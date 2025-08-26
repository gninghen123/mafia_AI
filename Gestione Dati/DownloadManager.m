//
//  DownloadManager.m - PARTE 1
//  TradingApp
//
//  UNIFICATO: HTTP request manager con supporto completo per failover automatico
//  Mantiene compatibilità con codice esistente + nuove funzionalità unificate
//

#import "DownloadManager.h"
#import "WebullDataSource.h"
#import "ClaudeDataSource.h"
#import "MarketData.h"
#import "OtherDataSource.h"
#import "SchwabDataSource.h"
#import "IBKRDataSource.h"
#import <Cocoa/Cocoa.h>

#pragma mark - DataSourceInfo Helper Class

@interface DataSourceInfo : NSObject
@property (nonatomic, strong) id<DataSource> dataSource;
@property (nonatomic, assign) DataSourceType type;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, assign) NSInteger failureCount;
@property (nonatomic, strong) NSDate *lastFailureTime;
@property (nonatomic, strong) NSDate *lastSuccessTime;  // NEW: track success times
@property (nonatomic, assign) BOOL isConnected;         // NEW: cached connection status
@end

@implementation DataSourceInfo
@end

#pragma mark - DownloadManager Implementation

@interface DownloadManager ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, DataSourceInfo *> *dataSources;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *activeRequests;
@property (nonatomic, strong) NSOperationQueue *requestQueue;
@property (nonatomic, assign) BOOL fallbackEnabled;
@property (nonatomic, assign) NSInteger maxRetries;
@property (nonatomic, assign) NSTimeInterval requestTimeout;
@property (nonatomic, strong) dispatch_queue_t dataSourceQueue;
@property (nonatomic, assign) DataSourceType currentDataSource;
@property (nonatomic, assign) NSInteger requestCounter;  // NEW: for unified request IDs
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
        _requestCounter = 0;
        _dataSourceQueue = dispatch_queue_create("com.tradingapp.downloadmanager.datasources", DISPATCH_QUEUE_SERIAL);
        
        _requestQueue = [[NSOperationQueue alloc] init];
        _requestQueue.maxConcurrentOperationCount = 10;
        
        // Data sources are registered by AppDelegate
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
        info.isConnected = dataSource.isConnected;
        
        self.dataSources[@(type)] = info;
        
        NSLog(@"📡 DownloadManager: Registered %@ (type: %ld, priority: %ld)",
              dataSource.sourceName, (long)type, (long)priority);
    });
}

- (void)unregisterDataSource:(DataSourceType)type {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info && info.dataSource.isConnected) {
            [info.dataSource disconnect];
        }
        [self.dataSources removeObjectForKey:@(type)];
        
        NSLog(@"📡 DownloadManager: Unregistered data source type %ld", (long)type);
    });
}

#pragma mark - UNIFIED REQUEST EXECUTION

/**
 * PRIMARY UNIFIED METHOD: Execute any request with automatic source selection
 */
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    return [self executeRequest:requestType
                     parameters:parameters
                preferredSource:-1 // Auto-select
                     completion:completion];
}

/**
 * ADVANCED UNIFIED METHOD: Execute with preferred source
 */
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
             preferredSource:(DataSourceType)preferredSource
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *requestID = [self generateRequestID];
    self.activeRequests[requestID] = parameters;
    
    NSLog(@"📡 DownloadManager: Execute unified request type:%ld preferredSource:%ld requestID:%@",
          (long)requestType, (long)preferredSource, requestID);
    
    dispatch_async(self.dataSourceQueue, ^{
        NSArray<DataSourceInfo *> *availableSources = [self getAvailableSourcesForRequestType:requestType
                                                                              preferredSource:preferredSource];
        
        if (availableSources.count == 0) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:404
                                             userInfo:@{NSLocalizedDescriptionKey: @"No available data sources for this request type"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            return;
        }
        
        [self executeRequestWithSources:availableSources
                            requestType:requestType
                             parameters:parameters
                              requestID:requestID
                            sourceIndex:0
                             completion:completion];
    });
    
    return requestID;
}

#pragma mark - UNIFIED CONVENIENCE METHODS

- (NSString *)fetchQuoteForSymbol:(NSString *)symbol
                       completion:(void (^)(id quote, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{@"symbol": symbol};
    return [self executeRequest:DataRequestTypeQuote
                     parameters:parameters
                     completion:completion];
}

- (NSString *)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                         completion:(void (^)(NSDictionary *quotes, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{@"symbols": symbols};
    return [self executeRequest:DataRequestTypeBatchQuotes
                     parameters:parameters
                     completion:completion];
}

- (NSString *)fetchHistoricalDataForSymbol:(NSString *)symbol
                                 timeframe:(BarTimeframe)timeframe
                                 startDate:(NSDate *)startDate
                                   endDate:(NSDate *)endDate
                         needExtendedHours:(BOOL)needExtendedHours
                                completion:(void (^)(NSArray *bars, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"startDate": startDate,
        @"endDate": endDate,
        @"needExtendedHours": @(needExtendedHours)
    };
    
    return [self executeRequest:DataRequestTypeHistoricalBars
                     parameters:parameters
                     completion:completion];
}

- (NSString *)fetchHistoricalDataForSymbol:(NSString *)symbol
                                 timeframe:(BarTimeframe)timeframe
                                  barCount:(NSInteger)barCount
                         needExtendedHours:(BOOL)needExtendedHours
                                completion:(void (^)(NSArray *bars, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"barCount": @(barCount),
        @"needExtendedHours": @(needExtendedHours)
    };
    
    return [self executeRequest:DataRequestTypeHistoricalBars
                     parameters:parameters
                     completion:completion];
}

- (NSString *)fetchMarketListForType:(DataRequestType)listType
                          parameters:(nullable NSDictionary *)parameters
                          completion:(void (^)(NSArray *results, DataSourceType usedSource, NSError *error))completion {
    
    NSMutableDictionary *requestParams = [NSMutableDictionary dictionary];
    requestParams[@"listType"] = @(listType);
    
    if (parameters) {
        [requestParams addEntriesFromDictionary:parameters];
    }
    
    return [self executeRequest:listType // Use the specific list type
                     parameters:[requestParams copy]
                     completion:completion];
}

#pragma mark - Internal Request Execution

- (void)executeRequestWithSources:(NSArray<DataSourceInfo *> *)sources
                      requestType:(DataRequestType)requestType
                       parameters:(NSDictionary *)parameters
                        requestID:(NSString *)requestID
                      sourceIndex:(NSInteger)sourceIndex
                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    // Check if request was cancelled
    if (!self.activeRequests[requestID]) {
        NSLog(@"⚠️ DownloadManager: Request %@ was cancelled", requestID);
        return;
    }
    
    if (sourceIndex >= sources.count) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:500
                                         userInfo:@{NSLocalizedDescriptionKey: @"All data sources failed"}];
        [self.activeRequests removeObjectForKey:requestID];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
        return;
    }
    
    DataSourceInfo *sourceInfo = sources[sourceIndex];
    id<DataSource> dataSource = sourceInfo.dataSource;
    
    NSLog(@"📡 DownloadManager: Trying %@ for request type %ld (attempt %ld/%lu)",
          dataSource.sourceName, (long)requestType, (long)(sourceIndex + 1), (unsigned long)sources.count);
    
    // Route to appropriate DataSource method based on request type
    switch (requestType) {
        case DataRequestTypeQuote:
            [self executeQuoteRequest:parameters
                       withDataSource:dataSource
                           sourceInfo:sourceInfo
                              sources:sources
                          sourceIndex:sourceIndex
                            requestID:requestID
                           completion:completion];
            break;
            
        case DataRequestTypeBatchQuotes:
            [self executeBatchQuotesRequest:parameters
                             withDataSource:dataSource
                                 sourceInfo:sourceInfo
                                    sources:sources
                                sourceIndex:sourceIndex
                                  requestID:requestID
                                 completion:completion];
            break;
            
        case DataRequestTypeHistoricalBars:
            [self executeHistoricalRequest:parameters
                            withDataSource:dataSource
                                sourceInfo:sourceInfo
                                   sources:sources
                               sourceIndex:sourceIndex
                                 requestID:requestID
                                completion:completion];
            break;
            
        case DataRequestTypeTopGainers:
        case DataRequestTypeTopLosers:
        case DataRequestTypeETFList:
        case DataRequestType52WeekHigh:
        case DataRequestTypeMarketList:
            [self executeMarketListRequest:parameters
                            withDataSource:dataSource
                                sourceInfo:sourceInfo
                                   sources:sources
                               sourceIndex:sourceIndex
                                 requestID:requestID
                                completion:completion];
            break;
            
        case DataRequestTypeOrderBook:
            [self executeOrderBookRequest:parameters
                           withDataSource:dataSource
                               sourceInfo:sourceInfo
                                  sources:sources
                              sourceIndex:sourceIndex
                                requestID:requestID
                               completion:completion];
            break;
            
        case DataRequestTypePositions:
            [self executePositionsRequest:parameters
                           withDataSource:dataSource
                               sourceInfo:sourceInfo
                                  sources:sources
                              sourceIndex:sourceIndex
                                requestID:requestID
                               completion:completion];
            break;
            
        case DataRequestTypeOrders:
            [self executeOrdersRequest:parameters
                        withDataSource:dataSource
                            sourceInfo:sourceInfo
                               sources:sources
                           sourceIndex:sourceIndex
                             requestID:requestID
                            completion:completion];
            break;
            
        case DataRequestTypeAccountInfo:
            [self executeAccountInfoRequest:parameters
                             withDataSource:dataSource
                                 sourceInfo:sourceInfo
                                    sources:sources
                                sourceIndex:sourceIndex
                                  requestID:requestID
                                 completion:completion];
            break;
            
        default: {
            NSError *unsupportedError = [NSError errorWithDomain:@"DownloadManager"
                                                            code:400
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Unsupported request type"}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, unsupportedError);
            });
            break;
        }
    }
}


#pragma mark - Specific Request Type Implementations

- (void)executeQuoteRequest:(NSDictionary *)parameters
             withDataSource:(id<DataSource>)dataSource
                 sourceInfo:(DataSourceInfo *)sourceInfo
                    sources:(NSArray<DataSourceInfo *> *)sources
                sourceIndex:(NSInteger)sourceIndex
                  requestID:(NSString *)requestID
                 completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    
    [dataSource fetchQuoteForSymbol:symbol completion:^(id quote, NSError *error) {
        if (!self.activeRequests[requestID]) {
            return; // Request was cancelled
        }
        
        if (error) {
            NSLog(@"❌ DownloadManager: %@ failed for quote %@: %@", dataSource.sourceName, symbol, error.localizedDescription);
            [self recordFailureForSource:sourceInfo];
            
            // Try next source
            [self executeRequestWithSources:sources
                                 requestType:DataRequestTypeQuote
                                  parameters:parameters
                                   requestID:requestID
                                 sourceIndex:sourceIndex + 1
                                  completion:completion];
        } else {
            NSLog(@"✅ DownloadManager: %@ succeeded for quote %@", dataSource.sourceName, symbol);
            [self recordSuccessForSource:sourceInfo];
            [self.activeRequests removeObjectForKey:requestID];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(quote, dataSource.sourceType, nil);
            });
        }
    }];
}

- (void)executeBatchQuotesRequest:(NSDictionary *)parameters
                   withDataSource:(id<DataSource>)dataSource
                       sourceInfo:(DataSourceInfo *)sourceInfo
                          sources:(NSArray<DataSourceInfo *> *)sources
                      sourceIndex:(NSInteger)sourceIndex
                        requestID:(NSString *)requestID
                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSArray<NSString *> *symbols = parameters[@"symbols"];
    
    [dataSource fetchQuotesForSymbols:symbols completion:^(NSDictionary *quotes, NSError *error) {
        if (!self.activeRequests[requestID]) {
            return; // Request was cancelled
        }
        
        if (error) {
            NSLog(@"❌ DownloadManager: %@ failed for batch quotes: %@", dataSource.sourceName, error.localizedDescription);
            [self recordFailureForSource:sourceInfo];
            
            // Try next source
            [self executeRequestWithSources:sources
                                 requestType:DataRequestTypeBatchQuotes
                                  parameters:parameters
                                   requestID:requestID
                                 sourceIndex:sourceIndex + 1
                                  completion:completion];
        } else {
            NSLog(@"✅ DownloadManager: %@ succeeded for batch quotes (%lu symbols)", dataSource.sourceName, (unsigned long)quotes.count);
            [self recordSuccessForSource:sourceInfo];
            [self.activeRequests removeObjectForKey:requestID];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(quotes, dataSource.sourceType, nil);
            });
        }
    }];
}

- (void)executeHistoricalRequest:(NSDictionary *)parameters
                  withDataSource:(id<DataSource>)dataSource
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)sourceIndex
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    BarTimeframe timeframe = [parameters[@"timeframe"] integerValue];
    BOOL needExtendedHours = [parameters[@"needExtendedHours"] boolValue];
    
    // Check if using date range or bar count
    if (parameters[@"startDate"] && parameters[@"endDate"]) {
        NSDate *startDate = parameters[@"startDate"];
        NSDate *endDate = parameters[@"endDate"];
        
        [dataSource fetchHistoricalDataForSymbol:symbol
                                       timeframe:timeframe
                                       startDate:startDate
                                         endDate:endDate
                                needExtendedHours:needExtendedHours
                                      completion:^(NSArray *bars, NSError *error) {
            [self handleHistoricalResponse:bars
                                     error:error
                                dataSource:dataSource
                                sourceInfo:sourceInfo
                                   sources:sources
                               sourceIndex:sourceIndex
                                parameters:parameters
                                 requestID:requestID
                                completion:completion];
        }];
    } else {
        NSInteger barCount = [parameters[@"barCount"] integerValue];
        
        [dataSource fetchHistoricalDataForSymbol:symbol
                                       timeframe:timeframe
                                        barCount:barCount
                                needExtendedHours:needExtendedHours
                                      completion:^(NSArray *bars, NSError *error) {
            [self handleHistoricalResponse:bars
                                     error:error
                                dataSource:dataSource
                                sourceInfo:sourceInfo
                                   sources:sources
                               sourceIndex:sourceIndex
                                parameters:parameters
                                 requestID:requestID
                                completion:completion];
        }];
    }
}

- (void)handleHistoricalResponse:(NSArray *)bars
                           error:(NSError *)error
                      dataSource:(id<DataSource>)dataSource
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)sourceIndex
                      parameters:(NSDictionary *)parameters
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!self.activeRequests[requestID]) {
        return; // Request was cancelled
    }
    
    if (error) {
        NSLog(@"❌ DownloadManager: %@ failed for historical data: %@", dataSource.sourceName, error.localizedDescription);
        [self recordFailureForSource:sourceInfo];
        
        // Try next source
        [self executeRequestWithSources:sources
                             requestType:DataRequestTypeHistoricalBars
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    } else {
        NSLog(@"✅ DownloadManager: %@ succeeded for historical data (%lu bars)", dataSource.sourceName, (unsigned long)bars.count);
        [self recordSuccessForSource:sourceInfo];
        [self.activeRequests removeObjectForKey:requestID];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(bars, dataSource.sourceType, nil);
        });
    }
}

- (void)executeMarketListRequest:(NSDictionary *)parameters
                  withDataSource:(id<DataSource>)dataSource
                      sourceInfo:(DataSourceInfo *)sourceInfo
                         sources:(NSArray<DataSourceInfo *> *)sources
                     sourceIndex:(NSInteger)sourceIndex
                       requestID:(NSString *)requestID
                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    DataRequestType listType = [parameters[@"listType"] integerValue];
    NSMutableDictionary *listParameters = [parameters mutableCopy];
    [listParameters removeObjectForKey:@"listType"]; // Remove our internal parameter
    
    if ([dataSource respondsToSelector:@selector(fetchMarketListForType:parameters:completion:)]) {
        [dataSource fetchMarketListForType:listType
                                parameters:[listParameters copy]
                                completion:^(NSArray *results, NSError *error) {
            [self handleGenericResponse:results
                                   error:error
                              dataSource:dataSource
                              sourceInfo:sourceInfo
                                 sources:sources
                             sourceIndex:sourceIndex
                              parameters:parameters
                               requestID:requestID
                             requestType:listType
                              completion:completion];
        }];
    } else {
        // DataSource doesn't support market lists - try next
        [self executeRequestWithSources:sources
                             requestType:listType
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    }
}

- (void)executeOrderBookRequest:(NSDictionary *)parameters
                 withDataSource:(id<DataSource>)dataSource
                     sourceInfo:(DataSourceInfo *)sourceInfo
                        sources:(NSArray<DataSourceInfo *> *)sources
                    sourceIndex:(NSInteger)sourceIndex
                      requestID:(NSString *)requestID
                     completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    NSInteger depth = [parameters[@"depth"] integerValue] ?: 10;
    
    if ([dataSource respondsToSelector:@selector(fetchOrderBookForSymbol:depth:completion:)]) {
        [dataSource fetchOrderBookForSymbol:symbol
                                      depth:depth
                                 completion:^(id orderBook, NSError *error) {
            [self handleGenericResponse:orderBook
                                   error:error
                              dataSource:dataSource
                              sourceInfo:sourceInfo
                                 sources:sources
                             sourceIndex:sourceIndex
                              parameters:parameters
                               requestID:requestID
                             requestType:DataRequestTypeOrderBook
                              completion:completion];
        }];
    } else {
        // DataSource doesn't support order book - try next
        [self executeRequestWithSources:sources
                             requestType:DataRequestTypeOrderBook
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    }
}

- (void)executePositionsRequest:(NSDictionary *)parameters
                 withDataSource:(id<DataSource>)dataSource
                     sourceInfo:(DataSourceInfo *)sourceInfo
                        sources:(NSArray<DataSourceInfo *> *)sources
                    sourceIndex:(NSInteger)sourceIndex
                      requestID:(NSString *)requestID
                     completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    
    if ([dataSource respondsToSelector:@selector(fetchPositionsForAccount:completion:)]) {
        [dataSource fetchPositionsForAccount:accountId
                                  completion:^(NSArray *positions, NSError *error) {
            [self handleGenericResponse:positions
                                   error:error
                              dataSource:dataSource
                              sourceInfo:sourceInfo
                                 sources:sources
                             sourceIndex:sourceIndex
                              parameters:parameters
                               requestID:requestID
                             requestType:DataRequestTypePositions
                              completion:completion];
        }];
    } else {
        // DataSource doesn't support positions - try next
        [self executeRequestWithSources:sources
                             requestType:DataRequestTypePositions
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    }
}

- (void)executeOrdersRequest:(NSDictionary *)parameters
              withDataSource:(id<DataSource>)dataSource
                  sourceInfo:(DataSourceInfo *)sourceInfo
                     sources:(NSArray<DataSourceInfo *> *)sources
                 sourceIndex:(NSInteger)sourceIndex
                   requestID:(NSString *)requestID
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    
    if ([dataSource respondsToSelector:@selector(fetchOrdersForAccount:completion:)]) {
        [dataSource fetchOrdersForAccount:accountId
                               completion:^(NSArray *orders, NSError *error) {
            [self handleGenericResponse:orders
                                   error:error
                              dataSource:dataSource
                              sourceInfo:sourceInfo
                                 sources:sources
                             sourceIndex:sourceIndex
                              parameters:parameters
                               requestID:requestID
                             requestType:DataRequestTypeOrders
                              completion:completion];
        }];
    } else {
        // DataSource doesn't support orders - try next
        [self executeRequestWithSources:sources
                             requestType:DataRequestTypeOrders
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    }
}

- (void)executeAccountInfoRequest:(NSDictionary *)parameters
                   withDataSource:(id<DataSource>)dataSource
                       sourceInfo:(DataSourceInfo *)sourceInfo
                          sources:(NSArray<DataSourceInfo *> *)sources
                      sourceIndex:(NSInteger)sourceIndex
                        requestID:(NSString *)requestID
                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    
    if (accountId) {
        // Request for specific account details
        if ([dataSource respondsToSelector:@selector(fetchAccountDetails:completion:)]) {
            [dataSource fetchAccountDetails:accountId completion:^(NSDictionary *details, NSError *error) {
                [self handleGenericResponse:details
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:DataRequestTypeAccountInfo
                                  completion:completion];
            }];
        } else {
            [self executeRequestWithSources:sources requestType:DataRequestTypeAccountInfo parameters:parameters requestID:requestID sourceIndex:sourceIndex + 1 completion:completion];
        }
    } else {
        // Request for all accounts
        if ([dataSource respondsToSelector:@selector(fetchAccountsWithCompletion:)]) {
            [dataSource fetchAccountsWithCompletion:^(NSArray *accounts, NSError *error) {
                [self handleGenericResponse:accounts
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:DataRequestTypeAccountInfo
                                  completion:completion];
            }];
        } else {
            [self executeRequestWithSources:sources requestType:DataRequestTypeAccountInfo parameters:parameters requestID:requestID sourceIndex:sourceIndex + 1 completion:completion];
        }
    }
}

- (void)handleGenericResponse:(id)result
                        error:(NSError *)error
                   dataSource:(id<DataSource>)dataSource
                   sourceInfo:(DataSourceInfo *)sourceInfo
                      sources:(NSArray<DataSourceInfo *> *)sources
                  sourceIndex:(NSInteger)sourceIndex
                   parameters:(NSDictionary *)parameters
                    requestID:(NSString *)requestID
                  requestType:(DataRequestType)requestType
                   completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!self.activeRequests[requestID]) {
        return; // Request was cancelled
    }
    
    if (error) {
        NSLog(@"❌ DownloadManager: %@ failed for request type %ld: %@", dataSource.sourceName, (long)requestType, error.localizedDescription);
        [self recordFailureForSource:sourceInfo];
        
        // Try next source
        [self executeRequestWithSources:sources
                             requestType:requestType
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    } else {
        NSLog(@"✅ DownloadManager: %@ succeeded for request type %ld", dataSource.sourceName, (long)requestType);
        [self recordSuccessForSource:sourceInfo];
        [self.activeRequests removeObjectForKey:requestID];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result, dataSource.sourceType, nil);
        });
    }
}

#pragma mark - Source Selection and Management

- (NSArray<DataSourceInfo *> *)getAvailableSourcesForRequestType:(DataRequestType)requestType
                                                  preferredSource:(DataSourceType)preferredSource {
    NSMutableArray<DataSourceInfo *> *availableSources = [NSMutableArray array];
    
    // First add preferred source if specified and supports the request type
    if (preferredSource != -1) {
        DataSourceInfo *preferredSourceInfo = self.dataSources[@(preferredSource)];
        if (preferredSourceInfo && [self dataSource:preferredSourceInfo.dataSource supportsRequestType:requestType]) {
            [availableSources addObject:preferredSourceInfo];
        }
    }
    
    // Sort remaining sources by priority and failure count
    NSArray *sortedKeys = [self.dataSources.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSNumber *key1, NSNumber *key2) {
        DataSourceInfo *info1 = self.dataSources[key1];
        DataSourceInfo *info2 = self.dataSources[key2];
        
        // Skip already added preferred source
        if (preferredSource != -1 &&
            (info1.type == preferredSource || info2.type == preferredSource)) {
            if (info1.type == preferredSource) return NSOrderedDescending;
            if (info2.type == preferredSource) return NSOrderedAscending;
        }
        
        // First by priority (lower number = higher priority)
        if (info1.priority < info2.priority) return NSOrderedAscending;
        if (info1.priority > info2.priority) return NSOrderedDescending;
        
        // Then by failure count (lower failures = higher priority)
        if (info1.failureCount < info2.failureCount) return NSOrderedAscending;
        if (info1.failureCount > info2.failureCount) return NSOrderedDescending;
        
        return NSOrderedSame;
    }];
    
    // Add remaining sources that support the request type
    for (NSNumber *key in sortedKeys) {
        DataSourceInfo *info = self.dataSources[key];
        
        // Skip if already added as preferred source
        if (preferredSource != -1 && info.type == preferredSource) {
            continue;
        }
        
        if ([self dataSource:info.dataSource supportsRequestType:requestType]) {
            [availableSources addObject:info];
        }
    }
    
    return [availableSources copy];
}

- (BOOL)dataSource:(id<DataSource>)dataSource supportsRequestType:(DataRequestType)requestType {
    DataSourceCapabilities capabilities = dataSource.capabilities;
    
    switch (requestType) {
        case DataRequestTypeQuote:
        case DataRequestTypeBatchQuotes:
            return (capabilities & DataSourceCapabilityQuotes) != 0;
            
        case DataRequestTypeHistoricalBars:
            // FIX: Usa il nome corretto dalla repo esistente
            return (capabilities & DataSourceCapabilityHistoricalData) != 0;  // NON DataSourceCapabilityHistoricalData
            
        case DataRequestTypeTopGainers:
        case DataRequestTypeTopLosers:
        case DataRequestTypeETFList:
        case DataRequestType52WeekHigh:
        case DataRequestTypeMarketList:
            // FIX: Questo capability non esiste nella repo - rimuovi o crea
            // return (capabilities & DataSourceCapabilityMarketLists) != 0;
            
            // WORKAROUND: Usa una capability esistente o check diretto
            return (capabilities & DataSourceCapabilityNews) != 0 || // Se WebullDataSource ha News
                   [dataSource respondsToSelector:@selector(fetchMarketListForType:parameters:completion:)];
            
        case DataRequestTypeOrderBook:
            // FIX: Usa il nome corretto
            return (capabilities & DataSourceCapabilityOptions) != 0;  // NON DataSourceCapabilityLevel2Data
            
        case DataRequestTypePositions:
        case DataRequestTypeOrders:
        case DataRequestTypeAccountInfo:
            // FIX: Usa il nome corretto dalla repo esistente
            return (capabilities & DataSourceCapabilityAccounts) != 0;  // NON DataSourceCapabilityPortfolioData
            
        case DataRequestTypeFundamentals:
            return (capabilities & DataSourceCapabilityFundamentals) != 0;
            
        default:
            // For unknown request types, check if the DataSource explicitly implements the method
            return [dataSource respondsToSelector:@selector(fetchMarketListForType:parameters:completion:)];
    }
}

#pragma mark - Source Performance Tracking

- (void)recordSuccessForSource:(DataSourceInfo *)sourceInfo {
    sourceInfo.failureCount = MAX(0, sourceInfo.failureCount - 1); // Reduce failure count on success
    sourceInfo.lastSuccessTime = [NSDate date];
    sourceInfo.isConnected = sourceInfo.dataSource.isConnected;
    NSLog(@"📈 DownloadManager: %@ success (failures: %ld)", sourceInfo.dataSource.sourceName, (long)sourceInfo.failureCount);
}

- (void)recordFailureForSource:(DataSourceInfo *)sourceInfo {
    sourceInfo.failureCount++;
    sourceInfo.lastFailureTime = [NSDate date];
    sourceInfo.isConnected = sourceInfo.dataSource.isConnected;
    NSLog(@"📉 DownloadManager: %@ failure (failures: %ld)", sourceInfo.dataSource.sourceName, (long)sourceInfo.failureCount);
}

#pragma mark - Request Management

- (NSString *)generateRequestID {
    @synchronized(self) {
        return [NSString stringWithFormat:@"REQ_%ld_%ld",
                (long)self.requestCounter++,
                (long)[[NSDate date] timeIntervalSince1970]];
    }
}

- (void)cancelRequest:(NSString *)requestID {
    if (requestID) {
        [self.activeRequests removeObjectForKey:requestID];
        NSLog(@"📡 DownloadManager: Cancelled request %@", requestID);
    }
}

- (void)cancelAllRequests {
    [self.activeRequests removeAllObjects];
    NSLog(@"📡 DownloadManager: Cancelled all active requests");
}

#pragma mark - Connection Management

- (void)connectDataSource:(DataSourceType)type completion:(void (^)(BOOL success, NSError *error))completion {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info) {
            [info.dataSource connectWithCompletion:^(BOOL success, NSError *error) {
                info.isConnected = success;
                if (success) {
                    info.failureCount = 0; // Reset failure count on successful connection
                    info.lastSuccessTime = [NSDate date];
                }
                if (completion) completion(success, error);
            }];
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
            info.isConnected = NO;
        }
    });
}

- (void)reconnectAllDataSources {
    dispatch_async(self.dataSourceQueue, ^{
        for (DataSourceInfo *info in self.dataSources.allValues) {
            [self connectDataSource:info.type completion:nil];
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

- (DataSourceType)currentDataSource {
    // Return the highest priority connected source
    __block DataSourceType current = -1;
    dispatch_sync(self.dataSourceQueue, ^{
        NSArray *sortedInfos = [self.dataSources.allValues sortedArrayUsingComparator:^NSComparisonResult(DataSourceInfo *info1, DataSourceInfo *info2) {
            if (info1.priority < info2.priority) return NSOrderedAscending;
            if (info1.priority > info2.priority) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        
        for (DataSourceInfo *info in sortedInfos) {
            if (info.dataSource.isConnected) {
                current = info.type;
                break;
            }
        }
    });
    
    return current;
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
                @"lastSuccessTime": info.lastSuccessTime ?: [NSNull null],
                @"lastFailureTime": info.lastFailureTime ?: [NSNull null],
                @"capabilities": @(info.dataSource.capabilities)
            };
        }
    });
    return stats;
}

@end
