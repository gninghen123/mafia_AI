
//
//  TickChartWidget.m
//  mafia_AI
//

#import "TickChartWidget.h"
#import "DataHub+TickData.h"
#import <Cocoa/Cocoa.h>

@interface TickChartWidget ()

// UI Components - Row 1
@property (nonatomic, strong) NSView *controlsView;
@property (nonatomic, strong) NSComboBox *symbolComboBox;
@property (nonatomic, strong) NSButton *realTimeButton;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *allDayButton;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;
@property (nonatomic, strong) NSTextField *statusLabel;

// 🆕 NEW: UI Components - Row 2 (Time & Market Controls)
@property (nonatomic, strong) NSView *timeControlsView;
@property (nonatomic, strong) NSComboBox *fromTimeComboBox;
@property (nonatomic, strong) NSTextField *fromTimeLabel;
@property (nonatomic, strong) NSComboBox *marketSessionComboBox;
@property (nonatomic, strong) NSTextField *marketSessionLabel;

// 🆕 NEW: UI Components - Row 3 (Advanced Settings)
@property (nonatomic, strong) NSView *advancedControlsView;
@property (nonatomic, strong) NSSlider *limitSlider;
@property (nonatomic, strong) NSTextField *limitLabel;
@property (nonatomic, strong) NSSlider *volumeThresholdSlider;
@property (nonatomic, strong) NSTextField *volumeThresholdLabel;

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
    _tickLimit = 3000;           // Default to last 500 trades
    _volumeThreshold = 1000;   // 10K+ shares considered significant
    _realTimeUpdates = NO;      // Start with manual updates
    _tickDataInternal = [NSMutableArray array];
    _isLoading = NO;
    
    // 🆕 NEW: Enhanced default settings
    _marketSession = @"regular"; // Default to regular hours
    _fromTime = [self calculateDefaultFromTime]; // 30 minutes ago
    
    // Register for DataHub notifications
    [self registerForNotifications];
}

// 🆕 NEW: Calculate default from time (30 minutes before current time)
- (NSString *)calculateDefaultFromTime {
    NSDate *currentDate = [NSDate date];
    NSDate *thirtyMinutesAgo = [currentDate dateByAddingTimeInterval:-(30 * 60)]; // 30 minutes * 60 seconds
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    
    return [formatter stringFromDate:thirtyMinutesAgo];
}

- (void)setupContentView {
    [super setupContentView];
    
    // Setup UI in order
    [self setupControls];
    [self setupTimeControls];        // 🆕 NEW
    [self setupAdvancedControls];    // 🆕 NEW
    [self setupStatsView];
    [self setupTickTable];
    [self setupChartView];
    [self setupLayout];
}

#pragma mark - UI Setup

- (void)setupControls {
    // Row 1: Symbol and basic controls
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

    // ALL DAY button
    self.allDayButton = [[NSButton alloc] init];
    self.allDayButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.allDayButton.title = @"ALL DAY";
    self.allDayButton.target = self;
    self.allDayButton.action = @selector(loadAllDayData);
    [self.controlsView addSubview:self.allDayButton];

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

// 🆕 NEW: Time and Market Session Controls
- (void)setupTimeControls {
    // Row 2: Time and market session controls
    self.timeControlsView = [[NSView alloc] init];
    self.timeControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.timeControlsView];
    
    // From Time Label
    self.fromTimeLabel = [[NSTextField alloc] init];
    self.fromTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fromTimeLabel.stringValue = @"From:";
    self.fromTimeLabel.editable = NO;
    self.fromTimeLabel.bordered = NO;
    self.fromTimeLabel.backgroundColor = [NSColor clearColor];
    self.fromTimeLabel.font = [NSFont systemFontOfSize:11];
    [self.timeControlsView addSubview:self.fromTimeLabel];
    
    // From Time ComboBox
    self.fromTimeComboBox = [[NSComboBox alloc] init];
    self.fromTimeComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.fromTimeComboBox.target = self;
    self.fromTimeComboBox.action = @selector(fromTimeChanged:);
    [self.timeControlsView addSubview:self.fromTimeComboBox];
    
    // Populate with common times
    [self.fromTimeComboBox addItemsWithObjectValues:@[
        @"4:00",    // Pre-market start
        @"8:00",    // Early pre-market
        @"9:00",    // Pre-market active
        @"9:30",    // Market open
        @"10:00",   // Market hours
        @"12:00",   // Lunch time
        @"15:00",   // Market hours
        @"16:00",   // Market close
        @"18:00",   // After hours
        @"20:00"    // After hours end
    ]];
    self.fromTimeComboBox.stringValue = self.fromTime;
    
    // Market Session Label
    self.marketSessionLabel = [[NSTextField alloc] init];
    self.marketSessionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.marketSessionLabel.stringValue = @"Session:";
    self.marketSessionLabel.editable = NO;
    self.marketSessionLabel.bordered = NO;
    self.marketSessionLabel.backgroundColor = [NSColor clearColor];
    self.marketSessionLabel.font = [NSFont systemFontOfSize:11];
    [self.timeControlsView addSubview:self.marketSessionLabel];
    
    // Market Session ComboBox
    self.marketSessionComboBox = [[NSComboBox alloc] init];
    self.marketSessionComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.marketSessionComboBox.target = self;
    self.marketSessionComboBox.action = @selector(marketSessionChanged:);
    [self.timeControlsView addSubview:self.marketSessionComboBox];
    
    // Populate with session options
    [self.marketSessionComboBox addItemsWithObjectValues:@[
        @"regular",  // 9:30-16:00 ET
        @"pre",      // 4:00-9:30 ET
        @"post",     // 16:00-20:00 ET
        @"full"      // Complete session (pre + regular + post)
    ]];
    self.marketSessionComboBox.stringValue = self.marketSession;
}

// 🆕 NEW: Advanced Controls (Limits and Thresholds)
- (void)setupAdvancedControls {
    // Row 3: Advanced settings
    self.advancedControlsView = [[NSView alloc] init];
    self.advancedControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.advancedControlsView];
    
    // Tick Limit Slider
    self.limitSlider = [[NSSlider alloc] init];
    self.limitSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.limitSlider.minValue = 100;
    self.limitSlider.maxValue = 999999999;  // 🆕 NEW: Increased to 999M
    self.limitSlider.integerValue = self.tickLimit;
    self.limitSlider.target = self;
    self.limitSlider.action = @selector(limitChanged:);
    [self.advancedControlsView addSubview:self.limitSlider];
    
    // Tick Limit Label
    self.limitLabel = [[NSTextField alloc] init];
    self.limitLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.limitLabel.stringValue = [NSString stringWithFormat:@"Limit: %@", [self formatNumber:self.tickLimit]];
    self.limitLabel.editable = NO;
    self.limitLabel.bordered = NO;
    self.limitLabel.backgroundColor = [NSColor clearColor];
    self.limitLabel.font = [NSFont systemFontOfSize:11];
    [self.advancedControlsView addSubview:self.limitLabel];
    
    // Volume Threshold Slider
    self.volumeThresholdSlider = [[NSSlider alloc] init];
    self.volumeThresholdSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.volumeThresholdSlider.minValue = 100;        // Min 100 shares
    self.volumeThresholdSlider.maxValue = 50000;     // Max 50k shares
    self.volumeThresholdSlider.integerValue = self.volumeThreshold;
    self.volumeThresholdSlider.target = self;
    self.volumeThresholdSlider.action = @selector(volumeThresholdChanged:);
    [self.advancedControlsView addSubview:self.volumeThresholdSlider];
    
    // Volume Threshold Label
    self.volumeThresholdLabel = [[NSTextField alloc] init];
    self.volumeThresholdLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.volumeThresholdLabel.stringValue = [NSString stringWithFormat:@"Vol Threshold: %@", [self formatVolume:self.volumeThreshold]];
    self.volumeThresholdLabel.editable = NO;
    self.volumeThresholdLabel.bordered = NO;
    self.volumeThresholdLabel.backgroundColor = [NSColor clearColor];
    self.volumeThresholdLabel.font = [NSFont systemFontOfSize:11];
    [self.advancedControlsView addSubview:self.volumeThresholdLabel];
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
    self.tickTableView.rowSizeStyle = NSTableViewRowSizeStyleSmall;
    
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
    [self.contentView addSubview:self.tickTableScrollView];
}

- (void)setupChartView {
    // 🆕 NEW: Create functional TickChartView
    TickChartView *chartView = [[TickChartView alloc] init];
    chartView.widget = self;
    self.chartView = chartView;
    
    self.chartView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chartView.wantsLayer = YES;
    self.chartView.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
    self.chartView.layer.borderColor = [[NSColor separatorColor] CGColor];
    self.chartView.layer.borderWidth = 1.0;
    self.chartView.layer.cornerRadius = 4.0;
    
    [self.contentView addSubview:self.chartView];
}

- (void)setupLayout {
    // Main layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Controls view (Row 1)
        [self.controlsView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.controlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.controlsView.heightAnchor constraintEqualToConstant:32],
        
        // 🆕 NEW: Time controls view (Row 2)
        [self.timeControlsView.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:8],
        [self.timeControlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.timeControlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.timeControlsView.heightAnchor constraintEqualToConstant:32],
        
        // 🆕 NEW: Advanced controls view (Row 3)
        [self.advancedControlsView.topAnchor constraintEqualToAnchor:self.timeControlsView.bottomAnchor constant:8],
        [self.advancedControlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.advancedControlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.advancedControlsView.heightAnchor constraintEqualToConstant:32],
        
        // Stats view (moved down)
        [self.statsView.topAnchor constraintEqualToAnchor:self.advancedControlsView.bottomAnchor constant:8],
        [self.statsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.statsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.statsView.heightAnchor constraintEqualToConstant:32],
        
        // Table view (left side)
        [self.tickTableScrollView.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:8],
        [self.tickTableScrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.tickTableScrollView.widthAnchor constraintEqualToConstant:260],
        [self.tickTableScrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        
        // Chart view (right side)
        [self.chartView.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:8],
        [self.chartView.leadingAnchor constraintEqualToAnchor:self.tickTableScrollView.trailingAnchor constant:8],
        [self.chartView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.chartView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];
    
    // Setup individual layouts
    [self setupControlsLayout];
    [self setupTimeControlsLayout];      // 🆕 NEW
    [self setupAdvancedControlsLayout];  // 🆕 NEW
    [self setupStatsLayout];
}

- (void)setupControlsLayout {
    [NSLayoutConstraint activateConstraints:@[
        // Symbol combo box
        [self.symbolComboBox.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor],
        [self.symbolComboBox.topAnchor constraintEqualToAnchor:self.controlsView.topAnchor constant:4],
        [self.symbolComboBox.widthAnchor constraintEqualToConstant:100],

        // Real-time button
        [self.realTimeButton.leadingAnchor constraintEqualToAnchor:self.symbolComboBox.trailingAnchor constant:8],
        [self.realTimeButton.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor],

        // Refresh button
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.realTimeButton.trailingAnchor constant:8],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor],

        // ALL DAY button
        [self.allDayButton.leadingAnchor constraintEqualToAnchor:self.refreshButton.trailingAnchor constant:8],
        [self.allDayButton.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor],

        // Loading indicator
        [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.allDayButton.trailingAnchor constant:8],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor],

        // Status label
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.controlsView.trailingAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.symbolComboBox.centerYAnchor]
    ]];
}

// 🆕 NEW: Time Controls Layout
- (void)setupTimeControlsLayout {
    [NSLayoutConstraint activateConstraints:@[
        // From Time Label
        [self.fromTimeLabel.leadingAnchor constraintEqualToAnchor:self.timeControlsView.leadingAnchor],
        [self.fromTimeLabel.centerYAnchor constraintEqualToAnchor:self.timeControlsView.centerYAnchor],
        [self.fromTimeLabel.widthAnchor constraintEqualToConstant:40],
        
        // From Time ComboBox
        [self.fromTimeComboBox.leadingAnchor constraintEqualToAnchor:self.fromTimeLabel.trailingAnchor constant:4],
        [self.fromTimeComboBox.centerYAnchor constraintEqualToAnchor:self.timeControlsView.centerYAnchor],
        [self.fromTimeComboBox.widthAnchor constraintEqualToConstant:80],
        
        // Market Session Label
        [self.marketSessionLabel.leadingAnchor constraintEqualToAnchor:self.fromTimeComboBox.trailingAnchor constant:16],
        [self.marketSessionLabel.centerYAnchor constraintEqualToAnchor:self.timeControlsView.centerYAnchor],
        [self.marketSessionLabel.widthAnchor constraintEqualToConstant:55],
        
        // Market Session ComboBox
        [self.marketSessionComboBox.leadingAnchor constraintEqualToAnchor:self.marketSessionLabel.trailingAnchor constant:4],
        [self.marketSessionComboBox.centerYAnchor constraintEqualToAnchor:self.timeControlsView.centerYAnchor],
        [self.marketSessionComboBox.widthAnchor constraintEqualToConstant:80]
    ]];
}

// 🆕 NEW: Advanced Controls Layout
- (void)setupAdvancedControlsLayout {
    [NSLayoutConstraint activateConstraints:@[
        // Limit Slider
        [self.limitSlider.leadingAnchor constraintEqualToAnchor:self.advancedControlsView.leadingAnchor],
        [self.limitSlider.centerYAnchor constraintEqualToAnchor:self.advancedControlsView.centerYAnchor],
        [self.limitSlider.widthAnchor constraintEqualToConstant:120],
        
        // Limit Label
        [self.limitLabel.leadingAnchor constraintEqualToAnchor:self.limitSlider.trailingAnchor constant:8],
        [self.limitLabel.centerYAnchor constraintEqualToAnchor:self.advancedControlsView.centerYAnchor],
        [self.limitLabel.widthAnchor constraintEqualToConstant:100],
        
        // Volume Threshold Slider
        [self.volumeThresholdSlider.leadingAnchor constraintEqualToAnchor:self.limitLabel.trailingAnchor constant:16],
        [self.volumeThresholdSlider.centerYAnchor constraintEqualToAnchor:self.advancedControlsView.centerYAnchor],
        [self.volumeThresholdSlider.widthAnchor constraintEqualToConstant:120],
        
        // Volume Threshold Label
        [self.volumeThresholdLabel.leadingAnchor constraintEqualToAnchor:self.volumeThresholdSlider.trailingAnchor constant:8],
        [self.volumeThresholdLabel.centerYAnchor constraintEqualToAnchor:self.advancedControlsView.centerYAnchor],
        [self.volumeThresholdLabel.widthAnchor constraintEqualToConstant:120]
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


- (void)updateChartWithTickData {
    if ([self.chartView isKindOfClass:[TickChartView class]]) {
        TickChartView *tickChartView = (TickChartView *)self.chartView;
        [tickChartView updateWithTickData:self.tickDataInternal];
    }
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

// 🆕 NEW: Number formatting for large values
- (NSString *)formatNumber:(NSInteger)number {
    if (number >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", number / 1000000.0];
    } else if (number >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", number / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%ld", (long)number];
    }
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

// 🆕 NEW: Enhanced refreshData with new parameters
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
    
    NSLog(@"TickChartWidget: Refreshing tick data for %@ (limit: %@, fromTime: %@, session: %@)",
          self.currentSymbol, [self formatNumber:self.tickLimit], self.fromTime, self.marketSession);
    
    // 🆕 NEW: Use appropriate DataHub method based on market session
    if ([self.marketSession isEqualToString:@"full"]) {
        // Full session data
        [[DataHub shared] getFullSessionTickDataForSymbol:self.currentSymbol
                                               completion:^(NSArray<TickDataModel *> *ticks, BOOL isFresh) {
            [self handleTickDataResponse:ticks isFresh:isFresh];
        }];
    } else if ([self.marketSession isEqualToString:@"pre"] || [self.marketSession isEqualToString:@"post"]) {
        // Extended hours data
        [[DataHub shared] getExtendedTickDataForSymbol:self.currentSymbol
                                            marketType:self.marketSession
                                            completion:^(NSArray<TickDataModel *> *ticks, BOOL isFresh) {
            [self handleTickDataResponse:ticks isFresh:isFresh];
        }];
    } else {
        // Regular hours with custom fromTime and limit
        [[DataHub shared] getTickDataForSymbol:self.currentSymbol
                                         limit:self.tickLimit
                                      fromTime:self.fromTime
                                    completion:^(NSArray<TickDataModel *> *ticks, BOOL isFresh) {
            [self handleTickDataResponse:ticks isFresh:isFresh];
            [self updateChartWithTickData];  // 🆕 ADD

        }];
    }
}

// 🆕 NEW: Centralized tick data response handler
- (void)handleTickDataResponse:(NSArray<TickDataModel *> *)ticks isFresh:(BOOL)isFresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideLoadingState];
        
        if (!ticks || ticks.count == 0) {
            self.statusLabel.stringValue = [NSString stringWithFormat:@"No tick data for %@ (%@)",
                                           self.currentSymbol, self.marketSession];
            return;
        }
        
        // Filter by volume threshold if needed
        NSArray<TickDataModel *> *filteredTicks = [self filterTicksByVolumeThreshold:ticks];
        
        // Update data
        [self.tickDataInternal removeAllObjects];
        [self.tickDataInternal addObjectsFromArray:filteredTicks];
        
        // Refresh UI
        [self.tickTableView reloadData];
        [self updateStatistics];
        [self scrollToBottomOfTable];
        
        // Update status
        NSString *sessionInfo = [self.marketSession isEqualToString:@"regular"] ? @"" :
                               [NSString stringWithFormat:@" (%@)", self.marketSession];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Loaded %@ ticks%@ (%@)",
                                       [self formatNumber:filteredTicks.count],
                                       sessionInfo,
                                       isFresh ? @"fresh" : @"cached"];
        
        NSLog(@"TickChartWidget: Successfully loaded %lu ticks for %@",
              (unsigned long)filteredTicks.count, self.currentSymbol);
    });
}

// 🆕 NEW: Filter ticks by volume threshold
- (NSArray<TickDataModel *> *)filterTicksByVolumeThreshold:(NSArray<TickDataModel *> *)ticks {
    if (self.volumeThreshold <= 1000) {
        return ticks; // No filtering for low thresholds
    }
    
    NSMutableArray *filteredTicks = [NSMutableArray array];
    for (TickDataModel *tick in ticks) {
        if (tick.volume >= self.volumeThreshold) {
            [filteredTicks addObject:tick];
        }
    }
    
    return [filteredTicks copy];
}

- (void)startRealTimeUpdates {
    if (!self.currentSymbol) return;
    
    self.realTimeUpdates = YES;
    self.realTimeButton.state = NSControlStateValueOn;
    
    [[DataHub shared] startTickStreamForSymbol:self.currentSymbol];
    
    NSLog(@"TickChartWidget: Started real-time updates for %@", self.currentSymbol);
}

- (void)stopRealTimeUpdates {
    self.realTimeUpdates = NO;
    self.realTimeButton.state = NSControlStateValueOff;
    
    if (self.currentSymbol) {
        [[DataHub shared] stopTickStreamForSymbol:self.currentSymbol];
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

// 🆕 NEW: Enhanced setter methods
- (void)setFromTime:(NSString *)fromTime {
    if ([fromTime isEqualToString:_fromTime]) return;
    
    _fromTime = fromTime;
    self.fromTimeComboBox.stringValue = fromTime;
    
    // Refresh data if we have a symbol
    if (self.currentSymbol) {
        [self refreshData];
    }
    
    NSLog(@"TickChartWidget: From time changed to %@", fromTime);
}

- (void)setMarketSession:(NSString *)marketSession {
    if ([marketSession isEqualToString:_marketSession]) return;
    
    _marketSession = marketSession;
    self.marketSessionComboBox.stringValue = marketSession;
    
    // Update fromTime automatically based on session
    [self updateFromTimeForSession:marketSession];
    
    // Refresh data if we have a symbol
    if (self.currentSymbol) {
        [self refreshData];
    }
    
    NSLog(@"TickChartWidget: Market session changed to %@", marketSession);
}

- (void)setVolumeThreshold:(NSInteger)volumeThreshold {
    if (volumeThreshold == _volumeThreshold) return;
    
    _volumeThreshold = volumeThreshold;
    self.volumeThresholdSlider.integerValue = volumeThreshold;
    self.volumeThresholdLabel.stringValue = [NSString stringWithFormat:@"Vol Threshold: %@",
                                           [self formatVolume:volumeThreshold]];
    
    // Refresh data if we have a symbol (to apply new filtering)
    if (self.currentSymbol) {
        [self refreshData];
    }
    
    NSLog(@"TickChartWidget: Volume threshold changed to %@", [self formatVolume:volumeThreshold]);
}

// 🆕 NEW: Auto-update fromTime based on market session
- (void)updateFromTimeForSession:(NSString *)session {
    if ([session isEqualToString:@"pre"]) {
        self.fromTime = @"4:00";
    } else if ([session isEqualToString:@"regular"]) {
        self.fromTime = [self calculateDefaultFromTime]; // 30 minutes ago
    } else if ([session isEqualToString:@"post"]) {
        self.fromTime = @"16:00";
    } else if ([session isEqualToString:@"full"]) {
        self.fromTime = @"4:00"; // Start from pre-market
    }
    
    self.fromTimeComboBox.stringValue = self.fromTime;
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
    self.limitLabel.stringValue = [NSString stringWithFormat:@"Limit: %@", [self formatNumber:self.tickLimit]];
    
    // Refresh data with new limit
    if (self.currentSymbol) {
        [self refreshData];
    }
}

// 🆕 NEW: Action methods for new controls
- (void)fromTimeChanged:(id)sender {
    NSString *newFromTime = self.fromTimeComboBox.stringValue;
    [self setFromTime:newFromTime];
}

- (void)marketSessionChanged:(id)sender {
    NSString *newSession = self.marketSessionComboBox.stringValue;
    [self setMarketSession:newSession];
}

- (void)volumeThresholdChanged:(id)sender {
    NSInteger newThreshold = self.volumeThresholdSlider.integerValue;
    [self setVolumeThreshold:newThreshold];
}

#pragma mark - Data Analysis

- (double)cumulativeVolumeDelta {
    return [[DataHub shared] calculateVolumeDeltaForTicks:self.tickDataInternal];
}

- (double)currentVWAP {
    return [[DataHub shared] calculateVWAPForTicks:self.tickDataInternal];
}

- (NSDictionary *)volumeBreakdown {
    return [[DataHub shared] calculateVolumeBreakdownForTicks:self.tickDataInternal];
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
    
    self.tickCountLabel.stringValue = [NSString stringWithFormat:@"Ticks: %@", [self formatNumber:self.tickDataInternal.count]];
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
    
    // Color coding for direction and significant trades
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
    } else if ([identifier isEqualToString:@"volume"]) {
        // Highlight significant trades
        if (tick.volume >= self.volumeThreshold) {
            cellView.textField.textColor = [NSColor systemOrangeColor];
            cellView.textField.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightBold];
        } else {
            cellView.textField.textColor = [NSColor labelColor];
            cellView.textField.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular];
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
        // Filter by volume threshold
        NSArray<TickDataModel *> *filteredTicks = [self filterTicksByVolumeThreshold:newTicks];
        
        // Update with new tick data
        [self.tickDataInternal removeAllObjects];
        [self.tickDataInternal addObjectsFromArray:filteredTicks];
        
        [self.tickTableView reloadData];
        [self updateStatistics];
        [self scrollToBottomOfTable];
        
        [self updateChartWithTickData];  // 🆕 ADD

        
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Updated: %@ ticks",
                                       [self formatNumber:filteredTicks.count]];
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
    // 🆕 NEW: Save enhanced settings
    state[@"fromTime"] = self.fromTime ?: @"9:30";
    state[@"marketSession"] = self.marketSession ?: @"regular";
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    self.tickLimit = [state[@"tickLimit"] integerValue] ?: 500;
    self.volumeThreshold = [state[@"volumeThreshold"] integerValue] ?: 10000;
    
    // 🆕 NEW: Restore enhanced settings
    self.fromTime = state[@"fromTime"] ?: [self calculateDefaultFromTime];
    self.marketSession = state[@"marketSession"] ?: @"regular";
    
    // Restore UI state
    self.limitSlider.integerValue = self.tickLimit;
    self.limitLabel.stringValue = [NSString stringWithFormat:@"Limit: %@", [self formatNumber:self.tickLimit]];
    
    self.volumeThresholdSlider.integerValue = self.volumeThreshold;
    self.volumeThresholdLabel.stringValue = [NSString stringWithFormat:@"Vol Threshold: %@",
                                           [self formatVolume:self.volumeThreshold]];
    
    self.fromTimeComboBox.stringValue = self.fromTime;
    self.marketSessionComboBox.stringValue = self.marketSession;
    
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



#pragma mark - ALL DAY Button Action

// Loads all tick data for the day in 30-minute increments and merges them
- (void)loadAllDayData {
    if (!self.currentSymbol || self.currentSymbol.length == 0) {
        self.statusLabel.stringValue = @"Enter a symbol to start";
        return;
    }
    if (self.isLoading) {
        NSLog(@"TickChartWidget: Already loading data, skipping ALL DAY fetch");
        return;
    }
    [self showLoadingState];
    self.statusLabel.stringValue = @"Loading ALL DAY data...";

    // Define the market open and close times
    NSString *dateString = [[NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle] componentsSeparatedByString:@","][0];
    // We'll parse times as "HH:mm"
    NSArray *timeWindows = @[@"9:30", @"10:00", @"10:30", @"11:00", @"11:30", @"12:00", @"12:30", @"13:00", @"13:30", @"14:00", @"14:30", @"15:00", @"15:30", @"16:00"];
    NSMutableArray<NSDictionary *> *windows = [NSMutableArray array];
    for (NSUInteger i = 0; i < timeWindows.count - 1; i++) {
        [windows addObject:@{@"from": timeWindows[i], @"to": timeWindows[i+1]}];
    }
    // For the last window, use 15:30 to 16:00 (already present)

    __block NSMutableArray<TickDataModel *> *allTicks = [NSMutableArray array];
    __block NSUInteger completed = 0;
    NSUInteger total = windows.count;
    __weak typeof(self) weakSelf = self;

    void (^finishBlock)(void) = ^{
        // Merge, sort, filter duplicates, and update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            // Remove duplicates by timestamp+price+volume (if any)
            NSMutableSet *seen = [NSMutableSet set];
            NSMutableArray *uniqueTicks = [NSMutableArray array];
            for (TickDataModel *tick in allTicks) {
                NSString *tickKey = [NSString stringWithFormat:@"%@-%.8f-%.0f", tick.timestamp, tick.price, tick.volume];
                if (![seen containsObject:tickKey]) {
                    [seen addObject:tickKey];
                    [uniqueTicks addObject:tick];
                }
            }
            // Sort by timestamp ascending
            [uniqueTicks sortUsingComparator:^NSComparisonResult(TickDataModel *a, TickDataModel *b) {
                return [a.timestamp compare:b.timestamp];
            }];
            [weakSelf.tickDataInternal removeAllObjects];
            [weakSelf.tickDataInternal addObjectsFromArray:uniqueTicks];
            [weakSelf.tickTableView reloadData];
            [weakSelf updateStatistics];
            [weakSelf scrollToBottomOfTable];
            [weakSelf updateChartWithTickData];
            [weakSelf hideLoadingState];
            weakSelf.statusLabel.stringValue = [NSString stringWithFormat:@"ALL DAY: %@ ticks loaded", [weakSelf formatNumber:uniqueTicks.count]];
        });
    };

    for (NSDictionary *window in windows) {
        NSString *fromTime = window[@"from"];
        // Use max limit, and fetch fromTime to toTime window
        [[DataHub shared] getTickDataForSymbol:self.currentSymbol
                                         limit:999999999
                                      fromTime:fromTime
                                    completion:^(NSArray<TickDataModel *> *ticks, BOOL isFresh) {
            @synchronized (allTicks) {
                if (ticks) {
                    [allTicks addObjectsFromArray:ticks];
                }
                completed++;
                if (completed == total) {
                    finishBlock();
                }
            }
        }];
    }
}

@end
