//
//  SymbolDatabaseWidget.m
//  mafia_AI
//

#import "SymbolDatabaseWidget.h"
#import "DataHub.h"
#import <QuartzCore/QuartzCore.h>

@interface SymbolDatabaseWidget ()
@property (nonatomic, strong) NSView *toolbar;
@end

@implementation SymbolDatabaseWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"SymbolDatabase";
        
        // Initialize data
        self.symbols = @[];
        self.filteredSymbols = @[];
        self.searchText = @"";
        self.selectedTagFilter = nil;
        self.showOnlyFavorites = NO;
        
        // Register for DataHub notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(symbolsUpdated:)
                                                     name:@"DataHubSymbolCreated"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(symbolsUpdated:)
                                                     name:@"DataHubSymbolDeleted"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - BaseWidget Override

- (void)setupContentView {
    [super setupContentView];
    
    // Remove BaseWidget's placeholder
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Setup UI components
    [self createToolbar];
    [self createMainTableView];
    [self setupConstraints];
    [self createTableColumns];
    [self setupContextMenu];
    
    // Load initial data
    [self loadSymbols];
}

#pragma mark - UI Creation

- (void)createToolbar {
    // Create toolbar
    self.toolbar = [[NSView alloc] init];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.toolbar];
    
    // Search field
    self.searchField = [[NSSearchField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = @"Search symbols...";
    self.searchField.target = self;
    self.searchField.action = @selector(searchFieldChanged:);
    [self.toolbar addSubview:self.searchField];
    
    // Tag filter button
    self.tagFilterButton = [[NSPopUpButton alloc] init];
    self.tagFilterButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.tagFilterButton.target = self;
    self.tagFilterButton.action = @selector(tagFilterChanged:);
    [self.toolbar addSubview:self.tagFilterButton];
    
    // Add symbol button
    self.addSymbolButton = [NSButton buttonWithTitle:@"Add Symbol"
                                               target:self
                                               action:@selector(addSymbol:)];
    self.addSymbolButton.bezelStyle = NSBezelStyleRounded;
    self.addSymbolButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar addSubview:self.addSymbolButton];
    
    // Favorite filter button
    self.favoriteFilterButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameBookmarksTemplate]
                                                    target:self
                                                    action:@selector(favoriteFilterToggled:)];
    self.favoriteFilterButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.favoriteFilterButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.favoriteFilterButton.toolTip = @"Show only favorites";
    [self.toolbar addSubview:self.favoriteFilterButton];
    
    // Status label
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    self.statusLabel.stringValue = @"Loading...";
    [self.toolbar addSubview:self.statusLabel];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    [self.toolbar addSubview:self.loadingIndicator];
}

- (void)createMainTableView {
    // Create table view
    self.mainTableView = [[NSTableView alloc] init];
    self.mainTableView.delegate = self;
    self.mainTableView.dataSource = self;
    self.mainTableView.headerView = [[NSTableHeaderView alloc] init];
    self.mainTableView.allowsMultipleSelection = YES;
    self.mainTableView.allowsColumnSelection = NO;
    self.mainTableView.usesAlternatingRowBackgroundColors = YES;
    
    // Create scroll view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.mainTableView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    [self.contentView addSubview:self.scrollView];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar
        [self.toolbar.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbar.heightAnchor constraintEqualToConstant:44],
        
        // Toolbar components
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.toolbar.leadingAnchor constant:8],
        [self.searchField.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.searchField.widthAnchor constraintEqualToConstant:200],
        
        [self.tagFilterButton.leadingAnchor constraintEqualToAnchor:self.searchField.trailingAnchor constant:8],
        [self.tagFilterButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.tagFilterButton.widthAnchor constraintEqualToConstant:120],
        
        [self.favoriteFilterButton.leadingAnchor constraintEqualToAnchor:self.tagFilterButton.trailingAnchor constant:8],
        [self.favoriteFilterButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        
        [self.addSymbolButton.trailingAnchor constraintEqualToAnchor:self.toolbar.trailingAnchor constant:-8],
        [self.addSymbolButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        
        [self.loadingIndicator.trailingAnchor constraintEqualToAnchor:self.addSymbolButton.leadingAnchor constant:-8],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.loadingIndicator.leadingAnchor constant:-8],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        
        // Main table view
        [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

- (void)createTableColumns {
    // Remove existing columns
    while (self.mainTableView.tableColumns.count > 0) {
        [self.mainTableView removeTableColumn:self.mainTableView.tableColumns[0]];
    }
    
    // Symbol column
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    symbolColumn.maxWidth = 120;
    [self.mainTableView addTableColumn:symbolColumn];
    
    // Tags column
    NSTableColumn *tagsColumn = [[NSTableColumn alloc] initWithIdentifier:@"tags"];
    tagsColumn.title = @"Tags";
    tagsColumn.width = 150;
    tagsColumn.minWidth = 100;
    tagsColumn.maxWidth = 300;
    [self.mainTableView addTableColumn:tagsColumn];
    
    // Interactions column
    NSTableColumn *interactionsColumn = [[NSTableColumn alloc] initWithIdentifier:@"interactions"];
    interactionsColumn.title = @"Uses";
    interactionsColumn.width = 60;
    interactionsColumn.minWidth = 50;
    interactionsColumn.maxWidth = 80;
    [self.mainTableView addTableColumn:interactionsColumn];
    
    // Last used column
    NSTableColumn *lastUsedColumn = [[NSTableColumn alloc] initWithIdentifier:@"lastUsed"];
    lastUsedColumn.title = @"Last Used";
    lastUsedColumn.width = 100;
    lastUsedColumn.minWidth = 80;
    lastUsedColumn.maxWidth = 150;
    [self.mainTableView addTableColumn:lastUsedColumn];
    
    // Favorite column
    NSTableColumn *favoriteColumn = [[NSTableColumn alloc] initWithIdentifier:@"favorite"];
    favoriteColumn.title = @"★";
    favoriteColumn.width = 30;
    favoriteColumn.minWidth = 30;
    favoriteColumn.maxWidth = 30;
    [self.mainTableView addTableColumn:favoriteColumn];
}

- (void)setupContextMenu {
    NSMenu *contextMenu = [[NSMenu alloc] init];
    contextMenu.delegate = self;
    self.mainTableView.menu = contextMenu;
}

#pragma mark - Data Management

- (void)loadSymbols {
    [self.loadingIndicator startAnimation:nil];
    self.statusLabel.stringValue = @"Loading symbols...";
    
    // Load from DataHub
    self.symbols = [[DataHub shared] getAllSymbols];
    
    // Update tag filter
    [self updateTagFilter];
    
    // Apply filters
    [self applyFilters];
    
    [self.loadingIndicator stopAnimation:nil];
    [self updateStatusLabel];
}

- (void)applyFilters {
    NSMutableArray<Symbol *> *filtered = [self.symbols mutableCopy];
    
    // Apply search filter
    if (self.searchText.length > 0) {
        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"symbol CONTAINS[cd] %@", self.searchText];
        [filtered filterUsingPredicate:searchPredicate];
    }
    
    // Apply tag filter
    if (self.selectedTagFilter && ![self.selectedTagFilter isEqualToString:@"All Tags"]) {
        NSPredicate *tagPredicate = [NSPredicate predicateWithFormat:@"ANY tags LIKE[cd] %@", self.selectedTagFilter];
        [filtered filterUsingPredicate:tagPredicate];
    }
    
    // Apply favorite filter
    if (self.showOnlyFavorites) {
        NSPredicate *favoritePredicate = [NSPredicate predicateWithFormat:@"isFavorite == YES"];
        [filtered filterUsingPredicate:favoritePredicate];
    }
    
    self.filteredSymbols = [filtered copy];
    [self.mainTableView reloadData];
    [self updateStatusLabel];
}

- (void)updateTagFilter {
    [self.tagFilterButton removeAllItems];
    [self.tagFilterButton addItemWithTitle:@"All Tags"];
    
    NSArray<NSString *> *allTags = [[DataHub shared] getAllTags];
    for (NSString *tag in allTags) {
        [self.tagFilterButton addItemWithTitle:tag];
    }
    
    if (!self.selectedTagFilter) {
        [self.tagFilterButton selectItemWithTitle:@"All Tags"];
    }
}

- (void)updateStatusLabel {
    NSInteger totalSymbols = self.symbols.count;
    NSInteger filteredCount = self.filteredSymbols.count;
    
    if (totalSymbols == filteredCount) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"%ld symbols", (long)totalSymbols];
    } else {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"%ld of %ld symbols", (long)filteredCount, (long)totalSymbols];
    }
}

- (void)refreshData {
    [self loadSymbols];
}

#pragma mark - Actions

- (void)addSymbol:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Symbol";
    alert.informativeText = @"Enter a symbol to add to the database:";
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"e.g. AAPL";
    alert.accessoryView = input;
    [alert.window setInitialFirstResponder:input];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *symbolName = [input.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (symbolName.length > 0) {
            Symbol *newSymbol = [[DataHub shared] createSymbolWithName:symbolName];
            if (newSymbol) {
                [self loadSymbols];
                NSLog(@"SymbolDatabaseWidget: Added symbol %@", newSymbol.symbol);
            }
        }
    }
}

- (void)searchFieldChanged:(id)sender {
    self.searchText = self.searchField.stringValue;
    [self applyFilters];
}

- (void)tagFilterChanged:(id)sender {
    self.selectedTagFilter = self.tagFilterButton.titleOfSelectedItem;
    [self applyFilters];
}

- (void)favoriteFilterToggled:(id)sender {
    self.showOnlyFavorites = !self.showOnlyFavorites;
    self.favoriteFilterButton.state = self.showOnlyFavorites ? NSControlStateValueOn : NSControlStateValueOff;
    [self applyFilters];
}

#pragma mark - Notifications

- (void)symbolsUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadSymbols];
    });
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredSymbols.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredSymbols.count) return nil;
    
    Symbol *symbol = self.filteredSymbols[row];
    NSString *identifier = tableColumn.identifier;
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.bordered = NO;
        textField.editable = NO;
        textField.backgroundColor = [NSColor clearColor];
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Populate cell based on column
    if ([identifier isEqualToString:@"symbol"]) {
        cellView.textField.stringValue = symbol.symbol ?: @"";
        cellView.textField.font = [NSFont boldSystemFontOfSize:12];
    } else if ([identifier isEqualToString:@"tags"]) {
        NSString *tagsString = symbol.tags ? [symbol.tags componentsJoinedByString:@", "] : @"";
        cellView.textField.stringValue = tagsString;
        cellView.textField.font = [NSFont systemFontOfSize:11];
        cellView.textField.textColor = [NSColor secondaryLabelColor];
    } else if ([identifier isEqualToString:@"interactions"]) {
        cellView.textField.stringValue = [NSString stringWithFormat:@"%d", symbol.interactionCount];
        cellView.textField.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    } else if ([identifier isEqualToString:@"lastUsed"]) {
        if (symbol.lastInteraction) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterShortStyle;
            cellView.textField.stringValue = [formatter stringFromDate:symbol.lastInteraction];
        } else {
            cellView.textField.stringValue = @"Never";
        }
        cellView.textField.font = [NSFont systemFontOfSize:11];
        cellView.textField.textColor = [NSColor secondaryLabelColor];
    } else if ([identifier isEqualToString:@"favorite"]) {
        cellView.textField.stringValue = symbol.isFavorite ? @"★" : @"";
        cellView.textField.font = [NSFont systemFontOfSize:14];
        cellView.textField.textColor = [NSColor systemYellowColor];
    }
    
    return cellView;
}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    [menu removeAllItems];
    
    NSIndexSet *selectedRows = self.mainTableView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    // Add context menu items based on selection
    [menu addItemWithTitle:@"Toggle Favorite" action:@selector(toggleFavoriteForSelectedSymbols:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Manage Tags..." action:@selector(manageTagsForSelectedSymbols:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Delete Symbol(s)" action:@selector(deleteSelectedSymbols:) keyEquivalent:@""];
    
    // Set target for all items
    for (NSMenuItem *item in menu.itemArray) {
        item.target = self;
    }
}

#pragma mark - Context Menu Actions

- (void)toggleFavoriteForSelectedSymbols:(id)sender {
    NSIndexSet *selectedRows = self.mainTableView.selectedRowIndexes;
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.filteredSymbols.count) {
            Symbol *symbol = self.filteredSymbols[idx];
            symbol.isFavorite = !symbol.isFavorite;
        }
    }];
    
    [[DataHub shared] saveContext];
    [self.mainTableView reloadData];
}

- (void)manageTagsForSelectedSymbols:(id)sender {
    // TODO: Implement tag management dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Feature Coming Soon";
    alert.informativeText = @"Tag management will be available in the next update.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)deleteSelectedSymbols:(id)sender {
    NSIndexSet *selectedRows = self.mainTableView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray *symbolsToDelete = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.filteredSymbols.count) {
            [symbolsToDelete addObject:self.filteredSymbols[idx]];
        }
    }];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Symbols";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete %lu symbol(s)?", (unsigned long)symbolsToDelete.count];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        for (Symbol *symbol in symbolsToDelete) {
            [[DataHub shared] deleteSymbol:symbol];
        }
        [self loadSymbols];
    }
}

@end
