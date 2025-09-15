//
//  DataSource.h
//  TradingApp
//
//  Protocol definition for external data sources
//  Defines the unified interface that all data sources must implement
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Data Source Protocol

/**
 * Data source protocol - HTTP requests only
 * All external data sources (Yahoo, Schwab, IBKR, Webull, etc.) must conform to this protocol
 */
@protocol DataSource <NSObject>

@required

#pragma mark - Basic Properties

@property (nonatomic, readonly) DataSourceType sourceType;
@property (nonatomic, readonly) DataSourceCapabilities capabilities;
@property (nonatomic, readonly) NSString *sourceName;
@property (nonatomic, readonly) BOOL isConnected;

#pragma mark - Connection Management

/**
 * Connect to the data source (HTTP authentication only)
 * @param completion Called with success/failure result
 */
- (void)connectWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/**
 * Disconnect from the data source
 */
- (void)disconnect;

#pragma mark - UNIFIED MARKET DATA METHODS (Required)

/**
 * UNIFIED: Single quote for any symbol
 * All DataSources MUST implement this method
 * @param symbol Stock symbol to get quote for
 * @param completion Called with quote data or error
 */
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id _Nullable quote, NSError * _Nullable error))completion;

/**
 * UNIFIED: Batch quotes for multiple symbols
 * All DataSources MUST implement this method
 * @param symbols Array of stock symbols
 * @param completion Called with dictionary of quotes or error
 */
- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary * _Nullable quotes, NSError * _Nullable error))completion;

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
                          completion:(void (^)(NSArray * _Nullable bars, NSError * _Nullable error))completion;

/**
 * UNIFIED: Historical bars by bar count instead of date range
 * All DataSources MUST implement this method
 * @param symbol The symbol to fetch data for
 * @param timeframe Standard timeframe enum (BarTimeframe)
 * @param barCount Number of bars to fetch
 * @param needExtendedHours YES for pre/post market data
 * @param completion Returns array of standardized bar dictionaries
 */
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray * _Nullable bars, NSError * _Nullable error))completion;

@optional

#pragma mark - MARKET LISTS AND ANALYTICS (Optional - implement if supported)

/**
 * UNIFIED: Market lists and screeners
 * Only implement if DataSource supports market lists
 * @param listType Type of list (TopGainers, TopLosers, ETFList, etc.)
 * @param parameters Additional parameters (limit, timeframe, etc.)
 * @param completion Returns array of result dictionaries
 */
- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(nullable NSDictionary *)parameters
                    completion:(void (^)(NSArray * _Nullable results, NSError * _Nullable error))completion;

/**
 * UNIFIED: Level 2 order book data
 * Only implement if DataSource supports order book
 * @param symbol Symbol to get order book for
 * @param depth Number of levels to fetch
 * @param completion Returns order book data or error
 */
- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(NSDictionary * _Nullable orderBook, NSError * _Nullable error))completion;

/**
 * UNIFIED: Company fundamentals
 * Only implement if DataSource supports fundamentals
 * @param symbol Symbol to get fundamentals for
 * @param completion Returns fundamentals data or error
 */
- (void)fetchFundamentalsForSymbol:(NSString *)symbol
                        completion:(void (^)(NSDictionary * _Nullable fundamentals, NSError * _Nullable error))completion;

#pragma mark - SEARCH AND COMPANY INFO (Optional)

/**
 * Search for symbols matching query
 * Only implement if DataSource supports symbol search
 * @param query Search text (company name or symbol)
 * @param limit Maximum number of results
 * @param completion Completion with raw API results (will be standardized by DataManager)
 */
- (void)searchSymbolsWithQuery:(NSString *)query
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<NSDictionary *> * _Nullable results, NSError * _Nullable error))completion;

/**
 * Get detailed company information for symbol
 * Only implement if DataSource supports company info
 * @param symbol Stock symbol
 * @param completion Completion with raw company data
 */
- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     completion:(void(^)(NSDictionary * _Nullable companyData, NSError * _Nullable error))completion;

#pragma mark - ACCOUNT DATA METHODS (Optional - only for trading DataSources)
// 🛡️ SECURITY: These methods require specific DataSource, NO automatic routing

/**
 * Get all available accounts for this broker
 * Only implemented by trading DataSources (Schwab, IBKR, etc.)
 * @param completion Called with accounts array or error
 */
- (void)fetchAccountsWithCompletion:(void (^)(NSArray * _Nullable accounts, NSError * _Nullable error))completion;

/**
 * Get detailed information for specific account
 * Only implemented by trading DataSources
 * @param accountId Account identifier
 * @param completion Called with account details or error
 */
- (void)fetchAccountDetails:(NSString *)accountId
                 completion:(void (^)(NSDictionary * _Nullable accountDetails, NSError * _Nullable error))completion;

/**
 * Get positions for specific account
 * Only implemented by trading DataSources
 * @param accountId Account identifier
 * @param completion Called with positions array or error
 */
- (void)fetchPositionsForAccount:(NSString *)accountId
                      completion:(void (^)(NSArray * _Nullable positions, NSError * _Nullable error))completion;

/**
 * Get orders for specific account
 * Only implemented by trading DataSources
 * @param accountId Account identifier
 * @param completion Called with orders array or error
 */
- (void)fetchOrdersForAccount:(NSString *)accountId
                   completion:(void (^)(NSArray * _Nullable orders, NSError * _Nullable error))completion;

#pragma mark - TRADING OPERATIONS (Optional - only for trading APIs)
// 🛡️ SECURITY: Trading operations require specific DataSource, NO fallback

/**
 * Place a new order
 * Only implemented by trading DataSources
 * @param accountId Account to place order in
 * @param orderData Order parameters (symbol, quantity, type, etc.)
 * @param completion Called with order ID or error
 */
- (void)placeOrderForAccount:(NSString *)accountId
                   orderData:(NSDictionary *)orderData
                  completion:(void (^)(NSString * _Nullable orderId, NSError * _Nullable error))completion;

/**
 * Cancel an existing order
 * Only implemented by trading DataSources
 * @param accountId Account containing the order
 * @param orderId Order identifier to cancel
 * @param completion Called with success result or error
 */
- (void)cancelOrderForAccount:(NSString *)accountId
                      orderId:(NSString *)orderId
                   completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
