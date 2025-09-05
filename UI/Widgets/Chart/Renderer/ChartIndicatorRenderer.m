//
// ChartIndicatorRenderer.m
// TradingApp
//
// Renderer implementation for technical indicators display in chart panels
//

#import "ChartIndicatorRenderer.h"
#import "ChartPanelView.h"
#import "TechnicalIndicatorBase+Hierarchy.h"
#import "SharedXCoordinateContext.h"
#import "PanelYCoordinateContext.h"

@interface ChartIndicatorRenderer ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *lastRenderTimes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *cachedRenderingData;
@end

@implementation ChartIndicatorRenderer

#pragma mark - Initialization

- (instancetype)initWithPanelView:(ChartPanelView *)panelView {
    self = [super init];
    if (self) {
        self.panelView = panelView;
        self.indicatorLayers = [[NSMutableDictionary alloc] init];
        self.lastRenderTimes = [[NSMutableDictionary alloc] init];
        self.cachedRenderingData = [[NSMutableDictionary alloc] init];
        [self setupIndicatorsLayer];
    }
    return self;
}

#pragma mark - Rendering Management

- (void)renderIndicatorTree:(TechnicalIndicatorBase *)rootIndicator {
    if (!rootIndicator || !rootIndicator.isCalculated) {
        NSLog(@"⚠️ Cannot render uncalculated indicator tree");
        return;
    }
    
    NSLog(@"🎨 Rendering indicator tree for: %@", rootIndicator.displayName);
    [self clearIndicatorLayers];
    
    if (rootIndicator.hasVisualOutput) {
        [self renderIndicator:rootIndicator];
    }
    
    [self renderChildrenRecursively:rootIndicator];
    NSLog(@"✅ Indicator tree rendering completed");
}

- (void)renderIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator || !indicator.isVisible || !indicator.hasVisualOutput) return;
    if (![self needsRenderingUpdate:indicator]) return;
    
    NSString *indicatorID = indicator.indicatorID;
    CAShapeLayer *layer = [self getOrCreateLayerForIndicator:indicatorID];
    [self configureLayer:layer forIndicator:indicator];
    
    NSArray<IndicatorDataModel *> *outputSeries = indicator.outputSeries;
    if (!outputSeries || outputSeries.count == 0) {
        NSLog(@"⚠️ No output series for indicator: %@", indicator.displayName);
        return;
    }
    
    IndicatorSeriesType seriesType = outputSeries.firstObject.seriesType;
    switch (seriesType) {
        case IndicatorSeriesTypeLine:
            [self renderLineIndicator:indicator layer:layer];
            break;
        case IndicatorSeriesTypeHistogram:
            [self renderHistogramIndicator:indicator layer:layer];
            break;
        case IndicatorSeriesTypeArea:
            [self renderAreaIndicator:indicator layer:layer];
            break;
        case IndicatorSeriesTypeSignal:
            [self renderSignalIndicator:indicator layer:layer];
            break;
        default:
            [self renderLineIndicator:indicator layer:layer];
            break;
    }
    
    [self cacheRenderingDataForIndicator:indicator];
    NSLog(@"🎨 Rendered indicator: %@", indicator.displayName);
}

- (void)clearIndicatorLayers {
    for (CAShapeLayer *layer in self.indicatorLayers.allValues) {
        [layer removeFromSuperlayer];
    }
    [self.indicatorLayers removeAllObjects];
    [self.lastRenderTimes removeAllObjects];
    [self.cachedRenderingData removeAllObjects];
}

- (void)clearIndicatorLayer:(NSString *)indicatorID {
    CAShapeLayer *layer = self.indicatorLayers[indicatorID];
    if (layer) {
        [layer removeFromSuperlayer];
        [self.indicatorLayers removeObjectForKey:indicatorID];
        [self.lastRenderTimes removeObjectForKey:indicatorID];
        [self.cachedRenderingData removeObjectForKey:indicatorID];
    }
}


- (void)invalidateIndicatorLayer:(NSString *)indicatorID {
    CAShapeLayer *layer = self.indicatorLayers[indicatorID];
    if (layer) [layer setNeedsDisplay];
}

#pragma mark - Layer Management

- (void)setupIndicatorsLayer {
    self.indicatorsLayer = [CALayer layer];
    self.indicatorsLayer.frame = self.panelView.bounds;
    [self.panelView.layer addSublayer:self.indicatorsLayer];
    NSLog(@"🏗️ Setup indicators layer for panel: %@", self.panelView.panelType);
}

- (void)updateLayerBounds {
    self.indicatorsLayer.frame = self.panelView.bounds;
    for (CAShapeLayer *layer in self.indicatorLayers.allValues) {
        layer.frame = self.indicatorsLayer.bounds;
    }
}

- (CAShapeLayer *)getOrCreateLayerForIndicator:(NSString *)indicatorID {
    CAShapeLayer *layer = self.indicatorLayers[indicatorID];
    if (!layer) {
        layer = [CAShapeLayer layer];
        layer.frame = self.indicatorsLayer.bounds;
        layer.fillColor = [NSColor clearColor].CGColor;
        layer.lineCap = kCALineCapRound;
        layer.lineJoin = kCALineJoinRound;
        [self.indicatorsLayer addSublayer:layer];
        self.indicatorLayers[indicatorID] = layer;
    }
    return layer;
}

- (void)configureLayer:(CAShapeLayer *)layer forIndicator:(TechnicalIndicatorBase *)indicator {
    layer.strokeColor = [self defaultStrokeColorForIndicator:indicator].CGColor;
    layer.lineWidth = [self defaultLineWidthForIndicator:indicator];
    layer.opacity = indicator.isVisible ? 1.0 : 0.0;
    [self applyVisualEffectsToLayer:layer forIndicator:indicator];
}

#pragma mark - Specialized Rendering Methods

- (void)renderLineIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    NSBezierPath *linePath = [self createLinePathFromDataPoints:dataPoints];
    if (linePath) {
        layer.path = linePath.CGPath;
        layer.fillColor = [NSColor clearColor].CGColor;
    }
}

- (void)renderHistogramIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    NSBezierPath *histogramPath = [self createHistogramPathFromDataPoints:dataPoints baselineY:baselineY];
    if (histogramPath) {
        layer.path = histogramPath.CGPath;
        layer.fillColor = [self defaultFillColorForIndicator:indicator].CGColor;
        layer.strokeColor = [NSColor clearColor].CGColor;
    }
}

- (void)renderAreaIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    NSBezierPath *areaPath = [self createAreaPathFromDataPoints:dataPoints baselineY:baselineY];
    if (areaPath) {
        layer.path = areaPath.CGPath;
        layer.fillColor = [[self defaultFillColorForIndicator:indicator] colorWithAlphaComponent:0.3].CGColor;
        layer.strokeColor = [self defaultStrokeColorForIndicator:indicator].CGColor;
        layer.lineWidth = [self defaultLineWidthForIndicator:indicator];
    }
}

- (void)renderSignalIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    NSBezierPath *signalPath = [NSBezierPath bezierPath];
    
    for (IndicatorDataModel *point in dataPoints) {
        if (!point.isSignal || isnan(point.value)) continue;
        CGFloat x = [self xCoordinateForTimestamp:point.timestamp];
        CGFloat y = [self yCoordinateForValue:point.value];
        NSRect markerRect = NSMakeRect(x - 4, y - 4, 8, 8);
        [signalPath appendBezierPathWithOvalInRect:markerRect];
    }
    
    layer.path = signalPath.CGPath;
    layer.fillColor = [self defaultFillColorForIndicator:indicator].CGColor;
    layer.strokeColor = [self defaultStrokeColorForIndicator:indicator].CGColor;
}

- (void)renderBandsIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    // Implementation for bands rendering (Bollinger Bands, etc.)
    NSLog(@"🎨 Bands indicator rendering - placeholder implementation");
}

- (void)renderOscillatorIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    [self renderLineIndicator:indicator layer:layer];
    
    if ([indicator.shortName isEqualToString:@"RSI"]) {
        [self drawRSIReferenceLinesInLayer:layer];
    }
}

#pragma mark - Path Creation Helpers

- (NSBezierPath *)createLinePathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints {
    if (!dataPoints || dataPoints.count == 0) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    BOOL firstPoint = YES;
    
    for (IndicatorDataModel *point in dataPoints) {
        if (isnan(point.value) || ![self isTimestampInVisibleRange:point.timestamp]) continue;
        
        CGFloat x = [self xCoordinateForTimestamp:point.timestamp];
        CGFloat y = [self yCoordinateForValue:point.value];
        
        if (firstPoint) {
            [path moveToPoint:NSMakePoint(x, y)];
            firstPoint = NO;
        } else {
            [path lineToPoint:NSMakePoint(x, y)];
        }
    }
    
    return path.isEmpty ? nil : path;
}

- (NSBezierPath *)createHistogramPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints baselineY:(CGFloat)baselineY {
    if (!dataPoints || dataPoints.count == 0) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat barWidth = 2.0;
    
    for (IndicatorDataModel *point in dataPoints) {
        if (isnan(point.value) || ![self isTimestampInVisibleRange:point.timestamp]) continue;
        
        CGFloat x = [self xCoordinateForTimestamp:point.timestamp];
        CGFloat y = [self yCoordinateForValue:point.value];
        NSRect barRect = NSMakeRect(x - barWidth/2, MIN(y, baselineY), barWidth, fabs(y - baselineY));
        [path appendBezierPathWithRect:barRect];
    }
    
    return path.isEmpty ? nil : path;
}

- (NSBezierPath *)createAreaPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints baselineY:(CGFloat)baselineY {
    if (!dataPoints || dataPoints.count == 0) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSMutableArray<NSValue *> *points = [[NSMutableArray alloc] init];
    
    for (IndicatorDataModel *point in dataPoints) {
        if (isnan(point.value) || ![self isTimestampInVisibleRange:point.timestamp]) continue;
        CGFloat x = [self xCoordinateForTimestamp:point.timestamp];
        CGFloat y = [self yCoordinateForValue:point.value];
        [points addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
    }
    
    if (points.count == 0) return nil;
    
    BOOL firstPoint = YES;
    for (NSValue *pointValue in points) {
        NSPoint point = [pointValue pointValue];
        if (firstPoint) {
            [path moveToPoint:NSMakePoint(point.x, baselineY)];
            [path lineToPoint:point];
            firstPoint = NO;
        } else {
            [path lineToPoint:point];
        }
    }
    
    NSPoint lastPoint = [[points lastObject] pointValue];
    NSPoint firstPoint_ = [[points firstObject] pointValue];
    [path lineToPoint:NSMakePoint(lastPoint.x, baselineY)];
    [path lineToPoint:NSMakePoint(firstPoint_.x, baselineY)];
    [path closePath];
    
    return path;
}

- (NSBezierPath *)createBandsPathFromUpperPoints:(NSArray<IndicatorDataModel *> *)upperPoints
                                     lowerPoints:(NSArray<IndicatorDataModel *> *)lowerPoints {
    // Implementation for bands path creation
    return [NSBezierPath bezierPath]; // Placeholder
}

#pragma mark - Reference Lines

- (void)drawRSIReferenceLinesInLayer:(CALayer *)parentLayer {
    NSArray *levels = @[@30.0, @50.0, @70.0];
    NSArray *colors = @[[NSColor systemRedColor], [NSColor systemGrayColor], [NSColor systemGreenColor]];
    
    for (NSInteger i = 0; i < levels.count; i++) {
        CGFloat level = [levels[i] doubleValue];
        NSColor *color = colors[i];
        CGFloat y = [self yCoordinateForValue:level];
        
        NSBezierPath *linePath = [NSBezierPath bezierPath];
        [linePath moveToPoint:NSMakePoint(0, y)];
        [linePath lineToPoint:NSMakePoint(parentLayer.bounds.size.width, y)];
        
        CAShapeLayer *refLayer = [CAShapeLayer layer];
        refLayer.frame = parentLayer.bounds;
        refLayer.path = linePath.CGPath;
        refLayer.strokeColor = color.CGColor;
        refLayer.lineWidth = 0.5;
        refLayer.opacity = 0.5;
        refLayer.lineDashPattern = @[@2, @2];
        [parentLayer addSublayer:refLayer];
    }
}

#pragma mark - Coordinate Conversion

- (CGFloat)xCoordinateForTimestamp:(NSDate *)timestamp {
    // ✅ CORRETTO: Use panel's shared X coordinate context
    if (self.panelView.sharedXContext) {
        return [self.panelView.sharedXContext screenXForDate:timestamp];
    }
    
    NSInteger barIndex = [self barIndexForTimestamp:timestamp];
    if (barIndex == NSNotFound) return 0;
    
    CGFloat panelWidth = self.panelView.bounds.size.width;
    CGFloat visibleBars = self.panelView.visibleEndIndex - self.panelView.visibleStartIndex;
    CGFloat barWidth = panelWidth / visibleBars;
    
    return (barIndex - self.panelView.visibleStartIndex) * barWidth;
}

- (CGFloat)yCoordinateForValue:(double)value {
    // ✅ CORRETTO: Use panel's Y coordinate context
    if (self.panelView.panelYContext) {
        return [self.panelView.panelYContext screenYForValue:value];
    }
    
    CGFloat panelHeight = self.panelView.bounds.size.height;
    double yRange = self.panelView.yRangeMax - self.panelView.yRangeMin;
    if (yRange <= 0) return panelHeight / 2;
    
    double normalizedValue = (value - self.panelView.yRangeMin) / yRange;
    return panelHeight - (normalizedValue * panelHeight);
}

- (NSInteger)barIndexForTimestamp:(NSDate *)timestamp {
    NSArray<HistoricalBarModel *> *chartData = self.panelView.chartData;
    if (!chartData || !timestamp) return NSNotFound;
    
    NSInteger left = 0, right = chartData.count - 1;
    
    while (left <= right) {
        NSInteger mid = (left + right) / 2;
        HistoricalBarModel *bar = chartData[mid];
        NSComparisonResult comparison = [bar.date compare:timestamp];  // ✅ CORRETTO: .date non .timestamp
        
        if (comparison == NSOrderedSame) return mid;
        else if (comparison == NSOrderedAscending) left = mid + 1;
        else right = mid - 1;
    }
    
    return (right >= 0 && right < chartData.count) ? right : NSNotFound;
}

- (BOOL)isTimestampInVisibleRange:(NSDate *)timestamp {
    NSInteger barIndex = [self barIndexForTimestamp:timestamp];
    return barIndex != NSNotFound &&
           barIndex >= self.panelView.visibleStartIndex &&
           barIndex <= self.panelView.visibleEndIndex;
}

#pragma mark - Styling

- (CGFloat)defaultLineWidthForIndicator:(TechnicalIndicatorBase *)indicator {
    if (indicator.lineWidth > 0) return indicator.lineWidth;
    return indicator.isRootIndicator ? 2.0 : 1.5;
}

- (NSColor *)defaultStrokeColorForIndicator:(TechnicalIndicatorBase *)indicator {
    if (indicator.displayColor) return indicator.displayColor;
    return [indicator defaultDisplayColor];
}

- (NSColor *)defaultFillColorForIndicator:(TechnicalIndicatorBase *)indicator {
    NSColor *strokeColor = [self defaultStrokeColorForIndicator:indicator];
    return [strokeColor colorWithAlphaComponent:0.3];
}

- (void)applyVisualEffectsToLayer:(CAShapeLayer *)layer forIndicator:(TechnicalIndicatorBase *)indicator {
    if (indicator.isRootIndicator) {
        layer.shadowColor = [NSColor blackColor].CGColor;
        layer.shadowOffset = CGSizeMake(0, -1);
        layer.shadowOpacity = 0.1;
        layer.shadowRadius = 1.0;
    }
}

#pragma mark - Performance

- (BOOL)needsRenderingUpdate:(TechnicalIndicatorBase *)indicator {
    // ✅ SOLUZIONE CORRETTA: Usa la flag needsRendering
    if (indicator.needsRendering) {
        indicator.needsRendering = NO;  // Consuma la flag dopo il check
        self.lastRenderTimes[indicator.indicatorID] = [NSDate date];
        return YES;
    }
    
    return NO; // Non serve re-rendering
}

- (void)cacheRenderingDataForIndicator:(TechnicalIndicatorBase *)indicator {
    // ✅ AGGIORNATO: Include la flag needsRendering
    NSDictionary *cacheData = @{
        @"outputSeriesCount": @(indicator.outputSeries.count),
        @"isVisible": @(indicator.isVisible),
        @"isCalculated": @(indicator.isCalculated),
        @"needsRendering": @(indicator.needsRendering)
    };
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheData];
    self.cachedRenderingData[indicator.indicatorID] = data;
}

- (void)clearCachedDataForIndicator:(NSString *)indicatorID {
    [self.cachedRenderingData removeObjectForKey:indicatorID];
    [self.lastRenderTimes removeObjectForKey:indicatorID];
}

- (void)batchRenderIndicators:(NSArray<TechnicalIndicatorBase *> *)indicators {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    for (TechnicalIndicatorBase *indicator in indicators) {
        [self renderIndicator:indicator];
    }
    
    [CATransaction commit];
}

#pragma mark - Animation

- (void)animateLayerAppearance:(CAShapeLayer *)layer duration:(NSTimeInterval)duration {
    CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeIn.fromValue = @0.0;
    fadeIn.toValue = @1.0;
    fadeIn.duration = duration;
    [layer addAnimation:fadeIn forKey:@"fadeIn"];
}

- (void)animateLayerUpdate:(CAShapeLayer *)layer newPath:(CGPathRef)newPath duration:(NSTimeInterval)duration {
    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    pathAnimation.fromValue = (__bridge id)layer.path;
    pathAnimation.toValue = (__bridge id)newPath;
    pathAnimation.duration = duration;
    pathAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    layer.path = newPath;
    [layer addAnimation:pathAnimation forKey:@"pathUpdate"];
}

- (void)animateLayerRemoval:(CAShapeLayer *)layer completion:(void(^)(void))completion {
    CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeOut.fromValue = @1.0;
    fadeOut.toValue = @0.0;
    fadeOut.duration = 0.25;
    
    if (completion) {
        layer.opacity = 0.0;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [layer removeFromSuperlayer];
            completion();
        });
    }
    
    [layer addAnimation:fadeOut forKey:@"fadeOut"];
}

#pragma mark - Error Handling

- (BOOL)validateIndicatorForRendering:(TechnicalIndicatorBase *)indicator error:(NSError **)error {
    if (!indicator) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartIndicatorRenderer" code:8001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Indicator cannot be nil"}];
        }
        return NO;
    }
    
    if (!indicator.isCalculated) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartIndicatorRenderer" code:8002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Indicator must be calculated before rendering"}];
        }
        return NO;
    }
    
    if (!indicator.outputSeries || indicator.outputSeries.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartIndicatorRenderer" code:8003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Indicator has no output series to render"}];
        }
        return NO;
    }
    
    return YES;
}

- (void)handleRenderingError:(NSError *)error forIndicator:(TechnicalIndicatorBase *)indicator {
    NSLog(@"❌ Rendering error for indicator %@: %@", indicator.displayName, error.localizedDescription);
    [self clearIndicatorLayer:indicator.indicatorID];
}

#pragma mark - Recursive Rendering

- (void)renderChildrenRecursively:(TechnicalIndicatorBase *)parentIndicator {
    for (TechnicalIndicatorBase *child in parentIndicator.childIndicators) {
        if (child.hasVisualOutput) [self renderIndicator:child];
        [self renderChildrenRecursively:child];
    }
}

- (void)updateIndicatorLayerZOrder {
    NSArray<NSString *> *sortedKeys = [self.indicatorLayers.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *key1, NSString *key2) {
        return [key1 compare:key2];
    }];
    
    for (NSInteger i = 0; i < sortedKeys.count; i++) {
        CAShapeLayer *layer = self.indicatorLayers[sortedKeys[i]];
        layer.zPosition = i;
    }
}

#pragma mark - Context Integration

- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext {
    [self invalidateIndicatorLayers];
}

- (void)updatePanelYContext:(PanelYCoordinateContext *)panelYContext {
    [self invalidateIndicatorLayers];
}

#pragma mark - Cleanup

- (void)cleanup {
    [self clearIndicatorLayers];
    [self.indicatorsLayer removeFromSuperlayer];
    self.indicatorsLayer = nil;
    self.panelView = nil;
    NSLog(@"🧹 ChartIndicatorRenderer cleanup completed");
}

- (void)removeAllLayers {
    [self clearIndicatorLayers];
    [self.indicatorsLayer removeFromSuperlayer];
}


#pragma mark - Visibility Management

- (void)setChildIndicatorsVisible:(BOOL)visible {
    if (!self.rootIndicator) {
        NSLog(@"⚠️ No root indicator to modify children visibility");
        return;
    }
    
    NSLog(@"👁️ Setting child indicators visible: %@ for root: %@",
          visible ? @"YES" : @"NO", self.rootIndicator.displayName);
    
    [self setVisibilityRecursively:self.rootIndicator.childIndicators visible:visible];
    
    // Trigger re-render
    [self invalidateIndicatorLayers];
    [self renderIndicatorTree:self.rootIndicator];
}

- (void)setVisibilityRecursively:(NSArray<TechnicalIndicatorBase *> *)indicators visible:(BOOL)visible {
    for (TechnicalIndicatorBase *indicator in indicators) {
        indicator.isVisible = visible;
        indicator.needsRendering = YES;
        
        NSLog(@"  %@ %@", visible ? @"👁️" : @"🙈", indicator.displayName);
        
        // Ricorsivo per i figli dei figli
        if (indicator.childIndicators.count > 0) {
            [self setVisibilityRecursively:indicator.childIndicators visible:visible];
        }
    }
}

- (void)invalidateIndicatorLayers {
    // ✅ MIGLIORAMENTO: Forza l'invalidazione di tutti i layer
    for (NSString *indicatorID in self.indicatorLayers.allKeys) {
        CAShapeLayer *layer = self.indicatorLayers[indicatorID];
        layer.path = NULL; // Forza re-render
    }
    
    NSLog(@"🔄 Invalidated %ld indicator layers", (long)self.indicatorLayers.count);
}

// ✅ PROPERTY IMPLEMENTATION
- (TechnicalIndicatorBase *)rootIndicator {
    // TODO: Implementare basandosi sulla tua architettura
    // Questo potrebbe essere:
    // 1. Una property separata che viene impostata durante l'init
    // 2. Derivata dal panelType del ChartPanelView
    // 3. Trovata attraverso il template system
    
    NSLog(@"⚠️ rootIndicator property needs implementation");
    return nil; // Placeholder
}
@end
