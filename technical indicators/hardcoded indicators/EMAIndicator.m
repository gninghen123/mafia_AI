//
// EMAIndicator.m
//

#import "EMAIndicator.h"
#import "IndicatorCalculationEngine.h"

@implementation EMAIndicator

#pragma mark - Initialization

- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {
    self = [super initWithParameters:parameters];
    if (self) {
        // EMAIndicator specific initialization
        // Note: name and shortName are implemented as methods, not properties
    }
    return self;
}

#pragma mark - Abstract Method Implementations

// Override name and shortName methods from base class
- (NSString *)name {
    return @"Exponential Moving Average";
}

- (NSString *)shortName {
    return @"EMA";
}

+ (NSDictionary<NSString *, id> *)defaultParameters {
    return @{
        @"period": @10,          // Standard EMA period
        @"source": @"close"      // Price source (open/high/low/close)
    };
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    return @{
        @"period": @{
            @"type": @"integer",
            @"min": @1,
            @"max": @500,
            @"description": @"EMA period (1-500)"
        },
        @"source": @{
            @"type": @"string",
            @"values": @[@"open", @"high", @"low", @"close"],
            @"description": @"Price source for EMA calculation"
        }
    };
}

- (NSInteger)minimumBarsRequired {
    NSInteger period = [self.parameters[@"period"] integerValue];
    // EMA can start calculating from the first bar, but meaningful values after period
    return MAX(1, period);
}

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    // Reset state
    [self reset];
    
    // Validate input
    if (![self canCalculateWithBars:bars]) {
        self.lastError = [NSError errorWithDomain:@"EMAIndicator"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Insufficient bars for EMA calculation"}];
        return;
    }
    
    // Get parameters
    NSInteger period = [self.parameters[@"period"] integerValue];
    NSString *source = self.parameters[@"source"] ?: @"close";
    
    // Validate parameters
    if (period <= 0 || period > 500) {
        self.lastError = [NSError errorWithDomain:@"EMAIndicator"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey:
                                               [NSString stringWithFormat:@"Invalid period: %ld", (long)period]}];
        return;
    }
    
    // Extract price series from bars
    NSArray<NSNumber *> *prices = [IndicatorCalculationEngine extractPriceSeries:bars priceType:source];
    if (!prices || prices.count == 0) {
        self.lastError = [NSError errorWithDomain:@"EMAIndicator"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract price series"}];
        return;
    }
    
    // Calculate EMA using the calculation engine
    NSArray<NSNumber *> *emaValues = [IndicatorCalculationEngine ema:prices period:period];
    if (!emaValues || emaValues.count != bars.count) {
        self.lastError = [NSError errorWithDomain:@"EMAIndicator"
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey: @"EMA calculation failed"}];
        return;
    }
    
    // Create output series
    NSMutableArray<IndicatorDataModel *> *outputData = [[NSMutableArray alloc] initWithCapacity:bars.count];
    NSString *seriesName = [NSString stringWithFormat:@"EMA(%ld)", (long)period];
    
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBarModel *bar = bars[i];
        double emaValue = [emaValues[i] doubleValue];
        
        IndicatorDataModel *dataPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                         value:emaValue
                                                                    seriesName:seriesName
                                                                   seriesType:VisualizationTypeLine
                                                                         color:[self emaColor]];
        
        // For EMA, we can use the EMA value itself as anchor (for overlay on price chart)
        dataPoint.anchorValue = emaValue;
        dataPoint.isSignal = NO;
        
        [outputData addObject:dataPoint];
    }
    
    // Set results
    self.outputSeries = [outputData copy];
    self.isCalculated = YES;
    self.lastError = nil;
    
    NSLog(@"✅ EMAIndicator: Calculated EMA(%ld) for %lu bars using %@ prices",
          (long)period, (unsigned long)bars.count, source);
}

#pragma mark - Parameter Validation Override

- (BOOL)validateParameters:(NSDictionary<NSString *, id> *)parameters error:(NSError **)error {
    // Call parent validation first
    if (![super validateParameters:parameters error:error]) {
        return NO;
    }
    
    // EMA-specific validation
    NSNumber *periodNumber = parameters[@"period"];
    NSString *source = parameters[@"source"];
    
    // Validate period
    if (!periodNumber || ![periodNumber isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"EMAIndicator"
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Period must be a number"}];
        }
        return NO;
    }
    
    NSInteger period = [periodNumber integerValue];
    if (period < 1 || period > 500) {
        if (error) {
            *error = [NSError errorWithDomain:@"EMAIndicator"
                                         code:2002
                                     userInfo:@{NSLocalizedDescriptionKey:
                                               [NSString stringWithFormat:@"Period must be between 1 and 500, got %ld", (long)period]}];
        }
        return NO;
    }
    
    // Validate source
    if (source) {
        NSArray *validSources = @[@"open", @"high", @"low", @"close"];
        if (![validSources containsObject:source]) {
            if (error) {
                *error = [NSError errorWithDomain:@"EMAIndicator"
                                             code:2003
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithFormat:@"Invalid source '%@'. Valid sources: %@",
                                                    source, [validSources componentsJoinedByString:@", "]]}];
            }
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - EMA-specific Convenience Methods

- (double)currentEMAValue {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count == 0) {
        return NAN;
    }
    
    IndicatorDataModel *lastPoint = [self.outputSeries lastObject];
    return lastPoint.value;
}

- (NSArray<NSNumber *> *)emaValues {
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

- (NSColor *)emaColor {
    // Standard EMA color - orange/yellow for moving average
    return [NSColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0]; // Orange
}

- (NSString *)displayDescription {
    NSInteger period = [self.parameters[@"period"] integerValue];
    NSString *source = self.parameters[@"source"] ?: @"close";
    
    return [NSString stringWithFormat:@"EMA(%ld) on %@", (long)period, source];
}

#pragma mark - Utility Methods

- (BOOL)isUptrending {
    if (!self.isCalculated || self.outputSeries.count < 2) {
        return NO;
    }
    
    IndicatorDataModel *current = [self.outputSeries lastObject];
    IndicatorDataModel *previous = self.outputSeries[self.outputSeries.count - 2];
    
    return current.value > previous.value;
}

- (BOOL)isDowntrending {
    if (!self.isCalculated || self.outputSeries.count < 2) {
        return NO;
    }
    
    IndicatorDataModel *current = [self.outputSeries lastObject];
    IndicatorDataModel *previous = self.outputSeries[self.outputSeries.count - 2];
    
    return current.value < previous.value;
}

- (double)slopePercentage {
    // Calculate the slope of EMA as percentage over last 5 periods
    if (!self.isCalculated || self.outputSeries.count < 5) {
        return 0.0;
    }
    
    NSInteger count = self.outputSeries.count;
    IndicatorDataModel *current = self.outputSeries[count - 1];
    IndicatorDataModel *previous = self.outputSeries[count - 5];  // 5 periods ago
    
    if (previous.value == 0) {
        return 0.0;
    }
    
    return ((current.value - previous.value) / previous.value) * 100.0;
}

@end
