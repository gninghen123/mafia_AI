//
//  DataRequirementCalculator.h
//  TradingApp
//
//  Calculates minimum data requirements for a scoring strategy
//

#import <Foundation/Foundation.h>
#import "ScoreTableWidget_Models.h"
#import "IndicatorCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Analyzes a scoring strategy and determines minimum data requirements
 */
@interface DataRequirementCalculator : NSObject

/**
 * Calculate requirements for a strategy
 * @param strategy The scoring strategy to analyze
 * @return DataRequirements object with minimum bars, timeframe, etc.
 */
+ (DataRequirements *)calculateRequirementsForStrategy:(ScoringStrategy *)strategy;

/**
 * Calculate requirements for a single indicator
 * @param indicator The indicator config to analyze
 * @return Minimum bars required for this indicator
 */
+ (NSInteger)minimumBarsForIndicator:(IndicatorConfig *)indicator;

/**
 * Get indicator calculator instance for a type
 * @param indicatorType Type string (e.g., "RSI", "MACD")
 * @return Calculator instance or nil if not found
 */
+ (id<IndicatorCalculator>)calculatorForType:(NSString *)indicatorType;

@end

NS_ASSUME_NONNULL_END
