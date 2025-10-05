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
#import "WatchlistProviders.h"
#import "TagManager.h"
#import "OtherDataSource.h"           // ✅ AGGIUNGERE QUESTO IMPORT
#import "DownloadManager.h"            // ✅ AGGIUNGERE ANCHE QUESTO SE NON GIÀ PRESENTE


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

- (instancetype)initWithType:(NSString *)type {
    if (self = [super initWithType:type]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    // BaseWidget doesn't support initWithFrame, use default init
    if (self = [super initWithType:@"WatchlistWidget"]) {
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
    self.pendingWidth = 0;
    [self startTagManagerBackgroundBuild];

}

// ✅ NUOVO METODO: Avvia il build del TagManager in background
- (void)startTagManagerBackgroundBuild {
    NSLog(@"🏷️ WatchlistWidget: Starting TagManager background build at widget initialization");
    
    TagManager *tagManager = [TagManager sharedManager];
    
    // Controlla lo stato attuale del TagManager
    if (tagManager.state == TagManagerStateEmpty) {
        NSLog(@"🏷️ TagManager is empty - starting background build");
        [tagManager buildCacheInBackground];
    } else if (tagManager.state == TagManagerStateReady) {
        NSLog(@"🏷️ TagManager already ready - no build needed");
    } else if (tagManager.state == TagManagerStateBuilding) {
        NSLog(@"🏷️ TagManager already building - will wait for completion");
    } else {
        NSLog(@"🏷️ TagManager in error state - triggering rebuild");
        [tagManager invalidateAndRebuild];
    }
    
    // Ascolta per la notifica di completamento (utile per debug e eventual UI updates)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tagManagerBuildCompleted:)
                                                 name:TagManagerDidFinishBuildingNotification
                                               object:nil];
}

// ✅ NUOVO METODO: Gestisce il completamento del build del TagManager
- (void)tagManagerBuildCompleted:(NSNotification *)notification {
    BOOL success = [notification.userInfo[@"success"] boolValue];
    
    if (success) {
        NSLog(@"✅ WatchlistWidget: TagManager build completed successfully");
        
        // Opzionale: Aggiorna i provider se il selector è già configurato
        // La prossima volta che l'utente apre "Tag Lists", i provider saranno già pronti
    } else {
        NSLog(@"❌ WatchlistWidget: TagManager build failed");
    }
    
    // Rimuovi l'observer dopo il primo completamento
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:TagManagerDidFinishBuildingNotification
                                                   object:nil];
}

#pragma mark - BaseWidget Lifecycle

- (void)setupContentView {
    [super setupContentView];
    [self setupProviderUI];
    [self setupInitialProvider];
    [self startDataRefreshTimer];
    [self setupStandardContextMenu];
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
    self.tableView.rowHeight = 28;
    self.tableView.headerView = [[NSTableHeaderView alloc] init];
    self.tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    

    
    // ✅ NEW: Enable double-click
    self.tableView.target = self;
    self.tableView.doubleAction = @selector(tableViewDoubleClick:);
    
    // Enable drag and drop for symbols
    [self.tableView registerForDraggedTypes:@[NSPasteboardTypeString]];
    
    self.scrollView.documentView = self.tableView;
}

- (void)tableViewDoubleClick:(id)sender {
    NSInteger clickedRow = self.tableView.clickedRow;
    [self tableView:self.tableView didDoubleClickRow:clickedRow];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // ===== TOOLBAR CONSTRAINTS =====
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:68], // ✅ Aumentata per due righe (era 44)
        
        // ===== ROW 1: Search Field + Actions Button =====
        // Search field (sinistra, riga 1)
        [self.searchField.topAnchor constraintEqualToAnchor:self.toolbarView.topAnchor constant:8],
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:8],
        [self.searchField.heightAnchor constraintEqualToConstant:24],
        
        // Actions button (destra, riga 1)
        [self.actionsButton.topAnchor constraintEqualToAnchor:self.toolbarView.topAnchor constant:8],
        [self.actionsButton.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-8],
        [self.actionsButton.widthAnchor constraintEqualToConstant:32],
        [self.actionsButton.heightAnchor constraintEqualToConstant:24],
        
        // ✅ CRITICAL: Gap between search field and actions button
        [self.actionsButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.searchField.trailingAnchor constant:8],
        
        // ===== ROW 2: Provider Selector + Loading + Status =====
        // Provider selector (espandibile, riga 2)
        [self.providerSelector.topAnchor constraintEqualToAnchor:self.searchField.bottomAnchor constant:8],
        [self.providerSelector.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:8],
        [self.providerSelector.heightAnchor constraintEqualToConstant:24],
        
        // Loading indicator (riga 2, dopo provider selector)
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.providerSelector.centerYAnchor],
        [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.providerSelector.trailingAnchor constant:8],
        [self.loadingIndicator.widthAnchor constraintEqualToConstant:16],
        [self.loadingIndicator.heightAnchor constraintEqualToConstant:16],
        
        // Status label (destra, riga 2)
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.providerSelector.centerYAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-8],
        [self.statusLabel.heightAnchor constraintEqualToConstant:16],
        
        // ✅ CRITICAL: Provider selector width constraint - flexible but leaves space for loading/status
        [self.providerSelector.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-60],
        
        // ===== SCROLL VIEW BELOW TOOLBAR =====
        [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    NSLog(@"✅ WatchlistWidget: Setup constraints completed - toolbar with two rows");
}

- (void)configureTableColumns {
    // Remove all existing columns
    while (self.tableView.tableColumns.count > 0) {
        [self.tableView removeTableColumn:self.tableView.tableColumns.firstObject];
    }
    
    [self addSymbolColumn];
    [self addChangeColumn];
    [self addArrowColumn];
    [self updateLayoutForWidth:self.currentWidth];
}

- (void)addSymbolColumn {
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";  // ← Titolo pulito, no "| Change%"
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    symbolColumn.resizingMask = NSTableColumnUserResizingMask;
    
    // ✅ AUTOMATIC: Sorting alfabetico per simboli
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"self"
                                                                     ascending:YES];
    symbolColumn.sortDescriptorPrototype = sortDescriptor;
    
    [self.tableView addTableColumn:symbolColumn];
}

- (void)addChangeColumn {
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change%";  // ← Titolo dedicato
    changeColumn.width = 60;
    changeColumn.minWidth = 50;
    changeColumn.resizingMask = NSTableColumnUserResizingMask;
    
    // ✅ AUTOMATIC: Sorting per change% (inizia con valori più alti)
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"changePercent"
                                                                      ascending:NO
                                                                       selector:@selector(compare:)];
    changeColumn.sortDescriptorPrototype = sortDescriptor;
    
    [self.tableView addTableColumn:changeColumn];
}

- (void)addArrowColumn {
    NSTableColumn *arrowColumn = [[NSTableColumn alloc] initWithIdentifier:@"arrow"];
    arrowColumn.title = @"";  // No title
    arrowColumn.width = 20;
    arrowColumn.minWidth = 20;
    arrowColumn.maxWidth = 20;
    arrowColumn.resizingMask = NSTableColumnNoResizing;
    
    // ✅ NO SORTING: Non aggiungere sortDescriptorPrototype
    
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
            strongSelf.displaySymbols = [symbols copy];  // ← SEMPRE aggiorna

            [strongSelf refreshQuotesForDisplaySymbols];

            [strongSelf.tableView reloadData];

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
            
         
                [self.tableView reloadData];
            
            
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
    // NEW: Handle header clicks for sorti
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
    
    NSMenuItem *importFinvizItem = [[NSMenuItem alloc] initWithTitle:@"🔍 Import from Finviz..."
                                                                action:@selector(showFinvizImportDialog:)
                                                         keyEquivalent:@""];
      importFinvizItem.target = self;
      [menu addItem:importFinvizItem];
      
      NSMenuItem *createFromFinvizItem = [[NSMenuItem alloc] initWithTitle:@"📈 Create List from Finviz..."
                                                                    action:@selector(showFinvizCreateListDialog:)
                                                             keyEquivalent:@""];
      createFromFinvizItem.target = self;
      [menu addItem:createFromFinvizItem];
    
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

#pragma mark - ✅ NUOVI METODI FINVIZ

- (void)showFinvizImportDialog:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Import Symbols from Finviz";
    alert.informativeText = @"Enter a keyword to search for related stocks:";
    alert.alertStyle = NSAlertStyleInformational;
    
    // Input field per keyword
    NSTextField *keywordInput = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    keywordInput.placeholderString = @"e.g., lidar, ev, solar";
    alert.accessoryView = keywordInput;
    
    [alert addButtonWithTitle:@"Search"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        NSString *keyword = keywordInput.stringValue.lowercaseString;
        if (keyword.length > 0) {
            [self performFinvizSearch:keyword forAction:@"import"];
        }
    }
}

- (void)showFinvizCreateListDialog:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create Watchlist from Finviz";
    alert.informativeText = @"Enter a keyword to create a new watchlist:";
    alert.alertStyle = NSAlertStyleInformational;
    
    // Input field per keyword
    NSTextField *keywordInput = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    keywordInput.placeholderString = @"e.g., lidar, ev, solar";
    alert.accessoryView = keywordInput;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        NSString *keyword = keywordInput.stringValue.lowercaseString;
        if (keyword.length > 0) {
            [self performFinvizSearch:keyword forAction:@"create"];
        }
    }
}

- (void)performFinvizSearch:(NSString *)keyword forAction:(NSString *)action {
    // Show loading indicator
    [self showLoadingMessage:[NSString stringWithFormat:@"Searching Finviz for '%@'...", keyword]];
    
    // Get OtherDataSource instance
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    OtherDataSource *otherDataSource = (OtherDataSource *)[downloadManager dataSourceForType:DataSourceTypeOther];
    
    if (!otherDataSource) {
        [self hideLoadingMessage];
        [self showErrorMessage:@"Finviz search not available"];
        return;
    }
    
    // Perform search
    [otherDataSource fetchFinvizSearchResultsForKeyword:keyword
                                             completion:^(NSArray<NSString *> *symbols, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoadingMessage];
            
            if (error) {
                [self showErrorMessage:error.localizedDescription];
                return;
            }
            
            if (symbols.count == 0) {
                [self showErrorMessage:[NSString stringWithFormat:@"No symbols found for '%@'", keyword]];
                return;
            }
            
            // Show confirmation dialog
            if ([action isEqualToString:@"import"]) {
                [self showImportConfirmationForSymbols:symbols keyword:keyword];
            } else if ([action isEqualToString:@"create"]) {
                [self showCreateConfirmationForSymbols:symbols keyword:keyword];
            }
        });
    }];
}

- (void)showImportConfirmationForSymbols:(NSArray<NSString *> *)symbols keyword:(NSString *)keyword {
    NSString *symbolsList = [symbols componentsJoinedByString:@", "];
    NSString *message = [NSString stringWithFormat:@"Add %lu symbols to current watchlist?", (unsigned long)symbols.count];
    NSString *details = [NSString stringWithFormat:@"Symbols found for '%@':\n%@", keyword, symbolsList];
    
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = message;
    confirmAlert.informativeText = details;
    confirmAlert.alertStyle = NSAlertStyleInformational;
    [confirmAlert addButtonWithTitle:@"Add Symbols"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [confirmAlert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        [self addSymbolsToCurrentWatchlist:symbols];
    }
}

- (void)showCreateConfirmationForSymbols:(NSArray<NSString *> *)symbols keyword:(NSString *)keyword {
    NSString *symbolsList = [symbols componentsJoinedByString:@", "];
    NSString *watchlistName = keyword.uppercaseString;
    NSString *message = [NSString stringWithFormat:@"Create watchlist '%@' with %lu symbols?", watchlistName, (unsigned long)symbols.count];
    NSString *details = [NSString stringWithFormat:@"Symbols found:\n%@", symbolsList];
    
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = message;
    confirmAlert.informativeText = details;
    confirmAlert.alertStyle = NSAlertStyleInformational;
    [confirmAlert addButtonWithTitle:@"Create Watchlist"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [confirmAlert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        [self createNewWatchlistWithName:watchlistName symbols:symbols];
    }
}

- (void)addSymbolsToCurrentWatchlist:(NSArray<NSString *> *)symbols {
    if (![self.currentProvider isKindOfClass:[ManualWatchlistProvider class]]) {
        [self showErrorMessage:@"Can only add symbols to manual watchlists"];
        return;
    }
    
    ManualWatchlistProvider *manualProvider = (ManualWatchlistProvider *)self.currentProvider;
    DataHub *dataHub = [DataHub shared];
    
    for (NSString *symbol in symbols) {
        [dataHub addSymbol:symbol toWatchlistModel:manualProvider.watchlistModel];
    }
    
    // Refresh current view
    [self refreshCurrentProvider];
    
    // Show success message
    [self showSuccessMessage:[NSString stringWithFormat:@"Added %lu symbols to watchlist", (unsigned long)symbols.count]];
}

- (void)createNewWatchlistWithName:(NSString *)name symbols:(NSArray<NSString *> *)symbols {
    DataHub *dataHub = [DataHub shared];
    
    // ✅ FIX: Usa createWatchlistModelWithName invece di createWatchlistWithName
    // Questo restituisce WatchlistModel (runtime), non Watchlist (CoreData)
    WatchlistModel *newWatchlist = [dataHub createWatchlistModelWithName:name];
    
    if (!newWatchlist) {
        [self showErrorMessage:@"Failed to create watchlist"];
        return;
    }
    
    // Add all symbols
    for (NSString *symbol in symbols) {
        [dataHub addSymbol:symbol toWatchlistModel:newWatchlist];
    }
    
    // ✅ FIX: Usa selectProvider: invece di switchToProvider:
    ManualWatchlistProvider *newProvider = [[ManualWatchlistProvider alloc] initWithWatchlistModel:newWatchlist];
    [self selectProvider:newProvider];
    
    // Show success message
    [self showSuccessMessage:[NSString stringWithFormat:@"Created watchlist '%@' with %lu symbols", name, (unsigned long)symbols.count]];
}




#pragma mark - ✅ UTILITY METHODS FOR MESSAGES

- (void)showLoadingMessage:(NSString *)message {
    // Use existing loading indicator or create temporary status
    if (self.statusLabel) {
        self.statusLabel.stringValue = message;
    }
    [self.loadingIndicator startAnimation:nil];
}

- (void)hideLoadingMessage {
    [self.loadingIndicator stopAnimation:nil];
    [self updateStatusDisplay]; // ✅ FIX: Usa metodo corretto invece di updateStatusLabel
}

- (void)showErrorMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Finviz Search Error";
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)showSuccessMessage:(NSString *)message {
    // Could use temporary status label or notification
    if (self.statusLabel) {
        self.statusLabel.stringValue = message;
    }
    
    // Auto-clear after 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateStatusDisplay]; // ✅ FIX: Usa metodo corretto invece di updateStatusLabel
    });
}

// ✅ NUOVO: Implementa il metodo updateStatusDisplay se non esiste
- (void)updateStatusDisplay {
    if (!self.statusLabel) return;
    
    if (self.isLoadingProvider) {
        self.statusLabel.stringValue = @"Loading...";
    } else if (self.displaySymbols.count > 0) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"%lu symbols", (unsigned long)self.displaySymbols.count];
    } else {
        self.statusLabel.stringValue = @"No symbols";
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
    
   
}


- (void)dealloc {
    [self stopDataRefreshTimer];
    [self.resizeThrottleTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                       name:TagManagerDidFinishBuildingNotification
                                                     object:nil];
}

#pragma mark - setup inital provider

// ✅ SOSTITUZIONE SEMPLICE del metodo setupInitialProvider in WatchlistWidget.m

- (void)setupInitialProvider {
    // Determina quale Top Gainers caricare basandosi sull'orario di New York
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:now];
    NSInteger hour = components.hour;
    NSInteger minute = components.minute;
    NSInteger totalMinutes = hour * 60 + minute;
    
    MarketTimeframe timeframe;
    NSString *sessionName;
    
    if (totalMinutes < 570) { // Prima delle 9:30
        timeframe = MarketTimeframePreMarket;
        sessionName = @"Pre-Market";
    } else if (totalMinutes < 960) { // 9:30 - 16:00
        timeframe = MarketTimeframeOneDay;
        sessionName = @"Regular Hours";
    } else { // Dopo le 16:00
        timeframe = MarketTimeframeAfterHours;
        sessionName = @"After Hours";
    }
    
    NSLog(@"🕐 Current time: %02ld:%02ld ET - Loading Top Gainers %@", (long)hour, (long)minute, sessionName);
    
    // Crea il provider Top Gainers con il timeframe appropriato
    id<WatchlistProvider> provider = [self.providerManager createMarketListProvider:MarketListTypeTopGainers
                                                                          timeframe:timeframe];
    
    if (provider) {
        [self selectProvider:provider];
    } else {
        // Fallback al provider di default normale
        id<WatchlistProvider> defaultProvider = [self.providerManager defaultProvider];
        if (defaultProvider) {
            [self selectProvider:defaultProvider];
        }
    }
}
#pragma mark - Watchlist Management Actions

- (void)showCreateWatchlistDialog:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create New Watchlist";
    alert.informativeText = @"Enter name for the new watchlist:";
    alert.alertStyle = NSAlertStyleInformational;
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"My Watchlist";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *watchlistName = input.stringValue;
        if (watchlistName.length > 0) {
            // Check if name already exists
            NSArray<WatchlistModel *> *existingWatchlists = [[DataHub shared] getAllWatchlistModels];
            for (WatchlistModel *existing in existingWatchlists) {
                if ([existing.name.lowercaseString isEqualToString:watchlistName.lowercaseString]) {
                    [self showErrorMessage:[NSString stringWithFormat:@"A watchlist named '%@' already exists.", watchlistName]];
                    return;
                }
            }
            
            // ✅ FIX: Usa createWatchlistModelWithName (restituisce WatchlistModel)
            WatchlistModel *newWatchlist = [[DataHub shared] createWatchlistModelWithName:watchlistName];
            if (newWatchlist) {
                // Refresh provider manager to include new watchlist
                [self.providerManager refreshAllProviders];
                [self.providerSelector rebuildMenuStructure];
                
                // Auto-select the new watchlist
                NSString *providerId = [NSString stringWithFormat:@"manual:%@", watchlistName];
                [self.providerSelector selectProviderWithId:providerId];
                
                NSLog(@"✅ Created new watchlist: %@", watchlistName);
                [self showSuccessMessage:[NSString stringWithFormat:@"'%@' has been created successfully.", watchlistName]];
            } else {
                [self showErrorMessage:@"Failed to create watchlist. Please try again."];
            }
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
    
    // ✅ FIX 1: Create text field instead of text view per evitare problemi UI
        NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 400, 80)];
        textField.placeholderString = @"Enter symbols: AAPL, MSFT, GOOGL or AAPL MSFT GOOGL";
        textField.font = [NSFont systemFontOfSize:13];
  
    
    // ✅ FIX 2: Configure per multi-line input
       NSTextFieldCell *cell = (NSTextFieldCell *)textField.cell;
       [cell setWraps:YES];
       [cell setScrollable:YES];
       textField.bordered = YES;
       textField.bezeled = YES;
       textField.editable = YES;
       textField.selectable = YES;
    // Add placeholder-like instruction
    NSTextField *instructionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 85, 400, 20)];
      instructionLabel.stringValue = @"Examples: AAPL, MSFT, GOOGL  or  AAPL MSFT GOOGL";
      instructionLabel.textColor = [NSColor secondaryLabelColor];
      instructionLabel.font = [NSFont systemFontOfSize:11];
      instructionLabel.bordered = NO;
      instructionLabel.editable = NO;
      instructionLabel.backgroundColor = [NSColor clearColor];
      instructionLabel.alignment = NSTextAlignmentCenter;
      
      // ✅ FIX 5: Container view with proper layout
      NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 110)];
      [containerView addSubview:textField];
      [containerView addSubview:instructionLabel];
      
      alert.accessoryView = containerView;
      
      // ✅ FIX 6: Set initial first responder
      [alert.window setInitialFirstResponder:textField];
      
      [alert addButtonWithTitle:@"Add All"];
      [alert addButtonWithTitle:@"Cancel"];
      
      if ([alert runModal] == NSAlertFirstButtonReturn) {
          // ✅ FIX 7: Get text from field, non da textView potenzialmente problematica
          NSString *input = [textField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
          
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

    // Pattern: separatori = virgola, spazio, tab, newline, punto e virgola
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^,\\s;\\n\\r\\t]+" options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:input options:0 range:NSMakeRange(0, input.length)];
    
    for (NSTextCheckingResult *match in matches) {
        NSString *symbol = [[input substringWithRange:match.range] uppercaseString];
        
        // Validazione: 1-10 caratteri alfanumerici
        if (symbol.length >= 1 && symbol.length <= 10) {
            NSCharacterSet *validCharacters = [NSCharacterSet alphanumericCharacterSet];
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


#pragma mark - NSTableViewDelegate Extensions (AGGIUNGI QUESTI METODI)

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSIndexSet *selection = self.tableView.selectedRowIndexes;
        self.isPerformingMultiSelection = (selection.count > 1);
        
        // ✅ BROADCAST: Solo per selezione singola E chain attiva
        if (self.chainActive && !self.isPerformingMultiSelection && selection.count == 1) {
            NSArray<NSString *> *selectedSymbols = [self selectedSymbols];
            if (selectedSymbols.count == 1) {
                [self broadcastUpdate:@{
                    @"action": @"setSymbols",
                    @"symbols": selectedSymbols
                }];
                
                NSLog(@"🔗 WatchlistWidget: Single selection broadcasted to chain: %@", selectedSymbols[0]);
            }
        }
}

// ✅ NEW: Double-click support per invio immediato alla chain
- (void)tableView:(NSTableView *)tableView didDoubleClickRow:(NSInteger)row {
    if (row >= 0 && row < self.displaySymbols.count) {
        NSString *symbol = self.displaySymbols[row];
        
        // Invia alla chain anche se non è attiva (comportamento di default)
        [self broadcastUpdate:@{
            @"action": @"setSymbols",
            @"symbols": @[symbol]
        }];
        
        NSLog(@"🔗 WatchlistWidget: Double-clicked symbol '%@' sent to chain", symbol);
        
        // Feedback visivo opzionale
        [self.statusLabel setStringValue:[NSString stringWithFormat:@"Sent %@ to chain", symbol]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.statusLabel setStringValue:@"Ready"];
        });
    }
}

#pragma mark - BaseWidget Chain Integration Overrides (AGGIUNGI QUESTI METODI)

// ✅ CRITICAL: Override selectedSymbols per BaseWidget context menu
- (NSArray<NSString *> *)selectedSymbols {
    NSMutableArray<NSString *> *selected = [NSMutableArray array];
    
    NSIndexSet *selectedRows = self.tableView.selectedRowIndexes;
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx < self.displaySymbols.count) {
            [selected addObject:self.displaySymbols[idx]];
        }
    }];
    
    return [selected copy];
}

// ✅ CRITICAL: Override contextualSymbols per BaseWidget context menu
- (NSArray<NSString *> *)contextualSymbols {
    // Se non c'è selezione, usa tutti i simboli visibili
    NSArray<NSString *> *selected = [self selectedSymbols];
    return selected.count > 0 ? selected : self.displaySymbols;
}

// ✅ CRITICAL: Override contextMenuTitle per BaseWidget context menu
- (NSString *)contextMenuTitle {
    NSArray<NSString *> *selected = [self selectedSymbols];
    
    if (selected.count == 1) {
        return selected[0];
    } else if (selected.count > 1) {
        return [NSString stringWithFormat:@"Selection (%lu)", (unsigned long)selected.count];
    } else if (self.displaySymbols.count > 0) {
        return [NSString stringWithFormat:@"All Symbols (%lu)", (unsigned long)self.displaySymbols.count];
    }
    
    return @"Watchlist";
}

// ✅ NEW: Handle symbols received from chain
- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"📥 WatchlistWidget: Received %lu symbols from chain: %@",
          (unsigned long)symbols.count, symbols);
    
    // ✅ Se il provider corrente può aggiungere simboli, chiedi conferma
    if (self.currentProvider && self.currentProvider.canAddSymbols) {
        
        // Quick add per singolo simbolo
        if (symbols.count == 1) {
            NSString *symbol = symbols[0];
            
            // Verifica se già presente
            if ([self.displaySymbols containsObject:symbol]) {
                NSLog(@"⚠️ Symbol %@ already in watchlist", symbol);
                return;
            }
            
            // Aggiungi direttamente
            [self addSymbolToCurrentProvider:symbol];
            
        } else {
            // Multi-symbol: chiedi conferma
            [self promptToAddSymbolsFromChain:symbols fromWidget:sender];
        }
        
    } else {
        // Provider non supporta add - mostra solo feedback
        NSString *message = [NSString stringWithFormat:@"Received %@ from %@",
                           [symbols componentsJoinedByString:@", "],
                           NSStringFromClass([sender class])];
        [self.statusLabel setStringValue:message];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.statusLabel setStringValue:@"Ready"];
        });
    }
}

// ✅ NEW: Prompt helper for chain symbols
- (void)promptToAddSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Symbols from Chain";
    alert.informativeText = [NSString stringWithFormat:@"Add %lu symbols from %@ to current watchlist?\n\n%@",
                           (unsigned long)symbols.count,
                           NSStringFromClass([sender class]),
                           [symbols componentsJoinedByString:@", "]];
    alert.alertStyle = NSAlertStyleInformational;
    
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [self addSymbolsToCurrentProvider:symbols];
        NSLog(@"✅ Added %lu symbols from chain to watchlist", (unsigned long)symbols.count);
    }
}

#pragma mark - Enhanced Symbol Management (AGGIUNGI QUESTI METODI)

// ✅ NEW: Single symbol add helper
- (void)addSymbolToCurrentProvider:(NSString *)symbol {
    if (!self.currentProvider || !self.currentProvider.canAddSymbols) return;
    
    if ([self.currentProvider isKindOfClass:[ManualWatchlistProvider class]]) {
        ManualWatchlistProvider *manualProvider = (ManualWatchlistProvider *)self.currentProvider;
        [[DataHub shared] addSymbol:symbol toWatchlistModel:manualProvider.watchlistModel];
        
        // Refresh immediately
        [self refreshCurrentProvider];
        
        NSLog(@"✅ Added single symbol %@ to watchlist", symbol);
    }
}


#pragma mark - Widget-Specific Context Menu Items (AGGIUNGI QUESTO METODO)

// ✅ NEW: Override per aggiungere items specifici del watchlist al context menu
- (void)appendWidgetSpecificItemsToMenu:(NSMenu *)menu {
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Add to different watchlist
    NSMenuItem *addToWatchlistItem = [[NSMenuItem alloc] initWithTitle:@"📋 Add to Other Watchlist..."
                                                               action:@selector(showAddToWatchlistDialog:)
                                                        keyEquivalent:@""];
    addToWatchlistItem.target = self;
    addToWatchlistItem.representedObject = [self selectedSymbols];
    addToWatchlistItem.enabled = ([self selectedSymbols].count > 0);
    [menu addItem:addToWatchlistItem];
    
    // Remove from current watchlist (only for manual watchlists)
    if (self.currentProvider.canRemoveSymbols && [self selectedSymbols].count > 0) {
        NSMenuItem *removeItem = [[NSMenuItem alloc] initWithTitle:@"➖ Remove from Watchlist"
                                                            action:@selector(removeSelectedSymbols:)
                                                     keyEquivalent:@""];
        removeItem.target = self;
        [menu addItem:removeItem];
    }
}

// ✅ NEW: Enhanced add to watchlist dialog
- (void)showAddToWatchlistDialog:(NSMenuItem *)sender {
    NSArray<NSString *> *symbols = sender.representedObject;
    if (symbols.count == 0) return;
    
    // Get available watchlists
    NSArray<WatchlistModel *> *watchlists = [[DataHub shared] getAllWatchlistModels];
    NSMutableArray<NSString *> *watchlistNames = [NSMutableArray array];
    
    for (WatchlistModel *wl in watchlists) {
        // Skip archive watchlists and current watchlist
        if ([wl.name hasPrefix:@"Archive-"]) continue;
        if (self.currentProvider && [self.currentProvider isKindOfClass:[ManualWatchlistProvider class]]) {
            ManualWatchlistProvider *currentManual = (ManualWatchlistProvider *)self.currentProvider;
            if ([wl.name isEqualToString:currentManual.watchlistModel.name]) continue;
        }
        [watchlistNames addObject:wl.name];
    }
    
    if (watchlistNames.count == 0) {
        [self showErrorAlert:@"No Available Watchlists"
                     message:@"Create a new watchlist first or select a different current watchlist."];
        return;
    }
    
    // Show selection dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add to Watchlist";
    alert.informativeText = [NSString stringWithFormat:@"Select watchlist for %lu symbols:", (unsigned long)symbols.count];
    
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [popup addItemsWithTitles:watchlistNames];
    alert.accessoryView = popup;
    
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *selectedWatchlistName = popup.selectedItem.title;
        
        // Find and add to selected watchlist
        for (WatchlistModel *wl in watchlists) {
            if ([wl.name isEqualToString:selectedWatchlistName]) {
                [[DataHub shared] addSymbols:symbols toWatchlistModel:wl];
                NSLog(@"✅ Added %lu symbols to watchlist: %@", (unsigned long)symbols.count, selectedWatchlistName);
                break;
            }
        }
    }
}
#pragma mark - Native macOS Sorting Support

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    NSLog(@"🔄 Sorting changed: %@", tableView.sortDescriptors);
    
    // Applica il sorting ai simboli usando i sort descriptors nativi
    [self applySortDescriptors:tableView.sortDescriptors];
}

- (void)applySortDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors {
    if (sortDescriptors.count == 0) {
        // No sorting - usa ordine originale
        self.displaySymbols = [self.symbols copy];
    } else {
        // Crea array di "decorated objects" per il sorting
        NSMutableArray *decoratedSymbols = [NSMutableArray array];
        
        for (NSString *symbol in self.symbols) {
            MarketQuoteModel *quote = self.quotesCache[symbol];
            
            NSMutableDictionary *decorated = [NSMutableDictionary dictionary];
            decorated[@"symbol"] = symbol;
            decorated[@"self"] = symbol;  // Per sorting alfabetico
            decorated[@"changePercent"] = quote.changePercent ?: @(0);  // Per sorting change%
            
            [decoratedSymbols addObject:decorated];
        }
        
        // Applica sorting
        NSArray *sortedDecorated = [decoratedSymbols sortedArrayUsingDescriptors:sortDescriptors];
        
        // Estrai solo i simboli
        self.displaySymbols = [sortedDecorated valueForKey:@"symbol"];
    }
    
    // Refresh table
    [self.tableView reloadData];
}

@end
