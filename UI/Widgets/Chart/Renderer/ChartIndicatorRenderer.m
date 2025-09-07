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
    CGPathRef cgPath = [self createCGLinePathFromDataPoints:dataPoints];
    if (cgPath) {
        layer.path = cgPath;
        layer.fillColor = [NSColor clearColor].CGColor;
        CGPathRelease(cgPath); // ✅ Memory management
    }
}

- (void)renderHistogramIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    CGPathRef cgPath = [self createCGHistogramPathFromDataPoints:dataPoints baselineY:baselineY];
    if (cgPath) {
        layer.path = cgPath;
        layer.fillColor = [self defaultFillColorForIndicator:indicator].CGColor;
        layer.strokeColor = [NSColor clearColor].CGColor;
        CGPathRelease(cgPath); // ✅ Memory management
    }
}

- (void)renderAreaIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    CGPathRef cgPath = [self createCGAreaPathFromDataPoints:dataPoints baselineY:baselineY];
    if (cgPath) {
        layer.path = cgPath;
        layer.fillColor = [[self defaultFillColorForIndicator:indicator] colorWithAlphaComponent:0.3].CGColor;
        layer.strokeColor = [self defaultStrokeColorForIndicator:indicator].CGColor;
        layer.lineWidth = [self defaultLineWidthForIndicator:indicator];
        CGPathRelease(cgPath); // ✅ Memory management
    }
}

- (void)renderSignalIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer {
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    CGPathRef cgPath = [self createCGSignalPathFromDataPoints:dataPoints];
    if (cgPath) {
        layer.path = cgPath;
        layer.fillColor = [self defaultFillColorForIndicator:indicator].CGColor;
        layer.strokeColor = [self defaultStrokeColorForIndicator:indicator].CGColor;
        CGPathRelease(cgPath); // ✅ Memory management
    }
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


- (CGPathRef)createCGLinePathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints {
    if (!dataPoints || dataPoints.count == 0) return NULL;
    
    // ✅ VERIFICA coordinate contexts
    if (!self.panelView.sharedXContext || !self.panelView.panelYContext) {
        NSLog(@"❌ Missing coordinate contexts - cannot render");
        return NULL;
    }
    
    CGMutablePathRef path = CGPathCreateMutable();
    BOOL firstPoint = YES;
    NSInteger validPoints = 0;
    
    // ✅ Solo parte visibile
    NSInteger startIndex = MAX(0, self.panelView.visibleStartIndex);
    NSInteger endIndex = MIN(dataPoints.count - 1, self.panelView.visibleEndIndex);
    
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *point = dataPoints[i];
        
        // ✅ Skip NaN values
        if (isnan(point.value)) continue;
        
        // ✅ Usa coordinate contexts DIRETTAMENTE
        CGFloat x = [self.panelView.sharedXContext screenXForBarIndex:i];
        CGFloat y = [self.panelView.panelYContext screenYForValue:point.value];
        
        CGPoint cgPoint = CGPointMake(x, y);
        
        if (firstPoint) {
            CGPathMoveToPoint(path, NULL, cgPoint.x, cgPoint.y);
            firstPoint = NO;
        } else {
            CGPathAddLineToPoint(path, NULL, cgPoint.x, cgPoint.y);
        }
        validPoints++;
    }
    
    if (validPoints == 0) {
        CGPathRelease(path);
        return NULL;
    }
    
    return path; // Caller must release
}

- (CGPathRef)createCGHistogramPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints
                                       baselineY:(CGFloat)baselineY {
    if (!dataPoints || dataPoints.count == 0) return NULL;
    
    // ✅ VERIFICA coordinate contexts
    if (!self.panelView.sharedXContext || !self.panelView.panelYContext) {
        return NULL;
    }
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat barWidth = [self.panelView.sharedXContext barWidth] * 0.8; // 80% della larghezza barra
    NSInteger validBars = 0;
    
    // ✅ Solo parte visibile
    NSInteger startIndex = MAX(0, self.panelView.visibleStartIndex);
    NSInteger endIndex = MIN(dataPoints.count - 1, self.panelView.visibleEndIndex);
    
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *point = dataPoints[i];
        
        if (isnan(point.value)) continue;
        
        // ✅ Coordinate contexts diretti
        CGFloat x = [self.panelView.sharedXContext screenXForBarIndex:i];
        CGFloat y = [self.panelView.panelYContext screenYForValue:point.value];
        
        CGRect barRect = CGRectMake(x - barWidth/2,
                                   MIN(y, baselineY),
                                   barWidth,
                                   fabs(y - baselineY));
        
        CGPathAddRect(path, NULL, barRect);
        validBars++;
    }
    
    if (validBars == 0) {
        CGPathRelease(path);
        return NULL;
    }
    
    return path; // Caller must release
}

- (CGPathRef)createCGAreaPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints
                                  baselineY:(CGFloat)baselineY {
    if (!dataPoints || dataPoints.count == 0) return NULL;
    
    // ✅ VERIFICA coordinate contexts
    if (!self.panelView.sharedXContext || !self.panelView.panelYContext) {
        return NULL;
    }
    
    CGMutablePathRef path = CGPathCreateMutable();
    NSMutableArray<NSValue *> *points = [[NSMutableArray alloc] init];
    
    // ✅ Solo parte visibile
    NSInteger startIndex = MAX(0, self.panelView.visibleStartIndex);
    NSInteger endIndex = MIN(dataPoints.count - 1, self.panelView.visibleEndIndex);
    
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *point = dataPoints[i];
        
        if (isnan(point.value)) continue;
        
        // ✅ Coordinate contexts diretti
        CGFloat x = [self.panelView.sharedXContext screenXForBarIndex:i];
        CGFloat y = [self.panelView.panelYContext screenYForValue:point.value];
        
        [points addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
    }
    
    if (points.count == 0) {
        CGPathRelease(path);
        return NULL;
    }
    
    // Crea area path
    BOOL firstPoint = YES;
    for (NSValue *pointValue in points) {
        NSPoint point = [pointValue pointValue];
        CGPoint cgPoint = NSPointToCGPoint(point);
        
        if (firstPoint) {
            CGPathMoveToPoint(path, NULL, cgPoint.x, baselineY);
            CGPathAddLineToPoint(path, NULL, cgPoint.x, cgPoint.y);
            firstPoint = NO;
        } else {
            CGPathAddLineToPoint(path, NULL, cgPoint.x, cgPoint.y);
        }
    }
    
    // Chiudi l'area
    NSPoint lastPoint = [[points lastObject] pointValue];
    NSPoint firstPoint_ = [[points firstObject] pointValue];
    CGPathAddLineToPoint(path, NULL, lastPoint.x, baselineY);
    CGPathAddLineToPoint(path, NULL, firstPoint_.x, baselineY);
    CGPathCloseSubpath(path);
    
    return path; // Caller must release
}

- (CGPathRef)createCGSignalPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints {
    if (!dataPoints || dataPoints.count == 0) return NULL;
    
    CGMutablePathRef path = CGPathCreateMutable();
    NSInteger validSignals = 0;
    
    for (IndicatorDataModel *point in dataPoints) {
        if (!point.isSignal || isnan(point.value)) continue;
        
        CGFloat x = [self xCoordinateForTimestamp:point.timestamp];
        CGFloat y = [self yCoordinateForValue:point.value];
        
        CGRect markerRect = CGRectMake(x - 4, y - 4, 8, 8);
        CGPathAddEllipseInRect(path, NULL, markerRect);
        validSignals++;
    }
    
    if (validSignals == 0) {
        CGPathRelease(path);
        return NULL;
    }
    
    return path; // Caller must release
}
// ✅ OTTIMIZZAZIONE 4: Cache management per path
- (BOOL)needsPathRecalculation:(TechnicalIndicatorBase *)indicator {
    // ✅ Controlla se viewport o dati sono cambiati
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%ld_%ld",
                         indicator.indicatorID,
                         (long)self.panelView.visibleStartIndex,
                         (long)self.panelView.visibleEndIndex];
    
    NSString *lastCacheKey = self.cachedPathKeys[indicator.indicatorID];
    
    if ([cacheKey isEqualToString:lastCacheKey] && !indicator.needsRendering) {
        return NO; // Riusa cache
    }
    
    return YES; // Ricalcola
}

// ✅ AGGIORNATO: Cache per CGPath invece di NSBezierPath
- (void)cacheCGPathForIndicator:(TechnicalIndicatorBase *)indicator cgPath:(CGPathRef)cgPath {
   NSString *cacheKey = [NSString stringWithFormat:@"cgpath_%@_%ld_%ld",
                        indicator.indicatorID,
                        (long)self.panelView.visibleStartIndex,
                        (long)self.panelView.visibleEndIndex];
   
   if (!self.cachedPathKeys) {
       self.cachedPathKeys = [[NSMutableDictionary alloc] init];
   }
   
   self.cachedPathKeys[indicator.indicatorID] = cacheKey;
}


- (void)batchRenderVisibleIndicators:(NSArray<TechnicalIndicatorBase *> *)indicators {
   if (!indicators || indicators.count == 0) return;
   
   NSLog(@"🚀 BATCH rendering %ld indicators for visible range [%ld-%ld]",
         (long)indicators.count,
         (long)self.panelView.visibleStartIndex,
         (long)self.panelView.visibleEndIndex);
   
   [CATransaction begin];
   [CATransaction setDisableActions:YES]; // Disabilita animazioni per performance
   
   for (TechnicalIndicatorBase *indicator in indicators) {
       if (indicator.isVisible && indicator.hasVisualOutput) {
           // ✅ USA il nuovo metodo standard renderIndicator invece di quello obsoleto
           [self renderIndicator:indicator];
       }
   }
   
   [CATransaction commit];
   
   NSLog(@"✅ BATCH rendering completed");
}

#pragma mark - Reference Lines - GENERICO

/// Disegna linee orizzontali per oscillatori a livelli specifici
/// @param parentLayer Layer contenitore
/// @param levels Array di NSNumber con i livelli (es: @[@30, @50, @70] per RSI)
/// @param colors Array di NSColor per ogni livello (opzionale, usa colori default se nil)
/// @param lineStyle Stile linea (opzionale: @{@"width": @1.0, @"opacity": @0.5, @"dash": @[@2, @2]})
- (void)drawHorizontalLinesForOscillatorAtLevels:(NSArray<NSNumber *> *)levels
                                        inLayer:(CALayer *)parentLayer
                                      withColors:(nullable NSArray<NSColor *> *)colors
                                       lineStyle:(nullable NSDictionary *)lineStyle {
    
    if (!levels || levels.count == 0 || !parentLayer) return;
    
    // ✅ VERIFICA coordinate context
    if (!self.panelView.panelYContext) {
        NSLog(@"⚠️ No panelYContext available for oscillator lines");
        return;
    }
    
    // ✅ Colori di default se non forniti
    NSArray<NSColor *> *defaultColors = @[
        [NSColor systemRedColor],     // Primo livello (es: oversold/overbought)
        [NSColor systemGrayColor],    // Livello centrale
        [NSColor systemGreenColor],   // Ultimo livello
        [NSColor systemOrangeColor],  // Livelli extra
        [NSColor systemPurpleColor],
        [NSColor systemBlueColor]
    ];
    
    NSArray<NSColor *> *colorsToUse = colors ?: defaultColors;
    
    // ✅ Stile di default se non fornito
    CGFloat lineWidth = lineStyle[@"width"] ? [lineStyle[@"width"] floatValue] : 0.5;
    CGFloat opacity = lineStyle[@"opacity"] ? [lineStyle[@"opacity"] floatValue] : 0.5;
    NSArray *dashPattern = lineStyle[@"dash"] ?: @[@2, @2];
    
    NSLog(@"📊 Drawing %ld oscillator reference lines", (long)levels.count);
    
    for (NSInteger i = 0; i < levels.count; i++) {
        CGFloat level = [levels[i] doubleValue];
        NSColor *color = (i < colorsToUse.count) ? colorsToUse[i] : [NSColor labelColor];
        
        // ✅ Usa coordinate context direttamente
        CGFloat y = [self.panelView.panelYContext screenYForValue:level];
        
        // ✅ Crea path per linea orizzontale
        NSBezierPath *linePath = [NSBezierPath bezierPath];
        [linePath moveToPoint:NSMakePoint(0, y)];
        [linePath lineToPoint:NSMakePoint(parentLayer.bounds.size.width, y)];
        
        // ✅ Crea layer per la linea
        CAShapeLayer *refLayer = [CAShapeLayer layer];
        refLayer.frame = parentLayer.bounds;
        refLayer.path = linePath.CGPath;
        refLayer.strokeColor = color.CGColor;
        refLayer.lineWidth = lineWidth;
        refLayer.opacity = opacity;
        refLayer.lineDashPattern = dashPattern;
        
        [parentLayer addSublayer:refLayer];
        
        NSLog(@"📏 Drew reference line at level %.1f (y=%.1f)", level, y);
    }
}

/// Custom oscillator lines - per indicatori personalizzati
/// @param levels Array di livelli personalizzati
/// @param parentLayer Layer contenitore
- (void)drawCustomOscillatorLines:(NSArray<NSNumber *> *)levels inLayer:(CALayer *)parentLayer {
    [self drawHorizontalLinesForOscillatorAtLevels:levels
                                           inLayer:parentLayer
                                        withColors:nil  // Usa colori default
                                         lineStyle:nil]; // Usa stile default
}

#pragma mark - Oscillator-Specific Convenience Methods

/// RSI reference lines (30, 50, 70)
- (void)drawRSIReferenceLinesInLayer:(CALayer *)parentLayer {
    NSArray *levels = @[@30.0, @50.0, @70.0];
    NSArray *colors = @[
        [NSColor systemRedColor],    // 30 - Oversold
        [NSColor systemGrayColor],   // 50 - Midline
        [NSColor systemGreenColor]   // 70 - Overbought
    ];
    
    [self drawHorizontalLinesForOscillatorAtLevels:levels
                                           inLayer:parentLayer
                                        withColors:colors
                                         lineStyle:@{@"width": @0.5, @"opacity": @0.6}];
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
    // ✅ Step 1: Invalida i layer (come prima)
    for (NSString *indicatorID in self.indicatorLayers.allKeys) {
        CAShapeLayer *layer = self.indicatorLayers[indicatorID];
        layer.path = NULL; // Forza re-render
    }
    
    // ✅ Step 2: CRITICO - Setta needsRendering flag per tutti gli indicatori!
    [self markAllIndicatorsForRerendering];
    
    NSLog(@"🔄 Invalidated %ld indicator layers + set needsRendering flags", (long)self.indicatorLayers.count);
}

- (void)markAllIndicatorsForRerendering {
    if (!self.rootIndicator) {
        NSLog(@"⚠️ No rootIndicator to mark for re-rendering");
        return;
    }
    
    // Marca il root
    self.rootIndicator.needsRendering = YES;
    
    // Marca tutti i children ricorsivamente
    [self markIndicatorsRecursively:self.rootIndicator.childIndicators];
    
    NSLog(@"🏁 Marked all indicators in tree for re-rendering");
}

- (void)markIndicatorsRecursively:(NSArray<TechnicalIndicatorBase *> *)indicators {
    for (TechnicalIndicatorBase *indicator in indicators) {
        indicator.needsRendering = YES;
        
        // Ricorsivo per i figli dei figli
        if (indicator.childIndicators.count > 0) {
            [self markIndicatorsRecursively:indicator.childIndicators];
        }
    }
}

#pragma mark - Coordinate System (NEW - Uniformato agli altri renderer)

- (void)updateCoordinateContext:(NSArray<HistoricalBarModel *> *)chartData
                     startIndex:(NSInteger)startIndex
                       endIndex:(NSInteger)endIndex
                      yRangeMin:(double)yMin
                      yRangeMax:(double)yMax
                         bounds:(CGRect)bounds {
    
    // Step 1: Update dei dati visibili (per future ottimizzazioni)
    // Potremmo voler cachare startIndex/endIndex per rendering ottimizzato
    
    // Step 2: Update bounds dei layer (IMPORTANTE: usa bounds passato, non panelView.bounds)
    [self updateLayerBoundsWithRect:bounds];
    
    // Step 3: Update Y coordinate context se l'IndicatorRenderer ne avrà bisogno
    // Per ora, gli indicatori usano principalmente le coordinate del panel parent
    // ma potremmo aggiungere un proprio PanelYCoordinateContext in futuro
    
    // Step 4: Invalida tutti i layer per forzare re-rendering con nuove coordinate
    [self invalidateIndicatorLayers];
    
    // ✅ FIX CRITICO: Chiama esplicitamente il re-rendering dopo invalidation
    if (self.rootIndicator) {
        [self renderIndicatorTree:self.rootIndicator];
        NSLog(@"🎨 IndicatorRenderer: Re-rendered after coordinate update");
    } else {
        NSLog(@"⚠️ IndicatorRenderer: No rootIndicator to re-render");
    }
    
    NSLog(@"🔄 ChartIndicatorRenderer: Coordinate contexts updated - Y Range: %.2f-%.2f, Height: %.0f, Visible: [%ld-%ld]",
          yMin, yMax, bounds.size.height, (long)startIndex, (long)endIndex);
}

- (void)updateLayerBoundsWithRect:(CGRect)bounds {
    // Converte CGRect a NSRect per compatibility
    NSRect boundsRect = NSRectFromCGRect(bounds);
    
    // Update del layer principale
    self.indicatorsLayer.frame = boundsRect;
    
    // Update di tutti i layer degli indicatori
    for (CAShapeLayer *layer in self.indicatorLayers.allValues) {
        layer.frame = boundsRect;
    }
    
    NSLog(@"📐 IndicatorRenderer: Updated layer bounds to %.0fx%.0f",
          bounds.size.width, bounds.size.height);
}




- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext {
    // ✅ Invalida + marca per re-rendering
    [self invalidateIndicatorLayers]; // ← Ora include markAllIndicatorsForRerendering!
    
    // ✅ FIX CRITICO: Aggiungi anche qui il re-rendering automatico
    if (self.rootIndicator) {
        [self renderIndicatorTree:self.rootIndicator];
        NSLog(@"🎨 IndicatorRenderer: Re-rendered after SharedXContext update");
    }
    
    NSLog(@"🔄 ChartIndicatorRenderer: SharedXContext updated");
}

- (void)updatePanelYContext:(PanelYCoordinateContext *)panelYContext {
    // ✅ Invalida + marca per re-rendering
    [self invalidateIndicatorLayers]; // ← Ora include markAllIndicatorsForRerendering!
    
    // ✅ FIX CRITICO: Aggiungi anche qui il re-rendering automatico
    if (self.rootIndicator) {
        [self renderIndicatorTree:self.rootIndicator];
        NSLog(@"🎨 IndicatorRenderer: Re-rendered after PanelYContext update");
    }
    
    NSLog(@"🔄 ChartIndicatorRenderer: PanelYContext updated");
}
@end
