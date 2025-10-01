//
//  StooqScreenerWidget.m
//  TradingApp
//

#import "StooqScreenerWidget.h"
#import "ModelManager.h"
#import "StooqDataManager.h"
#import "ScreenerBatchRunner.h"
#import "ScreenerModel.h"

@interface StooqScreenerWidget () <NSTableViewDelegate, NSTableViewDataSource, ScreenerBatchRunnerDelegate>

// Managers
@property (nonatomic, strong) ModelManager *modelManager;
@property (nonatomic, strong) StooqDataManager *dataManager;
@property (nonatomic, strong) ScreenerBatchRunner *batchRunner;

// UI Components - Tabs
@property (nonatomic, strong) NSTabView *tabView;

// Tab 1: Models
@property (nonatomic, strong) NSTableView *modelsTableView;
@property (nonatomic, strong) NSScrollView *modelsScrollView;
@property (nonatomic, strong) NSButton *runButton;
@property (nonatomic, strong) NSButton *createModelButton;
@property (nonatomic, strong) NSButton *editModelButton;
@property (nonatomic, strong) NSButton *deleteModelButton;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSTextField *universeLabel;

// Tab 2: Results
@property (nonatomic, strong) NSTableView *resultsTableView;
@property (nonatomic, strong) NSScrollView *resultsScrollView;
@property (nonatomic, strong) NSButton *exportButton;
@property (nonatomic, strong) NSButton *clearResultsButton;
@property (nonatomic, strong) NSTextField *resultsStatusLabel;

// Tab 3: Settings
@property (nonatomic, strong) NSTextField *dataPathField;
@property (nonatomic, strong) NSButton *browseButton;
@property (nonatomic, strong) NSButton *scanDatabaseButton;
@property (nonatomic, strong) NSTextField *symbolCountLabel;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;

// Data
@property (nonatomic, strong) NSMutableArray<ScreenerModel *> *models;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ModelResult *> *executionResults;
@property (nonatomic, strong) NSArray<NSString *> *availableSymbols;

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
    }
    return self;
}

#pragma mark - BaseWidget Overrides

- (NSString *)widgetTitle {
    return @"Stooq Screener";
}

- (NSSize)defaultSize {
    return NSMakeSize(900, 700);
}

- (NSSize)minimumSize {
    return NSMakeSize(700, 500);
}

- (void)setupContentView {
    [super setupContentView];
    [self setupUI];
    [self loadInitialData];
}

#pragma mark - UI Setup

- (void)setupUI {
    // Create tab view
    self.tabView = [[NSTabView alloc] initWithFrame:NSZeroRect];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.tabView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [self.tabView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
        [self.tabView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10]
    ]];
    
    // Create tabs
    [self setupModelsTab];
    [self setupResultsTab];
    [self setupSettingsTab];
}

- (void)setupModelsTab {
    NSView *modelsView = [[NSView alloc] init];
    
    // Table view for models
    self.modelsTableView = [[NSTableView alloc] init];
    self.modelsTableView.delegate = self;
    self.modelsTableView.dataSource = self;
    self.modelsTableView.allowsMultipleSelection = YES;
    self.modelsTableView.usesAlternatingRowBackgroundColors = YES;
    
    // Columns
    NSTableColumn *checkCol = [[NSTableColumn alloc] initWithIdentifier:@"enabled"];
    checkCol.title = @"✓";
    checkCol.width = 30;
    [self.modelsTableView addTableColumn:checkCol];
    
    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameCol.title = @"Model Name";
    nameCol.width = 250;
    [self.modelsTableView addTableColumn:nameCol];
    
    NSTableColumn *stepsCol = [[NSTableColumn alloc] initWithIdentifier:@"steps"];
    stepsCol.title = @"Steps";
    stepsCol.width = 80;
    [self.modelsTableView addTableColumn:stepsCol];
    
    NSTableColumn *descCol = [[NSTableColumn alloc] initWithIdentifier:@"description"];
    descCol.title = @"Description";
    descCol.width = 300;
    [self.modelsTableView addTableColumn:descCol];
    
    self.modelsScrollView = [[NSScrollView alloc] init];
    self.modelsScrollView.documentView = self.modelsTableView;
    self.modelsScrollView.hasVerticalScroller = YES;
    self.modelsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [modelsView addSubview:self.modelsScrollView];
    
    // Buttons
    self.runButton = [NSButton buttonWithTitle:@"Run Selected Models" target:self action:@selector(runSelectedModels)];
    self.runButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.runButton.bezelStyle = NSBezelStyleRounded;
    [modelsView addSubview:self.runButton];
    
    self.createModelButton = [NSButton buttonWithTitle:@"New Model" target:self action:@selector(createNewModel:)];
    self.createModelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [modelsView addSubview:self.createModelButton];
    
    self.editModelButton = [NSButton buttonWithTitle:@"Edit" target:self action:@selector(editModel:)];
    self.editModelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [modelsView addSubview:self.editModelButton];
    
    self.deleteModelButton = [NSButton buttonWithTitle:@"Delete" target:self action:@selector(deleteModel:)];
    self.deleteModelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [modelsView addSubview:self.deleteModelButton];
    
    self.refreshButton = [NSButton buttonWithTitle:@"Refresh" target:self action:@selector(refreshModels)];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [modelsView addSubview:self.refreshButton];
    
    // Universe info
    self.universeLabel = [[NSTextField alloc] init];
    self.universeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.universeLabel.editable = NO;
    self.universeLabel.bordered = NO;
    self.universeLabel.backgroundColor = [NSColor clearColor];
    self.universeLabel.stringValue = @"Universe: -- symbols";
    [modelsView addSubview:self.universeLabel];
    
    // Progress indicator
    self.progressIndicator = [[NSProgressIndicator alloc] init];
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressIndicator.style = NSProgressIndicatorStyleBar;
    self.progressIndicator.indeterminate = NO;
    self.progressIndicator.minValue = 0.0;
    self.progressIndicator.maxValue = 1.0;
    self.progressIndicator.hidden = YES;
    [modelsView addSubview:self.progressIndicator];
    
    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [self.modelsScrollView.topAnchor constraintEqualToAnchor:modelsView.topAnchor constant:10],
        [self.modelsScrollView.leadingAnchor constraintEqualToAnchor:modelsView.leadingAnchor constant:10],
        [self.modelsScrollView.trailingAnchor constraintEqualToAnchor:modelsView.trailingAnchor constant:-10],
        [self.modelsScrollView.bottomAnchor constraintEqualToAnchor:self.runButton.topAnchor constant:-10],
        
        [self.runButton.leadingAnchor constraintEqualToAnchor:modelsView.leadingAnchor constant:10],
        [self.runButton.bottomAnchor constraintEqualToAnchor:modelsView.bottomAnchor constant:-10],
        [self.runButton.widthAnchor constraintEqualToConstant:180],
        
        [self.createModelButton.leadingAnchor constraintEqualToAnchor:self.runButton.trailingAnchor constant:10],
        [self.createModelButton.centerYAnchor constraintEqualToAnchor:self.runButton.centerYAnchor],
        
        [self.editModelButton.leadingAnchor constraintEqualToAnchor:self.createModelButton.trailingAnchor constant:10],
        [self.editModelButton.centerYAnchor constraintEqualToAnchor:self.runButton.centerYAnchor],
        
        [self.deleteModelButton.leadingAnchor constraintEqualToAnchor:self.editModelButton.trailingAnchor constant:10],
        [self.deleteModelButton.centerYAnchor constraintEqualToAnchor:self.runButton.centerYAnchor],
        
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.deleteModelButton.trailingAnchor constant:10],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.runButton.centerYAnchor],
        
        [self.universeLabel.trailingAnchor constraintEqualToAnchor:modelsView.trailingAnchor constant:-10],
        [self.universeLabel.centerYAnchor constraintEqualToAnchor:self.runButton.centerYAnchor],
        
        [self.progressIndicator.leadingAnchor constraintEqualToAnchor:modelsView.leadingAnchor constant:10],
        [self.progressIndicator.trailingAnchor constraintEqualToAnchor:modelsView.trailingAnchor constant:-10],
        [self.progressIndicator.bottomAnchor constraintEqualToAnchor:self.runButton.topAnchor constant:-5],
        [self.progressIndicator.heightAnchor constraintEqualToConstant:20]
    ]];
    
    NSTabViewItem *modelsTab = [[NSTabViewItem alloc] initWithIdentifier:@"models"];
    modelsTab.label = @"Models";
    modelsTab.view = modelsView;
    [self.tabView addTabViewItem:modelsTab];
}

- (void)setupResultsTab {
    NSView *resultsView = [[NSView alloc] init];
    
    // Table view for results
    self.resultsTableView = [[NSTableView alloc] init];
    self.resultsTableView.delegate = self;
    self.resultsTableView.dataSource = self;
    self.resultsTableView.usesAlternatingRowBackgroundColors = YES;
    
    NSTableColumn *modelCol = [[NSTableColumn alloc] initWithIdentifier:@"model"];
    modelCol.title = @"Model";
    modelCol.width = 200;
    [self.resultsTableView addTableColumn:modelCol];
    
    NSTableColumn *countCol = [[NSTableColumn alloc] initWithIdentifier:@"count"];
    countCol.title = @"Results";
    countCol.width = 80;
    [self.resultsTableView addTableColumn:countCol];
    
    NSTableColumn *timeCol = [[NSTableColumn alloc] initWithIdentifier:@"time"];
    timeCol.title = @"Execution Time";
    timeCol.width = 120;
    [self.resultsTableView addTableColumn:timeCol];
    
    NSTableColumn *symbolsCol = [[NSTableColumn alloc] initWithIdentifier:@"symbols"];
    symbolsCol.title = @"Symbols";
    symbolsCol.width = 400;
    [self.resultsTableView addTableColumn:symbolsCol];
    
    self.resultsScrollView = [[NSScrollView alloc] init];
    self.resultsScrollView.documentView = self.resultsTableView;
    self.resultsScrollView.hasVerticalScroller = YES;
    self.resultsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [resultsView addSubview:self.resultsScrollView];
    
    // Buttons
    self.exportButton = [NSButton buttonWithTitle:@"Export Results" target:self action:@selector(exportResults:)];
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    [resultsView addSubview:self.exportButton];
    
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
    
    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [self.resultsScrollView.topAnchor constraintEqualToAnchor:resultsView.topAnchor constant:10],
        [self.resultsScrollView.leadingAnchor constraintEqualToAnchor:resultsView.leadingAnchor constant:10],
        [self.resultsScrollView.trailingAnchor constraintEqualToAnchor:resultsView.trailingAnchor constant:-10],
        [self.resultsScrollView.bottomAnchor constraintEqualToAnchor:self.exportButton.topAnchor constant:-10],
        
        [self.exportButton.leadingAnchor constraintEqualToAnchor:resultsView.leadingAnchor constant:10],
        [self.exportButton.bottomAnchor constraintEqualToAnchor:resultsView.bottomAnchor constant:-10],
        
        [self.clearResultsButton.leadingAnchor constraintEqualToAnchor:self.exportButton.trailingAnchor constant:10],
        [self.clearResultsButton.centerYAnchor constraintEqualToAnchor:self.exportButton.centerYAnchor],
        
        [self.resultsStatusLabel.trailingAnchor constraintEqualToAnchor:resultsView.trailingAnchor constant:-10],
        [self.resultsStatusLabel.centerYAnchor constraintEqualToAnchor:self.exportButton.centerYAnchor]
    ]];
    
    NSTabViewItem *resultsTab = [[NSTabViewItem alloc] initWithIdentifier:@"results"];
    resultsTab.label = @"Results";
    resultsTab.view = resultsView;
    [self.tabView addTabViewItem:resultsTab];
}

- (void)setupSettingsTab {
    NSView *settingsView = [[NSView alloc] init];
    
    // Data path
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
    
    // Layout
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

#pragma mark - Data Loading

- (void)loadInitialData {
    // Load models
    [self refreshModels];
    
    // Load saved data path
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
    
    // Save to preferences
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:@"StooqDataDirectory"];
    
    // Create data manager
    self.dataManager = [[StooqDataManager alloc] initWithDataDirectory:path];
    self.dataManager.selectedExchanges = self.selectedExchanges;
    
    // Create batch runner
    self.batchRunner = [[ScreenerBatchRunner alloc] initWithDataManager:self.dataManager];
    self.batchRunner.delegate = self;
    
    NSLog(@"✅ Data directory set: %@", path);
}

#pragma mark - Actions

- (void)runSelectedModels {
    if (!self.dataManager) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Data Directory";
        alert.informativeText = @"Please set the Stooq data directory in Settings tab";
        [alert runModal];
        return;
    }
    
    // Get selected models
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
    
    // Show progress
    self.progressIndicator.hidden = NO;
    self.progressIndicator.doubleValue = 0.0;
    self.runButton.enabled = NO;
    
    // Execute
    [self.batchRunner executeModels:selectedModels
                           universe:nil
                         completion:^(NSDictionary<NSString *,ModelResult *> *results, NSError *error) {
        
        if (error) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Execution Failed";
            alert.informativeText = error.localizedDescription;
            [alert runModal];
        } else {
            NSLog(@"✅ Batch complete: %lu results", (unsigned long)results.count);
        }
        
        self.progressIndicator.hidden = YES;
        self.runButton.enabled = YES;
    }];
}

- (void)cancelExecution {
    [self.batchRunner cancel];
}

- (void)createNewModel:(id)sender {
    // TODO: Show model editor dialog
    NSLog(@"TODO: Create new model");
}

- (void)editModel:(id)sender {
    // TODO: Show model editor for selected model
    NSLog(@"TODO: Edit model");
}

- (void)deleteModel:(id)sender {
    NSInteger selectedRow = [self.modelsTableView selectedRow];
    if (selectedRow < 0) return;
    
    ScreenerModel *model = self.models[selectedRow];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Model";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?", model.displayName];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSError *error;
        [self.modelManager deleteModel:model.modelID error:&error];
        [self refreshModels];
    }
}

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
    // TODO: Export results to CSV
    NSLog(@"TODO: Export results");
}

- (void)clearResults:(id)sender {
    [self.executionResults removeAllObjects];
    [self.resultsTableView reloadData];
    self.resultsStatusLabel.stringValue = @"No results";
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.modelsTableView) {
        return self.models.count;
    } else if (tableView == self.resultsTableView) {
        return self.executionResults.count;
    }
    return 0;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.editable = NO;
    textField.bordered = NO;
    textField.backgroundColor = [NSColor clearColor];
    
    if (tableView == self.modelsTableView) {
        ScreenerModel *model = self.models[row];
        
        if ([tableColumn.identifier isEqualToString:@"enabled"]) {
            textField.stringValue = model.isEnabled ? @"✓" : @"";
        } else if ([tableColumn.identifier isEqualToString:@"name"]) {
            textField.stringValue = model.displayName;
        } else if ([tableColumn.identifier isEqualToString:@"steps"]) {
            textField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)model.steps.count];
        } else if ([tableColumn.identifier isEqualToString:@"description"]) {
            textField.stringValue = model.modelDescription ?: @"";
        }
        
    } else if (tableView == self.resultsTableView) {
        NSArray *keys = [self.executionResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
        NSString *modelID = keys[row];
        ModelResult *result = self.executionResults[modelID];
        
        if ([tableColumn.identifier isEqualToString:@"model"]) {
            textField.stringValue = result.modelName;
        } else if ([tableColumn.identifier isEqualToString:@"count"]) {
            textField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)result.finalSymbols.count];
        } else if ([tableColumn.identifier isEqualToString:@"time"]) {
            textField.stringValue = [NSString stringWithFormat:@"%.2fs", result.totalExecutionTime];
        } else if ([tableColumn.identifier isEqualToString:@"symbols"]) {
            // Show first 10 symbols
            NSArray *firstSymbols = [result.finalSymbols subarrayWithRange:NSMakeRange(0, MIN(10, result.finalSymbols.count))];
            NSString *symbolsString = [firstSymbols componentsJoinedByString:@", "];
            if (result.finalSymbols.count > 10) {
                symbolsString = [symbolsString stringByAppendingFormat:@", ... (%lu more)", (unsigned long)(result.finalSymbols.count - 10)];
            }
            textField.stringValue = symbolsString;
        }
    }
    
    return textField;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = notification.object;
    
    if (tableView == self.modelsTableView) {
        BOOL hasSelection = [self.modelsTableView selectedRow] >= 0;
        self.editModelButton.enabled = hasSelection;
        self.deleteModelButton.enabled = hasSelection;
        self.runButton.enabled = hasSelection;
    }
}

#pragma mark - ScreenerBatchRunnerDelegate

- (void)batchRunnerDidStart:(ScreenerBatchRunner *)runner {
    NSLog(@"🚀 Batch runner started");
    self.resultsStatusLabel.stringValue = @"Execution started...";
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didStartLoadingDataForSymbols:(NSInteger)symbolCount {
    NSLog(@"📥 Loading data for %ld symbols", (long)symbolCount);
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Loading data for %ld symbols...", (long)symbolCount];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishLoadingData:(NSDictionary *)cache {
    NSLog(@"✅ Data loaded: %lu symbols", (unsigned long)cache.count);
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Data loaded: %lu symbols", (unsigned long)cache.count];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didStartModel:(ScreenerModel *)model {
    NSLog(@"▶️  Executing: %@", model.displayName);
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Executing: %@", model.displayName];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishModel:(ModelResult *)result {
    NSLog(@"✅ Model complete: %@ → %lu symbols", result.modelName, (unsigned long)result.finalSymbols.count);
    
    // Store result
    self.executionResults[result.modelID] = result;
    
    // Update results table
    [self.resultsTableView reloadData];
    
    // Update status
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Completed: %@ (%lu symbols)",
                                           result.modelName,
                                           (unsigned long)result.finalSymbols.count];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishWithResults:(NSDictionary<NSString *,ModelResult *> *)results {
    NSLog(@"🎉 Batch execution complete: %lu models", (unsigned long)results.count);
    
    // Calculate totals
    NSInteger totalSymbols = 0;
    for (ModelResult *result in results.allValues) {
        totalSymbols += result.finalSymbols.count;
    }
    
    self.resultsStatusLabel.stringValue = [NSString stringWithFormat:@"Complete: %lu models, %ld total symbols",
                                           (unsigned long)results.count,
                                           (long)totalSymbols];
    
    // Switch to results tab
    [self.tabView selectTabViewItemAtIndex:1];
    
    // Show alert
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Execution Complete";
    alert.informativeText = [NSString stringWithFormat:@"Successfully executed %lu models.\nTotal symbols found: %ld",
                            (unsigned long)results.count, (long)totalSymbols];
    alert.alertStyle = NSAlertStyleInformational;
    [alert runModal];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didFailWithError:(NSError *)error {
    NSLog(@"❌ Batch execution failed: %@", error.localizedDescription);
    
    self.resultsStatusLabel.stringValue = @"Execution failed";
    self.resultsStatusLabel.textColor = [NSColor redColor];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Execution Failed";
    alert.informativeText = error.localizedDescription;
    alert.alertStyle = NSAlertStyleCritical;
    [alert runModal];
}

- (void)batchRunner:(ScreenerBatchRunner *)runner didUpdateProgress:(double)progress {
    self.progressIndicator.doubleValue = progress;
}

@end
