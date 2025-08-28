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
        NSString *schwabTimeframe = [self convertTimeframeSchwab:timeframe];
        NSString *frequencyType = [self convertFrequencyTypeSchwab:timeframe];
        NSString *periodType = [self convertPeriodTypeSchwab:frequencyType];
        
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
        NSString *schwabTimeframe = [self convertTimeframeSchwab:timeframe];
        NSString *frequencyType = [self convertFrequencyTypeSchwab:timeframe];
        NSString *periodType = [self convertPeriodTypeSchwab:frequencyType];
        
        NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/pricehistory?symbol=%@&periodType=%@&frequencyType=%@&frequency=%@&period=%ld&needExtendedHoursData=%@",
                              kSchwabAPIBaseURL,
                              symbol,
                              periodType,
                              frequencyType,
                              schwabTimeframe,
                              (long)barCount,
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
    switch (timeframe) {
        case BarTimeframe1Min:
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            return @"minute";
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

- (NSString *)convertPeriodTypeSchwab:(NSString *)frequencyType {
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

@end
