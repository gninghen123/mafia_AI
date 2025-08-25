//
//  DownloadManager.m
//  TradingApp
//

#import "DownloadManager.h"
#import "WebullDataSource.h"
#import "ClaudeDataSource.h"
#import "MarketData.h"
#import "OtherDataSource.h"
#import "SchwabDataSource.h"
#import "IBKRDataSource.h"

@interface DataSourceInfo : NSObject
@property (nonatomic, strong) id<DataSource> dataSource;
@property (nonatomic, assign) DataSourceType type;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, assign) NSInteger failureCount;
@property (nonatomic, strong) NSDate *lastFailureTime;
@end

@implementation DataSourceInfo

@end


@interface DownloadManager ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, DataSourceInfo *> *dataSources;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *activeRequests;
@property (nonatomic, strong) NSOperationQueue *requestQueue;
@property (nonatomic, assign) BOOL fallbackEnabled;
@property (nonatomic, assign) NSInteger maxRetries;
@property (nonatomic, assign) NSTimeInterval requestTimeout;
@property (nonatomic, strong) dispatch_queue_t dataSourceQueue;
@property (nonatomic, assign) DataSourceType currentDataSource;
@end

@implementation DownloadManager

+ (instancetype)sharedManager {
    static DownloadManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dataSources = [NSMutableDictionary dictionary];
        _activeRequests = [NSMutableDictionary dictionary];
        _fallbackEnabled = YES;
        _maxRetries = 3;
        _requestTimeout = 30.0;
        _dataSourceQueue = dispatch_queue_create("com.tradingapp.downloadmanager.datasources", DISPATCH_QUEUE_SERIAL);
        
        _requestQueue = [[NSOperationQueue alloc] init];
        _requestQueue.maxConcurrentOperationCount = 10;
        
        // Data sources are now registered by AppDelegate
    }
    return self;
}

#pragma mark - Data Source Management

- (void)registerDataSource:(id<DataSource>)dataSource
                  withType:(DataSourceType)type
                  priority:(NSInteger)priority {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = [[DataSourceInfo alloc] init];
        info.dataSource = dataSource;
        info.type = type;
        info.priority = priority;
        info.failureCount = 0;
        
        self.dataSources[@(type)] = info;
        
        NSLog(@"Registered data source: %@ with priority: %ld", dataSource.sourceName, (long)priority);
    });
}

- (void)unregisterDataSource:(DataSourceType)type {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info && info.dataSource.isConnected) {
            [info.dataSource disconnect];
        }
        [self.dataSources removeObjectForKey:@(type)];
    });
}

#pragma mark - Request Execution Methods

// Metodo principale - il DownloadManager decide la priorità
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    return [self executeRequest:requestType
                     parameters:parameters
                preferredSource:-1  // -1 indica nessuna preferenza
                     completion:completion];
}

// Metodo avanzato - per casi speciali con source forzato
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
             preferredSource:(DataSourceType)preferredSource
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    self.activeRequests[requestID] = parameters;
    
    NSLog(@"DownloadManager: executeRequest type:%ld preferredSource:%ld requestID:%@",
          (long)requestType, (long)preferredSource, requestID);
    
    // Get sorted data sources by priority
    NSArray<DataSourceInfo *> *sortedSources = [self sortedDataSourcesForRequestType:requestType
                                                                      preferredSource:preferredSource];
    
    if (sortedSources.count == 0) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithFormat:@"No data sources available for request type %ld",
                                                    (long)requestType]}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, -1, error);
            });
        }
        return requestID;
    }
    
    // Try each data source in order
    [self executeRequestWithSources:sortedSources
                        requestType:requestType
                         parameters:parameters
                        sourceIndex:0
                          requestID:requestID
                         completion:completion];
    
    return requestID;
}

  

- (void)executeRequestWithSources:(NSArray<DataSourceInfo *> *)sources
                      requestType:(DataRequestType)requestType
                       parameters:(NSDictionary *)parameters
                      sourceIndex:(NSInteger)index
                        requestID:(NSString *)requestID
                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    // Check if request was cancelled
    if (!self.activeRequests[requestID]) {
        return;
    }
    
    // Check if we've exhausted all sources
    if (index >= sources.count) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:500
                                         userInfo:@{NSLocalizedDescriptionKey: @"All data sources failed"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, -1, error);
            });
        }
        return;
    }
    
    DataSourceInfo *sourceInfo = sources[index];
    id<DataSource> dataSource = sourceInfo.dataSource;
    
    // Check if source is connected
    if (!dataSource.isConnected) {
        NSLog(@"Data source %@ not connected, trying next source", dataSource.sourceName);
        [self executeRequestWithSources:sources
                            requestType:requestType
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
        return;
    }
    
    // Execute request based on type
    switch (requestType) {
        case DataRequestTypeTopGainers:
        case DataRequestTypeTopLosers:
        case DataRequestTypeETFList:
        case DataRequestTypeMarketList:
            [self executeMarketListRequest:parameters
                            withDataSource:dataSource
                                sourceInfo:sourceInfo
                                   sources:sources
                               sourceIndex:index
                                 requestID:requestID
                                completion:completion];
            break;
            
        case DataRequestTypeQuote:
            [self executeQuoteRequest:parameters
                       withDataSource:dataSource
                           sourceInfo:sourceInfo
                              sources:sources
                          sourceIndex:index
                            requestID:requestID
                           completion:completion];
            break;
            
        case DataRequestTypeHistoricalBars:
            [self executeHistoricalRequest:parameters
                            withDataSource:dataSource
                                sourceInfo:sourceInfo
                                   sources:sources
                               sourceIndex:index
                                 requestID:requestID
                                completion:completion];
            break;
            
        case DataRequestTypeOrderBook:
            [self executeOrderBookRequest:parameters
                           withDataSource:dataSource
                               sourceInfo:sourceInfo
                                  sources:sources
                              sourceIndex:index
                                requestID:requestID
                               completion:completion];
            break;
            
        case DataRequestTypePositions:
            [self executePositionsRequest:parameters
                           withDataSource:dataSource
                               sourceInfo:sourceInfo
                                  sources:sources
                              sourceIndex:index
                                requestID:requestID
                               completion:completion];
            break;
            
        case DataRequestTypeOrders:
            [self executeOrdersRequest:parameters
                        withDataSource:dataSource
                            sourceInfo:sourceInfo
                               sources:sources
                           sourceIndex:index
                             requestID:requestID
                            completion:completion];
            break;
        case DataRequestTypeBatchQuotes:
                   [self executeBatchQuoteRequest:parameters
                                   withDataSource:dataSource
                                       sourceInfo:sourceInfo
                                          sources:sources
                                      sourceIndex:index
                                        requestID:requestID
                                       completion:completion];
                   break;
        case DataRequestTypeNewsSummary:
        case DataRequestTypeTextSummary:
        case DataRequestTypeAIAnalysis:
            [self executeAIRequest:parameters
                    withDataSource:dataSource
                        sourceInfo:sourceInfo
                           sources:sources
                       sourceIndex:index
                         requestID:requestID
                        completion:completion];
            break;
        case DataRequestTypeZacksCharts:
            [self executeZacksChartRequest:parameters
                            withDataSource:dataSource
                                sourceInfo:sourceInfo
                                   sources:sources
                               sourceIndex:index
                                 requestID:requestID
                                completion:completion];
            break;
        default:
        case DataRequestTypeAccountInfo:
            [self executeAccountInfoRequest:parameters
                              withDataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:index
                                  requestID:requestID
                                  completion:completion];
           break;
            NSLog(@"Unsupported request type: %ld", (long)requestType);
            [self executeRequestWithSources:sources
                                requestType:requestType
                                 parameters:parameters
                                sourceIndex:index + 1
                                  requestID:requestID
                                 completion:completion];
            break;
    }
}

#pragma mark - Specific Request Type Handlers

- (void)executeBatchQuoteRequest:(NSDictionary *)parameters
                  withDataSource:(id<DataSource>)dataSource
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)index
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSArray<NSString *> *symbols = parameters[@"symbols"];
    
    NSLog(@"DownloadManager: Executing batch quote request for %lu symbols using %@ (index %ld of %lu)",
          (unsigned long)symbols.count, dataSource.sourceName, (long)index, (unsigned long)sources.count);
    
    // Check if data source supports batch quotes
    if ([dataSource respondsToSelector:@selector(fetchQuotesForSymbols:completion:)]) {
        [dataSource fetchQuotesForSymbols:symbols completion:^(NSDictionary *quotes, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                NSLog(@"DownloadManager: Batch quote request failed with %@, trying next source", dataSource.sourceName);
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypeBatchQuotes
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                NSLog(@"DownloadManager: Batch quote request succeeded with %@ - got %lu quotes",
                      dataSource.sourceName, (unsigned long)quotes.count);
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(quotes, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else {
        // Fallback: data source doesn't support batch, use individual calls
        NSLog(@"DownloadManager: %@ doesn't support batch quotes, falling back to individual calls", dataSource.sourceName);
        
        NSMutableDictionary *batchResult = [NSMutableDictionary dictionary];
        __block NSInteger completedCount = 0;
        __block NSError *lastError = nil;
        
        for (NSString *symbol in symbols) {
            if ([dataSource respondsToSelector:@selector(fetchQuoteForSymbol:completion:)]) {
                [dataSource fetchQuoteForSymbol:symbol completion:^(id quote, NSError *error) {
                    @synchronized(batchResult) {
                        if (quote) {
                            // Convert quote to dictionary based on type
                            if ([quote isKindOfClass:[NSDictionary class]]) {
                                batchResult[symbol] = quote;
                            } else if ([quote isKindOfClass:[MarketData class]]) {
                                // MarketData object - call toDictionary
                                if ([quote respondsToSelector:@selector(toDictionary)]) {
                                    batchResult[symbol] = [quote toDictionary];
                                } else {
                                    NSLog(@"Warning: MarketData object doesn't have toDictionary method for %@", symbol);
                                }
                            } else {
                                // Other types - try to convert or log warning
                                NSLog(@"Warning: Unknown quote format (%@) for %@", [quote class], symbol);
                                // Try to store as-is if it's a basic type
                                if ([quote isKindOfClass:[NSNumber class]] || [quote isKindOfClass:[NSString class]]) {
                                    batchResult[symbol] = @{@"last": quote, @"symbol": symbol};
                                }
                            }
                        }
                        if (error) {
                            lastError = error;
                        }
                        
                        completedCount++;
                        if (completedCount == symbols.count) {
                            [self.activeRequests removeObjectForKey:requestID];
                            if (completion) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    NSLog(@"DownloadManager: Fallback batch completed - %lu successful of %lu total",
                                          (unsigned long)batchResult.count, (unsigned long)symbols.count);
                                    completion([batchResult copy], sourceInfo.type, batchResult.count > 0 ? nil : lastError);
                                });
                            }
                        }
                    }
                }];
            }
        }
    }
}

- (void)executeMarketListRequest:(NSDictionary *)parameters
                  withDataSource:(id<DataSource>)dataSource
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)index
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    DataRequestType requestType = [parameters[@"requestType"] integerValue];
    
    if ([dataSource respondsToSelector:@selector(fetchMarketListForType:parameters:completion:)]) {
        [dataSource fetchMarketListForType:requestType
                                parameters:parameters
                                completion:^(NSArray *results, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:requestType
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(results, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else {
        [self executeRequestWithSources:sources
                            requestType:requestType
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}

- (void)executeQuoteRequest:(NSDictionary *)parameters
             withDataSource:(id<DataSource>)dataSource
                 sourceInfo:(DataSourceInfo *)sourceInfo
                    sources:(NSArray<DataSourceInfo *> *)sources
                sourceIndex:(NSInteger)index
                  requestID:(NSString *)requestID
                 completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    
    NSLog(@"DownloadManager: Executing quote request for %@ using %@ (index %ld of %lu)",
          symbol, dataSource.sourceName, (long)index, (unsigned long)sources.count);
    
    if ([dataSource respondsToSelector:@selector(fetchQuoteForSymbol:completion:)]) {
        [dataSource fetchQuoteForSymbol:symbol completion:^(id quote, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                NSLog(@"DownloadManager: Quote request failed with %@, trying next source", dataSource.sourceName);
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypeQuote
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                NSLog(@"DownloadManager: Quote request succeeded with %@", dataSource.sourceName);
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(quote, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else {
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeQuote
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}

- (void)executeHistoricalRequest:(NSDictionary *)parameters
                  withDataSource:(id<DataSource>)dataSource
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)index
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    BarTimeframe timeframe = [parameters[@"timeframe"] integerValue];
    NSDate *startDate = parameters[@"startDate"];
    NSDate *endDate = parameters[@"endDate"];
    NSInteger needexth = [parameters[@"needExtendedHours"] integerValue];
  //todo20ago
    if ([dataSource respondsToSelector:@selector(fetchHistoricalDataForSymbol:timeframe:startDate:endDate:needExtendedHours:completion:)]) {
        [dataSource fetchHistoricalDataForSymbol:symbol
                                       timeframe:timeframe
                                       startDate:startDate
                                         endDate:endDate
                               needExtendedHours:needexth
                                      completion:^(NSArray *bars, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypeHistoricalBars
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(bars, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else {
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeHistoricalBars
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}

- (void)executeOrderBookRequest:(NSDictionary *)parameters
                 withDataSource:(id<DataSource>)dataSource
                     sourceInfo:(DataSourceInfo *)sourceInfo
                        sources:(NSArray<DataSourceInfo *> *)sources
                    sourceIndex:(NSInteger)index
                      requestID:(NSString *)requestID
                     completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    NSInteger depth = [parameters[@"depth"] integerValue];
    
    if ([dataSource respondsToSelector:@selector(fetchOrderBookForSymbol:depth:completion:)]) {
        [dataSource fetchOrderBookForSymbol:symbol
                                      depth:depth
                                 completion:^(id orderBook, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypeOrderBook
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(orderBook, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else {
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeOrderBook
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}

- (void)executePositionsRequest:(NSDictionary *)parameters
                 withDataSource:(id<DataSource>)dataSource
                     sourceInfo:(DataSourceInfo *)sourceInfo
                        sources:(NSArray<DataSourceInfo *> *)sources
                    sourceIndex:(NSInteger)index
                      requestID:(NSString *)requestID
                     completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    // ✅ NUOVO: Controllare se abbiamo un accountId nei parametri per IBKR
    NSString *accountId = parameters[@"accountId"];
    
    if (accountId && [dataSource isKindOfClass:NSClassFromString(@"IBKRDataSource")]) {
        // ✅ IBKR con account specifico - usa getPositions:completion:
        NSLog(@"DownloadManager: Using IBKR-specific positions request for account %@", accountId);
        
        [dataSource performSelector:@selector(getPositions:completion:)
                          withObject:accountId
                          withObject:^(NSArray *positions, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypePositions
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(positions, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else if ([dataSource respondsToSelector:@selector(fetchPositionsWithCompletion:)]) {
        // ✅ Usa il metodo generico del protocollo DataSource
        [dataSource fetchPositionsWithCompletion:^(NSArray *positions, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypePositions
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(positions, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else {
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypePositions
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}

- (void)executeOrdersRequest:(NSDictionary *)parameters
              withDataSource:(id<DataSource>)dataSource
                  sourceInfo:(DataSourceInfo *)sourceInfo
                     sources:(NSArray<DataSourceInfo *> *)sources
                 sourceIndex:(NSInteger)index
                   requestID:(NSString *)requestID
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    // ✅ NUOVO: Controllare se abbiamo un accountId nei parametri per IBKR
    NSString *accountId = parameters[@"accountId"];
    
    if (accountId && [dataSource isKindOfClass:NSClassFromString(@"IBKRDataSource")]) {
        // ✅ IBKR con account specifico - usa getOrders:completion:
        NSLog(@"DownloadManager: Using IBKR-specific orders request for account %@", accountId);
        
        [dataSource performSelector:@selector(getOrders:completion:)
                          withObject:accountId
                          withObject:^(NSArray *orders, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypeOrders
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(orders, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else if ([dataSource respondsToSelector:@selector(fetchOrdersWithCompletion:)]) {
        // ✅ Usa il metodo generico del protocollo DataSource
        [dataSource fetchOrdersWithCompletion:^(NSArray *orders, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return;
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypeOrders
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(orders, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else {
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeOrders
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}

#pragma mark - Helper Methods

- (NSArray<DataSourceInfo *> *)sortedDataSourcesForRequestType:(DataRequestType)requestType
                                                preferredSource:(DataSourceType)preferredSource {
    __block NSMutableArray<DataSourceInfo *> *availableSources = [NSMutableArray array];
    
    dispatch_sync(self.dataSourceQueue, ^{
        // First, check if preferred source is available and supports the request type
        if (preferredSource >= 0) {
            DataSourceInfo *preferredInfo = self.dataSources[@(preferredSource)];
            if (preferredInfo && [self dataSource:preferredInfo.dataSource supportsRequestType:requestType]) {
                [availableSources addObject:preferredInfo];
            }
        }
        
        // Then add other sources sorted by priority
        NSArray *sortedKeys = [self.dataSources.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSNumber *key1, NSNumber *key2) {
            DataSourceInfo *info1 = self.dataSources[key1];
            DataSourceInfo *info2 = self.dataSources[key2];
            
            // Sort by priority (lower number = higher priority)
            if (info1.priority < info2.priority) return NSOrderedAscending;
            if (info1.priority > info2.priority) return NSOrderedDescending;
            
            // If same priority, sort by failure count
            if (info1.failureCount < info2.failureCount) return NSOrderedAscending;
            if (info1.failureCount > info2.failureCount) return NSOrderedDescending;
            
            return NSOrderedSame;
        }];
        
        for (NSNumber *key in sortedKeys) {
            DataSourceInfo *info = self.dataSources[key];
            if ((preferredSource < 0 || info.type != preferredSource) &&
                [self dataSource:info.dataSource supportsRequestType:requestType]) {
                [availableSources addObject:info];
            }
        }
    });
    
    return availableSources;
}

- (BOOL)dataSource:(id<DataSource>)dataSource supportsRequestType:(DataRequestType)requestType {
    DataSourceCapabilities capabilities = dataSource.capabilities;
    DataSourceType sourceType = dataSource.sourceType;
    
    // Market list types - handled by Webull and OtherDataSource
    if (requestType == DataRequestTypeMarketList ||
        requestType == DataRequestTypeTopGainers ||
        requestType == DataRequestTypeTopLosers ||
        requestType == DataRequestTypeETFList) {
        return sourceType == DataSourceTypeWebull || sourceType == DataSourceTypeOther;
    }
    
    // NEW: OtherDataSource specific request types
    if (requestType >= DataRequestType52WeekHigh && requestType <= DataRequestTypePMMovers) {
        // Market overview data - only OtherDataSource
        return sourceType == DataSourceTypeOther;
    }
    
    if (requestType >= DataRequestTypeCompanyNews && requestType <= DataRequestTypeAnalystMomentum) {
        // Company specific data - only OtherDataSource
        return sourceType == DataSourceTypeOther;
    }
    
    if (requestType >= DataRequestTypeFinvizStatements && requestType <= DataRequestTypeOpenInsider) {
        // External data sources - only OtherDataSource
        return sourceType == DataSourceTypeOther;
    }
    if (sourceType == DataSourceTypeIBKR) {
        switch (requestType) {
            case DataRequestTypeQuote:
            case DataRequestTypeBatchQuotes:
                return (capabilities & DataSourceCapabilityQuotes) != 0;
                
            case DataRequestTypeHistoricalBars:
                return (capabilities & DataSourceCapabilityHistorical) != 0;
                
            case DataRequestTypeOrderBook:
                return (capabilities & DataSourceCapabilityOrderBook) != 0;
                
            case DataRequestTypePositions:
            case DataRequestTypeOrders:
            case DataRequestTypeAccountInfo:
                return (capabilities & DataSourceCapabilityAccounts) != 0;
                
            case DataRequestTypeOptionChain:
                return (capabilities & DataSourceCapabilityOptions) != 0;
                
            case DataRequestTypeTimeSales:
                return (capabilities & DataSourceCapabilityTimeSales) != 0;
                
                // IBKR doesn't support these request types
            case DataRequestTypeNews:
            case DataRequestTypeFundamentals:
            case DataRequestTypeNewsSummary:
            case DataRequestTypeTextSummary:
            case DataRequestTypeAIAnalysis:
                return NO;
                
            default:
                return NO;
        }
    }
    // Existing request types with capability checks
    switch (requestType) {
        case DataRequestTypeQuote:
            return (capabilities & DataSourceCapabilityQuotes) != 0;
        case DataRequestTypeHistoricalBars:
            return (capabilities & DataSourceCapabilityHistorical) != 0;
        case DataRequestTypeOrderBook:
            return (capabilities & DataSourceCapabilityOrderBook) != 0;
        case DataRequestTypeTimeSales:
            return (capabilities & DataSourceCapabilityTimeSales) != 0;
        case DataRequestTypeOptionChain:
            return (capabilities & DataSourceCapabilityOptions) != 0;
        case DataRequestTypeNews:
            return (capabilities & DataSourceCapabilityNews) != 0;
        case DataRequestTypeFundamentals:
            return (capabilities & DataSourceCapabilityFundamentals) != 0;
        case DataRequestTypeBatchQuotes:
            return (capabilities & DataSourceCapabilityQuotes) != 0;
        case DataRequestTypePositions:
        case DataRequestTypeOrders:
        case DataRequestTypeAccountInfo:
            return (capabilities & DataSourceCapabilityAccounts) != 0;
        case DataRequestTypeNewsSummary:
        case DataRequestTypeTextSummary:
        case DataRequestTypeAIAnalysis:
            return (capabilities & DataSourceCapabilityAI) != 0;
        default:
            return NO;
    }
}

#pragma mark - Connection Management

- (void)connectDataSource:(DataSourceType)type completion:(void (^)(BOOL success, NSError *error))completion {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info) {
            [info.dataSource connectWithCompletion:completion];
        } else {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:404
                                             userInfo:@{NSLocalizedDescriptionKey: @"Data source not found"}];
            if (completion) completion(NO, error);
        }
    });
}

- (void)disconnectDataSource:(DataSourceType)type {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info) {
            [info.dataSource disconnect];
        }
    });
}

- (void)reconnectAllDataSources {
    dispatch_async(self.dataSourceQueue, ^{
        for (DataSourceInfo *info in self.dataSources.allValues) {
            if (info.dataSource.isConnected) {
                [info.dataSource disconnect];
                [info.dataSource connectWithCompletion:nil];
            }
        }
    });
}

#pragma mark - Status and Monitoring

- (BOOL)isDataSourceConnected:(DataSourceType)type {
    __block BOOL connected = NO;
    dispatch_sync(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        connected = info ? info.dataSource.isConnected : NO;
    });
    return connected;
}

- (DataSourceCapabilities)capabilitiesForDataSource:(DataSourceType)type {
    __block DataSourceCapabilities capabilities = 0;
    dispatch_sync(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        capabilities = info ? info.dataSource.capabilities : 0;
    });
    return capabilities;
}

- (NSDictionary *)statisticsForDataSource:(DataSourceType)type {
    __block NSDictionary *stats = nil;
    dispatch_sync(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info) {
            stats = @{
                @"sourceName": info.dataSource.sourceName,
                @"isConnected": @(info.dataSource.isConnected),
                @"priority": @(info.priority),
                @"failureCount": @(info.failureCount),
                @"lastFailureTime": info.lastFailureTime ?: [NSNull null]
            };
        }
    });
    return stats;
}

#pragma mark - Request Management

- (void)cancelRequest:(NSString *)requestID {
    if (requestID) {
        [self.activeRequests removeObjectForKey:requestID];
    }
}

- (void)cancelAllRequests {
    [self.activeRequests removeAllObjects];
}

#pragma mark - Convenience Methods

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    [self executeRequest:DataRequestTypeQuote
              parameters:@{@"symbol": symbol}
              completion:^(id result, DataSourceType usedSource, NSError *error) {
                  if (completion) completion(result, error);
              }];
}

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    NSDictionary *params = @{@"symbols": symbols};
    
    [self executeRequest:DataRequestTypeBatchQuotes
              parameters:params
              completion:^(id result, DataSourceType usedSource, NSError *error) {
                  if (completion) {
                      if ([result isKindOfClass:[NSDictionary class]]) {
                          completion((NSDictionary *)result, error);
                      } else {
                          completion(@{}, error);
                      }
                  }
              }];
}
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                    needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    NSLog(@"📊 DownloadManager: Convenience method called for %@ with extended hours: %@",
          symbol, needExtendedHours ? @"YES" : @"NO");
    
    // Valida parametri
    if (!symbol || !startDate || !endDate) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Crea parameters dictionary
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"startDate": startDate,
        @"endDate": endDate,
        @"needExtendedHours": @(needExtendedHours)  // ✅ INCLUDI IL PARAMETRO
    };
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    self.activeRequests[requestID] = parameters;
    
    NSLog(@"📊 DownloadManager: Starting date range historical request %@ for symbol %@",
          requestID, symbol);
    
    // Usa il metodo esistente per ottenere sources
    NSArray<DataSourceInfo *> *sortedSources = [self sortedDataSourcesForRequestType:DataRequestTypeHistoricalBars
                                                                      preferredSource:-1];
    
    if (sortedSources.count == 0) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"No data sources available for historical data"}];
        NSLog(@"❌ DownloadManager: No sources available for historical data");
        [self.activeRequests removeObjectForKey:requestID];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    NSLog(@"📊 DownloadManager: Found %lu data sources for historical request", (unsigned long)sortedSources.count);
    
    // Usa il metodo helper esistente executeHistoricalWithSources
    [self executeHistoricalWithSources:sortedSources
                            parameters:parameters
                           sourceIndex:0
                             requestID:requestID
                            completion:^(id result, DataSourceType usedSource, NSError *error) {
        
        // Rimuovi la richiesta dalla lista attiva
        [self.activeRequests removeObjectForKey:requestID];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // Converti il risultato se necessario
                NSArray *bars = nil;
                if ([result isKindOfClass:[NSArray class]]) {
                    bars = (NSArray *)result;
                } else if ([result isKindOfClass:[NSDictionary class]]) {
                    // Se è un dictionary (dati grezzi), potrebbe essere necessario convertirlo
                    NSLog(@"⚠️ DownloadManager: Received dictionary data for %@, conversion may be needed", symbol);
                    // Per ora passalo così com'è - l'adapter a livello superiore lo gestirà
                    bars = @[result];  // Wrappa in array per mantenere compatibilità
                }
                
                completion(bars, error);
            });
        }
    }];
}
- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(id orderBook, NSError *error))completion {
    NSDictionary *params = @{
        @"symbol": symbol,
        @"depth": @(depth)
    };
    
    [self executeRequest:DataRequestTypeOrderBook
              parameters:params
              completion:^(id result, DataSourceType usedSource, NSError *error) {
                  if (completion) completion(result, error);
              }];
}

- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion {
    [self executeRequest:DataRequestTypePositions
              parameters:@{}
              completion:^(id result, DataSourceType usedSource, NSError *error) {
                  if (completion) completion(result, error);
              }];
}

- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion {
    [self executeRequest:DataRequestTypeOrders
              parameters:@{}
              completion:^(id result, DataSourceType usedSource, NSError *error) {
                  if (completion) completion(result, error);
              }];
}

#pragma mark - AI Request Support (NUOVO)

// Aggiungere questo case nel metodo executeRequestWithSources


// NUOVO: AI Request Handler
- (void)executeAIRequest:(NSDictionary *)parameters
          withDataSource:(id<DataSource>)dataSource
              sourceInfo:(DataSourceInfo *)sourceInfo
                 sources:(NSArray<DataSourceInfo *> *)sources
             sourceIndex:(NSInteger)index
               requestID:(NSString *)requestID
              completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *requestType = parameters[@"requestType"];
    NSLog(@"DownloadManager: Executing AI request '%@' using %@", requestType, dataSource.sourceName);
    
    // Ensure we have a Claude data source
    if (![dataSource isKindOfClass:[ClaudeDataSource class]]) {
        NSLog(@"DownloadManager: Data source %@ does not support AI requests", dataSource.sourceName);
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeNewsSummary
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
        return;
    }
    
    ClaudeDataSource *claudeSource = (ClaudeDataSource *)dataSource;
    
    // Handle different AI request types
    if ([requestType isEqualToString:@"newsSummary"]) {
        NSString *url = parameters[@"url"];
        NSInteger maxTokens = [parameters[@"maxTokens"] integerValue] ?: 500;
        float temperature = [parameters[@"temperature"] floatValue] ?: 0.3f;
        
        [claudeSource summarizeFromURL:url
                             maxTokens:maxTokens
                           temperature:temperature
                            completion:^(NSString * _Nullable summary, NSError * _Nullable error) {
            [self handleAIRequestCompletion:summary
                                      error:error
                                 sourceInfo:sourceInfo
                                    sources:sources
                                sourceIndex:index
                                  requestID:requestID
                                 completion:completion];
        }];
        
    } else if ([requestType isEqualToString:@"textSummary"]) {
        NSString *text = parameters[@"text"];
        NSInteger maxTokens = [parameters[@"maxTokens"] integerValue] ?: 500;
        float temperature = [parameters[@"temperature"] floatValue] ?: 0.3f;
        
        [claudeSource summarizeText:text
                          maxTokens:maxTokens
                        temperature:temperature
                         completion:^(NSString * _Nullable summary, NSError * _Nullable error) {
            [self handleAIRequestCompletion:summary
                                      error:error
                                 sourceInfo:sourceInfo
                                    sources:sources
                                sourceIndex:index
                                  requestID:requestID
                                 completion:completion];
        }];
        
    } else {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:@"Unknown AI request type: %@", requestType]}];
        [self handleAIRequestCompletion:nil
                                  error:error
                             sourceInfo:sourceInfo
                                sources:sources
                            sourceIndex:index
                              requestID:requestID
                             completion:completion];
    }
}

// NUOVO: AI Request Completion Handler
- (void)handleAIRequestCompletion:(NSString *)summary
                            error:(NSError *)error
                       sourceInfo:(DataSourceInfo *)sourceInfo
                          sources:(NSArray<DataSourceInfo *> *)sources
                      sourceIndex:(NSInteger)index
                        requestID:(NSString *)requestID
                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"DownloadManager: AI request failed with %@: %@", sourceInfo.dataSource.sourceName, error.localizedDescription);
        
        // Increment failure count
        sourceInfo.failureCount++;
        sourceInfo.lastFailureTime = [NSDate date];
        
        // Try next source if available
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeNewsSummary
                             parameters:@{} // Parameters already consumed
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    } else {
        NSLog(@"DownloadManager: AI request successful with %@", sourceInfo.dataSource.sourceName);
        
        // Reset failure count on success
        sourceInfo.failureCount = 0;
        sourceInfo.lastFailureTime = nil;
        
        // Return successful result
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(summary, sourceInfo.type, nil);
            });
        }
    }
}
#pragma mark - Count-Based Historical Requests

- (NSString *)executeHistoricalRequestWithCount:(NSDictionary *)parameters
                                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!parameters || !completion) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters"}];
        completion(nil, -1, error);  // Usa -1 invece di DataSourceTypeNone
        return nil;
    }
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    self.activeRequests[requestID] = parameters;
    
    NSLog(@"DownloadManager: Starting count-based historical request %@ for symbol %@",
          requestID, parameters[@"symbol"]);
    
    // Usa il metodo esistente per ottenere sources
    NSArray<DataSourceInfo *> *sortedSources = [self sortedDataSourcesForRequestType:DataRequestTypeHistoricalBars
                                                                      preferredSource:-1];
    
    if (sortedSources.count == 0) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"No data sources available for historical data"}];
        NSLog(@"❌ DownloadManager: No sources available for historical data");
        [self.activeRequests removeObjectForKey:requestID];
        completion(nil, -1, error);  // Usa -1 invece di DataSourceTypeNone
        return requestID;
    }
    
    NSLog(@"📊 DownloadManager: Found %lu data sources for historical request", (unsigned long)sortedSources.count);
    
    // Usa il metodo helper esistente executeRequestWithSources ma con logica count-based
    [self executeCountBasedHistoricalWithSources:sortedSources
                                      parameters:parameters
                                     sourceIndex:0
                                       requestID:requestID
                                      completion:completion];
    
    return requestID;
}
- (void)executeCountBasedHistoricalWithSources:(NSArray<DataSourceInfo *> *)sources
                                   parameters:(NSDictionary *)parameters
                                  sourceIndex:(NSUInteger)sourceIndex
                                    requestID:(NSString *)requestID
                                   completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (sourceIndex >= sources.count) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"All data sources failed"}];
        NSLog(@"❌ DownloadManager: All sources exhausted for count-based historical request");
        [self.activeRequests removeObjectForKey:requestID];
        completion(nil, -1, error);
        return;
    }
    
    DataSourceInfo *sourceInfo = sources[sourceIndex];
    id<DataSource> dataSource = sourceInfo.dataSource;
    
    // Estrai parametri
    NSString *symbol = parameters[@"symbol"];
    NSNumber *timeframeNum = parameters[@"timeframe"];
    NSNumber *countNum = parameters[@"count"];
    NSNumber *needExtendedHoursNum = parameters[@"needExtendedHours"]; // ✅ NUOVO PARAMETRO
    
    BarTimeframe timeframe = timeframeNum.integerValue;
    NSInteger count = countNum.integerValue;
    BOOL needExtendedHours = needExtendedHoursNum.boolValue; // ✅ ESTRAZIONE PARAMETRO
    
    NSLog(@"📊 DownloadManager: Trying count-based request with %@ (source %lu/%lu) - Symbol: %@, Count: %ld, Extended: %@",
          dataSource.sourceName, (unsigned long)(sourceIndex + 1), (unsigned long)sources.count,
          symbol, (long)count, needExtendedHours ? @"YES" : @"NO");
    
    // ✅ AGGIORNATO: Controlla se il datasource supporta il nuovo metodo con extended hours
    if ([dataSource isKindOfClass:[SchwabDataSource class]]) {
        SchwabDataSource *schwabSource = (SchwabDataSource *)dataSource;
        
        // Usa il metodo count-based con extended hours
        [schwabSource fetchHistoricalDataForSymbolWithCount:symbol
                                                  timeframe:timeframe
                                                      count:count
                                      needExtendedHoursData:needExtendedHours
                                           needPreviousClose:YES
                                                  completion:^(NSArray *bars, NSError *error) {
            [self handleCountBasedHistoricalResponse:bars
                                                error:error
                                           dataSource:dataSource
                                           sourceInfo:sourceInfo
                                              sources:sources
                                          sourceIndex:sourceIndex
                                            requestID:requestID
                                           completion:completion];
        }];
        
    } else if ([dataSource respondsToSelector:@selector(fetchHistoricalDataForSymbol:timeframe:startDate:endDate:needExtendedHours:completion:)]) {
        // ✅ AGGIORNATO: Fallback per altri datasource che supportano extended hours
        NSLog(@"📊 DownloadManager: Using date-based method with extended hours for %@", dataSource.sourceName);
        
        // Calcola date range dal count (approssimativo)
        NSDate *endDate = [NSDate date];
        NSTimeInterval secondsPerBar = [self secondsPerBarForTimeframe:timeframe];
        NSTimeInterval totalSeconds = count * secondsPerBar;
        
        // Aggiungi buffer per ore non di trading
        if (timeframe < BarTimeframe1Day) {
            totalSeconds *= 1.5;
        }
        
        NSDate *startDate = [endDate dateByAddingTimeInterval:-totalSeconds];
        
        // ✅ USA IL METODO CON EXTENDED HOURS
        [dataSource fetchHistoricalDataForSymbol:symbol
                                        timeframe:timeframe
                                        startDate:startDate
                                          endDate:endDate
                                 needExtendedHours:needExtendedHours  // ✅ PASSA IL PARAMETRO
                                       completion:^(NSArray *bars, NSError *error) {
            [self handleCountBasedHistoricalResponse:bars
                                                error:error
                                           dataSource:dataSource
                                           sourceInfo:sourceInfo
                                              sources:sources
                                          sourceIndex:sourceIndex
                                            requestID:requestID
                                           completion:completion];
        }];
        
    } else {
        // DataSource non supporta dati storici o extended hours
        NSLog(@"❌ DownloadManager: Data source %@ doesn't support historical data with extended hours", dataSource.sourceName);
        
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: @"Data source doesn't support extended hours historical data"}];
        
        [self handleCountBasedHistoricalResponse:nil
                                            error:error
                                       dataSource:dataSource
                                       sourceInfo:sourceInfo
                                          sources:sources
                                      sourceIndex:sourceIndex
                                        requestID:requestID
                                       completion:completion];
    }
}



- (void)handleCountBasedResponse:(NSArray *)bars
                           error:(NSError *)error
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)index
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!self.activeRequests[requestID]) {
        NSLog(@"⚠️ DownloadManager: Request %@ was cancelled during response handling", requestID);
        return;
    }
    
    if (error && self.fallbackEnabled && index < sources.count - 1) {
        // Try next data source
        NSLog(@"❌ DownloadManager: Count-based request failed with %@ (%@), trying next source",
              sourceInfo.dataSource.sourceName, error.localizedDescription);
        
        // Usa le proprietà esistenti di DataSourceInfo
        sourceInfo.failureCount++;
        sourceInfo.lastFailureTime = [NSDate date];
        
        NSDictionary *parameters = self.activeRequests[requestID];
        
        [self executeCountBasedHistoricalWithSources:sources
                                          parameters:parameters
                                         sourceIndex:index + 1
                                           requestID:requestID
                                          completion:completion];
        return;
    }
    
    // Request completed (success or final failure)
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DownloadManager: Count-based historical request failed: %@", error.localizedDescription);
    } else {
        NSLog(@"✅ DownloadManager: Count-based request succeeded with %@, got %lu bars",
              sourceInfo.dataSource.sourceName, (unsigned long)bars.count);
    }
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(bars, sourceInfo.type, error);
        });
    }
}

#pragma mark - Date Range Historical Data Methods

- (void)executeHistoricalWithSources:(NSArray<DataSourceInfo *> *)sources
                          parameters:(NSDictionary *)parameters
                         sourceIndex:(NSInteger)index
                           requestID:(NSString *)requestID
                          completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!self.activeRequests[requestID]) {
        NSLog(@"⚠️ DownloadManager: Request %@ was cancelled", requestID);
        return;
    }
    
    if (index >= sources.count) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"No more data sources available"}];
        [self.activeRequests removeObjectForKey:requestID];
        completion(nil, -1, error);
        return;
    }
    
    DataSourceInfo *sourceInfo = sources[index];
    id<DataSource> dataSource = sourceInfo.dataSource;
    
    NSString *symbol = parameters[@"symbol"];
    BarTimeframe timeframe = [parameters[@"timeframe"] integerValue];
    NSDate *startDate = parameters[@"startDate"];
    NSDate *endDate = parameters[@"endDate"];
    BOOL needExtendedHours = [parameters[@"needExtendedHours"] boolValue];
    
    NSLog(@"📊 DownloadManager: Executing date range historical request for %@ from %@ to %@ (timeframe:%ld, extended:%@) using %@ (attempt %ld/%lu)",
          symbol, startDate, endDate, (long)timeframe, needExtendedHours ? @"YES" : @"NO",
          dataSource.sourceName, (long)(index + 1), (unsigned long)sources.count);
    
    // ✅ AGGIORNATO: Usa il metodo con needExtendedHours
    if ([dataSource respondsToSelector:@selector(fetchHistoricalDataForSymbol:timeframe:startDate:endDate:needExtendedHours:completion:)]) {
        
        [dataSource fetchHistoricalDataForSymbol:symbol
                                        timeframe:timeframe
                                        startDate:startDate
                                          endDate:endDate
                                 needExtendedHours:needExtendedHours  // ✅ PASSA IL PARAMETRO
                                       completion:^(NSArray *bars, NSError *error) {
            [self handleHistoricalResponseWithAutoComplete:bars
                                                      error:error
                                                 parameters:parameters
                                                 dataSource:dataSource
                                                 sourceInfo:sourceInfo
                                                    sources:sources
                                                sourceIndex:index
                                                  requestID:requestID
                                                 completion:completion];
        }];
        
    } else if ([dataSource isKindOfClass:[SchwabDataSource class]]) {
        // Fallback specifico per SchwabDataSource che potrebbe non aver implementato il protocol correttamente
        NSLog(@"📊 DownloadManager: Using SchwabDataSource fallback for date range request");
        
        SchwabDataSource *schwabSource = (SchwabDataSource *)dataSource;
        [schwabSource fetchPriceHistoryWithDateRange:symbol
                                           startDate:startDate
                                             endDate:endDate
                                           timeframe:timeframe
                               needExtendedHoursData:needExtendedHours
                                   needPreviousClose:YES
                                          completion:^(NSDictionary *priceHistory, NSError *error) {
            // Converti il dictionary in array per compatibilità
            NSArray *bars = nil;
            if (priceHistory && !error) {
                bars = @[priceHistory];  // Wrappa in array - l'adapter lo gestirà
            }
            
            [self handleHistoricalResponseWithAutoComplete:bars
                                                      error:error
                                                 parameters:parameters
                                                 dataSource:dataSource
                                                 sourceInfo:sourceInfo
                                                    sources:sources
                                                sourceIndex:index
                                                  requestID:requestID
                                                 completion:completion];
        }];
        
    } else {
        // DataSource non supporta historical data con extended hours
        NSLog(@"❌ DownloadManager: Data source %@ doesn't support historical data with extended hours", dataSource.sourceName);
        
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: @"Data source doesn't support extended hours historical data"}];
        
        [self handleHistoricalResponseWithAutoComplete:nil
                                                  error:error
                                             parameters:parameters
                                             dataSource:dataSource
                                             sourceInfo:sourceInfo
                                                sources:sources
                                            sourceIndex:index
                                              requestID:requestID
                                             completion:completion];
    }
}


- (void)executeHistoricalRequestWithCount:(NSDictionary *)parameters
                          withDataSource:(id<DataSource>)dataSource
                              sourceInfo:(DataSourceInfo *)sourceInfo
                                 sources:(NSArray<DataSourceInfo *> *)sources
                             sourceIndex:(NSInteger)index
                               requestID:(NSString *)requestID
                              completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!self.activeRequests[requestID]) {
        NSLog(@"⚠️ DownloadManager: Request %@ was cancelled", requestID);
        return;
    }
    
    NSString *symbol = parameters[@"symbol"];
    BarTimeframe timeframe = [parameters[@"timeframe"] integerValue];
    NSInteger count = [parameters[@"count"] integerValue];
    BOOL needExtendedHours = [parameters[@"needExtendedHours"] boolValue];
    
    NSLog(@"📈 DownloadManager: Executing count-based historical request for %@ (%ld bars, timeframe:%ld, extended:%@) using %@ (attempt %ld/%lu)",
          symbol, (long)count, (long)timeframe, needExtendedHours ? @"YES" : @"NO",
          dataSource.sourceName, (long)(index + 1), (unsigned long)sources.count);
    
    // Check if this is a SchwabDataSource that supports the new method
    if ([dataSource isKindOfClass:[SchwabDataSource class]]) {
        SchwabDataSource *schwabSource = (SchwabDataSource *)dataSource;
        
        // Use the new count-based method
        [schwabSource fetchHistoricalDataForSymbolWithCount:symbol
                                                  timeframe:timeframe
                                                      count:count
                                      needExtendedHoursData:needExtendedHours
                                           needPreviousClose:YES
                                                  completion:^(NSArray *bars, NSError *error) {
            [self handleCountBasedHistoricalResponse:bars
                                                error:error
                                           dataSource:dataSource
                                           sourceInfo:sourceInfo
                                              sources:sources
                                          sourceIndex:index
                                            requestID:requestID
                                           completion:completion];
        }];
        
    } else if ([dataSource respondsToSelector:@selector(fetchHistoricalDataForSymbol:timeframe:startDate:endDate:completion:)]) {
        // Fallback to date-based method for other data sources
        NSLog(@"📊 DownloadManager: Using fallback date-based method for %@", dataSource.sourceName);
        
        // Calculate date range from count (approximate)
        NSDate *endDate = [NSDate date];
        NSTimeInterval secondsPerBar = [self secondsPerBarForTimeframe:timeframe];
        NSTimeInterval totalSeconds = count * secondsPerBar;
        
        // Add buffer for non-trading hours
        if (timeframe < BarTimeframe1Day) {
            totalSeconds *= 1.5;
        }
        
        NSDate *startDate = [endDate dateByAddingTimeInterval:-totalSeconds];
        
        [dataSource fetchHistoricalDataForSymbol:symbol
                                        timeframe:timeframe
                                        startDate:startDate
                                          endDate:endDate
                               needExtendedHours:needExtendedHours
                                       completion:^(NSArray *bars, NSError *error) {
            [self handleCountBasedHistoricalResponse:bars
                                                error:error
                                           dataSource:dataSource
                                           sourceInfo:sourceInfo
                                              sources:sources
                                          sourceIndex:index
                                            requestID:requestID
                                           completion:completion];
        }];
        
    } else {
        // Data source doesn't support historical data
        NSLog(@"❌ DownloadManager: Data source %@ doesn't support historical data", dataSource.sourceName);
        
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: @"Data source doesn't support historical data"}];
        
        [self handleCountBasedHistoricalResponse:nil
                                            error:error
                                       dataSource:dataSource
                                       sourceInfo:sourceInfo
                                          sources:sources
                                      sourceIndex:index
                                        requestID:requestID
                                       completion:completion];
    }
}

- (void)handleCountBasedHistoricalResponse:(NSArray *)bars
                                     error:(NSError *)error
                                dataSource:(id<DataSource>)dataSource
                                sourceInfo:(DataSourceInfo *)sourceInfo
                                   sources:(NSArray<DataSourceInfo *> *)sources
                               sourceIndex:(NSInteger)index
                                 requestID:(NSString *)requestID
                                completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!self.activeRequests[requestID]) {
        NSLog(@"⚠️ DownloadManager: Request %@ was cancelled during response handling", requestID);
        return;
    }
    
    if (error && self.fallbackEnabled && index < sources.count - 1) {
        // Try next data source
        NSLog(@"❌ DownloadManager: Count-based request failed with %@ (%@), trying next source",
              dataSource.sourceName, error.localizedDescription);
        
        sourceInfo.failureCount++;
        sourceInfo.lastFailureTime = [NSDate date];
        
        NSDictionary *parameters = self.activeRequests[requestID][@"parameters"];
        
        [self executeHistoricalRequestWithCount:parameters
                                 withDataSource:sources[index + 1].dataSource
                                     sourceInfo:sources[index + 1]
                                        sources:sources
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
        return;
    }
    
    // Request completed (success or final failure)
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DownloadManager: Count-based historical request failed: %@", error.localizedDescription);
    } else {
        NSLog(@"✅ DownloadManager: Count-based request succeeded with %@, got %lu bars",
              dataSource.sourceName, (unsigned long)bars.count);
        
        // Update source statistics
    //    sourceInfo.successCount++;
    //    sourceInfo.lastSuccessTime = [NSDate date];
    }
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(bars, sourceInfo.type, error);
        });
    }
}

#pragma mark - Helper Methods

- (NSTimeInterval)secondsPerBarForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:   return 60;
        case BarTimeframe5Min:   return 300;
        case BarTimeframe15Min:  return 900;
        case BarTimeframe30Min:  return 1800;
        case BarTimeframe1Hour:  return 3600;
        case BarTimeframe4Hour:  return 14400;
        case BarTimeframe1Day:   return 86400;
        case BarTimeframe1Week:  return 604800;
        case BarTimeframe1Month: return 2592000;
        default: return 86400;
    }
}


- (void)executeZacksChartRequest:(NSDictionary *)parameters
                  withDataSource:(id<DataSource>)dataSource
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)index
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSLog(@"🔍 DownloadManager: Executing Zacks chart request with %@", dataSource.sourceName);
    
    // CORREZIONE: Il metodo si chiama fetchZacksChartForSymbol:wrapper:completion:
    if ([dataSource respondsToSelector:@selector(fetchZacksChartForSymbol:wrapper:completion:)]) {
        NSString *symbol = parameters[@"symbol"];
        NSString *wrapper = parameters[@"wrapper"];
        
        [(OtherDataSource*) dataSource fetchZacksChartForSymbol:symbol
                                     wrapper:wrapper
                                  completion:^(NSDictionary *result, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return; // Request was cancelled
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                NSLog(@"❌ DownloadManager: Zacks request failed with %@, trying next source", dataSource.sourceName);
                sourceInfo.failureCount++;
                sourceInfo.lastFailureTime = [NSDate date];
                
                // Prova il prossimo data source
                [self executeRequestWithSources:sources
                                    requestType:DataRequestTypeZacksCharts
                                     parameters:parameters
                                    sourceIndex:index + 1
                                      requestID:requestID
                                     completion:completion];
            } else {
                NSLog(@"✅ DownloadManager: Zacks request completed");
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(result, sourceInfo.type, error);
                    });
                }
            }
        }];
    } else {
        NSLog(@"❌ DownloadManager: DataSource %@ doesn't support fetchZacksChartForSymbol", dataSource.sourceName);
        // Prova il prossimo data source
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeZacksCharts
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}

#pragma mark - Current Bar Auto-Completion

- (BOOL)isDailyOrHigherTimeframe:(BarTimeframe)timeframe {
    return (timeframe >= BarTimeframe1Day);
}

- (BOOL)needsCurrentBarCompletion:(id)historicalData timeframe:(BarTimeframe)timeframe {
    
    // ✅ VERIFICA TIPO DI DATO RICEVUTO
    NSArray *historicalBars = nil;
    
    if ([historicalData isKindOfClass:[NSArray class]]) {
        // Caso normale: array di barre
        historicalBars = (NSArray *)historicalData;
    } else if ([historicalData isKindOfClass:[NSDictionary class]]) {
        // Caso particolare: dictionary con array inside
        NSDictionary *dataDict = (NSDictionary *)historicalData;
        
        // Prova chiavi comuni per array di barre
        historicalBars = dataDict[@"bars"] ?: dataDict[@"data"] ?: dataDict[@"candles"] ?: dataDict[@"results"];
        
        if (!historicalBars) {
            NSLog(@"⚠️ DownloadManager: Dictionary received but no bars array found. Keys: %@", dataDict.allKeys);
            return YES; // Assume current bar needed se non riusciamo a determinare
        }
    } else {
        NSLog(@"⚠️ DownloadManager: Unexpected data type: %@. Expected NSArray or NSDictionary", [historicalData class]);
        return YES; // Assume current bar needed per sicurezza
    }
    
    if (!historicalBars || historicalBars.count == 0) {
        NSLog(@"⚠️ DownloadManager: No historical bars found, assuming current bar needed");
        return YES;
    }
    
    // ✅ PROCEDI CON LA LOGICA NORMALE
    // Check se l'ultima barra è di oggi
    id lastBarData = historicalBars.lastObject;
    NSDate *lastBarDate = nil;
    
    if ([lastBarData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *lastBar = (NSDictionary *)lastBarData;
        
        // ✅ CERCA IL CAMPO DATA CON TUTTE LE VARIANTI POSSIBILI
        id dateValue = lastBar[@"date"] ?: lastBar[@"datetime"] ?: lastBar[@"timestamp"] ?: lastBar[@"time"];
        
        if (!dateValue) {
            NSLog(@"⚠️ DownloadManager: Last bar has no date field. Available keys: %@", lastBar.allKeys);
            return YES; // Assume current bar needed
        }
        
        // ✅ CONVERTI IL VALORE IN NSDate GESTENDO TUTTI I TIPI
        lastBarDate = [self convertToNSDate:dateValue];
        
    } else {
        NSLog(@"⚠️ DownloadManager: Last bar is not a dictionary: %@", [lastBarData class]);
        return YES; // Assume current bar needed
    }
    
    if (!lastBarDate) {
        NSLog(@"⚠️ DownloadManager: Could not convert last bar date, assuming current bar needed");
        return YES;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *lastBarComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                                      fromDate:lastBarDate];
    NSDateComponents *todayComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                                    fromDate:[NSDate date]];
    
    BOOL isToday = (lastBarComponents.year == todayComponents.year &&
                    lastBarComponents.month == todayComponents.month &&
                    lastBarComponents.day == todayComponents.day);
    
    if (isToday) {
        NSLog(@"📊 DownloadManager: Last bar (%@) is already today - no current bar needed", lastBarDate);
    } else {
        NSLog(@"📊 DownloadManager: Last bar (%@) is not today - current bar needed", lastBarDate);
    }
    
    return !isToday;  // Serve current bar se l'ultima NON è di oggi
}

- (NSDate *)convertToNSDate:(id)dateValue {
    if (!dateValue || [dateValue isKindOfClass:[NSNull class]]) {
        return nil;
    }
    
    if ([dateValue isKindOfClass:[NSDate class]]) {
        // Già un NSDate
        return (NSDate *)dateValue;
    }
    
    if ([dateValue isKindOfClass:[NSNumber class]]) {
        // Unix timestamp (seconds or milliseconds)
        NSNumber *timestamp = (NSNumber *)dateValue;
        double timeInterval = [timestamp doubleValue];
        
        // Detect se è in milliseconds (typical for modern APIs)
        if (timeInterval > 1000000000000) { // Greater than year 2001 in milliseconds
            timeInterval = timeInterval / 1000.0; // Convert to seconds
        }
        
        NSDate *convertedDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];
        NSLog(@"🔄 DownloadManager: Converted timestamp %@ to date %@", timestamp, convertedDate);
        return convertedDate;
    }
    
    if ([dateValue isKindOfClass:[NSString class]]) {
        // String date - prova vari formati
        NSString *dateString = (NSString *)dateValue;
        NSArray *dateFormats = @[
            @"yyyy-MM-dd",
            @"yyyy-MM-dd HH:mm:ss",
            @"yyyy-MM-dd'T'HH:mm:ss",
            @"yyyy-MM-dd'T'HH:mm:ss'Z'",
            @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            @"MM/dd/yyyy",
            @"MM-dd-yyyy"
        ];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        
        for (NSString *format in dateFormats) {
            formatter.dateFormat = format;
            NSDate *parsedDate = [formatter dateFromString:dateString];
            if (parsedDate) {
                NSLog(@"🔄 DownloadManager: Parsed date string '%@' with format '%@' to %@", dateString, format, parsedDate);
                return parsedDate;
            }
        }
        
        NSLog(@"❌ DownloadManager: Could not parse date string: %@", dateString);
        return nil;
    }
    
    NSLog(@"❌ DownloadManager: Unknown date type: %@ (value: %@)", [dateValue class], dateValue);
    return nil;
}


- (NSArray *)extractBarsArrayFromData:(id)historicalData {
    if ([historicalData isKindOfClass:[NSArray class]]) {
        return (NSArray *)historicalData;
    } else if ([historicalData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dataDict = (NSDictionary *)historicalData;
        NSArray *bars = dataDict[@"bars"] ?: dataDict[@"data"] ?: dataDict[@"candles"] ?: dataDict[@"results"];
        if (bars && [bars isKindOfClass:[NSArray class]]) {
            return bars;
        }
    }
    
    NSLog(@"❌ DownloadManager: Cannot extract bars array from data type: %@", [historicalData class]);
    return @[]; // Return empty array as fallback
}


// ===================================================================
// FIX: PARSING CORRETTO DEL QUOTE RESPONSE SCHWAB
// ===================================================================

// ✅ SOSTITUISCI la parte di parsing nel metodo autoCompleteWithCurrentBar:

- (void)autoCompleteWithCurrentBar:(id)historicalData
                        parameters:(NSDictionary *)parameters
                        dataSource:(id<DataSource>)dataSource
                        sourceInfo:(DataSourceInfo *)sourceInfo
                        completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    BarTimeframe timeframe = [parameters[@"timeframe"] integerValue];
    
    // ✅ ESTRAI ARRAY DAI DATI
    NSArray *historicalBars = [self extractBarsArrayFromData:historicalData];
    
    NSLog(@"📞 DownloadManager: Requesting quote for current bar completion");
    
    // ✅ RICHIEDI QUOTE PER COSTRUIRE CURRENT BAR
    [dataSource fetchQuoteForSymbol:symbol completion:^(id quoteResult, NSError *quoteError) {
        
        if (quoteError || !quoteResult) {
            NSLog(@"⚠️ DownloadManager: Quote request failed (%@), returning historical only",
                  quoteError.localizedDescription ?: @"no quote data");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(historicalData, sourceInfo.type, nil);
            });
            return;
        }
        
        // ✅ PARSING CORRETTO DEL QUOTE RESPONSE SCHWAB
        NSMutableDictionary *currentBar = [NSMutableDictionary dictionary];
        
        double openPrice = 0.0;
        double highPrice = 0.0;
        double lowPrice = 0.0;
        double lastPrice = 0.0;
        double closePrice = 0.0;
        NSInteger volume = 0;
        NSDate *timestamp = nil;
        
        if ([quoteResult isKindOfClass:[NSDictionary class]]) {
            NSDictionary *quoteDict = (NSDictionary *)quoteResult;
            
            // ✅ SCHWAB STRUCTURE: Estrai dai nested dictionaries
            NSDictionary *quoteSection = quoteDict[@"quote"];
            NSDictionary *regularSection = quoteDict[@"regular"];
            NSDictionary *extendedSection = quoteDict[@"extended"];
            
            if (quoteSection) {
                // Dati principali dalla sezione "quote"
                openPrice = [quoteSection[@"openPrice"] doubleValue];
                highPrice = [quoteSection[@"highPrice"] doubleValue];
                lowPrice = [quoteSection[@"lowPrice"] doubleValue];
                lastPrice = [quoteSection[@"lastPrice"] doubleValue];
                closePrice = [quoteSection[@"closePrice"] doubleValue];  // Previous close
                volume = [quoteSection[@"totalVolume"] integerValue];
                
                // Timestamp (in milliseconds)
                NSNumber *tradeTime = quoteSection[@"tradeTime"];
                if (tradeTime) {
                    timestamp = [self convertToNSDate:tradeTime];
                }
                
                NSLog(@"📊 DownloadManager: Schwab quote parsed - O:%.4f H:%.4f L:%.4f Last:%.4f Close:%.4f V:%ld",
                      openPrice, highPrice, lowPrice, lastPrice, closePrice, (long)volume);
            }
            
            // ✅ FALLBACK: Se regular session ha dati migliori
            if (regularSection && openPrice == 0) {
                lastPrice = [regularSection[@"regularMarketLastPrice"] doubleValue];
                volume = [regularSection[@"regularMarketLastSize"] integerValue];
                
                NSNumber *regularTradeTime = regularSection[@"regularMarketTradeTime"];
                if (regularTradeTime) {
                    timestamp = [self convertToNSDate:regularTradeTime];
                }
                
                NSLog(@"📊 DownloadManager: Using regular market data - Last:%.4f V:%ld", lastPrice, (long)volume);
            }
            
            // ✅ EXTENDED HOURS: Se siamo in after-hours
            if (extendedSection && [quoteSection[@"securityStatus"] isEqualToString:@"Closed"]) {
                double extendedLast = [extendedSection[@"lastPrice"] doubleValue];
                if (extendedLast > 0) {
                    lastPrice = extendedLast;
                    NSLog(@"📊 DownloadManager: Using extended hours price: %.4f", lastPrice);
                }
            }
            
        } else if ([quoteResult isKindOfClass:[MarketData class]]) {
            // Fallback per MarketData objects (se qualcuno converte già)
            MarketData *marketData = (MarketData *)quoteResult;
            openPrice = marketData.open ? [marketData.open doubleValue] : 0.0;
            highPrice = marketData.high ? [marketData.high doubleValue] : 0.0;
            lowPrice = marketData.low ? [marketData.low doubleValue] : 0.0;
            lastPrice = marketData.last ? [marketData.last doubleValue] : 0.0;
            volume = marketData.volume;
            timestamp = marketData.timestamp;
            
        } else {
            NSLog(@"❌ DownloadManager: Unknown quote result type: %@", [quoteResult class]);
        }
        
        // ✅ VALIDAZIONE DATI
        if (lastPrice <= 0) {
            NSLog(@"⚠️ DownloadManager: Invalid quote price (%.4f), returning historical only", lastPrice);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(historicalData, sourceInfo.type, nil);
            });
            return;
        }
        
        // ✅ GESTIONE TIMESTAMP
        if (!timestamp) {
            timestamp = [self adjustDateForTimeframe:[NSDate date] timeframe:timeframe];
        }
        
        // ✅ GESTIONE OPEN:
        // - Se abbiamo openPrice > 0, usalo
        // - Altrimenti usa closePrice (previous close)
        double finalOpen;
        if (openPrice > 0) {
            finalOpen = openPrice;
        } else if (closePrice > 0) {
            finalOpen = closePrice;  // Previous close diventa open
        } else {
            finalOpen = lastPrice;   // Ultimo fallback
        }
        
        // ✅ GESTIONE HIGH/LOW:
        // - Se abbiamo high/low > 0, usali
        // - Altrimenti calcola da open/close
        double finalHigh;
        if (highPrice > 0) {
            finalHigh = highPrice;
        } else {
            finalHigh = MAX(finalOpen, lastPrice);
        }
        
        double finalLow;
        if (lowPrice > 0) {
            finalLow = lowPrice;
        } else {
            finalLow = MIN(finalOpen, lastPrice);
        }
        
        // ✅ VALIDAZIONE FINALE OHLC
        // Assicura logica OHLC corretta
        if (finalHigh < MAX(finalOpen, lastPrice)) {
            finalHigh = MAX(finalOpen, lastPrice);
        }
        if (finalLow > MIN(finalOpen, lastPrice)) {
            finalLow = MIN(finalOpen, lastPrice);
        }
        
        // ✅ COSTRUISCI BARRA CORRENTE CON FORMATO UNIFORME AI DATI STORICI
        // Converti timestamp in formato Schwab (milliseconds Unix timestamp)
        NSTimeInterval timeInterval = [timestamp timeIntervalSince1970];
        long long timestampMillis = (long long)(timeInterval * 1000); // Convert to milliseconds
        
        // ✅ USA STESSO FORMATO E CHIAVI DEI DATI STORICI
        currentBar[@"datetime"] = @(timestampMillis);  // ← STESSO FORMATO degli historical!
        currentBar[@"close"] = [NSString stringWithFormat:@"%.4f", lastPrice];  // ← String come historical
        currentBar[@"open"] = [NSString stringWithFormat:@"%.4f", finalOpen];
        currentBar[@"high"] = [NSString stringWithFormat:@"%.4f", finalHigh];
        currentBar[@"low"] = [NSString stringWithFormat:@"%.4f", finalLow];
        currentBar[@"volume"] = @(volume);  // ← Number come historical
        
        // ✅ VERIFICA UNIFORMITÀ
        if (historicalBars.count > 0) {
            NSDictionary *lastHistoricalBar = historicalBars.lastObject;
            NSLog(@"🔍 DownloadManager: Format comparison:");
            NSLog(@"   Last historical: datetime=%@, close=%@",
                  lastHistoricalBar[@"datetime"], lastHistoricalBar[@"close"]);
            NSLog(@"   New current bar: datetime=%@, close=%@",
                  currentBar[@"datetime"], currentBar[@"close"]);
        }
        
        // ✅ MERGE CON HISTORICAL DATA
        NSMutableArray *completeBars = [historicalBars mutableCopy];
        [completeBars addObject:currentBar];
        
        // Se il dato originale era un dictionary, mantieni la struttura
        id finalResult;
        if ([historicalData isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *resultDict = [(NSDictionary *)historicalData mutableCopy];
            // Trova la chiave che conteneva i bars e aggiorna
            for (NSString *key in @[@"bars", @"data", @"candles", @"results"]) {
                if (resultDict[key]) {
                    resultDict[key] = [completeBars copy];
                    break;
                }
            }
            finalResult = [resultDict copy];
        } else {
            finalResult = [completeBars copy];
        }
        
        NSLog(@"✅ DownloadManager: Current bar added with uniform format - O:%@ H:%@ L:%@ C:%@ V:%ld (Total: %lu bars)",
              currentBar[@"open"], currentBar[@"high"], currentBar[@"low"], currentBar[@"close"],
              (long)volume, (unsigned long)completeBars.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(finalResult, sourceInfo.type, nil);
        });
    }];
}

- (NSDate *)adjustDateForTimeframe:(NSDate *)date timeframe:(BarTimeframe)timeframe {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    switch (timeframe) {
        case BarTimeframe1Day:
            // Per daily, usa la data così com'è
            return date;
            
        case BarTimeframe1Week: {
            // Per weekly, vai al lunedì della settimana corrente
            NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitWeekOfYear
                                                       fromDate:date];
            components.weekday = 2; // Monday
            return [calendar dateFromComponents:components];
        }
            
        case BarTimeframe1Month: {
            // Per monthly, vai al primo del mese corrente
            NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth
                                                       fromDate:date];
            components.day = 1;
            return [calendar dateFromComponents:components];
        }
            
        default:
            return date;
    }
}

- (void)handleHistoricalResponseWithAutoComplete:(NSArray *)bars
                                            error:(NSError *)error
                                       parameters:(NSDictionary *)parameters
                                       dataSource:(id<DataSource>)dataSource
                                       sourceInfo:(DataSourceInfo *)sourceInfo
                                          sources:(NSArray<DataSourceInfo *> *)sources
                                      sourceIndex:(NSInteger)index
                                        requestID:(NSString *)requestID
                                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!self.activeRequests[requestID]) {
        NSLog(@"⚠️ DownloadManager: Request %@ was cancelled during response handling", requestID);
        return;
    }
    
    if (error && self.fallbackEnabled && index < sources.count - 1) {
        // Try next data source
        NSLog(@"❌ DownloadManager: Date range request failed with %@ (%@), trying next source",
              dataSource.sourceName, error.localizedDescription);
        
        sourceInfo.failureCount++;
        sourceInfo.lastFailureTime = [NSDate date];
        
        [self executeHistoricalWithSources:sources
                                parameters:parameters
                               sourceIndex:index + 1
                                 requestID:requestID
                                completion:completion];
        return;
    }
    
    // Request completed (success or final failure)
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DownloadManager: Date range historical request failed: %@", error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, sourceInfo.type, error);
            });
        }
        return;
    }
    
    NSLog(@"✅ DownloadManager: Date range request succeeded with %@, got %lu bars",
          dataSource.sourceName, bars ? (unsigned long)bars.count : 0);
    
    // ✅ AUTO COMPLETE: Aggiungi current bar se necessario
    BarTimeframe timeframe = [parameters[@"timeframe"] integerValue];
    
    if ([self needsCurrentBarCompletion:bars timeframe:timeframe]) {
        NSLog(@"🔄 DownloadManager: Adding current bar to historical data");
        [self autoCompleteWithCurrentBar:bars
                               parameters:parameters
                               dataSource:dataSource
                               completion:^(NSArray *completedBars, DataSourceType usedSource, NSError *currentBarError) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Use completed bars if available, otherwise original bars
                    NSArray *finalBars = completedBars ?: bars;
                    completion(finalBars, sourceInfo.type, currentBarError ?: error);
                });
            }
        }];
    } else {
        // Return data as-is
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(bars, sourceInfo.type, nil);
            });
        }
    }
}

- (void)executeAccountInfoRequest:(NSDictionary *)parameters
                   withDataSource:(id<DataSource>)dataSource
                       sourceInfo:(DataSourceInfo *)sourceInfo
                          sources:(NSArray<DataSourceInfo *> *)sources
                      sourceIndex:(NSInteger)index
                        requestID:(NSString *)requestID
                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    
    if ([dataSource isKindOfClass:NSClassFromString(@"IBKRDataSource")]) {
        // ✅ IBKR: Se abbiamo accountId specifico, usa getAccountSummary, altrimenti getAccounts
        if (accountId) {
            NSLog(@"DownloadManager: Using IBKR account summary for account %@", accountId);
            
            [dataSource performSelector:@selector(getAccountSummary:completion:)
                              withObject:accountId
                              withObject:^(NSDictionary *summary, NSError *error) {
                if (!self.activeRequests[requestID]) {
                    return;
                }
                
                if (error && self.fallbackEnabled && index < sources.count - 1) {
                    sourceInfo.failureCount++;
                    sourceInfo.lastFailureTime = [NSDate date];
                    
                    [self executeRequestWithSources:sources
                                        requestType:DataRequestTypeAccountInfo
                                         parameters:parameters
                                        sourceIndex:index + 1
                                          requestID:requestID
                                         completion:completion];
                } else {
                    [self.activeRequests removeObjectForKey:requestID];
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(summary, sourceInfo.type, error);
                        });
                    }
                }
            }];
        } else {
            NSLog(@"DownloadManager: Using IBKR accounts list");
            
            [dataSource performSelector:@selector(getAccountsWithCompletion:)
                              withObject:^(NSArray<NSString *> *accounts, NSError *error) {
                if (!self.activeRequests[requestID]) {
                    return;
                }
                
                if (error && self.fallbackEnabled && index < sources.count - 1) {
                    sourceInfo.failureCount++;
                    sourceInfo.lastFailureTime = [NSDate date];
                    
                    [self executeRequestWithSources:sources
                                        requestType:DataRequestTypeAccountInfo
                                         parameters:parameters
                                        sourceIndex:index + 1
                                          requestID:requestID
                                         completion:completion];
                } else {
                    [self.activeRequests removeObjectForKey:requestID];
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // ✅ Converti array di account IDs in formato compatibile con altri broker
                            NSMutableArray *accountsData = [NSMutableArray array];
                            for (NSString *accountIdStr in accounts) {
                                [accountsData addObject:@{
                                    @"accountId": accountIdStr,
                                    @"accountNumber": accountIdStr, // Compatibility con Schwab
                                    @"brokerIndicator": @"IBKR", // Per detection nel DataHub
                                    @"type": @"UNKNOWN" // IBKR non fornisce tipo nell'elenco base
                                }];
                            }
                            completion(accountsData, sourceInfo.type, error);
                        });
                    }
                }
            }];
        }
    } else {
        // ✅ Altri data sources - usa metodo generico (se disponibile)
        // La maggior parte degli altri data sources non hanno metodi account specifici
        // quindi questa implementazione potrebbe essere estesa in futuro
        
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeAccountInfo
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}

@end
