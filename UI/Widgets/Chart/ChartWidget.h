//
//  ChartWidget.h
//  TradingApp
//
//  Chart widget with multiple coordinated panels
//

#import "BaseWidget.h"
#import "ObjectsPanel.h"
#import "ChartObjectsManager.h"
#import "ChartObjectRenderer.h"
#import "CommonTypes.h"          // Per BarTimeframe enum
#import "ChartPreferencesWindow.h"


@class ChartPanelView;
@class HistoricalBarModel;       
@class MarketQuoteModel;
@class SharedXCoordinateContext;  // ✅ Forward declaration invece di import

#define CHART_Y_AXIS_WIDTH 60
#define CHART_MARGIN_LEFT 10
#define CHART_MARGIN_RIGHT 10

typedef NS_ENUM(NSInteger, ChartTimeframe) {
    ChartTimeframe1Min,
    ChartTimeframe5Min,
    ChartTimeframe15Min,
    ChartTimeframe30Min,
    ChartTimeframe1Hour,
    ChartTimeframe4Hour,
    ChartTimeframeDaily,
    ChartTimeframeWeekly,
    ChartTimeframeMonthly
};

@interface ChartWidget : BaseWidget

@property (nonatomic, strong) SharedXCoordinateContext *  sharedXContext;

@property (nonatomic, assign) BOOL isStaticMode;
@property (nonatomic, assign) BOOL renderersInitialized;

@property (nonatomic, assign) BOOL yRangeCacheValid;
@property (nonatomic, assign) NSInteger cachedStartIndex;
@property (nonatomic, assign) NSInteger cachedEndIndex;


#pragma mark - Trading Hours Preferences
@property (nonatomic, assign) ChartTradingHours tradingHoursMode;


#pragma mark - UI Components (Programmatic - STRONG references)
@property (nonatomic, strong) NSTextField *symbolTextField;
@property (nonatomic, strong) NSSegmentedControl *timeframeSegmented;
@property (nonatomic, strong) NSPopUpButton *templatePopup;
@property (nonatomic, strong) NSButton *preferencesButton;
@property (nonatomic, strong) NSSplitView *panelsSplitView;
@property (nonatomic, strong) NSSlider *panSlider;
@property (nonatomic, strong) NSButton *zoomOutButton;
@property (nonatomic, strong) NSButton *zoomInButton;
@property (nonatomic, strong) NSButton *zoomAllButton;
// Objects UI
@property (nonatomic, strong) NSSegmentedControl *dateRangeSegmented;

@property (nonatomic, assign) NSInteger currentDateRangeDays;
@property (nonatomic, assign) NSInteger selectedDateRangeSegment; // 0=CUSTOM, 1=1M, 2=3M...

// Custom segment persistence
@property (nonatomic, assign) NSInteger customDateRangeDays;     // Ultimo valore custom inserito
@property (nonatomic, strong) NSString *customSegmentTitle;

// 🆕 NEW: Default preferences for each timeframe group
@property (nonatomic, assign) NSInteger defaultDaysFor1Min;        // 20
@property (nonatomic, assign) NSInteger defaultDaysFor5Min;        // 40
@property (nonatomic, assign) NSInteger defaultDaysForHourly;      // max available
@property (nonatomic, assign) NSInteger defaultDaysForDaily;       // 180 (6 months)
@property (nonatomic, assign) NSInteger defaultDaysForWeekly;      // 365 (1 year)
@property (nonatomic, assign) NSInteger defaultDaysForMonthly;     // 1825 (5 years)

// 🆕 NEW: Default visible bars for each timeframe group
@property (nonatomic, assign) NSInteger defaultVisibleFor1Min;     // days to show initially
@property (nonatomic, assign) NSInteger defaultVisibleFor5Min;
@property (nonatomic, assign) NSInteger defaultVisibleForHourly;
@property (nonatomic, assign) NSInteger defaultVisibleForDaily;
@property (nonatomic, assign) NSInteger defaultVisibleForWeekly;
@property (nonatomic, assign) NSInteger defaultVisibleForMonthly;
@property (nonatomic, strong) NSButton *objectsPanelToggle;
@property (nonatomic, strong) ObjectsPanel *objectsPanel;
@property (nonatomic, strong) ChartObjectsManager *objectsManager;
@property (nonatomic, assign) BOOL isObjectsPanelVisible;
@property (nonatomic, strong) NSButton *objectsVisibilityToggle;

@property (nonatomic, strong) NSButton *staticModeToggle;

#pragma mark - Data Properties
@property (nonatomic, strong, readwrite) NSString *currentSymbol;
@property (nonatomic, assign, readwrite) ChartTimeframe currentTimeframe;
@property (nonatomic, assign, readwrite) NSInteger barsToDownload;
@property (nonatomic, assign, readwrite) NSInteger initialBarsToShow;

#pragma mark - Chart Panels
@property (nonatomic, strong, readwrite) NSMutableArray<ChartPanelView *> *chartPanels;

#pragma mark - Viewport State (for ChartPanelView access)
@property (nonatomic, assign, readwrite) NSInteger visibleStartIndex;
@property (nonatomic, assign, readwrite) NSInteger visibleEndIndex;




// 🆕 NEW: Methods for date range management
- (void)updateDateRangeSliderForTimeframe:(ChartTimeframe)timeframe;
- (void)dateRangeSliderChanged:(id)sender;
- (NSInteger)getMinDaysForTimeframe:(ChartTimeframe)timeframe;
- (NSInteger)getMaxDaysForTimeframe:(ChartTimeframe)timeframe;
- (NSInteger)getDefaultDaysForTimeframe:(ChartTimeframe)timeframe;
- (NSInteger)getDefaultVisibleDaysForTimeframe:(ChartTimeframe)timeframe;
- (void)updateDateRangeLabel;
- (NSString *)formatDaysToDisplayString:(NSInteger)days;

#pragma mark - Public Methods
- (void)loadSymbol:(NSString *)symbol;
- (void)setTimeframe:(ChartTimeframe)timeframe;
- (void)zoomToRange:(NSInteger)startIndex endIndex:(NSInteger)endIndex;
- (void)synchronizePanels;

// Zoom methods for panels
- (void)zoomIn:(id)sender;
- (void)zoomOut:(id)sender;
- (void)zoomAll:(id)sender;

#pragma mark - Preferences Management
- (void)preferencesDidChange:(BOOL)needsDataReload;

#pragma mark - Trading Hours Calculation (Public for ChartObjectRenderer)
- (NSInteger)barsPerDayForCurrentTimeframe;
- (NSInteger)getCurrentTimeframeInMinutes;

- (void)updateWithHistoricalBars:(NSArray<HistoricalBarModel *> *)bars;


- (void)setStaticMode:(BOOL)staticMode;
- (void)toggleStaticMode:(id)sender;
- (void)updateStaticModeUI;

#pragma mark - Chart Data Access (for SaveData extension)

/// Get current chart data (accessor for private chartData property)
/// @return Array of current historical bars, or nil if no data loaded
- (NSArray<HistoricalBarModel *> * _Nullable)currentChartData;

-(void)resetToInitialView;
- (void)loadDateRangeDefaults;
- (void)saveDateRangeDefaults;


- (void)setupDateRangeSegmentedControl;
- (void)dateRangeSegmentChanged:(id)sender;
- (void)updateDateRangeSegmentedForTimeframe:(ChartTimeframe)timeframe;
- (void)updateCustomSegmentWithDays:(NSInteger)days;
- (NSString *)formatDaysToAbbreviation:(NSInteger)days;
- (NSInteger)getDaysForSegment:(NSInteger)segment;
- (void)loadDateRangeSegmentedDefaults;
- (void)saveDateRangeSegmentedDefaults;

@end
