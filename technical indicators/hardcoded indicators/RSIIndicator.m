//
// RSIIndicator.m
//

#import "RSIIndicator.h"
#import "IndicatorCalculationEngine.h"

@implementation RSIIndicator

#pragma mark - Abstract Method Implementations

- (NSString *)name {
    return @"Relative Strength Index";
}

- (NSString *)shortName {
    return @"RSI";
}

+ (NSDictionary<NSString *, id> *)defaultParameters {
    return @{
        @"period": @14,          // Standard RSI period
        @"source": @"close",     // Price source
        @"overbought": @70,      // Overbought level
        @"oversold": @30         // Oversold level
    };
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    return @{
        @"period": @{
            @"type": @"integer",
            @"min": @2,
            @"max": @100,
            @"description": @"RSI period (2-100)"
        },
        @"source": @{
            @"type": @"string",
            @"values": @[@"open", @"high", @"low", @"close"],
            @"description": @"Price source for RSI calculation"
        },
        @"overbought": @{
            @"type": @"number",
            @"min": @50,
            @"max": @100,
            @"description": @"Overbought level (50-100)"
        },
        @"oversold": @{
            @"type": @"number",
            @"min": @0,
            @"max": @50,
            @"description": @"Oversold level (0-50)"
        }
    };
}

- (NSInteger)minimumBarsRequired {
    NSInteger period = [self.parameters[@"period"] integerValue];
    return MAX(2, period + 1);  // RSI needs period + 1 for price changes
}

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    // Reset state
    [self reset];
    
    // Validate input
    if (![self canCalculateWithBars:bars]) {
        self.lastError = [NSError errorWithDomain:@"RSIIndicator"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Insufficient bars for RSI calculation"}];
        return;
    }
    
    // Get parameters
    NSInteger period = [self.parameters[@"period"] integerValue];
    NSString *source = self.parameters[@"source"] ?: @"close";
    
    // Extract price series
    NSArray<NSNumber *> *prices = [IndicatorCalculationEngine extractPriceSeries:bars priceType:source];
    if (!prices || prices.count == 0) {
        self.lastError = [NSError errorWithDomain:@"RSIIndicator"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract price series"}];
        return;
    }
    
    // Calculate RSI
    NSArray<NSNumber *> *rsiValues = [IndicatorCalculationEngine rsi:prices period:period];
    if (!rsiValues || rsiValues.count != bars.count) {
        self.lastError = [NSError errorWithDomain:@"RSIIndicator"
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey: @"RSI calculation failed"}];
        return;
    }
    
    // Create output series with RSI values and level lines
    NSMutableArray<IndicatorDataModel *> *outputData = [[NSMutableArray alloc] init];
    NSString *seriesName = [NSString stringWithFormat:@"RSI(%ld)", (long)period];
    
    // Get overbought/oversold levels
    double overboughtLevel = [self.parameters[@"overbought"] doubleValue] ?: 70.0;
    double oversoldLevel = [self.parameters[@"oversold"] doubleValue] ?: 30.0;
    
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBarModel *bar = bars[i];
        double rsiValue = [rsiValues[i] doubleValue];
        
        // Main RSI line
        IndicatorDataModel *dataPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                         value:rsiValue
                                                                    seriesName:seriesName
                                                                   seriesType:VisualizationTypeLine
                                                                         color:[self rsiColor]];
        dataPoint.anchorValue = 50.0;  // RSI center line
        dataPoint.isSignal = NO;
        [outputData addObject:dataPoint];
        
        // Add overbought line (only first and last to avoid duplicates)
        if (i == 0 || i == bars.count - 1) {
            IndicatorDataModel *overboughtPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                                   value:overboughtLevel
                                                                              seriesName:@"RSI_Overbought"
                                                                             seriesType:VisualizationTypeLine
                                                                                   color:[NSColor redColor]];
            overboughtPoint.anchorValue = 50.0;
            [outputData addObject:overboughtPoint];
            
            // Oversold line
            IndicatorDataModel *oversoldPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                                 value:oversoldLevel
                                                                            seriesName:@"RSI_Oversold"
                                                                           seriesType:VisualizationTypeLine
                                                                                 color:[NSColor greenColor]];
            oversoldPoint.anchorValue = 50.0;
            [outputData addObject:oversoldPoint];
        }
    }
    
    // Set results
    self.outputSeries = [outputData copy];
    self.isCalculated = YES;
    self.lastError = nil;
    
    NSLog(@"✅ RSIIndicator: Calculated RSI(%ld) for %lu bars", (long)period, (unsigned long)bars.count);
}

#pragma mark - RSI-specific Methods

- (double)currentRSIValue {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count == 0) {
        return NAN;
    }
    
    // Find the latest RSI data point (not overbought/oversold lines)
    for (NSInteger i = self.outputSeries.count - 1; i >= 0; i--) {
        IndicatorDataModel *point = self.outputSeries[i];
        if ([point.seriesName hasPrefix:@"RSI("]) {
            return point.value;
        }
    }
    
    return NAN;
}

- (NSArray<NSNumber *> *)rsiValues {
    if (!self.isCalculated || !self.outputSeries) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *values = [[NSMutableArray alloc] init];
    for (IndicatorDataModel *dataPoint in self.outputSeries) {
        if ([dataPoint.seriesName hasPrefix:@"RSI("]) {
            [values addObject:@(dataPoint.value)];
        }
    }
    
    return [values copy];
}

- (IndicatorDataModel *)latestDataPoint {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count == 0) {
        return nil;
    }
    
    // Return the latest RSI data point
    for (NSInteger i = self.outputSeries.count - 1; i >= 0; i--) {
        IndicatorDataModel *point = self.outputSeries[i];
        if ([point.seriesName hasPrefix:@"RSI("]) {
            return point;
        }
    }
    
    return nil;
}

- (BOOL)isOverbought {
    double currentRSI = [self currentRSIValue];
    double overboughtLevel = [self.parameters[@"overbought"] doubleValue] ?: 70.0;
    return [IndicatorCalculationEngine isValidNumber:currentRSI] && currentRSI > overboughtLevel;
}

- (BOOL)isOversold {
    double currentRSI = [self currentRSIValue];
    double oversoldLevel = [self.parameters[@"oversold"] doubleValue] ?: 30.0;
    return [IndicatorCalculationEngine isValidNumber:currentRSI] && currentRSI < oversoldLevel;
}

- (BOOL)isBullishDivergence:(NSArray<HistoricalBarModel *> *)bars {
    // Simple divergence check - price makes lower low, RSI makes higher low
    if (!bars || bars.count < 10 || !self.isCalculated) return NO;
    
    NSArray<NSNumber *> *rsiVals = [self rsiValues];
    if (rsiVals.count < 10) return NO;
    
    NSInteger len = MIN(bars.count, rsiVals.count);
    if (len < 10) return NO;
    
    // Check last 10 periods for divergence pattern
    double currentPrice = bars[len-1].close;
    double pastPrice = bars[len-10].close;
    double currentRSI = [rsiVals[len-1] doubleValue];
    double pastRSI = [rsiVals[len-10] doubleValue];
    
    // Bullish divergence: price down, RSI up
    return (currentPrice < pastPrice) && (currentRSI > pastRSI);
}

- (BOOL)isBearishDivergence:(NSArray<HistoricalBarModel *> *)bars {
    // Simple divergence check - price makes higher high, RSI makes lower high
    if (!bars || bars.count < 10 || !self.isCalculated) return NO;
    
    NSArray<NSNumber *> *rsiVals = [self rsiValues];
    if (rsiVals.count < 10) return NO;
    
    NSInteger len = MIN(bars.count, rsiVals.count);
    if (len < 10) return NO;
    
    // Check last 10 periods for divergence pattern
    double currentPrice = bars[len-1].close;
    double pastPrice = bars[len-10].close;
    double currentRSI = [rsiVals[len-1] doubleValue];
    double pastRSI = [rsiVals[len-10] doubleValue];
    
    // Bearish divergence: price up, RSI down
    return (currentPrice > pastPrice) && (currentRSI < pastRSI);
}

#pragma mark - Display Properties

- (NSColor *)rsiColor {
    return [NSColor colorWithRed:0.5 green:0.0 blue:1.0 alpha:1.0]; // Purple
}

- (NSString *)displayDescription {
    NSInteger period = [self.parameters[@"period"] integerValue];
    return [NSString stringWithFormat:@"RSI(%ld)", (long)period];
}

@end
