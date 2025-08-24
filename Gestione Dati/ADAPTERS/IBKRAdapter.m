
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
    marketData.last = [rawData[@"last"] doubleValue];
    marketData.bid = [rawData[@"bid"] doubleValue];
    marketData.ask = [rawData[@"ask"] doubleValue];
    marketData.volume = [rawData[@"volume"] longLongValue];
    marketData.open = [rawData[@"open"] doubleValue];
    marketData.high = [rawData[@"high"] doubleValue];
    marketData.low = [rawData[@"low"] doubleValue];
    marketData.previousClose = [rawData[@"close"] doubleValue];
    
    // Calculate change and change percent
    if (marketData.previousClose > 0) {
        marketData.change = marketData.last - marketData.previousClose;
        marketData.changePercent = (marketData.change / marketData.previousClose) * 100.0;
    }
    
    // Set timestamp
    marketData.marketTime = rawData[@"timestamp"] ?: [NSDate date];
    
    NSLog(@"✅ IBKRAdapter: Standardized quote for %@ - Last: %.2f, Bid: %.2f, Ask: %.2f",
          symbol, marketData.last, marketData.bid, marketData.ask);
    
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
    // Convert IBKR position data to standard format
    NSMutableDictionary *standardizedPosition = [NSMutableDictionary dictionary];
    
    standardizedPosition[@"symbol"] = rawData[@"contract"][@"symbol"] ?: @"";
    standardizedPosition[@"quantity"] = rawData[@"position"] ?: @0;
    standardizedPosition[@"averageCost"] = rawData[@"avgCost"] ?: @0;
    standardizedPosition[@"marketValue"] = rawData[@"marketValue"] ?: @0;
    standardizedPosition[@"unrealizedPnL"] = rawData[@"unrealizedPNL"] ?: @0;
    standardizedPosition[@"realizedPnL"] = rawData[@"realizedPNL"] ?: @0;
    standardizedPosition[@"account"] = rawData[@"account"] ?: @"";
    
    // Contract details
    NSDictionary *contract = rawData[@"contract"];
    if ([contract isKindOfClass:[NSDictionary class]]) {
        standardizedPosition[@"contractId"] = contract[@"conId"] ?: @0;
        standardizedPosition[@"secType"] = contract[@"secType"] ?: @"STK";
        standardizedPosition[@"exchange"] = contract[@"exchange"] ?: @"";
        standardizedPosition[@"currency"] = contract[@"currency"] ?: @"USD";
    }
    
    return [standardizedPosition copy];
}

- (id)standardizeOrderData:(NSDictionary *)rawData {
    // Convert IBKR order data to standard format
    NSMutableDictionary *standardizedOrder = [NSMutableDictionary dictionary];
    
    // Order identification
    standardizedOrder[@"orderId"] = rawData[@"orderId"] ?: @0;
    standardizedOrder[@"permId"] = rawData[@"permId"] ?: @0;
    standardizedOrder[@"clientId"] = rawData[@"clientId"] ?: @0;
    
    // Contract info
    NSDictionary *contract = rawData[@"contract"];
    if ([contract isKindOfClass:[NSDictionary class]]) {
        standardizedOrder[@"symbol"] = contract[@"symbol"] ?: @"";
        standardizedOrder[@"secType"] = contract[@"secType"] ?: @"STK";
        standardizedOrder[@"exchange"] = contract[@"exchange"] ?: @"";
        standardizedOrder[@"currency"] = contract[@"currency"] ?: @"USD";
    }
    
    // Order details
    NSDictionary *order = rawData[@"order"];
    if ([order isKindOfClass:[NSDictionary class]]) {
        standardizedOrder[@"action"] = order[@"action"] ?: @""; // BUY/SELL
        standardizedOrder[@"orderType"] = order[@"orderType"] ?: @""; // MKT/LMT/STP
        standardizedOrder[@"totalQuantity"] = order[@"totalQuantity"] ?: @0;
        standardizedOrder[@"lmtPrice"] = order[@"lmtPrice"] ?: @0;
        standardizedOrder[@"auxPrice"] = order[@"auxPrice"] ?: @0; // Stop price
        standardizedOrder[@"timeInForce"] = order[@"tif"] ?: @"DAY";
    }
    
    // Order status
    NSDictionary *orderStatus = rawData[@"orderStatus"];
    if ([orderStatus isKindOfClass:[NSDictionary class]]) {
        standardizedOrder[@"status"] = orderStatus[@"status"] ?: @"";
        standardizedOrder[@"filled"] = orderStatus[@"filled"] ?: @0;
        standardizedOrder[@"remaining"] = orderStatus[@"remaining"] ?: @0;
        standardizedOrder[@"avgFillPrice"] = orderStatus[@"avgFillPrice"] ?: @0;
        standardizedOrder[@"lastFillPrice"] = orderStatus[@"lastFillPrice"] ?: @0;
        standardizedOrder[@"whyHeld"] = orderStatus[@"whyHeld"] ?: @"";
    }
    
    return [standardizedOrder copy];
}

#pragma mark - DataSourceAdapter Optional

- (NSString *)sourceName {
    return @"Interactive Brokers";
}

@end
