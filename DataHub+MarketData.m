//
//  DataHub+MarketData.m
//  mafia_AI
//
//  NEW IMPLEMENTATION: Runtime models + DataManagerDelegate
//  Core Data used only for internal persistence
//

#import "DataHub+MarketData.h"
#import "DataHub+Private.h"
#import "DataManager.h"
#import "MarketData.h"

// Import Core Data entities (for internal persistence only)
#import "HistoricalBar+CoreDataClass.h"
#import "MarketQuote+CoreDataClass.h"
#import "CompanyInfo+CoreDataClass.h"

@interface DataHub () <DataManagerDelegate>

// Internal caches (runtime models)
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketQuote *> *quotesCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<HistoricalBar *> *> *historicalCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CompanyInfo *> *companyInfoCache;

// Cache timestamps for TTL management
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *cacheTimestamps;

// Active requests tracking
@property (nonatomic, strong) NSMutableSet<NSString *> *activeQuoteRequests;
@property (nonatomic, strong) NSMutableSet<NSString *> *activeHistoricalRequests;

// Subscriptions for real-time updates
@property (nonatomic, strong) NSMutableSet<NSString *> *subscribedSymbols;
@property (nonatomic, strong) NSTimer *refreshTimer;

@end

@implementation DataHub (MarketData)

#pragma mark - Initialization

+ (void)load {
    // Register as DataManager delegate when category loads
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[DataManager sharedManager] addDelegate:[DataHub shared]];
    });
}

- (void)initializeMarketDataCaches {
    if (!self.quotesCache) {
        self.quotesCache = [NSMutableDictionary dictionary];
        self.historicalCache = [NSMutableDictionary dictionary];
        self.companyInfoCache = [NSMutableDictionary dictionary];
        self.cacheTimestamps = [NSMutableDictionary dictionary];
        self.activeQuoteRequests = [NSMutableSet set];
        self.activeHistoricalRequests = [NSMutableSet set];
        self.subscribedSymbols = [NSMutableSet set];
    }
}

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

- (BOOL)isCacheStale:(NSString *)cacheKey dataType:(DataFreshnessType)type {
    [self initializeMarketDataCaches];
    
    NSDate *timestamp = self.cacheTimestamps[cacheKey];
    if (!timestamp) return YES;
    
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:timestamp];
    NSTimeInterval ttl = [self TTLForDataType:type];
    
    return age > ttl;
}

- (void)updateCacheTimestamp:(NSString *)cacheKey {
    [self initializeMarketDataCaches];
    self.cacheTimestamps[cacheKey] = [NSDate date];
}

#pragma mark - Public API - Market Quotes

- (void)getQuoteForSymbol:(NSString *)symbol
               completion:(void(^)(MarketQuote * _Nullable quote, BOOL isLive))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    NSLog(@"📊 DataHub: Getting quote for %@", symbol);
    
    // 1. Check memory cache first
    MarketQuote *cachedQuote = self.quotesCache[symbol];
    NSString *cacheKey = [NSString stringWithFormat:@"quote_%@", symbol];
    BOOL isStale = [self isCacheStale:cacheKey dataType:DataFreshnessTypeQuote];
    
    // 2. Return cached data immediately if available
    if (cachedQuote) {
        completion(cachedQuote, !isStale);
        
        // If fresh, we're done
        if (!isStale) return;
    }
    
    // 3. Check Core Data if no memory cache
    if (!cachedQuote) {
        [self loadQuoteFromCoreData:symbol completion:^(MarketQuote *quote) {
            if (quote) {
                self.quotesCache[symbol] = quote;
                completion(quote, NO); // From Core Data = not live
            }
        }];
    }
    
    // 4. Request fresh data if needed
    if (isStale && ![self.activeQuoteRequests containsObject:symbol]) {
        [self.activeQuoteRequests addObject:symbol];
        
        [[DataManager sharedManager] requestQuoteForSymbol:symbol
                                                completion:^(MarketData *marketData, NSError *error) {
            [self.activeQuoteRequests removeObject:symbol];
            
            if (marketData) {
                // Convert to runtime model and cache
                MarketQuote *runtimeQuote = [MarketQuote quoteFromMarketData:marketData];
                [self cacheQuote:runtimeQuote];
                
                // Save to Core Data in background
                [self saveQuoteToCoreData:runtimeQuote];
                
                // Call completion if this is the first response
                if (!cachedQuote && completion) {
                    completion(runtimeQuote, YES);
                }
            }
        }];
    }
}

- (void)getQuotesForSymbols:(NSArray<NSString *> *)symbols
                 completion:(void(^)(NSDictionary<NSString *, MarketQuote *> *quotes, BOOL allLive))completion {
    
    if (!symbols || symbols.count == 0 || !completion) return;
    
    NSMutableDictionary<NSString *, MarketQuote *> *result = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *symbolsNeedingRefresh = [NSMutableArray array];
    BOOL allLive = YES;
    
    // Check cache for each symbol
    for (NSString *symbol in symbols) {
        [self getQuoteForSymbol:symbol completion:^(MarketQuote *quote, BOOL isLive) {
            if (quote) {
                result[symbol] = quote;
                if (!isLive) allLive = NO;
            }
        }];
    }
    
    // Return what we have
    completion([result copy], allLive);
}

#pragma mark - Public API - Historical Data

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                          barCount:(NSInteger)barCount
                        completion:(void(^)(NSArray<HistoricalBar *> *bars, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    NSLog(@"📈 DataHub: Getting historical data for %@ timeframe:%ld count:%ld", symbol, (long)timeframe, (long)barCount);
    
    // 1. Check memory cache
    NSString *cacheKey = [NSString stringWithFormat:@"historical_%@_%ld_%ld", symbol, (long)timeframe, (long)barCount];
    NSArray<HistoricalBar *> *cachedBars = self.historicalCache[cacheKey];
    BOOL isStale = [self isCacheStale:cacheKey dataType:DataFreshnessTypeHistorical];
    
    // 2. Return cached data immediately if available
    if (cachedBars) {
        completion(cachedBars, !isStale);
        
        // If fresh, we're done
        if (!isStale) return;
    }
    
    // 3. Check Core Data if no memory cache
    if (!cachedBars) {
        [self loadHistoricalDataFromCoreData:symbol
                                   timeframe:timeframe
                                    barCount:barCount
                                  completion:^(NSArray<HistoricalBar *> *bars) {
            if (bars.count > 0) {
                self.historicalCache[cacheKey] = bars;
                completion(bars, NO); // From Core Data = not fresh
            }
        }];
    }
    
    // 4. Request fresh data if needed
    if (isStale && ![self.activeHistoricalRequests containsObject:cacheKey]) {
        [self.activeHistoricalRequests addObject:cacheKey];
        
        [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                          timeframe:timeframe
                                                              count:barCount
                                                         completion:^(NSArray<NSDictionary *> *barDictionaries, NSError *error) {
            [self.activeHistoricalRequests removeObject:cacheKey];
            
            if (barDictionaries && barDictionaries.count > 0) {
                // Convert to runtime models
                NSArray<HistoricalBar *> *runtimeBars = [HistoricalBar barsFromDictionaries:barDictionaries];
                
                // Cache in memory
                [self cacheHistoricalBars:runtimeBars forKey:cacheKey];
                
                // Save to Core Data in background
                [self saveHistoricalBarsToCoreData:barDictionaries symbol:symbol timeframe:timeframe];
                
                // Call completion if this is the first response
                if (!cachedBars && completion) {
                    completion(runtimeBars, YES);
                }
            }
        }];
    }
}

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                        completion:(void(^)(NSArray<HistoricalBar *> *bars, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    // Calculate approximate bar count for caching
    NSInteger estimatedCount = [self estimateBarCountForTimeframe:timeframe startDate:startDate endDate:endDate];
    
    [self getHistoricalBarsForSymbol:symbol
                           timeframe:timeframe
                            barCount:estimatedCount
                          completion:completion];
}

#pragma mark - Public API - Company Info

- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     completion:(void(^)(CompanyInfo * _Nullable info, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    // 1. Check memory cache
    CompanyInfo *cachedInfo = self.companyInfoCache[symbol];
    NSString *cacheKey = [NSString stringWithFormat:@"company_%@", symbol];
    BOOL isStale = [self isCacheStale:cacheKey dataType:DataFreshnessTypeCompanyInfo];
    
    // 2. Return cached data immediately if available
    if (cachedInfo) {
        completion(cachedInfo, !isStale);
        
        // If fresh, we're done
        if (!isStale) return;
    }
    
    // 3. Check Core Data if no memory cache
    if (!cachedInfo) {
        [self loadCompanyInfoFromCoreData:symbol completion:^(CompanyInfo *info) {
            if (info) {
                self.companyInfoCache[symbol] = info;
                completion(info, NO); // From Core Data = not fresh
            }
        }];
    }
    
    // 4. For now, company info requests are not implemented in DataManager
    // Return cached data or nil
    if (!cachedInfo) {
        completion(nil, NO);
    }
}

#pragma mark - DataManager Delegate Methods

- (void)dataManager:(DataManager *)manager didUpdateQuote:(MarketData *)marketData forSymbol:(NSString *)symbol {
    
    // Convert MarketData to runtime model
    MarketQuote *runtimeQuote = [MarketQuote quoteFromMarketData:marketData];
    
    // Cache in memory
    [self cacheQuote:runtimeQuote];
    
    // Save to Core Data in background
    [self saveQuoteToCoreData:runtimeQuote];
    
    // Broadcast notification with runtime model
    [self broadcastQuoteUpdate:runtimeQuote];
}

- (void)dataManager:(DataManager *)manager didUpdateHistoricalData:(NSArray<NSDictionary *> *)barDictionaries forSymbol:(NSString *)symbol {
    
    // Convert dictionaries to runtime models
    NSArray<HistoricalBar *> *runtimeBars = [HistoricalBar barsFromDictionaries:barDictionaries];
    
    // Cache in memory (need to determine cache key from context)
    // For now, cache with default timeframe
    NSString *cacheKey = [NSString stringWithFormat:@"historical_%@_%ld_0", symbol, (long)BarTimeframe1Day];
    [self cacheHistoricalBars:runtimeBars forKey:cacheKey];
    
    // Save to Core Data in background
    [self saveHistoricalBarsToCoreData:barDictionaries symbol:symbol timeframe:BarTimeframe1Day];
    
    // Broadcast notification with runtime models
    [self broadcastHistoricalDataUpdate:runtimeBars forSymbol:symbol];
}

- (void)dataManager:(DataManager *)manager didFailWithError:(NSError *)error forRequest:(NSString *)requestID {
    NSLog(@"DataHub: DataManager request failed: %@ - %@", requestID, error.localizedDescription);
    
    // Broadcast error notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubErrorNotification"
                                                        object:self
                                                      userInfo:@{
                                                          @"error": error,
                                                          @"requestID": requestID
                                                      }];
}

#pragma mark - Caching Methods

- (void)cacheQuote:(MarketQuote *)quote {
    if (!quote || !quote.symbol) return;
    
    [self initializeMarketDataCaches];
    
    self.quotesCache[quote.symbol] = quote;
    NSString *cacheKey = [NSString stringWithFormat:@"quote_%@", quote.symbol];
    [self updateCacheTimestamp:cacheKey];
    
    NSLog(@"DataHub: Cached quote for %@", quote.symbol);
}

- (void)cacheHistoricalBars:(NSArray<HistoricalBar *> *)bars forKey:(NSString *)cacheKey {
    if (!bars || bars.count == 0 || !cacheKey) return;
    
    [self initializeMarketDataCaches];
    
    self.historicalCache[cacheKey] = bars;
    [self updateCacheTimestamp:cacheKey];
    
    NSLog(@"DataHub: Cached %lu historical bars for key %@", (unsigned long)bars.count, cacheKey);
}

#pragma mark - Core Data Integration (Internal)

- (void)loadQuoteFromCoreData:(NSString *)symbol completion:(void(^)(MarketQuote *quote))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSFetchRequest *request = [MarketQuote fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        
        NSError *error = nil;
        NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
        
        MarketQuote *runtimeQuote = nil;
        if (results.firstObject) {
            // Convert Core Data entity to runtime model
            MarketQuote *coreDataQuote = results.firstObject;
            runtimeQuote = [MarketQuote quoteFromDictionary:[self quoteCoreDataToDictionary:coreDataQuote]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeQuote);
        });
    });
}

- (void)loadHistoricalDataFromCoreData:(NSString *)symbol
                             timeframe:(BarTimeframe)timeframe
                              barCount:(NSInteger)barCount
                            completion:(void(^)(NSArray<HistoricalBar *> *bars))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSFetchRequest *request = [HistoricalBar fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@ AND timeframe == %d", symbol, (int)timeframe];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
        
        if (barCount > 0) {
            request.fetchLimit = barCount;
        }
        
        NSError *error = nil;
        NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
        
        NSMutableArray<HistoricalBar *> *runtimeBars = [NSMutableArray array];
        for (HistoricalBar *coreDataBar in results) {
            NSDictionary *dict = [self historicalBarCoreDataToDictionary:coreDataBar];
            HistoricalBar *runtimeBar = [HistoricalBar barFromDictionary:dict];
            if (runtimeBar) {
                [runtimeBars addObject:runtimeBar];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([runtimeBars copy]);
        });
    });
}

- (void)loadCompanyInfoFromCoreData:(NSString *)symbol completion:(void(^)(CompanyInfo *info))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSFetchRequest *request = [CompanyInfo fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        
        NSError *error = nil;
        NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
        
        CompanyInfo *runtimeInfo = nil;
        if (results.firstObject) {
            CompanyInfo *coreDataInfo = results.firstObject;
            runtimeInfo = [CompanyInfo infoFromDictionary:[self companyInfoCoreDataToDictionary:coreDataInfo]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeInfo);
        });
    });
}

- (void)saveQuoteToCoreData:(MarketQuote *)quote {
    if (!quote) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSManagedObjectContext *backgroundContext = [self.persistentContainer newBackgroundContext];
        
        [backgroundContext performBlock:^{
            
            // Find existing or create new
            NSFetchRequest *request = [MarketQuote fetchRequest];
            request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", quote.symbol];
            
            NSError *error = nil;
            NSArray *results = [backgroundContext executeFetchRequest:request error:&error];
            
            MarketQuote *coreDataQuote = results.firstObject;
            if (!coreDataQuote) {
                coreDataQuote = [NSEntityDescription insertNewObjectForEntityForName:@"MarketQuote"
                                                              inManagedObjectContext:backgroundContext];
                coreDataQuote.symbol = quote.symbol;
            }
            
            // Update properties
            [self updateCoreDataQuote:coreDataQuote withRuntimeQuote:quote];
            coreDataQuote.lastUpdate = [NSDate date];
            
            // Save
            if (![backgroundContext save:&error]) {
                NSLog(@"Error saving quote to Core Data: %@", error);
            }
        }];
    });
}

- (void)saveHistoricalBarsToCoreData:(NSArray<NSDictionary *> *)barDictionaries
                              symbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe {
    
    if (!barDictionaries || barDictionaries.count == 0) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSManagedObjectContext *backgroundContext = [self.persistentContainer newBackgroundContext];
        
        [backgroundContext performBlock:^{
            
            for (NSDictionary *barDict in barDictionaries) {
                [self saveHistoricalBarDict:barDict
                                  forSymbol:symbol
                                  timeframe:timeframe
                                  inContext:backgroundContext];
            }
            
            NSError *error = nil;
            if (![backgroundContext save:&error]) {
                NSLog(@"Error saving historical bars to Core Data: %@", error);
            }
        }];
    });
}

#pragma mark - Core Data Conversion Helpers

- (NSDictionary *)quoteCoreDataToDictionary:(MarketQuote *)coreDataQuote {
    return @{
        @"symbol": coreDataQuote.symbol ?: @"",
        @"last": coreDataQuote.lastPrice ?: @0,
        @"bid": coreDataQuote.bid ?: @0,
        @"ask": coreDataQuote.ask ?: @0,
        @"open": coreDataQuote.open ?: @0,
        @"high": coreDataQuote.high ?: @0,
        @"low": coreDataQuote.low ?: @0,
        @"close": coreDataQuote.close ?: @0,
        @"previousClose": coreDataQuote.previousClose ?: @0,
        @"change": coreDataQuote.change ?: @0,
        @"changePercent": coreDataQuote.changePercent ?: @0,
        @"volume": coreDataQuote.volume ?: @0,
        @"timestamp": coreDataQuote.lastUpdate ?: [NSDate date]
    };
}

- (NSDictionary *)historicalBarCoreDataToDictionary:(HistoricalBar *)coreDataBar {
    return @{
        @"symbol": coreDataBar.symbol ?: @"",
        @"date": coreDataBar.date ?: [NSDate date],
        @"open": @(coreDataBar.open),
        @"high": @(coreDataBar.high),
        @"low": @(coreDataBar.low),
        @"close": @(coreDataBar.close),
        @"adjustedClose": @(coreDataBar.adjustedClose),
        @"volume": @(coreDataBar.volume),
        @"timeframe": @(coreDataBar.timeframe)
    };
}

- (NSDictionary *)companyInfoCoreDataToDictionary:(CompanyInfo *)coreDataInfo {
    return @{
        @"symbol": coreDataInfo.symbol ?: @"",
        @"name": coreDataInfo.name ?: @"",
        @"sector": coreDataInfo.sector ?: @"",
        @"industry": coreDataInfo.industry ?: @"",
        @"companyDescription": coreDataInfo.companyDescription ?: @"",
        @"website": coreDataInfo.website ?: @"",
        @"ceo": coreDataInfo.ceo ?: @"",
        @"employees": @(coreDataInfo.employees),
        @"headquarters": coreDataInfo.headquarters ?: @"",
        @"lastUpdate": coreDataInfo.lastUpdate ?: [NSDate date]
    };
}

- (void)updateCoreDataQuote:(MarketQuote *)coreDataQuote withRuntimeQuote:(MarketQuote *)runtimeQuote {
    coreDataQuote.lastPrice = runtimeQuote.last;
    coreDataQuote.bid = runtimeQuote.bid;
    coreDataQuote.ask = runtimeQuote.ask;
    coreDataQuote.open = runtimeQuote.open;
    coreDataQuote.high = runtimeQuote.high;
    coreDataQuote.low = runtimeQuote.low;
    coreDataQuote.close = runtimeQuote.close;
    coreDataQuote.previousClose = runtimeQuote.previousClose;
    coreDataQuote.change = runtimeQuote.change;
    coreDataQuote.changePercent = runtimeQuote.changePercent;
    coreDataQuote.volume = runtimeQuote.volume;
}

- (void)saveHistoricalBarDict:(NSDictionary *)barDict
                    forSymbol:(NSString *)symbol
                    timeframe:(BarTimeframe)timeframe
                    inContext:(NSManagedObjectContext *)context {
    
    NSDate *date = barDict[@"date"];
    if (!date) return;
    
    // Check if bar already exists
    NSFetchRequest *request = [HistoricalBar fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:
                        @"symbol == %@ AND timeframe == %d AND date == %@",
                        symbol, (int)timeframe, date];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    HistoricalBar *bar = results.firstObject;
    if (!bar) {
        bar = [NSEntityDescription insertNewObjectForEntityForName:@"HistoricalBar"
                                            inManagedObjectContext:context];
        bar.symbol = symbol;
        bar.timeframe = timeframe;
        bar.date = date;
    }
    
    // Update bar data
    bar.open = [barDict[@"open"] doubleValue];
    bar.high = [barDict[@"high"] doubleValue];
    bar.low = [barDict[@"low"] doubleValue];
    bar.close = [barDict[@"close"] doubleValue];
    bar.volume = [barDict[@"volume"] longLongValue];
    
    if (barDict[@"adjustedClose"]) {
        bar.adjustedClose = [barDict[@"adjustedClose"] doubleValue];
    } else {
        bar.adjustedClose = bar.close;
    }
}

#pragma mark - Notifications

- (void)broadcastQuoteUpdate:(MarketQuote *)quote {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubQuoteUpdatedNotification"
                                                            object:self
                                                          userInfo:@{
                                                              @"symbol": quote.symbol,
                                                              @"quote": quote,
                                                              @"timestamp": [NSDate date]
                                                          }];
    });
}

- (void)broadcastHistoricalDataUpdate:(NSArray<HistoricalBar *> *)bars forSymbol:(NSString *)symbol {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubHistoricalDataUpdatedNotification"
                                                            object:self
                                                          userInfo:@{
                                                              @"symbol": symbol,
                                                              @"bars": bars,
                                                              @"timestamp": [NSDate date]
                                                          }];
    });
}

#pragma mark - Subscription Management

- (void)subscribeToQuoteUpdatesForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    [self initializeMarketDataCaches];
    [self.subscribedSymbols addObject:symbol];
    
    // Start refresh timer if this is the first subscription
    if (self.subscribedSymbols.count == 1) {
        [self startRefreshTimer];
    }
    
    NSLog(@"DataHub: Subscribed to quote updates for %@", symbol);
}

- (void)subscribeToQuoteUpdatesForSymbols:(NSArray<NSString *> *)symbols {
    for (NSString *symbol in symbols) {
        [self subscribeToQuoteUpdatesForSymbol:symbol];
    }
}

- (void)unsubscribeFromQuoteUpdatesForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    [self initializeMarketDataCaches];
    [self.subscribedSymbols removeObject:symbol];
    
    // Stop timer if no more subscriptions
    if (self.subscribedSymbols.count == 0) {
        [self stopRefreshTimer];
    }
    
    NSLog(@"DataHub: Unsubscribed from quote updates for %@", symbol);
}

- (void)unsubscribeFromAllQuoteUpdates {
    [self initializeMarketDataCaches];
    [self.subscribedSymbols removeAllObjects];
    [self stopRefreshTimer];
    
    NSLog(@"DataHub: Unsubscribed from all quote updates");
}

- (void)startRefreshTimer {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
    }
    
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 // 5 seconds
                                                         target:self
                                                       selector:@selector(refreshSubscribedQuotes)
                                                       userInfo:nil
                                                        repeats:YES];
    
    NSLog(@"DataHub: Started refresh timer for subscribed quotes");
}

- (void)stopRefreshTimer {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
    
    NSLog(@"DataHub: Stopped refresh timer");
}

- (void)refreshSubscribedQuotes {
    for (NSString *symbol in self.subscribedSymbols) {
        // Force refresh by making direct request to DataManager
        [[DataManager sharedManager] requestQuoteForSymbol:symbol completion:nil];
    }
}

#pragma mark - Utility Methods

- (NSInteger)estimateBarCountForTimeframe:(BarTimeframe)timeframe startDate:(NSDate *)startDate endDate:(NSDate *)endDate {
    NSTimeInterval interval = [endDate timeIntervalSinceDate:startDate];
    
    switch (timeframe) {
        case BarTimeframe1Min:
            return (NSInteger)(interval / 60);
        case BarTimeframe5Min:
            return (NSInteger)(interval / 300);
        case BarTimeframe15Min:
            return (NSInteger)(interval / 900);
        case BarTimeframe30Min:
            return (NSInteger)(interval / 1800);
        case BarTimeframe1Hour:
            return (NSInteger)(interval / 3600);
        case BarTimeframe4Hour:
            return (NSInteger)(interval / 14400);
        case BarTimeframe1Day:
            return (NSInteger)(interval / 86400);
        case BarTimeframe1Week:
            return (NSInteger)(interval / 604800);
        case BarTimeframe1Month:
            return (NSInteger)(interval / 2592000);
    }
    
    return 100; // Default
}

#pragma mark - Batch Operations

- (void)refreshQuotesForSymbols:(NSArray<NSString *> *)symbols {
    for (NSString *symbol in symbols) {
        [self refreshQuoteForSymbol:symbol completion:nil];
    }
}

- (void)refreshQuoteForSymbol:(NSString *)symbol
                   completion:(void(^)(MarketQuote * _Nullable quote, NSError * _Nullable error))completion {
    
    [[DataManager sharedManager] requestQuoteForSymbol:symbol completion:^(MarketData *marketData, NSError *error) {
        if (marketData) {
            MarketQuote *runtimeQuote = [MarketQuote quoteFromMarketData:marketData];
            [self cacheQuote:runtimeQuote];
            [self saveQuoteToCoreData:runtimeQuote];
            
            if (completion) completion(runtimeQuote, nil);
        } else {
            if (completion) completion(nil, error);
        }
    }];
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
    [self initializeMarketDataCaches];
    
    [self.quotesCache removeAllObjects];
    [self.historicalCache removeAllObjects];
    [self.companyInfoCache removeAllObjects];
    [self.cacheTimestamps removeAllObjects];
    
    NSLog(@"DataHub: Cleared all market data cache");
}

- (void)clearCacheForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    [self initializeMarketDataCaches];
    
    // Clear quotes
    [self.quotesCache removeObjectForKey:symbol];
    
    // Clear historical data
    NSArray *keysToRemove = [self.historicalCache.allKeys filteredArrayUsingPredicate:
                            [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", symbol]];
    [self.historicalCache removeObjectsForKeys:keysToRemove];
    
    // Clear company info
    [self.companyInfoCache removeObjectForKey:symbol];
    
    // Clear timestamps
    NSArray *timestampKeysToRemove = [self.cacheTimestamps.allKeys filteredArrayUsingPredicate:
                                     [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", symbol]];
    [self.cacheTimestamps removeObjectsForKeys:timestampKeysToRemove];
    
    NSLog(@"DataHub: Cleared cache for symbol %@", symbol);
}

- (NSDictionary *)getCacheStatistics {
    [self initializeMarketDataCaches];
    
    return @{
        @"quotesCount": @(self.quotesCache.count),
        @"historicalCacheCount": @(self.historicalCache.count),
        @"companyInfoCount": @(self.companyInfoCache.count),
        @"subscribedSymbolsCount": @(self.subscribedSymbols.count),
        @"activeQuoteRequests": @(self.activeQuoteRequests.count),
        @"activeHistoricalRequests": @(self.activeHistoricalRequests.count)
    };
}

@end
