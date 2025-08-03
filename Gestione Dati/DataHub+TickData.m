
//
//  DataHub+TickData.m
//  mafia_AI
//

#import "DataHub+TickData.h"
#import "DataManager+TickData.h"
#import "DataHub+Private.h"
#import "DataHub+TickDataProperties.h"

// Notification names
NSString * const DataHubTickDataUpdatedNotification = @"DataHubTickDataUpdatedNotification";
NSString * const DataHubTickStreamStartedNotification = @"DataHubTickStreamStartedNotification";
NSString * const DataHubTickStreamStoppedNotification = @"DataHubTickStreamStoppedNotification";

@implementation DataHub (TickData)

#pragma mark - Initialization

- (void)initializeTickDataCaches {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!self.tickDataCache) {
            self.tickDataCache = [NSMutableDictionary dictionary];
        }
        if (!self.tickCacheTimestamps) {
            self.tickCacheTimestamps = [NSMutableDictionary dictionary];
        }
        if (!self.activeTickStreams) {
            self.activeTickStreams = [NSMutableSet set];
        }
    });
}

#pragma mark - Tick Data API

- (void)getTickDataForSymbol:(NSString *)symbol
                       limit:(NSInteger)limit
                    fromTime:(NSString *)fromTime
                  completion:(void(^)(NSArray<TickDataModel *> *ticks, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeTickDataCaches];
    
    NSLog(@"📈 DataHub: Getting tick data for %@ (limit: %ld)", symbol, (long)limit);
    
    // 1. Check cache first
    NSString *cacheKey = [NSString stringWithFormat:@"ticks_%@_%ld_%@", symbol, (long)limit, fromTime ?: @"930"];
    NSArray<TickDataModel *> *cachedTicks = self.tickDataCache[cacheKey];
    NSDate *cacheTimestamp = self.tickCacheTimestamps[cacheKey];
    
    // 2. Check if cache is fresh (TTL: 30 seconds for tick data)
    BOOL isCacheFresh = NO;
    if (cachedTicks && cacheTimestamp) {
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:cacheTimestamp];
        isCacheFresh = (age < 30.0); // 30 second TTL for tick data
    }
    
    // 3. Return cached data if fresh
    if (isCacheFresh) {
        NSLog(@"✅ DataHub: Returning fresh cached tick data for %@ (%lu ticks)",
              symbol, (unsigned long)cachedTicks.count);
        completion(cachedTicks, YES);
        return;
    }
    
    // 4. Return stale cached data first, then fetch fresh
    if (cachedTicks) {
        NSLog(@"📤 DataHub: Returning stale cached tick data for %@, fetching fresh...", symbol);
        completion(cachedTicks, NO);
    }
    
    // 5. Fetch fresh data from DataManager
    [[DataManager sharedManager] requestRealtimeTicksForSymbol:symbol
                                                         limit:limit
                                                      fromTime:fromTime
                                                    completion:^(NSArray<TickDataModel *> *ticks, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to fetch tick data for %@: %@", symbol, error.localizedDescription);
            if (!cachedTicks) {
                completion(@[], NO);
            }
            return;
        }
        
        if (!ticks || ticks.count == 0) {
            NSLog(@"⚠️ DataHub: No tick data returned for %@", symbol);
            if (!cachedTicks) {
                completion(@[], NO);
            }
            return;
        }
        
        // 6. Cache fresh data
        @synchronized(self.tickDataCache) {
            self.tickDataCache[cacheKey] = ticks;
            self.tickCacheTimestamps[cacheKey] = [NSDate date];
        }
        
        NSLog(@"✅ DataHub: Cached fresh tick data for %@ (%lu ticks)", symbol, (unsigned long)ticks.count);
        
        // 7. Broadcast update notification
        [self broadcastTickDataUpdate:ticks forSymbol:symbol];
        
        // 8. Return fresh data
        completion(ticks, YES);
    }];
}

- (void)getExtendedTickDataForSymbol:(NSString *)symbol
                          marketType:(NSString *)marketType
                          completion:(void(^)(NSArray<TickDataModel *> *ticks, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeTickDataCaches];
    
    NSLog(@"📈 DataHub: Getting extended tick data for %@ (%@)", symbol, marketType ?: @"post");
    
    // Cache key includes market type
    NSString *cacheKey = [NSString stringWithFormat:@"extended_ticks_%@_%@", symbol, marketType ?: @"post"];
    NSArray<TickDataModel *> *cachedTicks = self.tickDataCache[cacheKey];
    NSDate *cacheTimestamp = self.tickCacheTimestamps[cacheKey];
    
    // Check cache freshness (60 seconds for extended hours)
    BOOL isCacheFresh = NO;
    if (cachedTicks && cacheTimestamp) {
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:cacheTimestamp];
        isCacheFresh = (age < 60.0); // 60 second TTL for extended hours
    }
    
    if (isCacheFresh) {
        NSLog(@"✅ DataHub: Returning fresh cached extended tick data for %@", symbol);
        completion(cachedTicks, YES);
        return;
    }
    
    // Return stale data first if available
    if (cachedTicks) {
        completion(cachedTicks, NO);
    }
    
    // Fetch fresh data
    [[DataManager sharedManager] requestExtendedTicksForSymbol:symbol
                                                    marketType:marketType
                                                    completion:^(NSArray<TickDataModel *> *ticks, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to fetch extended tick data for %@: %@", symbol, error.localizedDescription);
            if (!cachedTicks) {
                completion(@[], NO);
            }
            return;
        }
        
        // Cache and return
        @synchronized(self.tickDataCache) {
            self.tickDataCache[cacheKey] = ticks ?: @[];
            self.tickCacheTimestamps[cacheKey] = [NSDate date];
        }
        
        [self broadcastTickDataUpdate:ticks forSymbol:symbol];
        completion(ticks ?: @[], YES);
    }];
}

- (void)getFullSessionTickDataForSymbol:(NSString *)symbol
                             completion:(void(^)(NSArray<TickDataModel *> *ticks, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeTickDataCaches];
    
    NSLog(@"📈 DataHub: Getting full session tick data for %@", symbol);
    
    [[DataManager sharedManager] requestFullSessionTicksForSymbol:symbol
                                                       completion:^(NSArray<TickDataModel *> *ticks, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to fetch full session tick data for %@: %@", symbol, error.localizedDescription);
            completion(@[], NO);
            return;
        }
        
        NSLog(@"✅ DataHub: Retrieved full session tick data for %@ (%lu ticks)", symbol, (unsigned long)ticks.count);
        completion(ticks ?: @[], YES);
    }];
}

#pragma mark - Real-Time Tick Streaming

- (void)startTickStreamForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    [self initializeTickDataCaches];
    
    @synchronized(self.activeTickStreams) {
        [self.activeTickStreams addObject:symbol];
        
        // Start timer if this is the first stream
        if (self.activeTickStreams.count == 1) {
            [self startTickStreamTimer];
        }
    }
    
    NSLog(@"🔄 DataHub: Started tick stream for %@", symbol);
    
    // Broadcast notification
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubTickStreamStartedNotification
                                                            object:self
                                                          userInfo:@{@"symbol": symbol}];
    });
}

- (void)stopTickStreamForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    @synchronized(self.activeTickStreams) {
        [self.activeTickStreams removeObject:symbol];
        
        // Stop timer if no more streams
        if (self.activeTickStreams.count == 0) {
            [self stopTickStreamTimer];
        }
    }
    
    NSLog(@"⏹ DataHub: Stopped tick stream for %@", symbol);
    
    // Broadcast notification
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubTickStreamStoppedNotification
                                                            object:self
                                                          userInfo:@{@"symbol": symbol}];
    });
}

- (void)stopAllTickStreams {
    NSArray *symbolsToStop = nil;
    
    @synchronized(self.activeTickStreams) {
        symbolsToStop = [self.activeTickStreams allObjects];
        [self.activeTickStreams removeAllObjects];
        [self stopTickStreamTimer];
    }
    
    NSLog(@"⏹ DataHub: Stopped all tick streams (%lu symbols)", (unsigned long)symbolsToStop.count);
    
    // Notify for each symbol
    for (NSString *symbol in symbolsToStop) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DataHubTickStreamStoppedNotification
                                                                object:self
                                                              userInfo:@{@"symbol": symbol}];
        });
    }
}

- (BOOL)hasActiveTickStreamForSymbol:(NSString *)symbol {
    if (!symbol) return NO;
    
    @synchronized(self.activeTickStreams) {
        return [self.activeTickStreams containsObject:symbol];
    }
}

- (NSArray<NSString *> *)activeTickStreamSymbols {
    @synchronized(self.activeTickStreams) {
        return [self.activeTickStreams allObjects];
    }
}

#pragma mark - Tick Analytics

- (double)calculateVolumeDeltaForTicks:(NSArray<TickDataModel *> *)ticks {
    double buyVolume = 0.0;
    double sellVolume = 0.0;
    
    for (TickDataModel *tick in ticks) {
        switch (tick.direction) {
            case TickDirectionUp:
                buyVolume += tick.volume;
                break;
            case TickDirectionDown:
                sellVolume += tick.volume;
                break;
            case TickDirectionNeutral:
                // Split neutral volume equally
                buyVolume += tick.volume * 0.5;
                sellVolume += tick.volume * 0.5;
                break;
        }
    }
    
    return buyVolume - sellVolume; // Positive = buying pressure, Negative = selling pressure
}

- (double)calculateVWAPForTicks:(NSArray<TickDataModel *> *)ticks {
    double totalDollarVolume = 0.0;
    double totalVolume = 0.0;
    
    for (TickDataModel *tick in ticks) {
        double dollarVol = tick.price * tick.volume;
        totalDollarVolume += dollarVol;
        totalVolume += tick.volume;
    }
    
    return totalVolume > 0 ? totalDollarVolume / totalVolume : 0.0;
}

- (NSDictionary *)calculateVolumeBreakdownForTicks:(NSArray<TickDataModel *> *)ticks {
    double buyVolume = 0.0;
    double sellVolume = 0.0;
    double neutralVolume = 0.0;
    NSInteger totalTicks = ticks.count;
    
    for (TickDataModel *tick in ticks) {
        switch (tick.direction) {
            case TickDirectionUp:
                buyVolume += tick.volume;
                break;
            case TickDirectionDown:
                sellVolume += tick.volume;
                break;
            case TickDirectionNeutral:
                neutralVolume += tick.volume;
                break;
        }
    }
    
    double totalVolume = buyVolume + sellVolume + neutralVolume;
    
    return @{
        @"buyVolume": @(buyVolume),
        @"sellVolume": @(sellVolume),
        @"neutralVolume": @(neutralVolume),
        @"totalVolume": @(totalVolume),
        @"buyPercentage": @(totalVolume > 0 ? (buyVolume / totalVolume) * 100 : 0),
        @"sellPercentage": @(totalVolume > 0 ? (sellVolume / totalVolume) * 100 : 0),
        @"volumeDelta": @(buyVolume - sellVolume),
        @"totalTicks": @(totalTicks)
    };
}

- (NSArray<TickDataModel *> *)findSignificantTradesInTicks:(NSArray<TickDataModel *> *)ticks
                                             volumeThreshold:(NSInteger)threshold {
    NSMutableArray *significantTrades = [NSMutableArray array];
    
    for (TickDataModel *tick in ticks) {
        if (tick.volume >= threshold) {
            [significantTrades addObject:tick];
        }
    }
    
    return [significantTrades copy];
}

#pragma mark - Private Methods

- (void)startTickStreamTimer {
    if (self.tickStreamTimer) {
        [self.tickStreamTimer invalidate];
    }
    
    // Refresh active streams every 10 seconds
    self.tickStreamTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                            target:self
                                                          selector:@selector(refreshActiveTickStreams)
                                                          userInfo:nil
                                                           repeats:YES];
    
    NSLog(@"🔄 DataHub: Started tick stream timer (10s interval)");
}

- (void)stopTickStreamTimer {
    if (self.tickStreamTimer) {
        [self.tickStreamTimer invalidate];
        self.tickStreamTimer = nil;
    }
    
    NSLog(@"⏹ DataHub: Stopped tick stream timer");
}

- (void)refreshActiveTickStreams {
    NSArray *activeSymbols = [self activeTickStreamSymbols];
    
    if (activeSymbols.count == 0) {
        return;
    }
    
    NSLog(@"🔄 DataHub: Refreshing tick streams for %lu symbols", (unsigned long)activeSymbols.count);
    
    for (NSString *symbol in activeSymbols) {
        // Fetch latest ticks (small limit for real-time updates)
        [self getTickDataForSymbol:symbol
                             limit:50  // Last 50 trades
                          fromTime:nil
                        completion:^(NSArray<TickDataModel *> *ticks, BOOL isFresh) {
            // Data will be cached and notifications sent automatically
        }];
    }
}

- (void)broadcastTickDataUpdate:(NSArray<TickDataModel *> *)ticks forSymbol:(NSString *)symbol {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubTickDataUpdatedNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"symbol": symbol,
                                                              @"ticks": ticks,
                                                              @"timestamp": [NSDate date],
                                                              @"tickCount": @(ticks.count)
                                                          }];
    });
}

@end
