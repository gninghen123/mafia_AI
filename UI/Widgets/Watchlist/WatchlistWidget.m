//
//  WatchlistWidget.m
//  mafia_AI
//

#import "WatchlistWidget.h"
#import "DataHub.h"
#import "Watchlist+CoreDataClass.h"
#import "WatchlistManagerController.h"
#import <QuartzCore/QuartzCore.h>
#import "WatchlistCellViews.h"



@implementation WatchlistWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Watchlist";
        self.title = @"Watchlist";
        self.symbolDataCache = [NSMutableDictionary dictionary];
        self.supportedImportFormats = @[@"csv", @"txt"];
        // Non chiamare loadWatchlists qui - il popup non esiste ancora!
        // [self loadWatchlists];
        // [self startRefreshTimer];
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    // Setup main container
    NSView *container = self.contentView;
    
    // Create toolbar
    NSView *toolbar = [[NSView alloc] init];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Watchlist popup selector
    self.watchlistPopup = [[NSPopUpButton alloc] init];
    self.watchlistPopup.translatesAutoresizingMaskIntoConstraints = NO;
    self.watchlistPopup.target = self;
    self.watchlistPopup.action = @selector(watchlistChanged:);
    
    // Navigation buttons
    self.previousButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameGoLeftTemplate]
                                             target:self
                                             action:@selector(navigateToPreviousWatchlist)];
    self.previousButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.previousButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.previousButton.toolTip = @"Previous watchlist (⌘[)";
    
    self.nextButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameGoRightTemplate]
                                         target:self
                                         action:@selector(navigateToNextWatchlist)];
    self.nextButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.nextButton.toolTip = @"Next watchlist (⌘])";
    
    // Favorite button
    self.favoriteButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameBookmarksTemplate]
                                             target:self
                                             action:@selector(toggleFavoriteFilter)];
    self.favoriteButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.favoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.favoriteButton.toolTip = @"Show only favorites";
    
    // Organize button
    self.organizeButton = [NSButton buttonWithTitle:@"⋮"
                                             target:self
                                             action:@selector(toggleSidebar)];
    self.organizeButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.organizeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.organizeButton.toolTip = @"Show watchlist sidebar for drag & drop";
    
    // Search field
    self.searchField = [[NSSearchField alloc] init];
    self.searchField.placeholderString = @"Filter symbols...";
    self.searchField.target = self;
    self.searchField.action = @selector(searchFieldChanged:);
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Import button
    self.importButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate]
                                           target:self
                                           action:@selector(showImportDialog)];
    self.importButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.importButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.importButton.toolTip = @"Import symbols from CSV";
    
    // Remove button
    self.removeSymbolButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameRemoveTemplate]
                                                 target:self
                                                 action:@selector(removeSelectedSymbols:)];
    self.removeSymbolButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.removeSymbolButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.removeSymbolButton.toolTip = @"Remove selected symbols";
    self.removeSymbolButton.enabled = NO;
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.displayedWhenStopped = NO;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Quick add button - semplice pulsante + accanto alla ricerca
    NSButton *quickAddButton = [NSButton buttonWithTitle:@"+"
                                                  target:self
                                                  action:@selector(showQuickAddDialog:)];
    quickAddButton.bezelStyle = NSBezelStyleTexturedRounded;
    quickAddButton.translatesAutoresizingMaskIntoConstraints = NO;
    quickAddButton.toolTip = @"Add symbols to watchlist";
    
    // Quick add bar (initially hidden)
    [self setupQuickAddBar];
    
    // Table view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.mainTableView = [[NSTableView alloc] init];
    self.mainTableView.delegate = self;
    self.mainTableView.dataSource = self;
    self.mainTableView.rowHeight = 32;
    self.mainTableView.intercellSpacing = NSMakeSize(0, 1);
    self.mainTableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    self.mainTableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    self.mainTableView.allowsMultipleSelection = YES;
    self.mainTableView.doubleAction = @selector(doubleClickedRow:);
    self.mainTableView.target = self;
    self.mainTableView.tag = 1001;
    self.mainTableView.rowHeight = 28.0;
       self.mainTableView.intercellSpacing = NSMakeSize(0, 2);
       self.mainTableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
       self.mainTableView.gridColor = [NSColor separatorColor];
       
       // Enable alternating row colors for better readability
       self.mainTableView.usesAlternatingRowBackgroundColors = YES;
       
       // Set selection highlight style
       self.mainTableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    // Enable drag and drop
    [self.mainTableView registerForDraggedTypes:@[NSPasteboardTypeString]];
    self.mainTableView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleSourceList;
    [self createTableColumns];
    self.scrollView.documentView = self.mainTableView;
    
    // Temporary sidebar for drag & drop
    [self setupTemporarySidebar];
    
    // Add to toolbar
    [toolbar addSubview:self.watchlistPopup];
    [toolbar addSubview:self.previousButton];
    [toolbar addSubview:self.nextButton];
    [toolbar addSubview:self.favoriteButton];
    [toolbar addSubview:self.organizeButton];
    [toolbar addSubview:self.searchField];
    [toolbar addSubview:quickAddButton];
    [toolbar addSubview:self.importButton];
    [toolbar addSubview:self.removeSymbolButton];
    [toolbar addSubview:self.loadingIndicator];
    
    // Add to main view
    [container addSubview:toolbar];
    [container addSubview:self.quickAddBar];
    [container addSubview:self.scrollView];
    [container addSubview:self.temporarySidebar];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar
        [toolbar.topAnchor constraintEqualToAnchor:container.topAnchor constant:5],
        [toolbar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:5],
        [toolbar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-5],
        [toolbar.heightAnchor constraintEqualToConstant:30],
        
        // Watchlist popup
        [self.watchlistPopup.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor],
        [self.watchlistPopup.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.watchlistPopup.widthAnchor constraintGreaterThanOrEqualToConstant:150],
        
        // Navigation buttons
        [self.previousButton.leadingAnchor constraintEqualToAnchor:self.watchlistPopup.trailingAnchor constant:5],
        [self.previousButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.previousButton.widthAnchor constraintEqualToConstant:25],
        
        [self.nextButton.leadingAnchor constraintEqualToAnchor:self.previousButton.trailingAnchor constant:2],
        [self.nextButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.nextButton.widthAnchor constraintEqualToConstant:25],
        
        // Favorite button
        [self.favoriteButton.leadingAnchor constraintEqualToAnchor:self.nextButton.trailingAnchor constant:5],
        [self.favoriteButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.favoriteButton.widthAnchor constraintEqualToConstant:25],
        
        // Organize button
        [self.organizeButton.leadingAnchor constraintEqualToAnchor:self.favoriteButton.trailingAnchor constant:5],
        [self.organizeButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.organizeButton.widthAnchor constraintEqualToConstant:25],
        
        // Import button
        [self.importButton.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor],
        [self.importButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.importButton.widthAnchor constraintEqualToConstant:25],
        
        // Remove button
        [self.removeSymbolButton.trailingAnchor constraintEqualToAnchor:self.importButton.leadingAnchor constant:-5],
        [self.removeSymbolButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.removeSymbolButton.widthAnchor constraintEqualToConstant:25],
        
        // Loading indicator
        [self.loadingIndicator.trailingAnchor constraintEqualToAnchor:self.removeSymbolButton.leadingAnchor constant:-10],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        // Search field
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.organizeButton.trailingAnchor constant:10],
        [self.searchField.trailingAnchor constraintEqualToAnchor:quickAddButton.leadingAnchor constant:-5],
        [self.searchField.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        // Quick add button
        [quickAddButton.trailingAnchor constraintEqualToAnchor:self.loadingIndicator.leadingAnchor constant:-5],
        [quickAddButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [quickAddButton.widthAnchor constraintEqualToConstant:30],
        
        // Quick add bar (initially hidden)
        [self.quickAddBar.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor constant:5],
        [self.quickAddBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:5],
        [self.quickAddBar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-5],
        [self.quickAddBar.heightAnchor constraintEqualToConstant:0], // Initially hidden
        
        // Table view
        [self.scrollView.topAnchor constraintEqualToAnchor:self.quickAddBar.bottomAnchor constant:5],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:5],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-5],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-5],
        
        // Temporary sidebar - posizionata sulla destra
        [self.temporarySidebar.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.temporarySidebar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-5],
        [self.temporarySidebar.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.temporarySidebar.widthAnchor constraintEqualToConstant:150]
    ]];
    
    // Ora che tutto è configurato, carica le watchlist e avvia il timer
    [self loadWatchlists];
    [self startRefreshTimer];
}

- (void)setupQuickAddBar {
    self.quickAddBar = [[NSView alloc] init];
    self.quickAddBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.quickAddBar.hidden = YES;
    
    NSTextField *label = [NSTextField labelWithString:@"Quick Add:"];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.quickAddField = [[NSTextField alloc] init];
    self.quickAddField.placeholderString = @"Enter symbols: AAPL, MSFT, GOOGL or paste from CSV...";
    self.quickAddField.translatesAutoresizingMaskIntoConstraints = NO;
    self.quickAddField.delegate = self;
    
    NSButton *addButton = [NSButton buttonWithTitle:@"Add"
                                             target:self
                                             action:@selector(quickAddSymbols:)];
    addButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSButton *closeButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameStopProgressTemplate]
                                               target:self
                                               action:@selector(hideQuickAddBar:)];
    closeButton.bezelStyle = NSBezelStyleTexturedRounded;
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.quickAddBar addSubview:label];
    [self.quickAddBar addSubview:self.quickAddField];
    [self.quickAddBar addSubview:addButton];
    [self.quickAddBar addSubview:closeButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.quickAddBar.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.quickAddBar.centerYAnchor],
        
        [self.quickAddField.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [self.quickAddField.centerYAnchor constraintEqualToAnchor:self.quickAddBar.centerYAnchor],
        
        [addButton.leadingAnchor constraintEqualToAnchor:self.quickAddField.trailingAnchor constant:10],
        [addButton.centerYAnchor constraintEqualToAnchor:self.quickAddBar.centerYAnchor],
        
        [closeButton.leadingAnchor constraintEqualToAnchor:addButton.trailingAnchor constant:5],
        [closeButton.trailingAnchor constraintEqualToAnchor:self.quickAddBar.trailingAnchor],
        [closeButton.centerYAnchor constraintEqualToAnchor:self.quickAddBar.centerYAnchor],
        [closeButton.widthAnchor constraintEqualToConstant:20]
    ]];
}

- (void)setupTemporarySidebar {
    self.temporarySidebar = [[NSView alloc] init];
    self.temporarySidebar.translatesAutoresizingMaskIntoConstraints = NO;
    self.temporarySidebar.wantsLayer = YES;
    self.temporarySidebar.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.temporarySidebar.layer.borderColor = [NSColor separatorColor].CGColor;
    self.temporarySidebar.layer.borderWidth = 1.0;
    self.temporarySidebar.hidden = YES;
    
    NSScrollView *sidebarScroll = [[NSScrollView alloc] init];
    sidebarScroll.translatesAutoresizingMaskIntoConstraints = NO;
    sidebarScroll.hasVerticalScroller = YES;
    
    self.sidebarTableView = [[NSTableView alloc] init];
    self.sidebarTableView.delegate = self;
    self.sidebarTableView.dataSource = self;
    [self.sidebarTableView registerForDraggedTypes:@[NSPasteboardTypeString]];
    self.sidebarTableView.tag = 1002;

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"watchlist"];
    column.title = @"Watchlists";
    [self.sidebarTableView addTableColumn:column];
    
    sidebarScroll.documentView = self.sidebarTableView;
    [self.temporarySidebar addSubview:sidebarScroll];
    
    [NSLayoutConstraint activateConstraints:@[
        [sidebarScroll.topAnchor constraintEqualToAnchor:self.temporarySidebar.topAnchor constant:5],
        [sidebarScroll.leadingAnchor constraintEqualToAnchor:self.temporarySidebar.leadingAnchor constant:5],
        [sidebarScroll.trailingAnchor constraintEqualToAnchor:self.temporarySidebar.trailingAnchor constant:-5],
        [sidebarScroll.bottomAnchor constraintEqualToAnchor:self.temporarySidebar.bottomAnchor constant:-5]
    ]];
}

- (void)createTableColumns {
    // Remove all existing columns
    while (self.mainTableView.tableColumns.count > 0) {
        [self.mainTableView removeTableColumn:self.mainTableView.tableColumns[0]];
    }
    
    // Symbol column (editable for adding new symbols)
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    symbolColumn.maxWidth = 120;
    [self.mainTableView addTableColumn:symbolColumn];
    
    // Price column
    NSTableColumn *priceColumn = [[NSTableColumn alloc] initWithIdentifier:@"price"];
    priceColumn.title = @"Price";
    priceColumn.width = 80;
    priceColumn.minWidth = 70;
    priceColumn.maxWidth = 100;
    [self.mainTableView addTableColumn:priceColumn];
    
    // Change column (includes both $ and %)
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change";
    changeColumn.width = 120;
    changeColumn.minWidth = 100;
    changeColumn.maxWidth = 150;
    [self.mainTableView addTableColumn:changeColumn];
    
    // Volume column
    NSTableColumn *volumeColumn = [[NSTableColumn alloc] initWithIdentifier:@"volume"];
    volumeColumn.title = @"Volume";
    volumeColumn.width = 80;
    volumeColumn.minWidth = 70;
    volumeColumn.maxWidth = 100;
    [self.mainTableView addTableColumn:volumeColumn];
    
    // Market Cap column
    NSTableColumn *marketCapColumn = [[NSTableColumn alloc] initWithIdentifier:@"marketCap"];
    marketCapColumn.title = @"Market Cap";
    marketCapColumn.width = 100;
    marketCapColumn.minWidth = 80;
    marketCapColumn.maxWidth = 120;
    [self.mainTableView addTableColumn:marketCapColumn];
}

#pragma mark - Data Management

- (void)loadWatchlists {
    self.watchlists = [[DataHub shared] getAllWatchlists];
    
    // Update popup menu
    [self.watchlistPopup removeAllItems];
    
    if (self.showOnlyFavorites) {
        // Filter to show only favorites - TEMPORANEAMENTE DISABILITATO
        // finché non aggiungiamo isFavorite al Core Data model
        /*
        NSMutableArray *favorites = [NSMutableArray array];
        for (Watchlist *watchlist in self.watchlists) {
            if (watchlist.isFavorite) {
                [favorites addObject:watchlist];
            }
        }
        self.favoriteWatchlists = favorites;
        
        for (Watchlist *watchlist in self.favoriteWatchlists) {
            [self.watchlistPopup addItemWithTitle:watchlist.name];
        }
        */
        // Per ora mostra tutte le watchlist
        for (Watchlist *watchlist in self.watchlists) {
            [self.watchlistPopup addItemWithTitle:watchlist.name];
        }
    } else {
        // Show all watchlists
        for (Watchlist *watchlist in self.watchlists) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:watchlist.name
                                                          action:nil
                                                   keyEquivalent:@""];
            // Temporaneamente disabilitato
            /*
            if (watchlist.isFavorite) {
                item.image = [NSImage imageNamed:NSImageNameBookmarksTemplate];
            }
            */
            [[self.watchlistPopup menu] addItem:item];
        }
    }
    
    // Add separator and management options
    [[self.watchlistPopup menu] addItem:[NSMenuItem separatorItem]];
    [self.watchlistPopup addItemWithTitle:@"Manage Watchlists..."];
    [self.watchlistPopup addItemWithTitle:@"New Watchlist..."];
    
    // Select first watchlist if available
    if (self.watchlists.count > 0) {
        [self.watchlistPopup selectItemAtIndex:0];
        self.currentWatchlist = self.watchlists[0];
        [self loadSymbolsForCurrentWatchlist];
    }
    
    // Update navigation buttons
    [self updateNavigationButtons];
}

- (void)loadSymbolsForCurrentWatchlist {
    if (!self.currentWatchlist) {
        self.symbols = @[];
        self.filteredSymbols = @[];
        [self.mainTableView reloadData];
        return;
    }
    
    NSMutableArray *symbolList = [[[DataHub shared] getSymbolsForWatchlist:self.currentWatchlist] mutableCopy];
    
    // Add empty row at the end for inline adding
    [symbolList addObject:@""];
    
    self.symbols = symbolList;
    [self applyFilter];
    [self refreshSymbolData];
  

}
- (void)filterSymbols {
    NSString *searchText = self.searchField.stringValue.lowercaseString;
    
    if (searchText.length == 0 && !self.showOnlyFavorites) {
        self.filteredSymbols = [self.symbols mutableCopy];
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        
        for (NSString *symbol in self.symbols) {
            BOOL matchesSearch = (searchText.length == 0 ||
                                [symbol.lowercaseString containsString:searchText]);
            
            BOOL matchesFavorite = !self.showOnlyFavorites ||
                                  [[DataHub shared] isSymbolFavorite:symbol];
            
            if (matchesSearch && matchesFavorite) {
                [filtered addObject:symbol];
            }
        }
        
        self.filteredSymbols = filtered;
    }
    
    // Always ensure there's an empty row at the end for adding new symbols
    if (self.filteredSymbols.count == 0 || self.filteredSymbols.lastObject.length > 0) {
        [self.filteredSymbols addObject:@""];
    }
    
    [self.mainTableView reloadData];
}
- (void)applyFilter {
    NSString *searchText = self.searchField.stringValue;
    
    if (searchText.length == 0) {
        self.filteredSymbols = self.symbols;
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *symbol in self.symbols) {
            if (symbol.length == 0 || [symbol.uppercaseString containsString:searchText.uppercaseString]) {
                [filtered addObject:symbol];
            }
        }
        self.filteredSymbols = filtered;
    }
    
    [self.mainTableView reloadData];
}

#pragma mark - Actions

- (void)watchlistChanged:(id)sender {
    NSInteger selectedIndex = self.watchlistPopup.indexOfSelectedItem;
    
    // Check if it's a menu action
    if (selectedIndex >= self.watchlists.count) {
        NSString *selectedTitle = self.watchlistPopup.titleOfSelectedItem;
        if ([selectedTitle isEqualToString:@"Manage Watchlists..."]) {
            [self manageWatchlists:sender];
            // Reset selection
            NSInteger currentIndex = [self.watchlists indexOfObject:self.currentWatchlist];
            if (currentIndex != NSNotFound) {
                [self.watchlistPopup selectItemAtIndex:currentIndex];
            }
        } else if ([selectedTitle isEqualToString:@"New Watchlist..."]) {
            [self createWatchlist:sender];
            // Reset selection
            NSInteger currentIndex = [self.watchlists indexOfObject:self.currentWatchlist];
            if (currentIndex != NSNotFound) {
                [self.watchlistPopup selectItemAtIndex:currentIndex];
            }
        }
        return;
    }
    
    // Normal watchlist selection
    if (selectedIndex >= 0 && selectedIndex < self.watchlists.count) {
        self.currentWatchlist = self.watchlists[selectedIndex];
        [self loadSymbolsForCurrentWatchlist];
        [self updateNavigationButtons];
    }
}

- (void)doubleClickedRow:(id)sender {
    NSInteger row = self.mainTableView.clickedRow;
    NSInteger column = self.mainTableView.clickedColumn;
    
    if (row == self.filteredSymbols.count - 1 && column >= 0) {
        // È l'ultima riga - inizia l'editing
        NSTableColumn *tableColumn = self.mainTableView.tableColumns[column];
        if ([tableColumn.identifier isEqualToString:@"symbol"]) {
            [self.mainTableView editColumn:column row:row withEvent:nil select:YES];
        }
    }
}

- (void)removeSelectedSymbols:(id)sender {
    NSIndexSet *selectedRows = self.mainTableView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray *symbolsToRemove = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.filteredSymbols.count - 1) { // Don't remove the empty last row
            NSString *symbol = self.filteredSymbols[idx];
            if (symbol.length > 0) {
                [symbolsToRemove addObject:symbol];
            }
        }
    }];
    
    if (symbolsToRemove.count > 0) {
        DataHub *hub = [DataHub shared];
        for (NSString *symbol in symbolsToRemove) {
            [hub removeSymbol:symbol fromWatchlist:self.currentWatchlist];
        }
        
        [self loadSymbolsForCurrentWatchlist];
        [self showTemporaryMessage:[NSString stringWithFormat:@"Removed %lu symbols", symbolsToRemove.count]];
    }
}

- (void)navigateToPreviousWatchlist {
    NSInteger currentIndex = [self.watchlists indexOfObject:self.currentWatchlist];
    if (currentIndex > 0) {
        [self.watchlistPopup selectItemAtIndex:currentIndex - 1];
        [self watchlistChanged:self.watchlistPopup];
    }
}

- (void)navigateToNextWatchlist {
    NSInteger currentIndex = [self.watchlists indexOfObject:self.currentWatchlist];
    if (currentIndex < self.watchlists.count - 1) {
        [self.watchlistPopup selectItemAtIndex:currentIndex + 1];
        [self watchlistChanged:self.watchlistPopup];
    }
}

- (void)updateNavigationButtons {
    NSInteger currentIndex = [self.watchlists indexOfObject:self.currentWatchlist];
    self.previousButton.enabled = (currentIndex > 0);
    self.nextButton.enabled = (currentIndex < self.watchlists.count - 1);
}

- (void)toggleFavoriteFilter {
    // TEMPORANEAMENTE DISABILITATO finché non aggiungiamo isFavorite al Core Data model
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Feature Coming Soon";
    alert.informativeText = @"The favorites feature will be available in the next update.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    return;
    
    /*
    self.showOnlyFavorites = !self.showOnlyFavorites;
    self.favoriteButton.state = self.showOnlyFavorites ? NSControlStateValueOn : NSControlStateValueOff;
    [self loadWatchlists];
    */
}

- (void)toggleSidebar:(id)sender {
    // Simple implementation without the sidebarVisible property
    BOOL isHidden = self.temporarySidebar.hidden;
    self.temporarySidebar.hidden = !isHidden;
    
    if (!isHidden) {
        // Hiding sidebar
        [NSLayoutConstraint deactivateConstraints:@[self.sidebarWidthConstraint]];
        self.sidebarWidthConstraint = [self.temporarySidebar.widthAnchor constraintEqualToConstant:0];
        [self.sidebarWidthConstraint setActive:YES];
    } else {
        // Showing sidebar
        [NSLayoutConstraint deactivateConstraints:@[self.sidebarWidthConstraint]];
        self.sidebarWidthConstraint = [self.temporarySidebar.widthAnchor constraintEqualToConstant:200];
        [self.sidebarWidthConstraint setActive:YES];
        [self.sidebarTableView reloadData];
    }
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.25;
        [self.view layoutSubtreeIfNeeded];
    }];
}

- (void)showImportDialog {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.allowsMultipleSelection = NO;
    openPanel.allowedFileTypes = self.supportedImportFormats;
    openPanel.message = @"Select a CSV file containing symbols to import";
    
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            [self importFromCSV:openPanel.URL];
        }
    }];
}

- (void)importFromCSV:(NSURL *)fileURL {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSString *csvContent = [NSString stringWithContentsOfURL:fileURL
                                                        encoding:NSUTF8StringEncoding
                                                           error:&error];
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Import Failed";
                alert.informativeText = error.localizedDescription;
                [alert runModal];
            });
            return;
        }
        
        // Parse CSV content
        NSArray *lines = [csvContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSMutableArray *symbols = [NSMutableArray array];
        
        BOOL hasHeaders = NO;
        for (NSInteger i = 0; i < lines.count; i++) {
            NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (line.length == 0) continue;
            
            // Check if first line is headers
            if (i == 0) {
                NSArray *components = [line componentsSeparatedByString:@","];
                NSString *firstComponent = [[components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
                if ([firstComponent isEqualToString:@"SYMBOL"] || [firstComponent isEqualToString:@"TICKER"]) {
                    hasHeaders = YES;
                    continue;
                }
            }
            
            // Parse line - support multiple formats
            NSArray *components = [line componentsSeparatedByString:@","];
            if (components.count > 0) {
                NSString *symbol = [[components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
                if (symbol.length > 0 && ![symbol containsString:@" "]) {
                    [symbols addObject:symbol];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self validateAndAddSymbols:symbols];
        });
    });
}

- (void)quickAddSymbols:(id)sender {
    NSString *input = self.quickAddField.stringValue;
    if (input.length > 0) {
        [self processQuickAddInput:input];
        self.quickAddField.stringValue = @"";
    }
}

- (void)processQuickAddInput:(NSString *)input {
    NSArray *symbols = [self parseSymbolInput:input];
    [self validateAndAddSymbols:symbols];
}

- (NSArray<NSString *> *)parseSymbolInput:(NSString *)input {
    NSMutableArray *symbols = [NSMutableArray array];
    
    // Remove any parentheses content (like notes)
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\([^)]*\\)"
                                                                           options:0
                                                                             error:&error];
    NSString *cleanedInput = [regex stringByReplacingMatchesInString:input
                                                             options:0
                                                               range:NSMakeRange(0, input.length)
                                                        withTemplate:@""];
    
    // Split by various delimiters
    NSCharacterSet *delimiters = [NSCharacterSet characterSetWithCharactersInString:@",;:\t\n "];
    NSArray *components = [cleanedInput componentsSeparatedByCharactersInSet:delimiters];
    
    for (NSString *component in components) {
        NSString *symbol = [[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        if (symbol.length > 0 && ![symbol containsString:@"$"] && ![symbols containsObject:symbol]) {
            [symbols addObject:symbol];
        }
    }
    
    return symbols;
}

- (void)validateAndAddSymbols:(NSArray<NSString *> *)symbols {
    if (symbols.count == 0) return;
    
    DataHub *hub = [DataHub shared];
    NSMutableArray *added = [NSMutableArray array];
    NSMutableArray *duplicates = [NSMutableArray array];
    NSMutableArray *invalid = [NSMutableArray array];
    
    for (NSString *symbol in symbols) {
        // Check if already in watchlist
        if ([self.symbols containsObject:symbol]) {
            [duplicates addObject:symbol];
            continue;
        }
        
        // Basic validation (you can enhance this)
        if (symbol.length > 0 && symbol.length <= 10) {
            [hub addSymbol:symbol toWatchlist:self.currentWatchlist];
            [added addObject:symbol];
        } else {
            [invalid addObject:symbol];
        }
    }
    
    // Reload data
    [self loadSymbolsForCurrentWatchlist];
    
    // Show feedback
    NSMutableString *message = [NSMutableString string];
    if (added.count > 0) {
        [message appendFormat:@"Added %lu symbols", added.count];
    }
    if (duplicates.count > 0) {
        if (message.length > 0) [message appendString:@"\n"];
        [message appendFormat:@"%lu duplicates skipped", duplicates.count];
    }
    if (invalid.count > 0) {
        if (message.length > 0) [message appendString:@"\n"];
        [message appendFormat:@"%lu invalid symbols", invalid.count];
    }
    
    if (message.length > 0) {
        [self showTemporaryMessage:message];
    }
}

- (void)showTemporaryMessage:(NSString *)message {
    // Show a temporary overlay message
    NSTextField *messageLabel = [NSTextField labelWithString:message];
    messageLabel.backgroundColor = [NSColor controlAccentColor];
    messageLabel.textColor = [NSColor controlTextColor];
    messageLabel.drawsBackground = YES;
    messageLabel.bordered = NO;
    messageLabel.editable = NO;
    messageLabel.alignment = NSTextAlignmentCenter;
    messageLabel.font = [NSFont systemFontOfSize:11];
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    messageLabel.wantsLayer = YES;
    messageLabel.layer.cornerRadius = 4.0;
    
    [self.contentView addSubview:messageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [messageLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:40],
        [messageLabel.widthAnchor constraintGreaterThanOrEqualToConstant:200],
        [messageLabel.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // Fade out and remove after 2 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.5;
            messageLabel.animator.alphaValue = 0.0;
        } completionHandler:^{
            [messageLabel removeFromSuperview];
        }];
    });
}

- (void)hideQuickAddBar:(id)sender {
    self.quickAddBar.hidden = YES;
    // Update constraint
    for (NSLayoutConstraint *constraint in self.quickAddBar.constraints) {
        if (constraint.firstAttribute == NSLayoutAttributeHeight) {
            constraint.constant = 0;
            break;
        }
    }
}

- (void)manageWatchlists:(id)sender {
    WatchlistManagerController *controller = [[WatchlistManagerController alloc] init];
    controller.completionHandler = ^(BOOL changed) {
        if (changed) {
            [self loadWatchlists];
        }
    };
    
    [self.view.window.windowController.window beginSheet:controller.window
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

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView.tag == 1002) {
        return self.watchlists.count;
    }
    
    // Main table - always show one extra row for adding new symbols
    NSInteger count = self.filteredSymbols.count;
    
    // Ensure we always have an empty row at the end
    if (count == 0 || self.filteredSymbols.lastObject.length > 0) {
        // Add empty string to allow new symbol entry
        [self.filteredSymbols addObject:@""];
        count = self.filteredSymbols.count;
    }
    
    return count;
}

#pragma mark - NSTableViewDelegate - VIEW-BASED Implementation





- (void)flashRow:(NSInteger)row color:(NSColor *)color {
    NSTableCellView *cellView = [self.mainTableView viewAtColumn:0 row:row makeIfNecessary:YES];
    if (cellView) {
        CALayer *flashLayer = [CALayer layer];
        flashLayer.backgroundColor = color.CGColor;
        flashLayer.opacity = 0.3;
        flashLayer.frame = cellView.bounds;
        [cellView.layer addSublayer:flashLayer];
        
        CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeOut.fromValue = @0.3;
        fadeOut.toValue = @0.0;
        fadeOut.duration = 0.5;
        fadeOut.removedOnCompletion = YES;
        
        [flashLayer addAnimation:fadeOut forKey:@"fadeOut"];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [flashLayer removeFromSuperlayer];
        });
    }
}

#pragma mark - NSTableViewDelegate



- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Only allow editing the symbol column on the last row
    return [tableColumn.identifier isEqualToString:@"symbol"] && row == self.filteredSymbols.count - 1;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = notification.object;
    
    if (tableView == self.mainTableView) {
        // Update remove button state
        NSIndexSet *selectedRows = tableView.selectedRowIndexes;
        BOOL hasSelection = selectedRows.count > 0;
        BOOL lastRowSelected = [selectedRows containsIndex:self.filteredSymbols.count - 1];
        
        // Don't allow removing the empty last row
        self.removeSymbolButton.enabled = hasSelection && !lastRowSelected;
    }
}
#pragma mark - Drag and Drop
- (void)setupDragAndDropVisualFeedback {
    // This should be called in setupUI after creating the table views
    
    // For main table
    self.mainTableView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleRegular;
    [self.mainTableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    
    // For sidebar
    self.sidebarTableView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleGap;
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    if (tableView.tag != 1001) return NO;
    
    // Don't allow dragging the empty last row
    NSUInteger lastRow = self.filteredSymbols.count - 1;
    if ([rowIndexes containsIndex:lastRow]) {
        NSMutableIndexSet *adjustedIndexes = [rowIndexes mutableCopy];
        [adjustedIndexes removeIndex:lastRow];
        if (adjustedIndexes.count == 0) return NO;
        rowIndexes = adjustedIndexes;
    }
    
    NSMutableArray *symbols = [NSMutableArray array];
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.filteredSymbols.count) {
            NSString *symbol = self.filteredSymbols[idx];
            if (symbol.length > 0) {
                [symbols addObject:symbol];
            }
        }
    }];
    
    if (symbols.count > 0) {
        self.draggedSymbols = symbols;
        [pboard declareTypes:@[NSPasteboardTypeString] owner:self];
        [pboard setString:[symbols componentsJoinedByString:@","] forType:NSPasteboardTypeString];
        return YES;
    }
    
    return NO;
}
/*
- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    if (tableView.tag != 1001) return NO;
    
    // Don't allow dragging the empty last row
    if ([rowIndexes containsIndex:self.filteredSymbols.count - 1]) return NO;
    
    NSMutableArray *symbols = [NSMutableArray array];
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.filteredSymbols.count) {
            NSString *symbol = self.filteredSymbols[idx];
            if (symbol.length > 0) {
                [symbols addObject:symbol];
            }
        }
    }];
    
    if (symbols.count > 0) {
        self.draggedSymbols = symbols;
        [pboard declareTypes:@[NSPasteboardTypeString] owner:self];
        [pboard setString:[symbols componentsJoinedByString:@","] forType:NSPasteboardTypeString];
        return YES;
    }
    
    return NO;
}
*/
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    if (tableView.tag == 1002 && self.draggedSymbols.count > 0) {
        // Allow drop on watchlists in sidebar
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    if (tableView.tag == 1002 && row < self.watchlists.count) {
        Watchlist *targetWatchlist = self.watchlists[row];
        DataHub *hub = [DataHub shared];
        
        for (NSString *symbol in self.draggedSymbols) {
            [hub addSymbol:symbol toWatchlist:targetWatchlist];
        }
        
        // Show feedback
        [self showTemporaryMessage:[NSString stringWithFormat:@"Added %lu symbols to %@",
                                    self.draggedSymbols.count, targetWatchlist.name]];
        
        self.draggedSymbols = nil;
        return YES;
    }
    
    return NO;
}

#pragma mark - Timer

- (void)startRefreshTimer {
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                         target:self
                                                       selector:@selector(refreshTimerFired:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)refreshTimerFired:(NSTimer *)timer {
    if (self.view.window && self.view.window.isVisible) {
        [self refreshSymbolData];
    }
}

- (void)refreshSymbolData {
    [self.loadingIndicator startAnimation:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *newCache = [NSMutableDictionary dictionary];
        for (NSString *symbol in self.symbols) {
            if (symbol.length > 0) {
                NSDictionary *data = [[DataHub shared] getDataForSymbol:symbol];
                if (data) {
                    newCache[symbol] = data;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.symbolDataCache = newCache;
            [self.mainTableView reloadData];
            [self.loadingIndicator stopAnimation:nil];
        });
    });
}

#pragma mark - Keyboard Shortcuts

- (void)keyDown:(NSEvent *)event {
    if (event.modifierFlags & NSEventModifierFlagCommand) {
        NSString *key = event.charactersIgnoringModifiers;
        
        if ([key isEqualToString:@"["]) {
            [self navigateToPreviousWatchlist];
        } else if ([key isEqualToString:@"]"]) {
            [self navigateToNextWatchlist];
        } else if ([key isEqualToString:@"a"]) {
            // Show quick add bar
            self.quickAddBar.hidden = NO;
            for (NSLayoutConstraint *constraint in self.quickAddBar.constraints) {
                if (constraint.firstAttribute == NSLayoutAttributeHeight) {
                    constraint.constant = 35;
                    break;
                }
            }
            [self.quickAddField becomeFirstResponder];
        } else if (key.integerValue >= 1 && key.integerValue <= 9) {
            // Jump to watchlist 1-9
            NSInteger index = key.integerValue - 1;
            if (index < self.watchlists.count) {
                [self.watchlistPopup selectItemAtIndex:index];
                [self watchlistChanged:self.watchlistPopup];
            }
        }
    } else {
        [super keyDown:event];
    }
}

- (void)showQuickAddDialog:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Symbols";
    alert.informativeText = @"Enter symbols separated by commas:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    input.placeholderString = @"AAPL, MSFT, GOOGL";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *symbolsText = input.stringValue;
        if (symbolsText.length > 0) {
            NSArray *symbols = [self parseSymbolInput:symbolsText];
            [self validateAndAddSymbols:symbols];
        }
    }
}

@end
