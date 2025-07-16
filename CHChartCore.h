//
//  CHChartCore.h
//  ChartWidget
//
//  Core engine for chart calculations and coordination
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@class CHChartConfiguration;
@class CHChartData;
@class CHDataPoint;

@interface CHChartCore : NSObject

// Configuration
@property (nonatomic, strong) CHChartConfiguration *configuration;

// Data
@property (nonatomic, strong) CHChartData *chartData;

// Calculated bounds
@property (nonatomic, readonly) CGFloat minX;
@property (nonatomic, readonly) CGFloat maxX;
@property (nonatomic, readonly) CGFloat minY;
@property (nonatomic, readonly) CGFloat maxY;

// Initialization
- (instancetype)initWithConfiguration:(CHChartConfiguration *)configuration;

// Data processing
- (void)processData:(CHChartData *)data;
- (void)calculateDataBounds;
- (void)normalizeData;

// Coordinate transformation
- (CGPoint)viewPointForDataPoint:(CHDataPoint *)dataPoint inRect:(CGRect)rect;
- (CHDataPoint *)dataPointForViewPoint:(CGPoint)viewPoint inRect:(CGRect)rect;
- (CGFloat)xScaleForRect:(CGRect)rect;
- (CGFloat)yScaleForRect:(CGRect)rect;

// Grid and axis calculations
- (NSArray<NSNumber *> *)calculateXAxisTickValues;
- (NSArray<NSNumber *> *)calculateYAxisTickValues;
- (NSArray<NSString *> *)formattedXAxisLabels;
- (NSArray<NSString *> *)formattedYAxisLabels;

// Hit testing
- (CHDataPoint *)dataPointAtLocation:(CGPoint)location
                              inRect:(CGRect)rect
                           tolerance:(CGFloat)tolerance;

// Validation
- (BOOL)validateData:(CHChartData *)data error:(NSError **)error;

@end
