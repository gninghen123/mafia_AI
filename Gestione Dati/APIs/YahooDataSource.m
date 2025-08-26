//
//  YahooDataSource.m
//  TradingApp
//

#import "YahooDataSource.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "CommonTypes.h"
@interface YahooDataSource ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSString *crumb;
@property (nonatomic, strong) NSHTTPCookie *cookie;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, strong) NSOperationQueue *requestQueue;

// Implement protocol properties
@property (nonatomic, readwrite) DataSourceType sourceType;
@property (nonatomic, readwrite) DataSourceCapabilities capabilities;
@property (nonatomic, readwrite) NSString *sourceName;
@end

@implementation YahooDataSource

@synthesize sourceType = _sourceType;
@synthesize capabilities = _capabilities;
@synthesize sourceName = _sourceName;

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourceType = DataSourceTypeYahoo;
        _capabilities = DataSourceCapabilityQuotes |
        DataSourceCapabilityHistoricalData |
                       DataSourceCapabilityFundamentals |
                       DataSourceCapabilityNews;
        _sourceName = @"Yahoo Finance";
        _cacheTimeout = 60; // 1 minute default
        
        // Setup URL session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30;
        _session = [NSURLSession sessionWithConfiguration:config];
        
        // Setup cache
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 100;
        
        // Setup operation queue
        _requestQueue = [[NSOperationQueue alloc] init];
        _requestQueue.maxConcurrentOperationCount = 5;
    }
    return self;
}

#pragma mark - DataSourceProtocol Required

- (BOOL)isConnected {
    return _connected;
}

- (void)connectWithCredentials:(NSDictionary *)credentials
                    completion:(void (^)(BOOL success, NSError *error))completion {
    // Yahoo doesn't require authentication for basic data
    // But we might need to get a crumb for some endpoints
    if (self.useCrumbAuthentication) {
        [self fetchCrumbWithCompletion:^(BOOL success, NSError *error) {
            self.connected = success;
            if (completion) {
                completion(success, error);
            }
        }];
    } else {
        self.connected = YES;
        if (completion) {
            completion(YES, nil);
        }
    }
}

- (void)disconnect {
    [self.session invalidateAndCancel];
    self.connected = NO;
    self.crumb = nil;
    self.cookie = nil;
    [self.cache removeAllObjects];
}

#pragma mark - Market Data

// Aggiornamento del metodo fetchQuoteForSymbol nel YahooDataSource.m

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    NSLog(@"YahooDataSource: Fetching quote for symbol: %@", symbol);
    
    // Check cache first
    NSString *cacheKey = [NSString stringWithFormat:@"quote_%@", symbol];
    MarketData *cachedQuote = [self.cache objectForKey:cacheKey];
    if (cachedQuote) {
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:cachedQuote.timestamp];
        if (age < self.cacheTimeout) {
            NSLog(@"YahooDataSource: Using cached quote for %@", symbol);
            if (completion) {
                completion(cachedQuote, nil);
            }
            return;
        }
    }
    
    NSString *urlString = [NSString stringWithFormat:
                          @"https://query1.finance.yahoo.com/v8/finance/chart/%@", symbol];
    
    NSLog(@"YahooDataSource: Requesting URL: %@", urlString);
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    // Add headers to mimic a browser request
    [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    if (self.cookie) {
        [request setValue:self.cookie.value forHTTPHeaderField:@"Cookie"];
    }
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"YahooDataSource: Network error for %@: %@", symbol, error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"YahooDataSource: HTTP Status Code: %ld", (long)httpResponse.statusCode);
        
        if (httpResponse.statusCode != 200) {
            NSString *errorMsg = [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode];
            NSError *httpError = [NSError errorWithDomain:@"YahooDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
            NSLog(@"YahooDataSource: HTTP error: %@", errorMsg);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, httpError);
            });
            return;
        }
        
        // Log raw response
        NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"YahooDataSource: Raw response for %@ (first 500 chars): %@",
              symbol, [responseString substringToIndex:MIN(500, responseString.length)]);
        
        NSError *parseError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        
        if (parseError) {
            NSLog(@"YahooDataSource: JSON parsing error for %@: %@", symbol, parseError.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, parseError);
            });
            return;
        }
        
        // Log parsed JSON structure
        NSLog(@"YahooDataSource: Parsed JSON keys: %@", json.allKeys);
        
        // Check for error in JSON
        if (json[@"chart"] && json[@"chart"][@"error"]) {
            NSDictionary *errorInfo = json[@"chart"][@"error"];
            NSString *errorMsg = errorInfo[@"description"] ?: @"Unknown Yahoo API error";
            NSError *yahooError = [NSError errorWithDomain:@"YahooDataSource"
                                                      code:[errorInfo[@"code"] integerValue]
                                                  userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
            NSLog(@"YahooDataSource: Yahoo API error for %@: %@", symbol, errorMsg);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, yahooError);
            });
            return;
        }
        
        MarketData *quote = [self parseQuoteFromJSON:json forSymbol:symbol];
        
        if (quote) {
            NSLog(@"YahooDataSource: Successfully parsed quote for %@", symbol);
            [self.cache setObject:quote forKey:cacheKey];
        } else {
            NSLog(@"YahooDataSource: Failed to parse quote for %@", symbol);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(quote, nil);
        });
    }];
    
    [task resume];
}
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    NSString *interval = [self intervalStringForTimeframe:timeframe];
    NSString *urlString = [NSString stringWithFormat:
                          @"https://query1.finance.yahoo.com/v8/finance/chart/%@?period1=%ld&period2=%ld&interval=%@",
                          symbol,
                          (long)[startDate timeIntervalSince1970],
                          (long)[endDate timeIntervalSince1970],
                          interval];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        NSError *parseError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        
        if (parseError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, parseError);
            });
            return;
        }
        
        NSArray *bars = [self parseHistoricalDataFromJSON:json];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(bars, nil);
        });
    }];
    
    [task resume];
}

#pragma mark - Helper Methods

- (void)fetchCrumbWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    // Implementation for getting Yahoo crumb if needed
    // This is required for some protected endpoints
    if (completion) {
        completion(YES, nil); // Simplified for now
    }
}

- (NSString *)intervalStringForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1m";
        case BarTimeframe5Min: return @"5m";
        case BarTimeframe15Min: return @"15m";
        case BarTimeframe30Min: return @"30m";
        case BarTimeframe1Hour: return @"60m";
        case BarTimeframeDaily: return @"1d";
        case BarTimeframeWeekly: return @"1wk";
        case BarTimeframeMonthly: return @"1mo";
        default: return @"1d";
    }
}

// Aggiornamento del metodo parseQuoteFromJSON nel YahooDataSource.m

- (MarketData *)parseQuoteFromJSON:(NSDictionary *)json forSymbol:(NSString *)symbol {
    NSLog(@"YahooDataSource: Parsing JSON for %@", symbol);
    
    NSDictionary *chart = json[@"chart"];
    if (!chart) {
        NSLog(@"YahooDataSource: No 'chart' key in JSON");
        return nil;
    }
    
    NSArray *results = chart[@"result"];
    if (!results || results.count == 0) {
        NSLog(@"YahooDataSource: No results in chart");
        return nil;
    }
    
    NSDictionary *result = results[0];
    NSDictionary *meta = result[@"meta"];
    
    NSLog(@"YahooDataSource: Meta data keys: %@", meta.allKeys);
    NSLog(@"YahooDataSource: regularMarketPrice: %@ (%@)", meta[@"regularMarketPrice"], [meta[@"regularMarketPrice"] class]);
    NSLog(@"YahooDataSource: previousClose: %@ (%@)", meta[@"previousClose"], [meta[@"previousClose"] class]);
    
    // Create dictionary for MarketData initialization
    NSMutableDictionary *marketDataDict = [NSMutableDictionary dictionary];
    marketDataDict[@"symbol"] = symbol;
    
    // Map Yahoo fields to our MarketData fields
    if (meta[@"regularMarketPrice"]) {
        marketDataDict[@"last"] = meta[@"regularMarketPrice"];
    }
    
    if (meta[@"previousClose"]) {
        marketDataDict[@"previousClose"] = meta[@"previousClose"];
    }
    
    if (meta[@"regularMarketVolume"]) {
        marketDataDict[@"volume"] = meta[@"regularMarketVolume"];
    }
    
    // Try to get bid/ask from meta or use last price as fallback
    if (meta[@"bid"]) {
        marketDataDict[@"bid"] = meta[@"bid"];
    } else if (meta[@"regularMarketPrice"]) {
        // Use last price as bid if no bid available
        marketDataDict[@"bid"] = meta[@"regularMarketPrice"];
    }
    
    if (meta[@"ask"]) {
        marketDataDict[@"ask"] = meta[@"ask"];
    } else if (meta[@"regularMarketPrice"]) {
        // Use last price as ask if no ask available
        marketDataDict[@"ask"] = meta[@"regularMarketPrice"];
    }
    
    // Get additional fields if available
    if (meta[@"regularMarketOpen"]) {
        marketDataDict[@"open"] = meta[@"regularMarketOpen"];
    }
    
    if (meta[@"regularMarketDayHigh"]) {
        marketDataDict[@"high"] = meta[@"regularMarketDayHigh"];
    }
    
    if (meta[@"regularMarketDayLow"]) {
        marketDataDict[@"low"] = meta[@"regularMarketDayLow"];
    }
    
    if (meta[@"chartPreviousClose"]) {
        marketDataDict[@"close"] = meta[@"chartPreviousClose"];
    }
    
    if (meta[@"exchangeName"]) {
        marketDataDict[@"exchange"] = meta[@"exchangeName"];
    }
    
    // Add timestamp
    marketDataDict[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    NSLog(@"YahooDataSource: MarketData dictionary: %@", marketDataDict);
    
    // Create MarketData object
    MarketData *quote = [[MarketData alloc] initWithDictionary:marketDataDict];
    
    NSLog(@"YahooDataSource: Created quote - Last: %@, Bid: %@, Ask: %@", quote.last, quote.bid, quote.ask);
    
    return quote;
}

- (NSArray *)parseHistoricalDataFromJSON:(NSDictionary *)json {
    NSDictionary *chart = json[@"chart"];
    if (!chart) return nil;
    
    NSArray *results = chart[@"result"];
    if (!results || results.count == 0) return nil;
    
    NSDictionary *result = results[0];
    NSArray *timestamps = result[@"timestamp"];
    NSDictionary *indicators = result[@"indicators"];
    NSDictionary *quote = indicators[@"quote"][0];
    
    NSArray *opens = quote[@"open"];
    NSArray *highs = quote[@"high"];
    NSArray *lows = quote[@"low"];
    NSArray *closes = quote[@"close"];
    NSArray *volumes = quote[@"volume"];
    
    NSMutableArray *bars = [NSMutableArray array];
    
    for (NSInteger i = 0; i < timestamps.count; i++) {
        NSMutableDictionary *barDict = [NSMutableDictionary dictionary];
        
        barDict[@"date"] = [NSDate dateWithTimeIntervalSince1970:[timestamps[i] doubleValue]];
        barDict[@"open"] = opens[i];
        barDict[@"high"] = highs[i];
        barDict[@"low"] = lows[i];
        barDict[@"close"] = closes[i];
        barDict[@"volume"] = volumes[i];
        
        [bars addObject:barDict];
    }
    
    return bars;
}

#pragma mark - Rate Limiting

- (NSInteger)remainingRequests {
    // Yahoo doesn't publish rate limits, but we should be conservative
    return 100; // Arbitrary limit
}

- (NSDate *)rateLimitResetDate {
    return [NSDate dateWithTimeIntervalSinceNow:60]; // Reset every minute
}

@end
