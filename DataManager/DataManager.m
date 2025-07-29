//
//  DataManager.m
//  TradingApp
//

#import "DataManager.h"
#import "DownloadManager.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "DataAdapterFactory.h"
#import "DataSourceAdapter.h"
#import "OrderBookEntry.h"

@interface DataManager ()
@property (nonatomic, strong) DownloadManager *downloadManager;
@property (nonatomic, strong) NSMutableSet<id<DataManagerDelegate>> *delegates;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) NSMutableDictionary *activeRequests;
@property (nonatomic, strong) NSCache *quoteCache;
@property (nonatomic, strong) NSCache *historicalCache;
@end

@implementation DataManager

+ (instancetype)sharedManager {
    static DataManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _downloadManager = [[DownloadManager alloc] init];
        _delegates = [NSMutableSet set];
        _delegateQueue = dispatch_queue_create("DataManagerDelegateQueue", DISPATCH_QUEUE_CONCURRENT);
        _activeRequests = [NSMutableDictionary dictionary];
        _cacheEnabled = YES;
        _quoteCacheTTL = 60.0;      // 1 minute for on-demand quotes
        _historicalCacheTTL = 300.0; // 5 minutes for historical data
        
        // Setup caches
        _quoteCache = [[NSCache alloc] init];
        _quoteCache.countLimit = 100;
        _quoteCache.totalCostLimit = 1024 * 1024; // 1MB
        
        _historicalCache = [[NSCache alloc] init];
        _historicalCache.countLimit = 50;
        _historicalCache.totalCostLimit = 10 * 1024 * 1024; // 10MB
    }
    return self;
}

#pragma mark - Delegate Management

- (void)addDelegate:(id<DataManagerDelegate>)delegate {
    dispatch_barrier_async(self.delegateQueue, ^{
        [self.delegates addObject:delegate];
    });
}

- (void)removeDelegate:(id<DataManagerDelegate>)delegate {
    dispatch_barrier_async(self.delegateQueue, ^{
        [self.delegates removeObject:delegate];
    });
}

#pragma mark - Market Data Requests

- (NSString *)requestQuoteForSymbol:(NSString *)symbol
                         completion:(void (^)(MarketData *quote, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    // Check cache first
    if (self.cacheEnabled) {
        MarketData *cachedQuote = [self getCachedQuoteForSymbol:symbol];
        if (cachedQuote) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(cachedQuote, nil);
                });
            }
            return nil; // Return nil as no ongoing request
        }
    }
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    // Store the completion block directly without NSNull
    NSMutableDictionary *requestInfo = [@{
        @"type": @"quote",
        @"symbol": symbol
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    [self.downloadManager fetchQuoteForSymbol:symbol completion:^(id responseData, NSError *error) {
        [self handleQuoteResponse:responseData error:error forSymbol:symbol requestID:requestID completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"historical",
        @"symbol": symbol
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    [self.downloadManager fetchHistoricalDataForSymbol:symbol
                                             timeframe:timeframe
                                             startDate:startDate
                                               endDate:endDate
                                            completion:^(NSArray *bars, NSError *error) {
        [self handleHistoricalResponse:bars error:error forSymbol:symbol requestID:requestID completion:completion];
    }];
    
    return requestID;
}


- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion {
    
    // Calculate date range based on count and timeframe
    NSDate *endDate = [NSDate date];
    NSDate *startDate;
    
    NSTimeInterval interval;
    switch (timeframe) {
        case BarTimeframe1Min:
            interval = count * 60;
            break;
        case BarTimeframe5Min:
            interval = count * 300;
            break;
        case BarTimeframe15Min:
            interval = count * 900;
            break;
        case BarTimeframe1Hour:
            interval = count * 3600;
            break;
        case BarTimeframe1Day:
            interval = count * 86400;
            break;
        default:
            interval = count * 86400;
            break;
    }
    
    startDate = [NSDate dateWithTimeInterval:-interval sinceDate:endDate];
    
    return [self requestHistoricalDataForSymbol:symbol
                                      timeframe:timeframe
                                      startDate:startDate
                                        endDate:endDate
                                     completion:completion];
}

- (NSString *)requestOrderBookForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray<OrderBookEntry *> *bids,
                                                 NSArray<OrderBookEntry *> *asks,
                                                 NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, nil, error);
            });
        }
        return nil;
    }
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"orderbook",
        @"symbol": symbol
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    [self.downloadManager fetchOrderBookForSymbol:symbol
                                            depth:20
                                       completion:^(id orderBook, NSError *error) {
        [self handleOrderBookResponse:orderBook error:error forSymbol:symbol requestID:requestID completion:completion];
    }];
    
    return requestID;
}
#pragma mark - Account Data Requests

- (void)requestPositionsWithCompletion:(void (^)(NSArray<Position *> *positions, NSError *error))completion {
    [self.downloadManager fetchPositionsWithCompletion:completion];
}

- (void)requestOrdersWithCompletion:(void (^)(NSArray<Order *> *orders, NSError *error))completion {
    [self.downloadManager fetchOrdersWithCompletion:completion];
}

#pragma mark - Response Handlers

- (void)handleQuoteResponse:(id)responseData
                      error:(NSError *)error
                  forSymbol:(NSString *)symbol
                  requestID:(NSString *)requestID
                 completion:(void (^)(MarketData *quote, NSError *error))completion {
    
    if (error) {
        [self.activeRequests removeObjectForKey:requestID];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        [self notifyDelegatesOfError:error forRequest:requestID];
        return;
    }
    
    // Get appropriate adapter and standardize data
    id<DataSourceAdapter> adapter = [self getAdapterForCurrentDataSource];
    if (!adapter) {
        NSError *adapterError = [NSError errorWithDomain:@"DataManager"
                                                     code:102
                                                 userInfo:@{NSLocalizedDescriptionKey: @"No adapter for current data source"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion) {
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
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, standardizationError);
            });
        }
        return;
    }
    
    // Update cache
    [self updateQuoteCache:standardizedQuote forSymbol:symbol];
    
    [self.activeRequests removeObjectForKey:requestID];
    
    // Call completion
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedQuote, nil);
        });
    }
    
    // Notify delegates
    [self notifyDelegatesOfQuoteUpdate:standardizedQuote forSymbol:symbol];
}

- (void)handleHistoricalResponse:(NSArray *)bars
                           error:(NSError *)error
                       forSymbol:(NSString *)symbol
                       requestID:(NSString *)requestID
                      completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion {
    
    if (error) {
        [self.activeRequests removeObjectForKey:requestID];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        [self notifyDelegatesOfError:error forRequest:requestID];
        return;
    }
    
    // Process and standardize historical data
    id<DataSourceAdapter> adapter = [self getAdapterForCurrentDataSource];
    NSArray<HistoricalBar *> *standardizedBars = [adapter standardizeHistoricalData:bars forSymbol:symbol];
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedBars, nil);
        });
    }
    
    [self notifyDelegatesOfHistoricalUpdate:standardizedBars forSymbol:symbol];
}

- (void)handleOrderBookResponse:(id)orderBook
                          error:(NSError *)error
                      forSymbol:(NSString *)symbol
                      requestID:(NSString *)requestID
                     completion:(void (^)(NSArray<OrderBookEntry *> *bids,
                                         NSArray<OrderBookEntry *> *asks,
                                         NSError *error))completion {
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, nil, error);
            });
        }
        return;
    }
    
    // Process order book data
    id<DataSourceAdapter> adapter = [self getAdapterForCurrentDataSource];
    NSDictionary *processedOrderBook = [adapter standardizeOrderBookData:orderBook forSymbol:symbol];
    
    NSArray<OrderBookEntry *> *bids = processedOrderBook[@"bids"];
    NSArray<OrderBookEntry *> *asks = processedOrderBook[@"asks"];
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(bids, asks, nil);
        });
    }
}
#pragma mark - Cache Management

- (MarketData *)getCachedQuoteForSymbol:(NSString *)symbol {
    NSDictionary *cacheEntry = [self.quoteCache objectForKey:symbol];
    if (!cacheEntry) return nil;
    
    NSDate *timestamp = cacheEntry[@"timestamp"];
    if ([[NSDate date] timeIntervalSinceDate:timestamp] > self.quoteCacheTTL) {
        [self.quoteCache removeObjectForKey:symbol];
        return nil;
    }
    
    return cacheEntry[@"data"];
}

- (void)updateQuoteCache:(MarketData *)quote forSymbol:(NSString *)symbol {
    if (!self.cacheEnabled) return;
    
    NSDictionary *cacheEntry = @{
        @"data": quote,
        @"timestamp": [NSDate date]
    };
    
    [self.quoteCache setObject:cacheEntry forKey:symbol];
}

- (void)clearCache {
    [self.quoteCache removeAllObjects];
    [self.historicalCache removeAllObjects];
}

#pragma mark - Helper Methods

- (id<DataSourceAdapter>)getAdapterForCurrentDataSource {
    DataSourceType currentSource = self.downloadManager.currentDataSource;
    return [DataAdapterFactory adapterForDataSource:currentSource];
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

#pragma mark - Request Management

- (void)cancelRequest:(NSString *)requestID {
    [self.activeRequests removeObjectForKey:requestID];
}

- (void)cancelAllRequests {
    [self.activeRequests removeAllObjects];
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

@end
