//
//  DownloadManager.m (PART 1 - SECURITY ENHANCED)
//  TradingApp
//
//  🛡️ SECURITY UPDATE: Distinguished Market Data vs Account Data routing
//  PART 1: Core methods, initialization, and MARKET DATA routing (with fallback)
//

#import "DownloadManager.h"

// Internal data source info
@interface DataSourceInfo : NSObject
@property (nonatomic, strong) id<DataSource> dataSource;
@property (nonatomic, assign) DataSourceType type;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, assign) NSInteger failureCount;
@property (atomic, assign) BOOL isConnected;  // Thread-safe automaticamente!
@property (nonatomic, strong) NSDate *lastFailureTime;
@end

@implementation DataSourceInfo
@end

@interface DownloadManager ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, DataSourceInfo *> *dataSources;
@property (nonatomic, strong) dispatch_queue_t dataSourceQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *activeRequests;
@end

@implementation DownloadManager

+ (instancetype)sharedManager {
    static DownloadManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dataSources = [NSMutableDictionary dictionary];
        _dataSourceQueue = dispatch_queue_create("com.tradingapp.datasourcequeue", DISPATCH_QUEUE_CONCURRENT);
        _activeRequests = [NSMutableDictionary dictionary];
        
        NSLog(@"📡 DownloadManager: Initialized with security-enhanced routing");
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

#pragma mark - Connection Management

- (void)connectDataSource:(DataSourceType)type completion:(void (^)(BOOL success, NSError *error))completion {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (!info) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:404
                                             userInfo:@{NSLocalizedDescriptionKey: @"Data source not registered"}];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
            }
            return;
        }
        
        [info.dataSource connectWithCompletion:^(BOOL success, NSError *error) {
            // ✅ IMPORTANTE: Aggiorna la property atomica
            info.isConnected = success;  // Thread-safe atomic write
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(success, error);
                });
            }
        }];
    });
}

- (void)disconnectDataSource:(DataSourceType)type {
    dispatch_async(self.dataSourceQueue, ^{
        DataSourceInfo *info = self.dataSources[@(type)];
        if (info && info.dataSource.isConnected) {
            [info.dataSource disconnect];
            
            // ✅ IMPORTANTE: Aggiorna la property atomica
            info.isConnected = NO;  // Thread-safe atomic write
        }
    });
}

- (void)reconnectAllDataSources {
    dispatch_async(self.dataSourceQueue, ^{
        for (NSNumber *typeNumber in self.dataSources) {
            DataSourceInfo *info = self.dataSources[typeNumber];
            if (!info.isConnected) {  // Atomic read - thread safe!
                [info.dataSource connectWithCompletion:^(BOOL success, NSError *error) {
                    // ✅ IMPORTANTE: Aggiorna la property atomica
                    info.isConnected = success;  // Thread-safe atomic write
                    
                    if (success) {
                        NSLog(@"✅ DownloadManager: Reconnected %@", info.dataSource.sourceName);
                    }
                }];
            }
        }
    });
}

#pragma mark - Status and Monitoring

- (BOOL)isDataSourceConnected:(DataSourceType)type {
    DataSourceInfo *info = self.dataSources[@(type)];
    BOOL connected = info ? info.isConnected : NO;
    
    // Log per debug (opzionale)
    NSLog(@"🔍 isDataSourceConnected(%@): %@", DataSourceTypeToString(type), connected ? @"YES" : @"NO");
    
    return connected;
}

- (DataSourceCapabilities)capabilitiesForDataSource:(DataSourceType)type {
    DataSourceInfo *info = self.dataSources[@(type)];
    DataSourceCapabilities capabilities = info ? info.dataSource.capabilities : DataSourceCapabilityNone;
    
    return capabilities;
}

- (NSDictionary *)statisticsForDataSource:(DataSourceType)type {
    DataSourceInfo *info = self.dataSources[@(type)];
    if (!info) {
        return @{};
    }
    
    // Accesso diretto alle property (thread-safe grazie ad atomic)
    return @{
        @"connected": @(info.isConnected),  // Atomic property - thread safe!
        @"failureCount": @(info.failureCount),
        @"lastFailure": info.lastFailureTime ?: [NSNull null],
        @"priority": @(info.priority)
    };
}

- (DataSourceType)currentDataSource {
    __block DataSourceType current = -1;
    __block NSInteger highestPriority = NSIntegerMin;
    
    dispatch_sync(self.dataSourceQueue, ^{
        for (NSNumber *typeNumber in self.dataSources) {
            DataSourceInfo *info = self.dataSources[typeNumber];
            if (info.isConnected && info.priority > highestPriority) {
                highestPriority = info.priority;
                current = [typeNumber integerValue];
            }
        }
    });
    return current;
}

#pragma mark - 📈 MARKET DATA REQUESTS (Automatic routing with fallback)

/**
 * 🔄 MARKET DATA routing logic: Automatic source selection with fallback
 */
- (NSString *)executeMarketDataRequest:(DataRequestType)requestType
                            parameters:(NSDictionary *)parameters
                            completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    return [self executeMarketDataRequest:requestType
                               parameters:parameters
                          preferredSource:-1 // Auto-select
                               completion:completion];
}

- (NSString *)executeMarketDataRequest:(DataRequestType)requestType
                            parameters:(NSDictionary *)parameters
                       preferredSource:(DataSourceType)preferredSource
                            completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    // Validate that this is market data request
    if (![self isMarketDataRequestType:requestType]) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"This is not a market data request type. Use executeAccountDataRequest or executeTradingRequest."}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
        return nil;
    }
    
    NSString *requestID = [self generateRequestID];
    self.activeRequests[requestID] = parameters;
    
    NSLog(@"📈 DownloadManager: Execute MARKET DATA request type:%ld preferredSource:%ld requestID:%@",
          (long)requestType, (long)preferredSource, requestID);
    
    dispatch_async(self.dataSourceQueue, ^{
        NSArray<DataSourceInfo *> *availableSources = [self getAvailableSourcesForRequestType:requestType
                                                                               preferredSource:preferredSource];
        
        if (availableSources.count == 0) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:503
                                             userInfo:@{NSLocalizedDescriptionKey: @"No data sources available for this request type"}];
            [self.activeRequests removeObjectForKey:requestID];
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

#pragma mark - UNIFIED CONVENIENCE METHODS for Market Data

- (NSString *)fetchQuoteForSymbol:(NSString *)symbol
                       completion:(void (^)(id quote, DataSourceType usedSource, NSError *error))completion {
    NSDictionary *parameters = @{@"symbol": symbol};
    
    return [self executeMarketDataRequest:DataRequestTypeQuote
                               parameters:parameters
                               completion:completion];
}

- (NSString *)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                         completion:(void (^)(NSDictionary *quotes, DataSourceType usedSource, NSError *error))completion {
    NSDictionary *parameters = @{@"symbols": symbols};
    
    return [self executeMarketDataRequest:DataRequestTypeBatchQuotes
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
    
    return [self executeMarketDataRequest:DataRequestTypeHistoricalBars
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
    
    return [self executeMarketDataRequest:DataRequestTypeHistoricalBars
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
    
    return [self executeMarketDataRequest:listType // Use the specific list type
                               parameters:[requestParams copy]
                               completion:completion];
}

#pragma mark - Helper Methods for Market Data Execution

/**
 * 📈 Classification: Check if request type is Market Data (allows automatic routing)
 */
- (BOOL)isMarketDataRequestType:(DataRequestType)requestType {
    switch (requestType) {
        // Core market data (routing OK)
        case DataRequestTypeQuote:
        case DataRequestTypeBatchQuotes:
        case DataRequestTypeHistoricalBars:
        case DataRequestTypeOrderBook:
        case DataRequestTypeTimeSales:
        case DataRequestTypeOptionChain:
        case DataRequestTypeNews:
        case DataRequestTypeFundamentals:
            
        // Market lists and screeners (routing OK)
        case DataRequestTypeMarketList:
        case DataRequestTypeTopGainers:
        case DataRequestTypeTopLosers:
        case DataRequestTypeETFList:
        case DataRequestType52WeekHigh:
        case DataRequestType52WeekLow:
        case DataRequestTypeStocksList:
        case DataRequestTypeEarningsCalendar:
        case DataRequestTypeEarningsSurprise:
        case DataRequestTypeInstitutionalTx:
        case DataRequestTypePMMovers:
            
        // Company specific data (routing OK)
        case DataRequestTypeCompanyNews:
        case DataRequestTypePressReleases:
        case DataRequestTypeFinancials:
        case DataRequestTypePEGRatio:
        case DataRequestTypeShortInterest:
        case DataRequestTypeInsiderTrades:
        case DataRequestTypeInstitutional:
        case DataRequestTypeSECFilings:
        case DataRequestTypeRevenue:
        case DataRequestTypePriceTarget:
        case DataRequestTypeRatings:
        case DataRequestTypeEarningsDate:
        case DataRequestTypeEPS:
        case DataRequestTypeEarningsForecast:
        case DataRequestTypeAnalystMomentum:
            
        // External data sources (routing OK)
        case DataRequestTypeFinvizStatements:
        case DataRequestTypeZacksCharts:
        case DataRequestTypeOpenInsider:
            return YES;
            
        default:
            return NO; // Account data, trading operations not allowed here
    }
}

/**
 * 📊 Get available sources for Market Data with automatic priority sorting
 */
- (NSArray<DataSourceInfo *> *)getAvailableSourcesForRequestType:(DataRequestType)requestType
                                                  preferredSource:(DataSourceType)preferredSource {
    NSMutableArray<DataSourceInfo *> *availableSources = [NSMutableArray array];
    
    // First add preferred source if specified and supports the request type
    if (preferredSource != -1) {
        DataSourceInfo *preferredSourceInfo = self.dataSources[@(preferredSource)];
        if (preferredSourceInfo && [self dataSourceSupportsRequestType:preferredSourceInfo requestType:requestType]) {
            [availableSources addObject:preferredSourceInfo];
        }
    }
    
    // Then add other available sources sorted by priority (excluding preferred source)
    NSArray<DataSourceInfo *> *allSources = [self.dataSources.allValues
                                              sortedArrayUsingComparator:^NSComparisonResult(DataSourceInfo *obj1, DataSourceInfo *obj2) {
        // Lower priority number first (1 = highest priority, 100 = lowest)
        if (obj1.priority < obj2.priority) return NSOrderedAscending;
        if (obj1.priority > obj2.priority) return NSOrderedDescending;
        
        // If same priority, prefer source with fewer recent failures
        if (obj1.failureCount < obj2.failureCount) return NSOrderedAscending;
        if (obj1.failureCount > obj2.failureCount) return NSOrderedDescending;
        
        return NSOrderedSame;
    }];
    
    
    for (DataSourceInfo *sourceInfo in allSources) {
        // Skip if already added as preferred source
        if (preferredSource != -1 && sourceInfo.type == preferredSource) {
            continue;
        }
        
        // Only add if connected and supports request type
        if (sourceInfo.isConnected && [self dataSourceSupportsRequestType:sourceInfo requestType:requestType]) {
            [availableSources addObject:sourceInfo];
        }
    }
    
    NSLog(@"📊 DownloadManager: Found %lu available sources for request type %ld",
          (unsigned long)availableSources.count, (long)requestType);
    
    return availableSources;
}

/**
 * 🔍 Check if DataSource supports specific request type
 */
- (BOOL)dataSourceSupportsRequestType:(DataSourceInfo *)sourceInfo requestType:(DataRequestType)requestType {
    DataSourceCapabilities capabilities = sourceInfo.dataSource.capabilities;
    
    switch (requestType) {
        case DataRequestTypeQuote:
        case DataRequestTypeBatchQuotes:
            return (capabilities & DataSourceCapabilityQuotes) != 0;
            
        case DataRequestTypeHistoricalBars:
            return (capabilities & DataSourceCapabilityHistoricalData) != 0;
            
        case DataRequestTypeOrderBook:
            return (capabilities & DataSourceCapabilityLevel2Data) != 0;
            
        case DataRequestTypeTopGainers:
        case DataRequestTypeTopLosers:
        case DataRequestTypeETFList:
        case DataRequestType52WeekHigh:
        case DataRequestType52WeekLow:
        case DataRequestTypeMarketList:
        case DataRequestTypeStocksList:
        case DataRequestTypeEarningsCalendar:
        case DataRequestTypePMMovers:
            return (capabilities & DataSourceCapabilityMarketLists) != 0;
            
        case DataRequestTypeFundamentals:
        case DataRequestTypeFinancials:
        case DataRequestTypePEGRatio:
        case DataRequestTypeRevenue:
        case DataRequestTypeEPS:
        case DataRequestTypeEarningsForecast:
            return (capabilities & DataSourceCapabilityFundamentals) != 0;
            
        case DataRequestTypeNews:
        case DataRequestTypeCompanyNews:
        case DataRequestTypePressReleases:
        case DataRequestTypeGoogleFinanceNews:      // NEW
               case DataRequestTypeSECFilings:             // NEW
               case DataRequestTypeYahooFinanceNews:       // NEW
               case DataRequestTypeSeekingAlphaNews:       // NEW
            return (capabilities & DataSourceCapabilityNews) != 0;
            
        case DataRequestTypeOptionChain:
            return (capabilities & DataSourceCapabilityOptions) != 0;
            
        default:
            // For other types, assume basic quote capability is enough
            return (capabilities & DataSourceCapabilityQuotes) != 0;
    }
}

#pragma mark - Internal Market Data Request Execution

/**
 * 🔄 Execute market data request with automatic fallback
 */
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
    
    NSLog(@"📡 DownloadManager: Trying %@ for market data request type %ld (attempt %ld/%lu)",
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
            
        case DataRequestTypeFundamentals:
            [self executeFundamentalsRequest:parameters
                              withDataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                   requestID:requestID
                                  completion:completion];
            break;
        case DataRequestTypeNews:
             case DataRequestTypeCompanyNews:
             case DataRequestTypePressReleases:
             case DataRequestTypeGoogleFinanceNews:
             case DataRequestTypeSECFilings:
             case DataRequestTypeYahooFinanceNews:
             case DataRequestTypeSeekingAlphaNews:
                 [self executeNewsRequest:parameters
                           withDataSource:dataSource
                               sourceInfo:sourceInfo
                                  sources:sources
                              sourceIndex:sourceIndex
                                requestID:requestID
                              requestType:requestType
                               completion:completion];
                 break;
            
        default: {
            NSError *unsupportedError = [NSError errorWithDomain:@"DownloadManager"
                                                            code:400
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Unsupported market data request type"}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, unsupportedError);
            });
            break;
        }
    }
}

#pragma mark - Specific Market Data Request Type Implementations


- (void)executeQuoteRequest:(NSDictionary *)parameters
             withDataSource:(id<DataSource>)dataSource
                 sourceInfo:(DataSourceInfo *)sourceInfo
                    sources:(NSArray<DataSourceInfo *> *)sources
                sourceIndex:(NSInteger)sourceIndex
                  requestID:(NSString *)requestID
                 completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    
    if ([dataSource respondsToSelector:@selector(fetchQuoteForSymbol:completion:)]) {
        [dataSource fetchQuoteForSymbol:symbol completion:^(id quote, NSError *error) {
            [self handleGenericResponse:quote
                                   error:error
                              dataSource:dataSource
                              sourceInfo:sourceInfo
                                 sources:sources
                             sourceIndex:sourceIndex
                              parameters:parameters
                               requestID:requestID
                             requestType:DataRequestTypeQuote
                              completion:completion];
        }];
    } else {
        // DataSource doesn't support quotes - try next
        [self executeRequestWithSources:sources
                             requestType:DataRequestTypeQuote
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    }
}

- (void)executeBatchQuotesRequest:(NSDictionary *)parameters
                   withDataSource:(id<DataSource>)dataSource
                       sourceInfo:(DataSourceInfo *)sourceInfo
                          sources:(NSArray<DataSourceInfo *> *)sources
                      sourceIndex:(NSInteger)sourceIndex
                        requestID:(NSString *)requestID
                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSArray *symbols = parameters[@"symbols"];
    
    if ([dataSource respondsToSelector:@selector(fetchQuotesForSymbols:completion:)]) {
        [dataSource fetchQuotesForSymbols:symbols completion:^(NSDictionary *quotes, NSError *error) {
            [self handleGenericResponse:quotes
                                   error:error
                              dataSource:dataSource
                              sourceInfo:sourceInfo
                                 sources:sources
                             sourceIndex:sourceIndex
                              parameters:parameters
                               requestID:requestID
                             requestType:DataRequestTypeBatchQuotes
                              completion:completion];
        }];
    } else {
        // DataSource doesn't support batch quotes - try next
        [self executeRequestWithSources:sources
                             requestType:DataRequestTypeBatchQuotes
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    }
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
    
    if ([dataSource respondsToSelector:@selector(fetchHistoricalDataForSymbol:timeframe:startDate:endDate:needExtendedHours:completion:)]) {
        if (parameters[@"startDate"] && parameters[@"endDate"]) {
            // Date range version
            NSDate *startDate = parameters[@"startDate"];
            NSDate *endDate = parameters[@"endDate"];
            
            [dataSource fetchHistoricalDataForSymbol:symbol
                                           timeframe:timeframe
                                           startDate:startDate
                                             endDate:endDate
                                   needExtendedHours:needExtendedHours
                                          completion:^(NSArray *bars, NSError *error) {
                [self handleGenericResponse:bars
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:DataRequestTypeHistoricalBars
                                  completion:completion];
            }];
        } else if (parameters[@"barCount"]) {
            // Bar count version
            NSInteger barCount = [parameters[@"barCount"] integerValue];
            
            if ([dataSource respondsToSelector:@selector(fetchHistoricalDataForSymbol:timeframe:barCount:needExtendedHours:completion:)]) {
                [dataSource fetchHistoricalDataForSymbol:symbol
                                               timeframe:timeframe
                                                barCount:barCount
                                       needExtendedHours:needExtendedHours
                                              completion:^(NSArray *bars, NSError *error) {
                    [self handleGenericResponse:bars
                                           error:error
                                      dataSource:dataSource
                                      sourceInfo:sourceInfo
                                         sources:sources
                                     sourceIndex:sourceIndex
                                      parameters:parameters
                                       requestID:requestID
                                     requestType:DataRequestTypeHistoricalBars
                                      completion:completion];
                }];
            } else {
                // DataSource doesn't support bar count version - try next
                [self executeRequestWithSources:sources
                                     requestType:DataRequestTypeHistoricalBars
                                      parameters:parameters
                                       requestID:requestID
                                     sourceIndex:sourceIndex + 1
                                      completion:completion];
            }
        }
    } else {
        // DataSource doesn't support historical data - try next
        [self executeRequestWithSources:sources
                             requestType:DataRequestTypeHistoricalBars
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    }
}

#pragma mark - Utility Methods

/**
 * 🆔 Generate unique request ID
 */
- (NSString *)generateRequestID {
    return [[NSUUID UUID] UUIDString];
}

/**
 * 📝 Record success for source (improve priority)
 */
- (void)recordSuccessForSource:(DataSourceInfo *)sourceInfo {
    sourceInfo.failureCount = MAX(0, sourceInfo.failureCount - 1);
    sourceInfo.lastFailureTime = nil;
}

/**
 * ❌ Record failure for source (decrease priority)
 */
- (void)recordFailureForSource:(DataSourceInfo *)sourceInfo {
    sourceInfo.failureCount++;
    sourceInfo.lastFailureTime = [NSDate date];
}


//
//  🛡️ SECURITY CRITICAL: Account Data & Trading Operations
//  - NO automatic routing
//  - Specific DataSource REQUIRED
//  - NO fallback to prevent data mixing between brokers
//


#pragma mark - 🛡️ ACCOUNT DATA REQUESTS (Specific DataSource REQUIRED)

/**
 * 🛡️ ACCOUNT DATA security logic: NO automatic routing, specific source required
 */
- (NSString *)executeAccountDataRequest:(DataRequestType)requestType
                             parameters:(NSDictionary *)parameters
                         requiredSource:(DataSourceType)requiredSource
                             completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    // Validate that this is account data request
    if (![self isAccountDataRequestType:requestType]) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"This is not an account data request type. Use executeMarketDataRequest for market data."}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
        return nil;
    }
    
    // Validate required parameters
    NSError *validationError = [self validateAccountDataParameters:parameters requestType:requestType];
    if (validationError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, validationError);
        });
        return nil;
    }
    
    NSString *requestID = [self generateRequestID];
    self.activeRequests[requestID] = parameters;
    
    NSLog(@"🛡️ DownloadManager: Execute ACCOUNT DATA request type:%ld requiredSource:%ld requestID:%@",
          (long)requestType, (long)requiredSource, requestID);
    
    dispatch_async(self.dataSourceQueue, ^{
        // Get ONLY the required source - NO fallback for account data
        DataSourceInfo *sourceInfo = self.dataSources[@(requiredSource)];
        
        if (!sourceInfo) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:404
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Required DataSource %ld is not registered", (long)requiredSource]}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            return;
        }
        
        if (!sourceInfo.isConnected) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:503
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Required DataSource %@ is not connected", sourceInfo.dataSource.sourceName]}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            return;
        }
        
        if (![self dataSourceSupportsAccountRequestType:sourceInfo requestType:requestType]) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:501
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"DataSource %@ does not support account request type %ld", sourceInfo.dataSource.sourceName, (long)requestType]}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            return;
        }
        
        // Execute account data request - NO fallback, single source only
        [self executeAccountDataRequestOnSpecificSource:requestType
                                              parameters:parameters
                                              sourceInfo:sourceInfo
                                               requestID:requestID
                                              completion:completion];
    });
    
    return requestID;
}

#pragma mark - 🚨 TRADING OPERATIONS (Specific DataSource REQUIRED)

/**
 * 🚨 TRADING OPERATIONS security logic: Most critical - exact broker required, NEVER fallback
 */
- (NSString *)executeTradingRequest:(DataRequestType)requestType
                         parameters:(NSDictionary *)parameters
                     requiredSource:(DataSourceType)requiredSource
                         completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    // Validate that this is trading request
    if (![self isTradingRequestType:requestType]) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"This is not a trading request type. Use executeAccountDataRequest for account data."}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
        return nil;
    }
    
    // Extra validation for trading operations
    NSError *validationError = [self validateTradingParameters:parameters requestType:requestType];
    if (validationError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, validationError);
        });
        return nil;
    }
    
    NSString *requestID = [self generateRequestID];
    self.activeRequests[requestID] = parameters;
    
    NSLog(@"🚨 DownloadManager: Execute TRADING request type:%ld requiredSource:%ld requestID:%@",
          (long)requestType, (long)requiredSource, requestID);
    
    dispatch_async(self.dataSourceQueue, ^{
        // Get ONLY the required source - ABSOLUTELY NO fallback for trading
        DataSourceInfo *sourceInfo = self.dataSources[@(requiredSource)];
        
        if (!sourceInfo) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:404
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"🚨 CRITICAL: Trading DataSource %ld is not registered", (long)requiredSource]}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            return;
        }
        
        if (!sourceInfo.isConnected) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:503
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"🚨 CRITICAL: Trading DataSource %@ is not connected", sourceInfo.dataSource.sourceName]}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            return;
        }
        
        if (![self dataSourceSupportsTradingRequestType:sourceInfo requestType:requestType]) {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:501
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"🚨 CRITICAL: Trading DataSource %@ does not support trading request type %ld", sourceInfo.dataSource.sourceName, (long)requestType]}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            return;
        }
        
        // Execute trading request - NO fallback, single source only, extra logging
        [self executeTradingRequestOnSpecificSource:requestType
                                         parameters:parameters
                                         sourceInfo:sourceInfo
                                          requestID:requestID
                                         completion:completion];
    });
    
    return requestID;
}

#pragma mark - CONVENIENCE METHODS for Account Data (🛡️ Require DataSource)

- (NSString *)fetchPositionsForAccount:(NSString *)accountId
                        fromDataSource:(DataSourceType)requiredSource
                            completion:(void (^)(NSArray *positions, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{@"accountId": accountId};
    
    return [self executeAccountDataRequest:DataRequestTypePositions
                                parameters:parameters
                            requiredSource:requiredSource
                                completion:completion];
}

- (NSString *)fetchOrdersForAccount:(NSString *)accountId
                     fromDataSource:(DataSourceType)requiredSource
                         completion:(void (^)(NSArray *orders, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{@"accountId": accountId};
    
    return [self executeAccountDataRequest:DataRequestTypeOrders
                                parameters:parameters
                            requiredSource:requiredSource
                                completion:completion];
}

- (NSString *)fetchAccountDetails:(NSString *)accountId
                   fromDataSource:(DataSourceType)requiredSource
                       completion:(void (^)(NSDictionary *details, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{@"accountId": accountId};
    
    return [self executeAccountDataRequest:DataRequestTypeAccountInfo
                                parameters:parameters
                            requiredSource:requiredSource
                                completion:completion];
}

#pragma mark - CONVENIENCE METHODS for Trading (🚨 Require DataSource)

- (NSString *)placeOrder:(NSDictionary *)orderData
              forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
               completion:(void (^)(NSString *orderId, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{
        @"accountId": accountId,
        @"orderData": orderData
    };
    
    return [self executeTradingRequest:DataRequestTypePlaceOrder
                            parameters:parameters
                        requiredSource:requiredSource
                            completion:completion];
}

- (NSString *)cancelOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
               completion:(void (^)(BOOL success, DataSourceType usedSource, NSError *error))completion {
    
    NSDictionary *parameters = @{
        @"accountId": accountId,
        @"orderId": orderId
    };
    
    // 🔧 WRAPPER: Converte da id a BOOL per il completion block
    return [self executeTradingRequest:DataRequestTypeCancelOrder
                            parameters:parameters
                        requiredSource:requiredSource
                            completion:^(id result, DataSourceType usedSource, NSError *error) {
        BOOL success = NO;
        
        if (!error && result) {
            if ([result isKindOfClass:[NSNumber class]]) {
                success = [(NSNumber *)result boolValue];
            } else if ([result respondsToSelector:@selector(boolValue)]) {
                success = [result boolValue];
            } else {
                // Se non è un numero, considera success = YES se non c'è errore
                success = YES;
            }
        }
        
        if (completion) {
            completion(success, usedSource, error);
        }
    }];
}

#pragma mark - Security Classification Methods

/**
 * 🛡️ Classification: Check if request type is Account Data (requires specific source)
 */
- (BOOL)isAccountDataRequestType:(DataRequestType)requestType {
    switch (requestType) {
        case DataRequestTypePositions:
        case DataRequestTypeOrders:
        case DataRequestTypeAccountInfo:
        case DataRequestTypeAccounts: // List of accounts for specific broker
            return YES;
            
        default:
            return NO;
    }
}

/**
 * 🚨 Classification: Check if request type is Trading Operation (most critical)
 */
- (BOOL)isTradingRequestType:(DataRequestType)requestType {
    switch (requestType) {
        case DataRequestTypePlaceOrder:
        case DataRequestTypeCancelOrder:
        case DataRequestTypeModifyOrder:
            return YES;
            
        default:
            return NO;
    }
}

/**
 * 🔍 Check if DataSource supports account data request type
 */
- (BOOL)dataSourceSupportsAccountRequestType:(DataSourceInfo *)sourceInfo requestType:(DataRequestType)requestType {
    DataSourceCapabilities capabilities = sourceInfo.dataSource.capabilities;
    
    switch (requestType) {
        case DataRequestTypePositions:
        case DataRequestTypeOrders:
        case DataRequestTypeAccountInfo:
        case DataRequestTypeAccounts:
            return (capabilities & DataSourceCapabilityPortfolioData) != 0;
            
        default:
            return NO;
    }
}

/**
 * 🔍 Check if DataSource supports trading request type
 */
- (BOOL)dataSourceSupportsTradingRequestType:(DataSourceInfo *)sourceInfo requestType:(DataRequestType)requestType {
    DataSourceCapabilities capabilities = sourceInfo.dataSource.capabilities;
    
    switch (requestType) {
        case DataRequestTypePlaceOrder:
        case DataRequestTypeCancelOrder:
        case DataRequestTypeModifyOrder:
            return (capabilities & DataSourceCapabilityTrading) != 0;
            
        default:
            return NO;
    }
}

#pragma mark - Parameter Validation

/**
 * ✅ Validate account data parameters
 */
- (NSError *)validateAccountDataParameters:(NSDictionary *)parameters requestType:(DataRequestType)requestType {
    switch (requestType) {
        case DataRequestTypePositions:
        case DataRequestTypeOrders:
        case DataRequestTypeAccountInfo: {
            NSString *accountId = parameters[@"accountId"];
            if (!accountId || accountId.length == 0) {
                return [NSError errorWithDomain:@"DownloadManager"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey: @"accountId is required for account data requests"}];
            }
            break;
        }
        case DataRequestTypeAccounts:
            // No specific parameters required for accounts list
            break;
            
        default:
            return [NSError errorWithDomain:@"DownloadManager"
                                       code:400
                                   userInfo:@{NSLocalizedDescriptionKey: @"Invalid account data request type"}];
    }
    
    return nil;
}

/**
 * ✅ Validate trading parameters (extra strict)
 */
- (NSError *)validateTradingParameters:(NSDictionary *)parameters requestType:(DataRequestType)requestType {
    NSString *accountId = parameters[@"accountId"];
    if (!accountId || accountId.length == 0) {
        return [NSError errorWithDomain:@"DownloadManager"
                                   code:400
                               userInfo:@{NSLocalizedDescriptionKey: @"🚨 CRITICAL: accountId is required for trading operations"}];
    }
    
    switch (requestType) {
        case DataRequestTypePlaceOrder: {
            NSDictionary *orderData = parameters[@"orderData"];
            if (!orderData) {
                return [NSError errorWithDomain:@"DownloadManager"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey: @"🚨 CRITICAL: orderData is required for place order"}];
            }
            break;
        }
        case DataRequestTypeCancelOrder: {
            NSString *orderId = parameters[@"orderId"];
            if (!orderId || orderId.length == 0) {
                return [NSError errorWithDomain:@"DownloadManager"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey: @"🚨 CRITICAL: orderId is required for cancel order"}];
            }
            break;
        }
        default:
            return [NSError errorWithDomain:@"DownloadManager"
                                       code:400
                                   userInfo:@{NSLocalizedDescriptionKey: @"🚨 CRITICAL: Invalid trading request type"}];
    }
    
    return nil;
}

#pragma mark - Single Source Request Execution (Account & Trading)

/**
 * 🛡️ Execute account data request on specific source (NO fallback)
 */
- (void)executeAccountDataRequestOnSpecificSource:(DataRequestType)requestType
                                       parameters:(NSDictionary *)parameters
                                       sourceInfo:(DataSourceInfo *)sourceInfo
                                        requestID:(NSString *)requestID
                                       completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    id<DataSource> dataSource = sourceInfo.dataSource;
    
    NSLog(@"🛡️ DownloadManager: Executing account data on %@ for request type %ld",
          dataSource.sourceName, (long)requestType);
    
    switch (requestType) {
        case DataRequestTypePositions:
            [self executePositionsRequestOnSource:parameters
                                        dataSource:dataSource
                                        sourceInfo:sourceInfo
                                         requestID:requestID
                                        completion:completion];
            break;
            
        case DataRequestTypeOrders:
            [self executeOrdersRequestOnSource:parameters
                                     dataSource:dataSource
                                     sourceInfo:sourceInfo
                                      requestID:requestID
                                     completion:completion];
            break;
            
        case DataRequestTypeAccountInfo:
            [self executeAccountInfoRequestOnSource:parameters
                                          dataSource:dataSource
                                          sourceInfo:sourceInfo
                                           requestID:requestID
                                          completion:completion];
            break;
            
        case DataRequestTypeAccounts:
            [self executeAccountsListRequestOnSource:parameters
                                           dataSource:dataSource
                                           sourceInfo:sourceInfo
                                            requestID:requestID
                                           completion:completion];
            break;
            
        default: {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"Unsupported account data request type"}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            break;
        }
    }
}

/**
 * 🚨 Execute trading request on specific source (NO fallback, extra logging)
 */
- (void)executeTradingRequestOnSpecificSource:(DataRequestType)requestType
                                   parameters:(NSDictionary *)parameters
                                   sourceInfo:(DataSourceInfo *)sourceInfo
                                    requestID:(NSString *)requestID
                                   completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    id<DataSource> dataSource = sourceInfo.dataSource;
    NSString *accountId = parameters[@"accountId"];
    
    NSLog(@"🚨 DownloadManager: TRADING OPERATION - Executing on %@ for account %@ request type %ld",
          dataSource.sourceName, accountId, (long)requestType);
    
    switch (requestType) {
        case DataRequestTypePlaceOrder:
            [self executePlaceOrderRequestOnSource:parameters
                                         dataSource:dataSource
                                         sourceInfo:sourceInfo
                                          requestID:requestID
                                         completion:completion];
            break;
            
        case DataRequestTypeCancelOrder:
            [self executeCancelOrderRequestOnSource:parameters
                                          dataSource:dataSource
                                          sourceInfo:sourceInfo
                                           requestID:requestID
                                          completion:completion];
            break;
            
        default: {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"🚨 CRITICAL: Unsupported trading request type"}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
            break;
        }
    }
}

#pragma mark - Specific Account Data Request Implementations

- (void)executePositionsRequestOnSource:(NSDictionary *)parameters
                             dataSource:(id<DataSource>)dataSource
                             sourceInfo:(DataSourceInfo *)sourceInfo
                              requestID:(NSString *)requestID
                             completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    
    if ([dataSource respondsToSelector:@selector(fetchPositionsForAccount:completion:)]) {
        [dataSource fetchPositionsForAccount:accountId completion:^(NSArray *positions, NSError *error) {
            [self handleSecureResponse:positions
                                 error:error
                            dataSource:dataSource
                            sourceInfo:sourceInfo
                            parameters:parameters
                             requestID:requestID
                           requestType:DataRequestTypePositions
                            completion:completion];
        }];
    } else {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"DataSource %@ does not support positions", dataSource.sourceName]}];
        [self.activeRequests removeObjectForKey:requestID];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
    }
}

- (void)executeOrdersRequestOnSource:(NSDictionary *)parameters
                          dataSource:(id<DataSource>)dataSource
                          sourceInfo:(DataSourceInfo *)sourceInfo
                           requestID:(NSString *)requestID
                          completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    
    if ([dataSource respondsToSelector:@selector(fetchOrdersForAccount:completion:)]) {
        [dataSource fetchOrdersForAccount:accountId completion:^(NSArray *orders, NSError *error) {
            [self handleSecureResponse:orders
                                 error:error
                            dataSource:dataSource
                            sourceInfo:sourceInfo
                            parameters:parameters
                             requestID:requestID
                           requestType:DataRequestTypeOrders
                            completion:completion];
        }];
    } else {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"DataSource %@ does not support orders", dataSource.sourceName]}];
        [self.activeRequests removeObjectForKey:requestID];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
    }
}

- (void)executeAccountInfoRequestOnSource:(NSDictionary *)parameters
                               dataSource:(id<DataSource>)dataSource
                               sourceInfo:(DataSourceInfo *)sourceInfo
                                requestID:(NSString *)requestID
                               completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    
    if (accountId) {
        // Request for specific account details
        if ([dataSource respondsToSelector:@selector(fetchAccountDetails:completion:)]) {
            [dataSource fetchAccountDetails:accountId completion:^(NSDictionary *details, NSError *error) {
                [self handleSecureResponse:details
                                     error:error
                                dataSource:dataSource
                                sourceInfo:sourceInfo
                                parameters:parameters
                                 requestID:requestID
                               requestType:DataRequestTypeAccountInfo
                                completion:completion];
            }];
        } else {
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:501
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"DataSource %@ does not support account details", dataSource.sourceName]}];
            [self.activeRequests removeObjectForKey:requestID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error);
            });
        }
    }
}

- (void)executeAccountsListRequestOnSource:(NSDictionary *)parameters
                                dataSource:(id<DataSource>)dataSource
                                sourceInfo:(DataSourceInfo *)sourceInfo
                                 requestID:(NSString *)requestID
                                completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if ([dataSource respondsToSelector:@selector(fetchAccountsWithCompletion:)]) {
        [dataSource fetchAccountsWithCompletion:^(NSArray *accounts, NSError *error) {
            [self handleSecureResponse:accounts
                                 error:error
                            dataSource:dataSource
                            sourceInfo:sourceInfo
                            parameters:parameters
                             requestID:requestID
                           requestType:DataRequestTypeAccounts
                            completion:completion];
        }];
    } else {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"DataSource %@ does not support accounts list", dataSource.sourceName]}];
        [self.activeRequests removeObjectForKey:requestID];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
    }
}

#pragma mark - Specific Trading Request Implementations

- (void)executePlaceOrderRequestOnSource:(NSDictionary *)parameters
                              dataSource:(id<DataSource>)dataSource
                              sourceInfo:(DataSourceInfo *)sourceInfo
                               requestID:(NSString *)requestID
                              completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    NSDictionary *orderData = parameters[@"orderData"];
    
    NSLog(@"🚨 DownloadManager: PLACE ORDER - Account: %@ DataSource: %@ OrderData: %@",
          accountId, dataSource.sourceName, orderData);
    
    if ([dataSource respondsToSelector:@selector(placeOrderForAccount:orderData:completion:)]) {
        [dataSource placeOrderForAccount:accountId orderData:orderData completion:^(NSString *orderId, NSError *error) {
            if (error) {
                NSLog(@"❌ DownloadManager: PLACE ORDER FAILED - Account: %@ Error: %@", accountId, error.localizedDescription);
            } else {
                NSLog(@"✅ DownloadManager: PLACE ORDER SUCCESS - Account: %@ OrderID: %@", accountId, orderId);
            }
            
            [self handleSecureResponse:orderId
                                 error:error
                            dataSource:dataSource
                            sourceInfo:sourceInfo
                            parameters:parameters
                             requestID:requestID
                           requestType:DataRequestTypePlaceOrder
                            completion:completion];
        }];
    } else {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"🚨 CRITICAL: DataSource %@ does not support place order", dataSource.sourceName]}];
        [self.activeRequests removeObjectForKey:requestID];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
    }
}

- (void)executeCancelOrderRequestOnSource:(NSDictionary *)parameters
                               dataSource:(id<DataSource>)dataSource
                               sourceInfo:(DataSourceInfo *)sourceInfo
                                requestID:(NSString *)requestID
                               completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *accountId = parameters[@"accountId"];
    NSString *orderId = parameters[@"orderId"];
    
    NSLog(@"🚨 DownloadManager: CANCEL ORDER - Account: %@ OrderID: %@ DataSource: %@",
          accountId, orderId, dataSource.sourceName);
    
    if ([dataSource respondsToSelector:@selector(cancelOrderForAccount:orderId:completion:)]) {
        [dataSource cancelOrderForAccount:accountId orderId:orderId completion:^(BOOL success, NSError *error) {
            if (error) {
                NSLog(@"❌ DownloadManager: CANCEL ORDER FAILED - Account: %@ OrderID: %@ Error: %@", accountId, orderId, error.localizedDescription);
            } else {
                NSLog(@"✅ DownloadManager: CANCEL ORDER SUCCESS - Account: %@ OrderID: %@ Success: %@", accountId, orderId, @(success));
            }
            
            [self handleSecureResponse:@(success)
                                 error:error
                            dataSource:dataSource
                            sourceInfo:sourceInfo
                            parameters:parameters
                             requestID:requestID
                           requestType:DataRequestTypeCancelOrder
                            completion:completion];
        }];
    } else {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:501
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"🚨 CRITICAL: DataSource %@ does not support cancel order", dataSource.sourceName]}];
        [self.activeRequests removeObjectForKey:requestID];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, -1, error);
        });
    }
}

#pragma mark - Market Data Request Implementations (continued from Part 1)

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
        [dataSource fetchOrderBookForSymbol:symbol depth:depth completion:^(NSDictionary *orderBook, NSError *error) {
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

- (void)executeFundamentalsRequest:(NSDictionary *)parameters
                    withDataSource:(id<DataSource>)dataSource
                        sourceInfo:(DataSourceInfo *)sourceInfo
                           sources:(NSArray<DataSourceInfo *> *)sources
                       sourceIndex:(NSInteger)sourceIndex
                         requestID:(NSString *)requestID
                        completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    
    if ([dataSource respondsToSelector:@selector(fetchFundamentalsForSymbol:completion:)]) {
        [dataSource fetchFundamentalsForSymbol:symbol completion:^(NSDictionary *fundamentals, NSError *error) {
            [self handleGenericResponse:fundamentals
                                   error:error
                              dataSource:dataSource
                              sourceInfo:sourceInfo
                                 sources:sources
                             sourceIndex:sourceIndex
                              parameters:parameters
                               requestID:requestID
                             requestType:DataRequestTypeFundamentals
                              completion:completion];
        }];
    } else {
        // DataSource doesn't support fundamentals - try next
        [self executeRequestWithSources:sources
                             requestType:DataRequestTypeFundamentals
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    }
}

#pragma mark - Response Handling

/**
 * 📈 Handle market data response with fallback (from Part 1)
 */
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
        NSLog(@"❌ DownloadManager: %@ failed for market data request type %ld: %@", dataSource.sourceName, (long)requestType, error.localizedDescription);
        [self recordFailureForSource:sourceInfo];
        
        // Try next source (fallback for market data)
        [self executeRequestWithSources:sources
                             requestType:requestType
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
    } else {
        NSLog(@"✅ DownloadManager: %@ succeeded for market data request type %ld", dataSource.sourceName, (long)requestType);
        [self recordSuccessForSource:sourceInfo];
        [self.activeRequests removeObjectForKey:requestID];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result, dataSource.sourceType, nil);
        });
    }
}

/**
 * 🛡️ Handle secure response (NO fallback for account/trading data)
 */
- (void)handleSecureResponse:(id)result
                       error:(NSError *)error
                  dataSource:(id<DataSource>)dataSource
                  sourceInfo:(DataSourceInfo *)sourceInfo
                  parameters:(NSDictionary *)parameters
                   requestID:(NSString *)requestID
                 requestType:(DataRequestType)requestType
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    if (!self.activeRequests[requestID]) {
        return; // Request was cancelled
    }
    
    [self.activeRequests removeObjectForKey:requestID];
    
    if (error) {
        NSLog(@"❌ DownloadManager: 🛡️ %@ failed for secure request type %ld: %@ (NO fallback)",
              dataSource.sourceName, (long)requestType, error.localizedDescription);
        [self recordFailureForSource:sourceInfo];
        
        // NO fallback for account/trading data - return error immediately
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, dataSource.sourceType, error);
        });
    } else {
        NSLog(@"✅ DownloadManager: 🛡️ %@ succeeded for secure request type %ld",
              dataSource.sourceName, (long)requestType);
        [self recordSuccessForSource:sourceInfo];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result, dataSource.sourceType, nil);
        });
    }
}

#pragma mark - Request Cancellation

- (void)cancelRequest:(NSString *)requestID {
    if (requestID && self.activeRequests[requestID]) {
        [self.activeRequests removeObjectForKey:requestID];
        NSLog(@"🚫 DownloadManager: Cancelled request %@", requestID);
    }
}

- (void)cancelAllRequests {
    NSUInteger cancelledCount = self.activeRequests.count;
    [self.activeRequests removeAllObjects];
    NSLog(@"🚫 DownloadManager: Cancelled all %lu active requests", (unsigned long)cancelledCount);
}

#pragma mark - news request

- (void)executeNewsRequest:(NSDictionary *)parameters
            withDataSource:(id<DataSource>)dataSource
                sourceInfo:(DataSourceInfo *)sourceInfo
                   sources:(NSArray<DataSourceInfo *> *)sources
               sourceIndex:(NSInteger)sourceIndex
                 requestID:(NSString *)requestID
               requestType:(DataRequestType)requestType
                completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion {
    
    NSString *symbol = parameters[@"symbol"];
    NSNumber *limitParam = parameters[@"limit"];
    NSInteger limit = limitParam ? [limitParam integerValue] : 50; // Default limit
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required for news requests"}];
        [self handleGenericResponse:nil
                               error:error
                          dataSource:dataSource
                          sourceInfo:sourceInfo
                             sources:sources
                         sourceIndex:sourceIndex
                          parameters:parameters
                           requestID:requestID
                         requestType:requestType
                          completion:completion];
        return;
    }
    
    // Cast to OtherDataSource since only OtherDataSource supports these news methods
    if (![dataSource isKindOfClass:[OtherDataSource class]]) {
        NSLog(@"⚠️ DownloadManager: DataSource %@ doesn't support news request type %ld, trying next source",
              dataSource.sourceName, (long)requestType);
        
        // Try next source
        [self executeRequestWithSources:sources
                             requestType:requestType
                              parameters:parameters
                               requestID:requestID
                             sourceIndex:sourceIndex + 1
                              completion:completion];
        return;
    }
    
    OtherDataSource *otherDataSource = (OtherDataSource *)dataSource;
    
    // Route to specific news method based on request type
    switch (requestType) {
        case DataRequestTypeNews:
        case DataRequestTypeCompanyNews:
            // Use existing Nasdaq news method
            [otherDataSource fetchNewsForSymbol:symbol
                                           limit:limit
                                      completion:^(NSArray *news, NSError *error) {
                [self handleGenericResponse:news
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:requestType
                                  completion:completion];
            }];
            break;
            
        case DataRequestTypePressReleases:
            // Use existing Nasdaq press releases method
            [otherDataSource fetchPressReleasesForSymbol:symbol
                                                   limit:limit
                                              completion:^(NSArray *releases, NSError *error) {
                [self handleGenericResponse:releases
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:requestType
                                  completion:completion];
            }];
            break;
            
        case DataRequestTypeGoogleFinanceNews:
            // Use new Google Finance RSS method
            [otherDataSource fetchGoogleFinanceNewsForSymbol:symbol
                                                   completion:^(NSArray *news, NSError *error) {
                [self handleGenericResponse:news
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:requestType
                                  completion:completion];
            }];
            break;
            
        case DataRequestTypeSECFilings:
            // Use new SEC EDGAR method
            [otherDataSource fetchSECFilingsForSymbol:symbol
                                           completion:^(NSArray *filings, NSError *error) {
                [self handleGenericResponse:filings
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:requestType
                                  completion:completion];
            }];
            break;
            
        case DataRequestTypeYahooFinanceNews:
            // Use new Yahoo Finance RSS method
            [otherDataSource fetchYahooFinanceNewsForSymbol:symbol
                                                  completion:^(NSArray *news, NSError *error) {
                [self handleGenericResponse:news
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:requestType
                                  completion:completion];
            }];
            break;
            
        case DataRequestTypeSeekingAlphaNews:
            // Use new Seeking Alpha RSS method
            [otherDataSource fetchSeekingAlphaNewsForSymbol:symbol
                                                 completion:^(NSArray *news, NSError *error) {
                [self handleGenericResponse:news
                                       error:error
                                  dataSource:dataSource
                                  sourceInfo:sourceInfo
                                     sources:sources
                                 sourceIndex:sourceIndex
                                  parameters:parameters
                                   requestID:requestID
                                 requestType:requestType
                                  completion:completion];
            }];
            break;
            
        default:
            // Unsupported news type
            NSError *error = [NSError errorWithDomain:@"DownloadManager"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                       [NSString stringWithFormat:@"Unsupported news request type: %ld", (long)requestType]}];
            [self handleGenericResponse:nil
                                   error:error
                              dataSource:dataSource
                              sourceInfo:sourceInfo
                                 sources:sources
                             sourceIndex:sourceIndex
                              parameters:parameters
                               requestID:requestID
                             requestType:requestType
                              completion:completion];
            break;
    }
}

@end


