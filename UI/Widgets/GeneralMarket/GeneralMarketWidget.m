//
//  GeneralMarketWidget.m
//  TradingApp
//

#import "GeneralMarketWidget.h"
#import "DataManager.h"
#import "DataHub.h"
#import "Watchlist+CoreDataClass.h"

@interface GeneralMarketWidget ()

@property (nonatomic, strong) NSMenuItem *contextMenuCreateWatchlist;
@property (nonatomic, strong) NSMenuItem *contextMenuSendToChain;
@property (nonatomic, strong) NSMenu *contextMenu;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL isLoading;

// Private method declarations
- (void)setupInitialDataStructure;
- (void)showTemporaryMessage:(NSString *)message;
- (NSMenu *)createContextMenu;
- (void)refreshButtonClicked:(id)sender;
- (void)sendSelectionToChain:(id)sender;
- (void)sendAllToChain:(id)sender;
- (void)createWatchlistFromSelection:(id)sender;
- (NSArray<NSString *> *)selectedSymbols;

@end

@implementation GeneralMarketWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        _marketLists = [NSMutableArray array];
        _quotesCache = [NSMutableDictionary dictionary];
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

#pragma mark - Data Management

- (void)setupInitialDataStructure {
    // Create empty market lists
    NSArray *listTypes = @[@"ETF", @"Day Gainers", @"Day Losers", @"Week Gainers", @"Week Losers"];
    
    for (NSString *type in listTypes) {
        MarketList *list = [[MarketList alloc] init];
        list.listType = type;
        list.items = @[];
        list.lastUpdate = [NSDate date];
        [self.marketLists addObject:list];
    }
    
    [self.outlineView reloadData];
}

- (void)refreshData {
    if (self.isLoading) return;
    
    self.isLoading = YES;
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];
    self.refreshButton.enabled = NO;
    
    DataManager *dataManager = [DataManager sharedManager];
    
    // Fetch each list type
    dispatch_group_t group = dispatch_group_create();
    
    // ETF List
    dispatch_group_enter(group);
    [dataManager requestETFListWithCompletion:^(NSArray *etfs, NSError *error) {
        if (!error && etfs) {
            [self updateMarketList:@"ETF" withData:etfs];
        }
        dispatch_group_leave(group);
    }];
    
    // Gainers/Losers for different rank types
    NSArray *rankTypes = @[@"1d", @"52w"];  // Day and Week
    for (NSString *rankType in rankTypes) {
        // Gainers
        dispatch_group_enter(group);
        NSString *gainersType = [rankType isEqualToString:@"1d"] ? @"Day Gainers" : @"Week Gainers";
        [dataManager requestTopGainersWithRankType:rankType
                                          pageSize:50
                                        completion:^(NSArray *gainers, NSError *error) {
            if (!error && gainers) {
                [self updateMarketList:gainersType withData:gainers];
            }
            dispatch_group_leave(group);
        }];
        
        // Losers
        dispatch_group_enter(group);
        NSString *losersType = [rankType isEqualToString:@"1d"] ? @"Day Losers" : @"Week Losers";
        [dataManager requestTopLosersWithRankType:rankType
                                         pageSize:50
                                       completion:^(NSArray *losers, NSError *error) {
            if (!error && losers) {
                [self updateMarketList:losersType withData:losers];
            }
            dispatch_group_leave(group);
        }];
    }
    
    // When all requests complete
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        self.isLoading = NO;
        self.progressIndicator.hidden = YES;
        [self.progressIndicator stopAnimation:nil];
        self.refreshButton.enabled = YES;
        [self.outlineView reloadData];
        [self showTemporaryMessage:@"Data refreshed"];
    });
}

- (void)updateMarketList:(NSString *)listType withData:(NSArray *)data {
    // Find the list
    MarketList *list = nil;
    for (MarketList *ml in self.marketLists) {
        if ([ml.listType isEqualToString:listType]) {
            list = ml;
            break;
        }
    }
    
    if (!list) return;
    
    // Convert data to MarketPerformer objects
    NSMutableArray *performers = [NSMutableArray array];
    
    for (NSDictionary *item in data) {
        MarketPerformer *performer = [[MarketPerformer alloc] init];
        performer.symbol = item[@"symbol"];
        performer.name = item[@"name"] ?: item[@"symbol"];
        performer.price = [item[@"price"] doubleValue];
        performer.changePercent = [item[@"changePercent"] doubleValue];
        performer.volume = [item[@"volume"] longLongValue];
        [performers addObject:performer];
    }
    
    list.items = performers;
    list.lastUpdate = [NSDate date];
}

#pragma mark - NSOutlineView DataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (!item) {
        return self.marketLists.count;
    }
    
    if ([item isKindOfClass:[MarketList class]]) {
        MarketList *list = (MarketList *)item;
        return list.items.count;
    }
    
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (!item) {
        return self.marketLists[index];
    }
    
    if ([item isKindOfClass:[MarketList class]]) {
        MarketList *list = (MarketList *)item;
        return list.items[index];
    }
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [item isKindOfClass:[MarketList class]];
}

#pragma mark - NSOutlineView Delegate

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item {
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.bordered = NO;
    textField.editable = NO;
    textField.backgroundColor = [NSColor clearColor];
    
    if ([item isKindOfClass:[MarketList class]]) {
        // Header row
        MarketList *list = (MarketList *)item;
        if ([tableColumn.identifier isEqualToString:@"symbol"]) {
            textField.stringValue = list.listType;
            textField.font = [NSFont boldSystemFontOfSize:12];
        } else if ([tableColumn.identifier isEqualToString:@"name"]) {
            textField.stringValue = [NSString stringWithFormat:@"%lu items",
                                   (unsigned long)list.items.count];
            textField.textColor = [NSColor secondaryLabelColor];
        }
    } else if ([item isKindOfClass:[MarketPerformer class]]) {
        // Data row
        MarketPerformer *performer = (MarketPerformer *)item;
        
        if ([tableColumn.identifier isEqualToString:@"symbol"]) {
            textField.stringValue = performer.symbol;
        } else if ([tableColumn.identifier isEqualToString:@"name"]) {
            textField.stringValue = performer.name;
        } else if ([tableColumn.identifier isEqualToString:@"price"]) {
            textField.stringValue = [NSString stringWithFormat:@"$%.2f", performer.price];
        } else if ([tableColumn.identifier isEqualToString:@"change"]) {
            textField.stringValue = [NSString stringWithFormat:@"%.2f%%", performer.changePercent];
            textField.textColor = performer.changePercent >= 0 ?
                                [NSColor systemGreenColor] : [NSColor systemRedColor];
        }
    }
    
    return textField;
}

#pragma mark - Actions

- (void)refreshButtonClicked:(id)sender {
    [self refreshData];
}

- (void)doubleClickAction:(id)sender {
    NSInteger clickedRow = self.outlineView.clickedRow;
    if (clickedRow < 0) return;
    
    id item = [self.outlineView itemAtRow:clickedRow];
    if ([item isKindOfClass:[MarketPerformer class]]) {
        MarketPerformer *performer = (MarketPerformer *)item;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SymbolSelected"
                                                            object:self
                                                          userInfo:@{@"symbol": performer.symbol}];
    }
}

- (NSArray<NSString *> *)selectedSymbols {
    NSMutableArray *symbols = [NSMutableArray array];
    NSIndexSet *selectedRows = self.outlineView.selectedRowIndexes;
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        id item = [self.outlineView itemAtRow:idx];
        if ([item isKindOfClass:[MarketPerformer class]]) {
            MarketPerformer *performer = (MarketPerformer *)item;
            [symbols addObject:performer.symbol];
        }
    }];
    
    return symbols;
}

#pragma mark - Context Menu

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

- (void)createWatchlistFromSelection:(id)sender {
    NSArray *symbols = [self selectedSymbols];
    if (symbols.count > 0) {
        [self createWatchlistFromList:symbols];
    }
}

- (void)createWatchlistFromList:(NSArray *)symbols {
    // Create dialog for watchlist name
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
            Watchlist *watchlist = [[DataHub shared] createWatchlistWithName:name];
            watchlist.symbols = symbols;
            [[DataHub shared] updateWatchlist:watchlist];
            [self showTemporaryMessage:[NSString stringWithFormat:@"Created watchlist: %@", name]];
        }
    }
}

- (void)sendSelectionToChain:(id)sender {
    NSArray *symbols = [self selectedSymbols];
    if (symbols.count > 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AddSymbolsToChain"
                                                            object:self
                                                          userInfo:@{@"symbols": symbols}];
    }
}

- (void)sendAllToChain:(id)sender {
    NSMutableArray *allSymbols = [NSMutableArray array];
    
    for (MarketList *list in self.marketLists) {
        for (MarketPerformer *performer in list.items) {
            [allSymbols addObject:performer.symbol];
        }
    }
    
    if (allSymbols.count > 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AddSymbolsToChain"
                                                            object:self
                                                          userInfo:@{@"symbols": allSymbols}];
    }
}

- (void)showTemporaryMessage:(NSString *)message {
    // Implement temporary message display
    NSLog(@"%@", message);
}

#pragma mark - Widget Protocol

- (void)refresh {
    [self refreshData];
}

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    // Add any specific state if needed
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    // Restore any specific state if needed
    [self refreshData];
}

- (void)dealloc {
    [self.refreshTimer invalidate];
}

@end
