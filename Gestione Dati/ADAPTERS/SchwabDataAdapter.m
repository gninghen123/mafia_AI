//
//  SchwabDataAdapter.m
//  mafia_AI
//

#import "SchwabDataAdapter.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "TradingRuntimeModels.h"
#import "OrderBookEntry.h"

@implementation SchwabDataAdapter

- (NSString *)sourceName {
    return @"Schwab";
}

- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol {
    if (!rawData) return nil;
    
    NSMutableDictionary *standardData = [NSMutableDictionary dictionary];
    
    // Symbol
    standardData[@"symbol"] = symbol;
    
    // Map Schwab fields to standard fields
    NSDictionary *quote = rawData[@"quote"];
    NSDictionary *reference = rawData[@"reference"];
    
    if (!quote) {
        // Sometimes Schwab puts data directly in rawData
        quote = rawData;
    }
    
    // Prices
    if (quote[@"lastPrice"]) {
        standardData[@"last"] = quote[@"lastPrice"];
    } else if (quote[@"mark"]) {
        standardData[@"last"] = quote[@"mark"];
    }
    
    // Bid/Ask
    if (quote[@"bidPrice"]) {
        standardData[@"bid"] = quote[@"bidPrice"];
    }
    
    if (quote[@"askPrice"]) {
        standardData[@"ask"] = quote[@"askPrice"];
    }
    
    // OHLC
    standardData[@"open"] = quote[@"openPrice"];
    standardData[@"high"] = quote[@"highPrice"];
    standardData[@"low"] = quote[@"lowPrice"];
    standardData[@"close"] = quote[@"closePrice"];
    standardData[@"previousClose"] = quote[@"previousClosePrice"];
    
    // Volume
    standardData[@"volume"] = quote[@"totalVolume"];
    
    // Change
    if (quote[@"netChange"]) {
        standardData[@"change"] = quote[@"netChange"];
    }
    
    if (quote[@"netPercentChange"]) {
        standardData[@"changePercent"] = quote[@"netPercentChange"];
    }
    
    // Exchange
    if (reference[@"exchangeName"]) {
        standardData[@"exchange"] = reference[@"exchangeName"];
    }
    
    // Timestamp (Schwab uses milliseconds)
    if (quote[@"quoteTime"]) {
        NSNumber *quoteTimeMs = quote[@"quoteTime"];
        NSTimeInterval quoteTimeSeconds = [quoteTimeMs doubleValue] / 1000.0;
        standardData[@"timestamp"] = [NSDate dateWithTimeIntervalSince1970:quoteTimeSeconds];
    }
    
    // Market status
    if (quote[@"securityStatus"]) {
        NSString *status = quote[@"securityStatus"];
        standardData[@"isMarketOpen"] = @([status isEqualToString:@"Normal"]);
    }
    
    // Create and return MarketData object
    return [[MarketData alloc] initWithDictionary:standardData];
}

- (NSDictionary *)standardizeBatchQuotesData:(id)rawData forSymbols:(NSArray<NSString *> *)symbols {
    if (!rawData) {
        NSLog(@"❌ SchwabAdapter: No raw data provided for batch quotes");
        return @{};
    }
    
    NSMutableDictionary *standardizedQuotes = [NSMutableDictionary dictionary];
    
    // Schwab batch quotes format può essere:
    // 1. Dictionary con symbol come chiave: {"AAPL": {...}, "MSFT": {...}}
    // 2. Array di oggetti quote con symbol inside
    
    if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *quotesDict = (NSDictionary *)rawData;
        
        for (NSString *symbol in symbols) {
            id quoteData = quotesDict[symbol];
            if (quoteData) {
                MarketData *standardizedQuote = [self standardizeQuoteData:quoteData forSymbol:symbol];
                if (standardizedQuote) {
                    standardizedQuotes[symbol] = standardizedQuote;
                }
            } else {
                NSLog(@"⚠️ SchwabAdapter: No data found for symbol %@", symbol);
            }
        }
        
    } else if ([rawData isKindOfClass:[NSArray class]]) {
        NSArray *quotesArray = (NSArray *)rawData;
        
        for (id quoteItem in quotesArray) {
            if (![quoteItem isKindOfClass:[NSDictionary class]]) continue;
            
            NSDictionary *quoteData = (NSDictionary *)quoteItem;
            NSString *symbol = quoteData[@"symbol"];
            
            if (symbol && [symbols containsObject:symbol]) {
                MarketData *standardizedQuote = [self standardizeQuoteData:quoteData forSymbol:symbol];
                if (standardizedQuote) {
                    standardizedQuotes[symbol] = standardizedQuote;
                }
            }
        }
        
    } else {
        NSLog(@"❌ SchwabAdapter: Unexpected batch quotes format: %@", [rawData class]);
        return @{};
    }
    
    NSLog(@"✅ SchwabAdapter: Standardized %lu/%lu batch quotes",
          (unsigned long)standardizedQuotes.count, (unsigned long)symbols.count);
    
    return [standardizedQuotes copy];
}

- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    if (!rawData) return @[];
    
    NSArray *candles = nil;
    
    // Gestione formato Schwab: può essere array diretto o dictionary con "candles"
    if ([rawData isKindOfClass:[NSArray class]]) {
        candles = (NSArray *)rawData;
        NSLog(@"SchwabAdapter: Raw data is array with %lu candles", (unsigned long)candles.count);
    } else if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *data = (NSDictionary *)rawData;
        candles = data[@"candles"];
        NSLog(@"SchwabAdapter: Raw data is dictionary, extracted %lu candles", (unsigned long)candles.count);
    } else {
        NSLog(@"SchwabAdapter ERROR: Unexpected raw data format: %@", [rawData class]);
        return @[];
    }
    
    if (!candles || ![candles isKindOfClass:[NSArray class]]) {
        NSLog(@"SchwabAdapter ERROR: No valid candles array found");
        return @[];
    }
    
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray array];
    
    for (id candleItem in candles) {
        if (![candleItem isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *candle = (NSDictionary *)candleItem;
        
        // Create HistoricalBarModel from Schwab candle data
        HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
        bar.symbol = symbol;
        
        // Schwab timestamp is in milliseconds
        NSNumber *timestampMs = candle[@"datetime"];
        if (timestampMs) {
            bar.date = [NSDate dateWithTimeIntervalSince1970:[timestampMs doubleValue] / 1000.0];
        }
        
        // OHLCV data
        bar.open = [candle[@"open"] doubleValue];
        bar.high = [candle[@"high"] doubleValue];
        bar.low = [candle[@"low"] doubleValue];
        bar.close = [candle[@"close"] doubleValue];
        bar.volume = [candle[@"volume"] integerValue];
        
    
        
        // Set timeframe based on data (this might need to be passed as parameter)
        bar.timeframe = 0; // Default, should be determined from context
        
        [bars addObject:bar];
    }
    
    // controlla l ultima barra che abbia close !=0
    if ([[bars lastObject] close] == 0) {
        [bars removeLastObject];
    }
    
    NSLog(@"✅ SchwabAdapter: Created %lu HistoricalBarModel objects for %@",
          (unsigned long)bars.count, symbol);
    
    return [bars copy];
}

- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol {
    // ✅ This method signature is correct in the protocol - returns NSDictionary
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return @{@"bids": @[], @"asks": @[]};
    }
    
    NSDictionary *orderBookData = (NSDictionary *)rawData;
    NSMutableArray<OrderBookEntry *> *bids = [NSMutableArray array];
    NSMutableArray<OrderBookEntry *> *asks = [NSMutableArray array];
    
    // Process bids
    NSArray *rawBids = orderBookData[@"bids"] ?: orderBookData[@"bidList"] ?: @[];
    for (NSDictionary *bidData in rawBids) {
        OrderBookEntry *entry = [[OrderBookEntry alloc] init];
        entry.price = [bidData[@"price"] ?: bidData[@"bidPrice"] ?: @0 doubleValue];
        entry.size = [bidData[@"size"] ?: bidData[@"bidSize"] ?: @0 integerValue];
        entry.marketMaker = bidData[@"marketMaker"];
        entry.isBid = YES;
        [bids addObject:entry];
    }
    
    // Process asks
    NSArray *rawAsks = orderBookData[@"asks"] ?: orderBookData[@"askList"] ?: @[];
    for (NSDictionary *askData in rawAsks) {
        OrderBookEntry *entry = [[OrderBookEntry alloc] init];
        entry.price = [askData[@"price"] ?: askData[@"askPrice"] ?: @0 doubleValue];
        entry.size = [askData[@"size"] ?: askData[@"askSize"] ?: @0 integerValue];
        entry.marketMaker = askData[@"marketMaker"];
        entry.isBid = NO;
        [asks addObject:entry];
    }
    
    return @{
        @"bids": [bids copy],
        @"asks": [asks copy]
    };
}

- (AdvancedPositionModel *)standardizePositionData:(NSDictionary *)rawData {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedPositionModel *position = [[AdvancedPositionModel alloc] init];
    
    // Basic position info
    position.symbol = rawData[@"instrument"][@"symbol"] ?: rawData[@"symbol"] ?: @"";
    position.accountId = rawData[@"accountId"] ?: @"";
    position.quantity = [rawData[@"longQuantity"] doubleValue] - [rawData[@"shortQuantity"] doubleValue];
    position.avgCost = [rawData[@"averagePrice"] doubleValue];
    
    // Market data
    position.currentPrice = [rawData[@"currentPrice"] doubleValue] ?: [rawData[@"marketValue"] doubleValue] / position.quantity;
    position.marketValue = [rawData[@"marketValue"] doubleValue];
    
    // P&L calculations
    double totalCost = position.quantity * position.avgCost;
    position.unrealizedPL = position.marketValue - totalCost;
    if (totalCost != 0) {
        position.unrealizedPLPercent = (position.unrealizedPL / totalCost) * 100.0;
    }
    
    // Additional market data (if available)
    position.bidPrice = [rawData[@"bidPrice"] doubleValue];
    position.askPrice = [rawData[@"askPrice"] doubleValue];
    position.dayHigh = [rawData[@"dayHigh"] doubleValue];
    position.dayLow = [rawData[@"dayLow"] doubleValue];
    position.dayOpen = [rawData[@"dayOpen"] doubleValue];
    position.previousClose = [rawData[@"previousClose"] doubleValue];
    position.volume = [rawData[@"volume"] integerValue];
    
    position.priceLastUpdated = [NSDate date];
    
    NSLog(@"✅ SchwabAdapter: Created AdvancedPositionModel for %@ - %.0f shares @ $%.2f",
          position.symbol, position.quantity, position.avgCost);
    
    return position;
}

- (AdvancedOrderModel *)standardizeOrderData:(NSDictionary *)rawData {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedOrderModel *order = [[AdvancedOrderModel alloc] init];
    
    // Basic order info
    order.orderId = rawData[@"orderId"] ?: @"";
    order.accountId = rawData[@"accountId"] ?: @"";
    order.symbol = rawData[@"orderLegCollection"][0][@"instrument"][@"symbol"] ?: @"";
    
    // Order type and side
    order.orderType = rawData[@"orderType"] ?: @"MARKET";
    order.side = rawData[@"orderLegCollection"][0][@"instruction"] ?: @"BUY";
    order.status = rawData[@"status"] ?: @"PENDING";
    order.timeInForce = rawData[@"duration"] ?: @"DAY";
    
    // Quantities and prices
    order.quantity = [rawData[@"quantity"] doubleValue];
    order.filledQuantity = [rawData[@"filledQuantity"] doubleValue];
    order.price = [rawData[@"price"] doubleValue];
    order.stopPrice = [rawData[@"stopPrice"] doubleValue];
    order.avgFillPrice = [rawData[@"avgFillPrice"] doubleValue];
    
    // Dates (Schwab uses ISO date strings or timestamps)
    NSString *enteredTime = rawData[@"enteredTime"];
    if (enteredTime) {
        // Handle ISO date string conversion
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        order.createdDate = [formatter dateFromString:enteredTime] ?: [NSDate date];
    }
    
    NSString *closeTime = rawData[@"closeTime"];
    if (closeTime) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        order.updatedDate = [formatter dateFromString:closeTime] ?: [NSDate date];
    } else {
        order.updatedDate = order.createdDate;
    }
    
    // Additional fields
    order.instruction = rawData[@"orderLegCollection"][0][@"instruction"] ?: @"";
    order.orderStrategy = rawData[@"orderStrategyType"] ?: @"SINGLE";
    
    NSLog(@"✅ SchwabAdapter: Created AdvancedOrderModel %@ for %@ - %@ %.0f shares",
          order.orderId, order.symbol, order.side, order.quantity);
    
    return order;
}

- (NSArray<AccountModel *> *)standardizeAccountData:(id)rawData {
    NSMutableArray<AccountModel *> *accounts = [NSMutableArray array];
    
    if ([rawData isKindOfClass:[NSArray class]]) {
        // Array of account dictionaries from Schwab API
        NSArray *accountsArray = (NSArray *)rawData;
        
        for (id accountItem in accountsArray) {
            if ([accountItem isKindOfClass:[NSDictionary class]]) {
                AccountModel *account = [self createAccountModelFromDictionary:(NSDictionary *)accountItem];
                if (account) {
                    [accounts addObject:account];
                }
            }
        }
        
    } else if ([rawData isKindOfClass:[NSDictionary class]]) {
        // Single account dictionary
        NSDictionary *accountDict = (NSDictionary *)rawData;
        
        // Check if it's a wrapper with "accounts" key
        if (accountDict[@"accounts"]) {
            return [self standardizeAccountData:accountDict[@"accounts"]];
        } else {
            // Single account data
            AccountModel *account = [self createAccountModelFromDictionary:accountDict];
            if (account) {
                [accounts addObject:account];
            }
        }
    }
    
    NSLog(@"✅ SchwabAdapter: Created %lu AccountModel objects", (unsigned long)accounts.count);
    return [accounts copy];
}

#pragma mark - Helper Methods

- (AccountModel *)createAccountModelFromDictionary:(NSDictionary *)accountDict {
    if (!accountDict || ![accountDict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AccountModel *account = [[AccountModel alloc] init];
    
    // Basic account info
    NSDictionary *securitiesAccount = accountDict[@"securitiesAccount"];
    if (securitiesAccount && [securitiesAccount isKindOfClass:[NSDictionary class]]) {
        account.accountId = securitiesAccount[@"accountNumber"] ?: @"";
        account.accountType = securitiesAccount[@"type"] ?: @"UNKNOWN";
        account.isPrimary = [securitiesAccount[@"isPrimary"] boolValue];
    } else {
        account.accountId = accountDict[@"accountNumber"] ?: accountDict[@"accountId"] ?: @"";
        account.accountType = accountDict[@"type"] ?: @"UNKNOWN";
        account.isPrimary = [accountDict[@"isPrimary"] boolValue];
    }
    
    account.brokerName = @"SCHWAB";
    account.displayName = [NSString stringWithFormat:@"SCHWAB-%@", account.accountId];
    account.isConnected = YES;
    account.lastUpdated = [NSDate date];
    
    NSLog(@"✅ SchwabAdapter: Created AccountModel %@ (%@)", account.accountId, account.accountType);
    
    return account;
}

@end
