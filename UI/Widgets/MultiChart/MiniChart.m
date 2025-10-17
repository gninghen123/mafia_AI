//
//  MiniChart.m
//  TradingApp
//
//  Lightweight chart view for grid display
//  REWRITTEN: Uses ONLY RuntimeModels, optimized direct drawing
//

#import "MiniChart.h"
#import "RuntimeModels.h"

@interface MiniChart ()

// UI Components - Only labels, no chart/volume subviews
@property (nonatomic, strong) NSTextField *symbolLabel;
@property (nonatomic, strong) NSTextField *priceLabel;
@property (nonatomic, strong) NSTextField *changeLabel;
@property (nonatomic, strong) NSTextField *aptrLabel;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// Chart drawing data
@property (nonatomic, assign) double minPrice;
@property (nonatomic, assign) double maxPrice;
@property (nonatomic, assign) double maxVolume;
@property (nonatomic, strong) NSBezierPath *chartPath;
@property (nonatomic, strong) NSBezierPath *volumePath;
@property (nonatomic, strong) NSTextField *descriptionLabel;
@end

@implementation MiniChart

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setupDefaults];
        [self setupUI];
        [self setupConstraints];
    }
    return self;
}

- (instancetype)init {
    return [self initWithFrame:NSMakeRect(0, 0, 300, 300)];
}

+ (instancetype)miniChartWithSymbol:(NSString *)symbol
                          chartType:(MiniChartType)chartType
                          timeframe:(MiniBarTimeframe)timeframe
                          scaleType:(MiniChartScaleType)scaleType
                            maxBars:(NSInteger)maxBars
                         showVolume:(BOOL)showVolume {
    
    MiniChart *chart = [[MiniChart alloc] init];
    chart.symbol = symbol;
    chart.chartType = chartType;
    chart.timeframe = timeframe;
    chart.scaleType = scaleType;
    chart.maxBars = maxBars;
    chart.showVolume = showVolume;
    return chart;
}

- (void)setupDefaults {
    // Default configuration
    _maxBars = 100;
    _showVolume = YES;
    _chartType = MiniChartTypeLine;
    _timeframe = MiniBarTimeframeDaily;
    _scaleType = MiniChartScaleLinear;
    
    // Default colors
    _positiveColor = [NSColor systemGreenColor];
    _negativeColor = [NSColor systemRedColor];
    _backgroundColor = [NSColor controlBackgroundColor];
    _textColor = [NSColor labelColor];
    
    // Default price range
    _minPrice = 0;
    _maxPrice = 100;
    _maxVolume = 1000000;
    
    // State
    _isLoading = NO;
    _hasError = NO;
    
    // Setup the view itself for drawing
    self.wantsLayer = YES;
    self.layer.backgroundColor = self.backgroundColor.CGColor;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.cornerRadius = 4.0;
}

- (void)setupUI {
   // self.wantsLayer = YES;
    self.layer.backgroundColor = self.backgroundColor.CGColor;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.cornerRadius = 4.0;
    
    // Symbol label (top left)
    self.symbolLabel = [[NSTextField alloc] init];
    self.symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolLabel.backgroundColor = [NSColor clearColor];
    self.symbolLabel.bordered = NO;
    self.symbolLabel.editable = NO;
    self.symbolLabel.font = [NSFont boldSystemFontOfSize:16];
    self.symbolLabel.textColor = self.textColor;
    self.symbolLabel.stringValue = self.symbol ?: @"";
    [self addSubview:self.symbolLabel];
    
    // Description label (NUOVO: sotto il simbolo, per nome modello)
    self.descriptionLabel = [[NSTextField alloc] init];
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.bordered = NO;
    self.descriptionLabel.editable = NO;
    self.descriptionLabel.font = [NSFont systemFontOfSize:12];
    self.descriptionLabel.textColor = [NSColor lightGrayColor];
    self.descriptionLabel.stringValue = @"";
    self.descriptionLabel.hidden = YES;  // Nascosto di default
    [self addSubview:self.descriptionLabel];
    
    // Price label (top right)
    self.priceLabel = [[NSTextField alloc] init];
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceLabel.backgroundColor = [NSColor clearColor];
    self.priceLabel.bordered = NO;
    self.priceLabel.editable = NO;
    self.priceLabel.font = [NSFont systemFontOfSize:14];
    self.priceLabel.textColor = self.textColor;
    self.priceLabel.alignment = NSTextAlignmentRight;
    self.priceLabel.stringValue = @"--";
    [self addSubview:self.priceLabel];
    
    // Change label (below price)
    self.changeLabel = [[NSTextField alloc] init];
    self.changeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.changeLabel.backgroundColor = [NSColor clearColor];
    self.changeLabel.bordered = NO;
    self.changeLabel.editable = NO;
    self.changeLabel.font = [NSFont systemFontOfSize:10];
    self.changeLabel.textColor = self.textColor;
    self.changeLabel.alignment = NSTextAlignmentRight;
    self.changeLabel.stringValue = @"+0.00%";
    [self addSubview:self.changeLabel];
    
    // APTR label (NUOVO: sotto il simbolo)
    self.aptrLabel = [[NSTextField alloc] init];
    self.aptrLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.aptrLabel.backgroundColor = [NSColor clearColor];
    self.aptrLabel.bordered = NO;
    self.aptrLabel.editable = NO;
    self.aptrLabel.font = [NSFont systemFontOfSize:10];
    self.aptrLabel.textColor = [NSColor secondaryLabelColor];
    self.aptrLabel.stringValue = @"APTR: --";
    [self addSubview:self.aptrLabel];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.hidden = YES;
    [self addSubview:self.loadingIndicator];
    
    NSLog(@"✅ MiniChart UI setup completed with APTR label");
}

- (void)setupConstraints {
    CGFloat padding = 4.0;
    CGFloat labelHeight = 16.0;
    
    // Symbol label (top left)
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:padding],
        [self.symbolLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
        [self.symbolLabel.heightAnchor constraintEqualToConstant:labelHeight]
    ]];
    // Description label (sotto il simbolo)
    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.symbolLabel.bottomAnchor],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
        [self.descriptionLabel.heightAnchor constraintEqualToConstant:12.0]
    ]];
    // APTR label (NUOVO: sotto il simbolo)
    [NSLayoutConstraint activateConstraints:@[
        [self.aptrLabel.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor],
        [self.aptrLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
        [self.aptrLabel.heightAnchor constraintEqualToConstant:12.0]
    ]];
    
    // Price label (top right)
    [NSLayoutConstraint activateConstraints:@[
        [self.priceLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:padding],
        [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
        [self.priceLabel.heightAnchor constraintEqualToConstant:labelHeight]
    ]];
    
    // Change label (below price)
    [NSLayoutConstraint activateConstraints:@[
        [self.changeLabel.topAnchor constraintEqualToAnchor:self.priceLabel.bottomAnchor],
        [self.changeLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
        [self.changeLabel.heightAnchor constraintEqualToConstant:12.0]
    ]];
    
    // Loading indicator (center)
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
    ]];
}
#pragma mark - Drawing Areas Calculation

- (CGRect)chartRect {
    CGFloat labelHeight = 30;
    CGFloat volumeHeight = self.showVolume ? 30 : 0;
    CGFloat padding = 8;
    
    return NSMakeRect(padding,
                     labelHeight,
                     self.bounds.size.width - 2*padding,
                     self.bounds.size.height - labelHeight - volumeHeight - 2*padding);
}

- (CGRect)volumeRect {
    if (!self.showVolume) return NSZeroRect;
    
    CGFloat volumeHeight = 30;
    CGFloat padding = 8;
    
    return NSMakeRect(padding,
                     padding,
                     self.bounds.size.width - 2*padding,
                     volumeHeight);
}

#pragma mark - Data Management

- (void)updateWithHistoricalBars:(NSArray<HistoricalBarModel *> *)bars {
    if (!bars || bars.count == 0) {
        [self setError:@"No data"];
        return;
    }
    
    // Clear any existing error
    [self clearError];
    
    // Store data
    self.priceData = bars;
    
    // Update current price from last bar
    HistoricalBarModel *lastBar = bars.lastObject;
    if (lastBar) {
        self.currentPrice = @(lastBar.close);
        
        // Calculate change from first to last
        HistoricalBarModel *firstBar = bars.firstObject;
        if (firstBar && bars.count > 1) {
            double change = lastBar.close - firstBar.close;
            double percentChange = (change / firstBar.close) * 100.0;
            self.priceChange = @(change);
            self.percentChange = @(percentChange);
        }
    }
    
    // Calculate ranges and generate paths
    [self calculatePriceRange];
    [self calculateVolumeRange];
    [self calculateAPTR];  // NUOVO: Calcola APTR quando si aggiornano i dati
    [self generateChartPath];
    [self generateVolumePath];
    
    // Update UI
    [self updateLabels];
    [self setNeedsDisplay:YES];
}

- (void)calculatePriceRange {
    if (!self.priceData || self.priceData.count == 0) return;
    
    double minPrice = INFINITY;
    double maxPrice = -INFINITY;
    
    for (HistoricalBarModel *bar in self.priceData) {
        double transformedLow = [self transformedPriceValue:bar.low];
        double transformedHigh = [self transformedPriceValue:bar.high];
        
        minPrice = MIN(minPrice, transformedLow);
        maxPrice = MAX(maxPrice, transformedHigh);
    }
    
    // Add 5% padding
    double range = maxPrice - minPrice;
    double padding = range * 0.05;
    
    self.minPrice = minPrice - padding;
    self.maxPrice = maxPrice + padding;
}

- (void)calculateVolumeRange {
    if (!self.priceData || self.priceData.count == 0) return;
    
    double maxVolume = 0;
    for (HistoricalBarModel *bar in self.priceData) {
        maxVolume = MAX(maxVolume, bar.volume);
    }
    
    self.maxVolume = maxVolume;
}

- (void)updateLabels {
    // Symbol label
    self.symbolLabel.stringValue = self.symbol ?: @"";
    
    // Price label
    if (self.currentPrice) {
        self.priceLabel.stringValue = [NSString stringWithFormat:@"$%.2f", [self.currentPrice doubleValue]];
    } else {
        self.priceLabel.stringValue = @"--";
    }
    
    // Change label
    if (self.percentChange && self.priceChange) {
        double change = [self.percentChange doubleValue];
        NSString *sign = change >= 0 ? @"+" : @"";
        self.changeLabel.stringValue = [NSString stringWithFormat:@"%@%.2f%%", sign, change];
        self.changeLabel.textColor = change >= 0 ? self.positiveColor : self.negativeColor;
    } else {
        self.changeLabel.stringValue = @"+0.00%";
        self.changeLabel.textColor = self.textColor;
    }
    
    // APTR label is updated by updateAPTRLabel method
    [self setNeedsDisplay:YES];
}

#pragma mark - Chart Path Generation

- (void)generateChartPath {
    if (!self.priceData || self.priceData.count == 0) {
        self.chartPath = nil;
        return;
    }
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    switch (self.chartType) {
        case MiniChartTypeLine:
            [self generateLineChartPath:path];
            break;
        case MiniChartTypeCandle:
            [self generateCandleChartPath:path];
            break;
        case MiniChartTypeBar:
            [self generateBarChartPath:path];
            break;
    }
    
    self.chartPath = path;
}

- (void)generateLineChartPath:(NSBezierPath *)path {
    CGRect rect = [self chartRect];
    if (CGRectIsEmpty(rect)) return;
    
    double yRange = self.maxPrice - self.minPrice;
    if (yRange <= 0) return;
    
    CGFloat xStep = rect.size.width / (CGFloat)self.priceData.count;
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBarModel *bar = self.priceData[i];
        
        CGFloat x = rect.origin.x + i * xStep + xStep * 0.5;
        CGFloat y = rect.origin.y + (([self transformedPriceValue:bar.close] - self.minPrice) / yRange) * rect.size.height;
        
        if (i == 0) {
            [path moveToPoint:NSMakePoint(x, y)];
        } else {
            [path lineToPoint:NSMakePoint(x, y)];
        }
    }
}

- (void)generateCandleChartPath:(NSBezierPath *)path {
    // For candle charts, we don't use a single path since each candle has different colors
    // The drawing is handled directly in drawCandleChart method
    // This method is kept for compatibility but does nothing for candles
}

- (void)generateBarChartPath:(NSBezierPath *)path {
    CGRect rect = [self chartRect];
    if (CGRectIsEmpty(rect)) return;
    
    double yRange = self.maxPrice - self.minPrice;
    if (yRange <= 0) return;
    
    CGFloat xStep = rect.size.width / (CGFloat)self.priceData.count;
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBarModel *bar = self.priceData[i];
        
        CGFloat x = rect.origin.x + i * xStep + xStep * 0.5;
        CGFloat highY = rect.origin.y + (([self transformedPriceValue:bar.high] - self.minPrice) / yRange) * rect.size.height;
        CGFloat lowY = rect.origin.y + (([self transformedPriceValue:bar.low] - self.minPrice) / yRange) * rect.size.height;
        CGFloat openY = rect.origin.y + (([self transformedPriceValue:bar.open] - self.minPrice) / yRange) * rect.size.height;
        CGFloat closeY = rect.origin.y + (([self transformedPriceValue:bar.close] - self.minPrice) / yRange) * rect.size.height;
        
        // Main line (high to low)
        [path moveToPoint:NSMakePoint(x, lowY)];
        [path lineToPoint:NSMakePoint(x, highY)];
        
        // Left tick for open
        [path moveToPoint:NSMakePoint(x - xStep * 0.2, openY)];
        [path lineToPoint:NSMakePoint(x, openY)];
        
        // Right tick for close
        [path moveToPoint:NSMakePoint(x, closeY)];
        [path lineToPoint:NSMakePoint(x + xStep * 0.2, closeY)];
    }
}

- (void)generateVolumePath {
    if (!self.priceData || self.priceData.count == 0 || !self.showVolume) {
        self.volumePath = nil;
        return;
    }

    NSBezierPath *path = [NSBezierPath bezierPath];
    CGRect chartRect = [self chartRect];   // <-- usa la stessa larghezza delle candele
    CGRect rect = [self volumeRect];
    if (CGRectIsEmpty(rect)) return;

    CGFloat xStep = chartRect.size.width / (CGFloat)self.priceData.count;
    CGFloat barWidth = xStep * 0.6; // come le candele

    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBarModel *bar = self.priceData[i];

        CGFloat x = chartRect.origin.x + i * xStep + xStep * 0.5;
        CGFloat height = (bar.volume / self.maxVolume) * rect.size.height;

        NSRect volumeRect = NSMakeRect(x - barWidth * 0.5, rect.origin.y, barWidth, height);
        [path appendBezierPathWithRect:volumeRect];
    }

    self.volumePath = path;
}

- (double)transformedPriceValue:(double)price {
    switch (self.scaleType) {
        case MiniChartScaleLinear:
            return price;
        case MiniChartScaleLog:
            return log(price);
        case MiniChartScalePercent: {
            if (self.priceData.count > 0) {
                HistoricalBarModel *firstBar = self.priceData.firstObject;
                return ((price - firstBar.close) / firstBar.close) * 100.0;
            }
            return 0;
        }
    }
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Clear background
    [self.backgroundColor setFill];
    NSRectFill(dirtyRect);
    
    // Draw chart if we have data
    if (self.chartPath && !self.isLoading && !self.hasError) {
        [self drawChart];
    }
    
    // Draw volume if enabled
    if (self.volumePath && self.showVolume && !self.isLoading && !self.hasError) {
        [self drawVolume];
    }
    
    // Draw loading or error state
    if (self.isLoading) {
        [self drawLoadingState];
    } else if (self.hasError) {
        [self drawErrorState];
    }
}

- (void)drawChart {
    if (!self.chartPath) return;
    
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    
    // Clip to chart area
    CGRect chartRect = [self chartRect];
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRect:chartRect];
    [clipPath addClip];
    
    if (self.chartType == MiniChartTypeCandle) {
        // For candle charts, draw each candle individually with correct colors
        [self drawCandleChart];
    } else {
        // For line and bar charts, use single color based on overall price change
        NSColor *strokeColor = self.textColor;
        if (self.priceChange) {
            double change = [self.priceChange doubleValue];
            strokeColor = change >= 0 ? self.positiveColor : self.negativeColor;
        }
        
        [strokeColor setStroke];
        self.chartPath.lineWidth = 2.0;
        [self.chartPath stroke];
    }
    
    [context restoreGraphicsState];
}

- (void)drawCandleChart {
    CGRect rect = [self chartRect];
    if (CGRectIsEmpty(rect)) return;
    
    double yRange = self.maxPrice - self.minPrice;
    if (yRange <= 0) return;
    
    CGFloat xStep = rect.size.width / (CGFloat)self.priceData.count;
    CGFloat candleWidth = xStep * 0.6;
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBarModel *bar = self.priceData[i];
        
        CGFloat x = rect.origin.x + i * xStep + xStep * 0.5;
        CGFloat highY = rect.origin.y + (([self transformedPriceValue:bar.high] - self.minPrice) / yRange) * rect.size.height;
        CGFloat lowY = rect.origin.y + (([self transformedPriceValue:bar.low] - self.minPrice) / yRange) * rect.size.height;
        CGFloat openY = rect.origin.y + (([self transformedPriceValue:bar.open] - self.minPrice) / yRange) * rect.size.height;
        CGFloat closeY = rect.origin.y + (([self transformedPriceValue:bar.close] - self.minPrice) / yRange) * rect.size.height;
        
        // Determine if bullish (green) or bearish (red)
        BOOL isBullish = bar.close >= bar.open;
        NSColor *candleColor = isBullish ? self.positiveColor : self.negativeColor;
        
        // Draw high-low line (wick)
        [candleColor setStroke];
        NSBezierPath *wickPath = [NSBezierPath bezierPath];
        wickPath.lineWidth = 1.0;
        [wickPath moveToPoint:NSMakePoint(x, lowY)];
        [wickPath lineToPoint:NSMakePoint(x, highY)];
        [wickPath stroke];
        
        // Draw candle body
        CGFloat bodyTop = MAX(openY, closeY);
        CGFloat bodyBottom = MIN(openY, closeY);
        CGFloat bodyHeight = bodyTop - bodyBottom;
        if (bodyHeight < 1) bodyHeight = 1; // Minimum height for doji
        
        NSRect bodyRect = NSMakeRect(x - candleWidth * 0.5, bodyBottom, candleWidth, bodyHeight);
        
        if (isBullish) {
            // Bullish candle: green border, white/hollow fill
            [self.positiveColor setStroke];
            [self.positiveColor setFill];
        } else {
            // Bearish candle: red border and fill
            [self.negativeColor setStroke];
            [self.negativeColor setFill];
        }
        
        NSBezierPath *bodyPath = [NSBezierPath bezierPathWithRect:bodyRect];
        bodyPath.lineWidth = 1.0;
        [bodyPath fill];
        [bodyPath stroke];
    }
}

- (void)drawVolume {
    if (!self.volumePath) return;
    
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    
    // Clip to volume area
    CGRect volumeRect = [self volumeRect];
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRect:volumeRect];
    [clipPath addClip];
    
    // Set volume color
    [[[NSColor systemBlueColor] colorWithAlphaComponent:0.6] setFill];
    [self.volumePath fill];
    
    [context restoreGraphicsState];
}

- (void)drawLoadingState {
    NSRect bounds = self.bounds;
    NSString *loadingText = @"Loading...";
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    NSSize textSize = [loadingText sizeWithAttributes:attributes];
    NSPoint textPoint = NSMakePoint(
        (bounds.size.width - textSize.width) / 2,
        (bounds.size.height - textSize.height) / 2
    );
    
    [loadingText drawAtPoint:textPoint withAttributes:attributes];
}

- (void)drawErrorState {
    NSRect bounds = self.bounds;
    NSString *errorText = self.errorMessage ?: @"Error";
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor systemRedColor]
    };
    
    NSSize textSize = [errorText sizeWithAttributes:attributes];
    NSPoint textPoint = NSMakePoint(
        (bounds.size.width - textSize.width) / 2,
        (bounds.size.height - textSize.height) / 2
    );
    
    [errorText drawAtPoint:textPoint withAttributes:attributes];
}

#pragma mark - Properties

- (void)setSymbol:(NSString *)symbol {
    _symbol = symbol;
    [self updateLabels];
}

- (void)setCurrentPrice:(NSNumber *)currentPrice {
    _currentPrice = currentPrice;
    [self updateLabels];
}

- (void)setPriceChange:(NSNumber *)priceChange {
    _priceChange = priceChange;
    [self updateLabels];
}

- (void)setPercentChange:(NSNumber *)percentChange {
    _percentChange = percentChange;
    [self updateLabels];
}

- (void)setChartType:(MiniChartType)chartType {
    _chartType = chartType;
    [self generateChartPath];
    [self setNeedsDisplay:YES];
}

- (void)setScaleType:(MiniChartScaleType)scaleType {
    _scaleType = scaleType;
    [self calculatePriceRange];
    [self generateChartPath];
    [self setNeedsDisplay:YES];
}

- (void)setShowVolume:(BOOL)showVolume {
    _showVolume = showVolume;
    [self generateVolumePath];
    [self setNeedsDisplay:YES];
}

#pragma mark - Loading State

- (void)setLoading:(BOOL)loading {
    _isLoading = loading;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loading) {
            self.loadingIndicator.hidden = NO;
            [self.loadingIndicator startAnimation:nil];
            self.aptrValue = nil;
                    [self updateAPTRLabel];
        } else {
            self.loadingIndicator.hidden = YES;
            [self.loadingIndicator stopAnimation:nil];
        }
        
        [self setNeedsDisplay:YES];
    });
}

- (void)setError:(NSString *)errorMessage {
    _hasError = (errorMessage != nil);
    _errorMessage = errorMessage;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (errorMessage) {
            self.priceLabel.stringValue = @"Error";
            // Clear APTR on error
              self.aptrValue = nil;
              [self updateAPTRLabel];
            self.changeLabel.stringValue = @"--";
            self.layer.borderColor = [NSColor systemRedColor].CGColor;
        } else {
            self.layer.borderColor = [NSColor separatorColor].CGColor;
        }
        
        [self setNeedsDisplay:YES];
    });
}

- (void)clearError {
    [self setError:nil];
}

#pragma mark - Actions



#pragma mark - Mouse Events


#pragma mark - Appearance Updates

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    
    // Update colors for dark/light mode
    self.backgroundColor = [NSColor controlBackgroundColor];
    self.textColor = [NSColor labelColor];
    self.layer.backgroundColor = self.backgroundColor.CGColor;
    
    // Update label colors
    self.symbolLabel.textColor = self.textColor;
    self.descriptionLabel.textColor = self.textColor;
    self.priceLabel.textColor = self.textColor;
    
    [self setNeedsDisplay:YES];
}

#pragma mark - DEPRECATED Methods (Remove these eventually)

// OLD METHOD - kept for backward compatibility
- (void)updateWithPriceData:(NSArray *)priceData {
    NSLog(@"⚠️ DEPRECATED: updateWithPriceData called on MiniChart[%@]. Use updateWithHistoricalBars: instead", self.symbol ?: @"nil");
    
    // For backward compatibility, attempt to convert if it's RuntimeModels
    if (priceData.count > 0 && [priceData.firstObject isKindOfClass:[HistoricalBarModel class]]) {
        [self updateWithHistoricalBars:(NSArray<HistoricalBarModel *> *)priceData];
    } else {
        NSLog(@"❌ Cannot convert priceData to HistoricalBarModel array");
        [self setError:@"Invalid data format"];
    }
}

- (void)calculateAPTR {
    if (!self.priceData || self.priceData.count < 10) {
        self.aptrValue = nil;
        self.aptrLabel.stringValue = @"APTR: --";
        return;
    }
    
    NSInteger startIndex = MAX(0, (NSInteger)self.priceData.count - 10);
    NSArray *last10Bars = [self.priceData subarrayWithRange:NSMakeRange(startIndex, MIN(10, self.priceData.count - startIndex))];
    
    double sum = 0.0;
    NSInteger validCount = 0;
    
    for (NSInteger i = 0; i < last10Bars.count; i++) {
        HistoricalBarModel *currentBar = last10Bars[i];
        HistoricalBarModel *previousBar = (i > 0) ? last10Bars[i-1] : nil;
        
        double bottom = previousBar ? MIN(previousBar.close, currentBar.low) : currentBar.low;
        double tr = currentBar.high - currentBar.low;
        if (previousBar) {
            tr = MAX(tr, fabs(currentBar.high - previousBar.close));
            tr = MAX(tr, fabs(currentBar.low - previousBar.close));
        }
        
        if (tr > 0 && bottom > 0) {
            double ptr = (tr / (bottom + tr / 2.0)) * 100.0;
            sum += ptr;
            validCount++;
        }
    }
    
    if (validCount > 0) {
        double aptr = sum / validCount;
        self.aptrValue = @(aptr);
        self.aptrLabel.stringValue = [NSString stringWithFormat:@"APTR: %.1f", aptr];
        
        if (aptr > 15.0) {
            self.aptrLabel.textColor = [NSColor redColor];
        } else if (aptr > 8.0) {
            self.aptrLabel.textColor = [NSColor orangeColor];
        } else {
            self.aptrLabel.textColor = [NSColor systemGreenColor];
        }
    } else {
        self.aptrValue = nil;
        self.aptrLabel.stringValue = @"APTR: --";
    }
}


- (double)calculateAPTRFromBars:(NSArray<HistoricalBarModel *> *)bars {
    if (!bars || bars.count < 10) {
        return NAN;
    }
    
    // Use last 10 bars for APTR calculation
    NSInteger startIndex = MAX(0, (NSInteger)bars.count - 10);
    NSArray<HistoricalBarModel *> *last10Bars = [bars subarrayWithRange:NSMakeRange(startIndex, MIN(10, bars.count - startIndex))];
    
    if (last10Bars.count < 2) {
        return NAN;
    }
    
    NSMutableArray<NSNumber *> *ptrValues = [NSMutableArray array];
    
    // Calculate PTR for each bar
    for (NSInteger i = 0; i < last10Bars.count; i++) {
        HistoricalBarModel *currentBar = last10Bars[i];
        HistoricalBarModel *previousBar = (i > 0) ? last10Bars[i-1] : nil;
        
        double ptr = [self calculatePTRForBar:currentBar previousBar:previousBar];
        if (!isnan(ptr) && !isinf(ptr)) {
            [ptrValues addObject:@(ptr)];
        }
    }
    
    if (ptrValues.count == 0) {
        return NAN;
    }
    
    // Calculate Simple Moving Average of PTR values (APTR)
    double sum = 0.0;
    for (NSNumber *value in ptrValues) {
        sum += [value doubleValue];
    }
    
    return sum / ptrValues.count;
}

- (double)calculatePTRForBar:(HistoricalBarModel *)currentBar previousBar:(HistoricalBarModel *)previousBar {
    // Formula from TOS:
    // def bottom = Min(close[1], low);
    // def tr = TrueRange(high, close, low);
    // def ptr = tr / (bottom + tr / 2) * 100;
    
    double bottom;
    if (previousBar) {
        bottom = MIN(previousBar.close, currentBar.low);
    } else {
        bottom = currentBar.low;  // For first bar, use current low
    }
    
    // Calculate True Range
    double tr = [self calculateTrueRange:currentBar previousBar:previousBar];
    
    if (tr <= 0 || bottom <= 0) {
        return NAN;
    }
    
    // PTR formula: tr / (bottom + tr / 2) * 100
    double denominator = bottom + (tr / 2.0);
    if (denominator <= 0) {
        return NAN;
    }
    
    return (tr / denominator) * 100.0;
}

- (double)calculateTrueRange:(HistoricalBarModel *)currentBar previousBar:(HistoricalBarModel *)previousBar {
    // True Range = max(high - low, |high - prevClose|, |low - prevClose|)
    
    double range1 = currentBar.high - currentBar.low;
    
    if (!previousBar) {
        return range1;  // For first bar, TR = high - low
    }
    
    double range2 = fabs(currentBar.high - previousBar.close);
    double range3 = fabs(currentBar.low - previousBar.close);
    
    return MAX(range1, MAX(range2, range3));
}

- (void)updateAPTRLabel {
    if (self.aptrValue) {
        self.aptrLabel.stringValue = [NSString stringWithFormat:@"APTR: %.1f", [self.aptrValue doubleValue]];
        
        // Color coding based on APTR value
        double aptr = [self.aptrValue doubleValue];
        if (aptr < 3.0) {
            self.aptrLabel.textColor = [NSColor orangeColor];        // < 3 = Arancione
        } else if (aptr >= 3.0 && aptr <= 6.0) {
            self.aptrLabel.textColor = [NSColor systemGreenColor];   // 3-6 = Verde
        } else {
            self.aptrLabel.textColor = [NSColor cyanColor];          // > 6 = Cyan
        }
    } else {
        self.aptrLabel.stringValue = @"APTR: --";
        self.aptrLabel.textColor = [NSColor secondaryLabelColor];
    }
}

@end
