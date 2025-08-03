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
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// Chart drawing data
@property (nonatomic, assign) double minPrice;
@property (nonatomic, assign) double maxPrice;
@property (nonatomic, assign) double maxVolume;
@property (nonatomic, strong) NSBezierPath *chartPath;
@property (nonatomic, strong) NSBezierPath *volumePath;

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
    return [self initWithFrame:NSMakeRect(0, 0, 300, 200)];
}

+ (instancetype)miniChartWithSymbol:(NSString *)symbol
                          chartType:(MiniChartType)chartType
                          timeframe:(MiniChartTimeframe)timeframe
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
    _timeframe = MiniChartTimeframeDaily;
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
    // Symbol label (top left)
    self.symbolLabel = [[NSTextField alloc] init];
    self.symbolLabel.editable = NO;
    self.symbolLabel.bordered = NO;
    self.symbolLabel.backgroundColor = [NSColor clearColor];
    self.symbolLabel.font = [NSFont boldSystemFontOfSize:14];
    self.symbolLabel.textColor = self.textColor;
    self.symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.symbolLabel];
    
    // Price label (top right)
    self.priceLabel = [[NSTextField alloc] init];
    self.priceLabel.editable = NO;
    self.priceLabel.bordered = NO;
    self.priceLabel.backgroundColor = [NSColor clearColor];
    self.priceLabel.font = [NSFont systemFontOfSize:12];
    self.priceLabel.textColor = self.textColor;
    self.priceLabel.alignment = NSTextAlignmentRight;
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.priceLabel];
    
    // Change label (below price, right aligned)
    self.changeLabel = [[NSTextField alloc] init];
    self.changeLabel.editable = NO;
    self.changeLabel.bordered = NO;
    self.changeLabel.backgroundColor = [NSColor clearColor];
    self.changeLabel.font = [NSFont systemFontOfSize:10];
    self.changeLabel.textColor = self.textColor;
    self.changeLabel.alignment = NSTextAlignmentRight;
    self.changeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.changeLabel];
    
    // Loading indicator (center)
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.hidden = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.loadingIndicator];
}

- (void)setupConstraints {
    CGFloat padding = 8;
    CGFloat labelHeight = 20;
    
    // Symbol label (top left)
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:padding],
        [self.symbolLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
        [self.symbolLabel.heightAnchor constraintEqualToConstant:labelHeight]
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
        [self.changeLabel.heightAnchor constraintEqualToConstant:labelHeight]
    ]];
    
    // Loading indicator (center)
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
    ]];
}

#pragma mark - Drawing Areas Calculation

- (CGRect)chartRect {
    CGFloat labelHeight = 40; // spazio per i label in alto
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
    CGRect rect = [self volumeRect];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat xStep = rect.size.width / (CGFloat)self.priceData.count;
    CGFloat barWidth = xStep * 0.8;
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBarModel *bar = self.priceData[i];
        
        CGFloat x = rect.origin.x + i * xStep + xStep * 0.5;
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
            [[NSColor controlBackgroundColor] setFill];
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

- (void)refresh {
    // The actual data loading is handled by the parent MultiChartWidget
}

#pragma mark - Mouse Events

- (void)mouseDown:(NSEvent *)event {
    // Could show detailed chart popup here
}

#pragma mark - Appearance Updates

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    
    // Update colors for dark/light mode
    self.backgroundColor = [NSColor controlBackgroundColor];
    self.textColor = [NSColor labelColor];
    self.layer.backgroundColor = self.backgroundColor.CGColor;
    
    // Update label colors
    self.symbolLabel.textColor = self.textColor;
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

@end
