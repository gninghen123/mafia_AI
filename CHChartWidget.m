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
@property (nonatomic) NSInteger maxDataPoints;
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
    CHChartWidget *widget = [self chartWidgetWithFrame:frame type:CHChartTypeBar];
    CHBarChartRenderer *renderer = (CHBarChartRenderer *)widget.chartView.renderer;
    renderer.barStyle = CHBarChartStyleHistogram;
    return widget;
}

+ (instancetype)scatterPlotWithFrame:(NSRect)frame {
    return [self chartWidgetWithFrame:frame type:CHChartTypeScatter];
}

#pragma mark - Initialization

// FIX: Override del designated initializer di BaseWidget
- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        // Determina il tipo di chart basato sul widget type
        [self configureChartTypeFromWidgetType:type];
        [self setupChartWidget];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frame {
    // FIX: CHChartWidget deve chiamare il corretto inizializzatore di BaseWidget
    self = [super initWithType:@"Chart Widget" panelType:PanelTypeCenter];
    if (self) {
        // Memorizza il frame per uso successivo
        _chartFrame = frame;
        [self setupChartWidget];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    // FIX: Stesso pattern per initWithCoder
    self = [super initWithType:@"Chart Widget" panelType:PanelTypeCenter];
    if (self) {
        // Frame sarà impostato dal coder
        _chartFrame = NSMakeRect(0, 0, 300, 200); // frame di default
        [self setupChartWidget];
    }
    return self;
}

- (void)configureChartTypeFromWidgetType:(NSString *)widgetType {
    // Mappa i widget types ai chart types
    if ([widgetType isEqualToString:@"Line Chart"]) {
        _chartType = CHChartTypeLine;
    } else if ([widgetType isEqualToString:@"Bar Chart"]) {
        _chartType = CHChartTypeBar;
    } else if ([widgetType isEqualToString:@"Candlestick Chart"]) {
        _chartType = CHChartTypeLine; // O un tipo specifico per candlestick
    } else if ([widgetType isEqualToString:@"Market Depth"]) {
        _chartType = CHChartTypeBar;
    } else if ([widgetType isEqualToString:@"Volume Profile"]) {
        _chartType = CHChartTypeBar;
    } else if ([widgetType isEqualToString:@"Heatmap"]) {
        _chartType = CHChartTypePie; // O un tipo specifico per heatmap
    } else {
        // Default per "Chart Widget" o tipi non riconosciuti
        _chartType = CHChartTypeLine;
    }
}

- (void)setupChartWidget {
    // Configura il widget chart-specifico
    
    // Default configuration
    _configuration = [CHChartConfiguration defaultConfiguration];
    if (_chartType == 0) {
        _chartType = CHChartTypeLine; // Assicurati che ci sia sempre un tipo valido
    }
    _configuration.chartType = _chartType;
    _maxDataPoints = NSIntegerMax;
    _realtimeData = [NSMutableArray array];
    
    // Default state
    _currentTimeframe = BarTimeframe1Day; // Default a daily
    _currentSymbol = nil;
    
    // Setup labels (hidden by default)
    [self setupLabels];
}

- (void)setupContentView {
    // FIX: Chiama prima la versione di BaseWidget per creare contentViewInternal
    [super setupContentView];
    
    // Ora setuppa i controlli chart specifici nel contentView esistente
    [self setupChartControls];
    [self setupChartView];
}

- (void)setupChartControls {
    // Rimuovi il placeholder di BaseWidget
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Crea la view per i controlli in alto
    self.controlsView = [[NSView alloc] init];
    self.controlsView.wantsLayer = YES;
    self.controlsView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.controlsView.layer.borderWidth = 1.0; // Debug: aggiungi bordo per vedere la view
    self.controlsView.layer.borderColor = [NSColor redColor].CGColor;
    self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.controlsView];
    
    // Symbol ComboBox
    self.symbolComboBox = [[NSComboBox alloc] init];
    self.symbolComboBox.placeholderString = @"Enter symbol (e.g., AAPL)";
    self.symbolComboBox.dataSource = self;
    self.symbolComboBox.delegate = self;
    self.symbolComboBox.usesDataSource = YES;
    self.symbolComboBox.completes = YES;
    self.symbolComboBox.target = self;
    self.symbolComboBox.action = @selector(symbolEntered:);
    self.symbolComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolComboBox.layer.backgroundColor = [NSColor whiteColor].CGColor; // Debug: background
    self.symbolComboBox.layer.borderWidth = 1.0; // Debug: bordo
    self.symbolComboBox.layer.borderColor = [NSColor blackColor].CGColor;
    [self.controlsView addSubview:self.symbolComboBox];
    
    // Timeframe buttons
    [self setupTimeframeButtons];
    
    // Loading indicator (usa NSProgressIndicator su macOS)
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.hidden = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.loadingIndicator];
    
    // Status label
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.drawsBackground = YES; // Debug: mostra background
    self.statusLabel.backgroundColor = [NSColor yellowColor]; // Debug: colore di sfondo
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor blackColor]; // Debug: testo nero
    self.statusLabel.stringValue = @"Enter symbol to load data";
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:self.statusLabel];
    
    // Setup constraints for controls
    [self setupControlsConstraints];
}

- (void)setupTimeframeButtons {
    // Crea stack view per i pulsanti timeframe
    self.timeframeButtonsStack = [[NSStackView alloc] init];
    self.timeframeButtonsStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.timeframeButtonsStack.spacing = 4;
    self.timeframeButtonsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeframeButtonsStack.wantsLayer = YES;
    self.timeframeButtonsStack.layer.backgroundColor = [NSColor greenColor].CGColor; // Debug: sfondo verde
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
        button.bezelStyle = NSBezelStyleRegularSquare;
        button.buttonType = NSButtonTypePushOnPushOff;
        button.tag = [tfInfo[@"timeframe"] integerValue];
        button.target = self;
        button.action = @selector(timeframeButtonClicked:);
        
        // Debug: colori visibili
        button.wantsLayer = YES;
        button.layer.backgroundColor = [NSColor lightGrayColor].CGColor;
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [NSColor blackColor].CGColor;
        
        // Imposta il pulsante daily come selezionato di default
        if (button.tag == BarTimeframe1Day) {
            button.state = NSControlStateValueOn;
            button.layer.backgroundColor = [NSColor blueColor].CGColor; // Debug: blu per selezionato
        }
        
        [button.widthAnchor constraintEqualToConstant:35].active = YES;
        [button.heightAnchor constraintEqualToConstant:25].active = YES;
        
        [buttons addObject:button];
        [self.timeframeButtonsStack addArrangedSubview:button];
    }
    
    self.timeframeButtons = [buttons copy];
}

- (void)setupControlsConstraints {
    // Constraints for controls view (FIXED: ancoraggio in ALTO)
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.controlsView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.controlsView.heightAnchor constraintEqualToConstant:40]
    ]];
    
    // Symbol combobox constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolComboBox.leadingAnchor constraintEqualToAnchor:self.controlsView.leadingAnchor constant:8],
        [self.symbolComboBox.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.symbolComboBox.widthAnchor constraintEqualToConstant:120],
        [self.symbolComboBox.heightAnchor constraintEqualToConstant:25]
    ]];
    
    // Timeframe buttons stack constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.timeframeButtonsStack.leadingAnchor constraintEqualToAnchor:self.symbolComboBox.trailingAnchor constant:8],
        [self.timeframeButtonsStack.centerYAnchor constraintEqualToAnchor:self.controlsView.centerYAnchor],
        [self.timeframeButtonsStack.heightAnchor constraintEqualToConstant:25]
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

- (void)setupChartView {
    if (!self.chartView && self.contentView && self.controlsView) {
        // Il chart view occuperà lo spazio sotto i controlli
        self.chartView = [[CHChartView alloc] init];
        self.chartView.translatesAutoresizingMaskIntoConstraints = NO;
        self.chartView.wantsLayer = YES;
        self.chartView.layer.backgroundColor = [NSColor whiteColor].CGColor;
        
        // IMPORTANTE: Aggiungi il chart view PRIMA dei controlli per z-order corretto
        [self.contentView addSubview:self.chartView];
        
        // Poi rimuovi e ri-aggiungi i controlli per metterli sopra
        [self.controlsView removeFromSuperview];
        [self.contentView addSubview:self.controlsView];
        
        // FIXED: Chart view constraints con margine dai controlli
        [NSLayoutConstraint activateConstraints:@[
            [self.chartView.topAnchor constraintEqualToAnchor:self.controlsView.bottomAnchor constant:8],
            [self.chartView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
            [self.chartView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [self.chartView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
        ]];
        
        // Apply configuration
        self.chartView.configuration = self.configuration;
        self.chartView.dataSource = self;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Aggiungi le label al content view dopo che è stato caricato (se necessario)
    if (self.contentView && !self.titleLabel.superview) {
        [self.contentView addSubview:self.titleLabel];
        [self.contentView addSubview:self.xAxisLabel];
        [self.contentView addSubview:self.yAxisLabel];
    }
}

#pragma mark - Actions

- (void)symbolEntered:(id)sender {
    NSString *symbol = [self.symbolComboBox.stringValue uppercaseString];
    if (symbol.length == 0) return;
    
    self.currentSymbol = symbol;
    [self loadHistoricalDataForCurrentSymbol];
}

- (void)timeframeButtonClicked:(NSButton *)sender {
    // Deselect all buttons
    for (NSButton *button in self.timeframeButtons) {
        button.state = NSControlStateValueOff;
    }
    
    // Select clicked button
    sender.state = NSControlStateValueOn;
    self.currentTimeframe = (BarTimeframe)sender.tag;
    
    // Reload data if we have a symbol
    if (self.currentSymbol) {
        [self loadHistoricalDataForCurrentSymbol];
    }
}

#pragma mark - Data Loading

- (void)loadHistoricalDataForCurrentSymbol {
    if (!self.currentSymbol || self.currentSymbol.length == 0) return;
    
    // Cancel any existing request
    if (self.activeDataRequest) {
        // TODO: Cancel previous request if DataManager supports it
        self.activeDataRequest = nil;
    }
    
    // Show loading state
    [self showLoadingState];
    
    // Calculate date range based on timeframe
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self startDateForTimeframe:self.currentTimeframe];
    
    // Request historical data
    DataManager *dataManager = [DataManager sharedManager];
    
    __weak typeof(self) weakSelf = self;
    self.activeDataRequest = [dataManager requestHistoricalDataForSymbol:self.currentSymbol
                                                               timeframe:self.currentTimeframe
                                                               startDate:startDate
                                                                 endDate:endDate
                                                              completion:^(NSArray<HistoricalBar *> *bars, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            strongSelf.activeDataRequest = nil;
            [strongSelf hideLoadingState];
            
            if (error) {
                [strongSelf showErrorState:error];
            } else {
                [strongSelf displayHistoricalData:bars];
            }
        });
    }];
}

- (NSDate *)startDateForTimeframe:(BarTimeframe)timeframe {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    
    switch (timeframe) {
        case BarTimeframe1Min:
            return [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:now options:0];
        case BarTimeframe5Min:
            return [calendar dateByAddingUnit:NSCalendarUnitDay value:-3 toDate:now options:0];
        case BarTimeframe1Hour:
            return [calendar dateByAddingUnit:NSCalendarUnitWeekOfYear value:-2 toDate:now options:0];
        case BarTimeframe1Day:
            return [calendar dateByAddingUnit:NSCalendarUnitYear value:-1 toDate:now options:0];
        case BarTimeframe1Week:
            return [calendar dateByAddingUnit:NSCalendarUnitYear value:-3 toDate:now options:0];
        default:
            return [calendar dateByAddingUnit:NSCalendarUnitYear value:-1 toDate:now options:0];
    }
}

- (void)displayHistoricalData:(NSArray<HistoricalBar *> *)bars {
    if (!bars || bars.count == 0) {
        self.statusLabel.stringValue = @"No data available";
        return;
    }
    
    self.historicalBars = bars;
    
    // Convert HistoricalBar objects to CHDataPoint objects
    NSMutableArray *dataPoints = [NSMutableArray array];
    
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBar *bar = bars[i];
        
        // For line charts, use close price
        // For candlestick charts, we might want to use OHLC data differently
        CGFloat value;
        if (self.chartType == CHChartTypeBar) {
            // For bar charts, show volume
            value = bar.volume;
        } else {
            // For line charts, show close price
            value = [bar.close doubleValue];
        }
        
        CHDataPoint *point = [[CHDataPoint alloc] initWithX:i y:value];
        point.label = [self formatDateForBar:bar];
        [dataPoints addObject:point];
    }
    
    // Update chart data
    CHChartData *chartData = [CHChartData chartData];
    [chartData addSeries:dataPoints withName:self.currentSymbol];
    self.chartData = chartData;
    
    // Update status and title
    self.statusLabel.stringValue = [NSString stringWithFormat:@"%@ - %ld bars loaded",
                                   self.currentSymbol, bars.count];
    [self setTitle:[NSString stringWithFormat:@"%@ - %@",
                   self.currentSymbol, [self timeframeDisplayName:self.currentTimeframe]]];
}

- (NSString *)formatDateForBar:(HistoricalBar *)bar {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    switch (self.currentTimeframe) {
        case BarTimeframe1Min:
        case BarTimeframe5Min:
            formatter.dateFormat = @"HH:mm";
            break;
        case BarTimeframe1Hour:
            formatter.dateFormat = @"MMM dd HH:mm";
            break;
        case BarTimeframe1Day:
            formatter.dateFormat = @"MMM dd";
            break;
        case BarTimeframe1Week:
            formatter.dateFormat = @"MMM yyyy";
            break;
        default:
            formatter.dateFormat = @"MMM dd";
            break;
    }
    
    return [formatter stringFromDate:bar.timestamp];
}

- (NSString *)timeframeDisplayName:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1 Minute";
        case BarTimeframe5Min: return @"5 Minutes";
        case BarTimeframe1Hour: return @"1 Hour";
        case BarTimeframe1Day: return @"Daily";
        case BarTimeframe1Week: return @"Weekly";
        default: return @"Daily";
    }
}

#pragma mark - UI State Management

- (void)showLoadingState {
    self.loadingIndicator.hidden = NO;
    [self.loadingIndicator startAnimation:nil];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Loading %@...", self.currentSymbol];
    self.symbolComboBox.enabled = NO;
    
    for (NSButton *button in self.timeframeButtons) {
        button.enabled = NO;
    }
}

- (void)hideLoadingState {
    self.loadingIndicator.hidden = YES;
    [self.loadingIndicator stopAnimation:nil];
    self.symbolComboBox.enabled = YES;
    
    for (NSButton *button in self.timeframeButtons) {
        button.enabled = YES;
    }
}

- (void)showErrorState:(NSError *)error {
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Data Loading Error";
    alert.informativeText = error.localizedDescription;
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

#pragma mark - NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    // Return a list of popular symbols for autocomplete
    return [self popularSymbols].count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    return [self popularSymbols][index];
}

- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    return [[self popularSymbols] indexOfObject:string];
}

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)uncompletedString {
    NSString *upperString = [uncompletedString uppercaseString];
    for (NSString *symbol in [self popularSymbols]) {
        if ([symbol hasPrefix:upperString]) {
            return symbol;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)popularSymbols {
    return @[@"AAPL", @"GOOGL", @"MSFT", @"AMZN", @"TSLA", @"META", @"NVDA", @"NFLX",
             @"SPY", @"QQQ", @"IWM", @"DIA", @"GLD", @"SLV", @"TLT", @"VIX"];
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

#pragma name - Layout Override

// Rimuovi i metodi di layout manuali - ora usiamo Auto Layout

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

- (void)setConfiguration:(CHChartConfiguration *)configuration {
    _configuration = configuration;
    self.chartView.configuration = configuration;
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

- (CGFloat)chartView:(CHChartView *)chartView valueForSeries:(NSInteger)series atIndex:(NSInteger)index {
    if (self.valueGetterBlock) {
        return self.valueGetterBlock(series, index);
    }
    
    if (self.chartData) {
        CHDataPoint *point = [self.chartData dataPointInSeries:series atIndex:index];
        return point ? point.y : 0.0;
    }
    
    return 0.0;
}

- (CGFloat)chartView:(CHChartView *)chartView xValueForSeries:(NSInteger)series atIndex:(NSInteger)index {
    if (self.chartData) {
        CHDataPoint *point = [self.chartData dataPointInSeries:series atIndex:index];
        return point ? point.x : (CGFloat)index;
    }
    
    return (CGFloat)index;
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
    }
    
    self.chartView.configuration = self.configuration;
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
    [self layoutLabels];
}

- (void)setXAxisLabel:(NSString *)label {
    self.xAxisLabel.stringValue = label ?: @"";
    self.xAxisLabel.hidden = (label == nil);
    [self layoutLabels];
}

- (void)setYAxisLabel:(NSString *)label {
    self.yAxisLabel.stringValue = label ?: @"";
    self.yAxisLabel.hidden = (label == nil);
    [self layoutLabels];
}

- (void)layoutLabels {
    if (!self.contentView) return;
    
    // Layout title at top
    if (!self.titleLabel.hidden) {
        CGFloat titleHeight = 30;
        self.titleLabel.frame = NSMakeRect(0, self.contentView.bounds.size.height - titleHeight,
                                          self.contentView.bounds.size.width, titleHeight);
    }
    
    // Layout X-axis label at bottom
    if (!self.xAxisLabel.hidden) {
        CGFloat labelHeight = 20;
        self.xAxisLabel.frame = NSMakeRect(0, 0, self.contentView.bounds.size.width, labelHeight);
    }
    
    // Layout Y-axis label at left (rotated)
    if (!self.yAxisLabel.hidden) {
        CGFloat labelWidth = 20;
        self.yAxisLabel.frame = NSMakeRect(0, 0, self.contentView.bounds.size.height, labelWidth);
    }
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

@end
