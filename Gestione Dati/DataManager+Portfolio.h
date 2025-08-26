//
//  DataManager+Portfolio.h (UPDATED - NEW ARCHITECTURE)
//  TradingApp
//
//  🛡️ ACCOUNT DATA: Methods require specific DataSource parameter
//  🚨 TRADING: Methods require specific DataSource parameter
//
//  Portfolio and account management extension for DataManager
//

#import "DataManager.h"
#import "TradingRuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataManager (Portfolio)

#pragma mark - Account Management

/**
 * Request all available accounts across all connected brokers
 * 🛡️ ORCHESTRATION: DataManager queries each broker separately and merges results
 * @param completion Completion block with array of raw account dictionaries
 * @return Request ID for tracking
 */
- (NSString *)requestAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion;

/**
 * Request detailed info for specific account
 * 🛡️ SECURITY: Requires specific DataSource - NO internal broker determination
 * @param accountId Account identifier
 * @param requiredSource Specific broker DataSource (provided by caller)
 * @param completion Completion block with raw account details dictionary
 * @return Request ID for tracking
 */
- (NSString *)requestAccountDetails:(NSString *)accountId
                     fromDataSource:(DataSourceType)requiredSource
                         completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion;

#pragma mark - Portfolio Data Requests

/**
 * Request portfolio summary for account
 * 🛡️ SECURITY: Requires specific DataSource - NO internal broker determination
 * @param accountId Account identifier
 * @param requiredSource Specific broker DataSource (provided by caller)
 * @param completion Completion block with raw portfolio summary dictionary
 * @return Request ID for tracking
 */
- (NSString *)requestPortfolioSummary:(NSString *)accountId
                       fromDataSource:(DataSourceType)requiredSource
                           completion:(void (^)(NSDictionary *summary, NSError *error))completion;

/**
 * Request positions for account
 * 🛡️ SECURITY: Requires specific DataSource - NO internal broker determination
 * @param accountId Account identifier
 * @param requiredSource Specific broker DataSource (provided by caller)
 * @param completion Completion block with array of raw position dictionaries
 * @return Request ID for tracking
 */
- (NSString *)requestPositions:(NSString *)accountId
                fromDataSource:(DataSourceType)requiredSource
                    completion:(void (^)(NSArray *positions, NSError *error))completion;

/**
 * Request orders for account
 * 🛡️ SECURITY: Requires specific DataSource - NO internal broker determination
 * @param accountId Account identifier
 * @param requiredSource Specific broker DataSource (provided by caller)
 * @param statusFilter Optional status filter ("OPEN", "FILLED", etc.) - nil for all
 * @param completion Completion block with array of raw order dictionaries
 * @return Request ID for tracking
 */
- (NSString *)requestOrders:(NSString *)accountId
             fromDataSource:(DataSourceType)requiredSource
                 withStatus:(NSString * _Nullable)statusFilter
                 completion:(void (^)(NSArray *orders, NSError *error))completion;

#pragma mark - 🚨 Order Management (Trading Operations)

/**
 * Place new order
 * 🚨 CRITICAL: Requires exact broker DataSource - NEVER allows fallback
 * @param orderData Order dictionary in standardized format
 * @param accountId Account identifier
 * @param requiredSource Exact broker DataSource (provided by caller)
 * @param completion Completion block with order ID or error
 * @return Request ID for tracking
 */
- (NSString *)placeOrder:(NSDictionary *)orderData
              forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
              completion:(void (^)(NSString *orderId, NSError *error))completion;

/**
 * Cancel existing order
 * 🚨 CRITICAL: Requires exact broker DataSource - NEVER allows fallback
 * @param orderId Order identifier to cancel
 * @param accountId Account identifier
 * @param requiredSource Exact broker DataSource (provided by caller)
 * @param completion Completion block with success status
 * @return Request ID for tracking
 */
- (NSString *)cancelOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
               completion:(void (^)(BOOL success, NSError *error))completion;

/**
 * Modify existing order
 * 🚨 CRITICAL: Requires exact broker DataSource - NEVER allows fallback
 * @param orderId Order identifier to modify
 * @param accountId Account identifier
 * @param requiredSource Exact broker DataSource (provided by caller)
 * @param newOrderData Modified order data
 * @param completion Completion block with success status
 * @return Request ID for tracking
 */
- (NSString *)modifyOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
              newOrderData:(NSDictionary *)newOrderData
               completion:(void (^)(BOOL success, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
