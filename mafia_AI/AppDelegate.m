//
//  AppDelegate.m
//  trading app
//
//  Created by fabio gattone on 16/07/25.
//

#import "AppDelegate.h"
#import "MainWindowController.h"
#import "DownloadManager.h"
#import "SchwabDataSource.h"
#import "WebullDataSource.h"
#import "DataHub.h"
#import "ClaudeDataSource.h"


@interface AppDelegate ()
@property (nonatomic, strong) MainWindowController *mainWindowController;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"AppDelegate: applicationDidFinishLaunching called");
    [DataHub shared];

     // Registra data sources
     [self registerDataSources];
     
     // Crea e mostra la finestra principale
     NSLog(@"AppDelegate: Creating MainWindowController");
     self.mainWindowController = [[MainWindowController alloc] init];
     
     NSLog(@"AppDelegate: Showing window");
     [self.mainWindowController showWindow:self];
     
     // IMPORTANTE: Porta l'app in primo piano
     [NSApp activateIgnoringOtherApps:YES];
     
     // NUOVO: Connetti automaticamente a Schwab dopo un breve delay
     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
         [self autoConnectToSchwab];
     });
    [self setupClaudeDataSource];

}

- (void)registerDataSources {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // Registra Schwab data source
    SchwabDataSource *schwabSource = [[SchwabDataSource alloc] init];
    [downloadManager registerDataSource:schwabSource
                               withType:DataSourceTypeSchwab
                               priority:1];
    
    // Registra Webull data source - FIXED: Use correct type
    WebullDataSource *webullSource = [[WebullDataSource alloc] init];
    [downloadManager registerDataSource:webullSource
                               withType:DataSourceTypeWebull  // FIXED: Use correct type
                               priority:2];  // Priority più bassa di Schwab
    
    NSLog(@"AppDelegate: Registered Schwab (priority 1) and Webull (priority 2) data sources");
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Cleanup code
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}


- (void)autoConnectToSchwabWithPreferences {
    // Controlla se l'utente ha abilitato la connessione automatica
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL autoConnectEnabled = [defaults boolForKey:@"AutoConnectSchwab"];
    
    if (!autoConnectEnabled) {
        NSLog(@"Auto-connect disabled by user");
        return;
    }
    
    [self autoConnectToSchwab];
}

- (void)autoConnectToSchwab {
    NSLog(@"AppDelegate: Attempting auto-connection to Schwab...");
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // Controlla se Schwab è già connesso
    if ([downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        NSLog(@"AppDelegate: Schwab already connected");
        return;
    }
    
    // Prova a connettersi automaticamente
    [downloadManager connectDataSource:DataSourceTypeSchwab
                            completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"AppDelegate: Schwab auto-connection successful");
                
                // Opzionale: Mostra una notifica di successo
                //todo inserire preferenza per non mosrtare piu
               // [self showConnectionNotification:@"Connected to Schwab" success:YES];
            } else {
                NSLog(@"AppDelegate: Schwab auto-connection failed: %@", error.localizedDescription);
                
                // Opzionale: Mostra notifica di errore (solo per errori non di autenticazione)
                if (error.code != 401) { // Non mostrare errori di autenticazione
                    [self showConnectionNotification:@"Schwab connection failed" success:NO];
                }
            }
        });
    }];
}

// NUOVO METODO: Mostra notifiche di connessione (opzionale)
- (void)showConnectionNotification:(NSString *)message success:(BOOL)success {
    // Crea una notifica discreta nell'app
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = success ? @"Connection Successful" : @"Connection Failed";
    alert.informativeText = message;
    alert.alertStyle = success ? NSAlertStyleInformational : NSAlertStyleWarning;
    
    // Mostra come sheet invece di modal (meno invasivo)
    if (self.mainWindowController.window) {
        [alert beginSheetModalForWindow:self.mainWindowController.window
                      completionHandler:nil];
        
        // Auto-chiudi dopo 3 secondi se successo
        if (success) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.mainWindowController.window endSheet:alert.window];
            });
        }
    }
}

#pragma mark - cluade api

- (void)setupClaudeDataSource {
    NSLog(@"AppDelegate: Setting up Claude AI Data Source");
    
    // Load API key from secure storage or settings
    NSString *claudeApiKey = [self loadClaudeAPIKey];
    
    if (!claudeApiKey || claudeApiKey.length == 0) {
        NSLog(@"AppDelegate: Claude API key not found - AI features will be disabled");
        NSLog(@"AppDelegate: Please configure Claude API key in app settings");
        return;
    }
    
    // Create and configure Claude data source
    ClaudeDataSource *claudeSource = [[ClaudeDataSource alloc] initWithAPIKey:claudeApiKey];
    
    // Optional: Update configuration from app settings
    NSDictionary *claudeConfig = [self loadClaudeConfiguration];
    if (claudeConfig) {
        [claudeSource updateConfiguration:claudeConfig];
    }
    
    // Register with DownloadManager
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    [downloadManager registerDataSource:claudeSource
                                withType:DataSourceTypeClaude
                                priority:1]; // High priority for AI requests
    
    // Test connection
    [claudeSource connectWithCompletion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"AppDelegate: Claude AI connected successfully");
        } else {
            NSLog(@"AppDelegate: Claude AI connection failed: %@", error.localizedDescription);
        }
    }];
}

// NUOVO: Load API key from secure storage
- (NSString *)loadClaudeAPIKey {
    // In production, questo dovrebbe essere caricato dal Keychain o da un file di configurazione sicuro
    // Per ora, supportiamo alcune opzioni:
    
    // 1. Check environment variable (for development)
    NSString *envKey = [[[NSProcessInfo processInfo] environment] objectForKey:@"CLAUDE_API_KEY"];
    if (envKey && envKey.length > 0) {
        return envKey;
    }
    
    // 2. Check app settings/preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *settingsKey = [defaults stringForKey:@"ClaudeAPIKey"];
    if (settingsKey && settingsKey.length > 0) {
        return settingsKey;
    }
    
    // 3. Check configuration file (claude_config.plist in app bundle)
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"claude_config" ofType:@"plist"];
    if (configPath) {
        NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
        NSString *configKey = config[@"apiKey"];
        if (configKey && configKey.length > 0) {
            return configKey;
        }
    }
    
    // 4. TODO: Load from macOS Keychain (most secure option)
    // NSString *keychainKey = [self loadFromKeychain:@"ClaudeAPIKey"];
    
    return nil;
}

// NUOVO: Load Claude configuration
- (NSDictionary *)loadClaudeConfiguration {
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    
    // Load from app settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *baseURL = [defaults stringForKey:@"ClaudeBaseURL"];
    if (baseURL) config[@"baseURL"] = baseURL;
    
    NSString *model = [defaults stringForKey:@"ClaudeModel"];
    if (model) config[@"model"] = model;
    
    NSNumber *timeout = [defaults objectForKey:@"ClaudeTimeout"];
    if (timeout) config[@"timeout"] = timeout;
    
    // Load from config file if exists
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"claude_config" ofType:@"plist"];
    if (configPath) {
        NSDictionary *fileConfig = [NSDictionary dictionaryWithContentsOfFile:configPath];
        [config addEntriesFromDictionary:fileConfig];
    }
    
    return config.count > 0 ? [config copy] : nil;
}

// NUOVO: Utility method to save API key (for preferences window)
- (void)saveClaudeAPIKey:(NSString *)apiKey {
    if (!apiKey) return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:apiKey forKey:@"ClaudeAPIKey"];
    [defaults synchronize];
    
    NSLog(@"AppDelegate: Claude API key saved to preferences");
    
    // Restart Claude data source with new key
    [self setupClaudeDataSource];
}

// NUOVO: Utility method to test Claude connection
- (void)testClaudeConnection:(void (^)(BOOL success, NSError *error))completion {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    if (![downloadManager isDataSourceConnected:DataSourceTypeClaude]) {
        NSError *error = [NSError errorWithDomain:@"AppDelegate"
                                             code:503
                                         userInfo:@{NSLocalizedDescriptionKey: @"Claude data source not connected"}];
        if (completion) completion(NO, error);
        return;
    }
    
    // Execute a simple test request
    NSDictionary *testParams = @{
        @"text": @"Hello, this is a test.",
        @"maxTokens": @(10),
        @"temperature": @(0.1),
        @"requestType": @"textSummary"
    };
    
    [downloadManager executeRequest:DataRequestTypeTextSummary
                         parameters:testParams
                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error == nil, error);
            });
        }
    }];
}

@end
