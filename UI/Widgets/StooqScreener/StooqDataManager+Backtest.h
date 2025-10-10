//
//  StooqDataManager+Backtest.h
//  TradingApp
//
//  Category for backtest-specific data loading
//  Adds support for extended range loading without modifying core functionality
//

#import "StooqDataManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface StooqDataManager (Backtest)

#pragma mark - Extended Range Loading

/**
 * Load extended data range for backtest
 * Automatically calculates extended start date based on maxBars
 *
 * @param symbols Array of symbols to load
 * @param startDate Backtest start date (user-selected range start)
 * @param endDate Backtest end date (user-selected range end)
 * @param maxBars Maximum bars required by screeners (for lookback calculation)
 * @param completion Called with full historical data cache or error
 *
 * @discussion
 * This method loads data from (startDate - maxBars - safetyMargin) to endDate.
 * The cache returned contains ALL bars in this extended range, allowing
 * for efficient slicing at any date within the backtest range.
 */
- (void)loadExtendedDataForSymbols:(NSArray<NSString *> *)symbols
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                           maxBars:(NSInteger)maxBars
                        completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> * _Nullable cache,
                                            NSError * _Nullable error))completion;

/**
 * Load data for specific date range (explicit start/end)
 *
 * @param symbols Array of symbols to load
 * @param fromDate Explicit start date for data
 * @param toDate Explicit end date for data
 * @param completion Called with filtered cache or error
 *
 * @discussion
 * Unlike loadExtendedDataForSymbols, this method uses explicit dates
 * without automatic lookback calculation. Use this when you've already
 * calculated the required start date externally.
 */
- (void)loadDataForSymbols:(NSArray<NSString *> *)symbols
                  fromDate:(NSDate *)fromDate
                    toDate:(NSDate *)toDate
                completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> * _Nullable cache,
                                    NSError * _Nullable error))completion;

#pragma mark - Bar Filtering Utilities

/**
 * Filter bars to specific date range
 *
 * @param bars Array of HistoricalBarModel objects
 * @param fromDate Start date (inclusive)
 * @param toDate End date (inclusive)
 * @return Filtered array containing only bars within range
 */
- (NSArray<HistoricalBarModel *> *)filterBars:(NSArray<HistoricalBarModel *> *)bars
                                     fromDate:(NSDate *)fromDate
                                       toDate:(NSDate *)toDate;

/**
 * Filter bars up to specific date
 *
 * @param bars Array of HistoricalBarModel objects
 * @param toDate End date (inclusive)
 * @return Filtered array containing only bars <= toDate
 */
- (NSArray<HistoricalBarModel *> *)filterBars:(NSArray<HistoricalBarModel *> *)bars
                                       upToDate:(NSDate *)toDate;

@end

NS_ASSUME_NONNULL_END
