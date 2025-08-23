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
    
    
    if (self.visibleBars <= 0) return CHART_MARGIN_LEFT;
    
    CGFloat chartWidth = [self chartAreaWidth];  // ✅ USA IL METODO
    CGFloat totalBarWidth = chartWidth / self.visibleBars;
    NSInteger relativeIndex = barIndex - self.visibleStartIndex;
    
    return CHART_MARGIN_LEFT + (relativeIndex * totalBarWidth);
}

- (NSInteger)barIndexForScreenX:(CGFloat)screenX {
    if (![self isValidForConversion]) {
        return 0;
    }
    
    
    if (self.visibleBars <= 0) return self.visibleStartIndex;
    
    CGFloat chartWidth = [self chartAreaWidth];
    CGFloat totalBarWidth = chartWidth / self.visibleBars;
    
    NSInteger relativeIndex = (screenX - CHART_MARGIN_LEFT) / totalBarWidth;
    NSInteger absoluteIndex = self.visibleStartIndex + relativeIndex;
    
    return MAX(self.visibleStartIndex, MIN(absoluteIndex, self.visibleEndIndex - 1));
}

- (CGFloat)screenXForDate:(NSDate *)targetDate {
    if (!targetDate || !self.chartData || self.chartData.count == 0) {
        return -9999;
    }

    // --- 1) Ricerca veloce nel range visibile ---
    for (NSInteger i = self.visibleStartIndex; i <= self.visibleEndIndex && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        if ([bar.date compare:targetDate] != NSOrderedAscending) {
            return [self screenXForBarIndex:i];
        }
    }

    // --- 2) Ricerca completa nel dataset ---
    for (NSInteger i = 0; i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        if ([bar.date compare:targetDate] != NSOrderedAscending) {
            return [self screenXForBarIndex:i];
        }
    }

    // --- 3) Inferenza fuori dal dataset ---
    NSDate *firstDate = self.chartData.firstObject.date;
    NSDate *lastDate  = self.chartData.lastObject.date;
    CGFloat barWidth  = [self barWidth];

    NSInteger barSizeSeconds = self.currentTimeframeMinutes * 60;
    NSInteger barsPerDay     = self.barsPerDay;

    if ([targetDate compare:firstDate] == NSOrderedAscending) {
        double barsDiff = [self tradableBarsBetweenDate:targetDate andDate:firstDate
                                             barSize:barSizeSeconds
                                          barsPerDay:barsPerDay];
        CGFloat firstBarX = [self screenXForBarIndex:0];
        return firstBarX - (barsDiff * barWidth);
    }

    if ([targetDate compare:lastDate] == NSOrderedDescending) {
        double barsDiff = [self tradableBarsBetweenDate:lastDate andDate:targetDate
                                             barSize:barSizeSeconds
                                          barsPerDay:barsPerDay];
        CGFloat lastBarX = [self screenXForBarIndex:self.chartData.count - 1];
        return lastBarX + (barsDiff * barWidth);
    }

    return -9999;
}


- (double)tradableBarsBetweenDate:(NSDate *)start
                          andDate:(NSDate *)end
                           barSize:(NSInteger)barSizeSeconds
                        barsPerDay:(NSInteger)barsPerDay {

    if ([end compare:start] != NSOrderedDescending) return 0;

    double totalBars = 0;
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    [cal setTimeZone:[NSTimeZone timeZoneWithName:@"America/New_York"]];

    NSDate *current = start;
    while ([current compare:end] == NSOrderedAscending) {
        // giorno corrente
        NSDateComponents *comp = [cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:current];

        NSDate *dayStart, *dayEnd;
        if (self.includesExtendedHours) {
            comp.hour = 4; comp.minute = 0; comp.second = 0;
            dayStart = [cal dateFromComponents:comp];
            comp.hour = 20; comp.minute = 0; comp.second = 0;
            dayEnd   = [cal dateFromComponents:comp];
        } else {
            comp.hour = 9; comp.minute = 30; comp.second = 0;
            dayStart = [cal dateFromComponents:comp];
            comp.hour = 16; comp.minute = 0; comp.second = 0;
            dayEnd   = [cal dateFromComponents:comp];
        }

        // skip weekend
        NSInteger weekday = [cal component:NSCalendarUnitWeekday fromDate:dayStart]; // 1 = domenica
        if (weekday == 1 || weekday == 7) {
            current = [cal dateByAddingUnit:NSCalendarUnitDay value:1 toDate:current options:0];
            continue;
        }

        NSDate *intervalStart = MAX(current, dayStart);
        NSDate *intervalEnd   = MIN(end, dayEnd);

        if ([intervalEnd compare:intervalStart] == NSOrderedDescending) {
            NSTimeInterval tradableSeconds = [intervalEnd timeIntervalSinceDate:intervalStart];
            totalBars += tradableSeconds / barSizeSeconds;
        }

        current = [cal dateByAddingUnit:NSCalendarUnitDay value:1 toDate:dayStart options:0];
    }

    return totalBars;
}


- (CGFloat)chartAreaWidth {
    // ✅ Chart area excludes Y-axis on the right (using centralized constants)
    return self.containerWidth - CHART_Y_AXIS_WIDTH - CHART_MARGIN_LEFT - CHART_MARGIN_RIGHT;
}

- (CGFloat)barWidth {
    
    if (self.visibleBars <= 0) return 0.0;
    
    return [self chartAreaWidth] / self.visibleBars;
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

- (NSInteger)visibleBars{
    return self.visibleEndIndex - self.visibleStartIndex + 1;
}


@end
