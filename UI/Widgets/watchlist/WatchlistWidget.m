//
//  WatchlistWidget.m
//  TradingApp
//
//  NEW UNIFIED WIDGET: Complete replacement for old WatchlistWidget and GeneralMarketWidget
//

#import "WatchlistWidget.h"
#import "HierarchicalWatchlistSelector.h"
#import "WatchlistProviderManager.h"
#import "DataHub.h"
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
}

#pragma mark - BaseWidget Lifecycle

- (void)setupContentView {
    [super setupContentView];
    [self setupProviderUI];
    [self setupInitialProvider];
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
    // Create our own toolbar view
    self.toolbarView = [[NSView alloc] init];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.toolbarView];
    
    // Hierarchical provider selector
    self.providerSelector = [[HierarchicalWatchlistSelector alloc] init];
    self.providerSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerSelector.selectorDelegate = self;
    [self.providerSelector configureWithProviderManager:self.providerManager];
    [self.toolbarView addSubview:self.providerSelector];
    
    // Actions button (⚙️)
    self.actionsButton = [NSButton buttonWithTitle:@"⚙️" target:self action:@selector(showActionsMenu:)];
    self.actionsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.actionsButton.toolTip = @"Actions and settings";
    [self.toolbarView addSubview:self.actionsButton];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.displayedWhenStopped = NO;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbarView addSubview:self.loadingIndicator];
    
    // Setup toolbar constraints
    [NSLayoutConstraint activateConstraints:@[
        // Provider selector
        [self.providerSelector.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:4],
        [self.providerSelector.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.providerSelector.trailingAnchor constraintEqualToAnchor:self.actionsButton.leadingAnchor constant:-4],
        
        // Actions button
        [self.actionsButton.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-4],
        [self.actionsButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.actionsButton.widthAnchor constraintEqualToConstant:24],
        
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
    self.tableView.headerView = nil; // No headers for compact display
    self.tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    
    // Enable drag and drop for symbols
    [self.tableView registerForDraggedTypes:@[NSPasteboardTypeString]];
    
    self.scrollView.documentView = self.tableView;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar at top
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:32],
        
        // Scroll view below toolbar
        [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
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

#pragma mark - Layout Management

- (void)updateLayoutForWidth:(CGFloat)width {
    self.currentWidth = width;
    
    NSInteger newVisibleColumns;
    if (width < 150) {
        newVisibleColumns = 1; // Symbol only
    } else if (width < 180) {
        newVisibleColumns = 2; // Symbol + VAR%
    } else {
        newVisibleColumns = 3; // Symbol + VAR% + Arrow
    }
    
    if (newVisibleColumns != self.visibleColumns) {
        self.visibleColumns = newVisibleColumns;
        [self reconfigureColumnsForCurrentWidth];
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
    if (!provider) return;
    
    NSLog(@"📋 WatchlistWidget: Selecting provider: %@", provider.displayName);
    
    self.currentProvider = provider;
    self.lastSelectedProviderId = provider.providerId;
    
    // Update selector display
    [self.providerSelector selectProviderWithId:provider.providerId];
    
    // Load symbols for this provider
    [self loadSymbolsForCurrentProvider];
}

- (void)loadSymbolsForCurrentProvider {
    if (!self.currentProvider) return;
    
    self.isLoadingProvider = YES;
    [self.loadingIndicator startAnimation:nil];
    
    [self.currentProvider loadSymbolsWithCompletion:^(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimation:nil];
            self.isLoadingProvider = NO;
            
            if (error) {
                NSLog(@"❌ Error loading symbols: %@", error);
                self.symbols = @[];
            } else {
                self.symbols = symbols ?: @[];
                NSLog(@"✅ Loaded %lu symbols for provider: %@",
                      (unsigned long)self.symbols.count, self.currentProvider.displayName);
            }
            
            self.displaySymbols = [self.symbols copy];
            [self.tableView reloadData];
            
            // Load quotes for visible symbols
            [self refreshQuotesForDisplaySymbols];
        });
    }];
}

- (void)refreshCurrentProvider {
    if (!self.currentProvider) return;
    
    // Clear cache for this provider's symbols
    [self.quotesCache removeAllObjects];
    
    // Reload symbols
    [self loadSymbolsForCurrentProvider];
}

#pragma mark - Data Management

- (void)refreshQuotesForDisplaySymbols {
    if (self.displaySymbols.count == 0) return;
    
    // Get quotes from DataHub (uses cache + refresh logic)
    [[DataHub shared] getQuotesForSymbols:self.displaySymbols
                               completion:^(NSDictionary<NSString *, MarketQuoteModel *> *quotes, BOOL allLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Update cache
            [self.quotesCache addEntriesFromDictionary:quotes];
            
            // Update timestamp
            self.lastQuoteUpdate = [[NSDate date] timeIntervalSince1970];
            
            // Reload table data
            [self.tableView reloadData];
            
            NSLog(@"📊 Updated quotes for %lu symbols (live: %@)",
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
        textField.font = [NSFont systemFontOfSize:11]; // Compact font
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.alignment = NSTextAlignmentLeft;
        
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        // Center the text field in the cell
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Configure cell content based on column
    if ([identifier isEqualToString:@"symbol"]) {
        cellView.textField.stringValue = symbol;
        cellView.textField.textColor = [NSColor labelColor];
        
    } else if ([identifier isEqualToString:@"change"]) {
        if (quote && quote.changePercent) {
            double changePercent = [quote.changePercent doubleValue];
            NSString *changeText = [NSString stringWithFormat:@"%.1f%%", changePercent];
            cellView.textField.stringValue = changeText;
            
            // Color coding: green positive, red negative, gray neutral
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
    // Handle sorting by column (future enhancement)
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
                                                                         action:@selector(createWatchlistFromSelection)
                                                                  keyEquivalent:@""];
            createWatchlistItem.target = self;
            [menu addItem:createWatchlistItem];
        }
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"Refresh Data"
                                                             action:@selector(refreshCurrentProvider)
                                                      keyEquivalent:@"r"];
        refreshItem.target = self;
        [menu addItem:refreshItem];
    }
    
    // Show menu
    [menu popUpMenuPositioningItem:nil atLocation:NSZeroPoint inView:sender];
}

- (BOOL)hasSelectedSymbols {
    return self.tableView.selectedRowIndexes.count > 0;
}

- (NSArray<NSString *> *)selectedSymbols {
    NSMutableArray *symbols = [NSMutableArray array];
    [self.tableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.displaySymbols.count) {
            [symbols addObject:self.displaySymbols[idx]];
        }
    }];
    return [symbols copy];
}

- (void)addSymbolToCurrentProvider:(id)sender {
    if (!self.currentProvider.canAddSymbols) return;
    
    // Show input dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Symbol";
    alert.informativeText = @"Enter symbol to add:";
    alert.alertStyle = NSAlertStyleInformational;
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"AAPL";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *symbol = input.stringValue.uppercaseString;
        if (symbol.length > 0) {
            [self addSymbol:symbol toManualWatchlist:nil];
        }
    }
}

- (void)removeSelectedSymbols:(id)sender {
    if (!self.currentProvider.canRemoveSymbols) return;
    
    NSArray<NSString *> *symbols = [self selectedSymbols];
    if (symbols.count == 0) return;
    
    // Confirm deletion
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Remove Symbols";
    alert.informativeText = [NSString stringWithFormat:@"Remove %lu selected symbols?", (unsigned long)symbols.count];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        for (NSString *symbol in symbols) {
            [self.currentProvider removeSymbol:symbol completion:^(BOOL success, NSError *error) {
                if (!success) {
                    NSLog(@"❌ Failed to remove symbol %@: %@", symbol, error);
                }
            }];
        }
        
        // Refresh provider after removals
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self refreshCurrentProvider];
        });
    }
}

#pragma mark - Public Methods

- (void)addSymbol:(NSString *)symbol toManualWatchlist:(NSString *)watchlistName {
    if (!symbol) return;
    
    // If no watchlist specified, use current provider if it's manual
    if (!watchlistName && [self.currentProvider isKindOfClass:[ManualWatchlistProvider class]]) {
        ManualWatchlistProvider *manualProvider = (ManualWatchlistProvider *)self.currentProvider;
        watchlistName = manualProvider.watchlistModel.name;
    }
    
    if (watchlistName) {
        // Find the watchlist model
        NSArray<WatchlistModel *> *watchlists = [[DataHub shared] getAllWatchlistModels];
        WatchlistModel *targetWatchlist = nil;
        
        for (WatchlistModel *wl in watchlists) {
            if ([wl.name isEqualToString:watchlistName]) {
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

#pragma mark - Widget Lifecycle

- (void)widgetDidLoad {
    [super widgetDidLoad];
    [self startDataRefreshTimer];
}

- (void)widgetWillClose {
    [self stopDataRefreshTimer];
    [super widgetWillClose];
}

- (void)dealloc {
    [self stopDataRefreshTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - BaseWidget Overrides

- (NSString *)widgetType {
    return @"WatchlistWidget";
}

- (NSDictionary *)widgetState {
    NSMutableDictionary *state = [[super widgetState] mutableCopy] ?: [NSMutableDictionary dictionary];
    
    if (self.lastSelectedProviderId) {
        state[@"lastSelectedProviderId"] = self.lastSelectedProviderId;
    }
    
    state[@"visibleColumns"] = @(self.visibleColumns);
    
    return [state copy];
}

- (void)restoreWidgetState:(NSDictionary *)state {
    [super restoreWidgetState:state];
    
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

@end
