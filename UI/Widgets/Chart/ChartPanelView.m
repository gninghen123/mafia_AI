//
//  ChartPanelView.m
//  TradingApp
//
//  Individual chart panel for rendering specific indicators
//

#import "AppDelegate.h"
#import "ChartPanelView.h"
#import "ChartWidget.h"
#import "ChartObjectRenderer.h"
#import "ChartObjectModels.h"
#import "ChartObjectsManager.h"
#import "ChartObjectSettingsWindow.h"
#import <objc/runtime.h>
#import "ChartAlertRenderer.h"
#import "AlertEditController.h"
#import "dataHub.h"
#import "datahub+marketdata.h"
#import "FloatingWidgetWindow.h"

@interface ChartPanelView ()


- (void)drawYAxisContent;
- (double)calculateOptimalTickStep:(double)range targetTicks:(NSInteger)targetTicks;


@property (nonatomic, assign) BOOL isInAlertDragMode;

// Mouse tracking
@property (nonatomic, strong) NSTrackingArea *trackingArea;

// Interaction state
@property (nonatomic, assign) BOOL isMouseDown;
@property (nonatomic, assign) BOOL isRightMouseDown;
@property (nonatomic, assign) NSPoint dragStartPoint;
@property (nonatomic, assign) NSPoint lastMousePoint;

// Selection state
@property (nonatomic, assign) BOOL isInChartPortionSelectionMode;
@property (nonatomic, assign) NSInteger selectionStartIndex;
@property (nonatomic, assign) NSInteger selectionEndIndex;
@property (nonatomic, assign) BOOL isInObjectCreationMode;
@property (nonatomic, assign) BOOL isInObjectEditingMode;
@property (nonatomic, assign) ChartObjectType currentCreationObjectType;


@end

@implementation ChartPanelView

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type {
    self = [super init];
    if (self) {
        _panelType = type;
        [self setupPanel];
        
    }
    return self;
}

- (void)setupPanel {
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.borderWidth = 1.0;
    self.dragThreshold = 4.0; // pixels

    [self setupPerformanceLayers];
    [self setupMouseTracking];
}


- (void)setupPerformanceLayers {
    // Chart content layer (static - redraws only when data changes)
    self.chartContentLayer = [CALayer layer];
    self.chartContentLayer.delegate = self;
    self.chartContentLayer.needsDisplayOnBoundsChange = YES;
    [self.layer addSublayer:self.chartContentLayer];
    
    // Selection layer (redraws only during selection)
    self.chartPortionSelectionLayer = [CALayer layer];
    self.chartPortionSelectionLayer.delegate = self;
    [self.layer addSublayer:self.chartPortionSelectionLayer];
    
    // 🆕 Y-Axis layer (redraws only when Y range changes)
    self.yAxisLayer = [CALayer layer];
    self.yAxisLayer.delegate = self;
    self.yAxisLayer.needsDisplayOnBoundsChange = YES;
    [self.layer addSublayer:self.yAxisLayer];
    
    // Crosshair layer (redraws frequently but lightweight)
    self.crosshairLayer = [CALayer layer];
    self.crosshairLayer.delegate = self;
    [self.layer addSublayer:self.crosshairLayer];
    
    NSLog(@"🎯 ChartPanelView: Performance layers setup completed with Y-Axis");
}



- (void)layout {
    [super layout];
    
    // Update all layer frames
    NSRect bounds = self.bounds;
    
    // Chart content area (reduced width for Y-axis)
    NSRect chartContentBounds = NSMakeRect(0, 0,
                                         bounds.size.width - Y_AXIS_WIDTH,
                                         bounds.size.height);
    self.chartContentLayer.frame = chartContentBounds;
    self.chartPortionSelectionLayer.frame = chartContentBounds;
    
    // Y-Axis area (right side)
    NSRect yAxisBounds = NSMakeRect(bounds.size.width - Y_AXIS_WIDTH, 0,
                                   Y_AXIS_WIDTH, bounds.size.height);
    self.yAxisLayer.frame = yAxisBounds;
    
    // Crosshair spans full width
    self.crosshairLayer.frame = bounds;
    
    // Update objects renderer layer frames AND coordinate context bounds
    if (self.objectRenderer) {
        [self.objectRenderer updateLayerFrames];
        
        // Update bounds in coordinate context (use chart area, not full bounds)
        if (self.chartData) {
            [self.objectRenderer updateCoordinateContext:self.chartData
                                              startIndex:self.visibleStartIndex
                                                endIndex:self.visibleEndIndex
                                               yRangeMin:self.yRangeMin
                                               yRangeMax:self.yRangeMax
                                                  bounds:chartContentBounds]; // Use chart area
        }
    }
}

#pragma mark - CALayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    if (layer == self.chartContentLayer) {
        [self drawChartContent];
    } else if (layer == self.crosshairLayer) {
        [self drawCrosshairContent];
    } else if (layer == self.chartPortionSelectionLayer) {
        [self drawChartPortionSelectionContent];
    } else if (layer == self.yAxisLayer) {
        [self drawYAxisContent]; // 🆕 QUESTO DEVE ESSERE PRESENTE!
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)setupMouseTracking {
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                     options:(NSTrackingActiveInKeyWindow |
                                                             NSTrackingInVisibleRect |
                                                             NSTrackingMouseMoved |
                                                             NSTrackingMouseEnteredAndExited)
                                                       owner:self
                                                    userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

#pragma mark - Data Update



- (void)updateWithData:(NSArray<HistoricalBarModel *> *)data
            startIndex:(NSInteger)startIndex
              endIndex:(NSInteger)endIndex
             yRangeMin:(double)yMin
             yRangeMax:(double)yMax {
    
    // Check if Y range changed
    BOOL yRangeChanged = (self.yRangeMin != yMin || self.yRangeMax != yMax);
    
    // Update data properties
    self.chartData = data;
    self.visibleStartIndex = startIndex;
    self.visibleEndIndex = endIndex;
    self.yRangeMin = yMin;
    self.yRangeMax = yMax;
    
    // Update objects renderer coordinate context
    if (self.objectRenderer) {
        NSRect chartBounds = NSMakeRect(0, 0,
                                      self.bounds.size.width - Y_AXIS_WIDTH,
                                      self.bounds.size.height);
        [self.objectRenderer updateCoordinateContext:data
                                          startIndex:startIndex
                                            endIndex:endIndex
                                           yRangeMin:yMin
                                           yRangeMax:yMax
                                              bounds:chartBounds];
    }
    
    // Update alert renderer if available
    if (self.alertRenderer) {
        NSRect chartBounds = NSMakeRect(0, 0,
                                      self.bounds.size.width - Y_AXIS_WIDTH,
                                      self.bounds.size.height);
        [self.alertRenderer updateCoordinateContext:data
                                         startIndex:startIndex
                                           endIndex:endIndex
                                          yRangeMin:yMin
                                          yRangeMax:yMax
                                             bounds:chartBounds
                                      currentSymbol:self.chartWidget.currentSymbol];
    }
    
    [self invalidateChartContent];
    
    // Invalidate Y-Axis only if range changed (performance optimization)
    if (yRangeChanged) {
        [self invalidateYAxis];
        NSLog(@"📊 Y-Axis invalidated: range [%.2f - %.2f]", yMin, yMax);
    }
}
- (void)setCrosshairPoint:(NSPoint)point visible:(BOOL)visible {
    self.crosshairPoint = point;
    self.crosshairVisible = visible;
    [self updateCrosshairOnly];
}

- (void)invalidateChartContent {
    // Only redraw the heavy chart content layer
    [self.chartContentLayer setNeedsDisplay];
}

- (void)updateCrosshairOnly {
    // Only redraw the lightweight crosshair layer
    [self.crosshairLayer setNeedsDisplay];
}

#pragma mark - Layer-Specific Drawing

- (void)drawChartContent {
    if (!self.chartData || self.chartData.count == 0) {
        [self drawEmptyState];
        return;
    }
    
    // Draw based on panel type
    if ([self.panelType isEqualToString:@"security"]) {
        [self drawCandlesticks];
    } else if ([self.panelType isEqualToString:@"volume"]) {
        [self drawVolumeHistogram];
    }
    
    NSLog(@"🎨 ChartPanelView: Chart content drawn (%@ panel)", self.panelType);
}


- (void)drawCrosshairContent {
    if (!self.crosshairVisible) return;
    
    NSPoint point = self.crosshairPoint;
    
    // Draw crosshair lines
    [[NSColor labelColor] setStroke];
    
    NSBezierPath *crosshair = [NSBezierPath bezierPath];
    crosshair.lineWidth = 1.0;
    
    // Vertical line (spans full height, but only in chart area)
    CGFloat chartAreaWidth = self.bounds.size.width - Y_AXIS_WIDTH;
    if (point.x <= chartAreaWidth) { // Solo se dentro l'area chart
        [crosshair moveToPoint:NSMakePoint(point.x, 0)];
        [crosshair lineToPoint:NSMakePoint(point.x, self.bounds.size.height)];
    }
    
    // 🔧 FIX: Horizontal line - FERMARSI al chart area, NON entrare nell'asse Y
    [crosshair moveToPoint:NSMakePoint(CHART_MARGIN_LEFT, point.y)];
    [crosshair lineToPoint:NSMakePoint(chartAreaWidth, point.y)]; // Stop at chart area edge
    
    [crosshair stroke];
    
    // 🆕 NEW: Price/Value bubble nell'asse Y
    [self drawPriceBubbleAtCrosshair];
    
    // 🆕 NEW: Date/Time bubble in basso (solo se crosshair in chart area)
    if (point.x <= chartAreaWidth) {
        [self drawDateBubbleAtCrosshair];
    }
}

- (NSPoint)clampCrosshairToChartArea:(NSPoint)rawPoint {
    CGFloat chartAreaWidth = self.bounds.size.width - Y_AXIS_WIDTH;
    
    // Clamp X to chart area (non entrare nell'asse Y)
    CGFloat clampedX = MAX(CHART_MARGIN_LEFT, MIN(rawPoint.x, chartAreaWidth));
    
    // Y può essere ovunque nell'altezza
    CGFloat clampedY = MAX(0, MIN(rawPoint.y, self.bounds.size.height));
    
    return NSMakePoint(clampedX, clampedY);
}

// 2. 🆕 AGGIUNGERE: Price/Value bubble nell'asse Y

- (void)drawPriceBubbleAtCrosshair {
    if (!self.crosshairVisible) return;
    
    // Calcola il valore alla posizione Y del crosshair
    double currentValue = [self valueForYCoordinate:self.crosshairPoint.y];
    NSString *valueText = [self formatValueForDisplay:currentValue];
    
    // Font più grande e bold per effetto magnifier
    NSDictionary *bubbleAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:13], // vs 11 per asse normale
        NSForegroundColorAttributeName: [NSColor controlBackgroundColor]
    };
    
    NSSize textSize = [valueText sizeWithAttributes:bubbleAttributes];
    
    // Posiziona nell'area dell'asse Y (lato destro)
    CGFloat bubbleX = self.bounds.size.width - Y_AXIS_WIDTH + 8;
    CGFloat bubbleY = self.crosshairPoint.y - textSize.height/2;
    
    // Clamp alla vista per evitare che esca dai bounds
    bubbleY = MAX(5, MIN(bubbleY, self.bounds.size.height - textSize.height - 5));
    
    // Bubble background con colore accent
    NSRect bubbleRect = NSMakeRect(bubbleX - 4, bubbleY - 3,
                                  textSize.width + 8, textSize.height + 6);
    
    // Colore dinamico basato sul tipo di panel
    NSColor *bubbleColor;
    if ([self.panelType isEqualToString:@"volume"]) {
        bubbleColor = [NSColor systemOrangeColor]; // Volume = arancione
    } else {
        bubbleColor = [NSColor systemBlueColor];   // Price = blu
    }
    
    [bubbleColor setFill];
    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:bubbleRect
                                                              xRadius:4 yRadius:4];
    [bubblePath fill];
    
    // Border sottile per definizione
    [[NSColor controlBackgroundColor] setStroke];
    bubblePath.lineWidth = 1.0;
    [bubblePath stroke];
    
    // Disegna il testo del valore
    [valueText drawAtPoint:NSMakePoint(bubbleX, bubbleY) withAttributes:bubbleAttributes];
}

// 3. 🆕 AGGIUNGERE: Date/Time bubble in basso

- (void)drawDateBubbleAtCrosshair {
    if (!self.crosshairVisible || !self.chartData || self.chartData.count == 0) return;
    
    // 🆕 FIX: Only show if crosshair is in chart area
    CGFloat chartAreaWidth = self.bounds.size.width - Y_AXIS_WIDTH;
    if (self.crosshairPoint.x > chartAreaWidth) return;
    
    // Trova l'indice della barra sotto il crosshair
    NSInteger barIndex = [self barIndexForXCoordinate:self.crosshairPoint.x];
    if (barIndex < 0 || barIndex >= self.chartData.count) return;
    
    HistoricalBarModel *bar = self.chartData[barIndex];
    if (!bar.date) return;
    
    // Formatta data/orario basandosi sul timeframe
    NSString *dateText = [self formatDateTimeForDisplay:bar.date];
    
    // Font per la bubble temporale
    NSDictionary *dateAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor controlBackgroundColor]
    };
    
    NSSize textSize = [dateText sizeWithAttributes:dateAttributes];
    
    // Posiziona in basso, centrata sulla linea verticale del crosshair
    CGFloat bubbleX = self.crosshairPoint.x - textSize.width/2;
    CGFloat bubbleY = 8; // 8px dal bottom
    
    // 🆕 FIX: Clamp orizzontalmente DENTRO l'area chart (non nell'asse Y)
    CGFloat maxX = chartAreaWidth - textSize.width - 8;
    bubbleX = MAX(CHART_MARGIN_LEFT + 8, MIN(bubbleX, maxX));
    
    // Bubble background
    NSRect bubbleRect = NSMakeRect(bubbleX - 6, bubbleY - 3,
                                  textSize.width + 12, textSize.height + 6);
    
    // Colore distintivo per il tempo
    [[NSColor systemGreenColor] setFill];
    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:bubbleRect
                                                              xRadius:4 yRadius:4];
    [bubblePath fill];
    
    // Border
    [[NSColor controlBackgroundColor] setStroke];
    bubblePath.lineWidth = 1.0;
    [bubblePath stroke];
    
    // Disegna il testo della data/ora
    [dateText drawAtPoint:NSMakePoint(bubbleX, bubbleY) withAttributes:dateAttributes];
}


// 4. 🆕 AGGIUNGERE: Helper per formattare date/time

- (NSString *)formatDateTimeForDisplay:(NSDate *)timestamp {
    if (!timestamp) return @"--";
    
    // Ottieni il timeframe corrente dal ChartWidget
    NSInteger timeframeMinutes = 0;
    if (self.chartWidget && [self.chartWidget respondsToSelector:@selector(getCurrentTimeframeInMinutes)]) {
        timeframeMinutes = [self.chartWidget getCurrentTimeframeInMinutes];
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    // Formatazione intelligente basata sul timeframe
    if (timeframeMinutes <= 0) {
        // Timeframe sconosciuto - mostra data e ora complete
        formatter.dateFormat = @"MMM dd HH:mm";
    } else if (timeframeMinutes < 60) {
        // Intraday (< 1 ora): mostra data e ora
        formatter.dateFormat = @"MMM dd HH:mm";
    } else if (timeframeMinutes < 1440) {
        // Intraday (>= 1 ora, < 1 giorno): mostra data e ora
        formatter.dateFormat = @"MMM dd HH:mm";
    } else if (timeframeMinutes == 1440) {
        // Daily: mostra solo data
        formatter.dateFormat = @"MMM dd, yyyy";
    } else if (timeframeMinutes == 10080) {
        // Weekly: mostra settimana
        formatter.dateFormat = @"'Week of' MMM dd";
    } else {
        // Monthly o superiore: mostra mese/anno
        formatter.dateFormat = @"MMM yyyy";
    }
    
    return [formatter stringFromDate:timestamp];
}


- (void)drawYAxisContent {
    if (self.yRangeMax == self.yRangeMin) return;
    
    // Y-Axis background
    [[NSColor controlBackgroundColor] setFill];
    NSRect axisBounds = NSMakeRect(0, 0, Y_AXIS_WIDTH, self.bounds.size.height);
    [[NSBezierPath bezierPathWithRect:axisBounds] fill];
    
    // Y-Axis border (left edge)
    [[NSColor separatorColor] setStroke];
    NSBezierPath *borderPath = [NSBezierPath bezierPath];
    borderPath.lineWidth = 1.0;
    [borderPath moveToPoint:NSMakePoint(0, 0)];
    [borderPath lineToPoint:NSMakePoint(0, self.bounds.size.height)];
    [borderPath stroke];
    
    // Calculate tick values
    double valueRange = self.yRangeMax - self.yRangeMin;
    NSInteger tickCount = 8;
    double tickStep = [self calculateOptimalTickStep:valueRange targetTicks:tickCount];
    
    // Start from first tick above yRangeMin
    double firstTick = ceil(self.yRangeMin / tickStep) * tickStep;
    
    // Text attributes for labels
    NSDictionary *textAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    // Draw ticks and labels
    for (double value = firstTick; value <= self.yRangeMax; value += tickStep) {
        CGFloat yPosition = [self yCoordinateForValue:value];
        
        if (yPosition < 0 || yPosition > self.bounds.size.height) continue;
        
        // Draw tick mark
        [[NSColor tertiaryLabelColor] setStroke];
        NSBezierPath *tickPath = [NSBezierPath bezierPath];
        tickPath.lineWidth = 1.0;
        [tickPath moveToPoint:NSMakePoint(0, yPosition)];
        [tickPath lineToPoint:NSMakePoint(8, yPosition)];
        [tickPath stroke];
        
        // Format label based on panel type
        NSString *labelText = [self formatValueForDisplay:value];
        NSSize textSize = [labelText sizeWithAttributes:textAttributes];
        
        NSPoint textPoint = NSMakePoint(12, yPosition - textSize.height/2);
        [labelText drawAtPoint:textPoint withAttributes:textAttributes];
    }
}

- (void)drawChartPortionSelectionContent {
    if (!self.isInChartPortionSelectionMode) return;
    
    // ✅ USA IL METODO ESISTENTE invece di riscriverlo
    [self drawChartPortionSelection];
}
- (void)drawRect:(NSRect)dirtyRect {
    // drawRect is now unused - all drawing happens in layer delegates
    // This improves performance by using CALayer rendering pipeline
}

#pragma mark - Original Drawing Methods (now used by layers)

- (void)drawEmptyState {
    NSString *message = [NSString stringWithFormat:@"%@ Panel - No Data", self.panelType.capitalizedString];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    NSSize textSize = [message sizeWithAttributes:attributes];
    NSPoint drawPoint = NSMakePoint((self.bounds.size.width - textSize.width) / 2,
                                   (self.bounds.size.height - textSize.height) / 2);
    
    [message drawAtPoint:drawPoint withAttributes:attributes];
}

- (void)drawCandlesticks {
    if (self.visibleStartIndex >= self.visibleEndIndex || self.visibleEndIndex > self.chartData.count) {
        return;
    }
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    // Use chart area width (excluding Y-axis)
    CGFloat chartAreaWidth = self.bounds.size.width - Y_AXIS_WIDTH - (2 * CHART_MARGIN_LEFT);
    CGFloat barWidth = chartAreaWidth / visibleBars;
    CGFloat barSpacing = MAX(1, barWidth * 0.1);
    barWidth = barWidth - barSpacing;
    
    for (NSInteger i = self.visibleStartIndex; i < self.visibleEndIndex && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        
        CGFloat x = CHART_MARGIN_LEFT + (i - self.visibleStartIndex) * (barWidth + barSpacing);
        CGFloat openY = [self yCoordinateForPrice:bar.open];
        CGFloat closeY = [self yCoordinateForPrice:bar.close];
        CGFloat highY = [self yCoordinateForPrice:bar.high];
        CGFloat lowY = [self yCoordinateForPrice:bar.low];
        
        // Color based on direction
        NSColor *bodyColor = (bar.close >= bar.open) ?
                            [NSColor systemGreenColor] : [NSColor systemRedColor];
        
        // Draw wick (high-low line)
        [bodyColor setStroke];
        NSBezierPath *wick = [NSBezierPath bezierPath];
        wick.lineWidth = 1.0;
        [wick moveToPoint:NSMakePoint(x + barWidth/2, lowY)];
        [wick lineToPoint:NSMakePoint(x + barWidth/2, highY)];
        [wick stroke];
        
        // Draw body (open-close rectangle)
        NSRect bodyRect = NSMakeRect(x, MIN(openY, closeY), barWidth, fabs(closeY - openY));
        if (bodyRect.size.height < 1) bodyRect.size.height = 1; // Minimum height for doji
        
        [bodyColor setFill];
        [[NSBezierPath bezierPathWithRect:bodyRect] fill];
    }
}

// 6. 🆕 NEW method: Y-Axis rendering



// 7. 🆕 Helper methods for Y-Axis

- (double)calculateOptimalTickStep:(double)range targetTicks:(NSInteger)targetTicks {
    if (range <= 0 || targetTicks <= 0) return 1.0;
    
    double rawStep = range / targetTicks;
    double magnitude = pow(10, floor(log10(rawStep)));
    double normalizedStep = rawStep / magnitude;
    
    // Choose nice step sizes
    if (normalizedStep <= 1.0) {
        return magnitude;
    } else if (normalizedStep <= 2.0) {
        return 2.0 * magnitude;
    } else if (normalizedStep <= 5.0) {
        return 5.0 * magnitude;
    } else {
        return 10.0 * magnitude;
    }
}

- (void)calculatePanelSpecificYRange {
    if (!self.chartData || self.chartData.count == 0) return;
    
    double minValue = DBL_MAX;
    double maxValue = -DBL_MAX;
    
    for (NSInteger i = self.visibleStartIndex; i < self.visibleEndIndex && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        
        if ([self.panelType isEqualToString:@"security"]) {
            // Price panel: use high/low
            minValue = MIN(minValue, bar.low);
            maxValue = MAX(maxValue, bar.high);
        } else if ([self.panelType isEqualToString:@"volume"]) {
            // Volume panel: use volume (min is always 0 for volumes)
            minValue = 0;
            maxValue = MAX(maxValue, bar.volume);
        }
        // Add other panel types here as needed
    }
    
    if (maxValue > minValue) {
        // Add 5% padding for security panels, 2% for volume panels
        double paddingPercent = [self.panelType isEqualToString:@"security"] ? 0.05 : 0.02;
        double range = maxValue - minValue;
        double padding = range * paddingPercent;
        
        self.yRangeMin = minValue - padding;
        self.yRangeMax = maxValue + padding;
        
        // Ensure volume panels start from 0
        if ([self.panelType isEqualToString:@"volume"]) {
            self.yRangeMin = 0;
        }
        
        NSLog(@"📊 %@ panel Y-range: [%.2f - %.2f]", self.panelType, self.yRangeMin, self.yRangeMax);
    }
}

- (void)invalidateYAxis {
    [self.yAxisLayer setNeedsDisplay];
}


- (NSString *)formatValueForDisplay:(double)value {
    if ([self.panelType isEqualToString:@"volume"]) {
        return [self formatVolumeForDisplay:value];
    } else {
        return [self formatPriceForDisplay:value];
    }
}

- (NSString *)formatVolumeForDisplay:(double)volume {
    if (volume >= 1000000000) {
        // Billions
        return [NSString stringWithFormat:@"%.1fB", volume / 1000000000.0];
    } else if (volume >= 1000000) {
        // Millions
        return [NSString stringWithFormat:@"%.1fM", volume / 1000000.0];
    } else if (volume >= 1000) {
        // Thousands
        return [NSString stringWithFormat:@"%.0fK", volume / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%.0f", volume];
    }
}


- (NSString *)formatPriceForDisplay:(double)price {
    // Smart formatting: <$1 = 4 decimals, >=$1 = 2 decimals
    if (price < 1.0) {
        return [NSString stringWithFormat:@"%.4f", price];
    } else {
        return [NSString stringWithFormat:@"%.2f", price];
    }
}

- (void)drawVolumeHistogram {
    if (self.visibleStartIndex >= self.visibleEndIndex || self.visibleEndIndex > self.chartData.count) {
        return;
    }
    
    // Find max volume in visible range for scaling
    double maxVolume = 0;
    for (NSInteger i = self.visibleStartIndex; i < self.visibleEndIndex && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        maxVolume = MAX(maxVolume, bar.volume);
    }
    
    if (maxVolume == 0) return;
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    
    // 🆕 FIX: Use chart area width (excluding Y-axis)
    CGFloat chartAreaWidth = self.bounds.size.width - Y_AXIS_WIDTH - (2 * CHART_MARGIN_LEFT);
    CGFloat barWidth = chartAreaWidth / visibleBars;
    CGFloat barSpacing = MAX(1, barWidth * 0.1);
    barWidth = barWidth - barSpacing;
    
    CGFloat chartHeight = self.bounds.size.height - 20; // 10px margin top/bottom
    
    for (NSInteger i = self.visibleStartIndex; i < self.visibleEndIndex && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        
        // 🆕 FIX: Use CHART_MARGIN_LEFT instead of hardcoded 10
        CGFloat x = CHART_MARGIN_LEFT + (i - self.visibleStartIndex) * (barWidth + barSpacing);
        CGFloat height = (bar.volume / maxVolume) * chartHeight;
        CGFloat y = 10; // Start from bottom margin
        
        // Color based on price direction
        NSColor *barColor = (bar.close >= bar.open) ?
                            [NSColor systemGreenColor] : [NSColor systemRedColor];
        
        NSRect volumeRect = NSMakeRect(x, y, barWidth, height);
        [barColor setFill];
        NSBezierPath *volumePath = [NSBezierPath bezierPathWithRect:volumeRect];
        [volumePath fill];
    }
    
    NSLog(@"📊 Volume histogram drawn with chartAreaWidth: %.1f", chartAreaWidth);
}


- (void)drawChartPortionSelection {
    if (labs(self.selectionStartIndex - self.selectionEndIndex) == 0) return;
    
    NSInteger startIdx = MIN(self.selectionStartIndex, self.selectionEndIndex);
    NSInteger endIdx = MAX(self.selectionStartIndex, self.selectionEndIndex);
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    CGFloat chartAreaWidth = self.bounds.size.width - Y_AXIS_WIDTH - (2 * CHART_MARGIN_LEFT);
    CGFloat barWidth = chartAreaWidth / visibleBars;

    CGFloat startX = CHART_MARGIN_LEFT + (startIdx - self.visibleStartIndex) * barWidth;
    CGFloat endX = CHART_MARGIN_LEFT + (endIdx - self.visibleStartIndex) * barWidth;
    
    // ✅ NUOVO: Calcola variazioni per determinare i colori
    if (!self.chartData || startIdx >= self.chartData.count || endIdx >= self.chartData.count) return;
    
    HistoricalBarModel *startBar = self.chartData[startIdx];
    HistoricalBarModel *endBar = self.chartData[endIdx];
    double startValue = startBar.close;
    double endValue = endBar.close;
    double priceVariationPercent = ((endValue - startValue) / startValue) * 100.0;
    
    // Trova max e min nella selezione
    double maxValue = -DBL_MAX;
    double minValue = DBL_MAX;
    for (NSInteger i = startIdx; i <= endIdx && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        maxValue = MAX(maxValue, bar.high);
        minValue = MIN(minValue, bar.low);
    }
    
    // Coordinate Y per max e min
    CGFloat maxY = [self yCoordinateForPrice:maxValue];
    CGFloat minY = [self yCoordinateForPrice:minValue];
    
    // Variazione mouse drag
    double dragStartPrice = [self priceForYCoordinate:self.dragStartPoint.y];
    double dragEndPrice = [self priceForYCoordinate:self.crosshairPoint.y];
    double dragVariationPercent = ((dragEndPrice - dragStartPrice) / dragStartPrice) * 100.0;
    
    // ✅ NUOVO: Colori basati sulla variazione prezzo
    NSColor *selectionColor = (priceVariationPercent >= 0) ?
                              [NSColor systemGreenColor] : [NSColor systemRedColor];
    NSColor *dragColor = (dragVariationPercent >= 0) ?
                         [NSColor systemGreenColor] : [NSColor systemRedColor];
    
    // ✅ NUOVO: Draw selection background con colore dinamico
    NSRect selectionRect = NSMakeRect(startX, 0, endX - startX, self.bounds.size.height);
    [[selectionColor colorWithAlphaComponent:0.15] setFill]; // Più trasparente per essere meno invasivo
    NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRect:selectionRect];
    [selectionPath fill];
    
    // ✅ NUOVO: Draw selection borders con colore dinamico
    [selectionColor setStroke];
    NSBezierPath *startLine = [NSBezierPath bezierPath];
    [startLine moveToPoint:NSMakePoint(startX, 0)];
    [startLine lineToPoint:NSMakePoint(startX, self.bounds.size.height)];
    startLine.lineWidth = 2.0;
    [startLine stroke];
    
    NSBezierPath *endLine = [NSBezierPath bezierPath];
    [endLine moveToPoint:NSMakePoint(endX, 0)];
    [endLine lineToPoint:NSMakePoint(endX, self.bounds.size.height)];
    endLine.lineWidth = 2.0;
    [endLine stroke];
    
    // ✅ NUOVO: Linee orizzontali per MAX e MIN
    [[NSColor systemOrangeColor] setStroke];
    
    // Linea MAX
    NSBezierPath *maxLine = [NSBezierPath bezierPath];
    [maxLine moveToPoint:NSMakePoint(startX, maxY)];
    [maxLine lineToPoint:NSMakePoint(endX, maxY)];
    maxLine.lineWidth = 1.5;
    [maxLine setLineDash:(CGFloat[]){4.0, 2.0} count:2 phase:0]; // Linea tratteggiata
    [maxLine stroke];
    
    // Linea MIN
    NSBezierPath *minLine = [NSBezierPath bezierPath];
    [minLine moveToPoint:NSMakePoint(startX, minY)];
    [minLine lineToPoint:NSMakePoint(endX, minY)];
    minLine.lineWidth = 1.5;
    [minLine setLineDash:(CGFloat[]){4.0, 2.0} count:2 phase:0]; // Linea tratteggiata
    [minLine stroke];
    
    // ✅ NUOVO: Connection line con colore del drag
    NSBezierPath *connectionLine = [NSBezierPath bezierPath];
    [connectionLine moveToPoint:NSMakePoint(startX, self.dragStartPoint.y)];
    [connectionLine lineToPoint:NSMakePoint(endX, self.crosshairPoint.y)];
    connectionLine.lineWidth = 2.0;
    [dragColor setStroke];
    [connectionLine stroke];
    
    // ✅ NUOVO: Label variazione prezzo - DENTRO la selezione con bubble
    NSString *priceVariationText = [NSString stringWithFormat:@"%+.2f%%", priceVariationPercent];
    NSDictionary *priceTextAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor whiteColor] // Testo bianco per contrasto
    };
    
    NSSize priceTextSize = [priceVariationText sizeWithAttributes:priceTextAttributes];
    CGFloat priceTextY = (self.bounds.size.height / 2) - (priceTextSize.height / 2);
    CGFloat priceTextX = startX + 15; // Dentro la selezione, a destra della barra sinistra
    NSPoint priceTextPoint = NSMakePoint(priceTextX, priceTextY);
    
    // ✅ BUBBLE per il testo della variazione prezzo
    NSRect priceBubbleRect = NSMakeRect(priceTextPoint.x - 8, priceTextPoint.y - 4,
                                       priceTextSize.width + 16, priceTextSize.height + 8);
    
    // Background bubble con colore della selezione
    [selectionColor setFill];
    NSBezierPath *priceBubble = [NSBezierPath bezierPathWithRoundedRect:priceBubbleRect xRadius:8 yRadius:8];
    [priceBubble fill];
    
    // Bordo bianco per la bubble
    [[NSColor whiteColor] setStroke];
    priceBubble.lineWidth = 1.0;
    [priceBubble stroke];
    
    [priceVariationText drawAtPoint:priceTextPoint withAttributes:priceTextAttributes];
    
    // ✅ NUOVO: Label variazione drag - DENTRO la selezione con bubble
    NSString *dragVariationText = [NSString stringWithFormat:@"%+.2f%%", dragVariationPercent];
    NSDictionary *dragTextAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor whiteColor] // Testo bianco per contrasto
    };
    
    NSSize dragTextSize = [dragVariationText sizeWithAttributes:dragTextAttributes];
    
    // Posiziona DENTRO la selezione, vicino al crosshair ma spostato verso l'interno
    CGFloat dragTextX = self.crosshairPoint.x;
    CGFloat dragTextY = self.crosshairPoint.y - dragTextSize.height - 15; // Sopra il crosshair
    
    // Assicurati che sia dentro la selezione
    if (dragTextX < startX + 10) {
        dragTextX = startX + 10;
    } else if (dragTextX + dragTextSize.width + 16 > endX - 10) { // +16 per la bubble padding
        dragTextX = endX - dragTextSize.width - 26; // -26 per bubble padding
    }
    
    // Controlla limiti verticali
    if (dragTextY < 10) {
        dragTextY = self.crosshairPoint.y + 15; // Metti sotto il crosshair
    }
    
    NSPoint dragTextPoint = NSMakePoint(dragTextX, dragTextY);
    
    // ✅ BUBBLE per il testo della variazione drag
    NSRect dragBubbleRect = NSMakeRect(dragTextPoint.x - 8, dragTextPoint.y - 4,
                                      dragTextSize.width + 16, dragTextSize.height + 8);
    
    // Background bubble con colore del drag
    [dragColor setFill];
    NSBezierPath *dragBubble = [NSBezierPath bezierPathWithRoundedRect:dragBubbleRect xRadius:8 yRadius:8];
    [dragBubble fill];
    
    // Bordo bianco per la bubble
    [[NSColor whiteColor] setStroke];
    dragBubble.lineWidth = 1.0;
    [dragBubble stroke];
    
    [dragVariationText drawAtPoint:dragTextPoint withAttributes:dragTextAttributes];
    
    // Draw info box (only for security panel)
    if ([self.panelType isEqualToString:@"security"]) {
        [self drawChartPortionSelectionInfoBox:startIdx endIdx:endIdx];
    }
}

// Enhanced drawChartPortionSelectionInfoBox with mouse drag variation % and styling
// Sostituisci il metodo esistente in ChartPanelView.m

- (void)drawChartPortionSelectionInfoBox:(NSInteger)startIdx endIdx:(NSInteger)endIdx {
    if (!self.chartData || startIdx >= self.chartData.count || endIdx >= self.chartData.count) return;
    
    // Calculate statistics
    HistoricalBarModel *startBar = self.chartData[startIdx];
    HistoricalBarModel *endBar = self.chartData[endIdx];
    
    double startValue = startBar.close;
    double endValue = endBar.close;
    double maxValue = -DBL_MAX;
    double minValue = DBL_MAX;
    NSInteger barCount = endIdx - startIdx + 1;
    
    // Find min/max in selection
    for (NSInteger i = startIdx; i <= endIdx && i < self.chartData.count; i++) {
        HistoricalBarModel *bar = self.chartData[i];
        maxValue = MAX(maxValue, bar.high);
        minValue = MIN(minValue, bar.low);
    }
    
    // ✅ NUOVO: Calculate mouse drag variation %
    // Trova i prezzi ai punti di mouse start e end
    double dragStartPrice = [self priceForYCoordinate:self.dragStartPoint.y];
    double dragEndPrice = [self priceForYCoordinate:self.crosshairPoint.y];
    double dragVariationPercent = ((dragEndPrice - dragStartPrice) / dragStartPrice) * 100.0;
    
    // Calculate other percentages
    double varPercentStartEnd = ((endValue - startValue) / startValue) * 100.0;
    double varPercentMaxMin = ((maxValue - minValue) / minValue) * 100.0;
    
    // Format dates
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterNoStyle;
    
    NSString *startDate = [dateFormatter stringFromDate:startBar.date];
    NSString *endDate = [dateFormatter stringFromDate:endBar.date];
    
    // ✅ NUOVO: Create styled info text with enhanced formatting
    NSArray *infoLines = @[
        [NSString stringWithFormat:@"📊 SELECTION STATS"],
        @"",
        [NSString stringWithFormat:@"Start: %@ (%.2f)", startDate, startValue],
        [NSString stringWithFormat:@"End: %@ (%.2f)", endDate, endValue],
        [NSString stringWithFormat:@"Max: %.2f  •  Min: %.2f", maxValue, minValue],
        @"",
        [NSString stringWithFormat:@"📏 Bars: %ld", (long)barCount],
        @"",
        [NSString stringWithFormat:@"🎯 Mouse Drag: %+.2f%%", dragVariationPercent],
        [NSString stringWithFormat:@"📈 Price Change: %+.2f%%", varPercentStartEnd],
        [NSString stringWithFormat:@"📊 Range: %.2f%%", varPercentMaxMin]
    ];
    
    // ✅ NUOVO: Enhanced text attributes with different styles
    NSDictionary *headerAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };
    
    NSDictionary *normalAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    NSDictionary *boldAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };
    
    // ✅ NUOVO: Color attributes for positive/negative values
    NSColor *positiveColor = [NSColor systemGreenColor];
    NSColor *negativeColor = [NSColor systemRedColor];
    NSColor *neutralColor = [NSColor labelColor];
    
    NSDictionary *positiveAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: positiveColor
    };
    
    NSDictionary *negativeAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: negativeColor
    };
    
    // Calculate box size
    CGFloat maxWidth = 0;
    CGFloat totalHeight = 0;
    CGFloat lineHeight = 16; // Increased for better readability
    
    for (NSString *line in infoLines) {
        if (line.length > 0) {
            NSSize lineSize = [line sizeWithAttributes:normalAttributes];
            maxWidth = MAX(maxWidth, lineSize.width);
        }
        totalHeight += lineHeight;
    }
    
    // Box dimensions with padding
    CGFloat padding = 12;
    CGFloat boxWidth = maxWidth + (padding * 2);
    CGFloat boxHeight = totalHeight + (padding * 2);
    
    // ✅ NUOVO: Position box intelligently (avoid chart edges)
    CGFloat chartAreaWidth = self.bounds.size.width - Y_AXIS_WIDTH;
    CGFloat boxX = 20; // Fixed left position
    CGFloat boxY = self.bounds.size.height - boxHeight - 20; // Fixed top position
    
   
    
    NSRect boxRect = NSMakeRect(boxX, boxY, boxWidth, boxHeight);
    
    // ✅ NUOVO: Enhanced box background with shadow effect
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    // Shadow
    CGContextSetShadowWithColor(ctx, CGSizeMake(2, -2), 4,
                               [[NSColor blackColor] colorWithAlphaComponent:0.3].CGColor);
    
    // Background with rounded corners
    NSBezierPath *backgroundPath = [NSBezierPath bezierPathWithRoundedRect:boxRect
                                                                   xRadius:8
                                                                   yRadius:8];
    [[NSColor controlBackgroundColor] setFill];
    [backgroundPath fill];
    
    // Border
    [[NSColor separatorColor] setStroke];
    backgroundPath.lineWidth = 1.0;
    [backgroundPath stroke];
    
    CGContextRestoreGState(ctx);
    
    // ✅ NUOVO: Draw enhanced text with smart styling
    CGFloat yPosition = boxY + boxHeight - padding - 12;
    
    for (NSInteger i = 0; i < infoLines.count; i++) {
        NSString *line = infoLines[i];
        
        if (line.length == 0) {
            yPosition -= lineHeight / 2; // Half space for empty lines
            continue;
        }
        
        NSDictionary *attributes = normalAttributes;
        
        // ✅ NUOVO: Smart text styling based on content
        if ([line containsString:@"📊 SELECTION STATS"]) {
            attributes = headerAttributes;
        } else if ([line containsString:@"📏 Bars:"]) {
            attributes = boldAttributes;
        } else if ([line containsString:@"🎯 Mouse Drag:"]) {
            // Color based on drag variation
            if (dragVariationPercent > 0) {
                attributes = positiveAttributes;
            } else if (dragVariationPercent < 0) {
                attributes = negativeAttributes;
            } else {
                attributes = boldAttributes;
            }
        } else if ([line containsString:@"📈 Price Change:"]) {
            // Color based on price change
            if (varPercentStartEnd > 0) {
                attributes = positiveAttributes;
            } else if (varPercentStartEnd < 0) {
                attributes = negativeAttributes;
            } else {
                attributes = boldAttributes;
            }
        } else if ([line containsString:@"📊 Range:"]) {
            attributes = boldAttributes;
        }
        
        NSPoint textPoint = NSMakePoint(boxX + padding, yPosition);
        [line drawAtPoint:textPoint withAttributes:attributes];
        
        yPosition -= lineHeight;
    }
    
    NSLog(@"📊 Enhanced selection info: Bars=%ld, Drag=%.2f%%, Price=%.2f%%",
          (long)barCount, dragVariationPercent, varPercentStartEnd);
}

- (void)drawCrosshair {
    // This method is now unused - drawing moved to drawCrosshairContent
    // Kept for compatibility but all crosshair drawing happens in layers
}

- (void)drawPriceLabel:(NSString *)priceText atPoint:(NSPoint)point {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor controlBackgroundColor],
        NSBackgroundColorAttributeName: [NSColor labelColor]
    };
    
    NSSize textSize = [priceText sizeWithAttributes:attributes];
    NSRect backgroundRect = NSMakeRect(point.x - 5, point.y - textSize.height/2 - 2,
                                      textSize.width + 10, textSize.height + 4);
    
    // Draw background
    [[NSColor labelColor] setFill];
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:backgroundRect xRadius:3 yRadius:3];
    [bgPath fill];
    
    // Draw text
    NSPoint textPoint = NSMakePoint(point.x, point.y - textSize.height/2);
    [priceText drawAtPoint:textPoint withAttributes:attributes];
}

#pragma mark - Coordinate Conversion


- (CGFloat)yCoordinateForPrice:(double)price {
    if (self.objectRenderer && self.objectRenderer.coordinateContext) {
        return [self.objectRenderer.coordinateContext screenYForValue:price];
    }
    
    if (self.yRangeMax == self.yRangeMin) return self.bounds.size.height / 2;
    
    double normalizedPrice = (price - self.yRangeMin) / (self.yRangeMax - self.yRangeMin);
    return CHART_MARGIN_LEFT + normalizedPrice * (self.bounds.size.height - 20);
}

- (CGFloat)yCoordinateForValue:(double)value {
    if (self.yRangeMax == self.yRangeMin) return self.bounds.size.height / 2;
    
    double normalizedValue = (value - self.yRangeMin) / (self.yRangeMax - self.yRangeMin);
    return CHART_MARGIN_LEFT + normalizedValue * (self.bounds.size.height - 20);
}

- (double)valueForYCoordinate:(CGFloat)y {
    if (self.bounds.size.height <= 20) return self.yRangeMin;
    
    double normalizedY = (y - CHART_MARGIN_LEFT) / (self.bounds.size.height - 20);
    return self.yRangeMin + normalizedY * (self.yRangeMax - self.yRangeMin);
}

- (double)priceForYCoordinate:(CGFloat)y {
    if (self.objectRenderer && self.objectRenderer.coordinateContext) {
        return [self.objectRenderer.coordinateContext priceFromScreenY:y];
    }
    
    if (self.bounds.size.height <= 20) return self.yRangeMin;
    
    double normalizedY = (y - CHART_MARGIN_LEFT) / (self.bounds.size.height - 20);
    return self.yRangeMin + normalizedY * (self.yRangeMax - self.yRangeMin);
}

- (NSInteger)barIndexForXCoordinate:(CGFloat)x {
    if (self.visibleStartIndex >= self.visibleEndIndex) return -1;
    
    NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex;
    // Use chart area width (excluding Y-axis)
    CGFloat chartAreaWidth = self.bounds.size.width - Y_AXIS_WIDTH - (2 * CHART_MARGIN_LEFT);
    CGFloat barWidth = chartAreaWidth / visibleBars;
    
    NSInteger relativeIndex = (x - CHART_MARGIN_LEFT) / barWidth;
    NSInteger absoluteIndex = self.visibleStartIndex + relativeIndex;
    
    return MAX(self.visibleStartIndex, MIN(absoluteIndex, self.visibleEndIndex - 1));
}


#pragma mark - Mouse Events

- (void)mouseEntered:(NSEvent *)event {
    self.crosshairVisible = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    self.crosshairVisible = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    // 🆕 FIX: Clamp crosshair position to chart area
    NSPoint clampedPoint = [self clampCrosshairToChartArea:locationInView];
    self.crosshairPoint = clampedPoint;
    
    [self.crosshairLayer setNeedsDisplay];
    
    // PRIORITA' 1: Se abbiamo currentCPSelected, aggiorna sempre le coordinate
    if (self.objectRenderer && self.objectRenderer.currentCPSelected) {
        [self.objectRenderer updateCurrentCPCoordinates:clampedPoint]; // Use clamped
        return;
    }
    
    // Update crosshair during object editing
    if (self.objectRenderer && self.objectRenderer.editingObject) {
        [self.objectRenderer updateEditingHoverAtPoint:clampedPoint]; // Use clamped
        
        // Sync crosshair anche durante editing (sync X, keep individual Y)
        for (ChartPanelView *panel in self.chartWidget.chartPanels) {
            if (panel != self) {
                NSPoint syncPoint = NSMakePoint(clampedPoint.x, panel.crosshairPoint.y);
                [panel setCrosshairPoint:syncPoint visible:YES];
            }
        }
        return;
    }
    
    // Normal crosshair sync (sync X across panels, keep individual Y)
    for (ChartPanelView *panel in self.chartWidget.chartPanels) {
        if (panel != self) {
            NSPoint syncPoint = NSMakePoint(clampedPoint.x, panel.crosshairPoint.y);
            [panel setCrosshairPoint:syncPoint visible:YES];
        }
    }
}



- (void)mouseDown:(NSEvent *)event {
    if (self.objectRenderer.currentCPSelected) {
        return;
    }
    
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    NSPoint clampedPoint = [self clampCrosshairToChartArea:locationInView]; // 🆕 FIX
    
    self.dragStartPoint = clampedPoint; // Use clamped
    self.isDragging = NO;
    
    // Alert hit testing
    if (self.alertRenderer) {
        AlertModel *hitAlert = [self.alertRenderer alertAtScreenPoint:clampedPoint tolerance:12.0];
        if (hitAlert) {
            [self.alertRenderer startDraggingAlert:hitAlert atPoint:clampedPoint];
            self.isInAlertDragMode = YES;
            NSLog(@"🚨 Started dragging alert %@ %.2f", hitAlert.symbol, hitAlert.triggerValue);
            return;
        }
    }
    
    // NEW LOGIC: Check if ObjectsPanel has active object type
    ChartObjectType activeType = -1;
    if (self.chartWidget && self.chartWidget.objectsPanel) {
        activeType = [self.chartWidget.objectsPanel getActiveObjectType];
        NSLog(@"🔍 Active object type: %ld", (long)activeType);
    }
    
    if (activeType != -1) {
        // CREATION MODE: Start creating object
        NSLog(@"🎯 Starting object creation for type %ld", (long)activeType);
        
        if (!self.objectRenderer) {
            [self setupObjectsRendererWithManager:self.chartWidget.objectsManager];
        }
        
        [self.objectRenderer startCreatingObjectOfType:activeType];
        [self.objectRenderer addControlPointAtScreenPoint:locationInView];
        
        return; // Don't handle other interactions during creation
    }
    
  
    
    // Original chart interaction behavior (zoom, pan, selection)
    self.isMouseDown = YES;
    self.lastMousePoint = locationInView;
}


- (void)mouseDragged:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    // Calculate drag distance
    CGFloat dragDistance = sqrt(pow(locationInView.x - self.dragStartPoint.x, 2) +
                               pow(locationInView.y - self.dragStartPoint.y, 2));
    
    if (dragDistance > self.dragThreshold) {
        self.isDragging = YES;
    }
    
    
    // PRIORITA' 1: Se abbiamo currentCPSelected, aggiorna coordinate
    if (self.objectRenderer && self.objectRenderer.currentCPSelected) {
        [self.objectRenderer updateCurrentCPCoordinates:locationInView];
        
        // Se in preview mode E stiamo draggando, aggiorna anche preview
        if (self.isDragging) {
            [self.objectRenderer updateCreationPreviewAtPoint:locationInView];
        }
        
        NSLog(@"🎯 MouseDragged: Updated currentCPSelected coordinates");
        return;
    }
    
    if (self.isInAlertDragMode && self.alertRenderer.isInAlertDragMode) {
           [self.alertRenderer updateDragToPoint:locationInView];
           return;
       }

    // Original drag behavior for chart (pan, selection, etc.)
    if (self.isMouseDown) {
        // Handle chart pan/selection as before
        
        if (self.isDragging) {
            // Chart selection mode
            self.isInChartPortionSelectionMode = YES;
            self.selectionStartIndex = [self barIndexForXCoordinate:self.dragStartPoint.x];
            self.selectionEndIndex = [self barIndexForXCoordinate:locationInView.x];
            
            [self.chartPortionSelectionLayer setNeedsDisplay];
        }
    }
    self.crosshairPoint = locationInView;
    [self.crosshairLayer setNeedsDisplay];
}

- (void)rightMouseDragged:(NSEvent *)event {
    if (!self.isRightMouseDown) return;
    
    NSPoint currentPoint = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat deltaX = currentPoint.x - self.lastMousePoint.x;
    CGFloat deltaY = currentPoint.y - self.lastMousePoint.y;
    
    // Right drag = pan mode
    [self handlePanWithDeltaX:deltaX deltaY:deltaY];
    
    self.lastMousePoint = currentPoint;
}



- (void)mouseUp:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    
    // PRIORITA' 1: Se abbiamo currentCPSelected, consolidalo
    if (self.objectRenderer && self.objectRenderer.currentCPSelected) {
        NSLog(@"🎯 MouseUp: Consolidating currentCPSelected");
        
        if (self.objectRenderer.isInCreationMode) {
            // Modalità creazione - consolida CP e prepara il prossimo
            [self.objectRenderer consolidateCurrentCPAndPrepareNext];
        } else {
            // Modalità editing - termina editing
            self.objectRenderer.currentCPSelected = nil;
            NSLog(@"🎯 MouseUp: Cleared currentCPSelected after editing");
        }
        
        self.isDragging = NO;
        return;
    }
    
    if (self.isInAlertDragMode && self.alertRenderer.isInAlertDragMode) {
         [self.alertRenderer finishDragWithConfirmation];
         self.isInAlertDragMode = NO;
         self.isDragging = NO;
         NSLog(@"🚨 Completed alert drag");
         return;
     }
    
    // If it was a click (not drag), handle object selection
    if (!self.isDragging && self.objectRenderer) {
        // Hit test for existing objects
        ChartObjectModel *objectAtPoint = [self.objectRenderer objectAtScreenPoint:locationInView
                                                                           tolerance:15.0];
        if (objectAtPoint) {
            // Object found - start editing
            [self.objectRenderer startEditingObject:objectAtPoint];
            
            // Select nearest control point
            ControlPointModel *nearestCP = [objectAtPoint controlPointNearPoint:locationInView tolerance:15.0];
            if (nearestCP) {
                [self.objectRenderer selectControlPointForEditing:nearestCP];
                NSLog(@"🎯 Selected object and nearest CP for editing");
            }
            
            self.isDragging = NO;
            return;
        }
        
        // No object found - clear any editing
        if (self.objectRenderer.editingObject) {
            [self.objectRenderer stopEditing];
            NSLog(@"✋ Stopped editing - clicked on empty space");
        }
    }
    
    // Original mouseUp behavior for chart
    if (self.isInChartPortionSelectionMode && self.isDragging) {
        // Zoom to selection
        NSInteger startIdx = MIN(self.selectionStartIndex, self.selectionEndIndex);
        NSInteger endIdx = MAX(self.selectionStartIndex, self.selectionEndIndex);
        
        if (endIdx > startIdx) {
            [self.chartWidget zoomToRange:startIdx endIndex:endIdx];
        }
    }
    
    // Reset states
    self.isMouseDown = NO;
    self.isDragging = NO;
    self.isInChartPortionSelectionMode = NO;
    [self.chartPortionSelectionLayer setNeedsDisplay];
}


- (void)rightMouseUp:(NSEvent *)event {
    self.isRightMouseDown = NO;
}


- (void)scrollWheel:(NSEvent *)event {
    if (!self.chartData || self.chartData.count == 0) return;
    
    // ✅ NUOVO: Usa l'endIndex corrente come punto fisso invece del mouse
    NSInteger fixedEndIndex = self.chartWidget.visibleEndIndex;
    NSInteger currentRange = self.chartWidget.visibleEndIndex - self.chartWidget.visibleStartIndex;
    NSInteger newRange;
    
    if (event.deltaY > 0) {
        // Zoom in - dimezza il range
        newRange = MAX(10, currentRange / 2);
    } else {
        // Zoom out - raddoppia il range
        newRange = MIN(self.chartData.count, currentRange * 2);
    }
    
    // Calcola nuovo startIndex mantenendo endIndex fisso
    NSInteger newStartIndex = fixedEndIndex - newRange;
    
    // Clamp ai limiti validi (solo per startIndex)
    if (newStartIndex < 0) {
        newStartIndex = 0;
    }
    
    // Applica zoom
    [self.chartWidget zoomToRange:newStartIndex endIndex:fixedEndIndex];
    
    NSLog(@"🔍🖱 Scroll zoom: fixed end at %ld, new range [%ld-%ld] (pan slider stays same)",
          (long)fixedEndIndex, (long)newStartIndex, (long)fixedEndIndex);
}

- (void)rightMouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
    // 🎯 PRIORITÀ 1: CONTEXT MENU PER OGGETTI (NUOVA FUNZIONALITÀ)
    if (self.objectRenderer && self.objectRenderer.objectsManager) {
        // Hit test per trovare oggetto sotto il cursore
        ChartObjectModel *hitObject = [self.objectRenderer objectAtScreenPoint:locationInView tolerance:15.0];
        
        // Se non trova oggetto normale, controlla se c'è un oggetto in editing
        if (!hitObject && self.objectRenderer.editingObject) {
            // Verifica se il right-click è sull'oggetto in editing
            if ([self isPoint:locationInView nearEditingObject:self.objectRenderer.editingObject tolerance:15.0]) {
                hitObject = self.objectRenderer.editingObject;
            }
        }
        
        // Se non trova ancora oggetto, controlla control point
        if (!hitObject) {
            ControlPointModel *hitCP = [self.objectRenderer.objectsManager controlPointAtPoint:locationInView tolerance:8.0];
            if (hitCP) {
                hitObject = [self findObjectOwningControlPoint:hitCP];
            }
        }
        if (self.objectRenderer.editingObject) {
              NSLog(@"⚠️ Clearing editing state before context menu");
              self.objectRenderer.editingObject = nil;
              self.objectRenderer.currentCPSelected = nil;
              [self.objectRenderer invalidateEditingLayer];
          }
        if (hitObject) {
            NSLog(@"🖱️ ChartPanelView: Right-click on object '%@' - showing context menu", hitObject.name);
            [self showContextMenuForObject:hitObject atPoint:locationInView withEvent:event];
            return; // Stop all other processing for object context menu
        }
    }
    
    // RESTO DEL CODICE ORIGINALE (PRIORITÀ 2, 3, 4...)
    
    // PRIORITY 2: Cancel object creation if active
    if (self.objectRenderer && self.objectRenderer.isInCreationMode) {
        [self.objectRenderer cancelCreatingObject];
        self.isInObjectCreationMode = NO;
        NSLog(@"❌ ChartPanelView: Cancelled object creation via right-click");
        return;
    }
   
    // PRIORITY 3: Delete editing object if active
    if (self.objectRenderer && self.objectRenderer.editingObject) {
        ChartObjectModel *objectToDelete = self.objectRenderer.editingObject;
        [self.objectRenderer stopEditing];
        [self.objectRenderer.objectsManager deleteObject:objectToDelete];
        [self.objectRenderer renderAllObjects];
        self.isInObjectEditingMode = NO;
        NSLog(@"🗑️ ChartPanelView: Deleted object via right-click");
        return;
    }
    
    // 🆕 PRIORITÀ 2: CONTEXT MENU PER ALERT (NUOVO)
     if (self.alertRenderer) {
         AlertModel *hitAlert = [self.alertRenderer alertAtScreenPoint:locationInView tolerance:15.0];
         if (hitAlert) {
             NSLog(@"🚨 ChartPanelView: Right-click on alert %@ %.2f - showing context menu",
                   hitAlert.symbol, hitAlert.triggerValue);
             [self showContextMenuForAlert:hitAlert atPoint:locationInView withEvent:event];
             return; // Stop processing for alert context menu
         }
     }
     
     // 🆕 PRIORITÀ 3: MENU GENERICO PER CREARE NUOVO ALERT (NUOVO)
     [self showGeneralContextMenuAtPoint:locationInView withEvent:event];
    
    
    // PRIORITY 5: Original right-click behavior (pan mode)
    self.isRightMouseDown = YES;
    self.dragStartPoint = locationInView;
    self.lastMousePoint = self.dragStartPoint;
}


- (void)showContextMenuForObject:(ChartObjectModel *)object atPoint:(NSPoint)point {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Object Actions"];
    
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit Object"
                                                      action:@selector(editSelectedObject:)
                                               keyEquivalent:@""];
    editItem.target = self;
    editItem.representedObject = object;
    [contextMenu addItem:editItem];
    
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Object"
                                                        action:@selector(deleteSelectedObject:)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    deleteItem.representedObject = object;
    [contextMenu addItem:deleteItem];
    
    [NSMenu popUpContextMenu:contextMenu withEvent:[NSApp currentEvent] forView:self];
}

- (void)editSelectedObject:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    if (object && self.objectRenderer) {
        [self.objectRenderer startEditingObject:object];
        self.isInObjectEditingMode = YES;
    }
}

- (void)deleteSelectedObject:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    if (object && self.objectRenderer) {
        [self.objectRenderer.objectsManager deleteObject:object];
        [self.objectRenderer renderAllObjects];
    }
}



#pragma mark - Key Events (NEW)
/*
// ADD keyboard shortcuts for object creation:
- (void)keyDown:(NSEvent *)event {
    NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
    
    if ([characters isEqualToString:@"h"]) {
        // H key - Horizontal Line
        [self startCreatingObjectOfType:ChartObjectTypeHorizontalLine];
    } else if ([characters isEqualToString:@"t"]) {
        // T key - Trendline
        [self startCreatingObjectOfType:ChartObjectTypeTrendline];
    } else if ([characters isEqualToString:@"f"]) {
        // F key - Fibonacci
        [self startCreatingObjectOfType:ChartObjectTypeFibonacci];
    } else if ([characters isEqualToString:@"r"]) {
        // R key - Rectangle
        [self startCreatingObjectOfType:ChartObjectTypeRectangle];
    } else if (event.keyCode == 53) { // ESC key
        // Cancel current operation
        if (self.isInObjectCreationMode && self.objectRenderer) {
            [self.objectRenderer cancelCreatingObject];
            self.isInObjectCreationMode = NO;
        } else if (self.isInObjectEditingMode) {
            [self stopEditingObject];
        }
    } else {
        [super keyDown:event];
    }
}
*/
// ENSURE view can receive key events:
- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)canBecomeKeyView {
    return YES;
}



#pragma mark - Pan Handling


- (void)handlePanWithDeltaX:(CGFloat)deltaX deltaY:(CGFloat)deltaY {
    // Horizontal pan
    if (fabs(deltaX) > 1) {
        NSInteger visibleBars = self.chartWidget.visibleEndIndex - self.chartWidget.visibleStartIndex;
        CGFloat barWidth = (self.bounds.size.width - 20) / visibleBars;
        NSInteger barDelta = -deltaX / barWidth; // Negative for natural scrolling
        
        NSInteger newStartIndex = self.chartWidget.visibleStartIndex + barDelta;
        NSInteger newEndIndex = self.chartWidget.visibleEndIndex + barDelta;
        
        // Clamp to valid range
        if (newStartIndex < 0) {
            newStartIndex = 0;
            newEndIndex = visibleBars;
        } else if (newEndIndex >= self.chartData.count) {
            newEndIndex = self.chartData.count - 1;
            newStartIndex = newEndIndex - visibleBars;
        }
        
        [self.chartWidget zoomToRange:newStartIndex endIndex:newEndIndex];
    }
    
    // Vertical pan (only for security panel, adjusts Y range temporarily)
    if (fabs(deltaY) > 1 && [self.panelType isEqualToString:@"security"]) {
        double yRange = self.yRangeMax - self.yRangeMin;
        double yDelta = (deltaY / self.bounds.size.height) * yRange;
        
        // Override Y range temporarily
        self.chartWidget.yRangeMin -= yDelta;
        self.chartWidget.yRangeMax -= yDelta;
        self.chartWidget.isYRangeOverridden = YES;
        
        [self.chartWidget synchronizePanels];
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
}


#pragma mark - Objects Renderer Setup

- (void)setupObjectsRendererWithManager:(ChartObjectsManager *)objectsManager {
    if (!objectsManager) {
        NSLog(@"⚠️ ChartPanelView: Cannot setup objects renderer without manager");
        return;
    }
    
    self.objectRenderer = [[ChartObjectRenderer alloc] initWithPanelView:self
                                                          objectsManager:objectsManager];
    
    // CRITICO: Initialize coordinate context with current data if available
    if (self.chartData) {
        [self.objectRenderer updateCoordinateContext:self.chartData
                                          startIndex:self.visibleStartIndex
                                            endIndex:self.visibleEndIndex
                                           yRangeMin:self.yRangeMin
                                           yRangeMax:self.yRangeMax
                                              bounds:self.bounds];
        NSLog(@"🎨 ChartObjectRenderer initialized with existing data (%lu bars)", (unsigned long)self.chartData.count);
    }
}

#pragma mark - Objects Interaction (NEW)


- (void)startCreatingObjectOfType:(ChartObjectType)objectType {
    self.isInObjectCreationMode = YES;
    self.currentCreationObjectType = objectType;
    
    if (self.objectRenderer) {
        [self.objectRenderer startCreatingObjectOfType:objectType];
    }
    
    // Make sure this panel becomes key view to receive mouse events
    [[self window] makeFirstResponder:self];
    
    NSLog(@"🎯 ChartPanelView (%@): Started creating object type %ld - ZOOM/PAN DISABLED",
          self.panelType, (long)objectType);
}

- (void)startEditingObjectAtPoint:(NSPoint)point {
    if (!self.objectRenderer) return;
    
    ChartObjectModel *objectAtPoint = [self.objectRenderer objectAtScreenPoint:point tolerance:10.0];
    if (objectAtPoint) {
        self.isInObjectEditingMode = YES;
        [self.objectRenderer startEditingObject:objectAtPoint];
        
        NSLog(@"✏️ ChartPanelView (%@): Started editing object %@",
              self.panelType, objectAtPoint.name);
    }
}

- (void)stopEditingObject {
    if (!self.isInObjectEditingMode) return;
    
    self.isInObjectEditingMode = NO;
    
    if (self.objectRenderer) {
        [self.objectRenderer stopEditing];
    }
    
    NSLog(@"✅ ChartPanelView (%@): Stopped editing object", self.panelType);
}

#pragma mark - Public Interface Updates

// ADD method to check if panel has objects capability:
- (BOOL)supportsObjects {
    return self.objectRenderer != nil;
}

// ADD method to get objects at point (for external queries):
- (NSArray<ChartObjectModel *> *)objectsAtPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    if (!self.objectRenderer) return @[];
    
    NSMutableArray *objectsAtPoint = [NSMutableArray array];
    
    for (ChartLayerModel *layer in self.objectRenderer.objectsManager.layers) {
        if (!layer.isVisible) continue;
        
        for (ChartObjectModel *object in layer.objects) {
            if (!object.isVisible) continue;
            
            // This is a simplified check - the renderer has more sophisticated hit testing
            if ([self.objectRenderer isPoint:point withinObject:object tolerance:tolerance]) {
                [objectsAtPoint addObject:object];
            }
        }
    }
    
    return [objectsAtPoint copy];
}

#pragma mark - Right-Click Context Menu Integration



// Context menu display
- (void)showContextMenuForObject:(ChartObjectModel *)object atPoint:(NSPoint)point withEvent:(NSEvent *)event {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Object Actions"];
    
    // Edit Object menu item
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Edit '%@'...", object.name]
                                                      action:@selector(editObjectFromContextMenu:)
                                               keyEquivalent:@""];
    editItem.target = self;
    editItem.representedObject = object;
    [contextMenu addItem:editItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Duplicate Object menu item
    NSMenuItem *duplicateItem = [[NSMenuItem alloc] initWithTitle:@"Duplicate Object"
                                                           action:@selector(duplicateObjectFromContextMenu:)
                                                    keyEquivalent:@""];
    duplicateItem.target = self;
    duplicateItem.representedObject = object;
    [contextMenu addItem:duplicateItem];
    
    // Delete Object menu item
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Object"
                                                        action:@selector(deleteObjectFromContextMenu:)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    deleteItem.representedObject = object;
    [contextMenu addItem:deleteItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Layer options
    NSMenuItem *layerItem = [[NSMenuItem alloc] initWithTitle:@"Move to Layer"
                                                       action:nil
                                                keyEquivalent:@""];
    NSMenu *layerSubmenu = [[NSMenu alloc] initWithTitle:@"Layer"];
    
    // Add layer options dynamically
    for (ChartLayerModel *layer in self.objectRenderer.objectsManager.layers) {
        NSMenuItem *layerOption = [[NSMenuItem alloc] initWithTitle:layer.name
                                                             action:@selector(moveObjectToLayerFromContextMenu:)
                                                      keyEquivalent:@""];
        layerOption.target = self;
        layerOption.representedObject = @{@"object": object, @"layer": layer};
        [layerSubmenu addItem:layerOption];
    }
    
    layerItem.submenu = layerSubmenu;
    [contextMenu addItem:layerItem];
    
    // Show the context menu
    [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self];
    
    NSLog(@"🎯 ChartPanelView: Context menu displayed for object '%@'", object.name);
}

// Context menu actions
- (void)editObjectFromContextMenu:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    NSLog(@"⚙️ ChartPanelView: Opening settings for object '%@' from context menu", object.name);
    [self openObjectSettingsForObject:object];
}

- (void)duplicateObjectFromContextMenu:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    NSLog(@"📋 ChartPanelView: Duplicating object '%@'", object.name);
    
    // Find current layer
    ChartLayerModel *currentLayer = nil;
    for (ChartLayerModel *layer in self.objectRenderer.objectsManager.layers) {
        if ([layer.objects containsObject:object]) {
            currentLayer = layer;
            break;
        }
    }
    
    if (currentLayer) {
        // Create duplicate
        ChartObjectModel *duplicate = [object copy];
        duplicate.name = [NSString stringWithFormat:@"%@ Copy", object.name];
        
        // Offset position slightly
        for (ControlPointModel *cp in duplicate.controlPoints) {
            cp.dateAnchor = [cp.dateAnchor dateByAddingTimeInterval:86400]; // +1 day
            cp.absoluteValue *= 1.02; // +2%
        }
        
        [currentLayer addObject:duplicate];
        [self.objectRenderer.objectsManager saveToDataHub];
        [self.objectRenderer renderAllObjects];
        
        NSLog(@"✅ ChartPanelView: Object duplicated successfully");
    }
}

- (void)deleteObjectFromContextMenu:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    NSLog(@"🗑️ ChartPanelView: Deleting object '%@' from context menu", object.name);
    
    [self.objectRenderer.objectsManager deleteObject:object];
    [self.objectRenderer renderAllObjects];
}

- (void)moveObjectToLayerFromContextMenu:(NSMenuItem *)menuItem {
    NSDictionary *info = menuItem.representedObject;
    ChartObjectModel *object = info[@"object"];
    ChartLayerModel *targetLayer = info[@"layer"];
    
    NSLog(@"📁 ChartPanelView: Moving object '%@' to layer '%@'", object.name, targetLayer.name);
    
    [self.objectRenderer.objectsManager moveObject:object toLayer:targetLayer];
    [self.objectRenderer renderAllObjects];
}

// Object settings window

- (void)openObjectSettingsForObject:(ChartObjectModel *)object {
   
    
    
    // Validate object before proceeding
    if (!object || !object.style) {
        NSLog(@"❌ ChartPanelView: Invalid object or object.style is nil");
        return;
    }
    
    if (!self.objectRenderer || !self.objectRenderer.objectsManager) {
        NSLog(@"❌ ChartPanelView: ObjectRenderer or ObjectsManager is nil");
        return;
    }
    self.objectSettingsWindow = nil;
    self.objectSettingsWindow = [[ChartObjectSettingsWindow alloc]
           initWithObject:object objectsManager:self.objectRenderer.objectsManager];
    
    
    self.objectSettingsWindow.onApplyCallback = ^(ChartObjectModel *object) {
        self.objectSettingsWindow = nil; // Rilascia reference
    };
    
    
    if (!self.objectSettingsWindow) {
        NSLog(@"❌ ChartPanelView: Failed to create settings window");
        return;
    }
    
    // ✅ SAFE CALLBACK: Use weak references to avoid retain cycles
    __weak typeof(self) weakSelf = self;
    __weak typeof(self.objectSettingsWindow) weakWindow = self.objectSettingsWindow;
    
    self.objectSettingsWindow.onApplyCallback = ^(ChartObjectModel *updatedObject) {
        // Use strong references inside block
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong typeof(weakWindow) strongWindow = weakWindow;
        
        if (!strongSelf) {
            NSLog(@"⚠️ ChartPanelView callback: ChartPanelView was deallocated");
            return;
        }
        
        // Validate objects still exist
        if (!updatedObject) {
            NSLog(@"⚠️ ChartPanelView callback: updatedObject is nil");
            return;
        }
        
        if (!strongSelf.objectRenderer) {
            NSLog(@"⚠️ ChartPanelView callback: ObjectRenderer was deallocated");
            return;
        }
        
        // Safe redraw
        @try {
            [strongSelf handleObjectSettingsApplied:updatedObject];
        } @catch (NSException *exception) {
            NSLog(@"❌ ChartPanelView callback: Exception in handleObjectSettingsApplied: %@", exception.reason);
        }
        
        // Clear callback to break retain cycle
        if (strongWindow) {
            strongWindow.onApplyCallback = nil;
        }
    };
    
    // Position and show
    [self.objectSettingsWindow makeKeyAndOrderFront:nil];
    
    NSLog(@"✅ ChartPanelView: Settings window opened successfully");
}


// AGGIUNGERE questo metodo di callback:
- (void)handleObjectSettingsApplied:(ChartObjectModel *)object {
    NSLog(@"🔄 ChartPanelView: Settings applied for object '%@' - triggering redraw", object.name ?: @"unknown");
    
    @try {
        // Validate object renderer exists
        if (!self.objectRenderer) {
            NSLog(@"❌ ChartPanelView: ObjectRenderer is nil, cannot redraw");
            return;
        }
        
        // Re-render all objects with new settings
        [self.objectRenderer renderAllObjects];
        NSLog(@"✅ ChartPanelView: Objects re-rendered successfully");
        
        // Notify chart widget if needed (optional)
        if (self.chartWidget && [self.chartWidget respondsToSelector:@selector(objectSettingsDidChange:)]) {
            [(id)self.chartWidget performSelector:@selector(objectSettingsDidChange:) withObject:object];
        }
        
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartPanelView: Exception in handleObjectSettingsApplied: %@", exception.reason);
    }
}

// Helper methods
- (BOOL)isPoint:(NSPoint)point nearEditingObject:(ChartObjectModel *)object tolerance:(CGFloat)tolerance {
    // Simple bounding box check for editing object
    // TODO: Implement proper hit testing for editing objects
    return YES; // For now, assume always true if we have an editing object
}

- (ChartObjectModel *)findObjectOwningControlPoint:(ControlPointModel *)controlPoint {
    // Search through all layers and objects to find the one containing this control point
    for (ChartLayerModel *layer in self.objectRenderer.objectsManager.layers) {
        for (ChartObjectModel *object in layer.objects) {
            if ([object.controlPoints containsObject:controlPoint]) {
                return object;
            }
        }
    }
    return nil;
}

#pragma mark - Alert Renderer Setup

- (void)setupAlertRenderer {
    self.alertRenderer = [[ChartAlertRenderer alloc] initWithPanelView:self];
    
    // CRITICO: Initialize coordinate context with current data if available
    if (self.chartData && self.chartWidget.currentSymbol) {
        [self.alertRenderer updateCoordinateContext:self.chartData
                                         startIndex:self.visibleStartIndex
                                           endIndex:self.visibleEndIndex
                                          yRangeMin:self.yRangeMin
                                          yRangeMax:self.yRangeMax
                                             bounds:self.bounds
                                      currentSymbol:self.chartWidget.currentSymbol];
        NSLog(@"🚨 ChartAlertRenderer initialized with existing data (%lu bars) for %@",
              (unsigned long)self.chartData.count, self.chartWidget.currentSymbol);
    }
    
    NSLog(@"🚨 ChartPanelView (%@): Alert renderer setup completed", self.panelType);
}
#pragma mark - showGeneralContextMenuAtPoint - MODIFICA ESISTENTE

- (void)showGeneralContextMenuAtPoint:(NSPoint)point withEvent:(NSEvent *)event {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Chart Context Menu"];
    
    // Only show alert creation if we have alert renderer and current symbol
    if (self.alertRenderer && self.chartWidget.currentSymbol) {
        // Convert point to price
        double priceAtPoint = [self.alertRenderer triggerValueForScreenY:point.y];
        NSString *formattedPrice = [NSString stringWithFormat:@"%.2f", priceAtPoint];
        
        // Menu item for creating alert
        NSMenuItem *createAlertItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Create Alert at %@", formattedPrice]
                                                                 action:@selector(createAlertAtMouseLocation:)
                                                          keyEquivalent:@""];
        createAlertItem.target = self;
        createAlertItem.representedObject = @{@"price": @(priceAtPoint), @"point": [NSValue valueWithPoint:point]};
        [contextMenu addItem:createAlertItem];
        
        [contextMenu addItem:[NSMenuItem separatorItem]];
    }
    
    // 🔬 NUOVO: Microscopio Menu
    if (self.chartData && self.chartData.count > 0 && self.chartWidget.currentSymbol) {
        NSMenuItem *microscopeItem = [self createMicroscopeMenuItem:point];
        if (microscopeItem) {
            [contextMenu addItem:microscopeItem];
            [contextMenu addItem:[NSMenuItem separatorItem]];
        }
    }
    
    // Other existing menu items could go here (chart settings, etc.)
    
    if (contextMenu.itemArray.count > 0) {
        [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self];
    }
}


#pragma mark - Alert Context Menu

- (void)showContextMenuForAlert:(AlertModel *)alert atPoint:(NSPoint)point withEvent:(NSEvent *)event {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Alert Actions"];
    
    // Edit Alert
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit Alert..."
                                                      action:@selector(editAlertFromContextMenu:)
                                               keyEquivalent:@""];
    editItem.target = self;
    editItem.representedObject = alert;
    [contextMenu addItem:editItem];
    
    // Delete Alert
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Alert"
                                                        action:@selector(deleteAlertFromContextMenu:)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    deleteItem.representedObject = alert;
    [contextMenu addItem:deleteItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Toggle Active/Inactive
    NSString *toggleTitle = alert.isActive ? @"Disable Alert" : @"Enable Alert";
    NSMenuItem *toggleItem = [[NSMenuItem alloc] initWithTitle:toggleTitle
                                                        action:@selector(toggleAlertFromContextMenu:)
                                                 keyEquivalent:@""];
    toggleItem.target = self;
    toggleItem.representedObject = alert;
    [contextMenu addItem:toggleItem];
    
    [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self];
}



#pragma mark - Alert Context Menu Actions

- (void)createAlertAtMouseLocation:(NSMenuItem *)menuItem {
    NSDictionary *info = menuItem.representedObject;
    double price = [info[@"price"] doubleValue];
    
    NSLog(@"🚨 Creating alert at price: %.2f for symbol: %@", price, self.chartWidget.currentSymbol);
    
    // Create pre-populated AlertModel
    AlertModel *newAlert = [self.alertRenderer createAlertTemplateAtScreenPoint:[info[@"point"] pointValue]];
    if (!newAlert) {
        NSLog(@"⚠️ Could not create alert template");
        return;
    }
    
    // Show AlertEditController (riuso totale!)
    AlertEditController *editor = [[AlertEditController alloc] initWithAlert:newAlert];
    editor.completionHandler = ^(AlertModel *editedAlert, BOOL saved) {
        if (saved && editedAlert) {
            // AlertEditController già salva via DataHub
            // Solo refresh della UI del chart
            [self.alertRenderer refreshAlerts];
            NSLog(@"✅ Alert created from chart: %@ at %.2f", editedAlert.symbol, editedAlert.triggerValue);
        }
    };
    
    // Show as sheet
    [self.window beginSheet:editor.window completionHandler:nil];
}

- (void)editAlertFromContextMenu:(NSMenuItem *)menuItem {
    AlertModel *alert = menuItem.representedObject;
    NSLog(@"✏️ ChartPanelView: Editing alert %@ %.2f", alert.symbol, alert.triggerValue);
    
    AlertEditController *editor = [[AlertEditController alloc] initWithAlert:alert];
    editor.completionHandler = ^(AlertModel *editedAlert, BOOL saved) {
        if (saved) {
            [self.alertRenderer refreshAlerts];
        }
    };
    
    [self.window beginSheet:editor.window completionHandler:nil];
}

- (void)deleteAlertFromContextMenu:(NSMenuItem *)menuItem {
    AlertModel *alert = menuItem.representedObject;
    
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"Delete Alert";
    confirmAlert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the alert for %@ at %.2f?",
                                   alert.symbol, alert.triggerValue];
    [confirmAlert addButtonWithTitle:@"Delete"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    confirmAlert.alertStyle = NSAlertStyleWarning;
    
    NSModalResponse response = [confirmAlert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [[DataHub shared] deleteAlertModel:alert];
        [self.alertRenderer refreshAlerts];
        NSLog(@"🗑️ Deleted alert %@ %.2f", alert.symbol, alert.triggerValue);
    }
}

- (void)toggleAlertFromContextMenu:(NSMenuItem *)menuItem {
    AlertModel *alert = menuItem.representedObject;
    
    alert.isActive = !alert.isActive;
    [[DataHub shared] updateAlertModel:alert];
    [self.alertRenderer refreshAlerts];
    
    NSLog(@"🔄 Toggled alert %@ %.2f to %@", alert.symbol, alert.triggerValue,
          alert.isActive ? @"ACTIVE" : @"INACTIVE");
}

#pragma mark - Alert Interaction Methods

- (void)startEditingAlertAtPoint:(NSPoint)point {
    if (!self.alertRenderer) return;
    
    AlertModel *alertAtPoint = [self.alertRenderer alertAtScreenPoint:point tolerance:10.0];
    if (alertAtPoint) {
        [self.alertRenderer startDraggingAlert:alertAtPoint atPoint:point];
        self.isInAlertDragMode = YES;
        
        NSLog(@"🚨 ChartPanelView (%@): Started editing alert %@ %.2f",
              self.panelType, alertAtPoint.symbol, alertAtPoint.triggerValue);
    }
}

- (void)stopEditingAlert {
    if (!self.isInAlertDragMode) return;
    
    self.isInAlertDragMode = NO;
    
    if (self.alertRenderer.isInAlertDragMode) {
        [self.alertRenderer cancelDrag];
    }
    
    NSLog(@"✅ ChartPanelView (%@): Stopped editing alert", self.panelType);
}



#pragma mark - Microscopio Implementation

- (NSMenuItem *)createMicroscopeMenuItem:(NSPoint)point {
    // Verifica che abbiamo dati e simbolo
    if (!self.chartData || self.chartData.count == 0 || !self.chartWidget.currentSymbol) {
        return nil;
    }
    
    // Determina barra cliccata
    NSInteger clickedBarIndex = [self barIndexForXCoordinate:point.x];
    if (clickedBarIndex < 0 || clickedBarIndex >= self.chartData.count) {
        return nil;
    }
    
    // Verifica che il timeframe corrente supporti zoom intraday
    ChartTimeframe currentTimeframe = self.chartWidget.currentTimeframe;
    NSArray<NSNumber *> *availableTimeframes = [self getIntradayTimeframesForCurrentTimeframe:currentTimeframe];
    
    if (availableTimeframes.count == 0) {
        return nil; // Nessun timeframe intraday disponibile
    }
    
    // Crea menu principale Microscopio
    NSMenuItem *microscopeItem = [[NSMenuItem alloc] initWithTitle:@"🔬 Microscopio"
                                                           action:nil
                                                    keyEquivalent:@""];
    
    NSMenu *microscopeSubmenu = [[NSMenu alloc] initWithTitle:@"Microscopio"];
    
    // Aggiungi opzioni range
    NSArray *rangeOptions = @[
        @{@"title": @"📊 Barra Singola", @"key": @"single"},
        @{@"title": @"📈 Zona Media (-2 a +5)", @"key": @"medium"},
        @{@"title": @"📊 Zona Estesa (-10 a +25)", @"key": @"extended"}
    ];
    
    for (NSDictionary *rangeOption in rangeOptions) {
        NSMenuItem *rangeItem = [[NSMenuItem alloc] initWithTitle:rangeOption[@"title"]
                                                           action:nil
                                                    keyEquivalent:@""];
        
        // Crea submenu timeframes per questo range
        NSMenu *timeframeSubmenu = [[NSMenu alloc] initWithTitle:rangeOption[@"title"]];
        
        for (NSNumber *timeframeNum in availableTimeframes) {
            ChartTimeframe timeframe = [timeframeNum intValue];
            NSString *timeframeStr = [self timeframeToDisplayString:timeframe];
            
            NSMenuItem *timeframeItem = [[NSMenuItem alloc] initWithTitle:timeframeStr
                                                                   action:@selector(openMicroscopeWithParameters:)
                                                            keyEquivalent:@""];
            timeframeItem.target = self;
            timeframeItem.representedObject = @{
                @"rangeType": rangeOption[@"key"],
                @"timeframe": timeframeNum,
                @"clickedBarIndex": @(clickedBarIndex),
                @"clickPoint": [NSValue valueWithPoint:point]
            };
            
            [timeframeSubmenu addItem:timeframeItem];
        }
        
        rangeItem.submenu = timeframeSubmenu;
        [microscopeSubmenu addItem:rangeItem];
    }
    
    microscopeItem.submenu = microscopeSubmenu;
    return microscopeItem;
}

- (NSArray<NSNumber *> *)getIntradayTimeframesForCurrentTimeframe:(ChartTimeframe)currentTimeframe {
    NSMutableArray *availableTimeframes = [NSMutableArray array];
    
    // Solo se siamo su Daily o superiore, mostriamo intraday
    if (currentTimeframe >= ChartTimeframeDaily) {
        [availableTimeframes addObject:@(ChartTimeframe1Hour)];
        [availableTimeframes addObject:@(ChartTimeframe30Min)];
        [availableTimeframes addObject:@(ChartTimeframe15Min)];
        [availableTimeframes addObject:@(ChartTimeframe5Min)];
        [availableTimeframes addObject:@(ChartTimeframe1Min)];
    }
    // Se siamo su 4H, mostriamo timeframes inferiori
    else if (currentTimeframe == ChartTimeframe4Hour) {
        [availableTimeframes addObject:@(ChartTimeframe1Hour)];
        [availableTimeframes addObject:@(ChartTimeframe30Min)];
        [availableTimeframes addObject:@(ChartTimeframe15Min)];
        [availableTimeframes addObject:@(ChartTimeframe5Min)];
    }
    // Se siamo su 1H, mostriamo solo minute timeframes
    else if (currentTimeframe == ChartTimeframe1Hour) {
        [availableTimeframes addObject:@(ChartTimeframe30Min)];
        [availableTimeframes addObject:@(ChartTimeframe15Min)];
        [availableTimeframes addObject:@(ChartTimeframe5Min)];
        [availableTimeframes addObject:@(ChartTimeframe1Min)];
    }
    
    return [availableTimeframes copy];
}

- (NSString *)timeframeToDisplayString:(ChartTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min: return @"1 minuto";
        case ChartTimeframe5Min: return @"5 minuti";
        case ChartTimeframe15Min: return @"15 minuti";
        case ChartTimeframe30Min: return @"30 minuti";
        case ChartTimeframe1Hour: return @"1 ora";
        case ChartTimeframe4Hour: return @"4 ore";
        case ChartTimeframeDaily: return @"1 giorno";
        case ChartTimeframeWeekly: return @"1 settimana";
        case ChartTimeframeMonthly: return @"1 mese";
        default: return @"Sconosciuto";
    }
}

- (void)openMicroscopeWithParameters:(NSMenuItem *)menuItem {
    NSDictionary *params = menuItem.representedObject;
    NSString *rangeType = params[@"rangeType"];
    ChartTimeframe targetTimeframe = [params[@"timeframe"] intValue];
    NSInteger clickedBarIndex = [params[@"clickedBarIndex"] integerValue];
    
    NSLog(@"🔬 Opening Microscopio: range=%@, timeframe=%ld, barIndex=%ld",
          rangeType, (long)targetTimeframe, (long)clickedBarIndex);
    
    // Calcola range di date
    NSArray<NSDate *> *dateRange = [self calculateDateRangeForType:rangeType
                                                   clickedBarIndex:clickedBarIndex];
    if (!dateRange || dateRange.count != 2) {
        NSLog(@"❌ Microscopio: Invalid date range calculated");
        return;
    }
    
    NSDate *startDate = dateRange[0];
    NSDate *endDate = dateRange[1];
    
    NSLog(@"🔬 Microscopio date range: %@ to %@", startDate, endDate);
    
    // Verifica validità range
    if ([startDate compare:endDate] != NSOrderedAscending) {
        NSLog(@"❌ Microscopio: Invalid date range - start >= end");
        return;
    }
    
    // Converte timeframe per API DataHub
    BarTimeframe apiTimeframe = [self chartTimeframeToBarTimeframe:targetTimeframe];
    BOOL needExtendedHours = (self.chartWidget.tradingHoursMode == ChartTradingHoursWithAfterHours);

    // Chiamata DataHub per dati microscopi (API date range)
    [[DataHub shared] getHistoricalBarsForSymbol:self.chartWidget.currentSymbol
                                        timeframe:apiTimeframe
                                        startDate:startDate
                                          endDate:endDate
                               needExtendedHours:needExtendedHours
                                       completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!isFresh) {
                // Se i dati sono dalla cache, potrebbe non essere un errore
                NSLog(@"⚠️ Microscopio: Using cached data or no fresh data available");
            }
            
            if (!bars || bars.count == 0) {
                NSLog(@"⚠️ Microscopio: No data returned for range");
                [self showMicroscopeNoDataAlert];
                return;
            }
            
            NSLog(@"✅ Microscopio: Received %lu bars (fresh: %@)", (unsigned long)bars.count, isFresh ? @"YES" : @"NO");
            [self openMicroscopeWindowWithBars:bars
                                     timeframe:targetTimeframe
                                     rangeType:rangeType
                                     dateRange:dateRange];
        });
    }];
}

- (NSArray<NSDate *> *)calculateDateRangeForType:(NSString *)rangeType
                                  clickedBarIndex:(NSInteger)clickedBarIndex {
    
    if (clickedBarIndex < 0 || clickedBarIndex >= self.chartData.count) {
        return nil;
    }
    
    NSInteger startIdx, endIdx;
    
    if ([rangeType isEqualToString:@"single"]) {
        // Barra singola
        startIdx = clickedBarIndex;
        endIdx = clickedBarIndex;
    }
    else if ([rangeType isEqualToString:@"medium"]) {
        // Zona media: -2 a +5
        startIdx = MAX(0, clickedBarIndex - 2);
        endIdx = MIN(self.chartData.count - 1, clickedBarIndex + 5);
    }
    else if ([rangeType isEqualToString:@"extended"]) {
        // Zona estesa: -10 a +25
        startIdx = MAX(0, clickedBarIndex - 10);
        endIdx = MIN(self.chartData.count - 1, clickedBarIndex + 25);
    }
    else {
        return nil;
    }
    
    NSDate *startDate = self.chartData[startIdx].date;
    NSDate *endDate = self.chartData[endIdx].date;
    
    // Per singola barra, estendi di qualche ora per garantire dati
    if ([rangeType isEqualToString:@"single"]) {
        startDate = [startDate dateByAddingTimeInterval:-3600]; // -1 ora
        endDate = [endDate dateByAddingTimeInterval:86400]; // +1 giorno
    }
    else {
        // Per range multipli, estendi leggermente per sicurezza
        endDate = [endDate dateByAddingTimeInterval:86400]; // +1 giorno
    }
    
    return @[startDate, endDate];
}

- (void)openMicroscopeWindowWithBars:(NSArray<HistoricalBarModel *> *)bars
                           timeframe:(ChartTimeframe)timeframe
                           rangeType:(NSString *)rangeType
                           dateRange:(NSArray<NSDate *> *)dateRange {
    
    // Crea ChartWidget per la finestra microscopio
    ChartWidget *microscopeChart = [[ChartWidget alloc] initWithType:@"chart"
                                                           panelType:PanelTypeCenter];
   
    
    [microscopeChart setChainActive:NO withColor:nil];
    [microscopeChart setStaticMode:YES];

    
    microscopeChart.currentSymbol = self.chartWidget.currentSymbol;
    [microscopeChart setTimeframe:timeframe];
    
    // Popola direttamente con i dati ricevuti invece di ricaricare
    
    // Genera titolo finestra descrittivo
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    // NUOVO: Usa Eastern Time per consistenza
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    
    NSString *rangeDescription = [rangeType isEqualToString:@"single"] ? @"Barra Singola" :
                                [rangeType isEqualToString:@"medium"] ? @"Zona Media" : @"Zona Estesa";
    
    NSString *windowTitle = [NSString stringWithFormat:@"🔬 %@ - %@ (%@) - %@ a %@",
                           self.chartWidget.currentSymbol,
                           [self timeframeToDisplayString:timeframe],
                           rangeDescription,
                           [formatter stringFromDate:dateRange[0]],
                           [formatter stringFromDate:dateRange[1]]];
    
    // NUOVO: Usa AppDelegate per creare la finestra invece di crearla direttamente
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    if (!appDelegate) {
        NSLog(@"❌ ChartPanelView: Cannot get AppDelegate for microscope window");
        return;
    }
    
    // Ottieni dimensioni appropriate per finestra microscopio
    NSSize microscopeSize = [appDelegate defaultSizeForWidgetType:@"Microscope Chart"];
    
    // Crea finestra tramite AppDelegate (viene automaticamente registrata)
    FloatingWidgetWindow *microscopeWindow = [appDelegate createMicroscopeWindowWithChartWidget:microscopeChart
                                                                                           title:windowTitle
                                                                                            size:microscopeSize];
    [microscopeChart.view setWantsLayer:YES];
    
    if (!microscopeWindow) {
        NSLog(@"❌ ChartPanelView: Failed to create microscope window via AppDelegate");
        return;
    }
    
    // Mostra la finestra
    [microscopeWindow makeKeyAndOrderFront:nil];
    [microscopeChart updateWithHistoricalBars:bars];

    NSLog(@"✅ ChartPanelView: Microscope window opened via AppDelegate with %lu bars", (unsigned long)bars.count);
}


- (void)showMicroscopeNoDataAlert {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Nessun Dato Disponibile";
    alert.informativeText = @"Non sono disponibili dati per il timeframe selezionato nel range richiesto.";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (BarTimeframe)chartTimeframeToBarTimeframe:(ChartTimeframe)chartTimeframe {
    switch (chartTimeframe) {
        case ChartTimeframe1Min: return BarTimeframe1Min;
        case ChartTimeframe5Min: return BarTimeframe5Min;
        case ChartTimeframe15Min: return BarTimeframe15Min;
        case ChartTimeframe30Min: return BarTimeframe30Min;
        case ChartTimeframe1Hour: return BarTimeframe1Hour;
        case ChartTimeframe4Hour: return BarTimeframe4Hour;
        case ChartTimeframeDaily: return BarTimeframe1Day;
        case ChartTimeframeWeekly: return BarTimeframe1Week;
        case ChartTimeframeMonthly: return BarTimeframe1Month;
        default: return BarTimeframe1Day;
    }
}


@end
