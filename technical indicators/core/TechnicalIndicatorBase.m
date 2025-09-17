//
// TechnicalIndicatorBase.m
// TradingApp
//

#import "TechnicalIndicatorBase.h"

@implementation TechnicalIndicatorBase

#pragma mark - Initialization

- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {
    if (self = [super init]) {
        _indicatorID = [[NSUUID UUID] UUIDString];
        _type = IndicatorTypeHardcoded;
        _parameters = parameters ?: @{};
        _isCalculated = NO;
        
        // ✅ NEW: Set default visualization type
        _visualizationType = [self defaultVisualizationType];
        
        // Override from parameters if provided
        if (parameters[@"visualizationType"]) {
            _visualizationType = [parameters[@"visualizationType"] integerValue];
        }
    }
    return self;
}

#pragma mark - Abstract Methods (Must be overridden)

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"calculateWithBars must be overridden by subclass"
                                 userInfo:nil];
}

- (NSInteger)minimumBarsRequired {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"minimumBarsRequired must be overridden by subclass"
                                 userInfo:nil];
}

+ (NSDictionary<NSString *, id> *)defaultParameters {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"defaultParameters must be overridden by subclass"
                                 userInfo:nil];
}

+ (NSDictionary<NSString *, id> *)parameterValidationRules {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"parameterValidationRules must be overridden by subclass"
                                 userInfo:nil];
}

#pragma mark - ✅ NEW: Visualization Methods

- (VisualizationType)defaultVisualizationType {
    // Base implementation - subclasses should override
    return VisualizationTypeLine;
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

#pragma mark - Default Implementations

- (NSString *)name {
    return NSStringFromClass(self.class);
}

- (NSString *)shortName {
    return [self.name stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
}

- (BOOL)validateParameters:(NSDictionary<NSString *, id> *)parameters error:(NSError **)error {
    // Basic validation - can be overridden by subclasses
    if (!parameters) {
        if (error) {
            *error = [NSError errorWithDomain:@"TechnicalIndicatorError"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Parameters cannot be nil"}];
        }
        return NO;
    }
    return YES;
}

- (BOOL)canCalculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    return bars && bars.count >= [self minimumBarsRequired];
}

- (void)reset {
    self.isCalculated = NO;
    self.outputSeries = nil;
    self.lastError = nil;
}

- (NSString *)displayDescription {
    return [NSString stringWithFormat:@"%@ (%@)", self.name, self.parameters];
}

@end

#pragma mark - Indicator Data Model Implementation

@implementation IndicatorDataModel

+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                       seriesType:(VisualizationType)type {
    return [self dataWithTimestamp:timestamp
                             value:value
                        seriesName:seriesName
                        seriesType:type
                             color:nil
                    priceDirection:PriceDirectionNeutral];
}

+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                       seriesType:(VisualizationType)type
                            color:(NSColor *)color {
    return [self dataWithTimestamp:timestamp
                             value:value
                        seriesName:seriesName
                        seriesType:type
                             color:color
                    priceDirection:PriceDirectionNeutral];
}

+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                       seriesType:(VisualizationType)type
                            color:(NSColor *)color
                   priceDirection:(PriceDirection)priceDirection {
    IndicatorDataModel *model = [[self alloc] init];
    model.timestamp = timestamp;
    model.value = value;
    model.seriesName = seriesName;
    model.seriesType = type;
    model.color = color ?: [NSColor systemBlueColor];
    model.anchorValue = 0.0;
    model.isSignal = NO;
    model.priceDirection = priceDirection;  // ✅ NUOVO
    return model;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %@: %.4f at %@>",
            self.class, self.seriesName, self.value, self.timestamp];
}

@end
