//
//  DataManager.h (CORRECTED - EXACT MATCH WITH .M)
//  TradingApp
//
//  Central data management system that provides unified data interface to widgets
//  Uses HTTP polling for frequent updates (no WebSocket/streaming)
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"
#import "RuntimeModels.h"
#import "SeasonalDataModel.h"
#import "DownloadManager.h"

// Forward declarations
@class MarketData;
@class OrderBookEntry;
@class DataManager;
@class CompanyInfoModel;
@class MarketPerformerModel;
@class NewsModel;
@class TickDataModel;

// Delegate protocol for data updates via HTTP polling
@protocol DataManagerDelegate <NSObject>
@optional
- (void)dataManager:(DataManager *)manager didUpdateQuote:(MarketData *)quote forSymbol:(NSString *)symbol;
- (void)dataManager:(DataManager *)manager didUpdateHistoricalData:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol;
- (void)dataManager:(DataManager *)manager didUpdateBatchQuotes:(NSDictionary *)quotes forSymbols:(NSArray<NSString *> *)symbols;
- (void)dataManager:(DataManager *)manager didUpdateOrderBook:(NSArray<OrderBookEntry *> *)orderBook forSymbol:(NSString *)symbol;
- (void)dataManager:(DataManager *)manager didUpdatePositions:(NSArray<NSDictionary *> *)positionDictionaries;
- (void)dataManager:(DataManager *)manager didUpdateOrders:(NSArray<NSDictionary *> *)orderDictionaries;
- (void)dataManager:(DataManager *)manager didFailWithError:(NSError *)error forRequest:(NSString *)requestID;
- (void)dataManager:(DataManager *)manager didUpdateNews:(NSArray<NewsModel *> *)news forSymbol:(NSString *)symbol;
@end

@interface DataManager : NSObject

+ (instancetype)sharedManager;

#pragma mark - Core Properties
@property (nonatomic, strong, readonly) DownloadManager *downloadManager;
@property (nonatomic, strong, readonly) NSMutableDictionary *dataSources;

#pragma mark - Delegate Management
- (void)addDelegate:(id<DataManagerDelegate>)delegate;
- (void)removeDelegate:(id<DataManagerDelegate>)delegate;

#pragma mark - Market Data Methods (EXACT MATCH WITH .M)

// Single quote request
- (NSString *)requestQuoteForSymbol:(NSString *)symbol
                         completion:(void (^)(MarketData *quote, NSError *error))completion;

// Batch quotes request
- (NSString *)requestQuotesForSymbols:(NSArray<NSString *> *)symbols
                           completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

// Historical data request with date range + needExtendedHours
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                           needExtendedHours:(BOOL)needExtendedHours
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion;

// Historical data request with count + needExtendedHours
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count
                           needExtendedHours:(BOOL)needExtendedHours
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion;

// Order book request (no depth parameter)
- (NSString *)requestOrderBookForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray<OrderBookEntry *> *bids, NSArray<OrderBookEntry *> *asks, NSError *error))completion;

#pragma mark - Market Lists Implementation (FROM .M)

// Market performers method as implemented
- (void)getMarketPerformersForList:(NSString *)listType
                         timeframe:(NSString *)timeframe
                        completion:(void (^)(NSArray<MarketPerformerModel *> *performers, NSError *error))completion;

#pragma mark - Seasonal Data (FROM EXTENSIONS)

// Seasonal data request method used by DataHub
- (void)requestSeasonalDataForSymbol:(NSString *)symbol
                            dataType:(NSString *)dataType
                          completion:(void (^)(SeasonalDataModel *seasonalData, NSError *error))completion;

#pragma mark - Symbol Search (FROM EXTENSIONS)

// From DataManager+SymbolSearch extension
- (void)searchSymbolsWithQuery:(NSString *)query
                    dataSource:(DataSourceType)dataSource
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<NSDictionary *> *results, NSError *error))completion;

#pragma mark - Connection Status (FROM .M)

- (BOOL)isConnected;
- (NSArray<NSString *> *)availableDataSources;
- (NSString *)activeDataSource;

#pragma mark - Utility Methods (FROM .M)

// Date calculations for historical data
- (NSDate *)dateBySubtractingBarsFromEndDate:(NSDate *)endDate
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count;

// Fallback and error handling helpers
- (DataSourceType)getNextAvailableDataSource:(DataSourceType)currentSource;
- (void)recordFailureForDataSource:(DataSourceType)dataSource;
- (void)recordSuccessForDataSource:(DataSourceType)dataSource;

// Delegate notification helpers (implemented in .m)
- (void)notifyDelegatesOfQuoteUpdate:(MarketData *)quote forSymbol:(NSString *)symbol;
- (void)notifyDelegatesOfBatchQuotesUpdate:(NSDictionary *)quotes forSymbols:(NSArray<NSString *> *)symbols;
- (void)notifyDelegatesOfHistoricalDataUpdate:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol;
- (void)notifyDelegatesOfError:(NSError *)error forRequest:(NSString *)requestID;

@end
