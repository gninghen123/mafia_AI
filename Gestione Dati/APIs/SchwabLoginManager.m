//
//  SchwabLoginManager.m
//  TradingApp
//
//  Gestione separata dell'autenticazione OAuth2 per Schwab
//  Estratta da SchwabDataSource seguendo il pattern di IBKRLoginManager
//

#import "SchwabLoginManager.h"
#import <WebKit/WebKit.h>

// API Configuration
static NSString *const kSchwabAuthURL = @"https://api.schwabapi.com/v1/oauth/authorize";
static NSString *const kSchwabTokenURL = @"https://api.schwabapi.com/v1/oauth/token";

// Forward declaration
@interface SchwabAuthWindowController : NSWindowController <WKNavigationDelegate, NSWindowDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy) void (^completionHandler)(BOOL success, NSError *error);
@property (nonatomic, strong) NSString *appKey;
@property (nonatomic, strong) NSString *callbackURL;
@property (nonatomic, strong) NSString *state;
- (instancetype)initWithAppKey:(NSString *)appKey callbackURL:(NSString *)callbackURL;
- (void)startAuthenticationFlow;
@end

@interface SchwabLoginManager ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSString *appKey;
@property (nonatomic, strong) NSString *appSecret;
@property (nonatomic, strong) NSString *callbackURL;
@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSString *refreshToken;
@property (nonatomic, strong) NSDate *tokenExpiry;
@property (nonatomic, strong) SchwabAuthWindowController *authWindowController;
@end

@implementation SchwabLoginManager

+ (instancetype)sharedManager {
    static SchwabLoginManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SchwabLoginManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Setup session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30;
        _session = [NSURLSession sessionWithConfiguration:config];
        
        // Load credentials from bundle
        [self loadConfiguration];
        
        // Load saved tokens
        [self loadTokensFromUserDefaults];
    }
    return self;
}

#pragma mark - Configuration

- (void)loadConfiguration {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"SchwabConfig" ofType:@"plist"];
    if (path) {
        NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:path];
        _appKey = config[@"AppKey"];
        _appSecret = config[@"Secret"];  // ✅ CORRETTO: usa "Secret" invece di "AppSecret"
        _callbackURL = config[@"CallbackURL"];
        NSLog(@"✅ SchwabLoginManager: Loaded configuration from SchwabConfig.plist");
    } else {
        NSLog(@"⚠️ SchwabLoginManager: SchwabConfig.plist not found");
    }
}

#pragma mark - Public Interface

- (void)ensureTokensValidWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"🔐 SchwabLoginManager: ensureTokensValidWithCompletion called");
    
    if ([self hasValidToken]) {
        NSLog(@"✅ SchwabLoginManager: Valid token already available");
        if (completion) completion(YES, nil);
        return;
    }
    
    if (self.refreshToken) {
        NSLog(@"🔄 SchwabLoginManager: Attempting to refresh token");
        [self refreshTokenIfNeeded:^(BOOL success, NSError *error) {
            if (success) {
                if (completion) completion(YES, nil);
            } else {
                NSLog(@"🔐 SchwabLoginManager: Refresh failed, starting authentication");
                [self authenticateWithCompletion:completion];
            }
        }];
    } else {
        NSLog(@"🔐 SchwabLoginManager: No refresh token, starting authentication");
        [self authenticateWithCompletion:completion];
    }
}

- (NSString *)getValidAccessToken {
    if ([self hasValidToken]) {
        return self.accessToken;
    }
    return nil;
}

- (void)clearTokens {
    [self clearTokensFromUserDefaults];
}

#pragma mark - OAuth2 Authentication Implementation

- (void)authenticateWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"🔐 SchwabLoginManager: Starting OAuth2 authentication...");
    
    if (!self.appKey || self.appKey.length == 0) {
        NSError *error = [NSError errorWithDomain:@"SchwabLoginManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Schwab App Key not configured"}];
        if (completion) completion(NO, error);
        return;
    }
    
    if (!self.callbackURL || self.callbackURL.length == 0) {
        NSError *error = [NSError errorWithDomain:@"SchwabLoginManager"
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

#pragma mark - OAuth2 Token Exchange & Refresh

- (void)exchangeAuthCodeForTokensWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSString *authCode = [[NSUserDefaults standardUserDefaults] stringForKey:@"SchwabTempAuthCode"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SchwabTempAuthCode"];
    
    if (!authCode) {
        NSError *error = [NSError errorWithDomain:@"SchwabLoginManager"
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
        NSError *error = [NSError errorWithDomain:@"SchwabLoginManager"
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

- (void)performTokenRequestWithBody:(NSString *)bodyString completion:(void (^)(BOOL success, NSError *error))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kSchwabTokenURL]];
    request.HTTPMethod = @"POST";
    
    // Basic auth header
    NSString *credentials = [NSString stringWithFormat:@"%@:%@", self.appKey, self.appSecret];
    NSData *credentialsData = [credentials dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64Credentials = [credentialsData base64EncodedStringWithOptions:0];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", base64Credentials];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleTokenResponse:data response:response error:error completion:completion];
    }];
    [task resume];
}

- (void)handleTokenResponse:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error completion:(void (^)(BOOL success, NSError *error))completion {
    if (error) {
        NSLog(@"❌ SchwabLoginManager: Token request failed: %@", error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        NSString *errorMessage = [NSString stringWithFormat:@"Token request failed with status %ld", (long)httpResponse.statusCode];
        NSError *error = [NSError errorWithDomain:@"SchwabLoginManager"
                                             code:httpResponse.statusCode
                                         userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        NSLog(@"❌ SchwabLoginManager: %@", errorMessage);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, error);
        });
        return;
    }
    
    NSError *jsonError;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || !responseDict) {
        NSLog(@"❌ SchwabLoginManager: Failed to parse token response");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, jsonError);
        });
        return;
    }
    
    // Extract tokens
    self.accessToken = responseDict[@"access_token"];
    self.refreshToken = responseDict[@"refresh_token"];
    
    NSNumber *expiresIn = responseDict[@"expires_in"];
    if (expiresIn) {
        self.tokenExpiry = [NSDate dateWithTimeIntervalSinceNow:[expiresIn doubleValue]];
    }
    
    [self saveTokensToUserDefaults];
    
    NSLog(@"✅ SchwabLoginManager: Tokens obtained successfully");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(YES, nil);
    });
}

#pragma mark - Token Validation

- (BOOL)hasValidToken {
    // Verifica che l'access token esista
    if (!self.accessToken || self.accessToken.length == 0) {
        NSLog(@"🚨 SchwabLoginManager: No access token available");
        return NO;
    }
    
    // Verifica che il token non sia scaduto
    if (self.tokenExpiry && [self.tokenExpiry timeIntervalSinceNow] <= 60) {
        NSLog(@"🚨 SchwabLoginManager: Access token expired or will expire in <60s");
        return NO;
    }
    
    // Se non abbiamo data di scadenza, assumiamo che il token sia ancora valido
    if (!self.tokenExpiry) {
        NSLog(@"⚠️ SchwabLoginManager: No token expiry info, assuming valid");
        return YES;
    }
    
    NSLog(@"✅ SchwabLoginManager: Access token is valid (expires in %.0f seconds)",
          [self.tokenExpiry timeIntervalSinceNow]);
    return YES;
}

#pragma mark - Token Management Helper Methods

- (void)loadTokensFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    self.accessToken = [defaults stringForKey:@"SchwabAccessToken"];
    self.refreshToken = [defaults stringForKey:@"SchwabRefreshToken"];
    
    NSNumber *expiryTimestamp = [defaults objectForKey:@"SchwabTokenExpiry"];
    if (expiryTimestamp) {
        self.tokenExpiry = [NSDate dateWithTimeIntervalSince1970:[expiryTimestamp doubleValue]];
    }
    
    if (self.accessToken) {
        NSLog(@"✅ SchwabLoginManager: Loaded tokens from UserDefaults (expires: %@)", self.tokenExpiry);
    } else {
        NSLog(@"ℹ️ SchwabLoginManager: No saved tokens found in UserDefaults");
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
    
    NSLog(@"💾 SchwabLoginManager: Saved tokens to UserDefaults");
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
    
    NSLog(@"🗑️ SchwabLoginManager: Cleared all tokens from UserDefaults");
}

@end

#pragma mark - Authentication Window Controller

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
        [NSURLQueryItem queryItemWithName:@"response_type" value:responseType],
        [NSURLQueryItem queryItemWithName:@"scope" value:scope],
        [NSURLQueryItem queryItemWithName:@"state" value:self.state]
    ];
    
    NSURL *authURL = components.URL;
    NSLog(@"🌐 Loading authorization URL: %@", authURL.absoluteString);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:authURL];
    [self.webView loadRequest:request];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"📱 WebView finished loading: %@", webView.URL.absoluteString);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"❌ WebView navigation failed: %@", error.localizedDescription);
    if (self.completionHandler) {
        self.completionHandler(NO, error);
        self.completionHandler = nil;
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSLog(@"🔍 WebView navigation to: %@", url.absoluteString);
    
    // 🎯 CONTROLLA se l'URL contiene il callback
    if ([url.absoluteString hasPrefix:self.callbackURL]) {
        NSLog(@"✅ OAuth2 callback detected: %@", url.absoluteString);
        [self handleCallbackURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - OAuth2 Callback Handling

- (void)handleCallbackURL:(NSURL *)callbackURL {
    NSLog(@"🔗 Processing callback URL: %@", callbackURL.absoluteString);
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:callbackURL resolvingAgainstBaseURL:NO];
    
    NSString *authCode = nil;
    NSString *receivedState = nil;
    NSString *error = nil;
    NSString *accessToken = nil;
    
    // 📝 CONTROLLA parametri nella query string
    for (NSURLQueryItem *queryItem in components.queryItems) {
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
        NSError *oauthError = [NSError errorWithDomain:@"SchwabLoginManager"
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
        NSError *error = [NSError errorWithDomain:@"SchwabLoginManager"
                                             code:1008
                                         userInfo:@{NSLocalizedDescriptionKey: @"Authentication window closed by user"}];
        self.completionHandler(NO, error);
        self.completionHandler = nil;
    }
}

@end
