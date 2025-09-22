//
//  ChartWidget.h
//  TradingApp
//
//  Chart widget with multiple coordinated panels - XIB VERSION
//

#import "BaseWidget.h"
#import "ObjectsPanel.h"
#import "ChartObjectsManager.h"
#import "ChartObjectRenderer.h"
#import "CommonTypes.h"          // Per BarTimeframe enum
#import "ChartPreferencesWindow.h"
#import "ChartTemplateModels.h"
#import "StorageMetadataCache.h"


@class ChartPanelView;
@class HistoricalBarModel;
@class MarketQuoteModel;
@class SharedXCoordinateContext;  // ✅ Forward declaration invece di import
@class ChartTemplateModel;
@class ChartObjectManagerWindow;

#define CHART_Y_AXIS_WIDTH 60
#define CHART_MARGIN_LEFT 10
#define CHART_MARGIN_RIGHT 10


typedef struct {
    NSString *symbol;
    BarTimeframe timeframe;          // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
    NSInteger daysToDownload;
    BOOL hasTimeframe;
    BOOL hasDaysSpecified;
    NSDate *startDate;
    NSDate *endDate;
} SmartSymbolParameters;

// ❌ REMOVED: BarTimeframe enum - use BarTimeframe from CommonTypes.h

@interface ChartWidget : BaseWidget <NSComboBoxDataSource,NSComboBoxDelegate>

@property (nonatomic, strong) SharedXCoordinateContext *  sharedXContext;

@property (nonatomic, assign) BOOL isStaticMode;

@property (nonatomic, assign) BOOL yRangeCacheValid;
@property (nonatomic, assign) NSInteger cachedStartIndex;
@property (nonatomic, assign) NSInteger cachedEndIndex;


@property (nonatomic, strong) ChartTemplateModel *currentChartTemplate;
@property (nonatomic, strong) NSMutableArray<ChartTemplateModel *> *availableTemplates;

@property (nonatomic, strong, readonly) NSArray<HistoricalBarModel *> *chartData;
#pragma mark - Trading Hours Preferences
@property (nonatomic, assign) ChartTradingHours tradingHoursMode;

#pragma mark - UI Components (Interface Builder - IBOutlet references)
@property (nonatomic, strong) IBOutlet NSComboBox *symbolTextField;
@property (nonatomic, strong) IBOutlet NSSegmentedControl *timeframeSegmented;
@property (nonatomic, strong) IBOutlet NSButton *preferencesButton;
@property (nonatomic, strong) IBOutlet NSSplitView *panelsSplitView;
@property (nonatomic, strong) IBOutlet NSSlider *panSlider;
@property (nonatomic, strong) IBOutlet NSButton *zoomOutButton;
@property (nonatomic, strong) IBOutlet NSButton *zoomInButton;
@property (nonatomic, strong) IBOutlet NSButton *zoomAllButton;
@property (nonatomic, strong) IBOutlet NSSwitch *indicatorsVisibilityToggle;

// Objects UI
@property (nonatomic, strong) IBOutlet NSSegmentedControl *dateRangeSegmented;
@property (nonatomic, strong) IBOutlet NSButton *objectsPanelToggle;
@property (nonatomic, strong) IBOutlet NSButton *objectsVisibilityToggle;
@property (nonatomic, strong) IBOutlet NSButton *staticModeToggle;

// Additional UI components from implementation
@property (nonatomic, strong) IBOutlet NSSplitView *mainSplitView;



@property (nonatomic, strong, nullable) NSArray<StorageMetadataItem *> *currentSearchResults;


// Date Range Control Properties (non-UI)
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

// Objects Panel (programmatic creation, not IBOutlet)
@property (nonatomic, strong) ObjectsPanel *objectsPanel;
@property (nonatomic, strong) ChartObjectsManager *objectsManager;
@property (nonatomic, assign) BOOL isObjectsPanelVisible;

@property (nonatomic, assign) BOOL isSetupCompleted;  // ✅ NUOVO FLAG principale
@property (nonatomic, assign) BOOL isTemplateSystemReady;  // ✅ FLAG per template system


@property (nonatomic, assign) BOOL isUpdatingSlider;
@property (nonatomic, assign) double lastSliderValue;

// Additional properties needed by implementation
@property (nonatomic, strong) ChartPreferencesWindow *preferencesWindowController;
@property (nonatomic, assign) BOOL objectsVisible;
@property (nonatomic, assign) BOOL isIndicatorsPanelVisible;

#pragma mark - Data Properties
@property (nonatomic, strong, readwrite) NSString *currentSymbol;
@property (nonatomic, assign, readwrite) BarTimeframe currentTimeframe;  // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
@property (nonatomic, assign, readwrite) NSInteger initialBarsToShow;

#pragma mark - Chart Panels
@property (nonatomic, strong, readwrite) NSMutableArray<ChartPanelView *> *chartPanels;

#pragma mark - Viewport State (for ChartPanelView access)
@property (nonatomic, assign, readwrite) NSInteger visibleStartIndex;
@property (nonatomic, assign, readwrite) NSInteger visibleEndIndex;

#pragma mark - IBAction Methods (Connected to XIB controls)

// Symbol and Timeframe Actions
- (IBAction)symbolChanged:(NSTextField *)sender;
- (IBAction)timeframeChanged:(NSSegmentedControl *)sender;

// Navigation and Zoom Actions
- (IBAction)panSliderChanged:(NSSlider *)sender;


// Date Range Actions
- (IBAction)dateRangeSegmentedChanged:(NSSegmentedControl *)sender; // Alternative name used in implementation

// Object Panel Actions
- (IBAction)toggleObjectsPanel:(NSButton *)sender;
- (IBAction)toggleObjectsVisibility:(NSButton *)sender;

// Mode Actions
- (IBAction)toggleStaticMode:(NSButton *)sender;
- (IBAction)showPreferences:(NSButton *)sender;

// Additional actions from implementation
- (IBAction)toggleIndicatorsPanel:(NSButton *)sender;

#pragma mark - Internal Methods (Called by IBActions and implementation)

// Data loading methods
- (void)reloadDataForCurrentSymbol;
- (void)loadChartTemplate:(NSString *)templateName;

#pragma mark - Date Range Management Methods
- (void)updateDateRangeSliderForTimeframe:(BarTimeframe)timeframe;  // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
- (void)dateRangeSliderChanged:(id)sender;
- (NSInteger)getMinDaysForTimeframe:(BarTimeframe)timeframe;         // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
- (NSInteger)getMaxDaysForTimeframe:(BarTimeframe)timeframe;         // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
- (NSInteger)getDefaultDaysForTimeframe:(BarTimeframe)timeframe;     // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
- (NSInteger)getDefaultVisibleDaysForTimeframe:(BarTimeframe)timeframe; // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
- (void)updateDateRangeLabel;
- (NSString *)formatDaysToDisplayString:(NSInteger)days;

#pragma mark - Public Methods
- (void)loadSymbol:(NSString *)symbol;
- (void)setTimeframe:(BarTimeframe)timeframe;                        // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
- (void)zoomToRange:(NSInteger)startIndex endIndex:(NSInteger)endIndex;
- (void)synchronizePanels;

// Internal zoom methods (called by IBAction methods)
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)zoomAll:(id)sender;

#pragma mark - Preferences Management
- (void)preferencesDidChange:(BOOL)needsDataReload;

#pragma mark - Trading Hours Calculation (Public for ChartObjectRenderer)
- (NSInteger)barsPerDayForCurrentTimeframe;
- (NSInteger)getCurrentTimeframeInMinutes;

- (void)updateWithHistoricalBars:(NSArray<HistoricalBarModel *> *)bars;

- (void)setStaticMode:(BOOL)staticMode;
- (void)updateStaticModeUI;

#pragma mark - Chart Data Access (for SaveData extension)

/// Get current chart data (accessor for private chartData property)
/// @return Array of current historical bars, or nil if no data loaded
- (NSArray<HistoricalBarModel *> * _Nullable)currentChartData;

-(void)resetToInitialView;
- (void)loadDateRangeDefaults;
- (void)saveDateRangeDefaults;

- (void)setupDateRangeSegmentedControl;
- (void)updateDateRangeSegmentedForTimeframe:(BarTimeframe)timeframe; // ✅ UNIFIED: Cambiato da BarTimeframe a BarTimeframe
- (void)updateCustomSegmentWithDays:(NSInteger)days;
- (NSString *)formatDaysToAbbreviation:(NSInteger)days;
- (NSInteger)getDaysForSegment:(NSInteger)segment;
- (void)loadDateRangeSegmentedDefaults;
- (void)saveDateRangeSegmentedDefaults;
- (NSInteger)barTimeframeToSegmentIndex:(BarTimeframe)timeframe;
- (void)processSmartSymbolInput:(NSString *)input;
- (void)showTemporaryMessage:(NSString *)message;


- (void)saveLastUsedTemplate:(ChartTemplateModel *)template;

/**
 * Reset visible range for current timeframe using preferences
 */
- (void)resetVisibleRangeForTimeframe;

/**
 * Refresh alerts for current symbol
 */
- (void)refreshAlertsForCurrentSymbol;

/**
 * Load data with current settings (symbol, timeframe, date range)
 */
- (void)loadDataWithCurrentSettings;

/**
 * Update viewport and synchronize panels
 */
- (void)updateViewport;

/**
 * Broadcast symbol change to widget chain
 */
- (void)broadcastSymbolToChain:(NSString *)symbol;
- (void)resetVisibleRangeForTimeframe;
- (void)refreshAlertsForCurrentSymbol;
- (void)loadDataWithCurrentSettings;
- (void)updateViewport;
- (void)broadcastSymbolToChain:(NSString *)symbol;



- (void)updateSymbolWithoutDataLoad:(NSString *)newSymbol;
- (void)updateTimeframeWithoutDataLoad:(BarTimeframe)newTimeframe;
- (void)updateDataRangeWithoutDataLoad:(NSInteger)newDays;

// ✅ Conditional methods (check if exist before calling)
- (void)recalculateAllIndicators;
- (void)refreshIndicatorsRendering;
- (void)applyChartTemplate:(ChartTemplateModel *)template;

@end
