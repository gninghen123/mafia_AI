//
//  DownloadManager.h
//  TradingApp
//
//  Manages API connections and data downloads from multiple providers
//

#import <Foundation/Foundation.h>
#import "DataManager.h"

// Data source priorities
typedef NS_ENUM(NSInteger, DataSourceType) {
    DataSourceTypeSchwab,
    DataSourceTypeIBKR,
    DataSourceTypeAlpaca,
    DataSourceTypeYahoo,
    DataSourceTypePolygon,
    DataSourceTypeIEX,
    DataSourceTypeCustom
};

// Data source capabilities
typedef NS_OPTIONS(NSUInteger, DataSourceCapabilities) {
    DataSourceCapabilityQuotes          = 1 << 0,
    DataSourceCapabilityHistorical      = 1 << 1,
    DataSourceCapabilityOrderBook       = 1 << 2,
    DataSourceCapabilityTimeSales       = 1 << 3,
    DataSourceCapabilityOptions         = 1 << 4,
    DataSourceCapabilityNews            = 1 << 5,
    DataSourceCapabilityFundamentals    = 1 << 6,
    DataSourceCapabilityAccounts        = 1 << 7,
    DataSourceCapabilityTrading         = 1 << 8,
    DataSourceCapabilityRealtime        = 1 << 9
};

@protocol DataSourceProtocol;

@interface DownloadManager : NSObject

+ (instancetype)sharedManager;

// Data source management
- (void)registerDataSource:(id<DataSourceProtocol>)dataSource
                  withType:(DataSourceType)type
                  priority:(NSInteger)priority;
- (void)unregisterDataSource:(DataSourceType)type;
- (void)setDataSourcePriority:(NSInteger)priority forType:(DataSourceType)type;

// Configuration
- (void)configureDataSource:(DataSourceType)type withCredentials:(NSDictionary *)credentials;
- (void)setFallbackEnabled:(BOOL)enabled;
- (void)setMaxRetries:(NSInteger)retries;
- (void)setRequestTimeout:(NSTimeInterval)timeout;

// Execute requests with automatic fallback
- (NSString *)executeRequest:(DataRequestType)requestType
                  parameters:(NSDictionary *)parameters
              preferredSource:(DataSourceType)preferredSource
                  completion:(void (^)(id result, DataSourceType usedSource, NSError *error))completion;

// Batch requests
- (NSString *)executeBatchRequests:(NSArray<NSDictionary *> *)requests
                        completion:(void (^)(NSArray *results, NSArray<NSError *> *errors))completion;

// Connection management
- (void)connectDataSource:(DataSourceType)type completion:(void (^)(BOOL success, NSError *error))completion;
- (void)disconnectDataSource:(DataSourceType)type;
- (void)reconnectAllDataSources;

// Status and monitoring
- (BOOL)isDataSourceConnected:(DataSourceType)type;
- (DataSourceCapabilities)capabilitiesForDataSource:(DataSourceType)type;
- (NSDictionary *)statisticsForDataSource:(DataSourceType)type;
- (NSArray<NSNumber *> *)availableDataSourcesForRequest:(DataRequestType)requestType;

// Rate limiting
- (NSInteger)remainingRequestsForDataSource:(DataSourceType)type;
- (NSDate *)rateLimitResetDateForDataSource:(DataSourceType)type;

@end

// Protocol that all data sources must implement
@protocol DataSourceProtocol <NSObject>

@required
@property (nonatomic, readonly) DataSourceType sourceType;
@property (nonatomic, readonly) DataSourceCapabilities capabilities;
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) NSString *sourceName;

- (void)connectWithCredentials:(NSDictionary *)credentials
                    completion:(void (^)(BOOL success, NSError *error))completion;
- (void)disconnect;

@optional
// Market data
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

// Account data
- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion;
- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion;
- (void)fetchAccountInfoWithCompletion:(void (^)(NSDictionary *accountInfo, NSError *error))completion;

// Real-time subscriptions
- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols;
- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols;

// Rate limiting info
- (NSInteger)remainingRequests;
- (NSDate *)rateLimitResetDate;

@end
