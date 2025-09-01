//
// IndicatorCalculationEngine.h
// TradingApp
//
// Mathematical engine for technical indicator calculations
//

#import <Foundation/Foundation.h>
#import "runtimemodels.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Mathematical Functions for Technical Analysis

@interface IndicatorCalculationEngine : NSObject

#pragma mark - Moving Averages

/// Simple Moving Average
/// @param values Input values
/// @param period Moving average period
/// @return Array of SMA values (padded with NaN for initial values)
+ (NSArray<NSNumber *> *)sma:(NSArray<NSNumber *> *)values period:(NSInteger)period;

/// Exponential Moving Average
/// @param values Input values
/// @param period EMA period
/// @return Array of EMA values (padded with NaN for initial values)
+ (NSArray<NSNumber *> *)ema:(NSArray<NSNumber *> *)values period:(NSInteger)period;

/// Weighted Moving Average
/// @param values Input values
/// @param period WMA period
/// @return Array of WMA values
+ (NSArray<NSNumber *> *)wma:(NSArray<NSNumber *> *)values period:(NSInteger)period;

#pragma mark - Momentum Indicators

/// Relative Strength Index
/// @param closes Closing prices
/// @param period RSI period (typically 14)
/// @return Array of RSI values (0-100 range)
+ (NSArray<NSNumber *> *)rsi:(NSArray<NSNumber *> *)closes period:(NSInteger)period;

/// Rate of Change
/// @param values Input values
/// @param period ROC period
/// @return Array of ROC values (percentage change)
+ (NSArray<NSNumber *> *)roc:(NSArray<NSNumber *> *)values period:(NSInteger)period;

#pragma mark - Volatility Indicators

/// Average True Range
/// @param bars Array of HistoricalBarModel
/// @param period ATR period (typically 14)
/// @return Array of ATR values
+ (NSArray<NSNumber *> *)atr:(NSArray<HistoricalBarModel *> *)bars period:(NSInteger)period;

/// True Range (single bar calculation)
/// @param current Current bar
/// @param previous Previous bar (can be nil for first bar)
/// @return True Range value
+ (double)trueRange:(HistoricalBarModel *)current previous:(nullable HistoricalBarModel *)previous;

#pragma mark - Statistical Functions

/// Standard Deviation
/// @param values Input values
/// @param period Period for calculation
/// @return Array of standard deviation values
+ (NSArray<NSNumber *> *)stdev:(NSArray<NSNumber *> *)values period:(NSInteger)period;

/// Pearson Correlation Coefficient
/// @param valuesX First data series
/// @param valuesY Second data series
/// @param period Period for correlation calculation
/// @return Array of correlation values (-1 to +1)
+ (NSArray<NSNumber *> *)correlation:(NSArray<NSNumber *> *)valuesX
                             valuesY:(NSArray<NSNumber *> *)valuesY
                              period:(NSInteger)period;

#pragma mark - Utility Functions

/// Extract price series from bars
/// @param bars Array of HistoricalBarModel
/// @param priceType "open", "high", "low", "close", "volume"
/// @return Array of NSNumber values
+ (NSArray<NSNumber *> *)extractPriceSeries:(NSArray<HistoricalBarModel *> *)bars
                                  priceType:(NSString *)priceType;

/// Calculate percentage change
/// @param current Current value
/// @param previous Previous value
/// @return Percentage change
+ (double)percentageChange:(double)current previous:(double)previous;

/// Check if value is NaN or infinite
/// @param value Value to check
/// @return YES if value is valid for calculations
+ (BOOL)isValidNumber:(double)value;

/// Create padded array with NaN values at beginning
/// @param count Number of NaN values to prepend
/// @return Array of NSNumber with NaN values
+ (NSArray<NSNumber *> *)nanArrayWithCount:(NSInteger)count;

@end

NS_ASSUME_NONNULL_END
