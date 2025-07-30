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
            NSLog(@"SchwabDataSource: fetchQuoteForSymbols succeeded, raw response: %@", quotes);
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
            NSLog(@"SchwabDataSource: HTTP Status Code: %ld", (long)httpResponse.statusCode);
            NSLog(@"SchwabDataSource: Response headers: %@", httpResponse.allHeaderFields);
            
            if (data) {
                NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"SchwabDataSource: Raw response: %@", responseString);
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
                NSLog(@"SchwabDataSource: JSON parsing error: %@", parseError.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, parseError);
                });
                return;
            }
            
            NSLog(@"SchwabDataSource: Successfully parsed JSON: %@", json);
            
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
    
    [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Convert timeframe to Schwab format
        NSString *periodType;
        NSInteger period;
        NSString *frequencyType;
        NSInteger frequency;
        
        [self convertTimeframe:timeframe
                    periodType:&periodType
                        period:&period
                 frequencyType:&frequencyType
                     frequency:&frequency];
        
        [self fetchPriceHistory:symbol
                     periodType:periodType
                         period:period
                  frequencyType:frequencyType
                      frequency:frequency
                     completion:^(NSDictionary *priceHistory, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
            } else {
                // CAMBIAMENTO: Restituisce i dati grezzi invece di parseHistoricalData
                if (completion) completion(priceHistory, nil);
            }
        }];
    }];
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

#pragma mark - Helper Methods

- (void)convertTimeframe:(BarTimeframe)timeframe
              periodType:(NSString **)periodType
                  period:(NSInteger *)period
           frequencyType:(NSString **)frequencyType
               frequency:(NSInteger *)frequency {
    
    switch (timeframe) {
        case BarTimeframe1Min:
            *periodType = @"day";
            *period = 1;
            *frequencyType = @"minute";
            *frequency = 1;
            break;
        case BarTimeframe5Min:
            *periodType = @"day";
            *period = 5;
            *frequencyType = @"minute";
            *frequency = 5;
            break;
        case BarTimeframe15Min:
            *periodType = @"day";
            *period = 10;
            *frequencyType = @"minute";
            *frequency = 15;
            break;
        case BarTimeframe30Min:
            *periodType = @"day";
            *period = 10;
            *frequencyType = @"minute";
            *frequency = 30;
            break;
        case BarTimeframe1Hour:
            *periodType = @"month";
            *period = 1;
            *frequencyType = @"minute";
            *frequency = 60;
            break;
        case BarTimeframe1Day:
            *periodType = @"year";
            *period = 1;
            *frequencyType = @"daily";
            *frequency = 1;
            break;
        case BarTimeframe1Week:
            *periodType = @"year";
            *period = 1;
            *frequencyType = @"weekly";
            *frequency = 1;
            break;
        case BarTimeframe1Month:
            *periodType = @"year";
            *period = 2;
            *frequencyType = @"monthly";
            *frequency = 1;
            break;
    }
}


// ATTENZIONE!!! parsing non necessario... il datamanager svolge la standardizzazione
// Aggiornamento del metodo parseQuoteData nel SchwabDataSource.m
/*
- (MarketData *)parseQuoteData:(NSDictionary *)data forSymbol:(NSString *)symbol {
    if (!data) {
        return nil;
    }
    
  
    
    // Schwab restituisce la struttura: data[@"quote"] contiene i prezzi principali
    NSDictionary *quoteData = data[@"quote"];
    NSDictionary *regularData = data[@"regular"];
    NSDictionary *referenceData = data[@"reference"];
    
    if (!quoteData) {
        return nil;
    }
    
    
    
    // Crea dictionary per inizializzare MarketData
    NSMutableDictionary *marketDataDict = [NSMutableDictionary dictionary];
    marketDataDict[@"symbol"] = symbol;
    
    // Mappiamo i campi di Schwab ai nostri campi MarketData
    // Schwab usa "lastPrice" per l'ultimo prezzo
    if (quoteData[@"lastPrice"]) {
        marketDataDict[@"last"] = quoteData[@"lastPrice"];
    }
    
    // Bid e Ask
    if (quoteData[@"bidPrice"]) {
        marketDataDict[@"bid"] = quoteData[@"bidPrice"];
    }
    
    if (quoteData[@"askPrice"]) {
        marketDataDict[@"ask"] = quoteData[@"askPrice"];
    }
    
    // Open, High, Low, Close
    if (quoteData[@"openPrice"]) {
        marketDataDict[@"open"] = quoteData[@"openPrice"];
    }
    
    if (quoteData[@"highPrice"]) {
        marketDataDict[@"high"] = quoteData[@"highPrice"];
    }
    
    if (quoteData[@"lowPrice"]) {
        marketDataDict[@"low"] = quoteData[@"lowPrice"];
    }
    
    if (quoteData[@"closePrice"]) {
        marketDataDict[@"previousClose"] = quoteData[@"closePrice"];
    }
    
    // Volume
    if (quoteData[@"totalVolume"]) {
        marketDataDict[@"volume"] = quoteData[@"totalVolume"];
    }
    
    // Bid/Ask sizes
    if (quoteData[@"bidSize"]) {
        marketDataDict[@"bidSize"] = quoteData[@"bidSize"];
    }
    
    if (quoteData[@"askSize"]) {
        marketDataDict[@"askSize"] = quoteData[@"askSize"];
    }
    
    // Change e Change Percent (se disponibili)
    if (quoteData[@"netChange"]) {
        marketDataDict[@"change"] = quoteData[@"netChange"];
    }
    
    if (quoteData[@"netPercentChange"]) {
        marketDataDict[@"changePercent"] = quoteData[@"netPercentChange"];
    }
    
    // Exchange
    if (referenceData[@"exchangeName"]) {
        marketDataDict[@"exchange"] = referenceData[@"exchangeName"];
    }
    
    // Timestamp (Schwab usa millisecondi)
    if (quoteData[@"quoteTime"]) {
        NSNumber *quoteTimeMs = quoteData[@"quoteTime"];
        NSTimeInterval quoteTimeSeconds = [quoteTimeMs doubleValue] / 1000.0;
        marketDataDict[@"timestamp"] = @(quoteTimeSeconds);
    }
    
    // Market status
    if (quoteData[@"securityStatus"]) {
        NSString *status = quoteData[@"securityStatus"];
        marketDataDict[@"isMarketOpen"] = @([status isEqualToString:@"Normal"]);
    }
    
    
    // Crea MarketData object
    MarketData *quote = [[MarketData alloc] initWithDictionary:marketDataDict];
    
    if (!quote) {
      
        NSLog(@"SchwabDataSource: Failed to create MarketData for %@", symbol);
    }
    
    return quote;
}

- (NSArray *)parseHistoricalData:(NSDictionary *)data {
    NSArray *candles = data[@"candles"];
    if (!candles) return @[];
    
    NSMutableArray *bars = [NSMutableArray array];
    
    for (NSDictionary *candle in candles) {
        NSMutableDictionary *barDict = [NSMutableDictionary dictionary];
        
        // Usa 'date' invece di 'timestamp'
        barDict[@"date"] = [NSDate dateWithTimeIntervalSince1970:[candle[@"datetime"] doubleValue] / 1000.0];
        
        // I valori potrebbero essere già NSNumber o NSDecimalNumber
        if (candle[@"open"]) {
            if ([candle[@"open"] isKindOfClass:[NSDecimalNumber class]]) {
                barDict[@"open"] = @([candle[@"open"] doubleValue]);
            } else {
                barDict[@"open"] = candle[@"open"];
            }
        }
        
        if (candle[@"high"]) {
            if ([candle[@"high"] isKindOfClass:[NSDecimalNumber class]]) {
                barDict[@"high"] = @([candle[@"high"] doubleValue]);
            } else {
                barDict[@"high"] = candle[@"high"];
            }
        }
        
        if (candle[@"low"]) {
            if ([candle[@"low"] isKindOfClass:[NSDecimalNumber class]]) {
                barDict[@"low"] = @([candle[@"low"] doubleValue]);
            } else {
                barDict[@"low"] = candle[@"low"];
            }
        }
        
        if (candle[@"close"]) {
            if ([candle[@"close"] isKindOfClass:[NSDecimalNumber class]]) {
                barDict[@"close"] = @([candle[@"close"] doubleValue]);
            } else {
                barDict[@"close"] = candle[@"close"];
            }
        }
        
        if (candle[@"volume"]) {
            barDict[@"volume"] = candle[@"volume"];
        }
        
        [bars addObject:barDict];
    }
    
    return bars;
}


- (Position *)parsePositionData:(NSDictionary *)data {
    // Per ora restituiamo nil perché Position dovrebbe essere creato tramite factory o builder
    // TODO: Implementare quando necessario
    return nil;
}
// fine parsing non necessario
 */

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
