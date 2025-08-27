//
//  YahooDataAdapter.m
//  TradingApp
//
//  Yahoo Finance API adapter implementation - JSON format
//  Handles Yahoo's modern API responses and converts to app standard format
//

#import "YahooDataAdapter.h"
#import "MarketData.h"
#import "RuntimeModels.h"
#import "CommonTypes.h"

@implementation YahooDataAdapter

#pragma mark - DataSourceAdapter Protocol Implementation

- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol {
    if (![self isValidYahooResponse:rawData]) {
        NSLog(@"❌ YahooDataAdapter: Invalid Yahoo response for symbol %@", symbol);
        return nil;
    }
    
    // Parse Yahoo chart response structure
    NSDictionary *parsedData = [self parseYahooChartResponse:rawData forSymbol:symbol];
    if (!parsedData) {
        NSLog(@"❌ YahooDataAdapter: Failed to parse Yahoo chart response for %@", symbol);
        return nil;
    }
    
    // Extract metadata and current values
    NSDictionary *meta = parsedData[@"meta"];
    NSDictionary *currentValues = parsedData[@"currentValues"];
    
    if (!meta || !currentValues) {
        NSLog(@"❌ YahooDataAdapter: Missing meta or currentValues in Yahoo response for %@", symbol);
        return nil;
    }
    
    // Create standardized MarketData
    NSMutableDictionary *standardData = [NSMutableDictionary dictionary];
    
    // Basic symbol info
    standardData[@"symbol"] = symbol;
    standardData[@"exchange"] = meta[@"exchangeName"] ?: @"Yahoo Finance";
    
    // Price data - Yahoo returns in meta for current quote
    standardData[@"last"] = meta[@"regularMarketPrice"] ?: @0;
    standardData[@"close"] = meta[@"regularMarketPrice"] ?: @0;
    standardData[@"previousClose"] = meta[@"previousClose"] ?: @0;
    standardData[@"open"] = meta[@"regularMarketOpen"] ?: @0;
    standardData[@"high"] = meta[@"regularMarketDayHigh"] ?: @0;
    standardData[@"low"] = meta[@"regularMarketDayLow"] ?: @0;
    
    // Volume
    standardData[@"volume"] = meta[@"regularMarketVolume"] ?: @0;
    
    // Calculate change and change percent
    double lastPrice = [meta[@"regularMarketPrice"] doubleValue];
    double previousClose = [meta[@"previousClose"] doubleValue];
    if (previousClose > 0) {
        double change = lastPrice - previousClose;
        double changePercent = (change / previousClose) * 100.0;
        standardData[@"change"] = @(change);
        standardData[@"changePercent"] = @(changePercent);
    } else {
        standardData[@"change"] = @0;
        standardData[@"changePercent"] = @0;
    }
    
    // Bid/Ask (not always available in Yahoo basic API)
    standardData[@"bid"] = meta[@"bid"] ?: @0;
    standardData[@"ask"] = meta[@"ask"] ?: @0;
    standardData[@"bidSize"] = meta[@"bidSize"] ?: @0;
    standardData[@"askSize"] = meta[@"askSize"] ?: @0;
    
    // Timestamp
    NSNumber *timestamp = rawData[@"timestamp"];
    if (timestamp) {
        standardData[@"timestamp"] = [NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue];
    } else {
        standardData[@"timestamp"] = [NSDate date];
    }
    
    // Market status
    NSString *marketState = meta[@"marketState"];
    standardData[@"isMarketOpen"] = @([marketState isEqualToString:@"REGULAR"] || [marketState isEqualToString:@"PRE"] || [marketState isEqualToString:@"POST"]);
    
    // Additional Yahoo-specific data
    standardData[@"currency"] = meta[@"currency"] ?: @"USD";
    standardData[@"marketCap"] = meta[@"marketCap"] ?: @0;
    
    NSLog(@"✅ YahooDataAdapter: Standardized quote for %@ - Price: %.2f, Change: %.2f (%.2f%%)",
          symbol, lastPrice, [standardData[@"change"] doubleValue], [standardData[@"changePercent"] doubleValue]);
    
    return [[MarketData alloc] initWithDictionary:standardData];
}

- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ YahooDataAdapter: Invalid historical data format for %@", symbol);
        return @[];
    }
    
    NSDictionary *yahooData = (NSDictionary *)rawData;
    
    // Yahoo historical data structure: chart.result[0] contains timestamps and indicators
    NSDictionary *chart = yahooData[@"chart"];
    if (!chart) return @[];
    
    NSArray *results = chart[@"result"];
    if (!results || results.count == 0) return @[];
    
    NSDictionary *result = results[0];
    NSArray *timestamps = result[@"timestamp"];
    NSDictionary *indicators = result[@"indicators"];
    
    if (!timestamps || !indicators) {
        NSLog(@"❌ YahooDataAdapter: Missing timestamps or indicators in Yahoo historical data for %@", symbol);
        return @[];
    }
    
    // Extract OHLCV data
    NSArray *quotes = indicators[@"quote"];
    if (!quotes || quotes.count == 0) return @[];
    
    NSDictionary *quoteData = quotes[0];
    NSArray *opens = quoteData[@"open"];
    NSArray *highs = quoteData[@"high"];
    NSArray *lows = quoteData[@"low"];
    NSArray *closes = quoteData[@"close"];
    NSArray *volumes = quoteData[@"volume"];
    
    // Convert to HistoricalBarModel objects
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray array];
    NSInteger count = timestamps.count;
    
    for (NSInteger i = 0; i < count; i++) {
        // Skip bars with null values
        if (i >= opens.count || i >= highs.count || i >= lows.count || i >= closes.count) continue;
        
        id openVal = opens[i];
        id highVal = highs[i];
        id lowVal = lows[i];
        id closeVal = closes[i];
        
        if ([openVal isKindOfClass:[NSNull class]] ||
            [highVal isKindOfClass:[NSNull class]] ||
            [lowVal isKindOfClass:[NSNull class]] ||
            [closeVal isKindOfClass:[NSNull class]]) {
            continue;
        }
        
        HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
        
        // Date from timestamp
        NSNumber *ts = timestamps[i];
        bar.date = [NSDate dateWithTimeIntervalSince1970:ts.doubleValue];
        bar.symbol = symbol;
        
        // OHLC prices
        bar.open = [openVal doubleValue];
        bar.high = [highVal doubleValue];
        bar.low = [lowVal doubleValue];
        bar.close = [closeVal doubleValue];
        
        // Volume (may be null for some timeframes)
        if (i < volumes.count && volumes[i] && ![volumes[i] isKindOfClass:[NSNull class]]) {
            bar.volume = [volumes[i] longLongValue];
        } else {
            bar.volume = 0;
        }
        
        
        [bars addObject:bar];
    }
    
    NSLog(@"✅ YahooDataAdapter: Standardized %lu historical bars for %@", (unsigned long)bars.count, symbol);
    
    return [bars copy];
}

- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol {
    // Yahoo Finance doesn't provide detailed order book data in free API
    NSLog(@"⚠️ YahooDataAdapter: Order book data not available from Yahoo Finance API");
    return @{
        @"symbol": symbol,
        @"bids": @[],
        @"asks": @[],
        @"timestamp": [NSDate date]
    };
}

- (NSDictionary *)standardizeBatchQuotesData:(id)rawData forSymbols:(NSArray<NSString *> *)symbols {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ YahooDataAdapter: Invalid batch quotes data format");
        return @{};
    }
    
    NSDictionary *rawQuotes = (NSDictionary *)rawData;
    NSMutableDictionary *standardizedQuotes = [NSMutableDictionary dictionary];
    
    for (NSString *symbol in symbols) {
        NSDictionary *yahooQuote = rawQuotes[symbol];
        if (!yahooQuote || ![yahooQuote isKindOfClass:[NSDictionary class]]) {
            NSLog(@"⚠️ YahooDataAdapter: No valid data for symbol %@", symbol);
            continue;
        }
        
        MarketData *standardizedQuote = [self standardizeQuoteData:yahooQuote forSymbol:symbol];
        if (standardizedQuote) {
            standardizedQuotes[symbol] = standardizedQuote;
        }
    }
    
    NSLog(@"✅ YahooDataAdapter: Standardized %lu/%lu Yahoo Finance batch quotes",
          (unsigned long)standardizedQuotes.count, (unsigned long)symbols.count);
    
    return [standardizedQuotes copy];
}

#pragma mark - Future Implementation (Portfolio/Trading)

- (id)standardizePositionData:(NSDictionary *)rawData {
    // Yahoo Finance doesn't provide portfolio data - this would be for Yahoo-connected brokers
    NSLog(@"⚠️ YahooDataAdapter: Position data not available from Yahoo Finance");
    return nil;
}

- (id)standardizeOrderData:(NSDictionary *)rawData {
    // Yahoo Finance doesn't provide order data
    NSLog(@"⚠️ YahooDataAdapter: Order data not available from Yahoo Finance");
    return nil;
}

- (NSDictionary *)standardizeAccountData:(id)rawData {
    // Yahoo Finance doesn't provide account data
    NSLog(@"⚠️ YahooDataAdapter: Account data not available from Yahoo Finance");
    return @{};
}

#pragma mark - Yahoo-Specific Helper Methods

- (NSDictionary *)parseYahooChartResponse:(NSDictionary *)jsonResponse forSymbol:(NSString *)symbol {
    // Yahoo chart API structure: chart.result[0].meta contains current quote info
    NSDictionary *chart = jsonResponse[@"chart"];
    if (!chart) return nil;
    
    NSArray *results = chart[@"result"];
    if (!results || results.count == 0) return nil;
    
    NSDictionary *result = results[0];
    NSDictionary *meta = result[@"meta"];
    
    if (!meta) return nil;
    
    // For quotes, we primarily use meta information
    // For historical data, we'd also process timestamps and indicators
    return @{
        @"meta": meta,
        @"result": result,
        @"currentValues": @{
            @"price": meta[@"regularMarketPrice"] ?: @0,
            @"change": @([meta[@"regularMarketPrice"] doubleValue] - [meta[@"previousClose"] doubleValue]),
            @"volume": meta[@"regularMarketVolume"] ?: @0
        }
    };
}

- (NSDictionary *)extractMetadataFromYahooResponse:(NSDictionary *)yahooResult {
    return yahooResult[@"meta"] ?: @{};
}

- (NSArray<NSDate *> *)convertYahooTimestamps:(NSArray<NSNumber *> *)timestamps {
    NSMutableArray<NSDate *> *dates = [NSMutableArray array];
    
    for (NSNumber *timestamp in timestamps) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue];
        [dates addObject:date];
    }
    
    return [dates copy];
}

- (BOOL)isValidYahooResponse:(NSDictionary *)response {
    if (!response || ![response isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    // Check for basic Yahoo API structure
    NSDictionary *chart = response[@"chart"];
    if (!chart) return NO;
    
    NSArray *results = chart[@"result"];
    if (!results || results.count == 0) return NO;
    
    // Check for error in Yahoo response
    NSArray *errors = chart[@"error"];
    if (errors && errors.count > 0) {
        NSLog(@"❌ YahooDataAdapter: Yahoo API returned error: %@", errors);
        return NO;
    }
    
    return YES;
}

- (NSString *)sourceName {
    return @"Yahoo Finance API";
}

@end
