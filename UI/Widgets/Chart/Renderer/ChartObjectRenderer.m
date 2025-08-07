//
//  ChartObjectRenderer.m
//  TradingApp
//
//  Chart objects rendering engine implementation
//

#import "ChartObjectRenderer.h"
#import "ChartPanelView.h"
#import "RuntimeModels.h"

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
        
        [self updateLayerFrames];
        [self invalidateObjectsLayer];
        
        NSLog(@"🔄 ChartObjectRenderer: Coordinate context updated");
    }
}

- (NSPoint)screenPointFromControlPoint:(ControlPointModel *)controlPoint {
    if (!controlPoint || !self.coordinateContext.chartData) {
        return NSZeroPoint;
    }
    
    // Step 1: Try to find exact bar in ALL data (not just visible range)
    HistoricalBarModel *targetBar = [self findBarForDate:controlPoint.dateAnchor];
    
    NSPoint screenPoint = NSZeroPoint;
    
    // Step 2: Calculate X coordinate using temporal extrapolation
    screenPoint.x = [self calculateXCoordinateForDate:controlPoint.dateAnchor];
    
    // Step 3: Calculate Y coordinate
    double actualPrice;
    if (targetBar) {
        // Use actual bar data if available
        double indicatorValue = [self getIndicatorValue:controlPoint.indicatorRef fromBar:targetBar];
        if (indicatorValue == 0.0) {
            return NSZeroPoint;
        }
        actualPrice = indicatorValue * (1.0 + controlPoint.valuePercent / 100.0);
    } else {
        // No bar data available - extrapolate price based on Y range
        // For now, we'll use the middle of the range as a fallback
        // This could be enhanced with price extrapolation algorithms
        double midPrice = (self.coordinateContext.yRangeMin + self.coordinateContext.yRangeMax) / 2.0;
        actualPrice = midPrice * (1.0 + controlPoint.valuePercent / 100.0);
        
        NSLog(@"⚠️ ChartObjectRenderer: Extrapolating price for date %@ (no bar data)", controlPoint.dateAnchor);
    }
    
    // Y coordinate: Price to pixel
    if (self.coordinateContext.yRangeMax != self.coordinateContext.yRangeMin) {
        double normalizedPrice = (actualPrice - self.coordinateContext.yRangeMin) /
                                (self.coordinateContext.yRangeMax - self.coordinateContext.yRangeMin);
        screenPoint.y = 10 + normalizedPrice * (self.coordinateContext.panelBounds.size.height - 20);
    }
    
    return screenPoint;
}

- (CGFloat)calculateXCoordinateForDate:(NSDate *)targetDate {
    if (!targetDate || self.coordinateContext.chartData.count == 0) {
        return 0.0;
    }
    
    NSInteger visibleBars = self.coordinateContext.visibleEndIndex - self.coordinateContext.visibleStartIndex;
    if (visibleBars <= 0) {
        return 0.0;
    }
    
    // Get first and last visible dates
    HistoricalBarModel *firstVisibleBar = self.coordinateContext.chartData[self.coordinateContext.visibleStartIndex];
    HistoricalBarModel *lastVisibleBar = self.coordinateContext.chartData[self.coordinateContext.visibleEndIndex - 1];
    
    NSDate *firstVisibleDate = firstVisibleBar.date;
    NSDate *lastVisibleDate = lastVisibleBar.date;
    
    // Calculate time span and pixels per bar (not per second)
    NSTimeInterval totalVisibleTimeSpan = [lastVisibleDate timeIntervalSinceDate:firstVisibleDate];
    if (totalVisibleTimeSpan <= 0) {
        return 10; // Fallback
    }
    
    CGFloat availableWidth = self.coordinateContext.panelBounds.size.width - 20; // Minus margins
    CGFloat barWidth = availableWidth / visibleBars;
    
    // Calculate which "bar index" this date would be at
    NSTimeInterval deltaTime = [targetDate timeIntervalSinceDate:firstVisibleDate];
    CGFloat proportionalIndex = (deltaTime / totalVisibleTimeSpan) * (visibleBars - 1);
    
    // Calculate X position at CENTER of bar
    CGFloat xPosition = 10 + (proportionalIndex * barWidth) + (barWidth / 2); // 10 = left margin
    
    return xPosition;
}

- (ControlPointModel *)controlPointFromScreenPoint:(NSPoint)screenPoint
                                       indicatorRef:(NSString *)indicatorRef {
    if (!self.coordinateContext.chartData) {
        return nil;
    }
    
    // Step 1: Convert screen X to bar index
    NSInteger visibleBars = self.coordinateContext.visibleEndIndex - self.coordinateContext.visibleStartIndex;
    if (visibleBars <= 0) return nil;
    
    CGFloat barWidth = (self.coordinateContext.panelBounds.size.width - 20) / visibleBars;
    NSInteger relativeIndex = (screenPoint.x - 10) / barWidth;
    NSInteger absoluteIndex = self.coordinateContext.visibleStartIndex + relativeIndex;
    
    // Clamp to valid range
    absoluteIndex = MAX(self.coordinateContext.visibleStartIndex,
                       MIN(absoluteIndex, self.coordinateContext.visibleEndIndex - 1));
    
    if (absoluteIndex >= self.coordinateContext.chartData.count) {
        return nil;
    }
    
    // Step 2: Get the bar and date
    HistoricalBarModel *targetBar = self.coordinateContext.chartData[absoluteIndex];
    NSDate *dateAnchor = targetBar.date;
    
    // Step 3: Convert screen Y to price
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
    if (self.editingObject) {
        // Draw the editing object with highlighting
        [self drawObjectWithHighlight:self.editingObject];
        [self drawControlPointsForObject:self.editingObject];
    }
    
    if (self.isInCreationMode && self.tempControlPoints.count > 0) {
        [self drawTemporaryObject];
    }
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
            
        case ChartObjectTypeTrailingFibo:
        case ChartObjectTypeTrailingFiboBetween:
            [self drawTrailingFibonacci:object];
            break;
            
        case ChartObjectTypeRectangle:
            [self drawRectangle:object];
            break;
            
        case ChartObjectTypeCircle:
            [self drawCircle:object];
            break;
            
        case ChartObjectTypeFreeDrawing:
            [self drawFreeDrawing:object];
            break;
            
        default:
            NSLog(@"⚠️ ChartObjectRenderer: Unknown object type %ld", (long)object.type);
            break;
    }
}

- (void)drawTrailingFibonacci:(ChartObjectModel *)object {
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
        NSString *label = level[@"label"];
        
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
        } else {
            // Intermediate levels - thinner
            path.lineWidth = 1.0;
        }
        
        // Draw the line
        [path moveToPoint:NSMakePoint(leftX, y)];
        [path lineToPoint:NSMakePoint(rightX, y)];
        [path stroke];
        
        // Draw level label
        [self drawTrailingFiboLabel:label atPoint:NSMakePoint(leftX + 5, y + 2)];
    }
    
    // Draw start point marker
    if (object.controlPoints.count > 0) {
        NSPoint startPoint = [self screenPointFromControlPoint:object.controlPoints.firstObject];
        [self drawTrailingFiboStartMarker:startPoint];
    }
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
    
    // Apply object style
    [self applyStyleForObject:object];
    
    // Draw horizontal line across entire panel width
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(0, screenPoint.y)];
    [path lineToPoint:NSMakePoint(self.coordinateContext.panelBounds.size.width, screenPoint.y)];
    [path stroke];
}

- (void)drawTrendline:(ChartObjectModel *)object {
    if (object.controlPoints.count < 2) return;
    
    ControlPointModel *cpA = object.controlPoints[0];
    ControlPointModel *cpB = object.controlPoints[1];
    
    // Get logical points (can be outside viewport)
    NSPoint logicalA = [self screenPointFromControlPoint:cpA];
    NSPoint logicalB = [self screenPointFromControlPoint:cpB];
    
    [self applyStyleForObject:object];
    
    // For now, always extend in both directions
    // TODO: Add extendLeft and extendRight properties to ChartObjectModel
    BOOL extendLeft = YES;
    BOOL extendRight = YES;
    
    if (extendLeft || extendRight) {
        // Calculate extended line that spans the viewport
        NSPoint extendedStart, extendedEnd;
        [self calculateExtendedLineFromPoint:logicalA
                                     toPoint:logicalB
                                  startPoint:&extendedStart
                                    endPoint:&extendedEnd
                                  extendLeft:extendLeft
                                 extendRight:extendRight];
        
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:extendedStart];
        [path lineToPoint:extendedEnd];
        [path stroke];
        
        // Draw original control points as small circles
        [self drawTrendlineControlPoints:logicalA pointB:logicalB];
    } else {
        // Draw only between the two points (no extension)
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:logicalA];
        [path lineToPoint:logicalB];
        [path stroke];
    }
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
    if (object.controlPoints.count < 2) return;
    
    NSPoint point1 = [self screenPointFromControlPoint:object.controlPoints[0]];
    NSPoint point2 = [self screenPointFromControlPoint:object.controlPoints[1]];
    
    [self applyStyleForObject:object];
    
    // Draw fibonacci levels (23.6%, 38.2%, 50%, 61.8%, 100%)
    NSArray *levels = @[@0.236, @0.382, @0.5, @0.618, @1.0];
    
    for (NSNumber *level in levels) {
        CGFloat ratio = level.floatValue;
        CGFloat y = point1.y + (point2.y - point1.y) * ratio;
        
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(0, y)];
        [path lineToPoint:NSMakePoint(self.coordinateContext.panelBounds.size.width, y)];
        [path stroke];
    }
}

- (void)drawRectangle:(ChartObjectModel *)object {
    if (object.controlPoints.count < 2) return;
    
    NSPoint point1 = [self screenPointFromControlPoint:object.controlPoints[0]];
    NSPoint point2 = [self screenPointFromControlPoint:object.controlPoints[1]];
    
    [self applyStyleForObject:object];
    
    NSRect rect = NSMakeRect(MIN(point1.x, point2.x), MIN(point1.y, point2.y),
                            fabs(point2.x - point1.x), fabs(point2.y - point1.y));
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:rect];
    [path stroke];
}

- (void)drawCircle:(ChartObjectModel *)object {
    if (object.controlPoints.count < 2) return;
    
    NSPoint center = [self screenPointFromControlPoint:object.controlPoints[0]];
    NSPoint edge = [self screenPointFromControlPoint:object.controlPoints[1]];
    
    [self applyStyleForObject:object];
    
    CGFloat radius = sqrt(pow(edge.x - center.x, 2) + pow(edge.y - center.y, 2));
    NSRect circleRect = NSMakeRect(center.x - radius, center.y - radius, radius * 2, radius * 2);
    
    NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    [path stroke];
}

- (void)drawFreeDrawing:(ChartObjectModel *)object {
    if (object.controlPoints.count < 2) return;
    
    [self applyStyleForObject:object];
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSPoint firstPoint = [self screenPointFromControlPoint:object.controlPoints.firstObject];
    [path moveToPoint:firstPoint];
    
    for (NSUInteger i = 1; i < object.controlPoints.count; i++) {
        NSPoint point = [self screenPointFromControlPoint:object.controlPoints[i]];
        [path lineToPoint:point];
    }
    
    [path stroke];
}

- (void)drawControlPointsForObject:(ChartObjectModel *)object {
    // Use red color for better visibility (same as creation mode)
    [[NSColor systemRedColor] setFill];
    
    for (ControlPointModel *cp in object.controlPoints) {
        NSPoint screenPoint = [self screenPointFromControlPoint:cp];
        
        // Size based on state: hovered > selected > normal
        CGFloat size = 8.0; // Base size
        if (cp == self.hoveredControlPoint) {
            size = 12.0; // Largest when hovered
        } else if (cp.isSelected) {
            size = 10.0; // Medium when selected
        }
        
        NSRect cpRect = NSMakeRect(screenPoint.x - size/2, screenPoint.y - size/2, size, size);
        NSBezierPath *cpPath = [NSBezierPath bezierPathWithOvalInRect:cpRect];
        [cpPath fill];
        
        // Different border styles for different states
        if (cp == self.hoveredControlPoint) {
            // Yellow border for hovered
            [[NSColor systemYellowColor] setStroke];
            cpPath.lineWidth = 3.0;
            [cpPath stroke];
        } else if (cp.isSelected) {
            // White border for selected
            [[NSColor whiteColor] setStroke];
            cpPath.lineWidth = 2.0;
            [cpPath stroke];
        }
        
        // Reset fill color for next iteration
        [[NSColor systemRedColor] setFill];
    }
}

- (void)drawTemporaryObject {
    // Draw preview of object being created
    if (self.tempControlPoints.count == 0) return;
    
    [[NSColor systemBlueColor] setStroke];
    
    // Draw temp control points
    for (ControlPointModel *cp in self.tempControlPoints) {
        NSPoint screenPoint = [self screenPointFromControlPoint:cp];
        NSRect cpRect = NSMakeRect(screenPoint.x - 4, screenPoint.y - 4, 8, 8);
        NSBezierPath *cpPath = [NSBezierPath bezierPathWithOvalInRect:cpRect];
        [[NSColor systemRedColor] setFill];
        [cpPath fill];
    }
    
    // Draw preview based on object type and current mouse position
    if (self.isInPreviewMode && self.tempControlPoints.count > 0) {
        [self drawCreationPreview];
    }
}

- (void)drawCreationPreview {
    [[NSColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.6] setStroke]; // Semi-transparent blue
    
    switch (self.creationObjectType) {
        case ChartObjectTypeTrendline:
            [self drawTrendlinePreview];
            break;
            
        case ChartObjectTypeFibonacci:
            [self drawFibonacciPreview];
            break;
            
        case ChartObjectTypeRectangle:
            [self drawRectanglePreview];
            break;
            
        case ChartObjectTypeCircle:
            [self drawCirclePreview];
            break;
            
        case ChartObjectTypeChannel:
            [self drawChannelPreview];
            break;
            
        case ChartObjectTypeTarget:
            [self drawTargetPreview];
            break;
            
        default:
            break;
    }
}

- (void)drawTrendlinePreview {
    if (self.tempControlPoints.count != 1) return;
    
    NSPoint point1 = [self screenPointFromControlPoint:self.tempControlPoints.firstObject];
    NSPoint point2 = self.currentMousePosition;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    path.lineWidth = 2.0;
    [path moveToPoint:point1];
    [path lineToPoint:point2];
    [path stroke];
}

- (void)drawFibonacciPreview {
    if (self.tempControlPoints.count != 1) return;
    
    NSPoint point1 = [self screenPointFromControlPoint:self.tempControlPoints.firstObject];
    NSPoint point2 = self.currentMousePosition;
    
    // Draw fibonacci levels preview
    NSArray *levels = @[@0.236, @0.382, @0.5, @0.618, @1.0];
    
    for (NSNumber *level in levels) {
        CGFloat ratio = level.floatValue;
        CGFloat y = point1.y + (point2.y - point1.y) * ratio;
        
        NSBezierPath *path = [NSBezierPath bezierPath];
        path.lineWidth = 1.0;
        [path moveToPoint:NSMakePoint(0, y)];
        [path lineToPoint:NSMakePoint(self.coordinateContext.panelBounds.size.width, y)];
        [path stroke];
    }
}

- (void)drawRectanglePreview {
    if (self.tempControlPoints.count != 1) return;
    
    NSPoint point1 = [self screenPointFromControlPoint:self.tempControlPoints.firstObject];
    NSPoint point2 = self.currentMousePosition;
    
    NSRect rect = NSMakeRect(MIN(point1.x, point2.x), MIN(point1.y, point2.y),
                            fabs(point2.x - point1.x), fabs(point2.y - point1.y));
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:rect];
    path.lineWidth = 2.0;
    [path stroke];
}

- (void)drawCirclePreview {
    if (self.tempControlPoints.count != 1) return;
    
    NSPoint center = [self screenPointFromControlPoint:self.tempControlPoints.firstObject];
    NSPoint edge = self.currentMousePosition;
    
    CGFloat radius = sqrt(pow(edge.x - center.x, 2) + pow(edge.y - center.y, 2));
    NSRect circleRect = NSMakeRect(center.x - radius, center.y - radius, radius * 2, radius * 2);
    
    NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    path.lineWidth = 2.0;
    [path stroke];
}

- (void)drawChannelPreview {
    // TODO: Implement channel preview (more complex - parallel lines)
    NSLog(@"🚧 Channel preview not yet implemented");
}

- (void)drawTargetPreview {
    // TODO: Implement target preview (buy/stop/target levels)
    NSLog(@"🚧 Target preview not yet implemented");
}

- (void)applyStyleForObject:(ChartObjectModel *)object {
    ObjectStyleModel *style = object.style;
    
    [style.color setStroke];
    
    // Apply line dash pattern
    CGFloat dashPattern[4];
    NSInteger dashCount = 0;
    
    switch (style.lineType) {
        case ChartLineTypeDashed:
            dashPattern[0] = 5.0;
            dashPattern[1] = 3.0;
            dashCount = 2;
            break;
        case ChartLineTypeDotted:
            dashPattern[0] = 2.0;
            dashPattern[1] = 2.0;
            dashCount = 2;
            break;
        case ChartLineTypeDashDot:
            dashPattern[0] = 5.0;
            dashPattern[1] = 2.0;
            dashPattern[2] = 2.0;
            dashPattern[3] = 2.0;
            dashCount = 4;
            break;
        default: // ChartLineTypeSolid
            dashCount = 0;
            break;
    }
    
    // This would be applied to the current NSBezierPath in a real implementation
    // For now, we set the basic properties
}

#pragma mark - Object Creation/Editing

- (void)startCreatingObjectOfType:(ChartObjectType)objectType {
    self.isInCreationMode = YES;
    self.creationObjectType = objectType;
    [self.tempControlPoints removeAllObjects];
    
    NSLog(@"🎯 ChartObjectRenderer: Started creating object type %ld", (long)objectType);
}

- (BOOL)addControlPointAtScreenPoint:(NSPoint)screenPoint {
    ControlPointModel *newCP = [self controlPointFromScreenPoint:screenPoint indicatorRef:@"close"];
    if (!newCP) return NO;
    
    [self.tempControlPoints addObject:newCP];
    
    // Check if we need to enter preview mode for multi-CP objects
    BOOL needsMorePoints = [self needsMoreControlPointsForPreview];
    if (needsMorePoints) {
        self.isInPreviewMode = YES;
        self.currentMousePosition = screenPoint;
        NSLog(@"🎯 ChartObjectRenderer: Entered preview mode after CP %lu",
              (unsigned long)self.tempControlPoints.count);
    }
    
    [self invalidateEditingLayer];
    
    // Check if object is complete
    BOOL isComplete = [self isObjectCreationComplete];
    if (isComplete) {
        [self finishCreatingObject];
    }
    
    return isComplete;
}

- (void)updateCreationPreviewAtPoint:(NSPoint)screenPoint {
    if (!self.isInCreationMode || !self.isInPreviewMode) return;
    
    self.currentMousePosition = screenPoint;
    [self invalidateEditingLayer];
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
    
    // Force redraw
    if (self.isInCreationMode) {
        [self invalidateEditingLayer];
    } else if (self.editingObject) {
        [self invalidateEditingLayer];
    }
    
    NSLog(@"🎯 Updated currentCP coordinates: %.2f%% at %@",
          self.currentCPSelected.valuePercent, self.currentCPSelected.dateAnchor);
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

- (BOOL)needsMoreControlPointsForPreview {
    switch (self.creationObjectType) {
        case ChartObjectTypeTrendline:
        case ChartObjectTypeFibonacci:
        case ChartObjectTypeRectangle:
        case ChartObjectTypeCircle:
            return self.tempControlPoints.count == 1; // Need preview after first point
            
        case ChartObjectTypeChannel:
            return self.tempControlPoints.count < 3; // Need preview for 2nd and 3rd point
            
        case ChartObjectTypeTarget:
            return self.tempControlPoints.count < 3; // Need preview for 2nd and 3rd point
            
        case ChartObjectTypeHorizontalLine:
        default:
            return NO; // Single point objects don't need preview
    }
}

- (BOOL)isObjectCreationComplete {
    switch (self.creationObjectType) {
        case ChartObjectTypeHorizontalLine:
            return self.tempControlPoints.count >= 1;
        case ChartObjectTypeTrendline:
        case ChartObjectTypeFibonacci:
        case ChartObjectTypeRectangle:
        case ChartObjectTypeCircle:
            return self.tempControlPoints.count >= 2;
        default:
            return NO;
    }
}

- (void)finishCreatingObject {
    if (!self.isInCreationMode || self.tempControlPoints.count == 0) return;
    
    // Create object in active layer
    ChartLayerModel *activeLayer = self.objectsManager.activeLayer;
    if (!activeLayer) {
        activeLayer = [self.objectsManager createLayerWithName:@"Drawing"];
    }
    
    ChartObjectModel *newObject = [self.objectsManager createObjectOfType:self.creationObjectType
                                                                  inLayer:activeLayer];
    
    // Add control points
    for (ControlPointModel *cp in self.tempControlPoints) {
        [newObject addControlPoint:cp];
    }
    
    [self cancelCreatingObject];
    [self invalidateObjectsLayer];
    
    NSLog(@"✅ ChartObjectRenderer: Finished creating object %@", newObject.name);
}

- (void)cancelCreatingObject {
    self.isInCreationMode = NO;
    self.isInPreviewMode = NO;
    self.creationObjectType = 0;
    self.currentMousePosition = NSZeroPoint;
    [self.tempControlPoints removeAllObjects];
    [self invalidateEditingLayer];
    
    NSLog(@"❌ ChartObjectRenderer: Cancelled object creation");
}

- (void)startEditingObject:(ChartObjectModel *)object {
    [self stopEditing]; // Stop any current editing
    
    self.editingObject = object;
    [self.objectsManager selectObject:object];
    
    // Move object from static layer to editing layer
    [self invalidateObjectsLayer];  // Redraw without this object
    [self invalidateEditingLayer];  // Draw object in editing layer
    
    NSLog(@"✏️ ChartObjectRenderer: Started editing object %@", object.name);
}

- (void)stopEditing {
    if (!self.editingObject) return;
    
    ChartObjectModel *object = self.editingObject;
    self.editingObject = nil;
    
    [self.objectsManager clearSelection];
    
    // Move object back to static layer
    [self invalidateObjectsLayer];  // Redraw with this object
    [self invalidateEditingLayer];  // Clear editing layer
    
    NSLog(@"✅ ChartObjectRenderer: Stopped editing object %@", object.name);
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
    
    // Get starting price
    HistoricalBarModel *startBar = [self findBarForDate:startCP.dateAnchor];
    if (!startBar) return fibLevels;
    
    double startIndicatorValue = [self getIndicatorValue:startCP.indicatorRef fromBar:startBar];
    double startPrice = startIndicatorValue * (1.0 + startCP.valuePercent / 100.0);
    
    // Get latest extreme price
    NSDictionary *lastPeak = peaks.lastObject;
    double extremePrice = [lastPeak[@"price"] doubleValue];
    NSDate *extremeDate = lastPeak[@"date"];
    
    // Fibonacci levels (from start to extreme)
    NSArray *fibRatios = @[@0.0, @0.236, @0.382, @0.5, @0.618, @1.0];
    NSArray *fibLabels = @[@"0%", @"23.6%", @"38.2%", @"50%", @"61.8%", @"100%"];
    
    for (NSUInteger i = 0; i < fibRatios.count; i++) {
        double ratio = [fibRatios[i] doubleValue];
        double levelPrice = startPrice + ratio * (extremePrice - startPrice);
        
        [fibLevels addObject:@{
            @"ratio": fibRatios[i],
            @"label": fibLabels[i],
            @"price": @(levelPrice),
            @"startDate": startCP.dateAnchor,
            @"endDate": extremeDate ?: startCP.dateAnchor
        }];
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

@end
