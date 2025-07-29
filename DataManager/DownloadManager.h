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
@property (nonatomic, readonly) BOOL isConnected; // AGGIUNGERE

// Connection management (HTTP authentication only)
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)disconnect;

@optional
// Market data via HTTP REST calls
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

// Account data via HTTP
- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion;
- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion;
- (void)fetchAccountInfoWithCompletion:(void (^)(NSDictionary *accountInfo, NSError *error))completion;

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
- (void)registerDataSource:(id<DataSource>)dataSource;
- (void)unregisterDataSource:(id<DataSource>)dataSource;
- (NSArray<id<DataSource>> *)availableDataSources;
- (id<DataSource>)primaryDataSource;

// Connection status (HTTP authentication status)
- (BOOL)isDataSourceConnected:(DataSourceType)sourceType;
- (void)connectToDataSource:(DataSourceType)sourceType
                 completion:(void (^)(BOOL success, NSError *error))completion;

// Data requests - all via HTTP REST API
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
- (void)fetchAccountInfoWithCompletion:(void (^)(NSDictionary *accountInfo, NSError *error))completion;

// Rate limiting
- (NSInteger)remainingRequestsForDataSource:(DataSourceType)sourceType;
- (NSDate *)rateLimitResetDateForDataSource:(DataSourceType)sourceType;

@end

NS_ASSUME_NONNULL_END
