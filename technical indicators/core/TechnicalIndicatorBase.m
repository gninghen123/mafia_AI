//
// TechnicalIndicatorBase.m
// TradingApp
//

#import "TechnicalIndicatorBase.h"
#import "TechnicalIndicatorBase+Hierarchy.h"  // ✅ IMPORT NECESSARIO

@implementation TechnicalIndicatorBase

#pragma mark - Initialization

- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {
    if (self = [super init]) {
        _indicatorID = [[NSUUID UUID] UUIDString];
        _type = IndicatorTypeHardcoded;
        _parameters = parameters ?: @{};
        _isCalculated = NO;
        
        // ✅ Set default visualization type
        _visualizationType = [self defaultVisualizationType];
        if (parameters[@"visualizationType"]) {
            _visualizationType = [parameters[@"visualizationType"] integerValue];
        }
        
        // ✅ NUOVO: Inizializza colore immediatamente
        [self initializeDisplayColorFromParameters:parameters];
    }
    return self;
}


- (void)initializeDisplayColorFromParameters:(NSDictionary *)parameters {
    NSColor *initialColor = nil;
    
    // ✅ Cerca colore nei parametri
    if (parameters[@"color"]) {
        id colorParam = parameters[@"color"];
        if ([colorParam isKindOfClass:[NSColor class]]) {
            initialColor = colorParam;
        } else if ([colorParam isKindOfClass:[NSData class]]) {
            initialColor = [NSUnarchiver unarchiveObjectWithData:colorParam];
        }
    }
    
    // ✅ Cerca displayColor nei parametri
    if (!initialColor && parameters[@"displayColor"]) {
        id colorParam = parameters[@"displayColor"];
        if ([colorParam isKindOfClass:[NSColor class]]) {
            initialColor = colorParam;
        } else if ([colorParam isKindOfClass:[NSData class]]) {
            initialColor = [NSUnarchiver unarchiveObjectWithData:colorParam];
        }
    }
    
    // ✅ Se non trovato, usa default per la classe
    if (!initialColor) {
        initialColor = [self getDefaultColorForIndicatorClass];
    }
    
    // ✅ Imposta il colore usando la property (triggera l'Associated Object)
    if (initialColor) {
        self.displayColor = initialColor;
        NSLog(@"🎨 Initialized %@ with color: %@", self.shortName, initialColor);
    } else {
        NSLog(@"⚠️ Could not initialize color for %@", self.shortName);
    }
}

// ✅ NUOVO: Colore default per classe specifica
- (NSColor *)getDefaultColorForIndicatorClass {
    // ✅ Prova defaultParameters della classe
    if ([self.class respondsToSelector:@selector(defaultParameters)]) {
        @try {
            NSDictionary *defaults = [self.class defaultParameters];
            if (defaults[@"color"]) {
                return defaults[@"color"];
            }
        } @catch (NSException *exception) {
            // defaultParameters potrebbe non essere implementato
            NSLog(@"⚠️ defaultParameters not implemented for %@", self.class);
        }
    }
    
    // ✅ Fallback su tipo indicator
    return [self getColorBasedOnIndicatorType] ?: [NSColor systemBlueColor];
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
