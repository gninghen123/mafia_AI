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

@property (nonatomic, strong) NSPopUpButton *trackingPresetPopup;
@property (nonatomic, strong) NSTextField *presetDescriptionLabel;
@property (nonatomic, strong) NSButton *optimizedTrackingToggle;

@property (nonatomic, strong) NSSlider *userDefaultsIntervalSlider;
@property (nonatomic, strong) NSTextField *userDefaultsIntervalLabel;
@property (nonatomic, strong) NSTextField *userDefaultsIntervalValue;

@property (nonatomic, strong) NSSlider *coreDataIntervalSlider;
@property (nonatomic, strong) NSTextField *coreDataIntervalLabel;
@property (nonatomic, strong) NSTextField *coreDataIntervalValue;
@property (nonatomic, strong) NSButton *coreDataAppCloseOnlyToggle;

@property (nonatomic, strong) NSSlider *maxBatchSizeSlider;
@property (nonatomic, strong) NSTextField *maxBatchSizeLabel;
@property (nonatomic, strong) NSTextField *maxBatchSizeValue;

@property (nonatomic, strong) NSSlider *chunkSizeSlider;
@property (nonatomic, strong) NSTextField *chunkSizeLabel;
@property (nonatomic, strong) NSTextField *chunkSizeValue;

@property (nonatomic, strong) NSButton *flushOnBackgroundToggle;
@property (nonatomic, strong) NSButton *flushOnTerminateToggle;

@property (nonatomic, strong) NSButton *forceUserDefaultsBackupButton;
@property (nonatomic, strong) NSButton *forceCoreDataFlushButton;
@property (nonatomic, strong) NSButton *resetToDefaultsButton;

@property (nonatomic, strong) NSTextField *currentStatusLabel;
@property (nonatomic, strong) NSTextField *nextOperationsLabel;


+ (instancetype)sharedController;
- (void)showPreferences;

@end
