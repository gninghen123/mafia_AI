//
//  WatchlistWidget.m
//  mafia_AI
//

#import "WatchlistWidget.h"
#import "DataHub.h"
#import "Watchlist+CoreDataClass.h"

@interface WatchlistWidget ()
@property (nonatomic, strong) NSNumberFormatter *priceFormatter;
@property (nonatomic, strong) NSNumberFormatter *percentFormatter;
@end

@implementation WatchlistWidget

- (instancetype)initWithType:(WidgetType)type {
    self = [super initWithType:type];
    if (self) {
        self.widgetTitle = @"Watchlist";
        self.symbolDataCache = [NSMutableDictionary dictionary];
        [self setupFormatters];
        [self setupUI];
        [self registerForNotifications];
        [self loadWatchlists];
        [self startRefreshTimer];
    }
    return self;
}

- (void)dealloc {
    [self.refreshTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup

- (void)setupFormatters {
    self.priceFormatter = [[NSNumberFormatter alloc] init];
    self.priceFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    self.priceFormatter.minimumFractionDigits = 2;
    self.priceFormatter.maximumFractionDigits = 2;
    
    self.percentFormatter = [[NSNumberFormatter alloc] init];
    self.percentFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    self.percentFormatter.minimumFractionDigits = 2;
    self.percentFormatter.maximumFractionDigits = 2;
    self.percentFormatter.positivePrefix = @"+";
    self.percentFormatter.positiveSuffix = @"%";
    self.percentFormatter.negativeSuffix = @"%";
}

- (void)setupUI {
    // Top toolbar
    NSView *toolbar = [[NSView alloc] init];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Watchlist selector (segmented control)
    self.watchlistSelector = [[NSSegmentedControl alloc] init];
    self.watchlistSelector.segmentStyle = NSSegmentStyleTexturedRounded;
    self.watchlistSelector.target = self;
    self.watchlistSelector.action = @selector(watchlistChanged:);
    self.watchlistSelector.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Menu button for watchlist management
    self.watchlistMenuButton = [[NSButton alloc] init];
    self.watchlistMenuButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.watchlistMenuButton.image = [NSImage imageNamed:NSImageNameActionTemplate];
    self.watchlistMenuButton.imagePosition = NSImageOnly;
    self.watchlistMenuButton.target = self;
    self.watchlistMenuButton.action = @selector(showWatchlistMenu:);
    self.watchlistMenuButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Search field
    self.searchField = [[NSSearchField alloc] init];
    self.searchField.placeholderString = @"Filter symbols...";
    self.searchField.target = self;
    self.searchField.action = @selector(searchFieldChanged:);
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add/Remove buttons
    self.addSymbolButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameAddTemplate]
                                              target:self
                                              action:@selector(addSymbol:)];
    self.addSymbolButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.addSymbolButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.removeSymbolButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameRemoveTemplate]
                                                 target:self
                                                 action:@selector(removeSymbol:)];
    self.removeSymbolButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.removeSymbolButton.enabled = NO;
    self.removeSymbolButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.displayedWhenStopped = NO;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Table view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 32;
    self.tableView.intercellSpacing = NSMakeSize(0, 1);
    self.tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    self.tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    self.tableView.allowsMultipleSelection = YES;
    
    [self createTableColumns];
    self.scrollView.documentView = self.tableView;
    
    // Add to toolbar
    [toolbar addSubview:self.watchlistSelector];
    [toolbar addSubview:self.watchlistMenuButton];
    [toolbar addSubview:self.searchField];
    [toolbar addSubview:self.addSymbolButton];
    [toolbar addSubview:self.removeSymbolButton];
    [toolbar addSubview:self.loadingIndicator];
    
    // Add to main view
    [self addSubview:toolbar];
    [self addSubview:self.scrollView];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar
        [toolbar.topAnchor constraintEqualToAnchor:self.topAnchor constant:5],
        [toolbar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:5],
        [toolbar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5],
        [toolbar.heightAnchor constraintEqualToConstant:30],
        
        // Watchlist selector
        [self.watchlistSelector.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor],
        [self.watchlistSelector.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.watchlistSelector.widthAnchor constraintGreaterThanOrEqualToConstant:150],
        
        // Menu button
        [self.watchlistMenuButton.leadingAnchor constraintEqualToAnchor:self.watchlistSelector.trailingAnchor constant:5],
        [self.watchlistMenuButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.watchlistMenuButton.widthAnchor constraintEqualToConstant:25],
        
        // Add/Remove buttons
        [self.removeSymbolButton.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor],
        [self.removeSymbolButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.removeSymbolButton.widthAnchor constraintEqualToConstant:25],
        
        [self.addSymbolButton.trailingAnchor constraintEqualToAnchor:self.removeSymbolButton.leadingAnchor constant:-5],
        [self.addSymbolButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.addSymbolButton.widthAnchor constraintEqualToConstant:25],
        
        // Loading indicator
        [self.loadingIndicator.trailingAnchor constraintEqualToAnchor:self.addSymbolButton.leadingAnchor constant:-10],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        // Search field
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.watchlistMenuButton.trailingAnchor constant:10],
        [self.searchField.trailingAnchor constraintEqualToAnchor:self.loadingIndicator.leadingAnchor constant:-10],
        [self.searchField.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        // Scroll view
        [self.scrollView.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor constant:5],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (void)createTableColumns {
    // Symbol column
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 70;
    symbolColumn.minWidth = 50;
    [self.tableView addTableColumn:symbolColumn];
    
    // Price column
    NSTableColumn *priceColumn = [[NSTableColumn alloc] initWithIdentifier:@"price"];
    priceColumn.title = @"Price";
    priceColumn.width = 80;
    priceColumn.minWidth = 60;
    [self.tableView addTableColumn:priceColumn];
    
    // Change column
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change";
    changeColumn.width = 80;
    changeColumn.minWidth = 60;
    [self.tableView addTableColumn:changeColumn];
    
    // Change % column
    NSTableColumn *changePercentColumn = [[NSTableColumn alloc] initWithIdentifier:@"changePercent"];
    changePercentColumn.title = @"Change %";
    changePercentColumn.width = 80;
    changePercentColumn.minWidth = 60;
    [self.tableView addTableColumn:changePercentColumn];
    
    // Volume column
    NSTableColumn *volumeColumn = [[NSTableColumn alloc] initWithIdentifier:@"volume"];
    volumeColumn.title = @"Volume";
    volumeColumn.width = 100;
    volumeColumn.minWidth = 80;
    [self.tableView addTableColumn:volumeColumn];
}

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(watchlistsUpdated:)
               name:DataHubWatchlistUpdatedNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(symbolDataUpdated:)
               name:DataHubSymbolsUpdatedNotification
             object:nil];
}

#pragma mark - Data Management

- (void)loadWatchlists {
    self.watchlists = [[DataHub shared] getAllWatchlists];
    
    // Update segmented control
    [self.watchlistSelector setSegmentCount:self.watchlists.count];
    for (NSInteger i = 0; i < self.watchlists.count; i++) {
        Watchlist *watchlist = self.watchlists[i];
        [self.watchlistSelector setLabel:watchlist.name forSegment:i];
        [self.watchlistSelector setWidth:0 forSegment:i]; // Auto-size
    }
    
    // Select first watchlist if available
    if (self.watchlists.count > 0) {
        self.watchlistSelector.selectedSegment = 0;
        self.currentWatchlist = self.watchlists[0];
        [self loadSymbolsForCurrentWatchlist];
    }
}

- (void)loadSymbolsForCurrentWatchlist {
    if (!self.currentWatchlist) {
        self.symbols = @[];
        self.filteredSymbols = @[];
        [self.tableView reloadData];
        return;
    }
    
    self.symbols = [[DataHub shared] getSymbolsForWatchlist:self.currentWatchlist];
    [self applyFilter];
    [self refreshSymbolData];
}

- (void)refreshSymbolData {
    [self.loadingIndicator startAnimation:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // In a real app, you would fetch fresh data from the data source
        // For now, we'll just update from the DataHub cache
        
        NSMutableDictionary *newCache = [NSMutableDictionary dictionary];
        for (NSString *symbol in self.symbols) {
            NSDictionary *data = [[DataHub shared] getDataForSymbol:symbol];
            if (data) {
                newCache[symbol] = data;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.symbolDataCache = newCache;
            [self.tableView reloadData];
            [self.loadingIndicator stopAnimation:nil];
        });
    });
}

- (void)applyFilter {
    NSString *searchText = self.searchField.stringValue;
    
    if (searchText.length == 0) {
        self.filteredSymbols = self.symbols;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", searchText];
        self.filteredSymbols = [self.symbols filteredArrayUsingPredicate:predicate];
    }
    
    [self.tableView reloadData];
}

#pragma mark - Timer

- (void)startRefreshTimer {
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                         target:self
                                                       selector:@selector(refreshTimerFired:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)refreshTimerFired:(NSTimer *)timer {
    if (self.window && self.window.isVisible) {
        [self refreshSymbolData];
    }
}

#pragma mark - Actions

- (void)watchlistChanged:(id)sender {
    NSInteger selectedIndex = self.watchlistSelector.selectedSegment;
    if (selectedIndex >= 0 && selectedIndex < self.watchlists.count) {
        self.currentWatchlist = self.watchlists[selectedIndex];
        [self loadSymbolsForCurrentWatchlist];
    }
}

- (void)showWatchlistMenu:(id)sender {
    NSMenu *menu = [[NSMenu alloc] init];
    
    [menu addItemWithTitle:@"Manage Watchlists..." action:@selector(manageWatchlists:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"New Watchlist..." action:@selector(createWatchlist:) keyEquivalent:@""];
    
    if (self.currentWatchlist) {
        [menu addItemWithTitle:@"Rename Current..." action:@selector(renameCurrentWatchlist:) keyEquivalent:@""];
        [menu addItemWithTitle:@"Delete Current..." action:@selector(deleteCurrentWatchlist:) keyEquivalent:@""];
    }
    
    menu.delegate = self;
    
    NSPoint point = NSMakePoint(NSMinX(self.watchlistMenuButton.frame), NSMinY(self.watchlistMenuButton.frame));
    [menu popUpMenuPositioningItem:nil atLocation:point inView:self];
}

- (void)searchFieldChanged:(id)sender {
    [self applyFilter];
}

- (void)addSymbol:(id)sender {
    if (!self.currentWatchlist) {
        NSBeep();
        return;
    }
    
    AddSymbolController *controller = [[AddSymbolController alloc] initWithWatchlist:self.currentWatchlist];
    controller.completionHandler = ^(NSArray<NSString *> *symbols) {
        if (symbols.count > 0) {
            DataHub *hub = [DataHub shared];
            for (NSString *symbol in symbols) {
                [hub addSymbol:symbol toWatchlist:self.currentWatchlist];
            }
            [self loadSymbolsForCurrentWatchlist];
        }
    };
    
    [self.window.windowController.window beginSheet:controller.window
                                  completionHandler:^(NSModalResponse returnCode) {
        // Sheet closed
    }];
}

- (void)removeSymbol:(id)sender {
    NSIndexSet *selectedRows = self.tableView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray *symbolsToRemove = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.filteredSymbols.count) {
            [symbolsToRemove addObject:self.filteredSymbols[idx]];
        }
    }];
    
    DataHub *hub = [DataHub shared];
    for (NSString *symbol in symbolsToRemove) {
        [hub removeSymbol:symbol fromWatchlist:self.currentWatchlist];
    }
    
    [self loadSymbolsForCurrentWatchlist];
}

- (void)manageWatchlists:(id)sender {
    WatchlistManagerController *controller = [[WatchlistManagerController alloc] init];
    controller.completionHandler = ^(BOOL changed) {
        if (changed) {
            [self loadWatchlists];
        }
    };
    
    [self.window.windowController.window beginSheet:controller.window
                                  completionHandler:^(NSModalResponse returnCode) {
        // Sheet closed
    }];
}

- (void)createWatchlist:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Watchlist";
    alert.informativeText = @"Enter a name for the new watchlist:";
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    alert.accessoryView = input;
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *name = input.stringValue;
        if (name.length > 0) {
            [[DataHub shared] createWatchlistWithName:name];
            [self loadWatchlists];
        }
    }
}

- (void)renameCurrentWatchlist:(id)sender {
    if (!self.currentWatchlist) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Watchlist";
    alert.informativeText = @"Enter a new name:";
    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = self.currentWatchlist.name;
    alert.accessoryView = input;
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *name = input.stringValue;
        if (name.length > 0) {
            [[DataHub shared] updateWatchlistName:self.currentWatchlist newName:name];
            [self loadWatchlists];
        }
    }
}

- (void)deleteCurrentWatchlist:(id)sender {
    if (!self.currentWatchlist) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Watchlist?";
    alert.informativeText = [NSString stringWithFormat:@"Delete watchlist '%@' and all its symbols?", self.currentWatchlist.name];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [[DataHub shared] deleteWatchlist:self.currentWatchlist];
        self.currentWatchlist = nil;
        [self loadWatchlists];
    }
}

#pragma mark - Notifications

- (void)watchlistsUpdated:(NSNotification *)notification {
    [self loadWatchlists];
}

- (void)symbolDataUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    if ([self.symbols containsObject:symbol]) {
        NSDictionary *data = [[DataHub shared] getDataForSymbol:symbol];
        if (data) {
            self.symbolDataCache[symbol] = data;
            
            // Update only the affected row
            NSInteger row = [self.filteredSymbols indexOfObject:symbol];
            if (row != NSNotFound) {
                [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                           columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableView.numberOfColumns)]];
            }
        }
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredSymbols.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredSymbols.count) return nil;
    
    NSString *symbol = self.filteredSymbols[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"symbol"]) {
        return symbol;
    }
    
    NSDictionary *data = self.symbolDataCache[symbol];
    if (!data) return @"--";
    
    if ([identifier isEqualToString:@"price"]) {
        return [self.priceFormatter stringFromNumber:data[@"price"]];
    } else if ([identifier isEqualToString:@"change"]) {
        return [self.priceFormatter stringFromNumber:data[@"change"]];
    } else if ([identifier isEqualToString:@"changePercent"]) {
        return [self.percentFormatter stringFromNumber:data[@"changePercent"]];
    } else if ([identifier isEqualToString:@"volume"]) {
        NSInteger volume = [data[@"volume"] integerValue];
        if (volume > 1000000) {
            return [NSString stringWithFormat:@"%.1fM", volume / 1000000.0];
        } else if (volume > 1000) {
            return [NSString stringWithFormat:@"%.1fK", volume / 1000.0];
        }
        return [NSString stringWithFormat:@"%ld", volume];
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredSymbols.count) return nil;
    
    NSString *symbol = self.filteredSymbols[row];
    NSDictionary *data = self.symbolDataCache[symbol];
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.font = [NSFont systemFontOfSize:12];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:5],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-5],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Set text
    cellView.textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row] ?: @"";
    
    // Color coding
    if ([tableColumn.identifier isEqualToString:@"change"] || [tableColumn.identifier isEqualToString:@"changePercent"]) {
        double change = [data[@"change"] doubleValue];
        if (change > 0) {
            cellView.textField.textColor = [NSColor systemGreenColor];
        } else if (change < 0) {
            cellView.textField.textColor = [NSColor systemRedColor];
        } else {
            cellView.textField.textColor = [NSColor labelColor];
        }
    } else {
        cellView.textField.textColor = [NSColor labelColor];
    }
    
    // Bold symbol column
    if ([tableColumn.identifier isEqualToString:@"symbol"]) {
        cellView.textField.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    }
    
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    self.removeSymbolButton.enabled = (self.tableView.selectedRowIndexes.count > 0);
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return YES;
}

#pragma mark - Widget Overrides

- (void)updateData {
    [self refreshSymbolData];
}

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    state[@"widgetType"] = @(self.widgetType);
    state[@"widgetID"] = self.widgetID ?: @"";
    
    if (self.currentWatchlist) {
        state[@"currentWatchlistName"] = self.currentWatchlist.name;
    }
    
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    NSString *watchlistName = state[@"currentWatchlistName"];
    if (watchlistName) {
        for (NSInteger i = 0; i < self.watchlists.count; i++) {
            if ([self.watchlists[i].name isEqualToString:watchlistName]) {
                self.watchlistSelector.selectedSegment = i;
                self.currentWatchlist = self.watchlists[i];
                [self loadSymbolsForCurrentWatchlist];
                break;
            }
        }
    }
}

@end
