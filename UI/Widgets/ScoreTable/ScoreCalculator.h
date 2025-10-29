//
//  ScoreCalculator.h
//  TradingApp
//
//  Core scoring calculation engine
//

#import <Foundation/Foundation.h>
#import "ScoreTableWidget_Models.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Calculates scores for symbols using a scoring strategy
 */
@interface ScoreCalculator : NSObject

/**
 * Calculate scores for multiple symbols
 * @param symbolData Dictionary: symbol → array of HistoricalBarModel
 * @param strategy Scoring strategy to use
 * @return Array of ScoreResult objects
 */
+ (NSArray<ScoreResult *> *)calculateScoresForSymbols:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)symbolData
                                         withStrategy:(ScoringStrategy *)strategy;

/**
 * Calculate score for a single symbol
 * @param symbol Symbol to score
 * @param bars Historical data
 * @param strategy Scoring strategy
 * @return ScoreResult for this symbol
 */
+ (ScoreResult *)calculateScoreForSymbol:(NSString *)symbol
                                withData:(NSArray<HistoricalBarModel *> *)bars
                            usingStrategy:(ScoringStrategy *)strategy;

/**
 * Calculate raw score for a single indicator
 * @param indicator Indicator configuration
 * @param symbol Symbol
 * @param bars Historical data
 * @return Raw score from indicator (-100 to +100 typically)
 */
+ (CGFloat)calculateIndicatorScore:(IndicatorConfig *)indicator
                         forSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars;

@end

NS_ASSUME_NONNULL_END
