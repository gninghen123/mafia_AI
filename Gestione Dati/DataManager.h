//
//  DataManager.h
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

// Forward declarations - SOLO runtime objects
@class MarketData;
@class OrderBookEntry;
@class DataManager;

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
@end

@interface DataManager : NSObject

+ (instancetype)sharedManager;

// Delegate management
- (void)addDelegate:(id<DataManagerDelegate>)delegate;
- (void)removeDelegate:(id<DataManagerDelegate>)delegate;

// Market data requests
- (NSString *)requestQuoteForSymbol:(NSString *)symbol
                         completion:(void (^)(MarketData *quote, NSError *error))completion;
// Batch quote request
- (NSString *)requestQuotesForSymbols:(NSArray<NSString *> *)symbols
                           completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

- (NSString *)requestOrderBookForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray<OrderBookEntry *> *bids,
                                                  NSArray<OrderBookEntry *> *asks,
                                                  NSError *error))completion;
// Historical data - with count + extended hours (NUOVO)
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count
                           needExtendedHours:(BOOL)needExtendedHours
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion;

// Historical data - with date range + extended hours (NUOVO)
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                           needExtendedHours:(BOOL)needExtendedHours
                                  completion:(void (^)(NSArray<HistoricalBarModel *> *bars, NSError *error))completion;

// Account data requests
// TODO: Update these when Position/Order runtime models are created
- (void)requestPositionsWithCompletion:(void (^)(NSArray<NSDictionary *> *positionDictionaries, NSError *error))completion;
- (void)requestOrdersWithCompletion:(void (^)(NSArray<NSDictionary *> *orderDictionaries, NSError *error))completion;

// HTTP Polling management (maintains symbol list for periodic requests)
- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols;
- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols;

// Request management
- (void)cancelRequest:(NSString *)requestID;
- (void)cancelAllRequests;

// Connection status
- (BOOL)isConnected;
- (NSArray<NSString *> *)availableDataSources;
- (NSString *)activeDataSource;


#pragma mark - Market Lists (NEW)
- (void)getMarketPerformersForList:(NSString *)listType
                         timeframe:(NSString *)timeframe
                        completion:(void (^)(NSArray<MarketPerformerModel *> *performers, NSError *error))completion;

- (void)refreshMarketListCache:(NSString *)listType timeframe:(NSString *)timeframe;
- (NSArray<MarketPerformerModel *> *)getCachedMarketPerformers:(NSString *)listType timeframe:(NSString *)timeframe;

#pragma mark - Seasonal/Zacks Data

/**
 * Request Zacks chart data for seasonal analysis
 * @param parameters Dictionary with "symbol" and "wrapper" keys
 * @param completion Completion block with raw Zacks data or error
 */
- (void)requestZacksData:(NSDictionary *)parameters
              completion:(void (^)(SeasonalDataModel * _Nullable data, NSError * _Nullable error))completion;




@end
