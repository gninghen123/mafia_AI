//
//  AscendingLowsIndicator.h
//  TradingApp
//
//  Ascending Lows (uptrend) indicator
//

#import <Foundation/Foundation.h>
#import "IndicatorCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Ascending Lows Indicator
 *
 * Formula: Checks if lows are consecutively ascending
 * low[0] > low[1] > low[2] > low[3] > low[4]
 *
 * Scoring (Graduated):
 * - 5/5 ascending → +100 (strong uptrend)
 * - 4/5 → +75
 * - 3/5 → +50
 * - 2/5 → +25
 * - <2/5 → -100
 *
 * Parameters:
 * - lookbackDays: Number of days to check (default: 5)
 */
@interface AscendingLowsIndicator : NSObject <IndicatorCalculator>

@end

NS_ASSUME_NONNULL_END
