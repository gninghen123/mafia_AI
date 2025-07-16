//
//  CHColorUtils.m
//  ChartWidget
//
//  Implementation of color utility functions
//

#import "CHColorUtils.h"

@implementation CHColorUtils

#pragma mark - Color Palette Generation

+ (NSArray<NSColor *> *)generatePaletteOfType:(CHColorPaletteType)type count:(NSInteger)count {
    if (count <= 0) return @[];
    
    switch (type) {
        case CHColorPaletteTypePastel:
            return [self generatePastelColors:count];
            
        case CHColorPaletteTypeVibrant:
            return [self generateVibrantColors:count];
            
        case CHColorPaletteTypeMaterial:
            return [self generateMaterialColors:count];
            
        case CHColorPaletteTypeMonochrome:
            return [self generateMonochromeColors:count];
            
        case CHColorPaletteTypeWarm:
            return [self generateWarmColors:count];
            
        case CHColorPaletteTypeCool:
            return [self generateCoolColors:count];
            
        case CHColorPaletteTypeEarth:
            return [self generateEarthColors:count];
            
        case CHColorPaletteTypeNeon:
            return [self generateNeonColors:count];
            
        case CHColorPaletteTypeRetro:
            return [self generateRetroColors:count];
            
        case CHColorPaletteTypeDefault:
        default:
            return [self generateDefaultColors:count];
    }
}

+ (NSArray<NSColor *> *)generateDefaultColors:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat hue = (CGFloat)i / count;
        NSColor *color = [NSColor colorWithHue:hue saturation:0.7 brightness:0.8 alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generatePastelColors:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat hue = (CGFloat)i / count;
        NSColor *color = [NSColor colorWithHue:hue saturation:0.3 brightness:0.9 alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateVibrantColors:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat hue = (CGFloat)i / count;
        NSColor *color = [NSColor colorWithHue:hue saturation:0.9 brightness:0.9 alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateMaterialColors:(NSInteger)count {
    NSArray *baseColors = @[
        [NSColor colorWithRed:0.96 green:0.26 blue:0.21 alpha:1.0], // Red
        [NSColor colorWithRed:0.91 green:0.12 blue:0.39 alpha:1.0], // Pink
        [NSColor colorWithRed:0.61 green:0.15 blue:0.69 alpha:1.0], // Purple
        [NSColor colorWithRed:0.40 green:0.23 blue:0.72 alpha:1.0], // Deep Purple
        [NSColor colorWithRed:0.25 green:0.32 blue:0.71 alpha:1.0], // Indigo
        [NSColor colorWithRed:0.13 green:0.59 blue:0.95 alpha:1.0], // Blue
        [NSColor colorWithRed:0.01 green:0.66 blue:0.96 alpha:1.0], // Light Blue
        [NSColor colorWithRed:0.00 green:0.74 blue:0.83 alpha:1.0], // Cyan
        [NSColor colorWithRed:0.00 green:0.59 blue:0.53 alpha:1.0], // Teal
        [NSColor colorWithRed:0.30 green:0.69 blue:0.31 alpha:1.0], // Green
        [NSColor colorWithRed:0.55 green:0.76 blue:0.29 alpha:1.0], // Light Green
        [NSColor colorWithRed:0.80 green:0.86 blue:0.22 alpha:1.0], // Lime
        [NSColor colorWithRed:1.00 green:0.92 blue:0.23 alpha:1.0], // Yellow
        [NSColor colorWithRed:1.00 green:0.76 blue:0.03 alpha:1.0], // Amber
        [NSColor colorWithRed:1.00 green:0.60 blue:0.00 alpha:1.0], // Orange
        [NSColor colorWithRed:1.00 green:0.34 blue:0.13 alpha:1.0]  // Deep Orange
    ];
    
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    for (NSInteger i = 0; i < count; i++) {
        [colors addObject:baseColors[i % baseColors.count]];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateMonochromeColors:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat brightness = 0.2 + (0.6 * i / (count - 1));
        NSColor *color = [NSColor colorWithWhite:brightness alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateWarmColors:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        // Warm colors: red to yellow range (0.0 to 0.17)
        CGFloat hue = (CGFloat)i / count * 0.17;
        NSColor *color = [NSColor colorWithHue:hue saturation:0.8 brightness:0.8 alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateCoolColors:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        // Cool colors: green to purple range (0.33 to 0.83)
        CGFloat hue = 0.33 + ((CGFloat)i / count * 0.5);
        NSColor *color = [NSColor colorWithHue:hue saturation:0.7 brightness:0.8 alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateEarthColors:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat factor = (CGFloat)i / count;
        // Earth tones: browns, greens, muted oranges
        CGFloat hue = 0.08 + (factor * 0.1); // Orange to yellow-green
        CGFloat saturation = 0.4 + (factor * 0.2);
        CGFloat brightness = 0.5 + (factor * 0.3);
        
        NSColor *color = [NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateNeonColors:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat hue = (CGFloat)i / count;
        NSColor *color = [NSColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateRetroColors:(NSInteger)count {
    NSArray *baseColors = @[
        [NSColor colorWithRed:0.95 green:0.77 blue:0.06 alpha:1.0], // Mustard
        [NSColor colorWithRed:0.91 green:0.30 blue:0.24 alpha:1.0], // Burnt Orange
        [NSColor colorWithRed:0.18 green:0.37 blue:0.29 alpha:1.0], // Forest Green
        [NSColor colorWithRed:0.40 green:0.20 blue:0.20 alpha:1.0], // Brown
        [NSColor colorWithRed:0.69 green:0.61 blue:0.49 alpha:1.0], // Tan
        [NSColor colorWithRed:0.31 green:0.49 blue:0.55 alpha:1.0], // Teal
        [NSColor colorWithRed:0.82 green:0.65 blue:0.64 alpha:1.0], // Dusty Rose
        [NSColor colorWithRed:0.55 green:0.35 blue:0.31 alpha:1.0]  // Terracotta
    ];
    
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    for (NSInteger i = 0; i < count; i++) {
        [colors addObject:baseColors[i % baseColors.count]];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generatePaletteFromBaseColor:(NSColor *)baseColor count:(NSInteger)count {
    if (count <= 0) return @[];
    if (count == 1) return @[baseColor];
    
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    CGFloat h, s, b, a;
    [[baseColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat factor = (CGFloat)i / (count - 1);
        
        // Vary brightness and saturation
        CGFloat newSaturation = s * (0.5 + factor * 0.5);
        CGFloat newBrightness = b * (0.7 + factor * 0.3);
        
        NSColor *color = [NSColor colorWithHue:h
                                    saturation:newSaturation
                                    brightness:newBrightness
                                         alpha:a];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateComplementaryColorsFromBase:(NSColor *)baseColor count:(NSInteger)count {
    if (count <= 0) return @[];
    
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    CGFloat h, s, b, a;
    [[baseColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    // Add base color
    [colors addObject:baseColor];
    
    if (count > 1) {
        // Add complementary color
        CGFloat complementaryHue = fmod(h + 0.5, 1.0);
        [colors addObject:[NSColor colorWithHue:complementaryHue
                                     saturation:s
                                     brightness:b
                                          alpha:a]];
    }
    
    // Add variations if more colors needed
    for (NSInteger i = 2; i < count; i++) {
        CGFloat variation = (CGFloat)(i - 2) / (count - 2);
        CGFloat variedHue = fmod(h + variation * 0.2, 1.0);
        CGFloat variedSat = s * (0.7 + variation * 0.3);
        
        [colors addObject:[NSColor colorWithHue:variedHue
                                     saturation:variedSat
                                     brightness:b
                                          alpha:a]];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateAnalogousColorsFromBase:(NSColor *)baseColor count:(NSInteger)count {
    if (count <= 0) return @[];
    
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    CGFloat h, s, b, a;
    [[baseColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    CGFloat hueStep = 0.083; // 30 degrees in hue circle
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat offset = ((CGFloat)i - count/2) * hueStep;
        CGFloat newHue = fmod(h + offset + 1.0, 1.0);
        
        [colors addObject:[NSColor colorWithHue:newHue
                                     saturation:s
                                     brightness:b
                                          alpha:a]];
    }
    
    return colors;
}

+ (NSArray<NSColor *> *)generateTriadicColorsFromBase:(NSColor *)baseColor {
    CGFloat h, s, b, a;
    [[baseColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    return @[
        baseColor,
        [NSColor colorWithHue:fmod(h + 0.333, 1.0) saturation:s brightness:b alpha:a],
        [NSColor colorWithHue:fmod(h + 0.667, 1.0) saturation:s brightness:b alpha:a]
    ];
}

#pragma mark - Color Interpolation

+ (NSColor *)interpolateFromColor:(NSColor *)startColor
                          toColor:(NSColor *)endColor
                         progress:(CGFloat)progress {
    progress = MAX(0.0, MIN(1.0, progress));
    
    CGFloat r1, g1, b1, a1;
    CGFloat r2, g2, b2, a2;
    
    [[startColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [[endColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    
    return [NSColor colorWithRed:r1 + (r2 - r1) * progress
                           green:g1 + (g2 - g1) * progress
                            blue:b1 + (b2 - b1) * progress
                           alpha:a1 + (a2 - a1) * progress];
}

+ (NSArray<NSColor *> *)interpolateColors:(NSArray<NSColor *> *)colors steps:(NSInteger)steps {
    if (colors.count < 2 || steps < 2) return colors;
    
    NSMutableArray<NSColor *> *interpolated = [NSMutableArray array];
    CGFloat stepSize = 1.0 / (steps - 1);
    
    for (NSInteger i = 0; i < steps; i++) {
        CGFloat position = i * stepSize;
        CGFloat scaledPosition = position * (colors.count - 1);
        NSInteger colorIndex = (NSInteger)scaledPosition;
        CGFloat localProgress = scaledPosition - colorIndex;
        
        if (colorIndex >= colors.count - 1) {
            [interpolated addObject:[colors lastObject]];
        } else {
            NSColor *color = [self interpolateFromColor:colors[colorIndex]
                                               toColor:colors[colorIndex + 1]
                                              progress:localProgress];
            [interpolated addObject:color];
        }
    }
    
    return interpolated;
}

#pragma mark - Color Analysis

+ (BOOL)isColorLight:(NSColor *)color {
    return [self luminanceOfColor:color] > 0.5;
}

+ (BOOL)isColorDark:(NSColor *)color {
    return ![self isColorLight:color];
}

+ (CGFloat)luminanceOfColor:(NSColor *)color {
    CGFloat r, g, b, a;
    [[color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getRed:&r green:&g blue:&b alpha:&a];
    
    // Calculate relative luminance using WCAG formula
    r = (r <= 0.03928) ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4);
    g = (g <= 0.03928) ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4);
    b = (b <= 0.03928) ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4);
    
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

+ (CGFloat)contrastRatioBetween:(NSColor *)color1 and:(NSColor *)color2 {
    CGFloat luminance1 = [self luminanceOfColor:color1];
    CGFloat luminance2 = [self luminanceOfColor:color2];
    
    CGFloat lighter = MAX(luminance1, luminance2);
    CGFloat darker = MIN(luminance1, luminance2);
    
    return (lighter + 0.05) / (darker + 0.05);
}

#pragma mark - Color Conversion

+ (NSColor *)colorInSRGBSpace:(NSColor *)color {
    return [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
}

+ (NSColor *)colorInDeviceRGBSpace:(NSColor *)color {
    return [color colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
}

+ (NSColor *)colorInCMYKSpace:(NSColor *)color {
    return [color colorUsingColorSpace:[NSColorSpace deviceCMYKColorSpace]];
}

+ (NSColor *)colorWithHue:(CGFloat)hue
               saturation:(CGFloat)saturation
                lightness:(CGFloat)lightness
                    alpha:(CGFloat)alpha {
    // Convert HSL to HSB
    CGFloat brightness = lightness + saturation * MIN(lightness, 1 - lightness);
    CGFloat newSaturation = 0;
    
    if (brightness != 0) {
        newSaturation = 2 * (1 - lightness / brightness);
    }
    
    return [NSColor colorWithHue:hue
                      saturation:newSaturation
                      brightness:brightness
                           alpha:alpha];
}

+ (void)getHue:(CGFloat *)hue
    saturation:(CGFloat *)saturation
     lightness:(CGFloat *)lightness
         alpha:(CGFloat *)alpha
      forColor:(NSColor *)color {
    
    CGFloat h, s, b, a;
    [[color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    // Convert HSB to HSL
    CGFloat l = b * (2 - s) / 2;
    CGFloat newS = 0;
    
    if (l > 0 && l < 1) {
        newS = (b - l) / MIN(l, 1 - l);
    }
    
    if (hue) *hue = h;
    if (saturation) *saturation = newS;
    if (lightness) *lightness = l;
    if (alpha) *alpha = a;
}

#pragma mark - Accessibility

+ (NSColor *)adjustColorForContrast:(NSColor *)color
                   againstBackground:(NSColor *)backgroundColor
                        minimumRatio:(CGFloat)ratio {
    
    CGFloat currentRatio = [self contrastRatioBetween:color and:backgroundColor];
    if (currentRatio >= ratio) return color;
    
    // Determine if we should lighten or darken
    BOOL shouldLighten = [self isColorDark:backgroundColor];
    
    CGFloat h, s, b, a;
    [[color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    // Binary search for the right brightness
    CGFloat minBrightness = shouldLighten ? b : 0;
    CGFloat maxBrightness = shouldLighten ? 1 : b;
    
    while (maxBrightness - minBrightness > 0.01) {
        CGFloat midBrightness = (minBrightness + maxBrightness) / 2;
        NSColor *testColor = [NSColor colorWithHue:h
                                        saturation:s
                                        brightness:midBrightness
                                             alpha:a];
        
        CGFloat testRatio = [self contrastRatioBetween:testColor and:backgroundColor];
        
        if (testRatio < ratio) {
            if (shouldLighten) {
                minBrightness = midBrightness;
            } else {
                maxBrightness = midBrightness;
            }
        } else {
            if (shouldLighten) {
                maxBrightness = midBrightness;
            } else {
                minBrightness = midBrightness;
            }
        }
    }
    
    return [NSColor colorWithHue:h
                      saturation:s
                      brightness:(minBrightness + maxBrightness) / 2
                           alpha:a];
}

+ (BOOL)meetsWCAGContrastRequirement:(NSColor *)foreground
                           background:(NSColor *)background
                                level:(NSString *)level {
    
    CGFloat ratio = [self contrastRatioBetween:foreground and:background];
    
    if ([level isEqualToString:@"AAA"]) {
        return ratio >= 7.0; // AAA level for normal text
    } else {
        return ratio >= 4.5; // AA level for normal text
    }
}

#pragma mark - Gradients

+ (NSGradient *)gradientFromColors:(NSArray<NSColor *> *)colors {
    if (colors.count == 0) return nil;
    if (colors.count == 1) {
        return [[NSGradient alloc] initWithStartingColor:colors[0]
                                              endingColor:colors[0]];
    }
    
    return [[NSGradient alloc] initWithColors:colors];
}

+ (NSGradient *)gradientFromColor:(NSColor *)startColor toColor:(NSColor *)endColor {
    return [[NSGradient alloc] initWithStartingColor:startColor
                                          endingColor:endColor];
}

+ (NSGradient *)radialGradientFromColor:(NSColor *)centerColor toColor:(NSColor *)edgeColor {
    // NSGradient doesn't directly support radial, but we can create a gradient
    // that would work well in a radial context
    return [[NSGradient alloc] initWithColors:@[centerColor, edgeColor]
                                    atLocations:@[@0.0, @1.0]
                                     colorSpace:[NSColorSpace genericRGBColorSpace]];
}

@end
