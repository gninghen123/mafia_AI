//
//  ShakeScreener.m
//  TradingApp
//

#import "ShakeScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation ShakeScreener

#pragma mark - Properties

- (NSString *)screenerID {
    return @"shake";
}

- (NSString *)displayName {
    return @"Shake (Gap + Volume)";
}

- (NSString *)descriptionText {
    return @"Finds stocks with gapping and high volume days in the last N days";
}

- (NSInteger)minBarsRequired {
    // Need 50 bars for SMA(volume, 50) + 16 lookback = 66 bars
    NSInteger lookback = [self parameterIntegerForKey:@"lookback_days" defaultValue:16];
    return 50 + lookback;
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSMutableArray *results = [NSMutableArray array];
    
    // Get parameters with defaults
    double volumeMultiplier = [self parameterDoubleForKey:@"volume_multiplier" defaultValue:2.0];
    double minDollarVolume = [self parameterDoubleForKey:@"min_dollar_volume" defaultValue:5000000.0];
    double minVolume = [self parameterDoubleForKey:@"min_volume" defaultValue:1000000.0];
    double gapThreshold = [self parameterDoubleForKey:@"gap_threshold" defaultValue:1.2];
    NSInteger lookbackDays = [self parameterIntegerForKey:@"lookback_days" defaultValue:16];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) {
            continue;  // Insufficient data
        }
        
        // Check if there was a "shake day" within the lookback period
        BOOL foundShakeDay = NO;
        
        NSInteger startIdx = bars.count - 1;
        NSInteger endIdx = MAX(0, bars.count - 1 - lookbackDays);
        
        for (NSInteger i = startIdx; i > endIdx; i--) {
            HistoricalBarModel *bar = bars[i];
            HistoricalBarModel *prevBar = (i > 0) ? bars[i-1] : nil;
            
            if (!prevBar) continue;
            
            // Calculate SMA(volume, 50) at position i
            double smaVolume = [TechnicalIndicatorHelper sma:bars
                                                        index:i
                                                       period:50
                                                     valueKey:@"volume"];
            
            // Calculate SMA(close, 5) at position i
            double smaClose5 = [TechnicalIndicatorHelper sma:bars
                                                        index:i
                                                       period:5
                                                     valueKey:@"close"];
            
            // Condition 1: volume >= SMA(volume, 50) * multiplier
            BOOL volumeCondition = bar.volume >= (smaVolume * volumeMultiplier);
            
            // Condition 2: volume * close >= min dollar volume
            double dollarVol = [TechnicalIndicatorHelper dollarVolume:bar];
            BOOL dollarVolumeCondition = dollarVol >= minDollarVolume;
            
            // Condition 3: volume >= min absolute volume
            BOOL minVolumeCondition = bar.volume >= minVolume;
            
            // Condition 4: Gap up OR close > previous close * threshold
            BOOL gapUp = [TechnicalIndicatorHelper isGapUp:bar previous:prevBar];
            BOOL bigMove = bar.close > (prevBar.close * gapThreshold);
            BOOL gapCondition = gapUp || bigMove;
            
            // Condition 5: close > SMA(close, 5)
            BOOL smaCondition = bar.close > smaClose5;
            
            // All conditions must be true for a "shake day"
            if (volumeCondition && dollarVolumeCondition && minVolumeCondition &&
                gapCondition && smaCondition) {
                foundShakeDay = YES;
                break;
            }
        }
        
        if (!foundShakeDay) continue;
        
        // Final condition: close today OR yesterday > SMA(close, 20)
        NSInteger todayIdx = bars.count - 1;
        NSInteger yesterdayIdx = bars.count - 2;
        
        HistoricalBarModel *today = bars[todayIdx];
        HistoricalBarModel *yesterday = bars[yesterdayIdx];
        
        double sma20Today = [TechnicalIndicatorHelper sma:bars
                                                     index:todayIdx
                                                    period:20
                                                  valueKey:@"close"];
        
        BOOL finalCondition = (today.close > sma20Today) || (yesterday.close > sma20Today);
        
        if (finalCondition) {
            [results addObject:symbol];
        }
    }
    
    return [results copy];
}

- (NSDictionary *)defaultParameters {
    return @{
        @"volume_multiplier": @2.0,
        @"min_dollar_volume": @5000000,
        @"min_volume": @1000000,
        @"gap_threshold": @1.2,
        @"lookback_days": @16
    };
}

@end
