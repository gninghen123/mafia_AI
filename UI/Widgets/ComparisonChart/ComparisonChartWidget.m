//
// ComparisonChartWidget.m (PARTE 1/2)
// TradingApp
//
// QUESTA È LA PARTE 1 - Contiene:
// - Implementation headers
// - Initialization
// - UI Setup
// - Actions
// - Chain Integration
// - Symbol Management
//

#import "ComparisonChartWidget.h"
#import "DataHub+MarketData.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - ComparisonDataPoint Implementation

@implementation ComparisonDataPoint
@end

#pragma mark - ComparisonChartWidget Implementation

@interface ComparisonChartWidget ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<ComparisonDataPoint *> *> *normalizedData;
@end

@implementation ComparisonChartWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type {
    self = [super initWithType:type];
    if (self) {
        _symbols = [NSMutableArray array];
        _symbolsData = [NSMutableDictionary dictionary];
        _symbolColors = [NSMutableDictionary dictionary];
        _normalizedData = [NSMutableDictionary dictionary];
        _currentTimeframe = BarTimeframeDaily;
        _currentRange = ComparisonRange3Months;
        _isLoading = NO;
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    CGFloat contentWidth = self.contentView.bounds.size.width;
    CGFloat contentHeight = self.contentView.bounds.size.height;
    
    // Altezze fisse
    CGFloat topControlsHeight = 40;
    CGFloat bottomStatusHeight = 30;
    
    // Chart canvas al centro
    CGFloat chartHeight = contentHeight - topControlsHeight - bottomStatusHeight;
    self.chartCanvasView = [[NSView alloc] initWithFrame:NSMakeRect(0, bottomStatusHeight, contentWidth, chartHeight)];
    self.chartCanvasView.wantsLayer = YES;
    self.chartCanvasView.layer.backgroundColor = [NSColor lightGrayColor].CGColor; // debug
    self.chartCanvasView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.chartCanvasView.translatesAutoresizingMaskIntoConstraints = YES;
    [self.contentView addSubview:self.chartCanvasView];
    
    [self setupChartLayers];
    
    // --- Controls row in alto ---
    CGFloat controlsY = contentHeight - topControlsHeight + (topControlsHeight - 25)/2;
    CGFloat currentX = 10;
    
    NSTextField *symbolsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(currentX, controlsY + 3, 60, 20)];
    symbolsLabel.stringValue = @"Symbols:";
    symbolsLabel.editable = NO;
    symbolsLabel.bordered = NO;
    symbolsLabel.backgroundColor = [NSColor clearColor];
    [self.contentView addSubview:symbolsLabel];
    currentX += 65;
    
    self.symbolsInputCombo = [[NSComboBox alloc] initWithFrame:NSMakeRect(currentX, controlsY, 280, 25)];
    self.symbolsInputCombo.placeholderString = @"AAPL, MSFT, GOOGL...";
    self.symbolsInputCombo.target = self;
    self.symbolsInputCombo.action = @selector(symbolsInputChanged:);
    [self.contentView addSubview:self.symbolsInputCombo];
    currentX += 290;
    
    NSTextField *timeframeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(currentX, controlsY + 3, 70, 20)];
    timeframeLabel.stringValue = @"Timeframe:";
    timeframeLabel.editable = NO;
    timeframeLabel.bordered = NO;
    timeframeLabel.backgroundColor = [NSColor clearColor];
    [self.contentView addSubview:timeframeLabel];
    currentX += 75;
    
    self.timeframeSelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(currentX, controlsY, 100, 25)];
    [self populateTimeframeSelector];
    self.timeframeSelector.target = self;
    self.timeframeSelector.action = @selector(timeframeChanged:);
    [self.contentView addSubview:self.timeframeSelector];
    currentX += 110;
    
    NSTextField *rangeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(currentX, controlsY + 3, 50, 20)];
    rangeLabel.stringValue = @"Range:";
    rangeLabel.editable = NO;
    rangeLabel.bordered = NO;
    rangeLabel.backgroundColor = [NSColor clearColor];
    [self.contentView addSubview:rangeLabel];
    currentX += 55;
    
    self.rangeSelector = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(currentX, controlsY, 250, 25)];
    [self setupRangeSelector];
    self.rangeSelector.target = self;
    self.rangeSelector.action = @selector(rangeChanged:);
    [self.contentView addSubview:self.rangeSelector];
    currentX += 260;
    
    self.refreshButton = [[NSButton alloc] initWithFrame:NSMakeRect(currentX, controlsY, 80, 25)];
    self.refreshButton.title = @"Refresh";
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshButtonClicked:);
    [self.contentView addSubview:self.refreshButton];
    
    // --- Status label in basso ---
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, (bottomStatusHeight-20)/2, contentWidth - 20, 20)];
    self.statusLabel.stringValue = @"Enter symbols to begin comparison";
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [self.contentView addSubview:self.statusLabel];
}


#pragma mark - UI Setup Helpers

- (void)populateTimeframeSelector {
    [self.timeframeSelector removeAllItems];
    
    NSDictionary *timeframeNames = @{
        @(BarTimeframe1Min): @"1 Min",
        @(BarTimeframe5Min): @"5 Min",
        @(BarTimeframe15Min): @"15 Min",
        @(BarTimeframe30Min): @"30 Min",
        @(BarTimeframe1Hour): @"1 Hour",
        @(BarTimeframe4Hour): @"4 Hour",
        @(BarTimeframeDaily): @"Daily",
        @(BarTimeframeWeekly): @"Weekly",
        @(BarTimeframeMonthly): @"Monthly"
    };
    
    NSArray *orderedTimeframes = @[
        @(BarTimeframe1Min),
        @(BarTimeframe5Min),
        @(BarTimeframe15Min),
        @(BarTimeframe30Min),
        @(BarTimeframe1Hour),
        @(BarTimeframe4Hour),
        @(BarTimeframeDaily),
        @(BarTimeframeWeekly),
        @(BarTimeframeMonthly)
    ];
    
    for (NSNumber *tf in orderedTimeframes) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:timeframeNames[tf]
                                                      action:nil
                                               keyEquivalent:@""];
        item.tag = tf.integerValue;
        [self.timeframeSelector.menu addItem:item];
    }
    
    [self.timeframeSelector selectItemWithTag:BarTimeframeDaily];
}

- (void)setupRangeSelector {
    [self.rangeSelector setSegmentCount:5];
    [self.rangeSelector setLabel:@"3M" forSegment:ComparisonRange3Months];
    [self.rangeSelector setLabel:@"6M" forSegment:ComparisonRange6Months];
    [self.rangeSelector setLabel:@"1Y" forSegment:ComparisonRange1Year];
    [self.rangeSelector setLabel:@"5Y" forSegment:ComparisonRange5Years];
    [self.rangeSelector setLabel:@"MAX" forSegment:ComparisonRangeMax];
    
    [self.rangeSelector setWidth:50 forSegment:ComparisonRange3Months];
    [self.rangeSelector setWidth:50 forSegment:ComparisonRange6Months];
    [self.rangeSelector setWidth:50 forSegment:ComparisonRange1Year];
    [self.rangeSelector setWidth:50 forSegment:ComparisonRange5Years];
    [self.rangeSelector setWidth:50 forSegment:ComparisonRangeMax];
    
    [self.rangeSelector setSelectedSegment:ComparisonRange3Months];
}

- (void)setupChartLayers {
    self.chartLayer = [CALayer layer];
    self.chartLayer.frame = self.chartCanvasView.bounds;
    [self.chartCanvasView.layer addSublayer:self.chartLayer];
    
    self.gridLayer = [CALayer layer];
    self.gridLayer.frame = self.chartCanvasView.bounds;
    [self.chartLayer addSublayer:self.gridLayer];
    
    self.legendLayer = [CALayer layer];
    self.legendLayer.frame = CGRectMake(10, self.chartCanvasView.bounds.size.height - 100, 200, 90);
    self.legendLayer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.9] CGColor];
    self.legendLayer.borderColor = [NSColor separatorColor].CGColor;
    self.legendLayer.borderWidth = 1.0;
    self.legendLayer.cornerRadius = 5.0;
    [self.chartLayer addSublayer:self.legendLayer];
}

#pragma mark - Actions

- (void)symbolsInputChanged:(id)sender {
    NSString *input = self.symbolsInputCombo.stringValue;
    if (!input || input.length == 0) return;
    
    NSArray *components = [input componentsSeparatedByString:@","];
    NSMutableArray *parsedSymbols = [NSMutableArray array];
    
    for (NSString *component in components) {
        NSString *trimmed = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0) {
            [parsedSymbols addObject:trimmed.uppercaseString];
        }
    }
    
    if (parsedSymbols.count > 0) {
        [self setSymbols:parsedSymbols];
        [self refreshData];
    }
}

- (void)timeframeChanged:(id)sender {
    NSInteger selectedTag = self.timeframeSelector.selectedItem.tag;
    self.currentTimeframe = (BarTimeframe)selectedTag;
    
    NSLog(@"ComparisonChartWidget: Timeframe changed to %ld", (long)self.currentTimeframe);
    
    if (self.symbols.count > 0) {
        [self refreshData];
    }
}

- (void)rangeChanged:(id)sender {
    NSInteger selectedSegment = self.rangeSelector.selectedSegment;
    self.currentRange = (ComparisonRange)selectedSegment;
    
    NSLog(@"ComparisonChartWidget: Range changed to %ld", (long)self.currentRange);
    
    if (self.symbols.count > 0) {
        [self refreshData];
    }
}

- (void)refreshButtonClicked:(id)sender {
    [self refreshData];
}

#pragma mark - Chain Integration

- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"📥 ComparisonChartWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
    
    [self setSymbols:symbols];
    
    NSString *symbolsString = [symbols componentsJoinedByString:@", "];
    self.symbolsInputCombo.stringValue = symbolsString;
    
    [self refreshData];
    
    [self showChainFeedback:[NSString stringWithFormat:@"📊 Comparing %lu symbols", (unsigned long)symbols.count]];
}

#pragma mark - Symbol Management

- (void)addSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    NSString *upperSymbol = symbol.uppercaseString;
    if (![self.symbols containsObject:upperSymbol]) {
        [self.symbols addObject:upperSymbol];
        NSLog(@"ComparisonChartWidget: Added symbol %@", upperSymbol);
    }
}

- (void)removeSymbol:(NSString *)symbol {
    [self.symbols removeObject:symbol.uppercaseString];
    [self.symbolsData removeObjectForKey:symbol.uppercaseString];
    [self.normalizedData removeObjectForKey:symbol.uppercaseString];
    NSLog(@"ComparisonChartWidget: Removed symbol %@", symbol);
}

- (void)setSymbols:(NSArray<NSString *> *)symbols {
    [self.symbols removeAllObjects];
    
    for (NSString *symbol in symbols) {
        if (symbol.length > 0) {
            [self.symbols addObject:symbol.uppercaseString];
        }
    }
    
    NSLog(@"ComparisonChartWidget: Set symbols to %@", self.symbols);
}



#pragma mark - Data Fetching

- (void)refreshData {
    if (self.symbols.count == 0) {
        self.statusLabel.stringValue = @"No symbols to compare";
        return;
    }
    
    if (self.isLoading) {
        NSLog(@"ComparisonChartWidget: Already loading data");
        return;
    }
    
    self.isLoading = YES;
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Loading data for %lu symbols...", (unsigned long)self.symbols.count];
    
    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:86400];
    NSDate *startDate = [self startDateForRange:self.currentRange];
    
    NSLog(@"📊 ComparisonChartWidget: Fetching data from %@ to %@ (timeframe: %ld)",
          startDate, endDate, (long)self.currentTimeframe);
    
    [self.symbolsData removeAllObjects];
    [self.normalizedData removeAllObjects];
    
    __block NSInteger pendingRequests = self.symbols.count;
    __block NSInteger successfulRequests = 0;
    
    for (NSString *symbol in self.symbols) {
        [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                           timeframe:self.currentTimeframe
                                           startDate:startDate
                                             endDate:endDate
                                   needExtendedHours:NO
                                          completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (bars && bars.count > 0) {
                    self.symbolsData[symbol] = bars;
                    successfulRequests++;
                    NSLog(@"✅ Loaded %lu bars for %@", (unsigned long)bars.count, symbol);
                } else {
                    NSLog(@"⚠️ No data received for %@", symbol);
                }
                
                pendingRequests--;
                
                if (pendingRequests == 0) {
                    self.isLoading = NO;
                    
                    if (successfulRequests > 0) {
                        self.statusLabel.stringValue = [NSString stringWithFormat:@"Loaded %ld/%lu symbols",
                                                        (long)successfulRequests, (unsigned long)self.symbols.count];
                        [self normalizeAndRenderData];
                    } else {
                        self.statusLabel.stringValue = @"Failed to load any data";
                    }
                }
            });
        }];
    }
}

- (NSDate *)startDateForRange:(ComparisonRange)range {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    
    switch (range) {
        case ComparisonRange3Months:
            components.month = -3;
            break;
        case ComparisonRange6Months:
            components.month = -6;
            break;
        case ComparisonRange1Year:
            components.year = -1;
            break;
        case ComparisonRange5Years:
            components.year = -5;
            break;
        case ComparisonRangeMax:
            components.year = -50;
            break;
    }
    
    return [calendar dateByAddingComponents:components toDate:[NSDate date] options:0];
}

#pragma mark - Data Normalization

- (void)normalizeAndRenderData {
    if (self.symbolsData.count == 0) {
        NSLog(@"⚠️ ComparisonChartWidget: No data to normalize");
        return;
    }
    
    NSDate *commonStartDate = nil;
    
    for (NSString *symbol in self.symbolsData.allKeys) {
        NSArray<HistoricalBarModel *> *bars = self.symbolsData[symbol];
        if (bars.count == 0) continue;
        
        NSDate *firstDate = bars.firstObject.date;
        
        if (!commonStartDate || [firstDate compare:commonStartDate] == NSOrderedDescending) {
            commonStartDate = firstDate;
        }
    }
    
    if (!commonStartDate) {
        NSLog(@"❌ ComparisonChartWidget: No common start date found");
        self.statusLabel.stringValue = @"Error: No common date found";
        return;
    }
    
    self.commonStartDate = commonStartDate;
    NSLog(@"✅ Common start date: %@", commonStartDate);
    
    [self.normalizedData removeAllObjects];
    
    for (NSString *symbol in self.symbolsData.allKeys) {
        NSArray<HistoricalBarModel *> *bars = self.symbolsData[symbol];
        
        NSPredicate *datePredicate = [NSPredicate predicateWithBlock:^BOOL(HistoricalBarModel *bar, NSDictionary *bindings) {
            return [bar.date compare:commonStartDate] != NSOrderedAscending;
        }];
        
        NSArray<HistoricalBarModel *> *filteredBars = [bars filteredArrayUsingPredicate:datePredicate];
        
        if (filteredBars.count == 0) {
            NSLog(@"⚠️ No bars after common date for %@", symbol);
            continue;
        }
        
        double baselinePrice = filteredBars.firstObject.close;
        if (baselinePrice == 0) {
            NSLog(@"⚠️ Invalid baseline price for %@", symbol);
            continue;
        }
        
        NSMutableArray<ComparisonDataPoint *> *points = [NSMutableArray array];
        
        for (HistoricalBarModel *bar in filteredBars) {
            ComparisonDataPoint *point = [[ComparisonDataPoint alloc] init];
            point.date = bar.date;
            point.percentChange = ((bar.close - baselinePrice) / baselinePrice) * 100.0;
            [points addObject:point];
        }
        
        self.normalizedData[symbol] = points;
        
        NSLog(@"📈 Normalized %lu points for %@ (baseline: %.2f)",
              (unsigned long)points.count, symbol, baselinePrice);
    }
    
    [self updateChart];
}

#pragma mark - Chart Rendering

- (void)updateChart {
    if (self.normalizedData.count == 0) {
        NSLog(@"⚠️ No normalized data to render");
        return;
    }
    
    for (CALayer *sublayer in [self.gridLayer.sublayers copy]) {
        [sublayer removeFromSuperlayer];
    }
    for (CALayer *sublayer in [self.chartLayer.sublayers copy]) {
        if (sublayer != self.gridLayer && sublayer != self.legendLayer) {
            [sublayer removeFromSuperlayer];
        }
    }
    
    CGRect bounds = self.chartCanvasView.bounds;
    CGFloat chartWidth = bounds.size.width - 80;
    CGFloat chartHeight = bounds.size.height - 60;
    CGFloat chartX = 50;
    CGFloat chartY = 40;
    
    double minPercent = 0, maxPercent = 0;
    NSDate *minDate = nil, *maxDate = nil;
    
    for (NSArray<ComparisonDataPoint *> *points in self.normalizedData.allValues) {
        for (ComparisonDataPoint *point in points) {
            if (point.percentChange < minPercent) minPercent = point.percentChange;
            if (point.percentChange > maxPercent) maxPercent = point.percentChange;
            
            if (!minDate || [point.date compare:minDate] == NSOrderedAscending) minDate = point.date;
            if (!maxDate || [point.date compare:maxDate] == NSOrderedDescending) maxDate = point.date;
        }
    }
    
    double yRange = maxPercent - minPercent;
    if (yRange < 1.0) yRange = 1.0;
    double yPadding = yRange * 0.1;
    minPercent -= yPadding;
    maxPercent += yPadding;
    
    NSTimeInterval timeRange = [maxDate timeIntervalSinceDate:minDate];
    if (timeRange <= 0) timeRange = 1;
    
    [self drawGridWithBounds:CGRectMake(chartX, chartY, chartWidth, chartHeight)
                   minPercent:minPercent
                   maxPercent:maxPercent
                      minDate:minDate
                      maxDate:maxDate];
    
    NSArray *colors = @[
        [NSColor systemBlueColor],
        [NSColor systemRedColor],
        [NSColor systemGreenColor],
        [NSColor systemOrangeColor],
        [NSColor systemPurpleColor],
        [NSColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0],
        [NSColor systemPinkColor],
        [NSColor systemTealColor],
        [NSColor systemBrownColor],
        [NSColor systemIndigoColor]
    ];
    
    NSInteger colorIndex = 0;
    
    for (NSString *symbol in [self.normalizedData.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSArray<ComparisonDataPoint *> *points = self.normalizedData[symbol];
        if (points.count < 2) continue;
        
        NSColor *color = colors[colorIndex % colors.count];
        self.symbolColors[symbol] = color;
        colorIndex++;
        
        CAShapeLayer *lineLayer = [CAShapeLayer layer];
        lineLayer.strokeColor = color.CGColor;
        lineLayer.fillColor = nil;
        lineLayer.lineWidth = 2.0;
        lineLayer.lineCap = kCALineCapRound;
        lineLayer.lineJoin = kCALineJoinRound;
        
        CGMutablePathRef path = CGPathCreateMutable();
        BOOL firstPoint = YES;
        
        for (ComparisonDataPoint *point in points) {
            CGFloat x = chartX + ([point.date timeIntervalSinceDate:minDate] / timeRange) * chartWidth;
            CGFloat y = chartY + ((point.percentChange - minPercent) / (maxPercent - minPercent)) * chartHeight;
            
            if (firstPoint) {
                CGPathMoveToPoint(path, NULL, x, y);
                firstPoint = NO;
            } else {
                CGPathAddLineToPoint(path, NULL, x, y);
            }
        }
        
        lineLayer.path = path;
        CGPathRelease(path);
        
        [self.chartLayer addSublayer:lineLayer];
    }
    
    [self updateLegend];
    
    NSLog(@"✅ Chart rendered with %lu symbols", (unsigned long)self.normalizedData.count);
}

- (void)drawGridWithBounds:(CGRect)bounds
                minPercent:(double)minPercent
                maxPercent:(double)maxPercent
                   minDate:(NSDate *)minDate
                   maxDate:(NSDate *)maxDate {
    
    NSInteger numYLines = 5;
    for (NSInteger i = 0; i <= numYLines; i++) {
        double percent = minPercent + (maxPercent - minPercent) * i / numYLines;
        CGFloat y = bounds.origin.y + bounds.size.height * i / numYLines;
        
        CAShapeLayer *gridLine = [CAShapeLayer layer];
        gridLine.strokeColor = [[NSColor separatorColor] CGColor];
        gridLine.lineWidth = 0.5;
        
        CGMutablePathRef linePath = CGPathCreateMutable();
        CGPathMoveToPoint(linePath, NULL, bounds.origin.x, y);
        CGPathAddLineToPoint(linePath, NULL, bounds.origin.x + bounds.size.width, y);
        gridLine.path = linePath;
        CGPathRelease(linePath);
        
        [self.gridLayer addSublayer:gridLine];
        
        CATextLayer *label = [CATextLayer layer];
        label.string = [NSString stringWithFormat:@"%.1f%%", percent];
        label.fontSize = 10;
        label.foregroundColor = [[NSColor secondaryLabelColor] CGColor];
        label.alignmentMode = kCAAlignmentRight;
        label.frame = CGRectMake(0, y - 8, bounds.origin.x - 5, 16);
        label.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
        
        [self.gridLayer addSublayer:label];
    }
    
    NSInteger numXLines = 5;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MMM dd";
    
    for (NSInteger i = 0; i <= numXLines; i++) {
        NSTimeInterval timeOffset = [maxDate timeIntervalSinceDate:minDate] * i / numXLines;
        NSDate *date = [minDate dateByAddingTimeInterval:timeOffset];
        CGFloat x = bounds.origin.x + bounds.size.width * i / numXLines;
        
        CAShapeLayer *gridLine = [CAShapeLayer layer];
        gridLine.strokeColor = [[NSColor separatorColor] CGColor];
        gridLine.lineWidth = 0.5;
        
        CGMutablePathRef linePath = CGPathCreateMutable();
        CGPathMoveToPoint(linePath, NULL, x, bounds.origin.y);
        CGPathAddLineToPoint(linePath, NULL, x, bounds.origin.y + bounds.size.height);
        gridLine.path = linePath;
        CGPathRelease(linePath);
        
        [self.gridLayer addSublayer:gridLine];
        
        CATextLayer *label = [CATextLayer layer];
        label.string = [formatter stringFromDate:date];
        label.fontSize = 10;
        label.foregroundColor = [[NSColor secondaryLabelColor] CGColor];
        label.alignmentMode = kCAAlignmentCenter;
        label.frame = CGRectMake(x - 30, bounds.origin.y - 20, 60, 16);
        label.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
        
        [self.gridLayer addSublayer:label];
    }
    
    if (minPercent < 0 && maxPercent > 0) {
        CGFloat zeroY = bounds.origin.y + bounds.size.height * (-minPercent) / (maxPercent - minPercent);
        
        CAShapeLayer *zeroLine = [CAShapeLayer layer];
        zeroLine.strokeColor = [[NSColor labelColor] CGColor];
        zeroLine.lineWidth = 1.0;
        zeroLine.lineDashPattern = @[@4, @2];
        
        CGMutablePathRef zeroPath = CGPathCreateMutable();
        CGPathMoveToPoint(zeroPath, NULL, bounds.origin.x, zeroY);
        CGPathAddLineToPoint(zeroPath, NULL, bounds.origin.x + bounds.size.width, zeroY);
        zeroLine.path = zeroPath;
        CGPathRelease(zeroPath);
        
        [self.gridLayer addSublayer:zeroLine];
    }
}

- (void)updateLegend {
    for (CALayer *sublayer in [self.legendLayer.sublayers copy]) {
        [sublayer removeFromSuperlayer];
    }
    
    if (self.normalizedData.count == 0) return;
    
    NSArray *sortedSymbols = [self.normalizedData.allKeys sortedArrayUsingSelector:@selector(compare:)];
    
    CGFloat itemHeight = 16;
    CGFloat padding = 5;
    CGFloat currentY = self.legendLayer.bounds.size.height - padding - itemHeight;
    
    for (NSString *symbol in sortedSymbols) {
        if (currentY < padding) break;
        
        NSColor *color = self.symbolColors[symbol];
        if (!color) continue;
        
        CALayer *colorBox = [CALayer layer];
        colorBox.frame = CGRectMake(padding, currentY, 12, 12);
        colorBox.backgroundColor = color.CGColor;
        colorBox.cornerRadius = 2.0;
        [self.legendLayer addSublayer:colorBox];
        
        CATextLayer *label = [CATextLayer layer];
        label.string = symbol;
        label.fontSize = 11;
        label.foregroundColor = [[NSColor labelColor] CGColor];
        label.frame = CGRectMake(padding + 17, currentY - 1, self.legendLayer.bounds.size.width - padding - 22, itemHeight);
        label.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
        
        [self.legendLayer addSublayer:label];
        
        NSArray<ComparisonDataPoint *> *points = self.normalizedData[symbol];
        if (points.count > 0) {
            ComparisonDataPoint *lastPoint = points.lastObject;
            
            CATextLayer *percentLabel = [CATextLayer layer];
            NSString *percentStr = [NSString stringWithFormat:@"%+.2f%%", lastPoint.percentChange];
            percentLabel.string = percentStr;
            percentLabel.fontSize = 10;
            percentLabel.foregroundColor = lastPoint.percentChange >= 0 ?
                [[NSColor systemGreenColor] CGColor] :
                [[NSColor systemRedColor] CGColor];
            percentLabel.alignmentMode = kCAAlignmentRight;
            percentLabel.frame = CGRectMake(self.legendLayer.bounds.size.width - 70, currentY - 1, 60, itemHeight);
            percentLabel.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
            
            [self.legendLayer addSublayer:percentLabel];
        }
        
        currentY -= (itemHeight + 2);
    }
    
    CGFloat neededHeight = (sortedSymbols.count * (itemHeight + 2)) + (padding * 2);
    CGFloat maxHeight = self.chartCanvasView.bounds.size.height - 120;
    CGFloat legendHeight = MIN(neededHeight, maxHeight);
    
    CGRect legendFrame = self.legendLayer.frame;
    legendFrame.size.height = legendHeight;
    legendFrame.origin.y = self.chartCanvasView.bounds.size.height - legendHeight - 10;
    self.legendLayer.frame = legendFrame;
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    state[@"symbols"] = [self.symbols copy];
    state[@"timeframe"] = @(self.currentTimeframe);
    state[@"range"] = @(self.currentRange);
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    NSArray *savedSymbols = state[@"symbols"];
    if (savedSymbols) {
        [self setSymbols:savedSymbols];
        self.symbolsInputCombo.stringValue = [savedSymbols componentsJoinedByString:@", "];
    }
    
    NSNumber *timeframe = state[@"timeframe"];
    if (timeframe) {
        self.currentTimeframe = timeframe.integerValue;
        [self.timeframeSelector selectItemWithTag:self.currentTimeframe];
    }
    
    NSNumber *range = state[@"range"];
    if (range) {
        self.currentRange = range.integerValue;
        [self.rangeSelector setSelectedSegment:self.currentRange];
    }
    
    if (self.symbols.count > 0) {
        [self refreshData];
    }
}

#pragma mark - Resize Handling

- (void)viewDidLayout {
    [super viewDidLayout];
    
    if (self.chartCanvasView && self.chartLayer) {
        CGRect newBounds = self.chartCanvasView.bounds;
        
        self.chartLayer.frame = newBounds;
        self.gridLayer.frame = newBounds;
        
        CGRect legendFrame = self.legendLayer.frame;
        legendFrame.origin.y = newBounds.size.height - legendFrame.size.height - 10;
        self.legendLayer.frame = legendFrame;
        
        if (self.normalizedData.count > 0) {
            [self updateChart];
        }
    }
}

@end
