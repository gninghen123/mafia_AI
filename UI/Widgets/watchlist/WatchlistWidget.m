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
#import "WatchlistProviders.h"

@interface WatchlistWidget () <HierarchicalWatchlistSelectorDelegate>

// Layout management
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *currentConstraints;

// ✅ FIX 2: Resize throttling properties
@property (nonatomic, strong) NSTimer *resizeThrottleTimer;
@property (nonatomic, assign) CGFloat pendingWidth;

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
    self.pendingWidth = 0;

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(viewDidResize:)
                                                  name:NSViewFrameDidChangeNotification
                                                object:self.contentView];
    // Enable frame change notifications
    self.contentView.postsBoundsChangedNotifications = YES;
    self.contentView.postsFrameChangedNotifications = YES;
}

- (void)createToolbar {
    self.toolbarView = [[NSView alloc] init];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.toolbarView];
    
    // Search field
    self.searchField = [[NSTextField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = @"Filter watchlists...";
    self.searchField.target = self;
    self.searchField.action = @selector(searchTextChanged:);
    [self.searchField.cell setWraps:NO];
    [self.searchField.cell setScrollable:YES];
    [self.toolbarView addSubview:self.searchField];
    
    // Actions button
    self.actionsButton = [NSButton buttonWithTitle:@"⚙️" target:self action:@selector(showActionsMenu:)];
    self.actionsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsButton.bezelStyle = NSBezelStyleTexturedRounded;
    [self.toolbarView addSubview:self.actionsButton];
    
    // Provider selector (Row 2)
    self.providerSelector = [[HierarchicalWatchlistSelector alloc] init];
    self.providerSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerSelector.selectorDelegate = self;
    [self.providerSelector configureWithProviderManager:self.providerManager];
    [self.toolbarView addSubview:self.providerSelector];
    
    // Loading indicator (Row 2)
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    [self.loadingIndicator setDisplayedWhenStopped:NO];
    [self.toolbarView addSubview:self.loadingIndicator];
    
    // Status label (Row 2)
    self.statusLabel = [NSTextField labelWithString:@"Ready"];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [self.toolbarView addSubview:self.statusLabel];
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
    CGFloat newWidth = self.contentView.frame.size.width;
    
    // Only process if width actually changed significantly
    if (fabs(newWidth - self.currentWidth) < 5.0) {
        return; // Skip minor width changes
    }
    
    self.pendingWidth = newWidth;
    
    // Cancel previous timer
    [self.resizeThrottleTimer invalidate];
    
    // Schedule delayed resize processing
    self.resizeThrottleTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 // 100ms delay
                                                                target:self
                                                              selector:@selector(processDelayedResize)
                                                              userInfo:nil
                                                               repeats:NO];
}

- (void)processDelayedResize {
    NSLog(@"🔄 WatchlistWidget: Processing delayed resize: %.0f -> %.0f",
          self.currentWidth, self.pendingWidth);
    [self updateLayoutForWidth:self.pendingWidth];
    self.resizeThrottleTimer = nil;
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
    
    NSLog(@"🔄 WatchlistWidget: selectProvider called with: %@ (ID: %@)",
          provider.displayName, provider.providerId);
    
    if (self.currentProvider == provider) {
        NSLog(@"📋 WatchlistWidget: Provider already selected, skipping: %@", provider.displayName);
        return;
    }
    
    if (!provider.providerId || provider.providerId.length == 0) {
        NSLog(@"❌ WatchlistWidget: Provider has invalid providerId: %@", provider);
        return;
    }
    
    NSLog(@"📋 WatchlistWidget: Selecting provider: %@ -> %@",
          self.currentProvider.displayName ?: @"none", provider.displayName);
    
    // ✅ FIX 1: Stop previous subscription before changing provider
    [self stopDataRefreshTimer];
    
    self.currentProvider = provider;
    self.lastSelectedProviderId = provider.providerId;
    
    if (!self.providerSelector.selectedProvider ||
        ![self.providerSelector.selectedProvider.providerId isEqualToString:provider.providerId]) {
        NSLog(@"🔄 WatchlistWidget: Updating selector display to: %@", provider.displayName);
        [self.providerSelector selectProviderWithId:provider.providerId];
    }
    
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
            [strongSelf applySorting];
            [strongSelf refreshQuotesForDisplaySymbols];
            
            // ✅ FIX 1: Start subscription for new symbols
            [strongSelf startDataRefreshTimer];
        });
    }];
}

- (void)refreshQuotesForDisplaySymbols {
    if (self.displaySymbols.count == 0) return;
    
    [[DataHub shared] getQuotesForSymbols:self.displaySymbols completion:^(NSDictionary<NSString *,MarketQuoteModel *> * _Nonnull quotes, BOOL allLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.quotesCache addEntriesFromDictionary:quotes];
            
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
    
    // ✅ FIX: Use DataHub subscription instead of own timer
    if (self.currentProvider.isAutoUpdating && self.displaySymbols.count > 0) {
        [[DataHub shared] subscribeToQuoteUpdatesForSymbols:self.displaySymbols];
        NSLog(@"✅ WatchlistWidget: Subscribed to DataHub quotes for %lu symbols",
              (unsigned long)self.displaySymbols.count);
        
        // Listen for quote updates from DataHub
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleQuoteUpdate:)
                                                     name:@"DataHubQuoteUpdated"
                                                   object:nil];
    }
}

- (void)stopDataRefreshTimer {
    // ✅ FIX: Unsubscribe from DataHub instead of stopping timer
    if (self.displaySymbols.count > 0) {
        for (NSString *symbol in self.displaySymbols) {
            [[DataHub shared] unsubscribeFromQuoteUpdatesForSymbol:symbol];
        }
        NSLog(@"✅ WatchlistWidget: Unsubscribed from DataHub quotes");
    }
    
    // Remove notification observer
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:@"DataHubQuoteUpdated"
                                                   object:nil];
}

- (void)handleQuoteUpdate:(NSNotification *)notification {
    // Handle quote updates from DataHub subscription
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"];
    
    if ([self.displaySymbols containsObject:symbol] && quote) {
        // Update cache
        self.quotesCache[symbol] = quote;
        
        // Re-apply sorting if needed (on main queue)
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.sortType == WatchlistSortTypeChangePercent) {
                [self applySorting];
            } else {
                [self.tableView reloadData];
            }
        });
        
        self.lastQuoteUpdate = [NSDate timeIntervalSinceReferenceDate];
    }
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
    
    // 🔧 SEZIONE 1: WATCHLIST MANAGEMENT (SEMPRE VISIBILI)
    NSMenuItem *createWatchlistItem = [[NSMenuItem alloc] initWithTitle:@"📝 Create New Watchlist..."
                                                                 action:@selector(showCreateWatchlistDialog:)
                                                          keyEquivalent:@""];
    createWatchlistItem.target = self;
    [menu addItem:createWatchlistItem];
    
    // Solo per watchlist manuali - mostra Remove option
    BOOL isManualWatchlist = [self.currentProvider isKindOfClass:[ManualWatchlistProvider class]];
    if (isManualWatchlist) {
        NSMenuItem *removeWatchlistItem = [[NSMenuItem alloc] initWithTitle:@"🗑️ Remove Current Watchlist..."
                                                                     action:@selector(showRemoveWatchlistDialog:)
                                                              keyEquivalent:@""];
        removeWatchlistItem.target = self;
        [menu addItem:removeWatchlistItem];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 🔧 SEZIONE 2: SYMBOL MANAGEMENT (SE PROVIDER SUPPORTA)
    if (self.currentProvider) {
        if (self.currentProvider.canAddSymbols) {
            NSMenuItem *addSingleItem = [[NSMenuItem alloc] initWithTitle:@"➕ Add Single Symbol..."
                                                                   action:@selector(showAddSingleSymbolDialog:)
                                                            keyEquivalent:@""];
            addSingleItem.target = self;
            [menu addItem:addSingleItem];
            
            NSMenuItem *addBulkItem = [[NSMenuItem alloc] initWithTitle:@"📊 Add Multiple Symbols..."
                                                                 action:@selector(showAddBulkSymbolsDialog:)
                                                          keyEquivalent:@""];
            addBulkItem.target = self;
            [menu addItem:addBulkItem];
        }
        
        if ([self hasSelectedSymbols]) {
            if (self.currentProvider.canRemoveSymbols) {
                NSMenuItem *removeItem = [[NSMenuItem alloc] initWithTitle:@"➖ Remove Selected Symbols"
                                                                    action:@selector(removeSelectedSymbols:)
                                                             keyEquivalent:@""];
                removeItem.target = self;
                [menu addItem:removeItem];
            }
            
            [menu addItem:[NSMenuItem separatorItem]];
            
            NSMenuItem *createFromSelectionItem = [[NSMenuItem alloc] initWithTitle:@"📋 Create Watchlist from Selection"
                                                                             action:@selector(createWatchlistFromCurrentSelection)
                                                                      keyEquivalent:@""];
            createFromSelectionItem.target = self;
            [menu addItem:createFromSelectionItem];
        }
    }
    
    // 🔧 SEZIONE 3: SEARCH & UTILITIES
    if (self.searchText.length > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *clearSearchItem = [[NSMenuItem alloc] initWithTitle:@"🔍 Clear Search Filter"
                                                                 action:@selector(clearSearch)
                                                          keyEquivalent:@""];
        clearSearchItem.target = self;
        [menu addItem:clearSearchItem];
    }
    
    // 🔧 SEZIONE 4: SORTING OPTIONS
    [menu addItem:[NSMenuItem separatorItem]];
    NSString *sortTitle = (self.sortType == WatchlistSortTypeChangePercent) ?
                         @"📈 Disable Sorting" : @"📈 Sort by Change %";
    NSMenuItem *sortItem = [[NSMenuItem alloc] initWithTitle:sortTitle
                                                      action:@selector(toggleSortByChangePercent)
                                               keyEquivalent:@""];
    sortItem.target = self;
    [menu addItem:sortItem];
    
    // Empty menu fallback
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
    [self.resizeThrottleTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Watchlist Management Actions

- (void)showCreateWatchlistDialog:(NSMenuItem *)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create New Watchlist";
    alert.informativeText = @"Enter a name for your new watchlist:";
    alert.alertStyle = NSAlertStyleInformational;
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    input.placeholderString = @"My Custom Watchlist";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *watchlistName = [input.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (watchlistName.length == 0) {
            [self showErrorAlert:@"Invalid Name" message:@"Watchlist name cannot be empty."];
            return;
        }
        
        // Check if name already exists
        NSArray<WatchlistModel *> *existingWatchlists = [[DataHub shared] getAllWatchlistModels];
        for (WatchlistModel *existing in existingWatchlists) {
            if ([existing.name.lowercaseString isEqualToString:watchlistName.lowercaseString]) {
                [self showErrorAlert:@"Name Already Exists"
                              message:[NSString stringWithFormat:@"A watchlist named '%@' already exists.", watchlistName]];
                return;
            }
        }
        
        // Create new watchlist
        WatchlistModel *newWatchlist = [[DataHub shared] createWatchlistModelWithName:watchlistName];
        if (newWatchlist) {
            // Refresh provider manager and selector
            [self.providerManager refreshAllProviders];
            [self.providerSelector rebuildMenuStructure];
            
            // Auto-select the new watchlist
            NSString *providerId = [NSString stringWithFormat:@"manual:%@", watchlistName];
            [self.providerSelector selectProviderWithId:providerId];
            
            NSLog(@"✅ Created new watchlist: %@", watchlistName);
            
            // Show success notification
            [self showSuccessAlert:@"Watchlist Created"
                           message:[NSString stringWithFormat:@"'%@' has been created successfully.", watchlistName]];
        } else {
            [self showErrorAlert:@"Creation Failed" message:@"Failed to create watchlist. Please try again."];
        }
    }
}

- (void)showRemoveWatchlistDialog:(NSMenuItem *)sender {
    if (![self.currentProvider isKindOfClass:[ManualWatchlistProvider class]]) {
        [self showErrorAlert:@"Cannot Delete" message:@"Only custom watchlists can be deleted."];
        return;
    }
    
    ManualWatchlistProvider *manualProvider = (ManualWatchlistProvider *)self.currentProvider;
    NSString *watchlistName = manualProvider.watchlistModel.name;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Watchlist";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the watchlist '%@'?\n\nThis action cannot be undone.", watchlistName];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Delete the watchlist
        [[DataHub shared] deleteWatchlistModel:manualProvider.watchlistModel];
        
        // Refresh provider manager and selector
        [self.providerManager refreshAllProviders];
        [self.providerSelector rebuildMenuStructure];
        
        // Select default provider
        [self.providerSelector selectDefaultProvider];
        
        NSLog(@"✅ Deleted watchlist: %@", watchlistName);
        
        // Show success notification
        [self showSuccessAlert:@"Watchlist Deleted"
                       message:[NSString stringWithFormat:@"'%@' has been deleted.", watchlistName]];
    }
}

#pragma mark - Symbol Management Actions

- (void)showAddSingleSymbolDialog:(NSMenuItem *)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Symbol";
    alert.informativeText = @"Enter the symbol you want to add:";
    alert.alertStyle = NSAlertStyleInformational;
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"e.g., AAPL, MSFT, GOOGL";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *symbolInput = [input.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (symbolInput.length == 0) {
            [self showErrorAlert:@"Invalid Input" message:@"Please enter a valid symbol."];
            return;
        }
        
        NSString *symbol = symbolInput.uppercaseString;
        
        // Add to current provider
        [self addSymbolToCurrentProvider:symbol];
    }
}

- (void)showAddBulkSymbolsDialog:(NSMenuItem *)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Multiple Symbols";
    alert.informativeText = @"Enter symbols separated by commas, spaces, or new lines:";
    alert.alertStyle = NSAlertStyleInformational;
    
    // Create a larger text view for bulk input
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 400, 120)];
    NSTextView *textView = [[NSTextView alloc] init];
    textView.string = @"";
    textView.font = [NSFont systemFontOfSize:13];
    scrollView.documentView = textView;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    
    // Add placeholder-like instruction
    NSTextField *instructionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 125, 400, 20)];
    instructionLabel.stringValue = @"Examples: AAPL, MSFT, GOOGL  or  AAPL MSFT GOOGL  or  AAPL\\nMSFT\\nGOOGL";
    instructionLabel.textColor = [NSColor secondaryLabelColor];
    instructionLabel.font = [NSFont systemFontOfSize:11];
    instructionLabel.bordered = NO;
    instructionLabel.editable = NO;
    instructionLabel.backgroundColor = [NSColor clearColor];
    
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 150)];
    [containerView addSubview:scrollView];
    [containerView addSubview:instructionLabel];
    
    alert.accessoryView = containerView;
    
    [alert addButtonWithTitle:@"Add All"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *input = [textView.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (input.length == 0) {
            [self showErrorAlert:@"Invalid Input" message:@"Please enter at least one symbol."];
            return;
        }
        
        // Parse symbols intelligently
        NSArray<NSString *> *symbols = [self parseSymbolsFromInput:input];
        
        if (symbols.count == 0) {
            [self showErrorAlert:@"No Valid Symbols" message:@"No valid symbols found in the input."];
            return;
        }
        
        // Add all symbols to current provider
        [self addSymbolsToCurrentProvider:symbols];
    }
}

#pragma mark - Smart Symbol Parsing

- (NSArray<NSString *> *)parseSymbolsFromInput:(NSString *)input {
    if (!input || input.length == 0) return @[];
    
    NSMutableSet<NSString *> *symbolSet = [NSMutableSet set];
    
    // Replace multiple whitespace/newlines with single space
    NSString *cleaned = [input stringByReplacingOccurrencesOfString:@"\\s+"
                                                         withString:@" "
                                                            options:NSRegularExpressionSearch
                                                              range:NSMakeRange(0, input.length)];
    
    // Split by common separators: comma, space, newline, semicolon, tab
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@", \\n\\r\\t;"];
    NSArray<NSString *> *components = [cleaned componentsSeparatedByCharactersInSet:separators];
    
    for (NSString *component in components) {
        NSString *symbol = [[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        
        // Basic validation: 1-10 characters, alphanumeric only
        if (symbol.length >= 1 && symbol.length <= 10) {
            NSCharacterSet *validCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"];
            if ([symbol rangeOfCharacterFromSet:[validCharacters invertedSet]].location == NSNotFound) {
                [symbolSet addObject:symbol];
            }
        }
    }
    
    NSArray<NSString *> *result = [[symbolSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    NSLog(@"📊 Parsed %lu unique symbols from input: %@", (unsigned long)result.count, result);
    
    return result;
}

#pragma mark - Provider Symbol Management

- (void)addSymbolsToCurrentProvider:(NSArray<NSString *> *)symbols {
    if (!self.currentProvider || !self.currentProvider.canAddSymbols) {
        [self showErrorAlert:@"Cannot Add Symbols" message:@"The current watchlist does not support adding symbols."];
        return;
    }
    
    if (![self.currentProvider isKindOfClass:[ManualWatchlistProvider class]]) {
        [self showErrorAlert:@"Bulk Add Not Supported" message:@"Bulk symbol adding is only supported for manual watchlists."];
        return;
    }
    
    ManualWatchlistProvider *manualProvider = (ManualWatchlistProvider *)self.currentProvider;
    
    // Use DataHub bulk add method
    [[DataHub shared] addSymbols:symbols toWatchlistModel:manualProvider.watchlistModel];
    
    // Refresh the provider
    [self refreshCurrentProvider];
    
    // Show success message
    [self showSuccessAlert:@"Symbols Added"
                   message:[NSString stringWithFormat:@"Successfully added %lu symbols to %@",
                           (unsigned long)symbols.count, manualProvider.watchlistModel.name]];
    
    NSLog(@"✅ Added %lu symbols to watchlist: %@", (unsigned long)symbols.count, symbols);
}

#pragma mark - UI Helper Methods

- (void)showErrorAlert:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)showSuccessAlert:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

#pragma mark - Updated Existing Methods



- (void)removeSelectedSymbols:(NSMenuItem *)sender {
    NSArray<NSString *> *selectedSymbols = [self selectedSymbols];
    
    if (selectedSymbols.count == 0) {
        [self showErrorAlert:@"No Selection" message:@"Please select symbols to remove."];
        return;
    }
    
    if (!self.currentProvider.canRemoveSymbols) {
        [self showErrorAlert:@"Cannot Remove" message:@"The current watchlist does not support removing symbols."];
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Remove Symbols";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to remove %lu selected symbol(s)?", (unsigned long)selectedSymbols.count];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Remove each selected symbol
        for (NSString *symbol in selectedSymbols) {
            [self.currentProvider removeSymbol:symbol completion:^(BOOL success, NSError * _Nullable error) {
                if (!success) {
                    NSLog(@"❌ Failed to remove symbol %@: %@", symbol, error.localizedDescription);
                }
            }];
        }
        
        // Refresh provider after all removals
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self refreshCurrentProvider];
        });
        
        NSLog(@"✅ Removed %lu symbols from watchlist", (unsigned long)selectedSymbols.count);
    }
}

@end
