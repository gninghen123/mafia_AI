//
//  ChartCoordinateContext.h
//  TradingApp
//
//  Unified coordinate conversion context for all chart renderers
//  Handles Y ↔ Value conversions with high performance for real-time interactions
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@class HistoricalBarModel;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Chart Coordinate Context

/// Unified coordinate conversion context for chart panels
/// Provides consistent Y ↔ value conversions for alerts, objects, and chart rendering
@interface ChartCoordinateContext : NSObject

#pragma mark - Chart Data Context

/// Current chart data displayed in the panel
@property (nonatomic, strong, nullable) NSArray<HistoricalBarModel *> *chartData;

/// Visible data range indices
@property (nonatomic, assign) NSInteger visibleStartIndex;
@property (nonatomic, assign) NSInteger visibleEndIndex;

/// Y-axis value range (price/indicator range)
@property (nonatomic, assign) double yRangeMin;
@property (nonatomic, assign) double yRangeMax;

/// Panel bounds for coordinate calculations
@property (nonatomic, assign) CGRect panelBounds;

#pragma mark - Trading Context (for X-axis calculations)

/// Number of bars per trading day (for date-based X coordinate calculations)
@property (nonatomic, assign) NSInteger barsPerDay;

/// Current timeframe in minutes (for trading hours calculations)
@property (nonatomic, assign) NSInteger currentTimeframeMinutes;

/// Current symbol (for alert rendering context)
@property (nonatomic, strong, nullable) NSString *currentSymbol;

#pragma mark - Primary Y ↔ Value Conversion Methods

/// Convert indicator value to screen Y coordinate
/// @param value Value of indicator (price, RSI, volume, etc.)
/// @return Y coordinate in pixels from top of panel
- (CGFloat)screenYForValue:(double)value;

/// Convert screen Y coordinate to indicator value
/// @param screenY Y coordinate in pixels from top of panel
/// @return Corresponding indicator value
- (double)valueForScreenY:(CGFloat)screenY;

/// Check if coordinate context is valid for conversions
/// @return YES if all required parameters are set for conversions
- (BOOL)isValidForConversion;


#pragma mark - X Coordinate Conversion Methods (NEW)

/// Convert bar index to screen X coordinate of BAR CENTER
/// @param barIndex Index in chartData array
/// @return X coordinate in pixels at CENTER of bar space
- (CGFloat)screenXForBarCenter:(NSInteger)barIndex;


/// Convert bar index to screen X coordinate using unified chart layout
/// @param barIndex Index in chartData array
/// @return X coordinate in pixels from left of panel (left edge of bar space)
- (CGFloat)screenXForBarIndex:(NSInteger)barIndex;

/// Convert screen X coordinate to bar index using unified chart layout
/// @param screenX X coordinate in pixels from left of panel
/// @return Bar index in chartData array, clamped to visible range
- (NSInteger)barIndexForScreenX:(CGFloat)screenX;

/// Convert date to screen X coordinate with extrapolation support
/// @param date Target date to locate
/// @return X coordinate in pixels, or -9999 if calculation failed
- (CGFloat)screenXForDate:(NSDate *)date;

/// Get chart area width (excluding Y-axis)
/// @return Available width for chart content in pixels
- (CGFloat)chartAreaWidth;

/// Get bar width for current zoom level
/// @return Width of each bar space in pixels (including spacing)
- (CGFloat)barWidth;

/// Get bar spacing for current zoom level
/// @return Spacing between bars in pixels
- (CGFloat)barSpacing;


#pragma mark - Normalized Conversion Utilities

/// Convert normalized Y coordinate (0.0-1.0) to indicator value
/// @param normalizedY Value between 0.0 (bottom) and 1.0 (top)
/// @return Indicator value
- (double)valueForNormalizedY:(double)normalizedY;

/// Convert indicator value to normalized Y coordinate (0.0-1.0)
/// @param value Indicator value
/// @return Normalized value between 0.0 (bottom) and 1.0 (top)
- (double)normalizedYForValue:(double)value;

#pragma mark - Legacy Compatibility Methods

/// Legacy method for ChartAlertRenderer compatibility
/// @param triggerValue Alert trigger price value
/// @return Y coordinate in panel
- (CGFloat)screenYForTriggerValue:(double)triggerValue;

/// Legacy method for ChartAlertRenderer compatibility
/// @param screenY Y coordinate in panel
/// @return Alert trigger price value
- (double)triggerValueForScreenY:(CGFloat)screenY;

/// Legacy method for ChartObjectRenderer compatibility
/// @param screenY Y coordinate in panel
/// @return Price value
- (CGFloat)priceFromScreenY:(CGFloat)screenY;

/// Legacy method for ChartPanelView compatibility
/// @param price Price value
/// @return Y coordinate in panel
- (CGFloat)yCoordinateForPrice:(double)price;

@end

NS_ASSUME_NONNULL_END
