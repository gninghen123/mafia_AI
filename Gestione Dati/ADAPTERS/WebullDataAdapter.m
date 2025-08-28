//
//  WebullDataAdapter.m
//  mafia_AI
//

#import "WebullDataAdapter.h"
#import "MarketData.h"
#import "RuntimeModels.h"
#import "TradingRuntimeModels.h"

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
    standardData[@"previousClose"] = rawData[@"preClose"] ?: rawData[@"pClose"];
    
    // Volume
    standardData[@"volume"] = rawData[@"volume"];
    
    // Change (Webull provides these directly)
    if (rawData[@"change"]) {
        standardData[@"change"] = rawData[@"change"];
    }
    
    if (rawData[@"changePct"]) {
        standardData[@"changePercent"] = rawData[@"changePct"];
    } else if (rawData[@"changeRatio"]) {
        // Webull sometimes uses changeRatio (as decimal, need to convert to percentage)
        double ratio = [rawData[@"changeRatio"] doubleValue];
        standardData[@"changePercent"] = @(ratio * 100.0);
    }
    
    // Timestamp
    if (rawData[@"timestamp"]) {
        NSNumber *timestamp = rawData[@"timestamp"];
        standardData[@"timestamp"] = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
    } else {
        standardData[@"timestamp"] = [NSDate date];
    }
    
    // Market status (simplified - would need more logic for Webull's status format)
    standardData[@"isMarketOpen"] = @([rawData[@"marketState"] integerValue] == 1);
    
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
    if (!rawData) {
        NSLog(@"❌ WebullAdapter: No raw data provided for %@", symbol);
        return @[];
    }
    
    NSLog(@"📊 WebullAdapter: Processing Webull historical data for %@", symbol);
    
    NSArray *webullBars = nil;
    
    // Webull historical data format can vary:
    // 1. Direct array of bar objects
    // 2. Dictionary with "data" key containing array
    // 3. Dictionary with nested structure
    
    if ([rawData isKindOfClass:[NSArray class]]) {
        webullBars = (NSArray *)rawData;
    } else if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dataDict = (NSDictionary *)rawData;
        
        // Try different possible keys
        webullBars = dataDict[@"data"] ?: dataDict[@"results"] ?: dataDict[@"bars"];
        
        // If still no array found, check if this dict itself contains bar data
        if (!webullBars && dataDict[@"open"] && dataDict[@"high"] && dataDict[@"low"] && dataDict[@"close"]) {
            // Single bar in dictionary format
            webullBars = @[dataDict];
        }
    } else {
        NSLog(@"❌ WebullAdapter: Unexpected raw data format: %@", [rawData class]);
        return @[];
    }
    
    if (!webullBars || ![webullBars isKindOfClass:[NSArray class]]) {
        NSLog(@"❌ WebullAdapter: No valid bars array found in Webull data");
        return @[];
    }
    
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray arrayWithCapacity:webullBars.count];
    
    for (id barItem in webullBars) {
        if (![barItem isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *barData = (NSDictionary *)barItem;
        
        // Create HistoricalBarModel from Webull bar data
        HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
        bar.symbol = symbol;
        
        // Webull timestamp handling - can be various formats
        NSDate *barDate = nil;
        if (barData[@"date"]) {
            if ([barData[@"date"] isKindOfClass:[NSString class]]) {
                // String date format - try to parse
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"yyyy-MM-dd"; // Common Webull format
                barDate = [formatter dateFromString:barData[@"date"]];
            } else if ([barData[@"date"] isKindOfClass:[NSNumber class]]) {
                // Unix timestamp
                barDate = [NSDate dateWithTimeIntervalSince1970:[barData[@"date"] doubleValue]];
            }
        } else if (barData[@"timestamp"]) {
            NSNumber *timestamp = barData[@"timestamp"];
            // Check if timestamp is in milliseconds (Webull sometimes uses this)
            double timestampValue = [timestamp doubleValue];
            if (timestampValue > 1e10) {
                // Likely milliseconds, convert to seconds
                timestampValue /= 1000.0;
            }
            barDate = [NSDate dateWithTimeIntervalSince1970:timestampValue];
        }
        
        if (!barDate) {
            NSLog(@"⚠️ WebullAdapter: No valid date found for bar, using current date");
            barDate = [NSDate date];
        }
        
        bar.date = barDate;
        
        // OHLCV data - Webull field names can vary
        bar.open = [barData[@"open"] doubleValue] ?: [barData[@"o"] doubleValue];
        bar.high = [barData[@"high"] doubleValue] ?: [barData[@"h"] doubleValue];
        bar.low = [barData[@"low"] doubleValue] ?: [barData[@"l"] doubleValue];
        bar.close = [barData[@"close"] doubleValue] ?: [barData[@"c"] doubleValue];
        bar.adjustedClose = bar.close; // Default to close if no adjusted close
        bar.volume = [barData[@"volume"] longLongValue] ?: [barData[@"v"] longLongValue];
        
        // Set timeframe (should be determined from context)
        bar.timeframe = BarTimeframeDaily; // Default
        
        // Basic validation
        if (bar.high >= bar.low && bar.high >= bar.open && bar.high >= bar.close &&
            bar.low <= bar.open && bar.low <= bar.close && bar.open > 0 && bar.close > 0) {
            [bars addObject:bar];
        } else {
            NSLog(@"⚠️ WebullAdapter: Skipping invalid bar data for %@", symbol);
        }
    }
    
    // Sort by date
    [bars sortUsingComparator:^NSComparisonResult(HistoricalBarModel *bar1, HistoricalBarModel *bar2) {
        return [bar1.date compare:bar2.date];
    }];
    
    NSLog(@"✅ WebullAdapter: Created %lu HistoricalBarModel objects for %@",
          (unsigned long)bars.count, symbol);
    
    return [bars copy];
}

- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol {
    // Webull order book data (if available in their API)
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return @{
            @"symbol": symbol,
            @"bids": @[],
            @"asks": @[],
            @"timestamp": [NSDate date]
        };
    }
    
    NSDictionary *orderBookData = (NSDictionary *)rawData;
    NSMutableArray *bids = [NSMutableArray array];
    NSMutableArray *asks = [NSMutableArray array];
    
    // Process bids - Webull format
    NSArray *rawBids = orderBookData[@"bidList"] ?: orderBookData[@"bids"];
    for (NSDictionary *bidData in rawBids) {
        if ([bidData isKindOfClass:[NSDictionary class]]) {
            NSDictionary *standardizedBid = @{
                @"price": bidData[@"price"] ?: @0,
                @"size": bidData[@"volume"] ?: bidData[@"size"] ?: @0,
                @"side": @"bid"
            };
            [bids addObject:standardizedBid];
        }
    }
    
    // Process asks - Webull format
    NSArray *rawAsks = orderBookData[@"askList"] ?: orderBookData[@"asks"];
    for (NSDictionary *askData in rawAsks) {
        if ([askData isKindOfClass:[NSDictionary class]]) {
            NSDictionary *standardizedAsk = @{
                @"price": askData[@"price"] ?: @0,
                @"size": askData[@"volume"] ?: askData[@"size"] ?: @0,
                @"side": @"ask"
            };
            [asks addObject:standardizedAsk];
        }
    }
    
    return @{
        @"symbol": symbol,
        @"bids": [bids copy],
        @"asks": [asks copy],
        @"timestamp": orderBookData[@"timestamp"] ? [NSDate dateWithTimeIntervalSince1970:[orderBookData[@"timestamp"] doubleValue]] : [NSDate date]
    };
}

- (nullable AdvancedPositionModel *)standardizePositionData:(NSDictionary *)rawData {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedPositionModel *position = [[AdvancedPositionModel alloc] init];
    
    // Basic position info - Webull field mapping
    position.symbol = rawData[@"ticker"][@"symbol"] ?: rawData[@"symbol"] ?: @"";
    position.accountId = rawData[@"accountId"] ?: @"";
    
    // Quantity - Webull uses different fields
    position.quantity = [rawData[@"position"] doubleValue] ?: [rawData[@"qty"] doubleValue];
    
    // Average cost
    position.avgCost = [rawData[@"costPrice"] doubleValue] ?: [rawData[@"avgPrice"] doubleValue];
    
    // Current market data
    position.currentPrice = [rawData[@"marketValue"] doubleValue] / position.quantity;
    if (position.currentPrice == 0) {
        position.currentPrice = [rawData[@"lastPrice"] doubleValue] ?: [rawData[@"price"] doubleValue];
    }
    
    // Market value
    position.marketValue = [rawData[@"marketValue"] doubleValue];
    if (position.marketValue == 0 && position.currentPrice > 0) {
        position.marketValue = position.quantity * position.currentPrice;
    }
    
    // P&L calculations
    double totalCost = position.quantity * position.avgCost;
    position.unrealizedPL = [rawData[@"unrealizedPnl"] doubleValue];
    if (position.unrealizedPL == 0) {
        position.unrealizedPL = position.marketValue - totalCost;
    }
    
    if (totalCost != 0) {
        position.unrealizedPLPercent = (position.unrealizedPL / totalCost) * 100.0;
    }
    
    // Additional market data (if available from Webull)
    position.bidPrice = [rawData[@"bid"] doubleValue];
    position.askPrice = [rawData[@"ask"] doubleValue];
    position.dayHigh = [rawData[@"high"] doubleValue];
    position.dayLow = [rawData[@"low"] doubleValue];
    position.dayOpen = [rawData[@"open"] doubleValue];
    position.previousClose = [rawData[@"pclose"] doubleValue] ?: [rawData[@"preClose"] doubleValue];
    position.volume = [rawData[@"volume"] integerValue];
    
    position.priceLastUpdated = [NSDate date];
    
    NSLog(@"✅ WebullAdapter: Created AdvancedPositionModel for %@ - %.0f shares @ $%.2f",
          position.symbol, position.quantity, position.avgCost);
    
    return position;
}

- (nullable AdvancedOrderModel *)standardizeOrderData:(NSDictionary *)rawData {
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedOrderModel *order = [[AdvancedOrderModel alloc] init];
    
    // Basic order info - Webull field mapping
    order.orderId = rawData[@"orderId"] ?: rawData[@"id"] ?: @"";
    order.accountId = rawData[@"accountId"] ?: @"";
    order.symbol = rawData[@"ticker"][@"symbol"] ?: rawData[@"symbol"] ?: @"";
    
    // Order type mapping from Webull
    NSString *webullOrderType = rawData[@"orderType"] ?: @"";
    order.orderType = [self mapWebullOrderTypeToStandard:webullOrderType];
    
    // Side mapping
    NSString *action = rawData[@"action"] ?: rawData[@"side"] ?: @"";
    order.side = [action isEqualToString:@"BUY"] ? @"BUY" : @"SELL";
    
    // Status mapping
    NSString *status = rawData[@"status"] ?: @"";
    order.status = [self mapWebullStatusToStandard:status];
    
    // Time in force
    NSString *timeInForce = rawData[@"timeInForce"] ?: @"";
    order.timeInForce = [timeInForce isEqualToString:@"GTC"] ? @"GTC" : @"DAY";
    
    // Quantities and prices
    order.quantity = [rawData[@"totalQuantity"] doubleValue] ?: [rawData[@"qty"] doubleValue];
    order.filledQuantity = [rawData[@"filledQuantity"] doubleValue] ?: [rawData[@"filled"] doubleValue];
    order.price = [rawData[@"lmtPrice"] doubleValue] ?: [rawData[@"price"] doubleValue];
    order.stopPrice = [rawData[@"auxPrice"] doubleValue] ?: [rawData[@"stopPrice"] doubleValue];
    order.avgFillPrice = [rawData[@"avgFillPrice"] doubleValue];
    
    // Dates - Webull timestamps
    NSNumber *createTime = rawData[@"createTime0"] ?: rawData[@"createTime"];
    if (createTime) {
        double timeValue = [createTime doubleValue];
        // Webull sometimes uses milliseconds
        if (timeValue > 1e10) {
            timeValue /= 1000.0;
        }
        order.createdDate = [NSDate dateWithTimeIntervalSince1970:timeValue];
    } else {
        order.createdDate = [NSDate date];
    }
    
    NSNumber *updateTime = rawData[@"updateTime0"] ?: rawData[@"updateTime"];
    if (updateTime) {
        double timeValue = [updateTime doubleValue];
        if (timeValue > 1e10) {
            timeValue /= 1000.0;
        }
        order.updatedDate = [NSDate dateWithTimeIntervalSince1970:timeValue];
    } else {
        order.updatedDate = order.createdDate;
    }
    
    // Additional fields
    order.instruction = order.side;
    order.orderStrategy = @"SINGLE";
    
    NSLog(@"✅ WebullAdapter: Created AdvancedOrderModel %@ for %@ - %@ %.0f shares @ $%.2f",
          order.orderId, order.symbol, order.side, order.quantity, order.price);
    
    return order;
}

- (NSArray<AccountModel *> *)standardizeAccountData:(id)rawData {
    NSMutableArray<AccountModel *> *accounts = [NSMutableArray array];
    
    if ([rawData isKindOfClass:[NSArray class]]) {
        // Array of account data from Webull API
        NSArray *accountsArray = (NSArray *)rawData;
        
        for (id accountItem in accountsArray) {
            if ([accountItem isKindOfClass:[NSDictionary class]]) {
                AccountModel *account = [self createAccountModelFromWebullDictionary:(NSDictionary *)accountItem];
                if (account) {
                    [accounts addObject:account];
                }
            }
        }
        
    } else if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *accountData = (NSDictionary *)rawData;
        
        // Check if it's a wrapper with accounts array
        if (accountData[@"accounts"] || accountData[@"data"]) {
            NSArray *accountsList = accountData[@"accounts"] ?: accountData[@"data"];
            return [self standardizeAccountData:accountsList];
        } else {
            // Single account dictionary
            AccountModel *account = [self createAccountModelFromWebullDictionary:accountData];
            if (account) {
                [accounts addObject:account];
            }
        }
    }
    
    NSLog(@"✅ WebullAdapter: Created %lu AccountModel objects", (unsigned long)accounts.count);
    return [accounts copy];
}

#pragma mark - Helper Methods

- (AccountModel *)createAccountModelFromWebullDictionary:(NSDictionary *)accountDict {
    if (!accountDict || ![accountDict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AccountModel *account = [[AccountModel alloc] init];
    
    // Webull account fields
    account.accountId = accountDict[@"accountId"] ?: accountDict[@"id"] ?: @"";
    account.accountType = [self mapWebullAccountType:accountDict[@"accountType"]];
    account.brokerName = @"WEBULL";
    account.displayName = accountDict[@"nickname"] ?: [NSString stringWithFormat:@"WEBULL-%@", account.accountId];
    account.isConnected = [accountDict[@"status"] integerValue] == 1; // Webull active status
    account.isPrimary = [accountDict[@"isPrimary"] boolValue];
    account.lastUpdated = [NSDate date];
    
    NSLog(@"✅ WebullAdapter: Created AccountModel %@ (%@)", account.accountId, account.accountType);
    return account;
}

- (NSString *)mapWebullOrderTypeToStandard:(NSString *)webullOrderType {
    if ([webullOrderType isEqualToString:@"MKT"]) {
        return @"MARKET";
    } else if ([webullOrderType isEqualToString:@"LMT"]) {
        return @"LIMIT";
    } else if ([webullOrderType isEqualToString:@"STP"]) {
        return @"STOP";
    } else if ([webullOrderType isEqualToString:@"STP_LMT"]) {
        return @"STOP_LIMIT";
    }
    return webullOrderType; // Return as-is if no mapping
}

- (NSString *)mapWebullStatusToStandard:(NSString *)webullStatus {
    if ([webullStatus isEqualToString:@"Working"] || [webullStatus isEqualToString:@"Submitted"]) {
        return @"OPEN";
    } else if ([webullStatus isEqualToString:@"Pending"]) {
        return @"PENDING";
    } else if ([webullStatus isEqualToString:@"Filled"]) {
        return @"FILLED";
    } else if ([webullStatus isEqualToString:@"Cancelled"]) {
        return @"CANCELLED";
    } else if ([webullStatus isEqualToString:@"Rejected"]) {
        return @"REJECTED";
    }
    return webullStatus; // Return as-is if no mapping
}

- (NSString *)mapWebullAccountType:(id)accountType {
    if ([accountType isEqualToString:@"1"] || [accountType integerValue] == 1) {
        return @"CASH";
    } else if ([accountType isEqualToString:@"2"] || [accountType integerValue] == 2) {
        return @"MARGIN";
    } else if ([accountType isEqualToString:@"5"] || [accountType integerValue] == 5) {
        return @"IRA";
    }
    return @"UNKNOWN";
}

#pragma mark - Market List Standardization (NEW)

#pragma mark - Market List Standardization (NEW)

- (NSArray<MarketPerformerModel *> *)standardizeMarketListData:(id)rawData
                                                      listType:(NSString *)listType
                                                     timeframe:(NSString *)timeframe {
    
    if (!rawData) {
        NSLog(@"❌ WebullAdapter: No raw data provided for market list %@", listType);
        return @[];
    }
    
    NSLog(@"📊 WebullAdapter: Standardizing Webull market list data for %@ (%@)", listType, timeframe);
    NSLog(@"📊 WebullAdapter: Input data type: %@", [rawData class]);
    
    NSArray *webullMarketArray = nil;
    
    // Webull market list format analysis from real data:
    // rawData is NSArray of dictionaries, each containing:
    // - "ticker": {complete stock data}
    // - "values": {simplified price data}
    
    if ([rawData isKindOfClass:[NSArray class]]) {
        webullMarketArray = (NSArray *)rawData;
    } else {
        NSLog(@"❌ WebullAdapter: Expected NSArray for Webull market data, got %@", [rawData class]);
        return @[];
    }
    
    if (webullMarketArray.count == 0) {
        NSLog(@"❌ WebullAdapter: Empty array for Webull market data");
        return @[];
    }
    
    NSMutableArray<MarketPerformerModel *> *performers = [NSMutableArray array];
    NSInteger rank = 1; // Track ranking position
    
    for (id item in webullMarketArray) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            NSLog(@"⚠️ WebullAdapter: Skipping non-dictionary item in market list");
            continue;
        }
        
        NSDictionary *webullItem = (NSDictionary *)item;
        
        // Extract ticker and values sections
        NSDictionary *ticker = webullItem[@"ticker"];
        NSDictionary *values = webullItem[@"values"];
        
        if (!ticker || ![ticker isKindOfClass:[NSDictionary class]]) {
            NSLog(@"⚠️ WebullAdapter: Missing or invalid ticker data in market item");
            continue;
        }
        
        MarketPerformerModel *performer = [self createMarketPerformerFromWebullTicker:ticker
                                                                               values:values
                                                                             listType:listType
                                                                            timeframe:timeframe
                                                                                 rank:rank];
        
        if (performer) {
            [performers addObject:performer];
            rank++;
        }
    }
    
    NSLog(@"✅ WebullAdapter: Created %lu MarketPerformerModel objects for %@ (%@)",
          (unsigned long)performers.count, listType, timeframe);
    
    return [performers copy];
}

#pragma mark - Helper Methods

- (MarketPerformerModel *)createMarketPerformerFromWebullTicker:(NSDictionary *)ticker
                                                         values:(NSDictionary *)values
                                                       listType:(NSString *)listType
                                                      timeframe:(NSString *)timeframe
                                                           rank:(NSInteger)rank {
    
    MarketPerformerModel *performer = [[MarketPerformerModel alloc] init];
    
    // Basic info from ticker section
    performer.symbol = ticker[@"symbol"] ?: ticker[@"disSymbol"];
    performer.name = ticker[@"name"];
    performer.exchange = ticker[@"disExchangeCode"] ?: ticker[@"exchangeCode"];
    performer.sector = ticker[@"sector"]; // Webull might not provide this in market lists
    
    // Price data - prefer values section, fallback to ticker
    // Current price
    NSNumber *currentPrice = values[@"price"] ?: ticker[@"close"] ?: ticker[@"price"];
    performer.price = currentPrice;
    
    // Change - Webull provides this directly
    NSNumber *change = values[@"change"] ?: ticker[@"change"];
    performer.change = change;
    
    // Change percent - Webull uses changeRatio (as decimal, need to convert to percentage)
    NSNumber *changeRatio = values[@"changeRatio"] ?: ticker[@"changeRatio"];
    if (changeRatio) {
        double ratio = [changeRatio doubleValue];
        // Webull changeRatio is already a decimal ratio (e.g., 0.2895 = 28.95%)
        performer.changePercent = @(ratio * 100.0);
    } else {
        // Fallback: calculate from change and price
        if (change && currentPrice && [currentPrice doubleValue] > 0 && [change doubleValue] != 0) {
            double changeValue = [change doubleValue];
            double priceValue = [currentPrice doubleValue];
            double prevClose = priceValue - changeValue;
            if (prevClose > 0) {
                double changePercent = (changeValue / prevClose) * 100.0;
                performer.changePercent = @(changePercent);
            }
        }
    }
    
    // Volume - from ticker section
    performer.volume = ticker[@"volume"];
    
    // Market cap - Webull provides marketValue
    performer.marketCap = ticker[@"marketValue"];
    
    // Average volume - not typically provided in Webull market lists
    performer.avgVolume = ticker[@"avgVolume"]; // This will likely be nil
    
    // Additional data from ticker
    // turnoverRate could be used as a volume indicator
    NSNumber *turnoverRate = ticker[@"turnoverRate"];
    if (turnoverRate && !performer.avgVolume) {
        // turnoverRate is in percentage, could indicate liquidity
        // Don't set as avgVolume since it's not the same thing
    }
    
    // List metadata
    performer.listType = listType;
    performer.timeframe = timeframe;
    performer.rank = rank;
    performer.timestamp = [NSDate date];
    
    // Validation - must have at least symbol and price
    if (!performer.symbol || !performer.price) {
        NSLog(@"⚠️ WebullAdapter: Skipping invalid market item - Symbol: %@, Price: %@",
              performer.symbol, performer.price);
        return nil;
    }
    
    NSLog(@"✅ WebullAdapter: Created performer - %@ at $%.4f (%+.2f%%)",
          performer.symbol,
          [performer.price doubleValue],
          [performer.changePercent doubleValue]);
    
    return performer;
}

// Legacy helper method (simplified, no longer using multiple key fallbacks)
- (NSNumber *)extractNumberValue:(NSDictionary *)data forKeys:(NSArray<NSString *> *)possibleKeys {
    for (NSString *key in possibleKeys) {
        id value = data[key];
        if (value && ![value isEqual:[NSNull null]]) {
            if ([value isKindOfClass:[NSNumber class]]) {
                return (NSNumber *)value;
            } else if ([value isKindOfClass:[NSString class]]) {
                NSString *stringValue = (NSString *)value;
                // Try to parse as number
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                formatter.numberStyle = NSNumberFormatterDecimalStyle;
                NSNumber *parsedNumber = [formatter numberFromString:stringValue];
                if (parsedNumber) {
                    return parsedNumber;
                }
            }
        }
    }
    return nil;
}

#pragma mark - Helper Methods

- (MarketPerformerModel *)createMarketPerformerFromWebullData:(NSDictionary *)webullData
                                                     listType:(NSString *)listType
                                                    timeframe:(NSString *)timeframe
                                                         rank:(NSInteger)rank {
    
    MarketPerformerModel *performer = [[MarketPerformerModel alloc] init];
    
    // Basic info - Webull field mapping
    performer.symbol = webullData[@"symbol"] ?: webullData[@"ticker"] ?: webullData[@"tickerId"];
    performer.name = webullData[@"name"] ?: webullData[@"disSymbol"] ?: webullData[@"shortName"];
    performer.exchange = webullData[@"exchange"] ?: webullData[@"exchangeCode"];
    performer.sector = webullData[@"sector"] ?: webullData[@"industryName"];
    
    // Price data - Webull specific fields
    performer.price = [self extractNumberValue:webullData forKeys:@[@"price", @"close", @"lastPrice"]];
    performer.change = [self extractNumberValue:webullData forKeys:@[@"change", @"priceChange"]];
    
    // Change percent - Webull might use different formats
    NSNumber *changePercent = [self extractNumberValue:webullData forKeys:@[@"changePct", @"changePercent", @"changeRatio"]];
    if (changePercent) {
        // Check if it's a ratio (0.05) vs percentage (5.0)
        double changeValue = [changePercent doubleValue];
        if (fabs(changeValue) < 1.0 && performer.price && performer.change) {
            // Seems like a ratio, convert to percentage
            performer.changePercent = @(changeValue * 100.0);
        } else {
            performer.changePercent = changePercent;
        }
    }
    
    // Volume
    performer.volume = [self extractNumberValue:webullData forKeys:@[@"volume", @"vol", @"turnoverRate"]];
    
    // Market cap - Webull specific
    performer.marketCap = [self extractNumberValue:webullData forKeys:@[@"marketCap", @"marketValue", @"totalShares"]];
    
    // Average volume
    performer.avgVolume = [self extractNumberValue:webullData forKeys:@[@"avgVolume", @"avgVol", @"averageVolume"]];
    
    // List metadata
    performer.listType = listType;
    performer.timeframe = timeframe;
    performer.rank = rank;
    performer.timestamp = [NSDate date];
    
    // Validation - must have at least symbol and price
    if (!performer.symbol || !performer.price) {
        NSLog(@"⚠️ WebullAdapter: Skipping invalid market item - missing symbol or price");
        return nil;
    }
    
    return performer;
}


@end
