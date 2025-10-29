//
//  UNRIndicator.h
//  TradingApp
//
//  Undercut and Reclaim indicator
//

#import <Foundation/Foundation.h>
#import "IndicatorCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * UNR (Undercut and Reclaim) Indicator
 *
 * Formula:
 * - Undercut: low <= EMA
 * - Reclaim: close >= EMA
 *
 * Searches for pattern in last N days:
 * - Same bar (low <= EMA AND close >= EMA) → High weight
 * - Next bar (bar1: low <= EMA, bar2: close >= EMA) → Medium weight
 *
 * Scoring:
 * - UNR today (same bar) → +100
 * - UNR today (next bar) → +70
 * - UNR yesterday (same bar) → +80
 * - Decay: -20% per day older
 * - No UNR found → 0
 *
 * Parameters:
 * - maType: "EMA" or "SMA" (default: EMA)
 * - maPeriod: Period for MA (default: 10)
 * - lookbackDays: Days to search back (default: 5)
 * - sameBarWeight: Weight multiplier for same-bar UNR (default: 1.0)
 * - nextBarWeight: Weight multiplier for next-bar UNR (default: 0.7)
 */
@interface UNRIndicator : NSObject <IndicatorCalculator>

@end

NS_ASSUME_NONNULL_END
