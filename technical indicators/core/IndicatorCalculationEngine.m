//
// IndicatorCalculationEngine.m
//

#import "IndicatorCalculationEngine.h"

@implementation IndicatorCalculationEngine

#pragma mark - Moving Averages

+ (NSArray<NSNumber *> *)sma:(NSArray<NSNumber *> *)values period:(NSInteger)period {
    if (!values || values.count == 0 || period <= 0) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:values.count];
    
    // Pad initial values with NaN
    for (NSInteger i = 0; i < period - 1 && i < values.count; i++) {
        [result addObject:@(NAN)];
    }
    
    // Calculate SMA values
    for (NSInteger i = period - 1; i < values.count; i++) {
        double sum = 0.0;
        NSInteger validCount = 0;
        
        for (NSInteger j = i - period + 1; j <= i; j++) {
            double value = [values[j] doubleValue];
            if ([self isValidNumber:value]) {
                sum += value;
                validCount++;
            }
        }
        
        if (validCount >= period * 0.8) {  // Require at least 80% valid values
            [result addObject:@(sum / validCount)];
        } else {
            [result addObject:@(NAN)];
        }
    }
    
    return [result copy];
}

+ (NSArray<NSNumber *> *)ema:(NSArray<NSNumber *> *)values period:(NSInteger)period {
    if (!values || values.count == 0 || period <= 0) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:values.count];
    double multiplier = 2.0 / (period + 1.0);
    double ema = NAN;
    
    for (NSInteger i = 0; i < values.count; i++) {
        double currentValue = [values[i] doubleValue];
        
        if (![self isValidNumber:currentValue]) {
            [result addObject:@(NAN)];
            continue;
        }
        
        if (isnan(ema)) {
            // First valid value becomes initial EMA
            ema = currentValue;
        } else {
            // EMA formula: (Current * multiplier) + (Previous EMA * (1 - multiplier))
            ema = (currentValue * multiplier) + (ema * (1.0 - multiplier));
        }
        
        [result addObject:@(ema)];
    }
    
    return [result copy];
}

+ (NSArray<NSNumber *> *)wma:(NSArray<NSNumber *> *)values period:(NSInteger)period {
    if (!values || values.count == 0 || period <= 0) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:values.count];
    
    // Pad initial values with NaN
    for (NSInteger i = 0; i < period - 1 && i < values.count; i++) {
        [result addObject:@(NAN)];
    }
    
    // Calculate WMA values
    NSInteger totalWeight = period * (period + 1) / 2;  // Sum of 1+2+...+period
    
    for (NSInteger i = period - 1; i < values.count; i++) {
        double weightedSum = 0.0;
        NSInteger validCount = 0;
        
        for (NSInteger j = 0; j < period; j++) {
            double value = [values[i - j] doubleValue];
            if ([self isValidNumber:value]) {
                NSInteger weight = period - j;  // Most recent gets highest weight
                weightedSum += value * weight;
                validCount++;
            }
        }
        
        if (validCount >= period * 0.8) {
            [result addObject:@(weightedSum / totalWeight)];
        } else {
            [result addObject:@(NAN)];
        }
    }
    
    return [result copy];
}

#pragma mark - Momentum Indicators

+ (NSArray<NSNumber *> *)rsi:(NSArray<NSNumber *> *)closes period:(NSInteger)period {
    if (!closes || closes.count < 2 || period <= 0) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:closes.count];
    NSMutableArray<NSNumber *> *gains = [[NSMutableArray alloc] init];
    NSMutableArray<NSNumber *> *losses = [[NSMutableArray alloc] init];
    
    // Calculate price changes
    [result addObject:@(NAN)];  // First value has no previous price
    
    for (NSInteger i = 1; i < closes.count; i++) {
        double current = [closes[i] doubleValue];
        double previous = [closes[i-1] doubleValue];
        
        if ([self isValidNumber:current] && [self isValidNumber:previous]) {
            double change = current - previous;
            [gains addObject:@(change > 0 ? change : 0.0)];
            [losses addObject:@(change < 0 ? -change : 0.0)];
        } else {
            [gains addObject:@(0.0)];
            [losses addObject:@(0.0)];
        }
    }
    
    // Calculate RSI using EMA of gains and losses
    NSArray<NSNumber *> *avgGains = [self ema:gains period:period];
    NSArray<NSNumber *> *avgLosses = [self ema:losses period:period];
    
    for (NSInteger i = 1; i < closes.count; i++) {
        if (i-1 < avgGains.count && i-1 < avgLosses.count) {
            double avgGain = [avgGains[i-1] doubleValue];
            double avgLoss = [avgLosses[i-1] doubleValue];
            
            if ([self isValidNumber:avgGain] && [self isValidNumber:avgLoss] && avgLoss > 0) {
                double rs = avgGain / avgLoss;
                double rsi = 100.0 - (100.0 / (1.0 + rs));
                [result addObject:@(rsi)];
            } else if (avgLoss == 0 && avgGain > 0) {
                [result addObject:@(100.0)];  // All gains, no losses
            } else {
                [result addObject:@(50.0)];   // Default middle value
            }
        } else {
            [result addObject:@(NAN)];
        }
    }
    
    return [result copy];
}

+ (NSArray<NSNumber *> *)roc:(NSArray<NSNumber *> *)values period:(NSInteger)period {
    if (!values || values.count <= period || period <= 0) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:values.count];
    
    // Pad initial values
    for (NSInteger i = 0; i < period && i < values.count; i++) {
        [result addObject:@(NAN)];
    }
    
    // Calculate ROC
    for (NSInteger i = period; i < values.count; i++) {
        double current = [values[i] doubleValue];
        double previous = [values[i - period] doubleValue];
        
        if ([self isValidNumber:current] && [self isValidNumber:previous] && previous != 0) {
            double roc = [self percentageChange:current previous:previous];
            [result addObject:@(roc)];
        } else {
            [result addObject:@(NAN)];
        }
    }
    
    return [result copy];
}

#pragma mark - Volatility Indicators

+ (NSArray<NSNumber *> *)atr:(NSArray<HistoricalBarModel *> *)bars period:(NSInteger)period {
    if (!bars || bars.count < 2 || period <= 0) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *trueRanges = [[NSMutableArray alloc] init];
    
    // Calculate True Range for each bar
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBarModel *current = bars[i];
        HistoricalBarModel *previous = (i > 0) ? bars[i-1] : nil;
        
        double tr = [self trueRange:current previous:previous];
        [trueRanges addObject:@(tr)];
    }
    
    // ATR is EMA of True Range
    return [self ema:trueRanges period:period];
}

+ (double)trueRange:(HistoricalBarModel *)current previous:(nullable HistoricalBarModel *)previous {
    double high = current.high;
    double low = current.low;
    double prevClose = previous ? previous.close : current.close;
    
    double range1 = high - low;                    // Current high - low
    double range2 = fabs(high - prevClose);       // Current high - previous close
    double range3 = fabs(low - prevClose);        // Current low - previous close
    
    return MAX(range1, MAX(range2, range3));
}

#pragma mark - Statistical Functions

+ (NSArray<NSNumber *> *)stdev:(NSArray<NSNumber *> *)values period:(NSInteger)period {
    if (!values || values.count == 0 || period <= 1) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:values.count];
    
    // Pad initial values
    for (NSInteger i = 0; i < period - 1 && i < values.count; i++) {
        [result addObject:@(NAN)];
    }
    
    // Calculate rolling standard deviation
    for (NSInteger i = period - 1; i < values.count; i++) {
        double sum = 0.0;
        NSInteger validCount = 0;
        
        // Calculate mean
        for (NSInteger j = i - period + 1; j <= i; j++) {
            double value = [values[j] doubleValue];
            if ([self isValidNumber:value]) {
                sum += value;
                validCount++;
            }
        }
        
        if (validCount < period * 0.8) {
            [result addObject:@(NAN)];
            continue;
        }
        
        double mean = sum / validCount;
        double sumSquaredDiffs = 0.0;
        
        // Calculate variance
        for (NSInteger j = i - period + 1; j <= i; j++) {
            double value = [values[j] doubleValue];
            if ([self isValidNumber:value]) {
                double diff = value - mean;
                sumSquaredDiffs += diff * diff;
            }
        }
        
        double variance = sumSquaredDiffs / (validCount - 1);  // Sample variance
        double stdev = sqrt(variance);
        
        [result addObject:@(stdev)];
    }
    
    return [result copy];
}

+ (NSArray<NSNumber *> *)correlation:(NSArray<NSNumber *> *)valuesX
                             valuesY:(NSArray<NSNumber *> *)valuesY
                              period:(NSInteger)period {
    if (!valuesX || !valuesY || valuesX.count != valuesY.count || period <= 1) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:valuesX.count];
    
    // Pad initial values
    for (NSInteger i = 0; i < period - 1 && i < valuesX.count; i++) {
        [result addObject:@(NAN)];
    }
    
    // Calculate rolling correlation
    for (NSInteger i = period - 1; i < valuesX.count; i++) {
        double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0, sumY2 = 0.0;
        NSInteger validCount = 0;
        
        for (NSInteger j = i - period + 1; j <= i; j++) {
            double x = [valuesX[j] doubleValue];
            double y = [valuesY[j] doubleValue];
            
            if ([self isValidNumber:x] && [self isValidNumber:y]) {
                sumX += x;
                sumY += y;
                sumXY += x * y;
                sumX2 += x * x;
                sumY2 += y * y;
                validCount++;
            }
        }
        
        if (validCount < period * 0.8) {
            [result addObject:@(NAN)];
            continue;
        }
        
        double n = validCount;
        double numerator = n * sumXY - sumX * sumY;
        double denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
        
        if (denominator != 0) {
            double correlation = numerator / denominator;
            [result addObject:@(correlation)];
        } else {
            [result addObject:@(0.0)];
        }
    }
    
    return [result copy];
}

#pragma mark - Utility Functions

+ (NSArray<NSNumber *> *)extractPriceSeries:(NSArray<HistoricalBarModel *> *)bars
                                  priceType:(NSString *)priceType {
    if (!bars || bars.count == 0) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:bars.count];
    
    for (HistoricalBarModel *bar in bars) {
        double value = 0.0;
        
        if ([priceType isEqualToString:@"open"]) {
            value = bar.open;
        } else if ([priceType isEqualToString:@"high"]) {
            value = bar.high;
        } else if ([priceType isEqualToString:@"low"]) {
            value = bar.low;
        } else if ([priceType isEqualToString:@"close"]) {
            value = bar.close;
        } else if ([priceType isEqualToString:@"volume"]) {
            value = bar.volume;
        } else {
            // Default to close
            value = bar.close;
        }
        
        [result addObject:@(value)];
    }
    
    return [result copy];
}

+ (double)percentageChange:(double)current previous:(double)previous {
    if (previous == 0.0) {
        return 0.0;
    }
    return ((current - previous) / previous) * 100.0;
}

+ (BOOL)isValidNumber:(double)value {
    return !isnan(value) && !isinf(value);
}

+ (NSArray<NSNumber *> *)nanArrayWithCount:(NSInteger)count {
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        [result addObject:@(NAN)];
    }
    return [result copy];
}

@end
