
//  YahooDataSource.m - IMPLEMENTAZIONE UNIFICATA
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

#pragma mark - Initialization

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

#pragma mark - DataSource Protocol Implementation - UNIFIED

- (BOOL)isConnected {
    return _connected;
}

// ✅ AGGIUNTO: Metodo unificato richiesto dal protocollo
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"YahooDataSource: connectWithCompletion called (unified protocol)");
    
    // Yahoo doesn't require authentication for basic data
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

// MANTIENE: Metodo legacy per backward compatibility (se necessario)
- (void)connectWithCredentials:(NSDictionary *)credentials
                    completion:(void (^)(BOOL success, NSError *error))completion {
    // Redirect to unified method
    [self connectWithCompletion:completion];
}

- (void)disconnect {
    [self.session invalidateAndCancel];
    self.connected = NO;
    self.crumb = nil;
    self.cookie = nil;
    [self.cache removeAllObjects];
}

#pragma mark - Market Data - UNIFIED

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"YahooDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"No symbol provided"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSLog(@"🔍 YahooDataSource: Fetching quote for %@", symbol);
    
    // Check cache first
    if (self.cacheTimeout > 0) {
        NSString *cacheKey = [NSString stringWithFormat:@"quote_%@", symbol];
        id cachedQuote = [self.cache objectForKey:cacheKey];
        if (cachedQuote) {
            NSLog(@"📦 YahooDataSource: Returning cached quote for %@", symbol);
            if (completion) {
                completion(cachedQuote, nil);
            }
            return;
        }
    }
    
    // ✅ HTTPS Yahoo JSON API
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
        [self handleQuoteResponse:data response:response error:error symbol:symbol completion:completion];
    }];
    
    [task resume];
}

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    NSLog(@"YahooDataSource: Fetching batch quotes for %lu symbols", (unsigned long)symbols.count);
    
    // Yahoo API doesn't support true batch requests, so we make individual requests
    NSMutableDictionary *allQuotes = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    __block NSError *firstError = nil;
    
    for (NSString *symbol in symbols) {
        dispatch_group_enter(group);
        
        [self fetchQuoteForSymbol:symbol completion:^(id quote, NSError *error) {
            @synchronized(allQuotes) {
                if (error && !firstError) {
                    firstError = error;
                } else if (quote) {
                    allQuotes[symbol] = quote;
                }
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion([allQuotes copy], firstError);
            }
        });
    });
}
#pragma mark - Modern Yahoo API Fallback

- (void)fetchQuotesUsingModernYahooAPI:(NSArray<NSString *> *)symbols
                            completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    NSLog(@"📊 OtherDataSource: Using modern Yahoo Finance API for %lu symbols", (unsigned long)symbols.count);
    
    // Usa le chiamate individuali con la nuova API Yahoo
    NSMutableDictionary *allQuotes = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    __block NSError *firstError = nil;
    
    for (NSString *symbol in symbols) {
        dispatch_group_enter(group);
        
        // Usa la nuova API Yahoo JSON
        NSString *urlString = [NSString stringWithFormat:
                              @"https://query1.finance.yahoo.com/v8/finance/chart/%@", symbol];
        
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        
        // Headers browser-like
        [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error || !data) {
                @synchronized(self) {
                    if (!firstError) firstError = error;
                }
            } else {
                // Parse JSON response
                NSError *jsonError;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (!jsonError && json) {
                    NSDictionary *quoteData = [self parseModernYahooResponse:json forSymbol:symbol];
                    if (quoteData) {
                        @synchronized(allQuotes) {
                            allQuotes[symbol] = quoteData;
                        }
                    }
                } else {
                    @synchronized(self) {
                        if (!firstError) firstError = jsonError;
                    }
                }
            }
            dispatch_group_leave(group);
        }];
        
        [task resume];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"📊 OtherDataSource: Modern Yahoo API completed with %lu quotes", (unsigned long)allQuotes.count);
            if (completion) {
                completion([allQuotes copy], firstError);
            }
        });
    });
}

- (NSDictionary *)parseModernYahooResponse:(NSDictionary *)json forSymbol:(NSString *)symbol {
    // Parse della nuova API Yahoo JSON (simile a YahooDataSource)
    NSDictionary *chart = json[@"chart"];
    if (!chart) return nil;
    
    NSArray *results = chart[@"result"];
    if (!results || results.count == 0) return nil;
    
    NSDictionary *result = results[0];
    NSDictionary *meta = result[@"meta"];
    if (!meta) return nil;
    
    // Extract quote data from meta
    double currentPrice = [meta[@"regularMarketPrice"] doubleValue];
    double previousClose = [meta[@"previousClose"] doubleValue];
    double change = currentPrice - previousClose;
    double changePercent = previousClose > 0 ? (change / previousClose) * 100.0 : 0.0;
    
    return @{
        @"symbol": symbol,
        @"last": @(currentPrice),
        @"change": @(change),
        @"changePercent": @(changePercent),
        @"open": meta[@"regularMarketOpen"] ?: @0,
        @"high": meta[@"regularMarketDayHigh"] ?: @0,
        @"low": meta[@"regularMarketDayLow"] ?: @0,
        @"volume": meta[@"regularMarketVolume"] ?: @0,
        @"previousClose": @(previousClose),
        @"timestamp": [NSDate date]
    };
}

#pragma mark - Historical Data - UNIFIED with Yahoo API

// ✅ METODO UNIFICATO: Historical data con date range
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    NSLog(@"YahooDataSource: Fetching historical data for %@ from %@ to %@",
          symbol, startDate, endDate);
    
    NSString *interval = [self intervalStringForTimeframe:timeframe];
    NSTimeInterval period1 = [startDate timeIntervalSince1970];
    NSTimeInterval period2 = [endDate timeIntervalSince1970];
    
    // ✅ USA L'API YAHOO CHE HAI SPECIFICATO
    NSMutableString *urlString = [NSMutableString stringWithFormat:
        @"https://query1.finance.yahoo.com/v8/finance/chart/%@?interval=%@&period1=%ld&period2=%ld",
        symbol, interval, (long)period1, (long)period2];
    
    // ✅ AGGIUNGE includePrePost per extended hours
    if (needExtendedHours) {
        [urlString appendString:@"&includePrePost=true"];
    }
    
    // Aggiungi events standard per dividendi/splits
    [urlString appendString:@"&events=div,splits,capitalGains"];
    
    NSLog(@"YahooDataSource: Historical URL: %@", urlString);
    
    [self executeHistoricalRequest:urlString completion:completion];
}

// ✅ METODO UNIFICATO: Historical data con bar count
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    NSLog(@"YahooDataSource: Fetching %ld bars of historical data for %@", (long)barCount, symbol);
    
    NSString *interval = [self intervalStringForTimeframe:timeframe];
    NSString *range = [self rangeStringForBarCount:barCount timeframe:timeframe];
    
    // ✅ USA L'API YAHOO con range invece di period1/period2
    NSMutableString *urlString = [NSMutableString stringWithFormat:
        @"https://query1.finance.yahoo.com/v8/finance/chart/%@?interval=%@&range=%@",
        symbol, interval, range];
    
    // ✅ AGGIUNGE includePrePost per extended hours
    if (needExtendedHours) {
        [urlString appendString:@"&includePrePost=true"];
    }
    
    // Aggiungi events standard
    [urlString appendString:@"&events=div,splits,capitalGains"];
    
    NSLog(@"YahooDataSource: Historical URL (count): %@", urlString);
    
    [self executeHistoricalRequest:urlString completion:completion];
}

#pragma mark - Helper Methods - ENHANCED

- (void)executeHistoricalRequest:(NSString *)urlString completion:(void (^)(NSArray *bars, NSError *error))completion {
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
        [self handleHistoricalResponse:data response:response error:error completion:completion];
    }];
    
    [task resume];
}

#pragma mark - Response Handlers - ✅ RESTITUISCONO SOLO DATI RAW

- (void)handleQuoteResponse:(NSData *)data
                   response:(NSURLResponse *)response
                      error:(NSError *)error
                     symbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    if (error) {
        NSLog(@"❌ YahooDataSource: Network error for %@: %@", symbol, error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        NSString *errorMsg = [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode];
        NSError *httpError = [NSError errorWithDomain:@"YahooDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
        NSLog(@"❌ YahooDataSource: HTTP %ld for %@", (long)httpResponse.statusCode, symbol);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, httpError);
        });
        return;
    }
    
    NSError *parseError;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    
    if (parseError) {
        NSLog(@"❌ YahooDataSource: JSON parsing error for %@: %@", symbol, parseError.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, parseError);
        });
        return;
    }
    
    // ✅ CONTROLLO ERRORI YAHOO API (con safe checking per NSNull)
    NSDictionary *chart = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        id chartObj = json[@"chart"];
        if (chartObj && ![chartObj isEqual:[NSNull null]] && [chartObj isKindOfClass:[NSDictionary class]]) {
            chart = (NSDictionary *)chartObj;
        }
    }
    
    if (chart) {
        id errorsObj = chart[@"error"];
        if (errorsObj && ![errorsObj isEqual:[NSNull null]] && [errorsObj isKindOfClass:[NSArray class]]) {
            NSArray *errors = (NSArray *)errorsObj;
            if (errors.count > 0) {
                NSDictionary *errorInfo = errors[0];
                NSString *errorMsg = errorInfo[@"description"] ?: @"Unknown Yahoo API error";
                NSError *yahooError = [NSError errorWithDomain:@"YahooDataSource"
                                                          code:[errorInfo[@"code"] integerValue]
                                                      userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                NSLog(@"❌ YahooDataSource: Yahoo API error for %@: %@", symbol, errorMsg);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, yahooError);
                });
                return;
            }
        }
    }
    
    // ✅ RITORNA DATI RAW COMPLETI - nessun parsing, nessuna trasformazione
    NSLog(@"✅ YahooDataSource: Raw Yahoo data received for %@ (%lu bytes)", symbol, (unsigned long)data.length);
    
    // Cache se abilitato
    if (self.cacheTimeout > 0) {
        NSString *cacheKey = [NSString stringWithFormat:@"quote_%@", symbol];
        [self.cache setObject:json forKey:cacheKey];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(json, nil);  // ✅ RITORNA IL JSON RAW COMPLETO
    });
}



- (void)handleHistoricalResponse:(NSData *)data
                        response:(NSURLResponse *)response
                           error:(NSError *)error
                      completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    if (error) {
        NSLog(@"❌ YahooDataSource: Historical request error: %@", error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        NSString *errorMsg = [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode];
        NSError *httpError = [NSError errorWithDomain:@"YahooDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
        NSLog(@"❌ YahooDataSource: Historical HTTP %ld", (long)httpResponse.statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, httpError);
        });
        return;
    }
    
    NSError *parseError;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    
    if (parseError) {
        NSLog(@"❌ YahooDataSource: Historical JSON parsing error: %@", parseError.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, parseError);
        });
        return;
    }
    
    // ✅ RITORNA ARRAY CON UN SOLO ELEMENTO: il JSON completo di Yahoo
    // Il YahooDataAdapter si occuperà di estrarre timestamps, indicators, etc.
    NSArray *rawHistoricalData = @[json];  // ✅ Wrapper in array per compatibilità
    
    NSLog(@"✅ YahooDataSource: Raw Yahoo historical data received (%lu bytes)", (unsigned long)data.length);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(rawHistoricalData, nil);
    });
}


#pragma mark - Yahoo API Helper Methods - ENHANCED

- (NSString *)intervalStringForTimeframe:(BarTimeframe)timeframe {
    // ✅ MAPPATURA COMPLETA Yahoo intervals
    switch (timeframe) {
        case BarTimeframe1Min:     return @"1m";
        case BarTimeframe2Min:     return @"2m";     // ✅ AGGIUNTO
        case BarTimeframe5Min:     return @"5m";
        case BarTimeframe15Min:    return @"15m";
        case BarTimeframe30Min:    return @"30m";
        case BarTimeframe1Hour:    return @"60m";
        case BarTimeframe90Min:    return @"90m";    // ✅ AGGIUNTO
        case BarTimeframeDaily:    return @"1d";
        case BarTimeframeWeekly:   return @"1wk";
        case BarTimeframeMonthly:  return @"1mo";
        default:                   return @"1d";
    }
}

- (NSString *)rangeStringForBarCount:(NSInteger)barCount timeframe:(BarTimeframe)timeframe {
    // ✅ LOGICA INTELLIGENTE per convertire barCount in range Yahoo
    
    // Per timeframes intraday, calcola giorni necessari
    if (timeframe <= BarTimeframe1Hour) {
        // Intraday: assumiamo 6.5 ore di trading per giorno (390 min)
        NSInteger barsPerDay;
        switch (timeframe) {
            case BarTimeframe1Min:  barsPerDay = 390; break;
            case BarTimeframe2Min:  barsPerDay = 195; break;
            case BarTimeframe5Min:  barsPerDay = 78; break;
            case BarTimeframe15Min: barsPerDay = 26; break;
            case BarTimeframe30Min: barsPerDay = 13; break;
            case BarTimeframe1Hour: barsPerDay = 6; break;
            default: barsPerDay = 390; break;
        }
        
        NSInteger daysNeeded = MAX(1, (barCount + barsPerDay - 1) / barsPerDay);
        
        if (daysNeeded <= 1) return @"1d";
        if (daysNeeded <= 5) return @"5d";
        if (daysNeeded <= 30) return @"1mo";
        if (daysNeeded <= 90) return @"3mo";
        if (daysNeeded <= 180) return @"6mo";
        if (daysNeeded <= 365) return @"1y";
        if (daysNeeded <= 730) return @"2y";
        if (daysNeeded <= 1825) return @"5y";
        return @"max";
    }
    
    // Per timeframes daily e superiori
    switch (timeframe) {
        case BarTimeframeDaily:
            if (barCount <= 5) return @"5d";
            if (barCount <= 22) return @"1mo";
            if (barCount <= 66) return @"3mo";
            if (barCount <= 132) return @"6mo";
            if (barCount <= 252) return @"1y";
            if (barCount <= 504) return @"2y";
            if (barCount <= 1260) return @"5y";
            return @"max";
            
        case BarTimeframeWeekly:
            if (barCount <= 4) return @"1mo";
            if (barCount <= 12) return @"3mo";
            if (barCount <= 26) return @"6mo";
            if (barCount <= 52) return @"1y";
            if (barCount <= 104) return @"2y";
            if (barCount <= 260) return @"5y";
            return @"max";
            
        case BarTimeframeMonthly:
            if (barCount <= 3) return @"3mo";
            if (barCount <= 6) return @"6mo";
            if (barCount <= 12) return @"1y";
            if (barCount <= 24) return @"2y";
            if (barCount <= 60) return @"5y";
            return @"max";
            
        default:
            return @"1y";
    }
}

- (void)fetchCrumbWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    // ✅ IMPLEMENTAZIONE crumb se necessario per protezione
    // Per ora Yahoo funziona senza crumb per i basic endpoints
    if (completion) {
        completion(YES, nil);
    }
}



#pragma mark - Legacy Support Methods

// ✅ MANTIENE metodi legacy per backward compatibility se necessari
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    // Redirect to unified method with needExtendedHours = NO
    [self fetchHistoricalDataForSymbol:symbol
                             timeframe:timeframe
                             startDate:startDate
                               endDate:endDate
                     needExtendedHours:NO
                            completion:completion];
}

#pragma mark - Rate Limiting

- (NSInteger)remainingRequests {
    // Yahoo doesn't publish rate limits, but we should be conservative
    return 100; // Arbitrary limit
}

- (NSDate *)rateLimitResetDate {
    return [NSDate dateWithTimeIntervalSinceNow:60]; // Reset every minute
}

#pragma mark - Utility Methods

+ (NSString *)userAgentString {
    return @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
}

+ (NSDictionary *)standardHeaders {
    return @{
        @"User-Agent": [self userAgentString],
        @"Accept": @"application/json, text/plain, */*",
        @"Accept-Language": @"en-US,en;q=0.9",
        @"Cache-Control": @"no-cache",
        @"Pragma": @"no-cache"
    };
}

@end
