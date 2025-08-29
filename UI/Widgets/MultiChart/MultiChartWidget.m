//
//  MultiChartWidget.m
//  TradingApp
//
//  Implementation of multi-symbol chart grid widget
//  FIXED: Properly follows BaseWidget architecture
//

#import "MultiChartWidget.h"
#import "MiniChart.h"
#import "DataHub+MarketData.h"
#import "RuntimeModels.h"
#import "MiniChartCollectionItem.h"

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
        [self registerForNotifications];
        // REMOVED: [self setupUI]; - Now handled in setupContentView
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
    _gridRows = 2;
      _gridColumns = 3;
    _symbols = @[];
    _symbolsString = @"";
    
    // Initialize arrays that are in header
    _miniCharts = [NSMutableArray array];
    _chartConstraints = [NSMutableArray array];
}

#pragma mark - BaseWidget Override

- (void)setupContentView {
    [super setupContentView];
     
     // Remove BaseWidget's placeholder
     for (NSView *subview in self.contentView.subviews) {
         [subview removeFromSuperview];
     }
     
     // Setup UI
     [self setupControlsView];
     [self setupScrollView];
    [self initializeSettingsSystem];
    
    //intercetta notifiche di frame per il resize delle minichart
    self.contentView.postsFrameChangedNotifications = YES;

}

#pragma mark - UI Setup

- (void)setupControlsView {
    // Controls view at top
    self.controlsView = [[NSView alloc] init];
    self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.controlsView];
    
    self.symbolsTextField = [[NSTextField alloc] init];
       self.symbolsTextField.placeholderString = @"Enter symbols (AAPL, TSLA, MSFT...)";
       self.symbolsTextField.translatesAutoresizingMaskIntoConstraints = NO;
       [self.symbolsTextField setTarget:self];
       [self.symbolsTextField setAction:@selector(symbolsChanged:)]; // ✅ NOTA: senza AutoSave
       [self.controlsView addSubview:self.symbolsTextField];
       
       // ✅ NUOVO: Reset symbols button
       self.resetSymbolsButton = [NSButton buttonWithTitle:@"×" target:self action:@selector(resetSymbolsClicked:)];
       self.resetSymbolsButton.bezelStyle = NSBezelStyleCircular;
       self.resetSymbolsButton.translatesAutoresizingMaskIntoConstraints = NO;
       [self.controlsView addSubview:self.resetSymbolsButton];

    
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
    self.rowsField = [[NSTextField alloc] init];
       self.rowsField.stringValue = @"2";
       self.rowsField.translatesAutoresizingMaskIntoConstraints = NO;
       [self.rowsField setTarget:self];
       [self.rowsField setAction:@selector(gridSizeChanged:)];
       [self.controlsView addSubview:self.rowsField];
       
       // ✅ NUOVO: Columns field
       self.columnsField = [[NSTextField alloc] init];
       self.columnsField.stringValue = @"3";
       self.columnsField.translatesAutoresizingMaskIntoConstraints = NO;
       [self.columnsField setTarget:self];
       [self.columnsField setAction:@selector(gridSizeChanged:)];
       [self.controlsView addSubview:self.columnsField];    // Columns control
   
    
    // Refresh button
    self.refreshButton = [NSButton buttonWithTitle:@"Refresh" target:self action:@selector(refreshButtonClicked:)];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.refreshButton];
    
    [self setupControlsConstraints];
}

- (void)setupControlsConstraints {
    CGFloat spacing = 8;
    
    // Controls view - FIXED: Proper height constraint
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.controlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.controlsView.heightAnchor constraintEqualToConstant:40] // Reduced from 60
    ]];
    
    // Symbols field
    [NSLayoutConstraint activateConstraints:@[
           [self.symbolsTextField.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor constant:spacing],
           [self.symbolsTextField.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
           [self.symbolsTextField.widthAnchor constraintEqualToConstant:180], // Ridotto da 200 per fare spazio al reset
           
           [self.resetSymbolsButton.leadingAnchor constraintEqualToAnchor:self.symbolsTextField.trailingAnchor constant:4],
           [self.resetSymbolsButton.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
           [self.resetSymbolsButton.widthAnchor constraintEqualToConstant:25],
           [self.resetSymbolsButton.heightAnchor constraintEqualToConstant:25]
       ]];
    
    // Chart type popup
    [NSLayoutConstraint activateConstraints:@[
        [self.chartTypePopup.leadingAnchor constraintEqualToAnchor:self.resetSymbolsButton.trailingAnchor constant:spacing],
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
    
    [NSLayoutConstraint activateConstraints:@[
            [self.rowsField.leadingAnchor constraintEqualToAnchor:self.volumeCheckbox.trailingAnchor constant:spacing],
            [self.rowsField.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
            [self.rowsField.widthAnchor constraintEqualToConstant:30]
        ]];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.columnsField.leadingAnchor constraintEqualToAnchor:self.rowsField.trailingAnchor constant:4],
            [self.columnsField.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
            [self.columnsField.widthAnchor constraintEqualToConstant:30]
        ]];
    
    // Refresh button
    [NSLayoutConstraint activateConstraints:@[
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.columnsField.trailingAnchor constant:spacing],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.refreshButton.trailingAnchor constraintLessThanOrEqualToAnchor:self.controlsView.trailingAnchor constant:-spacing]
    ]];
}

- (void)setupScrollView {
    // Collection view layout
    NSCollectionViewGridLayout *gridLayout = [[NSCollectionViewGridLayout alloc] init];
    gridLayout.minimumItemSize = NSMakeSize(100, 80);
    gridLayout.maximumItemSize = NSMakeSize(500, 400);
    gridLayout.minimumInteritemSpacing = 10;
    gridLayout.minimumLineSpacing = 10;
    gridLayout.margins = NSEdgeInsetsMake(10, 10, 10, 10);
    
    // Collection view
    self.collectionView = [[NSCollectionView alloc] init];
    self.collectionView.collectionViewLayout = gridLayout;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.backgroundColors = @[[NSColor controlBackgroundColor]];
    
    // Registra la classe item
    [self.collectionView registerClass:[MiniChartCollectionItem class]
                  forItemWithIdentifier:@"MiniChartItem"];
    
    // Scroll view per collection view
    self.collectionScrollView = [[NSScrollView alloc] init];
    self.collectionScrollView.hasVerticalScroller = YES;
    self.collectionScrollView.hasHorizontalScroller = YES;
    self.collectionScrollView.autohidesScrollers = YES;
    self.collectionScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionScrollView.documentView = self.collectionView;
    self.collectionScrollView.verticalScrollElasticity = NSScrollElasticityAllowed;
    self.collectionScrollView.horizontalScrollElasticity = NSScrollElasticityAllowed;
    
    [self.contentView addSubview:self.collectionScrollView];
    
    // Constraints - stesso layout del vecchio scrollView
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionScrollView.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:8],
        [self.collectionScrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.collectionScrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.collectionScrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
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
    
    // ✅ AGGIUNGI: Listen for view frame changes
    [nc addObserver:self
           selector:@selector(viewFrameDidChange:)
               name:NSViewFrameDidChangeNotification
             object:self.contentView];
}



- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopAutoRefresh];
    [self saveSettingsOnExit];

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

#pragma mark - Data Loading

- (void)loadDataFromDataHub {
    if (self.symbols.count == 0) return;
    
    NSLog(@"📊 MultiChartWidget: Loading data for %lu symbols using BATCH API", (unsigned long)self.symbols.count);
    
    // Disable refresh button during loading
    self.refreshButton.enabled = NO;
    
    // Make SINGLE batch call for quotes
    [[DataHub shared] getQuotesForSymbols:self.symbols completion:^(NSDictionary<NSString *,MarketQuoteModel *> *quotes, BOOL allLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ MultiChartWidget: Batch quotes received - %lu quotes (allLive: %@)",
                  (unsigned long)quotes.count, allLive ? @"YES" : @"NO");
            
            // Update all charts with quote data
            for (MiniChart *chart in self.miniCharts) {
                MarketQuoteModel *quote = quotes[chart.symbol];
                if (quote) {
                    chart.currentPrice = quote.last;
                    chart.priceChange = quote.change;
                    chart.percentChange = quote.changePercent;
                    NSLog(@"📈 Updated %@ with price: %@", chart.symbol, quote.last);
                }
            }
            
            // Now load historical data for each chart (these need individual calls)
            [self loadHistoricalDataForAllCharts];
        });
    }];
}
- (void)loadHistoricalDataForAllCharts {
    NSLog(@"📊 MultiChartWidget: Loading historical data for %lu charts", (unsigned long)self.miniCharts.count);
    
    __block NSInteger completedCount = 0;
    NSInteger totalCount = self.miniCharts.count;
    
    for (MiniChart *chart in self.miniCharts) {
        // ✅ SEMPLIFICATO: Loading solo se chiamato da setup iniziale
        // Non controlliamo historicalBars perché non esiste come proprietà
        [chart setLoading:YES];
        
        [[DataHub shared] getHistoricalBarsForSymbol:chart.symbol
                                           timeframe:[self convertToBarTimeframe:self.timeframe]
                                            barCount:self.maxBars
                                   needExtendedHours:NO  // ← Aggiungi questo
                                          completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isLive) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completedCount++;
                
                [chart setLoading:NO];
                
                if (bars && bars.count > 0) {
                    [chart updateWithHistoricalBars:bars];
                    NSLog(@"📈 Loaded %lu bars for %@", (unsigned long)bars.count, chart.symbol);
                } else {
                    [chart setError:@"No data available"];
                    NSLog(@"❌ No historical data for %@", chart.symbol);
                }
                
                if (completedCount == totalCount) {
                    self.refreshButton.enabled = YES;
                    NSLog(@"✅ MultiChartWidget: All data loading completed");
                }
            });
        }];
    }
}
- (void)loadDataForMiniChart:(MiniChart *)miniChart {
    NSString *symbol = miniChart.symbol;
    if (!symbol) return;
    
    // Show loading
    [miniChart setLoading:YES];
    
    // Load quote
    [[DataHub shared] getQuoteForSymbol:symbol
                             completion:^(MarketQuoteModel *quote, BOOL isLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (quote) {
                miniChart.currentPrice = quote.last;
                miniChart.priceChange = quote.change;
                miniChart.percentChange = quote.changePercent;
            }
            
            // Load historical data
            [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                               timeframe:[self convertToBarTimeframe:self.timeframe]
                                                barCount:self.maxBars
                                       needExtendedHours:NO  // ← Aggiungi questo
                                              completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isLive) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [miniChart setLoading:NO];
                    
                    if (bars && bars.count > 0) {
                        [miniChart updateWithHistoricalBars:bars];
                    } else {
                        [miniChart setError:@"No data available"];
                    }
                });
            }];
        });
    }];
}

- (BarTimeframe)convertToBarTimeframe:(MiniChartTimeframe)timeframe {
    switch (timeframe) {
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
            return BarTimeframeDaily;
        case MiniChartTimeframeWeekly:
            return BarTimeframeWeekly;
        case MiniChartTimeframeMonthly:
            return BarTimeframeMonthly;
    }
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
    // Mantieni gli stessi MiniChart esistenti ma pulisci l'array
    [self.miniCharts removeAllObjects];
    
    // Crea i MiniChart usando lo stesso codice esistente
    for (NSString *symbol in self.symbols) {
        MiniChart *miniChart = [[MiniChart alloc] init];
        miniChart.symbol = symbol;
        miniChart.chartType = self.chartType;
        miniChart.timeframe = self.timeframe;
        miniChart.scaleType = self.scaleType;
        miniChart.maxBars = self.maxBars;
        miniChart.showVolume = self.showVolume;
        
        // Setup appearance esistente
        [self setupChartSelectionAppearance:miniChart];
        
        [self.miniCharts addObject:miniChart];
    }
    
    // Aggiorna collection view
    [self.collectionView reloadData];
    
    NSLog(@"MultiChartWidget: Rebuilt %lu mini charts with NSCollectionView", (unsigned long)self.miniCharts.count);
}


- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.miniCharts.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
                     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    
    MiniChartCollectionItem *item = [collectionView makeItemWithIdentifier:@"MiniChartItem"
                                                              forIndexPath:indexPath];
    
    if (indexPath.item < self.miniCharts.count) {
        MiniChart *miniChart = self.miniCharts[indexPath.item];
        
        // Configura l'item con il MiniChart esistente
        [item configureMiniChart:miniChart];
        
        // Setup callbacks usando i metodi esistenti
        __weak typeof(self) weakSelf = self;
        item.onChartClicked = ^(MiniChart *chart) {
            [weakSelf handleChartClick:chart];
        };
        
        item.onSetupContextMenu = ^(MiniChart *chart) {
            [weakSelf setupChartContextMenu:chart];
        };
    }
    
    return item;
}

- (void)handleChartClick:(MiniChart *)clickedChart {
    NSString *symbol = clickedChart.symbol;
    
    NSLog(@"MultiChartWidget: Mini chart clicked for symbol: %@", symbol);
    
    // Aggiorna la selezione visuale (usa codice esistente)
    [self updateChartSelection:clickedChart];
    
    // Broadcast del simbolo selezionato alla chain (codice esistente)
    if (self.chainActive && symbol.length > 0) {
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[symbol]
        }];
        
        NSLog(@"MultiChartWidget: Broadcasted symbol '%@' to chain", symbol);
        
        // Mostra feedback temporaneo (risolvi problema scroll usando collection view bounds)
        [self showTemporaryMessageForCollectionView:[NSString stringWithFormat:@"Sent %@ to chain", symbol]];
    }
}

- (void)showTemporaryMessageForCollectionView:(NSString *)message {
    NSTextField *messageLabel = [NSTextField labelWithString:message];
    messageLabel.editable = NO;
    messageLabel.bordered = NO;
    messageLabel.backgroundColor = [NSColor.controlAccentColor colorWithAlphaComponent:0.8];
    messageLabel.textColor = [NSColor whiteColor];
    messageLabel.font = [NSFont boldSystemFontOfSize:12];
    messageLabel.alignment = NSTextAlignmentCenter;
    messageLabel.wantsLayer = YES;
    messageLabel.layer.cornerRadius = 4.0;
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Aggiungi al contentView (non alla collection view) per evitare problemi scroll
    [self.contentView addSubview:messageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [messageLabel.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:20],
        [messageLabel.heightAnchor constraintEqualToConstant:30],
        [messageLabel.widthAnchor constraintGreaterThanOrEqualToConstant:100]
    ]];
    
    // Rimuovi dopo 2 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [messageLabel removeFromSuperview];
    });
}

- (void)setupChartClickHandler:(MiniChart *)chart {
    // Aggiungi gesture recognizer per gestire i click
    NSClickGestureRecognizer *clickGesture = [[NSClickGestureRecognizer alloc]
                                              initWithTarget:self
                                              action:@selector(miniChartClicked:)];
    [chart addGestureRecognizer:clickGesture];
    
    // Configura il chart per essere selezionabile visivamente
    [self setupChartSelectionAppearance:chart];
}

- (void)setupChartSelectionAppearance:(MiniChart *)chart {
    // Aggiungi bordo per indicare lo stato di selezione
    chart.wantsLayer = YES;
    chart.layer.borderWidth = 0.0;
    chart.layer.borderColor = [NSColor controlAccentColor].CGColor;
    chart.layer.cornerRadius = 4.0;
}

- (void)miniChartClicked:(NSClickGestureRecognizer *)gesture {
    MiniChart *clickedChart = (MiniChart *)gesture.view;
    NSString *symbol = clickedChart.symbol;
    
    NSLog(@"MultiChartWidget: Mini chart clicked for symbol: %@", symbol);
    
    // Aggiorna la selezione visuale
    [self updateChartSelection:clickedChart];
    
    // Broadcast del simbolo selezionato alla chain
    if (self.chainActive && symbol.length > 0) {
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[symbol]
        }];
        
        NSLog(@"MultiChartWidget: Broadcasted symbol '%@' to chain", symbol);
        
        // Mostra feedback temporaneo
        [self showTemporaryMessage:[NSString stringWithFormat:@"Sent %@ to chain", symbol]];
    }
}

- (void)layoutMiniCharts {
    if (self.miniCharts.count == 0) return;
    
    // Remove existing constraints
    [self.chartsContainer removeConstraints:self.chartConstraints];
    [self.chartConstraints removeAllObjects];
    
    // ✅ NUOVO: Usa gridRows e gridColumns invece di columnsCount
    NSInteger rows = (self.miniCharts.count + self.gridColumns - 1) / self.gridColumns;
    CGFloat spacing = 10;
    
    // ✅ NUOVO: Calcolo responsivo basato su container size
    CGSize containerSize = self.scrollView.bounds.size;
    if (containerSize.width <= 0 || containerSize.height <= 0) {
        containerSize = CGSizeMake(800, 600); // Fallback
    }
    
    CGFloat chartWidth = (containerSize.width - (self.gridColumns + 1) * spacing) / self.gridColumns;
    CGFloat chartHeight = (containerSize.height - (self.gridRows + 1) * spacing) / self.gridRows;
    
    // Dimensioni minime
    chartWidth = MAX(chartWidth, 100);
    chartHeight = MAX(chartHeight, 80);
    
    NSLog(@"Layout: container=%.0fx%.0f, chart=%.0fx%.0f, grid=%ldx%ld",
          containerSize.width, containerSize.height, chartWidth, chartHeight,
          (long)self.gridColumns, (long)self.gridRows);
    
    // Layout each chart
    for (NSInteger i = 0; i < self.miniCharts.count; i++) {
        MiniChart *chart = self.miniCharts[i];
        
        // ✅ NUOVO: Usa gridColumns invece di columnsCount
        NSInteger row = i / self.gridColumns;
        NSInteger col = i % self.gridColumns;
        
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
    
    // Set container size
    CGFloat containerWidth = self.gridColumns * chartWidth + (self.gridColumns + 1) * spacing;
    CGFloat containerHeight = rows * chartHeight + (rows + 1) * spacing;
    
    // Container size constraints
    [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:self.chartsContainer
                                                                  attribute:NSLayoutAttributeWidth
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:nil
                                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                                 multiplier:1.0
                                                                   constant:containerWidth]];
    
    [self.chartConstraints addObject:[NSLayoutConstraint constraintWithItem:self.chartsContainer
                                                                  attribute:NSLayoutAttributeHeight
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:nil
                                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                                 multiplier:1.0
                                                                   constant:containerHeight]];
    
    [self.chartsContainer addConstraints:self.chartConstraints];
    
    // ✅ SCROLL TOP-DOWN: Assicura scroll dall'alto
    [self.chartsContainer scrollPoint:NSMakePoint(0, 0)];
}



- (void)setupChartContextMenu:(MiniChart *)chart {
    NSMenu *contextMenu = [[NSMenu alloc] init];
    
    // Send to chain
    NSMenuItem *sendToChainItem = [[NSMenuItem alloc] init];
    sendToChainItem.title = [NSString stringWithFormat:@"Send '%@' to Chain", chart.symbol];
    sendToChainItem.action = @selector(sendChartSymbolToChain:);
    sendToChainItem.target = self;
    sendToChainItem.representedObject = chart.symbol;
    [contextMenu addItem:sendToChainItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Send to specific chain colors
    NSMenuItem *sendToChainColorsItem = [[NSMenuItem alloc] init];
    sendToChainColorsItem.title = [NSString stringWithFormat:@"Send '%@' to Chain Color", chart.symbol];
    sendToChainColorsItem.submenu = [self createChainColorSubmenuForSymbol:chart.symbol];
    [contextMenu addItem:sendToChainColorsItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Remove from grid
    NSMenuItem *removeItem = [[NSMenuItem alloc] init];
    removeItem.title = [NSString stringWithFormat:@"Remove '%@'", chart.symbol];
    removeItem.action = @selector(removeChartSymbol:);
    removeItem.target = self;
    removeItem.representedObject = chart.symbol;
    [contextMenu addItem:removeItem];
    
    chart.menu = contextMenu;
}

- (NSMenu *)createChainColorSubmenuForSymbol:(NSString *)symbol {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    NSArray *chainColors = @[
        @{@"name": @"Red Chain", @"color": [NSColor systemRedColor]},
        @{@"name": @"Green Chain", @"color": [NSColor systemGreenColor]},
        @{@"name": @"Blue Chain", @"color": [NSColor systemBlueColor]},
        @{@"name": @"Yellow Chain", @"color": [NSColor systemYellowColor]},
        @{@"name": @"Orange Chain", @"color": [NSColor systemOrangeColor]},
        @{@"name": @"Purple Chain", @"color": [NSColor systemPurpleColor]},
        @{@"name": @"Gray Chain", @"color": [NSColor systemGrayColor]}
    ];
    
    for (NSDictionary *colorInfo in chainColors) {
        NSMenuItem *colorItem = [[NSMenuItem alloc] init];
        colorItem.title = [NSString stringWithFormat:@"%@ (%@)", colorInfo[@"name"], symbol];
        colorItem.action = @selector(sendSymbolToSpecificChain:);
        colorItem.target = self;
        
        NSDictionary *actionData = @{
            @"symbol": symbol,
            @"color": colorInfo[@"color"],
            @"colorName": colorInfo[@"name"]
        };
        colorItem.representedObject = actionData;
        
        // Aggiungi indicatore visivo del colore
        NSImage *colorIndicator = [self createColorIndicatorWithColor:colorInfo[@"color"]];
        colorItem.image = colorIndicator;
        
        [submenu addItem:colorItem];
    }
    
    return submenu;
}

- (NSImage *)createColorIndicatorWithColor:(NSColor *)color {
    NSSize size = NSMakeSize(16, 16);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    
    [image lockFocus];
    
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(2, 2, 12, 12)];
    [color setFill];
    [circle fill];
    
    [[NSColor blackColor] setStroke];
    circle.lineWidth = 0.5;
    [circle stroke];
    
    [image unlockFocus];
    
    return image;
}

#pragma mark - Context Menu Actions

- (void)sendChartSymbolToChain:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSString *symbol = menuItem.representedObject;
    
    if (symbol.length > 0) {
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[symbol]
        }];
        
        [self showTemporaryMessage:[NSString stringWithFormat:@"Sent %@ to chain", symbol]];
    }
}

- (void)sendSymbolToSpecificChain:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSDictionary *actionData = menuItem.representedObject;
    
    NSString *symbol = actionData[@"symbol"];
    NSColor *chainColor = actionData[@"color"];
    NSString *colorName = actionData[@"colorName"];
    
    if (symbol.length > 0 && chainColor) {
        // Attiva la chain con il colore specifico
        [self setChainActive:YES withColor:chainColor];
        
        // Invia il simbolo
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[symbol]
        }];
        
        [self showTemporaryMessage:[NSString stringWithFormat:@"Sent %@ to %@", symbol, colorName]];
    }
}

- (void)removeChartSymbol:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSString *symbol = menuItem.representedObject;
    
    if (symbol.length > 0) {
        [self removeSymbol:symbol];
        
        // Aggiorna il campo di testo
        self.symbolsString = [self.symbols componentsJoinedByString:@", "];
        self.symbolsTextField.stringValue = self.symbolsString;
        
        // Ricostruisci i chart
        [self rebuildMiniCharts];
        
        [self showTemporaryMessage:[NSString stringWithFormat:@"Removed %@", symbol]];
    }
}

#pragma mark - UI Feedback

- (void)showTemporaryMessage:(NSString *)message {
/*
    // Crea un label temporaneo per feedback
    NSTextField *messageLabel = [NSTextField labelWithString:message];
    messageLabel.backgroundColor = [NSColor controlAccentColor];
    messageLabel.textColor = [NSColor controlTextColor];
    messageLabel.drawsBackground = YES;
    messageLabel.bordered = NO;
    messageLabel.editable = NO;
    messageLabel.alignment = NSTextAlignmentCenter;
    messageLabel.font = [NSFont systemFontOfSize:11];
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:messageLabel];
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [messageLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        [messageLabel.heightAnchor constraintEqualToConstant:20],
        [messageLabel.widthAnchor constraintGreaterThanOrEqualToConstant:100]
    ]];
   
    // Rimuovi dopo 2 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [messageLabel removeFromSuperview];
    });*/
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



- (void)refreshButtonClicked:(id)sender {
    self.refreshButton.enabled = NO;
    [self refreshAllCharts];
    
    // Re-enable after 1 second to prevent spam
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.refreshButton.enabled = YES;
    });
}

#pragma mark - Public Methods

- (void)refreshAllCharts {
    NSLog(@"🔄 MultiChartWidget: Manual refresh triggered");
    [self loadDataFromDataHub];
}

- (void)refreshChartForSymbol:(NSString *)symbol {
    NSLog(@"🔄 MultiChartWidget: Refreshing single chart for %@", symbol);
    
    MiniChart *chart = [self miniChartForSymbol:symbol];
    if (chart) {
        // Use single symbol batch call (more consistent with architecture)
        [[DataHub shared] getQuotesForSymbols:@[symbol] completion:^(NSDictionary<NSString *,MarketQuoteModel *> *quotes, BOOL allLive) {
            dispatch_async(dispatch_get_main_queue(), ^{
                MarketQuoteModel *quote = quotes[symbol];
                if (quote) {
                    chart.currentPrice = quote.last;
                    chart.priceChange = quote.change;
                    chart.percentChange = quote.changePercent;
                }
                
                // Also refresh historical data
                [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                                   timeframe:[self convertToBarTimeframe:self.timeframe]
                                                    barCount:self.maxBars
                                           needExtendedHours:NO  // ← Aggiungi questo
                                                  completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isLive) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (bars && bars.count > 0) {
                            [chart updateWithHistoricalBars:bars];
                        }
                    });
                }];
            });
        }];
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
}

- (void)stopAutoRefresh {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
}

- (void)autoRefreshTick:(NSTimer *)timer {
    [self refreshAllCharts];
}

#pragma mark - Notification Handlers

- (void)quoteUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"];
    
    if (symbol && quote) {
        MiniChart *chart = [self miniChartForSymbol:symbol];
        if (chart) {
            chart.currentPrice = quote.last;
            chart.priceChange = quote.change;
            chart.percentChange = quote.changePercent;
        }
    }
}

- (void)historicalDataUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    NSArray<HistoricalBarModel *> *bars = notification.userInfo[@"bars"];
    
    if (symbol && bars) {
        MiniChart *chart = [self miniChartForSymbol:symbol];
        if (chart) {
            [chart updateWithHistoricalBars:bars];
        }
    }
}

#pragma mark - Chain Integration


- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"MultiChartWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
    
    
    // Combina i simboli ricevuti con quelli esistenti
    NSMutableSet *combinedSymbols = [NSMutableSet setWithArray:self.symbols];
    [combinedSymbols addObjectsFromArray:symbols];
    
    // Aggiorna la lista simboli
    NSArray *newSymbolsArray = [combinedSymbols.allObjects sortedArrayUsingSelector:@selector(compare:)];
    
    // ✅ ENHANCED: Check for actual changes
    if ([newSymbolsArray isEqualToArray:self.symbols]) {
        NSLog(@"MultiChartWidget: No new symbols to add, current list unchanged");
        return;
    }
    
    self.symbols = newSymbolsArray;
    
    // Aggiorna il campo di testo
    self.symbolsString = [newSymbolsArray componentsJoinedByString:@", "];
    if (self.symbolsTextField) {
        self.symbolsTextField.stringValue = self.symbolsString;
    }
    
    // Ricostruisci i mini chart
    [self rebuildMiniCharts];
    [self loadDataFromDataHub];
    
    // ✅ NUOVO: Usa metodo BaseWidget standard per feedback
    NSString *senderType = NSStringFromClass([sender class]);
    NSString *message = symbols.count == 1 ?
        [NSString stringWithFormat:@"📊 Added %@ from %@", symbols[0], senderType] :
        [NSString stringWithFormat:@"📊 Added %lu symbols from %@", (unsigned long)symbols.count, senderType];
    
    [self showChainFeedback:message];
}

#pragma mark - Enhanced BaseWidget State Management

// Override del metodo BaseWidget per includere le impostazioni UI
- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    // Includi le impostazioni UI nello stato del widget
    state[@"chartType"] = @(self.chartType);
    state[@"timeframe"] = @(self.timeframe);
    state[@"scaleType"] = @(self.scaleType);
    state[@"maxBars"] = @(self.maxBars);
    state[@"showVolume"] = @(self.showVolume);
    state[@"columnsCount"] = @(self.columnsCount);
    
    return state;
}

// Override del metodo BaseWidget per ripristinare le impostazioni UI
- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    // Ripristina le impostazioni UI dallo stato salvato
    if (state[@"chartType"]) {
        self.chartType = [state[@"chartType"] integerValue];
    }
    
    if (state[@"timeframe"]) {
        self.timeframe = [state[@"timeframe"] integerValue];
    }
    
    if (state[@"scaleType"]) {
        self.scaleType = [state[@"scaleType"] integerValue];
    }
    
    if (state[@"maxBars"]) {
        self.maxBars = [state[@"maxBars"] integerValue];
    }
    
    if (state[@"showVolume"]) {
        self.showVolume = [state[@"showVolume"] boolValue];
    }
    
    if (state[@"columnsCount"]) {
        self.columnsCount = [state[@"columnsCount"] integerValue];
    }
    
  
    
    // Aggiorna l'UI dopo il ripristino
    [self updateUIFromSettings];
    
    // Ricostruisci i chart con le nuove impostazioni
    [self rebuildMiniCharts];
    
    NSLog(@"MultiChartWidget: Restored state from layout");
}

//
// MultiChartWidget Settings Persistence
// Aggiungi questo codice al MultiChartWidget.m
//

#pragma mark - Settings Persistence Keys

// Keys per NSUserDefaults - prefisso per evitare conflitti
static NSString *const kMultiChartChartTypeKey = @"MultiChart_ChartType";
static NSString *const kMultiChartTimeframeKey = @"MultiChart_Timeframe";
static NSString *const kMultiChartScaleTypeKey = @"MultiChart_ScaleType";
static NSString *const kMultiChartMaxBarsKey = @"MultiChart_MaxBars";
static NSString *const kMultiChartShowVolumeKey = @"MultiChart_ShowVolume";
static NSString *const kMultiChartColumnsCountKey = @"MultiChart_ColumnsCount";
static NSString *const kMultiChartSymbolsKey = @"MultiChart_Symbols";

#pragma mark - Settings Management

- (void)loadSettingsFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Carica le impostazioni salvate o usa i default
    NSInteger savedChartType = [defaults integerForKey:kMultiChartChartTypeKey];
    NSInteger savedTimeframe = [defaults integerForKey:kMultiChartTimeframeKey];
    NSInteger savedScaleType = [defaults integerForKey:kMultiChartScaleTypeKey];
    NSInteger savedMaxBars = [defaults integerForKey:kMultiChartMaxBarsKey];
    BOOL savedShowVolume = [defaults boolForKey:kMultiChartShowVolumeKey];
    NSInteger savedColumnsCount = [defaults integerForKey:kMultiChartColumnsCountKey];
    NSInteger savedRows = [defaults integerForKey:@"MultiChart_GridRows"];
      NSInteger savedColumns = [defaults integerForKey:@"MultiChart_GridColumns"];
      
      if (savedRows > 0) self.gridRows = savedRows;
      if (savedColumns > 0) self.gridColumns = savedColumns;
    // Applica le impostazioni caricate con validazione
    
    // Chart Type (default: Line se non salvato)
    if (savedChartType >= MiniChartTypeLine && savedChartType <= MiniChartTypeCandle) {
        self.chartType = (MiniChartType)savedChartType;
    } else {
        self.chartType = MiniChartTypeLine; // Default
    }
    
    // Timeframe (default: Daily se non salvato)
    if (savedTimeframe >= MiniChartTimeframe5Min && savedTimeframe <= MiniChartTimeframeMonthly) {
        self.timeframe = (MiniChartTimeframe)savedTimeframe;
    } else {
        self.timeframe = MiniChartTimeframeDaily; // Default
    }
    
    // Scale Type (default: Linear se non salvato)
    if (savedScaleType >= MiniChartScaleLinear && savedScaleType <= MiniChartScaleLog) {
        self.scaleType = (MiniChartScaleType)savedScaleType;
    } else {
        self.scaleType = MiniChartScaleLinear; // Default
    }
    
    // Max Bars (default: 100 se non salvato o fuori range)
    if (savedMaxBars > 0 && savedMaxBars <= 500) {
        self.maxBars = savedMaxBars;
    } else {
        self.maxBars = 100; // Default
    }
    
    // Show Volume (default: YES se non salvato)
    // boolForKey ritorna NO se la key non esiste, quindi controlliamo se la key esiste
    if ([defaults objectForKey:kMultiChartShowVolumeKey] != nil) {
        self.showVolume = savedShowVolume;
    } else {
        self.showVolume = YES; // Default
    }
    
    // Columns Count (default: 3 se non salvato o fuori range)
    if (savedColumnsCount >= 1 && savedColumnsCount <= 5) {
        self.columnsCount = savedColumnsCount;
    } else {
        self.columnsCount = 3; // Default
    }
    
    // Symbols (default: vuoto se non salvato)
  
        self.symbolsString = @"";
        self.symbols = @[];
    
    
    NSLog(@"MultiChartWidget: Loaded settings - ChartType:%ld, Timeframe:%ld, ScaleType:%ld, MaxBars:%ld, ShowVolume:%@, Columns:%ld, Symbols:%@",
          (long)self.chartType, (long)self.timeframe, (long)self.scaleType, (long)self.maxBars,
          self.showVolume ? @"YES" : @"NO", (long)self.columnsCount, self.symbolsString);
}

- (void)saveSettingsToUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Salva tutte le impostazioni correnti
    [defaults setInteger:self.chartType forKey:kMultiChartChartTypeKey];
    [defaults setInteger:self.timeframe forKey:kMultiChartTimeframeKey];
    [defaults setInteger:self.scaleType forKey:kMultiChartScaleTypeKey];
    [defaults setInteger:self.maxBars forKey:kMultiChartMaxBarsKey];
    [defaults setBool:self.showVolume forKey:kMultiChartShowVolumeKey];
    [defaults setInteger:self.columnsCount forKey:kMultiChartColumnsCountKey];
    [defaults setInteger:self.gridRows forKey:@"MultiChart_GridRows"];
      [defaults setInteger:self.gridColumns forKey:@"MultiChart_GridColumns"];
    // Forza la sincronizzazione immediata
    [defaults synchronize];
    
    NSLog(@"MultiChartWidget: Saved settings - ChartType:%ld, Timeframe:%ld, ScaleType:%ld, MaxBars:%ld, ShowVolume:%@, Columns:%ld, Symbols:%@",
          (long)self.chartType, (long)self.timeframe, (long)self.scaleType, (long)self.maxBars,
          self.showVolume ? @"YES" : @"NO", (long)self.columnsCount, self.symbolsString);
}

- (void)updateUIFromSettings {
    // Aggiorna i controlli UI per riflettere le impostazioni caricate
    
    // Chart Type Popup
    if (self.chartTypePopup && self.chartType < self.chartTypePopup.numberOfItems) {
        [self.chartTypePopup selectItemAtIndex:self.chartType];
    }
    
    // Timeframe Popup
    if (self.timeframePopup && self.timeframe < self.timeframePopup.numberOfItems) {
        [self.timeframePopup selectItemAtIndex:self.timeframe];
    }
    
    // Scale Type Popup
    if (self.scaleTypePopup && self.scaleType < self.scaleTypePopup.numberOfItems) {
        [self.scaleTypePopup selectItemAtIndex:self.scaleType];
    }
    
    // Max Bars Field
    if (self.maxBarsField) {
        self.maxBarsField.integerValue = self.maxBars;
    }
    
    // Volume Checkbox
    if (self.volumeCheckbox) {
        self.volumeCheckbox.state = self.showVolume ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    
    if (self.rowsField) {
           self.rowsField.integerValue = self.gridRows;
       }
       if (self.columnsField) {
           self.columnsField.integerValue = self.gridColumns;
       }

    
    NSLog(@"MultiChartWidget: Updated UI from settings");
}

#pragma mark - Enhanced Action Methods with Auto-Save

// Override dei metodi action esistenti per aggiungere auto-save

- (void)chartTypeChangedWithAutoSave:(id)sender {
    // Chiama il metodo originale
    [self chartTypeChanged:sender];
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
}

- (void)timeframeChangedWithAutoSave:(id)sender {
    // Chiama il metodo originale
    [self timeframeChanged:sender];
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
}

- (void)scaleTypeChangedWithAutoSave:(id)sender {
    // Chiama il metodo originale
    [self scaleTypeChanged:sender];
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
}

- (void)maxBarsChangedWithAutoSave:(id)sender {
    // Chiama il metodo originale
    [self maxBarsChanged:sender];
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
}

- (void)volumeCheckboxChangedWithAutoSave:(id)sender {
    // Chiama il metodo originale
    [self volumeCheckboxChanged:sender];
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
}



- (void)symbolsChangedWithAutoSave:(id)sender {
    // Chiama il metodo originale
    [self symbolsChanged:sender];
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
}


#pragma mark - Lifecycle Integration

// Metodo da chiamare in setupContentView DOPO aver creato i controlli UI
- (void)initializeSettingsSystem {
    // Carica le impostazioni salvate
    [self loadSettingsFromUserDefaults];
    
    // Aggiorna l'UI per riflettere le impostazioni
    [self updateUIFromSettings];
    
    // Collega gli action methods enhanced con auto-save
    [self setupAutoSaveActionMethods];
    
    NSLog(@"MultiChartWidget: Settings system initialized");
}

- (void)setupAutoSaveActionMethods {
    // Ricollega i controlli UI ai metodi enhanced con auto-save
    
    if (self.chartTypePopup) {
        self.chartTypePopup.target = self;
        self.chartTypePopup.action = @selector(chartTypeChangedWithAutoSave:);
    }
    
    if (self.timeframePopup) {
        self.timeframePopup.target = self;
        self.timeframePopup.action = @selector(timeframeChangedWithAutoSave:);
    }
    
    if (self.scaleTypePopup) {
        self.scaleTypePopup.target = self;
        self.scaleTypePopup.action = @selector(scaleTypeChangedWithAutoSave:);
    }
    
    if (self.maxBarsField) {
        self.maxBarsField.target = self;
        self.maxBarsField.action = @selector(maxBarsChangedWithAutoSave:);
    }
    
    if (self.volumeCheckbox) {
        self.volumeCheckbox.target = self;
        self.volumeCheckbox.action = @selector(volumeCheckboxChangedWithAutoSave:);
    }
    
    
    
    if (self.symbolsTextField) {
        self.symbolsTextField.target = self;
        self.symbolsTextField.action = @selector(symbolsChanged:); // Senza auto-save
    }

    // ✅ AGGIUNGI collegamento grid fields:
    if (self.rowsField) {
        self.rowsField.target = self;
        self.rowsField.action = @selector(gridSizeChanged:);
    }

    if (self.columnsField) {
        self.columnsField.target = self;
        self.columnsField.action = @selector(gridSizeChanged:);
    }
    
    NSLog(@"MultiChartWidget: Auto-save action methods connected");
}

// Metodo da chiamare quando il widget viene deallocato
- (void)saveSettingsOnExit {
    [self saveSettingsToUserDefaults];
    NSLog(@"MultiChartWidget: Final settings save on exit");
}


#pragma mark - ✅ NUOVI ACTION METHODS

// ✅ NUOVO: Reset simboli (pulisce solo textfield)
- (void)resetSymbolsClicked:(id)sender {
    self.symbolsTextField.stringValue = @"";
    // Non tocca i simboli esistenti nei miniChart
    NSLog(@"MultiChartWidget: Symbols field reset");
}

- (void)resetSymbolsField {
    self.symbolsTextField.stringValue = @"";
}

- (void)gridSizeChanged:(id)sender {
    NSInteger newRows = self.rowsField.integerValue;
    NSInteger newColumns = self.columnsField.integerValue;
    
    if (newRows < 1) newRows = 1;
    if (newColumns < 1) newColumns = 1;
    
    self.gridRows = newRows;
    self.gridColumns = newColumns;
    
    // Aggiorna layout collection view
    if ([self.collectionView.collectionViewLayout isKindOfClass:[NSCollectionViewGridLayout class]]) {
        NSCollectionViewGridLayout *gridLayout = (NSCollectionViewGridLayout *)self.collectionView.collectionViewLayout;
        gridLayout.maximumNumberOfColumns = newColumns;
        gridLayout.maximumNumberOfRows = newRows;
        [self.collectionView.collectionViewLayout invalidateLayout];
    }
    
    NSLog(@"MultiChartWidget: Grid changed to %ldx%ld", (long)newRows, (long)newColumns);
}


- (void)updateChartSelection:(MiniChart *)selectedChart {
    // Rimuovi selezione da tutti i chart
    for (MiniChart *chart in self.miniCharts) {
        if (chart.layer) {
            chart.layer.borderWidth = 0.0;
        }
    }
    
    // Aggiungi selezione al chart cliccato
    if (selectedChart.layer) {
        selectedChart.layer.borderWidth = 2.0;
        selectedChart.layer.borderColor = [NSColor controlAccentColor].CGColor;
    }
    
    // Animazione per evidenziare la selezione
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2;
        if (selectedChart.layer) {
            selectedChart.layer.backgroundColor = [NSColor.controlAccentColor colorWithAlphaComponent:0.1].CGColor;
        }
    } completionHandler:^{
        // Rimuovi l'highlight dopo un breve periodo
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.3;
                if (selectedChart.layer) {
                    selectedChart.layer.backgroundColor = [NSColor clearColor].CGColor;
                }
            }];
        });
    }];
}

#pragma mark - Layout Management

- (void)optimizeLayoutForSize:(NSSize)size {
    NSLog(@"📐 MultiChartWidget: Optimizing layout for size %.0fx%.0f", size.width, size.height);
    [self layoutMiniCharts];
}

- (void)viewFrameDidChange:(NSNotification *)notification {
    if (!self.symbols.count) {
        return;
    }
    NSView *view = notification.object;
    NSSize newSize = view.frame.size;
    
    static NSSize lastSize = {0, 0}; // mantiene l'ultimo valore
    
    if (!NSEqualSizes(newSize, lastSize)) {
        NSLog(@"📐 MultiChartWidget: Frame size changed from %@ to %@",
              NSStringFromSize(lastSize), NSStringFromSize(newSize));
        
        lastSize = newSize;
        
        // Usa dispatch per sicurezza
        dispatch_async(dispatch_get_main_queue(), ^{
            [self layoutMiniCharts];
        });
    }
}


@end
