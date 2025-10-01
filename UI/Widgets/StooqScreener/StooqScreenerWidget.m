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

@interface StooqScreenerWidget () <NSTableViewDelegate, NSTableViewDataSource, ScreenerBatchRunnerDelegate>

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
    }
    return self;
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
    [self setupSettingsTab];
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
    timeCol.title = @"Time";
    timeCol.width = 100;
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
    
    self.exportButton = [NSButton buttonWithTitle:@"Export" target:self action:@selector(exportResults:)];
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
    if (tableView == self.modelsTableView) {
        return self.models.count;
    } else if (tableView == self.screenersTableView) {
        return self.editingModel ? self.editingModel.steps.count : 0;
    } else if (tableView == self.parametersTableView) {
        if (self.selectedStep) {
            return self.selectedStep.parameters.allKeys.count;
        }
        return 0;
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
            textField.tag = row;  // Store row for later retrieval
        }
    }
    
    // RESULTS TABLE
    else if (tableView == self.resultsTableView) {
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
    [self.resultsTableView reloadData];
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
    [self.resultsTableView reloadData];
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

@end

