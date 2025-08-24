

// IBKRLoginManager.m
#import "IBKRLoginManager.h"
#import <Cocoa/Cocoa.h>


@interface IBKRLoginManager()
@property (nonatomic, strong) NSTask *clientPortalTask;
@property (nonatomic, strong) NSTimer *authCheckTimer;
@end

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
        [self findClientPortalInstallation];
    }
    return self;
}

#pragma mark - Main Integration Method

- (void)ensureClientPortalReadyWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion {
    // 1. Check if already running and authenticated
    [self checkClientPortalStatus:^(BOOL running, BOOL authenticated) {
        if (running && authenticated) {
            // Already good to go
            completion(YES, nil);
            return;
        }
        
        if (running && !authenticated) {
            // Running but not authenticated - just need login
            [self promptForLogin:completion];
            return;
        }
        
        // Not running - need to launch
        if (!self.autoLaunchEnabled || !self.clientPortalPath) {
            NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"Client Portal not running. Please start manually or enable auto-launch."}];
            completion(NO, error);
            return;
        }
        
        // Auto-launch Client Portal
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
    if (self.clientPortalTask && self.clientPortalTask.isRunning) {
        completion(YES, nil);
        return;
    }
    
    NSString *runScript = [self.clientPortalPath stringByAppendingPathComponent:@"bin/run.sh"];
    NSString *configFile = [self.clientPortalPath stringByAppendingPathComponent:@"root/conf.yaml"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:runScript]) {
        NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Client Portal run.sh not found"}];
        completion(NO, error);
        return;
    }
    
    // Create task
    self.clientPortalTask = [[NSTask alloc] init];
    self.clientPortalTask.launchPath = runScript;
    self.clientPortalTask.arguments = @[configFile];
    self.clientPortalTask.currentDirectoryPath = [self.clientPortalPath stringByAppendingPathComponent:@"bin"];
    
    // Monitor output for startup confirmation
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
    
    // Launch with error handling
    @try {
        [self.clientPortalTask launch];
        NSLog(@"🚀 Auto-launching Client Portal...");
        
        // Timeout fallback
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
    // Show user-friendly dialog
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"IBKR Login Required";
        alert.informativeText = @"Client Portal is running. Please login in your browser to continue.";
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"Open Login & Wait"];
        [alert addButtonWithTitle:@"I'll Login Myself"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSModalResponse response = [alert runModal];
        
        if (response == NSAlertFirstButtonReturn) {
            // Open browser and wait for auth
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://localhost:5000"]];
            [self waitForAuthenticationWithCompletion:completion];
        } else if (response == NSAlertSecondButtonReturn) {
            // Just wait for auth without opening browser
            [self waitForAuthenticationWithCompletion:completion];
        } else {
            // Cancel
            NSError *error = [NSError errorWithDomain:@"IBKRLoginManager" code:1005
                                             userInfo:@{NSLocalizedDescriptionKey: @"Login cancelled by user"}];
            completion(NO, error);
        }
    });
}

- (void)waitForAuthenticationWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"⏳ Waiting for IBKR authentication...");
    
    __block int attempts = 0;
    const int maxAttempts = 30; // 1 minute with 2-second intervals
    
    self.authCheckTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *timer) {
        attempts++;
        
        [self checkClientPortalStatus:^(BOOL running, BOOL authenticated) {
            if (authenticated) {
                [timer invalidate];
                self.authCheckTimer = nil;
                NSLog(@"✅ IBKR authentication successful!");
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

#pragma mark - Status Checking

- (void)checkClientPortalStatus:(void (^)(BOOL running, BOOL authenticated))completion {
    NSURL *url = [NSURL URLWithString:@"https://localhost:5000/v1/api/iserver/auth/status"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 5.0;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(NO, NO);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
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
            }
        }
        
        completion(YES, authenticated);
    }];
    
    [task resume];
}

#pragma mark - Auto-Discovery

- (void)findClientPortalInstallation {
    NSArray *searchPaths = @[
        [@"~/Downloads/clientportal.gw" stringByExpandingTildeInPath],
        [@"~/Applications/clientportal.gw" stringByExpandingTildeInPath],
        [@"/Applications/clientportal.gw" stringByExpandingTildeInPath],
    ];
    
    for (NSString *path in searchPaths) {
        NSString *runScript = [path stringByAppendingPathComponent:@"bin/run.sh"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:runScript]) {
            self.clientPortalPath = path;
            NSLog(@"📍 Auto-found Client Portal: %@", path);
            return;
        }
    }
    
    NSLog(@"⚠️ Client Portal not found automatically. Set clientPortalPath manually if needed.");
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
