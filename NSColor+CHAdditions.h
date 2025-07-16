//
//  NSColor+CHAdditions.h
//  ChartWidget
//
//  NSColor category with convenience methods for charts
//

#import <Cocoa/Cocoa.h>

@interface NSColor (CHAdditions)

// Color manipulation
- (NSColor *)ch_colorWithAlpha:(CGFloat)alpha;
- (NSColor *)ch_lighterColor;
- (NSColor *)ch_darkerColor;
- (NSColor *)ch_lighterColorByFactor:(CGFloat)factor;
- (NSColor *)ch_darkerColorByFactor:(CGFloat)factor;
- (NSColor *)ch_saturatedColorByFactor:(CGFloat)factor;
- (NSColor *)ch_desaturatedColorByFactor:(CGFloat)factor;

// Color blending
- (NSColor *)ch_blendedColorWithColor:(NSColor *)color fraction:(CGFloat)fraction;

// Color components
- (CGFloat)ch_luminance;
- (BOOL)ch_isLight;
- (BOOL)ch_isDark;

// Hex support
+ (NSColor *)ch_colorWithHexString:(NSString *)hexString;
- (NSString *)ch_hexString;
- (NSString *)ch_hexStringWithAlpha:(BOOL)includeAlpha;

// Predefined chart colors
+ (NSArray<NSColor *> *)ch_defaultChartColors;
+ (NSArray<NSColor *> *)ch_materialDesignColors;
+ (NSArray<NSColor *> *)ch_pastelColors;
+ (NSArray<NSColor *> *)ch_vibrantColors;
+ (NSArray<NSColor *> *)ch_monochromaticColorsFromBase:(NSColor *)baseColor count:(NSInteger)count;

// Gradients
- (NSGradient *)ch_gradientToColor:(NSColor *)endColor;
- (NSGradient *)ch_gradientWithColors:(NSArray<NSColor *> *)colors;

@end
