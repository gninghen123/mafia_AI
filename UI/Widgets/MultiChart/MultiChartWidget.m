//
//  MultiChartWidget.m
//  TradingApp
//
//  Implementation of multi-symbol chart grid widget
//  REWRITTEN: Uses ONLY DataHub+MarketData and RuntimeModels
//

#import "MultiChartWidget.h"
#import "MiniChart.h"
#import "DataHub+MarketData.h"
#import "RuntimeModels.h"

// REMOVED: All Core Data imports
// #import "HistoricalBar+CoreDataClass.h"
// #import "MarketQuote+CoreDataClass.h"

@interface MultiChartWidget ()

// UI Components - Only declare internal ones not in header
@property (nonatomic, strong) NSView *controlsView;
@property (nonatomic, strong) NSButton *refreshButton;

// Layout
@property (nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *chartConstraints;

// Data management
@property (nonatomic, strong) NSTimer *refreshTimer;

@end

@implementation MultiChartWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        [self setupMultiChartDefaults];
        [self setupUI];
        [self registerForNotifications];
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
    
    // Initialize arrays that are in header
    _miniCharts = [NSMutableArray array];
    _chartConstraints = [NSMutableArray array];
}

- (void)setupUI {
    [self setupControlsView];
    [self setupScrollView];
}

- (void)setupControlsView {
    // Controls view at top
    self.controlsView = [[NSView alloc] init];
    self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.controlsView];
    
    // Symbols text field
    self.symbolsTextField = [[NSTextField alloc] init];
    self.symbolsTextField.placeholderString = @"Enter symbols (AAPL, TSLA, MSFT...)";
    self.symbolsTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.symbolsTextField setTarget:self];
    [self.symbolsTextField setAction:@selector(symbolsChanged:)];
    [self.controlsView addSubview:self.symbolsTextField];
    
    // Chart type popup
    self.chartTypePopup = [[NSPopUpButton alloc] init];
    [self.chartTypePopup addItemsWithTitles:@[@"Line", @"Candle", @"Bar"]];
    self.chartTypePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartTypePopup setTarget:self];
    [self.chartTypePopup setAction:@selector(chartTypeChanged:)];
    [self.controlsView addSubview:self.chartTypePopup];
    
    // Timeframe popup
    self.timeframePopup = [[NSPopUpButton alloc] init];
    [self.timeframePopup addItemsWithTitles:@[@"1m", @"5m", @"15m", @"30m", @"1h", @"1D", @"1W", @"1M"]];
    [self.timeframePopup selectItemAtIndex:5]; // Default to Daily
    self.timeframePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.timeframePopup setTarget:self];
    [self.timeframePopup setAction:@selector(timeframeChanged:)];
    [self.controlsView addSubview:self.timeframePopup];
    
    // Scale type popup
    self.scaleTypePopup = [[NSPopUpButton alloc] init];
    [self.scaleTypePopup addItemsWithTitles:@[@"Linear", @"Log", @"Percent"]];
    self.scaleTypePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scaleTypePopup setTarget:self];
    [self.scaleTypePopup setAction:@selector(scaleTypeChanged:)];
    [self.controlsView addSubview:self.scaleTypePopup];
    
    // Max bars field
    self.maxBarsField = [[NSTextField alloc] init];
    self.maxBarsField.stringValue = @"100";
    self.maxBarsField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.maxBarsField setTarget:self];
    [self.maxBarsField setAction:@selector(maxBarsChanged:)];
    [self.controlsView addSubview:self.maxBarsField];
    
    // Volume checkbox
    self.volumeCheckbox = [NSButton checkboxWithTitle:@"Volume" target:self action:@selector(volumeCheckboxChanged:)];
    self.volumeCheckbox.state = NSControlStateValueOn;
    self.volumeCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.volumeCheckbox];
    
    // Columns control
    self.columnsControl = [[NSSegmentedControl alloc] init];
    self.columnsControl.segmentCount = 5;
    for (NSInteger i = 0; i < 5; i++) {
        [self.columnsControl setLabel:[NSString stringWithFormat:@"%ld", i + 1] forSegment:i];
    }
    self.columnsControl.selectedSegment = 2; // Default to 3 columns
    self.columnsControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.columnsControl setTarget:self];
    [self.columnsControl setAction:@selector(columnsChanged:)];
    [self.controlsView addSubview:self.columnsControl];
    
    // Refresh button
    self.refreshButton = [NSButton buttonWithTitle:@"Refresh" target:self action:@selector(refreshButtonClicked:)];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.refreshButton];
    
    [self setupControlsConstraints];
}

- (void)setupControlsConstraints {
    CGFloat spacing = 8;
    
    // Controls view
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.controlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.controlsView.heightAnchor constraintEqualToConstant:60]
    ]];
    
    // Symbols field (takes most space)
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolsTextField.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor constant:spacing],
        [self.symbolsTextField.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.symbolsTextField.widthAnchor constraintEqualToConstant:200]
    ]];
    
    // Chart type popup
    [NSLayoutConstraint activateConstraints:@[
        [self.chartTypePopup.leadingAnchor constraintEqualToAnchor:self.symbolsTextField.trailingAnchor constant:spacing],
        [self.chartTypePopup.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.chartTypePopup.widthAnchor constraintEqualToConstant:70]
    ]];
    
    // Timeframe popup
    [NSLayoutConstraint activateConstraints:@[
        [self.timeframePopup.leadingAnchor constraintEqualToAnchor:self.chartTypePopup.trailingAnchor constant:spacing],
        [self.timeframePopup.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.timeframePopup.widthAnchor constraintEqualToConstant:50]
    ]];
    
    // Scale type popup
    [NSLayoutConstraint activateConstraints:@[
        [self.scaleTypePopup.leadingAnchor constraintEqualToAnchor:self.timeframePopup.trailingAnchor constant:spacing],
        [self.scaleTypePopup.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.scaleTypePopup.widthAnchor constraintEqualToConstant:70]
    ]];
    
    // Max bars field
    [NSLayoutConstraint activateConstraints:@[
        [self.maxBarsField.leadingAnchor constraintEqualToAnchor:self.scaleTypePopup.trailingAnchor constant:spacing],
        [self.maxBarsField.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.maxBarsField.widthAnchor constraintEqualToConstant:50]
    ]];
    
    // Volume checkbox
    [NSLayoutConstraint activateConstraints:@[
        [self.volumeCheckbox.leadingAnchor constraintEqualToAnchor:self.maxBarsField.trailingAnchor constant:spacing],
        [self.volumeCheckbox.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor]
    ]];
    
    // Columns control
    [NSLayoutConstraint activateConstraints:@[
        [self.columnsControl.leadingAnchor constraintEqualToAnchor:self.volumeCheckbox.trailingAnchor constant:spacing],
        [self.columnsControl.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.columnsControl.widthAnchor constraintEqualToConstant:100]
    ]];
    
    // Refresh button
    [NSLayoutConstraint activateConstraints:@[
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.columnsControl.trailingAnchor constant:spacing],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.refreshButton.trailingAnchor constraintLessThanOrEqualToAnchor:self.controlsView.trailingAnchor constant:-spacing]
    ]];
}

- (void)setupScrollView {
    // Scroll view for charts
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.scrollView];
    
    // Charts container
    self.chartsContainer = [[NSView alloc] init];
    self.chartsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.chartsContainer;
    
    // Scroll view constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:8],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - Notifications

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Listen for DataHub quote updates
    [nc addObserver:self
           selector:@selector(quoteUpdated:)
               name:@"DataHubQuoteUpdatedNotification"
             object:nil];
    
    // Listen for DataHub historical data updates
    [nc addObserver:self
           selector:@selector(historicalDataUpdated:)
               name:@"DataHubHistoricalDataUpdatedNotification"
             object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopAutoRefresh];
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

#pragma mark - Data Loading (NEW - Runtime Models ONLY)

- (void)loadDataFromDataHub {
    NSLog(@"📊 MultiChartWidget: Loading data for %lu symbols", (unsigned long)self.symbols.count);
    
    for (MiniChart *miniChart in self.miniCharts) {
        [self loadDataForMiniChart:miniChart];
    }
}

- (void)loadDataForMiniChart:(MiniChart *)miniChart {
    NSString *symbol = miniChart.symbol;
    if (!symbol) return;
    
    NSLog(@"📊 Loading data for MiniChart: %@", symbol);
    
    // Mostra loading
    [miniChart setLoading:YES];
    
    // 1. Carica quote corrente usando il nuovo DataHub+MarketData
    [[DataHub shared] getQuoteForSymbol:symbol
                             completion:^(MarketQuoteModel *quote, BOOL isLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (quote) {
                // Aggiorna le proprietà del MiniChart con i RuntimeModel data
                miniChart.currentPrice = quote.last;
                miniChart.priceChange = quote.change;
                miniChart.percentChange = quote.changePercent;
                
                NSLog(@"📊 Quote loaded for %@: $%.2f (%.2f%%)", symbol,
                      [quote.last doubleValue], [quote.changePercent doubleValue]);
            }
            
            // 2. Ora carica i dati storici
            [self loadHistoricalDataForMiniChart:miniChart];
        });
    }];
}

- (void)loadHistoricalDataForMiniChart:(MiniChart *)miniChart {
    NSString *symbol = miniChart.symbol;
    if (!symbol) return;
    
    BarTimeframe barTimeframe = [self barTimeframeFromMiniTimeframe:miniChart.timeframe];
    NSInteger barCount = miniChart.maxBars;
    
    NSLog(@"📊 Loading historical data for %@: timeframe=%ld, count=%ld",
          symbol, (long)barTimeframe, (long)barCount);
    
    // Usa il nuovo DataHub+MarketData con Runtime Models
    [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                       timeframe:barTimeframe
                                        barCount:barCount
                                      completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bars && bars.count > 0) {
                NSLog(@"📊 Historical data loaded for %@: %lu bars (fresh: %@)",
                      symbol, (unsigned long)bars.count, isFresh ? @"YES" : @"NO");
                
                // Aggiorna il MiniChart con i RuntimeModel data
                [miniChart updateWithHistoricalBars:bars];
                [miniChart setLoading:NO];
            } else {
                NSLog(@"⚠️ No historical data for %@", symbol);
                [miniChart setError:@"No data available"];
                [miniChart setLoading:NO];
            }
        });
    }];
}

#pragma mark - Data Updates (NEW - Runtime Models)

- (void)refreshAllCharts {
    NSLog(@"🔄 MultiChartWidget: Refreshing all charts");
    
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
    
    NSLog(@"🔄 Refreshing MiniChart for %@", symbol);
    
    // Force refresh quote using new DataHub+MarketData
    [[DataHub shared] refreshQuoteForSymbol:symbol
                                 completion:^(MarketQuoteModel *quote, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (quote && !error) {
                // Update MiniChart properties with RuntimeModel data
                miniChart.currentPrice = quote.last;
                miniChart.priceChange = quote.change;
                miniChart.percentChange = quote.changePercent;
                
                NSLog(@"✅ Quote refreshed for %@", symbol);
                
                // Refresh historical data too
                [self loadHistoricalDataForMiniChart:miniChart];
            } else {
                NSLog(@"❌ Quote refresh failed for %@: %@", symbol, error.localizedDescription);
                [miniChart setError:@"Update failed"];
            }
        });
    }];
}

#pragma mark - Notification Handlers (NEW - Runtime Models)

- (void)quoteUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"];
    
    if (!symbol || !quote) return;
    
    // Find MiniChart for this symbol and update
    MiniChart *miniChart = [self miniChartForSymbol:symbol];
    if (miniChart) {
        dispatch_async(dispatch_get_main_queue(), ^{
            miniChart.currentPrice = quote.last;
            miniChart.priceChange = quote.change;
            miniChart.percentChange = quote.changePercent;
            
            NSLog(@"📨 Quote notification for %@: $%.2f", symbol, [quote.last doubleValue]);
        });
    }
}

- (void)historicalDataUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    NSArray<HistoricalBarModel *> *bars = notification.userInfo[@"bars"];
    
    if (!symbol || !bars) return;
    
    // Find MiniChart for this symbol and update
    MiniChart *miniChart = [self miniChartForSymbol:symbol];
    if (miniChart) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [miniChart updateWithHistoricalBars:bars];
            NSLog(@"📨 Historical data notification for %@: %lu bars", symbol, (unsigned long)bars.count);
        });
    }
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

#pragma mark - Auto Refresh

- (void)startAutoRefresh {
    [self stopAutoRefresh]; // Stop existing timer
    
    // Refresh every 10 seconds
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                         target:self
                                                       selector:@selector(autoRefreshTick:)
                                                       userInfo:nil
                                                        repeats:YES];
    
    NSLog(@"🔄 Started auto-refresh timer");
}

- (void)stopAutoRefresh {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
        NSLog(@"⏹️ Stopped auto-refresh timer");
    }
}

- (void)autoRefreshTick:(NSTimer *)timer {
    NSLog(@"⏰ Auto-refresh tick");
    [self refreshAllCharts];
}

#pragma mark - Actions

- (void)symbolsChanged:(id)sender {
    [self setSymbolsFromString:self.symbolsTextField.stringValue];
}

- (void)chartTypeChanged:(id)sender {
    self.chartType = (MiniChartType)self.chartTypePopup.indexOfSelectedItem;
    
    // Update all charts
    for (MiniChart *chart in self.miniCharts) {
        chart.chartType = self.chartType;
        [chart setNeedsDisplay:YES];
    }
}

- (void)timeframeChanged:(id)sender {
    NSInteger index = self.timeframePopup.indexOfSelectedItem;
    self.timeframe = (MiniChartTimeframe)index;
    
    // Update all charts and reload data
    for (MiniChart *chart in self.miniCharts) {
        chart.timeframe = self.timeframe;
    }
    
    [self loadDataFromDataHub];
}

- (void)scaleTypeChanged:(id)sender {
    self.scaleType = (MiniChartScaleType)self.scaleTypePopup.indexOfSelectedItem;
    
    // Update all charts
    for (MiniChart *chart in self.miniCharts) {
        chart.scaleType = self.scaleType;
        [chart setNeedsDisplay:YES];
    }
}

- (void)maxBarsChanged:(id)sender {
    NSInteger newMaxBars = self.maxBarsField.integerValue;
    if (newMaxBars > 0 && newMaxBars <= 500) {
        self.maxBars = newMaxBars;
        
        // Update all charts
        for (MiniChart *chart in self.miniCharts) {
            chart.maxBars = self.maxBars;
        }
        
        [self loadDataFromDataHub];
    }
}

- (void)volumeCheckboxChanged:(id)sender {
    self.showVolume = (self.volumeCheckbox.state == NSControlStateValueOn);
    
    // Update all charts
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
    
    // Re-enable after 1 second to prevent spam
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.refreshButton.enabled = YES;
    });
}

#pragma mark - Symbol Management

- (void)setSymbols:(NSArray<NSString *> *)symbols {
    _symbols = symbols ?: @[];
    
    // Update symbols text field
    self.symbolsString = [_symbols componentsJoinedByString:@", "];
    self.symbolsTextField.stringValue = self.symbolsString;
    
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
    
    _symbols = parsedSymbols;
    [self rebuildMiniCharts];
    [self loadDataFromDataHub];
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
    NSLog(@"🔨 Rebuilding MiniCharts for %lu symbols", (unsigned long)self.symbols.count);
    
    // Remove existing charts
    for (MiniChart *chart in self.miniCharts) {
        [chart removeFromSuperview];
    }
    [self.miniCharts removeAllObjects];
    
    // Remove constraints
    [self.chartsContainer removeConstraints:self.chartConstraints];
    [self.chartConstraints removeAllObjects];
    
    // Create new charts
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
}

- (void)layoutMiniCharts {
    if (self.miniCharts.count == 0) return;
    
    NSInteger columns = self.columnsCount;
    NSInteger rows = (self.miniCharts.count + columns - 1) / columns;
    
    CGFloat chartWidth = 300;
    CGFloat chartHeight = 200;
    CGFloat spacing = 10;
    
    // Calculate container size
    CGFloat containerWidth = columns * chartWidth + (columns - 1) * spacing;
    CGFloat containerHeight = rows * chartHeight + (rows - 1) * spacing;
    
    // Set container size
    [NSLayoutConstraint activateConstraints:@[
        [self.chartsContainer.widthAnchor constraintEqualToConstant:containerWidth],
        [self.chartsContainer.heightAnchor constraintEqualToConstant:containerHeight]
    ]];
    
    // Layout each chart
    for (NSInteger i = 0; i < self.miniCharts.count; i++) {
        MiniChart *chart = self.miniCharts[i];
        
        NSInteger row = i / columns;
        NSInteger column = i % columns;
        
        CGFloat x = column * (chartWidth + spacing);
        CGFloat y = row * (chartHeight + spacing);
        
        // Chart size
        [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:chart
                                                                      attribute:NSLayoutAttributeWidth
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:nil
                                                                      attribute:NSLayoutAttributeNotAnAttribute
                                                                     multiplier:1.0
                                                                       constant:chartWidth]];
        
        [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:chart
                                                                      attribute:NSLayoutAttributeHeight
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:nil
                                                                      attribute:NSLayoutAttributeNotAnAttribute
                                                                     multiplier:1.0
                                                                       constant:chartHeight]];
        
        // X position
        [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:chart
                                                                      attribute:NSLayoutAttributeLeft
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.chartsContainer
                                                                      attribute:NSLayoutAttributeLeft
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
    // Calculate optimal number of columns based on width
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
        self.maxBarsField.integerValue = self.maxBars;
    }
    
    if (state[@"showVolume"]) {
        self.showVolume = [state[@"showVolume"] boolValue];
        self.volumeCheckbox.state = self.showVolume ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    if (state[@"columnsCount"]) {
        self.columnsCount = [state[@"columnsCount"] integerValue];
        self.columnsControl.selectedSegment = self.columnsCount - 1;
    }
    
    // Apply configuration to existing charts
    for (MiniChart *chart in self.miniCharts) {
        chart.chartType = self.chartType;
        chart.timeframe = self.timeframe;
        chart.scaleType = self.scaleType;
        chart.maxBars = self.maxBars;
        chart.showVolume = self.showVolume;
    }
    
    [self layoutMiniCharts];
    [self loadDataFromDataHub];
}

@end
