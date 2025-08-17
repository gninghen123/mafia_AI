//
//  ChartPreferencesWindow.m
//  TradingApp
//
//  Chart widget preferences window implementation
//

#import "ChartPreferencesWindow.h"
#import "ChartWidget.h"

@interface ChartPreferencesWindow ()
@property (nonatomic, assign) ChartTradingHours originalTradingHours;
@property (nonatomic, assign) NSInteger originalBarsToDownload;
@property (nonatomic, assign) NSInteger originalInitialBarsToShow;
@end

@implementation ChartPreferencesWindow

#pragma mark - Initialization

- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget {
    // Create window programmatically
    NSRect windowFrame = NSMakeRect(0, 0, 400, 280);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        _chartWidget = chartWidget;
        
        // Store original values for cancel
        _originalTradingHours = chartWidget.tradingHoursMode;
        _originalBarsToDownload = chartWidget.barsToDownload;
        _originalInitialBarsToShow = chartWidget.initialBarsToShow;
        [self setupWindow];
        [self createControls];
        [self loadCurrentValues];
    }
    return self;
}

#pragma mark - Window Setup

- (void)setupWindow {
    NSWindow *window = self.window;
    window.title = @"Chart Preferences";
    window.level = NSFloatingWindowLevel;
    window.hidesOnDeactivate = YES;
    
    // Center on screen
    [window center];
}

- (void)createControls {
    NSView *contentView = self.window.contentView;
    
    // Include After-Hours Section
    NSTextField *afterHoursLabel = [self createLabel:@"Include After-Hours:" frame:NSMakeRect(20, 220, 140, 20)];
    [contentView addSubview:afterHoursLabel];
    
    self.includeAfterHoursSwitch = [[NSButton alloc] initWithFrame:NSMakeRect(170, 218, 200, 24)];
    [self.includeAfterHoursSwitch setButtonType:NSButtonTypeSwitch];
    [self.includeAfterHoursSwitch setTitle:@"Include extended hours data"];
    [self.includeAfterHoursSwitch setTarget:self];
    [self.includeAfterHoursSwitch setAction:@selector(afterHoursSwitchChanged:)];
    [self.includeAfterHoursSwitch setEnabled:YES];
    [contentView addSubview:self.includeAfterHoursSwitch];
    
    // Bars to Download Section
    NSTextField *barsToDownloadLabel = [self createLabel:@"Bars to Download:" frame:NSMakeRect(20, 180, 120, 20)];
    [contentView addSubview:barsToDownloadLabel];
    
    self.barsToDownloadField = [[NSTextField alloc] initWithFrame:NSMakeRect(150, 178, 100, 24)];
    self.barsToDownloadField.placeholderString = @"50-10000";
    [self.barsToDownloadField setEnabled:YES];
    
    // ✅ FIX: Rimuovi formatter automatico e imposta formatter personalizzato
    [self configureNumericTextField:self.barsToDownloadField];
    
    [contentView addSubview:self.barsToDownloadField];
    
    NSTextField *barsToDownloadInfo = [self createLabel:@"(More bars = longer history)" frame:NSMakeRect(260, 180, 120, 20)];
    barsToDownloadInfo.textColor = [NSColor secondaryLabelColor];
    barsToDownloadInfo.font = [NSFont systemFontOfSize:11];
    [contentView addSubview:barsToDownloadInfo];
    
    // Initial Bars Visible Section
    NSTextField *initialBarsLabel = [self createLabel:@"Initial Bars Visible:" frame:NSMakeRect(20, 140, 120, 20)];
    [contentView addSubview:initialBarsLabel];
    
    self.initialBarsToShowField = [[NSTextField alloc] initWithFrame:NSMakeRect(150, 138, 100, 24)];
    self.initialBarsToShowField.placeholderString = @"10-500";
    [self.initialBarsToShowField setEnabled:YES];
    
    // ✅ FIX: Rimuovi formatter automatico e imposta formatter personalizzato
    [self configureNumericTextField:self.initialBarsToShowField];
    
    [contentView addSubview:self.initialBarsToShowField];
    
    NSTextField *initialBarsInfo = [self createLabel:@"(Default zoom level)" frame:NSMakeRect(260, 140, 120, 20)];
    initialBarsInfo.textColor = [NSColor secondaryLabelColor];
    initialBarsInfo.font = [NSFont systemFontOfSize:11];
    [contentView addSubview:initialBarsInfo];
    
    // Separator Line
    NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(20, 100, 360, 1)];
    separator.boxType = NSBoxSeparator;
    [contentView addSubview:separator];
    
    // Buttons
    self.saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(280, 40, 80, 32)];
    [self.saveButton setTitle:@"Save"];
    [self.saveButton setBezelStyle:NSBezelStyleRounded];
    [self.saveButton setKeyEquivalent:@"\r"]; // Enter key
    [self.saveButton setTarget:self];
    [self.saveButton setAction:@selector(savePreferences:)];
    [self.saveButton setEnabled:YES];
    [contentView addSubview:self.saveButton];
    
    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(190, 40, 80, 32)];
    [self.cancelButton setTitle:@"Cancel"];
    [self.cancelButton setBezelStyle:NSBezelStyleRounded];
    [self.cancelButton setKeyEquivalent:@"\033"]; // Escape key
    [self.cancelButton setTarget:self];
    [self.cancelButton setAction:@selector(cancelPreferences:)];
    [self.cancelButton setEnabled:YES];
    [contentView addSubview:self.cancelButton];
    
    NSLog(@"✅ Chart preferences controls created");
}

#pragma mark - Helper Methods

- (NSTextField *)createLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:13];
    return label;
}

#pragma mark - Data Loading

- (void)loadCurrentValues {
    if (!self.chartWidget) {
        NSLog(@"⚠️ No chart widget reference");
        return;
    }
    
    // ✅ LOAD FROM USER DEFAULTS FIRST
    [ChartPreferencesWindow loadDefaultPreferencesForChartWidget:self.chartWidget];
    
    // Load after-hours setting
    BOOL includeAfterHours = (self.chartWidget.tradingHoursMode == ChartTradingHoursWithAfterHours);
    [self.includeAfterHoursSwitch setState:(includeAfterHours ? NSControlStateValueOn : NSControlStateValueOff)];
    
    // ✅ FIX: Usa stringValue per evitare formattazione automatica
    self.barsToDownloadField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.barsToDownload];
    self.initialBarsToShowField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.initialBarsToShow];
    
    NSLog(@"📊 Loaded preferences - After-Hours: %@, Bars: %ld/%ld",
          includeAfterHours ? @"YES" : @"NO",
          (long)self.chartWidget.barsToDownload,
          (long)self.chartWidget.initialBarsToShow);
}

#pragma mark - Actions

- (IBAction)afterHoursSwitchChanged:(id)sender {
    BOOL isOn = (self.includeAfterHoursSwitch.state == NSControlStateValueOn);
    NSLog(@"⏰ After-hours switch changed to: %@", isOn ? @"ON" : @"OFF");
}

- (IBAction)savePreferences:(id)sender {
    // ✅ FIX: Usa stringValue e converti manualmente per evitare problemi di parsing
    NSString *barsToDownloadString = [self.barsToDownloadField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *initialBarsToShowString = [self.initialBarsToShowField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Rimuovi eventuali spazi o caratteri non numerici
    barsToDownloadString = [[barsToDownloadString componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
    initialBarsToShowString = [[initialBarsToShowString componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    NSInteger barsToDownload = [barsToDownloadString integerValue];
    NSInteger initialBarsToShow = [initialBarsToShowString integerValue];
    
    NSLog(@"📊 Parsing preferences - Raw strings: '%@' -> %ld, '%@' -> %ld",
          barsToDownloadString, (long)barsToDownload,
          initialBarsToShowString, (long)initialBarsToShow);
    
    // Validate inputs
    if (barsToDownload < 50) {
        [self showAlert:@"Bars to download must be at least 50"];
        return;
    }
    
    if (initialBarsToShow < 10) {
        [self showAlert:@"Initial bars to show must be at least 10"];
        return;
    }
    
    if (initialBarsToShow > barsToDownload) {
        [self showAlert:@"Initial bars to show cannot exceed bars to download"];
        return;
    }
    
    // Apply changes to chart widget
    BOOL includeAfterHours = (self.includeAfterHoursSwitch.state == NSControlStateValueOn);
    ChartTradingHours newTradingHours = includeAfterHours ? ChartTradingHoursWithAfterHours : ChartTradingHoursRegularOnly;
    
    BOOL needsDataReload = (newTradingHours != self.originalTradingHours ||
                           barsToDownload != self.originalBarsToDownload);
    
    self.chartWidget.tradingHoursMode = newTradingHours;
    self.chartWidget.barsToDownload = barsToDownload;
    self.chartWidget.initialBarsToShow = initialBarsToShow;
    
    // ✅ SAVE TO USER DEFAULTS
    [self savePreferencesToUserDefaults:newTradingHours
                         barsToDownload:barsToDownload
                     initialBarsToShow:initialBarsToShow];
    
    // Notify chart widget of changes
    [self.chartWidget preferencesDidChange:needsDataReload];
    
    NSLog(@"✅ Chart preferences saved - After-Hours: %@, Bars: %ld/%ld, Reload needed: %@",
          includeAfterHours ? @"YES" : @"NO", (long)barsToDownload, (long)initialBarsToShow, needsDataReload ? @"YES" : @"NO");
    
    [self closeWindow];
}

- (IBAction)cancelPreferences:(id)sender {
    NSLog(@"❌ Chart preferences cancelled");
    [self closeWindow];
}

#pragma mark - Window Management

- (void)showPreferencesWindow {
    [self loadCurrentValues];
    [self.window center];  // Center before showing
    [self.window makeKeyAndOrderFront:nil];
    
    // Make window key and focused
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [self.window makeFirstResponder:self.includeAfterHoursSwitch];
    
    NSLog(@"🪟 Chart preferences window opened");
}

- (void)closeWindow {
    NSLog(@"🔻 Closing preferences window");
    [self.window orderOut:self];
    [[NSApplication sharedApplication] stopModal];
}

#pragma mark - User Defaults Management

+ (void)loadDefaultPreferencesForChartWidget:(ChartWidget *)chartWidget {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load with default values if not set
    NSInteger tradingHours = [defaults integerForKey:@"ChartWidget_TradingHours"];
    NSInteger barsToDownload = [defaults integerForKey:@"ChartWidget_BarsToDownload"];
    NSInteger initialBarsToShow = [defaults integerForKey:@"ChartWidget_InitialBarsToShow"];
    
    // Apply defaults if values are invalid or not set
    if (barsToDownload < 50) barsToDownload = 500;           // Default: 500 bars
    if (initialBarsToShow < 10) initialBarsToShow = 100;     // Default: 100 bars visible
    if (initialBarsToShow > barsToDownload) initialBarsToShow = barsToDownload / 2;
    
    // Apply to chart widget
    chartWidget.tradingHoursMode = (ChartTradingHours)tradingHours;
    chartWidget.barsToDownload = barsToDownload;
    chartWidget.initialBarsToShow = initialBarsToShow;
    
    NSLog(@"📂 Loaded chart preferences from defaults - After-Hours: %@, Bars: %ld/%ld",
          (tradingHours == ChartTradingHoursWithAfterHours) ? @"YES" : @"NO",
          (long)barsToDownload, (long)initialBarsToShow);
}

- (void)savePreferencesToUserDefaults:(ChartTradingHours)tradingHours
                       barsToDownload:(NSInteger)barsToDownload
                   initialBarsToShow:(NSInteger)initialBarsToShow {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setInteger:(NSInteger)tradingHours forKey:@"ChartWidget_TradingHours"];
    [defaults setInteger:barsToDownload forKey:@"ChartWidget_BarsToDownload"];
    [defaults setInteger:initialBarsToShow forKey:@"ChartWidget_InitialBarsToShow"];
    
    // Force synchronization
    [defaults synchronize];
    
    NSLog(@"💾 Saved chart preferences to defaults - After-Hours: %@, Bars: %ld/%ld",
          (tradingHours == ChartTradingHoursWithAfterHours) ? @"YES" : @"NO",
          (long)barsToDownload, (long)initialBarsToShow);
}

#pragma mark - Helpers

- (void)showAlert:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Invalid Input";
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}
#pragma mark - Helper Methods - NUOVO METODO

// ✅ NUOVO: Configura TextField per numeri senza formatting automatico
- (void)configureNumericTextField:(NSTextField *)textField {
    // Rimuovi qualsiasi formatter esistente
    textField.formatter = nil;
    
    // Crea un formatter personalizzato che accetta solo numeri interi
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterNoStyle; // Nessuna formattazione
    numberFormatter.allowsFloats = NO; // Solo numeri interi
    numberFormatter.minimum = @(0); // Non permettere numeri negativi
    numberFormatter.maximum = @(999999); // Limite massimo ragionevole
    numberFormatter.usesGroupingSeparator = NO; // ✅ IMPORTANTE: No separatori migliaia
    
    // Applica il formatter
    textField.formatter = numberFormatter;
    
    NSLog(@"🔧 Configured numeric text field without grouping separator");
}

@end
