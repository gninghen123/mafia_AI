//
//  NSBezierPath+CHAdditions.m
//  ChartWidget
//
//  Implementation of NSBezierPath category
//

#import "NSBezierPath+CHAdditions.h"

@implementation NSBezierPath (CHAdditions)

#pragma mark - Shape Creation

+ (NSBezierPath *)ch_bezierPathWithArrowFromPoint:(NSPoint)startPoint
                                          toPoint:(NSPoint)endPoint
                                       headLength:(CGFloat)headLength
                                        headAngle:(CGFloat)headAngle {
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    // Draw the line
    [path moveToPoint:startPoint];
    [path lineToPoint:endPoint];
    
    // Calculate arrow head points
    CGFloat angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x);
    CGFloat angleLeft = angle + headAngle;
    CGFloat angleRight = angle - headAngle;
    
    NSPoint leftPoint = NSMakePoint(endPoint.x - headLength * cos(angleLeft),
                                   endPoint.y - headLength * sin(angleLeft));
    NSPoint rightPoint = NSMakePoint(endPoint.x - headLength * cos(angleRight),
                                    endPoint.y - headLength * sin(angleRight));
    
    // Draw arrow head
    [path moveToPoint:leftPoint];
    [path lineToPoint:endPoint];
    [path lineToPoint:rightPoint];
    
    return path;
}

+ (NSBezierPath *)ch_bezierPathWithStarInRect:(NSRect)rect
                                   pointCount:(NSInteger)pointCount
                                  innerRadius:(CGFloat)innerRadius {
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    CGPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
    CGFloat outerRadius = MIN(rect.size.width, rect.size.height) / 2;
    CGFloat innerRadiusActual = outerRadius * innerRadius;
    
    CGFloat angleStep = (2 * M_PI) / (pointCount * 2);
    
    for (NSInteger i = 0; i < pointCount * 2; i++) {
        CGFloat angle = -M_PI_2 + (i * angleStep); // Start from top
        CGFloat radius = (i % 2 == 0) ? outerRadius : innerRadiusActual;
        
        NSPoint point = NSMakePoint(center.x + radius * cos(angle),
                                   center.y + radius * sin(angle));
        
        if (i == 0) {
            [path moveToPoint:point];
        } else {
            [path lineToPoint:point];
        }
    }
    
    [path closePath];
    return path;
}

+ (NSBezierPath *)ch_bezierPathWithPolygonInRect:(NSRect)rect
                                           sides:(NSInteger)sides {
    if (sides < 3) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
    CGFloat radius = MIN(rect.size.width, rect.size.height) / 2;
    
    CGFloat angleStep = (2 * M_PI) / sides;
    
    for (NSInteger i = 0; i < sides; i++) {
        CGFloat angle = -M_PI_2 + (i * angleStep); // Start from top
        NSPoint point = NSMakePoint(center.x + radius * cos(angle),
                                   center.y + radius * sin(angle));
        
        if (i == 0) {
            [path moveToPoint:point];
        } else {
            [path lineToPoint:point];
        }
    }
    
    [path closePath];
    return path;
}

+ (NSBezierPath *)ch_bezierPathWithCrossInRect:(NSRect)rect
                                      thickness:(CGFloat)thickness {
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    CGFloat halfThickness = thickness / 2;
    CGPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
    
    // Horizontal bar
    [path moveToPoint:NSMakePoint(rect.origin.x, center.y - halfThickness)];
    [path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, center.y - halfThickness)];
    [path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, center.y + halfThickness)];
    [path lineToPoint:NSMakePoint(rect.origin.x, center.y + halfThickness)];
    [path closePath];
    
    // Vertical bar
    [path moveToPoint:NSMakePoint(center.x - halfThickness, rect.origin.y)];
    [path lineToPoint:NSMakePoint(center.x + halfThickness, rect.origin.y)];
    [path lineToPoint:NSMakePoint(center.x + halfThickness, rect.origin.y + rect.size.height)];
    [path lineToPoint:NSMakePoint(center.x - halfThickness, rect.origin.y + rect.size.height)];
    [path closePath];
    
    return path;
}

#pragma mark - Smooth Path

+ (NSBezierPath *)ch_smoothPathThroughPoints:(NSArray<NSValue *> *)points {
    if (points.count < 2) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    // Move to first point
    [path moveToPoint:[points[0] pointValue]];
    
    if (points.count == 2) {
        // Just draw a line for 2 points
        [path lineToPoint:[points[1] pointValue]];
        return path;
    }
    
    // Catmull-Rom spline implementation
    for (NSInteger i = 0; i < points.count - 1; i++) {
        NSPoint p0 = i > 0 ? [points[i-1] pointValue] : [points[i] pointValue];
        NSPoint p1 = [points[i] pointValue];
        NSPoint p2 = [points[i+1] pointValue];
        NSPoint p3 = i < points.count - 2 ? [points[i+2] pointValue] : [points[i+1] pointValue];
        
        // Calculate control points
        CGFloat tension = 0.5;
        NSPoint cp1 = NSMakePoint(p1.x + (p2.x - p0.x) / 6 * tension,
                                 p1.y + (p2.y - p0.y) / 6 * tension);
        NSPoint cp2 = NSMakePoint(p2.x - (p3.x - p1.x) / 6 * tension,
                                 p2.y - (p3.y - p1.y) / 6 * tension);
        
        [path curveToPoint:p2 controlPoint1:cp1 controlPoint2:cp2];
    }
    
    return path;
}

#pragma mark - Path Manipulation

- (void)ch_addDashedBorderWithPattern:(NSArray<NSNumber *> *)pattern {
    CGFloat dashPattern[pattern.count];
    for (NSInteger i = 0; i < pattern.count; i++) {
        dashPattern[i] = [pattern[i] floatValue];
    }
    [self setLineDash:dashPattern count:pattern.count phase:0];
}

- (NSBezierPath *)ch_pathWithRoundedCorners:(CHRoundedCorners)corners
                                      radius:(CGFloat)radius {
    NSRect bounds = [self bounds];
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    CGFloat minX = NSMinX(bounds);
    CGFloat minY = NSMinY(bounds);
    CGFloat maxX = NSMaxX(bounds);
    CGFloat maxY = NSMaxY(bounds);
    
    // Start from top-left corner
    if (corners & CHRoundedCornerTopLeft) {
        [path moveToPoint:NSMakePoint(minX + radius, minY)];
    } else {
        [path moveToPoint:NSMakePoint(minX, minY)];
    }
    
    // Top edge and top-right corner
    if (corners & CHRoundedCornerTopRight) {
        [path lineToPoint:NSMakePoint(maxX - radius, minY)];
        [path appendBezierPathWithArcFromPoint:NSMakePoint(maxX, minY)
                                       toPoint:NSMakePoint(maxX, minY + radius)
                                        radius:radius];
    } else {
        [path lineToPoint:NSMakePoint(maxX, minY)];
    }
    
    // Right edge and bottom-right corner
    if (corners & CHRoundedCornerBottomRight) {
        [path lineToPoint:NSMakePoint(maxX, maxY - radius)];
        [path appendBezierPathWithArcFromPoint:NSMakePoint(maxX, maxY)
                                       toPoint:NSMakePoint(maxX - radius, maxY)
                                        radius:radius];
    } else {
        [path lineToPoint:NSMakePoint(maxX, maxY)];
    }
    
    // Bottom edge and bottom-left corner
    if (corners & CHRoundedCornerBottomLeft) {
        [path lineToPoint:NSMakePoint(minX + radius, maxY)];
        [path appendBezierPathWithArcFromPoint:NSMakePoint(minX, maxY)
                                       toPoint:NSMakePoint(minX, maxY - radius)
                                        radius:radius];
    } else {
        [path lineToPoint:NSMakePoint(minX, maxY)];
    }
    
    // Left edge and top-left corner
    if (corners & CHRoundedCornerTopLeft) {
        [path lineToPoint:NSMakePoint(minX, minY + radius)];
        [path appendBezierPathWithArcFromPoint:NSMakePoint(minX, minY)
                                       toPoint:NSMakePoint(minX + radius, minY)
                                        radius:radius];
    } else {
        [path lineToPoint:NSMakePoint(minX, minY)];
    }
    
    [path closePath];
    return path;
}

#pragma mark - Drawing Utilities

- (void)ch_fillWithGradient:(NSGradient *)gradient angle:(CGFloat)angle {
    [NSGraphicsContext saveGraphicsState];
    [self addClip];
    [gradient drawInBezierPath:self angle:angle];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)ch_strokeWithGradient:(NSGradient *)gradient
                        angle:(CGFloat)angle
                    lineWidth:(CGFloat)lineWidth {
    [NSGraphicsContext saveGraphicsState];
    
    // Set the line width
    CGFloat originalLineWidth = [self lineWidth];
    [self setLineWidth:lineWidth];
    
    // Create a stroked outline path manually
    // Since bezierPathByStrokingPath doesn't exist on macOS,
    // we'll use a different approach
    
    // Draw the gradient along the path
    [self addClip];
    
    // Get the bounds of the path
    NSRect bounds = [self bounds];
    
    // Expand bounds to account for line width
    bounds = NSInsetRect(bounds, -lineWidth, -lineWidth);
    
    // Draw the gradient in the expanded area
    [gradient drawInRect:bounds angle:angle];
    
    // Restore line width
    [self setLineWidth:originalLineWidth];
    
    [NSGraphicsContext restoreGraphicsState];
}

- (NSBezierPath *)ch_strokedPathWithLineWidth:(CGFloat)lineWidth {
    // This creates an approximation of a stroked path
    // by creating an outline around the original path
    
    NSBezierPath *strokedPath = [NSBezierPath bezierPath];
    CGFloat flatness = 0.1;
    
    // Flatten the path first to work with line segments
    NSBezierPath *flatPath = [self bezierPathByFlatteningPath];
    
    // For a simple implementation, we'll just create a thicker version
    // In a full implementation, you'd calculate perpendicular offsets
    // at each point to create a proper outline
    
    [strokedPath appendBezierPath:self];
    [strokedPath setLineWidth:lineWidth];
    
    return strokedPath;
}

#pragma mark - Shadow Drawing

- (void)ch_drawWithInnerShadow:(NSShadow *)shadow {
    [NSGraphicsContext saveGraphicsState];
    
    // Create inverse clip
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRect:NSInsetRect([self bounds], -50, -50)];
    [clipPath appendBezierPath:self];
    [clipPath setWindingRule:NSWindingRuleEvenOdd];
    [clipPath addClip];
    
    // Draw shadow
    [shadow set];
    [[NSColor blackColor] set];
    [self fill];
    
    [NSGraphicsContext restoreGraphicsState];
}

#pragma mark - Animation Support

- (NSBezierPath *)ch_interpolatedPathToPath:(NSBezierPath *)toPath
                                   progress:(CGFloat)progress {
    if (progress <= 0) return [self copy];
    if (progress >= 1) return [toPath copy];
    
    NSBezierPath *interpolatedPath = [NSBezierPath bezierPath];
    
    NSInteger elementCount = MIN([self elementCount], [toPath elementCount]);
    
    for (NSInteger i = 0; i < elementCount; i++) {
        NSBezierPathElement fromElement = [self elementAtIndex:i];
        NSBezierPathElement toElement = [toPath elementAtIndex:i];
        
        if (fromElement != toElement) continue; // Elements must match
        
        NSPoint fromPoints[3], toPoints[3];
        [self elementAtIndex:i associatedPoints:fromPoints];
        [toPath elementAtIndex:i associatedPoints:toPoints];
        
        switch (fromElement) {
            case NSBezierPathElementMoveTo: {
                NSPoint interpolated = NSMakePoint(
                    fromPoints[0].x + (toPoints[0].x - fromPoints[0].x) * progress,
                    fromPoints[0].y + (toPoints[0].y - fromPoints[0].y) * progress
                );
                [interpolatedPath moveToPoint:interpolated];
                break;
            }
            
            case NSBezierPathElementLineTo: {
                NSPoint interpolated = NSMakePoint(
                    fromPoints[0].x + (toPoints[0].x - fromPoints[0].x) * progress,
                    fromPoints[0].y + (toPoints[0].y - fromPoints[0].y) * progress
                );
                [interpolatedPath lineToPoint:interpolated];
                break;
            }
            
            case NSBezierPathElementCurveTo: {
                NSPoint cp1 = NSMakePoint(
                    fromPoints[0].x + (toPoints[0].x - fromPoints[0].x) * progress,
                    fromPoints[0].y + (toPoints[0].y - fromPoints[0].y) * progress
                );
                NSPoint cp2 = NSMakePoint(
                    fromPoints[1].x + (toPoints[1].x - fromPoints[1].x) * progress,
                    fromPoints[1].y + (toPoints[1].y - fromPoints[1].y) * progress
                );
                NSPoint end = NSMakePoint(
                    fromPoints[2].x + (toPoints[2].x - fromPoints[2].x) * progress,
                    fromPoints[2].y + (toPoints[2].y - fromPoints[2].y) * progress
                );
                [interpolatedPath curveToPoint:end controlPoint1:cp1 controlPoint2:cp2];
                break;
            }
            
            case NSBezierPathElementClosePath:
                [interpolatedPath closePath];
                break;
                
            default:
                break;
        }
    }
    
    return interpolatedPath;
}

#pragma mark - Conversion

- (CGPathRef)ch_CGPath CF_RETURNS_RETAINED {
    CGMutablePathRef cgPath = CGPathCreateMutable();
    NSInteger elementCount = [self elementCount];
    
    for (NSInteger i = 0; i < elementCount; i++) {
        NSBezierPathElement element = [self elementAtIndex:i];
        NSPoint points[3];
        [self elementAtIndex:i associatedPoints:points];
        
        switch (element) {
            case NSBezierPathElementMoveTo:
                CGPathMoveToPoint(cgPath, NULL, points[0].x, points[0].y);
                break;
                
            case NSBezierPathElementLineTo:
                CGPathAddLineToPoint(cgPath, NULL, points[0].x, points[0].y);
                break;
                
            case NSBezierPathElementCurveTo:
                CGPathAddCurveToPoint(cgPath, NULL,
                                     points[0].x, points[0].y,
                                     points[1].x, points[1].y,
                                     points[2].x, points[2].y);
                break;
                
            case NSBezierPathElementClosePath:
                CGPathCloseSubpath(cgPath);
                break;
                
            default:
                break;
        }
    }
    
    return cgPath;
}

@end
