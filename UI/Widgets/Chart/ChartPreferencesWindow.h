//
//  ChartPreferencesWindow.h
//  TradingApp
//
//  Chart widget preferences window
//

#import <Cocoa/Cocoa.h>

@class ChartWidget;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ChartTradingHours) {
    ChartTradingHoursRegularOnly = 0,    // Regular hours only (09:30-16:00)
    ChartTradingHoursWithAfterHours = 1  // Include after-hours data
};

@interface ChartPreferencesWindow : NSWindowController

// UI Controls - CHANGED: Removed IBOutlet, made strong for programmatic creation
@property (nonatomic, strong) NSButton *includeAfterHoursSwitch;  // Changed from popup to switch
@property (nonatomic, strong) NSTextField *barsToDownloadField;
@property (nonatomic, strong) NSTextField *initialBarsToShowField;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *cancelButton;

// Reference to chart widget
@property (nonatomic, weak) ChartWidget *chartWidget;

// Initialization
- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget;

// Actions
- (IBAction)savePreferences:(id)sender;
- (IBAction)cancelPreferences:(id)sender;
- (IBAction)afterHoursSwitchChanged:(id)sender;  // Changed from tradingHoursChanged

// Window management
- (void)showPreferencesWindow;

// User Defaults management
+ (void)loadDefaultPreferencesForChartWidget:(ChartWidget *)chartWidget;

@end

NS_ASSUME_NONNULL_END
