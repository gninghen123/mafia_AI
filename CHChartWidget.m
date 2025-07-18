//
//  CHChartWidget.m
//  ChartWidget
//
//  Implementation of the chart widget
//

#import "CHChartWidget.h"
#import "CHChartView.h"
#import "CHChartData.h"
#import "CHDataPoint.h"
#import "CHChartCore.h"
#import "CHLineChartRenderer.h"
#import "CHBarChartRenderer.h"
#import "CHColorUtils.h"
#import "DataManager.h"
#import "MarketDataModels.h"

// Make sure we have the full definitions
#import "CHLineChartRenderer.h"
#import "CHBarChartRenderer.h"

// Notifications
NSString * const CHChartWidgetSelectionDidChangeNotification = @"CHChartWidgetSelectionDidChangeNotification";
NSString * const CHChartWidgetDataDidReloadNotification = @"CHChartWidgetDataDidReloadNotification";
NSString * const CHChartWidgetAnimationDidCompleteNotification = @"CHChartWidgetAnimationDidCompleteNotification";

@interface CHChartWidget () <CHChartDataSource, CHChartDelegate, NSComboBoxDataSource, NSComboBoxDelegate>

// Internal chart view
@property (nonatomic, strong) CHChartView *chartView;

// Frame storage for initialization
@property (nonatomic) NSRect chartFrame;

// UI Components for symbol and timeframe selection
@property (nonatomic, strong) NSView *controlsView;
@property (nonatomic, strong) NSComboBox *symbolComboBox;
@property (nonatomic, strong) NSStackView *timeframeButtonsStack;
@property (nonatomic, strong) NSArray<NSButton *> *timeframeButtons;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;
@property (nonatomic, strong) NSTextField *statusLabel;

// Current state
@property (nonatomic, strong) NSString *currentSymbol;
@property (nonatomic, assign) BarTimeframe currentTimeframe;
@property (nonatomic, strong) NSString *activeDataRequest;

// Block-based data source
@property (nonatomic, copy) CHChartWidgetSeriesCountBlock seriesCountBlock;
@property (nonatomic, copy) CHChartWidgetPointCountBlock pointCountBlock;
@property (nonatomic, copy) CHChartWidgetValueBlock valueGetterBlock;
@property (nonatomic, copy) CHChartWidgetLabelBlock labelGetterBlock;
@property (nonatomic, copy) CHChartWidgetColorBlock colorGetterBlock;

// Real-time data management
@property (nonatomic, strong) NSMutableArray<NSMutableArray<CHDataPoint *> *> *realtimeData;

// Title labels
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *xAxisLabel;
@property (nonatomic, strong) NSTextField *yAxisLabel;

// Historical data
@property (nonatomic, strong) NSArray<HistoricalBar *> *historicalBars;

@end

@implementation CHChartWidget

#pragma mark - Class Methods

+ (instancetype)chartWidgetWithFrame:(NSRect)frame type:(CHChartType)type {
    CHChartWidget *widget = [[self alloc] initWithFrame:frame];
    widget.chartType = type;
    return widget;
}

+ (instancetype)lineChartWithFrame:(NSRect)frame {
    return [self chartWidgetWithFrame:frame type:CHChartTypeLine];
}

+ (instancetype)barChartWithFrame:(NSRect)frame {
    return [self chartWidgetWithFrame:frame type:CHChartTypeBar];
}

+ (instancetype)histogramWithFrame:(NSRect)frame {
    return [self chartWidgetWithFrame:frame type:CHChartTypeBar];
}

+ (instancetype)scatterPlotWithFrame:(NSRect)frame {
    return [self chartWidgetWithFrame:frame type:CHChartTypeScatter];
}

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithType:@"Chart Widget" panelType:PanelTypeCenter];
    if (self) {
        _chartFrame = frame;
        [self setupChartWidget];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupChartWidget];
    }
    return self;
}

- (instancetype)initWithType:(NSString *)widgetType panelType:(PanelType)panelType {
    self = [super initWithType:widgetType panelType:panelType];
    if (self) {
        [self setupChartWidget];
        
        // Determina il tipo di chart dal widget type
        if ([widgetType isEqualToString:@"Line Chart"]) {
            _chartType = CHChartTypeLine;
        } else if ([widgetType isEqualToString:@"Bar Chart"]) {
            _chartType = CHChartTypeBar;
        } else if ([widgetType isEqualToString:@"Candlestick Chart"]) {
            _chartType = CHChartTypeCombined; // Per candlestick
        } else if ([widgetType isEqualToString:@"Volume Profile"]) {
            _chartType = CHChartTypeBar;
        } else if ([widgetType isEqualToString:@"Heatmap"]) {
            _chartType = CHChartTypePie; // O un tipo specifico per heatmap
        } else {
            // Default per "Chart Widget" o tipi non riconosciuti
            _chartType = CHChartTypeLine;
        }
    }
    return self;
}

#pragma mark - Setup Methods

- (void)setupChartWidget {
    // Configura il widget chart-specifico
    
    // Default configuration con tema adattivo
    _configuration = [CHChartConfiguration defaultConfiguration];
    if (_chartType == 0) {
        _chartType = CHChartTypeLine; // Assicurati che ci sia sempre un tipo valido
    }
    _configuration.chartType = _chartType;
    _maxDataPoints = NSIntegerMax;
    _realtimeData = [NSMutableArray array];
    
    // IMPORTANTE: Applica il tema corretto basato sull'aspetto dell'app
    [self applyAppropriateTheme];
    
    // Default state
    _currentTimeframe = BarTimeframe1Day; // Default a daily
    _currentSymbol = nil;
    
    // Setup labels (hidden by default)
    [self setupLabels];
}

- (void)setupContentView {
    // FIX: Chiama prima la versione di BaseWidget per creare contentViewInternal
    [super setupContentView];
    
    // IMPORTANTE: Setup nell'ordine corretto per evitare problemi di layout
    [self setupChartControls];
    [self setupChartView];
    
    // Forza il layout dopo aver creato tutto
    [self.contentView setNeedsUpdateConstraints:YES];
    [self.contentView setNeedsLayout:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
           [self debugViewHierarchy];
       });
   
}
// DEBUG AVANZATO - Aggiungi questo al metodo debugViewHierarchy

- (void)debugViewHierarchy {
    NSLog(@"=== CHChartWidget View Hierarchy Debug ===");
    NSLog(@"ContentView subviews count: %lu", (unsigned long)self.contentView.subviews.count);
    NSLog(@"ContentView frame: %@", NSStringFromRect(self.contentView.frame));
    NSLog(@"ContentView bounds: %@", NSStringFromRect(self.contentView.bounds));
    NSLog(@"ContentView alpha: %.2f", self.contentView.alphaValue);
    
    for (NSInteger i = 0; i < self.contentView.subviews.count; i++) {
        NSView *subview = self.contentView.subviews[i];
        NSLog(@"Subview %ld: %@ - Frame: %@ - Hidden: %@ - Alpha: %.2f",
              (long)i,
              NSStringFromClass([subview class]),
              NSStringFromRect(subview.frame),
              subview.hidden ? @"YES" : @"NO",
              subview.alphaValue);
        
        if (subview == self.controlsView) {
            NSLog(@"  -> Found controlsView!");
            NSLog(@"  -> Layer: %@", subview.layer);
            NSLog(@"  -> Layer backgroundColor: %@", subview.layer.backgroundColor);
            NSLog(@"  -> Layer borderColor: %@", subview.layer.borderColor);
            NSLog(@"  -> Layer borderWidth: %.2f", subview.layer.borderWidth);
            NSLog(@"  -> ControlsView subviews count: %lu", (unsigned long)self.controlsView.subviews.count);
            
            for (NSInteger j = 0; j < self.controlsView.subviews.count; j++) {
                NSView *control = self.controlsView.subviews[j];
                NSLog(@"    Control %ld: %@ - Frame: %@ - Hidden: %@ - Alpha: %.2f",
                      (long)j,
                      NSStringFromClass([control class]),
                      NSStringFromRect(control.frame),
                      control.hidden ? @"YES" : @"NO",
                      control.alphaValue);
                
                if (control.layer) {
                    NSLog(@"      -> Layer backgroundColor: %@", control.layer.backgroundColor);
                    NSLog(@"      -> Layer borderColor: %@", control.layer.borderColor);
                    NSLog(@"      -> Layer borderWidth: %.2f", control.layer.borderWidth);
                }
                
                // Test specifico per ComboBox
                if ([control isKindOfClass:[NSComboBox class]]) {
                    NSComboBox *combo = (NSComboBox *)control;
                    NSLog(@"      -> ComboBox enabled: %@", combo.enabled ? @"YES" : @"NO");
                    NSLog(@"      -> ComboBox editable: %@", combo.editable ? @"YES" : @"NO");
                    NSLog(@"      -> ComboBox stringValue: '%@'", combo.stringValue);
                }
            }
        }
    }
    NSLog(@"=== End Debug ===");
    
    // TEST ESTREMO: Aggiungi una view di test super visibile
}


- (void)setupChartControls {
    // Rimuovi il placeholder di BaseWidget se presente
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Crea la view per i controlli - NESSUN colore personalizzato
    self.controlsView = [[NSView alloc] init];
    self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // IMPORTANTE: Aggiungi subito i constraint per l'altezza fissa
    [self.contentView addSubview:self.controlsView];
    
    // Constraint per la controls view
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.controlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.controlsView.heightAnchor constraintEqualToConstant:40]
    ]];
    
    // Symbol ComboBox - COMPLETAMENTE NATIVO
    self.symbolComboBox = [[NSComboBox alloc] init];
    self.symbolComboBox.placeholderString = @"Enter symbol (e.g., AAPL)";
    self.symbolComboBox.dataSource = self;
    self.symbolComboBox.delegate = self;
    self.symbolComboBox.usesDataSource = YES;
    self.symbolComboBox.completes = YES;
    self.symbolComboBox.target = self;
    self.symbolComboBox.action = @selector(symbolEntered:);
    self.symbolComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    // NESSUN layer personalizzato - lascia che macOS gestisca l'aspetto
    
    [self.controlsView addSubview:self.symbolComboBox];
    
    // Timeframe buttons
    [self setupTimeframeButtons];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.hidden = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.loadingIndicator];
    
    // Status label - COLORI NATIVI
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.drawsBackground = NO; // Sfondo trasparente
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor]; // Colore nativo
    self.statusLabel.stringValue = @"Enter symbol to load data";
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.statusLabel];
    
    // Setup constraints for all controls
    [self setupControlsConstraints];
}

- (void)setupTimeframeButtons {
    // Crea stack view per i pulsanti timeframe - FORZATAMENTE VISIBILE
    self.timeframeButtonsStack = [[NSStackView alloc] init];
    self.timeframeButtonsStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.timeframeButtonsStack.spacing = 4;
    self.timeframeButtonsStack.distribution = NSStackViewDistributionFillEqually;
    self.timeframeButtonsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeframeButtonsStack.wantsLayer = YES;
    self.timeframeButtonsStack.layer.backgroundColor = [NSColor greenColor].CGColor; // VERDE SUPER VISIBILE
    [self.controlsView addSubview:self.timeframeButtonsStack];
    
    // Definisci i timeframe disponibili
    NSArray *timeframes = @[
        @{@"title": @"1m", @"timeframe": @(BarTimeframe1Min)},
        @{@"title": @"5m", @"timeframe": @(BarTimeframe5Min)},
        @{@"title": @"1h", @"timeframe": @(BarTimeframe1Hour)},
        @{@"title": @"D", @"timeframe": @(BarTimeframe1Day)},
        @{@"title": @"W", @"timeframe": @(BarTimeframe1Week)}
    ];
    
    NSMutableArray *buttons = [NSMutableArray array];
    
    for (NSDictionary *tfInfo in timeframes) {
        NSButton *button = [[NSButton alloc] init];
        button.title = tfInfo[@"title"];
        button.bezelStyle = NSBezelStyleRounded;
        button.buttonType = NSButtonTypeToggle;
        button.tag = [tfInfo[@"timeframe"] integerValue];
        button.target = self;
        button.action = @selector(timeframeButtonClicked:);
        
        // FORZA VISIBILITÀ Buttons
        button.wantsLayer = YES;
        button.layer.backgroundColor = [NSColor cyanColor].CGColor; // CIANO SUPER VISIBILE
        button.layer.borderWidth = 2.0;
        button.layer.borderColor = [NSColor magentaColor].CGColor;
        
        // Imposta il pulsante daily come selezionato di default
        if (button.tag == BarTimeframe1Day) {
            button.state = NSControlStateValueOn;
            button.layer.backgroundColor = [NSColor purpleColor].CGColor; // VIOLA per selezionato
        }
        
        // DIMENSIONI FISSE per i pulsanti
        [button.widthAnchor constraintEqualToConstant:35].active = YES;
        [button.heightAnchor constraintEqualToConstant:25].active = YES;
        
        [buttons addObject:button];
        [self.timeframeButtonsStack addArrangedSubview:button];
    }
    
    self.timeframeButtons = [buttons copy];
}


- (void)setupChartView {
    if (!self.chartView && self.contentView && self.controlsView) {
        // Il chart view occuperà TUTTO lo spazio sotto i controlli
        self.chartView = [[CHChartView alloc] init];
        self.chartView.translatesAutoresizingMaskIntoConstraints = NO;
        self.chartView.wantsLayer = YES;
        
        // FIX: Usa il background color dalla configurazione (che si adatta al tema)
        self.chartView.layer.backgroundColor = self.configuration.backgroundColor.CGColor;
        
        // IMPORTANTE: Aggiungi il chart view SOTTO i controlli (i controlli sono già stati aggiunti)
        [self.contentView addSubview:self.chartView];
        
        // CONSTRAINT CRITICI: Il chart view deve prendere tutto lo spazio rimanente
        [NSLayoutConstraint activateConstraints:@[
            // Top: subito sotto i controlli
            [self.chartView.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:8],
            // Left: margine dal bordo
            [self.chartView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
            // Right: margine dal bordo
            [self.chartView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            // Bottom: margine dal bordo - QUESTO È CRITICO!
            [self.chartView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
        ]];
        
        // Apply configuration
        self.chartView.configuration = self.configuration;
        self.chartView.dataSource = self;
        
        // IMPORTANTE: Forza il layout
        [self.chartView setNeedsUpdateConstraints:YES];
        [self.chartView setNeedsLayout:YES];
    }
}


- (void)setupControlsConstraints {
    // Symbol combobox constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolComboBox.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor constant:8],
        [self.symbolComboBox.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.symbolComboBox.widthAnchor constraintEqualToConstant:120],
        [self.symbolComboBox.heightAnchor constraintEqualToConstant:25]
    ]];
    
    // Timeframe buttons stack constraints - DIMENSIONI FISSE
    [NSLayoutConstraint activateConstraints:@[
        [self.timeframeButtonsStack.leadingAnchor constraintEqualToAnchor:self.symbolComboBox.trailingAnchor constant:8],
        [self.timeframeButtonsStack.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.timeframeButtonsStack.heightAnchor constraintEqualToConstant:25],
        [self.timeframeButtonsStack.widthAnchor constraintEqualToConstant:195] // 5 buttons * 35 + 4 spaces * 4
    ]];
    
    // Loading indicator constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.timeframeButtonsStack.trailingAnchor constant:8],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.loadingIndicator.widthAnchor constraintEqualToConstant:16],
        [self.loadingIndicator.heightAnchor constraintEqualToConstant:16]
    ]];
    
    // Status label constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.loadingIndicator.trailingAnchor constant:8],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.controlsView.trailingAnchor constant:-8]
    ]];
}



- (void)setupLabels {
    // Setup delle label di base (nascoste di default ora che abbiamo i controlli)
    
    // Title label
    self.titleLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.titleLabel.bezeled = NO;
    self.titleLabel.drawsBackground = NO;
    self.titleLabel.editable = NO;
    self.titleLabel.selectable = NO;
    self.titleLabel.alignment = NSTextAlignmentCenter;
    self.titleLabel.font = [NSFont boldSystemFontOfSize:14];
    self.titleLabel.hidden = YES; // Nascosta per default, usiamo i controlli
    
    // X-axis label
    self.xAxisLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.xAxisLabel.bezeled = NO;
    self.xAxisLabel.drawsBackground = NO;
    self.xAxisLabel.editable = NO;
    self.xAxisLabel.selectable = NO;
    self.xAxisLabel.alignment = NSTextAlignmentCenter;
    self.xAxisLabel.font = [NSFont systemFontOfSize:11];
    self.xAxisLabel.hidden = YES;
    
    // Y-axis label
    self.yAxisLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.yAxisLabel.bezeled = NO;
    self.yAxisLabel.drawsBackground = NO;
    self.yAxisLabel.editable = NO;
    self.yAxisLabel.selectable = NO;
    self.yAxisLabel.alignment = NSTextAlignmentCenter;
    self.yAxisLabel.font = [NSFont systemFontOfSize:11];
    self.yAxisLabel.hidden = YES;
}

#pragma mark - Theme Management

- (void)applyAppropriateTheme {
    // Detect if we're in dark mode
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    BOOL isDarkMode = ([osxMode isEqualToString:@"Dark"]);
    
    if (isDarkMode) {
        [self.configuration applyDarkTheme];
    } else {
        [self.configuration applyLightTheme];
    }
    
    // Aggiorna la configurazione se il chart view esiste già
    if (self.chartView) {
        self.chartView.configuration = self.configuration;
        self.chartView.layer.backgroundColor = self.configuration.backgroundColor.CGColor;
        [self.chartView setNeedsDisplay:YES];
    }
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    // Ascolta per i cambiamenti di tema
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(appleInterfaceThemeChangedNotification:)
                                                            name:@"AppleInterfaceThemeChangedNotification"
                                                          object:nil];
}

- (void)viewDidDisappear {
    [super viewDidDisappear];
    
    // Rimuovi l'observer
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self
                                                                name:@"AppleInterfaceThemeChangedNotification"
                                                              object:nil];
}

- (void)appleInterfaceThemeChangedNotification:(NSNotification *)notification {
    // Il tema è cambiato, aggiorna il chart
    [self applyAppropriateTheme];
}

#pragma mark - Layout Override

- (void)viewDidLayout {
    [super viewDidLayout];
    
    // Dopo ogni layout, assicurati che il chart view abbia le dimensioni corrette
    if (self.chartView) {
        [self.chartView setNeedsDisplay:YES];
        
        // Debug: stampa le dimensioni per verificare
        NSLog(@"CHChartWidget Layout - ContentView: %@", NSStringFromRect(self.contentView.frame));
        NSLog(@"CHChartWidget Layout - ControlsView: %@", NSStringFromRect(self.controlsView.frame));
        NSLog(@"CHChartWidget Layout - ChartView: %@", NSStringFromRect(self.chartView.frame));
    }
}

- (void)forceLayoutUpdate {
    // Metodo per forzare un aggiornamento del layout quando necessario
    [self.view setNeedsUpdateConstraints:YES];
    [self.contentView setNeedsUpdateConstraints:YES];
    [self.controlsView setNeedsUpdateConstraints:YES];
    [self.chartView setNeedsUpdateConstraints:YES];
    
    [self.view setNeedsLayout:YES];
    [self.contentView setNeedsLayout:YES];
    [self.controlsView setNeedsLayout:YES];
    [self.chartView setNeedsLayout:YES];
    
    // Force immediate layout
    [self.view layoutSubtreeIfNeeded];
    
    // Redraw the chart
    [self.chartView setNeedsDisplay:YES];
}

#pragma mark - Actions

- (void)symbolEntered:(id)sender {
    NSString *symbol = [self.symbolComboBox.stringValue uppercaseString];
    if (symbol.length == 0) return;
    
    // Update current symbol
    self.currentSymbol = symbol;
    
    // Update status
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Loading %@...", symbol];
    
    // Start loading animation
    [self.loadingIndicator startAnimation:nil];
    self.loadingIndicator.hidden = NO;
    
    // Request data
    NSString *requestID = [[NSUUID UUID] UUIDString];
    self.activeDataRequest = requestID;
    
    [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                      timeframe:self.currentTimeframe
                                                      startDate:nil
                                                        endDate:nil
                                                     completion:^(NSArray<HistoricalBar *> *bars, NSError *error) {
        // Check if this is still the active request
        if (![requestID isEqualToString:self.activeDataRequest]) return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimation:nil];
            self.loadingIndicator.hidden = YES;
            
            if (error) {
                self.statusLabel.stringValue = [NSString stringWithFormat:@"Error loading %@", symbol];
                NSLog(@"Error loading data for %@: %@", symbol, error.localizedDescription);
                return;
            }
            
            self.historicalBars = bars;
            self.statusLabel.stringValue = [NSString stringWithFormat:@"%@ loaded (%ld bars)", symbol, bars.count];
            
            // Convert bars to chart data and display
            [self updateChartWithBars:bars];
        });
    }];
}

- (void)timeframeButtonClicked:(NSButton *)sender {
    // Deselect all buttons
    for (NSButton *button in self.timeframeButtons) {
        button.state = NSControlStateValueOff;
    }
    
    // Select clicked button
    sender.state = NSControlStateValueOn;
    
    // Update current timeframe
    self.currentTimeframe = (BarTimeframe)sender.tag;
    
    // Reload data if we have a symbol
    if (self.currentSymbol) {
        [self symbolEntered:self.symbolComboBox];
    }
}

- (void)updateChartWithBars:(NSArray<HistoricalBar *> *)bars {
    if (bars.count == 0) return;
    
    // Convert bars to chart data points
    NSMutableArray *dataPoints = [NSMutableArray array];
    
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBar *bar = bars[i];
        
        // For line chart, use close price
        if (self.chartType == CHChartTypeLine) {
            CHDataPoint *point = [[CHDataPoint alloc] initWithX:i y:[bar.close doubleValue]];
            [dataPoints addObject:point];
        }
        // For other chart types, you might want to create OHLC data points
    }
    
    // Create chart data
    CHChartData *chartData = [CHChartData chartData];
    [chartData addSeries:dataPoints withName:self.currentSymbol];
    
    // Set chart data
    self.chartData = chartData;
}

#pragma mark - Properties

- (void)setConfiguration:(CHChartConfiguration *)configuration {
    _configuration = configuration;
    
    // Aggiorna anche il background del chart view se esiste
    if (self.chartView) {
        self.chartView.configuration = configuration;
        self.chartView.layer.backgroundColor = configuration.backgroundColor.CGColor;
        [self.chartView setNeedsDisplay:YES];
    }
}

- (void)setChartType:(CHChartType)chartType {
    _chartType = chartType;
    self.configuration.chartType = chartType;
    self.chartView.configuration = self.configuration;
}

- (void)setChartData:(CHChartData *)chartData {
    _chartData = chartData;
    // CHChartView non ha una proprietà chartData, dobbiamo usare il dataSource pattern
    if (!self.dataSource) {
        self.chartView.dataSource = self;
    }
    [self reloadData];
}

#pragma mark - CHChartDataSource

- (NSInteger)numberOfDataSeriesInChartView:(CHChartView *)chartView {
    if (self.seriesCountBlock) {
        return self.seriesCountBlock();
    }
    return self.chartData ? self.chartData.seriesCount : 0;
}

- (NSInteger)chartView:(CHChartView *)chartView numberOfPointsInSeries:(NSInteger)series {
    if (self.pointCountBlock) {
        return self.pointCountBlock(series);
    }
    
    if (self.chartData && series < self.chartData.seriesCount) {
        NSArray<CHDataPoint *> *seriesData = [self.chartData seriesAtIndex:series];
        return seriesData.count;
    }
    
    return 0;
}

- (CGFloat)chartView:(CHChartView *)chartView xValueForSeries:(NSInteger)series atIndex:(NSInteger)index {
    if (self.chartData && series < self.chartData.seriesCount) {
        CHDataPoint *point = [self.chartData dataPointInSeries:series atIndex:index];
        return point ? point.x : (CGFloat)index;
    }
    
    return (CGFloat)index;
}

- (CGFloat)chartView:(CHChartView *)chartView valueForSeries:(NSInteger)series atIndex:(NSInteger)index {
    if (self.valueGetterBlock) {
        return self.valueGetterBlock(series, index);
    }
    
    if (self.chartData && series < self.chartData.seriesCount) {
        CHDataPoint *point = [self.chartData dataPointInSeries:series atIndex:index];
        return point ? point.y : 0.0;
    }
    
    return 0.0;
}

- (NSString *)chartView:(CHChartView *)chartView labelForSeries:(NSInteger)series {
    if (self.labelGetterBlock) {
        return self.labelGetterBlock(series);
    }
    
    if (self.chartData) {
        NSString *name = [self.chartData nameForSeriesAtIndex:series];
        return name ?: [NSString stringWithFormat:@"Series %ld", series + 1];
    }
    
    return [NSString stringWithFormat:@"Series %ld", series + 1];
}

- (NSColor *)chartView:(CHChartView *)chartView colorForSeries:(NSInteger)series {
    if (self.colorGetterBlock) {
        return self.colorGetterBlock(series);
    }
    
    if (self.chartData) {
        NSColor *color = [self.chartData colorForSeriesAtIndex:series];
        if (color) return color;
    }
    
    if (series < self.configuration.seriesColors.count) {
        return self.configuration.seriesColors[series];
    }
    
    // Generate color based on series index
    NSInteger totalSeries = [self numberOfDataSeriesInChartView:chartView];
    return [NSColor colorWithHue:(CGFloat)series / MAX(totalSeries, 1)
                      saturation:0.8
                      brightness:0.8
                           alpha:1.0];
}

#pragma mark - Data Management

- (void)setDataPoints:(NSArray<NSNumber *> *)values {
    NSMutableArray *dataPoints = [NSMutableArray array];
    for (NSInteger i = 0; i < values.count; i++) {
        CHDataPoint *point = [[CHDataPoint alloc] initWithX:i y:[values[i] doubleValue]];
        [dataPoints addObject:point];
    }
    
    CHChartData *data = [CHChartData chartData];
    [data addSeries:dataPoints];
    
    self.chartData = data;
}

- (void)setDataPoints:(NSArray<NSNumber *> *)xValues yValues:(NSArray<NSNumber *> *)yValues {
    NSInteger count = MIN(xValues.count, yValues.count);
    NSMutableArray *dataPoints = [NSMutableArray array];
    
    for (NSInteger i = 0; i < count; i++) {
        CHDataPoint *point = [[CHDataPoint alloc] initWithX:[xValues[i] doubleValue]
                                                           y:[yValues[i] doubleValue]];
        [dataPoints addObject:point];
    }
    
    CHChartData *data = [CHChartData chartData];
    [data addSeries:dataPoints];
    
    self.chartData = data;
}

- (void)setMultipleSeries:(NSArray<NSArray<NSNumber *> *> *)seriesData {
    NSMutableArray *names = [NSMutableArray array];
    for (NSInteger i = 0; i < seriesData.count; i++) {
        [names addObject:[NSString stringWithFormat:@"Series %ld", i + 1]];
    }
    [self setMultipleSeries:seriesData seriesNames:names];
}

- (void)setMultipleSeries:(NSArray<NSArray<NSNumber *> *> *)seriesData
              seriesNames:(NSArray<NSString *> *)names {
    CHChartData *data = [CHChartData chartData];
    data.seriesNames = names;
    
    for (NSInteger i = 0; i < seriesData.count; i++) {
        NSArray<NSNumber *> *series = seriesData[i];
        NSMutableArray *dataPoints = [NSMutableArray array];
        
        for (NSInteger j = 0; j < series.count; j++) {
            CHDataPoint *point = [[CHDataPoint alloc] initWithX:j y:[series[j] doubleValue]];
            [dataPoints addObject:point];
        }
        
        NSString *name = (i < names.count) ? names[i] : [NSString stringWithFormat:@"Series %ld", i + 1];
        [data addSeries:dataPoints withName:name];
    }
    
    self.chartData = data;
}

- (void)setDataSourceWithSeriesCount:(CHChartWidgetSeriesCountBlock)seriesCount
                          pointCount:(CHChartWidgetPointCountBlock)pointCount
                         valueGetter:(CHChartWidgetValueBlock)valueGetter {
    self.seriesCountBlock = seriesCount;
    self.pointCountBlock = pointCount;
    self.valueGetterBlock = valueGetter;
    
    self.chartView.dataSource = self;
}

- (void)reloadData {
    [self reloadDataAnimated:NO];
}

- (void)reloadDataAnimated:(BOOL)animated {
    [self.chartView reloadData];
    
    // CHChartView non ha startAnimation, gestiamo diversamente l'animazione
    if (animated && self.configuration.animated) {
        // L'animazione sarà gestita internamente dal renderer
        [self.chartView setNeedsDisplay:YES];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CHChartWidgetDataDidReloadNotification
                                                        object:self];
}

#pragma mark - Appearance Customization

- (void)applyTheme:(NSString *)themeName {
    if ([themeName isEqualToString:@"dark"]) {
        [self.configuration applyDarkTheme];
    } else if ([themeName isEqualToString:@"light"]) {
        [self.configuration applyLightTheme];
    } else if ([themeName isEqualToString:@"minimal"]) {
        [self.configuration applyMinimalTheme];
    } else if ([themeName isEqualToString:@"auto"]) {
        [self applyAppropriateTheme];
        return; // applyAppropriateTheme già aggiorna tutto
    }
    
    // Aggiorna la vista
    if (self.chartView) {
        self.chartView.configuration = self.configuration;
        self.chartView.layer.backgroundColor = self.configuration.backgroundColor.CGColor;
        [self.chartView setNeedsDisplay:YES];
    }
}

- (void)setSeriesColors:(NSArray<NSColor *> *)colors {
    self.configuration.seriesColors = colors;
    self.chartView.configuration = self.configuration;
}

- (void)addSeriesWithColor:(NSColor *)color {
    NSMutableArray *colors = [self.configuration.seriesColors mutableCopy];
    [colors addObject:color];
    self.configuration.seriesColors = colors;
    self.chartView.configuration = self.configuration;
}

#pragma mark - Labels and Titles

- (void)setTitle:(NSString *)title {
    self.titleLabel.stringValue = title ?: @"";
    self.titleLabel.hidden = (title == nil);
}

- (void)setXAxisLabel:(NSString *)label {
    self.xAxisLabel.stringValue = label ?: @"";
    self.xAxisLabel.hidden = (label == nil);
}

- (void)setYAxisLabel:(NSString *)label {
    self.yAxisLabel.stringValue = label ?: @"";
    self.yAxisLabel.hidden = (label == nil);
}

#pragma mark - Line Chart Specific

- (void)setLineStyle:(CHLineChartStyle)style {
    if ([self.chartView.renderer isKindOfClass:[CHLineChartRenderer class]]) {
        ((CHLineChartRenderer *)self.chartView.renderer).lineStyle = style;
        [self.chartView setNeedsDisplay:YES];
    }
}

- (void)setShowDataPoints:(BOOL)show {
    if ([self.chartView.renderer isKindOfClass:[CHLineChartRenderer class]]) {
        ((CHLineChartRenderer *)self.chartView.renderer).showDataPoints = show;
        [self.chartView setNeedsDisplay:YES];
    }
}

- (void)setFillArea:(BOOL)fill {
    if ([self.chartView.renderer isKindOfClass:[CHLineChartRenderer class]]) {
        ((CHLineChartRenderer *)self.chartView.renderer).fillArea = fill;
        [self.chartView setNeedsDisplay:YES];
    }
}

- (void)setSmoothLines:(BOOL)smooth {
    if ([self.chartView.renderer isKindOfClass:[CHLineChartRenderer class]]) {
        ((CHLineChartRenderer *)self.chartView.renderer).lineStyle =
            smooth ? CHLineChartStyleSmooth : CHLineChartStyleStraight;
        [self.chartView setNeedsDisplay:YES];
    }
}

#pragma mark - Bar Chart Specific

- (void)setBarStyle:(CHBarChartStyle)style {
    if ([self.chartView.renderer isKindOfClass:[CHBarChartRenderer class]]) {
        ((CHBarChartRenderer *)self.chartView.renderer).barStyle = style;
        [self.chartView setNeedsDisplay:YES];
    }
}

- (void)setBarWidth:(CGFloat)width {
    self.configuration.barWidth = width;
    self.chartView.configuration = self.configuration;
}

- (void)setGrouped:(BOOL)grouped {
    if ([self.chartView.renderer isKindOfClass:[CHBarChartRenderer class]]) {
        ((CHBarChartRenderer *)self.chartView.renderer).barStyle =
            grouped ? CHBarChartStyleGrouped : CHBarChartStyleSeparated;
        [self.chartView setNeedsDisplay:YES];
    }
}

#pragma mark - Real-time Data

- (void)enableRealTimeMode {
    // Implementation for real-time data updates
}

- (void)disableRealTimeMode {
    // Implementation to disable real-time updates
}

- (void)addDataPoint:(CGFloat)value {
    [self addDataPoint:value toSeries:0];
}

- (void)addDataPoint:(CGFloat)value toSeries:(NSInteger)series {
    // Ensure we have enough series
    while (self.realtimeData.count <= series) {
        [self.realtimeData addObject:[NSMutableArray array]];
    }
    
    NSMutableArray *seriesData = self.realtimeData[series];
    CHDataPoint *point = [[CHDataPoint alloc] initWithX:seriesData.count y:value];
    [seriesData addObject:point];
    
    // Limit data points if needed
    if (seriesData.count > self.maxDataPoints) {
        [seriesData removeObjectAtIndex:0];
        
        // Update X values to maintain continuity
        for (NSInteger i = 0; i < seriesData.count; i++) {
            CHDataPoint *dataPoint = seriesData[i];
            dataPoint.x = i;
        }
    }
    
    [self reloadData];
}

- (void)setMaxDataPoints:(NSInteger)maxPoints {
    _maxDataPoints = maxPoints;
    
    // Trim existing data if needed
    for (NSMutableArray *seriesData in self.realtimeData) {
        while (seriesData.count > maxPoints) {
            [seriesData removeObjectAtIndex:0];
        }
    }
}

#pragma mark - Export

- (NSImage *)chartImage {
    return [self.chartView chartImage];
}

- (NSData *)chartImageDataWithType:(NSBitmapImageFileType)fileType {
    return [self.chartView chartImageDataWithType:fileType];
}

- (BOOL)exportChartToFile:(NSString *)filePath withType:(NSBitmapImageFileType)fileType {
    NSData *imageData = [self chartImageDataWithType:fileType];
    return [imageData writeToFile:filePath atomically:YES];
}

#pragma mark - NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    // Provide some common symbols
    return 20;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    // Common trading symbols
    NSArray *symbols = @[@"AAPL", @"GOOGL", @"MSFT", @"AMZN", @"TSLA", @"META", @"NVDA", @"NFLX",
                        @"SPY", @"QQQ", @"IWM", @"GLD", @"SLV", @"TLT", @"VIX", @"EURUSD", @"GBPUSD",
                        @"USDJPY", @"BTC", @"ETH"];
    
    return index < symbols.count ? symbols[index] : @"";
}

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)string {
    NSArray *symbols = @[@"AAPL", @"GOOGL", @"MSFT", @"AMZN", @"TSLA", @"META", @"NVDA", @"NFLX",
                        @"SPY", @"QQQ", @"IWM", @"GLD", @"SLV", @"TLT", @"VIX", @"EURUSD", @"GBPUSD",
                        @"USDJPY", @"BTC", @"ETH"];
    
    for (NSString *symbol in symbols) {
        if ([symbol.lowercaseString hasPrefix:string.lowercaseString]) {
            return symbol;
        }
    }
    return nil;
}

- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    NSArray *symbols = @[@"AAPL", @"GOOGL", @"MSFT", @"AMZN", @"TSLA", @"META", @"NVDA", @"NFLX",
                        @"SPY", @"QQQ", @"IWM", @"GLD", @"SLV", @"TLT", @"VIX", @"EURUSD", @"GBPUSD",
                        @"USDJPY", @"BTC", @"ETH"];
    
    return [symbols indexOfObject:string.uppercaseString];
}

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    // Questo metodo viene chiamato automaticamente quando:
    // 1. Questo widget ha la chain attiva
    // 2. Un altro widget invia un update con lo stesso colore di chain
    
    NSString *newSymbol = update[@"symbol"];
    if (newSymbol && ![newSymbol isEqualToString:self.currentSymbol]) {
        NSLog(@"ChartWidget ricevuto nuovo simbolo: %@ (chain color match!)", newSymbol);
        
        // Aggiorna il simbolo nel combo box
        self.symbolComboBox.stringValue = newSymbol;
        self.currentSymbol = newSymbol;
        
        // Ricarica i dati del grafico
        [self loadChartData];
    }
    
    // Potresti anche gestire altri tipi di update
    NSArray *symbols = update[@"symbols"];
    if (symbols) {
        // Aggiorna la lista di simboli disponibili
        [self updateAvailableSymbols:symbols];
    }
    
    NSString *timeframe = update[@"timeframe"];
    if (timeframe) {
        // Cambia il timeframe se supportato
        [self changeTimeframe:timeframe];
    }
}

#pragma mark - NSComboBoxDelegate

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    [self symbolEntered:self.symbolComboBox];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if (notification.object == self.symbolComboBox) {
        [self symbolEntered:self.symbolComboBox];
    }
}





#pragma mark - chain

// Quando l'utente cambia manualmente il simbolo nel widget
- (void)symbolComboBoxDidChange:(id)sender {
    NSString *newSymbol = self.symbolComboBox.stringValue;
    if (newSymbol.length > 0) {
        self.currentSymbol = newSymbol;
        [self loadChartData];
        
        // Propaga il cambio ad altri widget con lo stesso colore di chain
        if (self.chainActive) {
            [self broadcastUpdate:@{@"symbol": newSymbol}];
        }
    }
}

// Esempio di menu contestuale per configurare la chain
- (void)showChartContextMenu:(NSEvent *)event {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Opzioni standard del grafico...
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Opzioni per la chain
    NSMenuItem *chainItem = [[NSMenuItem alloc] init];
    chainItem.title = @"Chain Settings";
    
    NSMenu *chainSubmenu = [[NSMenu alloc] init];
    
    // Status della chain
    NSMenuItem *statusItem = [[NSMenuItem alloc] init];
    statusItem.title = self.chainActive ?
        [NSString stringWithFormat:@"Chain Attiva (%@)", [self colorNameForColor:self.chainColor]] :
        @"Chain Non Attiva";
    statusItem.enabled = NO;
    [chainSubmenu addItem:statusItem];
    
    [chainSubmenu addItem:[NSMenuItem separatorItem]];
    
    // Toggle chain
    NSMenuItem *toggleItem = [[NSMenuItem alloc] init];
    toggleItem.title = self.chainActive ? @"Disattiva Chain" : @"Attiva Chain";
    toggleItem.action = @selector(toggleChain:);
    [chainSubmenu addItem:toggleItem];
    
    chainItem.submenu = chainSubmenu;
    [menu addItem:chainItem];
    
    [menu popUpMenuPositioningItem:nil atLocation:event.locationInWindow inView:self.view];
}


// Helper per ottenere il nome del colore
- (NSString *)colorNameForColor:(NSColor *)color {
    // Confronta con i colori standard
  /*  if ([self colorsMatch:color with:[NSColor systemRedColor]]) return @"Rosso";
    if ([self colorsMatch:color with:[NSColor systemGreenColor]]) return @"Verde";
    if ([self colorsMatch:color with:[NSColor systemBlueColor]]) return @"Blu";
    if ([self colorsMatch:color with:[NSColor systemYellowColor]]) return @"Giallo";
    if ([self colorsMatch:color with:[NSColor systemOrangeColor]]) return @"Arancione";
    if ([self colorsMatch:color with:[NSColor systemPurpleColor]]) return @"Viola";
    if ([self colorsMatch:color with:[NSColor systemGrayColor]]) return @"Grigio";*/
    return @"Custom";
}

#pragma mark - Dealloc

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end
