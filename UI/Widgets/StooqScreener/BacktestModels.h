//
//  BacktestModels.h
//  TradingApp
//
//  Data models for backtest results
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"
#import "ScreenerModel.h"
#import "ScreenedSymbol.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Daily Backtest Result

/**
 * Represents the result of running ONE model on ONE specific date
 */
@interface DailyBacktestResult : NSObject

#pragma mark - Core Properties

/// Date this result represents
@property (nonatomic, strong) NSDate *date;

/// Model that was executed
@property (nonatomic, strong) NSString *modelName;

/// Model ID for reference
@property (nonatomic, strong) NSString *modelID;

/// Symbols that passed the screening
@property (nonatomic, strong) NSArray<ScreenedSymbol *> *screenedSymbols;

#pragma mark - Basic Statistics

/// Number of symbols screened
@property (nonatomic, assign) NSInteger symbolCount;

/// Execution time for this model on this date (seconds)
@property (nonatomic, assign) NSTimeInterval executionTime;

#pragma mark - Performance Statistics (Optional - calculated later)

/// Win rate percentage (0-100)
@property (nonatomic, assign) CGFloat winRate;

/// Average gain percentage
@property (nonatomic, assign) CGFloat avgGain;

/// Average loss percentage
@property (nonatomic, assign) CGFloat avgLoss;

/// Total number of trades (if tracking exits)
@property (nonatomic, assign) NSInteger tradeCount;

/// Win/Loss ratio
@property (nonatomic, assign) CGFloat winLossRatio;

#pragma mark - Metadata

/// Any additional metadata (for future extension)
@property (nonatomic, strong, nullable) NSDictionary *metadata;

#pragma mark - Convenience Initializers

+ (instancetype)resultWithDate:(NSDate *)date
                     modelName:(NSString *)modelName
                       modelID:(NSString *)modelID
               screenedSymbols:(NSArray<ScreenedSymbol *> *)symbols;

@end

#pragma mark - Backtest Session

/**
 * Represents a complete backtest session with results for multiple models over a date range
 */
@interface BacktestSession : NSObject <NSCoding, NSSecureCoding>

#pragma mark - Session Identity

/// Unique session ID
@property (nonatomic, strong) NSString *sessionID;

/// When this session was created
@property (nonatomic, strong) NSDate *createdAt;

#pragma mark - Date Range

/// Backtest start date (user-selected)
@property (nonatomic, strong) NSDate *startDate;

/// Backtest end date (user-selected)
@property (nonatomic, strong) NSDate *endDate;

#pragma mark - Benchmark Data

/// Symbol used for benchmark (e.g., "SPY")
@property (nonatomic, strong) NSString *benchmarkSymbol;

/// Historical bars for benchmark in backtest range
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *benchmarkBars;

#pragma mark - Models & Results

/// Models that were tested
@property (nonatomic, strong) NSArray<ScreenerModel *> *models;

/// All daily results (organized chronologically)
/// Array of DailyBacktestResult objects
@property (nonatomic, strong) NSArray<DailyBacktestResult *> *dailyResults;

#pragma mark - Model Colors (UI State - Not Persisted)

/// Dictionary mapping modelID → NSColor for chart display
/// Assigned randomly at session creation, not persisted
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSColor *> *modelColors;

#pragma mark - Statistics

/// Total number of trading days in backtest
@property (nonatomic, readonly) NSInteger tradingDaysCount;

/// Total execution time for entire backtest
@property (nonatomic, assign) NSTimeInterval totalExecutionTime;

#pragma mark - Convenience Methods

/**
 * Get all results for a specific model
 * @param modelID Model ID to filter by
 * @return Array of DailyBacktestResult for that model
 */
- (NSArray<DailyBacktestResult *> *)resultsForModelID:(NSString *)modelID;

/**
 * Get all results for a specific date
 * @param date Date to filter by
 * @return Array of DailyBacktestResult for that date (one per model)
 */
- (NSArray<DailyBacktestResult *> *)resultsForDate:(NSDate *)date;

/**
 * Get all unique dates in chronological order
 * @return Sorted array of NSDate objects
 */
- (NSArray<NSDate *> *)allDates;

/**
 * Get benchmark bar for specific date
 * @param date Date to find
 * @return HistoricalBarModel or nil if not found
 */
- (nullable HistoricalBarModel *)benchmarkBarForDate:(NSDate *)date;

#pragma mark - Persistence

/**
 * Save session to disk
 * @param path Full path to save location
 * @param error Error if save fails
 * @return YES if successful
 */
- (BOOL)saveToPath:(NSString *)path error:(NSError **)error;

/**
 * Load session from disk
 * @param path Full path to session file
 * @param error Error if load fails
 * @return Loaded session or nil
 */
+ (nullable instancetype)loadFromPath:(NSString *)path error:(NSError **)error;

@end

#pragma mark - Backtest Statistics Calculator

/**
 * Utility class for calculating statistics from backtest results
 */
@interface BacktestStatisticsCalculator : NSObject

/**
 * Calculate win rate for a set of symbols over next N days
 * @param symbols Symbols to track
 * @param startDate Date symbols were screened
 * @param holdingPeriod Number of days to hold
 * @param priceData Master cache with price data
 * @return Win rate percentage (0-100)
 */
+ (CGFloat)calculateWinRateForSymbols:(NSArray<NSString *> *)symbols
                            startDate:(NSDate *)startDate
                        holdingPeriod:(NSInteger)holdingPeriod
                            priceData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)priceData;

/**
 * Calculate average gain/loss for symbols
 * @param symbols Symbols to track
 * @param startDate Date symbols were screened
 * @param holdingPeriod Number of days to hold
 * @param priceData Master cache with price data
 * @return Dictionary with @"avgGain" and @"avgLoss"
 */
+ (NSDictionary<NSString *, NSNumber *> *)calculateReturnsForSymbols:(NSArray<NSString *> *)symbols
                                                           startDate:(NSDate *)startDate
                                                       holdingPeriod:(NSInteger)holdingPeriod
                                                           priceData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)priceData;

@end

NS_ASSUME_NONNULL_END
