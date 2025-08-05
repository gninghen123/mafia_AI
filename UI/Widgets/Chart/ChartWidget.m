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
    
    NSLog(@"🔧 ChartWidget: Starting XIB setup...");
    NSLog(@"🔍 contentView frame before XIB: %@", NSStringFromRect(self.contentView.frame));
    NSLog(@"🔍 contentView constraints: %@", self.contentView.constraints);
    
    // Remove BaseWidget's placeholder
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Load XIB content
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *topLevelObjects = nil;
    
    if ([bundle loadNibNamed:@"ChartWidget" owner:self topLevelObjects:&topLevelObjects]) {
        NSLog(@"✅ ChartWidget: XIB loaded successfully");
        NSLog(@"🔍 XIB view: %@", self.view);
        NSLog(@"🔍 XIB view frame: %@", NSStringFromRect(self.view.frame));
        
        // Add the XIB content to our content view
        if (self.view) {
            [self.contentView addSubview:self.view];
            self.view.translatesAutoresizingMaskIntoConstraints = NO;
            
            // 🎯 CRITICAL: Make sure XIB content fills the entire contentView
            [NSLayoutConstraint activateConstraints:@[
                [self.view.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
                [self.view.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
                [self.view.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
                [self.view.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
            ]];
            
            NSLog(@"✅ ChartWidget: XIB content anchored to fill contentView");
        }
        
        [self setupInitialUI];
        
        // 🚀 TIMING FIX: Setup panels AFTER layout is complete
        NSLog(@"⏰ ChartWidget: Deferring panel setup until after layout...");
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"🎯 ChartWidget: Layout should be complete now, setting up panels...");
            NSLog(@"🔍 contentView frame after layout: %@", NSStringFromRect(self.contentView.frame));
            NSLog(@"🔍 XIB view frame after layout: %@", NSStringFromRect(self.view.frame));
            [self setupDefaultPanels];
        });
        
    } else {
        NSLog(@"❌ Failed to load ChartWidget.xib");
    }
    
    NSLog(@"🎯 ChartWidget: setupContentView completed - panels will be setup after layout");
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
    // Setup text field delegates
    self.symbolTextField.delegate = self;
    self.barsCountTextField.stringValue = @"1000";
    
    // Setup timeframe segmented control
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
    
    // Setup template popup
    [self.templatePopup removeAllItems];
    [self.templatePopup addItemsWithTitles:@[@"Default", @"Technical", @"Volume Analysis", @"Custom"]];
    
    // Setup zoom controls
    self.panSlider.minValue = 0;
    self.panSlider.maxValue = 100;
    self.panSlider.integerValue = 50;
    
    // Connect actions - CRITICAL: These must be set!
    [self.symbolTextField setTarget:self];
    [self.symbolTextField setAction:@selector(symbolChanged:)];
    
    [self.timeframeSegmented setTarget:self];
    [self.timeframeSegmented setAction:@selector(timeframeChanged:)];
    
    [self.zoomOutButton setTarget:self];
    [self.zoomOutButton setAction:@selector(zoomOut:)];
    
    [self.zoomInButton setTarget:self];
    [self.zoomInButton setAction:@selector(zoomIn:)];
    
    [self.zoomAllButton setTarget:self];
    [self.zoomAllButton setAction:@selector(zoomAll:)];
    
    [self.panSlider setTarget:self];
    [self.panSlider setAction:@selector(panSliderChanged:)];
    
    NSLog(@"✅ ChartWidget: UI setup completed with actions connected");
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

- (void)zoomOut:(NSButton *)sender {
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger newRange = MIN(currentRange * 1.5, self.chartData.count);
    NSInteger center = (self.visibleStartIndex + self.visibleEndIndex) / 2;
    
    [self zoomToRange:MAX(0, center - newRange/2)
             endIndex:MIN(self.chartData.count - 1, center + newRange/2)];
}

- (void)zoomIn:(NSButton *)sender {
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger newRange = MAX(10, currentRange / 1.5);
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
    if (!self.chartData || self.chartData.count == 0) return;
    
    // Clamp to valid range
    startIndex = MAX(0, MIN(startIndex, self.chartData.count - 1));
    endIndex = MAX(startIndex + 1, MIN(endIndex, self.chartData.count - 1));
    
    self.visibleStartIndex = startIndex;
    self.visibleEndIndex = endIndex;
    
    [self updatePanSlider];
    [self calculateYRange];
    [self synchronizePanels];
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

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
