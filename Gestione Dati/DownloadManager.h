//
//  DownloadManager.h
//  TradingApp
//
//  HTTP request manager for external data sources
//  NO WebSocket - only HTTP REST API calls
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

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

@optional
#pragma mark - Market Data (Unified)
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;
- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion;
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                    needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;
- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(id orderBook, NSError *error))completion;

#pragma mark - Portfolio Data (Unified)
/// Get list of available accounts for this data source
- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion;

/// Get detailed information for specific account (portfolio summary, balances, etc.)
- (void)fetchAccountDetails:(NSString *)accountId
                 completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion;

/// Get all positions for this data source (will use first available account if no account specified)
- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion;

/// Get positions for specific account
- (void)fetchPositionsForAccount:(NSString *)accountId
                      completion:(void (^)(NSArray *positions, NSError *error))completion;

/// Get all orders for this data source (will use first available account if no account specified)
- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion;

/// Get orders for specific account
- (void)fetchOrdersForAccount:(NSString *)accountId
                   completion:(void (^)(NSArray *orders, NSError *error))completion;

#pragma mark - Trading Operations (Unified)
/// Place order on specific account
- (void)placeOrderForAccount:(NSString *)accountId
                   orderData:(NSDictionary *)orderData
                  completion:(void (^)(NSString *orderId, NSError *error))completion;

/// Cancel order on specific account
- (void)cancelOrderForAccount:(NSString *)accountId
                      orderId:(NSString *)orderId
                   completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - Market Lists (Unified)
- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion;

@end

@interface DownloadManager : NSObject

+ (instancetype)sharedManager;

// Data source management
- (void)registerDataSource:(id<DataSource>)dataSource
                  withType:(DataSourceType)type
                  priority:(NSInteger)priority;
- (void)unregisterDataSource:(DataSourceType)type;

// Connection management
- (void)connectDataSource:(DataSourceType)type
               completion:(nullable void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)disconnectDataSource:(DataSourceType)type;
- (void)reconnectAllDataSources;

// Status and monitoring
- (BOOL)isDataSourceConnected:(DataSourceType)type;
- (DataSourceCapabilities)capabilitiesForDataSource:(DataSourceType)type;
- (NSDictionary *)statisticsForDataSource:(DataSourceType)type;

// Properties
@property (nonatomic, readonly) DataSourceType currentDataSource;

// Request execution
// Metodo principale - il DownloadManager decide la priorità
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;

// Metodo avanzato - per casi speciali con source forzato
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
             preferredSource:(DataSourceType)preferredSource
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;
- (NSString *)executeHistoricalRequestWithCount:(NSDictionary *)parameters
                                      completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;


- (void)cancelRequest:(NSString *)requestID;
- (void)cancelAllRequests;

// Convenience methods for specific request types
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                    needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;


- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(id orderBook, NSError *error))completion;

- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion;
- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion;
// Current bar logic for DataSource-specific behavior
- (BOOL)isDailyOrHigherTimeframe:(BarTimeframe)timeframe;
- (BOOL)needsCurrentBarCompletion:(NSArray *)historicalBars
                        timeframe:(BarTimeframe)timeframe;
- (void)autoCompleteWithCurrentBar:(id)historicalData
                        parameters:(NSDictionary *)parameters
                        dataSource:(id<DataSource>)dataSource
                        completion:(void (^)(NSArray *bars, DataSourceType usedSource, NSError *error))completion;


@end

NS_ASSUME_NONNULL_END
