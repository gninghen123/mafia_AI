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
    [self registerForNotifications];
}

#pragma mark - Notifications

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Registra per le notifiche corrette di DataHub
    [nc addObserver:self
           selector:@selector(marketQuoteUpdated:)
               name:@"DataHubMarketQuoteUpdated"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(historicalDataUpdated:)
               name:@"DataHubHistoricalDataUpdated"
             object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.refreshTimer invalidate];
}

#pragma mark - UI Setup

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
    [self.timeframePopup selectItemAtIndex:5]; // Daily default
    self.timeframePopup.target = self;
    self.timeframePopup.action = @selector(timeframeChanged:);
    self.timeframePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.timeframePopup];
    
    // Scale type popup
    self.scaleTypePopup = [[NSPopUpButton alloc] init];
    [self.scaleTypePopup addItemWithTitle:@"Linear"];
    [self.scaleTypePopup addItemWithTitle:@"Logarithmic"];
    [self.scaleTypePopup selectItemAtIndex:self.scaleType];
    self.scaleTypePopup.target = self;
    self.scaleTypePopup.action = @selector(scaleTypeChanged:);
    self.scaleTypePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.scaleTypePopup];
    
    // Max bars field
    self.maxBarsField = [[NSTextField alloc] init];
    self.maxBarsField.placeholderString = @"Max bars";
    self.maxBarsField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.maxBars];
    self.maxBarsField.target = self;
    self.maxBarsField.action = @selector(maxBarsChanged:);
    self.maxBarsField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.maxBarsField];
    
    // Volume checkbox
    self.volumeCheckbox = [[NSButton alloc] init];
    self.volumeCheckbox.buttonType = NSButtonTypeSwitch;
    self.volumeCheckbox.title = @"Show Volume";
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
        @"scrollView": self.scrollView,
        @"symbols": self.symbolsTextField,
        @"chartType": self.chartTypePopup,
        @"timeframe": self.timeframePopup,
        @"scale": self.scaleTypePopup,
        @"maxBars": self.maxBarsField,
        @"volume": self.volumeCheckbox,
        @"columns": self.columnsControl,
        @"refresh": self.refreshButton
    };
    
    // Content view constraints
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[controls]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[scrollView]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[controls(50)][scrollView]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    
    // Controls layout
    [self.controlsView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[symbols(200)]-[chartType(80)]-[timeframe(80)]-[scale(100)]-[maxBars(60)]-[volume]-[columns(160)]-[refresh]-|"
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
    DataHub *hub = [DataHub shared];
    NSString *symbol = miniChart.symbol;
    
    // Mostra loading
    [miniChart setLoading:YES];
    
    // Carica quote corrente
    MarketQuote *quote = [hub getQuoteForSymbol:symbol];
    if (quote) {
        miniChart.currentPrice = @(quote.currentPrice);
        miniChart.priceChange = @(quote.change);
        miniChart.percentChange = @(quote.changePercent);
    }
    
    // Carica dati storici
    BarTimeframe barTimeframe = [self barTimeframeFromMiniTimeframe:miniChart.timeframe];
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self calculateStartDateForTimeframe:barTimeframe bars:miniChart.maxBars];
    
    NSArray<HistoricalBar *> *bars = [hub getHistoricalBarsForSymbol:symbol
                                                           timeframe:barTimeframe
                                                           startDate:startDate
                                                             endDate:endDate];
    
    if (bars.count > 0) {
        // Limita al numero massimo di barre
        if (bars.count > miniChart.maxBars) {
            NSInteger startIndex = bars.count - miniChart.maxBars;
            bars = [bars subarrayWithRange:NSMakeRange(startIndex, miniChart.maxBars)];
        }
        
        [miniChart updateWithPriceData:bars];
        [miniChart setLoading:NO];
    } else {
        // Se non ci sono dati, richiedi aggiornamento
        [self requestDataUpdateForSymbol:symbol timeframe:barTimeframe];
        [miniChart setError:@"Loading data..."];
    }
}

#pragma mark - Data Updates

- (void)refreshAllCharts {
    
    // Per ogni simbolo, carica i dati disponibili e richiedi aggiornamenti se necessario
    for (MiniChart *miniChart in self.miniCharts) {
        NSString *symbol = miniChart.symbol;
        BarTimeframe timeframe = [self barTimeframeFromMiniTimeframe:miniChart.timeframe];
        
        // Carica i dati correnti
        [self loadDataForMiniChart:miniChart];
        
        // Richiedi aggiornamento se i dati sono vecchi o mancanti
        [self checkAndRequestDataUpdateForSymbol:symbol timeframe:timeframe];
    }
}

- (void)refreshChartForSymbol:(NSString *)symbol {
    MiniChart *chart = [self miniChartForSymbol:symbol];
    if (chart) {
        [self loadDataForMiniChart:chart];
        
        // Richiedi aggiornamento dati
        BarTimeframe timeframe = [self barTimeframeFromMiniTimeframe:chart.timeframe];
        [self checkAndRequestDataUpdateForSymbol:symbol timeframe:timeframe];
    }
}

#pragma mark - Data Update Requests

- (void)requestDataUpdateForSymbol:(NSString *)symbol timeframe:(BarTimeframe)timeframe {
    // DataHub gestisce internamente la richiesta a DataManager
    // Utilizziamo il metodo che esiste già in DataHub+MarketData
    DataHub *hub = [DataHub shared];
    [hub requestHistoricalDataUpdateForSymbol:symbol timeframe:timeframe];
}

- (void)checkAndRequestDataUpdateForSymbol:(NSString *)symbol timeframe:(BarTimeframe)timeframe {
    DataHub *hub = [DataHub shared];
    
    // Verifica quando sono stati aggiornati i dati l'ultima volta
    NSDate *now = [NSDate date];
    NSDate *fiveMinutesAgo = [now dateByAddingTimeInterval:-300];
    
    // Se non abbiamo dati recenti, richiedi aggiornamento
    NSArray<HistoricalBar *> *recentBars = [hub getHistoricalBarsForSymbol:symbol
                                                                 timeframe:timeframe
                                                                 startDate:fiveMinutesAgo
                                                                   endDate:now];
    
    if (recentBars.count == 0) {
        // I dati sono vecchi o mancanti
        [self requestDataUpdateForSymbol:symbol timeframe:timeframe];
    }
}

#pragma mark - Symbol Management

- (void)setSymbols:(NSArray<NSString *> *)symbols {
    _symbols = symbols ?: @[];
    [self rebuildMiniCharts];
    
    // Carica dati per i nuovi chart
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
        NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:chart
                                                                           attribute:NSLayoutAttributeWidth
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:nil
                                                                           attribute:NSLayoutAttributeNotAnAttribute
                                                                          multiplier:1.0
                                                                            constant:chartWidth];
        
        // Height constraint
        NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:chart
                                                                            attribute:NSLayoutAttributeHeight
                                                                            relatedBy:NSLayoutRelationEqual
                                                                               toItem:nil
                                                                            attribute:NSLayoutAttributeNotAnAttribute
                                                                           multiplier:1.0
                                                                             constant:chartHeight];
        
        // Position constraints
        NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:chart
                                                                          attribute:NSLayoutAttributeLeft
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:self.chartsContainer
                                                                          attribute:NSLayoutAttributeLeft
                                                                         multiplier:1.0
                                                                           constant:x];
        
        NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:chart
                                                                         attribute:NSLayoutAttributeTop
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.chartsContainer
                                                                         attribute:NSLayoutAttributeTop
                                                                        multiplier:1.0
                                                                          constant:y];
        
        [self.chartsContainer addConstraints:@[widthConstraint, heightConstraint, leftConstraint, topConstraint]];
        [self.chartConstraints addObjectsFromArray:@[widthConstraint, heightConstraint, leftConstraint, topConstraint]];
    }
}

#pragma mark - DataHub Notifications

- (void)historicalDataUpdated:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *symbol = userInfo[@"symbol"];
    NSNumber *timeframe = userInfo[@"timeframe"];
    
    // Trova il mini chart per questo simbolo
    MiniChart *chart = [self miniChartForSymbol:symbol];
    if (chart && [self barTimeframeFromMiniTimeframe:chart.timeframe] == timeframe.integerValue) {
        // Ricarica i dati per questo chart
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadDataForMiniChart:chart];
        });
    }
}

- (void)marketQuoteUpdated:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *symbol = userInfo[@"symbol"];
    MarketQuote *quote = userInfo[@"quote"];
    
    // Trova il mini chart per questo simbolo
    MiniChart *chart = [self miniChartForSymbol:symbol];
    if (chart && quote) {
        dispatch_async(dispatch_get_main_queue(), ^{
            chart.currentPrice = @(quote.currentPrice);
            chart.priceChange = @(quote.change);
            chart.percentChange = @(quote.changePercent);
            [chart setNeedsDisplay:YES];
        });
    }
}

#pragma mark - Helper Methods

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
    NSInteger maxBars = self.maxBarsField.integerValue;
    if (maxBars > 0 && maxBars <= 1000) {
        self.maxBars = maxBars;
        
        // Aggiorna tutti i chart e ricarica dati
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
    [self refreshAllCharts];
}

#pragma mark - Layout Management

- (void)setColumnsCount:(NSInteger)count animated:(BOOL)animated {
    if (count < 1) count = 1;
    if (count > 5) count = 5;
    
    _columnsCount = count;
    
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.3;
            context.allowsImplicitAnimation = YES;
            [self layoutMiniCharts];
        }];
    } else {
        [self layoutMiniCharts];
    }
}

- (void)optimizeLayoutForSize:(NSSize)size {
    // Calcola numero ottimale di colonne basato sulla dimensione
    CGFloat chartWidth = 300;
    CGFloat spacing = 10;
    
    NSInteger optimalColumns = (size.width - 2 * spacing) / (chartWidth + spacing);
    if (optimalColumns < 1) optimalColumns = 1;
    if (optimalColumns > 5) optimalColumns = 5;
    
    if (optimalColumns != self.columnsCount) {
        [self setColumnsCount:optimalColumns animated:YES];
        self.columnsControl.selectedSegment = optimalColumns - 1;
    }
}

#pragma mark - State Saving

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    state[@"symbols"] = self.symbols ?: @[];
    state[@"symbolsString"] = self.symbolsString ?: @"";
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
        self.symbols = state[@"symbols"];
    }
    
    if (state[@"symbolsString"]) {
        self.symbolsString = state[@"symbolsString"];
        self.symbolsTextField.stringValue = self.symbolsString;
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
