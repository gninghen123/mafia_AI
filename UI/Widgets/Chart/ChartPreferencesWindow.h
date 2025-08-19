//
//  ChartPreferencesWindow.h - ENHANCED for Date Range Defaults
//  TradingApp
//

#import <Cocoa/Cocoa.h>

@class ChartWidget;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ChartTradingHours) {
    ChartTradingHoursRegularOnly = 0,    // Regular hours only (09:30-16:00)
    ChartTradingHoursWithAfterHours = 1  // Include after-hours data
};

@interface ChartPreferencesWindow : NSWindowController

// 🆕 NEW: Enhanced UI Controls for Date Range Defaults
@property (nonatomic, strong) NSButton *includeAfterHoursSwitch;

// 🆕 NEW: Download Range Defaults (grouped by timeframe)
@property (nonatomic, strong) NSTextField *defaultDays1MinField;
@property (nonatomic, strong) NSTextField *defaultDays5MinField;
@property (nonatomic, strong) NSTextField *defaultDaysHourlyField;
@property (nonatomic, strong) NSTextField *defaultDaysDailyField;
@property (nonatomic, strong) NSTextField *defaultDaysWeeklyField;
@property (nonatomic, strong) NSTextField *defaultDaysMonthlyField;

// 🆕 NEW: Visible Range Defaults (grouped by timeframe)
@property (nonatomic, strong) NSTextField *defaultVisible1MinField;
@property (nonatomic, strong) NSTextField *defaultVisible5MinField;
@property (nonatomic, strong) NSTextField *defaultVisibleHourlyField;
@property (nonatomic, strong) NSTextField *defaultVisibleDailyField;
@property (nonatomic, strong) NSTextField *defaultVisibleWeeklyField;
@property (nonatomic, strong) NSTextField *defaultVisibleMonthlyField;

// Buttons
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *cancelButton;
@property (nonatomic, strong) NSButton *resetToDefaultsButton;

// Reference to chart widget
@property (nonatomic, weak) ChartWidget *chartWidget;

// Initialization
- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget;

// Actions
- (IBAction)savePreferences:(id)sender;
- (IBAction)cancelPreferences:(id)sender;
- (IBAction)resetToDefaults:(id)sender;
- (IBAction)afterHoursSwitchChanged:(id)sender;

// Window management
- (void)showPreferencesWindow;

// User Defaults management
+ (void)loadDefaultPreferencesForChartWidget:(ChartWidget *)chartWidget;

@end

NS_ASSUME_NONNULL_END
