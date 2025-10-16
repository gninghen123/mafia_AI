//
//  StooqScreenerWidget.h
//  TradingApp
//
//  Widget for running screener models on Stooq database
//

#import "BaseWidget.h"
#import "BacktestRunner.h"

NS_ASSUME_NONNULL_BEGIN

@interface StooqScreenerWidget : BaseWidget

#pragma mark - Configuration
// StooqScreenerWidget.h - @interface
@property (nonatomic, strong) NSDatePicker *targetDatePicker;
/// Path to Stooq data directory
@property (nonatomic, strong, nullable) NSString *dataDirectory;

/// Selected exchanges to screen (e.g., @[@"nasdaq", @"nyse"])
@property (nonatomic, strong) NSArray<NSString *> *selectedExchanges;
@property (nonatomic, strong) NSView *archiveStatsPanel;
@property (nonatomic, strong) NSTextField *statsAllLabel;
@property (nonatomic, strong) NSTextField *statsSelectedLabel;

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




@property (nonatomic, strong) NSView *backtestView;

#pragma mark - Backtest Data

@property (nonatomic, strong, nullable) BacktestRunner *backtestRunner;
@property (nonatomic, strong, nullable) BacktestSession *currentBacktestSession;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *backtestMasterCache;
@property (nonatomic, strong, nullable) NSArray<NSString *> *availableStatisticsMetrics;
@property (nonatomic, strong, nullable) NSString *selectedStatisticMetric;
#pragma mark - Public Methods

/// Set data directory and initialize data manager
/// @param path Path to Stooq data directory
- (void)setDataDirectory:(NSString *)path;

/// Refresh models list from disk
- (void)refreshModels;

/// Run selected models on universe
- (void)runSelectedModels;

/// Cancel current batch execution
- (void)cancelExecution;

@end

NS_ASSUME_NONNULL_END
