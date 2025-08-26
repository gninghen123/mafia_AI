//
//  SchwabDataAdapter.m
//  mafia_AI
//

#import "SchwabDataAdapter.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "Position.h"
#import "Order.h"
#import "OrderBookEntry.h"  // AGGIUNGI QUESTO IMPORT

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
        if (![candleItem isKindOfClass:[NSDictionary class]]) {
            NSLog(@"SchwabAdapter WARNING: Skipping non-dictionary candle item");
            continue;
        }
        
        NSDictionary *candle = (NSDictionary *)candleItem;
        
        // Validazione datetime
        NSNumber *datetime = candle[@"datetime"];
        if (!datetime || [datetime doubleValue] <= 0) {
            NSLog(@"SchwabAdapter WARNING: Invalid datetime %@ for symbol %@", datetime, symbol);
            continue;
        }
        
        // Validazione valori OHLCV
        double open = [candle[@"open"] doubleValue];
        double high = [candle[@"high"] doubleValue];
        double low = [candle[@"low"] doubleValue];
        double close = [candle[@"close"] doubleValue];
        long long volume = [candle[@"volume"] longLongValue];
        
        // Validazione consistenza OHLC
        if (open <= 0 || high <= 0 || low <= 0 || close <= 0) {
            NSLog(@"SchwabAdapter WARNING: Invalid OHLC values for %@", symbol);
            continue;
        }
        
        if (high < low || open > high || open < low || close > high || close < low) {
            NSLog(@"SchwabAdapter WARNING: Inconsistent OHLC values for %@", symbol);
            continue;
        }
        
        // CREARE RUNTIME MODEL DIRETTAMENTE
        HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
        
        // Basic properties
        bar.symbol = symbol;
        bar.date = [NSDate dateWithTimeIntervalSince1970:[datetime doubleValue] / 1000.0];
        
        // OHLCV data
        bar.open = open;
        bar.high = high;
        bar.low = low;
        bar.close = close;
        bar.adjustedClose = close; // Default a close, miglioreremo con split/dividendi
        bar.volume = volume;
        
        // Default timeframe (sarà settato dal DataManager se necessario)
        bar.timeframe = BarTimeframeDaily;
        
        [bars addObject:bar];
    }
    
    // Ordina per data crescente
    NSArray<HistoricalBarModel *> *sortedBars = [bars sortedArrayUsingComparator:^NSComparisonResult(HistoricalBarModel *bar1, HistoricalBarModel *bar2) {
        return [bar1.date compare:bar2.date];
    }];
    
    NSLog(@"SchwabAdapter SUCCESS: Standardized %lu runtime HistoricalBarModel objects for %@", (unsigned long)sortedBars.count, symbol);
    return sortedBars;
}

- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol {
    if (!rawData) return @{@"bids": @[], @"asks": @[]};
    
    NSMutableArray<OrderBookEntry *> *bids = [NSMutableArray array];
    NSMutableArray<OrderBookEntry *> *asks = [NSMutableArray array];
    
    // Schwab potrebbe fornire order book in diversi formati
    if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *orderBookData = (NSDictionary *)rawData;
        
        // Processa i bid
        NSArray *rawBids = orderBookData[@"bids"] ?: orderBookData[@"bidList"] ?: @[];
        for (NSDictionary *bidData in rawBids) {
            OrderBookEntry *entry = [[OrderBookEntry alloc] init];
            entry.price = [bidData[@"price"] ?: bidData[@"bidPrice"] ?: @0 doubleValue];
            entry.size = [bidData[@"size"] ?: bidData[@"bidSize"] ?: @0 integerValue];
            entry.marketMaker = bidData[@"marketMaker"];
            entry.isBid = YES;
            [bids addObject:entry];
        }
        
        // Processa gli ask
        NSArray *rawAsks = orderBookData[@"asks"] ?: orderBookData[@"askList"] ?: @[];
        for (NSDictionary *askData in rawAsks) {
            OrderBookEntry *entry = [[OrderBookEntry alloc] init];
            entry.price = [askData[@"price"] ?: askData[@"askPrice"] ?: @0 doubleValue];
            entry.size = [askData[@"size"] ?: askData[@"askSize"] ?: @0 integerValue];
            entry.marketMaker = askData[@"marketMaker"];
            entry.isBid = NO;
            [asks addObject:entry];
        }
    }
    
    return @{
        @"bids": [bids copy],
        @"asks": [asks copy]
    };
}

- (Position *)standardizePositionData:(NSDictionary *)rawData {
    // TODO: Implementare quando necessario
    return nil;
}

- (Order *)standardizeOrderData:(NSDictionary *)rawData {
    // TODO: Implementare quando necessario
    return nil;
}

- (NSDictionary *)standardizeAccountData:(id)rawData {
    if ([rawData isKindOfClass:[NSArray class]]) {
        // Array di account da Schwab API
        return @{@"accounts": (NSArray *)rawData};
    } else if ([rawData isKindOfClass:[NSDictionary class]]) {
        // Singolo account
        return @{@"accounts": @[rawData]};
    }
    
    NSLog(@"❌ SchwabAdapter: Unexpected account data format: %@", [rawData class]);
    return @{@"accounts": @[]};
}
@end
