//
// RawDataSeriesIndicator.m
// TradingApp
//

#import "RawDataSeriesIndicator.h"

@implementation RawDataSeriesIndicator

#pragma mark - Initialization

- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {
    self = [super initWithParameters:parameters];
    if (self) {
        // Set defaults from parameters
        _dataType = parameters[@"dataType"] ? [parameters[@"dataType"] integerValue] : RawDataTypePrice;
        _visualizationType = parameters[@"visualizationType"] ? [parameters[@"visualizationType"] integerValue] : [self defaultVisualizationType];
        _dataField = parameters[@"dataField"] ?: @"close";
        _seriesColor = parameters[@"color"] ?: [self defaultColor];
        _lineWidth = parameters[@"lineWidth"] ? [parameters[@"lineWidth"] floatValue] : 1.0;
        _showValues = parameters[@"showValues"] ? [parameters[@"showValues"] boolValue] : NO;
        
        NSLog(@"🎨 RawDataSeriesIndicator initialized: dataType=%ld, vizType=%ld, field='%@'",
              (long)_dataType, (long)_visualizationType, _dataField);
    }
    return self;
}

- (instancetype)initWithDataType:(RawDataType)dataType
                visualizationType:(VisualizationType)vizType
                        dataField:(NSString *)field {
    
    NSDictionary *params = @{
        @"dataType": @(dataType),
        @"visualizationType": @(vizType),
        @"dataField": field ?: @"close"
    };
    
    return [self initWithParameters:params];
}

#pragma mark - TechnicalIndicatorBase Overrides

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
            @"min": @0,
            @"max": @4,
            @"description": @"Raw data type (0=Price, 1=Volume, 2=Fundamentals, 3=MarketMetrics, 4=Alternative)"
        },
        @"visualizationType": @{
            @"type": @"integer",
            @"min": @0,
            @"max": @5,
            @"description": @"Visualization type (0=Candlestick, 1=Line, 2=Area, 3=Histogram, 4=OHLC, 5=Step)"
        },
        @"dataField": @{
            @"type": @"string",
            @"description": @"Data field to extract (close, volume, revenue, etc.)"
        }
    };
}

- (NSInteger)minimumBarsRequired {
    return 1; // Raw data needs only 1 bar minimum
}

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    [self reset];
    
    if (![self canCalculateWithBars:bars]) {
        self.lastError = [NSError errorWithDomain:@"RawDataSeriesIndicator"
                                            code:1001
                                        userInfo:@{NSLocalizedDescriptionKey: @"Insufficient bars for calculation"}];
        return;
    }
    
    NSMutableArray<IndicatorDataModel *> *results = [[NSMutableArray alloc] initWithCapacity:bars.count];
    
    for (HistoricalBarModel *bar in bars) {
        double value = [self extractValueFromBar:bar];
        
        IndicatorDataModel *dataPoint = [IndicatorDataModel dataWithTimestamp:bar.date
                                                                       value:value
                                                                  seriesName:self.shortName
                                                                  seriesType:[[self class] seriesTypeFromVisualizationType:self.visualizationType]
                                                                       color:self.seriesColor];
        [results addObject:dataPoint];
    }
    
    self.outputSeries = [results copy];
    self.isCalculated = YES;
    
    NSLog(@"✅ RawDataSeriesIndicator calculated %lu data points", (unsigned long)results.count);
}

#pragma mark - Abstract Methods (Subclasses Override)

- (double)extractValueFromBar:(HistoricalBarModel *)bar {
    // Base implementation extracts based on dataField
    if ([self.dataField isEqualToString:@"open"]) {
        return bar.open;
    } else if ([self.dataField isEqualToString:@"high"]) {
        return bar.high;
    } else if ([self.dataField isEqualToString:@"low"]) {
        return bar.low;
    } else if ([self.dataField isEqualToString:@"close"]) {
        return bar.close;
    } else if ([self.dataField isEqualToString:@"adjustedClose"]) {
        return bar.adjustedClose;
    } else if ([self.dataField isEqualToString:@"volume"]) {
        return (double)bar.volume;
    } else if ([self.dataField isEqualToString:@"typical"]) {
        return bar.typicalPrice;
    } else if ([self.dataField isEqualToString:@"range"]) {
        return bar.range;
    }
    
    // Default to close
    return bar.close;
}

- (NSColor *)defaultColor {
    switch (self.dataType) {
        case RawDataTypePrice:
            return [NSColor systemBlueColor];
        case RawDataTypeVolume:
            return [NSColor systemGrayColor];
        case RawDataTypeFundamentals:
            return [NSColor systemGreenColor];
        case RawDataTypeMarketMetrics:
            return [NSColor systemOrangeColor];
        case RawDataTypeAlternative:
            return [NSColor systemPurpleColor];
        default:
            return [NSColor systemBlueColor];
    }
}

- (VisualizationType)defaultVisualizationType {
    switch (self.dataType) {
        case RawDataTypePrice:
            return VisualizationTypeLine;
        case RawDataTypeVolume:
            return VisualizationTypeHistogram;
        case RawDataTypeFundamentals:
            return VisualizationTypeLine;
        case RawDataTypeMarketMetrics:
            return VisualizationTypeLine;
        case RawDataTypeAlternative:
            return VisualizationTypeArea;
        default:
            return VisualizationTypeLine;
    }
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

+ (IndicatorSeriesType)seriesTypeFromVisualizationType:(VisualizationType)vizType {
    switch (vizType) {
        case VisualizationTypeCandlestick:
        case VisualizationTypeOHLC:
        case VisualizationTypeLine:
        case VisualizationTypeStep:
            return IndicatorSeriesTypeLine;
        case VisualizationTypeHistogram:
            return IndicatorSeriesTypeHistogram;
        case VisualizationTypeArea:
            return IndicatorSeriesTypeArea;
        default:
            return IndicatorSeriesTypeLine;
    }
}

+ (NSString *)displayNameForVisualizationType:(VisualizationType)vizType {
    switch (vizType) {
        case VisualizationTypeCandlestick:
            return @"Candlestick";
        case VisualizationTypeLine:
            return @"Line";
        case VisualizationTypeArea:
            return @"Area";
        case VisualizationTypeHistogram:
            return @"Histogram";
        case VisualizationTypeOHLC:
            return @"OHLC";
        case VisualizationTypeStep:
            return @"Step";
        default:
            return @"Unknown";
    }
}

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
