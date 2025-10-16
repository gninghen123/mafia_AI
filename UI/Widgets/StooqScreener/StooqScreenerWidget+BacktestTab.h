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
