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
        @"minDollarVolume": @2.0    // volume[2] * close[2] > 2M
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {

    double priceGainPercent = [self parameterDoubleForKey:@"priceGainPercent" defaultValue:10.0];
    double rangePercent = [self parameterDoubleForKey:@"rangePercent" defaultValue:45.0];
    double minDollarVolume = [self parameterDoubleForKey:@"minDollarVolume" defaultValue:2.0] * 1000000;

    NSMutableArray<NSString *> *results = [NSMutableArray array];

    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        if (!bars || bars.count < self.minBarsRequired) continue;

        // Aggiornato per ultima barra = più recente
        HistoricalBarModel *current = bars.lastObject;            // [0] -> ultima barra
        HistoricalBarModel *prev1 = bars[bars.count - 2];         // [1] -> penultima
        HistoricalBarModel *prev2 = bars[bars.count - 3];         // [2] -> due barre fa
        HistoricalBarModel *prev3 = bars[bars.count - 4];         // [3] -> tre barre fa

        // Condizione 1: close[2] > (close[3] * 1.10)
        BOOL strongMove = prev2.close > (prev3.close * (1.0 + priceGainPercent / 100.0));

        // Calcolo livello 45% di prev2
        double range2 = prev2.high - prev2.low;
        double level45 = (range2 * (rangePercent / 100.0)) + prev2.low;

        // Condizione 2: low[1] > level45
        BOOL prev1Above45 = prev1.low > level45;

        // Condizione 3: low > level45
        BOOL currentAbove45 = current.low > level45;

        // Condizione 4: close < high[2]
        BOOL closeBelowHigh2 = current.close < prev2.high;

        // Condizione 5: close[1] < high[2]
        BOOL close1BelowHigh2 = prev1.close < prev2.high;

        // Condizione 6: volume[2] * close[2] > minDollarVolume
        double dollarVolume2 = prev2.volume * prev2.close;
        BOOL volumeCondition = dollarVolume2 > minDollarVolume;

        // Condizione 7: volume < volume[2]
        BOOL volumeDecreasing = current.volume < prev2.volume;

        // Condizione 8: volume[1] < volume[2]
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
