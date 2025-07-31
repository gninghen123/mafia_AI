//
// GeneralMarketWidget.m - Versione aggiornata con RuntimeModels
//
#import "GeneralMarketWidget.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "RuntimeModels.h"

@interface GeneralMarketWidget ()
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *internalMarketLists;
@property (nonatomic, strong) NSMenu *contextMenu;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation GeneralMarketWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        _marketLists = [NSMutableArray array];
        _pageSize = 50;
    }
    return self;
}

#pragma mark - Setup

- (void)setupContentView {
    [super setupContentView];
    
    NSLog(@"GeneralMarketWidget: Setting up content view...");
    
    // Main container
    NSView *containerView = [[NSView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:containerView];
    
    // Toolbar with refresh button
    NSView *toolbar = [self createToolbar];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:toolbar];
    
    // Scroll view for outline
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    [containerView addSubview:self.scrollView];
    
    // Outline view
    self.outlineView = [[NSOutlineView alloc] init];
    self.outlineView.delegate = self;
    self.outlineView.dataSource = self;
    self.outlineView.headerView = nil;
    self.outlineView.allowsMultipleSelection = YES;
    self.outlineView.floatsGroupRows = NO;
    self.outlineView.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    self.outlineView.doubleAction = @selector(doubleClickAction:);
    self.outlineView.target = self;
    
    // Columns
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    [self.outlineView addTableColumn:symbolColumn];
    
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = @"Name";
    nameColumn.width = 200;
    [self.outlineView addTableColumn:nameColumn];
    
    NSTableColumn *priceColumn = [[NSTableColumn alloc] initWithIdentifier:@"price"];
    priceColumn.title = @"Price";
    priceColumn.width = 80;
    [self.outlineView addTableColumn:priceColumn];
    
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change %";
    changeColumn.width = 80;
    [self.outlineView addTableColumn:changeColumn];
    
    self.scrollView.documentView = self.outlineView;
    
    // Context menu
    self.outlineView.menu = [self createContextMenu];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        [toolbar.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [toolbar.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [toolbar.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [toolbar.heightAnchor constraintEqualToConstant:30],
        
        [self.scrollView.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
    ]];
    
    [self setupInitialDataStructure];
    [self registerForNotifications];
    [self loadDataFromDataHub];
}

- (void)setupInitialDataStructure {
    NSLog(@"GeneralMarketWidget: Setting up initial data structure...");
    
    // Usa marketLists esposto nell'header invece di internalMarketLists
    [self.marketLists removeAllObjects];
    
    NSArray *listTypes = @[@"ETF", @"Day Gainers", @"Day Losers", @"Week Gainers", @"Week Losers"];
    for (NSString *type in listTypes) {
        NSMutableDictionary *listDict = @{
            @"type": type,
            @"performers": [NSMutableArray array], // Usa performers invece di items
            @"expanded": @NO,
            @"isLoading": @NO,
            @"lastUpdate": [NSDate date]
        }.mutableCopy;
        
        [self.marketLists addObject:listDict];
    }
    
    NSLog(@"GeneralMarketWidget: Created %lu market list categories", (unsigned long)self.marketLists.count);
}

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(marketDataUpdated:)
               name:@"DataHubMarketListUpdated"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(marketQuoteUpdated:)
               name:@"DataHubMarketQuoteUpdated"
             object:nil];
}

#pragma mark - Toolbar Creation

- (NSView *)createToolbar {
    NSView *toolbar = [[NSView alloc] init];
    
    // Refresh button
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.refreshButton.title = @"Refresh";
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshButtonClicked:);
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [toolbar addSubview:self.refreshButton];
    
    // Progress indicator
    self.progressIndicator = [[NSProgressIndicator alloc] init];
    self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
    self.progressIndicator.controlSize = NSControlSizeSmall;
    self.progressIndicator.hidden = YES;
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [toolbar addSubview:self.progressIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor constant:10],
        
        [self.progressIndicator.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.progressIndicator.leadingAnchor constraintEqualToAnchor:self.refreshButton.trailingAnchor constant:10]
    ]];
    
    return toolbar;
}

- (NSMenu *)createContextMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self; // Important per aggiornare dinamicamente il menu
    return menu; // Il menu verrà popolato dinamicamente in menuNeedsUpdate
}

#pragma mark - NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu {
    // Rimuovi tutti gli item esistenti
    [menu removeAllItems];
    
    NSInteger clickedRow = [self.outlineView clickedRow];
    if (clickedRow < 0) return;
    
    id clickedItem = [self.outlineView itemAtRow:clickedRow];
    
    if ([clickedItem isKindOfClass:[NSDictionary class]] && clickedItem[@"type"]) {
        // È una categoria - mostra opzione per inviare tutti i children
        NSString *categoryName = clickedItem[@"type"];
        NSArray<MarketPerformerModel *> *performers = clickedItem[@"performers"];
        
        if (performers.count > 0) {
            // Estrai i simboli
            NSMutableArray *symbols = [NSMutableArray arrayWithCapacity:performers.count];
            for (MarketPerformerModel *performer in performers) {
                [symbols addObject:performer.symbol];
            }
            
            // Menu item per inviare tutti alla chain
            NSMenuItem *sendAllItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Send All %@ to Chain (%lu symbols)", categoryName, (unsigned long)symbols.count]
                                                                 action:@selector(sendChildrenToChain:)
                                                          keyEquivalent:@""];
            sendAllItem.target = self;
            sendAllItem.representedObject = symbols;
            [menu addItem:sendAllItem];
            
            // Separatore
            [menu addItem:[NSMenuItem separatorItem]];
            
            // Submenu per colori chain
            NSMenuItem *colorItem = [[NSMenuItem alloc] initWithTitle:@"Send to Chain Color"
                                                               action:nil
                                                        keyEquivalent:@""];
            NSMenu *colorSubmenu = [self createChainColorSubmenuForSymbols:symbols];
            colorItem.submenu = colorSubmenu;
            [menu addItem:colorItem];
        }
        
    } else if ([clickedItem isKindOfClass:[MarketPerformerModel class]]) {
        // È un simbolo - mostra opzioni per simboli selezionati
        NSArray *selectedSymbols = [self selectedSymbols];
        
        if (selectedSymbols.count == 1) {
            // Simbolo singolo
            NSString *symbol = selectedSymbols[0];
            
            // Create watchlist
            NSMenuItem *watchlistItem = [[NSMenuItem alloc] initWithTitle:@"Create Watchlist from Symbol"
                                                                   action:@selector(createWatchlistFromSelection:)
                                                            keyEquivalent:@""];
            watchlistItem.target = self;
            [menu addItem:watchlistItem];
            
            [menu addItem:[NSMenuItem separatorItem]];
            
            // Send to chain
            NSMenuItem *sendItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Send '%@' to Chain", symbol]
                                                              action:@selector(sendSelectionToChain:)
                                                       keyEquivalent:@""];
            sendItem.target = self;
            [menu addItem:sendItem];
            
        } else if (selectedSymbols.count > 1) {
            // Simboli multipli
            NSMenuItem *watchlistItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Create Watchlist from %lu Symbols", (unsigned long)selectedSymbols.count]
                                                                   action:@selector(createWatchlistFromSelection:)
                                                            keyEquivalent:@""];
            watchlistItem.target = self;
            [menu addItem:watchlistItem];
            
            [menu addItem:[NSMenuItem separatorItem]];
            
            NSMenuItem *sendAllItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Send %lu Symbols to Chain", (unsigned long)selectedSymbols.count]
                                                                 action:@selector(sendSelectionToChain:)
                                                          keyEquivalent:@""];
            sendAllItem.target = self;
            [menu addItem:sendAllItem];
        }
        
        // Aggiungi sempre il submenu colori se ci sono simboli selezionati
        if (selectedSymbols.count > 0) {
            [menu addItem:[NSMenuItem separatorItem]];
            
            NSMenuItem *colorItem = [[NSMenuItem alloc] initWithTitle:@"Send to Chain Color"
                                                               action:nil
                                                        keyEquivalent:@""];
            NSMenu *colorSubmenu = [self createChainColorSubmenuForSymbols:selectedSymbols];
            colorItem.submenu = colorSubmenu;
            [menu addItem:colorItem];
        }
    }
}

#pragma mark - Data Loading from DataHub with RuntimeModels

- (void)refreshData {
    if (self.isLoading) return;
    
    NSLog(@"GeneralMarketWidget: Starting refresh...");
    
    self.isLoading = YES;
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];
    self.refreshButton.enabled = NO;
    
    DataHub *hub = [DataHub shared];
    
    __block NSInteger pendingRequests = 0;
    __block NSInteger completedRequests = 0;
    
    NSDictionary *listMappings = @{
        @"Day Gainers": @{@"type": @"gainers", @"timeframe": @"1d"},
        @"Day Losers": @{@"type": @"losers", @"timeframe": @"1d"},
        @"Week Gainers": @{@"type": @"gainers", @"timeframe": @"52w"},
        @"Week Losers": @{@"type": @"losers", @"timeframe": @"52w"},
        @"ETF": @{@"type": @"etf", @"timeframe": @"1d"}
    };
    
    pendingRequests = listMappings.count;
    NSLog(@"GeneralMarketWidget: Will make %ld requests", (long)pendingRequests);
    
    for (NSMutableDictionary *marketList in self.marketLists) {
        NSString *listName = marketList[@"type"];
        NSDictionary *mapping = listMappings[listName];
        
        if (mapping) {
            marketList[@"isLoading"] = @YES;
            
            NSString *listType = mapping[@"type"];
            NSString *timeframe = mapping[@"timeframe"];
            
            NSLog(@"GeneralMarketWidget: Getting market performers for list:%@ timeframe:%@", listType, timeframe);
            
            [hub getMarketPerformersForList:listType
                                 timeframe:timeframe
                                completion:^(NSArray<MarketPerformerModel *> *performers, BOOL isFresh) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"GeneralMarketWidget: Received %lu performers for %@, isFresh:%@",
                          (unsigned long)performers.count, listName, isFresh ? @"YES" : @"NO");
                    
                    // Usa MarketPerformerModel direttamente
                    marketList[@"performers"] = [performers mutableCopy];
                    marketList[@"isLoading"] = @NO;
                    marketList[@"lastUpdate"] = [NSDate date];
                    
                    // Aggiorna la vista
                    [self.outlineView reloadItem:marketList reloadChildren:YES];
                    
                    completedRequests++;
                    if (completedRequests >= pendingRequests) {
                        self.isLoading = NO;
                        self.progressIndicator.hidden = YES;
                        [self.progressIndicator stopAnimation:nil];
                        self.refreshButton.enabled = YES;
                        
                        NSString *message = isFresh ? @"Data refreshed" : @"Loaded from cache";
                        [self showTemporaryMessage:message];
                        
                        NSLog(@"GeneralMarketWidget: Refresh completed");
                    }
                });
            }];
        }
    }
    
    if (pendingRequests == 0) {
        self.isLoading = NO;
        self.progressIndicator.hidden = YES;
        [self.progressIndicator stopAnimation:nil];
        self.refreshButton.enabled = YES;
        NSLog(@"GeneralMarketWidget: No requests to make");
    }
}

- (void)loadDataFromDataHub {
    NSLog(@"GeneralMarketWidget: Loading data from DataHub...");
    
    DataHub *hub = [DataHub shared];
    
    NSDictionary *listMappings = @{
        @"Day Gainers": @{@"type": @"gainers", @"timeframe": @"1d"},
        @"Day Losers": @{@"type": @"losers", @"timeframe": @"1d"},
        @"Week Gainers": @{@"type": @"gainers", @"timeframe": @"52w"},
        @"Week Losers": @{@"type": @"losers", @"timeframe": @"52w"},
        @"ETF": @{@"type": @"etf", @"timeframe": @"1d"}
    };
    
    for (NSMutableDictionary *marketList in self.marketLists) {
        NSString *listName = marketList[@"type"];
        NSDictionary *mapping = listMappings[listName];
        
        if (mapping) {
            NSString *listType = mapping[@"type"];
            NSString *timeframe = mapping[@"timeframe"];
            
            [hub getMarketPerformersForList:listType
                                 timeframe:timeframe
                                completion:^(NSArray<MarketPerformerModel *> *performers, BOOL isFresh) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    marketList[@"performers"] = [performers mutableCopy];
                    marketList[@"isLoading"] = @NO;
                    marketList[@"lastUpdate"] = [NSDate date];
                    
                    [self.outlineView reloadItem:marketList reloadChildren:YES];
                    
                    if (!isFresh) {
                        [self showTemporaryMessage:@"Showing cached data"];
                    }
                });
            }];
        }
    }
}

#pragma mark - Notifications

- (void)marketDataUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadDataFromDataHub];
    });
}

- (void)marketQuoteUpdated:(NSNotification *)notification {
    // TODO: Implementa aggiornamento quote individuali quando disponibile
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        // Root level - return number of market lists
        return self.marketLists.count;
    } else if ([item isKindOfClass:[NSDictionary class]] && item[@"type"]) {
        // Market list category - return number of performers
        NSArray *performers = item[@"performers"];
        return performers.count;
    }
    
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        // Root level - return market list category
        return self.marketLists[index];
    } else if ([item isKindOfClass:[NSDictionary class]] && item[@"type"]) {
        // Market list category - return specific performer
        NSArray *performers = item[@"performers"];
        return performers[index];
    }
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if ([item isKindOfClass:[NSDictionary class]] && item[@"type"]) {
        // This is a market list category
        return YES;
    }
    return NO;
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSString *identifier = tableColumn.identifier;
    
    if ([item isKindOfClass:[NSDictionary class]] && item[@"type"]) {
        // This is a category header
        if ([identifier isEqualToString:@"symbol"]) {
            NSTextField *textField = [outlineView makeViewWithIdentifier:@"CategoryCell" owner:self];
            if (!textField) {
                textField = [[NSTextField alloc] init];
                textField.identifier = @"CategoryCell";
                textField.bordered = NO;
                textField.backgroundColor = [NSColor clearColor];
                textField.font = [NSFont boldSystemFontOfSize:13];
                textField.editable = NO;
                textField.textColor = [NSColor controlAccentColor];
            }
            
            NSString *categoryName = item[@"type"];
            NSArray *performers = item[@"performers"];
            BOOL isLoading = [item[@"isLoading"] boolValue];
            
            if (isLoading) {
                textField.stringValue = [NSString stringWithFormat:@"%@ (Loading...)", categoryName];
            } else {
                textField.stringValue = [NSString stringWithFormat:@"%@ (%lu)", categoryName, (unsigned long)performers.count];
            }
            
            return textField;
        }
        return nil;
    } else if ([item isKindOfClass:[MarketPerformerModel class]]) {
        // This is a MarketPerformerModel
        MarketPerformerModel *performer = (MarketPerformerModel *)item;
        
        NSTextField *textField = [outlineView makeViewWithIdentifier:identifier owner:self];
        if (!textField) {
            textField = [[NSTextField alloc] init];
            textField.identifier = identifier;
            textField.bordered = NO;
            textField.backgroundColor = [NSColor clearColor];
            textField.font = [NSFont systemFontOfSize:12];
            textField.editable = NO;
        }
        
        if ([identifier isEqualToString:@"symbol"]) {
            textField.stringValue = performer.symbol ?: @"";
            textField.font = [NSFont boldSystemFontOfSize:12];
        } else if ([identifier isEqualToString:@"name"]) {
            textField.stringValue = performer.name ?: performer.symbol ?: @"";
        } else if ([identifier isEqualToString:@"price"]) {
            textField.stringValue = [performer formattedPrice];
        } else if ([identifier isEqualToString:@"change"]) {
            textField.stringValue = [performer formattedChangePercent];
            
            // Color coding for gains/losses
            if ([performer isGainer]) {
                textField.textColor = [NSColor systemGreenColor];
            } else if ([performer isLoser]) {
                textField.textColor = [NSColor systemRedColor];
            } else {
                textField.textColor = [NSColor labelColor];
            }
        }
        
        return textField;
    }
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    // Return YES for category headers
    return ([item isKindOfClass:[NSDictionary class]] && item[@"type"]);
}

#pragma mark - Actions

- (IBAction)refreshButtonClicked:(id)sender {
    [self refreshData];
}

- (IBAction)doubleClickAction:(id)sender {
    NSInteger clickedRow = [self.outlineView clickedRow];
    if (clickedRow >= 0) {
        id item = [self.outlineView itemAtRow:clickedRow];
        if ([item isKindOfClass:[MarketPerformerModel class]]) {
            MarketPerformerModel *performer = (MarketPerformerModel *)item;
            [self sendSymbolToChain:performer.symbol];
            [self showTemporaryMessage:[NSString stringWithFormat:@"Sent %@ to chain", performer.symbol]];
        }
    }
}

- (IBAction)createWatchlistFromSelection:(id)sender {
    NSArray *symbols = [self selectedSymbols];
    if (symbols.count > 0) {
        [self createWatchlistFromList:symbols];
    }
}

- (IBAction)sendSelectionToChain:(id)sender {
    NSArray *symbols = [self selectedSymbols];
    [self sendSymbolsToChain:symbols];
    
    if (symbols.count > 0) {
        NSString *message = symbols.count == 1 ?
            [NSString stringWithFormat:@"Sent %@ to chain", symbols[0]] :
            [NSString stringWithFormat:@"Sent %lu symbols to chain", (unsigned long)symbols.count];
        [self showTemporaryMessage:message];
    }
}

- (IBAction)sendChildrenToChain:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSArray *symbols = menuItem.representedObject;
    
    if (symbols.count > 0) {
        [self sendSymbolsToChain:symbols];
        [self showTemporaryMessage:[NSString stringWithFormat:@"Sent %lu symbols to chain", (unsigned long)symbols.count]];
    }
}

- (void)createWatchlistFromList:(NSArray *)symbols {
    DataHub *hub = [DataHub shared];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create New Watchlist";
    alert.informativeText = [NSString stringWithFormat:@"Enter a name for the watchlist with %lu symbols",
                           (unsigned long)symbols.count];
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = @"New Watchlist";
    alert.accessoryView = input;
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *name = input.stringValue;
        if (name.length > 0) {
            WatchlistModel *watchlist = [hub createWatchlistModelWithName:name];
            watchlist.symbols = symbols;
            [hub saveContext];
            [self showTemporaryMessage:[NSString stringWithFormat:@"Created watchlist: %@", name]];
        }
    }
}

#pragma mark - Helper Methods

- (void)showTemporaryMessage:(NSString *)message {
    NSTextField *messageLabel = [[NSTextField alloc] init];
    messageLabel.stringValue = message;
    messageLabel.editable = NO;
    messageLabel.bordered = NO;
    messageLabel.backgroundColor = [NSColor controlBackgroundColor];
    messageLabel.textColor = [NSColor labelColor];
    messageLabel.alignment = NSTextAlignmentCenter;
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.contentView addSubview:messageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [messageLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10]
    ]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [messageLabel removeFromSuperview];
    });
}

- (NSArray<NSString *> *)selectedSymbols {
    NSMutableArray *symbols = [NSMutableArray array];
    NSIndexSet *selectedRows = self.outlineView.selectedRowIndexes;
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        id item = [self.outlineView itemAtRow:idx];
        if ([item isKindOfClass:[MarketPerformerModel class]]) {
            MarketPerformerModel *performer = (MarketPerformerModel *)item;
            [symbols addObject:performer.symbol];
        }
    }];
    
    return symbols;
}

- (NSInteger)rowForItem:(id)item {
    for (NSInteger i = 0; i < [self.outlineView numberOfRows]; i++) {
        if ([self.outlineView itemAtRow:i] == item) {
            return i;
        }
    }
    return -1;
}

- (void)sendSymbolToActiveChain:(NSString *)symbol {
    // Backward compatibility method - usa il nuovo helper di BaseWidget
    [self sendSymbolToChain:symbol];
}

#pragma mark - Chain Integration

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    // Override BaseWidget per gestire aggiornamenti dalla chain
    NSString *action = update[@"action"];
    
    if ([action isEqualToString:@"setSymbols"]) {
        NSArray *symbols = update[@"symbols"];
        if (symbols.count > 0) {
            NSLog(@"GeneralMarketWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
            // Per ora logga solo, potremmo implementare highlight dei simboli ricevuti
        }
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.refreshTimer invalidate];
}

@end
