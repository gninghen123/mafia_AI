//
//  NSBezierPath+CHAdditions.h
//  ChartWidget
//
//  NSBezierPath category with convenience methods for chart drawing
//

#import <Cocoa/Cocoa.h>

@interface NSBezierPath (CHAdditions)

// Create paths for common shapes
+ (NSBezierPath *)ch_bezierPathWithArrowFromPoint:(NSPoint)startPoint
                                          toPoint:(NSPoint)endPoint
                                       headLength:(CGFloat)headLength
                                        headAngle:(CGFloat)headAngle;

+ (NSBezierPath *)ch_bezierPathWithStarInRect:(NSRect)rect
                                   pointCount:(NSInteger)pointCount
                                  innerRadius:(CGFloat)innerRadius;

+ (NSBezierPath *)ch_bezierPathWithPolygonInRect:(NSRect)rect
                                           sides:(NSInteger)sides;

+ (NSBezierPath *)ch_bezierPathWithCrossInRect:(NSRect)rect
                                      thickness:(CGFloat)thickness;

// Smooth path creation
+ (NSBezierPath *)ch_smoothPathThroughPoints:(NSArray<NSValue *> *)points;

// Path manipulation
- (void)ch_addDashedBorderWithPattern:(NSArray<NSNumber *> *)pattern;

// Rounded corners options
typedef NS_OPTIONS(NSUInteger, CHRoundedCorners) {
    CHRoundedCornerTopLeft     = 1 << 0,
    CHRoundedCornerTopRight    = 1 << 1,
    CHRoundedCornerBottomLeft  = 1 << 2,
    CHRoundedCornerBottomRight = 1 << 3,
    CHRoundedCornerAll = CHRoundedCornerTopLeft | CHRoundedCornerTopRight | CHRoundedCornerBottomLeft | CHRoundedCornerBottomRight
};

- (NSBezierPath *)ch_pathWithRoundedCorners:(CHRoundedCorners)corners
                                      radius:(CGFloat)radius;

// Drawing utilities
- (void)ch_fillWithGradient:(NSGradient *)gradient
                      angle:(CGFloat)angle;

- (void)ch_strokeWithGradient:(NSGradient *)gradient
                        angle:(CGFloat)angle
                    lineWidth:(CGFloat)lineWidth;

// Shadow drawing
- (void)ch_drawWithInnerShadow:(NSShadow *)shadow;

// Animation support
- (NSBezierPath *)ch_interpolatedPathToPath:(NSBezierPath *)toPath
                                   progress:(CGFloat)progress;

// Conversion
- (CGPathRef)ch_CGPath CF_RETURNS_RETAINED;

@end
