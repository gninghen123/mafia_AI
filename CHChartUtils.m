//
//  CHChartUtils.m
//  ChartWidget
//
//  Implementation of chart utility functions
//

#import "CHChartUtils.h"

@implementation CHChartUtils

#pragma mark - Number Formatting

+ (NSString *)formattedStringForNumber:(CGFloat)number {
    return [self formattedStringForNumber:number decimals:-1];
}

+ (NSString *)formattedStringForNumber:(CGFloat)number decimals:(NSInteger)decimals {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    
    if (decimals >= 0) {
        formatter.minimumFractionDigits = decimals;
        formatter.maximumFractionDigits = decimals;
    } else {
        // Auto-determine decimal places
        if (fabs(number) >= 100) {
            formatter.maximumFractionDigits = 0;
        } else if (fabs(number) >= 10) {
            formatter.maximumFractionDigits = 1;
        } else if (fabs(number) >= 1) {
            formatter.maximumFractionDigits = 2;
        } else {
            formatter.maximumFractionDigits = 3;
        }
    }
    
    return [formatter stringFromNumber:@(number)];
}

+ (NSString *)abbreviatedStringForNumber:(CGFloat)number {
    NSArray *suffixes = @[@"", @"K", @"M", @"B", @"T"];
    NSInteger suffixIndex = 0;
    CGFloat absNumber = fabs(number);
    
    while (absNumber >= 1000 && suffixIndex < suffixes.count - 1) {
        absNumber /= 1000;
        suffixIndex++;
    }
    
    NSString *format;
    if (absNumber >= 100) {
        format = @"%.0f%@";
    } else if (absNumber >= 10) {
        format = @"%.1f%@";
    } else {
        format = @"%.2f%@";
    }
    
    CGFloat displayNumber = (number < 0) ? -absNumber : absNumber;
    return [NSString stringWithFormat:format, displayNumber, suffixes[suffixIndex]];
}

#pragma mark - Scale Calculations

+ (CGFloat)niceMinimumForRange:(CGFloat)min max:(CGFloat)max {
    CGFloat range = max - min;
    if (range == 0) return min - 1;
    
    CGFloat padding = range * 0.1;
    CGFloat niceMin = min - padding;
    
    // Round down to nice number
    CGFloat magnitude = pow(10, floor(log10(fabs(niceMin))));
    return floor(niceMin / magnitude) * magnitude;
}

+ (CGFloat)niceMaximumForRange:(CGFloat)min max:(CGFloat)max {
    CGFloat range = max - min;
    if (range == 0) return max + 1;
    
    CGFloat padding = range * 0.1;
    CGFloat niceMax = max + padding;
    
    // Round up to nice number
    CGFloat magnitude = pow(10, floor(log10(fabs(niceMax))));
    return ceil(niceMax / magnitude) * magnitude;
}

+ (NSArray<NSNumber *> *)niceTickValuesForMin:(CGFloat)min max:(CGFloat)max count:(NSInteger)count {
    if (count <= 0) return @[];
    if (count == 1) return @[@((min + max) / 2)];
    
    NSMutableArray<NSNumber *> *ticks = [NSMutableArray array];
    CGFloat range = max - min;
    
    // Calculate nice step size
    CGFloat roughStep = range / (count - 1);
    CGFloat magnitude = pow(10, floor(log10(roughStep)));
    CGFloat normalizedStep = roughStep / magnitude;
    
    CGFloat niceStep;
    if (normalizedStep <= 1) {
        niceStep = 1 * magnitude;
    } else if (normalizedStep <= 2) {
        niceStep = 2 * magnitude;
    } else if (normalizedStep <= 5) {
        niceStep = 5 * magnitude;
    } else {
        niceStep = 10 * magnitude;
    }
    
    // Generate ticks
    CGFloat tickValue = floor(min / niceStep) * niceStep;
    while (tickValue <= max + niceStep * 0.5) {
        if (tickValue >= min - niceStep * 0.5) {
            [ticks addObject:@(tickValue)];
        }
        tickValue += niceStep;
    }
    
    return ticks;
}

#pragma mark - Date Formatting

+ (NSString *)formattedStringForDate:(NSDate *)date style:(NSDateFormatterStyle)style {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
    });
    
    formatter.dateStyle = style;
    formatter.timeStyle = NSDateFormatterNoStyle;
    
    return [formatter stringFromDate:date];
}

+ (NSString *)formattedStringForTimeInterval:(NSTimeInterval)interval {
    NSInteger hours = (NSInteger)(interval / 3600);
    NSInteger minutes = (NSInteger)((interval - hours * 3600) / 60);
    NSInteger seconds = (NSInteger)(interval - hours * 3600 - minutes * 60);
    
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
    } else if (minutes > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
    } else {
        return [NSString stringWithFormat:@"0:%02ld", (long)seconds];
    }
}

#pragma mark - Color Utilities

+ (NSArray<NSColor *> *)generateColorsForSeriesCount:(NSInteger)count {
    NSMutableArray<NSColor *> *colors = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CGFloat hue = (CGFloat)i / count;
        NSColor *color = [NSColor colorWithHue:hue
                                    saturation:0.7
                                    brightness:0.8
                                         alpha:1.0];
        [colors addObject:color];
    }
    
    return colors;
}

+ (NSColor *)colorByAdjustingBrightness:(NSColor *)color factor:(CGFloat)factor {
    CGFloat hue, saturation, brightness, alpha;
    [[color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    
    brightness = MAX(0.0, MIN(1.0, brightness * factor));
    
    return [NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

+ (NSColor *)contrastingColorForColor:(NSColor *)color {
    CGFloat red, green, blue, alpha;
    [[color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
        getRed:&red green:&green blue:&blue alpha:&alpha];
    
    // Calculate luminance
    CGFloat luminance = 0.299 * red + 0.587 * green + 0.114 * blue;
    
    // Return black or white based on luminance
    return luminance > 0.5 ? [NSColor blackColor] : [NSColor whiteColor];
}

#pragma mark - Geometry Utilities

+ (CGRect)rectByInsetting:(CGRect)rect edgeInsets:(NSEdgeInsets)insets {
    return CGRectMake(rect.origin.x + insets.left,
                      rect.origin.y + insets.top,
                      rect.size.width - insets.left - insets.right,
                      rect.size.height - insets.top - insets.bottom);
}

+ (CGPoint)centerOfRect:(CGRect)rect {
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

+ (CGFloat)distanceBetweenPoint:(CGPoint)p1 andPoint:(CGPoint)p2 {
    return hypot(p2.x - p1.x, p2.y - p1.y);
}

+ (CGPoint)pointOnCircleWithCenter:(CGPoint)center radius:(CGFloat)radius angle:(CGFloat)angle {
    return CGPointMake(center.x + radius * cos(angle),
                       center.y + radius * sin(angle));
}

#pragma mark - Animation Easing

+ (CGFloat)easeInQuad:(CGFloat)t {
    return t * t;
}

+ (CGFloat)easeOutQuad:(CGFloat)t {
    return t * (2 - t);
}

+ (CGFloat)easeInOutQuad:(CGFloat)t {
    if (t < 0.5) {
        return 2 * t * t;
    } else {
        return -1 + (4 - 2 * t) * t;
    }
}

+ (CGFloat)easeInCubic:(CGFloat)t {
    return t * t * t;
}

+ (CGFloat)easeOutCubic:(CGFloat)t {
    CGFloat t1 = t - 1;
    return t1 * t1 * t1 + 1;
}

+ (CGFloat)easeInOutCubic:(CGFloat)t {
    if (t < 0.5) {
        return 4 * t * t * t;
    } else {
        CGFloat t1 = 2 * t - 2;
        return 1 + t1 * t1 * t1 / 2;
    }
}

+ (CGFloat)easeInElastic:(CGFloat)t {
    if (t == 0) return 0;
    if (t == 1) return 1;
    
    CGFloat p = 0.3;
    CGFloat a = 1;
    CGFloat s = p / 4;
    CGFloat t1 = t - 1;
    
    return -(a * pow(2, 10 * t1) * sin((t1 - s) * (2 * M_PI) / p));
}

+ (CGFloat)easeOutElastic:(CGFloat)t {
    if (t == 0) return 0;
    if (t == 1) return 1;
    
    CGFloat p = 0.3;
    CGFloat a = 1;
    CGFloat s = p / 4;
    
    return a * pow(2, -10 * t) * sin((t - s) * (2 * M_PI) / p) + 1;
}

+ (CGFloat)easeOutBounce:(CGFloat)t {
    if (t < 1/2.75) {
        return 7.5625 * t * t;
    } else if (t < 2/2.75) {
        t -= 1.5/2.75;
        return 7.5625 * t * t + 0.75;
    } else if (t < 2.5/2.75) {
        t -= 2.25/2.75;
        return 7.5625 * t * t + 0.9375;
    } else {
        t -= 2.625/2.75;
        return 7.5625 * t * t + 0.984375;
    }
}

#pragma mark - Data Processing

+ (CGFloat)meanOfValues:(NSArray<NSNumber *> *)values {
    if (values.count == 0) return 0;
    
    CGFloat sum = 0;
    for (NSNumber *value in values) {
        sum += [value doubleValue];
    }
    
    return sum / values.count;
}

+ (CGFloat)medianOfValues:(NSArray<NSNumber *> *)values {
    if (values.count == 0) return 0;
    
    NSArray *sorted = [values sortedArrayUsingSelector:@selector(compare:)];
    NSInteger count = sorted.count;
    
    if (count % 2 == 0) {
        // Even count - average of two middle values
        CGFloat val1 = [sorted[count/2 - 1] doubleValue];
        CGFloat val2 = [sorted[count/2] doubleValue];
        return (val1 + val2) / 2;
    } else {
        // Odd count - middle value
        return [sorted[count/2] doubleValue];
    }
}

+ (CGFloat)standardDeviationOfValues:(NSArray<NSNumber *> *)values {
    if (values.count <= 1) return 0;
    
    CGFloat mean = [self meanOfValues:values];
    CGFloat sumSquaredDifferences = 0;
    
    for (NSNumber *value in values) {
        CGFloat difference = [value doubleValue] - mean;
        sumSquaredDifferences += difference * difference;
    }
    
    return sqrt(sumSquaredDifferences / (values.count - 1));
}

+ (CGFloat)sumOfValues:(NSArray<NSNumber *> *)values {
    CGFloat sum = 0;
    for (NSNumber *value in values) {
        sum += [value doubleValue];
    }
    return sum;
}

+ (NSArray<NSNumber *> *)movingAverageOfValues:(NSArray<NSNumber *> *)values window:(NSInteger)window {
    if (values.count == 0 || window <= 0) return @[];
    
    NSMutableArray<NSNumber *> *smoothed = [NSMutableArray array];
    
    for (NSInteger i = 0; i < values.count; i++) {
        NSInteger start = MAX(0, i - window + 1);
        NSInteger end = i + 1;
        
        CGFloat sum = 0;
        for (NSInteger j = start; j < end; j++) {
            sum += [values[j] doubleValue];
        }
        
        [smoothed addObject:@(sum / (end - start))];
    }
    
    return smoothed;
}

+ (NSArray<NSNumber *> *)exponentialSmoothingOfValues:(NSArray<NSNumber *> *)values alpha:(CGFloat)alpha {
    if (values.count == 0) return @[];
    
    NSMutableArray<NSNumber *> *smoothed = [NSMutableArray array];
    CGFloat previousSmoothed = [values[0] doubleValue];
    [smoothed addObject:@(previousSmoothed)];
    
    for (NSInteger i = 1; i < values.count; i++) {
        CGFloat currentValue = [values[i] doubleValue];
        CGFloat smoothedValue = alpha * currentValue + (1 - alpha) * previousSmoothed;
        [smoothed addObject:@(smoothedValue)];
        previousSmoothed = smoothedValue;
    }
    
    return smoothed;
}

@end
