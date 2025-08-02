//
//  SeasonalDataModel.h
//  TradingApp
//
//  Runtime model for seasonal quarterly data analysis
//

#import <Foundation/Foundation.h>

@class QuarterlyDataPoint;

NS_ASSUME_NONNULL_BEGIN

@interface SeasonalDataModel : NSObject <NSCopying>

// Core properties
@property (nonatomic, strong) NSString *symbol;        // "AAPL", "MSFT", etc.
@property (nonatomic, strong) NSString *dataType;      // "revenue", "eps", "gross_margin", etc.
@property (nonatomic, strong) NSArray<QuarterlyDataPoint *> *quarters; // Sorted by year, quarter

// Metadata
@property (nonatomic, strong, nullable) NSString *currency;    // "USD", "EUR", etc.
@property (nonatomic, strong, nullable) NSString *units;       // "millions", "billions", "per_share"
@property (nonatomic, strong) NSDate *lastUpdated;

// Initialization
+ (instancetype)modelWithSymbol:(NSString *)symbol
                       dataType:(NSString *)dataType
                       quarters:(NSArray<QuarterlyDataPoint *> *)quarters;

- (instancetype)initWithSymbol:(NSString *)symbol
                      dataType:(NSString *)dataType
                      quarters:(NSArray<QuarterlyDataPoint *> *)quarters;

#pragma mark - Data Access

// Find specific quarters
- (nullable QuarterlyDataPoint *)quarterForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (nullable QuarterlyDataPoint *)latestQuarter;
- (nullable QuarterlyDataPoint *)oldestQuarter;

// Get data ranges
- (NSArray<QuarterlyDataPoint *> *)quartersForYear:(NSInteger)year;
- (NSArray<QuarterlyDataPoint *> *)lastNQuarters:(NSInteger)count;
- (NSArray<QuarterlyDataPoint *> *)quartersInRange:(NSRange)yearRange;

#pragma mark - Calculated Metrics

// Year-over-Year changes
- (double)yoyChangeForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (double)yoyPercentChangeForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (nullable QuarterlyDataPoint *)yoyComparisonQuarterFor:(NSInteger)quarter year:(NSInteger)year;

// Quarter-over-Quarter changes
- (double)qoqChangeForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (double)qoqPercentChangeForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (nullable QuarterlyDataPoint *)qoqComparisonQuarterFor:(NSInteger)quarter year:(NSInteger)year;

// TTM (Trailing Twelve Months) calculations
- (double)ttmValueForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (double)ttmChangeForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (double)ttmPercentChangeForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (NSArray<QuarterlyDataPoint *> *)ttmQuartersForQuarter:(NSInteger)quarter year:(NSInteger)year;

// Growth rates and trends
- (double)averageYoyGrowthRate; // Average YoY growth across all available quarters
- (double)compoundQuarterlyGrowthRate; // CQGR across full time series
- (BOOL)isGrowingTrend; // Simple trend analysis

#pragma mark - Data Management

// Add/update data
- (void)addQuarter:(QuarterlyDataPoint *)quarter;
- (void)addQuarters:(NSArray<QuarterlyDataPoint *> *)newQuarters;
- (void)updateQuarter:(QuarterlyDataPoint *)quarter;
- (void)removeQuarter:(NSInteger)quarter year:(NSInteger)year;

// Sort and clean
- (void)sortQuarters; // Ensures quarters are properly sorted
- (void)removeDuplicateQuarters;
- (void)fillMissingQuarters; // Adds zero-value quarters for missing periods if needed

#pragma mark - Statistics

// Basic stats
- (double)minValue;
- (double)maxValue;
- (double)averageValue;
- (double)medianValue;
- (double)standardDeviation;

// Seasonal patterns
- (double)averageValueForQuarter:(NSInteger)quarter; // Average across all years for specific quarter
- (NSInteger)bestPerformingQuarter; // Quarter (1-4) with highest average
- (NSInteger)worstPerformingQuarter; // Quarter (1-4) with lowest average

#pragma mark - Validation

- (BOOL)isValid;
- (BOOL)hasDataForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (BOOL)canCalculateYoyForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (BOOL)canCalculateQoqForQuarter:(NSInteger)quarter year:(NSInteger)year;
- (BOOL)canCalculateTTMForQuarter:(NSInteger)quarter year:(NSInteger)year;

// Coverage analysis
- (NSInteger)dataPointCount;
- (NSInteger)yearsCovered;
- (NSRange)yearRange; // Min and max years
- (double)dataCompleteness; // Percentage of expected quarters that have data

@end

NS_ASSUME_NONNULL_END
