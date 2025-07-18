//
//  PreferencesWindowController.m
//  TradingApp
//

#import "PreferencesWindowController.h"
#import "AppSettings.h"

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
    NSRect frame = NSMakeRect(0, 0, 600, 500);
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
@end
