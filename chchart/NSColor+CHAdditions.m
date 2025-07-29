//
//  NSColor+CHAdditions.m
//  ChartWidget
//
//  Implementation of NSColor category
//

#import "NSColor+CHAdditions.h"

@implementation NSColor (CHAdditions)

#pragma mark - Color Manipulation

- (NSColor *)ch_colorWithAlpha:(CGFloat)alpha {
    return [self colorWithAlphaComponent:alpha];
}

- (NSColor *)ch_lighterColor {
    return [self ch_lighterColorByFactor:0.2];
}

- (NSColor *)ch_darkerColor {
    return [self ch_darkerColorByFactor:0.2];
}

- (NSColor *)ch_lighterColorByFactor:(CGFloat)factor {
    CGFloat h, s, b, a;
    [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    b = MIN(1.0, b + factor);
    return [NSColor colorWithHue:h saturation:s brightness:b alpha:a];
}

- (NSColor *)ch_darkerColorByFactor:(CGFloat)factor {
    CGFloat h, s, b, a;
    [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    b = MAX(0.0, b - factor);
    return [NSColor colorWithHue:h saturation:s brightness:b alpha:a];
}

- (NSColor *)ch_saturatedColorByFactor:(CGFloat)factor {
    CGFloat h, s, b, a;
    [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    s = MIN(1.0, s + factor);
    return [NSColor colorWithHue:h saturation:s brightness:b alpha:a];
}

- (NSColor *)ch_desaturatedColorByFactor:(CGFloat)factor {
    CGFloat h, s, b, a;
    [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&h saturation:&s brightness:&b alpha:&a];
    
    s = MAX(0.0, s - factor);
    return [NSColor colorWithHue:h saturation:s brightness:b alpha:a];
}

#pragma mark - Color Blending

- (NSColor *)ch_blendedColorWithColor:(NSColor *)color fraction:(CGFloat)fraction {
    fraction = MAX(0.0, MIN(1.0, fraction));
    
    CGFloat r1, g1, b1, a1;
    CGFloat r2, g2, b2, a2;
    
    [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [[color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    
    CGFloat r = r1 + (r2 - r1) * fraction;
    CGFloat g = g1 + (g2 - g1) * fraction;
    CGFloat b = b1 + (b2 - b1) * fraction;
    CGFloat a = a1 + (a2 - a1) * fraction;
    
    return [NSColor colorWithRed:r green:g blue:b alpha:a];
}

#pragma mark - Color Components

- (CGFloat)ch_luminance {
    CGFloat r, g, b, a;
    [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getRed:&r green:&g blue:&b alpha:&a];
    
    // ITU-R BT.709 formula
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

- (BOOL)ch_isLight {
    return [self ch_luminance] > 0.5;
}

- (BOOL)ch_isDark {
    return ![self ch_isLight];
}

#pragma mark - Hex Support

+ (NSColor *)ch_colorWithHexString:(NSString *)hexString {
    NSString *cleanString = [[hexString stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    if ([cleanString hasPrefix:@"#"]) {
        cleanString = [cleanString substringFromIndex:1];
    } else if ([cleanString hasPrefix:@"0X"]) {
        cleanString = [cleanString substringFromIndex:2];
    }
    
    NSInteger length = cleanString.length;
    
    // Handle 3-character hex codes
    if (length == 3) {
        NSMutableString *expanded = [NSMutableString string];
        for (NSInteger i = 0; i < 3; i++) {
            NSString *character = [cleanString substringWithRange:NSMakeRange(i, 1)];
            [expanded appendString:character];
            [expanded appendString:character];
        }
        cleanString = expanded;
        length = 6;
    }
    
    if (length != 6 && length != 8) {
        return nil;
    }
    
    unsigned int red, green, blue, alpha = 255;
    NSScanner *scanner = [NSScanner scannerWithString:cleanString];
    
    [scanner scanHexInt:&red];
    
    if (length == 6) {
        red = (red >> 16) & 0xFF;
        green = (red >> 8) & 0xFF;
        blue = red & 0xFF;
    } else {
        // 8 characters - includes alpha
        alpha = red & 0xFF;
        red = (red >> 24) & 0xFF;
        green = (red >> 16) & 0xFF;
        blue = (red >> 8) & 0xFF;
    }
    
    return [NSColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:alpha/255.0];
}

- (NSString *)ch_hexString {
    return [self ch_hexStringWithAlpha:NO];
}

- (NSString *)ch_hexStringWithAlpha:(BOOL)includeAlpha {
    CGFloat r, g, b, a;
    [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getRed:&r green:&g blue:&b alpha:&a];
    
    int red = (int)(r * 255);
    int green = (int)(g * 255);
    int blue = (int)(b * 255);
    int alpha = (int)(a * 255);
    
    if (includeAlpha) {
        return [NSString stringWithFormat:@"#%02X%02X%02X%02X", red, green, blue, alpha];
    } else {
        return [NSString stringWithFormat:@"#%02X%02X%02X", red, green, blue];
    }
}

#pragma mark - Predefined Chart Colors

+ (NSArray<NSColor *> *)ch_defaultChartColors {
    return @[
        [NSColor systemBlueColor],
        [NSColor systemRedColor],
        [NSColor systemGreenColor],
        [NSColor systemOrangeColor],
        [NSColor systemPurpleColor],
        [NSColor systemYellowColor],
        [NSColor systemBrownColor],
        [NSColor systemPinkColor],
        [NSColor systemTealColor],
        [NSColor systemIndigoColor]
    ];
}

+ (NSArray<NSColor *> *)ch_materialDesignColors {
    return @[
        [self ch_colorWithHexString:@"#2196F3"], // Blue
        [self ch_colorWithHexString:@"#F44336"], // Red
        [self ch_colorWithHexString:@"#4CAF50"], // Green
        [self ch_colorWithHexString:@"#FF9800"], // Orange
        [self ch_colorWithHexString:@"#9C27B0"], // Purple
        [self ch_colorWithHexString:@"#FFEB3B"], // Yellow
        [self ch_colorWithHexString:@"#795548"], // Brown
        [self ch_colorWithHexString:@"#E91E63"], // Pink
        [self ch_colorWithHexString:@"#00BCD4"], // Cyan
        [self ch_colorWithHexString:@"#3F51B5"]  // Indigo
    ];
}

+ (NSArray<NSColor *> *)ch_pastelColors {
    return @[
        [self ch_colorWithHexString:@"#B3E5FC"], // Light Blue
        [self ch_colorWithHexString:@"#FFCDD2"], // Light Red
        [self ch_colorWithHexString:@"#C8E6C9"], // Light Green
        [self ch_colorWithHexString:@"#FFE0B2"], // Light Orange
        [self ch_colorWithHexString:@"#E1BEE7"], // Light Purple
        [self ch_colorWithHexString:@"#FFF9C4"], // Light Yellow
        [self ch_colorWithHexString:@"#D7CCC8"], // Light Brown
        [self ch_colorWithHexString:@"#F8BBD0"], // Light Pink
        [self ch_colorWithHexString:@"#B2EBF2"], // Light Cyan
        [self ch_colorWithHexString:@"#C5CAE9"]  // Light Indigo
    ];
}

+ (NSArray<NSColor *> *)ch_vibrantColors {
    return @[
        [self ch_colorWithHexString:@"#FF006E"], // Vibrant Pink
        [self ch_colorWithHexString:@"#FB5607"], // Vibrant Orange
        [self ch_colorWithHexString:@"#FFBE0B"], // Vibrant Yellow
        [self ch_colorWithHexString:@"#8338EC"], // Vibrant Purple
        [self ch_colorWithHexString:@"#3A86FF"], // Vibrant Blue
        [self ch_colorWithHexString:@"#06FFB4"], // Vibrant Mint
        [self ch_colorWithHexString:@"#FF4365"], // Vibrant Coral
        [self ch_colorWithHexString:@"#00F5FF"], // Vibrant Cyan
        [self ch_colorWithHexString:@"#B91C1C"], // Vibrant Red
        [self ch_colorWithHexString:@"#16DB93"]  // Vibrant Green
    ];
}

+ (NSArray<NSColor *> *)ch_monochromaticColorsFromBase:(NSColor *)baseColor count:(NSInteger)count {
    if (count <= 0) return @[];
    if (count == 1) return @[baseColor];
    
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat factor = (CGFloat)i / (count - 1);
        NSColor *color;
        
        if (i < count / 2) {
            // Darker variations
            color = [baseColor ch_darkerColorByFactor:factor * 0.5];
        } else {
            // Lighter variations
            color = [baseColor ch_lighterColorByFactor:(factor - 0.5) * 0.5];
        }
        
        [colors addObject:color];
    }
    
    return colors;
}

#pragma mark - Gradients

- (NSGradient *)ch_gradientToColor:(NSColor *)endColor {
    return [[NSGradient alloc] initWithStartingColor:self endingColor:endColor];
}

- (NSGradient *)ch_gradientWithColors:(NSArray<NSColor *> *)colors {
    NSMutableArray<NSColor *> *allColors = [NSMutableArray arrayWithObject:self];
    [allColors addObjectsFromArray:colors];
    return [[NSGradient alloc] initWithColors:allColors];
}

@end
