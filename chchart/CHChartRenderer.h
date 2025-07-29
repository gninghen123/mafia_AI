//
//  CHChartRenderer.h
//  ChartWidget
//
//  Abstract base class for chart renderers
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@class CHChartConfiguration;
@class CHDataPoint;

@interface CHChartRenderer : NSObject

// Data
@property (nonatomic, strong) NSArray<NSArray<CHDataPoint *> *> *dataPoints;
@property (nonatomic, strong) CHChartConfiguration *configuration;

// Computed properties for data bounds
@property (nonatomic, readonly) CGFloat minX;
@property (nonatomic, readonly) CGFloat maxX;
@property (nonatomic, readonly) CGFloat minY;
@property (nonatomic, readonly) CGFloat maxY;

// Initialization
- (instancetype)initWithConfiguration:(CHChartConfiguration *)configuration;

// Update data
- (void)updateWithDataPoints:(NSArray<NSArray<CHDataPoint *> *> *)dataPoints
               configuration:(CHChartConfiguration *)configuration;

// Drawing - Subclasses must override
- (void)drawInRect:(CGRect)rect
           context:(NSGraphicsContext *)context
          animated:(BOOL)animated
          progress:(CGFloat)progress;

// Coordinate conversion
- (CGPoint)viewPointForDataPoint:(CHDataPoint *)dataPoint inRect:(CGRect)rect;
- (CHDataPoint *)dataPointForViewPoint:(CGPoint)viewPoint inRect:(CGRect)rect;

// Hit testing
- (CHDataPoint *)dataPointAtLocation:(CGPoint)location inRect:(CGRect)rect tolerance:(CGFloat)tolerance;

// Helper methods for subclasses
- (void)drawGridInRect:(CGRect)rect context:(NSGraphicsContext *)context;
- (void)drawAxesInRect:(CGRect)rect context:(NSGraphicsContext *)context;
- (void)drawLabelsInRect:(CGRect)rect context:(NSGraphicsContext *)context;

// Utility methods
- (CGFloat)xScaleForRect:(CGRect)rect;
- (CGFloat)yScaleForRect:(CGRect)rect;
- (CGRect)dataRectForChartRect:(CGRect)rect;

@end
