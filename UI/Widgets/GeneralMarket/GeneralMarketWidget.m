/*todo
 // GeneralMarketWidget.m - Versione che usa SOLO DataHub
#import "GeneralMarketWidget.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "Watchlist+CoreDataClass.h"
#import "MarketPerformer+CoreDataClass.h"

@interface GeneralMarketWidget ()
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *internalMarketLists;
@property (nonatomic, strong) NSMenuItem *contextMenuCreateWatchlist;
@property (nonatomic, strong) NSMenuItem *contextMenuSendToChain;
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
    self.internalMarketLists = [NSMutableArray array];
    
    NSArray *listTypes = @[@"ETF", @"Day Gainers", @"Day Losers", @"Week Gainers", @"Week Losers"];
    for (NSString *type in listTypes) {
        NSMutableDictionary *listDict = @{
            @"type": type,
            @"items": [NSMutableArray array],
            @"expanded": @NO,
            @"lastUpdate": [NSDate date]
        }.mutableCopy;
        
        [self.internalMarketLists addObject:listDict];
    }
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

  #pragma mark - Data Loading from DataHub ONLY

- (void)refreshData {
    if (self.isLoading) return;
    
    self.isLoading = YES;
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];
    self.refreshButton.enabled = NO;
    
    // DataHub gestisce internamente il refresh dei dati
    DataHub *hub = [DataHub shared];
    
    // Conta quante richieste dobbiamo fare
    __block NSInteger pendingRequests = 0;
    __block NSInteger completedRequests = 0;
    
    NSDictionary *listMappings = @{
        @"Day Gainers": @{@"type": @"gainers", @"timeframe": @"1d"},
        @"Day Losers": @{@"type": @"losers", @"timeframe": @"1d"},
        @"Week Gainers": @{@"type": @"gainers", @"timeframe": @"52w"},
        @"Week Losers": @{@"type": @"losers", @"timeframe": @"52w"},
        @"ETF": @{@"type": @"etf", @"timeframe": @"1d"}
    };
    
    for (NSMutableDictionary *marketList in self.marketLists) {
        NSDictionary *mapping = listMappings[marketList[@"type"]];
        if (mapping) {
            pendingRequests++;
        }
    }
    
    // Refresh ogni lista
    for (NSMutableDictionary *marketList in self.marketLists) {
        NSString *listName = marketList[@"type"];
        NSDictionary *mapping = listMappings[listName];
        
        if (mapping) {
            marketList[@"isLoading"] = @YES;
            
            // Forza refresh usando refreshQuotesForSymbols se abbiamo già dei simboli
            NSArray *currentItems = marketList[@"items"];
            if (currentItems.count > 0) {
                NSMutableArray *symbols = [NSMutableArray array];
                for (NSDictionary *item in currentItems) {
                    if (item[@"symbol"]) {
                        [symbols addObject:item[@"symbol"]];
                    }
                }
                [hub refreshQuotesForSymbols:symbols];
            }
            // Poi ricarica la lista
            [hub getMarketPerformersForList:mapping[@"type"]
                                 timeframe:mapping[@"timeframe"]
                                completion:^(NSArray<MarketPerformer *> *performers, BOOL isFresh) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSMutableArray *items = [NSMutableArray array];
                    for (MarketPerformer *performer in performers) {
                        [items addObject:@{
                            @"symbol": performer.symbol ?: @"",
                            @"name": performer.name ?: performer.symbol ?: @"",
                            @"price": @(performer.price),
                            @"changePercent": @(performer.changePercent),
                            @"volume": @(performer.volume)
                        }];
                    }
                    
                    marketList[@"items"] = items;
                    marketList[@"isLoading"] = @NO;
                    
                    [self.outlineView reloadItem:marketList reloadChildren:YES];
                    
                    completedRequests++;
                    if (completedRequests >= pendingRequests) {
                        self.isLoading = NO;
                        self.progressIndicator.hidden = YES;
                        [self.progressIndicator stopAnimation:nil];
                        self.refreshButton.enabled = YES;
                        
                        [self showTemporaryMessage:isFresh ? @"Data refreshed" : @"Loaded from cache"];
                    }
                });
            }];
        }
    }
    
    // Se non ci sono richieste da fare
    if (pendingRequests == 0) {
        self.isLoading = NO;
        self.progressIndicator.hidden = YES;
        [self.progressIndicator stopAnimation:nil];
        self.refreshButton.enabled = YES;
    }
             
}

- (void)loadDataFromDataHub {
    DataHub *hub = [DataHub shared];
    
    // Mapping tra tipo lista e timeframe
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
            // CORREZIONE: Usa il metodo con completion block
            [hub getMarketPerformersForList:mapping[@"type"]
                                 timeframe:mapping[@"timeframe"]
                                completion:^(NSArray<MarketPerformer *> *performers, BOOL isFresh) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSMutableArray *items = [NSMutableArray array];
                    for (MarketPerformer *performer in performers) {
                        [items addObject:@{
                            @"symbol": performer.symbol ?: @"",
                            @"name": performer.name ?: performer.symbol ?: @"",
                            @"price": @(performer.price),
                            @"changePercent": @(performer.changePercent),
                            @"volume": @(performer.volume)
                        }];
                    }
                    
                    marketList[@"items"] = items;
                    marketList[@"isLoading"] = @NO;
                    
                    // Aggiorna la vista
                    [self.outlineView reloadItem:marketList reloadChildren:YES];
                    
                    // Se i dati non sono freschi, mostra un indicatore
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
      // DataHub ci notifica che ci sono nuovi dati
      dispatch_async(dispatch_get_main_queue(), ^{
          [self loadDataFromDataHub];
      });
  }

  - (void)marketQuoteUpdated:(NSNotification *)notification {
      NSDictionary *userInfo = notification.userInfo;
      NSString *symbol = userInfo[@"symbol"];
      MarketQuote *quote = userInfo[@"quote"];
      
      // Aggiorna solo il simbolo specifico
      for (NSMutableDictionary *list in self.marketLists) {
          NSMutableArray *items = list[@"items"];
          for (NSMutableDictionary *item in items) {
              if ([item[@"symbol"] isEqualToString:symbol]) {
                  item[@"price"] = @(quote.currentPrice);
                  item[@"changePercent"] = @(quote.changePercent);
                  
                  // Aggiorna solo questa riga
                  NSInteger row = [self rowForItem:item];
                  if (row >= 0) {
                      [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                                  columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.outlineView.numberOfColumns)]];
                  }
              }
          }
      }
  }

  #pragma mark - Actions

  - (void)createWatchlistFromSelection {
      NSArray *symbols = [self selectedSymbols];
      if (symbols.count > 0) {
          [self createWatchlistFromList:symbols];
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
            Watchlist *watchlist = [hub createWatchlistWithName:name];
            watchlist.symbols = symbols;
            [hub saveContext]; // Salva invece di updateWatchlist
            [self showTemporaryMessage:[NSString stringWithFormat:@"Created watchlist: %@", name]];
        }
    }
}

  - (void)dealloc {
      [[NSNotificationCenter defaultCenter] removeObserver:self];
      [self.refreshTimer invalidate];
  }

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
    
    self.contextMenuCreateWatchlist = [[NSMenuItem alloc] initWithTitle:@"Create Watchlist from Selection"
                                                                  action:@selector(createWatchlistFromSelection:)
                                                           keyEquivalent:@""];
    self.contextMenuCreateWatchlist.target = self;
    
    self.contextMenuSendToChain = [[NSMenuItem alloc] initWithTitle:@"Send to Chain"
                                                              action:@selector(sendSelectionToChain:)
                                                       keyEquivalent:@""];
    self.contextMenuSendToChain.target = self;
    
    [menu addItem:self.contextMenuCreateWatchlist];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:self.contextMenuSendToChain];
    
    return menu;
}

- (void)showTemporaryMessage:(NSString *)message {
    // Implementa un messaggio temporaneo
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
    
    // Rimuovi dopo 3 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [messageLabel removeFromSuperview];
    });
}

- (NSArray<NSString *> *)selectedSymbols {
    NSMutableArray *symbols = [NSMutableArray array];
    NSIndexSet *selectedRows = self.outlineView.selectedRowIndexes;
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        id item = [self.outlineView itemAtRow:idx];
        if ([item isKindOfClass:[NSDictionary class]] && item[@"symbol"]) {
            [symbols addObject:item[@"symbol"]];
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


  @end

*/
