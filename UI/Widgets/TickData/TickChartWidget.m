
//
//  TickChartWidget.m
//  mafia_AI
//

#import "TickChartWidget.h"
#import "DataHub+TickData.h"
#import <Cocoa/Cocoa.h>

@interface TickChartWidget ()

// UI Components
@property (nonatomic, strong) NSView *controlsView;
@property (nonatomic, strong) NSComboBox *symbolComboBox;
@property (nonatomic, strong) NSButton *realTimeButton;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSSlider *limitSlider;
@property (nonatomic, strong) NSTextField *limitLabel;

// Chart and data views
@property (nonatomic, strong) NSScrollView *tickTableScrollView;
@property (nonatomic, strong) NSTableView *tickTableView;
@property (nonatomic, strong) NSView *chartView;
@property (nonatomic, strong) NSView *statsView;

// Statistics labels
@property (nonatomic, strong) NSTextField *volumeDeltaLabel;
@property (nonatomic, strong) NSTextField *vwapLabel;
@property (nonatomic, strong) NSTextField *buyVolumeLabel;
@property (nonatomic, strong) NSTextField *sellVolumeLabel;
@property (nonatomic, strong) NSTextField *tickCountLabel;

// Data
@property (nonatomic, strong) NSMutableArray<TickDataModel *> *tickDataInternal;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;
@property (nonatomic, strong) NSTextField *statusLabel;

// State
@property (nonatomic) BOOL isLoading;

@end

@implementation TickChartWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)widgetType panelType:(PanelType)panelType {
    self = [super initWithType:widgetType panelType:panelType];
    if (self) {
        [self setupTickChartWidget];
    }
    return self;
}

- (void)setupTickChartWidget {
    // Default configuration
    _tickLimit = 500;           // Default to last 500 trades
    _volumeThreshold = 10000;   // 10K+ shares considered significant
    _realTimeUpdates = NO;      // Start with manual updates
    _tickDataInternal = [NSMutableArray array];
    _isLoading = NO;
    
    // Register for DataHub notifications
    [self registerForNotifications];
}

- (void)setupContentView {
    [super setupContentView];
    
    // Setup UI in order
    [self setupControls];
    [self setupStatsView];
    [self setupTickTable];
    [self setupChartView];
    [self setupLayout];
}

#pragma mark - UI Setup

- (void)setupControls {
    // Controls container
    self.controlsView = [[NSView alloc] init];
    self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.controlsView];
    
    // Symbol combo box
    self.symbolComboBox = [[NSComboBox alloc] init];
    self.symbolComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolComboBox.placeholderString = @"Enter symbol (e.g., AAPL)";
    self.symbolComboBox.target = self;
    self.symbolComboBox.action = @selector(symbolChanged:);
    [self.controlsView addSubview:self.symbolComboBox];
    
    // Populate with common symbols
    [self.symbolComboBox addItemsWithObjectValues:@[
        @"AAPL", @"MSFT", @"GOOGL", @"AMZN", @"TSLA", @"META", @"NVDA", @"NFLX",
        @"SPY", @"QQQ", @"IWM", @"VIX"
    ]];
    
    // Real-time toggle button
    self.realTimeButton = [[NSButton alloc] init];
    self.realTimeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.realTimeButton setButtonType:NSButtonTypeToggle];
    self.realTimeButton.title = @"Real-Time";
    self.realTimeButton.target = self;
    self.realTimeButton.action = @selector(realTimeToggled:);
    [self.controlsView addSubview:self.realTimeButton];
    
    // Refresh button
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.refreshButton.title = @"Refresh";
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshData);
    [self.controlsView addSubview:self.refreshButton];
    
    // Tick limit slider
    self.limitSlider = [[NSSlider alloc] init];
    self.limitSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.limitSlider.minValue = 50;
    self.limitSlider.maxValue = 2000;
    self.limitSlider.integerValue = self.tickLimit;
    self.limitSlider.target = self;
    self.limitSlider.action = @selector(limitChanged:);
    [self.controlsView addSubview:self.limitSlider];
    
    // Limit label
    self.limitLabel = [[NSTextField alloc] init];
    self.limitLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.limitLabel.stringValue = [NSString stringWithFormat:@"Limit: %ld", (long)self.tickLimit];
    self.limitLabel.editable = NO;
    self.limitLabel.bordered = NO;
    self.limitLabel.backgroundColor = [NSColor clearColor];
    [self.controlsView addSubview:self.limitLabel];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.hidden = YES;
    [self.controlsView addSubview:self.loadingIndicator];
    
    // Status label
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.stringValue = @"Enter a symbol to start";
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [self.controlsView addSubview:self.statusLabel];
}

- (void)setupStatsView {
    // Stats container
    self.statsView = [[NSView alloc] init];
    self.statsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.statsView];
    
    // Volume Delta
    self.volumeDeltaLabel = [self createStatLabel:@"Volume Δ: --"];
    [self.statsView addSubview:self.volumeDeltaLabel];
    
    // VWAP
    self.vwapLabel = [self createStatLabel:@"VWAP: --"];
    [self.statsView addSubview:self.vwapLabel];
    
    // Buy Volume
    self.buyVolumeLabel = [self createStatLabel:@"Buy Vol: --"];
    [self.statsView addSubview:self.buyVolumeLabel];
    
    // Sell Volume
    self.sellVolumeLabel = [self createStatLabel:@"Sell Vol: --"];
    [self.statsView addSubview:self.sellVolumeLabel];
    
    // Tick Count
    self.tickCountLabel = [self createStatLabel:@"Ticks: --"];
    [self.statsView addSubview:self.tickCountLabel];
}

- (void)setupTickTable {
    // Table view for tick data
    self.tickTableView = [[NSTableView alloc] init];
    self.tickTableView.dataSource = self;
    self.tickTableView.delegate = self;
    self.tickTableView.headerView = nil;
    self.tickTableView.rowSizeStyle = NSTableViewRowSizeStyleSmall;  // Fixed: use NSTableViewRowSizeStyleSmall
    
    // Add columns
    [self addTableColumn:@"Time" identifier:@"time" width:60];
    [self addTableColumn:@"Price" identifier:@"price" width:60];
    [self addTableColumn:@"Volume" identifier:@"volume" width:60];
    [self addTableColumn:@"Dir" identifier:@"direction" width:30];
    [self addTableColumn:@"Exchange" identifier:@"exchange" width:40];
    
    // Scroll view
    self.tickTableScrollView = [[NSScrollView alloc] init];
    self.tickTableScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tickTableScrollView.documentView = self.tickTableView;
    self.tickTableScrollView.hasVerticalScroller = YES;
    self.tickTableScrollView.hasHorizontalScroller = NO;
    [self.contentView addSubview:self.tickTableScrollView];
}

- (void)setupChartView {
    // Simple chart view (placeholder for now)
    self.chartView = [[NSView alloc] init];
    self.chartView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chartView.wantsLayer = YES;
    self.chartView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.chartView.layer.borderColor = [NSColor separatorColor].CGColor;
    self.chartView.layer.borderWidth = 1.0;
    self.chartView.layer.cornerRadius = 4.0;
    [self.contentView addSubview:self.chartView];
}

- (void)setupLayout {
    // Controls view constraints (top)
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.controlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.controlsView.heightAnchor constraintEqualToConstant:60]
    ]];
    
    // Stats view constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.statsView.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:8],
        [self.statsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.statsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.statsView.heightAnchor constraintEqualToConstant:40]
    ]];
    
    // Tick table constraints (left side)
    [NSLayoutConstraint activateConstraints:@[
        [self.tickTableScrollView.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:8],
        [self.tickTableScrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.tickTableScrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.tickTableScrollView.widthAnchor constraintEqualToConstant:250]
    ]];
    
    // Chart view constraints (right side)
    [NSLayoutConstraint activateConstraints:@[
        [self.chartView.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:8],
        [self.chartView.leadingAnchor constraintEqualToAnchor:self.tickTableScrollView.trailingAnchor constant:8],
        [self.chartView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.chartView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];
    
    // Controls layout
    [self setupControlsLayout];
    [self setupStatsLayout];
}

- (void)setupControlsLayout {
    [NSLayoutConstraint activateConstraints:@[
        // Symbol combo box
        [self.symbolComboBox.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor],
        [self.symbolComboBox.topAnchor constraintEqualToAnchor:self.controlsView.topAnchor constant:8],
        [self.symbolComboBox.widthAnchor constraintEqualToConstant:100],
        
        // Real-time button
        [self.realTimeButton.leadingAnchor constraintEqualToAnchor:self.symbolComboBox.trailingAnchor constant:8],
        [self.realTimeButton.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor],
        
        // Refresh button
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.realTimeButton.trailingAnchor constant:8],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor],
        
        // Loading indicator
        [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.refreshButton.trailingAnchor constant:8],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor],
        
        // Limit slider
        [self.limitSlider.leadingAnchor constraintEqualToAnchor:self.symbolComboBox.leadingAnchor],
        [self.limitSlider.topAnchor constraintEqualToAnchor:self.symbolComboBox.bottomAnchor constant:8],
        [self.limitSlider.widthAnchor constraintEqualToConstant:120],
        
        // Limit label
        [self.limitLabel.leadingAnchor constraintEqualToAnchor:self.limitSlider.trailingAnchor constant:8],
        [self.limitLabel.centerYAnchor constraintEqualToAnchor:self.limitSlider.centerYAnchor],
        
        // Status label
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.controlsView.trailingAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor]
    ]];
}

- (void)setupStatsLayout {
    CGFloat labelWidth = 80;
    
    [NSLayoutConstraint activateConstraints:@[
        // Volume Delta
        [self.volumeDeltaLabel.leadingAnchor constraintEqualToAnchor:self.statsView.leadingAnchor],
        [self.volumeDeltaLabel.centerYAnchor constraintEqualToAnchor:self.statsView.centerYAnchor],
        [self.volumeDeltaLabel.widthAnchor constraintEqualToConstant:labelWidth],
        
        // VWAP
        [self.vwapLabel.leadingAnchor constraintEqualToAnchor:self.volumeDeltaLabel.trailingAnchor constant:8],
        [self.vwapLabel.centerYAnchor constraintEqualToAnchor:self.statsView.centerYAnchor],
        [self.vwapLabel.widthAnchor constraintEqualToConstant:labelWidth],
        
        // Buy Volume
        [self.buyVolumeLabel.leadingAnchor constraintEqualToAnchor:self.vwapLabel.trailingAnchor constant:8],
        [self.buyVolumeLabel.centerYAnchor constraintEqualToAnchor:self.statsView.centerYAnchor],
        [self.buyVolumeLabel.widthAnchor constraintEqualToConstant:labelWidth],
        
        // Sell Volume
        [self.sellVolumeLabel.leadingAnchor constraintEqualToAnchor:self.buyVolumeLabel.trailingAnchor constant:8],
        [self.sellVolumeLabel.centerYAnchor constraintEqualToAnchor:self.statsView.centerYAnchor],
        [self.sellVolumeLabel.widthAnchor constraintEqualToConstant:labelWidth],
        
        // Tick Count
        [self.tickCountLabel.leadingAnchor constraintEqualToAnchor:self.sellVolumeLabel.trailingAnchor constant:8],
        [self.tickCountLabel.centerYAnchor constraintEqualToAnchor:self.statsView.centerYAnchor],
        [self.tickCountLabel.widthAnchor constraintEqualToConstant:labelWidth]
    ]];
}

#pragma mark - Helper Methods

- (NSTextField *)createStatLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    return label;
}

- (void)addTableColumn:(NSString *)title identifier:(NSString *)identifier width:(CGFloat)width {
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier];
    column.title = title;
    column.width = width;
    column.minWidth = width;
    column.maxWidth = width;
    [self.tickTableView addTableColumn:column];
}

#pragma mark - Public Methods

- (void)setSymbol:(NSString *)symbol {
    if ([symbol isEqualToString:self.currentSymbol]) return;
    
    _currentSymbol = symbol.uppercaseString;
    self.symbolComboBox.stringValue = _currentSymbol;
    
    // Clear existing data
    [self.tickDataInternal removeAllObjects];
    [self.tickTableView reloadData];
    [self updateStatistics];
    
    // Load new data
    [self refreshData];
    
    NSLog(@"TickChartWidget: Symbol changed to %@", _currentSymbol);
}

- (NSArray<TickDataModel *> *)tickData {
    return [self.tickDataInternal copy];
}

- (void)refreshData {
    if (!self.currentSymbol || self.currentSymbol.length == 0) {
        self.statusLabel.stringValue = @"Enter a symbol to start";
        return;
    }
    
    if (self.isLoading) {
        NSLog(@"TickChartWidget: Already loading data, skipping refresh");
        return;
    }
    
    [self showLoadingState];
    
    NSLog(@"TickChartWidget: Refreshing tick data for %@ (limit: %ld)", self.currentSymbol, (long)self.tickLimit);
    
    [[DataHub shared] getTickDataForSymbol:self.currentSymbol  // Fixed: use [DataHub shared]
                                             limit:self.tickLimit
                                          fromTime:@"9:30"
                                        completion:^(NSArray<TickDataModel *> *ticks, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoadingState];
            
            if (!ticks || ticks.count == 0) {
                self.statusLabel.stringValue = [NSString stringWithFormat:@"No tick data for %@", self.currentSymbol];
                return;
            }
            
            // Update data
            [self.tickDataInternal removeAllObjects];
            [self.tickDataInternal addObjectsFromArray:ticks];
            
            // Refresh UI
            [self.tickTableView reloadData];
            [self updateStatistics];
            [self scrollToBottomOfTable];
            
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Loaded %lu ticks (%@)",
                                           (unsigned long)ticks.count,
                                           isFresh ? @"fresh" : @"cached"];
            
            NSLog(@"TickChartWidget: Successfully loaded %lu ticks for %@", (unsigned long)ticks.count, self.currentSymbol);
        });
    }];
}

- (void)startRealTimeUpdates {
    if (!self.currentSymbol) return;
    
    self.realTimeUpdates = YES;
    self.realTimeButton.state = NSControlStateValueOn;
    
    [[DataHub shared] startTickStreamForSymbol:self.currentSymbol];  // Fixed: use [DataHub shared]
    
    NSLog(@"TickChartWidget: Started real-time updates for %@", self.currentSymbol);
}

- (void)stopRealTimeUpdates {
    self.realTimeUpdates = NO;
    self.realTimeButton.state = NSControlStateValueOff;
    
    if (self.currentSymbol) {
        [[DataHub shared] stopTickStreamForSymbol:self.currentSymbol];  // Fixed: use [DataHub shared]
    }
    
    NSLog(@"TickChartWidget: Stopped real-time updates");
}

- (NSArray *)exportTickData {
    NSMutableArray *exportData = [NSMutableArray array];
    
    for (TickDataModel *tick in self.tickDataInternal) {
        NSDictionary *tickDict = @{
            @"symbol": tick.symbol ?: @"",
            @"timestamp": tick.timestamp ?: [NSDate date],
            @"price": @(tick.price),
            @"volume": @(tick.volume),
            @"direction": @(tick.direction),
            @"exchange": tick.exchange ?: @"",
            @"session": [tick sessionString]
        };
        [exportData addObject:tickDict];
    }
    
    return [exportData copy];
}

#pragma mark - Actions

- (void)symbolChanged:(id)sender {
    NSString *symbol = self.symbolComboBox.stringValue.uppercaseString;
    if (symbol.length > 0) {
        [self setSymbol:symbol];
    }
}

- (void)realTimeToggled:(id)sender {
    if (self.realTimeButton.state == NSControlStateValueOn) {
        [self startRealTimeUpdates];
    } else {
        [self stopRealTimeUpdates];
    }
}

- (void)limitChanged:(id)sender {
    self.tickLimit = self.limitSlider.integerValue;
    self.limitLabel.stringValue = [NSString stringWithFormat:@"Limit: %ld", (long)self.tickLimit];
    
    // Refresh data with new limit
    if (self.currentSymbol) {
        [self refreshData];
    }
}

#pragma mark - Data Analysis

- (double)cumulativeVolumeDelta {
    return [[DataHub shared] calculateVolumeDeltaForTicks:self.tickDataInternal];  // Fixed: use [DataHub shared]
}

- (double)currentVWAP {
    return [[DataHub shared] calculateVWAPForTicks:self.tickDataInternal];  // Fixed: use [DataHub shared]
}

- (NSDictionary *)volumeBreakdown {
    return [[DataHub shared] calculateVolumeBreakdownForTicks:self.tickDataInternal];  // Fixed: use [DataHub shared]
}

- (void)updateStatistics {
    if (self.tickDataInternal.count == 0) {
        self.volumeDeltaLabel.stringValue = @"Volume Δ: --";
        self.vwapLabel.stringValue = @"VWAP: --";
        self.buyVolumeLabel.stringValue = @"Buy Vol: --";
        self.sellVolumeLabel.stringValue = @"Sell Vol: --";
        self.tickCountLabel.stringValue = @"Ticks: --";
        return;
    }
    
    // Calculate statistics
    double volumeDelta = [self cumulativeVolumeDelta];
    double vwap = [self currentVWAP];
    NSDictionary *breakdown = [self volumeBreakdown];
    
    // Format and display
    self.volumeDeltaLabel.stringValue = [NSString stringWithFormat:@"Volume Δ: %@", [self formatVolume:volumeDelta]];
    self.volumeDeltaLabel.textColor = volumeDelta > 0 ? [NSColor systemGreenColor] : [NSColor systemRedColor];
    
    self.vwapLabel.stringValue = [NSString stringWithFormat:@"VWAP: %.2f", vwap];
    
    double buyVol = [breakdown[@"buyVolume"] doubleValue];
    double sellVol = [breakdown[@"sellVolume"] doubleValue];
    
    self.buyVolumeLabel.stringValue = [NSString stringWithFormat:@"Buy: %@", [self formatVolume:buyVol]];
    self.buyVolumeLabel.textColor = [NSColor systemGreenColor];
    
    self.sellVolumeLabel.stringValue = [NSString stringWithFormat:@"Sell: %@", [self formatVolume:sellVol]];
    self.sellVolumeLabel.textColor = [NSColor systemRedColor];
    
    self.tickCountLabel.stringValue = [NSString stringWithFormat:@"Ticks: %lu", (unsigned long)self.tickDataInternal.count];
}

- (NSString *)formatVolume:(double)volume {
    if (volume >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", volume / 1000000.0];
    } else if (volume >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", volume / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%.0f", volume];
    }
}

#pragma mark - UI State

- (void)showLoadingState {
    self.isLoading = YES;
    self.loadingIndicator.hidden = NO;
    [self.loadingIndicator startAnimation:nil];
    self.refreshButton.enabled = NO;
    self.statusLabel.stringValue = @"Loading...";
}

- (void)hideLoadingState {
    self.isLoading = NO;
    self.loadingIndicator.hidden = YES;
    [self.loadingIndicator stopAnimation:nil];
    self.refreshButton.enabled = YES;
}

- (void)scrollToBottomOfTable {
    if (self.tickDataInternal.count > 0) {
        NSInteger lastRow = self.tickDataInternal.count - 1;
        [self.tickTableView scrollRowToVisible:lastRow];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.tickDataInternal.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.tickDataInternal.count) return nil;
    
    TickDataModel *tick = self.tickDataInternal[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"time"]) {
        return [tick formattedTime];
    } else if ([identifier isEqualToString:@"price"]) {
        return [NSString stringWithFormat:@"%.2f", tick.price];
    } else if ([identifier isEqualToString:@"volume"]) {
        return [self formatVolume:tick.volume];
    } else if ([identifier isEqualToString:@"direction"]) {
        return [tick directionString];
    } else if ([identifier isEqualToString:@"exchange"]) {
        return tick.exchange.length > 0 ? tick.exchange : @"--";
    }
    
    return @"";
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.tickDataInternal.count) return nil;
    
    TickDataModel *tick = self.tickDataInternal[row];
    NSString *identifier = tableColumn.identifier;
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.bordered = NO;
        textField.editable = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular];
        
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
        
        cellView.identifier = identifier;
    }
    
    // Set text value
    cellView.textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row];
    
    // Color coding for direction
    if ([identifier isEqualToString:@"direction"]) {
        switch (tick.direction) {
            case TickDirectionUp:
                cellView.textField.textColor = [NSColor systemGreenColor];
                break;
            case TickDirectionDown:
                cellView.textField.textColor = [NSColor systemRedColor];
                break;
            default:
                cellView.textField.textColor = [NSColor labelColor];
                break;
        }
    } else {
        cellView.textField.textColor = [NSColor labelColor];
    }
    
    return cellView;
}

#pragma mark - Notifications

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(tickDataUpdated:)
               name:DataHubTickDataUpdatedNotification
             object:nil];
}

- (void)tickDataUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    
    // Only process if it's for our current symbol
    if (![symbol isEqualToString:self.currentSymbol]) return;
    
    NSArray<TickDataModel *> *newTicks = notification.userInfo[@"ticks"];
    if (!newTicks || newTicks.count == 0) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update with new tick data
        [self.tickDataInternal removeAllObjects];
        [self.tickDataInternal addObjectsFromArray:newTicks];
        
        [self.tickTableView reloadData];
        [self updateStatistics];
        [self scrollToBottomOfTable];
        
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Updated: %lu ticks", (unsigned long)newTicks.count];
    });
}

#pragma mark - Cleanup

- (void)dealloc {
    [self stopRealTimeUpdates];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - State Serialization

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    state[@"currentSymbol"] = self.currentSymbol ?: @"";
    state[@"tickLimit"] = @(self.tickLimit);
    state[@"volumeThreshold"] = @(self.volumeThreshold);
    state[@"realTimeUpdates"] = @(self.realTimeUpdates);
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    self.tickLimit = [state[@"tickLimit"] integerValue] ?: 500;
    self.volumeThreshold = [state[@"volumeThreshold"] integerValue] ?: 10000;
    
    // Restore UI state
    self.limitSlider.integerValue = self.tickLimit;
    self.limitLabel.stringValue = [NSString stringWithFormat:@"Limit: %ld", (long)self.tickLimit];
    
    NSString *symbol = state[@"currentSymbol"];
    if (symbol && symbol.length > 0) {
        [self setSymbol:symbol];
    }
    
    // Restore real-time updates if needed
    BOOL shouldEnableRealTime = [state[@"realTimeUpdates"] boolValue];
    if (shouldEnableRealTime && self.currentSymbol) {
        [self startRealTimeUpdates];
    }
}

@end
