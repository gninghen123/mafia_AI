//
//  DataManager+Portfolio.h - SECURE ARCHITECTURE
//  TradingApp
//
//  🛡️ ACCOUNT DATA: ALL methods require specific DataSource parameter
//  🚨 TRADING: ALL methods require specific DataSource parameter
//  ❌ ELIMINATED: Generic aggregation calls (security violation)
//

#import "DataManager.h"
#import "TradingRuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataManager (Portfolio)

#pragma mark - 🛡️ SECURE Account Management (Broker-Specific Only)

/**
 * Get accounts from all connected brokers (INTERNAL ORCHESTRATION)
 * 🛡️ SECURITY: This method orchestrates calls to specific brokers internally
 * @param completion Completion block with all accounts from connected brokers
 * @return Request ID for tracking
 */
- (NSString *)requestAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion;

/**
 * Get accounts from SPECIFIC broker only
 * 🛡️ SECURITY: Requires specific DataSource - NO aggregation
 * @param requiredSource Specific broker DataSource (Schwab, IBKR, etc.)
 * @param completion Completion block with accounts from that broker only
 * @return Request ID for tracking
 */
- (NSString *)requestAccountsFromDataSource:(DataSourceType)requiredSource
                                 completion:(void (^)(NSArray *accounts, NSError *error))completion;

/**
 * Get account details from SPECIFIC broker
 * 🛡️ SECURITY: Requires specific DataSource
 * @param accountId Account identifier
 * @param requiredSource Specific broker DataSource (provided by caller)
 * @param completion Completion block with account details
 * @return Request ID for tracking
 */
- (NSString *)requestAccountDetails:(NSString *)accountId
                     fromDataSource:(DataSourceType)requiredSource
                         completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion;

#pragma mark - 🛡️ SECURE Portfolio Data (Broker-Specific Only)

/**
 * Get portfolio summary from SPECIFIC broker
 * 🛡️ SECURITY: Requires specific DataSource
 */
- (NSString *)requestPortfolioSummary:(NSString *)accountId
                       fromDataSource:(DataSourceType)requiredSource
                           completion:(void (^)(NSDictionary *summary, NSError *error))completion;

/**
 * Get positions from SPECIFIC broker
 * 🛡️ SECURITY: Requires specific DataSource
 */
- (NSString *)requestPositions:(NSString *)accountId
                fromDataSource:(DataSourceType)requiredSource
                    completion:(void (^)(NSArray *positions, NSError *error))completion;

/**
 * Get orders from SPECIFIC broker
 * 🛡️ SECURITY: Requires specific DataSource
 */
- (NSString *)requestOrders:(NSString *)accountId
             fromDataSource:(DataSourceType)requiredSource
                 withStatus:(NSString * _Nullable)statusFilter
                 completion:(void (^)(NSArray *orders, NSError *error))completion;

#pragma mark - 🚨 SECURE Trading Operations (Broker-Specific Only)

/**
 * Place order on SPECIFIC broker
 * 🚨 CRITICAL: Requires exact broker DataSource
 */
- (NSString *)placeOrder:(NSDictionary *)orderData
              forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
              completion:(void (^)(NSString *orderId, NSError *error))completion;

/**
 * Cancel order on SPECIFIC broker
 * 🚨 CRITICAL: Requires exact broker DataSource
 */
- (NSString *)cancelOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
               completion:(void (^)(BOOL success, NSError *error))completion;

/**
 * Modify order on SPECIFIC broker
 * 🚨 CRITICAL: Requires exact broker DataSource
 */
- (NSString *)modifyOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
              newOrderData:(NSDictionary *)newOrderData
               completion:(void (^)(BOOL success, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
