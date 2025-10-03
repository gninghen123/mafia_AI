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
#import "TechnicalIndicatorHelper.h"  // ← Aggiungi import

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
        @"minAvgDollarVolume": @2.5,// Min average dollar volume
        @"smaPeriod": @20                // SMA period for trend filter
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSInteger lookback = [self parameterIntegerForKey:@"lookbackPeriod" defaultValue:5];
    double highLowRatio = [self parameterDoubleForKey:@"highLowRatio" defaultValue:2.0];
    double fibLevel = [self parameterDoubleForKey:@"fibLevel" defaultValue:0.348];
    double minAvgDollarVolume = [self parameterDoubleForKey:@"minAvgDollarVolume" defaultValue:2.5] * 1000000;
    NSInteger smaPeriod = [self parameterIntegerForKey:@"smaPeriod" defaultValue:20];
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        HistoricalBarModel *current = bars[0];
        HistoricalBarModel *prev = bars[1];
        
        // ✅ Calculate highest(high, 5) and lowest(low, 5) for CURRENT bars (index 0)
        double highestHigh = [TechnicalIndicatorHelper highest:bars
                                                         index:0
                                                        period:lookback
                                                      valueKey:@"high"];
        double lowestLow = [TechnicalIndicatorHelper lowest:bars
                                                       index:0
                                                      period:lookback
                                                    valueKey:@"low"];
        
        // ✅ Calculate for PREVIOUS bars [1]
        double highestHigh1 = [TechnicalIndicatorHelper highest:bars
                                                          index:1
                                                         period:lookback
                                                       valueKey:@"high"];
        double lowestLow1 = [TechnicalIndicatorHelper lowest:bars
                                                        index:1
                                                       period:lookback
                                                     valueKey:@"low"];
        
        // Condition 1: highest(high,5) > lowest(low,5) * 2
        BOOL highLowCondition = highestHigh > (lowestLow * highLowRatio);
        
        // Condition 2: high < close[1]
        BOOL belowPrevClose = current.high < prev.close;
        
        // Condition 3: close > (lowest(low,5)[1] + (highest(high,5)[1] - lowest(low,5)[1]) * 0.348)
        double range = highestHigh1 - lowestLow1;
        double fibLevel_price = lowestLow1 + (range * fibLevel);
        BOOL aboveFibLevel = current.close > fibLevel_price;
        
        // ✅ Condition 4: simpleMovingAvg(volume*close, 5) > 250000
        // Calculate average dollar volume manually (TechnicalIndicatorHelper doesn't have smaOfDollarVolume)
        double avgDollarVolume = 0.0;
        if (bars.count >= lookback) {
            double sum = 0.0;
            for (NSInteger i = 0; i < lookback; i++) {
                HistoricalBarModel *bar = bars[i];
                sum += (bar.volume * bar.close);
            }
            avgDollarVolume = sum / (double)lookback;
        }
        BOOL volumeCondition = avgDollarVolume > minAvgDollarVolume;
        
        // ✅ Condition 5: close >= simpleMovingAvg(close, 20)
        double sma20 = [TechnicalIndicatorHelper sma:bars
                                                index:0
                                               period:smaPeriod
                                             valueKey:@"close"];
        BOOL aboveSMA = current.close >= sma20;
        
        if (highLowCondition && belowPrevClose && aboveFibLevel && volumeCondition && aboveSMA) {
            [results addObject:symbol];
        }
    }
    
    return [results copy];
}


@end
