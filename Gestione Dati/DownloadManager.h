//
//  DownloadManager.h (CLEANED & ORGANIZED)
//  TradingApp
//
//  HTTP request manager for external data sources
//  🛡️ SECURITY: Distinguished Market Data vs Account Data routing
//  - Market Data: Automatic routing with fallback (Schwab → Yahoo)
//  - Account Data: Specific DataSource REQUIRED, NO fallback for security
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"
#import "RuntimeModels.h"
#import "DataSource.h"  // ✅ Import separated protocol

@class CompanyInfoModel;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - DOWNLOAD MANAGER INTERFACE

@interface DownloadManager : NSObject

+ (instancetype)sharedManager;

#pragma mark - Data Source Management

/**
 * Register a data source with priority
 * @param dataSource DataSource implementation to register
 * @param type DataSource type identifier
 * @param priority Priority (lower number = higher priority)
 */
- (void)registerDataSource:(id<DataSource>)dataSource
                  withType:(DataSourceType)type
                  priority:(NSInteger)priority;

/**
 * Unregister a data source
 * @param type DataSource type to unregister
 */
- (void)unregisterDataSource:(DataSourceType)type;

#pragma mark - Connection Management

/**
 * Connect to specific data source
 * @param type DataSource type to connect
 * @param completion Called with connection result
 */
- (void)connectDataSource:(DataSourceType)type
               completion:(nullable void (^)(BOOL success, NSError * _Nullable error))completion;

/**
 * Disconnect from specific data source
 * @param type DataSource type to disconnect
 */
- (void)disconnectDataSource:(DataSourceType)type;

/**
 * Reconnect all registered data sources
 */
- (void)reconnectAllDataSources;

#pragma mark - Status and Monitoring

/**
 * Check if data source is connected
 * @param type DataSource type to check
 * @return YES if connected, NO otherwise
 */
- (BOOL)isDataSourceConnected:(DataSourceType)type;

/**
 * Get capabilities for data source
 * @param type DataSource type to check
 * @return Capabilities bitmask
 */
- (DataSourceCapabilities)capabilitiesForDataSource:(DataSourceType)type;

/**
 * Get statistics for data source
 * @param type DataSource type to check
 * @return Statistics dictionary
 */
- (NSDictionary *)statisticsForDataSource:(DataSourceType)type;

/**
 * Get currently active data source
 */
@property (nonatomic, readonly) DataSourceType currentDataSource;

#pragma mark - ✅ DATA SOURCE ACCESS (For DataManager Integration)

/**
 * Get data source instance for given type
 * @param type DataSourceType to get
 * @return Data source instance or nil
 */
- (nullable id<DataSource>)dataSourceForType:(DataSourceType)type;

/**
 * Get priority for data source
 * @param dataSource DataSourceType to check
 * @return Priority value (lower = higher priority)
 */
- (NSInteger)priorityForDataSource:(DataSourceType)dataSource;

#pragma mark - 📈 MARKET DATA REQUESTS (Automatic routing with fallback)

/**
 * PRIMARY MARKET DATA METHOD: Execute market data requests with automatic source selection
 * 📈 MARKET DATA - Automatic routing OK, fallback enabled
 *
 * For market data (quotes, historical, market lists), the DownloadManager will:
 * 1. Find the best available DataSource based on capabilities and priority
 * 2. Execute the request
 * 3. Handle failures with automatic fallback to next DataSource
 * 4. Return standardized results regardless of source
 *
 * @param requestType Type of request (quotes, historical, market lists, etc.)
 * @param parameters Request parameters (symbol, timeframe, etc.)
 * @param completion Called with result, actual source used, and any errors
 * @return Request ID for cancellation
 */
- (NSString *)executeMarketDataRequest:(DataRequestType)requestType
                            parameters:(NSDictionary *)parameters
                            completion:(void (^)(id _Nullable result, DataSourceType usedSource, NSError * _Nullable error))completion;

/**
 * MARKET DATA with preferred source (still has fallback)
 * Use this when you prefer a specific DataSource but want fallback
 *
 * @param requestType Type of request
 * @param parameters Request parameters
 * @param preferredSource Try this DataSource first (-1 for auto-select)
 * @param completion Called with result, actual source used, and any errors
 * @return Request ID for cancellation
 */
- (NSString *)executeMarketDataRequest:(DataRequestType)requestType
                            parameters:(NSDictionary *)parameters
                       preferredSource:(DataSourceType)preferredSource
                            completion:(void (^)(id _Nullable result, DataSourceType usedSource, NSError * _Nullable error))completion;

#pragma mark - 🛡️ ACCOUNT DATA REQUESTS (Specific DataSource REQUIRED)

/**
 * 🛡️ ACCOUNT DATA REQUEST: Requires specific DataSource, NO fallback for security
 *
 * For account data (positions, orders, account info, trading), you MUST specify the DataSource.
 * NO automatic routing, NO fallback to prevent mixing data between brokers!
 *
 * @param requestType Account request type (positions, orders, account info)
 * @param parameters Request parameters (accountId required)
 * @param requiredSource REQUIRED: Specific broker DataSource (Schwab, IBKR, etc.)
 * @param completion Called with result, source used, and any errors
 * @return Request ID for cancellation
 */
- (NSString *)executeAccountDataRequest:(DataRequestType)requestType
                             parameters:(NSDictionary *)parameters
                         requiredSource:(DataSourceType)requiredSource
                             completion:(void (^)(id _Nullable result, DataSourceType usedSource, NSError * _Nullable error))completion;

#pragma mark - 🚨 TRADING OPERATIONS (Specific DataSource REQUIRED)

/**
 * 🚨 TRADING OPERATION: Requires specific DataSource, NEVER allows fallback
 *
 * Trading operations are the most critical - they MUST always specify exact DataSource.
 * Attempting to trade on wrong broker could be catastrophic!
 *
 * @param requestType Trading request type (place order, cancel order)
 * @param parameters Request parameters (accountId, orderData required)
 * @param requiredSource REQUIRED: Exact broker DataSource for the account
 * @param completion Called with result, source used, and any errors
 * @return Request ID for cancellation
 */
- (NSString *)executeTradingRequest:(DataRequestType)requestType
                         parameters:(NSDictionary *)parameters
                     requiredSource:(DataSourceType)requiredSource
                         completion:(void (^)(id _Nullable result, DataSourceType usedSource, NSError * _Nullable error))completion;

#pragma mark - 🔍 SYMBOL SEARCH AND COMPANY INFO

/**
 * Search for symbols using specific data source
 * @param query Search query text
 * @param dataSource Specific data source to use
 * @param limit Maximum number of results
 * @param completion Completion with results array
 */
- (void)searchSymbolsWithQuery:(NSString *)query
                    dataSource:(DataSourceType)dataSource
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<NSDictionary *> * _Nullable results, NSError * _Nullable error))completion;

/**
 * Get company information for symbol using specific data source
 * @param symbol Stock symbol
 * @param dataSource Data source to use
 * @param completion Completion with company info
 */
- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     dataSource:(DataSourceType)dataSource
                     completion:(void(^)(CompanyInfoModel * _Nullable companyInfo, NSError * _Nullable error))completion;

#pragma mark - Request Cancellation

/**
 * Cancel an active request
 * @param requestID Request ID to cancel
 */
- (void)cancelRequest:(NSString *)requestID;

/**
 * Cancel all active requests
 */
- (void)cancelAllRequests;

@end

NS_ASSUME_NONNULL_END
