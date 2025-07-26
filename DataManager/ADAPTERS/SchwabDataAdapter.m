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
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) return @[];
    
    NSDictionary *data = (NSDictionary *)rawData;
    NSArray *candles = data[@"candles"];
    
    if (!candles) return @[];
    
    NSMutableArray<NSDictionary *> *bars = [NSMutableArray array];
    
    for (NSDictionary *candle in candles) {
        NSMutableDictionary *barData = [NSMutableDictionary dictionary];
        
        // Date (Schwab uses milliseconds)
        if (candle[@"datetime"]) {
            NSNumber *timestamp = candle[@"datetime"];
            barData[@"date"] = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue] / 1000.0];
        }
        
        // OHLC data
        barData[@"open"] = candle[@"open"] ?: @0;
        barData[@"high"] = candle[@"high"] ?: @0;
        barData[@"low"] = candle[@"low"] ?: @0;
        barData[@"close"] = candle[@"close"] ?: @0;
        barData[@"volume"] = candle[@"volume"] ?: @0;
        barData[@"symbol"] = symbol;
        
        [bars addObject:barData];
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
