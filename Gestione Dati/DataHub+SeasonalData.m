//
//  DataHub+SeasonalData.m
//  TradingApp
//

#import "DataHub+SeasonalData.h"
#import "DataHub+Private.h"
#import "DataManager.h"
#import "SeasonalDataModel.h"
#import "QuarterlyDataPoint.h"
#import "CommonTypes.h"

// Cache key format: "seasonal_SYMBOL_DATATYPE" (e.g., "seasonal_AAPL_revenue")
static NSString *const kSeasonalCacheKeyFormat = @"seasonal_%@_%@";

// TTL for seasonal data: 6 hours (quarterly data doesn't change often)
static NSTimeInterval const kSeasonalDataTTL = 6 * 60 * 60; // 6 hours

@implementation DataHub (SeasonalData)

#pragma mark - Seasonal Data Cache Management

- (void)initializeSeasonalDataCache {
    if (!self.seasonalDataCache) {
        self.seasonalDataCache = [NSMutableDictionary dictionary];
        self.seasonalCacheTimestamps = [NSMutableDictionary dictionary];
    }
}

- (NSString *)cacheKeyForSymbol:(NSString *)symbol dataType:(NSString *)dataType {
    return [NSString stringWithFormat:kSeasonalCacheKeyFormat,
            [symbol uppercaseString], [dataType lowercaseString]];
}

- (BOOL)isSeasonalCacheStale:(NSString *)cacheKey {
    NSDate *timestamp = self.seasonalCacheTimestamps[cacheKey];
    if (!timestamp) return YES;
    
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:timestamp];
    return age > kSeasonalDataTTL;
}

- (void)updateSeasonalCacheTimestamp:(NSString *)cacheKey {
    [self initializeSeasonalDataCache];
    self.seasonalCacheTimestamps[cacheKey] = [NSDate date];
}

#pragma mark - Public API

- (void)requestSeasonalDataForSymbol:(NSString *)symbol
                            dataType:(NSString *)dataType
                          completion:(void (^)(SeasonalDataModel * _Nullable data, NSError * _Nullable error))completion {
    
    if (!symbol || symbol.length == 0 || !dataType || dataType.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol and dataType are required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    if (!completion) return;
    
    [self initializeSeasonalDataCache];
    
    NSString *normalizedSymbol = [symbol uppercaseString];
    NSString *normalizedDataType = [dataType lowercaseString];
    NSString *cacheKey = [self cacheKeyForSymbol:normalizedSymbol dataType:normalizedDataType];
    
    NSLog(@"📊 DataHub: Requesting seasonal data for %@ (%@)", normalizedSymbol, normalizedDataType);
    
    // 1. Check memory cache first
    SeasonalDataModel *cachedData = self.seasonalDataCache[cacheKey];
    BOOL isStale = [self isSeasonalCacheStale:cacheKey];
    
    // 2. Return cached data immediately if fresh
    if (cachedData && !isStale) {
        NSLog(@"✅ DataHub: Returning fresh cached seasonal data for %@", cacheKey);
        completion(cachedData, nil);
        return;
    }
    
    // 3. Return stale cached data immediately, then refresh in background
    if (cachedData && isStale) {
        NSLog(@"📦 DataHub: Returning stale cached data, refreshing in background for %@", cacheKey);
        completion(cachedData, nil);
        
        // Continue to refresh in background...
    }
    
    // 4. Fetch fresh data from DataManager -> DownloadManager -> OtherDataSource
    NSLog(@"🔄 DataHub: Fetching fresh seasonal data for %@", cacheKey);
    
    NSDictionary *parameters = @{
           @"symbol": normalizedSymbol,
           @"wrapper": normalizedDataType
       };
       
       [[DataManager sharedManager] requestZacksData:parameters
                                          completion:^(SeasonalDataModel * _Nullable seasonalModel, NSError * _Nullable error) {
           
           if (error) {
               NSLog(@"❌ DataHub: Failed to fetch seasonal data for %@: %@", cacheKey, error.localizedDescription);
               
               // If we have cached data (even stale), and this is first request, return error
               if (!cachedData) {
                   completion(nil, error);
               }
               // If we already returned stale data, don't call completion again
               return;
           }
           
           if (!seasonalModel) {
               NSLog(@"❌ DataHub: DataManager returned nil SeasonalDataModel for %@", cacheKey);
               
               if (!cachedData) {
                   NSError *conversionError = [NSError errorWithDomain:@"DataHub"
                                                                  code:500
                                                              userInfo:@{NSLocalizedDescriptionKey: @"Failed to get seasonal data"}];
                   completion(nil, conversionError);
               }
               return;
           }
           
           // 6. Cache the new data (no conversion needed - already SeasonalDataModel)
           [self cacheSeasonalData:seasonalModel forKey:cacheKey];
           
           NSLog(@"✅ DataHub: Successfully cached fresh seasonal data for %@ (%lu quarters)",
                 cacheKey, (unsigned long)seasonalModel.quarters.count);
           
           // 7. Return fresh data (only if we haven't already returned stale cached data)
           if (!cachedData) {
               completion(seasonalModel, nil);
               
           }
           // 8. Broadcast update notification for any listening widgets
           [self broadcastSeasonalDataUpdate:seasonalModel];
       }];
     
    
}

- (void)refreshSeasonalDataForSymbol:(NSString *)symbol
                            dataType:(NSString *)dataType
                          completion:(void (^)(SeasonalDataModel * _Nullable data, NSError * _Nullable error))completion {
    
    [self initializeSeasonalDataCache];
    
    NSString *cacheKey = [self cacheKeyForSymbol:symbol dataType:dataType];
    
    // Clear cache to force refresh
    [self.seasonalDataCache removeObjectForKey:cacheKey];
    [self.seasonalCacheTimestamps removeObjectForKey:cacheKey];
    
    // Request fresh data
    [self requestSeasonalDataForSymbol:symbol dataType:dataType completion:completion];
}

- (SeasonalDataModel *)getCachedSeasonalDataForSymbol:(NSString *)symbol
                                             dataType:(NSString *)dataType {
    [self initializeSeasonalDataCache];
    
    NSString *cacheKey = [self cacheKeyForSymbol:symbol dataType:dataType];
    return self.seasonalDataCache[cacheKey];
}

- (void)clearSeasonalCacheForSymbol:(NSString *)symbol dataType:(NSString *)dataType {
    [self initializeSeasonalDataCache];
    
    NSString *cacheKey = [self cacheKeyForSymbol:symbol dataType:dataType];
    [self.seasonalDataCache removeObjectForKey:cacheKey];
    [self.seasonalCacheTimestamps removeObjectForKey:cacheKey];
    
    NSLog(@"🗑️ DataHub: Cleared seasonal cache for %@", cacheKey);
}

- (void)clearAllSeasonalCache {
    [self initializeSeasonalDataCache];
    
    NSUInteger count = self.seasonalDataCache.count;
    [self.seasonalDataCache removeAllObjects];
    [self.seasonalCacheTimestamps removeAllObjects];
    
    NSLog(@"🗑️ DataHub: Cleared all seasonal cache (%lu entries)", (unsigned long)count);
}

#pragma mark - Cache Statistics

- (NSDictionary *)seasonalCacheStatistics {
    [self initializeSeasonalDataCache];
    
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    stats[@"totalCachedModels"] = @(self.seasonalDataCache.count);
    stats[@"cacheTimestamps"] = @(self.seasonalCacheTimestamps.count);
    
    // Calculate fresh vs stale entries
    NSInteger freshCount = 0;
    NSInteger staleCount = 0;
    
    for (NSString *cacheKey in self.seasonalDataCache.allKeys) {
        if ([self isSeasonalCacheStale:cacheKey]) {
            staleCount++;
        } else {
            freshCount++;
        }
    }
    
    stats[@"freshEntries"] = @(freshCount);
    stats[@"staleEntries"] = @(staleCount);
    stats[@"ttlHours"] = @(kSeasonalDataTTL / 3600.0);
    
    return stats;
}

#pragma mark - Private Helper Methods

- (void)cacheSeasonalData:(SeasonalDataModel *)data forKey:(NSString *)cacheKey {
    [self initializeSeasonalDataCache];
    
    self.seasonalDataCache[cacheKey] = data;
    [self updateSeasonalCacheTimestamp:cacheKey];
}



- (NSDate *)approximateQuarterEndDateForQuarter:(NSInteger)quarter year:(NSInteger)year {
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    
    switch (quarter) {
        case 1:
            components.month = 3;
            components.day = 31;
            break;
        case 2:
            components.month = 6;
            components.day = 30;
            break;
        case 3:
            components.month = 9;
            components.day = 30;
            break;
        case 4:
            components.month = 12;
            components.day = 31;
            break;
        default:
            return nil;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    return [calendar dateFromComponents:components];
}

- (void)broadcastSeasonalDataUpdate:(SeasonalDataModel *)seasonalModel {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{
            @"seasonalData": seasonalModel,
            @"symbol": seasonalModel.symbol,
            @"dataType": seasonalModel.dataType
        };
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SeasonalDataDidUpdate"
                                                            object:self
                                                          userInfo:userInfo];
    });
}

@end
