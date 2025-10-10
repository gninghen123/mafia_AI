//
//  StooqDataManager+Backtest.m
//  TradingApp
//
//  Implementation of backtest-specific data loading
//

#import "StooqDataManager+Backtest.h"

@implementation StooqDataManager (Backtest)

#pragma mark - Extended Range Loading

- (void)loadExtendedDataForSymbols:(NSArray<NSString *> *)symbols
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                           maxBars:(NSInteger)maxBars
                        completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> * _Nullable, NSError * _Nullable))completion {
    
    if (!symbols || symbols.count == 0) {
        NSError *error = [NSError errorWithDomain:@"StooqDataManager"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"No symbols provided"}];
        completion(nil, error);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Calculate extended start date with safety margin
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSInteger safetyMargin = 10; // Extra bars for safety
        NSInteger totalLookback = maxBars + safetyMargin;
        
        NSDate *extendedStart = [calendar dateByAddingUnit:NSCalendarUnitDay
                                                     value:-totalLookback
                                                    toDate:startDate
                                                   options:0];
        
        NSLog(@"📊 Loading extended data range for backtest:");
        NSLog(@"   Symbols: %lu", (unsigned long)symbols.count);
        NSLog(@"   Backtest range: %@ → %@",
              [self formatDate:startDate], [self formatDate:endDate]);
        NSLog(@"   Extended start: %@ (-%ld bars + %ld safety)",
              [self formatDate:extendedStart], (long)maxBars, (long)safetyMargin);
        
        NSDate *loadStartTime = [NSDate date];
        
        // Load data using internal method
        [self loadDataInRange:symbols
                     fromDate:extendedStart
                       toDate:endDate
                   completion:^(NSDictionary<NSString *,NSArray<HistoricalBarModel *> *> *cache, NSError *error) {
            
            NSTimeInterval loadTime = [[NSDate date] timeIntervalSinceDate:loadStartTime];
            
            if (error) {
                NSLog(@"❌ Failed to load extended data: %@", error.localizedDescription);
                completion(nil, error);
                return;
            }
            
            if (!cache || cache.count == 0) {
                NSLog(@"⚠️ No data loaded for any symbol");
                NSError *noDataError = [NSError errorWithDomain:@"StooqDataManager"
                                                           code:-2
                                                       userInfo:@{NSLocalizedDescriptionKey: @"No data available for symbols"}];
                completion(nil, noDataError);
                return;
            }
            
            // Calculate statistics
            NSInteger totalBars = 0;
            for (NSArray *bars in cache.allValues) {
                totalBars += bars.count;
            }
            NSInteger avgBarsPerSymbol = cache.count > 0 ? totalBars / cache.count : 0;
            
            NSLog(@"✅ Extended data loaded successfully:");
            NSLog(@"   Symbols loaded: %lu / %lu (%.1f%%)",
                  (unsigned long)cache.count,
                  (unsigned long)symbols.count,
                  cache.count * 100.0 / symbols.count);
            NSLog(@"   Total bars: %ld", (long)totalBars);
            NSLog(@"   Avg bars/symbol: %ld", (long)avgBarsPerSymbol);
            NSLog(@"   Load time: %.2fs", loadTime);
            
            completion(cache, nil);
        }];
    });
}

- (void)loadDataForSymbols:(NSArray<NSString *> *)symbols
                  fromDate:(NSDate *)fromDate
                    toDate:(NSDate *)toDate
                completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> * _Nullable, NSError * _Nullable))completion {
    
    if (!symbols || symbols.count == 0) {
        NSError *error = [NSError errorWithDomain:@"StooqDataManager"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"No symbols provided"}];
        completion(nil, error);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSLog(@"📊 Loading data for explicit range:");
        NSLog(@"   Symbols: %lu", (unsigned long)symbols.count);
        NSLog(@"   Date range: %@ → %@", [self formatDate:fromDate], [self formatDate:toDate]);
        
        [self loadDataInRange:symbols
                     fromDate:fromDate
                       toDate:toDate
                   completion:completion];
    });
}

#pragma mark - Internal Loading Method

- (void)loadDataInRange:(NSArray<NSString *> *)symbols
               fromDate:(NSDate *)fromDate
                 toDate:(NSDate *)toDate
             completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *, NSError *))completion {
    
    NSMutableDictionary<NSString *, NSArray<HistoricalBarModel *> *> *cache = [NSMutableDictionary dictionary];
    NSInteger loadedCount = 0;
    NSInteger failedCount = 0;
    
    for (NSString *symbol in symbols) {
        @autoreleasepool {
            // Load all bars for symbol (using existing method)
            NSArray<HistoricalBarModel *> *allBars = [self loadBarsForSymbol:symbol minBars:0];
            
            if (!allBars || allBars.count == 0) {
                failedCount++;
                continue;
            }
            
            // Filter to requested range
            NSArray<HistoricalBarModel *> *filteredBars = [self filterBars:allBars
                                                                   fromDate:fromDate
                                                                     toDate:toDate];
            
            if (filteredBars.count > 0) {
                cache[symbol] = filteredBars;
                loadedCount++;
            } else {
                failedCount++;
            }
        }
    }
    
    if (cache.count == 0) {
        NSError *error = [NSError errorWithDomain:@"StooqDataManager"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"No data available for any symbol"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, error);
        });
        return;
    }
    
    NSLog(@"   Loaded: %ld symbols, Failed: %ld symbols", (long)loadedCount, (long)failedCount);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        completion([cache copy], nil);
    });
}

#pragma mark - Bar Filtering Utilities

- (NSArray<HistoricalBarModel *> *)filterBars:(NSArray<HistoricalBarModel *> *)bars
                                     fromDate:(NSDate *)fromDate
                                       toDate:(NSDate *)toDate {
    
    if (!bars || bars.count == 0) {
        return @[];
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(HistoricalBarModel *bar, NSDictionary *bindings) {
        // Include bars where: fromDate <= bar.date <= toDate
        BOOL afterOrEqualStart = [bar.date compare:fromDate] != NSOrderedAscending;
        BOOL beforeOrEqualEnd = [bar.date compare:toDate] != NSOrderedDescending;
        return afterOrEqualStart && beforeOrEqualEnd;
    }];
    
    return [bars filteredArrayUsingPredicate:predicate];
}

- (NSArray<HistoricalBarModel *> *)filterBars:(NSArray<HistoricalBarModel *> *)bars
                                       upToDate:(NSDate *)toDate {
    
    if (!bars || bars.count == 0) {
        return @[];
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(HistoricalBarModel *bar, NSDictionary *bindings) {
        // Include bars where: bar.date <= toDate
        return [bar.date compare:toDate] != NSOrderedDescending;
    }];
    
    return [bars filteredArrayUsingPredicate:predicate];
}

#pragma mark - Helper Methods

- (NSString *)formatDate:(NSDate *)date {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;
    });
    return [formatter stringFromDate:date];
}

@end
