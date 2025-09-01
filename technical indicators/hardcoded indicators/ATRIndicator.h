//
// ATRIndicator.h
// TradingApp
//
// Average True Range indicator implementation
//

#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface ATRIndicator : TechnicalIndicatorBase

// ATR-specific convenience methods
- (double)currentATRValue;              // Latest ATR value
- (NSArray<NSNumber *> *)atrValues;     // Just the ATR numbers
- (IndicatorDataModel *)latestDataPoint; // Latest complete data point

// ATR analysis methods
- (double)atrPercentage:(double)currentPrice; // ATR as % of current price
- (BOOL)isHighVolatility:(double)threshold;   // ATR above threshold
- (BOOL)isLowVolatility:(double)threshold;    // ATR below threshold

@end

NS_ASSUME_NONNULL_END
