//
//  ChartCoordinateContext.m
//  TradingApp
//
//  Unified coordinate conversion context implementation
//

#import "ChartCoordinateContext.h"
#import "RuntimeModels.h"
#import "ChartPanelView.h"  

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
            self.panelBounds.size.width > (Y_AXIS_WIDTH + CHART_MARGIN_LEFT + CHART_MARGIN_RIGHT) &&
            self.visibleEndIndex > self.visibleStartIndex &&
            self.chartData.count > 0);
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


#pragma mark - X Coordinate Conversion Methods

- (CGFloat)screenXForBarCenter:(NSInteger)barIndex {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    // Ottieni posizione bordo sinistro
    CGFloat leftEdge = [self screenXForBarIndex:barIndex];
    
    // Aggiungi metà della larghezza totale barra per arrivare al centro
    CGFloat halfBarWidth = [self barWidth] / 2.0;
    
    return leftEdge + halfBarWidth;
}


- (CGFloat)screenXForBarIndex:(NSInteger)barIndex {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    if (visibleBars <= 0) return CHART_MARGIN_LEFT;
    
    // Calculate bar dimensions
    CGFloat chartWidth = [self chartAreaWidth];
    CGFloat totalBarWidth = chartWidth / visibleBars;
    CGFloat spacing = [self barSpacing];
    CGFloat actualBarWidth = totalBarWidth - spacing;
    
    // Control point can be outside viewport - calculate anyway
    NSInteger relativeIndex = barIndex - self.visibleStartIndex;
    
    // ✅ COORDINATE UNIFICATE: stesso calcolo di drawCandlesticks
    return CHART_MARGIN_LEFT + (relativeIndex * totalBarWidth);
}

- (NSInteger)barIndexForScreenX:(CGFloat)screenX {
    if (![self isValidForConversion]) {
        return 0;
    }
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    if (visibleBars <= 0) return self.visibleStartIndex;
    
    CGFloat chartWidth = [self chartAreaWidth];
    CGFloat totalBarWidth = chartWidth / visibleBars;
    
    // Convert screen X to relative index
    NSInteger relativeIndex = (screenX - CHART_MARGIN_LEFT) / totalBarWidth;
    NSInteger absoluteIndex = self.visibleStartIndex + relativeIndex;
    
    // Clamp to visible range
    return MAX(self.visibleStartIndex,
              MIN(absoluteIndex, self.visibleEndIndex - 1));
}

- (CGFloat)screenXForDate:(NSDate *)targetDate {
    if (!targetDate || !self.chartData || self.chartData.count == 0) {
        return -9999; // Invalid coordinates
    }
    
    // 1. Search for existing bar in data
    for (NSInteger i = 0; i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        if ([bar.date compare:targetDate] != NSOrderedAscending) {
            // Found bar >= target date
            return [self screenXForBarIndex:i];
        }
    }
    
    // 2. Date is before dataset - intelligent extrapolation
    NSDate *firstDate = self.chartData.firstObject.date;
    NSTimeInterval daysDiff = [firstDate timeIntervalSinceDate:targetDate] / 86400;
    
    // 3. Remove weekends (trading days only)
    NSInteger weeks = daysDiff / 7;
    daysDiff = daysDiff - (weeks * 2);
    
    // 4. Use trading context values
    NSInteger barsPerDay = self.barsPerDay > 0 ? self.barsPerDay : 26; // Default 15m regular hours
    CGFloat totalBars = daysDiff * barsPerDay;
    
    // 5. Calculate position (negative = left of viewport)
    CGFloat totalBarWidth = [self barWidth];
    CGFloat firstBarX = [self screenXForBarIndex:self.visibleStartIndex];
    
    return firstBarX - (totalBars * totalBarWidth);
}

- (CGFloat)chartAreaWidth {
    // Chart area excludes Y-axis on the right
    return self.panelBounds.size.width - Y_AXIS_WIDTH - CHART_MARGIN_LEFT - CHART_MARGIN_RIGHT;
}

- (CGFloat)barWidth {
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    if (visibleBars <= 0) return 0.0;
    
    CGFloat chartWidth = [self chartAreaWidth];
    return chartWidth / visibleBars;
}

- (CGFloat)barSpacing {
    CGFloat totalBarWidth = [self barWidth];
    return MAX(1.0, totalBarWidth * 0.1); // 10% spacing, minimum 1px
}
@end
