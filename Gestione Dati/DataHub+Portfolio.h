//
//  DataHub+Portfolio.h
//  TradingApp
//
//  Multi-account portfolio management extension for DataHub
//  Supports Schwab + future IBKR integration
//

#import "DataHub.h"
#import "TradingRuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

// Portfolio-specific notification names
extern NSString * const PortfolioAccountsUpdatedNotification;
extern NSString * const PortfolioSummaryUpdatedNotification;
extern NSString * const PortfolioPositionsUpdatedNotification;
extern NSString * const PortfolioOrdersUpdatedNotification;
extern NSString * const PortfolioOrderStatusChangedNotification;
extern NSString * const PortfolioOrderFilledNotification;

@interface DataHub (Portfolio)

#pragma mark - Account Discovery & Management

/// Get all available accounts across brokers
- (void)getAvailableAccountsWithCompletion:(void(^)(NSArray<AccountModel *> *accounts, NSError * _Nullable error))completion;

/// Get detailed info for specific account
- (void)getAccountDetails:(NSString *)accountId
               completion:(void(^)(AccountModel * _Nullable account, NSError * _Nullable error))completion;

/// Refresh account connection status
- (void)refreshAccountConnectionStatus:(NSString *)accountId
                            completion:(void(^)(BOOL isConnected, NSError * _Nullable error))completion;

#pragma mark - Multi-Account Portfolio Data with Smart Caching

/// Get portfolio summary with intelligent caching (30s TTL)
- (void)getPortfolioSummaryForAccount:(NSString *)accountId
                           completion:(void(^)(PortfolioSummaryModel * _Nullable summary, BOOL isFresh))completion;

/// Get positions with price-aware caching (positions cached 5min, prices real-time)
- (void)getPositionsForAccount:(NSString *)accountId
                    completion:(void(^)(NSArray<AdvancedPositionModel *> * _Nullable positions, BOOL isFresh))completion;

/// Get orders with smart filtering and caching (15s TTL for active orders)
- (void)getOrdersForAccount:(NSString *)accountId
                 completion:(void(^)(NSArray<AdvancedOrderModel *> * _Nullable orders, BOOL isFresh))completion;

/// Get filtered orders by status
- (void)getOrdersForAccount:(NSString *)accountId
                 withStatus:(NSString * _Nullable)statusFilter  // nil for all, "OPEN", "FILLED", etc.
                 completion:(void(^)(NSArray<AdvancedOrderModel *> * _Nullable orders, BOOL isFresh))completion;

#pragma mark - Smart Multi-Account Subscription System

/// Subscribe to portfolio updates for specific account (replaces any existing subscription)
- (void)subscribeToPortfolioUpdatesForAccount:(NSString *)accountId;

/// Unsubscribe from portfolio updates for specific account
- (void)unsubscribeFromPortfolioUpdatesForAccount:(NSString *)accountId;

/// Switch portfolio subscription to different account (efficient)
- (void)switchPortfolioSubscriptionToAccount:(NSString *)accountId;

/// Get currently subscribed account ID
- (NSString * _Nullable)currentlySubscribedAccountId;

#pragma mark - Real-Time Price Integration

/// Subscribe to real-time prices for all positions in account
- (void)subscribeToPositionPricesForAccount:(NSString *)accountId;

/// Update position prices from real-time quote data
- (void)updatePositionPricesFromQuote:(MarketQuoteModel *)quote;

#pragma mark - Order Management

/// Place new order
- (void)placeOrder:(NSDictionary *)orderData
        forAccount:(NSString *)accountId
        completion:(void(^)(NSString * _Nullable orderId, NSError * _Nullable error))completion;

/// Cancel existing order
- (void)cancelOrder:(NSString *)orderId
         forAccount:(NSString *)accountId
         completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/// Modify existing order
- (void)modifyOrder:(NSString *)orderId
         forAccount:(NSString *)accountId
            newData:(NSDictionary *)modifiedData
         completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

#pragma mark - Polling & Refresh Management

/// Start portfolio polling timers for account (different frequencies)
- (void)startPortfolioPollingForAccount:(NSString *)accountId;

/// Stop portfolio polling for account
- (void)stopPortfolioPollingForAccount:(NSString *)accountId;

/// Force refresh all portfolio data for account
- (void)forceRefreshPortfolioForAccount:(NSString *)accountId
                             completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

#pragma mark - Cache Management

/// Clear portfolio cache for account
- (void)clearPortfolioCacheForAccount:(NSString *)accountId;

/// Get cache freshness info
- (NSDictionary *)getPortfolioCacheInfoForAccount:(NSString *)accountId;

#pragma mark - Future: Cross-Account Aggregation

/// Get aggregated portfolio across all accounts (future feature)
- (void)getAggregatedPortfolioSummaryWithCompletion:(void(^)(PortfolioSummaryModel *aggregatedSummary))completion;

/// Get all positions across all accounts
- (void)getAllPositionsAcrossAccountsWithCompletion:(void(^)(NSDictionary<NSString *, NSArray<AdvancedPositionModel *> *> *positionsByAccount))completion;

@end

NS_ASSUME_NONNULL_END
