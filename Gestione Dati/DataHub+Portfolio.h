//
//  DataHub+Portfolio.h - SECURE ARCHITECTURE
//  TradingApp
//
//  🛡️ SECURITY: ALL portfolio methods require specific DataSource
//  ❌ ELIMINATED: Generic aggregation calls (security violation)
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

#pragma mark - 🛡️ SECURE Account Discovery (Broker-Specific Only)

/**
 * Get accounts from SPECIFIC broker with caching
 * 🛡️ SECURITY: Requires specific DataSource - NO aggregation
 * @param brokerType Specific broker (Schwab, IBKR, etc.)
 * @param completion Completion with AccountModel objects from that broker
 */
- (void)getAccountsFromBroker:(DataSourceType)brokerType
                   completion:(void(^)(NSArray<AccountModel *> *accounts, BOOL isFresh, NSError * _Nullable error))completion;

/**
 * Get account details from SPECIFIC broker with caching
 * 🛡️ SECURITY: Requires specific DataSource
 */
- (void)getAccountDetails:(NSString *)accountId
               fromBroker:(DataSourceType)brokerType
               completion:(void(^)(AccountModel * _Nullable account, BOOL isFresh, NSError * _Nullable error))completion;

/**
 * Check connection status for specific broker
 */
- (void)checkBrokerConnectionStatus:(DataSourceType)brokerType
                         completion:(void(^)(BOOL isConnected, NSError * _Nullable error))completion;

#pragma mark - 🛡️ SECURE Portfolio Data (Broker-Specific Only)

/**
 * Get portfolio summary with intelligent caching (30s TTL)
 * 🛡️ SECURITY: Account and broker must be specified
 */
- (void)getPortfolioSummaryForAccount:(NSString *)accountId
                           fromBroker:(DataSourceType)brokerType
                           completion:(void(^)(PortfolioSummaryModel * _Nullable summary, BOOL isFresh))completion;

/**
 * Get positions with price-aware caching
 * 🛡️ SECURITY: Account and broker must be specified
 */
- (void)getPositionsForAccount:(NSString *)accountId
                    fromBroker:(DataSourceType)brokerType
                    completion:(void(^)(NSArray<AdvancedPositionModel *> * _Nullable positions, BOOL isFresh))completion;

/**
 * Get orders with smart filtering and caching
 * 🛡️ SECURITY: Account and broker must be specified
 */
- (void)getOrdersForAccount:(NSString *)accountId
                 fromBroker:(DataSourceType)brokerType
                 withStatus:(NSString * _Nullable)statusFilter
                 completion:(void(^)(NSArray<AdvancedOrderModel *> * _Nullable orders, BOOL isFresh))completion;

#pragma mark - 🚨 SECURE Trading Operations (Broker-Specific Only)

/**
 * Place order on SPECIFIC broker
 * 🚨 CRITICAL: Account and broker must be specified
 */
- (void)placeOrder:(NSDictionary *)orderData
        forAccount:(NSString *)accountId
        usingBroker:(DataSourceType)brokerType
        completion:(void(^)(NSString * _Nullable orderId, NSError * _Nullable error))completion;

/**
 * Cancel order on SPECIFIC broker
 * 🚨 CRITICAL: Account and broker must be specified
 */
- (void)cancelOrder:(NSString *)orderId
         forAccount:(NSString *)accountId
        usingBroker:(DataSourceType)brokerType
         completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/**
 * Modify order on SPECIFIC broker
 * 🚨 CRITICAL: Account and broker must be specified
 */
- (void)modifyOrder:(NSString *)orderId
         forAccount:(NSString *)accountId
        usingBroker:(DataSourceType)brokerType
            newData:(NSDictionary *)modifiedData
         completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

#pragma mark - 🔧 SECURE Subscription System (Broker-Specific)

/**
 * Subscribe to portfolio updates for specific account on specific broker
 */
- (void)subscribeToPortfolioUpdatesForAccount:(NSString *)accountId
                                   fromBroker:(DataSourceType)brokerType;

/**
 * Unsubscribe from portfolio updates for specific account on specific broker
 */
- (void)unsubscribeFromPortfolioUpdatesForAccount:(NSString *)accountId
                                       fromBroker:(DataSourceType)brokerType;

#pragma mark - 🛠️ Utility Methods

/**
 * Get list of connected brokers
 * Returns array of DataSourceType as NSNumber
 */
- (NSArray<NSNumber *> *)getConnectedBrokers;

/**
 * Clear portfolio cache for specific account on specific broker
 */
- (void)clearPortfolioCacheForAccount:(NSString *)accountId
                           fromBroker:(DataSourceType)brokerType;

@end

NS_ASSUME_NONNULL_END
