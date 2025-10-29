//
//  UNRIndicator.m
//  TradingApp
//

#import "UNRIndicator.h"

@implementation UNRIndicator

- (CGFloat)calculateScoreForSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars
                        parameters:(NSDictionary *)params {
    
    // Extract parameters
    NSString *maType = params[@"maType"] ?: @"EMA";
    NSInteger maPeriod = [params[@"maPeriod"] integerValue] ?: 10;
    NSInteger lookbackDays = [params[@"lookbackDays"] integerValue] ?: 5;
    CGFloat sameBarWeight = [params[@"sameBarWeight"] doubleValue] ?: 1.0;
    CGFloat nextBarWeight = [params[@"nextBarWeight"] doubleValue] ?: 0.7;
    
    NSInteger minimumBars = maPeriod + lookbackDays + 1;
    
    if (!bars || bars.count < minimumBars) {
        NSLog(@"⚠️ UNR: Insufficient data for %@ (need %ld bars, have %lu)",
              symbol, (long)minimumBars, (unsigned long)bars.count);
        return 0.0;
    }
    
    // Calculate MA values for all bars
    NSArray<NSNumber *> *maValues = [self calculateMA:maType period:maPeriod forBars:bars];
    
    if (!maValues || maValues.count < bars.count) {
        NSLog(@"⚠️ UNR: MA calculation failed for %@", symbol);
        return 0.0;
    }
    
    // Search for UNR patterns in last N days
    NSInteger searchStart = bars.count - lookbackDays;
    CGFloat bestScore = 0.0;
    NSInteger daysAgo = 0;
    
    for (NSInteger i = searchStart; i < bars.count; i++) {
        HistoricalBarModel *bar = bars[i];
        CGFloat maValue = [maValues[i] doubleValue];
        
        // Check same-bar UNR (low <= MA AND close >= MA)
        if (bar.low <= maValue && bar.close >= maValue) {
            NSInteger barsFromPresent = bars.count - 1 - i;
            CGFloat decayFactor = 1.0 - (barsFromPresent * 0.2); // -20% per day
            decayFactor = MAX(0.0, decayFactor);
            
            CGFloat score = 100.0 * sameBarWeight * decayFactor;
            
            NSLog(@"🎯 UNR (same-bar) %@ at day -%ld: low=%.2f close=%.2f MA=%.2f → score=%.1f",
                  symbol, (long)barsFromPresent, bar.low, bar.close, maValue, score);
            
            if (score > bestScore) {
                bestScore = score;
                daysAgo = barsFromPresent;
            }
        }
        
        // Check next-bar UNR (low <= MA today, close >= MA tomorrow)
        if (i < bars.count - 1) {
            HistoricalBarModel *nextBar = bars[i + 1];
            CGFloat nextMAValue = [maValues[i + 1] doubleValue];
            
            if (bar.low <= maValue && nextBar.close >= nextMAValue) {
                NSInteger barsFromPresent = bars.count - 1 - i;
                CGFloat decayFactor = 1.0 - (barsFromPresent * 0.2);
                decayFactor = MAX(0.0, decayFactor);
                
                CGFloat score = 100.0 * nextBarWeight * decayFactor;
                
                NSLog(@"🎯 UNR (next-bar) %@ at day -%ld: low=%.2f, next_close=%.2f MA=%.2f → score=%.1f",
                      symbol, (long)barsFromPresent, bar.low, nextBar.close, maValue, score);
                
                if (score > bestScore) {
                    bestScore = score;
                    daysAgo = barsFromPresent;
                }
            }
        }
    }
    
    if (bestScore > 0) {
        NSLog(@"✅ UNR %@: Best score=%.1f (from %ld days ago)", symbol, bestScore, (long)daysAgo);
    } else {
        NSLog(@"⚠️ UNR %@: No UNR pattern found", symbol);
    }
    
    return bestScore;
}

#pragma mark - MA Calculation

- (NSArray<NSNumber *> *)calculateMA:(NSString *)type
                              period:(NSInteger)period
                             forBars:(NSArray<HistoricalBarModel *> *)bars {
    
    if ([type isEqualToString:@"EMA"]) {
        return [self calculateEMA:period forBars:bars];
    } else {
        return [self calculateSMA:period forBars:bars];
    }
}

- (NSArray<NSNumber *> *)calculateSMA:(NSInteger)period
                              forBars:(NSArray<HistoricalBarModel *> *)bars {
    
    NSMutableArray<NSNumber *> *smaValues = [NSMutableArray array];
    
    for (NSInteger i = 0; i < bars.count; i++) {
        if (i < period - 1) {
            // Not enough data yet
            [smaValues addObject:@(0.0)];
            continue;
        }
        
        // Calculate SMA
        CGFloat sum = 0.0;
        for (NSInteger j = i - period + 1; j <= i; j++) {
            sum += bars[j].close;
        }
        CGFloat sma = sum / period;
        [smaValues addObject:@(sma)];
    }
    
    return [smaValues copy];
}

- (NSArray<NSNumber *> *)calculateEMA:(NSInteger)period
                              forBars:(NSArray<HistoricalBarModel *> *)bars {
    
    NSMutableArray<NSNumber *> *emaValues = [NSMutableArray array];
    CGFloat multiplier = 2.0 / (period + 1.0);
    
    // First EMA = SMA of first period bars
    CGFloat sum = 0.0;
    for (NSInteger i = 0; i < period; i++) {
        if (i < bars.count) {
            sum += bars[i].close;
            [emaValues addObject:@(0.0)]; // Placeholder
        }
    }
    
    if (bars.count < period) {
        return [emaValues copy];
    }
    
    CGFloat ema = sum / period;
    emaValues[period - 1] = @(ema);
    
    // Calculate subsequent EMAs
    for (NSInteger i = period; i < bars.count; i++) {
        ema = (bars[i].close - ema) * multiplier + ema;
        [emaValues addObject:@(ema)];
    }
    
    return [emaValues copy];
}

#pragma mark - Protocol Implementation

- (NSString *)indicatorType {
    return @"UNR";
}

- (NSString *)displayName {
    return @"UNR";
}

- (NSInteger)minimumBarsRequired {
    return 16; // Default: 10 (EMA) + 5 (lookback) + 1
}

- (NSDictionary *)defaultParameters {
    return @{
        @"maType": @"EMA",
        @"maPeriod": @(10),
        @"lookbackDays": @(5),
        @"sameBarWeight": @(1.0),
        @"nextBarWeight": @(0.7)
    };
}

- (NSString *)indicatorDescription {
    return @"Identifies Undercut and Reclaim patterns where price dips below MA then closes above it, signaling potential reversal.";
}

@end
