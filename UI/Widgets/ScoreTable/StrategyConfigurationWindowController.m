//
//  StrategyConfigurationWindowController.m
//  TradingApp
//
//  Strategy Configuration Window Implementation
//

#import "StrategyConfigurationWindowController.h"
#import "StrategyManager.h"
#import "IndicatorParameterSheet.h"

// Column identifiers
static NSString * const kStrategyListColumnId = @"strategyName";
static NSString * const kIndicatorEnabledColumnId = @"enabled";
static NSString * const kIndicatorNameColumnId = @"name";
static NSString * const kIndicatorWeightColumnId = @"weight";
static NSString * const kIndicatorConfigColumnId = @"configure";

@interface StrategyConfigurationWindowController ()
@property (nonatomic, strong) NSMutableArray<IndicatorConfig *> *workingIndicators; // Copy for editing
@property (nonatomic, strong) IndicatorParameterSheet *currentParameterSheet; // ✅ AGGIUNTO per mantenere riferimento
@end

@implementation StrategyConfigurationWindowController

#pragma mark - Class Methods

+ (instancetype)showConfigurationWithStrategy:(nullable ScoringStrategy *)strategy
                                      delegate:(nullable id<StrategyConfigurationDelegate>)delegate {
    
    StrategyConfigurationWindowController *controller = [[StrategyConfigurationWindowController alloc] init];
    controller.delegate = delegate;
    
    if (strategy) {
        controller.selectedStrategy = strategy;
        controller.isEditingExisting = YES;
    } else {
        controller.isEditingExisting = NO;
    }
    
    [controller showWindow:nil];
    [controller.window makeKeyAndOrderFront:nil];
    
    return controller;
}

+ (NSArray<IndicatorConfig *> *)availableIndicatorTypes {
    // Return all available indicator types with default configurations
    return @[
        [[IndicatorConfig alloc] initWithType:@"DollarVolume"
                                  displayName:@"Dollar Volume"
                                       weight:16.67
                                   parameters:@{}],
        
        [[IndicatorConfig alloc] initWithType:@"AscendingLows"
                                  displayName:@"Ascending Lows"
                                       weight:16.67
                                   parameters:@{@"lookbackPeriod": @(10)}],
        
        [[IndicatorConfig alloc] initWithType:@"BearTrap"
                                  displayName:@"Bear Trap"
                                       weight:16.67
                                   parameters:@{@"supportPeriod": @(20)}],
        
        [[IndicatorConfig alloc] initWithType:@"UNR"
                                  displayName:@"UNR (Unusual News/Rally)"
                                       weight:16.67
                                   parameters:@{@"volumeThreshold": @(2.0),
                                               @"priceChangeThreshold": @(5.0)}],
        
        [[IndicatorConfig alloc] initWithType:@"PriceVsMA"
                                  displayName:@"Price vs MA"
                                       weight:16.67
                                   parameters:@{@"maType": @"EMA",
                                               @"maPeriod": @(10),
                                               @"pricePoints": @[@"close"],
                                               @"condition": @"above"}],
        
        [[IndicatorConfig alloc] initWithType:@"VolumeSpike"
                                  displayName:@"Volume Spike"
                                       weight:16.67
                                   parameters:@{@"volumeMAPeriod": @(20)}]
    ];
}

#pragma mark - Initialization

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 600)
                                                    styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskResizable)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    window.title = @"Strategy Configuration";
    [window center];
    
    self = [super initWithWindow:window];
    if (self) {
        [self loadStrategies];
        [self setupUI];
    }
    return self;
}

#pragma mark - Data Loading

- (void)loadStrategies {
    self.allStrategies = [[[StrategyManager sharedManager] allStrategies] mutableCopy];
    
    if (!self.allStrategies) {
        self.allStrategies = [NSMutableArray array];
    }
    
    // If no strategy selected and we have strategies, select first
    if (!self.selectedStrategy && self.allStrategies.count > 0) {
        self.selectedStrategy = self.allStrategies.firstObject;
    }
    
    // Load working copy of indicators
    if (self.selectedStrategy) {
        [self loadWorkingIndicatorsFromStrategy:self.selectedStrategy];
    }
}

- (void)loadWorkingIndicatorsFromStrategy:(ScoringStrategy *)strategy {
    self.workingIndicators = [NSMutableArray array];
    
    for (IndicatorConfig *indicator in strategy.indicators) {
        // Create a deep copy
        IndicatorConfig *copy = [[IndicatorConfig alloc] initWithType:indicator.indicatorType
                                                          displayName:indicator.displayName
                                                               weight:indicator.weight
                                                           parameters:[indicator.parameters copy]];
        copy.isEnabled = indicator.isEnabled;
        [self.workingIndicators addObject:copy];
    }
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *contentView = self.window.contentView;
    
    // Split view for left-right layout
    NSSplitView *splitView = [[NSSplitView alloc] init];
    splitView.translatesAutoresizingMaskIntoConstraints = NO;
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    splitView.vertical = YES;
    [contentView addSubview:splitView];
    
    // Left panel - Strategy list
    NSView *leftPanel = [self createStrategyListPanel];
    [splitView addArrangedSubview:leftPanel];
    
    // Right panel - Strategy details
    NSView *rightPanel = [self createStrategyDetailsPanel];
    [splitView addArrangedSubview:rightPanel];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [splitView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [splitView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [splitView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [splitView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
    ]];
    
    // Set split position (30% left, 70% right)
    [splitView setPosition:270 ofDividerAtIndex:0];
    
    [self updateUI];
}

#pragma mark - Left Panel (Strategy List)

- (NSView *)createStrategyListPanel {
    NSView *panel = [[NSView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    
    CGFloat padding = 10;
    
    // Title
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.stringValue = @"Strategies";
    titleLabel.font = [NSFont boldSystemFontOfSize:14];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    [panel addSubview:titleLabel];
    
    // Strategy list table
    self.strategyListScrollView = [[NSScrollView alloc] init];
    self.strategyListScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.strategyListScrollView.hasVerticalScroller = YES;
    self.strategyListScrollView.borderType = NSBezelBorder;
    
    self.strategyListTable = [[NSTableView alloc] init];
    self.strategyListTable.dataSource = self;
    self.strategyListTable.delegate = self;
    self.strategyListTable.allowsMultipleSelection = NO;
    
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:kStrategyListColumnId];
    nameColumn.title = @"Name";
    nameColumn.width = 200;
    [self.strategyListTable addTableColumn:nameColumn];
    
    self.strategyListScrollView.documentView = self.strategyListTable;
    [panel addSubview:self.strategyListScrollView];
    
    // Buttons row
    self.addStrategyButton = [[NSButton alloc] init];
    self.addStrategyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addStrategyButton setTitle:@"+ New"];
    [self.addStrategyButton setTarget:self];
    [self.addStrategyButton setAction:@selector(createNewStrategy:)];
    [self.addStrategyButton setBezelStyle:NSBezelStyleRounded];
    [panel addSubview:self.addStrategyButton];
    
    self.duplicateStrategyButton = [[NSButton alloc] init];
    self.duplicateStrategyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.duplicateStrategyButton setTitle:@"Duplicate"];
    [self.duplicateStrategyButton setTarget:self];
    [self.duplicateStrategyButton setAction:@selector(duplicateStrategy:)];
    [self.duplicateStrategyButton setBezelStyle:NSBezelStyleRounded];
    [panel addSubview:self.duplicateStrategyButton];
    
    self.deleteStrategyButton = [[NSButton alloc] init];
    self.deleteStrategyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.deleteStrategyButton setTitle:@"- Delete"];
    [self.deleteStrategyButton setTarget:self];
    [self.deleteStrategyButton setAction:@selector(deleteStrategy:)];
    [self.deleteStrategyButton setBezelStyle:NSBezelStyleRounded];
    [panel addSubview:self.deleteStrategyButton];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:padding],
        [titleLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        
        [self.strategyListScrollView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:padding],
        [self.strategyListScrollView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        [self.strategyListScrollView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-padding],
        [self.strategyListScrollView.bottomAnchor constraintEqualToAnchor:self.addStrategyButton.topAnchor constant:-padding],
        
        [self.addStrategyButton.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        [self.addStrategyButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-padding],
        [self.addStrategyButton.widthAnchor constraintEqualToConstant:70],
        
        [self.duplicateStrategyButton.leadingAnchor constraintEqualToAnchor:self.addStrategyButton.trailingAnchor constant:5],
        [self.duplicateStrategyButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-padding],
        [self.duplicateStrategyButton.widthAnchor constraintEqualToConstant:80],
        
        [self.deleteStrategyButton.leadingAnchor constraintEqualToAnchor:self.duplicateStrategyButton.trailingAnchor constant:5],
        [self.deleteStrategyButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-padding],
        [self.deleteStrategyButton.widthAnchor constraintEqualToConstant:70]
    ]];
    
    return panel;
}

#pragma mark - Right Panel (Strategy Details)

- (NSView *)createStrategyDetailsPanel {
    NSView *panel = [[NSView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    
    CGFloat padding = 10;
    
    // Strategy name field
    NSTextField *nameLabel = [[NSTextField alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.stringValue = @"Strategy Name:";
    nameLabel.editable = NO;
    nameLabel.bordered = NO;
    nameLabel.backgroundColor = [NSColor clearColor];
    [panel addSubview:nameLabel];
    
    self.strategyNameField = [[NSTextField alloc] init];
    self.strategyNameField.translatesAutoresizingMaskIntoConstraints = NO;
    self.strategyNameField.delegate = self;
    self.strategyNameField.placeholderString = @"Enter strategy name";
    [panel addSubview:self.strategyNameField];
    
    // Created/Modified labels
    self.createdLabel = [[NSTextField alloc] init];
    self.createdLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.createdLabel.editable = NO;
    self.createdLabel.bordered = NO;
    self.createdLabel.backgroundColor = [NSColor clearColor];
    self.createdLabel.font = [NSFont systemFontOfSize:11];
    self.createdLabel.textColor = [NSColor secondaryLabelColor];
    [panel addSubview:self.createdLabel];
    
    self.modifiedLabel = [[NSTextField alloc] init];
    self.modifiedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.modifiedLabel.editable = NO;
    self.modifiedLabel.bordered = NO;
    self.modifiedLabel.backgroundColor = [NSColor clearColor];
    self.modifiedLabel.font = [NSFont systemFontOfSize:11];
    self.modifiedLabel.textColor = [NSColor secondaryLabelColor];
    [panel addSubview:self.modifiedLabel];
    
    // Indicators section title
    NSTextField *indicatorsLabel = [[NSTextField alloc] init];
    indicatorsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    indicatorsLabel.stringValue = @"Indicators:";
    indicatorsLabel.font = [NSFont boldSystemFontOfSize:13];
    indicatorsLabel.editable = NO;
    indicatorsLabel.bordered = NO;
    indicatorsLabel.backgroundColor = [NSColor clearColor];
    [panel addSubview:indicatorsLabel];
    
    self.totalWeightLabel = [[NSTextField alloc] init];
    self.totalWeightLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.totalWeightLabel.editable = NO;
    self.totalWeightLabel.bordered = NO;
    self.totalWeightLabel.backgroundColor = [NSColor clearColor];
    self.totalWeightLabel.font = [NSFont systemFontOfSize:11];
    [panel addSubview:self.totalWeightLabel];
    
    // Indicator table
    self.indicatorScrollView = [[NSScrollView alloc] init];
    self.indicatorScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorScrollView.hasVerticalScroller = YES;
    self.indicatorScrollView.borderType = NSBezelBorder;
    
    self.indicatorTable = [[NSTableView alloc] init];
    self.indicatorTable.dataSource = self;
    self.indicatorTable.delegate = self;
    self.indicatorTable.allowsMultipleSelection = NO;
    
    // Enabled column (checkbox)
    NSTableColumn *enabledCol = [[NSTableColumn alloc] initWithIdentifier:kIndicatorEnabledColumnId];
    enabledCol.title = @"✓";
    enabledCol.width = 30;
    enabledCol.minWidth = 30;
    enabledCol.maxWidth = 30;
    [self.indicatorTable addTableColumn:enabledCol];
    
    // Name column
    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:kIndicatorNameColumnId];
    nameCol.title = @"Indicator";
    nameCol.width = 200;
    nameCol.minWidth = 150;
    [self.indicatorTable addTableColumn:nameCol];
    
    // Weight column
    NSTableColumn *weightCol = [[NSTableColumn alloc] initWithIdentifier:kIndicatorWeightColumnId];
    weightCol.title = @"Weight %";
    weightCol.width = 80;
    weightCol.minWidth = 60;
    [self.indicatorTable addTableColumn:weightCol];
    
    // Configure column (button)
    NSTableColumn *configCol = [[NSTableColumn alloc] initWithIdentifier:kIndicatorConfigColumnId];
    configCol.title = @"Config";
    configCol.width = 70;
    configCol.minWidth = 60;
    configCol.maxWidth = 80;
    [self.indicatorTable addTableColumn:configCol];
    
    self.indicatorScrollView.documentView = self.indicatorTable;
    [panel addSubview:self.indicatorScrollView];
    
    // Buttons row
    self.addIndicatorButton = [[NSButton alloc] init];
    self.addIndicatorButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addIndicatorButton setTitle:@"+ Add Indicator"];
    [self.addIndicatorButton setTarget:self];
    [self.addIndicatorButton setAction:@selector(addIndicator:)];
    [self.addIndicatorButton setBezelStyle:NSBezelStyleRounded];
    [panel addSubview:self.addIndicatorButton];
    
    self.normalizeWeightsButton = [[NSButton alloc] init];
    self.normalizeWeightsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.normalizeWeightsButton setTitle:@"Normalize Weights"];
    [self.normalizeWeightsButton setTarget:self];
    [self.normalizeWeightsButton setAction:@selector(normalizeWeights:)];
    [self.normalizeWeightsButton setBezelStyle:NSBezelStyleRounded];
    [panel addSubview:self.normalizeWeightsButton];
    
    // Bottom buttons
    self.cancelButton = [[NSButton alloc] init];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cancelButton setTitle:@"Cancel"];
    [self.cancelButton setTarget:self];
    [self.cancelButton setAction:@selector(cancel:)];
    [self.cancelButton setBezelStyle:NSBezelStyleRounded];
    [panel addSubview:self.cancelButton];
    
    self.saveButton = [[NSButton alloc] init];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.saveButton setTitle:@"Save"];
    [self.saveButton setTarget:self];
    [self.saveButton setAction:@selector(save:)];
    [self.saveButton setBezelStyle:NSBezelStyleRounded];
    self.saveButton.keyEquivalent = @"\r"; // Enter key
    [panel addSubview:self.saveButton];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Name field
        [nameLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:padding],
        [nameLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        [nameLabel.widthAnchor constraintEqualToConstant:110],
        
        [self.strategyNameField.centerYAnchor constraintEqualToAnchor:nameLabel.centerYAnchor],
        [self.strategyNameField.leadingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor constant:5],
        [self.strategyNameField.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-padding],
        
        // Date labels
        [self.createdLabel.topAnchor constraintEqualToAnchor:self.strategyNameField.bottomAnchor constant:5],
        [self.createdLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        
        [self.modifiedLabel.centerYAnchor constraintEqualToAnchor:self.createdLabel.centerYAnchor],
        [self.modifiedLabel.leadingAnchor constraintEqualToAnchor:self.createdLabel.trailingAnchor constant:20],
        
        // Indicators section
        [indicatorsLabel.topAnchor constraintEqualToAnchor:self.createdLabel.bottomAnchor constant:15],
        [indicatorsLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        
        [self.totalWeightLabel.centerYAnchor constraintEqualToAnchor:indicatorsLabel.centerYAnchor],
        [self.totalWeightLabel.leadingAnchor constraintEqualToAnchor:indicatorsLabel.trailingAnchor constant:10],
        
        // Indicator table
        [self.indicatorScrollView.topAnchor constraintEqualToAnchor:indicatorsLabel.bottomAnchor constant:8],
        [self.indicatorScrollView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        [self.indicatorScrollView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-padding],
        [self.indicatorScrollView.bottomAnchor constraintEqualToAnchor:self.addIndicatorButton.topAnchor constant:-padding],
        
        // Button row
        [self.addIndicatorButton.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        [self.addIndicatorButton.bottomAnchor constraintEqualToAnchor:self.cancelButton.topAnchor constant:-padding],
        
        [self.normalizeWeightsButton.leadingAnchor constraintEqualToAnchor:self.addIndicatorButton.trailingAnchor constant:10],
        [self.normalizeWeightsButton.centerYAnchor constraintEqualToAnchor:self.addIndicatorButton.centerYAnchor],
        
        // Bottom buttons
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor constant:-10],
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-padding],
        [self.cancelButton.widthAnchor constraintEqualToConstant:80],
        
        [self.saveButton.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-padding],
        [self.saveButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-padding],
        [self.saveButton.widthAnchor constraintEqualToConstant:80]
    ]];
    
    return panel;
}

#pragma mark - UI Updates

- (void)updateUI {
    [self.strategyListTable reloadData];
    [self updateStrategyDetails];
    [self updateButtonStates];
}

- (void)updateStrategyDetails {
    if (!self.selectedStrategy) {
        self.strategyNameField.stringValue = @"";
        self.createdLabel.stringValue = @"";
        self.modifiedLabel.stringValue = @"";
        self.totalWeightLabel.stringValue = @"";
        [self.indicatorTable reloadData];
        return;
    }
    
    self.strategyNameField.stringValue = self.selectedStrategy.strategyName ?: @"";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    
    self.createdLabel.stringValue = [NSString stringWithFormat:@"Created: %@",
                                     [formatter stringFromDate:self.selectedStrategy.dateCreated]];
    self.modifiedLabel.stringValue = [NSString stringWithFormat:@"Modified: %@",
                                      [formatter stringFromDate:self.selectedStrategy.dateModified]];
    
    [self updateTotalWeightLabel];
    [self.indicatorTable reloadData];
}

- (void)updateTotalWeightLabel {
    CGFloat total = 0;
    for (IndicatorConfig *indicator in self.workingIndicators) {
        if (indicator.isEnabled) {
            total += indicator.weight;
        }
    }
    
    NSColor *color = (fabs(total - 100.0) < 0.01) ? [NSColor systemGreenColor] : [NSColor systemRedColor];
    
    NSString *text = [NSString stringWithFormat:@"Total Weight: %.2f%%", total];
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:text];
    [attrString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, text.length)];
    
    self.totalWeightLabel.attributedStringValue = attrString;
}

- (void)updateButtonStates {
    BOOL hasSelection = (self.selectedStrategy != nil);
    self.deleteStrategyButton.enabled = hasSelection && self.allStrategies.count > 1; // Can't delete last strategy
    self.duplicateStrategyButton.enabled = hasSelection;
    self.saveButton.enabled = hasSelection;
}

#pragma mark - NSTableViewDataSource - Strategy List

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.strategyListTable) {
        return self.allStrategies.count;
    } else if (tableView == self.indicatorTable) {
        return self.workingIndicators.count;
    }
    return 0;
}

- (nullable NSView *)tableView:(NSTableView *)tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row {
    
    if (tableView == self.strategyListTable) {
        return [self viewForStrategyListAtRow:row column:tableColumn];
    } else if (tableView == self.indicatorTable) {
        return [self viewForIndicatorTableAtRow:row column:tableColumn];
    }
    
    return nil;
}

- (NSView *)viewForStrategyListAtRow:(NSInteger)row column:(NSTableColumn *)column {
    NSTableCellView *cell = [self.strategyListTable makeViewWithIdentifier:@"StrategyCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] init];
        cell.identifier = @"StrategyCell";
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        [cell addSubview:textField];
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:5],
            [textField.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-5],
            [textField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
        
        cell.textField = textField;
    }
    
    ScoringStrategy *strategy = self.allStrategies[row];
    cell.textField.stringValue = strategy.strategyName;
    
    return cell;
}

- (NSView *)viewForIndicatorTableAtRow:(NSInteger)row column:(NSTableColumn *)column {
    NSString *identifier = column.identifier;
    IndicatorConfig *indicator = self.workingIndicators[row];
    
    if ([identifier isEqualToString:kIndicatorEnabledColumnId]) {
        // Checkbox column
        NSButton *checkbox = [self.indicatorTable makeViewWithIdentifier:@"CheckboxCell" owner:self];
        if (!checkbox) {
            checkbox = [[NSButton alloc] init];
            checkbox.identifier = @"CheckboxCell";
            [checkbox setButtonType:NSButtonTypeSwitch];
            checkbox.title = @"";
            checkbox.target = self;
            checkbox.action = @selector(indicatorEnabledChanged:);
        }
        checkbox.state = indicator.isEnabled ? NSControlStateValueOn : NSControlStateValueOff;
        checkbox.tag = row;
        return checkbox;
        
    } else if ([identifier isEqualToString:kIndicatorNameColumnId]) {
        // Name column
        NSTableCellView *cell = [self.indicatorTable makeViewWithIdentifier:@"NameCell" owner:self];
        if (!cell) {
            cell = [[NSTableCellView alloc] init];
            cell.identifier = @"NameCell";
            
            NSTextField *textField = [[NSTextField alloc] init];
            textField.translatesAutoresizingMaskIntoConstraints = NO;
            textField.editable = NO;
            textField.bordered = NO;
            textField.backgroundColor = [NSColor clearColor];
            [cell addSubview:textField];
            
            [NSLayoutConstraint activateConstraints:@[
                [textField.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:5],
                [textField.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-5],
                [textField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
            ]];
            
            cell.textField = textField;
        }
        cell.textField.stringValue = indicator.displayName;
        return cell;
        
    } else if ([identifier isEqualToString:kIndicatorWeightColumnId]) {
        // Weight column (editable)
        NSTextField *textField = [self.indicatorTable makeViewWithIdentifier:@"WeightCell" owner:self];
        if (!textField) {
            textField = [[NSTextField alloc] init];
            textField.identifier = @"WeightCell";
            textField.delegate = self;
        }
        textField.doubleValue = indicator.weight;
        textField.tag = row;
        return textField;
        
    } else if ([identifier isEqualToString:kIndicatorConfigColumnId]) {
        // Configure button
        NSButton *button = [self.indicatorTable makeViewWithIdentifier:@"ConfigButton" owner:self];
        if (!button) {
            button = [[NSButton alloc] init];
            button.identifier = @"ConfigButton";
            button.title = @"⚙️";
            button.bezelStyle = NSBezelStyleRounded;
            button.target = self;
            button.action = @selector(configureIndicator:);
        }
        button.tag = row;
        return button;
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = notification.object;
    
    if (tableView == self.strategyListTable) {
        NSInteger selectedRow = tableView.selectedRow;
        if (selectedRow >= 0 && selectedRow < self.allStrategies.count) {
            self.selectedStrategy = self.allStrategies[selectedRow];
            [self loadWorkingIndicatorsFromStrategy:self.selectedStrategy];
            [self updateStrategyDetails];
            [self updateButtonStates];
        }
    }
}

#pragma mark - Actions - Strategy Management

- (IBAction)createNewStrategy:(id)sender {
    // Create new strategy with default name
    ScoringStrategy *newStrategy = [ScoringStrategy strategyWithName:@"New Strategy"];
    
    // Add all available indicators (disabled by default)
    NSArray<IndicatorConfig *> *availableIndicators = [[self class] availableIndicatorTypes];
    for (IndicatorConfig *indicator in availableIndicators) {
        IndicatorConfig *copy = [[IndicatorConfig alloc] initWithType:indicator.indicatorType
                                                          displayName:indicator.displayName
                                                               weight:indicator.weight
                                                           parameters:[indicator.parameters copy]];
        copy.isEnabled = NO; // Start disabled
        [newStrategy addIndicator:copy];
    }
    
    [self.allStrategies addObject:newStrategy];
    self.selectedStrategy = newStrategy;
    self.isEditingExisting = NO;
    
    [self loadWorkingIndicatorsFromStrategy:newStrategy];
    [self updateUI];
    
    // Select the new strategy in list
    NSInteger newRow = [self.allStrategies indexOfObject:newStrategy];
    [self.strategyListTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
    
    // Focus on name field for editing
    [self.window makeFirstResponder:self.strategyNameField];
    
    NSLog(@"✅ Created new strategy");
}

- (IBAction)duplicateStrategy:(id)sender {
    if (!self.selectedStrategy) return;
    
    // Create copy
    ScoringStrategy *copy = [ScoringStrategy strategyWithName:[self.selectedStrategy.strategyName stringByAppendingString:@" Copy"]];
    
    for (IndicatorConfig *indicator in self.selectedStrategy.indicators) {
        IndicatorConfig *indicatorCopy = [[IndicatorConfig alloc] initWithType:indicator.indicatorType
                                                                    displayName:indicator.displayName
                                                                         weight:indicator.weight
                                                                     parameters:[indicator.parameters copy]];
        indicatorCopy.isEnabled = indicator.isEnabled;
        [copy addIndicator:indicatorCopy];
    }
    
    [self.allStrategies addObject:copy];
    self.selectedStrategy = copy;
    self.isEditingExisting = NO;
    
    [self loadWorkingIndicatorsFromStrategy:copy];
    [self updateUI];
    
    NSInteger newRow = [self.allStrategies indexOfObject:copy];
    [self.strategyListTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
    
    NSLog(@"✅ Duplicated strategy: %@", copy.strategyName);
}

- (IBAction)deleteStrategy:(id)sender {
    if (!self.selectedStrategy || self.allStrategies.count <= 1) {
        NSLog(@"⚠️ Cannot delete: no selection or last strategy");
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Strategy?";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'? This action cannot be undone.",
                            self.selectedStrategy.strategyName];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self performDelete];
        }
    }];
}

- (void)performDelete {
    NSString *strategyId = self.selectedStrategy.strategyId;
    [self.allStrategies removeObject:self.selectedStrategy];
    
    // Delete from disk
    NSError *error;
    [[StrategyManager sharedManager] deleteStrategy:strategyId error:&error];
    
    if (error) {
        NSLog(@"❌ Failed to delete strategy: %@", error);
    } else {
        NSLog(@"🗑️ Deleted strategy: %@", strategyId);
        
        // Notify delegate
        if ([self.delegate respondsToSelector:@selector(strategyConfigurationDidDeleteStrategy:)]) {
            [self.delegate strategyConfigurationDidDeleteStrategy:strategyId];
        }
    }
    
    // Select first available strategy
    if (self.allStrategies.count > 0) {
        self.selectedStrategy = self.allStrategies.firstObject;
        [self loadWorkingIndicatorsFromStrategy:self.selectedStrategy];
    } else {
        self.selectedStrategy = nil;
        self.workingIndicators = [NSMutableArray array];
    }
    
    [self updateUI];
}

#pragma mark - Actions - Indicator Management

- (IBAction)addIndicator:(id)sender {
    if (!self.selectedStrategy) return;
    
    // Show popup to select indicator type
    NSMenu *menu = [[NSMenu alloc] init];
    
    NSArray<IndicatorConfig *> *available = [[self class] availableIndicatorTypes];
    for (IndicatorConfig *indicator in available) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:indicator.displayName
                                                      action:@selector(didSelectIndicatorType:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = indicator;
        [menu addItem:item];
    }
    
    NSPoint location = NSMakePoint(NSMinX(self.addIndicatorButton.frame),
                                  NSMaxY(self.addIndicatorButton.frame));
    [menu popUpMenuPositioningItem:nil atLocation:location inView:self.addIndicatorButton.superview];
}

- (void)didSelectIndicatorType:(NSMenuItem *)menuItem {
    IndicatorConfig *template = menuItem.representedObject;
    
    // Create new indicator from template
    IndicatorConfig *newIndicator = [[IndicatorConfig alloc] initWithType:template.indicatorType
                                                              displayName:template.displayName
                                                                   weight:template.weight
                                                               parameters:[template.parameters copy]];
    newIndicator.isEnabled = YES;
    
    [self.workingIndicators addObject:newIndicator];
    [self.indicatorTable reloadData];
    [self updateTotalWeightLabel];
    
    NSLog(@"➕ Added indicator: %@", newIndicator.displayName);
}

- (IBAction)normalizeWeights:(id)sender {
    // Count enabled indicators
    NSInteger enabledCount = 0;
    for (IndicatorConfig *indicator in self.workingIndicators) {
        if (indicator.isEnabled) enabledCount++;
    }
    
    if (enabledCount == 0) {
        NSLog(@"⚠️ No enabled indicators to normalize");
        return;
    }
    
    // Equal weight distribution
    CGFloat equalWeight = 100.0 / (CGFloat)enabledCount;
    
    for (IndicatorConfig *indicator in self.workingIndicators) {
        if (indicator.isEnabled) {
            indicator.weight = equalWeight;
        }
    }
    
    [self.indicatorTable reloadData];
    [self updateTotalWeightLabel];
    
    NSLog(@"⚖️ Normalized weights: %.2f%% each for %ld indicators", equalWeight, (long)enabledCount);
}

- (IBAction)indicatorEnabledChanged:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row >= 0 && row < self.workingIndicators.count) {
        IndicatorConfig *indicator = self.workingIndicators[row];
        indicator.isEnabled = (sender.state == NSControlStateValueOn);
        [self updateTotalWeightLabel];
        NSLog(@"🔄 Indicator '%@' enabled: %d", indicator.displayName, indicator.isEnabled);
    }
}

- (IBAction)configureIndicator:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row >= 0 && row < self.workingIndicators.count) {
        IndicatorConfig *indicator = self.workingIndicators[row];
        
        NSLog(@"⚙️ Opening parameter sheet for: %@ (current params: %@)",
              indicator.displayName, indicator.parameters);
        
        // Show parameter configuration sheet and KEEP STRONG REFERENCE
        self.currentParameterSheet = [IndicatorParameterSheet showSheetForIndicator:indicator
                                                                            onWindow:self.window
                                                                          completion:^(BOOL saved) {
            if (saved) {
                NSLog(@"✅ Parameters updated for %@: %@",
                      indicator.displayName, indicator.parameters);
                
                // Reload indicator table to reflect any changes
                [self.indicatorTable reloadData];
            } else {
                NSLog(@"❌ Parameter configuration cancelled");
            }
            
            // Clear reference after completion
            self.currentParameterSheet = nil;
        }];
    }
}
    

#pragma mark - Actions - Save/Cancel

- (IBAction)save:(id)sender {
    if (!self.selectedStrategy) return;
    
    // Validate
    NSString *name = self.strategyNameField.stringValue;
    if (name.length == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Invalid Strategy Name";
        alert.informativeText = @"Please enter a strategy name.";
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return;
    }
    
    // Check total weight
    CGFloat totalWeight = 0;
    for (IndicatorConfig *indicator in self.workingIndicators) {
        if (indicator.isEnabled) {
            totalWeight += indicator.weight;
        }
    }
    
    if (fabs(totalWeight - 100.0) > 0.01) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Invalid Total Weight";
        alert.informativeText = [NSString stringWithFormat:@"Total weight must equal 100%%. Current total: %.2f%%\n\nUse 'Normalize Weights' to auto-adjust.", totalWeight];
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return;
    }
    
    // Update strategy
    self.selectedStrategy.strategyName = name;
    self.selectedStrategy.indicators = self.workingIndicators;
    self.selectedStrategy.dateModified = [NSDate date];
    
    // Save to disk
    NSError *error;
    BOOL success = [[StrategyManager sharedManager] saveStrategy:self.selectedStrategy error:&error];
    
    if (!success) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Save Failed";
        alert.informativeText = [NSString stringWithFormat:@"Failed to save strategy: %@", error.localizedDescription];
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return;
    }
    
    NSLog(@"💾 Saved strategy: %@", self.selectedStrategy.strategyName);
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(strategyConfigurationDidSaveStrategy:)]) {
        [self.delegate strategyConfigurationDidSaveStrategy:self.selectedStrategy];
    }
    
    [self.window close];
}

- (IBAction)cancel:(id)sender {
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(strategyConfigurationDidCancel)]) {
        [self.delegate strategyConfigurationDidCancel];
    }
    
    [self.window close];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *textField = notification.object;
    
    if (textField == self.strategyNameField) {
        // Name changed - no action needed until save
        
    } else if (textField.tag >= 0 && textField.tag < self.workingIndicators.count) {
        // Weight field changed
        IndicatorConfig *indicator = self.workingIndicators[textField.tag];
        indicator.weight = textField.doubleValue;
        [self updateTotalWeightLabel];
    }
}

@end
