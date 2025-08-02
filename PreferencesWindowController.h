//
//  PreferencesWindowController.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>

@interface PreferencesWindowController : NSWindowController

// Database Reset Tab (aggiungi alle altre properties)
@property (nonatomic, strong) NSButton *resetSymbolsButton;
@property (nonatomic, strong) NSButton *resetWatchlistsButton;
@property (nonatomic, strong) NSButton *resetAlertsButton;
@property (nonatomic, strong) NSButton *resetConnectionsButton;
@property (nonatomic, strong) NSButton *resetAllDatabasesButton;
@property (nonatomic, strong) NSTextField *databaseStatusLabel;

+ (instancetype)sharedController;
- (void)showPreferences;

@end
