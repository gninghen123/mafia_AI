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
    _maxBarsToDisplay = 200;
    _isLoading = NO;
    
    // Initialize collections
    _panelModels = [NSMutableArray array];
    _panelViews = [NSMutableArray array];
    
    // Create coordinator
    _coordinator = [[ChartCoordinator alloc] init];
    _coordinator.maxVisibleBars = _maxBarsToDisplay;
    
    // Initialize indicators panel controller
    _indicatorsPanelController = [[IndicatorsPanelController alloc] initWithChartWidget:self];
    
    NSLog(@"📊 ChartWidget: Initialized with symbol %@", _currentSymbol);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.refreshTimer invalidate];
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
    
    [self createToolbar];
    [self createChartArea];
    [self setupConstraints];
    [self createMainPanel];
    
    // Load initial data
    [self loadHistoricalDataForSymbol:self.currentSymbol];
    
    NSLog(@"✅ ChartWidget: Content view setup complete");
}

#pragma mark - UI Setup Methods

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
    self.refreshButton.title = @"↻";
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
    
    // Stack view for panels (vertical layout)
    self.panelsStackView = [[NSStackView alloc] init];
    self.panelsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.panelsStackView.spacing = 2;
    self.panelsStackView.distribution = NSStackViewDistributionFillProportionally;
    self.panelsStackView.alignment = NSLayoutAttributeLeading;
    
    // Set stack view as document view
    self.chartScrollView.documentView = self.panelsStackView;
    
    NSLog(@"✅ ChartWidget: Chart area created");
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar constraints
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:40],
        
        // Chart scroll view constraints
        [self.chartScrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor constant:8],
        [self.chartScrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.chartScrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.chartScrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        // Stack view constraints
        [self.panelsStackView.topAnchor constraintEqualToAnchor:self.chartScrollView.topAnchor],
        [self.panelsStackView.leadingAnchor constraintEqualToAnchor:self.chartScrollView.leadingAnchor],
        [self.panelsStackView.trailingAnchor constraintEqualToAnchor:self.chartScrollView.trailingAnchor],
        [self.panelsStackView.bottomAnchor constraintEqualToAnchor:self.chartScrollView.bottomAnchor],
        [self.panelsStackView.widthAnchor constraintEqualToAnchor:self.chartScrollView.widthAnchor],
        [self.panelsStackView.heightAnchor constraintGreaterThanOrEqualToConstant:400]
    ]];
    
    // Toolbar elements constraints
    [NSLayoutConstraint activateConstraints:@[
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
    
    NSLog(@"✅ ChartWidget: Constraints setup complete");
}

#pragma mark - Panel Management

- (void)createMainPanel {
    // Create main security panel
    ChartPanelModel *mainPanel = [self createMainSecurityPanel];
    [self addPanelWithModel:mainPanel];
    
    NSLog(@"✅ ChartWidget: Main panel created");
}

- (ChartPanelModel *)createMainSecurityPanel {
    ChartPanelModel *panel = [ChartPanelModel mainPanelWithTitle:@"Security"];
    
    // Add candlestick renderer
    CandlestickRenderer *candlestickRenderer = [[CandlestickRenderer alloc] init];
    [panel addIndicator:candlestickRenderer];
    
    return panel;
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
    [self.panelsStackView addArrangedSubview:panelView];
    
    // Set height constraint based on panel type
    CGFloat height = (panelModel.panelType == ChartPanelTypeMain) ? 400 : 150;
    NSLayoutConstraint *heightConstraint = [panelView.heightAnchor constraintEqualToConstant:height];
    heightConstraint.priority = NSLayoutPriorityDefaultHigh;
    heightConstraint.active = YES;
    
    NSLog(@"📊 ChartWidget: Added panel '%@' (height: %.0f)", panelModel.title, height);
}

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
    
    // Remove from UI
    [self.panelsStackView removeArrangedSubview:panelView];
    [panelView removeFromSuperview];
    
    NSLog(@"🗑️ ChartWidget: Removed panel '%@'", panelModel.title);
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
    for (ChartPanelView *panelView in self.panelViews) {
        [panelView refreshDisplay];
    }
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
    
    // Update coordinator with new data
    [self.coordinator updateHistoricalData:data];
    
    // Update all panel views
    for (ChartPanelView *panelView in self.panelViews) {
        [panelView updateWithHistoricalData:data];
    }
    
    NSLog(@"📊 ChartWidget: Updated %lu panels with %lu data points",
          (unsigned long)self.panelViews.count, (unsigned long)data.count);
}

#pragma mark - Actions

- (IBAction)symbolChanged:(id)sender {
    NSString *newSymbol = self.symbolComboBox.stringValue.uppercaseString;
    if (![newSymbol isEqualToString:self.currentSymbol] && newSymbol.length > 0) {
        self.currentSymbol = newSymbol;
        [self loadHistoricalDataForSymbol:newSymbol];
        NSLog(@"📊 ChartWidget: Symbol changed to %@", newSymbol);
    }
}

- (IBAction)timeframeChanged:(id)sender {
    NSInteger newTimeframe = self.timeframeControl.selectedSegment;
    if (newTimeframe != self.selectedTimeframe) {
        self.selectedTimeframe = newTimeframe;
        [self loadHistoricalDataForSymbol:self.currentSymbol];
        NSLog(@"📊 ChartWidget: Timeframe changed to %ld", (long)newTimeframe);
    }
}

- (IBAction)refreshButtonClicked:(id)sender {
    [self refreshCurrentData];
}

- (IBAction)indicatorsButtonClicked:(id)sender {
    [self.indicatorsPanelController togglePanel];
    
    // Update button appearance based on panel visibility
    if (self.indicatorsPanelController.isVisible) {
        self.indicatorsButton.title = @"INDICATORS ▶";
        self.indicatorsButton.contentTintColor = [NSColor controlAccentColor];
    } else {
        self.indicatorsButton.title = @"INDICATORS";
        self.indicatorsButton.contentTintColor = nil;
    }
    
    NSLog(@"📊 ChartWidget: Indicators panel %@",
          self.indicatorsPanelController.isVisible ? @"shown" : @"hidden");
    
    // Also add demo volume panel if none exists (for testing)
    if (self.indicatorsPanelController.isVisible) {
        [self addDemoVolumePanelIfNeeded];
    }
}

- (void)addDemoVolumePanelIfNeeded {
    // Check if volume panel already exists
    for (ChartPanelModel *panel in self.panelModels) {
        if ([panel hasIndicatorOfType:@"Volume"]) {
            return; // Already exists
        }
    }
    
    // Create volume panel for demo
    ChartPanelModel *volumePanel = [ChartPanelModel secondaryPanelWithTitle:@"Volume"];
    VolumeRenderer *volumeRenderer = [[VolumeRenderer alloc] init];
    [volumePanel addIndicator:volumeRenderer];
    
    [self addPanelWithModel:volumePanel];
    NSLog(@"📊 ChartWidget: Added demo volume panel");
}

#pragma mark - Notifications

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(historicalDataUpdated:)
               name:@"DataHubHistoricalDataUpdatedNotification"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(quoteUpdated:)
               name:@"DataHubQuoteUpdatedNotification"
             object:nil];
}

- (void)historicalDataUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    if ([symbol isEqualToString:self.currentSymbol]) {
        NSArray<HistoricalBarModel *> *data = notification.userInfo[@"data"];
        [self updateAllPanelsWithData:data];
    }
}

- (void)quoteUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    if ([symbol isEqualToString:self.currentSymbol]) {
        [self refreshAllPanels];
    }
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


@end
