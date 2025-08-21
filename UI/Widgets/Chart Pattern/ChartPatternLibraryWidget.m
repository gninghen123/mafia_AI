//
//  ChartPatternLibraryWidget.m
//  TradingApp
//
//  Chart Pattern Library Widget - Browse and manage chart patterns
//

#import "ChartPatternLibraryWidget.h"
#import "ChartPatternManager.h"
#import "DataHub.h"
#import "DataHub+ChartPatterns.h"

// Table columns
static NSString * const kPatternTypeColumn = @"PatternType";
static NSString * const kSymbolColumn = @"Symbol";
static NSString * const kBarsColumn = @"Bars";
static NSString * const kDateColumn = @"Date";

@implementation ChartPatternLibraryWidget

#pragma mark - BaseWidget Override

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.patternManager = [ChartPatternManager shared];
        self.allPatterns = @[];
        self.filteredPatterns = @[];
        self.patternTypes = @[];
        self.selectedFilterType = nil;
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    // Remove placeholder
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    [self setupUI];
    [self setupConstraints];
    [self refreshPatternData];
}

#pragma mark - UI Setup

- (void)setupUI {
    // Toolbar
    self.toolbarView = [[NSView alloc] init];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.toolbarView];
    
    // Pattern type filter
    self.patternTypeFilter = [[NSPopUpButton alloc] init];
    self.patternTypeFilter.translatesAutoresizingMaskIntoConstraints = NO;
    self.patternTypeFilter.target = self;
    self.patternTypeFilter.action = @selector(patternTypeFilterChanged:);
    [self.toolbarView addSubview:self.patternTypeFilter];
    
    // Action buttons
    self.newTypeButton = [self createToolbarButtonWithTitle:@"+ Type" action:@selector(newTypeButtonClicked:)];
    self.renameTypeButton = [self createToolbarButtonWithTitle:@"Rename" action:@selector(renameTypeButtonClicked:)];
    self.deleteTypeButton = [self createToolbarButtonWithTitle:@"Delete" action:@selector(deleteTypeButtonClicked:)];
    self.refreshButton = [self createToolbarButtonWithTitle:@"Refresh" action:@selector(refreshButtonClicked:)];
    
    [self.toolbarView addSubview:self.newTypeButton];
    [self.toolbarView addSubview:self.renameTypeButton];
    [self.toolbarView addSubview:self.deleteTypeButton];
    [self.toolbarView addSubview:self.refreshButton];
    
    // Info label
    self.infoLabel = [[NSTextField alloc] init];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoLabel.editable = NO;
    self.infoLabel.bordered = NO;
    self.infoLabel.backgroundColor = [NSColor clearColor];
    self.infoLabel.font = [NSFont systemFontOfSize:11];
    self.infoLabel.textColor = [NSColor secondaryLabelColor];
    [self.toolbarView addSubview:self.infoLabel];
    
    // Table view setup
    self.patternsTableView = [[NSTableView alloc] init];
    self.patternsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.patternsTableView.dataSource = self;
    self.patternsTableView.delegate = self;
    self.patternsTableView.allowsMultipleSelection = NO;
    self.patternsTableView.target = self;
    self.patternsTableView.doubleAction = @selector(tableViewDoubleClicked:);
    
    // Create table columns
    [self setupTableColumns];
    
    // Scroll view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.patternsTableView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    [self.contentView addSubview:self.scrollView];
}

- (NSButton *)createToolbarButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [[NSButton alloc] init];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.title = title;
    button.target = self;
    button.action = action;
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}

- (void)setupTableColumns {
    // Pattern Type column
    NSTableColumn *typeColumn = [[NSTableColumn alloc] initWithIdentifier:kPatternTypeColumn];
    typeColumn.title = @"Pattern Type";
    typeColumn.width = 120;
    typeColumn.minWidth = 80;
    [self.patternsTableView addTableColumn:typeColumn];
    
    // Symbol column
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:kSymbolColumn];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    [self.patternsTableView addTableColumn:symbolColumn];
    
    // Bars column
    NSTableColumn *barsColumn = [[NSTableColumn alloc] initWithIdentifier:kBarsColumn];
    barsColumn.title = @"Bars";
    barsColumn.width = 60;
    barsColumn.minWidth = 50;
    [self.patternsTableView addTableColumn:barsColumn];
    
    // Date column
    NSTableColumn *dateColumn = [[NSTableColumn alloc] initWithIdentifier:kDateColumn];
    dateColumn.title = @"Created";
    dateColumn.width = 100;
    dateColumn.minWidth = 80;
    [self.patternsTableView addTableColumn:dateColumn];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:40],
        
        // Pattern type filter
        [self.patternTypeFilter.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:10],
        [self.patternTypeFilter.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.patternTypeFilter.widthAnchor constraintEqualToConstant:120],
        
        // Buttons
        [self.newTypeButton.leadingAnchor constraintEqualToAnchor:self.patternTypeFilter.trailingAnchor constant:10],
        [self.newTypeButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.newTypeButton.widthAnchor constraintEqualToConstant:60],
        
        [self.renameTypeButton.leadingAnchor constraintEqualToAnchor:self.newTypeButton.trailingAnchor constant:5],
        [self.renameTypeButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.renameTypeButton.widthAnchor constraintEqualToConstant:60],
        
        [self.deleteTypeButton.leadingAnchor constraintEqualToAnchor:self.renameTypeButton.trailingAnchor constant:5],
        [self.deleteTypeButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.deleteTypeButton.widthAnchor constraintEqualToConstant:60],
        
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-10],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.refreshButton.widthAnchor constraintEqualToConstant:60],
        
        // Info label
        [self.infoLabel.trailingAnchor constraintEqualToAnchor:self.refreshButton.leadingAnchor constant:-10],
        [self.infoLabel.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        
        // Scroll view (table)
        [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - Data Management

- (void)refreshPatternData {
    // Get all patterns
    self.allPatterns = [self.patternManager getAllPatterns];
    
    // Get all pattern types
    self.patternTypes = [self.patternManager getAllKnownPatternTypes];
    
    // Update filter popup
    [self updatePatternTypeFilter];
    
    // Apply current filter
    [self filterPatternsByType:self.selectedFilterType];
    
    // Update info
    [self updateInfoLabel];
    
    NSLog(@"📋 ChartPatternLibraryWidget: Refreshed data - %ld patterns, %ld types",
          (long)self.allPatterns.count, (long)self.patternTypes.count);
}

- (void)updatePatternTypeFilter {
    [self.patternTypeFilter removeAllItems];
    
    // Add "All Types" option
    [self.patternTypeFilter addItemWithTitle:@"All Types"];
    
    // Add pattern types
    for (NSString *patternType in self.patternTypes) {
        [self.patternTypeFilter addItemWithTitle:patternType];
    }
    
    // Select current filter
    if (self.selectedFilterType) {
        [self.patternTypeFilter selectItemWithTitle:self.selectedFilterType];
    } else {
        [self.patternTypeFilter selectItemAtIndex:0]; // "All Types"
    }
}

- (void)filterPatternsByType:(nullable NSString *)patternType {
    self.selectedFilterType = patternType;
    
    if (!patternType) {
        // Show all patterns
        self.filteredPatterns = self.allPatterns;
    } else {
        // Filter by type
        NSMutableArray *filtered = [NSMutableArray array];
        for (ChartPatternModel *pattern in self.allPatterns) {
            if ([pattern.patternType isEqualToString:patternType]) {
                [filtered addObject:pattern];
            }
        }
        self.filteredPatterns = [filtered copy];
    }
    
    [self.patternsTableView reloadData];
    [self updateInfoLabel];
}

- (void)updateInfoLabel {
    NSString *info;
    if (self.selectedFilterType) {
        info = [NSString stringWithFormat:@"%ld patterns (%@)",
                (long)self.filteredPatterns.count, self.selectedFilterType];
    } else {
        info = [NSString stringWithFormat:@"%ld patterns total",
                (long)self.filteredPatterns.count];
    }
    self.infoLabel.stringValue = info;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredPatterns.count;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredPatterns.count) return nil;
    
    ChartPatternModel *pattern = self.filteredPatterns[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:kPatternTypeColumn]) {
        return pattern.patternType;
    } else if ([identifier isEqualToString:kSymbolColumn]) {
        return pattern.symbol ?: @"N/A";
    } else if ([identifier isEqualToString:kBarsColumn]) {
        return @(pattern.barCount);
    } else if ([identifier isEqualToString:kDateColumn]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        return [formatter stringFromDate:pattern.creationDate];
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    // Update button states based on selection
    BOOL hasSelection = self.patternsTableView.selectedRow != -1;
    BOOL hasTypeSelected = self.selectedFilterType != nil;
    
    self.renameTypeButton.enabled = hasTypeSelected;
    self.deleteTypeButton.enabled = hasTypeSelected;
}

- (NSMenu *)tableView:(NSTableView *)tableView menuForEvent:(NSEvent *)event {
    NSPoint point = [tableView convertPoint:event.locationInWindow fromView:nil];
    NSInteger row = [tableView rowAtPoint:point];
    
    if (row >= 0 && row < self.filteredPatterns.count) {
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        return [self createContextMenuForPattern:self.filteredPatterns[row]];
    }
    
    return nil;
}

- (NSMenu *)createContextMenuForPattern:(ChartPatternModel *)pattern {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Pattern Actions"];
    
    NSMenuItem *loadItem = [[NSMenuItem alloc] initWithTitle:@"Load in Chart"
                                                      action:@selector(loadSelectedPatternToChain)
                                               keyEquivalent:@""];
    loadItem.target = self;
    [menu addItem:loadItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *detailsItem = [[NSMenuItem alloc] initWithTitle:@"Show Details..."
                                                         action:@selector(showPatternDetailsDialog)
                                                  keyEquivalent:@""];
    detailsItem.target = self;
    [menu addItem:detailsItem];
    
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Pattern..."
                                                        action:@selector(deleteSelectedPatternWithConfirmation)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    [menu addItem:deleteItem];
    
    return menu;
}

- (void)tableViewDoubleClicked:(id)sender {
    if (self.patternsTableView.selectedRow != -1) {
        [self loadSelectedPatternToChain];
    }
}

#pragma mark - Chain Integration

- (void)loadSelectedPatternToChain {
    NSInteger selectedRow = self.patternsTableView.selectedRow;
    if (selectedRow == -1 || selectedRow >= self.filteredPatterns.count) return;
    
    ChartPatternModel *pattern = self.filteredPatterns[selectedRow];
    
    // Load SavedChartData from pattern
    SavedChartData *savedData = [pattern loadConnectedSavedData];
    if (!savedData) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot Load Pattern";
        alert.informativeText = @"The saved chart data for this pattern could not be found or is corrupted.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Send to chain with symbol
    NSArray<NSString *> *symbols = @[savedData.symbol];
    [self sendSymbolsToChainWithColor:symbols color:[NSColor systemBlueColor]];
    
    NSLog(@"📋 ChartPatternLibraryWidget: Sent pattern '%@' (%@) to chain",
          pattern.patternType, savedData.symbol);
}

#pragma mark - BaseWidget Chain Methods Override

- (NSArray<NSString *> *)selectedSymbols {
    NSInteger selectedRow = self.patternsTableView.selectedRow;
    if (selectedRow == -1 || selectedRow >= self.filteredPatterns.count) return @[];
    
    ChartPatternModel *pattern = self.filteredPatterns[selectedRow];
    return pattern.symbol ? @[pattern.symbol] : @[];
}

- (NSArray<NSString *> *)contextualSymbols {
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    for (ChartPatternModel *pattern in self.filteredPatterns) {
        if (pattern.symbol) {
            [symbols addObject:pattern.symbol];
        }
    }
    return [symbols copy];
}

- (NSString *)contextMenuTitle {
    NSInteger selectedRow = self.patternsTableView.selectedRow;
    if (selectedRow != -1 && selectedRow < self.filteredPatterns.count) {
        ChartPatternModel *pattern = self.filteredPatterns[selectedRow];
        return [NSString stringWithFormat:@"Pattern: %@", pattern.patternType];
    }
    return @"Pattern Library";
}

#pragma mark - Pattern Type Management

- (void)showCreatePatternTypeDialog {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create New Pattern Type";
    alert.informativeText = @"Enter a name for the new pattern type:";
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 25)];
    textField.placeholderString = @"Pattern type name...";
    alert.accessoryView = textField;
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *newType = textField.stringValue;
        if (newType.length > 0 && [self.patternManager isValidPatternType:newType]) {
            [self.patternManager addPatternType:newType];
            [self refreshPatternData];
            
            // Select the new type
            [self.patternTypeFilter selectItemWithTitle:newType];
            [self filterPatternsByType:newType];
            
            NSLog(@"📋 Created new pattern type: %@", newType);
        }
    }
}

- (void)showRenamePatternTypeDialog {
    if (!self.selectedFilterType) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Pattern Type";
    alert.informativeText = [NSString stringWithFormat:@"Rename '%@' to:", self.selectedFilterType];
    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 25)];
    textField.stringValue = self.selectedFilterType;
    alert.accessoryView = textField;
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *newName = textField.stringValue;
        if (newName.length > 0 && [self.patternManager isValidPatternType:newName]) {
            // Update all patterns with this type
            DataHub *dataHub = [DataHub shared];
            NSArray<ChartPatternModel *> *patternsToUpdate = [dataHub getPatternsOfType:self.selectedFilterType];
            
            for (ChartPatternModel *pattern in patternsToUpdate) {
                [pattern updatePatternType:newName notes:pattern.additionalNotes];
                [dataHub updatePattern:pattern];
            }
            
            [self.patternManager addPatternType:newName];
            [self refreshPatternData];
            
            // Select the renamed type
            [self.patternTypeFilter selectItemWithTitle:newName];
            [self filterPatternsByType:newName];
            
            NSLog(@"📋 Renamed pattern type '%@' to '%@'", self.selectedFilterType, newName);
        }
    }
}

- (void)showDeletePatternTypeDialog {
    if (!self.selectedFilterType) return;
    
    DataHub *dataHub = [DataHub shared];
    NSArray<ChartPatternModel *> *patternsOfType = [dataHub getPatternsOfType:self.selectedFilterType];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Pattern Type";
    alert.informativeText = [NSString stringWithFormat:
        @"Delete pattern type '%@'?\n\nThis will also delete %ld patterns of this type.\nThis action cannot be undone.",
        self.selectedFilterType, (long)patternsOfType.count];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleCritical;
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        // Delete all patterns of this type
        for (ChartPatternModel *pattern in patternsOfType) {
            [dataHub deletePatternWithID:pattern.patternID];
        }
        
        [self refreshPatternData];
        
        // Reset filter to "All Types"
        [self.patternTypeFilter selectItemAtIndex:0];
        [self filterPatternsByType:nil];
        
        NSLog(@"📋 Deleted pattern type '%@' and %ld patterns",
              self.selectedFilterType, (long)patternsOfType.count);
    }
}

#pragma mark - Pattern Management

- (void)deleteSelectedPatternWithConfirmation {
    NSInteger selectedRow = self.patternsTableView.selectedRow;
    if (selectedRow == -1 || selectedRow >= self.filteredPatterns.count) return;
    
    ChartPatternModel *pattern = self.filteredPatterns[selectedRow];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Pattern";
    alert.informativeText = [NSString stringWithFormat:
        @"Delete pattern '%@'?\n\nDo you also want to delete the associated saved chart data?",
        pattern.patternType];
    [alert addButtonWithTitle:@"Delete Pattern Only"];
    [alert addButtonWithTitle:@"Delete Pattern + Chart Data"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertThirdButtonReturn) return; // Cancel
    
    BOOL deleteChartData = (response == NSAlertSecondButtonReturn);
    
    // Delete chart data if requested
    if (deleteChartData) {
        SavedChartData *savedData = [pattern loadConnectedSavedData];
        if (savedData) {
            NSString *directory = [ChartWidget savedChartDataDirectory];
            NSString *filename = [NSString stringWithFormat:@"%@.chartdata", pattern.savedDataReference];
            NSString *filePath = [directory stringByAppendingPathComponent:filename];
            
            NSError *error;
            if ([[NSFileManager defaultManager] removeItemAtPath:filePath error:&error]) {
                NSLog(@"🗑️ Deleted chart data file: %@", filename);
            } else {
                NSLog(@"❌ Failed to delete chart data file: %@", error.localizedDescription);
            }
        }
    }
    
    // Delete pattern
    DataHub *dataHub = [DataHub shared];
    [dataHub deletePatternWithID:pattern.patternID];
    
    [self refreshPatternData];
    
    NSLog(@"🗑️ Deleted pattern '%@' (chart data: %@)",
          pattern.patternType, deleteChartData ? @"YES" : @"NO");
}

- (void)showPatternDetailsDialog {
    NSInteger selectedRow = self.patternsTableView.selectedRow;
    if (selectedRow == -1 || selectedRow >= self.filteredPatterns.count) return;
    
    ChartPatternModel *pattern = self.filteredPatterns[selectedRow];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Pattern Details";
    alert.informativeText = pattern.displayInfo;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

#pragma mark - Action Methods

- (IBAction)patternTypeFilterChanged:(id)sender {
    NSString *selectedTitle = self.patternTypeFilter.selectedItem.title;
    NSString *filterType = [selectedTitle isEqualToString:@"All Types"] ? nil : selectedTitle;
    [self filterPatternsByType:filterType];
}

- (IBAction)newTypeButtonClicked:(id)sender {
    [self showCreatePatternTypeDialog];
}

- (IBAction)renameTypeButtonClicked:(id)sender {
    [self showRenamePatternTypeDialog];
}

- (IBAction)deleteTypeButtonClicked:(id)sender {
    [self showDeletePatternTypeDialog];
}

- (IBAction)refreshButtonClicked:(id)sender {
    [self refreshPatternData];
}

@end
