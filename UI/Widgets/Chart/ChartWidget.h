//
//  ChartWidget.h
//  TradingApp
//
//  Chart widget with XIB-based UI architecture
//  CLEANED: Contains only methods actually implemented in .m file
//

#import "BaseWidget.h"
#import "HistoricalBarModel.h"
#import "ChartPanelView.h"
#import "ChartObjectsManager.h"
#import "SharedXCoordinateContext.h"

@class ObjectsPanel;
@class ChartPreferencesWindow;

NS_ASSUME_NONNULL_BEGIN

// Enums
typedef NS_ENUM(NSInteger, ChartTimeframe) {
    ChartTimeframe1Min = 0,
    ChartTimeframe5Min = 1,
    ChartTimeframe15Min = 2,
    ChartTimeframe30Min = 3,
    ChartTimeframe1Hour = 4,
    ChartTimeframe4Hour = 5,
    ChartTimeframeDaily = 6,
    ChartTimeframeWeekly = 7,
    ChartTimeframeMonthly = 8
};

typedef struct {
    NSString *symbol;
    ChartTimeframe timeframe;
    NSInteger daysToDownload;
    NSDate *startDate;
    NSDate *endDate;
    BOOL hasTimeframe;
    BOOL hasDaysSpecified;
} SmartSymbolParameters;

@interface ChartWidget : BaseWidget

#pragma mark - XIB Outlets
@property (weak) IBOutlet NSTextField *symbolTextField;
@property (weak) IBOutlet NSSegmentedControl *timeframeSegmented;
@property (weak) IBOutlet NSSegmentedControl *dateRangeSegmented;
@property (weak) IBOutlet NSPopUpButton *templatePopup;
@property (weak) IBOutlet NSSplitView *panelsSplitView;
@property (weak) IBOutlet NSButton *objectsVisibilityToggle;
@property (weak) IBOutlet NSButton *staticModeToggle;
@property (weak) IBOutlet NSButton *objectsPanelToggle;
@property (weak) IBOutlet NSButton *indicatorsPanelToggle;

#pragma mark - Chart Data Properties
@property (nonatomic, strong, readonly) NSArray<HistoricalBarModel *> *chartData;
@property (nonatomic, strong, readwrite) NSString *currentSymbol;
@property (nonatomic, assign, readwrite) ChartTimeframe currentTimeframe;
@property (nonatomic, assign, readwrite) NSInteger initialBarsToShow;

#pragma mark - Chart Panels
@property (nonatomic, strong, readwrite) NSMutableArray<ChartPanelView *> *chartPanels;
@property (nonatomic, strong) SharedXCoordinateContext *sharedXContext;

#pragma mark - Viewport State
@property (nonatomic, assign, readwrite) NSInteger visibleStartIndex;
@property (nonatomic, assign, readwrite) NSInteger visibleEndIndex;

#pragma mark - Date Range Management
@property (nonatomic, assign) NSInteger currentDateRangeDays;
@property (nonatomic, assign) NSInteger selectedDateRangeSegment;
@property (nonatomic, assign) NSInteger customDateRangeDays;
@property (nonatomic, strong) NSString *customSegmentTitle;

// Download defaults per timeframe
@property (nonatomic, assign) NSInteger defaultDaysFor1Min;
@property (nonatomic, assign) NSInteger defaultDaysFor5Min;
@property (nonatomic, assign) NSInteger defaultDaysForHourly;
@property (nonatomic, assign) NSInteger defaultDaysForDaily;
@property (nonatomic, assign) NSInteger defaultDaysForWeekly;
@property (nonatomic, assign) NSInteger defaultDaysForMonthly;

// Visible defaults per timeframe
@property (nonatomic, assign) NSInteger defaultVisibleFor1Min;
@property (nonatomic, assign) NSInteger defaultVisibleFor5Min;
@property (nonatomic, assign) NSInteger defaultVisibleForHourly;
@property (nonatomic, assign) NSInteger defaultVisibleForDaily;
@property (nonatomic, assign) NSInteger defaultVisibleForWeekly;
@property (nonatomic, assign) NSInteger defaultVisibleForMonthly;

#pragma mark - Objects and UI Panels
@property (nonatomic, strong) ObjectsPanel *objectsPanel;
@property (nonatomic, strong) ChartObjectsManager *objectsManager;
@property (nonatomic, assign) BOOL isObjectsPanelVisible;
@property (nonatomic, assign) BOOL isIndicatorsPanelVisible;

#pragma mark - State Flags
@property (nonatomic, assign) BOOL isSetupCompleted;
@property (nonatomic, assign) BOOL isTemplateSystemReady;
@property (nonatomic, assign) BOOL isStaticMode;
@property (nonatomic, assign) BOOL objectsVisible;
@property (nonatomic, assign) BOOL isUpdatingSlider;
@property (nonatomic, assign) double lastSliderValue;

#pragma mark - Additional Properties
@property (nonatomic, strong) ChartPreferencesWindow *preferencesWindowController;

#pragma mark - Initialization
- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType;

#pragma mark - XIB Actions - Symbol and Timeframe
- (IBAction)symbolFieldChanged:(NSTextField *)sender;
- (IBAction)symbolChanged:(NSTextField *)sender;
- (IBAction)timeframeChanged:(NSSegmentedControl *)sender;


#pragma mark - XIB Actions - Date Range and Controls
- (IBAction)dateRangeSegmentedChanged:(NSSegmentedControl *)sender;
- (IBAction)toggleObjectsVisibility:(NSButton *)sender;
- (IBAction)toggleObjectsPanel:(NSButton *)sender;
- (IBAction)toggleIndicatorsPanel:(NSButton *)sender;

#pragma mark - XIB Actions - Zoom
- (IBAction)zoomOut:(NSButton *)sender;
- (IBAction)zoomIn:(NSButton *)sender;

#pragma mark - Data Loading
- (void)loadSymbol:(NSString *)symbol;
- (void)loadDataWithCurrentSettings;
- (void)updateWithHistoricalBars:(NSArray<HistoricalBarModel *> *)bars;

#pragma mark - Setup Methods
- (void)setupChartDefaults;
- (void)setupTimeframeSegmentedControl;
- (void)setupDateRangeSegmentedControl;
- (void)setupPlaceholderView;
- (void)setupFrameChangeNotifications;
- (void)setupObjectsAndIndicatorsUI;
- (void)loadAndApplyLastUsedTemplate;

#pragma mark - Preferences Management
- (void)loadInitialPreferences;
- (void)loadDateRangeDefaults;
- (void)loadDateRangeSegmentedDefaults;
- (void)saveDateRangeSegmentedDefaults;
- (void)updateDateRangeSegmentedForTimeframe:(ChartTimeframe)timeframe;

#pragma mark - Date Range Helpers
- (NSInteger)getDaysForSegment:(NSInteger)segment;
- (NSInteger)getDefaultDaysForTimeframe:(ChartTimeframe)timeframe;
- (NSInteger)getDefaultVisibleDaysForTimeframe:(ChartTimeframe)timeframe;
- (NSInteger)convertDaysToBarsForTimeframe:(NSInteger)days timeframe:(ChartTimeframe)timeframe;

#pragma mark - Visible Range Management
- (void)resetVisibleRangeForTimeframe;
- (void)updateVisibleRange;
- (void)setVisibleStartIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex;

#pragma mark - Panel Management
- (void)updatePanelsWithData:(NSArray<HistoricalBarModel *> *)data;
- (void)synchronizePanels;
- (void)clearExistingPanels;
- (void)setupPanelsFromTemplateSystem;
- (void)setInitialDividerPosition;

#pragma mark - Coordinate Context
- (void)updateSharedXContext;

#pragma mark - Data Notifications
- (void)registerForDataNotifications;
- (void)dataLoaded:(NSNotification *)notification;

#pragma mark - Smart Symbol Input
- (void)processSmartSymbolInput:(NSString *)inputText;
- (void)applySmartSymbolParameters:(SmartSymbolParameters)params;
- (void)updateUIAfterSmartSymbolInput:(SmartSymbolParameters)params;

#pragma mark - Symbol Coordination
- (void)setCurrentSymbol:(NSString *)currentSymbol;
- (void)refreshAlertsForCurrentSymbol;
- (void)broadcastSymbolToChain:(NSString *)symbol;

#pragma mark - Chain Handling
- (void)handleChainAction:(NSString *)action withData:(id)data fromWidget:(BaseWidget *)sender;
- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender;
- (void)loadChartPatternFromChainData:(NSDictionary *)data fromWidget:(BaseWidget *)sender;

#pragma mark - UI Feedback
- (void)showChainFeedback:(NSString *)message;
- (void)showMicroscopeModeNotification;

#pragma mark - View Lifecycle
- (void)viewDidLayout;
- (void)viewWillLayout;
- (void)viewDidAppear;
- (void)chartViewFrameDidChange:(NSNotification *)notification;
- (void)splitViewFrameDidChange:(NSNotification *)notification;

#pragma mark - Helper Methods
- (NSString *)timeframeDisplayName:(ChartTimeframe)timeframe;
- (NSString *)timeframeDisplayStringForTimeframe:(ChartTimeframe)timeframe;
- (ChartPanelView *)findMainChartPanel;
- (BOOL)areObjectsVisible;
- (void)setObjectsVisible:(BOOL)visible;

@end

NS_ASSUME_NONNULL_END
