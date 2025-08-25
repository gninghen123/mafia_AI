
//
//  IBKRAdapter.m
//  TradingApp
//

#import "IBKRAdapter.h"
#import "MarketData.h"
#import "RuntimeModels.h"
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
        runtimeBar.timeframe = BarTimeframe1Day;
        
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

- (id)standardizePositionData:(NSDictionary *)rawData {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    // Convert IBKR position data to standard format compatibile con Schwab
    NSMutableDictionary *standardizedPosition = [NSMutableDictionary dictionary];
    
    // Basic position info
    standardizedPosition[@"symbol"] = rawData[@"symbol"] ?: rawData[@"ticker"] ?: @"";
    standardizedPosition[@"accountId"] = rawData[@"accountId"] ?: @"";
    standardizedPosition[@"accountNumber"] = rawData[@"accountId"] ?: @""; // Compatibility
    
    // Quantities - IBKR usa "position" mentre Schwab usa longQuantity/shortQuantity
    double position = [rawData[@"position"] doubleValue];
    if (position >= 0) {
        standardizedPosition[@"longQuantity"] = @(position);
        standardizedPosition[@"shortQuantity"] = @0;
    } else {
        standardizedPosition[@"longQuantity"] = @0;
        standardizedPosition[@"shortQuantity"] = @(ABS(position));
    }
    
    // Pricing and costs
    standardizedPosition[@"averagePrice"] = rawData[@"avgCost"] ?: rawData[@"avgPrice"] ?: @0;
    standardizedPosition[@"averageCost"] = rawData[@"avgCost"] ?: rawData[@"avgPrice"] ?: @0;
    standardizedPosition[@"marketValue"] = rawData[@"marketValue"] ?: rawData[@"mktValue"] ?: @0;
    standardizedPosition[@"currentPrice"] = rawData[@"marketPrice"] ?: rawData[@"mktPrice"] ?: @0;
    
    // P&L information
    standardizedPosition[@"unrealizedPnL"] = rawData[@"unrealizedPL"] ?: rawData[@"unrealizedPnl"] ?: @0;
    standardizedPosition[@"realizedPnL"] = rawData[@"realizedPL"] ?: rawData[@"realizedPnl"] ?: @0;
    
    // IBKR specific fields (mantenuti per compatibilità)
    standardizedPosition[@"contractId"] = rawData[@"conid"] ?: @0;
    standardizedPosition[@"currency"] = rawData[@"currency"] ?: @"USD";
    
    // Instrument info (formato compatibile Schwab)
    NSDictionary *instrument = @{
        @"symbol": standardizedPosition[@"symbol"],
        @"cusip": @"", // IBKR non fornisce CUSIP tipicamente
        @"type": @"EQUITY" // Assume equity per ora
    };
    standardizedPosition[@"instrument"] = instrument;
    
    NSLog(@"✅ IBKRAdapter: Standardized position for %@ - Position: %.0f, Market Value: $%.2f",
          standardizedPosition[@"symbol"], position, [standardizedPosition[@"marketValue"] doubleValue]);
    
    return [standardizedPosition copy];
}

- (id)standardizeOrderData:(NSDictionary *)rawData {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    // Convert IBKR order data to standard format compatibile con Schwab
    NSMutableDictionary *standardizedOrder = [NSMutableDictionary dictionary];
    
    // Basic order identification
    standardizedOrder[@"orderId"] = [rawData[@"orderId"] stringValue] ?: @"";
    standardizedOrder[@"accountNumber"] = rawData[@"accountId"] ?: rawData[@"acct"] ?: @"";
    standardizedOrder[@"accountId"] = rawData[@"accountId"] ?: rawData[@"acct"] ?: @""; // Compatibility
    
    // Order status and type
    standardizedOrder[@"status"] = rawData[@"status"] ?: @"";
    standardizedOrder[@"orderType"] = rawData[@"orderType"] ?: @"";
    standardizedOrder[@"duration"] = rawData[@"timeInForce"] ?: @"DAY"; // Schwab usa "duration"
    
    // Pricing
    standardizedOrder[@"price"] = rawData[@"limitPrice"] ?: rawData[@"price"] ?: @0;
    standardizedOrder[@"stopPrice"] = rawData[@"stopPrice"] ?: @0;
    
    // Quantities and fills
    standardizedOrder[@"filledQuantity"] = rawData[@"filledQuantity"] ?: @0;
    standardizedOrder[@"remainingQuantity"] = rawData[@"remainingQuantity"] ?: @0;
    standardizedOrder[@"avgFillPrice"] = rawData[@"avgPrice"] ?: @0;
    
    // Timestamps
    if (rawData[@"submittedTime"]) {
        // Converti timestamp IBKR a formato Schwab
        NSDate *submittedDate;
        if ([rawData[@"submittedTime"] isKindOfClass:[NSNumber class]]) {
            submittedDate = [NSDate dateWithTimeIntervalSince1970:[rawData[@"submittedTime"] doubleValue]];
        } else if ([rawData[@"submittedTime"] isKindOfClass:[NSString class]]) {
            // Try to parse string timestamp
            submittedDate = [NSDate date]; // Fallback
        } else {
            submittedDate = [NSDate date];
        }
        
        // Formato Schwab timestamp
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        standardizedOrder[@"enteredTime"] = [formatter stringFromDate:submittedDate];
    }
    
    // Order legs (formato Schwab) - IBKR ha struttura diversa
    NSString *symbol = rawData[@"symbol"] ?: rawData[@"ticker"] ?: @"";
    NSString *side = rawData[@"side"] ?: @""; // BUY/SELL
    double quantity = [rawData[@"totalQuantity"] doubleValue];
    
    if (symbol.length > 0) {
        NSDictionary *instrument = @{
            @"symbol": symbol,
            @"cusip": @"", // IBKR non fornisce CUSIP
            @"type": @"EQUITY"
        };
        
        NSDictionary *orderLeg = @{
            @"instruction": side, // BUY/SELL
            @"quantity": @(quantity),
            @"instrument": instrument
        };
        
        standardizedOrder[@"orderLegCollection"] = @[orderLeg];
    }
    
    // IBKR specific fields (mantenuti per referenza)
    standardizedOrder[@"permId"] = rawData[@"permId"] ?: @0;
    standardizedOrder[@"conid"] = rawData[@"conid"] ?: @0;
    
    NSLog(@"✅ IBKRAdapter: Standardized order %@ for %@ - %@ %.0f shares @ $%.2f",
          standardizedOrder[@"orderId"], symbol, side, quantity, [standardizedOrder[@"price"] doubleValue]);
    
    return [standardizedOrder copy];
}


#pragma mark - DataSourceAdapter Optional

- (NSString *)sourceName {
    return @"Interactive Brokers";
}

- (NSDictionary *)standardizeAccountData:(id)rawData {
    if ([rawData isKindOfClass:[NSArray class]]) {
        // Array di account IDs da getAccountsWithCompletion
        NSArray *accountIds = (NSArray *)rawData;
        NSMutableArray *standardizedAccounts = [NSMutableArray array];
        
        for (NSString *accountId in accountIds) {
            if ([accountId isKindOfClass:[NSString class]]) {
                NSDictionary *standardAccount = @{
                    @"accountId": accountId,
                    @"accountNumber": accountId, // Compatibility con formato Schwab
                    @"type": @"UNKNOWN", // IBKR non fornisce tipo nell'elenco
                    @"brokerName": @"IBKR",
                    @"isConnected": @YES,
                    @"lastUpdated": [NSDate date]
                };
                [standardizedAccounts addObject:standardAccount];
            }
        }
        
        return @{@"accounts": [standardizedAccounts copy]};
        
    } else if ([rawData isKindOfClass:[NSDictionary class]]) {
        // Singolo account summary da getAccountSummary
        NSDictionary *rawAccount = (NSDictionary *)rawData;
        
        NSDictionary *standardAccount = @{
            @"accountId": rawAccount[@"AccountCode"] ?: @"",
            @"accountNumber": rawAccount[@"AccountCode"] ?: @"", // Compatibility
            @"type": @"UNKNOWN", // IBKR account summary non include tipo
            @"brokerName": @"IBKR",
            @"isConnected": @YES,
            @"lastUpdated": [NSDate date],
            
            // Balance information
            @"currentBalances": @{
                @"liquidationValue": rawAccount[@"NetLiquidation"] ?: @0,
                @"totalValue": rawAccount[@"NetLiquidation"] ?: @0,
                @"cashBalance": rawAccount[@"TotalCashValue"] ?: @0,
                @"buyingPower": rawAccount[@"BuyingPower"] ?: @0,
                @"dayPL": @([rawAccount[@"UnrealizedPnL"] doubleValue] + [rawAccount[@"RealizedPnL"] doubleValue]),
                @"marginUsed": rawAccount[@"InitMarginReq"] ?: @0
            }
        };
        
        return standardAccount;
    }
    
    NSLog(@"❌ IBKRAdapter: Unexpected account data format: %@", [rawData class]);
    return @{};
}

@end
