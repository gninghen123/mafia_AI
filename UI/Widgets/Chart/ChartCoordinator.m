
//
//  ChartCoordinator.m
//  TradingApp
//

#import "ChartCoordinator.h"

@implementation ChartCoordinator

- (instancetype)init {
    self = [super init];
    if (self) {
        _zoomFactor = 1.0;
        _panOffset = 0.0;
        _crosshairVisible = NO;
        _visibleBarsRange = NSMakeRange(0, 0);
        _maxVisibleBars = 200;
        _crosshairPosition = NSZeroPoint;
    }
    return self;
}

#pragma mark - Coordinate Conversion

- (CGFloat)xPositionForBarIndex:(NSInteger)index inRect:(NSRect)rect {
    if (self.visibleBarsRange.length == 0) return 0;
    
    // Calculate bar width based on visible range
    CGFloat barWidth = rect.size.width / self.visibleBarsRange.length;
    NSInteger relativeIndex = index - self.visibleBarsRange.location;
    
    return relativeIndex * barWidth + barWidth / 2;
}

- (CGFloat)yPositionForValue:(double)value inRange:(NSRange)valueRange rect:(NSRect)rect {
    if (valueRange.length == 0) return rect.size.height / 2;
    
    double minValue = valueRange.location / 10000.0; // Convert back from scaled range
    double maxValue = (valueRange.location + valueRange.length) / 10000.0;
    
    if (maxValue <= minValue) return rect.size.height / 2;
    
    double normalizedValue = (value - minValue) / (maxValue - minValue);
    normalizedValue = MAX(0.0, MIN(1.0, normalizedValue)); // Clamp to 0-1
    
    return rect.size.height * (1.0 - normalizedValue); // Flip Y coordinate
}

- (NSInteger)barIndexForXPosition:(CGFloat)x inRect:(NSRect)rect {
    if (self.visibleBarsRange.length == 0) return 0;
    
    CGFloat barWidth = rect.size.width / self.visibleBarsRange.length;
    NSInteger relativeIndex = (NSInteger)(x / barWidth);
    
    return self.visibleBarsRange.location + relativeIndex;
}

- (double)valueForYPosition:(CGFloat)y inRange:(NSRange)valueRange rect:(NSRect)rect {
    if (valueRange.length == 0) return 0;
    
    double minValue = valueRange.location / 10000.0;
    double maxValue = (valueRange.location + valueRange.length) / 10000.0;
    
    double normalizedY = (rect.size.height - y) / rect.size.height; // Flip Y coordinate
    normalizedY = MAX(0.0, MIN(1.0, normalizedY));
    
    return minValue + normalizedY * (maxValue - minValue);
}

#pragma mark - Event Handling

- (void)handleMouseMove:(NSPoint)point inRect:(NSRect)rect {
    self.crosshairPosition = point;
    self.crosshairVisible = YES;
    

}

- (void)handleScroll:(CGFloat)deltaX deltaY:(CGFloat)deltaY inRect:(NSRect)rect {
    // Horizontal scroll = pan through time
    CGFloat panSensitivity = 0.1;
    NSInteger barsToMove = (NSInteger)(deltaX * panSensitivity);
    
    NSRange newRange = self.visibleBarsRange;
    newRange.location = MAX(0, newRange.location + barsToMove);
    
    // Ensure we don't go beyond available data
    if (self.historicalData && newRange.location + newRange.length > self.historicalData.count) {
        newRange.location = MAX(0, self.historicalData.count - newRange.length);
    }
    
    self.visibleBarsRange = newRange;
    self.panOffset += deltaX;
    
}

- (void)handleZoom:(CGFloat)factor atPoint:(NSPoint)point inRect:(NSRect)rect {
    CGFloat newZoomFactor = MAX(0.1, MIN(10.0, self.zoomFactor * factor));
    
    // Adjust visible bars based on zoom
    NSInteger newVisibleBars = (NSInteger)(self.maxVisibleBars / newZoomFactor);
    newVisibleBars = MAX(10, MIN(newVisibleBars, self.maxVisibleBars));
    
    // Try to keep the zoom point centered
    NSInteger centerBarIndex = [self barIndexForXPosition:point.x inRect:rect];
    NSInteger newStartIndex = centerBarIndex - newVisibleBars / 2;
    newStartIndex = MAX(0, newStartIndex);
    
    self.zoomFactor = newZoomFactor;
    self.visibleBarsRange = NSMakeRange(newStartIndex, newVisibleBars);
    
    NSLog(@"🔍 Zoom: factor=%.2f, new range: %@", newZoomFactor, NSStringFromRange(self.visibleBarsRange));
}

#pragma mark - Data Management

- (void)updateHistoricalData:(NSArray<HistoricalBarModel *> *)data {
    self.historicalData = data;
    [self autoFitToData];
}

- (void)resetZoomAndPan {
    self.zoomFactor = 1.0;
    self.panOffset = 0.0;
    [self autoFitToData];
}

- (void)autoFitToData {
    if (!self.historicalData || self.historicalData.count == 0) {
        self.visibleBarsRange = NSMakeRange(0, 0);
        return;
    }
    
    NSInteger visibleBars = MIN(self.maxVisibleBars, self.historicalData.count);
    NSInteger startIndex = MAX(0, self.historicalData.count - visibleBars);
    
    self.visibleBarsRange = NSMakeRange(startIndex, visibleBars);
    
    NSLog(@"📊 Auto-fit to %lu bars, visible range: %@",
          (unsigned long)self.historicalData.count, NSStringFromRange(self.visibleBarsRange));
}

#pragma mark - Value Range Calculation

- (NSRange)calculateValueRangeForData:(NSArray<HistoricalBarModel *> *)data
                                 type:(NSString *)indicatorType {
    if (!data || data.count == 0) {
        return NSMakeRange(0, 10000); // Default range
    }
    
    NSRange visibleRange = self.visibleBarsRange;
    if (visibleRange.location >= data.count) {
        return NSMakeRange(0, 10000);
    }
    
    NSInteger startIndex = visibleRange.location;
    NSInteger endIndex = MIN(startIndex + visibleRange.length, data.count);
    
    if ([indicatorType isEqualToString:@"Security"]) {
        // Price data - use high/low
        return [self calculatePriceRangeForData:data start:startIndex end:endIndex];
        
    } else if ([indicatorType isEqualToString:@"Volume"]) {
        // Volume data
        return [self calculateVolumeRangeForData:data start:startIndex end:endIndex];
        
    } else if ([indicatorType isEqualToString:@"RSI"]) {
        // RSI is always 0-100
        return NSMakeRange(0, 1000000); // 0-100 scaled by 10000
        
    } else {
        // Generic range calculation
        return [self calculateGenericRangeForData:data start:startIndex end:endIndex];
    }
}

- (NSRange)calculatePriceRangeForData:(NSArray<HistoricalBarModel *> *)data
                                start:(NSInteger)startIndex
                                  end:(NSInteger)endIndex {
    if (startIndex >= data.count) return NSMakeRange(0, 10000);
    
    HistoricalBarModel *firstBar = data[startIndex];
    double minPrice = firstBar.low;
    double maxPrice = firstBar.high;
    
    for (NSInteger i = startIndex; i < endIndex; i++) {
        HistoricalBarModel *bar = data[i];
        minPrice = MIN(minPrice, bar.low);
        maxPrice = MAX(maxPrice, bar.high);
    }
    
    // Add 5% padding
    double padding = (maxPrice - minPrice) * 0.05;
    if (padding == 0) padding = maxPrice * 0.01;
    
    minPrice -= padding;
    maxPrice += padding;
    
    if (maxPrice <= minPrice) maxPrice = minPrice + 1.0;
    
    // Scale by 10000 for precision
    NSUInteger minValue = (NSUInteger)(minPrice * 10000);
    NSUInteger rangeLength = (NSUInteger)((maxPrice - minPrice) * 10000);
    
    return NSMakeRange(minValue, rangeLength);
}

- (NSRange)calculateVolumeRangeForData:(NSArray<HistoricalBarModel *> *)data
                                 start:(NSInteger)startIndex
                                   end:(NSInteger)endIndex {
    if (startIndex >= data.count) return NSMakeRange(0, 1000000);
    
    NSInteger minVolume = data[startIndex].volume;
    NSInteger maxVolume = data[startIndex].volume;
    
    for (NSInteger i = startIndex; i < endIndex; i++) {
        HistoricalBarModel *bar = data[i];
        minVolume = MIN(minVolume, bar.volume);
        maxVolume = MAX(maxVolume, bar.volume);
    }
    
    // Add 10% padding
    NSInteger padding = (maxVolume - minVolume) * 0.1;
    minVolume = MAX(0, minVolume - padding);
    maxVolume += padding;
    
    if (maxVolume <= minVolume) maxVolume = minVolume + 1000;
    
    return NSMakeRange(minVolume, maxVolume - minVolume);
}

- (NSRange)calculateGenericRangeForData:(NSArray<HistoricalBarModel *> *)data
                                  start:(NSInteger)startIndex
                                    end:(NSInteger)endIndex {
    // For generic indicators, use close price as default
    if (startIndex >= data.count) return NSMakeRange(0, 10000);
    
    double minValue = data[startIndex].close;
    double maxValue = data[startIndex].close;
    
    for (NSInteger i = startIndex; i < endIndex; i++) {
        HistoricalBarModel *bar = data[i];
        minValue = MIN(minValue, bar.close);
        maxValue = MAX(maxValue, bar.close);
    }
    
    // Add 5% padding
    double padding = (maxValue - minValue) * 0.05;
    if (padding == 0) padding = maxValue * 0.01;
    
    minValue -= padding;
    maxValue += padding;
    
    if (maxValue <= minValue) maxValue = minValue + 1.0;
    
    // Scale by 10000 for precision
    NSUInteger minVal = (NSUInteger)(minValue * 10000);
    NSUInteger rangeLen = (NSUInteger)((maxValue - minValue) * 10000);
    
    return NSMakeRange(minVal, rangeLen);
}

@end
