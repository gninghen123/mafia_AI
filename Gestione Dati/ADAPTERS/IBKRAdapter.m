//
//  IBKRAdapter.m
//  TradingApp
//

#import "IBKRAdapter.h"
#import "MarketData.h"
#import "RuntimeModels.h"
#import "TradingRuntimeModels.h"
#import "CommonTypes.h"

@implementation IBKRAdapter

#pragma mark - DataSourceAdapter Protocol

- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol {
    MarketData *marketData = [[MarketData alloc] init];
    
    // Map IBKR quote fields to MarketData
    marketData.symbol = symbol;
    marketData.last = @([rawData[@"last"] doubleValue]);
    marketData.bid = @([rawData[@"bid"] doubleValue]);
    marketData.ask = @([rawData[@"ask"] doubleValue]);
    marketData.volume = @([rawData[@"volume"] longLongValue]);
    marketData.open = @([rawData[@"open"] doubleValue]);
    marketData.high = @([rawData[@"high"] doubleValue]);
    marketData.low = @([rawData[@"low"] doubleValue]);
    marketData.previousClose = @([rawData[@"close"] doubleValue]);
    
    // Calculate change and change percent
    double lastPrice = [marketData.last doubleValue];
    double previousClose = [marketData.previousClose doubleValue];
    if (previousClose > 0) {
        double change = lastPrice - previousClose;
        double changePercent = (change / previousClose) * 100.0;
        marketData.change = @(change);
        marketData.changePercent = @(changePercent);
    }
    
    // Set timestamp
    marketData.timestamp = rawData[@"timestamp"] ?: [NSDate date];
    
    NSLog(@"✅ IBKRAdapter: Standardized quote for %@ - Last: %.2f, Bid: %.2f, Ask: %.2f",
          symbol, lastPrice, [marketData.bid doubleValue], [marketData.ask doubleValue]);
    
    return marketData;
}

- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    if (![rawData isKindOfClass:[NSArray class]]) {
        NSLog(@"❌ IBKRAdapter: Expected NSArray for historical data, got %@", [rawData class]);
        return @[];
    }
    
    NSArray *rawBars = (NSArray *)rawData;
    NSMutableArray<HistoricalBarModel *> *runtimeBars = [NSMutableArray arrayWithCapacity:rawBars.count];
    
    for (NSDictionary *rawBar in rawBars) {
        if (![rawBar isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        HistoricalBarModel *runtimeBar = [[HistoricalBarModel alloc] init];
        
        // Map IBKR bar fields to HistoricalBarModel
        runtimeBar.symbol = symbol;
        runtimeBar.date = rawBar[@"date"] ?: [NSDate date];
        runtimeBar.open = [rawBar[@"open"] doubleValue];
        runtimeBar.high = [rawBar[@"high"] doubleValue];
        runtimeBar.low = [rawBar[@"low"] doubleValue];
        runtimeBar.close = [rawBar[@"close"] doubleValue];
        runtimeBar.volume = [rawBar[@"volume"] longLongValue];
        
        // Set default timeframe (should be determined by request parameters)
        runtimeBar.timeframe = BarTimeframeDaily;
        
        [runtimeBars addObject:runtimeBar];
    }
    
    // Sort by date (oldest first)
    [runtimeBars sortUsingComparator:^NSComparisonResult(HistoricalBarModel *bar1, HistoricalBarModel *bar2) {
        return [bar1.date compare:bar2.date];
    }];
    
    NSLog(@"✅ IBKRAdapter: Standardized %lu historical bars for %@",
          (unsigned long)runtimeBars.count, symbol);
    
    return [runtimeBars copy];
}

- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol {
    if (![rawData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ IBKRAdapter: Expected NSDictionary for order book data, got %@", [rawData class]);
        return @{};
    }
    
    NSDictionary *rawOrderBook = (NSDictionary *)rawData;
    
    // IBKR order book structure (simplified)
    NSArray *bids = rawOrderBook[@"bids"] ?: @[];
    NSArray *asks = rawOrderBook[@"asks"] ?: @[];
    
    NSMutableArray *standardizedBids = [NSMutableArray array];
    NSMutableArray *standardizedAsks = [NSMutableArray array];
    
    // Process bids
    for (NSDictionary *bid in bids) {
        if ([bid isKindOfClass:[NSDictionary class]]) {
            NSDictionary *standardizedBid = @{
                @"price": bid[@"price"] ?: @0,
                @"size": bid[@"size"] ?: @0,
                @"mpid": bid[@"mpid"] ?: @"",
                @"side": @"bid"
            };
            [standardizedBids addObject:standardizedBid];
        }
    }
    
    // Process asks
    for (NSDictionary *ask in asks) {
        if ([ask isKindOfClass:[NSDictionary class]]) {
            NSDictionary *standardizedAsk = @{
                @"price": ask[@"price"] ?: @0,
                @"size": ask[@"size"] ?: @0,
                @"mpid": ask[@"mpid"] ?: @"",
                @"side": @"ask"
            };
            [standardizedAsks addObject:standardizedAsk];
        }
    }
    
    NSDictionary *standardizedOrderBook = @{
        @"symbol": symbol,
        @"bids": [standardizedBids copy],
        @"asks": [standardizedAsks copy],
        @"timestamp": rawOrderBook[@"timestamp"] ?: [NSDate date]
    };
    
    NSLog(@"✅ IBKRAdapter: Standardized order book for %@ - %lu bids, %lu asks",
          symbol, (unsigned long)standardizedBids.count, (unsigned long)standardizedAsks.count);
    
    return standardizedOrderBook;
}

- (NSDictionary *)standardizeBatchQuotesData:(id)rawData forSymbols:(NSArray<NSString *> *)symbols {
    if (![rawData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ IBKRAdapter: Expected NSDictionary for batch quotes, got %@", [rawData class]);
        return @{};
    }
    
    NSDictionary *rawQuotes = (NSDictionary *)rawData;
    NSMutableDictionary *standardizedQuotes = [NSMutableDictionary dictionary];
    
    for (NSString *symbol in symbols) {
        NSDictionary *rawQuote = rawQuotes[symbol];
        if ([rawQuote isKindOfClass:[NSDictionary class]]) {
            MarketData *marketData = [self standardizeQuoteData:rawQuote forSymbol:symbol];
            standardizedQuotes[symbol] = marketData;
        }
    }
    
    NSLog(@"✅ IBKRAdapter: Standardized batch quotes for %lu symbols",
          (unsigned long)standardizedQuotes.count);
    
    return [standardizedQuotes copy];
}

- (AdvancedPositionModel *)standardizePositionData:(NSDictionary *)rawData {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedPositionModel *position = [[AdvancedPositionModel alloc] init];
    
    // Basic position info
    position.symbol = rawData[@"symbol"] ?: rawData[@"ticker"] ?: @"";
    position.accountId = rawData[@"accountId"] ?: rawData[@"acctId"] ?: @"";
    
    // Quantities - IBKR usa "position" field (positive = long, negative = short)
    double positionSize = [rawData[@"position"] doubleValue];
    position.quantity = positionSize;
    
    // Pricing and costs
    position.avgCost = [rawData[@"avgCost"] doubleValue] ?: [rawData[@"avgPrice"] doubleValue];
    position.currentPrice = [rawData[@"marketPrice"] doubleValue] ?: [rawData[@"mktPrice"] doubleValue];
    position.marketValue = [rawData[@"marketValue"] doubleValue] ?: [rawData[@"mktValue"] doubleValue];
    
    // If market value not provided, calculate it
    if (position.marketValue == 0 && position.currentPrice > 0) {
        position.marketValue = position.quantity * position.currentPrice;
    }
    
    // Calculate P&L
    double totalCost = position.quantity * position.avgCost;
    position.unrealizedPL = [rawData[@"unrealizedPL"] doubleValue] ?: (position.marketValue - totalCost);
    
    if (totalCost != 0) {
        position.unrealizedPLPercent = (position.unrealizedPL / ABS(totalCost)) * 100.0;
    }
    
    // Additional market data (if available in IBKR response)
    position.bidPrice = [rawData[@"bid"] doubleValue];
    position.askPrice = [rawData[@"ask"] doubleValue];
    position.dayHigh = [rawData[@"high"] doubleValue];
    position.dayLow = [rawData[@"low"] doubleValue];
    position.dayOpen = [rawData[@"open"] doubleValue];
    position.previousClose = [rawData[@"close"] doubleValue];
    position.volume = [rawData[@"volume"] integerValue];
    
    position.priceLastUpdated = [NSDate date];
    
    NSLog(@"✅ IBKRAdapter: Created AdvancedPositionModel for %@ - %.0f shares @ $%.2f (P&L: $%.2f)",
          position.symbol, position.quantity, position.avgCost, position.unrealizedPL);
    
    return position;
}

- (AdvancedOrderModel *)standardizeOrderData:(NSDictionary *)rawData {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedOrderModel *order = [[AdvancedOrderModel alloc] init];
    
    // Basic order info
    order.orderId = rawData[@"orderId"] ?: rawData[@"order_id"] ?: @"";
    order.accountId = rawData[@"accountId"] ?: rawData[@"account"] ?: @"";
    order.symbol = rawData[@"symbol"] ?: rawData[@"ticker"] ?: @"";
    
    // Order type and side mapping from IBKR
    NSString *orderType = rawData[@"orderType"] ?: @"MKT";
    order.orderType = [self mapIBKROrderTypeToStandard:orderType];
    
    NSString *action = rawData[@"action"] ?: @"BUY";
    order.side = [action isEqualToString:@"BUY"] ? @"BUY" : @"SELL";
    
    // Order status mapping
    NSString *status = rawData[@"status"] ?: @"Submitted";
    order.status = [self mapIBKRStatusToStandard:status];
    
    // Time in force
    NSString *tif = rawData[@"tif"] ?: @"DAY";
    order.timeInForce = [tif isEqualToString:@"GTC"] ? @"GTC" : @"DAY";
    
    // Quantities and prices
    order.quantity = [rawData[@"totalQuantity"] doubleValue] ?: [rawData[@"quantity"] doubleValue];
    order.filledQuantity = [rawData[@"filled"] doubleValue] ?: [rawData[@"filledQuantity"] doubleValue];
    order.price = [rawData[@"lmtPrice"] doubleValue] ?: [rawData[@"price"] doubleValue];
    order.stopPrice = [rawData[@"auxPrice"] doubleValue] ?: [rawData[@"stopPrice"] doubleValue];
    order.avgFillPrice = [rawData[@"avgFillPrice"] doubleValue];
    
    // Dates - IBKR typically uses Unix timestamps
    NSNumber *submittedTime = rawData[@"submittedAt"] ?: rawData[@"created_time"];
    if (submittedTime) {
        order.createdDate = [NSDate dateWithTimeIntervalSince1970:[submittedTime doubleValue]];
    } else {
        order.createdDate = [NSDate date];
    }
    
    NSNumber *modifiedTime = rawData[@"modifiedAt"] ?: rawData[@"updated_time"];
    if (modifiedTime) {
        order.updatedDate = [NSDate dateWithTimeIntervalSince1970:[modifiedTime doubleValue]];
    } else {
        order.updatedDate = order.createdDate;
    }
    
    // Additional fields
    order.instruction = order.side; // Use side as instruction
    order.orderStrategy = @"SINGLE"; // IBKR default
    
    // Current market data (if available)
    order.currentBidPrice = [rawData[@"currentBid"] doubleValue];
    order.currentAskPrice = [rawData[@"currentAsk"] doubleValue];
    
    NSLog(@"✅ IBKRAdapter: Created AdvancedOrderModel %@ for %@ - %@ %.0f shares @ $%.2f",
          order.orderId, order.symbol, order.side, order.quantity, order.price);
    
    return order;
}

- (NSArray<AccountModel *> *)standardizeAccountData:(id)rawData {
    NSMutableArray<AccountModel *> *accounts = [NSMutableArray array];
    
    if ([rawData isKindOfClass:[NSArray class]]) {
        // Array of account IDs from IBKR API (common format)
        NSArray *accountIds = (NSArray *)rawData;
        
        for (id accountItem in accountIds) {
            if ([accountItem isKindOfClass:[NSString class]]) {
                // Simple account ID string
                AccountModel *account = [self createAccountModelFromId:(NSString *)accountItem];
                if (account) {
                    [accounts addObject:account];
                }
            } else if ([accountItem isKindOfClass:[NSDictionary class]]) {
                // Account dictionary with details
                AccountModel *account = [self createAccountModelFromDictionary:(NSDictionary *)accountItem];
                if (account) {
                    [accounts addObject:account];
                }
            }
        }
        
    } else if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *accountData = (NSDictionary *)rawData;
        
        // Check if it's a wrapper with account IDs
        if (accountData[@"accounts"] || accountData[@"accountIds"]) {
            NSArray *accountIds = accountData[@"accounts"] ?: accountData[@"accountIds"];
            return [self standardizeAccountData:accountIds];
        } else {
            // Single account data dictionary
            AccountModel *account = [self createAccountModelFromDictionary:accountData];
            if (account) {
                [accounts addObject:account];
            }
        }
    }
    
    NSLog(@"✅ IBKRAdapter: Created %lu AccountModel objects", (unsigned long)accounts.count);
    return [accounts copy];
}

#pragma mark - Helper Methods

- (AccountModel *)createAccountModelFromId:(NSString *)accountId {
    if (!accountId || accountId.length == 0) {
        return nil;
    }
    
    AccountModel *account = [[AccountModel alloc] init];
    account.accountId = accountId;
    account.accountType = @"UNKNOWN"; // IBKR doesn't provide type in simple ID list
    account.brokerName = @"IBKR";
    account.displayName = [NSString stringWithFormat:@"IBKR-%@", accountId];
    account.isConnected = YES;
    account.isPrimary = NO; // Will be determined later
    account.lastUpdated = [NSDate date];
    
    NSLog(@"✅ IBKRAdapter: Created AccountModel from ID: %@", accountId);
    return account;
}

- (AccountModel *)createAccountModelFromDictionary:(NSDictionary *)accountDict {
    if (!accountDict || ![accountDict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AccountModel *account = [[AccountModel alloc] init];
    
    // Extract account ID from various possible keys
    account.accountId = accountDict[@"accountId"] ?: accountDict[@"account"] ?: accountDict[@"id"] ?: @"";
    
    // Map account type (IBKR specific types)
    NSString *accountType = accountDict[@"type"] ?: accountDict[@"accountType"];
    if ([accountType isEqualToString:@"INDIVIDUAL"]) {
        account.accountType = @"CASH";
    } else if ([accountType isEqualToString:@"MARGIN"]) {
        account.accountType = @"MARGIN";
    } else {
        account.accountType = accountType ?: @"UNKNOWN";
    }
    
    account.brokerName = @"IBKR";
    account.displayName = accountDict[@"displayName"] ?: [NSString stringWithFormat:@"IBKR-%@", account.accountId];
    account.isConnected = [accountDict[@"isConnected"] boolValue] ? YES : YES; // Default to YES
    account.isPrimary = [accountDict[@"isPrimary"] boolValue];
    account.lastUpdated = [NSDate date];
    
    NSLog(@"✅ IBKRAdapter: Created AccountModel %@ (%@)", account.accountId, account.accountType);
    return account;
}

- (NSString *)mapIBKROrderTypeToStandard:(NSString *)ibkrOrderType {
    if ([ibkrOrderType isEqualToString:@"MKT"]) {
        return @"MARKET";
    } else if ([ibkrOrderType isEqualToString:@"LMT"]) {
        return @"LIMIT";
    } else if ([ibkrOrderType isEqualToString:@"STP"]) {
        return @"STOP";
    } else if ([ibkrOrderType isEqualToString:@"STP_LMT"]) {
        return @"STOP_LIMIT";
    }
    return ibkrOrderType; // Return as-is if no mapping found
}

- (NSString *)mapIBKRStatusToStandard:(NSString *)ibkrStatus {
    if ([ibkrStatus isEqualToString:@"Submitted"] || [ibkrStatus isEqualToString:@"PendingSubmit"]) {
        return @"PENDING";
    } else if ([ibkrStatus isEqualToString:@"PreSubmitted"]) {
        return @"OPEN";
    } else if ([ibkrStatus isEqualToString:@"Filled"]) {
        return @"FILLED";
    } else if ([ibkrStatus isEqualToString:@"Cancelled"]) {
        return @"CANCELLED";
    } else if ([ibkrStatus isEqualToString:@"ApiCancelled"]) {
        return @"CANCELLED";
    } else if ([ibkrStatus isEqualToString:@"Inactive"]) {
        return @"REJECTED";
    }
    return ibkrStatus; // Return as-is if no mapping found
}

#pragma mark - DataSourceAdapter Optional

- (NSString *)sourceName {
    return @"Interactive Brokers";
}

@end
