//
//  TechnicalIndicatorHelper.h
//  TradingApp
//
//  Static helper class for common technical indicator calculations
//  Used by screeners and other components for efficient calculations
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface TechnicalIndicatorHelper : NSObject

#pragma mark - Moving Averages

/**
 * Simple Moving Average (SMA)
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate SMA (lookback from here)
 * @param period Number of bars to average
 * @param valueKey Key to use: "open", "high", "low", "close", "volume"
 * @return SMA value, or 0.0 if insufficient data
 */
+ (double)sma:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period
     valueKey:(NSString *)valueKey;

/**
 * Exponential Moving Average (EMA)
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate EMA
 * @param period EMA period
 * @return EMA value, or 0.0 if insufficient data
 */
+ (double)ema:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period;

/**
 * Weighted Moving Average (WMA)
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate WMA
 * @param period WMA period
 * @return WMA value, or 0.0 if insufficient data
 */
+ (double)wma:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period;

#pragma mark - Momentum Indicators

/**
 * Relative Strength Index (RSI)
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate RSI
 * @param period RSI period (typically 14)
 * @return RSI value (0-100), or 0.0 if insufficient data
 */
+ (double)rsi:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period;

/**
 * Rate of Change (ROC)
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate ROC
 * @param period Lookback period
 * @return ROC percentage, or 0.0 if insufficient data
 */
+ (double)roc:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period;

/**
 * Momentum
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate momentum
 * @param period Lookback period
 * @return Momentum value (close - close[period]), or 0.0 if insufficient data
 */
+ (double)momentum:(NSArray<HistoricalBarModel *> *)bars
             index:(NSInteger)index
            period:(NSInteger)period;

#pragma mark - Volatility Indicators

/**
 * Average True Range (ATR)
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate ATR
 * @param period ATR period (typically 14)
 * @return ATR value, or 0.0 if insufficient data
 */
+ (double)atr:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period;

/**
 * True Range (TR)
 * @param current Current bar
 * @param previous Previous bar (nullable)
 * @return True Range value
 */
+ (double)trueRange:(HistoricalBarModel *)current
           previous:(nullable HistoricalBarModel *)previous;

/**
 * Standard Deviation
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate
 * @param period Lookback period
 * @return Standard deviation of close prices, or 0.0 if insufficient data
 */
+ (double)standardDeviation:(NSArray<HistoricalBarModel *> *)bars
                      index:(NSInteger)index
                     period:(NSInteger)period;

#pragma mark - High/Low Helpers

/**
 * Highest value over period
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to start lookback
 * @param period Number of bars to look back
 * @param valueKey Key to use: "open", "high", "low", "close"
 * @return Highest value in period, or 0.0 if insufficient data
 */
+ (double)highest:(NSArray<HistoricalBarModel *> *)bars
            index:(NSInteger)index
           period:(NSInteger)period
         valueKey:(NSString *)valueKey;

/**
 * Lowest value over period
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to start lookback
 * @param period Number of bars to look back
 * @param valueKey Key to use: "open", "high", "low", "close"
 * @return Lowest value in period, or 0.0 if insufficient data
 */
+ (double)lowest:(NSArray<HistoricalBarModel *> *)bars
           index:(NSInteger)index
          period:(NSInteger)period
        valueKey:(NSString *)valueKey;

/**
 * Index of highest bar over period
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to start lookback
 * @param period Number of bars to look back
 * @param valueKey Key to use: "open", "high", "low", "close"
 * @return Index of highest bar, or -1 if not found
 */
+ (NSInteger)highestBarIndex:(NSArray<HistoricalBarModel *> *)bars
                       index:(NSInteger)index
                      period:(NSInteger)period
                    valueKey:(NSString *)valueKey;

/**
 * Index of lowest bar over period
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to start lookback
 * @param period Number of bars to look back
 * @param valueKey Key to use: "open", "high", "low", "close"
 * @return Index of lowest bar, or -1 if not found
 */
+ (NSInteger)lowestBarIndex:(NSArray<HistoricalBarModel *> *)bars
                      index:(NSInteger)index
                     period:(NSInteger)period
                   valueKey:(NSString *)valueKey;

#pragma mark - Pattern Detection

/**
 * Check if bar is inside previous bar
 * @param current Current bar
 * @param previous Previous bar
 * @return YES if current high <= previous high AND current low >= previous low
 */
+ (BOOL)isInsideBar:(HistoricalBarModel *)current
           previous:(HistoricalBarModel *)previous;

/**
 * Check if bar is outside previous bar
 * @param current Current bar
 * @param previous Previous bar
 * @return YES if current high > previous high AND current low < previous low
 */
+ (BOOL)isOutsideBar:(HistoricalBarModel *)current
            previous:(HistoricalBarModel *)previous;

/**
 * Check if there was a gap up (low >= previous high)
 * @param current Current bar
 * @param previous Previous bar
 * @return YES if gap up detected
 */
+ (BOOL)isGapUp:(HistoricalBarModel *)current
       previous:(HistoricalBarModel *)previous;

/**
 * Check if there was a gap down (high <= previous low)
 * @param current Current bar
 * @param previous Previous bar
 * @return YES if gap down detected
 */
+ (BOOL)isGapDown:(HistoricalBarModel *)current
         previous:(HistoricalBarModel *)previous;

/**
 * Calculate gap percentage
 * @param current Current bar
 * @param previous Previous bar
 * @return Gap percentage: (open - previous.close) / previous.close * 100
 */
+ (double)gapPercent:(HistoricalBarModel *)current
            previous:(HistoricalBarModel *)previous;

#pragma mark - Volume Analysis

/**
 * Calculate dollar volume
 * @param bar Bar to calculate for
 * @return volume * close
 */
+ (double)dollarVolume:(HistoricalBarModel *)bar;

/**
 * Average volume over period
 * @param bars Array of HistoricalBarModel objects
 * @param index Index at which to calculate
 * @param period Number of bars to average
 * @return Average volume, or 0.0 if insufficient data
 */
+ (double)averageVolume:(NSArray<HistoricalBarModel *> *)bars
                  index:(NSInteger)index
                 period:(NSInteger)period;

#pragma mark - Utility Methods

/**
 * Extract value from bar by key
 * @param bar HistoricalBarModel object
 * @param key "open", "high", "low", "close", "volume", "typical", "range"
 * @return Value for the specified key
 */
+ (double)valueFromBar:(HistoricalBarModel *)bar
                forKey:(NSString *)key;

/**
 * Check if bars array has sufficient data for calculation
 * @param bars Array of bars
 * @param index Current index
 * @param requiredBars Number of bars required before index
 * @return YES if sufficient data available
 */
+ (BOOL)hasSufficientData:(NSArray<HistoricalBarModel *> *)bars
                    index:(NSInteger)index
             requiredBars:(NSInteger)requiredBars;

@end

NS_ASSUME_NONNULL_END
