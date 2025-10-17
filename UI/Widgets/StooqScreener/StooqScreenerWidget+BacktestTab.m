//
//  StooqScreenerWidget+BacktestTab.m
//  TradingApp
//

#import "StooqScreenerWidget+BacktestTab.h"
#import "StooqDataManager+Backtest.h"
#import <objc/runtime.h>
#import "StooqScreenerWidget+Private.h"  // ← Access to main widget properties
#import "CandlestickChartView.h"
#import "ComparisonChartView.h"

@interface BacktestChartsContainer : NSObject
@property (nonatomic, strong) CandlestickChartView *candlestickChartView;
@property (nonatomic, strong) ComparisonChartView *comparisonChartView;
@end

@implementation BacktestChartsContainer
@end

@implementation StooqScreenerWidget (BacktestTab)
- (IBAction)zoomInChart:(id)sender {
    if (self.candlestickChartView) {
        [self.candlestickChartView zoomIn];
        NSLog(@"🔍 Zoom In");
    }
}

- (IBAction)zoomOutChart:(id)sender {
    if (self.candlestickChartView) {
        [self.candlestickChartView zoomOut];
        NSLog(@"🔍 Zoom Out");
    }
}

- (IBAction)zoomAllChart:(id)sender {
    if (self.candlestickChartView) {
        [self.candlestickChartView zoomAll];
        NSLog(@"🔍 Zoom All");
    }
}
#pragma mark - CandlestickChartViewDelegate

- (void)candlestickChartView:(CandlestickChartView *)chartView
         didSelectDateRange:(NSDate *)startDate
                    endDate:(NSDate *)endDate {
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    
    NSLog(@"📅 User selected date range: %@ → %@",
          [formatter stringFromDate:startDate],
          [formatter stringFromDate:endDate]);
    
    // Update date pickers
    self.backtestStartDatePicker.dateValue = startDate;
    self.backtestEndDatePicker.dateValue = endDate;
    
    // Update label
    self.dateRangeLabel.stringValue = [NSString stringWithFormat:@"%@ → %@",
                                       [formatter stringFromDate:startDate],
                                       [formatter stringFromDate:endDate]];
}

- (void)candlestickChartView:(CandlestickChartView *)chartView
       didMoveCrosshairToDate:(NSDate *)date
                          bar:(HistoricalBarModel *)bar {
    // Crosshair coordination (optional for now)
}

#pragma mark - ComparisonChartViewDelegate

- (void)comparisonChartView:(ComparisonChartView *)chartView
     didMoveCrosshairToDate:(NSDate *)date {
    // Crosshair coordination (optional for now)
}
#pragma mark - Chart Views Container

static char backtestChartsContainerKey;

- (BacktestChartsContainer *)chartsContainer {
    BacktestChartsContainer *container = objc_getAssociatedObject(self, &backtestChartsContainerKey);
    if (!container) {
        container = [[BacktestChartsContainer alloc] init];
        objc_setAssociatedObject(self, &backtestChartsContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return container;
}

- (CandlestickChartView *)candlestickChartView {
    return self.chartsContainer.candlestickChartView;
}

- (void)setCandlestickChartView:(CandlestickChartView *)view {
    self.chartsContainer.candlestickChartView = view;
}

- (ComparisonChartView *)comparisonChartView {
    return self.chartsContainer.comparisonChartView;
}

- (void)setComparisonChartView:(ComparisonChartView *)view {
    self.chartsContainer.comparisonChartView = view;
}
#pragma mark - Associated Objects (for category properties)

// Note: These are getter/setter implementations for category properties
// In production, consider moving these to main @interface or using a dedicated container object

static char backtestRunnerKey;
static char currentBacktestSessionKey;
static char backtestMasterCacheKey;
static char availableStatisticsMetricsKey;
static char selectedStatisticMetricKey;

- (BacktestRunner *)backtestRunner {
    return objc_getAssociatedObject(self, &backtestRunnerKey);
}

- (void)setBacktestRunner:(BacktestRunner *)backtestRunner {
    objc_setAssociatedObject(self, &backtestRunnerKey, backtestRunner, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BacktestSession *)currentBacktestSession {
    return objc_getAssociatedObject(self, &currentBacktestSessionKey);
}

- (void)setCurrentBacktestSession:(BacktestSession *)session {
    objc_setAssociatedObject(self, &currentBacktestSessionKey, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)backtestMasterCache {
    return objc_getAssociatedObject(self, &backtestMasterCacheKey);
}

- (void)setBacktestMasterCache:(NSDictionary *)cache {
    objc_setAssociatedObject(self, &backtestMasterCacheKey, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSString *> *)availableStatisticsMetrics {
    NSArray *metrics = objc_getAssociatedObject(self, &availableStatisticsMetricsKey);
    if (!metrics) {
        // Default metrics
        metrics = @[
            @"# Symbols",
            @"Win Rate %",
            @"Avg Gain %",
            @"Avg Loss %",
            @"# Trades",
            @"Win/Loss Ratio"
        ];
        [self setAvailableStatisticsMetrics:metrics];
    }
    return metrics;
}

- (void)setAvailableStatisticsMetrics:(NSArray<NSString *> *)metrics {
    objc_setAssociatedObject(self, &availableStatisticsMetricsKey, metrics, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)selectedStatisticMetric {
    return objc_getAssociatedObject(self, &selectedStatisticMetricKey);
}

- (void)setSelectedStatisticMetric:(NSString *)metric {
    objc_setAssociatedObject(self, &selectedStatisticMetricKey, metric, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Tab Setup

- (void)setupBacktestTab {
    
    self.backtestView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 900, 900)];
    // ========================================
    // TOP BAR: Benchmark Symbol Input
    // ========================================
    
    NSView *topBar = [[NSView alloc] init];
    topBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backtestView addSubview:topBar];
    
    NSTextField *symbolLabel = [[NSTextField alloc] init];
    symbolLabel.stringValue = @"Benchmark Symbol:";
    symbolLabel.editable = NO;
    symbolLabel.bordered = NO;
    symbolLabel.backgroundColor = [NSColor clearColor];
    symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [topBar addSubview:symbolLabel];
    
    self.benchmarkSymbolField = [[NSTextField alloc] init];
    self.benchmarkSymbolField.stringValue = @"SPY";
    self.benchmarkSymbolField.placeholderString = @"Enter symbol (e.g., SPY)";
    self.benchmarkSymbolField.translatesAutoresizingMaskIntoConstraints = NO;
    [topBar addSubview:self.benchmarkSymbolField];
    
    self.validateSymbolButton = [NSButton buttonWithTitle:@"✓ Validate"
                                                    target:self
                                                    action:@selector(validateBenchmarkSymbol:)];
    self.validateSymbolButton.translatesAutoresizingMaskIntoConstraints = NO;
    [topBar addSubview:self.validateSymbolButton];
    
    self.symbolValidationLabel = [[NSTextField alloc] init];
    self.symbolValidationLabel.stringValue = @"";
    self.symbolValidationLabel.editable = NO;
    self.symbolValidationLabel.bordered = NO;
    self.symbolValidationLabel.backgroundColor = [NSColor clearColor];
    self.symbolValidationLabel.textColor = [NSColor secondaryLabelColor];
    self.symbolValidationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [topBar addSubview:self.symbolValidationLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [topBar.heightAnchor constraintEqualToConstant:40],
        
        [symbolLabel.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:10],
        [symbolLabel.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        
        [self.benchmarkSymbolField.leadingAnchor constraintEqualToAnchor:symbolLabel.trailingAnchor constant:10],
        [self.benchmarkSymbolField.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [self.benchmarkSymbolField.widthAnchor constraintEqualToConstant:100],
        
        [self.validateSymbolButton.leadingAnchor constraintEqualToAnchor:self.benchmarkSymbolField.trailingAnchor constant:10],
        [self.validateSymbolButton.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        
        [self.symbolValidationLabel.leadingAnchor constraintEqualToAnchor:self.validateSymbolButton.trailingAnchor constant:10],
        [self.symbolValidationLabel.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [self.symbolValidationLabel.trailingAnchor constraintLessThanOrEqualToAnchor:topBar.trailingAnchor constant:-10]
    ]];
    
    // ========================================
    // MAIN SPLIT VIEW: Left | Right
    // ========================================
    
    self.backtestMainSplitView = [[NSSplitView alloc] init];
    self.backtestMainSplitView.vertical = YES;
    self.backtestMainSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.backtestMainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    // Set initial frame (will be resized by constraints anyway, but avoids zero size)
    self.backtestMainSplitView.frame = NSMakeRect(0, 0, 800, 600);
    [self.backtestView addSubview:self.backtestMainSplitView];
    self.backtestMainSplitView.autosaveName = @"BacktestMainSplit";
    
    // ========================================
    // LEFT SIDE: Models (top) | Statistics (bottom)
    // ========================================
    
    self.backtestLeftSplitView = [[NSSplitView alloc] init];
    self.backtestLeftSplitView.vertical = NO;
    self.backtestLeftSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.backtestLeftSplitView.frame = NSMakeRect(0, 0, 400 , 200);
    [self.backtestMainSplitView addArrangedSubview:self.backtestLeftSplitView];
    
    // Left-Top: Models List
    NSView *modelsPanel = [self createBacktestModelsPanel];
    modelsPanel.frame = NSMakeRect(0, 0, 200, 600);
    [self.backtestLeftSplitView addArrangedSubview:modelsPanel];
    
    // Left-Bottom: Statistics Metrics
    NSView *statsPanel = [self createStatisticsMetricsPanel];
    statsPanel.frame = NSMakeRect(0, 0, 200, 600);
    [self.backtestLeftSplitView addArrangedSubview:statsPanel];
    
    // ========================================
    // RIGHT SIDE: Candlestick (top) | Comparison (bottom)
    // ========================================
    
    self.backtestRightSplitView = [[NSSplitView alloc] init];
    self.backtestRightSplitView.vertical = NO;
    self.backtestRightSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.backtestRightSplitView.frame = NSMakeRect(0, 0, 400, 600);
    [self.backtestMainSplitView addArrangedSubview:self.backtestRightSplitView];
    
    // Right-Top: Candlestick Chart
    NSView *candlestickPanel = [self createCandlestickChartPanel];
    candlestickPanel.frame = NSMakeRect(0, 0, 600, 600);
    [self.backtestRightSplitView addArrangedSubview:candlestickPanel];
    
    // Right-Bottom: Comparison Chart
    NSView *comparisonPanel = [self createComparisonChartPanel];
    comparisonPanel.frame = NSMakeRect(0, 0, 600, 600);
    [self.backtestRightSplitView addArrangedSubview:comparisonPanel];
    
    // ========================================
    // BOTTOM BAR: Controls & Progress
    // ========================================
    
    NSView *bottomBar = [self createBacktestControlBar];
    bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backtestView addSubview:bottomBar];
    
    // ========================================
    // Layout Constraints
    // ========================================
    
    [NSLayoutConstraint activateConstraints:@[
        // Top bar
        [topBar.topAnchor constraintEqualToAnchor:self.backtestView.topAnchor],
        [topBar.leadingAnchor constraintEqualToAnchor:self.backtestView.leadingAnchor],
        [topBar.trailingAnchor constraintEqualToAnchor:self.backtestView.trailingAnchor],
        
        // Main split view
        [self.backtestMainSplitView.topAnchor constraintEqualToAnchor:topBar.bottomAnchor constant:10],
        [self.backtestMainSplitView.leadingAnchor constraintEqualToAnchor:self.backtestView.leadingAnchor constant:10],
        [self.backtestMainSplitView.trailingAnchor constraintEqualToAnchor:self.backtestView.trailingAnchor constant:-10],
        [self.backtestMainSplitView.bottomAnchor constraintEqualToAnchor:bottomBar.topAnchor constant:-10],
        
        // Bottom bar
        [bottomBar.leadingAnchor constraintEqualToAnchor:self.backtestView.leadingAnchor],
        [bottomBar.trailingAnchor constraintEqualToAnchor:self.backtestView.trailingAnchor],
        [bottomBar.bottomAnchor constraintEqualToAnchor:self.backtestView.bottomAnchor],
        [bottomBar.heightAnchor constraintEqualToConstant:80]
    ]];

    // Relax split view horizontal constraints to prevent "spring back" effect
    for (NSLayoutConstraint *constraint in self.backtestView.constraints) {
        if (constraint.firstItem == self.backtestMainSplitView &&
            (constraint.firstAttribute == NSLayoutAttributeLeading || constraint.firstAttribute == NSLayoutAttributeTrailing)) {
            constraint.priority = NSLayoutPriorityDefaultLow;
        }
    }
    // No explicit contentHuggingPriority or compressionResistancePriority for split views or panels
/*
    // Set split positions after a delay (when view has size)
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat mainWidth = self.backtestMainSplitView.frame.size.width;
        if (mainWidth > 0) {
            [self.backtestMainSplitView setPosition:mainWidth * 0.25 ofDividerAtIndex:0];
        }
        
        CGFloat leftHeight = self.backtestLeftSplitView.frame.size.height;
        if (leftHeight > 0) {
            [self.backtestLeftSplitView setPosition:leftHeight * 0.5 ofDividerAtIndex:0];
        }
        
        CGFloat rightHeight = self.backtestRightSplitView.frame.size.height;
        if (rightHeight > 0) {
            [self.backtestRightSplitView setPosition:rightHeight * 0.6 ofDividerAtIndex:0];
        }
    });
 */
    
    // ========================================
    // Add Tab to TabView
    // ========================================
    
    NSTabViewItem *backtestTab = [[NSTabViewItem alloc] initWithIdentifier:@"backtest"];
    backtestTab.label = @"Backtest";
    backtestTab.view = self.backtestView;
    [self.tabView addTabViewItem:backtestTab];
    
    // Initialize backtest runner
    self.backtestRunner = [[BacktestRunner alloc] init];
    self.backtestRunner.delegate = self;
    
    NSLog(@"✅ Backtest tab created successfully");
}

#pragma mark - Panel Creation Methods

- (NSView *)createBacktestModelsPanel {
    NSView *panel = [[NSView alloc] init];
    
    // Header
    self.backtestModelsHeaderLabel = [[NSTextField alloc] init];
    self.backtestModelsHeaderLabel.stringValue = @"Models to Test";
    self.backtestModelsHeaderLabel.editable = NO;
    self.backtestModelsHeaderLabel.bordered = NO;
    self.backtestModelsHeaderLabel.backgroundColor = [NSColor clearColor];
    self.backtestModelsHeaderLabel.font = [NSFont boldSystemFontOfSize:13];
    self.backtestModelsHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:self.backtestModelsHeaderLabel];
    
    // Table view
    self.backtestModelsTableView = [[NSTableView alloc] init];
    self.backtestModelsTableView.headerView = nil;
    self.backtestModelsTableView.rowHeight = 24;
    
    // Checkbox column
    NSTableColumn *checkboxCol = [[NSTableColumn alloc] initWithIdentifier:@"checkbox"];
    checkboxCol.width = 30;
    [self.backtestModelsTableView addTableColumn:checkboxCol];
    
    // Name column
    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameCol.title = @"Model Name";
    [self.backtestModelsTableView addTableColumn:nameCol];
    
    self.backtestModelsTableView.dataSource = self;
    self.backtestModelsTableView.delegate = self;
    
    self.backtestModelsScrollView = [[NSScrollView alloc] init];
    self.backtestModelsScrollView.documentView = self.backtestModelsTableView;
    self.backtestModelsScrollView.hasVerticalScroller = YES;
    self.backtestModelsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:self.backtestModelsScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.backtestModelsHeaderLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:10],
        [self.backtestModelsHeaderLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [self.backtestModelsHeaderLabel.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        
        [self.backtestModelsScrollView.topAnchor constraintEqualToAnchor:self.backtestModelsHeaderLabel.bottomAnchor constant:5],
        [self.backtestModelsScrollView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [self.backtestModelsScrollView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        [self.backtestModelsScrollView.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-10]
    ]];
    
    return panel;
}

- (NSView *)createStatisticsMetricsPanel {
    NSView *panel = [[NSView alloc] init];
    
    // Header
    self.statisticsHeaderLabel = [[NSTextField alloc] init];
    self.statisticsHeaderLabel.stringValue = @"Statistics Metrics";
    self.statisticsHeaderLabel.editable = NO;
    self.statisticsHeaderLabel.bordered = NO;
    self.statisticsHeaderLabel.backgroundColor = [NSColor clearColor];
    self.statisticsHeaderLabel.font = [NSFont boldSystemFontOfSize:13];
    self.statisticsHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:self.statisticsHeaderLabel];
    
    // Table view
    self.statisticsMetricsTableView = [[NSTableView alloc] init];
    self.statisticsMetricsTableView.headerView = nil;
    self.statisticsMetricsTableView.rowHeight = 24;
    
    NSTableColumn *metricCol = [[NSTableColumn alloc] initWithIdentifier:@"metric"];
    metricCol.title = @"Metric";
    [self.statisticsMetricsTableView addTableColumn:metricCol];
    
    self.statisticsMetricsTableView.dataSource = self;
    self.statisticsMetricsTableView.delegate = self;
    
    self.statisticsMetricsScrollView = [[NSScrollView alloc] init];
    self.statisticsMetricsScrollView.documentView = self.statisticsMetricsTableView;
    self.statisticsMetricsScrollView.hasVerticalScroller = YES;
    self.statisticsMetricsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:self.statisticsMetricsScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.statisticsHeaderLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:10],
        [self.statisticsHeaderLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [self.statisticsHeaderLabel.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        
        [self.statisticsMetricsScrollView.topAnchor constraintEqualToAnchor:self.statisticsHeaderLabel.bottomAnchor constant:5],
        [self.statisticsMetricsScrollView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [self.statisticsMetricsScrollView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        [self.statisticsMetricsScrollView.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-10]
    ]];
    
    return panel;
}

- (NSView *)createCandlestickChartPanel {
    NSView *panel = [[NSView alloc] init];
    
    // Header with zoom controls
    NSView *headerView = [[NSView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:headerView];
    
    self.dateRangeLabel = [[NSTextField alloc] init];
    self.dateRangeLabel.stringValue = @"Select date range below";
    self.dateRangeLabel.editable = NO;
    self.dateRangeLabel.bordered = NO;
    self.dateRangeLabel.backgroundColor = [NSColor clearColor];
    self.dateRangeLabel.font = [NSFont boldSystemFontOfSize:13];
    self.dateRangeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:self.dateRangeLabel];
    
    self.zoomOutButton = [NSButton buttonWithTitle:@"➖" target:self action:@selector(zoomOutChart:)];
    self.zoomOutButton.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:self.zoomOutButton];
    
    self.zoomInButton = [NSButton buttonWithTitle:@"➕" target:self action:@selector(zoomInChart:)];
    self.zoomInButton.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:self.zoomInButton];
    
    self.zoomAllButton = [NSButton buttonWithTitle:@"ALL" target:self action:@selector(zoomAllChart:)];
    self.zoomAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:self.zoomAllButton];
    
    // ✅ CREATE ACTUAL CANDLESTICK CHART VIEW
    CandlestickChartView *chartView = [[CandlestickChartView alloc] initWithFrame:NSZeroRect];
    chartView.delegate = self;
    chartView.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:chartView];
    
    // Store reference using container
    [self setCandlestickChartView:chartView];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [headerView.topAnchor constraintEqualToAnchor:panel.topAnchor constant:10],
        [headerView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [headerView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        [headerView.heightAnchor constraintEqualToConstant:30],
        
        [self.dateRangeLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
        [self.dateRangeLabel.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        
        [self.zoomAllButton.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
        [self.zoomAllButton.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        
        [self.zoomInButton.trailingAnchor constraintEqualToAnchor:self.zoomAllButton.leadingAnchor constant:-5],
        [self.zoomInButton.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        
        [self.zoomOutButton.trailingAnchor constraintEqualToAnchor:self.zoomInButton.leadingAnchor constant:-5],
        [self.zoomOutButton.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        
        [chartView.topAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:5],
        [chartView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [chartView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        [chartView.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-10]
    ]];
    
    return panel;
}

- (NSView *)createComparisonChartPanel {
    NSView *panel = [[NSView alloc] init];
    
    // Header
    self.comparisonChartTitleLabel = [[NSTextField alloc] init];
    self.comparisonChartTitleLabel.stringValue = @"Metric Comparison (Select metric on left)";
    self.comparisonChartTitleLabel.editable = NO;
    self.comparisonChartTitleLabel.bordered = NO;
    self.comparisonChartTitleLabel.backgroundColor = [NSColor clearColor];
    self.comparisonChartTitleLabel.font = [NSFont boldSystemFontOfSize:13];
    self.comparisonChartTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:self.comparisonChartTitleLabel];
    
    // ✅ CREATE ACTUAL COMPARISON CHART VIEW
    ComparisonChartView *chartView = [[ComparisonChartView alloc] initWithFrame:NSZeroRect];
    chartView.delegate = self;
    chartView.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:chartView];
    
    // Store reference using container
    [self setComparisonChartView:chartView];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.comparisonChartTitleLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:10],
        [self.comparisonChartTitleLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [self.comparisonChartTitleLabel.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        
        [chartView.topAnchor constraintEqualToAnchor:self.comparisonChartTitleLabel.bottomAnchor constant:5],
        [chartView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [chartView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        [chartView.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-10]
    ]];
    
    return panel;
}
- (NSView *)createBacktestControlBar {
    NSView *controlBar = [[NSView alloc] init];
    
    // Date range pickers
    NSTextField *startLabel = [[NSTextField alloc] init];
    startLabel.stringValue = @"Start Date:";
    startLabel.editable = NO;
    startLabel.bordered = NO;
    startLabel.backgroundColor = [NSColor clearColor];
    startLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [controlBar addSubview:startLabel];
    
    self.backtestStartDatePicker = [[NSDatePicker alloc] init];
    self.backtestStartDatePicker.datePickerStyle = NSDatePickerStyleTextField;
    self.backtestStartDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
    self.backtestStartDatePicker.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Set default to 6 months ago
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *sixMonthsAgo = [calendar dateByAddingUnit:NSCalendarUnitMonth
                                                 value:-6
                                                toDate:[NSDate date]
                                               options:0];
    self.backtestStartDatePicker.dateValue = sixMonthsAgo;
    [controlBar addSubview:self.backtestStartDatePicker];
    
    NSTextField *endLabel = [[NSTextField alloc] init];
    endLabel.stringValue = @"End Date:";
    endLabel.editable = NO;
    endLabel.bordered = NO;
    endLabel.backgroundColor = [NSColor clearColor];
    endLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [controlBar addSubview:endLabel];
    
    self.backtestEndDatePicker = [[NSDatePicker alloc] init];
    self.backtestEndDatePicker.datePickerStyle = NSDatePickerStyleTextField;
    self.backtestEndDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
    self.backtestEndDatePicker.dateValue = [NSDate date];
    self.backtestEndDatePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [controlBar addSubview:self.backtestEndDatePicker];
    
    // Run/Cancel buttons
    self.runBacktestButton = [NSButton buttonWithTitle:@"🚀 RUN BACKTEST"
                                                 target:self
                                                 action:@selector(runBacktest:)];
    self.runBacktestButton.bezelStyle = NSBezelStyleRounded;
    self.runBacktestButton.translatesAutoresizingMaskIntoConstraints = NO;
    [controlBar addSubview:self.runBacktestButton];
    
    self.cancelBacktestButton = [NSButton buttonWithTitle:@"❌ Cancel"
                                                    target:self
                                                    action:@selector(cancelBacktest:)];
    self.cancelBacktestButton.bezelStyle = NSBezelStyleRounded;
    self.cancelBacktestButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cancelBacktestButton.hidden = YES;
    [controlBar addSubview:self.cancelBacktestButton];
    
    // Progress indicator
    self.backtestProgressIndicator = [[NSProgressIndicator alloc] init];
    self.backtestProgressIndicator.style = NSProgressIndicatorStyleBar;
    self.backtestProgressIndicator.indeterminate = NO;
    self.backtestProgressIndicator.minValue = 0.0;
    self.backtestProgressIndicator.maxValue = 1.0;
    self.backtestProgressIndicator.doubleValue = 0.0;
    self.backtestProgressIndicator.hidden = YES;
    self.backtestProgressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [controlBar addSubview:self.backtestProgressIndicator];
    
    // Status label
    self.backtestStatusLabel = [[NSTextField alloc] init];
    self.backtestStatusLabel.stringValue = @"";
    self.backtestStatusLabel.editable = NO;
    self.backtestStatusLabel.bordered = NO;
    self.backtestStatusLabel.backgroundColor = [NSColor clearColor];
    self.backtestStatusLabel.textColor = [NSColor secondaryLabelColor];
    self.backtestStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [controlBar addSubview:self.backtestStatusLabel];
    
    // Layout
    [NSLayoutConstraint activateConstraints:@[
        // First row: Date pickers and buttons
        [startLabel.leadingAnchor constraintEqualToAnchor:controlBar.leadingAnchor constant:10],
        [startLabel.topAnchor constraintEqualToAnchor:controlBar.topAnchor constant:10],
        
        [self.backtestStartDatePicker.leadingAnchor constraintEqualToAnchor:startLabel.trailingAnchor constant:5],
        [self.backtestStartDatePicker.centerYAnchor constraintEqualToAnchor:startLabel.centerYAnchor],
        [self.backtestStartDatePicker.widthAnchor constraintEqualToConstant:120],
        
        [endLabel.leadingAnchor constraintEqualToAnchor:self.backtestStartDatePicker.trailingAnchor constant:20],
        [endLabel.centerYAnchor constraintEqualToAnchor:startLabel.centerYAnchor],
        
        [self.backtestEndDatePicker.leadingAnchor constraintEqualToAnchor:endLabel.trailingAnchor constant:5],
        [self.backtestEndDatePicker.centerYAnchor constraintEqualToAnchor:startLabel.centerYAnchor],
        [self.backtestEndDatePicker.widthAnchor constraintEqualToConstant:120],
        
        [self.runBacktestButton.leadingAnchor constraintEqualToAnchor:self.backtestEndDatePicker.trailingAnchor constant:20],
        [self.runBacktestButton.centerYAnchor constraintEqualToAnchor:startLabel.centerYAnchor],
        [self.runBacktestButton.widthAnchor constraintEqualToConstant:150],
        
        [self.cancelBacktestButton.leadingAnchor constraintEqualToAnchor:self.runBacktestButton.trailingAnchor constant:10],
        [self.cancelBacktestButton.centerYAnchor constraintEqualToAnchor:startLabel.centerYAnchor],
        
        // Second row: Progress bar and status
        [self.backtestProgressIndicator.topAnchor constraintEqualToAnchor:self.runBacktestButton.bottomAnchor constant:10],
        [self.backtestProgressIndicator.leadingAnchor constraintEqualToAnchor:controlBar.leadingAnchor constant:10],
        [self.backtestProgressIndicator.trailingAnchor constraintEqualToAnchor:controlBar.trailingAnchor constant:-10],
        [self.backtestProgressIndicator.heightAnchor constraintEqualToConstant:20],
        
        [self.backtestStatusLabel.topAnchor constraintEqualToAnchor:self.backtestProgressIndicator.bottomAnchor constant:5],
        [self.backtestStatusLabel.leadingAnchor constraintEqualToAnchor:controlBar.leadingAnchor constant:10],
        [self.backtestStatusLabel.trailingAnchor constraintEqualToAnchor:controlBar.trailingAnchor constant:-10]
    ]];
    
    return controlBar;
}

#pragma mark - Actions

- (IBAction)validateBenchmarkSymbol:(id)sender {
    NSString *symbol = [self.benchmarkSymbolField.stringValue uppercaseString];
    
    if (symbol.length == 0) {
        self.symbolValidationLabel.stringValue = @"❌ Please enter a symbol";
        self.symbolValidationLabel.textColor = [NSColor systemRedColor];
        return;
    }
    
    self.symbolValidationLabel.stringValue = @"⏳ Validating...";
    self.symbolValidationLabel.textColor = [NSColor systemOrangeColor];
    
    // Load symbol data to validate
    [self loadBenchmarkSymbolData:symbol];
}

- (IBAction)backtestModelCheckboxChanged:(id)sender {
    // Model checkbox changed - just reload table
    [self.backtestModelsTableView reloadData];
}

- (IBAction)statisticsMetricSelected:(id)sender {
    NSInteger selectedRow = self.statisticsMetricsTableView.selectedRow;
    
    if (selectedRow >= 0 && selectedRow < self.availableStatisticsMetrics.count) {
        self.selectedStatisticMetric = self.availableStatisticsMetrics[selectedRow];
        
        // Update comparison chart title
        self.comparisonChartTitleLabel.stringValue = [NSString stringWithFormat:@"Metric Comparison: %@",
                                                      self.selectedStatisticMetric];
        
        // Update comparison chart data
        if (self.comparisonChartView && self.currentBacktestSession) {
            NSString *metricKey = [self metricKeyForDisplayName:self.selectedStatisticMetric];
            [self.comparisonChartView setMetricKey:metricKey];
        }
        
        NSLog(@"📊 Selected metric: %@", self.selectedStatisticMetric);
    }
}
- (IBAction)runBacktest:(id)sender {
    NSLog(@"🚀 Run Backtest button pressed");
    
    // Validation
    NSArray<ScreenerModel *> *selectedModels = [self getSelectedBacktestModels];
    
    if (selectedModels.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Models Selected";
        alert.informativeText = @"Please select at least one model to test.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert runModal];
        return;
    }
    
    NSDate *startDate = self.backtestStartDatePicker.dateValue;
    NSDate *endDate = self.backtestEndDatePicker.dateValue;
    
    if ([startDate compare:endDate] == NSOrderedDescending) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Invalid Date Range";
        alert.informativeText = @"Start date must be before end date.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert runModal];
        return;
    }
    
    NSString *benchmarkSymbol = [self.benchmarkSymbolField.stringValue uppercaseString];
    if (benchmarkSymbol.length == 0) {
        benchmarkSymbol = @"SPY";
        self.benchmarkSymbolField.stringValue = benchmarkSymbol;
    }
    
    // Calculate maxBars needed
    NSInteger maxBars = [BacktestRunner calculateMaxBarsForModels:selectedModels];
    
    NSLog(@"📊 Starting backtest with:");
    NSLog(@"   Models: %lu", (unsigned long)selectedModels.count);
    NSLog(@"   Date range: %@ to %@", startDate, endDate);
    NSLog(@"   Benchmark: %@", benchmarkSymbol);
    NSLog(@"   Max bars needed: %ld", (long)maxBars);
    
    // Update UI
    [self updateBacktestUIState:YES];
    
    // Load extended data
    self.backtestStatusLabel.stringValue = @"Loading historical data...";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Get all symbols from database
        NSArray<NSString *> *allSymbols = self.dataManager.availableSymbols;
        
        if (!allSymbols || allSymbols.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateBacktestUIState:NO];
                self.backtestStatusLabel.stringValue = @"❌ No symbols available in database";
                
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"No Data Available";
                alert.informativeText = @"Please scan the database in Settings tab first.";
                alert.alertStyle = NSAlertStyleCritical;
                [alert runModal];
            });
            return;
        }
        
        // Load extended data range
        [self.dataManager loadExtendedDataForSymbols:allSymbols
                                           startDate:startDate
                                             endDate:endDate
                                             maxBars:maxBars
                                          completion:^(NSDictionary<NSString *,NSArray<HistoricalBarModel *> *> *cache, NSError *error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || !cache || cache.count == 0) {
                    [self updateBacktestUIState:NO];
                    self.backtestStatusLabel.stringValue = @"❌ Failed to load data";
                    
                    NSAlert *alert = [[NSAlert alloc] init];
                    alert.messageText = @"Data Loading Failed";
                    alert.informativeText = error ? error.localizedDescription : @"No data available";
                    alert.alertStyle = NSAlertStyleCritical;
                    [alert runModal];
                    return;
                }
                
                NSLog(@"✅ Loaded extended data: %lu symbols", (unsigned long)cache.count);
                
                // Store cache
                self.backtestMasterCache = cache;
                
                // Run backtest
                self.backtestStatusLabel.stringValue = @"Running backtest...";
                
                [self.backtestRunner runBacktestForModels:selectedModels
                                                startDate:startDate
                                                  endDate:endDate
                                              masterCache:cache
                                           benchmarkSymbol:benchmarkSymbol];
            });
        }];
    });
}

- (IBAction)cancelBacktest:(id)sender {
    NSLog(@"🛑 Cancel Backtest button pressed");
    [self.backtestRunner cancel];
}



#pragma mark - Helper Methods

- (void)reloadBacktestModelsTable {
    [self.backtestModelsTableView reloadData];
}

- (void)loadBenchmarkSymbolData:(NSString *)symbol {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSArray<HistoricalBarModel *> *bars = [self.dataManager loadBarsForSymbol:symbol minBars:100];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bars && bars.count > 0) {
                self.symbolValidationLabel.stringValue = [NSString stringWithFormat:@"✅ Valid (%lu bars)",
                                                          (unsigned long)bars.count];
                self.symbolValidationLabel.textColor = [NSColor systemGreenColor];
                
                // ✅ FIX: Load data into candlestick chart
                if (self.candlestickChartView) {
                    [self.candlestickChartView setData:bars symbol:symbol];
                    [self.candlestickChartView zoomAll];
                    
                    NSLog(@"✅ Benchmark symbol '%@' validated and loaded: %lu bars", symbol, (unsigned long)bars.count);
                } else {
                    NSLog(@"⚠️ Candlestick chart view is not initialized");
                }
            } else {
                self.symbolValidationLabel.stringValue = @"❌ Symbol not found in database";
                self.symbolValidationLabel.textColor = [NSColor systemRedColor];
            }
        });
    });
}

- (void)updateBacktestUIState:(BOOL)isRunning {
    self.runBacktestButton.enabled = !isRunning;
    self.cancelBacktestButton.hidden = !isRunning;
    self.backtestProgressIndicator.hidden = !isRunning;
    
    if (isRunning) {
        self.backtestProgressIndicator.doubleValue = 0.0;
        [self.backtestProgressIndicator startAnimation:nil];
    } else {
        [self.backtestProgressIndicator stopAnimation:nil];
    }
    
    // Disable controls during backtest
    self.benchmarkSymbolField.enabled = !isRunning;
    self.validateSymbolButton.enabled = !isRunning;
    self.backtestStartDatePicker.enabled = !isRunning;
    self.backtestEndDatePicker.enabled = !isRunning;
    self.backtestModelsTableView.enabled = !isRunning;
}

- (NSArray<ScreenerModel *> *)getSelectedBacktestModels {
    NSMutableArray *selected = [NSMutableArray array];
    
    for (ScreenerModel *model in self.models) {
        if (model.isEnabled) {
            [selected addObject:model];
        }
    }
    
    return [selected copy];
}

#pragma mark - BacktestRunnerDelegate

- (void)backtestRunnerDidStart:(BacktestRunner *)runner {
    NSLog(@"🚀 Backtest started");
    self.backtestStatusLabel.stringValue = @"Preparing backtest...";
}

- (void)backtestRunner:(BacktestRunner *)runner
    didStartPreparationWithMessage:(NSString *)message {
    self.backtestStatusLabel.stringValue = message;
}

- (void)backtestRunner:(BacktestRunner *)runner
    didStartExecutionForDays:(NSInteger)dayCount
                      models:(NSInteger)modelCount {
    
    self.backtestStatusLabel.stringValue = [NSString stringWithFormat:@"Executing: %ld days × %ld models = %ld iterations",
                                            (long)dayCount, (long)modelCount, (long)(dayCount * modelCount)];
}

- (void)backtestRunner:(BacktestRunner *)runner
       didStartDate:(NSDate *)date
          dayNumber:(NSInteger)dayNumber
          totalDays:(NSInteger)totalDays {
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    
    self.backtestStatusLabel.stringValue = [NSString stringWithFormat:@"Processing day %ld/%ld: %@",
                                            (long)dayNumber, (long)totalDays,
                                            [formatter stringFromDate:date]];
}

- (void)backtestRunner:(BacktestRunner *)runner
      didUpdateProgress:(double)progress {
    
    self.backtestProgressIndicator.doubleValue = progress;
}

- (void)backtestRunner:(BacktestRunner *)runner
    didFinishWithSession:(BacktestSession *)session {
    
    NSLog(@"✅ Backtest completed successfully");
    
    [self updateBacktestUIState:NO];
    
    self.currentBacktestSession = session;
    self.backtestStatusLabel.stringValue = [NSString stringWithFormat:@"✅ Completed: %ld results in %.2fs",
                                            (long)session.dailyResults.count,
                                            session.totalExecutionTime];
    
    [self updateChartsWithSession:session];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Backtest Complete";
    alert.informativeText = [NSString stringWithFormat:@"Generated %ld daily results for %ld models.\n\nExecution time: %.2fs",
                            (long)session.dailyResults.count,
                            (long)session.models.count,
                            session.totalExecutionTime];
    alert.alertStyle = NSAlertStyleInformational;
    [alert runModal];
}

#pragma mark - Chart Updates

- (void)updateChartsWithSession:(BacktestSession *)session {
    
    if (!session) {
        NSLog(@"⚠️ Cannot update charts: nil session");
        return;
    }
    
    NSLog(@"📊 Updating charts with backtest session");
    
    // Update candlestick chart with benchmark data
    if (self.candlestickChartView && session.benchmarkBars) {
        [self.candlestickChartView setData:session.benchmarkBars
                                    symbol:session.benchmarkSymbol];
        
        // Zoom to backtest date range
        if (session.startDate && session.endDate) {
            [self.candlestickChartView zoomToDateRange:session.startDate
                                              endDate:session.endDate];
        }
        
        NSLog(@"✅ Updated candlestick chart: %@ (%lu bars)",
              session.benchmarkSymbol, (unsigned long)session.benchmarkBars.count);
    }
    
    // Update comparison chart
    if (self.comparisonChartView) {
        // Use first metric by default if none selected
        if (!self.selectedStatisticMetric) {
            self.selectedStatisticMetric = @"# Symbols";
        }
        
        NSString *metricKey = [self metricKeyForDisplayName:self.selectedStatisticMetric];
        
        [self.comparisonChartView setSession:session
                                  metricKey:metricKey
                                modelColors:session.modelColors];
        
        NSLog(@"✅ Updated comparison chart: %@ metric", self.selectedStatisticMetric);
    }
    
    // Update date range label
    if (session.startDate && session.endDate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        
        self.dateRangeLabel.stringValue = [NSString stringWithFormat:@"%@ → %@",
                                           [formatter stringFromDate:session.startDate],
                                           [formatter stringFromDate:session.endDate]];
    }
}

- (NSString *)metricKeyForDisplayName:(NSString *)displayName {
    NSDictionary *mapping = @{
        @"# Symbols": @"symbolCount",
        @"Win Rate %": @"winRate",
        @"Avg Gain %": @"avgGain",
        @"Avg Loss %": @"avgLoss",
        @"# Trades": @"tradeCount",
        @"Win/Loss Ratio": @"winLossRatio"
    };
    
    return mapping[displayName] ?: @"symbolCount";
}


- (void)backtestRunner:(BacktestRunner *)runner
        didFailWithError:(NSError *)error {
    
    NSLog(@"❌ Backtest failed: %@", error.localizedDescription);
    
    [self updateBacktestUIState:NO];
    
    self.backtestStatusLabel.stringValue = @"❌ Backtest failed";
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Backtest Failed";
    alert.informativeText = error.localizedDescription;
    alert.alertStyle = NSAlertStyleCritical;
    [alert runModal];
}

- (void)backtestRunnerDidCancel:(BacktestRunner *)runner {
    NSLog(@"🛑 Backtest cancelled");
    
    [self updateBacktestUIState:NO];
    
    self.backtestStatusLabel.stringValue = @"🛑 Backtest cancelled";
}


@end
