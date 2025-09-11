//
//  OtherDataSource+TickData.m
//  TradingApp
//
//  FIXED: Correct parsing for Nasdaq tick data response structure
//

#import "OtherDataSource+TickData.h"
#import "OtherDataSource+Private.h"

// Nasdaq tick data endpoints
static NSString *const kNasdaqRealtimeTradesURL = @"https://api.nasdaq.com/api/quote/%@/realtime-trades";
static NSString *const kNasdaqExtendedTradingURL = @"https://api.nasdaq.com/api/quote/%@/extended-trading";

@implementation OtherDataSource (TickData)

#pragma mark - Tick Data Methods

- (void)fetchRealtimeTradesForSymbol:(NSString *)symbol
                               limit:(NSInteger)limit
                            fromTime:(NSString *)fromTime
                          completion:(void (^)(NSArray *trades, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // Build URL with parameters
    NSString *baseURL = [NSString stringWithFormat:kNasdaqRealtimeTradesURL, symbol.uppercaseString];
    NSMutableString *urlString = [baseURL mutableCopy];
    
    // Add query parameters
    [urlString appendString:@"?"];
    
    if (limit > 0) {
        [urlString appendFormat:@"limit=%ld&", (long)limit];
    } else {
        [urlString appendString:@"limit=999999999&"];  // Max trades
    }
    
    if (fromTime && fromTime.length > 0) {
        [urlString appendFormat:@"fromTime=%@&", fromTime];
    } else {
        [urlString appendString:@"fromTime=9:30&"];  // Default market open
    }
    
    // Remove trailing &
    if ([urlString hasSuffix:@"&"]) {
        [urlString deleteCharactersInRange:NSMakeRange(urlString.length - 1, 1)];
    }
    
    NSLog(@"🔄 Fetching realtime trades: %@", urlString);
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"❌ Error fetching realtime trades for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        // 🆕 FIX: Use specific tick data extraction method
        NSArray *tradesData = [self extractTickDataFromNasdaqResponse:response];
        NSMutableArray *trades = [NSMutableArray array];
        
        for (NSDictionary *item in tradesData) {
            // 🆕 FIX: Parse the actual Nasdaq tick data structure
            NSDictionary *trade = [self parseNasdaqTickItem:item forSymbol:symbol];
            if (trade) {
                [trades addObject:trade];
            }
        }
        
        NSLog(@"✅ Fetched %lu realtime trades for %@", (unsigned long)trades.count, symbol);
        if (completion) completion([trades copy], nil);
    }];
}

- (void)fetchExtendedTradingForSymbol:(NSString *)symbol
                           marketType:(NSString *)marketType
                           completion:(void (^)(NSArray *trades, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // Validate market type
    if (!marketType || (![marketType isEqualToString:@"pre"] && ![marketType isEqualToString:@"post"])) {
        marketType = @"post";  // Default to after-hours
    }
    
    // Build URL
    NSString *urlString = [NSString stringWithFormat:@"%@?markettype=%@&assetclass=stocks&time=2",
                          [NSString stringWithFormat:kNasdaqExtendedTradingURL, symbol.uppercaseString],
                          marketType];
    
    NSLog(@"🔄 Fetching extended trading (%@): %@", marketType, urlString);
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"❌ Error fetching extended trading for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        // 🆕 FIX: Use specific tick data extraction method
        NSArray *tradesData = [self extractTickDataFromNasdaqResponse:response];
        NSMutableArray *trades = [NSMutableArray array];
        
        for (NSDictionary *item in tradesData) {
            // 🆕 FIX: Parse the actual Nasdaq tick data structure
            NSDictionary *trade = [self parseNasdaqTickItem:item forSymbol:symbol];
            if (trade) {
                // Add market type for extended hours
                NSMutableDictionary *mutableTrade = [trade mutableCopy];
                mutableTrade[@"marketType"] = marketType;
                [trades addObject:[mutableTrade copy]];
            }
        }
        
        NSLog(@"✅ Fetched %lu extended trading (%@) for %@", (unsigned long)trades.count, marketType, symbol);
        if (completion) completion([trades copy], nil);
    }];
}

- (void)fetchFullSessionTradesForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray *trades, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSMutableArray *allTrades = [NSMutableArray array];
    __block NSInteger completedRequests = 0;
    __block NSError *lastError = nil;
    
    void (^checkCompletion)(void) = ^{
        completedRequests++;
        if (completedRequests >= 3) {
            if (allTrades.count > 0) {
                // Sort by timestamp (most recent first)
                NSArray *sortedTrades = [allTrades sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
                    NSString *time1 = obj1[@"timestamp"] ?: @"";
                    NSString *time2 = obj2[@"timestamp"] ?: @"";
                    return [time2 compare:time1]; // Descending order
                }];
                if (completion) completion(sortedTrades, nil);
            } else {
                if (completion) completion(@[], lastError);
            }
        }
    };
    
    // Fetch pre-market data
    [self fetchExtendedTradingForSymbol:symbol marketType:@"pre" completion:^(NSArray *trades, NSError *error) {
        if (trades) [allTrades addObjectsFromArray:trades];
        if (error) lastError = error;
        checkCompletion();
    }];
    
    // Fetch regular hours data
    [self fetchRealtimeTradesForSymbol:symbol limit:0 fromTime:@"9:30" completion:^(NSArray *trades, NSError *error) {
        if (trades) [allTrades addObjectsFromArray:trades];
        if (error) lastError = error;
        checkCompletion();
    }];
    
    // Fetch after-hours data
    [self fetchExtendedTradingForSymbol:symbol marketType:@"post" completion:^(NSArray *trades, NSError *error) {
        if (trades) [allTrades addObjectsFromArray:trades];
        if (error) lastError = error;
        checkCompletion();
    }];
}

#pragma mark - 🆕 NEW: Specific Tick Data Parsing Methods

// Extract tick data specifically from Nasdaq response structure
- (NSArray *)extractTickDataFromNasdaqResponse:(id)response {
    if (![response isKindOfClass:[NSDictionary class]]) {
        NSLog(@"⚠️ Response is not a dictionary: %@", [response class]);
        return @[];
    }
    
    NSDictionary *dict = (NSDictionary *)response;
    
    // Log the response structure for debugging
    NSLog(@"📊 Response structure: %@", [dict allKeys]);
    
    // Navigate the Nasdaq tick data structure: data.rows
    if (dict[@"data"] && [dict[@"data"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dataDict = dict[@"data"];
        NSLog(@"📊 Data keys: %@", [dataDict allKeys]);
        
        if (dataDict[@"rows"] && [dataDict[@"rows"] isKindOfClass:[NSArray class]]) {
            NSArray *rows = dataDict[@"rows"];
            NSLog(@"✅ Found %lu tick data rows", (unsigned long)rows.count);
            return rows;
        }
    }
    
    // Fallback: try other common structures
    NSArray *fallback = [self extractDataFromNasdaqResponse:response];
    NSLog(@"🔄 Using fallback extraction, found %lu items", (unsigned long)fallback.count);
    return fallback;
}

// Parse individual Nasdaq tick item to standardized format
- (NSDictionary *)parseNasdaqTickItem:(NSDictionary *)item forSymbol:(NSString *)symbol {
    if (![item isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    // 🆕 FIX: Parse the actual Nasdaq field names from your response example
    
    // Extract price (remove $ and convert)
    NSString *priceString = item[@"nlsPrice"];
    double price = 0.0;
    if ([priceString isKindOfClass:[NSString class]]) {
        // Remove $ symbol and commas, then convert to double
        NSString *cleanPrice = [priceString stringByReplacingOccurrencesOfString:@"$" withString:@""];
        cleanPrice = [cleanPrice stringByReplacingOccurrencesOfString:@"," withString:@""];
        cleanPrice = [cleanPrice stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        price = [cleanPrice doubleValue];
    } else if ([priceString isKindOfClass:[NSNumber class]]) {
        price = [(NSNumber *)priceString doubleValue];
    }
    
    // Extract volume
    id volumeValue = item[@"nlsShareVolume"];
    NSInteger volume = 0;
    if ([volumeValue isKindOfClass:[NSString class]]) {
        // Remove commas and convert to integer
        NSString *cleanVolume = [volumeValue stringByReplacingOccurrencesOfString:@"," withString:@""];
        volume = [cleanVolume integerValue];
    } else if ([volumeValue isKindOfClass:[NSNumber class]]) {
        volume = [(NSNumber *)volumeValue integerValue];
    }
    
    // Extract timestamp
    NSString *timeString = item[@"nlsTime"];
    if (![timeString isKindOfClass:[NSString class]]) {
        timeString = @"";
    }
    
    // Extract other fields (may be empty for basic tick data)
    NSString *exchange = item[@"exchange"] ?: @"NASDAQ";
    NSString *conditions = item[@"conditions"] ?: @"";
    NSString *marketCenter = item[@"marketCenter"] ?: @"";
    
    // Calculate dollar volume
    double dollarVolume = price * volume;
    
    // Validate we have minimum required data
    if (price <= 0 || volume <= 0) {
        NSLog(@"⚠️ Invalid tick data - price: %.4f, volume: %ld", price, (long)volume);
        return nil;
    }
    
    // Create standardized trade dictionary
    NSDictionary *trade = @{
        @"symbol": symbol.uppercaseString,
        @"timestamp": timeString,
        @"price": @(price),
        @"size": @(volume),                    // Map nlsShareVolume to size
        @"volume": @(volume),                  // Also keep as volume for compatibility
        @"exchange": exchange,
        @"conditions": conditions,
        @"marketCenter": marketCenter,
        @"dollarVolume": @(dollarVolume),
        
        // 🆕 Keep original Nasdaq field names for reference
        @"nlsPrice": priceString ?: @"",
        @"nlsShareVolume": volumeValue ?: @0,
        @"nlsTime": timeString
    };
    
    return trade;
}

#pragma mark - 🆕 NEW: Enhanced Logging and Debugging

- (void)logNasdaqResponseStructure:(id)response forSymbol:(NSString *)symbol {
    NSLog(@"📊 === Nasdaq Response Debug for %@ ===", symbol);
    
    if ([response isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)response;
        NSLog(@"📊 Top-level keys: %@", [dict allKeys]);
        
        if (dict[@"data"]) {
            NSLog(@"📊 Data type: %@", [dict[@"data"] class]);
            if ([dict[@"data"] isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dataDict = dict[@"data"];
                NSLog(@"📊 Data keys: %@", [dataDict allKeys]);
                
                if (dataDict[@"rows"]) {
                    NSLog(@"📊 Rows type: %@", [dataDict[@"rows"] class]);
                    if ([dataDict[@"rows"] isKindOfClass:[NSArray class]]) {
                        NSArray *rows = dataDict[@"rows"];
                        NSLog(@"📊 Found %lu rows", (unsigned long)rows.count);
                        
                        if (rows.count > 0) {
                            NSDictionary *firstRow = rows[0];
                            if ([firstRow isKindOfClass:[NSDictionary class]]) {
                                NSLog(@"📊 First row keys: %@", [firstRow allKeys]);
                                NSLog(@"📊 Sample data: %@", firstRow);
                            }
                        }
                    }
                }
            }
        }
        
        if (dict[@"status"]) {
            NSLog(@"📊 Status: %@", dict[@"status"]);
        }
        
        if (dict[@"message"]) {
            NSLog(@"📊 Message: %@", dict[@"message"]);
        }
    } else {
        NSLog(@"📊 Response is not a dictionary: %@", [response class]);
    }
    
    NSLog(@"📊 === End Debug ===");
}

@end
