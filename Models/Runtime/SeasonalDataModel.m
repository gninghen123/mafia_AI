//
//  SeasonalDataModel.m
//  TradingApp
//

#import "SeasonalDataModel.h"
#import "QuarterlyDataPoint.h"

@interface SeasonalDataModel ()
@property (nonatomic, strong) NSMutableArray<QuarterlyDataPoint *> *mutableQuarters;
@end

@implementation SeasonalDataModel

#pragma mark - Class Methods

+ (instancetype)modelWithSymbol:(NSString *)symbol
                       dataType:(NSString *)dataType
                       quarters:(NSArray<QuarterlyDataPoint *> *)quarters {
    return [[self alloc] initWithSymbol:symbol dataType:dataType quarters:quarters];
}

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithSymbol:@"" dataType:@"" quarters:@[]];
}

- (instancetype)initWithSymbol:(NSString *)symbol
                      dataType:(NSString *)dataType
                      quarters:(NSArray<QuarterlyDataPoint *> *)quarters {
    self = [super init];
    if (self) {
        _symbol = [symbol copy];
        _dataType = [dataType copy];
        _mutableQuarters = [quarters mutableCopy];
        _lastUpdated = [NSDate date];
        
        [self sortQuarters];
    }
    return self;
}

#pragma mark - Properties

- (NSArray<QuarterlyDataPoint *> *)quarters {
    return [self.mutableQuarters copy];
}

- (void)setQuarters:(NSArray<QuarterlyDataPoint *> *)quarters {
    self.mutableQuarters = [quarters mutableCopy];
    [self sortQuarters];
}

#pragma mark - Data Access

- (QuarterlyDataPoint *)quarterForQuarter:(NSInteger)quarter year:(NSInteger)year {
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        if (point.quarter == quarter && point.year == year) {
            return point;
        }
    }
    return nil;
}

- (QuarterlyDataPoint *)latestQuarter {
    if (self.mutableQuarters.count == 0) return nil;
    return self.mutableQuarters.lastObject; // Assumes sorted order
}

- (QuarterlyDataPoint *)oldestQuarter {
    if (self.mutableQuarters.count == 0) return nil;
    return self.mutableQuarters.firstObject; // Assumes sorted order
}

- (NSArray<QuarterlyDataPoint *> *)quartersForYear:(NSInteger)year {
    NSMutableArray *result = [NSMutableArray array];
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        if (point.year == year) {
            [result addObject:point];
        }
    }
    return result;
}

- (NSArray<QuarterlyDataPoint *> *)lastNQuarters:(NSInteger)count {
    if (count <= 0 || self.mutableQuarters.count == 0) return @[];
    
    NSInteger startIndex = MAX(0, self.mutableQuarters.count - count);
    return [self.mutableQuarters subarrayWithRange:NSMakeRange(startIndex, self.mutableQuarters.count - startIndex)];
}

- (NSArray<QuarterlyDataPoint *> *)quartersInRange:(NSRange)yearRange {
    NSMutableArray *result = [NSMutableArray array];
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        if (point.year >= yearRange.location && point.year < yearRange.location + yearRange.length) {
            [result addObject:point];
        }
    }
    return result;
}

#pragma mark - Calculated Metrics

- (double)yoyChangeForQuarter:(NSInteger)quarter year:(NSInteger)year {
    QuarterlyDataPoint *current = [self quarterForQuarter:quarter year:year];
    QuarterlyDataPoint *previous = [self quarterForQuarter:quarter year:year - 1];
    
    if (!current || !previous) return 0.0;
    
    return current.value - previous.value;
}

- (double)yoyPercentChangeForQuarter:(NSInteger)quarter year:(NSInteger)year {
    QuarterlyDataPoint *current = [self quarterForQuarter:quarter year:year];
    QuarterlyDataPoint *previous = [self quarterForQuarter:quarter year:year - 1];
    
    if (!current || !previous || previous.value == 0.0) return 0.0;
    
    return ((current.value - previous.value) / ABS(previous.value)) * 100.0;
}

- (QuarterlyDataPoint *)yoyComparisonQuarterFor:(NSInteger)quarter year:(NSInteger)year {
    return [self quarterForQuarter:quarter year:year - 1];
}

- (double)qoqChangeForQuarter:(NSInteger)quarter year:(NSInteger)year {
    QuarterlyDataPoint *current = [self quarterForQuarter:quarter year:year];
    
    // Calculate previous quarter
    NSInteger prevQuarter = quarter - 1;
    NSInteger prevYear = year;
    if (prevQuarter < 1) {
        prevQuarter = 4;
        prevYear--;
    }
    
    QuarterlyDataPoint *previous = [self quarterForQuarter:prevQuarter year:prevYear];
    
    if (!current || !previous) return 0.0;
    
    return current.value - previous.value;
}

- (double)qoqPercentChangeForQuarter:(NSInteger)quarter year:(NSInteger)year {
    QuarterlyDataPoint *current = [self quarterForQuarter:quarter year:year];
    
    NSInteger prevQuarter = quarter - 1;
    NSInteger prevYear = year;
    if (prevQuarter < 1) {
        prevQuarter = 4;
        prevYear--;
    }
    
    QuarterlyDataPoint *previous = [self quarterForQuarter:prevQuarter year:prevYear];
    
    if (!current || !previous || previous.value == 0.0) return 0.0;
    
    return ((current.value - previous.value) / ABS(previous.value)) * 100.0;
}

- (QuarterlyDataPoint *)qoqComparisonQuarterFor:(NSInteger)quarter year:(NSInteger)year {
    NSInteger prevQuarter = quarter - 1;
    NSInteger prevYear = year;
    if (prevQuarter < 1) {
        prevQuarter = 4;
        prevYear--;
    }
    
    return [self quarterForQuarter:prevQuarter year:prevYear];
}

- (double)ttmValueForQuarter:(NSInteger)quarter year:(NSInteger)year {
    NSArray<QuarterlyDataPoint *> *ttmQuarters = [self ttmQuartersForQuarter:quarter year:year];
    
    if (ttmQuarters.count != 4) return 0.0;
    
    double total = 0.0;
    for (QuarterlyDataPoint *point in ttmQuarters) {
        total += point.value;
    }
    
    return total;
}

- (double)ttmChangeForQuarter:(NSInteger)quarter year:(NSInteger)year {
    double currentTTM = [self ttmValueForQuarter:quarter year:year];
    
    // Previous quarter TTM
    NSInteger prevQuarter = quarter - 1;
    NSInteger prevYear = year;
    if (prevQuarter < 1) {
        prevQuarter = 4;
        prevYear--;
    }
    
    double previousTTM = [self ttmValueForQuarter:prevQuarter year:prevYear];
    
    if (currentTTM == 0.0 || previousTTM == 0.0) return 0.0;
    
    return currentTTM - previousTTM;
}

- (double)ttmPercentChangeForQuarter:(NSInteger)quarter year:(NSInteger)year {
    double currentTTM = [self ttmValueForQuarter:quarter year:year];
    
    NSInteger prevQuarter = quarter - 1;
    NSInteger prevYear = year;
    if (prevQuarter < 1) {
        prevQuarter = 4;
        prevYear--;
    }
    
    double previousTTM = [self ttmValueForQuarter:prevQuarter year:prevYear];
    
    if (currentTTM == 0.0 || previousTTM == 0.0) return 0.0;
    
    return ((currentTTM - previousTTM) / ABS(previousTTM)) * 100.0;
}

- (NSArray<QuarterlyDataPoint *> *)ttmQuartersForQuarter:(NSInteger)quarter year:(NSInteger)year {
    NSMutableArray *ttmQuarters = [NSMutableArray array];
    
    NSInteger currentQuarter = quarter;
    NSInteger currentYear = year;
    
    // Collect last 4 quarters including current
    for (NSInteger i = 0; i < 4; i++) {
        QuarterlyDataPoint *point = [self quarterForQuarter:currentQuarter year:currentYear];
        if (point) {
            [ttmQuarters insertObject:point atIndex:0]; // Insert at beginning for chronological order
        } else {
            return @[]; // Missing data, can't calculate TTM
        }
        
        // Go to previous quarter
        currentQuarter--;
        if (currentQuarter < 1) {
            currentQuarter = 4;
            currentYear--;
        }
    }
    
    return ttmQuarters;
}

- (double)averageYoyGrowthRate {
    NSMutableArray *yoyRates = [NSMutableArray array];
    
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        if ([self canCalculateYoyForQuarter:point.quarter year:point.year]) {
            double yoyPercent = [self yoyPercentChangeForQuarter:point.quarter year:point.year];
            [yoyRates addObject:@(yoyPercent)];
        }
    }
    
    if (yoyRates.count == 0) return 0.0;
    
    double sum = 0.0;
    for (NSNumber *rate in yoyRates) {
        sum += rate.doubleValue;
    }
    
    return sum / yoyRates.count;
}

- (double)compoundQuarterlyGrowthRate {
    if (self.mutableQuarters.count < 2) return 0.0;
    
    QuarterlyDataPoint *oldest = [self oldestQuarter];
    QuarterlyDataPoint *latest = [self latestQuarter];
    
    if (!oldest || !latest || oldest.value <= 0) return 0.0;
    
    NSInteger quartersDiff = (latest.year - oldest.year) * 4 + (latest.quarter - oldest.quarter);
    if (quartersDiff <= 0) return 0.0;
    
    return (pow(latest.value / oldest.value, 1.0 / quartersDiff) - 1.0) * 100.0;
}

- (BOOL)isGrowingTrend {
    if (self.mutableQuarters.count < 3) return NO;
    
    NSArray *lastThree = [self lastNQuarters:3];
    
    return (lastThree[1].value > lastThree[0].value &&
            lastThree[2].value > lastThree[1].value);
}

#pragma mark - Data Management

- (void)addQuarter:(QuarterlyDataPoint *)quarter {
    if (!quarter || ![quarter isValidQuarter]) return;
    
    // Remove existing quarter if it exists
    [self removeQuarter:quarter.quarter year:quarter.year];
    
    // Add new quarter
    [self.mutableQuarters addObject:quarter];
    [self sortQuarters];
}

- (void)addQuarters:(NSArray<QuarterlyDataPoint *> *)newQuarters {
    for (QuarterlyDataPoint *quarter in newQuarters) {
        [self addQuarter:quarter];
    }
}

- (void)updateQuarter:(QuarterlyDataPoint *)quarter {
    [self addQuarter:quarter]; // addQuarter already handles replacement
}

- (void)removeQuarter:(NSInteger)quarter year:(NSInteger)year {
    QuarterlyDataPoint *existingQuarter = [self quarterForQuarter:quarter year:year];
    if (existingQuarter) {
        [self.mutableQuarters removeObject:existingQuarter];
    }
}

- (void)sortQuarters {
    [self.mutableQuarters sortUsingComparator:^NSComparisonResult(QuarterlyDataPoint *obj1, QuarterlyDataPoint *obj2) {
        return [obj1 compare:obj2];
    }];
}

- (void)removeDuplicateQuarters {
    NSMutableArray *uniqueQuarters = [NSMutableArray array];
    NSMutableSet *seenQuarters = [NSMutableSet set];
    
    for (QuarterlyDataPoint *quarter in self.mutableQuarters) {
        NSString *key = [NSString stringWithFormat:@"%ld-%ld", (long)quarter.year, (long)quarter.quarter];
        if (![seenQuarters containsObject:key]) {
            [seenQuarters addObject:key];
            [uniqueQuarters addObject:quarter];
        }
    }
    
    self.mutableQuarters = uniqueQuarters;
}

- (void)fillMissingQuarters {
    if (self.mutableQuarters.count < 2) return;
    
    QuarterlyDataPoint *oldest = [self oldestQuarter];
    QuarterlyDataPoint *latest = [self latestQuarter];
    
    NSMutableArray *allQuarters = [NSMutableArray array];
    
    NSInteger currentQuarter = oldest.quarter;
    NSInteger currentYear = oldest.year;
    
    while (currentYear < latest.year || (currentYear == latest.year && currentQuarter <= latest.quarter)) {
        QuarterlyDataPoint *existing = [self quarterForQuarter:currentQuarter year:currentYear];
        if (existing) {
            [allQuarters addObject:existing];
        } else {
            // Add missing quarter with zero value
            QuarterlyDataPoint *missing = [QuarterlyDataPoint dataPointWithQuarter:currentQuarter
                                                                               year:currentYear
                                                                              value:0.0];
            [allQuarters addObject:missing];
        }
        
        currentQuarter++;
        if (currentQuarter > 4) {
            currentQuarter = 1;
            currentYear++;
        }
    }
    
    self.mutableQuarters = allQuarters;
}

#pragma mark - Statistics

- (double)minValue {
    if (self.mutableQuarters.count == 0) return 0.0;
    
    double min = self.mutableQuarters[0].value;
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        if (point.value < min) min = point.value;
    }
    return min;
}

- (double)maxValue {
    if (self.mutableQuarters.count == 0) return 0.0;
    
    double max = self.mutableQuarters[0].value;
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        if (point.value > max) max = point.value;
    }
    return max;
}

- (double)averageValue {
    if (self.mutableQuarters.count == 0) return 0.0;
    
    double sum = 0.0;
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        sum += point.value;
    }
    return sum / self.mutableQuarters.count;
}

- (double)medianValue {
    if (self.mutableQuarters.count == 0) return 0.0;
    
    NSArray *sortedValues = [self.mutableQuarters sortedArrayUsingComparator:^NSComparisonResult(QuarterlyDataPoint *obj1, QuarterlyDataPoint *obj2) {
        if (obj1.value < obj2.value) return NSOrderedAscending;
        if (obj1.value > obj2.value) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    NSInteger count = sortedValues.count;
    if (count % 2 == 0) {
        // Even number of elements
        QuarterlyDataPoint *mid1 = sortedValues[count/2 - 1];
        QuarterlyDataPoint *mid2 = sortedValues[count/2];
        return (mid1.value + mid2.value) / 2.0;
    } else {
        // Odd number of elements
        return ((QuarterlyDataPoint *)sortedValues[count/2]).value;
    }
}

- (double)standardDeviation {
    if (self.mutableQuarters.count <= 1) return 0.0;
    
    double average = [self averageValue];
    double variance = 0.0;
    
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        double diff = point.value - average;
        variance += diff * diff;
    }
    
    variance /= (self.mutableQuarters.count - 1); // Sample standard deviation
    return sqrt(variance);
}

- (double)averageValueForQuarter:(NSInteger)quarter {
    NSMutableArray *quarterValues = [NSMutableArray array];
    
    for (QuarterlyDataPoint *point in self.mutableQuarters) {
        if (point.quarter == quarter) {
            [quarterValues addObject:@(point.value)];
        }
    }
    
    if (quarterValues.count == 0) return 0.0;
    
    double sum = 0.0;
    for (NSNumber *value in quarterValues) {
        sum += value.doubleValue;
    }
    
    return sum / quarterValues.count;
}

- (NSInteger)bestPerformingQuarter {
    double bestAverage = -INFINITY;
    NSInteger bestQuarter = 1;
    
    for (NSInteger quarter = 1; quarter <= 4; quarter++) {
        double average = [self averageValueForQuarter:quarter];
        if (average > bestAverage) {
            bestAverage = average;
            bestQuarter = quarter;
        }
    }
    
    return bestQuarter;
}

- (NSInteger)worstPerformingQuarter {
    double worstAverage = INFINITY;
    NSInteger worstQuarter = 1;
    
    for (NSInteger quarter = 1; quarter <= 4; quarter++) {
        double average = [self averageValueForQuarter:quarter];
        if (average < worstAverage && average != 0.0) { // Exclude quarters with no data
            worstAverage = average;
            worstQuarter = quarter;
        }
    }
    
    return worstQuarter;
}

#pragma mark - Validation

- (BOOL)isValid {
    return (self.symbol.length > 0 &&
            self.dataType.length > 0 &&
            self.mutableQuarters.count > 0);
}

- (BOOL)hasDataForQuarter:(NSInteger)quarter year:(NSInteger)year {
    return [self quarterForQuarter:quarter year:year] != nil;
}

- (BOOL)canCalculateYoyForQuarter:(NSInteger)quarter year:(NSInteger)year {
    return ([self hasDataForQuarter:quarter year:year] &&
            [self hasDataForQuarter:quarter year:year - 1]);
}

- (BOOL)canCalculateQoqForQuarter:(NSInteger)quarter year:(NSInteger)year {
    NSInteger prevQuarter = quarter - 1;
    NSInteger prevYear = year;
    if (prevQuarter < 1) {
        prevQuarter = 4;
        prevYear--;
    }
    
    return ([self hasDataForQuarter:quarter year:year] &&
            [self hasDataForQuarter:prevQuarter year:prevYear]);
}

- (BOOL)canCalculateTTMForQuarter:(NSInteger)quarter year:(NSInteger)year {
    NSArray *ttmQuarters = [self ttmQuartersForQuarter:quarter year:year];
    return ttmQuarters.count == 4;
}

- (NSInteger)dataPointCount {
    return self.mutableQuarters.count;
}

- (NSInteger)yearsCovered {
    if (self.mutableQuarters.count == 0) return 0;
    
    NSRange range = [self yearRange];
    return range.length;
}

- (NSRange)yearRange {
    if (self.mutableQuarters.count == 0) return NSMakeRange(0, 0);
    
    QuarterlyDataPoint *oldest = [self oldestQuarter];
    QuarterlyDataPoint *latest = [self latestQuarter];
    
    NSInteger minYear = oldest.year;
    NSInteger maxYear = latest.year;
    
    return NSMakeRange(minYear, maxYear - minYear + 1);
}

- (double)dataCompleteness {
    if (self.mutableQuarters.count == 0) return 0.0;
    
    NSRange range = [self yearRange];
    NSInteger expectedQuarters = range.length * 4;
    
    return (double)self.mutableQuarters.count / expectedQuarters;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    SeasonalDataModel *copy = [[SeasonalDataModel allocWithZone:zone] init];
    if (copy) {
        copy.symbol = [self.symbol copy];
        copy.dataType = [self.dataType copy];
        copy.currency = [self.currency copy];
        copy.units = [self.units copy];
        copy.lastUpdated = [self.lastUpdated copy];
        
        // Deep copy quarters
        NSMutableArray *copiedQuarters = [NSMutableArray array];
        for (QuarterlyDataPoint *quarter in self.mutableQuarters) {
            [copiedQuarters addObject:[quarter copy]];
        }
        copy.mutableQuarters = copiedQuarters;
    }
    return copy;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[SeasonalDataModel class]]) return NO;
    
    SeasonalDataModel *other = (SeasonalDataModel *)object;
    return ([self.symbol isEqualToString:other.symbol] &&
            [self.dataType isEqualToString:other.dataType] &&
            [self.quarters isEqualToArray:other.quarters]);
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%@-%@-%lu",
             self.symbol, self.dataType, (unsigned long)self.quarters.count] hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> symbol:%@ dataType:%@ quarters:%lu years:%ld completeness:%.1f%%",
            NSStringFromClass([self class]),
            self,
            self.symbol,
            self.dataType,
            (unsigned long)self.dataPointCount,
            (long)self.yearsCovered,
            self.dataCompleteness * 100.0];
}

@end
