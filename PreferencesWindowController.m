//
//  PreferencesWindowController.m
//  TradingApp
//

#import "PreferencesWindowController.h"
#import "AppSettings.h"
#import "datahub.h"
#import "connectionmodel.h"


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
        [self.tabView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [self.tabView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [self.tabView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [self.tabView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-50]
    ]];
    
    // Add tabs
    [self setupGeneralTab];
    [self setupAlertTab];
    [self setupDataSourceTab];
    [self setupAppearanceTab];
    [self setupButtons];
    [self setupDatabaseTab]; // ← AGGIUNGI QUESTA RIGA

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
    
    NSLog(@"PreferencesWindowController: Settings saved and synchronized");
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

// ====== RESET ACTION METHODS ======

- (void)resetSymbolDatabase:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset Symbol Database?";
    alert.informativeText = @"This will delete all symbols and their usage statistics. Watchlists will be preserved but may reference missing symbols.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        DataHub *dataHub = [DataHub shared];
        
        // Delete all symbols
        NSArray *allSymbols = [dataHub getAllSymbols];
        for (Symbol *symbol in allSymbols) {
            [dataHub deleteSymbol:symbol];
        }
        
        [self updateDatabaseStatus];
        [self showResetCompletedAlert:@"Symbol database reset completed"];
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
        DataHub *dataHub = [DataHub shared];
        
        // Delete all watchlists
        NSArray *allWatchlists = [dataHub getAllWatchlists];
        for (Watchlist *watchlist in [allWatchlists copy]) {
            [dataHub deleteWatchlist:watchlist];
        }
        
        [self updateDatabaseStatus];
        [self showResetCompletedAlert:@"All watchlists reset completed"];
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
        DataHub *dataHub = [DataHub shared];
        
        // Delete all alerts
        NSArray *allAlerts = [dataHub getAllAlerts];
        for (Alert *alert in [allAlerts copy]) {
            [dataHub deleteAlert:alert];
        }
        
        [self updateDatabaseStatus];
        [self showResetCompletedAlert:@"All alerts reset completed"];
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
        DataHub *dataHub = [DataHub shared];
        
        // Delete all connections
        NSArray *allConnections = [dataHub getAllConnections];
        for (ConnectionModel *connection in allConnections) {
            [dataHub deleteConnection:connection];
        }
        
        [self updateDatabaseStatus];
        [self showResetCompletedAlert:@"All connections reset completed"];
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
            // Reset everything
            [self resetSymbolDatabase:nil];
            [self resetWatchlists:nil];
            [self resetAlerts:nil];
            [self resetConnections:nil];
            
            // Reset app settings
            [[AppSettings sharedSettings] resetToDefaults];
            
            [self updateDatabaseStatus];
            [self showResetCompletedAlert:@"🚨 NUCLEAR RESET COMPLETED - All data deleted"];
        } else {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Reset Cancelled";
            errorAlert.informativeText = @"You must type 'DELETE' exactly to confirm.";
            [errorAlert runModal];
        }
    }
}

- (void)showResetCompletedAlert:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset Completed";
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}


@end
