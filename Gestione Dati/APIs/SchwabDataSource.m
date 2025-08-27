
//
//  SchwabDataSource.m - IMPLEMENTAZIONE UNIFICATA
//  TradingApp
//

#import "SchwabDataSource.h"
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import "CommonTypes.h"

// API Configuration
static NSString *const kSchwabAPIBaseURL = @"https://api.schwabapi.com";
static NSString *const kSchwabAuthURL = @"https://api.schwabapi.com/v1/oauth/authorize";
static NSString *const kSchwabTokenURL = @"https://api.schwabapi.com/v1/oauth/token";

@interface SchwabDataSource ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSString *appKey;
@property (nonatomic, strong) NSString *appSecret;
@property (nonatomic, strong) NSString *callbackURL;
@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSString *refreshToken;
@property (nonatomic, strong) NSDate *tokenExpiry;
@property (nonatomic, assign) BOOL connected;

// Protocol properties
@property (nonatomic, readwrite) DataSourceType sourceType;
@property (nonatomic, readwrite) DataSourceCapabilities capabilities;
@property (nonatomic, readwrite) NSString *sourceName;
@end

@implementation SchwabDataSource

@synthesize sourceType = _sourceType;
@synthesize capabilities = _capabilities;
@synthesize sourceName = _sourceName;

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourceType = DataSourceTypeSchwab;
        _capabilities = DataSourceCapabilityQuotes |
                       DataSourceCapabilityHistoricalData |
                       DataSourceCapabilityPortfolioData |
                       DataSourceCapabilityTrading |
                       DataSourceCapabilityFundamentals;
        _sourceName = @"Charles Schwab";
        _connected = NO;
        
        // Load credentials from bundle
        NSString *path = [[NSBundle mainBundle] pathForResource:@"SchwabConfig" ofType:@"plist"];
        if (path) {
            NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:path];
            _appKey = config[@"AppKey"];
            _appSecret = config[@"AppSecret"];
            _callbackURL = config[@"CallbackURL"];
        }
        
        // Setup session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30;
        _session = [NSURLSession sessionWithConfiguration:config];
        
        [self loadTokensFromUserDefaults];
    }
    return self;
}

#pragma mark - DataSource Protocol Implementation

- (BOOL)isConnected {
    return _connected;
}

// ✅ UNIFICATO: Implementa protocollo standard
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"SchwabDataSource: connectWithCompletion called (unified protocol)");
    
    [self loadTokensFromUserDefaults];
    
    if ([self hasValidToken]) {
        self.connected = YES;
        if (completion) completion(YES, nil);
        return;
    }
    
    if (self.refreshToken) {
        [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
            if (success) {
                self.connected = YES;
                if (completion) completion(YES, nil);
            } else {
                [self authenticateWithCompletion:^(BOOL success, NSError *error) {
                    self.connected = success;
                    if (completion) completion(success, error);
                }];
            }
        }];
    } else {
        [self authenticateWithCompletion:^(BOOL success, NSError *error) {
            self.connected = success;
            if (completion) completion(success, error);
        }];
    }
}

- (void)disconnect {
    [self.session invalidateAndCancel];
    self.connected = NO;
    self.accessToken = nil;
    self.refreshToken = nil;
    self.tokenExpiry = nil;
    [self clearTokensFromUserDefaults];
}

#pragma mark - Market Data - UNIFIED PROTOCOL

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    [self fetchQuotesForSymbols:@[symbol] completion:^(NSDictionary *quotes, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            // ✅ RITORNA DATI RAW SCHWAB
            id rawQuoteData = quotes[symbol];
            if (completion) completion(rawQuoteData, nil);
        }
    }];
}

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *symbolsString = [symbols componentsJoinedByString:@","];
        NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/quotes?symbols=%@",
                              kSchwabAPIBaseURL,
                              [symbolsString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                // ✅ RITORNA DATI RAW SCHWAB
                if (completion) completion(result, error);
            }];
        }];
        
        [task resume];
    }];
}

#pragma mark - Historical Data - UNIFIED PROTOCOL

// ✅ UNIFICATO: Historical data con date range
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *frequencyType;
        NSInteger frequency;
        [self convertTimeframeToFrequency:timeframe
                            frequencyType:&frequencyType
                                frequency:&frequency];
        
        NSTimeInterval startEpoch = [startDate timeIntervalSince1970] * 1000; // Schwab usa milliseconds
        NSTimeInterval endEpoch = [endDate timeIntervalSince1970] * 1000;
        
        NSString *urlString = [NSString stringWithFormat:
            @"%@/marketdata/v1/pricehistory?symbol=%@&periodType=%@&period=1&frequencyType=%@&frequency=%ld&startDate=%.0f&endDate=%.0f&needExtendedHoursData=%@&needPreviousClose=true",
            kSchwabAPIBaseURL,
            symbol,
            [self periodTypeForFrequencyType:frequencyType],
            frequencyType,
            (long)frequency,
            startEpoch,
            endEpoch,
            needExtendedHours ? @"true" : @"false"];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                // ✅ RITORNA DATI RAW SCHWAB
                if (completion) completion(result, error);
            }];
        }];
        
        [task resume];
    }];
}

// ✅ UNIFICATO: Historical data con bar count (AGGIUNTO - era mancante)
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    NSLog(@"📊 SchwabDataSource: fetchHistoricalData with barCount %ld", (long)barCount);
    
    // ✅ CALCOLA DATE RANGE dal barCount richiesto
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self calculateStartDateForTimeframe:timeframe
                                                       count:barCount
                                                    fromDate:endDate];
    
    // ✅ USA IL METODO CON DATE RANGE
    [self fetchHistoricalDataForSymbol:symbol
                             timeframe:timeframe
                             startDate:startDate
                               endDate:endDate
                     needExtendedHours:needExtendedHours
                            completion:completion];
}

#pragma mark - Portfolio Data - UNIFIED PROTOCOL

- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion {
    
    [self fetchAccountNumbers:^(NSArray *accountNumbers, NSError *error) {
        if (error) {
            if (completion) completion(@[], error);
            return;
        }
        
        // ✅ CONVERTI in formato standardizzato semplice
        NSMutableArray *accounts = [NSMutableArray array];
        for (NSString *accountNumber in accountNumbers) {
            [accounts addObject:@{
                @"accountId": accountNumber,
                @"accountNumber": accountNumber,
                @"source": @"schwab"
            }];
        }
        
        if (completion) completion([accounts copy], nil);
    }];
}

- (void)fetchAccountDetails:(NSString *)accountId
                 completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@",
                              kSchwabAPIBaseURL, accountId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                // ✅ RITORNA DATI RAW SCHWAB
                if (completion) completion(result, error);
            }];
        }];
        
        [task resume];
    }];
}

- (void)fetchPositionsForAccount:(NSString *)accountId
                      completion:(void (^)(NSArray *positions, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/positions",
                              kSchwabAPIBaseURL, accountId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                // ✅ RITORNA ARRAY RAW SCHWAB positions
                if (completion) completion(result ?: @[], error);
            }];
        }];
        
        [task resume];
    }];
}

- (void)fetchOrdersForAccount:(NSString *)accountId
                   completion:(void (^)(NSArray *orders, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/orders",
                              kSchwabAPIBaseURL, accountId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                // ✅ RITORNA ARRAY RAW SCHWAB orders
                if (completion) completion(result ?: @[], error);
            }];
        }];
        
        [task resume];
    }];
}

#pragma mark - Trading Operations - UNIFIED PROTOCOL

- (void)placeOrderForAccount:(NSString *)accountId
                   orderData:(NSDictionary *)orderData
                  completion:(void (^)(NSString *orderId, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/orders",
                              kSchwabAPIBaseURL, accountId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:orderData options:0 error:&jsonError];
        if (jsonError) {
            if (completion) completion(nil, jsonError);
            return;
        }
        request.HTTPBody = jsonData;
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handlePlaceOrderResponse:data response:response error:error completion:completion];
        }];
        
        [task resume];
    }];
}

- (void)cancelOrderForAccount:(NSString *)accountId
                      orderId:(NSString *)orderId
                   completion:(void (^)(BOOL success, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(NO, error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/orders/%@",
                              kSchwabAPIBaseURL, accountId, orderId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = @"DELETE";
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleCancelOrderResponse:data response:response error:error completion:completion];
        }];
        
        [task resume];
    }];
}

#pragma mark - Response Handlers

- (void)handleGenericResponse:(NSData *)data
                     response:(NSURLResponse *)response
                        error:(NSError *)error
                   completion:(void (^)(id result, NSError *error))completion {
    
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        NSError *httpError = [NSError errorWithDomain:@"SchwabDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, httpError);
        });
        return;
    }
    
    NSError *parseError;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    
    if (parseError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, parseError);
        });
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(json, nil);
    });
}

- (void)handlePlaceOrderResponse:(NSData *)data
                        response:(NSURLResponse *)response
                           error:(NSError *)error
                      completion:(void (^)(NSString *orderId, NSError *error))completion {
    
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 201) {
        // Order created successfully, extract order ID from response headers
        NSString *location = httpResponse.allHeaderFields[@"Location"];
        NSString *orderId = [location lastPathComponent];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(orderId, nil);
        });
    } else {
        NSError *httpError = [NSError errorWithDomain:@"SchwabDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, httpError);
        });
    }
}

- (void)handleCancelOrderResponse:(NSData *)data
                         response:(NSURLResponse *)response
                            error:(NSError *)error
                       completion:(void (^)(BOOL success, NSError *error))completion {
    
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    BOOL success = (httpResponse.statusCode == 200 || httpResponse.statusCode == 204);
    
    if (!success) {
        NSError *httpError = [NSError errorWithDomain:@"SchwabDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, httpError);
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(YES, nil);
        });
    }
}

#pragma mark - Internal Helper Methods

- (void)fetchAccountNumbers:(void (^)(NSArray *accountNumbers, NSError *error))completion {
    // [MANTIENE implementazione esistente dal repository]
}

- (NSDate *)calculateStartDateForTimeframe:(BarTimeframe)timeframe
                                     count:(NSInteger)count
                                  fromDate:(NSDate *)endDate {
    
    NSTimeInterval interval = 0;
    
    switch (timeframe) {
        case BarTimeframe1Min:     interval = 60; break;
        case BarTimeframe5Min:     interval = 300; break;
        case BarTimeframe15Min:    interval = 900; break;
        case BarTimeframe30Min:    interval = 1800; break;
        case BarTimeframe1Hour:    interval = 3600; break;
        case BarTimeframeDaily:    interval = 86400; break;
        case BarTimeframeWeekly:   interval = 604800; break;
        case BarTimeframeMonthly:  interval = 2592000; break;
        default:                   interval = 86400; break;
    }
    
    // Per intraday, aggiungi buffer per weekends (40% extra)
    NSTimeInterval totalInterval = interval * count;
    if (timeframe < BarTimeframeDaily) {
        totalInterval *= 1.4;
    }
    
    return [endDate dateByAddingTimeInterval:-totalInterval];
}

- (void)convertTimeframeToFrequency:(BarTimeframe)timeframe
                      frequencyType:(NSString **)frequencyType
                          frequency:(NSInteger *)frequency {
    
    switch (timeframe) {
        case BarTimeframe1Min:
            *frequencyType = @"minute";
            *frequency = 1;
            break;
        case BarTimeframe5Min:
            *frequencyType = @"minute";
            *frequency = 5;
            break;
        case BarTimeframe15Min:
            *frequencyType = @"minute";
            *frequency = 15;
            break;
        case BarTimeframe30Min:
            *frequencyType = @"minute";
            *frequency = 30;
            break;
        case BarTimeframe1Hour:
            *frequencyType = @"minute";
            *frequency = 60;
            break;
        case BarTimeframeDaily:
            *frequencyType = @"daily";
            *frequency = 1;
            break;
        case BarTimeframeWeekly:
            *frequencyType = @"weekly";
            *frequency = 1;
            break;
        case BarTimeframeMonthly:
            *frequencyType = @"monthly";
            *frequency = 1;
            break;
        default:
            *frequencyType = @"daily";
            *frequency = 1;
            break;
    }
}

- (NSString *)periodTypeForFrequencyType:(NSString *)frequencyType {
    if ([frequencyType isEqualToString:@"minute"]) {
        return @"day";
    } else if ([frequencyType isEqualToString:@"daily"]) {
        return @"year";
    } else if ([frequencyType isEqualToString:@"weekly"]) {
        return @"year";
    } else if ([frequencyType isEqualToString:@"monthly"]) {
        return @"year";
    }
    return @"day";
}



#pragma mark - OAuth2 Token Validation - IMPLEMENTAZIONE MANCANTE

- (BOOL)hasValidToken {
    // Verifica che l'access token esista
    if (!self.accessToken || self.accessToken.length == 0) {
        NSLog(@"🚨 SchwabDataSource: No access token available");
        return NO;
    }
    
    // Verifica che il token non sia scaduto
    if (self.tokenExpiry && [self.tokenExpiry timeIntervalSinceNow] <= 60) {
        NSLog(@"🚨 SchwabDataSource: Access token expired or will expire in <60s");
        return NO;
    }
    
    // Se non abbiamo data di scadenza, assumiamo che il token sia ancora valido
    // ma dovremmo provare a usarlo
    if (!self.tokenExpiry) {
        NSLog(@"⚠️ SchwabDataSource: No token expiry info, assuming valid");
        return YES;
    }
    
    NSLog(@"✅ SchwabDataSource: Access token is valid (expires in %.0f seconds)",
          [self.tokenExpiry timeIntervalSinceNow]);
    return YES;
}

#pragma mark - Token Management Helper Methods - IMPLEMENTAZIONI COMPLETE

- (void)loadTokensFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    self.accessToken = [defaults stringForKey:@"SchwabAccessToken"];
    self.refreshToken = [defaults stringForKey:@"SchwabRefreshToken"];
    
    NSNumber *expiryTimestamp = [defaults objectForKey:@"SchwabTokenExpiry"];
    if (expiryTimestamp) {
        self.tokenExpiry = [NSDate dateWithTimeIntervalSince1970:[expiryTimestamp doubleValue]];
    }
    
    if (self.accessToken) {
        NSLog(@"✅ SchwabDataSource: Loaded tokens from UserDefaults (expires: %@)", self.tokenExpiry);
    } else {
        NSLog(@"ℹ️ SchwabDataSource: No saved tokens found in UserDefaults");
    }
}

- (void)saveTokensToUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (self.accessToken) {
        [defaults setObject:self.accessToken forKey:@"SchwabAccessToken"];
    } else {
        [defaults removeObjectForKey:@"SchwabAccessToken"];
    }
    
    if (self.refreshToken) {
        [defaults setObject:self.refreshToken forKey:@"SchwabRefreshToken"];
    } else {
        [defaults removeObjectForKey:@"SchwabRefreshToken"];
    }
    
    if (self.tokenExpiry) {
        NSNumber *timestamp = @([self.tokenExpiry timeIntervalSince1970]);
        [defaults setObject:timestamp forKey:@"SchwabTokenExpiry"];
    } else {
        [defaults removeObjectForKey:@"SchwabTokenExpiry"];
    }
    
    [defaults synchronize];
    
    NSLog(@"💾 SchwabDataSource: Saved tokens to UserDefaults");
}

- (void)clearTokensFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults removeObjectForKey:@"SchwabAccessToken"];
    [defaults removeObjectForKey:@"SchwabRefreshToken"];
    [defaults removeObjectForKey:@"SchwabTokenExpiry"];
    [defaults synchronize];
    
    self.accessToken = nil;
    self.refreshToken = nil;
    self.tokenExpiry = nil;
    
    NSLog(@"🗑️ SchwabDataSource: Cleared all tokens from UserDefaults");
}


- (void)authenticateWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"🔐 SchwabDataSource: Starting OAuth2 authentication...");
    
    // TODO: Implementazione OAuth2 completa
    // Per ora restituisce errore per evitare crash
    NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                         code:501
                                     userInfo:@{NSLocalizedDescriptionKey: @"OAuth2 authentication not implemented yet"}];
    
    if (completion) {
        completion(NO, error);
    }
}

- (void)refreshTokenIfNeeded:(void (^)(BOOL success, NSError *error))completion {
    // Controlla se il refresh è necessario
    if ([self hasValidToken]) {
        NSLog(@"✅ SchwabDataSource: Token still valid, no refresh needed");
        if (completion) completion(YES, nil);
        return;
    }
    
    if (!self.refreshToken) {
        NSLog(@"❌ SchwabDataSource: No refresh token available");
        NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey: @"No refresh token available"}];
        if (completion) completion(NO, error);
        return;
    }
    
    NSLog(@"🔄 SchwabDataSource: Refreshing access token...");
    
    // TODO: Implementazione refresh token completa
    // Per ora restituisce errore per evitare crash
    NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                         code:501
                                     userInfo:@{NSLocalizedDescriptionKey: @"Token refresh not implemented yet"}];
    
    if (completion) {
        completion(NO, error);
    }
}

@end
