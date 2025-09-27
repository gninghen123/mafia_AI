//
//  YahooScreenerAPI.m
//  TradingApp
//
//  Yahoo Finance Screener API Manager Implementation
//

#import "YahooScreenerAPI.h"
#import "ScreenerWidget.h"

// Forward declarations per evitare import circolari
@class YahooScreenerResult, YahooScreenerFilter;


// ============================================================================
// CACHE ENTRY MODEL
// ============================================================================

@interface YahooScreenerCacheEntry : NSObject
@property (nonatomic, strong) NSArray<YahooScreenerResult *> *results;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSString *cacheKey;
@end

@implementation YahooScreenerCacheEntry
@end

// ============================================================================
// MAIN IMPLEMENTATION
// ============================================================================

@interface YahooScreenerAPI ()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSString *, YahooScreenerCacheEntry *> *cache;
@property (nonatomic, strong) NSArray<NSString *> *availableSectorsArray;

@end

@implementation YahooScreenerAPI

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static YahooScreenerAPI *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YahooScreenerAPI alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        // Default configuration
        _baseURL = @"https://yahoo-screener-backend-production.up.railway.app/api";
        _timeout = 30.0;
        _enableLogging = YES;
        _enableCaching = YES;
        _cacheTimeout = 60.0; // 1 minuto
        
        // Initialize session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = _timeout;
        config.timeoutIntervalForResource = _timeout * 2;
        _session = [NSURLSession sessionWithConfiguration:config];
        
        // Initialize cache
        _cache = [NSMutableDictionary dictionary];
        
        // Initialize sectors
        [self initializeAvailableSectors];
        
        [self logInfo:@"YahooScreenerAPI initialized with base URL: %@", _baseURL];
    }
    return self;
}

#pragma mark - Main Screener Methods

- (void)fetchScreenerResults:(YahooScreenerPreset)preset
                  maxResults:(NSInteger)maxResults
                  completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *_Nullable error))completion {
    
    NSString *endpoint = [self endpointForPreset:preset];
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%ld", endpoint, (long)maxResults];
    
    // Check cache first
    if ([self shouldUseCachedResult:cacheKey]) {
        YahooScreenerCacheEntry *entry = self.cache[cacheKey];
        [self logInfo:@"Returning cached results for %@", [self nameForPreset:preset]];
        completion(entry.results, nil);
        return;
    }
    
    [self logInfo:@"Fetching %@ screener results (max: %ld)", [self nameForPreset:preset], (long)maxResults];
    
    // Build request
    NSString *urlString = [NSString stringWithFormat:@"%@/%@", self.baseURL, endpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    // Request body
    NSDictionary *requestBody = @{
        @"maxResults": @(maxResults),
        @"preset": [self nameForPreset:preset]
    };
    
    [self executeRequest:request
                withBody:requestBody
                cacheKey:cacheKey
              completion:completion];
}

- (void)fetchCustomScreenerWithFilters:(NSArray<YahooScreenerFilter *> *)filters
                            maxResults:(NSInteger)maxResults
                            completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *_Nullable error))completion {
    
    NSString *cacheKey = [NSString stringWithFormat:@"custom_%lu_%ld", (unsigned long)filters.count, (long)maxResults];
    
    // Check cache
    if ([self shouldUseCachedResult:cacheKey]) {
        YahooScreenerCacheEntry *entry = self.cache[cacheKey];
        [self logInfo:@"Returning cached custom screener results"];
        completion(entry.results, nil);
        return;
    }
    
    [self logInfo:@"Fetching custom screener with %lu filters (max: %ld)", (unsigned long)filters.count, (long)maxResults];
    
    // Build request
    NSString *urlString = [NSString stringWithFormat:@"%@/screener/custom", self.baseURL];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    // Convert filters to API format
    NSMutableArray *filterArray = [NSMutableArray array];
    for (YahooScreenerFilter *filter in filters) {
        NSDictionary *filterDict = [self filterToDictionary:filter];
        [filterArray addObject:filterDict];
    }
    
    // Request body
    NSDictionary *requestBody = @{
        @"maxResults": @(maxResults),
        @"filters": filterArray
    };
    
    [self executeRequest:request
                withBody:requestBody
                cacheKey:cacheKey
              completion:completion];
}

- (void)fetchQuickScreener:(YahooScreenerPreset)preset
                 minVolume:(nullable NSNumber *)minVolume
              minMarketCap:(nullable NSNumber *)minMarketCap
                    sector:(nullable NSString *)sector
                maxResults:(NSInteger)maxResults
                completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *_Nullable error))completion {
    
    // Build filters array
    NSMutableArray<YahooScreenerFilter *> *filters = [NSMutableArray array];
    
    if (minVolume && minVolume.doubleValue > 0) {
        YahooScreenerFilter *volumeFilter = [[YahooScreenerFilter alloc] init];
        volumeFilter.field = @"dayvolume";
        volumeFilter.comparison = YahooFilterGreaterThan;
        volumeFilter.values = @[minVolume];
        [filters addObject:volumeFilter];
    }
    
    if (minMarketCap && minMarketCap.doubleValue > 0) {
        YahooScreenerFilter *marketCapFilter = [[YahooScreenerFilter alloc] init];
        marketCapFilter.field = @"intradaymarketcap";
        marketCapFilter.comparison = YahooFilterGreaterThan;
        marketCapFilter.values = @[minMarketCap];
        [filters addObject:marketCapFilter];
    }
    
    if (sector && ![sector isEqualToString:@"All Sectors"]) {
        YahooScreenerFilter *sectorFilter = [[YahooScreenerFilter alloc] init];
        sectorFilter.field = @"sector";
        sectorFilter.comparison = YahooFilterEqual;
        sectorFilter.values = @[sector];
        [filters addObject:sectorFilter];
    }
    
    // Use appropriate method based on filters
    if (filters.count == 0) {
        [self fetchScreenerResults:preset maxResults:maxResults completion:completion];
    } else {
        // Build cache key including preset
        NSString *presetName = [self nameForPreset:preset];
        NSString *cacheKey = [NSString stringWithFormat:@"quick_%@_%lu_%ld", presetName, (unsigned long)filters.count, (long)maxResults];
        
        // Check cache
        if ([self shouldUseCachedResult:cacheKey]) {
            YahooScreenerCacheEntry *entry = self.cache[cacheKey];
            [self logInfo:@"Returning cached quick screener results"];
            completion(entry.results, nil);
            return;
        }
        
        [self logInfo:@"Fetching quick %@ screener with %lu filters", presetName, (unsigned long)filters.count];
        
        // Build request for quick screener
        NSString *urlString = [NSString stringWithFormat:@"%@/screener/quick", self.baseURL];
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"POST";
        
        // Request body
        NSMutableDictionary *requestBody = [NSMutableDictionary dictionary];
        requestBody[@"preset"] = presetName;
        requestBody[@"maxResults"] = @(maxResults);
        
        if (minVolume) requestBody[@"minVolume"] = minVolume;
        if (minMarketCap) requestBody[@"minMarketCap"] = minMarketCap;
        if (sector) requestBody[@"sector"] = sector;
        
        [self executeRequest:request
                    withBody:requestBody
                    cacheKey:cacheKey
                  completion:completion];
    }
}

#pragma mark - HTTP Request Execution

- (void)executeRequest:(NSMutableURLRequest *)request
              withBody:(NSDictionary *)requestBody
              cacheKey:(NSString *)cacheKey
            completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *_Nullable error))completion {
    
    // Set headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"TradingApp/1.0" forHTTPHeaderField:@"User-Agent"];
    
    // Set body
    NSError *jsonError;
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
    if (jsonError) {
        [self logError:@"Failed to serialize request body: %@", jsonError.localizedDescription];
        completion(@[], jsonError);
        return;
    }
    request.HTTPBody = requestData;
    
    [self logInfo:@"Making request to: %@", request.URL.absoluteString];
    
    // Execute request
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            [self logError:@"Network error: %@", error.localizedDescription];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], error);
            });
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        [self logInfo:@"Response status: %ld", (long)httpResponse.statusCode];
        
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"YahooScreenerAPI"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], httpError);
            });
            return;
        }
        
        // Parse response
        NSError *parseError;
        id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            [self logError:@"JSON parse error: %@", parseError.localizedDescription];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], parseError);
            });
            return;
        }
        
        // Convert to YahooScreenerResult objects
        NSArray<YahooScreenerResult *> *results = [self parseScreenerResults:jsonResponse];
        
        // Cache results
        if (self.enableCaching && results.count > 0) {
            [self cacheResults:results forKey:cacheKey];
        }
        
        [self logInfo:@"Successfully parsed %lu results", (unsigned long)results.count];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(results, nil);
        });
    }];
    
    [task resume];
}

#pragma mark - Response Parsing

- (NSArray<YahooScreenerResult *> *)parseScreenerResults:(id)jsonResponse {
    NSMutableArray<YahooScreenerResult *> *results = [NSMutableArray array];
    
    // Handle different response formats
    NSArray *dataArray = nil;
    if ([jsonResponse isKindOfClass:[NSDictionary class]]) {
        NSDictionary *responseDict = (NSDictionary *)jsonResponse;
        dataArray = responseDict[@"results"] ?: responseDict[@"data"] ?: responseDict[@"stocks"];
    } else if ([jsonResponse isKindOfClass:[NSArray class]]) {
        dataArray = (NSArray *)jsonResponse;
    }
    
    if (!dataArray || ![dataArray isKindOfClass:[NSArray class]]) {
        [self logError:@"Invalid response format - expected array of results"];
        return @[];
    }
    
    // Parse each result
    for (id item in dataArray) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            YahooScreenerResult *result = [YahooScreenerResult resultFromYahooData:(NSDictionary *)item];
            if (result.symbol.length > 0) {
                [results addObject:result];
            }
        }
    }
    
    return [results copy];
}

#pragma mark - Cache Management

- (BOOL)shouldUseCachedResult:(NSString *)cacheKey {
    if (!self.enableCaching) return NO;
    
    YahooScreenerCacheEntry *entry = self.cache[cacheKey];
    if (!entry) return NO;
    
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:entry.timestamp];
    return elapsed < self.cacheTimeout;
}

- (void)cacheResults:(NSArray<YahooScreenerResult *> *)results forKey:(NSString *)cacheKey {
    YahooScreenerCacheEntry *entry = [[YahooScreenerCacheEntry alloc] init];
    entry.results = results;
    entry.timestamp = [NSDate date];
    entry.cacheKey = cacheKey;
    
    self.cache[cacheKey] = entry;
    [self logInfo:@"Cached %lu results for key: %@", (unsigned long)results.count, cacheKey];
}

- (void)clearCache {
    [self.cache removeAllObjects];
    [self logInfo:@"Cache cleared"];
}

#pragma mark - Utility Methods

- (void)checkServiceAvailability:(void (^)(BOOL available, NSString *_Nullable version))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@/health", self.baseURL];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 10.0; // Short timeout for health check
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        BOOL available = NO;
        NSString *version = nil;
        
        if (!error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            available = (httpResponse.statusCode == 200);
            
            if (available && data) {
                NSError *jsonError;
                id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (!jsonError && [jsonResponse isKindOfClass:[NSDictionary class]]) {
                    version = jsonResponse[@"version"] ?: @"unknown";
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(available, version);
        });
    }];
    
    [task resume];
}

- (NSArray<NSString *> *)availableSectors {
    return self.availableSectorsArray;
}

- (void)initializeAvailableSectors {
    self.availableSectorsArray = @[
        @"All Sectors",
        @"Technology",
        @"Healthcare",
        @"Financial Services",
        @"Consumer Cyclical",
        @"Consumer Defensive",
        @"Industrials",
        @"Energy",
        @"Basic Materials",
        @"Real Estate",
        @"Utilities",
        @"Communication Services"
    ];
}

- (NSString *)nameForPreset:(YahooScreenerPreset)preset {
    switch (preset) {
        case YahooScreenerPresetMostActive:
            return @"most_active";
        case YahooScreenerPresetGainers:
            return @"gainers";
        case YahooScreenerPresetLosers:
            return @"losers";
        case YahooScreenerPresetUndervalued:
            return @"undervalued";
        case YahooScreenerPresetGrowthTech:
            return @"growth_tech";
        case YahooScreenerPresetHighDividend:
            return @"high_dividend";
        case YahooScreenerPresetSmallCapGrowth:
            return @"small_cap_growth";
        case YahooScreenerPresetMostShorted:
            return @"most_shorted";
        case YahooScreenerPresetCustom:
            return @"custom";
        default:
            return @"most_active";
    }
}

- (NSString *)endpointForPreset:(YahooScreenerPreset)preset {
    return [NSString stringWithFormat:@"screener/%@", [self nameForPreset:preset]];
}

- (NSDictionary *)filterToDictionary:(YahooScreenerFilter *)filter {
    NSString *comparison;
    switch (filter.comparison) {
        case YahooFilterEqual:
            comparison = @"eq";
            break;
        case YahooFilterGreaterThan:
            comparison = @"gt";
            break;
        case YahooFilterLessThan:
            comparison = @"lt";
            break;
        case YahooFilterBetween:
            comparison = @"btwn";
            break;
        default:
            comparison = @"eq";
    }
    
    return @{
        @"field": filter.field,
        @"comparison": comparison,
        @"values": filter.values
    };
}

#pragma mark - Logging

- (void)logInfo:(NSString *)format, ... {
    if (!self.enableLogging) return;
    
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"🔍 YahooScreenerAPI: %@", message);
}

- (void)logError:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"❌ YahooScreenerAPI ERROR: %@", message);
}

@end
