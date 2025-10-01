//
//  TechnicalIndicatorHelper.m
//  TradingApp
//

#import "TechnicalIndicatorHelper.h"

@implementation TechnicalIndicatorHelper

#pragma mark - Moving Averages

+ (double)sma:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period
     valueKey:(NSString *)valueKey {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    double sum = 0.0;
    for (NSInteger i = index; i > index - period; i--) {
        sum += [self valueFromBar:bars[i] forKey:valueKey];
    }
    
    return sum / period;
}

+ (double)ema:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    // Calculate initial SMA for first EMA value
    NSInteger startIndex = index - period + 1;
    double initialSMA = [self sma:bars index:startIndex + period - 1 period:period valueKey:@"close"];
    
    // Calculate multiplier
    double multiplier = 2.0 / (period + 1.0);
    
    // Calculate EMA iteratively
    double ema = initialSMA;
    for (NSInteger i = startIndex + period; i <= index; i++) {
        double close = bars[i].close;
        ema = (close - ema) * multiplier + ema;
    }
    
    return ema;
}

+ (double)wma:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    double weightedSum = 0.0;
    double weightTotal = 0.0;
    
    for (NSInteger i = 0; i < period; i++) {
        NSInteger barIndex = index - i;
        double weight = period - i;  // Most recent bar has highest weight
        weightedSum += bars[barIndex].close * weight;
        weightTotal += weight;
    }
    
    return weightedSum / weightTotal;
}

#pragma mark - Momentum Indicators

+ (double)rsi:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period + 1]) {
        return 0.0;
    }
    
    double avgGain = 0.0;
    double avgLoss = 0.0;
    
    // Calculate initial average gain/loss
    for (NSInteger i = index - period + 1; i <= index; i++) {
        double change = bars[i].close - bars[i - 1].close;
        if (change > 0) {
            avgGain += change;
        } else {
            avgLoss += fabs(change);
        }
    }
    
    avgGain /= period;
    avgLoss /= period;
    
    if (avgLoss == 0.0) {
        return 100.0;  // No losses = RSI 100
    }
    
    double rs = avgGain / avgLoss;
    double rsi = 100.0 - (100.0 / (1.0 + rs));
    
    return rsi;
}

+ (double)roc:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    double currentClose = bars[index].close;
    double previousClose = bars[index - period].close;
    
    if (previousClose == 0.0) return 0.0;
    
    return ((currentClose - previousClose) / previousClose) * 100.0;
}

+ (double)momentum:(NSArray<HistoricalBarModel *> *)bars
             index:(NSInteger)index
            period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    return bars[index].close - bars[index - period].close;
}

#pragma mark - Volatility Indicators

+ (double)atr:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    // Calculate initial ATR as average of first 'period' TRs
    double atr = 0.0;
    for (NSInteger i = index - period + 1; i <= index; i++) {
        HistoricalBarModel *current = bars[i];
        HistoricalBarModel *previous = (i > 0) ? bars[i - 1] : nil;
        atr += [self trueRange:current previous:previous];
    }
    atr /= period;
    
    return atr;
}

+ (double)trueRange:(HistoricalBarModel *)current
           previous:(nullable HistoricalBarModel *)previous {
    
    if (!previous) {
        return current.high - current.low;
    }
    
    double hl = current.high - current.low;
    double hc = fabs(current.high - previous.close);
    double lc = fabs(current.low - previous.close);
    
    return fmax(hl, fmax(hc, lc));
}

+ (double)standardDeviation:(NSArray<HistoricalBarModel *> *)bars
                      index:(NSInteger)index
                     period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    // Calculate mean
    double mean = [self sma:bars index:index period:period valueKey:@"close"];
    
    // Calculate variance
    double variance = 0.0;
    for (NSInteger i = index; i > index - period; i--) {
        double diff = bars[i].close - mean;
        variance += diff * diff;
    }
    variance /= period;
    
    return sqrt(variance);
}

#pragma mark - High/Low Helpers

+ (double)highest:(NSArray<HistoricalBarModel *> *)bars
            index:(NSInteger)index
           period:(NSInteger)period
         valueKey:(NSString *)valueKey {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    double highest = -INFINITY;
    for (NSInteger i = index; i > index - period; i--) {
        double value = [self valueFromBar:bars[i] forKey:valueKey];
        if (value > highest) {
            highest = value;
        }
    }
    
    return highest;
}

+ (double)lowest:(NSArray<HistoricalBarModel *> *)bars
           index:(NSInteger)index
          period:(NSInteger)period
        valueKey:(NSString *)valueKey {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    double lowest = INFINITY;
    for (NSInteger i = index; i > index - period; i--) {
        double value = [self valueFromBar:bars[i] forKey:valueKey];
        if (value < lowest) {
            lowest = value;
        }
    }
    
    return lowest;
}

+ (NSInteger)highestBarIndex:(NSArray<HistoricalBarModel *> *)bars
                       index:(NSInteger)index
                      period:(NSInteger)period
                    valueKey:(NSString *)valueKey {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return -1;
    }
    
    double highest = -INFINITY;
    NSInteger highestIndex = -1;
    
    for (NSInteger i = index; i > index - period; i--) {
        double value = [self valueFromBar:bars[i] forKey:valueKey];
        if (value > highest) {
            highest = value;
            highestIndex = i;
        }
    }
    
    return highestIndex;
}

+ (NSInteger)lowestBarIndex:(NSArray<HistoricalBarModel *> *)bars
                      index:(NSInteger)index
                     period:(NSInteger)period
                   valueKey:(NSString *)valueKey {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return -1;
    }
    
    double lowest = INFINITY;
    NSInteger lowestIndex = -1;
    
    for (NSInteger i = index; i > index - period; i--) {
        double value = [self valueFromBar:bars[i] forKey:valueKey];
        if (value < lowest) {
            lowest = value;
            lowestIndex = i;
        }
    }
    
    return lowestIndex;
}

#pragma mark - Pattern Detection

+ (BOOL)isInsideBar:(HistoricalBarModel *)current
           previous:(HistoricalBarModel *)previous {
    return (current.high <= previous.high) && (current.low >= previous.low);
}

+ (BOOL)isOutsideBar:(HistoricalBarModel *)current
            previous:(HistoricalBarModel *)previous {
    return (current.high > previous.high) && (current.low < previous.low);
}

+ (BOOL)isGapUp:(HistoricalBarModel *)current
       previous:(HistoricalBarModel *)previous {
    return current.low >= previous.high;
}

+ (BOOL)isGapDown:(HistoricalBarModel *)current
         previous:(HistoricalBarModel *)previous {
    return current.high <= previous.low;
}

+ (double)gapPercent:(HistoricalBarModel *)current
            previous:(HistoricalBarModel *)previous {
    if (previous.close == 0.0) return 0.0;
    return ((current.open - previous.close) / previous.close) * 100.0;
}

#pragma mark - Volume Analysis

+ (double)dollarVolume:(HistoricalBarModel *)bar {
    return bar.volume * bar.close;
}

+ (double)averageVolume:(NSArray<HistoricalBarModel *> *)bars
                  index:(NSInteger)index
                 period:(NSInteger)period {
    return [self sma:bars index:index period:period valueKey:@"volume"];
}

#pragma mark - Utility Methods

+ (double)valueFromBar:(HistoricalBarModel *)bar
                forKey:(NSString *)key {
    
    if ([key isEqualToString:@"open"]) return bar.open;
    if ([key isEqualToString:@"high"]) return bar.high;
    if ([key isEqualToString:@"low"]) return bar.low;
    if ([key isEqualToString:@"close"]) return bar.close;
    if ([key isEqualToString:@"volume"]) return (double)bar.volume;
    if ([key isEqualToString:@"typical"]) return bar.typicalPrice;
    if ([key isEqualToString:@"range"]) return bar.range;
    
    return 0.0;
}

+ (BOOL)hasSufficientData:(NSArray<HistoricalBarModel *> *)bars
                    index:(NSInteger)index
             requiredBars:(NSInteger)requiredBars {
    
    if (!bars || bars.count == 0) return NO;
    if (index < 0 || index >= bars.count) return NO;
    if (index < requiredBars - 1) return NO;
    
    return YES;
}

@end
