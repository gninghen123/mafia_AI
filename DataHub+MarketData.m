//
//  DataHub+MarketData.m
//  mafia_AI
//
//  FINAL IMPLEMENTATION: Runtime models from DataManager
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
               completion:(void(^)(MarketQuoteModel * _Nullable quote, BOOL isLive))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    NSLog(@"📊 DataHub: Getting quote for %@", symbol);
    
    // 1. Check memory cache first
    MarketQuoteModel *cachedQuote = self.quotesCache[symbol];
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
        [self loadQuoteFromCoreData:symbol completion:^(MarketQuoteModel *quote) {
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
                MarketQuoteModel *runtimeQuote = [MarketQuoteModel quoteFromMarketData:marketData];
                [self cacheQuote:runtimeQuote];
                
                // Save to Core Data in background
                [self saveQuoteModelToCoreData:runtimeQuote];
                
                // Call completion if this is the first response
                if (!cachedQuote && completion) {
                    completion(runtimeQuote, YES);
                }
            }
        }];
    }
}

- (void)getQuotesForSymbols:(NSArray<NSString *> *)symbols
                 completion:(void(^)(NSDictionary<NSString *, MarketQuoteModel *> *quotes, BOOL allLive))completion {
    
    if (!symbols || symbols.count == 0 || !completion) return;
    
    NSMutableDictionary<NSString *, MarketQuoteModel *> *result = [NSMutableDictionary dictionary];
    __block NSInteger completedCount = 0;
    __block BOOL allLive = YES;
    
    // Get quote for each symbol
    for (NSString *symbol in symbols) {
        [self getQuoteForSymbol:symbol completion:^(MarketQuoteModel *quote, BOOL isLive) {
            if (quote) {
                @synchronized(result) {
                    result[symbol] = quote;
                    if (!isLive) allLive = NO;
                    
                    completedCount++;
                    if (completedCount == symbols.count) {
                        completion([result copy], allLive);
                    }
                }
            } else {
                @synchronized(result) {
                    completedCount++;
                    allLive = NO;
                    if (completedCount == symbols.count) {
                        completion([result copy], allLive);
                    }
                }
            }
        }];
    }
}

#pragma mark - Public API - Historical Data

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                          barCount:(NSInteger)barCount
                        completion:(void(^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    NSLog(@"📈 DataHub: Getting historical data for %@ timeframe:%ld count:%ld", symbol, (long)timeframe, (long)barCount);
    
    // 1. Check memory cache
    NSString *cacheKey = [NSString stringWithFormat:@"historical_%@_%ld_%ld", symbol, (long)timeframe, (long)barCount];
    NSArray<HistoricalBarModel *> *cachedBars = self.historicalCache[cacheKey];
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
                                  completion:^(NSArray<HistoricalBarModel *> *bars) {
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
                                                         completion:^(NSArray<HistoricalBarModel *> *runtimeBars, NSError *error) {
            [self.activeHistoricalRequests removeObject:cacheKey];
            
            if (runtimeBars && runtimeBars.count > 0) {
                // Cache in memory
                [self cacheHistoricalBars:runtimeBars forKey:cacheKey];
                
                // Save to Core Data in background
                [self saveHistoricalBarsModelToCoreData:runtimeBars symbol:symbol timeframe:timeframe];
                
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
                        completion:(void(^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion {
    
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
                     completion:(void(^)(CompanyInfoModel * _Nullable info, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    // 1. Check memory cache
    CompanyInfoModel *cachedInfo = self.companyInfoCache[symbol];
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
        [self loadCompanyInfoFromCoreData:symbol completion:^(CompanyInfoModel *info) {
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
    MarketQuoteModel *runtimeQuote = [MarketQuoteModel quoteFromMarketData:marketData];
    
    // Cache in memory
    [self cacheQuote:runtimeQuote];
    
    // Save to Core Data in background
    [self saveQuoteModelToCoreData:runtimeQuote];
    
    // Broadcast notification with runtime model
    [self broadcastQuoteUpdate:runtimeQuote];
}

- (void)dataManager:(DataManager *)manager didUpdateHistoricalData:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol {
    
    NSLog(@"📈 DataHub: Received %lu runtime HistoricalBarModel objects for %@", (unsigned long)bars.count, symbol);
    
    // Cache in memory with appropriate key
    BarTimeframe timeframe = bars.firstObject ? bars.firstObject.timeframe : BarTimeframe1Day;
    NSString *cacheKey = [NSString stringWithFormat:@"historical_%@_%ld_%lu", symbol, (long)timeframe, (unsigned long)bars.count];
    [self cacheHistoricalBars:bars forKey:cacheKey];
    
    // Save to Core Data in background
    [self saveHistoricalBarsModelToCoreData:bars symbol:symbol timeframe:timeframe];
    
    // Broadcast notification with runtime models
    [self broadcastHistoricalDataUpdate:bars forSymbol:symbol];
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

- (void)cacheQuote:(MarketQuoteModel *)quote {
    if (!quote || !quote.symbol) return;
    
    [self initializeMarketDataCaches];
    
    self.quotesCache[quote.symbol] = quote;
    NSString *cacheKey = [NSString stringWithFormat:@"quote_%@", quote.symbol];
    [self updateCacheTimestamp:cacheKey];
    
    NSLog(@"DataHub: Cached MarketQuoteModel for %@", quote.symbol);
}

- (void)cacheHistoricalBars:(NSArray<HistoricalBarModel *> *)bars forKey:(NSString *)cacheKey {
    if (!bars || bars.count == 0 || !cacheKey) return;
    
    [self initializeMarketDataCaches];
    
    self.historicalCache[cacheKey] = bars;
    [self updateCacheTimestamp:cacheKey];
    
    NSLog(@"DataHub: Cached %lu HistoricalBarModel objects for key %@", (unsigned long)bars.count, cacheKey);
}

#pragma mark - Core Data Integration (Internal Persistence)

- (void)loadQuoteFromCoreData:(NSString *)symbol completion:(void(^)(MarketQuoteModel *quote))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSFetchRequest *request = [MarketQuote fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        
        NSError *error = nil;
        NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
        
        MarketQuoteModel *runtimeQuote = nil;
        if (results.firstObject) {
            // Convert Core Data entity to runtime model
            MarketQuote *coreDataQuote = results.firstObject;
            runtimeQuote = [self convertCoreDataQuoteToRuntimeModel:coreDataQuote];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeQuote);
        });
    });
}

- (void)loadHistoricalDataFromCoreData:(NSString *)symbol
                             timeframe:(BarTimeframe)timeframe
                              barCount:(NSInteger)barCount
                            completion:(void(^)(NSArray<HistoricalBarModel *> *bars))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSFetchRequest *request = [HistoricalBar fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@ AND timeframe == %d", symbol, (int)timeframe];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
        
        if (barCount > 0) {
            request.fetchLimit = barCount;
        }
        
        NSError *error = nil;
        NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
        
        NSMutableArray<HistoricalBarModel *> *runtimeBars = [NSMutableArray array];
        for (HistoricalBar *coreDataBar in results) {
            HistoricalBarModel *runtimeBar = [self convertCoreDataBarToRuntimeModel:coreDataBar];
            if (runtimeBar) {
                [runtimeBars addObject:runtimeBar];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([runtimeBars copy]);
        });
    });
}

- (void)loadCompanyInfoFromCoreData:(NSString *)symbol completion:(void(^)(CompanyInfoModel *info))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSFetchRequest *request = [CompanyInfo fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        
        NSError *error = nil;
        NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
        
        CompanyInfoModel *runtimeInfo = nil;
        if (results.firstObject) {
            CompanyInfo *coreDataInfo = results.firstObject;
            runtimeInfo = [self convertCoreDataCompanyInfoToRuntimeModel:coreDataInfo];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeInfo);
        });
    });
}

#pragma mark - Core Data Saving (Background)

- (void)saveQuoteModelToCoreData:(MarketQuoteModel *)quote {
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
            
            // Update properties using corrected method
            [self updateCoreDataQuote:coreDataQuote withRuntimeModel:quote];
            coreDataQuote.lastUpdate = [NSDate date];
            
            // Save
            if (![backgroundContext save:&error]) {
                NSLog(@"Error saving quote to Core Data: %@", error);
            }
        }];
    });
}

- (void)saveHistoricalBarsModelToCoreData:(NSArray<HistoricalBarModel *> *)bars
                                   symbol:(NSString *)symbol
                                timeframe:(BarTimeframe)timeframe {
    
    if (!bars || bars.count == 0) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSManagedObjectContext *backgroundContext = [self.persistentContainer newBackgroundContext];
        
        [backgroundContext performBlock:^{
            
            for (HistoricalBarModel *barModel in bars) {
                [self saveHistoricalBarModel:barModel inContext:backgroundContext];
            }
            
            NSError *error = nil;
            if (![backgroundContext save:&error]) {
                NSLog(@"Error saving historical bars to Core Data: %@", error);
            }
        }];
    });
}

#pragma mark - Core Data Conversion Helpers (FIXED)

- (MarketQuoteModel *)convertCoreDataQuoteToRuntimeModel:(MarketQuote *)coreDataQuote {
    MarketQuoteModel *runtimeQuote = [[MarketQuoteModel alloc] init];
    
    runtimeQuote.symbol = coreDataQuote.symbol;
    runtimeQuote.name = coreDataQuote.name;
    runtimeQuote.exchange = coreDataQuote.exchange;
    
    // FIXED: Core Data uses currentPrice, convert to NSNumber
    runtimeQuote.last = @(coreDataQuote.currentPrice);
    
    // Core Data doesn't have bid/ask, use currentPrice as fallback
    runtimeQuote.bid = @(coreDataQuote.currentPrice);
    runtimeQuote.ask = @(coreDataQuote.currentPrice);
    
    // OHLC data - Core Data uses double, convert to NSNumber
    runtimeQuote.open = @(coreDataQuote.open);
    runtimeQuote.high = @(coreDataQuote.high);
    runtimeQuote.low = @(coreDataQuote.low);
    runtimeQuote.close = @(coreDataQuote.currentPrice); // Use currentPrice as close
    runtimeQuote.previousClose = @(coreDataQuote.previousClose);
    
    // Changes
    runtimeQuote.change = @(coreDataQuote.change);
    runtimeQuote.changePercent = @(coreDataQuote.changePercent);
    
    // Volume - Core Data uses int64_t, convert to NSNumber
    runtimeQuote.volume = @(coreDataQuote.volume);
    runtimeQuote.avgVolume = @(coreDataQuote.avgVolume);
    
    // Market data
    runtimeQuote.marketCap = @(coreDataQuote.marketCap);
    runtimeQuote.pe = @(coreDataQuote.pe);
    runtimeQuote.eps = @(coreDataQuote.eps);
    runtimeQuote.beta = @(coreDataQuote.beta);
    
    // Timestamp
    runtimeQuote.timestamp = coreDataQuote.lastUpdate ?: [NSDate date];
    runtimeQuote.isMarketOpen = YES; // Default, Core Data doesn't store this
    
    return runtimeQuote;
}

- (void)updateCoreDataQuote:(MarketQuote *)coreDataQuote withRuntimeModel:(MarketQuoteModel *)runtimeQuote {
    // FIXED: Map runtime model properties to Core Data properties correctly
    coreDataQuote.name = runtimeQuote.name;
    coreDataQuote.exchange = runtimeQuote.exchange;
    
    // Core Data uses currentPrice, not lastPrice
    coreDataQuote.currentPrice = runtimeQuote.last ? [runtimeQuote.last doubleValue] : 0.0;
    
    // OHLC data - convert NSNumber to double
    coreDataQuote.open = runtimeQuote.open ? [runtimeQuote.open doubleValue] : 0.0;
    coreDataQuote.high = runtimeQuote.high ? [runtimeQuote.high doubleValue] : 0.0;
    coreDataQuote.low = runtimeQuote.low ? [runtimeQuote.low doubleValue] : 0.0;
    coreDataQuote.previousClose = runtimeQuote.previousClose ? [runtimeQuote.previousClose doubleValue] : 0.0;
    
    // Changes
    coreDataQuote.change = runtimeQuote.change ? [runtimeQuote.change doubleValue] : 0.0;
    coreDataQuote.changePercent = runtimeQuote.changePercent ? [runtimeQuote.changePercent doubleValue] : 0.0;
    
    // Volume - convert NSNumber to int64_t
    coreDataQuote.volume = runtimeQuote.volume ? [runtimeQuote.volume longLongValue] : 0;
    coreDataQuote.avgVolume = runtimeQuote.avgVolume ? [runtimeQuote.avgVolume longLongValue] : 0;
    
    // Market data
    coreDataQuote.marketCap = runtimeQuote.marketCap ? [runtimeQuote.marketCap doubleValue] : 0.0;
    coreDataQuote.pe = runtimeQuote.pe ? [runtimeQuote.pe doubleValue] : 0.0;
    coreDataQuote.eps = runtimeQuote.eps ? [runtimeQuote.eps doubleValue] : 0.0;
    coreDataQuote.beta = runtimeQuote.beta ? [runtimeQuote.beta doubleValue] : 0.0;
    
    // Timestamp
    coreDataQuote.marketTime = runtimeQuote.timestamp;
}

- (HistoricalBarModel *)convertCoreDataBarToRuntimeModel:(HistoricalBar *)coreDataBar {
    HistoricalBarModel *runtimeBar = [[HistoricalBarModel alloc] init];
    
    runtimeBar.symbol = coreDataBar.symbol;
    runtimeBar.date = coreDataBar.date;
    runtimeBar.open = coreDataBar.open;
    runtimeBar.high = coreDataBar.high;
    runtimeBar.low = coreDataBar.low;
    runtimeBar.close = coreDataBar.close;
    runtimeBar.adjustedClose = coreDataBar.adjustedClose;
    runtimeBar.volume = coreDataBar.volume;
    runtimeBar.timeframe = (BarTimeframe)coreDataBar.timeframe;
    
    return runtimeBar;
}

- (CompanyInfoModel *)convertCoreDataCompanyInfoToRuntimeModel:(CompanyInfo *)coreDataInfo {
    CompanyInfoModel *runtimeInfo = [[CompanyInfoModel alloc] init];
    
    runtimeInfo.symbol = coreDataInfo.symbol;
    runtimeInfo.name = coreDataInfo.name;
    runtimeInfo.sector = coreDataInfo.sector;
    runtimeInfo.industry = coreDataInfo.industry;
    runtimeInfo.companyDescription = coreDataInfo.companyDescription;
    runtimeInfo.website = coreDataInfo.website;
    runtimeInfo.ceo = coreDataInfo.ceo;
    runtimeInfo.employees = coreDataInfo.employees;
    runtimeInfo.headquarters = coreDataInfo.headquarters;
    runtimeInfo.lastUpdate = coreDataInfo.lastUpdate;
    
    return runtimeInfo;
}

- (void)saveHistoricalBarModel:(HistoricalBarModel *)barModel
                     inContext:(NSManagedObjectContext *)context {
    
    NSDate *date = barModel.date;
    if (!date) return;
    
    // Check if bar already exists
    NSFetchRequest *request = [HistoricalBar fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:
                        @"symbol == %@ AND timeframe == %d AND date == %@",
                        barModel.symbol, (int)barModel.timeframe, date];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    HistoricalBar *coreDataBar = results.firstObject;
    if (!coreDataBar) {
        coreDataBar = [NSEntityDescription insertNewObjectForEntityForName:@"HistoricalBar"
                                                    inManagedObjectContext:context];
        coreDataBar.symbol = barModel.symbol;
        coreDataBar.timeframe = barModel.timeframe;
        coreDataBar.date = date;
    }
    
    // Update bar data from runtime model
    coreDataBar.open = barModel.open;
    coreDataBar.high = barModel.high;
    coreDataBar.low = barModel.low;
    coreDataBar.close = barModel.close;
    coreDataBar.adjustedClose = barModel.adjustedClose;
    coreDataBar.volume = barModel.volume;
}

#pragma mark - Notifications

- (void)broadcastQuoteUpdate:(MarketQuoteModel *)quote {
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

- (void)broadcastHistoricalDataUpdate:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol {
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
                   completion:(void(^)(MarketQuoteModel * _Nullable quote, NSError * _Nullable error))completion {
    
    [[DataManager sharedManager] requestQuoteForSymbol:symbol completion:^(MarketData *marketData, NSError *error) {
        if (marketData) {
            MarketQuoteModel *runtimeQuote = [MarketQuoteModel quoteFromMarketData:marketData];
            [self cacheQuote:runtimeQuote];
            [self saveQuoteModelToCoreData:runtimeQuote];
            
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
