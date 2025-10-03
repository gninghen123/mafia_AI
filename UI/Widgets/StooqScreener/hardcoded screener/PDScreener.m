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

        // L’ultima barra è la più recente
        HistoricalBarModel *current = bars.lastObject;
        HistoricalBarModel *prev = bars[bars.count - 2];

        // Highest/lowest per barra corrente (ultime 'lookback' barre)
        double highestHigh = [TechnicalIndicatorHelper highest:bars
                                                         index:bars.count - 1
                                                        period:lookback
                                                      valueKey:@"high"];
        double lowestLow = [TechnicalIndicatorHelper lowest:bars
                                                       index:bars.count - 1
                                                      period:lookback
                                                    valueKey:@"low"];

        // Highest/lowest per barra precedente (penultima)
        double highestHigh1 = [TechnicalIndicatorHelper highest:bars
                                                          index:bars.count - 2
                                                         period:lookback
                                                       valueKey:@"high"];
        double lowestLow1 = [TechnicalIndicatorHelper lowest:bars
                                                        index:bars.count - 2
                                                       period:lookback
                                                     valueKey:@"low"];

        // Condizione 1: highest(high,5) > lowest(low,5) * highLowRatio
        BOOL highLowCondition = highestHigh > (lowestLow * highLowRatio);

        // Condizione 2: high < close[1]
        BOOL belowPrevClose = current.high < prev.close;

        // Condizione 3: close > fib retracement (barra precedente)
        double range = highestHigh1 - lowestLow1;
        double fibLevelPrice = lowestLow1 + (range * fibLevel);
        BOOL aboveFibLevel = current.close > fibLevelPrice;

        // Condizione 4: avg dollar volume > min
        double avgDollarVolume = 0.0;
        if (bars.count >= lookback) {
            double sum = 0.0;
            for (NSInteger i = 0; i < lookback; i++) {
                HistoricalBarModel *bar = bars[bars.count - 1 - i]; // partendo dall’ultima
                sum += (bar.volume * bar.close);
            }
            avgDollarVolume = sum / (double)lookback;
        }
        BOOL volumeCondition = avgDollarVolume > minAvgDollarVolume;

        // Condizione 5: close >= SMA20
        double sma20 = [TechnicalIndicatorHelper sma:bars
                                                index:bars.count - 1
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
