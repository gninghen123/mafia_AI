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

@interface ChartPanelView ()



// Mouse tracking
@property (nonatomic, strong) NSTrackingArea *trackingArea;

// Interaction state
@property (nonatomic, assign) BOOL isMouseDown;
@property (nonatomic, assign) BOOL isRightMouseDown;
@property (nonatomic, assign) NSPoint dragStartPoint;
@property (nonatomic, assign) NSPoint lastMousePoint;

// Selection state
@property (nonatomic, assign) BOOL isInSelectionMode;
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
    self.selectionLayer = [CALayer layer];
    self.selectionLayer.delegate = self;
    [self.layer addSublayer:self.selectionLayer];
    
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
    self.selectionLayer.frame = bounds;
    self.crosshairLayer.frame = bounds;
    
    // NUOVO: Update objects renderer layer frames
    if (self.objectRenderer) {
        [self.objectRenderer updateLayerFrames];
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
    } else if (layer == self.selectionLayer) {
        [self drawSelectionContent];
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
    
    BOOL dataChanged = ![self.chartData isEqualToArray:data] ||
                      self.visibleStartIndex != startIndex ||
                      self.visibleEndIndex != endIndex ||
                      self.yRangeMin != yMin ||
                      self.yRangeMax != yMax;
    
    self.chartData = data;
    self.visibleStartIndex = startIndex;
    self.visibleEndIndex = endIndex;
    self.yRangeMin = yMin;
    self.yRangeMax = yMax;
    
    if (dataChanged) {
        [self invalidateChartContent];
        
        // NUOVO: Update objects renderer coordinate context
        if (self.objectRenderer) {
            [self.objectRenderer updateCoordinateContext:data
                                               startIndex:startIndex
                                                 endIndex:endIndex
                                                yRangeMin:yMin
                                                yRangeMax:yMax
                                                   bounds:self.bounds];
        }
        
        NSLog(@"📊 ChartPanelView: Chart content and objects invalidated due to data change");
    }
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


- (void)drawSelectionContent {
    if (!self.isInSelectionMode) return;
    
    // ✅ USA IL METODO ESISTENTE invece di riscriverlo
    [self drawSelection];
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
        CGFloat openY = [self yCoordinateForPrice:bar.open];
        CGFloat closeY = [self yCoordinateForPrice:bar.close];
        CGFloat highY = [self yCoordinateForPrice:bar.high];
        CGFloat lowY = [self yCoordinateForPrice:bar.low];
        
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

- (void)drawSelection {
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
        [self drawSelectionInfoBox:startIdx endIdx:endIdx];
    }
}

- (void)drawSelectionInfoBox:(NSInteger)startIdx endIdx:(NSInteger)endIdx {
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
    if (self.yRangeMax == self.yRangeMin) return self.bounds.size.height / 2;
    
    double normalizedPrice = (price - self.yRangeMin) / (self.yRangeMax - self.yRangeMin);
    return 10 + normalizedPrice * (self.bounds.size.height - 20); // 10px margins
}

- (double)priceForYCoordinate:(CGFloat)y {
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
    
    // SEMPRE aggiorna crosshair (anche durante object creation/editing)
    self.crosshairVisible = YES;
    [self updateCrosshairOnly];
    
    // Handle object creation preview
    if (self.objectRenderer && self.objectRenderer.isInCreationMode) {
        [self.objectRenderer updateCreationPreviewAtPoint:locationInView];
        
        // MANTIENI crosshair sync con altri panel anche durante creation
        for (ChartPanelView *panel in self.chartWidget.chartPanels) {
            if (panel != self) {
                [panel setCrosshairPoint:NSMakePoint(locationInView.x, panel.crosshairPoint.y) visible:YES];
            }
        }
        
        return;
    }
    
    // Handle object editing hover
    if (self.objectRenderer && self.objectRenderer.editingObject) {
        [self.objectRenderer updateEditingHoverAtPoint:locationInView];
        
        // MANTIENI crosshair sync anche durante editing
        for (ChartPanelView *panel in self.chartWidget.chartPanels) {
            if (panel != self) {
                [panel setCrosshairPoint:NSMakePoint(locationInView.x, panel.crosshairPoint.y) visible:YES];
            }
        }
        
        return;
    }
    
    // Normal crosshair sync con altri panels
    for (ChartPanelView *panel in self.chartWidget.chartPanels) {
        if (panel != self) {
            [panel setCrosshairPoint:NSMakePoint(locationInView.x, panel.crosshairPoint.y) visible:YES];
        }
    }
}


- (void)mouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    self.isMouseDown = YES;

    // PRIORITY 1: Handle object creation mode (BLOCK other interactions)
    if (self.objectRenderer && self.objectRenderer.isInCreationMode) {
        BOOL objectCompleted = [self.objectRenderer addControlPointAtScreenPoint:locationInView];
        if (objectCompleted) {
            self.isInObjectCreationMode = NO;
            NSLog(@"✅ ChartPanelView: Object creation completed");
        }
        // IMPORTANT: Return here to prevent zoom/pan interactions during creation
        return;
    }
    
    // PRIORITY 2: Handle object editing mode
    if (self.objectRenderer) {
        // Check if clicking on a control point
        ControlPointModel *cpAtPoint = [self.objectRenderer controlPointAtScreenPoint:locationInView
                                                                             tolerance:12.0]; // Increased tolerance
        if (cpAtPoint) {
            // Start dragging control point
            [self.objectRenderer.objectsManager selectControlPoint:cpAtPoint
                                                          ofObject:self.objectRenderer.editingObject];
            NSLog(@"🎯 ChartPanelView: Started dragging control point");
            return;
        }
        
        // Check if clicking on an object to start editing
        ChartObjectModel *objectAtPoint = [self.objectRenderer objectAtScreenPoint:locationInView
                                                                           tolerance:15.0]; // Increased tolerance
        if (objectAtPoint) {
            [self startEditingObjectAtPoint:locationInView];
            return; // Object editing started - don't handle chart interactions
        }
        
        // Click on empty space - clear current editing
        if (self.isInObjectEditingMode) {
            [self stopEditingObject];
            NSLog(@"✋ ChartPanelView: Stopped editing - clicked on empty space");
        }
    }
    
    // PRIORITY 3: Original chart interaction behavior (zoom, pan, selection)
    self.dragStartPoint = locationInView;
    self.lastMousePoint = self.dragStartPoint;
}


- (void)rightMouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    // PRIORITY 1: Cancel object creation if active
    if (self.objectRenderer && self.objectRenderer.isInCreationMode) {
        [self.objectRenderer cancelCreatingObject];
        self.isInObjectCreationMode = NO;
        NSLog(@"❌ ChartPanelView: Cancelled object creation via right-click");
        return;
    }
    
    // PRIORITY 2: Delete editing object if active
    if (self.objectRenderer && self.objectRenderer.editingObject) {
        ChartObjectModel *objectToDelete = self.objectRenderer.editingObject;
        [self.objectRenderer stopEditing];
        [self.objectRenderer.objectsManager deleteObject:objectToDelete];
        [self.objectRenderer renderAllObjects];
        self.isInObjectEditingMode = NO;
        NSLog(@"🗑️ ChartPanelView: Deleted object via right-click");
        return;
    }
    
    // PRIORITY 3: Check if right-clicking on an object to delete
    if (self.objectRenderer) {
        ChartObjectModel *objectAtPoint = [self.objectRenderer objectAtScreenPoint:locationInView
                                                                           tolerance:15.0];
        if (objectAtPoint) {
            [self.objectRenderer.objectsManager deleteObject:objectAtPoint];
            [self.objectRenderer renderAllObjects];
            NSLog(@"🗑️ ChartPanelView: Deleted object %@ via right-click", objectAtPoint.name);
            return;
        }
    }
    
    // PRIORITY 4: Original right-click behavior (pan mode)
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
- (void)mouseDragged:(NSEvent *)event {
    if (!self.isMouseDown) return;
    
    if (self.isInObjectEditingMode) {
        return;
    }
    
    NSPoint currentPoint = [self convertPoint:event.locationInWindow fromView:nil];
    self.isInSelectionMode = YES;

    // Left drag = selection mode
    self.selectionStartIndex = [self barIndexForXCoordinate:self.dragStartPoint.x];
    self.selectionEndIndex = [self barIndexForXCoordinate:currentPoint.x];
   
   [self.selectionLayer setNeedsDisplay];
     
    self.crosshairPoint = currentPoint;
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
    if (self.isInSelectionMode) {
        // Zoom to selection
        NSInteger startIdx = MIN(self.selectionStartIndex, self.selectionEndIndex);
        NSInteger endIdx = MAX(self.selectionStartIndex, self.selectionEndIndex);
        
        NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
        NSInteger minimumAllowedBarsForZoom = visibleBars / 95;
        if (minimumAllowedBarsForZoom <3) {
            minimumAllowedBarsForZoom = 3;
        }
        if (endIdx > startIdx && endIdx - startIdx > minimumAllowedBarsForZoom) {
            [self.chartWidget zoomToRange:startIdx endIndex:endIdx];
        }
        
        self.isInSelectionMode = NO;
        [self.selectionLayer setNeedsDisplay];
    }
    
    self.isMouseDown = NO;
}

- (void)rightMouseUp:(NSEvent *)event {
    self.isRightMouseDown = NO;
}


- (void)scrollWheel:(NSEvent *)event {
    if (!self.chartData || self.chartData.count == 0) return;
    
    NSPoint mouseLocation = [self convertPoint:event.locationInWindow fromView:nil];
    
    // Calcola quale barra è sotto il mouse
    NSInteger mouseBarIndex = [self barIndexForXCoordinate:mouseLocation.x];
    if (mouseBarIndex < 0) return;
    
    // Calcola range attuale
    NSInteger currentRange = self.chartWidget.visibleEndIndex - self.chartWidget.visibleStartIndex;
    NSInteger newRange;
    
    if (event.deltaY > 0) {
        // Zoom in - dimezza il range
        newRange = MAX(10, currentRange / 2);
    } else {
        // Zoom out - raddoppia il range
        newRange = MIN(self.chartData.count, currentRange * 2);
    }
    
    // ✅ ZOOM INTELLIGENTE: Mantieni la barra sotto il mouse come punto fisso
    
    // Calcola la posizione relativa del mouse nel range attuale (0.0 - 1.0)
    double mouseRatio = (double)(mouseBarIndex - self.chartWidget.visibleStartIndex) / currentRange;
    
    // Calcola nuovo start/end mantenendo la stessa proporzione
    NSInteger newStartIndex = mouseBarIndex - (NSInteger)(newRange * mouseRatio);
    NSInteger newEndIndex = newStartIndex + newRange;
    
    // Clamp ai limiti validi
    if (newStartIndex < 0) {
        newStartIndex = 0;
        newEndIndex = newRange;
    } else if (newEndIndex >= self.chartData.count) {
        newEndIndex = self.chartData.count - 1;
        newStartIndex = newEndIndex - newRange;
    }
    
    // Applica zoom
    [self.chartWidget zoomToRange:newStartIndex endIndex:newEndIndex];
    
    NSLog(@"🔍 Smart zoom: mouse at bar %ld (ratio %.2f), new range [%ld-%ld]",
          (long)mouseBarIndex, mouseRatio, (long)newStartIndex, (long)newEndIndex);
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
    
    NSLog(@"🎨 ChartPanelView (%@): Objects renderer setup completed", self.panelType);
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

@end
