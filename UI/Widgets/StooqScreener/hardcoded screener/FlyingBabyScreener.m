

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

