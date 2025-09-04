//
// VolumeIndicator.m
// TradingApp
//

#import "VolumeIndicator.h"

@implementation VolumeIndicator

#pragma mark - Initialization

- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {
    // Create modified parameters with VolumeIndicator defaults
    NSMutableDictionary *modifiedParams = parameters ? [parameters mutableCopy] : [[NSMutableDictionary alloc] init];
    
    // Force specific values for VolumeIndicator
    modifiedParams[@"dataType"] = @(RawDataTypeVolume);
    modifiedParams[@"dataField"] = @"volume";
    
    // Set default visualization if not specified
    if (!modifiedParams[@"visualizationType"]) {
        modifiedParams[@"visualizationType"] = @(VisualizationTypeHistogram);
    }
    
    self = [super initWithParameters:[modifiedParams copy]];
    if (self) {
        NSLog(@"📊 VolumeIndicator initialized with visualization: %@",
              [[self class] displayNameForVisualizationType:self.visualizationType]);
    }
    return self;
}

#pragma mark - TechnicalIndicatorBase Overrides

+ (NSDictionary<NSString *, id> *)defaultParameters {
    return @{
        @"dataType": @(RawDataTypeVolume),
        @"visualizationType": @(VisualizationTypeHistogram),
        @"dataField": @"volume",
        @"color": [NSColor systemGrayColor],
        @"highVolumeColor": [NSColor systemOrangeColor],
        @"lowVolumeColor": [NSColor systemGrayColor],
        @"thresholdMultiplier": @1.5,
        @"lineWidth": @1.0,
        @"smoothing": @NO,
        @"showValues": @YES
    };
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    return @{
        @"visualizationType": @{
            @"type": @"integer",
            @"values": @[@(VisualizationTypeHistogram), @(VisualizationTypeLine), @(VisualizationTypeArea)],
            @"description": @"Volume visualization type"
        },
        @"thresholdMultiplier": @{
            @"type": @"number",
            @"min": @1.0,
            @"max": @5.0,
            @"description": @"Multiplier for high/low volume threshold"
        }
    };
}

- (NSString *)name {
    return [NSString stringWithFormat:@"Volume (%@)",
            [[self class] displayNameForVisualizationType:self.visualizationType]];
}

- (NSString *)shortName {
    return @"Volume";
}

#pragma mark - RawDataSeriesIndicator Overrides

- (double)extractValueFromBar:(HistoricalBarModel *)bar {
    // Always extract volume for VolumeIndicator
    return (double)bar.volume;
}

- (NSColor *)defaultColor {
    return [NSColor systemGrayColor];
}

- (VisualizationType)defaultVisualizationType {
    return VisualizationTypeHistogram;
}

#pragma mark - Factory Methods

+ (instancetype)histogramIndicator {
    return [[VolumeIndicator alloc] initWithParameters:@{
        @"visualizationType": @(VisualizationTypeHistogram)
    }];
}

+ (instancetype)lineIndicator {
    return [[VolumeIndicator alloc] initWithParameters:@{
        @"visualizationType": @(VisualizationTypeLine)
    }];
}

+ (instancetype)areaIndicator {
    return [[VolumeIndicator alloc] initWithParameters:@{
        @"visualizationType": @(VisualizationTypeArea)
    }];
}

#pragma mark - Volume-Specific Methods

- (long long)currentVolume {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count == 0) {
        return 0;
    }
    
    IndicatorDataModel *lastPoint = [self.outputSeries lastObject];
    return (long long)lastPoint.value;
}

- (long long)volumeChange {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count < 2) {
        return 0;
    }
    
    IndicatorDataModel *current = [self.outputSeries lastObject];
    IndicatorDataModel *previous = self.outputSeries[self.outputSeries.count - 2];
    
    return (long long)(current.value - previous.value);
}

- (double)volumePercentChange {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count < 2) {
        return NAN;
    }
    
    IndicatorDataModel *current = [self.outputSeries lastObject];
    IndicatorDataModel *previous = self.outputSeries[self.outputSeries.count - 2];
    
    if (previous.value == 0) {
        return NAN;
    }
    
    return ((current.value - previous.value) / previous.value) * 100.0;
}

- (double)averageVolume:(NSInteger)period {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count < period) {
        return NAN;
    }
    
    NSInteger startIndex = MAX(0, (NSInteger)self.outputSeries.count - period);
    double sum = 0.0;
    NSInteger count = 0;
    
    for (NSInteger i = startIndex; i < self.outputSeries.count; i++) {
        IndicatorDataModel *point = self.outputSeries[i];
        sum += point.value;
        count++;
    }
    
    return count > 0 ? (sum / count) : NAN;
}

- (BOOL)isVolumeAboveAverage:(NSInteger)period {
    double avgVolume = [self averageVolume:period];
    double currentVol = [self currentVolume];
    
    if (isnan(avgVolume) || currentVol == 0) {
        return NO;
    }
    
    double thresholdMultiplier = [self.parameters[@"thresholdMultiplier"] doubleValue];
    if (thresholdMultiplier == 0) {
        thresholdMultiplier = 1.5; // Default
    }
    
    return currentVol > (avgVolume * thresholdMultiplier);
}

- (double)volumeTrend:(NSInteger)period {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count < period) {
        return 0.0;
    }
    
    // Calculate simple linear trend over the period
    NSInteger startIndex = MAX(0, (NSInteger)self.outputSeries.count - period);
    NSInteger count = self.outputSeries.count - startIndex;
    
    if (count < 2) {
        return 0.0;
    }
    
    // Calculate trend using first and last values
    IndicatorDataModel *first = self.outputSeries[startIndex];
    IndicatorDataModel *last = [self.outputSeries lastObject];
    
    if (first.value == 0) {
        return 0.0;
    }
    
    return ((last.value - first.value) / first.value) * 100.0;
}

#pragma mark - Display Configuration

- (void)configureHistogramWithHighVolumeColor:(NSColor *)highVolumeColor
                               lowVolumeColor:(NSColor *)lowVolumeColor
                           thresholdMultiplier:(double)thresholdMultiplier {
    
    NSMutableDictionary *newParams = [self.parameters mutableCopy];
    newParams[@"visualizationType"] = @(VisualizationTypeHistogram);
    newParams[@"highVolumeColor"] = highVolumeColor;
    newParams[@"lowVolumeColor"] = lowVolumeColor;
    newParams[@"thresholdMultiplier"] = @(thresholdMultiplier);
    self.parameters = [newParams copy];
    
    // The base class will handle the parameter updates
}

- (void)configureLineWithColor:(NSColor *)color
                         width:(CGFloat)width
                     smoothing:(BOOL)smoothing {
    
    NSMutableDictionary *newParams = [self.parameters mutableCopy];
    newParams[@"visualizationType"] = @(VisualizationTypeLine);
    newParams[@"color"] = color;
    newParams[@"lineWidth"] = @(width);
    newParams[@"smoothing"] = @(smoothing);
    self.parameters = [newParams copy];
    
    // The base class will handle the parameter updates
}

@end
