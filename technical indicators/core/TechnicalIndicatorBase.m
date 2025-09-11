//
// TechnicalIndicatorBase.m
//

#import "TechnicalIndicatorBase.h"

@implementation TechnicalIndicatorBase

- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {
    self = [super init];
    if (self) {
        // Generate unique ID
        _indicatorID = [[NSUUID UUID] UUIDString];
        
        // Set parameters (with validation)
        NSError *error;
        if (![self validateParameters:parameters error:&error]) {
            NSLog(@"❌ TechnicalIndicatorBase: Invalid parameters for %@: %@", self.class, error.localizedDescription);
            return nil;
        }
        
        _parameters = [parameters copy] ?: @{};
        _type = IndicatorTypeHardcoded;  // Default, can be overridden
        
        // Initialize state
        _isCalculated = NO;
        self.outputSeries = nil;
        self.lastError = nil;
    }
    return self;
}

- (instancetype)init {
    return [self initWithParameters:[[self class] defaultParameters]];
}

#pragma mark - Abstract Methods (Must be overridden)

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"calculateWithBars: must be overridden by subclass"
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
                visualizationType:(VisualizationType)type {
    return [self dataWithTimestamp:timestamp
                             value:value
                        seriesName:seriesName
                 visualizationType:type
                             color:nil];
}

+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                visualizationType:(VisualizationType)type
                            color:(NSColor *)color {
    IndicatorDataModel *model = [[self alloc] init];
    model.timestamp = timestamp;
    model.value = value;
    model.seriesName = seriesName;
    model.visualizationType = type;
    model.color = color ?: [NSColor systemBlueColor];  // Default color
    model.anchorValue = 0.0;
    model.isSignal = NO;
    return model;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %@: %.4f at %@>",
            self.class, self.seriesName, self.value, self.timestamp];
}

@end
