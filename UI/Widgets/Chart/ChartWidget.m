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
#import "TradingDaysUtility.h"
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
    
    // Load preferences
    self.maxBarsToDisplay = [[NSUserDefaults standardUserDefaults] integerForKey:@"ChartWidget.MaxBars"];
    if (self.maxBarsToDisplay == 0) {
        self.maxBarsToDisplay = 250; // Default value
    }
    
    self.useExtendedHours = [[NSUserDefaults standardUserDefaults] boolForKey:@"ChartWidget.ExtendedHours"];
    
    // NEW: Load right padding preference (default: 5 bars)
    self.rightPaddingBars = [[NSUserDefaults standardUserDefaults] integerForKey:@"ChartWidget.RightPadding"];
    if (self.rightPaddingBars == 0) {
        self.rightPaddingBars = 5; // Default: 5 future trading days
    }
    
    _isLoading = NO;
    
    // Initialize collections
    _panelModels = [NSMutableArray array];
    _panelViews = [NSMutableArray array];
    
    // Create coordinator
    _coordinator = [[ChartCoordinator alloc] init];
    _coordinator.maxVisibleBars = _maxBarsToDisplay;
    
    // Initialize indicators panel controller
    _indicatorsPanelController = [[IndicatorsPanelController alloc] initWithChartWidget:self];
    
    NSLog(@"📊 ChartWidget: Initialized with symbol %@, rightPadding: %ld bars",
          _currentSymbol, (long)self.rightPaddingBars);
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
    
    self.preferencesButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameActionTemplate]
                                                    target:self
                                                    action:@selector(showPreferences:)];
       self.preferencesButton.bezelStyle = NSBezelStyleTexturedRounded;
       self.preferencesButton.translatesAutoresizingMaskIntoConstraints = NO;
       self.preferencesButton.toolTip = @"Chart Preferences";
       [self.toolbarView addSubview:self.preferencesButton];
    
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
    self.panSlider = [[NSSlider alloc] init];
    if (!self.panSlider) {
        NSLog(@"❌ Failed to create panSlider");
        return;
    }
    
    self.panSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.panSlider.minValue = 0.1;
    self.panSlider.maxValue = 10.0;
    self.panSlider.doubleValue = 1.0;
    self.panSlider.continuous = YES;
    self.panSlider.target = self;
    self.panSlider.action = @selector(panSliderChanged:);
    self.panSlider.toolTip = @"Zoom Level";
    [self.zoomControlsView addSubview:self.panSlider];
    
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
    
    if (!self.zoomControlsView || !self.zoomOutButton || !self.panSlider ||
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
            [self.panSlider.leadingAnchor constraintEqualToAnchor:self.zoomControlsView.leadingAnchor constant:16],
            [self.panSlider.trailingAnchor constraintEqualToAnchor:self.zoomOutButton.leadingAnchor constant:-16],
            [self.panSlider.centerYAnchor constraintEqualToAnchor:self.zoomControlsView.centerYAnchor],
            [self.panSlider.heightAnchor constraintEqualToConstant:24]
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
        
              [self.preferencesButton.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-8],
              [self.preferencesButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
              [self.preferencesButton.widthAnchor constraintEqualToConstant:30],
              
              // MODIFICA: indicatorsButton ora va prima di preferencesButton
              [self.indicatorsButton.trailingAnchor constraintEqualToAnchor:self.preferencesButton.leadingAnchor constant:-8],
              [self.indicatorsButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor]
          ]];
    
    [self setupZoomControlsConstraints];
}

#pragma mark - preferences

- (void)showPreferences:(id)sender {
    [self showChartPreferencesPopover:sender];
}

// NEW: Chart preferences popover
- (void)showChartPreferencesPopover:(id)sender {
    NSViewController *prefsController = [[NSViewController alloc] init];
    NSView *contentView = [[NSView alloc] init];
    prefsController.view = contentView;
    
    // Set content view size
    contentView.frame = NSMakeRect(0, 0, 300, 160);
    
    // Create preferences UI
    [self createPreferencesUI:contentView];
    
    // Show popover
    NSPopover *popover = [[NSPopover alloc] init];
    popover.contentViewController = prefsController;
    popover.behavior = NSPopoverBehaviorTransient;
    
    [popover showRelativeToRect:[sender bounds]
                         ofView:sender
                  preferredEdge:NSRectEdgeMinY];
}


// NEW: Create preferences UI
- (void)createPreferencesUI:(NSView *)contentView {
    // Title
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.stringValue = @"Chart Preferences";
    titleLabel.editable = NO;
    titleLabel.bezeled = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.font = [NSFont boldSystemFontOfSize:14];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:titleLabel];
    
    // Max bars label
    NSTextField *barsLabel = [[NSTextField alloc] init];
    barsLabel.stringValue = @"Maximum Bars:";
    barsLabel.editable = NO;
    barsLabel.bezeled = NO;
    barsLabel.backgroundColor = [NSColor clearColor];
    barsLabel.font = [NSFont systemFontOfSize:12];
    barsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:barsLabel];
    
    // Max bars slider
    NSSlider *barsSlider = [[NSSlider alloc] init];
    barsSlider.minValue = 50;
    barsSlider.maxValue = 9999999;
    barsSlider.integerValue = self.maxBarsToDisplay;
    barsSlider.continuous = YES;
    barsSlider.target = self;
    barsSlider.action = @selector(maxBarsSliderChanged:);
    barsSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:barsSlider];
    
    // Max bars value label
    NSTextField *barsValueLabel = [[NSTextField alloc] init];
    barsValueLabel.stringValue = [self formatBarsValue:self.maxBarsToDisplay];
    barsValueLabel.editable = NO;
    barsValueLabel.bezeled = NO;
    barsValueLabel.backgroundColor = [NSColor clearColor];
    barsValueLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    barsValueLabel.alignment = NSTextAlignmentRight;
    barsValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    barsValueLabel.tag = 100; // Tag per trovarlo nell'action
    [contentView addSubview:barsValueLabel];
    
    NSTextField *paddingLabel = [[NSTextField alloc] init];
       paddingLabel.stringValue = @"Right Padding:";
       paddingLabel.editable = NO;
       paddingLabel.selectable = NO;
       paddingLabel.backgroundColor = [NSColor clearColor];
       paddingLabel.bordered = NO;
       paddingLabel.translatesAutoresizingMaskIntoConstraints = NO;
       [contentView addSubview:paddingLabel];
       
       NSSlider *paddingSlider = [[NSSlider alloc] init];
       paddingSlider.minValue = 0;
       paddingSlider.maxValue = 20; // 0-20 future bars
       paddingSlider.integerValue = self.rightPaddingBars;
       paddingSlider.target = self;
       paddingSlider.action = @selector(rightPaddingSliderChanged:);
       paddingSlider.translatesAutoresizingMaskIntoConstraints = NO;
       [contentView addSubview:paddingSlider];
       
       NSTextField *paddingValueLabel = [[NSTextField alloc] init];
       paddingValueLabel.stringValue = [NSString stringWithFormat:@"%ld bars", (long)self.rightPaddingBars];
       paddingValueLabel.editable = NO;
       paddingValueLabel.selectable = NO;
       paddingValueLabel.backgroundColor = [NSColor clearColor];
       paddingValueLabel.bordered = NO;
       paddingValueLabel.tag = 101; // For finding in slider action
       paddingValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
       [contentView addSubview:paddingValueLabel];
    
    
    // Extended hours checkbox
    NSButton *extendedHoursCheckbox = [NSButton checkboxWithTitle:@"Include Extended Hours Data"
                                                           target:self
                                                           action:@selector(extendedHoursChanged:)];
    extendedHoursCheckbox.state = self.useExtendedHours ? NSControlStateValueOn : NSControlStateValueOff;
    extendedHoursCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:extendedHoursCheckbox];
    
    // Apply button
    NSButton *applyButton = [NSButton buttonWithTitle:@"Apply" target:self action:@selector(applyPreferences:)];
    applyButton.bezelStyle = NSBezelStyleRounded;
    applyButton.keyEquivalent = @"\r";
    applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:applyButton];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Title
        [titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16],
        [titleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        
        // Bars label
        [barsLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:20],
        [barsLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        
        // Bars value label
        [barsValueLabel.centerYAnchor constraintEqualToAnchor:barsLabel.centerYAnchor],
        [barsValueLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [barsValueLabel.widthAnchor constraintEqualToConstant:80],
        
        // Bars slider
        [barsSlider.topAnchor constraintEqualToAnchor:barsLabel.bottomAnchor constant:8],
        [barsSlider.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [barsSlider.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        
        
        // NEW: Right padding controls
              [paddingLabel.topAnchor constraintEqualToAnchor:barsSlider.bottomAnchor constant:16],
              [paddingLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
              
              [paddingValueLabel.topAnchor constraintEqualToAnchor:barsSlider.bottomAnchor constant:16],
              [paddingValueLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
              
              [paddingSlider.topAnchor constraintEqualToAnchor:paddingLabel.bottomAnchor constant:8],
              [paddingSlider.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
              [paddingSlider.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        
        
        // Extended hours checkbox
        [extendedHoursCheckbox.topAnchor constraintEqualToAnchor:barsSlider.bottomAnchor constant:16],
        [extendedHoursCheckbox.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        
        // Apply button
        [applyButton.topAnchor constraintEqualToAnchor:extendedHoursCheckbox.bottomAnchor constant:16],
        [applyButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [applyButton.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-16]
    ]];
}

// NEW: Format bars value for display
- (NSString *)formatBarsValue:(NSInteger)value {
    if (value >= 9999999) {
        return @"Max Available";
    } else if (value >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", value / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%ld", (long)value];
    }
}

// NEW: Max bars slider action
- (void)maxBarsSliderChanged:(NSSlider *)sender {
    self.maxBarsToDisplay = sender.integerValue;
    
    // Update value label
    NSTextField *valueLabel = [sender.superview viewWithTag:100];
    if (valueLabel) {
        valueLabel.stringValue = [self formatBarsValue:self.maxBarsToDisplay];
    }
}

// NEW: Extended hours checkbox action
- (void)extendedHoursChanged:(NSButton *)sender {
    self.useExtendedHours = (sender.state == NSControlStateValueOn);
}

- (void)applyPreferences:(id)sender {
    // Save preferences to user defaults
    [[NSUserDefaults standardUserDefaults] setInteger:self.maxBarsToDisplay forKey:@"ChartWidget.MaxBars"];
    [[NSUserDefaults standardUserDefaults] setBool:self.useExtendedHours forKey:@"ChartWidget.ExtendedHours"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.rightPaddingBars forKey:@"ChartWidget.RightPadding"]; // NEW
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Sync coordinator with new preferences
    if (self.coordinator) {
        self.coordinator.maxVisibleBars = self.maxBarsToDisplay;
        
        // Re-process current data with new padding
        if (self.historicalData && self.historicalData.count > 0) {
            // Remove old padding and re-add with new settings
            NSArray<HistoricalBarModel *> *originalBars = [self removeRightPaddingFromBars:self.historicalData];
            [self processHistoricalData:originalBars];
        }
    }
    
    // Close popover
    NSView *contentView = [(NSButton *)sender superview];
    NSViewController *controller = nil;
    NSResponder *responder = contentView.nextResponder;
    while (responder && ![responder isKindOfClass:[NSViewController class]]) {
        responder = responder.nextResponder;
    }
    if ([responder isKindOfClass:[NSViewController class]]) {
        controller = (NSViewController *)responder;
        if (controller.presentingViewController) {
            [controller dismissViewController:controller];
        }
    }
    
    // Refresh chart with new settings
    [self refreshCurrentData];
    
    NSLog(@"Chart preferences applied: maxBars=%ld, extendedHours=%@, rightPadding=%ld, coordinator.maxVisibleBars=%ld",
          (long)self.maxBarsToDisplay, self.useExtendedHours ? @"YES" : @"NO",
          (long)self.rightPaddingBars, (long)self.coordinator.maxVisibleBars);
}


- (void)syncCoordinatorWithPreferences {
    if (self.coordinator) {
        self.coordinator.maxVisibleBars = self.maxBarsToDisplay;
        NSLog(@"📊 ChartWidget: Synced coordinator maxVisibleBars to %ld", (long)self.maxBarsToDisplay);
    }
}

// NUOVO: Override del setter per maxBarsToDisplay per mantenere sync
- (void)setMaxBarsToDisplay:(NSInteger)maxBarsToDisplay {
    if (_maxBarsToDisplay != maxBarsToDisplay) {
        _maxBarsToDisplay = maxBarsToDisplay;
        
        // Sincronizza automaticamente il coordinator
        if (self.coordinator) {
            self.coordinator.maxVisibleBars = maxBarsToDisplay;
            NSLog(@"📊 ChartWidget: Auto-synced coordinator maxVisibleBars to %ld", (long)maxBarsToDisplay);
        }
    }
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
    
    BarTimeframe timeframe = [self timeframeEnumForIndex:self.selectedTimeframe];
    
    NSLog(@"📈 ChartWidget: Loading data for %@ timeframe %ld (maxBars: %ld, extended: %@)",
          symbol, (long)timeframe, (long)self.maxBarsToDisplay, self.useExtendedHours ? @"YES" : @"NO");
    
    // CAMBIAMENTO: Passa extended hours setting al DataHub
    [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                       timeframe:timeframe
                                        barCount:self.maxBarsToDisplay  // USA le preferences
                                      completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            [self.loadingIndicator stopAnimation:nil];
            self.refreshButton.enabled = YES;
            
            if (!bars || bars.count == 0) {
                NSLog(@"⚠️ ChartWidget: No data received for %@", symbol);
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
        // NUOVO: Sincronizza maxVisibleBars con preferences
        self.coordinator.maxVisibleBars = self.maxBarsToDisplay;
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
    
    NSLog(@"📊 ChartWidget: Updated coordinator maxVisibleBars=%ld, %lu panels with %lu data points",
          (long)self.maxBarsToDisplay, (unsigned long)self.panelViews.count, (unsigned long)(data ? data.count : 0));
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
    if (!self.coordinator || !self.historicalData) {
         NSLog(@"⚠️ Cannot zoom: missing coordinator or data");
         return;
     }
     
     // Aumenta visible bars (diminuisce zoom factor)
     NSRange currentRange = self.coordinator.visibleBarsRange;
     NSInteger newVisibleBars = MIN(self.maxBarsToDisplay, currentRange.length * 1.5); // USA maxBarsToDisplay
     
     if (newVisibleBars <= currentRange.length) {
         NSLog(@"🚫 Already at minimum zoom (max bars: %ld)", (long)self.maxBarsToDisplay);
         return;
     }
     
     // Calcola nuovo range mantenendo il centro
     NSInteger centerBar = currentRange.location + currentRange.length / 2;
     NSInteger newStart = centerBar - newVisibleBars / 2;
     newStart = MAX(0, newStart);
     
     if (newStart + newVisibleBars > self.historicalData.count) {
         newStart = MAX(0, self.historicalData.count - newVisibleBars);
         newVisibleBars = MIN(newVisibleBars, self.historicalData.count - newStart);
     }
     
     self.coordinator.visibleBarsRange = NSMakeRange(newStart, newVisibleBars);
     // NUOVO: Calcola zoom factor rispetto a maxBarsToDisplay
     self.coordinator.zoomFactor = (CGFloat)self.maxBarsToDisplay / newVisibleBars;
     
     [self updatePanSliderRange];
     [self refreshAllPanels];
     
     NSLog(@"🔍 Zoom Out: %@ (factor %.2f, max bars: %ld)",
           NSStringFromRange(self.coordinator.visibleBarsRange), self.coordinator.zoomFactor, (long)self.maxBarsToDisplay);
 }


- (IBAction)zoomInButtonClicked:(id)sender {
    if (!self.coordinator || !self.historicalData) {
           NSLog(@"⚠️ Cannot zoom: missing coordinator or data");
           return;
       }
       
       // Diminuisce visible bars (aumenta zoom factor)
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
       
       if (newStart + newVisibleBars > self.historicalData.count) {
           newStart = MAX(0, self.historicalData.count - newVisibleBars);
       }
       
       self.coordinator.visibleBarsRange = NSMakeRange(newStart, newVisibleBars);
       // NUOVO: Calcola zoom factor rispetto a maxBarsToDisplay (non maxVisibleBars)
       self.coordinator.zoomFactor = (CGFloat)self.maxBarsToDisplay / newVisibleBars;
       
       [self updatePanSliderRange];
       [self refreshAllPanels];
       
       NSLog(@"🔍 Zoom In: %@ (factor %.2f, max bars: %ld)",
             NSStringFromRange(self.coordinator.visibleBarsRange), self.coordinator.zoomFactor, (long)self.maxBarsToDisplay);
   }


- (IBAction)panSliderChanged:(id)sender {
    NSLog(@"🔄 Pan slider changed to %.2f", self.panSlider.doubleValue);
    
    // LO SLIDER È PER IL PANNING, NON ZOOM!
    if (!self.historicalData || self.historicalData.count == 0) return;
    
    NSRange currentRange = self.coordinator.visibleBarsRange;
    NSInteger totalBars = self.historicalData.count;
    NSInteger maxStart = MAX(0, totalBars - currentRange.length);
    
    // Slider value da 0.0 a 1.0 rappresenta la posizione nella timeline
    double sliderValue = self.panSlider.doubleValue;
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
    if (!self.panSlider || !self.historicalData || self.historicalData.count == 0) {
        return;
    }
    
    NSInteger totalBars = self.historicalData.count;
    NSInteger visibleBars = self.coordinator.maxVisibleBars;
    
    // Calculate the scrollable range
    // User can pan from showing first bars to showing last bars
    NSInteger maxPanPosition = MAX(0, totalBars - visibleBars);
    
    // Update slider range
    self.panSlider.minValue = 0;
    self.panSlider.maxValue = maxPanPosition;
    
    // Set current position (usually at the end to show latest data)
    NSInteger currentPosition = MAX(0, totalBars - visibleBars);
    self.panSlider.integerValue = currentPosition;
    
    // Update coordinator
    if (self.coordinator) {
        self.coordinator.startIndex = currentPosition;
    }
    
    NSLog(@"📊 ChartWidget: Updated pan slider range: 0-%ld (total: %ld, visible: %ld, padding: %ld)",
          (long)maxPanPosition, (long)totalBars, (long)visibleBars, (long)self.rightPaddingBars);
}
        

#pragma mark - Right Padding Setup


#pragma mark - Data Processing with Padding

- (void)processHistoricalData:(NSArray<HistoricalBarModel *> *)bars {
    if (!bars || bars.count == 0) {
        self.historicalData = @[];
        [self updateAllPanels];
        return;
    }
    
    // Sort bars by date (should already be sorted, but ensure it)
    NSArray<HistoricalBarModel *> *sortedBars = [bars sortedArrayUsingComparator:^NSComparisonResult(HistoricalBarModel *bar1, HistoricalBarModel *bar2) {
        return [bar1.date compare:bar2.date];
    }];
    
    // Create padded data with future trading days
    NSArray<HistoricalBarModel *> *paddedBars = [self addRightPaddingToBars:sortedBars];
    
    self.historicalData = paddedBars;
    
    // Update coordinator with new data
    if (self.coordinator) {
        // FIXED: Use correct method name
        [self.coordinator updateHistoricalData:paddedBars];
        [self.coordinator autoFitToData];
    }
    
    [self updateAllPanels];
    
    NSLog(@"📊 ChartWidget: Processed %lu bars + %ld padding = %lu total bars for %@",
          (unsigned long)sortedBars.count, (long)self.rightPaddingBars, (unsigned long)paddedBars.count, self.currentSymbol);
}

- (NSArray<HistoricalBarModel *> *)addRightPaddingToBars:(NSArray<HistoricalBarModel *> *)originalBars {
    if (!originalBars || originalBars.count == 0 || self.rightPaddingBars <= 0) {
        return originalBars;
    }
    
    HistoricalBarModel *lastBar = originalBars.lastObject;
    if (!lastBar || !lastBar.date) {
        return originalBars;
    }
    
    // Get future trading days based on the timeframe
    NSArray<NSDate *> *futureDates = [self getFutureTradingDatesFromDate:lastBar.date
                                                                   count:self.rightPaddingBars
                                                               timeframe:lastBar.timeframe];
    
    NSMutableArray<HistoricalBarModel *> *paddedBars = [originalBars mutableCopy];
    
    // Create padding bars with future dates
    for (NSDate *futureDate in futureDates) {
        HistoricalBarModel *paddingBar = [self createPaddingBarWithDate:futureDate
                                                               lastPrice:lastBar.close
                                                               timeframe:lastBar.timeframe
                                                                  symbol:lastBar.symbol];
        [paddedBars addObject:paddingBar];
    }
    
    NSLog(@"📅 ChartWidget: Added %lu padding bars from %@ to %@",
          (unsigned long)futureDates.count, lastBar.date, futureDates.lastObject);
    
    return [paddedBars copy];
}

- (NSArray<NSDate *> *)getFutureTradingDatesFromDate:(NSDate *)startDate
                                                count:(NSInteger)count
                                            timeframe:(BarTimeframe)timeframe {
    if (!startDate || count <= 0) return @[];
    
    NSMutableArray<NSDate *> *futureDates = [NSMutableArray array];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *currentDate = startDate;
    
    // Calculate the time interval for the timeframe
    NSTimeInterval timeframeDuration = [self getTimeframeDuration:timeframe];
    
    NSInteger collected = 0;
    while (collected < count) {
        // Move to next period
        currentDate = [currentDate dateByAddingTimeInterval:timeframeDuration];
        
        // For daily and higher timeframes, ensure we only get trading days
        if (timeframe >= BarTimeframe1Day) {
            if ([TradingDaysUtility isTradingDay:currentDate]) {
                [futureDates addObject:currentDate];
                collected++;
            }
        } else {
            // For intraday, add all periods (market hours logic could be added later)
            [futureDates addObject:currentDate];
            collected++;
        }
    }
    
    return [futureDates copy];
}

- (NSTimeInterval)getTimeframeDuration:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:   return 60;           // 1 minute
        case BarTimeframe5Min:   return 300;          // 5 minutes
        case BarTimeframe15Min:  return 900;          // 15 minutes
        case BarTimeframe30Min:  return 1800;         // 30 minutes
        case BarTimeframe1Hour:  return 3600;         // 1 hour
        case BarTimeframe4Hour:  return 14400;        // 4 hours
        case BarTimeframe1Day:   return 86400;        // 1 day
        case BarTimeframe1Week:  return 604800;       // 1 week
        case BarTimeframe1Month: return 2592000;      // 30 days (approximate)
        default:                 return 86400;        // Default to 1 day
    }
}

- (HistoricalBarModel *)createPaddingBarWithDate:(NSDate *)date
                                       lastPrice:(double)lastPrice
                                       timeframe:(BarTimeframe)timeframe
                                          symbol:(NSString *)symbol {
    HistoricalBarModel *paddingBar = [[HistoricalBarModel alloc] init];
    
    paddingBar.symbol = symbol;
    paddingBar.date = date;
    paddingBar.timeframe = timeframe;
    
    // Padding bars have no OHLCV data - they're just placeholders for future dates
    paddingBar.open = 0.0;
    paddingBar.high = 0.0;
    paddingBar.low = 0.0;
    paddingBar.close = 0.0;
    paddingBar.adjustedClose = 0.0;
    paddingBar.volume = 0;
    
    // Mark as padding bar (can be used by renderers to handle differently)
    paddingBar.isPaddingBar = YES; // Assuming we add this property to HistoricalBarModel
    
    return paddingBar;
}

- (void)rightPaddingSliderChanged:(NSSlider *)sender {
    self.rightPaddingBars = sender.integerValue;
    
    // Update value label
    NSTextField *valueLabel = [sender.superview viewWithTag:101];
    if (valueLabel) {
        if (self.rightPaddingBars == 0) {
            valueLabel.stringValue = @"No padding";
        } else {
            valueLabel.stringValue = [NSString stringWithFormat:@"%ld bar%@",
                                     (long)self.rightPaddingBars,
                                     self.rightPaddingBars == 1 ? @"" : @"s"];
        }
    }
}


#pragma mark - Utility Methods

- (NSArray<HistoricalBarModel *> *)removeRightPaddingFromBars:(NSArray<HistoricalBarModel *> *)paddedBars {
    if (!paddedBars || paddedBars.count == 0) return paddedBars;
    
    NSMutableArray<HistoricalBarModel *> *originalBars = [NSMutableArray array];
    
    for (HistoricalBarModel *bar in paddedBars) {
        // Assuming we add isPaddingBar property to HistoricalBarModel
        if (!bar.isPaddingBar) {
            [originalBars addObject:bar];
        }
    }
    
    return [originalBars copy];
}




@end

