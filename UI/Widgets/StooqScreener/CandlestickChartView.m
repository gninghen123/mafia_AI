//
//  CandlestickChartView.m
//  TradingApp
//

#import "CandlestickChartView.h"

@interface CandlestickChartView ()

// Drawing state
@property (nonatomic, assign) CGFloat minPrice;
@property (nonatomic, assign) CGFloat maxPrice;
@property (nonatomic, assign) CGFloat priceRange;

// Mouse tracking
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) CGFloat dragStartX;
@property (nonatomic, assign) NSInteger dragStartIndex;

// Tracking area for mouse events
@property (nonatomic, strong) NSTrackingArea *trackingArea;

@end

@implementation CandlestickChartView

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
    
    _visibleStartIndex = 0;
    _visibleEndIndex = 0;
    _showCrosshair = NO;
    _isDragging = NO;
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

- (void)setData:(NSArray<HistoricalBarModel *> *)bars symbol:(NSString *)symbol {
    self.bars = bars;
    self.symbolName = symbol;
    
    if (bars.count > 0) {
        // Show all bars initially
        self.visibleStartIndex = 0;
        self.visibleEndIndex = bars.count - 1;
        
        [self calculatePriceRange];
    }
    
    [self setNeedsDisplay:YES];
}

- (void)calculatePriceRange {
    if (!self.bars || self.visibleStartIndex < 0 || self.visibleEndIndex >= self.bars.count) {
        return;
    }
    
    self.minPrice = CGFLOAT_MAX;
    self.maxPrice = -CGFLOAT_MAX;
    
    for (NSInteger i = self.visibleStartIndex; i <= self.visibleEndIndex; i++) {
        HistoricalBarModel *bar = self.bars[i];
        
        if (bar.low < self.minPrice) {
            self.minPrice = bar.low;
        }
        if (bar.high > self.maxPrice) {
            self.maxPrice = bar.high;
        }
    }
    
    self.priceRange = self.maxPrice - self.minPrice;
    
    // Add 5% padding
    CGFloat padding = self.priceRange * 0.05;
    self.minPrice -= padding;
    self.maxPrice += padding;
    self.priceRange = self.maxPrice - self.minPrice;
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (!self.bars || self.bars.count == 0) {
        [self drawEmptyState];
        return;
    }
    
    // Draw background
    [[NSColor windowBackgroundColor] setFill];
    NSRectFill(dirtyRect);
    
    // Calculate chart area (leave margins)
    CGFloat leftMargin = 60;
    CGFloat rightMargin = 20;
    CGFloat topMargin = 30;
    CGFloat bottomMargin = 30;
    
    NSRect chartRect = NSMakeRect(leftMargin,
                                  bottomMargin,
                                  self.bounds.size.width - leftMargin - rightMargin,
                                  self.bounds.size.height - topMargin - bottomMargin);
    
    // Draw axes and grid
    [self drawAxesInRect:chartRect];
    
    // Draw candlesticks
    [self drawCandlesticksInRect:chartRect];
    
    // Draw crosshair if enabled
    if (self.showCrosshair) {
        [self drawCrosshairAtX:self.crosshairX inRect:chartRect];
    }
    
    // Draw title
    [self drawTitle];
}

- (void)drawEmptyState {
    NSString *message = @"No data to display";
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
    
    // Draw price axis (left)
    NSBezierPath *priceAxis = [NSBezierPath bezierPath];
    [priceAxis moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y)];
    [priceAxis lineToPoint:NSMakePoint(rect.origin.x, NSMaxY(rect))];
    [[NSColor separatorColor] setStroke];
    priceAxis.lineWidth = 1.0;
    [priceAxis stroke];
    
    // Draw time axis (bottom)
    NSBezierPath *timeAxis = [NSBezierPath bezierPath];
    [timeAxis moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y)];
    [timeAxis lineToPoint:NSMakePoint(NSMaxX(rect), rect.origin.y)];
    [timeAxis stroke];
    
    // Draw price labels
    NSInteger priceSteps = 5;
    for (NSInteger i = 0; i <= priceSteps; i++) {
        CGFloat ratio = (CGFloat)i / (CGFloat)priceSteps;
        CGFloat price = self.minPrice + (self.priceRange * ratio);
        CGFloat y = rect.origin.y + (rect.size.height * ratio);
        
        // Grid line
        NSBezierPath *gridLine = [NSBezierPath bezierPath];
        [gridLine moveToPoint:NSMakePoint(rect.origin.x, y)];
        [gridLine lineToPoint:NSMakePoint(NSMaxX(rect), y)];
        [[NSColor separatorColor] setStroke];
        gridLine.lineWidth = 0.5;
        [gridLine stroke];
        
        // Price label
        NSString *priceLabel = [NSString stringWithFormat:@"$%.2f", price];
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:10],
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
        };
        
        NSSize labelSize = [priceLabel sizeWithAttributes:attrs];
        [priceLabel drawAtPoint:NSMakePoint(rect.origin.x - labelSize.width - 5, y - labelSize.height / 2)
                 withAttributes:attrs];
    }
}

- (void)drawCandlesticksInRect:(NSRect)rect {
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex + 1;
    if (visibleBars <= 0) return;
    
    CGFloat candleWidth = rect.size.width / (CGFloat)visibleBars;
    CGFloat candleBodyWidth = candleWidth * 0.7;
    CGFloat candleSpacing = candleWidth * 0.15;
    
    for (NSInteger i = self.visibleStartIndex; i <= self.visibleEndIndex; i++) {
        HistoricalBarModel *bar = self.bars[i];
        
        NSInteger relativeIndex = i - self.visibleStartIndex;
        CGFloat x = rect.origin.x + (relativeIndex * candleWidth) + candleSpacing;
        
        // Calculate Y positions
        CGFloat highY = [self yPositionForPrice:bar.high inRect:rect];
        CGFloat lowY = [self yPositionForPrice:bar.low inRect:rect];
        CGFloat openY = [self yPositionForPrice:bar.open inRect:rect];
        CGFloat closeY = [self yPositionForPrice:bar.close inRect:rect];
        
        BOOL isUp = bar.close >= bar.open;
        NSColor *color = isUp ? [NSColor systemGreenColor] : [NSColor systemRedColor];
        
        // Draw wick (high-low line)
        NSBezierPath *wick = [NSBezierPath bezierPath];
        [wick moveToPoint:NSMakePoint(x + candleBodyWidth / 2, highY)];
        [wick lineToPoint:NSMakePoint(x + candleBodyWidth / 2, lowY)];
        [color setStroke];
        wick.lineWidth = 1.0;
        [wick stroke];
        
        // Draw body (open-close rectangle)
        CGFloat bodyTop = isUp ? closeY : openY;
        CGFloat bodyHeight = fabs(closeY - openY);
        if (bodyHeight < 1.0) bodyHeight = 1.0; // Minimum height for doji
        
        NSRect bodyRect = NSMakeRect(x, bodyTop, candleBodyWidth, bodyHeight);
        
        if (isUp) {
            [color setFill];
            NSRectFill(bodyRect);
        } else {
            [color setFill];
            NSRectFill(bodyRect);
        }
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
    
    // Find bar at this X position
    HistoricalBarModel *bar = [self barAtX:x inRect:rect];
    if (bar) {
        // Draw info box
        NSString *info = [NSString stringWithFormat:@"O:%.2f H:%.2f L:%.2f C:%.2f",
                         bar.open, bar.high, bar.low, bar.close];
        
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:11],
            NSForegroundColorAttributeName: [NSColor labelColor],
            NSBackgroundColorAttributeName: [NSColor controlBackgroundColor]
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
    if (!self.symbolName) return;
    
    NSString *title = [NSString stringWithFormat:@"%@ - Candlestick Chart", self.symbolName];
    
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };
    
    NSSize titleSize = [title sizeWithAttributes:attrs];
    [title drawAtPoint:NSMakePoint(10, self.bounds.size.height - titleSize.height - 5)
        withAttributes:attrs];
}

#pragma mark - Helper Methods

- (CGFloat)yPositionForPrice:(CGFloat)price inRect:(NSRect)rect {
    if (self.priceRange == 0) return rect.origin.y;
    
    CGFloat ratio = (price - self.minPrice) / self.priceRange;
    return rect.origin.y + (rect.size.height * ratio);
}

- (nullable HistoricalBarModel *)barAtX:(CGFloat)x inRect:(NSRect)rect {
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex + 1;
    if (visibleBars <= 0) return nil;
    
    CGFloat candleWidth = rect.size.width / (CGFloat)visibleBars;
    CGFloat relativeX = x - rect.origin.x;
    NSInteger index = (NSInteger)(relativeX / candleWidth);
    
    NSInteger barIndex = self.visibleStartIndex + index;
    if (barIndex >= 0 && barIndex < self.bars.count) {
        return self.bars[barIndex];
    }
    
    return nil;
}

#pragma mark - Zoom Methods

- (void)zoomToDateRange:(NSDate *)startDate endDate:(NSDate *)endDate {
    
    if (!self.bars || self.bars.count == 0) return;
    
    // Find indices for dates
    NSInteger startIndex = -1;
    NSInteger endIndex = -1;
    
    for (NSInteger i = 0; i < self.bars.count; i++) {
        HistoricalBarModel *bar = self.bars[i];
        
        if (startIndex == -1 && [bar.date compare:startDate] != NSOrderedAscending) {
            startIndex = i;
        }
        
        if ([bar.date compare:endDate] != NSOrderedDescending) {
            endIndex = i;
        }
    }
    
    if (startIndex >= 0 && endIndex >= 0 && startIndex <= endIndex) {
        self.visibleStartIndex = startIndex;
        self.visibleEndIndex = endIndex;
        
        [self calculatePriceRange];
        [self setNeedsDisplay:YES];
        
        NSLog(@"📊 Zoomed to range: %ld - %ld (%ld bars)",
              (long)startIndex, (long)endIndex, (long)(endIndex - startIndex + 1));
    }
}

- (void)zoomIn {
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex + 1;
    NSInteger newVisibleBars = visibleBars / 2;
    
    if (newVisibleBars < 10) newVisibleBars = 10; // Minimum 10 bars
    
    NSInteger center = (self.visibleStartIndex + self.visibleEndIndex) / 2;
    self.visibleStartIndex = center - newVisibleBars / 2;
    self.visibleEndIndex = center + newVisibleBars / 2;
    
    // Bounds check
    if (self.visibleStartIndex < 0) self.visibleStartIndex = 0;
    if (self.visibleEndIndex >= self.bars.count) self.visibleEndIndex = self.bars.count - 1;
    
    [self calculatePriceRange];
    [self setNeedsDisplay:YES];
}

- (void)zoomOut {
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex + 1;
    NSInteger newVisibleBars = visibleBars * 2;
    
    if (newVisibleBars > self.bars.count) {
        [self zoomAll];
        return;
    }
    
    NSInteger center = (self.visibleStartIndex + self.visibleEndIndex) / 2;
    self.visibleStartIndex = center - newVisibleBars / 2;
    self.visibleEndIndex = center + newVisibleBars / 2;
    
    // Bounds check
    if (self.visibleStartIndex < 0) self.visibleStartIndex = 0;
    if (self.visibleEndIndex >= self.bars.count) self.visibleEndIndex = self.bars.count - 1;
    
    [self calculatePriceRange];
    [self setNeedsDisplay:YES];
}

- (void)zoomAll {
    if (!self.bars || self.bars.count == 0) return;
    
    self.visibleStartIndex = 0;
    self.visibleEndIndex = self.bars.count - 1;
    
    [self calculatePriceRange];
    [self setNeedsDisplay:YES];
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

- (void)mouseDown:(NSEvent *)event {
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    
    self.isDragging = YES;
    self.dragStartX = location.x;
    
    // Store start index for range selection
    CGFloat leftMargin = 60;
    NSRect chartRect = NSMakeRect(leftMargin, 30, self.bounds.size.width - 80, self.bounds.size.height - 60);
    HistoricalBarModel *bar = [self barAtX:location.x inRect:chartRect];
    
    if (bar) {
        self.dragStartIndex = [self.bars indexOfObject:bar];
    }
}

- (void)mouseDragged:(NSEvent *)event {
    if (!self.isDragging) return;
    
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    
    // Show selection preview (could draw a highlighted region)
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (!self.isDragging) return;
    
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    
    // Calculate selected range
    CGFloat leftMargin = 60;
    NSRect chartRect = NSMakeRect(leftMargin, 30, self.bounds.size.width - 80, self.bounds.size.height - 60);
    
    HistoricalBarModel *endBar = [self barAtX:location.x inRect:chartRect];
    
    if (endBar && self.dragStartIndex >= 0) {
        NSInteger endIndex = [self.bars indexOfObject:endBar];
        
        NSInteger startIdx = MIN(self.dragStartIndex, endIndex);
        NSInteger endIdx = MAX(self.dragStartIndex, endIndex);
        
        if (startIdx != endIdx && startIdx >= 0 && endIdx < self.bars.count) {
            // User selected a range - zoom to it
            NSDate *startDate = self.bars[startIdx].date;
            NSDate *endDate = self.bars[endIdx].date;
            
            [self zoomToDateRange:startDate endDate:endDate];
            
            // Notify delegate
            if ([self.delegate respondsToSelector:@selector(candlestickChartView:didSelectDateRange:endDate:)]) {
                [self.delegate candlestickChartView:self didSelectDateRange:startDate endDate:endDate];
            }
        }
    }
    
    self.isDragging = NO;
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    
    CGFloat leftMargin = 60;
    NSRect chartRect = NSMakeRect(leftMargin, 30, self.bounds.size.width - 80, self.bounds.size.height - 60);
    
    if (NSPointInRect(location, chartRect)) {
        [self showCrosshairAtX:location.x];
        
        // Notify delegate for coordination with comparison chart
        HistoricalBarModel *bar = [self barAtX:location.x inRect:chartRect];
        if ([self.delegate respondsToSelector:@selector(candlestickChartView:didMoveCrosshairToDate:bar:)]) {
            [self.delegate candlestickChartView:self didMoveCrosshairToDate:bar.date bar:bar];
        }
    } else {
        [self hideCrosshair];
    }
}

- (void)mouseExited:(NSEvent *)event {
    [self hideCrosshair];
}

@end
