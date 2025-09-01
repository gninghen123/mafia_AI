//
// BollingerBandsIndicator.m
//

#import "BollingerBandsIndicator.h"
#import "IndicatorCalculationEngine.h"

@implementation BollingerBandsIndicator

#pragma mark - Abstract Method Implementations

- (NSString *)name {
    return @"Bollinger Bands";
}

- (NSString *)shortName {
    return @"BB";
}

+ (NSDictionary<NSString *, id> *)defaultParameters {
    return @{
        @"period": @20,          // Standard Bollinger period
        @"multiplier": @2.0,     // Standard deviation multiplier
        @"source": @"close"      // Price source
    };
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    return @{
        @"period": @{
            @"type": @"integer",
            @"min": @2,
            @"max": @100,
            @"description": @"Bollinger Bands period (2-100)"
        },
        @"multiplier": @{
            @"type": @"number",
            @"min": @0.5,
            @"max": @5.0,
            @"description": @"Standard deviation multiplier (0.5-5.0)"
        },
        @"source": @{
            @"type": @"string",
            @"values": @[@"open", @"high", @"low", @"close"],
            @"description": @"Price source for calculation"
        }
    };
}

- (NSInteger)minimumBarsRequired {
    NSInteger period = [self.parameters[@"period"] integerValue];
    return MAX(2, period);
}

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    // Reset state
    [self reset];
    
    // Validate input
    if (![self canCalculateWithBars:bars]) {
        self.lastError = [NSError errorWithDomain:@"BollingerBandsIndicator"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Insufficient bars for Bollinger Bands calculation"}];
        return;
    }
    
    // Get parameters
    NSInteger period = [self.parameters[@"period"] integerValue];
    double multiplier = [self.parameters[@"multiplier"] doubleValue] ?: 2.0;
    NSString *source = self.parameters[@"source"] ?: @"close";
    
    // Extract price series
    NSArray<NSNumber *> *prices = [IndicatorCalculationEngine extractPriceSeries:bars priceType:source];
    if (!prices || prices.count == 0) {
        self.lastError = [NSError errorWithDomain:@"BollingerBandsIndicator"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract price series"}];
        return;
    }
    
    // Calculate SMA (middle band)
    NSArray<NSNumber *> *smaValues = [IndicatorCalculationEngine sma:prices period:period];
    
    // Calculate Standard Deviation
    NSArray<NSNumber *> *stdevValues = [IndicatorCalculationEngine stdev:prices period:period];
    
    if (!smaValues || !stdevValues ||
        smaValues.count != bars.count || stdevValues.count != bars.count) {
        self.lastError = [NSError errorWithDomain:@"BollingerBandsIndicator"
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey: @"Bollinger Bands calculation failed"}];
        return;
    }
    
    // Create output series
    NSMutableArray<IndicatorDataModel *> *outputData = [[NSMutableArray alloc] init];
    
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBarModel *bar = bars[i];
        double sma = [smaValues[i] doubleValue];
        double stdev = [stdevValues[i] doubleValue];
        
        // Calculate bands
        double upperBand = sma + (stdev * multiplier);
        double lowerBand = sma - (stdev * multiplier);
        
        // Create data points for all three bands
        if ([IndicatorCalculationEngine isValidNumber:sma]) {
            // Middle Band (SMA)
            IndicatorDataModel *middlePoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                               value:sma
                                                                          seriesName:@"BB_Middle"
                                                                          seriesType:IndicatorSeriesTypeLine
                                                                               color:[self middleBandColor]];
            middlePoint.anchorValue = sma;
            [outputData addObject:middlePoint];
            
            // Upper Band
            IndicatorDataModel *upperPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                              value:upperBand
                                                                         seriesName:@"BB_Upper"
                                                                         seriesType:IndicatorSeriesTypeLine
                                                                              color:[self upperBandColor]];
            upperPoint.anchorValue = sma;
            [outputData addObject:upperPoint];
            
            // Lower Band
            IndicatorDataModel *lowerPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                              value:lowerBand
                                                                         seriesName:@"BB_Lower"
                                                                         seriesType:IndicatorSeriesTypeLine
                                                                              color:[self lowerBandColor]];
            lowerPoint.anchorValue = sma;
            [outputData addObject:lowerPoint];
        }
    }
    
    // Set results
    self.outputSeries = [outputData copy];
    self.isCalculated = YES;
    self.lastError = nil;
    
    NSLog(@"✅ BollingerBandsIndicator: Calculated BB(%ld, %.1f) for %lu bars",
          (long)period, multiplier, (unsigned long)bars.count);
}

#pragma mark - Bollinger Bands Specific Methods

- (double)currentMiddleBand {
    return [self getBandValue:@"BB_Middle"];
}

- (double)currentUpperBand {
    return [self getBandValue:@"BB_Upper"];
}

- (double)currentLowerBand {
    return [self getBandValue:@"BB_Lower"];
}

- (double)getBandValue:(NSString *)bandName {
    if (!self.isCalculated || !self.outputSeries) {
        return NAN;
    }
    
    // Find the latest data point for the specified band
    for (NSInteger i = self.outputSeries.count - 1; i >= 0; i--) {
        IndicatorDataModel *point = self.outputSeries[i];
        if ([point.seriesName isEqualToString:bandName]) {
            return point.value;
        }
    }
    
    return NAN;
}

- (double)currentBandwidth {
    double upper = [self currentUpperBand];
    double lower = [self currentLowerBand];
    
    if ([IndicatorCalculationEngine isValidNumber:upper] && [IndicatorCalculationEngine isValidNumber:lower]) {
        return upper - lower;
    }
    
    return NAN;
}

- (double)currentPercentB:(double)price {
    double upper = [self currentUpperBand];
    double lower = [self currentLowerBand];
    
    if ([IndicatorCalculationEngine isValidNumber:upper] && [IndicatorCalculationEngine isValidNumber:lower] && upper != lower) {
        return (price - lower) / (upper - lower);
    }
    
    return NAN;
}

- (BOOL)isPriceTouchingUpperBand:(double)price tolerance:(double)tolerance {
    double upper = [self currentUpperBand];
    if (![IndicatorCalculationEngine isValidNumber:upper]) return NO;
    
    return fabs(price - upper) <= tolerance;
}

- (BOOL)isPriceTouchingLowerBand:(double)price tolerance:(double)tolerance {
    double lower = [self currentLowerBand];
    if (![IndicatorCalculationEngine isValidNumber:lower]) return NO;
    
    return fabs(price - lower) <= tolerance;
}

- (BOOL)isPriceOutsideBands:(double)price {
    double upper = [self currentUpperBand];
    double lower = [self currentLowerBand];
    
    if (![IndicatorCalculationEngine isValidNumber:upper] || ![IndicatorCalculationEngine isValidNumber:lower]) {
        return NO;
    }
    
    return price > upper || price < lower;
}

- (BOOL)areBandsContracting:(NSInteger)lookbackPeriods {
    if (!self.isCalculated || self.outputSeries.count < lookbackPeriods * 3) return NO;
    
    // Get current and past bandwidth
    double currentBandwidth = [self currentBandwidth];
    
    // Find bandwidth from lookbackPeriods ago
    // Need to find corresponding upper and lower band values
    NSInteger targetIndex = self.outputSeries.count - (lookbackPeriods * 3);  // 3 bands per period
    if (targetIndex < 0) return NO;
    
    double pastUpper = NAN, pastLower = NAN;
    
    // Look for upper and lower bands around the target index
    for (NSInteger i = targetIndex; i < targetIndex + 10 && i < self.outputSeries.count; i++) {
        IndicatorDataModel *point = self.outputSeries[i];
        if ([point.seriesName isEqualToString:@"BB_Upper"]) {
            pastUpper = point.value;
        } else if ([point.seriesName isEqualToString:@"BB_Lower"]) {
            pastLower = point.value;
        }
        
        if ([IndicatorCalculationEngine isValidNumber:pastUpper] && [IndicatorCalculationEngine isValidNumber:pastLower]) {
            break;
        }
    }
    
    if (![IndicatorCalculationEngine isValidNumber:pastUpper] || ![IndicatorCalculationEngine isValidNumber:pastLower]) {
        return NO;
    }
    
    double pastBandwidth = pastUpper - pastLower;
    
    return [IndicatorCalculationEngine isValidNumber:currentBandwidth] &&
           [IndicatorCalculationEngine isValidNumber:pastBandwidth] &&
           currentBandwidth < pastBandwidth;
}

#pragma mark - Display Properties

- (NSColor *)middleBandColor {
    return [NSColor colorWithRed:0.0 green:0.7 blue:1.0 alpha:1.0]; // Light blue
}

- (NSColor *)upperBandColor {
    return [NSColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.7]; // Semi-transparent red
}

- (NSColor *)lowerBandColor {
    return [NSColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.7]; // Semi-transparent green
}

- (NSString *)displayDescription {
    NSInteger period = [self.parameters[@"period"] integerValue];
    double multiplier = [self.parameters[@"multiplier"] doubleValue];
    NSString *source = self.parameters[@"source"] ?: @"close";
    
    return [NSString stringWithFormat:@"BB(%ld, %.1f) on %@", (long)period, multiplier, source];
}

@end
