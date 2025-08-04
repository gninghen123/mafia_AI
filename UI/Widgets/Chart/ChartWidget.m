//
//  ChartWidget.m
//  TradingApp
//
//  Main chart widget with multi-panel indicator support
//

#import "ChartWidget.h"
#import "ChartPanelModel.h"
#import "ChartPanelView.h"
#import "ChartCoordinator.h"
#import "DataHub+MarketData.h"
#import "IndicatorsPanelController.h"

// Renderers imports
#import "CandlestickRenderer.h"
#import "VolumeRenderer.h"


@interface ChartWidget ()
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL isLoading;
@end

// Private category to access BaseWidget's internal properties
@interface BaseWidget ()
@property (nonatomic, strong) NSView *contentViewInternal;
@end

@implementation ChartWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        [self setupDefaults];
        [self registerForNotifications];
    }
    return self;
}

- (void)setupDefaults {
    self.widgetType = @"Chart Widget";
    _currentSymbol = @"AAPL";
    _selectedTimeframe = 4; // Daily
    _maxBarsToDisplay = 99999999999999;
    _isLoading = NO;
    
    // Initialize collections
    _panelModels = [NSMutableArray array];
    _panelViews = [NSMutableArray array];
    
    // Create coordinator - IMPORTANTE: inizializzarlo prima di creare i panels
    _coordinator = [[ChartCoordinator alloc] init];
    _coordinator.maxVisibleBars = _maxBarsToDisplay;
    
    // Initialize indicators panel controller
    _indicatorsPanelController = [[IndicatorsPanelController alloc] initWithChartWidget:self];
    
    NSLog(@"📊 ChartWidget: Initialized with symbol %@", _currentSymbol);
}


#pragma mark - Properties

- (NSView *)contentView {
    return self.contentViewInternal;
}

#pragma mark - BaseWidget Override

- (void)setupContentView {
    [super setupContentView];
    
    NSLog(@"📊 ChartWidget: Setting up content view...");
    
    // Remove BaseWidget's placeholder
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Create UI components
    [self createToolbar];
    [self createChartArea];
    [self createZoomControls];
    
    [self setupConstraints];
    [self createMainPanel];
    
    // Initial data load
    [self loadHistoricalDataForSymbol:self.currentSymbol];
    
    NSLog(@"✅ ChartWidget: Content view setup complete");
}

#pragma mark - UI Creation

- (void)createToolbar {
    // Toolbar container
    self.toolbarView = [[NSView alloc] init];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toolbarView.wantsLayer = YES;
    self.toolbarView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    [self.contentView addSubview:self.toolbarView];
    
    // Symbol combo box
    self.symbolComboBox = [[NSComboBox alloc] init];
    self.symbolComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolComboBox.stringValue = self.currentSymbol;
    self.symbolComboBox.target = self;
    self.symbolComboBox.action = @selector(symbolChanged:);
    [self.toolbarView addSubview:self.symbolComboBox];
    
    // Timeframe control
    self.timeframeControl = [[NSSegmentedControl alloc] init];
    self.timeframeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeframeControl.segmentCount = 6;
    [self.timeframeControl setLabel:@"1m" forSegment:0];
    [self.timeframeControl setLabel:@"5m" forSegment:1];
    [self.timeframeControl setLabel:@"15m" forSegment:2];
    [self.timeframeControl setLabel:@"1h" forSegment:3];
    [self.timeframeControl setLabel:@"1d" forSegment:4];
    [self.timeframeControl setLabel:@"1w" forSegment:5];
    self.timeframeControl.selectedSegment = self.selectedTimeframe;
    self.timeframeControl.target = self;
    self.timeframeControl.action = @selector(timeframeChanged:);
    [self.toolbarView addSubview:self.timeframeControl];
    
    // Refresh button
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.refreshButton.title = @"⟳";
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshButtonClicked:);
    [self.toolbarView addSubview:self.refreshButton];
    
    // Indicators button
    self.indicatorsButton = [[NSButton alloc] init];
    self.indicatorsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorsButton.title = @"INDICATORS";
    self.indicatorsButton.target = self;
    self.indicatorsButton.action = @selector(indicatorsButtonClicked:);
    [self.toolbarView addSubview:self.indicatorsButton];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    [self.loadingIndicator stopAnimation:nil];
    [self.toolbarView addSubview:self.loadingIndicator];
    
    NSLog(@"✅ ChartWidget: Toolbar created");
}

- (void)createChartArea {
    // Scroll view for chart panels
    self.chartScrollView = [[NSScrollView alloc] init];
    self.chartScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chartScrollView.hasVerticalScroller = YES;
    self.chartScrollView.hasHorizontalScroller = NO;
    self.chartScrollView.autohidesScrollers = YES;
    [self.contentView addSubview:self.chartScrollView];
    
    // NUOVO: Split view per pannelli ridimensionabili
    self.panelsSplitView = [[NSSplitView alloc] init];
    self.panelsSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsSplitView.vertical = NO;  // Orientamento verticale (split orizzontali)
    self.panelsSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.panelsSplitView.delegate = self;  // Aggiungi delegate per controllo resize
    
    // Set split view as document view
    self.chartScrollView.documentView = self.panelsSplitView;
    
    NSLog(@"✅ ChartWidget: Chart area created with resizable panels");
}

- (void)createZoomControls {
    NSLog(@"🎛️ Creating zoom controls...");
    
    // Container view per controlli zoom
    self.zoomControlsView = [[NSView alloc] init];
    if (!self.zoomControlsView) {
        NSLog(@"❌ Failed to create zoomControlsView");
        return;
    }
    
    self.zoomControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomControlsView.wantsLayer = YES;
    self.zoomControlsView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    [self.contentView addSubview:self.zoomControlsView];
    
    // Zoom Out button (-)
    self.zoomOutButton = [[NSButton alloc] init];
    if (!self.zoomOutButton) {
        NSLog(@"❌ Failed to create zoomOutButton");
        return;
    }
    
    self.zoomOutButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomOutButton.title = @"−";
    self.zoomOutButton.font = [NSFont systemFontOfSize:16 weight:NSFontWeightMedium];
    self.zoomOutButton.bezelStyle = NSBezelStyleRounded;
    self.zoomOutButton.target = self;
    self.zoomOutButton.action = @selector(zoomOutButtonClicked:);
    self.zoomOutButton.toolTip = @"Zoom Out";
    [self.zoomControlsView addSubview:self.zoomOutButton];
    
    // Zoom slider
    self.zoomSlider = [[NSSlider alloc] init];
    if (!self.zoomSlider) {
        NSLog(@"❌ Failed to create zoomSlider");
        return;
    }
    
    self.zoomSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomSlider.minValue = 0.1;
    self.zoomSlider.maxValue = 10.0;
    self.zoomSlider.doubleValue = 1.0;
    self.zoomSlider.continuous = YES;
    self.zoomSlider.target = self;
    self.zoomSlider.action = @selector(zoomSliderChanged:);
    self.zoomSlider.toolTip = @"Zoom Level";
    [self.zoomControlsView addSubview:self.zoomSlider];
    
    // Zoom In button (+)
    self.zoomInButton = [[NSButton alloc] init];
    if (!self.zoomInButton) {
        NSLog(@"❌ Failed to create zoomInButton");
        return;
    }
    
    self.zoomInButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomInButton.title = @"+";
    self.zoomInButton.font = [NSFont systemFontOfSize:16 weight:NSFontWeightMedium];
    self.zoomInButton.bezelStyle = NSBezelStyleRounded;
    self.zoomInButton.target = self;
    self.zoomInButton.action = @selector(zoomInButtonClicked:);
    self.zoomInButton.toolTip = @"Zoom In";
    [self.zoomControlsView addSubview:self.zoomInButton];
    
    // Zoom All button
    self.zoomAllButton = [[NSButton alloc] init];
    if (!self.zoomAllButton) {
        NSLog(@"❌ Failed to create zoomAllButton");
        return;
    }
    
    self.zoomAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomAllButton.title = @"ALL";
    self.zoomAllButton.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.zoomAllButton.bezelStyle = NSBezelStyleRounded;
    self.zoomAllButton.target = self;
    self.zoomAllButton.action = @selector(zoomAllButtonClicked:);
    self.zoomAllButton.toolTip = @"Fit All Data";
    [self.zoomControlsView addSubview:self.zoomAllButton];
    
    NSLog(@"✅ ChartWidget: Zoom controls created successfully");
}



- (void)setupZoomControlsConstraints {
    NSLog(@"🔧 Setting up zoom controls constraints...");
    
    if (!self.zoomControlsView || !self.zoomOutButton || !self.zoomSlider ||
        !self.zoomInButton || !self.zoomAllButton || !self.contentView) {
        NSLog(@"⚠️ Missing zoom controls elements, skipping constraints");
        return;
    }
    
    CGFloat controlsHeight = 40;
    
    @try {
        // 1. Zoom controls view - attaccato in basso e piena larghezza
        [NSLayoutConstraint activateConstraints:@[
            [self.zoomControlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [self.zoomControlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [self.zoomControlsView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [self.zoomControlsView.heightAnchor constraintEqualToConstant:controlsHeight]
        ]];
        
        // 2. Zoom ALL button - destra
        [NSLayoutConstraint activateConstraints:@[
            [self.zoomAllButton.trailingAnchor constraintEqualToAnchor:self.zoomControlsView.trailingAnchor constant:-16],
            [self.zoomAllButton.centerYAnchor constraintEqualToAnchor:self.zoomControlsView.centerYAnchor],
            [self.zoomAllButton.widthAnchor constraintEqualToConstant:48],
            [self.zoomAllButton.heightAnchor constraintEqualToConstant:28]
        ]];
        
        // 3. Zoom IN button - a sinistra di ALL
        [NSLayoutConstraint activateConstraints:@[
            [self.zoomInButton.trailingAnchor constraintEqualToAnchor:self.zoomAllButton.leadingAnchor constant:-8],
            [self.zoomInButton.centerYAnchor constraintEqualToAnchor:self.zoomControlsView.centerYAnchor],
            [self.zoomInButton.widthAnchor constraintEqualToConstant:32],
            [self.zoomInButton.heightAnchor constraintEqualToConstant:28]
        ]];
        
        // 4. Zoom OUT button - a sinistra di IN
        [NSLayoutConstraint activateConstraints:@[
            [self.zoomOutButton.trailingAnchor constraintEqualToAnchor:self.zoomInButton.leadingAnchor constant:-4],
            [self.zoomOutButton.centerYAnchor constraintEqualToAnchor:self.zoomControlsView.centerYAnchor],
            [self.zoomOutButton.widthAnchor constraintEqualToConstant:32],
            [self.zoomOutButton.heightAnchor constraintEqualToConstant:28]
        ]];
        
        // 5. Zoom SLIDER - riempie lo spazio rimanente
        [NSLayoutConstraint activateConstraints:@[
            [self.zoomSlider.leadingAnchor constraintEqualToAnchor:self.zoomControlsView.leadingAnchor constant:16],
            [self.zoomSlider.trailingAnchor constraintEqualToAnchor:self.zoomOutButton.leadingAnchor constant:-16],
            [self.zoomSlider.centerYAnchor constraintEqualToAnchor:self.zoomControlsView.centerYAnchor],
            [self.zoomSlider.heightAnchor constraintEqualToConstant:24]
        ]];
        
        NSLog(@"✅ Zoom control constraints applied correctly.");
        
    } @catch (NSException *exception) {
        NSLog(@"❌ Exception setting zoom controls constraints: %@", exception);
    }
}


- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar constraints
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:40],
        
        // Chart scroll view - CORREZIONE: si estende per tutto lo spazio disponibile
        [self.chartScrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor],
        [self.chartScrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.chartScrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.chartScrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        // CORREZIONE: Stack view constraints - si espande completamente
        [self.panelsSplitView.topAnchor constraintEqualToAnchor:self.chartScrollView.topAnchor],
        [self.panelsSplitView.leadingAnchor constraintEqualToAnchor:self.chartScrollView.leadingAnchor],
        [self.panelsSplitView.trailingAnchor constraintEqualToAnchor:self.chartScrollView.trailingAnchor],
        [self.panelsSplitView.bottomAnchor constraintEqualToAnchor:self.chartScrollView.bottomAnchor],
        [self.panelsSplitView.widthAnchor constraintEqualToAnchor:self.chartScrollView.widthAnchor],
        
        // Toolbar components
        [self.symbolComboBox.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:8],
        [self.symbolComboBox.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.symbolComboBox.widthAnchor constraintEqualToConstant:100],
        
        [self.timeframeControl.leadingAnchor constraintEqualToAnchor:self.symbolComboBox.trailingAnchor constant:8],
        [self.timeframeControl.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.timeframeControl.trailingAnchor constant:8],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.refreshButton.widthAnchor constraintEqualToConstant:30],
        
        [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.refreshButton.trailingAnchor constant:8],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        
        [self.indicatorsButton.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-8],
        [self.indicatorsButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor]
    ]];
    
    [self setupZoomControlsConstraints];
}


#pragma mark - Panel Management

- (void)createMainPanel {
    // Crea pannello principale per prezzi
    ChartPanelModel *mainPanel = [ChartPanelModel mainPanelWithTitle:@"Security"];
    
    // Aggiungi indicatore prezzi principale se disponibile
    id<IndicatorRenderer> priceRenderer = [self createIndicatorOfType:@"Security"];
    if (priceRenderer) {
        [mainPanel addIndicator:priceRenderer];
    }
    
    [self addPanelWithModel:mainPanel];
    
    // NUOVO: Aggiorna pan slider dopo aver creato il pannello principale
    [self updatePanSliderRange];
    
    NSLog(@"✅ ChartWidget: Main panel created with price indicator");
}

- (ChartPanelModel *)createMainSecurityPanel {
    ChartPanelModel *panel = [ChartPanelModel mainPanelWithTitle:@"Security"];
    
    // Add candlestick renderer
    CandlestickRenderer *candlestickRenderer = [[CandlestickRenderer alloc] init];
    [panel addIndicator:candlestickRenderer];
    
    return panel;
}


- (void)requestDeletePanel:(ChartPanelModel *)panelModel {
    if (!panelModel.canBeDeleted) {
        NSLog(@"⚠️ ChartWidget: Cannot delete main panel");
        return;
    }
    
    [self removePanelWithModel:panelModel];
}

#pragma mark - Factory Methods for Indicators

- (id<IndicatorRenderer>)createIndicatorOfType:(NSString *)indicatorType {
    if ([indicatorType isEqualToString:@"Security"]) {
        return [[CandlestickRenderer alloc] init];
    } else if ([indicatorType isEqualToString:@"Volume"]) {
        return [[VolumeRenderer alloc] init];
    }
    
    NSLog(@"⚠️ ChartWidget: Unknown indicator type: %@", indicatorType);
    return nil;
}

#pragma mark - UI Updates

- (void)refreshAllPanels {
    // CORREZIONE: forza il refresh di tutti i panels
    dispatch_async(dispatch_get_main_queue(), ^{
        for (ChartPanelView *panelView in self.panelViews) {
            [panelView setNeedsDisplay:YES];
            [panelView refreshDisplay];
        }
    });
}

- (void)updateToolbarState {
    self.symbolComboBox.stringValue = self.currentSymbol;
    self.timeframeControl.selectedSegment = self.selectedTimeframe;
    self.refreshButton.enabled = !self.isLoading;
}

#pragma mark - Data Management

- (void)loadHistoricalDataForSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    self.isLoading = YES;
    [self.loadingIndicator startAnimation:nil];
    self.refreshButton.enabled = NO;
    
    // Convert selectedTimeframe to BarTimeframe enum
    BarTimeframe timeframe = [self timeframeEnumForIndex:self.selectedTimeframe];
    
    NSLog(@"📈 ChartWidget: Loading data for %@ timeframe %ld", symbol, (long)timeframe);
    
    [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                       timeframe:timeframe
                                        barCount:self.maxBarsToDisplay
                                      completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            [self.loadingIndicator stopAnimation:nil];
            self.refreshButton.enabled = YES;
            
            if (!bars || bars.count == 0) {
                NSLog(@"⚠️ ChartWidget: No data received for %@", symbol);
                // CORREZIONE: forza il refresh anche senza dati
                [self updateAllPanelsWithData:nil];
                return;
            }
            
            NSLog(@"✅ ChartWidget: Loaded %lu bars for %@ (isFresh: %@)",
                  (unsigned long)bars.count, symbol, isFresh ? @"YES" : @"NO");
            
            [self updateAllPanelsWithData:bars];
        });
    }];
}

- (void)refreshCurrentData {
    [self loadHistoricalDataForSymbol:self.currentSymbol];
}

- (void)updateAllPanelsWithData:(NSArray<HistoricalBarModel *> *)data {
    self.historicalData = data;
    
    // CORREZIONE: validazione del coordinator prima di aggiornare
    if (self.coordinator) {
        [self.coordinator updateHistoricalData:data];
    } else {
        NSLog(@"⚠️ ChartWidget: Coordinator not initialized!");
        self.coordinator = [[ChartCoordinator alloc] init];
        self.coordinator.maxVisibleBars = self.maxBarsToDisplay;
        [self.coordinator updateHistoricalData:data];
    }
    
    // NUOVO: Aggiorna il pan slider dopo aver caricato nuovi dati
    [self updatePanSliderRange];
    
    // Update all panel views - CORREZIONE: forza il display update
    dispatch_async(dispatch_get_main_queue(), ^{
        for (ChartPanelView *panelView in self.panelViews) {
            [panelView updateWithHistoricalData:data];
            [panelView setNeedsDisplay:YES];
        }
    });
    
    NSLog(@"📊 ChartWidget: Updated %lu panels with %lu data points and refreshed pan slider",
          (unsigned long)self.panelViews.count, (unsigned long)(data ? data.count : 0));
}
#pragma mark - Actions

- (IBAction)symbolChanged:(id)sender {
    NSString *newSymbol = self.symbolComboBox.stringValue.uppercaseString;
    if (!newSymbol || newSymbol.length == 0) return;
    
    self.currentSymbol = newSymbol;
    [self loadHistoricalDataForSymbol:newSymbol];
    
    NSLog(@"📊 ChartWidget: Symbol changed to %@", newSymbol);
}

- (IBAction)timeframeChanged:(id)sender {
    self.selectedTimeframe = self.timeframeControl.selectedSegment;
    [self loadHistoricalDataForSymbol:self.currentSymbol];
    
    NSLog(@"📊 ChartWidget: Timeframe changed to %ld", (long)self.selectedTimeframe);
}

- (IBAction)refreshButtonClicked:(id)sender {
    [self refreshCurrentData];
}



#pragma mark - Utility Methods

- (BarTimeframe)timeframeEnumForIndex:(NSInteger)index {
    switch (index) {
        case 0: return BarTimeframe1Min;
        case 1: return BarTimeframe5Min;
        case 2: return BarTimeframe15Min;
        case 3: return BarTimeframe1Hour;
        case 4: return BarTimeframe1Day;
        case 5: return BarTimeframe1Week;
        default: return BarTimeframe1Day;
    }
}

- (NSDate *)startDateForTimeframe {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    
    switch (self.selectedTimeframe) {
        case 0: // 1m
        case 1: // 5m
        case 2: // 15m
            return [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:now options:0];
        case 3: // 1h
            return [calendar dateByAddingUnit:NSCalendarUnitDay value:-5 toDate:now options:0];
        case 4: // 1d
            return [calendar dateByAddingUnit:NSCalendarUnitMonth value:-6 toDate:now options:0];
        case 5: // 1w
            return [calendar dateByAddingUnit:NSCalendarUnitYear value:-2 toDate:now options:0];
        default:
            return [calendar dateByAddingUnit:NSCalendarUnitMonth value:-6 toDate:now options:0];
    }
}

#pragma mark - Notifications

- (void)registerForNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMarketDataUpdate:)
                                                 name:@"MarketDataUpdated"
                                               object:nil];
}

- (void)handleMarketDataUpdate:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *symbol = userInfo[@"symbol"];
    
    if ([symbol isEqualToString:self.currentSymbol]) {
        [self refreshCurrentData];
    }
}


#pragma mark - Indicators Panel Integration

- (IBAction)indicatorsButtonClicked:(id)sender {
    // Inizializza il controller se non esiste
    if (!self.indicatorsPanelController) {
        self.indicatorsPanelController = [[IndicatorsPanelController alloc] initWithChartWidget:self];
    }
    
    // CORREZIONE: Gestione popup window invece di toggle
    if (self.indicatorsPanelController.isVisible) {
        // Se è già visibile, nascondilo
        [self.indicatorsPanelController hidePanel];
        NSLog(@"🎛️ ChartWidget: Indicators popup hidden");
    } else {
        // Se non è visibile, mostralo
        [self.indicatorsPanelController showPanel];
        NSLog(@"🎛️ ChartWidget: Indicators popup shown");
    }
}

// METODO HELPER: Controlla se il popup è ancora valido (non chiuso dall'utente)
- (void)checkIndicatorsPanelStatus {
    // Questo metodo può essere chiamato periodicamente per sincronizzare lo stato
    // se l'utente chiude il popup cliccando fuori
    if (self.indicatorsPanelController && !self.indicatorsPanelController.popupWindow) {
        // Il popup è stato chiuso dall'utente
        self.indicatorsPanelController.isVisible = NO;
    }
}

// AGGIUNTA: Metodo per notificare il panel quando i panel cambiano
- (void)notifyIndicatorsPanelOfChanges {
    if (self.indicatorsPanelController && self.indicatorsPanelController.isVisible) {
        [self.indicatorsPanelController refreshPanelsList];
    }
}

- (void)addPanelWithModel:(ChartPanelModel *)panelModel {
    // Add to data model
    [self.panelModels addObject:panelModel];
    
    // Create view for panel
    ChartPanelView *panelView = [[ChartPanelView alloc] initWithPanelModel:panelModel
                                                               coordinator:self.coordinator
                                                               chartWidget:self];
    
    // Set historical data if available
    if (self.historicalData) {
        [panelView updateWithHistoricalData:self.historicalData];
    }
    
    // Add to collections and UI
    [self.panelViews addObject:panelView];
    [self.panelsSplitView addSubview:panelView];
    
    // CORREZIONE 1: Rimuovi tutti i constraint di altezza fissi
    panelView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // CORREZIONE 2: Setup delle priorità di ridimensionamento SENZA constraint di altezza
    if (panelModel.panelType == ChartPanelTypeMain) {
        // Main panel: bassa hugging priority = vuole espandersi di più
        [panelView setContentHuggingPriority:NSLayoutPriorityDefaultLow
                              forOrientation:NSLayoutConstraintOrientationVertical];
        [panelView setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                            forOrientation:NSLayoutConstraintOrientationVertical];
    } else {
        // Secondary panels: media hugging priority
        [panelView setContentHuggingPriority:NSLayoutPriorityDefaultHigh - 100
                              forOrientation:NSLayoutConstraintOrientationVertical];
        [panelView setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh
                                            forOrientation:NSLayoutConstraintOrientationVertical];
    }
    
    // CORREZIONE 3: Width constraint per riempire orizzontalmente
    NSLayoutConstraint *widthConstraint = [panelView.widthAnchor constraintEqualToAnchor:self.panelsSplitView.widthAnchor];
    widthConstraint.active = YES;
    
    // CORREZIONE 4: Force layout e ridistribuzione IMMEDIATA
    [self.panelsSplitView adjustSubviews];
    
    // CORREZIONE 5: Calcola e applica proporzioni corrette
    [self redistributePanelProportions];
    
    // Notifica il popup se è visibile
    [self notifyIndicatorsPanelOfChanges];
    
    NSLog(@"📊 ChartWidget: Added panel '%@' with automatic sizing",
          panelModel.title);
}
- (void)redistributePanelProportions {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat totalHeight = self.panelsSplitView.frame.size.height;
        if (totalHeight <= 0) {
            // Retry dopo il layout
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self redistributePanelProportions];
            });
            return;
        }
        
        NSInteger panelCount = self.panelViews.count;
        if (panelCount <= 1) return;
        
        // Calcola altezze target basate sui heightRatio
        CGFloat totalRatio = 0;
        for (ChartPanelModel *model in self.panelModels) {
            totalRatio += model.heightRatio;
        }
        
        // Normalizza i ratio se necessario
        if (totalRatio <= 0) totalRatio = 1.0;
        
        // Applica le proporzioni
        CGFloat currentY = 0;
        for (NSInteger i = 0; i < panelCount; i++) {
            ChartPanelModel *model = self.panelModels[i];
            CGFloat targetHeight = (model.heightRatio / totalRatio) * totalHeight;
            
            // Assicura altezza minima
            CGFloat minHeight = model.minHeight > 0 ? model.minHeight : 80.0;
            targetHeight = MAX(targetHeight, minHeight);
            
            if (i < panelCount - 1) {
                // Per tutti i pannelli tranne l'ultimo, imposta la posizione del divider
                currentY += targetHeight;
                [self.panelsSplitView setPosition:currentY ofDividerAtIndex:i];
            }
            
            NSLog(@"📏 Panel %ld: target height %.1f (ratio %.2f)",
                  (long)i, targetHeight, model.heightRatio);
        }
        
        // Force final layout
        [self.panelsSplitView adjustSubviews];
        [self.view layoutSubtreeIfNeeded];
    });
}

// MODIFICA per removePanelWithModel - aggiungi notifica
- (void)removePanelWithModel:(ChartPanelModel *)panelModel {
    NSInteger index = [self.panelModels indexOfObject:panelModel];
    if (index == NSNotFound) return;
    
    // Cannot delete main panel
    if (panelModel.panelType == ChartPanelTypeMain) {
        NSLog(@"⚠️ ChartWidget: Cannot delete main panel");
        return;
    }
    
    // Remove from collections
    ChartPanelView *panelView = self.panelViews[index];
    [self.panelModels removeObjectAtIndex:index];
    [self.panelViews removeObjectAtIndex:index];
    
    // Remove from UI - CAMBIATO per NSSplitView
    [panelView removeFromSuperview];
    [self.panelsSplitView adjustSubviews];  // Ricalcola le proporzioni
    
    // Notifica il popup se è visibile
    [self notifyIndicatorsPanelOfChanges];
    
    NSLog(@"🗑️ ChartWidget: Removed resizable panel '%@'", panelModel.title);
}

#pragma mark - NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    // IMPORTANTE: Non permettere il collasso automatico
    return NO;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    // Ogni pannello deve avere almeno l'altezza minima
    CGFloat minHeight = 80.0;
    if (dividerIndex < self.panelModels.count) {
        ChartPanelModel *model = self.panelModels[dividerIndex];
        minHeight = model.minHeight > 0 ? model.minHeight : 80.0;
    }
    
    CGFloat currentTop = 0;
    for (NSInteger i = 0; i < dividerIndex; i++) {
        currentTop += self.panelViews[i].frame.size.height;
    }
    
    return currentTop + minHeight;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    // Il pannello successivo deve avere almeno la sua altezza minima
    CGFloat totalHeight = splitView.frame.size.height;
    CGFloat minHeightBelow = 0;
    
    for (NSInteger i = dividerIndex + 1; i < self.panelModels.count; i++) {
        ChartPanelModel *model = self.panelModels[i];
        minHeightBelow += model.minHeight > 0 ? model.minHeight : 80.0;
    }
    
    return totalHeight - minHeightBelow;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    // Aggiorna i heightRatio quando l'utente ridimensiona manualmente
    [self updatePanelHeightRatiosFromCurrentSizes];
}

// ======= NUOVO METODO: Aggiorna ratio da dimensioni correnti =======
- (void)updatePanelHeightRatiosFromCurrentSizes {
    CGFloat totalHeight = self.panelsSplitView.frame.size.height;
    if (totalHeight <= 0) return;
    
    for (NSInteger i = 0; i < self.panelViews.count; i++) {
        ChartPanelView *panelView = self.panelViews[i];
        ChartPanelModel *panelModel = self.panelModels[i];
        
        CGFloat panelHeight = panelView.frame.size.height;
        panelModel.heightRatio = panelHeight / totalHeight;
        
        NSLog(@"📏 Updated panel %ld ratio to %.3f (height %.1f/%.1f)",
              (long)i, panelModel.heightRatio, panelHeight, totalHeight);
    }
}
// AGGIUNTA al dealloc per cleanup
- (void)dealloc {
    // Nascondi il popup se è visibile per cleanup
    if (self.indicatorsPanelController.isVisible) {
        [self.indicatorsPanelController hidePanel];
    }
}
#pragma mark - Zoom Controls Actions

- (IBAction)zoomOutButtonClicked:(id)sender {
    NSLog(@"🔍 Zoom Out button clicked");
    
    // Zoom out = mostra più barre (diminuisce zoom factor)
    NSRange currentRange = self.coordinator.visibleBarsRange;
    NSInteger newVisibleBars = MIN(self.maxBarsToDisplay, currentRange.length * 1.5);
    
    // Calcola nuovo range mantenendo il centro
    NSInteger centerBar = currentRange.location + currentRange.length / 2;
    NSInteger newStart = centerBar - newVisibleBars / 2;
    newStart = MAX(0, newStart);
    
    if (self.historicalData && newStart + newVisibleBars > self.historicalData.count) {
        newStart = MAX(0, self.historicalData.count - newVisibleBars);
    }
    
    self.coordinator.visibleBarsRange = NSMakeRange(newStart, newVisibleBars);
    self.coordinator.zoomFactor = (CGFloat)self.maxBarsToDisplay / newVisibleBars;
    
    [self updatePanSliderRange];
    [self refreshAllPanels];
    
    NSLog(@"🔍 Zoom Out: %@ (factor %.2f)", NSStringFromRange(self.coordinator.visibleBarsRange), self.coordinator.zoomFactor);
}

- (IBAction)zoomInButtonClicked:(id)sender {
    NSLog(@"🔍 Zoom In button clicked");
    
    // Zoom in = mostra meno barre (aumenta zoom factor)
    NSRange currentRange = self.coordinator.visibleBarsRange;
    NSInteger newVisibleBars = MAX(10, currentRange.length / 1.5);
    
    if (newVisibleBars >= currentRange.length) {
        NSLog(@"🚫 Already at maximum zoom");
        return;
    }
    
    // Calcola nuovo range mantenendo il centro
    NSInteger centerBar = currentRange.location + currentRange.length / 2;
    NSInteger newStart = centerBar - newVisibleBars / 2;
    newStart = MAX(0, newStart);
    
    if (self.historicalData && newStart + newVisibleBars > self.historicalData.count) {
        newStart = MAX(0, self.historicalData.count - newVisibleBars);
    }
    
    self.coordinator.visibleBarsRange = NSMakeRange(newStart, newVisibleBars);
    self.coordinator.zoomFactor = (CGFloat)self.maxBarsToDisplay / newVisibleBars;
    
    [self updatePanSliderRange];
    [self refreshAllPanels];
    
    NSLog(@"🔍 Zoom In: %@ (factor %.2f)", NSStringFromRange(self.coordinator.visibleBarsRange), self.coordinator.zoomFactor);
}

- (IBAction)zoomSliderChanged:(id)sender {
    NSLog(@"🔄 Pan slider changed to %.2f", self.zoomSlider.doubleValue);
    
    // LO SLIDER È PER IL PANNING, NON ZOOM!
    if (!self.historicalData || self.historicalData.count == 0) return;
    
    NSRange currentRange = self.coordinator.visibleBarsRange;
    NSInteger totalBars = self.historicalData.count;
    NSInteger maxStart = MAX(0, totalBars - currentRange.length);
    
    // Slider value da 0.0 a 1.0 rappresenta la posizione nella timeline
    double sliderValue = self.zoomSlider.doubleValue;
    NSInteger newStart = (NSInteger)(sliderValue * maxStart);
    
    self.coordinator.visibleBarsRange = NSMakeRange(newStart, currentRange.length);
    [self refreshAllPanels];
    
    NSLog(@"🔄 Pan to position: %@ (%.1f%% of timeline)",
          NSStringFromRange(self.coordinator.visibleBarsRange),
          sliderValue * 100);
}

- (IBAction)zoomAllButtonClicked:(id)sender {
    NSLog(@"🔍 Zoom All button clicked");
    
    [self.coordinator resetZoomAndPan];
    [self updatePanSliderRange];
    [self refreshAllPanels];
    
    NSLog(@"🔍 Reset to show all data: %@", NSStringFromRange(self.coordinator.visibleBarsRange));
}

// ======= NUOVO METODO: Aggiorna range dello slider per panning =======
- (void)updatePanSliderRange {
    if (!self.historicalData || self.historicalData.count == 0 || !self.zoomSlider) {
        return;
    }
    
    NSRange currentRange = self.coordinator.visibleBarsRange;
    NSInteger totalBars = self.historicalData.count;
    NSInteger maxStart = MAX(0, totalBars - currentRange.length);
    
    if (maxStart <= 0) {
        // Se mostriamo tutti i dati, disabilita lo slider
        self.zoomSlider.enabled = NO;
        self.zoomSlider.doubleValue = 0.0;
    } else {
        // Abilita lo slider e calcola posizione corrente
        self.zoomSlider.enabled = YES;
        self.zoomSlider.minValue = 0.0;
        self.zoomSlider.maxValue = 1.0;
        
        double currentPosition = (double)currentRange.location / maxStart;
        self.zoomSlider.doubleValue = currentPosition;
    }
    
    // Aggiorna tooltip
    self.zoomSlider.toolTip = [NSString stringWithFormat:@"Pan Timeline (showing %ld of %ld bars)",
                               (long)currentRange.length, (long)totalBars];
}

@end

