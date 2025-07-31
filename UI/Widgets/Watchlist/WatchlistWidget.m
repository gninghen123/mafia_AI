//
//  WatchlistWidget.m
//  TradingApp
//
//  REFACTORED: Uses DataHub+MarketData for real-time quotes and %change
//
#import "WatchlistWidget.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "WatchlistManagerController.h"
#import "WatchlistCellViews.h"
#import "RuntimeModels.h"  // Add this import
#import <QuartzCore/QuartzCore.h>
@interface WatchlistWidget ()

// UPDATED: Use MarketQuoteModel cache instead of NSDictionary
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketQuoteModel *> *quotesCache;
@property (nonatomic, assign) BOOL isRefreshing;

// UI refs for constraints
@property (nonatomic, strong) NSView *toolbar;
@property (nonatomic, strong) NSButton *quickAddButton;

@end

@implementation WatchlistWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Watchlist";
        self.isRefreshing = NO;
        self.showOnlyFavorites = NO;
        self.sidebarVisible = NO;

        // Initialize data arrays
        self.symbols = [NSMutableArray array];
        self.filteredSymbols = [NSMutableArray array];
        self.symbolDataCache = [NSMutableDictionary dictionary];
        self.quotesCache = [NSMutableDictionary dictionary];  // Add this if missing
        self.supportedImportFormats = @[@"csv", @"txt"];
        
        // Register for DataHub notifications
        [self registerForNotifications];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRefreshTimer];
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
    
    // Load data after UI is ready
    [self loadWatchlists];
    [self startRefreshTimer];
}

#pragma mark - UI Creation

- (void)createToolbar {
    // Create toolbar
    self.toolbar = [[NSView alloc] init];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.toolbar];
    
    // Watchlist popup selector
    self.watchlistPopup = [[NSPopUpButton alloc] init];
    self.watchlistPopup.translatesAutoresizingMaskIntoConstraints = NO;
    self.watchlistPopup.target = self;
    self.watchlistPopup.action = @selector(watchlistChanged:);
    [self.toolbar addSubview:self.watchlistPopup];
    
    // Navigation buttons
    self.previousButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameGoLeftTemplate]
                                             target:self
                                             action:@selector(navigateToPreviousWatchlist)];
    self.previousButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.previousButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.previousButton.toolTip = @"Previous watchlist (⌘[)";
    [self.toolbar addSubview:self.previousButton];
    
    self.nextButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameGoRightTemplate]
                                         target:self
                                         action:@selector(navigateToNextWatchlist)];
    self.nextButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.nextButton.toolTip = @"Next watchlist (⌘])";
    [self.toolbar addSubview:self.nextButton];
    
    // Favorite button
    self.favoriteButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameBookmarksTemplate]
                                             target:self
                                             action:@selector(toggleFavoriteFilter)];
    self.favoriteButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.favoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.favoriteButton.toolTip = @"Show only favorites";
    [self.toolbar addSubview:self.favoriteButton];
    
    // Organize button
    self.organizeButton = [NSButton buttonWithTitle:@"⋮"
                                             target:self
                                             action:@selector(toggleSidebar)];
    self.organizeButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.organizeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.organizeButton.toolTip = @"Show watchlist sidebar";
    [self.toolbar addSubview:self.organizeButton];
    
    // Search field
    self.searchField = [[NSSearchField alloc] init];
    self.searchField.placeholderString = @"Filter symbols...";
    self.searchField.target = self;
    self.searchField.action = @selector(searchFieldChanged:);
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar addSubview:self.searchField];
    
    // Quick add button
    self.quickAddButton = [NSButton buttonWithTitle:@"+"
                                              target:self
                                              action:@selector(quickAddSymbol:)];
    self.quickAddButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.quickAddButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.quickAddButton.toolTip = @"Quick add symbol";
    [self.toolbar addSubview:self.quickAddButton];
    
    // Loading indicator
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar addSubview:self.loadingIndicator];
    
    // Remove symbol button
    self.removeSymbolButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameRemoveTemplate]
                                                  target:self
                                                  action:@selector(removeSelectedSymbol:)];
    self.removeSymbolButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.removeSymbolButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.removeSymbolButton.toolTip = @"Remove selected symbol";
    [self.toolbar addSubview:self.removeSymbolButton];
    
    // Import button
    self.importButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameActionTemplate]
                                           target:self
                                           action:@selector(importSymbols:)];
    self.importButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.importButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.importButton.toolTip = @"Import symbols";
    [self.toolbar addSubview:self.importButton];
}

- (void)createMainTableView {
    // Create scroll view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.scrollView];
    
    // Create table view
    self.mainTableView = [[NSTableView alloc] init];
    self.mainTableView.delegate = self;
    self.mainTableView.dataSource = self;
    self.mainTableView.allowsMultipleSelection = YES;
    self.mainTableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    self.mainTableView.intercellSpacing = NSMakeSize(0, 1);
    self.mainTableView.rowHeight = 32;
    self.mainTableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    
    // Enable drag and drop
    [self.mainTableView registerForDraggedTypes:@[NSPasteboardTypeString]];
    
    self.scrollView.documentView = self.mainTableView;
}

- (void)setupConstraints {
    // Toolbar constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.toolbar.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbar.heightAnchor constraintEqualToConstant:32]
    ]];
    
    // Toolbar elements
    CGFloat spacing = 5;
    [NSLayoutConstraint activateConstraints:@[
        // Watchlist popup
        [self.watchlistPopup.leadingAnchor constraintEqualToAnchor:self.toolbar.leadingAnchor constant:spacing],
        [self.watchlistPopup.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.watchlistPopup.widthAnchor constraintEqualToConstant:150],
        
        // Navigation buttons
        [self.previousButton.leadingAnchor constraintEqualToAnchor:self.watchlistPopup.trailingAnchor constant:spacing],
        [self.previousButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.previousButton.widthAnchor constraintEqualToConstant:25],
        
        [self.nextButton.leadingAnchor constraintEqualToAnchor:self.previousButton.trailingAnchor constant:2],
        [self.nextButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.nextButton.widthAnchor constraintEqualToConstant:25],
        
        // Favorite button
        [self.favoriteButton.leadingAnchor constraintEqualToAnchor:self.nextButton.trailingAnchor constant:spacing],
        [self.favoriteButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.favoriteButton.widthAnchor constraintEqualToConstant:25],
        
        // Organize button
        [self.organizeButton.leadingAnchor constraintEqualToAnchor:self.favoriteButton.trailingAnchor constant:spacing],
        [self.organizeButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.organizeButton.widthAnchor constraintEqualToConstant:25],
        
        // Search field (flexible width)
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.organizeButton.trailingAnchor constant:10],
        [self.searchField.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.searchField.trailingAnchor constraintEqualToAnchor:self.quickAddButton.leadingAnchor constant:-spacing],
        
        // Right side buttons
        [self.quickAddButton.trailingAnchor constraintEqualToAnchor:self.loadingIndicator.leadingAnchor constant:-spacing],
        [self.quickAddButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.quickAddButton.widthAnchor constraintEqualToConstant:25],
        
        [self.loadingIndicator.trailingAnchor constraintEqualToAnchor:self.removeSymbolButton.leadingAnchor constant:-spacing],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.loadingIndicator.widthAnchor constraintEqualToConstant:16],
        
        [self.removeSymbolButton.trailingAnchor constraintEqualToAnchor:self.importButton.leadingAnchor constant:-spacing],
        [self.removeSymbolButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.removeSymbolButton.widthAnchor constraintEqualToConstant:25],
        
        [self.importButton.trailingAnchor constraintEqualToAnchor:self.toolbar.trailingAnchor constant:-spacing],
        [self.importButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.importButton.widthAnchor constraintEqualToConstant:25]
    ]];
    
    // Scroll view constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor constant:2],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
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
    
    // Change column (ONLY %change, no $change)
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change %";
    changeColumn.width = 80;
    changeColumn.minWidth = 70;
    changeColumn.maxWidth = 100;
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
    // FIXED: Use RuntimeModels instead of Core Data objects
    self.watchlists = [[DataHub shared] getAllWatchlistModels];
    
    // Update popup menu
    [self.watchlistPopup removeAllItems];
    
    for (WatchlistModel *watchlist in self.watchlists) {
        [self.watchlistPopup addItemWithTitle:watchlist.name];
    }
    
    // Add management options
    if (self.watchlists.count > 0) {
        [self.watchlistPopup.menu addItem:[NSMenuItem separatorItem]];
    }
    [self.watchlistPopup addItemWithTitle:@"New Watchlist..."];
    [self.watchlistPopup addItemWithTitle:@"Manage Watchlists..."];
    
    // Select first watchlist if available
    if (!self.currentWatchlist) {
        if (self.watchlists.count > 0) {
            [self.watchlistPopup selectItemAtIndex:0];
            self.currentWatchlist = self.watchlists[0];
            [self loadSymbolsForCurrentWatchlist];
        }
    }else {
        [self.watchlistPopup selectItemWithTitle:[self.currentWatchlist name]];
    }
   
    // Update navigation buttons
    [self updateNavigationButtons];
}

- (void)loadSymbolsForCurrentWatchlist {
    if (!self.currentWatchlist) {
        self.symbols = [NSMutableArray array];
        self.filteredSymbols = [NSMutableArray array];
        [self.mainTableView reloadData];
        return;
    }
    
    // FIXED: Get symbols from RuntimeModel instead of Core Data
    NSMutableArray *symbolList = [[[DataHub shared] getSymbolsForWatchlistModel:self.currentWatchlist] mutableCopy];
    
    // Add empty row at the end for inline adding
    [symbolList addObject:@""];
    
    self.symbols = symbolList;
    [self applyFilter];
    [self refreshSymbolData];
}

// UPDATED: New method using DataHub+MarketData
// UPDATED: New method using DataHub+MarketData with safety checks
// Replace refreshSymbolData method in WatchlistWidget.m

- (void)refreshSymbolData {
    NSLog(@"=== WatchlistWidget: RefreshSymbolData START ===");
    
    // Safety checks
    if (self.isRefreshing) {
        NSLog(@"WatchlistWidget: Refresh already in progress, skipping");
        return;
    }
    
    if (!self.symbols || self.symbols.count == 0) {
        NSLog(@"WatchlistWidget: No symbols to refresh");
        return;
    }
    
    // Filter out empty symbols
    NSMutableArray *validSymbols = [NSMutableArray array];
    for (NSString *symbol in self.symbols) {
        if (symbol && [symbol isKindOfClass:[NSString class]] && symbol.length > 0) {
            [validSymbols addObject:symbol];
        }
    }
    
    if (validSymbols.count == 0) {
        NSLog(@"WatchlistWidget: No valid symbols to refresh");
        return;
    }
    
    // Ensure we're on main thread for UI updates
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshSymbolData];
        });
        return;
    }
    
    NSLog(@"WatchlistWidget: Starting BATCH refresh for %lu symbols: %@", (unsigned long)validSymbols.count, validSymbols);
    
    self.isRefreshing = YES;
    
    // Check loading indicator exists before using it
    if (self.loadingIndicator) {
        [self.loadingIndicator startAnimation:nil];
    }
    
    // Initialize quotes cache if needed
    if (!self.quotesCache) {
        self.quotesCache = [NSMutableDictionary dictionary];
    }
    
    // Make SINGLE batch call for all symbols
    [[DataHub shared] getQuotesForSymbols:validSymbols completion:^(NSDictionary<NSString *,MarketQuoteModel *> *quotes, BOOL allLive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ WatchlistWidget: Batch refresh completed - received %lu quotes (allLive: %@)",
                  (unsigned long)quotes.count, allLive ? @"YES" : @"NO");
            
            // Update quotes cache
            if (self.quotesCache && quotes) {
                [self.quotesCache addEntriesFromDictionary:quotes];
            }
            
            // Update UI state
            self.isRefreshing = NO;
            if (self.loadingIndicator) {
                [self.loadingIndicator stopAnimation:nil];
            }
            
            // Reload table view
            if (self.mainTableView) {
                [self.mainTableView reloadData];
            }
            
            NSLog(@"🔄 WatchlistWidget: UI updated with fresh quotes");
        });
    }];
    
    NSLog(@"=== WatchlistWidget: RefreshSymbolData END ===");
}
- (void)applyFilter {
    NSString *searchText = self.searchField.stringValue;
    
    if (searchText.length == 0) {
        self.filteredSymbols = [self.symbols mutableCopy];
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

#pragma mark - Notifications

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // UPDATED: Listen for DataHub quote updates
    [nc addObserver:self
           selector:@selector(quoteUpdated:)
               name:@"DataHubQuoteUpdatedNotification"
             object:nil];
    
    // Listen for watchlist updates
    [nc addObserver:self
           selector:@selector(watchlistUpdated:)
               name:@"DataHubWatchlistUpdatedNotification"
             object:nil];
}

- (void)quoteUpdated:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"];
    
    if (symbol && quote && [self.symbols containsObject:symbol]) {
        self.quotesCache[symbol] = quote;
        
        // Update only the affected row
        NSInteger row = [self.filteredSymbols indexOfObject:symbol];
        if (row != NSNotFound) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.mainTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                              columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.mainTableView.numberOfColumns)]];
            });
        }
    }
}

- (void)watchlistUpdated:(NSNotification *)notification {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadWatchlists];
    });
}

#pragma mark - Timer Management

- (void)startRefreshTimer {
    [self stopRefreshTimer];
    
    // UPDATED: Reduced refresh interval since DataHub manages caching efficiently
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                         target:self
                                                       selector:@selector(refreshTimerFired:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopRefreshTimer {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
}

- (void)refreshTimerFired:(NSTimer *)timer {
    if (self.view.window && self.view.window.isVisible) {
        [self refreshSymbolData];
    }
}

#pragma mark - NSTableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredSymbols.count;
}

// UPDATED: Use MarketQuoteModel data
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = tableColumn.identifier;
    
    if (row >= self.filteredSymbols.count) return nil;
    
    NSString *symbol = self.filteredSymbols[row];
    BOOL isEmpty = (symbol.length == 0);
    
    // Symbol column
    if ([identifier isEqualToString:@"symbol"]) {
        WatchlistSymbolCellView *cellView = [tableView makeViewWithIdentifier:@"SymbolCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistSymbolCellView alloc] init];
            cellView.identifier = @"SymbolCell";
        }
        
        cellView.symbolField.stringValue = symbol;
        cellView.isEditable = isEmpty;
        
        if (!isEmpty) {
            cellView.symbolField.delegate = self;
            cellView.symbolField.tag = row;
        }
        
        return cellView;
    }
    
    // For empty rows, return empty cells
    if (isEmpty) {
        NSTableCellView *emptyCell = [tableView makeViewWithIdentifier:@"EmptyCell" owner:self];
        if (!emptyCell) {
            emptyCell = [[NSTableCellView alloc] init];
            emptyCell.identifier = @"EmptyCell";
            
            NSTextField *textField = [NSTextField labelWithString:@"--"];
            textField.font = [NSFont systemFontOfSize:12];
            textField.textColor = [NSColor tertiaryLabelColor];
            textField.alignment = NSTextAlignmentCenter;
            textField.translatesAutoresizingMaskIntoConstraints = NO;
            
            [emptyCell addSubview:textField];
            [NSLayoutConstraint activateConstraints:@[
                [textField.centerXAnchor constraintEqualToAnchor:emptyCell.centerXAnchor],
                [textField.centerYAnchor constraintEqualToAnchor:emptyCell.centerYAnchor]
            ]];
        }
        return emptyCell;
    }
    
    // UPDATED: Get MarketQuoteModel from cache
    MarketQuoteModel *quote = self.quotesCache[symbol];
    
    // Price column
    if ([identifier isEqualToString:@"price"]) {
        WatchlistPriceCellView *cellView = [tableView makeViewWithIdentifier:@"PriceCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistPriceCellView alloc] init];
            cellView.identifier = @"PriceCell";
        }
        
        if (quote && quote.last) {
            cellView.priceField.stringValue = [NSString stringWithFormat:@"$%.2f", quote.last.doubleValue];
            cellView.priceField.textColor = [NSColor labelColor];
        } else {
            cellView.priceField.stringValue = @"--";
            cellView.priceField.textColor = [NSColor tertiaryLabelColor];
        }
        
        return cellView;
    }
    
    // UPDATED: Change column - ONLY %change with color
    else if ([identifier isEqualToString:@"change"]) {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"ChangeCell" owner:self];
        if (!cellView) {
            cellView = [[NSTableCellView alloc] init];
            cellView.identifier = @"ChangeCell";
            
            NSTextField *percentField = [[NSTextField alloc] init];
            percentField.bordered = NO;
            percentField.editable = NO;
            percentField.backgroundColor = [NSColor clearColor];
            percentField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];
            percentField.alignment = NSTextAlignmentRight;
            percentField.translatesAutoresizingMaskIntoConstraints = NO;
            
            [cellView addSubview:percentField];
            [NSLayoutConstraint activateConstraints:@[
                [percentField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:8],
                [percentField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-8],
                [percentField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
            ]];
            
            // Store reference for later access
            cellView.textField = percentField;
        }
        
        NSTextField *percentField = cellView.textField;
        
        if (quote && quote.changePercent) {
            double changePercent = quote.changePercent.doubleValue;
            NSString *sign = changePercent >= 0 ? @"+" : @"";
            percentField.stringValue = [NSString stringWithFormat:@"%@%.2f%%", sign, changePercent];
            
            // Color coding: Green for positive, Red for negative
            if (changePercent > 0) {
                percentField.textColor = [NSColor systemGreenColor];
            } else if (changePercent < 0) {
                percentField.textColor = [NSColor systemRedColor];
            } else {
                percentField.textColor = [NSColor labelColor];
            }
        } else {
            percentField.stringValue = @"--";
            percentField.textColor = [NSColor tertiaryLabelColor];
        }
        
        return cellView;
    }
    
    // Volume column
    else if ([identifier isEqualToString:@"volume"]) {
        WatchlistVolumeCellView *cellView = [tableView makeViewWithIdentifier:@"VolumeCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistVolumeCellView alloc] init];
            cellView.identifier = @"VolumeCell";
        }
        
        if (quote) {
            [cellView setVolume:quote.volume avgVolume:quote.avgVolume];
        } else {
            [cellView setVolume:nil avgVolume:nil];
        }
        
        return cellView;
    }
    
    // Market Cap column
    else if ([identifier isEqualToString:@"marketCap"]) {
        WatchlistMarketCapCellView *cellView = [tableView makeViewWithIdentifier:@"MarketCapCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistMarketCapCellView alloc] init];
            cellView.identifier = @"MarketCapCell";
        }
        
        if (quote) {
            [cellView setMarketCap:quote.marketCap];
        } else {
            [cellView setMarketCap:nil];
        }
        
        return cellView;
    }
    
    return nil;
}

#pragma mark - NSTableView Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    self.removeSymbolButton.enabled = (self.mainTableView.selectedRow >= 0);
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *textField = notification.object;
    NSString *newText = [textField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (newText.length > 0) {
        NSString *upperSymbol = newText.uppercaseString;
        
        if (![self.symbols containsObject:upperSymbol]) {
            // FIXED: Use RuntimeModel method
            [[DataHub shared] addSymbol:upperSymbol toWatchlistModel:self.currentWatchlist];
            
            // Reload data
            [self loadSymbolsForCurrentWatchlist];
            
            // Refresh data for new symbol
            [self refreshSymbolData];
        } else {
            // Symbol already exists - show alert
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Symbol Already Exists";
            alert.informativeText = [NSString stringWithFormat:@"'%@' is already in this watchlist.", upperSymbol];
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            
            // Clear the field
            textField.stringValue = @"";
        }
    }
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
    
    // Normal watchlist selection - FIXED: Use RuntimeModel
    if (selectedIndex >= 0 && selectedIndex < self.watchlists.count) {
        self.currentWatchlist = self.watchlists[selectedIndex];
        [self loadSymbolsForCurrentWatchlist];
        [self updateNavigationButtons];
    }
}
- (void)searchFieldChanged:(id)sender {
    [self applyFilter];
}

- (void)quickAddSymbol:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Symbol";
    alert.informativeText = @"Enter a symbol to add to the current watchlist:";
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Symbol (e.g. AAPL)";
    alert.accessoryView = input;
    
    [alert.window setInitialFirstResponder:input];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *symbols = input.stringValue.uppercaseString;
        if (symbols.length > 0) {
            for(NSString* symbol in [symbols componentsSeparatedByString:@","]){
                NSString* c_symbol = [symbol  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (![self.symbols containsObject:c_symbol]) {
                    // FIXED: Use RuntimeModel method
                    [[DataHub shared] addSymbol:c_symbol toWatchlistModel:self.currentWatchlist];
                    [self loadSymbolsForCurrentWatchlist];
                    [self refreshSymbolData];
                }
            }
        }
    }
}

- (void)removeSelectedSymbol:(id)sender {
    NSIndexSet *selectedRows = self.mainTableView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray *symbolsToRemove = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.filteredSymbols.count) {
            NSString *symbol = self.filteredSymbols[idx];
            if (symbol.length > 0) { // Don't remove the empty last row
                [symbolsToRemove addObject:symbol];
            }
        }
    }];
    
    if (symbolsToRemove.count > 0) {
        for (NSString *symbol in symbolsToRemove) {
            // FIXED: Use RuntimeModel method
            [[DataHub shared] removeSymbol:symbol fromWatchlistModel:self.currentWatchlist];
        }
        
        [self loadSymbolsForCurrentWatchlist];
        [self showTemporaryMessage:[NSString stringWithFormat:@"Removed %lu symbols", (unsigned long)symbolsToRemove.count]];
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
    // Feature coming soon
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Feature Coming Soon";
    alert.informativeText = @"The favorites feature will be available in the next update.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)toggleSidebar {
    // Feature coming soon - drag & drop sidebar
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Feature Coming Soon";
    alert.informativeText = @"The drag & drop sidebar will be available in the next update.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)createWatchlist:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Watchlist";
    alert.informativeText = @"Enter a name for the new watchlist:";
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Watchlist Name";
    alert.accessoryView = input;
    
    [alert.window setInitialFirstResponder:input];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *name = [input.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length > 0) {
            // FIXED: Use RuntimeModel method
            WatchlistModel *watchlist = [[DataHub shared] createWatchlistModelWithName:name];
            [self loadWatchlists];
            
            // Select the new watchlist
            NSInteger newIndex = [self.watchlists indexOfObject:watchlist];
            if (newIndex != NSNotFound) {
                [self.watchlistPopup selectItemAtIndex:newIndex];
                [self watchlistChanged:self.watchlistPopup];
            }
        }
    }
}

- (void)manageWatchlists:(id)sender {
    WatchlistManagerController *manager = [[WatchlistManagerController alloc] init];
    manager.completionHandler = ^(BOOL changed) {
        if (changed) {
            [self loadWatchlists];
        }
    };
    
    [self.view.window beginSheet:manager.window completionHandler:nil];
}

- (void)importSymbols:(id)sender {
    // Feature coming soon - CSV/TXT import
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Feature Coming Soon";
    alert.informativeText = @"Symbol import will be available in the next update.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

#pragma mark - Helper Methods

- (void)showTemporaryMessage:(NSString *)message {
    // Simple temporary message display
    NSTextField *messageLabel = [NSTextField labelWithString:message];
    messageLabel.backgroundColor = [NSColor controlAccentColor];
    messageLabel.textColor = [NSColor controlTextColor];
    messageLabel.drawsBackground = YES;
    messageLabel.bordered = NO;
    messageLabel.editable = NO;
    messageLabel.alignment = NSTextAlignmentCenter;
    messageLabel.font = [NSFont systemFontOfSize:11];
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.contentView addSubview:messageLabel];
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [messageLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        [messageLabel.heightAnchor constraintEqualToConstant:24]
    ]];
    
    // Remove after 2 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [messageLabel removeFromSuperview];
    });
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    if (self.currentWatchlist) {
        // FIXED: Use RuntimeModel property
        state[@"currentWatchlistName"] = self.currentWatchlist.name;
    }
    
    state[@"searchText"] = self.searchField.stringValue ?: @"";
    state[@"showOnlyFavorites"] = @(self.showOnlyFavorites);
    
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    // Restore watchlist selection
    NSString *watchlistName = state[@"currentWatchlistName"];
    if (watchlistName) {
        for (NSInteger i = 0; i < self.watchlists.count; i++) {
            // FIXED: Use RuntimeModel
            WatchlistModel *watchlist = self.watchlists[i];
            if ([watchlist.name isEqualToString:watchlistName]) {
                [self.watchlistPopup selectItemAtIndex:i];
                self.currentWatchlist = watchlist;
                [self loadSymbolsForCurrentWatchlist];
                break;
            }
        }
    }
    
    // Restore search text
    NSString *searchText = state[@"searchText"];
    if (searchText) {
        self.searchField.stringValue = searchText;
        [self applyFilter];
    }
    
    // Restore favorites filter
    self.showOnlyFavorites = [state[@"showOnlyFavorites"] boolValue];
}

@end
