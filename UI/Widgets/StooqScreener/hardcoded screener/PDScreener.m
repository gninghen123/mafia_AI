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
        @"fibLevel": @0.328,             // Fibonacci retracement level
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

        // Highest/lowest per barra corrente (ultime 'lookback' barre)
        double highestHigh = [TechnicalIndicatorHelper highest:bars
                                                         index:0
                                                        period:lookback
                                                      valueKey:@"high"];
        double lowestLow = [TechnicalIndicatorHelper lowest:bars
                                                       index:0
                                                      period:lookback
                                                    valueKey:@"low"];

        // Condizione 1: filtro preliminare (skip diretto se non passa)
        if (!(highestHigh > (lowestLow * highLowRatio))) {
            continue;
        }

        // L’ultima barra e la penultima
        HistoricalBarModel *current = bars.lastObject;
        HistoricalBarModel *prev = bars[bars.count - 2];

       

        // Condizione 2: high < close[1]
        BOOL belowPrevClose = current.high < prev.close;

        // Condizione 3: close > fib retracement (barra precedente)
        double range = highestHigh - lowestLow;
        double fibLevelPrice = lowestLow + (range * fibLevel);
        BOOL aboveFibLevel = current.close > fibLevelPrice;

        // Condizione 4: avg dollar volume > min
        double avgDollarVolume = 0.0;
        if (bars.count >= lookback) {
            double sum = 0.0;
            for (NSInteger i = 0; i < lookback; i++) {
                HistoricalBarModel *bar = bars[bars.count - 1 - i];
                sum += (bar.volume * bar.close);
            }
            avgDollarVolume = sum / lookback;
        }
        BOOL volumeCondition = avgDollarVolume > minAvgDollarVolume;

        // Condizione 5: close >= SMA20
        double sma20 = [TechnicalIndicatorHelper sma:bars
                                                index:0
                                               period:smaPeriod
                                             valueKey:@"close"];
        BOOL aboveSMA = current.close >= sma20;

        if (belowPrevClose && aboveFibLevel && volumeCondition && aboveSMA) {
            [results addObject:symbol];
        }
    }

    return [results copy];
}

@end
