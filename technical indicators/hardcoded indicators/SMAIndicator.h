//
// SMAIndicator.h
// TradingApp
//
// Simple Moving Average indicator implementation
//

#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface SMAIndicator : TechnicalIndicatorBase

// SMA-specific convenience methods
- (double)currentSMAValue;              // Latest SMA value
- (NSArray<NSNumber *> *)smaValues;     // Just the SMA numbers (no timestamps)
- (IndicatorDataModel *)latestDataPoint; // Latest complete data point

@end

NS_ASSUME_NONNULL_END
