//
//  ScoreTableWidget_Models.m
//  TradingApp
//

#import "ScoreTableWidget_Models.h"

#pragma mark - Indicator Configuration

@implementation IndicatorConfig

- (instancetype)initWithType:(NSString *)type
                 displayName:(NSString *)displayName
                      weight:(CGFloat)weight
                  parameters:(NSDictionary *)parameters {
    self = [super init];
    if (self) {
        _indicatorType = type;
        _displayName = displayName;
        _weight = weight;
        _parameters = parameters ?: @{};
        _isEnabled = YES;
    }
    return self;
}

- (BOOL)isValid {
    return self.indicatorType.length > 0 &&
           self.displayName.length > 0 &&
           self.weight >= 0 &&
           self.weight <= 100;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.indicatorType forKey:@"indicatorType"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeDouble:self.weight forKey:@"weight"];
    [coder encodeObject:self.parameters forKey:@"parameters"];
    [coder encodeBool:self.isEnabled forKey:@"isEnabled"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _indicatorType = [coder decodeObjectForKey:@"indicatorType"];
        _displayName = [coder decodeObjectForKey:@"displayName"];
        _weight = [coder decodeDoubleForKey:@"weight"];
        _parameters = [coder decodeObjectForKey:@"parameters"];
        _isEnabled = [coder decodeBoolForKey:@"isEnabled"];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<IndicatorConfig: %@ (%.1f%%) %@>",
            self.displayName, self.weight, self.isEnabled ? @"✓" : @"✗"];
}

@end

#pragma mark - Scoring Strategy

@implementation ScoringStrategy

- (instancetype)init {
    self = [super init];
    if (self) {
        _strategyId = [[NSUUID UUID] UUIDString];
        _indicators = [NSMutableArray array];
        _dateCreated = [NSDate date];
        _dateModified = [NSDate date];
    }
    return self;
}

+ (instancetype)strategyWithName:(NSString *)name {
    ScoringStrategy *strategy = [[ScoringStrategy alloc] init];
    strategy.strategyName = name;
    return strategy;
}

- (void)addIndicator:(IndicatorConfig *)indicator {
    [self.indicators addObject:indicator];
    self.dateModified = [NSDate date];
}

- (void)removeIndicatorAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.indicators.count) {
        [self.indicators removeObjectAtIndex:index];
        self.dateModified = [NSDate date];
    }
}

- (BOOL)isValid {
    if (self.strategyName.length == 0) return NO;
    if (self.indicators.count == 0) return NO;
    
    // Check all indicators are valid
    for (IndicatorConfig *indicator in self.indicators) {
        if (!indicator.isValid) return NO;
    }
    
    // Check total weight = 100%
    CGFloat total = [self totalWeight];
    return fabs(total - 100.0) < 0.01; // Allow tiny floating point error
}

- (CGFloat)totalWeight {
    CGFloat total = 0;
    for (IndicatorConfig *indicator in self.indicators) {
        if (indicator.isEnabled) {
            total += indicator.weight;
        }
    }
    return total;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.strategyName forKey:@"strategyName"];
    [coder encodeObject:self.strategyId forKey:@"strategyId"];
    [coder encodeObject:self.indicators forKey:@"indicators"];
    [coder encodeObject:self.dateCreated forKey:@"dateCreated"];
    [coder encodeObject:self.dateModified forKey:@"dateModified"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _strategyName = [coder decodeObjectForKey:@"strategyName"];
        _strategyId = [coder decodeObjectForKey:@"strategyId"];
        _indicators = [coder decodeObjectForKey:@"indicators"];
        _dateCreated = [coder decodeObjectForKey:@"dateCreated"];
        _dateModified = [coder decodeObjectForKey:@"dateModified"];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<ScoringStrategy: %@ (%lu indicators, %.1f%% total weight)>",
            self.strategyName, (unsigned long)self.indicators.count, [self totalWeight]];
}

@end

#pragma mark - Score Result

@implementation ScoreResult

+ (instancetype)resultForSymbol:(NSString *)symbol {
    ScoreResult *result = [[ScoreResult alloc] init];
    result.symbol = symbol;
    result.indicatorScores = [NSMutableDictionary dictionary];
    result.calculatedAt = [NSDate date];
    return result;
}

- (void)setScore:(CGFloat)score forIndicator:(NSString *)indicatorType {
    self.indicatorScores[indicatorType] = @(score);
}

- (CGFloat)scoreForIndicator:(NSString *)indicatorType {
    NSNumber *score = self.indicatorScores[indicatorType];
    return score ? [score doubleValue] : 0.0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<ScoreResult: %@ = %.2f (%lu indicators)>",
            self.symbol, self.totalScore, (unsigned long)self.indicatorScores.count];
}

@end

#pragma mark - Data Requirements

@implementation DataRequirements

+ (instancetype)requirements {
    return [[DataRequirements alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _minimumBars = 0;
        _timeframe = BarTimeframeDaily;
        _needsFundamentals = NO;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DataRequirements: %ld bars, timeframe=%ld>",
            (long)self.minimumBars, (long)self.timeframe];
}

@end

#pragma mark - Validation Result

@implementation ValidationResult

+ (instancetype)validResult {
    ValidationResult *result = [[ValidationResult alloc] init];
    result.isValid = YES;
    result.hasSufficientBars = YES;
    result.hasCompatibleTimeframe = YES;
    result.reason = @"Valid";
    return result;
}

+ (instancetype)invalidResultWithReason:(NSString *)reason {
    ValidationResult *result = [[ValidationResult alloc] init];
    result.isValid = NO;
    result.reason = reason;
    return result;
}

- (NSString *)description {
    if (self.isValid) {
        return @"<ValidationResult: VALID>";
    } else {
        return [NSString stringWithFormat:@"<ValidationResult: INVALID - %@>", self.reason];
    }
}

@end
