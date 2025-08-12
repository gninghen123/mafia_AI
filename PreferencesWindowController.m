//
//  PreferencesWindowController.m
//  TradingApp
//

#import "PreferencesWindowController.h"
#import "AppSettings.h"
#import "datahub.h"
#import "connectionmodel.h"
#import "DataHub+TrackingPreferences.h"
#import <objc/runtime.h>

@interface PreferencesWindowController ()

// UI Elements
@property (nonatomic, strong) NSTabView *tabView;

// General Settings Tab
@property (nonatomic, strong) NSTextField *priceUpdateIntervalField;
@property (nonatomic, strong) NSTextField *alertBackupIntervalField;
@property (nonatomic, strong) NSButton *autosaveLayoutsCheckbox;

// Alert Settings Tab
@property (nonatomic, strong) NSButton *alertSoundsCheckbox;
@property (nonatomic, strong) NSButton *alertPopupsCheckbox;
@property (nonatomic, strong) NSPopUpButton *alertSoundPopup;

// Data Source Settings Tab
@property (nonatomic, strong) NSButton *enableYahooCheckbox;
@property (nonatomic, strong) NSButton *enableSchwabCheckbox;
@property (nonatomic, strong) NSButton *enableIBKRCheckbox;

// Appearance Settings Tab
@property (nonatomic, strong) NSPopUpButton *themePopup;
@property (nonatomic, strong) NSColorWell *accentColorWell;

@end

@implementation PreferencesWindowController

+ (instancetype)sharedController {
    static PreferencesWindowController *sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[self alloc] init];
    });
    return sharedController;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupWindow];
        [self setupUI];
        [self loadSettings];
    }
    return self;
}

- (void)setupWindow {
    NSRect frame = NSMakeRect(0, 0, 600, 700);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled |
                        NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.title = @"Preferences";
    window.restorable = NO;
    [window center];
    
    self.window = window;
}

- (void)setupUI {
    NSView *contentView = self.window.contentView;
    
    // Create tab view
    self.tabView = [[NSTabView alloc] init];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.tabView];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
           [self.tabView.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor constant:20],
           [self.tabView.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:20],
           [self.tabView.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-20],
           [self.tabView.bottomAnchor constraintEqualToAnchor:self.window.contentView.bottomAnchor constant:-70] // Space for buttons
       ]];
    
    // Add tabs
    [self setupGeneralTab];
    [self setupAlertTab];
    [self setupDataSourceTab];
    [self setupAppearanceTab];
    [self setupButtons];
    [self setupDatabaseTab];
    [self setupPerformanceTab];


}

- (void)setupPerformanceTab {
    NSLog(@"🚀 setupPerformanceTab - START COMPLETE VERSION");
    
    NSTabViewItem *performanceTab = [[NSTabViewItem alloc] init];
    performanceTab.label = @"Performance";
    performanceTab.identifier = @"performance";
    
    NSView *performanceView = [[NSView alloc] init];
    
    // Main stack per tutto il contenuto
    NSStackView *mainStack = [[NSStackView alloc] init];
    mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStack.spacing = 20;
    mainStack.alignment = NSLayoutAttributeLeading;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 1. HEADER SECTION
    NSTextField *titleLabel = [self createLabel:@"Performance & Tracking Settings"];
    titleLabel.font = [NSFont boldSystemFontOfSize:16];
    
    NSTextField *descLabel = [self createLabel:@"Configure how symbol interactions are tracked and saved. Optimized tracking improves UI responsiveness by batching operations."];
    descLabel.textColor = [NSColor secondaryLabelColor];
    descLabel.font = [NSFont systemFontOfSize:11];
    descLabel.lineBreakMode = NSLineBreakByWordWrapping;
    descLabel.usesSingleLineMode = NO;
    
    [mainStack addArrangedSubview:titleLabel];
    [mainStack addArrangedSubview:descLabel];
    
    // 2. PRESET SECTION
    NSTextField *presetSectionLabel = [self createLabel:@"Quick Configuration"];
    presetSectionLabel.font = [NSFont boldSystemFontOfSize:14];
    [mainStack addArrangedSubview:presetSectionLabel];
    
    // Preset dropdown
    NSStackView *presetRow = [[NSStackView alloc] init];
    presetRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    presetRow.spacing = 10;
    presetRow.alignment = NSLayoutAttributeCenterY;
    
    NSTextField *presetLabel = [self createLabel:@"Performance Preset:"];
    [presetLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    self.trackingPresetPopup = [[NSPopUpButton alloc] init];
    [self.trackingPresetPopup addItemsWithTitles:@[
        @"Real-time (Immediate saves)",
        @"Balanced (10min/1h) - Recommended",
        @"Performance (30min/4h)",
        @"Minimal (1h/app-close)",
        @"Custom Settings"
    ]];
    self.trackingPresetPopup.target = self;
    self.trackingPresetPopup.action = @selector(trackingPresetChanged:);
    
    [presetRow addArrangedSubview:presetLabel];
    [presetRow addArrangedSubview:self.trackingPresetPopup];
    [presetRow addArrangedSubview:[[NSView alloc] init]]; // Spacer
    
    // Preset description
    self.presetDescriptionLabel = [self createLabel:@""];
    self.presetDescriptionLabel.textColor = [NSColor secondaryLabelColor];
    self.presetDescriptionLabel.font = [NSFont systemFontOfSize:11];
    self.presetDescriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.presetDescriptionLabel.usesSingleLineMode = NO;
    
    [mainStack addArrangedSubview:presetRow];
    [mainStack addArrangedSubview:self.presetDescriptionLabel];
    
    // 3. OPTIMIZATION TOGGLE SECTION
    NSTextField *optimSectionLabel = [self createLabel:@"Optimization Mode"];
    optimSectionLabel.font = [NSFont boldSystemFontOfSize:14];
    [mainStack addArrangedSubview:optimSectionLabel];
    
    self.optimizedTrackingToggle = [self createCheckbox:@"Enable Optimized Tracking"];
    self.optimizedTrackingToggle.target = self;
    self.optimizedTrackingToggle.action = @selector(optimizedTrackingToggled:);
    
    NSTextField *optimDesc = [self createLabel:@"When enabled, symbol interactions are batched and saved in background. When disabled, each interaction is saved immediately (may cause UI lag)."];
    optimDesc.textColor = [NSColor secondaryLabelColor];
    optimDesc.font = [NSFont systemFontOfSize:11];
    optimDesc.lineBreakMode = NSLineBreakByWordWrapping;
    optimDesc.usesSingleLineMode = NO;
    
    [mainStack addArrangedSubview:self.optimizedTrackingToggle];
    [mainStack addArrangedSubview:optimDesc];
    
  
    // 4. TIMING SECTION
       NSTextField *timingSectionLabel = [self createLabel:@"Save Timing"];
       timingSectionLabel.font = [NSFont boldSystemFontOfSize:14];
       [mainStack addArrangedSubview:timingSectionLabel];
       
       // UserDefaults slider - USA VARIABILI LOCALI
       NSSlider *udSlider;
       NSTextField *udValueLabel;
       NSStackView *udSliderRow = [self createSimpleSliderRow:@"Memory Backup Interval:"
                                                      minValue:1.0
                                                      maxValue:120.0
                                                        slider:&udSlider
                                                    valueLabel:&udValueLabel
                                                        action:@selector(userDefaultsIntervalChanged:)
                                                        suffix:@" min"];
       // Assegna alle proprietà DOPO la creazione
       self.userDefaultsIntervalSlider = udSlider;
       self.userDefaultsIntervalValue = udValueLabel;
       [mainStack addArrangedSubview:udSliderRow];
       
       // Core Data slider - USA VARIABILI LOCALI
       NSSlider *cdSlider;
       NSTextField *cdValueLabel;
       NSStackView *cdSliderRow = [self createSimpleSliderRow:@"Database Save Interval:"
                                                      minValue:5.0
                                                      maxValue:360.0
                                                        slider:&cdSlider
                                                    valueLabel:&cdValueLabel
                                                        action:@selector(coreDataIntervalChanged:)
                                                        suffix:@" min"];
       // Assegna alle proprietà DOPO la creazione
       self.coreDataIntervalSlider = cdSlider;
       self.coreDataIntervalValue = cdValueLabel;
       [mainStack addArrangedSubview:cdSliderRow];

  
       // 5. BATCH SECTION
       NSTextField *batchSectionLabel = [self createLabel:@"Batch Processing"];
       batchSectionLabel.font = [NSFont boldSystemFontOfSize:14];
       [mainStack addArrangedSubview:batchSectionLabel];
       
       // Max batch size slider - USA VARIABILI LOCALI
       NSSlider *maxBatchSlider;
       NSTextField *maxBatchValueLabel;
       NSStackView *maxBatchRow = [self createSimpleSliderRow:@"Maximum Batch Size:"
                                                      minValue:100
                                                      maxValue:5000
                                                        slider:&maxBatchSlider
                                                    valueLabel:&maxBatchValueLabel
                                                        action:@selector(maxBatchSizeChanged:)
                                                        suffix:@" symbols"];
       // Assegna alle proprietà DOPO la creazione
       self.maxBatchSizeSlider = maxBatchSlider;
       self.maxBatchSizeValue = maxBatchValueLabel;
       [mainStack addArrangedSubview:maxBatchRow];
       
       // Chunk size slider - USA VARIABILI LOCALI
       NSSlider *chunkSlider;
       NSTextField *chunkValueLabel;
       NSStackView *chunkSizeRow = [self createSimpleSliderRow:@"Processing Chunk Size:"
                                                       minValue:25
                                                       maxValue:500
                                                         slider:&chunkSlider
                                                     valueLabel:&chunkValueLabel
                                                         action:@selector(chunkSizeChanged:)
                                                         suffix:@" symbols"];
       // Assegna alle proprietà DOPO la creazione
       self.chunkSizeSlider = chunkSlider;
       self.chunkSizeValue = chunkValueLabel;
       [mainStack addArrangedSubview:chunkSizeRow];

 

    
    // 6. APP LIFECYCLE SECTION
    NSTextField *lifecycleSectionLabel = [self createLabel:@"App Lifecycle"];
    lifecycleSectionLabel.font = [NSFont boldSystemFontOfSize:14];
    [mainStack addArrangedSubview:lifecycleSectionLabel];
    
    self.flushOnBackgroundToggle = [self createCheckbox:@"Save pending changes when app goes to background"];
    self.flushOnBackgroundToggle.target = self;
    self.flushOnBackgroundToggle.action = @selector(flushOnBackgroundToggled:);
    
    self.flushOnTerminateToggle = [self createCheckbox:@"Save pending changes when app terminates"];
    self.flushOnTerminateToggle.target = self;
    self.flushOnTerminateToggle.action = @selector(flushOnTerminateToggled:);
    
    [mainStack addArrangedSubview:self.flushOnBackgroundToggle];
    [mainStack addArrangedSubview:self.flushOnTerminateToggle];
    
    // 7. MANUAL ACTIONS SECTION
    NSTextField *actionsSectionLabel = [self createLabel:@"Manual Actions"];
    actionsSectionLabel.font = [NSFont boldSystemFontOfSize:14];
    [mainStack addArrangedSubview:actionsSectionLabel];
    
    NSStackView *actionsRow = [[NSStackView alloc] init];
    actionsRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actionsRow.spacing = 12;
    actionsRow.alignment = NSLayoutAttributeCenterY;
    
    self.forceUserDefaultsBackupButton = [[NSButton alloc] init];
    self.forceUserDefaultsBackupButton.title = @"Backup Now";
    self.forceUserDefaultsBackupButton.bezelStyle = NSBezelStyleRounded;
    self.forceUserDefaultsBackupButton.target = self;
    self.forceUserDefaultsBackupButton.action = @selector(forceUserDefaultsBackup:);
    
    self.forceCoreDataFlushButton = [[NSButton alloc] init];
    self.forceCoreDataFlushButton.title = @"Save to Database";
    self.forceCoreDataFlushButton.bezelStyle = NSBezelStyleRounded;
    self.forceCoreDataFlushButton.target = self;
    self.forceCoreDataFlushButton.action = @selector(forceCoreDataFlush:);
    
    self.resetToDefaultsButton = [[NSButton alloc] init];
    self.resetToDefaultsButton.title = @"Reset to Defaults";
    self.resetToDefaultsButton.bezelStyle = NSBezelStyleRounded;
    self.resetToDefaultsButton.target = self;
    self.resetToDefaultsButton.action = @selector(resetTrackingToDefaults:);
    
    [actionsRow addArrangedSubview:self.forceUserDefaultsBackupButton];
    [actionsRow addArrangedSubview:self.forceCoreDataFlushButton];
    [actionsRow addArrangedSubview:[[NSView alloc] init]]; // Spacer
    [actionsRow addArrangedSubview:self.resetToDefaultsButton];
    
    [mainStack addArrangedSubview:actionsRow];
    
    // 8. STATUS SECTION
    NSTextField *statusSectionLabel = [self createLabel:@"Current Status"];
    statusSectionLabel.font = [NSFont boldSystemFontOfSize:14];
    [mainStack addArrangedSubview:statusSectionLabel];
    
    self.currentStatusLabel = [self createLabel:@"Loading configuration..."];
    self.currentStatusLabel.textColor = [NSColor secondaryLabelColor];
    self.currentStatusLabel.font = [NSFont systemFontOfSize:11];
    
    self.nextOperationsLabel = [self createLabel:@""];
    self.nextOperationsLabel.textColor = [NSColor tertiaryLabelColor];
    self.nextOperationsLabel.font = [NSFont systemFontOfSize:11];
    
    [mainStack addArrangedSubview:self.currentStatusLabel];
    [mainStack addArrangedSubview:self.nextOperationsLabel];
    
    // LAYOUT FINAL
    [performanceView addSubview:mainStack];
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:performanceView.topAnchor constant:20],
        [mainStack.leadingAnchor constraintEqualToAnchor:performanceView.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:performanceView.trailingAnchor constant:-20],
        [mainStack.bottomAnchor constraintLessThanOrEqualToAnchor:performanceView.bottomAnchor constant:-20]
    ]];
    
    performanceTab.view = performanceView;
    [self.tabView addTabViewItem:performanceTab];
    
    NSLog(@"🚀 setupPerformanceTab - COMPLETED WITH ALL CONTROLS");
}



// ADD THESE HELPER METHODS to the existing .m file:

- (NSView *)createPerformanceHeader {
    NSStackView *headerStack = [[NSStackView alloc] init];
    headerStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    headerStack.spacing = 8;
    
    NSTextField *titleLabel = [self createBoldLabel:@"Performance & Tracking" fontSize:16];
    NSTextField *descLabel = [self createLabel:@"Configure how symbol interactions are tracked and saved. Optimized tracking improves UI responsiveness by batching operations."];
    descLabel.textColor = [NSColor secondaryLabelColor];
    descLabel.font = [NSFont systemFontOfSize:11];
    
    [headerStack addArrangedSubview:titleLabel];
    [headerStack addArrangedSubview:descLabel];
    
    return [self createSectionBox:headerStack title:nil];
}


- (NSStackView *)createSimpleSliderRow:(NSString *)title
                              minValue:(double)minValue
                              maxValue:(double)maxValue
                                slider:(NSSlider **)slider
                            valueLabel:(NSTextField **)valueLabel
                                action:(SEL)action
                                suffix:(NSString *)suffix {
    
    NSStackView *rowStack = [[NSStackView alloc] init];
    rowStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    rowStack.spacing = 8;
    
    // Title and value row
    NSStackView *titleRow = [[NSStackView alloc] init];
    titleRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    titleRow.alignment = NSLayoutAttributeCenterY;
    
    NSTextField *titleLabel = [self createLabel:title];
    [titleLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    *valueLabel = [self createLabel:@""];
    (*valueLabel).textColor = [NSColor controlAccentColor];
    (*valueLabel).alignment = NSTextAlignmentRight;
    (*valueLabel).font = [NSFont boldSystemFontOfSize:13];
    [*valueLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    [titleRow addArrangedSubview:titleLabel];
    [titleRow addArrangedSubview:[[NSView alloc] init]]; // Spacer
    [titleRow addArrangedSubview:*valueLabel];
    
    // Slider
    *slider = [[NSSlider alloc] init];
    (*slider).minValue = minValue;
    (*slider).maxValue = maxValue;
    (*slider).target = self;
    (*slider).action = action;
    (*slider).continuous = YES;
    
    // Store suffix for value updates
    objc_setAssociatedObject(*slider, @"valueSuffix", suffix, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(*slider, @"valueLabel", *valueLabel, OBJC_ASSOCIATION_ASSIGN);
    
    [rowStack addArrangedSubview:titleRow];
    [rowStack addArrangedSubview:*slider];
    
    return rowStack;
}

- (NSTextField *)createBoldLabel:(NSString *)text fontSize:(CGFloat)fontSize {
    NSTextField *label = [self createLabel:text];
    label.font = [NSFont boldSystemFontOfSize:fontSize];
    return label;
}

- (NSView *)createSectionBox:(NSView *)contentView title:(NSString *)title {
    NSStackView *boxStack = [[NSStackView alloc] init];
    boxStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    boxStack.spacing = 8;
    
    if (title) {
        NSTextField *titleLabel = [self createBoldLabel:title fontSize:14];
        [boxStack addArrangedSubview:titleLabel];
        
        NSBox *separator = [[NSBox alloc] init];
        separator.boxType = NSBoxSeparator;
        [separator.heightAnchor constraintEqualToConstant:1].active = YES;
        [boxStack addArrangedSubview:separator];
    }
    
    [boxStack addArrangedSubview:contentView];
    
    NSView *paddedView = [[NSView alloc] init];
    [paddedView addSubview:boxStack];
    
    boxStack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [boxStack.topAnchor constraintEqualToAnchor:paddedView.topAnchor constant:12],
        [boxStack.leadingAnchor constraintEqualToAnchor:paddedView.leadingAnchor constant:16],
        [boxStack.trailingAnchor constraintEqualToAnchor:paddedView.trailingAnchor constant:-16],
        [boxStack.bottomAnchor constraintEqualToAnchor:paddedView.bottomAnchor constant:-12]
    ]];
    
    return paddedView;
}


- (void)setupDatabaseTab {
   
   
    NSTabViewItem *databaseTab = [[NSTabViewItem alloc] init];
    databaseTab.label = @"Database";
    
    // ✅ CREA UNA VIEW SEMPLICE CON FRAME FISSO
    NSView *databaseView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 550, 700)];
    databaseView.wantsLayer = YES;
    databaseView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    
    NSLog(@"🔍 Created databaseView with frame: %@", NSStringFromRect(databaseView.frame));
    
    databaseTab.view = databaseView;
    
    // Status label con frame fisso
    self.databaseStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 450, 500, 80)];
    self.databaseStatusLabel.stringValue = @"Loading database status...";
    self.databaseStatusLabel.editable = NO;
    self.databaseStatusLabel.bordered = YES;
    self.databaseStatusLabel.backgroundColor = [NSColor controlBackgroundColor];
    self.databaseStatusLabel.textColor = [NSColor secondaryLabelColor];
    self.databaseStatusLabel.font = [NSFont systemFontOfSize:11];
    self.databaseStatusLabel.usesSingleLineMode = NO;
    self.databaseStatusLabel.cell.wraps = YES;
    self.databaseStatusLabel.cell.lineBreakMode = NSLineBreakByWordWrapping;
    self.databaseStatusLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [databaseView addSubview:self.databaseStatusLabel];
    
    // Bottoni con frame fissi
    self.resetSymbolsButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 380, 200, 32)];
    self.resetSymbolsButton.title = @"Reset Symbol Database";
    self.resetSymbolsButton.bezelStyle = NSBezelStyleRounded;
    self.resetSymbolsButton.target = self;
    self.resetSymbolsButton.action = @selector(resetSymbolDatabase:);
    self.resetSymbolsButton.contentTintColor = [NSColor systemOrangeColor];
    [databaseView addSubview:self.resetSymbolsButton];
    
    self.resetWatchlistsButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 340, 200, 32)];
    self.resetWatchlistsButton.title = @"Reset All Watchlists";
    self.resetWatchlistsButton.bezelStyle = NSBezelStyleRounded;
    self.resetWatchlistsButton.target = self;
    self.resetWatchlistsButton.action = @selector(resetWatchlists:);
    self.resetWatchlistsButton.contentTintColor = [NSColor systemOrangeColor];
    [databaseView addSubview:self.resetWatchlistsButton];
    
    self.resetAlertsButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 300, 200, 32)];
    self.resetAlertsButton.title = @"Reset All Alerts";
    self.resetAlertsButton.bezelStyle = NSBezelStyleRounded;
    self.resetAlertsButton.target = self;
    self.resetAlertsButton.action = @selector(resetAlerts:);
    self.resetAlertsButton.contentTintColor = [NSColor systemOrangeColor];
    [databaseView addSubview:self.resetAlertsButton];
    
    self.resetConnectionsButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 260, 200, 32)];
    self.resetConnectionsButton.title = @"Reset All Connections";
    self.resetConnectionsButton.bezelStyle = NSBezelStyleRounded;
    self.resetConnectionsButton.target = self;
    self.resetConnectionsButton.action = @selector(resetConnections:);
    self.resetConnectionsButton.contentTintColor = [NSColor systemOrangeColor];
    [databaseView addSubview:self.resetConnectionsButton];
    
    // Separator
    NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(20, 220, 500, 1)];
    separator.boxType = NSBoxSeparator;
    [databaseView addSubview:separator];
    
    // Nuclear button
    self.resetAllDatabasesButton = [[NSButton alloc] initWithFrame:NSMakeRect(150, 150, 250, 40)];
    self.resetAllDatabasesButton.title = @"🚨 RESET EVERYTHING 🚨";
    self.resetAllDatabasesButton.bezelStyle = NSBezelStyleRounded;
    self.resetAllDatabasesButton.target = self;
    self.resetAllDatabasesButton.action = @selector(resetAllDatabases:);
    self.resetAllDatabasesButton.contentTintColor = [NSColor systemRedColor];
    self.resetAllDatabasesButton.font = [NSFont boldSystemFontOfSize:14];
    [databaseView addSubview:self.resetAllDatabasesButton];
    
    // Warning
    NSTextField *warningLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 100, 500, 40)];
    warningLabel.stringValue = @"⚠️ Warning: These actions cannot be undone. All data will be permanently deleted.";
    warningLabel.editable = NO;
    warningLabel.bordered = NO;
    warningLabel.backgroundColor = [NSColor clearColor];
    warningLabel.textColor = [NSColor systemRedColor];
    warningLabel.font = [NSFont systemFontOfSize:12];
    warningLabel.maximumNumberOfLines = 0;
    warningLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [databaseView addSubview:warningLabel];
    
    NSTextField *nuclearWarning = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, 500, 40)];
    nuclearWarning.stringValue = @"Nuclear option will delete ALL data: symbols, watchlists, alerts, connections, settings";
    nuclearWarning.editable = NO;
    nuclearWarning.bordered = NO;
    nuclearWarning.backgroundColor = [NSColor clearColor];
    nuclearWarning.textColor = [NSColor systemRedColor];
    nuclearWarning.font = [NSFont systemFontOfSize:10];
    nuclearWarning.alignment = NSTextAlignmentCenter;
    nuclearWarning.maximumNumberOfLines = 0;
    nuclearWarning.lineBreakMode = NSLineBreakByWordWrapping;
    [databaseView addSubview:nuclearWarning];
    
    [self.tabView addTabViewItem:databaseTab];
    NSLog(@"🔍 Added tab to tabView");
    NSLog(@"🔍 setupDatabaseTab - START");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          NSLog(@"🔍 Calling updateDatabaseStatus...");
          [self updateDatabaseStatus];
      });
   
}
- (void)setupGeneralTab {
    NSTabViewItem *generalTab = [[NSTabViewItem alloc] init];
    generalTab.label = @"General";
    
    NSView *generalView = [[NSView alloc] init];
    
    // Price update interval
    NSTextField *priceLabel = [self createLabel:@"Price Update Interval (seconds):"];
    self.priceUpdateIntervalField = [self createNumberField];
    
    // Alert backup interval
    NSTextField *alertLabel = [self createLabel:@"Alert Backup Check Interval (seconds):"];
    self.alertBackupIntervalField = [self createNumberField];
    
    // Autosave layouts
    self.autosaveLayoutsCheckbox = [self createCheckbox:@"Auto-save layouts"];
    
    // Layout using stack view
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 15;
    stack.alignment = NSLayoutAttributeLeading;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [stack addArrangedSubview:[self createFieldGroup:priceLabel field:self.priceUpdateIntervalField]];
    [stack addArrangedSubview:[self createFieldGroup:alertLabel field:self.alertBackupIntervalField]];
    [stack addArrangedSubview:self.autosaveLayoutsCheckbox];
    
    [generalView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:generalView.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:generalView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:generalView.trailingAnchor constant:-20]
    ]];
    
    generalTab.view = generalView;
    [self.tabView addTabViewItem:generalTab];
}

- (void)setupAlertTab {
    NSTabViewItem *alertTab = [[NSTabViewItem alloc] init];
    alertTab.label = @"Alerts";
    
    NSView *alertView = [[NSView alloc] init];
    
    // Alert settings
    self.alertSoundsCheckbox = [self createCheckbox:@"Enable alert sounds"];
    self.alertPopupsCheckbox = [self createCheckbox:@"Enable alert popups"];
    
    NSTextField *soundLabel = [self createLabel:@"Alert Sound:"];
    self.alertSoundPopup = [[NSPopUpButton alloc] init];
    [self.alertSoundPopup addItemsWithTitles:@[@"Glass", @"Ping", @"Pop", @"Purr", @"Sosumi"]];
    
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 15;
    stack.alignment = NSLayoutAttributeLeading;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [stack addArrangedSubview:self.alertSoundsCheckbox];
    [stack addArrangedSubview:self.alertPopupsCheckbox];
    [stack addArrangedSubview:[self createFieldGroup:soundLabel field:self.alertSoundPopup]];
    
    [alertView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:alertView.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:alertView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:alertView.trailingAnchor constant:-20]
    ]];
    
    alertTab.view = alertView;
    [self.tabView addTabViewItem:alertTab];
}

- (void)setupDataSourceTab {
    NSTabViewItem *dataTab = [[NSTabViewItem alloc] init];
    dataTab.label = @"Data Sources";
    
    NSView *dataView = [[NSView alloc] init];
    
    self.enableYahooCheckbox = [self createCheckbox:@"Enable Yahoo Finance"];
    self.enableSchwabCheckbox = [self createCheckbox:@"Enable Schwab"];
    self.enableIBKRCheckbox = [self createCheckbox:@"Enable Interactive Brokers"];
    
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 15;
    stack.alignment = NSLayoutAttributeLeading;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [stack addArrangedSubview:self.enableYahooCheckbox];
    [stack addArrangedSubview:self.enableSchwabCheckbox];
    [stack addArrangedSubview:self.enableIBKRCheckbox];
    
    [dataView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:dataView.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:dataView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:dataView.trailingAnchor constant:-20]
    ]];
    
    dataTab.view = dataView;
    [self.tabView addTabViewItem:dataTab];
}

- (void)setupAppearanceTab {
    NSTabViewItem *appearanceTab = [[NSTabViewItem alloc] init];
    appearanceTab.label = @"Appearance";
    
    NSView *appearanceView = [[NSView alloc] init];
    
    NSTextField *themeLabel = [self createLabel:@"Theme:"];
    self.themePopup = [[NSPopUpButton alloc] init];
    [self.themePopup addItemsWithTitles:@[@"System", @"Light", @"Dark"]];
    
    NSTextField *colorLabel = [self createLabel:@"Accent Color:"];
    self.accentColorWell = [[NSColorWell alloc] init];
    
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 15;
    stack.alignment = NSLayoutAttributeLeading;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [stack addArrangedSubview:[self createFieldGroup:themeLabel field:self.themePopup]];
    [stack addArrangedSubview:[self createFieldGroup:colorLabel field:self.accentColorWell]];
    
    [appearanceView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:appearanceView.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:appearanceView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:appearanceView.trailingAnchor constant:-20]
    ]];
    
    appearanceTab.view = appearanceView;
    [self.tabView addTabViewItem:appearanceTab];
}

#pragma mark - Helper Methods

- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    return label;
}

- (NSTextField *)createNumberField {
    NSTextField *field = [[NSTextField alloc] init];
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimum = @(0.1);
    formatter.maximum = @(60);
    field.formatter = formatter;
    
    return field;
}

- (NSButton *)createCheckbox:(NSString *)title {
    NSButton *checkbox = [[NSButton alloc] init];
    checkbox.buttonType = NSButtonTypeSwitch;
    checkbox.title = title;
    return checkbox;
}

- (NSView *)createFieldGroup:(NSTextField *)label field:(NSView *)field {
    NSStackView *group = [[NSStackView alloc] init];
    group.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    group.spacing = 10;
    group.alignment = NSLayoutAttributeCenterY;
    
    [label setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [field setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    [group addArrangedSubview:label];
    [group addArrangedSubview:field];
    
    return group;
}

#pragma mark - Settings Management

- (void)loadSettings {
    AppSettings *settings = [AppSettings sharedSettings];
    
    // Forza il reload delle impostazioni da NSUserDefaults
    [settings load];
    
    // General
    self.priceUpdateIntervalField.doubleValue = settings.priceUpdateInterval;
    self.alertBackupIntervalField.doubleValue = settings.alertBackupInterval;
    self.autosaveLayoutsCheckbox.state = settings.autosaveLayouts ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Alerts
    self.alertSoundsCheckbox.state = settings.alertSoundsEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.alertPopupsCheckbox.state = settings.alertPopupsEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.alertSoundPopup selectItemWithTitle:settings.alertSoundName ?: @"Glass"];
    
    // Data Sources
    self.enableYahooCheckbox.state = settings.yahooEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.enableSchwabCheckbox.state = settings.schwabEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.enableIBKRCheckbox.state = settings.ibkrEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Appearance
    [self.themePopup selectItemWithTitle:settings.themeName ?: @"System"];
    self.accentColorWell.color = settings.accentColor ?: [NSColor systemBlueColor];
    
    [self loadTrackingSettings];

}

- (void)saveSettings {
    AppSettings *settings = [AppSettings sharedSettings];
    
    NSLog(@"PreferencesWindowController: Saving settings...");
    
    // General Settings
    settings.priceUpdateInterval = self.priceUpdateIntervalField.doubleValue;
    settings.alertBackupInterval = self.alertBackupIntervalField.doubleValue;
    settings.autosaveLayouts = (self.autosaveLayoutsCheckbox.state == NSControlStateValueOn);
    
    NSLog(@"Saving - Price Update Interval: %.2f", settings.priceUpdateInterval);
    NSLog(@"Saving - Alert Backup Interval: %.2f", settings.alertBackupInterval);
    NSLog(@"Saving - Autosave Layouts: %@", settings.autosaveLayouts ? @"YES" : @"NO");
    
    // Alert Settings
    settings.alertSoundsEnabled = (self.alertSoundsCheckbox.state == NSControlStateValueOn);
    settings.alertPopupsEnabled = (self.alertPopupsCheckbox.state == NSControlStateValueOn);
    settings.alertSoundName = self.alertSoundPopup.selectedItem.title;
    
    NSLog(@"Saving - Alert Sounds: %@", settings.alertSoundsEnabled ? @"YES" : @"NO");
    NSLog(@"Saving - Alert Popups: %@", settings.alertPopupsEnabled ? @"YES" : @"NO");
    NSLog(@"Saving - Alert Sound Name: %@", settings.alertSoundName);
    
    // Data Source Settings
    settings.yahooEnabled = (self.enableYahooCheckbox.state == NSControlStateValueOn);
    settings.schwabEnabled = (self.enableSchwabCheckbox.state == NSControlStateValueOn);
    settings.ibkrEnabled = (self.enableIBKRCheckbox.state == NSControlStateValueOn);
    
    NSLog(@"Saving - Yahoo Enabled: %@", settings.yahooEnabled ? @"YES" : @"NO");
    NSLog(@"Saving - Schwab Enabled: %@", settings.schwabEnabled ? @"YES" : @"NO");
    NSLog(@"Saving - IBKR Enabled: %@", settings.ibkrEnabled ? @"YES" : @"NO");
    
    // Appearance Settings
    settings.themeName = self.themePopup.selectedItem.title;
    settings.accentColor = self.accentColorWell.color;
    
    NSLog(@"Saving - Theme: %@", settings.themeName);
    NSLog(@"Saving - Accent Color: %@", settings.accentColor);
    
    // Salva effettivamente le impostazioni
    [settings save];
    
    // Forza la sincronizzazione immediata
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self saveTrackingSettings];

    NSLog(@"PreferencesWindowController: Settings saved and synchronized");
}

- (void)loadTrackingSettings {
    NSLog(@"🔄 Loading tracking settings...");
    
    DataHub *dataHub = [DataHub shared];
    [dataHub loadTrackingConfiguration];
    
    // Update UI with current settings
    self.optimizedTrackingToggle.state = dataHub.optimizedTrackingEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Set slider values (convert seconds to minutes for display)
    self.userDefaultsIntervalSlider.doubleValue = dataHub.userDefaultsBackupInterval / 60.0;
    self.coreDataIntervalSlider.doubleValue = dataHub.coreDataFlushInterval / 60.0;
    
    // Handle app-close-only mode
    self.coreDataAppCloseOnlyToggle.state = (dataHub.coreDataFlushInterval == 0.0) ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Set batch values
    self.maxBatchSizeSlider.doubleValue = dataHub.maxBatchSize;
    self.chunkSizeSlider.doubleValue = dataHub.chunkSize;
    
    // Set lifecycle toggles
    self.flushOnBackgroundToggle.state = dataHub.flushOnAppBackground ? NSControlStateValueOn : NSControlStateValueOff;
    self.flushOnTerminateToggle.state = dataHub.flushOnAppTerminate ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Update preset selection
    TrackingPresetMode currentPreset = [dataHub getCurrentPresetMode];
    if (currentPreset != -1) {
        [self.trackingPresetPopup selectItemAtIndex:currentPreset];
    } else {
        [self.trackingPresetPopup selectItemAtIndex:4]; // Custom
    }
    
    // Update all slider value labels
    [self updateSliderValues];
    
    // Update UI state based on preset
    [self updateTrackingUIForPreset:self.trackingPresetPopup.indexOfSelectedItem];
    
    // Update status display
    [self updateTrackingStatusDisplay];
    
    NSLog(@"✅ Tracking settings loaded successfully");
}

- (void)saveTrackingSettings {
    NSLog(@"💾 Saving tracking settings...");
    
    DataHub *dataHub = [DataHub shared];
    
    // Save all settings to DataHub
    dataHub.optimizedTrackingEnabled = (self.optimizedTrackingToggle.state == NSControlStateValueOn);
    
    // Convert minutes back to seconds for storage
    dataHub.userDefaultsBackupInterval = self.userDefaultsIntervalSlider.doubleValue * 60.0;
    
    // Handle app-close-only mode
    if (self.coreDataAppCloseOnlyToggle.state == NSControlStateValueOn) {
        dataHub.coreDataFlushInterval = 0.0; // App close only
    } else {
        dataHub.coreDataFlushInterval = self.coreDataIntervalSlider.doubleValue * 60.0;
    }
    
    dataHub.maxBatchSize = (NSInteger)self.maxBatchSizeSlider.doubleValue;
    dataHub.chunkSize = (NSInteger)self.chunkSizeSlider.doubleValue;
    
    dataHub.flushOnAppBackground = (self.flushOnBackgroundToggle.state == NSControlStateValueOn);
    dataHub.flushOnAppTerminate = (self.flushOnTerminateToggle.state == NSControlStateValueOn);
    
    // Apply configuration and restart tracking system
    [dataHub applyTrackingConfiguration];
    
    // Update status display
    [self updateTrackingStatusDisplay];
    
    NSLog(@"✅ Tracking settings saved successfully");
}

- (void)updateSliderValues {
    [self updateSliderValueLabel:self.userDefaultsIntervalSlider];
    [self updateSliderValueLabel:self.coreDataIntervalSlider];
    [self updateSliderValueLabel:self.maxBatchSizeSlider];
    [self updateSliderValueLabel:self.chunkSizeSlider];
}

- (void)updateSliderValueLabel:(NSSlider *)slider {
    NSString *format = objc_getAssociatedObject(slider, @"valueFormat");
    NSTextField *valueLabel = objc_getAssociatedObject(slider, @"valueLabel");
    
    if (format && valueLabel) {
        valueLabel.stringValue = [NSString stringWithFormat:format, slider.doubleValue];
    }
}

- (void)updateTrackingUIForPreset:(NSInteger)presetIndex {
    NSString *descriptions[] = {
        @"Maximum responsiveness for tracking changes. Each interaction is saved immediately. May cause UI lag with high activity.",
        @"Recommended balance of performance and data safety. Backup every 10 minutes, save to database every hour.",
        @"Optimized for performance. Less frequent saves reduce UI interruptions but increase potential data loss window.",
        @"Maximum performance mode. Data saved only when app closes. Best performance but highest data loss risk.",
        @"Custom configuration. Adjust individual settings below to match your needs."
    };
    
    if (presetIndex >= 0 && presetIndex < 5) {
        self.presetDescriptionLabel.stringValue = descriptions[presetIndex];
        
        BOOL isCustom = (presetIndex == 4);
        self.userDefaultsIntervalSlider.enabled = isCustom;
        self.coreDataIntervalSlider.enabled = isCustom && (self.coreDataAppCloseOnlyToggle.state == NSControlStateValueOff);
        self.coreDataAppCloseOnlyToggle.enabled = isCustom;
        self.maxBatchSizeSlider.enabled = isCustom;
        self.chunkSizeSlider.enabled = isCustom;
    }
}

- (void)updateTrackingStatusDisplay {
    DataHub *dataHub = [DataHub shared];
    
    NSString *configDescription = [dataHub getTrackingConfigurationDescription];
    self.currentStatusLabel.stringValue = [NSString stringWithFormat:@"Current: %@", configDescription];
    
    NSDictionary *nextOps = [dataHub getNextScheduledOperations];
    NSDate *nextBackup = nextOps[@"nextUserDefaultsBackup"];
    NSDate *nextFlush = nextOps[@"nextCoreDataFlush"];
    
    NSMutableString *nextOpsString = [NSMutableString string];
    if (nextBackup && ![nextBackup isEqual:[NSNull null]]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterNoStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        [nextOpsString appendFormat:@"Next backup: %@", [formatter stringFromDate:nextBackup]];
    }
    
    if (nextFlush && ![nextFlush isEqual:[NSNull null]]) {
        if (nextOpsString.length > 0) [nextOpsString appendString:@" • "];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterNoStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        [nextOpsString appendFormat:@"Next save: %@", [formatter stringFromDate:nextFlush]];
    }
    
    self.nextOperationsLabel.stringValue = nextOpsString.length > 0 ? nextOpsString : @"Times estimated based on current settings";
}


#pragma mark - Public Methods

- (void)showPreferences {
    // Assicurati che le impostazioni siano caricate ogni volta che la finestra viene mostrata
    [self loadSettings];
    
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
#pragma mark - Window Delegate

- (void)windowWillClose:(NSNotification *)notification {
    [self saveSettings];
}


#pragma mark - Action Methods

- (void)applyButtonClicked:(id)sender {
    NSLog(@"Apply button clicked");
    [self saveSettings];
    
    // Mostra un feedback visivo all'utente
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Settings Saved";
    alert.informativeText = @"Your preferences have been saved successfully.";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)okButtonClicked:(id)sender {
    NSLog(@"OK button clicked");
    [self saveSettings];
    [self.window close];
}

- (void)cancelButtonClicked:(id)sender {
    NSLog(@"Cancel button clicked");
    // Ricarica le impostazioni originali
    [self loadSettings];
    [self.window close];
}

// Aggiungi i pulsanti Apply, OK e Cancel se non esistono già
- (void)setupButtons {
    // Crea un contenitore per i pulsanti
    NSView *buttonContainer = [[NSView alloc] init];
    buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:buttonContainer];
    
    // Pulsante Cancel
    NSButton *cancelButton = [[NSButton alloc] init];
    cancelButton.title = @"Cancel";
    cancelButton.bezelStyle = NSBezelStyleRounded;
    cancelButton.target = self;
    cancelButton.action = @selector(cancelButtonClicked:);
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [buttonContainer addSubview:cancelButton];
    
    // Pulsante Apply
    NSButton *applyButton = [[NSButton alloc] init];
    applyButton.title = @"Apply";
    applyButton.bezelStyle = NSBezelStyleRounded;
    applyButton.target = self;
    applyButton.action = @selector(applyButtonClicked:);
    applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [buttonContainer addSubview:applyButton];
    
    // Pulsante OK
    NSButton *okButton = [[NSButton alloc] init];
    okButton.title = @"OK";
    okButton.bezelStyle = NSBezelStyleRounded;
    okButton.target = self;
    okButton.action = @selector(okButtonClicked:);
    okButton.keyEquivalent = @"\r"; // Invio
    okButton.translatesAutoresizingMaskIntoConstraints = NO;
    [buttonContainer addSubview:okButton];
    
    // Layout dei pulsanti
    [NSLayoutConstraint activateConstraints:@[
        // Container position
        [buttonContainer.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-20],
        [buttonContainer.bottomAnchor constraintEqualToAnchor:self.window.contentView.bottomAnchor constant:-20],
        [buttonContainer.heightAnchor constraintEqualToConstant:32],
        
        // Cancel button
        [cancelButton.leadingAnchor constraintEqualToAnchor:buttonContainer.leadingAnchor],
        [cancelButton.centerYAnchor constraintEqualToAnchor:buttonContainer.centerYAnchor],
        [cancelButton.widthAnchor constraintEqualToConstant:80],
        
        // Apply button
        [applyButton.leadingAnchor constraintEqualToAnchor:cancelButton.trailingAnchor constant:10],
        [applyButton.centerYAnchor constraintEqualToAnchor:buttonContainer.centerYAnchor],
        [applyButton.widthAnchor constraintEqualToConstant:80],
        
        // OK button
        [okButton.leadingAnchor constraintEqualToAnchor:applyButton.trailingAnchor constant:10],
        [okButton.centerYAnchor constraintEqualToAnchor:buttonContainer.centerYAnchor],
        [okButton.widthAnchor constraintEqualToConstant:80],
        [okButton.trailingAnchor constraintEqualToAnchor:buttonContainer.trailingAnchor]
    ]];
    
    // Aggiusta la posizione del TabView per fare spazio ai pulsanti
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.bottomAnchor constraintEqualToAnchor:buttonContainer.topAnchor constant:-20]
    ]];
}


// ====== HELPER METHODS ======

- (NSButton *)createResetButton:(NSString *)title action:(SEL)action {
    NSButton *button = [[NSButton alloc] init];
    button.title = title;
    button.bezelStyle = NSBezelStyleRounded;
    button.controlSize = NSControlSizeRegular;
    button.target = self;
    button.action = action;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Warning color
    button.contentTintColor = [NSColor systemOrangeColor];
    
    return button;
}

- (NSButton *)createDangerButton:(NSString *)title action:(SEL)action {
    NSButton *button = [[NSButton alloc] init];
    button.title = title;
    button.bezelStyle = NSBezelStyleRounded;
    button.controlSize = NSControlSizeLarge;
    button.target = self;
    button.action = action;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Danger styling
    button.contentTintColor = [NSColor systemRedColor];
    button.font = [NSFont boldSystemFontOfSize:14];
    
    return button;
}

// ====== AGGIUNGI DEBUG A updateDatabaseStatus ======

- (void)updateDatabaseStatus {
    NSLog(@"🔍 updateDatabaseStatus CALLED");
    
    DataHub *dataHub = [DataHub shared];
    NSLog(@"🔍 DataHub instance: %@", dataHub);
    
    NSUInteger symbolsCount = [dataHub getAllSymbols].count;
    NSUInteger watchlistsCount = [dataHub getAllWatchlists].count;
    NSUInteger alertsCount = [dataHub getAllAlerts].count;
    NSUInteger connectionsCount = 0; // Update quando implementato
    
    NSLog(@"🔍 Counts - Symbols: %lu, Watchlists: %lu, Alerts: %lu, Connections: %lu",
          (unsigned long)symbolsCount, (unsigned long)watchlistsCount,
          (unsigned long)alertsCount, (unsigned long)connectionsCount);
    
    NSString *status = [NSString stringWithFormat:
                       @"Current database status:\n\n"
                       @"• %lu symbols in database\n"
                       @"• %lu watchlists\n"
                       @"• %lu alerts\n"
                       @"• %lu connections\n\n"
                       @"Click individual buttons to reset specific data types, or use the nuclear option to reset everything.",
                       (unsigned long)symbolsCount,
                       (unsigned long)watchlistsCount,
                       (unsigned long)alertsCount,
                       (unsigned long)connectionsCount];
    
    NSLog(@"🔍 Status text: %@", status);
    NSLog(@"🔍 Status label: %@", self.databaseStatusLabel);
    NSLog(@"🔍 Status label frame: %@", NSStringFromRect(self.databaseStatusLabel.frame));
    
    if (self.databaseStatusLabel) {
        self.databaseStatusLabel.stringValue = status;
        NSLog(@"✅ Status updated in label");
        
        // Force redraw
        [self.databaseStatusLabel setNeedsDisplay:YES];
        [self.databaseStatusLabel.superview setNeedsDisplay:YES];
    } else {
        NSLog(@"❌ databaseStatusLabel is nil!");
    }
}


- (void)resetSymbolDatabase:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset Symbol Database?";
    alert.informativeText = @"This will delete all symbols and their usage statistics. Watchlists will be preserved but may reference missing symbols.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Show loading state
        [self setResetButtonsEnabled:NO];
        self.databaseStatusLabel.stringValue = @"Resetting symbol database...";
        
        [[DataHub shared] resetSymbolDatabase:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setResetButtonsEnabled:YES];
                [self updateDatabaseStatus];
                [self showResetCompletedAlert:success ? @"Symbol database reset completed successfully" : @"Symbol database reset failed"];
            });
        }];
    }
}

- (void)resetWatchlists:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset All Watchlists?";
    alert.informativeText = @"This will delete all watchlists and their symbols.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Show loading state
        [self setResetButtonsEnabled:NO];
        self.databaseStatusLabel.stringValue = @"Resetting watchlists...";
        
        [[DataHub shared] resetWatchlistDatabase:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setResetButtonsEnabled:YES];
                [self updateDatabaseStatus];
                [self showResetCompletedAlert:success ? @"All watchlists reset completed successfully" : @"Watchlist reset failed"];
            });
        }];
    }
}

- (void)resetAlerts:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset All Alerts?";
    alert.informativeText = @"This will delete all price alerts and notifications.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Show loading state
        [self setResetButtonsEnabled:NO];
        self.databaseStatusLabel.stringValue = @"Resetting alerts...";
        
        [[DataHub shared] resetAlertDatabase:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setResetButtonsEnabled:YES];
                [self updateDatabaseStatus];
                [self showResetCompletedAlert:success ? @"All alerts reset completed successfully" : @"Alert reset failed"];
            });
        }];
    }
}

- (void)resetConnections:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset All Connections?";
    alert.informativeText = @"This will delete all symbol connections and relationships.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Show loading state
        [self setResetButtonsEnabled:NO];
        self.databaseStatusLabel.stringValue = @"Resetting connections...";
        
        [[DataHub shared] resetConnectionDatabase:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setResetButtonsEnabled:YES];
                [self updateDatabaseStatus];
                [self showResetCompletedAlert:success ? @"All connections reset completed successfully" : @"Connection reset failed"];
            });
        }];
    }
}

- (void)resetAllDatabases:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"🚨 NUCLEAR RESET 🚨";
    alert.informativeText = @"This will delete EVERYTHING:\n\n"
                           @"• All symbols and usage data\n"
                           @"• All watchlists\n"
                           @"• All alerts\n"
                           @"• All connections\n"
                           @"• All app preferences\n\n"
                           @"This action CANNOT be undone!";
    alert.alertStyle = NSAlertStyleCritical;
    [alert addButtonWithTitle:@"🚨 DELETE EVERYTHING"];
    [alert addButtonWithTitle:@"Cancel"];
    
    // Make user type confirmation
    NSTextField *confirmField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    confirmField.placeholderString = @"Type DELETE to confirm";
    alert.accessoryView = confirmField;
    [alert.window setInitialFirstResponder:confirmField];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        if ([confirmField.stringValue isEqualToString:@"DELETE"]) {
            // Show loading state
            [self setResetButtonsEnabled:NO];
            self.databaseStatusLabel.stringValue = @"🚨 NUCLEAR RESET IN PROGRESS... 🚨";
            
            [[DataHub shared] resetAllDatabases:^(BOOL success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Also reset app settings
                    [[AppSettings sharedSettings] resetToDefaults];
                    
                    [self setResetButtonsEnabled:YES];
                    [self updateDatabaseStatus];
                    [self showResetCompletedAlert:success ? @"🚨 NUCLEAR RESET COMPLETED - All data deleted successfully" : @"Nuclear reset completed with some errors - check console"];
                });
            }];
        } else {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Reset Cancelled";
            errorAlert.informativeText = @"You must type 'DELETE' exactly to confirm.";
            [errorAlert runModal];
        }
    }
}

// ====== HELPER METHODS ======

- (void)setResetButtonsEnabled:(BOOL)enabled {
    self.resetSymbolsButton.enabled = enabled;
    self.resetWatchlistsButton.enabled = enabled;
    self.resetAlertsButton.enabled = enabled;
    self.resetConnectionsButton.enabled = enabled;
    self.resetAllDatabasesButton.enabled = enabled;
}

- (void)showResetCompletedAlert:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset Completed";
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}



#pragma mark - Tracking Action Methods

- (void)trackingPresetChanged:(NSPopUpButton *)sender {
    NSInteger selectedIndex = sender.indexOfSelectedItem;
    
    if (selectedIndex < 4) { // Not custom
        DataHub *dataHub = [DataHub shared];
        [dataHub applyTrackingPreset:(TrackingPresetMode)selectedIndex];
        [self loadTrackingSettings]; // Reload UI with new preset values
    }
    
    [self updateTrackingUIForPreset:selectedIndex];
}

- (void)optimizedTrackingToggled:(NSButton *)sender {
    [self saveTrackingSettings];
}

- (void)userDefaultsIntervalChanged:(NSSlider *)sender {
    [self updateSliderValueLabel:sender];
    [self.trackingPresetPopup selectItemAtIndex:4]; // Switch to custom
    [self updateTrackingUIForPreset:4];
    [self saveTrackingSettings];
}

- (void)coreDataIntervalChanged:(NSSlider *)sender {
    [self updateSliderValueLabel:sender];
    [self.trackingPresetPopup selectItemAtIndex:4]; // Switch to custom
    [self updateTrackingUIForPreset:4];
    [self saveTrackingSettings];
}

- (void)coreDataAppCloseOnlyToggled:(NSButton *)sender {
    BOOL appCloseOnly = (sender.state == NSControlStateValueOn);
    self.coreDataIntervalSlider.enabled = !appCloseOnly;
    
    [self.trackingPresetPopup selectItemAtIndex:4]; // Switch to custom
    [self updateTrackingUIForPreset:4];
    [self saveTrackingSettings];
}

- (void)maxBatchSizeChanged:(NSSlider *)sender {
    [self updateSliderValueLabel:sender];
    
    // Ensure chunk size doesn't exceed batch size
    if (self.chunkSizeSlider.doubleValue > sender.doubleValue) {
        self.chunkSizeSlider.doubleValue = sender.doubleValue / 2;
        [self updateSliderValueLabel:self.chunkSizeSlider];
    }
    
    [self.trackingPresetPopup selectItemAtIndex:4]; // Switch to custom
    [self updateTrackingUIForPreset:4];
    [self saveTrackingSettings];
}

- (void)chunkSizeChanged:(NSSlider *)sender {
    [self updateSliderValueLabel:sender];
    [self.trackingPresetPopup selectItemAtIndex:4]; // Switch to custom
    [self updateTrackingUIForPreset:4];
    [self saveTrackingSettings];
}

- (void)flushOnBackgroundToggled:(NSButton *)sender {
    [self saveTrackingSettings];
}

- (void)flushOnTerminateToggled:(NSButton *)sender {
    [self saveTrackingSettings];
}

- (void)forceUserDefaultsBackup:(NSButton *)sender {
    [[DataHub shared] forceUserDefaultsBackup];
    
    sender.title = @"Backed Up!";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        sender.title = @"Backup Now";
    });
}

- (void)forceCoreDataFlush:(NSButton *)sender {
    sender.enabled = NO;
    sender.title = @"Saving...";
    
    [[DataHub shared] forceCoreDataFlushWithCompletion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            sender.enabled = YES;
            sender.title = success ? @"Saved!" : @"Error";
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                sender.title = @"Save to Database";
            });
        });
    }];
}

- (void)resetTrackingToDefaults:(NSButton *)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset Tracking Settings";
    alert.informativeText = @"This will reset all performance tracking settings to recommended defaults. Continue?";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [[DataHub shared] resetTrackingConfigurationToDefaults];
            [self loadTrackingSettings];
        }
    }];
}


@end
