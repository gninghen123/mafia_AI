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
#import "OtherDataSource.h"           // ✅ AGGIUNGERE QUESTO IMPORT
#import "DownloadManager.h"            // ✅ AGGIUNGERE ANCHE QUESTO SE NON GIÀ PRESENTE
#import "SavedChartData.h"


static NSString *const kMultiChartItemWidthKey = @"MultiChart_ItemWidth";
static NSString *const kMultiChartItemHeightKey = @"MultiChart_ItemHeight";
static NSString *const kMultiChartAutoRefreshEnabledKey = @"MultiChart_AutoRefreshEnabled";
static NSString *const kMultiChartIncludeAfterHoursKey = @"MultiChart_IncludeAfterHours";


@interface MultiChartWidget ()

// UI Components - Only declare internal ones not in header
@property (nonatomic, strong) NSView *controlsView;
@property (nonatomic, strong) NSButton *refreshButton;

// Layout
@property (nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *chartConstraints;

@end

@implementation MultiChartWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type {
    self = [super initWithType:type];
    if (self) {
        [self setupMultiChartDefaults];
    }
    return self;
}

- (void)setupMultiChartDefaults {
    // Default configuration
    _chartType = MiniChartTypeLine;
    _timeframe = MiniBarTimeframeDaily;
    _scaleType = MiniChartScaleLinear;
    self.timeRange = 1;

    _autoRefreshEnabled = NO;  // Default: disattivato

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
    [self setupImageExportContextMenu];

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
    
    // ✅ Timeframe segmented control
        self.timeframeSegmented = [[NSSegmentedControl alloc] init];
        self.timeframeSegmented.translatesAutoresizingMaskIntoConstraints = NO;
        self.timeframeSegmented.segmentCount = 8;
        [self.timeframeSegmented setLabel:@"1" forSegment:0];
        [self.timeframeSegmented setLabel:@"5" forSegment:1];
        [self.timeframeSegmented setLabel:@"15" forSegment:2];
        [self.timeframeSegmented setLabel:@"30" forSegment:3];
    [self.timeframeSegmented setLabel:@"1h" forSegment:4];
    [self.timeframeSegmented setLabel:@"12h" forSegment:5];
        [self.timeframeSegmented setLabel:@"D" forSegment:6];
        [self.timeframeSegmented setLabel:@"W" forSegment:7];
        [self.timeframeSegmented setLabel:@"M" forSegment:8];
        self.timeframeSegmented.selectedSegment = self.timeframe;
        self.timeframeSegmented.target = self;
        self.timeframeSegmented.action = @selector(timeframeChanged:);
        [self.controlsView addSubview:self.timeframeSegmented];

    // ✅ MODIFICA 2: Aggiungere afterhours switch DOPO volumeCheckbox
    // NUOVO CODICE DA AGGIUNGERE (dopo la volumeCheckbox):
        // AfterHours switch
        self.afterHoursSwitch = [[NSButton alloc] init];
        self.afterHoursSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        self.afterHoursSwitch.buttonType = NSButtonTypeSwitch;
        self.afterHoursSwitch.title = @"After Hours";
        self.afterHoursSwitch.target = self;
        self.afterHoursSwitch.action = @selector(afterHoursSwitchChanged:);
        [self.controlsView addSubview:self.afterHoursSwitch];

    // Scale type popup
    self.scaleTypePopup = [[NSPopUpButton alloc] init];
    [self.scaleTypePopup addItemsWithTitles:@[@"Linear", @"Log", @"Percent"]];
    self.scaleTypePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scaleTypePopup setTarget:self];
    [self.scaleTypePopup setAction:@selector(scaleTypeChanged:)];
    [self.controlsView addSubview:self.scaleTypePopup];
    
    // SOSTITUISCI tutto il blocco maxBarsField con:
    self.timeRangeSegmented = [[NSSegmentedControl alloc] init];
    self.timeRangeSegmented.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeRangeSegmented.segmentCount = 8;
    [self.timeRangeSegmented setLabel:@"1d" forSegment:0];
    [self.timeRangeSegmented setLabel:@"3d" forSegment:1];
    [self.timeRangeSegmented setLabel:@"5d" forSegment:2];
    [self.timeRangeSegmented setLabel:@"1m" forSegment:3];
    [self.timeRangeSegmented setLabel:@"3m" forSegment:4];
    [self.timeRangeSegmented setLabel:@"6m" forSegment:5];
    [self.timeRangeSegmented setLabel:@"1y" forSegment:6];
    [self.timeRangeSegmented setLabel:@"5y" forSegment:7];
    self.timeRangeSegmented.selectedSegment = self.timeRange;
    self.timeRangeSegmented.target = self;
    self.timeRangeSegmented.action = @selector(timeRangeChanged:);
    [self.controlsView addSubview:self.timeRangeSegmented];
    
    
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
    
    
    self.autoRefreshToggle = [[NSButton alloc] init];
     self.autoRefreshToggle.translatesAutoresizingMaskIntoConstraints = NO;
     self.autoRefreshToggle.buttonType = NSButtonTypeSwitch;
     self.autoRefreshToggle.title = @"Auto Refresh";
     self.autoRefreshToggle.target = self;
     self.autoRefreshToggle.action = @selector(autoRefreshToggleChanged:);
     [self.controlsView addSubview:self.autoRefreshToggle];
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
        [self.symbolsTextField.widthAnchor constraintEqualToConstant:120],
        
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
    
    // Timeframe segmented
    [NSLayoutConstraint activateConstraints:@[
        [self.timeframeSegmented.leadingAnchor constraintEqualToAnchor:self.chartTypePopup.trailingAnchor constant:spacing],
        [self.timeframeSegmented.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.timeframeSegmented.widthAnchor constraintEqualToConstant:260]  
    ]];

    
    // Scale type popup
       [NSLayoutConstraint activateConstraints:@[
           [self.scaleTypePopup.leadingAnchor constraintEqualToAnchor:self.timeframeSegmented.trailingAnchor constant:spacing],
           [self.scaleTypePopup.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
           [self.scaleTypePopup.widthAnchor constraintEqualToConstant:70]
       ]];
    
    // Max bars field
    [NSLayoutConstraint activateConstraints:@[
        [self.timeRangeSegmented.leadingAnchor constraintEqualToAnchor:self.scaleTypePopup.trailingAnchor constant:spacing],
    [self.timeRangeSegmented.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
    [self.timeRangeSegmented.widthAnchor constraintEqualToConstant:250]
    ]];
    
    // Volume checkbox
    [NSLayoutConstraint activateConstraints:@[
        [self.volumeCheckbox.leadingAnchor constraintEqualToAnchor:self.timeRangeSegmented.trailingAnchor constant:spacing],
        [self.volumeCheckbox.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
          [self.afterHoursSwitch.leadingAnchor constraintEqualToAnchor:self.volumeCheckbox.trailingAnchor constant:spacing],
          [self.afterHoursSwitch.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor]
      ]];
    
    // ✅ SOSTITUISCI CON QUESTI (nuovi constraint width/height):
    [NSLayoutConstraint activateConstraints:@[
        [self.itemWidthField.leadingAnchor constraintEqualToAnchor:self.afterHoursSwitch.trailingAnchor constant:spacing],
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
    
    [NSLayoutConstraint activateConstraints:@[
           [self.autoRefreshToggle.leadingAnchor constraintEqualToAnchor:self.refreshButton.trailingAnchor constant:15],
           [self.autoRefreshToggle.centerYAnchor constraintEqualToAnchor:self.refreshButton.centerYAnchor]
       ]];
}
    

- (void)setupScrollView {
    // ✅ Collection view layout with adaptive sizing
    NSCollectionViewGridLayout *gridLayout = [[NSCollectionViewGridLayout alloc] init];

    // Initial sizes (will be updated by updateAdaptiveLayout)
    gridLayout.minimumItemSize = NSMakeSize(self.itemWidth, self.itemHeight);
    gridLayout.maximumItemSize = NSMakeSize(self.itemWidth * 2, self.itemHeight * 2);
    gridLayout.minimumInteritemSpacing = 10;
    gridLayout.minimumLineSpacing = 10;
    gridLayout.margins = NSEdgeInsetsMake(10, 10, 10, 10);

    NSLog(@"🔧 GridLayout configured: minSize=%.0fx%.0f, maxSize=%.0fx%.0f (will be updated adaptively)",
          gridLayout.minimumItemSize.width, gridLayout.minimumItemSize.height,
          gridLayout.maximumItemSize.width, gridLayout.maximumItemSize.height);
    
    // Collection view
    self.collectionView = [[NSCollectionView alloc] init];
    self.collectionView.collectionViewLayout = gridLayout;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
   // self.collectionView.backgroundColors = @[[NSColor controlBackgroundColor]];
    self.collectionView.allowsMultipleSelection = YES;
    self.collectionView.allowsEmptySelection = NO;
    self.collectionView.selectable = YES;
    
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

    // Observe frame changes to update adaptive layout when view resizes
    self.collectionScrollView.postsFrameChangedNotifications = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(scrollViewFrameDidChange:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self.collectionScrollView];

    NSLog(@"✅ NSCollectionView setup completed with proper grid configuration");
}

- (void)scrollViewFrameDidChange:(NSNotification *)notification {
    // Update adaptive layout when scroll view resizes
    [self updateAdaptiveLayout];
}


- (IBAction)timeRangeChanged:(id)sender {
    self.timeRange = (NSInteger)self.timeRangeSegmented.selectedSegment;
    [self loadDataFromDataHub];
}

- (NSInteger)calculateMaxBarsForTimeRange {
    NSArray *days = @[@1, @3, @5, @30, @90, @180, @365, @1825];
    NSInteger daysCount = [days[self.timeRange] integerValue];
    
    switch (self.timeframe) {
        case MiniBarTimeframe1Min: return daysCount * 390;
        case MiniBarTimeframe5Min: return daysCount * 78;
        case MiniBarTimeframe15Min: return daysCount * 26;
        case MiniBarTimeframe30Min: return daysCount * 13;
        case MiniBarTimeframe1Hour: return daysCount * 7;
        case MiniBarTimeframeDaily: return daysCount;
        case MiniBarTimeframeWeekly: return daysCount / 7;
        case MiniBarTimeframeMonthly: return daysCount / 30;
        default: return daysCount;
    }
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
    [self saveSettingsOnExit];

}

#pragma mark - View Lifecycle

- (void)viewWillAppear {
    [super viewWillAppear];
    [self loadDataFromDataHub];
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
}

- (void)viewDidLayout {
    [super viewDidLayout];
    // Update adaptive layout after view is laid out and has final frame
    [self updateAdaptiveLayout];
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
                                            barCount:[self calculateMaxBarsForTimeRange]
                                   needExtendedHours:self.afterHoursSwitch.state
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
                                                barCount:[self calculateMaxBarsForTimeRange]
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
        case MiniBarTimeframe12Hour:
            return BarTimeframe12Hour;
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
        miniChart.showVolume = self.showVolume;
        
        // Setup appearance esistente
        [self setupChartSelectionAppearance:miniChart];
        
        [self.miniCharts addObject:miniChart];
    }
    
    
    // ✅ Update adaptive layout based on chart count
    [self updateAdaptiveLayout];

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

    // Aggiorna layout adattivo
    [self updateAdaptiveLayout];
}

#pragma mark - Adaptive Layout

- (void)updateAdaptiveLayout {
    // Get chart count
    NSInteger chartCount = self.miniCharts.count;
    if (chartCount == 0) {
        NSLog(@"⚠️ updateAdaptiveLayout: No charts, skipping");
        return;
    }

    if (!self.collectionScrollView) {
        NSLog(@"⚠️ updateAdaptiveLayout: No scroll view, skipping");
        return;
    }

    // Get available space in scroll view (use documentVisibleRect for actual visible area)
    NSSize availableSize = self.collectionScrollView.documentVisibleRect.size;

    // Minimum sizes from controls (these are the user-defined minimums)
    CGFloat minWidth = self.itemWidth;
    CGFloat minHeight = self.itemHeight;

    NSLog(@"📐 updateAdaptiveLayout: chartCount=%ld, availableSize=%.0fx%.0f, minSize=%.0fx%.0f",
          (long)chartCount, availableSize.width, availableSize.height, minWidth, minHeight);

    // Calculate optimal grid layout based on chart count
    NSInteger columns, rows;

    if (chartCount == 1) {
        // Single chart: full space
        columns = 1;
        rows = 1;
    } else if (chartCount == 2) {
        // Two charts: side by side
        columns = 2;
        rows = 1;
    } else if (chartCount <= 4) {
        // 3-4 charts: 2x2 grid
        columns = 2;
        rows = (chartCount <= 2) ? 1 : 2;
    } else if (chartCount <= 6) {
        // 5-6 charts: 3x2 grid
        columns = 3;
        rows = 2;
    } else if (chartCount <= 9) {
        // 7-9 charts: 3x3 grid
        columns = 3;
        rows = 3;
    } else if (chartCount <= 12) {
        // 10-12 charts: 4x3 grid
        columns = 4;
        rows = 3;
    } else {
        // More charts: calculate dynamically
        columns = (NSInteger)ceil(sqrt(chartCount));
        rows = (NSInteger)ceil((double)chartCount / columns);
    }

    // Calculate item sizes based on available space and grid
    CGFloat padding = 10;
    CGFloat totalPaddingWidth = padding * (columns + 1);
    CGFloat totalPaddingHeight = padding * (rows + 1);

    CGFloat availableWidthForItems = availableSize.width - totalPaddingWidth;
    CGFloat availableHeightForItems = availableSize.height - totalPaddingHeight;

    CGFloat calculatedWidth = availableWidthForItems / columns;
    CGFloat calculatedHeight = availableHeightForItems / rows;

    // Apply minimum constraints - items can be larger than minimum, but never smaller
    CGFloat maxWidth = MAX(minWidth, calculatedWidth);
    CGFloat maxHeight = MAX(minHeight, calculatedHeight);

    // Cap maximum size to something reasonable (to prevent huge items)
    maxWidth = MIN(maxWidth, 800);
    maxHeight = MIN(maxHeight, 600);

    NSLog(@"📊 Calculated layout: %ldx%ld grid, itemSize: min(%.0fx%.0f) max(%.0fx%.0f)",
          (long)columns, (long)rows, minWidth, minHeight, maxWidth, maxHeight);

    // Update grid layout
    if ([self.collectionView.collectionViewLayout isKindOfClass:[NSCollectionViewGridLayout class]]) {
        NSCollectionViewGridLayout *gridLayout = (NSCollectionViewGridLayout *)self.collectionView.collectionViewLayout;

        // Set minimum size (user-defined minimum)
        gridLayout.minimumItemSize = NSMakeSize(minWidth, minHeight);

        // Set maximum size (calculated based on available space and chart count)
        gridLayout.maximumItemSize = NSMakeSize(maxWidth, maxHeight);

        // Update column count to match calculated grid
        gridLayout.maximumNumberOfColumns = columns;

        NSLog(@"✅ Grid layout updated: columns=%ld, minSize=%.0fx%.0f, maxSize=%.0fx%.0f",
              (long)columns, minWidth, minHeight, maxWidth, maxHeight);

        [gridLayout invalidateLayout];
    }
}


- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger count = self.miniCharts.count;
    return count;
}

// Sostituisci il metodo itemForRepresentedObjectAtIndexPath: in MultiChartWidget.m

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
    
    
    // ✅ AGGIUNTO: Setup callbacks
    __weak typeof(self) weakSelf = self;
    
    // ✅ NUOVO: Callback per click su chart -> invia alla chain
    item.onChartClicked = ^(MiniChart *chart) {
        NSLog(@"📈 MultiChartWidget: Chart clicked callback for: %@", chart.symbol);
        [weakSelf handleChartSelection:chart];
    };
    
    // Setup context menu callback (esistente)
    item.onSetupContextMenu = ^(MiniChart *chart) {
        [weakSelf setupChartContextMenu:chart];
    };
    
    
    NSLog(@"✅ Created collection item for: %@ with callbacks", miniChart.symbol);
    return item;
}

// ✅ AGGIUNTO: Metodo per gestire la selezione di un chart
- (void)handleChartSelection:(MiniChart *)selectedChart {
    NSLog(@"🎯 MultiChartWidget: Handling selection for chart: %@", selectedChart.symbol);
    
    // Aggiorna la selezione visiva
    [self updateChartSelection:selectedChart];
    
    // ✅ INVIA ALLA CHAIN se attiva
    if (self.chainActive && selectedChart.symbol) {
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[selectedChart.symbol]
        }];
        
        NSLog(@"🔗 MultiChartWidget: Chart '%@' sent to chain", selectedChart.symbol);
        
        // Mostra feedback visivo
        [self showTemporaryMessageForCollectionView:
         [NSString stringWithFormat:@"📈 %@ sent to chain", selectedChart.symbol]];
    } else if (!self.chainActive) {
        NSLog(@"⚠️ MultiChartWidget: Chain not active, selection not broadcasted");
        
        // Anche se chain non attiva, mostra feedback che il chart è selezionato
        [self showTemporaryMessageForCollectionView:
         [NSString stringWithFormat:@"📊 %@ selected", selectedChart.symbol]];
    }
}
#pragma mark - NSCollectionView Delegate Selection

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    NSIndexPath *indexPath = indexPaths.anyObject;
    if (indexPath && indexPath.item < self.miniCharts.count) {
        MiniChart *selectedChart = self.miniCharts[indexPath.item];
        [self updateChartSelection:selectedChart];
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
- (void)setupChartSelectionAppearance:(MiniChart *)chart {
    // Aggiungi bordo per indicare lo stato di selezione
    chart.wantsLayer = YES;
    chart.layer.borderWidth = 0.0;
    chart.layer.borderColor = [NSColor controlAccentColor].CGColor;
    chart.layer.cornerRadius = 4.0;
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
    NSString *input = self.symbolsTextField.stringValue;
    
    // ✅ NUOVO: Check for Finviz search pattern
    if ([input hasPrefix:@"?"]) {
        NSString *keyword = [input substringFromIndex:1]; // Remove the '?'
        keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (keyword.length > 0) {
            [self performFinvizSearch:keyword];
            return;
        } else {
            NSLog(@"⚠️ Empty keyword after '?' - ignoring");
            return;
        }
    }
    
    // ✅ FALLBACK: Existing logic for normal symbol input
    NSArray<NSString *> *newSymbols = [self parseSymbolsFromInput:input];
    
    if ([newSymbols isEqualToArray:self.symbols]) {
        NSLog(@"MultiChartWidget: Symbols unchanged, skipping update");
        return;
    }
    
    self.symbols = newSymbols;
    self.symbolsString = [newSymbols componentsJoinedByString:@", "];
    
    [self rebuildMiniCharts];
    [self loadDataFromDataHub];
    
    // Auto-save settings if enabled
    [self saveSettingsToUserDefaults];
    
    NSLog(@"MultiChartWidget: Updated symbols: %@", self.symbolsString);
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
    // Ottieni il nuovo timeframe dal segmented control
    NSInteger segmentIndex = self.timeframeSegmented.selectedSegment;
    self.timeframe = (MiniBarTimeframe)segmentIndex;
    
    // ✅ LOGICA AUTO-UPDATE DATE RANGE
    // Prima di caricare i dati, aggiorna il timeRange in base al timeframe
    switch (self.timeframe) {
        case MiniBarTimeframe1Min:
            self.timeRange = 0;  // 1 day
            self.timeRangeSegmented.selectedSegment = 0;
            NSLog(@"📊 Timeframe changed to 1m → Auto-set range to 1 day");
            break;
            
        case MiniBarTimeframe5Min:
        case MiniBarTimeframe15Min:
            self.timeRange = 1;  // 3 days
            self.timeRangeSegmented.selectedSegment = 1;
            NSLog(@"📊 Timeframe changed to 5m/15m → Auto-set range to 3 days");
            break;
            
        case MiniBarTimeframe30Min:
        case MiniBarTimeframe1Hour:
        case MiniBarTimeframe12Hour:
            self.timeRange = 4;  // 3 months
            self.timeRangeSegmented.selectedSegment = 4;
            NSLog(@"📊 Timeframe changed to 30m/1h/12h → Auto-set range to 3 months");
            break;
            
        case MiniBarTimeframeDaily:
            self.timeRange = 4;  // 3 months
            self.timeRangeSegmented.selectedSegment = 4;
            NSLog(@"📊 Timeframe changed to Daily → Auto-set range to 3 months");
            break;
            
        case MiniBarTimeframeWeekly:
        case MiniBarTimeframeMonthly:
            self.timeRange = 6;  // 1 year
            self.timeRangeSegmented.selectedSegment = 6;
            NSLog(@"📊 Timeframe changed to Weekly/Monthly → Auto-set range to 1 year");
            break;
            
        default:
            NSLog(@"⚠️ Unknown timeframe: %ld", (long)self.timeframe);
            break;
    }
    
    // Reload data con nuovo timeframe e range
    [self loadDataFromDataHub];
}

- (void)afterHoursSwitchChanged:(id)sender {
   
    // Ricarica i dati con la nuova impostazione
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
                                                    barCount:[self calculateMaxBarsForTimeRange]
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


- (void)handleChainAction:(NSString *)action withData:(id)data fromWidget:(BaseWidget *)sender {
    if ([action isEqualToString:@"loadChartPattern"]) {
        [self loadChartPatternFromChainData:data fromWidget:sender];
    } else if ([action isEqualToString:@"loadScreenerData"]) {
        // ✅ NUOVO: Gestisce dati screener con historicalBars già caricati
        [self loadScreenerDataFromChainData:data fromWidget:sender];
    } else {
        [super handleChainAction:action withData:data fromWidget:sender];
    }
}

-  (void)loadScreenerDataFromChainData:(NSDictionary *)data fromWidget:(BaseWidget *)sender {
    // 1️⃣ VALIDAZIONE DATI
    if (!data || ![data isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ MultiChartWidget: Invalid screener data received from %@", NSStringFromClass([sender class]));
        return;
    }
    
    NSString *symbol = data[@"symbol"];
    NSArray<HistoricalBarModel *> *historicalBars = data[@"historicalBars"];
    NSNumber *timeframeNum = data[@"timeframe"];
    NSString *source = data[@"source"] ?: @"Unknown";
    
    // Validazione campi essenziali
    if (!symbol || !historicalBars || historicalBars.count == 0) {
        NSLog(@"❌ MultiChartWidget: Missing essential screener data - symbol:%@ bars:%lu",
              symbol, (unsigned long)historicalBars.count);
        [self showTemporaryMessageForCollectionView:@"❌ Missing screener data"];
        return;
    }
    
    BarTimeframe timeframe = timeframeNum ? [timeframeNum integerValue] : BarTimeframeDaily;
    
    NSLog(@"📊 MultiChartWidget: Loading screener data for %@ (%lu bars) from model: %@",
          symbol, (unsigned long)historicalBars.count, source);
    
    // ✅ AGGIUNGI IL SIMBOLO AL TEXTFIELD (separato da virgola)
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentText = self.symbolsTextField.stringValue;
        
        if (!currentText || currentText.length == 0) {
            // TextField vuoto: aggiungi solo il simbolo
            self.symbolsTextField.stringValue = symbol;
        } else {
            // TextField ha già simboli: aggiungi con virgola
            NSArray *existingSymbols = [currentText componentsSeparatedByString:@","];
            NSMutableArray *trimmedSymbols = [NSMutableArray array];
            
            for (NSString *existing in existingSymbols) {
                NSString *trimmed = [existing stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (trimmed.length > 0) {
                    [trimmedSymbols addObject:trimmed];
                }
            }
            
            // Aggiungi solo se non è già presente
            if (![trimmedSymbols containsObject:symbol]) {
                [trimmedSymbols addObject:symbol];
                self.symbolsTextField.stringValue = [trimmedSymbols componentsJoinedByString:@", "];
            }
        }
    });
    
    // 2️⃣ CREA MINICHART CON DATI STATICI
    MiniChart *miniChart = [[MiniChart alloc] initWithFrame:CGRectMake(0, 0, self.itemWidth, self.itemHeight)];
    
    // ✅ SIMBOLO NEL CAMPO PRINCIPALE (solo il ticker)
    miniChart.symbol = symbol;
    
    // ✅ NOME DEL MODELLO NEL DESCRIPTION LABEL
    if (miniChart.descriptionLabel) {
        miniChart.descriptionLabel.stringValue = source;
        miniChart.descriptionLabel.hidden = NO;
    }
    
    // Configura il MiniChart
    miniChart.chartType = self.chartType;
    miniChart.timeframe = [self convertFromBarTimeframe:timeframe];
    miniChart.scaleType = self.scaleType;
    miniChart.showVolume = self.showVolume;
    
    // 3️⃣ CARICA DATI STATICI (già pronti, non serve fetch)
    [miniChart updateWithHistoricalBars:historicalBars];
    
    // 4️⃣ AGGIUNGI ALLA COLLEZIONE
    [self.miniCharts addObject:miniChart];
    
    // 5️⃣ AGGIORNA UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
        
        // Scroll all'ultimo item aggiunto
        NSInteger lastIndex = self.miniCharts.count - 1;
        NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:lastIndex inSection:0];
        [self.collectionView scrollToItemsAtIndexPaths:@[lastIndexPath]
                                        scrollPosition:NSCollectionViewScrollPositionBottom];
        
        // ✅ FEEDBACK CON SIMBOLO E MODELLO SEPARATI
        NSString *feedbackMessage = [NSString stringWithFormat:@"📊 Added %@ from %@", symbol, source];
        [self showTemporaryMessageForCollectionView:feedbackMessage];
        
        NSLog(@"✅ MultiChartWidget: Added chart for %@ (Model: %@)", symbol, source);
    });
}


- (void)loadChartPatternFromChainData:(NSDictionary *)data fromWidget:(BaseWidget *)sender {
    // 1️⃣ VALIDAZIONE DATI
    if (!data || ![data isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ MultiChartWidget: Invalid pattern data received from %@", NSStringFromClass([sender class]));
        return;
    }
    
    NSString *patternID = data[@"patternID"];
    NSString *symbol = data[@"symbol"];
    NSString *savedDataReference = data[@"savedDataReference"];
    NSDate *patternStartDate = data[@"patternStartDate"];
    NSDate *patternEndDate = data[@"patternEndDate"];
    NSString *patternType = data[@"patternType"];
    
    if (!patternID || !savedDataReference || !symbol) {
        NSLog(@"❌ MultiChartWidget: Missing essential pattern data");
        return;
    }
    
    // 2️⃣ CARICA SAVEDCHARTDATA
    NSString *directory = [CommonTypes savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedDataReference];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    if (!savedData || !savedData.isDataValid) {
        NSLog(@"❌ MultiChartWidget: Failed to load SavedChartData for pattern %@", patternID);
        [self showTemporaryMessageForCollectionView:@"❌ Failed to load pattern data"];
        return;
    }
    
    // 3️⃣ CREA MINICHART CON DATI STATICI
    MiniChart *miniChart = [[MiniChart alloc] initWithFrame:CGRectMake(0, 0, self.itemWidth, self.itemHeight)];
    
    // ✅ DENOMINAZIONE: "PatternType Symbol" o "Saved Symbol"
    NSString *displayName;
    if (patternType && patternType.length > 0) {
        displayName = [NSString stringWithFormat:@"%@ %@", patternType, symbol];
    } else {
        displayName = [NSString stringWithFormat:@"Saved %@", symbol];
    }
    
    // Configura il MiniChart
    miniChart.symbol = displayName;  // ✅ Usa display name invece del simbolo originale
    miniChart.chartType = self.chartType;
    miniChart.timeframe = [self convertFromBarTimeframe:savedData.timeframe];
    miniChart.scaleType = self.scaleType;
    miniChart.showVolume = self.showVolume;
    
    // 4️⃣ CARICA DATI STATICI
    NSArray<HistoricalBarModel *> *barsToShow = savedData.historicalBars;
    
    // Se ci sono date pattern specifiche, estrai solo quel range
    if (patternStartDate && patternEndDate && barsToShow.count > 0) {
        NSInteger startIndex = NSNotFound;
        NSInteger endIndex = NSNotFound;
        
        for (NSInteger i = 0; i < barsToShow.count; i++) {
            HistoricalBarModel *bar = barsToShow[i];
            if (startIndex == NSNotFound && [bar.date compare:patternStartDate] != NSOrderedAscending) {
                startIndex = i;
            }
            if ([bar.date compare:patternEndDate] != NSOrderedDescending) {
                endIndex = i;
            }
        }
        
        if (startIndex != NSNotFound && endIndex != NSNotFound && startIndex <= endIndex) {
            NSInteger padding = MAX(1, (endIndex - startIndex + 1) / 10); // 10% padding
            NSInteger paddedStart = MAX(0, startIndex - padding);
            NSInteger paddedEnd = MIN(barsToShow.count - 1, endIndex + padding);
            
            NSRange range = NSMakeRange(paddedStart, paddedEnd - paddedStart + 1);
            barsToShow = [barsToShow subarrayWithRange:range];
            
            NSLog(@"📊 MultiChartWidget: Using pattern range [%ld-%ld] with padding", (long)startIndex, (long)endIndex);
        }
    }
    
    // Carica i dati nel MiniChart
    [miniChart updateWithHistoricalBars:barsToShow];
    
    // 5️⃣ AGGIUNGI ALLA COLLEZIONE
    [self.miniCharts addObject:miniChart];
    
    // Aggiorna la UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
        
        // Scroll all'ultimo item aggiunto
        NSInteger lastIndex = self.miniCharts.count - 1;
        NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:lastIndex inSection:0];
        [self.collectionView scrollToItemsAtIndexPaths:@[lastIndexPath]
                                        scrollPosition:NSCollectionViewScrollPositionBottom];
        
        // Feedback all'utente
        NSString *feedbackMessage = [NSString stringWithFormat:@"📊 Added %@", displayName];
        [self showTemporaryMessageForCollectionView:feedbackMessage];
        
        NSLog(@"✅ MultiChartWidget: Added pattern chart '%@' from %@", displayName, NSStringFromClass([sender class]));
    });
}

// ✅ HELPER METHOD: Converte da BarTimeframe a MiniBarTimeframe
- (MiniBarTimeframe)convertFromBarTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:
            return MiniBarTimeframe1Min;
        case BarTimeframe5Min:
            return MiniBarTimeframe5Min;
        case BarTimeframe15Min:
            return MiniBarTimeframe15Min;
        case BarTimeframe30Min:
            return MiniBarTimeframe30Min;
        case BarTimeframe1Hour:
            return MiniBarTimeframe1Hour;
        case BarTimeframe12Hour:
            return MiniBarTimeframe12Hour;
        case BarTimeframeDaily:
            return MiniBarTimeframeDaily;
        case BarTimeframeWeekly:
            return MiniBarTimeframeWeekly;
        case BarTimeframeMonthly:
            return MiniBarTimeframeMonthly;
        default:
            return MiniBarTimeframeDaily;
    }
}


- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"MultiChartWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
    
    
    // ✅ ENHANCED: Check for actual changes
    if ([symbols isEqualToArray:self.symbols]) {
        NSLog(@"MultiChartWidget: No new symbols to add, current list unchanged");
        return;
    }
    [self.miniCharts removeAllObjects];
    
    self.symbols = symbols;
    
    // Aggiorna il campo di testo
    self.symbolsString = [symbols componentsJoinedByString:@", "];
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
    state[@"showVolume"] = @(self.showVolume);
    state[@"timeRange"] = @(self.timeRange);
    state[@"itemWidth"] = @(self.itemWidth);
    state[@"itemHeight"] = @(self.itemHeight);
    state[@"autoRefreshEnabled"] = @(self.autoRefreshEnabled);

    // Save symbols string
    if (self.symbolsString) {
        state[@"symbolsString"] = self.symbolsString;
    }

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

    if (state[@"showVolume"]) {
        self.showVolume = [state[@"showVolume"] boolValue];
    }

    if (state[@"timeRange"]) {
        self.timeRange = [state[@"timeRange"] integerValue];
    }

    if (state[@"itemWidth"]) {
        self.itemWidth = [state[@"itemWidth"] floatValue];
    }

    if (state[@"itemHeight"]) {
        self.itemHeight = [state[@"itemHeight"] floatValue];
    }

    if (state[@"autoRefreshEnabled"]) {
        self.autoRefreshEnabled = [state[@"autoRefreshEnabled"] boolValue];
    }

    // Restore symbols string
    if (state[@"symbolsString"]) {
        self.symbolsString = state[@"symbolsString"];
        // Also update the text field
        if (self.symbolsTextField) {
            self.symbolsTextField.stringValue = self.symbolsString;
        }
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
    BOOL savedShowVolume = [defaults boolForKey:kMultiChartShowVolumeKey];

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
    if (savedTimeframe) {
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
    self.afterHoursSwitch.state = [defaults boolForKey:kMultiChartIncludeAfterHoursKey];

    if ([defaults objectForKey:kMultiChartAutoRefreshEnabledKey] == nil) {
           self.autoRefreshEnabled = NO;  // Default disabilitato
       } else {
           self.autoRefreshEnabled = [defaults boolForKey:kMultiChartAutoRefreshEnabledKey];
       }
       
    
    // Show Volume (default: YES se non salvato)
    // boolForKey ritorna NO se la key non esiste, quindi controlliamo se la key esiste
    if ([defaults objectForKey:kMultiChartShowVolumeKey] != nil) {
        self.showVolume = savedShowVolume;
    } else {
        self.showVolume = YES; // Default
    }
    
    // Applica con validazione
      if (savedItemWidth >= 100 ) {
          self.itemWidth = savedItemWidth;
      } else {
          self.itemWidth = 200; // Default
      }
      
      if (savedItemHeight >= 80 ) {
          self.itemHeight = savedItemHeight;
      } else {
          self.itemHeight = 150; // Default
      }
  
        self.symbolsString = @"";
        self.symbols = @[];
    
    
   
}

- (void)saveSettingsToUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Salva tutte le impostazioni correnti
    [defaults setInteger:self.chartType forKey:kMultiChartChartTypeKey];
    [defaults setInteger:self.timeframe forKey:kMultiBarTimeframeKey];
    [defaults setInteger:self.scaleType forKey:kMultiChartScaleTypeKey];
    [defaults setBool:self.showVolume forKey:kMultiChartShowVolumeKey];
    [defaults setInteger:self.itemWidth forKey:kMultiChartItemWidthKey];
       [defaults setInteger:self.itemHeight forKey:kMultiChartItemHeightKey];
    [defaults setBool:self.autoRefreshEnabled forKey:kMultiChartAutoRefreshEnabledKey];
    [defaults setBool:self.afterHoursSwitch.state forKey:kMultiChartIncludeAfterHoursKey];

    // Forza la sincronizzazione immediata
    [defaults synchronize];
    
  
}

- (void)updateUIFromSettings {
    // Aggiorna i controlli UI per riflettere le impostazioni caricate

    // Chart Type Popup
    if (self.chartTypePopup && self.chartType < self.chartTypePopup.numberOfItems) {
        [self.chartTypePopup selectItemAtIndex:self.chartType];
    }

    // Timeframe Segmented
    if (self.timeframeSegmented && self.timeframe < self.timeframeSegmented.segmentCount) {
        self.timeframeSegmented.selectedSegment = self.timeframe;
    }

   

    // Scale Type Popup
    if (self.scaleTypePopup && self.scaleType < self.scaleTypePopup.numberOfItems) {
        [self.scaleTypePopup selectItemAtIndex:self.scaleType];
    }

    // Volume Checkbox
    if (self.volumeCheckbox) {
        self.volumeCheckbox.state = self.showVolume ? NSControlStateValueOn : NSControlStateValueOff;
    }

    // Time Range Segmented Control
    if (self.timeRangeSegmented && self.timeRange < self.timeRangeSegmented.segmentCount) {
        self.timeRangeSegmented.selectedSegment = self.timeRange;
    }

    // Auto Refresh Toggle
    if (self.autoRefreshToggle) {
        self.autoRefreshToggle.state = self.autoRefreshEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    }
    // Item Width/Height Fields
    if (self.itemWidthField) {
        self.itemWidthField.integerValue = self.itemWidth;
    }
    if (self.itemHeightField) {
        self.itemHeightField.integerValue = self.itemHeight;
    }

    // Symbols TextField (already updated in restoreState, but ensure it's set)
    if (self.symbolsTextField && self.symbolsString) {
        self.symbolsTextField.stringValue = self.symbolsString;
    }

    NSLog(@"📋 MultiChartWidget: Updated UI from settings (chartType=%ld, timeframe=%ld, timeRange=%ld, autoRefresh=%d)",
          (long)self.chartType, (long)self.timeframe, (long)self.timeRange, self.autoRefreshEnabled);
}

#pragma mark - Enhanced Action Methods with Auto-Save

// Override dei metodi action esistenti per aggiungere auto-save

- (void)chartTypeChangedWithAutoSave:(id)sender {
    // Chiama il metodo originale
    [self chartTypeChanged:sender];
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
}



- (void)scaleTypeChangedWithAutoSave:(id)sender {
    // Chiama il metodo originale
    [self scaleTypeChanged:sender];
    
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
    
    if (self.timeframeSegmented) {
          self.timeframeSegmented.target = self;
          self.timeframeSegmented.action = @selector(timeframeChanged:);
      }

      if (self.afterHoursSwitch) {
          self.afterHoursSwitch.target = self;
          self.afterHoursSwitch.action = @selector(afterHoursSwitchChanged:);
      }
    
    if (self.scaleTypePopup) {
        self.scaleTypePopup.target = self;
        self.scaleTypePopup.action = @selector(scaleTypeChangedWithAutoSave:);
    }
    if (self.autoRefreshToggle) {
           self.autoRefreshToggle.target = self;
           self.autoRefreshToggle.action = @selector(autoRefreshToggleChanged:);
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
    [self.miniCharts removeAllObjects];
    self.symbolsTextField.stringValue = @"";
    [self.collectionView reloadData];
}

- (void)resetSymbolsField {
    self.symbolsTextField.stringValue = @"";
}



// Modifica il metodo updateChartSelection: in MultiChartWidget.m

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
    
    // ✅ NUOVO: Invia simbolo alla chain se attiva
    if (self.chainActive && selectedChart.symbol) {
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[selectedChart.symbol]
        }];
        
        NSLog(@"🔗 MultiChartWidget: Selected chart '%@' sent to chain", selectedChart.symbol);
    }
    
    // Scroll al chart selezionato
    NSInteger index = [self.miniCharts indexOfObject:selectedChart];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        [self.collectionView scrollToItemsAtIndexPaths:@[indexPath]
                                        scrollPosition:NSCollectionViewScrollPositionCenteredVertically];
    }
    
    // Animazione UI esistente
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

#pragma mark - Enhanced Action Methods with Auto-Save (AGGIUNGI)

// ✅ NUOVO: Action method per toggle autorefresh
- (void)autoRefreshToggleChanged:(id)sender {
    self.autoRefreshEnabled = (self.autoRefreshToggle.state == NSControlStateValueOn);
    
    NSLog(@"MultiChartWidget: AutoRefresh toggled to %@", self.autoRefreshEnabled ? @"ON" : @"OFF");
    
    // Salva automaticamente
    [self saveSettingsToUserDefaults];
    
    // ✅ GESTIONE OBSERVER: Aggiungi/rimuovi observer in base allo stato
    if (self.autoRefreshEnabled) {
        [self registerForNotifications];
        NSLog(@"MultiChartWidget: AutoRefresh enabled - observer registered");
    } else {
        [self unregisterFromNotifications];
        NSLog(@"MultiChartWidget: AutoRefresh disabled - observer removed");
    }
}

- (void)unregisterFromNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Rimuovi solo gli observer per auto-refresh
    [nc removeObserver:self name:@"DataHubQuoteUpdatedNotification" object:nil];
    [nc removeObserver:self name:@"DataHubHistoricalDataUpdatedNotification" object:nil];
    
    NSLog(@"📊 MultiChartWidget: Unregistered from auto-refresh notifications");
}

#pragma mark - ✅ FINVIZ SEARCH IMPLEMENTATION

- (void)performFinvizSearch:(NSString *)keyword {
    NSLog(@"🔍 MultiChartWidget: Performing Finviz search for '%@'", keyword);
    
    // Show loading state in text field
    self.symbolsTextField.stringValue = [NSString stringWithFormat:@"Searching '%@'...", keyword];
    self.symbolsTextField.enabled = NO;
    
    // Get OtherDataSource instance
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    OtherDataSource *otherDataSource = (OtherDataSource *)[downloadManager dataSourceForType:DataSourceTypeOther];
    
    if (!otherDataSource) {
        [self handleFinvizSearchError:@"Finviz search not available" keyword:keyword];
        return;
    }
    
    // Perform the search
    [otherDataSource fetchFinvizSearchResultsForKeyword:keyword
                                             completion:^(NSArray<NSString *> *symbols, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Restore text field
            self.symbolsTextField.enabled = YES;
            
            if (error) {
                [self handleFinvizSearchError:error.localizedDescription keyword:keyword];
                return;
            }
            
            if (symbols.count == 0) {
                [self handleFinvizSearchError:[NSString stringWithFormat:@"No symbols found for '%@'", keyword] keyword:keyword];
                return;
            }
            
            // Success - update with found symbols
            [self applyFinvizSearchResults:symbols keyword:keyword];
        });
    }];
}

- (void)handleFinvizSearchError:(NSString *)errorMessage keyword:(NSString *)keyword {
    NSLog(@"❌ MultiChartWidget Finviz search error: %@", errorMessage);
    
    // Restore original text field state
    self.symbolsTextField.stringValue = [NSString stringWithFormat:@"?%@", keyword];
    
    // Show error in a non-intrusive way
    NSString *errorText = [NSString stringWithFormat:@"❌ %@", errorMessage];
    self.symbolsTextField.stringValue = errorText;
    
    // Auto-clear error after 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.symbolsTextField.stringValue = @"";
    });
}

- (void)applyFinvizSearchResults:(NSArray<NSString *> *)symbols keyword:(NSString *)keyword {
    NSLog(@"✅ MultiChartWidget: Finviz found %lu symbols for '%@': %@",
          (unsigned long)symbols.count, keyword, [symbols componentsJoinedByString:@", "]);
    
    // Update symbols array and UI
    self.symbols = symbols;
    self.symbolsString = [symbols componentsJoinedByString:@", "];
    self.symbolsTextField.stringValue = self.symbolsString;
    
    // Rebuild charts with new symbols
    [self rebuildMiniCharts];
    [self loadDataFromDataHub];
    
    // Save settings
    [self saveSettingsToUserDefaults];
    
    // Show temporary success feedback
    NSString *successMessage = [NSString stringWithFormat:@"✅ Found %lu symbols for '%@'", (unsigned long)symbols.count, keyword];
    
    // Use temporary message if available, otherwise log
    if ([self respondsToSelector:@selector(showTemporaryMessage:)]) {
        [self performSelector:@selector(showTemporaryMessage:) withObject:successMessage];
    } else {
        NSLog(@"📊 %@", successMessage);
    }
    
    // Broadcast to chain if active
    if (self.chainActive) {
        [self broadcastSymbolToChain:symbols];
    }
}

#pragma mark - ✅ UTILITY METHODS

- (NSArray<NSString *> *)parseSymbolsFromInput:(NSString *)input {
    if (!input || input.length == 0) {
        return @[];
    }
    
    // Split by comma and clean up
    NSArray<NSString *> *components = [input componentsSeparatedByString:@","];
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    
    for (NSString *component in components) {
        NSString *cleanSymbol = [[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        if (cleanSymbol.length > 0) {
            [symbols addObject:cleanSymbol];
        }
    }
    
    return [symbols copy];
}

- (void)broadcastSymbolToChain:(NSArray<NSString *> *)symbols {
    // Send symbols to chain if active
    [self broadcastUpdate:@{
        @"action": @"setSymbols",
        @"symbols": symbols
    }];
    
    NSLog(@"🔗 MultiChartWidget: Finviz results sent to chain: %@", [symbols componentsJoinedByString:@", "]);
}

#pragma mark - Image Export

- (void)createMultiChartImageInteractive {
    // Check if there are charts to export
    if (self.miniCharts.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Charts to Export";
        alert.informativeText = @"Add symbols to the multi-chart before exporting.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Create image with completion
    [self createMultiChartImage:^(BOOL success, NSString *filePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && filePath) {
                // Show success alert
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Multi-Chart Image Saved";
                alert.informativeText = [NSString stringWithFormat:@"Image saved to:\n%@", filePath.lastPathComponent];
                [alert addButtonWithTitle:@"Show in Finder"];
                [alert addButtonWithTitle:@"OK"];
                
                NSModalResponse response = [alert runModal];
                if (response == NSAlertFirstButtonReturn) {
                    // Open Finder and select the file
                    [[NSWorkspace sharedWorkspace] selectFile:filePath
                                     inFileViewerRootedAtPath:filePath.stringByDeletingLastPathComponent];
                }
            } else {
                // Show error alert
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Export Failed";
                alert.informativeText = error.localizedDescription ?: @"Failed to create multi-chart image";
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        });
    }];
}

- (void)createMultiChartImage:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    @try {
        // Calculate grid layout
        NSInteger chartsCount = self.miniCharts.count;
        if (chartsCount == 0) {
            NSError *error = [NSError errorWithDomain:@"MultiChartImageExport" code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"No charts to export"}];
            if (completion) completion(NO, nil, error);
            return;
        }
        
        // Get item size from actual mini charts or widget properties
        CGSize itemSize;
        if (self.miniCharts.count > 0 && self.miniCharts.firstObject.bounds.size.width > 0) {
            // Use actual size from first chart
            itemSize = self.miniCharts.firstObject.bounds.size;
        } else {
            // Fallback to configured size
            itemSize = CGSizeMake(self.itemWidth, self.itemHeight);
        }

        // Calculate columns based on collection view width
        CGFloat collectionWidth = self.collectionView.bounds.size.width;
        NSInteger columns = MAX(1, (NSInteger)(collectionWidth / itemSize.width));
        NSInteger rows = (chartsCount + columns - 1) / columns;
        
        // Add padding between charts
        CGFloat padding = 10;
        CGFloat totalWidth = (itemSize.width * columns) + (padding * (columns - 1));
        CGFloat totalHeight = (itemSize.height * rows) + (padding * (rows - 1));
        
        // Create combined image
        NSSize imageSize = NSMakeSize(totalWidth, totalHeight);
        NSImage *combinedImage = [[NSImage alloc] initWithSize:imageSize];
        
        [combinedImage lockFocus];
        
        // Fill background
        [[NSColor controlBackgroundColor] setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, imageSize.width, imageSize.height)] fill];
        
        // Draw each mini chart
        for (NSInteger i = 0; i < chartsCount; i++) {
            MiniChart *miniChart = self.miniCharts[i];
            
            // Calculate position in grid
            NSInteger row = i / columns;
            NSInteger col = i % columns;
            
            CGFloat x = col * (itemSize.width + padding);
            CGFloat y = imageSize.height - ((row + 1) * itemSize.height) - (row * padding);
            
            // Create chart image
            NSImage *chartImage = [self renderMiniChartToImage:miniChart withSize:itemSize];
            if (chartImage) {
                // Draw chart image at position
                [chartImage drawInRect:NSMakeRect(x, y, itemSize.width, itemSize.height)
                              fromRect:NSZeroRect
                             operation:NSCompositingOperationSourceOver
                              fraction:1.0];
                
                // Add symbol label at top
                [self drawSymbolLabel:miniChart.symbol
                              inRect:NSMakeRect(x, y + itemSize.height - 25, itemSize.width, 25)];
            }
        }
        
        // Add timestamp and title at bottom
        [self drawFooterInRect:NSMakeRect(0, 0, imageSize.width, 30) chartsCount:chartsCount];
        
        [combinedImage unlockFocus];
        
        // Ensure directory exists
        NSError *dirError = nil;
        if (!EnsureChartImagesDirectoryExists(&dirError)) {
            if (completion) completion(NO, nil, dirError);
            return;
        }
        
        // Generate filename with timestamp
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyyMMdd_HHmmss";
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        NSString *filename = [NSString stringWithFormat:@"MultiChart_%@_%ld_symbols.png",
                              timestamp, (long)chartsCount];
        
        // Save image
        NSString *imagesDirectory = ChartImagesDirectory();
        NSString *filePath = [imagesDirectory stringByAppendingPathComponent:filename];
        
        NSData *imageData = [self convertImageToPNG:combinedImage];
        BOOL saveSuccess = [imageData writeToFile:filePath atomically:YES];
        
        if (saveSuccess) {
            NSLog(@"✅ Multi-chart image saved: %@", filePath);
            if (completion) completion(YES, filePath, nil);
        } else {
            NSError *saveError = [NSError errorWithDomain:@"MultiChartImageExport" code:1003
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to save image file"}];
            if (completion) completion(NO, nil, saveError);
        }
        
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"MultiChartImageExport" code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        if (completion) completion(NO, nil, error);
    }
}

#pragma mark - Rendering Helpers

- (NSImage *)renderMiniChartToImage:(MiniChart *)miniChart withSize:(NSSize)size {
    if (!miniChart || size.width == 0 || size.height == 0) {
        return nil;
    }
    
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];
    
    // Fill chart background
    [[NSColor windowBackgroundColor] setFill];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, size.width, size.height)] fill];
    
    // Force the mini chart to draw its content
    if (miniChart.priceData && miniChart.priceData.count > 0) {
        // Trigger a redraw to the current graphics context
        [miniChart setNeedsDisplay:YES];
        [miniChart displayIfNeeded];
        
        // Draw the mini chart's view hierarchy
        NSBitmapImageRep *bitmapRep = [miniChart bitmapImageRepForCachingDisplayInRect:miniChart.bounds];
        [miniChart cacheDisplayInRect:miniChart.bounds toBitmapImageRep:bitmapRep];
        
        // Draw the cached bitmap
        [bitmapRep drawInRect:NSMakeRect(0, 0, size.width, size.height)
                     fromRect:NSZeroRect
                    operation:NSCompositingOperationSourceOver
                     fraction:1.0
               respectFlipped:YES
                        hints:nil];
    }
    
    [image unlockFocus];
    
    return image;
}

- (void)renderLayer:(CALayer *)layer inContext:(NSGraphicsContext *)context {
    if (!layer || layer.hidden) return;
    
    CGContextRef ctx = context.CGContext;
    CGContextSaveGState(ctx);
    
    // Apply layer transform and position
    CGContextTranslateCTM(ctx, layer.position.x - layer.bounds.size.width * layer.anchorPoint.x,
                          layer.position.y - layer.bounds.size.height * layer.anchorPoint.y);
    
    // Draw layer contents
    if (layer.delegate && [layer.delegate respondsToSelector:@selector(drawLayer:inContext:)]) {
        [layer.delegate drawLayer:layer inContext:ctx];
    } else if (layer.backgroundColor) {
        CGContextSetFillColorWithColor(ctx, layer.backgroundColor);
        CGContextFillRect(ctx, layer.bounds);
    }
    
    // Render sublayers
    for (CALayer *sublayer in layer.sublayers) {
        [self renderLayer:sublayer inContext:context];
    }
    
    CGContextRestoreGState(ctx);
}

- (void)drawSymbolLabel:(NSString *)symbol inRect:(NSRect)rect {
    if (!symbol) return;
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor labelColor],
        NSParagraphStyleAttributeName: style
    };
    
   
    // Draw text
    NSRect textRect = NSInsetRect(rect, 5, 2);
    [symbol drawInRect:textRect withAttributes:attributes];
}

- (void)drawFooterInRect:(NSRect)rect chartsCount:(NSInteger)count {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    
    // Create timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // Create footer text
    NSString *footerText = [NSString stringWithFormat:@"Multi-Chart Export • %ld Symbols • %@ • %@",
                            (long)count, timestamp, self.timeframeString];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
        NSParagraphStyleAttributeName: style
    };
    
    // Draw footer
    NSRect textRect = NSInsetRect(rect, 10, 5);
    [footerText drawInRect:textRect withAttributes:attributes];
}

- (NSString *)timeframeString {
    switch (self.timeframe) {
        case MiniBarTimeframe1Min: return @"1 Min";
        case MiniBarTimeframe5Min: return @"5 Min";
        case MiniBarTimeframe15Min: return @"15 Min";
        case MiniBarTimeframe30Min: return @"30 Min";
        case MiniBarTimeframe1Hour: return @"1 Hour";
        case MiniBarTimeframeDaily: return @"Daily";
        case MiniBarTimeframeWeekly: return @"Weekly";
        case MiniBarTimeframeMonthly: return @"Monthly";
        default: return @"Unknown";
    }
}

- (NSData *)convertImageToPNG:(NSImage *)image {
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
    return [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

#pragma mark - Context Menu Setup

- (void)setupImageExportContextMenu {
    // Add right-click gesture recognizer to collection view
    NSClickGestureRecognizer *rightClickGesture = [[NSClickGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(handleRightClick:)];
    rightClickGesture.buttonMask = 0x2; // Right mouse button
    [self.collectionView addGestureRecognizer:rightClickGesture];
    
    NSLog(@"📸 MultiChartWidget: Image export context menu setup completed");
}

- (void)handleRightClick:(NSClickGestureRecognizer *)gesture {
    if (gesture.state == NSGestureRecognizerStateEnded) {
        NSPoint clickPoint = [gesture locationInView:self.collectionView];
        
        // Check if click is on a specific chart or empty area
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:clickPoint];
        
       
            [self showGeneralContextMenuAtPoint:clickPoint];
      
    }
}

- (void)showGeneralContextMenuAtPoint:(NSPoint)point {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Multi-Chart Actions"];
    
    // Create Image menu item
    NSMenuItem *createImageItem = [[NSMenuItem alloc] initWithTitle:@"📸 Create Multi-Chart Image"
                                                             action:@selector(contextMenuCreateImage:)
                                                      keyEquivalent:@""];
    createImageItem.target = self;
    createImageItem.enabled = (self.miniCharts.count > 0);
    [contextMenu addItem:createImageItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Refresh All
    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"🔄 Refresh All Charts"
                                                         action:@selector(refreshAllCharts)
                                                  keyEquivalent:@""];
    refreshItem.target = self;
    refreshItem.enabled = (self.miniCharts.count > 0);
    [contextMenu addItem:refreshItem];
    
    // Clear All
    NSMenuItem *clearItem = [[NSMenuItem alloc] initWithTitle:@"🗑 Clear All Charts"
                                                       action:@selector(removeAllSymbols)
                                                keyEquivalent:@""];
    clearItem.target = self;
    clearItem.enabled = (self.miniCharts.count > 0);
    [contextMenu addItem:clearItem];
    
    // Show menu
    [contextMenu popUpMenuPositioningItem:nil
                               atLocation:point
                                   inView:self.collectionView];
}

#pragma mark - Context Menu Actions

- (IBAction)contextMenuCreateImage:(id)sender {
    [self createMultiChartImageInteractive];
}



@end
