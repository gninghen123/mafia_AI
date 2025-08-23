//
//  PortfolioWidget.h
//  TradingApp
//
//  Advanced multi-account portfolio widget with trading capabilities
//

#import "BaseWidget.h"
#import "TradingRuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PortfolioTabIndex) {
    PortfolioTabPositions = 0,
    PortfolioTabOrders = 1,
    PortfolioTabNewOrder = 2
};

typedef NS_ENUM(NSInteger, PositionTableColumn) {
    PositionColumnSymbol = 0,
    PositionColumnQuantity = 1,
    PositionColumnAvgCost = 2,
    PositionColumnCurrentPrice = 3,
    PositionColumnBidAsk = 4,
    PositionColumnMarketValue = 5,
    PositionColumnPL = 6,
    PositionColumnPLPercent = 7,
    PositionColumnActions = 8
};

typedef NS_ENUM(NSInteger, OrderTableColumn) {
    OrderColumnOrderId = 0,
    OrderColumnSymbol = 1,
    OrderColumnType = 2,
    OrderColumnSide = 3,
    OrderColumnQuantity = 4,
    OrderColumnPrice = 5,
    OrderColumnStatus = 6,
    OrderColumnCreatedTime = 7,
    OrderColumnActions = 8
};

@interface PortfolioWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate>

#pragma mark - Multi-Account Support

/// All available accounts from all brokers
@property (nonatomic, strong) NSArray<AccountModel *> *availableAccounts;

/// Currently selected account
@property (nonatomic, strong, nullable) AccountModel *selectedAccount;

/// Account selector UI
@property (nonatomic, strong) IBOutlet NSPopUpButton *accountSelector;
@property (nonatomic, strong) IBOutlet NSTextField *connectionStatusLabel;
@property (nonatomic, strong) IBOutlet NSButton *refreshAccountButton;

#pragma mark - Account-Specific Data

/// Portfolio summary for selected account
@property (nonatomic, strong, nullable) PortfolioSummaryModel *portfolioSummary;

/// Positions for selected account
@property (nonatomic, strong) NSArray<AdvancedPositionModel *> *positions;

/// Orders for selected account (filtered)
@property (nonatomic, strong) NSArray<AdvancedOrderModel *> *orders;

#pragma mark - UI Components - Account Bar

@property (nonatomic, strong) IBOutlet NSView *accountSelectorBar;

#pragma mark - UI Components - Portfolio Summary

@property (nonatomic, strong) IBOutlet NSView *portfolioSummarySection;
@property (nonatomic, strong) IBOutlet NSTextField *totalValueLabel;
@property (nonatomic, strong) IBOutlet NSTextField *dayPLLabel;
@property (nonatomic, strong) IBOutlet NSTextField *buyingPowerLabel;
@property (nonatomic, strong) IBOutlet NSTextField *cashBalanceLabel;
@property (nonatomic, strong) IBOutlet NSTextField *marginUsedLabel;
@property (nonatomic, strong) IBOutlet NSTextField *dayTradesLeftLabel;

#pragma mark - UI Components - Tab View

@property (nonatomic, strong) IBOutlet NSTabView *mainTabView;

#pragma mark - UI Components - Positions Tab

@property (nonatomic, strong) IBOutlet NSTableView *positionsTableView;
@property (nonatomic, strong) IBOutlet NSScrollView *positionsScrollView;

#pragma mark - UI Components - Orders Tab

@property (nonatomic, strong) IBOutlet NSTableView *ordersTableView;
@property (nonatomic, strong) IBOutlet NSScrollView *ordersScrollView;

/// Order filtering controls
@property (nonatomic, strong) IBOutlet NSPopUpButton *orderStatusFilter;  // All/Active/Filled/Cancelled
@property (nonatomic, strong) IBOutlet NSPopUpButton *orderTypeFilter;    // All/Market/Limit/Stop
@property (nonatomic, strong) IBOutlet NSSearchField *orderSymbolSearch;

/// Orders table controls
@property (nonatomic, strong) IBOutlet NSButton *cancelSelectedOrdersButton;
@property (nonatomic, strong) IBOutlet NSButton *refreshOrdersButton;

#pragma mark - UI Components - New Order Tab

@property (nonatomic, strong) IBOutlet NSView *newOrderContainer;
// New Order content will be loaded as separate view controller

#pragma mark - Polling Management

/// Portfolio summary refresh timer (30s)
@property (nonatomic, strong, nullable) NSTimer *portfolioSummaryTimer;

/// Orders refresh timer (15s for active orders)
@property (nonatomic, strong, nullable) NSTimer *ordersRefreshTimer;

/// Set of symbols currently subscribed for real-time prices
@property (nonatomic, strong) NSMutableSet<NSString *> *subscribedSymbols;

#pragma mark - State Management

/// Currently selected tab
@property (nonatomic, assign) PortfolioTabIndex currentTabIndex;

/// Order filtering state
@property (nonatomic, strong) NSString *currentOrderStatusFilter;   // nil = all
@property (nonatomic, strong) NSString *currentOrderTypeFilter;     // nil = all
@property (nonatomic, strong) NSString *currentOrderSymbolSearch;   // "" = all

/// Loading states
@property (nonatomic, assign) BOOL isLoadingAccounts;
@property (nonatomic, assign) BOOL isLoadingPortfolioData;
@property (nonatomic, assign) BOOL isLoadingPositions;
@property (nonatomic, assign) BOOL isLoadingOrders;

#pragma mark - Account Management Actions

/// Account selector changed
- (IBAction)accountSelectionChanged:(NSPopUpButton *)sender;

/// Refresh current account connection and data
- (IBAction)refreshCurrentAccount:(NSButton *)sender;

/// Force refresh all portfolio data
- (IBAction)forceRefreshPortfolio:(id)sender;

#pragma mark - Tab Management

/// Tab view selection changed
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem;

#pragma mark - Positions Table Actions

/// Context menu for positions
- (IBAction)showPositionsContextMenu:(NSTableView *)tableView;

/// Quick action buttons in positions table
- (IBAction)sellPosition:(id)sender;                    // Sell all
- (IBAction)sellHalfPosition:(id)sender;               // Sell 50%
- (IBAction)addToPosition:(id)sender;                  // Buy more
- (IBAction)setBracketOrders:(id)sender;               // Auto SL/TP
- (IBAction)viewPositionOnChart:(id)sender;            // Open in ChartWidget

#pragma mark - Orders Table Actions

/// Apply order filters
- (IBAction)orderStatusFilterChanged:(NSPopUpButton *)sender;
- (IBAction)orderTypeFilterChanged:(NSPopUpButton *)sender;
- (IBAction)orderSymbolSearchChanged:(NSSearchField *)sender;

/// Order management actions
- (IBAction)cancelSelectedOrders:(id)sender;
- (IBAction)cancelOrder:(id)sender;                    // Single order cancel
- (IBAction)modifyOrder:(id)sender;                   // Modify order
- (IBAction)duplicateOrder:(id)sender;                 // Duplicate order
- (IBAction)refreshOrders:(id)sender;

/// Context menu for orders
- (IBAction)showOrdersContextMenu:(NSTableView *)tableView;

#pragma mark - Data Loading

/// Load all available accounts
- (void)loadAvailableAccounts;

/// Switch to specific account
- (void)switchToAccount:(AccountModel *)account;

/// Load portfolio data for current account
- (void)loadPortfolioDataForCurrentAccount;

/// Load positions for current account
- (void)loadPositionsForCurrentAccount;

/// Load orders for current account with current filters
- (void)loadOrdersForCurrentAccount;

#pragma mark - Real-Time Updates

/// Handle real-time quote updates for positions
- (void)handleQuoteUpdate:(NSNotification *)notification;

/// Handle portfolio update notifications
- (void)handlePortfolioUpdate:(NSNotification *)notification;

/// Handle order status change notifications
- (void)handleOrderStatusUpdate:(NSNotification *)notification;

#pragma mark - Subscription Management

/// Subscribe to real-time data for current account
- (void)subscribeToCurrentAccountUpdates;

/// Unsubscribe from real-time data
- (void)unsubscribeFromCurrentAccountUpdates;

/// Update position prices from real-time quotes
- (void)updatePositionPricesFromQuote:(MarketQuoteModel *)quote;

#pragma mark - Polling Management

/// Start polling timers for current account
- (void)startPollingForCurrentAccount;

/// Stop all polling timers
- (void)stopAllPolling;

#pragma mark - Table Management

/// Refresh positions table display
- (void)refreshPositionsTable;

/// Refresh orders table with current filters
- (void)refreshOrdersTable;

/// Apply order filters to current orders list
- (NSArray<AdvancedOrderModel *> *)filteredOrders;

#pragma mark - Helper Methods

/// Find account by ID
- (AccountModel * _Nullable)findAccountById:(NSString *)accountId;

/// Update connection status display
- (void)updateConnectionStatus;

/// Update portfolio summary display
- (void)updatePortfolioSummaryDisplay;

/// Format currency values
- (NSString *)formatCurrency:(double)amount;

/// Format percentage values
- (NSString *)formatPercentage:(double)percentage;

/// Get color for P&L display (green/red)
- (NSColor *)colorForPLValue:(double)plValue;

@end

NS_ASSUME_NONNULL_END
