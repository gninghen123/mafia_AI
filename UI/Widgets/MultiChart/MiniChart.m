
#import "MiniChart.h"
#import "DataManager.h"

@interface MiniChart ()

// UI Components
@property (nonatomic, strong) NSTextField *symbolLabel;
@property (nonatomic, strong) NSTextField *priceLabel;
@property (nonatomic, strong) NSTextField *changeLabel;
@property (nonatomic, strong) NSView *chartArea;
@property (nonatomic, strong) NSView *volumeArea;  // Area per i volumi
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// Drawing
@property (nonatomic, strong) NSBezierPath *chartPath;
@property (nonatomic, strong) NSBezierPath *volumePath;  // Path per i volumi
@property (nonatomic, strong) NSMutableArray *candlestickData;  // Dati per candlestick
@property (nonatomic, assign) CGFloat minPrice;
@property (nonatomic, assign) CGFloat maxPrice;
@property (nonatomic, assign) CGFloat maxVolume;  // Volume massimo per normalizzazione

@end

@implementation MiniChart

#pragma mark - Class Methods

+ (instancetype)miniChartWithSymbol:(NSString *)symbol
                          chartType:(MiniChartType)chartType
                          timeframe:(MiniChartTimeframe)timeframe
                          scaleType:(MiniChartScaleType)scaleType
                            maxBars:(NSInteger)maxBars
                         showVolume:(BOOL)showVolume {
    MiniChart *chart = [[MiniChart alloc] initWithFrame:NSMakeRect(0, 0, 200, 150)];
    chart.symbol = symbol;
    chart.chartType = chartType;
    chart.timeframe = timeframe;
    chart.scaleType = scaleType;
    chart.maxBars = maxBars;
    chart.showVolume = showVolume;
    return chart;
}

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

- (void)setupDefaults {
    // Default colors
    _positiveColor = [NSColor systemGreenColor];
    _negativeColor = [NSColor systemRedColor];
    _backgroundColor = [NSColor controlBackgroundColor];
    _textColor = [NSColor labelColor];
    
    // Default state
    _isLoading = NO;
    _hasError = NO;
    _chartType = MiniChartTypeLine;
    _timeframe = MiniChartTimeframeDaily;
    _scaleType = MiniChartScaleLinear;
    _maxBars = 100;
    _showVolume = YES;
    
    // View setup
    self.wantsLayer = YES;
    self.layer.backgroundColor = _backgroundColor.CGColor;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.cornerRadius = 4.0;
}

- (void)setupUI {
    // Symbol label (top left)
    self.symbolLabel = [[NSTextField alloc] init];
    self.symbolLabel.stringValue = self.symbol ?: @"";
    self.symbolLabel.textColor = [NSColor colorWithRed:1 green:1 blue:1 alpha:0.25];
    self.symbolLabel.font = [NSFont boldSystemFontOfSize:18];
    self.symbolLabel.backgroundColor = [NSColor clearColor];
    self.symbolLabel.bordered = NO;
    self.symbolLabel.editable = NO;
    self.symbolLabel.selectable = NO;
    self.symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.symbolLabel];
    
    // Price label (top right)
    self.priceLabel = [[NSTextField alloc] init];
    self.priceLabel.stringValue = @"$0.00";
    self.priceLabel.textColor = self.textColor;
    self.priceLabel.font = [NSFont systemFontOfSize:9];
    self.priceLabel.backgroundColor = [NSColor clearColor];
    self.priceLabel.bordered = NO;
    self.priceLabel.editable = NO;
    self.priceLabel.selectable = NO;
    self.priceLabel.alignment = NSTextAlignmentRight;
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.priceLabel];
    
    // Change label (bottom right)
    self.changeLabel = [[NSTextField alloc] init];
    self.changeLabel.stringValue = @"+0.00%";
    self.changeLabel.textColor = self.positiveColor;
    self.changeLabel.font = [NSFont systemFontOfSize:8];
    self.changeLabel.backgroundColor = [NSColor clearColor];
    self.changeLabel.bordered = NO;
    self.changeLabel.editable = NO;
    self.changeLabel.selectable = NO;
    self.changeLabel.alignment = NSTextAlignmentRight;
    self.changeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.changeLabel];
    
    // Chart area (area principale per prezzi)
    self.chartArea = [[NSView alloc] init];
    self.chartArea.wantsLayer = YES;
    self.chartArea.layer.backgroundColor = [NSColor clearColor].CGColor;
    self.chartArea.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.chartArea];
    
    // Volume area (area separata per volumi)
    self.volumeArea = [[NSView alloc] init];
    self.volumeArea.wantsLayer = YES;
    self.volumeArea.layer.backgroundColor = [NSColor clearColor].CGColor;
    self.volumeArea.translatesAutoresizingMaskIntoConstraints = NO;
    self.volumeArea.hidden = !self.showVolume; // Nascondi se volume disabilitato
    [self addSubview:self.volumeArea];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.hidden = YES;
    [self addSubview:self.loadingIndicator];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Symbol label - top left
        [self.symbolLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
        [self.symbolLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
        [self.symbolLabel.widthAnchor constraintLessThanOrEqualToConstant:60],
        
        // Price label - top right
        [self.priceLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
        [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
        [self.priceLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.symbolLabel.trailingAnchor constant:4],
        
        // Change label - bottom right
        [self.changeLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
        [self.changeLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
        [self.changeLabel.widthAnchor constraintLessThanOrEqualToConstant:50]
    ]];
    
    if (self.showVolume) {
        // Layout con volume: Chart area 70%, Volume area 25%, gap 5%
        [NSLayoutConstraint activateConstraints:@[
            // Chart area - area principale per prezzi
            [self.chartArea.topAnchor constraintEqualToAnchor:self.symbolLabel.bottomAnchor constant:2],
            [self.chartArea.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
            [self.chartArea.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
            [self.chartArea.heightAnchor constraintEqualToAnchor:self.heightAnchor multiplier:0.65], // 65% dell'altezza
            
            // Volume area - area separata per volumi
            [self.volumeArea.topAnchor constraintEqualToAnchor:self.chartArea.bottomAnchor constant:4],
            [self.volumeArea.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
            [self.volumeArea.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
            [self.volumeArea.bottomAnchor constraintEqualToAnchor:self.changeLabel.topAnchor constant:-2]
        ]];
    } else {
        // Layout senza volume: Chart area occupa tutto lo spazio
        [NSLayoutConstraint activateConstraints:@[
            // Chart area - occupa tutto lo spazio disponibile
            [self.chartArea.topAnchor constraintEqualToAnchor:self.symbolLabel.bottomAnchor constant:2],
            [self.chartArea.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
            [self.chartArea.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
            [self.chartArea.bottomAnchor constraintEqualToAnchor:self.changeLabel.topAnchor constant:-2]
        ]];
    }
    
    // Loading indicator - center
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
    ]];
}

#pragma mark - Properties

- (void)setSymbol:(NSString *)symbol {
    _symbol = symbol;
    self.symbolLabel.stringValue = symbol ?: @"";
}

- (void)setCurrentPrice:(NSNumber *)currentPrice {
    _currentPrice = currentPrice;
    if (currentPrice) {
        self.priceLabel.stringValue = [NSString stringWithFormat:@"$%.2f", currentPrice.doubleValue];
    } else {
        self.priceLabel.stringValue = @"$0.00";
    }
}

- (void)setPercentChange:(NSNumber *)percentChange {
    _percentChange = percentChange;
    if (percentChange) {
        double change = percentChange.doubleValue;
        NSString *sign = change >= 0 ? @"+" : @"";
        self.changeLabel.stringValue = [NSString stringWithFormat:@"%@%.2f%%", sign, change];
        self.changeLabel.textColor = change >= 0 ? self.positiveColor : self.negativeColor;
    } else {
        self.changeLabel.stringValue = @"+0.00%";
        self.changeLabel.textColor = self.textColor;
    }
}

- (void)setShowVolume:(BOOL)showVolume {
    _showVolume = showVolume;
    self.volumeArea.hidden = !showVolume;
    [self updateConstraintsIfNeeded];
    [self setNeedsDisplay:YES];
}

- (void)updateConstraintsIfNeeded {
    // Rimuovi tutti i constraints esistenti per chart e volume area
    NSArray *constraintsToRemove = [self.constraints filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSLayoutConstraint *constraint, NSDictionary *bindings) {
        return (constraint.firstItem == self.chartArea ||
                constraint.firstItem == self.volumeArea ||
                constraint.secondItem == self.chartArea ||
                constraint.secondItem == self.volumeArea);
    }]];
    
    [NSLayoutConstraint deactivateConstraints:constraintsToRemove];
    
    // Ricrea i constraints
    [self setupConstraints];
}

#pragma mark - Data Management

- (void)updateWithPriceData:(NSArray *)priceData {
    self.priceData = priceData;
    
    // Limita il numero di barre se necessario
    if (priceData.count > self.maxBars) {
        NSInteger startIndex = priceData.count - self.maxBars;
        self.priceData = [priceData subarrayWithRange:NSMakeRange(startIndex, self.maxBars)];
    }
    
    [self calculatePriceRange];
    [self calculateVolumeRange];
    [self generateChartPath];
    [self generateVolumePath];
    [self updatePriceLabels];
    [self setNeedsDisplay:YES];
}

- (void)calculateVolumeRange {
    if (!self.priceData || self.priceData.count == 0) {
        self.maxVolume = 1000000; // Default
        return;
    }
    
    self.maxVolume = 0;
    for (HistoricalBar *bar in self.priceData) {
        double volume = bar.volume;
        if (volume > self.maxVolume) {
            self.maxVolume = volume;
        }
    }
}

- (void)calculatePriceRange {
    if (!self.priceData || self.priceData.count == 0) {
        self.minPrice = 0;
        self.maxPrice = 100;
        return;
    }
    
    self.minPrice = CGFLOAT_MAX;
    self.maxPrice = CGFLOAT_MIN;
    
    // Per scala percentuale, usa il primo valore come base
    double basePrice = 0;
    if (self.scaleType == MiniChartScalePercent && self.priceData.count > 0) {
        HistoricalBar *firstBar = self.priceData.firstObject;
        basePrice = firstBar.close.doubleValue;
    }
    
    for (HistoricalBar *bar in self.priceData) {
        double lowPrice, highPrice;
        
        switch (self.scaleType) {
            case MiniChartScaleLinear:
                lowPrice = bar.low.doubleValue;
                highPrice = bar.high.doubleValue;
                break;
                
            case MiniChartScaleLog:
                lowPrice = log(bar.low.doubleValue);
                highPrice = log(bar.high.doubleValue);
                break;
                
            case MiniChartScalePercent:
                lowPrice = ((bar.low.doubleValue - basePrice) / basePrice) * 100.0;
                highPrice = ((bar.high.doubleValue - basePrice) / basePrice) * 100.0;
                break;
        }
        
        if (lowPrice < self.minPrice) self.minPrice = lowPrice;
        if (highPrice > self.maxPrice) self.maxPrice = highPrice;
    }
    
    // Add some padding
    CGFloat range = self.maxPrice - self.minPrice;
    CGFloat padding = range * 0.05; // 5% padding
    self.minPrice -= padding;
    self.maxPrice += padding;
}

- (void)generateChartPath {
    if (!self.priceData || self.priceData.count == 0) {
        self.chartPath = nil;
        return;
    }
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGRect chartRect = self.chartArea.bounds;
    
    switch (self.chartType) {
        case MiniChartTypeLine:
            [self generateLineChartPath:path inRect:chartRect];
            break;
        case MiniChartTypeCandle:
            [self generateCandlestickChartPath:path inRect:chartRect];
            break;
        case MiniChartTypeBar:
            [self generateOHLCBarChartPath:path inRect:chartRect];
            break;
    }
    
    self.chartPath = path;
}

- (void)generateVolumePath {
    if (!self.showVolume || !self.priceData || self.priceData.count == 0) {
        self.volumePath = nil;
        return;
    }
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGRect volumeRect = self.volumeArea.bounds;
    
    CGFloat xStep = volumeRect.size.width / self.priceData.count;
    CGFloat barWidth = xStep * 0.8;
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBar *bar = self.priceData[i];
        CGFloat x = volumeRect.origin.x + (i * xStep) + (xStep * 0.1);
        CGFloat barHeight = (bar.volume / self.maxVolume) * volumeRect.size.height;
        
        NSRect barRect = NSMakeRect(x, volumeRect.origin.y, barWidth, barHeight);
        [path appendBezierPathWithRect:barRect];
    }
    
    self.volumePath = path;
}

- (CGFloat)transformedPriceValue:(double)price {
    if (self.priceData.count == 0) return price;
    
    switch (self.scaleType) {
        case MiniChartScaleLinear:
            return price;
            
        case MiniChartScaleLog:
            return log(price);
            
        case MiniChartScalePercent: {
            HistoricalBar *firstBar = self.priceData.firstObject;
            double basePrice = firstBar.close.doubleValue;
            return ((price - basePrice) / basePrice) * 100.0;
        }
    }
    return price;
}

- (void)generateLineChartPath:(NSBezierPath *)path inRect:(CGRect)rect {
    if (self.priceData.count == 0) return;
    
    CGFloat xStep = rect.size.width / (self.priceData.count - 1);
    CGFloat yRange = self.maxPrice - self.minPrice;
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBar *bar = self.priceData[i];
        CGFloat x = rect.origin.x + (i * xStep);
        
        // Usa il valore trasformato in base alla scala
        CGFloat transformedPrice = [self transformedPriceValue:bar.close.doubleValue];
        CGFloat y = rect.origin.y + ((transformedPrice - self.minPrice) / yRange) * rect.size.height;
        
        if (i == 0) {
            [path moveToPoint:NSMakePoint(x, y)];
        } else {
            [path lineToPoint:NSMakePoint(x, y)];
        }
    }
}

- (void)generateCandlestickChartPath:(NSBezierPath *)path inRect:(CGRect)rect {
    // Per i candlestick, creiamo un array di dizionari che contiene le informazioni per ogni candela
    // Questo sarà usato nel metodo drawRect per disegnare correttamente corpo e wick
    
    if (!self.candlestickData) {
        self.candlestickData = [NSMutableArray array];
    } else {
        [self.candlestickData removeAllObjects];
    }
    
    CGFloat xStep = rect.size.width / self.priceData.count;
    CGFloat yRange = self.maxPrice - self.minPrice;
    CGFloat candleWidth = xStep * 0.7; // Larghezza del corpo della candela
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBar *bar = self.priceData[i];
        CGFloat x = rect.origin.x + (i * xStep) + (xStep * 0.15);
        
        // Trasforma i valori OHLC
        CGFloat open = [self transformedPriceValue:bar.open.doubleValue];
        CGFloat high = [self transformedPriceValue:bar.high.doubleValue];
        CGFloat low = [self transformedPriceValue:bar.low.doubleValue];
        CGFloat close = [self transformedPriceValue:bar.close.doubleValue];
        
        // Calcola posizioni Y
        CGFloat yHigh = rect.origin.y + ((high - self.minPrice) / yRange) * rect.size.height;
        CGFloat yLow = rect.origin.y + ((low - self.minPrice) / yRange) * rect.size.height;
        CGFloat yOpen = rect.origin.y + ((open - self.minPrice) / yRange) * rect.size.height;
        CGFloat yClose = rect.origin.y + ((close - self.minPrice) / yRange) * rect.size.height;
        
        // Determina colore: verde se close > open, rosso altrimenti
        BOOL isGreen = (bar.close.doubleValue >= bar.open.doubleValue);
        
        // Crea dizionario con info della candela
        NSDictionary *candleInfo = @{
            @"x": @(x),
            @"width": @(candleWidth),
            @"yHigh": @(yHigh),
            @"yLow": @(yLow),
            @"yOpen": @(yOpen),
            @"yClose": @(yClose),
            @"isGreen": @(isGreen)
        };
        
        [self.candlestickData addObject:candleInfo];
    }
    
    // Il path principale non viene usato per candlestick
    // Il disegno avviene direttamente in drawRect usando candlestickData
}

- (void)generateOHLCBarChartPath:(NSBezierPath *)path inRect:(CGRect)rect {
    // OHLC Bar chart: linea verticale per High-Low + tick a sinistra per Open + tick a destra per Close
    
    CGFloat xStep = rect.size.width / self.priceData.count;
    CGFloat yRange = self.maxPrice - self.minPrice;
    CGFloat tickLength = xStep * 0.3; // Lunghezza dei tick
    
    for (NSInteger i = 0; i < self.priceData.count; i++) {
        HistoricalBar *bar = self.priceData[i];
        CGFloat x = rect.origin.x + (i * xStep) + (xStep * 0.5); // Centro della barra
        
        // Trasforma i valori OHLC
        CGFloat open = [self transformedPriceValue:bar.open.doubleValue];
        CGFloat high = [self transformedPriceValue:bar.high.doubleValue];
        CGFloat low = [self transformedPriceValue:bar.low.doubleValue];
        CGFloat close = [self transformedPriceValue:bar.close.doubleValue];
        
        // Calcola posizioni Y
        CGFloat yHigh = rect.origin.y + ((high - self.minPrice) / yRange) * rect.size.height;
        CGFloat yLow = rect.origin.y + ((low - self.minPrice) / yRange) * rect.size.height;
        CGFloat yOpen = rect.origin.y + ((open - self.minPrice) / yRange) * rect.size.height;
        CGFloat yClose = rect.origin.y + ((close - self.minPrice) / yRange) * rect.size.height;
        
        // Linea verticale High-Low
        [path moveToPoint:NSMakePoint(x, yLow)];
        [path lineToPoint:NSMakePoint(x, yHigh)];
        
        // Tick per Open (a sinistra)
        [path moveToPoint:NSMakePoint(x - tickLength, yOpen)];
        [path lineToPoint:NSMakePoint(x, yOpen)];
        
        // Tick per Close (a destra)
        [path moveToPoint:NSMakePoint(x, yClose)];
        [path lineToPoint:NSMakePoint(x + tickLength, yClose)];
    }
}

- (void)updatePriceLabels {
    if (!self.priceData || self.priceData.count == 0) return;
    
    HistoricalBar *lastBar = self.priceData.lastObject;
    HistoricalBar *firstBar = self.priceData.firstObject;
    
    // Converti NSDecimalNumber a double
    self.currentPrice = @(lastBar.close.doubleValue);
    
    if (firstBar && lastBar) {
        double closePrice = lastBar.close.doubleValue;
        double openPrice = firstBar.close.doubleValue;
        double priceChange = closePrice - openPrice;
        double percentChange = (priceChange / openPrice) * 100.0;
        
        self.priceChange = @(priceChange);
        self.percentChange = @(percentChange);
    }
}

#pragma mark - Loading State

- (void)setLoading:(BOOL)loading {
    _isLoading = loading;
    if (loading) {
        self.loadingIndicator.hidden = NO;
        [self.loadingIndicator startAnimation:nil];
        self.chartArea.hidden = YES;
    } else {
        self.loadingIndicator.hidden = YES;
        [self.loadingIndicator stopAnimation:nil];
        self.chartArea.hidden = NO;
    }
}

- (void)setError:(NSString *)errorMessage {
    _hasError = (errorMessage != nil);
    _errorMessage = errorMessage;
    
    if (errorMessage) {
        self.priceLabel.stringValue = @"Error";
        self.changeLabel.stringValue = @"--";
        self.layer.borderColor = [NSColor systemRedColor].CGColor;
    } else {
        self.layer.borderColor = [NSColor separatorColor].CGColor;
    }
}

- (void)clearError {
    [self setError:nil];
}

#pragma mark - Actions

- (void)refresh {
    [self setLoading:YES];
    
    // Calcola date range per i dati storici
    NSDate *endDate = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *startDate = [calendar dateByAddingUnit:NSCalendarUnitYear value:-1 toDate:endDate options:0];
    
    // Richiedi i dati dal DataManager usando il metodo corretto
    BarTimeframe barTimeframe = BarTimeframe1Day; // Default
    
    [[DataManager sharedManager] requestHistoricalDataForSymbol:self.symbol
                                                      timeframe:barTimeframe
                                                      startDate:startDate
                                                        endDate:endDate
                                                     completion:^(NSArray<HistoricalBar *> *bars, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO];
            
            if (error) {
                [self setError:error.localizedDescription];
            } else {
                [self clearError];
                [self updateWithPriceData:bars];
            }
        });
    }];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (self.hasError) return;
    
    // Disegna il grafico principale
    if (self.chartType == MiniChartTypeCandle && self.candlestickData) {
        // Disegna candlestick chart
        [self drawCandlestickChart];
    } else if (self.chartPath) {
        // Disegna line chart o OHLC bar chart
        NSColor *strokeColor = self.textColor;
        if (self.percentChange) {
            strokeColor = self.percentChange.doubleValue >= 0 ? self.positiveColor : self.negativeColor;
        }
        
        [strokeColor setStroke];
        [self.chartPath setLineWidth:1.0];
        [self.chartPath stroke];
        
        // Fill area per line charts
        if (self.chartType == MiniChartTypeLine && self.chartPath.elementCount > 0) {
            NSBezierPath *fillPath = [self.chartPath copy];
            CGRect chartRect = self.chartArea.bounds;
            
            // Chiudi il path per creare l'area di riempimento
            [fillPath lineToPoint:NSMakePoint(chartRect.origin.x + chartRect.size.width, chartRect.origin.y)];
            [fillPath lineToPoint:NSMakePoint(chartRect.origin.x, chartRect.origin.y)];
            [fillPath closePath];
            
            [[strokeColor colorWithAlphaComponent:0.1] setFill];
            [fillPath fill];
        }
    }
    
    // Disegna i volumi se attivi
    if (self.showVolume && self.volumePath) {
        // Disegna nell'area volume separata
        NSGraphicsContext *context = [NSGraphicsContext currentContext];
        [context saveGraphicsState];
        
        // Clip alla volume area
        NSRectClip(self.volumeArea.bounds);
        
        [[NSColor colorWithWhite:0.6 alpha:0.5] setFill];
        [self.volumePath fill];
        
        [[NSColor colorWithWhite:0.4 alpha:0.8] setStroke];
        [self.volumePath setLineWidth:0.5];
        [self.volumePath stroke];
        
        [context restoreGraphicsState];
    }
}

- (void)drawCandlestickChart {
    for (NSDictionary *candleInfo in self.candlestickData) {
        CGFloat x = [candleInfo[@"x"] floatValue];
        CGFloat width = [candleInfo[@"width"] floatValue];
        CGFloat yHigh = [candleInfo[@"yHigh"] floatValue];
        CGFloat yLow = [candleInfo[@"yLow"] floatValue];
        CGFloat yOpen = [candleInfo[@"yOpen"] floatValue];
        CGFloat yClose = [candleInfo[@"yClose"] floatValue];
        BOOL isGreen = [candleInfo[@"isGreen"] boolValue];
        
        NSColor *candleColor = isGreen ? self.positiveColor : self.negativeColor;
        
        // Disegna il wick (linea sottile High-Low)
        NSBezierPath *wickPath = [NSBezierPath bezierPath];
        [wickPath moveToPoint:NSMakePoint(x + width/2, yLow)];
        [wickPath lineToPoint:NSMakePoint(x + width/2, yHigh)];
        [wickPath setLineWidth:1.0];
        [candleColor setStroke];
        [wickPath stroke];
        
        // Disegna il corpo della candela
        CGFloat bodyTop = MAX(yOpen, yClose);
        CGFloat bodyBottom = MIN(yOpen, yClose);
        CGFloat bodyHeight = bodyTop - bodyBottom;
        
        if (bodyHeight < 1.0) {
            bodyHeight = 1.0; // Altezza minima per candele doji
        }
        
        NSRect bodyRect = NSMakeRect(x, bodyBottom, width, bodyHeight);
        NSBezierPath *bodyPath = [NSBezierPath bezierPathWithRect:bodyRect];
        
        if (isGreen) {
            // Candela verde: corpo pieno
            [candleColor setFill];
            [bodyPath fill];
        } else {
            [candleColor setFill];
            [bodyPath fill];
            [candleColor setStroke];
            [bodyPath setLineWidth:1.0];
            [bodyPath stroke];
        }
    }
}

@end
