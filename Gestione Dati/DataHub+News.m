//
//  DataHub+News.m
//  TradingApp
//
//  Implementation for DataHub news extension with memory caching
//  Follows DataHub pattern: cache + DataManager delegation
//

#import "DataHub+News.h"
#import "DataHub+Private.h"
#import "DataManager.h"
#import "DataManager+News.h"
#import "CommonTypes.h"

// Cache keys and internal data structures
static NSString *const kNewsCachePrefix = @"news_";
static NSString *const kNewsCacheTimestampPrefix = @"news_ts_";

@implementation DataHub (News)

#pragma mark - Lazy Loading of News Cache

- (NSMutableDictionary<NSString *, NSArray<NewsModel *> *> *)newsCache {
    static NSMutableDictionary *_newsCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _newsCache = [NSMutableDictionary dictionary];
    });
    return _newsCache;
}

- (NSMutableDictionary<NSString *, NSDate *> *)newsCacheTimestamps {
    static NSMutableDictionary *_newsCacheTimestamps = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _newsCacheTimestamps = [NSMutableDictionary dictionary];
    });
    return _newsCacheTimestamps;
}

#pragma mark - Main News Methods

- (void)getNewsForSymbol:(NSString *)symbol
                   limit:(NSInteger)limit
            forceRefresh:(BOOL)forceRefresh
              completion:(void(^)(NSArray<NewsModel *> *news, BOOL isFresh, NSError * _Nullable error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol for news request"}];
        if (completion) completion(@[], NO, error);
        return;
    }
    
    if (!completion) {
        NSLog(@"⚠️ DataHub: No completion block provided for news request");
        return;
    }
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@_%ld", kNewsCachePrefix, symbol.uppercaseString, (long)limit];
    
    // Check cache first (unless force refresh)
    if (!forceRefresh) {
        NSArray<NewsModel *> *cachedNews = [self getCachedNewsForKey:cacheKey];
        if (cachedNews) {
            NSLog(@"📰 DataHub: Returning cached news for %@ (%lu items)", symbol, (unsigned long)cachedNews.count);
            completion(cachedNews, YES, nil);
            return;
        }
    }
    
    NSLog(@"📰 DataHub: Fetching fresh news for %@ (limit: %ld)", symbol, (long)limit);
    
    // Fetch from DataManager
    DataManager *dataManager = [DataManager sharedManager];
    [dataManager requestNewsForSymbol:symbol
                                limit:limit > 0 ? limit : 50
                           completion:^(NSArray<NewsModel *> *news, NSError *error) {
        
        if (error) {
            NSLog(@"❌ DataHub: News request failed for %@: %@", symbol, error.localizedDescription);
            completion(@[], NO, error);
            return;
        }
        
        // Cache the results
        [self cacheNews:news forKey:cacheKey withTTL:NewsCacheTTLMedium];
        
        NSLog(@"✅ DataHub: Cached %lu news items for %@", (unsigned long)news.count, symbol);
        completion(news, YES, nil);
    }];
}

- (void)getNewsForSymbol:(NSString *)symbol
                newsType:(DataRequestType)newsType
              completion:(void(^)(NSArray<NewsModel *> *news, BOOL isFresh, NSError * _Nullable error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol for specific news type request"}];
        if (completion) completion(@[], NO, error);
        return;
    }
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@_%ld", kNewsCachePrefix, symbol.uppercaseString, (long)newsType];
    
    // Check cache first
    NSArray<NewsModel *> *cachedNews = [self getCachedNewsForKey:cacheKey];
    if (cachedNews) {
        NSLog(@"📰 DataHub: Returning cached %@ news for %@ (%lu items)",
              DataRequestTypeToString(newsType), symbol, (unsigned long)cachedNews.count);
        completion(cachedNews, YES, nil);
        return;
    }
    
    NSLog(@"📰 DataHub: Fetching fresh %@ news for %@", DataRequestTypeToString(newsType), symbol);
    
    // Determine appropriate limit and TTL based on news type
    NSInteger limit;
    NewsCacheTTL ttl;
    
    switch (newsType) {
        case DataRequestTypeSECFilings:
            limit = 40;
            ttl = NewsCacheTTLLong;
            break;
        case DataRequestTypePressReleases:
            limit = 25;
            ttl = NewsCacheTTLLong;
            break;
        default:
            limit = 20;
            ttl = NewsCacheTTLMedium;
            break;
    }
    
    // Fetch from DataManager
    DataManager *dataManager = [DataManager sharedManager];
    [dataManager requestNewsForSymbol:symbol
                             newsType:newsType
                                limit:limit
                      preferredSource:DataSourceTypeOther
                           completion:^(NSArray<NewsModel *> *news, NSError *error) {
        
        if (error) {
            NSLog(@"❌ DataHub: %@ news request failed for %@: %@",
                  DataRequestTypeToString(newsType), symbol, error.localizedDescription);
            completion(@[], NO, error);
            return;
        }
        
        // Cache the results
        [self cacheNews:news forKey:cacheKey withTTL:ttl];
        
        NSLog(@"✅ DataHub: Cached %lu %@ news items for %@",
              (unsigned long)news.count, DataRequestTypeToString(newsType), symbol);
        completion(news, YES, nil);
    }];
}

- (void)getAggregatedNewsForSymbol:(NSString *)symbol
                       fromSources:(NSArray<NSNumber *> *)sources
                        completion:(void(^)(NSArray<NewsModel *> *news, NSError * _Nullable error))completion {
    
    if (!symbol || symbol.length == 0 || !sources || sources.count == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters for aggregated news request"}];
        if (completion) completion(@[], error);
        return;
    }
    
    NSMutableArray<NewsModel *> *allNews = [NSMutableArray array];
    NSMutableArray<NSError *> *errors = [NSMutableArray array];
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSNumber *sourceNum in sources) {
        DataRequestType newsType = [sourceNum integerValue];
        
        dispatch_group_enter(group);
        [self getNewsForSymbol:symbol
                      newsType:newsType
                    completion:^(NSArray<NewsModel *> *news, BOOL isFresh, NSError * _Nullable error) {
            
            if (error) {
                [errors addObject:error];
            } else {
                [allNews addObjectsFromArray:news];
            }
            
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // Sort all news by date (newest first)
        NSArray<NewsModel *> *sortedNews = [allNews sortedArrayUsingComparator:^NSComparisonResult(NewsModel *obj1, NewsModel *obj2) {
            return [obj2.publishedDate compare:obj1.publishedDate];
        }];
        
        // Remove duplicates based on URL or headline
        NSArray<NewsModel *> *uniqueNews = [self removeDuplicateNews:sortedNews];
        
        NSLog(@"✅ DataHub: Aggregated %lu unique news items from %lu sources for %@",
              (unsigned long)uniqueNews.count, (unsigned long)sources.count, symbol);
        
        if (completion) {
            NSError *aggregatedError = errors.count > 0 ? errors.firstObject : nil;
            completion(uniqueNews, aggregatedError);
        }
    });
}

#pragma mark - Time-based News Queries (NEW)

/**
 * Get news for symbol within a specific date range
 * Used by annotation system to find news relevant to visible chart period
 */
- (void)getNewsForSymbol:(NSString *)symbol
               startDate:(NSDate *)startDate
                 endDate:(NSDate *)endDate
              completion:(void(^)(NSArray<NewsModel *> *news, NSError * _Nullable error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol for time-based news request"}];
        if (completion) completion(@[], error);
        return;
    }
    
    if (!startDate || !endDate) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid date range for news request"}];
        if (completion) completion(@[], error);
        return;
    }
    
    NSLog(@"📰 DataHub: Fetching news for %@ from %@ to %@", symbol, startDate, endDate);
    
    // Per ora, usa il metodo standard e filtra i risultati per date
    // TODO: In futuro, implementare query diretta con date range nell'API
    [self getNewsForSymbol:symbol
                     limit:100  // Prendi più news per avere copertura del range
              forceRefresh:NO
                completion:^(NSArray<NewsModel *> *allNews, BOOL isFresh, NSError * _Nullable error) {
        
        if (error) {
            if (completion) completion(@[], error);
            return;
        }
        
        // Filtra news nel range di date
        NSPredicate *datePredicate = [NSPredicate predicateWithBlock:^BOOL(NewsModel *news, NSDictionary *bindings) {
            return [news.publishedDate compare:startDate] != NSOrderedAscending &&
                   [news.publishedDate compare:endDate] != NSOrderedDescending;
        }];
        
        NSArray<NewsModel *> *filteredNews = [allNews filteredArrayUsingPredicate:datePredicate];
        
        NSLog(@"✅ DataHub: Found %lu news items for %@ in date range (from %lu total)",
              (unsigned long)filteredNews.count, symbol, (unsigned long)allNews.count);
        
        if (completion) completion(filteredNews, nil);
    }];
}

#pragma mark - Cache Management

- (void)cacheNews:(NSArray<NewsModel *> *)news forKey:(NSString *)cacheKey withTTL:(NewsCacheTTL)ttl {
    if (!news || !cacheKey) return;
    
    self.newsCache[cacheKey] = news;
    self.newsCacheTimestamps[cacheKey] = [NSDate date];
    
    // Schedule cache invalidation
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ttl * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.newsCache removeObjectForKey:cacheKey];
        [self.newsCacheTimestamps removeObjectForKey:cacheKey];
    });
}

- (NSArray<NewsModel *> *)getCachedNewsForKey:(NSString *)cacheKey {
    NSArray<NewsModel *> *cachedNews = self.newsCache[cacheKey];
    NSDate *timestamp = self.newsCacheTimestamps[cacheKey];
    
    if (!cachedNews || !timestamp) {
        return nil;
    }
    
    // Check if cache is still valid (this is redundant with auto-invalidation but safer)
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:timestamp];
    if (age > NewsCacheTTLLong) { // Use longest TTL as maximum
        [self.newsCache removeObjectForKey:cacheKey];
        [self.newsCacheTimestamps removeObjectForKey:cacheKey];
        return nil;
    }
    
    return cachedNews;
}

- (void)clearNewsCacheForSymbol:(NSString *)symbol {
    if (symbol) {
        // Clear cache for specific symbol
        NSString *prefix = [NSString stringWithFormat:@"%@%@", kNewsCachePrefix, symbol.uppercaseString];
        NSArray *keysToRemove = [self.newsCache.allKeys filteredArrayUsingPredicate:
                                [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", prefix]];
        
        for (NSString *key in keysToRemove) {
            [self.newsCache removeObjectForKey:key];
            [self.newsCacheTimestamps removeObjectForKey:key];
        }
        
        NSLog(@"🗑️ DataHub: Cleared news cache for %@ (%lu entries)", symbol, (unsigned long)keysToRemove.count);
    } else {
        // Clear all news cache
        NSUInteger count = self.newsCache.count;
        [self.newsCache removeAllObjects];
        [self.newsCacheTimestamps removeAllObjects];
        
        NSLog(@"🗑️ DataHub: Cleared all news cache (%lu entries)", (unsigned long)count);
    }
}

- (NSDictionary *)getNewsCacheStatistics {
    NSUInteger totalEntries = self.newsCache.count;
    NSUInteger totalNewsItems = 0;
    
    for (NSArray *newsArray in self.newsCache.allValues) {
        totalNewsItems += newsArray.count;
    }
    
    return @{
        @"totalCacheEntries": @(totalEntries),
        @"totalNewsItems": @(totalNewsItems),
        @"cacheKeys": self.newsCache.allKeys ?: @[]
    };
}

- (void)preloadNewsForSymbols:(NSArray<NSString *> *)symbols {
    NSLog(@"📰 DataHub: Preloading news for %lu symbols", (unsigned long)symbols.count);
    
    for (NSString *symbol in symbols) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [self getNewsForSymbol:symbol
                             limit:20
                      forceRefresh:NO
                        completion:^(NSArray<NewsModel *> *news, BOOL isFresh, NSError * _Nullable error) {
                // Background preloading - don't need to handle response
                if (!error) {
                    NSLog(@"📰 DataHub: Preloaded %lu news items for %@", (unsigned long)news.count, symbol);
                }
            }];
        });
    }
}

#pragma mark - Helper Methods

- (NSArray<NewsModel *> *)removeDuplicateNews:(NSArray<NewsModel *> *)news {
    NSMutableArray<NewsModel *> *uniqueNews = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIdentifiers = [NSMutableSet set];
    
    for (NewsModel *newsItem in news) {
        // Create identifier based on URL or headline + source
        NSString *identifier;
        if (newsItem.url && newsItem.url.length > 0) {
            identifier = newsItem.url;
        } else {
            identifier = [NSString stringWithFormat:@"%@_%@", newsItem.headline, newsItem.source];
        }
        
        if (![seenIdentifiers containsObject:identifier]) {
            [seenIdentifiers addObject:identifier];
            [uniqueNews addObject:newsItem];
        }
    }
    
    return [uniqueNews copy];
}

// DataHub+News.m - AGGIUNGI QUESTE IMPLEMENTAZIONI

- (void)getNewsAroundDate:(NSDate *)anomalyDate
                forSymbol:(NSString *)symbol
             hoursBefore:(NSInteger)hoursBefore
              hoursAfter:(NSInteger)hoursAfter
            forceRefresh:(BOOL)forceRefresh
              completion:(void(^)(NSArray<NewsModel *> *news, BOOL isFresh, NSError *error))completion {
    
    if (!anomalyDate || !symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters for news request"}];
        if (completion) completion(@[], NO, error);
        return;
    }
    
    // Calcola range temporale
    NSDate *startDate = [anomalyDate dateByAddingTimeInterval:-hoursBefore * 3600];
    NSDate *endDate = [anomalyDate dateByAddingTimeInterval:hoursAfter * 3600];
    
    [self getNewsForSymbol:symbol
                 startDate:startDate
                   endDate:endDate
              forceRefresh:forceRefresh
                completion:completion];
}

- (void)getNewsForSymbol:(NSString *)symbol
               startDate:(NSDate *)startDate
                 endDate:(NSDate *)endDate
            forceRefresh:(BOOL)forceRefresh
              completion:(void(^)(NSArray<NewsModel *> *news, BOOL isFresh, NSError *error))completion {
    
    if (!symbol || symbol.length == 0 || !startDate || !endDate) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters"}];
        if (completion) completion(@[], NO, error);
        return;
    }
    
    // Genera cache key specifico per il range temporale
    NSTimeInterval startTimestamp = [startDate timeIntervalSince1970];
    NSTimeInterval endTimestamp = [endDate timeIntervalSince1970];
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@_%.0f_%.0f",
                          kNewsCachePrefix,
                          symbol.uppercaseString,
                          startTimestamp,
                          endTimestamp];
    
    // Check cache (se non forceRefresh)
    if (!forceRefresh) {
        NSArray<NewsModel *> *cachedNews = [self getCachedNewsForKey:cacheKey];
        if (cachedNews) {
            // Filtra per date range (safety check)
            NSArray *filteredNews = [self filterNews:cachedNews betweenStart:startDate andEnd:endDate];
            NSLog(@"📰 DataHub: Returning cached news for %@ (%lu items in range)", symbol, (unsigned long)filteredNews.count);
            completion(filteredNews, YES, nil);
            return;
        }
    }
    
    NSLog(@"📰 DataHub: Fetching news for %@ between %@ and %@", symbol, startDate, endDate);
    
    // Fetch from DataManager
    DataManager *dataManager = [DataManager sharedManager];
    
    // Prima prendi tutte le news (API potrebbero non supportare filtro date)
    [dataManager requestNewsForSymbol:symbol
                                limit:100  // Prendi più news per poi filtrare
                           completion:^(NSArray<NewsModel *> *allNews, NSError *error) {
        
        if (error) {
            NSLog(@"❌ DataHub: Failed to fetch news: %@", error.localizedDescription);
            completion(@[], NO, error);
            return;
        }
        
        // Filtra per date range
        NSArray<NewsModel *> *filteredNews = [self filterNews:allNews betweenStart:startDate andEnd:endDate];
        
        NSLog(@"✅ DataHub: Fetched %lu news, %lu in date range", (unsigned long)allNews.count, (unsigned long)filteredNews.count);
        
        // Cache todo
      //  [self cache:filteredNews forKey:cacheKey wit];
        
        completion(filteredNews, NO, nil);
    }];
}

#pragma mark - Helper Methods

- (NSArray<NewsModel *> *)filterNews:(NSArray<NewsModel *> *)news
                        betweenStart:(NSDate *)startDate
                              andEnd:(NSDate *)endDate {
    
    return [news filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NewsModel *newsItem, NSDictionary *bindings) {
        if (!newsItem.publishedDate) return NO;
        
        NSComparisonResult startComparison = [newsItem.publishedDate compare:startDate];
        NSComparisonResult endComparison = [newsItem.publishedDate compare:endDate];
        
        return (startComparison != NSOrderedAscending && endComparison != NSOrderedDescending);
    }]];
}

@end
