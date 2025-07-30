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

- (NSArray<NSDictionary *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    if (!rawData) return @[];
    
    NSArray *candles = nil;
    
    // Caso 1: rawData è già un array di candele (formato diretto)
    if ([rawData isKindOfClass:[NSArray class]]) {
        candles = (NSArray *)rawData;
        NSLog(@"SchwabAdapter: Raw data is array with %lu candles", (unsigned long)candles.count);
    }
    // Caso 2: rawData è un dictionary con chiave "candles" (formato wrapped)
    else if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *data = (NSDictionary *)rawData;
        candles = data[@"candles"];
        NSLog(@"SchwabAdapter: Raw data is dictionary, extracted %lu candles", (unsigned long)candles.count);
    }
    // Caso 3: formato non riconosciuto
    else {
        NSLog(@"SchwabAdapter: Unexpected raw data format: %@", [rawData class]);
        return @[];
    }
    
    if (!candles || ![candles isKindOfClass:[NSArray class]]) {
        NSLog(@"SchwabAdapter: No valid candles array found");
        return @[];
    }
    
    NSMutableArray<NSDictionary *> *bars = [NSMutableArray array];
    
    for (id candleItem in candles) {
        NSMutableDictionary *barDict = [NSMutableDictionary dictionary];
        
        if ([candleItem isKindOfClass:[NSDictionary class]]) {
            NSDictionary *candle = (NSDictionary *)candleItem;
            
            // Schwab usa epoch in millisecondi
            NSNumber *datetime = candle[@"datetime"];
            if (datetime) {
                NSTimeInterval timestamp = [datetime doubleValue] / 1000.0;
                barDict[@"date"] = [NSDate dateWithTimeIntervalSince1970:timestamp];
            }
            
            barDict[@"symbol"] = symbol;
            
            // Converti valori numerici correttamente
            barDict[@"open"] = @([candle[@"open"] doubleValue]);
            barDict[@"high"] = @([candle[@"high"] doubleValue]);
            barDict[@"low"] = @([candle[@"low"] doubleValue]);
            barDict[@"close"] = @([candle[@"close"] doubleValue]);
            barDict[@"volume"] = @([candle[@"volume"] longLongValue]);
            
            // Aggiungi adjustedClose se disponibile (per ora uguale a close)
            barDict[@"adjustedClose"] = barDict[@"close"];
        }
        // Supporta anche formato array [timestamp, open, high, low, close, volume]
        else if ([candleItem isKindOfClass:[NSArray class]]) {
            NSArray *candleArray = (NSArray *)candleItem;
            if (candleArray.count >= 6) {
                NSNumber *timestamp = candleArray[0];
                barDict[@"date"] = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue] / 1000.0];
                barDict[@"symbol"] = symbol;
                barDict[@"open"] = @([candleArray[1] doubleValue]);
                barDict[@"high"] = @([candleArray[2] doubleValue]);
                barDict[@"low"] = @([candleArray[3] doubleValue]);
                barDict[@"close"] = @([candleArray[4] doubleValue]);
                barDict[@"volume"] = @([candleArray[5] longLongValue]);
                barDict[@"adjustedClose"] = barDict[@"close"];
            }
        }
        
        // Aggiungi solo se abbiamo una data valida
        if (barDict[@"date"]) {
            [bars addObject:barDict];
        }
    }
    
    // Ordina per data (dal più vecchio al più recente)
    NSArray *sortedBars = [bars sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *bar1, NSDictionary *bar2) {
        NSDate *date1 = bar1[@"date"];
        NSDate *date2 = bar2[@"date"];
        return [date1 compare:date2];
    }];
    
    NSLog(@"SchwabAdapter: Standardized %lu bars for symbol %@", (unsigned long)sortedBars.count, symbol);
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

@end
