//
//  GeneralMarketWidget.m
//  TradingApp
//

#import "GeneralMarketWidget.h"
#import "DataManager.h"
#import "DataManager+MarketLists.h"
#import "WatchlistManager.h"

@implementation MarketDataNode

- (instancetype)init {
    self = [super init];
    if (self) {
        _children = [NSMutableArray array];
        _isExpandable = NO;
        _changeColor = [NSColor labelColor];
    }
    return self;
}

@end

@interface GeneralMarketWidget ()

@property (nonatomic, strong) NSMenuItem *contextMenuCreateWatchlist;
@property (nonatomic, strong) NSMenuItem *contextMenuSendToChain;
@property (nonatomic, strong) NSMenu *contextMenu;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL isLoading;

// Private method declarations
- (void)setupInitialDataStructure;
- (NSString *)displayNameForRankType:(NSString *)rankType;
- (void)showTemporaryMessage:(NSString *)message;
- (void)updateETFNode:(NSArray *)etfs;
- (void)updateGainersNode:(NSArray *)gainers forRankType:(NSString *)rankType;
- (void)updateLosersNode:(NSArray *)losers forRankType:(NSString *)rankType;
- (void)collectSymbolsFromNode:(MarketDataNode *)node intoArray:(NSMutableArray *)array;
- (void)highlightSymbol:(NSString *)symbol;
- (NSMenu *)createContextMenu;
- (void)refreshButtonClicked:(id)sender;
- (void)sendSelectionToChain:(id)sender;
- (void)sendAllToChain:(id)sender;
- (void)createWatchlistFromSelection:(id)sender;

@end

@implementation GeneralMarketWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        _pageSize = 50; // Default page size
        _dataSource = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupInitialDataStructure];
}

- (void)setupContentView {
    [super setupContentView];
    
    // Inizializza la struttura dati
        [self setupInitialDataStructure];
    
    // Usa il contentView fornito da BaseWidget
    NSView *container = self.contentView;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Refresh button
    self.refreshButton = [NSButton buttonWithTitle:@"Refresh"
                                            target:self
                                            action:@selector(refreshButtonClicked:)];
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.refreshButton];
    
    // Progress indicator
    self.progressIndicator = [[NSProgressIndicator alloc] init];
    self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
    self.progressIndicator.displayedWhenStopped = NO;
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.progressIndicator];
    
    // Scroll view and outline view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.outlineView = [[NSOutlineView alloc] init];
    self.outlineView.delegate = self;
    self.outlineView.dataSource = self;
    self.outlineView.allowsMultipleSelection = YES;
    self.outlineView.allowsColumnSelection = NO;
    self.outlineView.usesAlternatingRowBackgroundColors = YES;
    self.outlineView.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    self.outlineView.floatsGroupRows = YES;
    self.outlineView.menu = [self createContextMenu];
    
    // Create columns
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 200;
    symbolColumn.minWidth = 150;
    [self.outlineView addTableColumn:symbolColumn];
    
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Var%";
    changeColumn.width = 100;
    changeColumn.minWidth = 80;
    [self.outlineView addTableColumn:changeColumn];
    
    self.outlineView.outlineTableColumn = symbolColumn;
    
    self.scrollView.documentView = self.outlineView;
    [container addSubview:self.scrollView];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.refreshButton.topAnchor constraintEqualToAnchor:container.topAnchor constant:10],
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10],
        
        [self.progressIndicator.centerYAnchor constraintEqualToAnchor:self.refreshButton.centerYAnchor],
        [self.progressIndicator.trailingAnchor constraintEqualToAnchor:self.refreshButton.leadingAnchor constant:-10],
        
        [self.scrollView.topAnchor constraintEqualToAnchor:self.refreshButton.bottomAnchor constant:10],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:10],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-10]
    ]];
}

- (NSMenu *)createContextMenu {
    self.contextMenu = [[NSMenu alloc] init];
    
    // Send to Chain
    self.contextMenuSendToChain = [[NSMenuItem alloc] initWithTitle:@"Send to Chain"
                                                             action:@selector(sendSelectionToChain:)
                                                      keyEquivalent:@""];
    self.contextMenuSendToChain.target = self;
    [self.contextMenu addItem:self.contextMenuSendToChain];
    
    // Create Watchlist
    self.contextMenuCreateWatchlist = [[NSMenuItem alloc] initWithTitle:@"Create Watchlist from Selection"
                                                                 action:@selector(createWatchlistFromSelection:)
                                                          keyEquivalent:@""];
    self.contextMenuCreateWatchlist.target = self;
    [self.contextMenu addItem:self.contextMenuCreateWatchlist];
    
    [self.contextMenu addItem:[NSMenuItem separatorItem]];
    
    // Send All to Chain
    NSMenuItem *sendAllItem = [[NSMenuItem alloc] initWithTitle:@"Send All to Chain"
                                                         action:@selector(sendAllToChain:)
                                                  keyEquivalent:@""];
    sendAllItem.target = self;
    [self.contextMenu addItem:sendAllItem];
    
    return self.contextMenu;
}

#pragma mark - Data Structure Setup

- (void)setupInitialDataStructure {
    if (!self.dataSource) {
        self.dataSource = [NSMutableArray array];
    }
    
    [self.dataSource removeAllObjects];
    
    // Top Gainers node
    MarketDataNode *gainersNode = [[MarketDataNode alloc] init];
    gainersNode.title = @"Top Gainers";
    gainersNode.isExpandable = YES;
    gainersNode.nodeType = @"category";
    
    // Top Losers node
    MarketDataNode *losersNode = [[MarketDataNode alloc] init];
    losersNode.title = @"Top Losers";
    losersNode.isExpandable = YES;
    losersNode.nodeType = @"category";
    
    // ETF List node
    MarketDataNode *etfNode = [[MarketDataNode alloc] init];
    etfNode.title = @"ETF List";
    etfNode.isExpandable = YES;
    etfNode.nodeType = @"category";
    
    // Add rank types to gainers and losers
    NSArray *rankTypes = @[@"5min", @"1d", @"1m", @"3m", @"52w", @"preMarket", @"afterMarket"];
    
    for (NSString *rankType in rankTypes) {
        // Gainers sub-node
        MarketDataNode *gainersRankNode = [[MarketDataNode alloc] init];
        gainersRankNode.title = [self displayNameForRankType:rankType];
        gainersRankNode.isExpandable = YES;
        gainersRankNode.nodeType = @"rankType";
        gainersRankNode.rawData = @{@"rankType": rankType, @"type": @"gainers"};
        [gainersNode.children addObject:gainersRankNode];
        
        // Losers sub-node
        MarketDataNode *losersRankNode = [[MarketDataNode alloc] init];
        losersRankNode.title = [self displayNameForRankType:rankType];
        losersRankNode.isExpandable = YES;
        losersRankNode.nodeType = @"rankType";
        losersRankNode.rawData = @{@"rankType": rankType, @"type": @"losers"};
        [losersNode.children addObject:losersRankNode];
    }
    
    [self.dataSource addObject:gainersNode];
    [self.dataSource addObject:losersNode];
    [self.dataSource addObject:etfNode];
}

- (NSString *)displayNameForRankType:(NSString *)rankType {
    NSDictionary *displayNames = @{
        @"5min": @"5 Minutes",
        @"1d": @"1 Day",
        @"1m": @"1 Month",
        @"3m": @"3 Months",
        @"52w": @"52 Weeks",
        @"preMarket": @"Pre-Market",
        @"afterMarket": @"After-Market"
    };
    return displayNames[rankType] ?: rankType;
}
#pragma mark - Actions

- (void)refreshButtonClicked:(id)sender {
    [self refreshData];
}

- (void)refreshData {
    if (self.isLoading) return;
    
    self.isLoading = YES;
    [self.progressIndicator startAnimation:nil];
    self.refreshButton.enabled = NO;
    
    // Carica dati reali da Webull
    dispatch_group_t loadGroup = dispatch_group_create();
    
    // Carica ETF List
    dispatch_group_enter(loadGroup);
    [[DataManager sharedManager] requestETFListWithCompletion:^(NSArray *etfs, NSError *error) {
        if (!error && etfs) {
            [self updateETFNode:etfs];
        }
        dispatch_group_leave(loadGroup);
    }];
    
    // Carica gainers e losers per ogni rank type
    NSArray *rankTypes = @[@"5min", @"1d", @"1m", @"3m", @"52w", @"preMarket", @"afterMarket"];
    
    for (NSString *rankType in rankTypes) {
        // Gainers
        dispatch_group_enter(loadGroup);
        [[DataManager sharedManager] requestTopGainersWithRankType:rankType
                                                         pageSize:self.pageSize
                                                       completion:^(NSArray *gainers, NSError *error) {
            if (!error && gainers) {
                [self updateGainersNode:gainers forRankType:rankType];
            }
            dispatch_group_leave(loadGroup);
        }];
        
        // Losers
        dispatch_group_enter(loadGroup);
        [[DataManager sharedManager] requestTopLosersWithRankType:rankType
                                                        pageSize:self.pageSize
                                                      completion:^(NSArray *losers, NSError *error) {
            if (!error && losers) {
                [self updateLosersNode:losers forRankType:rankType];
            }
            dispatch_group_leave(loadGroup);
        }];
    }
    
    dispatch_group_notify(loadGroup, dispatch_get_main_queue(), ^{
        [self.outlineView reloadData];
        [self.progressIndicator stopAnimation:nil];
        self.refreshButton.enabled = YES;
        self.isLoading = NO;
    });
}

- (void)updateETFNode:(NSArray *)etfs {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Trova il nodo ETF
        for (MarketDataNode *categoryNode in self.dataSource) {
            if ([categoryNode.title isEqualToString:@"ETF List"]) {
                [categoryNode.children removeAllObjects];
                
                for (NSDictionary *etfData in etfs) {
                    MarketDataNode *etfNode = [[MarketDataNode alloc] init];
                    etfNode.symbol = etfData[@"symbol"];
                    etfNode.title = [NSString stringWithFormat:@"%@ - %@",
                                   etfData[@"symbol"],
                                   etfData[@"name"]];
                    etfNode.changePercent = etfData[@"changePercent"];
                    
                    double change = [etfNode.changePercent doubleValue];
                    etfNode.changeColor = (change >= 0) ? [NSColor systemGreenColor] : [NSColor systemRedColor];
                    etfNode.nodeType = @"symbol";
                    etfNode.rawData = etfData;
                    
                    [categoryNode.children addObject:etfNode];
                }
                break;
            }
        }
    });
}

- (void)updateGainersNode:(NSArray *)gainers forRankType:(NSString *)rankType {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Trova il nodo Top Gainers
        for (MarketDataNode *categoryNode in self.dataSource) {
            if ([categoryNode.title isEqualToString:@"Top Gainers"]) {
                // Trova il rank type node
                for (MarketDataNode *rankNode in categoryNode.children) {
                    if ([rankNode.rawData[@"rankType"] isEqualToString:rankType]) {
                        [rankNode.children removeAllObjects];
                        
                        for (NSDictionary *gainerData in gainers) {
                            MarketDataNode *symbolNode = [[MarketDataNode alloc] init];
                            symbolNode.symbol = gainerData[@"symbol"];
                            symbolNode.title = [NSString stringWithFormat:@"%@ - %@",
                                              gainerData[@"symbol"],
                                              gainerData[@"name"]];
                            symbolNode.changePercent = gainerData[@"changePercent"];
                            symbolNode.changeColor = [NSColor systemGreenColor];
                            symbolNode.nodeType = @"symbol";
                            symbolNode.rawData = gainerData;
                            
                            [rankNode.children addObject:symbolNode];
                        }
                        break;
                    }
                }
                break;
            }
        }
    });
}

- (void)updateLosersNode:(NSArray *)losers forRankType:(NSString *)rankType {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Trova il nodo Top Losers
        for (MarketDataNode *categoryNode in self.dataSource) {
            if ([categoryNode.title isEqualToString:@"Top Losers"]) {
                // Trova il rank type node
                for (MarketDataNode *rankNode in categoryNode.children) {
                    if ([rankNode.rawData[@"rankType"] isEqualToString:rankType]) {
                        [rankNode.children removeAllObjects];
                        
                        for (NSDictionary *loserData in losers) {
                            MarketDataNode *symbolNode = [[MarketDataNode alloc] init];
                            symbolNode.symbol = loserData[@"symbol"];
                            symbolNode.title = [NSString stringWithFormat:@"%@ - %@",
                                              loserData[@"symbol"],
                                              loserData[@"name"]];
                            symbolNode.changePercent = loserData[@"changePercent"];
                            symbolNode.changeColor = [NSColor systemRedColor];
                            symbolNode.nodeType = @"symbol";
                            symbolNode.rawData = loserData;
                            
                            [rankNode.children addObject:symbolNode];
                        }
                        break;
                    }
                }
                break;
            }
        }
    });
}

#pragma mark - Context Menu Actions

- (void)sendSelectionToChain:(id)sender {
    NSIndexSet *selectedRows = self.outlineView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray *symbols = [NSMutableArray array];
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        MarketDataNode *node = [self.outlineView itemAtRow:idx];
        if ([node.nodeType isEqualToString:@"symbol"] && node.symbol) {
            [symbols addObject:node.symbol];
        }
    }];
    
    if (symbols.count > 0) {
        NSDictionary *update = @{
            @"symbols": symbols,
            @"source": @"GeneralMarket"
        };
        [self broadcastUpdate:update];
        [self showTemporaryMessage:[NSString stringWithFormat:@"Sent %lu symbols to chain", symbols.count]];
    }
}

- (void)sendAllToChain:(id)sender {
    NSMutableArray *allSymbols = [NSMutableArray array];
    
    for (MarketDataNode *categoryNode in self.dataSource) {
        [self collectSymbolsFromNode:categoryNode intoArray:allSymbols];
    }
    
    if (allSymbols.count > 0) {
        NSDictionary *update = @{
            @"symbols": allSymbols,
            @"source": @"GeneralMarket"
        };
        [self broadcastUpdate:update];
        [self showTemporaryMessage:[NSString stringWithFormat:@"Sent %lu symbols to chain", allSymbols.count]];
    }
}

- (void)collectSymbolsFromNode:(MarketDataNode *)node intoArray:(NSMutableArray *)array {
    if ([node.nodeType isEqualToString:@"symbol"] && node.symbol) {
        [array addObject:node.symbol];
    }
    
    for (MarketDataNode *child in node.children) {
        [self collectSymbolsFromNode:child intoArray:array];
    }
}

- (void)createWatchlistFromSelection:(id)sender {
    NSIndexSet *selectedRows = self.outlineView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray *symbols = [NSMutableArray array];
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        MarketDataNode *node = [self.outlineView itemAtRow:idx];
        if ([node.nodeType isEqualToString:@"symbol"] && node.symbol) {
            [symbols addObject:node.symbol];
        }
    }];
    
    if (symbols.count > 0) {
        [self createWatchlistFromList:symbols];
    }
}

- (void)createWatchlistFromList:(NSArray *)symbols {
    // Mostra dialog per nome watchlist
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Watchlist";
    alert.informativeText = [NSString stringWithFormat:@"Create watchlist with %lu symbols:", symbols.count];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Watchlist name";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
        WatchlistManager *manager = [WatchlistManager sharedManager];
        
        // Crea la watchlist
        WatchlistData *newWatchlist = [manager createWatchlistWithName:input.stringValue];
        
        // Aggiungi i simboli
        [manager addSymbols:symbols toWatchlist:newWatchlist.name];
        
        [self showTemporaryMessage:@"Watchlist created successfully"];
    }
}

- (void)showTemporaryMessage:(NSString *)message {
    // Crea un overlay temporaneo per mostrare feedback
    NSTextField *messageLabel = [[NSTextField alloc] init];
    messageLabel.stringValue = message;
    messageLabel.backgroundColor = [NSColor controlAccentColor];
    messageLabel.textColor = [NSColor whiteColor];
    messageLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    messageLabel.alignment = NSTextAlignmentCenter;
    messageLabel.bordered = NO;
    messageLabel.editable = NO;
    messageLabel.selectable = NO;
    messageLabel.wantsLayer = YES;
    messageLabel.layer.cornerRadius = 4;
    messageLabel.layer.opacity = 0.95;
    
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:messageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [messageLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:50],
        [messageLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.contentView.widthAnchor constant:-16],
        [messageLabel.heightAnchor constraintEqualToConstant:28]
    ]];
    
    // Anima l'apparizione
    messageLabel.layer.opacity = 0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        messageLabel.animator.layer.opacity = 0.95;
    } completionHandler:^{
        // Rimuovi dopo 2 secondi
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.3;
                messageLabel.animator.layer.opacity = 0;
            } completionHandler:^{
                [messageLabel removeFromSuperview];
            }];
        });
    }];
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return self.dataSource.count;
    }
    
    MarketDataNode *node = item;
    return node.children.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return self.dataSource[index];
    }
    
    MarketDataNode *node = item;
    return node.children[index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    MarketDataNode *node = item;
    return node.isExpandable;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    MarketDataNode *node = item;
    
    if ([tableColumn.identifier isEqualToString:@"symbol"]) {
        return node.title;
    } else if ([tableColumn.identifier isEqualToString:@"change"]) {
        if (node.changePercent) {
            return [NSString stringWithFormat:@"%+.2f%%", [node.changePercent doubleValue]];
        }
        return @"";
    }
    
    return nil;
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    MarketDataNode *node = item;
    NSTableCellView *cellView = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.bordered = NO;
        textField.editable = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        
        cellView.textField = textField;
        [cellView addSubview:textField];
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:2],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-2],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    if ([tableColumn.identifier isEqualToString:@"symbol"]) {
        cellView.textField.stringValue = node.title ?: @"";
        cellView.textField.textColor = [NSColor labelColor];
        
        // Bold font for category and rankType nodes
        if ([node.nodeType isEqualToString:@"category"] || [node.nodeType isEqualToString:@"rankType"]) {
            cellView.textField.font = [NSFont boldSystemFontOfSize:12];
        } else {
            cellView.textField.font = [NSFont systemFontOfSize:12];
        }
    } else if ([tableColumn.identifier isEqualToString:@"change"]) {
        if (node.changePercent) {
            cellView.textField.stringValue = [NSString stringWithFormat:@"%+.2f%%", [node.changePercent doubleValue]];
            cellView.textField.textColor = node.changeColor ?: [NSColor labelColor];
            cellView.textField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
        } else {
            cellView.textField.stringValue = @"";
        }
    }
    
    return cellView;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    MarketDataNode *node = item;
    // Solo i nodi symbol sono selezionabili
    return [node.nodeType isEqualToString:@"symbol"];
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
    return 24.0;
}

#pragma mark - BaseWidget Override

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    // Gestisci aggiornamenti da altri widget se necessario
    NSString *updateType = update[@"type"];
    
    if ([updateType isEqualToString:@"symbolSelected"]) {
        NSString *symbol = update[@"symbol"];
        if (symbol) {
            // Potremmo evidenziare il simbolo se presente nelle nostre liste
            [self highlightSymbol:symbol];
        }
    }
}

- (void)highlightSymbol:(NSString *)symbol {
    // Cerca e seleziona il simbolo nell'outline view
    for (NSInteger i = 0; i < [self.outlineView numberOfRows]; i++) {
        MarketDataNode *node = [self.outlineView itemAtRow:i];
        if ([node.nodeType isEqualToString:@"symbol"] && [node.symbol isEqualToString:symbol]) {
            [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
            [self.outlineView scrollRowToVisible:i];
            break;
        }
    }
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    state[@"pageSize"] = @(self.pageSize);
    
    // Salva stato espanso/collassato dei nodi
    NSMutableArray *expandedItems = [NSMutableArray array];
    for (NSInteger i = 0; i < [self.outlineView numberOfRows]; i++) {
            id item = [self.outlineView itemAtRow:i];
            if ([self.outlineView isItemExpanded:item]) {
                MarketDataNode *node = item;
                if (node.title) {
                    [expandedItems addObject:node.title];
                }
            }
        }
        state[@"expandedItems"] = expandedItems;
        
        return state;
    }

    - (void)restoreState:(NSDictionary *)state {
        [super restoreState:state];
        
        if (state[@"pageSize"]) {
            self.pageSize = [state[@"pageSize"] integerValue];
        }
        
        // Ripristina stato espanso/collassato
        NSArray *expandedItems = state[@"expandedItems"];
        if (expandedItems) {
            for (NSString *title in expandedItems) {
                for (NSInteger i = 0; i < [self.outlineView numberOfRows]; i++) {
                    MarketDataNode *node = [self.outlineView itemAtRow:i];
                    if ([node.title isEqualToString:title]) {
                        [self.outlineView expandItem:node];
                        break;
                    }
                }
            }
        }
        
        [self refreshData];
    }

    #pragma mark - Lifecycle

    - (void)viewDidAppear {
        [super viewDidAppear];
        
        // Espandi i nodi principali per default
        for (MarketDataNode *node in self.dataSource) {
            if ([node.nodeType isEqualToString:@"category"]) {
                [self.outlineView expandItem:node];
            }
        }
        
        // Carica i dati iniziali
        [self refreshData];
    }

    - (void)dealloc {
        if (self.refreshTimer) {
            [self.refreshTimer invalidate];
            self.refreshTimer = nil;
        }
    }

@end
