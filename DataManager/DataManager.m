//
//  DataManager.m
//  TradingApp
//
//  Refactored to use standardized data adapters
//

#import "DataManager.h"
#import "CommonTypes.h"
#import "DownloadManager.h"
#import "DataAdapterFactory.h"
#import "DataSourceAdapter.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "Position.h"
#import "Order.h"
#import "OrderBookEntry.h"
#import "DataManager+Persistence.h"
#import "DataManager+Cache.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import <AppKit/AppKit.h>

@interface DataManager ()
@property (nonatomic, strong) DownloadManager *downloadManager;
@property (nonatomic, strong) NSMutableSet<id<DataManagerDelegate>> *delegates;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *activeRequests;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketData *> *quoteCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *cacheTimestamps;
@property (nonatomic, strong) NSMutableSet<NSString *> *subscribedSymbols;
@property (nonatomic, strong) NSTimer *quoteTimer;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@end

@implementation DataManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static DataManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _downloadManager = [DownloadManager sharedManager];
        _delegates = [NSMutableSet set];
        _activeRequests = [NSMutableDictionary dictionary];
        _quoteCache = [NSMutableDictionary dictionary];
        _cacheTimestamps = [NSMutableDictionary dictionary];
        _subscribedSymbols = [NSMutableSet set];
        _cacheEnabled = YES;
        _delegateQueue = dispatch_queue_create("com.tradingapp.datamanager.delegates", DISPATCH_QUEUE_SERIAL);
        
        // Default cache TTLs
        _quoteCacheTTL = 5.0; // 5 seconds for real-time quotes
        _historicalCacheTTL = 300.0; // 5 minutes for historical data
        self.autoSaveToDataHub = YES;
              self.saveHistoricalData = YES;
              self.saveMarketLists = YES;
        [self setupNotifications];
    }
    return self;
}

- (void)setupNotifications {
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                            selector:@selector(applicationDidBecomeActive:)
                                                                name:NSWorkspaceDidActivateApplicationNotification
                                                              object:nil];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                            selector:@selector(applicationDidResignActive:)
                                                                name:NSWorkspaceDidDeactivateApplicationNotification
                                                              object:nil];
}

#pragma mark - Delegate Management

- (void)addDelegate:(id<DataManagerDelegate>)delegate {
    dispatch_async(self.delegateQueue, ^{
        [self.delegates addObject:delegate];
    });
}

- (void)removeDelegate:(id<DataManagerDelegate>)delegate {
    dispatch_async(self.delegateQueue, ^{
        [self.delegates removeObject:delegate];
    });
}

#pragma mark - Quote Requests

- (NSString *)requestQuoteForSymbol:(NSString *)symbol
                          completion:(void (^)(MarketData *quote, NSError *error))completion {
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    // Check cache first
    if ([self isQuoteCacheValidForSymbol:symbol]) {
        MarketData *cachedQuote = self.quoteCache[symbol];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(cachedQuote, nil);
            });
        }
        return requestID;
    }
    
    // Store the request
    self.activeRequests[requestID] = @{
        @"type": @"quote",
        @"symbol": symbol,
        @"completion": completion ? [completion copy] : [NSNull null]
    };
    
    // Request from DownloadManager
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"requestID": requestID
    };
    
    [self.downloadManager executeRequest:DataRequestTypeQuote
                              parameters:parameters
                          preferredSource:DataSourceTypeSchwab
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleQuoteResponse:result
                   fromDataSource:usedSource
                        forSymbol:symbol
                        requestID:requestID
                           error:error];
    }];
    
    return requestID;
}

#pragma mark - Historical Data Requests

- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion {
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    // Store the request
    self.activeRequests[requestID] = @{
        @"type": @"historical",
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"count": @(count),
        @"completion": completion ? [completion copy] : [NSNull null]
    };
    
    // Request from DownloadManager
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"count": @(count),
        @"requestID": requestID
    };
    
    [self.downloadManager executeRequest:DataRequestTypeHistoricalBars
                              parameters:parameters
                          preferredSource:DataSourceTypeSchwab
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleHistoricalResponse:result
                        fromDataSource:usedSource
                             forSymbol:symbol
                             requestID:requestID
                                 error:error];
    }];
    
    return requestID;
}

- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion {
    // For now, convert to count-based request
    // TODO: Implement proper date range support
    NSInteger count = 100; // Default count
    return [self requestHistoricalDataForSymbol:symbol
                                      timeframe:timeframe
                                          count:count
                                     completion:completion];
}

#pragma mark - Response Handlers with Standardization

- (void)handleQuoteResponse:(id)responseData
             fromDataSource:(DataSourceType)sourceType
                  forSymbol:(NSString *)symbol
                  requestID:(NSString *)requestID
                      error:(NSError *)error {
    
    // Get stored request info
    NSDictionary *requestInfo = self.activeRequests[requestID];
    void (^completion)(MarketData *, NSError *) = requestInfo[@"completion"];
    
    if (error) {
        [self.activeRequests removeObjectForKey:requestID];
        if (completion && completion != (id)[NSNull null]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Get appropriate adapter
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:sourceType];
    
    if (!adapter) {
        NSError *adapterError = [NSError errorWithDomain:@"DataManager"
                                                     code:100
                                                 userInfo:@{NSLocalizedDescriptionKey: @"No adapter available for data source"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion && completion != (id)[NSNull null]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, adapterError);
            });
        }
        return;
    }
    
    // Standardize the data
    MarketData *standardizedQuote = [adapter standardizeQuoteData:responseData forSymbol:symbol];
    
    if (!standardizedQuote) {
        NSError *standardizationError = [NSError errorWithDomain:@"DataManager"
                                                             code:101
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to standardize quote data"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion && completion != (id)[NSNull null]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, standardizationError);
            });
        }
        return;
    }
    
    // Update cache
    [self updateQuoteCache:standardizedQuote forSymbol:symbol];
    
    // NUOVO: Salva automaticamente in DataHub
    if (self.autoSaveToDataHub) {
        // Converti MarketData in dictionary per DataHub
        NSDictionary *quoteDict = @{
            @"symbol": symbol,
            @"name": standardizedQuote.name ?: symbol,
            @"last": standardizedQuote.last ?: @0,
            @"bid": standardizedQuote.bid ?: @0,
            @"ask": standardizedQuote.ask ?: @0,
            @"volume": standardizedQuote.volume ?: @0,
            @"open": standardizedQuote.open ?: @0,
            @"high": standardizedQuote.high ?: @0,
            @"low": standardizedQuote.low ?: @0,
            @"previousClose": standardizedQuote.previousClose ?: @0,
            @"change": standardizedQuote.change ?: @0,
            @"changePercent": standardizedQuote.changePercent ?: @0,
            @"timestamp": standardizedQuote.timestamp ?: [NSDate date]
        };
        
        [self saveQuoteToDataHub:quoteDict forSymbol:symbol];
    }
    
    // Notify delegates
    [self notifyDelegatesOfQuoteUpdate:standardizedQuote forSymbol:symbol];
    
    // Complete the request
    [self.activeRequests removeObjectForKey:requestID];
    if (completion && completion != (id)[NSNull null]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedQuote, nil);
        });
    }
}
- (void)handleHistoricalResponse:(id)responseData
                  fromDataSource:(DataSourceType)sourceType
                       forSymbol:(NSString *)symbol
                       requestID:(NSString *)requestID
                           error:(NSError *)error {
    
    // Get stored request info
    NSDictionary *requestInfo = self.activeRequests[requestID];
    void (^completion)(NSArray<HistoricalBar *> *, NSError *) = requestInfo[@"completion"];
    
    if (error) {
        [self.activeRequests removeObjectForKey:requestID];
        if (completion && completion != (id)[NSNull null]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Get appropriate adapter
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:sourceType];
    
    if (!adapter) {
        NSError *adapterError = [NSError errorWithDomain:@"DataManager"
                                                     code:100
                                                 userInfo:@{NSLocalizedDescriptionKey: @"No adapter available for data source"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion && completion != (id)[NSNull null]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, adapterError);
            });
        }
        return;
    }
    
    // Standardize the data
    NSArray<HistoricalBar *> *standardizedBars = [adapter standardizeHistoricalData:responseData forSymbol:symbol];
    
    if (!standardizedBars) {
        NSError *standardizationError = [NSError errorWithDomain:@"DataManager"
                                                             code:102
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to standardize historical data"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion && completion != (id)[NSNull null]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, standardizationError);
            });
        }
        return;
    }
    
    // Notify delegates
    [self notifyDelegatesOfHistoricalUpdate:standardizedBars forSymbol:symbol];
    
    // Complete the request
    [self.activeRequests removeObjectForKey:requestID];
    if (completion && completion != (id)[NSNull null]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedBars, nil);
        });
    }
}

#pragma mark - Other Request Types

- (NSString *)requestOrderBookForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray<OrderBookEntry *> *bids,
                                                 NSArray<OrderBookEntry *> *asks,
                                                 NSError *error))completion {
    // TODO: Implement order book requests
    NSString *requestID = [[NSUUID UUID] UUIDString];
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"DataManager"
                                                 code:501
                                             userInfo:@{NSLocalizedDescriptionKey: @"Order book not implemented"}];
            completion(nil, nil, error);
        });
    }
    return requestID;
}

- (void)requestPositionsWithCompletion:(void (^)(NSArray<Position *> *positions, NSError *error))completion {
    // TODO: Implement positions request
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], nil);
        });
    }
}

- (void)requestOrdersWithCompletion:(void (^)(NSArray<Order *> *orders, NSError *error))completion {
    // TODO: Implement orders request
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], nil);
        });
    }
}

#pragma mark - Cache Management

- (BOOL)isQuoteCacheValidForSymbol:(NSString *)symbol {
    if (!self.cacheEnabled) return NO;
    
    MarketData *cachedQuote = self.quoteCache[symbol];
    NSDate *cacheTime = self.cacheTimestamps[symbol];
    
    if (!cachedQuote || !cacheTime) return NO;
    
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:cacheTime];
    return age < self.quoteCacheTTL;
}

- (void)updateQuoteCache:(MarketData *)quote forSymbol:(NSString *)symbol {
    if (!self.cacheEnabled) return;
    
    @synchronized(self.quoteCache) {
        self.quoteCache[symbol] = quote;
        self.cacheTimestamps[symbol] = [NSDate date];
    }
}

- (void)clearCache {
    @synchronized(self.quoteCache) {
        [self.quoteCache removeAllObjects];
        [self.cacheTimestamps removeAllObjects];
    }
}

- (void)clearCacheForSymbol:(NSString *)symbol {
    @synchronized(self.quoteCache) {
        [self.quoteCache removeObjectForKey:symbol];
        [self.cacheTimestamps removeObjectForKey:symbol];
    }
}

#pragma mark - Delegate Notifications

- (void)notifyDelegatesOfQuoteUpdate:(MarketData *)quote forSymbol:(NSString *)symbol {
    dispatch_async(self.delegateQueue, ^{
        for (id<DataManagerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(dataManager:didUpdateQuote:forSymbol:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate dataManager:self didUpdateQuote:quote forSymbol:symbol];
                });
            }
        }
    });
}

- (void)notifyDelegatesOfHistoricalUpdate:(NSArray<HistoricalBar *> *)bars forSymbol:(NSString *)symbol {
    dispatch_async(self.delegateQueue, ^{
        for (id<DataManagerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(dataManager:didUpdateHistoricalData:forSymbol:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate dataManager:self didUpdateHistoricalData:bars forSymbol:symbol];
                });
            }
        }
    });
}

- (void)notifyDelegatesOfError:(NSError *)error forRequest:(NSString *)requestID {
    dispatch_async(self.delegateQueue, ^{
        for (id<DataManagerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(dataManager:didFailWithError:forRequest:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate dataManager:self didFailWithError:error forRequest:requestID];
                });
            }
        }
    });
}

#pragma mark - Subscription Management

- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols {
    [self.subscribedSymbols addObjectsFromArray:symbols];
    
    if (!self.quoteTimer) {
        self.quoteTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                           target:self
                                                         selector:@selector(refreshSubscribedQuotes)
                                                         userInfo:nil
                                                          repeats:YES];
    }
}

- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols {
    for (NSString *symbol in symbols) {
        [self.subscribedSymbols removeObject:symbol];
    }
    
    if (self.subscribedSymbols.count == 0 && self.quoteTimer) {
        [self.quoteTimer invalidate];
        self.quoteTimer = nil;
    }
}

- (void)refreshSubscribedQuotes {
    for (NSString *symbol in self.subscribedSymbols) {
        [self requestQuoteForSymbol:symbol completion:nil];
    }
}

#pragma mark - Application State

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    // Resume updates when app becomes active
    if (self.subscribedSymbols.count > 0 && !self.quoteTimer) {
        [self refreshSubscribedQuotes];
        self.quoteTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                           target:self
                                                         selector:@selector(refreshSubscribedQuotes)
                                                         userInfo:nil
                                                          repeats:YES];
    }
}

- (void)applicationDidResignActive:(NSNotification *)notification {
    // Pause updates when app is in background
    if (self.quoteTimer) {
        [self.quoteTimer invalidate];
        self.quoteTimer = nil;
    }
}

#pragma mark - Request Management

- (void)cancelRequest:(NSString *)requestID {
    [self.activeRequests removeObjectForKey:requestID];
    // DownloadManager doesn't have cancelRequest method, just remove from our tracking
}

- (void)cancelAllRequests {
    [self.activeRequests removeAllObjects];
    // DownloadManager doesn't have cancelAllRequests method
}

#pragma mark - Connection Status

- (BOOL)isConnected {
    return [self.downloadManager isDataSourceConnected:DataSourceTypeSchwab] ||
           [self.downloadManager isDataSourceConnected:DataSourceTypeCustom];
}

- (NSArray<NSString *> *)availableDataSources {
    NSMutableArray *sources = [NSMutableArray array];
    
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        [sources addObject:@"Schwab"];
    }
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeCustom]) {
        [sources addObject:@"Webull"];
    }
    
    return sources;
}

- (NSString *)activeDataSource {
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        return @"Schwab";
    } else if ([self.downloadManager isDataSourceConnected:DataSourceTypeCustom]) {
        return @"Webull";
    }
    return @"None";
}

#pragma mark - Cleanup

- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [self.quoteTimer invalidate];
}





@end
