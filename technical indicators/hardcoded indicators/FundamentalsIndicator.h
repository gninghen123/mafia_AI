//
// FundamentalsIndicator.h
// TradingApp
//
// Fundamentals data visualizer - displays revenue, EPS, debt/equity, etc.
// FUTURE IMPLEMENTATION - demonstrates system extensibility
//

#import "RawDataSeriesIndicator.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FundamentalDataType) {
    FundamentalDataTypeRevenue,           // Quarterly/Annual revenue
    FundamentalDataTypeEPS,               // Earnings per share
    FundamentalDataTypeDebtEquityRatio,   // Debt to equity ratio
    FundamentalDataTypePERatio,           // Price to earnings ratio
    FundamentalDataTypeCashFlow,          // Operating cash flow
    FundamentalDataTypeBookValue,         // Book value per share
    FundamentalDataTypeROE,               // Return on equity
    FundamentalDataTypeROA,               // Return on assets
    FundamentalDataTypeMargins            // Profit margins
};

typedef NS_ENUM(NSInteger, FundamentalPeriod) {
    FundamentalPeriodQuarterly,           // Quarterly data
    FundamentalPeriodAnnual,              // Annual data
    FundamentalPeriodTTM                  // Trailing twelve months
};

@interface FundamentalsIndicator : RawDataSeriesIndicator

#pragma mark - Fundamental-Specific Properties
@property (nonatomic, assign) FundamentalDataType fundamentalType;
@property (nonatomic, assign) FundamentalPeriod period;
@property (nonatomic, assign) BOOL adjustForSplits;    // Adjust historical data for stock splits
@property (nonatomic, assign) BOOL showGrowthRate;     // Display YoY growth rate

#pragma mark - Factory Methods

/// Create revenue visualizer
/// @param period Data period (quarterly/annual)
/// @return FundamentalsIndicator for revenue
+ (instancetype)revenueIndicatorWithPeriod:(FundamentalPeriod)period;

/// Create EPS visualizer
/// @param period Data period
/// @return FundamentalsIndicator for EPS
+ (instancetype)epsIndicatorWithPeriod:(FundamentalPeriod)period;

/// Create debt/equity ratio visualizer
/// @return FundamentalsIndicator for debt/equity
+ (instancetype)debtEquityIndicator;

/// Create P/E ratio visualizer
/// @return FundamentalsIndicator for P/E ratio
+ (instancetype)peRatioIndicator;

#pragma mark - Fundamental-Specific Methods

/// Get latest fundamental value
/// @return Latest value or NAN if not available
- (double)latestFundamentalValue;

/// Get year-over-year growth rate
/// @return Growth rate percentage or NAN
- (double)yoyGrowthRate;

/// Get quarter-over-quarter growth rate
/// @return Growth rate percentage or NAN
- (double)qoqGrowthRate;

/// Get trend over specified periods
/// @param periods Number of periods to analyze
/// @return Trend percentage
- (double)trendOverPeriods:(NSInteger)periods;

/// Check if metric is improving
/// @return YES if trend is positive
- (BOOL)isImproving;

@end

NS_ASSUME_NONNULL_END
