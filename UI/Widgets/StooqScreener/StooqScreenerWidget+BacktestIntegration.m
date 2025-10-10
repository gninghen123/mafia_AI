//
//  StooqScreenerWidget+BacktestIntegration.m
//  TradingApp
//
//  Integration code for connecting backtest tab components
//  This extends the BacktestTab category with chart integration
//

#import "StooqScreenerWidget+BacktestTab.h"
#import "StooqScreenerWidget+Private.h"  // ← Access to main widget properties
#import "CandlestickChartView.h"
#import "ComparisonChartView.h"
#import <objc/runtime.h>

@implementation StooqScreenerWidget (BacktestIntegration)

#pragma mark - Associated Objects for Chart Views

static char candlestickChartViewKey;
static char comparisonChartViewKey;

- (CandlestickChartView *)candlestickChartView {
    return objc_getAssociatedObject(self, &candlestickChartViewKey);
}

- (void)setCandlestickChartView:(CandlestickChartView *)view {
    objc_setAssociatedObject(self, &candlestickChartViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ComparisonChartView *)comparisonChartView {
    return objc_getAssociatedObject(self, &comparisonChartViewKey);
}

- (void)setComparisonChartView:(ComparisonChartView *)view {
    objc_setAssociatedObject(self, &comparisonChartViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Chart View Setup (Override panel creation methods)

/**
 * Enhanced createCandlestickChartPanel with actual chart view
 * Call this instead of the placeholder version in setupBacktestTab
 */
- (NSView *)createCandlestickChartPanelWithChartView {
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
    
    // Store reference
    self.candlestickChartView = chartView;
    
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

/**
 * Enhanced createComparisonChartPanel with actual chart view
 */
- (NSView *)createComparisonChartPanelWithChartView {
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
    
    // Store reference
    self.comparisonChartView = chartView;
    
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

#pragma mark - Chart Data Updates

/**
 * Update charts with backtest session results
 * Call this when backtest completes
 */
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
            self.selectedStatisticMetric = @"symbolCount";
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

/**
 * Map display name to metric key
 */
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

#pragma mark - Enhanced Actions (Override zoom actions)

- (void)zoomInChart:(id)sender {
    if (self.candlestickChartView) {
        [self.candlestickChartView zoomIn];
        NSLog(@"🔍 Zoom In");
    }
}

- (void)zoomOutChart:(id)sender {
    if (self.candlestickChartView) {
        [self.candlestickChartView zoomOut];
        NSLog(@"🔍 Zoom Out");
    }
}

- (void)zoomAllChart:(id)sender {
    if (self.candlestickChartView) {
        [self.candlestickChartView zoomAll];
        NSLog(@"🔍 Zoom All");
    }
}

#pragma mark - Enhanced Statistics Metric Selection

- (void)statisticsMetricSelected:(id)sender {
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

#pragma mark - Enhanced BacktestRunnerDelegate (Override to update charts)

- (void)backtestRunner:(BacktestRunner *)runner
    didFinishWithSession:(BacktestSession *)session {
    
    NSLog(@"✅ Backtest completed successfully");
    
    [self updateBacktestUIState:NO];
    
    self.currentBacktestSession = session;
    self.backtestStatusLabel.stringValue = [NSString stringWithFormat:@"✅ Completed: %ld results in %.2fs",
                                            (long)session.dailyResults.count,
                                            session.totalExecutionTime];
    
    // ✅ UPDATE CHARTS WITH RESULTS
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

#pragma mark - CandlestickChartViewDelegate

- (void)candlestickChartView:(CandlestickChartView *)chartView
         didSelectDateRange:(NSDate *)startDate
                    endDate:(NSDate *)endDate {
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    
    NSLog(@"📅 User selected date range: %@ → %@",
          [formatter stringFromDate:startDate],
          [formatter stringFromDate:endDate]);
    
    // Update date pickers in control bar
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
    
    // Coordinate crosshair with comparison chart
    if (self.comparisonChartView && date) {
        // Find X position in comparison chart for this date
        // For now, just notify the comparison chart to update
        // The comparison chart will handle finding the correct X position
        
        // This is a simplified approach - for pixel-perfect coordination,
        // we'd need to calculate the exact X position based on date
    }
}

#pragma mark - ComparisonChartViewDelegate

- (void)comparisonChartView:(ComparisonChartView *)chartView
     didMoveCrosshairToDate:(NSDate *)date {
    
    // Coordinate crosshair with candlestick chart
    if (self.candlestickChartView && date) {
        // For now, we'll let each chart handle its own crosshair
        // For pixel-perfect coordination, we'd need to:
        // 1. Find the X position of this date in candlestick chart
        // 2. Call [self.candlestickChartView showCrosshairAtX:x]
    }
}

@end
