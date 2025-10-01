// ============================================================================

//
//  WIRScreener.m
//  TradingApp
//

#import "WIRScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation WIRScreener

#pragma mark - Properties

- (NSString *)screenerID {
    return @"wir";
}

- (NSString *)displayName {
    return @"WIR (Within Inside Reversal)";
}

- (NSString *)descriptionText {
    return @"Inside bar after breaking low within lookback period";
}

- (NSInteger)minBarsRequired {
    // Need 20 for SMA + 5 lookback + 1 for previous bar comparison = 26
    NSInteger lookback = [self parameterIntegerForKey:@"lookback_days" defaultValue:5];
    return 20 + lookback + 1;
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSMutableArray *results = [NSMutableArray array];
    
    // Get parameters
    NSInteger lookbackDays = [self parameterIntegerForKey:@"lookback_days" defaultValue:5];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        NSInteger todayIdx = bars.count - 1;
        NSInteger yesterdayIdx = todayIdx - 1;
        
        HistoricalBarModel *today = bars[todayIdx];
        HistoricalBarModel *yesterday = bars[yesterdayIdx];
        
        // Condition 1: Inside bar (high <= prev high AND low >= prev low)
        BOOL insideBar = [TechnicalIndicatorHelper isInsideBar:today previous:yesterday];
        
        // Condition 2: Yesterday was red candle (open >= close)
        BOOL yesterdayRed = yesterday.open >= yesterday.close;
        
        if (!insideBar || !yesterdayRed) continue;
        
        // Condition 3: within(low < low[1], lookbackDays)
        // Check if in the last N days there was a day where low broke previous low
        BOOL foundLowBreak = NO;
        
        NSInteger startIdx = todayIdx;
        NSInteger endIdx = MAX(0, todayIdx - lookbackDays);
        
        for (NSInteger i = startIdx; i > endIdx; i--) {
            if (i == 0) continue;  // Need previous bar for comparison
            
            HistoricalBarModel *bar = bars[i];
            HistoricalBarModel *prevBar = bars[i-1];
            
            if (bar.low < prevBar.low) {
                foundLowBreak = YES;
                break;
            }
        }
        
        if (!foundLowBreak) continue;
        
        // Condition 4: close > SMA(close, 20)
        double sma20 = [TechnicalIndicatorHelper sma:bars
                                                index:todayIdx
                                               period:20
                                             valueKey:@"close"];
        
        if (today.close > sma20) {
            [results addObject:symbol];
        }
    }
    
    return [results copy];
}

@end
