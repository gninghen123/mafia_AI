//
// SMAIndicator.m
//

#import "SMAIndicator.h"
#import "IndicatorCalculationEngine.h"

@implementation SMAIndicator

#pragma mark - Abstract Method Implementations

// Override name and shortName methods from base class
- (NSString *)name {
    return @"Simple Moving Average";
}

- (NSString *)shortName {
    return @"SMA";
}

+ (NSDictionary<NSString *, id> *)defaultParameters {
    return @{
        @"period": @20,          // Standard SMA period
        @"source": @"close"      // Price source (open/high/low/close)
    };
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    return @{
        @"period": @{
            @"type": @"integer",
            @"min": @1,
            @"max": @500,
            @"description": @"SMA period (1-500)"
        },
        @"source": @{
            @"type": @"string",
            @"values": @[@"open", @"high", @"low", @"close"],
            @"description": @"Price source for SMA calculation"
        }
    };
}

- (NSInteger)minimumBarsRequired {
    NSInteger period = [self.parameters[@"period"] integerValue];
    return MAX(1, period);  // SMA needs at least 'period' bars for meaningful values
}

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    // Reset state
    [self reset];
    
    // Validate input
    if (![self canCalculateWithBars:bars]) {
        self.lastError = [NSError errorWithDomain:@"SMAIndicator"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Insufficient bars for SMA calculation"}];
        return;
    }
    
    // Get parameters
    NSInteger period = [self.parameters[@"period"] integerValue];
    NSString *source = self.parameters[@"source"] ?: @"close";
    
    // Validate parameters
    if (period <= 0 || period > 500) {
        self.lastError = [NSError errorWithDomain:@"SMAIndicator"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey:
                                               [NSString stringWithFormat:@"Invalid period: %ld", (long)period]}];
        return;
    }
    
    // Extract price series from bars
    NSArray<NSNumber *> *prices = [IndicatorCalculationEngine extractPriceSeries:bars priceType:source];
    if (!prices || prices.count == 0) {
        self.lastError = [NSError errorWithDomain:@"SMAIndicator"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract price series"}];
        return;
    }
    
    // Calculate SMA using the calculation engine
    NSArray<NSNumber *> *smaValues = [IndicatorCalculationEngine sma:prices period:period];
    if (!smaValues || smaValues.count != bars.count) {
        self.lastError = [NSError errorWithDomain:@"SMAIndicator"
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey: @"SMA calculation failed"}];
        return;
    }
    
    // Create output series
    NSMutableArray<IndicatorDataModel *> *outputData = [[NSMutableArray alloc] initWithCapacity:bars.count];
    NSString *seriesName = [NSString stringWithFormat:@"SMA(%ld)", (long)period];
    
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBarModel *bar = bars[i];
        double smaValue = [smaValues[i] doubleValue];
        
        IndicatorDataModel *dataPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                         value:smaValue
                                                                    seriesName:seriesName
                                                                    seriesType:IndicatorSeriesTypeLine
                                                                         color:[self smaColor]];
        
        dataPoint.anchorValue = smaValue;
        dataPoint.isSignal = NO;
        
        [outputData addObject:dataPoint];
    }
    
    // Set results
    self.outputSeries = [outputData copy];
    self.isCalculated = YES;
    self.lastError = nil;
    
    NSLog(@"✅ SMAIndicator: Calculated SMA(%ld) for %lu bars using %@ prices",
          (long)period, (unsigned long)bars.count, source);
}

#pragma mark - SMA-specific Methods

- (double)currentSMAValue {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count == 0) {
        return NAN;
    }
    
    IndicatorDataModel *lastPoint = [self.outputSeries lastObject];
    return lastPoint.value;
}

- (NSArray<NSNumber *> *)smaValues {
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

#pragma mark - Display Properties

- (NSColor *)smaColor {
    // Standard SMA color - blue for simple moving average
    return [NSColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0]; // Light blue
}

- (NSString *)displayDescription {
    NSInteger period = [self.parameters[@"period"] integerValue];
    NSString *source = self.parameters[@"source"] ?: @"close";
    
    return [NSString stringWithFormat:@"SMA(%ld) on %@", (long)period, source];
}

@end
