//
//  DownloadManager.h (UPDATED - SECURITY ENHANCED)
//  TradingApp
//
//  UNIFICATO: HTTP request manager for external data sources
//  🛡️ SECURITY UPDATE: Distinguished Market Data vs Account Data routing
//  - Market Data: Automatic routing with fallback (Schwab → Yahoo)
//  - Account Data: Specific DataSource REQUIRED, NO fallback for security
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"
#import "runtimeModels.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Data Source Protocol

// Data source protocol - HTTP requests only
@protocol DataSource <NSObject>

@required
@property (nonatomic, readonly) DataSourceType sourceType;
@property (nonatomic, readonly) DataSourceCapabilities capabilities;
@property (nonatomic, readonly) NSString *sourceName;
@property (nonatomic, readonly) BOOL isConnected;

// Connection management (HTTP authentication only)
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)disconnect;

#pragma mark - UNIFIED MARKET DATA METHODS (Required)

/**
 * UNIFIED: Single quote for any symbol
 * All DataSources MUST implement this method
 */
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;

/**
 * UNIFIED: Batch quotes for multiple symbols
 * All DataSources MUST implement this method
 */
- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

/**
 * UNIFIED: Historical bars with standardized parameters
 * All DataSources MUST implement this method
 *
 * @param symbol The symbol to fetch data for
 * @param timeframe Standard timeframe enum (BarTimeframe)
 * @param startDate Start date for historical data
 * @param endDate End date for historical data
 * @param needExtendedHours YES for pre/post market data
 * @param completion Returns array of standardized bar dictionaries
 */
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

/**
 * UNIFIED: Historical bars by bar count instead of date range
 * All DataSources MUST implement this method
 */
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

#pragma mark - MARKET LISTS AND ANALYTICS (Optional - implement if supported)

/**
 * UNIFIED: Market lists and screeners
 * Only implement if DataSource supports market lists
 *
 * @param listType Type of list (TopGainers, TopLosers, ETFList, etc.)
 * @param parameters Additional parameters (limit, timeframe, etc.)
 * @param completion Returns array of result dictionaries
 */
- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(nullable NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion;

/**
 * UNIFIED: Level 2 order book data
 * Only implement if DataSource supports order book
 */
- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(NSDictionary *orderBook, NSError *error))completion;

/**
 * UNIFIED: Company fundamentals
 * Only implement if DataSource supports fundamentals
 */
- (void)fetchFundamentalsForSymbol:(NSString *)symbol
                        completion:(void (^)(NSDictionary *fundamentals, NSError *error))completion;

#pragma mark - ACCOUNT DATA METHODS (Optional - only for trading DataSources)
// 🛡️ SECURITY: These methods require specific DataSource, NO automatic routing

/**
 * Get all available accounts for this broker
 * Only implemented by trading DataSources
 */
- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion;

/**
 * Get detailed information for specific account
 * Only implemented by trading DataSources
 */
- (void)fetchAccountDetails:(NSString *)accountId
                 completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion;

/**
 * Get positions for specific account
 * Only implemented by trading DataSources
 */
- (void)fetchPositionsForAccount:(NSString *)accountId
                      completion:(void (^)(NSArray *positions, NSError *error))completion;

/**
 * Get orders for specific account
 * Only implemented by trading DataSources
 */
- (void)fetchOrdersForAccount:(NSString *)accountId
                   completion:(void (^)(NSArray *orders, NSError *error))completion;

#pragma mark - TRADING OPERATIONS (Optional - only for trading APIs)
// 🛡️ SECURITY: Trading operations require specific DataSource, NO fallback

/**
 * Place a new order
 * Only implemented by trading DataSources
 */
- (void)placeOrderForAccount:(NSString *)accountId
                   orderData:(NSDictionary *)orderData
                  completion:(void (^)(NSString *orderId, NSError *error))completion;

/**
 * Cancel an existing order
 * Only implemented by trading DataSources
 */
- (void)cancelOrderForAccount:(NSString *)accountId
                      orderId:(NSString *)orderId
                   completion:(void (^)(BOOL success, NSError *error))completion;

@end

#pragma mark - DOWNLOAD MANAGER INTERFACE

@interface DownloadManager : NSObject

+ (instancetype)sharedManager;

#pragma mark - Data Source Management

- (void)registerDataSource:(id<DataSource>)dataSource
                  withType:(DataSourceType)type
                  priority:(NSInteger)priority;
- (void)unregisterDataSource:(DataSourceType)type;

#pragma mark - Connection Management

- (void)connectDataSource:(DataSourceType)type
               completion:(nullable void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)disconnectDataSource:(DataSourceType)type;
- (void)reconnectAllDataSources;

#pragma mark - Status and Monitoring

- (BOOL)isDataSourceConnected:(DataSourceType)type;
- (DataSourceCapabilities)capabilitiesForDataSource:(DataSourceType)type;
- (NSDictionary *)statisticsForDataSource:(DataSourceType)type;

@property (nonatomic, readonly) DataSourceType currentDataSource;

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
                            completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;

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
                            completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;

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
                             completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;

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
                         completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;

#pragma mark - UNIFIED CONVENIENCE METHODS for Market Data

/**
 * CONVENIENCE: Single quote with automatic source selection and failover
 */
- (NSString *)fetchQuoteForSymbol:(NSString *)symbol
                       completion:(void (^)(id quote, DataSourceType usedSource, NSError *error))completion;

/**
 * CONVENIENCE: Batch quotes with automatic source selection and failover
 */
- (NSString *)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                         completion:(void (^)(NSDictionary *quotes, DataSourceType usedSource, NSError *error))completion;

/**
 * CONVENIENCE: Historical bars (date range) with automatic source selection and failover
 */
- (NSString *)fetchHistoricalDataForSymbol:(NSString *)symbol
                                 timeframe:(BarTimeframe)timeframe
                                 startDate:(NSDate *)startDate
                                   endDate:(NSDate *)endDate
                          needExtendedHours:(BOOL)needExtendedHours
                                completion:(void (^)(NSArray *bars, DataSourceType usedSource, NSError *error))completion;

/**
 * CONVENIENCE: Historical bars (bar count) with automatic source selection and failover
 */
- (NSString *)fetchHistoricalDataForSymbol:(NSString *)symbol
                                 timeframe:(BarTimeframe)timeframe
                                  barCount:(NSInteger)barCount
                         needExtendedHours:(BOOL)needExtendedHours
                                completion:(void (^)(NSArray *bars, DataSourceType usedSource, NSError *error))completion;

/**
 * CONVENIENCE: Market lists with automatic source selection and failover
 */
- (NSString *)fetchMarketListForType:(DataRequestType)listType
                          parameters:(nullable NSDictionary *)parameters
                          completion:(void (^)(NSArray *results, DataSourceType usedSource, NSError *error))completion;

/**
 * Search for symbols across data sources
 * @param query Search query text
 * @param dataSource Specific data source to use
 * @param limit Maximum number of results
 * @param completion Completion with results array
 */
- (void)searchSymbolsWithQuery:(NSString *)query
                    dataSource:(DataSourceType)dataSource
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<NSDictionary *> *results, NSError *error))completion;

/**
 * Get company information for symbol
 * @param symbol Stock symbol
 * @param dataSource Data source to use
 * @param completion Completion with company info
 */
- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     dataSource:(DataSourceType)dataSource
                     completion:(void(^)(CompanyInfoModel *companyInfo, NSError *error))completion;


#pragma mark - CONVENIENCE METHODS for Account Data (🛡️ Require DataSource)

/**
 * 🛡️ CONVENIENCE: Account positions - requires specific DataSource
 */
- (NSString *)fetchPositionsForAccount:(NSString *)accountId
                        fromDataSource:(DataSourceType)requiredSource
                            completion:(void (^)(NSArray *positions, DataSourceType usedSource, NSError *error))completion;

/**
 * 🛡️ CONVENIENCE: Account orders - requires specific DataSource
 */
- (NSString *)fetchOrdersForAccount:(NSString *)accountId
                     fromDataSource:(DataSourceType)requiredSource
                         completion:(void (^)(NSArray *orders, DataSourceType usedSource, NSError *error))completion;

/**
 * 🛡️ CONVENIENCE: Account details - requires specific DataSource
 */
- (NSString *)fetchAccountDetails:(NSString *)accountId
                   fromDataSource:(DataSourceType)requiredSource
                       completion:(void (^)(NSDictionary *details, DataSourceType usedSource, NSError *error))completion;

#pragma mark - CONVENIENCE METHODS for Trading (🚨 Require DataSource)

/**
 * 🚨 CONVENIENCE: Place order - requires exact DataSource
 */
- (NSString *)placeOrder:(NSDictionary *)orderData
              forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
               completion:(void (^)(NSString *orderId, DataSourceType usedSource, NSError *error))completion;

/**
 * 🚨 CONVENIENCE: Cancel order - requires exact DataSource
 */
- (NSString *)cancelOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
               completion:(void (^)(BOOL success, DataSourceType usedSource, NSError *error))completion;

#pragma mark - Request Cancellation

/**
 * Cancel an active request
 */
- (void)cancelRequest:(NSString *)requestID;

/**
 * Cancel all active requests
 */
- (void)cancelAllRequests;

@end

NS_ASSUME_NONNULL_END
