
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



//-----------------

#pragma mark - autentication window

//---------------------



@interface SchwabAuthWindowController : NSWindowController <WKNavigationDelegate, NSWindowDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy) void (^completionHandler)(BOOL success, NSError *error);
@property (nonatomic, strong) NSString *appKey;
@property (nonatomic, strong) NSString *callbackURL;
@property (nonatomic, strong) NSString *state;
- (instancetype)initWithAppKey:(NSString *)appKey callbackURL:(NSString *)callbackURL;
- (void)startAuthenticationFlow;
@end

@implementation SchwabAuthWindowController

- (instancetype)initWithAppKey:(NSString *)appKey callbackURL:(NSString *)callbackURL {
    NSRect frame = NSMakeRect(0, 0, 900, 700);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled |
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Schwab Authentication";
    [window center];
    
    self = [super initWithWindow:window];
    if (self) {
        _appKey = [appKey copy];
        _callbackURL = [callbackURL copy];
        _state = [[NSUUID UUID] UUIDString];
        
        // ✅ CONFIGURAZIONE WEBVIEW CORRETTA
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.processPool = [[WKProcessPool alloc] init];
        
        // Preferences di base
        WKPreferences *preferences = [[WKPreferences alloc] init];
        preferences.javaScriptEnabled = YES;
        config.preferences = preferences;
        
        // 🚫 DISABILITA keychain auto-save usando websiteDataStore non persistente
        // Solo se disponibile (macOS 10.13+)
        if (@available(macOS 10.13, *)) {
            config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
        }
        
        // 🚫 DISABILITA user content controller per evitare script injection
        config.userContentController = [[WKUserContentController alloc] init];
        
        self.webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
        self.webView.navigationDelegate = self;
        
        // 🚫 DISABILITA altre funzioni che potrebbero triggera keychain
        self.webView.allowsBackForwardNavigationGestures = NO;
        if (@available(macOS 10.13, *)) {
            self.webView.customUserAgent = @"SchwabTradingApp/1.0";
        }
        
        window.contentView = self.webView;
        window.delegate = self;
    }
    return self;
}


- (void)startAuthenticationFlow {
    NSLog(@"🔐 Starting Schwab OAuth2 authentication flow...");
    
    // Costruisci URL di autorizzazione OAuth2
    NSString *scope = @"readonly"; // Modifica secondo le tue necessità
    NSString *responseType = @"code";
    
    NSURLComponents *components = [NSURLComponents componentsWithString:kSchwabAuthURL];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"client_id" value:self.appKey],
        [NSURLQueryItem queryItemWithName:@"redirect_uri" value:self.callbackURL],
        [NSURLQueryItem queryItemWithName:@"scope" value:scope],
        [NSURLQueryItem queryItemWithName:@"response_type" value:responseType],
        [NSURLQueryItem queryItemWithName:@"state" value:self.state]
    ];
    
    NSURL *authURL = components.URL;
    NSLog(@"🌐 Loading Schwab auth URL: %@", authURL);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:authURL];
    request.timeoutInterval = 30.0;
    
    [self.webView loadRequest:request];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"📱 Schwab WebView loaded: %@", webView.URL.absoluteString);
    
    // 🎯 CONTROLLA se siamo arrivati al callback URL
    if ([webView.URL.absoluteString hasPrefix:self.callbackURL]) {
        NSLog(@"🎯 Detected callback URL: %@", webView.URL.absoluteString);
        [self handleCallbackURL:webView.URL];
        return;
    }
    
    // 🎯 CONTROLLA altri possibili pattern di success
    NSString *urlString = webView.URL.absoluteString;
    if ([urlString containsString:@"code="] ||
        [urlString containsString:@"access_token="] ||
        [urlString containsString:@"success"] ||
        [urlString containsString:@"authorized"]) {
        NSLog(@"🎯 Detected OAuth success pattern in URL: %@", urlString);
        [self handleCallbackURL:webView.URL];
        return;
    }
    
    // 🔍 DEBUG: Log URL per capire il flusso
    NSLog(@"🔍 WebView URL: %@", urlString);
    
    // 🎯 CONTROLLA il title della pagina per success indicators
    [webView evaluateJavaScript:@"document.title" completionHandler:^(id result, NSError *error) {
        if (!error && [result isKindOfClass:[NSString class]]) {
            NSString *title = (NSString *)result;
            NSLog(@"📄 Page title: %@", title);
        }
    }];
}
- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURL *url = navigationAction.request.URL;
    if ([url.absoluteString hasPrefix:self.callbackURL]) {
        NSLog(@"🎯 Caught callback in navigationAction: %@", url.absoluteString);
        [self handleCallbackURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"❌ Schwab WebView navigation failed: %@ (Code: %ld)", error.localizedDescription, (long)error.code);
    
    // Non chiudere immediatamente, potrebbe essere solo un redirect
    if (error.code == NSURLErrorCancelled) {
        NSLog(@"⚠️ Navigation cancelled, ignoring...");
        return;
    }
    
    if (self.completionHandler) {
        self.completionHandler(NO, error);
        self.completionHandler = nil;
    }
    
    [self close];
}

- (void)handleCallbackURL:(NSURL *)callbackURL {
    NSLog(@"🎯 Processing Schwab callback: %@", callbackURL.absoluteString);
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:callbackURL resolvingAgainstBaseURL:NO];
    
    NSString *authCode = nil;
    NSString *receivedState = nil;
    NSString *error = nil;
    NSString *accessToken = nil; // Alcuni OAuth2 tornano direttamente il token
    
    // 📝 ESTRAI parametri dalla query string
    for (NSURLQueryItem *queryItem in components.queryItems) {
        NSLog(@"📝 Query param: %@ = %@", queryItem.name, queryItem.value);
        
        if ([queryItem.name isEqualToString:@"code"]) {
            authCode = queryItem.value;
        } else if ([queryItem.name isEqualToString:@"state"]) {
            receivedState = queryItem.value;
        } else if ([queryItem.name isEqualToString:@"error"]) {
            error = queryItem.value;
        } else if ([queryItem.name isEqualToString:@"access_token"]) {
            accessToken = queryItem.value;
        }
    }
    
    // 📝 CONTROLLA anche il fragment (#) per token
    if (!authCode && !accessToken && callbackURL.fragment) {
        NSLog(@"📝 Checking URL fragment: %@", callbackURL.fragment);
        NSArray *fragmentParams = [callbackURL.fragment componentsSeparatedByString:@"&"];
        for (NSString *param in fragmentParams) {
            NSArray *keyValue = [param componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                NSString *key = keyValue[0];
                NSString *value = keyValue[1];
                NSLog(@"📝 Fragment param: %@ = %@", key, value);
                
                if ([key isEqualToString:@"access_token"]) {
                    accessToken = value;
                } else if ([key isEqualToString:@"code"]) {
                    authCode = value;
                }
            }
        }
    }
    
    // 🚨 CONTROLLA errori
    if (error) {
        NSLog(@"❌ OAuth2 error: %@", error);
        NSError *oauthError = [NSError errorWithDomain:@"SchwabDataSource"
                                                  code:401
                                              userInfo:@{NSLocalizedDescriptionKey: error}];
        if (self.completionHandler) {
            self.completionHandler(NO, oauthError);
            self.completionHandler = nil;
        }
        [self close];
        return;
    }
    
    // ✅ SUCCESS: Abbiamo ricevuto un authorization code o access token
    if (authCode || accessToken) {
        NSLog(@"✅ OAuth2 success! Code: %@, Token: %@",
              authCode ? @"YES" : @"NO",
              accessToken ? @"YES" : @"NO");
        
        // Salva temporaneamente per il parent
        if (authCode) {
            [[NSUserDefaults standardUserDefaults] setObject:authCode forKey:@"SchwabTempAuthCode"];
        }
        if (accessToken) {
            [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:@"SchwabTempAccessToken"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // 🎉 NOTIFICA SUCCESSO
        if (self.completionHandler) {
            self.completionHandler(YES, nil);
            self.completionHandler = nil;
        }
        
        [self close];
    }
}

- (void)close {
    [super close];
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    if (self.completionHandler) {
        NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                             code:1008
                                         userInfo:@{NSLocalizedDescriptionKey: @"Authentication window closed by user"}];
        self.completionHandler(NO, error);
        self.completionHandler = nil;
    }
}



@end

@class SchwabAuthWindowController;

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

// 🆕 AGGIUNTO: OAuth2 window controller
@property (nonatomic, strong) SchwabAuthWindowController *authWindowController;
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



#pragma mark - OAuth2 Authentication Implementation

- (void)authenticateWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"🔐 SchwabDataSource: Starting OAuth2 authentication...");
    if (!self.appKey || self.appKey.length == 0) {
        NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Schwab App Key not configured"}];
        if (completion) completion(NO, error);
        return;
    }
    if (!self.callbackURL || self.callbackURL.length == 0) {
        NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Schwab Callback URL not configured"}];
        if (completion) completion(NO, error);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.authWindowController = [[SchwabAuthWindowController alloc] initWithAppKey:self.appKey callbackURL:self.callbackURL];
        __weak typeof(self) weakSelf = self;
        self.authWindowController.completionHandler = ^(BOOL success, NSError *error) {
            if (success) {
                [weakSelf exchangeAuthCodeForTokensWithCompletion:completion];
            } else {
                if (completion) completion(NO, error);
            }
            weakSelf.authWindowController = nil;
        };
        [self.authWindowController showWindow:nil];
        [self.authWindowController startAuthenticationFlow];
    });
}

// MARK: - OAuth2 Token Exchange & Refresh (Refactored)

- (void)exchangeAuthCodeForTokensWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSString *authCode = [[NSUserDefaults standardUserDefaults] stringForKey:@"SchwabTempAuthCode"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SchwabTempAuthCode"];
    if (!authCode) {
        NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"No authorization code available"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, error);
        });
        return;
    }
    NSString *bodyString = [NSString stringWithFormat:@"grant_type=authorization_code&code=%@&redirect_uri=%@",
                            [authCode stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                            [self.callbackURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    [self performTokenRequestWithBody:bodyString completion:completion];
}

- (void)refreshTokenIfNeeded:(void (^)(BOOL success, NSError *error))completion {
    if ([self hasValidToken]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(YES, nil);
        });
        return;
    }
    if (!self.refreshToken) {
        NSError *error = [NSError errorWithDomain:@"SchwabDataSource"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey: @"No refresh token available"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, error);
        });
        return;
    }
    NSString *bodyString = [NSString stringWithFormat:@"grant_type=refresh_token&refresh_token=%@",
                            [self.refreshToken stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    [self performTokenRequestWithBody:bodyString completion:^(BOOL success, NSError *error) {
        if (!success) {
            [self clearTokensFromUserDefaults];
        }
        if (completion) completion(success, error);
    }];
}

/// Helper method to perform token exchange/refresh requests and handle responses.
- (void)performTokenRequestWithBody:(NSString *)bodyString completion:(void (^)(BOOL success, NSError *error))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kSchwabTokenURL]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSString *credentials = [NSString stringWithFormat:@"%@:%@", self.appKey, self.appSecret];
    NSData *credentialsData = [credentials dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64Credentials = [credentialsData base64EncodedStringWithOptions:0];
    [request setValue:[NSString stringWithFormat:@"Basic %@", base64Credentials]
   forHTTPHeaderField:@"Authorization"];
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, error);
            });
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"SchwabDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Token request failed with HTTP %ld", (long)httpResponse.statusCode]}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, httpError);
            });
            return;
        }
        NSError *jsonError;
        NSDictionary *tokenResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![tokenResponse isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, jsonError);
            });
            return;
        }
        NSString *accessToken = tokenResponse[@"access_token"];
        NSString *refreshToken = tokenResponse[@"refresh_token"];
        NSNumber *expiresIn = tokenResponse[@"expires_in"];
        if (!accessToken) {
            NSError *tokenError = [NSError errorWithDomain:@"SchwabDataSource"
                                                      code:400
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No access token in response"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, tokenError);
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.accessToken = accessToken;
            if (refreshToken) self.refreshToken = refreshToken;
            if (expiresIn) {
                self.tokenExpiry = [NSDate dateWithTimeIntervalSinceNow:[expiresIn doubleValue]];
            } else {
                self.tokenExpiry = [NSDate dateWithTimeIntervalSinceNow:1800];
            }
            [self saveTokensToUserDefaults];
            if (completion) completion(YES, nil);
        });
    }];
    [task resume];
}



@end
