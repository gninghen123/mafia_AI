//
//  IndicatorCalculator.h
//  TradingApp
//
//  Base protocol for all indicator calculators
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol that all indicator calculators must implement
 */
@protocol IndicatorCalculator <NSObject>

@required

/**
 * Calculate score for a symbol
 * @param symbol Symbol to calculate for
 * @param bars Historical data (sorted oldest to newest)
 * @param params Custom parameters for the indicator
 * @return Score value (typically -100 to +100 or 0 to +100)
 */
- (CGFloat)calculateScoreForSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars
                        parameters:(NSDictionary *)params;

/**
 * Unique identifier for this indicator type
 */
- (NSString *)indicatorType;

/**
 * Human-readable name
 */
- (NSString *)displayName;

/**
 * Minimum number of bars required for calculation
 */
- (NSInteger)minimumBarsRequired;

/**
 * Default parameters for this indicator
 */
- (NSDictionary *)defaultParameters;

@optional

/**
 * Detailed description of what this indicator measures
 */
- (NSString *)indicatorDescription;

/**
 * Parameter validation
 */
- (BOOL)validateParameters:(NSDictionary *)params error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
