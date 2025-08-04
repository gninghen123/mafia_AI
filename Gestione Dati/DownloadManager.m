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
    
    if ([dataSource respondsToSelector:@selector(fetchHistoricalDataForSymbol:timeframe:startDate:endDate:completion:)]) {
        [dataSource fetchHistoricalDataForSymbol:symbol
                                       timeframe:timeframe
                                       startDate:startDate
                                         endDate:endDate
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
    
    if ([dataSource respondsToSelector:@selector(fetchPositionsWithCompletion:)]) {
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
    
    if ([dataSource respondsToSelector:@selector(fetchOrdersWithCompletion:)]) {
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
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    NSDictionary *params = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"startDate": startDate,
        @"endDate": endDate
    };
    
    [self executeRequest:DataRequestTypeHistoricalBars
              parameters:params
              completion:^(id result, DataSourceType usedSource, NSError *error) {
                  if (completion) completion(result, error);
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
            [self handleCountBasedResponse:bars
                                     error:error
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
                                       completion:^(NSArray *bars, NSError *error) {
            [self handleCountBasedResponse:bars
                                     error:error
                                sourceInfo:sourceInfo
                                   sources:sources
                               sourceIndex:index
                                 requestID:requestID
                                completion:completion];
        }];
        
    } else {
        // Data source doesn't support historical data - try next source
        NSLog(@"❌ DownloadManager: Data source %@ doesn't support historical data", dataSource.sourceName);
        
        [self executeCountBasedHistoricalWithSources:sources
                                          parameters:parameters
                                         sourceIndex:index + 1
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




@end
