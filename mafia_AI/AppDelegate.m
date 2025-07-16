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

@interface AppDelegate ()
@property (nonatomic, strong) MainWindowController *mainWindowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Registra data sources
    [self registerDataSources];
    
    // Crea e mostra la finestra principale
    self.mainWindowController = [[MainWindowController alloc] init];
    [self.mainWindowController showWindow:self];
}

- (void)registerDataSources {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // Registra Schwab data source
    SchwabDataSource *schwabSource = [[SchwabDataSource alloc] init];
    [downloadManager registerDataSource:schwabSource
                               withType:DataSourceTypeSchwab
                               priority:1];
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

@end
