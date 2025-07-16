//
//  CHColorUtils.h
//  ChartWidget
//
//  Utility functions for color operations and palettes
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, CHColorPaletteType) {
    CHColorPaletteTypeDefault,
    CHColorPaletteTypePastel,
    CHColorPaletteTypeVibrant,
    CHColorPaletteTypeMaterial,
    CHColorPaletteTypeMonochrome,
    CHColorPaletteTypeWarm,
    CHColorPaletteTypeCool,
    CHColorPaletteTypeEarth,
    CHColorPaletteTypeNeon,
    CHColorPaletteTypeRetro
};

@interface CHColorUtils : NSObject

#pragma mark - Color Palette Generation

// Generate color palette
+ (NSArray<NSColor *> *)generatePaletteOfType:(CHColorPaletteType)type
                                         count:(NSInteger)count;

+ (NSArray<NSColor *> *)generatePaletteFromBaseColor:(NSColor *)baseColor
                                               count:(NSInteger)count;

+ (NSArray<NSColor *> *)generateComplementaryColorsFromBase:(NSColor *)baseColor
                                                      count:(NSInteger)count;

+ (NSArray<NSColor *> *)generateAnalogousColorsFromBase:(NSColor *)baseColor
                                                  count:(NSInteger)count;

+ (NSArray<NSColor *> *)generateTriadicColorsFromBase:(NSColor *)baseColor;

#pragma mark - Color Interpolation

// Interpolate between colors
+ (NSColor *)interpolateFromColor:(NSColor *)startColor
                          toColor:(NSColor *)endColor
                         progress:(CGFloat)progress;

+ (NSArray<NSColor *> *)interpolateColors:(NSArray<NSColor *> *)colors
                                    steps:(NSInteger)steps;

#pragma mark - Color Analysis

// Analyze color properties
+ (BOOL)isColorLight:(NSColor *)color;
+ (BOOL)isColorDark:(NSColor *)color;
+ (CGFloat)luminanceOfColor:(NSColor *)color;
+ (CGFloat)contrastRatioBetween:(NSColor *)color1 and:(NSColor *)color2;

#pragma mark - Color Conversion

// Convert between color spaces
+ (NSColor *)colorInSRGBSpace:(NSColor *)color;
+ (NSColor *)colorInDeviceRGBSpace:(NSColor *)color;
+ (NSColor *)colorInCMYKSpace:(NSColor *)color;

// HSL support
+ (NSColor *)colorWithHue:(CGFloat)hue
               saturation:(CGFloat)saturation
                lightness:(CGFloat)lightness
                    alpha:(CGFloat)alpha;

+ (void)getHue:(CGFloat *)hue
    saturation:(CGFloat *)saturation
     lightness:(CGFloat *)lightness
         alpha:(CGFloat *)alpha
      forColor:(NSColor *)color;

#pragma mark - Accessibility

// WCAG compliance
+ (NSColor *)adjustColorForContrast:(NSColor *)color
                   againstBackground:(NSColor *)backgroundColor
                        minimumRatio:(CGFloat)ratio;

+ (BOOL)meetsWCAGContrastRequirement:(NSColor *)foreground
                           background:(NSColor *)background
                                level:(NSString *)level; // "AA" or "AAA"

#pragma mark - Gradients

// Create gradients
+ (NSGradient *)gradientFromColors:(NSArray<NSColor *> *)colors;
+ (NSGradient *)gradientFromColor:(NSColor *)startColor
                          toColor:(NSColor *)endColor;
+ (NSGradient *)radialGradientFromColor:(NSColor *)centerColor
                                toColor:(NSColor *)edgeColor;

@end
