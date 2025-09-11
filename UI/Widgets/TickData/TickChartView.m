//
//  TickChartView.m
//  mafia_AI
//

#import "TickChartView.h"
#import "TickChartWidget.h"
#import "Quartz/Quartz.h"

@interface TickChartView ()

@property (nonatomic) CGRect chartRect;
@property (nonatomic) CGRect volumeRect;
@property (nonatomic) double minPrice;
@property (nonatomic) double maxPrice;
@property (nonatomic) NSInteger maxVolume;

// Mouse tracking
@property (nonatomic) NSPoint mouseLocation;
@property (nonatomic) BOOL isMouseInside;
@property (nonatomic) NSInteger hoveredTickIndex;

@property (nonatomic, strong) CAShapeLayer *gridLayer;
@property (nonatomic, strong) CAShapeLayer *priceLayer;
@property (nonatomic, strong) CAShapeLayer *volumeUpLayer;
@property (nonatomic, strong) CAShapeLayer *volumeDownLayer;
@property (nonatomic, strong) CAShapeLayer *volumeNeutralLayer;
@property (nonatomic, strong) CAShapeLayer *vwapLayer;
@property (nonatomic, strong) CAShapeLayer *crosshairLayer;

@end

@implementation TickChartView

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setupChartView];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupChartView];
    }
    return self;
}

- (void)setupChartView {
    _showVolume = YES;
    _showVWAP = YES;
    _showBuySellColors = YES;
    _hoveredTickIndex = -1;
    
    self.wantsLayer = YES;
    _gridLayer = [CAShapeLayer layer];
    _priceLayer = [CAShapeLayer layer];
    _volumeUpLayer = [CAShapeLayer layer];
    _volumeDownLayer = [CAShapeLayer layer];
    _volumeNeutralLayer = [CAShapeLayer layer];
    _vwapLayer = [CAShapeLayer layer];
    _crosshairLayer = [CAShapeLayer layer];
    for (CAShapeLayer *layer in @[_gridLayer, _priceLayer, _volumeUpLayer, _volumeDownLayer, _volumeNeutralLayer, _vwapLayer, _crosshairLayer]) {
        layer.fillColor = nil;
        layer.strokeColor = [NSColor clearColor].CGColor;
        [self.layer addSublayer:layer];
    }
    
    [self setupTrackingArea];
}

- (void)setupTrackingArea {
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc]
        initWithRect:self.bounds
        options:(NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect |
                NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited)
        owner:self
        userInfo:nil];
    [self addTrackingArea:trackingArea];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) {
        [self removeTrackingArea:area];
    }
    [self setupTrackingArea];
}

#pragma mark - Public Methods

- (void)updateWithTickData:(NSArray<TickDataModel *> *)tickData {
    self.tickData = tickData;
    [self calculateChartBounds];
    [self redrawChart];
}

- (void)redrawChart {
    if (!self.tickData || self.tickData.count == 0) {
        [self drawEmptyState];
        self.gridLayer.path = nil;
        self.priceLayer.path = nil;
        self.volumeUpLayer.path = nil;
        self.volumeDownLayer.path = nil;
        self.volumeNeutralLayer.path = nil;
        self.vwapLayer.path = nil;
        self.crosshairLayer.path = nil;
        [self setNeedsDisplay:YES];
        return;
    }
    
    [self calculateLayout];
    [self drawGridAndAxes];
    [self drawVolumeChart];
    [self drawPriceChart];
    
    if (self.showVWAP) [self drawVWAPLine];
    if (self.isMouseInside) {
        [self drawCrosshair];
    } else {
        self.crosshairLayer.path = nil;
    }
    [self setNeedsDisplay:YES];
}

#pragma mark - Drawing

- (void)drawEmptyState {
    [self setNeedsDisplay:YES];
}

- (void)calculateLayout {
    CGFloat margin = 20;
    CGFloat volumeHeight = self.showVolume ? self.bounds.size.height * 0.25 : 0;
    
    self.chartRect = CGRectMake(
        margin,
        volumeHeight + margin,
        self.bounds.size.width - (margin * 2),
        self.bounds.size.height - volumeHeight - (margin * 2)
    );
    
    if (self.showVolume) {
        self.volumeRect = CGRectMake(
            margin,
            margin,
            self.bounds.size.width - (margin * 2),
            volumeHeight - margin
        );
    }
}

- (void)calculateChartBounds {
    if (!self.tickData || self.tickData.count == 0) return;
    
    self.minPrice = CGFLOAT_MAX;
    self.maxPrice = CGFLOAT_MIN;
    self.maxVolume = 0;
    
    for (TickDataModel *tick in self.tickData) {
        if (tick.price < self.minPrice) self.minPrice = tick.price;
        if (tick.price > self.maxPrice) self.maxPrice = tick.price;
        if (tick.volume > self.maxVolume) self.maxVolume = tick.volume;
    }
    
    double priceRange = self.maxPrice - self.minPrice;
    double padding = priceRange * 0.05;
    self.minPrice -= padding;
    self.maxPrice += padding;
}

- (void)drawGridAndAxes {
    CGMutablePathRef path = CGPathCreateMutable();
    
    NSInteger gridLines = 5;
    for (NSInteger i = 0; i <= gridLines; i++) {
        double y = self.chartRect.origin.y + (self.chartRect.size.height * i / gridLines);
        CGPathMoveToPoint(path, NULL, self.chartRect.origin.x, y);
        CGPathAddLineToPoint(path, NULL, self.chartRect.origin.x + self.chartRect.size.width, y);
    }
    
    self.gridLayer.path = path;
    self.gridLayer.lineWidth = 0.5;
    self.gridLayer.strokeColor = [NSColor gridColor].CGColor;
    self.gridLayer.fillColor = nil;
    
    CGPathRelease(path);
    
    // Price labels will be drawn in drawRect:
}

- (void)drawPriceChart {
    if (self.tickData.count < 2) {
        self.priceLayer.path = nil;
        return;
    }
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    for (NSInteger i = 0; i < self.tickData.count; i++) {
        TickDataModel *tick = self.tickData[i];
        NSPoint point = [self pointForTickIndex:i price:tick.price];
        
        if (i == 0) {
            CGPathMoveToPoint(path, NULL, point.x, point.y);
        } else {
            CGPathAddLineToPoint(path, NULL, point.x, point.y);
        }
    }
    
    self.priceLayer.path = path;
    self.priceLayer.lineWidth = 1.5;
    self.priceLayer.strokeColor = [NSColor systemBlueColor].CGColor;
    self.priceLayer.fillColor = nil;
    
    CGPathRelease(path);
}

- (void)drawVolumeChart {
    if (!self.showVolume || self.tickData.count == 0) {
        self.volumeUpLayer.path = nil;
        self.volumeDownLayer.path = nil;
        self.volumeNeutralLayer.path = nil;
        return;
    }
    
    CGMutablePathRef upPath = CGPathCreateMutable();
    CGMutablePathRef downPath = CGPathCreateMutable();
    CGMutablePathRef neutralPath = CGPathCreateMutable();
    
    for (NSInteger i = 0; i < self.tickData.count; i++) {
        TickDataModel *tick = self.tickData[i];
        
        double x = self.volumeRect.origin.x + self.volumeRect.size.width - (self.volumeRect.size.width * i / (self.tickData.count - 1));
        double barHeight = (self.volumeRect.size.height * tick.volume) / self.maxVolume;
        CGRect volumeBar = CGRectMake(x - 1, self.volumeRect.origin.y, 2, barHeight);
        
        switch (tick.direction) {
            case TickDirectionUp:
                CGPathAddRect(upPath, NULL, volumeBar);
                break;
            case TickDirectionDown:
                CGPathAddRect(downPath, NULL, volumeBar);
                break;
            default:
                CGPathAddRect(neutralPath, NULL, volumeBar);
                break;
        }
    }
    
    self.volumeUpLayer.path = upPath;
    self.volumeUpLayer.fillColor = [NSColor systemGreenColor].CGColor;
    self.volumeUpLayer.strokeColor = nil;
    
    self.volumeDownLayer.path = downPath;
    self.volumeDownLayer.fillColor = [NSColor systemRedColor].CGColor;
    self.volumeDownLayer.strokeColor = nil;
    
    self.volumeNeutralLayer.path = neutralPath;
    self.volumeNeutralLayer.fillColor = [NSColor systemGrayColor].CGColor;
    self.volumeNeutralLayer.strokeColor = nil;
    
    CGPathRelease(upPath);
    CGPathRelease(downPath);
    CGPathRelease(neutralPath);
}

- (void)drawVWAPLine {
    if (self.tickData.count < 2) {
        self.vwapLayer.path = nil;
        return;
    }
    
    double vwap = [self.widget currentVWAP];
    if (vwap <= 0) {
        self.vwapLayer.path = nil;
        return;
    }
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    double y = [self yCoordinateForPrice:vwap];
    CGPathMoveToPoint(path, NULL, self.chartRect.origin.x, y);
    CGPathAddLineToPoint(path, NULL, self.chartRect.origin.x + self.chartRect.size.width, y);
    
    self.vwapLayer.path = path;
    self.vwapLayer.lineWidth = 1.0;
    self.vwapLayer.strokeColor = [NSColor systemOrangeColor].CGColor;
    self.vwapLayer.fillColor = nil;
    
    CGPathRelease(path);
}

- (void)drawCrosshair {
    if (self.hoveredTickIndex < 0 || self.hoveredTickIndex >= self.tickData.count) {
        self.crosshairLayer.path = nil;
        return;
    }
    
    TickDataModel *hoveredTick = self.tickData[self.hoveredTickIndex];
    // Compute the X coordinate so that the crosshair aligns with the reversed (right-to-left) chart direction.
    double x = self.chartRect.origin.x + self.chartRect.size.width - (self.chartRect.size.width * self.hoveredTickIndex / (self.tickData.count - 1));
    NSPoint tickPoint = NSMakePoint(x, [self yCoordinateForPrice:hoveredTick.price]);
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    CGPathMoveToPoint(path, NULL, tickPoint.x, self.chartRect.origin.y);
    CGPathAddLineToPoint(path, NULL, tickPoint.x, self.chartRect.origin.y + self.chartRect.size.height);
    
    CGPathMoveToPoint(path, NULL, self.chartRect.origin.x, tickPoint.y);
    CGPathAddLineToPoint(path, NULL, self.chartRect.origin.x + self.chartRect.size.width, tickPoint.y);
    
    self.crosshairLayer.path = path;
    self.crosshairLayer.lineWidth = 0.5;
    self.crosshairLayer.strokeColor = [NSColor systemGrayColor].CGColor;
    self.crosshairLayer.fillColor = nil;
    
    CGPathRelease(path);
}

#pragma mark - drawRect for overlays

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Fill background
    [[NSColor controlBackgroundColor] setFill];
    NSRectFill(self.bounds);
    
    if (!self.tickData || self.tickData.count == 0) return;
    
    // Draw price labels on grid lines
    NSInteger gridLines = 5;
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    for (NSInteger i = 0; i <= gridLines; i++) {
        double y = self.chartRect.origin.y + (self.chartRect.size.height * i / gridLines);
        double priceValue = self.maxPrice - ((self.maxPrice - self.minPrice) * i / gridLines);
        NSString *priceString = [NSString stringWithFormat:@"%.2f", priceValue];
        
        NSSize textSize = [priceString sizeWithAttributes:attributes];
        NSPoint textPoint = NSMakePoint(self.chartRect.origin.x - textSize.width - 6, y - textSize.height / 2);
        [priceString drawAtPoint:textPoint withAttributes:attributes];
    }
    
    // Draw crosshair info box text
    if (self.isMouseInside && self.hoveredTickIndex >= 0 && self.hoveredTickIndex < self.tickData.count) {
        TickDataModel *tick = self.tickData[self.hoveredTickIndex];
        
        NSString *infoText = [NSString stringWithFormat:@"%@ | %.4f | %@ %@",
                             [tick formattedTime], tick.price, [self formatVolume:tick.volume], [tick directionString]];
        
        NSDictionary *textAttributes = @{
            NSFontAttributeName: [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: [NSColor controlTextColor]
        };
        
        NSSize textSize = [infoText sizeWithAttributes:textAttributes];
        NSPoint infoPoint = NSMakePoint(self.mouseLocation.x + 10, self.mouseLocation.y + 10);
        
        if (infoPoint.x + textSize.width > self.bounds.size.width - 10) {
            infoPoint.x = self.mouseLocation.x - textSize.width - 10;
        }
        
        NSRect infoRect = NSMakeRect(infoPoint.x - 4, infoPoint.y - 2,
                                    textSize.width + 8, textSize.height + 4);
        [[NSColor controlBackgroundColor] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:infoRect xRadius:4 yRadius:4] fill];
        
        [infoText drawAtPoint:infoPoint withAttributes:textAttributes];
    }
}

#pragma mark - Helper Methods

- (NSPoint)pointForTickIndex:(NSInteger)index price:(double)price {
    if (self.tickData.count <= 1) return NSZeroPoint;
    
    double x = self.chartRect.origin.x + self.chartRect.size.width - (self.chartRect.size.width * index / (self.tickData.count - 1));
    double y = [self yCoordinateForPrice:price];
    
    return NSMakePoint(x, y);
}

- (double)yCoordinateForPrice:(double)price {
    double priceRange = self.maxPrice - self.minPrice;
    if (priceRange == 0) return self.chartRect.origin.y + self.chartRect.size.height / 2;
    
    double normalizedPrice = (price - self.minPrice) / priceRange;
    return self.chartRect.origin.y + (self.chartRect.size.height * normalizedPrice);
}

- (NSInteger)tickIndexForXCoordinate:(double)x {
    if (self.tickData.count <= 1) return -1;
    
    double relativeX = x - self.chartRect.origin.x;
    double normalizedX = 1.0 - (relativeX / self.chartRect.size.width);
    
    NSInteger index = (NSInteger)(normalizedX * (self.tickData.count - 1));
    return MAX(0, MIN(index, self.tickData.count - 1));
}

- (NSColor *)colorForTickDirection:(TickDirection)direction {
    switch (direction) {
        case TickDirectionUp: return [NSColor systemGreenColor];
        case TickDirectionDown: return [NSColor systemRedColor];
        default: return [NSColor systemGrayColor];
    }
}

- (NSString *)formatVolume:(NSInteger)volume {
    if (volume >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", volume / 1000000.0];
    } else if (volume >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", volume / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%ld", (long)volume];
    }
}

#pragma mark - Mouse Events

- (void)mouseMoved:(NSEvent *)event {
    self.mouseLocation = [self convertPoint:event.locationInWindow fromView:nil];
    
    if (NSPointInRect(self.mouseLocation, self.chartRect)) {
        self.hoveredTickIndex = [self tickIndexForXCoordinate:self.mouseLocation.x];
    } else {
        self.hoveredTickIndex = -1;
    }
    
    [self redrawChart];
}

- (void)mouseEntered:(NSEvent *)event {
    self.isMouseInside = YES;
    [self redrawChart];
}

- (void)mouseExited:(NSEvent *)event {
    self.isMouseInside = NO;
    self.hoveredTickIndex = -1;
    [self redrawChart];
}

@end
