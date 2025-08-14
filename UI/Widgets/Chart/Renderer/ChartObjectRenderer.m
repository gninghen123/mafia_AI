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

#pragma mark - Coordinate Context Implementation

@implementation ChartCoordinateContext
@end

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
        return NSMakePoint(-9999, -9999); // Coordinate invalide
    }
    
    // Step 1: Find exact bar in data
    HistoricalBarModel *targetBar = [self findBarForDate:controlPoint.dateAnchor];
    
    NSPoint screenPoint = NSMakePoint(-9999, -9999);
    
    if (targetBar) {
        // Barra trovata - calcolo preciso
        NSInteger barIndex = [self findBarIndexForDate:controlPoint.dateAnchor];
        if (barIndex != NSNotFound) {
            screenPoint.x = [self xCoordinateForBarIndex:barIndex];
        }
        
        // Y coordinate dal prezzo reale
        double indicatorValue = [self getIndicatorValue:controlPoint.indicatorRef fromBar:targetBar];
        if (indicatorValue > 0.0) {
            double actualPrice = indicatorValue * (1.0 + controlPoint.valuePercent / 100.0);
            
            if (self.coordinateContext.yRangeMax != self.coordinateContext.yRangeMin) {
                double normalizedPrice = (actualPrice - self.coordinateContext.yRangeMin) /
                                        (self.coordinateContext.yRangeMax - self.coordinateContext.yRangeMin);
                screenPoint.y = 10 + normalizedPrice * (self.coordinateContext.panelBounds.size.height - 20);
            }
        }
    } else {
        // ✅ BARRA NON TROVATA - USA ESTRAPOLAZIONE SMART
        screenPoint.x = [self xCoordinateForDate:controlPoint.dateAnchor];
        
        // Per Y, non inventare prezzi - skip questo CP
        return NSMakePoint(-9999, -9999);
    }
    
    return screenPoint;
}




- (ControlPointModel *)controlPointFromScreenPoint:(NSPoint)screenPoint
                                       indicatorRef:(NSString *)indicatorRef {
    if (!self.coordinateContext.chartData) {
        return nil;
    }
    
    // ✅ USA IL NUOVO METODO UNIFICATO
    NSInteger barIndex = [self barIndexForXCoordinate:screenPoint.x];
    
    if (barIndex < 0 || barIndex >= self.coordinateContext.chartData.count) {
        return nil;
    }
    
    // Step 2: Get the bar and date
    HistoricalBarModel *targetBar = self.coordinateContext.chartData[barIndex];
    NSDate *dateAnchor = targetBar.date;
    
    // Step 3: Convert screen Y to price (INVARIATO)
    double normalizedY = (screenPoint.y - 10) / (self.coordinateContext.panelBounds.size.height - 20);
    double screenPrice = self.coordinateContext.yRangeMin +
                        normalizedY * (self.coordinateContext.yRangeMax - self.coordinateContext.yRangeMin);
    
    // Step 4: Get indicator value and calculate percentage
    double indicatorValue = [self getIndicatorValue:indicatorRef fromBar:targetBar];
    if (indicatorValue == 0.0) {
        return nil;
    }
    
    double valuePercent = ((screenPrice - indicatorValue) / indicatorValue) * 100.0;
    
    // Step 5: Create control point
    return [ControlPointModel pointWithDate:dateAnchor
                                valuePercent:valuePercent
                                   indicator:indicatorRef];
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
            
        default:
            NSLog(@"⚠️ ChartObjectRenderer: Unknown object type %ld", (long)object.type);
            break;
    }
}

- (void)drawTrailingFibo:(ChartObjectModel *)object {
    // Calculate fibonacci levels using the algorithm
    NSArray<NSDictionary *> *fibLevels = [self calculateTrailingFibonacciForObject:object];
    
    if (fibLevels.count == 0) {
        NSLog(@"⚠️ TrailingFibo: No levels calculated for object %@", object.name);
        return;
    }
    
    [self applyStyleForObject:object];
    
    // Get viewport bounds for line extension
    CGFloat leftX = 0;
    CGFloat rightX = self.coordinateContext.panelBounds.size.width;
    
    // For TrailingFiboBetween, limit right extension to CP2
    if (object.type == ChartObjectTypeTrailingFiboBetween && object.controlPoints.count >= 2) {
        NSPoint cp2Screen = [self screenPointFromControlPoint:object.controlPoints[1]];
        rightX = cp2Screen.x;
    }
    
    // Draw each fibonacci level
    for (NSDictionary *level in fibLevels) {
        double levelPrice = [level[@"price"] doubleValue];
        double ratio = [level[@"ratio"] doubleValue];
        NSString *label = level[@"label"];  // Ora include % e valore
        
        // Convert price to screen Y coordinate
        CGFloat y = [self yCoordinateForPrice:levelPrice];
        
        // Skip levels outside viewport
        if (y < -10 || y > self.coordinateContext.panelBounds.size.height + 10) {
            continue;
        }
        
        // Different line styles for different levels
        NSBezierPath *path = [NSBezierPath bezierPath];
        
        if (ratio == 0.0 || ratio == 1.0) {
            // 0% and 100% levels - solid and thicker
            path.lineWidth = 2.0;
            [[NSColor systemBlueColor] setStroke];
        } else {
            // Intermediate levels - thinner
            path.lineWidth = 1.0;
            [[NSColor systemOrangeColor] setStroke];
        }
        
        // Draw the line
        [path moveToPoint:NSMakePoint(leftX, y)];
        [path lineToPoint:NSMakePoint(rightX, y)];
        [path stroke];
        
        // ✅ MIGLIORE RENDERING LABEL: sulla sinistra con % e valore
        [self drawTrailingFiboEnhancedLabel:label
                                    atPoint:NSMakePoint(leftX + 5, y + 2)
                                    isKeyLevel:(ratio == 0.0 || ratio == 1.0)];
    }
    
    // Draw start point marker
    if (object.controlPoints.count > 0) {
        NSPoint startPoint = [self screenPointFromControlPoint:object.controlPoints.firstObject];
        [self drawTrailingFiboStartMarker:startPoint];
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

- (CGFloat)yCoordinateForPrice:(double)price {
    if (self.coordinateContext.yRangeMax == self.coordinateContext.yRangeMin) {
        return self.coordinateContext.panelBounds.size.height / 2;
    }
    
    double normalizedPrice = (price - self.coordinateContext.yRangeMin) /
                            (self.coordinateContext.yRangeMax - self.coordinateContext.yRangeMin);
    return 10 + normalizedPrice * (self.coordinateContext.panelBounds.size.height - 20);
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
        [levelPath moveToPoint:NSMakePoint(0, fibY)];
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
                         atPoint:NSMakePoint(panelWidth - 100, fibY)
                      isKeyLevel:(ratio == 0.0 || ratio == 1.0)
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
    // Inverte la conversione di yCoordinateForPrice
    CGFloat panelHeight = self.coordinateContext.panelBounds.size.height;
    CGFloat normalizedY = (panelHeight - screenY - 10) / (panelHeight - 20);
    
    return self.coordinateContext.yRangeMin +
           normalizedY * (self.coordinateContext.yRangeMax - self.coordinateContext.yRangeMin);
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

// 4. ChartObjectRenderer.m - Implementazione drawTargetPrice

// ✅ CORREZIONE: Modifica solo il metodo drawTargetPrice esistente
// Riutilizza tutti i metodi già presenti nel codice

// ✅ CORREZIONE: Modifica solo il metodo drawTargetPrice esistente
// Riutilizza tutti i metodi già presenti nel codice

- (void)drawTargetPrice:(ChartObjectModel *)object {
    // ✅ VERIFICA: Target deve avere esattamente 3 CP (buy, stop, target)
    if (object.controlPoints.count < 3) {
        // Se non completo, disegna solo le linee disponibili come prima
        if (object.controlPoints.count >= 1) {
            ControlPointModel *cp = object.controlPoints.firstObject;
            NSPoint screenPoint = [self screenPointFromControlPoint:cp];
            
            [self applyStyleForObject:object];
            
            NSBezierPath *path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(0, screenPoint.y)];
            [path lineToPoint:NSMakePoint(self.coordinateContext.panelBounds.size.width, screenPoint.y)];
            [self strokePath:path withStyle:object.style];
            
            CGFloat targetPrice = [self priceFromScreenY:screenPoint.y];
            NSString *labelText = [NSString stringWithFormat:@"Target: %.2f", targetPrice];
            [self drawTargetLabel:labelText atPoint:NSMakePoint(10, screenPoint.y) color:object.style.color];
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
- (void)drawTargetLabel:(NSString *)text atPoint:(NSPoint)point color:(NSColor *)textColor {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:24],
        NSForegroundColorAttributeName: textColor,
        NSBackgroundColorAttributeName: [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.9]
    };
    
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    NSSize textSize = [attributedText size];
    
    NSRect labelRect = NSMakeRect(point.x, point.y - textSize.height/2 - 2,
                                  textSize.width + 8, textSize.height + 4);
    
    // Draw background
    [[NSColor controlBackgroundColor] setFill];
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:labelRect xRadius:3 yRadius:3];
    [bgPath fill];
    
    // Draw border
    [textColor setStroke];
    bgPath.lineWidth = 1.0;
    [bgPath stroke];
    
    // Draw text
    [attributedText drawAtPoint:NSMakePoint(point.x + 4, point.y - textSize.height/2)];
}

// Helper per label semplici (backward compatibility)
- (void)drawTargetLabel:(NSString *)text
                atPoint:(NSPoint)point
                  color:(NSColor *)color
                   size:(CGFloat)size {
    [self drawTargetEnhancedLabel:text atPoint:point color:color size:size isBold:NO];
}

// Helper per punti target
- (void)drawTargetPoint:(NSPoint)point color:(NSColor *)color label:(NSString *)label {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    // Punto più grande
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(point.x - 5, point.y - 5, 10, 10));
    
    // Bordo bianco
    CGContextSetStrokeColorWithColor(ctx, [NSColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextStrokeEllipseInRect(ctx, CGRectMake(point.x - 5, point.y - 5, 10, 10));
    
    CGContextRestoreGState(ctx);
    
    // Label
    if (label) {
        [self drawTargetEnhancedLabel:label
                              atPoint:NSMakePoint(point.x + 15, point.y)
                                color:color
                                 size:13
                               isBold:YES];
    }
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

- (void)drawTargetLine:(CGFloat)y startX:(CGFloat)startX endX:(CGFloat)endX
                 color:(NSColor *)color width:(CGFloat)width {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, width);
    CGContextMoveToPoint(ctx, startX, y);
    CGContextAddLineToPoint(ctx, endX, y);
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
}

// ✅ NUOVO: Line con spessore variabile
- (void)drawTargetLine:(CGFloat)y color:(NSColor *)color width:(CGFloat)width {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGFloat panelWidth = self.coordinateContext.panelBounds.size.width;
    
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, width);
    CGContextMoveToPoint(ctx, 0, y);
    CGContextAddLineToPoint(ctx, panelWidth, y);
    CGContextStrokePath(ctx);
}

// ✅ NUOVO: Label grandi e migliorate
- (void)drawTargetEnhancedLabel:(NSString *)text
                        atPoint:(NSPoint)point
                          color:(NSColor *)textColor
                           size:(CGFloat)fontSize
                         isBold:(BOOL)isBold {
    
    NSFont *font = isBold ?
        [NSFont boldSystemFontOfSize:fontSize] :
        [NSFont systemFontOfSize:fontSize];
    
    // ✅ Background con alpha controllato
    NSColor *bgColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.95];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor,
        NSBackgroundColorAttributeName: bgColor
    };
    
    NSAttributedString *attributedText = [[NSAttributedString alloc]
                                         initWithString:text
                                         attributes:attributes];
    
    NSSize textSize = [attributedText size];
    NSRect labelRect = NSMakeRect(point.x - 2,
                                 point.y - textSize.height/2 - 2,
                                 textSize.width + 8,
                                 textSize.height + 4);
    
    // ✅ Background con alpha fisso
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    CGContextSetFillColorWithColor(ctx, bgColor.CGColor);
    CGContextFillRect(ctx, labelRect);
    
    // Bordo sottile del colore del testo
    CGContextSetStrokeColorWithColor(ctx, textColor.CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextStrokeRect(ctx, labelRect);
    CGContextRestoreGState(ctx);
    
    // Testo centrato
    [attributedText drawAtPoint:NSMakePoint(point.x + 2, point.y - textSize.height/2)];
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
        [self notifyObjectCreationCompleted];
    }
}

- (BOOL)needsMoreControlPointsForCreation {
    switch (self.creationObjectType) {
        case ChartObjectTypeHorizontalLine:
            // ✅ Questi oggetti hanno bisogno di solo 1 CP
            return self.tempControlPoints.count < 1;
            
        case ChartObjectTypeTrendline:
        case ChartObjectTypeFibonacci:
        case ChartObjectTypeRectangle:
        case ChartObjectTypeCircle:
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

- (void)updateCurrentCPCoordinates:(NSPoint)screenPoint {
    if (!self.currentCPSelected) return;
    
    // Convert screen point back to control point coordinates
    ControlPointModel *newCP = [self controlPointFromScreenPoint:screenPoint
                                                     indicatorRef:self.currentCPSelected.indicatorRef];
    if (!newCP) return;
    
    // Update the current selected CP coordinates
    self.currentCPSelected.dateAnchor = newCP.dateAnchor;
    self.currentCPSelected.valuePercent = newCP.valuePercent;
    
    // NUOVO: Se in creation mode, update editing object
    if (self.isInCreationMode) {
        [self createEditingObjectFromTempCPs];
    }
    
    // Force redraw editing layer
    [self invalidateEditingLayer];
    
    NSLog(@"🎯 Updated currentCP coordinates: %.2f%%", self.currentCPSelected.valuePercent);
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
    
    // Create final object in active layer del MODEL
    ChartLayerModel *activeLayer = self.objectsManager.activeLayer;
    if (!activeLayer) {
        activeLayer = [self.objectsManager createLayerWithName:@"Drawing"];
    }
    
    // ✅ Crea oggetto SENZA salvare
    ChartObjectModel *finalObject = [self.objectsManager createObjectOfType:self.creationObjectType
                                                                     inLayer:activeLayer];
    
    // Copy control points from temp to final
    for (ControlPointModel *cp in self.tempControlPoints) {
        [finalObject addControlPoint:cp];
    }
    
    // ✅ SALVA SOLO QUI - quando l'oggetto è completamente configurato
    [self.objectsManager saveToDataHub];
    
    // Cleanup
    [self cancelCreatingObject];
    [self invalidateObjectsLayer];
    
    NSLog(@"✅ Created and saved complete object '%@' in layer '%@'", finalObject.name, activeLayer.name);
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

- (NSArray<NSDictionary *> *)calculateTrailingFibonacciForObject:(ChartObjectModel *)object {
    if (object.controlPoints.count < 1) return @[];
    
    ControlPointModel *startCP = object.controlPoints.firstObject;
    NSDate *startDate = startCP.dateAnchor;
    NSDate *endDate = nil;
    
    // Determine end date for TrailingFiboBetween
    if (object.type == ChartObjectTypeTrailingFiboBetween && object.controlPoints.count >= 2) {
        endDate = object.controlPoints[1].dateAnchor;
    }
    
    // Auto-detect direction based on CP1 position
    BOOL searchForHighs = [self shouldSearchForHighsFromControlPoint:startCP];
    
    // Calculate trailing peaks
    NSArray<NSDictionary *> *peaks = [self calculateTrailingPeaksFromDate:startDate
                                                                   toDate:endDate
                                                            searchForHighs:searchForHighs];
    
    // Convert peaks to fibonacci levels
    return [self calculateFibonacciLevelsFromPeaks:peaks startControlPoint:startCP];
}

- (BOOL)shouldSearchForHighsFromControlPoint:(ControlPointModel *)controlPoint {
    // Find the bar for this control point
    HistoricalBarModel *bar = [self findBarForDate:controlPoint.dateAnchor];
    if (!bar) return YES; // Default fallback
    
    // Calculate actual price at control point
    double indicatorValue = [self getIndicatorValue:controlPoint.indicatorRef fromBar:bar];
    double actualPrice = indicatorValue * (1.0 + controlPoint.valuePercent / 100.0);
    
    // Compare distance to high vs low
    double distanceToHigh = fabs(bar.high - actualPrice);
    double distanceToLow = fabs(bar.low - actualPrice);
    
    // If CP1 is closer to low, search for highs (trend up)
    BOOL searchForHighs = (distanceToLow < distanceToHigh);
    
    NSLog(@"🎯 TrailingFibo Direction: %@ (CP1 price: %.2f, High: %.2f, Low: %.2f)",
          searchForHighs ? @"SEARCH HIGHS" : @"SEARCH LOWS", actualPrice, bar.high, bar.low);
    
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
    double cp1Price = startIndicatorValue * (1.0 + startCP.valuePercent / 100.0);
    
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


- (double)priceFromControlPoint:(ControlPointModel *)cp {
    // Trova la barra corrispondente alla data del CP
    for (HistoricalBarModel *bar in self.coordinateContext.chartData) {
        if ([bar.date isEqualToDate:cp.dateAnchor]) {
            double basePrice = [self getIndicatorValue:cp.indicatorRef fromBar:bar];
            return basePrice * (1.0 + cp.valuePercent / 100.0);
        }
    }
    
    // Fallback: calcola prezzo dal range Y
    NSPoint screenPoint = [self screenPointFromControlPoint:cp];
    double normalizedY = (screenPoint.y - 10) / (self.coordinateContext.panelBounds.size.height - 20);
    return self.coordinateContext.yRangeMin + normalizedY * (self.coordinateContext.yRangeMax - self.coordinateContext.yRangeMin);
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

// NUOVO: Metodo centralizzato che usa le preferenze del ChartWidget
- (CGFloat)xCoordinateForBarIndex:(NSInteger)barIndex {
    if (barIndex < self.coordinateContext.visibleStartIndex ||
        barIndex >= self.coordinateContext.visibleEndIndex) {
        
        // Control point fuori viewport - calcola comunque la posizione
        // (può risultare in coordinate negative o oltre la larghezza)
    }
    
    NSInteger visibleBars = self.coordinateContext.visibleEndIndex - self.coordinateContext.visibleStartIndex;
    if (visibleBars <= 0) return 0;
    
    CGFloat totalWidth = self.coordinateContext.panelBounds.size.width - 20; // Margini
    CGFloat barWidth = totalWidth / visibleBars;
    CGFloat barSpacing = MAX(1, barWidth * 0.1);
    
    NSInteger relativeIndex = barIndex - self.coordinateContext.visibleStartIndex;
    
    // ✅ STESSO CALCOLO del drawCandlesticks
    return 10 + (relativeIndex * barWidth);  // Bordo sinistro della barra
}

- (NSInteger)barIndexForXCoordinate:(CGFloat)x {
    NSInteger visibleBars = self.coordinateContext.visibleEndIndex - self.coordinateContext.visibleStartIndex;
    if (visibleBars <= 0) return -1;
    
    CGFloat barWidth = (self.coordinateContext.panelBounds.size.width - 20) / visibleBars;
    NSInteger relativeIndex = (x - 10) / barWidth;
    NSInteger absoluteIndex = self.coordinateContext.visibleStartIndex + relativeIndex;
    
    return MAX(self.coordinateContext.visibleStartIndex,
              MIN(absoluteIndex, self.coordinateContext.visibleEndIndex - 1));
}
#pragma mark - Updated Date-Based X Coordinate (con preferenze Trading Hours)

- (CGFloat)xCoordinateForDate:(NSDate *)targetDate {
    if (!targetDate || self.coordinateContext.chartData.count == 0) {
        return -9999; // Coordinate invalide
    }
    
    // 1. Cerca barra esistente nei dati
    for (NSInteger i = 0; i < self.coordinateContext.chartData.count; i++) {
        HistoricalBarModel *bar = self.coordinateContext.chartData[i];
        if ([bar.date compare:targetDate] != NSOrderedAscending) {
            // Trovata barra >= data target
            return [self xCoordinateForBarIndex:i];
        }
    }
    
    // 2. Data prima del dataset - ESTRAPOLAZIONE intelligente
    NSDate *firstDate = self.coordinateContext.chartData.firstObject.date;
    NSTimeInterval daysDiff = [firstDate timeIntervalSinceDate:targetDate] / 86400;
    
    // 3. Rimuovi weekend (logica dalla tua vecchia funzione)
    NSInteger weeks = daysDiff / 7;
    daysDiff = daysDiff - (weeks * 2);
    
    // 4. ✅ USA I VALORI DAL COORDINATE CONTEXT
    NSInteger barsPerDay = self.coordinateContext.barsPerDay;
    if (barsPerDay <= 0) {
        // Fallback se non disponibile
        barsPerDay = 26; // Default 15m regular hours
    }
    
    CGFloat totalBars = daysDiff * barsPerDay;
    
    // 5. Calcola posizione (coordinate negative = fuori viewport sinistra)
    NSInteger visibleBars = self.coordinateContext.visibleEndIndex - self.coordinateContext.visibleStartIndex;
    CGFloat barWidth = (self.coordinateContext.panelBounds.size.width - 20) / visibleBars;
    
    // Posizione relativa al primo indice visibile
    CGFloat firstBarX = [self xCoordinateForBarIndex:self.coordinateContext.visibleStartIndex];
    return firstBarX - (totalBars * barWidth);
}


@end
