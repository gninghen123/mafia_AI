//
//  WatchlistWidget.m
//  TradingApp
//
//  NEW UNIFIED WIDGET: Complete replacement for old WatchlistWidget and GeneralMarketWidget
//  UPDATED: Added search for watchlists and sorting for symbols
//

#import "WatchlistWidget.h"
#import "HierarchicalWatchlistSelector.h"
#import "WatchlistProviderManager.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "DataHub+WatchlistProviders.h"
#import "TradingAppTypes.h"



@interface WatchlistWidget () <HierarchicalWatchlistSelectorDelegate>

// Layout management
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *currentConstraints;

// Refresh timing
@property (nonatomic, strong) NSTimer *dataRefreshTimer;
@property (nonatomic, assign) NSTimeInterval lastQuoteUpdate;


@end

@implementation WatchlistWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    if (self = [super initWithType:type panelType:panelType]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    // BaseWidget doesn't support initWithFrame, use default init
    if (self = [super initWithType:@"WatchlistWidget" panelType:PanelTypeLeft]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    // Initialize provider system
    self.providerManager = [WatchlistProviderManager sharedManager];
    self.quotesCache = [NSMutableDictionary dictionary];
    self.symbols = @[];
    self.displaySymbols = @[];
    self.visibleColumns = 1; // Default: symbol only
    
    // NEW: Initialize search and sorting
    self.searchText = @"";
    self.sortType = WatchlistSortTypeNone;
    self.sortAscending = NO; // Start with highest change% first
}

#pragma mark - BaseWidget Lifecycle

- (void)setupContentView {
    [super setupContentView];
    [self setupProviderUI];
    [self setupInitialProvider];
    [self startDataRefreshTimer];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self startDataRefreshTimer];
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
    [self stopDataRefreshTimer];
}

#pragma mark - UI Setup

- (void)setupProviderUI {
    [self createToolbar];
    [self createTableView];
    [self setupConstraints];
    [self configureTableColumns];
    
    // Set initial width tracking
    self.currentWidth = self.contentView.frame.size.width;
    
    // Register for resize notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewDidResize:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self.contentView];
    
    // Enable frame change notifications
    self.contentView.postsBoundsChangedNotifications = YES;
    self.contentView.postsFrameChangedNotifications = YES;
}

- (void)createToolbar {
    // Create our own toolbar view - UPDATED HEIGHT
    self.toolbarView = [[NSView alloc] init];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.toolbarView];
    
    // NEW: Search field (Row 1)
    self.searchField = [[NSTextField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = @"Filter watchlists...";
    self.searchField.target = self;
    self.searchField.action = @selector(searchTextChanged:);
    [self.searchField.cell setWraps:NO];
    [self.searchField.cell setScrollable:YES];
    [self.toolbarView addSubview:self.searchField];
    
    // Actions button (Row 1 - next to search)
    self.actionsButton = [NSButton buttonWithTitle:@"⚙️" target:self action:@selector(showActionsMenu:)];
    self.actionsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.actionsButton.toolTip = @"Actions and settings";
    [self.toolbarView addSubview:self.actionsButton];
    
    // Hierarchical provider selector (Row 2)
    self.providerSelector = [[HierarchicalWatchlistSelector alloc] init];
    self.providerSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerSelector.selectorDelegate = self;
    [self.providerSelector configureWithProviderManager:self.providerManager];
    [self.toolbarView addSubview:self.providerSelector];
    
    // Loading indicator (overlays actions button)
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.displayedWhenStopped = NO;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbarView addSubview:self.loadingIndicator];
    
    // FIX #3: MAGGIORE SPACING tra search e popup (era 2px, ora 6px)
    [NSLayoutConstraint activateConstraints:@[
        // Row 1: Search field + Actions button
        [self.searchField.topAnchor constraintEqualToAnchor:self.toolbarView.topAnchor constant:2],
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:4],
        [self.searchField.trailingAnchor constraintEqualToAnchor:self.actionsButton.leadingAnchor constant:-4],
        [self.searchField.heightAnchor constraintEqualToConstant:18],
        
        [self.actionsButton.topAnchor constraintEqualToAnchor:self.toolbarView.topAnchor constant:2],
        [self.actionsButton.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-4],
        [self.actionsButton.widthAnchor constraintEqualToConstant:24],
        [self.actionsButton.heightAnchor constraintEqualToConstant:18],
        
        // Row 2: Provider selector (full width) - FIX #3: Aumentato spacing da 2px a 6px
        [self.providerSelector.topAnchor constraintEqualToAnchor:self.searchField.bottomAnchor constant:6], // CAMBIATO: era 2
        [self.providerSelector.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:4],
        [self.providerSelector.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-4],
        [self.providerSelector.heightAnchor constraintEqualToConstant:18],
        [self.providerSelector.bottomAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor constant:-2],
        
        // Loading indicator (overlays actions button)
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.actionsButton.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.actionsButton.centerYAnchor]
    ]];
}


- (void)createTableView {
    // Scroll view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    [self.contentView addSubview:self.scrollView];
    
    // Table view
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsMultipleSelection = YES;
    self.tableView.intercellSpacing = NSMakeSize(0, 1);
    self.tableView.rowHeight = 28; // Compact for narrow widgets
    // NEW: Enable header view for sorting
    self.tableView.headerView = [[NSTableHeaderView alloc] init];
    self.tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    
    // Enable drag and drop for symbols
    [self.tableView registerForDraggedTypes:@[NSPasteboardTypeString]];
    
    self.scrollView.documentView = self.tableView;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar at top - FIX #3: Aumentata height per maggiore spacing
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:44], // Aumentata da 40 per spacing
        
        // Scroll view below toolbar
        [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    // FIX #1: NESSUN constraint di larghezza fissa sul widget
    // Rimuovere eventuali constraint di width constraint sul contentView
    // Il widget ora si espande orizzontalmente seguendo il container
}

- (void)configureTableColumns {
    // Remove all existing columns
    while (self.tableView.tableColumns.count > 0) {
        [self.tableView removeTableColumn:self.tableView.tableColumns.firstObject];
    }
    
    // Start with symbol column only
    [self addSymbolColumn];
    [self updateLayoutForWidth:self.currentWidth];
}

- (void)addSymbolColumn {
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    // NEW: Add title for header with sorting indicator
    symbolColumn.title = @"Symbol | Change%";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    symbolColumn.resizingMask = NSTableColumnUserResizingMask;
    [self.tableView addTableColumn:symbolColumn];
}

- (void)addChangeColumn {
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.width = 60;
    changeColumn.minWidth = 50;
    changeColumn.resizingMask = NSTableColumnUserResizingMask;
    [self.tableView addTableColumn:changeColumn];
}

- (void)addArrowColumn {
    NSTableColumn *arrowColumn = [[NSTableColumn alloc] initWithIdentifier:@"arrow"];
    arrowColumn.width = 20;
    arrowColumn.minWidth = 20;
    arrowColumn.maxWidth = 20;
    arrowColumn.resizingMask = NSTableColumnNoResizing;
    [self.tableView addTableColumn:arrowColumn];
}

#pragma mark - NEW: Search Implementation (for Watchlists)

- (void)searchTextChanged:(NSTextField *)sender {
    self.searchText = sender.stringValue;
    
    NSLog(@"🔍 WatchlistWidget: Search text changed to: '%@'", self.searchText);
    
    // FIX #2 + FILTER: Implementazione temporanea del filtering
    // Per ora, stampa solo log - il filtering completo richiede modifiche al HierarchicalWatchlistSelector
    
    if ([self.providerSelector respondsToSelector:@selector(setFilterText:)]) {
        NSLog(@"🔍 WatchlistWidget: Passing filter text to selector");
        [self.providerSelector performSelector:@selector(setFilterText:) withObject:self.searchText];
    } else {
        NSLog(@"⚠️ WatchlistWidget: HierarchicalWatchlistSelector doesn't support setFilterText: yet");
        NSLog(@"   Current search: '%@' (filtering not implemented yet)", self.searchText);
    }
}

- (void)clearSearch {
    self.searchField.stringValue = @"";
    self.searchText = @"";
    [self searchTextChanged:self.searchField];
}

#pragma mark - NEW: Sorting Implementation (for Symbols)

- (void)applySorting {
    if (self.isApplyingSorting) return;
    self.isApplyingSorting = YES;
    
    if (self.sortType == WatchlistSortTypeNone) {
        // No sorting, use symbols as-is
        self.displaySymbols = [self.symbols copy];
    } else if (self.sortType == WatchlistSortTypeChangePercent) {
        // Sort by change percentage
        NSArray *sorted = [self.symbols sortedArrayUsingComparator:^NSComparisonResult(NSString *symbol1, NSString *symbol2) {
            MarketQuoteModel *quote1 = self.quotesCache[symbol1];
            MarketQuoteModel *quote2 = self.quotesCache[symbol2];
            
            double change1 = quote1.changePercent ? [quote1.changePercent doubleValue] : 0.0;
            double change2 = quote2.changePercent ? [quote2.changePercent doubleValue] : 0.0;
            
            if (change1 < change2) return NSOrderedAscending;
            if (change1 > change2) return NSOrderedDescending;
            
            // Secondary sort: alphabetical for ties
            return [symbol1 compare:symbol2];
        }];
        
        if (!self.sortAscending) {
            sorted = [[sorted reverseObjectEnumerator] allObjects];
        }
        
        self.displaySymbols = sorted;
    }
    
    // Update header title to show current sort
    [self updateHeaderTitle];
    
    // Reload table
    [self.tableView reloadData];
    
    self.isApplyingSorting = NO;
}

- (void)updateHeaderTitle {
    if (self.tableView.tableColumns.count == 0) return;
    
    NSTableColumn *symbolColumn = self.tableView.tableColumns.firstObject;
    NSString *title = @"Symbol | Change%";
    
    if (self.sortType == WatchlistSortTypeChangePercent) {
        NSString *arrow = self.sortAscending ? @"▲" : @"▼";
        title = [NSString stringWithFormat:@"Symbol | Change% %@", arrow];
    }
    
    symbolColumn.title = title;
}

- (void)toggleSortByChangePercent {
    if (self.sortType == WatchlistSortTypeNone) {
        // Start sorting: highest change% first
        self.sortType = WatchlistSortTypeChangePercent;
        self.sortAscending = NO;
    } else if (self.sortType == WatchlistSortTypeChangePercent && !self.sortAscending) {
        // Switch to lowest change% first
        self.sortAscending = YES;
    } else {
        // Turn off sorting
        self.sortType = WatchlistSortTypeNone;
        self.sortAscending = NO;
    }
    
    [self applySorting];
}

#pragma mark - Layout Management

- (void)updateLayoutForWidth:(CGFloat)width {
    self.currentWidth = width;
    
    NSInteger newVisibleColumns;
    
    // FIX #1: Breakpoint espansi per widget più larghi
    if (width < 120) {
        newVisibleColumns = 1; // Symbol only (molto stretto)
    } else if (width < 160) {
        newVisibleColumns = 2; // Symbol + Change% (stretto)
    } else if (width < 200) {
        newVisibleColumns = 3; // Symbol + Change% + Arrow (normale)
    } else {
        // FIX #1: Widget largo - aggiungi più colonne o espandi esistenti
        newVisibleColumns = 3; // Per ora mantieni 3, ma espandi larghezza colonne
    }
    
    if (newVisibleColumns != self.visibleColumns) {
        self.visibleColumns = newVisibleColumns;
        [self reconfigureColumnsForCurrentWidth];
    }
    
    // FIX #1: Adatta larghezza colonne per widget espansi
    [self adjustColumnWidthsForCurrentWidth:width];
}

// FIX #1: NUOVO METODO per adattare larghezza colonne
- (void)adjustColumnWidthsForCurrentWidth:(CGFloat)width {
    if (self.tableView.tableColumns.count == 0) return;
    
    // Distribuisci spazio disponibile tra le colonne esistenti
    CGFloat availableWidth = width - 20; // Margini per scrollbar
    
    if (self.visibleColumns == 1) {
        // Una colonna - usa tutto lo spazio
        NSTableColumn *symbolColumn = self.tableView.tableColumns[0];
        symbolColumn.width = availableWidth;
        
    } else if (self.visibleColumns == 2) {
        // Due colonne - symbol più largo, change fisso
        NSTableColumn *symbolColumn = self.tableView.tableColumns[0];
        NSTableColumn *changeColumn = self.tableView.tableColumns[1];
        
        changeColumn.width = 60; // Fisso
        symbolColumn.width = availableWidth - 60;
        
    } else if (self.visibleColumns == 3) {
        // Tre colonne - distribuzione intelligente
        NSTableColumn *symbolColumn = self.tableView.tableColumns[0];
        NSTableColumn *changeColumn = self.tableView.tableColumns[1];
        NSTableColumn *arrowColumn = self.tableView.tableColumns[2];
        
        arrowColumn.width = 25; // Fisso
        changeColumn.width = 65; // Fisso
        symbolColumn.width = availableWidth - 25 - 65; // Resto
    }
}


- (void)reconfigureColumnsForCurrentWidth {
    // Remove all columns
    while (self.tableView.tableColumns.count > 0) {
        [self.tableView removeTableColumn:self.tableView.tableColumns.firstObject];
    }
    
    // Add columns based on current width
    [self addSymbolColumn];
    
    if (self.visibleColumns >= 2) {
        [self addChangeColumn];
    }
    
    if (self.visibleColumns >= 3) {
        [self addArrowColumn];
    }
    
    // Update header title after reconfiguring columns
    [self updateHeaderTitle];
    
    // Reload to update display
    [self.tableView reloadData];
}

- (void)viewDidResize:(NSNotification *)notification {
    [self updateLayoutForWidth:self.contentView.frame.size.width];
}

#pragma mark - Provider Management

- (void)setupInitialProvider {
    id<WatchlistProvider> defaultProvider = [self.providerManager defaultProvider];
    if (defaultProvider) {
        [self selectProvider:defaultProvider];
    }
}


- (void)selectProvider:(id<WatchlistProvider>)provider {
    if (!provider) {
        NSLog(@"❌ WatchlistWidget: selectProvider called with nil provider");
        return;
    }
    
    // FIX #2: Logging dettagliato per debug click issue
    NSLog(@"🔄 WatchlistWidget: selectProvider called with: %@ (ID: %@)",
          provider.displayName, provider.providerId);
    
    // Prevent infinite loops
    if (self.currentProvider == provider) {
        NSLog(@"📋 WatchlistWidget: Provider already selected, skipping: %@", provider.displayName);
        return;
    }
    
    // FIX #2: Verifica che il provider abbia un ID valido
    if (!provider.providerId || provider.providerId.length == 0) {
        NSLog(@"❌ WatchlistWidget: Provider has invalid providerId: %@", provider);
        return;
    }
    
    NSLog(@"📋 WatchlistWidget: Selecting provider: %@ -> %@",
          self.currentProvider.displayName ?: @"none", provider.displayName);
    
    self.currentProvider = provider;
    self.lastSelectedProviderId = provider.providerId;
    
    // FIX #2: Update selector display WITHOUT triggering selection again
    // Ma SOLO se è diverso da quello già selezionato
    if (!self.providerSelector.selectedProvider ||
        ![self.providerSelector.selectedProvider.providerId isEqualToString:provider.providerId]) {
        NSLog(@"🔄 WatchlistWidget: Updating selector display to: %@", provider.displayName);
        [self.providerSelector selectProviderWithId:provider.providerId];
    }
    
    // Load provider data
    [self refreshCurrentProvider];
}

- (void)refreshCurrentProvider {
    if (!self.currentProvider) return;
    
    [self.loadingIndicator startAnimation:nil];
    self.isLoadingProvider = YES;
    
    __weak typeof(self) weakSelf = self;
    [self.currentProvider loadSymbolsWithCompletion:^(NSArray<NSString *> * _Nonnull symbols, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            [strongSelf.loadingIndicator stopAnimation:nil];
            strongSelf.isLoadingProvider = NO;
            
            if (error) {
                NSLog(@"❌ Error loading provider symbols: %@", error.localizedDescription);
                return;
            }
            
            strongSelf.symbols = symbols;
            
            // NEW: Apply sorting instead of direct assignment
            [strongSelf applySorting];
            
            // Load quotes for visible symbols
            [strongSelf refreshQuotesForDisplaySymbols];
        });
    }];
}

- (void)refreshQuotesForDisplaySymbols {
    if (self.displaySymbols.count == 0) return;
    
    // Use displaySymbols for quote refresh
    [[DataHub shared] getQuotesForSymbols:self.displaySymbols completion:^(NSDictionary<NSString *,MarketQuoteModel *> * _Nonnull quotes, BOOL allLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Update cache
            [self.quotesCache addEntriesFromDictionary:quotes];
            
            // NEW: Re-apply sorting since quotes changed (for change% sorting)
            if (self.sortType == WatchlistSortTypeChangePercent) {
                [self applySorting];
            } else {
                [self.tableView reloadData];
            }
            
            self.lastQuoteUpdate = [NSDate timeIntervalSinceReferenceDate];
            
            NSLog(@"✅ WatchlistWidget: Refreshed quotes for %lu symbols (allLive: %@)",
                  (unsigned long)quotes.count, allLive ? @"YES" : @"NO");
        });
    }];
}

- (void)startDataRefreshTimer {
    [self stopDataRefreshTimer];
    
    // Refresh every 30 seconds for auto-updating providers
    if (self.currentProvider.isAutoUpdating) {
        self.dataRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                                  target:self
                                                                selector:@selector(refreshQuotesForDisplaySymbols)
                                                                userInfo:nil
                                                                 repeats:YES];
    }
}

- (void)stopDataRefreshTimer {
    [self.dataRefreshTimer invalidate];
    self.dataRefreshTimer = nil;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.displaySymbols.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.displaySymbols.count) return nil;
    
    NSString *symbol = self.displaySymbols[row];
    NSString *identifier = tableColumn.identifier;
    MarketQuoteModel *quote = self.quotesCache[symbol];
    
    // Create or reuse cell view
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = identifier;
        
        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Configure cell based on column
    if ([identifier isEqualToString:@"symbol"]) {
        cellView.textField.stringValue = symbol;
        cellView.textField.font = [NSFont boldSystemFontOfSize:11];
        cellView.textField.textColor = [NSColor labelColor];
        
    } else if ([identifier isEqualToString:@"change"]) {
        if (quote && quote.changePercent) {
            double changePercent = [quote.changePercent doubleValue];
            NSString *changeString = [NSString stringWithFormat:@"%.2f%%", changePercent];
            
            cellView.textField.stringValue = changeString;
            cellView.textField.font = [NSFont systemFontOfSize:10];
            
            if (changePercent > 0.05) {
                cellView.textField.textColor = [NSColor systemGreenColor];
            } else if (changePercent < -0.05) {
                cellView.textField.textColor = [NSColor systemRedColor];
            } else {
                cellView.textField.textColor = [NSColor secondaryLabelColor];
            }
        } else {
            cellView.textField.stringValue = @"--";
            cellView.textField.textColor = [NSColor secondaryLabelColor];
        }
        
    } else if ([identifier isEqualToString:@"arrow"]) {
        if (quote && quote.changePercent) {
            double changePercent = [quote.changePercent doubleValue];
            NSString *arrow;
            NSColor *color;
            
            if (changePercent > 0.05) {
                arrow = @"▲";
                color = [NSColor systemGreenColor];
            } else if (changePercent < -0.05) {
                arrow = @"▼";
                color = [NSColor systemRedColor];
            } else {
                arrow = @"─";
                color = [NSColor secondaryLabelColor];
            }
            
            cellView.textField.stringValue = arrow;
            cellView.textField.textColor = color;
            cellView.textField.alignment = NSTextAlignmentCenter;
        } else {
            cellView.textField.stringValue = @"─";
            cellView.textField.textColor = [NSColor secondaryLabelColor];
            cellView.textField.alignment = NSTextAlignmentCenter;
        }
    }
    
    return cellView;
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
    // NEW: Handle header clicks for sorting
    if ([tableColumn.identifier isEqualToString:@"symbol"]) {
        [self toggleSortByChangePercent];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    // Handle selection changes for context menu, etc.
}

#pragma mark - Actions

- (void)showActionsMenu:(NSButton *)sender {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Provider-specific actions
    if (self.currentProvider) {
        if (self.currentProvider.canAddSymbols) {
            NSMenuItem *addItem = [[NSMenuItem alloc] initWithTitle:@"Add Symbol..."
                                                             action:@selector(addSymbolToCurrentProvider:)
                                                      keyEquivalent:@""];
            addItem.target = self;
            [menu addItem:addItem];
        }
        
        if ([self hasSelectedSymbols]) {
            if (self.currentProvider.canRemoveSymbols) {
                NSMenuItem *removeItem = [[NSMenuItem alloc] initWithTitle:@"Remove Selected"
                                                                    action:@selector(removeSelectedSymbols:)
                                                             keyEquivalent:@""];
                removeItem.target = self;
                [menu addItem:removeItem];
            }
            
            [menu addItem:[NSMenuItem separatorItem]];
            
            NSMenuItem *createWatchlistItem = [[NSMenuItem alloc] initWithTitle:@"Create Watchlist from Selection"
                                                                         action:@selector(createWatchlistFromCurrentSelection)
                                                                  keyEquivalent:@""];
            createWatchlistItem.target = self;
            [menu addItem:createWatchlistItem];
        }
        
        // Add search clear option
        if (self.searchText.length > 0) {
            [menu addItem:[NSMenuItem separatorItem]];
            NSMenuItem *clearSearchItem = [[NSMenuItem alloc] initWithTitle:@"Clear Search"
                                                                     action:@selector(clearSearch)
                                                              keyEquivalent:@""];
            clearSearchItem.target = self;
            [menu addItem:clearSearchItem];
        }
    }
    
    if (menu.itemArray.count == 0) {
        NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"No actions available"
                                                           action:nil
                                                    keyEquivalent:@""];
        emptyItem.enabled = NO;
        [menu addItem:emptyItem];
    }
    
    // Show menu below the button
    NSRect buttonFrame = sender.frame;
    NSPoint menuOrigin = NSMakePoint(NSMinX(buttonFrame), NSMinY(buttonFrame));
    [menu popUpMenuPositioningItem:nil atLocation:menuOrigin inView:sender.superview];
}

- (BOOL)hasSelectedSymbols {
    return self.tableView.selectedRowIndexes.count > 0;
}

- (NSArray<NSString *> *)selectedSymbols {
    NSMutableArray *selected = [NSMutableArray array];
    NSIndexSet *selectedRows = self.tableView.selectedRowIndexes;
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx < self.displaySymbols.count) {
            [selected addObject:self.displaySymbols[idx]];
        }
    }];
    
    return [selected copy];
}

- (void)addSymbolToCurrentProvider:(NSMenuItem *)sender {
    // Implementation for adding symbols
    NSLog(@"Add symbol requested for provider: %@", self.currentProvider.displayName);
}

- (void)removeSelectedSymbols:(NSMenuItem *)sender {
    NSArray<NSString *> *selectedSymbols = [self selectedSymbols];
    NSLog(@"Remove symbols requested: %@", selectedSymbols);
}

- (void)addSymbol:(NSString *)symbol toManualWatchlist:(NSString *)watchlistName {
    if (!symbol || !watchlistName) return;
    
    // Find the target watchlist
    NSArray<WatchlistModel *> *watchlists = [[DataHub shared] getAllWatchlistModels];
    WatchlistModel *targetWatchlist = nil;
    
    for (WatchlistModel *wl in watchlists) {
        if ([wl.name.lowercaseString isEqualToString:watchlistName]) {
            targetWatchlist = wl;
            break;
        }
    }
    
    if (targetWatchlist) {
        [[DataHub shared] addSymbol:symbol toWatchlistModel:targetWatchlist];
        
        // Refresh current provider if it's the same watchlist
        if ([self.currentProvider isKindOfClass:[ManualWatchlistProvider class]]) {
            ManualWatchlistProvider *manualProvider = (ManualWatchlistProvider *)self.currentProvider;
            if ([manualProvider.watchlistModel.name isEqualToString:watchlistName]) {
                [self refreshCurrentProvider];
            }
        }
    }
}

- (void)createWatchlistFromCurrentSelection {
    NSArray<NSString *> *selectedSymbols = [self selectedSymbols];
    if (selectedSymbols.count == 0) return;
    
    // Show name input dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create Watchlist";
    alert.informativeText = [NSString stringWithFormat:@"Create watchlist with %lu symbols:", (unsigned long)selectedSymbols.count];
    alert.alertStyle = NSAlertStyleInformational;
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"My Watchlist";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *watchlistName = input.stringValue;
        if (watchlistName.length > 0) {
            // Create new watchlist
            WatchlistModel *newWatchlist = [[DataHub shared] createWatchlistModelWithName:watchlistName];
            if (newWatchlist) {
                // Add all selected symbols
                [[DataHub shared] addSymbols:selectedSymbols toWatchlistModel:newWatchlist];
                
                // Refresh provider manager to include new watchlist
                [self.providerManager refreshAllProviders];
                [self.providerSelector rebuildMenuStructure];
                
                NSLog(@"✅ Created watchlist '%@' with %lu symbols", watchlistName, (unsigned long)selectedSymbols.count);
            }
        }
    }
}

#pragma mark - HierarchicalWatchlistSelectorDelegate

- (void)hierarchicalSelector:(id)selector didSelectProvider:(id<WatchlistProvider>)provider {
    NSLog(@"🎯 WatchlistWidget: Delegate called - hierarchicalSelector:didSelectProvider: %@", provider.displayName);
    
    // FIX #2: Verifica che sia realmente un cambio di provider
    if (self.currentProvider && [self.currentProvider.providerId isEqualToString:provider.providerId]) {
        NSLog(@"⚠️ WatchlistWidget: Same provider selected via delegate, ignoring to prevent loop");
        return;
    }
    
    // FIX #2: Chiama selectProvider ma previeni loop infiniti
    [self selectProvider:provider];
}

- (void)hierarchicalSelector:(id)selector willShowMenuForCategory:(NSString *)categoryName {
    // Lazy load providers for this category if needed
    if ([categoryName isEqualToString:@"Tag Lists"]) {
        [self.providerManager refreshTagListProviders];
    } else if ([categoryName isEqualToString:@"Archives"]) {
        [self.providerManager refreshArchiveProviders];
    }
}

#pragma mark - BaseWidget Overrides

- (NSString *)widgetType {
    return @"WatchlistWidget";
}

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy] ?: [NSMutableDictionary dictionary];
    
    if (self.lastSelectedProviderId) {
        state[@"lastSelectedProviderId"] = self.lastSelectedProviderId;
    }
    
    state[@"visibleColumns"] = @(self.visibleColumns);
    
    // NEW: Persist sorting preferences
    state[@"sortType"] = @(self.sortType);
    state[@"sortAscending"] = @(self.sortAscending);
    
    // Note: Don't persist search text (session-only)
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    NSString *providerId = state[@"lastSelectedProviderId"];
    if (providerId) {
        id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
        if (provider) {
            [self selectProvider:provider];
        }
    }
    
    NSNumber *visibleColumns = state[@"visibleColumns"];
    if (visibleColumns) {
        self.visibleColumns = [visibleColumns integerValue];
        [self reconfigureColumnsForCurrentWidth];
    }
    
    // NEW: Restore sorting preferences
    NSNumber *sortType = state[@"sortType"];
    if (sortType) {
        self.sortType = [sortType integerValue];
    }
    
    NSNumber *sortAscending = state[@"sortAscending"];
    if (sortAscending) {
        self.sortAscending = [sortAscending boolValue];
    }
    
    // Apply sorting if we have data
    if (self.symbols.count > 0) {
        [self applySorting];
    }
}

- (void)dealloc {
    [self stopDataRefreshTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
