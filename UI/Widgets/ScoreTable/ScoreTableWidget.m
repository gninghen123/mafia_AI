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
#import "ScoreTableWidget+Export.h"

#import "ScoreTableWidget_Private.h"  // ✅ IMPORTA IL PRIVATE HEADER

@implementation ScoreTableWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type {
    self = [super initWithType:type];  // ✅ CORRETTO
    if (self) {
        self.scoreResults = [NSMutableArray array];
        self.currentSymbols = [NSMutableArray array];
        self.symbolDataCache = [NSMutableDictionary dictionary];
        self.isCalculating = NO;
        
        [self initializeStooqDataManager];

        // Load default strategy
        self.currentStrategy = [[StrategyManager sharedManager] defaultStrategy];
        
        NSLog(@"✅ ScoreTableWidget initialized with strategy: %@", self.currentStrategy.strategyName);
    }
    return self;
}

#pragma mark - StooqDataManager Initialization

- (void)initializeStooqDataManager {
    // ✅ Leggi il path salvato da StooqScreenerWidget (stessa chiave usata in loadInitialData)
    NSString *savedPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"StooqDataDirectory"];
    
    if (savedPath) {
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDir;
        
        // Verifica che la directory esista ancora
        if ([fm fileExistsAtPath:savedPath isDirectory:&isDir] && isDir) {
            NSLog(@"✅ ScoreTableWidget: Using saved data directory: %@", savedPath);
            self.stooqManager = [[StooqDataManager alloc] initWithDataDirectory:savedPath];
            return;
        } else {
            NSLog(@"⚠️ ScoreTableWidget: Saved directory no longer exists: %@", savedPath);
        }
    } else {
        NSLog(@"⚠️ ScoreTableWidget: No saved data directory found");
    }
    
    // ✅ Fallback: usa path di default se non c'è path salvato
    NSString *fallbackPath = [@"~/Documents/stooq_data" stringByExpandingTildeInPath];
    NSLog(@"ℹ️ ScoreTableWidget: Using fallback path: %@", fallbackPath);
    self.stooqManager = [[StooqDataManager alloc] initWithDataDirectory:fallbackPath];
}

#pragma mark - BaseWidget Override

- (void)setupContentView {
   
  
      
      [super setupContentView];
      
     
      
    NSLog(@"🔧 ScoreTableWidget: Setting up UI...");
    
    // Setup UI programmatically
    [self setupUI];
    [self setupTableColumns];
    [self loadStrategies];
    
    // Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDataHubUpdate:)
                                                 name:@"DataHubDataLoadedNotification"
                                               object:nil];
    
    NSLog(@"✅ ScoreTableWidget: UI setup complete");
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Setup

- (void)setupUI {
    // Remove placeholder
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    CGFloat padding = 10;
    CGFloat inputHeight = 28; // ✅ RIDOTTO: Una sola riga come MultiChart
    
    // 1️⃣ SYMBOL INPUT (mini, top)
    self.symbolInputScrollView = [[NSScrollView alloc] init];
    self.symbolInputScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolInputScrollView.hasVerticalScroller = NO;  // ✅ No scroll verticale
    self.symbolInputScrollView.borderType = NSBezelBorder;
    
    self.symbolInputTextView = [[NSTextView alloc] init];
    self.symbolInputTextView.font = [NSFont systemFontOfSize:12];
    self.symbolInputTextView.delegate = self;
    self.symbolInputTextView.string = @"Symbols (or use chain)";
    self.symbolInputTextView.textColor = [NSColor secondaryLabelColor]; // ✅ Placeholder style
    
    self.symbolInputScrollView.documentView = self.symbolInputTextView;
    [self.contentView addSubview:self.symbolInputScrollView];
    
    // 2️⃣ CONTROLS ROW (stessa riga del text input)
    self.strategySelector = [[NSPopUpButton alloc] init];
    self.strategySelector.translatesAutoresizingMaskIntoConstraints = NO;
    [self.strategySelector setTarget:self];
    [self.strategySelector setAction:@selector(strategyChanged:)];
    [self.contentView addSubview:self.strategySelector];
    
    self.configureButton = [[NSButton alloc] init];
    self.configureButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.configureButton setTitle:@"Configure"];
    [self.configureButton setTarget:self];
    [self.configureButton setAction:@selector(configureStrategy:)];
    [self.configureButton setBezelStyle:NSBezelStyleRounded];
    [self.contentView addSubview:self.configureButton];
    
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.refreshButton setTitle:@"Refresh"];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshScores:)];
    [self.refreshButton setBezelStyle:NSBezelStyleRounded];
    [self.contentView addSubview:self.refreshButton];
    
    self.exportButton = [[NSButton alloc] init];
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.exportButton setTitle:@"Export"];
    [self.exportButton setTarget:self];
    [self.exportButton setAction:@selector(exportToCSV:)];
    [self.exportButton setBezelStyle:NSBezelStyleRounded];
    [self.contentView addSubview:self.exportButton];
    
    // 3️⃣ TABLE VIEW (massima priorità - prende quasi tutto lo spazio)
    self.tableScrollView = [[NSScrollView alloc] init];
    self.tableScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableScrollView.hasVerticalScroller = YES;
    self.tableScrollView.hasHorizontalScroller = YES;
    self.tableScrollView.borderType = NSBezelBorder;
    
    self.scoreTableView = [[NSTableView alloc] init];
    self.scoreTableView.dataSource = self;
    self.scoreTableView.delegate = self;
    self.scoreTableView.allowsMultipleSelection = YES;
    self.scoreTableView.usesAlternatingRowBackgroundColors = YES;
    self.scoreTableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    
    self.tableScrollView.documentView = self.scoreTableView;
    [self.contentView addSubview:self.tableScrollView];
    
    // 4️⃣ STATUS BAR (piccolo, bottom)
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.stringValue = @"Ready";
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [self.contentView addSubview:self.statusLabel];
    
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.displayedWhenStopped = NO;
    [self.contentView addSubview:self.loadingIndicator];
    // ✅ NUOVO: Progress Bar
    self.progressBar = [[NSProgressIndicator alloc] init];
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressBar.style = NSProgressIndicatorStyleBar;
    self.progressBar.minValue = 0;
    self.progressBar.maxValue = 100;
    self.progressBar.doubleValue = 0;
    self.progressBar.hidden = YES; // Nascosto di default
    [self.contentView addSubview:self.progressBar];
    
    // ✅ NUOVO: Cancel Button
    self.cancelButton = [[NSButton alloc] init];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cancelButton setTitle:@"Cancel"];
    [self.cancelButton setBezelStyle:NSBezelStyleRounded];
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelCalculation:);
    self.cancelButton.hidden = YES; // Nascosto di default
    [self.contentView addSubview:self.cancelButton];
    
    // 🎯 CONSTRAINTS - Layout compatto
    [NSLayoutConstraint activateConstraints:@[
        // TOP ROW: Symbol Input + Controls (tutti sulla stessa riga, altezza fissa 28px)
        [self.symbolInputScrollView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:padding],
        [self.symbolInputScrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.symbolInputScrollView.heightAnchor constraintEqualToConstant:inputHeight],
        [self.symbolInputScrollView.widthAnchor constraintEqualToConstant:150], // ✅ Larghezza fissa piccola
        
        [self.strategySelector.centerYAnchor constraintEqualToAnchor:self.symbolInputScrollView.centerYAnchor],
        [self.strategySelector.leadingAnchor constraintEqualToAnchor:self.symbolInputScrollView.trailingAnchor constant:10],
        [self.strategySelector.widthAnchor constraintEqualToConstant:200],
        
        [self.configureButton.centerYAnchor constraintEqualToAnchor:self.symbolInputScrollView.centerYAnchor],
        [self.configureButton.leadingAnchor constraintEqualToAnchor:self.strategySelector.trailingAnchor constant:10],
        [self.configureButton.widthAnchor constraintEqualToConstant:100],
        
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.symbolInputScrollView.centerYAnchor],
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.configureButton.trailingAnchor constant:10],
        [self.refreshButton.widthAnchor constraintEqualToConstant:80],
        
        [self.exportButton.centerYAnchor constraintEqualToAnchor:self.symbolInputScrollView.centerYAnchor],
        [self.exportButton.leadingAnchor constraintEqualToAnchor:self.refreshButton.trailingAnchor constant:10],
        [self.exportButton.widthAnchor constraintEqualToConstant:80],
        
        // TABLE VIEW - Riempie quasi tutto lo spazio verticale
        [self.tableScrollView.topAnchor constraintEqualToAnchor:self.symbolInputScrollView.bottomAnchor constant:padding],
        [self.tableScrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.tableScrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [self.tableScrollView.bottomAnchor constraintEqualToAnchor:self.statusLabel.topAnchor constant:-5],
        
        // STATUS BAR - Piccolo footer
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.statusLabel.heightAnchor constraintEqualToConstant:18],
        
        // Progress Bar (affianco a status label)
              [self.progressBar.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor],
              [self.progressBar.leadingAnchor constraintEqualToAnchor:self.statusLabel.trailingAnchor constant:10],
              [self.progressBar.widthAnchor constraintEqualToConstant:150],
              [self.progressBar.heightAnchor constraintEqualToConstant:16],
              
              // Cancel Button (dopo progress bar)
              [self.cancelButton.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor],
              [self.cancelButton.leadingAnchor constraintEqualToAnchor:self.progressBar.trailingAnchor constant:10],
              [self.cancelButton.widthAnchor constraintEqualToConstant:60],
              
              // Loading Indicator (dopo cancel button)
              [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor],
              [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.cancelButton.trailingAnchor constant:10],
              [self.loadingIndicator.widthAnchor constraintEqualToConstant:16],
              [self.loadingIndicator.heightAnchor constraintEqualToConstant:16]
    ]];
    
    NSLog(@"✅ UI setup complete with compact layout (chain-optimized)");
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


#pragma mark - Chain Integration

- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"📊 ScoreTableWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
    
    if (symbols.count == 0) {
        NSLog(@"⚠️ No symbols received from chain");
        return;
    }
    
    // REPLACE - Sostituisci i vecchi simboli
    self.symbolInputTextView.string = [symbols componentsJoinedByString:@", "];
    self.symbolInputTextView.textColor = [NSColor labelColor];
    
    // Show feedback ma NON calcola
    [self showChainFeedback:[NSString stringWithFormat:@"📥 Received %lu symbols (press Refresh to calculate)", (unsigned long)symbols.count]];
    
    NSLog(@"✅ Symbols loaded in text field, waiting for manual refresh");
}


#pragma mark - Cancel Support

- (IBAction)cancelCalculation:(id)sender {
    NSLog(@"❌ User cancelled calculation");
    self.isCancelled = YES;
    
    [self hideLoadingUI];
    self.statusLabel.stringValue = @"Cancelled";
}

- (void)showLoadingUI {
    self.progressBar.hidden = NO;
    self.progressBar.doubleValue = 0;
    self.cancelButton.hidden = NO;
    [self.loadingIndicator startAnimation:nil];
    self.isCancelled = NO;
}

- (void)hideLoadingUI {
    self.progressBar.hidden = YES;
    self.cancelButton.hidden = YES;
    [self.loadingIndicator stopAnimation:nil];
    self.isCalculating = NO;
}

- (void)updateProgress:(NSInteger)current total:(NSInteger)total {
    double percentage = (double)current / (double)total * 100.0;
    self.progressBar.doubleValue = percentage;
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Loading... (%ld/%ld)", (long)current, (long)total];
}


#pragma mark - Helper Methods

- (NSColor *)colorForScore:(CGFloat)score {
    // Color coding basato sul punteggio
    // Score range: -100 to +100 (normalized weights)
    
    if (score >= 75.0) {
        // Excellent: Dark Green
        return [NSColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:1.0];
    }
    else if (score >= 50.0) {
        // Good: Green
        return [NSColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
    }
    else if (score >= 25.0) {
        // Average: Yellow/Orange
        return [NSColor colorWithRed:0.8 green:0.6 blue:0.0 alpha:1.0];
    }
    else if (score >= 0.0) {
        // Poor: Orange/Red
        return [NSColor colorWithRed:0.9 green:0.4 blue:0.0 alpha:1.0];
    }
    else {
        // Negative: Red
        return [NSColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0];
    }
}
@end
