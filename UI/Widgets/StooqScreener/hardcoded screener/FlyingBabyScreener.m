

// ============================================================================

//
//  FlyingBabyScreener.m
//  TradingApp
//
//  Pattern: close[1] > (close[2] * 1.07) && low >= high[1] * 0.99 &&
//           high - low < high[1] - low[1] && volume[1] * close[1] > 4000000
//  Within: 2 bars
//

#import "FlyingBabyScreener.h"

@implementation FlyingBabyScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"flying_baby";
}

- (NSString *)displayName {
    return @"Flying Baby";
}

- (NSString *)descriptionText {
    return @"Looks for strong upward move followed by tight consolidation within 2 bars";
}

- (NSInteger)minBarsRequired {
    return 3; // Need [2], [1], [0]
}

- (NSDictionary *)defaultParameters {
    return @{
        @"length": @2,                    // Window to check pattern
        @"priceGainPercent": @7.0,        // close[1] > close[2] * 1.07
        @"lowThreshold": @0.99,           // low >= high[1] * 0.99
        @"minDollarVolume": @4000000.0    // volume[1] * close[1] > 4M
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSInteger length = [self parameterIntegerForKey:@"length" defaultValue:2];
    double priceGainPercent = [self parameterDoubleForKey:@"priceGainPercent" defaultValue:7.0];
    double lowThreshold = [self parameterDoubleForKey:@"lowThreshold" defaultValue:0.99];
    double minDollarVolume = [self parameterDoubleForKey:@"minDollarVolume" defaultValue:4000000.0];
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        // Check within the last 'length' bars
        BOOL foundPattern = NO;
        
        for (NSInteger i = 0; i < MIN(length, bars.count - 2); i++) {
            HistoricalBarModel *current = bars[i];      // [0] or current position
            HistoricalBarModel *prev1 = bars[i + 1];    // [1]
            HistoricalBarModel *prev2 = bars[i + 2];    // [2]
            
            // Condition 1: close[1] > (close[2] * 1.07)
            BOOL strongMove = prev1.close > (prev2.close * (1.0 + priceGainPercent / 100.0));
            
            // Condition 2: low >= high[1] * 0.99
            BOOL tightLow = current.low >= (prev1.high * lowThreshold);
            
            // Condition 3: high - low < high[1] - low[1] (narrower range)
            double currentRange = current.high - current.low;
            double prev1Range = prev1.high - prev1.low;
            BOOL narrowerRange = currentRange < prev1Range;
            
            // Condition 4: volume[1] * close[1] > 4000000
            double dollarVolume = prev1.volume * prev1.close;
            BOOL sufficientVolume = dollarVolume > minDollarVolume;
            
            if (strongMove && tightLow && narrowerRange && sufficientVolume) {
                foundPattern = YES;
                break;
            }
        }
        
        if (foundPattern) {
            [results addObject:symbol];
        }
    }
    
    return [results copy];
}

@end

// ============================================================================
// ============================================================================

//
//  PDScreener.h
//  TradingApp
//
//  PD pattern screener
//

#import "BaseScreener.h"

NS_ASSUME_NONNULL_BEGIN

@interface PDScreener : BaseScreener
@end

NS_ASSUME_NONNULL_END

// ============================================================================

//
//  PDScreener.m
//  TradingApp
//
//  Pattern: highest(high,5) > lowest(low,5)*2 &&
//           high < close[1] &&
//           close > (lowest(low,5)[1] + (highest(high,5)[1] - lowest(low,5)[1]) * 0.348) &&
//           simpleMovingAvg(volume*close,5) > 250000 &&
//           close >= simpleMovingAvg(close,20)
//

#import "PDScreener.h"

@implementation PDScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"pd";
}

- (NSString *)displayName {
    return @"PD";
}

- (NSString *)descriptionText {
    return @"PD pattern with high/low ratio, retracement level, and moving average filters";
}

- (NSInteger)minBarsRequired {
    return 21; // Need 20 bars for SMA(20) + 1 current
}

- (NSDictionary *)defaultParameters {
    return @{
        @"lookbackPeriod": @5,           // Period for high/low calculation
        @"highLowRatio": @2.0,           // highest > lowest * 2
        @"fibLevel": @0.348,             // Fibonacci retracement level
        @"minAvgDollarVolume": @250000.0,// Min average dollar volume
        @"smaPeriod": @20                // SMA period for trend filter
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSInteger lookback = [self parameterIntegerForKey:@"lookbackPeriod" defaultValue:5];
    double highLowRatio = [self parameterDoubleForKey:@"highLowRatio" defaultValue:2.0];
    double fibLevel = [self parameterDoubleForKey:@"fibLevel" defaultValue:0.348];
    double minAvgDollarVolume = [self parameterDoubleForKey:@"minAvgDollarVolume" defaultValue:250000.0];
    NSInteger smaPeriod = [self parameterIntegerForKey:@"smaPeriod" defaultValue:20];
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        HistoricalBarModel *current = bars[0];
        HistoricalBarModel *prev = bars[1];
        
        // Calculate highest(high, 5) and lowest(low, 5) for CURRENT bars
        double highestHigh = [self highest:bars period:lookback offset:0 key:@"high"];
        double lowestLow = [self lowest:bars period:lookback offset:0 key:@"low"];
        
        // Calculate for PREVIOUS bars [1]
        double highestHigh1 = [self highest:bars period:lookback offset:1 key:@"high"];
        double lowestLow1 = [self lowest:bars period:lookback offset:1 key:@"low"];
        
        // Condition 1: highest(high,5) > lowest(low,5) * 2
        BOOL highLowCondition = highestHigh > (lowestLow * highLowRatio);
        
        // Condition 2: high < close[1]
        BOOL belowPrevClose = current.high < prev.close;
        
        // Condition 3: close > (lowest(low,5)[1] + (highest(high,5)[1] - lowest(low,5)[1]) * 0.348)
        double range = highestHigh1 - lowestLow1;
        double fibLevel_price = lowestLow1 + (range * fibLevel);
        BOOL aboveFibLevel = current.close > fibLevel_price;
        
        // Condition 4: simpleMovingAvg(volume*close, 5) > 250000
        double avgDollarVolume = [self smaOfDollarVolume:bars period:lookback];
        BOOL volumeCondition = avgDollarVolume > minAvgDollarVolume;
        
        // Condition 5: close >= simpleMovingAvg(close, 20)
        double sma20 = [self sma:bars period:smaPeriod offset:0 key:@"close"];
        BOOL aboveSMA = current.close >= sma20;
        
        if (highLowCondition && belowPrevClose && aboveFibLevel && volumeCondition && aboveSMA) {
            [results addObject:symbol];
        }
    }
    
    return [results copy];
}

#pragma mark - Helper Methods

- (double)highest:(NSArray<HistoricalBarModel *> *)bars period:(NSInteger)period offset:(NSInteger)offset key:(NSString *)key {
    double max = -INFINITY;
    NSInteger end = MIN(offset + period, bars.count);
    
    for (NSInteger i = offset; i < end; i++) {
        HistoricalBarModel *bar = bars[i];
        double value = [key isEqualToString:@"high"] ? bar.high :
                      [key isEqualToString:@"low"] ? bar.low :
                      [key isEqualToString:@"close"] ? bar.close : bar.open;
        if (value > max) max = value;
    }
    return max;
}

- (double)lowest:(NSArray<HistoricalBarModel *> *)bars period:(NSInteger)period offset:(NSInteger)offset key:(NSString *)key {
    double min = INFINITY;
    NSInteger end = MIN(offset + period, bars.count);
    
    for (NSInteger i = offset; i < end; i++) {
        HistoricalBarModel *bar = bars[i];
        double value = [key isEqualToString:@"high"] ? bar.high :
                      [key isEqualToString:@"low"] ? bar.low :
                      [key isEqualToString:@"close"] ? bar.close : bar.open;
        if (value < min) min = value;
    }
    return min;
}

- (double)sma:(NSArray<HistoricalBarModel *> *)bars period:(NSInteger)period offset:(NSInteger)offset key:(NSString *)key {
    if (bars.count < offset + period) return 0.0;
    
    double sum = 0.0;
    for (NSInteger i = offset; i < offset + period; i++) {
        HistoricalBarModel *bar = bars[i];
        double value = [key isEqualToString:@"close"] ? bar.close :
                      [key isEqualToString:@"high"] ? bar.high :
                      [key isEqualToString:@"low"] ? bar.low : bar.open;
        sum += value;
    }
    return sum / (double)period;
}

- (double)smaOfDollarVolume:(NSArray<HistoricalBarModel *> *)bars period:(NSInteger)period {
    if (bars.count < period) return 0.0;
    
    double sum = 0.0;
    for (NSInteger i = 0; i < period; i++) {
        HistoricalBarModel *bar = bars[i];
        sum += (bar.volume * bar.close);
    }
    return sum / (double)period;
}

@end

// ============================================================================
// ============================================================================

//
//  SMCScreener.h
//  TradingApp
//
//  SMC pattern screener
//

#import "BaseScreener.h"

NS_ASSUME_NONNULL_BEGIN

@interface SMCScreener : BaseScreener
@end

NS_ASSUME_NONNULL_END

// ============================================================================

//
//  SMCScreener.m
//  TradingApp
//
//  Pattern: close[2] > (close[3] * 1.10) &&
//           low[1] > ((high[2] - low[2]) * 0.45) + low[2] &&
//           low > ((high[2] - low[2]) * 0.45) + low[2] &&
//           close < high[2] &&
//           close[1] < high[2] &&
//           volume[2] * close[2] > 2000000 &&
//           volume < volume[2] &&
//           volume[1] < volume[2]
//

#import "SMCScreener.h"

@implementation SMCScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"smc";
}

- (NSString *)displayName {
    return @"SMC";
}

- (NSString *)descriptionText {
    return @"SMC pattern: Strong move followed by consolidation with decreasing volume";
}

- (NSInteger)minBarsRequired {
    return 4; // Need [3], [2], [1], [0]
}

- (NSDictionary *)defaultParameters {
    return @{
        @"priceGainPercent": @10.0,       // close[2] > close[3] * 1.10
        @"rangePercent": @45.0,           // 45% of range[2]
        @"minDollarVolume": @2000000.0    // volume[2] * close[2] > 2M
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    double priceGainPercent = [self parameterDoubleForKey:@"priceGainPercent" defaultValue:10.0];
    double rangePercent = [self parameterDoubleForKey:@"rangePercent" defaultValue:45.0];
    double minDollarVolume = [self parameterDoubleForKey:@"minDollarVolume" defaultValue:2000000.0];
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        HistoricalBarModel *current = bars[0];  // [0]
        HistoricalBarModel *prev1 = bars[1];    // [1]
        HistoricalBarModel *prev2 = bars[2];    // [2]
        HistoricalBarModel *prev3 = bars[3];    // [3]
        
        // Condition 1: close[2] > (close[3] * 1.10)
        BOOL strongMove = prev2.close > (prev3.close * (1.0 + priceGainPercent / 100.0));
        
        // Calculate 45% level of prev2 range
        double range2 = prev2.high - prev2.low;
        double level45 = (range2 * (rangePercent / 100.0)) + prev2.low;
        
        // Condition 2: low[1] > ((high[2] - low[2]) * 0.45) + low[2]
        BOOL prev1Above45 = prev1.low > level45;
        
        // Condition 3: low > ((high[2] - low[2]) * 0.45) + low[2]
        BOOL currentAbove45 = current.low > level45;
        
        // Condition 4: close < high[2]
        BOOL closeBelowHigh2 = current.close < prev2.high;
        
        // Condition 5: close[1] < high[2]
        BOOL close1BelowHigh2 = prev1.close < prev2.high;
        
        // Condition 6: volume[2] * close[2] > 2000000
        double dollarVolume2 = prev2.volume * prev2.close;
        BOOL volumeCondition = dollarVolume2 > minDollarVolume;
        
        // Condition 7: volume < volume[2]
        BOOL volumeDecreasing = current.volume < prev2.volume;
        
        // Condition 8: volume[1] < volume[2]
        BOOL volume1Decreasing = prev1.volume < prev2.volume;
        
        if (strongMove && prev1Above45 && currentAbove45 &&
            closeBelowHigh2 && close1BelowHigh2 &&
            volumeCondition && volumeDecreasing && volume1Decreasing) {
            [results addObject:symbol];
        }
    }
    
    return [results copy];
}

@end

// ============================================================================
// REGISTRATION - AGGIUNGERE A ScreenerRegistry.m
// ============================================================================

/*
Nel metodo registerDefaultScreeners di ScreenerRegistry.m, aggiungere:

#import "FlyingBabyScreener.h"
#import "PDScreener.h"
#import "SMCScreener.h"

- (void)registerDefaultScreeners {
    // Existing screeners
    [self registerScreenerClass:[ShakeScreener class]];
    [self registerScreenerClass:[WIRScreener class]];
    
    // NEW SCREENERS
    [self registerScreenerClass:[FlyingBabyScreener class]];
    [self registerScreenerClass:[PDScreener class]];
    [self registerScreenerClass:[SMCScreener class]];
    
    NSLog(@"✅ Registered %lu default screeners", (unsigned long)self.screeners.count);
}
*/
