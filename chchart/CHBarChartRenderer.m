//
//  CHBarChartRenderer.m
//  ChartWidget
//
//  Implementation of bar chart and histogram renderer
//

#import "CHBarChartRenderer.h"
#import "CHChartConfiguration.h"
#import "CHDataPoint.h"

@interface CHBarChartRenderer ()
@property (nonatomic, strong) NSMutableArray<NSNumber *> *histogramBins;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *binEdges;
@end

@implementation CHBarChartRenderer

#pragma mark - Initialization

- (instancetype)initWithConfiguration:(CHChartConfiguration *)configuration {
    self = [super initWithConfiguration:configuration];
    if (self) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    _barStyle = CHBarChartStyleSeparated;
    _orientation = CHBarChartOrientationVertical;
    _cornerStyle = CHBarCornerStyleSquare;
    _cornerRadius = 4.0;
    
    _barWidthRatio = 0.8;
    _groupSpacingRatio = 0.2;
    _barSpacingRatio = 0.1;
    
    _showBarLabels = NO;
    _showBarOutline = NO;
    _barOutlineWidth = 1.0;
    _barOutlineColor = [NSColor colorWithWhite:0.3 alpha:1.0];
    
    _useGradient = NO;
    _gradientAngle = 90.0;
    _gradientIntensity = 0.3;
    
    _drawBarShadow = NO;
    _barShadowColor = [NSColor colorWithWhite:0 alpha:0.2];
    _barShadowOffset = CGSizeMake(2, 2);
    _barShadowBlurRadius = 3.0;
    
    _animateFromBaseline = YES;
    _animateSequentially = NO;
    
    _binCount = 10;
    _normalizeHistogram = NO;
}

#pragma mark - Data Processing

- (void)updateWithDataPoints:(NSArray<NSArray<CHDataPoint *> *> *)dataPoints
               configuration:(CHChartConfiguration *)configuration {
    [super updateWithDataPoints:dataPoints configuration:configuration];
    
    // Process histogram data if needed
    if (self.barStyle == CHBarChartStyleHistogram && dataPoints.count > 0) {
        [self calculateHistogramBins];
    }
}

- (void)calculateHistogramBins {
    // Initialize bins
    self.histogramBins = [NSMutableArray array];
    self.binEdges = [NSMutableArray array];
    
    for (NSInteger i = 0; i <= self.binCount; i++) {
        [self.histogramBins addObject:@0];
    }
    
    // Calculate bin edges
    CGFloat binWidth = (self.maxX - self.minX) / self.binCount;
    for (NSInteger i = 0; i <= self.binCount; i++) {
        CGFloat edge = self.minX + (i * binWidth);
        [self.binEdges addObject:@(edge)];
    }
    
    // Count values in each bin
    for (NSArray<CHDataPoint *> *series in self.dataPoints) {
        for (CHDataPoint *point in series) {
            NSInteger binIndex = [self binIndexForValue:point.x];
            if (binIndex >= 0 && binIndex < self.binCount) {
                CGFloat currentCount = [self.histogramBins[binIndex] floatValue];
                self.histogramBins[binIndex] = @(currentCount + 1);
            }
        }
    }
    
    // Normalize if requested
    if (self.normalizeHistogram) {
        CGFloat total = 0;
        for (NSNumber *count in self.histogramBins) {
            total += [count floatValue];
        }
        
        if (total > 0) {
            for (NSInteger i = 0; i < self.histogramBins.count; i++) {
                CGFloat normalized = [self.histogramBins[i] floatValue] / (total * binWidth);
                self.histogramBins[i] = @(normalized);
            }
        }
    }
}

- (NSInteger)binIndexForValue:(CGFloat)value {
    if (value < self.minX || value > self.maxX) return -1;
    
    NSInteger index = (NSInteger)((value - self.minX) / ((self.maxX - self.minX) / self.binCount));
    return MIN(index, self.binCount - 1);
}

#pragma mark - Drawing

- (void)drawInRect:(CGRect)rect
           context:(NSGraphicsContext *)context
          animated:(BOOL)animated
          progress:(CGFloat)progress {
    // Draw base elements
    [super drawInRect:rect context:context animated:animated progress:progress];
    
    if (self.barStyle == CHBarChartStyleHistogram) {
        [self drawHistogramInRect:rect context:context animated:animated progress:progress];
    } else {
        [self drawBarsInRect:rect context:context animated:animated progress:progress];
    }
}

- (void)drawBarsInRect:(CGRect)rect
               context:(NSGraphicsContext *)context
              animated:(BOOL)animated
              progress:(CGFloat)progress {
    
    NSInteger seriesCount = self.dataPoints.count;
    if (seriesCount == 0) return;
    
    // Calculate layout based on style
    switch (self.barStyle) {
        case CHBarChartStyleSeparated:
            [self drawSeparatedBarsInRect:rect context:context animated:animated progress:progress];
            break;
            
        case CHBarChartStyleGrouped:
            [self drawGroupedBarsInRect:rect context:context animated:animated progress:progress];
            break;
            
        case CHBarChartStyleStacked:
            [self drawStackedBarsInRect:rect context:context animated:animated progress:progress];
            break;
            
        case CHBarChartStyleWaterfall:
            [self drawWaterfallBarsInRect:rect context:context animated:animated progress:progress];
            break;
            
        default:
            break;
    }
}

- (void)drawSeparatedBarsInRect:(CGRect)rect
                        context:(NSGraphicsContext *)context
                       animated:(BOOL)animated
                       progress:(CGFloat)progress {
    
    // For separated bars, we draw all series overlapped
    for (NSInteger seriesIndex = 0; seriesIndex < self.dataPoints.count; seriesIndex++) {
        NSArray<CHDataPoint *> *series = self.dataPoints[seriesIndex];
        NSColor *seriesColor = [self colorForSeries:seriesIndex];
        
        for (NSInteger i = 0; i < series.count; i++) {
            CHDataPoint *point = series[i];
            
            // Calculate animation progress for this bar
            CGFloat barProgress = [self calculateBarProgress:i
                                                 totalBars:series.count
                                             totalProgress:progress
                                                  animated:animated];
            
            if (barProgress <= 0) continue;
            
            // Calculate bar rect
            CGRect barRect = [self rectForDataPoint:point
                                         seriesIndex:seriesIndex
                                         seriesCount:self.dataPoints.count
                                              inRect:rect];
            
            // Apply animation
            if (self.animateFromBaseline && animated) {
                if (self.orientation == CHBarChartOrientationVertical) {
                    CGFloat fullHeight = barRect.size.height;
                    barRect.size.height *= barProgress;
                    barRect.origin.y += (fullHeight - barRect.size.height);
                } else {
                    barRect.size.width *= barProgress;
                }
            }
            
            // Draw the bar
            [self drawBarInRect:barRect
                      withColor:seriesColor
                        context:context];
            
            // Draw label if enabled
            if (self.showBarLabels) {
                [self drawLabelForValue:point.y
                               inBarRect:barRect
                                 context:context];
            }
        }
    }
}

- (void)drawGroupedBarsInRect:(CGRect)rect
                      context:(NSGraphicsContext *)context
                     animated:(BOOL)animated
                     progress:(CGFloat)progress {
    
    if (self.dataPoints.count == 0) return;
    
    // Assume all series have the same number of points
    NSInteger pointCount = self.dataPoints[0].count;
    NSInteger seriesCount = self.dataPoints.count;
    
    CGFloat groupWidth = rect.size.width / pointCount;
    CGFloat barWidth = (groupWidth * self.barWidthRatio) / seriesCount;
    CGFloat groupSpacing = groupWidth * (1 - self.barWidthRatio);
    CGFloat barSpacing = barWidth * self.barSpacingRatio;
    
    for (NSInteger groupIndex = 0; groupIndex < pointCount; groupIndex++) {
        CGFloat groupX = rect.origin.x + (groupIndex * groupWidth) + (groupSpacing / 2);
        
        for (NSInteger seriesIndex = 0; seriesIndex < seriesCount; seriesIndex++) {
            CHDataPoint *point = self.dataPoints[seriesIndex][groupIndex];
            NSColor *seriesColor = [self colorForSeries:seriesIndex];
            
            // Calculate bar position within group
            CGFloat barX = groupX + (seriesIndex * (barWidth + barSpacing));
            
            // Calculate bar height
            CGFloat barHeight = [self heightForValue:point.y inRect:rect];
            CGRect barRect = CGRectMake(barX,
                                       rect.origin.y + rect.size.height - barHeight,
                                       barWidth - barSpacing,
                                       barHeight);
            
            // Apply animation
            CGFloat barProgress = [self calculateBarProgress:groupIndex
                                                 totalBars:pointCount
                                             totalProgress:progress
                                                  animated:animated];
            
            if (self.animateFromBaseline && animated) {
                barRect.size.height *= barProgress;
                barRect.origin.y = rect.origin.y + rect.size.height - barRect.size.height;
            }
            
            // Draw the bar
            [self drawBarInRect:barRect
                      withColor:seriesColor
                        context:context];
        }
    }
}

- (void)drawStackedBarsInRect:(CGRect)rect
                      context:(NSGraphicsContext *)context
                     animated:(BOOL)animated
                     progress:(CGFloat)progress {
    
    if (self.dataPoints.count == 0) return;
    
    NSInteger pointCount = self.dataPoints[0].count;
    CGFloat barWidth = (rect.size.width / pointCount) * self.barWidthRatio;
    CGFloat spacing = (rect.size.width / pointCount) * (1 - self.barWidthRatio);
    
    for (NSInteger i = 0; i < pointCount; i++) {
        CGFloat x = rect.origin.x + (i * (barWidth + spacing)) + (spacing / 2);
        CGFloat currentY = rect.origin.y + rect.size.height;
        
        // Stack bars for each series
        for (NSInteger seriesIndex = 0; seriesIndex < self.dataPoints.count; seriesIndex++) {
            CHDataPoint *point = self.dataPoints[seriesIndex][i];
            NSColor *seriesColor = [self colorForSeries:seriesIndex];
            
            CGFloat barHeight = [self heightForValue:point.y inRect:rect];
            
            // Apply animation
            CGFloat barProgress = [self calculateBarProgress:i
                                                 totalBars:pointCount
                                             totalProgress:progress
                                                  animated:animated];
            barHeight *= barProgress;
            
            CGRect barRect = CGRectMake(x, currentY - barHeight, barWidth, barHeight);
            
            [self drawBarInRect:barRect
                      withColor:seriesColor
                        context:context];
            
            currentY -= barHeight;
        }
    }
}

- (void)drawHistogramInRect:(CGRect)rect
                    context:(NSGraphicsContext *)context
                   animated:(BOOL)animated
                   progress:(CGFloat)progress {
    
    if (!self.histogramBins || self.histogramBins.count == 0) return;
    
    CGFloat binWidth = rect.size.width / self.binCount;
    
    // Find max bin value for scaling
    CGFloat maxBinValue = 0;
    for (NSNumber *binValue in self.histogramBins) {
        maxBinValue = MAX(maxBinValue, [binValue floatValue]);
    }
    
    if (maxBinValue == 0) return;
    
    // Draw each bin
    for (NSInteger i = 0; i < self.binCount; i++) {
        CGFloat binValue = [self.histogramBins[i] floatValue];
        CGFloat binHeight = (binValue / maxBinValue) * rect.size.height;
        
        // Apply animation
        CGFloat barProgress = [self calculateBarProgress:i
                                             totalBars:self.binCount
                                         totalProgress:progress
                                              animated:animated];
        binHeight *= barProgress;
        
        CGRect binRect = CGRectMake(rect.origin.x + (i * binWidth),
                                   rect.origin.y + rect.size.height - binHeight,
                                   binWidth,
                                   binHeight);
        
        // Use first series color for histogram
        NSColor *histogramColor = [self colorForSeries:0];
        
        [self drawBarInRect:binRect
                  withColor:histogramColor
                    context:context];
    }
}

- (void)drawWaterfallBarsInRect:(CGRect)rect
                        context:(NSGraphicsContext *)context
                       animated:(BOOL)animated
                       progress:(CGFloat)progress {
    // Waterfall implementation - shows running total
    // This is a simplified version
    [self drawSeparatedBarsInRect:rect context:context animated:animated progress:progress];
}

#pragma mark - Bar Drawing

- (void)drawBarInRect:(CGRect)barRect
            withColor:(NSColor *)color
              context:(NSGraphicsContext *)context {
    
    [context saveGraphicsState];
    
    // Create bar path
    NSBezierPath *barPath = [self pathForBarRect:barRect];
    
    // Draw shadow if enabled
    if (self.drawBarShadow) {
        NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowColor:self.barShadowColor];
        [shadow setShadowOffset:self.barShadowOffset];
        [shadow setShadowBlurRadius:self.barShadowBlurRadius];
        [shadow set];
    }
    
    // Fill bar
    if (self.useGradient) {
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:color
                                                              endingColor:[color highlightWithLevel:self.gradientIntensity]];
        [gradient drawInBezierPath:barPath angle:self.gradientAngle];
    } else {
        [color set];
        [barPath fill];
    }
    
    // Draw outline if enabled
    if (self.showBarOutline) {
        [self.barOutlineColor set];
        [barPath setLineWidth:self.barOutlineWidth];
        [barPath stroke];
    }
    
    [context restoreGraphicsState];
}

- (NSBezierPath *)pathForBarRect:(CGRect)rect {
    switch (self.cornerStyle) {
        case CHBarCornerStyleSquare:
            return [NSBezierPath bezierPathWithRect:rect];
            
        case CHBarCornerStyleRounded:
            return [NSBezierPath bezierPathWithRoundedRect:rect
                                                   xRadius:self.cornerRadius
                                                   yRadius:self.cornerRadius];
            
        case CHBarCornerStyleRoundedTop: {
            NSBezierPath *path = [NSBezierPath bezierPath];
            CGFloat radius = MIN(self.cornerRadius, MIN(rect.size.width, rect.size.height) / 2);
            
            // Start from bottom left
            [path moveToPoint:CGPointMake(rect.origin.x, rect.origin.y + rect.size.height)];
            
            // Line to top left curve start
            [path lineToPoint:CGPointMake(rect.origin.x, rect.origin.y + radius)];
            
            // Top left corner
            [path appendBezierPathWithArcFromPoint:CGPointMake(rect.origin.x, rect.origin.y)
                                           toPoint:CGPointMake(rect.origin.x + radius, rect.origin.y)
                                            radius:radius];
            
            // Line to top right curve start
            [path lineToPoint:CGPointMake(rect.origin.x + rect.size.width - radius, rect.origin.y)];
            
            // Top right corner
            [path appendBezierPathWithArcFromPoint:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y)
                                           toPoint:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + radius)
                                            radius:radius];
            
            // Line to bottom right
            [path lineToPoint:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)];
            
            // Close path
            [path closePath];
            
            return path;
        }
    }
}

#pragma mark - Helper Methods

- (CGRect)rectForDataPoint:(CHDataPoint *)point
               seriesIndex:(NSInteger)seriesIndex
               seriesCount:(NSInteger)seriesCount
                    inRect:(CGRect)rect {
    
    if (self.orientation == CHBarChartOrientationVertical) {
        CGFloat barWidth = (rect.size.width / self.dataPoints[seriesIndex].count) * self.barWidthRatio;
        CGFloat x = [self xPositionForDataPoint:point inRect:rect] - (barWidth / 2);
        CGFloat height = [self heightForValue:point.y inRect:rect];
        CGFloat y = rect.origin.y + rect.size.height - height;
        
        return CGRectMake(x, y, barWidth, height);
    } else {
        // Horizontal bars
        CGFloat barHeight = (rect.size.height / self.dataPoints[seriesIndex].count) * self.barWidthRatio;
        CGFloat y = [self yPositionForDataPoint:point inRect:rect] - (barHeight / 2);
        CGFloat width = [self widthForValue:point.y inRect:rect];
        
        return CGRectMake(rect.origin.x, y, width, barHeight);
    }
}

- (CGFloat)xPositionForDataPoint:(CHDataPoint *)point inRect:(CGRect)rect {
    CGPoint viewPoint = [self viewPointForDataPoint:point inRect:rect];
    return viewPoint.x;
}

- (CGFloat)yPositionForDataPoint:(CHDataPoint *)point inRect:(CGRect)rect {
    CGPoint viewPoint = [self viewPointForDataPoint:point inRect:rect];
    return viewPoint.y;
}

- (CGFloat)heightForValue:(CGFloat)value inRect:(CGRect)rect {
    if (self.maxY == self.minY) return 0;
    
    CGFloat normalizedValue = (value - self.minY) / (self.maxY - self.minY);
    return normalizedValue * rect.size.height;
}

- (CGFloat)widthForValue:(CGFloat)value inRect:(CGRect)rect {
    if (self.maxX == self.minX) return 0;
    
    CGFloat normalizedValue = (value - self.minX) / (self.maxX - self.minX);
    return normalizedValue * rect.size.width;
}

- (NSColor *)colorForSeries:(NSInteger)seriesIndex {
    if (seriesIndex < self.configuration.seriesColors.count) {
        return self.configuration.seriesColors[seriesIndex];
    }
    
    // Generate color based on series index
    return [NSColor colorWithHue:(CGFloat)seriesIndex / MAX(self.dataPoints.count, 1)
                      saturation:0.8
                      brightness:0.8
                           alpha:1.0];
}

- (CGFloat)calculateBarProgress:(NSInteger)barIndex
                     totalBars:(NSInteger)totalBars
                 totalProgress:(CGFloat)progress
                      animated:(BOOL)animated {
    
    if (!animated) return 1.0;
    
    if (self.animateSequentially) {
        // Each bar animates after the previous one
        CGFloat barDuration = 1.0 / totalBars;
        CGFloat barStartTime = barIndex * barDuration;
        CGFloat barEndTime = barStartTime + barDuration;
        
        if (progress < barStartTime) return 0.0;
        if (progress > barEndTime) return 1.0;
        
        return (progress - barStartTime) / barDuration;
    } else {
        // All bars animate together
        return progress;
    }
}

- (void)drawLabelForValue:(CGFloat)value
               inBarRect:(CGRect)barRect
                 context:(NSGraphicsContext *)context {
    
    NSString *label = [NSString stringWithFormat:@"%.1f", value];
    NSDictionary *attributes = @{
        NSFontAttributeName: self.configuration.labelFont,
        NSForegroundColorAttributeName: self.configuration.textColor
    };
    
    NSSize labelSize = [label sizeWithAttributes:attributes];
    NSPoint labelPoint;
    
    if (self.orientation == CHBarChartOrientationVertical) {
        labelPoint = NSMakePoint(barRect.origin.x + (barRect.size.width - labelSize.width) / 2,
                                barRect.origin.y - labelSize.height - 2);
    } else {
        labelPoint = NSMakePoint(barRect.origin.x + barRect.size.width + 5,
                                barRect.origin.y + (barRect.size.height - labelSize.height) / 2);
    }
    
    [label drawAtPoint:labelPoint withAttributes:attributes];
}

@end
