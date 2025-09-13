
//
//  WebullDataSource.m - IMPLEMENTAZIONE UNIFICATA (PARTE 1)
//  TradingApp
//

#import "WebullDataSource.h"
#import "CommonTypes.h"

// Webull API Endpoints
static NSString *const kWebullTopGainersURL = @"https://quotes-gw.webullfintech.com/api/bgw/market/topGainers";
static NSString *const kWebullTopLosersURL = @"https://quotes-gw.webullfintech.com/api/bgw/market/dropGainers";
static NSString *const kWebullETFListURL = @"https://quotes-gw.webullfintech.com/api/wlas/etfinder/pcFinder?topNum=5&finderId=wlas.etfinder.index&nbboLevel=false";
static NSString *const kWebullQuotesURL = @"https://quotes-gw.webullfintech.com/api/bgw/quote/tickerRealTimes";
static NSString *const kWebullHistoricalURL = @"https://quotes-gw.webullfintech.com/api/quote/charts/query";

@interface WebullDataSource ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSString *deviceId;

// Protocol properties
@property (nonatomic, readwrite) DataSourceType sourceType;
@property (nonatomic, readwrite) DataSourceCapabilities capabilities;
@property (nonatomic, readwrite) NSString *sourceName;
@property (nonatomic, readwrite) BOOL isConnected;
@end

@implementation WebullDataSource

@synthesize sourceType = _sourceType;
@synthesize capabilities = _capabilities;
@synthesize sourceName = _sourceName;
@synthesize isConnected = _isConnected;

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourceType = DataSourceTypeWebull;
        _sourceName = @"Webull";
        _capabilities = DataSourceCapabilityQuotes |
                       DataSourceCapabilityHistoricalData |
                       DataSourceCapabilityMarketLists;
        _isConnected = YES; // Webull API doesn't require authentication for public endpoints
        
        // Generate device ID for session
        _deviceId = [[NSUUID UUID] UUIDString];
        
        // Configure session with headers
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPAdditionalHeaders = @{
            @"User-Agent": @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            @"Accept": @"application/json",
            @"Accept-Language": @"en-US,en;q=0.9",
            @"sec-ch-ua": @"\"Not_A Brand\";v=\"99\", \"Google Chrome\";v=\"109\", \"Chromium\";v=\"109\"",
            @"sec-ch-ua-mobile": @"?0",
            @"sec-ch-ua-platform": @"\"macOS\"",
            @"did": _deviceId
        };
        
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

#pragma mark - DataSource Protocol Implementation

- (BOOL)isConnected {
    return _isConnected;
}

// ✅ UNIFICATO: Aggiunto metodo protocollo standard (era connectWithCredentials)
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"WebullDataSource: connectWithCompletion called (unified protocol)");
    
    // Webull doesn't require authentication for market data endpoints
    self.isConnected = YES;
    
    if (completion) {
        completion(YES, nil);
    }
}

- (void)disconnect {
    [self.session invalidateAndCancel];
    self.isConnected = NO;
}

#pragma mark - Market Data - UNIFIED PROTOCOL

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    [self fetchQuotesForSymbols:@[symbol] completion:^(NSDictionary *quotes, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            // ✅ RITORNA DATI RAW WEBULL
            id rawQuoteData = quotes[symbol];
            if (completion) completion(rawQuoteData, nil);
        }
    }];
}

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    if (symbols.count == 0) {
        if (completion) completion(@{}, nil);
        return;
    }
    
    // Build tickerIds parameter
    NSString *tickerIds = [symbols componentsJoinedByString:@","];
    NSString *urlString = [NSString stringWithFormat:@"%@?tickerIds=%@&includeSecu=1&includeQuote=1",
                          kWebullQuotesURL, tickerIds];
    
    [self executeRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = nil;
        if ([response isKindOfClass:[NSArray class]]) {
            data = response;
        } else if ([response isKindOfClass:[NSDictionary class]]) {
            data = response[@"data"];
        }
        
        if (!data) {
            if (completion) completion(@{}, nil);
            return;
        }
        
        NSMutableDictionary *quotesDict = [NSMutableDictionary dictionary];
        
        for (NSDictionary *item in data) {
            NSString *symbol = item[@"symbol"];
            if (!symbol) continue;
            
            // ✅ RITORNA DATI RAW WEBULL - nessuna conversione a MarketData
            // Il WebullDataAdapter si occuperà della standardizzazione
            quotesDict[symbol] = item;
        }
        
        if (completion) completion(quotesDict, nil);
    }];
}

#pragma mark - HTTP Request Helper

- (void)executeRequest:(NSString *)urlString completion:(void (^)(id response, NSError *error))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    // Headers are already set in session configuration
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleHTTPResponse:data response:response error:error completion:completion];
    }];
    
    [task resume];
}

- (void)handleHTTPResponse:(NSData *)data
                  response:(NSURLResponse *)response
                     error:(NSError *)error
                completion:(void (^)(id response, NSError *error))completion {
    
    if (error) {
        NSLog(@"❌ WebullDataSource: Network error: %@", error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);  // ✅ FIX: sintassi completa
        });
        return;
    }
    
    if (!data) {
        NSError *noDataError = [NSError errorWithDomain:@"WebullDataSource"
                                                   code:404
                                               userInfo:@{NSLocalizedDescriptionKey: @"No data received"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, noDataError);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        NSError *httpError = [NSError errorWithDomain:@"WebullDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                       [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode]}];
        NSLog(@"❌ WebullDataSource: HTTP Error %ld", (long)httpResponse.statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, httpError);
        });
        return;
    }
    
    NSError *parseError;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    
    if (parseError) {
        NSLog(@"❌ WebullDataSource: JSON parse error: %@", parseError.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, parseError);
        });
        return;
    }
    
    NSLog(@"✅ WebullDataSource: Request successful, parsed JSON response");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(json, nil);
    });
}


#pragma mark - Historical Data - UNIFIED PROTOCOL

// ✅ UNIFICATO: Historical data con date range (AGGIUNTO)
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    NSLog(@"WebullDataSource: fetchHistoricalData with date range for %@", symbol);
    
    // ✅ CONVERTI BarTimeframe → Webull timeframe string
    NSString *webullTimeframe = [self webullTimeframeFromBarTimeframe:timeframe];
    
    // ✅ CALCOLA count dal date range
    NSInteger count = [self calculateBarCountFromStartDate:startDate endDate:endDate timeframe:timeframe];
    
    // ✅ USA IL METODO CON BAR COUNT
    [self fetchHistoricalDataForSymbol:symbol
                             timeframe:timeframe
                              barCount:count
                     needExtendedHours:needExtendedHours
                            completion:completion];
}

// ✅ UNIFICATO: Historical data con bar count (PARAMETRI CORRETTI)
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe  // ✅ BarTimeframe non NSString
                            barCount:(NSInteger)barCount      // ✅ barCount non count
                   needExtendedHours:(BOOL)needExtendedHours  // ✅ AGGIUNTO
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    NSLog(@"WebullDataSource: fetchHistoricalData with barCount %ld for %@", (long)barCount, symbol);
    
    // ✅ CONVERTI BarTimeframe → Webull timeframe string
    NSString *webullTimeframe = [self webullTimeframeFromBarTimeframe:timeframe];
    
    // ✅ COSTRUISCE URL WEBULL
    NSString *urlString = [NSString stringWithFormat:@"%@?tickerIds=%@&type=%@&count=%ld",
                          kWebullHistoricalURL, symbol, webullTimeframe, (long)barCount];
    
    // ✅ AGGIUNGE extended hours se richiesto (Webull supporta)
    if (needExtendedHours) {
        urlString = [urlString stringByAppendingString:@"&extendedTradingSession=1"];
    }
    
    [self executeRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // ✅ RITORNA DATI RAW WEBULL - nessuna conversione
        // Il WebullDataAdapter si occuperà della standardizzazione
        id rawBars = [self extractHistoricalDataFromResponse:response];
        
        if (completion) completion(rawBars, nil);
    }];
}

#pragma mark - Market Lists - UNIFIED PROTOCOL

// Modifica al metodo fetchMarketListForType nel file WebullDataSource.m

- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion {
    
    switch (listType) {
        case DataRequestTypeTopGainers: {
            NSString *rankType = parameters[@"timeframe"] ?: @"1d";
            NSInteger pageSize = [parameters[@"pageSize"] integerValue] ?: 50;
            [self fetchTopGainersWithRankType:rankType
                                     pageSize:pageSize
                                   completion:completion];
            break;
        }
        case DataRequestTypeTopLosers: {
            NSString *rankType = parameters[@"timeframe"] ?: @"1d";
            NSInteger pageSize = [parameters[@"pageSize"] integerValue] ?: 50;
            [self fetchTopLosersWithRankType:rankType
                                    pageSize:pageSize
                                  completion:completion];
            break;
        }
        case DataRequestTypeETFList: {
            [self fetchETFListWithCompletion:completion];
            break;
        }
        
        // ✅ NUOVO: Earnings Market Lists
        case DataRequestTypeMarketList: {
                    // Estrae il timeframe come stringa dai parametri
                    NSString *timeframeString = parameters[@"timeframe"] ?: @"today_bmo";
                    [self fetchEarningsForTimeframe:timeframeString completion:completion];
                    break;
                }
        
        default: {
            NSError *error = [NSError errorWithDomain:@"WebullDataSource"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                       [NSString stringWithFormat:@"Unsupported market list type: %ld", (long)listType]}];
            if (completion) completion(nil, error);
            break;
        }
    }
}

#pragma mark - Earnings Implementation

- (void)fetchEarningsForTimeframe:(NSString *)timeframeString
                       completion:(void (^)(NSArray *results, NSError *error))completion {
    
    NSString *startDate;
    NSString *qualifierFilter = nil; // nil = tutti, "BMO"/"AMC" = filtro specifico
    
    if ([timeframeString isEqualToString:@"today_bmo"]) {
        startDate = [self todayDateString];
        qualifierFilter = @"BMO";
    }
    else if ([timeframeString isEqualToString:@"today_amc"]) {
        startDate = [self todayDateString];
        qualifierFilter = @"AMC";
    }
    else if ([timeframeString isEqualToString:@"last_5_days"]) {
        startDate = [self dateStringDaysAgo:5];
        // qualifierFilter rimane nil per includere tutti
    }
    else if ([timeframeString isEqualToString:@"last_10_days"]) {
        startDate = [self dateStringDaysAgo:10];
        // qualifierFilter rimane nil per includere tutti
    }
    else {
        NSError *error = [NSError errorWithDomain:@"WebullDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithFormat:@"Unsupported earnings timeframe: %@", timeframeString]}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSLog(@"🔍 WebullDataSource: Fetching earnings for timeframe '%@', startDate: %@, qualifier: %@",
          timeframeString, startDate, qualifierFilter ?: @"ALL");
    
    [self fetchWebullEarningsFromDate:startDate
                      qualifierFilter:qualifierFilter
                           completion:completion];
}

- (void)fetchWebullEarningsFromDate:(NSString *)startDate
                    qualifierFilter:(NSString *)qualifierFilter
                         completion:(void (^)(NSArray *results, NSError *error))completion {
    
    // URL Webull Earnings Calendar
    NSString *urlString = [NSString stringWithFormat:
                          @"https://quotes-gw.webullfintech.com/api/bgw/explore/calendar/earnings?regionId=6&pageIndex=1&pageSize=350&startDate=%@",
                          startDate];
    
    NSLog(@"🔍 WebullDataSource: Fetching earnings from: %@", urlString);
    
    [self executeRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"❌ WebullDataSource: Earnings request failed: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *rawEarnings = [self extractEarningsDataFromResponse:response];
        
        // ✅ Applica filtro BMO/AMC se specificato
        if (qualifierFilter) {
            rawEarnings = [self filterEarningsData:rawEarnings byQualifier:qualifierFilter];
            NSLog(@"🎯 WebullDataSource: Filtered earnings for %@: %lu results",
                  qualifierFilter, (unsigned long)rawEarnings.count);
        } else {
            NSLog(@"📊 WebullDataSource: Fetched ALL earnings: %lu results",
                  (unsigned long)rawEarnings.count);
        }
        
        // ✅ RITORNA DATI RAW WEBULL - WebullDataAdapter si occuperà della standardizzazione
        if (completion) completion(rawEarnings, nil);
    }];
}

- (NSArray *)extractEarningsDataFromResponse:(id)response {
    if (![response isKindOfClass:[NSDictionary class]]) {
        NSLog(@"⚠️ WebullDataSource: Earnings response non è un dictionary");
        return @[];
    }
    
    NSDictionary *responseDict = (NSDictionary *)response;
    NSArray *data = responseDict[@"data"];
    
    if (![data isKindOfClass:[NSArray class]]) {
        NSLog(@"⚠️ WebullDataSource: Earnings data non è un array, structure: %@", responseDict.allKeys);
        return @[];
    }
    
    NSLog(@"✅ WebullDataSource: Extracted %lu earnings items from response", (unsigned long)data.count);
    return data;
}

- (NSArray *)filterEarningsData:(NSArray *)earningsData byQualifier:(NSString *)qualifier {
    if (!earningsData || !qualifier) {
        return earningsData;
    }
    
    NSMutableArray *filteredResults = [NSMutableArray array];
    
    for (NSDictionary *item in earningsData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        // ✅ FIX: Il qualifier è dentro il dizionario "values"
        NSDictionary *values = item[@"values"];
        if (![values isKindOfClass:[NSDictionary class]]) continue;
        
        NSString *itemQualifier = values[@"qualifier"] ?: values[@"timing"] ?: values[@"timeOfDay"] ?: @"";
        
        if ([itemQualifier isEqualToString:qualifier]) {
            [filteredResults addObject:item];
            NSLog(@"✅ WebullDataSource: Found %@ earnings for %@", qualifier, values[@"ticker"][@"symbol"] ?: @"unknown");
        }
    }
    
    NSLog(@"🎯 WebullDataSource: Filtered %lu items for qualifier '%@'", (unsigned long)filteredResults.count, qualifier);
    return [filteredResults copy];
}

#pragma mark - Date Helper Methods

- (NSString *)todayDateString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"]; // US markets timezone
    return [formatter stringFromDate:[NSDate date]];
}

- (NSString *)dateStringDaysAgo:(NSInteger)daysAgo {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    
    NSDate *pastDate = [calendar dateByAddingUnit:NSCalendarUnitDay
                                            value:-daysAgo
                                           toDate:[NSDate date]
                                          options:0];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    return [formatter stringFromDate:pastDate];
}

// INTERNAL: Top Gainers
- (void)fetchTopGainersWithRankType:(NSString *)rankType
                           pageSize:(NSInteger)pageSize
                         completion:(void (^)(NSArray *gainers, NSError *error))completion {
    // Default pageSize to 50 if not specified or <= 0
    if (pageSize <= 0) {
        pageSize = 50;
    }
    // Add regionId=6 and pageIndex=1 to URL
    NSString *urlString = [NSString stringWithFormat:@"%@?rankType=%@&pageSize=%ld&regionId=6&pageIndex=1",
                          kWebullTopGainersURL, rankType, (long)pageSize];
    
    [self executeRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // ✅ RITORNA DATI RAW WEBULL
        NSArray *data = nil;
        if ([response isKindOfClass:[NSArray class]]) {
            data = response;
        } else if ([response isKindOfClass:[NSDictionary class]]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data ?: @[], nil);
    }];
}

// INTERNAL: Top Losers
- (void)fetchTopLosersWithRankType:(NSString *)rankType
                          pageSize:(NSInteger)pageSize
                        completion:(void (^)(NSArray *losers, NSError *error))completion {
    // Default pageSize to 50 if not specified or <= 0
    if (pageSize <= 0) {
        pageSize = 50;
    }
    // Add regionId=6 and pageIndex=1 to URL
    NSString *urlString = [NSString stringWithFormat:@"%@?rankType=%@&pageSize=%ld&regionId=6&pageIndex=1",
                          kWebullTopLosersURL, rankType, (long)pageSize];
    
    [self executeRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // ✅ RITORNA DATI RAW WEBULL
        NSArray *data = nil;
        if ([response isKindOfClass:[NSArray class]]) {
            data = response;
        } else if ([response isKindOfClass:[NSDictionary class]]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data ?: @[], nil);
    }];
}

// INTERNAL: ETF List
- (void)fetchETFListWithCompletion:(void (^)(NSArray *etfs, NSError *error))completion {
    
    [self executeRequest:kWebullETFListURL completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // ✅ RITORNA DATI RAW WEBULL ETFs
        NSArray *data = nil;
        if ([response isKindOfClass:[NSArray class]]) {
            data = response;
        } else if ([response isKindOfClass:[NSDictionary class]]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data ?: @[], nil);
    }];
}

#pragma mark - Helper Methods

- (NSString *)webullTimeframeFromBarTimeframe:(BarTimeframe)timeframe {
    // ✅ MAPPATURA BarTimeframe → Webull timeframe strings
    switch (timeframe) {
        case BarTimeframe1Min:     return @"m1";
        case BarTimeframe5Min:     return @"m5";
        case BarTimeframe15Min:    return @"m15";
        case BarTimeframe30Min:    return @"m30";
        case BarTimeframe1Hour:    return @"h1";
        case BarTimeframe4Hour:    return @"h4";   // Se supportato da Webull
        case BarTimeframeDaily:    return @"d1";
        case BarTimeframeWeekly:   return @"w1";
        case BarTimeframeMonthly:  return @"M1";
        default:                   return @"d1";
    }
}

- (NSInteger)calculateBarCountFromStartDate:(NSDate *)startDate
                                    endDate:(NSDate *)endDate
                                  timeframe:(BarTimeframe)timeframe {
    
    NSTimeInterval interval = [endDate timeIntervalSinceDate:startDate];
    
    // ✅ CALCOLA count basato su timeframe
    switch (timeframe) {
        case BarTimeframe1Min:     return (NSInteger)(interval / 60);
        case BarTimeframe5Min:     return (NSInteger)(interval / 300);
        case BarTimeframe15Min:    return (NSInteger)(interval / 900);
        case BarTimeframe30Min:    return (NSInteger)(interval / 1800);
        case BarTimeframe1Hour:    return (NSInteger)(interval / 3600);
        case BarTimeframe4Hour:    return (NSInteger)(interval / 14400);
        case BarTimeframeDaily:    return (NSInteger)(interval / 86400);
        case BarTimeframeWeekly:   return (NSInteger)(interval / 604800);
        case BarTimeframeMonthly:  return (NSInteger)(interval / 2592000);
        default:                   return (NSInteger)(interval / 86400);
    }
}

- (id)extractHistoricalDataFromResponse:(id)response {
    // ✅ ESTRAE DATI RAW WEBULL dalla response
    
    NSArray *data = nil;
    if ([response isKindOfClass:[NSArray class]]) {
        data = response;
    } else if ([response isKindOfClass:[NSDictionary class]]) {
        NSDictionary *chartData = [response[@"data"] firstObject];
        data = chartData[@"data"];
    }
    
    // ✅ RITORNA ARRAY RAW WEBULL bars
    return data ?: @[];
}

@end
