//
//  VolumeSpikeIndicator.h
//  TradingApp
//
//  Volume Spike indicator
//

#import <Foundation/Foundation.h>
#import "IndicatorCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Volume Spike Indicator
 *
 * Formula: Volume > SMA(Volume, N) × Coefficient
 *
 * Scoring (Graduated):
 * - Volume >= 3.0× avg → +100
 * - Volume >= 2.5× avg → +85
 * - Volume >= 2.0× avg → +70
 * - Volume >= 1.5× avg → +50
 * - Volume >= 1.0× avg → +25
 * - Volume < 1.0× avg → 0
 * - Volume < 0.5× avg → -50 (dead volume)
 *
 * Parameters:
 * - volumeMAPeriod: Period for volume SMA (default: 20)
 * - baseCoefficient: Minimum threshold multiplier (default: 1.5)
 */
@interface VolumeSpikeIndicator : NSObject <IndicatorCalculator>

@end

NS_ASSUME_NONNULL_END
