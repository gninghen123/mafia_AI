//
//  DownloadManager.h
//  TradingApp
//
//  UNIFICATO: HTTP request manager for external data sources
//  Gestisce tutte le chiamate API in modo unificato con failover automatico
//  VERSIONE PULITA - Solo metodi unificati, niente legacy
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"

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
 * UNIFIED: Historical bars with bar count instead of date range
 * All DataSources MUST implement this method
 *
 * @param symbol The symbol to fetch data for
 * @param timeframe Standard timeframe enum (BarTimeframe)
 * @param barCount Number of bars to return (e.g., last 200 bars)
 * @param needExtendedHours YES for pre/post market data
 * @param completion Returns array of standardized bar dictionaries
 */
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                    needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

@optional
#pragma mark - MARKET LISTS (Optional)

/**
 * UNIFIED: Market lists (top gainers, losers, ETFs, etc.)
 * Implement this for DataSources that support market lists
 *
 * @param listType The type of market list (DataRequestType enum)
 * @param parameters Dictionary with parameters like:
 *   - @"limit": NSNumber with max results to return
 *   - @"timeframe": MarketTimeframe enum for filtering
 *   - @"minVolume": NSNumber minimum volume filter
 * @param completion Returns array of symbol dictionaries with basic market data
 */
- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(nullable NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion;

#pragma mark - EXTENDED MARKET DATA (Optional)

/**
 * Order book / Level 2 data
 * Only implemented by DataSources that support Level 2
 */
- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(id orderBook, NSError *error))completion;

/**
 * Options chain data
 * Only implemented by DataSources that support options
 */
- (void)fetchOptionChainForSymbol:(NSString *)symbol
                   expirationDate:(nullable NSDate *)expirationDate
                       completion:(void (^)(id optionChain, NSError *error))completion;

/**
 * Company fundamental data
 * Only implemented by DataSources that support fundamentals
 */
- (void)fetchFundamentalsForSymbol:(NSString *)symbol
                        completion:(void (^)(id fundamentals, NSError *error))completion;

#pragma mark - PORTFOLIO DATA (Optional - only for trading APIs)

/**
 * Get list of available accounts for this data source
 * Only implemented by trading DataSources (Schwab, IBKR, etc.)
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

#pragma mark - UNIFIED REQUEST EXECUTION

/**
 * PRIMARY METHOD: Execute any request with automatic source selection
 * The DownloadManager will:
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
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;

/**
 * ADVANCED METHOD: Execute request with preferred source
 * Use this when you want to force a specific DataSource
 * Still falls back to other sources if preferred source fails
 *
 * @param requestType Type of request
 * @param parameters Request parameters
 * @param preferredSource Try this DataSource first (-1 for auto-select)
 * @param completion Called with result, actual source used, and any errors
 * @return Request ID for cancellation
 */
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
             preferredSource:(DataSourceType)preferredSource
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;

#pragma mark - UNIFIED CONVENIENCE METHODS

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

#pragma mark - Request Management

- (void)cancelRequest:(NSString *)requestID;
- (void)cancelAllRequests;

@end

NS_ASSUME_NONNULL_END
