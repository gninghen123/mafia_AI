//
//  BacktestCacheHelper.h
//  TradingApp
//
//  Utility class for efficient cache slicing during backtest
//  Allows creating "snapshots" of historical data at specific dates
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface BacktestCacheHelper : NSObject

#pragma mark - Cache Slicing

/**
 * Slice master cache to specific reference date
 * Creates a "snapshot" of the cache as it would have been at that date
 *
 * @param masterCache Full cache with all historical bars
 * @param referenceDate Date to slice at (inclusive)
 * @return New cache containing only bars where date <= referenceDate
 *
 * @discussion
 * This is the core method for backtest time-travel. Given a master cache
 * containing data from (startDate - maxBars) to endDate, this method
 * creates a cache that contains only data up to referenceDate.
 *
 * This allows screeners to run as if they were executing on that specific
 * date, with no knowledge of future data.
 *
 * Performance: O(n) where n = number of bars per symbol (typically < 300)
 * Memory: Creates new arrays, but shares underlying HistoricalBarModel objects
 */
+ (NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)sliceCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache
                                                                 upToDate:(NSDate *)referenceDate;

/**
 * Slice cache to specific date range
 *
 * @param masterCache Full cache with all historical bars
 * @param startDate Start date (inclusive)
 * @param endDate End date (inclusive)
 * @return Cache containing only bars within date range
 */
+ (NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)sliceCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache
                                                                  fromDate:(NSDate *)startDate
                                                                    toDate:(NSDate *)endDate;

#pragma mark - Cache Statistics

/**
 * Count symbols available at specific date
 *
 * @param referenceDate Date to check
 * @param masterCache Full cache
 * @return Number of symbols with at least one bar <= referenceDate
 */
+ (NSInteger)symbolCountAtDate:(NSDate *)referenceDate
                       inCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache;

/**
 * Get date range covered by cache
 *
 * @param cache Cache to analyze
 * @return Dictionary with @"startDate" and @"endDate", or nil if cache is empty
 */
+ (nullable NSDictionary<NSString *, NSDate *> *)dateRangeForCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache;

/**
 * Calculate total bar count across all symbols
 *
 * @param cache Cache to analyze
 * @return Total number of bars
 */
+ (NSInteger)totalBarCountInCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache;

#pragma mark - Cache Validation

/**
 * Validate cache for backtest use
 * Checks if cache has sufficient data for the given date range
 *
 * @param cache Cache to validate
 * @param startDate Backtest start date
 * @param endDate Backtest end date
 * @param minBarsRequired Minimum bars needed before start date
 * @return YES if cache is valid for backtest, NO otherwise
 */
+ (BOOL)validateCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache
        forDateRange:(NSDate *)startDate
              toDate:(NSDate *)endDate
    minBarsRequired:(NSInteger)minBarsRequired;

@end

NS_ASSUME_NONNULL_END
