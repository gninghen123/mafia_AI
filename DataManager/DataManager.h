//
//  DataManager.h
//  TradingApp
//
//  Central data management system that provides unified data interface to widgets
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"  // Aggiungi questo


// Forward declarations
@class MarketData;
@class HistoricalBar;
@class OrderBookEntry;
@class Position;
@class Order;
@class DataManager;

// Delegate protocol for real-time updates
@protocol DataManagerDelegate <NSObject>
@optional
- (void)dataManager:(DataManager *)manager didUpdateQuote:(MarketData *)quote forSymbol:(NSString *)symbol;
- (void)dataManager:(DataManager *)manager didUpdateHistoricalData:(NSArray<HistoricalBar *> *)bars forSymbol:(NSString *)symbol;
- (void)dataManager:(DataManager *)manager didUpdateOrderBook:(NSArray<OrderBookEntry *> *)orderBook forSymbol:(NSString *)symbol;
- (void)dataManager:(DataManager *)manager didUpdatePositions:(NSArray<Position *> *)positions;
- (void)dataManager:(DataManager *)manager didUpdateOrders:(NSArray<Order *> *)orders;
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

// Historical data - with date range (original method)
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion;

// Historical data - with count (new method to match implementation)
- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                       count:(NSInteger)count
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion;

- (NSString *)requestOrderBookForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray<OrderBookEntry *> *bids,
                                                 NSArray<OrderBookEntry *> *asks,
                                                 NSError *error))completion;

// Account data requests
- (void)requestPositionsWithCompletion:(void (^)(NSArray<Position *> *positions, NSError *error))completion;
- (void)requestOrdersWithCompletion:(void (^)(NSArray<Order *> *orders, NSError *error))completion;

// Subscription management
- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols;
- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols;

// Request management
- (void)cancelRequest:(NSString *)requestID;
- (void)cancelAllRequests;

// Cache management
@property (nonatomic, assign) BOOL cacheEnabled;
@property (nonatomic, assign) NSTimeInterval quoteCacheTTL;      // Default: 5 seconds
@property (nonatomic, assign) NSTimeInterval historicalCacheTTL; // Default: 300 seconds
- (void)clearCache;

// Connection status
- (BOOL)isConnected;
- (NSArray<NSString *> *)availableDataSources;
- (NSString *)activeDataSource;

@end
