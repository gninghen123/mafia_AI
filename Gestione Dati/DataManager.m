//
//  DataManager.m (UPDATED - NEW ARCHITECTURE)
//  TradingApp
//
//  📈 MARKET DATA: Uses executeMarketDataRequest (automatic routing with fallback)
//  🛡️ ACCOUNT DATA: Handled by DataManager+Portfolio extension
//
//  UPDATED: Now works with runtime models from adapters and secure DownloadManager APIs
//

#import "DataManager.h"
#import "DownloadManager.h"
#import "MarketData.h"
#import "OtherDataAdapter.h"
#import "DataAdapterFactory.h"
#import "SeasonalDataModel.h"
#import "DataSourceAdapter.h"
#import "OrderBookEntry.h"
#import "RuntimeModels.h"

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
        
        NSLog(@"📊 DataManager: Initialized with secure DownloadManager integration");
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

#pragma mark - 📈 Market Data Requests (Secure with Automatic Routing)

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
    
    NSLog(@"📈 DataManager: Requesting quote for symbol %@", symbol);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"quote",
        @"symbol": symbol
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    // 📈 MARKET DATA: Use secure market data request with automatic routing and fallback
    [self.downloadManager executeMarketDataRequest:DataRequestTypeQuote
                                        parameters:@{@"symbol": symbol}
                                        completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleQuoteResponse:result
                            error:error
                       usedSource:usedSource
                        forSymbol:symbol
                        requestID:requestID
                       completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestQuotesForSymbols:(NSArray<NSString *> *)symbols
                           completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    if (!symbols || symbols.count == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbols array"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"📈 DataManager: Requesting batch quotes for %lu symbols: %@", (unsigned long)symbols.count, symbols);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"batchQuotes",
        @"symbols": symbols
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    // 📈 MARKET DATA: Use secure market data request with automatic routing and fallback
    [self.downloadManager executeMarketDataRequest:DataRequestTypeBatchQuotes
                                        parameters:@{@"symbols": symbols}
                                        completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleBatchQuotesResponse:result
                                  error:error
                             usedSource:usedSource
                             forSymbols:symbols
                              requestID:requestID
                             completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                           needExtendedHours:(BOOL)needExtendedHours
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion {
    
    if (!symbol || symbol.length == 0 || !startDate || !endDate) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:101
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters for historical data request"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"📈 DataManager: Requesting historical data for %@ (%@, %@ to %@, extended: %@)",
          symbol, BarTimeframeToString(timeframe), startDate, endDate, @(needExtendedHours));
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"historical",
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"startDate": startDate,
        @"endDate": endDate,
        @"needExtendedHours": @(needExtendedHours)
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"startDate": startDate,
        @"endDate": endDate,
        @"needExtendedHours": @(needExtendedHours)
    };
    
    // 📈 MARKET DATA: Use secure market data request with automatic routing and fallback
    [self.downloadManager executeMarketDataRequest:DataRequestTypeHistoricalBars
                                        parameters:parameters
                                        completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleHistoricalDataResponse:result
                                     error:error
                                usedSource:usedSource
                                 forSymbol:symbol
                                 requestID:requestID
                                completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count
                           needExtendedHours:(BOOL)needExtendedHours
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion {
    
    if (!symbol || symbol.length == 0 || count <= 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:102
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters for historical data count request"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"📈 DataManager: Requesting %ld bars of historical data for %@ (%@, extended: %@)",
          (long)count, symbol, BarTimeframeToString(timeframe), @(needExtendedHours));
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"historical",
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"count": @(count),
        @"needExtendedHours": @(needExtendedHours)
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"barCount": @(count),
        @"needExtendedHours": @(needExtendedHours)
    };
    
    // 📈 MARKET DATA: Use secure market data request with automatic routing and fallback
    [self.downloadManager executeMarketDataRequest:DataRequestTypeHistoricalBars
                                        parameters:parameters
                                        completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleHistoricalDataResponse:result
                                     error:error
                                usedSource:usedSource
                                 forSymbol:symbol
                                 requestID:requestID
                                completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestOrderBookForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray<OrderBookEntry *> *bids,
                                                  NSArray<OrderBookEntry *> *asks,
                                                  NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:103
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol for order book request"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"📈 DataManager: Requesting order book for %@", symbol);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"orderBook",
        @"symbol": symbol
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"depth": @(20) // Default depth
    };
    
    // 📈 MARKET DATA: Use secure market data request with automatic routing and fallback
    [self.downloadManager executeMarketDataRequest:DataRequestTypeOrderBook
                                        parameters:parameters
                                        completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleOrderBookResponse:result
                                error:error
                           usedSource:usedSource
                            forSymbol:symbol
                            requestID:requestID
                           completion:completion];
    }];
    
    return requestID;
}

#pragma mark - Market Lists Implementation

- (void)getMarketPerformersForList:(NSString *)listType
                         timeframe:(NSString *)timeframe
                        completion:(void (^)(NSArray<MarketPerformerModel *> *performers, NSError *error))completion {
    
    if (!listType || !timeframe) {
        NSError *error = [NSError errorWithDomain:@"DataManagerError"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid listType or timeframe"}];
        if (completion) completion(@[], error);
        return;
    }
    
    NSLog(@"📈 DataManager: Getting market performers for list:%@ timeframe:%@", listType, timeframe);
    
    // Determine the request type based on listType
    DataRequestType requestType;
    if ([listType isEqualToString:@"gainers"]) {
        requestType = DataRequestTypeTopGainers;
    } else if ([listType isEqualToString:@"losers"]) {
        requestType = DataRequestTypeTopLosers;
    } else if ([listType isEqualToString:@"etf"]) {
        requestType = DataRequestTypeETFList;
    } else if ([listType isEqualToString:@"52WeekHigh"]) {
        requestType = DataRequestType52WeekHigh;
    } else if ([listType isEqualToString:@"52WeekLow"]) {
        requestType = DataRequestType52WeekLow;
    } else {
        requestType = DataRequestTypeMarketList;
    }
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"marketList",
        @"listType": listType
    } mutableCopy];
    
    if (completion) {
        requestInfo[@"completion"] = [completion copy];
    }
    
    self.activeRequests[requestID] = requestInfo;
    
    NSMutableDictionary *parameters = [@{@"listType": @(requestType)} mutableCopy];
    if (timeframe) {
        parameters[@"timeframe"] = timeframe;
    }
    
    // 📈 MARKET DATA: Use secure market data request with automatic routing and fallback
    [self.downloadManager executeMarketDataRequest:requestType
                                        parameters:[parameters copy]
                                        completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleMarketListResponse:result
                                 error:error
                            usedSource:usedSource
                               forList:listType
                             requestID:requestID
                            completion:completion];
    }];
}

#pragma mark - 📊 Response Handling (Updated for New Architecture)

- (void)handleQuoteResponse:(id)result
                      error:(NSError *)error
                 usedSource:(DataSourceType)usedSource
                  forSymbol:(NSString *)symbol
                  requestID:(NSString *)requestID
                 completion:(void (^)(MarketData *quote, NSError *error))completion {
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DataManager: Quote request failed for %@ from %@: %@",
              symbol, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        [self notifyDelegatesOfError:error forRequest:requestID];
        return;
    }
    
    NSLog(@"✅ DataManager: Quote received for %@ from %@", symbol, DataSourceTypeToString(usedSource));
    
    // Standardize the quote data using adapter
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    MarketData *standardizedQuote = nil;
    
    if (adapter && [result isKindOfClass:[NSDictionary class]]) {
          standardizedQuote = [adapter standardizeQuoteData:(NSDictionary *)result forSymbol:symbol];
      }
      
      if (!standardizedQuote) {
          NSError *parseError = [NSError errorWithDomain:@"DataManager"
                                                    code:150
                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to standardize quote data"}];
          if (completion) {
              dispatch_async(dispatch_get_main_queue(), ^{
                  completion(nil, parseError);
              });
          }
          return;
      }
    
    // Success - return standardized quote
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedQuote, nil);
        });
    }
    
    // Notify delegates
    [self notifyDelegatesOfQuoteUpdate:standardizedQuote forSymbol:symbol];
}

- (void)handleBatchQuotesResponse:(id)result
                            error:(NSError *)error
                       usedSource:(DataSourceType)usedSource
                       forSymbols:(NSArray<NSString *> *)symbols
                        requestID:(NSString *)requestID
                       completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DataManager: Batch quotes request failed for symbols from %@: %@",
              DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        [self notifyDelegatesOfError:error forRequest:requestID];
        return;
    }
    
    NSLog(@"✅ DataManager: Batch quotes received for %lu symbols from %@",
          (unsigned long)symbols.count, DataSourceTypeToString(usedSource));
    
    // CORREZIONE: Standardize batch quotes using adapter with forSymbols:
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    NSDictionary *standardizedQuotes = @{};
    
    if (adapter && [result isKindOfClass:[NSDictionary class]]) {
        standardizedQuotes = [adapter standardizeBatchQuotesData:(NSDictionary *)result forSymbols:symbols];
    }
    
    NSLog(@"📊 DataManager: Standardized %lu quotes via adapter", (unsigned long)standardizedQuotes.count);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedQuotes, nil);
        });
    }
    
    // Notify delegates
    [self notifyDelegatesOfBatchQuotesUpdate:standardizedQuotes forSymbols:symbols];
}

// FIX per DataManager.m - metodo handleHistoricalDataResponse
// Sostituire la sezione di standardizzazione dei dati storici

- (void)handleHistoricalDataResponse:(id)result
                               error:(NSError *)error
                          usedSource:(DataSourceType)usedSource
                           forSymbol:(NSString *)symbol
                           requestID:(NSString *)requestID
                          completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion {
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DataManager: Historical data request failed for %@ from %@: %@",
              symbol, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        [self notifyDelegatesOfError:error forRequest:requestID];
        return;
    }
    
    NSLog(@"✅ DataManager: Historical data received for %@ from %@", symbol, DataSourceTypeToString(usedSource));
    
    // ✅ FIXED: Standardize historical data using adapter - support both NSArray and NSDictionary
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    NSArray<HistoricalBarModel *> *standardizedBars = @[];
    
    if (adapter && result) {
        // ✅ NEW: Accept both NSArray (direct bars) and NSDictionary (wrapped response)
        if ([result isKindOfClass:[NSArray class]] || [result isKindOfClass:[NSDictionary class]]) {
            standardizedBars = [adapter standardizeHistoricalData:result forSymbol:symbol];
        } else {
            NSLog(@"⚠️ DataManager: Unexpected historical data format from %@: %@",
                  DataSourceTypeToString(usedSource), [result class]);
        }
    } else {
        NSLog(@"❌ DataManager: No adapter available for %@ or result is nil",
              DataSourceTypeToString(usedSource));
    }
    
    NSLog(@"📊 DataManager: Standardized %lu bars via %@ adapter",
          (unsigned long)standardizedBars.count, DataSourceTypeToString(usedSource));
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedBars, nil);
        });
    }
    
    // Notify delegates
    [self notifyDelegatesOfHistoricalDataUpdate:standardizedBars forSymbol:symbol];
}
- (void)handleOrderBookResponse:(id)result
                          error:(NSError *)error
                     usedSource:(DataSourceType)usedSource
                      forSymbol:(NSString *)symbol
                      requestID:(NSString *)requestID
                     completion:(void (^)(NSArray<OrderBookEntry *> *bids, NSArray<OrderBookEntry *> *asks, NSError *error))completion {
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DataManager: Order book request failed for %@ from %@: %@",
              symbol, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, nil, error);
            });
        }
        return;
    }
    
    NSLog(@"✅ DataManager: Order book received for %@ from %@", symbol, DataSourceTypeToString(usedSource));
    
    // Parse order book data (implementation depends on format)
    NSArray<OrderBookEntry *> *bids = @[];
    NSArray<OrderBookEntry *> *asks = @[];
    
    // TODO: Implement order book parsing based on result format
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(bids, asks, nil);
        });
    }
}

- (void)handleMarketListResponse:(id)result
                           error:(NSError *)error
                      usedSource:(DataSourceType)usedSource
                         forList:(NSString *)listType
                       requestID:(NSString *)requestID
                      completion:(void (^)(NSArray<MarketPerformerModel *> *performers, NSError *error))completion {
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DataManager: Market list request failed for %@ from %@: %@",
              listType, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        [self notifyDelegatesOfError:error forRequest:requestID];
        return;
    }
    
    NSLog(@"✅ DataManager: Market list data received for %@ from %@", listType, DataSourceTypeToString(usedSource));
    
    // ✅ NEW: Use adapter to standardize market list data instead of manual creation
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    NSArray<MarketPerformerModel *> *standardizedPerformers = @[];
    
    if (adapter && result) {
        // Extract timeframe from request info if available
        NSDictionary *requestInfo = self.activeRequests[requestID];
        NSString *timeframe = requestInfo[@"timeframe"] ?: @"1d"; // Default timeframe
        
        NSLog(@"📊 DataManager: Using %@ adapter to standardize market list data", DataSourceTypeToString(usedSource));
        
        // Use the new adapter method to standardize market list data
        standardizedPerformers = [adapter standardizeMarketListData:result
                                                           listType:listType
                                                          timeframe:timeframe];
    } else {
        NSLog(@"❌ DataManager: No adapter available for %@ or result is nil", DataSourceTypeToString(usedSource));
        
        // ⚠️ FALLBACK: Create MarketPerformerModel objects manually (legacy behavior)
        NSMutableArray<MarketPerformerModel *> *performers = [NSMutableArray array];
        
        if ([result isKindOfClass:[NSArray class]]) {
            for (NSDictionary *item in (NSArray *)result) {
                if ([item isKindOfClass:[NSDictionary class]]) {
                    MarketPerformerModel *performer = [[MarketPerformerModel alloc] init];
                    performer.symbol = item[@"symbol"];
                    performer.name = item[@"name"];
                    performer.exchange = item[@"exchange"];
                    performer.sector = item[@"sector"];
                    
                    // Price data - using NSNumber properties
                    performer.price = item[@"price"] ?: item[@"lastPrice"];
                    performer.change = item[@"change"];
                    performer.changePercent = item[@"changePercent"];
                    performer.volume = item[@"volume"];
                    performer.marketCap = item[@"marketCap"];
                    performer.avgVolume = item[@"avgVolume"];
                    
                    // List metadata
                    performer.listType = listType;
                    performer.timeframe = @"1d"; // Default timeframe
                    performer.timestamp = [NSDate date];
                    
                    if (performer.symbol) { // Solo se abbiamo almeno un symbol valido
                        [performers addObject:performer];
                    }
                }
            }
        }
        
        standardizedPerformers = [performers copy];
        NSLog(@"📦 DataManager: Used fallback manual creation for %lu performers", (unsigned long)standardizedPerformers.count);
    }
    
    NSLog(@"✅ DataManager: Standardized %lu MarketPerformerModel objects for %@",
          (unsigned long)standardizedPerformers.count, listType);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedPerformers, nil);
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

- (void)notifyDelegatesOfBatchQuotesUpdate:(NSDictionary *)quotes forSymbols:(NSArray<NSString *> *)symbols {
    dispatch_async(self.delegateQueue, ^{
        for (id<DataManagerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(dataManager:didUpdateBatchQuotes:forSymbols:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate dataManager:self didUpdateBatchQuotes:quotes forSymbols:symbols];
                });
            }
        }
    });
}

- (void)notifyDelegatesOfHistoricalDataUpdate:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol {
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

#pragma mark - Utility Methods (moved from old version)

- (NSDate *)dateBySubtractingBarsFromEndDate:(NSDate *)endDate
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count {
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
        case BarTimeframeDaily:
            components.day = -count;
            break;
        case BarTimeframeWeekly:
            components.weekOfYear = -count;
            break;
        case BarTimeframeMonthly:
            components.month = -count;
            break;
    }
    
    return [calendar dateByAddingComponents:components toDate:endDate options:0];
}

#pragma mark - Connection Status

- (BOOL)isConnected {
    return [self.downloadManager isDataSourceConnected:DataSourceTypeSchwab] ||
           [self.downloadManager isDataSourceConnected:DataSourceTypeIBKR] ||
           [self.downloadManager isDataSourceConnected:DataSourceTypeWebull] ||
           [self.downloadManager isDataSourceConnected:DataSourceTypeYahoo];
}

- (NSArray<NSString *> *)availableDataSources {
    NSMutableArray *sources = [NSMutableArray array];
    
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        [sources addObject:@"Schwab"];
    }
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeIBKR]) {
        [sources addObject:@"IBKR"];
    }
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeWebull]) {
        [sources addObject:@"Webull"];
    }
    if ([self.downloadManager isDataSourceConnected:DataSourceTypeYahoo]) {
        [sources addObject:@"Yahoo"];
    }
    
    return sources;
}

- (NSString *)activeDataSource {
    DataSourceType current = [self.downloadManager currentDataSource];
    return DataSourceTypeToString(current);
}


- (void)searchSymbolsWithQuery:(NSString *)query
                    dataSource:(DataSourceType)dataSource
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<NSDictionary *> *results, NSError *error))completion {
    
    if (!query || query.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    
    NSLog(@"🌐 DownloadManager: Executing symbol search for '%@' via %@", query, DataSourceTypeToString(dataSource));
    
    // Get appropriate data source
    id<DataSource> dataSourceImpl = [self dataSourceForType:dataSource];

    if (!dataSourceImpl) {
        // Try fallback to next available source
        DataSourceType fallbackSource = [self getNextAvailableDataSource:dataSource];
        if (fallbackSource != DataSourceTypeUnknown) {
            NSLog(@"🔄 DownloadManager: Falling back to %@", DataSourceTypeToString(fallbackSource));
            [self searchSymbolsWithQuery:query dataSource:fallbackSource limit:limit completion:completion];
            return;
        }
        
        NSError *error = [NSError errorWithDomain:@"DownloadManager" code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"No available data sources for symbol search"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Check if data source supports symbol search
    if (![dataSourceImpl respondsToSelector:@selector(searchSymbolsWithQuery:limit:completion:)]) {
        NSLog(@"⚠️ DownloadManager: %@ does not support symbol search", DataSourceTypeToString(dataSource));
        
        // Try next available source
        DataSourceType fallbackSource = [self getNextAvailableDataSource:dataSource];
        if (fallbackSource != DataSourceTypeUnknown) {
            [self searchSymbolsWithQuery:query dataSource:fallbackSource limit:limit completion:completion];
            return;
        }
        
        NSError *error = [NSError errorWithDomain:@"DownloadManager" code:501
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol search not supported by available data sources"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Execute search via selected data source
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    
    [dataSourceImpl searchSymbolsWithQuery:query
                                      limit:limit
                                 completion:^(NSArray<NSDictionary *> *results, NSError *error) {
        
        NSTimeInterval duration = [[NSDate date] timeIntervalSince1970] - startTime;
        
        if (error) {
            NSLog(@"❌ DownloadManager: Symbol search failed for %@ (%.2fs): %@",
                  DataSourceTypeToString(dataSource), duration, error.localizedDescription);
            
            // Track failure and try fallback
            [self recordFailureForDataSource:dataSource];
            
            DataSourceType fallbackSource = [self getNextAvailableDataSource:dataSource];
            if (fallbackSource != DataSourceTypeUnknown) {
                NSLog(@"🔄 DownloadManager: Trying fallback to %@", DataSourceTypeToString(fallbackSource));
                [self searchSymbolsWithQuery:query dataSource:fallbackSource limit:limit completion:completion];
                return;
            }
            
            // No more fallbacks available
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
            return;
        }
        
        NSLog(@"✅ DownloadManager: Symbol search completed for %@ (%.2fs): %ld results",
              DataSourceTypeToString(dataSource), duration, (long)results.count);
        
        // Reset failure count on success
        [self recordSuccessForDataSource:dataSource];
        
        // Return results
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(results ?: @[], nil);
            });
        }
    }];
}

// Helper methods for DownloadManager:

- (DataSourceType)getNextAvailableDataSource:(DataSourceType)currentSource {
    // Get list of data sources sorted by priority
    NSArray<NSNumber *> *availableSources = [self.dataSources.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        NSInteger priority1 = [self priorityForDataSource:(DataSourceType)obj1.integerValue];
        NSInteger priority2 = [self priorityForDataSource:(DataSourceType)obj2.integerValue];
        return [@(priority1) compare:@(priority2)];
    }];
    
    // Find next available source after current one
    BOOL foundCurrent = NO;
    for (NSNumber *sourceTypeNum in availableSources) {
        DataSourceType sourceType = (DataSourceType)sourceTypeNum.integerValue;
        
        if (foundCurrent) {
            if ([self isDataSourceConnected:sourceType]) {
                return sourceType;
            }
        }
        
        if (sourceType == currentSource) {
            foundCurrent = YES;
        }
    }
    
    return DataSourceTypeUnknown;
}

- (void)recordFailureForDataSource:(DataSourceType)dataSource {
    // Implementation for failure tracking
    // This helps with smart fallback decisions
}

- (void)recordSuccessForDataSource:(DataSourceType)dataSource {
    // Implementation for success tracking
    // Reset failure counters on success
}


@end
