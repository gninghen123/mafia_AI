// PanelYCoordinateContext.m
#import "PanelYCoordinateContext.h"
#import "ChartPanelView.h"

@implementation PanelYCoordinateContext

#pragma mark - Primary Y ↔ Value Conversion Methods

- (CGFloat)screenYForValue:(double)value {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    double range = self.yRangeMax - self.yRangeMin;
    if (range <= 0.0) {
        return 0.0;
    }
    
    CGFloat usableHeight = self.panelHeight - 20.0; // 10px margin top/bottom
    double normalizedValue = (value - self.yRangeMin) / range;
    
    // Financial chart standard: top = high value, bottom = low value
    CGFloat screenY = 10.0 + (normalizedValue * usableHeight);
    return screenY;
}

- (double)valueForScreenY:(CGFloat)screenY {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    CGFloat usableHeight = self.panelHeight - 20.0;
    CGFloat normalizedY = (screenY - 10.0) / usableHeight;
    normalizedY = MAX(0.0, MIN(1.0, normalizedY));
    
    double range = self.yRangeMax - self.yRangeMin;
    return self.yRangeMin + (normalizedY * range);
}

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

- (BOOL)isValidForConversion {
    return (self.yRangeMax > self.yRangeMin &&
            self.panelHeight > 20.0);
}

@end
