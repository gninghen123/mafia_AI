//
//  CHChartUtils.h
//  ChartWidget
//
//  Utility functions for chart calculations and formatting
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface CHChartUtils : NSObject

#pragma mark - Number Formatting

// Format a number for display on axes
+ (NSString *)formattedStringForNumber:(CGFloat)number;
+ (NSString *)formattedStringForNumber:(CGFloat)number decimals:(NSInteger)decimals;
+ (NSString *)abbreviatedStringForNumber:(CGFloat)number; // 1K, 1M, etc.

#pragma mark - Scale Calculations

// Calculate nice round numbers for axis scales
+ (CGFloat)niceMinimumForRange:(CGFloat)min max:(CGFloat)max;
+ (CGFloat)niceMaximumForRange:(CGFloat)min max:(CGFloat)max;
+ (NSArray<NSNumber *> *)niceTickValuesForMin:(CGFloat)min max:(CGFloat)max count:(NSInteger)count;

#pragma mark - Date Formatting

// Format dates for time-series charts
+ (NSString *)formattedStringForDate:(NSDate *)date style:(NSDateFormatterStyle)style;
+ (NSString *)formattedStringForTimeInterval:(NSTimeInterval)interval;

#pragma mark - Color Utilities

// Generate colors for series
+ (NSArray<NSColor *> *)generateColorsForSeriesCount:(NSInteger)count;
+ (NSColor *)colorByAdjustingBrightness:(NSColor *)color factor:(CGFloat)factor;
+ (NSColor *)contrastingColorForColor:(NSColor *)color;

#pragma mark - Geometry Utilities

// Calculate positions and sizes
+ (CGRect)rectByInsetting:(CGRect)rect edgeInsets:(NSEdgeInsets)insets;
+ (CGPoint)centerOfRect:(CGRect)rect;
+ (CGFloat)distanceBetweenPoint:(CGPoint)p1 andPoint:(CGPoint)p2;
+ (CGPoint)pointOnCircleWithCenter:(CGPoint)center radius:(CGFloat)radius angle:(CGFloat)angle;

#pragma mark - Animation Easing

// Easing functions for animations
+ (CGFloat)easeInQuad:(CGFloat)t;
+ (CGFloat)easeOutQuad:(CGFloat)t;
+ (CGFloat)easeInOutQuad:(CGFloat)t;
+ (CGFloat)easeInCubic:(CGFloat)t;
+ (CGFloat)easeOutCubic:(CGFloat)t;
+ (CGFloat)easeInOutCubic:(CGFloat)t;
+ (CGFloat)easeInElastic:(CGFloat)t;
+ (CGFloat)easeOutElastic:(CGFloat)t;
+ (CGFloat)easeOutBounce:(CGFloat)t;

#pragma mark - Data Processing

// Statistical calculations
+ (CGFloat)meanOfValues:(NSArray<NSNumber *> *)values;
+ (CGFloat)medianOfValues:(NSArray<NSNumber *> *)values;
+ (CGFloat)standardDeviationOfValues:(NSArray<NSNumber *> *)values;
+ (CGFloat)sumOfValues:(NSArray<NSNumber *> *)values;

// Data smoothing
+ (NSArray<NSNumber *> *)movingAverageOfValues:(NSArray<NSNumber *> *)values window:(NSInteger)window;
+ (NSArray<NSNumber *> *)exponentialSmoothingOfValues:(NSArray<NSNumber *> *)values alpha:(CGFloat)alpha;

@end
