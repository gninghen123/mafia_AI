//
//  AdvancedOrderBuilder.m
//  TradingApp
//
//  Implementation of advanced order construction system
//

#import "AdvancedOrderBuilder.h"
#import "OrderQuantityCalculator.h"

@implementation AdvancedOrderBuilder

#pragma mark - Order Construction

+ (NSDictionary *)buildSimpleOrder:(NSString *)symbol
                               side:(NSString *)side
                           quantity:(double)quantity
                          orderType:(NSString *)orderType
                              price:(double)price
                          stopPrice:(double)stopPrice
                        timeInForce:(NSString *)timeInForce {
    
    NSMutableDictionary *order = [NSMutableDictionary dictionary];
    
    // Basic order info
    order[@"orderType"] = orderType;
    order[@"session"] = @"NORMAL";  // Regular trading hours
    order[@"duration"] = timeInForce ?: @"DAY";
    
    // Order strategy
    order[@"orderStrategyType"] = @"SINGLE";
    
    // Order leg (Schwab format)
    NSMutableDictionary *orderLegCollection = [NSMutableDictionary dictionary];
    orderLegCollection[@"instruction"] = side;
    orderLegCollection[@"quantity"] = @(quantity);
    
    // Instrument
    NSMutableDictionary *instrument = [NSMutableDictionary dictionary];
    instrument[@"symbol"] = symbol;
    instrument[@"assetType"] = @"EQUITY";
    orderLegCollection[@"instrument"] = instrument;
    
    order[@"orderLegCollection"] = @[orderLegCollection];
    
    // Price based on order type
    if ([orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        if (price > 0) {
            order[@"price"] = @(price);
        }
    }
    
    if ([orderType isEqualToString:@"STOP"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        if (stopPrice > 0) {
            order[@"stopPrice"] = @(stopPrice);
        }
    }
    
    NSLog(@"🔨 OrderBuilder: Built simple %@ order - %@ %.0f %@ at %@",
          orderType, side, quantity, symbol, @(price));
    
    return [order copy];
}

+ (NSArray<NSDictionary *> *)buildBracketOrder:(NSString *)symbol
                                          side:(NSString *)side
                                      quantity:(double)quantity
                                     entryType:(NSString *)entryType
                                    entryPrice:(double)entryPrice
                                 stopLossPrice:(double)stopLossPrice
                             profitTargetPrice:(double)profitTargetPrice
                                   timeInForce:(NSString *)timeInForce {
    
    NSMutableArray *orders = [NSMutableArray array];
    
    // 1. Parent Entry Order
    NSDictionary *entryOrder = [self buildSimpleOrder:symbol
                                                  side:side
                                              quantity:quantity
                                             orderType:entryType
                                                 price:entryPrice
                                             stopPrice:0
                                           timeInForce:timeInForce];
    
    NSMutableDictionary *parentOrder = [entryOrder mutableCopy];
    parentOrder[@"orderStrategyType"] = @"TRIGGER";
    
    // 2. Child Orders Array
    NSMutableArray *childOrders = [NSMutableArray array];
    
    // 3. Stop Loss Child Order
    NSString *stopSide = [self getOppositeSide:side];
    NSDictionary *stopOrder = [self buildSimpleOrder:symbol
                                                 side:stopSide
                                             quantity:quantity
                                            orderType:@"STOP"
                                                price:0
                                            stopPrice:stopLossPrice
                                          timeInForce:timeInForce];
    
    NSMutableDictionary *stopChildOrder = [stopOrder mutableCopy];
    stopChildOrder[@"orderStrategyType"] = @"SINGLE";
    [childOrders addObject:stopChildOrder];
    
    // 4. Profit Target Child Order
    NSDictionary *targetOrder = [self buildSimpleOrder:symbol
                                                   side:stopSide
                                               quantity:quantity
                                              orderType:@"LIMIT"
                                                  price:profitTargetPrice
                                              stopPrice:0
                                            timeInForce:timeInForce];
    
    NSMutableDictionary *targetChildOrder = [targetOrder mutableCopy];
    targetChildOrder[@"orderStrategyType"] = @"SINGLE";
    [childOrders addObject:targetChildOrder];
    
    // 5. Link child orders with OCO relationship
    for (NSMutableDictionary *childOrder in childOrders) {
        childOrder[@"orderStrategyType"] = @"OCO";
    }
    
    parentOrder[@"childOrderStrategies"] = [childOrders copy];
    
    [orders addObject:parentOrder];
    
    NSLog(@"🔨 OrderBuilder: Built bracket order - Entry: %.2f, Stop: %.2f, Target: %.2f",
          entryPrice, stopLossPrice, profitTargetPrice);
    
    return [orders copy];
}

+ (NSArray<NSDictionary *> *)buildOCOOrder:(NSString *)symbol
                                      side:(NSString *)side
                                  quantity:(double)quantity
                                    price1:(double)price1
                                orderType1:(NSString *)orderType1
                                    price2:(double)price2
                                orderType2:(NSString *)orderType2
                               timeInForce:(NSString *)timeInForce {
    
    NSMutableArray *orders = [NSMutableArray array];
    
    // Build first order
    NSDictionary *order1 = [self buildSimpleOrder:symbol
                                             side:side
                                         quantity:quantity
                                        orderType:orderType1
                                            price:price1
                                        stopPrice:price1  // For stop orders
                                      timeInForce:timeInForce];
    
    NSMutableDictionary *ocoOrder1 = [order1 mutableCopy];
    ocoOrder1[@"orderStrategyType"] = @"OCO";
    
    // Build second order
    NSDictionary *order2 = [self buildSimpleOrder:symbol
                                             side:side
                                         quantity:quantity
                                        orderType:orderType2
                                            price:price2
                                        stopPrice:price2  // For stop orders
                                      timeInForce:timeInForce];
    
    NSMutableDictionary *ocoOrder2 = [order2 mutableCopy];
    ocoOrder2[@"orderStrategyType"] = @"OCO";
    
    // Link them together
    NSString *ocoId = [[NSUUID UUID] UUIDString];
    ocoOrder1[@"ocoId"] = ocoId;
    ocoOrder2[@"ocoId"] = ocoId;
    
    [orders addObject:ocoOrder1];
    [orders addObject:ocoOrder2];
    
    NSLog(@"🔨 OrderBuilder: Built OCO order - %@ %.2f OR %@ %.2f",
          orderType1, price1, orderType2, price2);
    
    return [orders copy];
}

+ (NSDictionary *)buildTrailingStopOrder:(NSString *)symbol
                                    side:(NSString *)side
                                quantity:(double)quantity
                             trailAmount:(double)trailAmount
                            isPercentage:(BOOL)isPercentage {
    
    NSMutableDictionary *order = [NSMutableDictionary dictionary];
    
    order[@"orderType"] = @"TRAILING_STOP";
    order[@"session"] = @"NORMAL";
    order[@"duration"] = @"GTC";  // Trailing stops typically GTC
    order[@"orderStrategyType"] = @"SINGLE";
    
    // Order leg
    NSMutableDictionary *orderLegCollection = [NSMutableDictionary dictionary];
    orderLegCollection[@"instruction"] = side;
    orderLegCollection[@"quantity"] = @(quantity);
    
    // Instrument
    NSMutableDictionary *instrument = [NSMutableDictionary dictionary];
    instrument[@"symbol"] = symbol;
    instrument[@"assetType"] = @"EQUITY";
    orderLegCollection[@"instrument"] = instrument;
    
    order[@"orderLegCollection"] = @[orderLegCollection];
    
    // Trailing stop parameters
    if (isPercentage) {
        order[@"trailPercent"] = @(trailAmount);
    } else {
        order[@"trailAmount"] = @(trailAmount);
    }
    
    NSLog(@"🔨 OrderBuilder: Built trailing stop - Trail: %.2f%@",
          trailAmount, isPercentage ? @"%" : @"$");
    
    return [order copy];
}

#pragma mark - Advanced Order Strategies

+ (NSArray<NSDictionary *> *)buildScaleInOrders:(NSString *)symbol
                                            side:(NSString *)side
                                   totalQuantity:(double)totalQuantity
                                    entryPrices:(NSArray<NSNumber *> *)entryPrices
                            quantityDistribution:(NSArray<NSNumber *> *)quantityDistribution
                                       orderType:(NSString *)orderType
                                     timeInForce:(NSString *)timeInForce {
    
    NSMutableArray *orders = [NSMutableArray array];
    
    if (entryPrices.count != quantityDistribution.count) {
        NSLog(@"❌ OrderBuilder: Scale-in prices and distribution count mismatch");
        return [orders copy];
    }
    
    for (NSInteger i = 0; i < entryPrices.count; i++) {
        double price = entryPrices[i].doubleValue;
        double distribution = quantityDistribution[i].doubleValue;
        double quantity = floor(totalQuantity * distribution);
        
        if (quantity > 0) {
            NSDictionary *scaleOrder = [self buildSimpleOrder:symbol
                                                         side:side
                                                     quantity:quantity
                                                    orderType:orderType
                                                        price:price
                                                    stopPrice:0
                                                  timeInForce:timeInForce];
            [orders addObject:scaleOrder];
        }
    }
    
    NSLog(@"🔨 OrderBuilder: Built %lu scale-in orders for %.0f shares",
          (unsigned long)orders.count, totalQuantity);
    
    return [orders copy];
}

+ (NSArray<NSDictionary *> *)buildScaleOutOrders:(NSString *)symbol
                                             side:(NSString *)side
                                    totalQuantity:(double)totalQuantity
                                     targetPrices:(NSArray<NSNumber *> *)targetPrices
                             quantityDistribution:(NSArray<NSNumber *> *)quantityDistribution
                                        orderType:(NSString *)orderType
                                      timeInForce:(NSString *)timeInForce {
    
    NSMutableArray *orders = [NSMutableArray array];
    
    if (targetPrices.count != quantityDistribution.count) {
        NSLog(@"❌ OrderBuilder: Scale-out prices and distribution count mismatch");
        return [orders copy];
    }
    
    for (NSInteger i = 0; i < targetPrices.count; i++) {
        double price = targetPrices[i].doubleValue;
        double distribution = quantityDistribution[i].doubleValue;
        double quantity = floor(totalQuantity * distribution);
        
        if (quantity > 0) {
            NSDictionary *scaleOrder = [self buildSimpleOrder:symbol
                                                         side:side
                                                     quantity:quantity
                                                    orderType:orderType
                                                        price:price
                                                    stopPrice:0
                                                  timeInForce:timeInForce];
            [orders addObject:scaleOrder];
        }
    }
    
    NSLog(@"🔨 OrderBuilder: Built %lu scale-out orders for %.0f shares",
          (unsigned long)orders.count, totalQuantity);
    
    return [orders copy];
}

#pragma mark - Order Validation

+ (BOOL)validateOrder:(NSDictionary *)orderData error:(NSError **)error {
    // Basic validation
    if (!orderData[@"orderLegCollection"] || ![orderData[@"orderLegCollection"] isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderValidation"
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Order must have order leg collection"}];
        }
        return NO;
    }
    
    NSArray *orderLegs = orderData[@"orderLegCollection"];
    if (orderLegs.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderValidation"
                                         code:2002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Order must have at least one leg"}];
        }
        return NO;
    }
    
    // Validate each order leg
    for (NSDictionary *leg in orderLegs) {
        if (!leg[@"instruction"] || !leg[@"quantity"] || !leg[@"instrument"]) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:2003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Order leg missing required fields"}];
            }
            return NO;
        }
        
        // Validate quantity
        NSNumber *quantity = leg[@"quantity"];
        if (quantity.doubleValue <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:2004
                                         userInfo:@{NSLocalizedDescriptionKey: @"Order quantity must be greater than zero"}];
            }
            return NO;
        }
        
        // Validate symbol
        NSDictionary *instrument = leg[@"instrument"];
        NSString *symbol = instrument[@"symbol"];
        if (!symbol || symbol.length == 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:2005
                                         userInfo:@{NSLocalizedDescriptionKey: @"Order must have valid symbol"}];
            }
            return NO;
        }
    }
    
    // Validate order type specific requirements
    NSString *orderType = orderData[@"orderType"];
    
    if ([orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        if (!orderData[@"price"] || [orderData[@"price"] doubleValue] <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:2006
                                         userInfo:@{NSLocalizedDescriptionKey: @"Limit orders must have valid price"}];
            }
            return NO;
        }
    }
    
    if ([orderType isEqualToString:@"STOP"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        if (!orderData[@"stopPrice"] || [orderData[@"stopPrice"] doubleValue] <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:2007
                                         userInfo:@{NSLocalizedDescriptionKey: @"Stop orders must have valid stop price"}];
            }
            return NO;
        }
    }
    
    return YES;
}

+ (BOOL)validateBracketOrder:(double)entryPrice
                   stopPrice:(double)stopPrice
                 targetPrice:(double)targetPrice
                        side:(NSString *)side
                       error:(NSError **)error {
    
    if (entryPrice <= 0 || stopPrice <= 0 || targetPrice <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderValidation"
                                         code:3001
                                     userInfo:@{NSLocalizedDescriptionKey: @"All prices must be greater than zero"}];
        }
        return NO;
    }
    
    if ([side hasPrefix:@"BUY"]) {
        // Long position: stop < entry < target
        if (stopPrice >= entryPrice) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:3002
                                         userInfo:@{NSLocalizedDescriptionKey: @"For BUY orders, stop price must be below entry price"}];
            }
            return NO;
        }
        
        if (targetPrice <= entryPrice) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:3003
                                         userInfo:@{NSLocalizedDescriptionKey: @"For BUY orders, target price must be above entry price"}];
            }
            return NO;
        }
    } else {
        // Short position: target < entry < stop
        if (stopPrice <= entryPrice) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:3004
                                         userInfo:@{NSLocalizedDescriptionKey: @"For SELL orders, stop price must be above entry price"}];
            }
            return NO;
        }
        
        if (targetPrice >= entryPrice) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:3005
                                         userInfo:@{NSLocalizedDescriptionKey: @"For SELL orders, target price must be below entry price"}];
            }
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Order Formatting

+ (NSString *)formatOrderDescription:(NSDictionary *)orderData {
    NSArray *orderLegs = orderData[@"orderLegCollection"];
    if (orderLegs.count == 0) return @"Invalid Order";
    
    NSDictionary *leg = orderLegs[0];
    NSDictionary *instrument = leg[@"instrument"];
    
    NSString *side = leg[@"instruction"];
    NSString *symbol = instrument[@"symbol"];
    NSNumber *quantity = leg[@"quantity"];
    NSString *orderType = orderData[@"orderType"];
    
    NSMutableString *description = [NSMutableString string];
    [description appendFormat:@"%@ %.0f %@ %@", side, quantity.doubleValue, symbol, orderType];
    
    if (orderData[@"price"]) {
        [description appendFormat:@" @ %.2f", [orderData[@"price"] doubleValue]];
    }
    
    if (orderData[@"stopPrice"]) {
        [description appendFormat:@" Stop: %.2f", [orderData[@"stopPrice"] doubleValue]];
    }
    
    return [description copy];
}

+ (NSString *)formatBracketOrderDescription:(NSArray<NSDictionary *> *)bracketOrders {
    if (bracketOrders.count == 0) return @"Empty Bracket Order";
    
    NSDictionary *parentOrder = bracketOrders[0];
    NSString *parentDescription = [self formatOrderDescription:parentOrder];
    
    NSMutableString *description = [NSMutableString string];
    [description appendString:@"Bracket Order:\n"];
    [description appendFormat:@"Entry: %@\n", parentDescription];
    
    NSArray *childOrders = parentOrder[@"childOrderStrategies"];
    for (NSDictionary *childOrder in childOrders) {
        NSString *childDescription = [self formatOrderDescription:childOrder];
        [description appendFormat:@"  └─ %@\n", childDescription];
    }
    
    return [description copy];
}

+ (NSString *)generateOrderPreview:(id)orderData portfolioValue:(double)portfolioValue {
    NSMutableString *preview = [NSMutableString string];
    
    if ([orderData isKindOfClass:[NSArray class]]) {
        // Multiple orders (bracket, OCO, etc.)
        NSArray *orders = (NSArray *)orderData;
        
        if (orders.count == 1) {
            NSDictionary *order = orders[0];
            if (order[@"childOrderStrategies"]) {
                // Bracket order
                [preview appendString:[self formatBracketOrderDescription:orders]];
            } else {
                // Single order in array
                [preview appendString:[self formatOrderDescription:order]];
            }
        } else {
            // Multiple separate orders
            [preview appendString:@"Multi-Order Strategy:\n"];
            for (NSInteger i = 0; i < orders.count; i++) {
                [preview appendFormat:@"%ld. %@\n", (long)(i + 1), [self formatOrderDescription:orders[i]]];
            }
        }
    } else if ([orderData isKindOfClass:[NSDictionary class]]) {
        // Single order
        [preview appendString:[self formatOrderDescription:(NSDictionary *)orderData]];
    }
    
    // Add risk analysis if portfolio value available
    if (portfolioValue > 0) {
        NSDictionary *riskMetrics = [self calculateOrderRiskMetrics:orderData currentPrice:0];
        if (riskMetrics[@"totalRisk"]) {
            double totalRisk = [riskMetrics[@"totalRisk"] doubleValue];
            double riskPercent = (totalRisk / portfolioValue) * 100.0;
            
            OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
            
            [preview appendString:@"\n--- Risk Analysis ---\n"];
            [preview appendFormat:@"Total Risk: %@\n", [calculator formatCurrency:totalRisk]];
            [preview appendFormat:@"Portfolio Risk: %@\n", [calculator formatPercentage:riskPercent]];
            
            if (riskMetrics[@"totalReward"]) {
                double totalReward = [riskMetrics[@"totalReward"] doubleValue];
                double rrr = totalReward / totalRisk;
                [preview appendFormat:@"Risk/Reward: %@\n", [calculator formatRiskRewardRatio:rrr]];
            }
        }
    }
    
    return [preview copy];
}

#pragma mark - Helper Methods

+ (NSString *)getOppositeSide:(NSString *)side {
    if ([side isEqualToString:@"BUY"]) {
        return @"SELL";
    } else if ([side isEqualToString:@"SELL"]) {
        return @"BUY";
    } else if ([side isEqualToString:@"SELL_SHORT"]) {
        return @"BUY_TO_COVER";
    } else if ([side isEqualToString:@"BUY_TO_COVER"]) {
        return @"SELL_SHORT";
    }
    
    return side;  // Default fallback
}

+ (NSDictionary *)calculateOrderRiskMetrics:(NSDictionary *)orderData currentPrice:(double)currentPrice {
    // This is a simplified implementation - would need more complex logic for different order types
    NSMutableDictionary *metrics = [NSMutableDictionary dictionary];
    
    // Extract basic order info
    NSArray *orderLegs = orderData[@"orderLegCollection"];
    if (orderLegs.count == 0) return [metrics copy];
    
    NSDictionary *leg = orderLegs[0];
    double quantity = [leg[@"quantity"] doubleValue];
    
    // Calculate risk based on order type and prices
    if (orderData[@"price"] && orderData[@"stopPrice"]) {
        double entryPrice = [orderData[@"price"] doubleValue];
        double stopPrice = [orderData[@"stopPrice"] doubleValue];
        
        double riskPerShare = fabs(entryPrice - stopPrice);
        double totalRisk = quantity * riskPerShare;
        
        metrics[@"totalRisk"] = @(totalRisk);
        metrics[@"riskPerShare"] = @(riskPerShare);
    }
    
    return [metrics copy];
}

#pragma mark - Order Presets

+ (NSArray<NSDictionary *> *)createScalpingPreset:(NSString *)symbol
                                              side:(NSString *)side
                                          quantity:(double)quantity
                                        entryPrice:(double)entryPrice
                                       stopPercent:(double)stopPercent
                                     targetPercent:(double)targetPercent {
    
    OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
    
    double stopPrice = [calculator calculateStopPriceFromPercent:stopPercent
                                                      entryPrice:entryPrice
                                                            side:side];
    
    double targetPrice = [calculator calculateTargetPriceFromPercent:targetPercent
                                                          entryPrice:entryPrice
                                                                side:side];
    
    return [self buildBracketOrder:symbol
                              side:side
                          quantity:quantity
                         entryType:@"LIMIT"
                        entryPrice:entryPrice
                     stopLossPrice:stopPrice
                 profitTargetPrice:targetPrice
                       timeInForce:@"DAY"];
}

+ (NSArray<NSDictionary *> *)createSwingTradingPreset:(NSString *)symbol
                                                 side:(NSString *)side
                                             quantity:(double)quantity
                                           entryPrice:(double)entryPrice
                                          stopPercent:(double)stopPercent
                                        targetPercent:(double)targetPercent {
    
    OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
    
    double stopPrice = [calculator calculateStopPriceFromPercent:stopPercent
                                                      entryPrice:entryPrice
                                                            side:side];
    
    double targetPrice = [calculator calculateTargetPriceFromPercent:targetPercent
                                                          entryPrice:entryPrice
                                                                side:side];
    
    return [self buildBracketOrder:symbol
                              side:side
                          quantity:quantity
                         entryType:@"LIMIT"
                        entryPrice:entryPrice
                     stopLossPrice:stopPrice
                 profitTargetPrice:targetPrice
                       timeInForce:@"GTC"];
}

+ (NSArray<NSDictionary *> *)createBreakoutPreset:(NSString *)symbol
                                             side:(NSString *)side
                                         quantity:(double)quantity
                                          dayHigh:(double)dayHigh
                                           dayLow:(double)dayLow
                                   breakoutOffset:(double)breakoutOffset
                                       stopOffset:(double)stopOffset
                                 targetMultiplier:(double)targetMultiplier {
    
    double dayRange = dayHigh - dayLow;
    
    double entryPrice;
    double stopPrice;
    double targetPrice;
    
    if ([side hasPrefix:@"BUY"]) {
        // Bullish breakout above day high
        entryPrice = dayHigh + breakoutOffset;
        stopPrice = dayLow - stopOffset;
        targetPrice = entryPrice + (dayRange * targetMultiplier);
    } else {
        // Bearish breakdown below day low
        entryPrice = dayLow - breakoutOffset;
        stopPrice = dayHigh + stopOffset;
        targetPrice = entryPrice - (dayRange * targetMultiplier);
    }
    
    return [self buildBracketOrder:symbol
                              side:side
                          quantity:quantity
                         entryType:@"STOP"
                        entryPrice:entryPrice
                     stopLossPrice:stopPrice
                 profitTargetPrice:targetPrice
                       timeInForce:@"DAY"];
}

@end
