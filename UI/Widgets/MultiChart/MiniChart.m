//
//  MiniChart.m
//  TradingApp
//
//  Lightweight chart view for grid display
//  REWRITTEN: Uses ONLY RuntimeModels, optimized direct drawing
//  UPDATED: Added intraday reference lines support
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
- (instancetype)initWithFrame:(NSRect)frameRect showReferenceLines:(BOOL)showRefLines{
    self =    self = [self initWithFrame:frameRect];
    if (self) {
        self.showReferenceLines = showRefLines;
    }
    return self;
}
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
                         showVolume:(BOOL)showVolume
                 showReferenceLines:(BOOL)showRefLines{
    
    MiniChart *chart = [[MiniChart alloc] init];
    chart.symbol = symbol;
    chart.chartType = chartType;
    chart.timeframe = timeframe;
    chart.scaleType = scaleType;
    chart.maxBars = maxBars;
    chart.showVolume = showVolume;
    chart.showReferenceLines=showRefLines;
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
    if (!self.showVolume) return CGRectZero;
    
    CGFloat labelHeight = 30;
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
        NSLog(@"⚠️ MiniChart[%@]: No bars to update", self.symbol ?: @"nil");
        self.priceData = nil;
        [self setError:@"No data"];
        return;
    }
    
    self.priceData = bars;
    [self clearError];
    [self setLoading:NO];
    
    // Calculate price range and volume
    [self calculatePriceRange];
    [self calculateVolumeRange];
    
    // Generate chart paths
    [self generateChartPath];
    [self generateVolumePath];
    
    // Update price labels
    [self updatePriceLabels];
    
    // Calculate APTR
    [self calculateAPTR];
    
    [self setNeedsDisplay:YES];
    
    NSLog(@"📊 MiniChart[%@]: Updated with %lu bars", self.symbol ?: @"nil", (unsigned long)bars.count);
}

- (void)calculatePriceRange {
    if (!self.priceData || self.priceData.count == 0) {
        self.minPrice = 0;
        self.maxPrice = 100;
        return;
    }
    
    double minVal = INFINITY;
    double maxVal = -INFINITY;
    
    for (HistoricalBarModel *bar in self.priceData) {
        minVal = MIN(minVal, [self transformedPriceValue:bar.low]);
        maxVal = MAX(maxVal, [self transformedPriceValue:bar.high]);
    }
    
    // Add 5% padding
    double range = maxVal - minVal;
    double padding = range * 0.05;
    
    self.minPrice = minVal - padding;
    self.maxPrice = maxVal + padding;
}

- (void)calculateVolumeRange {
    if (!self.priceData || self.priceData.count == 0) {
        self.maxVolume = 1000000;
        return;
    }
    
    long long maxVol = 0;
    for (HistoricalBarModel *bar in self.priceData) {
        maxVol = MAX(maxVol, bar.volume);
    }
    
    self.maxVolume = maxVol > 0 ? maxVol : 1000000;
}

- (void)updatePriceLabels {
    if (!self.priceData || self.priceData.count == 0) return;
    
    HistoricalBarModel *lastBar = self.priceData.lastObject;
    
    if (self.currentPrice) {
        self.priceLabel.stringValue = [NSString stringWithFormat:@"$%.2f", [self.currentPrice doubleValue]];
    } else {
        self.priceLabel.stringValue = [NSString stringWithFormat:@"$%.2f", lastBar.close];
    }
    
    if (self.percentChange) {
        double percent = [self.percentChange doubleValue];
        self.changeLabel.stringValue = [NSString stringWithFormat:@"%+.2f%%", percent];
        self.changeLabel.textColor = percent >= 0 ? self.positiveColor : self.negativeColor;
    }
}

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
        
        // ✅ NUOVO: Disegna linee di riferimento intraday DOPO le candele (solo se attivato)
        if (self.showReferenceLines) {
            [self drawIntradayReferenceLines];
        }
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
    NSString *message = @"Loading...";
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    NSSize textSize = [message sizeWithAttributes:attributes];
    NSPoint drawPoint = NSMakePoint((bounds.size.width - textSize.width) / 2,
                                   (bounds.size.height - textSize.height) / 2);
    
    [message drawAtPoint:drawPoint withAttributes:attributes];
}

- (void)drawErrorState {
    NSRect bounds = self.bounds;
    NSString *message = self.errorMessage ?: @"Error";
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor systemRedColor]
    };
    
    NSSize textSize = [message sizeWithAttributes:attributes];
    NSPoint drawPoint = NSMakePoint((bounds.size.width - textSize.width) / 2,
                                   (bounds.size.height - textSize.height) / 2);
    
    [message drawAtPoint:drawPoint withAttributes:attributes];
}

#pragma mark - UI State

- (void)setLoading:(BOOL)loading {
    _isLoading = loading;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loading) {
            self.loadingIndicator.hidden = NO;
            [self.loadingIndicator startAnimation:nil];
            // Clear APTR when loading
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

#pragma mark - Intraday Reference Lines

/**
 Verifica se il timeframe corrente è intraday (< Daily)
 */
- (BOOL)isIntradayTimeframe {
    return (self.timeframe < MiniBarTimeframeDaily);
}

/**
 Identifica la sessione di trading basandosi sull'orario ET
 @param components Componenti date/ora in timezone ET
 @return Tipo di sessione: 0=premarket, 1=regular, 2=afterhours
 */
- (NSInteger)identifyTradingSession:(NSDateComponents *)components {
    NSInteger hour = components.hour;
    NSInteger minute = components.minute;
    NSInteger totalMinutes = hour * 60 + minute;
    
    // Premarket: 4:00-9:30 (240-570 minuti)
    if (totalMinutes >= 240 && totalMinutes < 570) {
        return 0; // Premarket
    }
    // Regular session: 9:30-16:00 (570-960 minuti)
    else if (totalMinutes >= 570 && totalMinutes < 960) {
        return 1; // Regular
    }
    // After-hours: 16:00-23:59 O 0:00-4:00 (960-1440 minuti O 0-240 minuti)
    else if (totalMinutes >= 960 || totalMinutes < 240) {
        return 2; // Afterhours
    }
    
    return -1; // Should not happen
}

/**
 Trova l'inizio dell'ultimo giorno di trading completo (ieri)
 @param currentDate Data corrente
 @return Data dell'inizio dell'ultimo giorno di trading
 */
- (NSDate *)findPreviousTradingDay:(NSDate *)currentDate {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    
    NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday) fromDate:currentDate];
    
    // Sottrai 1 giorno
    components.day -= 1;
    
    // Se è weekend, torna indietro fino a venerdì
    if (components.weekday == 1) { // Domenica
        components.day -= 2;
    } else if (components.weekday == 7) { // Sabato
        components.day -= 1;
    }
    
    // Azzera ore per avere inizio giornata
    components.hour = 0;
    components.minute = 0;
    components.second = 0;
    
    return [calendar dateFromComponents:components];
}

/**
 Calcola i valori delle linee di riferimento intraday (ottimizzato: solo ultimi due giorni, ciclo interrotto appena trovati tutti)
 @return Dizionario con i valori delle linee, o nil se non applicabile
 */
- (NSDictionary *)calculateIntradayReferenceValues {
    // Verifica che sia timeframe intraday
    if (![self isIntradayTimeframe]) {
        return nil;
    }

    // Verifica dati disponibili
    if (!self.priceData || self.priceData.count == 0) {
        return nil;
    }

    NSCalendar *calendar = [NSCalendar currentCalendar];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];

    // Ottieni data più recente
    HistoricalBarModel *lastBar = self.priceData.lastObject;
    NSDate *mostRecentDate = lastBar.date;
    NSDateComponents *currentComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                                                      fromDate:mostRecentDate];

    // Trova l'inizio dell'ultimo giorno di trading completo
    NSDate *previousTradingDay = [self findPreviousTradingDay:mostRecentDate];
    NSDate *threeDaysAgo = [mostRecentDate dateByAddingTimeInterval:-3 * 24 * 60 * 60];
    NSDateComponents *previousComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                                                       fromDate:previousTradingDay];

    NSMutableDictionary *values = [NSMutableDictionary dictionary];

    BOOL foundOpenToday = NO;
    double highPremarket = -INFINITY;
    double lowPremarket = INFINITY;
    double highAfterPrevious = -INFINITY;
    double lowAfterPrevious = INFINITY;
    double highRegularPrevious = -INFINITY;
    double lowRegularPrevious = INFINITY;

    // ✅ Limita la scansione agli ultimi 3 giorni per garantire la presenza del giorno precedente completo
    NSMutableArray<HistoricalBarModel *> *recentBars = [NSMutableArray array];
    for (HistoricalBarModel *bar in self.priceData) {
        if (!bar.date) continue;
        if ([bar.date compare:threeDaysAgo] == NSOrderedDescending) {
            [recentBars addObject:bar];
        }
    }

    // ✅ Scorri solo le barre più recenti
    for (HistoricalBarModel *bar in recentBars) {
        NSDateComponents *barComponents = [calendar components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute)
                                                      fromDate:bar.date];
        NSInteger session = [self identifyTradingSession:barComponents];

        BOOL isToday = (barComponents.year == currentComponents.year &&
                        barComponents.month == currentComponents.month &&
                        barComponents.day == currentComponents.day);
        BOOL isPreviousDay = (barComponents.year == previousComponents.year &&
                              barComponents.month == previousComponents.month &&
                              barComponents.day == previousComponents.day);

        if (isToday) {
            if (session == 1 && !foundOpenToday) {
                values[@"openToday"] = @(bar.open);
                foundOpenToday = YES;
            } else if (session == 0) {
                highPremarket = MAX(highPremarket, bar.high);
                lowPremarket = MIN(lowPremarket, bar.low);
            }
        } else if (isPreviousDay) {
            if (session == 2) {
                highAfterPrevious = MAX(highAfterPrevious, bar.high);
                lowAfterPrevious = MIN(lowAfterPrevious, bar.low);
            } else if (session == 1) {
                highRegularPrevious = MAX(highRegularPrevious, bar.high);
                lowRegularPrevious = MIN(lowRegularPrevious, bar.low);
            }
        }

        // ✅ Interrompi se tutti i valori sono stati trovati
        if (foundOpenToday &&
            highPremarket != -INFINITY && lowPremarket != INFINITY &&
            highAfterPrevious != -INFINITY && lowAfterPrevious != INFINITY &&
            highRegularPrevious != -INFINITY && lowRegularPrevious != INFINITY) {
            break;
        }
    }

    // Salva i valori trovati
    if (highPremarket != -INFINITY) values[@"highPremarketToday"] = @(highPremarket);
    if (lowPremarket != INFINITY) values[@"lowPremarketToday"] = @(lowPremarket);
    if (highAfterPrevious != -INFINITY) values[@"highAfterhoursPrevious"] = @(highAfterPrevious);
    if (lowAfterPrevious != INFINITY) values[@"lowAfterhoursPrevious"] = @(lowAfterPrevious);
    if (highRegularPrevious != -INFINITY) values[@"highRegularPrevious"] = @(highRegularPrevious);
    if (lowRegularPrevious != INFINITY) values[@"lowRegularPrevious"] = @(lowRegularPrevious);

    NSLog(@"📊 MiniChart[%@]: Calculated %lu optimized intraday reference values: %@",
          self.symbol ?: @"nil", (unsigned long)values.count, values);
    NSLog(@"🟩 RegularPrev High=%.2f, Low=%.2f", highRegularPrevious, lowRegularPrevious);
    return values.count > 0 ? values : nil;
}

/**
 Disegna le linee di riferimento intraday nel grafico
 */
- (void)drawIntradayReferenceLines {
    // ✅ OTTIMIZZAZIONE: Calcola solo se necessario
    if (!self.showReferenceLines) return;
    
    NSDictionary *referenceValues = [self calculateIntradayReferenceValues];
    if (!referenceValues) return;
    
    CGRect rect = [self chartRect];
    if (CGRectIsEmpty(rect)) return;
    
    double yRange = self.maxPrice - self.minPrice;
    if (yRange <= 0) return;
    
    CGFloat leftX = rect.origin.x;
    CGFloat rightX = rect.origin.x + rect.size.width;
    
    // Helper per calcolare Y
    CGFloat (^calculateY)(double) = ^CGFloat(double price) {
        return rect.origin.y + (([self transformedPriceValue:price] - self.minPrice) / yRange) * rect.size.height;
    };
    
    // 1. OPEN OGGI - Giallo continuo, alpha 0.6
    NSNumber *openToday = referenceValues[@"openToday"];
    if (openToday) {
        CGFloat y = calculateY([openToday doubleValue]);
        [[NSColor.systemYellowColor colorWithAlphaComponent:0.6] setStroke];
        NSBezierPath *path = [NSBezierPath bezierPath];
        path.lineWidth = 1.5;
        [path moveToPoint:NSMakePoint(leftX, y)];
        [path lineToPoint:NSMakePoint(rightX, y)];
        [path stroke];
    }
    
    // 2. HIGH/LOW PREMARKET OGGI - Arancione tratteggiato, alpha 0.3
    NSNumber *highPremarket = referenceValues[@"highPremarketToday"];
    NSNumber *lowPremarket = referenceValues[@"lowPremarketToday"];
    if (highPremarket || lowPremarket) {
        [[NSColor.systemOrangeColor colorWithAlphaComponent:0.3] setStroke];
        CGFloat dashPattern[] = {4.0, 4.0};
        
        if (highPremarket) {
            CGFloat y = calculateY([highPremarket doubleValue]);
            NSBezierPath *path = [NSBezierPath bezierPath];
            path.lineWidth = 1.0;
            [path setLineDash:dashPattern count:2 phase:0];
            [path moveToPoint:NSMakePoint(leftX, y)];
            [path lineToPoint:NSMakePoint(rightX, y)];
            [path stroke];
        }
        
        if (lowPremarket) {
            CGFloat y = calculateY([lowPremarket doubleValue]);
            NSBezierPath *path = [NSBezierPath bezierPath];
            path.lineWidth = 1.0;
            [path setLineDash:dashPattern count:2 phase:0];
            [path moveToPoint:NSMakePoint(leftX, y)];
            [path lineToPoint:NSMakePoint(rightX, y)];
            [path stroke];
        }
    }
    
    // 3. HIGH/LOW AFTERHOURS IERI - Blu tratteggiato, alpha 0.3
    NSNumber *highAfter = referenceValues[@"highAfterhoursPrevious"];
    NSNumber *lowAfter = referenceValues[@"lowAfterhoursPrevious"];
    if (highAfter || lowAfter) {
        [[NSColor.systemBlueColor colorWithAlphaComponent:0.3] setStroke];
        CGFloat dashPattern[] = {4.0, 4.0};
        
        if (highAfter) {
            CGFloat y = calculateY([highAfter doubleValue]);
            NSBezierPath *path = [NSBezierPath bezierPath];
            path.lineWidth = 1.0;
            [path setLineDash:dashPattern count:2 phase:0];
            [path moveToPoint:NSMakePoint(leftX, y)];
            [path lineToPoint:NSMakePoint(rightX, y)];
            [path stroke];
        }
        
        if (lowAfter) {
            CGFloat y = calculateY([lowAfter doubleValue]);
            NSBezierPath *path = [NSBezierPath bezierPath];
            path.lineWidth = 1.0;
            [path setLineDash:dashPattern count:2 phase:0];
            [path moveToPoint:NSMakePoint(leftX, y)];
            [path lineToPoint:NSMakePoint(rightX, y)];
            [path stroke];
        }
    }
    
    // 4. HIGH REGULAR SESSION IERI - Verde continuo, alpha 0.6
    NSNumber *highRegular = referenceValues[@"highRegularPrevious"];
    if (highRegular) {
        CGFloat y = calculateY([highRegular doubleValue]);
        [[NSColor.systemGreenColor colorWithAlphaComponent:0.6] setStroke];
        NSBezierPath *path = [NSBezierPath bezierPath];
        path.lineWidth = 1.5;
        [path moveToPoint:NSMakePoint(leftX, y)];
        [path lineToPoint:NSMakePoint(rightX, y)];
        [path stroke];
    }
    
    // 5. LOW REGULAR SESSION IERI - Rosso continuo, alpha 0.6
    NSNumber *lowRegular = referenceValues[@"lowRegularPrevious"];
    if (lowRegular) {
        CGFloat y = calculateY([lowRegular doubleValue]);
        [[NSColor.systemRedColor colorWithAlphaComponent:0.6] setStroke];
        NSBezierPath *path = [NSBezierPath bezierPath];
        path.lineWidth = 1.5;
        [path moveToPoint:NSMakePoint(leftX, y)];
        [path lineToPoint:NSMakePoint(rightX, y)];
        [path stroke];
    }
}
- (void)setSymbol:(NSString *)symbol {
    _symbol = symbol;

    if (self.symbolLabel) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.symbolLabel.stringValue = symbol ?: @"";
        });
    }
}
@end
