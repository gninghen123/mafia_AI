//
//  ChartPreferencesWindow.m - ENHANCED Implementation
//  TradingApp
//

#import "ChartPreferencesWindow.h"
#import "ChartWidget.h"

@interface ChartPreferencesWindow ()
@property (nonatomic, assign) ChartTradingHours originalTradingHours;

// 🆕 NEW: Store original values for cancel
@property (nonatomic, assign) NSInteger original1MinDays;
@property (nonatomic, assign) NSInteger original5MinDays;
@property (nonatomic, assign) NSInteger originalHourlyDays;
@property (nonatomic, assign) NSInteger originalDailyDays;
@property (nonatomic, assign) NSInteger originalWeeklyDays;
@property (nonatomic, assign) NSInteger originalMonthlyDays;

@property (nonatomic, assign) NSInteger original1MinVisible;
@property (nonatomic, assign) NSInteger original5MinVisible;
@property (nonatomic, assign) NSInteger originalHourlyVisible;
@property (nonatomic, assign) NSInteger originalDailyVisible;
@property (nonatomic, assign) NSInteger originalWeeklyVisible;
@property (nonatomic, assign) NSInteger originalMonthlyVisible;

@end

@implementation ChartPreferencesWindow

#pragma mark - Initialization

- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget {
    // Create larger window to accommodate new controls
    NSRect windowFrame = NSMakeRect(0, 0, 500, 480);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        _chartWidget = chartWidget;
        [self storeOriginalValues];
        [self setupWindow];
        [self createControls];
        [self loadCurrentValues];
    }
    return self;
}

- (void)storeOriginalValues {
    if (!self.chartWidget) return;
    
    // Store trading hours
    _originalTradingHours = self.chartWidget.tradingHoursMode;
    
    // Store download defaults
    _original1MinDays = self.chartWidget.defaultDaysFor1Min;
    _original5MinDays = self.chartWidget.defaultDaysFor5Min;
    _originalHourlyDays = self.chartWidget.defaultDaysForHourly;
    _originalDailyDays = self.chartWidget.defaultDaysForDaily;
    _originalWeeklyDays = self.chartWidget.defaultDaysForWeekly;
    _originalMonthlyDays = self.chartWidget.defaultDaysForMonthly;
    
    // Store visible defaults
    _original1MinVisible = self.chartWidget.defaultVisibleFor1Min;
    _original5MinVisible = self.chartWidget.defaultVisibleFor5Min;
    _originalHourlyVisible = self.chartWidget.defaultVisibleForHourly;
    _originalDailyVisible = self.chartWidget.defaultVisibleForDaily;
    _originalWeeklyVisible = self.chartWidget.defaultVisibleForWeekly;
    _originalMonthlyVisible = self.chartWidget.defaultVisibleForMonthly;
}

#pragma mark - Window Setup

- (void)setupWindow {
    NSWindow *window = self.window;
    window.title = @"Chart Preferences";
    window.level = NSNormalWindowLevel;
    window.backgroundColor = [NSColor controlBackgroundColor];
    
    // Make window non-resizable but allow close
    window.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
    
    NSLog(@"🪟 Enhanced chart preferences window created (500x480)");
}

- (void)createControls {
    NSView *contentView = self.window.contentView;
    
    // Create scroll view for content (since we have many controls now)
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 500, 480)];
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    [contentView addSubview:scrollView];
    
    // Content container view
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 480, 600)];
    scrollView.documentView = containerView;
    
    CGFloat yPos = 550; // Start from top
    
    // ===== SECTION 1: Trading Hours =====
    [self addSectionTitle:@"Trading Hours" toView:containerView atY:&yPos];
    
    self.includeAfterHoursSwitch = [[NSButton alloc] initWithFrame:NSMakeRect(20, yPos, 300, 24)];
    [self.includeAfterHoursSwitch setButtonType:NSButtonTypeSwitch];
    self.includeAfterHoursSwitch.title = @"Include After-Hours Data";
    self.includeAfterHoursSwitch.target = self;
    self.includeAfterHoursSwitch.action = @selector(afterHoursSwitchChanged:);
    [containerView addSubview:self.includeAfterHoursSwitch];
    yPos -= 40;
    
    // ===== SECTION 2: Download Range Defaults =====
    [self addSectionTitle:@"Default Download Range (by Timeframe)" toView:containerView atY:&yPos];
    
    // 1 Minute
    self.defaultDays1MinField = [self createLabelAndField:@"1 Minute:"
                                                   toView:containerView
                                                     atY:&yPos
                                             placeholder:@"20"];
    
    // 5-30 Minutes
    self.defaultDays5MinField = [self createLabelAndField:@"5-30 Minutes:"
                                                   toView:containerView
                                                     atY:&yPos
                                             placeholder:@"40"];
    
    // 1+ Hours
    self.defaultDaysHourlyField = [self createLabelAndField:@"1+ Hours:"
                                                     toView:containerView
                                                       atY:&yPos
                                               placeholder:@"999999"];
    
    // Daily
    self.defaultDaysDailyField = [self createLabelAndField:@"Daily:"
                                                    toView:containerView
                                                      atY:&yPos
                                              placeholder:@"180"];
    
    // Weekly
    self.defaultDaysWeeklyField = [self createLabelAndField:@"Weekly:"
                                                     toView:containerView
                                                       atY:&yPos
                                               placeholder:@"365"];
    
    // Monthly
    self.defaultDaysMonthlyField = [self createLabelAndField:@"Monthly:"
                                                      toView:containerView
                                                        atY:&yPos
                                                placeholder:@"1825"];
    
    yPos -= 20; // Extra spacing
    
    // ===== SECTION 3: Visible Range Defaults =====
    [self addSectionTitle:@"Default Visible Range (by Timeframe)" toView:containerView atY:&yPos];
    
    // 1 Minute
    self.defaultVisible1MinField = [self createLabelAndField:@"1 Minute:"
                                                      toView:containerView
                                                        atY:&yPos
                                                placeholder:@"5"];
    
    // 5-30 Minutes
    self.defaultVisible5MinField = [self createLabelAndField:@"5-30 Minutes:"
                                                      toView:containerView
                                                        atY:&yPos
                                                placeholder:@"10"];
    
    // 1+ Hours
    self.defaultVisibleHourlyField = [self createLabelAndField:@"1+ Hours:"
                                                        toView:containerView
                                                          atY:&yPos
                                                  placeholder:@"30"];
    
    // Daily
    self.defaultVisibleDailyField = [self createLabelAndField:@"Daily:"
                                                       toView:containerView
                                                         atY:&yPos
                                                 placeholder:@"90"];
    
    // Weekly
    self.defaultVisibleWeeklyField = [self createLabelAndField:@"Weekly:"
                                                        toView:containerView
                                                          atY:&yPos
                                                  placeholder:@"180"];
    
    // Monthly
    self.defaultVisibleMonthlyField = [self createLabelAndField:@"Monthly:"
                                                         toView:containerView
                                                           atY:&yPos
                                                   placeholder:@"365"];
    
    yPos -= 30; // Extra spacing before buttons
    
    // ===== BUTTONS =====
    self.resetToDefaultsButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, yPos, 120, 32)];
    [self.resetToDefaultsButton setTitle:@"Reset to Defaults"];
    [self.resetToDefaultsButton setBezelStyle:NSBezelStyleRounded];
    [self.resetToDefaultsButton setTarget:self];
    [self.resetToDefaultsButton setAction:@selector(resetToDefaults:)];
    [containerView addSubview:self.resetToDefaultsButton];
    
    self.saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(280, yPos, 80, 32)];
    [self.saveButton setTitle:@"Save"];
    [self.saveButton setBezelStyle:NSBezelStyleRounded];
    [self.saveButton setKeyEquivalent:@"\r"]; // Enter key
    [self.saveButton setTarget:self];
    [self.saveButton setAction:@selector(savePreferences:)];
    [self.saveButton setEnabled:YES];
    [containerView addSubview:self.saveButton];
    
    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(370, yPos, 80, 32)];
    [self.cancelButton setTitle:@"Cancel"];
    [self.cancelButton setBezelStyle:NSBezelStyleRounded];
    [self.cancelButton setKeyEquivalent:@"\033"]; // Escape key
    [self.cancelButton setTarget:self];
    [self.cancelButton setAction:@selector(cancelPreferences:)];
    [self.cancelButton setEnabled:YES];
    [containerView addSubview:self.cancelButton];
    
    NSLog(@"✅ Enhanced chart preferences controls created");
}

#pragma mark - Helper Methods

- (void)addSectionTitle:(NSString *)title toView:(NSView *)view atY:(CGFloat *)yPos {
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, *yPos, 400, 20)];
    titleLabel.stringValue = title;
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.font = [NSFont boldSystemFontOfSize:14];
    titleLabel.textColor = [NSColor labelColor];
    [view addSubview:titleLabel];
    
    *yPos -= 30;
}

- (NSTextField *)createLabelAndField:(NSString *)labelText
                              toView:(NSView *)view
                                atY:(CGFloat *)yPos
                        placeholder:(NSString *)placeholder {
    
    // Label
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(40, *yPos, 120, 20)];
    label.stringValue = labelText;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:12];
    label.alignment = NSTextAlignmentRight;
    [view addSubview:label];
    
    // Field
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(170, *yPos, 80, 20)];
    field.placeholderString = placeholder;
    field.font = [NSFont systemFontOfSize:12];
    [view addSubview:field];
    
    // Units label
    NSTextField *unitsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(260, *yPos, 40, 20)];
    unitsLabel.stringValue = @"days";
    unitsLabel.editable = NO;
    unitsLabel.bordered = NO;
    unitsLabel.backgroundColor = [NSColor clearColor];
    unitsLabel.font = [NSFont systemFontOfSize:11];
    unitsLabel.textColor = [NSColor secondaryLabelColor];
    [view addSubview:unitsLabel];
    
    *yPos -= 25;
    
    return field;
}

#pragma mark - Data Loading

- (void)loadCurrentValues {
    if (!self.chartWidget) {
        NSLog(@"⚠️ No chart widget reference");
        return;
    }
    
    // Load after-hours setting
    BOOL includeAfterHours = (self.chartWidget.tradingHoursMode == ChartTradingHoursWithAfterHours);
    [self.includeAfterHoursSwitch setState:(includeAfterHours ? NSControlStateValueOn : NSControlStateValueOff)];
    
    // Load download defaults
    self.defaultDays1MinField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultDaysFor1Min];
    self.defaultDays5MinField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultDaysFor5Min];
    self.defaultDaysHourlyField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultDaysForHourly];
    self.defaultDaysDailyField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultDaysForDaily];
    self.defaultDaysWeeklyField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultDaysForWeekly];
    self.defaultDaysMonthlyField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultDaysForMonthly];
    
    // Load visible defaults
    self.defaultVisible1MinField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultVisibleFor1Min];
    self.defaultVisible5MinField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultVisibleFor5Min];
    self.defaultVisibleHourlyField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultVisibleForHourly];
    self.defaultVisibleDailyField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultVisibleForDaily];
    self.defaultVisibleWeeklyField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultVisibleForWeekly];
    self.defaultVisibleMonthlyField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.chartWidget.defaultVisibleForMonthly];
    
    NSLog(@"📊 Loaded enhanced preferences - After-Hours: %@", includeAfterHours ? @"YES" : @"NO");
}

#pragma mark - Actions

- (IBAction)afterHoursSwitchChanged:(id)sender {
    BOOL isOn = (self.includeAfterHoursSwitch.state == NSControlStateValueOn);
    NSLog(@"⏰ After-hours switch changed to: %@", isOn ? @"YES" : @"NO");
}

- (IBAction)resetToDefaults:(id)sender {
    // Reset to hard-coded defaults
    self.defaultDays1MinField.stringValue = @"20";
    self.defaultDays5MinField.stringValue = @"40";
    self.defaultDaysHourlyField.stringValue = @"999999";
    self.defaultDaysDailyField.stringValue = @"180";
    self.defaultDaysWeeklyField.stringValue = @"365";
    self.defaultDaysMonthlyField.stringValue = @"1825";
    
    self.defaultVisible1MinField.stringValue = @"5";
    self.defaultVisible5MinField.stringValue = @"10";
    self.defaultVisibleHourlyField.stringValue = @"30";
    self.defaultVisibleDailyField.stringValue = @"90";
    self.defaultVisibleWeeklyField.stringValue = @"180";
    self.defaultVisibleMonthlyField.stringValue = @"365";
    
    [self.includeAfterHoursSwitch setState:NSControlStateValueOff];
    
    NSLog(@"🔄 Reset all preferences to defaults");
}

- (IBAction)savePreferences:(id)sender {
    if (!self.chartWidget) {
        NSLog(@"❌ No chart widget reference for saving");
        return;
    }
    
    // Save trading hours
    BOOL includeAfterHours = (self.includeAfterHoursSwitch.state == NSControlStateValueOn);
    ChartTradingHours newTradingHours = includeAfterHours ? ChartTradingHoursWithAfterHours : ChartTradingHoursRegularOnly;
    self.chartWidget.tradingHoursMode = newTradingHours;
    
    // Save download defaults
    self.chartWidget.defaultDaysFor1Min = MAX(1, self.defaultDays1MinField.integerValue);
    self.chartWidget.defaultDaysFor5Min = MAX(1, self.defaultDays5MinField.integerValue);
    self.chartWidget.defaultDaysForHourly = MAX(1, self.defaultDaysHourlyField.integerValue);
    self.chartWidget.defaultDaysForDaily = MAX(1, self.defaultDaysDailyField.integerValue);
    self.chartWidget.defaultDaysForWeekly = MAX(1, self.defaultDaysWeeklyField.integerValue);
    self.chartWidget.defaultDaysForMonthly = MAX(1, self.defaultDaysMonthlyField.integerValue);
    
    // Save visible defaults
    self.chartWidget.defaultVisibleFor1Min = MAX(1, self.defaultVisible1MinField.integerValue);
    self.chartWidget.defaultVisibleFor5Min = MAX(1, self.defaultVisible5MinField.integerValue);
    self.chartWidget.defaultVisibleForHourly = MAX(1, self.defaultVisibleHourlyField.integerValue);
    self.chartWidget.defaultVisibleForDaily = MAX(1, self.defaultVisibleDailyField.integerValue);
    self.chartWidget.defaultVisibleForWeekly = MAX(1, self.defaultVisibleWeeklyField.integerValue);
    self.chartWidget.defaultVisibleForMonthly = MAX(1, self.defaultVisibleMonthlyField.integerValue);
    
    // Save to User Defaults
    [self.chartWidget saveDateRangeDefaults];
    [self savePreferencesToUserDefaults:newTradingHours];
    
    // Update the current slider if needed
    [self.chartWidget updateDateRangeSliderForTimeframe:self.chartWidget.currentTimeframe];
    
    // Notify chart widget of changes
    BOOL needsDataReload = (newTradingHours != self.originalTradingHours);
    [self.chartWidget preferencesDidChange:needsDataReload];
    
    NSLog(@"✅ Enhanced chart preferences saved - After-Hours: %@, Download defaults updated, Reload needed: %@",
          includeAfterHours ? @"YES" : @"NO", needsDataReload ? @"YES" : @"NO");
    
    [self closeWindow];
}

- (IBAction)cancelPreferences:(id)sender {
    // Restore original values
    if (self.chartWidget) {
        self.chartWidget.tradingHoursMode = self.originalTradingHours;
        
        // Restore download defaults
        self.chartWidget.defaultDaysFor1Min = self.original1MinDays;
        self.chartWidget.defaultDaysFor5Min = self.original5MinDays;
        self.chartWidget.defaultDaysForHourly = self.originalHourlyDays;
        self.chartWidget.defaultDaysForDaily = self.originalDailyDays;
        self.chartWidget.defaultDaysForWeekly = self.originalWeeklyDays;
        self.chartWidget.defaultDaysForMonthly = self.originalMonthlyDays;
        
        // Restore visible defaults
        self.chartWidget.defaultVisibleFor1Min = self.original1MinVisible;
        self.chartWidget.defaultVisibleFor5Min = self.original5MinVisible;
        self.chartWidget.defaultVisibleForHourly = self.originalHourlyVisible;
        self.chartWidget.defaultVisibleForDaily = self.originalDailyVisible;
        self.chartWidget.defaultVisibleForWeekly = self.originalWeeklyVisible;
        self.chartWidget.defaultVisibleForMonthly = self.originalMonthlyVisible;
    }
    
    NSLog(@"❌ Enhanced chart preferences cancelled - restored original values");
    [self closeWindow];
}

#pragma mark - Window Management

- (void)showPreferencesWindow {
    [self loadCurrentValues];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [self.window makeFirstResponder:self.includeAfterHoursSwitch];
    
    NSLog(@"🪟 Enhanced chart preferences window opened");
}

- (void)closeWindow {
    NSLog(@"🔻 Closing enhanced preferences window");
    [self.window orderOut:self];
    [[NSApplication sharedApplication] stopModal];
}

#pragma mark - User Defaults Management

- (void)savePreferencesToUserDefaults:(ChartTradingHours)tradingHours {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setInteger:tradingHours forKey:@"ChartWidget_TradingHours"];
    [defaults synchronize];
    
    NSLog(@"💾 Saved trading hours preference: %ld", (long)tradingHours);
}

+ (void)loadDefaultPreferencesForChartWidget:(ChartWidget *)chartWidget {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load trading hours
    NSInteger tradingHours = [defaults integerForKey:@"ChartWidget_TradingHours"];
    chartWidget.tradingHoursMode = (ChartTradingHours)tradingHours;
    
    // Load date range defaults (this will call chartWidget's loadDateRangeDefaults)
    [chartWidget loadDateRangeDefaults];
    
    NSLog(@"📂 Loaded enhanced chart preferences from defaults");
}

@end
