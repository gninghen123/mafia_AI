//
//  CHLineChartRenderer.m
//  ChartWidget
//
//  Implementation of line chart renderer
//

#import "CHLineChartRenderer.h"
#import "CHChartConfiguration.h"
#import "CHDataPoint.h"

@implementation CHLineChartRenderer

#pragma mark - Initialization

- (instancetype)initWithConfiguration:(CHChartConfiguration *)configuration {
    self = [super initWithConfiguration:configuration];
    if (self) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    _lineStyle = CHLineChartStyleStraight;
    _pointStyle = CHLineChartPointStyleCircle;
    _fillArea = NO;
    _fillOpacity = 0.2;
    _showDataPoints = YES;
    _animatePointByPoint = NO;
    _drawShadow = NO;
    _shadowColor = [NSColor colorWithWhite:0 alpha:0.3];
    _shadowOffset = CGSizeMake(0, 2);
    _shadowBlurRadius = 3.0;
}

#pragma mark - Drawing

- (void)drawInRect:(CGRect)rect
           context:(NSGraphicsContext *)context
          animated:(BOOL)animated
          progress:(CGFloat)progress {
    // Draw base elements (grid, axes, labels)
    [super drawInRect:rect context:context animated:animated progress:progress];
    
    // Draw each data series
    for (NSInteger seriesIndex = 0; seriesIndex < self.dataPoints.count; seriesIndex++) {
        NSArray<CHDataPoint *> *series = self.dataPoints[seriesIndex];
        if (series.count < 2) continue; // Need at least 2 points for a line
        
        // Get series color
        NSColor *seriesColor = nil;
        if (seriesIndex < self.configuration.seriesColors.count) {
            seriesColor = self.configuration.seriesColors[seriesIndex];
        } else {
            seriesColor = [NSColor colorWithHue:(CGFloat)seriesIndex/self.dataPoints.count
                                     saturation:0.8
                                     brightness:0.8
                                          alpha:1.0];
        }
        
        // Calculate how many points to draw based on animation progress
        NSInteger pointsToDraw = animated ? (NSInteger)(series.count * progress) : series.count;
        if (pointsToDraw < 2) continue;
        
        // Create path for the line
        NSBezierPath *linePath = [NSBezierPath bezierPath];
        [linePath setLineWidth:self.configuration.lineWidth];
        [linePath setLineCapStyle:NSLineCapStyleRound];
        [linePath setLineJoinStyle:NSLineJoinStyleRound];
        
        // Build the line path
        [self buildLinePath:linePath
                 forSeries:series
                pointCount:pointsToDraw
                    inRect:rect];
        
        // Draw shadow if enabled
        if (self.drawShadow) {
            [self drawShadowForPath:linePath context:context];
        }
        
        // Fill area under curve if enabled
        if (self.fillArea) {
            [self fillAreaUnderPath:linePath
                         withColor:seriesColor
                            inRect:rect
                           context:context];
        }
        
        // Draw the line
        [context saveGraphicsState];
        [seriesColor set];
        [linePath stroke];
        [context restoreGraphicsState];
        
        // Draw data points if enabled
        if (self.showDataPoints) {
            [self drawDataPointsForSeries:series
                               pointCount:pointsToDraw
                                withColor:seriesColor
                                   inRect:rect
                                  context:context
                                 animated:animated
                                 progress:progress];
        }
    }
}

#pragma mark - Path Building

- (void)buildLinePath:(NSBezierPath *)path
           forSeries:(NSArray<CHDataPoint *> *)series
          pointCount:(NSInteger)pointCount
              inRect:(CGRect)rect {
    
    switch (self.lineStyle) {
        case CHLineChartStyleStraight:
            [self buildStraightLinePath:path forSeries:series pointCount:pointCount inRect:rect];
            break;
            
        case CHLineChartStyleSmooth:
            [self buildSmoothLinePath:path forSeries:series pointCount:pointCount inRect:rect];
            break;
            
        case CHLineChartStyleStepped:
            [self buildSteppedLinePath:path forSeries:series pointCount:pointCount inRect:rect stepped:YES];
            break;
            
        case CHLineChartStyleSteppedMiddle:
            [self buildSteppedLinePath:path forSeries:series pointCount:pointCount inRect:rect stepped:NO];
            break;
    }
}

- (void)buildStraightLinePath:(NSBezierPath *)path
                   forSeries:(NSArray<CHDataPoint *> *)series
                  pointCount:(NSInteger)pointCount
                      inRect:(CGRect)rect {
    
    CGPoint firstPoint = [self viewPointForDataPoint:series[0] inRect:rect];
    [path moveToPoint:firstPoint];
    
    for (NSInteger i = 1; i < pointCount; i++) {
        CGPoint point = [self viewPointForDataPoint:series[i] inRect:rect];
        [path lineToPoint:point];
    }
}

- (void)buildSmoothLinePath:(NSBezierPath *)path
                 forSeries:(NSArray<CHDataPoint *> *)series
                pointCount:(NSInteger)pointCount
                    inRect:(CGRect)rect {
    
    if (pointCount < 2) return;
    
    // Convert data points to view points
    NSMutableArray<NSValue *> *viewPoints = [NSMutableArray array];
    for (NSInteger i = 0; i < pointCount; i++) {
        CGPoint point = [self viewPointForDataPoint:series[i] inRect:rect];
        [viewPoints addObject:[NSValue valueWithPoint:NSPointFromCGPoint(point)]];
    }
    
    // Move to first point
    CGPoint firstPoint = [viewPoints[0] pointValue];
    [path moveToPoint:firstPoint];
    
    // Draw smooth curves through points
    for (NSInteger i = 0; i < pointCount - 1; i++) {
        CGPoint p0 = i > 0 ? [viewPoints[i-1] pointValue] : [viewPoints[i] pointValue];
        CGPoint p1 = [viewPoints[i] pointValue];
        CGPoint p2 = [viewPoints[i+1] pointValue];
        CGPoint p3 = i < pointCount - 2 ? [viewPoints[i+2] pointValue] : [viewPoints[i+1] pointValue];
        
        // Calculate control points for cubic bezier
        CGFloat tension = 0.3;
        CGPoint cp1, cp2;
        
        cp1.x = p1.x + (p2.x - p0.x) * tension;
        cp1.y = p1.y + (p2.y - p0.y) * tension;
        
        cp2.x = p2.x - (p3.x - p1.x) * tension;
        cp2.y = p2.y - (p3.y - p1.y) * tension;
        
        [path curveToPoint:p2 controlPoint1:cp1 controlPoint2:cp2];
    }
}

- (void)buildSteppedLinePath:(NSBezierPath *)path
                  forSeries:(NSArray<CHDataPoint *> *)series
                 pointCount:(NSInteger)pointCount
                     inRect:(CGRect)rect
                    stepped:(BOOL)stepped {
    
    CGPoint firstPoint = [self viewPointForDataPoint:series[0] inRect:rect];
    [path moveToPoint:firstPoint];
    
    for (NSInteger i = 1; i < pointCount; i++) {
        CGPoint prevPoint = [self viewPointForDataPoint:series[i-1] inRect:rect];
        CGPoint currPoint = [self viewPointForDataPoint:series[i] inRect:rect];
        
        if (stepped) {
            // Step happens at the end of the interval
            [path lineToPoint:CGPointMake(currPoint.x, prevPoint.y)];
            [path lineToPoint:currPoint];
        } else {
            // Step happens in the middle of the interval
            CGFloat midX = (prevPoint.x + currPoint.x) / 2;
            [path lineToPoint:CGPointMake(midX, prevPoint.y)];
            [path lineToPoint:CGPointMake(midX, currPoint.y)];
            [path lineToPoint:currPoint];
        }
    }
}

#pragma mark - Area Filling

- (void)fillAreaUnderPath:(NSBezierPath *)linePath
               withColor:(NSColor *)color
                  inRect:(CGRect)rect
                 context:(NSGraphicsContext *)context {
    
    [context saveGraphicsState];
    
    // Create fill path
    NSBezierPath *fillPath = [linePath copy];
    
    // Get the last point
    NSPoint lastPoint = [fillPath currentPoint];
    
    // Close the path by drawing to the bottom
    CGFloat baseY = rect.origin.y + rect.size.height;
    [fillPath lineToPoint:NSMakePoint(lastPoint.x, baseY)];
    
    // Draw back to the first point's X at the bottom
    NSPoint firstPoint = NSZeroPoint;
    NSInteger elementCount = [linePath elementCount];
    if (elementCount > 0) {
        NSBezierPathElement element = [linePath elementAtIndex:0];
        if (element == NSBezierPathElementMoveTo) {
            NSPoint points[3];
            [linePath elementAtIndex:0 associatedPoints:points];
            firstPoint = points[0];
        }
    }
    [fillPath lineToPoint:NSMakePoint(firstPoint.x, baseY)];
    [fillPath closePath];
    
    // Fill with transparency
    NSColor *fillColor = [color colorWithAlphaComponent:self.fillOpacity];
    [fillColor set];
    [fillPath fill];
    
    [context restoreGraphicsState];
}

#pragma mark - Shadow Drawing

- (void)drawShadowForPath:(NSBezierPath *)path context:(NSGraphicsContext *)context {
    [context saveGraphicsState];
    
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowColor:self.shadowColor];
    [shadow setShadowOffset:self.shadowOffset];
    [shadow setShadowBlurRadius:self.shadowBlurRadius];
    
    [shadow set];
    
    [context restoreGraphicsState];
}

#pragma mark - Data Points Drawing

- (void)drawDataPointsForSeries:(NSArray<CHDataPoint *> *)series
                     pointCount:(NSInteger)pointCount
                      withColor:(NSColor *)color
                         inRect:(CGRect)rect
                        context:(NSGraphicsContext *)context
                       animated:(BOOL)animated
                       progress:(CGFloat)progress {
    
    [context saveGraphicsState];
    
    for (NSInteger i = 0; i < pointCount; i++) {
        CHDataPoint *dataPoint = series[i];
        CGPoint viewPoint = [self viewPointForDataPoint:dataPoint inRect:rect];
        
        // Skip if animating point by point and we haven't reached this point yet
        if (self.animatePointByPoint && animated) {
            CGFloat pointProgress = (CGFloat)i / (series.count - 1);
            if (pointProgress > progress) continue;
        }
        
        // Draw the point based on style
        [self drawPointAt:viewPoint
                withStyle:self.pointStyle
                    color:color
                 selected:dataPoint.isSelected
              highlighted:dataPoint.isHighlighted
                  context:context];
    }
    
    [context restoreGraphicsState];
}

- (void)drawPointAt:(CGPoint)point
          withStyle:(CHLineChartPointStyle)style
              color:(NSColor *)color
           selected:(BOOL)selected
        highlighted:(BOOL)highlighted
            context:(NSGraphicsContext *)context {
    
    if (style == CHLineChartPointStyleNone) return;
    
    CGFloat radius = self.configuration.pointRadius;
    if (selected || highlighted) {
        radius *= 1.5; // Make selected/highlighted points larger
    }
    
    NSBezierPath *pointPath = nil;
    
    switch (style) {
        case CHLineChartPointStyleCircle: {
            pointPath = [NSBezierPath bezierPathWithOvalInRect:
                        NSMakeRect(point.x - radius, point.y - radius, radius * 2, radius * 2)];
            break;
        }
            
        case CHLineChartPointStyleSquare: {
            pointPath = [NSBezierPath bezierPathWithRect:
                        NSMakeRect(point.x - radius, point.y - radius, radius * 2, radius * 2)];
            break;
        }
            
        case CHLineChartPointStyleDiamond: {
            pointPath = [NSBezierPath bezierPath];
            [pointPath moveToPoint:NSMakePoint(point.x, point.y - radius)];
            [pointPath lineToPoint:NSMakePoint(point.x + radius, point.y)];
            [pointPath lineToPoint:NSMakePoint(point.x, point.y + radius)];
            [pointPath lineToPoint:NSMakePoint(point.x - radius, point.y)];
            [pointPath closePath];
            break;
        }
            
        case CHLineChartPointStyleTriangle: {
            pointPath = [NSBezierPath bezierPath];
            CGFloat height = radius * 1.732; // sqrt(3) for equilateral triangle
            [pointPath moveToPoint:NSMakePoint(point.x, point.y - radius)];
            [pointPath lineToPoint:NSMakePoint(point.x - height/2, point.y + radius/2)];
            [pointPath lineToPoint:NSMakePoint(point.x + height/2, point.y + radius/2)];
            [pointPath closePath];
            break;
        }
            
        default:
            break;
    }
    
    if (pointPath) {
        // Fill the point
        [color set];
        [pointPath fill];
        
        // Draw border for selected/highlighted points
        if (selected || highlighted) {
            [[NSColor whiteColor] set];
            [pointPath setLineWidth:2.0];
            [pointPath stroke];
        }
    }
}

@end
