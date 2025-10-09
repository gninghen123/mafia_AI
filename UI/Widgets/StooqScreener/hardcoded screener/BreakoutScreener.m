//
//  BreakoutScreener.m
//  TradingApp
//
//  Pattern: close > highest(close[1], lookbackPeriod)
//  - Current close breaks above the highest close of the previous N bars
//  - lookbackPeriod is configurable (default 20)
//

#import "BreakoutScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation BreakoutScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"breakout";
}

- (NSString *)displayName {
    return @"Breakout";
}

- (NSString *)descriptionText {
    return @"Finds stocks breaking above the highest close of the previous N bars";
}

- (NSInteger)minBarsRequired {
    // Need lookbackPeriod + 1 (for current bar) + 1 (for index offset)
    NSInteger lookback = [self parameterIntegerForKey:@"lookbackPeriod" defaultValue:20];
    return lookback + 2;
}

- (NSDictionary *)defaultParameters {
    return @{
        @"lookbackPeriod": @20  // Default to 20-day breakout
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSInteger lookbackPeriod = [self parameterIntegerForKey:@"lookbackPeriod" defaultValue:20];
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        HistoricalBarModel *current = bars.lastObject;
        HistoricalBarModel *previous = bars[bars.count-2];

        
        // Calculate highest(close[1], lookbackPeriod)
        // Index 1 = previous bar, then look back 'lookbackPeriod' bars from there
        double highestPreviousClose = [TechnicalIndicatorHelper highest:bars
                                                                   index:2
                                                                  period:lookbackPeriod
                                                                valueKey:@"close"];
        
        // Condition: close > highest(close[1], lookbackPeriod)
        if (current.close > highestPreviousClose && previous.close <= highestPreviousClose && current.volume > previous.volume) {
            [results addObject:symbol];
            
            NSLog(@"✅ Breakout: %@ - Close: %.2f > Highest[1,%ld]: %.2f",
                  symbol, current.close, (long)lookbackPeriod, highestPreviousClose);
        }
    }
    
    NSLog(@"🎯 Breakout screener found %lu symbols (lookback: %ld)",
          (unsigned long)results.count, (long)lookbackPeriod);
    
    return [results copy];
}

@end
