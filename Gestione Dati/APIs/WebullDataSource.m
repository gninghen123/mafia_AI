//
//  WebullDataSource.m
//  TradingApp
//

#import "WebullDataSource.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "CommonTypes.h"  // Per BarTimeframe

// Webull API Endpoints
static NSString *const kWebullTopGainersURL = @"https://quotes-gw.webullfintech.com/api/bgw/market/topGainers";
static NSString *const kWebullTopLosersURL = @"https://quotes-gw.webullfintech.com/api/bgw/market/dropGainers";
static NSString *const kWebullETFListURL = @"https://quotes-gw.webullfintech.com/api/wlas/etfinder/pcFinder";
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

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourceType = DataSourceTypeWebull; // FIXED: Use correct WebullDataSource type
        _sourceName = @"Webull";
        _capabilities = DataSourceCapabilityQuotes |
        DataSourceCapabilityHistoricalData |
                       DataSourceCapabilityFundamentals;
        _isConnected = YES; // Webull API doesn't require authentication for these endpoints
        
        // Generate a device ID for the session
        _deviceId = [[NSUUID UUID] UUIDString];
        
        // Configure session
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
#pragma mark - DataSource Protocol - Market Lists

- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion {
    
    switch (listType) {
        case DataRequestTypeTopGainers: {
            NSString *rankType = parameters[@"rankType"] ?: @"1d";
            NSInteger pageSize = [parameters[@"pageSize"] integerValue] ?: 20;
            [self fetchTopGainersWithRankType:rankType
                                     pageSize:pageSize
                                   completion:completion];
            break;
        }
        case DataRequestTypeTopLosers: {
            NSString *rankType = parameters[@"rankType"] ?: @"1d";
            NSInteger pageSize = [parameters[@"pageSize"] integerValue] ?: 20;
            [self fetchTopLosersWithRankType:rankType
                                    pageSize:pageSize
                                  completion:completion];
            break;
        }
        case DataRequestTypeETFList: {
            [self fetchETFListWithCompletion:completion];
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

#pragma mark - DataSourceProtocol Required Methods

- (void)connectWithCredentials:(NSDictionary *)credentials
                    completion:(void (^)(BOOL success, NSError *error))completion {
    // Webull doesn't require authentication for market data
    if (completion) {
        completion(YES, nil);
    }
}

- (void)disconnect {
    [self.session invalidateAndCancel];
    self.isConnected = NO;
}

#pragma mark - DataSourceProtocol Optional Methods

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    [self fetchQuotesForSymbols:@[symbol] completion:^(NSDictionary *quotes, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            MarketData *quote = quotes[symbol];
            if (completion) completion(quote, nil);
        }
    }];
}

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    // Convert timeframe to Webull format
    NSString *webullTimeframe = [self webullTimeframeFromBarTimeframe:timeframe];
    NSInteger count = [self calculateBarCountFromStartDate:startDate endDate:endDate timeframe:timeframe];
    
    [self fetchHistoricalDataForSymbol:symbol
                             timeframe:webullTimeframe
                                 count:count
                            completion:completion];
}

#pragma mark - Market Lists

- (void)fetchTopGainersWithRankType:(NSString *)rankType
                           pageSize:(NSInteger)pageSize
                         completion:(void (^)(NSArray *gainers, NSError *error))completion {
    
    NSString *urlString = [NSString stringWithFormat:@"%@?regionId=6&pageIndex=1&pageSize=%ld&rankType=%@",
                          kWebullTopGainersURL, (long)pageSize, rankType];
    
    [self executeRequest:urlString completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = response[@"data"];
        if (!data) {
            if (completion) completion(@[], nil);
            return;
        }
        
        NSMutableArray *gainers = [NSMutableArray array];
        for (NSDictionary *item0 in data) {
            NSDictionary *item = item0[@"ticker"];
            // Calcola la variazione percentuale
            NSNumber *changeRatio = item[@"changeRatio"];
            double changePercent = 0.0;
            if (changeRatio) {
                changePercent = [changeRatio doubleValue] * 100.0; // Converti in percentuale
            }
            
            NSDictionary *gainersData = @{
                @"symbol": item[@"symbol"] ?: @"",
                @"name": item[@"name"] ?: @"",
                @"changePercent": @(changePercent),
                @"price": item[@"close"] ?: @0,
                @"change": item[@"change"] ?: @0,
                @"volume": item[@"volume"] ?: @0
            };
            [gainers addObject:gainersData];
        }
        
        if (completion) completion(gainers, nil);
    }];
}

- (void)fetchTopLosersWithRankType:(NSString *)rankType
                          pageSize:(NSInteger)pageSize
                        completion:(void (^)(NSArray *losers, NSError *error))completion {
    
    NSString *urlString = [NSString stringWithFormat:@"%@?regionId=6&pageIndex=1&pageSize=%ld&rankType=%@",
                          kWebullTopLosersURL, (long)pageSize, rankType];
    
    [self executeRequest:urlString completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = response[@"data"];
        if (!data) {
            if (completion) completion(@[], nil);
            return;
        }
        
        NSMutableArray *losers = [NSMutableArray array];
        for (NSDictionary *item0 in data) {
            NSDictionary *item = item0[@"ticker"];
            // Calcola la variazione percentuale
            NSNumber *changeRatio = item[@"changeRatio"];
            double changePercent = 0.0;
            if (changeRatio) {
                changePercent = [changeRatio doubleValue] * 100.0; // Converti in percentuale
            }
            
            NSDictionary *loserData = @{
                @"symbol": item[@"symbol"] ?: @"",
                @"name": item[@"name"] ?: @"",
                @"changePercent": @(changePercent),
                @"price": item[@"close"] ?: @0,
                @"change": item[@"change"] ?: @0,
                @"volume": item[@"volume"] ?: @0
            };
            [losers addObject:loserData];
        }
        
        if (completion) completion(losers, nil);
    }];
}

- (void)fetchETFListWithCompletion:(void (^)(NSArray *etfs, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?topNum=5&finderId=wlas.etfinder.index&nbboLevel=false",
                          kWebullETFListURL];
    
    [self executeRequest:urlString completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSMutableArray *etfs = [NSMutableArray array];
        
        // La struttura è: response -> tabs -> tickerTupleList
        NSArray *tabs = response[@"tabs"];
        if (!tabs || tabs.count == 0) {
            if (completion) completion(@[], nil);
            return;
        }
        
        // Prendiamo il primo tab (All) che contiene tutti gli ETF
        NSDictionary *allTab = tabs[0];
        NSArray *tickerTupleList = allTab[@"tickerTupleList"];
        
        if (!tickerTupleList) {
            if (completion) completion(@[], nil);
            return;
        }
        
        // Limitiamo a 20 ETF per non sovraccaricare l'interfaccia
        NSInteger maxETFs = MIN(tickerTupleList.count, 20);
        
        for (NSInteger i = 0; i < maxETFs; i++) {
            NSDictionary *etf = tickerTupleList[i];
            
            // Estrai i dati dell'ETF
            NSString *symbol = etf[@"symbol"] ?: etf[@"disSymbol"] ?: @"";
            NSString *name = etf[@"name"] ?: @"";
            
            // Calcola la variazione percentuale
            NSNumber *changeRatio = etf[@"changeRatio"];
            double changePercent = 0.0;
            if (changeRatio) {
                changePercent = [changeRatio doubleValue] * 100.0; // Converti in percentuale
            }
            
            NSDictionary *etfData = @{
                @"symbol": symbol,
                @"name": name,
                @"changePercent": @(changePercent),
                @"price": etf[@"close"] ?: @0,
                @"change": etf[@"change"] ?: @0,
                @"volume": etf[@"volume"] ?: @0
            };
            
            [etfs addObject:etfData];
        }
        
        if (completion) completion(etfs, nil);
    }];
}

#pragma mark - Quotes

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
            
            // Create MarketData from Webull response
            NSMutableDictionary *marketDataDict = [NSMutableDictionary dictionary];
            marketDataDict[@"symbol"] = symbol;
            marketDataDict[@"last"] = item[@"close"] ?: item[@"price"] ?: @0;
            marketDataDict[@"bid"] = item[@"bid"] ?: item[@"close"] ?: @0;
            marketDataDict[@"ask"] = item[@"ask"] ?: item[@"close"] ?: @0;
            marketDataDict[@"volume"] = item[@"volume"] ?: @0;
            marketDataDict[@"open"] = item[@"open"] ?: @0;
            marketDataDict[@"high"] = item[@"high"] ?: @0;
            marketDataDict[@"low"] = item[@"low"] ?: @0;
            marketDataDict[@"previousClose"] = item[@"preClose"] ?: @0;
            
            MarketData *quote = [[MarketData alloc] initWithDictionary:marketDataDict];
            quotesDict[symbol] = quote;
        }
        
        if (completion) completion(quotesDict, nil);
    }];
}

#pragma mark - Historical Data

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                          timeframe:(NSString *)timeframe
                              count:(NSInteger)count
                         completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    NSString *urlString = [NSString stringWithFormat:@"%@?tickerIds=%@&type=%@&count=%ld",
                          kWebullHistoricalURL, symbol, timeframe, (long)count];
    
    [self executeRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = nil;
        if ([response isKindOfClass:[NSArray class]]) {
            data = response;
        } else if ([response isKindOfClass:[NSDictionary class]]) {
            NSDictionary *chartData = [response[@"data"] firstObject];
            data = chartData[@"data"];
        }
        
        if (!data) {
            if (completion) completion(@[], nil);
            return;
        }
        
        NSMutableArray *bars = [NSMutableArray array];
        
        for (NSDictionary *barData in data) {
            // Crea un dizionario invece di un oggetto HistoricalBar
            NSMutableDictionary *bar = [NSMutableDictionary dictionary];
            bar[@"date"] = [NSDate dateWithTimeIntervalSince1970:[barData[@"time"] doubleValue] / 1000.0];
            bar[@"open"] = barData[@"open"] ?: @0;
            bar[@"high"] = barData[@"high"] ?: @0;
            bar[@"low"] = barData[@"low"] ?: @0;
            bar[@"close"] = barData[@"close"] ?: @0;
            bar[@"volume"] = barData[@"volume"] ?: @0;
            bar[@"symbol"] = symbol;
            
            [bars addObject:bar];
        }
        
        if (completion) completion(bars, nil);
    }];
}

#pragma mark - Helper Methods

- (void)executeRequest:(NSString *)urlString
            completion:(void (^)(id response, NSError *error))completion {
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *statusError = [NSError errorWithDomain:@"WebullDataSource"
                                                       code:httpResponse.statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, statusError);
                });
            }
            return;
        }
        
        NSError *parseError;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        
        if (parseError) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, parseError);
                });
            }
            return;
        }
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(json, nil);
            });
        }
    }];
    
    [task resume];
}

- (NSString *)webullTimeframeFromBarTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"m1";
        case BarTimeframe5Min: return @"m5";
        case BarTimeframe15Min: return @"m15";
        case BarTimeframe30Min: return @"m30";
        case BarTimeframe1Hour: return @"m60";
        case BarTimeframeDaily: return @"d1";
        case BarTimeframeWeekly: return @"w1";
        case BarTimeframeMonthly: return @"mo1";
        default: return @"d1";
    }
}

- (NSInteger)calculateBarCountFromStartDate:(NSDate *)startDate
                                   endDate:(NSDate *)endDate
                                 timeframe:(BarTimeframe)timeframe {
    // Calculate approximate number of bars needed
    NSTimeInterval interval = [endDate timeIntervalSinceDate:startDate];
    NSInteger bars = 100; // Default
    
    switch (timeframe) {
        case BarTimeframe1Min: bars = interval / 60; break;
        case BarTimeframe5Min: bars = interval / (60 * 5); break;
        case BarTimeframe15Min: bars = interval / (60 * 15); break;
        case BarTimeframe30Min: bars = interval / (60 * 30); break;
        case BarTimeframe1Hour: bars = interval / (60 * 60); break;
        case BarTimeframeDaily: bars = interval / (60 * 60 * 24); break;
        case BarTimeframeWeekly: bars = interval / (60 * 60 * 24 * 7); break;
        case BarTimeframeMonthly: bars = interval / (60 * 60 * 24 * 30); break;
    }
    
    return MAX(1, MIN(bars, 800)); // Webull limit
}

#pragma mark - Rate Limiting

- (NSInteger)remainingRequests {
    return 100; // Webull doesn't provide rate limit info
}

- (NSDate *)rateLimitResetDate {
    return [NSDate dateWithTimeIntervalSinceNow:60]; // Assume 1 minute
}

@end
