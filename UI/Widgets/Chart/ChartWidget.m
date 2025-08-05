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

// Define constants locally instead of importing
static NSString *const kWidgetChainUpdateNotification = @"WidgetChainUpdateNotification";
static NSString *const kChainUpdateKey = @"update";
static NSString *const kChainSenderKey = @"sender";

// Import DataHub constants
extern NSString *const DataHubDataLoadedNotification;

@interface ChartWidget () <NSTextFieldDelegate>

// Internal data
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *chartData;

// Interaction state
@property (nonatomic, assign) BOOL isInPanMode;
@property (nonatomic, assign) BOOL isInSelectionMode;
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

// ======== AGGIUNGI setupUI ========
- (void)setupUI {
    // Toolbar superiore (simbolo, timeframe, etc.)
    [self setupTopToolbar];
    
    // SplitView principale per i pannelli chart
    [self setupMainSplitView];
    
    // Controlli zoom inferiori
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

// ======== AGGIUNGI setupConstraints ========
- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Top toolbar - Symbol field (top-left)
        [self.symbolTextField.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.symbolTextField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.symbolTextField.widthAnchor constraintEqualToConstant:100],
        [self.symbolTextField.heightAnchor constraintEqualToConstant:21],
        
        // Timeframe segmented control (dopo symbol field)
        [self.timeframeSegmented.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.timeframeSegmented.leadingAnchor constraintEqualToAnchor:self.symbolTextField.trailingAnchor constant:24],
        
        // Bars count field (dopo timeframe)
        [self.barsCountTextField.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.barsCountTextField.leadingAnchor constraintEqualToAnchor:self.timeframeSegmented.trailingAnchor constant:8],
        [self.barsCountTextField.widthAnchor constraintEqualToConstant:60],
        
        // Template popup (dopo bars count)
        [self.templatePopup.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.templatePopup.leadingAnchor constraintEqualToAnchor:self.barsCountTextField.trailingAnchor constant:8],
        [self.templatePopup.widthAnchor constraintEqualToConstant:80],
        
        // Preferences button (ALL'ESTREMO DESTRO)
        [self.preferencesButton.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.preferencesButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.preferencesButton.widthAnchor constraintEqualToConstant:30],
        [self.preferencesButton.heightAnchor constraintEqualToConstant:21],
        
        // Main split view (centro - area principale)
        [self.panelsSplitView.topAnchor constraintEqualToAnchor:self.symbolTextField.bottomAnchor constant:8],
        [self.panelsSplitView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
        [self.panelsSplitView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.panelsSplitView.bottomAnchor constraintEqualToAnchor:self.panSlider.topAnchor constant:-8],
        
        // Bottom controls - Pan slider (DA BORDO SINISTRO A ZOOM OUT)
        [self.panSlider.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
        [self.panSlider.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.panSlider.trailingAnchor constraintEqualToAnchor:self.zoomOutButton.leadingAnchor constant:-8],
        [self.panSlider.heightAnchor constraintEqualToConstant:20],
        
        // Zoom out button (A DESTRA DEL SLIDER)
        [self.zoomOutButton.centerYAnchor constraintEqualToAnchor:self.panSlider.centerYAnchor],
        [self.zoomOutButton.trailingAnchor constraintEqualToAnchor:self.zoomInButton.leadingAnchor constant:-6],
        [self.zoomOutButton.widthAnchor constraintEqualToConstant:30],
        
        // Zoom in button (A DESTRA DI ZOOM OUT)
        [self.zoomInButton.centerYAnchor constraintEqualToAnchor:self.panSlider.centerYAnchor],
        [self.zoomInButton.trailingAnchor constraintEqualToAnchor:self.zoomAllButton.leadingAnchor constant:-6],
        [self.zoomInButton.widthAnchor constraintEqualToConstant:30],
        
        // Zoom all button (ALL'ESTREMO DESTRO)
        [self.zoomAllButton.centerYAnchor constraintEqualToAnchor:self.panSlider.centerYAnchor],
        [self.zoomAllButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.zoomAllButton.widthAnchor constraintEqualToConstant:40]
    ]];
}


- (void)setupChartDefaults {
    _currentTimeframe = ChartTimeframeDaily;
    _barsToDownload = 1000;
    _initialBarsToShow = 250;
    _chartPanels = [NSMutableArray array];
    _visibleStartIndex = 0;
    _visibleEndIndex = 250;
    _isYRangeOverridden = NO;
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
    
    // Ora setup panels DOPO che la UI è stata creata
    [self setupDefaultPanels];
}

- (void)setupDefaultPanels {
    NSLog(@"🔧 Setting up default panels...");
    NSLog(@"🔍 Split view: %@", self.panelsSplitView);
    NSLog(@"🔍 Split view frame before setup: %@", NSStringFromRect(self.panelsSplitView.frame));
    NSLog(@"🔍 Split view subviews before: %@", self.panelsSplitView.subviews);
    
    // Remove any existing panels
    [self.chartPanels removeAllObjects];
    
    // Clear existing subviews from split view
    for (NSView *subview in [self.panelsSplitView.subviews copy]) {
        [subview removeFromSuperview];  // ✅ Correct method for removing from split view
    }
    
    NSLog(@"🔍 Split view subviews after clear: %@", self.panelsSplitView.subviews);
    
    // Add Security panel (candlestick)
    ChartPanelView *securityPanel = [[ChartPanelView alloc] initWithType:@"security"];
    securityPanel.chartWidget = self;
    securityPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartPanels addObject:securityPanel];
    [self.panelsSplitView addSubview:securityPanel];
    
    // 🎯 CRITICAL: Give security panel a minimum height to prevent collapse
    //[securityPanel.heightAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
    
    NSLog(@"✅ Added security panel: %@", securityPanel);
    NSLog(@"🔍 Security panel frame: %@", NSStringFromRect(securityPanel.frame));
    
    // Add Volume panel (histogram)
    ChartPanelView *volumePanel = [[ChartPanelView alloc] initWithType:@"volume"];
    volumePanel.chartWidget = self;
    volumePanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartPanels addObject:volumePanel];
    [self.panelsSplitView addSubview:volumePanel];
    
    // 🎯 CRITICAL: Give volume panel a minimum height to prevent collapse
  //  [volumePanel.heightAnchor constraintGreaterThanOrEqualToConstant:50].active = YES;
    
    NSLog(@"✅ Added volume panel: %@", volumePanel);
    NSLog(@"🔍 Volume panel frame: %@", NSStringFromRect(volumePanel.frame));
    NSLog(@"🔍 Split view subviews final: %@", self.panelsSplitView.subviews);
    NSLog(@"🔍 Split view frame after setup: %@", NSStringFromRect(self.panelsSplitView.frame));
    
    // 🚀 CRITICAL: Force split view to have minimum height
    [self.panelsSplitView.heightAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
    
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
    if (symbol.length > 0) {
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
            
            self.chartData = data;
            [self resetToInitialView];
            [self synchronizePanels];
        });
    }];
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

@end
