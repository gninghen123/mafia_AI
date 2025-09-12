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
        [self setupWarningMessagesLayer];

        NSLog(@"🎨 ChartIndicatorRenderer: Initialized for panel: %@", panelView.panelType);
    }
    return self;
}

#pragma mark - Layer Management (UPDATED)

- (void)setupIndicatorsLayer {
    self.indicatorsLayer = [CALayer layer];
    self.indicatorsLayer.delegate = self;
    self.indicatorsLayer.needsDisplayOnBoundsChange = YES;
    
    [self.panelView.layer insertSublayer:self.indicatorsLayer above:self.panelView.chartContentLayer];
    [self updateLayerBounds];
    
    NSLog(@"📊 ChartIndicatorRenderer: Indicators layer setup completed");
}

// 🆕 NEW: Setup warning messages layer
- (void)setupWarningMessagesLayer {
    self.warningMessagesLayer = [CATextLayer layer];
    self.warningMessagesLayer.fontSize = 12.0;
    self.warningMessagesLayer.foregroundColor = [NSColor systemOrangeColor].CGColor;
    self.warningMessagesLayer.backgroundColor = [[NSColor systemOrangeColor] colorWithAlphaComponent:0.1].CGColor;
    self.warningMessagesLayer.borderColor = [NSColor systemOrangeColor].CGColor;
    self.warningMessagesLayer.borderWidth = 1.0;
    self.warningMessagesLayer.cornerRadius = 4.0;
    self.warningMessagesLayer.alignmentMode = kCAAlignmentLeft;
    self.warningMessagesLayer.wrapped = YES;
    self.warningMessagesLayer.hidden = YES; // Hidden by default
    
    [self.panelView.layer insertSublayer:self.warningMessagesLayer above:self.indicatorsLayer];
    [self updateWarningMessagesLayerFrame];
    
    NSLog(@"⚠️ ChartIndicatorRenderer: Warning messages layer setup completed");
}

- (void)updateLayerBounds {
    if (self.indicatorsLayer) {
        self.indicatorsLayer.frame = self.panelView.bounds;
    }
    [self updateWarningMessagesLayerFrame];
}

// 🆕 NEW: Update warning messages layer position (bottom left)
- (void)updateWarningMessagesLayerFrame {
    if (!self.warningMessagesLayer) return;
    
    CGRect panelBounds = self.panelView.bounds;
    CGFloat warningWidth = 250;
    CGFloat warningHeight = 30;
    CGFloat margin = 10;
    
    CGRect warningFrame = CGRectMake(margin,
                                   margin,
                                   warningWidth,
                                   warningHeight);
    
    self.warningMessagesLayer.frame = warningFrame;
}

#pragma mark - Period Optimization (NEW)

- (BOOL)isPeriodTooShortForIndicator:(TechnicalIndicatorBase *)indicator visibleRange:(NSInteger)visibleRange {
    // ⚠️ IMPORTANTE: Questo controllo si applica SOLO ai child indicators
    // Il root indicator (dati principali come prezzo) deve sempre essere disegnato
    BOOL isRootIndicator = (indicator == self.rootIndicator);
    if (isRootIndicator) {
        return NO; // Root indicator sempre disegnato
    }
    
    NSInteger period = [self extractPeriodFromIndicator:indicator];
    NSInteger threshold = period * 30;
    
    BOOL isTooShort = threshold < visibleRange;
    
    if (isTooShort) {
        NSLog(@"⚠️ Period too short: %@ (child) period=%ld, threshold=%ld, visibleRange=%ld",
              indicator.shortName, (long)period, (long)threshold, (long)visibleRange);
    }
    
    return isTooShort;
}

- (NSInteger)extractPeriodFromIndicator:(TechnicalIndicatorBase *)indicator {
    // Try to extract period from parameters
    id periodValue = indicator.parameters[@"period"];
    if (periodValue && [periodValue isKindOfClass:[NSNumber class]]) {
        return [periodValue integerValue];
    }
    
    // Fallback to minimumBarsRequired if period not found
    NSInteger minBars = indicator.minimumBarsRequired;
    return MAX(1, minBars);
}

#pragma mark - Warning Messages System (NEW)

- (void)addWarningMessage:(NSString *)message {
    if (![self.activeWarnings containsObject:message]) {
        [self.activeWarnings addObject:message];
        [self updateWarningMessagesDisplay];
        NSLog(@"⚠️ Added warning: %@", message);
    }
}

- (void)clearWarningMessages {
    [self.activeWarnings removeAllObjects];
    [self updateWarningMessagesDisplay];
}

- (void)updateWarningMessagesDisplay {
    if (self.activeWarnings.count == 0) {
        self.warningMessagesLayer.hidden = YES;
        self.warningMessagesLayer.string = @"";
        return;
    }
    
    // Join all warnings with newlines
    NSString *combinedWarnings = [self.activeWarnings componentsJoinedByString:@"\n"];
    self.warningMessagesLayer.string = combinedWarnings;
    self.warningMessagesLayer.hidden = NO;
    
    // Adjust layer height based on number of warnings
    CGRect currentFrame = self.warningMessagesLayer.frame;
    CGFloat newHeight = MAX(30, self.activeWarnings.count * 18 + 12); // 18px per line + padding
    self.warningMessagesLayer.frame = CGRectMake(currentFrame.origin.x,
                                               currentFrame.origin.y,
                                               currentFrame.size.width,
                                               newHeight);
    
    NSLog(@"📄 Updated warning display: %lu warnings", (unsigned long)self.activeWarnings.count);
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
  
    
    BOOL isRoot = (indicator == self.rootIndicator);
     BOOL toggleIsOn = (self.panelView.chartWidget.indicatorsVisibilityToggle.state == NSControlStateValueOn);
     
    if (!isRoot && !toggleIsOn) {
         return;
     }
    // ✅ SKIP RENDERING FOR INDICATORS WITHOUT VISUAL OUTPUT
       if (![indicator hasVisualOutput]) {
           // Skip rendering ma continua con i children
           [self renderChildrenRecursively:indicator];
           return;
       }
       
       // 🆕 NEW: PERIOD OPTIMIZATION - Skip rendering if period too short
       NSInteger visibleRange = self.lastVisibleEndIndex - self.lastVisibleStartIndex + 1;
       if (visibleRange > 0 && [self isPeriodTooShortForIndicator:indicator visibleRange:visibleRange]) {
           
           // Add warning message
           NSString *warningMessage = [NSString stringWithFormat:@"⚠️ %@ periodi troppo brevi!", indicator.shortName];
           [self addWarningMessage:warningMessage];
           
           // Skip rendering completely for this indicator
           NSLog(@"🚫 Skipping render for %@ - period too short (range=%ld)",
                 indicator.shortName, (long)visibleRange);
           
           // Still process children (they might have different periods)
           [self renderChildrenRecursively:indicator];
           return;
       }
       
      
    // Draw this indicator based on its type
    switch (indicator.visualizationType) {
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

#pragma mark - Visible Data Optimization (UPDATED)

- (BOOL)hasVisibleRangeChanged:(NSInteger)startIndex endIndex:(NSInteger)endIndex {
    return (self.lastVisibleStartIndex != startIndex || self.lastVisibleEndIndex != endIndex);
}

- (NSRange)validVisibleRangeForIndicator:(TechnicalIndicatorBase *)indicator
                              startIndex:(NSInteger)startIndex
                                endIndex:(NSInteger)endIndex {
    NSInteger dataCount = indicator.outputSeries.count;
    
    if (!dataCount || startIndex == NSNotFound || endIndex == NSNotFound) {
        return NSMakeRange(0, dataCount); // Return full range if no visible range specified
    }
    
    // ✅ VALIDAZIONE E CLAMPING DEGLI INDICI
    if (startIndex < 0) startIndex = 0;
    if (endIndex >= dataCount) endIndex = dataCount - 1;
    if (startIndex > endIndex) return NSMakeRange(0, 0); // Range invalido
    
    NSInteger length = endIndex - startIndex + 1; // +1 perché range è inclusivo
    return NSMakeRange(startIndex, length);
}

#pragma mark - Specialized Drawing Methods (UPDATED - No Array Allocation)

- (void)drawLineIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator.outputSeries.count) return;
    
    // ✅ USA GLI INDICI DIRETTAMENTE - NO ARRAY ALLOCATION
    NSRange visibleRange = [self validVisibleRangeForIndicator:indicator
                                                   startIndex:self.lastVisibleStartIndex
                                                     endIndex:self.lastVisibleEndIndex];
    
    if (visibleRange.length == 0) return;
    
    NSBezierPath *path = [self createLinePathFromIndicator:indicator
                                                startIndex:visibleRange.location
                                                  endIndex:visibleRange.location + visibleRange.length - 1];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    [path stroke];

    NSLog(@"📈 Drew line indicator: %@ with range [%ld-%ld] (%ld points)",
          indicator.displayName, (long)visibleRange.location,
          (long)(visibleRange.location + visibleRange.length - 1), (long)visibleRange.length);
}

- (void)drawHistogramIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator.outputSeries.count) return;
    
    // ✅ USA GLI INDICI DIRETTAMENTE - NO ARRAY ALLOCATION
    NSRange visibleRange = [self validVisibleRangeForIndicator:indicator
                                                   startIndex:self.lastVisibleStartIndex
                                                     endIndex:self.lastVisibleEndIndex];
    
    if (visibleRange.length == 0) return;
    
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    NSBezierPath *path = [self createHistogramPathFromIndicator:indicator
                                                     startIndex:visibleRange.location
                                                       endIndex:visibleRange.location + visibleRange.length - 1
                                                      baselineY:baselineY];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultFillColorForIndicator:indicator] setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
    
    NSLog(@"📊 Drew histogram indicator: %@ with range [%ld-%ld] (%ld bars)",
          indicator.displayName, (long)visibleRange.location,
          (long)(visibleRange.location + visibleRange.length - 1), (long)visibleRange.length);
}

- (void)drawAreaIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator.outputSeries.count) return;
    
    // ✅ USA GLI INDICI DIRETTAMENTE - NO ARRAY ALLOCATION
    NSRange visibleRange = [self validVisibleRangeForIndicator:indicator
                                                   startIndex:self.lastVisibleStartIndex
                                                     endIndex:self.lastVisibleEndIndex];
    
    if (visibleRange.length == 0) return;
    
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    NSBezierPath *path = [self createAreaPathFromIndicator:indicator
                                                startIndex:visibleRange.location
                                                  endIndex:visibleRange.location + visibleRange.length - 1
                                                 baselineY:baselineY];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    NSColor *fillColor = [[self defaultFillColorForIndicator:indicator] colorWithAlphaComponent:0.3];
    [fillColor setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
    
    NSLog(@"🎨 Drew area indicator: %@ with range [%ld-%ld] (%ld points)",
          indicator.displayName, (long)visibleRange.location,
          (long)(visibleRange.location + visibleRange.length - 1), (long)visibleRange.length);
}

- (void)drawSignalIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator.outputSeries.count) return;
    
    // ✅ USA GLI INDICI DIRETTAMENTE - NO ARRAY ALLOCATION
    NSRange visibleRange = [self validVisibleRangeForIndicator:indicator
                                                   startIndex:self.lastVisibleStartIndex
                                                     endIndex:self.lastVisibleEndIndex];
    
    if (visibleRange.length == 0) return;
    
    NSBezierPath *path = [self createSignalPathFromIndicator:indicator
                                                  startIndex:visibleRange.location
                                                    endIndex:visibleRange.location + visibleRange.length - 1];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultFillColorForIndicator:indicator] setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
    
    NSLog(@"🎯 Drew signal indicator: %@ with range [%ld-%ld] (%ld signals)",
          indicator.displayName, (long)visibleRange.location,
          (long)(visibleRange.location + visibleRange.length - 1), (long)visibleRange.length);
}

#pragma mark - BezierPath Creation Helpers (UPDATED - Direct Index Access)

- (NSBezierPath *)createLinePathFromIndicator:(TechnicalIndicatorBase *)indicator
                                   startIndex:(NSInteger)startIndex
                                     endIndex:(NSInteger)endIndex {
    
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    if (!dataPoints.count) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    BOOL isFirstPoint = YES;
    
    // ✅ ITERA DIRETTAMENTE SUGLI INDICI - NO ARRAY ALLOCATION
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *dataPoint = dataPoints[i];
        
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

- (NSBezierPath *)createHistogramPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                        startIndex:(NSInteger)startIndex
                                          endIndex:(NSInteger)endIndex
                                         baselineY:(CGFloat)baselineY {
    
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    if (!dataPoints.count) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat barWidth = [self.sharedXContext barWidth] * 0.8; // Slightly smaller than candle width
    
    // ✅ ITERA DIRETTAMENTE SUGLI INDICI - NO ARRAY ALLOCATION
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *dataPoint = dataPoints[i];
        
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

- (NSBezierPath *)createAreaPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                   startIndex:(NSInteger)startIndex
                                     endIndex:(NSInteger)endIndex
                                    baselineY:(CGFloat)baselineY {
    
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    if (!dataPoints.count) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSMutableArray *validPoints = [NSMutableArray array];
    
    // ✅ ITERA DIRETTAMENTE SUGLI INDICI - NO ARRAY ALLOCATION
    // Collect valid points (skip NaN values)
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *dataPoint = dataPoints[i];
        
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

- (NSBezierPath *)createSignalPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                     startIndex:(NSInteger)startIndex
                                       endIndex:(NSInteger)endIndex {
    
    NSArray<IndicatorDataModel *> *dataPoints = indicator.outputSeries;
    if (!dataPoints.count) return nil;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat markerSize = 6.0;
    
    // ✅ ITERA DIRETTAMENTE SUGLI INDICI - NO ARRAY ALLOCATION
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *dataPoint = dataPoints[i];
        
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



#pragma mark - Visibility Management

- (void)setVisibilityRecursively:(NSArray<TechnicalIndicatorBase *> *)indicators visible:(BOOL)visible {
    for (TechnicalIndicatorBase *indicator in indicators) {
        if (indicator != self.rootIndicator) {
            indicator.isVisible = visible;
            indicator.needsRendering = YES;
        }
       
        
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
