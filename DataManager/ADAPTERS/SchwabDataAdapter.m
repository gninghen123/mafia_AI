// SchwabDataAdapter.m
#import "SchwabDataAdapter.h"

@implementation SchwabDataAdapter

- (NSString *)sourceName {
    return @"Schwab";
}

- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol {
    if (!rawData) return nil;
    
    // Schwab structure: data[@"quote"] contains main price data
    NSDictionary *quote = rawData[@"quote"];
    NSDictionary *reference = rawData[@"reference"];
    
    if (!quote) return nil;
    
    NSMutableDictionary *standardData = [NSMutableDictionary dictionary];
    
    // Symbol
    standardData[@"symbol"] = symbol;
    
    // Prices - Map Schwab fields to standard fields
    if (quote[@"lastPrice"]) {
        standardData[@"last"] = quote[@"lastPrice"];
    }
    
    if (quote[@"bidPrice"]) {
        standardData[@"bid"] = quote[@"bidPrice"];
    }
    
    if (quote[@"askPrice"]) {
        standardData[@"ask"] = quote[@"askPrice"];
    }
    
    if (quote[@"openPrice"]) {
        standardData[@"open"] = quote[@"openPrice"];
    }
    
    if (quote[@"highPrice"]) {
        standardData[@"high"] = quote[@"highPrice"];
    }
    
    if (quote[@"lowPrice"]) {
        standardData[@"low"] = quote[@"lowPrice"];
    }
    
    // Previous close (Schwab uses "closePrice" for previous close)
    if (quote[@"closePrice"]) {
        standardData[@"previousClose"] = quote[@"closePrice"];
    }
    
    // Current close (for after hours)
    if (quote[@"regularMarketLastPrice"]) {
        standardData[@"close"] = quote[@"regularMarketLastPrice"];
    } else {
        standardData[@"close"] = quote[@"lastPrice"];
    }
    
    // Volume
    if (quote[@"totalVolume"]) {
        standardData[@"volume"] = quote[@"totalVolume"];
    }
    
    // Bid/Ask sizes
    if (quote[@"bidSize"]) {
        standardData[@"bidSize"] = quote[@"bidSize"];
    }
    
    if (quote[@"askSize"]) {
        standardData[@"askSize"] = quote[@"askSize"];
    }
    
    // Change and Change Percent
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

- (NSArray<HistoricalBar *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) return @[];
    
    NSDictionary *data = (NSDictionary *)rawData;
    NSArray *candles = data[@"candles"];
    
    if (!candles) return @[];
    
    NSMutableArray<HistoricalBar *> *bars = [NSMutableArray array];
    
    for (NSDictionary *candle in candles) {
        NSMutableDictionary *barData = [NSMutableDictionary dictionary];
        
        // Timestamp (Schwab uses milliseconds)
        if (candle[@"datetime"]) {
            NSNumber *timestamp = candle[@"datetime"];
            barData[@"timestamp"] = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue] / 1000.0];
        }
        
        // OHLC data
        barData[@"open"] = candle[@"open"];
        barData[@"high"] = candle[@"high"];
        barData[@"low"] = candle[@"low"];
        barData[@"close"] = candle[@"close"];
        barData[@"volume"] = candle[@"volume"];
        
        HistoricalBar *bar = [[HistoricalBar alloc] initWithDictionary:barData];
        [bars addObject:bar];
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
