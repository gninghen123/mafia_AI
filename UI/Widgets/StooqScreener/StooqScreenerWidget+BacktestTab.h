//
//  StooqScreenerWidget+BacktestTab.h
//  TradingApp
//
//  Category for Backtest Tab UI setup and management
//

#import "StooqScreenerWidget.h"
#import "BacktestRunner.h"
#import "BacktestModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface StooqScreenerWidget (BacktestTab) <BacktestRunnerDelegate>

#pragma mark - Tab Setup

/**
 * Setup the backtest tab UI
 * Called from setupUI in main implementation
 */
- (void)setupBacktestTab;

#pragma mark - Backtest Tab Components (declare as properties in main interface if needed)

// Top bar
@property (nonatomic, strong) NSTextField *benchmarkSymbolField;
@property (nonatomic, strong) NSButton *validateSymbolButton;
@property (nonatomic, strong) NSTextField *symbolValidationLabel;

// Left side - Top (Models list)
@property (nonatomic, strong) NSTableView *backtestModelsTableView;
@property (nonatomic, strong) NSScrollView *backtestModelsScrollView;
@property (nonatomic, strong) NSTextField *backtestModelsHeaderLabel;

// Right side - Top (Candlestick Chart)
@property (nonatomic, strong) NSView *candlestickChartContainer;
@property (nonatomic, strong) NSTextField *dateRangeLabel;
@property (nonatomic, strong) NSButton *zoomInButton;
@property (nonatomic, strong) NSButton *zoomOutButton;
@property (nonatomic, strong) NSButton *zoomAllButton;

// Left side - Bottom (Statistics Metrics)
@property (nonatomic, strong) NSTableView *statisticsMetricsTableView;
@property (nonatomic, strong) NSScrollView *statisticsMetricsScrollView;
@property (nonatomic, strong) NSTextField *statisticsHeaderLabel;

// Right side - Bottom (Comparison Chart)
@property (nonatomic, strong) NSView *comparisonChartContainer;
@property (nonatomic, strong) NSTextField *comparisonChartTitleLabel;

// Control bar
@property (nonatomic, strong) NSDatePicker *backtestStartDatePicker;
@property (nonatomic, strong) NSDatePicker *backtestEndDatePicker;
@property (nonatomic, strong) NSButton *runBacktestButton;
@property (nonatomic, strong) NSButton *cancelBacktestButton;
@property (nonatomic, strong) NSProgressIndicator *backtestProgressIndicator;
@property (nonatomic, strong) NSTextField *backtestStatusLabel;

// Split views for layout
@property (nonatomic, strong) NSSplitView *backtestMainSplitView;      // Left | Right
@property (nonatomic, strong) NSSplitView *backtestLeftSplitView;      // Models | Stats
@property (nonatomic, strong) NSSplitView *backtestRightSplitView;     // Candlestick | Comparison

#pragma mark - Backtest Data

@property (nonatomic, strong, nullable) BacktestRunner *backtestRunner;
@property (nonatomic, strong, nullable) BacktestSession *currentBacktestSession;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *backtestMasterCache;
@property (nonatomic, strong, nullable) NSArray<NSString *> *availableStatisticsMetrics;
@property (nonatomic, strong, nullable) NSString *selectedStatisticMetric;

#pragma mark - Actions

- (IBAction)validateBenchmarkSymbol:(id)sender;
- (IBAction)backtestModelCheckboxChanged:(id)sender;
- (IBAction)statisticsMetricSelected:(id)sender;
- (IBAction)runBacktest:(id)sender;
- (IBAction)cancelBacktest:(id)sender;
- (IBAction)zoomInChart:(id)sender;
- (IBAction)zoomOutChart:(id)sender;
- (IBAction)zoomAllChart:(id)sender;

#pragma mark - Helper Methods

/**
 * Reload backtest models table (shows models from main tab)
 */
- (void)reloadBacktestModelsTable;

/**
 * Load and validate benchmark symbol data
 */
- (void)loadBenchmarkSymbolData:(NSString *)symbol;

/**
 * Update UI state based on backtest running status
 */
- (void)updateBacktestUIState:(BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END
