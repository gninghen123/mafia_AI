//
//  AscendingLowsIndicator.m
//  TradingApp
//

#import "AscendingLowsIndicator.h"

@implementation AscendingLowsIndicator

- (CGFloat)calculateScoreForSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars
                        parameters:(NSDictionary *)params {
    
    NSInteger lookbackDays = [params[@"lookbackDays"] integerValue] ?: 5;
    
    if (!bars || bars.count < lookbackDays) {
        NSLog(@"⚠️ AscendingLows: Insufficient data for %@ (need %ld bars, have %lu)",
              symbol, (long)lookbackDays, (unsigned long)bars.count);
        return -100.0;
    }
    
    // Get last N bars
    NSInteger startIndex = bars.count - lookbackDays;
    NSArray<HistoricalBarModel *> *recentBars = [bars subarrayWithRange:NSMakeRange(startIndex, lookbackDays)];
    
    // Count ascending lows
    NSInteger ascendingCount = 0;
    
    for (NSInteger i = 1; i < recentBars.count; i++) {
        HistoricalBarModel *currentBar = recentBars[i];
        HistoricalBarModel *previousBar = recentBars[i - 1];
        
        if (currentBar.low > previousBar.low) {
            ascendingCount++;
        }
    }
    
    NSLog(@"📈 AscendingLows %@: %ld/%ld ascending",
          symbol, (long)ascendingCount, (long)(lookbackDays - 1));
    
    // Graduated scoring
    // Note: lookbackDays=5 means 4 comparisons (5 bars → 4 transitions)
    NSInteger maxComparisons = lookbackDays - 1;
    
    if (ascendingCount >= maxComparisons) {
        return 100.0;  // All ascending
    } else if (ascendingCount >= (maxComparisons - 1)) {
        return 75.0;   // 4/5 or 3/4
    } else if (ascendingCount >= (maxComparisons - 2)) {
        return 50.0;   // 3/5 or 2/4
    } else if (ascendingCount >= 2) {
        return 25.0;   // 2/5 or better
    } else {
        return -100.0; // Less than 2 ascending
    }
}

- (NSString *)indicatorType {
    return @"AscendingLows";
}

- (NSString *)displayName {
    return @"Ascending Lows";
}

- (NSInteger)minimumBarsRequired {
    return 5;
}

- (NSDictionary *)defaultParameters {
    return @{
        @"lookbackDays": @(5)
    };
}

- (NSString *)indicatorDescription {
    return @"Identifies uptrends by checking if recent lows are consecutively ascending. Strong signal of bullish momentum.";
}

@end
