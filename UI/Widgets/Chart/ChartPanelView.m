//
//  ChartPanelView.m
//  TradingApp
//

#import "ChartPanelView.h"
#import "ChartWidget.h"

@interface ChartPanelView ()
@property (nonatomic, strong) NSTrackingArea *trackingArea;
@end

@implementation ChartPanelView

- (instancetype)initWithPanelModel:(ChartPanelModel *)panelModel
                        coordinator:(ChartCoordinator *)coordinator
                        chartWidget:(ChartWidget *)chartWidget {
    self = [super init];
    if (self) {
        _panelModel = panelModel;
        _coordinator = coordinator;
        _chartWidget = chartWidget;
        _showYAxis = YES;
        _showTitle = YES;
        
        [self setupView];
        [self setupUI];
    }
    return self;
}

- (void)setupView {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.wantsLayer = YES;
    
    // Set background color based on panel type
    if (self.panelModel.panelType == ChartPanelTypeMain) {
        self.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    } else {
        self.layer.backgroundColor = [[NSColor controlBackgroundColor]
            blendedColorWithFraction:0.05 ofColor:[NSColor systemBlueColor]].CGColor;
    }
    
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.borderWidth = 1.0;
}

- (void)setupUI {
    [self setupTitleLabel];
    [self setupDeleteButton];
    [self setupYAxis];
    [self setupConstraints];
}

- (void)setupTitleLabel {
    self.titleLabel = [[NSTextField alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.stringValue = self.panelModel.title;
    self.titleLabel.font = [NSFont boldSystemFontOfSize:12];
    self.titleLabel.textColor = [NSColor labelColor];
    self.titleLabel.backgroundColor = [NSColor clearColor];
    self.titleLabel.bordered = NO;
    self.titleLabel.editable = NO;
    self.titleLabel.selectable = NO;
    [self addSubview:self.titleLabel];
}

- (void)setupDeleteButton {
    if (self.panelModel.canBeDeleted) {
        self.deleteButton = [[NSButton alloc] init];
        self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.deleteButton.title = @"✕";
        self.deleteButton.font = [NSFont systemFontOfSize:12];
        self.deleteButton.buttonType = NSButtonTypeMomentaryPushIn;
        self.deleteButton.bezelStyle = NSBezelStyleInline;
        self.deleteButton.target = self;
        self.deleteButton.action = @selector(deleteButtonClicked:);
        [self addSubview:self.deleteButton];
    }
}

- (void)setupYAxis {
    self.yAxisLabel = [[NSTextField alloc] init];
    self.yAxisLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.yAxisLabel.stringValue = @"";
    self.yAxisLabel.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular];
    self.yAxisLabel.textColor = [NSColor secondaryLabelColor];
    self.yAxisLabel.backgroundColor = [NSColor clearColor];
    self.yAxisLabel.bordered = NO;
    self.yAxisLabel.editable = NO;
    self.yAxisLabel.selectable = NO;
    self.yAxisLabel.alignment = NSTextAlignmentRight;
    [self addSubview:self.yAxisLabel];
}

- (void)setupConstraints {
    NSMutableArray *constraints = [NSMutableArray array];
    
    // Title constraints
    [constraints addObjectsFromArray:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.titleLabel.heightAnchor constraintEqualToConstant:20]
    ]];
    
    // Delete button constraints (if exists)
    if (self.deleteButton) {
        [constraints addObjectsFromArray:@[
            [self.deleteButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
            [self.deleteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.deleteButton.widthAnchor constraintEqualToConstant:20],
            [self.deleteButton.heightAnchor constraintEqualToConstant:20],
            
            // Title should not overlap delete button
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.deleteButton.leadingAnchor constant:-8]
        ]];
    } else {
        // No delete button, title can go to edge
        [constraints addObject:
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-8]
        ];
    }
    
    // Y-axis label constraints
    [constraints addObjectsFromArray:@[
        [self.yAxisLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.yAxisLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
        [self.yAxisLabel.widthAnchor constraintEqualToConstant:60],
    ]];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

#pragma mark - Tracking Area Management

- (void)updateTrackingAreas {
    // CORREZIONE: rimuovi correttamente le tracking areas precedenti
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
        self.trackingArea = nil;
    }
    
    // Remove any other tracking areas
    for (NSTrackingArea *area in self.trackingAreas) {
        [self removeTrackingArea:area];
    }
    
    // Create new tracking area
    NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited |
                                   NSTrackingMouseMoved |
                                   NSTrackingActiveInKeyWindow;
    
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                      options:options
                                                        owner:self
                                                     userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // CORREZIONE: sempre disegna lo sfondo
    [[NSColor controlBackgroundColor] setFill];
    NSRectFill(dirtyRect);
    
    // CORREZIONE: controlla sia i dati che il panel model
    if (!self.panelModel) {
        NSLog(@"⚠️ ChartPanelView: No panel model");
        [self drawPlaceholder:dirtyRect withText:@"No Panel Model"];
        return;
    }
    
    if (!self.historicalData || self.historicalData.count == 0) {
        [self drawPlaceholder:dirtyRect withText:[NSString stringWithFormat:@"%@ - Loading...", self.panelModel.title]];
        return;
    }
    
    // Calculate drawing area (exclude title and button areas)
    NSRect drawingRect = [self chartDrawingRect];
    // NUOVO: Disegna selezione area se attiva
    if (self.isSelecting) {
        [self drawSelectionArea];
    }
    
    // Draw crosshair if visible
    if (self.coordinator.crosshairVisible) {
        [self drawCrosshairInRect:drawingRect];
    }
    
    // NUOVO: Disegna info box se stiamo selezionando
    if (self.isSelecting && self.coordinator.crosshairVisible) {
        [self drawSelectionInfoBox];
    }
    
    // CORREZIONE: validazione del coordinator
    if (!self.coordinator) {
        NSLog(@"⚠️ ChartPanelView: No coordinator");
        [self drawPlaceholder:drawingRect withText:@"No Coordinator"];
        return;
    }
    
    // Draw all indicators in this panel
    for (id<IndicatorRenderer> indicator in self.panelModel.indicators) {
        if (indicator) {
            [indicator drawInRect:drawingRect
                         withData:self.historicalData
                      coordinator:self.coordinator];
        }
    }
    
    
    
    // Update Y-axis labels
    [self updateYAxisLabels:drawingRect];
}


// ======= NUOVO METODO: Disegna area di selezione =======
- (void)drawSelectionArea {
    NSRect drawingRect = [self chartDrawingRect];
    
    // Calcola X delle linee verticali
    CGFloat startX = self.selectionStartPoint.x;
    CGFloat endX = self.selectionCurrentPoint.x;
    
    // Assicura che le linee siano dentro l'area del chart
    startX = MAX(drawingRect.origin.x, MIN(startX, drawingRect.origin.x + drawingRect.size.width));
    endX = MAX(drawingRect.origin.x, MIN(endX, drawingRect.origin.x + drawingRect.size.width));
    
    // Area di selezione evidenziata
    NSRect selectionRect = NSMakeRect(MIN(startX, endX),
                                     drawingRect.origin.y,
                                     fabs(endX - startX),
                                     drawingRect.size.height);
    
    // CORREZIONE 1: Solo bordo, NO riempimento per non coprire il chart
    [[[NSColor systemBlueColor] colorWithAlphaComponent:0.1] setFill];
    NSRectFill(selectionRect);
    
    // Linee verticali ai bordi
    [[NSColor systemBlueColor] setStroke];
    NSBezierPath *selectionPath = [NSBezierPath bezierPath];
    selectionPath.lineWidth = 2.0;
    
    // Linea sinistra
    [selectionPath moveToPoint:NSMakePoint(startX, drawingRect.origin.y)];
    [selectionPath lineToPoint:NSMakePoint(startX, drawingRect.origin.y + drawingRect.size.height)];
    
    // Linea destra
    [selectionPath moveToPoint:NSMakePoint(endX, drawingRect.origin.y)];
    [selectionPath lineToPoint:NSMakePoint(endX, drawingRect.origin.y + drawingRect.size.height)];
    
    [selectionPath stroke];
}


- (void)drawSelectionInfoBox {
    if (!self.historicalData || self.historicalData.count == 0) return;
    
    // Calcola statistiche della selezione
    NSDictionary *selectionStats = [self calculateSelectionStatistics];
    if (!selectionStats) return;
    
    // Prepara testo info box
    NSString *infoText = [NSString stringWithFormat:@"Bars: %@\nChange: %@\nHigh: %@\nLow: %@\nAvg/Bar: %@",
                         selectionStats[@"barCount"],
                         selectionStats[@"totalChange"],
                         selectionStats[@"highestHigh"],
                         selectionStats[@"lowestLow"],
                         selectionStats[@"avgChangePerBar"]];
    
    // Stile testo
    NSDictionary *textAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor labelColor],
        NSBackgroundColorAttributeName: [NSColor clearColor]
    };
    
    NSSize textSize = [infoText sizeWithAttributes:textAttributes];
    
    // Posizione info box (vicino al cursore ma dentro i bordi)
    NSPoint boxPosition = self.selectionCurrentPoint;
    boxPosition.x += 10;
    boxPosition.y -= textSize.height + 10;
    
    // Assicura che sia dentro i bordi
    NSRect drawingRect = [self chartDrawingRect];
    if (boxPosition.x + textSize.width + 16 > drawingRect.origin.x + drawingRect.size.width) {
        boxPosition.x = self.selectionCurrentPoint.x - textSize.width - 26;
    }
    if (boxPosition.y < drawingRect.origin.y) {
        boxPosition.y = self.selectionCurrentPoint.y + 10;
    }
    
    NSRect boxRect = NSMakeRect(boxPosition.x, boxPosition.y, textSize.width + 16, textSize.height + 12);
    
    // Disegna sfondo info box
    [[[NSColor controlBackgroundColor] colorWithAlphaComponent:0.95] setFill];
    NSBezierPath *boxPath = [NSBezierPath bezierPathWithRoundedRect:boxRect xRadius:6 yRadius:6];
    [boxPath fill];
    
    // Bordo info box
    [[NSColor separatorColor] setStroke];
    boxPath.lineWidth = 1.0;
    [boxPath stroke];
    
    // Disegna testo
    [infoText drawAtPoint:NSMakePoint(boxPosition.x + 8, boxPosition.y + 6) withAttributes:textAttributes];
}


- (NSDictionary *)calculateSelectionStatistics {
    if (!self.historicalData || self.historicalData.count == 0) return nil;
    
    NSInteger startBar = MIN(self.selectionStartBarIndex, self.selectionEndBarIndex);
    NSInteger endBar = MAX(self.selectionStartBarIndex, self.selectionEndBarIndex);
    
    // Valida indici
    startBar = MAX(0, MIN(startBar, self.historicalData.count - 1));
    endBar = MAX(0, MIN(endBar, self.historicalData.count - 1));
    
    if (startBar >= endBar) return nil;
    
    NSInteger barCount = endBar - startBar + 1;
    
    // Ottieni dati primo e ultimo bar
    HistoricalBarModel *firstBar = self.historicalData[startBar];
    HistoricalBarModel *lastBar = self.historicalData[endBar];
    
    // Trova highest/lowest nel range
    double highestHigh = -INFINITY;
    double lowestLow = INFINITY;
    
    for (NSInteger i = startBar; i <= endBar; i++) {
        HistoricalBarModel *bar = self.historicalData[i];
        highestHigh = MAX(highestHigh, bar.high);
        lowestLow = MIN(lowestLow, bar.low);
    }
    
    // Calcola variazioni percentuali
    double totalChange = ((lastBar.close - firstBar.open) / firstBar.open) * 100.0;
    double highLowChange = ((highestHigh - lowestLow) / lowestLow) * 100.0;
    double avgChangePerBar = totalChange / barCount;
    
    return @{
        @"barCount": @(barCount),
        @"totalChange": [NSString stringWithFormat:@"%.2f%%", totalChange],
        @"highestHigh": [NSString stringWithFormat:@"%.2f", highestHigh],
        @"lowestLow": [NSString stringWithFormat:@"%.2f", lowestLow],
        @"avgChangePerBar": [NSString stringWithFormat:@"%.3f%%", avgChangePerBar]
    };
}

- (void)drawPlaceholder:(NSRect)rect withText:(NSString *)text {
    // CORREZIONE: placeholder più informativo
    NSString *placeholder = text ?: [NSString stringWithFormat:@"%@ - No Data", self.panelModel.title];
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    NSSize textSize = [placeholder sizeWithAttributes:attrs];
    NSPoint textPoint = NSMakePoint((rect.size.width - textSize.width) / 2,
                                   (rect.size.height - textSize.height) / 2);
    [placeholder drawAtPoint:textPoint withAttributes:attrs];
}

- (NSRect)chartDrawingRect {
    NSRect bounds = self.bounds;
    
    // Reserve space for title at top
    CGFloat topMargin = 24;
    // Reserve space for Y-axis labels on right
    CGFloat rightMargin = 70;
    // Small margins for left and bottom
    CGFloat leftMargin = 4;
    CGFloat bottomMargin = 4;
    
    return NSMakeRect(leftMargin,
                     bottomMargin,
                     bounds.size.width - leftMargin - rightMargin,
                     bounds.size.height - topMargin - bottomMargin);
}

- (void)drawCrosshairInRect:(NSRect)rect {
    NSPoint crosshairPos = self.coordinator.crosshairPosition;
    
    // Only draw crosshair if it's within this panel's drawing area
    if (!NSPointInRect(crosshairPos, rect)) return;
    
    [[NSColor labelColor] colorWithAlphaComponent:0.7].setStroke;
    
    NSBezierPath *crosshair = [NSBezierPath bezierPath];
    crosshair.lineWidth = 1.0;
    
    // Dashed line pattern
    CGFloat dashPattern[] = {4.0, 2.0};
    [crosshair setLineDash:dashPattern count:2 phase:0.0];
    
    // Vertical line
    [crosshair moveToPoint:NSMakePoint(crosshairPos.x, rect.origin.y)];
    [crosshair lineToPoint:NSMakePoint(crosshairPos.x, rect.origin.y + rect.size.height)];
    
    // Horizontal line
    [crosshair moveToPoint:NSMakePoint(rect.origin.x, crosshairPos.y)];
    [crosshair lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, crosshairPos.y)];
    
    [crosshair stroke];
}

- (void)updateYAxisLabels:(NSRect)drawingRect {
    if (!self.showYAxis || self.panelModel.indicators.count == 0) {
        self.yAxisLabel.stringValue = @"";
        return;
    }
    
    // Get the primary indicator's value range
    id<IndicatorRenderer> primaryIndicator = self.panelModel.indicators.firstObject;
    if (!primaryIndicator) return;
    
    // CORREZIONE: gestione sicura del value range
    if ([self.coordinator respondsToSelector:@selector(calculateValueRangeForData:type:)]) {
        NSRange valueRange = [self.coordinator calculateValueRangeForData:self.historicalData
                                                                     type:[primaryIndicator indicatorType]];
        
        // Show current value at crosshair position
        if (self.coordinator.crosshairVisible) {
            NSPoint crosshairPos = self.coordinator.crosshairPosition;
            if (NSPointInRect(crosshairPos, drawingRect)) {
                // Calculate value at Y position
                double normalizedY = (drawingRect.size.height - (crosshairPos.y - drawingRect.origin.y)) / drawingRect.size.height;
                double value = valueRange.location + (normalizedY * valueRange.length);
                
                self.yAxisLabel.stringValue = [NSString stringWithFormat:@"%.2f", value];
            }
        }
    }
}
- (BOOL)isFlipped{
    return YES;
}
#pragma mark - Mouse Event Handling


- (void)scrollWheel:(NSEvent *)event {
    NSPoint localPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect drawingRect = [self chartDrawingRect];
    
    if (!NSPointInRect(localPoint, drawingRect)) return;
    
    // CORREZIONE 2: Limiti zoom - non andare sotto 10 barre visibili
    NSRange currentRange = self.coordinator.visibleBarsRange;
    if (event.deltaY > 0 && currentRange.length <= 10) {
        NSLog(@"🚫 Zoom limit reached: minimum 10 bars visible");
        return;
    }
    
    // NUOVO: Scrolling del mouse = ZOOM con limiti
    CGFloat zoomSensitivity = 0.05;
    CGFloat zoomFactor = 1.0 + (event.deltaY * zoomSensitivity);
    
    // Zoom centrato sul punto del mouse
    [self.coordinator handleZoom:zoomFactor atPoint:localPoint inRect:drawingRect];
    [self.chartWidget refreshAllPanels];
    
    NSLog(@"🔍 Mouse wheel zoom: factor=%.3f at point (%.1f,%.1f)",
          zoomFactor, localPoint.x, localPoint.y);
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint localPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect drawingRect = [self chartDrawingRect];
    
    if (!NSPointInRect(localPoint, drawingRect)) return;
    
    // Inizia selezione area
    self.isSelecting = YES;
    self.selectionStartPoint = localPoint;
    self.selectionCurrentPoint = localPoint;
    
    // Calcola indice barra di partenza
    self.selectionStartBarIndex = [self.coordinator barIndexForXPosition:localPoint.x inRect:drawingRect];
    self.selectionEndBarIndex = self.selectionStartBarIndex;
    
    [self setNeedsDisplay:YES];
    
    NSLog(@"📊 Selection started at bar index %ld", (long)self.selectionStartBarIndex);
}

- (void)mouseDragged:(NSEvent *)event {
    if (!self.isSelecting) return;
    
    NSPoint localPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect drawingRect = [self chartDrawingRect];
    
    // Aggiorna punto corrente della selezione
    self.selectionCurrentPoint = localPoint;
    
    // Calcola indice barra corrente
    self.selectionEndBarIndex = [self.coordinator barIndexForXPosition:localPoint.x inRect:drawingRect];
    
    // Assicura che gli indici siano validi
    NSInteger maxBarIndex = self.historicalData.count - 1;
    self.selectionStartBarIndex = MAX(0, MIN(self.selectionStartBarIndex, maxBarIndex));
    self.selectionEndBarIndex = MAX(0, MIN(self.selectionEndBarIndex, maxBarIndex));
    
    // Aggiorna crosshair per mostrare info box
    [self.coordinator handleMouseMove:localPoint inRect:drawingRect];
    
    [self setNeedsDisplay:YES];
    [self.chartWidget refreshAllPanels];
}

- (void)mouseUp:(NSEvent *)event {
    if (!self.isSelecting) return;
    
    NSPoint localPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect drawingRect = [self chartDrawingRect];
    
    // Finalizza selezione
    self.selectionCurrentPoint = localPoint;
    self.selectionEndBarIndex = [self.coordinator barIndexForXPosition:localPoint.x inRect:drawingRect];
    
    // Assicura che gli indici siano ordinati correttamente
    NSInteger startBar = MIN(self.selectionStartBarIndex, self.selectionEndBarIndex);
    NSInteger endBar = MAX(self.selectionStartBarIndex, self.selectionEndBarIndex);
    
    // Se abbiamo una selezione valida, zoom nell'area selezionata
    if (abs((int)(endBar - startBar)) > 1) {
        [self zoomToBarRange:NSMakeRange(startBar, endBar - startBar + 1)];
        NSLog(@"🔍 Zooming to bars %ld-%ld", (long)startBar, (long)endBar);
    }
    
    // Reset stato selezione
    self.isSelecting = NO;
    [self setNeedsDisplay:YES];
}
// ======= NUOVO METODO: Zoom su range di barre =======
- (void)zoomToBarRange:(NSRange)barRange {
    // Valida il range
    if (!self.historicalData || barRange.location >= self.historicalData.count) return;
    
    NSInteger maxLength = self.historicalData.count - barRange.location;
    NSRange validRange = NSMakeRange(barRange.location, MIN(barRange.length, maxLength));
    
    // Aggiorna il coordinator con il nuovo range visibile
    [self.coordinator zoomToBarRange:validRange];
    
    // Refresh tutti i pannelli
    [self.chartWidget refreshAllPanels];
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint localPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect drawingRect = [self chartDrawingRect];
    
    if (NSPointInRect(localPoint, drawingRect)) {
        [self.coordinator handleMouseMove:localPoint inRect:drawingRect];
        [self setNeedsDisplay:YES];
        
        // Notify chart widget to update other panels
        [self.chartWidget refreshAllPanels];
    }
}

- (void)mouseEntered:(NSEvent *)event {
    self.coordinator.crosshairVisible = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    self.coordinator.crosshairVisible = NO;
    [self setNeedsDisplay:YES];
    [self.chartWidget refreshAllPanels];
}



#pragma mark - Data Updates

- (void)updateWithHistoricalData:(NSArray<HistoricalBarModel *> *)data {
    self.historicalData = data;
    // CORREZIONE: forza sempre il refresh
    [self setNeedsDisplay:YES];
}

- (void)refreshDisplay {
    [self setNeedsDisplay:YES];
}

- (void)updateUI {
    self.titleLabel.stringValue = self.panelModel.title;
    
    if (self.panelModel.canBeDeleted && !self.deleteButton) {
        [self setupDeleteButton];
        [self setupConstraints];
    } else if (!self.panelModel.canBeDeleted && self.deleteButton) {
        [self.deleteButton removeFromSuperview];
        self.deleteButton = nil;
        [self setupConstraints];
    }
}

#pragma mark - Actions

- (IBAction)deleteButtonClicked:(id)sender {
    NSLog(@"🗑️ Delete panel requested: %@", self.panelModel.title);
    [self.chartWidget requestDeletePanel:self.panelModel];
}

#pragma mark - View Lifecycle

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self updateTrackingAreas];
}

- (void)viewDidMoveToSuperview {
    [super viewDidMoveToSuperview];
    if (self.superview) {
        [self updateTrackingAreas];
    }
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    [self updateTrackingAreas];
}

- (void)setBounds:(NSRect)bounds {
    [super setBounds:bounds];
    [self updateTrackingAreas];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
