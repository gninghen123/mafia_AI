//
//  MiniChart.m
//  TradingApp
//
//  Lightweight chart view for grid display
//  REWRITTEN: Uses ONLY RuntimeModels, removed all Core Data dependencies
//

#import "MiniChart.h"
#import "RuntimeModels.h"

@interface MiniChart ()

// UI Components
@property (nonatomic, strong) NSTextField *symbolLabel;
@property (nonatomic, strong) NSTextField *priceLabel;
@property (nonatomic, strong) NSTextField *changeLabel;
@property (nonatomic, strong) NSView *chartArea;
@property (nonatomic, strong) NSView *volumeArea;
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
    
    // Border
    self.wantsLayer = YES;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.cornerRadius = 4.0;
}

- (void)setupUI {
    // Symbol label
    self.symbolLabel = [[NSTextField alloc] init];
    self.symbolLabel.editable = NO;
    self.symbolLabel.bordered = NO;
    self.symbolLabel.backgroundColor = [NSColor clearColor];
    self.symbolLabel.font = [NSFont boldSystemFontOfSize:14];
    self.symbolLabel.textColor = self.textColor;
    self.symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.symbolLabel];
    
    // Price label
    self.priceLabel = [[NSTextField alloc] init];
    self.priceLabel.editable = NO;
    self.priceLabel.bordered = NO;
    self.priceLabel.backgroundColor = [NSColor clearColor];
    self.priceLabel.font = [NSFont systemFontOfSize:12];
    self.priceLabel.textColor = self.textColor;
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.priceLabel];
    
    // Change label
    self.changeLabel = [[NSTextField alloc] init];
    self.changeLabel.editable = NO;
    self.changeLabel.bordered = NO;
    self.changeLabel.backgroundColor = [NSColor clearColor];
    self.changeLabel.font = [NSFont systemFontOfSize:10];
    self.changeLabel.textColor = self.textColor;
    self.changeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.changeLabel];
    
    // Chart area
    self.chartArea = [[NSView alloc] init];
    self.chartArea.wantsLayer = YES;
    self.chartArea.layer.backgroundColor = self.backgroundColor.CGColor;
    self.chartArea.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.chartArea];
    
    // Volume area
    self.volumeArea = [[NSView alloc] init];
    self.volumeArea.wantsLayer = YES;
    self.volumeArea.layer.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.1].CGColor;
    self.volumeArea.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.volumeArea];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.hidden = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.loadingIndicator];
}

- (void)setupConstraints {
    CGFloat padding = 8;
    CGFloat labelHeight = 20;
    CGFloat volumeHeight = 30;
    
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
    
    // Volume area (bottom)
    [NSLayoutConstraint activateConstraints:@[
        [self.volumeArea.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
        [self.volumeArea.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
        [self.volumeArea.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-padding],
        [self.volumeArea.heightAnchor constraintEqualToConstant:volumeHeight]
    ]];
    
    // Chart area (middle)
    [NSLayoutConstraint activateConstraints:@[
        [self.chartArea.topAnchor constraintEqualToAnchor:self.symbolLabel.bottomAnchor constant:padding],
        [self.chartArea.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
        [self.chartArea.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
        [self.chartArea.bottomAnchor constraintEqualToAnchor:self.volumeArea.topAnchor constant:-padding]
    ]];
    
    // Loading indicator (center)
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
    ]];
}

#pragma mark - Data Management (NEW - RuntimeModels ONLY)

- (void)updateWithHistoricalBars:(NSArray<HistoricalBarModel *> *)bars {
    if (!bars || bars.count == 0) {
        NSLog(@"⚠️ MiniChart[%@]: No bars to update", self.symbol ?: @"nil");
        return;
    }
    
    NSLog(@"📊 MiniChart[%@]: Updating with %lu bars", self.symbol ?: @"nil", (unsigned long)bars.count);
    
    // Limit bars if necessary
    if (bars.count > self.maxBars) {
        NSInteger startIndex = bars.count - self.maxBars;
        self.priceData = [bars subarrayWithRange:NSMakeRange(startIndex, self.maxBars)];
    } else {
        self.priceData = bars;
    }
    
    [self calculatePriceRange];
    [self calculateVolumeRange];
    [self generateChartPath];
    [self generateVolumePath];
    [self updatePriceLabelsFromBars];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
    });
}

- (void)calculatePriceRange {
    if (!self.priceData || self.priceData.count == 0) {
        self.minPrice = 0;
        self.maxPrice = 100;
        return;
    }
    
    self.minPrice = CGFLOAT_MAX;
    self.maxPrice = CGFLOAT_MIN;
    
    for (HistoricalBarModel *bar in self.priceData) {
        double low = bar.low;
        double high = bar.high;
        
        if (low < self.minPrice) self.minPrice = low;
        if (high > self.maxPrice) self.maxPrice = high;
    }
    
    // Add some padding
    double range = self.maxPrice - self.minPrice;
    double padding = range * 0.05; // 5% padding
    self.minPrice -= padding;
    self.maxPrice += padding;
}

- (void)calculateVolumeRange {
    if (!self.priceData || self.priceData.count == 0) {
        self.maxVolume = 1000000; // Default
        return;
    }
    
    self.maxVolume = 0;
    for (HistoricalBarModel *bar in self.priceData) {
        if (bar.volume > self.maxVolume) {
            self.maxVolume = bar.volume;
        }
    }
}

- (void)updatePriceLabelsFromBars {
    if (!self.priceData || self.priceData.count == 0) return;
    
    HistoricalBarModel *lastBar = self.priceData.lastObject;
    HistoricalBarModel *firstBar = self.priceData.firstObject;
    
    if (lastBar) {
        // Update current price from last bar
        if (!self.currentPrice) {
            self.currentPrice = @(lastBar.close);
        }
        
        // Calculate change from first to last bar if needed
        if (firstBar && lastBar && !self.priceChange) {
            double closePrice = lastBar.close;
            double openPrice = firstBar.close;
            double priceChange = closePrice - openPrice;
            double percentChange = (priceChange / openPrice) * 100.0;
            
            self.priceChange = @(priceChange);
            self.percentChange = @(percentChange);
        }
    }
    
    [self updateLabels];
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
    NSRect rect = self.chartArea.bounds;
    if (NSIsEmptyRect(rect)) return;
    
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
    NSRect rect = self.chartArea.bounds;
    if (NSIsEmptyRect(rect)) return;
    
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
        
        // High-low line
        [path moveToPoint:NSMakePoint(x, lowY)];
        [path lineToPoint:NSMakePoint(x, highY)];
        
        // Body
        CGFloat bodyTop = MAX(openY, closeY);
        CGFloat bodyBottom = MIN(openY, closeY);
        NSRect bodyRect = NSMakeRect(x - candleWidth * 0.5, bodyBottom, candleWidth, bodyTop - bodyBottom);
        [path appendBezierPathWithRect:bodyRect];
    }
}

- (void)generateBarChartPath:(NSBezierPath *)path {
    NSRect rect = self.chartArea.bounds;
    if (NSIsEmptyRect(rect)) return;
    
    double yRange = self.maxPrice - self.minPrice;
    if (yRange <= 0) return;
    
    CGFloat xStep = rect.size.width / (CGFloat)self.priceData.count;
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBarModel *bar = self.priceData[i];
        
        CGFloat x = rect.origin.x + i * xStep + xStep * 0.5;
        CGFloat highY = rect.origin.y + (([self transformedPriceValue:bar.high] - self.minPrice) / yRange) * rect.size.height;
        CGFloat lowY = rect.origin.y + (([self transformedPriceValue:bar.low] - self.minPrice) / yRange) * rect.size.height;
        
        // Main line (high to low)
        [path moveToPoint:NSMakePoint(x, lowY)];
        [path lineToPoint:NSMakePoint(x, highY)];
        
        // Left tick for open
        CGFloat openY = rect.origin.y + (([self transformedPriceValue:bar.open] - self.minPrice) / yRange) * rect.size.height;
        [path moveToPoint:NSMakePoint(x - xStep * 0.2, openY)];
        [path lineToPoint:NSMakePoint(x, openY)];
        
        // Right tick for close
        CGFloat closeY = rect.origin.y + (([self transformedPriceValue:bar.close] - self.minPrice) / yRange) * rect.size.height;
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
    NSRect rect = self.volumeArea.bounds;
    if (NSIsEmptyRect(rect)) return;
    
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
    NSRect chartRect = [self convertRect:self.chartArea.bounds fromView:self.chartArea];
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRect:chartRect];
    [clipPath addClip];
    
    // Set stroke color based on price change
    NSColor *strokeColor = self.textColor;
    if (self.priceChange) {
        double change = [self.priceChange doubleValue];
        strokeColor = change >= 0 ? self.positiveColor : self.negativeColor;
    }
    
    [strokeColor setStroke];
    self.chartPath.lineWidth = 1.5;
    [self.chartPath stroke];
    
    // Fill for candle charts
    if (self.chartType == MiniChartTypeCandle) {
        for (NSInteger i = 0; i < self.priceData.count; i++) {
            HistoricalBarModel *bar = self.priceData[i];
            NSColor *fillColor = (bar.close >= bar.open) ? self.positiveColor : self.negativeColor;
            [fillColor setFill];
        }
    }
    
    [context restoreGraphicsState];
}

- (void)drawVolume {
    if (!self.volumePath) return;
    
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    
    // Clip to volume area
    NSRect volumeRect = [self convertRect:self.volumeArea.bounds fromView:self.volumeArea];
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRect:volumeRect];
    [clipPath addClip];
    
    // Set fill color with transparency
    NSColor *volumeColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.3];
    [volumeColor setFill];
    [self.volumePath fill];
    
    [context restoreGraphicsState];
}

- (void)drawLoadingState {
    NSRect bounds = self.bounds;
    
    // Semi-transparent overlay
    [[NSColor colorWithWhite:0.5 alpha:0.5] setFill];
    NSRectFillUsingOperation(bounds, NSCompositingOperationSourceOver);
    
    // Loading text
    NSString *loadingText = @"Loading...";
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14],
        NSForegroundColorAttributeName: self.textColor
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
    
    // Error background
    [[[NSColor systemRedColor] colorWithAlphaComponent:0.1] setFill];
    NSRectFill(bounds);
    
    // Error text
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
    self.volumeArea.hidden = !showVolume;
    [self updateConstraintsIfNeeded];
    [self setNeedsDisplay:YES];
}

- (void)updateConstraintsIfNeeded {
    // Remove existing constraints for chart and volume area
    NSArray *constraintsToRemove = [self.constraints filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSLayoutConstraint *constraint, NSDictionary *bindings) {
        return (constraint.firstItem == self.chartArea ||
                constraint.firstItem == self.volumeArea ||
                constraint.secondItem == self.chartArea ||
                constraint.secondItem == self.volumeArea);
    }]];
    
    [NSLayoutConstraint deactivateConstraints:constraintsToRemove];
    
    // Recreate constraints
    [self setupConstraints];
}

#pragma mark - Loading State

- (void)setLoading:(BOOL)loading {
    _isLoading = loading;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loading) {
            self.loadingIndicator.hidden = NO;
            [self.loadingIndicator startAnimation:nil];
            self.chartArea.hidden = YES;
            self.volumeArea.hidden = YES;
        } else {
            self.loadingIndicator.hidden = YES;
            [self.loadingIndicator stopAnimation:nil];
            self.chartArea.hidden = NO;
            self.volumeArea.hidden = !self.showVolume;
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
    // This method can be called to refresh data
    // The actual data loading is handled by the parent MultiChartWidget
    NSLog(@"🔄 MiniChart[%@]: Refresh requested", self.symbol ?: @"nil");
}

#pragma mark - Mouse Events

- (void)mouseDown:(NSEvent *)event {
    // Handle click events - could show detailed chart
    NSLog(@"🖱️ MiniChart[%@]: Mouse down", self.symbol ?: @"nil");
}

#pragma mark - Appearance Updates

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    
    // Update colors for dark/light mode
    if ([self.effectiveAppearance.name isEqualToString:NSAppearanceNameDarkAqua]) {
        self.backgroundColor = [NSColor controlBackgroundColor];
        self.textColor = [NSColor labelColor];
    } else {
        self.backgroundColor = [NSColor controlBackgroundColor];
        self.textColor = [NSColor labelColor];
    }
    
    [self setNeedsDisplay:YES];
}

#pragma mark - DEPRECATED Methods (Remove these)

// OLD METHOD - DO NOT USE
// This is kept temporarily for compatibility but should be removed
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
