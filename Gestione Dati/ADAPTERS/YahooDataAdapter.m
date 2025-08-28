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
#import "TradingRuntimeModels.h"
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
    if (!rawData) {
        NSLog(@"❌ YahooDataAdapter: No raw data provided for %@", symbol);
        return @[];
    }
    
    NSLog(@"📊 YahooDataAdapter: Processing Yahoo historical data for %@ - Input type: %@", symbol, [rawData class]);
    
    // Yahoo returns an NSArray with a single NSDictionary containing all the chart data
    NSArray *yahooArray = nil;
    if ([rawData isKindOfClass:[NSArray class]]) {
        yahooArray = (NSArray *)rawData;
    } else {
        NSLog(@"❌ YahooDataAdapter: Expected NSArray for Yahoo historical data, got %@", [rawData class]);
        return @[];
    }
    
    if (yahooArray.count == 0) {
        NSLog(@"❌ YahooDataAdapter: Empty array for Yahoo historical data");
        return @[];
    }
    
    // Get the first (and only) dictionary from the array
    NSDictionary *yahooDataDict = yahooArray.firstObject;
    if (![yahooDataDict isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ YahooDataAdapter: Expected NSDictionary in Yahoo array, got %@", [yahooDataDict class]);
        return @[];
    }
    
    // Extract timestamps array
    NSArray *timestamps = yahooDataDict[@"timestamp"];
    if (!timestamps || ![timestamps isKindOfClass:[NSArray class]]) {
        NSLog(@"❌ YahooDataAdapter: No timestamps found in Yahoo data");
        return @[];
    }
    
    // Extract indicators -> quote data
    NSDictionary *indicators = yahooDataDict[@"indicators"];
    if (!indicators || ![indicators isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ YahooDataAdapter: No indicators found in Yahoo data");
        return @[];
    }
    
    NSArray *quoteArray = indicators[@"quote"];
    if (!quoteArray || ![quoteArray isKindOfClass:[NSArray class]] || quoteArray.count == 0) {
        NSLog(@"❌ YahooDataAdapter: No quote data found in indicators");
        return @[];
    }
    
    // Get the first quote object (Yahoo structure)
    NSDictionary *quoteData = quoteArray.firstObject;
    if (!quoteData || ![quoteData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ YahooDataAdapter: Invalid quote data structure");
        return @[];
    }
    
    // Extract OHLCV arrays
    NSArray *opens = quoteData[@"open"];
    NSArray *highs = quoteData[@"high"];
    NSArray *lows = quoteData[@"low"];
    NSArray *closes = quoteData[@"close"];
    NSArray *volumes = quoteData[@"volume"];
    
    if (!opens || !highs || !lows || !closes || !volumes) {
        NSLog(@"❌ YahooDataAdapter: Missing OHLCV data in Yahoo response");
        return @[];
    }
    
    NSInteger barCount = timestamps.count;
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray arrayWithCapacity:barCount];
    
    for (NSInteger i = 0; i < barCount; i++) {
        // Create HistoricalBarModel
        HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
        bar.symbol = symbol;
        
        // Convert timestamp (Yahoo uses Unix timestamp)
        NSNumber *timestamp = timestamps[i];
        if (timestamp) {
            bar.date = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
        } else {
            continue; // Skip bars without valid timestamp
        }
        
        // OHLCV data - Yahoo sometimes has null values
        NSNumber *open = i < opens.count ? opens[i] : nil;
        NSNumber *high = i < highs.count ? highs[i] : nil;
        NSNumber *low = i < lows.count ? lows[i] : nil;
        NSNumber *close = i < closes.count ? closes[i] : nil;
        NSNumber *volume = i < volumes.count ? volumes[i] : nil;
        
        // Skip bars with null essential data
        if (!open || !high || !low || !close || [open isEqual:[NSNull null]] ||
            [high isEqual:[NSNull null]] || [low isEqual:[NSNull null]] || [close isEqual:[NSNull null]]) {
            continue;
        }
        
        bar.open = [open doubleValue];
        bar.high = [high doubleValue];
        bar.low = [low doubleValue];
        bar.close = [close doubleValue];
        bar.adjustedClose = bar.close; // Yahoo doesn't always provide adjusted close in this format
        bar.volume = volume ? [volume longLongValue] : 0;
        
        // Set default timeframe (should be determined from context)
        bar.timeframe = BarTimeframeDaily; // Default
        
        [bars addObject:bar];
    }
    
    NSLog(@"✅ YahooDataAdapter: Created %lu HistoricalBarModel objects for %@",
          (unsigned long)bars.count, symbol);
    
    return [bars copy];
}

- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol {
    // Yahoo Finance doesn't typically provide order book data in free tier
    NSLog(@"⚠️ YahooDataAdapter: Order book data not available from Yahoo Finance free tier");
    return @{
        @"symbol": symbol,
        @"bids": @[],
        @"asks": @[],
        @"timestamp": [NSDate date]
    };
}

- (NSDictionary *)standardizeBatchQuotesData:(id)rawData forSymbols:(NSArray<NSString *> *)symbols {
    if (![rawData isKindOfClass:[NSDictionary class]]) {
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

#pragma mark - Portfolio/Trading Methods (Not Available for Yahoo)

- (nullable AdvancedPositionModel *)standardizePositionData:(NSDictionary *)rawData {
    // Yahoo Finance doesn't provide portfolio data - this would be for Yahoo-connected brokers
    NSLog(@"⚠️ YahooDataAdapter: Position data not available from Yahoo Finance");
    return nil;
}

- (nullable AdvancedOrderModel *)standardizeOrderData:(NSDictionary *)rawData {
    // Yahoo Finance doesn't provide order data
    NSLog(@"⚠️ YahooDataAdapter: Order data not available from Yahoo Finance");
    return nil;
}

- (NSArray<AccountModel *> *)standardizeAccountData:(id)rawData {
    // Yahoo Finance doesn't provide account data
    NSLog(@"⚠️ YahooDataAdapter: Account data not available from Yahoo Finance");
    return @[];
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
