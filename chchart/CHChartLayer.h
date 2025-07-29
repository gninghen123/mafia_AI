//
//  CHChartLayer.h
//  ChartWidget
//
//  CALayer subclass for high-performance chart rendering
//

#import <QuartzCore/QuartzCore.h>
#import <Cocoa/Cocoa.h>

@class CHChartConfiguration;
@class CHChartData;
@class CHChartRenderer;

typedef NS_ENUM(NSInteger, CHChartLayerType) {
    CHChartLayerTypeBackground,
    CHChartLayerTypeGrid,
    CHChartLayerTypeAxes,
    CHChartLayerTypeData,
    CHChartLayerTypeOverlay,
    CHChartLayerTypeAnimation
};

@interface CHChartLayer : CALayer

// Layer type
@property (nonatomic) CHChartLayerType layerType;

// Configuration
@property (nonatomic, strong) CHChartConfiguration *configuration;

// Data
@property (nonatomic, strong) CHChartData *chartData;

// Renderer
@property (nonatomic, strong) CHChartRenderer *renderer;

// Animation
@property (nonatomic) CGFloat animationProgress;
@property (nonatomic) BOOL isAnimating;

// Performance
@property (nonatomic) BOOL shouldRasterize;
@property (nonatomic) BOOL drawsAsynchronously;

// Initialization
+ (instancetype)layerWithType:(CHChartLayerType)type;
- (instancetype)initWithLayerType:(CHChartLayerType)type;

// Drawing
- (void)setNeedsRedraw;
- (void)redrawIfNeeded;

// Animation
- (void)animateFromProgress:(CGFloat)fromProgress
                 toProgress:(CGFloat)toProgress
                   duration:(NSTimeInterval)duration;

- (void)animateFromProgress:(CGFloat)fromProgress
                 toProgress:(CGFloat)toProgress
                   duration:(NSTimeInterval)duration
                 completion:(void (^)(void))completion;

// Hit testing
- (BOOL)containsPoint:(CGPoint)point;
- (CALayer *)hitTest:(CGPoint)point;

@end
