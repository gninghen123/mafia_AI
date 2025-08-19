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
#import "ChartWidget+SaveData.h"


#pragma mark - Smart Symbol Input Parameters

// Structure per i parametri parsati dal simbolo
typedef struct {
    NSString *symbol;
    ChartTimeframe timeframe;
    NSInteger daysToDownload;       // Sempre in giorni
    BOOL hasTimeframe;
    BOOL hasDaysSpecified;
    NSDate *startDate;              // Calcolato dal parsing
    NSDate *endDate;                // Sempre "domani" per includere oggi
} SmartSymbolParameters;


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

@property (nonatomic, strong) ChartPreferencesWindow *preferencesWindowController;


@end

@implementation ChartWidget

#pragma mark - BaseWidget Override

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        [self setupChartDefaults];
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

- (void)setupTopToolbar {
    // Objects panel toggle (NUOVO - primo elemento)
    self.objectsPanelToggle = [[NSButton alloc] init];
    self.objectsPanelToggle.title = @"📊";
    self.objectsPanelToggle.bezelStyle = NSBezelStyleRounded;
    self.objectsPanelToggle.state = NSControlStateValueOff;
    self.objectsPanelToggle.target = self;
    self.objectsPanelToggle.action = @selector(toggleObjectsPanel:);
    self.objectsPanelToggle.toolTip = @"Toggle Objects Panel";
    [self.contentView addSubview:self.objectsPanelToggle];
    
    // Symbol text field
    self.symbolTextField = [[NSTextField alloc] init];
    self.symbolTextField.stringValue = @"";
    self.symbolTextField.placeholderString = @"Symbol";
    self.symbolTextField.delegate = self;
    [self.contentView addSubview:self.symbolTextField];
    
    // ✅ NEW: StaticMode toggle button
       self.staticModeToggle = [[NSButton alloc] init];
       self.staticModeToggle.title = @"📋";
       self.staticModeToggle.bezelStyle = NSBezelStyleRounded;
       self.staticModeToggle.state = NSControlStateValueOff;
       self.staticModeToggle.target = self;
       self.staticModeToggle.action = @selector(toggleStaticMode:);
       self.staticModeToggle.toolTip = @"Toggle Static Mode (No Data Updates)";
       self.staticModeToggle.wantsLayer = YES;
       [self.contentView addSubview:self.staticModeToggle];
    
    
    // Objects visibility toggle (NUOVO)
    self.objectsVisibilityToggle = [[NSButton alloc] init];
    self.objectsVisibilityToggle.title = @"👁";
    self.objectsVisibilityToggle.bezelStyle = NSBezelStyleRounded;
    self.objectsVisibilityToggle.state = NSControlStateValueOn;
    self.objectsVisibilityToggle.target = self;
    self.objectsVisibilityToggle.action = @selector(toggleAllObjectsVisibility:);
    self.objectsVisibilityToggle.toolTip = @"Toggle Objects Visibility";
    [self.contentView addSubview:self.objectsVisibilityToggle];
    
    // Timeframe segmented control
    self.timeframeSegmented = [[NSSegmentedControl alloc] init];
    self.timeframeSegmented.segmentCount = 8;
    [self.contentView addSubview:self.timeframeSegmented];
    
    // 🆕 NEW: Date Range Slider
       self.dateRangeSlider = [[NSSlider alloc] init];
       self.dateRangeSlider.sliderType = NSSliderTypeLinear;
       self.dateRangeSlider.target = self;
       self.dateRangeSlider.action = @selector(dateRangeSliderChanged:);
       self.dateRangeSlider.continuous = YES;
       [self.contentView addSubview:self.dateRangeSlider];
       
       // 🆕 NEW: Date Range Label
       self.dateRangeLabel = [[NSTextField alloc] init];
       self.dateRangeLabel.editable = NO;
       self.dateRangeLabel.bordered = NO;
       self.dateRangeLabel.backgroundColor = [NSColor clearColor];
       self.dateRangeLabel.font = [NSFont systemFontOfSize:11];
       self.dateRangeLabel.alignment = NSTextAlignmentCenter;
       self.dateRangeLabel.stringValue = @"6 months";
       [self.contentView addSubview:self.dateRangeLabel];
    
    // Template popup (mantieni)
    self.templatePopup = [[NSPopUpButton alloc] init];
    [self.contentView addSubview:self.templatePopup];
    
    // Preferences button (MODIFICATO - ora apre preferences window)
    self.preferencesButton = [[NSButton alloc] init];
    self.preferencesButton.title = @"⚙️";
    self.preferencesButton.bezelStyle = NSBezelStyleRounded;
    self.preferencesButton.target = self;
    self.preferencesButton.action = @selector(showPreferences:);
    self.preferencesButton.toolTip = @"Chart Preferences";
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
    // Disable autoresizing
    self.objectsPanelToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectsVisibilityToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeframeSegmented.translatesAutoresizingMaskIntoConstraints = NO;
    // RIMUOVERE: self.barsCountTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.templatePopup.translatesAutoresizingMaskIntoConstraints = NO;
    self.preferencesButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectsPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.panSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomOutButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomInButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.zoomAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.staticModeToggle.translatesAutoresizingMaskIntoConstraints = NO;

    // Create constraint per split view (per animazione sidebar)
    self.splitViewLeadingConstraint = [self.panelsSplitView.leadingAnchor
                                      constraintEqualToAnchor:self.contentView.leadingAnchor
                                      constant:8];
    
    [NSLayoutConstraint activateConstraints:@[
        // Top toolbar - AGGIORNATO senza barsCountTextField
        [self.objectsPanelToggle.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.objectsPanelToggle.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.objectsPanelToggle.widthAnchor constraintEqualToConstant:32],
        [self.objectsPanelToggle.heightAnchor constraintEqualToConstant:21],
        
        [self.symbolTextField.centerYAnchor constraintEqualToAnchor:self.objectsPanelToggle.centerYAnchor],
              [self.symbolTextField.leadingAnchor constraintEqualToAnchor:self.objectsPanelToggle.trailingAnchor constant:8],
              [self.symbolTextField.widthAnchor constraintEqualToConstant:100],
              [self.symbolTextField.heightAnchor constraintEqualToConstant:21],
              
              // 👉 Static mode toggle subito dopo symbolTextField
              [self.staticModeToggle.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
              [self.staticModeToggle.leadingAnchor constraintEqualToAnchor:self.symbolTextField.trailingAnchor constant:8],
              [self.staticModeToggle.widthAnchor constraintEqualToConstant:32],
              [self.staticModeToggle.heightAnchor constraintEqualToConstant:21],
              
              // Objects visibility toggle spostato a destra dello static toggle
              [self.objectsVisibilityToggle.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
              [self.objectsVisibilityToggle.leadingAnchor constraintEqualToAnchor:self.staticModeToggle.trailingAnchor constant:8],
              [self.objectsVisibilityToggle.widthAnchor constraintEqualToConstant:32],
              [self.objectsVisibilityToggle.heightAnchor constraintEqualToConstant:21],
        
        // Timeframe segments - COLLEGATO DIRETTAMENTE al visibility toggle
        [self.timeframeSegmented.leadingAnchor constraintEqualToAnchor:self.objectsVisibilityToggle.trailingAnchor constant:8],
        [self.timeframeSegmented.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        
        [self.dateRangeSlider.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
             [self.dateRangeSlider.leadingAnchor constraintEqualToAnchor:self.timeframeSegmented.trailingAnchor constant:8],
             [self.dateRangeSlider.widthAnchor constraintEqualToConstant:150],
             [self.dateRangeSlider.heightAnchor constraintEqualToConstant:21],
             
             // 🆕 NEW: Date Range Label - positioned right of slider
             [self.dateRangeLabel.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
             [self.dateRangeLabel.leadingAnchor constraintEqualToAnchor:self.dateRangeSlider.trailingAnchor constant:4],
             [self.dateRangeLabel.widthAnchor constraintEqualToConstant:80],
             [self.dateRangeLabel.heightAnchor constraintEqualToConstant:21],
             
             // Template popup - NOW connected to date range label instead of timeframe
             [self.templatePopup.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
             [self.templatePopup.leadingAnchor constraintEqualToAnchor:self.dateRangeLabel.trailingAnchor constant:8],
             [self.templatePopup.widthAnchor constraintEqualToConstant:100],
        
        
        // Preferences button - INVARIATO (all'estrema destra)
        [self.preferencesButton.centerYAnchor constraintEqualToAnchor:self.symbolTextField.centerYAnchor],
        [self.preferencesButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.preferencesButton.widthAnchor constraintEqualToConstant:30],
        [self.preferencesButton.heightAnchor constraintEqualToConstant:21],
        
        // Objects panel e resto INVARIATO...
        [self.objectsPanel.topAnchor constraintEqualToAnchor:self.panelsSplitView.topAnchor],
        [self.objectsPanel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.objectsPanel.bottomAnchor constraintEqualToAnchor:self.panelsSplitView.bottomAnchor],
        
        [self.panelsSplitView.topAnchor constraintEqualToAnchor:self.symbolTextField.bottomAnchor constant:8],
        self.splitViewLeadingConstraint,
        [self.panelsSplitView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.panelsSplitView.bottomAnchor constraintEqualToAnchor:self.panSlider.topAnchor constant:-8],
        
        // Bottom controls INVARIATI
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
    self.currentSymbol = @"CRCL";
    self.currentTimeframe = ChartTimeframeDaily;
    
    // NUOVO: Default preferences
    self.tradingHoursMode = ChartTradingHoursRegularOnly;
    self.barsToDownload = 1000;
    self.initialBarsToShow = 100;
    // 🆕 NEW: Load default preferences for date ranges
    [self loadDateRangeDefaults];
    
    // 🆕 NEW: Set initial date range for default timeframe (Daily)
    self.currentDateRangeDays = [self getDefaultDaysForTimeframe:ChartTimeframeDaily];
    
    
    self.chartPanels = [NSMutableArray array];
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
    
    
    [self updateDateRangeSliderForTimeframe:self.currentTimeframe];

    // Actions già collegati nei setup dei bottoni:
    // - zoomOutButton -> zoomOut:
    // - zoomInButton -> zoomIn:
    // - zoomAllButton -> zoomAll:
    // - preferencesButton -> showPreferences:
    
}

- (void)ensureRenderersAreSetup {
    for (ChartPanelView *panel in self.chartPanels) {
        
        // ✅ SETUP OBJECTS RENDERER: SOLO per il pannello dei prezzi (security)
        if ([panel.panelType isEqualToString:@"security"]) {
            if (!panel.objectRenderer) {
                [panel setupObjectsRendererWithManager:self.objectsManager];
                NSLog(@"🔧 Setup objects renderer for SECURITY panel only");
            }
        } else {
            // ✅ ASSICURATI che altri pannelli NON abbiano l'objects renderer
            if (panel.objectRenderer) {
                panel.objectRenderer = nil;
                NSLog(@"🚫 Removed objects renderer from %@ panel", panel.panelType);
            }
        }
        
        // ✅ SETUP ALERT RENDERER: Per tutti i pannelli (gli alert possono essere ovunque)
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

- (void)viewDidLoad {
    [super viewDidLoad];
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
    if (self.isStaticMode) {
            NSLog(@"StaticMode: Ignoring DataHub update (static data mode)");
            return;
        }
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

- (IBAction)timeframeChanged:(id)sender {
    if (self.timeframeSegmented.selectedSegment >= 0) {
        ChartTimeframe newTimeframe = (ChartTimeframe)self.timeframeSegmented.selectedSegment;
        
        if (newTimeframe != self.currentTimeframe) {
            self.currentTimeframe = newTimeframe;
            
            // 🆕 NEW: Update date range slider for new timeframe
            [self updateDateRangeSliderForTimeframe:newTimeframe];
            
            // Reload data if we have a symbol
            if (self.currentSymbol && self.currentSymbol.length > 0) {
                [self loadDataWithCurrentSettings];
            }
            
            NSLog(@"📊 Timeframe changed to: %ld", (long)newTimeframe);
        }
    }
}


- (void)zoomIn:(NSButton *)sender {
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger newRange = MAX(10, currentRange / 1.5);
    
    // ✅ NUOVO: Mantieni l'endIndex fisso (barra più recente visualizzata) come punto di riferimento
    NSInteger fixedEndIndex = self.visibleEndIndex;
    NSInteger newStartIndex = fixedEndIndex - newRange;
    
    // Clamp ai limiti validi (solo per startIndex, endIndex rimane fisso)
    if (newStartIndex < 0) {
        newStartIndex = 0;
    }
    
    [self zoomToRange:newStartIndex endIndex:fixedEndIndex];
    
    NSLog(@"🔍➕ Zoom In: fixed end at %ld, new range [%ld-%ld] (pan slider stays same)",
          (long)fixedEndIndex, (long)newStartIndex, (long)fixedEndIndex);
}

- (void)zoomOut:(NSButton *)sender {
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger newRange = MIN(self.chartData.count, currentRange * 1.5);
    
    // ✅ NUOVO: Mantieni l'endIndex fisso (barra più recente visualizzata) come punto di riferimento
    NSInteger fixedEndIndex = self.visibleEndIndex;
    NSInteger newStartIndex = fixedEndIndex - newRange;
    
    // Clamp ai limiti validi (solo per startIndex, endIndex rimane fisso)
    if (newStartIndex < 0) {
        newStartIndex = 0;
    }
    
    [self zoomToRange:newStartIndex endIndex:fixedEndIndex];
    
    NSLog(@"🔍➖ Zoom Out: fixed end at %ld, new range [%ld-%ld] (pan slider stays same)",
          (long)fixedEndIndex, (long)newStartIndex, (long)fixedEndIndex);
}


- (void)zoomAll:(NSButton *)sender {
    [self resetZoom];
}

- (void)panSliderChanged:(NSSlider *)sender {
    if (!self.chartData || self.chartData.count == 0) return;
    
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger totalBars = self.chartData.count;
    double recentDataPercentage = sender.doubleValue / 100.0; // 0.0 = inizio timeline, 1.0 = fine timeline
    
    // ✅ NUOVA LOGICA: Calcola dove posizionare la finestra basandosi sull'estremo più recente desiderato
    NSInteger desiredEndIndex = (NSInteger)((totalBars - 1) * recentDataPercentage);
    NSInteger newStartIndex = desiredEndIndex - currentRange;
    NSInteger newEndIndex = desiredEndIndex;
    
    // Clamp ai limiti validi
    if (newStartIndex < 0) {
        newStartIndex = 0;
        newEndIndex = currentRange;
    } else if (newEndIndex >= totalBars) {
        newEndIndex = totalBars - 1;
        newStartIndex = newEndIndex - currentRange;
    }
    
    [self zoomToRange:newStartIndex endIndex:newEndIndex];
    
    NSLog(@"📅 Timeline position: %.1f%% -> showing bars [%ld-%ld] (most recent at bar %ld)",
          sender.doubleValue, (long)newStartIndex, (long)newEndIndex, (long)newEndIndex);
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
    NSInteger barsCount = self.barsToDownload;
    if (barsCount <= 0) barsCount = 50; // Fallback se non impostato
    
    // ✅ NUOVO: Determina se includere after-hours dalle preferenze
    BOOL needExtendedHours = (self.tradingHoursMode == ChartTradingHoursWithAfterHours);
    
    NSLog(@"📊 ChartWidget: Loading %@ with %ld bars (timeframe: %ld, after-hours: %@)",
          symbol, (long)barsCount, (long)barTimeframe, needExtendedHours ? @"YES" : @"NO");
    
    if (!self.isStaticMode) {
        [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                              timeframe:barTimeframe
                                               barCount:barsCount
                                   needExtendedHours:needExtendedHours
                                             completion:^(NSArray<HistoricalBarModel *> *data, BOOL isFresh) {
               dispatch_async(dispatch_get_main_queue(), ^{
                   if (!data || data.count == 0) {
                       NSLog(@"❌ ChartWidget: No data received for %@", symbol);
                       return;
                   }
                   
                   NSLog(@"✅ ChartWidget: Received %lu bars for %@ (%@, extended-hours: %@)",
                         (unsigned long)data.count, symbol, isFresh ? @"fresh" : @"cached",
                         needExtendedHours ? @"included" : @"excluded");
                   
                   // ✅ DIRETTO: Dataset già completo dal DownloadManager
                   self.chartData = data;
                   
                   [self resetToInitialView];
                   
                   
                   NSLog(@"📊 ChartWidget: Final dataset has %lu bars (auto-completed by DownloadManager)",
                         (unsigned long)data.count);
               });
           }];
        
        
        [self refreshAlertsForCurrentSymbol];
    }else{
        [self showMicroscopeModeNotification];
    }
 
    
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

- (void)showMicroscopeModeNotification {
    // Trova il primo panel per mostrare il messaggio
    ChartPanelView *targetPanel = self.chartPanels.firstObject;
    if (!targetPanel) return;
    
    // Crea messaggio temporaneo
    NSTextField *notificationLabel = [[NSTextField alloc] init];
    notificationLabel.stringValue = @"🔬 MICROSCOPE MODE - Static Data";
    notificationLabel.font = [NSFont boldSystemFontOfSize:14];
    notificationLabel.textColor = [NSColor systemBlueColor];
    notificationLabel.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.1];
    notificationLabel.bordered = YES;
    notificationLabel.bezeled = YES;
    notificationLabel.editable = NO;
    notificationLabel.selectable = NO;
    notificationLabel.alignment = NSTextAlignmentCenter;
    
    // Posiziona al centro del panel
    notificationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [targetPanel addSubview:notificationLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [notificationLabel.centerXAnchor constraintEqualToAnchor:targetPanel.centerXAnchor],
        [notificationLabel.topAnchor constraintEqualToAnchor:targetPanel.topAnchor constant:10],
        [notificationLabel.widthAnchor constraintEqualToConstant:250],
        [notificationLabel.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // Rimuovi dopo 3 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [notificationLabel removeFromSuperview];
    });
    
    NSLog(@"🔬 Showed microscope mode notification to user");
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
    if (!self.chartData || self.chartData.count == 0) return;
    
    // ✅ FIX: Clamp indices ai valori validi dell'array
    startIndex = MAX(0, startIndex);
    endIndex = MIN(self.chartData.count , endIndex);  // ❌ ERA: self.chartData.count
    
    // ✅ VERIFICA: Ensure valid range
    if (startIndex >= endIndex) {
        NSLog(@"⚠️ Invalid zoom range: start=%ld >= end=%ld, data count=%ld",
              (long)startIndex, (long)endIndex, (long)self.chartData.count);
        return;
    }
    
    self.visibleStartIndex = startIndex;
    self.visibleEndIndex = endIndex;
    
    [self updateViewport];
    [self synchronizePanels];
    
    NSLog(@"📊 Zoom applied: [%ld-%ld] (%ld bars visible, data=%ld bars total)",
          (long)startIndex, (long)endIndex,
          (long)(endIndex - startIndex + 1), (long)self.chartData.count);
}

- (void)resetZoom {
    if (!self.chartData || self.chartData.count == 0) return;
    
    // ✅ FIX: endIndex corretto
    [self zoomToRange:0 endIndex:self.chartData.count ];  // ❌ ERA: self.chartData.count
}
#pragma mark - Helper Methods

- (void)resetToInitialView {
    if (!self.chartData || self.chartData.count == 0) return;
        
    NSInteger totalBars = self.chartData.count;
    NSInteger barsToShow = totalBars;
    NSInteger startIndex = 0;
   
    if (!self.isStaticMode) {
         barsToShow = MIN(self.initialBarsToShow, totalBars);
         startIndex = MAX(0, totalBars - barsToShow);
    }
    // ✅ FIX: endIndex corretto (ultimo elemento valido)
    NSInteger endIndex = totalBars;  // ❌ ERA: totalBars (fuori range)
    
    [self zoomToRange:startIndex endIndex:endIndex];
    
    NSLog(@"📅 Reset to initial view: [%ld-%ld] showing %ld recent bars",
          (long)startIndex, (long)endIndex, (long)barsToShow);
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
    
    // ✅ NUOVA LOGICA: Calcola la posizione basandosi sull'ESTREMO PIÙ RECENTE dei dati visibili
    NSInteger totalBars = self.chartData.count;
    
    // Percentuale della timeline raggiunta dall'estremo destro (più recente) della finestra visibile
    double recentDataPercentage = (double)self.visibleEndIndex / (totalBars - 1);
    recentDataPercentage = MAX(0.0, MIN(1.0, recentDataPercentage));
    
    // Aggiorna slider senza triggerare l'action
    id originalTarget = self.panSlider.target;
    self.panSlider.target = nil;
    [self.panSlider setDoubleValue:recentDataPercentage * 100.0];
    self.panSlider.target = originalTarget;
    
    NSLog(@"📅 Timeline slider updated: %.1f%% (most recent visible: bar %ld of %ld)",
          recentDataPercentage * 100.0, (long)self.visibleEndIndex, (long)(totalBars - 1));
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
    [self addSaveDataMenuItemsToMenu:menu];

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




// ======== AGGIUNGI metodi delegate per symbolTextField ========
#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *textField = [notification object];
    
    // Verifica se è il titleComboBox di BaseWidget
    if (textField == self.titleComboBox) {
        [super controlTextDidEndEditing:notification];
        return;
    }
    
    // ✅ NUOVO: Gestisci smart symbol text field
    if (textField == self.symbolTextField) {
        NSString *inputText = [textField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (inputText.length > 0) {
            [self processSmartSymbolInput:inputText];
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
    
    // Store data reference
    self.chartData = data;
    
    // ✅ FIX: Calculate visible range CORRETTAMENTE
    NSInteger dataCount = data.count;
    NSInteger barsToShow = MIN(self.initialBarsToShow, dataCount);
    
    // ✅ CORREZIONE CRUCIALE: endIndex deve essere l'ultimo elemento valido, non oltre
    self.visibleStartIndex = MAX(0, dataCount - barsToShow);
    self.visibleEndIndex = dataCount - 1;  // ❌ ERA: dataCount (fuori range)
    
    NSLog(@"📊 Setting initial viewport - Data: %ld bars, Showing: [%ld-%ld] (%ld bars visible)",
          (long)dataCount, (long)self.visibleStartIndex, (long)self.visibleEndIndex,
          (long)(self.visibleEndIndex - self.visibleStartIndex + 1));
    
    // Calculate Y range if not overridden
    if (!self.isYRangeOverridden) {
        double minPrice = CGFLOAT_MAX;
        double maxPrice = CGFLOAT_MIN;
        
        // ✅ FIX: Ensure we don't exceed array bounds
        NSInteger endIndex = MIN(self.visibleEndIndex, dataCount - 1);
        
        // Find min/max in visible range
        for (NSInteger i = self.visibleStartIndex; i <= endIndex; i++) {
            HistoricalBarModel *bar = data[i];
            minPrice = MIN(minPrice, bar.low);
            maxPrice = MAX(maxPrice, bar.high);
        }
        
        // Add 5% padding
        double range = maxPrice - minPrice;
        double padding = range * 0.05;
        
        self.yRangeMin = minPrice - padding;
        self.yRangeMax = maxPrice + padding;
        
        // Ensure non-zero range
        if (self.yRangeMax <= self.yRangeMin) {
            self.yRangeMin = minPrice - 1.0;
            self.yRangeMax = maxPrice + 1.0;
        }
        
        NSLog(@"📊 Y-Range calculated: %.2f - %.2f (padding: %.2f)",
              self.yRangeMin, self.yRangeMax, padding);
    }
    
    // Update all panels with new data and viewport
    [self updateViewport];
    [self synchronizePanels];
    
    NSLog(@"✅ Chart data updated successfully - %ld bars loaded, viewport: [%ld-%ld]",
          (long)dataCount, (long)self.visibleStartIndex, (long)self.visibleEndIndex);
}

// ============================================================
// NUOVO: Public Symbol Access Method
// ============================================================

- (NSString *)getCurrentSymbol {
    return self.currentSymbol;
}


#pragma mark - Preferences Management

- (IBAction)showPreferences:(id)sender {
    self.preferencesWindowController = [[ChartPreferencesWindow alloc] initWithChartWidget:self];
    [self.preferencesWindowController showPreferencesWindow];
    NSLog(@"🛠️ Chart preferences window opened");
}

- (void)preferencesDidChange:(BOOL)needsDataReload {
    NSLog(@"⚙️ Chart preferences changed - Data reload needed: %@", needsDataReload ? @"YES" : @"NO");
    
    if (needsDataReload) {
        // Ricarica dati con nuove impostazioni trading hours
        if (self.currentSymbol) {
            [self loadSymbol:self.currentSymbol];
        }
        
        // Notifica tutti i renderer del cambio context
        [self updateAllRenderersContext];
    } else {
        // Solo aggiornamenti UI senza ricarica dati
        if (self.chartData) {
                    [self updatePanelsWithData:self.chartData]; // ✅ CORREZIONE: usa updatePanelsWithData:
                }    }
}

- (void)updateAllRenderersContext {
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.objectRenderer) {
            // Gli object renderer useranno le nuove preferenze per calcolare coordinate X
            [panel.objectRenderer invalidateObjectsLayer];
            NSLog(@"🔄 Updated object renderer context for panel %@", panel.panelType);
        }
    }
}

- (NSInteger)barsPerDayForCurrentTimeframe {
    NSInteger timeframeMinutes = [self getCurrentTimeframeInMinutes];
    
    // ✅ FIX: Gestione speciale per timeframe Daily+
    if (self.currentTimeframe >= ChartTimeframeDaily) {
        return 1; // 1 barra per giorno di trading
    }
    
    switch (self.tradingHoursMode) {
        case ChartTradingHoursRegularOnly:
            // Regular hours: 09:30-16:00 = 6.5 ore = 390 minuti
            return 390 / timeframeMinutes;
            
        case ChartTradingHoursWithAfterHours:
            // ✅ FIX: After-hours realistici
            // Pre-market: 04:00-09:30 = 5.5 ore = 330 minuti
            // Regular: 09:30-16:00 = 6.5 ore = 390 minuti
            // After-hours: 16:00-20:00 = 4 ore = 240 minuti
            // Totale: 15 ore = 900 minuti (non 24 ore!)
            return 900 / timeframeMinutes;
    }
}

- (NSInteger)getCurrentTimeframeInMinutes {
    switch (self.currentTimeframe) {
        case ChartTimeframe1Min: return 1;
        case ChartTimeframe5Min: return 5;
        case ChartTimeframe15Min: return 15;
        case ChartTimeframe30Min: return 30;
        case ChartTimeframe1Hour: return 60;
        case ChartTimeframe4Hour: return 240;
        
        // ✅ FIX: Per Daily+ restituisci valori che hanno senso per i calcoli
        case ChartTimeframeDaily: return 390;    // Trading minutes in a day
        case ChartTimeframeWeekly: return 1950;  // Trading minutes in a week (5 * 390)
        case ChartTimeframeMonthly: return 8190; // Trading minutes in a month (~21 * 390)
        
        default: return 390; // Default to daily trading minutes
    }
}

#pragma mark - State Serialization


- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    if (self.currentSymbol) {
        state[@"currentSymbol"] = self.currentSymbol;
    }
    
    state[@"timeframe"] = @(self.currentTimeframe);
    state[@"tradingHoursMode"] = @(self.tradingHoursMode);  // NUOVO
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
    
    // NUOVO: Restore trading hours mode
    NSNumber *tradingHoursMode = state[@"tradingHoursMode"];
    if (tradingHoursMode) {
        self.tradingHoursMode = tradingHoursMode.integerValue;
    }
    
    NSNumber *barsToDownload = state[@"barsToDownload"];
    if (barsToDownload) {
        self.barsToDownload = barsToDownload.integerValue;
    }
    
    NSNumber *initialBarsToShow = state[@"initialBarsToShow"];
    if (initialBarsToShow) {
        self.initialBarsToShow = initialBarsToShow.integerValue;
    }

    self.isYRangeOverridden = [state[@"isYRangeOverridden"] boolValue];
}

- (void)logViewportState {
    NSLog(@"🔍 Viewport State Debug:");
    NSLog(@"   - Data count: %ld", (long)self.chartData.count);
    NSLog(@"   - Visible range: [%ld-%ld]", (long)self.visibleStartIndex, (long)self.visibleEndIndex);
    NSLog(@"   - Visible bars: %ld", (long)(self.visibleEndIndex - self.visibleStartIndex + 1));
    NSLog(@"   - Y range: %.2f - %.2f", self.yRangeMin, self.yRangeMax);
    NSLog(@"   - Initial bars to show: %ld", (long)self.initialBarsToShow);
    
    // Validate ranges
    if (self.visibleStartIndex < 0 || self.visibleEndIndex >= self.chartData.count) {
        NSLog(@"❌ INVALID VIEWPORT: Indices out of bounds!");
    }
    if (self.visibleStartIndex >= self.visibleEndIndex) {
        NSLog(@"❌ INVALID VIEWPORT: Start >= End!");
    }
}


#pragma mark - Smart Symbol Processing - VERSIONE SEMPLIFICATA


- (void)processSmartSymbolInput:(NSString *)input {
    NSLog(@"📝 Processing smart symbol input: '%@'", input);
    
    // Parse i parametri dall'input
    SmartSymbolParameters params = [self parseSmartSymbolInput:input];
    
    // Validate symbol
    if (!params.symbol || params.symbol.length == 0) {
        NSLog(@"❌ Invalid symbol in input");
        return;
    }
    
    // ✅ APPLY PARAMETERS
    [self applySmartSymbolParameters:params];
    
    // ✅ NUOVO: Usa direttamente le date con DataHub
    [self loadSymbolWithDateRange:params];
    
    // Broadcast to chain
    [self broadcastSymbolToChain:@[params.symbol]];
    
    // Update UI
    [self updateUIAfterSmartSymbolInput:params];
    
    NSLog(@"✅ Smart symbol processing completed for: %@", params.symbol);
}

- (SmartSymbolParameters)parseSmartSymbolInput:(NSString *)input {
    SmartSymbolParameters params = {0};
    
    // Default values
    params.timeframe = self.currentTimeframe;
    params.daysToDownload = 20;  // Default 20 giorni
    params.hasTimeframe = NO;
    params.hasDaysSpecified = NO;
    
    // Split input by comma
    NSArray<NSString *> *components = [input componentsSeparatedByString:@","];
    
    // ✅ COMPONENT 1: Symbol (required)
    if (components.count >= 1) {
        params.symbol = [[components[0] stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    }
    
    // ✅ COMPONENT 2: Timeframe (optional)
    if (components.count >= 2) {
        NSString *timeframeStr = [components[1] stringByTrimmingCharactersInSet:
                                  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        ChartTimeframe parsedTimeframe = [self parseTimeframeString:timeframeStr];
        if (parsedTimeframe != -1) {
            params.timeframe = parsedTimeframe;
            params.hasTimeframe = YES;
            NSLog(@"📊 Parsed timeframe: %@ -> %ld", timeframeStr, (long)parsedTimeframe);
        }
    }
    
    // ✅ COMPONENT 3: Days to download (optional)
    if (components.count >= 3) {
        NSString *daysStr = [components[2] stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSInteger days = [self parseDaysString:daysStr];
        if (days > 0) {
            params.daysToDownload = days;
            params.hasDaysSpecified = YES;
            NSLog(@"📅 Parsed days: %@ -> %ld days", daysStr, (long)days);
        }
    }
    
    // ✅ CALCOLA LE DATE (sempre usa date per semplicità)
    params.endDate = [[NSDate date] dateByAddingTimeInterval:86400]; // Domani (include oggi)
    params.startDate = [params.endDate dateByAddingTimeInterval:-(params.daysToDownload * 86400)];
    
    NSLog(@"📝 Parsed parameters - Symbol: %@, TF: %ld, Days: %ld, StartDate: %@, EndDate: %@",
          params.symbol, (long)params.timeframe, (long)params.daysToDownload,
          params.startDate, params.endDate);
    
    return params;
}

- (ChartTimeframe)parseTimeframeString:(NSString *)timeframeStr {
    if (!timeframeStr || timeframeStr.length == 0) return -1;
    
    NSString *tf = timeframeStr.lowercaseString;
    
    // ✅ NUMERIC FIRST - Se è solo numero, sono minuti
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([tf rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
        NSInteger minutes = tf.integerValue;
        switch (minutes) {
            case 1: return ChartTimeframe1Min;
            case 5: return ChartTimeframe5Min;
            case 15: return ChartTimeframe15Min;
            case 30: return ChartTimeframe30Min;
            case 60: return ChartTimeframe1Hour;
            case 240: return ChartTimeframe4Hour;
            default:
                NSLog(@"⚠️ Unsupported numeric timeframe: %ld minutes", (long)minutes);
                return -1;
        }
    }
    
    // ✅ MINUTE SUFFIX (es: 5m, 5min)
    if ([tf hasSuffix:@"m"] || [tf hasSuffix:@"min"]) {
        NSString *numberPart = tf;
        if ([tf hasSuffix:@"min"]) {
            numberPart = [tf substringToIndex:tf.length - 3];
        } else if ([tf hasSuffix:@"m"]) {
            numberPart = [tf substringToIndex:tf.length - 1];
        }
        
        NSInteger minutes = numberPart.integerValue;
        switch (minutes) {
            case 1: return ChartTimeframe1Min;
            case 5: return ChartTimeframe5Min;
            case 15: return ChartTimeframe15Min;
            case 30: return ChartTimeframe30Min;
            default:
                NSLog(@"⚠️ Unsupported minute timeframe: %ldm", (long)minutes);
                return -1;
        }
    }
    
    // ✅ HOUR SUFFIX (es: 1h, 4h)
    if ([tf hasSuffix:@"h"]) {
        NSString *hourPart = [tf substringToIndex:tf.length - 1];
        NSInteger hours = hourPart.integerValue;
        switch (hours) {
            case 1: return ChartTimeframe1Hour;
            case 4: return ChartTimeframe4Hour;
            default:
                NSLog(@"⚠️ Unsupported hour timeframe: %ldh", (long)hours);
                return -1;
        }
    }
    
    // ✅ DAILY+ TIMEFRAMES (single letter or full word)
    if ([tf isEqualToString:@"d"] || [tf isEqualToString:@"daily"]) return ChartTimeframeDaily;
    if ([tf isEqualToString:@"w"] || [tf isEqualToString:@"weekly"]) return ChartTimeframeWeekly;
    if ([tf isEqualToString:@"m"] || [tf isEqualToString:@"monthly"]) return ChartTimeframeMonthly;
    
    NSLog(@"⚠️ Unrecognized timeframe: %@", timeframeStr);
    return -1;
}

- (NSInteger)parseDaysString:(NSString *)daysStr {
    if (!daysStr || daysStr.length == 0) return 0;
    
    NSString *cleanStr = daysStr.lowercaseString;
    
    // ✅ CHECK FOR SUFFIXES (w, m, q, y)
    
    // Weeks
    if ([cleanStr hasSuffix:@"w"]) {
        NSString *numberPart = [cleanStr substringToIndex:cleanStr.length - 1];
        NSInteger weeks = numberPart.integerValue;
        return weeks * 7;  // Semplice: 1 settimana = 7 giorni
    }
    
    // Months (nel componente 3, 'm' = sempre mesi)
    if ([cleanStr hasSuffix:@"m"]) {
        NSString *numberPart = [cleanStr substringToIndex:cleanStr.length - 1];
        NSInteger months = numberPart.integerValue;
        return months * 22;  // Approssimazione: 1 mese = 22 giorni trading
    }
    
    // Quarters
    if ([cleanStr hasSuffix:@"q"]) {
        NSString *numberPart = [cleanStr substringToIndex:cleanStr.length - 1];
        NSInteger quarters = numberPart.integerValue;
        return quarters * 66;  // 3 mesi * 22 giorni = 66 giorni trading
    }
    
    // Years
    if ([cleanStr hasSuffix:@"y"]) {
        NSString *numberPart = [cleanStr substringToIndex:cleanStr.length - 1];
        NSInteger years = numberPart.integerValue;
        return years * 252;  // Standard trading days in a year
    }
    
    // ✅ PLAIN NUMBER = giorni
    NSInteger days = cleanStr.integerValue;
    if (days > 0) {
        return days;
    }
    
    return 0;
}



#pragma mark - StaticMode Implementation (NUOVO)

- (void)setStaticMode:(BOOL)staticMode {
    if (_isStaticMode == staticMode) return;
    
    _isStaticMode = staticMode;
    
    NSLog(@"📋 ChartWidget: StaticMode %@ for symbol %@",
          staticMode ? @"ENABLED" : @"DISABLED", self.currentSymbol ?: @"(none)");
    
    [self updateStaticModeUI];
    
    if (staticMode) {
        [self showStaticModeNotification];
    }
}

- (void)toggleStaticMode:(id)sender {
    [self setStaticMode:!self.isStaticMode];
}

- (void)updateStaticModeUI {
    // Update toggle button state
    if (self.staticModeToggle) {
        self.staticModeToggle.state = self.isStaticMode ? NSControlStateValueOn : NSControlStateValueOff;
        
        // Update button appearance
        if (self.isStaticMode) {
            self.staticModeToggle.layer.borderColor = [NSColor systemBlueColor].CGColor;
            self.staticModeToggle.layer.borderWidth = 2.0;
        } else {
            self.staticModeToggle.layer.borderColor = [NSColor clearColor].CGColor;
            self.staticModeToggle.layer.borderWidth = 0.0;
        }
    }
    
    // Update content view border (blue highlight like microscope)
    if (self.isStaticMode) {
        self.contentView.wantsLayer = YES;
        self.contentView.layer.borderColor = [NSColor systemBlueColor].CGColor;
        self.contentView.layer.borderWidth = 2.0;
        self.contentView.layer.cornerRadius = 4.0;
    } else {
        self.contentView.layer.borderColor = [NSColor clearColor].CGColor;
        self.contentView.layer.borderWidth = 0.0;
    }
}

- (void)showStaticModeNotification {
    // ✅ CHANGED: Updated notification message
    // Trova il primo panel per mostrare il messaggio
    ChartPanelView *targetPanel = self.chartPanels.firstObject;
    if (!targetPanel) return;
    
    // Crea messaggio temporaneo
    NSTextField *notificationLabel = [[NSTextField alloc] init];
    notificationLabel.stringValue = @"📋 STATIC MODE - No Data Updates";
    notificationLabel.font = [NSFont boldSystemFontOfSize:14];
    notificationLabel.textColor = [NSColor systemBlueColor];
    notificationLabel.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.1];
    notificationLabel.bordered = YES;
    notificationLabel.bezeled = YES;
    notificationLabel.editable = NO;
    notificationLabel.selectable = NO;
    notificationLabel.alignment = NSTextAlignmentCenter;
    
    // Posiziona al centro del panel
    notificationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [targetPanel addSubview:notificationLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [notificationLabel.centerXAnchor constraintEqualToAnchor:targetPanel.centerXAnchor],
        [notificationLabel.topAnchor constraintEqualToAnchor:targetPanel.topAnchor constant:10],
        [notificationLabel.widthAnchor constraintEqualToConstant:280],
        [notificationLabel.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // Rimuovi dopo 3 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [notificationLabel removeFromSuperview];
    });
    
    NSLog(@"📋 Showed StaticMode notification to user");
}

#pragma mark - Chart Data Access

- (NSArray<HistoricalBarModel *> *)currentChartData {
    return self.chartData;  // Direct access since we're in the main implementation
}

#pragma mark - New Loading Method with Date Range

- (void)loadSymbolWithDateRange:(SmartSymbolParameters)params {
    // Convert ChartTimeframe to BarTimeframe
    BarTimeframe barTimeframe = [self chartTimeframeToBarTimeframe:params.timeframe];
    
    // Determine if we need extended hours
    BOOL needExtendedHours = (self.tradingHoursMode == ChartTradingHoursWithAfterHours);
    
    NSLog(@"📊 ChartWidget: Loading %@ from %@ to %@ (timeframe: %ld, after-hours: %@)",
          params.symbol, params.startDate, params.endDate,
          (long)barTimeframe, needExtendedHours ? @"YES" : @"NO");
    
    if (self.isStaticMode) {
        NSLog(@"⚠️ Chart in static mode, skipping data load");
        return;
    }
    
    // ✅ USA IL METODO DataHub CON DATE DIRETTE!
    [[DataHub shared] getHistoricalBarsForSymbol:params.symbol
                                       timeframe:barTimeframe
                                       startDate:params.startDate
                                         endDate:params.endDate
                              needExtendedHours:needExtendedHours
                                     completion:^(NSArray<HistoricalBarModel *> *data, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!data || data.count == 0) {
                NSLog(@"❌ ChartWidget: No data received for %@", params.symbol);
                return;
            }
            
            NSLog(@"✅ ChartWidget: Received %lu bars for %@ (%@)",
                  (unsigned long)data.count, params.symbol, isFresh ? @"fresh" : @"cached");
            
            // Store the received data
            self.chartData = data;
            
            // Update the barsToDownload to reflect actual bars received
            self.barsToDownload = data.count;
            
            // Update panels with new data
            [self updatePanelsWithData:data];
            
            // Update viewport to show recent data
            [self resetToInitialView];
        });
    }];
}

#pragma mark - Helper Methods

- (void)applySmartSymbolParameters:(SmartSymbolParameters)params {
    // Apply timeframe if specified
    if (params.hasTimeframe) {
        self.currentTimeframe = params.timeframe;
        NSLog(@"⏰ Applied timeframe: %ld", (long)params.timeframe);
        
        // 🆕 NEW: Update slider for new timeframe
        [self updateDateRangeSliderForTimeframe:params.timeframe];
    }
    
    // 🆕 NEW: Apply days if specified
    if (params.hasDaysSpecified) {
        // Clamp to valid range for current timeframe
        NSInteger minDays = [self getMinDaysForTimeframe:self.currentTimeframe];
        NSInteger maxDays = [self getMaxDaysForTimeframe:self.currentTimeframe];
        NSInteger clampedDays = MAX(minDays, MIN(maxDays, params.daysToDownload));
        
        self.currentDateRangeDays = clampedDays;
        self.dateRangeSlider.integerValue = clampedDays;
        [self updateDateRangeLabel];
        
        NSLog(@"📅 Applied date range: %ld days (requested: %ld, clamped: %ld)",
              (long)clampedDays, (long)params.daysToDownload, (long)clampedDays);
    }
    
    // Store current symbol
    self.currentSymbol = params.symbol;
}

- (void)updateUIAfterSmartSymbolInput:(SmartSymbolParameters)params {
    // Update symbol text field (show clean symbol only)
    self.symbolTextField.stringValue = params.symbol;
    
    // Update timeframe segmented control if needed
    if (params.hasTimeframe && self.timeframeSegmented.segmentCount > params.timeframe) {
        self.timeframeSegmented.selectedSegment = params.timeframe;
    }
    
    // Show feedback about what was applied
    NSMutableArray *appliedParams = [NSMutableArray array];
    
    if (params.hasTimeframe) {
        [appliedParams addObject:[NSString stringWithFormat:@"TF: %@",
                                 [self timeframeDisplayName:params.timeframe]]];
    }
    
    if (params.hasDaysSpecified) {
        [appliedParams addObject:[NSString stringWithFormat:@"%ld days",
                                 (long)params.daysToDownload]];
    }
    
    if (appliedParams.count > 0) {
        NSString *message = [NSString stringWithFormat:@"Applied: %@",
                           [appliedParams componentsJoinedByString:@", "]];
        NSLog(@"💬 %@", message);
        // Potresti mostrare questo in una status bar o tooltip
    }
}

- (NSString *)timeframeDisplayName:(ChartTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min: return @"1min";
        case ChartTimeframe5Min: return @"5min";
        case ChartTimeframe15Min: return @"15min";
        case ChartTimeframe30Min: return @"30min";
        case ChartTimeframe1Hour: return @"1H";
        case ChartTimeframe4Hour: return @"4H";
        case ChartTimeframeDaily: return @"Daily";
        case ChartTimeframeWeekly: return @"Weekly";
        case ChartTimeframeMonthly: return @"Monthly";
        default: return @"Unknown";
    }
}

#pragma mark - Date Range Management (🆕 NEW)

- (void)loadDateRangeDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load download defaults (with fallbacks)
    self.defaultDaysFor1Min = [defaults integerForKey:@"ChartWidget_DefaultDays1Min"];
    if (self.defaultDaysFor1Min < 1) self.defaultDaysFor1Min = 20;
    
    self.defaultDaysFor5Min = [defaults integerForKey:@"ChartWidget_DefaultDays5Min"];
    if (self.defaultDaysFor5Min < 1) self.defaultDaysFor5Min = 40;
    
    self.defaultDaysForHourly = [defaults integerForKey:@"ChartWidget_DefaultDaysHourly"];
    if (self.defaultDaysForHourly < 1) self.defaultDaysForHourly = 999999; // max available
    
    self.defaultDaysForDaily = [defaults integerForKey:@"ChartWidget_DefaultDaysDaily"];
    if (self.defaultDaysForDaily < 1) self.defaultDaysForDaily = 180; // 6 months
    
    self.defaultDaysForWeekly = [defaults integerForKey:@"ChartWidget_DefaultDaysWeekly"];
    if (self.defaultDaysForWeekly < 1) self.defaultDaysForWeekly = 365; // 1 year
    
    self.defaultDaysForMonthly = [defaults integerForKey:@"ChartWidget_DefaultDaysMonthly"];
    if (self.defaultDaysForMonthly < 1) self.defaultDaysForMonthly = 1825; // 5 years
    
    // Load visible defaults
    self.defaultVisibleFor1Min = [defaults integerForKey:@"ChartWidget_DefaultVisible1Min"];
    if (self.defaultVisibleFor1Min < 1) self.defaultVisibleFor1Min = 5; // 5 days visible
    
    self.defaultVisibleFor5Min = [defaults integerForKey:@"ChartWidget_DefaultVisible5Min"];
    if (self.defaultVisibleFor5Min < 1) self.defaultVisibleFor5Min = 10; // 10 days visible
    
    self.defaultVisibleForHourly = [defaults integerForKey:@"ChartWidget_DefaultVisibleHourly"];
    if (self.defaultVisibleForHourly < 1) self.defaultVisibleForHourly = 30; // 30 days visible
    
    self.defaultVisibleForDaily = [defaults integerForKey:@"ChartWidget_DefaultVisibleDaily"];
    if (self.defaultVisibleForDaily < 1) self.defaultVisibleForDaily = 90; // 3 months visible
    
    self.defaultVisibleForWeekly = [defaults integerForKey:@"ChartWidget_DefaultVisibleWeekly"];
    if (self.defaultVisibleForWeekly < 1) self.defaultVisibleForWeekly = 180; // 6 months visible
    
    self.defaultVisibleForMonthly = [defaults integerForKey:@"ChartWidget_DefaultVisibleMonthly"];
    if (self.defaultVisibleForMonthly < 1) self.defaultVisibleForMonthly = 365; // 1 year visible
    
    NSLog(@"📂 Loaded date range defaults - 1m:%ld, 5m:%ld, hourly:%ld, daily:%ld, weekly:%ld, monthly:%ld",
          (long)self.defaultDaysFor1Min, (long)self.defaultDaysFor5Min, (long)self.defaultDaysForHourly,
          (long)self.defaultDaysForDaily, (long)self.defaultDaysForWeekly, (long)self.defaultDaysForMonthly);
}

- (void)saveDateRangeDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Save download defaults
    [defaults setInteger:self.defaultDaysFor1Min forKey:@"ChartWidget_DefaultDays1Min"];
    [defaults setInteger:self.defaultDaysFor5Min forKey:@"ChartWidget_DefaultDays5Min"];
    [defaults setInteger:self.defaultDaysForHourly forKey:@"ChartWidget_DefaultDaysHourly"];
    [defaults setInteger:self.defaultDaysForDaily forKey:@"ChartWidget_DefaultDaysDaily"];
    [defaults setInteger:self.defaultDaysForWeekly forKey:@"ChartWidget_DefaultDaysWeekly"];
    [defaults setInteger:self.defaultDaysForMonthly forKey:@"ChartWidget_DefaultDaysMonthly"];
    
    // Save visible defaults
    [defaults setInteger:self.defaultVisibleFor1Min forKey:@"ChartWidget_DefaultVisible1Min"];
    [defaults setInteger:self.defaultVisibleFor5Min forKey:@"ChartWidget_DefaultVisible5Min"];
    [defaults setInteger:self.defaultVisibleForHourly forKey:@"ChartWidget_DefaultVisibleHourly"];
    [defaults setInteger:self.defaultVisibleForDaily forKey:@"ChartWidget_DefaultVisibleDaily"];
    [defaults setInteger:self.defaultVisibleForWeekly forKey:@"ChartWidget_DefaultVisibleWeekly"];
    [defaults setInteger:self.defaultVisibleForMonthly forKey:@"ChartWidget_DefaultVisibleMonthly"];
    
    [defaults synchronize];
    
    NSLog(@"💾 Saved date range defaults to User Defaults");
}

- (NSInteger)getMinDaysForTimeframe:(ChartTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min:
        case ChartTimeframe5Min:
        case ChartTimeframe15Min:
        case ChartTimeframe30Min:
        case ChartTimeframe1Hour:
        case ChartTimeframe4Hour:
            return 1; // Minimum 1 day for intraday
            
        case ChartTimeframeDaily:
        case ChartTimeframeWeekly:
        case ChartTimeframeMonthly:
        default:
            return 10; // Minimum 10 days for daily+
    }
}

- (NSInteger)getMaxDaysForTimeframe:(ChartTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min:
            return 45; // ~1.5 months - Schwab API limit
            
        case ChartTimeframe5Min:
        case ChartTimeframe15Min:
        case ChartTimeframe30Min:
        case ChartTimeframe1Hour:
        case ChartTimeframe4Hour:
            return 255; // ~8.5 months - Schwab API limit
            
        case ChartTimeframeDaily:
        case ChartTimeframeWeekly:
        case ChartTimeframeMonthly:
        default:
            return 3650; // ~10 years (practically unlimited)
    }
}

- (NSInteger)getDefaultDaysForTimeframe:(ChartTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min:
            return self.defaultDaysFor1Min;
            
        case ChartTimeframe5Min:
        case ChartTimeframe15Min:
        case ChartTimeframe30Min:
            return self.defaultDaysFor5Min;
            
        case ChartTimeframe1Hour:
        case ChartTimeframe4Hour:
            return self.defaultDaysForHourly;
            
        case ChartTimeframeDaily:
            return self.defaultDaysForDaily;
            
        case ChartTimeframeWeekly:
            return self.defaultDaysForWeekly;
            
        case ChartTimeframeMonthly:
        default:
            return self.defaultDaysForMonthly;
    }
}

- (NSInteger)getDefaultVisibleDaysForTimeframe:(ChartTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min:
            return self.defaultVisibleFor1Min;
            
        case ChartTimeframe5Min:
        case ChartTimeframe15Min:
        case ChartTimeframe30Min:
            return self.defaultVisibleFor5Min;
            
        case ChartTimeframe1Hour:
        case ChartTimeframe4Hour:
            return self.defaultVisibleForHourly;
            
        case ChartTimeframeDaily:
            return self.defaultVisibleForDaily;
            
        case ChartTimeframeWeekly:
            return self.defaultVisibleForWeekly;
            
        case ChartTimeframeMonthly:
        default:
            return self.defaultVisibleForMonthly;
    }
}

- (void)updateDateRangeSliderForTimeframe:(ChartTimeframe)timeframe {
    NSInteger minDays = [self getMinDaysForTimeframe:timeframe];
    NSInteger maxDays = [self getMaxDaysForTimeframe:timeframe];
    NSInteger defaultDays = [self getDefaultDaysForTimeframe:timeframe];
    
    // Clamp default to valid range
    if (defaultDays < minDays) defaultDays = minDays;
    if (defaultDays > maxDays) defaultDays = maxDays;
    
    // Update slider range
    self.dateRangeSlider.minValue = minDays;
    self.dateRangeSlider.maxValue = maxDays;
    self.dateRangeSlider.integerValue = defaultDays;
    
    // Update current value
    self.currentDateRangeDays = defaultDays;
    
    // Update label
    [self updateDateRangeLabel];
    
    NSLog(@"📊 Updated date range slider for timeframe %ld: %ld-%ld days (default: %ld)",
          (long)timeframe, (long)minDays, (long)maxDays, (long)defaultDays);
}

- (void)dateRangeSliderChanged:(id)sender {
    self.currentDateRangeDays = self.dateRangeSlider.integerValue;
    [self updateDateRangeLabel];
    
    // Reload data with new date range
    if (self.currentSymbol && self.currentSymbol.length > 0) {
        [self loadDataWithCurrentSettings];
    }
    
    NSLog(@"📅 Date range slider changed to: %ld days", (long)self.currentDateRangeDays);
}

- (void)updateDateRangeLabel {
    NSString *displayText = [self formatDaysToDisplayString:self.currentDateRangeDays];
    self.dateRangeLabel.stringValue = displayText;
}

- (NSString *)formatDaysToDisplayString:(NSInteger)days {
    if (days >= 3650) {
        return @"max";
    } else if (days >= 365) {
        NSInteger years = days / 365;
        if (years == 1) {
            return @"1 year";
        } else {
            return [NSString stringWithFormat:@"%ld years", (long)years];
        }
    } else if (days >= 30) {
        NSInteger months = days / 30;
        if (months == 1) {
            return @"1 month";
        } else {
            return [NSString stringWithFormat:@"%ld months", (long)months];
        }
    } else if (days >= 7) {
        NSInteger weeks = days / 7;
        if (weeks == 1) {
            return @"1 week";
        } else {
            return [NSString stringWithFormat:@"%ld weeks", (long)weeks];
        }
    } else {
        if (days == 1) {
            return @"1 day";
        } else {
            return [NSString stringWithFormat:@"%ld days", (long)days];
        }
    }
}

- (void)loadDataWithCurrentSettings {
    if (!self.currentSymbol || self.currentSymbol.length == 0) return;
    
    // Calculate date range from slider value
    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:86400]; // Tomorrow
    NSDate *startDate = [endDate dateByAddingTimeInterval:-(self.currentDateRangeDays * 86400)];
    
    // Create smart symbol parameters
    SmartSymbolParameters params = {0};
    params.symbol = self.currentSymbol;
    params.timeframe = self.currentTimeframe;
    params.daysToDownload = self.currentDateRangeDays;
    params.startDate = startDate;
    params.endDate = endDate;
    params.hasTimeframe = YES;
    params.hasDaysSpecified = YES;
    
    // Load data
    [self loadSymbolWithDateRange:params];
    
    NSLog(@"🔄 Loading data with current settings - Symbol: %@, Days: %ld, Timeframe: %ld",
          self.currentSymbol, (long)self.currentDateRangeDays, (long)self.currentTimeframe);
}


@end
