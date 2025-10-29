//
//  ScoreTableWidget+DataFetching.m
//  TradingApp
//
//  Data fetching logic with priority cascade
//

#import "ScoreTableWidget.h"
#import "DataHub.h"
#import "ScoreCalculator.h"
#import "DataRequirementCalculator.h"
#import "ChainDataValidator.h"
#import "ScoreTableWidget_Private.h"  // ✅ IMPORTA IL PRIVATE HEADER

@implementation ScoreTableWidget (DataFetching)

#pragma mark - Main Entry Point

- (void)loadSymbolsAndCalculateScores:(NSArray<NSString *> *)symbols {
    if (self.isCalculating) {
        NSLog(@"⚠️ Already calculating, ignoring request");
        return;
    }
    
    self.isCalculating = YES;
    self.isCancelled = NO; // ✅ Reset cancel flag
    [self.currentSymbols setArray:symbols];
    
    NSLog(@"📊 Loading data for %lu symbols...", (unsigned long)symbols.count);
    
    // ✅ Show progress UI
    [self showLoadingUI];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Loading data for %lu symbols...", (unsigned long)symbols.count];
    
    // Calculate requirements
    DataRequirements *requirements = [DataRequirementCalculator calculateRequirementsForStrategy:self.currentStrategy];
    
    // Fetch data with priority cascade
    [self fetchDataForSymbols:symbols requirements:requirements completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *symbolData, NSError *error) {
        
        // ✅ Check if cancelled
        if (self.isCancelled) {
            NSLog(@"❌ Calculation was cancelled");
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isCalculating = NO;
                [self hideLoadingUI];
                self.statusLabel.stringValue = @"Cancelled";
            });
            return;
        }
        
        if (error) {
            NSLog(@"❌ Data fetch failed: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isCalculating = NO;
                [self hideLoadingUI];
                self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
            });
            return;
        }
        
        [self calculateScoresWithData:symbolData];
    }];
}

#pragma mark - Data Fetching Priority Cascade

- (void)fetchDataForSymbols:(NSArray<NSString *> *)symbols
               requirements:(DataRequirements *)requirements
                 completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *symbolData, NSError *error))completion {
    
    NSLog(@"🔄 Starting data fetch for %lu symbols with priority cascade", (unsigned long)symbols.count);
    
    __block NSInteger processedCount = 0;
    __block NSInteger totalSymbols = symbols.count;
    NSMutableDictionary<NSString *, NSArray<HistoricalBarModel *> *> *results = [NSMutableDictionary dictionary];
    
    dispatch_queue_t fetchQueue = dispatch_queue_create("com.scoretable.fetch", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    for (NSString *symbol in symbols) {
        dispatch_group_enter(group);
        
        dispatch_async(fetchQueue, ^{
            // ✅ Check cancel before processing each symbol
            if (self.isCancelled) {
                NSLog(@"❌ Fetch cancelled, skipping %@", symbol);
                dispatch_group_leave(group);
                return;
            }
            
            // Try cache first
            NSArray<HistoricalBarModel *> *cachedData = self.symbolDataCache[symbol];
            if (cachedData && [self isDataValid:cachedData forRequirements:requirements]) {
                NSLog(@"💾 Using cached data for %@", symbol);
                @synchronized (results) {
                    results[symbol] = cachedData;
                }
                
                // ✅ Update progress
                @synchronized (self) {
                    processedCount++;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateProgress:processedCount total:totalSymbols];
                });
                
                dispatch_group_leave(group);
                return;
            }
            
            // Priority 1: Try DataHub
            [self fetchFromDataHub:@[symbol]
                      requirements:requirements
                        completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *data, NSError *error) {
                
                // ✅ Check cancel after DataHub fetch
                if (self.isCancelled) {
                    NSLog(@"❌ Fetch cancelled after DataHub for %@", symbol);
                    dispatch_group_leave(group);
                    return;
                }
                
                if (data[symbol] && [self isDataValid:data[symbol] forRequirements:requirements]) {
                    NSLog(@"✅ DataHub: Got valid data for %@", symbol);
                    @synchronized (results) {
                        results[symbol] = data[symbol];
                        self.symbolDataCache[symbol] = data[symbol];
                    }
                    
                    // ✅ Update progress
                    @synchronized (self) {
                        processedCount++;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateProgress:processedCount total:totalSymbols];
                    });
                    
                    dispatch_group_leave(group);
                    return;
                }
                
                // Priority 2: Try StooqDataManager
                if (self.stooqManager) {
                    NSLog(@"📂 DataHub failed, trying Stooq for %@", symbol);
                    
                    [self.stooqManager loadDataForSymbols:@[symbol]
                                                  minBars:requirements.minimumBars
                                               completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *stooqData, NSError *stooqError) {
                        
                        // ✅ Check cancel after Stooq fetch
                        if (self.isCancelled) {
                            NSLog(@"❌ Fetch cancelled after Stooq for %@", symbol);
                            dispatch_group_leave(group);
                            return;
                        }
                        
                        if (stooqData[symbol] && [self isDataValid:stooqData[symbol] forRequirements:requirements]) {
                            NSLog(@"✅ Stooq: Got valid data for %@", symbol);
                            @synchronized (results) {
                                results[symbol] = stooqData[symbol];
                                self.symbolDataCache[symbol] = stooqData[symbol];
                            }
                        } else {
                            NSLog(@"❌ All sources failed for %@", symbol);
                        }
                        
                        // ✅ Update progress
                        @synchronized (self) {
                            processedCount++;
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateProgress:processedCount total:totalSymbols];
                        });
                        
                        dispatch_group_leave(group);
                    }];
                } else {
                    NSLog(@"❌ No Stooq manager, failed for %@", symbol);
                    
                    // ✅ Update progress even on failure
                    @synchronized (self) {
                        processedCount++;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateProgress:processedCount total:totalSymbols];
                    });
                    
                    dispatch_group_leave(group);
                }
            }];
        });
    }
    
    // Wait for all fetches to complete
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // ✅ Final check if cancelled
        if (self.isCancelled) {
            NSLog(@"❌ Fetch completed but was cancelled");
            if (completion) {
                NSError *cancelError = [NSError errorWithDomain:@"ScoreTableWidget"
                                                           code:-999
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Cancelled by user"}];
                completion(@{}, cancelError);
            }
            return;
        }
        
        NSLog(@"✅ Data fetch complete: %lu/%lu symbols successful",
              (unsigned long)results.count, (unsigned long)totalSymbols);
        
        if (results.count == 0) {
            NSError *error = [NSError errorWithDomain:@"ScoreTableWidget"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"No data could be loaded for any symbol"}];
            if (completion) completion(@{}, error);
        } else {
            if (completion) completion([results copy], nil);
        }
    });
}

- (BOOL)isDataValid:(NSArray<HistoricalBarModel *> *)data forRequirements:(DataRequirements *)requirements {
    if (!data || data.count < requirements.minimumBars) {
        return NO;
    }
    
    // Check timeframe if first bar has it
    if (data.count > 0) {
        HistoricalBarModel *firstBar = data.firstObject;
        if (firstBar.timeframe != requirements.timeframe) {
            return NO;
        }
    }
    
    return YES;
}

- (void)fetchFromDataHub:(NSArray<NSString *> *)symbols
            requirements:(DataRequirements *)requirements
              completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *data, NSError *error))completion {
    
    NSLog(@"🌐 Fetching %lu symbols from DataHub...", (unsigned long)symbols.count);
    
    __block NSMutableDictionary *results = [NSMutableDictionary dictionary];
    __block NSInteger completedRequests = 0;
    __block NSError *fetchError = nil;
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSString *symbol in symbols) {
        dispatch_group_enter(group);
        
        if (!self.stooqManager) {
            NSLog(@"⚠️ StooqDataManager not initialized");
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"ScoreTableWidget"
                                                     code:-1
                                                 userInfo:@{NSLocalizedDescriptionKey: @"StooqDataManager not initialized"}];
                completion(@{}, error);
            }
            return;
        }

        [self.stooqManager loadDataForSymbols:symbols
                                      minBars:requirements.timeframe
                                   completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *cache, NSError *error) {
            if (completion) {
                completion(cache, error);
            }
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"✅ DataHub fetch complete: %lu/%lu symbols",
              (unsigned long)results.count, (unsigned long)symbols.count);
        
        if (results.count == 0 && fetchError) {
            completion(nil, fetchError);
        } else {
            completion([results copy], nil);
        }
    });
}

#pragma mark - Score Calculation

- (void)calculateScoresWithData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)symbolData {
    NSLog(@"🎯 Calculating scores for %lu symbols...", (unsigned long)symbolData.count);
    
    self.statusLabel.stringValue = @"Calculating scores...";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<ScoreResult *> *results = [ScoreCalculator calculateScoresForSymbols:symbolData
                                                                         withStrategy:self.currentStrategy];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scoreResults setArray:results];
            
            // Sort by total score (descending)
            [self.scoreResults sortUsingComparator:^NSComparisonResult(ScoreResult *obj1, ScoreResult *obj2) {
                if (obj1.totalScore > obj2.totalScore) return NSOrderedAscending;
                if (obj1.totalScore < obj2.totalScore) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            
            [self.scoreTableView reloadData];
            
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Calculated scores for %lu symbols", (unsigned long)results.count];
            
            NSLog(@"✅ Scores calculated and displayed");
        });
    });
}

- (void)refreshScores {
    if (self.currentSymbols.count == 0) {
        NSLog(@"⚠️ No symbols to refresh");
        return;
    }
    
    // Clear cache to force refresh
    [self.symbolDataCache removeAllObjects];
    
    [self loadSymbolsAndCalculateScores:self.currentSymbols];
}

@end
