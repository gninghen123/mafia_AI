//
//  OtherDataSource.m
//  TradingApp
//

#import "OtherDataSource.h"
#import "CommonTypes.h"

// Nasdaq API Endpoints
static NSString *const kNasdaq52WeekHighURL = @"https://api.nasdaq.com/api/quote/list-type/FIFTYTWOWEEKHILOW?&queryString=exchange%3Dq%7Cstatus%3DHi&limit=99999&sortColumn=symbol&sortOrder=ASC";
static NSString *const kNasdaqInstitutionalSearchURL = @"https://api.nasdaq.com/api/company/search-ownership";
static NSString *const kNasdaqStocksListURL = @"https://api.nasdaq.com/api/screener/stocks?tableonly=true&download=true";
static NSString *const kNasdaqETFListURL = @"https://api.nasdaq.com/api/screener/etf?download=true";
static NSString *const kNasdaqEarningsCalendarURL = @"https://api.nasdaq.com/api/calendar/earnings";
static NSString *const kNasdaqEarningsSurpriseURL = @"https://api.nasdaq.com/api/quote/list-type-extended/daily_earnings_surprise";
static NSString *const kNasdaqNewsURL = @"https://api.nasdaq.com/api/news/topic/articlebysymbol";
static NSString *const kNasdaqPressReleaseURL = @"https://api.nasdaq.com/api/news/topic/press_release";
static NSString *const kNasdaqFinancialsURL = @"https://api.nasdaq.com/api/company/%@/financials";
static NSString *const kNasdaqPEGRatioURL = @"https://api.nasdaq.com/api/analyst/%@/peg-ratio";
static NSString *const kNasdaqShortInterestURL = @"https://api.nasdaq.com/api/quote/%@/short-interest";
static NSString *const kNasdaqInsiderTradesURL = @"https://api.nasdaq.com/api/company/%@/insider-trades";
static NSString *const kNasdaqInstitutionalURL = @"https://api.nasdaq.com/api/company/%@/institutional-holdings";
static NSString *const kNasdaqSECFilingsURL = @"https://api.nasdaq.com/api/company/%@/sec-filings";
static NSString *const kNasdaqRevenueURL = @"https://api.nasdaq.com/api/company/%@/revenue";
static NSString *const kNasdaqPriceTargetURL = @"https://api.nasdaq.com/api/analyst/%@/targetprice";
static NSString *const kNasdaqRatingsURL = @"https://api.nasdaq.com/api/analyst/%@/ratings";
static NSString *const kNasdaqEarningsDateURL = @"https://api.nasdaq.com/api/analyst/%@/earnings-date";
static NSString *const kNasdaqEPSURL = @"https://api.nasdaq.com/api/quote/%@/eps";
static NSString *const kNasdaqEarningsSurpriseSymbolURL = @"https://api.nasdaq.com/api/company/%@/earnings-surprise";
static NSString *const kNasdaqEarningsForecastURL = @"https://api.nasdaq.com/api/analyst/%@/earnings-forecast";
static NSString *const kNasdaqAnalystMomentumURL = @"https://api.nasdaq.com/api/analyst/%@/estimate-momentum";

// Finviz Endpoints
static NSString *const kFinvizStatementURL = @"https://finviz.com/api/statement.ashx";

// Zacks Endpoints
static NSString *const kZacksChartURL = @"https://www.zacks.com//data_handler/charts/";

// OpenInsider Endpoints
static NSString *const kOpenInsiderURL = @"http://openinsider.com/ps_data.csv";

// StockCatalyst Endpoints
static NSString *const kStockCatalystURL = @"https://www.thestockcatalyst.com/NYSEPMMovers?ShowFloats=true";

// Google Finance News RSS
static NSString *const kGoogleFinanceNewsURL = @"https://www.google.com/finance/company_news?q=%@&output=rss";

// SEC EDGAR Filings Atom Feed
static NSString *const kSECEdgarFilingsURL = @"https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=%@&type=&dateb=&owner=exclude&start=0&count=40&output=atom";

// Yahoo Finance News RSS
static NSString *const kYahooFinanceNewsURL = @"https://finance.yahoo.com/rss/headline?s=%@";

// Seeking Alpha RSS Feed
static NSString *const kSeekingAlphaNewsURL = @"https://seekingalpha.com/api/sa/combined/%@.xml";


@interface OtherDataSource ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *requestCount;
@property (nonatomic, strong) NSDate *lastResetTime;

// Protocol properties
@property (nonatomic, readwrite) DataSourceType sourceType;
@property (nonatomic, readwrite) DataSourceCapabilities capabilities;
@property (nonatomic, readwrite) NSString *sourceName;
@property (nonatomic, readwrite) BOOL isConnected;
@end

@implementation OtherDataSource

@synthesize sourceType = _sourceType;
@synthesize capabilities = _capabilities;
@synthesize sourceName = _sourceName;
@synthesize isConnected = _isConnected;

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourceType = DataSourceTypeOther;
        _sourceName = @"Other APIs (Yahoo/Nasdaq/Finviz/Zacks)"; // ✅ UPDATED: Include Yahoo
        _capabilities = DataSourceCapabilityQuotes |
                       DataSourceCapabilityNews |
        DataSourceCapabilityFundamentals ;
        _isConnected = YES; // No authentication required
        
        _requestCount = [NSMutableDictionary dictionary];
        _lastResetTime = [NSDate date];
        
        // Configure session with random user agents
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPAdditionalHeaders = [self randomUserAgentHeaders];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 60.0;
        
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

#pragma mark - DataSource Protocol

- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    // No authentication needed - always connected
    if (completion) {
        completion(YES, nil);
    }
}

- (void)disconnect {
    [self.session invalidateAndCancel];
    self.isConnected = NO;
}


#pragma mark - Yahoo Finance Quotes (FALLBACK)

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"No symbol provided"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSLog(@"📊 OtherDataSource: Fetching single quote for %@ using Yahoo Finance", symbol);
    
    // Use batch quotes method with single symbol for consistency
    [self fetchQuotesForSymbols:@[symbol] completion:^(NSDictionary *quotes, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            // Return the single quote data
            NSDictionary *singleQuote = quotes[symbol];
            if (completion) completion(singleQuote, nil);
        }
    }];
}

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    if (!symbols || symbols.count == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"No symbols provided"}];
        if (completion) completion(@{}, error);
        return;
    }
    
    NSLog(@"📊 OtherDataSource: Fetching batch quotes for %lu symbols using Yahoo Finance", (unsigned long)symbols.count);
    
    // Yahoo Finance CSV API URL
    // Format: http://finance.yahoo.com/d/quotes.csv?s=AAPL+MSFT+GOOG&f=snl1c1p2ohgvt1
    // Fields: s=symbol, n=name, l1=last, c1=change, p2=change%, o=open, h=high, g=low, v=volume, t1=time
    
    NSString *symbolsString = [symbols componentsJoinedByString:@"+"];
    NSString *fields = @"snl1c1p2ohgvt1ab"; // symbol,name,last,change,change%,open,high,low,volume,time,ask,bid
    
    NSString *urlString = [NSString stringWithFormat:@"http://finance.yahoo.com/d/quotes.csv?s=%@&f=%@",
                          [symbolsString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                          fields];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSLog(@"📊 OtherDataSource: Yahoo URL: %@", urlString);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:30.0];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            NSLog(@"❌ OtherDataSource: Yahoo Finance request failed: %@", error.localizedDescription);
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(@{}, error);
                });
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"OtherDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Yahoo Finance HTTP error: %ld", (long)httpResponse.statusCode]}];
            NSLog(@"❌ OtherDataSource: Yahoo Finance HTTP error %ld", (long)httpResponse.statusCode);
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(@{}, httpError);
                });
            }
            return;
        }
        
        // Parse CSV response
        NSString *csvString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!csvString || csvString.length == 0) {
            NSError *parseError = [NSError errorWithDomain:@"OtherDataSource"
                                                      code:500
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Empty response from Yahoo Finance"}];
            NSLog(@"❌ OtherDataSource: Empty CSV response from Yahoo Finance");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(@{}, parseError);
                });
            }
            return;
        }
        
        NSDictionary *quotesDict = [self parseYahooCSVResponse:csvString forSymbols:symbols];
        
        NSLog(@"✅ OtherDataSource: Successfully parsed %lu quotes from Yahoo Finance", (unsigned long)quotesDict.count);
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(quotesDict, nil);
            });
        }
    }];
    
    [task resume];
}

#pragma mark - Yahoo CSV Parser

- (NSDictionary *)parseYahooCSVResponse:(NSString *)csvString forSymbols:(NSArray<NSString *> *)symbols {
    NSMutableDictionary *quotes = [NSMutableDictionary dictionary];
    
    // Split CSV into lines
    NSArray *lines = [csvString componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedLine.length == 0) continue;
        
        // Parse CSV line (handle quoted fields)
        NSArray *fields = [self parseCSVLine:trimmedLine];
        if (fields.count < 12) {
            NSLog(@"⚠️ OtherDataSource: Invalid CSV line (expected 12 fields, got %lu): %@", (unsigned long)fields.count, trimmedLine);
            continue;
        }
        
        // Field mapping for Yahoo CSV:
        // 0=symbol, 1=name, 2=last, 3=change, 4=change%, 5=open, 6=high, 7=low, 8=volume, 9=time, 10=ask, 11=bid
        
        NSString *symbol = [self cleanCSVField:fields[0]];
        if (!symbol || ![symbols containsObject:symbol]) {
            continue;
        }
        
        // Build quote dictionary
        NSMutableDictionary *quote = [NSMutableDictionary dictionary];
        quote[@"symbol"] = symbol;
        quote[@"name"] = [self cleanCSVField:fields[1]];
        quote[@"last"] = [self parseYahooNumber:fields[2]];
        quote[@"change"] = [self parseYahooNumber:fields[3]];
        quote[@"changePercent"] = [self parseYahooNumber:fields[4]];
        quote[@"open"] = [self parseYahooNumber:fields[5]];
        quote[@"high"] = [self parseYahooNumber:fields[6]];
        quote[@"low"] = [self parseYahooNumber:fields[7]];
        quote[@"volume"] = [self parseYahooNumber:fields[8]];
        quote[@"time"] = [self cleanCSVField:fields[9]];
        quote[@"ask"] = [self parseYahooNumber:fields[10]];
        quote[@"bid"] = [self parseYahooNumber:fields[11]];
        
        // Add timestamp
        quote[@"timestamp"] = [NSDate date];
        
        // Calculate previous close from last and change
        NSNumber *last = quote[@"last"];
        NSNumber *change = quote[@"change"];
        if (last && change) {
            double previousClose = [last doubleValue] - [change doubleValue];
            quote[@"previousClose"] = @(previousClose);
        }
        
        quotes[symbol] = [quote copy];
    }
    
    return [quotes copy];
}

#pragma mark - CSV Parsing Helpers

- (NSArray *)parseCSVLine:(NSString *)line {
    NSMutableArray *fields = [NSMutableArray array];
    NSMutableString *currentField = [NSMutableString string];
    BOOL inQuotes = NO;
    
    for (NSInteger i = 0; i < line.length; i++) {
        unichar c = [line characterAtIndex:i];
        
        if (c == '"') {
            inQuotes = !inQuotes;
        } else if (c == ',' && !inQuotes) {
            [fields addObject:[currentField copy]];
            [currentField setString:@""];
        } else {
            [currentField appendFormat:@"%c", c];
        }
    }
    
    // Add last field
    [fields addObject:[currentField copy]];
    
    return [fields copy];
}

- (NSString *)cleanCSVField:(NSString *)field {
    if (!field) return @"";
    
    // Remove quotes and trim whitespace
    NSString *cleaned = [field stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([cleaned hasPrefix:@"\""] && [cleaned hasSuffix:@"\""]) {
        cleaned = [cleaned substringWithRange:NSMakeRange(1, cleaned.length - 2)];
    }
    
    // Replace "N/A" with empty string
    if ([cleaned isEqualToString:@"N/A"]) {
        return @"";
    }
    
    return cleaned;
}

- (NSNumber *)parseYahooNumber:(NSString *)field {
    NSString *cleaned = [self cleanCSVField:field];
    if (!cleaned || cleaned.length == 0) {
        return @(0.0);
    }
    
    // Remove percentage sign if present
    if ([cleaned hasSuffix:@"%"]) {
        cleaned = [cleaned substringToIndex:cleaned.length - 1];
    }
    
    // Try to parse as number
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *number = [formatter numberFromString:cleaned];
    
    return number ?: @(0.0);
}

#pragma mark - Market List Dispatcher (DataSource Protocol)

- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion {
    
    switch (listType) {
        case DataRequestType52WeekHigh:
            [self fetch52WeekHighsWithCompletion:completion];
            break;
            
        case DataRequestTypeStocksList:
            [self fetchStocksListWithCompletion:completion];
            break;
            
        case DataRequestTypeETFList:
            [self fetchETFListWithCompletion:completion];
            break;
            
        case DataRequestTypeEarningsCalendar: {
            NSString *date = parameters[@"date"] ?: [self todayDateString];
            [self fetchEarningsCalendarForDate:date completion:completion];
            break;
        }
            
        case DataRequestTypeEarningsSurprise: {
            NSString *date = parameters[@"date"] ?: [self todayDateString];
            [self fetchEarningsSurpriseForDate:date completion:completion];
            break;
        }
            
        case DataRequestTypeInstitutionalTx: {
            NSInteger type = [parameters[@"type"] integerValue] ?: 1;
            NSInteger limit = [parameters[@"limit"] integerValue] ?: 20;
            [self fetchInstitutionalTransactionsWithType:type limit:limit completion:completion];
            break;
        }
            
        case DataRequestTypePMMovers:
            [self fetchPrePostMarketMoversWithCompletion:completion];
            break;
            
        default: {
            NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                       [NSString stringWithFormat:@"Unsupported market list type: %ld", (long)listType]}];
            if (completion) completion(nil, error);
            break;
        }
    }
}

#pragma mark - Market Overview Data

- (void)fetch52WeekHighsWithCompletion:(void (^)(NSArray *results, NSError *error))completion {
    [self executeNasdaqRequest:kNasdaq52WeekHighURL completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *results = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *result = @{
                @"symbol": item[@"symbol"] ?: @"",
                @"lastSale": item[@"lastSale"] ?: @0,
                @"netChange": item[@"netchange"] ?: @0,
                @"pctChange": item[@"pctchange"] ?: @0,
                @"volume": item[@"volume"] ?: @0,
                @"marketCap": item[@"marketCap"] ?: @0
            };
            [results addObject:result];
        }
        
        if (completion) completion(results, nil);
    }];
}

- (void)fetchStocksListWithCompletion:(void (^)(NSArray *stocks, NSError *error))completion {
    [self executeNasdaqRequest:kNasdaqStocksListURL completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *stocks = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *stock = @{
                @"symbol": item[@"symbol"] ?: @"",
                @"name": item[@"name"] ?: @"",
                @"lastsale": item[@"lastsale"] ?: @0,
                @"netchange": item[@"netchange"] ?: @0,
                @"pctchange": item[@"pctchange"] ?: @0,
                @"volume": item[@"volume"] ?: @0,
                @"marketCap": item[@"marketCap"] ?: @0,
                @"country": item[@"country"] ?: @"",
                @"ipoyear": item[@"ipoyear"] ?: @"",
                @"industry": item[@"industry"] ?: @"",
                @"sector": item[@"sector"] ?: @""
            };
            [stocks addObject:stock];
        }
        
        if (completion) completion(stocks, nil);
    }];
}

- (void)fetchETFListWithCompletion:(void (^)(NSArray *etfs, NSError *error))completion {
    [self executeNasdaqRequest:kNasdaqETFListURL completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *etfs = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *etf = @{
                @"symbol": item[@"symbol"] ?: @"",
                @"companyName": item[@"companyName"] ?: @"",
                @"lastSale": item[@"lastSale"] ?: @0,
                @"netChange": item[@"netChange"] ?: @0,
                @"pctChange": item[@"pctChange"] ?: @0,
                @"volume": item[@"volume"] ?: @0
            };
            [etfs addObject:etf];
        }
        
        if (completion) completion(etfs, nil);
    }];
}

- (void)fetchEarningsCalendarForDate:(NSString *)date
                          completion:(void (^)(NSArray *earnings, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?date=%@", kNasdaqEarningsCalendarURL, date];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *earnings = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *earning = @{
                @"symbol": item[@"symbol"] ?: @"",
                @"companyName": item[@"companyName"] ?: @"",
                @"epsForecast": item[@"epsForecast"] ?: @0,
                @"noOfEsts": item[@"noOfEsts"] ?: @0,
                @"time": item[@"time"] ?: @"",
                @"lastYearEPS": item[@"lastYearEPS"] ?: @0,
                @"lastYearDate": item[@"lastYearDate"] ?: @""
            };
            [earnings addObject:earning];
        }
        
        if (completion) completion(earnings, nil);
    }];
}

- (void)fetchEarningsSurpriseForDate:(NSString *)date
                          completion:(void (^)(NSArray *surprises, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?queryString=date=%@", kNasdaqEarningsSurpriseURL, date];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *surprises = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *surprise = @{
                @"symbol": item[@"symbol"] ?: @"",
                @"companyName": item[@"companyName"] ?: @"",
                @"eps": item[@"eps"] ?: @0,
                @"epsEstimate": item[@"epsEstimate"] ?: @0,
                @"epsSurprise": item[@"epsSurprise"] ?: @0,
                @"epsSurprisePct": item[@"epsSurprisePct"] ?: @0,
                @"time": item[@"time"] ?: @""
            };
            [surprises addObject:surprise];
        }
        
        if (completion) completion(surprises, nil);
    }];
}

- (void)fetchInstitutionalTransactionsWithType:(NSInteger)type
                                         limit:(NSInteger)limit
                                    completion:(void (^)(NSArray *transactions, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?&type=%ld&searchonly=false&limit=%ld",
                          kNasdaqInstitutionalSearchURL, (long)type, (long)limit];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *transactions = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *transaction = @{
                @"symbol": item[@"symbol"] ?: @"",
                @"companyName": item[@"companyName"] ?: @"",
                @"ownerName": item[@"ownerName"] ?: @"",
                @"sharesTraded": item[@"sharesTraded"] ?: @0,
                @"lastPrice": item[@"lastPrice"] ?: @0,
                @"transactionValue": item[@"transactionValue"] ?: @0,
                @"transactionType": item[@"transactionType"] ?: @"",
                @"filingDate": item[@"filingDate"] ?: @""
            };
            [transactions addObject:transaction];
        }
        
        if (completion) completion(transactions, nil);
    }];
}

- (void)fetchPrePostMarketMoversWithCompletion:(void (^)(NSArray *movers, NSError *error))completion {
    [self scrapeStockCatalyst:completion];
}

#pragma mark - Company Specific Data

- (void)fetchNewsForSymbol:(NSString *)symbol
                     limit:(NSInteger)limit
                completion:(void (^)(NSArray *news, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?q=%@|stocks&offset=0&limit=%ld&fallback=false",
                          kNasdaqNewsURL, symbol, (long)limit];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *news = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *newsItem = @{
                @"headline": item[@"headline"] ?: @"",
                @"summary": item[@"summary"] ?: @"",
                @"publishedDate": item[@"publishedDate"] ?: @"",
                @"url": item[@"url"] ?: @"",
                @"source": item[@"source"] ?: @""
            };
            [news addObject:newsItem];
        }
        
        if (completion) completion(news, nil);
    }];
}

- (void)fetchPressReleasesForSymbol:(NSString *)symbol
                              limit:(NSInteger)limit
                         completion:(void (^)(NSArray *releases, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?q=symbol:%@|assetclass:stocks&limit=%ld&offset=0",
                          kNasdaqPressReleaseURL, symbol, (long)limit];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *releases = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *release = @{
                @"headline": item[@"headline"] ?: @"",
                @"summary": item[@"summary"] ?: @"",
                @"publishedDate": item[@"publishedDate"] ?: @"",
                @"url": item[@"url"] ?: @"",
                @"source": item[@"source"] ?: @""
            };
            [releases addObject:release];
        }
        
        if (completion) completion(releases, nil);
    }];
}

- (void)fetchFinancialsForSymbol:(NSString *)symbol
                       frequency:(NSInteger)frequency
                      completion:(void (^)(NSDictionary *financials, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqFinancialsURL, symbol];
    urlString = [NSString stringWithFormat:@"%@?frequency=%ld", urlString, (long)frequency];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

- (void)fetchPEGRatioForSymbol:(NSString *)symbol
                    completion:(void (^)(NSDictionary *pegData, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqPEGRatioURL, symbol];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

- (void)fetchPriceTargetForSymbol:(NSString *)symbol
                       completion:(void (^)(NSDictionary *target, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqPriceTargetURL, symbol];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

- (void)fetchRatingsForSymbol:(NSString *)symbol
                   completion:(void (^)(NSArray *ratings, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqRatingsURL, symbol];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *ratings = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *rating = @{
                @"firm": item[@"firm"] ?: @"",
                @"rating": item[@"rating"] ?: @"",
                @"priceTarget": item[@"priceTarget"] ?: @0,
                @"date": item[@"date"] ?: @"",
                @"action": item[@"action"] ?: @""
            };
            [ratings addObject:rating];
        }
        
        if (completion) completion(ratings, nil);
    }];
}

- (void)fetchShortInterestForSymbol:(NSString *)symbol
                         completion:(void (^)(NSDictionary *shortData, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?assetClass=stocks",
                          [NSString stringWithFormat:kNasdaqShortInterestURL, symbol]];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

- (void)fetchInsiderTradesForSymbol:(NSString *)symbol
                              limit:(NSInteger)limit
                         completion:(void (^)(NSArray *trades, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?limit=%ld&type=ALL&sortColumn=lastDate&sortOrder=DESC",
                          [NSString stringWithFormat:kNasdaqInsiderTradesURL, symbol], (long)limit];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *trades = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *trade = @{
                @"insider": item[@"insider"] ?: @"",
                @"relation": item[@"relation"] ?: @"",
                @"lastDate": item[@"lastDate"] ?: @"",
                @"transactionType": item[@"transactionType"] ?: @"",
                @"ownershipType": item[@"ownershipType"] ?: @"",
                @"sharesTraded": item[@"sharesTraded"] ?: @0,
                @"lastPrice": item[@"lastPrice"] ?: @0,
                @"sharesHeld": item[@"sharesHeld"] ?: @0
            };
            [trades addObject:trade];
        }
        
        if (completion) completion(trades, nil);
    }];
}

- (void)fetchInstitutionalHoldingsForSymbol:(NSString *)symbol
                                      limit:(NSInteger)limit
                                 completion:(void (^)(NSArray *holdings, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?limit=%ld&type=TOTAL&sortColumn=marketValue&sortOrder=DESC",
                          [NSString stringWithFormat:kNasdaqInstitutionalURL, symbol], (long)limit];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *holdings = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *holding = @{
                @"institutionName": item[@"institutionName"] ?: @"",
                @"sharesHeld": item[@"sharesHeld"] ?: @0,
                @"marketValue": item[@"marketValue"] ?: @0,
                @"percentHeld": item[@"percentHeld"] ?: @0,
                @"reportDate": item[@"reportDate"] ?: @"",
                @"change": item[@"change"] ?: @0,
                @"changePercent": item[@"changePercent"] ?: @0
            };
            [holdings addObject:holding];
        }
        
        if (completion) completion(holdings, nil);
    }];
}

- (void)fetchSECFilingsForSymbol:(NSString *)symbol
                           limit:(NSInteger)limit
                      completion:(void (^)(NSArray *filings, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?limit=%ld&sortColumn=filed&sortOrder=desc&IsQuoteMedia=true",
                          [NSString stringWithFormat:kNasdaqSECFilingsURL, symbol], (long)limit];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *filings = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *filing = @{
                @"form": item[@"form"] ?: @"",
                @"description": item[@"description"] ?: @"",
                @"filed": item[@"filed"] ?: @"",
                @"period": item[@"period"] ?: @"",
                @"url": item[@"url"] ?: @""
            };
            [filings addObject:filing];
        }
        
        if (completion) completion(filings, nil);
    }];
}

- (void)fetchRevenueForSymbol:(NSString *)symbol
                        limit:(NSInteger)limit
                   completion:(void (^)(NSDictionary *revenue, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?limit=%ld",
                          [NSString stringWithFormat:kNasdaqRevenueURL, symbol], (long)limit];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

- (void)fetchEPSForSymbol:(NSString *)symbol
               completion:(void (^)(NSDictionary *eps, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqEPSURL, symbol];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

- (void)fetchEarningsDateForSymbol:(NSString *)symbol
                        completion:(void (^)(NSDictionary *earningsDate, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqEarningsDateURL, symbol];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

- (void)fetchEarningsSurpriseForSymbol:(NSString *)symbol
                            completion:(void (^)(NSArray *surprises, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqEarningsSurpriseSymbolURL, symbol];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *data = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *surprises = [NSMutableArray array];
        
        for (NSDictionary *item in data) {
            NSDictionary *surprise = @{
                @"reportDate": item[@"reportDate"] ?: @"",
                @"fiscalQuarterEnding": item[@"fiscalQuarterEnding"] ?: @"",
                @"eps": item[@"eps"] ?: @0,
                @"epsEstimate": item[@"epsEstimate"] ?: @0,
                @"epsSurprise": item[@"epsSurprise"] ?: @0,
                @"epsSurprisePct": item[@"epsSurprisePct"] ?: @0
            };
            [surprises addObject:surprise];
        }
        
        if (completion) completion(surprises, nil);
    }];
}

- (void)fetchEarningsForecastForSymbol:(NSString *)symbol
                            completion:(void (^)(NSDictionary *forecast, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqEarningsForecastURL, symbol];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

- (void)fetchAnalystMomentumForSymbol:(NSString *)symbol
                           completion:(void (^)(NSDictionary *momentum, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:kNasdaqAnalystMomentumURL, symbol];
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *data = response;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"data"]) {
            data = response[@"data"];
        }
        
        if (completion) completion(data, nil);
    }];
}

#pragma mark - Finviz Data

- (void)fetchFinvizStatementForSymbol:(NSString *)symbol
                            statement:(NSString *)statement
                           completion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?t=%@&so=F&s=%@",
                          kFinvizStatementURL, symbol, statement];
    
    [self executeGenericRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Finviz returns data in different format - may need custom parsing
        NSDictionary *data = @{@"raw_data": response};
        if (completion) completion(data, nil);
    }];
}

#pragma mark - Zacks Data

- (void)fetchZacksFundamentalChartForSymbol:(NSString *)symbol
                         wrapper:(NSString *)wrapper
                      completion:(void (^)(NSDictionary *chartData, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@?ticker=%@&wrapper=%@",
                          kZacksChartURL, symbol, wrapper];
    
    // Usa il nuovo metodo per Zacks
    [self executeZacksRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        if (completion) completion(response, nil);
    }];
}

#pragma mark - Web Scraping Data

- (void)fetchOpenInsiderDataWithCompletion:(void (^)(NSArray *insiderData, NSError *error))completion {
    [self executeGenericRequest:kOpenInsiderURL completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Parse CSV data
        NSArray *insiderData = [self parseOpenInsiderCSV:response];
        if (completion) completion(insiderData, nil);
    }];
}

- (void)scrapeStockCatalyst:(void (^)(NSArray *movers, NSError *error))completion {
    [self executeGenericRequest:kStockCatalystURL completion:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Parse HTML table
        NSArray *movers = [self parseStockCatalystHTML:response];
        if (completion) completion(movers, nil);
    }];
}

#pragma mark - Helper Methods

- (void)executeNasdaqRequest:(NSString *)urlString
                  completion:(void (^)(id response, NSError *error))completion {
    
    if (![self checkRateLimit:@"nasdaq"]) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:429
                                         userInfo:@{NSLocalizedDescriptionKey: @"Rate limit exceeded for Nasdaq API"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    // Add Nasdaq-specific headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self incrementRequestCount:@"nasdaq"];
        
        if (error) {
            NSLog(@"Nasdaq API error: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"OtherDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey:
                                                           [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            if (completion) completion(nil, httpError);
            return;
        }
        
        NSError *jsonError;
        id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            NSLog(@"JSON parsing error: %@", jsonError.localizedDescription);
            if (completion) completion(nil, jsonError);
            return;
        }
        
        if (completion) completion(jsonResponse, nil);
    }] resume];
}

- (void)executeGenericRequest:(NSString *)urlString
                   completion:(void (^)(id response, NSError *error))completion {
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    // Rotate user agent to avoid blocking
    NSDictionary *headers = [self randomUserAgentHeaders];
    for (NSString *key in headers.allKeys) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Generic request error: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"OtherDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey:
                                                           [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            if (completion) completion(nil, httpError);
            return;
        }
        
        // Try JSON first, fallback to string
        NSError *jsonError;
        id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            // Return as string for HTML/CSV content
            NSString *stringResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (completion) completion(stringResponse, nil);
        } else {
            if (completion) completion(jsonResponse, nil);
        }
    }] resume];
}

- (void)executeZacksRequest:(NSString *)urlString
                 completion:(void (^)(id response, NSError *error))completion {
    
    NSLog(@"🔍 OtherDataSource: Making Zacks request to: %@", urlString);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *err = nil;
        NSString *responseString = [NSString stringWithContentsOfURL:[NSURL URLWithString:urlString]
                                                            encoding:NSUTF8StringEncoding
                                                               error:&err];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err) {
                NSLog(@"❌ Zacks request error: %@", err.localizedDescription);
                if (completion) completion(nil, err);
                return;
            }

            if (!responseString) {
                NSError *encodingError = [NSError errorWithDomain:@"OtherDataSource"
                                                             code:500
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode response"}];
                NSLog(@"❌ Zacks encoding error");
                if (completion) completion(nil, encodingError);
                return;
            }

            NSLog(@"🔍 Zacks raw response (first 200 chars): %@", [responseString substringToIndex:MIN(200, responseString.length)]);
            
            // Try to parse as JSON
            NSData *data = [responseString dataUsingEncoding:NSUTF8StringEncoding];
            NSError *jsonError = nil;
            id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            if (!jsonError && jsonResponse) {
                NSLog(@"✅ Zacks response parsed as JSON successfully");
                if (completion) completion(jsonResponse, nil);
                return;
            }

            NSLog(@"⚠️ Zacks JSON parsing failed: %@", jsonError.localizedDescription);
            NSLog(@"Trying to extract JSON from JSONP/JavaScript...");
            
            NSDictionary *extractedJSON = [self extractJSONFromZacksResponse:responseString];
            if (extractedJSON) {
                NSLog(@"✅ Zacks JSON extracted from JSONP/JavaScript");
                if (completion) completion(extractedJSON, nil);
            } else {
                NSLog(@"❌ Failed to extract JSON from Zacks response");
                NSError *parseError = [NSError errorWithDomain:@"OtherDataSource"
                                                          code:500
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse Zacks response"}];
                if (completion) completion(nil, parseError);
            }
        });
    });
}
// Metodo per estrarre JSON da JSONP o JavaScript - VERSIONE MIGLIORATA
- (NSDictionary *)extractJSONFromZacksResponse:(NSString *)responseString {
    if (!responseString || responseString.length == 0) return nil;
    
    NSLog(@"🔍 Full response length: %lu", (unsigned long)responseString.length);
    
    // Prima cerca direttamente il pattern del JSON che hai mostrato
    // Pattern: {"revenue":{"06\/30\/25":"N\/A",...}}
    
    // Trova l'inizio del JSON con chiave specifica (revenue, eps_diluted, etc)
    NSRange jsonStart = [responseString rangeOfString:@"{\""];
    if (jsonStart.location == NSNotFound) {
        NSLog(@"❌ No JSON start found");
        return nil;
    }
    
    // Trova la fine del JSON - cerca l'ultima parentesi graffa
    NSString *fromStart = [responseString substringFromIndex:jsonStart.location];
    NSRange jsonEnd = [fromStart rangeOfString:@"}}" options:NSBackwardsSearch];
    
    if (jsonEnd.location == NSNotFound) {
        // Prova con una sola parentesi graffa
        jsonEnd = [fromStart rangeOfString:@"}" options:NSBackwardsSearch];
        if (jsonEnd.location == NSNotFound) {
            NSLog(@"❌ No JSON end found");
            return nil;
        }
    }
    
    // Estrai il JSON
    NSString *jsonString = [fromStart substringToIndex:jsonEnd.location + jsonEnd.length];
    
    NSLog(@"🔍 Extracted JSON (first 200 chars): %@", [jsonString substringToIndex:MIN(200, jsonString.length)]);
    
    // Pulisci gli escape characters
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    
    return [self parseJSONString:jsonString];
}

// Helper per parsing JSON string - VERSIONE MIGLIORATA
- (NSDictionary *)parseJSONString:(NSString *)jsonString {
    if (!jsonString || jsonString.length == 0) return nil;
    
    NSLog(@"🔍 Attempting to parse JSON (length: %lu)", (unsigned long)jsonString.length);
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) {
        NSLog(@"❌ Failed to convert string to data");
        return nil;
    }
    
    NSError *error;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                    options:NSJSONReadingAllowFragments
                                                      error:&error];
    
    if (error) {
        NSLog(@"❌ JSON parsing error: %@", error.localizedDescription);
        
        // Debug: mostra caratteri problematici
        NSLog(@"JSON string preview: %@", [jsonString substringToIndex:MIN(500, jsonString.length)]);
        
        // Prova a pulire ulteriormente il JSON
        NSString *cleanedJSON = [self cleanZacksJSON:jsonString];
        if (cleanedJSON && ![cleanedJSON isEqualToString:jsonString]) {
            NSLog(@"🔧 Trying with cleaned JSON...");
            return [self parseJSONString:cleanedJSON];
        }
        
        return nil;
    }
    
    if ([jsonObject isKindOfClass:[NSDictionary class]]) {
        NSLog(@"✅ Successfully parsed JSON with keys: %@", [(NSDictionary *)jsonObject allKeys]);
        return (NSDictionary *)jsonObject;
    }
    
    NSLog(@"❌ JSON object is not a dictionary: %@", [jsonObject class]);
    return nil;
}

// Nuovo metodo per pulire il JSON di Zacks
- (NSString *)cleanZacksJSON:(NSString *)rawJSON {
    if (!rawJSON) return nil;
    
    NSString *cleaned = rawJSON;
    
    // Rimuovi caratteri di controllo invisibili
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    
    // Rimuovi spazi extra
    cleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Fix common escape issues
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
    
    return cleaned;
}

- (NSArray *)extractDataFromNasdaqResponse:(id)response {
    if ([response isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)response;
        
        // Try common Nasdaq response structures
        if (dict[@"data"] && [dict[@"data"] isKindOfClass:[NSArray class]]) {
            return dict[@"data"];
        }
        if (dict[@"data"] && [dict[@"data"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataDict = dict[@"data"];
            if (dataDict[@"rows"] && [dataDict[@"rows"] isKindOfClass:[NSArray class]]) {
                return dataDict[@"rows"];
            }
            if (dataDict[@"data"] && [dataDict[@"data"] isKindOfClass:[NSArray class]]) {
                return dataDict[@"data"];
            }
        }
        if (dict[@"rows"] && [dict[@"rows"] isKindOfClass:[NSArray class]]) {
            return dict[@"rows"];
        }
    }
    
    if ([response isKindOfClass:[NSArray class]]) {
        return (NSArray *)response;
    }
    
    return @[];
}

- (NSArray *)parseOpenInsiderCSV:(NSString *)csvString {
    NSMutableArray *results = [NSMutableArray array];
    
    NSArray *lines = [csvString componentsSeparatedByString:@"\n"];
    if (lines.count < 2) return results;
    
    // Skip header line
    for (NSInteger i = 1; i < lines.count; i++) {
        NSString *line = lines[i];
        if (line.length == 0) continue;
        
        NSArray *fields = [line componentsSeparatedByString:@","];
        if (fields.count >= 10) {
            NSDictionary *data = @{
                @"filing_date": fields[1] ?: @"",
                @"trade_date": fields[2] ?: @"",
                @"ticker": fields[3] ?: @"",
                @"company_name": fields[4] ?: @"",
                @"insider_name": fields[5] ?: @"",
                @"title": fields[6] ?: @"",
                @"trade_type": fields[7] ?: @"",
                @"price": fields[8] ?: @"",
                @"qty": fields[9] ?: @"",
                @"owned": fields[10] ?: @"",
                @"delta_own": fields[11] ?: @"",
                @"value": fields[12] ?: @""
            };
            [results addObject:data];
        }
    }
    
    return results;
}

- (NSArray *)parseStockCatalystHTML:(NSString *)htmlString {
    NSMutableArray *results = [NSMutableArray array];
    
    // Simple HTML table parsing for StockCatalyst
    // Look for table rows with stock data
    NSArray *lines = [htmlString componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        if ([line containsString:@"<tr"] && [line containsString:@"data-"]) {
            // Extract data from table row
            NSDictionary *mover = [self extractStockCatalystRowData:line];
            if (mover) {
                [results addObject:mover];
            }
        }
    }
    
    return results;
}

- (NSDictionary *)extractStockCatalystRowData:(NSString *)rowHTML {
    // Basic HTML parsing for table data
    // This is a simplified parser - for production use a proper HTML parser
    
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    
    // Extract symbol, price, change, volume etc. from HTML
    // Implementation would involve regex or HTML parsing library
    // For now, return empty to avoid parsing complexity
    
    return nil;
}

- (NSDictionary *)randomUserAgentHeaders {
    NSArray *userAgents = @[
        @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
        @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        @"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
    ];
    
    NSString *randomUA = userAgents[arc4random_uniform((uint32_t)userAgents.count)];
    
    return @{
        @"User-Agent": randomUA,
        @"Accept": @"text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        @"Accept-Language": @"en-US,en;q=0.5",
        @"Accept-Encoding": @"gzip, deflate, br",
        @"DNT": @"1",
        @"Connection": @"keep-alive",
        @"Upgrade-Insecure-Requests": @"1"
    };
}

- (BOOL)checkRateLimit:(NSString *)service {
    NSNumber *count = self.requestCount[service];
    if (!count) count = @0;
    
    // Reset counter every hour
    NSTimeInterval timeSinceReset = [[NSDate date] timeIntervalSinceDate:self.lastResetTime];
    if (timeSinceReset > 3600) { // 1 hour
        [self.requestCount removeAllObjects];
        self.lastResetTime = [NSDate date];
        return YES;
    }
    
    // Limit: 100 requests per hour per service
    return count.integerValue < 100;
}

- (void)incrementRequestCount:(NSString *)service {
    NSNumber *count = self.requestCount[service];
    if (!count) count = @0;
    
    self.requestCount[service] = @(count.integerValue + 1);
}

- (NSString *)todayDateString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter stringFromDate:[NSDate date]];
}

#pragma mark - Enhanced News Data Methods

/**
 * Fetch news from Google Finance RSS feed
 * @param symbol Stock symbol
 * @param completion Completion handler with parsed news array
 */
- (void)fetchGoogleFinanceNewsForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray *news, NSError *error))completion {
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:kGoogleFinanceNewsURL, symbol.uppercaseString];
    
    [self executeGenericRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"❌ Google Finance News error for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        // Parse RSS XML response
        NSArray *newsItems = [self parseRSSResponse:response forSymbol:symbol source:@"Google Finance"];
        
        NSLog(@"✅ Google Finance: Retrieved %lu news items for %@", (unsigned long)newsItems.count, symbol);
        if (completion) completion(newsItems, nil);
    }];
}

/**
 * Fetch SEC EDGAR filings from Atom feed
 * @param symbol Stock symbol (will be converted to CIK if needed)
 * @param completion Completion handler with parsed filings array
 */
- (void)fetchSECFilingsForSymbol:(NSString *)symbol
                      completion:(void (^)(NSArray *filings, NSError *error))completion {
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // For now, use symbol directly - in future we might need CIK lookup
    NSString *urlString = [NSString stringWithFormat:kSECEdgarFilingsURL, symbol.uppercaseString];
    
    [self executeGenericRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"❌ SEC EDGAR error for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        // Parse Atom XML response
        NSArray *filings = [self parseAtomResponse:response forSymbol:symbol source:@"SEC EDGAR"];
        
        NSLog(@"✅ SEC EDGAR: Retrieved %lu filings for %@", (unsigned long)filings.count, symbol);
        if (completion) completion(filings, nil);
    }];
}

/**
 * Fetch news from Yahoo Finance RSS feed
 * @param symbol Stock symbol
 * @param completion Completion handler with parsed news array
 */
- (void)fetchYahooFinanceNewsForSymbol:(NSString *)symbol
                            completion:(void (^)(NSArray *news, NSError *error))completion {
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:kYahooFinanceNewsURL, symbol.uppercaseString];
    
    [self executeGenericRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"❌ Yahoo Finance News error for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        // Parse RSS XML response
        NSArray *newsItems = [self parseRSSResponse:response forSymbol:symbol source:@"Yahoo Finance"];
        
        NSLog(@"✅ Yahoo Finance: Retrieved %lu news items for %@", (unsigned long)newsItems.count, symbol);
        if (completion) completion(newsItems, nil);
    }];
}

/**
 * Fetch news from Seeking Alpha RSS feed
 * @param symbol Stock symbol
 * @param completion Completion handler with parsed news array
 */
- (void)fetchSeekingAlphaNewsForSymbol:(NSString *)symbol
                            completion:(void (^)(NSArray *news, NSError *error))completion {
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:kSeekingAlphaNewsURL, symbol.uppercaseString];
    
    [self executeGenericRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"❌ Seeking Alpha News error for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        // Parse XML response (Seeking Alpha uses custom XML format)
        NSArray *newsItems = [self parseSeekingAlphaResponse:response forSymbol:symbol];
        
        NSLog(@"✅ Seeking Alpha: Retrieved %lu news items for %@", (unsigned long)newsItems.count, symbol);
        if (completion) completion(newsItems, nil);
    }];
}

#pragma mark - XML/RSS Parsing Helper Methods

/**
 * Parse RSS XML response to standardized news format
 */
- (NSArray *)parseRSSResponse:(NSString *)xmlString forSymbol:(NSString *)symbol source:(NSString *)source {
    if (!xmlString || xmlString.length == 0) {
        return @[];
    }
    
    NSMutableArray *newsItems = [NSMutableArray array];
    
    // Basic RSS parsing - in a production app, you'd use NSXMLParser
    // For now, we'll do simple string parsing as a proof of concept
    
    // Split by <item> tags
    NSArray *itemStrings = [xmlString componentsSeparatedByString:@"<item>"];
    
    for (NSInteger i = 1; i < itemStrings.count; i++) { // Skip first (header)
        NSString *itemString = itemStrings[i];
        
        // Extract title
        NSString *title = [self extractXMLValue:@"title" fromString:itemString];
        
        // Extract description
        NSString *description = [self extractXMLValue:@"description" fromString:itemString];
        
        // Extract link
        NSString *link = [self extractXMLValue:@"link" fromString:itemString];
        
        // Extract pubDate
        NSString *pubDate = [self extractXMLValue:@"pubDate" fromString:itemString];
        
        if (title && title.length > 0) {
            NSDictionary *newsItem = @{
                @"headline": title,
                @"summary": description ?: @"",
                @"url": link ?: @"",
                @"publishedDate": pubDate ?: @"",
                @"source": source,
                @"symbol": symbol.uppercaseString
            };
            [newsItems addObject:newsItem];
        }
    }
    
    return [newsItems copy];
}

/**
 * Parse Atom XML response to standardized news format
 */
- (NSArray *)parseAtomResponse:(NSString *)xmlString forSymbol:(NSString *)symbol source:(NSString *)source {
    if (!xmlString || xmlString.length == 0) {
        return @[];
    }
    
    NSMutableArray *filings = [NSMutableArray array];
    
    // Split by <entry> tags for Atom feeds
    NSArray *entryStrings = [xmlString componentsSeparatedByString:@"<entry>"];
    
    for (NSInteger i = 1; i < entryStrings.count; i++) { // Skip first (header)
        NSString *entryString = entryStrings[i];
        
        // Extract title
        NSString *title = [self extractXMLValue:@"title" fromString:entryString];
        
        // Extract summary
        NSString *summary = [self extractXMLValue:@"summary" fromString:entryString];
        
        // Extract link href
        NSString *link = [self extractAtomLink:entryString];
        
        // Extract updated date
        NSString *updated = [self extractXMLValue:@"updated" fromString:entryString];
        
        if (title && title.length > 0) {
            NSDictionary *filing = @{
                @"headline": title,
                @"summary": summary ?: @"",
                @"url": link ?: @"",
                @"publishedDate": updated ?: @"",
                @"source": source,
                @"symbol": symbol.uppercaseString,
                @"type": @"filing"
            };
            [filings addObject:filing];
        }
    }
    
    return [filings copy];
}

/**
 * Parse Seeking Alpha custom XML response
 */
- (NSArray *)parseSeekingAlphaResponse:(NSString *)xmlString forSymbol:(NSString *)symbol {
    if (!xmlString || xmlString.length == 0) {
        return @[];
    }
    
    NSMutableArray *newsItems = [NSMutableArray array];
    
    // Seeking Alpha uses a custom XML format - adapt as needed
    // This is a basic implementation that may need refinement
    
    NSArray *itemStrings = [xmlString componentsSeparatedByString:@"<item>"];
    
    for (NSInteger i = 1; i < itemStrings.count; i++) {
        NSString *itemString = itemStrings[i];
        
        NSString *title = [self extractXMLValue:@"title" fromString:itemString];
        NSString *description = [self extractXMLValue:@"description" fromString:itemString];
        NSString *link = [self extractXMLValue:@"link" fromString:itemString];
        NSString *pubDate = [self extractXMLValue:@"pubDate" fromString:itemString];
        
        if (title && title.length > 0) {
            NSDictionary *newsItem = @{
                @"headline": title,
                @"summary": description ?: @"",
                @"url": link ?: @"",
                @"publishedDate": pubDate ?: @"",
                @"source": @"Seeking Alpha",
                @"symbol": symbol.uppercaseString
            };
            [newsItems addObject:newsItem];
        }
    }
    
    return [newsItems copy];
}

#pragma mark - XML Parsing Utilities

/**
 * Extract XML tag value from string
 */
- (NSString *)extractXMLValue:(NSString *)tagName fromString:(NSString *)xmlString {
    NSString *openTag = [NSString stringWithFormat:@"<%@>", tagName];
    NSString *closeTag = [NSString stringWithFormat:@"</%@>", tagName];
    
    NSRange openRange = [xmlString rangeOfString:openTag];
    if (openRange.location == NSNotFound) {
        return nil;
    }
    
    NSRange searchRange = NSMakeRange(NSMaxRange(openRange), xmlString.length - NSMaxRange(openRange));
    NSRange closeRange = [xmlString rangeOfString:closeTag options:0 range:searchRange];
    if (closeRange.location == NSNotFound) {
        return nil;
    }
    
    NSRange valueRange = NSMakeRange(NSMaxRange(openRange), closeRange.location - NSMaxRange(openRange));
    NSString *value = [xmlString substringWithRange:valueRange];
    
    // Clean up HTML entities and CDATA
    value = [value stringByReplacingOccurrencesOfString:@"<![CDATA[" withString:@""];
    value = [value stringByReplacingOccurrencesOfString:@"]]>" withString:@""];
    value = [value stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    value = [value stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    value = [value stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    return value;
}

/**
 * Extract link href from Atom entry
 */
- (NSString *)extractAtomLink:(NSString *)entryString {
    NSRange linkRange = [entryString rangeOfString:@"<link"];
    if (linkRange.location == NSNotFound) {
        return nil;
    }
    
    NSRange hrefRange = [entryString rangeOfString:@"href=\"" options:0 range:NSMakeRange(linkRange.location, entryString.length - linkRange.location)];
    if (hrefRange.location == NSNotFound) {
        return nil;
    }
    
    NSUInteger startPos = NSMaxRange(hrefRange);
    NSRange quoteRange = [entryString rangeOfString:@"\"" options:0 range:NSMakeRange(startPos, entryString.length - startPos)];
    if (quoteRange.location == NSNotFound) {
        return nil;
    }
    
    NSRange urlRange = NSMakeRange(startPos, quoteRange.location - startPos);
    return [entryString substringWithRange:urlRange];
}



@end
