//
//  ChartWidget.m
//  TradingApp
//
//  Chart widget with multiple coordinated panels
//

#import "ChartWidget.h"
#import "DataHub+MarketData.h"
#import "RuntimeModels.h"
#import "ChartPanelView.h"
#import "ChartWidget+ObjectsUI.h"
#import "ChartObjectModels.h"
#import "ChartObjectManagerWindow.h"
#import "ChartWidget+ObjectsUI.h"

// Define constants locally instead of importing
static NSString *const kWidgetChainUpdateNotification = @"WidgetChainUpdateNotification";
static NSString *const kChainUpdateKey = @"update";
static NSString *const kChainSenderKey = @"sender";

// Import DataHub constants
extern NSString *const DataHubDataLoadedNotification;

@interface ChartWidget () <NSTextFieldDelegate,ObjectsPanelDelegate>

// Internal data
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *chartData;

// Interaction state
@property (nonatomic, assign) BOOL isInPanMode;
@property (nonatomic, assign) BOOL isInChartPortionSelectionMode;
@property (nonatomic, assign) NSPoint dragStartPoint;
@property (nonatomic, assign) NSPoint currentCrosshairPoint;
@property (nonatomic, assign) BOOL crosshairVisible;

@end

@implementation ChartWidget

#pragma mark - BaseWidget Override

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        [self setupChartDefaults];
        [self registerForChainNotifications];
        [self registerForDataNotifications];
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    // Rimuovi il placeholder del BaseWidget
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Setup UI programmatico seguendo il pattern degli altri widget
    [self setupUI];
    [self setupConstraints];
    [self setupInitialUI]; // Mantieni questa chiamata esistente
}

- (void)setupUI {
    // Setup toolbar superiore (MODIFICATO per objects UI)
    [self setupTopToolbar];
    
    // Setup objects UI (NUOVO)
    [self setupObjectsUI];
    
    // SplitView principale per i pannelli chart (ESISTENTE)
    [self setupMainSplitView];
    
    // Controlli zoom inferiori (ESISTENTE)
    [self setupBottomControls];
}

// ======== AGGIUNGI setupTopToolbar ========
- (void)setupTopToolbar {
    // Symbol text field (come nello XIB)
    self.symbolTextField = [[NSTextField alloc] init];
    self.symbolTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolTextField.placeholderString = @"Enter symbol";
    self.symbolTextField.delegate = self;
    [self.contentView addSubview:self.symbolTextField];
    
    self.objectsVisibilityToggle = [NSButton buttonWithTitle:@"👁️"
                                                     target:self
                                                     action:@selector(toggleAllObjectsVisibility:)];
    self.objectsVisibilityToggle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.objectsVisibilityToggle];

    // Timeframe segmented control (come nello XIB)
    self.timeframeSegmented = [[NSSegmentedControl alloc] init];
    self.timeframeSegmented.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeframeSegmented.segmentCount = 8;
    self.timeframeSegmented.segmentStyle = NSSegmentStyleRounded;
    [self.contentView addSubview:self.timeframeSegmented];
    
    // Bars count text field (come nello XIB)
    self.barsCountTextField = [[NSTextField alloc] init];
    self.barsCountTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.barsCountTextField.stringValue = @"1000";
    [self.contentView addSubview:self.barsCountTextField];
    
    // Template popup (come nello XIB)
      self.templatePopup = [[NSPopUpButton alloc] init];
      self.templatePopup.translatesAutoresizingMaskIntoConstraints = NO;
      [self.contentView addSubview:self.templatePopup];
    
    // Preferences button (come nello XIB)
    self.preferencesButton = [NSButton buttonWithTitle:@"⚙"
                                                target:self
                                                action:@selector(showPreferences:)];
    self.preferencesButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.preferencesButton.bezelStyle = NSBezelStyleRounded;
    [self.contentView addSubview:self.preferencesButton];
}

// ======== AGGIUNGI setupMainSplitView ========
- (void)setupMainSplitView {
    // Split view principale per i pannelli (come nello XIB)
    self.panelsSplitView = [[NSSplitView alloc] init];
    self.panelsSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsSplitView.vertical = NO; // Divisione orizzontale
    self.panelsSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [self.contentView addSubview:self.panelsSplitView];
}

// ======== AGGIUNGI setupBottomControls ========
- (void)setupBottomControls {
    // Pan slider (come nello XIB)
    self.panSlider = [[NSSlider alloc] init];
    self.panSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.panSlider.minValue = 0;
    self.panSlider.maxValue = 100;
    self.panSlider.integerValue = 50;
    [self.contentView addSubview:self.panSlider];
    
    // Zoom out button (come nello XIB)
    self.zoomOutButton = [NSButton buttonWithTitle:@"-"
                                           target:self
                                           action:@selector(zoomOut:)];
    self.zoomOutButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomOutButton.bezelStyle = NSBezelStyleRounded;
    [self.contentView addSubview:self.zoomOutButton];
    
    // Zoom in button (come nello XIB)
    self.zoomInButton = [NSButton buttonWithTitle:@"+"
                                          target:self
                                          action:@selector(zoomIn:)];
    self.zoomInButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomInButton.bezelStyle = NSBezelStyleRounded;
    [self.contentView addSubview:self.zoomInButton];
    
    // Zoom all button (come nello XIB)
    self.zoomAllButton = [NSButton buttonWithTitle:@"All"
                                           target:self
                                           action:@selector(zoomAll:)];
    self.zoomAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomAllButton.bezelStyle = NSBezelStyleRounded;
    [self.contentView addSubview:self.zoomAllButton];
}

- (void)setupConstraints {
    
    self.splitViewLeadingConstraint = [self.panelsSplitView.leadingAnchor
                                         constraintEqualToAnchor:self.contentView.leadingAnchor
                                         constant:14];
    
    [NSLayoutConstraint activateConstraints:@[
        // Objects panel toggle - NUOVO (all'estrema sinistra)
        [self.objectsPanelToggle.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.objectsPanelToggle.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.objectsPanelToggle.widthAnchor constraintEqualToConstant:30],
        [self.objectsPanelToggle.heightAnchor constraintEqualToConstant:21],
        
        // Symbol field - MODIFICATO (ora dopo il toggle button)
        [self.symbolTextField.centerYAnchor constraintEqualToAnchor:self.objectsPanelToggle.centerYAnchor],
        [self.symbolTextField.leadingAnchor constraintEqualToAnchor:self.objectsPanelToggle.trailingAnchor constant:8],
        [self.symbolTextField.widthAnchor constraintEqualToConstant:100],
        [self.symbolTextField.heightAnchor constraintEqualToConstant:21],
        
        [self.objectsVisibilityToggle.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.objectsVisibilityToggle.leadingAnchor constraintEqualToAnchor:self.symbolTextField.trailingAnchor constant:8],
        [self.objectsVisibilityToggle.widthAnchor constraintEqualToConstant:32],
        [self.objectsVisibilityToggle.heightAnchor constraintEqualToConstant:21],
        
        // Timeframe segments (spostati per fare spazio)
        [self.timeframeSegmented.leadingAnchor constraintEqualToAnchor:self.objectsVisibilityToggle.trailingAnchor constant:8],
        [self.timeframeSegmented.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        
        // Bars count field - INVARIATO (relativo al timeframe)
        [self.barsCountTextField.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.barsCountTextField.leadingAnchor constraintEqualToAnchor:self.timeframeSegmented.trailingAnchor constant:8],
        [self.barsCountTextField.widthAnchor constraintEqualToConstant:60],
        
        // Template popup - INVARIATO (relativo al bars count)
        [self.templatePopup.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.templatePopup.leadingAnchor constraintEqualToAnchor:self.barsCountTextField.trailingAnchor constant:8],
        [self.templatePopup.widthAnchor constraintEqualToConstant:80],
        
        // Preferences button - INVARIATO (all'estrema destra)
        [self.preferencesButton.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.preferencesButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.preferencesButton.widthAnchor constraintEqualToConstant:30],
        [self.preferencesButton.heightAnchor constraintEqualToConstant:21],
        
        // Objects panel - NUOVO (a sinistra del main split view quando visibile)
        [self.objectsPanel.topAnchor constraintEqualToAnchor:self.panelsSplitView.topAnchor],
        [self.objectsPanel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.objectsPanel.bottomAnchor constraintEqualToAnchor:self.panelsSplitView.bottomAnchor],
        
        // Main split view - INVARIATO in alto e destra, MA leading sarà animato
        [self.panelsSplitView.topAnchor constraintEqualToAnchor:self.symbolTextField.bottomAnchor constant:8],
        self.splitViewLeadingConstraint, // ← Usa il constraint memorizzato
        [self.panelsSplitView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.panelsSplitView.bottomAnchor constraintEqualToAnchor:self.panSlider.topAnchor constant:-8],
        
        // Bottom controls - TUTTI INVARIATI
        [self.panSlider.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
        [self.panSlider.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.panSlider.trailingAnchor constraintEqualToAnchor:self.zoomOutButton.leadingAnchor constant:-8],
        
        [self.zoomOutButton.centerYAnchor constraintEqualToAnchor:self.panSlider.centerYAnchor],
        [self.zoomOutButton.trailingAnchor constraintEqualToAnchor:self.zoomInButton.leadingAnchor constant:-4],
        [self.zoomOutButton.widthAnchor constraintEqualToConstant:30],
        
        [self.zoomInButton.centerYAnchor constraintEqualToAnchor:self.panSlider.centerYAnchor],
        [self.zoomInButton.trailingAnchor constraintEqualToAnchor:self.zoomAllButton.leadingAnchor constant:-4],
        [self.zoomInButton.widthAnchor constraintEqualToConstant:30],
        
        [self.zoomAllButton.centerYAnchor constraintEqualToAnchor:self.panSlider.centerYAnchor],
        [self.zoomAllButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.zoomAllButton.widthAnchor constraintEqualToConstant:50]
    ]];
}



- (void)setupChartDefaults {
    // Codice esistente...
    self.currentSymbol = @"CRCL";
    self.currentTimeframe = ChartTimeframeDaily;
    self.barsToDownload = 1000;
    self.initialBarsToShow = 100;
    self.chartPanels = [NSMutableArray array];
    
    // NUOVO: Inizializza objects manager
    self.objectsManager = [ChartObjectsManager managerForSymbol:self.currentSymbol];
    
    // Reset viewport state
    self.visibleStartIndex = 0;
    self.visibleEndIndex = 0;
    self.yRangeMin = 0;
    self.yRangeMax = 0;
    self.isYRangeOverridden = NO;
}
- (void)setupInitialUI {
    // Setup text field delegates e actions
    self.symbolTextField.delegate = self;
    self.symbolTextField.target = self;
    self.symbolTextField.action = @selector(symbolChanged:);
    self.barsCountTextField.stringValue = @"1000";
    
    // Setup timeframe segmented control (mantieni codice esistente)
    if (self.timeframeSegmented.segmentCount >= 8) {
        [self.timeframeSegmented setLabel:@"1m" forSegment:0];
        [self.timeframeSegmented setLabel:@"5m" forSegment:1];
        [self.timeframeSegmented setLabel:@"15m" forSegment:2];
        [self.timeframeSegmented setLabel:@"30m" forSegment:3];
        [self.timeframeSegmented setLabel:@"1h" forSegment:4];
        [self.timeframeSegmented setLabel:@"4h" forSegment:5];
        [self.timeframeSegmented setLabel:@"1D" forSegment:6];
        [self.timeframeSegmented setLabel:@"1W" forSegment:7];
        [self.timeframeSegmented setSelectedSegment:6]; // Daily default
    }
    
    // Setup template popup (mantieni codice esistente)
    [self.templatePopup removeAllItems];
    [self.templatePopup addItemsWithTitles:@[@"Default", @"Technical", @"Volume Analysis", @"Custom"]];
    
    // Setup zoom controls
    self.panSlider.minValue = 0;
    self.panSlider.maxValue = 100;
    self.panSlider.integerValue = 50;
    
    // Connect actions se non già collegati
    self.timeframeSegmented.target = self;
    self.timeframeSegmented.action = @selector(timeframeChanged:);
    
    self.panSlider.target = self;
    self.panSlider.action = @selector(panSliderChanged:);
    
    // Actions già collegati nei setup dei bottoni:
    // - zoomOutButton -> zoomOut:
    // - zoomInButton -> zoomIn:
    // - zoomAllButton -> zoomAll:
    // - preferencesButton -> showPreferences:

}

- (void)ensureRenderersAreSetup {
    for (ChartPanelView *panel in self.chartPanels) {
        // Setup objects renderer (ESISTENTE)
        if (!panel.objectRenderer) {
            [panel setupObjectsRendererWithManager:self.objectsManager];
            NSLog(@"🔧 Setup missing objects renderer for panel %@", panel.panelType);
        }
        
        // 🆕 NUOVO: Setup alert renderer
        if (!panel.alertRenderer) {
            [panel setupAlertRenderer];
            NSLog(@"🚨 Setup alert renderer for panel %@", panel.panelType);
        }
    }
}

- (void)viewDidAppear{
    [super viewDidAppear];
    // Ora setup panels DOPO che la UI è stata creata
    [self setupDefaultPanels];
    [self ensureRenderersAreSetup];

}

- (void)setupDefaultPanels {
    
    
   
    // Remove any existing panels
    [self.chartPanels removeAllObjects];
    
    // Clear existing subviews from split view
    for (NSView *subview in [self.panelsSplitView.subviews copy]) {
        [subview removeFromSuperview];  // ✅ Correct method for removing from split view
    }
    
    NSRect splitFrame = self.panelsSplitView.frame;
    double secheight = splitFrame.size.height * 0.8;
    double volh = splitFrame.size.height - secheight;
    splitFrame.size.height = secheight;
    
    // Add Security panel (candlestick)
    ChartPanelView *securityPanel = [[ChartPanelView alloc] initWithType:@"security"];
    securityPanel.chartWidget = self;
    securityPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [securityPanel setFrame:splitFrame];
    [self.chartPanels addObject:securityPanel];
    [self.panelsSplitView addSubview:securityPanel];
    
    
    
    // Add Volume panel (histogram)
    ChartPanelView *volumePanel = [[ChartPanelView alloc] initWithType:@"volume"];
    volumePanel.chartWidget = self;
    volumePanel.translatesAutoresizingMaskIntoConstraints = NO;
    splitFrame.size.height = volh;
    [volumePanel setFrame:splitFrame];
    [self.chartPanels addObject:volumePanel];
    [self.panelsSplitView addSubview:volumePanel];
    
    [_panelsSplitView arrangesAllSubviews];
    
 
    
 /*   // Force layout
    [self.panelsSplitView setNeedsLayout:YES];
    [self.view setNeedsLayout:YES];
    [self configureSplitViewPriorities];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setInitialDividerPosition];
    });
    // Set initial divider position after a delay to ensure layout is complete
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"🔧 Setting divider position...");
        CGFloat totalHeight = self.panelsSplitView.frame.size.height;
        NSLog(@"🔍 Total height for divider calculation: %.2f", totalHeight);
        
        if (totalHeight > 150) { // Only if we have reasonable height
            CGFloat securityHeight = totalHeight * 0.8;
            [self.panelsSplitView setPosition:securityHeight ofDividerAtIndex:0];
            NSLog(@"✅ Set divider at position: %.2f (80%% of %.2f)", securityHeight, totalHeight);
        } else {
            NSLog(@"⚠️ Height too small (%.2f), will retry later", totalHeight);
            // Retry after view is properly sized
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                CGFloat retryHeight = self.panelsSplitView.frame.size.height;
                NSLog(@"🔄 Retry height: %.2f", retryHeight);
                if (retryHeight > 150) {
                    [self.panelsSplitView setPosition:retryHeight * 0.8 ofDividerAtIndex:0];
                    NSLog(@"✅ Retry: Set divider at position: %.2f", retryHeight * 0.8);
                } else {
                    NSLog(@"❌ Still too small after retry: %.2f", retryHeight);
                }
            });
        }
    });
    */
    NSLog(@"🎯 Default panels setup completed");
}
- (void)configureSplitViewPriorities {
    NSLog(@"🔧 Configuring split view priorities...");
    
    if (self.chartPanels.count >= 2) {
        ChartPanelView *securityPanel = self.chartPanels[0];
        ChartPanelView *volumePanel = self.chartPanels[1];
        
        // Set holding priorities for resize behavior
        [self.panelsSplitView setHoldingPriority:NSLayoutPriorityDefaultHigh
                                  forSubviewAtIndex:0]; // Security panel
        [self.panelsSplitView setHoldingPriority:NSLayoutPriorityDefaultLow
                                  forSubviewAtIndex:1]; // Volume panel
        
        // Set content hugging priorities
        [securityPanel setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                   forOrientation:NSLayoutConstraintOrientationVertical];
        [volumePanel setContentHuggingPriority:NSLayoutPriorityDefaultHigh
                                 forOrientation:NSLayoutConstraintOrientationVertical];
        
        // Set compression resistance
        [securityPanel setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh
                                                forOrientation:NSLayoutConstraintOrientationVertical];
        [volumePanel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                              forOrientation:NSLayoutConstraintOrientationVertical];
        
        NSLog(@"✅ Split view priorities configured");
    }
}

- (void)setInitialDividerPosition {
    NSLog(@"🔧 Setting initial divider position...");
    CGFloat totalHeight = self.panelsSplitView.frame.size.height;
    
    if (totalHeight > 150) {
        CGFloat securityHeight = totalHeight * 0.8;
        [self.panelsSplitView setPosition:securityHeight ofDividerAtIndex:0];
        
        NSLog(@"✅ Set divider position: %.2f (Security: %.2f, Volume: %.2f)",
              securityHeight, securityHeight, totalHeight - securityHeight);
        
        [self configureSplitViewPriorities];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self setInitialDividerPosition];
        });
    }
}
#pragma mark - Data Notifications

- (void)registerForDataNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleHistoricalDataUpdate:)
                                                 name:DataHubDataLoadedNotification
                                               object:nil];
}

- (void)handleHistoricalDataUpdate:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *symbol = userInfo[@"symbol"];
    
    if ([symbol isEqualToString:self.currentSymbol]) {
        NSArray<HistoricalBarModel *> *newData = userInfo[@"data"];
        if (newData) {
            self.chartData = newData;
            [self updateViewport];
            [self synchronizePanels];
        }
    }
}

#pragma mark - Chain Notifications

- (void)registerForChainNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSymbolChainNotification:)
                                                 name:kWidgetChainUpdateNotification
                                               object:nil];
}

- (void)handleSymbolChainNotification:(NSNotification *)notification {
    if (!self.chainActive) return;
    
    NSDictionary *userInfo = notification.userInfo;
    NSDictionary *update = userInfo[kChainUpdateKey];
    NSString *senderId = userInfo[kChainSenderKey];
    
    // Don't react to our own broadcasts
    if ([senderId isEqualToString:self.widgetID]) return;
    
    if (update) {
        NSString *action = update[@"action"];
        NSArray *symbols = update[@"symbols"];
        
        if ([action isEqualToString:@"setSymbols"] && symbols.count > 0) {
            NSString *symbol = symbols.firstObject;
            if (symbol && ![symbol isEqualToString:self.currentSymbol]) {
                [self loadSymbol:symbol];
            }
        }
    }
}

- (void)broadcastSymbolToChain:(NSString *)symbol {
    if (!self.chainActive || !symbol) return;
    
    NSDictionary *update = @{
        @"action": @"setSymbols",
        @"symbols": @[symbol]
    };
    
    NSDictionary *userInfo = @{
        kChainUpdateKey: update,
        kChainSenderKey: self.widgetID,
        @"timestamp": [NSDate date]
    };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kWidgetChainUpdateNotification
                                                        object:self
                                                      userInfo:userInfo];
}

#pragma mark - Actions

- (void)symbolChanged:(NSTextField *)sender {
    NSString *symbol = sender.stringValue.uppercaseString;
    if (symbol.length > 0 && ![symbol isEqualToString:self.currentSymbol]) {
        [self loadSymbol:symbol];
        [self broadcastSymbolToChain:symbol];
    }
}

- (void)timeframeChanged:(NSSegmentedControl *)sender {
    ChartTimeframe newTimeframe = (ChartTimeframe)sender.selectedSegment;
    [self setTimeframe:newTimeframe];
}
- (void)zoomIn:(NSButton *)sender {
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger newRange = MAX(10, currentRange / 1.5);
    NSInteger center = (self.visibleStartIndex + self.visibleEndIndex) / 2;
    
    [self zoomToRange:MAX(0, center - newRange/2)
             endIndex:MIN(self.chartData.count - 1, center + newRange/2)];
}

- (void)zoomOut:(NSButton *)sender {
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger newRange = MIN(self.chartData.count, currentRange * 1.5);
    NSInteger center = (self.visibleStartIndex + self.visibleEndIndex) / 2;
    
    [self zoomToRange:MAX(0, center - newRange/2)
             endIndex:MIN(self.chartData.count - 1, center + newRange/2)];
}

- (void)zoomAll:(NSButton *)sender {
    [self resetZoom];
}

- (void)panSliderChanged:(NSSlider *)sender {
    if (!self.chartData || self.chartData.count == 0) return;
    
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    double percentage = sender.doubleValue / 100.0;
    NSInteger maxStartIndex = self.chartData.count - currentRange;
    NSInteger newStartIndex = maxStartIndex * percentage;
    
    [self zoomToRange:newStartIndex endIndex:newStartIndex + currentRange];
}

#pragma mark - Public Methods


- (void)loadSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    BOOL sameSymbol = NO;
    if ([self.currentSymbol isEqualToString:symbol]) {
        sameSymbol = YES;
    }
    self.currentSymbol = symbol;
    self.symbolTextField.stringValue = symbol;
    
    // Convert ChartTimeframe to BarTimeframe
    BarTimeframe barTimeframe = [self chartTimeframeToBarTimeframe:self.currentTimeframe];
    NSInteger barsCount = self.barsCountTextField.integerValue;
    if (barsCount <= 0) barsCount = self.barsToDownload;
    
    // Request data from DataHub
    [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                       timeframe:barTimeframe
                                        barCount:barsCount
                                      completion:^(NSArray<HistoricalBarModel *> *data, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!data || data.count == 0) {
                NSLog(@"❌ ChartWidget: No data received for %@", symbol);
                return;
            }
            
            NSLog(@"✅ ChartWidget: Received %lu bars for %@ (%@)",
                  (unsigned long)data.count, symbol, isFresh ? @"fresh" : @"cached");
            
            // ✅ NUOVO: Controllo se serve aggiungere la barra corrente
            [self checkAndAddCurrentBarIfNeeded:data
                                        symbol:symbol
                                     timeframe:barTimeframe
                                    completion:^(NSArray<HistoricalBarModel *> *finalData) {
                
                self.chartData = finalData;
                if (!sameSymbol) {
                    [self resetToInitialView];
                }
                [self synchronizePanels];
                
                NSLog(@"📊 ChartWidget: Final dataset has %lu bars (potentially including current bar)",
                      (unsigned long)finalData.count);
            }];
        });
    }];
    
    [self refreshAlertsForCurrentSymbol];
    
    // ✅ OGGETTI: Aggiorna manager per nuovo symbol e forza load
    if (self.objectsManager) {
        self.objectsManager.currentSymbol = symbol;
        [self.objectsManager loadFromDataHub];
        
        NSLog(@"🔄 ChartWidget: Loading objects for symbol %@", symbol);
        
        if (self.objectsPanel && self.objectsPanel.objectManagerWindow) {
            [self.objectsPanel.objectManagerWindow updateForSymbol:symbol];
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self forceChartRedraw];
        });
    }
}

- (void)forceChartRedraw {
    // Metodo helper per forzare redraw completo
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.objectRenderer) {
            [panel.objectRenderer invalidateObjectsLayer];
            [panel.objectRenderer invalidateEditingLayer];
            
            // ✅ FORZA anche redraw del panel view stesso
            [panel setNeedsDisplay:YES];
        }
    }
    
    NSLog(@"🎨 Forced complete chart redraw");
}

- (void)setTimeframe:(ChartTimeframe)timeframe {
    if (timeframe == self.currentTimeframe) return;
    
    self.currentTimeframe = timeframe;
    [self.timeframeSegmented setSelectedSegment:timeframe];
    
    // Reload data with new timeframe
    if (self.currentSymbol) {
        [self loadSymbol:self.currentSymbol];
    }
}

- (void)zoomToRange:(NSInteger)startIndex endIndex:(NSInteger)endIndex {
    // Clamp indices
    startIndex = MAX(0, startIndex);
    endIndex = MIN(self.chartData.count - 1, endIndex);
    
    if (startIndex >= endIndex) return;
    
    self.visibleStartIndex = startIndex;
    self.visibleEndIndex = endIndex;
    
    // ✅ AGGIUNGI: Aggiorna slider senza triggerare action
    if (self.chartData.count > 0) {
        NSInteger visibleRange = endIndex - startIndex;
        double percentage = (double)startIndex / (self.chartData.count - visibleRange);
        percentage = MAX(0.0, MIN(1.0, percentage));
        
        // Temporaneamente rimuovi target per evitare loop
        id originalTarget = self.panSlider.target;
        self.panSlider.target = nil;
        [self.panSlider setDoubleValue:percentage * 100.0];
        self.panSlider.target = originalTarget;
    }
    
    [self updateViewport];
    [self synchronizePanels];
    
    NSLog(@"📊 Zoom applied: [%ld-%ld], slider at %.1f%%",
          (long)startIndex, (long)endIndex, self.panSlider.doubleValue);
}
- (void)resetZoom {
    if (!self.chartData || self.chartData.count == 0) return;
    
    [self zoomToRange:0 endIndex:self.chartData.count - 1];
}

#pragma mark - Helper Methods

- (void)resetToInitialView {
    if (!self.chartData || self.chartData.count == 0) return;
    
    NSInteger totalBars = self.chartData.count;
    NSInteger barsToShow = MIN(self.initialBarsToShow, totalBars);
    NSInteger startIndex = MAX(0, totalBars - barsToShow);
    
    [self zoomToRange:startIndex endIndex:totalBars - 1];
}

- (void)updateViewport {
    [self calculateYRange];
    [self updatePanSlider];
}

- (void)calculateYRange {
    if (!self.isYRangeOverridden) {
        // Calculate Y range from visible data
        if (self.chartData && self.visibleStartIndex < self.visibleEndIndex) {
            double minPrice = DBL_MAX;
            double maxPrice = -DBL_MAX;
            
            for (NSInteger i = self.visibleStartIndex; i <= self.visibleEndIndex && i < self.chartData.count; i++) {
                HistoricalBarModel *bar = self.chartData[i];
                minPrice = MIN(minPrice, bar.low);
                maxPrice = MAX(maxPrice, bar.high);
            }
            
            // Add 5% padding
            double padding = (maxPrice - minPrice) * 0.05;
            self.yRangeMin = minPrice - padding;
            self.yRangeMax = maxPrice + padding;
        }
    }
}

- (void)updatePanSlider {
    if (!self.chartData || self.chartData.count == 0) return;
    
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger maxStartIndex = self.chartData.count - currentRange;
    
    if (maxStartIndex > 0) {
        double percentage = (double)self.visibleStartIndex / maxStartIndex * 100.0;
        self.panSlider.doubleValue = percentage;
    } else {
        self.panSlider.doubleValue = 0;
    }
}

- (void)synchronizePanels {
    for (ChartPanelView *panel in self.chartPanels) {
        [panel updateWithData:self.chartData
                   startIndex:self.visibleStartIndex
                     endIndex:self.visibleEndIndex
                     yRangeMin:self.yRangeMin
                     yRangeMax:self.yRangeMax];
    }
}

- (BarTimeframe)chartTimeframeToBarTimeframe:(ChartTimeframe)chartTimeframe {
    switch (chartTimeframe) {
        case ChartTimeframe1Min: return BarTimeframe1Min;
        case ChartTimeframe5Min: return BarTimeframe5Min;
        case ChartTimeframe15Min: return BarTimeframe15Min;
        case ChartTimeframe30Min: return BarTimeframe30Min;
        case ChartTimeframe1Hour: return BarTimeframe1Hour;
        case ChartTimeframe4Hour: return BarTimeframe4Hour;
        case ChartTimeframeDaily: return BarTimeframe1Day;
        case ChartTimeframeWeekly: return BarTimeframe1Week;
        case ChartTimeframeMonthly: return BarTimeframe1Month;
        default: return BarTimeframe1Day;
    }
}

- (NSString *)timeframeToString:(ChartTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min: return @"1m";
        case ChartTimeframe5Min: return @"5m";
        case ChartTimeframe15Min: return @"15m";
        case ChartTimeframe30Min: return @"30m";
        case ChartTimeframe1Hour: return @"1h";
        case ChartTimeframe4Hour: return @"4h";
        case ChartTimeframeDaily: return @"1d";
        case ChartTimeframeWeekly: return @"1w";
        case ChartTimeframeMonthly: return @"1M";
        default: return @"1d";
    }
}

#pragma mark - Menu Support

- (void)appendWidgetSpecificItemsToMenu:(NSMenu *)menu {
    // Add chart-specific menu items
    NSMenuItem *separator = [NSMenuItem separatorItem];
    [menu addItem:separator];
    
    NSMenuItem *addPanelItem = [[NSMenuItem alloc] initWithTitle:@"Add Panel"
                                                          action:@selector(showAddPanelMenu:)
                                                   keyEquivalent:@""];
    addPanelItem.target = self;
    [menu addItem:addPanelItem];
    
    NSMenuItem *resetZoomItem = [[NSMenuItem alloc] initWithTitle:@"Reset Zoom"
                                                           action:@selector(zoomAll:)
                                                    keyEquivalent:@""];
    resetZoomItem.target = self;
    [menu addItem:resetZoomItem];
}

- (NSArray<NSString *> *)selectedSymbols {
    // ChartWidget doesn't have selection, return current symbol if any
    return self.currentSymbol ? @[self.currentSymbol] : @[];
}

- (NSArray<NSString *> *)contextualSymbols {
    // Return current symbol as contextual
    return self.currentSymbol ? @[self.currentSymbol] : @[];
}

- (NSString *)contextMenuTitle {
    return self.currentSymbol ?: @"Chart";
}

- (void)showAddPanelMenu:(NSMenuItem *)sender {
    // TODO: Implement panel addition menu
}



#pragma mark - State Serialization

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    if (self.currentSymbol) {
    state[@"currentSymbol"] = self.currentSymbol;
    }
    
    state[@"timeframe"] = @(self.currentTimeframe);
    state[@"barsToDownload"] = @(self.barsToDownload);
    state[@"initialBarsToShow"] = @(self.initialBarsToShow);
    state[@"visibleStartIndex"] = @(self.visibleStartIndex);
    state[@"visibleEndIndex"] = @(self.visibleEndIndex);
    state[@"isYRangeOverridden"] = @(self.isYRangeOverridden);

    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    NSString *symbol = state[@"currentSymbol"];
    if (symbol) {
        [self loadSymbol:symbol];
    }
    
    NSNumber *timeframe = state[@"timeframe"];
    if (timeframe) {
        [self setTimeframe:timeframe.integerValue];
    }
    
    NSNumber *barsToDownload = state[@"barsToDownload"];
    if (barsToDownload) {
        self.barsToDownload = barsToDownload.integerValue;
    }
    
    NSNumber *initialBarsToShow = state[@"initialBarsToShow"];
    if (initialBarsToShow) {
        self.initialBarsToShow = initialBarsToShow.integerValue;

        self.isYRangeOverridden = [state[@"isYRangeOverridden"] boolValue];
    }
}
// ======== AGGIUNGI metodi delegate per symbolTextField ========
#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *textField = [notification object];
    
    // Verifica se è il titleComboBox di BaseWidget
    if (textField == self.titleComboBox) {
        [super controlTextDidEndEditing:notification];
        return;
    }
    
    // Gestisci symbol text field
    if (textField == self.symbolTextField) {
        NSString *symbol = textField.stringValue.uppercaseString;
        if (symbol.length > 0) {
            [self loadSymbol:symbol];
            [self broadcastSymbolToChain:symbol];
        }
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)toggleAllObjectsVisibility:(NSButton *)sender {
    BOOL showObjects = (sender.state == NSControlStateValueOn);
    
    NSLog(@"🎨 Toggling objects visibility: %@", showObjects ? @"SHOW" : @"HIDE");
    
    // ✅ USA METODO PUBBLICO del renderer (più pulito)
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.objectRenderer) {
            [panel.objectRenderer setObjectsVisible:showObjects];
            
            NSLog(@"🎯 Panel %@: objects visible = %@",
                  panel.panelType, showObjects ? @"YES" : @"NO");
        }
    }
    
    // ✅ Feedback visivo sul button
    sender.title = showObjects ? @"👁️" : @"🚫";
    
    // ✅ Optional: Feedback temporaneo all'utente
    if (!showObjects) {
        // Mostra briefly che gli oggetti sono nascosti
        [self showTemporaryMessage:@"Objects hidden - focus on price action"];
    }
    
    NSLog(@"✅ Objects visibility toggle completed: %@", showObjects ? @"VISIBLE" : @"HIDDEN");
}

- (void)showTemporaryMessage:(NSString *)message {
    // Crea label temporanea che scompare dopo 2 secondi
    NSTextField *tempLabel = [[NSTextField alloc] init];
    tempLabel.stringValue = message;
    tempLabel.editable = NO;
    tempLabel.bordered = NO;
    tempLabel.backgroundColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.9];
    tempLabel.textColor = [NSColor secondaryLabelColor];
    tempLabel.font = [NSFont systemFontOfSize:11];
    tempLabel.alignment = NSTextAlignmentCenter;
    tempLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:tempLabel];
    
    // Posiziona al centro del chart
    [NSLayoutConstraint activateConstraints:@[
        [tempLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [tempLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:60],
        [tempLabel.heightAnchor constraintEqualToConstant:20]
    ]];
    
    // Scompare dopo 2 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tempLabel removeFromSuperview];
    });
}

- (BOOL)areObjectsVisible {
    return (self.objectsVisibilityToggle.state == NSControlStateValueOn);
}

- (void)setObjectsVisible:(BOOL)visible {
    self.objectsVisibilityToggle.state = visible ? NSControlStateValueOn : NSControlStateValueOff;
    [self toggleAllObjectsVisibility:self.objectsVisibilityToggle];
}

#pragma mark - Alert Management

- (void)refreshAlertsForCurrentSymbol {
    if (!self.currentSymbol) return;
    
    NSLog(@"🚨 ChartWidget: Refreshing alerts for symbol %@", self.currentSymbol);
    
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.alertRenderer) {
            [panel.alertRenderer loadAlertsForSymbol:self.currentSymbol];
        }
    }
}

#pragma mark - Chain Notifications



- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"ChartWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
    
    
    
    // ChartWidget mostra un simbolo alla volta - prendi il primo
    NSString *newSymbol = symbols.firstObject;
    if (!newSymbol || newSymbol.length == 0) return;
    
    // ✅ ENHANCED: Evita loop se è lo stesso simbolo + logging migliorato
    if ([newSymbol.uppercaseString isEqualToString:self.currentSymbol]) {
        NSLog(@"ChartWidget: Ignoring same symbol from chain: %@ (current: %@)", newSymbol, self.currentSymbol);
        return;
    }
    
    // Carica il nuovo simbolo
    [self loadSymbol:newSymbol];
    
    // ✅ NUOVO: Usa metodo BaseWidget standard per feedback
    NSString *senderType = NSStringFromClass([sender class]);
    [self showChainFeedback:[NSString stringWithFormat:@"📈 Loaded %@ from %@", newSymbol, senderType]];
    
    NSLog(@"ChartWidget: Loaded symbol '%@' from %@ chain", newSymbol, senderType);
}


- (void)showChainFeedback:(NSString *)message {
    // Trova il primo panel per mostrare il feedback
    ChartPanelView *mainPanel = [self findMainChartPanel];
    if (!mainPanel) {
        mainPanel = self.chartPanels.firstObject;
    }
    
    if (!mainPanel) {
        NSLog(@"⚠️ No chart panel available for feedback display");
        return;
    }
    
    // Crea un label temporaneo per feedback
    NSTextField *feedbackLabel = [NSTextField labelWithString:message];
    feedbackLabel.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.9];
    feedbackLabel.textColor = [NSColor controlBackgroundColor];
    feedbackLabel.font = [NSFont boldSystemFontOfSize:12];
    feedbackLabel.alignment = NSTextAlignmentCenter;
    feedbackLabel.drawsBackground = YES;
    feedbackLabel.bordered = NO;
    feedbackLabel.editable = NO;
    
    // Posiziona il feedback nell'angolo in basso a sinistra del panel
    feedbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [mainPanel addSubview:feedbackLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [feedbackLabel.bottomAnchor constraintEqualToAnchor:mainPanel.bottomAnchor constant:-15],
        [feedbackLabel.leadingAnchor constraintEqualToAnchor:mainPanel.leadingAnchor constant:15],
        [feedbackLabel.heightAnchor constraintEqualToConstant:25]
    ]];
    
    // Anima la scomparsa dopo 2.5 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.3;
            [[feedbackLabel animator] setAlphaValue:0.0];
        } completionHandler:^{
            [feedbackLabel removeFromSuperview];
        }];
    });
}

// ============================================================
// HELPER: Find Main Chart Panel
// ============================================================

- (ChartPanelView *)findMainChartPanel {
    for (ChartPanelView *panel in self.chartPanels) {
        if ([panel.panelType isEqualToString:@"security"]) {
            return panel;
        }
    }
    return nil;
}

- (void)updatePanelsWithData:(NSArray<HistoricalBarModel *> *)data {
    if (data.count == 0) return;
    
    // Calculate visible range (CODICE ESISTENTE)
    NSInteger dataCount = data.count;
    NSInteger barsToShow = MIN(100, dataCount); // Default visible bars
    
    self.visibleStartIndex = MAX(0, dataCount - barsToShow);
    self.visibleEndIndex = dataCount;
    
    // Calculate Y range if not overridden (CODICE ESISTENTE)
    
    
    // Update all panels (CODICE ESISTENTE + NUOVO)
    for (ChartPanelView *panel in self.chartPanels) {
        // Update chart data (ESISTENTE)
        [panel updateWithData:data
                   startIndex:self.visibleStartIndex
                     endIndex:self.visibleEndIndex
                    yRangeMin:self.yRangeMin
                    yRangeMax:self.yRangeMax];
        
        // 🆕 NUOVO: Alert coordinate context è già aggiornato in updateWithData
        // ma assicuriamoci che il simbolo sia aggiornato
        if (panel.alertRenderer && self.currentSymbol) {
            [panel.alertRenderer updateCoordinateContext:data
                                               startIndex:self.visibleStartIndex
                                                 endIndex:self.visibleEndIndex
                                                yRangeMin:self.yRangeMin
                                                yRangeMax:self.yRangeMax
                                                   bounds:panel.bounds
                                            currentSymbol:self.currentSymbol];
        }
    }
    
    NSLog(@"📊 Updated %lu panels with %lu data points for %@",
          (unsigned long)self.chartPanels.count, (unsigned long)data.count, self.currentSymbol);
}

// ============================================================
// NUOVO: Public Symbol Access Method
// ============================================================

- (NSString *)getCurrentSymbol {
    return self.currentSymbol;
}

#pragma mark - Current Bar Management

/**
 * Controlla se serve aggiungere la barra corrente e la aggiunge se necessario
 * @param historicalBars Array di barre storiche ricevute
 * @param symbol Simbolo per cui controllare
 * @param timeframe Timeframe utilizzato
 * @param completion Callback con l'array finale (con o senza barra corrente)
 */
- (void)checkAndAddCurrentBarIfNeeded:(NSArray<HistoricalBarModel *> *)historicalBars
                               symbol:(NSString *)symbol
                            timeframe:(BarTimeframe)timeframe
                           completion:(void(^)(NSArray<HistoricalBarModel *> *finalData))completion {
    
    // ✅ CONDIZIONE 1: Solo per timeframe daily e superiori
    if (![self isDailyOrHigherTimeframe:timeframe]) {
        NSLog(@"📊 ChartWidget: Timeframe %ld is intraday - no current bar needed", (long)timeframe);
        completion(historicalBars);
        return;
    }
    
    // ✅ CONDIZIONE 2: Controlla se l'ultima barra è di oggi
    if ([self lastBarIsToday:historicalBars]) {
        NSLog(@"📊 ChartWidget: Last bar is already today - no current bar needed");
        completion(historicalBars);
        return;
    }
    
    NSLog(@"📊 ChartWidget: Need to add current bar for %@ (timeframe: %ld)", symbol, (long)timeframe);
    
    // ✅ AZIONE: Richiedi quote corrente per costruire la barra
    [[DataHub shared] getQuoteForSymbol:symbol completion:^(MarketQuoteModel *quote, BOOL isLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (!quote) {
                NSLog(@"❌ ChartWidget: No quote available for current bar - using historical data only");
                completion(historicalBars);
                return;
            }
            
            // ✅ COSTRUZIONE: Crea la barra corrente dal quote
            HistoricalBarModel *currentBar = [self createCurrentBarFromQuote:quote timeframe:timeframe];
            
            if (!currentBar) {
                NSLog(@"❌ ChartWidget: Failed to create current bar from quote");
                completion(historicalBars);
                return;
            }
            
            // ✅ INTEGRAZIONE: Aggiungi la barra corrente ai dati storici
            NSMutableArray<HistoricalBarModel *> *finalData = [historicalBars mutableCopy];
            [finalData addObject:currentBar];
            
            NSLog(@"✅ ChartWidget: Added current bar for %@ (price: %.2f, volume: %ld)",
                  symbol, currentBar.close, (long)currentBar.volume);
            
            completion([finalData copy]);
        });
    }];
}

/**
 * Controlla se il timeframe è daily o superiore
 */
- (BOOL)isDailyOrHigherTimeframe:(BarTimeframe)timeframe {
    return (timeframe >= BarTimeframe1Day);
}

/**
 * Controlla se l'ultima barra nell'array è di oggi
 */
- (BOOL)lastBarIsToday:(NSArray<HistoricalBarModel *> *)bars {
    if (bars.count == 0) return NO;
    
    HistoricalBarModel *lastBar = bars.lastObject;
    NSDate *today = [NSDate date];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *lastBarComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                                      fromDate:lastBar.date];
    NSDateComponents *todayComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                                    fromDate:today];
    
    BOOL isToday = (lastBarComponents.year == todayComponents.year &&
                    lastBarComponents.month == todayComponents.month &&
                    lastBarComponents.day == todayComponents.day);
    
    if (isToday) {
        NSLog(@"📊 ChartWidget: Last bar (%@) is already today", lastBar.date);
    } else {
        NSLog(@"📊 ChartWidget: Last bar (%@) is not today - current bar needed", lastBar.date);
    }
    
    return isToday;
}

/**
 * Crea una barra corrente dal quote per il timeframe specificato
 */
- (HistoricalBarModel *)createCurrentBarFromQuote:(MarketQuoteModel *)quote
                                        timeframe:(BarTimeframe)timeframe {
    
    if (!quote) return nil;
    
    HistoricalBarModel *currentBar = [[HistoricalBarModel alloc] init];
    
    // ✅ DATA: Imposta la data della barra in base al timeframe
    currentBar.date = [self adjustDateForTimeframe:[NSDate date] timeframe:timeframe];
    
    // ✅ PREZZI: Costruisci i prezzi OHLC dalla quote
    // Per la barra corrente, abbiamo informazioni limitate:
    // - Close = current price
    // - Open = previous close (se disponibile) o current price
    // - High/Low = current price (approssimazione)
    
    currentBar.close = [quote.close doubleValue];
    currentBar.open = [quote.previousClose doubleValue] > 0 ? [quote.previousClose doubleValue]: [quote.close doubleValue];
    
    // Per high/low, usiamo il current price come approssimazione
    // In una implementazione più sofisticata, potremmo tenere traccia del day's high/low
    currentBar.high = MAX(currentBar.open, currentBar.close);
    currentBar.low = MIN(currentBar.open, currentBar.close);
    
    // ✅ VOLUME: Usa il volume corrente (se disponibile)
    currentBar.volume = quote.volume;
    
    NSLog(@"📊 ChartWidget: Created current bar - O:%.2f H:%.2f L:%.2f C:%.2f V:%ld",
          currentBar.open, currentBar.high, currentBar.low, currentBar.close, (long)currentBar.volume);
    
    return currentBar;
}

/**
 * Aggiusta la data per il timeframe specificato
 * Per weekly: va al lunedì della settimana corrente
 * Per monthly: va al primo del mese corrente
 */
- (NSDate *)adjustDateForTimeframe:(NSDate *)date timeframe:(BarTimeframe)timeframe {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    switch (timeframe) {
        case BarTimeframe1Day:
            // Per daily, usa la data così com'è
            return date;
            
        case BarTimeframe1Week: {
            // Per weekly, vai al lunedì della settimana corrente
            NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitWeekOfYear
                                                       fromDate:date];
            components.weekday = 2; // Lunedì
            return [calendar dateFromComponents:components];
        }
            
        case BarTimeframe1Month: {
            // Per monthly, vai al primo del mese corrente
            NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth
                                                       fromDate:date];
            components.day = 1;
            return [calendar dateFromComponents:components];
        }
            
        default:
            return date;
    }
}

@end
