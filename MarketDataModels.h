//
//  MarketDataModels.h
//  TradingApp
//
//  Data models for market data
//

#import <Foundation/Foundation.h>

// Base market data quote
@interface MarketData : NSObject
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSDecimalNumber *bid;
@property (nonatomic, strong) NSDecimalNumber *ask;
@property (nonatomic, strong) NSDecimalNumber *last;
@property (nonatomic, strong) NSDecimalNumber *open;
@property (nonatomic, strong) NSDecimalNumber *high;
@property (nonatomic, strong) NSDecimalNumber *low;
@property (nonatomic, strong) NSDecimalNumber *close;
@property (nonatomic, strong) NSDecimalNumber *previousClose;
@property (nonatomic, assign) NSInteger volume;
@property (nonatomic, assign) NSInteger bidSize;
@property (nonatomic, assign) NSInteger askSize;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSDecimalNumber *change;
@property (nonatomic, strong) NSDecimalNumber *changePercent;
@property (nonatomic, assign) BOOL isMarketOpen;
@property (nonatomic, strong) NSString *exchange;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;
@end

// Historical bar data
@interface HistoricalBar : NSObject
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSDecimalNumber *open;
@property (nonatomic, strong) NSDecimalNumber *high;
@property (nonatomic, strong) NSDecimalNumber *low;
@property (nonatomic, strong) NSDecimalNumber *close;
@property (nonatomic, assign) NSInteger volume;
@property (nonatomic, strong) NSDecimalNumber *vwap;
@property (nonatomic, assign) NSInteger trades;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;
@end

// Order book entry
@interface OrderBookEntry : NSObject
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, strong) NSString *exchange;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, assign) NSInteger orders; // Number of orders at this level

- (instancetype)initWithPrice:(NSDecimalNumber *)price size:(NSInteger)size;
@end

// Time and sales entry
@interface TimeSalesEntry : NSObject
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, strong) NSString *condition;
@property (nonatomic, assign) BOOL isBuy; // Aggressor side
@end

// Position data
@interface Position : NSObject
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *account;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, strong) NSDecimalNumber *averageCost;
@property (nonatomic, strong) NSDecimalNumber *currentPrice;
@property (nonatomic, strong) NSDecimalNumber *marketValue;
@property (nonatomic, strong) NSDecimalNumber *unrealizedPnL;
@property (nonatomic, strong) NSDecimalNumber *realizedPnL;
@property (nonatomic, strong) NSDecimalNumber *dayPnL;
@property (nonatomic, strong) NSDecimalNumber *percentChange;
@property (nonatomic, strong) NSString *side; // "long" or "short"
@property (nonatomic, strong) NSDate *openDate;

- (NSDecimalNumber *)totalPnL;
- (NSDecimalNumber *)totalPnLPercent;
@end

// Order data
@interface Order : NSObject
@property (nonatomic, strong) NSString *orderID;
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *side; // "buy" or "sell"
@property (nonatomic, strong) NSString *orderType; // "market", "limit", "stop", etc.
@property (nonatomic, strong) NSString *timeInForce; // "day", "gtc", "ioc", etc.
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) NSInteger filledQuantity;
@property (nonatomic, strong) NSDecimalNumber *price; // Limit price
@property (nonatomic, strong) NSDecimalNumber *stopPrice;
@property (nonatomic, strong) NSDecimalNumber *averageFillPrice;
@property (nonatomic, strong) NSString *status; // "pending", "filled", "cancelled", etc.
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, strong) NSDate *filledAt;
@property (nonatomic, strong) NSString *account;

- (BOOL)isActive;
- (BOOL)isFilled;
- (BOOL)isCancelled;
@end
