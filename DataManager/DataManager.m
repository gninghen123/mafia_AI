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
        _downloadManager = [DownloadManager sharedManager];
        _delegates = [NSMutableSet set];
        _delegateQueue = dispatch_queue_create("DataManagerDelegateQueue", DISPATCH_QUEUE_CONCURRENT);
        _activeRequests = [NSMutableDictionary dictionary];
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
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"quote",
        @"symbol": symbol
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    // Usa executeRequest senza preferredSource - lascia decidere al DownloadManager
    [self.downloadManager executeRequest:DataRequestTypeQuote
                              parameters:@{@"symbol": symbol}
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleQuoteResponse:result
                            error:error
                        forSymbol:symbol
                        requestID:requestID
                       completion:completion];
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
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"startDate": startDate,
        @"endDate": endDate
    };
    
    // Usa executeRequest invece di fetchHistoricalDataForSymbol
    [self.downloadManager executeRequest:DataRequestTypeHistoricalBars
                              parameters:parameters
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleHistoricalResponse:result
                                 error:error
                             forSymbol:symbol
                             requestID:requestID
                            completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion {
    
    // Calculate date range based on count
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self calculateStartDateForTimeframe:timeframe count:count fromDate:endDate];
    
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
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"depth": @(20)
    };
    
    // Usa executeRequest invece di fetchOrderBookForSymbol
    [self.downloadManager executeRequest:DataRequestTypeOrderBook
                              parameters:parameters
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleOrderBookResponse:result
                                error:error
                            forSymbol:symbol
                            requestID:requestID
                           completion:completion];
    }];
    
    return requestID;
}

#pragma mark - Account Data Requests

- (void)requestPositionsWithCompletion:(void (^)(NSArray<Position *> *positions, NSError *error))completion {
    // Usa executeRequest invece di fetchPositionsWithCompletion
    [self.downloadManager executeRequest:DataRequestTypePositions
                              parameters:@{}
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (completion) {
            completion(result, error);
        }
    }];
}

- (void)requestOrdersWithCompletion:(void (^)(NSArray<Order *> *orders, NSError *error))completion {
    // Usa executeRequest invece di fetchOrdersWithCompletion
    [self.downloadManager executeRequest:DataRequestTypeOrders
                              parameters:@{}
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (completion) {
            completion(result, error);
        }
    }];
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
    
    // Standardizza i dati usando l'adapter
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
    
    // L'adapter ora restituisce array di dizionari
    NSArray<NSDictionary *> *standardizedData = [adapter standardizeHistoricalData:bars forSymbol:symbol];
    
    if (!standardizedData || standardizedData.count == 0) {
        NSError *standardizationError = [NSError errorWithDomain:@"DataManager"
                                                             code:103
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to standardize historical data"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, standardizationError);
            });
        }
        return;
    }
    
    [self.activeRequests removeObjectForKey:requestID];
    
    // Passa i dizionari al DataHub che li convertirà in oggetti Core Data
    // Per ora restituiamo array vuoto nel completion ma notifichiamo i dati corretti
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], nil); // Il DataHub gestirà la conversione
        });
    }
    
    // Notifica con i dati standardizzati (array di dizionari)
    [self notifyDelegatesOfHistoricalUpdate:standardizedData forSymbol:symbol];
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

#pragma mark - Helper Methods

- (id<DataSourceAdapter>)getAdapterForCurrentDataSource {
    DataSourceType currentSource = self.downloadManager.currentDataSource;
    return [DataAdapterFactory adapterForDataSource:currentSource];
}

- (NSDate *)calculateStartDateForTimeframe:(BarTimeframe)timeframe count:(NSInteger)count fromDate:(NSDate *)endDate {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    
    switch (timeframe) {
        case BarTimeframe1Min:
            components.minute = -count;
            break;
        case BarTimeframe5Min:
            components.minute = -count * 5;
            break;
        case BarTimeframe15Min:
            components.minute = -count * 15;
            break;
        case BarTimeframe30Min:
            components.minute = -count * 30;
            break;
        case BarTimeframe1Hour:
            components.hour = -count;
            break;
        case BarTimeframe4Hour:
            components.hour = -count * 4;
            break;
        case BarTimeframe1Day:
            components.day = -count;
            break;
        case BarTimeframe1Week:
            components.weekOfYear = -count;
            break;
        case BarTimeframe1Month:
            components.month = -count;
            break;
    }
    
    return [calendar dateByAddingComponents:components toDate:endDate options:0];
}

#pragma mark - Polling Management

- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols {
    // For now, just store the symbols for potential polling
    // In a real implementation, this would set up periodic requests
}

- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols {
    // Remove symbols from polling list
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
    [self.downloadManager cancelRequest:requestID];
}

- (void)cancelAllRequests {
    [self.activeRequests removeAllObjects];
    [self.downloadManager cancelAllRequests];
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
