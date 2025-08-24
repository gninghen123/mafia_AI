//
//  TradingRuntimeModels.m
//  TradingApp
//
//  Implementation of enhanced runtime models for advanced trading functionality
//

#import "TradingRuntimeModels.h"

#pragma mark - Account Model Implementation

@implementation AccountModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _accountId = @"";
        _accountType = @"CASH";
        _brokerName = @"UNKNOWN";
        _displayName = @"";
        _isConnected = NO;
        _isPrimary = NO;
        _lastUpdated = [NSDate date];
    }
    return self;
}

- (NSString *)formattedDisplayName {
    if (self.displayName && self.displayName.length > 0) {
        return self.displayName;
    }
    
    // Generate display name from broker and account
    if (self.accountId.length >= 4) {
        NSString *lastFour = [self.accountId substringFromIndex:self.accountId.length - 4];
        return [NSString stringWithFormat:@"%@-****%@", self.brokerName, lastFour];
    }
    
    return [NSString stringWithFormat:@"%@-%@", self.brokerName, self.accountId];
}

- (NSColor *)connectionStatusColor {
    return self.isConnected ? [NSColor systemGreenColor] : [NSColor systemRedColor];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"AccountModel<%@: %@ (%@)>",
            self.brokerName, self.formattedDisplayName, self.isConnected ? @"Connected" : @"Disconnected"];
}

@end

#pragma mark - Portfolio Summary Model Implementation

@implementation PortfolioSummaryModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _accountId = @"";
        _brokerName = @"UNKNOWN";
        _totalValue = 0.0;
        _dayPL = 0.0;
        _dayPLPercent = 0.0;
        _buyingPower = 0.0;
        _cashBalance = 0.0;
        _marginUsed = 0.0;
        _dayTradesLeft = 3; // Default for non-PDT accounts
        _lastUpdated = [NSDate date];
    }
    return self;
}

- (double)totalEquity {
    return self.totalValue + self.cashBalance;
}

- (double)marginAvailable {
    return self.buyingPower - self.marginUsed;
}

- (BOOL)isPDTRestricted {
    return self.dayTradesLeft <= 0;
}

- (NSString *)formattedTotalValue {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    return [formatter stringFromNumber:@(self.totalValue)];
}

- (NSString *)formattedDayPL {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    NSString *plString = [formatter stringFromNumber:@(self.dayPL)];
    
    if (self.dayPL >= 0) {
        return [NSString stringWithFormat:@"+%@", plString];
    }
    return plString;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"PortfolioSummary<%@: $%.2f (%.2f%%)>",
            self.accountId, self.totalValue, self.dayPLPercent];
}

@end

#pragma mark - Advanced Position Model Implementation

@implementation AdvancedPositionModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _symbol = @"";
        _accountId = @"";
        _quantity = 0.0;
        _avgCost = 0.0;
        _currentPrice = 0.0;
        _bidPrice = 0.0;
        _askPrice = 0.0;
        _dayHigh = 0.0;
        _dayLow = 0.0;
        _dayOpen = 0.0;
        _previousClose = 0.0;
        _marketValue = 0.0;
        _unrealizedPL = 0.0;
        _unrealizedPLPercent = 0.0;
        _volume = 0;
        _priceLastUpdated = [NSDate date];
    }
    return self;
}

- (BOOL)isLongPosition {
    return self.quantity > 0;
}

- (BOOL)isShortPosition {
    return self.quantity < 0;
}

- (double)riskPercentageOfPortfolio:(double)totalPortfolioValue {
    if (totalPortfolioValue <= 0) return 0.0;
    return (fabs(self.marketValue) / totalPortfolioValue) * 100.0;
}

- (double)sharesNeededForPercentOfPortfolio:(double)percent portfolioValue:(double)totalValue {
    if (self.currentPrice <= 0 || totalValue <= 0) return 0.0;
    double dollarAmount = totalValue * (percent / 100.0);
    return floor(dollarAmount / self.currentPrice);
}

- (double)sharesNeededForPercentOfCash:(double)percent cashAvailable:(double)cash {
    if (self.currentPrice <= 0 || cash <= 0) return 0.0;
    double dollarAmount = cash * (percent / 100.0);
    return floor(dollarAmount / self.currentPrice);
}

- (double)sharesNeededForDollarAmount:(double)dollarAmount {
    if (self.currentPrice <= 0) return 0.0;
    return floor(dollarAmount / self.currentPrice);
}

- (NSString *)formattedQuantity {
    return [NSString stringWithFormat:@"%.0f", fabs(self.quantity)];
}

- (NSString *)formattedMarketValue {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    return [formatter stringFromNumber:@(self.marketValue)];
}

- (NSString *)formattedUnrealizedPL {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    NSString *plString = [formatter stringFromNumber:@(self.unrealizedPL)];
    
    if (self.unrealizedPL >= 0) {
        return [NSString stringWithFormat:@"+%@", plString];
    }
    return plString;
}

- (NSString *)formattedBidAsk {
    if (self.bidPrice > 0 && self.askPrice > 0) {
        return [NSString stringWithFormat:@"%.2f / %.2f", self.bidPrice, self.askPrice];
    }
    return @"-- / --";
}

- (NSColor *)plColor {
    if (self.unrealizedPL > 0) {
        return [NSColor systemGreenColor];
    } else if (self.unrealizedPL < 0) {
        return [NSColor systemRedColor];
    }
    return [NSColor labelColor];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Position<%@: %.0f @ $%.2f = $%.2f (P&L: $%.2f)>",
            self.symbol, self.quantity, self.currentPrice, self.marketValue, self.unrealizedPL];
}

@end

#pragma mark - Advanced Order Model Implementation

@implementation AdvancedOrderModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _orderId = @"";
        _accountId = @"";
        _symbol = @"";
        _orderType = @"MARKET";
        _side = @"BUY";
        _status = @"PENDING";
        _timeInForce = @"DAY";
        _quantity = 0.0;
        _filledQuantity = 0.0;
        _price = 0.0;
        _stopPrice = 0.0;
        _avgFillPrice = 0.0;
        _createdDate = [NSDate date];
        _updatedDate = [NSDate date];
        _instruction = @"";
        _linkedOrderIds = @[];
        _parentOrderId = nil;
        _isChildOrder = NO;
        _orderStrategy = @"SINGLE";
        _currentBidPrice = 0.0;
        _currentAskPrice = 0.0;
        _dayHigh = 0.0;
        _dayLow = 0.0;
    }
    return self;
}

- (BOOL)isActive {
    return [self.status isEqualToString:@"OPEN"] || [self.status isEqualToString:@"PENDING"];
}

- (BOOL)isPending {
    return [self.status isEqualToString:@"PENDING"];
}

- (BOOL)isCompleted {
    return [self.status isEqualToString:@"FILLED"];
}

- (BOOL)isCancelled {
    return [self.status isEqualToString:@"CANCELLED"] || [self.status isEqualToString:@"REJECTED"];
}

- (BOOL)isPartiallyFilled {
    return self.filledQuantity > 0 && self.filledQuantity < self.quantity;
}

- (double)remainingQuantity {
    return self.quantity - self.filledQuantity;
}

- (double)distanceFromCurrentPrice:(double)currentPrice {
    if (currentPrice <= 0 || self.price <= 0) return 0.0;
    return fabs(self.price - currentPrice);
}

- (NSString *)riskRewardRatioStringWithStopPrice:(double)stopPrice targetPrice:(double)targetPrice {
    if (self.price <= 0 || stopPrice <= 0 || targetPrice <= 0) return @"N/A";
    
    double risk = fabs(self.price - stopPrice);
    double reward = fabs(targetPrice - self.price);
    
    if (risk <= 0) return @"N/A";
    
    double ratio = reward / risk;
    return [NSString stringWithFormat:@"%.2f:1", ratio];
}

- (NSString *)formattedQuantity {
    if (self.filledQuantity > 0 && self.filledQuantity < self.quantity) {
        return [NSString stringWithFormat:@"%.0f/%.0f", self.filledQuantity, self.quantity];
    }
    return [NSString stringWithFormat:@"%.0f", self.quantity];
}

- (NSString *)formattedPrice {
    if (self.price > 0) {
        return [NSString stringWithFormat:@"$%.2f", self.price];
    }
    return @"MARKET";
}

- (NSString *)formattedStatus {
    if ([self isPartiallyFilled]) {
        return [NSString stringWithFormat:@"%@ (%.0f%%)", self.status, (self.filledQuantity / self.quantity) * 100.0];
    }
    return self.status;
}

- (NSString *)formattedCreatedDate {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MM/dd HH:mm";
    return [formatter stringFromDate:self.createdDate];
}

- (NSColor *)statusColor {
    if ([self.status isEqualToString:@"FILLED"]) {
        return [NSColor systemGreenColor];
    } else if ([self.status isEqualToString:@"CANCELLED"] || [self.status isEqualToString:@"REJECTED"]) {
        return [NSColor systemRedColor];
    } else if ([self.status isEqualToString:@"PENDING"]) {
        return [NSColor systemOrangeColor];
    }
    return [NSColor labelColor];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Order<%@: %@ %.0f %@ @ %@ (%@)>",
            self.orderId, self.side, self.quantity, self.symbol, [self formattedPrice], self.status];
}

@end

#pragma mark - Order Book Level Implementation

@implementation OrderBookLevel

- (instancetype)init {
    self = [super init];
    if (self) {
        _price = 0.0;
        _size = 0;
        _orderCount = 0;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Level<$%.2f: %ld @ %ld orders>",
            self.price, (long)self.size, (long)self.orderCount];
}

@end

#pragma mark - Trading Quote Model Implementation

@implementation TradingQuoteModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _bidSize = 0.0;
        _askSize = 0.0;
        _topBids = @[];
        _topAsks = @[];
        _vwap = 0.0;
        _atr14 = 0.0;
    }
    return self;
}

- (double)bidAskSpread {
    if (self.bid && self.ask) {
        return self.ask.doubleValue - self.bid.doubleValue;
    }
    return 0.0;
}

- (double)bidAskSpreadPercent {
    double spread = [self bidAskSpread];
    if (spread > 0 && self.last && self.last.doubleValue > 0) {
        return (spread / self.last.doubleValue) * 100.0;
    }
    return 0.0;
}

- (NSInteger)totalBidSize {
    NSInteger total = (NSInteger)self.bidSize;
    for (OrderBookLevel *level in self.topBids) {
        total += level.size;
    }
    return total;
}

- (NSInteger)totalAskSize {
    NSInteger total = (NSInteger)self.askSize;
    for (OrderBookLevel *level in self.topAsks) {
        total += level.size;
    }
    return total;
}

- (double)level2Imbalance {
    NSInteger bidSize = [self totalBidSize];
    NSInteger askSize = [self totalAskSize];
    NSInteger totalSize = bidSize + askSize;
    
    if (totalSize > 0) {
        return ((double)bidSize - (double)askSize) / (double)totalSize;
    }
    return 0.0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"TradingQuote<%@: $%.2f (%.2f x %.2f) VWAP: $%.2f>",
            self.symbol, self.last.doubleValue,
            self.bid ? self.bid.doubleValue : 0.0,
            self.ask ? self.ask.doubleValue : 0.0,
            self.vwap];
}

@end
