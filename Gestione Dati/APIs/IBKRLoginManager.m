//
//  IBKRLoginManager.m
//  TradingApp
//
//  Complete implementation with external browser cookie support
//

#import "IBKRLoginManager.h"
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// Forward declaration for IBKRAuthWindowController
@interface IBKRAuthWindowController : NSWindowController <WKNavigationDelegate, NSWindowDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSTimer *authCheckTimer;
@property (nonatomic, copy) void (^completionHandler)(BOOL success, NSError *error);

- (instancetype)initWithPort:(NSInteger)port;
- (void)startAuthenticationFlow;
@end

// Main IBKRLoginManager private interface
@interface IBKRLoginManager () <NSURLSessionDelegate>
@property (nonatomic, copy) NSString *internalSessionCookie;
@property (nonatomic, strong) NSTask *clientPortalTask;
@property (nonatomic, strong) NSTimer *authCheckTimer;
@property (nonatomic, strong) IBKRAuthWindowController *authWindowController;
@end

#pragma mark - IBKRAuthWindowController Implementation

@implementation IBKRAuthWindowController {
    NSInteger _port;
}

- (instancetype)initWithPort:(NSInteger)port {
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled |
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"IBKR Authentication";
    [window center];
    
    self = [super initWithWindow:window];
    if (self) {
        _port = port;
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.processPool = [[WKProcessPool alloc] init];
        
        self.webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
        self.webView.navigationDelegate = self;
        
        window.contentView = self.webView;
        window.delegate = self;
    }
    return self;
}

- (void)startAuthenticationFlow {
    NSString *urlString = [NSString stringWithFormat:@"https://localhost:%ld", (long)_port];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 30.0;
    
    [self.webView loadRequest:request];
    
    // Start checking auth status
    self.authCheckTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer *timer) {
        [self checkAuthenticationStatus];
    }];
}

- (void)checkAuthenticationStatus {
    NSString *urlString = [NSString stringWithFormat:@"https://localhost:%ld/v1/api/iserver/auth/status", (long)_port];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 5.0;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:(id<NSURLSessionDelegate>)self
                                                     delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            return; // Keep checking
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 200 && data) {
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            if (!jsonError && [json[@"authenticated"] boolValue] && [json[@"connected"] boolValue]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.authCheckTimer) {
                        [self.authCheckTimer invalidate];
                        self.authCheckTimer = nil;
                    }

                    NSLog(@"✅ Authentication successful in WebView!");

                    // Retrieve x-sess-uuid cookie from WKWebView
                    WKWebView *webView = self.webView;
                    if (@available(macOS 10.13, *)) {
                        WKHTTPCookieStore *cookieStore = webView.configuration.websiteDataStore.httpCookieStore;
                        [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
                            for (NSHTTPCookie *cookie in cookies) {
                                if ([cookie.name isEqualToString:@"x-sess-uuid"]) {
                                    // Set the sessionCookie on the login manager singleton
                                    [[IBKRLoginManager sharedManager] setInternalSessionCookie:cookie.value];
                                    NSLog(@"🍪 x-sess-uuid cookie set: %@", cookie.value);
                                    break;
                                }
                            }
                            if (self.completionHandler) {
                                self.completionHandler(YES, nil);
                                self.completionHandler = nil;
                            }
                            [self close];
                        }];
                    } else {
                        // Fallback for older macOS
                        if (self.completionHandler) {
                            self.completionHandler(YES, nil);
                            self.completionHandler = nil;
                        }
                        [self close];
                    }
                });
            }
        }
    }];
    
    [task resume];
}

- (void)close {
    if (self.authCheckTimer) {
        [self.authCheckTimer invalidate];
        self.authCheckTimer = nil;
    }
    [super close];
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    if (self.authCheckTimer) {
        [self.authCheckTimer invalidate];
        self.authCheckTimer = nil;
    }
    
    if (self.completionHandler) {
        NSError *error = [NSError errorWithDomain:@"IBKRLoginManager"
                                             code:1008
                                         userInfo:@{NSLocalizedDescriptionKey: @"Authentication window closed by user"}];
        self.completionHandler(NO, error);
        self.completionHandler = nil;
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"IBKR WebView loaded: %@", webView.URL);
    
    if ([webView.URL.absoluteString containsString:@"authenticated"] ||
        [webView.URL.absoluteString containsString:@"success"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkAuthenticationStatus];
        });
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"IBKR WebView navigation failed: %@ (Code: %ld)", error.localizedDescription, (long)error.code);
    
    // Handle SSL certificate errors
    if (error.code == NSURLErrorServerCertificateUntrusted || error.code == -1202) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Certificate Trust Required";
            alert.informativeText = @"IBKR Client Portal requires accepting a self-signed certificate.\n\nClick 'Open in Browser' to complete login in Safari.";
            alert.alertStyle = NSAlertStyleWarning;
            [alert addButtonWithTitle:@"Open in Browser"];
            [alert addButtonWithTitle:@"Cancel"];
            
            [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                if (returnCode == NSAlertFirstButtonReturn) {
                    // Open in browser
                    NSString *urlString = [NSString stringWithFormat:@"https://localhost:%ld", (long)self->_port];
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
                    
                    // Start monitoring for auth completion
                    [self startAuthenticationFlow];
                } else {
                    // Cancel
                    if (self.completionHandler) {
                        NSError *cancelError = [NSError errorWithDomain:@"IBKRLoginManager" code:1008
                                                               userInfo:@{NSLocalizedDescriptionKey: @"SSL certificate not accepted"}];
                        self.completionHandler(NO, cancelError);
                        self.completionHandler = nil;
                    }
                    [self close];
                }
            }];
        });
        return;
    }
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    
    NSString *host = challenge.protectionSpace.host;
    if ([host isEqualToString:@"localhost"] || [host isEqualToString:@"127.0.0.1"]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

@end

#pragma mark - Main IBKRLoginManager Implementation

@implementation IBKRLoginManager

+ (instancetype)sharedManager {
    static IBKRLoginManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[IBKRLoginManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoLaunchEnabled = YES;
        _port = 5001;
        [self findClientPortalInstallation];
    }
    return self;
}

#pragma mark - Public Cookie Methods

- (NSString *)sessionCookie {
    return self.internalSessionCookie;
}

- (void)setInternalSessionCookie:(NSString *)cookie {
    _internalSessionCookie = [cookie copy];
    NSLog(@"🍪 IBKRLoginManager: Session cookie updated: %@", cookie ? @"[SET]" : @"[CLEARED]");
}

#pragma mark - Main Integration Method

- (void)ensureClientPortalReadyWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion {
    [self checkClientPortalStatus:^(BOOL running, BOOL authenticated) {
        if (running && authenticated) {
            completion(YES, nil);
            return;
        }
        
        if (running && !authenticated) {
            [self promptForLogin:completion];
            return;
        }
        
        if (!self.autoLaunchEnabled || !self.clientPortalPath) {
            NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"Client Portal not running. Please start manually or enable auto-launch."}];
            completion(NO, error);
            return;
        }
        
        [self launchClientPortalWithCompletion:^(BOOL launchSuccess, NSError *launchError) {
            if (launchSuccess) {
                [self promptForLogin:completion];
            } else {
                completion(NO, launchError);
            }
        }];
    }];
}

#pragma mark - Client Portal Launch

- (void)launchClientPortalWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSString *relativeRunScript = @"bin/run.sh";
    NSString *relativeConfigFile = @"root/conf.yaml";
    
    NSString *runScriptPath = [self.clientPortalPath stringByAppendingPathComponent:relativeRunScript];
    if (![[NSFileManager defaultManager] fileExistsAtPath:runScriptPath]) {
        NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Client Portal run.sh not found"}];
        completion(NO, error);
        return;
    }
    
    if (self.clientPortalTask && self.clientPortalTask.isRunning) {
        completion(YES, nil);
        return;
    }
    
    NSString *tempDir = NSTemporaryDirectory();
    NSString *javaTmpDir = [tempDir stringByAppendingPathComponent:@"java-tmp"];
    NSString *workingDir = [javaTmpDir stringByAppendingPathComponent:@"workspace"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:workingDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    NSArray *itemsToCopy = @[@"root", @"dist", @"build", @"bin"];
    for (NSString *item in itemsToCopy) {
        NSString *sourcePath = [self.clientPortalPath stringByAppendingPathComponent:item];
        NSString *destPath = [workingDir stringByAppendingPathComponent:item];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath]) {
            [[NSFileManager defaultManager] copyItemAtPath:sourcePath
                                                    toPath:destPath
                                                     error:nil];
        }
    }
    
    NSString *newRunScript = [workingDir stringByAppendingPathComponent:@"bin/run.sh"];
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0755}
                                     ofItemAtPath:newRunScript
                                            error:nil];
    
    self.clientPortalTask = [[NSTask alloc] init];
    self.clientPortalTask.launchPath = @"/bin/bash";
    self.clientPortalTask.currentDirectoryPath = workingDir;
    self.clientPortalTask.arguments = @[relativeRunScript, relativeConfigFile];
    
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    env[@"VERTX_CACHE_DIR"] = javaTmpDir;
    self.clientPortalTask.environment = env;
    
    NSPipe *outputPipe = [NSPipe pipe];
    self.clientPortalTask.standardOutput = outputPipe;
    
    __block BOOL startupDetected = NO;
    __block BOOL completionCalled = NO;
    
    [[outputPipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
        NSData *data = [handle availableData];
        if (data.length > 0) {
            NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"[Client Portal] %@", output);
            
            if ([output containsString:@"Open https://localhost"] && !startupDetected) {
                startupDetected = YES;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!completionCalled) {
                        completionCalled = YES;
                        completion(YES, nil);
                    }
                });
            }
        }
    }];
    
    @try {
        [self.clientPortalTask launch];
        NSLog(@"Auto-launching Client Portal...");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!completionCalled) {
                completionCalled = YES;
                NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1003
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Client Portal startup timeout"}];
                completion(NO, error);
            }
        });
        
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        completion(NO, error);
    }
}

#pragma mark - Authentication Flow

- (void)promptForLogin:(void (^)(BOOL success, NSError *error))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"IBKR Login Required";
        alert.informativeText = @"Client Portal is running.\nPlease choose how to login:";
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"Open in App"];       // WebView option
        [alert addButtonWithTitle:@"Open in Browser"];   // External browser
        [alert addButtonWithTitle:@"I'll Login Myself"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSModalResponse response = [alert runModal];
        
        if (response == NSAlertFirstButtonReturn) {
            // Use integrated WebView
            [self openLoginInAppWithCompletion:completion];
            
        } else if (response == NSAlertSecondButtonReturn) {
            // Use external browser
            [self openLoginPageInBrowser];
            [self waitForAuthenticationWithCompletion:completion];
            
        } else if (response == NSAlertThirdButtonReturn) {
            // Just wait for manual login
            [self waitForAuthenticationWithCompletion:completion];
            
        } else {
            // Cancel
            NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1005
                                             userInfo:@{NSLocalizedDescriptionKey: @"Login cancelled by user"}];
            completion(NO, error);
        }
    });
}

- (void)openLoginInAppWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    self.authWindowController = [[IBKRAuthWindowController alloc] initWithPort:self.port];
    
    __weak typeof(self) weakSelf = self;
    self.authWindowController.completionHandler = ^(BOOL success, NSError *error) {
        if (completion) {
            completion(success, error);
        }
        weakSelf.authWindowController = nil;
    };
    
    [self.authWindowController showWindow:nil];
    [self.authWindowController startAuthenticationFlow];
}

- (void)waitForAuthenticationWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"Waiting for IBKR authentication...");
    
    __block int attempts = 0;
    const int maxAttempts = 30;
    
    self.authCheckTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *timer) {
        attempts++;
        
        [self checkClientPortalStatus:^(BOOL running, BOOL authenticated) {
            if (authenticated) {
                [timer invalidate];
                self.authCheckTimer = nil;
                NSLog(@"IBKR authentication successful!");
                completion(YES, nil);
            } else if (attempts >= maxAttempts) {
                [timer invalidate];
                self.authCheckTimer = nil;
                NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1006
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Authentication timeout. Please try again."}];
                completion(NO, error);
            } else if (!running) {
                [timer invalidate];
                self.authCheckTimer = nil;
                NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1007
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Client Portal stopped running"}];
                completion(NO, error);
            }
        }];
    }];
}

#pragma mark - Status Checking with Enhanced Cookie Management

- (void)checkClientPortalStatus:(void (^)(BOOL running, BOOL authenticated))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://localhost:%ld/v1/api/iserver/auth/status", (long)self.port];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 5.0;
    
    // ✅ ENHANCED: Cookie sharing configuration for external browser support
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    config.HTTPShouldSetCookies = YES;
    config.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:(id<NSURLSessionDelegate>)self
                                                     delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"❌ Auth status check failed: %@", error.localizedDescription);
            completion(NO, NO);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"📡 Auth status response: %ld", (long)httpResponse.statusCode);
        
        if (httpResponse.statusCode != 200) {
            completion(NO, NO);
            return;
        }
        
        BOOL authenticated = NO;
        if (data) {
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!jsonError) {
                authenticated = [json[@"authenticated"] boolValue] && [json[@"connected"] boolValue];
                NSLog(@"🔍 Auth response: authenticated=%@, connected=%@",
                      json[@"authenticated"], json[@"connected"]);
            }
        }
        
        // ✅ ENHANCED: Extract session cookie when authenticated
        if (authenticated) {
            [self extractSessionCookieFromStorage];
        }
        
        completion(YES, authenticated);
    }];
    
    [task resume];
}

#pragma mark - Enhanced Cookie Management for External Browser

- (void)extractSessionCookieFromStorage {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSString *urlString = [NSString stringWithFormat:@"https://localhost:%ld", (long)self.port];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSArray<NSHTTPCookie *> *cookies = [cookieStorage cookiesForURL:url];
    NSLog(@"🔍 Found %lu cookies for localhost:%ld", (unsigned long)cookies.count, (long)self.port);
    
    for (NSHTTPCookie *cookie in cookies) {
        NSLog(@"🍪 Cookie: %@ = %@", cookie.name, cookie.value);
        
        if ([cookie.name isEqualToString:@"x-sess-uuid"]) {
            self.internalSessionCookie = cookie.value;
            NSLog(@"✅ Extracted session cookie: %@", cookie.value);
            return;
        }
    }
    
    NSLog(@"⚠️ x-sess-uuid cookie not found in storage");
    
    // Fallback: Force refresh session cookie
    [self forceRefreshSessionCookie];
}

- (void)forceRefreshSessionCookie {
    NSLog(@"🔄 Forcing session cookie refresh...");
    
    NSString *urlString = [NSString stringWithFormat:@"https://localhost:%ld/v1/api/tickle", (long)self.port];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    config.HTTPShouldSetCookies = YES;
    config.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:(id<NSURLSessionDelegate>)self
                                                     delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSLog(@"🔄 Tickle call completed, re-checking cookies...");
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self extractSessionCookieFromStorage];
            });
        }
    }];
    
    [task resume];
}

#pragma mark - Debug Methods

- (void)debugAllCookies {
    NSLog(@"🔍 === DEBUGGING ALL COOKIES ===");
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray<NSHTTPCookie *> *allCookies = cookieStorage.cookies;
    
    NSLog(@"📊 Total cookies in storage: %lu", (unsigned long)allCookies.count);
    
    for (NSHTTPCookie *cookie in allCookies) {
        if ([cookie.domain containsString:@"localhost"]) {
            NSLog(@"🍪 Localhost cookie: %@ = %@ (domain: %@)",
                  cookie.name, cookie.value, cookie.domain);
        }
    }
    
    NSString *urlString = [NSString stringWithFormat:@"https://localhost:%ld", (long)self.port];
    NSURL *url = [NSURL URLWithString:urlString];
    NSArray<NSHTTPCookie *> *urlCookies = [cookieStorage cookiesForURL:url];
    
    NSLog(@"🎯 Cookies for %@: %lu", urlString, (unsigned long)urlCookies.count);
    NSLog(@"🔍 Internal session cookie: %@", self.internalSessionCookie ?: @"NOT SET");
    NSLog(@"🔍 === END DEBUG ===");
}

- (void)refreshSessionCookie {
    NSLog(@"🔄 Manual session cookie refresh requested");
    [self extractSessionCookieFromStorage];
    [self debugAllCookies];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    
    NSString *host = challenge.protectionSpace.host;
    if ([host isEqualToString:@"localhost"] || [host isEqualToString:@"127.0.0.1"]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)openLoginPageInBrowser {
    NSString *urlString = [NSString stringWithFormat:@"https://localhost:%ld", (long)self.port];
    NSURL *url = [NSURL URLWithString:urlString];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark - Auto-Discovery

- (void)findClientPortalInstallation {
    NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
    NSString *clientPortalPath = [bundlePath stringByAppendingPathComponent:@"clientportal"];
    
    NSString *runScript = [clientPortalPath stringByAppendingPathComponent:@"bin/run.sh"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:runScript]) {
        self.clientPortalPath = clientPortalPath;
        NSLog(@"Found bundled Client Portal: %@", clientPortalPath);
        return;
    }
    
    NSLog(@"Bundled Client Portal not found");
}

- (void)dealloc {
    if (self.authCheckTimer) {
        [self.authCheckTimer invalidate];
    }
    if (self.clientPortalTask && self.clientPortalTask.isRunning) {
        [self.clientPortalTask terminate];
    }
}

@end
