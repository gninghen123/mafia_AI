//
//  WatchlistWidget.m - REFACTORED
//  TradingApp
//
//  PART 1: Initialization and UI Setup
//

#import "WatchlistWidget.h"
#import "WatchlistProviderManager.h"
#import "WatchlistProviders.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "DataHub+WatchlistProviders.h"
#import "TagManager.h"
#import "OtherDataSource.h"
#import "DownloadManager.h"

@interface WatchlistWidget ()

// Layout management
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *currentConstraints;
@property (nonatomic, strong) NSLayoutConstraint *scrollViewTopConstraint; // ← AGGIUNGI QUESTA


// Resize throttling
@property (nonatomic, strong) NSTimer *resizeThrottleTimer;
@property (nonatomic, assign) CGFloat pendingWidth;

// Data refresh
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
    if (self = [super initWithType:@"Watchlist"]) {
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
    NSLog(@"🔧 WatchlistWidget: commonInit");
    
    // Initialize provider system
    self.providerManager = [WatchlistProviderManager sharedManager];
    self.quotesCache = [NSMutableDictionary dictionary];
    self.symbols = @[];
    self.displaySymbols = @[];
    self.currentProviderLists = @[];
    self.visibleColumns = 1;
    
    // Initialize navigation state
    self.displayMode = WatchlistDisplayModeListSelection;
    self.selectedProviderType = WatchlistProviderTypeManual;
    self.selectedWatchlist = nil;
    
    // Initialize search
    self.searchText = @"";
    self.pendingWidth = 0;
    
    // Start tag manager background build
    [self startTagManagerBackgroundBuild];
}

- (void)startTagManagerBackgroundBuild {
    NSLog(@"🏷️ WatchlistWidget: Starting TagManager background build");
    
    TagManager *tagManager = [TagManager sharedManager];
    if (tagManager.state == TagManagerStateEmpty) {
        [tagManager buildCacheInBackground];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(tagManagerDidFinishBuilding:)
                                                     name:TagManagerDidFinishBuildingNotification
                                                   object:nil];
    }
}

- (void)tagManagerDidFinishBuilding:(NSNotification *)notification {
    NSLog(@"🏷️ WatchlistWidget: TagManager finished building");
    
    // Refresh tag providers if we're in tags mode
    if (self.selectedProviderType == WatchlistProviderTypeTags) {
        [self selectProviderType:WatchlistProviderTypeTags];
    }
}

#pragma mark - BaseWidget Overrides



#pragma mark - UI Creation

- (void)createToolbar {
    self.toolbarView = [[NSView alloc] init];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.toolbarView];
    
    // ROW 1: Search field + Actions button
    self.searchField = [[NSTextField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = @"Filter watchlists...";
    self.searchField.target = self;
    self.searchField.action = @selector(searchTextChanged:);
    [self.searchField.cell setWraps:NO];
    [self.searchField.cell setScrollable:YES];
    [self.toolbarView addSubview:self.searchField];
    
    self.actionsButton = [NSButton buttonWithTitle:@"⚙️"
                                            target:self
                                            action:@selector(showActionsMenu:)];
    self.actionsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsButton.bezelStyle = NSBezelStyleTexturedRounded;
    [self.toolbarView addSubview:self.actionsButton];
    
    // ROW 2: Segmented control for provider types
    [self createProviderTypeSegmentedControl];
    
    // Loading indicator (ROW 2, right side)
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    [self.loadingIndicator setDisplayedWhenStopped:NO];
    [self.toolbarView addSubview:self.loadingIndicator];
    
    // Status label (ROW 2, far right)
    self.statusLabel = [NSTextField labelWithString:@"Ready"];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [self.toolbarView addSubview:self.statusLabel];
}

- (void)createProviderTypeSegmentedControl {
    // Create segmented control with 5 segments
    self.providerTypeSegmented = [[NSSegmentedControl alloc] init];
    self.providerTypeSegmented.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerTypeSegmented.segmentCount = 5;
    self.providerTypeSegmented.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.providerTypeSegmented.target = self;
    self.providerTypeSegmented.action = @selector(providerTypeChanged:);
    
    [self.providerTypeSegmented setImage:[NSImage imageWithSystemSymbolName:@"list.bullet"
                                                 accessibilityDescription:nil]
                               forSegment:0];

    [self.providerTypeSegmented setImage:[NSImage imageWithSystemSymbolName:@"globe.americas.fill"
                                                 accessibilityDescription:nil]
                               forSegment:1];

    [self.providerTypeSegmented setImage:[NSImage imageWithSystemSymbolName:@"basket"
                                                 accessibilityDescription:nil]
                               forSegment:2];

    [self.providerTypeSegmented setImage:[NSImage imageWithSystemSymbolName:@"tag"
                                                 accessibilityDescription:nil]
                               forSegment:3];

    [self.providerTypeSegmented setImage:[NSImage imageWithSystemSymbolName:@"archivebox"
                                                 accessibilityDescription:nil]
                               forSegment:4];
    
    // Set equal widths for all segments
    for (NSInteger i = 0; i < 5; i++) {
        [self.providerTypeSegmented setWidth:50 forSegment:i];
    }
    
    // Select Manual by default
    [self.providerTypeSegmented setSelectedSegment:WatchlistProviderTypeManual];
    
    [self.toolbarView addSubview:self.providerTypeSegmented];
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
    //self.tableView.headerView = [[NSTableHeaderView alloc] init];
    self.tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    
    // Enable double-click
    self.tableView.target = self;
    self.tableView.doubleAction = @selector(tableViewDoubleClick:);
    
    // Enable drag and drop
    [self.tableView registerForDraggedTypes:@[NSPasteboardTypeString]];
    
    self.scrollView.documentView = self.tableView;
}
#pragma mark - Layout Constraints

- (void)setupConstraints {
    // Store the scrollView top constraint
    self.scrollViewTopConstraint = [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor];
    
    [NSLayoutConstraint activateConstraints:@[
        // ===== TOOLBAR (ora più alto per 3 righe) =====
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:90], // ← ERA 68, ORA 90
        
        // ===== ROW 1: Search + Actions =====
        [self.searchField.topAnchor constraintEqualToAnchor:self.toolbarView.topAnchor constant:8],
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:8],
        [self.searchField.heightAnchor constraintEqualToConstant:24],
        
        [self.actionsButton.topAnchor constraintEqualToAnchor:self.toolbarView.topAnchor constant:8],
        [self.actionsButton.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-8],
        [self.actionsButton.widthAnchor constraintEqualToConstant:32],
        [self.actionsButton.heightAnchor constraintEqualToConstant:24],
        
        [self.searchField.trailingAnchor constraintEqualToAnchor:self.actionsButton.leadingAnchor constant:-8],
        
        // ===== ROW 2: Segmented Control =====
        [self.providerTypeSegmented.topAnchor constraintEqualToAnchor:self.searchField.bottomAnchor constant:8],
        [self.providerTypeSegmented.centerXAnchor constraintEqualToAnchor:self.toolbarView.centerXAnchor],
        [self.providerTypeSegmented.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.toolbarView.leadingAnchor constant:8],
        [self.providerTypeSegmented.trailingAnchor constraintLessThanOrEqualToAnchor:self.toolbarView.trailingAnchor constant:-8],
        [self.providerTypeSegmented.heightAnchor constraintEqualToConstant:24],
        
        // ===== ROW 3: Loading + Status =====
        [self.loadingIndicator.topAnchor constraintEqualToAnchor:self.providerTypeSegmented.bottomAnchor constant:8],
        [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:8],
        [self.loadingIndicator.widthAnchor constraintEqualToConstant:16],
        [self.loadingIndicator.heightAnchor constraintEqualToConstant:16],
        
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.loadingIndicator.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.loadingIndicator.trailingAnchor constant:8],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.toolbarView.trailingAnchor constant:-8],
        [self.statusLabel.heightAnchor constraintEqualToConstant:16],
        
        // ===== SCROLL VIEW =====
        self.scrollViewTopConstraint,
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}
#pragma mark - Provider Type Selection

- (void)providerTypeChanged:(NSSegmentedControl *)sender {
    NSInteger selectedIndex = sender.selectedSegment;
    
    NSLog(@"🔄 WatchlistWidget: Provider type changed to index: %ld", (long)selectedIndex);
    
    [self selectProviderType:(WatchlistProviderType)selectedIndex];
}

- (void)selectProviderType:(WatchlistProviderType)type {
    NSLog(@"📋 WatchlistWidget: Selecting provider type: %ld", (long)type);
    
    self.selectedProviderType = type;
    
    NSString *categoryName = [self categoryNameForProviderType:type];
    
    // Special handling for Market Lists
    if (type == WatchlistProviderTypeMarket) {
        self.currentProviderLists = [self.providerManager createStandardMarketListProviders];
    } else {
        [self.providerManager ensureProvidersLoadedForCategory:categoryName];
        self.currentProviderLists = [self.providerManager providersForCategory:categoryName];
    }
    
    NSLog(@"   → Loaded %lu providers for category: %@",
          (unsigned long)self.currentProviderLists.count, categoryName);
    
    // Reset navigation state
    self.displayMode = WatchlistDisplayModeListSelection;
    self.selectedWatchlist = nil;
    self.currentProvider = nil;
    
    [self.tableView reloadData];
    
    // Clear search
    self.searchField.stringValue = @"";
    self.searchText = @"";
}

- (NSString *)categoryNameForProviderType:(WatchlistProviderType)type {
    switch (type) {
        case WatchlistProviderTypeManual:
            return @"Manual Watchlists";
        case WatchlistProviderTypeMarket:
            return @"Market Lists";
        case WatchlistProviderTypeBaskets:
            return @"Baskets";
        case WatchlistProviderTypeTags:
            return @"Tag Lists";
        case WatchlistProviderTypeArchives:
            return @"Archives";
        default:
            return @"Manual Watchlists";
    }
}

#pragma mark - Navigation Logic

- (void)drillDownToWatchlistAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.currentProviderLists.count) {
        NSLog(@"⚠️ WatchlistWidget: Invalid index for drill-down: %ld", (long)index);
        return;
    }
    
    id<WatchlistProvider> watchlist = self.currentProviderLists[index];
    
    NSLog(@"🔽 WatchlistWidget: Drilling down into watchlist: %@", watchlist.displayName);
    
    // Save selected watchlist
    self.selectedWatchlist = watchlist;
    
    // Load symbols for this watchlist
    [self selectProvider:watchlist];
    
    // Change to symbols mode
    self.displayMode = WatchlistDisplayModeSymbols;
    
    // Show navigation header
    NSUInteger symbolCount = watchlist.symbols.count;
    // Reload table
    [self.tableView reloadData];
}

- (void)navigateBackToListSelection {
    NSLog(@"🔼 WatchlistWidget: Navigating back to list selection");
    
    // Stop data refresh for symbols
    [self stopDataRefreshTimer];
    
    // Reset to list selection mode
    self.displayMode = WatchlistDisplayModeListSelection;
    self.selectedWatchlist = nil;
    self.currentProvider = nil;
    

    // Reload table with watchlist list
    [self.tableView reloadData];
}

#pragma mark - TableView Selection Handling

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (self.displayMode == WatchlistDisplayModeListSelection) {
        // In list mode, selection is just visual - drill down happens on double-click
        return;
    } else {
        // In symbols mode, handle symbol selection (existing logic)
        [self handleSymbolSelection];
    }
}

- (void)tableViewDoubleClick:(id)sender {
    NSInteger clickedRow = self.tableView.clickedRow;
    
    if (clickedRow < 0) return;
    
    if (self.displayMode == WatchlistDisplayModeListSelection) {
        // Double-click on watchlist → drill down
        [self drillDownToWatchlistAtIndex:clickedRow];
    } else {
        // Double-click on symbol → open chart (existing behavior)
        [self tableView:self.tableView didDoubleClickRow:clickedRow];
    }
}

- (void)handleSymbolSelection {
    // Existing symbol selection logic
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.displaySymbols.count) return;
    
    NSString *symbol = self.displaySymbols[selectedRow];
    if (self.chainActive && !self.isPerformingMultiSelection) {
        NSArray<NSString *> *selectedSymbols = [self selectedSymbols];
        if (selectedSymbols.count == 1) {
            [super broadcastUpdate:@{
                @"action": @"setSymbols",
                @"symbols": selectedSymbols
            }];
        }
    }NSLog(@"📌 WatchlistWidget: Symbol selected: %@", symbol);
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (self.displayMode == WatchlistDisplayModeListSelection) {
        // Show watchlists
        return self.currentProviderLists.count;
    } else {
        // Show symbols
        return self.displaySymbols.count;
    }
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    
    if (self.displayMode == WatchlistDisplayModeListSelection) {
        return [self cellForWatchlistAtRow:row column:tableColumn];
    } else {
        return [self cellForSymbolAtRow:row column:tableColumn];
    }
}

#pragma mark - Cell Creation - Watchlist Mode

- (NSView *)cellForWatchlistAtRow:(NSInteger)row column:(NSTableColumn *)tableColumn {
    if (row < 0 || row >= self.currentProviderLists.count) return nil;
    
    id<WatchlistProvider> provider = self.currentProviderLists[row];
    
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"symbol"]) {
        // Main column: show "Name (count)"
        NSTableCellView *cellView = [self.tableView makeViewWithIdentifier:@"WatchlistNameCell" owner:self];
        
        if (!cellView) {
            cellView = [[NSTableCellView alloc] init];
            cellView.identifier = @"WatchlistNameCell";
            
            NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
            textField.bordered = NO;
            textField.editable = NO;
            textField.drawsBackground = NO;
            textField.font = [NSFont systemFontOfSize:13];
            textField.lineBreakMode = NSLineBreakByTruncatingTail;
            textField.translatesAutoresizingMaskIntoConstraints = NO;
            [cellView addSubview:textField];
            cellView.textField = textField;
            
            [NSLayoutConstraint activateConstraints:@[
                [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:8],
                [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-8],
                [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
            ]];
        }
        
        // Format: "Watchlist Name (15)"
        NSString *displayText;
        if (provider.showCount && provider.isLoaded) {
            NSUInteger count = provider.symbols.count;
            displayText = [NSString stringWithFormat:@"%@ (%lu)",
                          provider.displayName, (unsigned long)count];
        } else {
            displayText = provider.displayName;
        }
        
        cellView.textField.stringValue = displayText;
        cellView.textField.textColor = [NSColor labelColor];
        
        return cellView;
    }
    
    // Other columns empty in list mode
    return [[NSTableCellView alloc] init];
}

#pragma mark - Cell Creation - Symbol Mode

- (NSView *)cellForSymbolAtRow:(NSInteger)row column:(NSTableColumn *)tableColumn {
    if (row < 0 || row >= self.displaySymbols.count) return nil;
    
    NSString *symbol = self.displaySymbols[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"symbol"]) {
        return [self createSymbolCellForSymbol:symbol];
    } else if ([identifier isEqualToString:@"change"]) {
        return [self createChangeCellForSymbol:symbol];
    } else if ([identifier isEqualToString:@"arrow"]) {
        return [self createArrowCellForSymbol:symbol];
    }
    
    return [[NSTableCellView alloc] init];
}

- (NSTableCellView *)createSymbolCellForSymbol:(NSString *)symbol {
    NSTableCellView *cellView = [self.tableView makeViewWithIdentifier:@"SymbolCell" owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = @"SymbolCell";
        
        NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        textField.bordered = NO;
        textField.editable = NO;
        textField.drawsBackground = NO;
        textField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        textField.lineBreakMode = NSLineBreakByTruncatingTail;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:8],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-8],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    cellView.textField.stringValue = symbol;
    cellView.textField.textColor = [NSColor labelColor];
    
    return cellView;
}

- (NSTableCellView *)createChangeCellForSymbol:(NSString *)symbol {
    NSTableCellView *cellView = [self.tableView makeViewWithIdentifier:@"ChangeCell" owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = @"ChangeCell";
        
        NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        textField.bordered = NO;
        textField.editable = NO;
        textField.drawsBackground = NO;
        textField.font = [NSFont systemFontOfSize:12];
        textField.alignment = NSTextAlignmentRight;
        textField.lineBreakMode = NSLineBreakByTruncatingTail;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Get quote data
    MarketQuoteModel *quote = self.quotesCache[symbol];
    
    if (quote && quote.changePercent.doubleValue != 0.0) {
        double changePercent = quote.changePercent.doubleValue;
        NSString *changeText = [NSString stringWithFormat:@"%+.2f%%", changePercent];
        
        cellView.textField.stringValue = changeText;
        
        if (changePercent > 0) {
            cellView.textField.textColor = [NSColor systemGreenColor];
        } else if (changePercent < 0) {
            cellView.textField.textColor = [NSColor systemRedColor];
        } else {
            cellView.textField.textColor = [NSColor secondaryLabelColor];
        }
    } else {
        cellView.textField.stringValue = @"--";
        cellView.textField.textColor = [NSColor secondaryLabelColor];
    }
    
    return cellView;
}

- (NSTableCellView *)createArrowCellForSymbol:(NSString *)symbol {
    NSTableCellView *cellView = [self.tableView makeViewWithIdentifier:@"ArrowCell" owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = @"ArrowCell";
        
        NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        textField.bordered = NO;
        textField.editable = NO;
        textField.drawsBackground = NO;
        textField.font = [NSFont systemFontOfSize:14];
        textField.alignment = NSTextAlignmentCenter;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Get quote data
    MarketQuoteModel *quote = self.quotesCache[symbol];
    
    if (quote && quote.changePercent.doubleValue != 0.0) {
        double changePercent = quote.changePercent.doubleValue;
        
        if (changePercent > 0) {
            cellView.textField.stringValue = @"↑";
            cellView.textField.textColor = [NSColor systemGreenColor];
        } else if (changePercent < 0) {
            cellView.textField.stringValue = @"↓";
            cellView.textField.textColor = [NSColor systemRedColor];
        } else {
            cellView.textField.stringValue = @"";
        }
    } else {
        cellView.textField.stringValue = @"";
    }
    
    return cellView;
}

#pragma mark - Table Configuration

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
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    symbolColumn.resizingMask = NSTableColumnUserResizingMask;
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"self"
                                                                     ascending:YES];
    symbolColumn.sortDescriptorPrototype = sortDescriptor;
    
    [self.tableView addTableColumn:symbolColumn];
}

- (void)addChangeColumn {
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change%";
    changeColumn.width = 60;
    changeColumn.minWidth = 50;
    changeColumn.resizingMask = NSTableColumnUserResizingMask;
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"changePercent"
                                                                      ascending:NO
                                                                       selector:@selector(compare:)];
    changeColumn.sortDescriptorPrototype = sortDescriptor;
    
    [self.tableView addTableColumn:changeColumn];
}

- (void)addArrowColumn {
    NSTableColumn *arrowColumn = [[NSTableColumn alloc] initWithIdentifier:@"arrow"];
    arrowColumn.title = @"";
    arrowColumn.width = 20;
    arrowColumn.minWidth = 20;
    arrowColumn.maxWidth = 20;
    arrowColumn.resizingMask = NSTableColumnNoResizing;
    
    [self.tableView addTableColumn:arrowColumn];
}

#pragma mark - Provider Selection (Existing Logic - Adapted)

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
    
    // Stop previous subscription before changing provider
    [self stopDataRefreshTimer];
    
    self.currentProvider = provider;
    self.lastSelectedProviderId = provider.providerId;
    
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
                [strongSelf.statusLabel setStringValue:@"Error loading symbols"];
                return;
            }
            
            strongSelf.symbols = symbols;
            strongSelf.displaySymbols = [symbols copy];
            
            [strongSelf.statusLabel setStringValue:[NSString stringWithFormat:@"%lu symbols",
                                                    (unsigned long)symbols.count]];

            [strongSelf refreshQuotesForDisplaySymbols];
            [strongSelf.tableView reloadData];

            // Start subscription for new symbols
            [strongSelf startDataRefreshTimer];
        });
    }];
}

- (void)refreshQuotesForDisplaySymbols {
    if (self.displaySymbols.count == 0) return;
    
    [[DataHub shared] getQuotesForSymbols:self.displaySymbols
                               completion:^(NSDictionary<NSString *,MarketQuoteModel *> * _Nonnull quotes, BOOL allLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.quotesCache addEntriesFromDictionary:quotes];
            [self.tableView reloadData];
            
            self.lastQuoteUpdate = [NSDate timeIntervalSinceReferenceDate];
            
            NSLog(@"✅ WatchlistWidget: Refreshed quotes for %lu symbols (allLive: %@)",
                  (unsigned long)quotes.count, allLive ? @"YES" : @"NO");
        });
    }];
}

#pragma mark - Data Refresh Timer

- (void)startDataRefreshTimer {
    [self stopDataRefreshTimer];
    
    // Only subscribe if in symbols mode
    if (self.displayMode != WatchlistDisplayModeSymbols) {
        return;
    }
    
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
    if (self.displaySymbols.count > 0) {
        for (NSString *symbol in self.displaySymbols) {
            [[DataHub shared] unsubscribeFromQuoteUpdatesForSymbol:symbol];
        }
        NSLog(@"✅ WatchlistWidget: Unsubscribed from DataHub quotes");
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:@"DataHubQuoteUpdated"
                                                   object:nil];
}

- (void)handleQuoteUpdate:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"];
    
    if ([self.displaySymbols containsObject:symbol] && quote) {
        self.quotesCache[symbol] = quote;
        
        // Reload only visible rows for better performance
        NSInteger row = [self.displaySymbols indexOfObject:symbol];
        if (row != NSNotFound) {
            [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                       columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableView.tableColumns.count)]];
        }
        
        self.lastQuoteUpdate = [NSDate timeIntervalSinceReferenceDate];
    }
}

#pragma mark - Search Functionality

- (void)searchTextChanged:(NSTextField *)sender {
    self.searchText = sender.stringValue;
    
    NSLog(@"🔍 WatchlistWidget: Search text changed to: '%@'", self.searchText);
    
    // Search filters the watchlists in list mode
    if (self.displayMode == WatchlistDisplayModeListSelection) {
        [self filterWatchlistsWithSearchText:self.searchText];
    }
    // In symbols mode, search could filter symbols (optional future enhancement)
}

- (void)filterWatchlistsWithSearchText:(NSString *)searchText {
    if (!searchText || searchText.length == 0) {
        // No filter - show all
        NSString *categoryName = [self categoryNameForProviderType:self.selectedProviderType];
        self.currentProviderLists = [self.providerManager providersForCategory:categoryName];
    } else {
        // Filter by name
        NSString *categoryName = [self categoryNameForProviderType:self.selectedProviderType];
        NSArray<id<WatchlistProvider>> *allProviders = [self.providerManager providersForCategory:categoryName];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName CONTAINS[cd] %@", searchText];
        self.currentProviderLists = [allProviders filteredArrayUsingPredicate:predicate];
        
        NSLog(@"🔍 Filtered to %lu watchlists", (unsigned long)self.currentProviderLists.count);
    }
    
    [self.tableView reloadData];
}

- (void)clearSearch {
    self.searchField.stringValue = @"";
    self.searchText = @"";
    [self filterWatchlistsWithSearchText:@""];
}

#pragma mark - Layout Management (Existing Logic)

- (void)updateLayoutForWidth:(CGFloat)width {
    self.currentWidth = width;
    
    NSInteger newVisibleColumns;
    if (width < 150) {
        newVisibleColumns = 1; // Symbol only
    } else if (width < 220) {
        newVisibleColumns = 2; // Symbol + Change%
    } else {
        newVisibleColumns = 3; // Symbol + Change% + Arrow
    }
    
    if (newVisibleColumns != self.visibleColumns) {
        self.visibleColumns = newVisibleColumns;
        [self reconfigureColumnsForCurrentWidth];
    } else {
        [self adjustColumnWidthsForWidth:width];
    }
}

- (void)adjustColumnWidthsForWidth:(CGFloat)width {
    if (self.tableView.tableColumns.count == 0) return;
    
    NSTableColumn *symbolColumn = [self.tableView tableColumnWithIdentifier:@"symbol"];
    NSTableColumn *changeColumn = [self.tableView tableColumnWithIdentifier:@"change"];
    NSTableColumn *arrowColumn = [self.tableView tableColumnWithIdentifier:@"arrow"];
    
    CGFloat availableWidth = width - 20;
    
    if (self.visibleColumns == 1) {
        symbolColumn.width = availableWidth;
    } else if (self.visibleColumns == 2) {
        changeColumn.width = 65;
        symbolColumn.width = availableWidth - 65;
    } else {
        arrowColumn.width = 25;
        changeColumn.width = 65;
        symbolColumn.width = availableWidth - 25 - 65;
    }
}

- (void)reconfigureColumnsForCurrentWidth {
    while (self.tableView.tableColumns.count > 0) {
        [self.tableView removeTableColumn:self.tableView.tableColumns.firstObject];
    }
    
    [self addSymbolColumn];
    
    if (self.visibleColumns >= 2) {
        [self addChangeColumn];
    }
    
    if (self.visibleColumns >= 3) {
        [self addArrowColumn];
    }
    
    [self.tableView reloadData];
}

- (void)viewDidResize:(NSNotification *)notification {
    CGFloat newWidth = self.contentView.frame.size.width;
    
    if (fabs(newWidth - self.currentWidth) < 5.0) {
        return;
    }
    
    self.pendingWidth = newWidth;
    [self.resizeThrottleTimer invalidate];
    
    self.resizeThrottleTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
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


#pragma mark - Actions Menu

- (void)showActionsMenu:(NSButton *)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Actions"];
    
    // Only show symbol-related actions when in symbols mode with selections
    if (self.displayMode == WatchlistDisplayModeSymbols && [self hasSelectedSymbols]) {
        [menu addItemWithTitle:@"Create Watchlist from Selection"
                        action:@selector(createWatchlistFromCurrentSelection)
                 keyEquivalent:@""];
        
        // Add to manual watchlist submenu
        NSMenuItem *addToWatchlistItem = [[NSMenuItem alloc] initWithTitle:@"Add to Watchlist"
                                                                    action:nil
                                                             keyEquivalent:@""];
        NSMenu *watchlistSubmenu = [[NSMenu alloc] initWithTitle:@""];
        
        NSArray<id<WatchlistProvider>> *manualProviders = [self.providerManager providersForCategory:@"Manual Watchlists"];
        for (id<WatchlistProvider> provider in manualProviders) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:provider.displayName
                                                          action:@selector(addSelectionToWatchlistMenuItem:)
                                                   keyEquivalent:@""];
            item.representedObject = provider;
            item.target = self;
            [watchlistSubmenu addItem:item];
        }
        
        addToWatchlistItem.submenu = watchlistSubmenu;
        [menu addItem:addToWatchlistItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    // General actions
    [menu addItemWithTitle:@"Refresh"
                    action:@selector(refreshCurrentProvider)
             keyEquivalent:@""];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    [menu addItemWithTitle:@"Widget Settings"
                    action:@selector(showWidgetSettings)
             keyEquivalent:@""];
    
    [NSMenu popUpContextMenu:menu withEvent:NSApp.currentEvent forView:sender];
}

- (void)addSelectionToWatchlistMenuItem:(NSMenuItem *)menuItem {
    id<WatchlistProvider> provider = menuItem.representedObject;
    
    if (![provider isKindOfClass:[ManualWatchlistProvider class]]) {
        NSLog(@"⚠️ Selected provider is not a manual watchlist");
        return;
    }
    
    ManualWatchlistProvider *manualProvider = (ManualWatchlistProvider *)provider;
    NSArray<NSString *> *selectedSymbols = [self selectedSymbols];
    
    DataHub *dataHub = [DataHub shared];
    for (NSString *symbol in selectedSymbols) {
        [dataHub addSymbol:symbol toWatchlistModel:manualProvider.watchlistModel];
    }
    
    NSLog(@"✅ Added %lu symbols to watchlist: %@",
          (unsigned long)selectedSymbols.count, provider.displayName);
}

- (void)createWatchlistFromCurrentSelection {
    NSArray<NSString *> *selectedSymbols = [self selectedSymbols];
    
    if (selectedSymbols.count == 0) {
        NSLog(@"⚠️ No symbols selected");
        return;
    }
    
    // Show input dialog for watchlist name
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create Watchlist";
    alert.informativeText = [NSString stringWithFormat:@"Create new watchlist with %lu selected symbols?",
                            (unsigned long)selectedSymbols.count];
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Watchlist name";
    alert.accessoryView = input;
    NSWindow *window = self.contentView.window;

    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSString *watchlistName = input.stringValue;
            if (watchlistName.length > 0) {
                [self createNewWatchlistWithName:watchlistName symbols:selectedSymbols];
            }
        }
    }];
}

- (void)createNewWatchlistWithName:(NSString *)name symbols:(NSArray<NSString *> *)symbols {
    DataHub *dataHub = [DataHub shared];
    
    WatchlistModel *newWatchlist = [dataHub createWatchlistModelWithName:name];
    
    if (!newWatchlist) {
        NSLog(@"❌ Failed to create watchlist");
        return;
    }
    
    // Add all symbols
    for (NSString *symbol in symbols) {
        [dataHub addSymbol:symbol toWatchlistModel:newWatchlist];
    }
    
    NSLog(@"✅ Created watchlist '%@' with %lu symbols", name, (unsigned long)symbols.count);
    
    // Refresh provider manager and switch to manual type
    [self.providerManager refreshAllProviders];
    [self selectProviderType:WatchlistProviderTypeManual];
}

- (void)showWidgetSettings {
    // Placeholder for widget settings
    NSLog(@"Widget settings not implemented yet");
}

#pragma mark - Utility Methods

- (BOOL)hasSelectedSymbols {
    if (self.displayMode != WatchlistDisplayModeSymbols) {
        return NO;
    }
    return self.tableView.selectedRowIndexes.count > 0;
}

- (NSArray<NSString *> *)selectedSymbols {
    if (self.displayMode != WatchlistDisplayModeSymbols) {
        return @[];
    }
    
    NSMutableArray<NSString *> *selected = [NSMutableArray array];
    [self.tableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx < self.displaySymbols.count) {
            [selected addObject:self.displaySymbols[idx]];
        }
    }];
    return [selected copy];
}

#pragma mark - Double Click Handling

- (void)tableView:(NSTableView *)tableView didDoubleClickRow:(NSInteger)row {
    if (self.displayMode != WatchlistDisplayModeSymbols) {
        return; // Already handled in tableViewDoubleClick:
    }
    
    if (row < 0 || row >= self.displaySymbols.count) return;
    
    NSString *symbol = self.displaySymbols[row];
    
    NSLog(@"📊 WatchlistWidget: Opening chart for symbol: %@", symbol);
    
    // Post notification to open chart widget
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OpenChartForSymbol"
                                                        object:nil
                                                      userInfo:@{@"symbol": symbol}];
}

#pragma mark - Context Menu

- (void)setupStandardContextMenu {
    NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@""];
    
    NSMenuItem *openChartItem = [[NSMenuItem alloc] initWithTitle:@"Open Chart"
                                                           action:@selector(contextMenuOpenChart:)
                                                    keyEquivalent:@""];
    openChartItem.target = self;
    [contextMenu addItem:openChartItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *copySymbolItem = [[NSMenuItem alloc] initWithTitle:@"Copy Symbol"
                                                            action:@selector(contextMenuCopySymbol:)
                                                     keyEquivalent:@""];
    copySymbolItem.target = self;
    [contextMenu addItem:copySymbolItem];
    
    self.tableView.menu = contextMenu;
}

- (void)contextMenuOpenChart:(NSMenuItem *)sender {
    NSInteger clickedRow = self.tableView.clickedRow;
    if (clickedRow >= 0) {
        [self tableView:self.tableView didDoubleClickRow:clickedRow];
    }
}

- (void)contextMenuCopySymbol:(NSMenuItem *)sender {
    NSInteger clickedRow = self.tableView.clickedRow;
    if (clickedRow >= 0 && clickedRow < self.displaySymbols.count) {
        NSString *symbol = self.displaySymbols[clickedRow];
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard setString:symbol forType:NSPasteboardTypeString];
        
        NSLog(@"📋 Copied symbol to clipboard: %@", symbol);
    }
}

#pragma mark - BaseWidget Overrides

- (NSString *)widgetType {
    return @"Watchlist";
}

- (void)setupContentView {
    [super setupContentView];
    
    NSLog(@"🎨 WatchlistWidget: setupContentView");
    
    // Remove BaseWidget's placeholder
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Create UI components
    [self createToolbar];
    [self createTableView];
    [self setupConstraints];
    [self configureTableColumns];
    
    // Setup resize observation
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewDidResize:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self.contentView];
    self.contentView.postsBoundsChangedNotifications = YES;
    self.contentView.postsFrameChangedNotifications = YES;
    
    // Setup initial provider and start refresh
    [self setupInitialProvider];
    [self setupStandardContextMenu];
}

- (void)setupInitialProvider {
    NSLog(@"🔧 WatchlistWidget: Setting up initial provider");
    
    // Start with Manual watchlists by default
    [self selectProviderType:WatchlistProviderTypeManual];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self startDataRefreshTimer];
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
    [self stopDataRefreshTimer];
}

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy] ?: [NSMutableDictionary dictionary];
    
    // Save selected provider type
    state[@"selectedProviderType"] = @(self.selectedProviderType);
    
    // Save last selected provider ID (if in symbols mode)
    if (self.lastSelectedProviderId) {
        state[@"lastSelectedProviderId"] = self.lastSelectedProviderId;
    }
    
    // Save display mode
    state[@"displayMode"] = @(self.displayMode);
    
    // Save visible columns
    state[@"visibleColumns"] = @(self.visibleColumns);
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    NSLog(@"🔄 WatchlistWidget: Restoring state");
    
    // Restore provider type
    NSNumber *providerType = state[@"selectedProviderType"];
    if (providerType) {
        [self selectProviderType:(WatchlistProviderType)[providerType integerValue]];
        [self.providerTypeSegmented setSelectedSegment:[providerType integerValue]];
    }
    
    // Restore visible columns
    NSNumber *visibleColumns = state[@"visibleColumns"];
    if (visibleColumns) {
        self.visibleColumns = [visibleColumns integerValue];
        [self reconfigureColumnsForCurrentWidth];
    }
    
    // Restore display mode and provider
    NSNumber *displayMode = state[@"displayMode"];
    NSString *providerId = state[@"lastSelectedProviderId"];
    
    if (displayMode && [displayMode integerValue] == WatchlistDisplayModeSymbols && providerId) {
        // Try to restore the drill-down state
        id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
        if (provider) {
            // Find the provider in the current list
            NSInteger index = [self.currentProviderLists indexOfObject:provider];
            if (index != NSNotFound) {
                [self drillDownToWatchlistAtIndex:index];
            } else {
                // Provider not in current list, just select it directly
                [self selectProvider:provider];
                self.displayMode = WatchlistDisplayModeSymbols;
                ;
            }
        }
    }
}

- (void)dealloc {
    [self stopDataRefreshTimer];
    [self.resizeThrottleTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Error/Success Messages

- (void)showErrorMessage:(NSString *)message {
    self.statusLabel.stringValue = message;
    self.statusLabel.textColor = [NSColor systemRedColor];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = @"Ready";
        self.statusLabel.textColor = [NSColor secondaryLabelColor];
    });
}

- (void)showSuccessMessage:(NSString *)message {
    self.statusLabel.stringValue = message;
    self.statusLabel.textColor = [NSColor systemGreenColor];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = @"Ready";
        self.statusLabel.textColor = [NSColor secondaryLabelColor];
    });
}


#pragma mark - NSTableViewDelegate - Sorting

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    if (self.displayMode == WatchlistDisplayModeListSelection) {
         // Sort watchlists alfabeticamente
         NSArray<NSSortDescriptor *> *newDescriptors = tableView.sortDescriptors;
         if (newDescriptors.count > 0) {
             self.currentProviderLists = [self.currentProviderLists sortedArrayUsingComparator:^NSComparisonResult(id<WatchlistProvider> obj1, id<WatchlistProvider> obj2) {
                 return [obj1.displayName compare:obj2.displayName];
             }];
             [tableView reloadData];
         }
         return;
     }
    
    if (self.displayMode != WatchlistDisplayModeSymbols) {
        return;
    }
    
    NSArray<NSSortDescriptor *> *newDescriptors = tableView.sortDescriptors;
    
    if (newDescriptors.count == 0) {
        // No sorting - restore original order
        self.displaySymbols = [self.symbols copy];
        [tableView reloadData];
        return;
    }
    
    NSSortDescriptor *primaryDescriptor = newDescriptors.firstObject;
    NSString *key = primaryDescriptor.key;
    BOOL ascending = primaryDescriptor.ascending;
    
    NSLog(@"🔄 Sorting by: %@ (ascending: %@)", key, ascending ? @"YES" : @"NO");
    
    if ([key isEqualToString:@"self"]) {
        // Sort alfabetico per simbolo
        self.displaySymbols = [self.displaySymbols sortedArrayUsingDescriptors:newDescriptors];
    } else if ([key isEqualToString:@"changePercent"]) {
        // Sort per change%
        [self sortSymbolsByChangePercent:ascending];
    }
    
    [tableView reloadData];
}

- (void)sortSymbolsByChangePercent:(BOOL)ascending {
    NSArray<NSString *> *sorted = [self.displaySymbols sortedArrayUsingComparator:^NSComparisonResult(NSString *symbol1, NSString *symbol2) {
        MarketQuoteModel *quote1 = self.quotesCache[symbol1];
        MarketQuoteModel *quote2 = self.quotesCache[symbol2];
        
        double change1 = quote1 ? quote1.changePercent.doubleValue : 0.0;
        double change2 = quote2 ? quote2.changePercent.doubleValue : 0.0;
        
        if (ascending) {
            return [@(change1) compare:@(change2)];
        } else {
            return [@(change2) compare:@(change1)];
        }
    }];
    
    self.displaySymbols = sorted;
}

@end
