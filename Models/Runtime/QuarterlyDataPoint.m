//
//  QuarterlyDataPoint.m
//  TradingApp
//

#import "QuarterlyDataPoint.h"

@implementation QuarterlyDataPoint

#pragma mark - Class Methods

+ (instancetype)dataPointWithQuarter:(NSInteger)quarter
                                 year:(NSInteger)year
                                value:(double)value {
    return [[self alloc] initWithQuarter:quarter year:year value:value quarterEndDate:nil];
}

+ (instancetype)dataPointWithQuarter:(NSInteger)quarter
                                 year:(NSInteger)year
                                value:(double)value
                       quarterEndDate:(NSDate *)quarterEndDate {
    return [[self alloc] initWithQuarter:quarter year:year value:value quarterEndDate:quarterEndDate];
}

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithQuarter:1 year:2024 value:0.0 quarterEndDate:nil];
}

- (instancetype)initWithQuarter:(NSInteger)quarter
                           year:(NSInteger)year
                          value:(double)value
                 quarterEndDate:(NSDate *)quarterEndDate {
    self = [super init];
    if (self) {
        _quarter = quarter;
        _year = year;
        _value = value;
        _quarterEndDate = quarterEndDate;
    }
    return self;
}

#pragma mark - Computed Properties

- (NSString *)quarterString {
    if (self.quarterEndDate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"M/d/yy";
        NSString *dateString = [formatter stringFromDate:self.quarterEndDate];
        return [NSString stringWithFormat:@"Q%ld %@", (long)self.quarter, dateString];
    } else {
        return [self shortQuarterString];
    }
}

- (NSString *)shortQuarterString {
    return [NSString stringWithFormat:@"Q%ld'%02ld", (long)self.quarter, (long)(self.year % 100)];
}

- (NSDate *)estimatedQuarterEndDate {
    if (self.quarterEndDate) {
        return self.quarterEndDate;
    }
    
    // Estimate calendar quarter end dates
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = self.year;
    
    switch (self.quarter) {
        case 1:
            components.month = 3;
            components.day = 31;
            break;
        case 2:
            components.month = 6;
            components.day = 30;
            break;
        case 3:
            components.month = 9;
            components.day = 30;
            break;
        case 4:
            components.month = 12;
            components.day = 31;
            break;
        default:
            components.month = 12;
            components.day = 31;
            break;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    return [calendar dateFromComponents:components];
}

#pragma mark - Comparison

- (NSComparisonResult)compare:(QuarterlyDataPoint *)other {
    if (!other) return NSOrderedDescending;
    
    // First compare by year
    if (self.year < other.year) return NSOrderedAscending;
    if (self.year > other.year) return NSOrderedDescending;
    
    // Then by quarter
    if (self.quarter < other.quarter) return NSOrderedAscending;
    if (self.quarter > other.quarter) return NSOrderedDescending;
    
    return NSOrderedSame;
}

- (BOOL)isSameQuarterAs:(QuarterlyDataPoint *)other {
    return (self.quarter == other.quarter && self.year == other.year);
}

- (BOOL)isYearOverYearCounterpartOf:(QuarterlyDataPoint *)other {
    return (self.quarter == other.quarter && self.year == other.year + 1);
}

#pragma mark - Quarter Calculations

- (QuarterlyDataPoint *)previousQuarter {
    NSInteger prevQuarter = self.quarter - 1;
    NSInteger prevYear = self.year;
    
    if (prevQuarter < 1) {
        prevQuarter = 4;
        prevYear--;
    }
    
    return [QuarterlyDataPoint dataPointWithQuarter:prevQuarter
                                               year:prevYear
                                              value:0.0]; // Value not relevant for navigation
}

- (QuarterlyDataPoint *)previousYearSameQuarter {
    return [QuarterlyDataPoint dataPointWithQuarter:self.quarter
                                               year:self.year - 1
                                              value:0.0];
}

- (QuarterlyDataPoint *)nextQuarter {
    NSInteger nextQuarter = self.quarter + 1;
    NSInteger nextYear = self.year;
    
    if (nextQuarter > 4) {
        nextQuarter = 1;
        nextYear++;
    }
    
    return [QuarterlyDataPoint dataPointWithQuarter:nextQuarter
                                               year:nextYear
                                              value:0.0];
}

#pragma mark - Validation

- (BOOL)isValidQuarter {
    return (self.quarter >= 1 && self.quarter <= 4 && self.year > 1900 && self.year < 3000);
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    QuarterlyDataPoint *copy = [[QuarterlyDataPoint allocWithZone:zone] init];
    if (copy) {
        copy.quarter = self.quarter;
        copy.year = self.year;
        copy.value = self.value;
        copy.quarterEndDate = [self.quarterEndDate copy];
    }
    return copy;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[QuarterlyDataPoint class]]) return NO;
    
    QuarterlyDataPoint *other = (QuarterlyDataPoint *)object;
    return [self isSameQuarterAs:other] && self.value == other.value;
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%ld-%ld-%.2f",
             (long)self.year, (long)self.quarter, self.value] hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> %@ value:%.2f%@",
            NSStringFromClass([self class]),
            self,
            self.quarterString,
            self.value,
            self.quarterEndDate ? [NSString stringWithFormat:@" date:%@", self.quarterEndDate] : @""];
}

@end
