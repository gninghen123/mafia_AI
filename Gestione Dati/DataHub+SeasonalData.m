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
    
    // Create request parameters for Zacks API
    NSDictionary *parameters = @{
        @"symbol": normalizedSymbol,
        @"wrapper": normalizedDataType
    };
    
    [[DataManager sharedManager] requestZacksData:parameters
                                       completion:^(NSDictionary * _Nullable rawData, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"❌ DataHub: Failed to fetch seasonal data for %@: %@", cacheKey, error.localizedDescription);
            
            // If we have cached data (even stale), and this is first request, return error
            if (!cachedData) {
                completion(nil, error);
            }
            // If we already returned stale data, don't call completion again
            return;
        }
        
        // 5. Convert raw Zacks data to SeasonalDataModel
        SeasonalDataModel *seasonalModel = [self convertZacksDataToSeasonalModel:rawData
                                                                           symbol:normalizedSymbol
                                                                         dataType:normalizedDataType];
        
        if (!seasonalModel) {
            NSLog(@"❌ DataHub: Failed to convert Zacks data to SeasonalDataModel for %@", cacheKey);
            
            if (!cachedData) {
                NSError *conversionError = [NSError errorWithDomain:@"DataHub"
                                                               code:500
                                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse seasonal data"}];
                completion(nil, conversionError);
            }
            return;
        }
        
        // 6. Cache the new data
        [self cacheSeasonalData:seasonalModel forKey:cacheKey];
        
        NSLog(@"✅ DataHub: Successfully cached fresh seasonal data for %@ (%lu quarters)",
              cacheKey, (unsigned long)seasonalModel.quarters.count);
        
        // 7. If this was the first request (no cached data), return the fresh data
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

- (SeasonalDataModel *)convertZacksDataToSeasonalModel:(NSDictionary *)rawData
                                                symbol:(NSString *)symbol
                                              dataType:(NSString *)dataType {
    
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ DataHub: Invalid raw data format from Zacks");
        return nil;
    }
    
    // Parse Zacks response format
    // Note: This is a placeholder - actual implementation depends on Zacks API response format
    NSArray *chartData = rawData[@"data"];
    if (!chartData || ![chartData isKindOfClass:[NSArray class]]) {
        NSLog(@"❌ DataHub: No chart data array found in Zacks response");
        return nil;
    }
    
    NSMutableArray<QuarterlyDataPoint *> *quarters = [NSMutableArray array];
    
    for (NSDictionary *dataPoint in chartData) {
        if (![dataPoint isKindOfClass:[NSDictionary class]]) continue;
        
        // Extract quarter information from Zacks data
        // Format may vary - adapt based on actual Zacks API response
        NSString *periodStr = dataPoint[@"period"] ?: dataPoint[@"date"];
        NSNumber *valueNum = dataPoint[@"value"] ?: dataPoint[dataType];
        
        if (!periodStr || !valueNum) continue;
        
        // Parse quarter and year from period string (e.g., "Q1 2024", "2024-Q1", etc.)
        NSInteger quarter = 0;
        NSInteger year = 0;
        NSDate *quarterEndDate = nil;
        
        if ([self parseQuarterFromPeriodString:periodStr quarter:&quarter year:&year date:&quarterEndDate]) {
            QuarterlyDataPoint *quarterPoint = [QuarterlyDataPoint dataPointWithQuarter:quarter
                                                                                    year:year
                                                                                   value:valueNum.doubleValue
                                                                          quarterEndDate:quarterEndDate];
            [quarters addObject:quarterPoint];
        }
    }
    
    if (quarters.count == 0) {
        NSLog(@"❌ DataHub: No valid quarterly data points parsed from Zacks response");
        return nil;
    }
    
    // Create SeasonalDataModel
    SeasonalDataModel *seasonalModel = [SeasonalDataModel modelWithSymbol:symbol
                                                                 dataType:dataType
                                                                 quarters:quarters];
    
    // Set metadata if available
    seasonalModel.currency = rawData[@"currency"] ?: @"USD";
    seasonalModel.units = rawData[@"units"] ?: @"";
    
    NSLog(@"✅ DataHub: Converted %lu quarters to SeasonalDataModel for %@ (%@)",
          (unsigned long)quarters.count, symbol, dataType);
    
    return seasonalModel;
}

- (BOOL)parseQuarterFromPeriodString:(NSString *)periodStr
                             quarter:(NSInteger *)quarter
                                year:(NSInteger *)year
                                date:(NSDate **)date {
    
    if (!periodStr || periodStr.length == 0) return NO;
    
    // Try various formats that Zacks might use
    NSString *normalizedPeriod = [periodStr uppercaseString];
    
    // Format: "Q1 2024", "Q2 2023", etc.
    NSRegularExpression *qYearRegex = [NSRegularExpression regularExpressionWithPattern:@"Q([1-4])\\s+(\\d{4})"
                                                                                options:0
                                                                                  error:nil];
    NSTextCheckingResult *qYearMatch = [qYearRegex firstMatchInString:normalizedPeriod
                                                              options:0
                                                                range:NSMakeRange(0, normalizedPeriod.length)];
    
    if (qYearMatch && qYearMatch.numberOfRanges >= 3) {
        NSString *quarterStr = [normalizedPeriod substringWithRange:[qYearMatch rangeAtIndex:1]];
        NSString *yearStr = [normalizedPeriod substringWithRange:[qYearMatch rangeAtIndex:2]];
        
        *quarter = quarterStr.integerValue;
        *year = yearStr.integerValue;
        
        // Set approximate quarter end date
        if (date) {
            *date = [self approximateQuarterEndDateForQuarter:*quarter year:*year];
        }
        
        return YES;
    }
    
    // Format: "2024-Q1", "2023-Q4", etc.
    NSRegularExpression *yearQRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{4})-Q([1-4])"
                                                                                options:0
                                                                                  error:nil];
    NSTextCheckingResult *yearQMatch = [yearQRegex firstMatchInString:normalizedPeriod
                                                              options:0
                                                                range:NSMakeRange(0, normalizedPeriod.length)];
    
    if (yearQMatch && yearQMatch.numberOfRanges >= 3) {
        NSString *yearStr = [normalizedPeriod substringWithRange:[yearQMatch rangeAtIndex:1]];
        NSString *quarterStr = [normalizedPeriod substringWithRange:[yearQMatch rangeAtIndex:2]];
        
        *quarter = quarterStr.integerValue;
        *year = yearStr.integerValue;
        
        if (date) {
            *date = [self approximateQuarterEndDateForQuarter:*quarter year:*year];
        }
        
        return YES;
    }
    
    NSLog(@"⚠️ DataHub: Could not parse quarter from period string: %@", periodStr);
    return NO;
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
