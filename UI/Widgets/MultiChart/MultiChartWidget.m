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

static NSString *const kMultiChartItemWidthKey = @"MultiChart_ItemWidth";
static NSString *const kMultiChartItemHeightKey = @"MultiChart_ItemHeight";

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
    _timeframe = MiniBarTimeframeDaily;
    _scaleType = MiniChartScaleLinear;
    _maxBars = 100;
    _showVolume = YES;
    _symbols = @[];
    _symbolsString = @"";
    
    // ✅ AGGIUNGI: Inizializzazione itemWidth/itemHeight
    _itemWidth = 200;
    _itemHeight = 150;
    
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
    
    
    self.itemWidthField = [[NSTextField alloc] init];
    self.itemWidthField.stringValue = @"200";
    self.itemWidthField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.itemWidthField setTarget:self];
    [self.itemWidthField setAction:@selector(itemSizeChanged:)];
    [self.controlsView addSubview:self.itemWidthField];
    
    self.itemHeightField = [[NSTextField alloc] init];
    self.itemHeightField.stringValue = @"150";
    self.itemHeightField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.itemHeightField setTarget:self];
    [self.itemHeightField setAction:@selector(itemSizeChanged:)];
    [self.controlsView addSubview:self.itemHeightField];
    
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
        [self.controlsView.heightAnchor constraintEqualToConstant:40]
    ]];
    
    // Symbols field + reset button
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolsTextField.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor constant:spacing],
        [self.symbolsTextField.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.symbolsTextField.widthAnchor constraintEqualToConstant:180],
        
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
    
    // ❌ ELIMINA QUESTI (vecchi constraint righe/colonne):
    // [self.rowsField.leadingAnchor constraintEqualToAnchor:self.volumeCheckbox.trailingAnchor constant:spacing]
    // [self.columnsField.leadingAnchor constraintEqualToAnchor:self.rowsField.trailingAnchor constant:4]
    
    // ✅ SOSTITUISCI CON QUESTI (nuovi constraint width/height):
    [NSLayoutConstraint activateConstraints:@[
        [self.itemWidthField.leadingAnchor constraintEqualToAnchor:self.volumeCheckbox.trailingAnchor constant:spacing],
        [self.itemWidthField.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.itemWidthField.widthAnchor constraintEqualToConstant:40]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.itemHeightField.leadingAnchor constraintEqualToAnchor:self.itemWidthField.trailingAnchor constant:4],
        [self.itemHeightField.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.itemHeightField.widthAnchor constraintEqualToConstant:40]
    ]];
    
    // Refresh button
    [NSLayoutConstraint activateConstraints:@[
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.itemHeightField.trailingAnchor constant:spacing],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.refreshButton.trailingAnchor constraintLessThanOrEqualToAnchor:self.controlsView.trailingAnchor constant:-spacing]
    ]];
}
    

- (void)setupScrollView {
    // ✅ FIX: Collection view layout CORRETTO
    NSCollectionViewGridLayout *gridLayout = [[NSCollectionViewGridLayout alloc] init];
    
    // ❌ PROBLEMA ERA QUI: minimumItemSize troppo piccolo e maximumItemSize troppo grande
    gridLayout.minimumItemSize = NSMakeSize(200, 150);  // Era 100,80 - troppo piccolo
    gridLayout.maximumItemSize = NSMakeSize(400, 300);  // Era 500,400 - troppo grande
    gridLayout.minimumInteritemSpacing = 10;
    gridLayout.minimumLineSpacing = 10;
    gridLayout.margins = NSEdgeInsetsMake(10, 10, 10, 10);
    
    // ✅ FIX: Configura ESPLICITAMENTE il numero di colonne

    
    NSLog(@"🔧 GridLayout configured: columns=%ld, minSize=%.0fx%.0f, maxSize=%.0fx%.0f",
          (long)gridLayout.maximumNumberOfColumns,
          gridLayout.minimumItemSize.width, gridLayout.minimumItemSize.height,
          gridLayout.maximumItemSize.width, gridLayout.maximumItemSize.height);
    
    // Collection view
    self.collectionView = [[NSCollectionView alloc] init];
    self.collectionView.collectionViewLayout = gridLayout;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.backgroundColors = @[[NSColor controlBackgroundColor]];
    
    // ✅ FIX: Registra la classe item CORRETTAMENTE
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
    
    NSLog(@"✅ NSCollectionView setup completed with proper grid configuration");
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

- (BarTimeframe)convertToBarTimeframe:(MiniBarTimeframe)timeframe {
    switch (timeframe) {
        case MiniBarTimeframe1Min:
            return BarTimeframe1Min;
        case MiniBarTimeframe5Min:
            return BarTimeframe5Min;
        case MiniBarTimeframe15Min:
            return BarTimeframe15Min;
        case MiniBarTimeframe30Min:
            return BarTimeframe30Min;
        case MiniBarTimeframe1Hour:
            return BarTimeframe1Hour;
        case MiniBarTimeframeDaily:
            return BarTimeframeDaily;
        case MiniBarTimeframeWeekly:
            return BarTimeframeWeekly;
        case MiniBarTimeframeMonthly:
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
    NSLog(@"🔨 rebuildMiniCharts called with symbols: %@", [self.symbols componentsJoinedByString:@","]);
    
    // Mantieni gli stessi MiniChart esistenti ma pulisci l'array
    [self.miniCharts removeAllObjects];
    
    if (self.symbols.count == 0) {
        NSLog(@"⚠️ No symbols to build charts for");
        [self.collectionView reloadData];
        return;
    }
    
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
    
    
    // ✅ FIX: Force layout update prima del reload
    [self.collectionView.collectionViewLayout invalidateLayout];
    
    // Aggiorna collection view
    [self.collectionView reloadData];
    
    NSLog(@"✅ MultiChartWidget: Rebuilt %lu mini charts with NSCollectionView", (unsigned long)self.miniCharts.count);
}

- (void)itemSizeChanged:(id)sender {
    NSInteger newWidth = self.itemWidthField.integerValue;
    NSInteger newHeight = self.itemHeightField.integerValue;
    
    // Validazione
    if (newWidth < 100) newWidth = 100;
    if (newWidth > 500) newWidth = 500;
    if (newHeight < 80) newHeight = 80;
    if (newHeight > 400) newHeight = 400;
    
    NSLog(@"🔧 Item size changing: %ldx%ld -> %ldx%ld",
          (long)self.itemWidth, (long)self.itemHeight, (long)newWidth, (long)newHeight);
    
    self.itemWidth = newWidth;
    self.itemHeight = newHeight;
    
    // Aggiorna field se corretti
    self.itemWidthField.integerValue = newWidth;
    self.itemHeightField.integerValue = newHeight;
    
    // Aggiorna layout collection view
    if ([self.collectionView.collectionViewLayout isKindOfClass:[NSCollectionViewGridLayout class]]) {
        NSCollectionViewGridLayout *gridLayout = (NSCollectionViewGridLayout *)self.collectionView.collectionViewLayout;
        gridLayout.minimumItemSize = NSMakeSize(newWidth, newHeight);
        gridLayout.maximumItemSize = NSMakeSize(newWidth * 1.2, newHeight * 1.2);
        
        NSLog(@"🔧 Updated grid layout: itemSize=%ldx%ld", (long)newWidth, (long)newHeight);
        
        [self.collectionView.collectionViewLayout invalidateLayout];
    }
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
    
    NSLog(@"✅ MultiChartWidget: Item size changed to %ldx%ld", (long)newWidth, (long)newHeight);
}


- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger count = self.miniCharts.count;
    return count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
                     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"🏗️ Collection view requesting item at indexPath: %ld/%ld",
          (long)indexPath.item, (long)self.miniCharts.count);
    
    MiniChartCollectionItem *item = [collectionView makeItemWithIdentifier:@"MiniChartItem"
                                                              forIndexPath:indexPath];
    
    // ✅ FIX: Se non riesce a creare l'item, crea uno vuoto invece di return nil
    if (!item) {
        NSLog(@"❌ Failed to create collection item, creating fallback");
        item = [[MiniChartCollectionItem alloc] init];
    }
    
    if (indexPath.item >= self.miniCharts.count) {
        NSLog(@"❌ Index %ld out of bounds for miniCharts array (count: %ld)",
              (long)indexPath.item, (long)self.miniCharts.count);
        return item;
    }
    
    MiniChart *miniChart = self.miniCharts[indexPath.item];
    if (!miniChart) {
        NSLog(@"❌ MiniChart at index %ld is nil", (long)indexPath.item);
        return item;
    }
    
    // Configura l'item con il MiniChart esistente
    [item configureMiniChart:miniChart];
    
    // Setup callbacks usando i metodi esistenti
    __weak typeof(self) weakSelf = self;
    item.onChartClicked = ^(MiniChart *chart) {
        NSLog(@"👆 Chart clicked callback: %@", chart.symbol);
        [weakSelf handleChartClick:chart];
    };
    
    item.onSetupContextMenu = ^(MiniChart *chart) {
        [weakSelf setupChartContextMenu:chart];
    };
    
    NSLog(@"✅ Created collection item for: %@", miniChart.symbol);
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
        
        // Mostra feedback temporaneo
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
        [self showTemporaryMessageForCollectionView:[NSString stringWithFormat:@"Sent %@ to chain", symbol]];
    }
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
        
        [self showTemporaryMessageForCollectionView:[NSString stringWithFormat:@"Sent %@ to chain", symbol]];
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
        
        [self showTemporaryMessageForCollectionView:[NSString stringWithFormat:@"Sent %@ to %@", symbol, colorName]];
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
        
        [self showTemporaryMessageForCollectionView:[NSString stringWithFormat:@"Removed %@", symbol]];
    }
}

#pragma mark - UI Feedback




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
    self.timeframe = (MiniBarTimeframe)index;
    
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
    // Con collection view, cerchiamo direttamente nell'array miniCharts
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
    
    // Refresh every 5min seconds
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:300.0
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
static NSString *const kMultiBarTimeframeKey = @"MultiChart_Timeframe";
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
    NSInteger savedTimeframe = [defaults integerForKey:kMultiBarTimeframeKey];
    NSInteger savedScaleType = [defaults integerForKey:kMultiChartScaleTypeKey];
    NSInteger savedMaxBars = [defaults integerForKey:kMultiChartMaxBarsKey];
    BOOL savedShowVolume = [defaults boolForKey:kMultiChartShowVolumeKey];
    NSInteger savedColumnsCount = [defaults integerForKey:kMultiChartColumnsCountKey];

    NSInteger savedItemWidth = [defaults integerForKey:kMultiChartItemWidthKey];
     NSInteger savedItemHeight = [defaults integerForKey:kMultiChartItemHeightKey];
    
    
    // Applica le impostazioni caricate con validazione
    
    // Chart Type (default: Line se non salvato)
    if (savedChartType >= MiniChartTypeLine && savedChartType <= MiniChartTypeCandle) {
        self.chartType = (MiniChartType)savedChartType;
    } else {
        self.chartType = MiniChartTypeLine; // Default
    }
    
    // Timeframe (default: Daily se non salvato)
    if (savedTimeframe >= MiniBarTimeframe5Min && savedTimeframe <= MiniBarTimeframeMonthly) {
        self.timeframe = (MiniBarTimeframe)savedTimeframe;
    } else {
        self.timeframe = MiniBarTimeframeDaily; // Default
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
    
    // Applica con validazione
      if (savedItemWidth >= 100 && savedItemWidth <= 500) {
          self.itemWidth = savedItemWidth;
      } else {
          self.itemWidth = 200; // Default
      }
      
      if (savedItemHeight >= 80 && savedItemHeight <= 400) {
          self.itemHeight = savedItemHeight;
      } else {
          self.itemHeight = 150; // Default
      }
  
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
    [defaults setInteger:self.timeframe forKey:kMultiBarTimeframeKey];
    [defaults setInteger:self.scaleType forKey:kMultiChartScaleTypeKey];
    [defaults setInteger:self.maxBars forKey:kMultiChartMaxBarsKey];
    [defaults setBool:self.showVolume forKey:kMultiChartShowVolumeKey];
    [defaults setInteger:self.columnsCount forKey:kMultiChartColumnsCountKey];
    [defaults setInteger:self.itemWidth forKey:kMultiChartItemWidthKey];
       [defaults setInteger:self.itemHeight forKey:kMultiChartItemHeightKey];
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
    
    if (self.itemWidthField) {
           self.itemWidthField.integerValue = self.itemWidth;
       }
       if (self.itemHeightField) {
           self.itemHeightField.integerValue = self.itemHeight;
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



- (void)updateChartSelection:(MiniChart *)selectedChart {
    // Rimuovi selezione da tutti i chart (stesso codice)
    for (MiniChart *chart in self.miniCharts) {
        if (chart.layer) {
            chart.layer.borderWidth = 0.0;
        }
    }
    
    // Aggiungi selezione al chart cliccato (stesso codice)
    if (selectedChart.layer) {
        selectedChart.layer.borderWidth = 2.0;
        selectedChart.layer.borderColor = [NSColor controlAccentColor].CGColor;
    }
    
    // ✅ NUOVO: Scroll al chart selezionato per assicurarsi che sia visibile
    NSInteger index = [self.miniCharts indexOfObject:selectedChart];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        [self.collectionView scrollToItemsAtIndexPaths:@[indexPath]
                                        scrollPosition:NSCollectionViewScrollPositionCenteredVertically];
    }
    
    // Animazione esistente rimane identica
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2;
        if (selectedChart.layer) {
            selectedChart.layer.backgroundColor = [NSColor.controlAccentColor colorWithAlphaComponent:0.1].CGColor;
        }
    } completionHandler:^{
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




@end
