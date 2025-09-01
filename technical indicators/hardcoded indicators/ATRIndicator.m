//
// ATRIndicator.m
//

#import "ATRIndicator.h"
#import "IndicatorCalculationEngine.h"

@implementation ATRIndicator

#pragma mark - Abstract Method Implementations

- (NSString *)name {
    return @"Average True Range";
}

- (NSString *)shortName {
    return @"ATR";
}

+ (NSDictionary<NSString *, id> *)defaultParameters {
    return @{
        @"period": @14          // Standard ATR period
    };
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    return @{
        @"period": @{
            @"type": @"integer",
            @"min": @1,
            @"max": @100,
            @"description": @"ATR period (1-100)"
        }
    };
}

- (NSInteger)minimumBarsRequired {
    NSInteger period = [self.parameters[@"period"] integerValue];
    return MAX(2, period);  // ATR needs at least 2 bars for True Range
}

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    // Reset state
    [self reset];
    
    // Validate input
    if (![self canCalculateWithBars:bars]) {
        self.lastError = [NSError errorWithDomain:@"ATRIndicator"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Insufficient bars for ATR calculation"}];
        return;
    }
    
    // Get parameters
    NSInteger period = [self.parameters[@"period"] integerValue];
    
    // Calculate ATR using the calculation engine
    NSArray<NSNumber *> *atrValues = [IndicatorCalculationEngine atr:bars period:period];
    if (!atrValues || atrValues.count != bars.count) {
        self.lastError = [NSError errorWithDomain:@"ATRIndicator"
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey: @"ATR calculation failed"}];
        return;
    }
    
    // Create output series
    NSMutableArray<IndicatorDataModel *> *outputData = [[NSMutableArray alloc] initWithCapacity:bars.count];
    NSString *seriesName = [NSString stringWithFormat:@"ATR(%ld)", (long)period];
    
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBarModel *bar = bars[i];
        double atrValue = [atrValues[i] doubleValue];
        
        IndicatorDataModel *dataPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                         value:atrValue
                                                                    seriesName:seriesName
                                                                    seriesType:IndicatorSeriesTypeLine
                                                                         color:[self atrColor]];
        
        dataPoint.anchorValue = 0.0;  // ATR starts from 0
        dataPoint.isSignal = NO;
        
        [outputData addObject:dataPoint];
    }
    
    // Set results
    self.outputSeries = [outputData copy];
    self.isCalculated = YES;
    self.lastError = nil;
    
    NSLog(@"✅ ATRIndicator: Calculated ATR(%ld) for %lu bars", (long)period, (unsigned long)bars.count);
}

#pragma mark - ATR-specific Methods

- (double)currentATRValue {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count == 0) {
        return NAN;
    }
    
    IndicatorDataModel *lastPoint = [self.outputSeries lastObject];
    return lastPoint.value;
}

- (NSArray<NSNumber *> *)atrValues {
    if (!self.isCalculated || !self.outputSeries) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *values = [[NSMutableArray alloc] initWithCapacity:self.outputSeries.count];
    for (IndicatorDataModel *dataPoint in self.outputSeries) {
        [values addObject:@(dataPoint.value)];
    }
    
    return [values copy];
}

- (IndicatorDataModel *)latestDataPoint {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count == 0) {
        return nil;
    }
    
    return [self.outputSeries lastObject];
}

- (double)atrPercentage:(double)currentPrice {
    double atr = [self currentATRValue];
    if (![IndicatorCalculationEngine isValidNumber:atr] || currentPrice <= 0) {
        return NAN;
    }
    return (atr / currentPrice) * 100.0;
}

- (BOOL)isHighVolatility:(double)threshold {
    double atr = [self currentATRValue];
    return [IndicatorCalculationEngine isValidNumber:atr] && atr > threshold;
}

- (BOOL)isLowVolatility:(double)threshold {
    double atr = [self currentATRValue];
    return [IndicatorCalculationEngine isValidNumber:atr] && atr < threshold;
}

#pragma mark - Display Properties

- (NSColor *)atrColor {
    return [NSColor colorWithRed:1.0 green:0.4 blue:0.0 alpha:1.0]; // Dark orange
}

- (NSString *)displayDescription {
    NSInteger period = [self.parameters[@"period"] integerValue];
    return [NSString stringWithFormat:@"ATR(%ld)", (long)period];
}

@end
