//
//  DataManager.m
//  TradingApp
//
//  UPDATED: Now works with runtime models from adapters
//

#import "DataManager.h"
#import "DownloadManager.h"
#import "MarketData.h"
#import "DataAdapterFactory.h"
#import "DataSourceAdapter.h"
#import "OrderBookEntry.h"
#import "RuntimeModels.h"  // Add runtime models import

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

// Historical data - with date range
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion {
    
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
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"startDate": startDate ?: [NSDate dateWithTimeIntervalSinceNow:-86400 * 30], // Default 30 days
        @"endDate": endDate ?: [NSDate date]
    };
    
    NSMutableDictionary *requestInfo = [@{
        @"type": @"historical",
        @"symbol": symbol,
        @"timeframe": @(timeframe)
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    [self.downloadManager executeRequest:DataRequestTypeHistoricalBars
                              parameters:parameters
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleHistoricalResponse:result
                                 error:error
                             forSymbol:symbol
                            timeframe:timeframe
                             requestID:requestID
                            completion:completion];
    }];
    
    return requestID;
}

// Historical data - with count
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion {
    
    // Calculate date range from count
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self calculateStartDateForTimeframe:timeframe count:count fromDate:endDate];
    
    return [self requestHistoricalDataForSymbol:symbol
                                      timeframe:timeframe
                                      startDate:startDate
                                        endDate:endDate
                                     completion:completion];
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
    
    // Standardize the data (unchanged - still returns MarketData)
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

// UPDATED: Now handles runtime HistoricalBarModel objects from adapters
- (void)handleHistoricalResponse:(NSArray *)rawData
                           error:(NSError *)error
                       forSymbol:(NSString *)symbol
                       timeframe:(BarTimeframe)timeframe
                       requestID:(NSString *)requestID
                      completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion {
    
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
    
    // UPDATED: L'adapter ora restituisce runtime HistoricalBarModel objects
    NSArray<HistoricalBarModel *> *runtimeBars = [adapter standardizeHistoricalData:rawData forSymbol:symbol];
    
    if (!runtimeBars || runtimeBars.count == 0) {
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
    
    // Set timeframe on all bars (adapter might not have this context)
    for (HistoricalBarModel *bar in runtimeBars) {
        bar.timeframe = timeframe;
    }
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeBars, nil);
        });
    }
    
    // UPDATED: Notifica con runtime models
    [self notifyDelegatesOfHistoricalUpdate:runtimeBars forSymbol:symbol];
}
// Order book requests
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
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"depth": @(10) // Default depth
    };
    
    NSMutableDictionary *requestInfo = [@{
        @"type": @"orderbook",
        @"symbol": symbol
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
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

// Account data requests - AGGIORNATI per restituire dizionari
- (void)requestPositionsWithCompletion:(void (^)(NSArray<NSDictionary *> *positionDictionaries, NSError *error))completion {
    [self.downloadManager executeRequest:DataRequestTypePositions
                              parameters:@{}
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (completion) {
            completion(result, error);
        }
    }];
}

- (void)requestOrdersWithCompletion:(void (^)(NSArray<NSDictionary *> *orderDictionaries, NSError *error))completion {
    [self.downloadManager executeRequest:DataRequestTypeOrders
                              parameters:@{}
                              completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (completion) {
            completion(result, error);
        }
    }];
}

#pragma mark - Response Handlers


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
    
    // Process order book data through adapter
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

// UPDATED: Now notifies with runtime HistoricalBarModel objects
- (void)notifyDelegatesOfHistoricalUpdate:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol {
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
