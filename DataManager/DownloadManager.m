//
//  DownloadManager.m
//  TradingApp
//

#import "DownloadManager.h"
#import "WebullDataSource.h"




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

- (void)setDataSourcePriority:(NSInteger)priority forType:(DataSourceType)type {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info) {
            info.priority = priority;
        }
    });
}

#pragma mark - Configuration

- (void)configureDataSource:(DataSourceType)type withCredentials:(NSDictionary *)credentials {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info) {
            [info.dataSource connectWithCompletion:^(BOOL success, NSError *error) {
                if (success) {
                    NSLog(@"Successfully configured data source: %@", info.dataSource.sourceName);
                } else {
                    NSLog(@"Failed to configure data source %@: %@", info.dataSource.sourceName, error);
                }
            }];
        }
    });
}

#pragma mark - Request Execution
- (void)executeMarketListRequest:(NSDictionary *)parameters
                  withDataSource:(id<DataSource>)dataSource
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)index
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    // Check if this is a Webull data source
    if ([dataSource isKindOfClass:[WebullDataSource class]]) {
        WebullDataSource *webullSource = (WebullDataSource *)dataSource;
        NSString *listType = parameters[@"listType"];
        
        if ([listType isEqualToString:@"topGainers"]) {
            NSString *rankType = parameters[@"rankType"];
            NSInteger pageSize = [parameters[@"pageSize"] integerValue];
            
            [webullSource fetchTopGainersWithRankType:rankType
                                             pageSize:pageSize
                                           completion:^(NSArray *gainers, NSError *error) {
                if (error) {
                    // Try next source
                    [self executeRequestWithSources:sources
                                        requestType:DataRequestTypeTopGainers
                                         parameters:parameters
                                        sourceIndex:index + 1
                                          requestID:requestID
                                         completion:completion];
                } else {
                    [self.activeRequests removeObjectForKey:requestID];
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(gainers, sourceInfo.type, nil);
                        });
                    }
                }
            }];
        } else if ([listType isEqualToString:@"topLosers"]) {
            NSString *rankType = parameters[@"rankType"];
            NSInteger pageSize = [parameters[@"pageSize"] integerValue];
            
            [webullSource fetchTopLosersWithRankType:rankType
                                            pageSize:pageSize
                                          completion:^(NSArray *losers, NSError *error) {
                if (error) {
                    // Try next source
                    [self executeRequestWithSources:sources
                                        requestType:DataRequestTypeTopLosers
                                         parameters:parameters
                                        sourceIndex:index + 1
                                          requestID:requestID
                                         completion:completion];
                } else {
                    [self.activeRequests removeObjectForKey:requestID];
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(losers, sourceInfo.type, nil);
                        });
                    }
                }
            }];
        } else if ([listType isEqualToString:@"etfList"]) {
            [webullSource fetchETFListWithCompletion:^(NSArray *etfs, NSError *error) {
                if (error) {
                    // Try next source
                    [self executeRequestWithSources:sources
                                        requestType:DataRequestTypeETFList
                                         parameters:parameters
                                        sourceIndex:index + 1
                                          requestID:requestID
                                         completion:completion];
                } else {
                    [self.activeRequests removeObjectForKey:requestID];
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(etfs, sourceInfo.type, nil);
                        });
                    }
                }
            }];
        }
    } else {
        // This source doesn't support market lists
        [self executeRequestWithSources:sources
                            requestType:DataRequestTypeMarketList
                             parameters:parameters
                            sourceIndex:index + 1
                              requestID:requestID
                             completion:completion];
    }
}


- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
              preferredSource:(DataSourceType)preferredSource
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    self.activeRequests[requestID] = parameters;
    
    // Debug logging migliorato
   
    
    // Get sorted data sources by priority
    NSArray<DataSourceInfo *> *sortedSources = [self sortedDataSourcesForRequestType:requestType
                                                                      preferredSource:preferredSource];
    
    if (sortedSources.count == 0) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithFormat:@"No data sources available for %@ request",
                                                    @"h"]}];
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

#pragma mark - Specific Request Types

// Aggiornamento del metodo executeQuoteRequest nel DownloadManager.m

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
        NSLog(@"DownloadManager: Data source %@ supports fetchQuoteForSymbol", dataSource.sourceName);
        
        [dataSource fetchQuoteForSymbol:symbol completion:^(id quote, NSError *error) {
            if (!self.activeRequests[requestID]) {
                NSLog(@"DownloadManager: Request %@ was cancelled", requestID);
                return; // Request was cancelled
            }
            
            if (error) {
                NSLog(@"DownloadManager: Quote request failed with %@ (error: %@)", dataSource.sourceName, error.localizedDescription);
                
                if (self.fallbackEnabled && index < sources.count - 1) {
                    NSLog(@"DownloadManager: Trying next data source...");
                    sourceInfo.failureCount++;
                    sourceInfo.lastFailureTime = [NSDate date];
                    
                    [self executeRequestWithSources:sources
                                        requestType:DataRequestTypeQuote
                                         parameters:parameters
                                        sourceIndex:index + 1
                                          requestID:requestID
                                         completion:completion];
                } else {
                    NSLog(@"DownloadManager: No more data sources to try for %@", symbol);
                    [self.activeRequests removeObjectForKey:requestID];
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(nil, sourceInfo.type, error);
                        });
                    }
                }
            } else {
                NSLog(@"DownloadManager: Quote request succeeded with %@ for %@", dataSource.sourceName, symbol);
                NSLog(@"DownloadManager: Quote result: %@", quote);
                
                [self.activeRequests removeObjectForKey:requestID];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(quote, sourceInfo.type, nil);
                    });
                }
            }
        }];
    } else {
        NSLog(@"DownloadManager: Data source %@ does NOT support fetchQuoteForSymbol", dataSource.sourceName);
        
        // This source doesn't support quotes, try next
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
                return; // Request was cancelled
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                NSLog(@"Historical data request failed with %@, trying next source", dataSource.sourceName);
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
        // This source doesn't support historical data, try next
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
        [dataSource fetchOrderBookForSymbol:symbol depth:depth completion:^(id orderBook, NSError *error) {
            if (!self.activeRequests[requestID]) {
                return; // Request was cancelled
            }
            
            if (error && self.fallbackEnabled && index < sources.count - 1) {
                NSLog(@"Order book request failed with %@, trying next source", dataSource.sourceName);
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
        // This source doesn't support order book, try next
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
                return; // Request was cancelled
            }
            
            [self.activeRequests removeObjectForKey:requestID];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(positions, sourceInfo.type, error);
                });
            }
        }];
    } else {
        // This source doesn't support positions, return error
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: @"Data source does not support position data"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, sourceInfo.type, error);
            });
        }
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
                return; // Request was cancelled
            }
            
            [self.activeRequests removeObjectForKey:requestID];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(orders, sourceInfo.type, error);
                });
            }
        }];
    } else {
        // This source doesn't support orders, return error
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: @"Data source does not support order data"}];
        [self.activeRequests removeObjectForKey:requestID];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, sourceInfo.type, error);
            });
        }
    }
}

#pragma mark - Helper Methods

- (NSArray<DataSourceInfo *> *)sortedDataSourcesForRequestType:(DataRequestType)requestType
                                                preferredSource:(DataSourceType)preferredSource {
    __block NSMutableArray<DataSourceInfo *> *availableSources = [NSMutableArray array];
    
    dispatch_sync(self.dataSourceQueue, ^{
        // First, check if preferred source is available and supports the request type
        DataSourceInfo *preferredInfo = self.dataSources[@(preferredSource)];
        if (preferredInfo && [self dataSource:preferredInfo.dataSource supportsRequestType:requestType]) {
            [availableSources addObject:preferredInfo];
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
            if (info.type != preferredSource &&
                [self dataSource:info.dataSource supportsRequestType:requestType]) {
                [availableSources addObject:info];
            }
        }
    });
    
    return availableSources;
}

// Nel file DownloadManager.m, modifica il metodo dataSource:supportsRequestType:

- (BOOL)dataSource:(id<DataSource>)dataSource supportsRequestType:(DataRequestType)requestType {
    DataSourceCapabilities capabilities = dataSource.capabilities;
    
    // Aggiungi supporto per i nuovi tipi di richiesta
    // I valori 100-103 sono quelli definiti in DataManager+MarketLists.h
    if (requestType == 100 || // DataRequestTypeMarketList
        requestType == 101 || // DataRequestTypeTopGainers
        requestType == 102 || // DataRequestTypeTopLosers
        requestType == 103) { // DataRequestTypeETFList
        
        // Per ora, solo DataSourceTypeCustom (Webull) supporta questi tipi
        return dataSource.sourceType == DataSourceTypeCustom;
    }
    
    // Gestione dei tipi esistenti
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
        case DataRequestTypePositions:
        case DataRequestTypeOrders:
        case DataRequestTypeAccountInfo:
            return (capabilities & DataSourceCapabilityAccounts) != 0;
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
                //todo 29lug
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
                @"name": info.dataSource.sourceName,
                @"connected": @(info.dataSource.isConnected),
                @"priority": @(info.priority),
                @"failureCount": @(info.failureCount),
                @"lastFailureTime": info.lastFailureTime ?: [NSNull null]
            };
        }
    });
    return stats;
}

- (NSArray<NSNumber *> *)availableDataSourcesForRequest:(DataRequestType)requestType {
    NSMutableArray *sources = [NSMutableArray array];
    
    dispatch_sync(self.dataSourceQueue, ^{
        for (NSNumber *key in self.dataSources) {
            DataSourceInfo *info = self.dataSources[key];
            if ([self dataSource:info.dataSource supportsRequestType:requestType]) {
                [sources addObject:key];
            }
        }
    });
    
    return sources;
}

#pragma mark - Rate Limiting

- (NSInteger)remainingRequestsForDataSource:(DataSourceType)type {
    __block NSInteger remaining = 0;
    dispatch_sync(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info && [info.dataSource respondsToSelector:@selector(remainingRequests)]) {
            remaining = [info.dataSource remainingRequests];
        }
    });
    return remaining;
}

- (NSDate *)rateLimitResetDateForDataSource:(DataSourceType)type {
    __block NSDate *resetDate = nil;
    dispatch_sync(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info && [info.dataSource respondsToSelector:@selector(rateLimitResetDate)]) {
            resetDate = [info.dataSource rateLimitResetDate];
        }
    });
    return resetDate;
}

#pragma mark - Batch Requests

- (NSString *)executeBatchRequests:(NSArray<NSDictionary *> *)requests
                        completion:(void (^)(NSArray *results, NSArray<NSError *> *errors))completion {
    NSString *batchID = [[NSUUID UUID] UUIDString];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:requests.count];
    NSMutableArray *errors = [NSMutableArray arrayWithCapacity:requests.count];
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSInteger i = 0; i < requests.count; i++) {
        [results addObject:[NSNull null]];
        [errors addObject:[NSNull null]];
        
        NSDictionary *request = requests[i];
        DataRequestType requestType = [request[@"requestType"] integerValue];
        NSDictionary *parameters = request[@"parameters"];
        DataSourceType preferredSource = [request[@"preferredSource"] integerValue];
        
        dispatch_group_enter(group);
        [self executeRequest:requestType
                  parameters:parameters
              preferredSource:preferredSource
                  completion:^(id result, DataSourceType usedSource, NSError *error) {
            if (result) {
                results[i] = result;
            }
            if (error) {
                errors[i] = error;
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion(results, errors);
        }
    });
    
    return batchID;
}

@end
