//
//  MultiChartWidget.m
//  TradingApp
//
//  Implementation of multi-symbol chart grid widget
//  FIXED: Properly follows BaseWidget architecture
//  ✅ UPDATED: Lazy loading with prefetch for historical data
//

#import "MultiChartWidget.h"
#import "MiniChart.h"
#import "DataHub+MarketData.h"
#import "RuntimeModels.h"
#import "MiniChartCollectionItem.h"
#import "OtherDataSource.h"
#import "DownloadManager.h"
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

// ✅ NUOVO: Lazy Loading Support
@property (nonatomic, strong) NSMutableSet<NSNumber *> *loadingIndices;      // Indici in caricamento
@property (nonatomic, strong) NSMutableSet<NSNumber *> *loadedIndices;       // Indici già caricati
@property (nonatomic, assign) NSInteger maxConcurrentLoads;                  // Max chiamate simultanee
@property (nonatomic, strong) NSMutableArray<NSNumber *> *loadQueue;         // Coda di caricamento

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
    
    // ✅ NUOVO: Inizializza lazy loading properties
    _loadingIndices = [NSMutableSet set];
    _loadedIndices = [NSMutableSet set];
    _loadQueue = [NSMutableArray array];
    _maxConcurrentLoads = 5; // Max 5 chiamate simultanee
    
    NSLog(@"✅ MultiChartWidget initialized with lazy loading (max concurrent: %ld)", (long)_maxConcurrentLoads);
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
       [self.symbolsTextField setAction:@selector(symbolsChanged:)];
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
    
    // Reference Lines checkbox (✅ NUOVO - dopo volumeCheckbox)
    self.referenceLinesCheckbox = [NSButton checkboxWithTitle:@"Studi"
                                                        target:self
                                                        action:@selector(referenceLinesCheckboxChanged:)];
    self.referenceLinesCheckbox.state = NSControlStateValueOn;  // Default: attivo
    self.referenceLinesCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.referenceLinesCheckbox];
    
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
        [self.referenceLinesCheckbox.leadingAnchor constraintEqualToAnchor:self.volumeCheckbox.trailingAnchor constant:12],
        [self.referenceLinesCheckbox.centerYAnchor constraintEqualToAnchor:self.volumeCheckbox.centerYAnchor]
    ]];
    [NSLayoutConstraint activateConstraints:@[
          [self.afterHoursSwitch.leadingAnchor constraintEqualToAnchor:self.referenceLinesCheckbox.trailingAnchor constant:spacing],
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
    
    NSLog(@"📊 MultiChartWidget: Loading data for %lu symbols using LAZY LOADING", (unsigned long)self.symbols.count);
    
    // Disable refresh button during loading
    self.refreshButton.enabled = NO;
    
    // ✅ STEP 1: Load BATCH quotes for ALL symbols (lightweight)
    [[DataHub shared] getQuotesForSymbols:self.symbols completion:^(NSDictionary<NSString *,MarketQuoteModel *> *quotes, BOOL allLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ Batch quotes received - %lu quotes", (unsigned long)quotes.count);
            
            // Update all charts with quote data
            for (MiniChart *chart in self.miniCharts) {
                MarketQuoteModel *quote = quotes[chart.symbol];
                if (quote) {
                    chart.currentPrice = quote.last;
                    chart.priceChange = quote.change;
                    chart.percentChange = quote.changePercent;
                }
            }
            
            // ✅ STEP 2: Historical data will be loaded LAZILY via NSCollectionViewDelegate
            // Reset lazy loading state
            [self.loadingIndices removeAllObjects];
            [self.loadedIndices removeAllObjects];
            [self.loadQueue removeAllObjects];
            
            self.refreshButton.enabled = YES;
            
            // ✅ NUOVO: Forza ricaricamento dei chart visibili
            [self reloadVisibleCharts];
            
            NSLog(@"✅ Lazy loading ready - historical data will load on-demand");
        });
    }];
}

- (void)reloadVisibleCharts {
    // Ottieni gli index path visibili nella collection view
    NSSet<NSIndexPath *> *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
    
    if (visibleIndexPaths.count == 0) {
        NSLog(@"⚠️ No visible charts to reload");
        return;
    }
    
    NSLog(@"🔄 Reloading %lu visible charts", (unsigned long)visibleIndexPaths.count);
    
    for (NSIndexPath *indexPath in visibleIndexPaths) {
        NSInteger index = indexPath.item;
        
        // Carica dati per questo chart
        [self loadHistoricalDataForChartAtIndex:index];
        
        // Prefetch anche i chart vicini
        [self prefetchChartsAroundIndex:index radius:5];
    }
}

#pragma mark - 🚀 Lazy Loading Implementation

- (void)loadHistoricalDataForChartAtIndex:(NSInteger)index {
    // Validazione
    if (index < 0 || index >= self.miniCharts.count) {
        return;
    }
    
    NSNumber *indexKey = @(index);
    
    // Skip se già caricato o in caricamento
    if ([self.loadedIndices containsObject:indexKey] ||
        [self.loadingIndices containsObject:indexKey]) {
        return;
    }
    
    // Check rate limiting
    if (self.loadingIndices.count >= self.maxConcurrentLoads) {
        // Aggiungi alla coda
        if (![self.loadQueue containsObject:indexKey]) {
            [self.loadQueue addObject:indexKey];
            NSLog(@"⏳ Chart %ld queued (loading: %lu)", (long)index, (unsigned long)self.loadingIndices.count);
        }
        return;
    }
    
    MiniChart *chart = self.miniCharts[index];
    NSString *symbol = chart.symbol;
    
    if (!symbol) {
        return;
    }
    
    NSLog(@"📥 Loading historical data for chart %ld: %@", (long)index, symbol);
    
    // Mark as loading
    [self.loadingIndices addObject:indexKey];
    [chart setLoading:YES];
    
    // Calculate date range
    NSDate *startDate = [self calculateStartDateForTimeRange];
    NSDate *endDate = [self calculateEndDateForTimeRange];
    
    // Start loading
    __weak typeof(self) weakSelf = self;
    [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                       timeframe:[self convertToBarTimeframe:self.timeframe]
                                       startDate:startDate
                                         endDate:endDate
                               needExtendedHours:self.afterHoursSwitch.state
                                      completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // Remove from loading
            [strongSelf.loadingIndices removeObject:indexKey];
            [chart setLoading:NO];
            
            if (bars && bars.count > 0) {
                // Update chart
                chart.timeframe = strongSelf.timeframe;
                [chart updateWithHistoricalBars:bars];
                
                // Mark as loaded
                [strongSelf.loadedIndices addObject:indexKey];
                
                NSLog(@"✅ Loaded %lu bars for chart %ld: %@ (fresh: %@)",
                      (unsigned long)bars.count, (long)index, symbol, isFresh ? @"YES" : @"NO");
            } else {
                [chart setError:@"No data"];
                NSLog(@"❌ No data for chart %ld: %@", (long)index, symbol);
            }
            
            // Process queue
            [strongSelf processLoadQueue];
        });
    }];
}

- (void)prefetchChartsAroundIndex:(NSInteger)index radius:(NSInteger)radius {
    NSInteger startIndex = MAX(0, index - radius);
    NSInteger endIndex = MIN(self.miniCharts.count - 1, index + radius);
    
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        [self loadHistoricalDataForChartAtIndex:i];
    }
}

- (void)processLoadQueue {
    while (self.loadQueue.count > 0 && self.loadingIndices.count < self.maxConcurrentLoads) {
        NSNumber *indexToLoad = self.loadQueue.firstObject;
        [self.loadQueue removeObjectAtIndex:0];
        
        NSInteger index = indexToLoad.integerValue;
        [self loadHistoricalDataForChartAtIndex:index];
    }
}

- (void)cancelLoadingForChartAtIndex:(NSInteger)index {
    NSNumber *indexKey = @(index);
    
    // Remove from loading set
    [self.loadingIndices removeObject:indexKey];
    
    // Remove from queue if present
    [self.loadQueue removeObject:indexKey];
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
            
            // ✅ CALCOLA DATE RANGE
            NSDate *startDate = [self calculateStartDateForTimeRange];
            NSDate *endDate = [self calculateEndDateForTimeRange];
            
            // ✅ USA IL NUOVO METODO CON DATE RANGE
            [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                               timeframe:[self convertToBarTimeframe:self.timeframe]
                                               startDate:startDate
                                                 endDate:endDate
                                       needExtendedHours:self.afterHoursSwitch.state
                                              completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [miniChart setLoading:NO];
                    
                    if (bars && bars.count > 0) {
                        miniChart.timeframe = self.timeframe;
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
        miniChart.showReferenceLines = self.referenceLinesCheckbox.state;
        
        // Setup appearance esistente
        [self setupChartSelectionAppearance:miniChart];
        
        [self.miniCharts addObject:miniChart];
    }
    
    // ✅ NUOVO: Reset lazy loading state when rebuilding
    [self.loadingIndices removeAllObjects];
    [self.loadedIndices removeAllObjects];
    [self.loadQueue removeAllObjects];
    
    // ✅ Update adaptive layout based on chart count
    [self updateAdaptiveLayout];

    // Aggiorna collection view
    [self.collectionView reloadData];

    NSLog(@"✅ MultiChartWidget: Rebuilt %lu mini charts (lazy loading reset)", (unsigned long)self.miniCharts.count);
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
        return;
    }

    if (!self.collectionScrollView) {
        return;
    }

    // Get available space in scroll view
    NSSize availableSize = self.collectionScrollView.documentVisibleRect.size;

    // Minimum sizes from controls
    CGFloat minWidth = self.itemWidth;
    CGFloat minHeight = self.itemHeight;

    // Calculate optimal grid layout based on chart count
    NSInteger columns, rows;

    if (chartCount == 1) {
        columns = 1;
        rows = 1;
    } else if (chartCount == 2) {
        columns = 2;
        rows = 1;
    } else if (chartCount <= 4) {
        columns = 2;
        rows = (chartCount <= 2) ? 1 : 2;
    } else if (chartCount <= 6) {
        columns = 3;
        rows = 2;
    } else if (chartCount <= 9) {
        columns = 3;
        rows = 3;
    } else if (chartCount <= 12) {
        columns = 4;
        rows = 3;
    } else {
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

    // Apply minimum constraints
    CGFloat maxWidth = MAX(minWidth, calculatedWidth);
    CGFloat maxHeight = MAX(minHeight, calculatedHeight);

    // Cap maximum size
    maxWidth = MIN(maxWidth, 800);
    maxHeight = MIN(maxHeight, 600);

    // Update grid layout
    if ([self.collectionView.collectionViewLayout isKindOfClass:[NSCollectionViewGridLayout class]]) {
        NSCollectionViewGridLayout *gridLayout = (NSCollectionViewGridLayout *)self.collectionView.collectionViewLayout;

        gridLayout.minimumItemSize = NSMakeSize(minWidth, minHeight);
        gridLayout.maximumItemSize = NSMakeSize(maxWidth, maxHeight);
        gridLayout.maximumNumberOfColumns = columns;

        [gridLayout invalidateLayout];
    }
}

#pragma mark - 🎯 NSCollectionView Delegate (Lazy Loading)

- (void)collectionView:(NSCollectionView *)collectionView
       willDisplayItem:(NSCollectionViewItem *)item
forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger index = indexPath.item;
    
    NSLog(@"👁️ Will display chart at index: %ld", (long)index);
    
    // ✅ STEP 1: Load data for this chart
    [self loadHistoricalDataForChartAtIndex:index];
    
    // ✅ STEP 2: Prefetch surrounding charts
    [self prefetchChartsAroundIndex:index radius:5];
}

- (void)collectionView:(NSCollectionView *)collectionView
  didEndDisplayingItem:(NSCollectionViewItem *)item
forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger index = indexPath.item;
    NSLog(@"👋 Did end displaying chart at index: %ld", (long)index);
}

#pragma mark - NSCollectionView DataSource & Delegate

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger count = self.miniCharts.count;
    return count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
                     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    
    MiniChartCollectionItem *item = [collectionView makeItemWithIdentifier:@"MiniChartItem"
                                                              forIndexPath:indexPath];
    
    if (!item) {
        item = [[MiniChartCollectionItem alloc] init];
    }
    
    if (indexPath.item >= self.miniCharts.count) {
        return item;
    }
    
    MiniChart *miniChart = self.miniCharts[indexPath.item];
    if (!miniChart) {
        return item;
    }
    
    // Configura l'item con il MiniChart esistente
    [item configureMiniChart:miniChart];
    
    // ✅ AGGIUNTO: Setup callbacks
    __weak typeof(self) weakSelf = self;
    
    item.onChartClicked = ^(MiniChart *chart) {
        [weakSelf handleChartSelection:chart];
    };
    
    item.onSetupContextMenu = ^(MiniChart *chart) {
        [weakSelf setupChartContextMenu:chart];
    };
    
    return item;
}

- (void)handleChartSelection:(MiniChart *)selectedChart {
    [self updateChartSelection:selectedChart];
    
    if (self.chainActive && selectedChart.symbol) {
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[selectedChart.symbol]
        }];
        
        [self showTemporaryMessageForCollectionView:
         [NSString stringWithFormat:@"📈 %@ sent to chain", selectedChart.symbol]];
    } else if (!self.chainActive) {
        [self showTemporaryMessageForCollectionView:
         [NSString stringWithFormat:@"📊 %@ selected", selectedChart.symbol]];
    }
}

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
    
    [self.contentView addSubview:messageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [messageLabel.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:20],
        [messageLabel.heightAnchor constraintEqualToConstant:30],
        [messageLabel.widthAnchor constraintGreaterThanOrEqualToConstant:100]
    ]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [messageLabel removeFromSuperview];
    });
}

- (void)setupChartSelectionAppearance:(MiniChart *)chart {
    chart.wantsLayer = YES;
    chart.layer.borderWidth = 0.0;
    chart.layer.borderColor = [NSColor controlAccentColor].CGColor;
    chart.layer.cornerRadius = 4.0;
}

- (void)setupChartContextMenu:(MiniChart *)chart {
    NSMenu *contextMenu = [[NSMenu alloc] init];
    
    NSMenuItem *sendToChainItem = [[NSMenuItem alloc] init];
    sendToChainItem.title = [NSString stringWithFormat:@"Send '%@' to Chain", chart.symbol];
    sendToChainItem.action = @selector(sendChartSymbolToChain:);
    sendToChainItem.target = self;
    sendToChainItem.representedObject = chart.symbol;
    [contextMenu addItem:sendToChainItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *sendToChainColorsItem = [[NSMenuItem alloc] init];
    sendToChainColorsItem.title = [NSString stringWithFormat:@"Send '%@' to Chain Color", chart.symbol];
    sendToChainColorsItem.submenu = [self createChainColorSubmenuForSymbol:chart.symbol];
    [contextMenu addItem:sendToChainColorsItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
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
        [self setChainActive:YES withColor:chainColor];
        
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
        
        self.symbolsString = [self.symbols componentsJoinedByString:@", "];
        self.symbolsTextField.stringValue = self.symbolsString;
        
        [self rebuildMiniCharts];
        
        [self showTemporaryMessageForCollectionView:[NSString stringWithFormat:@"Removed %@", symbol]];
    }
}

#pragma mark - Actions

- (void)symbolsChanged:(id)sender {
    NSString *input = self.symbolsTextField.stringValue;
    
    if ([input hasPrefix:@"?"]) {
        NSString *keyword = [input substringFromIndex:1];
        keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (keyword.length > 0) {
            [self performFinvizSearch:keyword];
            return;
        } else {
            return;
        }
    }
    
    NSArray<NSString *> *newSymbols = [self parseSymbolsFromInput:input];
    
    if ([newSymbols isEqualToArray:self.symbols]) {
        return;
    }
    
    self.symbols = newSymbols;
    self.symbolsString = [newSymbols componentsJoinedByString:@", "];
    
    [self rebuildMiniCharts];
    [self loadDataFromDataHub];
    
    [self saveSettingsToUserDefaults];
}

- (void)chartTypeChanged:(id)sender {
    self.chartType = (MiniChartType)self.chartTypePopup.indexOfSelectedItem;
    
    for (MiniChart *chart in self.miniCharts) {
        chart.chartType = self.chartType;
        [chart setNeedsDisplay:YES];
    }
}

- (void)timeframeChanged:(id)sender {
    NSInteger segmentIndex = self.timeframeSegmented.selectedSegment;
    self.timeframe = (MiniBarTimeframe)segmentIndex;
    
    switch (self.timeframe) {
        case MiniBarTimeframe1Min:
            self.timeRange = 0;
            self.timeRangeSegmented.selectedSegment = 0;
            break;
            
        case MiniBarTimeframe5Min:
        case MiniBarTimeframe15Min:
            self.timeRange = 1;
            self.timeRangeSegmented.selectedSegment = 1;
            break;
            
        case MiniBarTimeframe30Min:
        case MiniBarTimeframe1Hour:
        case MiniBarTimeframe12Hour:
            self.timeRange = 3;
            self.timeRangeSegmented.selectedSegment = 3;
            break;
            
        case MiniBarTimeframeDaily:
            self.timeRange = 3;
            self.timeRangeSegmented.selectedSegment = 3;
            break;
            
        case MiniBarTimeframeWeekly:
        case MiniBarTimeframeMonthly:
            self.timeRange = 6;
            self.timeRangeSegmented.selectedSegment = 6;
            break;
            
        default:
            break;
    }
    
    // Update timeframe per tutti i minichart
    for (MiniChart *chart in self.miniCharts) {
        chart.timeframe = self.timeframe;
    }
    
    [self loadDataFromDataHub];
}

- (void)afterHoursSwitchChanged:(id)sender {
    [self loadDataFromDataHub];
}

- (void)scaleTypeChanged:(id)sender {
    self.scaleType = (MiniChartScaleType)self.scaleTypePopup.indexOfSelectedItem;
    
    for (MiniChart *chart in self.miniCharts) {
        chart.scaleType = self.scaleType;
        [chart setNeedsDisplay:YES];
    }
}

- (void)volumeCheckboxChanged:(id)sender {
    self.showVolume = (self.volumeCheckbox.state == NSControlStateValueOn);
    
    for (MiniChart *chart in self.miniCharts) {
        chart.showVolume = self.showVolume;
        [chart setNeedsDisplay:YES];
    }
}

- (void)refreshButtonClicked:(id)sender {
    self.refreshButton.enabled = NO;
    [self refreshAllCharts];
    
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
        [[DataHub shared] getQuotesForSymbols:@[symbol] completion:^(NSDictionary<NSString *,MarketQuoteModel *> *quotes, BOOL allLive) {
            dispatch_async(dispatch_get_main_queue(), ^{
                MarketQuoteModel *quote = quotes[symbol];
                if (quote) {
                    chart.currentPrice = quote.last;
                    chart.priceChange = quote.change;
                    chart.percentChange = quote.changePercent;
                }
                
                NSDate *startDate = [self calculateStartDateForTimeRange];
                NSDate *endDate = [self calculateEndDateForTimeRange];
                
                [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                                   timeframe:[self convertToBarTimeframe:self.timeframe]
                                                   startDate:startDate
                                                     endDate:endDate
                                           needExtendedHours:self.afterHoursSwitch.state
                                                  completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (bars && bars.count > 0) {
                            chart.timeframe = self.timeframe;
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
        [self loadScreenerDataFromChainData:data fromWidget:sender];
    } else {
        [super handleChainAction:action withData:data fromWidget:sender];
    }
}

- (void)loadScreenerDataFromChainData:(NSDictionary *)data fromWidget:(BaseWidget *)sender {
    if (!data || ![data isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSString *symbol = data[@"symbol"];
    NSArray<HistoricalBarModel *> *historicalBars = data[@"historicalBars"];
    NSNumber *timeframeNum = data[@"timeframe"];
    NSString *source = data[@"source"] ?: @"Unknown";
    
    if (!symbol || !historicalBars || historicalBars.count == 0) {
        [self showTemporaryMessageForCollectionView:@"❌ Missing screener data"];
        return;
    }
    
    BarTimeframe timeframe = timeframeNum ? [timeframeNum integerValue] : BarTimeframeDaily;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentText = self.symbolsTextField.stringValue;
        
        if (!currentText || currentText.length == 0) {
            self.symbolsTextField.stringValue = symbol;
        } else {
            NSArray *existingSymbols = [currentText componentsSeparatedByString:@","];
            NSMutableArray *trimmedSymbols = [NSMutableArray array];
            
            for (NSString *existing in existingSymbols) {
                NSString *trimmed = [existing stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (trimmed.length > 0) {
                    [trimmedSymbols addObject:trimmed];
                }
            }
            
            if (![trimmedSymbols containsObject:symbol]) {
                [trimmedSymbols addObject:symbol];
                self.symbolsTextField.stringValue = [trimmedSymbols componentsJoinedByString:@", "];
            }
        }
    });
    
    MiniChart *miniChart = [[MiniChart alloc] initWithFrame:CGRectMake(0, 0, self.itemWidth, self.itemHeight)];
    miniChart.symbol = symbol;
    
    if (miniChart.descriptionLabel) {
        miniChart.descriptionLabel.stringValue = source;
        miniChart.descriptionLabel.hidden = NO;
    }
    
    miniChart.chartType = self.chartType;
    miniChart.timeframe = [self convertFromBarTimeframe:timeframe];
    miniChart.scaleType = self.scaleType;
    miniChart.showVolume = self.showVolume;
    
    [miniChart updateWithHistoricalBars:historicalBars];
    [self.miniCharts addObject:miniChart];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
        
        NSInteger lastIndex = self.miniCharts.count - 1;
        NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:lastIndex inSection:0];
        [self.collectionView scrollToItemsAtIndexPaths:@[lastIndexPath]
                                        scrollPosition:NSCollectionViewScrollPositionBottom];
        
        NSString *feedbackMessage = [NSString stringWithFormat:@"📊 Added %@ from %@", symbol, source];
        [self showTemporaryMessageForCollectionView:feedbackMessage];
    });
}

- (void)loadChartPatternFromChainData:(NSDictionary *)data fromWidget:(BaseWidget *)sender {
    if (!data || ![data isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSString *patternID = data[@"patternID"];
    NSString *symbol = data[@"symbol"];
    NSString *savedDataReference = data[@"savedDataReference"];
    NSDate *patternStartDate = data[@"patternStartDate"];
    NSDate *patternEndDate = data[@"patternEndDate"];
    NSString *patternType = data[@"patternType"];
    
    if (!patternID || !savedDataReference || !symbol) {
        return;
    }
    
    NSString *directory = [CommonTypes savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedDataReference];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    if (!savedData || !savedData.isDataValid) {
        [self showTemporaryMessageForCollectionView:@"❌ Failed to load pattern data"];
        return;
    }
    
    MiniChart *miniChart = [[MiniChart alloc] initWithFrame:CGRectMake(0, 0, self.itemWidth, self.itemHeight)];
    
    NSString *displayName;
    if (patternType && patternType.length > 0) {
        displayName = [NSString stringWithFormat:@"%@ %@", patternType, symbol];
    } else {
        displayName = [NSString stringWithFormat:@"Saved %@", symbol];
    }
    
    miniChart.symbol = displayName;
    miniChart.chartType = self.chartType;
    miniChart.timeframe = [self convertFromBarTimeframe:savedData.timeframe];
    miniChart.scaleType = self.scaleType;
    miniChart.showVolume = self.showVolume;
    
    NSArray<HistoricalBarModel *> *barsToShow = savedData.historicalBars;
    
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
            NSInteger padding = MAX(1, (endIndex - startIndex + 1) / 10);
            NSInteger paddedStart = MAX(0, startIndex - padding);
            NSInteger paddedEnd = MIN(barsToShow.count - 1, endIndex + padding);
            
            NSRange range = NSMakeRange(paddedStart, paddedEnd - paddedStart + 1);
            barsToShow = [barsToShow subarrayWithRange:range];
        }
    }
    
    [miniChart updateWithHistoricalBars:barsToShow];
    [self.miniCharts addObject:miniChart];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
        
        NSInteger lastIndex = self.miniCharts.count - 1;
        NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:lastIndex inSection:0];
        [self.collectionView scrollToItemsAtIndexPaths:@[lastIndexPath]
                                        scrollPosition:NSCollectionViewScrollPositionBottom];
        
        NSString *feedbackMessage = [NSString stringWithFormat:@"📊 Added %@", displayName];
        [self showTemporaryMessageForCollectionView:feedbackMessage];
    });
}

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
    if ([symbols isEqualToArray:self.symbols]) {
        return;
    }
    [self.miniCharts removeAllObjects];
    
    self.symbols = symbols;
    
    self.symbolsString = [symbols componentsJoinedByString:@", "];
    if (self.symbolsTextField) {
        self.symbolsTextField.stringValue = self.symbolsString;
    }
    
    [self rebuildMiniCharts];
    [self loadDataFromDataHub];
    
    NSString *senderType = NSStringFromClass([sender class]);
    NSString *message = symbols.count == 1 ?
        [NSString stringWithFormat:@"📊 Added %@ from %@", symbols[0], senderType] :
        [NSString stringWithFormat:@"📊 Added %lu symbols from %@", (unsigned long)symbols.count, senderType];
    
    [self showChainFeedback:message];
}

#pragma mark - Settings Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];

    state[@"chartType"] = @(self.chartType);
    state[@"timeframe"] = @(self.timeframe);
    state[@"scaleType"] = @(self.scaleType);
    state[@"showVolume"] = @(self.showVolume);
    state[@"timeRange"] = @(self.timeRange);
    state[@"itemWidth"] = @(self.itemWidth);
    state[@"itemHeight"] = @(self.itemHeight);
    state[@"autoRefreshEnabled"] = @(self.autoRefreshEnabled);

    if (self.symbolsString) {
        state[@"symbolsString"] = self.symbolsString;
    }

    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
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

    if (state[@"symbolsString"]) {
        self.symbolsString = state[@"symbolsString"];
        if (self.symbolsTextField) {
            self.symbolsTextField.stringValue = self.symbolsString;
        }
    }

    [self updateUIFromSettings];
    [self rebuildMiniCharts];
}

static NSString *const kMultiChartChartTypeKey = @"MultiChart_ChartType";
static NSString *const kMultiBarTimeframeKey = @"MultiChart_Timeframe";
static NSString *const kMultiChartScaleTypeKey = @"MultiChart_ScaleType";
static NSString *const kMultiChartMaxBarsKey = @"MultiChart_MaxBars";
static NSString *const kMultiChartShowVolumeKey = @"MultiChart_ShowVolume";
static NSString *const kMultiChartColumnsCountKey = @"MultiChart_ColumnsCount";
static NSString *const kMultiChartSymbolsKey = @"MultiChart_Symbols";

- (void)loadSettingsFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSInteger savedChartType = [defaults integerForKey:kMultiChartChartTypeKey];
    NSInteger savedTimeframe = [defaults integerForKey:kMultiBarTimeframeKey];
    NSInteger savedScaleType = [defaults integerForKey:kMultiChartScaleTypeKey];
    BOOL savedShowVolume = [defaults boolForKey:kMultiChartShowVolumeKey];

    NSInteger savedItemWidth = [defaults integerForKey:kMultiChartItemWidthKey];
    NSInteger savedItemHeight = [defaults integerForKey:kMultiChartItemHeightKey];
    
    if (savedChartType >= MiniChartTypeLine && savedChartType <= MiniChartTypeCandle) {
        self.chartType = (MiniChartType)savedChartType;
    } else {
        self.chartType = MiniChartTypeLine;
    }
    
    if (savedTimeframe) {
        self.timeframe = (MiniBarTimeframe)savedTimeframe;
    } else {
        self.timeframe = MiniBarTimeframeDaily;
    }
    
    if (savedScaleType >= MiniChartScaleLinear && savedScaleType <= MiniChartScaleLog) {
        self.scaleType = (MiniChartScaleType)savedScaleType;
    } else {
        self.scaleType = MiniChartScaleLinear;
    }
    
    self.afterHoursSwitch.state = [defaults boolForKey:kMultiChartIncludeAfterHoursKey];

    if ([defaults objectForKey:kMultiChartAutoRefreshEnabledKey] == nil) {
        self.autoRefreshEnabled = NO;
    } else {
        self.autoRefreshEnabled = [defaults boolForKey:kMultiChartAutoRefreshEnabledKey];
    }
    
    if ([defaults objectForKey:kMultiChartShowVolumeKey] != nil) {
        self.showVolume = savedShowVolume;
    } else {
        self.showVolume = YES;
    }
    
    if (savedItemWidth >= 100) {
        self.itemWidth = savedItemWidth;
    } else {
        self.itemWidth = 200;
    }
    
    if (savedItemHeight >= 80) {
        self.itemHeight = savedItemHeight;
    } else {
        self.itemHeight = 150;
    }

    self.symbolsString = @"";
    self.symbols = @[];
}

- (void)saveSettingsToUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setInteger:self.chartType forKey:kMultiChartChartTypeKey];
    [defaults setInteger:self.timeframe forKey:kMultiBarTimeframeKey];
    [defaults setInteger:self.scaleType forKey:kMultiChartScaleTypeKey];
    [defaults setBool:self.showVolume forKey:kMultiChartShowVolumeKey];
    [defaults setInteger:self.itemWidth forKey:kMultiChartItemWidthKey];
    [defaults setInteger:self.itemHeight forKey:kMultiChartItemHeightKey];
    [defaults setBool:self.autoRefreshEnabled forKey:kMultiChartAutoRefreshEnabledKey];
    [defaults setBool:self.afterHoursSwitch.state forKey:kMultiChartIncludeAfterHoursKey];

    [defaults synchronize];
}

- (void)updateUIFromSettings {
    if (self.chartTypePopup && self.chartType < self.chartTypePopup.numberOfItems) {
        [self.chartTypePopup selectItemAtIndex:self.chartType];
    }

    if (self.timeframeSegmented && self.timeframe < self.timeframeSegmented.segmentCount) {
        self.timeframeSegmented.selectedSegment = self.timeframe;
    }

    if (self.scaleTypePopup && self.scaleType < self.scaleTypePopup.numberOfItems) {
        [self.scaleTypePopup selectItemAtIndex:self.scaleType];
    }

    if (self.volumeCheckbox) {
        self.volumeCheckbox.state = self.showVolume ? NSControlStateValueOn : NSControlStateValueOff;
    }

    if (self.timeRangeSegmented && self.timeRange < self.timeRangeSegmented.segmentCount) {
        self.timeRangeSegmented.selectedSegment = self.timeRange;
    }

    if (self.autoRefreshToggle) {
        self.autoRefreshToggle.state = self.autoRefreshEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    }

    if (self.itemWidthField) {
        self.itemWidthField.integerValue = self.itemWidth;
    }
    if (self.itemHeightField) {
        self.itemHeightField.integerValue = self.itemHeight;
    }

    if (self.symbolsTextField && self.symbolsString) {
        self.symbolsTextField.stringValue = self.symbolsString;
    }
}

- (void)chartTypeChangedWithAutoSave:(id)sender {
    [self chartTypeChanged:sender];
    [self saveSettingsToUserDefaults];
}

- (void)scaleTypeChangedWithAutoSave:(id)sender {
    [self scaleTypeChanged:sender];
    [self saveSettingsToUserDefaults];
}

- (void)volumeCheckboxChangedWithAutoSave:(id)sender {
    [self volumeCheckboxChanged:sender];
    [self saveSettingsToUserDefaults];
}

- (void)symbolsChangedWithAutoSave:(id)sender {
    [self symbolsChanged:sender];
    [self saveSettingsToUserDefaults];
}

- (void)initializeSettingsSystem {
    [self loadSettingsFromUserDefaults];
    [self updateUIFromSettings];
    [self setupAutoSaveActionMethods];
}

- (void)setupAutoSaveActionMethods {
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
        self.symbolsTextField.action = @selector(symbolsChanged:);
    }
}

- (void)saveSettingsOnExit {
    [self saveSettingsToUserDefaults];
}

- (void)resetSymbolsClicked:(id)sender {
    [self.miniCharts removeAllObjects];
    self.symbolsTextField.stringValue = @"";
    [self.collectionView reloadData];
}

- (void)resetSymbolsField {
    self.symbolsTextField.stringValue = @"";
}

- (void)updateChartSelection:(MiniChart *)selectedChart {
    for (MiniChart *chart in self.miniCharts) {
        if (chart.layer) {
            chart.layer.borderWidth = 0.0;
        }
    }
    
    if (selectedChart.layer) {
        selectedChart.layer.borderWidth = 2.0;
        selectedChart.layer.borderColor = [NSColor controlAccentColor].CGColor;
    }
    
    if (self.chainActive && selectedChart.symbol) {
        self.currentSymbol = selectedChart.symbol;
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[selectedChart.symbol]
        }];
    }
    
    NSInteger index = [self.miniCharts indexOfObject:selectedChart];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        [self.collectionView scrollToItemsAtIndexPaths:@[indexPath]
                                        scrollPosition:NSCollectionViewScrollPositionCenteredVertically];
    }
    
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

- (void)autoRefreshToggleChanged:(id)sender {
    self.autoRefreshEnabled = (self.autoRefreshToggle.state == NSControlStateValueOn);
    
    [self saveSettingsToUserDefaults];
    
    if (self.autoRefreshEnabled) {
        [self registerForNotifications];
    } else {
        [self unregisterFromNotifications];
    }
}

- (void)unregisterFromNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc removeObserver:self name:@"DataHubQuoteUpdatedNotification" object:nil];
    [nc removeObserver:self name:@"DataHubHistoricalDataUpdatedNotification" object:nil];
}

#pragma mark - Finviz Search

- (void)performFinvizSearch:(NSString *)keyword {
    self.symbolsTextField.stringValue = [NSString stringWithFormat:@"Searching '%@'...", keyword];
    self.symbolsTextField.enabled = NO;
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    OtherDataSource *otherDataSource = (OtherDataSource *)[downloadManager dataSourceForType:DataSourceTypeOther];
    
    if (!otherDataSource) {
        [self handleFinvizSearchError:@"Finviz search not available" keyword:keyword];
        return;
    }
    
    [otherDataSource fetchFinvizSearchResultsForKeyword:keyword
                                             completion:^(NSArray<NSString *> *symbols, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.symbolsTextField.enabled = YES;
            
            if (error) {
                [self handleFinvizSearchError:error.localizedDescription keyword:keyword];
                return;
            }
            
            if (symbols.count == 0) {
                [self handleFinvizSearchError:[NSString stringWithFormat:@"No symbols found for '%@'", keyword] keyword:keyword];
                return;
            }
            
            [self applyFinvizSearchResults:symbols keyword:keyword];
        });
    }];
}

- (void)handleFinvizSearchError:(NSString *)errorMessage keyword:(NSString *)keyword {
    self.symbolsTextField.stringValue = [NSString stringWithFormat:@"?%@", keyword];
    
    NSString *errorText = [NSString stringWithFormat:@"❌ %@", errorMessage];
    self.symbolsTextField.stringValue = errorText;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.symbolsTextField.stringValue = @"";
    });
}

- (void)applyFinvizSearchResults:(NSArray<NSString *> *)symbols keyword:(NSString *)keyword {
    self.symbols = symbols;
    self.symbolsString = [symbols componentsJoinedByString:@", "];
    self.symbolsTextField.stringValue = self.symbolsString;
    
    [self rebuildMiniCharts];
    [self loadDataFromDataHub];
    
    [self saveSettingsToUserDefaults];
    
    if (self.chainActive) {
        [self broadcastSymbolToChain:symbols];
    }
}

- (NSArray<NSString *> *)parseSymbolsFromInput:(NSString *)input {
    if (!input || input.length == 0) {
        return @[];
    }
    
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
    [self broadcastUpdate:@{
        @"action": @"setSymbols",
        @"symbols": symbols
    }];
}

#pragma mark - Image Export

- (void)createMultiChartImageInteractive {
    if (self.miniCharts.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Charts to Export";
        alert.informativeText = @"Add symbols to the multi-chart before exporting.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    [self createMultiChartImage:^(BOOL success, NSString *filePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && filePath) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Multi-Chart Image Saved";
                alert.informativeText = [NSString stringWithFormat:@"Image saved to:\n%@", filePath.lastPathComponent];
                [alert addButtonWithTitle:@"Show in Finder"];
                [alert addButtonWithTitle:@"OK"];
                
                NSModalResponse response = [alert runModal];
                if (response == NSAlertFirstButtonReturn) {
                    [[NSWorkspace sharedWorkspace] selectFile:filePath
                                     inFileViewerRootedAtPath:filePath.stringByDeletingLastPathComponent];
                }
            } else {
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
        NSInteger chartsCount = self.miniCharts.count;
        if (chartsCount == 0) {
            NSError *error = [NSError errorWithDomain:@"MultiChartImageExport" code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"No charts to export"}];
            if (completion) completion(NO, nil, error);
            return;
        }
        
        CGSize itemSize;
        if (self.miniCharts.count > 0 && self.miniCharts.firstObject.bounds.size.width > 0) {
            itemSize = self.miniCharts.firstObject.bounds.size;
        } else {
            itemSize = CGSizeMake(self.itemWidth, self.itemHeight);
        }

        CGFloat collectionWidth = self.collectionView.bounds.size.width;
        NSInteger columns = MAX(1, (NSInteger)(collectionWidth / itemSize.width));
        NSInteger rows = (chartsCount + columns - 1) / columns;
        
        CGFloat padding = 10;
        CGFloat totalWidth = (itemSize.width * columns) + (padding * (columns - 1));
        CGFloat totalHeight = (itemSize.height * rows) + (padding * (rows - 1));
        
        NSSize imageSize = NSMakeSize(totalWidth, totalHeight);
        NSImage *combinedImage = [[NSImage alloc] initWithSize:imageSize];
        
        [combinedImage lockFocus];
        
        [[NSColor controlBackgroundColor] setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, imageSize.width, imageSize.height)] fill];
        
        for (NSInteger i = 0; i < chartsCount; i++) {
            MiniChart *miniChart = self.miniCharts[i];
            
            NSInteger row = i / columns;
            NSInteger col = i % columns;
            
            CGFloat x = col * (itemSize.width + padding);
            CGFloat y = imageSize.height - ((row + 1) * itemSize.height) - (row * padding);
            
            NSImage *chartImage = [self renderMiniChartToImage:miniChart withSize:itemSize];
            if (chartImage) {
                [chartImage drawInRect:NSMakeRect(x, y, itemSize.width, itemSize.height)
                              fromRect:NSZeroRect
                             operation:NSCompositingOperationSourceOver
                              fraction:1.0];
                
                [self drawSymbolLabel:miniChart.symbol
                              inRect:NSMakeRect(x, y + itemSize.height - 25, itemSize.width, 25)];
            }
        }
        
        [self drawFooterInRect:NSMakeRect(0, 0, imageSize.width, 30) chartsCount:chartsCount];
        
        [combinedImage unlockFocus];
        
        NSError *dirError = nil;
        if (!EnsureChartImagesDirectoryExists(&dirError)) {
            if (completion) completion(NO, nil, dirError);
            return;
        }
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyyMMdd_HHmmss";
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        NSString *filename = [NSString stringWithFormat:@"MultiChart_%@_%ld_symbols.png",
                              timestamp, (long)chartsCount];
        
        NSString *imagesDirectory = ChartImagesDirectory();
        NSString *filePath = [imagesDirectory stringByAppendingPathComponent:filename];
        
        NSData *imageData = [self convertImageToPNG:combinedImage];
        BOOL saveSuccess = [imageData writeToFile:filePath atomically:YES];
        
        if (saveSuccess) {
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

- (NSImage *)renderMiniChartToImage:(MiniChart *)miniChart withSize:(NSSize)size {
    if (!miniChart || size.width == 0 || size.height == 0) {
        return nil;
    }
    
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];
    
    [[NSColor windowBackgroundColor] setFill];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, size.width, size.height)] fill];
    
    if (miniChart.priceData && miniChart.priceData.count > 0) {
        [miniChart setNeedsDisplay:YES];
        [miniChart displayIfNeeded];
        
        NSBitmapImageRep *bitmapRep = [miniChart bitmapImageRepForCachingDisplayInRect:miniChart.bounds];
        [miniChart cacheDisplayInRect:miniChart.bounds toBitmapImageRep:bitmapRep];
        
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
    
    CGContextTranslateCTM(ctx, layer.position.x - layer.bounds.size.width * layer.anchorPoint.x,
                          layer.position.y - layer.bounds.size.height * layer.anchorPoint.y);
    
    if (layer.delegate && [layer.delegate respondsToSelector:@selector(drawLayer:inContext:)]) {
        [layer.delegate drawLayer:layer inContext:ctx];
    } else if (layer.backgroundColor) {
        CGContextSetFillColorWithColor(ctx, layer.backgroundColor);
        CGContextFillRect(ctx, layer.bounds);
    }
    
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
    
    NSRect textRect = NSInsetRect(rect, 5, 2);
    [symbol drawInRect:textRect withAttributes:attributes];
}

- (void)drawFooterInRect:(NSRect)rect chartsCount:(NSInteger)count {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *footerText = [NSString stringWithFormat:@"Multi-Chart Export • %ld Symbols • %@ • %@",
                            (long)count, timestamp, self.timeframeString];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
        NSParagraphStyleAttributeName: style
    };
    
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

- (void)setupImageExportContextMenu {
    NSClickGestureRecognizer *rightClickGesture = [[NSClickGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(handleRightClick:)];
    rightClickGesture.buttonMask = 0x2;
    [self.collectionView addGestureRecognizer:rightClickGesture];
}

- (void)handleRightClick:(NSClickGestureRecognizer *)gesture {
    if (gesture.state == NSGestureRecognizerStateEnded) {
        NSPoint clickPoint = [gesture locationInView:self.collectionView];
        [self showGeneralContextMenuAtPoint:clickPoint];
    }
}

- (void)showGeneralContextMenuAtPoint:(NSPoint)point {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Multi-Chart Actions"];
    
    NSMenuItem *createImageItem = [[NSMenuItem alloc] initWithTitle:@"📸 Create Multi-Chart Image"
                                                             action:@selector(contextMenuCreateImage:)
                                                      keyEquivalent:@""];
    createImageItem.target = self;
    createImageItem.enabled = (self.miniCharts.count > 0);
    [contextMenu addItem:createImageItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"🔄 Refresh All Charts"
                                                         action:@selector(refreshAllCharts)
                                                  keyEquivalent:@""];
    refreshItem.target = self;
    refreshItem.enabled = (self.miniCharts.count > 0);
    [contextMenu addItem:refreshItem];
    
    NSMenuItem *clearItem = [[NSMenuItem alloc] initWithTitle:@"🗑 Clear All Charts"
                                                       action:@selector(removeAllSymbols)
                                                keyEquivalent:@""];
    clearItem.target = self;
    clearItem.enabled = (self.miniCharts.count > 0);
    [contextMenu addItem:clearItem];
    
    [contextMenu popUpMenuPositioningItem:nil
                               atLocation:point
                                   inView:self.collectionView];
}

- (IBAction)contextMenuCreateImage:(id)sender {
    [self createMultiChartImageInteractive];
}

- (void)referenceLinesCheckboxChanged:(id)sender {
    bool showReferenceLines = (self.referenceLinesCheckbox.state == NSControlStateValueOn);
    
    for (MiniChart *chart in self.miniCharts) {
        chart.showReferenceLines = showReferenceLines;
        [chart setNeedsDisplay:YES];
    }
}

#pragma mark - Date Range Calculation

- (NSDate *)calculateStartDateForTimeRange {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    
    NSArray *calendarDays = @[@1, @3, @5, @30, @90, @180, @365, @1825];
    NSInteger totalDays = [calendarDays[self.timeRange] integerValue];
    
    NSInteger businessDaysToAdd = 0;
    NSInteger totalBusinessDaysNeeded = totalDays;
    NSDate *startDate = now;
    
    while (businessDaysToAdd < totalBusinessDaysNeeded) {
        startDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:startDate options:0];
        
        NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:startDate];
        
        if (weekday != 1 && weekday != 7) {
            businessDaysToAdd++;
        }
    }
    
    CGFloat rawBuffer = totalBusinessDaysNeeded * 0.05;
    NSInteger bufferDays = 0;
    if (rawBuffer >= 0.5) {
        bufferDays = MAX(1, (NSInteger)round(rawBuffer));
    }
    for (NSInteger i = 0; i < bufferDays; i++) {
        startDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:startDate options:0];
        NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:startDate];
        if (weekday == 1 || weekday == 7) {
            i--;
        }
    }
    
    return startDate;
}

- (NSDate *)calculateEndDateForTimeRange {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *tomorrow = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[NSDate date] options:0];
    
    return tomorrow;
}

@end
