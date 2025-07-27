//
//  SchwabDataAdapter.m
//  mafia_AI
//

#import "SchwabDataAdapter.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "Position.h"
#import "Order.h"

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
        if (![candleItem isKindOfClass:[NSDictionary class]]) {
            NSLog(@"SchwabAdapter: Skipping non-dictionary candle: %@", candleItem);
            continue;
        }
        
        NSDictionary *candle = (NSDictionary *)candleItem;
        NSMutableDictionary *barData = [NSMutableDictionary dictionary];
        
        // Date handling - supporta sia "datetime" (timestamp) che "date" (string)
        NSDate *candleDate = nil;
        
        if (candle[@"datetime"]) {
            // Formato timestamp (milliseconds)
            NSNumber *timestamp = candle[@"datetime"];
            candleDate = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue] / 1000.0];
        }else if (candle[@"date"]){
            candleDate = candleItem[@"date"];
        }
        
        if (!candleDate) {
            NSLog(@"SchwabAdapter: Missing or invalid date in candle: %@", candle);
            continue; // Skip candles without valid date
        }
        
        // Assicurati che sia proprio un NSDate
        if (candleDate && [candleDate isKindOfClass:[NSDate class]]) {
            barData[@"date"] = candleDate;
        } else {
            NSLog(@"SchwabAdapter: Invalid date object type: %@", [candleDate class]);
            continue;
        }
        
        // OHLC data con validazione
        barData[@"open"] = [self safeNumberFromValue:candle[@"open"]];
        barData[@"high"] = [self safeNumberFromValue:candle[@"high"]];
        barData[@"low"] = [self safeNumberFromValue:candle[@"low"]];
        barData[@"close"] = [self safeNumberFromValue:candle[@"close"]];
        barData[@"volume"] = [self safeNumberFromValue:candle[@"volume"]];
        barData[@"symbol"] = symbol;
        
        [bars addObject:barData];
    }
    
    NSLog(@"SchwabAdapter: Successfully converted %lu bars for %@", (unsigned long)bars.count, symbol);
    return bars;
}

// Helper method per validare i numeri
- (NSNumber *)safeNumberFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)value;
    } else if ([value isKindOfClass:[NSString class]]) {
        return @([value doubleValue]);
    }
    return @0;
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
