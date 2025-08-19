//
//  SchwabDataSource.m
//  TradingApp
//

#import "SchwabDataSource.h"
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "Position.h"
#import "Order.h"
#import "CommonTypes.h"

// API Configuration
static NSString *const kSchwabAPIBaseURL = @"https://api.schwabapi.com";
static NSString *const kSchwabAuthURL = @"https://api.schwabapi.com/v1/oauth/authorize";
static NSString *const kSchwabTokenURL = @"https://api.schwabapi.com/v1/oauth/token";

// Keychain keys
static NSString *const kKeychainService = @"com.tradingapp.schwab";
static NSString *const kKeychainAccessToken = @"access_token";
static NSString *const kKeychainRefreshToken = @"refresh_token";
static NSString *const kKeychainTokenExpiry = @"token_expiry";

@interface SchwabAuthWindowController : NSWindowController <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy) void (^completionHandler)(NSString *code, NSError *error);
@end

@interface SchwabDataSource ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSString *appKey;
@property (nonatomic, strong) NSString *appSecret;
@property (nonatomic, strong) NSString *callbackURL;
@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSString *refreshToken;
@property (nonatomic, strong) NSDate *tokenExpiry;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, strong) NSOperationQueue *requestQueue;
@property (nonatomic, strong) SchwabAuthWindowController *authWindowController;

// Implement protocol properties
@property (nonatomic, readwrite) DataSourceType sourceType;
@property (nonatomic, readwrite) DataSourceCapabilities capabilities;
@property (nonatomic, readwrite) NSString *sourceName;
@end

@implementation SchwabDataSource

@synthesize sourceType = _sourceType;
@synthesize capabilities = _capabilities;
@synthesize sourceName = _sourceName;

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourceType = DataSourceTypeSchwab;
        _capabilities = DataSourceCapabilityQuotes |
                       DataSourceCapabilityHistorical |
                       DataSourceCapabilityOrderBook |
                       DataSourceCapabilityAccounts |
                       DataSourceCapabilityTrading;
        _sourceName = @"Charles Schwab";
        
        // Load credentials from configuration
        [self loadCredentials];
        
        // Setup URL session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30;
        _session = [NSURLSession sessionWithConfiguration:config];
        
        // Setup operation queue
        _requestQueue = [[NSOperationQueue alloc] init];
        _requestQueue.maxConcurrentOperationCount = 5;
        
        // Load tokens from keychain
        [self loadTokensFromKeychain];
    }
    return self;
}

- (void)loadCredentials {
    // Load from plist or user defaults - never hardcode!
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"SchwabConfig" ofType:@"plist"];
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    
    if (config) {
        self.appKey = config[@"AppKey"];
        self.appSecret = config[@"Secret"];
        self.callbackURL = config[@"CallbackURL"];
    } else {
        // Use the provided credentials temporarily - should be stored securely!
        self.appKey = @"XVweZPSbC0mMKbZJpGHbds6ueGmLRj1Z";
        self.appSecret = @"enwEqrEQmPZlt7KS";
        self.callbackURL = @"https://127.0.0.1";
    }
}

#pragma mark - DataSourceProtocol Required

- (BOOL)isConnected {
    return _connected && [self hasValidToken];
}

- (void)connectWithCredentials:(NSDictionary *)credentials
                    completion:(void (^)(BOOL success, NSError *error))completion {
    
    // Check if we have a valid token
    if ([self hasValidToken]) {
        self.connected = YES;
        if (completion) {
            completion(YES, nil);
        }
        return;
    }
    
    // Try to refresh token first
    if (self.refreshToken) {
        [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
            if (success) {
                self.connected = YES;
                if (completion) completion(YES, nil);
            } else {
                // Need to re-authenticate
                [self authenticateWithCompletion:completion];
            }
        }];
    } else {
        // Need to authenticate
        [self authenticateWithCompletion:completion];
    }
}

- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"SchwabDataSource: connectWithCompletion called");
    
    // Check if we already have valid tokens from keychain
    [self loadTokensFromKeychain];
    
    // Check if we have a valid token
    if ([self hasValidToken]) {
        NSLog(@"SchwabDataSource: Already have valid token, marking as connected");
        self.connected = YES;
        if (completion) {
            completion(YES, nil);
        }
        return;
    }
    
    // Try to refresh token first
    if (self.refreshToken) {
        NSLog(@"SchwabDataSource: Attempting to refresh token");
        [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
            if (success) {
                self.connected = YES;
                NSLog(@"SchwabDataSource: Token refresh successful");
                if (completion) completion(YES, nil);
            } else {
                // Need to re-authenticate
                NSLog(@"SchwabDataSource: Token refresh failed, need to re-authenticate");
                [self authenticateWithCompletion:^(BOOL success, NSError *error) {
                    self.connected = success;
                    if (completion) completion(success, error);
                }];
            }
        }];
    } else {
        // Need to authenticate
        NSLog(@"SchwabDataSource: No refresh token, need to authenticate");
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
    [self clearTokensFromKeychain];
}

#pragma mark - OAuth2 Authentication

- (void)authenticateWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Create auth window
        self.authWindowController = [[SchwabAuthWindowController alloc] init];
        
        // Build authorization URL
        NSURLComponents *components = [NSURLComponents componentsWithString:kSchwabAuthURL];
        components.queryItems = @[
            [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
            [NSURLQueryItem queryItemWithName:@"client_id" value:self.appKey],
            [NSURLQueryItem queryItemWithName:@"redirect_uri" value:self.callbackURL],
            [NSURLQueryItem queryItemWithName:@"scope" value:@"read write trade"]
        ];
        
        // Load auth URL in web view
        NSURLRequest *request = [NSURLRequest requestWithURL:components.URL];
        [self.authWindowController.webView loadRequest:request];
        
        // Show window
        [self.authWindowController showWindow:nil];
        
        // Handle completion
        __weak typeof(self) weakSelf = self;
        self.authWindowController.completionHandler = ^(NSString *code, NSError *error) {
            if (code) {
                [weakSelf exchangeCodeForToken:code completion:completion];
            } else {
                if (completion) completion(NO, error);
            }
            weakSelf.authWindowController = nil;
        };
    });
}

- (void)exchangeCodeForToken:(NSString *)code
                  completion:(void (^)(BOOL success, NSError *error))completion {
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kSchwabTokenURL]];
    request.HTTPMethod = @"POST";
    
    // Create base64 encoded credentials
    NSString *credentials = [NSString stringWithFormat:@"%@:%@", self.appKey, self.appSecret];
    NSData *credentialsData = [credentials dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64Credentials = [credentialsData base64EncodedStringWithOptions:0];
    
    // Set headers
    [request setValue:[NSString stringWithFormat:@"Basic %@", base64Credentials]
   forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    // Set body
    NSString *bodyString = [NSString stringWithFormat:@"grant_type=authorization_code&code=%@&redirect_uri=%@",
                           [code stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                           [self.callbackURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, error);
            });
            return;
        }
        
        NSError *parseError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        
        if (parseError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, parseError);
            });
            return;
        }
        
        // Save tokens
        self.accessToken = json[@"access_token"];
        self.refreshToken = json[@"refresh_token"];
        NSInteger expiresIn = [json[@"expires_in"] integerValue];
        self.tokenExpiry = [NSDate dateWithTimeIntervalSinceNow:expiresIn];
        
        [self saveTokensToKeychain];
        self.connected = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(YES, nil);
        });
    }];
    
    [task resume];
}

- (void)refreshTokenIfNeeded:(void (^)(BOOL success, NSError *error))completion {
    if ([self hasValidToken]) {
        if (completion) completion(YES, nil);
        return;
    }
    
    if (!self.refreshToken) {
        NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey: @"No refresh token available"}];
        if (completion) completion(NO, error);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kSchwabTokenURL]];
    request.HTTPMethod = @"POST";
    
    // Create base64 encoded credentials
    NSString *credentials = [NSString stringWithFormat:@"%@:%@", self.appKey, self.appSecret];
    NSData *credentialsData = [credentials dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64Credentials = [credentialsData base64EncodedStringWithOptions:0];
    
    // Set headers
    [request setValue:[NSString stringWithFormat:@"Basic %@", base64Credentials]
   forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    // Set body
    NSString *bodyString = [NSString stringWithFormat:@"grant_type=refresh_token&refresh_token=%@",
                           [self.refreshToken stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, error);
            });
            return;
        }
        
        NSError *parseError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        
        if (parseError || json[@"error"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, parseError ?: [NSError errorWithDomain:@"SchwabDataSource" code:401 userInfo:@{NSLocalizedDescriptionKey: json[@"error"] ?: @"Token refresh failed"}]);
            });
            return;
        }
        
        // Update tokens
        self.accessToken = json[@"access_token"];
        if (json[@"refresh_token"]) {
            self.refreshToken = json[@"refresh_token"];
        }
        NSInteger expiresIn = [json[@"expires_in"] integerValue];
        self.tokenExpiry = [NSDate dateWithTimeIntervalSinceNow:expiresIn];
        
        [self saveTokensToKeychain];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(YES, nil);
        });
    }];
    
    [task resume];
}

- (BOOL)hasValidToken {
    return self.accessToken && self.tokenExpiry && [self.tokenExpiry timeIntervalSinceNow] > 60;
}

#pragma mark - Market Data Implementation

// Aggiornamento del metodo fetchQuoteForSymbol in SchwabDataSource.m con debug

- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    NSLog(@"SchwabDataSource: fetchQuoteForSymbol called for %@", symbol);
    NSLog(@"SchwabDataSource: Current token status - hasValidToken: %@", [self hasValidToken] ? @"YES" : @"NO");
    
    [self fetchQuotesForSymbols:@[symbol] completion:^(NSDictionary *quotes, NSError *error) {
        if (error) {
            NSLog(@"SchwabDataSource: fetchQuoteForSymbols failed: %@", error.localizedDescription);
            if (completion) completion(nil, error);
        } else {
            // CAMBIAMENTO: Restituisce i dati grezzi
            NSDictionary *rawQuoteData = quotes[symbol];
            if (completion) completion(rawQuoteData, nil);
        }
    }];
}

// Aggiornamento del metodo fetchQuoteForSymbols per aggiungere debug

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                  completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    NSLog(@"SchwabDataSource: fetchQuoteForSymbols called with symbols: %@", symbols);
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"SchwabDataSource: Token refresh failed: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        NSLog(@"SchwabDataSource: Token is valid, proceeding with API call");
        
        NSString *symbolsString = [symbols componentsJoinedByString:@","];
        NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/quotes?symbols=%@",
                              kSchwabAPIBaseURL,
                              [symbolsString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        
        NSLog(@"SchwabDataSource: Making request to URL: %@", urlString);
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSLog(@"SchwabDataSource: Authorization header: Bearer %@...", [self.accessToken substringToIndex:MIN(10, self.accessToken.length)]);
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
            if (networkError) {
                NSLog(@"SchwabDataSource: Network error: %@", networkError.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, networkError);
                });
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            
            if (data) {
                NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            
            if (httpResponse.statusCode == 401) {
                NSLog(@"SchwabDataSource: Unauthorized - token may be invalid");
                NSError *authError = [NSError errorWithDomain:@"SchwabDataSource"
                                                         code:401
                                                     userInfo:@{NSLocalizedDescriptionKey: @"Unauthorized - token invalid"}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, authError);
                });
                return;
            }
            
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode];
                NSError *httpError = [NSError errorWithDomain:@"SchwabDataSource"
                                                         code:httpResponse.statusCode
                                                     userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, httpError);
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
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(json, nil);
            });
        }];
        
        [task resume];
    }];
}

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    // Usa il nuovo metodo con extended hours = NO di default
    [self fetchPriceHistoryWithDateRange:symbol
                               startDate:startDate
                                 endDate:endDate
                               timeframe:timeframe
                   needExtendedHoursData:NO  // Default: NO extended hours
                       needPreviousClose:YES // Default: YES previous close
                              completion:^(NSDictionary *priceHistory, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            // Restituisce dati grezzi per SchwabDataAdapter
            if (completion) completion(priceHistory, nil);
        }
    }];
}

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                               count:(NSInteger)count
               needExtendedHoursData:(BOOL)needExtendedHours
                needPreviousClose:(BOOL)needPreviousClose
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Calcola date range dal count richiesto
        NSDate *endDate = [NSDate date];
        NSDate *startDate = [self calculateStartDateForTimeframe:timeframe
                                                           count:count
                                                        fromDate:endDate];
        
        NSLog(@"📈 SchwabDataSource: Requesting %ld bars for %@ from %@ to %@ (extended: %@)",
              (long)count, symbol, startDate, endDate, needExtendedHours ? @"YES" : @"NO");
        // Usa il nuovo metodo con date range
        [self fetchPriceHistoryWithDateRange:symbol
                                   startDate:startDate
                                     endDate:endDate
                                   timeframe:timeframe
                       needExtendedHoursData:needExtendedHours
                           needPreviousClose:needPreviousClose
                                  completion:^(NSDictionary *priceHistory, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
            } else {
                // Restituisce dati grezzi per SchwabDataAdapter
                if (completion) completion(priceHistory, nil);
            }
        }];
    }];
}
- (void)fetchPriceHistoryWithDateRange:(NSString *)symbol
                             startDate:(NSDate *)startDate
                               endDate:(NSDate *)endDate
                             timeframe:(BarTimeframe)timeframe
                 needExtendedHoursData:(BOOL)needExtendedHours
                     needPreviousClose:(BOOL)needPreviousClose
                            completion:(void (^)(NSDictionary *priceHistory, NSError *error))completion {
    
    NSString *frequencyType;
    NSInteger frequency;
    [self convertTimeframeToFrequency:timeframe frequencyType:&frequencyType frequency:&frequency];
    
    // Convert dates to milliseconds since epoch (Schwab API format)
    // Use NSTimeInterval for precision, then convert to integer milliseconds
    NSTimeInterval startDateSeconds = [startDate timeIntervalSince1970];
    NSTimeInterval endDateSeconds = [endDate timeIntervalSince1970];
    
    // Convert to milliseconds and ensure we have integer values
    long long startDateMs = (long long)round(startDateSeconds * 1000.0);
    long long endDateMs = (long long)round(endDateSeconds * 1000.0);
    
    // Se startDate è prima del 1970 (timestamp negativo), usa una data minima sicura
    if (startDateMs <= 0) {
        startDateMs = 10; // 10 millisecondi dal 1970 = data minima sicura
        NSLog(@"📅 SchwabDataSource: Corrected negative timestamp to minimum safe value: %lld", startDateMs);
    }
    
  
    // NEW: Add periodType and period based on timeframe
    NSString *periodType;
    NSInteger period;
    
    if (timeframe < BarTimeframe1Day) {
        // Intraday: use "day" period
        periodType = @"day";
        period = 10;
    } else {
        // Daily and higher: use "year" period
        periodType = @"year";
        period = 1;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/pricehistory?symbol=%@&periodType=%@&period=%ld&startDate=%lld&endDate=%lld&frequencyType=%@&frequency=%ld&needExtendedHoursData=%@&needPreviousClose=%@",
                          kSchwabAPIBaseURL,
                          symbol,
                          periodType,
                          (long)period,
                          startDateMs,
                          endDateMs,
                          frequencyType,
                          (long)frequency,
                          needExtendedHours ? @"true" : @"false",
                          needPreviousClose ? @"true" : @"false"];
    
    NSLog(@"📈 SchwabDataSource: Request URL: %@", urlString);
  
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken]
   forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"❌ SchwabDataSource: Network Error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"📊 SchwabDataSource: HTTP Status: %ld", (long)httpResponse.statusCode);
        
        if (httpResponse.statusCode != 200) {
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"❌ SchwabDataSource: HTTP Error %ld: %@", (long)httpResponse.statusCode, responseString);
            
            NSError *httpError = [NSError errorWithDomain:@"SchwabDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, httpError);
            });
            return;
        }
        
        NSError *parseError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        
        if (parseError) {
            NSLog(@"❌ SchwabDataSource: JSON Parse Error: %@", parseError.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, parseError);
            });
            return;
        }
        
        NSArray *candles = json[@"candles"];
        NSLog(@"✅ SchwabDataSource: Received %lu candles for %@", (unsigned long)candles.count, symbol);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(json, nil);
        });
    }];
    
    [task resume];
}
- (void)fetchPriceHistory:(NSString *)symbol
               periodType:(NSString *)periodType
                   period:(NSInteger)period
            frequencyType:(NSString *)frequencyType
                frequency:(NSInteger)frequency
               completion:(void (^)(NSDictionary *priceHistory, NSError *error))completion {
    
    NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/pricehistory?symbol=%@&periodType=%@&period=%ld&frequencyType=%@&frequency=%ld",
                          kSchwabAPIBaseURL,
                          symbol,
                          periodType,
                          (long)period,
                          frequencyType,
                          (long)frequency];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken]
   forHTTPHeaderField:@"Authorization"];
    
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(json, parseError);
        });
    }];
    
    [task resume];
}

#pragma mark - Count-Based Historical Data (NEW)

- (void)fetchHistoricalDataForSymbolWithCount:(NSString *)symbol
                                    timeframe:(BarTimeframe)timeframe
                                        count:(NSInteger)count
                        needExtendedHoursData:(BOOL)needExtendedHours
                             needPreviousClose:(BOOL)needPreviousClose
                                    completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDate *endDate = [NSDate date];
        NSDate *startDate = [self calculateStartDateForTimeframe:timeframe
                                                           count:count
                                                        fromDate:endDate];
        
        NSLog(@"📈 SchwabDataSource: Requesting %ld bars for %@ from %@ to %@ (extended: %@)",
              (long)count, symbol, startDate, endDate, needExtendedHours ? @"YES" : @"NO");
        
        [self fetchPriceHistoryWithDateRange:symbol
                                   startDate:startDate
                                     endDate:endDate
                                   timeframe:timeframe
                       needExtendedHoursData:needExtendedHours
                           needPreviousClose:needPreviousClose
                                  completion:^(NSDictionary *priceHistory, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
            } else {
                // Restituisce i dati grezzi per l'adapter
                if (completion) completion(priceHistory, nil);
            }
        }];
    }];
}

#pragma mark - Account Data

- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion {
    [self fetchAccountNumbers:^(NSArray *accountNumbers, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // For now, fetch positions from first account
        if (accountNumbers.count > 0) {
            NSString *accountNumber = accountNumbers[0];
            [self fetchPositionsForAccount:accountNumber completion:completion];
        } else {
            if (completion) completion(@[], nil);
        }
    }];
}
- (void)fetchPositionsForAccount:(NSString *)accountNumber
                      completion:(void (^)(NSArray *positions, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/%@/positions",
                              kSchwabAPIBaseURL, accountNumber];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken]
       forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, error);
                });
                return;
            }
            
            NSError *parseError;
            NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            
            if (parseError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, parseError);
                });
                return;
            }
            
            // CAMBIAMENTO: Restituisce i dati JSON grezzi invece di processarli
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(json, nil);
            });
        }];
        
        [task resume];
    }];
}

- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion {
    [self fetchAccountNumbers:^(NSArray *accountNumbers, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Fetch orders from first account
        if (accountNumbers.count > 0) {
            NSString *accountNumber = accountNumbers[0];
            [self fetchOrdersForAccount:accountNumber completion:completion];
        } else {
            if (completion) completion(@[], nil);
        }
    }];
}

- (void)fetchOrdersForAccount:(NSString *)accountNumber
                   completion:(void (^)(NSArray *orders, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Fetch orders from last 30 days
        NSDate *fromDate = [[NSDate date] dateByAddingTimeInterval:-30*24*60*60];
        NSDate *toDate = [NSDate date];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/orders?accountNumber=%@&fromEnteredTime=%@&toEnteredTime=%@",
                              kSchwabAPIBaseURL,
                              accountNumber,
                              [formatter stringFromDate:fromDate],
                              [formatter stringFromDate:toDate]];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken]
       forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, error);
                });
                return;
            }
            
            NSError *parseError;
            NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            
            if (parseError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, parseError);
                });
                return;
            }
            
            // CAMBIAMENTO: Restituisce i dati JSON grezzi invece di processarli
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(json, nil);
            });
        }];
        
        [task resume];
    }];
}

- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(id orderBook, NSError *error))completion {
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/marketdata/v1/quotes/%@/orderbook",
                              kSchwabAPIBaseURL, symbol];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken]
       forHTTPHeaderField:@"Authorization"];
        
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
            
            // CAMBIAMENTO: Restituisce i dati JSON grezzi
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(json, nil);
            });
        }];
        
        [task resume];
    }];
}


- (void)fetchAccountNumbers:(void (^)(NSArray *accountNumbers, NSError *error))completion {
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/trader/v1/accounts/accountNumbers", kSchwabAPIBaseURL];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken]
       forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, error);
                });
                return;
            }
            
            NSError *parseError;
            NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(json, parseError);
            });
        }];
        
        [task resume];
    }];
}

#pragma mark - Helper Methods (NEW)

- (NSDate *)calculateStartDateForTimeframe:(BarTimeframe)timeframe
                                     count:(NSInteger)count
                                  fromDate:(NSDate *)endDate {
    
    // NEW: Check for maxAvailable request
    if (count >= 9999999) {
        if (timeframe < BarTimeframe1Day) {
            // Intraday: 1 year back
            NSDateComponents *components = [[NSDateComponents alloc] init];
            components.year = -1;
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSDate *oneYearAgo = [calendar dateByAddingComponents:components toDate:endDate options:0];
            NSLog(@"📅 SchwabDataSource: MaxAvailable intraday - using 1 year back: %@", oneYearAgo);
            return oneYearAgo;
        } else {
            // Daily or higher: January 1, 1800
            NSDateComponents *components = [[NSDateComponents alloc] init];
            components.year = 1970;
            components.month = 1;
            components.day = 5;
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSDate *historicalDate = [calendar dateFromComponents:components];
            NSLog(@"📅 SchwabDataSource: MaxAvailable daily - using historical date: %@", historicalDate);
            return historicalDate;
        }
    }
    
    // Original logic for specific count
    NSTimeInterval secondsPerBar;
    
    switch (timeframe) {
        case BarTimeframe1Min:   secondsPerBar = 60; break;
        case BarTimeframe5Min:   secondsPerBar = 300; break;
        case BarTimeframe15Min:  secondsPerBar = 900; break;
        case BarTimeframe30Min:  secondsPerBar = 1800; break;
        case BarTimeframe1Hour:  secondsPerBar = 3600; break;
        case BarTimeframe4Hour:  secondsPerBar = 14400; break;
        case BarTimeframe1Day:   secondsPerBar = 86400; break;
        case BarTimeframe1Week:  secondsPerBar = 604800; break;
        case BarTimeframe1Month: secondsPerBar = 2592000; break;
        default: secondsPerBar = 86400; break;
    }
    
    NSTimeInterval totalSeconds = count * secondsPerBar;
    
    if (timeframe < BarTimeframe1Day) {
        totalSeconds *= 1.5; // 50% buffer for non-trading hours
    }
    
    return [endDate dateByAddingTimeInterval:-totalSeconds];
}
// In SchwabDataSource.m - convertTimeframeToFrequency method

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
        case BarTimeframe4Hour:
            *frequencyType = @"minute";
            *frequency = 240;
            break;
        case BarTimeframe1Day:
            *frequencyType = @"daily";
            *frequency = 1;
            break;
        case BarTimeframe1Week:
            // FIX: Use daily instead of weekly for Schwab API compatibility
            *frequencyType = @"daily";
            *frequency = 1;  // Will aggregate to weekly in adapter
            break;
        case BarTimeframe1Month:
            // FIX: Use daily instead of monthly for Schwab API compatibility
            *frequencyType = @"daily";
            *frequency = 1;  // Will aggregate to monthly in adapter
            break;
        default:
            *frequencyType = @"daily";
            *frequency = 1;
            break;
    }
}
#pragma mark - Keychain Management

- (void)saveTokensToKeychain {
    [self saveToKeychain:self.accessToken forKey:kKeychainAccessToken];
    [self saveToKeychain:self.refreshToken forKey:kKeychainRefreshToken];
    [self saveToKeychain:[NSString stringWithFormat:@"%f", [self.tokenExpiry timeIntervalSince1970]]
                  forKey:kKeychainTokenExpiry];
}

- (void)loadTokensFromKeychain {
    self.accessToken = [self loadFromKeychain:kKeychainAccessToken];
    self.refreshToken = [self loadFromKeychain:kKeychainRefreshToken];
    
    NSString *expiryString = [self loadFromKeychain:kKeychainTokenExpiry];
    if (expiryString) {
        self.tokenExpiry = [NSDate dateWithTimeIntervalSince1970:[expiryString doubleValue]];
    }
}

- (void)clearTokensFromKeychain {
    [self deleteFromKeychain:kKeychainAccessToken];
    [self deleteFromKeychain:kKeychainRefreshToken];
    [self deleteFromKeychain:kKeychainTokenExpiry];
}

- (void)saveToKeychain:(NSString *)value forKey:(NSString *)key {
    if (!value) return;
    
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecValueData: data
    };
    
    SecItemDelete((__bridge CFDictionaryRef)query);
    SecItemAdd((__bridge CFDictionaryRef)query, NULL);
}

- (NSString *)loadFromKeychain:(NSString *)key {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (status == errSecSuccess) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (void)deleteFromKeychain:(NSString *)key {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: key
    };
    
    SecItemDelete((__bridge CFDictionaryRef)query);
}

#pragma mark - Rate Limiting

- (NSInteger)remainingRequests {
    return 120; // Schwab rate limits vary by endpoint
}

- (NSDate *)rateLimitResetDate {
    return [NSDate dateWithTimeIntervalSinceNow:60];
}

@end

#pragma mark - SchwabAuthWindowController Implementation

@implementation SchwabAuthWindowController

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupWindow];
    }
    return self;
}

- (void)setupWindow {
    // Create window
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    NSUInteger styleMask = NSWindowStyleMaskTitled |
                          NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable;
    
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:styleMask
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    window.title = @"Schwab Authentication";
    [window center];
    
    // Create web view
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    self.webView.navigationDelegate = self;
    
    window.contentView = self.webView;
    self.window = window;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURL *url = navigationAction.request.URL;
    
    // Check if this is our callback URL
    if ([url.absoluteString hasPrefix:@"https://127.0.0.1"]) {
        // Extract code from query parameters
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString *code = nil;
        
        for (NSURLQueryItem *item in components.queryItems) {
            if ([item.name isEqualToString:@"code"]) {
                code = item.value;
                break;
            }
        }
        
        if (code) {
            if (self.completionHandler) {
                self.completionHandler(code, nil);
            }
            [self close];
        } else {
            NSError *error = [NSError errorWithDomain:@"SchwabAuth"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"No authorization code received"}];
            if (self.completionHandler) {
                self.completionHandler(nil, error);
            }
            [self close];
        }
        
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    // Ignore SSL errors for localhost callback
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorServerCertificateUntrusted) {
        return;
    }
    
    if (self.completionHandler) {
        self.completionHandler(nil, error);
    }
    [self close];
}




@end
