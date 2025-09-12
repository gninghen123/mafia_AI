//
//  SchwabDataSource.m - REFACTORED: AUTH REMOVED
//  TradingApp
//
//  ✅ REFACTORED: Rimossa tutta la logica di autenticazione (ora in SchwabLoginManager)
//  ✅ MANTIENE: Tutte le API di market data, account, trading (INVARIATE)
//  ✅ USA: SchwabLoginManager per gestire i token
//

#import "SchwabDataSource.h"
#import "SchwabLoginManager.h"
#import "CommonTypes.h"
#import <AppKit/AppKit.h>

// API Configuration - INVARIATI
static NSString *const kSchwabAPIBaseURL = @"https://api.schwabapi.com";

@interface SchwabDataSource ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) BOOL connected;

// Protocol properties - INVARIATI
@property (nonatomic, readwrite) DataSourceType sourceType;
@property (nonatomic, readwrite) DataSourceCapabilities capabilities;
@property (nonatomic, readwrite) NSString *sourceName;

// ✅ NUOVO: Reference al login manager invece di gestire auth internamente
@property (nonatomic, strong) SchwabLoginManager *loginManager;
@end

@implementation SchwabDataSource

@synthesize sourceType = _sourceType;
@synthesize capabilities = _capabilities;
@synthesize sourceName = _sourceName;

#pragma mark - Initialization - SEMPLIFICATA (no auth logic)

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
        
        // ✅ REFACTORED: Usa SchwabLoginManager per auth
        _loginManager = [SchwabLoginManager sharedManager];
        
        // Setup session - INVARIATO
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30;
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

#pragma mark - DataSource Protocol Implementation - SEMPLIFICATA

- (BOOL)isConnected {
    return _connected;
}

// ✅ REFACTORED: Usa SchwabLoginManager invece di logica auth interna
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"SchwabDataSource: connectWithCompletion called (using SchwabLoginManager)");
    
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (success) {
            self.connected = YES;
            NSLog(@"✅ SchwabDataSource: Connected successfully via SchwabLoginManager");
            if (completion) completion(YES, nil);
        } else {
            self.connected = NO;
            NSLog(@"❌ SchwabDataSource: Connection failed: %@", error.localizedDescription);
            if (completion) completion(NO, error);
        }
    }];
}

- (void)disconnect {
    [self.session invalidateAndCancel];
    self.connected = NO;
    [self.loginManager clearTokens];
    NSLog(@"🔌 SchwabDataSource: Disconnected and cleared tokens");
}

#pragma mark - Market Data - UNIFIED PROTOCOL - INVARIATI (solo auth token cambiato)

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    [self fetchQuotesForSymbols:@[symbol] completion:^(NSDictionary *quotes, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            // ✅ RITORNA DATI RAW SCHWAB - INVARIATO
            id rawQuoteData = quotes[symbol];
            if (completion) completion(rawQuoteData, nil);
        }
    }];
}

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    // ✅ REFACTORED: Usa loginManager per ottenere token valido
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(nil, tokenError);
            return;
        }
        
        // ✅ REST OF API CALL - INVARIATO
        NSString *symbolsString = [symbols componentsJoinedByString:@","];
        NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/quotes?symbols=%@",
                              kSchwabAPIBaseURL,
                              [symbolsString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                if (error) {
                    if (completion) completion(nil, error);
                } else {
                    // ✅ RITORNA DATI RAW SCHWAB - INVARIATO
                    NSDictionary *quotes = @{};
                    if ([result isKindOfClass:[NSDictionary class]]) {
                        quotes = (NSDictionary *)result;
                    }
                    
                    if (completion) completion(quotes, nil);
                }
            }];
        }];
        [task resume];
    }];
}

#pragma mark - Historical Data - UNIFIED PROTOCOL - INVARIATI (solo auth token cambiato)

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    // ✅ NUOVO: Check per timeframe che richiedono aggregazione
    if ([self needsAggregationForTimeframe:timeframe]) {
        NSLog(@"🔄 SchwabDataSource: Timeframe %ld needs aggregation, using 30min base", (long)timeframe);
        
        // Usa 30min come base e aggrega
        [self fetchAndAggregateHistoricalData:symbol
                                    timeframe:timeframe
                                    startDate:startDate
                                      endDate:endDate
                            needExtendedHours:needExtendedHours
                                   completion:completion];
        return;
    }
    
    // ✅ ESISTENTE: Per timeframe supportati nativamente, continua con la logica originale
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(nil, tokenError);
            return;
        }
        
        // ✅ RESTO DELLA LOGICA ORIGINALE - INVARIATA
        NSString *schwabTimeframe = [self convertTimeframeSchwab:timeframe];
        NSString *frequencyType = [self convertFrequencyTypeSchwab:timeframe];
        NSString *periodType = [self convertPeriodTypeSchwab:frequencyType timeframe:timeframe];
        
        
        // Schwab richiede UNIX timestamp in ms per startDate/endDate
        long long startDateMillis = (long long)([startDate timeIntervalSince1970] * 1000.0);
        long long endDateMillis = (long long)([endDate timeIntervalSince1970] * 1000.0);
        NSString *startDateStr = [NSString stringWithFormat:@"%lld", startDateMillis];
        NSString *endDateStr = [NSString stringWithFormat:@"%lld", endDateMillis];
        
        NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/pricehistory?symbol=%@&periodType=%@&frequencyType=%@&frequency=%@&startDate=%@&endDate=%@&needExtendedHoursData=%@",
                              kSchwabAPIBaseURL,
                              symbol,
                              periodType,
                              frequencyType,
                              schwabTimeframe,
                              startDateStr,
                              endDateStr,
                              needExtendedHours ? @"true" : @"false"];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                if (error) {
                    if (completion) completion(nil, error);
                } else {
                    // ✅ PARSING SCHWAB DATA - INVARIATO
                    NSArray *bars = @[];
                    if ([result isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *responseDict = (NSDictionary *)result;
                        NSArray *candlesArray = responseDict[@"candles"];
                        if ([candlesArray isKindOfClass:[NSArray class]]) {
                            bars = candlesArray;
                        }
                    }
                    
                    if (completion) completion(bars, nil);
                }
            }];
        }];
        [task resume];
    }];
}

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    // ✅ NUOVO: Check per timeframe che richiedono aggregazione
    if ([self needsAggregationForTimeframe:timeframe]) {
        NSLog(@"🔄 SchwabDataSource: Timeframe %ld needs aggregation for %ld bars", (long)timeframe, (long)barCount);
        
        // Usa 30min come base e aggrega
        [self fetchAndAggregateHistoricalData:symbol
                                    timeframe:timeframe
                                     barCount:barCount
                            needExtendedHours:needExtendedHours
                                   completion:completion];
        return;
    }
    
    // ✅ ESISTENTE: Per timeframe supportati nativamente, continua con la logica originale
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(nil, tokenError);
            return;
        }
        
        // ✅ RESTO DELLA LOGICA ORIGINALE - INVARIATA
        NSString *schwabTimeframe = [self convertTimeframeSchwab:timeframe];
        NSString *frequencyType = [self convertFrequencyTypeSchwab:timeframe];
        NSString *periodType = [self convertPeriodTypeSchwab:frequencyType timeframe:timeframe];
        
        
        // Calculate endDateMillis = now, startDateMillis = now - barCount * interval * 1000
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        long long endDateMillis = (long long)(now * 1000.0);
        long long intervalSeconds = 60; // default to 1 min
        NSInteger frequency = [schwabTimeframe integerValue];
        if ([frequencyType isEqualToString:@"minute"]) {
            intervalSeconds = 60 * frequency;
        } else if ([frequencyType isEqualToString:@"daily"]) {
            intervalSeconds = 60 * 60 * 24 * frequency;
        } else if ([frequencyType isEqualToString:@"weekly"]) {
            intervalSeconds = 60 * 60 * 24 * 7 * frequency;
        } else if ([frequencyType isEqualToString:@"monthly"]) {
            // Approximate a month as 30 days
            intervalSeconds = 60 * 60 * 24 * 30 * frequency;
        }
        long long startDateMillis = endDateMillis - (long long)barCount * intervalSeconds * 1000;
        
        NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/pricehistory?symbol=%@&periodType=%@&frequencyType=%@&frequency=%@&startDate=%lld&endDate=%lld&needExtendedHoursData=%@",
                              kSchwabAPIBaseURL,
                              symbol,
                              periodType,
                              frequencyType,
                              schwabTimeframe,
                              startDateMillis,
                              endDateMillis,
                              needExtendedHours ? @"true" : @"false"];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                if (error) {
                    if (completion) completion(nil, error);
                } else {
                    // ✅ PARSING SCHWAB DATA - INVARIATO
                    NSArray *bars = @[];
                    if ([result isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *responseDict = (NSDictionary *)result;
                        NSArray *candlesArray = responseDict[@"candles"];
                        if ([candlesArray isKindOfClass:[NSArray class]]) {
                            bars = candlesArray;
                        }
                    }
                    
                    if (completion) completion(bars, nil);
                }
            }];
        }];
        [task resume];
    }];
}


#pragma mark - Portfolio Data - INVARIATI (solo auth token cambiato)

- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion {
    
    // ✅ REFACTORED: Usa loginManager per token
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(@[], tokenError);
            return;
        }
        
        // ✅ REST OF IMPLEMENTATION - INVARIATO
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts", kSchwabAPIBaseURL];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                if (error) {
                    if (completion) completion(@[], error);
                } else {
                    // ✅ RITORNA DATI RAW SCHWAB - INVARIATO
                    NSArray *accounts = @[];
                    if ([result isKindOfClass:[NSArray class]]) {
                        accounts = (NSArray *)result;
                    } else if ([result isKindOfClass:[NSDictionary class]]) {
                        accounts = @[result];
                    }
                    
                    if (completion) completion(accounts, nil);
                }
            }];
        }];
        [task resume];
    }];
}

- (void)fetchAccountDetails:(NSString *)accountId
                 completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion {
    
    // ✅ REFACTORED: Usa loginManager per token
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(nil, tokenError);
            return;
        }
        
        // ✅ REST OF IMPLEMENTATION - INVARIATO
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@", kSchwabAPIBaseURL, accountId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                if (error) {
                    if (completion) completion(nil, error);
                } else {
                    // ✅ RITORNA DATI RAW SCHWAB - INVARIATO
                    NSDictionary *accountDetails = @{};
                    if ([result isKindOfClass:[NSDictionary class]]) {
                        accountDetails = (NSDictionary *)result;
                    }
                    
                    if (completion) completion(accountDetails, nil);
                }
            }];
        }];
        [task resume];
    }];
}

- (void)fetchPositionsForAccount:(NSString *)accountId
                      completion:(void (^)(NSArray *positions, NSError *error))completion {
    
    // ✅ REFACTORED: Usa loginManager per token
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(@[], tokenError);
            return;
        }
        
        // ✅ REST OF IMPLEMENTATION - INVARIATO
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/positions", kSchwabAPIBaseURL, accountId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                if (error) {
                    if (completion) completion(@[], error);
                } else {
                    // ✅ RITORNA DATI RAW SCHWAB - INVARIATO
                    NSArray *positions = @[];
                    if ([result isKindOfClass:[NSArray class]]) {
                        positions = (NSArray *)result;
                    } else if ([result isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *positionsDict = (NSDictionary *)result;
                        if (positionsDict[@"positions"]) {
                            positions = positionsDict[@"positions"];
                        }
                    }
                    
                    if (completion) completion(positions, nil);
                }
            }];
        }];
        [task resume];
    }];
}

- (void)fetchOrdersForAccount:(NSString *)accountId
                   completion:(void (^)(NSArray *orders, NSError *error))completion {
    
    // ✅ REFACTORED: Usa loginManager per token
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(@[], tokenError);
            return;
        }
        
        // ✅ REST OF IMPLEMENTATION - INVARIATO
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/orders", kSchwabAPIBaseURL, accountId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                if (error) {
                    if (completion) completion(@[], error);
                } else {
                    // ✅ RITORNA DATI RAW SCHWAB - INVARIATO
                    NSArray *orders = @[];
                    if ([result isKindOfClass:[NSArray class]]) {
                        orders = (NSArray *)result;
                    } else if ([result isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *ordersDict = (NSDictionary *)result;
                        if (ordersDict[@"orders"]) {
                            orders = ordersDict[@"orders"];
                        }
                    }
                    
                    if (completion) completion(orders, nil);
                }
            }];
        }];
        [task resume];
    }];
}

#pragma mark - Trading Operations - INVARIATI (solo auth token cambiato)

- (void)placeOrderForAccount:(NSString *)accountId
                   orderData:(NSDictionary *)orderData
                  completion:(void (^)(NSString *orderId, NSError *error))completion {
    
    // ✅ REFACTORED: Usa loginManager per token
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(nil, tokenError);
            return;
        }
        
        // ✅ REST OF IMPLEMENTATION - INVARIATO
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/orders", kSchwabAPIBaseURL, accountId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = @"POST";
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:orderData options:0 error:&jsonError];
        if (jsonError) {
            if (completion) completion(nil, jsonError);
            return;
        }
        request.HTTPBody = jsonData;
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                if (error) {
                    if (completion) completion(nil, error);
                } else {
                    // ✅ EXTRACT ORDER ID SCHWAB - INVARIATO
                    NSString *orderId = nil;
                    if ([result isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *responseDict = (NSDictionary *)result;
                        orderId = responseDict[@"orderId"];
                    }
                    
                    if (completion) completion(orderId, nil);
                }
            }];
        }];
        [task resume];
    }];
}

- (void)cancelOrderForAccount:(NSString *)accountId
                      orderId:(NSString *)orderId
                   completion:(void (^)(BOOL success, NSError *error))completion {
    
    // ✅ REFACTORED: Usa loginManager per token
    [self.loginManager ensureTokensValidWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(NO, error);
            return;
        }
        
        NSString *accessToken = [self.loginManager getValidAccessToken];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No valid access token available"}];
            if (completion) completion(NO, tokenError);
            return;
        }
        
        // ✅ REST OF IMPLEMENTATION - INVARIATO
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/orders/%@", kSchwabAPIBaseURL, accountId, orderId];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = @"DELETE";
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            BOOL success = (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300);
            
            if (completion) completion(success, error);
        }];
        [task resume];
    }];
}

#pragma mark - Helper Methods - INVARIATI

- (void)handleGenericResponse:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error completion:(void (^)(id result, NSError *error))completion {
    if (error) {
        NSLog(@"❌ SchwabDataSource: Network error: %@", error.localizedDescription);
        if (completion) completion(nil, error);
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        NSString *errorMessage = [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode];
        NSError *httpError = [NSError errorWithDomain:@"SchwabDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        NSLog(@"❌ SchwabDataSource: %@", errorMessage);
        if (completion) completion(nil, httpError);
        return;
    }
    
    if (!data || data.length == 0) {
        if (completion) completion(@{}, nil);
        return;
    }
    
    NSError *jsonError;
    id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"❌ SchwabDataSource: JSON parsing error: %@", jsonError.localizedDescription);
        if (completion) completion(nil, jsonError);
        return;
    }
    
    if (completion) completion(result, nil);
}

// ✅ HELPER METHODS - COMPLETAMENTE INVARIATI
- (NSString *)convertTimeframeSchwab:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1";
        case BarTimeframe5Min: return @"5";
        case BarTimeframe15Min: return @"15";
        case BarTimeframe30Min: return @"30";
        case BarTimeframe1Hour: return @"60";
        case BarTimeframe4Hour: return @"240";
        case BarTimeframeDaily: return @"1";
        case BarTimeframeWeekly: return @"1";
        case BarTimeframeMonthly: return @"1";
        default: return @"1";
    }
}

- (NSString *)convertFrequencyTypeSchwab:(BarTimeframe)timeframe {
    if (timeframe<1000) {
        return @"minute";
    }
    switch (timeframe) {
        case BarTimeframeDaily:
            return @"daily";
        case BarTimeframeWeekly:
            return @"weekly";
        case BarTimeframeMonthly:
            return @"monthly";
        default:
            return @"daily";
    }
}

- (NSString *)convertPeriodTypeSchwab:(NSString *)frequencyType timeframe:(BarTimeframe)timeframe {
    if ([frequencyType isEqualToString:@"minute"]) {
        return @"day"; // intraday 1min-4h copre massimo 1 giorno
    } else if ([frequencyType isEqualToString:@"daily"] ||
               [frequencyType isEqualToString:@"weekly"] ||
               [frequencyType isEqualToString:@"monthly"]) {
        return @"year"; // dati giornalieri o superiori
    }
    return @"day";
}


#pragma mark - 🆕 NUOVI METODI HELPER PER AGGREGAZIONE (da aggiungere in fondo al file)

- (BOOL)needsAggregationForTimeframe:(BarTimeframe)timeframe {
    // Schwab supporta nativamente solo fino a 30min per intraday
    // Timeframe > 30min ma < daily richiedono aggregazione
    switch (timeframe) {
        case BarTimeframe1Min:
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframeDaily:
        case BarTimeframeWeekly:
        case BarTimeframeMonthly:
            return NO; // Supportati nativamente
            
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            return YES; // Richiedono aggregazione da 30min
            
        default:
            return NO;
    }
}

- (void)fetchAndAggregateHistoricalData:(NSString *)symbol
                              timeframe:(BarTimeframe)timeframe
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                      needExtendedHours:(BOOL)needExtendedHours
                             completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    // Usa sempre 30min come base per l'aggregazione
    BarTimeframe baseTimeframe = BarTimeframe30Min;
    
    NSLog(@"📊 SchwabAggregation: Fetching %@ base data (30min) from %@ to %@", symbol, startDate, endDate);
    
    // Ricorsione: chiama il metodo originale con 30min (che non richiede aggregazione)
    [self fetchHistoricalDataForSymbol:symbol
                             timeframe:baseTimeframe
                             startDate:startDate
                               endDate:endDate
                     needExtendedHours:needExtendedHours
                            completion:^(NSArray *baseBars, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Aggrega i dati al timeframe target
        NSArray *aggregatedBars = [self aggregateBars:baseBars toTimeframe:timeframe];
        
        NSLog(@"✅ SchwabAggregation: %lu base bars -> %lu aggregated bars",
              (unsigned long)baseBars.count, (unsigned long)aggregatedBars.count);
        
        if (completion) completion(aggregatedBars, nil);
    }];
}

- (void)fetchAndAggregateHistoricalData:(NSString *)symbol
                              timeframe:(BarTimeframe)timeframe
                               barCount:(NSInteger)barCount
                      needExtendedHours:(BOOL)needExtendedHours
                             completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    // Usa sempre 30min come base per l'aggregazione
    BarTimeframe baseTimeframe = BarTimeframe30Min;
    NSInteger aggregationFactor = [self getAggregationFactor:timeframe];
    
    // Calcola quante barre base servono (con margine per aggregazione perfetta)
    NSInteger baseBarsNeeded = barCount * aggregationFactor * 1.2; // 20% di margine
    
    NSLog(@"📊 SchwabAggregation: Fetching %ld base bars (30min) to get %ld target bars (factor: %ld)",
          (long)baseBarsNeeded, (long)barCount, (long)aggregationFactor);
    
    // Ricorsione: chiama il metodo originale con 30min (che non richiede aggregazione)
    [self fetchHistoricalDataForSymbol:symbol
                             timeframe:baseTimeframe
                              barCount:baseBarsNeeded
                     needExtendedHours:needExtendedHours
                            completion:^(NSArray *baseBars, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Aggrega i dati al timeframe target
        NSArray *aggregatedBars = [self aggregateBars:baseBars toTimeframe:timeframe];
        
        // Taglia al numero di barre richieste (prendi le più recenti)
        NSArray *finalBars = aggregatedBars;
        if (aggregatedBars.count > barCount) {
            NSRange range = NSMakeRange(aggregatedBars.count - barCount, barCount);
            finalBars = [aggregatedBars subarrayWithRange:range];
        }
        
        NSLog(@"✅ SchwabAggregation: %lu base bars -> %lu aggregated bars -> %lu final bars",
              (unsigned long)baseBars.count, (unsigned long)aggregatedBars.count, (unsigned long)finalBars.count);
        
        if (completion) completion(finalBars, nil);
    }];
}

- (NSInteger)getAggregationFactor:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Hour:  return 2;  // 60min / 30min = 2
        case BarTimeframe4Hour:  return 8;  // 240min / 30min = 8
        default:                 return 1;
    }
}

- (NSArray *)aggregateBars:(NSArray *)baseBars toTimeframe:(BarTimeframe)targetTimeframe {
    if (!baseBars || baseBars.count == 0) {
        return @[];
    }
    
    NSInteger aggregationFactor = [self getAggregationFactor:targetTimeframe];
    
    if (aggregationFactor <= 1) {
        return baseBars; // Nessuna aggregazione necessaria
    }
    
    NSMutableArray *aggregatedBars = [NSMutableArray array];
    NSMutableArray *currentGroup = [NSMutableArray array];
    
    for (NSDictionary *bar in baseBars) {
        [currentGroup addObject:bar];
        
        // Quando raggiungiamo il fattore di aggregazione, crea la barra aggregata
        if (currentGroup.count >= aggregationFactor) {
            NSDictionary *aggregatedBar = [self createAggregatedBar:currentGroup targetTimeframe:targetTimeframe];
            if (aggregatedBar) {
                [aggregatedBars addObject:aggregatedBar];
            }
            [currentGroup removeAllObjects];
        }
    }
    
    // Gestisci l'ultimo gruppo parziale se presente
    if (currentGroup.count > 0) {
        NSDictionary *aggregatedBar = [self createAggregatedBar:currentGroup targetTimeframe:targetTimeframe];
        if (aggregatedBar) {
            [aggregatedBars addObject:aggregatedBar];
        }
    }
    
    return [aggregatedBars copy];
}

- (NSDictionary *)createAggregatedBar:(NSArray *)barGroup targetTimeframe:(BarTimeframe)targetTimeframe {
    if (!barGroup || barGroup.count == 0) {
        return nil;
    }
    
    // Prendi la prima barra per timestamp e open
    NSDictionary *firstBar = barGroup[0];
    NSDictionary *lastBar = barGroup.lastObject;
    
    // Calcola valori aggregati OHLCV
    double open = [firstBar[@"open"] doubleValue];
    double close = [lastBar[@"close"] doubleValue];
    double high = 0.0;
    double low = DBL_MAX;
    long long volume = 0;
    
    for (NSDictionary *bar in barGroup) {
        double barHigh = [bar[@"high"] doubleValue];
        double barLow = [bar[@"low"] doubleValue];
        long long barVolume = [bar[@"volume"] longLongValue];
        
        if (barHigh > high) high = barHigh;
        if (barLow < low) low = barLow;
        volume += barVolume;
    }
    
    // Calcola il timestamp allineato per la barra aggregata
    NSNumber *aggregatedTimestamp = [self calculateAlignedTimestamp:firstBar[@"datetime"] targetTimeframe:targetTimeframe];
    
    return @{
        @"datetime": aggregatedTimestamp,
        @"open": @(open),
        @"high": @(high),
        @"low": @(low),
        @"close": @(close),
        @"volume": @(volume)
    };
}

- (NSNumber *)calculateAlignedTimestamp:(NSNumber *)baseTimestamp targetTimeframe:(BarTimeframe)targetTimeframe {
    if (!baseTimestamp) {
        return @([[NSDate date] timeIntervalSince1970] * 1000.0);
    }
    
    double timestampMillis = [baseTimestamp doubleValue];
    NSDate *baseDate = [NSDate dateWithTimeIntervalSince1970:timestampMillis / 1000.0];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:baseDate];
    
    switch (targetTimeframe) {
        case BarTimeframe1Hour: {
            // Allinea all'inizio dell'ora
            components.minute = 0;
            components.second = 0;
            break;
        }
        case BarTimeframe4Hour: {
            // Allinea a intervalli di 4 ore: 00:00, 04:00, 08:00, 12:00, 16:00, 20:00
            NSInteger hour = components.hour;
            NSInteger alignedHour = (hour / 4) * 4;
            components.hour = alignedHour;
            components.minute = 0;
            components.second = 0;
            break;
        }
        default: {
            // Per altri timeframe, usa il timestamp originale
            return baseTimestamp;
        }
    }
    
    NSDate *alignedDate = [calendar dateFromComponents:components] ?: baseDate;
    return @([alignedDate timeIntervalSince1970] * 1000.0);
}
@end
