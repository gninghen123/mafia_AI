//
//  PriceVsMAIndicator.m
//  TradingApp
//

#import "PriceVsMAIndicator.h"

@implementation PriceVsMAIndicator

- (CGFloat)calculateScoreForSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars
                        parameters:(NSDictionary *)params {
    
    // Extract parameters
    NSString *maType = params[@"maType"] ?: @"EMA";
    NSInteger maPeriod = [params[@"maPeriod"] integerValue] ?: 10;
    NSArray<NSString *> *pricePoints = params[@"pricePoints"] ?: @[@"close"];
    NSString *condition = params[@"condition"] ?: @"above";
    
    if (!bars || bars.count < maPeriod) {
        NSLog(@"⚠️ PriceVsMA: Insufficient data for %@ (need %ld bars, have %lu)",
              symbol, (long)maPeriod, (unsigned long)bars.count);
        return -100.0;
    }
    
    // Calculate MA
    NSArray<NSNumber *> *maValues = [self calculateMA:maType period:maPeriod forBars:bars];
    
    if (!maValues || maValues.count == 0) {
        NSLog(@"⚠️ PriceVsMA: MA calculation failed for %@", symbol);
        return -100.0;
    }
    
    // Get latest bar and MA value
    HistoricalBarModel *latestBar = bars.lastObject;
    CGFloat maValue = [maValues.lastObject doubleValue];
    
    // Check each price point
    NSInteger satisfiedCount = 0;
    NSInteger totalPoints = pricePoints.count;
    
    for (NSString *pricePoint in pricePoints) {
        CGFloat priceValue = [self getPriceValue:pricePoint fromBar:latestBar];
        BOOL satisfies = NO;
        
        if ([condition isEqualToString:@"above"]) {
            satisfies = (priceValue >= maValue);
        } else {
            satisfies = (priceValue <= maValue);
        }
        
        if (satisfies) {
            satisfiedCount++;
        }
        
        NSLog(@"📊 PriceVsMA %@: %@=%.2f %@ MA(%.2f) → %@",
              symbol, pricePoint, priceValue,
              [condition isEqualToString:@"above"] ? @">=" : @"<=",
              maValue, satisfies ? @"✓" : @"✗");
    }
    
    // Calculate score based on percentage satisfied
    CGFloat ratio = (CGFloat)satisfiedCount / (CGFloat)totalPoints;
    
    CGFloat score;
    if (ratio >= 1.0) {
        score = 100.0;
    } else if (ratio >= 0.75) {
        score = 75.0;
    } else if (ratio >= 0.50) {
        score = 50.0;
    } else if (ratio >= 0.25) {
        score = 25.0;
    } else {
        score = -100.0;
    }
    
    NSLog(@"✅ PriceVsMA %@: %ld/%ld satisfied → score=%.1f",
          symbol, (long)satisfiedCount, (long)totalPoints, score);
    
    return score;
}

#pragma mark - Helper Methods

- (CGFloat)getPriceValue:(NSString *)pricePoint fromBar:(HistoricalBarModel *)bar {
    if ([pricePoint isEqualToString:@"open"]) {
        return bar.open;
    } else if ([pricePoint isEqualToString:@"high"]) {
        return bar.high;
    } else if ([pricePoint isEqualToString:@"low"]) {
        return bar.low;
    } else { // "close" is default
        return bar.close;
    }
}

#pragma mark - MA Calculation (reuse from UNR)

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
            [smaValues addObject:@(0.0)];
            continue;
        }
        
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
    
    CGFloat sum = 0.0;
    for (NSInteger i = 0; i < period; i++) {
        if (i < bars.count) {
            sum += bars[i].close;
            [emaValues addObject:@(0.0)];
        }
    }
    
    if (bars.count < period) {
        return [emaValues copy];
    }
    
    CGFloat ema = sum / period;
    emaValues[period - 1] = @(ema);
    
    for (NSInteger i = period; i < bars.count; i++) {
        ema = (bars[i].close - ema) * multiplier + ema;
        [emaValues addObject:@(ema)];
    }
    
    return [emaValues copy];
}

#pragma mark - Protocol Implementation

- (NSString *)indicatorType {
    return @"PriceVsMA";
}

- (NSString *)displayName {
    return @"Price vs MA";
}

- (NSInteger)minimumBarsRequired {
    return 10; // Default MA period
}

- (NSDictionary *)defaultParameters {
    return @{
        @"maType": @"EMA",
        @"maPeriod": @(10),
        @"pricePoints": @[@"close"],
        @"condition": @"above"
    };
}

- (NSString *)indicatorDescription {
    return @"Compares selected price points (open/high/low/close) with moving average to identify bullish or bearish positioning.";
}

@end
