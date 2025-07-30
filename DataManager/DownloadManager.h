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
// Market data via HTTP REST calls
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;
- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion;
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(id orderBook, NSError *error))completion;

- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion;
- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion;

// Market lists
- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion;

// HTTP Polling subscription (NOT WebSocket - just symbol list management)
- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols;
- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols;

// Rate limiting info
- (NSInteger)remainingRequests;
- (NSDate *)rateLimitResetDate;

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

- (void)cancelRequest:(NSString *)requestID;
- (void)cancelAllRequests;

// Convenience methods for specific request types
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

- (void)fetchOrderBookForSymbol:(NSString *)symbol
                          depth:(NSInteger)depth
                     completion:(void (^)(id orderBook, NSError *error))completion;

- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion;
- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
