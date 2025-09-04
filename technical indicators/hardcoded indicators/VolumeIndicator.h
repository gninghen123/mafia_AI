//
// VolumeIndicator.h
// TradingApp
//
// Volume data visualizer - displays volume as histogram, line, etc.
// This replaces the missing "VolumeIndicator" referenced in default templates
//

#import "RawDataSeriesIndicator.h"

NS_ASSUME_NONNULL_BEGIN

@interface VolumeIndicator : RawDataSeriesIndicator

#pragma mark - Convenience Factory Methods

/// Create volume histogram (default for volume data)
/// @return VolumeIndicator configured for histogram display
+ (instancetype)histogramIndicator;

/// Create volume line chart
/// @return VolumeIndicator configured for line chart
+ (instancetype)lineIndicator;

/// Create volume area chart
/// @return VolumeIndicator configured for area chart
+ (instancetype)areaIndicator;

#pragma mark - Volume-Specific Methods

/// Get current volume (latest bar)
/// @return Current volume or NAN if not calculated
- (long long)currentVolume;

/// Get volume change from previous bar
/// @return Volume change or NAN if insufficient data
- (long long)volumeChange;

/// Get percentage volume change from previous bar
/// @return Percentage change or NAN if insufficient data
- (double)volumePercentChange;

/// Get average volume over specified period
/// @param period Number of bars to average
/// @return Average volume or NAN if insufficient data
- (double)averageVolume:(NSInteger)period;

/// Check if current volume is above average
/// @param period Period for average calculation
/// @return YES if current volume > average
- (BOOL)isVolumeAboveAverage:(NSInteger)period;

/// Get volume trend (increasing/decreasing)
/// @param period Number of bars to analyze
/// @return Positive for increasing, negative for decreasing, 0 for flat
- (double)volumeTrend:(NSInteger)period;

#pragma mark - Display Configuration

/// Configure for histogram display with volume-based coloring
/// @param highVolumeColor Color for high volume bars
/// @param lowVolumeColor Color for low volume bars
/// @param thresholdMultiplier Multiplier of average volume to determine high/low
- (void)configureHistogramWithHighVolumeColor:(NSColor *)highVolumeColor
                               lowVolumeColor:(NSColor *)lowVolumeColor
                           thresholdMultiplier:(double)thresholdMultiplier;

/// Configure for line display with custom styling
/// @param color Line color
/// @param width Line width
/// @param smoothing Apply smoothing to volume line
- (void)configureLineWithColor:(NSColor *)color
                         width:(CGFloat)width
                     smoothing:(BOOL)smoothing;

@end

NS_ASSUME_NONNULL_END
