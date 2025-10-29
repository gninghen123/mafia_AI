//
//  PriceVsMAIndicator.h
//  TradingApp
//
//  Price vs Moving Average position indicator
//

#import <Foundation/Foundation.h>
#import "IndicatorCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Price vs MA Position Indicator
 *
 * Formula: Compares selected price points (low/close/open/high) with MA
 *
 * Example: "Close > EMA(10)" = bullish position
 *
 * Scoring:
 * - All selected points satisfy condition → +100
 * - 3/4 → +75
 * - 2/4 → +50
 * - 1/4 → +25
 * - 0/4 → -100
 *
 * Parameters:
 * - maType: "SMA" or "EMA" (default: EMA)
 * - maPeriod: Period for MA (default: 10)
 * - pricePoints: Array of ["low", "close", "open", "high"] to check (default: ["close"])
 * - condition: "above" or "below" (default: "above")
 */
@interface PriceVsMAIndicator : NSObject <IndicatorCalculator>

@end

NS_ASSUME_NONNULL_END
