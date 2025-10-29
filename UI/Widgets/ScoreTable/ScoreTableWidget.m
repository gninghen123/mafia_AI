//
//  ScoreTableWidget.m
//  TradingApp
//
//  Score Table Widget Implementation
//

#import "ScoreTableWidget.h"
#import "DataHub.h"
#import "StrategyManager.h"
#import "ScoreCalculator.h"
#import "DataRequirementCalculator.h"
#import "ChainDataValidator.h"

@interface ScoreTableWidget ()
@property (nonatomic, strong) NSMutableArray<NSString *> *currentSymbols;
@property (nonatomic, assign) BOOL isCalculating;
@end

@implementation ScoreTableWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type {
    self = [super initWithType:type];
    if (self) {
        self.scoreResults = [NSMutableArray array];
        self.currentSymbols = [NSMutableArray array];
        self.symbolDataCache = [NSMutableDictionary dictionary];
        self.isCalculating = NO;
        
        // Load default strategy
        self.currentStrategy = [[StrategyManager sharedManager] defaultStrategy];
        
        NSLog(@"✅ ScoreTableWidget initialized with strategy: %@", self.currentStrategy.strategyName);
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    NSLog(@"🔧 ScoreTableWidget: Setting up UI...");
    
    // Setup UI programmatically
    [self setupUI];
    [self setupTableColumns];
    [self loadStrategies];
    
    NSLog(@"✅ ScoreTableWidget: UI setup complete");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDataHubUpdate:)
                                                 name:@"DataHubDataLoadedNotification"
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Setup

- (void)setupUI {
    if (!self.contentView) {
        NSLog(@"❌ No content view available");
        return;
    }
    
    // Container for all content
    NSView *container = [[NSView alloc] initWithFrame:self.contentView.bounds];
    container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.contentView addSubview:container];
    
    CGFloat y = container.bounds.size.height;
    CGFloat padding = 10;
    CGFloat controlHeight = 30;
    
    // 1️⃣ TOP SECTION: Symbol Input + Strategy Selector
    y -= (padding + 60); // Space for symbol input
    
    // Symbol input label
    NSTextField *symbolLabel = [NSTextField labelWithString:@"Symbols (comma-separated):"];
    symbolLabel.frame = NSMakeRect(padding, y + 35, 200, 20);
    [container addSubview:symbolLabel];
    
    // Symbol input text view
    self.symbolInputScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(padding, y, container.bounds.size.width - 2*padding, 60)];
    self.symbolInputScrollView.autoresizingMask = NSViewWidthSizable;
    self.symbolInputScrollView.hasVerticalScroller = YES;
    self.symbolInputScrollView.borderType = NSBezelBorder;
    
    self.symbolInputTextView = [[NSTextView alloc] initWithFrame:self.symbolInputScrollView.bounds];
    self.symbolInputTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.symbolInputTextView.font = [NSFont systemFontOfSize:13];
    self.symbolInputTextView.delegate = self;
    self.symbolInputTextView.string = @"AAPL, MSFT, GOOGL, AMZN, TSLA";
    
    self.symbolInputScrollView.documentView = self.symbolInputTextView;
    [container addSubview:self.symbolInputScrollView];
    
    // 2️⃣ CONTROLS ROW: Strategy + Buttons
    y -= (padding + controlHeight);
    
    CGFloat xPos = padding;
    
    // Strategy label
    NSTextField *strategyLabel = [NSTextField labelWithString:@"Strategy:"];
    strategyLabel.frame = NSMakeRect(xPos, y + 5, 70, 20);
    [container addSubview:strategyLabel];
    xPos += 75;
    
    // Strategy selector
    self.strategySelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(xPos, y, 200, controlHeight)];
    [self.strategySelector setTarget:self];
    [self.strategySelector setAction:@selector(strategyChanged:)];
    [container addSubview:self.strategySelector];
    xPos += 210;
    
    // Configure button
    self.configureButton = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, y, 100, controlHeight)];
    [self.configureButton setTitle:@"Configure..."];
    [self.configureButton setTarget:self];
    [self.configureButton setAction:@selector(configureStrategy:)];
    [self.configureButton setBezelStyle:NSBezelStyleRounded];
    [container addSubview:self.configureButton];
    xPos += 110;
    
    // Refresh button
    self.refreshButton = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, y, 80, controlHeight)];
    [self.refreshButton setTitle:@"Refresh"];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshScores:)];
    [self.refreshButton setBezelStyle:NSBezelStyleRounded];
    [container addSubview:self.refreshButton];
    xPos += 90;
    
    // Export button
    self.exportButton = [[NSButton alloc] initWithFrame:NSMakeRect(xPos, y, 80, controlHeight)];
    [self.exportButton setTitle:@"Export"];
    [self.exportButton setTarget:self];
    [self.exportButton setAction:@selector(exportToCSV:)];
    [self.exportButton setBezelStyle:NSBezelStyleRounded];
    [container addSubview:self.exportButton];
    
    // 3️⃣ TABLE VIEW
    y -= (padding + 10);
    CGFloat tableHeight = y - 30; // Leave space for status bar
    
    self.tableScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(padding, 30,
                                                                          container.bounds.size.width - 2*padding,
                                                                          tableHeight)];
    self.tableScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.tableScrollView.hasVerticalScroller = YES;
    self.tableScrollView.hasHorizontalScroller = YES;
    self.tableScrollView.borderType = NSBezelBorder;
    
    self.scoreTableView = [[NSTableView alloc] initWithFrame:self.tableScrollView.bounds];
    self.scoreTableView.dataSource = self;
    self.scoreTableView.delegate = self;
    self.scoreTableView.allowsMultipleSelection = YES;
    self.scoreTableView.usesAlternatingRowBackgroundColors = YES;
    self.scoreTableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    
    self.tableScrollView.documentView = self.scoreTableView;
    [container addSubview:self.tableScrollView];
    
    // 4️⃣ BOTTOM STATUS BAR
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(padding, 5,
                                                                     container.bounds.size.width - 100, 20)];
    self.statusLabel.autoresizingMask = NSViewWidthSizable;
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.stringValue = @"Ready";
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [container addSubview:self.statusLabel];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(container.bounds.size.width - 80, 5, 20, 20)];
    self.loadingIndicator.autoresizingMask = NSViewMinXMargin;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.displayedWhenStopped = NO;
    [container addSubview:self.loadingIndicator];
    
    NSLog(@"✅ UI setup complete");
}

- (void)setupTableColumns {
    // Remove existing columns
    while (self.scoreTableView.tableColumns.count > 0) {
        [self.scoreTableView removeTableColumn:self.scoreTableView.tableColumns.lastObject];
    }
    
    // Fixed columns: Symbol and Total Score
    NSTableColumn *symbolCol = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolCol.title = @"Symbol";
    symbolCol.width = 100;
    symbolCol.minWidth = 80;
    [self.scoreTableView addTableColumn:symbolCol];
    
    NSTableColumn *scoreCol = [[NSTableColumn alloc] initWithIdentifier:@"totalScore"];
    scoreCol.title = @"Total Score";
    scoreCol.width = 100;
    scoreCol.minWidth = 80;
    
    // Make total score sortable
    NSSortDescriptor *scoreSortDesc = [NSSortDescriptor sortDescriptorWithKey:@"totalScore" ascending:NO];
    scoreCol.sortDescriptorPrototype = scoreSortDesc;
    
    [self.scoreTableView addTableColumn:scoreCol];
    
    // Dynamic columns from strategy
    if (self.currentStrategy) {
        for (IndicatorConfig *indicator in self.currentStrategy.indicators) {
            if (!indicator.isEnabled) continue;
            
            NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:indicator.indicatorType];
            col.title = indicator.displayName;
            col.width = 90;
            col.minWidth = 70;
            
            // Make sortable
            NSSortDescriptor *sortDesc = [NSSortDescriptor sortDescriptorWithKey:indicator.indicatorType ascending:NO];
            col.sortDescriptorPrototype = sortDesc;
            
            [self.scoreTableView addTableColumn:col];
        }
    }
    
    NSLog(@"✅ Setup %ld table columns", (long)self.scoreTableView.tableColumns.count);
}

#pragma mark - Strategy Management

- (void)loadStrategies {
    [self.strategySelector removeAllItems];
    
    NSArray<ScoringStrategy *> *strategies = [[StrategyManager sharedManager] allStrategies];
    
    for (ScoringStrategy *strategy in strategies) {
        [self.strategySelector addItemWithTitle:strategy.strategyName];
        NSMenuItem *item = [self.strategySelector itemWithTitle:strategy.strategyName];
        item.representedObject = strategy;
    }
    
    // Select current strategy
    if (self.currentStrategy) {
        [self.strategySelector selectItemWithTitle:self.currentStrategy.strategyName];
    }
    
    NSLog(@"📋 Loaded %lu strategies", (unsigned long)strategies.count);
}

- (IBAction)strategyChanged:(NSPopUpButton *)sender {
    NSMenuItem *selectedItem = sender.selectedItem;
    ScoringStrategy *strategy = selectedItem.representedObject;
    
    if (strategy) {
        self.currentStrategy = strategy;
        NSLog(@"📊 Strategy changed to: %@", strategy.strategyName);
        
        // Rebuild table columns
        [self setupTableColumns];
        
        // Recalculate if we have symbols
        if (self.currentSymbols.count > 0) {
            [self refreshScores];
        }
    }
}

- (IBAction)configureStrategy:(id)sender {
    // TODO: Open configuration window
    NSLog(@"⚙️ Configure strategy (not yet implemented)");
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Configuration";
    alert.informativeText = @"Strategy configuration UI will be implemented in the next phase.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

#pragma mark - Actions

- (IBAction)refreshScores:(id)sender {
    NSLog(@"🔄 Refresh scores requested");
    
    // Parse symbols from text view
    NSString *text = self.symbolInputTextView.string;
    NSArray<NSString *> *symbols = [self parseSymbolsFromText:text];
    
    if (symbols.count == 0) {
        self.statusLabel.stringValue = @"No symbols entered";
        return;
    }
    
    [self loadSymbolsAndCalculateScores:symbols];
}

- (IBAction)exportToCSV:(id)sender {
    [self exportToCSV];
}

#pragma mark - Symbol Parsing

- (NSArray<NSString *> *)parseSymbolsFromText:(NSString *)text {
    if (!text || text.length == 0) return @[];
    
    // Split by comma, newline, space
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@", \n\r\t"];
    NSArray<NSString *> *components = [text componentsSeparatedByCharactersInSet:separators];
    
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    for (NSString *component in components) {
        NSString *trimmed = [[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        if (trimmed.length > 0) {
            [symbols addObject:trimmed];
        }
    }
    
    return [symbols copy];
}

@end
