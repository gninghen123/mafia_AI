
//
//  VolumeRenderer.m
//  TradingApp
//

#import "VolumeRenderer.h"
#import "ChartCoordinator.h"

@implementation VolumeRenderer

- (instancetype)init {
    self = [super init];
    if (self) {
        _settings = [IndicatorSettings defaultSettingsForIndicatorType:@"Volume"];
        [self applySettings:_settings];
        
        // Default settings
        _showMovingAverage = NO; // Start simple
        _movingAveragePeriod = 20;
    }
    return self;
}

#pragma mark - IndicatorRenderer Protocol

- (NSString *)indicatorType {
    return @"Volume";
}

- (NSString *)displayName {
    return self.settings.displayName;
}

- (IndicatorCategory)category {
    return IndicatorCategoryVolume;
}

- (BOOL)needsSeparatePanel {
    return YES; // Volume needs its own panel
}

- (void)drawInRect:(NSRect)rect
          withData:(NSArray<HistoricalBarModel *> *)data
        coordinator:(ChartCoordinator *)coordinator {
    
    if (!data || data.count == 0) return;
    
    NSRange visibleRange = coordinator.visibleBarsRange;
    if (visibleRange.location >= data.count) return;
    
    NSInteger startIndex = visibleRange.location;
    NSInteger endIndex = MIN(startIndex + visibleRange.length, data.count);
    NSInteger visibleBars = endIndex - startIndex;
    
    if (visibleBars <= 0) return;
    
    // Calculate volume range for Y-axis
    NSRange volumeRange = [coordinator calculateValueRangeForData:data type:@"Volume"];
    
    // Calculate bar dimensions
    CGFloat barWidth = rect.size.width / visibleBars;
    CGFloat volumeBarWidth = MAX(1.0, barWidth * 0.9);
    CGFloat barSpacing = MAX(0.5, (barWidth - volumeBarWidth) / 2);
    
    // Draw volume bars
    for (NSInteger i = 0; i < visibleBars; i++) {
        NSInteger dataIndex = startIndex + i;
        if (dataIndex >= data.count) break;
        
        HistoricalBarModel *bar = data[dataIndex];
        [self drawVolumeBarForBar:bar
                          atIndex:i
                         barWidth:volumeBarWidth
                       barSpacing:barSpacing
                           inRect:rect
                      volumeRange:volumeRange
                      coordinator:coordinator];
    }
    
    // Draw moving average if enabled
    if (self.showMovingAverage && data.count >= self.movingAveragePeriod) {
        [self drawMovingAverageInRect:rect
                             withData:data
                          coordinator:coordinator
                          volumeRange:volumeRange
                          visibleBars:visibleBars
                           startIndex:startIndex];
    }
}

- (void)drawVolumeBarForBar:(HistoricalBarModel *)bar
                    atIndex:(NSInteger)index
                   barWidth:(CGFloat)barWidth
                 barSpacing:(CGFloat)barSpacing
                     inRect:(NSRect)rect
                volumeRange:(NSRange)volumeRange
                coordinator:(ChartCoordinator *)coordinator {
    
    CGFloat x = index * (barWidth + barSpacing * 2) + barSpacing;
    
    // Calculate volume bar height (from bottom up)
    NSInteger minVolume = volumeRange.location;
    NSInteger maxVolume = volumeRange.location + volumeRange.length;
    
    double normalizedVolume = 0.0;
    if (maxVolume > minVolume) {
        normalizedVolume = (double)(bar.volume - minVolume) / (double)(maxVolume - minVolume);
    }
    
    CGFloat barHeight = rect.size.height * normalizedVolume * 0.95; // Use 95% of available height
    CGFloat barY = rect.size.height - barHeight; // Start from bottom
    
    // Color based on price movement
    BOOL isUp = bar.close >= bar.open;
    NSColor *barColor = isUp ? self.upVolumeColor : self.downVolumeColor;
    
    // Draw volume bar
    NSRect volumeRect = NSMakeRect(x, barY, barWidth, barHeight);
    [barColor setFill];
    NSRectFill(volumeRect);
    
    // Draw subtle border
    [[NSColor labelColor] colorWithAlphaComponent:0.3].setStroke;
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:volumeRect];
    border.lineWidth = 0.5;
    [border stroke];
}

- (void)drawMovingAverageInRect:(NSRect)rect
                       withData:(NSArray<HistoricalBarModel *> *)data
                    coordinator:(ChartCoordinator *)coordinator
                    volumeRange:(NSRange)volumeRange
                    visibleBars:(NSInteger)visibleBars
                     startIndex:(NSInteger)startIndex {
    
    NSMutableArray *movingAverages = [NSMutableArray array];
    
    // Calculate moving averages for visible range
    for (NSInteger i = startIndex; i < startIndex + visibleBars; i++) {
        if (i < self.movingAveragePeriod - 1) {
            [movingAverages addObject:[NSNull null]];
            continue;
        }
        
        NSInteger sum = 0;
        for (NSInteger j = i - self.movingAveragePeriod + 1; j <= i && j < data.count; j++) {
            sum += data[j].volume;
        }
        
        double average = (double)sum / self.movingAveragePeriod;
        [movingAverages addObject:@(average)];
    }
    
    // Draw moving average line
    NSBezierPath *maPath = [NSBezierPath bezierPath];
    maPath.lineWidth = self.settings.lineWidth;
    [self.settings.secondaryColor setStroke];
    
    BOOL firstPoint = YES;
    CGFloat barWidth = rect.size.width / visibleBars;
    
    for (NSInteger i = 0; i < movingAverages.count; i++) {
        id maValue = movingAverages[i];
        if ([maValue isKindOfClass:[NSNull class]]) continue;
        
        double average = [maValue doubleValue];
        CGFloat x = i * barWidth + barWidth / 2;
        
        // Convert volume to Y position
        NSInteger minVolume = volumeRange.location;
        NSInteger maxVolume = volumeRange.location + volumeRange.length;
        double normalizedVolume = (average - minVolume) / (double)(maxVolume - minVolume);
        CGFloat y = rect.size.height * (1.0 - normalizedVolume);
        
        if (firstPoint) {
            [maPath moveToPoint:NSMakePoint(x, y)];
            firstPoint = NO;
        } else {
            [maPath lineToPoint:NSMakePoint(x, y)];
        }
    }
    
    [maPath stroke];
}

#pragma mark - Optional Protocol Methods

- (NSColor *)primaryColor {
    return self.upVolumeColor;
}

- (IndicatorSettings *)settings {
    return _settings;
}

- (void)applySettings:(IndicatorSettings *)settings {
    _settings = [settings copy];
    
    // Update visual properties from settings
    _upVolumeColor = settings.primaryColor;
    _downVolumeColor = settings.secondaryColor;
}

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    state[@"settings"] = [self.settings toDictionary];
    state[@"showMovingAverage"] = @(self.showMovingAverage);
    state[@"movingAveragePeriod"] = @(self.movingAveragePeriod);
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    if (state[@"settings"]) {
        IndicatorSettings *newSettings = [IndicatorSettings settingsFromDictionary:state[@"settings"]];
        [self applySettings:newSettings];
    }
    
    if (state[@"showMovingAverage"]) {
        self.showMovingAverage = [state[@"showMovingAverage"] boolValue];
    }
    
    if (state[@"movingAveragePeriod"]) {
        self.movingAveragePeriod = [state[@"movingAveragePeriod"] integerValue];
    }
}

@end
