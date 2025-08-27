//
//  PortfolioWidget.m
//  TradingApp
//
//  Implementation of advanced multi-account portfolio widget
//

#import "PortfolioWidget.h"
#import "DataHub+Portfolio.h"
#import "OrderEntryViewController.h"
#import "DataHub+MarketData.h"  // ✅ NUOVO: Necessario per i metodi di subscription
#import "downloadmanager.h"

@interface PortfolioWidget ()

/// New Order view controller (loaded in tab)
@property (nonatomic, strong) OrderEntryViewController *orderEntryViewController;

/// Table cell views cache
@property (nonatomic, strong) NSMutableDictionary *tableCellViewsCache;

@end

@implementation PortfolioWidget

#pragma mark - Widget Lifecycle

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        // Initialize arrays
        _availableAccounts = @[];
        _positions = @[];
        _orders = @[];
        _subscribedSymbols = [NSMutableSet set];
        _tableCellViewsCache = [NSMutableDictionary dictionary];
        
        // Initialize filter state
        _currentOrderStatusFilter = nil;  // All orders
        _currentOrderTypeFilter = nil;    // All types
        _currentOrderSymbolSearch = @"";
        _currentTabIndex = PortfolioTabPositions;
        
        NSLog(@"📱 PortfolioWidget initialized");
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    // Setup UI components
    [self setupAccountSelectorBar];
    [self setupPortfolioSummarySection];
    [self setupTabView];
    [self setupPositionsTable];
    [self setupOrdersTable];
    [self setupNewOrderTab];
    [self setupLayoutConstraints];
    
    // Setup notifications
    [self setupNotificationObservers];
    
    // Load initial data
    [self loadAvailableAccounts];
    
    NSLog(@"✅ PortfolioWidget content view setup complete");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Restore last selected account
    NSString *savedAccountId = [[NSUserDefaults standardUserDefaults] stringForKey:@"SelectedAccountId"];
    if (savedAccountId && self.availableAccounts.count > 0) {
        AccountModel *savedAccount = [self findAccountById:savedAccountId];
        if (savedAccount) {
            [self switchToAccount:savedAccount];
        }
    }
}

- (void)dealloc {
    // Cleanup
    [self stopAllPolling];
    [self unsubscribeFromCurrentAccountUpdates];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NSLog(@"📱 PortfolioWidget deallocated");
}

#pragma mark - UI Setup

- (void)setupAccountSelectorBar {
    // Account selector bar at top
    self.accountSelectorBar = [[NSView alloc] init];
    self.accountSelectorBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.accountSelectorBar];
    
    // Account label
    NSTextField *accountLabel = [[NSTextField alloc] init];
    accountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    accountLabel.stringValue = @"Account:";
    accountLabel.editable = NO;
    accountLabel.bordered = NO;
    accountLabel.backgroundColor = [NSColor clearColor];
    accountLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    
    // Account selector popup
    self.accountSelector = [[NSPopUpButton alloc] init];
    self.accountSelector.translatesAutoresizingMaskIntoConstraints = NO;
    [self.accountSelector setTarget:self];
    [self.accountSelector setAction:@selector(accountSelectionChanged:)];
    
    // Connection status label
    self.connectionStatusLabel = [[NSTextField alloc] init];
    self.connectionStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectionStatusLabel.stringValue = @"🔄 Loading...";
    self.connectionStatusLabel.editable = NO;
    self.connectionStatusLabel.bordered = NO;
    self.connectionStatusLabel.backgroundColor = [NSColor clearColor];
    self.connectionStatusLabel.font = [NSFont systemFontOfSize:11];
    self.connectionStatusLabel.textColor = [NSColor secondaryLabelColor];
    
    // Refresh button
    self.refreshAccountButton = [[NSButton alloc] init];
    self.refreshAccountButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.refreshAccountButton setTitle:@"🔄"];
    self.refreshAccountButton.bordered = NO;
    [self.refreshAccountButton setTarget:self];
    [self.refreshAccountButton setAction:@selector(refreshCurrentAccount:)];
    
    // Layout in horizontal stack
    NSStackView *accountStack = [[NSStackView alloc] init];
    accountStack.translatesAutoresizingMaskIntoConstraints = NO;
    accountStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    accountStack.spacing = 8;
    accountStack.alignment = NSLayoutAttributeCenterY;
    
    [accountStack addArrangedSubview:accountLabel];
    [accountStack addArrangedSubview:self.accountSelector];
    [accountStack addArrangedSubview:self.connectionStatusLabel];
    [accountStack addArrangedSubview:self.refreshAccountButton];
    
    [self.accountSelectorBar addSubview:accountStack];
    
    // Constraints for stack within bar
    [NSLayoutConstraint activateConstraints:@[
        [accountStack.leadingAnchor constraintEqualToAnchor:self.accountSelectorBar.leadingAnchor constant:8],
        [accountStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.accountSelectorBar.trailingAnchor constant:-8],
        [accountStack.centerYAnchor constraintEqualToAnchor:self.accountSelectorBar.centerYAnchor]
    ]];
}

- (void)setupPortfolioSummarySection {
    self.portfolioSummarySection = [[NSView alloc] init];
    self.portfolioSummarySection.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.portfolioSummarySection];
    
    // Create summary labels
    self.totalValueLabel = [self createSummaryLabel:@"Total: $0"];
    self.dayPLLabel = [self createSummaryLabel:@"Day P&L: $0 (0%)"];
    self.buyingPowerLabel = [self createSummaryLabel:@"Buying Power: $0"];
    self.cashBalanceLabel = [self createSummaryLabel:@"Cash: $0"];
    self.marginUsedLabel = [self createSummaryLabel:@"Margin: $0"];
    self.dayTradesLeftLabel = [self createSummaryLabel:@"Day Trades: 0"];
    
    // Arrange in grid layout (2 rows x 3 columns)
    NSStackView *topRow = [[NSStackView alloc] init];
    topRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    topRow.distribution = NSStackViewDistributionFillEqually;
    topRow.spacing = 16;
    [topRow addArrangedSubview:self.totalValueLabel];
    [topRow addArrangedSubview:self.dayPLLabel];
    [topRow addArrangedSubview:self.buyingPowerLabel];
    
    NSStackView *bottomRow = [[NSStackView alloc] init];
    bottomRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    bottomRow.distribution = NSStackViewDistributionFillEqually;
    bottomRow.spacing = 16;
    [bottomRow addArrangedSubview:self.cashBalanceLabel];
    [bottomRow addArrangedSubview:self.marginUsedLabel];
    [bottomRow addArrangedSubview:self.dayTradesLeftLabel];
    
    NSStackView *summaryStack = [[NSStackView alloc] init];
    summaryStack.translatesAutoresizingMaskIntoConstraints = NO;
    summaryStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    summaryStack.spacing = 8;
    [summaryStack addArrangedSubview:topRow];
    [summaryStack addArrangedSubview:bottomRow];
    
    [self.portfolioSummarySection addSubview:summaryStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [summaryStack.leadingAnchor constraintEqualToAnchor:self.portfolioSummarySection.leadingAnchor constant:8],
        [summaryStack.trailingAnchor constraintEqualToAnchor:self.portfolioSummarySection.trailingAnchor constant:-8],
        [summaryStack.topAnchor constraintEqualToAnchor:self.portfolioSummarySection.topAnchor constant:8],
        [summaryStack.bottomAnchor constraintEqualToAnchor:self.portfolioSummarySection.bottomAnchor constant:-8]
    ]];
}

- (NSTextField *)createSummaryLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    label.alignment = NSTextAlignmentCenter;
    return label;
}

- (void)setupTabView {
    self.mainTabView = [[NSTabView alloc] init];
    self.mainTabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.mainTabView];
    
    // Positions Tab
    NSTabViewItem *positionsTab = [[NSTabViewItem alloc] init];
    positionsTab.label = @"Positions";
    positionsTab.identifier = @(PortfolioTabPositions);
    NSView *positionsContainer = [[NSView alloc] init];
    positionsTab.view = positionsContainer;
    [self.mainTabView addTabViewItem:positionsTab];
    
    // Orders Tab
    NSTabViewItem *ordersTab = [[NSTabViewItem alloc] init];
    ordersTab.label = @"Orders";
    ordersTab.identifier = @(PortfolioTabOrders);
    NSView *ordersContainer = [[NSView alloc] init];
    ordersTab.view = ordersContainer;
    [self.mainTabView addTabViewItem:ordersTab];
    
    // New Order Tab
    NSTabViewItem *newOrderTab = [[NSTabViewItem alloc] init];
    newOrderTab.label = @"New Order";
    newOrderTab.identifier = @(PortfolioTabNewOrder);
    self.orderEntryContainer = [[NSView alloc] init];
    newOrderTab.view = self.orderEntryContainer;
    [self.mainTabView addTabViewItem:newOrderTab];
    
    // Set delegate
    self.mainTabView.delegate = (id<NSTabViewDelegate>)self;
}

- (void)setupPositionsTable {
    // Get positions container from tab
    NSTabViewItem *positionsTab = [self.mainTabView tabViewItemAtIndex:PortfolioTabPositions];
    NSView *container = positionsTab.view;
    
    // Create scroll view and table view
    self.positionsScrollView = [[NSScrollView alloc] init];
    self.positionsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.positionsScrollView.hasVerticalScroller = YES;
    self.positionsScrollView.hasHorizontalScroller = YES;
    self.positionsScrollView.borderType = NSBezelBorder;
    
    self.positionsTableView = [[NSTableView alloc] init];
    self.positionsTableView.dataSource = self;
    self.positionsTableView.delegate = self;
    self.positionsTableView.allowsMultipleSelection = YES;
    self.positionsTableView.usesAlternatingRowBackgroundColors = YES;
    
    self.positionsScrollView.documentView = self.positionsTableView;
    [container addSubview:self.positionsScrollView];
    
    // Setup table columns
    [self setupPositionsTableColumns];
    
    // Fill container
    [NSLayoutConstraint activateConstraints:@[
        [self.positionsScrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.positionsScrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.positionsScrollView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.positionsScrollView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
}

- (void)setupPositionsTableColumns {
    // Remove existing columns
    while (self.positionsTableView.tableColumns.count > 0) {
        [self.positionsTableView removeTableColumn:self.positionsTableView.tableColumns.firstObject];
    }
    
    // Column definitions
    NSArray *columnDefinitions = @[
        @{@"identifier": @"symbol", @"title": @"Symbol", @"width": @80},
        @{@"identifier": @"quantity", @"title": @"Qty", @"width": @60},
        @{@"identifier": @"avgCost", @"title": @"Avg Cost", @"width": @70},
        @{@"identifier": @"currentPrice", @"title": @"Current", @"width": @70},
        @{@"identifier": @"bidAsk", @"title": @"Bid/Ask", @"width": @80},
        @{@"identifier": @"marketValue", @"title": @"Market Val", @"width": @80},
        @{@"identifier": @"pl", @"title": @"P&L", @"width": @70},
        @{@"identifier": @"plPercent", @"title": @"%", @"width": @50},
        @{@"identifier": @"actions", @"title": @"Actions", @"width": @80}
    ];
    
    for (NSDictionary *colDef in columnDefinitions) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:colDef[@"identifier"]];
        column.title = colDef[@"title"];
        column.width = [colDef[@"width"] doubleValue];
        column.minWidth = 50;
        [self.positionsTableView addTableColumn:column];
    }
}

- (void)setupOrdersTable {
    // Get orders container from tab
    NSTabViewItem *ordersTab = [self.mainTabView tabViewItemAtIndex:PortfolioTabOrders];
    NSView *container = ordersTab.view;
    
    // Create filter controls at top
    NSView *filtersContainer = [[NSView alloc] init];
    filtersContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Filter controls
    NSTextField *statusLabel = [self createFilterLabel:@"Status:"];
    self.orderStatusFilter = [self createFilterPopUp:@[@"All", @"Active", @"Filled", @"Cancelled"]];
    [self.orderStatusFilter setTarget:self];
    [self.orderStatusFilter setAction:@selector(orderStatusFilterChanged:)];
    
    NSTextField *typeLabel = [self createFilterLabel:@"Type:"];
    self.orderTypeFilter = [self createFilterPopUp:@[@"All", @"Market", @"Limit", @"Stop", @"Stop Limit"]];
    [self.orderTypeFilter setTarget:self];
    [self.orderTypeFilter setAction:@selector(orderTypeFilterChanged:)];
    
    NSTextField *searchLabel = [self createFilterLabel:@"Symbol:"];
    self.orderSymbolSearch = [[NSSearchField alloc] init];
    self.orderSymbolSearch.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderSymbolSearch.placeholderString = @"Search symbol...";
    [self.orderSymbolSearch setTarget:self];
    [self.orderSymbolSearch setAction:@selector(orderSymbolSearchChanged:)];
    
    // Action buttons
    self.cancelSelectedOrdersButton = [[NSButton alloc] init];
    [self.cancelSelectedOrdersButton setTitle:@"Cancel Selected"];
    [self.cancelSelectedOrdersButton setTarget:self];
    [self.cancelSelectedOrdersButton setAction:@selector(cancelSelectedOrders:)];
    
    self.refreshOrdersButton = [[NSButton alloc] init];
    [self.refreshOrdersButton setTitle:@"Refresh"];
    [self.refreshOrdersButton setTarget:self];
    [self.refreshOrdersButton setAction:@selector(refreshOrders:)];
    
    // Layout filters horizontally
    NSStackView *filtersStack = [[NSStackView alloc] init];
    filtersStack.translatesAutoresizingMaskIntoConstraints = NO;
    filtersStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    filtersStack.spacing = 8;
    filtersStack.alignment = NSLayoutAttributeCenterY;
    
    [filtersStack addArrangedSubview:statusLabel];
    [filtersStack addArrangedSubview:self.orderStatusFilter];
    [filtersStack addArrangedSubview:typeLabel];
    [filtersStack addArrangedSubview:self.orderTypeFilter];
    [filtersStack addArrangedSubview:searchLabel];
    [filtersStack addArrangedSubview:self.orderSymbolSearch];
    [filtersStack addArrangedSubview:self.cancelSelectedOrdersButton];
    [filtersStack addArrangedSubview:self.refreshOrdersButton];
    
    [filtersContainer addSubview:filtersStack];
    [container addSubview:filtersContainer];
    
    // Table view
    self.ordersScrollView = [[NSScrollView alloc] init];
    self.ordersScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ordersScrollView.hasVerticalScroller = YES;
    self.ordersScrollView.hasHorizontalScroller = YES;
    self.ordersScrollView.borderType = NSBezelBorder;
    
    self.ordersTableView = [[NSTableView alloc] init];
    self.ordersTableView.dataSource = self;
    self.ordersTableView.delegate = self;
    self.ordersTableView.allowsMultipleSelection = YES;
    self.ordersTableView.usesAlternatingRowBackgroundColors = YES;
    
    self.ordersScrollView.documentView = self.ordersTableView;
    [container addSubview:self.ordersScrollView];
    
    // Setup orders table columns
    [self setupOrdersTableColumns];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Filters at top
        [filtersStack.leadingAnchor constraintEqualToAnchor:filtersContainer.leadingAnchor constant:8],
        [filtersStack.trailingAnchor constraintLessThanOrEqualToAnchor:filtersContainer.trailingAnchor constant:-8],
        [filtersStack.centerYAnchor constraintEqualToAnchor:filtersContainer.centerYAnchor],
        
        [filtersContainer.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [filtersContainer.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [filtersContainer.topAnchor constraintEqualToAnchor:container.topAnchor],
        [filtersContainer.heightAnchor constraintEqualToConstant:40],
        
        // Table below filters
        [self.ordersScrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.ordersScrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.ordersScrollView.topAnchor constraintEqualToAnchor:filtersContainer.bottomAnchor],
        [self.ordersScrollView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
}

- (NSTextField *)createFilterLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:12];
    [label setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

- (NSPopUpButton *)createFilterPopUp:(NSArray<NSString *> *)items {
    NSPopUpButton *popup = [[NSPopUpButton alloc] init];
    popup.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSString *item in items) {
        [popup addItemWithTitle:item];
    }
    [popup selectItemAtIndex:0]; // Default to first item
    return popup;
}

- (void)setupOrdersTableColumns {
    // Remove existing columns
    while (self.ordersTableView.tableColumns.count > 0) {
        [self.ordersTableView removeTableColumn:self.ordersTableView.tableColumns.firstObject];
    }
    
    // Column definitions
    NSArray *columnDefinitions = @[
        @{@"identifier": @"orderId", @"title": @"ID", @"width": @80},
        @{@"identifier": @"symbol", @"title": @"Symbol", @"width": @70},
        @{@"identifier": @"type", @"title": @"Type", @"width": @70},
        @{@"identifier": @"side", @"title": @"Side", @"width": @60},
        @{@"identifier": @"quantity", @"title": @"Qty", @"width": @60},
        @{@"identifier": @"price", @"title": @"Price", @"width": @70},
        @{@"identifier": @"status", @"title": @"Status", @"width": @80},
        @{@"identifier": @"createdTime", @"title": @"Time", @"width": @90},
        @{@"identifier": @"actions", @"title": @"Actions", @"width": @80}
    ];
    
    for (NSDictionary *colDef in columnDefinitions) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:colDef[@"identifier"]];
        column.title = colDef[@"title"];
        column.width = [colDef[@"width"] doubleValue];
        column.minWidth = 50;
        [self.ordersTableView addTableColumn:column];
    }
}

- (void)setupNewOrderTab {
    // Create and embed OrderEntryViewController
    self.orderEntryViewController = [[OrderEntryViewController alloc] init];
    self.orderEntryViewController.selectedAccount = self.selectedAccount;
    
    // Add as child view controller
    [self addChildViewController:self.orderEntryViewController];
    [self.orderEntryContainer addSubview:self.orderEntryViewController.view];
    
    // Fill container
    self.orderEntryViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.orderEntryViewController.view.leadingAnchor constraintEqualToAnchor:self.orderEntryContainer.leadingAnchor],
        [self.orderEntryViewController.view.trailingAnchor constraintEqualToAnchor:self.orderEntryContainer.trailingAnchor],
        [self.orderEntryViewController.view.topAnchor constraintEqualToAnchor:self.orderEntryContainer.topAnchor],
        [self.orderEntryViewController.view.bottomAnchor constraintEqualToAnchor:self.orderEntryContainer.bottomAnchor]
    ]];
    
}

- (void)setupLayoutConstraints {
    // Main layout: AccountBar | Summary | TabView
    [NSLayoutConstraint activateConstraints:@[
        // Account selector bar at top
        [self.accountSelectorBar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.accountSelectorBar.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.accountSelectorBar.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.accountSelectorBar.heightAnchor constraintEqualToConstant:36],
        
        // Portfolio summary below account bar
        [self.portfolioSummarySection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.portfolioSummarySection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.portfolioSummarySection.topAnchor constraintEqualToAnchor:self.accountSelectorBar.bottomAnchor],
        [self.portfolioSummarySection.heightAnchor constraintEqualToConstant:80],
        
        // Tab view fills remaining space
        [self.mainTabView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.mainTabView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.mainTabView.topAnchor constraintEqualToAnchor:self.portfolioSummarySection.bottomAnchor],
        [self.mainTabView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - Notification Observers

- (void)setupNotificationObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Portfolio notifications
    [nc addObserver:self
           selector:@selector(handlePortfolioUpdate:)
               name:PortfolioAccountsUpdatedNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(handlePortfolioUpdate:)
               name:PortfolioSummaryUpdatedNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(handlePortfolioUpdate:)
               name:PortfolioPositionsUpdatedNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(handlePortfolioUpdate:)
               name:PortfolioOrdersUpdatedNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(handleOrderStatusUpdate:)
               name:PortfolioOrderStatusChangedNotification
             object:nil];
    
    // Quote updates for position prices
    [nc addObserver:self
           selector:@selector(handleQuoteUpdate:)
               name:@"DataHubQuoteUpdatedNotification"  // ✅ CORRETTO - usa stringa invece di constante
             object:nil];
}

#pragma mark - Account Management

- (void)loadAvailableAccounts {
    self.isLoadingAccounts = YES;
    [self updateConnectionStatus];
    
    NSLog(@"PortfolioWidget: Loading accounts from all connected brokers");
    
    // Get list of connected brokers
    NSArray<NSNumber *> *connectedBrokers = [self getConnectedBrokers];
    
    if (connectedBrokers.count == 0) {
        NSLog(@"PortfolioWidget: No brokers connected");
        self.isLoadingAccounts = NO;
        self.connectionStatusLabel.stringValue = @"No brokers connected";
        return;
    }
    
    NSMutableArray<AccountModel *> *allAccounts = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    __block NSInteger successCount = 0;
    __block NSInteger errorCount = 0;
    
    // Request accounts from each connected broker separately
    for (NSNumber *brokerTypeNum in connectedBrokers) {
        DataSourceType brokerType = [brokerTypeNum integerValue];
        dispatch_group_enter(group);
        
        NSLog(@"PortfolioWidget: Requesting accounts from %@", DataSourceTypeToString(brokerType));
        
        // Use DataHub with broker-specific method
        [[DataHub shared] getAccountsFromBroker:brokerType
                                      completion:^(NSArray<AccountModel *> *accounts, BOOL isFresh, NSError *error) {
            if (error) {
                NSLog(@"PortfolioWidget: Failed to get accounts from %@: %@",
                      DataSourceTypeToString(brokerType), error.localizedDescription);
                errorCount++;
            } else {
                NSLog(@"PortfolioWidget: Got %lu accounts from %@",
                      (unsigned long)accounts.count, DataSourceTypeToString(brokerType));
                
                // Convert raw dictionaries to AccountModel objects and set broker type
                for (id accountData in accounts) {
                    AccountModel *accountModel = nil;
                    
                    if ([accountData isKindOfClass:[AccountModel class]]) {
                        accountModel = (AccountModel *)accountData;
                    } else if ([accountData isKindOfClass:[NSDictionary class]]) {
                        accountModel = [[AccountModel alloc] initWithDictionary:(NSDictionary *)accountData];
                    }
                    
                    if (accountModel) {
                        // Set the broker name so we know which broker this account belongs to
                        accountModel.brokerName = DataSourceTypeToString(brokerType);
                        [allAccounts addObject:accountModel];
                    }
                }
                successCount++;
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        self.isLoadingAccounts = NO;
        
        if (allAccounts.count == 0) {
            NSLog(@"PortfolioWidget: No accounts retrieved from any broker");
            self.connectionStatusLabel.stringValue = @"No accounts available";
            return;
        }
        
        self.availableAccounts = [allAccounts copy];
        [self populateAccountSelector];
        
        // Auto-select first account or saved account
        [self selectInitialAccount];
        
        NSLog(@"PortfolioWidget: Loaded %lu total accounts from %ld brokers (Success: %ld, Errors: %ld)",
              (unsigned long)allAccounts.count, (long)connectedBrokers.count, (long)successCount, (long)errorCount);
        
        self.connectionStatusLabel.stringValue = [NSString stringWithFormat:@"%lu accounts from %ld brokers",
                                                 (unsigned long)allAccounts.count, (long)successCount];
    });
}

- (void)selectInitialAccount {
    // Try to restore saved account
    NSString *savedAccountId = [[NSUserDefaults standardUserDefaults] stringForKey:@"SelectedAccountId"];
    AccountModel *accountToSelect = nil;
    
    if (savedAccountId) {
        accountToSelect = [self findAccountById:savedAccountId];
        if (accountToSelect) {
            NSLog(@"PortfolioWidget: Restored saved account: %@", savedAccountId);
        }
    }
    
    if (!accountToSelect && self.availableAccounts.count > 0) {
        accountToSelect = self.availableAccounts[0];
        NSLog(@"PortfolioWidget: Auto-selected first account: %@", accountToSelect.accountId);
    }
    
    if (accountToSelect) {
        [self switchToAccount:accountToSelect];
    }
}

- (NSArray<NSNumber *> *)getConnectedBrokers {
    NSMutableArray<NSNumber *> *connectedBrokers = [NSMutableArray array];
    
    // Check each broker type
    NSArray *allBrokerTypes = @[@(DataSourceTypeSchwab), @(DataSourceTypeIBKR), @(DataSourceTypeWebull)];
    
    for (NSNumber *brokerTypeNum in allBrokerTypes) {
        DataSourceType brokerType = [brokerTypeNum integerValue];
        
        // Check if broker is connected
        if ([[DownloadManager sharedManager] isDataSourceConnected:brokerType]) {
            [connectedBrokers addObject:brokerTypeNum];
            NSLog(@"PortfolioWidget: %@ is connected", DataSourceTypeToString(brokerType));
        } else {
            NSLog(@"PortfolioWidget: %@ is not connected", DataSourceTypeToString(brokerType));
        }
    }
    
    return [connectedBrokers copy];
}



- (void)populateAccountSelector {
    [self.accountSelector removeAllItems];
    
    for (AccountModel *account in self.availableAccounts) {
        NSString *displayName = [account formattedDisplayName];
        [self.accountSelector addItemWithTitle:displayName];
        
        // Store account reference in represented object
        NSMenuItem *item = [self.accountSelector itemWithTitle:displayName];
        item.representedObject = account;
    }
}

- (void)switchToAccount:(AccountModel *)account {
    if (!account || [account.accountId isEqualToString:self.selectedAccount.accountId]) {
        return; // No change needed
    }
    
    NSLog(@"PortfolioWidget: Switching to account %@ (Broker: %@)",
          account.accountId, account.brokerName);
    
    // Save selection
    [[NSUserDefaults standardUserDefaults] setObject:account.accountId forKey:@"SelectedAccountId"];
    
    // Update selected account
    self.selectedAccount = account;
    
    // Update UI selector
    NSString *displayName = [account formattedDisplayName];
    [self.accountSelector selectItemWithTitle:displayName];
    
    // Load portfolio data for this account using secure broker-specific calls
    [self loadPortfolioDataForCurrentAccount];
    
    // Update connection status
    [self updateConnectionStatus];
}




- (AccountModel *)findAccountById:(NSString *)accountId {
    for (AccountModel *account in self.availableAccounts) {
        if ([account.accountId isEqualToString:accountId]) {
            return account;
        }
    }
    return nil;
}

#pragma mark - Data Loading

- (void)loadPortfolioDataForCurrentAccount {
    if (!self.selectedAccount) {
        NSLog(@"PortfolioWidget: No selected account to load portfolio data");
        return;
    }
    
    NSString *accountId = self.selectedAccount.accountId;
    DataSourceType brokerType = [self dataSourceTypeFromBrokerName:self.selectedAccount.brokerName];
    
    NSLog(@"PortfolioWidget: Loading portfolio data for account %@ from broker %@",
          accountId, self.selectedAccount.brokerName);
    
    self.isLoadingPortfolioData = YES;
    
    // Use DataHub with broker-specific call
    [[DataHub shared] getPortfolioSummaryForAccount:accountId
                                         fromBroker:brokerType
                                         completion:^(PortfolioSummaryModel *summary, BOOL isFresh) {
        self.isLoadingPortfolioData = NO;
        
        if (summary) {
            self.portfolioSummary = summary;
            [self updatePortfolioSummaryDisplay];
        }
    }];
    
    // Load positions using DataHub broker-specific call
    [self loadPositionsForCurrentAccount];
    
    // Load orders using DataHub broker-specific call
    [self loadOrdersForCurrentAccount];
    
    // Start polling using existing method
    [self startPollingForCurrentAccount];
}


- (void)loadPositionsForCurrentAccount {
    if (!self.selectedAccount) return;
    
    NSString *accountId = self.selectedAccount.accountId;
    DataSourceType brokerType = [self dataSourceTypeFromBrokerName:self.selectedAccount.brokerName];
    
    self.isLoadingPositions = YES;
    
    [[DataHub shared] getPositionsForAccount:accountId
                                  fromBroker:brokerType
                                  completion:^(NSArray<AdvancedPositionModel *> *positions, BOOL isFresh) {
        self.isLoadingPositions = NO;
        self.positions = positions ?: @[];
        
        [self refreshPositionsTable];
        [self subscribeToPositionPrices];
        
        NSLog(@"PortfolioWidget: Loaded %lu positions for account %@",
              (unsigned long)self.positions.count, accountId);
    }];
}


- (void)loadOrdersForCurrentAccount {
    if (!self.selectedAccount) return;
    
    NSString *accountId = self.selectedAccount.accountId;
    DataSourceType brokerType = [self dataSourceTypeFromBrokerName:self.selectedAccount.brokerName];
    
    self.isLoadingOrders = YES;
    
    [[DataHub shared] getOrdersForAccount:accountId
                               fromBroker:brokerType
                               withStatus:self.currentOrderStatusFilter
                               completion:^(NSArray<AdvancedOrderModel *> *orders, BOOL isFresh) {
        self.isLoadingOrders = NO;
        self.orders = orders ?: @[];
        
        [self refreshOrdersTable];
        
        NSLog(@"PortfolioWidget: Loaded %lu orders for account %@",
              (unsigned long)self.orders.count, accountId);
    }];
}


- (DataSourceType)dataSourceTypeFromBrokerName:(NSString *)brokerName {
    if ([brokerName isEqualToString:@"Schwab"]) {
        return DataSourceTypeSchwab;
    } else if ([brokerName isEqualToString:@"IBKR"]) {
        return DataSourceTypeIBKR;
    } else if ([brokerName isEqualToString:@"Webull"]) {
        return DataSourceTypeWebull;
    } else {
        NSLog(@"Unknown broker name: %@, defaulting to Other", brokerName);
        return DataSourceTypeOther;
    }
}


- (void)placeOrder:(NSDictionary *)orderData {
    if (!self.selectedAccount) {
        NSLog(@"PortfolioWidget: Cannot place order - no account selected");
        return;
    }
    
    NSString *accountId = self.selectedAccount.accountId;
    DataSourceType brokerType = [self dataSourceTypeFromBrokerName:self.selectedAccount.brokerName];
    
    NSLog(@"PortfolioWidget: Placing order for account %@ using broker %@",
          accountId, self.selectedAccount.brokerName);
    
    [[DataHub shared] placeOrder:orderData
                      forAccount:accountId
                     usingBroker:brokerType
                      completion:^(NSString *orderId, NSError *error) {
        if (error) {
            NSLog(@"PortfolioWidget: Order placement failed: %@", error.localizedDescription);
            // Show error to user
        } else {
            NSLog(@"PortfolioWidget: Order placed successfully with ID: %@", orderId);
            // Refresh orders and positions
            [self loadOrdersForCurrentAccount];
            [self loadPositionsForCurrentAccount];
        }
    }];
}


#pragma mark - Real-Time Updates

- (void)handleQuoteUpdate:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"];
    
    if (!symbol || !quote) return;
    
    // Update position prices
    [self updatePositionPricesFromQuote:quote];
    
    // Update order entry view with latest quote
    [self.orderEntryViewController updateMarketDataForSymbol:symbol quote:quote];
}

- (void)updatePositionPricesFromQuote:(MarketQuoteModel *)quote {
    BOOL positionsUpdated = NO;
    
    for (AdvancedPositionModel *position in self.positions) {
        if ([position.symbol isEqualToString:quote.symbol]) {
            // ✅ CORREZIONE: Accesso corretto alle proprietà NSNumber
            position.currentPrice = quote.last.doubleValue; // ✅ CORRETTO: usa .last invece di .lastPrice
            position.bidPrice = quote.bid ? quote.bid.doubleValue : 0.0; // ✅ CORRETTO: .doubleValue
            position.askPrice = quote.ask ? quote.ask.doubleValue : 0.0; // ✅ CORRETTO: .doubleValue
            position.dayHigh = quote.high ? quote.high.doubleValue : 0.0; // ✅ CORRETTO: .doubleValue
            position.dayLow = quote.low ? quote.low.doubleValue : 0.0; // ✅ CORRETTO: .doubleValue
            position.dayOpen = quote.open ? quote.open.doubleValue : 0.0; // ✅ CORRETTO: .doubleValue
            position.previousClose = quote.previousClose ? quote.previousClose.doubleValue : 0.0; // ✅ CORRETTO: .doubleValue
            position.volume = quote.volume ? quote.volume.integerValue : 0; // ✅ CORRETTO: .integerValue
            position.priceLastUpdated = [NSDate date];
            
            // Recalculate derived values
            position.marketValue = position.quantity * position.currentPrice;
            position.unrealizedPL = position.marketValue - (position.quantity * position.avgCost);
            
            if (position.quantity * position.avgCost != 0) {
                position.unrealizedPLPercent = (position.unrealizedPL / (position.quantity * position.avgCost)) * 100.0;
            }
            
            positionsUpdated = YES;
        }
    }
    
    if (positionsUpdated) {
        [self refreshPositionsTable];
        [self recalculatePortfolioTotals];
    }
}
- (void)recalculatePortfolioTotals {
    if (!self.portfolioSummary) return;
    
    // Recalculate total value from current position prices
    double calculatedTotalValue = self.portfolioSummary.cashBalance;
    double calculatedDayPL = 0.0;
    
    for (AdvancedPositionModel *position in self.positions) {
        calculatedTotalValue += position.marketValue;
        
        // Day P&L = (current - previousClose) * quantity
        if (position.previousClose > 0) {
            double dayChange = (position.currentPrice - position.previousClose) * position.quantity;
            calculatedDayPL += dayChange;
        }
    }
    
    // Update portfolio summary with calculated values
    self.portfolioSummary.totalValue = calculatedTotalValue;
    self.portfolioSummary.dayPL = calculatedDayPL;
    
    if (calculatedTotalValue > 0) {
        self.portfolioSummary.dayPLPercent = (calculatedDayPL / calculatedTotalValue) * 100.0;
    }
    
    [self updatePortfolioSummaryDisplay];
}

#pragma mark - Action Methods

- (IBAction)accountSelectionChanged:(NSPopUpButton *)sender {
    NSMenuItem *selectedItem = sender.selectedItem;
    AccountModel *selectedAccount = selectedItem.representedObject;
    
    if (selectedAccount) {
        [self switchToAccount:selectedAccount];
    }
}

- (IBAction)refreshCurrentAccount:(NSButton *)sender {
    if (!self.selectedAccount) return;
    
    NSLog(@"🔄 PortfolioWidget: Force refreshing account %@", self.selectedAccount.accountId);
    
    DataSourceType brokerType = [self dataSourceTypeFromBrokerName:self.selectedAccount.brokerName];
    [[DataHub shared] getPortfolioSummaryForAccount:self.selectedAccount.accountId
                                         fromBroker:brokerType
                                         completion:^(PortfolioSummaryModel *summary, BOOL isFresh) {
        // Mantieni la logica esistente, ma adatta per il nuovo formato
        if (summary) {
            // Success - equivalente a quando error era nil
            self.portfolioSummary = summary;
            [self updatePortfolioSummaryDisplay];
            [self loadPositionsForCurrentAccount];
            [self loadOrdersForCurrentAccount];
        } else {
            // Error case - quando summary è nil
            NSLog(@"❌ PortfolioWidget: Failed to refresh portfolio");
            self.connectionStatusLabel.stringValue = @"Refresh failed";
        }
    }];
}

#pragma mark - Display Updates

- (void)updateConnectionStatus {
    if (self.isLoadingAccounts) {
        self.connectionStatusLabel.stringValue = @"🔄 Loading accounts...";
        self.connectionStatusLabel.textColor = [NSColor secondaryLabelColor];
    } else if (!self.selectedAccount) {
        self.connectionStatusLabel.stringValue = @"❌ No account selected";
        self.connectionStatusLabel.textColor = [NSColor systemRedColor];
    } else if (self.selectedAccount.isConnected) {
        self.connectionStatusLabel.stringValue = @"📡 Connected";
        self.connectionStatusLabel.textColor = [NSColor systemGreenColor];
    } else {
        self.connectionStatusLabel.stringValue = @"🔌 Disconnected";
        self.connectionStatusLabel.textColor = [NSColor systemOrangeColor];
    }
}

- (void)updatePortfolioSummaryDisplay {
    if (!self.portfolioSummary) {
        // Show empty state
        self.totalValueLabel.stringValue = @"Total: --";
        self.dayPLLabel.stringValue = @"Day P&L: --";
        self.buyingPowerLabel.stringValue = @"Buying Power: --";
        self.cashBalanceLabel.stringValue = @"Cash: --";
        self.marginUsedLabel.stringValue = @"Margin: --";
        self.dayTradesLeftLabel.stringValue = @"Day Trades: --";
        return;
    }
    
    PortfolioSummaryModel *summary = self.portfolioSummary;
    
    // Update labels with formatted values
    self.totalValueLabel.stringValue = [NSString stringWithFormat:@"Total: %@", [self formatCurrency:summary.totalValue]];
    
    NSString *dayPLText = [NSString stringWithFormat:@"Day P&L: %@ (%@)",
                          [self formatCurrency:summary.dayPL], [self formatPercentage:summary.dayPLPercent]];
    self.dayPLLabel.stringValue = dayPLText;
    self.dayPLLabel.textColor = [self colorForPLValue:summary.dayPL];
    
    self.buyingPowerLabel.stringValue = [NSString stringWithFormat:@"Buying Power: %@", [self formatCurrency:summary.buyingPower]];
    self.cashBalanceLabel.stringValue = [NSString stringWithFormat:@"Cash: %@", [self formatCurrency:summary.cashBalance]];
    self.marginUsedLabel.stringValue = [NSString stringWithFormat:@"Margin: %@", [self formatCurrency:summary.marginUsed]];
    self.dayTradesLeftLabel.stringValue = [NSString stringWithFormat:@"Day Trades: %ld", (long)summary.dayTradesLeft];
    
    // Color code day trades if low
    if (summary.dayTradesLeft <= 0) {
        self.dayTradesLeftLabel.textColor = [NSColor systemRedColor];
    } else if (summary.dayTradesLeft <= 1) {
        self.dayTradesLeftLabel.textColor = [NSColor systemOrangeColor];
    } else {
        self.dayTradesLeftLabel.textColor = [NSColor labelColor];
    }
}

#pragma mark - Helper Methods

- (NSString *)formatCurrency:(double)amount {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.maximumFractionDigits = 2;
    return [formatter stringFromNumber:@(amount)];
}

- (NSString *)formatPercentage:(double)percentage {
    return [NSString stringWithFormat:@"%.2f%%", percentage];
}

- (NSColor *)colorForPLValue:(double)plValue {
    if (plValue > 0) {
        return [NSColor systemGreenColor];
    } else if (plValue < 0) {
        return [NSColor systemRedColor];
    } else {
        return [NSColor labelColor];
    }
}

#pragma mark - Subscription Management

- (void)subscribeToPositionPrices {
    // Clear existing subscriptions
    for (NSString *symbol in self.subscribedSymbols) {
        // ✅ CORREZIONE: Usa DataHub shared e nome metodo corretto
        [[DataHub shared] unsubscribeFromQuoteUpdatesForSymbol:symbol];
    }
    [self.subscribedSymbols removeAllObjects];
    
    // Subscribe to current position symbols
    for (AdvancedPositionModel *position in self.positions) {
        // ✅ CORREZIONE: Usa DataHub shared e nome metodo corretto
        [[DataHub shared] subscribeToQuoteUpdatesForSymbol:position.symbol];
        [self.subscribedSymbols addObject:position.symbol];
    }
    
    NSLog(@"📡 PortfolioWidget: Subscribed to %lu symbols for real-time prices", (unsigned long)self.subscribedSymbols.count);
}

- (void)unsubscribeFromCurrentAccountUpdates {
    // Unsubscribe from all symbols
    for (NSString *symbol in self.subscribedSymbols) {
        // ✅ CORREZIONE: Usa DataHub shared
        [[DataHub shared] unsubscribeFromQuoteUpdatesForSymbol:symbol];
    }
    [self.subscribedSymbols removeAllObjects];
    
    NSLog(@"📡 PortfolioWidget: Unsubscribed from all quote updates");
}

#pragma mark - Polling Management

- (void)startPollingForCurrentAccount {
    [self stopAllPolling];
    
    if (!self.selectedAccount) return;
    
    NSLog(@"⏲ PortfolioWidget: Starting polling for account %@", self.selectedAccount.accountId);
    
    // Portfolio summary polling (30 seconds)
    self.portfolioSummaryTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                                   target:self
                                                                 selector:@selector(refreshPortfolioSummary)
                                                                 userInfo:nil
                                                                  repeats:YES];
    
    // Orders polling (15 seconds for active orders)
    self.ordersRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                               target:self
                                                             selector:@selector(refreshOrdersIfActive)
                                                             userInfo:nil
                                                              repeats:YES];
}

- (void)stopAllPolling {
    if (self.portfolioSummaryTimer) {
        [self.portfolioSummaryTimer invalidate];
        self.portfolioSummaryTimer = nil;
    }
    
    if (self.ordersRefreshTimer) {
        [self.ordersRefreshTimer invalidate];
        self.ordersRefreshTimer = nil;
    }
    
    NSLog(@"⏹ PortfolioWidget: Stopped all polling timers");
}

- (void)refreshPortfolioSummary {
    if (!self.selectedAccount) return;
    
    DataSourceType brokerType = [self dataSourceTypeFromBrokerName:self.selectedAccount.brokerName];
    [[DataHub shared] getPortfolioSummaryForAccount:self.selectedAccount.accountId
                                         fromBroker:brokerType
                                         completion:^(PortfolioSummaryModel *summary, BOOL isFresh) {
        self.portfolioSummary = summary;
        [self updatePortfolioSummaryDisplay];
    }];
}

- (void)refreshOrdersIfActive {
    // Only refresh if we have active orders or user is viewing orders tab
    BOOL hasActiveOrders = NO;
    for (AdvancedOrderModel *order in self.orders) {
        if ([order isActive]) {
            hasActiveOrders = YES;
            break;
        }
    }
    
    if (hasActiveOrders || self.currentTabIndex == PortfolioTabOrders) {
        [self loadOrdersForCurrentAccount];
    }
}

#pragma mark - Table Management

- (void)refreshPositionsTable {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.positionsTableView reloadData];
    });
}

- (void)refreshOrdersTable {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.ordersTableView reloadData];
    });
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.positionsTableView) {
        return self.positions.count;
    } else if (tableView == self.ordersTableView) {
        return [[self filteredOrders] count];
    }
    return 0;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.ordersTableView) {
        // ✅ CORREZIONE: Gestione corretta per orders table
        return [self ordersTableView:tableView viewForTableColumn:tableColumn row:row];
    } else if (tableView == self.positionsTableView) {
        // Gestione positions table
        return [self positionsTableView:tableView viewForTableColumn:tableColumn row:row];
    }
    
    return nil;
}
- (NSView *)positionsTableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.positions.count) return nil;
    
    AdvancedPositionModel *position = self.positions[row];
    NSString *identifier = tableColumn.identifier;
    
    // Create table cell view
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.bezeled = NO;
        textField.editable = NO;
        textField.backgroundColor = [NSColor clearColor];
        [cellView addSubview:textField];
        cellView.textField = textField;
    }
    
    // Set cell content based on column
    if ([identifier isEqualToString:@"symbol"]) {
        cellView.textField.stringValue = position.symbol ?: @"";
    } else if ([identifier isEqualToString:@"quantity"]) {
        cellView.textField.stringValue = [NSString stringWithFormat:@"%.0f", position.quantity];
    } else if ([identifier isEqualToString:@"avgCost"]) {
        cellView.textField.stringValue = [NSString stringWithFormat:@"$%.2f", position.avgCost];
    } else if ([identifier isEqualToString:@"currentPrice"]) {
        cellView.textField.stringValue = [NSString stringWithFormat:@"$%.2f", position.currentPrice];
    } else if ([identifier isEqualToString:@"marketValue"]) {
        cellView.textField.stringValue = [self formatCurrency:position.marketValue];
    } else if ([identifier isEqualToString:@"unrealizedPL"]) {
        cellView.textField.stringValue = [self formatCurrency:position.unrealizedPL];
        cellView.textField.textColor = [self colorForPLValue:position.unrealizedPL];
    } else if ([identifier isEqualToString:@"unrealizedPLPercent"]) {
        cellView.textField.stringValue = [NSString stringWithFormat:@"%.2f%%", position.unrealizedPLPercent];
        cellView.textField.textColor = [self colorForPLValue:position.unrealizedPL];
    }
    
    return cellView;
}

- (NSView *)ordersTableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.orders.count) return nil;
    
    AdvancedOrderModel *order = self.orders[row]; // ✅ CORRETTO: definisci order correttamente
    NSString *identifier = tableColumn.identifier;
    
    // Create table cell view
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.bezeled = NO;
        textField.editable = NO;
        textField.backgroundColor = [NSColor clearColor];
        [cellView addSubview:textField];
        cellView.textField = textField;
    }
    
    // Set cell content based on column
    if ([identifier isEqualToString:@"orderId"]) {
        cellView.textField.stringValue = order.orderId ?: @"";
    } else if ([identifier isEqualToString:@"symbol"]) {
        cellView.textField.stringValue = order.symbol ?: @"";
    } else if ([identifier isEqualToString:@"type"]) {
        cellView.textField.stringValue = order.orderType ?: @"";
    } else if ([identifier isEqualToString:@"side"]) {
        cellView.textField.stringValue = order.side ?: @"";
    } else if ([identifier isEqualToString:@"quantity"]) {
        cellView.textField.stringValue = [NSString stringWithFormat:@"%.0f", order.quantity];
    } else if ([identifier isEqualToString:@"price"]) {
        if (order.price > 0) {
            cellView.textField.stringValue = [NSString stringWithFormat:@"$%.2f", order.price];
        } else {
            cellView.textField.stringValue = @"MARKET";
        }
    } else if ([identifier isEqualToString:@"status"]) {
        cellView.textField.stringValue = order.status ?: @"";
        
        // Color code status
        if ([order.status isEqualToString:@"FILLED"]) {
            cellView.textField.textColor = [NSColor systemGreenColor];
        } else if ([order.status isEqualToString:@"CANCELLED"] || [order.status isEqualToString:@"REJECTED"]) {
            cellView.textField.textColor = [NSColor systemRedColor];
        } else {
            cellView.textField.textColor = [NSColor labelColor];
        }
    } else if ([identifier isEqualToString:@"createdTime"]) {
        if (order.createdDate) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"MM/dd HH:mm";
            cellView.textField.stringValue = [formatter stringFromDate:order.createdDate];
        } else {
            cellView.textField.stringValue = @"--";
        }
    }
    
    return cellView;
}

#pragma mark - Order Filtering

- (NSArray<AdvancedOrderModel *> *)filteredOrders {
    NSArray<AdvancedOrderModel *> *filtered = self.orders;
    
    // Apply status filter
    if (self.currentOrderStatusFilter && ![self.currentOrderStatusFilter isEqualToString:@"All"]) {
        NSString *statusFilter = self.currentOrderStatusFilter;
        
        filtered = [filtered filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AdvancedOrderModel *order, NSDictionary *bindings) {
            if ([statusFilter isEqualToString:@"Active"]) {
                return [order isActive];
            } else if ([statusFilter isEqualToString:@"Filled"]) {
                return [order isCompleted];
            } else if ([statusFilter isEqualToString:@"Cancelled"]) {
                return [order isCancelled];
            }
            return YES;
        }]];
    }
    
    // Apply type filter
    if (self.currentOrderTypeFilter && ![self.currentOrderTypeFilter isEqualToString:@"All"]) {
        NSString *typeFilter = self.currentOrderTypeFilter;
        
        filtered = [filtered filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AdvancedOrderModel *order, NSDictionary *bindings) {
            if ([typeFilter isEqualToString:@"Market"]) {
                return [order.orderType isEqualToString:@"MARKET"];
            } else if ([typeFilter isEqualToString:@"Limit"]) {
                return [order.orderType isEqualToString:@"LIMIT"];
            } else if ([typeFilter isEqualToString:@"Stop"]) {
                return [order.orderType isEqualToString:@"STOP"];
            } else if ([typeFilter isEqualToString:@"Stop Limit"]) {
                return [order.orderType isEqualToString:@"STOP_LIMIT"];
            }
            return YES;
        }]];
    }
    
    // Apply symbol search
    if (self.currentOrderSymbolSearch.length > 0) {
        NSString *searchTerm = self.currentOrderSymbolSearch.uppercaseString;
        filtered = [filtered filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AdvancedOrderModel *order, NSDictionary *bindings) {
            return [order.symbol.uppercaseString containsString:searchTerm];
        }]];
    }
    
    return filtered;
}

#pragma mark - Filter Actions

- (IBAction)orderStatusFilterChanged:(NSPopUpButton *)sender {
    NSString *selectedStatus = sender.selectedItem.title;
    self.currentOrderStatusFilter = [selectedStatus isEqualToString:@"All"] ? nil : selectedStatus;
    [self refreshOrdersTable];
    
    NSLog(@"📋 PortfolioWidget: Order status filter changed to: %@", selectedStatus);
}

- (IBAction)orderTypeFilterChanged:(NSPopUpButton *)sender {
    NSString *selectedType = sender.selectedItem.title;
    self.currentOrderTypeFilter = [selectedType isEqualToString:@"All"] ? nil : selectedType;
    [self refreshOrdersTable];
    
    NSLog(@"📋 PortfolioWidget: Order type filter changed to: %@", selectedType);
}

- (IBAction)orderSymbolSearchChanged:(NSSearchField *)sender {
    self.currentOrderSymbolSearch = sender.stringValue;
    [self refreshOrdersTable];
    
    NSLog(@"📋 PortfolioWidget: Order symbol search changed to: %@", sender.stringValue);
}

#pragma mark - Order Actions

- (IBAction)cancelSelectedOrders:(id)sender {
    NSIndexSet *selectedRows = self.ordersTableView.selectedRowIndexes;
    if (selectedRows.count == 0) {
        NSLog(@"⚠️ PortfolioWidget: No orders selected for cancellation");
        return;
    }
    
    NSArray<AdvancedOrderModel *> *filteredOrders = [self filteredOrders];
    NSMutableArray<AdvancedOrderModel *> *ordersToCancel = [NSMutableArray array];
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < filteredOrders.count) {
            AdvancedOrderModel *order = filteredOrders[idx];
            if ([order isActive]) {
                [ordersToCancel addObject:order];
            }
        }
    }];
    
    if (ordersToCancel.count == 0) {
        NSLog(@"⚠️ PortfolioWidget: No active orders selected");
        return;
    }
    
    // Show confirmation dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Cancel Selected Orders";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to cancel %lu selected orders?", (unsigned long)ordersToCancel.count];
    [alert addButtonWithTitle:@"Cancel Orders"];
    [alert addButtonWithTitle:@"Keep Orders"];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) {
            [self cancelOrders:ordersToCancel];
        }
    }];
}


- (void)cancelOrder:(NSString *)orderId {
    if (!self.selectedAccount) {
        NSLog(@"PortfolioWidget: Cannot cancel order - no account selected");
        return;
    }
    
    NSString *accountId = self.selectedAccount.accountId;
    DataSourceType brokerType = [self dataSourceTypeFromBrokerName:self.selectedAccount.brokerName];
    
    NSLog(@"PortfolioWidget: Cancelling order %@ for account %@ using broker %@",
          orderId, accountId, self.selectedAccount.brokerName);
    
    [[DataHub shared] cancelOrder:orderId
                       forAccount:accountId
                      usingBroker:brokerType
                       completion:^(BOOL success, NSError *error) {
        if (error || !success) {
            NSLog(@"PortfolioWidget: Order cancellation failed: %@", error.localizedDescription);
            // Show error to user
        } else {
            NSLog(@"PortfolioWidget: Order cancelled successfully");
            // Refresh orders
            [self loadOrdersForCurrentAccount];
        }
    }];
}




- (void)cancelOrders:(NSArray<AdvancedOrderModel *> *)orders {
    NSString *accountId = self.selectedAccount.accountId;
    DataSourceType brokerType = [self dataSourceTypeFromBrokerName:self.selectedAccount.brokerName];
    
    for (AdvancedOrderModel *order in orders) {
        [[DataHub shared] cancelOrder:order.orderId
                          forAccount:accountId
                         usingBroker:brokerType
                          completion:^(BOOL success, NSError *error) {
            if (success) {
                NSLog(@"✅ PortfolioWidget: Cancelled order %@", order.orderId);
            } else {
                NSLog(@"❌ PortfolioWidget: Failed to cancel order %@: %@", order.orderId, error);
            }
        }];
    }
    
    // Refresh orders after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadOrdersForCurrentAccount];
    });
}

- (IBAction)refreshOrders:(id)sender {
    [self loadOrdersForCurrentAccount];
}

#pragma mark - Notification Handlers

- (void)handlePortfolioUpdate:(NSNotification *)notification {
    NSString *notificationName = notification.name;
    NSDictionary *userInfo = notification.userInfo;
    NSString *accountId = userInfo[@"accountId"];
    
    // Only process updates for current account
    if (accountId && ![accountId isEqualToString:self.selectedAccount.accountId]) {
        return;
    }
    
    if ([notificationName isEqualToString:PortfolioAccountsUpdatedNotification]) {
        NSArray<AccountModel *> *accounts = userInfo[@"accounts"];
        self.availableAccounts = accounts;
        [self populateAccountSelector];
        
    } else if ([notificationName isEqualToString:PortfolioSummaryUpdatedNotification]) {
        PortfolioSummaryModel *summary = userInfo[@"summary"];
        self.portfolioSummary = summary;
        [self updatePortfolioSummaryDisplay];
        
    } else if ([notificationName isEqualToString:PortfolioPositionsUpdatedNotification]) {
        NSArray<AdvancedPositionModel *> *positions = userInfo[@"positions"];
        self.positions = positions;
        [self refreshPositionsTable];
        [self subscribeToPositionPrices];
        
    } else if ([notificationName isEqualToString:PortfolioOrdersUpdatedNotification]) {
        NSArray<AdvancedOrderModel *> *orders = userInfo[@"orders"];
        self.orders = orders;
        [self refreshOrdersTable];
    }
}

- (void)handleOrderStatusUpdate:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *accountId = userInfo[@"accountId"];
    NSString *orderId = userInfo[@"orderId"];
    NSString *newStatus = userInfo[@"status"];
    
    // Only process updates for current account
    if (![accountId isEqualToString:self.selectedAccount.accountId]) {
        return;
    }
    
    // Find and update the order
    for (AdvancedOrderModel *order in self.orders) {
        if ([order.orderId isEqualToString:orderId]) {
            order.status = newStatus;
            order.updatedDate = [NSDate date];
            
            // Check if order was filled
            if ([newStatus isEqualToString:@"FILLED"]) {
                NSLog(@"✅ PortfolioWidget: Order %@ filled", orderId);
                
                // Refresh positions to reflect fill
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self loadPositionsForCurrentAccount];
                    [self loadPortfolioDataForCurrentAccount];
                });
            }
            
            break;
        }
    }
    
    [self refreshOrdersTable];
}

#pragma mark - Tab View Delegate

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    self.currentTabIndex = [tabViewItem.identifier integerValue];
    
    NSLog(@"📱 PortfolioWidget: Switched to tab %ld", (long)self.currentTabIndex);
    
    // Refresh data when switching to orders tab
    if (self.currentTabIndex == PortfolioTabOrders) {
        [self loadOrdersForCurrentAccount];
    }
    
    // Update order entry view when switching to new order tab
    if (self.currentTabIndex == PortfolioTabNewOrder) {
        [self.orderEntryViewController refreshMarketData];
    }
}

#pragma mark - State Serialization (BaseWidget Override)

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    if (self.selectedAccount) {
        state[@"selectedAccountId"] = self.selectedAccount.accountId;
    }
    
    state[@"currentTabIndex"] = @(self.currentTabIndex);
    state[@"orderStatusFilter"] = self.currentOrderStatusFilter ?: @"All";
    state[@"orderTypeFilter"] = self.currentOrderTypeFilter ?: @"All";
    state[@"orderSymbolSearch"] = self.currentOrderSymbolSearch ?: @"";
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    // Restore selected account (will be applied when accounts load)
    NSString *savedAccountId = state[@"selectedAccountId"];
    if (savedAccountId) {
        [[NSUserDefaults standardUserDefaults] setObject:savedAccountId forKey:@"SelectedAccountId"];
    }
    
    // Restore tab selection
    if (state[@"currentTabIndex"]) {
        NSInteger tabIndex = [state[@"currentTabIndex"] integerValue];
        if (tabIndex >= 0 && tabIndex < self.mainTabView.numberOfTabViewItems) {
            [self.mainTabView selectTabViewItemAtIndex:tabIndex];
            self.currentTabIndex = tabIndex;
        }
    }
    
    // Restore filter state
    self.currentOrderStatusFilter = state[@"orderStatusFilter"];
    if ([self.currentOrderStatusFilter isEqualToString:@"All"]) {
        self.currentOrderStatusFilter = nil;
    }
    
    self.currentOrderTypeFilter = state[@"orderTypeFilter"];
    if ([self.currentOrderTypeFilter isEqualToString:@"All"]) {
        self.currentOrderTypeFilter = nil;
    }
    
    self.currentOrderSymbolSearch = state[@"orderSymbolSearch"] ?: @"";
    
    // Apply restored filter state to UI when available
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.orderStatusFilter) {
            [self.orderStatusFilter selectItemWithTitle:state[@"orderStatusFilter"] ?: @"All"];
        }
        if (self.orderTypeFilter) {
            [self.orderTypeFilter selectItemWithTitle:state[@"orderTypeFilter"] ?: @"All"];
        }
        if (self.orderSymbolSearch) {
            self.orderSymbolSearch.stringValue = self.currentOrderSymbolSearch;
        }
    });
}

@end
