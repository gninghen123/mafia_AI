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
        @"period": @5,          // Standard SMA period
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
                                                                   seriesType:VisualizationTypeLine
                                                                         color:[self defaultColor]];
        
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

// Restituisce un colore in base al valore di 'period'
- (NSColor *)defaultColor {
    NSInteger period = [self.parameters[@"period"] integerValue];
    switch (period) {
        case 5:
            return [NSColor grayColor];
        case 10:
            return [NSColor blueColor];
        case 20:
            return [NSColor yellowColor];
        case 50:
            return [NSColor redColor];
        case 100:
            return [NSColor greenColor];
        case 200:
            return [NSColor grayColor];
        case 500:
            return [NSColor orangeColor];
        default:
            return [NSColor lightGrayColor];
    }
}

- (NSString *)displayDescription {
    NSInteger period = [self.parameters[@"period"] integerValue];
    NSString *source = self.parameters[@"source"] ?: @"close";
    
    return [NSString stringWithFormat:@"SMA(%ld) on %@", (long)period, source];
}

@end
