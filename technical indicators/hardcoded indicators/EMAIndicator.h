//
// EMAIndicator.h
// TradingApp
//
// Exponential Moving Average indicator implementation
//

#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface EMAIndicator : TechnicalIndicatorBase

// Override initialization to set proper name and shortName
- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters;

// EMA-specific convenience methods
- (double)currentEMAValue;              // Latest EMA value
- (NSArray<NSNumber *> *)emaValues;     // Just the EMA numbers (no timestamps)
- (IndicatorDataModel *)latestDataPoint; // Latest complete data point

@end

NS_ASSUME_NONNULL_END
