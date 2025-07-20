//
//  DataManager.h
//  TradingApp
//
//  Central data management system that provides unified data interface to widgets
//

#import <Foundation/Foundation.h>

// Data types
typedef NS_ENUM(NSInteger, DataRequestType) {
    DataRequestTypeQuote,           // Current price quote
    DataRequestTypeHistoricalBars,  // Historical OHLCV data
    DataRequestTypeOrderBook,       // Level 2 data
    DataRequestTypeTimeSales,       // Time and sales
    DataRequestTypeOptionChain,     // Options data
    DataRequestTypeNews,            // News feed
    DataRequestTypeFundamentals,    // Company fundamentals
    DataRequestTypePositions,       // Account positions
    DataRequestTypeOrders,          // Account orders
    DataRequestTypeAccountInfo,      // Account details
    
    DataRequestTypeMarketList = 100,
      DataRequestTypeTopGainers = 101,
      DataRequestTypeTopLosers = 102,
      DataRequestTypeETFList = 103,
};

typedef NS_ENUM(NSInteger, BarTimeframe) {
    BarTimeframe1Min,
    BarTimeframe5Min,
    BarTimeframe15Min,
    BarTimeframe30Min,
    BarTimeframe1Hour,
    BarTimeframe4Hour,
    BarTimeframe1Day,
    BarTimeframe1Week,
    BarTimeframe1Month
};

// Forward declarations
@class MarketData;
@class HistoricalBar;
@class OrderBookEntry;
@class Position;
@class Order;

// Delegate protocol for real-time updates
@protocol DataManagerDelegate <NSObject>
@optional
- (void)dataManager:(id)manager didUpdateQuote:(MarketData *)quote forSymbol:(NSString *)symbol;
- (void)dataManager:(id)manager didUpdateOrderBook:(NSArray<OrderBookEntry *> *)orderBook forSymbol:(NSString *)symbol;
- (void)dataManager:(id)manager didUpdatePositions:(NSArray<Position *> *)positions;
- (void)dataManager:(id)manager didUpdateOrders:(NSArray<Order *> *)orders;
- (void)dataManager:(id)manager didFailWithError:(NSError *)error forRequest:(NSString *)requestID;
@end

@interface DataManager : NSObject

+ (instancetype)sharedManager;

// Delegate management
- (void)addDelegate:(id<DataManagerDelegate>)delegate;
- (void)removeDelegate:(id<DataManagerDelegate>)delegate;

// Market data requests
- (NSString *)requestQuoteForSymbol:(NSString *)symbol
                          completion:(void (^)(MarketData *quote, NSError *error))completion;

- (NSString *)requestHistoricalDataForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                  completion:(void (^)(NSArray<HistoricalBar *> *bars, NSError *error))completion;

- (NSString *)requestOrderBookForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray<OrderBookEntry *> *bids,
                                                 NSArray<OrderBookEntry *> *asks,
                                                 NSError *error))completion;
//helper
- (NSDictionary *)dataForSymbol:(NSString *)symbol;
- (double)tickSizeForSymbol:(NSString *)symbol;


// Subscription management for real-time data
- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols;
- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols;
- (void)subscribeToOrderBook:(NSString *)symbol depth:(NSInteger)depth;
- (void)unsubscribeFromOrderBook:(NSString *)symbol;

// Account data requests
- (void)requestPositionsWithCompletion:(void (^)(NSArray<Position *> *positions, NSError *error))completion;
- (void)requestOrdersWithCompletion:(void (^)(NSArray<Order *> *orders, NSError *error))completion;
- (void)requestAccountInfoWithCompletion:(void (^)(NSDictionary *accountInfo, NSError *error))completion;

// Cancel requests
- (void)cancelRequest:(NSString *)requestID;
- (void)cancelAllRequests;

// Data caching
- (void)setCacheEnabled:(BOOL)enabled;
- (void)clearCache;

// Connection status
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) NSArray<NSString *> *availableDataSources;
@property (nonatomic, readonly) NSString *activeDataSource;

@end
