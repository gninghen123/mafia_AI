//
//  WebullDataAdapter.m
//  mafia_AI
//

#import "WebullDataAdapter.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "Position.h"
#import "Order.h"

@implementation WebullDataAdapter

- (NSString *)sourceName {
    return @"Webull";
}

- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol {
    if (!rawData) return nil;
    
    NSMutableDictionary *standardData = [NSMutableDictionary dictionary];
    
    // Symbol
    standardData[@"symbol"] = symbol;
    
    // Webull uses different field names
    if (rawData[@"close"]) {
        standardData[@"last"] = rawData[@"close"];
    } else if (rawData[@"price"]) {
        standardData[@"last"] = rawData[@"price"];
    }
    
    // Bid/Ask (Webull might not provide these in free tier)
    if (rawData[@"bid"]) {
        standardData[@"bid"] = rawData[@"bid"];
    } else if (rawData[@"close"]) {
        // Use close as fallback
        standardData[@"bid"] = rawData[@"close"];
    }
    
    if (rawData[@"ask"]) {
        standardData[@"ask"] = rawData[@"ask"];
    } else if (rawData[@"close"]) {
        // Use close as fallback
        standardData[@"ask"] = rawData[@"close"];
    }
    
    // OHLC
    standardData[@"open"] = rawData[@"open"];
    standardData[@"high"] = rawData[@"high"];
    standardData[@"low"] = rawData[@"low"];
    standardData[@"close"] = rawData[@"close"];
    standardData[@"previousClose"] = rawData[@"preClose"];
    
    // Volume
    standardData[@"volume"] = rawData[@"volume"];
    
    // Change (Webull provides these directly)
    if (rawData[@"change"]) {
        standardData[@"change"] = rawData[@"change"];
    }
    
    if (rawData[@"changePct"]) {
        standardData[@"changePercent"] = rawData[@"changePct"];
    }
    
    // Timestamp
    standardData[@"timestamp"] = [NSDate date]; // Webull doesn't always provide timestamp
    
    // Market status (simplified)
    standardData[@"isMarketOpen"] = @YES; // Would need more logic
    
    return [[MarketData alloc] initWithDictionary:standardData];
}

- (NSDictionary *)standardizeBatchQuotesData:(id)rawData forSymbols:(NSArray<NSString *> *)symbols {
    if (!rawData) {
        NSLog(@"❌ WebullAdapter: No raw data provided for batch quotes");
        return @{};
    }
    
    NSMutableDictionary *standardizedQuotes = [NSMutableDictionary dictionary];
    
    // Webull batch quotes format può essere simile a Schwab:
    // 1. Dictionary con symbol come chiave
    // 2. Array di oggetti quote
    
    if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *quotesDict = (NSDictionary *)rawData;
        
        // Webull potrebbe avere un wrapper, controlla "data" o "results"
        NSDictionary *actualData = quotesDict[@"data"] ?: quotesDict[@"results"] ?: quotesDict;
        
        for (NSString *symbol in symbols) {
            id quoteData = actualData[symbol];
            if (quoteData) {
                MarketData *standardizedQuote = [self standardizeQuoteData:quoteData forSymbol:symbol];
                if (standardizedQuote) {
                    standardizedQuotes[symbol] = standardizedQuote;
                }
            } else {
                NSLog(@"⚠️ WebullAdapter: No data found for symbol %@", symbol);
            }
        }
        
    } else if ([rawData isKindOfClass:[NSArray class]]) {
        NSArray *quotesArray = (NSArray *)rawData;
        
        for (id quoteItem in quotesArray) {
            if (![quoteItem isKindOfClass:[NSDictionary class]]) continue;
            
            NSDictionary *quoteData = (NSDictionary *)quoteItem;
            NSString *symbol = quoteData[@"symbol"] ?: quoteData[@"ticker"];
            
            if (symbol && [symbols containsObject:symbol]) {
                MarketData *standardizedQuote = [self standardizeQuoteData:quoteData forSymbol:symbol];
                if (standardizedQuote) {
                    standardizedQuotes[symbol] = standardizedQuote;
                }
            }
        }
        
    } else {
        NSLog(@"❌ WebullAdapter: Unexpected batch quotes format: %@", [rawData class]);
        return @{};
    }
    
    NSLog(@"✅ WebullAdapter: Standardized %lu/%lu batch quotes",
          (unsigned long)standardizedQuotes.count, (unsigned long)symbols.count);
    
    return [standardizedQuotes copy];
}

- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray array];
    
    if ([rawData isKindOfClass:[NSArray class]]) {
        for (id barItem in (NSArray *)rawData) {
            if (![barItem isKindOfClass:[NSDictionary class]]) continue;
            
            NSDictionary *barData = (NSDictionary *)barItem;
            
            // CREARE RUNTIME MODEL DIRETTAMENTE
            HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
            
            bar.symbol = symbol;
            bar.date = barData[@"date"] ?: [NSDate date];
            bar.open = [barData[@"open"] doubleValue];
            bar.high = [barData[@"high"] doubleValue];
            bar.low = [barData[@"low"] doubleValue];
            bar.close = [barData[@"close"] doubleValue];
            bar.adjustedClose = bar.close; // Default
            bar.volume = [barData[@"volume"] longLongValue];
            bar.timeframe = BarTimeframeDaily; // Default
            
            [bars addObject:bar];
        }
    }
    
    NSLog(@"WebullAdapter: Standardized %lu runtime HistoricalBarModel objects for %@", (unsigned long)bars.count, symbol);
    return [bars copy];
}

- (Position *)standardizePositionData:(NSDictionary *)rawData {
    // TODO: Implement when needed
    return nil;
}

- (Order *)standardizeOrderData:(NSDictionary *)rawData {
    // TODO: Implement when needed
    return nil;
}

@end
