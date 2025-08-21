// SharedXCoordinateContext.m
#import "SharedXCoordinateContext.h"
#import "RuntimeModels.h"
#import "ChartPanelView.h"
#import "ChartWidget.h"  // ✅ Import per accedere alle costanti

@implementation SharedXCoordinateContext

#pragma mark - X Coordinate Conversion Methods

- (CGFloat)screenXForBarCenter:(NSInteger)barIndex {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    CGFloat leftEdge = [self screenXForBarIndex:barIndex];
    CGFloat halfBarWidth = [self barWidth] / 2.0;
    return leftEdge + halfBarWidth;
}

- (CGFloat)screenXForBarIndex:(NSInteger)barIndex {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    if (visibleBars <= 0) return CHART_MARGIN_LEFT;
    
    CGFloat chartWidth = [self chartAreaWidth];  // ✅ USA IL METODO
    CGFloat totalBarWidth = chartWidth / visibleBars;
    NSInteger relativeIndex = barIndex - self.visibleStartIndex;
    
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
    
    NSInteger relativeIndex = (screenX - CHART_MARGIN_LEFT) / totalBarWidth;
    NSInteger absoluteIndex = self.visibleStartIndex + relativeIndex;
    
    return MAX(self.visibleStartIndex, MIN(absoluteIndex, self.visibleEndIndex - 1));
}

- (CGFloat)screenXForDate:(NSDate *)targetDate {
    if (!targetDate || !self.chartData || self.chartData.count == 0) {
        return -9999;
    }
    
    // Search for existing bar in data
    for (NSInteger i = 0; i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        if ([bar.date compare:targetDate] != NSOrderedAscending) {
            return [self screenXForBarIndex:i];
        }
    }
    
    // Extrapolation for dates before dataset
    NSDate *firstDate = self.chartData.firstObject.date;
    NSTimeInterval daysDiff = [firstDate timeIntervalSinceDate:targetDate] / 86400;
    
    NSInteger weeks = daysDiff / 7;
    daysDiff = daysDiff - (weeks * 2); // Remove weekends
    
    NSInteger barsPerDay = self.barsPerDay > 0 ? self.barsPerDay : 26;
    CGFloat totalBars = daysDiff * barsPerDay;
    
    CGFloat totalBarWidth = [self barWidth];
    CGFloat firstBarX = [self screenXForBarIndex:self.visibleStartIndex];
    
    return firstBarX - (totalBars * totalBarWidth);
}

- (CGFloat)chartAreaWidth {
    // ✅ Chart area excludes Y-axis on the right (using centralized constants)
    return self.containerWidth - CHART_Y_AXIS_WIDTH - CHART_MARGIN_LEFT - CHART_MARGIN_RIGHT;
}

- (CGFloat)barWidth {
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    if (visibleBars <= 0) return 0.0;
    
    return [self chartAreaWidth] / visibleBars;
}

- (CGFloat)barSpacing {
    CGFloat totalBarWidth = [self barWidth];
    return MAX(1.0, totalBarWidth * 0.1);
}

- (BOOL)isValidForConversion {
    return (self.containerWidth > (CHART_Y_AXIS_WIDTH + CHART_MARGIN_LEFT + CHART_MARGIN_RIGHT + 20) &&
            self.visibleEndIndex > self.visibleStartIndex &&
            self.chartData.count > 0);
}
@end
