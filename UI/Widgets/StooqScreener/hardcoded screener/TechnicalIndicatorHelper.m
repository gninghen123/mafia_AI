//
//  TechnicalIndicatorHelper.m
//  TradingApp
//
//  NOTA IMPORTANTE: Tutti i metodi assumono array ASCENDENTI [vecchio → recente]
//  - index = 0 significa "barra più recente" (ultima nell'array)
//  - index = 1 significa "penultima barra"
//  - Gli indici vengono convertiti internamente: realIndex = bars.count - 1 - index
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
    
    // Converti index: 0 = ultima barra, 1 = penultima, ecc.
    NSInteger startIndex = bars.count - 1 - index;
    NSInteger endIndex = startIndex - period + 1;
    
    double sum = 0.0;
    for (NSInteger i = startIndex; i >= endIndex; i--) {
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
    
    // Converti index
    NSInteger targetIndex = bars.count - 1 - index;
    NSInteger startIndex = targetIndex - period + 1;
    
    // Calculate initial SMA
    double initialSMA = [self sma:bars index:index + period - 1 period:period valueKey:@"close"];
    
    // Calculate multiplier
    double multiplier = 2.0 / (period + 1.0);
    
    // Calculate EMA iteratively from startIndex to targetIndex
    double ema = initialSMA;
    for (NSInteger i = startIndex; i <= targetIndex; i++) {
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
    
    // Converti index
    NSInteger startIndex = bars.count - 1 - index;
    
    for (NSInteger i = 0; i < period; i++) {
        NSInteger barIndex = startIndex - i;
        double weight = period - i;  // Most recent bar has highest weight
        weightedSum += bars[barIndex].close * weight;
        weightTotal += weight;
    }
    
    return weightedSum / weightTotal;
}

+ (double)wilders:(NSArray<HistoricalBarModel *> *)bars
            index:(NSInteger)index
           period:(NSInteger)period
         valueKey:(NSString *)valueKey {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    // Converti index
    NSInteger targetIndex = bars.count - 1 - index;
    NSInteger startIndex = targetIndex - period + 1;
    
    // Calculate initial SMA for first Wilders value
    double sum = 0.0;
    for (NSInteger i = targetIndex; i >= startIndex; i--) {
        sum += [self valueFromBar:bars[i] forKey:valueKey];
    }
    double wilders = sum / (double)period;
    
    // Apply Wilders smoothing formula: SMMA[i] = (SMMA[i-1] * (period-1) + value[i]) / period
    // Moving forward from oldest to newest for iterative calculation
    for (NSInteger i = startIndex; i <= targetIndex; i++) {
        double value = [self valueFromBar:bars[i] forKey:valueKey];
        wilders = (wilders * (period - 1) + value) / (double)period;
    }
    
    return wilders;
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
    
    // Converti index
    NSInteger targetIndex = bars.count - 1 - index;
    NSInteger startIndex = targetIndex - period + 1;
    
    // Calculate initial average gain/loss
    for (NSInteger i = startIndex; i <= targetIndex; i++) {
        if (i > 0) {
            double change = bars[i].close - bars[i - 1].close;
            if (change > 0) {
                avgGain += change;
            } else {
                avgLoss += fabs(change);
            }
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
    
    // Converti index
    NSInteger currentIndex = bars.count - 1 - index;
    NSInteger previousIndex = currentIndex - period;
    
    double currentClose = bars[currentIndex].close;
    double previousClose = bars[previousIndex].close;
    
    if (previousClose == 0.0) return 0.0;
    
    return ((currentClose - previousClose) / previousClose) * 100.0;
}

+ (double)momentum:(NSArray<HistoricalBarModel *> *)bars
             index:(NSInteger)index
            period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    // Converti index
    NSInteger currentIndex = bars.count - 1 - index;
    NSInteger previousIndex = currentIndex - period;
    
    return bars[currentIndex].close - bars[previousIndex].close;
}

#pragma mark - Volatility Indicators

+ (double)atr:(NSArray<HistoricalBarModel *> *)bars
        index:(NSInteger)index
       period:(NSInteger)period {
    
    if (![self hasSufficientData:bars index:index requiredBars:period]) {
        return 0.0;
    }
    
    // Converti index
    NSInteger targetIndex = bars.count - 1 - index;
    NSInteger startIndex = targetIndex - period + 1;
    
    // Calculate initial ATR as average of first 'period' TRs
    double atr = 0.0;
    for (NSInteger i = startIndex; i <= targetIndex; i++) {
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
    
    // Converti index
    NSInteger startIndex = bars.count - 1 - index;
    NSInteger endIndex = startIndex - period + 1;
    
    // Calculate variance
    double variance = 0.0;
    for (NSInteger i = startIndex; i >= endIndex; i--) {
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
    
    // Converti index: 0 = ultima barra, 1 = penultima
    NSInteger startIndex = bars.count - 1 - index;
    NSInteger endIndex = startIndex - period + 1;
    
    if (endIndex < 0) {
        endIndex = 0;
    }
    
    // Loop da startIndex a endIndex (indietro nel tempo)
    for (NSInteger i = startIndex; i >= endIndex; i--) {
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
    
    NSInteger startIndex = bars.count - 1 - index;
    NSInteger endIndex = startIndex - period + 1;
    
    if (endIndex < 0) {
        endIndex = 0;
    }
    
    for (NSInteger i = startIndex; i >= endIndex; i--) {
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
    
    NSInteger startIndex = bars.count - 1 - index;
    NSInteger endIndex = startIndex - period + 1;
    
    if (endIndex < 0) {
        endIndex = 0;
    }
    
    for (NSInteger i = startIndex; i >= endIndex; i--) {
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
    
    NSInteger startIndex = bars.count - 1 - index;
    NSInteger endIndex = startIndex - period + 1;
    
    if (endIndex < 0) {
        endIndex = 0;
    }
    
    for (NSInteger i = startIndex; i >= endIndex; i--) {
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
    if (index < 0) return NO;
    
    // Converti index per verificare se abbiamo abbastanza dati
    NSInteger realIndex = bars.count - 1 - index;
    
    // Verifica che realIndex sia valido e che ci siano abbastanza barre prima
    if (realIndex >= bars.count) return NO;
    if (realIndex - requiredBars + 1 < 0) return NO;
    
    return YES;
}

@end
