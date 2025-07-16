//
//  CHChartCore.m
//  ChartWidget
//
//  Implementation of core chart engine
//

#import "CHChartCore.h"
#import "CHChartConfiguration.h"
#import "CHChartData.h"
#import "CHDataPoint.h"
#import "CHChartUtils.h"

@interface CHChartCore ()
@property (nonatomic, readwrite) CGFloat minX;
@property (nonatomic, readwrite) CGFloat maxX;
@property (nonatomic, readwrite) CGFloat minY;
@property (nonatomic, readwrite) CGFloat maxY;
@end

@implementation CHChartCore

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithConfiguration:[CHChartConfiguration defaultConfiguration]];
}

- (instancetype)initWithConfiguration:(CHChartConfiguration *)configuration {
    self = [super init];
    if (self) {
        _configuration = configuration;
        [self resetBounds];
    }
    return self;
}

- (void)resetBounds {
    self.minX = 0;
    self.maxX = 1;
    self.minY = 0;
    self.maxY = 1;
}

#pragma mark - Data Processing

- (void)processData:(CHChartData *)data {
    self.chartData = data;
    [self calculateDataBounds];
    
    if (data.shouldNormalizeData) {
        [self normalizeData];
    }
}

- (void)calculateDataBounds {
    if (!self.chartData || self.chartData.seriesCount == 0) {
        [self resetBounds];
        return;
    }
    
    self.minX = CGFLOAT_MAX;
    self.maxX = -CGFLOAT_MAX;
    self.minY = CGFLOAT_MAX;
    self.maxY = -CGFLOAT_MAX;
    
    for (NSInteger seriesIndex = 0; seriesIndex < self.chartData.seriesCount; seriesIndex++) {
        NSArray<CHDataPoint *> *series = [self.chartData seriesAtIndex:seriesIndex];
        
        for (CHDataPoint *point in series) {
            self.minX = MIN(self.minX, point.x);
            self.maxX = MAX(self.maxX, point.x);
            self.minY = MIN(self.minY, point.y);
            self.maxY = MAX(self.maxY, point.y);
        }
    }
    
    // Apply padding
    CGFloat xPadding = (self.maxX - self.minX) * 0.05;
    CGFloat yPadding = (self.maxY - self.minY) * 0.1;
    
    if (xPadding == 0) xPadding = 0.5;
    if (yPadding == 0) yPadding = 0.5;
    
    self.minX -= xPadding;
    self.maxX += xPadding;
    self.minY -= yPadding;
    self.maxY += yPadding;
    
    // Apply custom bounds if set
    if (self.chartData.customMinX != CGFLOAT_MAX) {
        self.minX = self.chartData.customMinX;
    }
    if (self.chartData.customMaxX != CGFLOAT_MAX) {
        self.maxX = self.chartData.customMaxX;
    }
    if (self.chartData.customMinY != CGFLOAT_MAX) {
        self.minY = self.chartData.customMinY;
    }
    if (self.chartData.customMaxY != CGFLOAT_MAX) {
        self.maxY = self.chartData.customMaxY;
    }
    
    // Ensure we don't have zero range
    if (self.maxX == self.minX) {
        self.minX -= 0.5;
        self.maxX += 0.5;
    }
    if (self.maxY == self.minY) {
        self.minY -= 0.5;
        self.maxY += 0.5;
    }
}

- (void)normalizeData {
    if (!self.chartData || self.maxY == self.minY) return;
    
    CGFloat range = self.maxY - self.minY;
    
    for (NSInteger seriesIndex = 0; seriesIndex < self.chartData.seriesCount; seriesIndex++) {
        NSArray<CHDataPoint *> *series = [self.chartData seriesAtIndex:seriesIndex];
        
        for (CHDataPoint *point in series) {
            point.y = (point.y - self.minY) / range;
        }
    }
    
    // Update bounds after normalization
    self.minY = 0;
    self.maxY = 1;
}

#pragma mark - Coordinate Transformation

- (CGPoint)viewPointForDataPoint:(CHDataPoint *)dataPoint inRect:(CGRect)rect {
    CGFloat xScale = [self xScaleForRect:rect];
    CGFloat yScale = [self yScaleForRect:rect];
    
    CGFloat x = rect.origin.x + (dataPoint.x - self.minX) * xScale;
    CGFloat y = rect.origin.y + rect.size.height - ((dataPoint.y - self.minY) * yScale);
    
    return CGPointMake(x, y);
}

- (CHDataPoint *)dataPointForViewPoint:(CGPoint)viewPoint inRect:(CGRect)rect {
    CGFloat xScale = [self xScaleForRect:rect];
    CGFloat yScale = [self yScaleForRect:rect];
    
    CGFloat dataX = ((viewPoint.x - rect.origin.x) / xScale) + self.minX;
    CGFloat dataY = ((rect.origin.y + rect.size.height - viewPoint.y) / yScale) + self.minY;
    
    return [CHDataPoint dataPointWithX:dataX y:dataY];
}

- (CGFloat)xScaleForRect:(CGRect)rect {
    if (self.maxX == self.minX) return 1.0;
    return rect.size.width / (self.maxX - self.minX);
}

- (CGFloat)yScaleForRect:(CGRect)rect {
    if (self.maxY == self.minY) return 1.0;
    return rect.size.height / (self.maxY - self.minY);
}

#pragma mark - Grid and Axis Calculations

- (NSArray<NSNumber *> *)calculateXAxisTickValues {
    return [CHChartUtils niceTickValuesForMin:self.minX
                                          max:self.maxX
                                        count:self.configuration.xAxisLabelCount];
}

- (NSArray<NSNumber *> *)calculateYAxisTickValues {
    return [CHChartUtils niceTickValuesForMin:self.minY
                                          max:self.maxY
                                        count:self.configuration.yAxisLabelCount];
}

- (NSArray<NSString *> *)formattedXAxisLabels {
    NSArray<NSNumber *> *tickValues = [self calculateXAxisTickValues];
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    
    for (NSNumber *value in tickValues) {
        NSString *label = [CHChartUtils formattedStringForNumber:[value doubleValue]];
        [labels addObject:label];
    }
    
    return labels;
}

- (NSArray<NSString *> *)formattedYAxisLabels {
    NSArray<NSNumber *> *tickValues = [self calculateYAxisTickValues];
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    
    for (NSNumber *value in tickValues) {
        NSString *label = [CHChartUtils formattedStringForNumber:[value doubleValue]];
        [labels addObject:label];
    }
    
    return labels;
}

#pragma mark - Hit Testing

- (CHDataPoint *)dataPointAtLocation:(CGPoint)location
                              inRect:(CGRect)rect
                           tolerance:(CGFloat)tolerance {
    if (!self.chartData) return nil;
    
    CHDataPoint *closestPoint = nil;
    CGFloat minDistance = tolerance;
    
    for (NSInteger seriesIndex = 0; seriesIndex < self.chartData.seriesCount; seriesIndex++) {
        NSArray<CHDataPoint *> *series = [self.chartData seriesAtIndex:seriesIndex];
        
        for (CHDataPoint *point in series) {
            CGPoint viewPoint = [self viewPointForDataPoint:point inRect:rect];
            CGFloat distance = hypot(location.x - viewPoint.x, location.y - viewPoint.y);
            
            if (distance < minDistance) {
                minDistance = distance;
                closestPoint = point;
            }
        }
    }
    
    return closestPoint;
}

#pragma mark - Validation

- (BOOL)validateData:(CHChartData *)data error:(NSError **)error {
    if (!data) {
        if (error) {
            *error = [NSError errorWithDomain:@"CHChartCore"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Data is nil"}];
        }
        return NO;
    }
    
    if (data.seriesCount == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"CHChartCore"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"No data series found"}];
        }
        return NO;
    }
    
    // Check for empty series
    for (NSInteger i = 0; i < data.seriesCount; i++) {
        NSArray<CHDataPoint *> *series = [data seriesAtIndex:i];
        if (series.count == 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"CHChartCore"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithFormat:@"Series %ld is empty", (long)i]}];
            }
            return NO;
        }
    }
    
    return YES;
}

@end
