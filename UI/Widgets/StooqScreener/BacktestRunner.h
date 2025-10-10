//
//  BacktestRunner.h
//  TradingApp
//
//  Engine for running backtest simulations
//  Executes models across date ranges using pre-loaded data
//

#import <Cocoa/Cocoa.h>
#import "BacktestModels.h"
#import "ScreenerModel.h"

NS_ASSUME_NONNULL_BEGIN

@class BacktestRunner;

#pragma mark - Backtest Runner Delegate

@protocol BacktestRunnerDelegate <NSObject>
@optional

/// Called when backtest execution starts
- (void)backtestRunnerDidStart:(BacktestRunner *)runner;

/// Called when data loading/preparation starts
- (void)backtestRunner:(BacktestRunner *)runner
    didStartPreparationWithMessage:(NSString *)message;

/// Called when backtest execution begins (after preparation)
- (void)backtestRunner:(BacktestRunner *)runner
    didStartExecutionForDays:(NSInteger)dayCount
                      models:(NSInteger)modelCount;

/// Called when processing a specific date
- (void)backtestRunner:(BacktestRunner *)runner
       didStartDate:(NSDate *)date
          dayNumber:(NSInteger)dayNumber
          totalDays:(NSInteger)totalDays;

/// Called when a model completes on a specific date
- (void)backtestRunner:(BacktestRunner *)runner
    didCompleteModel:(NSString *)modelName
              onDate:(NSDate *)date
         symbolCount:(NSInteger)symbolCount;

/// Called periodically with progress updates (0.0 - 1.0)
- (void)backtestRunner:(BacktestRunner *)runner
      didUpdateProgress:(double)progress;

/// Called when backtest completes successfully
- (void)backtestRunner:(BacktestRunner *)runner
    didFinishWithSession:(BacktestSession *)session;

/// Called if backtest fails
- (void)backtestRunner:(BacktestRunner *)runner
        didFailWithError:(NSError *)error;

/// Called if backtest is cancelled
- (void)backtestRunnerDidCancel:(BacktestRunner *)runner;

@end

#pragma mark - Backtest Runner

@interface BacktestRunner : NSObject

#pragma mark - Properties

/// Delegate for progress callbacks
@property (nonatomic, weak, nullable) id<BacktestRunnerDelegate> delegate;

/// Whether backtest is currently running
@property (nonatomic, readonly) BOOL isRunning;

/// Current progress (0.0 - 1.0)
@property (nonatomic, readonly) double progress;

#pragma mark - Initialization

- (instancetype)init;

#pragma mark - Execution

/**
 * Run backtest using pre-loaded master cache
 *
 * @param models Models to test (must have at least 1 model)
 * @param startDate Backtest start date
 * @param endDate Backtest end date (must be >= startDate)
 * @param masterCache Pre-loaded extended data cache
 * @param benchmarkSymbol Symbol for benchmark chart (e.g., "SPY")
 *
 * @discussion
 * This method assumes masterCache contains data from (startDate - maxBars) to endDate.
 * It will:
 * 1. Generate all trading dates in range
 * 2. For each date, slice the cache to that date
 * 3. Execute all models with the sliced cache
 * 4. Collect results into a BacktestSession
 * 5. Call delegate with completion or error
 *
 * Execution happens on background queue. All delegate callbacks are on main queue.
 */
- (void)runBacktestForModels:(NSArray<ScreenerModel *> *)models
                   startDate:(NSDate *)startDate
                     endDate:(NSDate *)endDate
                 masterCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache
              benchmarkSymbol:(NSString *)benchmarkSymbol;

/**
 * Cancel running backtest
 * Will call backtestRunnerDidCancel: delegate method
 */
- (void)cancel;

#pragma mark - Utilities

/**
 * Calculate maximum bars required by a set of models
 * @param models Models to analyze
 * @return Maximum minBarsRequired across all screeners in all models
 */
+ (NSInteger)calculateMaxBarsForModels:(NSArray<ScreenerModel *> *)models;

/**
 * Generate trading dates between start and end (excluding weekends)
 * @param startDate Start date
 * @param endDate End date
 * @return Array of NSDate objects (weekdays only)
 */
+ (NSArray<NSDate *> *)generateTradingDatesFrom:(NSDate *)startDate
                                         toDate:(NSDate *)endDate;

/**
 * Assign random colors to models for visualization
 * @param models Models to assign colors to
 * @return Dictionary mapping modelID → NSColor
 */
+ (NSDictionary<NSString *, NSColor *> *)assignRandomColorsToModels:(NSArray<ScreenerModel *> *)models;

@end

NS_ASSUME_NONNULL_END
