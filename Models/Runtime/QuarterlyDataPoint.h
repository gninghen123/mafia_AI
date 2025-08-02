//
//  QuarterlyDataPoint.h
//  TradingApp
//
//  Runtime model for quarterly financial data points
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QuarterlyDataPoint : NSObject <NSCopying>

// Core data
@property (nonatomic, assign) NSInteger quarter;        // 1, 2, 3, 4
@property (nonatomic, assign) NSInteger year;          // 2024, 2025, etc.
@property (nonatomic, assign) double value;           // Revenue/EPS/whatever metric
@property (nonatomic, strong, nullable) NSDate *quarterEndDate; // Actual quarter end date if available

// Computed properties
@property (nonatomic, readonly) NSString *quarterString;     // "Q1'25" or "Q1 3/31/25"
@property (nonatomic, readonly) NSString *shortQuarterString; // Always "Q1'25"
@property (nonatomic, readonly) NSDate *estimatedQuarterEndDate; // Calculated if actual date missing

// Initialization
+ (instancetype)dataPointWithQuarter:(NSInteger)quarter
                                 year:(NSInteger)year
                                value:(double)value;

+ (instancetype)dataPointWithQuarter:(NSInteger)quarter
                                 year:(NSInteger)year
                                value:(double)value
                       quarterEndDate:(nullable NSDate *)quarterEndDate;

- (instancetype)initWithQuarter:(NSInteger)quarter
                           year:(NSInteger)year
                          value:(double)value
                 quarterEndDate:(nullable NSDate *)quarterEndDate;

// Comparison
- (NSComparisonResult)compare:(QuarterlyDataPoint *)other;
- (BOOL)isSameQuarterAs:(QuarterlyDataPoint *)other;
- (BOOL)isYearOverYearCounterpartOf:(QuarterlyDataPoint *)other;

// Quarter calculations
- (QuarterlyDataPoint *)previousQuarter; // Returns quarter/year for previous quarter
- (QuarterlyDataPoint *)previousYearSameQuarter; // Returns quarter/year for same quarter last year
- (QuarterlyDataPoint *)nextQuarter; // Returns quarter/year for next quarter

// Validation
- (BOOL)isValidQuarter;

@end

NS_ASSUME_NONNULL_END
