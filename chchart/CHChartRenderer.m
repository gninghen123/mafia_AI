//
//  CHChartRenderer.m
//  ChartWidget
//
//  Implementation of abstract base class for chart renderers
//

#import "CHChartRenderer.h"
#import "CHChartConfiguration.h"
#import "CHDataPoint.h"

@interface CHChartRenderer ()
@property (nonatomic, readwrite) CGFloat minX;
@property (nonatomic, readwrite) CGFloat maxX;
@property (nonatomic, readwrite) CGFloat minY;
@property (nonatomic, readwrite) CGFloat maxY;
@end

@implementation CHChartRenderer

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithConfiguration:[CHChartConfiguration defaultConfiguration]];
}

- (instancetype)initWithConfiguration:(CHChartConfiguration *)configuration {
    self = [super init];
    if (self) {
        _configuration = configuration;
        _dataPoints = @[];
        [self calculateDataBounds];
    }
    return self;
}

#pragma mark - Data Management

- (void)updateWithDataPoints:(NSArray<NSArray<CHDataPoint *> *> *)dataPoints
               configuration:(CHChartConfiguration *)configuration {
    self.dataPoints = dataPoints;
    self.configuration = configuration;
    [self calculateDataBounds];
}

- (void)calculateDataBounds {
    if (self.dataPoints.count == 0) {
        self.minX = 0;
        self.maxX = 1;
        self.minY = 0;
        self.maxY = 1;
        return;
    }
    
    self.minX = CGFLOAT_MAX;
    self.maxX = -CGFLOAT_MAX;
    self.minY = CGFLOAT_MAX;
    self.maxY = -CGFLOAT_MAX;
    
    for (NSArray<CHDataPoint *> *series in self.dataPoints) {
        for (CHDataPoint *point in series) {
            self.minX = MIN(self.minX, point.x);
            self.maxX = MAX(self.maxX, point.x);
            self.minY = MIN(self.minY, point.y);
            self.maxY = MAX(self.maxY, point.y);
        }
    }
    
    // Add some padding to Y axis
    CGFloat yPadding = (self.maxY - self.minY) * 0.1;
    if (yPadding == 0) yPadding = 1; // Handle case where all Y values are the same
    
    self.minY -= yPadding;
    self.maxY += yPadding;
    
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

#pragma mark - Drawing (Must be overridden by subclasses)

- (void)drawInRect:(CGRect)rect
           context:(NSGraphicsContext *)context
          animated:(BOOL)animated
          progress:(CGFloat)progress {
    // Base implementation draws grid and axes
    [self drawGridInRect:rect context:context];
    [self drawAxesInRect:rect context:context];
    [self drawLabelsInRect:rect context:context];
    
    // Subclasses should override to draw actual chart content
}

#pragma mark - Grid Drawing

- (void)drawGridInRect:(CGRect)rect context:(NSGraphicsContext *)context {
    if (self.configuration.gridLines == CHChartGridLinesNone) return;
    
    [context saveGraphicsState];
    
    // Set up grid line appearance
    [self.configuration.gridLineColor set];
    NSBezierPath *gridPath = [NSBezierPath bezierPath];
    [gridPath setLineWidth:self.configuration.gridLineWidth];
    
    if (self.configuration.gridLineDashPattern) {
        CGFloat pattern[self.configuration.gridLineDashPattern.count];
        for (NSInteger i = 0; i < self.configuration.gridLineDashPattern.count; i++) {
            pattern[i] = [self.configuration.gridLineDashPattern[i] floatValue];
        }
        [gridPath setLineDash:pattern count:self.configuration.gridLineDashPattern.count phase:0];
    }
    
    // Draw horizontal grid lines
    if (self.configuration.gridLines & CHChartGridLinesHorizontal) {
        NSInteger lineCount = self.configuration.yAxisLabelCount;
        CGFloat yStep = rect.size.height / (lineCount - 1);
        
        for (NSInteger i = 0; i < lineCount; i++) {
            CGFloat y = rect.origin.y + (i * yStep);
            [gridPath moveToPoint:CGPointMake(rect.origin.x, y)];
            [gridPath lineToPoint:CGPointMake(rect.origin.x + rect.size.width, y)];
        }
    }
    
    // Draw vertical grid lines
    if (self.configuration.gridLines & CHChartGridLinesVertical) {
        NSInteger lineCount = self.configuration.xAxisLabelCount;
        CGFloat xStep = rect.size.width / (lineCount - 1);
        
        for (NSInteger i = 0; i < lineCount; i++) {
            CGFloat x = rect.origin.x + (i * xStep);
            [gridPath moveToPoint:CGPointMake(x, rect.origin.y)];
            [gridPath lineToPoint:CGPointMake(x, rect.origin.y + rect.size.height)];
        }
    }
    
    [gridPath stroke];
    [context restoreGraphicsState];
}

#pragma mark - Axes Drawing

- (void)drawAxesInRect:(CGRect)rect context:(NSGraphicsContext *)context {
    [context saveGraphicsState];
    
    [self.configuration.axisColor set];
    NSBezierPath *axisPath = [NSBezierPath bezierPath];
    [axisPath setLineWidth:1.0];
    
    // Draw X axis
    if (self.configuration.showXAxis) {
        [axisPath moveToPoint:CGPointMake(rect.origin.x, rect.origin.y + rect.size.height)];
        [axisPath lineToPoint:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)];
    }
    
    // Draw Y axis
    if (self.configuration.showYAxis) {
        [axisPath moveToPoint:CGPointMake(rect.origin.x, rect.origin.y)];
        [axisPath lineToPoint:CGPointMake(rect.origin.x, rect.origin.y + rect.size.height)];
    }
    
    [axisPath stroke];
    [context restoreGraphicsState];
}

#pragma mark - Labels Drawing

- (void)drawLabelsInRect:(CGRect)rect context:(NSGraphicsContext *)context {
    [context saveGraphicsState];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: self.configuration.labelFont,
        NSForegroundColorAttributeName: self.configuration.textColor
    };
    
    // Draw Y axis labels
    if (self.configuration.showYAxis && self.configuration.showYLabels) {
        NSInteger labelCount = self.configuration.yAxisLabelCount;
        CGFloat yStep = rect.size.height / (labelCount - 1);
        CGFloat valueStep = (self.maxY - self.minY) / (labelCount - 1);
        
        for (NSInteger i = 0; i < labelCount; i++) {
            CGFloat y = rect.origin.y + rect.size.height - (i * yStep);
            CGFloat value = self.minY + (i * valueStep);
            
            NSString *label = [NSString stringWithFormat:@"%.1f", value];
            NSSize labelSize = [label sizeWithAttributes:attributes];
            
            NSPoint labelPoint = NSMakePoint(rect.origin.x - labelSize.width - 5, y - labelSize.height/2);
            [label drawAtPoint:labelPoint withAttributes:attributes];
        }
    }
    
    // Draw X axis labels
    if (self.configuration.showXAxis && self.configuration.showXLabels) {
        NSInteger labelCount = self.configuration.xAxisLabelCount;
        CGFloat xStep = rect.size.width / (labelCount - 1);
        CGFloat valueStep = (self.maxX - self.minX) / (labelCount - 1);
        
        for (NSInteger i = 0; i < labelCount; i++) {
            CGFloat x = rect.origin.x + (i * xStep);
            CGFloat value = self.minX + (i * valueStep);
            
            NSString *label = [NSString stringWithFormat:@"%.0f", value];
            NSSize labelSize = [label sizeWithAttributes:attributes];
            
            NSPoint labelPoint = NSMakePoint(x - labelSize.width/2, rect.origin.y + rect.size.height + 5);
            [label drawAtPoint:labelPoint withAttributes:attributes];
        }
    }
    
    [context restoreGraphicsState];
}

#pragma mark - Coordinate Conversion

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

#pragma mark - Hit Testing

- (CHDataPoint *)dataPointAtLocation:(CGPoint)location inRect:(CGRect)rect tolerance:(CGFloat)tolerance {
    CHDataPoint *closestPoint = nil;
    CGFloat minDistance = tolerance;
    
    for (NSArray<CHDataPoint *> *series in self.dataPoints) {
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

#pragma mark - Utility Methods

- (CGFloat)xScaleForRect:(CGRect)rect {
    if (self.maxX == self.minX) return 1.0;
    return rect.size.width / (self.maxX - self.minX);
}

- (CGFloat)yScaleForRect:(CGRect)rect {
    if (self.maxY == self.minY) return 1.0;
    return rect.size.height / (self.maxY - self.minY);
}

- (CGRect)dataRectForChartRect:(CGRect)rect {
    // Returns the rect in data coordinates
    return CGRectMake(self.minX, self.minY,
                      self.maxX - self.minX,
                      self.maxY - self.minY);
}

@end
