//
//  MultiChartWidget.m
//  TradingApp
//
//  Implementation of multi-symbol chart grid widget
//

#import "MultiChartWidget.h"
#import "MiniChart.h"
#import "DataManager.h"

@interface MultiChartWidget ()

// UI Components
@property (nonatomic, strong) NSView *controlsView;
@property (nonatomic, strong) NSTextField *symbolsTextField;
@property (nonatomic, strong) NSPopUpButton *chartTypePopup;
@property (nonatomic, strong) NSPopUpButton *timeframePopup;
@property (nonatomic, strong) NSPopUpButton *scaleTypePopup;
@property (nonatomic, strong) NSTextField *maxBarsField;
@property (nonatomic, strong) NSButton *volumeCheckbox;
@property (nonatomic, strong) NSSegmentedControl *columnsControl;
@property (nonatomic, strong) NSButton *refreshButton;

// Content
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSView *chartsContainer;
@property (nonatomic, strong) NSMutableArray<MiniChart *> *miniCharts;

// Layout
@property (nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *chartConstraints;

// Data management
@property (nonatomic, strong) NSOperationQueue *dataQueue;
@property (nonatomic, strong) NSTimer *refreshTimer;

@end

@implementation MultiChartWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        [self setupMultiChartDefaults];
    }
    return self;
}

- (void)setupMultiChartDefaults {
    // Default configuration
    _chartType = MiniChartTypeLine;
    _timeframe = MiniChartTimeframeDaily;
    _scaleType = MiniChartScaleLinear;
    _maxBars = 100;  // Default 100 barre
    _showVolume = YES; // Volume attivo di default
    _columnsCount = 3;
    _symbols = @[];
    _symbolsString = @"";
    
    // Initialize collections
    _miniCharts = [NSMutableArray array];
    _chartConstraints = [NSMutableArray array];
    
    // Data queue for async operations
    _dataQueue = [[NSOperationQueue alloc] init];
    _dataQueue.name = @"MultiChartDataQueue";
    _dataQueue.maxConcurrentOperationCount = 5; // Limit concurrent requests
}

#pragma mark - BaseWidget Override

- (void)setupContentView {
    [super setupContentView];
    
    // Remove BaseWidget placeholder
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    [self setupControlsView];
    [self setupChartsView];
    [self setupConstraints];
    
}

- (void)setupControlsView {
    // Controls container
    self.controlsView = [[NSView alloc] init];
    self.controlsView.wantsLayer = YES;
    self.controlsView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.controlsView];
    
    // Symbols text field
    self.symbolsTextField = [[NSTextField alloc] init];
    self.symbolsTextField.placeholderString = @"Enter symbols (e.g., AAPL,MSFT,GOOGL)";
    self.symbolsTextField.stringValue = self.symbolsString;
    self.symbolsTextField.target = self;
    self.symbolsTextField.action = @selector(symbolsTextChanged:);
    self.symbolsTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.symbolsTextField];
    
    // Chart type popup
    self.chartTypePopup = [[NSPopUpButton alloc] init];
    [self.chartTypePopup addItemWithTitle:@"Line"];
    [self.chartTypePopup addItemWithTitle:@"Candle"];
    [self.chartTypePopup addItemWithTitle:@"Bar"];
    [self.chartTypePopup selectItemAtIndex:self.chartType];
    self.chartTypePopup.target = self;
    self.chartTypePopup.action = @selector(chartTypeChanged:);
    self.chartTypePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.chartTypePopup];
    
    // Timeframe popup
    self.timeframePopup = [[NSPopUpButton alloc] init];
    [self.timeframePopup addItemWithTitle:@"1m"];
    [self.timeframePopup addItemWithTitle:@"5m"];
    [self.timeframePopup addItemWithTitle:@"15m"];
    [self.timeframePopup addItemWithTitle:@"1h"];
    [self.timeframePopup addItemWithTitle:@"4h"];
    [self.timeframePopup addItemWithTitle:@"1d"];
    [self.timeframePopup addItemWithTitle:@"1w"];
    [self.timeframePopup selectItemAtIndex:self.timeframe];
    self.timeframePopup.target = self;
    self.timeframePopup.action = @selector(timeframeChanged:);
    self.timeframePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.timeframePopup];
    
    // Scale type popup
    self.scaleTypePopup = [[NSPopUpButton alloc] init];
    [self.scaleTypePopup addItemWithTitle:@"Linear"];
    [self.scaleTypePopup addItemWithTitle:@"Log"];
    [self.scaleTypePopup addItemWithTitle:@"Percent"];
    [self.scaleTypePopup selectItemAtIndex:self.scaleType];
    self.scaleTypePopup.target = self;
    self.scaleTypePopup.action = @selector(scaleTypeChanged:);
    self.scaleTypePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.scaleTypePopup];
    
    // Max bars field
    self.maxBarsField = [[NSTextField alloc] init];
    self.maxBarsField.stringValue = [NSString stringWithFormat:@"%ld", self.maxBars];
    self.maxBarsField.placeholderString = @"Max bars";
    self.maxBarsField.target = self;
    self.maxBarsField.action = @selector(maxBarsChanged:);
    self.maxBarsField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.maxBarsField];
    
    // Volume checkbox
    self.volumeCheckbox = [[NSButton alloc] init];
    [self.volumeCheckbox setButtonType:NSButtonTypeSwitch];
    self.volumeCheckbox.title = @"Volume";
    self.volumeCheckbox.state = self.showVolume ? NSControlStateValueOn : NSControlStateValueOff;
    self.volumeCheckbox.target = self;
    self.volumeCheckbox.action = @selector(volumeCheckboxChanged:);
    self.volumeCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.volumeCheckbox];
    
    // Columns control
    self.columnsControl = [[NSSegmentedControl alloc] init];
    self.columnsControl.segmentCount = 4;
    [self.columnsControl setLabel:@"2" forSegment:0];
    [self.columnsControl setLabel:@"3" forSegment:1];
    [self.columnsControl setLabel:@"4" forSegment:2];
    [self.columnsControl setLabel:@"5" forSegment:3];
    self.columnsControl.selectedSegment = 1; // Default to 3 columns
    self.columnsControl.target = self;
    self.columnsControl.action = @selector(columnsChanged:);
    self.columnsControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.columnsControl];
    
    // Refresh button
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.title = @"↻";
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshAllCharts);
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.refreshButton];
}

- (void)setupChartsView {
    // Scroll view for charts
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.scrollView];
    
    // Charts container
    self.chartsContainer = [[NSView alloc] init];
    self.chartsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.chartsContainer;
    
    // IMPORTANTE: Fissa la larghezza del container alla scroll view
    [NSLayoutConstraint activateConstraints:@[
        [self.chartsContainer.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
}

- (void)setupConstraints {
    // Controls view constraints - aumenta altezza per i controlli aggiuntivi
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.controlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.controlsView.heightAnchor constraintEqualToConstant:90] // Aumentato da 60 a 90
    ]];
    
    // Symbols text field - prima riga
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolsTextField.topAnchor constraintEqualToAnchor:self.controlsView.topAnchor constant:8],
        [self.symbolsTextField.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor constant:8],
        [self.symbolsTextField.trailingAnchor constraintEqualToAnchor:self.controlsView.trailingAnchor constant:-8],
        [self.symbolsTextField.heightAnchor constraintEqualToConstant:22]
    ]];
    
    // Controlli su seconda riga
    [NSLayoutConstraint activateConstraints:@[
        [self.chartTypePopup.topAnchor constraintEqualToAnchor:self.symbolsTextField.bottomAnchor constant:8],
        [self.chartTypePopup.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor constant:8],
        [self.chartTypePopup.widthAnchor constraintEqualToConstant:80],
        
        [self.timeframePopup.topAnchor constraintEqualToAnchor:self.symbolsTextField.bottomAnchor constant:8],
        [self.timeframePopup.leadingAnchor constraintEqualToAnchor:self.chartTypePopup.trailingAnchor constant:8],
        [self.timeframePopup.widthAnchor constraintEqualToConstant:60],
        
        [self.scaleTypePopup.topAnchor constraintEqualToAnchor:self.symbolsTextField.bottomAnchor constant:8],
        [self.scaleTypePopup.leadingAnchor constraintEqualToAnchor:self.timeframePopup.trailingAnchor constant:8],
        [self.scaleTypePopup.widthAnchor constraintEqualToConstant:80],
        
        [self.maxBarsField.topAnchor constraintEqualToAnchor:self.symbolsTextField.bottomAnchor constant:8],
        [self.maxBarsField.leadingAnchor constraintEqualToAnchor:self.scaleTypePopup.trailingAnchor constant:8],
        [self.maxBarsField.widthAnchor constraintEqualToConstant:60]
    ]];
    
    // Controlli su terza riga
    [NSLayoutConstraint activateConstraints:@[
        [self.volumeCheckbox.topAnchor constraintEqualToAnchor:self.chartTypePopup.bottomAnchor constant:8],
        [self.volumeCheckbox.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor constant:8],
        [self.volumeCheckbox.widthAnchor constraintEqualToConstant:80],
        
        [self.columnsControl.topAnchor constraintEqualToAnchor:self.chartTypePopup.bottomAnchor constant:8],
        [self.columnsControl.leadingAnchor constraintEqualToAnchor:self.volumeCheckbox.trailingAnchor constant:8],
        [self.columnsControl.widthAnchor constraintEqualToConstant:120],
        
        [self.refreshButton.topAnchor constraintEqualToAnchor:self.chartTypePopup.bottomAnchor constant:8],
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.controlsView.trailingAnchor constant:-8],
        [self.refreshButton.widthAnchor constraintEqualToConstant:30]
    ]];
    
    // Scroll view constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:8],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - Properties

- (void)setSymbolsString:(NSString *)symbolsString {
    _symbolsString = symbolsString ?: @"";
    self.symbolsTextField.stringValue = _symbolsString;
    
    // Parse symbols
    NSArray<NSString *> *newSymbols = [self parseSymbolsFromString:_symbolsString];
    self.symbols = newSymbols;
}

- (void)setSymbols:(NSArray<NSString *> *)symbols {
    _symbols = symbols ?: @[];
    [self rebuildMiniCharts];
}

- (void)setColumnsCount:(NSInteger)columnsCount {
    [self setColumnsCount:columnsCount animated:YES];
}

- (void)setColumnsCount:(NSInteger)count animated:(BOOL)animated {
    _columnsCount = MAX(2, MIN(6, count)); // Clamp between 2-6
    [self layoutMiniChartsAnimated:animated];
}

#pragma mark - Symbol Management

- (NSArray<NSString *> *)parseSymbolsFromString:(NSString *)symbolsString {
    if (!symbolsString || symbolsString.length == 0) {
        return @[];
    }
    
    // Split by comma, clean whitespace, filter empty, uppercase
    NSArray<NSString *> *components = [symbolsString componentsSeparatedByString:@","];
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    
    for (NSString *symbol in components) {
        NSString *cleanSymbol = [[symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
        if (cleanSymbol.length > 0) {
            [symbols addObject:cleanSymbol];
        }
    }
    
    return [symbols copy];
}

- (void)setSymbolsFromString:(NSString *)symbolsString {
    self.symbolsString = symbolsString;
}

- (void)addSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    NSString *cleanSymbol = [[symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
    NSMutableArray *newSymbols = [self.symbols mutableCopy];
    
    if (![newSymbols containsObject:cleanSymbol]) {
        [newSymbols addObject:cleanSymbol];
        self.symbols = [newSymbols copy];
        self.symbolsString = [newSymbols componentsJoinedByString:@","];
    }
}

- (void)removeSymbol:(NSString *)symbol {
    NSMutableArray *newSymbols = [self.symbols mutableCopy];
    [newSymbols removeObject:symbol];
    self.symbols = [newSymbols copy];
    self.symbolsString = [newSymbols componentsJoinedByString:@","];
}

- (void)removeAllSymbols {
    self.symbols = @[];
    self.symbolsString = @"";
}

#pragma mark - Mini Charts Management

- (void)rebuildMiniCharts {
    // Remove existing charts
    for (MiniChart *chart in self.miniCharts) {
        [chart removeFromSuperview];
    }
    [self.miniCharts removeAllObjects];
    
    // Create new charts with current settings
    for (NSString *symbol in self.symbols) {
        MiniChart *miniChart = [MiniChart miniChartWithSymbol:symbol
                                                    chartType:self.chartType
                                                    timeframe:self.timeframe
                                                    scaleType:self.scaleType
                                                      maxBars:self.maxBars
                                                   showVolume:self.showVolume];
        miniChart.translatesAutoresizingMaskIntoConstraints = NO;
        [self.chartsContainer addSubview:miniChart];
        [self.miniCharts addObject:miniChart];
    }
    
    [self layoutMiniChartsAnimated:NO];
    [self refreshAllCharts];
}

- (void)layoutMiniChartsAnimated:(BOOL)animated {
    // Remove existing constraints
    [NSLayoutConstraint deactivateConstraints:self.chartConstraints];
    [self.chartConstraints removeAllObjects];
    
    if (self.miniCharts.count == 0) return;
    
    // DEBUG: Stampa le dimensioni attuali
    CGFloat containerWidth = CGRectGetWidth(self.scrollView.bounds);
    NSLog(@"🔍 ScrollView bounds: %@", NSStringFromRect(self.scrollView.bounds));
    NSLog(@"🔍 ScrollView frame: %@", NSStringFromRect(self.scrollView.frame));
    NSLog(@"🔍 Container width: %.2f", containerWidth);
    
    // Se la scrollView non ha ancora dimensioni, usa la contentView
    if (containerWidth <= 0) {
        containerWidth = CGRectGetWidth(self.contentView.bounds);
        NSLog(@"🔍 Using contentView width: %.2f", containerWidth);
    }
    
    // Se ancora zero, usa un fallback minimo
    if (containerWidth <= 0) {
        containerWidth = 600; // Fallback più piccolo
        NSLog(@"🔍 Using fallback width: %.2f", containerWidth);
    }
    
    CGFloat margin = 8.0;
    CGFloat availableWidth = containerWidth - (2 * margin);
    CGFloat chartWidth = (availableWidth - ((self.columnsCount - 1) * margin)) / self.columnsCount;
    CGFloat chartHeight = chartWidth * 0.75; // Rapporto 4:3
    
    NSLog(@"🔍 Calculated - ChartWidth: %.2f, ChartHeight: %.2f, Columns: %ld",
          chartWidth, chartHeight, self.columnsCount);
    
    NSInteger rows = (NSInteger)ceil((double)self.miniCharts.count / (double)self.columnsCount);
    
    for (NSInteger i = 0; i < self.miniCharts.count; i++) {
        MiniChart *chart = self.miniCharts[i];
        NSInteger row = i / self.columnsCount;
        NSInteger col = i % self.columnsCount;
        
        CGFloat xPos = margin + (col * (chartWidth + margin));
        CGFloat yPos = margin + (row * (chartHeight + margin));
        
        NSLog(@"🔍 Chart %ld (%@): position(%.1f, %.1f) size(%.1f, %.1f)",
              i, chart.symbol, xPos, yPos, chartWidth, chartHeight);
        
        // Position constraints
        NSLayoutConstraint *widthConstraint = [chart.widthAnchor constraintEqualToConstant:chartWidth];
        NSLayoutConstraint *heightConstraint = [chart.heightAnchor constraintEqualToConstant:chartHeight];
        
        NSLayoutConstraint *leadingConstraint = [chart.leadingAnchor constraintEqualToAnchor:self.chartsContainer.leadingAnchor
                                                                                    constant:xPos];
        NSLayoutConstraint *topConstraint = [chart.topAnchor constraintEqualToAnchor:self.chartsContainer.topAnchor
                                                                            constant:yPos];
        
        [self.chartConstraints addObjectsFromArray:@[widthConstraint, heightConstraint, leadingConstraint, topConstraint]];
    }
    
    // Container height (larghezza già fissata alla scroll view)
    CGFloat totalHeight = rows * chartHeight + (rows + 1) * margin;
    NSLayoutConstraint *containerHeightConstraint = [self.chartsContainer.heightAnchor constraintEqualToConstant:totalHeight];
    [self.chartConstraints addObject:containerHeightConstraint];
    
    NSLog(@"🔍 Total height: %.2f", totalHeight);
    
    // Activate constraints
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.3;
            context.allowsImplicitAnimation = YES;
            [NSLayoutConstraint activateConstraints:self.chartConstraints];
            [self.view layoutSubtreeIfNeeded];
        } completionHandler:nil];
    } else {
        [NSLayoutConstraint activateConstraints:self.chartConstraints];
    }
}


- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
   
        NSArray<NSString *> *symbols = update[@"symbols"];
    if ([symbols count]) {
        
    
        NSString *source = update[@"source"];
        NSString *watchlistName = update[@"watchlistName"];
        
        if (symbols && symbols.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // Aggiorna il campo simboli
                NSString *symbolsString = [symbols componentsJoinedByString:@","];
                [self setSymbolsFromString:symbolsString];
                
                // Mostra feedback
                [self showReceivedSymbolsMessage:symbols.count fromSource:source watchlistName:watchlistName];
                
                NSLog(@"📥 MultiChartWidget: Received %ld symbols from %@ (%@)",
                      symbols.count, source ?: @"unknown", watchlistName ?: @"");
            });
        }
    } else if (update[@"symbol"]) {
        // Gestione simbolo singolo (compatibilità)
        NSString *symbol = update[@"symbol"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self addSymbol:symbol];
        });
    }
}

- (void)showReceivedSymbolsMessage:(NSInteger)symbolCount fromSource:(NSString *)source watchlistName:(NSString *)watchlistName {
    NSString *message;
    if ([source isEqualToString:@"watchlist"]) {
        message = [NSString stringWithFormat:@"📥 Received %ld symbols from watchlist '%@'", symbolCount, watchlistName ?: @"Unknown"];
    } else {
        message = [NSString stringWithFormat:@"📥 Received %ld symbols", symbolCount];
    }
    
    // Usa lo stesso sistema di feedback del WatchlistWidget
    NSTextField *messageLabel = [[NSTextField alloc] init];
    messageLabel.stringValue = message;
    messageLabel.backgroundColor = [NSColor systemGreenColor];
    messageLabel.textColor = [NSColor controlAlternatingRowBackgroundColors].firstObject;
    messageLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    messageLabel.alignment = NSTextAlignmentCenter;
    messageLabel.bordered = NO;
    messageLabel.editable = NO;
    messageLabel.selectable = NO;
    messageLabel.wantsLayer = YES;
    messageLabel.layer.cornerRadius = 4;
    
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:messageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [messageLabel.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:8],
        [messageLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.contentView.widthAnchor constant:-16],
        [messageLabel.heightAnchor constraintEqualToConstant:28]
    ]];
    
    // Anima e rimuovi
    messageLabel.layer.opacity = 0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        messageLabel.animator.layer.opacity = 0.95;
    } completionHandler:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.3;
                messageLabel.animator.layer.opacity = 0;
            } completionHandler:^{
                [messageLabel removeFromSuperview];
            }];
        });
    }];
}

#pragma mark - Data Updates

- (void)refreshAllCharts {
    for (MiniChart *chart in self.miniCharts) {
        [self refreshChartForSymbol:chart.symbol];
    }
}

- (void)refreshChartForSymbol:(NSString *)symbol {
    MiniChart *chart = [self miniChartForSymbol:symbol];
    if (!chart) return;
    
    [self.dataQueue addOperationWithBlock:^{
        // Convert MiniChartTimeframe to BarTimeframe
        BarTimeframe barTimeframe = [self barTimeframeFromMiniTimeframe:self.timeframe];
        
        // Calculate date range based on timeframe
        NSDate *endDate = [NSDate date];
        NSDate *startDate = [self startDateForTimeframe:barTimeframe];
        
        // Usa il metodo corretto di DataManager con tutti i parametri
        [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                          timeframe:barTimeframe
                                                          startDate:startDate
                                                            endDate:endDate
                                                         completion:^(NSArray<HistoricalBar *> *bars, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [chart setError:error.localizedDescription];
                } else {
                    [chart updateWithPriceData:bars];
                }
            });
        }];
    }];
}

- (NSDate *)startDateForTimeframe:(BarTimeframe)timeframe {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    
    switch (timeframe) {
        case BarTimeframe1Min:
            return [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:now options:0];
        case BarTimeframe5Min:
            return [calendar dateByAddingUnit:NSCalendarUnitDay value:-3 toDate:now options:0];
        case BarTimeframe15Min:
            return [calendar dateByAddingUnit:NSCalendarUnitWeekOfYear value:-1 toDate:now options:0];
        case BarTimeframe1Hour:
            return [calendar dateByAddingUnit:NSCalendarUnitWeekOfYear value:-2 toDate:now options:0];
        case BarTimeframe1Day:
            return [calendar dateByAddingUnit:NSCalendarUnitYear value:-1 toDate:now options:0];
        case BarTimeframe1Week:
            return [calendar dateByAddingUnit:NSCalendarUnitYear value:-3 toDate:now options:0];
        default:
            return [calendar dateByAddingUnit:NSCalendarUnitYear value:-1 toDate:now options:0];
    }
}

- (MiniChart *)miniChartForSymbol:(NSString *)symbol {
    for (MiniChart *chart in self.miniCharts) {
        if ([chart.symbol isEqualToString:symbol]) {
            return chart;
        }
    }
    return nil;
}

- (BarTimeframe)barTimeframeFromMiniTimeframe:(MiniChartTimeframe)miniTimeframe {
    switch (miniTimeframe) {
        case MiniChartTimeframe1Min: return BarTimeframe1Min;
        case MiniChartTimeframe5Min: return BarTimeframe5Min;
        case MiniChartTimeframe15Min: return BarTimeframe15Min;
        case MiniChartTimeframe1Hour: return BarTimeframe1Hour;
        case MiniChartTimeframe4Hour: return BarTimeframe4Hour;
        case MiniChartTimeframeDaily: return BarTimeframe1Day;
        case MiniChartTimeframeWeekly: return BarTimeframe1Week;
        default: return BarTimeframe1Day;
    }
}

#pragma mark - Auto Refresh

- (void)startAutoRefresh {
    [self stopAutoRefresh];
    
    // Refresh every 30 seconds for intraday, 5 minutes for daily+
    NSTimeInterval interval = (self.timeframe <= MiniChartTimeframe4Hour) ? 30.0 : 300.0;
    
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                         target:self
                                                       selector:@selector(refreshAllCharts)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopAutoRefresh {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

#pragma mark - Actions

- (void)symbolsTextChanged:(id)sender {
    NSString *newSymbolsString = self.symbolsTextField.stringValue;
    [self setSymbolsFromString:newSymbolsString];
}

- (void)chartTypeChanged:(id)sender {
    self.chartType = (MiniChartType)self.chartTypePopup.indexOfSelectedItem;
    
    // Update all existing charts
    for (MiniChart *chart in self.miniCharts) {
        chart.chartType = self.chartType;
        [chart setNeedsDisplay:YES];
    }
}

- (void)timeframeChanged:(id)sender {
    self.timeframe = (MiniChartTimeframe)self.timeframePopup.indexOfSelectedItem;
    
    // Update all existing charts and refresh data
    for (MiniChart *chart in self.miniCharts) {
        chart.timeframe = self.timeframe;
    }
    
    [self refreshAllCharts];
    [self startAutoRefresh]; // Restart timer with new interval
}

- (void)scaleTypeChanged:(id)sender {
    self.scaleType = (MiniChartScaleType)self.scaleTypePopup.indexOfSelectedItem;
    
    // Update all existing charts
    for (MiniChart *chart in self.miniCharts) {
        chart.scaleType = self.scaleType;
        [chart setNeedsDisplay:YES];
    }
}

- (void)maxBarsChanged:(id)sender {
    NSInteger newMaxBars = [self.maxBarsField.stringValue integerValue];
    if (newMaxBars > 0 && newMaxBars <= 1000) { // Limite ragionevole
        self.maxBars = newMaxBars;
        
        // Update all existing charts
        for (MiniChart *chart in self.miniCharts) {
            chart.maxBars = self.maxBars;
            [chart setNeedsDisplay:YES];
        }
        
        [self refreshAllCharts]; // Ricarica i dati con il nuovo limite
    } else {
        // Reset to previous valid value
        self.maxBarsField.stringValue = [NSString stringWithFormat:@"%ld", self.maxBars];
    }
}

- (void)volumeCheckboxChanged:(id)sender {
    self.showVolume = (self.volumeCheckbox.state == NSControlStateValueOn);
    
    // Update all existing charts
    for (MiniChart *chart in self.miniCharts) {
        chart.showVolume = self.showVolume;
        
        // Forza il rebuild dei constraints per ogni chart
        [chart setNeedsUpdateConstraints:YES];
       // [chart updateConstraintsIfNeeded];
        [chart setNeedsDisplay:YES];
    }
}

- (void)columnsChanged:(id)sender {
    NSInteger newColumnCount = self.columnsControl.selectedSegment + 2; // 0->2, 1->3, 2->4, 3->5
    [self setColumnsCount:newColumnCount animated:YES];
}

#pragma mark - Layout Optimization

- (void)optimizeLayoutForSize:(NSSize)size {
    // Ricalcola il layout quando cambia la dimensione
    [self layoutMiniChartsAnimated:YES];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self startAutoRefresh];
    
    // Osserva i cambiamenti di dimensione
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewFrameDidChange:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self.view];
}

- (void)viewFrameDidChange:(NSNotification *)notification {
    // Ricalcola il layout quando cambia la dimensione della view
    [self performSelector:@selector(relayoutCharts) withObject:nil afterDelay:0.1];
}

- (void)relayoutCharts {
    [self layoutMiniChartsAnimated:NO];
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
    [self stopAutoRefresh];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopAutoRefresh];
    [self.dataQueue cancelAllOperations];
}

@end
