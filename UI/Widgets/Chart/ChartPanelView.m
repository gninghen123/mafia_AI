//
//  ChartPanelView.m
//  TradingApp
//
//  Individual chart panel for rendering specific indicators
//

#import "ChartPanelView.h"
#import "ChartWidget.h"
#import "ChartObjectRenderer.h"
#import "ChartObjectModels.h"
#import "ChartObjectsManager.h"
#import "ChartObjectSettingsWindow.h"
#import <objc/runtime.h>
#import "ChartAlertRenderer.h"
#import "AlertEditController.h"
#import "dataHub.h"

@interface ChartPanelView ()




@property (nonatomic, assign) BOOL isInAlertDragMode;

// Mouse tracking
@property (nonatomic, strong) NSTrackingArea *trackingArea;

// Interaction state
@property (nonatomic, assign) BOOL isMouseDown;
@property (nonatomic, assign) BOOL isRightMouseDown;
@property (nonatomic, assign) NSPoint dragStartPoint;
@property (nonatomic, assign) NSPoint lastMousePoint;

// Selection state
@property (nonatomic, assign) BOOL isInChartPortionSelectionMode;
@property (nonatomic, assign) NSInteger selectionStartIndex;
@property (nonatomic, assign) NSInteger selectionEndIndex;
@property (nonatomic, assign) BOOL isInObjectCreationMode;
@property (nonatomic, assign) BOOL isInObjectEditingMode;
@property (nonatomic, assign) ChartObjectType currentCreationObjectType;


@end

@implementation ChartPanelView

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type {
    self = [super init];
    if (self) {
        _panelType = type;
        [self setupPanel];
        
    }
    return self;
}

- (void)setupPanel {
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.borderWidth = 1.0;
    self.dragThreshold = 4.0; // pixels

    [self setupPerformanceLayers];
    [self setupMouseTracking];
}

- (void)setupPerformanceLayers {
    // Chart content layer (static - redraws only when data changes)
    self.chartContentLayer = [CALayer layer];
    self.chartContentLayer.delegate = self;
    self.chartContentLayer.needsDisplayOnBoundsChange = YES;
    [self.layer addSublayer:self.chartContentLayer];
    
    // Selection layer (redraws only during selection)
    self.chartPortionSelectionLayer = [CALayer layer];
    self.chartPortionSelectionLayer.delegate = self;
    [self.layer addSublayer:self.chartPortionSelectionLayer];
    
    // Crosshair layer (redraws frequently but lightweight)
    self.crosshairLayer = [CALayer layer];
    self.crosshairLayer.delegate = self;
    [self.layer addSublayer:self.crosshairLayer];
    
    NSLog(@"🎯 ChartPanelView: Performance layers setup completed");
}


- (void)layout {
    [super layout];
    
    // Update all layer frames
    NSRect bounds = self.bounds;
    self.chartContentLayer.frame = bounds;
    self.chartPortionSelectionLayer.frame = bounds;
    self.crosshairLayer.frame = bounds;
    
    // Update objects renderer layer frames AND coordinate context bounds
    if (self.objectRenderer) {
        [self.objectRenderer updateLayerFrames];
        
        // Update bounds in coordinate context
        if (self.chartData) {
            [self.objectRenderer updateCoordinateContext:self.chartData
                                              startIndex:self.visibleStartIndex
                                                endIndex:self.visibleEndIndex
                                               yRangeMin:self.yRangeMin
                                               yRangeMax:self.yRangeMax
                                                  bounds:bounds];
        }
    }
}

#pragma mark - CALayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    if (layer == self.chartContentLayer) {
        [self drawChartContent];
    } else if (layer == self.crosshairLayer) {
        [self drawCrosshairContent];
    } else if (layer == self.chartPortionSelectionLayer) {
        [self drawChartPortionSelectionContent];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)setupMouseTracking {
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                     options:(NSTrackingActiveInKeyWindow |
                                                             NSTrackingInVisibleRect |
                                                             NSTrackingMouseMoved |
                                                             NSTrackingMouseEnteredAndExited)
                                                       owner:self
                                                    userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

#pragma mark - Data Update



- (void)updateWithData:(NSArray<HistoricalBarModel *> *)data
            startIndex:(NSInteger)startIndex
              endIndex:(NSInteger)endIndex
             yRangeMin:(double)yMin
             yRangeMax:(double)yMax {
    
    // Update panel data (CODICE ESISTENTE)
    self.chartData = data;
    self.visibleStartIndex = startIndex;
    self.visibleEndIndex = endIndex;
    self.yRangeMin = yMin;
    self.yRangeMax = yMax;
    
    // CRITICO: Update objects renderer coordinate context (CODICE ESISTENTE)
    if (self.objectRenderer) {
        [self.objectRenderer updateCoordinateContext:data
                                          startIndex:startIndex
                                            endIndex:endIndex
                                           yRangeMin:yMin
                                           yRangeMax:yMax
                                              bounds:self.bounds];
        NSLog(@"🔄 Updated ChartObjectRenderer coordinate context with %lu bars", (unsigned long)data.count);
    }
    
    // 🆕 NUOVO: Update alert renderer coordinate context
    if (self.alertRenderer && self.chartWidget.currentSymbol) {
        [self.alertRenderer updateCoordinateContext:data
                                         startIndex:startIndex
                                           endIndex:endIndex
                                          yRangeMin:yMin
                                          yRangeMax:yMax
                                             bounds:self.bounds
                                      currentSymbol:self.chartWidget.currentSymbol];
        NSLog(@"🚨 Updated ChartAlertRenderer coordinate context with %lu bars for %@",
              (unsigned long)data.count, self.chartWidget.currentSymbol);
    }
    
    [self invalidateChartContent]; // CODICE ESISTENTE
}

- (void)setCrosshairPoint:(NSPoint)point visible:(BOOL)visible {
    self.crosshairPoint = point;
    self.crosshairVisible = visible;
    [self updateCrosshairOnly];
}

- (void)invalidateChartContent {
    // Only redraw the heavy chart content layer
    [self.chartContentLayer setNeedsDisplay];
}

- (void)updateCrosshairOnly {
    // Only redraw the lightweight crosshair layer
    [self.crosshairLayer setNeedsDisplay];
}

#pragma mark - Layer-Specific Drawing

- (void)drawChartContent {
    if (!self.chartData || self.chartData.count == 0) {
        [self drawEmptyState];
        return;
    }
    
    // Draw based on panel type
    if ([self.panelType isEqualToString:@"security"]) {
        [self drawCandlesticks];
    } else if ([self.panelType isEqualToString:@"volume"]) {
        [self drawVolumeHistogram];
    }
    
    NSLog(@"🎨 ChartPanelView: Chart content drawn (%@ panel)", self.panelType);
}


- (void)drawCrosshairContent {
    if (!self.crosshairVisible) return;
    
    NSPoint point = self.crosshairPoint;
    
    // Draw crosshair lines
    [[NSColor labelColor] setStroke];
    
    NSBezierPath *crosshair = [NSBezierPath bezierPath];
    crosshair.lineWidth = 1.0;
    
    // Vertical line
    [crosshair moveToPoint:NSMakePoint(point.x, 0)];
    [crosshair lineToPoint:NSMakePoint(point.x, self.bounds.size.height)];
    
    // Horizontal line
    [crosshair moveToPoint:NSMakePoint(0, point.y)];
    [crosshair lineToPoint:NSMakePoint(self.bounds.size.width, point.y)];
    
    [crosshair stroke];
    
    // ✅ USA IL METODO ESISTENTE se presente
    if ([self respondsToSelector:@selector(drawPriceLabelAtPoint:)]) {
     //todo   [self drawPriceLabelAtPoint:point];
    }
}


- (void)drawChartPortionSelectionContent {
    if (!self.isInChartPortionSelectionMode) return;
    
    // ✅ USA IL METODO ESISTENTE invece di riscriverlo
    [self drawChartPortionSelection];
}
- (void)drawRect:(NSRect)dirtyRect {
    // drawRect is now unused - all drawing happens in layer delegates
    // This improves performance by using CALayer rendering pipeline
}

#pragma mark - Original Drawing Methods (now used by layers)

- (void)drawEmptyState {
    NSString *message = [NSString stringWithFormat:@"%@ Panel - No Data", self.panelType.capitalizedString];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    NSSize textSize = [message sizeWithAttributes:attributes];
    NSPoint drawPoint = NSMakePoint((self.bounds.size.width - textSize.width) / 2,
                                   (self.bounds.size.height - textSize.height) / 2);
    
    [message drawAtPoint:drawPoint withAttributes:attributes];
}

- (void)drawCandlesticks {
    if (self.visibleStartIndex >= self.visibleEndIndex || self.visibleEndIndex > self.chartData.count) {
        return;
    }
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    CGFloat barWidth = (self.bounds.size.width - 20) / visibleBars; // 10px margin each side
    CGFloat barSpacing = MAX(1, barWidth * 0.1);
    barWidth = barWidth - barSpacing;
    
    for (NSInteger i = self.visibleStartIndex; i < self.visibleEndIndex && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        
        CGFloat x = 10 + (i - self.visibleStartIndex) * (barWidth + barSpacing);
        CGFloat openY = [self.objectRenderer.coordinateContext screenYForValue:bar.open];
        CGFloat closeY = [self.objectRenderer.coordinateContext screenYForValue:bar.close];
        CGFloat highY = [self.objectRenderer.coordinateContext screenYForValue:bar.high];
        CGFloat lowY = [self.objectRenderer.coordinateContext screenYForValue:bar.low];
        
        // Color based on direction
        NSColor *bodyColor = (bar.close >= bar.open) ? [NSColor systemGreenColor] : [NSColor systemRedColor];
        NSColor *wickColor = [NSColor labelColor];
        
        // Draw wick (high-low line)
        NSBezierPath *wickPath = [NSBezierPath bezierPath];
        [wickPath moveToPoint:NSMakePoint(x + barWidth/2, lowY)];
        [wickPath lineToPoint:NSMakePoint(x + barWidth/2, highY)];
        wickPath.lineWidth = 1.0;
        [wickColor setStroke];
        [wickPath stroke];
        
        // Draw body (open-close rectangle)
        CGFloat bodyTop = MAX(openY, closeY);
        CGFloat bodyBottom = MIN(openY, closeY);
        CGFloat bodyHeight = MAX(1, bodyTop - bodyBottom); // Minimum 1px height
        
        NSRect bodyRect = NSMakeRect(x, bodyBottom, barWidth, bodyHeight);
        
        if (bar.close >= bar.open) {
            [bodyColor setFill];
            NSBezierPath *bodyPath = [NSBezierPath bezierPathWithRect:bodyRect];
            [bodyPath fill];
        } else {
            // Red candle - filled
            [bodyColor setFill];
            NSBezierPath *bodyPath = [NSBezierPath bezierPathWithRect:bodyRect];
            [bodyPath fill];
        }
    }
}

- (void)drawVolumeHistogram {
    if (self.visibleStartIndex >= self.visibleEndIndex || self.visibleEndIndex > self.chartData.count) {
        return;
    }
    
    // Find max volume in visible range for scaling
    double maxVolume = 0;
    for (NSInteger i = self.visibleStartIndex; i < self.visibleEndIndex && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        maxVolume = MAX(maxVolume, bar.volume);
    }
    
    if (maxVolume == 0) return;
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    CGFloat barWidth = (self.bounds.size.width - 20) / visibleBars;
    CGFloat barSpacing = MAX(1, barWidth * 0.1);
    barWidth = barWidth - barSpacing;
    
    CGFloat chartHeight = self.bounds.size.height - 20; // 10px margin top/bottom
    
    for (NSInteger i = self.visibleStartIndex; i < self.visibleEndIndex && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        
        CGFloat x = 10 + (i - self.visibleStartIndex) * (barWidth + barSpacing);
        CGFloat height = (bar.volume / maxVolume) * chartHeight;
        CGFloat y = 10; // Start from bottom margin
        
        // Color based on price direction
        NSColor *barColor = (bar.close >= bar.open) ? [NSColor systemGreenColor] : [NSColor systemRedColor];
        
        NSRect volumeRect = NSMakeRect(x, y, barWidth, height);
        [barColor setFill];
        NSBezierPath *volumePath = [NSBezierPath bezierPathWithRect:volumeRect];
        [volumePath fill];
    }
}

- (void)drawChartPortionSelection {
    if (labs(self.selectionStartIndex-self.selectionEndIndex)==0) return;
    
    NSInteger startIdx = MIN(self.selectionStartIndex, self.selectionEndIndex);
    NSInteger endIdx = MAX(self.selectionStartIndex, self.selectionEndIndex);
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    CGFloat barWidth = (self.bounds.size.width - 20) / visibleBars;
    
    CGFloat startX = 10 + (startIdx - self.visibleStartIndex) * barWidth;
    CGFloat endX = 10 + (endIdx - self.visibleStartIndex) * barWidth;
    
    // Draw selection background
    NSRect selectionRect = NSMakeRect(startX, 0, endX - startX, self.bounds.size.height);
    [[[NSColor selectedControlColor] colorWithAlphaComponent:0.3] setFill];
    NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRect:selectionRect];
    [selectionPath fill];
    
    // Draw selection borders
    [[NSColor selectedControlColor] setStroke];
    NSBezierPath *startLine = [NSBezierPath bezierPath];
    [startLine moveToPoint:NSMakePoint(startX, 0)];
    [startLine lineToPoint:NSMakePoint(startX, self.bounds.size.height)];
    startLine.lineWidth = 2.0;
    [startLine stroke];
    
    NSBezierPath *endLine = [NSBezierPath bezierPath];
    [endLine moveToPoint:NSMakePoint(endX, 0)];
    [endLine lineToPoint:NSMakePoint(endX, self.bounds.size.height)];
    endLine.lineWidth = 2.0;
    [endLine stroke];
    
    // Draw info box (only for security panel)
    if ([self.panelType isEqualToString:@"security"]) {
        [self drawChartPortionSelectionInfoBox:startIdx endIdx:endIdx];
    }
}

- (void)drawChartPortionSelectionInfoBox:(NSInteger)startIdx endIdx:(NSInteger)endIdx {
    if (!self.chartData || startIdx >= self.chartData.count || endIdx >= self.chartData.count) return;
    
    // Calculate statistics
    HistoricalBarModel *startBar = self.chartData[startIdx];
    HistoricalBarModel *endBar = self.chartData[endIdx];
    
    double startValue = startBar.close;
    double endValue = endBar.close;
    double maxValue = -DBL_MAX;
    double minValue = DBL_MAX;
    NSInteger barCount = endIdx - startIdx + 1;
    
    // Find min/max in selection
    for (NSInteger i = startIdx; i <= endIdx && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        maxValue = MAX(maxValue, bar.high);
        minValue = MIN(minValue, bar.low);
    }
    
    // Calculate percentages
    double varPercentStartEnd = ((endValue - startValue) / startValue) * 100.0;
    double varPercentMaxMin = ((maxValue - minValue) / minValue) * 100.0;
    double varPercentMaxMinPerBar = varPercentMaxMin / barCount;
    double varPercentStartEndPerBar = varPercentStartEnd / barCount;
    
    // Format dates
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterNoStyle;
    
    NSString *startDate = [dateFormatter stringFromDate:startBar.date];
    NSString *endDate = [dateFormatter stringFromDate:endBar.date];
    
    // Create info text
    NSArray *infoLines = @[
        [NSString stringWithFormat:@"Start: %@ (%.2f)", startDate, startValue],
        [NSString stringWithFormat:@"End: %@ (%.2f)", endDate, endValue],
        [NSString stringWithFormat:@"Max: %.2f", maxValue],
        [NSString stringWithFormat:@"Min: %.2f", minValue],
        [NSString stringWithFormat:@"Bars: %ld", (long)barCount],
        @"",
        [NSString stringWithFormat:@"Var%% Start→End: %+.2f%%", varPercentStartEnd],
        [NSString stringWithFormat:@"Var%% Max→Min: %.2f%%", varPercentMaxMin],
        [NSString stringWithFormat:@"Var%% Max-Min/Bar: %.3f%%", varPercentMaxMinPerBar],
        [NSString stringWithFormat:@"Var%% Start-End/Bar: %+.3f%%", varPercentStartEndPerBar]
    ];
    
    // Calculate box size
    NSDictionary *textAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor controlTextColor]
    };
    
    CGFloat maxWidth = 0;
    CGFloat totalHeight = 0;
    CGFloat lineHeight = 14;
    
    for (NSString *line in infoLines) {
        if (line.length > 0) {
            NSSize lineSize = [line sizeWithAttributes:textAttributes];
            maxWidth = MAX(maxWidth, lineSize.width);
        }
        totalHeight += lineHeight;
    }
    
    // Position info box near crosshair, but keep it visible
    CGFloat boxWidth = maxWidth + 16;
    CGFloat boxHeight = totalHeight + 10;
    CGFloat boxX = self.crosshairPoint.x + 10;
    CGFloat boxY = self.crosshairPoint.y - boxHeight/2;
    
    // Keep box within bounds
    if (boxX + boxWidth > self.bounds.size.width - 10) {
        boxX = self.crosshairPoint.x - boxWidth - 10;
    }
    if (boxY < 10) boxY = 10;
    if (boxY + boxHeight > self.bounds.size.height - 10) {
        boxY = self.bounds.size.height - boxHeight - 10;
    }
    
    NSRect boxRect = NSMakeRect(boxX, boxY, boxWidth, boxHeight);
    
    // Draw box background
    [[[NSColor controlBackgroundColor] colorWithAlphaComponent:0.95] setFill];
    NSBezierPath *boxPath = [NSBezierPath bezierPathWithRoundedRect:boxRect xRadius:6 yRadius:6];
    [boxPath fill];
    
    // Draw box border
    [[NSColor separatorColor] setStroke];
    boxPath.lineWidth = 1.0;
    [boxPath stroke];
    
    // Draw text lines
    CGFloat textY = boxY + boxHeight - 15;
    for (NSString *line in infoLines) {
        if (line.length > 0) {
            NSPoint textPoint = NSMakePoint(boxX + 8, textY);
            [line drawAtPoint:textPoint withAttributes:textAttributes];
        }
        textY -= lineHeight;
    }
}

- (void)drawCrosshair {
    // This method is now unused - drawing moved to drawCrosshairContent
    // Kept for compatibility but all crosshair drawing happens in layers
}

- (void)drawPriceLabel:(NSString *)priceText atPoint:(NSPoint)point {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor controlBackgroundColor],
        NSBackgroundColorAttributeName: [NSColor labelColor]
    };
    
    NSSize textSize = [priceText sizeWithAttributes:attributes];
    NSRect backgroundRect = NSMakeRect(point.x - 5, point.y - textSize.height/2 - 2,
                                      textSize.width + 10, textSize.height + 4);
    
    // Draw background
    [[NSColor labelColor] setFill];
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:backgroundRect xRadius:3 yRadius:3];
    [bgPath fill];
    
    // Draw text
    NSPoint textPoint = NSMakePoint(point.x, point.y - textSize.height/2);
    [priceText drawAtPoint:textPoint withAttributes:attributes];
}

#pragma mark - Coordinate Conversion

- (CGFloat)yCoordinateForPrice:(double)price {
    if (self.objectRenderer && self.objectRenderer.coordinateContext) {
           return [self.objectRenderer.coordinateContext screenYForValue:price];
       }
    
    if (self.yRangeMax == self.yRangeMin) return self.bounds.size.height / 2;
    
    double normalizedPrice = (price - self.yRangeMin) / (self.yRangeMax - self.yRangeMin);
    return 10 + normalizedPrice * (self.bounds.size.height - 20); // 10px margins
}

- (double)priceForYCoordinate:(CGFloat)y {
    if (self.objectRenderer && self.objectRenderer.coordinateContext) {
        return [self.objectRenderer.coordinateContext priceFromScreenY:y];
       }
    
    
    if (self.bounds.size.height <= 20) return self.yRangeMin;
    
    double normalizedY = (y - 10) / (self.bounds.size.height - 20);
    return self.yRangeMin + normalizedY * (self.yRangeMax - self.yRangeMin);
}

- (NSInteger)barIndexForXCoordinate:(CGFloat)x {
    if (self.visibleStartIndex >= self.visibleEndIndex) return -1;
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    CGFloat barWidth = (self.bounds.size.width - 20) / visibleBars;
    
    NSInteger relativeIndex = (x - 10) / barWidth;
    NSInteger absoluteIndex = self.visibleStartIndex + relativeIndex;
    
    return MAX(self.visibleStartIndex, MIN(absoluteIndex, self.visibleEndIndex - 1));
}

#pragma mark - Mouse Events

- (void)mouseEntered:(NSEvent *)event {
    self.crosshairVisible = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    self.crosshairVisible = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    self.crosshairPoint = locationInView;
    [self.crosshairLayer setNeedsDisplay];
    
    // PRIORITA' 1: Se abbiamo currentCPSelected, aggiorna sempre le coordinate
    if (self.objectRenderer && self.objectRenderer.currentCPSelected) {
        [self.objectRenderer updateCurrentCPCoordinates:locationInView];
        
     
        return;
    }
    
    // Update crosshair during object editing
    if (self.objectRenderer && self.objectRenderer.editingObject) {
        [self.objectRenderer updateEditingHoverAtPoint:locationInView];
        
        // Sync crosshair anche durante editing
        for (ChartPanelView *panel in self.chartWidget.chartPanels) {
            if (panel != self) {
                [panel setCrosshairPoint:NSMakePoint(locationInView.x, panel.crosshairPoint.y) visible:YES];
            }
        }
        return;
    }
    
    // Normal crosshair sync
    for (ChartPanelView *panel in self.chartWidget.chartPanels) {
        if (panel != self) {
            [panel setCrosshairPoint:NSMakePoint(locationInView.x, panel.crosshairPoint.y) visible:YES];
        }
    }
}


- (void)mouseDown:(NSEvent *)event {
    if (self.objectRenderer.currentCPSelected) {
        return;
    }
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    self.dragStartPoint = locationInView;
    self.isDragging = NO;
  
    
    //alert
    
    if (self.alertRenderer) {
           AlertModel *hitAlert = [self.alertRenderer alertAtScreenPoint:locationInView tolerance:12.0];
           if (hitAlert) {
               [self.alertRenderer startDraggingAlert:hitAlert atPoint:locationInView];
               self.isInAlertDragMode = YES;
               NSLog(@"🚨 Started dragging alert %@ %.2f", hitAlert.symbol, hitAlert.triggerValue);
               return; // Don't handle other interactions during alert drag
           }
       }
    
    //
    
    // NEW LOGIC: Check if ObjectsPanel has active object type
    ChartObjectType activeType = -1;
    if (self.chartWidget && self.chartWidget.objectsPanel) {
        activeType = [self.chartWidget.objectsPanel getActiveObjectType];
        NSLog(@"🔍 Active object type: %ld", (long)activeType);
    }
    
    if (activeType != -1) {
        // CREATION MODE: Start creating object
        NSLog(@"🎯 Starting object creation for type %ld", (long)activeType);
        
        if (!self.objectRenderer) {
            [self setupObjectsRendererWithManager:self.chartWidget.objectsManager];
        }
        
        [self.objectRenderer startCreatingObjectOfType:activeType];
        [self.objectRenderer addControlPointAtScreenPoint:locationInView];
        
        return; // Don't handle other interactions during creation
    }
    
  
    
    // Original chart interaction behavior (zoom, pan, selection)
    self.isMouseDown = YES;
    self.lastMousePoint = locationInView;
}


- (void)mouseDragged:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    // Calculate drag distance
    CGFloat dragDistance = sqrt(pow(locationInView.x - self.dragStartPoint.x, 2) +
                               pow(locationInView.y - self.dragStartPoint.y, 2));
    
    if (dragDistance > self.dragThreshold) {
        self.isDragging = YES;
    }
    
    
    // PRIORITA' 1: Se abbiamo currentCPSelected, aggiorna coordinate
    if (self.objectRenderer && self.objectRenderer.currentCPSelected) {
        [self.objectRenderer updateCurrentCPCoordinates:locationInView];
        
        // Se in preview mode E stiamo draggando, aggiorna anche preview
        if (self.isDragging) {
            [self.objectRenderer updateCreationPreviewAtPoint:locationInView];
        }
        
        NSLog(@"🎯 MouseDragged: Updated currentCPSelected coordinates");
        return;
    }
    
    if (self.isInAlertDragMode && self.alertRenderer.isInAlertDragMode) {
           [self.alertRenderer updateDragToPoint:locationInView];
           return;
       }

    // Original drag behavior for chart (pan, selection, etc.)
    if (self.isMouseDown) {
        // Handle chart pan/selection as before
        
        if (self.isDragging) {
            // Chart selection mode
            self.isInChartPortionSelectionMode = YES;
            self.selectionStartIndex = [self barIndexForXCoordinate:self.dragStartPoint.x];
            self.selectionEndIndex = [self barIndexForXCoordinate:locationInView.x];
            
            [self.chartPortionSelectionLayer setNeedsDisplay];
        }
    }
    self.crosshairPoint = locationInView;
    [self.crosshairLayer setNeedsDisplay];
}

- (void)rightMouseDragged:(NSEvent *)event {
    if (!self.isRightMouseDown) return;
    
    NSPoint currentPoint = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat deltaX = currentPoint.x - self.lastMousePoint.x;
    CGFloat deltaY = currentPoint.y - self.lastMousePoint.y;
    
    // Right drag = pan mode
    [self handlePanWithDeltaX:deltaX deltaY:deltaY];
    
    self.lastMousePoint = currentPoint;
}



- (void)mouseUp:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    // PRIORITA' 1: Se abbiamo currentCPSelected, consolidalo
    if (self.objectRenderer && self.objectRenderer.currentCPSelected) {
        NSLog(@"🎯 MouseUp: Consolidating currentCPSelected");
        
        if (self.objectRenderer.isInCreationMode) {
            // Modalità creazione - consolida CP e prepara il prossimo
            [self.objectRenderer consolidateCurrentCPAndPrepareNext];
        } else {
            // Modalità editing - termina editing
            self.objectRenderer.currentCPSelected = nil;
            NSLog(@"🎯 MouseUp: Cleared currentCPSelected after editing");
        }
        
        self.isDragging = NO;
        return;
    }
    
    if (self.isInAlertDragMode && self.alertRenderer.isInAlertDragMode) {
         [self.alertRenderer finishDragWithConfirmation];
         self.isInAlertDragMode = NO;
         self.isDragging = NO;
         NSLog(@"🚨 Completed alert drag");
         return;
     }
    
    // If it was a click (not drag), handle object selection
    if (!self.isDragging && self.objectRenderer) {
        // Hit test for existing objects
        ChartObjectModel *objectAtPoint = [self.objectRenderer objectAtScreenPoint:locationInView
                                                                           tolerance:15.0];
        if (objectAtPoint) {
            // Object found - start editing
            [self.objectRenderer startEditingObject:objectAtPoint];
            
            // Select nearest control point
            ControlPointModel *nearestCP = [objectAtPoint controlPointNearPoint:locationInView tolerance:15.0];
            if (nearestCP) {
                [self.objectRenderer selectControlPointForEditing:nearestCP];
                NSLog(@"🎯 Selected object and nearest CP for editing");
            }
            
            self.isDragging = NO;
            return;
        }
        
        // No object found - clear any editing
        if (self.objectRenderer.editingObject) {
            [self.objectRenderer stopEditing];
            NSLog(@"✋ Stopped editing - clicked on empty space");
        }
    }
    
    // Original mouseUp behavior for chart
    if (self.isInChartPortionSelectionMode && self.isDragging) {
        // Zoom to selection
        NSInteger startIdx = MIN(self.selectionStartIndex, self.selectionEndIndex);
        NSInteger endIdx = MAX(self.selectionStartIndex, self.selectionEndIndex);
        
        if (endIdx > startIdx) {
            [self.chartWidget zoomToRange:startIdx endIndex:endIdx];
        }
    }
    
    // Reset states
    self.isMouseDown = NO;
    self.isDragging = NO;
    self.isInChartPortionSelectionMode = NO;
    [self.chartPortionSelectionLayer setNeedsDisplay];
}


- (void)rightMouseUp:(NSEvent *)event {
    self.isRightMouseDown = NO;
}


- (void)scrollWheel:(NSEvent *)event {
    if (!self.chartData || self.chartData.count == 0) return;
    
    // ✅ NUOVO: Usa l'endIndex corrente come punto fisso invece del mouse
    NSInteger fixedEndIndex = self.chartWidget.visibleEndIndex;
    NSInteger currentRange = self.chartWidget.visibleEndIndex - self.chartWidget.visibleStartIndex;
    NSInteger newRange;
    
    if (event.deltaY > 0) {
        // Zoom in - dimezza il range
        newRange = MAX(10, currentRange / 2);
    } else {
        // Zoom out - raddoppia il range
        newRange = MIN(self.chartData.count, currentRange * 2);
    }
    
    // Calcola nuovo startIndex mantenendo endIndex fisso
    NSInteger newStartIndex = fixedEndIndex - newRange;
    
    // Clamp ai limiti validi (solo per startIndex)
    if (newStartIndex < 0) {
        newStartIndex = 0;
    }
    
    // Applica zoom
    [self.chartWidget zoomToRange:newStartIndex endIndex:fixedEndIndex];
    
    NSLog(@"🔍🖱 Scroll zoom: fixed end at %ld, new range [%ld-%ld] (pan slider stays same)",
          (long)fixedEndIndex, (long)newStartIndex, (long)fixedEndIndex);
}

- (void)rightMouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    // 🎯 PRIORITÀ 1: CONTEXT MENU PER OGGETTI (NUOVA FUNZIONALITÀ)
    if (self.objectRenderer && self.objectRenderer.objectsManager) {
        // Hit test per trovare oggetto sotto il cursore
        ChartObjectModel *hitObject = [self.objectRenderer objectAtScreenPoint:locationInView tolerance:15.0];
        
        // Se non trova oggetto normale, controlla se c'è un oggetto in editing
        if (!hitObject && self.objectRenderer.editingObject) {
            // Verifica se il right-click è sull'oggetto in editing
            if ([self isPoint:locationInView nearEditingObject:self.objectRenderer.editingObject tolerance:15.0]) {
                hitObject = self.objectRenderer.editingObject;
            }
        }
        
        // Se non trova ancora oggetto, controlla control point
        if (!hitObject) {
            ControlPointModel *hitCP = [self.objectRenderer.objectsManager controlPointAtPoint:locationInView tolerance:8.0];
            if (hitCP) {
                hitObject = [self findObjectOwningControlPoint:hitCP];
            }
        }
        if (self.objectRenderer.editingObject) {
              NSLog(@"⚠️ Clearing editing state before context menu");
              self.objectRenderer.editingObject = nil;
              self.objectRenderer.currentCPSelected = nil;
              [self.objectRenderer invalidateEditingLayer];
          }
        if (hitObject) {
            NSLog(@"🖱️ ChartPanelView: Right-click on object '%@' - showing context menu", hitObject.name);
            [self showContextMenuForObject:hitObject atPoint:locationInView withEvent:event];
            return; // Stop all other processing for object context menu
        }
    }
    
    // RESTO DEL CODICE ORIGINALE (PRIORITÀ 2, 3, 4...)
    
    // PRIORITY 2: Cancel object creation if active
    if (self.objectRenderer && self.objectRenderer.isInCreationMode) {
        [self.objectRenderer cancelCreatingObject];
        self.isInObjectCreationMode = NO;
        NSLog(@"❌ ChartPanelView: Cancelled object creation via right-click");
        return;
    }
   
    // PRIORITY 3: Delete editing object if active
    if (self.objectRenderer && self.objectRenderer.editingObject) {
        ChartObjectModel *objectToDelete = self.objectRenderer.editingObject;
        [self.objectRenderer stopEditing];
        [self.objectRenderer.objectsManager deleteObject:objectToDelete];
        [self.objectRenderer renderAllObjects];
        self.isInObjectEditingMode = NO;
        NSLog(@"🗑️ ChartPanelView: Deleted object via right-click");
        return;
    }
    
    // 🆕 PRIORITÀ 2: CONTEXT MENU PER ALERT (NUOVO)
     if (self.alertRenderer) {
         AlertModel *hitAlert = [self.alertRenderer alertAtScreenPoint:locationInView tolerance:15.0];
         if (hitAlert) {
             NSLog(@"🚨 ChartPanelView: Right-click on alert %@ %.2f - showing context menu",
                   hitAlert.symbol, hitAlert.triggerValue);
             [self showContextMenuForAlert:hitAlert atPoint:locationInView withEvent:event];
             return; // Stop processing for alert context menu
         }
     }
     
     // 🆕 PRIORITÀ 3: MENU GENERICO PER CREARE NUOVO ALERT (NUOVO)
     [self showGeneralContextMenuAtPoint:locationInView withEvent:event];
    
    
    // PRIORITY 5: Original right-click behavior (pan mode)
    self.isRightMouseDown = YES;
    self.dragStartPoint = locationInView;
    self.lastMousePoint = self.dragStartPoint;
}


- (void)showContextMenuForObject:(ChartObjectModel *)object atPoint:(NSPoint)point {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Object Actions"];
    
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit Object"
                                                      action:@selector(editSelectedObject:)
                                               keyEquivalent:@""];
    editItem.target = self;
    editItem.representedObject = object;
    [contextMenu addItem:editItem];
    
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Object"
                                                        action:@selector(deleteSelectedObject:)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    deleteItem.representedObject = object;
    [contextMenu addItem:deleteItem];
    
    [NSMenu popUpContextMenu:contextMenu withEvent:[NSApp currentEvent] forView:self];
}

- (void)editSelectedObject:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    if (object && self.objectRenderer) {
        [self.objectRenderer startEditingObject:object];
        self.isInObjectEditingMode = YES;
    }
}

- (void)deleteSelectedObject:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    if (object && self.objectRenderer) {
        [self.objectRenderer.objectsManager deleteObject:object];
        [self.objectRenderer renderAllObjects];
    }
}



#pragma mark - Key Events (NEW)
/*
// ADD keyboard shortcuts for object creation:
- (void)keyDown:(NSEvent *)event {
    NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
    
    if ([characters isEqualToString:@"h"]) {
        // H key - Horizontal Line
        [self startCreatingObjectOfType:ChartObjectTypeHorizontalLine];
    } else if ([characters isEqualToString:@"t"]) {
        // T key - Trendline
        [self startCreatingObjectOfType:ChartObjectTypeTrendline];
    } else if ([characters isEqualToString:@"f"]) {
        // F key - Fibonacci
        [self startCreatingObjectOfType:ChartObjectTypeFibonacci];
    } else if ([characters isEqualToString:@"r"]) {
        // R key - Rectangle
        [self startCreatingObjectOfType:ChartObjectTypeRectangle];
    } else if (event.keyCode == 53) { // ESC key
        // Cancel current operation
        if (self.isInObjectCreationMode && self.objectRenderer) {
            [self.objectRenderer cancelCreatingObject];
            self.isInObjectCreationMode = NO;
        } else if (self.isInObjectEditingMode) {
            [self stopEditingObject];
        }
    } else {
        [super keyDown:event];
    }
}
*/
// ENSURE view can receive key events:
- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)canBecomeKeyView {
    return YES;
}



#pragma mark - Pan Handling


- (void)handlePanWithDeltaX:(CGFloat)deltaX deltaY:(CGFloat)deltaY {
    // Horizontal pan
    if (fabs(deltaX) > 1) {
        NSInteger visibleBars = self.chartWidget.visibleEndIndex - self.chartWidget.visibleStartIndex;
        CGFloat barWidth = (self.bounds.size.width - 20) / visibleBars;
        NSInteger barDelta = -deltaX / barWidth; // Negative for natural scrolling
        
        NSInteger newStartIndex = self.chartWidget.visibleStartIndex + barDelta;
        NSInteger newEndIndex = self.chartWidget.visibleEndIndex + barDelta;
        
        // Clamp to valid range
        if (newStartIndex < 0) {
            newStartIndex = 0;
            newEndIndex = visibleBars;
        } else if (newEndIndex >= self.chartData.count) {
            newEndIndex = self.chartData.count - 1;
            newStartIndex = newEndIndex - visibleBars;
        }
        
        [self.chartWidget zoomToRange:newStartIndex endIndex:newEndIndex];
    }
    
    // Vertical pan (only for security panel, adjusts Y range temporarily)
    if (fabs(deltaY) > 1 && [self.panelType isEqualToString:@"security"]) {
        double yRange = self.yRangeMax - self.yRangeMin;
        double yDelta = (deltaY / self.bounds.size.height) * yRange;
        
        // Override Y range temporarily
        self.chartWidget.yRangeMin -= yDelta;
        self.chartWidget.yRangeMax -= yDelta;
        self.chartWidget.isYRangeOverridden = YES;
        
        [self.chartWidget synchronizePanels];
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
}


#pragma mark - Objects Renderer Setup

- (void)setupObjectsRendererWithManager:(ChartObjectsManager *)objectsManager {
    if (!objectsManager) {
        NSLog(@"⚠️ ChartPanelView: Cannot setup objects renderer without manager");
        return;
    }
    
    self.objectRenderer = [[ChartObjectRenderer alloc] initWithPanelView:self
                                                          objectsManager:objectsManager];
    
    // CRITICO: Initialize coordinate context with current data if available
    if (self.chartData) {
        [self.objectRenderer updateCoordinateContext:self.chartData
                                          startIndex:self.visibleStartIndex
                                            endIndex:self.visibleEndIndex
                                           yRangeMin:self.yRangeMin
                                           yRangeMax:self.yRangeMax
                                              bounds:self.bounds];
        NSLog(@"🎨 ChartObjectRenderer initialized with existing data (%lu bars)", (unsigned long)self.chartData.count);
    }
}

#pragma mark - Objects Interaction (NEW)


- (void)startCreatingObjectOfType:(ChartObjectType)objectType {
    self.isInObjectCreationMode = YES;
    self.currentCreationObjectType = objectType;
    
    if (self.objectRenderer) {
        [self.objectRenderer startCreatingObjectOfType:objectType];
    }
    
    // Make sure this panel becomes key view to receive mouse events
    [[self window] makeFirstResponder:self];
    
    NSLog(@"🎯 ChartPanelView (%@): Started creating object type %ld - ZOOM/PAN DISABLED",
          self.panelType, (long)objectType);
}

- (void)startEditingObjectAtPoint:(NSPoint)point {
    if (!self.objectRenderer) return;
    
    ChartObjectModel *objectAtPoint = [self.objectRenderer objectAtScreenPoint:point tolerance:10.0];
    if (objectAtPoint) {
        self.isInObjectEditingMode = YES;
        [self.objectRenderer startEditingObject:objectAtPoint];
        
        NSLog(@"✏️ ChartPanelView (%@): Started editing object %@",
              self.panelType, objectAtPoint.name);
    }
}

- (void)stopEditingObject {
    if (!self.isInObjectEditingMode) return;
    
    self.isInObjectEditingMode = NO;
    
    if (self.objectRenderer) {
        [self.objectRenderer stopEditing];
    }
    
    NSLog(@"✅ ChartPanelView (%@): Stopped editing object", self.panelType);
}

#pragma mark - Public Interface Updates

// ADD method to check if panel has objects capability:
- (BOOL)supportsObjects {
    return self.objectRenderer != nil;
}

// ADD method to get objects at point (for external queries):
- (NSArray<ChartObjectModel *> *)objectsAtPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    if (!self.objectRenderer) return @[];
    
    NSMutableArray *objectsAtPoint = [NSMutableArray array];
    
    for (ChartLayerModel *layer in self.objectRenderer.objectsManager.layers) {
        if (!layer.isVisible) continue;
        
        for (ChartObjectModel *object in layer.objects) {
            if (!object.isVisible) continue;
            
            // This is a simplified check - the renderer has more sophisticated hit testing
            if ([self.objectRenderer isPoint:point withinObject:object tolerance:tolerance]) {
                [objectsAtPoint addObject:object];
            }
        }
    }
    
    return [objectsAtPoint copy];
}

#pragma mark - Right-Click Context Menu Integration



// Context menu display
- (void)showContextMenuForObject:(ChartObjectModel *)object atPoint:(NSPoint)point withEvent:(NSEvent *)event {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Object Actions"];
    
    // Edit Object menu item
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Edit '%@'...", object.name]
                                                      action:@selector(editObjectFromContextMenu:)
                                               keyEquivalent:@""];
    editItem.target = self;
    editItem.representedObject = object;
    [contextMenu addItem:editItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Duplicate Object menu item
    NSMenuItem *duplicateItem = [[NSMenuItem alloc] initWithTitle:@"Duplicate Object"
                                                           action:@selector(duplicateObjectFromContextMenu:)
                                                    keyEquivalent:@""];
    duplicateItem.target = self;
    duplicateItem.representedObject = object;
    [contextMenu addItem:duplicateItem];
    
    // Delete Object menu item
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Object"
                                                        action:@selector(deleteObjectFromContextMenu:)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    deleteItem.representedObject = object;
    [contextMenu addItem:deleteItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Layer options
    NSMenuItem *layerItem = [[NSMenuItem alloc] initWithTitle:@"Move to Layer"
                                                       action:nil
                                                keyEquivalent:@""];
    NSMenu *layerSubmenu = [[NSMenu alloc] initWithTitle:@"Layer"];
    
    // Add layer options dynamically
    for (ChartLayerModel *layer in self.objectRenderer.objectsManager.layers) {
        NSMenuItem *layerOption = [[NSMenuItem alloc] initWithTitle:layer.name
                                                             action:@selector(moveObjectToLayerFromContextMenu:)
                                                      keyEquivalent:@""];
        layerOption.target = self;
        layerOption.representedObject = @{@"object": object, @"layer": layer};
        [layerSubmenu addItem:layerOption];
    }
    
    layerItem.submenu = layerSubmenu;
    [contextMenu addItem:layerItem];
    
    // Show the context menu
    [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self];
    
    NSLog(@"🎯 ChartPanelView: Context menu displayed for object '%@'", object.name);
}

// Context menu actions
- (void)editObjectFromContextMenu:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    NSLog(@"⚙️ ChartPanelView: Opening settings for object '%@' from context menu", object.name);
    [self openObjectSettingsForObject:object];
}

- (void)duplicateObjectFromContextMenu:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    NSLog(@"📋 ChartPanelView: Duplicating object '%@'", object.name);
    
    // Find current layer
    ChartLayerModel *currentLayer = nil;
    for (ChartLayerModel *layer in self.objectRenderer.objectsManager.layers) {
        if ([layer.objects containsObject:object]) {
            currentLayer = layer;
            break;
        }
    }
    
    if (currentLayer) {
        // Create duplicate
        ChartObjectModel *duplicate = [object copy];
        duplicate.name = [NSString stringWithFormat:@"%@ Copy", object.name];
        
        // Offset position slightly
        for (ControlPointModel *cp in duplicate.controlPoints) {
            cp.dateAnchor = [cp.dateAnchor dateByAddingTimeInterval:86400]; // +1 day
            cp.valuePercent += 0.02; // +2%
        }
        
        [currentLayer addObject:duplicate];
        [self.objectRenderer.objectsManager saveToDataHub];
        [self.objectRenderer renderAllObjects];
        
        NSLog(@"✅ ChartPanelView: Object duplicated successfully");
    }
}

- (void)deleteObjectFromContextMenu:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    NSLog(@"🗑️ ChartPanelView: Deleting object '%@' from context menu", object.name);
    
    [self.objectRenderer.objectsManager deleteObject:object];
    [self.objectRenderer renderAllObjects];
}

- (void)moveObjectToLayerFromContextMenu:(NSMenuItem *)menuItem {
    NSDictionary *info = menuItem.representedObject;
    ChartObjectModel *object = info[@"object"];
    ChartLayerModel *targetLayer = info[@"layer"];
    
    NSLog(@"📁 ChartPanelView: Moving object '%@' to layer '%@'", object.name, targetLayer.name);
    
    [self.objectRenderer.objectsManager moveObject:object toLayer:targetLayer];
    [self.objectRenderer renderAllObjects];
}

// Object settings window

- (void)openObjectSettingsForObject:(ChartObjectModel *)object {
   
    
    
    // Validate object before proceeding
    if (!object || !object.style) {
        NSLog(@"❌ ChartPanelView: Invalid object or object.style is nil");
        return;
    }
    
    if (!self.objectRenderer || !self.objectRenderer.objectsManager) {
        NSLog(@"❌ ChartPanelView: ObjectRenderer or ObjectsManager is nil");
        return;
    }
    self.objectSettingsWindow = nil;
    self.objectSettingsWindow = [[ChartObjectSettingsWindow alloc]
           initWithObject:object objectsManager:self.objectRenderer.objectsManager];
    
    
    self.objectSettingsWindow.onApplyCallback = ^(ChartObjectModel *object) {
        self.objectSettingsWindow = nil; // Rilascia reference
    };
    
    
    if (!self.objectSettingsWindow) {
        NSLog(@"❌ ChartPanelView: Failed to create settings window");
        return;
    }
    
    // ✅ SAFE CALLBACK: Use weak references to avoid retain cycles
    __weak typeof(self) weakSelf = self;
    __weak typeof(self.objectSettingsWindow) weakWindow = self.objectSettingsWindow;
    
    self.objectSettingsWindow.onApplyCallback = ^(ChartObjectModel *updatedObject) {
        // Use strong references inside block
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong typeof(weakWindow) strongWindow = weakWindow;
        
        if (!strongSelf) {
            NSLog(@"⚠️ ChartPanelView callback: ChartPanelView was deallocated");
            return;
        }
        
        // Validate objects still exist
        if (!updatedObject) {
            NSLog(@"⚠️ ChartPanelView callback: updatedObject is nil");
            return;
        }
        
        if (!strongSelf.objectRenderer) {
            NSLog(@"⚠️ ChartPanelView callback: ObjectRenderer was deallocated");
            return;
        }
        
        // Safe redraw
        @try {
            [strongSelf handleObjectSettingsApplied:updatedObject];
        } @catch (NSException *exception) {
            NSLog(@"❌ ChartPanelView callback: Exception in handleObjectSettingsApplied: %@", exception.reason);
        }
        
        // Clear callback to break retain cycle
        if (strongWindow) {
            strongWindow.onApplyCallback = nil;
        }
    };
    
    // Position and show
    [self.objectSettingsWindow makeKeyAndOrderFront:nil];
    
    NSLog(@"✅ ChartPanelView: Settings window opened successfully");
}


// AGGIUNGERE questo metodo di callback:
- (void)handleObjectSettingsApplied:(ChartObjectModel *)object {
    NSLog(@"🔄 ChartPanelView: Settings applied for object '%@' - triggering redraw", object.name ?: @"unknown");
    
    @try {
        // Validate object renderer exists
        if (!self.objectRenderer) {
            NSLog(@"❌ ChartPanelView: ObjectRenderer is nil, cannot redraw");
            return;
        }
        
        // Re-render all objects with new settings
        [self.objectRenderer renderAllObjects];
        NSLog(@"✅ ChartPanelView: Objects re-rendered successfully");
        
        // Notify chart widget if needed (optional)
        if (self.chartWidget && [self.chartWidget respondsToSelector:@selector(objectSettingsDidChange:)]) {
            [(id)self.chartWidget performSelector:@selector(objectSettingsDidChange:) withObject:object];
        }
        
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartPanelView: Exception in handleObjectSettingsApplied: %@", exception.reason);
    }
}

// Helper methods
- (BOOL)isPoint:(NSPoint)point nearEditingObject:(ChartObjectModel *)object tolerance:(CGFloat)tolerance {
    // Simple bounding box check for editing object
    // TODO: Implement proper hit testing for editing objects
    return YES; // For now, assume always true if we have an editing object
}

- (ChartObjectModel *)findObjectOwningControlPoint:(ControlPointModel *)controlPoint {
    // Search through all layers and objects to find the one containing this control point
    for (ChartLayerModel *layer in self.objectRenderer.objectsManager.layers) {
        for (ChartObjectModel *object in layer.objects) {
            if ([object.controlPoints containsObject:controlPoint]) {
                return object;
            }
        }
    }
    return nil;
}

#pragma mark - Alert Renderer Setup

- (void)setupAlertRenderer {
    self.alertRenderer = [[ChartAlertRenderer alloc] initWithPanelView:self];
    
    // CRITICO: Initialize coordinate context with current data if available
    if (self.chartData && self.chartWidget.currentSymbol) {
        [self.alertRenderer updateCoordinateContext:self.chartData
                                         startIndex:self.visibleStartIndex
                                           endIndex:self.visibleEndIndex
                                          yRangeMin:self.yRangeMin
                                          yRangeMax:self.yRangeMax
                                             bounds:self.bounds
                                      currentSymbol:self.chartWidget.currentSymbol];
        NSLog(@"🚨 ChartAlertRenderer initialized with existing data (%lu bars) for %@",
              (unsigned long)self.chartData.count, self.chartWidget.currentSymbol);
    }
    
    NSLog(@"🚨 ChartPanelView (%@): Alert renderer setup completed", self.panelType);
}


#pragma mark - Alert Context Menu

- (void)showContextMenuForAlert:(AlertModel *)alert atPoint:(NSPoint)point withEvent:(NSEvent *)event {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Alert Actions"];
    
    // Edit Alert
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit Alert..."
                                                      action:@selector(editAlertFromContextMenu:)
                                               keyEquivalent:@""];
    editItem.target = self;
    editItem.representedObject = alert;
    [contextMenu addItem:editItem];
    
    // Delete Alert
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Alert"
                                                        action:@selector(deleteAlertFromContextMenu:)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    deleteItem.representedObject = alert;
    [contextMenu addItem:deleteItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Toggle Active/Inactive
    NSString *toggleTitle = alert.isActive ? @"Disable Alert" : @"Enable Alert";
    NSMenuItem *toggleItem = [[NSMenuItem alloc] initWithTitle:toggleTitle
                                                        action:@selector(toggleAlertFromContextMenu:)
                                                 keyEquivalent:@""];
    toggleItem.target = self;
    toggleItem.representedObject = alert;
    [contextMenu addItem:toggleItem];
    
    [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self];
}

- (void)showGeneralContextMenuAtPoint:(NSPoint)point withEvent:(NSEvent *)event {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Chart Context Menu"];
    
    // Only show alert creation if we have alert renderer and current symbol
    if (self.alertRenderer && self.chartWidget.currentSymbol) {
        // Convert point to price
        double priceAtPoint = [self.alertRenderer triggerValueForScreenY:point.y];
        NSString *formattedPrice = [NSString stringWithFormat:@"%.2f", priceAtPoint];
        
        // Menu item for creating alert
        NSMenuItem *createAlertItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Create Alert at %@", formattedPrice]
                                                                 action:@selector(createAlertAtMouseLocation:)
                                                          keyEquivalent:@""];
        createAlertItem.target = self;
        createAlertItem.representedObject = @{@"price": @(priceAtPoint), @"point": [NSValue valueWithPoint:point]};
        [contextMenu addItem:createAlertItem];
        
        [contextMenu addItem:[NSMenuItem separatorItem]];
    }
    
    // Other menu items could go here (chart settings, etc.)
    
    if (contextMenu.itemArray.count > 0) {
        [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self];
    }
}

#pragma mark - Alert Context Menu Actions

- (void)createAlertAtMouseLocation:(NSMenuItem *)menuItem {
    NSDictionary *info = menuItem.representedObject;
    double price = [info[@"price"] doubleValue];
    
    NSLog(@"🚨 Creating alert at price: %.2f for symbol: %@", price, self.chartWidget.currentSymbol);
    
    // Create pre-populated AlertModel
    AlertModel *newAlert = [self.alertRenderer createAlertTemplateAtScreenPoint:[info[@"point"] pointValue]];
    if (!newAlert) {
        NSLog(@"⚠️ Could not create alert template");
        return;
    }
    
    // Show AlertEditController (riuso totale!)
    AlertEditController *editor = [[AlertEditController alloc] initWithAlert:newAlert];
    editor.completionHandler = ^(AlertModel *editedAlert, BOOL saved) {
        if (saved && editedAlert) {
            // AlertEditController già salva via DataHub
            // Solo refresh della UI del chart
            [self.alertRenderer refreshAlerts];
            NSLog(@"✅ Alert created from chart: %@ at %.2f", editedAlert.symbol, editedAlert.triggerValue);
        }
    };
    
    // Show as sheet
    [self.window beginSheet:editor.window completionHandler:nil];
}

- (void)editAlertFromContextMenu:(NSMenuItem *)menuItem {
    AlertModel *alert = menuItem.representedObject;
    NSLog(@"✏️ ChartPanelView: Editing alert %@ %.2f", alert.symbol, alert.triggerValue);
    
    AlertEditController *editor = [[AlertEditController alloc] initWithAlert:alert];
    editor.completionHandler = ^(AlertModel *editedAlert, BOOL saved) {
        if (saved) {
            [self.alertRenderer refreshAlerts];
        }
    };
    
    [self.window beginSheet:editor.window completionHandler:nil];
}

- (void)deleteAlertFromContextMenu:(NSMenuItem *)menuItem {
    AlertModel *alert = menuItem.representedObject;
    
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"Delete Alert";
    confirmAlert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the alert for %@ at %.2f?",
                                   alert.symbol, alert.triggerValue];
    [confirmAlert addButtonWithTitle:@"Delete"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    confirmAlert.alertStyle = NSAlertStyleWarning;
    
    NSModalResponse response = [confirmAlert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [[DataHub shared] deleteAlertModel:alert];
        [self.alertRenderer refreshAlerts];
        NSLog(@"🗑️ Deleted alert %@ %.2f", alert.symbol, alert.triggerValue);
    }
}

- (void)toggleAlertFromContextMenu:(NSMenuItem *)menuItem {
    AlertModel *alert = menuItem.representedObject;
    
    alert.isActive = !alert.isActive;
    [[DataHub shared] updateAlertModel:alert];
    [self.alertRenderer refreshAlerts];
    
    NSLog(@"🔄 Toggled alert %@ %.2f to %@", alert.symbol, alert.triggerValue,
          alert.isActive ? @"ACTIVE" : @"INACTIVE");
}

#pragma mark - Alert Interaction Methods

- (void)startEditingAlertAtPoint:(NSPoint)point {
    if (!self.alertRenderer) return;
    
    AlertModel *alertAtPoint = [self.alertRenderer alertAtScreenPoint:point tolerance:10.0];
    if (alertAtPoint) {
        [self.alertRenderer startDraggingAlert:alertAtPoint atPoint:point];
        self.isInAlertDragMode = YES;
        
        NSLog(@"🚨 ChartPanelView (%@): Started editing alert %@ %.2f",
              self.panelType, alertAtPoint.symbol, alertAtPoint.triggerValue);
    }
}

- (void)stopEditingAlert {
    if (!self.isInAlertDragMode) return;
    
    self.isInAlertDragMode = NO;
    
    if (self.alertRenderer.isInAlertDragMode) {
        [self.alertRenderer cancelDrag];
    }
    
    NSLog(@"✅ ChartPanelView (%@): Stopped editing alert", self.panelType);
}
@end
