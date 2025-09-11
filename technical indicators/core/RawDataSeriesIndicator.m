//
// RawDataSeriesIndicator.m
// TradingApp
//

#import "RawDataSeriesIndicator.h"

@implementation RawDataSeriesIndicator

#pragma mark - Initialization

- (instancetype)initWithDataType:(RawDataType)dataType
                 visualizationType:(VisualizationType)vizType
                         dataField:(NSString *)field {
    
    NSDictionary *params = @{
        @"dataType": @(dataType),
        @"visualizationType": @(vizType),
        @"dataField": field ?: @"close"
    };
    
    if (self = [super initWithParameters:params]) {
        _dataType = dataType;
        _dataField = field ?: @"close";
        _lineWidth = 1.0;
        _showValues = NO;
        
        // Set the visualization type on the base class
        self.visualizationType = vizType;
        
        NSLog(@"📊 RawDataSeriesIndicator created: %@ - %@",
              [[self class] displayNameForDataType:dataType],
              [[self class] displayNameForVisualizationType:vizType]);
    }
    return self;
}

- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {
    RawDataType dataType = [parameters[@"dataType"] integerValue];
    VisualizationType vizType = parameters[@"visualizationType"] ?
        [parameters[@"visualizationType"] integerValue] : [self defaultVisualizationType];
    NSString *dataField = parameters[@"dataField"] ?: @"close";
    
    return [self initWithDataType:dataType visualizationType:vizType dataField:dataField];
}

#pragma mark - TechnicalIndicatorBase Overrides

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    if (!bars || bars.count == 0) {
        self.isCalculated = NO;
        return;
    }
    
    NSMutableArray<IndicatorDataModel *> *results = [[NSMutableArray alloc] init];
    
    for (HistoricalBarModel *bar in bars) {
        double value = [self extractValueFromBar:bar];
        
        IndicatorDataModel *dataPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                         value:value
                                                                    seriesName:self.shortName
                                                                    seriesType:self.visualizationType];
        [results addObject:dataPoint];
    }
    
    self.outputSeries = [results copy];
    self.isCalculated = YES;
    
    NSLog(@"📈 %@ calculated with %lu data points", self.name, (unsigned long)results.count);
}

- (NSInteger)minimumBarsRequired {
    return 1; // Raw data series only need one bar
}

+ (NSDictionary<NSString *, id> *)defaultParameters {
    return @{
        @"dataType": @(RawDataTypePrice),
        @"visualizationType": @(VisualizationTypeLine),
        @"dataField": @"close",
        @"color": [NSColor systemBlueColor],
        @"lineWidth": @1.0,
        @"showValues": @NO
    };
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    return @{
        @"dataType": @{
            @"type": @"integer",
            @"values": @[@(RawDataTypePrice), @(RawDataTypeVolume),
                        @(RawDataTypeFundamentals), @(RawDataTypeMarketMetrics),
                        @(RawDataTypeAlternative)],
            @"description": @"Type of raw data to visualize"
        },
        @"visualizationType": @{
            @"type": @"integer",
            @"values": @[@(VisualizationTypeLine), @(VisualizationTypeArea),
                        @(VisualizationTypeHistogram), @(VisualizationTypeCandlestick),
                        @(VisualizationTypeOHLC), @(VisualizationTypeStep)],
            @"description": @"How to visualize the data"
        },
        @"dataField": @{
            @"type": @"string",
            @"description": @"Field name to extract from bars"
        }
    };
}

#pragma mark - Abstract Method Implementations

- (double)extractValueFromBar:(HistoricalBarModel *)bar {
    // Extract the specified field from the bar
    if ([self.dataField isEqualToString:@"open"]) {
        return bar.open;
    } else if ([self.dataField isEqualToString:@"high"]) {
        return bar.high;
    } else if ([self.dataField isEqualToString:@"low"]) {
        return bar.low;
    } else if ([self.dataField isEqualToString:@"close"]) {
        return bar.close;
    } else if ([self.dataField isEqualToString:@"volume"]) {
        return bar.volume;
    } else if ([self.dataField isEqualToString:@"adjustedClose"]) {
        return bar.adjustedClose;
    } else if ([self.dataField isEqualToString:@"typical"]) {
        return (bar.high + bar.low + bar.close) / 3.0;
    }
    
    // Default to close price
    return bar.close;
}

- (NSColor *)defaultColor {
    switch (self.dataType) {
        case RawDataTypePrice:
            return [NSColor systemBlueColor];
        case RawDataTypeVolume:
            return [NSColor systemGrayColor];
        case RawDataTypeFundamentals:
            return [NSColor systemPurpleColor];
        case RawDataTypeMarketMetrics:
            return [NSColor systemOrangeColor];
        case RawDataTypeAlternative:
            return [NSColor systemYellowColor];
        default:
            return [NSColor systemBlueColor];
    }
}

- (VisualizationType)defaultVisualizationType {
    switch (self.dataType) {
        case RawDataTypePrice:
            return VisualizationTypeCandlestick;
        case RawDataTypeVolume:
            return VisualizationTypeHistogram;
        case RawDataTypeFundamentals:
        case RawDataTypeMarketMetrics:
            return VisualizationTypeLine;
        case RawDataTypeAlternative:
            return VisualizationTypeArea;
        default:
            return VisualizationTypeLine;
    }
}

- (BOOL)hasVisualOutput {
    return YES; // All raw data series have visual output
}

#pragma mark - Display Properties

- (NSString *)name {
    return [NSString stringWithFormat:@"%@ %@",
            [[self class] displayNameForDataType:self.dataType],
            [[self class] displayNameForVisualizationType:self.visualizationType]];
}

- (NSString *)shortName {
    return [[self class] displayNameForDataType:self.dataType];
}

#pragma mark - Utility Methods

+ (NSString *)displayNameForDataType:(RawDataType)dataType {
    switch (dataType) {
        case RawDataTypePrice:
            return @"Price";
        case RawDataTypeVolume:
            return @"Volume";
        case RawDataTypeFundamentals:
            return @"Fundamentals";
        case RawDataTypeMarketMetrics:
            return @"Market";
        case RawDataTypeAlternative:
            return @"Alternative";
        default:
            return @"Unknown";
    }
}

@end
