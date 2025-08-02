//
//  SeasonalChartWidget.m
//  TradingApp
//

#import "SeasonalChartWidget.h"
#import "SeasonalDataModel.h"
#import "QuarterlyDataPoint.h"
#import "DataHub+SeasonalData.h"

// Available data types from Zacks
static NSArray<NSString *> *kAvailableDataTypes = nil;

@interface SeasonalChartWidget () <NSTextFieldDelegate, NSComboBoxDelegate, NSComboBoxDataSource>

// Chart drawing properties
@property (nonatomic, assign) CGRect chartRect;
@property (nonatomic, assign) CGFloat barWidth;
@property (nonatomic, assign) CGFloat barSpacing;

// Chart data arrays for display
@property (nonatomic, strong) NSArray<QuarterlyDataPoint *> *displayQuarters;
@property (nonatomic, assign) double minValue;
@property (nonatomic, assign) double maxValue;
@property (nonatomic, assign) double minTTMValue;
@property (nonatomic, assign) double maxTTMValue;
// Drawing methods (used by SeasonalChartView)
- (void)drawChartInRect:(CGRect)rect;
- (void)drawEmptyState:(CGRect)rect;
- (void)drawGrid;
- (void)drawBars;
- (void)drawTTMLine;
- (void)drawAxes;
- (void)drawLabels;
- (void)drawBubbles;
- (void)drawCrosshair;
- (void)drawSegmentLabel:(NSString *)label atPoint:(CGPoint)point color:(NSColor *)color;

@end

@interface SeasonalChartView : NSView
@property (nonatomic, weak) SeasonalChartWidget *widget;

@end
@implementation SeasonalChartView

- (void)drawRect:(NSRect)dirtyRect {
    NSLog(@"🎨 SeasonalChartView drawRect called with rect: %@", NSStringFromRect(dirtyRect));
    
    // Clear background
    [[NSColor controlBackgroundColor] setFill];
    NSRectFill(dirtyRect);
    
    if (self.widget) {
        [self.widget drawChartInRect:dirtyRect];
    } else {
        // Fallback - draw error message
        NSString *message = @"Chart widget not connected";
        NSDictionary *attributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:16],
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
        };
        
        NSSize textSize = [message sizeWithAttributes:attributes];
        CGPoint textPoint = CGPointMake(
            dirtyRect.origin.x + (dirtyRect.size.width - textSize.width) / 2,
            dirtyRect.origin.y + (dirtyRect.size.height - textSize.height) / 2
        );
        
        [message drawAtPoint:textPoint withAttributes:attributes];
    }
}

- (BOOL)isFlipped {
    return NO; // Coordinate system con origine in basso-sinistra
}
- (void)scrollWheel:(NSEvent *)event {
    NSLog(@"🖱️ scrollWheel event: deltaY=%.2f", event.scrollingDeltaY);
    
    if (self.widget) {
        // Determina la direzione dello scroll
        // deltaY positivo = scroll up = zoom out (più anni)
        // deltaY negativo = scroll down = zoom in (meno anni)
        
        CGFloat deltaY = event.scrollingDeltaY;
        
        // Soglia minima per evitare zoom troppo sensibili
        if (fabs(deltaY) < 1.0) return;
        
        // Calcola il nuovo livello di zoom
        NSInteger currentZoom = self.widget.yearsToShow;
        NSInteger newZoom = currentZoom;
        
        if (deltaY < 0) {
            // Scroll up = zoom out (più anni)
            newZoom = currentZoom + 1;
        } else {
            // Scroll down = zoom in (meno anni)
            newZoom = currentZoom - 1;
        }
        
        // Applica il nuovo zoom tramite il widget
        [self.widget setZoomLevel:newZoom];
        
        NSLog(@"🔍 Zoom changed from %ld to %ld years", (long)currentZoom, (long)newZoom);
    }
}

- (BOOL)acceptsFirstResponder {
    return YES;
}
@end

@implementation SeasonalChartWidget

+ (void)initialize {
    if (self == [SeasonalChartWidget class]) {
        kAvailableDataTypes = @[
            @"revenue",
            @"eps_diluted",
            @"revenue_ttm",
            @"ps_ratio",
            @"pe_ratio",
            @"peg_ratio",
            @"gross_margin_profit",
            @"revenue_yoy"
        ];
    }
}

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.widgetType = @"SeasonalChart";
    self.currentSymbol = @"";
    self.currentDataType = @"revenue";
    self.yearsToShow = 5;
    self.maxYears = 10;
    self.isMouseInChart = NO;
}



#pragma mark - UI Setup

- (void)setupContentView {
    [super setupContentView];
    
    // CRITICO: Rimuove il placeholder di BaseWidget
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Setup dell'UI del SeasonalChart
    [self setupUI];
    [self setupConstraints];
    [self setupDefaults];
    
    // NUOVO: Setup context menu per chain integration
    [self setupChartContextMenu];
}

- (void)setupUI {
    // Header controls
    [self setupHeaderControls];
    
    // Main chart view
    [self setupChartView];
    
    // Footer controls
    [self setupFooterControls];
}

- (void)setupHeaderControls {
    // Symbol text field
    self.symbolTextField = [[NSTextField alloc] init];
    self.symbolTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolTextField.placeholderString = @"Enter symbol (e.g. AAPL)";
    self.symbolTextField.delegate = self;
    [self.contentView addSubview:self.symbolTextField];
    
    // Data type combo box
    self.dataTypeComboBox = [[NSComboBox alloc] init];
    self.dataTypeComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.dataTypeComboBox.delegate = self;
    self.dataTypeComboBox.dataSource = self;
    [self.dataTypeComboBox addItemsWithObjectValues:kAvailableDataTypes];
    [self.dataTypeComboBox selectItemAtIndex:0];
    [self.contentView addSubview:self.dataTypeComboBox];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.displayedWhenStopped = NO;
    [self.contentView addSubview:self.loadingIndicator];
}

- (void)setupChartView {
    NSLog(@"🎯 setupChartView called");
    
    // Crea la custom view invece di NSView normale
    SeasonalChartView *chartView = [[SeasonalChartView alloc] init];
    chartView.widget = self;
    self.chartView = chartView;
    
    self.chartView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Configurazione layer per border e styling
    self.chartView.wantsLayer = YES;
    self.chartView.layer.borderColor = [NSColor separatorColor].CGColor;
    self.chartView.layer.borderWidth = 1.0;
    self.chartView.layer.cornerRadius = 6.0;
    
    [self.contentView addSubview:self.chartView];
    
    // Add mouse tracking (esistente)
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc]
        initWithRect:NSZeroRect
        options:(NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect | NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited)
        owner:self
        userInfo:nil];
    [self.chartView addTrackingArea:trackingArea];
    
    NSLog(@"🎯 chartView created and added to contentView");
}

- (void)setupDefaults {
    NSLog(@"🎯 setupDefaults called");
    // Non serve più impostare layer delegate, drawRect si occupa di tutto
}

- (void)setupFooterControls {
    // Zoom slider
    self.zoomSlider = [[NSSlider alloc] init];
    self.zoomSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomSlider.minValue = 2;
    self.zoomSlider.maxValue = 10;
    self.zoomSlider.integerValue = self.yearsToShow;
    self.zoomSlider.target = self;
    self.zoomSlider.action = @selector(zoomSliderChanged:);
    [self.contentView addSubview:self.zoomSlider];
    
    // Zoom buttons
    self.zoomOutButton = [NSButton buttonWithTitle:@"−" target:self action:@selector(zoomOutClicked:)];
    self.zoomOutButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.zoomOutButton];
    
    self.zoomInButton = [NSButton buttonWithTitle:@"+" target:self action:@selector(zoomInClicked:)];
    self.zoomInButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.zoomInButton];
    
    self.zoomAllButton = [NSButton buttonWithTitle:@"ALL" target:self action:@selector(zoomAllClicked:)];
    self.zoomAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.zoomAllButton];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Header controls
        [self.symbolTextField.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.symbolTextField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.symbolTextField.widthAnchor constraintEqualToConstant:120],
        [self.symbolTextField.heightAnchor constraintEqualToConstant:25],
        
        [self.dataTypeComboBox.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.dataTypeComboBox.leadingAnchor constraintEqualToAnchor:self.symbolTextField.trailingAnchor constant:8],
        [self.dataTypeComboBox.widthAnchor constraintEqualToConstant:140],
        [self.dataTypeComboBox.heightAnchor constraintEqualToConstant:25],
        
        [self.loadingIndicator.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.dataTypeComboBox.trailingAnchor constant:8],
        [self.loadingIndicator.widthAnchor constraintEqualToConstant:20],
        [self.loadingIndicator.heightAnchor constraintEqualToConstant:20],
        
        // Chart view
        [self.chartView.topAnchor constraintEqualToAnchor:self.symbolTextField.bottomAnchor constant:8],
        [self.chartView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.chartView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.chartView.bottomAnchor constraintEqualToAnchor:self.zoomSlider.topAnchor constant:-8],
        
        // Footer controls
        [self.zoomSlider.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.zoomSlider.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:50],
        [self.zoomSlider.trailingAnchor constraintEqualToAnchor:self.zoomAllButton.leadingAnchor constant:-8],
        [self.zoomSlider.heightAnchor constraintEqualToConstant:20],
        
        [self.zoomOutButton.centerYAnchor constraintEqualToAnchor:self.zoomSlider.centerYAnchor],
        [self.zoomOutButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.zoomOutButton.widthAnchor constraintEqualToConstant:30],
        
        [self.zoomInButton.centerYAnchor constraintEqualToAnchor:self.zoomSlider.centerYAnchor],
        [self.zoomInButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.zoomInButton.widthAnchor constraintEqualToConstant:30],
        
        [self.zoomAllButton.centerYAnchor constraintEqualToAnchor:self.zoomSlider.centerYAnchor],
        [self.zoomAllButton.trailingAnchor constraintEqualToAnchor:self.zoomInButton.leadingAnchor constant:-4],
        [self.zoomAllButton.widthAnchor constraintEqualToConstant:35]
    ]];
}

#pragma mark - Data Loading

- (void)loadDataForSymbol:(NSString *)symbol dataType:(NSString *)dataType {
    NSLog(@"🎯 loadDataForSymbol: %@ dataType: %@", symbol, dataType);
    
    if (symbol.length == 0) return;
    
    self.currentSymbol = [symbol uppercaseString];
    self.currentDataType = dataType;
    
    [self.loadingIndicator startAnimation:nil];
    
    // Request data from DataHub
    [[DataHub shared] requestSeasonalDataForSymbol:self.currentSymbol
                                          dataType:self.currentDataType
                                        completion:^(SeasonalDataModel *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimation:nil];
            
            if (error) {
                NSLog(@"❌ Error loading seasonal data: %@", error.localizedDescription);
                // Forza comunque il redraw per mostrare l'errore
                [self.chartView setNeedsDisplay:YES];
                return;
            }
            
            NSLog(@"✅ Received seasonal data with %lu quarters", (unsigned long)data.quarters.count);
            
            self.seasonalData = data;
            [self updateDisplayData];
            
            NSLog(@"🎯 About to call setNeedsDisplay on chartView");
            [self.chartView setNeedsDisplay:YES];
            NSLog(@"🎯 setNeedsDisplay called");
        });
    }];
}


- (void)refreshCurrentData {
    if (self.currentSymbol.length > 0) {
        [self loadDataForSymbol:self.currentSymbol dataType:self.currentDataType];
    }
}

#pragma mark - Display Data Management

- (void)updateDisplayData {
    NSLog(@"🎯 updateDisplayData called");
    NSLog(@"🎯 seasonalData: %@", self.seasonalData ? @"present" : @"nil");
    
    if (!self.seasonalData) {
        self.displayQuarters = @[];
        NSLog(@"🎯 No seasonal data, setting empty displayQuarters");
        [self.chartView setNeedsDisplay:YES];
        return;
    }
    
    // Get quarters to display based on zoom level
    NSArray<QuarterlyDataPoint *> *allQuarters = self.seasonalData.quarters;
    NSLog(@"🎯 All quarters count: %lu", (unsigned long)allQuarters.count);
    
    if (allQuarters.count == 0) {
        self.displayQuarters = @[];
        NSLog(@"🎯 No quarters in seasonalData, setting empty displayQuarters");
        [self.chartView setNeedsDisplay:YES];
        return;
    }
    
    // Get last N years of quarters
    QuarterlyDataPoint *latestQuarter = [self.seasonalData latestQuarter];
    if (!latestQuarter) {
        self.displayQuarters = @[];
        NSLog(@"🎯 No latest quarter found, setting empty displayQuarters");
        [self.chartView setNeedsDisplay:YES];
        return;
    }
    
    NSLog(@"🎯 Latest quarter: Q%ld'%ld, yearsToShow: %ld", (long)latestQuarter.quarter, (long)latestQuarter.year, (long)self.yearsToShow);
    
    NSInteger startYear = latestQuarter.year - self.yearsToShow + 1;
    NSMutableArray *filteredQuarters = [NSMutableArray array];
    
    for (QuarterlyDataPoint *quarter in allQuarters) {
        if (quarter.year >= startYear) {
            [filteredQuarters addObject:quarter];
            NSLog(@"🎯 Including quarter: Q%ld'%ld = %.2f", (long)quarter.quarter, (long)quarter.year, quarter.value);
        }
    }
    
    self.displayQuarters = filteredQuarters;
    NSLog(@"🎯 Final displayQuarters count: %lu", (unsigned long)self.displayQuarters.count);
    
    // Calculate value ranges for Y-axis scaling
    [self calculateValueRanges];
    
    // Update max years available
    if (allQuarters.count > 0) {
        QuarterlyDataPoint *oldestQuarter = [self.seasonalData oldestQuarter];
        self.maxYears = latestQuarter.year - oldestQuarter.year + 1;
        self.zoomSlider.maxValue = MIN(self.maxYears, 10);
        NSLog(@"🎯 Updated maxYears: %ld", (long)self.maxYears);
    }
    
    // Force redraw
    NSLog(@"🎯 Forcing view redraw...");
    [self.chartView setNeedsDisplay:YES];
}

- (void)calculateValueRanges {
    if (self.displayQuarters.count == 0) {
        self.minValue = self.maxValue = 0;
        self.minTTMValue = self.maxTTMValue = 0;
        return;
    }
    
    // Calculate bar value range
    double minVal = INFINITY;
    double maxVal = -INFINITY;
    
    for (QuarterlyDataPoint *quarter in self.displayQuarters) {
        minVal = MIN(minVal, quarter.value);
        maxVal = MAX(maxVal, quarter.value);
    }
    
    // Add 10% padding
    double range = maxVal - minVal;
    self.minValue = minVal - (range * 0.1);
    self.maxValue = maxVal + (range * 0.1);
    
    // Calculate TTM value range
    double minTTM = INFINITY;
    double maxTTM = -INFINITY;
    
    for (QuarterlyDataPoint *quarter in self.displayQuarters) {
        double ttm = [self.seasonalData ttmValueForQuarter:quarter.quarter year:quarter.year];
        if (ttm > 0) {
            minTTM = MIN(minTTM, ttm);
            maxTTM = MAX(maxTTM, ttm);
        }
    }
    
    if (minTTM != INFINITY) {
        double ttmRange = maxTTM - minTTM;
        self.minTTMValue = minTTM - (ttmRange * 0.1);
        self.maxTTMValue = maxTTM + (ttmRange * 0.1);
    } else {
        self.minTTMValue = self.maxTTMValue = 0;
    }
}

#pragma mark - Chart Drawing (CALayer Delegate)

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    if (layer != self.chartView.layer) return;
    
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    CGRect bounds = layer.bounds;
    [self drawChartInRect:bounds];
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawChartInRect:(CGRect)rect {
    if (self.displayQuarters.count == 0) {
        [self drawEmptyState:rect];
        return;
    }
    
    // Calculate chart area (leave space for axes and labels)
    CGFloat margin = 40;
    self.chartRect = CGRectMake(margin, margin,
                               rect.size.width - margin * 2 - 60, // Extra space for right Y-axis
                               rect.size.height - margin * 2);
    
    // Calculate bar dimensions
    NSInteger quarterCount = self.displayQuarters.count;
    CGFloat availableWidth = self.chartRect.size.width;
    self.barSpacing = 4;
    self.barWidth = (availableWidth - (quarterCount - 1) * self.barSpacing) / quarterCount;
    
    // Draw components
    [self drawGrid];
    [self drawBars];
    [self drawTTMLine];
    [self drawAxes];
    [self drawLabels];
    [self drawBubbles];
    
    // Draw crosshair if mouse is in chart
    if (self.isMouseInChart) {
        [self drawCrosshair];
    }
}

- (void)drawEmptyState:(CGRect)rect {
    NSString *message = @"Enter a symbol to view seasonal data";
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:16],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    NSSize textSize = [message sizeWithAttributes:attributes];
    CGPoint textPoint = CGPointMake(
        rect.origin.x + (rect.size.width - textSize.width) / 2,
        rect.origin.y + (rect.size.height - textSize.height) / 2
    );
    
    [message drawAtPoint:textPoint withAttributes:attributes];
}

- (void)drawGrid {
    [[NSColor gridColor] setStroke];
    NSBezierPath *gridPath = [NSBezierPath bezierPath];
    gridPath.lineWidth = 0.5;
    
    // Horizontal grid lines
    NSInteger horizontalLines = 5;
    for (NSInteger i = 0; i <= horizontalLines; i++) {
        CGFloat y = self.chartRect.origin.y + (self.chartRect.size.height * i / horizontalLines);
        [gridPath moveToPoint:CGPointMake(self.chartRect.origin.x, y)];
        [gridPath lineToPoint:CGPointMake(self.chartRect.origin.x + self.chartRect.size.width, y)];
    }
    
    [gridPath stroke];
}

- (void)drawBars {
    for (NSInteger i = 0; i < self.displayQuarters.count; i++) {
        QuarterlyDataPoint *quarter = self.displayQuarters[i];
        
        // Calculate bar position and height
        CGFloat x = self.chartRect.origin.x + i * (self.barWidth + self.barSpacing);
        CGFloat normalizedValue = (quarter.value - self.minValue) / (self.maxValue - self.minValue);
        CGFloat height = normalizedValue * self.chartRect.size.height;
        CGFloat y = self.chartRect.origin.y;
        
        CGRect barRect = CGRectMake(x, y, self.barWidth, height);
        
        // COLORE BARRA: Basato su YoY performance se disponibile
        NSColor *barColor;
        if ([self.seasonalData canCalculateYoyForQuarter:quarter.quarter year:quarter.year]) {
            double yoyChange = [self.seasonalData yoyPercentChangeForQuarter:quarter.quarter year:quarter.year];
            barColor = (yoyChange >= 0) ? [NSColor systemGreenColor] : [NSColor systemRedColor];
        } else {
            // Default color se non c'è YoY comparison
            barColor = [NSColor systemBlueColor];
        }
        
        // Highlight la barra se è quella in hover
        if (quarter == self.hoveredQuarter) {
            barColor = [barColor colorWithAlphaComponent:0.8]; // Più opaca
        } else {
            barColor = [barColor colorWithAlphaComponent:0.6]; // Più trasparente
        }
        
        [barColor setFill];
        NSRectFill(barRect);
        /*
        // Border della barra
        [[NSColor labelColor] setStroke];
        NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:barRect];
        borderPath.lineWidth = 1.0;
        [borderPath stroke];*/
    }
}

- (void)drawTTMLine {
    if (self.displayQuarters.count < 4) return; // Need at least 4 quarters for TTM
    
    [[NSColor systemYellowColor] setStroke];
    NSBezierPath *ttmPath = [NSBezierPath bezierPath];
    ttmPath.lineWidth = 2.0;
    
    BOOL firstPoint = YES;
    
    for (NSInteger i = 0; i < self.displayQuarters.count; i++) {
        QuarterlyDataPoint *quarter = self.displayQuarters[i];
        
        // Skip if we can't calculate TTM
        if (![self.seasonalData canCalculateTTMForQuarter:quarter.quarter year:quarter.year]) {
            continue;
        }
        
        double ttmValue = [self.seasonalData ttmValueForQuarter:quarter.quarter year:quarter.year];
        
        // Calculate position
        CGFloat x = self.chartRect.origin.x + i * (self.barWidth + self.barSpacing) + self.barWidth / 2;
        CGFloat normalizedTTM = (ttmValue - self.minTTMValue) / (self.maxTTMValue - self.minTTMValue);
        CGFloat y = self.chartRect.origin.y + normalizedTTM * self.chartRect.size.height;
        
        CGPoint point = CGPointMake(x, y);
        
        if (firstPoint) {
            [ttmPath moveToPoint:point];
            firstPoint = NO;
        } else {
            [ttmPath lineToPoint:point];
        }
        
        // Draw point circle
        NSBezierPath *circlePath = [NSBezierPath bezierPath];
        [circlePath appendBezierPathWithOvalInRect:CGRectMake(x - 3, y - 3, 6, 6)];
        [circlePath fill];
    }
    
    [ttmPath stroke];
}

- (void)drawAxes {
    [[NSColor labelColor] setStroke];
    NSBezierPath *axesPath = [NSBezierPath bezierPath];
    axesPath.lineWidth = 1.0;
    
    // Left Y-axis
    [axesPath moveToPoint:CGPointMake(self.chartRect.origin.x, self.chartRect.origin.y)];
    [axesPath lineToPoint:CGPointMake(self.chartRect.origin.x,
                                     self.chartRect.origin.y + self.chartRect.size.height)];
    
    // Bottom X-axis
    [axesPath moveToPoint:CGPointMake(self.chartRect.origin.x, self.chartRect.origin.y)];
    [axesPath lineToPoint:CGPointMake(self.chartRect.origin.x + self.chartRect.size.width,
                                     self.chartRect.origin.y)];
    
    // Right Y-axis (for TTM values)
    [axesPath moveToPoint:CGPointMake(self.chartRect.origin.x + self.chartRect.size.width,
                                     self.chartRect.origin.y)];
    [axesPath lineToPoint:CGPointMake(self.chartRect.origin.x + self.chartRect.size.width,
                                     self.chartRect.origin.y + self.chartRect.size.height)];
    
    [axesPath stroke];
}

- (void)drawLabels {
    NSDictionary *labelAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };
    
    // X-axis labels (Quarter strings)
    for (NSInteger i = 0; i < self.displayQuarters.count; i++) {
        QuarterlyDataPoint *quarter = self.displayQuarters[i];
        NSString *label = quarter.shortQuarterString;
        
        CGFloat x = self.chartRect.origin.x + i * (self.barWidth + self.barSpacing) + self.barWidth / 2;
        NSSize labelSize = [label sizeWithAttributes:labelAttributes];
        CGPoint labelPoint = CGPointMake(x - labelSize.width / 2, self.chartRect.origin.y - 20);
        
        [label drawAtPoint:labelPoint withAttributes:labelAttributes];
    }
    
    // Left Y-axis labels (Bar values)
    NSInteger yLabelCount = 5;
    for (NSInteger i = 0; i <= yLabelCount; i++) {
        double value = self.minValue + (self.maxValue - self.minValue) * i / yLabelCount;
        NSString *label = [self formatValue:value];
        
        CGFloat y = self.chartRect.origin.y + self.chartRect.size.height * i / yLabelCount;
        NSSize labelSize = [label sizeWithAttributes:labelAttributes];
        CGPoint labelPoint = CGPointMake(self.chartRect.origin.x - labelSize.width - 5,
                                        y - labelSize.height / 2);
        
        [label drawAtPoint:labelPoint withAttributes:labelAttributes];
    }
    
    // Right Y-axis labels (TTM values)
    if (self.maxTTMValue > 0) {
        for (NSInteger i = 0; i <= yLabelCount; i++) {
            double ttmValue = self.minTTMValue + (self.maxTTMValue - self.minTTMValue) * i / yLabelCount;
            NSString *label = [self formatValue:ttmValue];
            
            CGFloat y = self.chartRect.origin.y + self.chartRect.size.height * i / yLabelCount;
            CGPoint labelPoint = CGPointMake(self.chartRect.origin.x + self.chartRect.size.width + 5,
                                           y - 5);
            
            [[NSColor systemYellowColor] setFill];
            [label drawAtPoint:labelPoint withAttributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:10],
                NSForegroundColorAttributeName: [NSColor systemYellowColor]
            }];
        }
    }
}

- (void)drawBubbles {
    // Disegna i segmenti solo se c'è un quarter selezionato dal mouse
    if (self.isMouseInChart && self.hoveredQuarter) {
        [self drawSegmentsForHoveredQuarter];
    }
}

- (void)drawSegmentsForHoveredQuarter {
    QuarterlyDataPoint *quarter = self.hoveredQuarter;
    NSInteger hoveredIndex = [self.displayQuarters indexOfObject:quarter];
    
    if (hoveredIndex == NSNotFound) return;
    
    // Calculate hovered bar center position
    CGFloat x = self.chartRect.origin.x + hoveredIndex * (self.barWidth + self.barSpacing) + self.barWidth / 2;
    CGFloat normalizedValue = (quarter.value - self.minValue) / (self.maxValue - self.minValue);
    CGFloat y = self.chartRect.origin.y + normalizedValue * self.chartRect.size.height;
    
    // YoY Comparison Segment (Verde/Rosso basato su incremento)
    if ([self.seasonalData canCalculateYoyForQuarter:quarter.quarter year:quarter.year]) {
        QuarterlyDataPoint *yoyQuarter = [self.seasonalData yoyComparisonQuarterFor:quarter.quarter year:quarter.year];
        NSInteger yoyIndex = [self.displayQuarters indexOfObject:yoyQuarter];
        
        if (yoyIndex != NSNotFound) {
            CGFloat yoyX = self.chartRect.origin.x + yoyIndex * (self.barWidth + self.barSpacing) + self.barWidth / 2;
            CGFloat yoyNormalizedValue = (yoyQuarter.value - self.minValue) / (self.maxValue - self.minValue);
            CGFloat yoyY = self.chartRect.origin.y + yoyNormalizedValue * self.chartRect.size.height;
            
            double yoyPercent = [self.seasonalData yoyPercentChangeForQuarter:quarter.quarter year:quarter.year];
            
            // COLORE CONDIZIONALE: Verde se positivo, Rosso se negativo
            NSColor *segmentColor = (yoyPercent >= 0) ? [NSColor systemGreenColor] : [NSColor systemRedColor];
            
            [self drawSquaredArcFrom:CGPointMake(yoyX, yoyY)
                                  to:CGPointMake(x, y)
                               color:segmentColor
                             yOffset:30];
            
            // YoY percentage label con colore condizionale
            NSString *yoyLabel = [NSString stringWithFormat:@"YoY %@", [self formatPercentChange:yoyPercent]];
            CGPoint midPoint = CGPointMake((yoyX + x) / 2, MAX(yoyY, y) + 40);
            [self drawLargeSegmentLabel:yoyLabel atPoint:midPoint color:segmentColor];
        }
    }
    
    // QoQ Comparison Segment (Verde/Rosso basato su incremento)
    if ([self.seasonalData canCalculateQoqForQuarter:quarter.quarter year:quarter.year]) {
        QuarterlyDataPoint *qoqQuarter = [self.seasonalData qoqComparisonQuarterFor:quarter.quarter year:quarter.year];
        NSInteger qoqIndex = [self.displayQuarters indexOfObject:qoqQuarter];
        
        if (qoqIndex != NSNotFound) {
            CGFloat qoqX = self.chartRect.origin.x + qoqIndex * (self.barWidth + self.barSpacing) + self.barWidth / 2;
            CGFloat qoqNormalizedValue = (qoqQuarter.value - self.minValue) / (self.maxValue - self.minValue);
            CGFloat qoqY = self.chartRect.origin.y + qoqNormalizedValue * self.chartRect.size.height;
            
            double qoqPercent = [self.seasonalData qoqPercentChangeForQuarter:quarter.quarter year:quarter.year];
            
            // COLORE CONDIZIONALE: Verde se positivo, Rosso se negativo
            NSColor *segmentColor = (qoqPercent >= 0) ? [NSColor systemGreenColor] : [NSColor systemRedColor];
            
            [self drawSquaredArcFrom:CGPointMake(qoqX, qoqY)
                                  to:CGPointMake(x, y)
                               color:segmentColor
                             yOffset:-40];
            
            // QoQ percentage label con colore condizionale
            NSString *qoqLabel = [NSString stringWithFormat:@"QoQ %@", [self formatPercentChange:qoqPercent]];
            CGPoint midPoint = CGPointMake((qoqX + x) / 2, MIN(qoqY, y) - 50);
            [self drawLargeSegmentLabel:qoqLabel atPoint:midPoint color:segmentColor];
        }
    }
    
    // TTM Comparison (se disponibile) - Blu/Arancione per differenziare
    if ([self.seasonalData canCalculateTTMForQuarter:quarter.quarter year:quarter.year]) {
        double ttmPercent = [self.seasonalData ttmPercentChangeForQuarter:quarter.quarter year:quarter.year];
        if (ttmPercent != 0) {
            // COLORE CONDIZIONALE: Blu scuro se positivo, Arancione se negativo
            NSColor *ttmColor = (ttmPercent >= 0) ? [NSColor systemBlueColor] : [NSColor systemOrangeColor];
            
            // TTM line indicator (orizzontale)
            CGFloat ttmY = y + ((ttmPercent >= 0) ? 60 : -60);
            
            [ttmColor setStroke];
            NSBezierPath *ttmIndicator = [NSBezierPath bezierPath];
            ttmIndicator.lineWidth = 3.0;
            [ttmIndicator moveToPoint:CGPointMake(x - 25, ttmY)];
            [ttmIndicator lineToPoint:CGPointMake(x + 25, ttmY)];
            [ttmIndicator stroke];
            
            // TTM percentage label
            NSString *ttmLabel = [NSString stringWithFormat:@"TTM %@", [self formatPercentChange:ttmPercent]];
            CGPoint ttmPoint = CGPointMake(x + 35, ttmY);
            [self drawLargeSegmentLabel:ttmLabel atPoint:ttmPoint color:ttmColor];
        }
    }
}

- (void)drawSquaredArcFrom:(CGPoint)startPoint to:(CGPoint)endPoint color:(NSColor *)color yOffset:(CGFloat)yOffset {
    [color setStroke];
    NSBezierPath *arcPath = [NSBezierPath bezierPath];
    arcPath.lineWidth = 2.5;
    
    // Calcola il punto medio orizzontale per l'arco
    CGFloat midX = (startPoint.x + endPoint.x) / 2;
    CGFloat arcY = MAX(startPoint.y, endPoint.y) + yOffset;
    
    // Disegna l'arco squadrato: verticale -> orizzontale -> verticale
    [arcPath moveToPoint:startPoint];
    [arcPath lineToPoint:CGPointMake(startPoint.x, arcY)]; // Verticale su
    [arcPath lineToPoint:CGPointMake(endPoint.x, arcY)];   // Orizzontale
    [arcPath lineToPoint:endPoint];                        // Verticale giù
    
    [arcPath stroke];
}

// NUOVO: Metodo per etichette grandi dei segmenti
- (void)drawLargeSegmentLabel:(NSString *)label atPoint:(CGPoint)point color:(NSColor *)color {
    NSDictionary *labelAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:16], // FONT GRANDE
        NSForegroundColorAttributeName: color
    };
    
    NSSize labelSize = [label sizeWithAttributes:labelAttributes];
    CGRect labelRect = CGRectMake(point.x - labelSize.width/2 - 8, point.y - labelSize.height/2 - 4,
                                  labelSize.width + 16, labelSize.height + 8);
    
    // Draw label background con più padding
    [[NSColor controlBackgroundColor] setFill];
    NSBezierPath *labelBg = [NSBezierPath bezierPathWithRoundedRect:labelRect xRadius:6 yRadius:6];
    [labelBg fill];
    
    // Draw label border più spesso
    [color setStroke];
    labelBg.lineWidth = 2.0;
    [labelBg stroke];
    
    // Draw label text
    [label drawAtPoint:CGPointMake(labelRect.origin.x + 8, labelRect.origin.y + 4) withAttributes:labelAttributes];
}


- (void)drawBubbleWithText:(NSString *)text atPoint:(CGPoint)point color:(NSColor *)color {
    NSDictionary *textAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor controlBackgroundColor]
    };
    
    NSSize textSize = [text sizeWithAttributes:textAttributes];
    CGFloat padding = 6;
    CGRect bubbleRect = CGRectMake(point.x, point.y - textSize.height/2 - padding/2,
                                   textSize.width + padding, textSize.height + padding);
    
    // Draw bubble background
    [color setFill];
    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:bubbleRect xRadius:4 yRadius:4];
    [bubblePath fill];
    
    // Draw text
    CGPoint textPoint = CGPointMake(bubbleRect.origin.x + padding/2, bubbleRect.origin.y + padding/2);
    [text drawAtPoint:textPoint withAttributes:textAttributes];
}

- (void)drawCrosshair {
    if (!self.hoveredQuarter) return;
    
    NSInteger hoveredIndex = [self.displayQuarters indexOfObject:self.hoveredQuarter];
    if (hoveredIndex == NSNotFound) return;
    
    // Calculate crosshair position
    CGFloat x = self.chartRect.origin.x + hoveredIndex * (self.barWidth + self.barSpacing) + self.barWidth / 2;
    CGFloat normalizedValue = (self.hoveredQuarter.value - self.minValue) / (self.maxValue - self.minValue);
    CGFloat y = self.chartRect.origin.y + normalizedValue * self.chartRect.size.height;
    
    [[NSColor systemGrayColor] setStroke];
    NSBezierPath *crosshairPath = [NSBezierPath bezierPath];
    crosshairPath.lineWidth = 1.0;
    
    // Vertical line (esistente)
    [crosshairPath moveToPoint:CGPointMake(x, self.chartRect.origin.y)];
    [crosshairPath lineToPoint:CGPointMake(x, self.chartRect.origin.y + self.chartRect.size.height)];
    
    // NUOVO: Horizontal line
    [crosshairPath moveToPoint:CGPointMake(self.chartRect.origin.x, y)];
    [crosshairPath lineToPoint:CGPointMake(self.chartRect.origin.x + self.chartRect.size.width, y)];
    
    [crosshairPath stroke];
    
    // NUOVO: Value bubble sulla linea orizzontale
    [self drawValueBubbleAtPoint:CGPointMake(self.chartRect.origin.x + self.chartRect.size.width + 5, y)
                           value:self.hoveredQuarter.value];
    
    // Quarter info bubble (esistente, spostato leggermente)
    [self drawQuarterInfoBubbleAtPoint:CGPointMake(x, self.chartRect.origin.y + self.chartRect.size.height + 5)
                               quarter:self.hoveredQuarter];
}

- (void)drawQuarterInfoBubbleAtPoint:(CGPoint)point quarter:(QuarterlyDataPoint *)quarter {
    NSString *quarterText = [NSString stringWithFormat:@"Q%ld'%ld", (long)quarter.quarter, (long)quarter.year];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor controlTextColor]
    };
    
    NSSize textSize = [quarterText sizeWithAttributes:attributes];
    CGRect bubbleRect = CGRectMake(point.x - textSize.width/2 - 6, point.y,
                                   textSize.width + 12, textSize.height + 6);
    
    // Draw bubble background
    [[NSColor controlBackgroundColor] setFill];
    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:bubbleRect xRadius:3 yRadius:3];
    [bubblePath fill];
    
    // Draw bubble border
    [[NSColor systemGrayColor] setStroke];
    bubblePath.lineWidth = 1.0;
    [bubblePath stroke];
    
    // Draw text
    [quarterText drawAtPoint:CGPointMake(bubbleRect.origin.x + 6, bubbleRect.origin.y + 3)
              withAttributes:attributes];
}

- (void)drawValueBubbleAtPoint:(CGPoint)point value:(double)value {
    NSString *valueText = [self formatValue:value];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor controlTextColor]
    };
    
    NSSize textSize = [valueText sizeWithAttributes:attributes];
    CGRect bubbleRect = CGRectMake(point.x, point.y - textSize.height/2 - 4,
                                   textSize.width + 12, textSize.height + 8);
    
    // Draw bubble background
    [[NSColor controlBackgroundColor] setFill];
    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:bubbleRect xRadius:4 yRadius:4];
    [bubblePath fill];
    
    // Draw bubble border
    [[NSColor systemGrayColor] setStroke];
    bubblePath.lineWidth = 1.0;
    [bubblePath stroke];
    
    // Draw text
    [valueText drawAtPoint:CGPointMake(bubbleRect.origin.x + 6, bubbleRect.origin.y + 4)
            withAttributes:attributes];
}

- (void)drawComparisonSegmentsForQuarter:(QuarterlyDataPoint *)quarter atIndex:(NSInteger)index {
    CGFloat x = self.chartRect.origin.x + index * (self.barWidth + self.barSpacing) + self.barWidth / 2;
    CGFloat normalizedValue = (quarter.value - self.minValue) / (self.maxValue - self.minValue);
    CGFloat y = self.chartRect.origin.y + normalizedValue * self.chartRect.size.height;
    
    // YoY Comparison Segment (Green)
    if ([self.seasonalData canCalculateYoyForQuarter:quarter.quarter year:quarter.year]) {
        QuarterlyDataPoint *yoyQuarter = [self.seasonalData yoyComparisonQuarterFor:quarter.quarter year:quarter.year];
        NSInteger yoyIndex = [self.displayQuarters indexOfObject:yoyQuarter];
        
        if (yoyIndex != NSNotFound) {
            CGFloat yoyX = self.chartRect.origin.x + yoyIndex * (self.barWidth + self.barSpacing) + self.barWidth / 2;
            CGFloat yoyNormalizedValue = (yoyQuarter.value - self.minValue) / (self.maxValue - self.minValue);
            CGFloat yoyY = self.chartRect.origin.y + yoyNormalizedValue * self.chartRect.size.height;
            
            [[NSColor systemGreenColor] setStroke];
            NSBezierPath *yoySegment = [NSBezierPath bezierPath];
            yoySegment.lineWidth = 2.0;
            [yoySegment moveToPoint:CGPointMake(x, y)];
            [yoySegment lineToPoint:CGPointMake(yoyX, yoyY)];
            [yoySegment stroke];
            
            // YoY percentage label
            double yoyPercent = [self.seasonalData yoyPercentChangeForQuarter:quarter.quarter year:quarter.year];
            NSString *yoyLabel = [NSString stringWithFormat:@"YoY %@", [self formatPercentChange:yoyPercent]];
            CGPoint midPoint = CGPointMake((x + yoyX) / 2, (y + yoyY) / 2 + 15);
            [self drawSegmentLabel:yoyLabel atPoint:midPoint color:[NSColor systemGreenColor]];
        }
    }
    
    // QoQ Comparison Segment (Blue)
    if ([self.seasonalData canCalculateQoqForQuarter:quarter.quarter year:quarter.year]) {
        QuarterlyDataPoint *qoqQuarter = [self.seasonalData qoqComparisonQuarterFor:quarter.quarter year:quarter.year];
        NSInteger qoqIndex = [self.displayQuarters indexOfObject:qoqQuarter];
        
        if (qoqIndex != NSNotFound) {
            CGFloat qoqX = self.chartRect.origin.x + qoqIndex * (self.barWidth + self.barSpacing) + self.barWidth / 2;
            CGFloat qoqNormalizedValue = (qoqQuarter.value - self.minValue) / (self.maxValue - self.minValue);
            CGFloat qoqY = self.chartRect.origin.y + qoqNormalizedValue * self.chartRect.size.height;
            
            [[NSColor systemBlueColor] setStroke];
            NSBezierPath *qoqSegment = [NSBezierPath bezierPath];
            qoqSegment.lineWidth = 2.0;
            [qoqSegment moveToPoint:CGPointMake(x, y)];
            [qoqSegment lineToPoint:CGPointMake(qoqX, qoqY)];
            [qoqSegment stroke];
            
            // QoQ percentage label
            double qoqPercent = [self.seasonalData qoqPercentChangeForQuarter:quarter.quarter year:quarter.year];
            NSString *qoqLabel = [NSString stringWithFormat:@"QoQ %@", [self formatPercentChange:qoqPercent]];
            CGPoint midPoint = CGPointMake((x + qoqX) / 2, (y + qoqY) / 2 - 15);
            [self drawSegmentLabel:qoqLabel atPoint:midPoint color:[NSColor systemBlueColor]];
        }
    }
    
    // TTM Comparison Segment (Yellow)
    if ([self.seasonalData canCalculateTTMForQuarter:quarter.quarter year:quarter.year]) {
        double ttmPercent = [self.seasonalData ttmPercentChangeForQuarter:quarter.quarter year:quarter.year];
        if (ttmPercent != 0) {
            CGFloat ttmY = y + 30; // Offset for TTM line
            
            [[NSColor systemYellowColor] setStroke];
            NSBezierPath *ttmSegment = [NSBezierPath bezierPath];
            ttmSegment.lineWidth = 2.0;
            [ttmSegment moveToPoint:CGPointMake(x - 20, ttmY)];
            [ttmSegment lineToPoint:CGPointMake(x + 20, ttmY)];
            [ttmSegment stroke];
            
            // TTM percentage label
            NSString *ttmLabel = [NSString stringWithFormat:@"TTM %@", [self formatPercentChange:ttmPercent]];
            CGPoint ttmPoint = CGPointMake(x + 25, ttmY);
            [self drawSegmentLabel:ttmLabel atPoint:ttmPoint color:[NSColor systemYellowColor]];
        }
    }
}

- (void)drawSegmentLabel:(NSString *)label atPoint:(CGPoint)point color:(NSColor *)color {
    NSDictionary *labelAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:10],
        NSForegroundColorAttributeName: color
    };
    
    NSSize labelSize = [label sizeWithAttributes:labelAttributes];
    CGRect labelRect = CGRectMake(point.x - labelSize.width/2 - 3, point.y - labelSize.height/2 - 2,
                                  labelSize.width + 6, labelSize.height + 4);
    
    // Draw label background
    [[NSColor controlBackgroundColor] setFill];
    NSBezierPath *labelBg = [NSBezierPath bezierPathWithRoundedRect:labelRect xRadius:3 yRadius:3];
    [labelBg fill];
    
    // Draw label border
    [color setStroke];
    labelBg.lineWidth = 1.0;
    [labelBg stroke];
    
    // Draw label text
    [label drawAtPoint:CGPointMake(labelRect.origin.x + 3, labelRect.origin.y + 2) withAttributes:labelAttributes];
}

#pragma mark - Mouse Tracking

- (void)mouseEntered:(NSEvent *)event {
    self.isMouseInChart = YES;
    [self.chartView.layer setNeedsDisplay];
}

- (void)mouseExited:(NSEvent *)event {
    self.isMouseInChart = NO;
    self.hoveredQuarter = nil;
    [self.chartView.layer setNeedsDisplay];
}

- (void)mouseMoved:(NSEvent *)event {
    if (!self.isMouseInChart || self.displayQuarters.count == 0) return;
    
    CGPoint locationInChart = [self.chartView convertPoint:event.locationInWindow fromView:nil];
    self.mouseLocation = locationInChart;
    
    // Find which quarter the mouse is over
    if (CGRectContainsPoint(self.chartRect, locationInChart)) {
        CGFloat relativeX = locationInChart.x - self.chartRect.origin.x;
        NSInteger quarterIndex = relativeX / (self.barWidth + self.barSpacing);
        
        if (quarterIndex >= 0 && quarterIndex < self.displayQuarters.count) {
            self.hoveredQuarter = self.displayQuarters[quarterIndex];
        } else {
            self.hoveredQuarter = nil;
        }
    } else {
        self.hoveredQuarter = nil;
    }
    
    [self.chartView.layer setNeedsDisplay];
}

#pragma mark - Control Actions

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if (notification.object == self.symbolTextField) {
        NSString *symbol = self.symbolTextField.stringValue;
        if (symbol.length > 0) {
            [self loadDataForSymbol:symbol dataType:self.currentDataType];
            
            // NUOVO: Invia automaticamente il simbolo alla chain se attiva
            [self sendCurrentSymbolToChain];
        }
    }
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    if (notification.object == self.dataTypeComboBox) {
        NSString *selectedDataType = self.dataTypeComboBox.objectValueOfSelectedItem;
        if (selectedDataType && self.currentSymbol.length > 0) {
            [self loadDataForSymbol:self.currentSymbol dataType:selectedDataType];
        }
    }
}

- (void)zoomSliderChanged:(NSSlider *)sender {
    [self setZoomLevel:sender.integerValue];
}

- (void)zoomOutClicked:(NSButton *)sender {
    [self zoomOut];
}

- (void)zoomInClicked:(NSButton *)sender {
    [self zoomIn];
}

- (void)zoomAllClicked:(NSButton *)sender {
    [self zoomToAll];
}

#pragma mark - Zoom Control

- (void)setZoomLevel:(NSInteger)years {
    // Assicurati che il nuovo valore sia nei limiti validi
    NSInteger minYears = 2;
    NSInteger maxYears = MIN(self.maxYears, 15); // Limite massimo ragionevole
    
    NSInteger newYears = MAX(minYears, MIN(years, maxYears));
    
    // Solo aggiorna se il valore è effettivamente cambiato
    if (newYears != self.yearsToShow) {
        NSLog(@"🔍 Setting zoom level from %ld to %ld years (requested: %ld)",
              (long)self.yearsToShow, (long)newYears, (long)years);
        
        self.yearsToShow = newYears;
        
        // Aggiorna lo slider per riflettere il cambiamento
        self.zoomSlider.integerValue = self.yearsToShow;
        
        // Aggiorna i dati visualizzati e ridisegna
        [self updateDisplayData];
        [self.chartView setNeedsDisplay:YES];
        
        // Feedback visivo opzionale
        [self showZoomFeedback];
    } else {
        NSLog(@"🔍 Zoom level unchanged: %ld years (at limit)", (long)self.yearsToShow);
    }
}

- (void)showZoomFeedback {
    // Crea un label temporaneo per mostrare il livello di zoom corrente
    NSTextField *feedbackLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"%ld Years", (long)self.yearsToShow]];
    feedbackLabel.backgroundColor = [[NSColor labelColor] colorWithAlphaComponent:0.8];
    feedbackLabel.textColor = [NSColor controlBackgroundColor];
    feedbackLabel.font = [NSFont boldSystemFontOfSize:14];
    feedbackLabel.alignment = NSTextAlignmentCenter;
    
    // Posiziona il feedback nell'angolo in alto a destra del chart
    feedbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartView addSubview:feedbackLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [feedbackLabel.topAnchor constraintEqualToAnchor:self.chartView.topAnchor constant:10],
        [feedbackLabel.trailingAnchor constraintEqualToAnchor:self.chartView.trailingAnchor constant:-10],
        [feedbackLabel.widthAnchor constraintEqualToConstant:80],
        [feedbackLabel.heightAnchor constraintEqualToConstant:25]
    ]];
    
    // Anima la scomparsa dopo 1 secondo
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.3;
            feedbackLabel.animator.alphaValue = 0.0;
        } completionHandler:^{
            [feedbackLabel removeFromSuperview];
        }];
    });
}
- (void)zoomIn {
    [self setZoomLevel:self.yearsToShow - 1];
}

- (void)zoomOut {
    [self setZoomLevel:self.yearsToShow + 1];
}

- (void)zoomToAll {
    [self setZoomLevel:self.maxYears];
}

#pragma mark - NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    return kAvailableDataTypes.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    return kAvailableDataTypes[index];
}

#pragma mark - Formatting Helpers

- (NSString *)formatValue:(double)value {
    if (value == 0) return @"0";
    
    if (ABS(value) >= 1e12) {
        return [NSString stringWithFormat:@"$%.1fT", value / 1e12];
    } else if (ABS(value) >= 1e9) {
        return [NSString stringWithFormat:@"$%.1fB", value / 1e9];
    } else if (ABS(value) >= 1e6) {
        return [NSString stringWithFormat:@"$%.1fM", value / 1e6];
    } else if (ABS(value) >= 1e3) {
        return [NSString stringWithFormat:@"$%.1fK", value / 1e3];
    } else {
        return [NSString stringWithFormat:@"$%.2f", value];
    }
}

- (NSString *)formatPercentChange:(double)percentChange {
    NSString *sign = (percentChange >= 0) ? @"+" : @"";
    return [NSString stringWithFormat:@"%@%.1f%%", sign, percentChange];
}

#pragma mark - BaseWidget Override

- (void)updateContentForType:(NSString *)newType {
    // SeasonalChart doesn't change based on type
    // Type is always "SeasonalChart"
}


- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    state[@"currentSymbol"] = self.currentSymbol ?: @"";
    state[@"currentDataType"] = self.currentDataType ?: @"revenue";
    state[@"yearsToShow"] = @(self.yearsToShow);
    
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    self.currentSymbol = state[@"currentSymbol"] ?: @"";
    self.currentDataType = state[@"currentDataType"] ?: @"revenue";
    self.yearsToShow = [state[@"yearsToShow"] integerValue] ?: 5;
    
    // Update UI
    self.symbolTextField.stringValue = self.currentSymbol;
    [self.dataTypeComboBox selectItemWithObjectValue:self.currentDataType];
    self.zoomSlider.integerValue = self.yearsToShow;
    
    // Reload data if we have a symbol
    if (self.currentSymbol.length > 0) {
        [self loadDataForSymbol:self.currentSymbol dataType:self.currentDataType];
    }
}

#pragma mark - Chain Integration

// Override del metodo BaseWidget per ricevere simboli dalle chain
- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    NSString *action = update[@"action"];
    
    if ([action isEqualToString:@"setSymbols"]) {
        NSArray *symbols = update[@"symbols"];
        if (symbols.count > 0) {
            [self handleSymbolsFromChain:symbols fromWidget:sender];
        }
    }
}

- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"SeasonalChartWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
    
    // Prendi il primo simbolo (SeasonalChart mostra un simbolo alla volta)
    NSString *newSymbol = symbols.firstObject;
    if (!newSymbol || newSymbol.length == 0) return;
    
    // Aggiorna il campo di input
    self.symbolTextField.stringValue = [newSymbol uppercaseString];
    
    // Carica i dati per il nuovo simbolo
    [self loadDataForSymbol:newSymbol dataType:self.currentDataType];
    
    // Mostra feedback temporaneo
    NSString *senderType = NSStringFromClass([sender class]);
    NSString *message = [NSString stringWithFormat:@"📊 Loaded %@ from %@", newSymbol, senderType];
    [self showChainFeedback:message];
    
    NSLog(@"SeasonalChartWidget: Loaded symbol '%@' from %@ chain", newSymbol, senderType);
}

// Invia il simbolo corrente alla chain quando l'utente ne inserisce uno nuovo
- (void)sendCurrentSymbolToChain {
    if (self.chainActive && self.currentSymbol.length > 0) {
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[self.currentSymbol]
        }];
        
        NSLog(@"SeasonalChartWidget: Sent symbol '%@' to chain", self.currentSymbol);
        [self showChainFeedback:[NSString stringWithFormat:@"📤 Sent %@ to chain", self.currentSymbol]];
    }
}

// NUOVO: Metodo per mostrare feedback temporaneo
- (void)showChainFeedback:(NSString *)message {
    // Crea un label temporaneo per feedback
    NSTextField *feedbackLabel = [NSTextField labelWithString:message];
    feedbackLabel.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.9];
    feedbackLabel.textColor = [NSColor controlBackgroundColor];
    feedbackLabel.font = [NSFont boldSystemFontOfSize:12];
    feedbackLabel.alignment = NSTextAlignmentCenter;
    feedbackLabel.drawsBackground = YES;
    feedbackLabel.bordered = NO;
    feedbackLabel.editable = NO;
    
    // Posiziona il feedback nell'angolo in basso a sinistra del chart
    feedbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartView addSubview:feedbackLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [feedbackLabel.bottomAnchor constraintEqualToAnchor:self.chartView.bottomAnchor constant:-10],
        [feedbackLabel.leadingAnchor constraintEqualToAnchor:self.chartView.leadingAnchor constant:10],
        [feedbackLabel.heightAnchor constraintEqualToConstant:25]
    ]];
    
    // Anima la scomparsa dopo 2.5 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.5;
            feedbackLabel.animator.alphaValue = 0.0;
        } completionHandler:^{
            [feedbackLabel removeFromSuperview];
        }];
    });
}

#pragma mark - Context Menu Integration

// Aggiungi context menu al chart per inviare simbolo alla chain
- (void)setupChartContextMenu {
    NSMenu *contextMenu = [[NSMenu alloc] init];
    
    // Menu item per inviare simbolo corrente alla chain
    NSMenuItem *sendToChainItem = [[NSMenuItem alloc] initWithTitle:@"Send Symbol to Chain"
                                                             action:@selector(contextMenuSendSymbolToChain:)
                                                      keyEquivalent:@""];
    sendToChainItem.target = self;
    [contextMenu addItem:sendToChainItem];
    
    // Separator
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Menu item per copiare simbolo
    NSMenuItem *copySymbolItem = [[NSMenuItem alloc] initWithTitle:@"Copy Symbol"
                                                            action:@selector(contextMenuCopySymbol:)
                                                     keyEquivalent:@""];
    copySymbolItem.target = self;
    [contextMenu addItem:copySymbolItem];
    
    self.chartView.menu = contextMenu;
}

- (IBAction)contextMenuSendSymbolToChain:(id)sender {
    if (self.currentSymbol.length > 0) {
        [self sendCurrentSymbolToChain];
    }
}

- (IBAction)contextMenuCopySymbol:(id)sender {
    if (self.currentSymbol.length > 0) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard setString:self.currentSymbol forType:NSPasteboardTypeString];
        
        [self showChainFeedback:[NSString stringWithFormat:@"📋 Copied %@", self.currentSymbol]];
    }
}

@end
