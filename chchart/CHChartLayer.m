//
//  CHChartLayer.m
//  ChartWidget
//
//  Implementation of CALayer subclass for chart rendering
//

#import "CHChartLayer.h"
#import "CHChartConfiguration.h"
#import "CHChartData.h"
#import "CHChartRenderer.h"

@interface CHChartLayer ()
@property (nonatomic) BOOL needsRedraw;
@property (nonatomic, strong) NSTimer *animationTimer;
@property (nonatomic) CFTimeInterval animationStartTime;
@property (nonatomic) CFTimeInterval animationDuration;
@property (nonatomic) CGFloat animationFromProgress;
@property (nonatomic) CGFloat animationToProgress;
@property (nonatomic, copy) void (^animationCompletion)(void);
@end

@implementation CHChartLayer

#pragma mark - Initialization

+ (instancetype)layerWithType:(CHChartLayerType)type {
    return [[self alloc] initWithLayerType:type];
}

- (instancetype)init {
    return [self initWithLayerType:CHChartLayerTypeData];
}

- (instancetype)initWithLayerType:(CHChartLayerType)type {
    self = [super init];
    if (self) {
        _layerType = type;
        _animationProgress = 1.0;
        _isAnimating = NO;
        
        // FIX: Utilizza le proprietà invece delle variabili di istanza
        self.shouldRasterize = NO;
        self.drawsAsynchronously = YES;
        _needsRedraw = YES;
        
        [self setupLayerProperties];
    }
    return self;
}

- (void)setupLayerProperties {
    self.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    self.needsDisplayOnBoundsChange = YES;
    
    switch (self.layerType) {
        case CHChartLayerTypeBackground:
            self.zPosition = -100;
            self.shouldRasterize = YES;
            break;
            
        case CHChartLayerTypeGrid:
            self.zPosition = -50;
            self.shouldRasterize = YES;
            break;
            
        case CHChartLayerTypeAxes:
            self.zPosition = -40;
            self.shouldRasterize = YES;
            break;
            
        case CHChartLayerTypeData:
            self.zPosition = 0;
            break;
            
        case CHChartLayerTypeOverlay:
            self.zPosition = 50;
            break;
            
        case CHChartLayerTypeAnimation:
            self.zPosition = 100;
            break;
    }
}

#pragma mark - Properties

- (void)setConfiguration:(CHChartConfiguration *)configuration {
    _configuration = configuration;
    [self setNeedsRedraw];
}

- (void)setChartData:(CHChartData *)chartData {
    _chartData = chartData;
    [self setNeedsRedraw];
}

- (void)setRenderer:(CHChartRenderer *)renderer {
    _renderer = renderer;
    [self setNeedsRedraw];
}

#pragma mark - Drawing

- (void)setNeedsRedraw {
    self.needsRedraw = YES;
    [self setNeedsDisplay];
}

- (void)redrawIfNeeded {
    if (self.needsRedraw) {
        [self setNeedsDisplay];
        self.needsRedraw = NO;
    }
}

- (void)drawInContext:(CGContextRef)ctx {
    if (!self.configuration || !self.renderer) return;
    
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    CGRect bounds = self.bounds;
    
    switch (self.layerType) {
        case CHChartLayerTypeBackground:
            [self drawBackgroundInRect:bounds context:nsContext];
            break;
            
        case CHChartLayerTypeGrid:
            [self.renderer drawGridInRect:bounds context:nsContext];
            break;
            
        case CHChartLayerTypeAxes:
            [self.renderer drawAxesInRect:bounds context:nsContext];
            [self.renderer drawLabelsInRect:bounds context:nsContext];
            break;
            
        case CHChartLayerTypeData:
            [self.renderer drawInRect:bounds
                             context:nsContext
                            animated:self.isAnimating
                            progress:self.animationProgress];
            break;
            
        case CHChartLayerTypeOverlay:
            // Draw overlays like tooltips, selection highlights
            break;
            
        case CHChartLayerTypeAnimation:
            // Special layer for animation effects
            break;
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawBackgroundInRect:(CGRect)rect context:(NSGraphicsContext *)context {
    [self.configuration.backgroundColor set];
    NSRectFill(rect);
}

#pragma mark - Animation

- (void)animateFromProgress:(CGFloat)fromProgress
                 toProgress:(CGFloat)toProgress
                   duration:(NSTimeInterval)duration {
    [self animateFromProgress:fromProgress
                   toProgress:toProgress
                     duration:duration
                   completion:nil];
}

- (void)animateFromProgress:(CGFloat)fromProgress
                 toProgress:(CGFloat)toProgress
                   duration:(NSTimeInterval)duration
                 completion:(void (^)(void))completion {
    
    if (self.isAnimating) {
        [self stopAnimation];
    }
    
    self.animationFromProgress = fromProgress;
    self.animationToProgress = toProgress;
    self.animationProgress = fromProgress;
    self.animationDuration = duration;
    self.animationCompletion = completion;
    self.isAnimating = YES;
    
    if (duration <= 0) {
        self.animationProgress = toProgress;
        [self setNeedsDisplay];
        if (completion) completion();
        return;
    }
    
    // Create animation timer for smooth animation (60 FPS)
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0
                                                           target:self
                                                         selector:@selector(updateAnimation:)
                                                         userInfo:nil
                                                          repeats:YES];
    self.animationStartTime = CACurrentMediaTime();
}

- (void)updateAnimation:(NSTimer *)timer {
    CFTimeInterval elapsed = CACurrentMediaTime() - self.animationStartTime;
    CGFloat t = MIN(elapsed / self.animationDuration, 1.0);
    
    // Apply easing
    t = [self easeInOutQuad:t];
    
    self.animationProgress = self.animationFromProgress +
                            (self.animationToProgress - self.animationFromProgress) * t;
    
    [self setNeedsDisplay];
    
    if (t >= 1.0) {
        [self stopAnimation];
        if (self.animationCompletion) {
            self.animationCompletion();
            self.animationCompletion = nil;
        }
    }
}

- (void)stopAnimation {
    if (self.animationTimer) {
        [self.animationTimer invalidate];
        self.animationTimer = nil;
    }
    self.isAnimating = NO;
}

- (CGFloat)easeInOutQuad:(CGFloat)t {
    if (t < 0.5) {
        return 2 * t * t;
    } else {
        return -1 + (4 - 2 * t) * t;
    }
}

#pragma mark - Hit Testing

- (BOOL)containsPoint:(CGPoint)point {
    return CGRectContainsPoint(self.bounds, point);
}

- (CALayer *)hitTest:(CGPoint)point {
    if (![self containsPoint:point]) return nil;
    
    // Check sublayers in reverse order (top to bottom)
    for (CALayer *sublayer in [self.sublayers reverseObjectEnumerator]) {
        CGPoint convertedPoint = [self convertPoint:point toLayer:sublayer];
        CALayer *hitLayer = [sublayer hitTest:convertedPoint];
        if (hitLayer) return hitLayer;
    }
    
    return self;
}

#pragma mark - Layer Delegate

- (id<CAAction>)actionForKey:(NSString *)event {
    // Disable implicit animations for certain properties
    if ([event isEqualToString:@"bounds"] ||
        [event isEqualToString:@"position"] ||
        [event isEqualToString:@"contents"]) {
        return (id<CAAction>)[NSNull null];
    }
    return [super actionForKey:event];
}

@end
