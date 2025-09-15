//
//  DataManager.h (COMPLETE & FIXED VERSION)
//  TradingApp
//
//  Central data management system that provides unified data interface to widgets
//  Uses HTTP polling for frequent updates (no WebSocket/streaming)
//
//  UPDATED: Now works with runtime models from adapters
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"
#import "RuntimeModels.h"  // Import runtime models
#import "SeasonalDataModel.h"
#import "DownloadManager.h"

// Forward declarations - SOLO runtime objects
@class MarketData;
@class OrderBookEntry;
@class DataManager;
@class CompanyInfoModel;
@class MarketPerformerModel;
@class NewsModel;

// Delegate protocol for data updates via HTTP polling
// UPDATED: Now notifies with runtime models
@protocol DataManagerDelegate <NSObject>
@optional
- (void)dataManager:(DataManager *)manager didUpdateQuote:(MarketData *)quote forSymbol:(NSString *)symbol;

// UPDATED: Now notifies with runtime HistoricalBarModel objects
- (void)dataManager:(DataManager *)manager didUpdateHistoricalData:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol;
- (void)dataManager:(DataManager *)manager didUpdateBatchQuotes:(NSDictionary *)quotes forSymbols:(NSArray<NSString *> *)symbols;

- (void)dataManager:(DataManager *)manager didUpdateOrderBook:(NSArray<OrderBookEntry *> *)orderBook forSymbol:(NSString *)symbol;

// TODO: Update these to runtime models when Position/Order runtime models are created
- (void)dataManager:(DataManager *)manager didUpdatePositions:(NSArray<NSDictionary *> *)positionDictionaries;
- (void)dataManager:(DataManager *)manager didUpdateOrders:(NSArray<NSDictionary *> *)orderDictionaries;

- (void)dataManager:(DataManager *)manager didFailWithError:(NSError *)error forRequest:(NSString *)requestID;

// ✅ AGGIUNTO: News delegate method (era nel .m ma non nel .h)
- (void)dataManager:(DataManager *)manager didUpdateNews:(NSArray<NewsModel *> *)news forSymbol:(NSString *)symbol;

@end

@interface DataManager : NSObject

+ (instancetype)sharedManager;

#pragma mark - Core Properties
// ✅ AGGIUNTO: Proprietà downloadManager per accesso pubblico
@property (nonatomic, strong, readonly) DownloadManager *downloadManager;

// ✅ AGGIUNTO: Proprietà dataSources (readonly per sicurezza)
@property (nonatomic, strong, readonly) NSMutableDictionary *dataSources;

#pragma mark - Delegate Management

- (void)addDelegate:(id<DataManagerDelegate>)delegate;
- (void)removeDelegate:(id<DataManagerDelegate>)delegate;

#pragma mark - Data Source Management Methods
// ✅ AGGIUNTO: Metodi mancanti per gestione data sources

/**
 * Get data source instance for given type
 * @param type DataSourceType to lookup
 * @return Data source instance or nil if not found
 */
- (id<DataSource>)dataSourceForType:(DataSourceType)type;

/**
 * Get priority for a data source
 * @param dataSource DataSourceType to check
 * @return Priority value (lower = higher priority)
 */
- (NSInteger)priorityForDataSource:(DataSourceType)dataSource;

/**
 * Check if data source is currently connected
 * @param dataSource DataSourceType to check
 * @return YES if connected, NO otherwise
 */
- (BOOL)isDataSourceConnected:(DataSourceType)dataSource;

#pragma mark - Market Data Methods

// Single quote request
- (NSString *)requestQuoteForSymbol:(NSString *)symbol
                         completion:(void (^)(MarketData *quote, NSError *error))completion;

// Batch quotes request
- (NSString *)requestQuotesForSymbols:(NSArray<NSString *> *)symbols
                           completion:(void (^)(NSArray<MarketData *> *quotes, NSError *error))completion;

// Historical data request with adapter conversion
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion;

// Company information request
- (void)requestCompanyInfoForSymbol:(NSString *)symbol
                         completion:(void (^)(NSDictionary *companyInfo, NSError *error))completion;

#pragma mark - Market Lists and Discovery

// Market lists (top gainers, losers, etc.)
- (void)requestMarketListForType:(NSString *)listType
                      completion:(void (^)(NSArray *results, NSError *error))completion;

#pragma mark - Market Performers (NEW - era nel .m)
// ✅ AGGIUNTO: Market performers methods che erano implementati ma non dichiarati

- (void)getMarketPerformersForList:(NSString *)listType
                         timeframe:(NSString *)timeframe
                        completion:(void (^)(NSArray<MarketPerformerModel *> *performers, NSError *error))completion;

- (void)refreshMarketListCache:(NSString *)listType timeframe:(NSString *)timeframe;
- (NSArray<MarketPerformerModel *> *)getCachedMarketPerformers:(NSString *)listType timeframe:(NSString *)timeframe;

#pragma mark - Seasonal Data (Special)

// Seasonal data requests for quarterly analysis
- (void)requestSeasonalDataForSymbol:(NSString *)symbol
                            dataType:(NSString *)dataType
                          completion:(void (^)(SeasonalDataModel *seasonalData, NSError *error))completion;

#pragma mark - Account data requests
// TODO: Update these when Position/Order runtime models are created
- (void)requestPositionsWithCompletion:(void (^)(NSArray<NSDictionary *> *positionDictionaries, NSError *error))completion;
- (void)requestOrdersWithCompletion:(void (^)(NSArray<NSDictionary *> *orderDictionaries, NSError *error))completion;

#pragma mark - HTTP Polling management (maintains symbol list for periodic requests)

- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols;
- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols;

#pragma mark - Request management

- (void)cancelRequest:(NSString *)requestID;
- (void)cancelAllRequests;

#pragma mark - Connection status

- (BOOL)isConnected;
- (NSArray<NSString *> *)availableDataSources;
- (NSString *)activeDataSource;

#pragma mark - ❌ REMOVE THESE - Violate Architecture
// ⚠️ THESE METHODS SHOULD BE REMOVED as they violate the architecture:
// DataManager should not know about specific APIs like Zacks

/*
 * ❌ DEPRECATED: Remove this method - violates architecture
 * DataManager should use generic requestSeasonalDataForSymbol instead
 */
// - (void)requestZacksData:(NSDictionary *)parameters
//               completion:(void (^)(SeasonalDataModel * _Nullable data, NSError * _Nullable error))completion;

@end
