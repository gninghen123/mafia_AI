//
//  ChartAnnotationRenderer.m
//  TradingApp
//
//  Annotation rendering engine implementation with CALayer-based drawing
//  ✅ REFACTORED: Direct drawing approach following AlertRenderer pattern
//

#import "ChartAnnotationRenderer.h"
#import "ChartAnnotationsManager.h"
#import "ChartPanelView.h"
#import "SharedXCoordinateContext.h"
#import "PanelYCoordinateContext.h"
#import <QuartzCore/QuartzCore.h>

// Constants
static const CGFloat ANNOTATION_MARKER_SIZE = 20.0;
static const CGFloat ANNOTATION_MARKER_RADIUS = 10.0;
static const CGFloat ANNOTATION_HIT_TOLERANCE = 15.0;
static const CGFloat ANNOTATION_Y_POSITION_RATIO = 0.95; // Position near top of panel

@interface ChartAnnotationRenderer ()


@end

@implementation ChartAnnotationRenderer

#pragma mark - Initialization

- (instancetype)initWithPanelView:(ChartPanelView *)panelView
                          manager:(ChartAnnotationsManager *)manager {
    self = [super init];
    if (self) {
        _panelView = panelView;
        _manager = manager;
        _visibleAnnotations = [NSMutableArray array];
        
        // ✅ CRITICAL: Link coordinate contexts
        _sharedXContext = panelView.sharedXContext;
        _panelYContext = panelView.panelYContext;
        
        [self setupLayersInPanelView];
        
        NSLog(@"📍 ChartAnnotationRenderer: Initialized for panel %@", panelView.panelType);
    }
    return self;
}

#pragma mark - Layer Management

- (void)setupLayersInPanelView {
    // Annotations layer
    self.annotationsLayer = [CALayer layer];
    self.annotationsLayer.delegate = self;
    self.annotationsLayer.needsDisplayOnBoundsChange = YES;
    
    // Insert above crosshair but below alerts
    [self.panelView.layer insertSublayer:self.annotationsLayer above:self.panelView.crosshairLayer];
    
    [self updateLayerFrames];
    
    NSLog(@"🎯 ChartAnnotationRenderer: Layers setup completed");
}

- (void)updateLayerFrames {
    CGRect panelBounds = self.panelView.bounds;
    self.annotationsLayer.frame = panelBounds;
}

#pragma mark - Data Management

- (void)renderAllAnnotations {
    if (!self.manager) {
        NSLog(@"⚠️ ChartAnnotationRenderer: No manager available");
        return;
    }
    
    // Get filtered annotations from manager
    NSArray<ChartAnnotation *> *allAnnotations = [self.manager filteredAnnotations];
    
    // Filter to only visible annotations (within chart date range)
    NSMutableArray *visible = [NSMutableArray array];
    for (ChartAnnotation *annotation in allAnnotations) {
        if ([self isDateVisible:annotation.date]) {
            [visible addObject:annotation];
        }
    }
    
    self.visibleAnnotations = visible;
    
    [self invalidateAnnotationsLayer];
    
    NSLog(@"📍 ChartAnnotationRenderer: Prepared %lu visible annotations",
          (unsigned long)self.visibleAnnotations.count);
}

- (void)clearAllAnnotations {
    [self.visibleAnnotations removeAllObjects];
    [self invalidateAnnotationsLayer];
}

#pragma mark - Rendering

- (void)invalidateAnnotationsLayer {
    [self.annotationsLayer setNeedsDisplay];
}

#pragma mark - CALayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    if (layer != self.annotationsLayer) {
        return;
    }
    
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    
    // Verify coordinate contexts are available
    if (!self.sharedXContext || !self.panelYContext) {
        NSLog(@"⚠️ AnnotationRenderer: Missing coordinate contexts - skipping draw");
        [NSGraphicsContext restoreGraphicsState];
        return;
    }
    
    // Draw all visible annotations
    [self drawAllAnnotations];
    
    [NSGraphicsContext restoreGraphicsState];
}

#pragma mark - Drawing Implementation

- (void)drawAllAnnotations {
    if (self.visibleAnnotations.count == 0) {
        return;
    }
    
    for (ChartAnnotation *annotation in self.visibleAnnotations) {
        [self drawAnnotation:annotation];
    }
    
    NSLog(@"🎨 ChartAnnotationRenderer: Drew %lu annotations",
          (unsigned long)self.visibleAnnotations.count);
}

- (void)drawAnnotation:(ChartAnnotation *)annotation {
    // Get X position from date
    CGFloat x = [self screenXForDate:annotation.date];
    if (x < 0 || x > self.panelView.bounds.size.width) {
        return; // Outside visible area
    }
    
    // Position near top of panel
    CGFloat y = self.panelView.bounds.size.height * ANNOTATION_Y_POSITION_RATIO;
    NSPoint markerCenter = NSMakePoint(x, y);
    
    // Draw marker circle
    [self drawMarkerCircle:markerCenter annotation:annotation];
    
    // Draw icon/text inside circle
    [self drawMarkerIcon:markerCenter annotation:annotation];
    
    // If hovered, draw additional info
    if (annotation == self.hoveredAnnotation) {
        [self drawHoverInfo:markerCenter annotation:annotation];
    }
}

- (void)drawMarkerCircle:(NSPoint)center annotation:(ChartAnnotation *)annotation {
    NSRect circleRect = NSMakeRect(center.x - ANNOTATION_MARKER_RADIUS,
                                   center.y - ANNOTATION_MARKER_RADIUS,
                                   ANNOTATION_MARKER_SIZE,
                                   ANNOTATION_MARKER_SIZE);
    
    NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    
    // Fill color based on annotation type/priority
    NSColor *fillColor = [self colorForAnnotation:annotation];
    [fillColor setFill];
    [circlePath fill];
    
    // Stroke for contrast
    [[NSColor whiteColor] setStroke];
    circlePath.lineWidth = 2.0;
    [circlePath stroke];
    
    // Optional: Pulse effect for high priority
    if (annotation.priority == ChartAnnotationPriorityCritical) {
        // Draw outer ring for pulse effect
        NSRect outerRect = NSInsetRect(circleRect, -3, -3);
        NSBezierPath *outerPath = [NSBezierPath bezierPathWithOvalInRect:outerRect];
        [[fillColor colorWithAlphaComponent:0.3] setStroke];
        outerPath.lineWidth = 2.0;
        [outerPath stroke];
    }
}

- (void)drawMarkerIcon:(NSPoint)center annotation:(ChartAnnotation *)annotation {
    // Draw icon text (emoji) centered in circle
    NSString *iconText = annotation.icon ?: @"📌";
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    
    NSSize textSize = [iconText sizeWithAttributes:attributes];
    NSPoint textPoint = NSMakePoint(center.x - textSize.width / 2,
                                    center.y - textSize.height / 2);
    
    [iconText drawAtPoint:textPoint withAttributes:attributes];
}

- (void)drawHoverInfo:(NSPoint)markerCenter annotation:(ChartAnnotation *)annotation {
    // Draw tooltip box below marker
    NSString *tooltipText = annotation.title ?: @"Annotation";
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };
    
    NSSize textSize = [tooltipText sizeWithAttributes:attributes];
    CGFloat padding = 6;
    CGFloat tooltipWidth = textSize.width + padding * 2;
    CGFloat tooltipHeight = textSize.height + padding * 2;
    
    // Position below marker
    CGFloat tooltipX = markerCenter.x - tooltipWidth / 2;
    CGFloat tooltipY = markerCenter.y - ANNOTATION_MARKER_RADIUS - tooltipHeight - 5;
    
    // Ensure tooltip stays within bounds
    tooltipX = MAX(5, MIN(tooltipX, self.panelView.bounds.size.width - tooltipWidth - 5));
    
    NSRect tooltipRect = NSMakeRect(tooltipX, tooltipY, tooltipWidth, tooltipHeight);
    
    // Draw background
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:tooltipRect
                                                           xRadius:4
                                                           yRadius:4];
    [[NSColor controlBackgroundColor] setFill];
    [bgPath fill];
    
    // Draw border
    [[NSColor separatorColor] setStroke];
    bgPath.lineWidth = 1.0;
    [bgPath stroke];
    
    // Draw text
    NSPoint textPoint = NSMakePoint(tooltipX + padding, tooltipY + padding);
    [tooltipText drawAtPoint:textPoint withAttributes:attributes];
    
    // Draw small arrow pointing to marker
    [self drawTooltipArrow:tooltipRect markerCenter:markerCenter];
}

- (void)drawTooltipArrow:(NSRect)tooltipRect markerCenter:(NSPoint)markerCenter {
    // Small triangle pointing down from tooltip to marker
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    
    CGFloat arrowWidth = 8;
    CGFloat arrowHeight = 5;
    CGFloat centerX = NSMidX(tooltipRect);
    CGFloat bottomY = NSMinY(tooltipRect);
    
    [arrow moveToPoint:NSMakePoint(centerX - arrowWidth/2, bottomY)];
    [arrow lineToPoint:NSMakePoint(centerX, bottomY - arrowHeight)];
    [arrow lineToPoint:NSMakePoint(centerX + arrowWidth/2, bottomY)];
    [arrow closePath];
    
    [[NSColor controlBackgroundColor] setFill];
    [arrow fill];
    
    [[NSColor separatorColor] setStroke];
    arrow.lineWidth = 1.0;
    [arrow stroke];
}

#pragma mark - Styling

- (NSColor *)colorForAnnotation:(ChartAnnotation *)annotation {
    // Return custom color if set
    if (annotation.color) {
        return annotation.color;
    }
    
    // Default colors by type
    switch (annotation.type) {
        case ChartAnnotationTypeNews:
            return [NSColor systemBlueColor];
            
        case ChartAnnotationTypeNote:
            return [NSColor systemYellowColor];
            
        case ChartAnnotationTypeUserMessage:
            return [NSColor systemGreenColor];
            
        case ChartAnnotationTypeAlert:
            return [NSColor systemRedColor];
            
        case ChartAnnotationTypeEvent:
            return [NSColor systemPurpleColor];
            
        default:
            return [NSColor systemGrayColor];
    }
}

#pragma mark - Coordinate Conversion

- (CGFloat)screenXForDate:(NSDate *)date {
    if (!self.sharedXContext || !date) {
        return -9999;
    }
    
    return [self.sharedXContext screenXForDate:date];
}

- (BOOL)isDateVisible:(NSDate *)date {
    if (!self.sharedXContext || !date) {
        return NO;
    }
    
    CGFloat x = [self screenXForDate:date];
    return (x >= 0 && x <= self.panelView.bounds.size.width);
}

#pragma mark - Hit Testing

- (nullable ChartAnnotation *)annotationAtScreenPoint:(NSPoint)screenPoint
                                            tolerance:(CGFloat)tolerance {
    CGFloat y = self.panelView.bounds.size.height * ANNOTATION_Y_POSITION_RATIO;
    
    for (ChartAnnotation *annotation in self.visibleAnnotations) {
        CGFloat x = [self screenXForDate:annotation.date];
        
        // Check if point is within tolerance of marker
        CGFloat distance = hypot(screenPoint.x - x, screenPoint.y - y);
        if (distance <= tolerance) {
            return annotation;
        }
    }
    
    return nil;
}

- (NSArray<ChartAnnotation *> *)annotationsNearPoint:(NSPoint)screenPoint
                                           tolerance:(CGFloat)tolerance {
    NSMutableArray *nearAnnotations = [NSMutableArray array];
    CGFloat y = self.panelView.bounds.size.height * ANNOTATION_Y_POSITION_RATIO;
    
    for (ChartAnnotation *annotation in self.visibleAnnotations) {
        CGFloat x = [self screenXForDate:annotation.date];
        
        CGFloat distance = hypot(screenPoint.x - x, screenPoint.y - y);
        if (distance <= tolerance) {
            [nearAnnotations addObject:annotation];
        }
    }
    
    return [nearAnnotations copy];
}

#pragma mark - Interactive Feedback

- (void)updateHoverAtPoint:(NSPoint)screenPoint {
    ChartAnnotation *annotation = [self annotationAtScreenPoint:screenPoint
                                                      tolerance:ANNOTATION_HIT_TOLERANCE];
    
    if (annotation != self.hoveredAnnotation) {
        self.hoveredAnnotation = annotation;
        [self invalidateAnnotationsLayer];
        
        if (annotation) {
            NSLog(@"🔍 Hovering annotation: %@", annotation.title);
        }
    }
}

- (void)clearHover {
    if (self.hoveredAnnotation) {
        self.hoveredAnnotation = nil;
        [self invalidateAnnotationsLayer];
    }
}

@end
