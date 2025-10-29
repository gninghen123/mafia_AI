//
//  ScoreCalculator.m
//  TradingApp
//

#import "ScoreCalculator.h"
#import "DataRequirementCalculator.h"

@implementation ScoreCalculator

+ (NSArray<ScoreResult *> *)calculateScoresForSymbols:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)symbolData
                                         withStrategy:(ScoringStrategy *)strategy {
    
    if (!symbolData || symbolData.count == 0) {
        NSLog(@"⚠️ ScoreCalculator: No symbol data provided");
        return @[];
    }
    
    if (!strategy || !strategy.isValid) {
        NSLog(@"⚠️ ScoreCalculator: Invalid strategy");
        return @[];
    }
    
    NSLog(@"🎯 ScoreCalculator: Calculating scores for %lu symbols with strategy '%@'",
          (unsigned long)symbolData.count, strategy.strategyName);
    
    NSMutableArray<ScoreResult *> *results = [NSMutableArray array];
    
    // Calculate score for each symbol
    for (NSString *symbol in symbolData.allKeys) {
        @autoreleasepool {
            NSArray<HistoricalBarModel *> *bars = symbolData[symbol];
            
            ScoreResult *result = [self calculateScoreForSymbol:symbol
                                                       withData:bars
                                                  usingStrategy:strategy];
            
            if (result) {
                [results addObject:result];
            }
        }
    }
    
    NSLog(@"✅ ScoreCalculator: Completed %lu scores", (unsigned long)results.count);
    
    return [results copy];
}

+ (ScoreResult *)calculateScoreForSymbol:(NSString *)symbol
                                withData:(NSArray<HistoricalBarModel *> *)bars
                            usingStrategy:(ScoringStrategy *)strategy {
    
    ScoreResult *result = [ScoreResult resultForSymbol:symbol];
    
    if (!bars || bars.count == 0) {
        result.error = [NSError errorWithDomain:@"ScoreCalculator"
                                           code:1001
                                       userInfo:@{NSLocalizedDescriptionKey: @"No data available"}];
        NSLog(@"❌ ScoreCalculator: No data for %@", symbol);
        return result;
    }
    
    CGFloat weightedScoreTotal = 0.0;
    CGFloat totalWeightUsed = 0.0;
    
    // Calculate each indicator
    for (IndicatorConfig *indicator in strategy.indicators) {
        if (!indicator.isEnabled) {
            NSLog(@"⏭️ Skipping disabled indicator: %@", indicator.displayName);
            continue;
        }
        
        @autoreleasepool {
            CGFloat rawScore = [self calculateIndicatorScore:indicator
                                                   forSymbol:symbol
                                                    withData:bars];
            
            // Store raw score
            [result setScore:rawScore forIndicator:indicator.indicatorType];
            
            // Apply weight
            CGFloat weightedScore = rawScore * (indicator.weight / 100.0);
            weightedScoreTotal += weightedScore;
            totalWeightUsed += indicator.weight;
            
            NSLog(@"   %@ [%.1f%%]: raw=%.1f → weighted=%.1f",
                  indicator.displayName, indicator.weight, rawScore, weightedScore);
        }
    }
    
    // Normalize if weights don't sum to 100 (shouldn't happen if strategy is valid)
    if (totalWeightUsed > 0 && fabs(totalWeightUsed - 100.0) > 0.01) {
        NSLog(@"⚠️ Warning: Weights sum to %.1f%%, normalizing", totalWeightUsed);
        weightedScoreTotal = (weightedScoreTotal / totalWeightUsed) * 100.0;
    }
    
    result.totalScore = weightedScoreTotal;
    
    NSLog(@"🎯 %@ TOTAL SCORE: %.2f", symbol, result.totalScore);
    
    return result;
}

+ (CGFloat)calculateIndicatorScore:(IndicatorConfig *)indicator
                         forSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars {
    
    // Get calculator for this indicator type
    id<IndicatorCalculator> calculator = [DataRequirementCalculator calculatorForType:indicator.indicatorType];
    
    if (!calculator) {
        NSLog(@"❌ No calculator found for indicator type: %@", indicator.indicatorType);
        return 0.0;
    }
    
    // Calculate score
    @try {
        CGFloat score = [calculator calculateScoreForSymbol:symbol
                                                   withData:bars
                                                 parameters:indicator.parameters];
        return score;
    }
    @catch (NSException *exception) {
        NSLog(@"❌ Exception calculating %@ for %@: %@",
              indicator.indicatorType, symbol, exception.reason);
        return 0.0;
    }
}

@end
