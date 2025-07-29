//
//  MultiChartWidget.m
//  TradingApp
//
//  Implementation of multi-symbol chart grid widget
//  Updated for full DataHub integration
//

#import "MultiChartWidget.h"
#import "MiniChart.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "MarketQuote+CoreDataClass.h"

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
    _maxBars = 100;
    _showVolume = YES;
    _columnsCount = 3;
    _symbols = @[];
    _symbolsString = @"";
    
    // Arrays
    _miniCharts = [NSMutableArray array];
    _chartConstraints = [NSMutableArray array];
    
    // Data queue
    _dataQueue = [[NSOperationQueue alloc] init];
    _dataQueue.maxConcurrentOperationCount = 4;
    _dataQueue.name = @"MultiChartDataQueue";
}

#pragma mark - View Setup

- (void)setupContentView {
    [super setupContentView];
    
    // Setup UI components
    [self setupControlsView];
    [self setupChartsView];
    [self setupConstraints];
    
    // Load initial data if we have symbols
    if (self.symbols.count > 0) {
        [self rebuildMiniCharts];
    }
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
    [self.timeframePopup addItemWithTitle:@"1 Min"];
    [self.timeframePopup addItemWithTitle:@"5 Min"];
    [self.timeframePopup addItemWithTitle:@"15 Min"];
    [self.timeframePopup addItemWithTitle:@"30 Min"];
    [self.timeframePopup addItemWithTitle:@"1 Hour"];
    [self.timeframePopup addItemWithTitle:@"Daily"];
    [self.timeframePopup addItemWithTitle:@"Weekly"];
    [self.timeframePopup addItemWithTitle:@"Monthly"];
    [self.timeframePopup selectItemAtIndex:5]; // Daily
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
    self.maxBarsField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.maxBars];
    self.maxBarsField.target = self;
    self.maxBarsField.action = @selector(maxBarsChanged:);
    self.maxBarsField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.maxBarsField];
    
    // Volume checkbox
    self.volumeCheckbox = [[NSButton alloc] init];
    self.volumeCheckbox.buttonType = NSSwitchButton;
    self.volumeCheckbox.title = @"Volume";
    self.volumeCheckbox.state = self.showVolume ? NSControlStateValueOn : NSControlStateValueOff;
    self.volumeCheckbox.target = self;
    self.volumeCheckbox.action = @selector(volumeCheckboxChanged:);
    self.volumeCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.volumeCheckbox];
    
    // Columns control
    self.columnsControl = [[NSSegmentedControl alloc] init];
    self.columnsControl.segmentCount = 5;
    for (int i = 0; i < 5; i++) {
        [self.columnsControl setLabel:[NSString stringWithFormat:@"%d", i+1] forSegment:i];
        [self.columnsControl setWidth:30.0 forSegment:i];
    }
    self.columnsControl.selectedSegment = self.columnsCount - 1;
    self.columnsControl.target = self;
    self.columnsControl.action = @selector(columnsChanged:);
    self.columnsControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.columnsControl];
    
    // Refresh button
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.title = @"Refresh";
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshButtonClicked:);
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.refreshButton];
}

- (void)setupChartsView {
    // Scroll view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.scrollView];
    
    // Charts container
    self.chartsContainer = [[NSView alloc] init];
    self.chartsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.chartsContainer;
}

- (void)setupConstraints {
    NSDictionary *views = @{
        @"controls": self.controlsView,
        @"scroll": self.scrollView
    };
    
    // Main layout
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[controls]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[scroll]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[controls(40)][scroll]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    
    // Controls layout
    views = @{
        @"symbols": self.symbolsTextField,
        @"chart": self.chartTypePopup,
        @"timeframe": self.timeframePopup,
        @"scale": self.scaleTypePopup,
        @"maxBars": self.maxBarsField,
        @"volume": self.volumeCheckbox,
        @"columns": self.columnsControl,
        @"refresh": self.refreshButton
    };
    
    [self.controlsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[symbols(>=200)]-[chart(80)]-[timeframe(80)]-[scale(100)]-[maxBars(60)]-[volume]-[columns(160)]-[refresh]-|"
                                                                              options:NSLayoutFormatAlignAllCenterY
                                                                              metrics:nil
                                                                                views:views]];
    
    [self.controlsView addConstraint:[NSLayoutConstraint constraintWithItem:self.symbolsTextField
                                                                  attribute:NSLayoutAttributeCenterY
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.controlsView
                                                                  attribute:NSLayoutAttributeCenterY
                                                                 multiplier:1.0
                                                                   constant:0]];
}

#pragma mark - View Lifecycle

- (void)viewWillAppear {
    [super viewWillAppear];
    [self startAutoRefresh];
    [self loadDataFromDataHub];
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
    [self stopAutoRefresh];
}

#pragma mark - Data Loading from DataHub

- (void)loadDataFromDataHub {
    for (MiniChart *miniChart in self.miniCharts) {
        [self loadDataForMiniChart:miniChart];
    }
}

- (void)loadDataForMiniChart:(MiniChart *)miniChart {
    NSString *symbol = miniChart.symbol;
    if (!symbol) return;
    
    // Mostra loading
    [miniChart setLoading:YES];
    
    // Carica quote corrente con il nuovo metodo asincrono
    [[DataHub shared] getQuoteForSymbol:symbol completion:^(MarketQuote *quote, BOOL isLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (quote) {
                miniChart.currentPrice = @(quote.currentPrice);
                miniChart.priceChange = @(quote.change);
                miniChart.percentChange = @(quote.changePercent);
            }
            
            // Ora carica i dati storici
            [self loadHistoricalDataForMiniChart:miniChart];
        });
    }];
}

- (void)loadHistoricalDataForMiniChart:(MiniChart *)miniChart {
    NSString *symbol = miniChart.symbol;
    if (!symbol) return;
    
    BarTimeframe barTimeframe = [self barTimeframeFromMiniTimeframe:miniChart.timeframe];
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self calculateStartDateForTimeframe:barTimeframe bars:miniChart.maxBars];
    
    [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                        timeframe:barTimeframe
                                        startDate:startDate
                                          endDate:endDate
                                       completion:^(NSArray<HistoricalBar *> *bars, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bars && bars.count > 0) {
                // Limita al numero massimo di barre
                NSArray<HistoricalBar *> *limitedBars = bars;
                if (bars.count > miniChart.maxBars) {
                    NSInteger startIndex = bars.count - miniChart.maxBars;
                    limitedBars = [bars subarrayWithRange:NSMakeRange(startIndex, miniChart.maxBars)];
                }
                
                [miniChart updateWithPriceData:limitedBars];
                [miniChart setLoading:NO];
            } else {
                [miniChart setError:@"No data available"];
                [miniChart setLoading:NO];
            }
        });
    }];
}

#pragma mark - Data Updates

- (void)refreshAllCharts {
    for (MiniChart *miniChart in self.miniCharts) {
        [self refreshMiniChart:miniChart];
    }
}

- (void)refreshChartForSymbol:(NSString *)symbol {
    MiniChart *chart = [self miniChartForSymbol:symbol];
    if (chart) {
        [self refreshMiniChart:chart];
    }
}

- (void)refreshMiniChart:(MiniChart *)miniChart {
    NSString *symbol = miniChart.symbol;
    if (!symbol) return;
    
    // Forza refresh dei dati quote
    [[DataHub shared] refreshQuoteForSymbol:symbol completion:^(MarketQuote *quote, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (quote && !error) {
                miniChart.currentPrice = @(quote.currentPrice);
                miniChart.priceChange = @(quote.change);
                miniChart.percentChange = @(quote.changePercent);
                
                // Aggiorna anche i dati storici
                [self loadHistoricalDataForMiniChart:miniChart];
            } else {
                [miniChart setError:@"Update failed"];
            }
        });
    }];
}

#pragma mark - Helper Methods

- (BarTimeframe)barTimeframeFromMiniTimeframe:(MiniChartTimeframe)miniTimeframe {
    switch (miniTimeframe) {
        case MiniChartTimeframe1Min:
            return BarTimeframe1Min;
        case MiniChartTimeframe5Min:
            return BarTimeframe5Min;
        case MiniChartTimeframe15Min:
            return BarTimeframe15Min;
        case MiniChartTimeframe30Min:
            return BarTimeframe30Min;
        case MiniChartTimeframe1Hour:
            return BarTimeframe1Hour;
        case MiniChartTimeframeDaily:
            return BarTimeframe1Day;
        case MiniChartTimeframeWeekly:
            return BarTimeframe1Week;
        case MiniChartTimeframeMonthly:
            return BarTimeframe1Month;
        default:
            return BarTimeframe1Day;
    }
}

- (NSDate *)calculateStartDateForTimeframe:(BarTimeframe)timeframe bars:(NSInteger)bars {
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    
    switch (timeframe) {
        case BarTimeframe1Min:
            components.minute = -bars;
            break;
        case BarTimeframe5Min:
            components.minute = -bars * 5;
            break;
        case BarTimeframe15Min:
            components.minute = -bars * 15;
            break;
        case BarTimeframe30Min:
            components.minute = -bars * 30;
            break;
        case BarTimeframe1Hour:
            components.hour = -bars;
            break;
        case BarTimeframe1Day:
            components.day = -bars;
            break;
        case BarTimeframe1Week:
            components.weekOfYear = -bars;
            break;
        case BarTimeframe1Month:
            components.month = -bars;
            break;
    }
    
    return [calendar dateByAddingComponents:components toDate:now options:0];
}

- (MiniChart *)miniChartForSymbol:(NSString *)symbol {
    for (MiniChart *chart in self.miniCharts) {
        if ([chart.symbol isEqualToString:symbol]) {
            return chart;
        }
    }
    return nil;
}

#pragma mark - Auto Refresh

- (void)startAutoRefresh {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
    }
    
    // Refresh ogni 240 secondi
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:240.0
                                                         target:self
                                                       selector:@selector(autoRefreshTimerFired:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopAutoRefresh {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)autoRefreshTimerFired:(NSTimer *)timer {
    [self refreshAllCharts];
}

#pragma mark - UI Actions

- (void)symbolsTextChanged:(id)sender {
    [self setSymbolsFromString:self.symbolsTextField.stringValue];
}

- (void)chartTypeChanged:(id)sender {
    self.chartType = (MiniChartType)self.chartTypePopup.indexOfSelectedItem;
    
    // Aggiorna tutti i chart
    for (MiniChart *chart in self.miniCharts) {
        chart.chartType = self.chartType;
        [chart setNeedsDisplay:YES];
    }
}

- (void)timeframeChanged:(id)sender {
    NSInteger index = self.timeframePopup.indexOfSelectedItem;
    self.timeframe = (MiniChartTimeframe)index;
    
    // Aggiorna tutti i chart e ricarica dati
    for (MiniChart *chart in self.miniCharts) {
        chart.timeframe = self.timeframe;
    }
    
    [self loadDataFromDataHub];
}

- (void)scaleTypeChanged:(id)sender {
    self.scaleType = (MiniChartScaleType)self.scaleTypePopup.indexOfSelectedItem;
    
    // Aggiorna tutti i chart
    for (MiniChart *chart in self.miniCharts) {
        chart.scaleType = self.scaleType;
        [chart setNeedsDisplay:YES];
    }
}

- (void)maxBarsChanged:(id)sender {
    NSInteger newMaxBars = self.maxBarsField.integerValue;
    if (newMaxBars > 0 && newMaxBars <= 500) {
        self.maxBars = newMaxBars;
        
        // Aggiorna tutti i chart
        for (MiniChart *chart in self.miniCharts) {
            chart.maxBars = self.maxBars;
        }
        
        [self loadDataFromDataHub];
    }
}

- (void)volumeCheckboxChanged:(id)sender {
    self.showVolume = (self.volumeCheckbox.state == NSControlStateValueOn);
    
    // Aggiorna tutti i chart
    for (MiniChart *chart in self.miniCharts) {
        chart.showVolume = self.showVolume;
        [chart setNeedsDisplay:YES];
    }
}

- (void)columnsChanged:(id)sender {
    NSInteger newColumns = self.columnsControl.selectedSegment + 1;
    [self setColumnsCount:newColumns animated:YES];
}

- (void)refreshButtonClicked:(id)sender {
    self.refreshButton.enabled = NO;
    [self refreshAllCharts];
    
    // Riabilita dopo 1 secondo per evitare spam
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.refreshButton.enabled = YES;
    });
}

#pragma mark - Symbol Management

- (void)setSymbols:(NSArray<NSString *> *)symbols {
    _symbols = symbols ?: @[];
    [self rebuildMiniCharts];
    [self loadDataFromDataHub];
}

- (void)setSymbolsFromString:(NSString *)symbolsString {
    self.symbolsString = symbolsString ?: @"";
    
    // Parse symbols
    NSMutableArray *parsedSymbols = [NSMutableArray array];
    NSArray *components = [symbolsString componentsSeparatedByString:@","];
    
    for (NSString *symbol in components) {
        NSString *trimmed = [symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            [parsedSymbols addObject:trimmed.uppercaseString];
        }
    }
    
    self.symbols = parsedSymbols;
}

- (void)addSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    NSMutableArray *mutableSymbols = [self.symbols mutableCopy] ?: [NSMutableArray array];
    NSString *upperSymbol = symbol.uppercaseString;
    
    if (![mutableSymbols containsObject:upperSymbol]) {
        [mutableSymbols addObject:upperSymbol];
        self.symbols = mutableSymbols;
    }
}

- (void)removeSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    NSMutableArray *mutableSymbols = [self.symbols mutableCopy];
    [mutableSymbols removeObject:symbol.uppercaseString];
    self.symbols = mutableSymbols;
}

- (void)removeAllSymbols {
    self.symbols = @[];
}

#pragma mark - MiniChart Management

- (void)rebuildMiniCharts {
    // Rimuovi chart esistenti
    for (MiniChart *chart in self.miniCharts) {
        [chart removeFromSuperview];
    }
    [self.miniCharts removeAllObjects];
    
    // Rimuovi constraints
    [self.chartsContainer removeConstraints:self.chartConstraints];
    [self.chartConstraints removeAllObjects];
    
    // Crea nuovi chart
    for (NSString *symbol in self.symbols) {
        MiniChart *miniChart = [[MiniChart alloc] init];
        miniChart.symbol = symbol;
        miniChart.chartType = self.chartType;
        miniChart.timeframe = self.timeframe;
        miniChart.scaleType = self.scaleType;
        miniChart.maxBars = self.maxBars;
        miniChart.showVolume = self.showVolume;
        miniChart.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self.chartsContainer addSubview:miniChart];
        [self.miniCharts addObject:miniChart];
    }
    
    // Layout charts
    [self layoutMiniCharts];
    
    // Carica dati per i nuovi chart
    for (MiniChart *miniChart in self.miniCharts) {
        [self loadDataForMiniChart:miniChart];
    }
}

- (void)layoutMiniCharts {
    if (self.miniCharts.count == 0) return;
    
    NSInteger columns = self.columnsCount;
    NSInteger rows = (self.miniCharts.count + columns - 1) / columns;
    
    CGFloat chartWidth = 300;
    CGFloat chartHeight = 200;
    CGFloat spacing = 10;
    
    // Calcola dimensione container
    CGFloat containerWidth = columns * chartWidth + (columns - 1) * spacing + 2 * spacing;
    CGFloat containerHeight = rows * chartHeight + (rows - 1) * spacing + 2 * spacing;
    
    // Imposta dimensione container
    [self.chartsContainer addConstraint:[NSLayoutConstraint constraintWithItem:self.chartsContainer
                                                                     attribute:NSLayoutAttributeWidth
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0
                                                                      constant:containerWidth]];
    
    [self.chartsContainer addConstraint:[NSLayoutConstraint constraintWithItem:self.chartsContainer
                                                                     attribute:NSLayoutAttributeHeight
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0
                                                                      constant:containerHeight]];
    
    // Layout mini charts
    for (NSInteger i = 0; i < self.miniCharts.count; i++) {
        MiniChart *chart = self.miniCharts[i];
        NSInteger row = i / columns;
        NSInteger col = i % columns;
        
        CGFloat x = spacing + col * (chartWidth + spacing);
        CGFloat y = spacing + row * (chartHeight + spacing);
        
        // Width constraint
        [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:chart
                                                                      attribute:NSLayoutAttributeWidth
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:nil
                                                                      attribute:NSLayoutAttributeNotAnAttribute
                                                                     multiplier:1.0
                                                                       constant:chartWidth]];
        
        // Height constraint
        [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:chart
                                                                      attribute:NSLayoutAttributeHeight
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:nil
                                                                      attribute:NSLayoutAttributeNotAnAttribute
                                                                     multiplier:1.0
                                                                       constant:chartHeight]];
        
        // X position
        [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:chart
                                                                      attribute:NSLayoutAttributeLeading
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.chartsContainer
                                                                      attribute:NSLayoutAttributeLeading
                                                                     multiplier:1.0
                                                                       constant:x]];
        
        // Y position
        [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:chart
                                                                      attribute:NSLayoutAttributeTop
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.chartsContainer
                                                                      attribute:NSLayoutAttributeTop
                                                                     multiplier:1.0
                                                                       constant:y]];
    }
    
    [self.chartsContainer addConstraints:self.chartConstraints];
}

#pragma mark - Layout Management

- (void)setColumnsCount:(NSInteger)count animated:(BOOL)animated {
    if (count < 1) count = 1;
    if (count > 5) count = 5;
    
    _columnsCount = count;
    self.columnsControl.selectedSegment = count - 1;
    
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.3;
            [self layoutMiniCharts];
        }];
    } else {
        [self layoutMiniCharts];
    }
}

- (void)optimizeLayoutForSize:(NSSize)size {
    // Calcola numero ottimale di colonne basato sulla larghezza
    CGFloat chartWidth = 300;
    CGFloat spacing = 10;
    
    NSInteger optimalColumns = (size.width - 2 * spacing) / (chartWidth + spacing);
    if (optimalColumns < 1) optimalColumns = 1;
    if (optimalColumns > 5) optimalColumns = 5;
    
    [self setColumnsCount:optimalColumns animated:YES];
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    state[@"symbols"] = self.symbolsString ?: @"";
    state[@"chartType"] = @(self.chartType);
    state[@"timeframe"] = @(self.timeframe);
    state[@"scaleType"] = @(self.scaleType);
    state[@"maxBars"] = @(self.maxBars);
    state[@"showVolume"] = @(self.showVolume);
    state[@"columnsCount"] = @(self.columnsCount);
    
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    if (state[@"symbols"]) {
        [self setSymbolsFromString:state[@"symbols"]];
    }
    
    if (state[@"chartType"]) {
        self.chartType = [state[@"chartType"] integerValue];
        [self.chartTypePopup selectItemAtIndex:self.chartType];
    }
    
    if (state[@"timeframe"]) {
        self.timeframe = [state[@"timeframe"] integerValue];
        [self.timeframePopup selectItemAtIndex:self.timeframe];
    }
    
    if (state[@"scaleType"]) {
        self.scaleType = [state[@"scaleType"] integerValue];
        [self.scaleTypePopup selectItemAtIndex:self.scaleType];
    }
    
    if (state[@"maxBars"]) {
        self.maxBars = [state[@"maxBars"] integerValue];
        self.maxBarsField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.maxBars];
    }
    
    if (state[@"showVolume"]) {
        self.showVolume = [state[@"showVolume"] boolValue];
        self.volumeCheckbox.state = self.showVolume ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    if (state[@"columnsCount"]) {
        self.columnsCount = [state[@"columnsCount"] integerValue];
        self.columnsControl.selectedSegment = self.columnsCount - 1;
    }
}

@end
