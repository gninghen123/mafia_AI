//
//  ChartAlertRenderer.m
//  TradingApp
//
//  Alert rendering engine implementation with ThinkOrSwim-style labels
//

#import "ChartAlertRenderer.h"
#import "ChartPanelView.h"
#import "DataHub.h"



#pragma mark - Chart Alert Renderer Implementation

@interface ChartAlertRenderer () <CALayerDelegate>

// Private readwrite override for isInAlertDragMode
@property (nonatomic, assign, readwrite) BOOL isInAlertDragMode;

@end

@implementation ChartAlertRenderer

#pragma mark - Initialization

- (instancetype)initWithPanelView:(ChartPanelView *)panelView {
    self = [super init];
    if (self) {
        _panelView = panelView;
        _panelYContext = [[PanelYCoordinateContext alloc] init];
        _alerts = @[];
        
        [self setupLayersInPanelView];
        [self registerForNotifications];
        
        NSLog(@"🚨 ChartAlertRenderer: Initialized for panel %@", panelView.panelType);
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Layer Management

- (void)setupLayersInPanelView {
    // Alerts layer (static alerts)
    self.alertsLayer = [CALayer layer];
    self.alertsLayer.delegate = self;
    self.alertsLayer.needsDisplayOnBoundsChange = YES;
    [self.panelView.layer insertSublayer:self.alertsLayer above:self.panelView.crosshairLayer];
    
    // Alerts editing layer (alert being dragged)
    self.alertsEditingLayer = [CALayer layer];
    self.alertsEditingLayer.delegate = self;
    self.alertsEditingLayer.needsDisplayOnBoundsChange = YES;
    [self.panelView.layer insertSublayer:self.alertsEditingLayer above:self.alertsLayer];
    
    [self updateLayerFrames];
    
    NSLog(@"🎯 ChartAlertRenderer: Layers setup completed");
}

- (void)updateLayerFrames {
    CGRect panelBounds = self.panelView.bounds;
    self.alertsLayer.frame = panelBounds;
    self.alertsEditingLayer.frame = panelBounds;
}

#pragma mark - Notifications

- (void)registerForNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(alertsUpdated:)
                                                 name:DataHubAlertTriggeredNotification
                                               object:nil];
}

- (void)alertsUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshAlerts];
    });
}

#pragma mark - Coordinate Context

- (void)updateCoordinateContext:(NSArray<HistoricalBarModel *> *)chartData
                     startIndex:(NSInteger)startIndex
                       endIndex:(NSInteger)endIndex
                      yRangeMin:(double)yMin
                      yRangeMax:(double)yMax
                         bounds:(CGRect)bounds
                  currentSymbol:(NSString *)symbol {
    
    // ✅ NUOVO: Aggiorna panel Y context
    self.panelYContext.yRangeMin = yMin;
    self.panelYContext.yRangeMax = yMax;
    self.panelYContext.panelHeight = bounds.size.height;
    self.panelYContext.currentSymbol = symbol;
    
    // ✅ NUOVO: Shared X context viene passato dal panel view separatamente
    // (Il panelView lo aggiorna tramite updateSharedXContext)
    
    [self updateLayerFrames];
    
    // Refresh alerts if symbol changed
    static NSString *lastSymbol = nil;
    if (![symbol isEqualToString:lastSymbol]) {
        lastSymbol = symbol;
        [self loadAlertsForSymbol:symbol];
    }
    
    // Redraw with new coordinates
    [self invalidateAlertsLayer];
}

#pragma mark - Data Management

- (void)refreshAlerts {
    if (self.panelYContext.currentSymbol) {
        [self loadAlertsForSymbol:self.panelYContext.currentSymbol];
    }
}

- (void)loadAlertsForSymbol:(NSString *)symbol {
    if (!symbol) {
        self.alerts = @[];
        [self invalidateAlertsLayer];
        return;
    }
    
    // Get alerts from DataHub for this symbol
    NSArray<AlertModel *> *allAlerts = [[DataHub shared] getAllAlertModels];
    NSPredicate *symbolPredicate = [NSPredicate predicateWithFormat:@"symbol LIKE[c] %@", symbol];
    self.alerts = [allAlerts filteredArrayUsingPredicate:symbolPredicate];
    
    [self invalidateAlertsLayer];
    
    NSLog(@"🚨 ChartAlertRenderer: Loaded %lu alerts for symbol %@",
          (unsigned long)self.alerts.count, symbol);
}

#pragma mark - Rendering

- (void)renderAllAlerts {
    if (!self.sharedXContext || !self.panelYContext || self.alerts.count == 0) {
        return;
    }
    
    for (AlertModel *alert in self.alerts) {
        if (alert != self.draggingAlert) { // Don't render dragging alert here
            [self drawAlert:alert];
        }
    }
    
    NSLog(@"🎨 ChartAlertRenderer: Rendered %lu static alerts", (unsigned long)self.alerts.count);
}

- (void)renderDraggingAlert {
    if (!self.draggingAlert) return;
    
    // Draw with preview style during drag
    [self drawAlertWithDragStyle:self.draggingAlert];
    
    NSLog(@"🎨 ChartAlertRenderer: Rendered dragging alert");
}

- (void)invalidateAlertsLayer {
    [self.alertsLayer setNeedsDisplay];
}

- (void)invalidateAlertsEditingLayer {
    [self.alertsEditingLayer setNeedsDisplay];
}

#pragma mark - CALayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    
    if (layer == self.alertsLayer) {
        [self renderAllAlerts];
    } else if (layer == self.alertsEditingLayer) {
        [self renderDraggingAlert];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

#pragma mark - Alert Drawing

- (void)drawAlert:(AlertModel *)alert {
    CGFloat y = [self screenYForTriggerValue:alert.triggerValue];
    if (y < 0 || y > self.coordinateContext.panelBounds.size.height) return; // Out of visible range
    
    CGRect bounds = self.coordinateContext.panelBounds;
    
    // Draw horizontal line
    [self drawAlertLine:alert atY:y bounds:bounds];
    
    // Draw ThinkOrSwim-style label
    [self drawAlertLabel:alert atY:y bounds:bounds];
}

- (void)drawAlertWithDragStyle:(AlertModel *)alert {
    CGFloat y = [self screenYForTriggerValue:alert.triggerValue];
    CGRect bounds = self.coordinateContext.panelBounds;
    
    // Set drag preview style
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    CGContextSetAlpha(ctx, 0.8);
    
    // Draw with dashed line style
    CGFloat dashLengths[] = {4.0, 2.0};
    CGContextSetLineDash(ctx, 0, dashLengths, 2);
    
    [self drawAlertLine:alert atY:y bounds:bounds];
    [self drawAlertLabel:alert atY:y bounds:bounds];
    
    CGContextRestoreGState(ctx);
}

- (void)drawAlertLine:(AlertModel *)alert atY:(CGFloat)y bounds:(CGRect)bounds {
    NSColor *lineColor = [self colorForAlert:alert];
    [lineColor setStroke];
    
    NSBezierPath *linePath = [NSBezierPath bezierPath];
    linePath.lineWidth = 1.5;
    
    // Draw line from left edge to label start
    CGFloat labelWidth = 80;
    [linePath moveToPoint:NSMakePoint(10, y)];
    [linePath lineToPoint:NSMakePoint(bounds.size.width - labelWidth - 5, y)];
    [linePath stroke];
}

- (void)drawAlertLabel:(AlertModel *)alert atY:(CGFloat)y bounds:(CGRect)bounds {
    // ThinkOrSwim-style label on the right
    CGFloat labelWidth = 80;
    CGFloat labelHeight = 20;
    CGFloat labelX = bounds.size.width - labelWidth - 5;
    CGFloat labelY = y - labelHeight/2;
    
    NSRect labelRect = NSMakeRect(labelX, labelY, labelWidth, labelHeight);
    
    // Draw label background
    NSColor *bgColor = [self backgroundColorForAlert:alert];
    [bgColor setFill];
    [[NSBezierPath bezierPathWithRoundedRect:labelRect xRadius:3 yRadius:3] fill];
    
    // Draw label text
    NSString *labelText = [self labelTextForAlert:alert];
    NSColor *textColor = [self textColorForAlert:alert];
    NSDictionary *textAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: textColor
    };
    
    NSRect textRect = NSInsetRect(labelRect, 4, 2);
    [labelText drawInRect:textRect withAttributes:textAttrs];
}

#pragma mark - Alert Styling

- (NSColor *)colorForAlert:(AlertModel *)alert {
    if (alert.isTriggered) {
        return [NSColor systemGreenColor]; // Triggered = green
    } else if (alert.isActive) {
        return [NSColor systemOrangeColor]; // Active = orange (like ThinkOrSwim)
    } else {
        return [NSColor systemGrayColor]; // Inactive = gray
    }
}

- (NSColor *)backgroundColorForAlert:(AlertModel *)alert {
    NSColor *baseColor = [self colorForAlert:alert];
    return [baseColor colorWithAlphaComponent:0.9];
}

- (NSColor *)textColorForAlert:(AlertModel *)alert {
    return [NSColor whiteColor]; // White text on colored background
}

- (NSString *)labelTextForAlert:(AlertModel *)alert {
    NSString *condition = @"";
    if ([alert.conditionString isEqualToString:@"above"]) {
        condition = @"≥";
    } else if ([alert.conditionString isEqualToString:@"below"]) {
        condition = @"≤";
    } else if ([alert.conditionString isEqualToString:@"crosses_above"]) {
        condition = @"⤴";
    } else if ([alert.conditionString isEqualToString:@"crosses_below"]) {
        condition = @"⤵";
    }
    if (alert.triggerValue < 1) {
        return [NSString stringWithFormat:@"%@ %.4f", condition, alert.triggerValue];
    }
    return [NSString stringWithFormat:@"%@ %.2f", condition, alert.triggerValue];
}

#pragma mark - Hit Testing

- (nullable AlertModel *)alertAtScreenPoint:(NSPoint)screenPoint tolerance:(CGFloat)tolerance {
    for (AlertModel *alert in self.alerts) {
        CGFloat alertY = [self screenYForTriggerValue:alert.triggerValue];
        
        // Check Y proximity for horizontal line
        if (ABS(screenPoint.y - alertY) <= tolerance) {
            // Check if click is on label area (easier to grab)
            CGFloat labelX = self.coordinateContext.panelBounds.size.width - 85;
            if (screenPoint.x >= labelX) {
                return alert;
            }
            // Or on line itself
            if (screenPoint.x >= 10 && screenPoint.x <= labelX) {
                return alert;
            }
        }
    }
    return nil;
}

#pragma mark - Coordinate Conversion

- (CGFloat)screenYForTriggerValue:(double)triggerValue {
    return [self.panelYContext screenYForValue:triggerValue];
}

- (double)triggerValueForScreenY:(CGFloat)screenY {
    return [self.panelYContext valueForScreenY:screenY];
}

#pragma mark - Alert Drag Operations

- (void)startDraggingAlert:(AlertModel *)alert atPoint:(NSPoint)screenPoint {
    self.isInAlertDragMode = YES;
    self.draggingAlert = alert;
    self.dragStartPoint = screenPoint;
    self.originalTriggerValue = alert.triggerValue;
    
    // Move alert from static layer to editing layer
    [self invalidateAlertsLayer];      // Remove from static
    [self invalidateAlertsEditingLayer]; // Show in editing
    
    NSLog(@"🚨 Started dragging alert %@ from %.2f", alert.symbol, alert.triggerValue);
}

- (void)updateDragToPoint:(NSPoint)screenPoint {
    if (!self.isInAlertDragMode || !self.draggingAlert) return;
    
    // Update alert trigger value based on new Y position
    double newTriggerValue = [self triggerValueForScreenY:screenPoint.y];
    self.draggingAlert.triggerValue = newTriggerValue;
    
    // Redraw editing layer
    [self invalidateAlertsEditingLayer];
    
    NSLog(@"🎯 Dragging alert to %.2f", newTriggerValue);
}

- (void)finishDragWithConfirmation {
    if (!self.isInAlertDragMode || !self.draggingAlert) return;
    
    AlertModel *alert = self.draggingAlert;
    double newValue = alert.triggerValue;
    double oldValue = self.originalTriggerValue;
    
    // Show confirmation dialog
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"Confirm Alert Change";
    confirmAlert.informativeText = [NSString stringWithFormat:
        @"Move alert for %@ from %.2f to %.2f?", alert.symbol, oldValue, newValue];
    [confirmAlert addButtonWithTitle:@"Confirm"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [confirmAlert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        // Confirmed - save via DataHub
        [[DataHub shared] updateAlertModel:alert];
        NSLog(@"✅ Alert updated: %@ %.2f", alert.symbol, newValue);
    } else {
        // Cancelled - restore original value
        alert.triggerValue = oldValue;
        NSLog(@"❌ Alert drag cancelled, restored to %.2f", oldValue);
    }
    
    // Clean up drag state
    [self finishDrag];
}

- (void)cancelDrag {
    if (!self.isInAlertDragMode || !self.draggingAlert) return;
    
    // Restore original value
    self.draggingAlert.triggerValue = self.originalTriggerValue;
    NSLog(@"❌ Alert drag cancelled");
    
    [self finishDrag];
}

- (void)finishDrag {
    self.isInAlertDragMode = NO;
    self.draggingAlert = nil;
    
    // Move alert back to static layer
    [self invalidateAlertsEditingLayer]; // Clear editing layer
    [self invalidateAlertsLayer];        // Redraw static layer
}

#pragma mark - Alert Creation Helper

- (AlertModel *)createAlertTemplateAtScreenPoint:(NSPoint)screenPoint {
    if (!self.coordinateContext.currentSymbol) return nil;
    
    double price = [self triggerValueForScreenY:screenPoint.y];
    
    AlertModel *template = [[AlertModel alloc] init];
    template.symbol = self.coordinateContext.currentSymbol;
    template.triggerValue = price;
    template.conditionString = @"above"; // Default
    template.isActive = YES;
    template.notificationEnabled = YES;
    template.creationDate = [NSDate date];
    
    return template;
}

@end
