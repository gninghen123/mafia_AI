//
//  TradingRuntimeModels.h
//  TradingApp
//
//  Enhanced runtime models for advanced trading functionality
//  Extends existing RuntimeModels.h with trading-specific models
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Account Model

@interface AccountModel : NSObject
@property (nonatomic, strong) NSString *accountId;      // "123456789"
@property (nonatomic, strong) NSString *accountType;    // "MARGIN", "CASH", "IRA"
@property (nonatomic, strong) NSString *brokerName;     // "SCHWAB", "IBKR"
@property (nonatomic, strong) NSString *displayName;    // "SCHWAB-12345" or user custom
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isPrimary;           // Default account
@property (nonatomic, strong) NSDate *lastUpdated;

// Display helpers
- (NSString *)formattedDisplayName;
- (NSColor *)connectionStatusColor;
@end

#pragma mark - Enhanced Portfolio Summary

@interface PortfolioSummaryModel : NSObject
@property (nonatomic, strong) NSString *accountId;      // FK to AccountModel
@property (nonatomic, strong) NSString *brokerName;     // "SCHWAB", "IBKR"
@property (nonatomic, assign) double totalValue;
@property (nonatomic, assign) double dayPL;
@property (nonatomic, assign) double dayPLPercent;
@property (nonatomic, assign) double buyingPower;
@property (nonatomic, assign) double cashBalance;
@property (nonatomic, assign) double marginUsed;        // For margin accounts
@property (nonatomic, assign) NSInteger dayTradesLeft;  // PDT tracking
@property (nonatomic, strong) NSDate *lastUpdated;

// Calculated properties
- (double)totalEquity;                                   // totalValue + cashBalance
- (double)marginAvailable;                              // buyingPower - marginUsed
- (BOOL)isPDTRestricted;                                // dayTradesLeft <= 0
- (NSString *)formattedTotalValue;
- (NSString *)formattedDayPL;
@end

#pragma mark - Advanced Position Model

@interface AdvancedPositionModel : NSObject
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *accountId;
@property (nonatomic, assign) double quantity;                    // +/- for LONG/SHORT
@property (nonatomic, assign) double avgCost;
@property (nonatomic, assign) double currentPrice;               // Real-time
@property (nonatomic, assign) double bidPrice;                   // Real-time
@property (nonatomic, assign) double askPrice;                   // Real-time
@property (nonatomic, assign) double dayHigh;                    // From quote
@property (nonatomic, assign) double dayLow;                     // From quote
@property (nonatomic, assign) double dayOpen;                    // From quote
@property (nonatomic, assign) double previousClose;              // From quote
@property (nonatomic, assign) double marketValue;                // quantity * currentPrice
@property (nonatomic, assign) double unrealizedPL;
@property (nonatomic, assign) double unrealizedPLPercent;
@property (nonatomic, assign) NSInteger volume;                  // Daily volume
@property (nonatomic, strong) NSDate *priceLastUpdated;

// Position analysis
- (BOOL)isLongPosition;
- (BOOL)isShortPosition;
- (double)riskPercentageOfPortfolio:(double)totalPortfolioValue;
- (double)sharesNeededForPercentOfPortfolio:(double)percent portfolioValue:(double)totalValue;
- (double)sharesNeededForPercentOfCash:(double)percent cashAvailable:(double)cash;
- (double)sharesNeededForDollarAmount:(double)dollarAmount;

// Display helpers
- (NSString *)formattedQuantity;
- (NSString *)formattedMarketValue;
- (NSString *)formattedUnrealizedPL;
- (NSString *)formattedBidAsk;
- (NSColor *)plColor;                                           // Green/Red based on P&L
@end

#pragma mark - Advanced Order Model

@interface AdvancedOrderModel : NSObject
@property (nonatomic, strong) NSString *orderId;
@property (nonatomic, strong) NSString *accountId;
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *orderType;               // "MARKET", "LIMIT", "STOP", "STOP_LIMIT"
@property (nonatomic, strong) NSString *side;                    // "BUY", "SELL", "SELL_SHORT"
@property (nonatomic, strong) NSString *status;                  // "OPEN", "FILLED", "CANCELLED", "PENDING"
@property (nonatomic, strong) NSString *timeInForce;             // "DAY", "GTC", "IOC", "FOK"
@property (nonatomic, assign) double quantity;
@property (nonatomic, assign) double filledQuantity;
@property (nonatomic, assign) double price;                      // Limit price
@property (nonatomic, assign) double stopPrice;                  // Stop price
@property (nonatomic, assign) double avgFillPrice;
@property (nonatomic, strong) NSDate *createdDate;
@property (nonatomic, strong) NSDate *updatedDate;
@property (nonatomic, strong) NSString *instruction;             // "BUY_TO_OPEN", "SELL_TO_CLOSE", etc.

// Advanced order features
@property (nonatomic, strong, nullable) NSArray<NSString *> *linkedOrderIds;      // OCO, Bracket orders
@property (nonatomic, strong, nullable) NSString *parentOrderId;                  // For child orders
@property (nonatomic, assign) BOOL isChildOrder;
@property (nonatomic, strong) NSString *orderStrategy;                           // "SINGLE", "OCO", "BRACKET"

// Market context (for risk calculations)
@property (nonatomic, assign) double currentBidPrice;           // For real-time calculations
@property (nonatomic, assign) double currentAskPrice;
@property (nonatomic, assign) double dayHigh;
@property (nonatomic, assign) double dayLow;

// Order state analysis
- (BOOL)isActive;                                               // OPEN, PENDING
- (BOOL)isPending;                                              // Waiting execution
- (BOOL)isCompleted;                                            // FILLED
- (BOOL)isCancelled;                                            // CANCELLED, REJECTED
- (BOOL)isPartiallyFilled;                                      // filledQuantity > 0 && < quantity
- (double)remainingQuantity;                                    // quantity - filledQuantity
- (double)distanceFromCurrentPrice:(double)currentPrice;        // For monitoring
- (NSString *)riskRewardRatioStringWithStopPrice:(double)stopPrice targetPrice:(double)targetPrice;

// Display helpers
- (NSString *)formattedQuantity;
- (NSString *)formattedPrice;
- (NSString *)formattedStatus;
- (NSString *)formattedCreatedDate;
- (NSColor *)statusColor;
@end

#pragma mark - Order Book Entry (for Level 2 data)

@interface OrderBookLevel : NSObject
@property (nonatomic, assign) double price;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, assign) NSInteger orderCount;             // Number of orders at this level
@end

#pragma mark - Trading Quote Model (Enhanced MarketQuoteModel)

@interface TradingQuoteModel : MarketQuoteModel
@property (nonatomic, assign) double bidSize;
@property (nonatomic, assign) double askSize;
@property (nonatomic, strong, nullable) NSArray<OrderBookLevel *> *topBids;          // Top 5 bid levels
@property (nonatomic, strong, nullable) NSArray<OrderBookLevel *> *topAsks;          // Top 5 ask levels
@property (nonatomic, assign) double vwap;                                          // Volume weighted average
@property (nonatomic, assign) double atr14;                                         // 14-day ATR for SL calculations

// Level 2 analysis
- (double)bidAskSpread;
- (double)bidAskSpreadPercent;
- (NSInteger)totalBidSize;
- (NSInteger)totalAskSize;
- (double)level2Imbalance;                                      // Bid vs Ask pressure
@end

NS_ASSUME_NONNULL_END
