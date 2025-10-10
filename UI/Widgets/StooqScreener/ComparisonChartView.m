//
//  ComparisonChartView.m
//  TradingApp
//

#import "ComparisonChartView.h"

@interface ComparisonChartView ()

// Organized data for drawing
@property (nonatomic, strong) NSArray<NSDate *> *dates;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSNumber *> *> *modelData; // modelID → values array

// Drawing state
@property (nonatomic, assign) CGFloat minValue;
@property (nonatomic, assign) CGFloat maxValue;
@property (nonatomic, assign) CGFloat valueRange;

// Tracking area for mouse events
@property (nonatomic, strong) NSTrackingArea *trackingArea;

@end

@implementation ComparisonChartView

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.wantsLayer = YES;
    self.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
    
    _showCrosshair = NO;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
    
    NSTrackingAreaOptions options = NSTrackingActiveInKeyWindow |
                                    NSTrackingMouseMoved |
                                    NSTrackingMouseEnteredAndExited;
    
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                     options:options
                                                       owner:self
                                                    userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

#pragma mark - Data Management

- (void)setSession:(BacktestSession *)session
        metricKey:(NSString *)metricKey
      modelColors:(NSDictionary<NSString *, NSColor *> *)colors {
    
    self.session = session;
    self.metricKey = metricKey;
    self.modelColors = colors;
    
    [self prepareDataForDisplay];
    [self setNeedsDisplay:YES];
}

- (void)setMetricKey:(NSString *)metricKey {
    _metricKey = metricKey;
    
    [self prepareDataForDisplay];
    [self setNeedsDisplay:YES];
}

- (void)prepareDataForDisplay {
    if (!self.session || !self.metricKey) {
        self.dates = nil;
        self.modelData = nil;
        return;
    }
    
    // Get all unique dates
    self.dates = [self.session allDates];
    
    if (self.dates.count == 0) {
        return;
    }
    
    // Organize data by model
    NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *dataByModel = [NSMutableDictionary dictionary];
    
    for (ScreenerModel *model in self.session.models) {
        dataByModel[model.modelID] = [NSMutableArray array];
    }
    
    // Extract metric values for each date
    for (NSDate *date in self.dates) {
        NSArray<DailyBacktestResult *> *resultsForDate = [self.session resultsForDate:date];
        
        for (DailyBacktestResult *result in resultsForDate) {
            CGFloat value = [self extractMetricValue:result forKey:self.metricKey];
            [dataByModel[result.modelID] addObject:@(value)];
        }
    }
    
    // Convert to immutable
    NSMutableDictionary *finalData = [NSMutableDictionary dictionary];
    for (NSString *modelID in dataByModel) {
        finalData[modelID] = [dataByModel[modelID] copy];
    }
    self.modelData = [finalData copy];
    
    // Calculate value range
    [self calculateValueRange];
}

- (CGFloat)extractMetricValue:(DailyBacktestResult *)result forKey:(NSString *)key {
    
    if ([key isEqualToString:@"symbolCount"]) {
        return (CGFloat)result.symbolCount;
    }
    else if ([key isEqualToString:@"winRate"]) {
        return result.winRate;
    }
    else if ([key isEqualToString:@"avgGain"]) {
        return result.avgGain;
    }
    else if ([key isEqualToString:@"avgLoss"]) {
        return result.avgLoss;
    }
    else if ([key isEqualToString:@"tradeCount"]) {
        return (CGFloat)result.tradeCount;
    }
    else if ([key isEqualToString:@"winLossRatio"]) {
        return result.winLossRatio;
    }
    
    return 0.0;
}

- (void)calculateValueRange {
    if (!self.modelData || self.modelData.count == 0) {
        return;
    }
    
    self.minValue = CGFLOAT_MAX;
    self.maxValue = -CGFLOAT_MAX;
    
    for (NSArray<NSNumber *> *values in self.modelData.allValues) {
        for (NSNumber *num in values) {
            CGFloat value = num.doubleValue;
            if (value < self.minValue) self.minValue = value;
            if (value > self.maxValue) self.maxValue = value;
        }
    }
    
    self.valueRange = self.maxValue - self.minValue;
    
    // Add 10% padding
    CGFloat padding = self.valueRange * 0.1;
    self.minValue -= padding;
    self.maxValue += padding;
    self.valueRange = self.maxValue - self.minValue;
    
    // Ensure non-zero range
    if (self.valueRange < 0.01) {
        self.valueRange = 1.0;
        self.minValue = self.minValue - 0.5;
        self.maxValue = self.maxValue + 0.5;
    }
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (!self.session || !self.dates || self.dates.count == 0) {
        [self drawEmptyState];
        return;
    }
    
    // Draw background
    [[NSColor windowBackgroundColor] setFill];
    NSRectFill(dirtyRect);
    
    // Calculate chart area (leave margins)
    CGFloat leftMargin = 60;
    CGFloat rightMargin = 100; // More space for legend
    CGFloat topMargin = 30;
    CGFloat bottomMargin = 30;
    
    NSRect chartRect = NSMakeRect(leftMargin,
                                  bottomMargin,
                                  self.bounds.size.width - leftMargin - rightMargin,
                                  self.bounds.size.height - topMargin - bottomMargin);
    
    // Draw axes and grid
    [self drawAxesInRect:chartRect];
    
    // Draw lines for each model
    [self drawLinesInRect:chartRect];
    
    // Draw legend
    [self drawLegendInRect:NSMakeRect(NSMaxX(chartRect) + 10, chartRect.origin.y,
                                      rightMargin - 20, chartRect.size.height)];
    
    // Draw crosshair if enabled
    if (self.showCrosshair) {
        [self drawCrosshairAtX:self.crosshairX inRect:chartRect];
    }
    
    // Draw title
    [self drawTitle];
}

- (void)drawEmptyState {
    NSString *message = @"Run backtest to see comparison";
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:16],
        NSForegroundColorAttributeName: [NSColor tertiaryLabelColor]
    };
    
    NSSize textSize = [message sizeWithAttributes:attrs];
    NSPoint textPoint = NSMakePoint((self.bounds.size.width - textSize.width) / 2,
                                   (self.bounds.size.height - textSize.height) / 2);
    
    [message drawAtPoint:textPoint withAttributes:attrs];
}

- (void)drawAxesInRect:(NSRect)rect {
    
    // Draw value axis (left)
    NSBezierPath *valueAxis = [NSBezierPath bezierPath];
    [valueAxis moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y)];
    [valueAxis lineToPoint:NSMakePoint(rect.origin.x, NSMaxY(rect))];
    [[NSColor separatorColor] setStroke];
    valueAxis.lineWidth = 1.0;
    [valueAxis stroke];
    
    // Draw time axis (bottom)
    NSBezierPath *timeAxis = [NSBezierPath bezierPath];
    [timeAxis moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y)];
    [timeAxis lineToPoint:NSMakePoint(NSMaxX(rect), rect.origin.y)];
    [timeAxis stroke];
    
    // Draw value labels
    NSInteger valueSteps = 5;
    for (NSInteger i = 0; i <= valueSteps; i++) {
        CGFloat ratio = (CGFloat)i / (CGFloat)valueSteps;
        CGFloat value = self.minValue + (self.valueRange * ratio);
        CGFloat y = rect.origin.y + (rect.size.height * ratio);
        
        // Grid line
        NSBezierPath *gridLine = [NSBezierPath bezierPath];
        [gridLine moveToPoint:NSMakePoint(rect.origin.x, y)];
        [gridLine lineToPoint:NSMakePoint(NSMaxX(rect), y)];
        [[NSColor separatorColor] setStroke];
        gridLine.lineWidth = 0.5;
        [gridLine stroke];
        
        // Value label
        NSString *valueLabel = [self formatValue:value];
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:10],
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
        };
        
        NSSize labelSize = [valueLabel sizeWithAttributes:attrs];
        [valueLabel drawAtPoint:NSMakePoint(rect.origin.x - labelSize.width - 5, y - labelSize.height / 2)
                 withAttributes:attrs];
    }
    
    // Draw date labels (every N dates to avoid crowding)
    NSInteger dateStep = MAX(1, self.dates.count / 5);
    for (NSInteger i = 0; i < self.dates.count; i += dateStep) {
        NSDate *date = self.dates[i];
        CGFloat x = [self xPositionForDateIndex:i inRect:rect];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MM/dd";
        NSString *dateLabel = [formatter stringFromDate:date];
        
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:9],
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
        };
        
        NSSize labelSize = [dateLabel sizeWithAttributes:attrs];
        [dateLabel drawAtPoint:NSMakePoint(x - labelSize.width / 2, rect.origin.y - labelSize.height - 5)
                withAttributes:attrs];
    }
}

- (void)drawLinesInRect:(NSRect)rect {
    
    if (!self.session || !self.modelData) return;
    
    for (ScreenerModel *model in self.session.models) {
        NSArray<NSNumber *> *values = self.modelData[model.modelID];
        
        if (!values || values.count == 0) continue;
        
        NSColor *color = self.modelColors[model.modelID] ?: [NSColor systemBlueColor];
        
        NSBezierPath *linePath = [NSBezierPath bezierPath];
        linePath.lineWidth = 2.0;
        
        BOOL firstPoint = YES;
        
        for (NSInteger i = 0; i < values.count; i++) {
            CGFloat value = [values[i] doubleValue];
            
            CGFloat x = [self xPositionForDateIndex:i inRect:rect];
            CGFloat y = [self yPositionForValue:value inRect:rect];
            
            if (firstPoint) {
                [linePath moveToPoint:NSMakePoint(x, y)];
                firstPoint = NO;
            } else {
                [linePath lineToPoint:NSMakePoint(x, y)];
            }
        }
        
        [color setStroke];
        [linePath stroke];
    }
}

- (void)drawLegendInRect:(NSRect)rect {
    
    if (!self.session || !self.session.models) return;
    
    CGFloat y = NSMaxY(rect) - 10;
    CGFloat lineHeight = 20;
    
    for (ScreenerModel *model in self.session.models) {
        NSColor *color = self.modelColors[model.modelID] ?: [NSColor systemBlueColor];
        
        // Color box
        NSRect colorBox = NSMakeRect(rect.origin.x, y - lineHeight + 5, 15, 10);
        [color setFill];
        NSRectFill(colorBox);
        
        // Model name
        NSString *name = model.displayName ?: @"Unknown";
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:11],
            NSForegroundColorAttributeName: [NSColor labelColor]
        };
        
        [name drawAtPoint:NSMakePoint(NSMaxX(colorBox) + 5, y - lineHeight) withAttributes:attrs];
        
        y -= lineHeight;
    }
}

- (void)drawCrosshairAtX:(CGFloat)x inRect:(NSRect)rect {
    
    if (x < rect.origin.x || x > NSMaxX(rect)) return;
    
    // Draw vertical line
    NSBezierPath *line = [NSBezierPath bezierPath];
    [line moveToPoint:NSMakePoint(x, rect.origin.y)];
    [line lineToPoint:NSMakePoint(x, NSMaxY(rect))];
    [[NSColor systemBlueColor] setStroke];
    line.lineWidth = 1.0;
    [line stroke];
    
    // Find date index at this X
    NSInteger dateIndex = [self dateIndexAtX:x inRect:rect];
    
    if (dateIndex >= 0 && dateIndex < self.dates.count) {
        
        // Draw info box with values for all models
        NSMutableString *info = [NSMutableString string];
        
        // Date
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        [info appendFormat:@"%@\n", [formatter stringFromDate:self.dates[dateIndex]]];
        
        // Values for each model
        for (ScreenerModel *model in self.session.models) {
            NSArray<NSNumber *> *values = self.modelData[model.modelID];
            if (dateIndex < values.count) {
                CGFloat value = [values[dateIndex] doubleValue];
                NSColor *color = self.modelColors[model.modelID];
                
                [info appendFormat:@"%@: %@\n",
                    model.displayName, [self formatValue:value]];
            }
        }
        
        // Draw info box
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:11],
            NSForegroundColorAttributeName: [NSColor labelColor]
        };
        
        NSSize infoSize = [info sizeWithAttributes:attrs];
        CGFloat infoX = x + 10;
        CGFloat infoY = NSMaxY(rect) - infoSize.height - 10;
        
        // Adjust if would go off screen
        if (infoX + infoSize.width > NSMaxX(rect)) {
            infoX = x - infoSize.width - 10;
        }
        
        // Draw background
        NSRect infoRect = NSMakeRect(infoX - 5, infoY - 2, infoSize.width + 10, infoSize.height + 4);
        [[NSColor controlBackgroundColor] setFill];
        NSRectFill(infoRect);
        
        // Draw border
        [[NSColor separatorColor] setStroke];
        NSFrameRect(infoRect);
        
        // Draw text
        [info drawAtPoint:NSMakePoint(infoX, infoY) withAttributes:attrs];
    }
}

- (void)drawTitle {
    if (!self.metricKey) return;
    
    NSString *title = [self metricDisplayName:self.metricKey];
    
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };
    
    NSSize titleSize = [title sizeWithAttributes:attrs];
    [title drawAtPoint:NSMakePoint(10, self.bounds.size.height - titleSize.height - 5)
        withAttributes:attrs];
}

#pragma mark - Helper Methods

- (CGFloat)xPositionForDateIndex:(NSInteger)index inRect:(NSRect)rect {
    if (self.dates.count <= 1) return rect.origin.x;
    
    CGFloat ratio = (CGFloat)index / (CGFloat)(self.dates.count - 1);
    return rect.origin.x + (rect.size.width * ratio);
}

- (CGFloat)yPositionForValue:(CGFloat)value inRect:(NSRect)rect {
    if (self.valueRange == 0) return rect.origin.y;
    
    CGFloat ratio = (value - self.minValue) / self.valueRange;
    return rect.origin.y + (rect.size.height * ratio);
}

- (NSInteger)dateIndexAtX:(CGFloat)x inRect:(NSRect)rect {
    if (self.dates.count == 0) return -1;
    
    CGFloat relativeX = x - rect.origin.x;
    CGFloat ratio = relativeX / rect.size.width;
    
    NSInteger index = (NSInteger)(ratio * (self.dates.count - 1));
    
    if (index < 0) index = 0;
    if (index >= self.dates.count) index = self.dates.count - 1;
    
    return index;
}

- (NSString *)formatValue:(CGFloat)value {
    
    // Format based on metric type
    if ([self.metricKey isEqualToString:@"symbolCount"] ||
        [self.metricKey isEqualToString:@"tradeCount"]) {
        return [NSString stringWithFormat:@"%ld", (long)value];
    }
    else if ([self.metricKey isEqualToString:@"winRate"] ||
             [self.metricKey isEqualToString:@"avgGain"] ||
             [self.metricKey isEqualToString:@"avgLoss"]) {
        return [NSString stringWithFormat:@"%.1f%%", value];
    }
    else {
        return [NSString stringWithFormat:@"%.2f", value];
    }
}

- (NSString *)metricDisplayName:(NSString *)key {
    
    NSDictionary *displayNames = @{
        @"symbolCount": @"# Symbols",
        @"winRate": @"Win Rate %",
        @"avgGain": @"Avg Gain %",
        @"avgLoss": @"Avg Loss %",
        @"tradeCount": @"# Trades",
        @"winLossRatio": @"Win/Loss Ratio"
    };
    
    return displayNames[key] ?: key;
}

#pragma mark - Crosshair Methods

- (void)showCrosshairAtX:(CGFloat)x {
    self.showCrosshair = YES;
    self.crosshairX = x;
    [self setNeedsDisplay:YES];
}

- (void)hideCrosshair {
    self.showCrosshair = NO;
    [self setNeedsDisplay:YES];
}

#pragma mark - Mouse Events

- (void)mouseMoved:(NSEvent *)event {
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    
    CGFloat leftMargin = 60;
    CGFloat rightMargin = 100;
    NSRect chartRect = NSMakeRect(leftMargin, 30,
                                  self.bounds.size.width - leftMargin - rightMargin,
                                  self.bounds.size.height - 60);
    
    if (NSPointInRect(location, chartRect)) {
        [self showCrosshairAtX:location.x];
        
        // Notify delegate for coordination with candlestick chart
        NSInteger dateIndex = [self dateIndexAtX:location.x inRect:chartRect];
        if (dateIndex >= 0 && dateIndex < self.dates.count) {
            NSDate *date = self.dates[dateIndex];
            
            if ([self.delegate respondsToSelector:@selector(comparisonChartView:didMoveCrosshairToDate:)]) {
                [self.delegate comparisonChartView:self didMoveCrosshairToDate:date];
            }
        }
    } else {
        [self hideCrosshair];
    }
}

- (void)mouseExited:(NSEvent *)event {
    [self hideCrosshair];
}

@end
