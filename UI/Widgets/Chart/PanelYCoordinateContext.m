// PanelYCoordinateContext.m
#import "PanelYCoordinateContext.h"
#import "ChartPanelView.h"

@implementation PanelYCoordinateContext

#pragma mark - Primary Y ↔ Value Conversion Methods
// Sostituire completamente il metodo screenYForValue: in PanelYCoordinateContext.m
// Corrected code for macOS's Y-axis
- (CGFloat)screenYForValue:(double)value {
    if (![self isValidForConversion]) {
        return 0.0;
    }

    double range = self.yRangeMax - self.yRangeMin;
    if (range <= 0.0) {
        return 0.0;
    }

    CGFloat usableHeight = self.panelHeight - 20.0; // top/bottom margins
    double normalizedValue;

    if (self.useLogScale && value > 0 && self.yRangeMin > 0 && self.yRangeMax > 0) {
        double logMin = log(self.yRangeMin);
        double logMax = log(self.yRangeMax);
        double logValue = log(value);
        normalizedValue = (logValue - logMin) / (logMax - logMin);
    } else {
        normalizedValue = (value - self.yRangeMin) / range;
    }

    normalizedValue = fmax(0.0, fmin(1.0, normalizedValue));
    
    // Y-axis increases upwards.
    // The lowest value should be at the bottom (y=10.0), and the highest at the top (y=panelHeight-10.0).
    return 10.0 + (normalizedValue * usableHeight);
}

// Corrected code for macOS's Y-axis
- (double)valueForScreenY:(CGFloat)screenY {
    if (![self isValidForConversion]) {
        return 0.0;
    }

    CGFloat usableHeight = self.panelHeight - 20.0;
    
    // Normalize the screen Y position. The lowest point (y=10.0) is 0.0, the highest point is 1.0.
    double normalizedY = (screenY - 10.0) / usableHeight;
    normalizedY = fmax(0.0, fmin(1.0, normalizedY));

    if (self.useLogScale && self.yRangeMin > 0 && self.yRangeMax > 0) {
        double logMin = log(self.yRangeMin);
        double logMax = log(self.yRangeMax);
        double logValue = logMin + (normalizedY * (logMax - logMin));
        return exp(logValue);
    } else {
        double range = self.yRangeMax - self.yRangeMin;
        return self.yRangeMin + (normalizedY * range);
    }
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
