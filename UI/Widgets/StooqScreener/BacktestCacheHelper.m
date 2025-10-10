//
//  BacktestCacheHelper.m
//  TradingApp
//
//  Implementation of cache slicing utilities
//

#import "BacktestCacheHelper.h"

@implementation BacktestCacheHelper

#pragma mark - Cache Slicing

+ (NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)sliceCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache
                                                                 upToDate:(NSDate *)referenceDate {
    
    if (!masterCache || masterCache.count == 0) {
        return @{};
    }
    
    if (!referenceDate) {
        NSLog(@"⚠️ BacktestCacheHelper: nil reference date, returning empty cache");
        return @{};
    }
    
    NSMutableDictionary<NSString *, NSArray<HistoricalBarModel *> *> *slicedCache =
        [NSMutableDictionary dictionaryWithCapacity:masterCache.count];
    
    for (NSString *symbol in masterCache) {
        @autoreleasepool {
            NSArray<HistoricalBarModel *> *allBars = masterCache[symbol];
            
            if (!allBars || allBars.count == 0) {
                continue;
            }
            
            // Find last valid index (binary search would be faster, but array is small)
            NSInteger lastValidIndex = -1;
            for (NSInteger i = 0; i < allBars.count; i++) {
                HistoricalBarModel *bar = allBars[i];
                
                if ([bar.date compare:referenceDate] == NSOrderedDescending) {
                    // This bar is AFTER reference date - stop here
                    break;
                }
                
                lastValidIndex = i;
            }
            
            // If we found at least one valid bar, add to sliced cache
            if (lastValidIndex >= 0) {
                NSArray<HistoricalBarModel *> *validBars =
                    [allBars subarrayWithRange:NSMakeRange(0, lastValidIndex + 1)];
                slicedCache[symbol] = validBars;
            }
        }
    }
    
    return [slicedCache copy];
}

+ (NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)sliceCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache
                                                                  fromDate:(NSDate *)startDate
                                                                    toDate:(NSDate *)endDate {
    
    if (!masterCache || masterCache.count == 0) {
        return @{};
    }
    
    if (!startDate || !endDate) {
        NSLog(@"⚠️ BacktestCacheHelper: nil date range, returning empty cache");
        return @{};
    }
    
    NSMutableDictionary<NSString *, NSArray<HistoricalBarModel *> *> *slicedCache =
        [NSMutableDictionary dictionaryWithCapacity:masterCache.count];
    
    for (NSString *symbol in masterCache) {
        @autoreleasepool {
            NSArray<HistoricalBarModel *> *allBars = masterCache[symbol];
            
            if (!allBars || allBars.count == 0) {
                continue;
            }
            
            // Filter bars within range
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(HistoricalBarModel *bar, NSDictionary *bindings) {
                BOOL afterOrEqualStart = [bar.date compare:startDate] != NSOrderedAscending;
                BOOL beforeOrEqualEnd = [bar.date compare:endDate] != NSOrderedDescending;
                return afterOrEqualStart && beforeOrEqualEnd;
            }];
            
            NSArray<HistoricalBarModel *> *filteredBars = [allBars filteredArrayUsingPredicate:predicate];
            
            if (filteredBars.count > 0) {
                slicedCache[symbol] = filteredBars;
            }
        }
    }
    
    return [slicedCache copy];
}

#pragma mark - Cache Statistics

+ (NSInteger)symbolCountAtDate:(NSDate *)referenceDate
                       inCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache {
    
    NSDictionary *sliced = [self sliceCache:masterCache upToDate:referenceDate];
    return sliced.count;
}

+ (NSDictionary<NSString *, NSDate *> *)dateRangeForCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    if (!cache || cache.count == 0) {
        return nil;
    }
    
    NSDate *earliestDate = nil;
    NSDate *latestDate = nil;
    
    for (NSArray<HistoricalBarModel *> *bars in cache.allValues) {
        if (bars.count == 0) continue;
        
        NSDate *firstBarDate = bars.firstObject.date;
        NSDate *lastBarDate = bars.lastObject.date;
        
        if (!earliestDate || [firstBarDate compare:earliestDate] == NSOrderedAscending) {
            earliestDate = firstBarDate;
        }
        
        if (!latestDate || [lastBarDate compare:latestDate] == NSOrderedDescending) {
            latestDate = lastBarDate;
        }
    }
    
    if (earliestDate && latestDate) {
        return @{
            @"startDate": earliestDate,
            @"endDate": latestDate
        };
    }
    
    return nil;
}

+ (NSInteger)totalBarCountInCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    if (!cache || cache.count == 0) {
        return 0;
    }
    
    NSInteger total = 0;
    for (NSArray<HistoricalBarModel *> *bars in cache.allValues) {
        total += bars.count;
    }
    
    return total;
}

#pragma mark - Cache Validation

+ (BOOL)validateCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache
        forDateRange:(NSDate *)startDate
              toDate:(NSDate *)endDate
    minBarsRequired:(NSInteger)minBarsRequired {
    
    if (!cache || cache.count == 0) {
        NSLog(@"⚠️ Cache validation failed: Empty cache");
        return NO;
    }
    
    if (!startDate || !endDate) {
        NSLog(@"⚠️ Cache validation failed: Invalid date range");
        return NO;
    }
    
    // Get cache date range
    NSDictionary *cacheRange = [self dateRangeForCache:cache];
    if (!cacheRange) {
        NSLog(@"⚠️ Cache validation failed: Could not determine cache range");
        return NO;
    }
    
    NSDate *cacheStart = cacheRange[@"startDate"];
    NSDate *cacheEnd = cacheRange[@"endDate"];
    
    // Calculate required start date (accounting for lookback)
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *requiredStart = [calendar dateByAddingUnit:NSCalendarUnitDay
                                                 value:-(minBarsRequired + 5)  // +5 safety
                                                toDate:startDate
                                               options:0];
    
    // Validate start date
    if ([cacheStart compare:requiredStart] == NSOrderedDescending) {
        NSLog(@"⚠️ Cache validation failed: Cache starts too late");
        NSLog(@"   Required: %@, Cache: %@", requiredStart, cacheStart);
        return NO;
    }
    
    // Validate end date
    if ([cacheEnd compare:endDate] == NSOrderedAscending) {
        NSLog(@"⚠️ Cache validation failed: Cache ends too early");
        NSLog(@"   Required: %@, Cache: %@", endDate, cacheEnd);
        return NO;
    }
    
    // Check symbol count at start and end dates
    NSInteger symbolsAtStart = [self symbolCountAtDate:startDate inCache:cache];
    NSInteger symbolsAtEnd = [self symbolCountAtDate:endDate inCache:cache];
    
    if (symbolsAtStart < cache.count * 0.8 || symbolsAtEnd < cache.count * 0.8) {
        NSLog(@"⚠️ Cache validation warning: Significant symbol gaps detected");
        NSLog(@"   Total symbols: %ld", (long)cache.count);
        NSLog(@"   At start (%@): %ld (%.1f%%)", startDate, (long)symbolsAtStart,
              symbolsAtStart * 100.0 / cache.count);
        NSLog(@"   At end (%@): %ld (%.1f%%)", endDate, (long)symbolsAtEnd,
              symbolsAtEnd * 100.0 / cache.count);
        // Warning only, don't fail validation
    }
    
    NSLog(@"✅ Cache validation passed:");
    NSLog(@"   Cache range: %@ → %@", cacheStart, cacheEnd);
    NSLog(@"   Required range: %@ → %@", requiredStart, endDate);
    NSLog(@"   Total symbols: %ld", (long)cache.count);
    NSLog(@"   Total bars: %ld", (long)[self totalBarCountInCache:cache]);
    
    return YES;
}

@end
