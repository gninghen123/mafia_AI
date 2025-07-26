//
//  Order.h
//  mafia_AI
//
//  Modello per rappresentare un ordine di trading
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OrderType) {
    OrderTypeMarket,
    OrderTypeLimit,
    OrderTypeStop,
    OrderTypeStopLimit
};

typedef NS_ENUM(NSInteger, OrderSide) {
    OrderSideBuy,
    OrderSideSell
};

typedef NS_ENUM(NSInteger, OrderStatus) {
    OrderStatusPending,
    OrderStatusOpen,
    OrderStatusPartiallyFilled,
    OrderStatusFilled,
    OrderStatusCanceled,
    OrderStatusRejected
};

@interface Order : NSObject

@property (nonatomic, strong) NSString *orderId;
@property (nonatomic, strong) NSString *accountId;
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, assign) OrderType orderType;
@property (nonatomic, assign) OrderSide side;
@property (nonatomic, assign) OrderStatus status;
@property (nonatomic, assign) double quantity;
@property (nonatomic, assign) double filledQuantity;
@property (nonatomic, assign) double price;           // Per limit orders
@property (nonatomic, assign) double stopPrice;       // Per stop orders
@property (nonatomic, assign) double avgFillPrice;
@property (nonatomic, strong) NSDate *createdDate;
@property (nonatomic, strong, nullable) NSDate *filledDate;
@property (nonatomic, strong, nullable) NSString *timeInForce; // "day", "gtc", etc.

// Helper methods
- (NSString *)orderTypeString;
- (NSString *)sideString;
- (NSString *)statusString;
- (BOOL)isActive;
- (BOOL)isComplete;

@end

NS_ASSUME_NONNULL_END
