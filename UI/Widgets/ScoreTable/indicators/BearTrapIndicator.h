//
//  BearTrapIndicator.h
//  TradingApp
//
//  Bear Trap (undercut) indicator
//

#import <Foundation/Foundation.h>
#import "IndicatorCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Bear Trap Indicator
 *
 * Formula: Checks if low[0] < low[1]
 * Simple undercut detection
 *
 * Scoring (Binary):
 * - low[0] < low[1] → +100 (possible trap/shakeout)
 * - low[0] >= low[1] → -100
 *
 * Parameters: None
 */
@interface BearTrapIndicator : NSObject <IndicatorCalculator>

@end

NS_ASSUME_NONNULL_END
