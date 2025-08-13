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
    
    // Trading Hours Section
    NSTextField *tradingHoursLabel = [self createLabel:@"Trading Hours:" frame:NSMakeRect(20, 220, 120, 20)];
    [contentView addSubview:tradingHoursLabel];
    
    self.tradingHoursPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 218, 220, 24)];
    [self.tradingHoursPopup addItemsWithTitles:@[
        @"Regular Hours Only (09:30-16:00)",
        @"Pre-Market + Regular (04:00-16:00)",
        @"Regular + After Hours (09:30-20:00)",
        @"Extended Hours (04:00-20:00)"
    ]];
    self.tradingHoursPopup.target = self;
    self.tradingHoursPopup.action = @selector(tradingHoursChanged:);
    [contentView addSubview:self.tradingHoursPopup];
    
    // Bars to Download Section
    NSTextField *barsDownloadLabel = [self createLabel:@"Bars to Download:" frame:NSMakeRect(20, 180, 120, 20)];
    [contentView addSubview:barsDownloadLabel];
    
    self.barsToDownloadField = [[NSTextField alloc] initWithFrame:NSMakeRect(150, 178, 100, 24)];
    self.barsToDownloadField.placeholderString = @"1000";
    [contentView addSubview:self.barsToDownloadField];
    
    NSTextField *barsDownloadHint = [self createLabel:@"(More bars = longer history)"
                                                frame:NSMakeRect(260, 180, 120, 20)];
    barsDownloadHint.font = [NSFont systemFontOfSize:11];
    barsDownloadHint.textColor = [NSColor secondaryLabelColor];
    [contentView addSubview:barsDownloadHint];
    
    // Initial Bars to Show Section
    NSTextField *initialBarsLabel = [self createLabel:@"Initial Bars Visible:" frame:NSMakeRect(20, 140, 120, 20)];
    [contentView addSubview:initialBarsLabel];
    
    self.initialBarsToShowField = [[NSTextField alloc] initWithFrame:NSMakeRect(150, 138, 100, 24)];
    self.initialBarsToShowField.placeholderString = @"100";
    [contentView addSubview:self.initialBarsToShowField];
    
    NSTextField *initialBarsHint = [self createLabel:@"(Default zoom level)"
                                               frame:NSMakeRect(260, 140, 120, 20)];
    initialBarsHint.font = [NSFont systemFontOfSize:11];
    initialBarsHint.textColor = [NSColor secondaryLabelColor];
    [contentView addSubview:initialBarsHint];
    
    // Info Section
    NSTextField *infoLabel = [self createLabel:@"Trading Hours Info:" frame:NSMakeRect(20, 100, 120, 20)];
    infoLabel.font = [NSFont boldSystemFontOfSize:12];
    [contentView addSubview:infoLabel];
    
    NSTextField *infoText = [self createLabel:@"• Regular: 09:30-16:00 (6.5 hours)\n• Pre-Market: 04:00-09:30 (5.5 hours)\n• After-Hours: 16:00-20:00 (4 hours)\n• Extended: All sessions (16 hours total)"
                                        frame:NSMakeRect(150, 60, 220, 60)];
    infoText.font = [NSFont systemFontOfSize:10];
    infoText.textColor = [NSColor secondaryLabelColor];
    [contentView addSubview:infoText];
    
    // Buttons
    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(210, 20, 80, 24)];
    self.cancelButton.title = @"Cancel";
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelPreferences:);
    [contentView addSubview:self.cancelButton];
    
    self.saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(300, 20, 80, 24)];
    self.saveButton.title = @"Save";
    self.saveButton.bezelStyle = NSBezelStyleRounded;
    self.saveButton.keyEquivalent = @"\r"; // Enter key
    self.saveButton.target = self;
    self.saveButton.action = @selector(savePreferences:);
    [contentView addSubview:self.saveButton];
}

- (NSTextField *)createLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.bordered = NO;
    label.editable = NO;
    label.backgroundColor = [NSColor clearColor];
    return label;
}

#pragma mark - Data Management

- (void)loadCurrentValues {
    // Load trading hours
    [self.tradingHoursPopup selectItemAtIndex:self.chartWidget.tradingHoursMode];
    
    // Load bars settings
    self.barsToDownloadField.integerValue = self.chartWidget.barsToDownload;
    self.initialBarsToShowField.integerValue = self.chartWidget.initialBarsToShow;
}

#pragma mark - Actions

- (IBAction)tradingHoursChanged:(id)sender {
    // Update info text based on selection
    NSInteger selectedIndex = self.tradingHoursPopup.indexOfSelectedItem;
    NSLog(@"📊 Trading hours changed to index: %ld", (long)selectedIndex);
}

- (IBAction)savePreferences:(id)sender {
    // Validate inputs
    NSInteger barsToDownload = self.barsToDownloadField.integerValue;
    NSInteger initialBarsToShow = self.initialBarsToShowField.integerValue;
    
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
    ChartTradingHours newTradingHours = (ChartTradingHours)self.tradingHoursPopup.indexOfSelectedItem;
    
    BOOL needsDataReload = (newTradingHours != self.originalTradingHours ||
                           barsToDownload != self.originalBarsToDownload);
    
    self.chartWidget.tradingHoursMode = newTradingHours;
    self.chartWidget.barsToDownload = barsToDownload;
    self.chartWidget.initialBarsToShow = initialBarsToShow;
    
    // Notify chart widget of changes
    [self.chartWidget preferencesDidChange:needsDataReload];
    
    NSLog(@"✅ Chart preferences saved - Trading Hours: %ld, Bars: %ld/%ld",
          (long)newTradingHours, (long)barsToDownload, (long)initialBarsToShow);
    
    [self closeWindow];
}

- (IBAction)cancelPreferences:(id)sender {
    NSLog(@"❌ Chart preferences cancelled");
    [self closeWindow];
}

#pragma mark - Window Management

- (void)showPreferencesWindow {
    [self loadCurrentValues];
    [self.window makeKeyAndOrderFront:nil];
    NSLog(@"🪟 Chart preferences window opened");
}

- (void)closeWindow {
    [self.window close];
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

@end
