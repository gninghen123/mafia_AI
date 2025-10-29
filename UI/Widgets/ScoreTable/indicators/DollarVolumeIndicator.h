//
//  DollarVolumeIndicator.h
//  TradingApp
//
//  Dollar Volume filter indicator
//

#import <Foundation/Foundation.h>
#import "IndicatorCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Dollar Volume Indicator
 *
 * Formula: (Close × Volume) > Threshold
 *
 * Scoring (Graduated):
 * - >= 5× threshold → +100
 * - >= 3× threshold → +75
 * - >= 2× threshold → +50
 * - >= 1× threshold → +25
 * - < threshold → -100
 *
 * Parameters:
 * - threshold: Minimum dollar volume (default: 10,000,000 = $10M)
 */
@interface DollarVolumeIndicator : NSObject <IndicatorCalculator>

@end

NS_ASSUME_NONNULL_END
