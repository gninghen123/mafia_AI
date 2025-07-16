//
//  CHChartView.m
//  ChartWidget
//
//  Implementation of CHChartView
//

#import "CHChartView.h"
#import "CHChartConfiguration.h"
#import "CHDataPoint.h"
#import "CHChartRenderer.h"
#import "CHLineChartRenderer.h"
#import "CHBarChartRenderer.h"

@interface CHChartView () {
    NSTrackingArea *_trackingArea;
    BOOL _needsDataReload;
}

@property (nonatomic, strong) CHChartRenderer *renderer;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<CHDataPoint *> *> *dataPoints;
@property (nonatomic, strong) CHDataPoint *selectedDataPoint;
@property (nonatomic, strong) CHDataPoint *hoveredDataPoint;
@property (nonatomic) BOOL isAnimating;

// Animation support
@property (nonatomic, strong) NSTimer *animationTimer;
@property (nonatomic) CGFloat animationProgress;

@end

@implementation CHChartView

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    // Initialize properties
    _configuration = [CHChartConfiguration defaultConfiguration];
    _dataPoints = [NSMutableArray array];
    _needsDataReload = YES;
    _isAnimating = NO;
    _animationProgress = 0.0;
    
    // Set up view
    self.wantsLayer = YES;
    self.layer.backgroundColor = _configuration.backgroundColor.CGColor;
    
    // We'll create the renderer later based on chart type
    _renderer = nil;
}

#pragma mark - View Lifecycle

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    
    if (self.window) {
        [self updateTrackingAreas];
    }
}

- (void)updateTrackingAreas {
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
    }
    
    if (self.configuration.interactive) {
        NSTrackingAreaOptions options = NSTrackingActiveInKeyWindow |
                                       NSTrackingMouseEnteredAndExited |
                                       NSTrackingMouseMoved;
        
        _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                     options:options
                                                       owner:self
                                                    userInfo:nil];
        [self addTrackingArea:_trackingArea];
    }
}

#pragma mark - Properties

- (void)setConfiguration:(CHChartConfiguration *)configuration {
    _configuration = [configuration copy];
    
    // Update view appearance
    self.layer.backgroundColor = _configuration.backgroundColor.CGColor;
    
    // Create appropriate renderer based on chart type
    [self createRenderer];
    
    // Reload data with new configuration
    [self setNeedsDisplay:YES];
    [self updateTrackingAreas];
}

- (void)setDataSource:(id<CHChartDataSource>)dataSource {
    _dataSource = dataSource;
    _needsDataReload = YES;
    [self setNeedsDisplay:YES];
}

#pragma mark - Data Management

- (void)reloadData {
    [self reloadDataAnimated:self.configuration.animated];
}

- (void)reloadDataAnimated:(BOOL)animated {
    if (!self.dataSource) return;
    
    // Stop any ongoing animations
    [self stopAllAnimations];
    
    // Clear existing data
    [self.dataPoints removeAllObjects];
    
    // Load new data
    NSInteger seriesCount = [self.dataSource numberOfDataSeriesInChartView:self];
    
    for (NSInteger series = 0; series < seriesCount; series++) {
        NSMutableArray<CHDataPoint *> *seriesData = [NSMutableArray array];
        NSInteger pointCount = [self.dataSource chartView:self numberOfPointsInSeries:series];
        
        for (NSInteger index = 0; index < pointCount; index++) {
            CGFloat y = [self.dataSource chartView:self valueForSeries:series atIndex:index];
            CGFloat x = index; // Default to index
            
            // Check if custom x value is provided
            if ([self.dataSource respondsToSelector:@selector(chartView:xValueForSeries:atIndex:)]) {
                x = [self.dataSource chartView:self xValueForSeries:series atIndex:index];
            }
            
            CHDataPoint *point = [CHDataPoint dataPointWithX:x y:y];
            point.seriesIndex = series;
            point.pointIndex = index;
            
            // Optional label
            if ([self.dataSource respondsToSelector:@selector(chartView:labelForPointInSeries:atIndex:)]) {
                point.label = [self.dataSource chartView:self labelForPointInSeries:series atIndex:index];
            }
            
            // Optional color
            if ([self.dataSource respondsToSelector:@selector(chartView:colorForSeries:)]) {
                point.color = [self.dataSource chartView:self colorForSeries:series];
            } else if (series < self.configuration.seriesColors.count) {
                point.color = self.configuration.seriesColors[series];
            }
            
            [seriesData addObject:point];
        }
        
        [self.dataPoints addObject:seriesData];
    }
    
    _needsDataReload = NO;
    
    // Update renderer with new data
    if (self.renderer) {
        [self.renderer updateWithDataPoints:self.dataPoints configuration:self.configuration];
    }
    
    // Animate if requested
    if (animated && self.configuration.animated) {
        [self startAnimation];
    } else {
        [self setNeedsDisplay:YES];
    }
}

- (void)reloadDataForSeries:(NSInteger)series animated:(BOOL)animated {
    if (!self.dataSource) return;
    if (series < 0 || series >= self.dataPoints.count) return;
    
    // Reload just the specified series
    NSMutableArray<CHDataPoint *> *seriesData = self.dataPoints[series];
    [seriesData removeAllObjects];
    
    NSInteger pointCount = [self.dataSource chartView:self numberOfPointsInSeries:series];
    
    for (NSInteger index = 0; index < pointCount; index++) {
        CGFloat y = [self.dataSource chartView:self valueForSeries:series atIndex:index];
        CGFloat x = index;
        
        if ([self.dataSource respondsToSelector:@selector(chartView:xValueForSeries:atIndex:)]) {
            x = [self.dataSource chartView:self xValueForSeries:series atIndex:index];
        }
        
        CHDataPoint *point = [CHDataPoint dataPointWithX:x y:y];
        point.seriesIndex = series;
        point.pointIndex = index;
        
        [seriesData addObject:point];
    }
    
    // Update renderer
    if (self.renderer) {
        [self.renderer updateWithDataPoints:self.dataPoints configuration:self.configuration];
    }
    
    if (animated && self.configuration.animated) {
        [self startAnimation];
    } else {
        [self setNeedsDisplay:YES];
    }
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Reload data if needed
    if (_needsDataReload) {
        [self reloadData];
    }
    
    // Get graphics context
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    
    // Clear background
    [self.configuration.backgroundColor set];
    NSRectFill(dirtyRect);
    
    // Draw using renderer
    if (self.renderer) {
        CGRect chartArea = [self chartArea];
        [self.renderer drawInRect:chartArea
                        context:context
                        animated:self.isAnimating
                        progress:self.animationProgress];
    }
    
    [context restoreGraphicsState];
}

- (BOOL)isFlipped {
    return YES; // Use top-left origin
}

#pragma mark - Layout

- (CGRect)drawingArea {
    NSEdgeInsets padding = self.configuration.padding;
    return NSInsetRect(self.bounds, padding.left + padding.right, padding.top + padding.bottom);
}

- (CGRect)chartArea {
    CGRect drawingArea = [self drawingArea];
    
    // Reserve space for axes labels if needed
    CGFloat leftMargin = self.configuration.showYAxis && self.configuration.showYLabels ? 40 : 0;
    CGFloat bottomMargin = self.configuration.showXAxis && self.configuration.showXLabels ? 30 : 0;
    
    return CGRectInset(drawingArea, leftMargin, bottomMargin);
}

#pragma mark - Mouse Tracking

- (void)mouseEntered:(NSEvent *)event {
    // Mouse entered view
}

- (void)mouseExited:(NSEvent *)event {
    // Clear hover state
    if (self.hoveredDataPoint) {
        self.hoveredDataPoint = nil;
        
        if ([self.delegate respondsToSelector:@selector(chartViewDidEndHovering:)]) {
            [self.delegate chartViewDidEndHovering:self];
        }
        
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseMoved:(NSEvent *)event {
    if (!self.configuration.interactive) return;
    
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    CHDataPoint *nearestPoint = [self dataPointNearLocation:locationInView];
    
    if (nearestPoint != self.hoveredDataPoint) {
        self.hoveredDataPoint = nearestPoint;
        
        if (nearestPoint && [self.delegate respondsToSelector:@selector(chartView:didHoverOverDataPoint:inSeries:)]) {
            [self.delegate chartView:self didHoverOverDataPoint:nearestPoint inSeries:nearestPoint.seriesIndex];
        }
        
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(NSEvent *)event {
    if (!self.configuration.allowSelection) return;
    
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    CHDataPoint *nearestPoint = [self dataPointNearLocation:locationInView];
    
    if (nearestPoint) {
        BOOL shouldSelect = YES;
        
        if ([self.delegate respondsToSelector:@selector(chartView:shouldSelectDataPoint:inSeries:)]) {
            shouldSelect = [self.delegate chartView:self shouldSelectDataPoint:nearestPoint inSeries:nearestPoint.seriesIndex];
        }
        
        if (shouldSelect) {
            [self selectDataPoint:nearestPoint animated:YES];
        }
    } else {
        [self deselectDataPointAnimated:YES];
    }
}

#pragma mark - Selection

- (void)selectDataPoint:(CHDataPoint *)dataPoint animated:(BOOL)animated {
    if (self.selectedDataPoint == dataPoint) return;
    
    self.selectedDataPoint = dataPoint;
    dataPoint.isSelected = YES;
    
    if ([self.delegate respondsToSelector:@selector(chartView:didSelectDataPoint:inSeries:)]) {
        [self.delegate chartView:self didSelectDataPoint:dataPoint inSeries:dataPoint.seriesIndex];
    }
    
    [self setNeedsDisplay:YES];
}

- (void)deselectDataPointAnimated:(BOOL)animated {
    if (!self.selectedDataPoint) return;
    
    self.selectedDataPoint.isSelected = NO;
    self.selectedDataPoint = nil;
    
    if ([self.delegate respondsToSelector:@selector(chartViewDidDeselectDataPoint:)]) {
        [self.delegate chartViewDidDeselectDataPoint:self];
    }
    
    [self setNeedsDisplay:YES];
}

#pragma mark - Helper Methods

- (CHDataPoint *)dataPointNearLocation:(NSPoint)location {
    // This is a simple implementation - renderer should provide more accurate hit testing
    CGFloat minDistance = CGFLOAT_MAX;
    CHDataPoint *nearestPoint = nil;
    
    for (NSArray<CHDataPoint *> *series in self.dataPoints) {
        for (CHDataPoint *point in series) {
            // Convert data point to view coordinates
            CGPoint viewPoint = [self.renderer viewPointForDataPoint:point inRect:[self chartArea]];
            
            CGFloat distance = hypot(location.x - viewPoint.x, location.y - viewPoint.y);
            if (distance < minDistance && distance < 20) { // 20 points threshold
                minDistance = distance;
                nearestPoint = point;
            }
        }
    }
    
    return nearestPoint;
}

#pragma mark - Animation

- (void)startAnimation {
    if (self.isAnimating) return;
    
    self.isAnimating = YES;
    self.animationProgress = 0.0;
    
    if ([self.delegate respondsToSelector:@selector(chartViewWillBeginAnimating:)]) {
        [self.delegate chartViewWillBeginAnimating:self];
    }
    
    // Create animation timer
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0 // 60 FPS
                                                           target:self
                                                         selector:@selector(updateAnimation:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)updateAnimation:(NSTimer *)timer {
    self.animationProgress += (1.0 / 60.0) / self.configuration.animationDuration;
    
    if (self.animationProgress >= 1.0) {
        self.animationProgress = 1.0;
        [self stopAllAnimations];
        
        if ([self.delegate respondsToSelector:@selector(chartViewDidFinishAnimating:)]) {
            [self.delegate chartViewDidFinishAnimating:self];
        }
    }
    
    [self setNeedsDisplay:YES];
}

- (void)stopAllAnimations {
    if (self.animationTimer) {
        [self.animationTimer invalidate];
        self.animationTimer = nil;
    }
    
    self.isAnimating = NO;
    self.animationProgress = 1.0;
}

#pragma mark - Export

- (NSImage *)chartImage {
    NSImage *image = [[NSImage alloc] initWithSize:self.bounds.size];
    [image lockFocus];
    
    // Draw the chart
    [self drawRect:self.bounds];
    
    [image unlockFocus];
    return image;
}

- (NSData *)chartImageDataWithType:(NSBitmapImageFileType)fileType {
    NSImage *image = [self chartImage];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
    
    NSDictionary *properties = @{};
    if (fileType == NSBitmapImageFileTypeJPEG) {
        properties = @{NSImageCompressionFactor: @0.9};
    }
    
    return [imageRep representationUsingType:fileType properties:properties];
}

#pragma mark - Renderer Management

- (void)createRenderer {
    // Create appropriate renderer based on chart type
    switch (self.configuration.chartType) {
        case CHChartTypeLine:
            self.renderer = [[CHLineChartRenderer alloc] initWithConfiguration:self.configuration];
            break;
            
        case CHChartTypeBar:
        case CHChartTypeArea:  // Area can use bar renderer with modifications
            self.renderer = [[CHBarChartRenderer alloc] initWithConfiguration:self.configuration];
            break;
            
        case CHChartTypeScatter:
            // For now, use line renderer without lines
            self.renderer = [[CHLineChartRenderer alloc] initWithConfiguration:self.configuration];
            ((CHLineChartRenderer *)self.renderer).lineStyle = CHLineChartStyleStraight;
            ((CHLineChartRenderer *)self.renderer).showDataPoints = YES;
            break;
            
        case CHChartTypePie:
            // Not implemented yet
            NSLog(@"Pie chart not implemented yet");
            self.renderer = nil;
            break;
            
        case CHChartTypeCombined:
            // Would need a special combined renderer
            NSLog(@"Combined chart not implemented yet");
            self.renderer = nil;
            break;
            
        default:
            self.renderer = nil;
            break;
    }
}

@end
