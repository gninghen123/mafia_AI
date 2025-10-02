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

@interface StooqScreenerWidget () <NSTableViewDelegate, NSTableViewDataSource, ScreenerBatchRunnerDelegate>
// Tab 4: Archive
@property (nonatomic, strong) NSTableView *archiveTableView;
@property (nonatomic, strong) NSScrollView *archiveScrollView;
@property (nonatomic, strong) NSTableView *archiveSymbolsTableView;
@property (nonatomic, strong) NSScrollView *archiveSymbolsScrollView;
@property (nonatomic, strong) NSSplitView *archiveSplitView;
@property (nonatomic, strong) NSTextField *archiveHeaderLabel;
@property (nonatomic, strong) NSButton *deleteArchiveButton;
@property (nonatomic, strong) NSButton *exportArchiveButton;


@property (nonatomic, strong) NSArray<NSString *> *selectedModelSymbols;

// Archive data
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *archivedResults;  // Array di {date, modelName, symbols}
@property (nonatomic, strong) NSDictionary *selectedArchiveEntry;  // Entry selezionata
@property (nonatomic, strong) StooqDataManager *currentPriceDataManager;  // Per calcolare var%

// Aggiungi questa property all'interface
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedSymbolsForReport;
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
@property (nonatomic, strong) NSSplitView *resultsSplitView;

// Left side: Models results table
@property (nonatomic, strong) NSTableView *resultsModelsTableView;
@property (nonatomic, strong) NSScrollView *resultsModelsScrollView;

// Right side: Symbols table
@property (nonatomic, strong) NSTableView *resultsSymbolsTableView;
@property (nonatomic, strong) NSScrollView *resultsSymbolsScrollView;
@property (nonatomic, strong) NSTextField *symbolsHeaderLabel;
@property (nonatomic, strong) NSButton *sendSelectedButton;
@property (nonatomic, strong) NSButton *sendAllButton;

// Results data
@property (nonatomic, strong) NSString *selectedResultModelID;  // Currently selected model ID
@property (nonatomic, strong) NSArray<NSString *> *currentModelSymbols;  // Symbols of selected model

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

- (instancetype)initWithType:(NSString *)widgetType panelType:(PanelType)panelType {
    self = [super initWithType:widgetType panelType:panelType];
    if (self) {
        _models = [NSMutableArray array];
        _executionResults = [NSMutableDictionary dictionary];
        _selectedExchanges = @[@"nasdaq", @"nyse"];
        _modelManager = [ModelManager sharedManager];
        [self initDataBase];
    }
    return self;
}

- (void)initDataBase{
    [self loadInitialData];
    [self scanDatabase:nil];
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
    [self setupResultsTab];
    [self setupArchiveTab];  // ✅ NUOVO TAB

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
    
    // Bottom bar
    self.deleteArchiveButton = [NSButton buttonWithTitle:@"Delete" target:self action:@selector(deleteArchiveEntry:)];
    self.deleteArchiveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteArchiveButton.enabled = NO;
    [archiveView addSubview:self.deleteArchiveButton];
    
    self.exportArchiveButton = [NSButton buttonWithTitle:@"Export" target:self action:@selector(exportArchive:)];
    self.exportArchiveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [archiveView addSubview:self.exportArchiveButton];
    
    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [self.archiveSplitView.topAnchor constraintEqualToAnchor:archiveView.topAnchor constant:10],
        [self.archiveSplitView.leadingAnchor constraintEqualToAnchor:archiveView.leadingAnchor constant:10],
        [self.archiveSplitView.trailingAnchor constraintEqualToAnchor:archiveView.trailingAnchor constant:-10],
        [self.archiveSplitView.bottomAnchor constraintEqualToAnchor:self.deleteArchiveButton.topAnchor constant:-10],
        
        [self.deleteArchiveButton.leadingAnchor constraintEqualToAnchor:archiveView.leadingAnchor constant:10],
        [self.deleteArchiveButton.bottomAnchor constraintEqualToAnchor:archiveView.bottomAnchor constant:-10],
        
        [self.exportArchiveButton.leadingAnchor constraintEqualToAnchor:self.deleteArchiveButton.trailingAnchor constant:10],
        [self.exportArchiveButton.centerYAnchor constraintEqualToAnchor:self.deleteArchiveButton.centerYAnchor]
    ]];
    
    // Set split position
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat totalWidth = self.archiveSplitView.frame.size.width;
        if (totalWidth > 0) {
            [self.archiveSplitView setPosition:totalWidth * 0.35 ofDividerAtIndex:0];
        }
    });
    
    NSTabViewItem *archiveTab = [[NSTabViewItem alloc] initWithIdentifier:@"archive"];
    archiveTab.label = @"Archive";
    archiveTab.view = archiveView;
    [self.tabView addTabViewItem:archiveTab];
    
    // Inizializza array archivio
    self.archivedResults = [NSMutableArray array];
    [self loadArchivedResults];
}

- (NSView *)setupArchiveListView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 800)];
    
    NSTextField *label = [NSTextField labelWithString:@"Archived Results"];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [NSFont boldSystemFontOfSize:13];
    [view addSubview:label];
    
    self.archiveTableView = [[NSTableView alloc] init];
    self.archiveTableView.delegate = self;
    self.archiveTableView.dataSource = self;
    self.archiveTableView.allowsMultipleSelection = NO;
    self.archiveTableView.usesAlternatingRowBackgroundColors = YES;
    
    NSTableColumn *dateCol = [[NSTableColumn alloc] initWithIdentifier:@"archive_date"];
    dateCol.title = @"Date";
    dateCol.width = 120;
    [self.archiveTableView addTableColumn:dateCol];
    
    NSTableColumn *modelCol = [[NSTableColumn alloc] initWithIdentifier:@"archive_model"];
    modelCol.title = @"Model";
    modelCol.width = 150;
    [self.archiveTableView addTableColumn:modelCol];
    
    NSTableColumn *countCol = [[NSTableColumn alloc] initWithIdentifier:@"archive_count"];
    countCol.title = @"Symbols";
    countCol.width = 70;
    [self.archiveTableView addTableColumn:countCol];
    
    self.archiveScrollView = [[NSScrollView alloc] init];
    self.archiveScrollView.documentView = self.archiveTableView;
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
    
    self.archiveHeaderLabel = [NSTextField labelWithString:@"Select an archive entry"];
    self.archiveHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.archiveHeaderLabel.font = [NSFont boldSystemFontOfSize:13];
    [view addSubview:self.archiveHeaderLabel];
    
    self.archiveSymbolsTableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 500, 800)];
    self.archiveSymbolsTableView.delegate = self;
    self.archiveSymbolsTableView.dataSource = self;
    self.archiveSymbolsTableView.allowsMultipleSelection = YES;
    self.archiveSymbolsTableView.usesAlternatingRowBackgroundColors = YES;
    
    NSTableColumn *symbolCol = [[NSTableColumn alloc] initWithIdentifier:@"archive_symbol"];
    symbolCol.title = @"Symbol";
    symbolCol.width = 100;
    [self.archiveSymbolsTableView addTableColumn:symbolCol];
    
    NSTableColumn *signalPriceCol = [[NSTableColumn alloc] initWithIdentifier:@"signal_price"];
    signalPriceCol.title = @"Signal Price";
    signalPriceCol.width = 100;
    [self.archiveSymbolsTableView addTableColumn:signalPriceCol];
    
    NSTableColumn *currentPriceCol = [[NSTableColumn alloc] initWithIdentifier:@"current_price"];
    currentPriceCol.title = @"Current Price";
    currentPriceCol.width = 100;
    [self.archiveSymbolsTableView addTableColumn:currentPriceCol];
    
    NSTableColumn *varCol = [[NSTableColumn alloc] initWithIdentifier:@"var_percent"];
    varCol.title = @"Var %";
    varCol.width = 80;
    [self.archiveSymbolsTableView addTableColumn:varCol];
    
    self.archiveSymbolsScrollView = [[NSScrollView alloc] init];
    self.archiveSymbolsScrollView.documentView = self.archiveSymbolsTableView;
    self.archiveSymbolsScrollView.hasVerticalScroller = YES;
    self.archiveSymbolsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.archiveSymbolsScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.archiveHeaderLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:5],
        [self.archiveHeaderLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:5],
        
        [self.archiveSymbolsScrollView.topAnchor constraintEqualToAnchor:self.archiveHeaderLabel.bottomAnchor constant:5],
        [self.archiveSymbolsScrollView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.archiveSymbolsScrollView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [self.archiveSymbolsScrollView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
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
    
    [NSLayoutConstraint activateConstraints:@[
        [self.modelsSplitView.topAnchor constraintEqualToAnchor:modelsView.topAnchor constant:10],
        [self.modelsSplitView.leadingAnchor constraintEqualToAnchor:modelsView.leadingAnchor constant:10],
        [self.modelsSplitView.trailingAnchor constraintEqualToAnchor:modelsView.trailingAnchor constant:-10],
        [self.modelsSplitView.bottomAnchor constraintEqualToAnchor:bottomBar.topAnchor constant:-10],
        
        [bottomBar.leadingAnchor constraintEqualToAnchor:modelsView.leadingAnchor constant:10],
        [bottomBar.trailingAnchor constraintEqualToAnchor:modelsView.trailingAnchor constant:-10],
        [bottomBar.bottomAnchor constraintEqualToAnchor:modelsView.bottomAnchor constant:-10],
        [bottomBar.heightAnchor constraintEqualToConstant:60]
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

- (void)setupResultsTab {
    NSView *resultsView = [[NSView alloc] init];
    
    // Split view per dividere modelli e simboli
    self.resultsSplitView = [[NSSplitView alloc] init];
    self.resultsSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultsSplitView.vertical = YES;
    self.resultsSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [resultsView addSubview:self.resultsSplitView];
    
    // Left side: Models results
    NSView *modelsResultsView = [self setupResultsModelsView];
    [self.resultsSplitView addArrangedSubview:modelsResultsView];
    
    // Right side: Symbols
    NSView *symbolsResultsView = [self setupResultsSymbolsView];
    [self.resultsSplitView addArrangedSubview:symbolsResultsView];
    
    // ✅ Inizializza il set per i simboli selezionati
    self.selectedSymbolsForReport = [NSMutableSet set];
    
    // Bottom bar
    self.exportButton = [NSButton buttonWithTitle:@"Export" target:self action:@selector(exportResults:)];
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    [resultsView addSubview:self.exportButton];
    
    // ✅ NUOVO BOTTONE: Generate Report
    self.generateReportButton = [NSButton buttonWithTitle:@"📝 Generate Report" target:self action:@selector(generateReport:)];
    self.generateReportButton.translatesAutoresizingMaskIntoConstraints = NO;
    [resultsView addSubview:self.generateReportButton];
    
    self.clearResultsButton = [NSButton buttonWithTitle:@"Clear" target:self action:@selector(clearResults:)];
    self.clearResultsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [resultsView addSubview:self.clearResultsButton];
    
    self.resultsStatusLabel = [[NSTextField alloc] init];
    self.resultsStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultsStatusLabel.editable = NO;
    self.resultsStatusLabel.bordered = NO;
    self.resultsStatusLabel.backgroundColor = [NSColor clearColor];
    self.resultsStatusLabel.stringValue = @"No results";
    [resultsView addSubview:self.resultsStatusLabel];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.resultsSplitView.topAnchor constraintEqualToAnchor:resultsView.topAnchor constant:10],
        [self.resultsSplitView.leadingAnchor constraintEqualToAnchor:resultsView.leadingAnchor constant:10],
        [self.resultsSplitView.trailingAnchor constraintEqualToAnchor:resultsView.trailingAnchor constant:-10],
        [self.resultsSplitView.bottomAnchor constraintEqualToAnchor:self.exportButton.topAnchor constant:-10],
        
        [self.exportButton.leadingAnchor constraintEqualToAnchor:resultsView.leadingAnchor constant:10],
        [self.exportButton.bottomAnchor constraintEqualToAnchor:resultsView.bottomAnchor constant:-10],
        
        // ✅ NUOVO CONSTRAINT per Generate Report
        [self.generateReportButton.leadingAnchor constraintEqualToAnchor:self.exportButton.trailingAnchor constant:10],
        [self.generateReportButton.centerYAnchor constraintEqualToAnchor:self.exportButton.centerYAnchor],
        
        [self.clearResultsButton.leadingAnchor constraintEqualToAnchor:self.generateReportButton.trailingAnchor constant:10],
        [self.clearResultsButton.centerYAnchor constraintEqualToAnchor:self.exportButton.centerYAnchor],
        
        [self.resultsStatusLabel.trailingAnchor constraintEqualToAnchor:resultsView.trailingAnchor constant:-10],
        [self.resultsStatusLabel.centerYAnchor constraintEqualToAnchor:self.exportButton.centerYAnchor]
    ]];
    
    // Set split position (35% left, 65% right)
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat totalWidth = self.resultsSplitView.frame.size.width;
        if (totalWidth > 0) {
            [self.resultsSplitView setPosition:totalWidth * 0.35 ofDividerAtIndex:0];
        }
    });
    
    NSTabViewItem *resultsTab = [[NSTabViewItem alloc] initWithIdentifier:@"results"];
    resultsTab.label = @"Results";
    resultsTab.view = resultsView;
    [self.tabView addTabViewItem:resultsTab];
}

- (NSView *)setupResultsSymbolsView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 800)];
    
    // Header
    self.symbolsHeaderLabel = [NSTextField labelWithString:@"Select a model"];
    self.symbolsHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolsHeaderLabel.font = [NSFont boldSystemFontOfSize:13];
    [view addSubview:self.symbolsHeaderLabel];
    
    // Table view
    self.resultsSymbolsTableView = [[NSTableView alloc] init];
    self.resultsSymbolsTableView.delegate = self;
    self.resultsSymbolsTableView.dataSource = self;
    self.resultsSymbolsTableView.allowsMultipleSelection = YES;
    self.resultsSymbolsTableView.usesAlternatingRowBackgroundColors = YES;
    
    // ✅ NUOVA COLONNA: Checkbox
    NSTableColumn *selectCol = [[NSTableColumn alloc] initWithIdentifier:@"select"];
    selectCol.title = @"✓";
    selectCol.width = 30;
    [self.resultsSymbolsTableView addTableColumn:selectCol];
    
    // Column
    NSTableColumn *symbolCol = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolCol.title = @"Symbol";
    symbolCol.width = 100;
    [self.resultsSymbolsTableView addTableColumn:symbolCol];
    
    self.resultsSymbolsScrollView = [[NSScrollView alloc] init];
    self.resultsSymbolsScrollView.documentView = self.resultsSymbolsTableView;
    self.resultsSymbolsScrollView.hasVerticalScroller = YES;
    self.resultsSymbolsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.resultsSymbolsScrollView];
    
    // Buttons
    self.sendSelectedButton = [NSButton buttonWithTitle:@"Send Selected to Chain"
                                                 target:self
                                                 action:@selector(sendSelectedSymbolsToChain:)];
    self.sendSelectedButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.sendSelectedButton.enabled = NO;
    [view addSubview:self.sendSelectedButton];
    
    self.sendAllButton = [NSButton buttonWithTitle:@"Send All to Chain"
                                            target:self
                                            action:@selector(sendAllSymbolsToChain:)];
    self.sendAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.sendAllButton.enabled = NO;
    [view addSubview:self.sendAllButton];
    
    // Layout (invariato)
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolsHeaderLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:5],
        [self.symbolsHeaderLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:5],
        
        [self.resultsSymbolsScrollView.topAnchor constraintEqualToAnchor:self.symbolsHeaderLabel.bottomAnchor constant:5],
        [self.resultsSymbolsScrollView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.resultsSymbolsScrollView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [self.resultsSymbolsScrollView.bottomAnchor constraintEqualToAnchor:self.sendSelectedButton.topAnchor constant:-10],
        
        [self.sendSelectedButton.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:5],
        [self.sendSelectedButton.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-5],
        
        [self.sendAllButton.leadingAnchor constraintEqualToAnchor:self.sendSelectedButton.trailingAnchor constant:10],
        [self.sendAllButton.centerYAnchor constraintEqualToAnchor:self.sendSelectedButton.centerYAnchor]
    ]];
    
    return view;
}


- (NSView *)setupResultsModelsView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 250, 800)];
    
    // Header
    NSTextField *label = [NSTextField labelWithString:@"Models Results"];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [NSFont boldSystemFontOfSize:13];
    [view addSubview:label];
    
    // Table view
    self.resultsModelsTableView = [[NSTableView alloc] init];
    self.resultsModelsTableView.delegate = self;
    self.resultsModelsTableView.dataSource = self;
    self.resultsModelsTableView.allowsMultipleSelection = NO;
    self.resultsModelsTableView.usesAlternatingRowBackgroundColors = YES;
    
    // Columns
    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"model"];
    nameCol.title = @"Model";
    nameCol.width = 150;
    [self.resultsModelsTableView addTableColumn:nameCol];
    
    NSTableColumn *countCol = [[NSTableColumn alloc] initWithIdentifier:@"count"];
    countCol.title = @"Symbols";
    countCol.width = 70;
    [self.resultsModelsTableView addTableColumn:countCol];
    
    NSTableColumn *timeCol = [[NSTableColumn alloc] initWithIdentifier:@"time"];
    timeCol.title = @"Time";
    timeCol.width = 80;
    [self.resultsModelsTableView addTableColumn:timeCol];
    
    self.resultsModelsScrollView = [[NSScrollView alloc] init];
    self.resultsModelsScrollView.documentView = self.resultsModelsTableView;
    self.resultsModelsScrollView.hasVerticalScroller = YES;
    self.resultsModelsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.resultsModelsScrollView];
    
    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:view.topAnchor constant:5],
        [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:5],
        
        [self.resultsModelsScrollView.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:5],
        [self.resultsModelsScrollView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.resultsModelsScrollView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [self.resultsModelsScrollView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];
    
    return view;
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
    
    NSString *savedPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"StooqDataDirectory"];
    if (savedPath) {
        self.dataPathField.stringValue = savedPath;
        [self setDataDirectory:savedPath];
    }
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
    
    // RESULTS MODELS TABLE
    if (tableView == self.resultsModelsTableView) {
        return self.executionResults.count;
    }
    
    // ✅ RESULTS SYMBOLS TABLE - AGGIUNGI QUESTO
    if (tableView == self.resultsSymbolsTableView) {
        return self.selectedModelSymbols ? self.selectedModelSymbols.count : 0;
    }
    
    // ARCHIVE TABLE
    if (tableView == self.archiveTableView) {
        return self.archivedResults.count;
    }
    
    // ARCHIVE SYMBOLS TABLE
    if (tableView == self.archiveSymbolsTableView) {
        if (!self.selectedArchiveEntry) {
            return 0;
        }
        NSDictionary *symbols = self.selectedArchiveEntry[@"symbols"];
        return symbols.count;
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
    
    // RESULTS MODELS TABLE
    else if (tableView == self.resultsModelsTableView) {
        NSArray *keys = [self.executionResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
        NSString *modelID = keys[row];
        ModelResult *result = self.executionResults[modelID];
        
        if ([tableColumn.identifier isEqualToString:@"model"]) {
            textField.stringValue = result.modelName;
        } else if ([tableColumn.identifier isEqualToString:@"count"]) {
            textField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)result.finalSymbols.count];
            textField.alignment = NSTextAlignmentCenter;
        } else if ([tableColumn.identifier isEqualToString:@"time"]) {
            textField.stringValue = [NSString stringWithFormat:@"%.2fs", result.totalExecutionTime];
            textField.alignment = NSTextAlignmentCenter;
        }
    }
    
    // RESULTS SYMBOLS TABLE
    else if (tableView == self.resultsSymbolsTableView) {
        if (row < self.selectedModelSymbols.count) {
            NSString *symbol = self.selectedModelSymbols[row];
            
            if ([tableColumn.identifier isEqualToString:@"select"]) {
                NSButton *checkbox = [[NSButton alloc] init];
                [checkbox setButtonType:NSButtonTypeSwitch];
                checkbox.title = @"";
                checkbox.tag = row;
                checkbox.target = self;
                checkbox.action = @selector(symbolCheckboxToggled:);
                
                BOOL isSelected = [self.selectedSymbols containsObject:symbol];
                checkbox.state = isSelected ? NSControlStateValueOn : NSControlStateValueOff;
                
                return checkbox;
            }
            else if ([tableColumn.identifier isEqualToString:@"symbol"]) {
                textField.stringValue = symbol;
            }
        }
    }
    
    // ✅ ARCHIVE TABLE
    else if (tableView == self.archiveTableView) {
        if (row < self.archivedResults.count) {
            NSDictionary *entry = self.archivedResults[row];
            
            if ([tableColumn.identifier isEqualToString:@"archive_date"]) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateStyle = NSDateFormatterMediumStyle;
                formatter.timeStyle = NSDateFormatterShortStyle;
                textField.stringValue = [formatter stringFromDate:entry[@"date"]];
            } else if ([tableColumn.identifier isEqualToString:@"archive_model"]) {
                textField.stringValue = entry[@"modelName"];
            } else if ([tableColumn.identifier isEqualToString:@"archive_count"]) {
                NSDictionary *symbols = entry[@"symbols"];
                textField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)symbols.count];
            }
        }
    }
    
    // ✅ ARCHIVE SYMBOLS TABLE
    // ARCHIVE SYMBOLS TABLE
    else if (tableView == self.archiveSymbolsTableView) {
        if (self.selectedArchiveEntry) {
            NSDictionary *symbolsWithPrices = self.selectedArchiveEntry[@"symbols"];
            NSArray *symbols = [symbolsWithPrices.allKeys sortedArrayUsingSelector:@selector(compare:)];
            
            if (row < symbols.count) {
                NSString *symbol = symbols[row];
                double signalPrice = [symbolsWithPrices[symbol] doubleValue];
                
                if ([tableColumn.identifier isEqualToString:@"archive_symbol"]) {
                    textField.stringValue = symbol;
                } else if ([tableColumn.identifier isEqualToString:@"signal_price"]) {
                    textField.stringValue = [NSString stringWithFormat:@"%.2f", signalPrice];
                } else if ([tableColumn.identifier isEqualToString:@"current_price"]) {
                    // Mostra "--" inizialmente, verrà aggiornato dopo la batch request
                    textField.stringValue = @"--";
                } else if ([tableColumn.identifier isEqualToString:@"var_percent"]) {
                    textField.stringValue = @"--";
                }
            }
        }
    }
    return textField;
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
    else if (tableView == self.resultsModelsTableView) {
          NSInteger selectedRow = self.resultsModelsTableView.selectedRow;
          
          if (selectedRow >= 0) {
              NSArray *keys = [self.executionResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
              NSString *modelID = keys[selectedRow];
              ModelResult *result = self.executionResults[modelID];
              
              // Update state
              self.selectedResultModelID = modelID;
              self.currentModelSymbols = result.finalSymbols;
              
              // Update UI
              self.symbolsHeaderLabel.stringValue = [NSString stringWithFormat:@"Symbols from: %@ (%lu)",
                                                     result.modelName,
                                                     (unsigned long)result.finalSymbols.count];
              
              [self.resultsSymbolsTableView reloadData];
              [self.resultsSymbolsTableView deselectAll:nil];
              
              // Enable "Send All" button
              self.sendAllButton.enabled = (result.finalSymbols.count > 0);
              self.sendSelectedButton.enabled = NO;
              
              NSLog(@"📊 Selected model: %@ with %lu symbols", result.modelName, (unsigned long)result.finalSymbols.count);
          } else {
              [self clearSymbolsSelection];
          }
      }
      
      // RESULTS SYMBOLS TABLE
    else if (tableView == self.resultsSymbolsTableView) {
           NSInteger selectedRow = self.resultsSymbolsTableView.selectedRow;
           NSIndexSet *selectedRows = self.resultsSymbolsTableView.selectedRowIndexes;
           
           if (selectedRow >= 0 && selectedRow < self.currentModelSymbols.count) {
               NSString *symbol = self.currentModelSymbols[selectedRow];
               
               // ✅ INVIO IMMEDIATO ALLA CHAIN (usa simbolo pulito senza .us)
               NSString *cleanedSymbol = [self cleanSymbol:symbol];
               [self sendSymbolToChain:cleanedSymbol];
               
               // Feedback
               [self showChainFeedback:[NSString stringWithFormat:@"Sent %@ to chain", cleanedSymbol]];
               
               NSLog(@"🔗 Sent symbol to chain: %@", cleanedSymbol);
           }
          
          // Update button state
          self.sendSelectedButton.enabled = (selectedRows.count > 0);
          
          // Update button title with count
          if (selectedRows.count > 0) {
              self.sendSelectedButton.title = [NSString stringWithFormat:@"Send Selected to Chain (%lu)",
                                               (unsigned long)selectedRows.count];
          } else {
              self.sendSelectedButton.title = @"Send Selected to Chain";
          }
      }
    // ARCHIVE TABLE SELECTION (NUOVO)

    else if (tableView == self.archiveTableView) {
        NSInteger selectedRow = tableView.selectedRow;
        
        if (selectedRow >= 0) {
            self.selectedArchiveEntry = self.archivedResults[selectedRow];
            self.deleteArchiveButton.enabled = YES;
            
            NSString *modelName = self.selectedArchiveEntry[@"modelName"];
            self.archiveHeaderLabel.stringValue = [NSString stringWithFormat:@"Symbols from: %@", modelName];
            
            // Batch request - DataHub gestisce cache/freshness
            NSDictionary *symbolsWithPrices = self.selectedArchiveEntry[@"symbols"];
            NSArray *symbols = symbolsWithPrices.allKeys;
            
            if (symbols.count > 0) {
                [[DataHub shared] getQuotesForSymbols:symbols
                                              completion:^(NSDictionary<NSString *, MarketQuoteModel *> *quotes, BOOL allLive) {
                    // I prezzi sono ora disponibili, reload della tabella per mostrarli
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.archiveSymbolsTableView reloadData];
                    });
                }];
            }
            
            [self.archiveSymbolsTableView reloadData];
        }
    }
}

- (void)sendSelectedSymbolsToChain:(id)sender {
    NSIndexSet *selectedRows = self.resultsSymbolsTableView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray *selectedSymbols = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.currentModelSymbols.count) {
            // ✅ RIMUOVE .us prima di inviare
            NSString *cleanedSymbol = [self cleanSymbol:self.currentModelSymbols[idx]];
            [selectedSymbols addObject:cleanedSymbol];
        }
    }];
    
    if (selectedSymbols.count > 0) {
        // ✅ USA METODO BASEWIDGET
        [self sendSymbolsToChain:selectedSymbols];
        
        // Feedback
        NSString *message = [NSString stringWithFormat:@"Sent %lu symbols to chain",
                            (unsigned long)selectedSymbols.count];
        [self showChainFeedback:message];
        
        NSLog(@"🔗 Sent %lu symbols to chain: %@", (unsigned long)selectedSymbols.count, selectedSymbols);
    }
}

- (void)sendAllSymbolsToChain:(id)sender {
    if (!self.currentModelSymbols || self.currentModelSymbols.count == 0) return;
    
    // ✅ RIMUOVE .us da tutti i simboli prima di inviare
    NSArray<NSString *> *cleanedSymbols = [self cleanSymbols:self.currentModelSymbols];
    [self sendSymbolsToChain:cleanedSymbols];
    // Feedback
    NSString *message = [NSString stringWithFormat:@"Sent all %lu symbols to chain",
                        (unsigned long)self.currentModelSymbols.count];
    [self showChainFeedback:message];
    
    NSLog(@"🔗 Sent all %lu symbols to chain", (unsigned long)self.currentModelSymbols.count);
}

- (void)clearSymbolsSelection {
    self.selectedResultModelID = nil;
    self.currentModelSymbols = nil;
    self.symbolsHeaderLabel.stringValue = @"Select a model";
    [self.resultsSymbolsTableView reloadData];
    self.sendSelectedButton.enabled = NO;
    self.sendAllButton.enabled = NO;
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

- (void)clearResults:(id)sender {
    [self.executionResults removeAllObjects];
    [self.resultsModelsTableView reloadData];
    [self clearSymbolsSelection];
    self.resultsStatusLabel.stringValue = @"No results";
}


#pragma mark - ScreenerBatchRunnerDelegate

- (void)batchRunnerDidStart:(ScreenerBatchRunner *)runner {
    self.resultsStatusLabel.stringValue = @"Starting...";
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didStartLoadingDataForSymbols:(NSInteger)symbolCount {
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Loading %ld symbols...", (long)symbolCount];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishLoadingData:(NSDictionary *)cache {
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Data loaded: %lu symbols", (unsigned long)cache.count];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didStartModel:(ScreenerModel *)model {
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Executing: %@", model.displayName];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishModel:(ModelResult *)result {
    self.executionResults[result.modelID] = result;
    [self.resultsModelsTableView reloadData];
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Completed: %@ (%lu symbols)",
                                           result.modelName,
                                           (unsigned long)result.finalSymbols.count];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishWithResults:(NSDictionary<NSString *,ModelResult *> *)results {
    NSInteger totalSymbols = 0;
    for (ModelResult *result in results.allValues) {
        totalSymbols += result.finalSymbols.count;
    }
    
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Complete: %lu models, %ld symbols",
                                           (unsigned long)results.count, (long)totalSymbols];
    
    [self.tabView selectTabViewItemAtIndex:1];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Execution Complete";
    alert.informativeText = [NSString stringWithFormat:@"Executed %lu models.\nTotal symbols: %ld",
                            (unsigned long)results.count, (long)totalSymbols];
    [alert runModal];
    [self saveCurrentResultsToArchive];  // ✅ Salva in archivio
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
    // Restituisce i simboli selezionati nella tabella simboli
    NSMutableArray *selected = [NSMutableArray array];
    NSIndexSet *selectedRows = self.resultsSymbolsTableView.selectedRowIndexes;
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.currentModelSymbols.count) {
            [selected addObject:self.currentModelSymbols[idx]];
        }
    }];
    
    return [selected copy];
}

- (NSArray<NSString *> *)contextualSymbols {
    // Tutti i simboli del modello correntemente selezionato
    if (self.currentModelSymbols && self.currentModelSymbols.count > 0) {
        return self.currentModelSymbols;
    }
    return @[];
}

- (NSString *)contextMenuTitle {
    NSArray<NSString *> *selected = [self selectedSymbols];
    
    if (selected.count == 1) {
        return selected[0];
    } else if (selected.count > 1) {
        return [NSString stringWithFormat:@"Selection (%lu)", (unsigned long)selected.count];
    } else if (self.selectedResultModelID) {
        ModelResult *result = self.executionResults[self.selectedResultModelID];
        return [NSString stringWithFormat:@"%@ (%lu symbols)",
                result.modelName,
                (unsigned long)result.finalSymbols.count];
    }
    
    return @"Stooq Screener";
}

- (NSString *)cleanSymbol:(NSString *)symbol {
    // Rimuove il suffisso .us dai simboli Stooq
    if ([symbol hasSuffix:@".US"]) {
        return [symbol substringToIndex:symbol.length - 3];
    }
    return symbol;
}

- (NSArray<NSString *> *)cleanSymbols:(NSArray<NSString *> *)symbols {
    NSMutableArray *cleaned = [NSMutableArray arrayWithCapacity:symbols.count];
    for (NSString *symbol in symbols) {
        [cleaned addObject:[self cleanSymbol:symbol]];
    }
    return [cleaned copy];
}

#pragma mark - Symbol Selection

- (void)symbolCheckboxToggled:(NSButton *)sender {
    NSInteger row = sender.tag;
    NSArray *keys = [self.executionResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSString *modelID = keys[row];
    ModelResult *result = self.executionResults[modelID];
    
    if (sender.state == NSControlStateValueOn) {
        // Aggiungi tutti i simboli di questo modello
        [self.selectedSymbolsForReport addObjectsFromArray:result.finalSymbols];
    } else {
        // Rimuovi tutti i simboli di questo modello
        for (NSString *symbol in result.finalSymbols) {
            [self.selectedSymbolsForReport removeObject:symbol];
        }
    }
    
    NSLog(@"Selected symbols count: %lu", (unsigned long)self.selectedSymbols.count);
}

- (void)generateReport:(id)sender {
    if (self.selectedSymbols.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No symbols selected";
        alert.informativeText = @"Please select at least one model to include in the report.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Chiedi dove salvare il report
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"txt"];
    savePanel.nameFieldStringValue = [NSString stringWithFormat:@"Screener_Report_%@.txt",
                                      [[NSDate date] descriptionWithLocale:nil]];
    
    [savePanel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            [self saveReportToURL:savePanel.URL];
        }
    }];
}

- (void)saveReportToURL:(NSURL *)url {
    NSMutableString *report = [NSMutableString string];
    
    // Header
    [report appendString:@"SCREENER REPORT\n"];
    [report appendString:@"===============\n\n"];
    [report appendFormat:@"Generated: %@\n\n", [[NSDate date] description]];
    
    // Per ogni modello con simboli selezionati
    NSArray *keys = [self.executionResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *modelID in keys) {
        ModelResult *result = self.executionResults[modelID];
        
        // Trova simboli selezionati per questo modello
        NSMutableArray *selectedForModel = [NSMutableArray array];
        for (NSString *symbol in result.finalSymbols) {
            if ([self.selectedSymbols containsObject:symbol]) {
                [selectedForModel addObject:symbol];
            }
        }
        
        if (selectedForModel.count > 0) {
            [report appendFormat:@"MODEL: %@\n", result.modelName];
            [report appendFormat:@"Execution Time: %.2fs\n", result.totalExecutionTime];
            [report appendFormat:@"Selected Symbols: %@\n\n", [selectedForModel componentsJoinedByString:@", "]];
        }
    }
    
    // Salva il file
    NSError *error;
    BOOL success = [report writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (success) {
        NSLog(@"Report saved successfully to %@", url.path);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Report Generated";
        alert.informativeText = [NSString stringWithFormat:@"Report saved with %lu symbols", (unsigned long)self.selectedSymbols.count];
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    } else {
        NSLog(@"Error saving report: %@", error.localizedDescription);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Error Saving Report";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleCritical;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}


#pragma mark - Archive Management

- (void)saveCurrentResultsToArchive {
    if (self.executionResults.count == 0) return;
    
    NSDate *now = [NSDate date];
    
    for (NSString *modelID in self.executionResults.allKeys) {
        ModelResult *result = self.executionResults[modelID];
        
        // Salva prezzo corrente per ogni simbolo
        NSMutableDictionary *symbolsWithPrices = [NSMutableDictionary dictionary];
        for (NSString *symbol in result.finalSymbols) {
            // ✅ CORRETTO: usa loadBarsForSymbol:minBars:
            NSArray<HistoricalBarModel *> *bars = [self.dataManager loadBarsForSymbol:symbol minBars:1];
            if (bars.count > 0) {
                HistoricalBarModel *lastBar = bars[bars.count - 1];
                symbolsWithPrices[symbol] = @(lastBar.close);
            } else {
                symbolsWithPrices[symbol] = @(0.0);
            }
        }
        
        NSDictionary *archiveEntry = @{
            @"date": now,
            @"modelName": result.modelName,
            @"modelID": modelID,
            @"symbols": symbolsWithPrices,
            @"executionTime": @(result.totalExecutionTime)
        };
        
        [self.archivedResults addObject:archiveEntry];
    }
    
    [self persistArchivedResults];
    [self.archiveTableView reloadData];
    
    NSLog(@"📦 Archived %lu model results", (unsigned long)self.executionResults.count);
}

- (void)loadArchivedResults {
    NSString *archivePath = [self archiveFilePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:archivePath]) {
        NSArray *archived = [NSKeyedUnarchiver unarchiveObjectWithFile:archivePath];
        if (archived) {
            self.archivedResults = [archived mutableCopy];
        }
    }
}

- (void)persistArchivedResults {
    NSString *archivePath = [self archiveFilePath];
    [NSKeyedArchiver archiveRootObject:self.archivedResults toFile:archivePath];
}

- (NSString *)archiveFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportDir = paths[0];
    NSString *appDir = [appSupportDir stringByAppendingPathComponent:@"TradingApp"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:appDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    return [appDir stringByAppendingPathComponent:@"screener_archive.dat"];
}

- (void)deleteArchiveEntry:(id)sender {
    NSInteger selectedRow = [self.archiveTableView selectedRow];
    if (selectedRow >= 0 && selectedRow < self.archivedResults.count) {
        [self.archivedResults removeObjectAtIndex:selectedRow];
        [self persistArchivedResults];
        [self.archiveTableView reloadData];
        [self.archiveSymbolsTableView reloadData];
        self.deleteArchiveButton.enabled = NO;
    }
}

- (void)exportArchive:(id)sender {
    // Implementazione simile a exportResults
}

@end

