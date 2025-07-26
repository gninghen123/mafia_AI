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

- (NSArray<HistoricalBar *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    // TODO: Implement when needed
    // Per ora restituiamo array di dizionari invece di HistoricalBar
    NSMutableArray *bars = [NSMutableArray array];
    
    if ([rawData isKindOfClass:[NSArray class]]) {
        for (NSDictionary *barData in rawData) {
            NSMutableDictionary *standardBar = [NSMutableDictionary dictionary];
            
            standardBar[@"symbol"] = symbol;
            standardBar[@"date"] = barData[@"date"] ?: [NSDate date];
            standardBar[@"open"] = barData[@"open"] ?: @0;
            standardBar[@"high"] = barData[@"high"] ?: @0;
            standardBar[@"low"] = barData[@"low"] ?: @0;
            standardBar[@"close"] = barData[@"close"] ?: @0;
            standardBar[@"volume"] = barData[@"volume"] ?: @0;
            
            [bars addObject:standardBar];
        }
    }
    
    return bars;
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
