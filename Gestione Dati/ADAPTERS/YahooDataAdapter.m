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
    
    NSLog(@"📊 YahooDataAdapter: Processing Yahoo quote for %@", symbol);
    
    // Parse Yahoo chart response structure
    NSDictionary *parsedData = [self parseYahooChartResponse:rawData forSymbol:symbol];
    if (!parsedData) {
        NSLog(@"❌ YahooDataAdapter: Failed to parse Yahoo chart response for %@", symbol);
        return nil;
    }
    
    // Extract metadata and current values
    NSDictionary *meta = parsedData[@"meta"];
    NSDictionary *currentValues = parsedData[@"currentValues"];
    
    if (!meta) {
        NSLog(@"❌ YahooDataAdapter: Missing meta in Yahoo response for %@", symbol);
        return nil;
    }
    
    // Create standardized MarketData
    NSMutableDictionary *standardData = [NSMutableDictionary dictionary];
    
    // Basic symbol info
    standardData[@"symbol"] = symbol;
    standardData[@"exchange"] = meta[@"exchangeName"] ?: @"Yahoo Finance";
    
    // Price data - Yahoo returns in meta for current quote
    NSNumber *regularPrice = meta[@"regularMarketPrice"];
    standardData[@"last"] = regularPrice ?: @0;
    standardData[@"close"] = regularPrice ?: @0;
    standardData[@"previousClose"] = meta[@"previousClose"] ?: @0;
    standardData[@"open"] = meta[@"regularMarketOpen"] ?: @0;
    standardData[@"high"] = meta[@"regularMarketDayHigh"] ?: @0;
    standardData[@"low"] = meta[@"regularMarketDayLow"] ?: @0;
    
    // Volume
    standardData[@"volume"] = meta[@"regularMarketVolume"] ?: @0;
    
    // Calculate change and change percent
    double lastPrice = [regularPrice doubleValue];
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
    standardData[@"bid"] = meta[@"bid"] ?: regularPrice ?: @0;
    standardData[@"ask"] = meta[@"ask"] ?: regularPrice ?: @0;
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
    standardData[@"isMarketOpen"] = @([marketState isEqualToString:@"REGULAR"] ||
                                     [marketState isEqualToString:@"PRE"] ||
                                     [marketState isEqualToString:@"POST"]);
    
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
    
    // Extract chart data
    NSDictionary *chart = yahooDataDict[@"chart"];
    if (!chart) {
        NSLog(@"❌ YahooDataAdapter: No chart data found");
        return @[];
    }
    
    NSArray *results = chart[@"result"];
    if (!results || results.count == 0) {
        NSLog(@"❌ YahooDataAdapter: No chart results found");
        return @[];
    }
    
    NSDictionary *result = results[0];
    
    // Extract timestamps array
    NSArray *timestamps = result[@"timestamp"];
    if (!timestamps || ![timestamps isKindOfClass:[NSArray class]]) {
        NSLog(@"❌ YahooDataAdapter: No timestamps found in Yahoo data");
        return @[];
    }
    
    // Extract indicators -> quote data
    NSDictionary *indicators = result[@"indicators"];
    if (!indicators || ![indicators isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ YahooDataAdapter: No indicators found in Yahoo data");
        return @[];
    }
    
    NSArray *quoteArray = indicators[@"quote"];
    if (!quoteArray || quoteArray.count == 0) {
        NSLog(@"❌ YahooDataAdapter: No quote array found in indicators");
        return @[];
    }
    
    NSDictionary *quote = quoteArray[0]; // Yahoo sempre ha un solo quote object
    
    // Extract OHLCV arrays
    NSArray *opens = quote[@"open"];
    NSArray *highs = quote[@"high"];
    NSArray *lows = quote[@"low"];
    NSArray *closes = quote[@"close"];
    NSArray *volumes = quote[@"volume"];
    
    if (!opens || !highs || !lows || !closes || !volumes) {
        NSLog(@"❌ YahooDataAdapter: Missing OHLCV data in quote");
        return @[];
    }
    
    if (timestamps.count != opens.count) {
        NSLog(@"❌ YahooDataAdapter: Timestamp count (%lu) doesn't match OHLCV count (%lu)",
              (unsigned long)timestamps.count, (unsigned long)opens.count);
        return @[];
    }
    
    // Convert to HistoricalBarModel objects
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray array];
    
    for (NSInteger i = 0; i < timestamps.count; i++) {
        // Skip bars with null values
        if ([opens[i] isEqual:[NSNull null]] || [closes[i] isEqual:[NSNull null]]) {
            continue;
        }
        
        HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
        bar.symbol = symbol;
        bar.date = [NSDate dateWithTimeIntervalSince1970:[timestamps[i] doubleValue]];
        bar.open = [opens[i] doubleValue];
        bar.high = [highs[i] doubleValue];
        bar.low = [lows[i] doubleValue];
        bar.close = [closes[i] doubleValue];
        bar.adjustedClose = bar.close; // Yahoo adjustedClose is in separate array if needed
        bar.volume = [volumes[i] longLongValue];
        bar.timeframe = BarTimeframeDaily; // Default, should be determined from context
        bar.isPaddingBar = NO;
        
        // Basic validation
        if (bar.high >= bar.low && bar.high >= bar.open && bar.high >= bar.close &&
            bar.low <= bar.open && bar.low <= bar.close && bar.open > 0 && bar.close > 0) {
            [bars addObject:bar];
        } else {
            NSLog(@"⚠️ YahooDataAdapter: Skipping invalid bar data for %@ at %@", symbol, bar.date);
        }
    }
    
    // Sort by date
    [bars sortUsingComparator:^NSComparisonResult(HistoricalBarModel *bar1, HistoricalBarModel *bar2) {
        return [bar1.date compare:bar2.date];
    }];
    
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

#pragma mark - ✅ METODI DI PARSING SPOSTATI DAL DATASOURCE

- (NSDictionary *)parseYahooChartResponse:(NSDictionary *)jsonResponse forSymbol:(NSString *)symbol {
    // Yahoo chart API structure: chart.result[0].meta contains current quote info
    NSDictionary *chart = jsonResponse[@"chart"];
    if (!chart) {
        NSLog(@"❌ YahooDataAdapter: No chart in response");
        return nil;
    }
    
    NSArray *results = chart[@"result"];
    if (!results || results.count == 0) {
        NSLog(@"❌ YahooDataAdapter: No results in chart");
        return nil;
    }
    
    NSDictionary *result = results[0];
    NSDictionary *meta = result[@"meta"];
    
    if (!meta) {
        NSLog(@"❌ YahooDataAdapter: No meta in result");
        return nil;
    }
    
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

- (BOOL)isValidYahooResponse:(NSDictionary *)response {
    if (!response || ![response isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    // Check for basic Yahoo API structure
    NSDictionary *chart = response[@"chart"];
    if (!chart || ![chart isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    // ✅ FIX: Controllo sicuro per NSNull prima di chiamare count
    id resultsObj = chart[@"result"];
    if (!resultsObj || [resultsObj isEqual:[NSNull null]]) {
        return NO;
    }
    
    // Verifica che sia un array valido
    if (![resultsObj isKindOfClass:[NSArray class]]) {
        return NO;
    }
    
    NSArray *results = (NSArray *)resultsObj;
    if (results.count == 0) {
        return NO;
    }
    
    // ✅ FIX: Controllo sicuro anche per errors
    id errorsObj = chart[@"error"];
    if (errorsObj && ![errorsObj isEqual:[NSNull null]] && [errorsObj isKindOfClass:[NSArray class]]) {
        NSArray *errors = (NSArray *)errorsObj;
        if (errors.count > 0) {
            NSLog(@"YahooDataAdapter: Yahoo API returned error: %@", errors);
            return NO;
        }
    }
    
    return YES;
}

- (NSString *)sourceName {
    return @"Yahoo Finance API";
}

@end
