//
//  ChartObjectRenderer.m
//  TradingApp
//
//  Chart objects rendering engine implementation
//

#import "ChartObjectRenderer.h"
#import "ChartPanelView.h"
#import "RuntimeModels.h"
#import "ChartWidget.h"

typedef NS_ENUM(NSUInteger, SnapType) {
    SnapTypeNone = 0,
    SnapTypeOHLC,      // Snap a Open/High/Low/Close
    SnapTypeHL,        // Solo High/Low (zoom molto ampio)
    SnapTypeClose      // Solo Close (chart lineare)
};

#pragma mark - Chart Object Renderer Implementation

@interface ChartObjectRenderer () <CALayerDelegate>

// Creation state
@property (nonatomic, assign) ChartObjectType creationObjectType;
@property (nonatomic, strong) NSMutableArray<ControlPointModel *> *tempControlPoints;

// Private readwrite override for isInCreationMode
@property (nonatomic, assign, readwrite) BOOL isInCreationMode;

@end

@implementation ChartObjectRenderer

#pragma mark - Initialization

- (instancetype)initWithPanelView:(ChartPanelView *)panelView
                   objectsManager:(ChartObjectsManager *)objectsManager {
    self = [super init];
    if (self) {
        _panelView = panelView;
        _objectsManager = objectsManager;
        _coordinateContext = [[ChartCoordinateContext alloc] init];
        _tempControlPoints = [NSMutableArray array];
        objectsManager.coordinateRenderer = self;

        [self setupLayersInPanelView];
        
        NSLog(@"🎨 ChartObjectRenderer: Initialized for panel %@", panelView.panelType);
    }
    return self;
}

#pragma mark - Layer Management

- (void)setupLayersInPanelView {
    // Objects layer (static objects)
    self.objectsLayer = [CALayer layer];
    self.objectsLayer.delegate = self;
    self.objectsLayer.needsDisplayOnBoundsChange = YES;
    [self.panelView.layer insertSublayer:self.objectsLayer above:self.panelView.chartContentLayer];
    
    // Objects editing layer (dynamic object being edited)
    self.objectsEditingLayer = [CALayer layer];
    self.objectsEditingLayer.delegate = self;
    self.objectsEditingLayer.needsDisplayOnBoundsChange = YES;
    [self.panelView.layer insertSublayer:self.objectsEditingLayer above:self.objectsLayer];
    
    [self updateLayerFrames];
    
    NSLog(@"🎯 ChartObjectRenderer: Layers setup completed");
}

- (void)updateLayerFrames {
    NSRect bounds = self.panelView.bounds;
    self.objectsLayer.frame = bounds;
    self.objectsEditingLayer.frame = bounds;
}

#pragma mark - CALayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    if (layer == self.objectsLayer) {
        [self drawAllObjectsInContext:ctx];
    } else if (layer == self.objectsEditingLayer) {
        [self drawEditingObjectInContext:ctx];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

#pragma mark - Coordinate System

- (void)updateCoordinateContext:(NSArray<HistoricalBarModel *> *)chartData
                     startIndex:(NSInteger)startIndex
                       endIndex:(NSInteger)endIndex
                      yRangeMin:(double)yMin
                      yRangeMax:(double)yMax
                         bounds:(CGRect)bounds {
    
    BOOL contextChanged = ![self.coordinateContext.chartData isEqualToArray:chartData] ||
                         self.coordinateContext.visibleStartIndex != startIndex ||
                         self.coordinateContext.visibleEndIndex != endIndex ||
                         self.coordinateContext.yRangeMin != yMin ||
                         self.coordinateContext.yRangeMax != yMax ||
                         !CGRectEqualToRect(self.coordinateContext.panelBounds, bounds);
    
    if (contextChanged) {
        self.coordinateContext.chartData = chartData;
        self.coordinateContext.visibleStartIndex = startIndex;
        self.coordinateContext.visibleEndIndex = endIndex;
        self.coordinateContext.yRangeMin = yMin;
        self.coordinateContext.yRangeMax = yMax;
        self.coordinateContext.panelBounds = bounds;
        
        // NUOVO: Aggiorna trading hours context
        ChartWidget *chartWidget = self.panelView.chartWidget;
        if (chartWidget) {
            self.coordinateContext.barsPerDay = [chartWidget barsPerDayForCurrentTimeframe];
            self.coordinateContext.currentTimeframeMinutes = [chartWidget getCurrentTimeframeInMinutes];
        }
        
        [self updateLayerFrames];
        [self invalidateObjectsLayer];
        
        NSLog(@"🔄 ChartObjectRenderer: Coordinate context updated - BarsPerDay: %ld",
              (long)self.coordinateContext.barsPerDay);
    }
}

- (NSPoint)screenPointFromControlPoint:(ControlPointModel *)controlPoint {
    if (!controlPoint || !self.coordinateContext.chartData) {
        return NSMakePoint(-9999, -9999);
    }
    
    NSPoint screenPoint = NSZeroPoint;
    
    // X coordinate: trova la barra (usa metodo corretto)
    NSInteger barIndex = [self findBarIndexForDate:controlPoint.dateAnchor];
    if (barIndex != NSNotFound && barIndex >= 0) {
        screenPoint.x = [self xCoordinateForBarIndex:barIndex];
        
        // ✅ NUOVO: Usa absoluteValue direttamente
        screenPoint.y = [self.coordinateContext screenYForValue:controlPoint.absoluteValue];
        
    } else {
        // Estrapolazione per date fuori dal dataset
        screenPoint.x = [self xCoordinateForDate:controlPoint.dateAnchor];
        // Se la coordinata X è valida ma non abbiamo la barra, usiamo comunque absoluteValue
        if (screenPoint.x > -9999) {
            screenPoint.y = [self.coordinateContext screenYForValue:controlPoint.absoluteValue];
        } else {
            return NSMakePoint(-9999, -9999);
        }
    }
    
    return screenPoint;
}



#pragma mark - Rendering

- (void)renderAllObjects {
    [self invalidateObjectsLayer];
}

- (void)renderObject:(ChartObjectModel *)object {
    [self invalidateObjectsLayer];
}

- (void)renderEditingObject {
    [self invalidateEditingLayer];
}

- (void)invalidateObjectsLayer {
    [self.objectsLayer setNeedsDisplay];
}

- (void)invalidateEditingLayer {
    [self.objectsEditingLayer setNeedsDisplay];
}

#pragma mark - Drawing Implementation

- (void)drawAllObjectsInContext:(CGContextRef)ctx {
    if (!self.objectsManager || !self.coordinateContext.chartData) {
        return;
    }
    
    // Draw all objects from all visible layers
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        if (!layer.isVisible) continue;
        
        for (ChartObjectModel *object in layer.objects) {
            if (!object.isVisible || object == self.editingObject) continue;
            
            [self drawObject:object];
        }
    }
    
    NSLog(@"🎨 ChartObjectRenderer: Drew all static objects");
}


- (void)drawEditingObjectInContext:(CGContextRef)ctx {
    if (!self.editingObject) return;
    
    // NUOVO: Disegna oggetto normale con eventuale highlight
    if (self.isInCreationMode) {
        // Preview style durante creazione
        [self drawObjectWithPreviewStyle:self.editingObject];
    } else {
        // Editing style con control points visibili
        [self drawObjectWithEditingStyle:self.editingObject];
        [self drawControlPointsForObject:self.editingObject];
    }
    
    NSLog(@"🎨 Drew editing object on editing layer");
}

- (void)drawObjectWithPreviewStyle:(ChartObjectModel *)object {
    // Set preview style (dashed, translucent)
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, [NSColor systemPinkColor].CGColor);

    CGContextSetAlpha(ctx, 0.7);
    CGFloat dashLengths[] = {5.0, 3.0};
    CGContextSetLineDash(ctx, 0, dashLengths, 2);
    
    // Draw object normally (will handle missing CPs)
    [self drawObject:object];
    
    CGContextRestoreGState(ctx);
}

- (void)drawObjectWithEditingStyle:(ChartObjectModel *)object {
    // Set editing highlight style
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, [NSColor systemOrangeColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    
    // Draw object normally
    [self drawObject:object];
    
    CGContextRestoreGState(ctx);
}

- (void)drawObjectWithHighlight:(ChartObjectModel *)object {
    // Save original style
    ObjectStyleModel *originalStyle = object.style;
    
    // Create highlighted style
    ObjectStyleModel *highlightStyle = [originalStyle copy];
    highlightStyle.color = [NSColor systemOrangeColor]; // Orange for editing
    highlightStyle.thickness = originalStyle.thickness + 1.0; // Slightly thicker
    highlightStyle.opacity = 1.0; // Full opacity
    
    // Temporarily replace style
    object.style = highlightStyle;
    
    // Draw with highlight
    [self drawObject:object];
    
    // Restore original style
    object.style = originalStyle;
}


- (void)drawObject:(ChartObjectModel *)object {
    switch (object.type) {
        case ChartObjectTypeHorizontalLine:
            [self drawHorizontalLine:object];
            break;
            
        case ChartObjectTypeTrendline:
            [self drawTrendline:object];
            break;
            
        case ChartObjectTypeFibonacci:
            [self drawFibonacci:object];
            break;
            
        case ChartObjectTypeRectangle:
            [self drawRectangle:object];
            break;
            
        case ChartObjectTypeCircle:
            [self drawCircle:object];
            break;
            
        // NUOVO: Channel e Target
        case ChartObjectTypeChannel:
            [self drawChannel:object];
            break;
            
        case ChartObjectTypeTarget:
            [self drawTargetPrice:object];
            break;
            
        case ChartObjectTypeFreeDrawing:
            [self drawFreeDrawing:object];
            break;
            
        case ChartObjectTypeTrailingFibo:
            [self drawTrailingFibo:object];
            break;
        case ChartObjectTypeTrailingFiboBetween:
            [self drawTrailingFibo:object];
            break;
            
        default:
            NSLog(@"⚠️ ChartObjectRenderer: Unknown object type %ld", (long)object.type);
            break;
    }
}


- (void)drawTrailingFiboEnhancedLabel:(NSString *)label
                               atPoint:(NSPoint)point
                           isKeyLevel:(BOOL)isKeyLevel {
    
    // Scegli font in base all'importanza del livello
    NSFont *font = isKeyLevel ?
        [NSFont boldSystemFontOfSize:11] :
        [NSFont systemFontOfSize:10];
    
    // Colore in base al tipo di livello
    NSColor *textColor = isKeyLevel ?
        [NSColor systemBlueColor] :
        [NSColor secondaryLabelColor];
    
    // Background per migliore leggibilità
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor,
        NSBackgroundColorAttributeName: [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.8]
    };
    
    NSAttributedString *attributedLabel = [[NSAttributedString alloc]
                                          initWithString:label
                                          attributes:attributes];
    
    // Calcola dimensioni per posizionamento
    NSSize labelSize = [attributedLabel size];
    NSRect labelRect = NSMakeRect(point.x,
                                 point.y - labelSize.height/2,
                                 labelSize.width + 4,
                                 labelSize.height);
    
    // Disegna background
    [[NSColor controlBackgroundColor] setFill];
    NSRectFillUsingOperation(labelRect, NSCompositingOperationSourceOver);
    
    // Disegna testo
    [attributedLabel drawAtPoint:NSMakePoint(point.x + 2, point.y - labelSize.height/2)];
}

- (void)drawTrailingFiboLabel:(NSString *)label atPoint:(NSPoint)point {
    NSColor *textColor = [NSColor systemTealColor];
    NSColor *bgColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.8];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:9],
        NSForegroundColorAttributeName: textColor,
        NSBackgroundColorAttributeName: bgColor
    };
    
    [label drawAtPoint:point withAttributes:attributes];
}

- (void)drawTrailingFiboStartMarker:(NSPoint)point {
    [[NSColor systemTealColor] setFill];
    
    NSRect markerRect = NSMakeRect(point.x - 4, point.y - 4, 8, 8);
    NSBezierPath *markerPath = [NSBezierPath bezierPathWithOvalInRect:markerRect];
    [markerPath fill];
    
    // White border
    [[NSColor whiteColor] setStroke];
    markerPath.lineWidth = 1.0;
    [markerPath stroke];
}


- (void)drawHorizontalLine:(ChartObjectModel *)object {
    if (object.controlPoints.count < 1) return;
    
    ControlPointModel *cp = object.controlPoints.firstObject;
    NSPoint screenPoint = [self screenPointFromControlPoint:cp];
    
    // ✅ Apply global style (color, opacity)
    [self applyStyleForObject:object];
    
    // ✅ Create and style path
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(0, screenPoint.y)];
    [path lineToPoint:NSMakePoint(self.coordinateContext.panelBounds.size.width, screenPoint.y)];
    
    // ✅ Apply path-specific style and stroke
    [self strokePath:path withStyle:object.style];
}

- (void)drawTrendline:(ChartObjectModel *)object {
    if (object.controlPoints.count < 1) return;
    
    ControlPointModel *cp1 = object.controlPoints[0];
    ControlPointModel *cp2 = object.controlPoints.count > 1 ?
        object.controlPoints[1] : cp1; // FALLBACK
    
    NSPoint startPoint = [self screenPointFromControlPoint:cp1];
    NSPoint endPoint = [self screenPointFromControlPoint:cp2];
    
    // ✅ Apply global style (color, opacity)
    [self applyStyleForObject:object];
    
    // ✅ Create and style path
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:startPoint];
    [path lineToPoint:endPoint];
    
    // ✅ Apply path-specific style and stroke
    [self strokePath:path withStyle:object.style];
    
    NSLog(@"🎨 Drew trendline from (%.1f,%.1f) to (%.1f,%.1f) with thickness %.1f",
          startPoint.x, startPoint.y, endPoint.x, endPoint.y, object.style.thickness);
}

- (void)drawTrendlineControlPoints:(NSPoint)pointA pointB:(NSPoint)pointB {
    [[NSColor systemBlueColor] setFill];
    
    // Draw control point markers
    NSArray *points = @[@(pointA), @(pointB)];
    for (NSValue *pointValue in points) {
        NSPoint point = pointValue.pointValue;
        
        // Only draw if point is reasonably close to viewport
        if (point.x >= -50 && point.x <= self.coordinateContext.panelBounds.size.width + 50) {
            NSRect cpRect = NSMakeRect(point.x - 3, point.y - 3, 6, 6);
            NSBezierPath *cpPath = [NSBezierPath bezierPathWithOvalInRect:cpRect];
            [cpPath fill];
        }
    }
}

- (void)calculateExtendedLineFromPoint:(NSPoint)pointA
                               toPoint:(NSPoint)pointB
                            startPoint:(NSPoint *)startPoint
                              endPoint:(NSPoint *)endPoint
                            extendLeft:(BOOL)extendLeft
                           extendRight:(BOOL)extendRight {
    
    CGRect viewport = self.coordinateContext.panelBounds;
    
    if (!extendLeft && !extendRight) {
        // No extension - just use the original points
        *startPoint = pointA;
        *endPoint = pointB;
        return;
    }
    
    // Calculate line equation: y = mx + c
    CGFloat deltaX = pointB.x - pointA.x;
    CGFloat deltaY = pointB.y - pointA.y;
    
    if (fabs(deltaX) < 0.001) {
        // Vertical line
        CGFloat x = pointA.x;
        *startPoint = NSMakePoint(x, extendLeft ? (viewport.origin.y - 50) : MIN(pointA.y, pointB.y));
        *endPoint = NSMakePoint(x, extendRight ? (viewport.origin.y + viewport.size.height + 50) : MAX(pointA.y, pointB.y));
        return;
    }
    
    CGFloat slope = deltaY / deltaX;
    CGFloat intercept = pointA.y - slope * pointA.x;
    
    // Calculate extended endpoints
    CGFloat startX, endX;
    
    if (extendLeft) {
        startX = viewport.origin.x - 100; // Extend well beyond left edge
    } else {
        startX = MIN(pointA.x, pointB.x);
    }
    
    if (extendRight) {
        endX = viewport.origin.x + viewport.size.width + 100; // Extend well beyond right edge
    } else {
        endX = MAX(pointA.x, pointB.x);
    }
    
    // Calculate Y values for extended endpoints
    CGFloat startY = slope * startX + intercept;
    CGFloat endY = slope * endX + intercept;
    
    *startPoint = NSMakePoint(startX, startY);
    *endPoint = NSMakePoint(endX, endY);
}

- (void)drawFibonacci:(ChartObjectModel *)object {
    if (object.controlPoints.count < 1) return;
    
    ControlPointModel *cp1 = object.controlPoints[0];
    ControlPointModel *cp2 = object.controlPoints.count > 1 ? object.controlPoints[1] : cp1;
    
    NSPoint startPoint = [self screenPointFromControlPoint:cp1];
    NSPoint endPoint = [self screenPointFromControlPoint:cp2];
    
    // ✅ Apply global style (color, opacity)
    [self applyStyleForObject:object];
    
    if (cp2 == cp1) {
        // Single point - draw horizontal line
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(0, startPoint.y)];
        [path lineToPoint:NSMakePoint(self.coordinateContext.panelBounds.size.width, startPoint.y)];
        [self strokePath:path withStyle:object.style];
    } else {
        // Full fibonacci with levels
        [self drawFibonacciLevels:startPoint endPoint:endPoint style:object.style];
    }
}


- (void)drawFibonacciLevels:(NSPoint)startPoint endPoint:(NSPoint)endPoint style:(ObjectStyleModel *)style {
    // Calculate prices from screen points
    CGFloat cp1Price = [self priceFromScreenY:startPoint.y];
    CGFloat cp2Price = [self priceFromScreenY:endPoint.y];
    CGFloat priceRange = cp2Price - cp1Price;
    
    // ✅ FIBONACCI CORRETTI: Retracements da CP2 verso CP1, Extensions oltre CP2
    NSArray *fibRatios = @[@0.0, @0.236, @0.382, @0.5, @0.618, @0.786, @1.0, @1.272, @1.414, @1.618, @2.618, @4.236];
    NSArray *fibLabels = @[@"0%", @"23.6%", @"38.2%", @"50%", @"61.8%", @"78.6%", @"100%", @"127.2%", @"141.4%", @"161.8%", @"261.8%", @"423.6%"];
    
    CGFloat panelWidth = self.coordinateContext.panelBounds.size.width;
    
    for (NSUInteger i = 0; i < fibRatios.count; i++) {
        CGFloat ratio = [fibRatios[i] doubleValue];
        CGFloat fibPrice;
        
        if (ratio <= 1.0) {
            // ✅ RETRACEMENTS (0% - 100%): da CP2 verso CP1
            // Formula: CP2 - (ratio × range)
            // Esempio: 23.6% = $100 - (0.236 × $99) = $76.64 (vicino a CP2)
            fibPrice = cp2Price - (ratio * priceRange);
        } else {
            // ✅ EXTENSIONS (>100%): oltre CP2 verso l'alto
            // Formula: CP2 + ((ratio - 1.0) × range)
            // Esempio: 127.2% = $100 + (0.272 × $99) = $126.93 (sopra CP2)
            fibPrice = cp2Price + ((ratio - 1.0) * priceRange);
        }
        
        CGFloat fibY = [self yCoordinateForPrice:fibPrice];
        
        // Skip levels outside visible range
        if (fibY < -20 || fibY > self.coordinateContext.panelBounds.size.height + 20) continue;
        
        // ✅ STILE DIVERSO per livelli chiave vs extensions
        NSBezierPath *levelPath = [NSBezierPath bezierPath];
        [levelPath moveToPoint:NSMakePoint(startPoint.x, fibY)];
        [levelPath lineToPoint:NSMakePoint(panelWidth, fibY)];
        
        if (ratio == 0.0 || ratio == 1.0) {
            // 0% e 100% - linee principali più spesse
            levelPath.lineWidth = 2.0;
            [[NSColor systemBlueColor] setStroke];
        } else if (ratio > 1.0) {
            // Extensions - linee tratteggiate
            levelPath.lineWidth = 1.5;
            CGFloat dashPattern[] = {5.0, 3.0};
            [levelPath setLineDash:dashPattern count:2 phase:0];
            [[NSColor systemRedColor] setStroke];
        } else {
            // Retracements normali
            levelPath.lineWidth = 1.0;
            [style.color setStroke];
        }
        
        [levelPath stroke];
        
        // ✅ DRAW LABEL con prezzo calcolato
        NSString *labelText = [NSString stringWithFormat:@"%@ (%.2f)", fibLabels[i], fibPrice];
        [self drawFibonacciLabel:labelText
                         atPoint:NSMakePoint(startPoint.x, fibY)
                      isKeyLevel:(ratio == 0.5 || ratio == 0.0 || ratio == 1.0)
                     isExtension:(ratio > 1.0)];
    }
    
    // ✅ DRAW CONTROL POINTS per riferimento
    [self drawFibonacciControlPoint:startPoint label:@"CP1" price:cp1Price];
    [self drawFibonacciControlPoint:endPoint label:@"CP2" price:cp2Price];
}

- (void)drawFibonacciLabel:(NSString *)label
                   atPoint:(NSPoint)point
                isKeyLevel:(BOOL)isKeyLevel
               isExtension:(BOOL)isExtension {
    
    NSFont *font = isKeyLevel ? [NSFont boldSystemFontOfSize:12] : [NSFont systemFontOfSize:10];
    NSColor *textColor = isExtension ? [NSColor systemRedColor] :
                        isKeyLevel ? [NSColor systemBlueColor] : [NSColor labelColor];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor,
        NSBackgroundColorAttributeName: [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.9]
    };
    
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:label attributes:attributes];
    NSSize textSize = [attributedText size];
    
    NSRect labelRect = NSMakeRect(point.x - textSize.width - 4, point.y - textSize.height/2 - 2,
                                  textSize.width + 8, textSize.height + 4);
    
    // Draw background with rounded corners
    [[NSColor controlBackgroundColor] setFill];
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:labelRect xRadius:3 yRadius:3];
    [bgPath fill];
    
    // Draw border for extensions
    if (isExtension) {
        [[NSColor systemRedColor] setStroke];
        bgPath.lineWidth = 1.0;
        [bgPath stroke];
    }
    
    // Draw text
    [attributedText drawAtPoint:NSMakePoint(point.x - textSize.width, point.y - textSize.height/2)];
}
- (void)drawFibonacciControlPoint:(NSPoint)point label:(NSString *)label price:(CGFloat)price {
    // Draw control point marker
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:
                           NSMakeRect(point.x - 4, point.y - 4, 8, 8)];
    [[NSColor systemOrangeColor] setFill];
    [circle fill];
    [[NSColor blackColor] setStroke];
    circle.lineWidth = 1.0;
    [circle stroke];
    
    // Draw label
    NSString *fullLabel = [NSString stringWithFormat:@"%@ (%.2f)", label, price];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor systemOrangeColor]
    };
    
    [fullLabel drawAtPoint:NSMakePoint(point.x + 8, point.y + 4) withAttributes:attributes];
}

- (void)drawFibLabel:(NSString *)text atPoint:(NSPoint)point color:(NSColor *)textColor {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: textColor,
        NSBackgroundColorAttributeName: [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.8]
    };
    
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    NSSize textSize = [attributedText size];
    
    NSRect labelRect = NSMakeRect(point.x - textSize.width - 4, point.y - textSize.height/2 - 2,
                                  textSize.width + 8, textSize.height + 4);
    
    // Draw background
    [[NSColor controlBackgroundColor] setFill];
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:labelRect xRadius:2 yRadius:2];
    [bgPath fill];
    
    // Draw text
    [attributedText drawAtPoint:NSMakePoint(point.x - textSize.width, point.y - textSize.height/2)];
}



- (CGFloat)priceFromScreenY:(CGFloat)screenY {
    return [self.coordinateContext valueForScreenY:screenY];
}

- (CGFloat)yCoordinateForPrice:(double)price {
    return [self.coordinateContext screenYForValue:price];
}

- (void)drawRectangle:(ChartObjectModel *)object {
    if (object.controlPoints.count < 1) return;
    
    ControlPointModel *cp1 = object.controlPoints[0];
    ControlPointModel *cp2 = object.controlPoints.count > 1 ?
        object.controlPoints[1] : cp1; // FALLBACK
    
    NSPoint startPoint = [self screenPointFromControlPoint:cp1];
    NSPoint endPoint = [self screenPointFromControlPoint:cp2];
    
    // ✅ Apply global style (color, opacity)
    [self applyStyleForObject:object];
    
    // ✅ Create and style path
    NSBezierPath *path;
    
    if (cp2 == cp1) {
        // Single point - draw small square
        NSRect rect = NSMakeRect(startPoint.x - 2, startPoint.y - 2, 4, 4);
        path = [NSBezierPath bezierPathWithRect:rect];
    } else {
        // Full rectangle
        NSRect rect = NSMakeRect(MIN(startPoint.x, endPoint.x),
                                MIN(startPoint.y, endPoint.y),
                                fabs(endPoint.x - startPoint.x),
                                fabs(endPoint.y - startPoint.y));
        path = [NSBezierPath bezierPathWithRect:rect];
    }
    
    // ✅ Apply path-specific style and stroke
    [self strokePath:path withStyle:object.style];
}


- (void)drawCircle:(ChartObjectModel *)object {
    if (object.controlPoints.count < 2) return;
    
    NSPoint center = [self screenPointFromControlPoint:object.controlPoints[0]];
    NSPoint edge = [self screenPointFromControlPoint:object.controlPoints[1]];
    
    // ✅ Apply global style (color, opacity)
    [self applyStyleForObject:object];
    
    // ✅ Create and style path
    CGFloat radius = sqrt(pow(edge.x - center.x, 2) + pow(edge.y - center.y, 2));
    NSRect circleRect = NSMakeRect(center.x - radius, center.y - radius, radius * 2, radius * 2);
    NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    
    // ✅ Apply path-specific style and stroke
    [self strokePath:path withStyle:object.style];
}

- (void)drawFreeDrawing:(ChartObjectModel *)object {
    if (object.controlPoints.count < 2) return;
    
    // ✅ Apply global style (color, opacity)
    [self applyStyleForObject:object];
    
    // ✅ Create and style path
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSPoint firstPoint = [self screenPointFromControlPoint:object.controlPoints.firstObject];
    [path moveToPoint:firstPoint];
    
    for (NSUInteger i = 1; i < object.controlPoints.count; i++) {
        NSPoint point = [self screenPointFromControlPoint:object.controlPoints[i]];
        [path lineToPoint:point];
    }
    
    // ✅ Apply path-specific style and stroke
    [self strokePath:path withStyle:object.style];
}
- (void)drawChannel:(ChartObjectModel *)object {
    if (object.controlPoints.count < 1) return;
    
    ControlPointModel *cp1 = object.controlPoints[0];
    ControlPointModel *cp2 = object.controlPoints.count > 1 ? object.controlPoints[1] : cp1;
    ControlPointModel *cp3 = object.controlPoints.count > 2 ? object.controlPoints[2] : cp1;
    
    NSPoint point1 = [self screenPointFromControlPoint:cp1];
    NSPoint point2 = [self screenPointFromControlPoint:cp2];
    NSPoint point3 = [self screenPointFromControlPoint:cp3];
    
    // ✅ Apply global style (color, opacity)
    [self applyStyleForObject:object];
    
    if (object.controlPoints.count == 1) {
        // Solo CP1 - disegna punto
        NSRect rect = NSMakeRect(point1.x - 2, point1.y - 2, 4, 4);
        NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:rect];
        [path fill]; // Point is filled, not stroked
        
    } else if (object.controlPoints.count == 2) {
        // CP1 + CP2 - disegna prima trendline
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:point1];
        [path lineToPoint:point2];
        [self strokePath:path withStyle:object.style];
        
    } else {
        // Tutti e 3 CP - disegna channel completo
        
        // Prima trendline (CP1 - CP2)
        NSBezierPath *path1 = [NSBezierPath bezierPath];
        [path1 moveToPoint:point1];
        [path1 lineToPoint:point2];
        [self strokePath:path1 withStyle:object.style];
        
        // Calcola parallela attraverso CP3
        CGFloat dx = point2.x - point1.x;
        CGFloat dy = point2.y - point1.y;
        
        CGFloat panelWidth = self.coordinateContext.panelBounds.size.width;
        CGFloat lineLength = sqrt(dx*dx + dy*dy);
        CGFloat extensionFactor = panelWidth / lineLength * 2;
        
        CGFloat dirX = dx / lineLength;
        CGFloat dirY = dy / lineLength;
        
        CGFloat extendedDx = dirX * extensionFactor * lineLength;
        CGFloat extendedDy = dirY * extensionFactor * lineLength;
        
        NSPoint parallelStart = NSMakePoint(point3.x - extendedDx/2, point3.y - extendedDy/2);
        NSPoint parallelEnd = NSMakePoint(point3.x + extendedDx/2, point3.y + extendedDy/2);
        
        // Seconda trendline (parallela attraverso CP3)
        NSBezierPath *path2 = [NSBezierPath bezierPath];
        [path2 moveToPoint:parallelStart];
        [path2 lineToPoint:parallelEnd];
        [self strokePath:path2 withStyle:object.style];
        
        // Linee di connessione (tratteggiate)
        ObjectStyleModel *dashStyle = [object.style copy];
        dashStyle.lineType = ChartLineTypeDashed;
        dashStyle.opacity = 0.5;
        
        NSBezierPath *connectionPath = [NSBezierPath bezierPath];
        [connectionPath moveToPoint:point1];
        [connectionPath lineToPoint:point3];
        
        // Apply dashed style temporarily
        CGContextSetAlpha([[NSGraphicsContext currentContext] CGContext], dashStyle.opacity);
        [self strokePath:connectionPath withStyle:dashStyle];
        CGContextSetAlpha([[NSGraphicsContext currentContext] CGContext], object.style.opacity); // Restore
    }
    
    NSLog(@"🎨 Drew channel with %lu CPs", (unsigned long)object.controlPoints.count);
}

- (void)drawSimpleTargetLabel:(NSString *)text atPoint:(NSPoint)point color:(NSColor *)textColor {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:16], // Coerente con drawTargetLabels
        NSForegroundColorAttributeName: textColor,
        NSBackgroundColorAttributeName: [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.9]
    };
    
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    NSSize textSize = [attributedText size];
    
    NSRect labelRect = NSMakeRect(point.x, point.y - textSize.height/2 - 2,
                                  textSize.width + 8, textSize.height + 4);
    
    // Draw background
    [[NSColor controlBackgroundColor] setFill];
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:labelRect xRadius:2 yRadius:2];
    [bgPath fill];
    
    // Draw text
    [attributedText drawAtPoint:NSMakePoint(point.x + 4, point.y - textSize.height/2)];
}

- (void)drawTargetPrice:(ChartObjectModel *)object {
    // ✅ VERIFICA: Target deve avere esattamente 3 CP (buy, stop, target)
    if (object.controlPoints.count < 3) {
           if (object.controlPoints.count >= 1) {
               ControlPointModel *cp = object.controlPoints.firstObject;
               NSPoint screenPoint = [self screenPointFromControlPoint:cp];
               
               [self applyStyleForObject:object];
               
               NSBezierPath *path = [NSBezierPath bezierPath];
               [path moveToPoint:NSMakePoint(0, screenPoint.y)];
               [path lineToPoint:NSMakePoint(self.coordinateContext.panelBounds.size.width, screenPoint.y)];
               [self strokePath:path withStyle:object.style];
               
               // ✅ CORRETTO: Usa metodo semplice invece di drawTargetLabel obsoleto
               CGFloat targetPrice = [self.coordinateContext valueForScreenY:screenPoint.y];
               NSString *labelText = [NSString stringWithFormat:@"Target: %.2f", targetPrice];
               [self drawSimpleTargetLabel:labelText atPoint:NSMakePoint(10, screenPoint.y) color:object.style.color];
           }
           return;
       }
    
    // ✅ ESTRAI i 3 control points
    ControlPointModel *buyCP = object.controlPoints[0];    // CP1 = Buy Signal
    ControlPointModel *stopCP = object.controlPoints[1];   // CP2 = Stop Loss
    ControlPointModel *targetCP = object.controlPoints[2]; // CP3 = Target Price
    
    // ✅ CONVERTI in coordinate schermo
    NSPoint buyPoint = [self screenPointFromControlPoint:buyCP];
    NSPoint stopPoint = [self screenPointFromControlPoint:stopCP];
    NSPoint targetPoint = [self screenPointFromControlPoint:targetCP];
    
    // ✅ CALCOLA prezzi reali
    double buyPrice = [self priceFromControlPoint:buyCP];
    double stopPrice = [self priceFromControlPoint:stopCP];
    double targetPrice = [self priceFromControlPoint:targetCP];
    
    // ✅ CALCOLA percentuali e RRR
    double stopLossPercent = ((stopPrice - buyPrice) / buyPrice) * 100.0;
    double targetPercent = ((targetPrice - buyPrice) / buyPrice) * 100.0;
    double rrr = fabs(targetPercent) / fabs(stopLossPercent);
    
    // ✅ DISEGNA zone evidenziate (solo da CP1 in poi)
    CGFloat panelWidth = self.coordinateContext.panelBounds.size.width;
    
    // Zona Loss (tra buy e stop) - rossa traslucida, solo da CP1 verso destra
    CGFloat lossTop = MIN(buyPoint.y, stopPoint.y);
    CGFloat lossBottom = MAX(buyPoint.y, stopPoint.y);
    NSRect lossZone = NSMakeRect(buyPoint.x, lossTop, panelWidth - buyPoint.x, lossBottom - lossTop);
    [self drawTargetHighlight:lossZone color:[NSColor systemRedColor]];
    
    // Zona Profit (tra buy e target) - verde traslucida, solo da CP1 verso destra
    CGFloat profitTop = MIN(buyPoint.y, targetPoint.y);
    CGFloat profitBottom = MAX(buyPoint.y, targetPoint.y);
    NSRect profitZone = NSMakeRect(buyPoint.x, profitTop, panelWidth - buyPoint.x, profitBottom - profitTop);
    [self drawTargetHighlight:profitZone color:[NSColor systemGreenColor]];
    
    // ✅ DISEGNA le 3 linee orizzontali (da CP1 verso destra, fermate a sinistra su CP1)
    [self applyStyleForObject:object];
    
    // Linea BUY - da CP1 verso destra infinito
    NSBezierPath *buyPath = [NSBezierPath bezierPath];
    [buyPath moveToPoint:NSMakePoint(buyPoint.x, buyPoint.y)];
    [buyPath lineToPoint:NSMakePoint(panelWidth, buyPoint.y)];
    [self strokePath:buyPath withStyle:object.style];
    
    // Linea STOP - da CP1 verso destra infinito, tratteggiata rossa
    ObjectStyleModel *stopStyle = [object.style copy];
    stopStyle.color = [NSColor systemRedColor];
    stopStyle.lineType = ChartLineTypeDashed;
    NSBezierPath *stopPath = [NSBezierPath bezierPath];
    [stopPath moveToPoint:NSMakePoint(buyPoint.x, stopPoint.y)];
    [stopPath lineToPoint:NSMakePoint(panelWidth, stopPoint.y)];
    [self strokePath:stopPath withStyle:stopStyle];
    
    // Linea TARGET - da CP1 verso destra infinito, tratteggiata verde
    ObjectStyleModel *targetStyle = [object.style copy];
    targetStyle.color = [NSColor systemGreenColor];
    targetStyle.lineType = ChartLineTypeDashed;
    NSBezierPath *targetPath = [NSBezierPath bezierPath];
    [targetPath moveToPoint:NSMakePoint(buyPoint.x, targetPoint.y)];
    [targetPath lineToPoint:NSMakePoint(panelWidth, targetPoint.y)];
    [self strokePath:targetPath withStyle:targetStyle];
    
    // ✅ USA IL METODO ESISTENTE per i labels
    [self drawTargetLabels:buyPoint stopPoint:stopPoint targetPoint:targetPoint
                  buyPrice:buyPrice stopPrice:stopPrice targetPrice:targetPrice
              stopLossPercent:stopLossPercent targetPercent:targetPercent rrr:rrr];
}



- (void)drawTargetHighlight:(NSRect)rect color:(NSColor *)color {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    // ✅ FORZA alpha 0.1 sempre, anche quando finalizzato
    NSColor *highlightColor = [color colorWithAlphaComponent:0.1];
    CGContextSetFillColorWithColor(ctx, highlightColor.CGColor);
    
    // ✅ DISABILITA blending mode per evitare accumulo alpha
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    CGContextFillRect(ctx, rect);
    
    CGContextRestoreGState(ctx);
    
    NSLog(@"🎨 Target highlight: alpha=%.1f, rect=%@",
          highlightColor.alphaComponent, NSStringFromRect(rect));
}



- (void)drawControlPointsForObject:(ChartObjectModel *)object {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    for (ControlPointModel *cp in object.controlPoints) {
        NSPoint point = [self screenPointFromControlPoint:cp];
        
        if (cp == self.currentCPSelected) {
            // Selected CP - filled orange circle
            CGContextSetFillColorWithColor(ctx, [NSColor systemOrangeColor].CGColor);
            CGRect rect = CGRectMake(point.x - 4, point.y - 4, 8, 8);
            CGContextFillEllipseInRect(ctx, rect);
        } else {
            // Normal CP - small blue circle
            CGContextSetStrokeColorWithColor(ctx, [NSColor systemBlueColor].CGColor);
            CGContextSetLineWidth(ctx, 1.0);
            CGRect rect = CGRectMake(point.x - 3, point.y - 3, 6, 6);
            CGContextStrokeEllipseInRect(ctx, rect);
        }
    }
    
    CGContextRestoreGState(ctx);
}

#pragma mark - Unified Style Application

// ✅ COMPLETE applyStyleForObject - now works with both CGContext AND NSBezierPath
- (void)applyStyleForObject:(ChartObjectModel *)object {
    ObjectStyleModel *style = object.style;
    
    if (!style) {
        NSLog(@"⚠️ ChartObjectRenderer: Object %@ has no style, using defaults", object.name);
        style = [ObjectStyleModel defaultStyleForObjectType:object.type];
    }
    
    // ✅ Set stroke color globally
    [style.color setStroke];
    
    // ✅ Set opacity globally via graphics context
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSetAlpha(ctx, style.opacity);
    
    NSLog(@"🎨 Applied global style - Color: %@, Opacity: %.1f for object: %@",
          style.color, style.opacity, object.name);
}

// ✅ NEW: Helper method to apply complete style to NSBezierPath
- (void)applyStyle:(ObjectStyleModel *)style toPath:(NSBezierPath *)path {
    if (!style) return;
    
    // Apply thickness
    path.lineWidth = style.thickness;
    
    // Apply dash pattern
    switch (style.lineType) {
        case ChartLineTypeDashed: {
            CGFloat pattern[] = {5.0, 3.0};
            [path setLineDash:pattern count:2 phase:0];
            break;
        }
        case ChartLineTypeDotted: {
            CGFloat pattern[] = {2.0, 2.0};
            [path setLineDash:pattern count:2 phase:0];
            break;
        }
        case ChartLineTypeDashDot: {
            CGFloat pattern[] = {5.0, 2.0, 2.0, 2.0};
            [path setLineDash:pattern count:4 phase:0];
            break;
        }
        default: // ChartLineTypeSolid
            [path setLineDash:NULL count:0 phase:0];
            break;
    }
    
    NSLog(@"🎨 Applied path style - Thickness: %.1f, LineType: %ld",
          style.thickness, (long)style.lineType);
}

// ✅ NEW: Convenience method to create and stroke a styled path
- (void)strokePath:(NSBezierPath *)path withStyle:(ObjectStyleModel *)style {
    [self applyStyle:style toPath:path];
    [path stroke];
}

#pragma mark - Object Creation/Editing

- (void)startCreatingObjectOfType:(ChartObjectType)objectType {
    self.isInCreationMode = YES;
    self.creationObjectType = objectType;
    [self.tempControlPoints removeAllObjects];
    
    // Clear any previous editing object
    self.editingObject = nil;
    
    NSLog(@"🎯 ChartObjectRenderer: Started creating object type %ld", (long)objectType);
}

- (void)createEditingObjectFromTempCPs {
    // ✅ PULITO: Crea solo oggetto in memoria, nessun layer temp!
    ChartObjectModel *tempObject = [ChartObjectModel objectWithType:self.creationObjectType
                                                                name:@"Preview"];
    
    // Add all temp control points
    for (ControlPointModel *cp in self.tempControlPoints) {
        [tempObject addControlPoint:cp];
    }
    
    // Set as editing object - verrà disegnato nel CALayer editing
    self.editingObject = tempObject;
    [self invalidateEditingLayer];
    
    NSLog(@"🎯 Created preview object with %lu CPs (no model layer needed)",
          (unsigned long)tempObject.controlPoints.count);
}




- (BOOL)addControlPointAtScreenPoint:(NSPoint)screenPoint {
    ControlPointModel *newCP = [self controlPointFromScreenPoint:screenPoint indicatorRef:@"close"];
    if (!newCP) return NO;
    
    [self.tempControlPoints addObject:newCP];
    self.currentCPSelected = newCP;
    
    // Crea oggetto preview
    [self createEditingObjectFromTempCPs];
    
    NSLog(@"🎯 Added CP %lu for type %ld", (unsigned long)self.tempControlPoints.count, (long)self.creationObjectType);
    
 
    NSLog(@"🔄 Object needs more CPs, continuing creation...");
    return NO; // Continua la creazione
}


- (void)consolidateCurrentCPAndPrepareNext {
    if (!self.isInCreationMode || !self.currentCPSelected) return;
    
    NSLog(@"🎯 Consolidating current CP... (tempPoints: %lu)", (unsigned long)self.tempControlPoints.count);
    
    // Clear currentCPSelected (consolida)
    self.currentCPSelected = nil;
    
    // ✅ FIX: Check se l'oggetto è già completo PRIMA di aggiungere altri CP
    BOOL isAlreadyComplete = [self isObjectCreationComplete];
    
    if (isAlreadyComplete) {
        // ✅ OGGETTO GIÀ COMPLETO: Non aggiungere altri CP, finisci
        NSLog(@"✅ Object already complete, finishing creation");
        [self finishCreatingObject];
        
        // ✅ AGGIUNGI QUESTA CHIAMATA:
        [self finalizeObjectCreation:self.objectsManager.activeLayer.objects.lastObject];
        
        [self notifyObjectCreationCompleted];
        return;
    }
    
    // Check if object needs more control points
    BOOL needsMorePoints = [self needsMoreControlPointsForCreation];
    
    if (needsMorePoints) {
        // Create next CP at current mouse position
        ControlPointModel *nextCP = [self controlPointFromScreenPoint:self.currentMousePosition
                                                      indicatorRef:@"close"];
        if (nextCP) {
            [self.tempControlPoints addObject:nextCP];
            self.currentCPSelected = nextCP;
            
            // Update editing object with new CP
            [self createEditingObjectFromTempCPs];
            
            NSLog(@"🎯 Created next CP %lu", (unsigned long)self.tempControlPoints.count);
        }
    } else {
        // Object is complete
        NSLog(@"✅ Object creation completed in consolidate");
        [self finishCreatingObject];
        
        // ✅ AGGIUNGI QUESTA CHIAMATA:
        [self finalizeObjectCreation:self.objectsManager.activeLayer.objects.lastObject];
        
        [self notifyObjectCreationCompleted];
    }
}

- (BOOL)needsMoreControlPointsForCreation {
    switch (self.creationObjectType) {
        case ChartObjectTypeHorizontalLine:
        case ChartObjectTypeTrailingFibo:
            // ✅ Questi oggetti hanno bisogno di solo 1 CP
            return self.tempControlPoints.count < 1;
            
        case ChartObjectTypeTrendline:
        case ChartObjectTypeFibonacci:
        case ChartObjectTypeRectangle:
        case ChartObjectTypeCircle:
        case ChartObjectTypeTrailingFiboBetween:
            // ✅ Questi oggetti hanno bisogno di 2 CP
            return self.tempControlPoints.count < 2;
            
        case ChartObjectTypeChannel:
        case ChartObjectTypeTarget:
            // ✅ Channel ha bisogno di 3 CP
            return self.tempControlPoints.count < 3;
            
        default:
            return NO;
    }
}

- (BOOL)isObjectCreationComplete {
    // ✅ Semplicemente nega needsMoreControlPointsForCreation
    return ![self needsMoreControlPointsForCreation];
}

- (void)notifyObjectCreationCompleted {
    // Find ChartWidget through panelView
    if (self.panelView.chartWidget && self.panelView.chartWidget.objectsPanel) {
        [self.panelView.chartWidget.objectsPanel objectCreationCompleted];
        NSLog(@"🔔 Notified ObjectsPanel that object creation completed");
    }
}


- (void)finalizeObjectCreation:(ChartObjectModel *)object {
    if (!object) return;
    
    NSLog(@"💾 ChartObjectRenderer: Finalizing object creation for '%@'", object.name);
    
    // Salva tutto nel DataHub (incluso eventuale layer lazy-created)
    [self.objectsManager saveToDataHub];
    
    // Notifica UI refresh
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChartObjectsChanged"
                                                        object:self
                                                      userInfo:@{@"symbol": self.objectsManager.currentSymbol ?: @""}];
    
    NSLog(@"✅ ChartObjectRenderer: Object creation finalized and saved");
    NSLog(@"💾 SENDING NOTIFICATION for symbol: %@", self.objectsManager.currentSymbol);
    NSLog(@"💾 Manager has %lu layers", (unsigned long)self.objectsManager.layers.count);
}


- (void)updateEditingHoverAtPoint:(NSPoint)screenPoint {
    if (!self.editingObject) return;
    
    // Check if hovering over a control point
    ControlPointModel *hoveredCP = nil;
    for (ControlPointModel *cp in self.editingObject.controlPoints) {
        NSPoint cpPoint = [self screenPointFromControlPoint:cp];
        CGFloat distance = sqrt(pow(screenPoint.x - cpPoint.x, 2) + pow(screenPoint.y - cpPoint.y, 2));
        if (distance <= 12.0) { // Hover tolerance
            hoveredCP = cp;
            break;
        }
    }
    
    // Update hover state
    if (hoveredCP != self.hoveredControlPoint) {
        self.hoveredControlPoint = hoveredCP;
        [self invalidateEditingLayer];
    }
}



- (void)selectControlPointForEditing:(ControlPointModel *)controlPoint {
    // Clear previous selection
    if (self.currentCPSelected) {
        self.currentCPSelected.isSelected = NO;
    }
    
    // Set new selection
    self.currentCPSelected = controlPoint;
    if (controlPoint) {
        controlPoint.isSelected = YES;
        NSLog(@"🎯 Selected control point for editing");
    }
    
    [self invalidateEditingLayer];
}





- (void)finishCreatingObject {
    if (!self.isInCreationMode || self.tempControlPoints.count == 0) return;
    
    // ✅ CORREZIONE: Usa ensureActiveLayerForObjectCreation invece di creare layer direttamente
    // Questo è il metodo corretto che gestisce la creazione lazy dei layer
    ChartLayerModel *activeLayer = [self.objectsManager ensureActiveLayerForObjectCreation];
    
    if (!activeLayer) {
        NSLog(@"❌ ChartObjectRenderer: Failed to ensure active layer");
        [self cancelCreatingObject];
        return;
    }
    
    // ✅ Crea oggetto nel layer assicurato
    ChartObjectModel *finalObject = [self.objectsManager createObjectOfType:self.creationObjectType
                                                                     inLayer:activeLayer];
    
    if (!finalObject) {
        NSLog(@"❌ ChartObjectRenderer: Failed to create object");
        [self cancelCreatingObject];
        return;
    }
    
    // Copy control points from temp to final
    for (ControlPointModel *cp in self.tempControlPoints) {
        [finalObject addControlPoint:cp];
    }
    
    // ✅ SALVA SOLO QUI - quando l'oggetto è completamente configurato
    [self.objectsManager saveToDataHub];
    
    // Cleanup
    [self cancelCreatingObject];
    [self invalidateObjectsLayer];
    
    NSLog(@"✅ Created and saved complete object '%@' in layer '%@'",
          finalObject.name, activeLayer.name);
}


// 4. Modificare cancelCreatingObject per clear currentCPSelected
- (void)cancelCreatingObject {
    self.isInCreationMode = NO;
    self.creationObjectType = 0;
    self.currentMousePosition = NSZeroPoint;
    self.currentCPSelected = nil;
    
    // ✅ PULITO: Elimina solo l'oggetto preview dalla memoria
    self.editingObject = nil;
    
    [self.tempControlPoints removeAllObjects];
    [self invalidateEditingLayer];  // Cancella preview dal CALayer
    
    NSLog(@"❌ Cancelled object creation - cleaned preview from memory");
}


// ✅ STESSO PRINCIPIO per editing oggetti esistenti
- (void)startEditingObject:(ChartObjectModel *)object {
    [self stopEditing]; // Stop any current editing
    
    // ✅ SEMPLICE: L'oggetto reale diventa l'editingObject
    self.editingObject = object;
    [self.objectsManager selectObject:object];
    
    // Move object visualization from static layer to editing layer
    [self invalidateObjectsLayer];  // Redraw without this object
    [self invalidateEditingLayer];  // Draw object in editing layer
    
    NSLog(@"✏️ Started editing object '%@' - moved to editing layer", object.name);
}

- (void)stopEditing {
    if (!self.editingObject) return;
    
    ChartObjectModel *object = self.editingObject;
    
    // ✅ SALVA quando finisci di editare
    [self.objectsManager saveToDataHub];
    
    // Cleanup editing state
    self.editingObject = nil;
    [self.objectsManager clearSelection];
    
    // Move object visualization back to static layer
    [self invalidateObjectsLayer];
    [self invalidateEditingLayer];
    
    NSLog(@"✅ Stopped editing object '%@' and saved changes", object.name);
}

#pragma mark - Hit Testing

- (ChartObjectModel *)objectAtScreenPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    // Iterate through objects in reverse layer order (top to bottom)
    NSArray *reversedLayers = [[self.objectsManager.layers reverseObjectEnumerator] allObjects];
    
    for (ChartLayerModel *layer in reversedLayers) {
        if (!layer.isVisible) continue;
        
        NSArray *reversedObjects = [[layer.objects reverseObjectEnumerator] allObjects];
        for (ChartObjectModel *object in reversedObjects) {
            if (!object.isVisible) continue;
            
            if ([self isPoint:point withinObject:object tolerance:tolerance]) {
                return object;
            }
        }
    }
    
    return nil;
}

- (ControlPointModel *)controlPointAtScreenPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    // Check editing object control points first
    if (self.editingObject) {
        for (ControlPointModel *cp in self.editingObject.controlPoints) {
            NSPoint cpPoint = [self screenPointFromControlPoint:cp];
            CGFloat distance = sqrt(pow(point.x - cpPoint.x, 2) + pow(point.y - cpPoint.y, 2));
            if (distance <= tolerance) {
                return cp;
            }
        }
    }
    
    return nil;
}

- (BOOL)isPoint:(NSPoint)point withinObject:(ChartObjectModel *)object tolerance:(CGFloat)tolerance {
    switch (object.type) {
        case ChartObjectTypeHorizontalLine:
            return [self isPoint:point withinHorizontalLine:object tolerance:tolerance];
            
        case ChartObjectTypeTrendline:
            return [self isPoint:point withinTrendline:object tolerance:tolerance];
            
        case ChartObjectTypeFibonacci:
            return [self isPoint:point withinFibonacci:object tolerance:tolerance];
            
        case ChartObjectTypeRectangle:
            return [self isPoint:point withinRectangle:object tolerance:tolerance];
            
        case ChartObjectTypeCircle:
            return [self isPoint:point withinCircle:object tolerance:tolerance];
            
        default:
            // Fallback: Check control points with increased tolerance
            for (ControlPointModel *cp in object.controlPoints) {
                NSPoint cpPoint = [self screenPointFromControlPoint:cp];
                CGFloat distance = sqrt(pow(point.x - cpPoint.x, 2) + pow(point.y - cpPoint.y, 2));
                if (distance <= tolerance * 2.0) { // Double tolerance for fallback
                    return YES;
                }
            }
            return NO;
    }
}

- (BOOL)isPoint:(NSPoint)point withinHorizontalLine:(ChartObjectModel *)object tolerance:(CGFloat)tolerance {
    if (object.controlPoints.count < 1) return NO;
    
    NSPoint linePoint = [self screenPointFromControlPoint:object.controlPoints.firstObject];
    
    // Check if point is close to the horizontal line Y coordinate
    CGFloat yDistance = fabs(point.y - linePoint.y);
    return yDistance <= (tolerance + 5.0); // Extra tolerance for horizontal lines
}

- (BOOL)isPoint:(NSPoint)point withinTrendline:(ChartObjectModel *)object tolerance:(CGFloat)tolerance {
    if (object.controlPoints.count < 2) return NO;
    
    NSPoint pointA = [self screenPointFromControlPoint:object.controlPoints[0]];
    NSPoint pointB = [self screenPointFromControlPoint:object.controlPoints[1]];
    
    // Calculate distance from point to line segment
    CGFloat distance = [self distanceFromPoint:point toLineSegmentA:pointA B:pointB];
    return distance <= (tolerance + 8.0); // Extra tolerance for trendlines
}

- (BOOL)isPoint:(NSPoint)point withinFibonacci:(ChartObjectModel *)object tolerance:(CGFloat)tolerance {
    if (object.controlPoints.count < 2) return NO;
    
    NSPoint pointA = [self screenPointFromControlPoint:object.controlPoints[0]];
    NSPoint pointB = [self screenPointFromControlPoint:object.controlPoints[1]];
    
    // Check if point is near any fibonacci level
    NSArray *levels = @[@0.0, @0.236, @0.382, @0.5, @0.618, @1.0];
    
    for (NSNumber *level in levels) {
        CGFloat ratio = level.floatValue;
        CGFloat y = pointA.y + ratio * (pointB.y - pointA.y);
        
        if (fabs(point.y - y) <= (tolerance + 5.0)) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isPoint:(NSPoint)point withinRectangle:(ChartObjectModel *)object tolerance:(CGFloat)tolerance {
    if (object.controlPoints.count < 2) return NO;
    
    NSPoint point1 = [self screenPointFromControlPoint:object.controlPoints[0]];
    NSPoint point2 = [self screenPointFromControlPoint:object.controlPoints[1]];
    
    NSRect rect = NSMakeRect(MIN(point1.x, point2.x), MIN(point1.y, point2.y),
                            fabs(point2.x - point1.x), fabs(point2.y - point1.y));
    
    // Expand rect by tolerance for easier selection
    NSRect expandedRect = NSInsetRect(rect, -(tolerance + 5.0), -(tolerance + 5.0));
    return NSPointInRect(point, expandedRect) && !NSPointInRect(point, NSInsetRect(rect, tolerance + 5.0, tolerance + 5.0));
}

- (BOOL)isPoint:(NSPoint)point withinCircle:(ChartObjectModel *)object tolerance:(CGFloat)tolerance {
    if (object.controlPoints.count < 2) return NO;
    
    NSPoint center = [self screenPointFromControlPoint:object.controlPoints[0]];
    NSPoint edge = [self screenPointFromControlPoint:object.controlPoints[1]];
    
    CGFloat radius = sqrt(pow(edge.x - center.x, 2) + pow(edge.y - center.y, 2));
    CGFloat distanceFromCenter = sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2));
    
    // Check if point is near the circle circumference
    return fabs(distanceFromCenter - radius) <= (tolerance + 8.0);
}

- (CGFloat)distanceFromPoint:(NSPoint)point toLineSegmentA:(NSPoint)a B:(NSPoint)b {
    // Calculate distance from point to line segment
    CGFloat A = point.x - a.x;
    CGFloat B = point.y - a.y;
    CGFloat C = b.x - a.x;
    CGFloat D = b.y - a.y;
    
    CGFloat dot = A * C + B * D;
    CGFloat lenSq = C * C + D * D;
    
    if (lenSq == 0) {
        // Line segment is actually a point
        return sqrt(A * A + B * B);
    }
    
    CGFloat param = dot / lenSq;
    
    CGFloat xx, yy;
    
    if (param < 0) {
        xx = a.x;
        yy = a.y;
    } else if (param > 1) {
        xx = b.x;
        yy = b.y;
    } else {
        xx = a.x + param * C;
        yy = a.y + param * D;
    }
    
    CGFloat dx = point.x - xx;
    CGFloat dy = point.y - yy;
    
    return sqrt(dx * dx + dy * dy);
}

#pragma mark - TrailingFibo Core Algorithm

/**
 * Calcola i livelli Fibonacci trailing basandosi sui picchi progressivi
 * Adattato dal codice esistente della vecchia app
 */
- (NSArray<NSDictionary *> *)calculateTrailingFibonacciForObject:(ChartObjectModel *)object {
    NSMutableArray<NSDictionary *> *segments = [NSMutableArray array];
    
    // Ottieni dati storici dal coordinateContext
    NSArray<HistoricalBarModel *> *data = self.coordinateContext.chartData;
    if (data.count == 0 || object.controlPoints.count == 0) {
        NSLog(@"⚠️ TrailingFibo: No data or control points available");
        return @[];
    }
    
    // Estrai informazioni del control point di partenza
    ControlPointModel *startCP = object.controlPoints.firstObject;
    NSDate *cp1Date = startCP.dateAnchor;
    double cp1Value = [self priceFromControlPoint:startCP];
    
    // ✅ TRAILING BETWEEN: Gestione del secondo control point
    ControlPointModel *endCP = nil;
    NSDate *cp2Date = nil;
    CGFloat maxSegmentX = self.coordinateContext.panelBounds.size.width; // Default: bordo destro
    
    if (object.type == ChartObjectTypeTrailingFiboBetween && object.controlPoints.count >= 2) {
        endCP = object.controlPoints[1];
        cp2Date = endCP.dateAnchor;
        maxSegmentX = [self xCoordinateForDataIndex:[self findDataIndexForDate:cp2Date]];
        NSLog(@"🎯 TrailingFiboBetween: Limited from %@ to %@ (maxX: %.1f)", cp1Date, cp2Date, maxSegmentX);
    } else {
        NSLog(@"🎯 TrailingFibo: Starting from CP1 at %@ with price %.2f", cp1Date, cp1Value);
    }
    
    // 1️⃣ Trova indice di partenza nei dati storici
    NSInteger startIndex = [self findDataIndexForDate:cp1Date];
    if (startIndex == -1) {
        NSLog(@"❌ TrailingFibo: Could not find start date in historical data");
        return @[];
    }
    
    // 2️⃣ Determina direzione del trailing Fibonacci
    BOOL upFibo = [self shouldSearchForHighsFromBar:data[startIndex] cpValue:cp1Value];
    NSLog(@"📈 TrailingFibo: Direction = %@ (searching for %@)",
          upFibo ? @"UP" : @"DOWN", upFibo ? @"highs" : @"lows");
    
    // 3️⃣ Trova la data di fine
    NSInteger endIndex = data.count - 1;
    if (cp2Date) {
        endIndex = [self findDataIndexForDate:cp2Date];
        if (endIndex == -1) endIndex = data.count - 1;
        NSLog(@"🏁 TrailingFiboBetween: End date limiting to index %ld", (long)endIndex);
    }
    
    // 4️⃣ Inizializza min/max tracking
    double minPrice = cp1Value;
    double maxPrice = cp1Value;
    CGFloat lastX = [self xCoordinateForDataIndex:startIndex];
    
    // 5️⃣ Ciclo progressivo per trovare picchi
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        HistoricalBarModel *bar = data[i];
        
        if (upFibo) {
            // Cerca nuovi massimi
            double currentHigh = bar.high > 0 ? bar.high : bar.close;
            if (currentHigh > maxPrice) {
                // 🔹 Chiudi segmento precedente se esistente
                if (maxPrice > minPrice) {
                    CGFloat segmentEndX = [self xCoordinateForDataIndex:i];
                    // ✅ TRAILING BETWEEN: Limita segmentEndX al massimo consentito
                    if (cp2Date) {
                        segmentEndX = MIN(segmentEndX, maxSegmentX);
                    }
                    
                    [self addTrailingFiboSegments:segments
                                            fromX:lastX
                                              toX:segmentEndX
                                              min:minPrice
                                              max:maxPrice
                                          uptrend:YES];
                }
                
                // Aggiorna massimo e punto di partenza
                maxPrice = currentHigh;
                lastX = [self xCoordinateForDataIndex:i];
                NSLog(@"📈 New HIGH: %.2f at index %ld", maxPrice, (long)i);
            }
        } else {
            // Cerca nuovi minimi
            double currentLow = (bar.low > 0) ? bar.low : bar.close;
            if (currentLow < minPrice && currentLow > 0.0) {
                // 🔹 Chiudi segmento precedente se esistente
                if (maxPrice > minPrice) {
                    CGFloat segmentEndX = [self xCoordinateForDataIndex:i];
                    // ✅ TRAILING BETWEEN: Limita segmentEndX al massimo consentito
                    if (cp2Date) {
                        segmentEndX = MIN(segmentEndX, maxSegmentX);
                    }
                    
                    [self addTrailingFiboSegments:segments
                                            fromX:lastX
                                              toX:segmentEndX
                                              min:minPrice
                                              max:maxPrice
                                          uptrend:NO];
                }
                
                // Aggiorna minimo e punto di partenza
                minPrice = currentLow;
                lastX = [self xCoordinateForDataIndex:i];
                NSLog(@"📉 New LOW: %.2f at index %ld", minPrice, (long)i);
            }
        }
    }
    
    // 6️⃣ Ultimo tratto
    if (maxPrice > minPrice) {
        // ✅ TRAILING BETWEEN: Usa maxSegmentX invece del bordo destro
        CGFloat finalEndX = cp2Date ? maxSegmentX : self.coordinateContext.panelBounds.size.width;
        
        [self addTrailingFiboSegments:segments
                                fromX:lastX
                                  toX:finalEndX
                                  min:minPrice
                                  max:maxPrice
                              uptrend:upFibo];
        
        if (cp2Date) {
            NSLog(@"📏 Final segment (BETWEEN): %.2f to %.2f, ends at CP2 (X: %.1f)", minPrice, maxPrice, finalEndX);
        } else {
            NSLog(@"📏 Final segment (NORMAL): %.2f to %.2f, extends to right edge", minPrice, maxPrice);
        }
    }
    
    NSLog(@"✅ TrailingFibo: Generated %lu segments", (unsigned long)segments.count);
    return segments;
}
/**
 * Helper per aggiungere i segmenti Fibonacci di un blocco di livelli
 * Adattato dal codice della vecchia app
 */
- (void)addTrailingFiboSegments:(NSMutableArray<NSDictionary *> *)segments
                          fromX:(CGFloat)fromX
                            toX:(CGFloat)toX
                            min:(double)minPrice
                            max:(double)maxPrice
                        uptrend:(BOOL)uptrend {
    
    // Calcola i livelli Fibonacci standard
    double range = maxPrice - minPrice;
    if (range <= 0) return;
    
    // Livelli per uptrend: dal max verso il basso
    // Livelli per downtrend: dal min verso l'alto
    double p100 = uptrend ? maxPrice : minPrice;
    double p618 = uptrend ? (maxPrice - range * 0.618) : (minPrice + range * 0.618);
    double p50  = uptrend ? (maxPrice - range * 0.5)   : (minPrice + range * 0.5);
    double p382 = uptrend ? (maxPrice - range * 0.382) : (minPrice + range * 0.382);
    double p236 = uptrend ? (maxPrice - range * 0.236) : (minPrice + range * 0.236);
    double p0   = uptrend ? minPrice : maxPrice;
    
    // Aggiungi segmenti con ratio per styling differenziato
    [segments addObject:@{
        @"fromX": @(fromX),
        @"toX": @(toX),
        @"price": @(p100),
        @"ratio": @(1.0),
        @"label": [NSString stringWithFormat:@"100%% (%.2f)", p100]
    }];
    
    [segments addObject:@{
        @"fromX": @(fromX),
        @"toX": @(toX),
        @"price": @(p618),
        @"ratio": @(0.618),
        @"label": [NSString stringWithFormat:@"61.8%% (%.2f)", p618]
    }];
    
    [segments addObject:@{
        @"fromX": @(fromX),
        @"toX": @(toX),
        @"price": @(p50),
        @"ratio": @(0.5),
        @"label": [NSString stringWithFormat:@"50%% (%.2f)", p50]
    }];
    
    [segments addObject:@{
        @"fromX": @(fromX),
        @"toX": @(toX),
        @"price": @(p382),
        @"ratio": @(0.382),
        @"label": [NSString stringWithFormat:@"38.2%% (%.2f)", p382]
    }];
    
    [segments addObject:@{
        @"fromX": @(fromX),
        @"toX": @(toX),
        @"price": @(p236),
        @"ratio": @(0.236),
        @"label": [NSString stringWithFormat:@"23.6%% (%.2f)", p236]
    }];
    
    [segments addObject:@{
        @"fromX": @(fromX),
        @"toX": @(toX),
        @"price": @(p0),
        @"ratio": @(0.0),
        @"label": [NSString stringWithFormat:@"0%% (%.2f)", p0]
    }];
}

#pragma mark - TrailingFibo Helper Methods

/**
 * Trova l'indice nei dati storici corrispondente a una data
 */
- (NSInteger)findDataIndexForDate:(NSDate *)targetDate {
    NSArray<HistoricalBarModel *> *data = self.coordinateContext.chartData;
    
    for (NSInteger i = 0; i < data.count; i++) {
        if ([data[i].date compare:targetDate] != NSOrderedAscending) {
            return i;
        }
    }
    return -1; // Not found
}

/**
 * Determina se cercare massimi o minimi basandosi sulla posizione del CP nel bar
 */
- (BOOL)shouldSearchForHighsFromBar:(HistoricalBarModel *)bar cpValue:(double)cpValue {
    if (!bar) return YES;
    
    // Confronta distanza del CP dal high vs low
    double distanceToHigh = fabs(bar.high - cpValue);
    double distanceToLow = fabs(bar.low - cpValue);
    
    // Se CP è più vicino al low, cerca highs (trend up)
    BOOL searchForHighs = (distanceToLow < distanceToHigh);
    
    NSLog(@"🎯 Direction analysis: CP %.2f, High %.2f, Low %.2f → Search for %@",
          cpValue, bar.high, bar.low, searchForHighs ? @"HIGHS" : @"LOWS");
    
    return searchForHighs;
}

/**
 * Ottieni coordinata X dello schermo per un indice di dati
 */
- (CGFloat)xCoordinateForDataIndex:(NSInteger)index {
    if (!self.coordinateContext || !self.coordinateContext.chartData) return 0;
    
    NSArray<HistoricalBarModel *> *data = self.coordinateContext.chartData;
    if (index < 0 || index >= data.count) return 0;
    
    // Usa il sistema di coordinate esistente del context
    CGRect bounds = self.coordinateContext.panelBounds;
    NSInteger visibleStart = self.coordinateContext.visibleStartIndex;
    NSInteger visibleEnd = self.coordinateContext.visibleEndIndex;
    
    if (index < visibleStart || index > visibleEnd) {
        // Index fuori viewport - calcola posizione teorica
        CGFloat barsPerPixel = (CGFloat)(visibleEnd - visibleStart) / bounds.size.width;
        CGFloat offsetFromStart = index - visibleStart;
        return offsetFromStart / barsPerPixel;
    }
    
    // Index nel viewport visibile
    CGFloat barWidth = bounds.size.width / (CGFloat)(visibleEnd - visibleStart + 1);
    return (index - visibleStart) * barWidth + barWidth / 2.0;
}

- (double)priceFromControlPoint:(ControlPointModel *)controlPoint {
    return controlPoint.absoluteValue;
}

#pragma mark - TrailingFibo Rendering - UPDATED

/**
 * Disegna i livelli trailing Fibonacci con styling migliorato
 */
- (void)drawTrailingFibo:(ChartObjectModel *)object {
    // Calcola i livelli usando il nuovo algoritmo
    NSArray<NSDictionary *> *fibLevels = [self calculateTrailingFibonacciForObject:object];
    
    if (fibLevels.count == 0) {
        NSLog(@"⚠️ TrailingFibo: No levels calculated for object %@", object.name);
        return;
    }
    
    BOOL isBetweenType = (object.type == ChartObjectTypeTrailingFiboBetween);
    NSLog(@"🎨 Drawing %lu trailing fibonacci levels (%@)",
          (unsigned long)fibLevels.count, isBetweenType ? @"BETWEEN" : @"NORMAL");
    
    // Applica lo stile globale dell'oggetto
    [self applyStyleForObject:object];
    
    // Disegna ogni livello Fibonacci
    for (NSDictionary *level in fibLevels) {
        double levelPrice = [level[@"price"] doubleValue];
        double ratio = [level[@"ratio"] doubleValue];
        NSString *label = level[@"label"];
        CGFloat fromX = [level[@"fromX"] floatValue];
        CGFloat toX = [level[@"toX"] floatValue];
        
        // Converti prezzo in coordinata Y dello schermo
        CGFloat y = [self yCoordinateForPrice:levelPrice];
        
        // Salta livelli fuori dal viewport
        CGRect bounds = self.coordinateContext.panelBounds;
        if (y < -10 || y > bounds.size.height + 10) {
            continue;
        }
        
        // Stile differenziato per livelli chiave
        NSBezierPath *path = [NSBezierPath bezierPath];
        
        if (ratio == 0.0 || ratio == 1.0) {
            // Livelli 0% e 100% - più evidenti
            path.lineWidth = 2.0;
            [[NSColor systemBlueColor] setStroke];
        } else if (ratio == 0.618 || ratio == 0.382) {
            // Livelli golden ratio - medi
            path.lineWidth = 1.5;
            [[NSColor systemOrangeColor] setStroke];
        } else {
            // Altri livelli - sottili
            path.lineWidth = 1.0;
            [[NSColor systemGrayColor] setStroke];
        }
        
        // ✅ TRAILING BETWEEN: Usa i segmenti calcolati invece di leftX/rightX fissi
        [path moveToPoint:NSMakePoint(fromX, y)];
        [path lineToPoint:NSMakePoint(toX, y)];
        [path stroke];
        
        // Disegna label migliorata
        // per ora non disegno label troppa confusione
       /* [self drawTrailingFiboEnhancedLabel:label
                                    atPoint:NSMakePoint(fromX + 5, y + 2)
                                 isKeyLevel:(ratio == 0.0 || ratio == 1.0 || ratio == 0.618)];
        */
    }
    
    // Disegna marker del punto di partenza
    if (object.controlPoints.count > 0) {
        NSPoint startPoint = [self screenPointFromControlPoint:object.controlPoints.firstObject];
        [self drawTrailingFiboStartMarker:startPoint];
    }
    
    // ✅ TRAILING BETWEEN: Disegna anche marker di fine se presente
    if (isBetweenType && object.controlPoints.count >= 2) {
        NSPoint endPoint = [self screenPointFromControlPoint:object.controlPoints[1]];
        [self drawTrailingFiboEndMarker:endPoint];
    }
}


/**
 * Disegna marker di fine per TrailingFiboBetween
 */
- (void)drawTrailingFiboEndMarker:(NSPoint)point {
    [[NSColor systemRedColor] setFill];
    
    NSRect markerRect = NSMakeRect(point.x - 4, point.y - 4, 8, 8);
    NSBezierPath *markerPath = [NSBezierPath bezierPathWithRect:markerRect];
    [markerPath fill];
    
    // White border
    [[NSColor whiteColor] setStroke];
    markerPath.lineWidth = 1.0;
    [markerPath stroke];
}

- (BOOL)shouldSearchForHighsFromControlPoint:(ControlPointModel *)controlPoint {
    HistoricalBarModel *bar = [self findBarForDate:controlPoint.dateAnchor];
    if (!bar) return YES; // Default fallback
    
    
    double actualPrice = controlPoint.absoluteValue;
    
    // RESTO INVARIATO
    double distanceToHigh = fabs(bar.high - actualPrice);
    double distanceToLow = fabs(bar.low - actualPrice);
    
    BOOL searchForHighs = (distanceToLow < distanceToHigh);
    
    NSLog(@"🎯 TrailingFibo Direction: %@ (CP price: %.2f, High: %.2f, Low: %.2f)",
          searchForHighs ? @"UP (search highs)" : @"DOWN (search lows)",
          actualPrice, bar.high, bar.low);
    
    return searchForHighs;
}

- (NSArray<NSDictionary *> *)calculateTrailingPeaksFromDate:(NSDate *)startDate
                                                     toDate:(NSDate *)endDate
                                              searchForHighs:(BOOL)searchForHighs {
    
    NSMutableArray<NSDictionary *> *peaks = [NSMutableArray array];
    
    // Find start index in chart data
    NSInteger startIndex = [self findBarIndexForDate:startDate];
    if (startIndex == NSNotFound) return peaks;
    
    // Find end index (or use last available data)
    NSInteger endIndex = self.coordinateContext.chartData.count - 1;
    if (endDate) {
        NSInteger boundedEndIndex = [self findBarIndexForDate:endDate];
        if (boundedEndIndex != NSNotFound && boundedEndIndex < endIndex) {
            endIndex = boundedEndIndex;
        }
    }
    
    // Initialize tracking variables
    double currentExtreme = 0.0;
    double confirmedExtreme = 0.0;
    NSDate *extremeDate = startDate;
    BOOL waitingForConfirmation = NO;
    
    // Get starting value
    HistoricalBarModel *startBar = self.coordinateContext.chartData[startIndex];
    if (searchForHighs) {
        currentExtreme = confirmedExtreme = startBar.high;
    } else {
        currentExtreme = confirmedExtreme = startBar.low;
    }
    
    // Scan through bars looking for confirmed peaks
    for (NSInteger i = startIndex + 1; i <= endIndex && i < self.coordinateContext.chartData.count; i++) {
        HistoricalBarModel *bar = self.coordinateContext.chartData[i];
        
        if (searchForHighs) {
            // Looking for highs
            if (bar.high > currentExtreme) {
                currentExtreme = bar.high;
                extremeDate = bar.date;
                waitingForConfirmation = YES;
            } else if (waitingForConfirmation && bar.high < currentExtreme) {
                // Peak confirmed! Price started declining
                if (currentExtreme > confirmedExtreme) {
                    confirmedExtreme = currentExtreme;
                    
                    [peaks addObject:@{
                        @"date": extremeDate,
                        @"price": @(confirmedExtreme),
                        @"type": @"high",
                        @"barIndex": @(i-1)
                    }];
                    
                    NSLog(@"📈 TrailingFibo: New HIGH peak confirmed at %.2f on %@",
                          confirmedExtreme, extremeDate);
                }
                waitingForConfirmation = NO;
            }
        } else {
            // Looking for lows
            if (bar.low < currentExtreme) {
                currentExtreme = bar.low;
                extremeDate = bar.date;
                waitingForConfirmation = YES;
            } else if (waitingForConfirmation && bar.low > currentExtreme) {
                // Trough confirmed! Price started rising
                if (currentExtreme < confirmedExtreme) {
                    confirmedExtreme = currentExtreme;
                    
                    [peaks addObject:@{
                        @"date": extremeDate,
                        @"price": @(confirmedExtreme),
                        @"type": @"low",
                        @"barIndex": @(i-1)
                    }];
                    
                    NSLog(@"📉 TrailingFibo: New LOW peak confirmed at %.2f on %@",
                          confirmedExtreme, extremeDate);
                }
                waitingForConfirmation = NO;
            }
        }
    }
    
    NSLog(@"🎯 TrailingFibo: Found %lu confirmed peaks", (unsigned long)peaks.count);
    return [peaks copy];
}

- (NSArray<NSDictionary *> *)calculateFibonacciLevelsFromPeaks:(NSArray<NSDictionary *> *)peaks
                                               startControlPoint:(ControlPointModel *)startCP {
    
    NSMutableArray<NSDictionary *> *fibLevels = [NSMutableArray array];
    
    if (peaks.count == 0) return fibLevels;
    
    // Get starting price (CP1)
    HistoricalBarModel *startBar = [self findBarForDate:startCP.dateAnchor];
    if (!startBar) return fibLevels;
    
    double startIndicatorValue = [self getIndicatorValue:startCP.indicatorRef fromBar:startBar];
    double cp1Price = startCP.absoluteValue;
    
    // Get latest extreme price (CP2)
    NSDictionary *lastPeak = peaks.lastObject;
    double cp2Price = [lastPeak[@"price"] doubleValue];
    NSDate *extremeDate = lastPeak[@"date"];
    
    // ✅ FIBONACCI RETRACEMENT CORRETTO
    // Esempio: CP1=1, CP2=100, Range=99
    // 23.6% retracement = CP2 - (23.6% * range) = 100 - (0.236 * 99) = 100 - 23.364 = 76.636
    // Quindi 23.6% STA VICINO AL CP2 come deve essere!
    
    double priceRange = cp2Price - cp1Price;  // Range totale
    
    // Fibonacci retracements (standard + extensions)
    NSArray *fibRatios = @[@0.0, @0.236, @0.382, @0.5, @0.618, @0.786, @1.0, @1.272, @1.414, @1.618, @2.618, @4.236];
    NSArray *fibLabels = @[@"0%", @"23.6%", @"38.2%", @"50%", @"61.8%", @"78.6%", @"100%", @"127.2%", @"141.4%", @"161.8%", @"261.8%", @"423.6%"];
    
    for (NSUInteger i = 0; i < fibRatios.count; i++) {
        double ratio = [fibRatios[i] doubleValue];
        
        // ✅ FORMULA CORRETTA per retracements e extensions
        double levelPrice;
        if (ratio <= 1.0) {
            // RETRACEMENTS (0% - 100%): da CP2 verso CP1
            levelPrice = cp2Price - (ratio * priceRange);
        } else {
            // EXTENSIONS (>100%): oltre CP2
            levelPrice = cp2Price + ((ratio - 1.0) * priceRange);
        }
        
        // Label con % e valore
        NSString *percentageLabel = fibLabels[i];
        NSString *fullLabel = [NSString stringWithFormat:@"%@ (%.2f)", percentageLabel, levelPrice];
        
        [fibLevels addObject:@{
            @"ratio": fibRatios[i],
            @"label": fullLabel,
            @"price": @(levelPrice),
            @"isExtension": @(ratio > 1.0),
            @"startDate": startCP.dateAnchor,
            @"endDate": extremeDate ?: startCP.dateAnchor
        }];
        
        NSLog(@"📊 Fibo %@: %.2f (CP1=%.2f, CP2=%.2f, Range=%.2f)",
              percentageLabel, levelPrice, cp1Price, cp2Price, priceRange);
    }
    
    return [fibLevels copy];
}
- (NSInteger)findBarIndexForDate:(NSDate *)date {
    for (NSInteger i = 0; i < self.coordinateContext.chartData.count; i++) {
        HistoricalBarModel *bar = self.coordinateContext.chartData[i];
        if ([bar.date isEqualToDate:date] || [bar.date compare:date] == NSOrderedDescending) {
            return i;
        }
    }
    return NSNotFound;
}

- (HistoricalBarModel *)findBarForDate:(NSDate *)date {
    for (HistoricalBarModel *bar in self.coordinateContext.chartData) {
        if ([bar.date isEqualToDate:date]) {
            return bar;
        }
    }
    
    // If exact match not found, find closest bar
    HistoricalBarModel *closestBar = nil;
    NSTimeInterval smallestDiff = CGFLOAT_MAX;
    
    for (HistoricalBarModel *bar in self.coordinateContext.chartData) {
        NSTimeInterval diff = fabs([bar.date timeIntervalSinceDate:date]);
        if (diff < smallestDiff) {
            smallestDiff = diff;
            closestBar = bar;
        }
    }
    
    return closestBar;
}

- (double)getIndicatorValue:(NSString *)indicatorRef fromBar:(HistoricalBarModel *)bar {
    if (!bar || !indicatorRef) return 0.0;
    
    if ([indicatorRef isEqualToString:@"open"]) {
        return bar.open;
    } else if ([indicatorRef isEqualToString:@"high"]) {
        return bar.high;
    } else if ([indicatorRef isEqualToString:@"low"]) {
        return bar.low;
    } else if ([indicatorRef isEqualToString:@"close"]) {
        return bar.close;
    }
    
    // Default to close if unknown indicator
    return bar.close;
}



- (void)drawTargetLabels:(NSPoint)buyPoint stopPoint:(NSPoint)stopPoint targetPoint:(NSPoint)targetPoint
                buyPrice:(double)buyPrice stopPrice:(double)stopPrice targetPrice:(double)targetPrice
            stopLossPercent:(double)stopLoss targetPercent:(double)target rrr:(double)rrr {
    
    // Setup text attributes
    NSDictionary *textAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor labelColor],
        NSBackgroundColorAttributeName: [NSColor controlBackgroundColor]
    };
    
    // Buy label
    NSString *buyText = [NSString stringWithFormat:@"BUY: $%.2f", buyPrice];
    [buyText drawAtPoint:NSMakePoint(buyPoint.x + 10, buyPoint.y - 5) withAttributes:textAttributes];
    
    // Stop label
    NSString *stopText = [NSString stringWithFormat:@"STOP: $%.2f (-%.1f%%)", stopPrice, fabs(stopLoss)];
    [stopText drawAtPoint:NSMakePoint(stopPoint.x + 10, stopPoint.y - 5) withAttributes:textAttributes];
    
    // Target label
    NSString *targetText = [NSString stringWithFormat:@"TARGET: $%.2f (+%.1f%%) RRR: %.1f", targetPrice, target, rrr];
    [targetText drawAtPoint:NSMakePoint(targetPoint.x + 10, targetPoint.y - 5) withAttributes:textAttributes];
}


- (void)setObjectsVisible:(BOOL)visible {
    self.objectsLayer.hidden = !visible;
    self.objectsEditingLayer.hidden = !visible;
}

- (BOOL)areObjectsVisible {
    return !self.objectsLayer.hidden;
}

#pragma mark - Unified X Coordinate Calculation

- (CGFloat)xCoordinateForBarIndex:(NSInteger)barIndex {
    // ✅ DEPRECATED: Usa coordinate context unificato
    return [self.coordinateContext screenXForBarIndex:barIndex];
}

- (NSInteger)barIndexForXCoordinate:(CGFloat)x {
    // ✅ DEPRECATED: Usa coordinate context unificato
    return [self.coordinateContext barIndexForScreenX:x];
}

- (CGFloat)xCoordinateForDate:(NSDate *)targetDate {
    // ✅ DEPRECATED: Usa coordinate context unificato
    return [self.coordinateContext screenXForDate:targetDate];
}

// Aggiungi questi metodi a ChartObjectRenderer.m

#pragma mark - NEW: Snap Implementation


// Sostituisci il metodo controlPointFromScreenPoint:indicatorRef: esistente
- (ControlPointModel *)controlPointFromScreenPoint:(NSPoint)screenPoint
                                       indicatorRef:(NSString *)indicatorRef {
    if (!self.coordinateContext.chartData) {
        return nil;
    }
    
    // 🧲 SNAP: Controlla se snap è attivo
    CGFloat snapIntensity = [[NSUserDefaults standardUserDefaults] floatForKey:@"ChartSnapIntensity"];
    
    if (snapIntensity == 0.0) {
        // ✅ SNAP DISATTIVATO: usa logica originale (esatta)
        return [self controlPointFromScreenPointWithoutSnap:screenPoint indicatorRef:indicatorRef];
    } else {
        // 🧲 SNAP ATTIVATO: usa logica snap
        return [self controlPointFromScreenPointWithSnap:screenPoint
                                             indicatorRef:indicatorRef
                                            snapIntensity:snapIntensity];
    }
}

// Logica originale senza snap (esatta come prima)
- (ControlPointModel *)controlPointFromScreenPointWithoutSnap:(NSPoint)screenPoint
                                                  indicatorRef:(NSString *)indicatorRef {
    // X coordinate conversion (usa metodo corretto)
    NSInteger barIndex = [self barIndexForXCoordinate:screenPoint.x];
    if (barIndex < 0 || barIndex >= self.coordinateContext.chartData.count) {
        return nil;
    }
    
    HistoricalBarModel *targetBar = self.coordinateContext.chartData[barIndex];
    NSDate *dateAnchor = targetBar.date;
    
    // Y coordinate → valore assoluto diretto (NESSUNO SNAP)
    double absoluteValue = [self.coordinateContext valueForScreenY:screenPoint.y];
    return [ControlPointModel pointWithDate:dateAnchor absoluteValue:absoluteValue indicator:indicatorRef];
}

// NUOVA logica con snap ai valori OHLC
- (ControlPointModel *)controlPointFromScreenPointWithSnap:(NSPoint)screenPoint
                                               indicatorRef:(NSString *)indicatorRef
                                              snapIntensity:(CGFloat)snapIntensity {
    
    // 1. Trova candela target
    NSInteger barIndex = [self barIndexForXCoordinate:screenPoint.x];
    if (barIndex < 0 || barIndex >= self.coordinateContext.chartData.count) {
        return nil;
    }
    
    HistoricalBarModel *targetBar = self.coordinateContext.chartData[barIndex];
    NSDate *dateAnchor = targetBar.date;
    
    // 2. Converti Y in prezzo senza snap
    double requestedPrice = [self.coordinateContext valueForScreenY:screenPoint.y];
    
    // 3. Determina tipo di snap basato su zoom e chart type
    SnapType snapType = [self determineSnapTypeForCurrentContext];
    
    // 4. Se snap type è None, ritorna valore esatto
    if (snapType == SnapTypeNone) {
        return [ControlPointModel pointWithDate:dateAnchor absoluteValue:requestedPrice indicator:indicatorRef];
    }
    
    // 5. Calcola tolleranza snap basata su intensità
    CGFloat snapTolerance = [self calculateSnapToleranceForIntensity:snapIntensity];
    
    // 6. Trova il miglior valore snap nella candela
    double snappedValue = [self findBestSnapValue:requestedPrice
                                          fromBar:targetBar
                                         snapType:snapType
                                        tolerance:snapTolerance];
    
    NSLog(@"🧲 SNAP: requested=%.4f, snapped=%.4f, type=%ld, tolerance=%.1f",
          requestedPrice, snappedValue, (long)snapType, snapTolerance);
    
    return [ControlPointModel pointWithDate:dateAnchor absoluteValue:snappedValue indicator:indicatorRef];
}

- (SnapType)determineSnapTypeForCurrentContext {
    // Calcola larghezza visibile di una candela in pixel
    NSInteger visibleBars = self.coordinateContext.visibleEndIndex - self.coordinateContext.visibleStartIndex;
    if (visibleBars <= 0) return SnapTypeNone;
    
    CGFloat barWidth = (self.coordinateContext.panelBounds.size.width - 20) / visibleBars;
    
    // Verifica se è un chart lineare (usa currentSymbol per determinare tipo di indicator)
    // Per ora assumiamo che sia sempre OHLC, ma potremmo espandere questa logica
    BOOL isLinearChart = NO; // TODO: Implementare controllo tipo chart
    
    if (isLinearChart) {
        return SnapTypeClose;
    } else if (barWidth < 6.0) {
        // Zoom molto compatto: snap solo a High/Low (come nel vecchio codice)
        return SnapTypeHL;
    } else {
        // Zoom normale: snap a tutti i valori OHLC
        return SnapTypeOHLC;
    }
}

- (CGFloat)calculateSnapToleranceForIntensity:(CGFloat)intensity {
    // Intensità 0-10 → tolleranza in pixel
    // Intensità alta = tolleranza molto più ampia (snap super aggressivo)
    CGFloat maxTolerancePixels = 80.0; // AUMENTATO: Tolleranza massima molto ampia
    CGFloat minTolerancePixels = 5.0;  // Minima tolleranza
    
    // Scala NON-LINEARE per rendere intensità 8-10 molto aggressive
    CGFloat normalizedIntensity = intensity / 10.0;
    
    // Usa una curva quadratica per amplificare le intensità alte
    CGFloat curvedIntensity = normalizedIntensity * normalizedIntensity;
    
    CGFloat tolerance = minTolerancePixels + (curvedIntensity * (maxTolerancePixels - minTolerancePixels));
    
    NSLog(@"🧲 SNAP TOLERANCE: intensity=%.0f → tolerance=%.1fpx (curved=%.2f)",
          intensity, tolerance, curvedIntensity);
    
    return tolerance;
}

- (double)findBestSnapValue:(double)requestedPrice
                    fromBar:(HistoricalBarModel *)bar
                   snapType:(SnapType)snapType
                  tolerance:(CGFloat)tolerancePixels {
    
    // Array di valori candidati per snap
    NSMutableArray<NSNumber *> *candidates = [NSMutableArray array];
    
    switch (snapType) {
        case SnapTypeOHLC:
            [candidates addObject:@(bar.open)];
            [candidates addObject:@(bar.high)];
            [candidates addObject:@(bar.low)];
            [candidates addObject:@(bar.close)];
            break;
            
        case SnapTypeHL:
            [candidates addObject:@(bar.high)];
            [candidates addObject:@(bar.low)];
            break;
            
        case SnapTypeClose:
            [candidates addObject:@(bar.close)];
            break;
            
        case SnapTypeNone:
        default:
            return requestedPrice; // No snap
    }
    
    // Converti tolleranza da pixel a unità di prezzo
    double tolerancePrice = [self pixelToleranceToPriceTolerance:tolerancePixels];
    
    // 🧲 NUOVO: Per intensità alte, espandi la ricerca alle candele vicine
    if (tolerancePixels > 40.0) { // Intensità ~7-10
        [self addNearbyBarsToSnapCandidates:candidates
                                 sourceBar:bar
                                  snapType:snapType
                             tolerancePrice:tolerancePrice];
    }
    
    // Trova il candidato più vicino dentro la tolleranza
    double bestValue = requestedPrice;
    double smallestDelta = tolerancePrice + 1; // Inizia fuori tolleranza
    
    for (NSNumber *candidate in candidates) {
        double candidateValue = candidate.doubleValue;
        double delta = fabs(requestedPrice - candidateValue);
        
        if (delta < smallestDelta && delta <= tolerancePrice) {
            bestValue = candidateValue;
            smallestDelta = delta;
        }
    }
    
    return bestValue;
}

// NUOVO: Aggiunge candele vicine per snap super-aggressivo
- (void)addNearbyBarsToSnapCandidates:(NSMutableArray<NSNumber *> *)candidates
                             sourceBar:(HistoricalBarModel *)sourceBar
                              snapType:(SnapType)snapType
                         tolerancePrice:(double)tolerancePrice {
    
    // Trova l'indice della candela source
    NSInteger sourceIndex = [self.coordinateContext.chartData indexOfObject:sourceBar];
    if (sourceIndex == NSNotFound) return;
    
    // Cerca nelle 3 candele precedenti e successive
    NSInteger searchRange = 3;
    NSInteger startIndex = MAX(0, sourceIndex - searchRange);
    NSInteger endIndex = MIN(self.coordinateContext.chartData.count - 1, sourceIndex + searchRange);
    
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        if (i == sourceIndex) continue; // Skip source bar
        
        HistoricalBarModel *nearbyBar = self.coordinateContext.chartData[i];
        
        switch (snapType) {
            case SnapTypeOHLC:
                [candidates addObject:@(nearbyBar.open)];
                [candidates addObject:@(nearbyBar.high)];
                [candidates addObject:@(nearbyBar.low)];
                [candidates addObject:@(nearbyBar.close)];
                break;
                
            case SnapTypeHL:
                [candidates addObject:@(nearbyBar.high)];
                [candidates addObject:@(nearbyBar.low)];
                break;
                
            case SnapTypeClose:
                [candidates addObject:@(nearbyBar.close)];
                break;
                
            default:
                break;
        }
    }
    
    NSLog(@"🧲 EXPANDED SEARCH: Added %lu nearby bars for super-aggressive snap",
          (unsigned long)(endIndex - startIndex));
}

- (double)pixelToleranceToPriceTolerance:(CGFloat)pixels {
    // Converti pixel in unità di prezzo basandosi sul range Y corrente
    double yRange = self.coordinateContext.yRangeMax - self.coordinateContext.yRangeMin;
    CGFloat panelHeight = self.coordinateContext.panelBounds.size.height;
    
    if (panelHeight <= 0) return 0.01; // Fallback
    
    return (pixels / panelHeight) * yRange;
}

// Aggiorna anche updateCurrentCPCoordinates per usare snap
- (void)updateCurrentCPCoordinates:(NSPoint)screenPoint {
    if (!self.currentCPSelected) return;
    
    // 🧲 USA IL NUOVO METODO CON SNAP
    ControlPointModel *newCP = [self controlPointFromScreenPoint:screenPoint
                                                     indicatorRef:self.currentCPSelected.indicatorRef];
    if (!newCP) return;
    
    // Aggiorna absoluteValue con snap applicato
    self.currentCPSelected.dateAnchor = newCP.dateAnchor;
    self.currentCPSelected.absoluteValue = newCP.absoluteValue;
    
    // Resto invariato
    if (self.isInCreationMode) {
        [self createEditingObjectFromTempCPs];
    }
    
    [self invalidateEditingLayer];
    
    NSLog(@"🎯 Updated currentCP coordinates: %.4f (with snap)", self.currentCPSelected.absoluteValue);
}


@end
