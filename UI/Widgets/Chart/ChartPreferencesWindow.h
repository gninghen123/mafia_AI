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
    ChartTradingHoursRegularOnly = 0,    // 09:30-16:00 (6.5h)
    ChartTradingHoursWithPreMarket,      // 04:00-16:00 (12h)
    ChartTradingHoursWithAfterHours,     // 09:30-20:00 (10.5h)
    ChartTradingHoursExtended            // 04:00-20:00 (16h)
};

@interface ChartPreferencesWindow : NSWindowController

// UI Controls
@property (nonatomic, weak) IBOutlet NSPopUpButton *tradingHoursPopup;
@property (nonatomic, weak) IBOutlet NSTextField *barsToDownloadField;
@property (nonatomic, weak) IBOutlet NSTextField *initialBarsToShowField;
@property (nonatomic, weak) IBOutlet NSButton *saveButton;
@property (nonatomic, weak) IBOutlet NSButton *cancelButton;

// Reference to chart widget
@property (nonatomic, weak) ChartWidget *chartWidget;

// Initialization
- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget;

// Actions
- (IBAction)savePreferences:(id)sender;
- (IBAction)cancelPreferences:(id)sender;
- (IBAction)tradingHoursChanged:(id)sender;

// Window management
- (void)showPreferencesWindow;

@end

NS_ASSUME_NONNULL_END
