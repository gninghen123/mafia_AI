//
// SecurityIndicator.m
// TradingApp
//

#import "SecurityIndicator.h"

@implementation SecurityIndicator

#pragma mark - Initialization

- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {
    // Create modified parameters with SecurityIndicator defaults
    NSMutableDictionary *modifiedParams = parameters ? [parameters mutableCopy] : [[NSMutableDictionary alloc] init];
    
    // Force specific values for SecurityIndicator
    modifiedParams[@"dataType"] = @(RawDataTypePrice);
    
    // Set default visualization if not specified
    if (!modifiedParams[@"visualizationType"]) {
        modifiedParams[@"visualizationType"] = @(VisualizationTypeCandlestick);
    }
    
    // Set default data field if not specified
    if (!modifiedParams[@"dataField"]) {
        modifiedParams[@"dataField"] = @"close";
    }
    
    self = [super initWithParameters:[modifiedParams copy]];
    if (self) {
        NSLog(@"🏦 SecurityIndicator initialized with visualization: %@",
              [[self class] displayNameForVisualizationType:self.visualizationType]);
    }
    return self;
}

#pragma mark - TechnicalIndicatorBase Overrides

+ (NSDictionary<NSString *, id> *)defaultParameters {
    return @{
        @"dataType": @(RawDataTypePrice),
        @"visualizationType": @(VisualizationTypeCandlestick),
        @"dataField": @"close",
        @"bullishColor": [NSColor systemGreenColor],
        @"bearishColor": [NSColor systemRedColor],
        @"lineWidth": @1.0,
        @"showValues": @NO
    };
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    return @{
        @"visualizationType": @{
            @"type": @"integer",
            @"values": @[@(VisualizationTypeCandlestick), @(VisualizationTypeLine),
                        @(VisualizationTypeOHLC), @(VisualizationTypeArea)],
            @"description": @"Security visualization type"
        },
        @"dataField": @{
            @"type": @"string",
            @"values": @[@"close", @"open", @"high", @"low", @"adjustedClose", @"typical"],
            @"description": @"Price field to display"
        }
    };
}

- (NSString *)name {
    return [NSString stringWithFormat:@"Security (%@)",
            [[self class] displayNameForVisualizationType:self.visualizationType]];
}

- (NSString *)shortName {
    return @"Security";
}

#pragma mark - RawDataSeriesIndicator Overrides

- (double)extractValueFromBar:(HistoricalBarModel *)bar {
    // For candlestick/OHLC, we actually need all OHLC values
    // But base implementation handles individual field extraction
    return [super extractValueFromBar:bar];
}

- (NSColor *)defaultColor {
    // Security data typically uses green/red for bullish/bearish
    return self.parameters[@"bullishColor"] ?: [NSColor systemGreenColor];
}

- (VisualizationType)defaultVisualizationType {
    return VisualizationTypeCandlestick;
}

#pragma mark - Factory Methods

+ (instancetype)candlestickIndicator {
    return [[SecurityIndicator alloc] initWithParameters:@{
        @"visualizationType": @(VisualizationTypeCandlestick),
        @"dataField": @"close"
    }];
}

+ (instancetype)lineIndicator {
    return [[SecurityIndicator alloc] initWithParameters:@{
        @"visualizationType": @(VisualizationTypeLine),
        @"dataField": @"close"
    }];
}

+ (instancetype)ohlcIndicator {
    return [[SecurityIndicator alloc] initWithParameters:@{
        @"visualizationType": @(VisualizationTypeOHLC),
        @"dataField": @"close"
    }];
}

+ (instancetype)areaIndicator {
    return [[SecurityIndicator alloc] initWithParameters:@{
        @"visualizationType": @(VisualizationTypeArea),
        @"dataField": @"close"
    }];
}

#pragma mark - Security-Specific Methods

- (double)currentPrice {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count == 0) {
        return NAN;
    }
    
    IndicatorDataModel *lastPoint = [self.outputSeries lastObject];
    return lastPoint.value;
}

- (double)priceChange {
    if (!self.isCalculated || !self.outputSeries || self.outputSeries.count < 2) {
        return NAN;
    }
    
    IndicatorDataModel *current = [self.outputSeries lastObject];
    IndicatorDataModel *previous = self.outputSeries[self.outputSeries.count - 2];
    
    return current.value - previous.value;
}

- (double)percentChange {
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

- (BOOL)isCurrentBarBullish {
    // For this method, we need to check the actual bar data, not just the extracted field
    // This would require access to the original bars - simplified for now
    double change = [self priceChange];
    return !isnan(change) && change > 0;
}

- (NSDictionary<NSString *, NSNumber *> *)currentOHLC {
    // This would require storing OHLC data separately or accessing original bars
    // For now, return current price in all fields (simplified)
    double currentValue = [self currentPrice];
    
    if (isnan(currentValue)) {
        return @{};
    }
    
    return @{
        @"open": @(currentValue),
        @"high": @(currentValue),
        @"low": @(currentValue),
        @"close": @(currentValue)
    };
}

#pragma mark - Display Configuration

- (void)configureCandlestickWithBullishColor:(NSColor *)bullishColor
                                bearishColor:(NSColor *)bearishColor {
    
    NSMutableDictionary *newParams = [self.parameters mutableCopy];
    newParams[@"visualizationType"] = @(VisualizationTypeCandlestick);
    newParams[@"bullishColor"] = bullishColor;
    newParams[@"bearishColor"] = bearishColor;
    self.parameters = [newParams copy];
    
    // Re-read properties from parameters instead of setting ivars directly
    // The base class will handle the parameter updates
}

- (void)configureLineWithColor:(NSColor *)color width:(CGFloat)width {
    NSMutableDictionary *newParams = [self.parameters mutableCopy];
    newParams[@"visualizationType"] = @(VisualizationTypeLine);
    newParams[@"color"] = color;
    newParams[@"lineWidth"] = @(width);
    self.parameters = [newParams copy];
    
    // Re-read properties from parameters instead of setting ivars directly
     // The base class will handle the parameter updates
}

- (BOOL)hasVisualOutput {
    return YES; // ChartPanelView disegna già i candlestick
}

@end
