//
//  AdvancedOrderBuilder.h
//  TradingApp
//
//  Advanced order construction system for bracket orders, OCO orders, and complex strategies
//

#import <Foundation/Foundation.h>
#import "TradingRuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OrderStrategyType) {
    OrderStrategyTypeSingle = 0,        // Simple single order
    OrderStrategyTypeBracket,           // Entry + Stop + Target
    OrderStrategyTypeOCO,               // One-Cancels-Other
    OrderStrategyTypeOTO,               // One-Triggers-Other
    OrderStrategyTypeTrailingStop,      // Trailing stop loss
    OrderStrategyTypeScaleIn,           // Scale into position
    OrderStrategyTypeScaleOut           // Scale out of position
};

@interface AdvancedOrderBuilder : NSObject

#pragma mark - Order Construction

/**
 * Build a simple single order
 * @param symbol Stock symbol
 * @param side BUY/SELL/SELL_SHORT
 * @param quantity Number of shares
 * @param orderType MARKET/LIMIT/STOP/STOP_LIMIT
 * @param price Limit price (0 for market orders)
 * @param stopPrice Stop price (for stop orders)
 * @param timeInForce DAY/GTC/IOC/FOK
 * @return Order dictionary ready for API submission
 */
+ (NSDictionary *)buildSimpleOrder:(NSString *)symbol
                               side:(NSString *)side
                           quantity:(double)quantity
                          orderType:(NSString *)orderType
                              price:(double)price
                          stopPrice:(double)stopPrice
                        timeInForce:(NSString *)timeInForce;

/**
 * Build a bracket order (entry + stop loss + profit target)
 * @param symbol Stock symbol
 * @param side BUY/SELL/SELL_SHORT
 * @param quantity Number of shares
 * @param entryType Entry order type (MARKET/LIMIT)
 * @param entryPrice Entry price (0 for market)
 * @param stopLossPrice Stop loss price
 * @param profitTargetPrice Profit target price
 * @param timeInForce Time in force for all orders
 * @return Array of order dictionaries (parent + children)
 */
+ (NSArray<NSDictionary *> *)buildBracketOrder:(NSString *)symbol
                                          side:(NSString *)side
                                      quantity:(double)quantity
                                     entryType:(NSString *)entryType
                                    entryPrice:(double)entryPrice
                                 stopLossPrice:(double)stopLossPrice
                             profitTargetPrice:(double)profitTargetPrice
                                   timeInForce:(NSString *)timeInForce;

/**
 * Build an OCO (One-Cancels-Other) order
 * @param symbol Stock symbol
 * @param side BUY/SELL/SELL_SHORT
 * @param quantity Number of shares
 * @param price1 First order price
 * @param orderType1 First order type
 * @param price2 Second order price
 * @param orderType2 Second order type
 * @param timeInForce Time in force
 * @return Array of linked OCO orders
 */
+ (NSArray<NSDictionary *> *)buildOCOOrder:(NSString *)symbol
                                      side:(NSString *)side
                                  quantity:(double)quantity
                                    price1:(double)price1
                                orderType1:(NSString *)orderType1
                                    price2:(double)price2
                                orderType2:(NSString *)orderType2
                               timeInForce:(NSString *)timeInForce;

/**
 * Build a trailing stop order
 * @param symbol Stock symbol
 * @param side SELL (for long position) or BUY_TO_COVER (for short)
 * @param quantity Number of shares
 * @param trailAmount Trail amount in dollars or percentage
 * @param isPercentage YES if trailAmount is percentage, NO if dollar amount
 * @return Trailing stop order dictionary
 */
+ (NSDictionary *)buildTrailingStopOrder:(NSString *)symbol
                                    side:(NSString *)side
                                quantity:(double)quantity
                             trailAmount:(double)trailAmount
                            isPercentage:(BOOL)isPercentage;

#pragma mark - Advanced Order Strategies

/**
 * Build scale-in orders (multiple entries at different prices)
 * @param symbol Stock symbol
 * @param side BUY/SELL_SHORT
 * @param totalQuantity Total shares to acquire across all orders
 * @param entryPrices Array of entry prices (NSNumber)
 * @param quantityDistribution Array of quantity percentages (should sum to 1.0)
 * @param orderType Order type for all entries
 * @param timeInForce Time in force
 * @return Array of scale-in orders
 */
+ (NSArray<NSDictionary *> *)buildScaleInOrders:(NSString *)symbol
                                            side:(NSString *)side
                                   totalQuantity:(double)totalQuantity
                                    entryPrices:(NSArray<NSNumber *> *)entryPrices
                            quantityDistribution:(NSArray<NSNumber *> *)quantityDistribution
                                       orderType:(NSString *)orderType
                                     timeInForce:(NSString *)timeInForce;

/**
 * Build scale-out orders (partial profit taking)
 * @param symbol Stock symbol
 * @param side SELL (for long) or BUY_TO_COVER (for short)
 * @param totalQuantity Total shares to sell
 * @param targetPrices Array of target prices (NSNumber)
 * @param quantityDistribution Array of quantity percentages
 * @param orderType Order type for all exits
 * @param timeInForce Time in force
 * @return Array of scale-out orders
 */
+ (NSArray<NSDictionary *> *)buildScaleOutOrders:(NSString *)symbol
                                             side:(NSString *)side
                                    totalQuantity:(double)totalQuantity
                                     targetPrices:(NSArray<NSNumber *> *)targetPrices
                             quantityDistribution:(NSArray<NSNumber *> *)quantityDistribution
                                        orderType:(NSString *)orderType
                                      timeInForce:(NSString *)timeInForce;

#pragma mark - Conditional Order Building

/**
 * Build conditional order that triggers based on another symbol's price
 * @param symbol Primary symbol to trade
 * @param conditionSymbol Symbol to watch for condition
 * @param conditionPrice Trigger price
 * @param conditionOperator ">", "<", ">=", "<="
 * @param orderData Main order data
 * @return Conditional order dictionary
 */
+ (NSDictionary *)buildConditionalOrder:(NSString *)symbol
                         conditionSymbol:(NSString *)conditionSymbol
                          conditionPrice:(double)conditionPrice
                       conditionOperator:(NSString *)conditionOperator
                               orderData:(NSDictionary *)orderData;

#pragma mark - Order Validation & Analysis

/**
 * Validate order data before submission
 * @param orderData Order dictionary to validate
 * @param error Error details if validation fails
 * @return YES if order is valid
 */
+ (BOOL)validateOrder:(NSDictionary *)orderData error:(NSError **)error;

/**
 * Validate bracket order logic
 * @param entryPrice Entry price
 * @param stopPrice Stop loss price
 * @param targetPrice Profit target price
 * @param side Order side
 * @param error Error details if validation fails
 * @return YES if bracket logic is valid
 */
+ (BOOL)validateBracketOrder:(double)entryPrice
                   stopPrice:(double)stopPrice
                 targetPrice:(double)targetPrice
                        side:(NSString *)side
                       error:(NSError **)error;

/**
 * Calculate order risk metrics
 * @param orderData Order dictionary
 * @param currentPrice Current market price
 * @return Dictionary with risk metrics
 */
+ (NSDictionary *)calculateOrderRiskMetrics:(NSDictionary *)orderData
                                currentPrice:(double)currentPrice;

#pragma mark - Order Formatting

/**
 * Convert order dictionary to human-readable description
 * @param orderData Order dictionary
 * @return Human-readable order description
 */
+ (NSString *)formatOrderDescription:(NSDictionary *)orderData;

/**
 * Convert bracket order to human-readable description
 * @param bracketOrders Array of bracket order dictionaries
 * @return Human-readable bracket description
 */
+ (NSString *)formatBracketOrderDescription:(NSArray<NSDictionary *> *)bracketOrders;

/**
 * Generate order preview for UI display
 * @param orderData Order data or array of orders
 * @param portfolioValue Current portfolio value for risk calculations
 * @return Formatted preview text
 */
+ (NSString *)generateOrderPreview:(id)orderData portfolioValue:(double)portfolioValue;

#pragma mark - Schwab API Specific Formatting

/**
 * Convert generic order to Schwab API format
 * @param genericOrder Generic order dictionary
 * @param accountId Account ID
 * @return Schwab API formatted order
 */
+ (NSDictionary *)convertToSchwabFormat:(NSDictionary *)genericOrder accountId:(NSString *)accountId;

/**
 * Convert bracket orders to Schwab API format
 * @param bracketOrders Array of bracket orders
 * @param accountId Account ID
 * @return Array of Schwab formatted orders
 */
+ (NSArray<NSDictionary *> *)convertBracketToSchwabFormat:(NSArray<NSDictionary *> *)bracketOrders
                                                accountId:(NSString *)accountId;

#pragma mark - Order Templates & Presets

/**
 * Create scalping preset (tight stops, quick profits)
 * @param symbol Stock symbol
 * @param side BUY/SELL
 * @param quantity Number of shares
 * @param entryPrice Entry price
 * @param stopPercent Stop loss percentage (e.g., 0.5 for 0.5%)
 * @param targetPercent Profit target percentage (e.g., 1.0 for 1%)
 * @return Scalping bracket order
 */
+ (NSArray<NSDictionary *> *)createScalpingPreset:(NSString *)symbol
                                              side:(NSString *)side
                                          quantity:(double)quantity
                                        entryPrice:(double)entryPrice
                                       stopPercent:(double)stopPercent
                                     targetPercent:(double)targetPercent;

/**
 * Create swing trading preset (wider stops, larger targets)
 * @param symbol Stock symbol
 * @param side BUY/SELL
 * @param quantity Number of shares
 * @param entryPrice Entry price
 * @param stopPercent Stop loss percentage (e.g., 3.0 for 3%)
 * @param targetPercent Profit target percentage (e.g., 10.0 for 10%)
 * @return Swing trading bracket order
 */
+ (NSArray<NSDictionary *> *)createSwingTradingPreset:(NSString *)symbol
                                                 side:(NSString *)side
                                             quantity:(double)quantity
                                           entryPrice:(double)entryPrice
                                          stopPercent:(double)stopPercent
                                        targetPercent:(double)targetPercent;

/**
 * Create breakout preset (based on day's range)
 * @param symbol Stock symbol
 * @param side BUY/SELL
 * @param quantity Number of shares
 * @param dayHigh Day's high price
 * @param dayLow Day's low price
 * @param breakoutOffset Offset from high/low for entry
 * @param stopOffset Offset for stop loss
 * @param targetMultiplier Target as multiple of range
 * @return Breakout bracket order
 */
+ (NSArray<NSDictionary *> *)createBreakoutPreset:(NSString *)symbol
                                             side:(NSString *)side
                                         quantity:(double)quantity
                                          dayHigh:(double)dayHigh
                                           dayLow:(double)dayLow
                                   breakoutOffset:(double)breakoutOffset
                                       stopOffset:(double)stopOffset
                                 targetMultiplier:(double)targetMultiplier;

@end

NS_ASSUME_NONNULL_END
