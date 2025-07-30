//
//  DataHub+MarketData.m
//  mafia_AI
//
//  Implementation with intelligent caching and automatic data fetching
//

#import "DataHub+MarketData.h"
#import "DataHub+Private.h"
#import "DataManager.h"
#import "DataHub+MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "MarketQuote+CoreDataClass.h"
#import "MarketPerformer+CoreDataClass.h"
#import "CompanyInfo+CoreDataClass.h"
#import "MarketData.h"


@implementation DataHub (MarketData)

#pragma mark - Data Freshness Management

- (NSTimeInterval)TTLForDataType:(DataFreshnessType)type {
    switch (type) {
        case DataFreshnessTypeQuote:
            return 10.0; // 10 seconds for quotes
        case DataFreshnessTypeMarketOverview:
            return 60.0; // 1 minute
        case DataFreshnessTypeHistorical:
            return 300.0; // 5 minutes
        case DataFreshnessTypeCompanyInfo:
            return 86400.0; // 24 hours
        case DataFreshnessTypeWatchlist:
            return INFINITY; // Never expires
    }
}

- (BOOL)isDataStale:(NSDate *)lastUpdate forType:(DataFreshnessType)type {
    if (!lastUpdate) return YES;
    
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:lastUpdate];
    NSTimeInterval ttl = [self TTLForDataType:type];
    
    return age > ttl;
}

- (BOOL)hasPendingRequestForSymbol:(NSString *)symbol dataType:(DataFreshnessType)type {
    NSString *requestKey = [self requestKeyForSymbol:symbol dataType:type];
    
    @synchronized(self.pendingRequests) {
        return self.pendingRequests[requestKey] != nil;
    }
}

- (NSString *)requestKeyForSymbol:(NSString *)symbol dataType:(DataFreshnessType)type {
    return [NSString stringWithFormat:@"%@_%ld", symbol, (long)type];
}

#pragma mark - Market Quotes with Smart Caching

- (void)getQuoteForSymbol:(NSString *)symbol
               completion:(void(^)(MarketQuote * _Nullable quote, BOOL isLive))completion {
    
    if (!symbol || !completion) return;
    
    NSLog(@"📊 DataHub: Getting quote for %@", symbol);
    
    // 1. Check memory cache first
    NSDictionary *cachedData = [self getDataForSymbol:symbol];
    MarketQuote *quote = nil;
    BOOL needsFresh = YES;
    
    // 2. Check Core Data
    if (!cachedData) {
        quote = [self fetchQuoteFromCoreData:symbol];
    }
    
    // 3. Determine if data is fresh
    if (quote && quote.lastUpdate) {
        needsFresh = [self isDataStale:quote.lastUpdate forType:DataFreshnessTypeQuote];
    }
    
    // 4. Return cached data immediately if available
    if (quote) {
        completion(quote, !needsFresh);
    }
    
    // 5. Request fresh data if needed and not already pending
    if (needsFresh && ![self hasPendingRequestForSymbol:symbol dataType:DataFreshnessTypeQuote]) {
        [self requestFreshQuoteForSymbol:symbol completion:^(MarketQuote *freshQuote, NSError *error) {
            if (freshQuote && completion) {
                completion(freshQuote, YES);
            }
        }];
    }
}

- (void)getQuotesForSymbols:(NSArray<NSString *> *)symbols
                 completion:(void(^)(NSDictionary<NSString *, MarketQuote *> *quotes, BOOL isLive))completion {
    
    if (!symbols || symbols.count == 0 || !completion) return;
    
    NSMutableDictionary *quotesDict = [NSMutableDictionary dictionary];
    NSMutableArray *symbolsNeedingRefresh = [NSMutableArray array];
    BOOL allFresh = YES;
    
    // Check each symbol
    for (NSString *symbol in symbols) {
        MarketQuote *quote = [self fetchQuoteFromCoreData:symbol];
        
        if (quote) {
            quotesDict[symbol] = quote;
            
            if ([self isDataStale:quote.lastUpdate forType:DataFreshnessTypeQuote]) {
                [symbolsNeedingRefresh addObject:symbol];
                allFresh = NO;
            }
        } else {
            [symbolsNeedingRefresh addObject:symbol];
            allFresh = NO;
        }
    }
    
    // Return cached data immediately
    if (quotesDict.count > 0) {
        completion([quotesDict copy], allFresh);
    }
    
    // Request fresh data for symbols that need it
    if (symbolsNeedingRefresh.count > 0) {
        [self refreshQuotesForSymbols:symbolsNeedingRefresh];
    }
}

- (void)refreshQuoteForSymbol:(NSString *)symbol
                   completion:(void(^)(MarketQuote * _Nullable quote, NSError * _Nullable error))completion {
    [self requestFreshQuoteForSymbol:symbol completion:completion];
}

#pragma mark - Historical Data with Smart Caching

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                          barCount:(NSInteger)barCount
                        completion:(void(^)(NSArray<HistoricalBar *> *bars, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    NSLog(@"📈 DataHub: Getting historical data for %@ timeframe:%ld", symbol, (long)timeframe);
    
    // Calculate date range based on bar count
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self calculateStartDateForTimeframe:timeframe barCount:barCount fromDate:endDate];
    
    [self getHistoricalBarsForSymbol:symbol
                          timeframe:timeframe
                          startDate:startDate
                            endDate:endDate
                         completion:completion];
}

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                        completion:(void(^)(NSArray<HistoricalBar *> *bars, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    // 1. Check Core Data
    NSArray<HistoricalBar *> *bars = [self fetchHistoricalBarsFromCoreData:symbol
                                                                 timeframe:timeframe
                                                                 startDate:startDate
                                                                   endDate:endDate];
    
    // 2. Determine if data is fresh
    BOOL needsFresh = YES;
    if (bars.count > 0) {
        HistoricalBar *mostRecent = bars.lastObject;
        needsFresh = [self isDataStale:mostRecent.date forType:DataFreshnessTypeHistorical];
    }
    
    // 3. Return cached data immediately if available
    if (bars.count > 0) {
        completion(bars, !needsFresh);
    }
    
    // 4. Request fresh data if needed
    NSString *requestKey = [NSString stringWithFormat:@"historical_%@_%ld", symbol, (long)timeframe];
    if (needsFresh && ![self hasPendingRequestForKey:requestKey]) {
        [self requestFreshHistoricalDataForSymbol:symbol
                                       timeframe:timeframe
                                       startDate:startDate
                                         endDate:endDate
                                      completion:^(NSArray<HistoricalBar *> *freshBars, NSError *error) {
            if (freshBars && completion) {
                completion(freshBars, YES);
            }
        }];
    }
}

// Il DataHub riceverà i dizionari e li convertirà in oggetti Core Data
- (void)convertHistoricalDataDictionaries:(NSArray<NSDictionary *> *)dataDictionaries
                                forSymbol:(NSString *)symbol
                                timeframe:(BarTimeframe)timeframe {
    
    for (NSDictionary *barData in dataDictionaries) {
        [self saveHistoricalBar:barData forSymbol:symbol timeframe:timeframe];
    }
    
    [self saveContext];
}

#pragma mark - Company Info

- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     completion:(void(^)(CompanyInfo * _Nullable info, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    // 1. Check Core Data
    CompanyInfo *info = [self fetchCompanyInfoFromCoreData:symbol];
    
    // 2. Determine if data is fresh
    BOOL needsFresh = YES;
    if (info && info.lastUpdate) {
        needsFresh = [self isDataStale:info.lastUpdate forType:DataFreshnessTypeCompanyInfo];
    }
    
    // 3. Return cached data immediately if available
    if (info) {
        completion(info, !needsFresh);
    }
    
    // 4. Request fresh data if needed
    if (needsFresh && ![self hasPendingRequestForSymbol:symbol dataType:DataFreshnessTypeCompanyInfo]) {
        [self requestFreshCompanyInfoForSymbol:symbol completion:^(CompanyInfo *freshInfo, NSError *error) {
            if (freshInfo && completion) {
                completion(freshInfo, YES);
            }
        }];
    }
}

#pragma mark - Private Helper Methods

- (MarketQuote *)fetchQuoteFromCoreData:(NSString *)symbol {
    NSFetchRequest *request = [MarketQuote fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ Error fetching quote: %@", error);
    }
    
    return results.firstObject;
}

- (NSArray<HistoricalBar *> *)fetchHistoricalBarsFromCoreData:(NSString *)symbol
                                                    timeframe:(NSInteger)timeframe
                                                    startDate:(NSDate *)startDate
                                                      endDate:(NSDate *)endDate {
    NSFetchRequest *request = [HistoricalBar fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:
                        @"symbol == %@ AND timeframe == %d AND date >= %@ AND date <= %@",
                        symbol, (int)timeframe, startDate, endDate];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ Error fetching historical bars: %@", error);
    }
    
    return results ?: @[];
}

- (CompanyInfo *)fetchCompanyInfoFromCoreData:(NSString *)symbol {
    NSFetchRequest *request = [CompanyInfo fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    return results.firstObject;
}

#pragma mark - Fresh Data Requests

- (void)requestFreshQuoteForSymbol:(NSString *)symbol
                        completion:(void(^)(MarketQuote *quote, NSError *error))completion {
    
    NSString *requestKey = [self requestKeyForSymbol:symbol dataType:DataFreshnessTypeQuote];
    
    // Mark request as pending
    @synchronized(self.pendingRequests) {
        self.pendingRequests[requestKey] = @YES;
    }
    
    // Request from DataManager
    [[DataManager sharedManager] requestQuoteForSymbol:symbol completion:^(MarketData *marketData, NSError *error) {
        
        // Remove from pending
        @synchronized(self.pendingRequests) {
            [self.pendingRequests removeObjectForKey:requestKey];
        }
        
        if (error || !marketData) {
            if (completion) completion(nil, error);
            return;
        }
        
        // Convert MarketData to dictionary for saving
        NSDictionary *quoteDict = @{
            @"symbol": symbol,
            @"lastPrice": marketData.last ?: @0,
            @"bid": marketData.bid ?: @0,
            @"ask": marketData.ask ?: @0,
            @"volume": marketData.volume ?: @0,
            @"open": marketData.open ?: @0,
            @"high": marketData.high ?: @0,
            @"low": marketData.low ?: @0,
            @"previousClose": marketData.previousClose ?: @0,
            @"change": marketData.change ?: @0,
            @"changePercent": marketData.changePercent ?: @0,
            @"timestamp": marketData.timestamp ?: [NSDate date]
        };
        
        // Save quote
        MarketQuote *savedQuote = [self saveMarketQuoteData:quoteDict forSymbol:symbol];
        
        // Update memory cache usando il metodo esistente
        [self updateSymbolData:symbol
                     withPrice:[marketData.last doubleValue]
                        volume:[marketData.volume longLongValue]
                        change:[marketData.change doubleValue]
                  changePercent:[marketData.changePercent doubleValue]];
        
        if (completion) completion(savedQuote, nil);
    }];
}

- (void)requestFreshHistoricalDataForSymbol:(NSString *)symbol
                                  timeframe:(BarTimeframe)timeframe
                                  startDate:(NSDate *)startDate
                                    endDate:(NSDate *)endDate
                                 completion:(void(^)(NSArray<HistoricalBar *> *bars, NSError *error))completion {
    
    NSString *requestKey = [NSString stringWithFormat:@"historical_%@_%ld", symbol, (long)timeframe];
    
    // Mark request as pending
    @synchronized(self.pendingRequests) {
        self.pendingRequests[requestKey] = @YES;
    }
    
    // Request from DataManager
    [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                      timeframe:timeframe
                                                      startDate:startDate
                                                        endDate:endDate
                                                     completion:^(NSArray<HistoricalBar *> *bars, NSError *error) {
        
        // Remove from pending
        @synchronized(self.pendingRequests) {
            [self.pendingRequests removeObjectForKey:requestKey];
        }
        
        if (error || !bars) {
            if (completion) completion(nil, error);
            return;
        }
        
        // I bars sono già oggetti HistoricalBar dal DataManager
        // Non serve conversione, sono già salvati nel Core Data dal DataManager
        
        if (completion) completion(bars, nil);
    }];
}

- (void)requestFreshCompanyInfoForSymbol:(NSString *)symbol
                              completion:(void(^)(CompanyInfo *info, NSError *error))completion {
    
    // TODO: DataManager doesn't currently support company info requests
    // For now, just return nil
    NSError *error = [NSError errorWithDomain:@"DataHub"
                                         code:404
                                     userInfo:@{NSLocalizedDescriptionKey: @"Company info not implemented"}];
    if (completion) completion(nil, error);
}

#pragma mark - Core Data Save Methods

- (MarketQuote *)saveMarketQuoteData:(NSDictionary *)quoteData forSymbol:(NSString *)symbol {
    NSFetchRequest *request = [MarketQuote fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    MarketQuote *quote = results.firstObject;
    if (!quote) {
        quote = [NSEntityDescription insertNewObjectForEntityForName:@"MarketQuote"
                                              inManagedObjectContext:self.mainContext];
        quote.symbol = symbol;
    }
    
    // Update quote properties
    [self updateQuoteObject:quote withData:quoteData];
    quote.lastUpdate = [NSDate date];
    
    [self saveContext];
    
    return quote;
}

- (CompanyInfo *)saveCompanyInfoData:(NSDictionary *)infoData forSymbol:(NSString *)symbol {
    NSFetchRequest *request = [CompanyInfo fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    CompanyInfo *info = results.firstObject;
    if (!info) {
        info = [NSEntityDescription insertNewObjectForEntityForName:@"CompanyInfo"
                                             inManagedObjectContext:self.mainContext];
        info.symbol = symbol;
    }
    
    // Update info properties
    [self updateCompanyInfoObject:info withData:infoData];
    info.lastUpdate = [NSDate date];
    
    [self saveContext];
    
    return info;
}

#pragma mark - Batch Operations

- (void)refreshQuotesForSymbols:(NSArray<NSString *> *)symbols {
    for (NSString *symbol in symbols) {
        [self refreshQuoteForSymbol:symbol completion:nil];
    }
}

- (void)prefetchDataForSymbols:(NSArray<NSString *> *)symbols {
    // Prefetch quotes
    [self getQuotesForSymbols:symbols completion:nil];
    
    // Prefetch recent historical data
    for (NSString *symbol in symbols) {
        [self getHistoricalBarsForSymbol:symbol
                               timeframe:BarTimeframe1Day
                                barCount:30
                              completion:nil];
    }
}

#pragma mark - Cache Management

- (void)clearMarketDataCache {
    // Clear memory cache
    [self.symbolDataCache removeAllObjects];
    
    // Clear pending requests
    @synchronized(self.pendingRequests) {
        [self.pendingRequests removeAllObjects];
    }
}

- (void)clearCacheForSymbol:(NSString *)symbol {
    // Clear memory cache
    [self.symbolDataCache removeObjectForKey:symbol];
    
    // Clear pending requests for this symbol
    @synchronized(self.pendingRequests) {
        NSArray *keysToRemove = [self.pendingRequests.allKeys filteredArrayUsingPredicate:
                                [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", symbol]];
        [self.pendingRequests removeObjectsForKeys:keysToRemove];
    }
}

- (NSDictionary *)getCacheStatistics {
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    
    // Memory cache stats
    stats[@"memoryCacheCount"] = @(self.symbolDataCache.count);
    
    // Core Data stats
    NSFetchRequest *quoteRequest = [MarketQuote fetchRequest];
    NSUInteger quoteCount = [self.mainContext countForFetchRequest:quoteRequest error:nil];
    stats[@"quotesInCoreData"] = @(quoteCount);
    
    // Pending requests
    @synchronized(self.pendingRequests) {
        stats[@"pendingRequests"] = @(self.pendingRequests.count);
    }
    
    return stats;
}

#pragma mark - Helper Methods

- (NSDate *)calculateStartDateForTimeframe:(BarTimeframe)timeframe barCount:(NSInteger)barCount fromDate:(NSDate *)endDate {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    
    switch (timeframe) {
        case BarTimeframe1Min:
            components.minute = -barCount;
            break;
        case BarTimeframe5Min:
            components.minute = -barCount * 5;
            break;
        case BarTimeframe15Min:
            components.minute = -barCount * 15;
            break;
        case BarTimeframe30Min:
            components.minute = -barCount * 30;
            break;
        case BarTimeframe1Hour:
            components.hour = -barCount;
            break;
        case BarTimeframe1Day:
            components.day = -barCount;
            break;
        case BarTimeframe1Week:
            components.weekOfYear = -barCount;
            break;
        case BarTimeframe1Month:
            components.month = -barCount;
            break;
    }
    
    return [calendar dateByAddingComponents:components toDate:endDate options:0];
}

- (void)updateQuoteObject:(MarketQuote *)quote withData:(NSDictionary *)data {
    quote.currentPrice = [data[@"lastPrice"] doubleValue];
    quote.previousClose = [data[@"previousClose"] doubleValue];
    quote.change = [data[@"change"] doubleValue];
    quote.changePercent = [data[@"changePercent"] doubleValue];
    quote.volume = [data[@"volume"] longLongValue];
    quote.open = [data[@"open"] doubleValue];
    quote.high = [data[@"dayHigh"] doubleValue];
    quote.low = [data[@"dayLow"] doubleValue];
    quote.marketCap = [data[@"marketCap"] doubleValue];
    quote.pe = [data[@"peRatio"] doubleValue];
    
    // NON includere bid/ask perché MarketQuote non ha queste proprietà
    
    if (data[@"name"]) quote.name = data[@"name"];
    if (data[@"exchange"]) quote.exchange = data[@"exchange"];
}

- (void)updateCompanyInfoObject:(CompanyInfo *)info withData:(NSDictionary *)data {
    if (data[@"name"]) info.name = data[@"name"];
    if (data[@"sector"]) info.sector = data[@"sector"];
    if (data[@"industry"]) info.industry = data[@"industry"];
    if (data[@"description"]) info.companyDescription = data[@"description"];
    if (data[@"website"]) info.website = data[@"website"];
    if (data[@"ceo"]) info.ceo = data[@"ceo"];
    if (data[@"employees"]) info.employees = [data[@"employees"] intValue];
    if (data[@"headquarters"]) info.headquarters = data[@"headquarters"];
}

- (void)saveHistoricalBar:(NSDictionary *)barData forSymbol:(NSString *)symbol timeframe:(NSInteger)timeframe {
    NSDate *date = barData[@"date"];
    if (!date) return;
    
    // Check if bar already exists
    NSFetchRequest *request = [HistoricalBar fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:
                        @"symbol == %@ AND timeframe == %d AND date == %@",
                        symbol, (int)timeframe, date];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    HistoricalBar *bar = results.firstObject;
    if (!bar) {
        bar = [NSEntityDescription insertNewObjectForEntityForName:@"HistoricalBar"
                                            inManagedObjectContext:self.mainContext];
        bar.symbol = symbol;
        bar.timeframe = timeframe;
        bar.date = date;
    }
    
    // Update bar data
    bar.open = [barData[@"open"] doubleValue];
    bar.high = [barData[@"high"] doubleValue];
    bar.low = [barData[@"low"] doubleValue];
    bar.close = [barData[@"close"] doubleValue];
    bar.volume = [barData[@"volume"] longLongValue];
    
    if (barData[@"adjustedClose"]) {
        bar.adjustedClose = [barData[@"adjustedClose"] doubleValue];
    }
}

- (BOOL)hasPendingRequestForKey:(NSString *)requestKey {
    @synchronized(self.pendingRequests) {
        return self.pendingRequests[requestKey] != nil;
    }
}



@end
