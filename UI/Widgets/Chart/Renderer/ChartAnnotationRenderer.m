//
//  ChartAnnotationRenderer.m
//  mafia_AI
//
//  Implementation of ChartAnnotationRenderer
//

#import "ChartAnnotationRenderer.h"
#import "ChartAnnotationsManager.h"
#import "ChartPanelView.h"
#import <QuartzCore/QuartzCore.h>

@interface ChartAnnotationRenderer ()

@property (nonatomic, strong, readwrite) NSMutableArray<ChartAnnotationMarker *> *visibleMarkers;

@end

@implementation ChartAnnotationRenderer

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _visibleMarkers = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithPanelView:(ChartPanelView *)panelView
                          manager:(ChartAnnotationsManager *)manager {
    self = [self init];
    if (self) {
        _panelView = panelView;
        _manager = manager;
    }
    return self;
}

#pragma mark - Rendering

- (void)renderInLayer:(CALayer *)layer {
    if (!self.manager || !self.panelView) {
        NSLog(@"⚠️ ChartAnnotationRenderer: Missing manager or panelView");
        return;
    }
    
    self.annotationsLayer = layer;
    
    // Get filtered annotations from manager
    NSArray<ChartAnnotation *> *annotations = [self.manager filteredAnnotations];
    
    NSLog(@"🎨 ChartAnnotationRenderer: Rendering %lu annotations", (unsigned long)annotations.count);
    
    // Clear existing markers
    [self clearAllMarkers];
    
    // Create markers for each annotation
    for (ChartAnnotation *annotation in annotations) {
        
        // Get screen position
        CGPoint position = [self screenPositionForDate:annotation.date];
        
        if (CGPointEqualToPoint(position, CGPointZero)) {
            // Date not visible
            continue;
        }
        
        // Create marker
        ChartAnnotationMarker *marker = [[ChartAnnotationMarker alloc] initWithAnnotation:annotation];
        [marker updatePosition:position];
        
        // Add to panel view
        [self.panelView addSubview:marker];
        [self.visibleMarkers addObject:marker];
    }
    
    NSLog(@"✅ ChartAnnotationRenderer: Displayed %lu markers", (unsigned long)self.visibleMarkers.count);
}

- (void)updateAllMarkerPositions {
    for (ChartAnnotationMarker *marker in self.visibleMarkers) {
        CGPoint newPosition = [self screenPositionForDate:marker.annotation.date];
        
        if (CGPointEqualToPoint(newPosition, CGPointZero)) {
            // No longer visible
            marker.hidden = YES;
        } else {
            marker.hidden = NO;
            [marker updatePosition:newPosition];
        }
    }
    
    NSLog(@"🔄 ChartAnnotationRenderer: Updated %lu marker positions", (unsigned long)self.visibleMarkers.count);
}

- (void)clearAllMarkers {
    for (ChartAnnotationMarker *marker in self.visibleMarkers) {
        [marker removeFromSuperview];
    }
    [self.visibleMarkers removeAllObjects];
    
    NSLog(@"🗑️ ChartAnnotationRenderer: Cleared all markers");
}

- (void)invalidate {
    [self clearAllMarkers];
    
    if (self.annotationsLayer) {
        [self renderInLayer:self.annotationsLayer];
    }
}

#pragma mark - Coordinate Conversion

- (CGPoint)screenPositionForDate:(NSDate *)date {
    if (!self.panelView) {
        return CGPointZero;
    }
    
    // Delegate to ChartPanelView for coordinate conversion
    if ([self.panelView respondsToSelector:@selector(screenPositionForDate:)]) {
        return [self.panelView screenPositionForDate:date];
    }
    
    NSLog(@"⚠️ ChartAnnotationRenderer: PanelView doesn't implement screenPositionForDate:");
    return CGPointZero;
}

- (BOOL)isDateVisible:(NSDate *)date {
    if (!self.panelView) {
        return NO;
    }
    
    if ([self.panelView respondsToSelector:@selector(isDateVisibleInCurrentRange:)]) {
        return [self.panelView isDateVisibleInCurrentRange:date];
    }
    
    return NO;
}

#pragma mark - Interaction

- (nullable ChartAnnotationMarker *)markerAtPoint:(CGPoint)point tolerance:(CGFloat)tolerance {
    for (ChartAnnotationMarker *marker in self.visibleMarkers) {
        if (marker.hidden) continue;
        
        CGFloat distance = hypot(point.x - marker.frame.origin.x,
                                point.y - marker.frame.origin.y);
        
        if (distance <= tolerance) {
            return marker;
        }
    }
    
    return nil;
}

- (NSArray<ChartAnnotationMarker *> *)markersNearPoint:(CGPoint)point tolerance:(CGFloat)tolerance {
    NSMutableArray *nearMarkers = [NSMutableArray array];
    
    for (ChartAnnotationMarker *marker in self.visibleMarkers) {
        if (marker.hidden) continue;
        
        CGFloat distance = hypot(point.x - marker.frame.origin.x,
                                point.y - marker.frame.origin.y);
        
        if (distance <= tolerance) {
            [nearMarkers addObject:marker];
        }
    }
    
    return [nearMarkers copy];
}

@end

#pragma mark - ChartAnnotationMarker Implementation

@implementation ChartAnnotationMarker

- (instancetype)initWithAnnotation:(ChartAnnotation *)annotation {
    self = [super initWithFrame:NSMakeRect(0, 0, 24, 24)];
    if (self) {
        _annotation = annotation;
        [self setupView];
    }
    return self;
}

- (void)setupView {
    self.wantsLayer = YES;
    
    // Create icon layer
    self.iconLayer = [CAShapeLayer layer];
    self.iconLayer.frame = CGRectMake(2, 2, 20, 20);
    
    // Icon based on type
    NSColor *iconColor = [self colorForAnnotationType:self.annotation.type];
    self.iconLayer.fillColor = iconColor.CGColor;
    self.iconLayer.strokeColor = [NSColor whiteColor].CGColor;
    self.iconLayer.lineWidth = 1.5;
    
    // Circle shape
    CGPathRef circlePath = CGPathCreateWithEllipseInRect(CGRectMake(0, 0, 20, 20), NULL);
    self.iconLayer.path = circlePath;
    CGPathRelease(circlePath);
    
    // Shadow
    self.iconLayer.shadowColor = [NSColor blackColor].CGColor;
    self.iconLayer.shadowOpacity = 0.3;
    self.iconLayer.shadowOffset = CGSizeMake(0, -1);
    self.iconLayer.shadowRadius = 2;
    
    [self.layer addSublayer:self.iconLayer];
    
    // Add tracking area for hover
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                                 options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                                                   owner:self
                                                                userInfo:nil];
    [self addTrackingArea:trackingArea];
}

- (void)updatePosition:(CGPoint)position {
    self.chartPosition = position;
    self.frame = NSMakeRect(position.x - 12, position.y - 12, 24, 24);
}

- (void)mouseEntered:(NSEvent *)event {
    [self showPopup];
}

- (void)mouseExited:(NSEvent *)event {
    [self hidePopup];
}

- (void)showPopup {
    if (self.popupLabel) return;
    
    // Create popup label
    self.popupLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(28, -10, 200, 44)];
    self.popupLabel.stringValue = self.annotation.title;
    self.popupLabel.font = [NSFont systemFontOfSize:11];
    self.popupLabel.textColor = [NSColor whiteColor];
    self.popupLabel.backgroundColor = [NSColor colorWithWhite:0.2 alpha:0.95];
    self.popupLabel.bordered = NO;
    self.popupLabel.editable = NO;
    self.popupLabel.selectable = NO;
    self.popupLabel.wantsLayer = YES;
    self.popupLabel.layer.cornerRadius = 4;
    self.popupLabel.alignment = NSTextAlignmentCenter;
    
    [self addSubview:self.popupLabel];
    
    // Animate in
    self.popupLabel.alphaValue = 0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2;
        self.popupLabel.animator.alphaValue = 1.0;
    } completionHandler:nil];
}

- (void)hidePopup {
    if (!self.popupLabel) return;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.15;
        self.popupLabel.animator.alphaValue = 0;
    } completionHandler:^{
        [self.popupLabel removeFromSuperview];
        self.popupLabel = nil;
    }];
}

- (NSColor *)colorForAnnotationType:(ChartAnnotationType)type {
    switch (type) {
        case ChartAnnotationTypeNews:
            return [NSColor systemBlueColor];
        case ChartAnnotationTypeNote:
            return [NSColor systemYellowColor];
        case ChartAnnotationTypeUserMessage:
            return [NSColor systemPurpleColor];
        case ChartAnnotationTypeAlert:
            return [NSColor systemRedColor];
        case ChartAnnotationTypeEvent:
            return [NSColor systemGreenColor];
        default:
            return [NSColor systemGrayColor];
    }
}

@end
