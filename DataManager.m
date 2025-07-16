//
//  DataManager.m
//  TradingApp
//

#import "DataManager.h"
#import "DownloadManager.h"
#import "MarketDataModels.h"
#import <AppKit/AppKit.h>

@interface DataManager ()
@property (nonatomic, strong) DownloadManager *downloadManager;
@property (nonatomic, strong) NSMutableSet<id<DataManagerDelegate>> *delegates;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *activeRequests;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketData *> *quoteCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *subscribedSymbols;
@property (nonatomic, strong) NSTimer *quoteTimer;
@property (nonatomic, assign) BOOL cacheEnabled;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@end

@implementation DataManager

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
        _subscribedSymbols = [NSMutableSet set];
        _cacheEnabled = YES;
        _delegateQueue = dispatch_queue_create("com.tradingapp.datamanager.delegates", DISPATCH_QUEUE_SERIAL);
        
        [self setupNotifications];
    }
    return self;
}

- (void)setupNotifications {
    // Use NSWorkspace notifications for macOS
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

#pragma mark - Market Data Requests

- (NSString *)requestQuoteForSymbol:(NSString *)symbol
                          completion:(void (^)(MarketData *quote, NSError *error))completion {
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    // Check cache first
    if (self.cacheEnabled && self.quoteCache[symbol]) {
        MarketData *cachedQuote = self.quoteCache[symbol];
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:cachedQuote.timestamp];
        if (age < 5.0) { // 5 second cache
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(cachedQuote, nil);
                });
            }
            return requestID;
        }
    }
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"requestID": requestID
    };
    
    [self.downloadManager executeRequest:DataRequestTypeQuote
                              parameters:parameters
                          preferredSource:DataSourceTypeSchwab
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            [self notifyDelegatesOfError:error forRequest:requestID];
        } else {
            MarketData *quote = result;
            
            // Update cache
            if (self.cacheEnabled) {
                self.quoteCache[symbol] = quote;
            }
            
            if (completion) completion(quote, nil);
            
            // Notify delegates
            [self notifyDelegatesOfQuoteUpdate:quote forSymbol:symbol];
        }
    }];
    
    return requestID;
}

- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion {
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"startDate": startDate,
        @"endDate": endDate,
        @"requestID": requestID
    };
    
    [self.downloadManager executeRequest:DataRequestTypeHistoricalBars
                              parameters:parameters
                          preferredSource:DataSourceTypeSchwab
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            [self notifyDelegatesOfError:error forRequest:requestID];
        } else {
            NSArray<HistoricalBar *> *bars = result;
            if (completion) completion(bars, nil);
        }
    }];
    
    return requestID;
}

- (NSString *)requestOrderBookForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray<OrderBookEntry *> *bids,
                                                 NSArray<OrderBookEntry *> *asks,
                                                 NSError *error))completion {
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"depth": @20,
        @"requestID": requestID
    };
    
    [self.downloadManager executeRequest:DataRequestTypeOrderBook
                              parameters:parameters
                          preferredSource:DataSourceTypeSchwab
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (error) {
            if (completion) completion(nil, nil, error);
            [self notifyDelegatesOfError:error forRequest:requestID];
        } else {
            NSDictionary *orderBook = result;
            NSArray *bids = orderBook[@"bids"];
            NSArray *asks = orderBook[@"asks"];
            
            if (completion) completion(bids, asks, nil);
            
            // Notify delegates
            NSMutableArray *allEntries = [NSMutableArray arrayWithArray:bids];
            [allEntries addObjectsFromArray:asks];
            [self notifyDelegatesOfOrderBookUpdate:allEntries forSymbol:symbol];
        }
    }];
    
    return requestID;
}

#pragma mark - Real-time Subscriptions

- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols {
    [self.subscribedSymbols addObjectsFromArray:symbols];
    
    // Start quote timer if not running
    if (!self.quoteTimer && self.subscribedSymbols.count > 0) {
        self.quoteTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(updateQuotes:)
                                                        userInfo:nil
                                                         repeats:YES];
    }
}

- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols {
    for (NSString *symbol in symbols) {
        [self.subscribedSymbols removeObject:symbol];
    }
    
    // Stop timer if no more subscriptions
    if (self.subscribedSymbols.count == 0 && self.quoteTimer) {
        [self.quoteTimer invalidate];
        self.quoteTimer = nil;
    }
}

- (void)updateQuotes:(NSTimer *)timer {
    for (NSString *symbol in self.subscribedSymbols) {
        [self requestQuoteForSymbol:symbol completion:nil];
    }
}

#pragma mark - Account Data

- (void)requestPositionsWithCompletion:(void (^)(NSArray<Position *> *positions, NSError *error))completion {
    NSDictionary *parameters = @{
        @"requestID": [[NSUUID UUID] UUIDString]
    };
    
    [self.downloadManager executeRequest:DataRequestTypePositions
                              parameters:parameters
                          preferredSource:DataSourceTypeSchwab
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            NSArray<Position *> *positions = result;
            if (completion) completion(positions, nil);
            [self notifyDelegatesOfPositionsUpdate:positions];
        }
    }];
}

- (void)requestOrdersWithCompletion:(void (^)(NSArray<Order *> *orders, NSError *error))completion {
    NSDictionary *parameters = @{
        @"requestID": [[NSUUID UUID] UUIDString]
    };
    
    [self.downloadManager executeRequest:DataRequestTypeOrders
                              parameters:parameters
                          preferredSource:DataSourceTypeSchwab
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            NSArray<Order *> *orders = result;
            if (completion) completion(orders, nil);
            [self notifyDelegatesOfOrdersUpdate:orders];
        }
    }];
}

#pragma mark - Delegate Notifications

- (void)notifyDelegatesOfQuoteUpdate:(MarketData *)quote forSymbol:(NSString *)symbol {
    // Codice esistente per notificare i delegates...
    dispatch_async(self.delegateQueue, ^{
        for (id<DataManagerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(dataManager:didUpdateQuote:forSymbol:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate dataManager:self didUpdateQuote:quote forSymbol:symbol];
                });
            }
        }
    });
    
    // NUOVO: Notifica anche l'AlertManager
    if (quote && [quote.last doubleValue] > 0) {
         [[NSNotificationCenter defaultCenter] postNotificationName:@"PriceUpdateNotification"
                                                             object:self
                                                           userInfo:@{
                                                               @"symbol": symbol,
                                                               @"price": @([quote.last doubleValue]),
                                                               @"bid": @([quote.bid doubleValue]),
                                                               @"ask": @([quote.ask doubleValue]),
                                                               @"timestamp": quote.timestamp ?: [NSDate date]
                                                           }];
     }
 }

- (void)notifyDelegatesOfOrderBookUpdate:(NSArray<OrderBookEntry *> *)orderBook forSymbol:(NSString *)symbol {
    dispatch_async(self.delegateQueue, ^{
        for (id<DataManagerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(dataManager:didUpdateOrderBook:forSymbol:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate dataManager:self didUpdateOrderBook:orderBook forSymbol:symbol];
                });
            }
        }
    });
}

- (void)notifyDelegatesOfPositionsUpdate:(NSArray<Position *> *)positions {
    dispatch_async(self.delegateQueue, ^{
        for (id<DataManagerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(dataManager:didUpdatePositions:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate dataManager:self didUpdatePositions:positions];
                });
            }
        }
    });
}

- (void)notifyDelegatesOfOrdersUpdate:(NSArray<Order *> *)orders {
    dispatch_async(self.delegateQueue, ^{
        for (id<DataManagerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(dataManager:didUpdateOrders:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate dataManager:self didUpdateOrders:orders];
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
    // TODO: Implement actual request cancellation in DownloadManager
}

- (void)cancelAllRequests {
    [self.activeRequests removeAllObjects];
    // TODO: Implement in DownloadManager
}

#pragma mark - Cache Management

- (void)setCacheEnabled:(BOOL)enabled {
    _cacheEnabled = enabled;
    if (!enabled) {
        [self clearCache];
    }
}

- (void)clearCache {
    [self.quoteCache removeAllObjects];
}

#pragma mark - Connection Status

- (BOOL)isConnected {
    return [self.downloadManager isDataSourceConnected:DataSourceTypeSchwab] ||
           [self.downloadManager isDataSourceConnected:DataSourceTypeIBKR] ||
           [self.downloadManager isDataSourceConnected:DataSourceTypeYahoo];
}

- (NSArray<NSString *> *)availableDataSources {
    NSMutableArray *sources = [NSMutableArray array];
    
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        [sources addObject:@"Schwab"];
    }
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeIBKR]) {
        [sources addObject:@"Interactive Brokers"];
    }
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeYahoo]) {
        [sources addObject:@"Yahoo Finance"];
    }
    
    return sources;
}

- (NSString *)activeDataSource {
    // Return the primary connected source
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        return @"Charles Schwab";
    } else if ([self.downloadManager isDataSourceConnected:DataSourceTypeIBKR]) {
        return @"Interactive Brokers";
    } else if ([self.downloadManager isDataSourceConnected:DataSourceTypeYahoo]) {
        return @"Yahoo Finance";
    }
    return @"None";
}

#pragma mark - Application Lifecycle

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    // Resume quote updates
    if (self.subscribedSymbols.count > 0 && !self.quoteTimer) {
        self.quoteTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(updateQuotes:)
                                                        userInfo:nil
                                                         repeats:YES];
    }
}

- (void)applicationDidResignActive:(NSNotification *)notification {
    // Pause quote updates to save resources
    if (self.quoteTimer) {
        [self.quoteTimer invalidate];
        self.quoteTimer = nil;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [self.quoteTimer invalidate];
}


#pragma mark helper


- (NSDictionary *)dataForSymbol:(NSString *)symbol {
    MarketData *quote = self.quoteCache[symbol];
    if (!quote) {
        return nil;
    }
    
    return @{
           @"symbol": symbol,
           @"last": @([quote.last doubleValue]),
           @"bid": @([quote.bid doubleValue]),
           @"ask": @([quote.ask doubleValue]),
           @"high": @([quote.high doubleValue]),
           @"low": @([quote.low doubleValue]),
           @"open": @([quote.open doubleValue]),
           @"close": @([quote.close doubleValue]),
           @"volume": @(quote.volume),
           @"timestamp": quote.timestamp ?: [NSDate date]
       };
}

- (double)tickSizeForSymbol:(NSString *)symbol {
    // Logica per determinare il tick size basato sul simbolo
    // Questa è una implementazione di esempio - adattala alle tue esigenze
    
    NSString *upperSymbol = [symbol uppercaseString];
    
    // Forex majors con JPY
    if ([upperSymbol containsString:@"JPY"]) {
        return 0.001;  // 3 decimali
    }
    
    // Metalli preziosi
    if ([upperSymbol containsString:@"XAU"] || [upperSymbol containsString:@"XAG"]) {
        return 0.01;   // 2 decimali per oro/argento
    }
    
    // Altri Forex (EUR/USD, GBP/USD, etc.)
    if ([upperSymbol containsString:@"/"] &&
        ([upperSymbol containsString:@"EUR"] ||
         [upperSymbol containsString:@"GBP"] ||
         [upperSymbol containsString:@"USD"] ||
         [upperSymbol containsString:@"CHF"] ||
         [upperSymbol containsString:@"CAD"] ||
         [upperSymbol containsString:@"AUD"] ||
         [upperSymbol containsString:@"NZD"])) {
        return 0.00001;  // 5 decimali standard Forex
    }
    
    // Indici
    if ([upperSymbol containsString:@"SPX"] ||
        [upperSymbol containsString:@"NDX"] ||
        [upperSymbol containsString:@"DJI"]) {
        return 0.25;  // Quarter point per indici
    }
    
    // Futures
    if ([upperSymbol hasPrefix:@"ES"] || [upperSymbol hasPrefix:@"NQ"]) {
        return 0.25;  // E-mini futures
    }
    
    // Default per azioni e altri strumenti
    return 0.01;  // 2 decimali
}
@end
