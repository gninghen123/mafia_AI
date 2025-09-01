//
// RSIIndicator.h
// TradingApp
//
// Relative Strength Index indicator implementation
//

#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface RSIIndicator : TechnicalIndicatorBase

// RSI-specific convenience methods
- (double)currentRSIValue;              // Latest RSI value (0-100)
- (NSArray<NSNumber *> *)rsiValues;     // Just the RSI numbers
- (IndicatorDataModel *)latestDataPoint; // Latest complete data point

// RSI analysis methods
- (BOOL)isOverbought;                   // RSI > 70
- (BOOL)isOversold;                     // RSI < 30
- (BOOL)isBullishDivergence:(NSArray<HistoricalBarModel *> *)bars; // Price down, RSI up
- (BOOL)isBearishDivergence:(NSArray<HistoricalBarModel *> *)bars; // Price up, RSI down

@end

NS_ASSUME_NONNULL_END
