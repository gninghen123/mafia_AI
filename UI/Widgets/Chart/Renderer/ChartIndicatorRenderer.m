//
// ChartIndicatorRenderer.m
// TradingApp
//
// ✅ REFACTORED: NSBezierPath-based rendering with CALayer delegate pattern
//

#import "ChartIndicatorRenderer.h"
#import "ChartPanelView.h"
#import "SharedXCoordinateContext.h"
#import "PanelYCoordinateContext.h"
#import "RuntimeModels.h"
#import "TechnicalIndicatorBase+Hierarchy.h"
#import "rawdataseriesindicator.h"

@implementation ChartIndicatorRenderer

#pragma mark - Initialization

- (instancetype)initWithPanelView:(ChartPanelView *)panelView {
    if (self = [super init]) {
        _panelView = panelView;
        _cachedVisibleData = [NSMutableDictionary dictionary];
        _lastVisibleStartIndex = NSNotFound;
        _lastVisibleEndIndex = NSNotFound;
        _panelYContext = [[PanelYCoordinateContext alloc] init];

        [self setupIndicatorsLayer];
        
        NSLog(@"🎨 ChartIndicatorRenderer: Initialized for panel: %@", panelView.panelType);
    }
    return self;
}

#pragma mark - Layer Management

- (void)setupIndicatorsLayer {
    self.indicatorsLayer = [CALayer layer];
    self.indicatorsLayer.frame = self.panelView.bounds;
    self.indicatorsLayer.delegate = self;
    self.indicatorsLayer.needsDisplayOnBoundsChange = YES;
    
    // Insert below objects layer but above chart content
    [self.panelView.layer addSublayer:self.indicatorsLayer];
    
    NSLog(@"🏗️ Setup indicators layer for panel: %@", self.panelView.panelType);
}

- (void)updateLayerBounds {
    CGRect newBounds = self.panelView.bounds;
    
    if (!CGRectEqualToRect(self.indicatorsLayer.frame, newBounds)) {
        self.indicatorsLayer.frame = newBounds;
        NSLog(@"📐 IndicatorRenderer: Updated layer bounds to %.0fx%.0f",
              newBounds.size.width, newBounds.size.height);
    }
}

#pragma mark - Coordinate System Integration

- (void)updateCoordinateContext:(NSArray<HistoricalBarModel *> *)chartData
                     startIndex:(NSInteger)startIndex
                       endIndex:(NSInteger)endIndex
                      yRangeMin:(double)yMin
                      yRangeMax:(double)yMax
                         bounds:(CGRect)bounds {
    
    // Update layer bounds if needed
    [self updateLayerBounds];
    
    // Check if visible range changed to optimize rendering
    BOOL visibleRangeChanged = [self hasVisibleRangeChanged:startIndex endIndex:endIndex];
    
    // Update cached visible range
    self.lastVisibleStartIndex = startIndex;
    self.lastVisibleEndIndex = endIndex;
    
    self.panelYContext.yRangeMin = yMin;
    self.panelYContext.yRangeMax = yMax;
    self.panelYContext.panelHeight = bounds.size.height;
    self.panelYContext.panelType = self.panelView.panelType;
    
    // Trigger re-rendering if rootIndicator exists
    if (self.rootIndicator) {
        if (visibleRangeChanged) {
            // Clear cached visible data when range changes
            [self.cachedVisibleData removeAllObjects];
        }
        
        [self invalidateIndicatorLayers];
    }
    
    NSLog(@"🔄 ChartIndicatorRenderer: Coordinate contexts updated - Y Range: %.2f-%.2f, Visible: [%ld-%ld]",
          yMin, yMax, (long)startIndex, (long)endIndex);
}

- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext {
    self.sharedXContext = sharedXContext;
    
    // Trigger re-rendering if rootIndicator exists
    if (self.rootIndicator) {
        [self invalidateIndicatorLayers];
    }
    
    NSLog(@"🔄 ChartIndicatorRenderer: SharedXContext updated");
}

- (void)updatePanelYContext:(PanelYCoordinateContext *)panelYContext {
    self.panelYContext = panelYContext;
    
    // Trigger re-rendering if rootIndicator exists
    if (self.rootIndicator) {
        [self invalidateIndicatorLayers];
    }
    
    NSLog(@"🔄 ChartIndicatorRenderer: PanelYContext updated");
}

#pragma mark - Rendering Management

- (void)renderIndicatorTree:(TechnicalIndicatorBase *)rootIndicator {
    
    if (self.panelView.chartWidget.indicatorsVisibilityToggle.state != NSControlStateValueOn) {
          NSLog(@"📈 Indicators disabled - skipping rendering");
          return;
      }
    self.rootIndicator = rootIndicator;
    
    if (!rootIndicator) {
        [self clearIndicatorLayers];
        return;
    }
    
    // Mark all indicators for rendering
    [self markAllIndicatorsForRerendering];
    
    // Trigger layer redraw
    [self invalidateIndicatorLayers];
    
    NSLog(@"🎨 Rendered indicator tree for: %@", rootIndicator.displayName);
}

- (void)clearIndicatorLayers {
    self.rootIndicator = nil;
    [self.cachedVisibleData removeAllObjects];
    [self.indicatorsLayer setNeedsDisplay];
    
    NSLog(@"🧹 Cleared all indicator layers");
}

- (void)invalidateIndicatorLayers {
    if (self.panelView.chartWidget.indicatorsVisibilityToggle.state != NSControlStateValueOn) {
          NSLog(@"📈 Indicators disabled - skipping rendering");
          return;
      }
    [self.indicatorsLayer setNeedsDisplay];
}

#pragma mark - CALayerDelegate Implementation

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    if (layer != self.indicatorsLayer || !self.rootIndicator) {
        return;
    }
    
    // Setup NSGraphicsContext for NSBezierPath drawing
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    // Verify coordinate contexts are available
    if (!self.sharedXContext || !self.panelYContext) {
        NSLog(@"⚠️ IndicatorRenderer: Missing coordinate contexts - skipping draw");
        [NSGraphicsContext restoreGraphicsState];
        return;
    }
    
    // Draw root indicator and children recursively
    [self drawIndicatorRecursively:self.rootIndicator];
    
    [NSGraphicsContext restoreGraphicsState];
    
    NSLog(@"🎨 Drew indicator tree in layer");
}

#pragma mark - Recursive Drawing

- (void)drawIndicatorRecursively:(TechnicalIndicatorBase *)indicator {
    if (!indicator || !indicator.isVisible || !indicator.outputSeries.count) {
        return;
    }
   /* // ✅ AGGIUNTO: Skip indicators senza output visuale
      if (![indicator hasVisualOutput]) {
          // Skip rendering ma continua con i children
          [self renderChildrenRecursively:indicator];
          return;
      }*/
      
    // Draw this indicator based on its type
    switch (indicator.visualizationType) {//todo
            case VisualizationTypeCandlestick:
                [self drawCandlestickIndicator:indicator];
                break;
                
            case VisualizationTypeHistogram:
                [self drawHistogramIndicator:indicator];
                break;
                
            case VisualizationTypeLine:
                [self drawLineIndicator:indicator];
                break;
                
            case VisualizationTypeArea:
                [self drawAreaIndicator:indicator];
                break;
                
            case VisualizationTypeOHLC:
                // TODO: Implementare OHLC bars se necessario
                [self drawLineIndicator:indicator]; // Fallback temporaneo
                break;
                
            default:
                // Fallback per tipi non gestiti
                [self drawLineIndicator:indicator];
                break;
        }
    
    // Recursively draw children
    [self renderChildrenRecursively:indicator];
}

- (void)renderChildrenRecursively:(TechnicalIndicatorBase *)parentIndicator {
    for (TechnicalIndicatorBase *child in parentIndicator.childIndicators) {
        [self drawIndicatorRecursively:child];
    }
}

#pragma mark - Specialized Drawing Methods

- (void)drawLineIndicator:(TechnicalIndicatorBase *)indicator {
    NSArray<IndicatorDataModel *> *visibleData = [self getVisibleDataForIndicator:indicator];
    if (!visibleData.count) return;
    
    NSBezierPath *path = [self createLinePathFromDataPoints:visibleData];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    [path stroke];

    NSLog(@"📈 Drew line indicator: %@ with %lu points",
          indicator.displayName, (unsigned long)visibleData.count);
}

- (void)drawHistogramIndicator:(TechnicalIndicatorBase *)indicator {
    NSArray<IndicatorDataModel *> *visibleData = [self getVisibleDataForIndicator:indicator];
    if (!visibleData.count) return;
    
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    NSBezierPath *path = [self createHistogramPathFromDataPoints:visibleData baselineY:baselineY];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultFillColorForIndicator:indicator] setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
    
    NSLog(@"📊 Drew histogram indicator: %@ with %lu bars",
          indicator.displayName, (unsigned long)visibleData.count);
}

- (void)drawAreaIndicator:(TechnicalIndicatorBase *)indicator {
    NSArray<IndicatorDataModel *> *visibleData = [self getVisibleDataForIndicator:indicator];
    if (!visibleData.count) return;
    
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    NSBezierPath *path = [self createAreaPathFromDataPoints:visibleData baselineY:baselineY];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    NSColor *fillColor = [[self defaultFillColorForIndicator:indicator] colorWithAlphaComponent:0.3];
    [fillColor setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
    
    NSLog(@"🎨 Drew area indicator: %@ with %lu points",
          indicator.displayName, (unsigned long)visibleData.count);
}

- (void)drawSignalIndicator:(TechnicalIndicatorBase *)indicator {
    NSArray<IndicatorDataModel *> *visibleData = [self getVisibleDataForIndicator:indicator];
    if (!visibleData.count) return;
    
    NSBezierPath *path = [self createSignalPathFromDataPoints:visibleData];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultFillColorForIndicator:indicator] setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
    
    NSLog(@"🎯 Drew signal indicator: %@ with %lu signals",
          indicator.displayName, (unsigned long)visibleData.count);
}

- (void)drawBandsIndicator:(TechnicalIndicatorBase *)indicator {
    // For bands, we expect multiple series (upper, middle, lower)
    // This is a simplified implementation - might need adjustment based on actual data structure
    
    [self drawLineIndicator:indicator]; // Fallback to line for now
    
    NSLog(@"📏 Drew bands indicator: %@", indicator.displayName);
}

#pragma mark - BezierPath Creation Helpers

- (NSBezierPath *)createLinePathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints {
    if (!dataPoints.count) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    BOOL isFirstPoint = YES;
    
    for (IndicatorDataModel *dataPoint in dataPoints) {
        // ✅ CRITICAL FIX: Skip NaN values FIRST before any coordinate conversion
        if (isnan(dataPoint.value)) {
            continue;
        }
        
        CGFloat x = [self xCoordinateForTimestamp:dataPoint.timestamp];
        CGFloat y = [self yCoordinateForValue:dataPoint.value];
        
        // Skip invalid coordinates (coordinate conversion problems)
        if (x < -9999 || y < -9999) continue;
        
        NSPoint point = NSMakePoint(x, y);
        
        if (isFirstPoint) {
            [path moveToPoint:point];
            isFirstPoint = NO;
        } else {
            [path lineToPoint:point];
        }
    }
    
    return path.elementCount > 0 ? path : nil;
}

- (NSBezierPath *)createHistogramPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints
                                          baselineY:(CGFloat)baselineY {
    if (!dataPoints.count) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat barWidth = [self.sharedXContext barWidth] * 0.8; // Slightly smaller than candle width
    
    for (IndicatorDataModel *dataPoint in dataPoints) {
        // ✅ SKIP NaN VALUES
        if (isnan(dataPoint.value)) continue;
        
        CGFloat x = [self xCoordinateForTimestamp:dataPoint.timestamp];
        CGFloat y = [self yCoordinateForValue:dataPoint.value];
        
        // Skip invalid coordinates
        if (x < -9999 || y < -9999) continue;
        
        // Create bar rectangle
        CGFloat barHeight = ABS(y - baselineY);
        CGFloat barBottom = MIN(y, baselineY);
        
        NSRect barRect = NSMakeRect(x - barWidth/2, barBottom, barWidth, barHeight);
        [path appendBezierPathWithRect:barRect];
    }
    
    return path.elementCount > 0 ? path : nil;
}

- (NSBezierPath *)createAreaPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints
                                     baselineY:(CGFloat)baselineY {
    if (!dataPoints.count) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSMutableArray *validPoints = [NSMutableArray array];
    
    // Collect valid points (skip NaN values)
    for (IndicatorDataModel *dataPoint in dataPoints) {
        // ✅ SKIP NaN VALUES
        if (isnan(dataPoint.value)) continue;
        
        CGFloat x = [self xCoordinateForTimestamp:dataPoint.timestamp];
        CGFloat y = [self yCoordinateForValue:dataPoint.value];
        
        if (x > -9999 && y > -9999) {
            [validPoints addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
        }
    }
    
    if (!validPoints.count) return nil;
    
    // Start from baseline at first point
    NSPoint firstPoint = [[validPoints firstObject] pointValue];
    [path moveToPoint:NSMakePoint(firstPoint.x, baselineY)];
    
    // Draw line through all points
    for (NSValue *pointValue in validPoints) {
        [path lineToPoint:[pointValue pointValue]];
    }
    
    // Close area back to baseline
    NSPoint lastPoint = [[validPoints lastObject] pointValue];
    [path lineToPoint:NSMakePoint(lastPoint.x, baselineY)];
    [path closePath];
    
    return path;
}

- (NSBezierPath *)createSignalPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints {
    if (!dataPoints.count) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat markerSize = 6.0;
    
    for (IndicatorDataModel *dataPoint in dataPoints) {
        // Only draw signals where value is non-zero
        if (ABS(dataPoint.value) < 0.001) continue;
        
        CGFloat x = [self xCoordinateForTimestamp:dataPoint.timestamp];
        CGFloat y = [self yCoordinateForValue:dataPoint.value];
        
        // Skip invalid coordinates
        if (x < -9999 || y < -9999) continue;
        
        // Create marker (circle for now, could be arrows based on value sign)
        NSRect markerRect = NSMakeRect(x - markerSize/2, y - markerSize/2, markerSize, markerSize);
        [path appendBezierPathWithOvalInRect:markerRect];
    }
    
    return path.elementCount > 0 ? path : nil;
}
#pragma mark - Specialized Drawing Methods

- (void)drawCandlestickIndicator:(TechnicalIndicatorBase *)indicator {
    // Per i candlestick, abbiamo bisogno dei dati OHLC originali dal ChartPanelView
    NSArray<HistoricalBarModel *> *chartData = self.panelView.chartData;
    if (!chartData.count) {
        NSLog(@"⚠️ No chart data available for candlestick rendering");
        return;
    }
    
    NSInteger startIndex = self.panelView.visibleStartIndex;
    NSInteger endIndex = self.panelView.visibleEndIndex;
    
    // Verifica range valido
    if (startIndex == NSNotFound || endIndex == NSNotFound || startIndex > endIndex) {
        NSLog(@"⚠️ Invalid visible range for candlestick rendering");
        return;
    }
    
    // Verifica che i coordinate contexts siano disponibili
    if (!self.sharedXContext || !self.panelYContext) {
        NSLog(@"⚠️ Missing coordinate contexts for candlestick rendering");
        return;
    }
    
    // ✅ Calcola barWidth per ottimizzazione
    CGFloat barWidth = [self.sharedXContext barWidth];
    barWidth -= [self.sharedXContext barSpacing];
    
    // 🚀 OTTIMIZZAZIONE: Se barWidth <= 1px, disegna solo linee semplici
    if (barWidth <= 1.0) {
        [self drawSimplifiedCandlesticks:chartData startIndex:startIndex endIndex:endIndex];
        return;
    }
    
    // ✅ DISEGNO COMPLETO per barWidth > 1px
    [self drawFullCandlesticks:chartData startIndex:startIndex endIndex:endIndex barWidth:barWidth];
    
    NSLog(@"🕯️ Drew candlestick indicator with %ld bars (width: %.1fpx)",
          (long)(endIndex - startIndex + 1), barWidth);
}

// 🚀 METODO PRIVATO: Disegno semplificato quando width <= 1px
- (void)drawSimplifiedCandlesticks:(NSArray<HistoricalBarModel *> *)chartData
                        startIndex:(NSInteger)startIndex
                          endIndex:(NSInteger)endIndex {
    
    NSColor *neutralColor = [NSColor labelColor]; // Colore neutro
    NSBezierPath *simplePath = [NSBezierPath bezierPath];
    simplePath.lineWidth = 1.0;
    
    [neutralColor setStroke];
    
    for (NSInteger i = startIndex; i <= endIndex && i < chartData.count; i++) {
        HistoricalBarModel *bar = chartData[i];
        
        // ✅ COORDINATE X - dal sharedXContext
        CGFloat centerX = [self.sharedXContext screenXForBarIndex:i] + ([self.sharedXContext barWidth] / 2.0);
        
        // ✅ COORDINATE Y - dal panelYContext
        CGFloat highY = [self.panelYContext screenYForValue:bar.high];
        CGFloat lowY = [self.panelYContext screenYForValue:bar.low];
        
        // Disegna solo una linea verticale da high a low
        [simplePath moveToPoint:NSMakePoint(centerX, highY)];
        [simplePath lineToPoint:NSMakePoint(centerX, lowY)];
    }
    
    [simplePath stroke];
    NSLog(@"📊 Simplified candlesticks drawn (%ld bars, width <= 1px)", (long)(endIndex - startIndex + 1));
}

// ✅ METODO PRIVATO: Disegno completo per barWidth > 1px
- (void)drawFullCandlesticks:(NSArray<HistoricalBarModel *> *)chartData
                  startIndex:(NSInteger)startIndex
                    endIndex:(NSInteger)endIndex
                    barWidth:(CGFloat)barWidth {
    
    // ✅ Pre-alloca colori e paths
    NSColor *greenColor = [NSColor systemGreenColor];
    NSColor *redColor = [NSColor systemRedColor];
    NSColor *strokeColor = [NSColor labelColor];
    CGFloat halfBarWidth = barWidth / 2.0;
    
    NSBezierPath *shadowPath = [NSBezierPath bezierPath];
    NSBezierPath *bodyPath = [NSBezierPath bezierPath];
    shadowPath.lineWidth = 1.0;
    
    for (NSInteger i = startIndex; i <= endIndex && i < chartData.count; i++) {
        HistoricalBarModel *bar = chartData[i];
        
        // ✅ COORDINATE X - dal sharedXContext
        CGFloat x = [self.sharedXContext screenXForBarIndex:i];
        
        // ✅ COORDINATE Y - dal panelYContext
        CGFloat openY = [self.panelYContext screenYForValue:bar.open];
        CGFloat closeY = [self.panelYContext screenYForValue:bar.close];
        CGFloat highY = [self.panelYContext screenYForValue:bar.high];
        CGFloat lowY = [self.panelYContext screenYForValue:bar.low];
        
        NSColor *bodyColor = (bar.close >= bar.open) ? greenColor : redColor;
        CGFloat centerX = x + halfBarWidth;
        
        // ✅ Draw high-low line (wick)
        [strokeColor setStroke];
        [shadowPath removeAllPoints];
        [shadowPath moveToPoint:NSMakePoint(centerX, highY)];
        [shadowPath lineToPoint:NSMakePoint(centerX, lowY)];
        [shadowPath stroke];
        
        // ✅ Draw body rectangle
        CGFloat bodyTop = MAX(openY, closeY);
        CGFloat bodyBottom = MIN(openY, closeY);
        CGFloat bodyHeight = bodyTop - bodyBottom;
        
        if (bodyHeight < 1) bodyHeight = 1; // Minimum height for doji
        
        NSRect bodyRect = NSMakeRect(x, bodyBottom, barWidth, bodyHeight);
        [bodyColor setFill];
        [bodyPath removeAllPoints];
        [bodyPath appendBezierPathWithRect:bodyRect];
        [bodyPath fill];
    }
    
    NSLog(@"📊 Full candlesticks drawn (%ld bars, width > 1px)", (long)(endIndex - startIndex + 1));
}

#pragma mark - Coordinate Conversion

- (CGFloat)xCoordinateForTimestamp:(NSDate *)timestamp {
    if (!self.sharedXContext || !timestamp) {
        return -9999;
    }
    
    return [self.sharedXContext screenXForDate:timestamp];
}

- (CGFloat)yCoordinateForValue:(double)value {
    if (!self.panelYContext) {
        return -9999;
    }
    
    return [self.panelYContext screenYForValue:value];
}

#pragma mark - Style and Color Helpers

- (NSColor *)defaultStrokeColorForIndicator:(TechnicalIndicatorBase *)indicator {
    // Return indicator-specific color or default
    return indicator.displayColor ?: [NSColor systemBlueColor];
}

- (CGFloat)defaultLineWidthForIndicator:(TechnicalIndicatorBase *)indicator {
    // Return indicator-specific width or default
    return indicator.lineWidth > 0 ? indicator.lineWidth : 2.0;
}

- (NSColor *)defaultFillColorForIndicator:(TechnicalIndicatorBase *)indicator {
    // Return indicator-specific fill color or derive from stroke color
    return indicator.displayColor ?: [self defaultStrokeColorForIndicator:indicator];
}

- (void)applyStyleToPath:(NSBezierPath *)path forIndicator:(TechnicalIndicatorBase *)indicator {
    path.lineWidth = [self defaultLineWidthForIndicator:indicator];
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    
    // Apply dash pattern if needed
    if ([indicator respondsToSelector:@selector(isDashed)] &&
        [[indicator valueForKey:@"isDashed"] boolValue]) {
        CGFloat pattern[] = {5.0, 3.0};
        [path setLineDash:pattern count:2 phase:0];
    }
}

#pragma mark - Visible Data Optimization

- (NSArray<IndicatorDataModel *> *)getVisibleDataForIndicator:(TechnicalIndicatorBase *)indicator {
    // Use cached data if available and visible range hasn't changed
    NSString *cacheKey = indicator.indicatorID;
    NSArray<IndicatorDataModel *> *cachedData = self.cachedVisibleData[cacheKey];
    
    if (cachedData &&
        self.lastVisibleStartIndex != NSNotFound &&
        self.lastVisibleEndIndex != NSNotFound) {
        return cachedData;
    }
    
    // Extract visible data
    NSArray<IndicatorDataModel *> *visibleData = [self extractVisibleDataPoints:indicator.outputSeries
                                                                      startIndex:self.lastVisibleStartIndex
                                                                        endIndex:self.lastVisibleEndIndex];
    
    // Cache the result
    if (visibleData) {
        self.cachedVisibleData[cacheKey] = visibleData;
    }
    
    return visibleData;
}

- (NSArray<IndicatorDataModel *> *)extractVisibleDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints
                                                  startIndex:(NSInteger)startIndex
                                                    endIndex:(NSInteger)endIndex {
    if (!dataPoints.count || startIndex == NSNotFound || endIndex == NSNotFound) {
        return dataPoints; // Return all if no visible range specified
    }
    
    // ✅ VALIDAZIONE DEGLI INDICI
    if (startIndex < 0) startIndex = 0;
    if (endIndex >= dataPoints.count) endIndex = dataPoints.count - 1;
    if (startIndex > endIndex) return @[]; // Range invalido
    
    // ✅ ESTRAI SOLO I DATI VISIBILI
    NSInteger length = endIndex - startIndex + 1; // +1 perché range è inclusivo
    NSRange visibleRange = NSMakeRange(startIndex, length);
    
    NSArray<IndicatorDataModel *> *visibleData = [dataPoints subarrayWithRange:visibleRange];
    
    NSLog(@"📊 Extracted %ld visible points from range [%ld-%ld] (total: %ld)",
          (long)visibleData.count, (long)startIndex, (long)endIndex, (long)dataPoints.count);
    
    return visibleData;
}

- (BOOL)hasVisibleRangeChanged:(NSInteger)startIndex endIndex:(NSInteger)endIndex {
    return (self.lastVisibleStartIndex != startIndex || self.lastVisibleEndIndex != endIndex);
}

#pragma mark - Visibility Management

- (void)setVisibilityRecursively:(NSArray<TechnicalIndicatorBase *> *)indicators visible:(BOOL)visible {
    for (TechnicalIndicatorBase *indicator in indicators) {
        indicator.isVisible = visible;
        indicator.needsRendering = YES;
        
        // Recursively apply to children
        if (indicator.childIndicators.count > 0) {
            [self setVisibilityRecursively:indicator.childIndicators visible:visible];
        }
    }
}

- (void)markAllIndicatorsForRerendering {
    if (self.rootIndicator) {
        [self markIndicatorForRerenderingRecursively:self.rootIndicator];
    }
}

- (void)markIndicatorForRerenderingRecursively:(TechnicalIndicatorBase *)indicator {
    indicator.needsRendering = YES;
    
    for (TechnicalIndicatorBase *child in indicator.childIndicators) {
        [self markIndicatorForRerenderingRecursively:child];
    }
}

#pragma mark - Cleanup

- (void)cleanup {
    [self clearIndicatorLayers];
    
    if (self.indicatorsLayer) {
        [self.indicatorsLayer removeFromSuperlayer];
        self.indicatorsLayer.delegate = nil;
        self.indicatorsLayer = nil;
    }
    
    self.sharedXContext = nil;
    self.panelYContext = nil;
    self.panelView = nil;
    
    NSLog(@"🧹 ChartIndicatorRenderer: Cleanup completed");
}

@end
