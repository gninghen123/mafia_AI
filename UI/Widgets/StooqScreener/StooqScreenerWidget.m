//
//  StooqScreenerWidget.m - PARTE 1
//  TradingApp
//

#import "StooqScreenerWidget.h"
#import "ModelManager.h"
#import "StooqDataManager.h"
#import "ScreenerBatchRunner.h"
#import "ScreenerModel.h"
#import "ScreenerRegistry.h"
#import "BaseScreener.h"
#import "datahub+marketdata.h"
#import "ScreenedSymbol.h"
#import "ExecutionSession.h"
#import "StooqScreenerWidget+BacktestTab.h"  // ← ADD THIS


@interface StooqScreenerWidget () <NSTableViewDelegate, NSTableViewDataSource,
                                    NSOutlineViewDelegate, NSOutlineViewDataSource,  // ← AGGIUNGI
                                    ScreenerBatchRunnerDelegate>


/// Cache dei dati storici dell'ultimo screening
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *lastScreeningCache;

/// Data di riferimento dell'ultimo screening (per validare la cache)
@property (nonatomic, strong) NSDate *lastScreeningDate;

/// ID della session a cui appartiene la cache corrente (nil se è uno screening recente)
@property (nonatomic, strong, nullable) NSString *cachedSessionID;


@property (nonatomic, strong) NSArray<ScreenedSymbol *> *currentModelSymbols;

@property (nonatomic, strong) IBOutlet NSPopUpButton *compactReportButton;
// Tab 4: Archive
@property (nonatomic, strong) NSOutlineView *archiveOutlineView;  // ← CAMBIATO da NSTableView
@property (nonatomic, strong) NSScrollView *archiveScrollView;
@property (nonatomic, strong) NSTableView *archiveSymbolsTableView;
@property (nonatomic, strong) NSScrollView *archiveSymbolsScrollView;
@property (nonatomic, strong) NSSplitView *archiveSplitView;
@property (nonatomic, strong) NSTextField *archiveHeaderLabel;
@property (nonatomic, strong) NSButton *deleteArchiveButton;
@property (nonatomic, strong) NSButton *exportArchiveButton;
@property (nonatomic, strong) NSButton *updateArchiveButton;

// Archive data (NUOVO FORMATO)
@property (nonatomic, strong) NSMutableArray<ExecutionSession *> *archivedSessions;
@property (nonatomic, strong) ExecutionSession *selectedSession;
@property (nonatomic, strong) ModelResult *selectedModelResult;  // ← NUOVO: modello selezionato

// Archive data
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *archivedResults;  // Array di {date, modelName, symbols}
@property (nonatomic, strong) NSDictionary *selectedArchiveEntry;  // Entry selezionata
@property (nonatomic, strong) StooqDataManager *currentPriceDataManager;  // Per calcolare var%

// Aggiungi questa property all'interface
@property (nonatomic, strong) NSButton *generateReportButton;
// Managers
@property (nonatomic, strong) ModelManager *modelManager;
@property (nonatomic, strong) StooqDataManager *dataManager;
@property (nonatomic, strong) ScreenerBatchRunner *batchRunner;

// UI Components - Tabs
@property (nonatomic, strong) NSTabView *tabView;

// Tab 1: Models - Split View
@property (nonatomic, strong) NSSplitView *modelsSplitView;

// Left side: Models list
@property (nonatomic, strong) NSTableView *modelsTableView;
@property (nonatomic, strong) NSScrollView *modelsScrollView;
@property (nonatomic, strong) NSButton *createModelButton;
@property (nonatomic, strong) NSButton *deleteModelButton;
@property (nonatomic, strong) NSButton *duplicateModelButton;

// Right side: Model editor - UPDATED
@property (nonatomic, strong) NSTableView *screenersTableView;  // Screeners list
@property (nonatomic, strong) NSScrollView *screenersScrollView;
@property (nonatomic, strong) NSTableView *parametersTableView;  // Parameters for selected screener
@property (nonatomic, strong) NSScrollView *parametersScrollView;
@property (nonatomic, strong) NSButton *addScreenerButton;
@property (nonatomic, strong) NSButton *removeScreenerButton;
@property (nonatomic, strong) NSButton *saveChangesButton;
@property (nonatomic, strong) NSButton *revertChangesButton;
@property (nonatomic, strong) NSTextField *modelNameField;
@property (nonatomic, strong) NSTextField *modelDescriptionField;

// Bottom bar (Models tab)
@property (nonatomic, strong) NSButton *runButton;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSTextField *universeLabel;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;

// Tab 2: Results - NEW STRUCTURE

@property (nonatomic, strong) NSButton *sendSelectedButton;
@property (nonatomic, strong) NSButton *sendAllButton;


// Bottom bar
@property (nonatomic, strong) NSButton *exportButton;
@property (nonatomic, strong) NSButton *clearResultsButton;
@property (nonatomic, strong) NSTextField *resultsStatusLabel;


// Tab 3: Settings
@property (nonatomic, strong) NSTextField *dataPathField;
@property (nonatomic, strong) NSButton *browseButton;
@property (nonatomic, strong) NSButton *scanDatabaseButton;
@property (nonatomic, strong) NSTextField *symbolCountLabel;

// Data
@property (nonatomic, strong) NSMutableArray<ScreenerModel *> *models;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ModelResult *> *executionResults;
@property (nonatomic, strong) NSArray<NSString *> *availableSymbols;

// Model Editor State
@property (nonatomic, strong, nullable) ScreenerModel *selectedModel;
@property (nonatomic, strong, nullable) ScreenerModel *editingModel;
@property (nonatomic, strong, nullable) ScreenerStep *selectedStep;  // Currently selected screener step
@property (nonatomic, assign) BOOL hasUnsavedChanges;

@end

@implementation StooqScreenerWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)widgetType{
    self = [super initWithType:widgetType];
    if (self) {
        _models = [NSMutableArray array];
        _executionResults = [NSMutableDictionary dictionary];
        _selectedExchanges = @[@"nasdaq", @"nyse"];
        _modelManager = [ModelManager sharedManager];
        _archivedSessions = [NSMutableArray array];

        [self initDataBase];
    }
    return self;
}

- (void)initDataBase{
    [self loadInitialData];
}


#pragma mark - BaseWidget Overrides

- (NSString *)widgetTitle {
    return @"Stooq Screener";
}

- (NSSize)defaultSize {
    return NSMakeSize(1000, 700);
}

- (NSSize)minimumSize {
    return NSMakeSize(800, 600);
}

- (void)setupContentView {
    [super setupContentView];
    [self setupUI];
    [self loadInitialData];
    [self loadArchivedSessions];

}

#pragma mark - UI Setup

- (void)setupUI {
    self.tabView = [[NSTabView alloc] initWithFrame:NSZeroRect];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.tabView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [self.tabView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
        [self.tabView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10]
    ]];
    
    [self setupModelsTab];
    [self setupArchiveTab];  // ✅ NUOVO TAB
    [self setupBacktestTab];
    [self setupSettingsTab];
}

- (void)setupArchiveTab {
    NSView *archiveView = [[NSView alloc] init];
    
    // Split view: sinistra = lista archive, destra = simboli con var%
    self.archiveSplitView = [[NSSplitView alloc] init];
    self.archiveSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.archiveSplitView.vertical = YES;
    self.archiveSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [archiveView addSubview:self.archiveSplitView];
    
    // Left side: Archive list
    NSView *archiveListView = [self setupArchiveListView];
    [self.archiveSplitView addArrangedSubview:archiveListView];
    
    // Right side: Symbols with var%
    NSView *archiveSymbolsView = [self setupArchiveSymbolsView];
    [self.archiveSplitView addArrangedSubview:archiveSymbolsView];
    
    // BOTTOM BAR - Tutti i bottoni
    self.deleteArchiveButton = [NSButton buttonWithTitle:@"Delete"
                                                   target:self
                                                   action:@selector(deleteArchiveEntry:)];
    self.deleteArchiveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteArchiveButton.enabled = NO;
    [archiveView addSubview:self.deleteArchiveButton];
    
    self.exportArchiveButton = [NSButton buttonWithTitle:@"Export"
                                                   target:self
                                                   action:@selector(exportArchive:)];
    self.exportArchiveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.exportArchiveButton.enabled = NO;
    [archiveView addSubview:self.exportArchiveButton];
    
    // Generate Report Button
    self.generateReportButton = [NSButton buttonWithTitle:@"Generate Report"
                                                    target:self
                                                    action:@selector(generateArchiveReport:)];
    self.generateReportButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.generateReportButton.enabled = NO;
    [archiveView addSubview:self.generateReportButton];
    
    // Compact Report PopUpButton
    self.compactReportButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:YES];
    [self.compactReportButton addItemWithTitle:@"Compact Report"];
    [self.compactReportButton.menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *allItem = [[NSMenuItem alloc] initWithTitle:@"All Symbols"
                                                      action:@selector(copyArchiveAllSymbols:)
                                               keyEquivalent:@""];
    allItem.target = self;
    [self.compactReportButton.menu addItem:allItem];
    
    NSMenuItem *selectedItem = [[NSMenuItem alloc] initWithTitle:@"Selected Only"
                                                           action:@selector(copyArchiveSelectedSymbols:)
                                                    keyEquivalent:@""];
    selectedItem.target = self;
    [self.compactReportButton.menu addItem:selectedItem];
    
    self.compactReportButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.compactReportButton.enabled = NO;
    [archiveView addSubview:self.compactReportButton];
    
    // Send buttons
    self.sendSelectedButton = [NSButton buttonWithTitle:@"Send Selected"
                                                  target:self
                                                  action:@selector(sendSelectedSymbols:)];
    self.sendSelectedButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.sendSelectedButton.enabled = NO;
    [archiveView addSubview:self.sendSelectedButton];
    
    self.sendAllButton = [NSButton buttonWithTitle:@"Send All"
                                             target:self
                                             action:@selector(sendAllSymbols:)];
    self.sendAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.sendAllButton.enabled = NO;
    [archiveView addSubview:self.sendAllButton];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.archiveSplitView.topAnchor constraintEqualToAnchor:archiveView.topAnchor constant:10],
        [self.archiveSplitView.leadingAnchor constraintEqualToAnchor:archiveView.leadingAnchor constant:10],
        [self.archiveSplitView.trailingAnchor constraintEqualToAnchor:archiveView.trailingAnchor constant:-10],
        [self.archiveSplitView.bottomAnchor constraintEqualToAnchor:self.deleteArchiveButton.topAnchor constant:-10],
        
        // Bottom bar buttons (da sinistra a destra)
        [self.deleteArchiveButton.leadingAnchor constraintEqualToAnchor:archiveView.leadingAnchor constant:10],
        [self.deleteArchiveButton.bottomAnchor constraintEqualToAnchor:archiveView.bottomAnchor constant:-10],
        
        [self.exportArchiveButton.leadingAnchor constraintEqualToAnchor:self.deleteArchiveButton.trailingAnchor constant:10],
        [self.exportArchiveButton.centerYAnchor constraintEqualToAnchor:self.deleteArchiveButton.centerYAnchor],
        
        [self.generateReportButton.leadingAnchor constraintEqualToAnchor:self.exportArchiveButton.trailingAnchor constant:20],
        [self.generateReportButton.centerYAnchor constraintEqualToAnchor:self.deleteArchiveButton.centerYAnchor],
        
        [self.compactReportButton.leadingAnchor constraintEqualToAnchor:self.generateReportButton.trailingAnchor constant:10],
        [self.compactReportButton.centerYAnchor constraintEqualToAnchor:self.deleteArchiveButton.centerYAnchor],
        
        [self.sendSelectedButton.leadingAnchor constraintEqualToAnchor:self.compactReportButton.trailingAnchor constant:20],
        [self.sendSelectedButton.centerYAnchor constraintEqualToAnchor:self.deleteArchiveButton.centerYAnchor],
        
        [self.sendAllButton.leadingAnchor constraintEqualToAnchor:self.sendSelectedButton.trailingAnchor constant:10],
        [self.sendAllButton.centerYAnchor constraintEqualToAnchor:self.deleteArchiveButton.centerYAnchor]
    ]];
    
    // Set split position
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat totalWidth = self.archiveSplitView.frame.size.width;
        if (totalWidth > 0) {
            [self.archiveSplitView setPosition:totalWidth * 0.35 ofDividerAtIndex:0];
        }
    });
    
    // Tab item
    NSTabViewItem *resultsTab = [[NSTabViewItem alloc] initWithIdentifier:@"results"];
    resultsTab.label = @"Results";
    resultsTab.view = archiveView;
    [self.tabView addTabViewItem:resultsTab];
    
    // Inizializza array archivio
    self.archivedResults = [NSMutableArray array];
}

- (NSView *)setupArchiveListView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 800)];
    
    NSTextField *label = [NSTextField labelWithString:@"Screening Sessions"];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [NSFont boldSystemFontOfSize:13];
    [view addSubview:label];
    
    // OUTLINE VIEW
    self.archiveOutlineView = [[NSOutlineView alloc] init];
    self.archiveOutlineView.delegate = self;
    self.archiveOutlineView.dataSource = self;
    self.archiveOutlineView.allowsMultipleSelection = NO;
    self.archiveOutlineView.usesAlternatingRowBackgroundColors = YES;
    self.archiveOutlineView.indentationPerLevel = 16;
    self.archiveOutlineView.autoresizesOutlineColumn = YES;
    
    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameCol.title = @"Date / Model";
    nameCol.width = 250;
    nameCol.minWidth = 150;
    [self.archiveOutlineView addTableColumn:nameCol];
    [self.archiveOutlineView setOutlineTableColumn:nameCol];
    
    NSTableColumn *countCol = [[NSTableColumn alloc] initWithIdentifier:@"count"];
    countCol.title = @"Symbols";
    countCol.width = 70;
    countCol.minWidth = 50;
    [self.archiveOutlineView addTableColumn:countCol];
    
    NSTableColumn *timeCol = [[NSTableColumn alloc] initWithIdentifier:@"time"];
    timeCol.title = @"Time";
    timeCol.width = 60;
    timeCol.minWidth = 50;
    [self.archiveOutlineView addTableColumn:timeCol];
    
    self.archiveScrollView = [[NSScrollView alloc] init];
    self.archiveScrollView.documentView = self.archiveOutlineView;
    self.archiveScrollView.hasVerticalScroller = YES;
    self.archiveScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.archiveScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:view.topAnchor constant:5],
        [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:5],
        
        [self.archiveScrollView.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:5],
        [self.archiveScrollView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.archiveScrollView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [self.archiveScrollView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];
    
    return view;
}


- (NSView *)setupArchiveSymbolsView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 800)];
    
    self.archiveHeaderLabel = [NSTextField labelWithString:@"Select a session"];
    self.archiveHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.archiveHeaderLabel.font = [NSFont boldSystemFontOfSize:13];
    [view addSubview:self.archiveHeaderLabel];
    
    self.archiveSymbolsTableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 500, 800)];
    self.archiveSymbolsTableView.delegate = self;
    self.archiveSymbolsTableView.dataSource = self;
    self.archiveSymbolsTableView.allowsMultipleSelection = YES;
    self.archiveSymbolsTableView.usesAlternatingRowBackgroundColors = YES;
    
    // Colonna Select (checkbox)
    NSTableColumn *selectCol = [[NSTableColumn alloc] initWithIdentifier:@"archive_select"];
    selectCol.title = @"✓";
    selectCol.width = 30;
    selectCol.minWidth = 30;
    selectCol.maxWidth = 30;
    [self.archiveSymbolsTableView addTableColumn:selectCol];
    
    // Colonna Symbol (con sorting alfabetico)
    NSTableColumn *symbolCol = [[NSTableColumn alloc] initWithIdentifier:@"archive_symbol"];
    symbolCol.title = @"Symbol";
    symbolCol.width = 100;
    NSSortDescriptor *symbolSort = [NSSortDescriptor sortDescriptorWithKey:@"symbol"
                                                                  ascending:YES
                                                                   selector:@selector(localizedCaseInsensitiveCompare:)];
    symbolCol.sortDescriptorPrototype = symbolSort;
    [self.archiveSymbolsTableView addTableColumn:symbolCol];
    
    // Colonna Signal Price (con sorting numerico)
    NSTableColumn *signalPriceCol = [[NSTableColumn alloc] initWithIdentifier:@"signal_price"];
    signalPriceCol.title = @"Signal Price";
    signalPriceCol.width = 100;
    NSSortDescriptor *signalPriceSort = [NSSortDescriptor sortDescriptorWithKey:@"metadata.signalPrice"
                                                                       ascending:NO];
    signalPriceCol.sortDescriptorPrototype = signalPriceSort;
    [self.archiveSymbolsTableView addTableColumn:signalPriceCol];
    
    // Colonna Current Price (con sorting numerico)
    NSTableColumn *currentPriceCol = [[NSTableColumn alloc] initWithIdentifier:@"current_price"];
    currentPriceCol.title = @"Current Price";
    currentPriceCol.width = 100;
    NSSortDescriptor *currentPriceSort = [NSSortDescriptor sortDescriptorWithKey:@"metadata.currentPrice"
                                                                        ascending:NO];
    currentPriceCol.sortDescriptorPrototype = currentPriceSort;
    [self.archiveSymbolsTableView addTableColumn:currentPriceCol];
    
    // Colonna Var % (con sorting numerico - migliori performance prima)
    NSTableColumn *varCol = [[NSTableColumn alloc] initWithIdentifier:@"var_percent"];
    varCol.title = @"Var %";
    varCol.width = 80;
    NSSortDescriptor *varPercentSort = [NSSortDescriptor sortDescriptorWithKey:@"metadata.changePercent"
                                                                      ascending:NO];
    varCol.sortDescriptorPrototype = varPercentSort;
    [self.archiveSymbolsTableView addTableColumn:varCol];
    
    self.archiveSymbolsScrollView = [[NSScrollView alloc] init];
    self.archiveSymbolsScrollView.documentView = self.archiveSymbolsTableView;
    self.archiveSymbolsScrollView.hasVerticalScroller = YES;
    self.archiveSymbolsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.archiveSymbolsScrollView];
    
    // Stats panel
    self.archiveStatsPanel = [[NSView alloc] init];
    self.archiveStatsPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.archiveStatsPanel.wantsLayer = YES;
    self.archiveStatsPanel.layer.backgroundColor = [[NSColor colorWithWhite:0.15 alpha:1.0] CGColor];
    self.archiveStatsPanel.layer.borderColor = [[NSColor colorWithWhite:0.25 alpha:1.0] CGColor];
    self.archiveStatsPanel.layer.borderWidth = 1.0;
    [view addSubview:self.archiveStatsPanel];
    
    self.statsAllLabel = [NSTextField labelWithString:@"All: --"];
    self.statsAllLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statsAllLabel.font = [NSFont systemFontOfSize:11];
    self.statsAllLabel.textColor = [NSColor colorWithWhite:0.8 alpha:1.0];
    [self.archiveStatsPanel addSubview:self.statsAllLabel];
    
    self.statsSelectedLabel = [NSTextField labelWithString:@"Selected: --"];
    self.statsSelectedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statsSelectedLabel.font = [NSFont systemFontOfSize:11];
    self.statsSelectedLabel.textColor = [NSColor colorWithWhite:0.8 alpha:1.0];
    [self.archiveStatsPanel addSubview:self.statsSelectedLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.archiveHeaderLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:5],
        [self.archiveHeaderLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:5],
        
        [self.archiveSymbolsScrollView.topAnchor constraintEqualToAnchor:self.archiveHeaderLabel.bottomAnchor constant:5],
        [self.archiveSymbolsScrollView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.archiveSymbolsScrollView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [self.archiveSymbolsScrollView.bottomAnchor constraintEqualToAnchor:self.archiveStatsPanel.topAnchor],
        
        [self.archiveStatsPanel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.archiveStatsPanel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [self.archiveStatsPanel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        [self.archiveStatsPanel.heightAnchor constraintEqualToConstant:50],
        
        [self.statsAllLabel.leadingAnchor constraintEqualToAnchor:self.archiveStatsPanel.leadingAnchor constant:10],
        [self.statsAllLabel.topAnchor constraintEqualToAnchor:self.archiveStatsPanel.topAnchor constant:5],
        
        [self.statsSelectedLabel.leadingAnchor constraintEqualToAnchor:self.archiveStatsPanel.leadingAnchor constant:10],
        [self.statsSelectedLabel.topAnchor constraintEqualToAnchor:self.statsAllLabel.bottomAnchor constant:3]
    ]];
    
    return view;
}

- (void)setupModelsTab {
    NSView *modelsView = [[NSView alloc] init];
    
    self.modelsSplitView = [[NSSplitView alloc] init];
    self.modelsSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.modelsSplitView.vertical = YES;
    self.modelsSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [modelsView addSubview:self.modelsSplitView];
    
    NSView *leftView = [self setupModelsListView];
    [self.modelsSplitView addArrangedSubview:leftView];
    
    NSView *rightView = [self setupModelEditorView];
    [self.modelsSplitView addArrangedSubview:rightView];
    
    NSView *bottomBar = [self setupModelsBottomBar];
    bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [modelsView addSubview:bottomBar];
    
    NSTextField *dateLabel = [NSTextField labelWithString:@"Target Date:"];
      dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
      [bottomBar addSubview:dateLabel];
    
    self.targetDatePicker = [[NSDatePicker alloc] init];
        self.targetDatePicker.translatesAutoresizingMaskIntoConstraints = NO;
        self.targetDatePicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
        self.targetDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
        self.targetDatePicker.dateValue = [self.dataManager expectedLastCloseDate]; // Inizializza con data calcolata
        self.targetDatePicker.target = self;
        self.targetDatePicker.action = @selector(targetDateChanged:);
        [bottomBar addSubview:self.targetDatePicker];
    
    
    [NSLayoutConstraint activateConstraints:@[
        [self.modelsSplitView.topAnchor constraintEqualToAnchor:modelsView.topAnchor],
        [self.modelsSplitView.leadingAnchor constraintEqualToAnchor:modelsView.leadingAnchor],
        [self.modelsSplitView.trailingAnchor constraintEqualToAnchor:modelsView.trailingAnchor],
        [self.modelsSplitView.bottomAnchor constraintEqualToAnchor:bottomBar.topAnchor constant:-10],
        
        [bottomBar.leadingAnchor constraintEqualToAnchor:modelsView.leadingAnchor constant:10],
        [bottomBar.trailingAnchor constraintEqualToAnchor:modelsView.trailingAnchor constant:-10],
        [bottomBar.bottomAnchor constraintEqualToAnchor:modelsView.bottomAnchor constant:-10],
        [bottomBar.heightAnchor constraintEqualToConstant:60],
        
        // Label "Target Date:"
        [dateLabel.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor constant:10],
        [dateLabel.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],
        
        // Run button accanto alla label
        [self.runButton.leadingAnchor constraintEqualToAnchor:dateLabel.trailingAnchor constant:20],
        [self.runButton.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],
        
        // Refresh accanto a Run
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.runButton.trailingAnchor constant:10],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],
        
        // ✅ DatePicker DOPO Refresh
        [self.targetDatePicker.leadingAnchor constraintEqualToAnchor:self.refreshButton.trailingAnchor constant:20],
        [self.targetDatePicker.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],
        [self.targetDatePicker.widthAnchor constraintEqualToConstant:160],
        
        // Universe label DOPO il datepicker
        [self.universeLabel.leadingAnchor constraintEqualToAnchor:self.targetDatePicker.trailingAnchor constant:20],
        [self.universeLabel.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],
        
        // Progress indicator in fondo a destra
        [self.progressIndicator.trailingAnchor constraintEqualToAnchor:bottomBar.trailingAnchor constant:-10],
        [self.progressIndicator.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor]
    ]];
        
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat totalWidth = self.modelsSplitView.frame.size.width;
        if (totalWidth > 0) {
            [self.modelsSplitView setPosition:totalWidth * 0.35 ofDividerAtIndex:0];
        }
    });
    
    NSTabViewItem *modelsTab = [[NSTabViewItem alloc] initWithIdentifier:@"models"];
    modelsTab.label = @"Models";
    modelsTab.view = modelsView;
    [self.tabView addTabViewItem:modelsTab];
}

- (NSView *)setupModelsListView {
    NSView *leftView = [[NSView alloc] init];
    
    NSTextField *label = [NSTextField labelWithString:@"Screener Models"];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [NSFont boldSystemFontOfSize:13];
    [leftView addSubview:label];
    
    self.modelsTableView = [[NSTableView alloc] init];
    self.modelsTableView.delegate = self;
    self.modelsTableView.dataSource = self;
    self.modelsTableView.allowsMultipleSelection = YES;
    self.modelsTableView.usesAlternatingRowBackgroundColors = YES;
    
    NSTableColumn *checkCol = [[NSTableColumn alloc] initWithIdentifier:@"enabled"];
    checkCol.title = @"✓";
    checkCol.width = 30;
    [self.modelsTableView addTableColumn:checkCol];
    
    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameCol.title = @"Name";
    nameCol.width = 180;
    [self.modelsTableView addTableColumn:nameCol];
    
    NSTableColumn *stepsCol = [[NSTableColumn alloc] initWithIdentifier:@"steps"];
    stepsCol.title = @"Steps";
    stepsCol.width = 50;
    [self.modelsTableView addTableColumn:stepsCol];
    
    self.modelsScrollView = [[NSScrollView alloc] init];
    self.modelsScrollView.documentView = self.modelsTableView;
    self.modelsScrollView.hasVerticalScroller = YES;
    self.modelsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [leftView addSubview:self.modelsScrollView];
    
    self.createModelButton = [NSButton buttonWithTitle:@"+ New" target:self action:@selector(createNewModel:)];
    self.createModelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [leftView addSubview:self.createModelButton];
    
    self.duplicateModelButton = [NSButton buttonWithTitle:@"Duplicate" target:self action:@selector(duplicateModel:)];
    self.duplicateModelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.duplicateModelButton.enabled = NO;
    [leftView addSubview:self.duplicateModelButton];
    
    self.deleteModelButton = [NSButton buttonWithTitle:@"Delete" target:self action:@selector(deleteModel:)];
    self.deleteModelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteModelButton.enabled = NO;
    [leftView addSubview:self.deleteModelButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:leftView.topAnchor constant:5],
        [label.leadingAnchor constraintEqualToAnchor:leftView.leadingAnchor constant:5],
        
        [self.modelsScrollView.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:5],
        [self.modelsScrollView.leadingAnchor constraintEqualToAnchor:leftView.leadingAnchor],
        [self.modelsScrollView.trailingAnchor constraintEqualToAnchor:leftView.trailingAnchor],
        [self.modelsScrollView.bottomAnchor constraintEqualToAnchor:self.createModelButton.topAnchor constant:-5],
        
        [self.createModelButton.leadingAnchor constraintEqualToAnchor:leftView.leadingAnchor constant:5],
        [self.createModelButton.bottomAnchor constraintEqualToAnchor:leftView.bottomAnchor constant:-5],
        
        [self.duplicateModelButton.leadingAnchor constraintEqualToAnchor:self.createModelButton.trailingAnchor constant:5],
        [self.duplicateModelButton.centerYAnchor constraintEqualToAnchor:self.createModelButton.centerYAnchor],
        
        [self.deleteModelButton.leadingAnchor constraintEqualToAnchor:self.duplicateModelButton.trailingAnchor constant:5],
        [self.deleteModelButton.centerYAnchor constraintEqualToAnchor:self.createModelButton.centerYAnchor]
    ]];
    
    return leftView;
}




- (void)setupSettingsTab {
    NSView *settingsView = [[NSView alloc] init];
    
    NSTextField *pathLabel = [NSTextField labelWithString:@"Stooq Data Directory:"];
    pathLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsView addSubview:pathLabel];
    
    self.dataPathField = [[NSTextField alloc] init];
    self.dataPathField.translatesAutoresizingMaskIntoConstraints = NO;
    self.dataPathField.placeholderString = @"/path/to/stooq/data/";
    [settingsView addSubview:self.dataPathField];
    
    self.browseButton = [NSButton buttonWithTitle:@"Browse..." target:self action:@selector(browseDataDirectory:)];
    self.browseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsView addSubview:self.browseButton];
    
    self.scanDatabaseButton = [NSButton buttonWithTitle:@"Scan Database" target:self action:@selector(scanDatabase:)];
    self.scanDatabaseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsView addSubview:self.scanDatabaseButton];
    
    self.symbolCountLabel = [[NSTextField alloc] init];
    self.symbolCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolCountLabel.editable = NO;
    self.symbolCountLabel.bordered = NO;
    self.symbolCountLabel.backgroundColor = [NSColor clearColor];
    self.symbolCountLabel.stringValue = @"Symbols: --";
    [settingsView addSubview:self.symbolCountLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [pathLabel.topAnchor constraintEqualToAnchor:settingsView.topAnchor constant:20],
        [pathLabel.leadingAnchor constraintEqualToAnchor:settingsView.leadingAnchor constant:20],
        
        [self.dataPathField.topAnchor constraintEqualToAnchor:pathLabel.bottomAnchor constant:8],
        [self.dataPathField.leadingAnchor constraintEqualToAnchor:settingsView.leadingAnchor constant:20],
        [self.dataPathField.trailingAnchor constraintEqualToAnchor:self.browseButton.leadingAnchor constant:-10],
        
        [self.browseButton.centerYAnchor constraintEqualToAnchor:self.dataPathField.centerYAnchor],
        [self.browseButton.trailingAnchor constraintEqualToAnchor:settingsView.trailingAnchor constant:-20],
        [self.browseButton.widthAnchor constraintEqualToConstant:100],
        
        [self.scanDatabaseButton.topAnchor constraintEqualToAnchor:self.dataPathField.bottomAnchor constant:20],
        [self.scanDatabaseButton.leadingAnchor constraintEqualToAnchor:settingsView.leadingAnchor constant:20],
        
        [self.symbolCountLabel.leadingAnchor constraintEqualToAnchor:self.scanDatabaseButton.trailingAnchor constant:20],
        [self.symbolCountLabel.centerYAnchor constraintEqualToAnchor:self.scanDatabaseButton.centerYAnchor]
    ]];
    
    NSTabViewItem *settingsTab = [[NSTabViewItem alloc] initWithIdentifier:@"settings"];
    settingsTab.label = @"Settings";
    settingsTab.view = settingsView;
    [self.tabView addTabViewItem:settingsTab];
}

- (NSView *)setupModelEditorView {
    NSView *rightView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 700, 800)];
    
    // Top: Model name and description
    NSTextField *nameLabel = [NSTextField labelWithString:@"Name:"];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [rightView addSubview:nameLabel];
    
    self.modelNameField = [[NSTextField alloc] init];
    self.modelNameField.translatesAutoresizingMaskIntoConstraints = NO;
    self.modelNameField.placeholderString = @"Model name...";
    self.modelNameField.enabled = NO;
    [rightView addSubview:self.modelNameField];
    
    NSTextField *descLabel = [NSTextField labelWithString:@"Description:"];
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [rightView addSubview:descLabel];
    
    self.modelDescriptionField = [[NSTextField alloc] init];
    self.modelDescriptionField.translatesAutoresizingMaskIntoConstraints = NO;
    self.modelDescriptionField.placeholderString = @"Description...";
    self.modelDescriptionField.enabled = NO;
    [rightView addSubview:self.modelDescriptionField];
    
    // Screeners section
    NSTextField *screenersLabel = [NSTextField labelWithString:@"Screener Pipeline:"];
    screenersLabel.translatesAutoresizingMaskIntoConstraints = NO;
    screenersLabel.font = [NSFont boldSystemFontOfSize:11];
    [rightView addSubview:screenersLabel];
    
    self.screenersTableView = [[NSTableView alloc] init];
    self.screenersTableView.delegate = self;
    self.screenersTableView.dataSource = self;
    self.screenersTableView.usesAlternatingRowBackgroundColors = YES;
    
    NSTableColumn *stepCol = [[NSTableColumn alloc] initWithIdentifier:@"step"];
    stepCol.title = @"#";
    stepCol.width = 30;
    [self.screenersTableView addTableColumn:stepCol];
    
    NSTableColumn *screenerCol = [[NSTableColumn alloc] initWithIdentifier:@"screener"];
    screenerCol.title = @"Screener";
    screenerCol.width = 200;
    [self.screenersTableView addTableColumn:screenerCol];
    
    NSTableColumn *inputCol = [[NSTableColumn alloc] initWithIdentifier:@"input"];
    inputCol.title = @"Input";
    inputCol.width = 80;
    [self.screenersTableView addTableColumn:inputCol];
    
    self.screenersScrollView = [[NSScrollView alloc] init];
    self.screenersScrollView.documentView = self.screenersTableView;
    self.screenersScrollView.hasVerticalScroller = YES;
    self.screenersScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [rightView addSubview:self.screenersScrollView];
    
    self.addScreenerButton = [NSButton buttonWithTitle:@"+ Add" target:self action:@selector(addScreener:)];
    self.addScreenerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addScreenerButton.enabled = NO;
    [rightView addSubview:self.addScreenerButton];
    
    self.removeScreenerButton = [NSButton buttonWithTitle:@"− Remove" target:self action:@selector(removeScreener:)];
    self.removeScreenerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.removeScreenerButton.enabled = NO;
    [rightView addSubview:self.removeScreenerButton];
    
    // Parameters section
    NSTextField *paramsLabel = [NSTextField labelWithString:@"Parameters:"];
    paramsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    paramsLabel.font = [NSFont boldSystemFontOfSize:11];
    [rightView addSubview:paramsLabel];
    
    self.parametersTableView = [[NSTableView alloc] init];
    self.parametersTableView.delegate = self;
    self.parametersTableView.dataSource = self;
    self.parametersTableView.usesAlternatingRowBackgroundColors = YES;
    
    NSTableColumn *paramNameCol = [[NSTableColumn alloc] initWithIdentifier:@"param_name"];
    paramNameCol.title = @"Parameter";
    paramNameCol.width = 150;
    [self.parametersTableView addTableColumn:paramNameCol];
    
    NSTableColumn *paramValueCol = [[NSTableColumn alloc] initWithIdentifier:@"param_value"];
    paramValueCol.title = @"Value";
    paramValueCol.width = 150;
    [self.parametersTableView addTableColumn:paramValueCol];
    
    self.parametersScrollView = [[NSScrollView alloc] init];
    self.parametersScrollView.documentView = self.parametersTableView;
    self.parametersScrollView.hasVerticalScroller = YES;
    self.parametersScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [rightView addSubview:self.parametersScrollView];
    
    // Bottom buttons
    self.saveChangesButton = [NSButton buttonWithTitle:@"Save" target:self action:@selector(saveModelChanges:)];
    self.saveChangesButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveChangesButton.enabled = NO;
    [rightView addSubview:self.saveChangesButton];
    
    self.revertChangesButton = [NSButton buttonWithTitle:@"Revert" target:self action:@selector(revertModelChanges:)];
    self.revertChangesButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.revertChangesButton.enabled = NO;
    [rightView addSubview:self.revertChangesButton];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Name
        [nameLabel.topAnchor constraintEqualToAnchor:rightView.topAnchor constant:5],
        [nameLabel.leadingAnchor constraintEqualToAnchor:rightView.leadingAnchor constant:5],
        [self.modelNameField.centerYAnchor constraintEqualToAnchor:nameLabel.centerYAnchor],
        [self.modelNameField.leadingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor constant:5],
        [self.modelNameField.trailingAnchor constraintEqualToAnchor:rightView.trailingAnchor constant:-5],
        
        // Description
        [descLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:8],
        [descLabel.leadingAnchor constraintEqualToAnchor:rightView.leadingAnchor constant:5],
        [self.modelDescriptionField.centerYAnchor constraintEqualToAnchor:descLabel.centerYAnchor],
        [self.modelDescriptionField.leadingAnchor constraintEqualToAnchor:descLabel.trailingAnchor constant:5],
        [self.modelDescriptionField.trailingAnchor constraintEqualToAnchor:rightView.trailingAnchor constant:-5],
        
        // Screeners
        [screenersLabel.topAnchor constraintEqualToAnchor:descLabel.bottomAnchor constant:15],
        [screenersLabel.leadingAnchor constraintEqualToAnchor:rightView.leadingAnchor constant:5],
        
        [self.screenersScrollView.topAnchor constraintEqualToAnchor:screenersLabel.bottomAnchor constant:5],
        [self.screenersScrollView.leadingAnchor constraintEqualToAnchor:rightView.leadingAnchor],
        [self.screenersScrollView.trailingAnchor constraintEqualToAnchor:rightView.trailingAnchor],
        [self.screenersScrollView.heightAnchor constraintEqualToConstant:120],
        
        [self.addScreenerButton.topAnchor constraintEqualToAnchor:self.screenersScrollView.bottomAnchor constant:5],
        [self.addScreenerButton.leadingAnchor constraintEqualToAnchor:rightView.leadingAnchor constant:5],
        
        [self.removeScreenerButton.centerYAnchor constraintEqualToAnchor:self.addScreenerButton.centerYAnchor],
        [self.removeScreenerButton.leadingAnchor constraintEqualToAnchor:self.addScreenerButton.trailingAnchor constant:5],
        
        // Parameters
        [paramsLabel.topAnchor constraintEqualToAnchor:self.addScreenerButton.bottomAnchor constant:15],
        [paramsLabel.leadingAnchor constraintEqualToAnchor:rightView.leadingAnchor constant:5],
        
        [self.parametersScrollView.topAnchor constraintEqualToAnchor:paramsLabel.bottomAnchor constant:5],
        [self.parametersScrollView.leadingAnchor constraintEqualToAnchor:rightView.leadingAnchor],
        [self.parametersScrollView.trailingAnchor constraintEqualToAnchor:rightView.trailingAnchor],
        [self.parametersScrollView.bottomAnchor constraintEqualToAnchor:self.saveChangesButton.topAnchor constant:-10],
        
        // Save/Revert
        [self.saveChangesButton.trailingAnchor constraintEqualToAnchor:rightView.trailingAnchor constant:-5],
        [self.saveChangesButton.bottomAnchor constraintEqualToAnchor:rightView.bottomAnchor constant:-5],
        
        [self.revertChangesButton.trailingAnchor constraintEqualToAnchor:self.saveChangesButton.leadingAnchor constant:-5],
        [self.revertChangesButton.centerYAnchor constraintEqualToAnchor:self.saveChangesButton.centerYAnchor]
    ]];
    
    return rightView;
}



- (NSView *)setupModelsBottomBar {
    NSView *bottomBar = [[NSView alloc] init];
    
    self.runButton = [NSButton buttonWithTitle:@"Run Selected Models" target:self action:@selector(runSelectedModels)];
    self.runButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.runButton.bezelStyle = NSBezelStyleRounded;
    [bottomBar addSubview:self.runButton];
    
    self.refreshButton = [NSButton buttonWithTitle:@"Refresh" target:self action:@selector(refreshModels)];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [bottomBar addSubview:self.refreshButton];
    
    self.universeLabel = [[NSTextField alloc] init];
    self.universeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.universeLabel.editable = NO;
    self.universeLabel.bordered = NO;
    self.universeLabel.backgroundColor = [NSColor clearColor];
    self.universeLabel.stringValue = @"Universe: -- symbols";
    [bottomBar addSubview:self.universeLabel];
    
    self.progressIndicator = [[NSProgressIndicator alloc] init];
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressIndicator.style = NSProgressIndicatorStyleBar;
    self.progressIndicator.indeterminate = NO;
    self.progressIndicator.minValue = 0.0;
    self.progressIndicator.maxValue = 1.0;
    self.progressIndicator.hidden = YES;
    [bottomBar addSubview:self.progressIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.runButton.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor],
        [self.runButton.bottomAnchor constraintEqualToAnchor:bottomBar.bottomAnchor],
        [self.runButton.widthAnchor constraintEqualToConstant:180],
        
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.runButton.trailingAnchor constant:10],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.runButton.centerYAnchor],
        
        [self.universeLabel.trailingAnchor constraintEqualToAnchor:bottomBar.trailingAnchor],
        [self.universeLabel.centerYAnchor constraintEqualToAnchor:self.runButton.centerYAnchor],
        
        [self.progressIndicator.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor],
        [self.progressIndicator.trailingAnchor constraintEqualToAnchor:bottomBar.trailingAnchor],
        [self.progressIndicator.bottomAnchor constraintEqualToAnchor:self.runButton.topAnchor constant:-5],
        [self.progressIndicator.heightAnchor constraintEqualToConstant:20]
    ]];
    
    return bottomBar;
}



#pragma mark - Data Loading

- (void)loadInitialData {
    [self refreshModels];
    
    // ✅ NUOVO: Inizializza la data target del datepicker PRIMA dello scan
    NSDate *initialDate = [self.dataManager expectedLastCloseDate];
    if (self.targetDatePicker) {
        self.targetDatePicker.dateValue = initialDate;
    }
    self.dataManager.targetDate = initialDate;
    
    NSLog(@"📅 Target date initialized to: %@", 
          [NSDateFormatter localizedStringFromDate:initialDate
                                         dateStyle:NSDateFormatterShortStyle
                                         timeStyle:NSDateFormatterNoStyle]);
    
    // ✅ Carica il path salvato
    NSString *savedPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"StooqDataDirectory"];
    if (savedPath) {
        NSFileManager *fm = [NSFileManager defaultManager];
        
        // Verifica che la directory esista ancora
        BOOL isDir;
        if ([fm fileExistsAtPath:savedPath isDirectory:&isDir] && isDir) {
            NSLog(@"✅ Restoring saved data directory: %@", savedPath);
            
            self.dataPathField.stringValue = savedPath;
            [self setDataDirectory:savedPath];
            
            // ✅ Avvia automaticamente lo scan con la data target impostata
            [self autoScanDatabase];
        } else {
            NSLog(@"⚠️ Saved directory no longer exists: %@", savedPath);
            self.dataPathField.stringValue = @"";
            self.symbolCountLabel.stringValue = @"Symbols: Directory not found";
        }
    } else {
        NSLog(@"ℹ️ No saved data directory found");
        self.symbolCountLabel.stringValue = @"Symbols: Please select directory";
    }
}

- (void)autoScanDatabase {
    if (!self.dataManager) {
        NSLog(@"⚠️ Cannot auto-scan: no data manager");
        return;
    }
    
    NSLog(@"🔍 Auto-scanning database...");
    
    // ✅ Mostra indicatore di progresso
    self.progressIndicator.hidden = NO;
    self.progressIndicator.indeterminate = YES;
    [self.progressIndicator startAnimation:nil];
    
    self.symbolCountLabel.stringValue = @"Symbols: Scanning...";
    self.scanDatabaseButton.enabled = NO;
    self.runButton.enabled = NO;
    
    [self.dataManager scanDatabaseWithCompletion:^(NSArray<NSString *> *symbols, NSError *error) {
        // ✅ Nascondi indicatore
        [self.progressIndicator stopAnimation:nil];
        self.progressIndicator.hidden = YES;
        
        if (error) {
            NSLog(@"❌ Auto-scan failed: %@", error.localizedDescription);
            self.symbolCountLabel.stringValue = @"Symbols: Scan failed";
            self.scanDatabaseButton.enabled = YES;
            
            // Mostra alert solo in caso di errore
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Database Scan Failed";
            alert.informativeText = [NSString stringWithFormat:@"Could not scan database:\n%@",
                                    error.localizedDescription];
            alert.alertStyle = NSAlertStyleWarning;
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            
        } else {
            self.availableSymbols = symbols;
            self.symbolCountLabel.stringValue = [NSString stringWithFormat:@"Symbols: %lu",
                                                 (unsigned long)symbols.count];
            self.universeLabel.stringValue = [NSString stringWithFormat:@"Universe: %lu symbols",
                                             (unsigned long)symbols.count];
            self.scanDatabaseButton.enabled = YES;
            self.runButton.enabled = YES;
            
            NSLog(@"✅ Auto-scan complete: %lu symbols loaded", (unsigned long)symbols.count);
        }
    }];
}

- (void)refreshModels {
    [self.modelManager refreshModels];
    self.models = [[self.modelManager allModels] mutableCopy];
    [self.modelsTableView reloadData];
    NSLog(@"✅ Loaded %lu models", (unsigned long)self.models.count);
}

- (void)setDataDirectory:(NSString *)path {
    _dataDirectory = path;
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:@"StooqDataDirectory"];
    
    self.dataManager = [[StooqDataManager alloc] initWithDataDirectory:path];
    self.dataManager.selectedExchanges = self.selectedExchanges;
    
    self.batchRunner = [[ScreenerBatchRunner alloc] initWithDataManager:self.dataManager];
    self.batchRunner.delegate = self;
    
    NSLog(@"✅ Data directory set: %@", path);
}

#pragma mark - Model Editor

- (void)loadModelIntoEditor:(ScreenerModel *)model {
    self.selectedModel = model;
    
    NSDictionary *dict = [model toDictionary];
    self.editingModel = [ScreenerModel fromDictionary:dict];
    
    self.modelNameField.stringValue = model.displayName ?: @"";
    self.modelDescriptionField.stringValue = model.modelDescription ?: @"";
    self.modelNameField.enabled = YES;
    self.modelDescriptionField.enabled = YES;
    
    self.selectedStep = nil;
    
    [self.screenersTableView reloadData];
    [self.parametersTableView reloadData];
    
    self.addScreenerButton.enabled = YES;
    self.removeScreenerButton.enabled = NO;
    self.saveChangesButton.enabled = NO;
    self.revertChangesButton.enabled = NO;
    
    self.hasUnsavedChanges = NO;
    
    NSLog(@"📝 Loaded model: %@ (%lu steps)", model.displayName, (unsigned long)self.editingModel.steps.count);
}

- (void)clearEditor {
    self.selectedModel = nil;
    self.editingModel = nil;
    self.selectedStep = nil;
    
    self.modelNameField.stringValue = @"";
    self.modelDescriptionField.stringValue = @"";
    self.modelNameField.enabled = NO;
    self.modelDescriptionField.enabled = NO;
    
    [self.screenersTableView reloadData];
    [self.parametersTableView reloadData];
    
    self.addScreenerButton.enabled = NO;
    self.removeScreenerButton.enabled = NO;
    self.saveChangesButton.enabled = NO;
    self.revertChangesButton.enabled = NO;
    
    self.hasUnsavedChanges = NO;
}

- (void)markAsModified {
    self.hasUnsavedChanges = YES;
    self.saveChangesButton.enabled = YES;
    self.revertChangesButton.enabled = YES;
}



#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    
    // MODELS TABLE
    if (tableView == self.modelsTableView) {
        return self.models.count;
    }
    
    // SCREENERS TABLE
    if (tableView == self.screenersTableView) {
        return self.editingModel ? self.editingModel.steps.count : 0;
    }
    
    // PARAMETERS TABLE
    if (tableView == self.parametersTableView) {
        return self.selectedStep ? self.selectedStep.parameters.count : 0;
    }
    
   
    // ARCHIVE SYMBOLS TABLE
       if (tableView == self.archiveSymbolsTableView) {
           if (self.selectedModelResult) {
               // Se è selezionato un modello, mostra solo i suoi simboli
               return self.selectedModelResult.screenedSymbols.count;
           } else if (self.selectedSession) {
               // Se è selezionata una sessione, conta tutti i simboli di tutti i modelli
               NSInteger totalSymbols = 0;
               for (ModelResult *result in self.selectedSession.modelResults) {
                   totalSymbols += result.screenedSymbols.count;
               }
               return totalSymbols;
           }
           return 0;
       }
            
          
    return 0;
}
- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.editable = NO;
    textField.bordered = NO;
    textField.backgroundColor = [NSColor clearColor];
    
    // MODELS TABLE
    if (tableView == self.modelsTableView) {
        ScreenerModel *model = self.models[row];
        
        if ([tableColumn.identifier isEqualToString:@"enabled"]) {
            textField.stringValue = model.isEnabled ? @"✓" : @"";
        } else if ([tableColumn.identifier isEqualToString:@"name"]) {
            textField.stringValue = model.displayName;
        } else if ([tableColumn.identifier isEqualToString:@"steps"]) {
            textField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)model.steps.count];
        }
    }
    
    // SCREENERS TABLE
    else if (tableView == self.screenersTableView) {
        ScreenerStep *step = self.editingModel.steps[row];
        
        if ([tableColumn.identifier isEqualToString:@"step"]) {
            textField.stringValue = [NSString stringWithFormat:@"%ld", (long)(row + 1)];
            textField.alignment = NSTextAlignmentCenter;
        } else if ([tableColumn.identifier isEqualToString:@"screener"]) {
            BaseScreener *screener = [[ScreenerRegistry sharedRegistry] screenerWithID:step.screenerID];
            textField.stringValue = screener ? screener.displayName : step.screenerID;
        } else if ([tableColumn.identifier isEqualToString:@"input"]) {
            textField.stringValue = [step.inputSource isEqualToString:@"universe"] ? @"Universe" : @"Previous";
            textField.textColor = [step.inputSource isEqualToString:@"universe"] ? [NSColor systemBlueColor] : [NSColor systemGrayColor];
        }
    }
    
    // PARAMETERS TABLE
    else if (tableView == self.parametersTableView) {
        NSArray *keys = [self.selectedStep.parameters.allKeys sortedArrayUsingSelector:@selector(compare:)];
        NSString *key = keys[row];
        id value = self.selectedStep.parameters[key];
        
        if ([tableColumn.identifier isEqualToString:@"param_name"]) {
            textField.stringValue = key;
        } else if ([tableColumn.identifier isEqualToString:@"param_value"]) {
            textField.stringValue = [NSString stringWithFormat:@"%@", value];
            textField.editable = YES;
            textField.bordered = YES;
            textField.backgroundColor = [NSColor controlBackgroundColor];
            textField.target = self;
            textField.action = @selector(parameterValueChanged:);
            textField.tag = row;
        }
    }
    
    
    
    // ARCHIVE SYMBOLS TABLE
    else if (tableView == self.archiveSymbolsTableView) {
        ScreenedSymbol *symbol = nil;
        
        if (self.selectedModelResult) {
            // Simboli del modello selezionato
            if (row < self.selectedModelResult.screenedSymbols.count) {
                symbol = self.selectedModelResult.screenedSymbols[row];
            }
        } else if (self.selectedSession) {
            // Simboli di tutti i modelli della sessione
            NSInteger currentIndex = 0;
            for (ModelResult *result in self.selectedSession.modelResults) {
                if (row < currentIndex + result.screenedSymbols.count) {
                    symbol = result.screenedSymbols[row - currentIndex];
                    break;
                }
                currentIndex += result.screenedSymbols.count;
            }
        }
        
        if (!symbol) {
            NSTextField *textField = [[NSTextField alloc] init];
            textField.editable = NO;
            textField.bordered = NO;
            textField.backgroundColor = [NSColor clearColor];
            return textField;
        }
        
        // ✅ NUOVA GESTIONE: Checkbox per colonna "archive_select"
        if ([tableColumn.identifier isEqualToString:@"archive_select"]) {
            NSButton *checkbox = [[NSButton alloc] init];
            checkbox.buttonType = NSButtonTypeSwitch;
            checkbox.title = @"";
            checkbox.target = self;
            checkbox.action = @selector(archiveSymbolCheckboxChanged:);
            checkbox.tag = row;  // Salva row per identificare il simbolo
            checkbox.state = symbol.isSelected ? NSControlStateValueOn : NSControlStateValueOff;
            return checkbox;
        }
        
        // Gestione delle altre colonne (codice esistente)
        NSTextField *textField = [[NSTextField alloc] init];
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        
        if ([tableColumn.identifier isEqualToString:@"archive_symbol"]) {
            textField.stringValue = symbol.symbol;
            
        } else if ([tableColumn.identifier isEqualToString:@"signal_price"]) {
            if (symbol.metadata[@"signalPrice"]) {
                textField.stringValue = [NSString stringWithFormat:@"%.2f",
                    [symbol.metadata[@"signalPrice"] doubleValue]];
            } else {
                textField.stringValue = @"--";
            }
            
        } else if ([tableColumn.identifier isEqualToString:@"current_price"]) {
            if (symbol.metadata[@"currentPrice"]) {
                textField.stringValue = [NSString stringWithFormat:@"%.2f",
                                         [symbol.metadata[@"currentPrice"] doubleValue]];
            } else {
                textField.stringValue = @"--";
            }
            
        } else if ([tableColumn.identifier isEqualToString:@"var_percent"]) {
            if (symbol.metadata[@"changePercent"]) {
                double changePercent = [symbol.metadata[@"changePercent"] doubleValue];
                textField.stringValue = [NSString stringWithFormat:@"%.2f%%", changePercent];
                textField.textColor = (changePercent >= 0) ?
                    [NSColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0] :
                    [NSColor colorWithRed:0.9 green:0.0 blue:0.0 alpha:1.0];
            } else {
                textField.stringValue = @"--";
            }
        }
        
        return textField;
    }
    return textField;
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (outlineView != self.archiveOutlineView) return 0;
    
    if (item == nil) {
        // Root level: numero di sessioni
        return self.archivedSessions.count;
    }
    
    if ([item isKindOfClass:[ExecutionSession class]]) {
        // Session level: numero di modelli
        ExecutionSession *session = (ExecutionSession *)item;
        return session.modelResults.count;
    }
    
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (outlineView != self.archiveOutlineView) return nil;
    
    if (item == nil) {
        // Root level: ritorna session
        return self.archivedSessions[index];
    }
    
    if ([item isKindOfClass:[ExecutionSession class]]) {
        // Session level: ritorna model result
        ExecutionSession *session = (ExecutionSession *)item;
        return session.modelResults[index];
    }
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if (outlineView != self.archiveOutlineView) return NO;
    
    // Solo le sessioni sono espandibili
    return [item isKindOfClass:[ExecutionSession class]];
}


// 4️⃣ IMPLEMENTARE NSOutlineViewDelegate

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item {
    
    if (outlineView != self.archiveOutlineView) return nil;
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.editable = NO;
    textField.bordered = NO;
    textField.backgroundColor = [NSColor clearColor];
    
    // SESSION ROW (parent)
    if ([item isKindOfClass:[ExecutionSession class]]) {
        ExecutionSession *session = (ExecutionSession *)item;
        
        if ([tableColumn.identifier isEqualToString:@"name"]) {
            textField.stringValue = [session formattedExecutionDate];
            textField.font = [NSFont boldSystemFontOfSize:12];
            
        } else if ([tableColumn.identifier isEqualToString:@"count"]) {
            textField.stringValue = [NSString stringWithFormat:@"%ld", (long)session.totalSymbols];
            textField.alignment = NSTextAlignmentCenter;
            textField.textColor = [NSColor secondaryLabelColor];
            
        } else if ([tableColumn.identifier isEqualToString:@"time"]) {
            textField.stringValue = @"";
        }
    }
    
    // MODEL ROW (child)
    else if ([item isKindOfClass:[ModelResult class]]) {
        ModelResult *result = (ModelResult *)item;
        
        if ([tableColumn.identifier isEqualToString:@"name"]) {
            textField.stringValue = result.modelName;
            textField.font = [NSFont systemFontOfSize:11];
            
        } else if ([tableColumn.identifier isEqualToString:@"count"]) {
            textField.stringValue = [NSString stringWithFormat:@"%lu",
                                     (unsigned long)result.screenedSymbols.count];
            textField.alignment = NSTextAlignmentCenter;
            textField.font = [NSFont systemFontOfSize:11];
            
        } else if ([tableColumn.identifier isEqualToString:@"time"]) {
            textField.stringValue = [NSString stringWithFormat:@"%.1fs", result.totalExecutionTime];
            textField.alignment = NSTextAlignmentCenter;
            textField.font = [NSFont systemFontOfSize:11];
            textField.textColor = [NSColor secondaryLabelColor];
        }
    }
    
    return textField;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSOutlineView *outlineView = notification.object;
    
    if (outlineView != self.archiveOutlineView) return;
    
    NSInteger selectedRow = [self.archiveOutlineView selectedRow];
    
    if (selectedRow < 0) {
        self.selectedSession = nil;
        self.selectedModelResult = nil;
        self.deleteArchiveButton.enabled = NO;
        self.exportArchiveButton.enabled = NO;
        self.sendSelectedButton.enabled = NO;
        self.sendAllButton.enabled = NO;
        self.archiveHeaderLabel.stringValue = @"Select a session or model";
        [self.archiveSymbolsTableView reloadData];
        
        self.statsAllLabel.stringValue = @"All: --";
        self.statsSelectedLabel.stringValue = @"Selected: --";
        return;
    }
    
    id selectedItem = [outlineView itemAtRow:selectedRow];
    
    // SESSION SELECTED
    if ([selectedItem isKindOfClass:[ExecutionSession class]]) {
        self.selectedSession = (ExecutionSession *)selectedItem;
        self.selectedModelResult = nil;
        
        self.deleteArchiveButton.enabled = YES;
        self.exportArchiveButton.enabled = YES;
        self.sendSelectedButton.enabled = NO;  // Abilitato dopo aver selezionato simboli
        self.generateReportButton.enabled = YES;     // ✅ NUOVO
          self.compactReportButton.enabled = YES;      // ✅ NUOVO
        self.sendAllButton.enabled = YES;
        
        self.archiveHeaderLabel.stringValue = [NSString stringWithFormat:
            @"Session: %@ (%ld symbols)",
            [self.selectedSession formattedExecutionDate],
            (long)self.selectedSession.totalSymbols];
        
        [self updateCurrentPricesForSession:self.selectedSession];
    }
    // MODEL SELECTED
    else if ([selectedItem isKindOfClass:[ModelResult class]]) {
        self.selectedModelResult = (ModelResult *)selectedItem;
        
        id parentItem = [outlineView parentForItem:selectedItem];
        if ([parentItem isKindOfClass:[ExecutionSession class]]) {
            self.selectedSession = (ExecutionSession *)parentItem;
        }
        
        self.deleteArchiveButton.enabled = YES;
        self.exportArchiveButton.enabled = YES;
        self.generateReportButton.enabled = YES;     // ✅ NUOVO
           self.compactReportButton.enabled = YES;      // ✅ NUOVO
        self.sendSelectedButton.enabled = NO;  // Abilitato dopo aver selezionato simboli
        self.sendAllButton.enabled = YES;
        
        self.archiveHeaderLabel.stringValue = [NSString stringWithFormat:
            @"Model: %@ (%lu symbols)",
            self.selectedModelResult.modelName,
            (unsigned long)self.selectedModelResult.screenedSymbols.count];
        
        [self updateCurrentPricesForModelResult:self.selectedModelResult];
    }
    
    [self.archiveSymbolsTableView reloadData];
    [self updateArchiveStatistics];
}

- (void)updateCurrentPricesForSession:(ExecutionSession *)session {
    NSLog(@"💰 Updating current prices for session...");
    
    // Raccogli tutti i simboli unici dalla sessione
    NSMutableSet *uniqueSymbols = [NSMutableSet set];
    for (ModelResult *result in session.modelResults) {
        for (ScreenedSymbol *symbol in result.screenedSymbols) {
            [uniqueSymbols addObject:symbol.symbol];
        }
    }
    
    // Aggiorna i prezzi per ogni simbolo
    for (NSString *symbolString in uniqueSymbols) {
        [self fetchAndUpdateCurrentPriceForSymbol:symbolString inSession:session];
    }
}

- (void)updateCurrentPricesForModelResult:(ModelResult *)modelResult {
    NSLog(@"💰 Updating current prices for model: %@", modelResult.modelName);
    
    for (ScreenedSymbol *symbol in modelResult.screenedSymbols) {
        [self fetchAndUpdateCurrentPriceForSymbol:symbol.symbol inModelResult:modelResult];
    }
}

- (void)fetchAndUpdateCurrentPriceForSymbol:(NSString *)symbolString
                                  inSession:(ExecutionSession *)session {
    // Recupera il prezzo corrente da DataHub
    [[DataHub shared] getQuoteForSymbol:symbolString completion:^(MarketQuoteModel *quote, BOOL isLive) {
        if (quote && quote.last) {
            double currentPrice = [quote.last doubleValue];
            
            // Aggiorna il metadata per tutti i ScreenedSymbol con questo simbolo
            for (ModelResult *result in session.modelResults) {
                for (ScreenedSymbol *symbol in result.screenedSymbols) {
                    if ([symbol.symbol isEqualToString:symbolString]) {
                        [symbol setMetadataValue:@(currentPrice) forKey:@"currentPrice"];
                        
                        // Calcola la variazione percentuale se esiste signalPrice
                        NSNumber *signalPrice = [symbol metadataValueForKey:@"signalPrice"];
                        if (signalPrice) {
                            double signal = [signalPrice doubleValue];
                            if (signal > 0) {
                                double changePercent = ((currentPrice - signal) / signal) * 100.0;
                                [symbol setMetadataValue:@(changePercent) forKey:@"changePercent"];
                            }
                        }
                    }
                }
            }
            
            // Ricarica la tabella
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateArchiveStatistics];
                [self.archiveSymbolsTableView reloadData];
            });
            
            NSLog(@"💰 Updated %@: Current = $%.2f", symbolString, currentPrice);
        }
    }];
}

- (void)fetchAndUpdateCurrentPriceForSymbol:(NSString *)symbolString
                              inModelResult:(ModelResult *)modelResult {
    [[DataHub shared] getQuoteForSymbol:symbolString completion:^(MarketQuoteModel *quote, BOOL isLive) {
        if (quote && quote.last) {
            double currentPrice = [quote.last doubleValue];
            
            // Aggiorna il metadata per il ScreenedSymbol
            for (ScreenedSymbol *symbol in modelResult.screenedSymbols) {
                if ([symbol.symbol isEqualToString:symbolString]) {
                    [symbol setMetadataValue:@(currentPrice) forKey:@"currentPrice"];
                    
                    // Calcola la variazione percentuale
                    NSNumber *signalPrice = [symbol metadataValueForKey:@"signalPrice"];
                    if (signalPrice) {
                        double signal = [signalPrice doubleValue];
                        if (signal > 0) {
                            double changePercent = ((currentPrice - signal) / signal) * 100.0;
                            [symbol setMetadataValue:@(changePercent) forKey:@"changePercent"];
                        }
                    }
                }
            }
            
            // Ricarica la tabella
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateArchiveStatistics];
                [self.archiveSymbolsTableView reloadData];
            });
        }
    }];
}



#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = notification.object;
    
    // MODELS TABLE
    if (tableView == self.modelsTableView) {
        NSInteger selectedRow = [self.modelsTableView selectedRow];
        BOOL hasSelection = selectedRow >= 0;
        
        self.duplicateModelButton.enabled = hasSelection;
        self.deleteModelButton.enabled = hasSelection;
        self.runButton.enabled = hasSelection;
        
        if (hasSelection) {
            ScreenerModel *model = self.models[selectedRow];
            [self loadModelIntoEditor:model];
        } else {
            [self clearEditor];
        }
    }
    
    // SCREENERS TABLE
    else if (tableView == self.screenersTableView) {
        NSInteger selectedRow = [self.screenersTableView selectedRow];
        
        if (selectedRow >= 0 && self.editingModel) {
            self.selectedStep = self.editingModel.steps[selectedRow];
            self.removeScreenerButton.enabled = YES;
            [self.parametersTableView reloadData];
            NSLog(@"📝 Selected step: %@", self.selectedStep.screenerID);
        } else {
            self.selectedStep = nil;
            self.removeScreenerButton.enabled = NO;
            [self.parametersTableView reloadData];
        }
    }
    
    // ✅ ARCHIVE SYMBOLS TABLE - MODIFICATO PER USARE CACHE
    else if (tableView == self.archiveSymbolsTableView) {
        NSInteger selectedRow = self.archiveSymbolsTableView.selectedRow;
        
        if (selectedRow >= 0 && self.chainActive) {
            ScreenedSymbol *symbol = nil;
            
            if (self.selectedModelResult) {
                // Simboli del modello selezionato
                if (selectedRow < self.selectedModelResult.screenedSymbols.count) {
                    symbol = self.selectedModelResult.screenedSymbols[selectedRow];
                }
            } else if (self.selectedSession) {
                // Simboli di tutti i modelli della sessione
                NSInteger currentIndex = 0;
                for (ModelResult *result in self.selectedSession.modelResults) {
                    if (selectedRow < currentIndex + result.screenedSymbols.count) {
                        symbol = result.screenedSymbols[selectedRow - currentIndex];
                        break;
                    }
                    currentIndex += result.screenedSymbols.count;
                }
            }
            
            if (symbol) {
                // ✅ INVIO CON DATI STORICI (usa cache se disponibile)
                [self sendSingleSymbolWithData:symbol.symbol];
                [self showChainFeedback:[NSString stringWithFormat:@"📊 Sent %@ with data", symbol.symbol]];
                NSLog(@"🔗 Sent archive symbol WITH DATA to chain: %@", symbol.symbol);
            }
        }
    }
}
- (void)sendSelectedSymbols:(id)sender {
    NSArray<ScreenedSymbol *> *selectedSymbols = [self getSelectedArchiveSymbols];
    
    if (selectedSymbols.count == 0) {
        NSLog(@"⚠️ No symbols selected");
        return;
    }
    
    NSMutableArray<NSString *> *symbolNames = [NSMutableArray array];
    for (ScreenedSymbol *symbol in selectedSymbols) {
        [symbolNames addObject:symbol.symbol];
    }
    
    NSLog(@"📤 Sending %ld selected symbols with historical data...", (long)symbolNames.count);
    [self loadHistoricalDataAndSendToChain:symbolNames];
}

- (void)sendAllSymbols:(id)sender {
    NSArray<ScreenedSymbol *> *allSymbols = [self getAllArchiveSymbols];
    
    if (allSymbols.count == 0) {
        NSLog(@"⚠️ No symbols available");
        return;
    }
    
    NSMutableArray<NSString *> *symbolNames = [NSMutableArray array];
    for (ScreenedSymbol *symbol in allSymbols) {
        [symbolNames addObject:symbol.symbol];
    }
    
    NSLog(@"📤 Sending %ld symbols with historical data...", (long)symbolNames.count);
    [self loadHistoricalDataAndSendToChain:symbolNames];
}



- (void)updateSymbolSelectionButtons {
    NSInteger selectedCount = 0;
    for (ScreenedSymbol *symbol in self.currentModelSymbols) {
        if (symbol.isSelected) selectedCount++;
    }
    
    self.sendSelectedButton.enabled = (selectedCount > 0);
    
    if (selectedCount > 0) {
        self.sendSelectedButton.title = [NSString stringWithFormat:@"Send Selected (%ld)",
                                         (long)selectedCount];
    } else {
        self.sendSelectedButton.title = @"Send Selected";
    }
}

- (void)selectAllSymbols:(BOOL)selected {
    for (ScreenedSymbol *symbol in self.currentModelSymbols) {
        symbol.isSelected = selected;
    }
    [self updateSymbolSelectionButtons];
}


#pragma mark - Actions - Parameter Editing

- (void)parameterValueChanged:(NSTextField *)textField {
    if (!self.selectedStep) return;
    
    NSInteger row = textField.tag;
    NSArray *keys = [self.selectedStep.parameters.allKeys sortedArrayUsingSelector:@selector(compare:)];
    
    if (row < 0 || row >= keys.count) return;
    
    NSString *key = keys[row];
    NSString *newValue = textField.stringValue;
    
    // Parse value (try number, then bool, then string)
    id parsedValue = [self parameterValueFromString:newValue];
    
    // Update parameter
    NSMutableDictionary *params = [self.selectedStep.parameters mutableCopy];
    params[key] = parsedValue;
    self.selectedStep.parameters = params;
    
    [self markAsModified];
    
    NSLog(@"✏️ Parameter changed: %@ = %@", key, parsedValue);
}

- (id)parameterValueFromString:(NSString *)string {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *number = [formatter numberFromString:string];
    
    if (number) {
        if ([string rangeOfString:@"."].location == NSNotFound) {
            return @([number integerValue]);
        }
        return @([number doubleValue]);
    }
    
    if ([string.lowercaseString isEqualToString:@"true"] || [string.lowercaseString isEqualToString:@"yes"]) {
        return @YES;
    }
    if ([string.lowercaseString isEqualToString:@"false"] || [string.lowercaseString isEqualToString:@"no"]) {
        return @NO;
    }
    
    return string;
}

#pragma mark - Actions - Screeners

- (void)addScreener:(id)sender {
    if (!self.editingModel) return;
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    NSArray<BaseScreener *> *screeners = [[ScreenerRegistry sharedRegistry] allScreeners];
    for (BaseScreener *screener in screeners) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:screener.displayName
                                                       action:@selector(addScreenerFromMenu:)
                                                keyEquivalent:@""];
        item.target = self;
        item.representedObject = screener.screenerID;
        [menu addItem:item];
    }
    
    NSPoint location = NSMakePoint(0, self.addScreenerButton.bounds.size.height);
    [menu popUpMenuPositioningItem:nil atLocation:location inView:self.addScreenerButton];
}

- (void)addScreenerFromMenu:(NSMenuItem *)menuItem {
    NSString *screenerID = menuItem.representedObject;
    
    BaseScreener *screener = [[ScreenerRegistry sharedRegistry] screenerWithID:screenerID];
    NSDictionary *defaultParams = screener ? [screener defaultParameters] : @{};
    
    ScreenerStep *newStep = [ScreenerStep stepWithScreenerID:screenerID
                                                 inputSource:@"previous"
                                                  parameters:defaultParams];
    
    NSMutableArray *steps = [self.editingModel.steps mutableCopy];
    [steps addObject:newStep];
    self.editingModel.steps = steps;
    
    [self.screenersTableView reloadData];
    [self markAsModified];
    
    NSLog(@"➕ Added screener: %@ with %lu parameters", screenerID, (unsigned long)defaultParams.count);
}

- (void)removeScreener:(id)sender {
    NSInteger selectedRow = [self.screenersTableView selectedRow];
    if (selectedRow < 0 || !self.editingModel) return;
    
    ScreenerStep *step = self.editingModel.steps[selectedRow];
    
    NSMutableArray *steps = [self.editingModel.steps mutableCopy];
    [steps removeObject:step];
    self.editingModel.steps = steps;
    
    self.selectedStep = nil;
    
    [self.screenersTableView reloadData];
    [self.parametersTableView reloadData];
    [self markAsModified];
    
    NSLog(@"➖ Removed screener");
}

#pragma mark - Actions - Model Management

- (void)saveModelChanges:(id)sender {
    if (!self.editingModel || !self.selectedModel) return;
    
    self.editingModel.displayName = self.modelNameField.stringValue;
    self.editingModel.modelDescription = self.modelDescriptionField.stringValue;
    
    NSError *error;
    BOOL success = [self.modelManager saveModel:self.editingModel error:&error];
    
    if (success) {
        NSLog(@"✅ Model saved: %@", self.editingModel.displayName);
        
        [self refreshModels];
        
        self.hasUnsavedChanges = NO;
        self.saveChangesButton.enabled = NO;
        self.revertChangesButton.enabled = NO;
        
        NSAlert *alert = [[NSAlert alloc] init];
        if (self.editingModel.steps.count == 0) {
            alert.messageText = @"Model Saved (Empty)";
            alert.informativeText = [NSString stringWithFormat:@"'%@' has been saved.\n\n⚠️ This model has no screener steps yet. Add at least one screener before running.", self.editingModel.displayName];
            alert.alertStyle = NSAlertStyleWarning;
        } else {
            alert.messageText = @"Model Saved";
            alert.informativeText = [NSString stringWithFormat:@"'%@' has been saved with %lu step(s).",
                                    self.editingModel.displayName,
                                    (unsigned long)self.editingModel.steps.count];
            alert.alertStyle = NSAlertStyleInformational;
        }
        [alert runModal];
        
    } else {
        NSLog(@"❌ Failed to save: %@", error.localizedDescription);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Save Failed";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleCritical;
        [alert runModal];
    }
}

- (void)revertModelChanges:(id)sender {
    if (!self.selectedModel) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Revert Changes";
    alert.informativeText = @"Discard all unsaved changes?";
    [alert addButtonWithTitle:@"Revert"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [self loadModelIntoEditor:self.selectedModel];
        NSLog(@"↩️  Reverted");
    }
}

- (void)createNewModel:(id)sender {
    ScreenerModel *newModel = [ScreenerModel modelWithID:[NSUUID UUID].UUIDString
                                             displayName:@"New Model"
                                                   steps:@[]];
    
    NSError *error;
    BOOL success = [self.modelManager saveModel:newModel error:&error];
    
    if (success) {
        [self refreshModels];
        
        NSInteger index = [self.models indexOfObject:newModel];
        if (index != NSNotFound) {
            [self.modelsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
        }
        
        NSLog(@"✅ Created new model");
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Failed to Create Model";
        alert.informativeText = error.localizedDescription;
        [alert runModal];
    }
}

- (void)duplicateModel:(id)sender {
    NSInteger selectedRow = [self.modelsTableView selectedRow];
    if (selectedRow < 0) return;
    
    ScreenerModel *original = self.models[selectedRow];
    
    NSDictionary *dict = [original toDictionary];
    ScreenerModel *duplicate = [ScreenerModel fromDictionary:dict];
    duplicate.modelID = [NSUUID UUID].UUIDString;
    duplicate.displayName = [NSString stringWithFormat:@"%@ (Copy)", original.displayName];
    
    NSError *error;
    BOOL success = [self.modelManager saveModel:duplicate error:&error];
    
    if (success) {
        [self refreshModels];
        NSLog(@"✅ Duplicated model");
    }
}

- (void)deleteModel:(id)sender {
    NSInteger selectedRow = [self.modelsTableView selectedRow];
    if (selectedRow < 0) return;
    
    ScreenerModel *model = self.models[selectedRow];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Model";
    alert.informativeText = [NSString stringWithFormat:@"Delete '%@'?", model.displayName];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSError *error;
        [self.modelManager deleteModel:model.modelID error:&error];
        [self refreshModels];
        [self clearEditor];
    }
}

#pragma mark - Actions - Execution

- (void)runSelectedModels {
    if (!self.dataManager) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Data Directory";
        alert.informativeText = @"Please set the Stooq data directory in Settings tab";
        [alert runModal];
        return;
    }
    
    NSIndexSet *selectedRows = [self.modelsTableView selectedRowIndexes];
    if (selectedRows.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Models Selected";
        alert.informativeText = @"Please select one or more models to run";
        [alert runModal];
        return;
    }
    
    NSMutableArray *selectedModels = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [selectedModels addObject:self.models[idx]];
    }];
    
    NSLog(@"🚀 Running %lu models", (unsigned long)selectedModels.count);
    
    self.progressIndicator.hidden = NO;
    self.progressIndicator.doubleValue = 0.0;
    self.runButton.enabled = NO;
    
    [self.batchRunner executeModels:selectedModels
                           universe:nil
                         completion:^(NSDictionary<NSString *,ModelResult *> *results, NSError *error) {
        
        if (error) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Execution Failed";
            alert.informativeText = error.localizedDescription;
            [alert runModal];
        }
        
        self.progressIndicator.hidden = YES;
        self.runButton.enabled = YES;
    }];
}

- (void)cancelExecution {
    [self.batchRunner cancel];
}

#pragma mark - Actions - Settings

- (void)browseDataDirectory:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.allowsMultipleSelection = NO;
    panel.prompt = @"Select Stooq Data Directory";
    
    if ([panel runModal] == NSModalResponseOK) {
        NSString *path = panel.URL.path;
        self.dataPathField.stringValue = path;
        [self setDataDirectory:path];
    }
}

- (void)scanDatabase:(id)sender {
    if (!self.dataManager) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Data Directory";
        alert.informativeText = @"Please select a data directory first";
        [alert runModal];
        return;
    }
    
    self.scanDatabaseButton.enabled = NO;
    self.symbolCountLabel.stringValue = @"Scanning...";
    
    [self.dataManager scanDatabaseWithCompletion:^(NSArray<NSString *> *symbols, NSError *error) {
        if (error) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Scan Failed";
            alert.informativeText = error.localizedDescription;
            [alert runModal];
            self.symbolCountLabel.stringValue = @"Symbols: Error";
        } else {
            self.availableSymbols = symbols;
            self.symbolCountLabel.stringValue = [NSString stringWithFormat:@"Symbols: %lu", (unsigned long)symbols.count];
            self.universeLabel.stringValue = [NSString stringWithFormat:@"Universe: %lu symbols", (unsigned long)symbols.count];
        }
        
        self.scanDatabaseButton.enabled = YES;
    }];
}

- (void)exportResults:(id)sender {
    NSLog(@"TODO: Export results");
}



#pragma mark - ScreenerBatchRunnerDelegate

- (void)batchRunnerDidStart:(ScreenerBatchRunner *)runner {
    self.resultsStatusLabel.stringValue = @"Starting...";
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didStartLoadingDataForSymbols:(NSInteger)symbolCount {
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Loading %ld symbols...", (long)symbolCount];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishLoadingData:(NSDictionary *)cache {
    self.lastScreeningCache = cache;
      self.lastScreeningDate = self.dataManager.targetDate;
    
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Data loaded: %lu symbols", (unsigned long)cache.count];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didStartModel:(ScreenerModel *)model {
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Executing: %@", model.displayName];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishModel:(ModelResult *)result {
    self.executionResults[result.modelID] = result;
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Completed: %@ (%lu symbols)",
                                            result.modelName,
                                            (unsigned long)result.screenedSymbols.count];

}

- (void)batchRunner:(ScreenerBatchRunner *)runner
  didFinishWithResults:(NSDictionary<NSString *, ModelResult *> *)results {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressIndicator stopAnimation:nil];
        
        self.executionResults = [results mutableCopy];
        
        NSLog(@"Batch execution complete: %lu models", (unsigned long)results.count);
        
        // Salva nell'archivio
        [self saveCurrentResultsToArchive];
        
        // ✅ SWITCH AL TAB RESULTS (ex-Archive, ora è il secondo tab)
        [self.tabView selectTabViewItemAtIndex:1];
        
        // ✅ SELEZIONA AUTOMATICAMENTE L'ULTIMA SESSIONE (la più recente)
        if (self.archivedSessions.count > 0) {
            [self.archiveOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                                  byExtendingSelection:NO];
            
            // Espandi automaticamente per mostrare i modelli
            [self.archiveOutlineView expandItem:self.archivedSessions.firstObject];
        }
    });
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFailWithError:(NSError *)error {
    self.resultsStatusLabel.stringValue = @"Failed";
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Execution Failed";
    alert.informativeText = error.localizedDescription;
    [alert runModal];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didUpdateProgress:(double)progress {
    self.progressIndicator.doubleValue = progress;
}


- (NSArray<NSString *> *)selectedSymbols {
    NSMutableArray *selected = [NSMutableArray array];
    
    for (ScreenedSymbol *screenedSymbol in self.currentModelSymbols) {
        if (screenedSymbol.isSelected) {
            [selected addObject:screenedSymbol.symbol];
        }
    }
    
    return [selected copy];
}

- (NSArray<NSString *> *)contextualSymbols {
    if (!self.currentModelSymbols) return @[];
    
    NSMutableArray *symbols = [NSMutableArray array];
    for (ScreenedSymbol *screenedSymbol in self.currentModelSymbols) {
        [symbols addObject:screenedSymbol.symbol];
    }
    return [symbols copy];
}

- (NSString *)contextMenuTitle {
    NSArray<NSString *> *selected = [self selectedSymbols];
    
    if (selected.count == 1) {
        return selected[0];
    } else if (selected.count > 1) {
        return [NSString stringWithFormat:@"Selection (%lu)", (unsigned long)selected.count];
    }
    
    return @"Stooq Screener";
}





#pragma mark - Symbol Selection

- (void)archiveSymbolCheckboxChanged:(NSButton *)sender {
    NSInteger row = sender.tag;
    
    ScreenedSymbol *symbol = nil;
    if (self.selectedModelResult) {
        if (row < self.selectedModelResult.screenedSymbols.count) {
            symbol = self.selectedModelResult.screenedSymbols[row];
        }
    } else if (self.selectedSession) {
        NSInteger currentIndex = 0;
        for (ModelResult *result in self.selectedSession.modelResults) {
            if (row < currentIndex + result.screenedSymbols.count) {
                symbol = result.screenedSymbols[row - currentIndex];
                break;
            }
            currentIndex += result.screenedSymbols.count;
        }
    }
    
    if (symbol) {
        symbol.isSelected = (sender.state == NSControlStateValueOn);
        
        // Aggiorna statistiche
        [self updateArchiveStatistics];
        
        // ✅ NUOVO: Abilita/disabilita bottone Send Selected
        NSArray<ScreenedSymbol *> *selected = [self getSelectedArchiveSymbols];
        self.sendSelectedButton.enabled = (selected.count > 0);
    }
}
- (void)symbolCheckboxToggled:(NSButton *)sender {
    NSInteger row = sender.tag;
    
    if (row < 0 || row >= self.currentModelSymbols.count) {
        return;
    }
    
    ScreenedSymbol *screenedSymbol = self.currentModelSymbols[row];
    screenedSymbol.isSelected = (sender.state == NSControlStateValueOn);
    
    NSLog(@"%@ symbol: %@",
          screenedSymbol.isSelected ? @"✅ Selected" : @"❌ Deselected",
          screenedSymbol.symbol);
    
    [self updateSymbolSelectionButtons];
}




- (void)saveReportToURL:(NSURL *)url
     withSelectedSymbols:(NSDictionary<NSString *, NSArray<ScreenedSymbol *> *> *)selectedByModel
       includeAllSymbols:(BOOL)includeAll
      includeParameters:(BOOL)includeParams {
    
    NSMutableString *report = [NSMutableString string];
    
    // Header
    [report appendString:@"           SCREENER EXECUTION REPORT\n"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"EEEE, MMMM d, yyyy 'at' HH:mm:ss";
    [report appendFormat:@"Generated: %@\n", [dateFormatter stringFromDate:[NSDate date]]];
    [report appendFormat:@"Mode: %@\n", includeAll ? @"All Symbols" : @"Selected Symbols Only"];
    
    // Calcola statistiche
    NSInteger totalModels = includeAll ? self.executionResults.count : selectedByModel.count;
    NSInteger totalSymbols = 0;
    NSMutableSet<NSString *> *uniqueSymbols = [NSMutableSet set];
    
    if (includeAll) {
        // Conta tutti i simboli
        for (ModelResult *result in self.executionResults.allValues) {
            totalSymbols += result.screenedSymbols.count;
            for (ScreenedSymbol *symbol in result.screenedSymbols) {
                [uniqueSymbols addObject:symbol.symbol];
            }
        }
    } else {
        // Conta solo selezionati
        for (NSArray<ScreenedSymbol *> *symbols in selectedByModel.allValues) {
            totalSymbols += symbols.count;
            for (ScreenedSymbol *symbol in symbols) {
                [uniqueSymbols addObject:symbol.symbol];
            }
        }
    }
    
    [report appendFormat:@"Models: %ld\n", (long)totalModels];
    [report appendFormat:@"Total symbols: %ld\n", (long)totalSymbols];
    [report appendFormat:@"Unique symbols: %ld\n\n", (long)uniqueSymbols.count];
    [report appendString:@"────────────────────────────────\n\n"];
    
    // Determina quali modelli processare
    NSArray<NSString *> *modelIDsToProcess;
    
    if (includeAll) {
        modelIDsToProcess = [self.executionResults.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *id1, NSString *id2) {
            ModelResult *r1 = self.executionResults[id1];
            ModelResult *r2 = self.executionResults[id2];
            return [r1.modelName compare:r2.modelName];
        }];
    } else {
        modelIDsToProcess = [selectedByModel.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *id1, NSString *id2) {
            ModelResult *r1 = self.executionResults[id1];
            ModelResult *r2 = self.executionResults[id2];
            return [r1.modelName compare:r2.modelName];
        }];
    }
    
    // Per ogni modello
    NSInteger modelNumber = 1;
    for (NSString *modelID in modelIDsToProcess) {
        ModelResult *result = self.executionResults[modelID];
        
        // Determina quali simboli mostrare
        NSArray<ScreenedSymbol *> *symbolsToShow;
        if (includeAll) {
            symbolsToShow = result.screenedSymbols;
        } else {
            symbolsToShow = selectedByModel[modelID];
            if (!symbolsToShow || symbolsToShow.count == 0) continue;
        }
        
        [report appendFormat:@"%ld. MODEL: %@\n", (long)modelNumber++, result.modelName];
        
        if (result.modelDescription && result.modelDescription.length > 0) {
            [report appendFormat:@"   Description: %@\n", result.modelDescription];
        }
        
        [report appendFormat:@"   Execution Time: %.2fs\n", result.totalExecutionTime];
        [report appendFormat:@"   Total Symbols: %lu\n", (unsigned long)result.screenedSymbols.count];
        
        if (!includeAll) {
            [report appendFormat:@"   Selected Symbols: %lu\n", (unsigned long)symbolsToShow.count];
        }
        
        [report appendString:@"\n"];
        
        // Lista simboli
        [report appendFormat:@"   Symbols (%lu):\n", (unsigned long)symbolsToShow.count];
        NSArray *sortedSymbols = [symbolsToShow sortedArrayUsingComparator:^NSComparisonResult(ScreenedSymbol *s1, ScreenedSymbol *s2) {
            return [s1.symbol compare:s2.symbol];
        }];
        
        for (ScreenedSymbol *symbol in sortedSymbols) {
            NSString *marker = includeAll ? (symbol.isSelected ? @"✓" : @" ") : @"✓";
            [report appendFormat:@"      [%@] %@", marker, symbol.symbol];
            
            // Aggiungi metadata se disponibile
            if (symbol.metadata.count > 0) {
                NSMutableArray *metadataStrings = [NSMutableArray array];
                for (NSString *key in symbol.metadata.allKeys) {
                    [metadataStrings addObject:[NSString stringWithFormat:@"%@: %@", key, symbol.metadata[key]]];
                }
                [report appendFormat:@" (%@)", [metadataStrings componentsJoinedByString:@", "]];
            }
            
            [report appendString:@"\n"];
        }
        
        [report appendString:@"\n"];
        
        // ✅ Mostra parametri solo se richiesto
        if (includeParams && result.steps && result.steps.count > 0) {
            [report appendString:@"   Screening Steps:\n"];
            for (NSInteger i = 0; i < result.steps.count; i++) {
                ScreenerStep *step = result.steps[i];
                [report appendFormat:@"      Step %ld: %@", (long)(i + 1), step.screenerID];
                [report appendFormat:@" (Input: %@)\n",
                    [step.inputSource isEqualToString:@"universe"] ? @"Universe" : @"Previous"];
                
                if (step.parameters.count > 0) {
                    [report appendString:@"         Parameters:\n"];
                    NSArray *sortedKeys = [step.parameters.allKeys sortedArrayUsingSelector:@selector(compare:)];
                    for (NSString *key in sortedKeys) {
                        [report appendFormat:@"            %@ = %@\n", key, step.parameters[key]];
                    }
                }
            }
            [report appendString:@"\n"];
        }
        
        [report appendString:@"─────────────────────────────────────\n\n"];
    }
    
    // Footer con tutti i simboli unici
    [report appendString:@"           ALL UNIQUE SYMBOLS\n"];
    
    NSArray *sortedUniqueSymbols = [[uniqueSymbols allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    // Stampa in colonne (5 simboli per riga)
    NSInteger column = 0;
    for (NSString *symbol in sortedUniqueSymbols) {
        [report appendFormat:@"%-12s", [symbol UTF8String]];
        column++;
        if (column >= 5) {
            [report appendString:@"\n"];
            column = 0;
        }
    }
    
    if (column > 0) {
        [report appendString:@"\n"];
    }
    
    // Salva il file
    NSError *error;
    BOOL success = [report writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (success) {
        NSLog(@"✅ Report saved successfully to %@", url.path);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Report Generated";
        alert.informativeText = [NSString stringWithFormat:
            @"Report saved with:\n• %ld models\n• %ld symbols\n• %ld unique symbols\n• Mode: %@%@",
            (long)totalModels,
            (long)totalSymbols,
            (long)uniqueSymbols.count,
            includeAll ? @"All Symbols" : @"Selected Only",
            includeParams ? @"\n• Including parameters" : @""];
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"Open"];
        [alert addButtonWithTitle:@"OK"];
        
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
    } else {
        NSLog(@"❌ Error saving report: %@", error.localizedDescription);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Error Saving Report";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleCritical;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}
    


#pragma mark - Archive Management

- (void)loadArchivedSessions {
    NSString *archiveDir = [self archiveDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Verifica che la directory esista
    if (![fm fileExistsAtPath:archiveDir]) {
        NSLog(@"📦 Archive directory doesn't exist yet");
        return;
    }
    
    NSLog(@"📦 Loading archived sessions from: %@", archiveDir);
    
    NSError *error;
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:archiveDir error:&error];
    
    if (error) {
        NSLog(@"❌ Error reading archive directory: %@", error);
        return;
    }
    
    [self.archivedSessions removeAllObjects];
    
    NSInteger loadedCount = 0;
    NSInteger errorCount = 0;
    
    for (NSString *filename in files) {
        // Carica solo file JSON che iniziano con "session_"
        if (![filename hasPrefix:@"session_"] || ![filename hasSuffix:@".json"]) {
            continue;
        }
        
        NSString *filepath = [archiveDir stringByAppendingPathComponent:filename];
        
        NSError *loadError;
        ExecutionSession *session = [ExecutionSession loadFromFile:filepath error:&loadError];
        
        if (session) {
            [self.archivedSessions addObject:session];
            loadedCount++;
        } else {
            NSLog(@"⚠️ Failed to load session from %@: %@", filename, loadError);
            errorCount++;
        }
    }
    
    // Ordina per data (più recenti prima)
    [self.archivedSessions sortUsingComparator:^NSComparisonResult(ExecutionSession *s1, ExecutionSession *s2) {
        return [s2.executionDate compare:s1.executionDate];
    }];
    
    NSLog(@"✅ Loaded %ld archived sessions (%ld errors)", (long)loadedCount, (long)errorCount);
    
    // Ricarica la tabella dell'archivio
    [self.archiveOutlineView reloadData];  // ← CAMBIATO
}

- (void)saveCurrentResultsToArchive {
    if (self.executionResults.count == 0) {
        NSLog(@"⚠️ No results to archive");
        return;
    }
    
    NSLog(@"📦 Saving execution session to archive...");
    
    // ✅ FIX: Usa la targetDate dal dataManager (fonte di verità)
    NSDate *targetDate = self.dataManager.targetDate ?: [self.targetDatePicker dateValue];
    
    // Crea ExecutionSession CON LA DATA TARGET
    NSArray<ModelResult *> *results = [self.executionResults.allValues copy];
    ExecutionSession *session = [ExecutionSession sessionWithModelResults:results
                                                                 universe:self.availableSymbols
                                                                     date:targetDate];  // ✅ PASSA LA DATA
    
    NSLog(@"   🎯 Target date: %@",
          [NSDateFormatter localizedStringFromDate:targetDate
                                         dateStyle:NSDateFormatterMediumStyle
                                         timeStyle:NSDateFormatterNoStyle]);
    
    // Crea directory se non esiste
    NSString *archiveDir = [self archiveDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *dirError;
    
    if (![fm fileExistsAtPath:archiveDir]) {
        if (![fm createDirectoryAtPath:archiveDir
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&dirError]) {
            NSLog(@"❌ Failed to create archive directory: %@", dirError);
            return;
        }
    }
    
    // Genera nome file usando la TARGET DATE (non timestamp corrente)
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd_HHmmss";
    NSString *dateString = [dateFormatter stringFromDate:targetDate];  // ✅ USA TARGET DATE
    
    NSString *filename = [NSString stringWithFormat:@"session_%@_%@.json",
                         dateString,
                         [session.sessionID substringToIndex:8]];
    NSString *filepath = [archiveDir stringByAppendingPathComponent:filename];
    
    // Salva su file
    NSError *error;
    if ([session saveToFile:filepath error:&error]) {
        NSLog(@"✅ Saved execution session to archive:");
        NSLog(@"   📄 File: %@", filename);
        NSLog(@"   📊 %@", [session summaryString]);
        NSLog(@"   🎯 Target: %@",
              [NSDateFormatter localizedStringFromDate:targetDate
                                             dateStyle:NSDateFormatterShortStyle
                                             timeStyle:NSDateFormatterNoStyle]);
        NSLog(@"   💾 Path: %@", filepath);
        
        // ✅ Ricarica l'archivio
        [self loadArchivedSessions];
        
        // ✅ NUOVO: Mostra alert di conferma
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Results Archived Successfully";
        alert.informativeText = [NSString stringWithFormat:@"Saved %ld model results for %@\n\n%@",
                                (long)results.count,
                                [NSDateFormatter localizedStringFromDate:targetDate
                                                               dateStyle:NSDateFormatterMediumStyle
                                                               timeStyle:NSDateFormatterNoStyle],
                                [session summaryString]];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
    } else {
        NSLog(@"❌ Failed to save session: %@", error.localizedDescription);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Archive Save Failed";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}
- (NSString *)archiveDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString *appSupportDir = paths.firstObject;
    NSString *archiveDir = [appSupportDir stringByAppendingPathComponent:
                           @"TradingApp/ScreenerArchive"];
    return archiveDir;
}

#pragma mark - Archive Actions (COMPLETI PER OUTLINEVIEW)

- (void)deleteArchiveEntry:(id)sender {
    NSInteger selectedRow = [self.archiveOutlineView selectedRow];
    
    if (selectedRow < 0) {
        NSLog(@"⚠️ No selection to delete");
        return;
    }
    
    id selectedItem = [self.archiveOutlineView itemAtRow:selectedRow];
    
    // Determina quale sessione eliminare
    ExecutionSession *sessionToDelete = nil;
    
    if ([selectedItem isKindOfClass:[ExecutionSession class]]) {
        // È stata selezionata una sessione
        sessionToDelete = (ExecutionSession *)selectedItem;
    } else if ([selectedItem isKindOfClass:[ModelResult class]]) {
        // È stato selezionato un modello - trova la sessione parent
        id parentItem = [self.archiveOutlineView parentForItem:selectedItem];
        if ([parentItem isKindOfClass:[ExecutionSession class]]) {
            sessionToDelete = (ExecutionSession *)parentItem;
        }
    }
    
    if (!sessionToDelete) {
        NSLog(@"⚠️ Could not determine session to delete");
        return;
    }
    
    // Conferma eliminazione
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Archive Entry?";
    alert.informativeText = [NSString stringWithFormat:
        @"Delete entire session from %@?\n\n"
        @"This will delete:\n"
        @"• %ld models\n"
        @"• %ld total symbols\n\n"
        @"This action cannot be undone.",
        [sessionToDelete formattedExecutionDate],
        (long)sessionToDelete.totalModels,
        (long)sessionToDelete.totalSymbols];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        NSLog(@"ℹ️ Delete cancelled by user");
        return;
    }
    
    // Trova e elimina il file
    NSString *archiveDir = [self archiveDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *readError;
    
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:archiveDir error:&readError];
    
    if (readError) {
        NSLog(@"❌ Error reading archive directory: %@", readError);
        
        NSAlert *errorAlert = [[NSAlert alloc] init];
        errorAlert.messageText = @"Delete Failed";
        errorAlert.informativeText = [NSString stringWithFormat:@"Could not read archive directory:\n%@",
                                     readError.localizedDescription];
        errorAlert.alertStyle = NSAlertStyleCritical;
        [errorAlert runModal];
        return;
    }
    
    // Cerca il file corrispondente alla sessione
    BOOL fileFound = NO;
    for (NSString *filename in files) {
        if (![filename hasPrefix:@"session_"] || ![filename hasSuffix:@".json"]) {
            continue;
        }
        
        NSString *filepath = [archiveDir stringByAppendingPathComponent:filename];
        
        // Carica e verifica che sia la sessione corretta
        NSError *loadError;
        ExecutionSession *fileSession = [ExecutionSession loadFromFile:filepath error:&loadError];
        
        if (fileSession && [fileSession.sessionID isEqualToString:sessionToDelete.sessionID]) {
            // Trovato il file - eliminalo
            NSError *deleteError;
            if ([fm removeItemAtPath:filepath error:&deleteError]) {
                NSLog(@"✅ Deleted archive file: %@", filename);
                fileFound = YES;
                
                // Rimuovi dall'array
                [self.archivedSessions removeObject:sessionToDelete];
                
                // Reset selezione
                self.selectedSession = nil;
                self.selectedModelResult = nil;
                
                // Aggiorna UI
                [self.archiveOutlineView reloadData];
                [self.archiveSymbolsTableView reloadData];
                
                self.archiveHeaderLabel.stringValue = @"Select a session or model";
                self.deleteArchiveButton.enabled = NO;
                self.exportArchiveButton.enabled = NO;
                
                NSLog(@"✅ Archive entry deleted successfully");
                return;
                
            } else {
                NSLog(@"❌ Failed to delete file: %@", deleteError);
                
                NSAlert *errorAlert = [[NSAlert alloc] init];
                errorAlert.messageText = @"Delete Failed";
                errorAlert.informativeText = [NSString stringWithFormat:@"Could not delete file:\n%@",
                                             deleteError.localizedDescription];
                errorAlert.alertStyle = NSAlertStyleCritical;
                [errorAlert runModal];
                return;
            }
        }
    }
    
    if (!fileFound) {
        NSLog(@"⚠️ Could not find archive file for session %@", sessionToDelete.sessionID);
        
        NSAlert *errorAlert = [[NSAlert alloc] init];
        errorAlert.messageText = @"Delete Failed";
        errorAlert.informativeText = @"Archive file not found on disk. The session may have been deleted externally.";
        errorAlert.alertStyle = NSAlertStyleWarning;
        [errorAlert runModal];
        
        // Rimuovi comunque dall'array visto che il file non esiste
        [self.archivedSessions removeObject:sessionToDelete];
        [self.archiveOutlineView reloadData];
    }
}

- (void)exportArchive:(id)sender {
    NSInteger selectedRow = [self.archiveOutlineView selectedRow];
    
    if (selectedRow < 0) {
        NSLog(@"⚠️ No selection to export");
        return;
    }
    
    id selectedItem = [self.archiveOutlineView itemAtRow:selectedRow];
    
    // Determina cosa esportare
    ExecutionSession *sessionToExport = nil;
    ModelResult *singleModelToExport = nil;
    
    if ([selectedItem isKindOfClass:[ExecutionSession class]]) {
        // Esporta intera sessione
        sessionToExport = (ExecutionSession *)selectedItem;
        
    } else if ([selectedItem isKindOfClass:[ModelResult class]]) {
        // Esporta solo il modello selezionato
        singleModelToExport = (ModelResult *)selectedItem;
        
        // Trova anche la sessione parent per il contesto
        id parentItem = [self.archiveOutlineView parentForItem:selectedItem];
        if ([parentItem isKindOfClass:[ExecutionSession class]]) {
            sessionToExport = (ExecutionSession *)parentItem;
        }
    }
    
    if (!sessionToExport) {
        NSLog(@"⚠️ Could not determine session to export");
        return;
    }
    
    // Configura il save panel
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"txt"];
    
    NSString *defaultName;
    if (singleModelToExport) {
        defaultName = [NSString stringWithFormat:@"Archive_%@_%@.txt",
                      [sessionToExport formattedExecutionDate],
                      singleModelToExport.modelName];
    } else {
        defaultName = [NSString stringWithFormat:@"Archive_%@.txt",
                      [sessionToExport formattedExecutionDate]];
    }
    
    // Pulisci il nome file (rimuovi caratteri non validi)
    NSCharacterSet *invalidChars = [NSCharacterSet characterSetWithCharactersInString:@"/:*?\"<>|"];
    defaultName = [[defaultName componentsSeparatedByCharactersInSet:invalidChars]
                   componentsJoinedByString:@"_"];
    
    savePanel.nameFieldStringValue = defaultName;
    savePanel.message = singleModelToExport ?
        @"Export single model from archive" :
        @"Export entire session from archive";
    
    [savePanel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            if (singleModelToExport) {
                [self exportSingleModel:singleModelToExport
                            fromSession:sessionToExport
                                  toURL:savePanel.URL];
            } else {
                [self exportSession:sessionToExport toURL:savePanel.URL];
            }
        }
    }];
}

- (void)exportSession:(ExecutionSession *)session toURL:(NSURL *)url {
    NSMutableString *report = [NSMutableString string];
    
    // Header
    [report appendString:@"           ARCHIVED SCREENING SESSION\n"];
    
    [report appendFormat:@"Execution Date: %@\n", [session formattedExecutionDate]];
    [report appendFormat:@"Session ID: %@\n", session.sessionID];
    [report appendFormat:@"Total Models: %ld\n", (long)session.totalModels];
    [report appendFormat:@"Total Symbols: %ld\n", (long)session.totalSymbols];
    [report appendFormat:@"Universe Size: %ld\n\n", (long)session.universe.count];
    [report appendString:@"───────────────────────────────────────────────────\n\n"];
    
    // Per ogni modello
    NSInteger modelNumber = 1;
    for (ModelResult *result in session.modelResults) {
        [report appendFormat:@"%ld. MODEL: %@\n", (long)modelNumber++, result.modelName];
        
        if (result.modelDescription && result.modelDescription.length > 0) {
            [report appendFormat:@"   Description: %@\n", result.modelDescription];
        }
        
        [report appendFormat:@"   Execution Time: %.2fs\n", result.totalExecutionTime];
        [report appendFormat:@"   Initial Universe: %ld symbols\n", (long)result.initialUniverseSize];
        [report appendFormat:@"   Final Symbols: %lu\n\n", (unsigned long)result.screenedSymbols.count];
        
        // Step details
        if (result.steps && result.steps.count > 0) {
            [report appendString:@"   Screening Pipeline:\n"];
            for (NSInteger i = 0; i < result.steps.count; i++) {
                ScreenerStep *step = result.steps[i];
                [report appendFormat:@"      Step %ld: %@", (long)(i + 1), step.screenerID];
                [report appendFormat:@" (Input: %@)\n",
                    [step.inputSource isEqualToString:@"universe"] ? @"Universe" : @"Previous"];
                
                if (step.parameters.count > 0) {
                    NSArray *sortedKeys = [step.parameters.allKeys sortedArrayUsingSelector:@selector(compare:)];
                    for (NSString *key in sortedKeys) {
                        [report appendFormat:@"         • %@ = %@\n", key, step.parameters[key]];
                    }
                }
            }
            [report appendString:@"\n"];
        }
        
        // Lista simboli
        [report appendFormat:@"   Symbols (%lu):\n", (unsigned long)result.screenedSymbols.count];
        
        NSArray *sortedSymbols = [result.screenedSymbols sortedArrayUsingComparator:
            ^NSComparisonResult(ScreenedSymbol *s1, ScreenedSymbol *s2) {
                return [s1.symbol compare:s2.symbol];
            }];
        
        for (ScreenedSymbol *symbol in sortedSymbols) {
            [report appendFormat:@"      • %@", symbol.symbol];
            
            // Aggiungi metadata se disponibile
            if (symbol.metadata.count > 0) {
                NSMutableArray *metadataStrings = [NSMutableArray array];
                for (NSString *key in symbol.metadata.allKeys) {
                    [metadataStrings addObject:[NSString stringWithFormat:@"%@: %@",
                                               key, symbol.metadata[key]]];
                }
                [report appendFormat:@" (%@)", [metadataStrings componentsJoinedByString:@", "]];
            }
            
            [report appendString:@"\n"];
        }
        
        [report appendString:@"\n───────────────────────────────────────────────────\n\n"];
    }
    
    // Footer con tutti i simboli unici
    NSMutableSet<NSString *> *uniqueSymbols = [NSMutableSet set];
    for (ModelResult *result in session.modelResults) {
        for (ScreenedSymbol *symbol in result.screenedSymbols) {
            [uniqueSymbols addObject:symbol.symbol];
        }
    }
    
    [report appendFormat:@"      ALL UNIQUE SYMBOLS (%lu)\n", (unsigned long)uniqueSymbols.count];
    
    NSArray *sortedUniqueSymbols = [[uniqueSymbols allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    // Stampa in colonne (5 simboli per riga)
    NSInteger column = 0;
    for (NSString *symbol in sortedUniqueSymbols) {
        [report appendFormat:@"%-12s", [symbol UTF8String]];
        column++;
        if (column >= 5) {
            [report appendString:@"\n"];
            column = 0;
        }
    }
    
    if (column > 0) {
        [report appendString:@"\n"];
    }
    
   
    
    // Salva il file
    NSError *error;
    BOOL success = [report writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (success) {
        NSLog(@"✅ Exported session to: %@", url.path);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Export Successful";
        alert.informativeText = [NSString stringWithFormat:
            @"Session exported:\n"
            @"• %ld models\n"
            @"• %ld total symbols\n"
            @"• %lu unique symbols",
            (long)session.totalModels,
            (long)session.totalSymbols,
            (unsigned long)uniqueSymbols.count];
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"Open"];
        [alert addButtonWithTitle:@"OK"];
        
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
        
    } else {
        NSLog(@"❌ Failed to export: %@", error);
        
        NSAlert *errorAlert = [[NSAlert alloc] init];
        errorAlert.messageText = @"Export Failed";
        errorAlert.informativeText = error.localizedDescription;
        errorAlert.alertStyle = NSAlertStyleCritical;
        [errorAlert runModal];
    }
}

- (void)exportSingleModel:(ModelResult *)modelResult
              fromSession:(ExecutionSession *)session
                    toURL:(NSURL *)url {
    
    NSMutableString *report = [NSMutableString string];
    
    // Header
    [report appendString:@"           ARCHIVED MODEL EXPORT\n"];
    
    [report appendFormat:@"Session Date: %@\n", [session formattedExecutionDate]];
    [report appendFormat:@"Model: %@\n", modelResult.modelName];
    
    if (modelResult.modelDescription && modelResult.modelDescription.length > 0) {
        [report appendFormat:@"Description: %@\n", modelResult.modelDescription];
    }
    
    [report appendFormat:@"Execution Time: %.2fs\n", modelResult.totalExecutionTime];
    [report appendFormat:@"Initial Universe: %ld symbols\n", (long)modelResult.initialUniverseSize];
    [report appendFormat:@"Final Symbols: %lu\n\n", (unsigned long)modelResult.screenedSymbols.count];
    [report appendString:@"───────────────────────────────────────────────────\n\n"];
    
    // Step details
    if (modelResult.steps && modelResult.steps.count > 0) {
        [report appendString:@"Screening Pipeline:\n\n"];
        for (NSInteger i = 0; i < modelResult.steps.count; i++) {
            ScreenerStep *step = modelResult.steps[i];
            [report appendFormat:@"Step %ld: %@\n", (long)(i + 1), step.screenerID];
            [report appendFormat:@"   Input Source: %@\n",
                [step.inputSource isEqualToString:@"universe"] ? @"Universe" : @"Previous Step"];
            
            if (step.parameters.count > 0) {
                [report appendString:@"   Parameters:\n"];
                NSArray *sortedKeys = [step.parameters.allKeys sortedArrayUsingSelector:@selector(compare:)];
                for (NSString *key in sortedKeys) {
                    [report appendFormat:@"      • %@ = %@\n", key, step.parameters[key]];
                }
            }
            [report appendString:@"\n"];
        }
        [report appendString:@"───────────────────────────────────────────────────\n\n"];
    }
    
    // Lista simboli
    [report appendFormat:@"Screened Symbols (%lu):\n\n", (unsigned long)modelResult.screenedSymbols.count];
    
    NSArray *sortedSymbols = [modelResult.screenedSymbols sortedArrayUsingComparator:
        ^NSComparisonResult(ScreenedSymbol *s1, ScreenedSymbol *s2) {
            return [s1.symbol compare:s2.symbol];
        }];
    
    for (ScreenedSymbol *symbol in sortedSymbols) {
        [report appendFormat:@"   • %@", symbol.symbol];
        
        // Aggiungi metadata se disponibile
        if (symbol.metadata.count > 0) {
            NSMutableArray *metadataStrings = [NSMutableArray array];
            for (NSString *key in symbol.metadata.allKeys) {
                [metadataStrings addObject:[NSString stringWithFormat:@"%@: %@",
                                           key, symbol.metadata[key]]];
            }
            [report appendFormat:@" (%@)", [metadataStrings componentsJoinedByString:@", "]];
        }
        
        [report appendString:@"\n"];
    }
    
  
    
    // Salva il file
    NSError *error;
    BOOL success = [report writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (success) {
        NSLog(@"✅ Exported model to: %@", url.path);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Export Successful";
        alert.informativeText = [NSString stringWithFormat:
            @"Model '%@' exported:\n"
            @"• %lu symbols\n"
            @"• %ld screening steps",
            modelResult.modelName,
            (unsigned long)modelResult.screenedSymbols.count,
            (long)modelResult.steps.count];
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"Open"];
        [alert addButtonWithTitle:@"OK"];
        
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
        
    } else {
        NSLog(@"❌ Failed to export: %@", error);
        
        NSAlert *errorAlert = [[NSAlert alloc] init];
        errorAlert.messageText = @"Export Failed";
        errorAlert.informativeText = error.localizedDescription;
        errorAlert.alertStyle = NSAlertStyleCritical;
        [errorAlert runModal];
    }
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    if (tableView != self.archiveSymbolsTableView) return;
    
    NSArray<ScreenedSymbol *> *symbolsToSort;
    
    if (self.selectedModelResult) {
        symbolsToSort = self.selectedModelResult.screenedSymbols;
    } else if (self.selectedSession) {
        NSMutableArray *allSymbols = [NSMutableArray array];
        for (ModelResult *result in self.selectedSession.modelResults) {
            [allSymbols addObjectsFromArray:result.screenedSymbols];
        }
        symbolsToSort = allSymbols;
    } else {
        return;
    }
    
    // Applica il sorting
    NSArray<ScreenedSymbol *> *sortedSymbols = [symbolsToSort sortedArrayUsingDescriptors:tableView.sortDescriptors];
    
    // Aggiorna i dati
    if (self.selectedModelResult) {
        self.selectedModelResult.screenedSymbols = sortedSymbols;
    }
    // Se è una sessione, non possiamo modificare l'array originale facilmente,
    // quindi ricarica semplicemente la tabella che userà i sort descriptors
    
    [self.archiveSymbolsTableView reloadData];
}


#pragma mark - Compact Report to Clipboard
    

- (void)targetDateChanged:(NSDatePicker *)sender {
    NSLog(@"📅 Target date changed to: %@", sender.dateValue);
    
    // Aggiorna la data target nel dataManager
    self.dataManager.targetDate = sender.dateValue;
    
    // Invalida il database corrente - deve essere riscansionato
    [self.dataManager scanDatabaseWithCompletion:^(NSArray<NSString *> *symbols, NSError *error) {
        if (error) {
            NSLog(@"❌ Error rescanning database: %@", error);
            return;
        }
        
        self.availableSymbols = symbols;
        self.universeLabel.stringValue = [NSString stringWithFormat:@"Universe: %ld symbols (for %@)",
                                          (long)symbols.count,
                                          [NSDateFormatter localizedStringFromDate:sender.dateValue
                                                                         dateStyle:NSDateFormatterShortStyle
                                                                         timeStyle:NSDateFormatterNoStyle]];
        
        NSLog(@"✅ Database rescanned for target date: %ld symbols available", (long)symbols.count);
    }];
}

#pragma mark - Send to Chain with Historical Data



- (void)loadHistoricalDataAndSendToChain:(NSArray<NSString *> *)symbols {
    if (!self.dataManager) {
        NSLog(@"❌ No data manager available");
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot Load Data";
        alert.informativeText = @"Data manager not initialized. Please check Settings tab.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert runModal];
        return;
    }
    
    // ✅ USA LA DATA DELLA SESSION SELEZIONATA (quella usata per lo screening)
    NSDate *targetDate = self.selectedSession.executionDate;
    
    if (!targetDate) {
        // Fallback se non c'è session selezionata
        targetDate = [self.dataManager expectedLastCloseDate];
        NSLog(@"⚠️ No session selected, using expected last close date");
    }
    
    // ✅ VERIFICA SE LA CACHE È VALIDA
    BOOL cacheIsValid = NO;
    
    if (self.lastScreeningCache && self.lastScreeningDate) {
        // Verifica se è la cache della session corrente O dello screening recente con stessa data
        BOOL isCorrectSession = NO;
        
        if (self.selectedSession) {
            // Stiamo lavorando su una session dall'archivio
            isCorrectSession = (self.cachedSessionID != nil &&
                               [self.cachedSessionID isEqualToString:self.selectedSession.sessionID]);
        } else {
            // Stiamo lavorando su screening appena fatto
            isCorrectSession = (self.cachedSessionID == nil &&
                               [self.lastScreeningDate isEqualToDate:targetDate]);
        }
        
        if (isCorrectSession) {
            // Verifica che la cache contenga i simboli richiesti
            NSInteger foundCount = 0;
            for (NSString *symbol in symbols) {
                if (self.lastScreeningCache[symbol]) {
                    foundCount++;
                }
            }
            
            if (foundCount == symbols.count) {
                cacheIsValid = YES;
                NSLog(@"✅ Cache HIT! Using cached data for %ld symbols", (long)symbols.count);
            } else {
                NSLog(@"⚠️ Cache PARTIAL: only %ld/%ld symbols available",
                      (long)foundCount, (long)symbols.count);
            }
        } else {
            if (self.selectedSession) {
                NSLog(@"⚠️ Cache session mismatch: cached=%@ current=%@",
                      self.cachedSessionID ?: @"(recent screening)",
                      self.selectedSession.sessionID);
            } else {
                NSLog(@"⚠️ Cache date mismatch or session changed");
            }
        }
    } else {
        NSLog(@"⚠️ No cache available");
    }
    
    // ✅ SE LA CACHE È VALIDA, USA QUELLA
    if (cacheIsValid) {
        NSLog(@"🚀 Using cached data - instant send!");
        
        // Filtra solo i simboli richiesti dalla cache
        NSMutableDictionary *filteredCache = [NSMutableDictionary dictionary];
        for (NSString *symbol in symbols) {
            filteredCache[symbol] = self.lastScreeningCache[symbol];
        }
        
        [self sendSymbolsWithDataToChain:symbols historicalData:filteredCache];
        return;
    }
    
    // ✅ NESSUNA CACHE VALIDA - RICARICA I DATI
    NSLog(@"📊 No valid cache - reloading data from disk...");
    
    // Calcola minBars necessari
    NSInteger minBars = 100;  // Default
    
    if (self.selectedModelResult) {
        minBars = [self calculateMinBarsForModelResult:self.selectedModelResult];
    } else if (self.selectedSession) {
        minBars = [self calculateMinBarsForSession:self.selectedSession];
    }
    
    // ✅ IMPOSTA LA TARGET DATE nel dataManager
    self.dataManager.targetDate = targetDate;
    
    NSLog(@"📊 Loading %ld bars for %ld symbols from date: %@",
          (long)minBars,
          (long)symbols.count,
          [NSDateFormatter localizedStringFromDate:targetDate
                                         dateStyle:NSDateFormatterShortStyle
                                         timeStyle:NSDateFormatterNoStyle]);
    
    // ✅ Ricarica i dati storici
    [self.dataManager loadDataForSymbols:symbols
                                 minBars:minBars
                              completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *cache, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !cache || cache.count == 0) {
                NSLog(@"❌ Failed to load historical data: %@", error ?: @"No data");
                
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Failed to Load Data";
                alert.informativeText = error ? error.localizedDescription : @"No data available";
                alert.alertStyle = NSAlertStyleCritical;
                [alert runModal];
                return;
            }
            
            NSLog(@"✅ Loaded historical data for %lu symbols", (unsigned long)cache.count);
            
            // ✅✅✅ SALVA LA CACHE
            if (self.selectedSession) {
                // Merge con cache esistente se è la stessa session
                if (self.lastScreeningCache &&
                    self.cachedSessionID &&
                    [self.cachedSessionID isEqualToString:self.selectedSession.sessionID]) {
                    // Merge i nuovi dati
                    NSMutableDictionary *mergedCache = [self.lastScreeningCache mutableCopy];
                    [mergedCache addEntriesFromDictionary:cache];
                    self.lastScreeningCache = [mergedCache copy];
                    
                    NSLog(@"💾 Merged cache for session %@ (now %lu symbols)",
                          self.selectedSession.sessionID,
                          (unsigned long)self.lastScreeningCache.count);
                } else {
                    // Nuova session - sostituisci la cache
                    self.lastScreeningCache = cache;
                    self.lastScreeningDate = targetDate;
                    self.cachedSessionID = self.selectedSession.sessionID;
                    
                    NSLog(@"💾 Cached data for session %@ (%lu symbols)",
                          self.selectedSession.sessionID,
                          (unsigned long)cache.count);
                }
            } else {
                // Screening recente - salva con cachedSessionID = nil
                self.lastScreeningCache = cache;
                self.lastScreeningDate = targetDate;
                self.cachedSessionID = nil;  // ✅ nil = screening recente
                
                NSLog(@"💾 Cached screening data for date %@ (%lu symbols)",
                      [NSDateFormatter localizedStringFromDate:targetDate
                                                     dateStyle:NSDateFormatterShortStyle
                                                     timeStyle:NSDateFormatterNoStyle],
                      (unsigned long)cache.count);
            }
            
            // ✅ INVIA tramite chain
            [self sendSymbolsWithDataToChain:symbols historicalData:cache];
        });
    }];
}

#pragma mark - Send Single Symbol with Historical Data

#pragma mark - Send Single Symbol with Historical Data

- (void)sendSingleSymbolWithData:(NSString *)symbolString {
    if (!symbolString || symbolString.length == 0) {
        NSLog(@"⚠️ No symbol to send");
        return;
    }
    
    // ✅ Riutilizza il metodo esistente che gestisce già la cache!
    [self loadHistoricalDataAndSendToChain:@[symbolString]];
}
- (void)sendSymbolsWithDataToChain:(NSArray<NSString *> *)symbols
                    historicalData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)historicalData {
    
    if (!self.chainActive) {
        NSLog(@"⚠️ Chain not active");
        return;
    }
    
    // ✅ INVIA OGNI SIMBOLO SEPARATAMENTE come fa ChartPatternLibrary
    for (NSString *symbol in symbols) {
        NSArray<HistoricalBarModel *> *bars = historicalData[symbol];
        if (!bars || bars.count == 0) continue;
        
        // ✅ USA LA STESSA STRUTTURA DI ChartPatternLibraryWidget
        // Crea un payload che simula un pattern con i dati screener
        NSDictionary *screenerData = @{
            @"symbol": symbol,
            @"historicalBars": bars,  // ✅ Stessa chiave usata da SavedChartData
            @"timeframe": @(1000),
            @"source": @"StooqScreener",
            @"patternType": @"Screener Result"  // Identificativo per debugging
        };
        
        // ✅ INVIA con action personalizzata (non loadChartPattern)
        [self sendChainAction:@"loadScreenerData" withData:screenerData];
        
        NSLog(@"🔗 Sent %@ with %lu bars to chain", symbol, (unsigned long)bars.count);
    }
    
    // Feedback visivo
    [self showChainFeedback:[NSString stringWithFormat:@"📊 Sent %ld symbols with data", (long)symbols.count]];
}

#pragma mark - Calculate MinBars

- (NSInteger)calculateMinBarsForModelResult:(ModelResult *)modelResult {
    NSInteger maxBars = 60;
    
    if (!modelResult.steps || modelResult.steps.count == 0) {
        return maxBars;
    }
    
    ScreenerRegistry *registry = [ScreenerRegistry sharedRegistry];
    
    for (ScreenerStep *step in modelResult.steps) {
        BaseScreener *screener = [registry screenerWithID:step.screenerID];
        if (screener) {
            screener.parameters = step.parameters;
            NSInteger required = screener.minBarsRequired;
            if (required > maxBars) {
                maxBars = required;
            }
        }
    }
    
    return maxBars;
}

- (NSInteger)calculateMinBarsForSession:(ExecutionSession *)session {
    NSInteger maxBars = 60;
    
    for (ModelResult *result in session.modelResults) {
        NSInteger resultBars = [self calculateMinBarsForModelResult:result];
        if (resultBars > maxBars) {
            maxBars = resultBars;
        }
    }
    
    return maxBars;
}

/*
#pragma mark - per cancellare archivio

- (void)deleteAllArchiveData {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    
    NSLog(@"🗑️ Deleting all archive data...");
    
    // 1. Trova la directory dell'archivio
    NSString *archiveDir = [self archiveDirectory];
    
    // 2. Elimina TUTTA la directory
    if ([fm fileExistsAtPath:archiveDir]) {
        if ([fm removeItemAtPath:archiveDir error:&error]) {
            NSLog(@"✅ Deleted archive directory: %@", archiveDir);
        } else {
            NSLog(@"❌ Failed to delete archive: %@", error);
            return;
        }
    }
    
    // 3. Elimina anche il vecchio file .dat se esiste
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString *appSupportDir = paths[0];
    NSString *appDir = [appSupportDir stringByAppendingPathComponent:@"TradingApp"];
    NSString *oldArchiveFile = [appDir stringByAppendingPathComponent:@"screener_archive.dat"];
    
    if ([fm fileExistsAtPath:oldArchiveFile]) {
        if ([fm removeItemAtPath:oldArchiveFile error:&error]) {
            NSLog(@"✅ Deleted old archive file: %@", oldArchiveFile);
        } else {
            NSLog(@"⚠️ Failed to delete old file: %@", error);
        }
    }
    
    NSLog(@"✅ Archive cleanup complete - all data deleted");
}
 */
#pragma mark - calcolo stats archivio

- (void)updateArchiveStatistics {
    NSArray<ScreenedSymbol *> *allSymbols = [self getAllArchiveSymbols];
    NSArray<ScreenedSymbol *> *selectedSymbols = [self getSelectedArchiveSymbols];
    
    // Calcola per TUTTI
    NSString *allStats = [self calculateStatisticsForSymbols:allSymbols prefix:@"All"];
    self.statsAllLabel.stringValue = allStats;
    
    // Calcola per SELECTED
    NSString *selectedStats = [self calculateStatisticsForSymbols:selectedSymbols prefix:@"Selected"];
    self.statsSelectedLabel.stringValue = selectedStats;
}

/// Ottiene TUTTI i simboli dal modello corrente (archiveSymbolsTableView)
- (NSArray<ScreenedSymbol *> *)getAllArchiveSymbols {
    if (self.selectedModelResult) {
        // ✅ TUTTI i simboli del MODELLO selezionato
        return self.selectedModelResult.screenedSymbols;
    } else if (self.selectedSession) {
        // ⚠️ Se è selezionata una SESSION intera, prendi da TUTTI i modelli
        NSMutableArray<ScreenedSymbol *> *allSymbols = [NSMutableArray array];
        for (ModelResult *result in self.selectedSession.modelResults) {
            [allSymbols addObjectsFromArray:result.screenedSymbols];
        }
        return [allSymbols copy];
    }
    
    return @[];
}

/// Ottiene i simboli SELEZIONATI dal modello corrente (archiveSymbolsTableView)
- (NSArray<ScreenedSymbol *> *)getSelectedArchiveSymbols {
    NSMutableArray<ScreenedSymbol *> *selected = [NSMutableArray array];
    
    if (self.selectedModelResult) {
        // ✅ Simboli del MODELLO selezionato
        for (ScreenedSymbol *symbol in self.selectedModelResult.screenedSymbols) {
            if (symbol.isSelected) {
                [selected addObject:symbol];
            }
        }
    } else if (self.selectedSession) {
        // ⚠️ Se è selezionata una SESSION intera, prendi da TUTTI i modelli
        for (ModelResult *result in self.selectedSession.modelResults) {
            for (ScreenedSymbol *symbol in result.screenedSymbols) {
                if (symbol.isSelected) {
                    [selected addObject:symbol];
                }
            }
        }
    }
    
    return [selected copy];
}


- (NSString *)calculateStatisticsForSymbols:(NSArray<ScreenedSymbol *> *)symbols prefix:(NSString *)prefix {
    if (symbols.count == 0) {
        return [NSString stringWithFormat:@"%@: --", prefix];
    }
    
    // 1. Count
    NSInteger count = symbols.count;
    
    // 2. Days count
    NSInteger days = 0;
    if (self.selectedSession || self.selectedModelResult) {
        NSDate *targetDate = self.selectedSession ?
            self.selectedSession.executionDate :
            self.selectedModelResult.executionTime;
        
        NSDate *today = [NSDate date];
        days = [[NSCalendar currentCalendar]
            components:NSCalendarUnitDay
            fromDate:targetDate
            toDate:today
            options:0].day;
    }
    
    // 3. Win rate + Avg % per trade
    NSInteger winners = 0;
    NSInteger losers = 0;
    double totalChange = 0.0;
    NSInteger validCount = 0;
    
    for (ScreenedSymbol *symbol in symbols) {
        NSNumber *changePercent = [symbol metadataValueForKey:@"changePercent"];
        if (changePercent) {
            double change = [changePercent doubleValue];
            totalChange += change;
            validCount++;
            
            if (change >= 0) winners++;
            else losers++;
        }
    }
    
    double winRate = (winners + losers > 0) ?
        (winners * 100.0) / (winners + losers) : 0.0;
    
    double avgPerTrade = validCount > 0 ? totalChange / validCount : 0.0;
    
    // 4. Avg % per day (semplice)
    double avgPerDaySimple = (days > 0) ? avgPerTrade / days : 0.0;
    
    // 5. Avg % per day (composta)
    double avgPerDayCompound = 0.0;
    if (days > 0 && avgPerTrade != 0) {
        avgPerDayCompound = (pow(1.0 + avgPerTrade/100.0, 1.0/days) - 1.0) * 100.0;
    }
    
    // Formato output
    return [NSString stringWithFormat:
        @"%@: %ld symbols • %ld days • Win: %.1f%% • Avg/Trade: %+.2f%% • Avg/Day: %+.2f%% (simple) / %+.2f%% (compound)",
        prefix, (long)count, (long)days, winRate, avgPerTrade, avgPerDaySimple, avgPerDayCompound];
}


- (void)updateArchivedSession:(id)sender {
    if (self.executionResults.count == 0) {
        NSLog(@"No results to update");
        return;
    }
    
    // Trova la sessione archiviata più recente (quella appena creata)
    if (self.archivedSessions.count == 0) {
        NSLog(@"No archived session found");
        return;
    }
    
    ExecutionSession *latestSession = self.archivedSessions.firstObject;  // Sono ordinate per data
    
    // Aggiorna le selezioni nella session
    for (ModelResult *archivedResult in latestSession.modelResults) {
        ModelResult *currentResult = self.executionResults[archivedResult.modelID];
        if (currentResult) {
            // Copia lo stato isSelected dai risultati correnti
            for (NSInteger i = 0; i < archivedResult.screenedSymbols.count; i++) {
                if (i < currentResult.screenedSymbols.count) {
                    archivedResult.screenedSymbols[i].isSelected =
                        currentResult.screenedSymbols[i].isSelected;
                }
            }
        }
    }
    
    // Salva su disco
    NSString *archiveDir = [self archiveDirectory];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd_HHmmss";
    NSString *dateString = [dateFormatter stringFromDate:latestSession.executionDate];
    
    NSString *filename = [NSString stringWithFormat:@"session_%@_%@.json",
                         dateString,
                         [latestSession.sessionID substringToIndex:8]];
    NSString *filepath = [archiveDir stringByAppendingPathComponent:filename];
    
    NSError *error;
    if ([latestSession saveToFile:filepath error:&error]) {
        NSLog(@"✅ Archive updated with current selections");
    } else {
        NSLog(@"❌ Failed to update archive: %@", error);
    }
}


#pragma mark - archive report

#pragma mark - Archive Report Actions

- (void)generateArchiveReport:(id)sender {
    // Verifica che ci sia una selezione
    if (!self.selectedSession && !self.selectedModelResult) {
        NSLog(@"⚠️ No session or model selected");
        return;
    }
    
    // Conta simboli selezionati
    NSArray<ScreenedSymbol *> *selectedSymbols = [self getSelectedArchiveSymbols];
    NSArray<ScreenedSymbol *> *allSymbols = [self getAllArchiveSymbols];
    
    // Setup save panel
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"txt"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd_HHmm";
    NSString *dateString;
    
    if (self.selectedSession) {
        dateString = [dateFormatter stringFromDate:self.selectedSession.executionDate];
    } else {
        dateString = [dateFormatter stringFromDate:[NSDate date]];
    }
    
    NSString *defaultName = [NSString stringWithFormat:@"Archive_Report_%@.txt", dateString];
    savePanel.nameFieldStringValue = defaultName;
    
    // Accessory view con opzioni
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 80)];
    
    NSButton *includeAllCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 50, 360, 25)];
    [includeAllCheckbox setButtonType:NSButtonTypeSwitch];
    includeAllCheckbox.title = @"Include all symbols (not just selected)";
    includeAllCheckbox.state = NSControlStateValueOff;
    includeAllCheckbox.tag = 100;
    [accessoryView addSubview:includeAllCheckbox];
    
    NSButton *includeParamsCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 25, 360, 25)];
    [includeParamsCheckbox setButtonType:NSButtonTypeSwitch];
    includeParamsCheckbox.title = @"Include model parameters";
    includeParamsCheckbox.state = NSControlStateValueOff;
    includeParamsCheckbox.tag = 101;
    [accessoryView addSubview:includeParamsCheckbox];
    
    NSTextField *infoLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 0, 360, 20)];
    infoLabel.stringValue = [NSString stringWithFormat:@"Selected: %ld / %ld symbols",
                            (long)selectedSymbols.count, (long)allSymbols.count];
    infoLabel.editable = NO;
    infoLabel.bordered = NO;
    infoLabel.backgroundColor = [NSColor clearColor];
    infoLabel.textColor = [NSColor secondaryLabelColor];
    infoLabel.font = [NSFont systemFontOfSize:11];
    [accessoryView addSubview:infoLabel];
    
    savePanel.accessoryView = accessoryView;
    
    [savePanel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            BOOL includeAll = (includeAllCheckbox.state == NSControlStateValueOn);
            BOOL includeParams = (includeParamsCheckbox.state == NSControlStateValueOn);
            
            // Usa i metodi di export esistenti
            if (self.selectedModelResult) {
                [self exportSingleModel:self.selectedModelResult
                            fromSession:self.selectedSession
                                  toURL:savePanel.URL];
            } else if (self.selectedSession) {
                [self exportSession:self.selectedSession toURL:savePanel.URL];
            }
        }
    }];
}

- (void)copyArchiveAllSymbols:(id)sender {
    [self copyArchiveCompactReportWithSelectedOnly:NO];
}

- (void)copyArchiveSelectedSymbols:(id)sender {
    [self copyArchiveCompactReportWithSelectedOnly:YES];
}

- (void)copyArchiveCompactReportWithSelectedOnly:(BOOL)onlySelectedSymbols {
    NSMutableString *reportString = [NSMutableString string];
    
    // Determina quali modelli processare
    NSArray<ModelResult *> *modelsToProcess;
    
    if (self.selectedModelResult) {
        // Solo il modello selezionato
        modelsToProcess = @[self.selectedModelResult];
    } else if (self.selectedSession) {
        // Tutti i modelli della sessione
        modelsToProcess = self.selectedSession.modelResults;
    } else {
        NSLog(@"⚠️ No selection for compact report");
        return;
    }
    
    // Per ogni modello
    for (ModelResult *result in modelsToProcess) {
        NSMutableArray<NSString *> *symbolsToInclude = [NSMutableArray array];
        
        for (ScreenedSymbol *symbol in result.screenedSymbols) {
            if (!onlySelectedSymbols || symbol.isSelected) {
                [symbolsToInclude addObject:symbol.symbol];
            }
        }
        
        if (symbolsToInclude.count == 0) continue;
        
        NSString *line = [NSString stringWithFormat:@"%@: %@\n",
                         result.modelName,
                         [symbolsToInclude componentsJoinedByString:@","]];
        [reportString appendString:line];
    }
    
    if (reportString.length == 0) {
        NSLog(@"⚠️ No symbols to copy");
        return;
    }
    
    // Copia negli appunti
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:reportString forType:NSPasteboardTypeString];
    
    NSLog(@"📋 Compact archive report copied (%@)", onlySelectedSymbols ? @"selected" : @"all");
}


@end

