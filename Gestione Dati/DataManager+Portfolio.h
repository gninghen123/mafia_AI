//
//  DataManager+Portfolio.h
//  TradingApp
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
 * @param completion Completion block with array of raw account dictionaries
 * @return Request ID for tracking
 */
- (NSString *)requestAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion;

/**
 * Request detailed info for specific account
 * @param accountId Account identifier
 * @param completion Completion block with raw account details dictionary
 * @return Request ID for tracking
 */
- (NSString *)requestAccountDetails:(NSString *)accountId
                         completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion;

#pragma mark - Portfolio Data Requests

/**
 * Request portfolio summary for account
 * @param accountId Account identifier
 * @param completion Completion block with raw portfolio summary dictionary
 * @return Request ID for tracking
 */
- (NSString *)requestPortfolioSummary:(NSString *)accountId
                           completion:(void (^)(NSDictionary *summary, NSError *error))completion;

/**
 * Request positions for account
 * @param accountId Account identifier
 * @param completion Completion block with array of raw position dictionaries
 * @return Request ID for tracking
 */
- (NSString *)requestPositions:(NSString *)accountId
                    completion:(void (^)(NSArray *positions, NSError *error))completion;

/**
 * Request orders for account
 * @param accountId Account identifier
 * @param statusFilter Optional status filter ("OPEN", "FILLED", etc.) - nil for all
 * @param completion Completion block with array of raw order dictionaries
 * @return Request ID for tracking
 */
- (NSString *)requestOrders:(NSString *)accountId
                 withStatus:(NSString * _Nullable)statusFilter
                 completion:(void (^)(NSArray *orders, NSError *error))completion;

#pragma mark - Order Management

/**
 * Place new order
 * @param orderData Order dictionary in standardized format
 * @param accountId Account identifier
 * @param completion Completion block with order ID or error
 * @return Request ID for tracking
 */
- (NSString *)placeOrder:(NSDictionary *)orderData
              forAccount:(NSString *)accountId
              completion:(void (^)(NSString *orderId, NSError *error))completion;

/**
 * Cancel existing order
 * @param orderId Order identifier to cancel
 * @param accountId Account identifier
 * @param completion Completion block with success status
 * @return Request ID for tracking
 */
- (NSString *)cancelOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
               completion:(void (^)(BOOL success, NSError *error))completion;

/**
 * Modify existing order
 * @param orderId Order identifier to modify
 * @param accountId Account identifier
 * @param newOrderData Modified order data
 * @param completion Completion block with success status
 * @return Request ID for tracking
 */
- (NSString *)modifyOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
              newOrderData:(NSDictionary *)newOrderData
               completion:(void (^)(BOOL success, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
