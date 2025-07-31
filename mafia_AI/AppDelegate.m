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

@end
