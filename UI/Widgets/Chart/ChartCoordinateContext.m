//
//  ChartCoordinateContext.m
//  TradingApp
//
//  Unified coordinate conversion context implementation
//

#import "ChartCoordinateContext.h"
#import "RuntimeModels.h"

@implementation ChartCoordinateContext

#pragma mark - Primary Y ↔ Value Conversion Methods

- (CGFloat)screenYForValue:(double)value {
    // ✅ FAST VALIDATION
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    // ✅ PERFORMANCE: Pre-calculate reused values
    double range = self.yRangeMax - self.yRangeMin;
    if (range <= 0.0) {
        return 0.0;
    }
    
    CGFloat panelHeight = self.panelBounds.size.height;
    CGFloat usableHeight = panelHeight - 20.0; // 10px margin top/bottom
    
    // ✅ CONVERSION: value → normalizedY → screenY
    double normalizedValue = (value - self.yRangeMin) / range;
    
    // ✅ CORRETTO: top = high value, bottom = low value (financial chart standard)
    // normalizedValue 0.0 = yRangeMin = bottom of chart = panelHeight - 10
    // normalizedValue 1.0 = yRangeMax = top of chart = 10
    CGFloat screenY = 10.0 + (normalizedValue * usableHeight);
    
    return screenY;
}

- (double)valueForScreenY:(CGFloat)screenY {
    // ✅ FAST VALIDATION
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    CGFloat panelHeight = self.panelBounds.size.height;
    CGFloat usableHeight = panelHeight - 20.0;
    
    // ✅ CONVERSION: screenY → normalizedY → value
    // screenY 10 = top = yRangeMax = normalizedY 1.0
    // screenY (panelHeight-10) = bottom = yRangeMin = normalizedY 0.0
    CGFloat normalizedY = (screenY - 10.0) / usableHeight;
    
    // ✅ CLAMP: Keep within valid bounds
    normalizedY = MAX(0.0, MIN(1.0, normalizedY));
    
    double range = self.yRangeMax - self.yRangeMin;
    return self.yRangeMin + (normalizedY * range);
}

- (BOOL)isValidForConversion {
    return (self.yRangeMax > self.yRangeMin &&
            self.panelBounds.size.height > 20.0 &&
            self.panelBounds.size.width > 0.0);
}

#pragma mark - Normalized Conversion Utilities

- (double)valueForNormalizedY:(double)normalizedY {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    normalizedY = MAX(0.0, MIN(1.0, normalizedY));
    double range = self.yRangeMax - self.yRangeMin;
    return self.yRangeMin + (normalizedY * range);
}

- (double)normalizedYForValue:(double)value {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    double range = self.yRangeMax - self.yRangeMin;
    if (range <= 0.0) return 0.0;
    
    double normalized = (value - self.yRangeMin) / range;
    return MAX(0.0, MIN(1.0, normalized));
}

#pragma mark - Legacy Compatibility Methods

- (CGFloat)screenYForTriggerValue:(double)triggerValue {
    return [self screenYForValue:triggerValue];
}

- (double)triggerValueForScreenY:(CGFloat)screenY {
    return [self valueForScreenY:screenY];
}

- (CGFloat)priceFromScreenY:(CGFloat)screenY {
    return [self valueForScreenY:screenY];
}

- (CGFloat)yCoordinateForPrice:(double)price {
    return [self screenYForValue:price];
}

#pragma mark - Debugging Support

- (NSString *)description {
    return [NSString stringWithFormat:@"<ChartCoordinateContext: yRange=%.2f-%.2f, bounds=%@, symbol=%@, valid=%@>",
            self.yRangeMin, self.yRangeMax, NSStringFromRect(self.panelBounds),
            self.currentSymbol ?: @"nil", self.isValidForConversion ? @"YES" : @"NO"];
}

@end
