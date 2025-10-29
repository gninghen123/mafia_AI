//
//  ScoreTableWidget+DataFetching.m
//  TradingApp
//
//  Data fetching logic with priority cascade
//  ✅ FIXED: Added on-demand database scanning
//  ✅ FIXED: Corrected minBars parameter (was using timeframe enum)
//

#import "ScoreTableWidget.h"
#import "DataHub+marketdata.h"
#import "ScoreCalculator.h"
#import "DataRequirementCalculator.h"
#import "ChainDataValidator.h"
#import "ScoreTableWidget_Private.h"

@implementation ScoreTableWidget (DataFetching)

#pragma mark - Main Entry Point

- (void)loadSymbolsAndCalculateScores:(NSArray<NSString *> *)symbols {
    if (self.isCalculating) {
        NSLog(@"⚠️ Already calculating, ignoring request");
        return;
    }
    
    self.isCalculating = YES;
    self.isCancelled = NO;
    [self.currentSymbols setArray:symbols];
    
    NSLog(@"📊 Loading data for %lu symbols...", (unsigned long)symbols.count);
    
    [self showLoadingUI];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Loading data for %lu symbols...", (unsigned long)symbols.count];
    
    // Calculate requirements
    DataRequirements *requirements = [DataRequirementCalculator calculateRequirementsForStrategy:self.currentStrategy];
    
    // Fetch data with priority cascade
    [self fetchDataForSymbols:symbols requirements:requirements completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *symbolData, NSError *error) {
        
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

/**
 * Main entry point for data fetching
 * Ensures database is scanned before attempting to fetch data
 */
- (void)fetchDataForSymbols:(NSArray<NSString *> *)symbols
               requirements:(DataRequirements *)requirements
                 completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *, NSError *))completion {
    
    // ✅ FIX: Check if StooqDataManager database needs scanning
    if (self.stooqManager && self.stooqManager.symbolCount == 0) {
        NSLog(@"📂 StooqDataManager database not scanned yet, scanning now...");
        
        [self.stooqManager scanDatabaseWithCompletion:^(NSArray<NSString *> *availableSymbols, NSError *error) {
            if (error) {
                NSLog(@"❌ Database scan failed: %@", error);
                if (completion) completion(@{}, error);
                return;
            }
            
            NSLog(@"✅ Database scanned: %ld symbols available", (long)availableSymbols.count);
            
            // Now proceed with normal fetch
            [self performFetchDataForSymbols:symbols requirements:requirements completion:completion];
        }];
        
        return;
    }
    
    // Database already scanned (or StooqDataManager not available), proceed normally
    [self performFetchDataForSymbols:symbols requirements:requirements completion:completion];
}

/**
 * Internal implementation of data fetching with priority cascade
 * PHASE 1: Cache → PHASE 2: StooqDataManager → PHASE 3: DataHub
 */
- (void)performFetchDataForSymbols:(NSArray<NSString *> *)symbols
                      requirements:(DataRequirements *)requirements
                        completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *, NSError *))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *resultData = [NSMutableDictionary dictionary];
        NSMutableArray *missingSymbols = [NSMutableArray array];
        
        // PHASE 1: Check cache
        NSLog(@"🔍 PHASE 1: Checking cache for %lu symbols...", (unsigned long)symbols.count);
        
        for (NSString *symbol in symbols) {
            NSArray<HistoricalBarModel *> *cachedData = self.symbolDataCache[symbol];
            
            if (cachedData && [self isDataValid:cachedData forRequirements:requirements]) {
                NSLog(@"✅ Cache hit: %@", symbol);
                resultData[symbol] = cachedData;
            } else {
                [missingSymbols addObject:symbol];
            }
        }
        
        if (missingSymbols.count == 0) {
            NSLog(@"✅ All data found in cache");
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([resultData copy], nil);
            });
            return;
        }
        
        // PHASE 2: Try StooqDataManager
        NSLog(@"📂 PHASE 2: Requesting %lu symbols from StooqDataManager...", (unsigned long)missingSymbols.count);
        
        // PHASE 2: Try StooqDataManager for all missing symbols
        NSLog(@"📂 PHASE 2: Requesting %lu symbols from StooqDataManager...", (unsigned long)missingSymbols.count);
        
        if (self.stooqManager) {
            // ✅ FIX: Use requirements.minimumBars instead of requirements.timeframe
            [self.stooqManager loadDataForSymbols:missingSymbols
                                          minBars:requirements.minimumBars
                                       completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *stooqData, NSError *stooqError) {
                
                if (self.isCancelled) {
                    NSLog(@"❌ Fetch cancelled after Stooq");
                    if (completion) {
                        NSError *cancelError = [NSError errorWithDomain:@"ScoreTableWidget"
                                                                   code:-999
                                                               userInfo:@{NSLocalizedDescriptionKey: @"Cancelled by user"}];
                        completion(@{}, cancelError);
                    }
                    return;
                }
                
                // Merge Stooq results
                NSMutableArray *stillMissingSymbols = [NSMutableArray array];
                
                if (stooqData) {
                    [resultData addEntriesFromDictionary:stooqData];
                    
                    // Cache Stooq results
                    for (NSString *symbol in stooqData.allKeys) {
                        self.symbolDataCache[symbol] = stooqData[symbol];
                    }
                    
                    NSLog(@"✅ Stooq: Got data for %lu/%lu symbols",
                          (unsigned long)stooqData.count, (unsigned long)missingSymbols.count);
                    
                    // Find symbols still missing
                    for (NSString *symbol in missingSymbols) {
                        if (!stooqData[symbol]) {
                            [stillMissingSymbols addObject:symbol];
                        }
                    }
                } else {
                    // All symbols still missing
                    [stillMissingSymbols addObjectsFromArray:missingSymbols];
                }
                
                // PHASE 3: Fallback to DataHub for symbols not found in Stooq
                if (stillMissingSymbols.count > 0) {
                    NSLog(@"🌐 PHASE 3: Requesting %lu symbols from DataHub (fallback)...",
                          (unsigned long)stillMissingSymbols.count);
                    
                    dispatch_group_t dataHubGroup = dispatch_group_create();
                    
                    for (NSString *symbol in stillMissingSymbols) {
                        dispatch_group_enter(dataHubGroup);
                        
                        [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                                           timeframe:requirements.timeframe
                                                            barCount:requirements.minimumBars
                                                   needExtendedHours:NO
                                                          completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
                            
                            if (self.isCancelled) {
                                NSLog(@"❌ Fetch cancelled during DataHub fallback for %@", symbol);
                                dispatch_group_leave(dataHubGroup);
                                return;
                            }
                            
                            if (bars && bars.count > 0 && [self isDataValid:bars forRequirements:requirements]) {
                                NSLog(@"✅ DataHub: Got valid data for %@ (fallback)", symbol);
                                @synchronized (resultData) {
                                    resultData[symbol] = bars;
                                    self.symbolDataCache[symbol] = bars;
                                }
                            } else {
                                NSLog(@"❌ DataHub: No valid data for %@", symbol);
                            }
                            
                            dispatch_group_leave(dataHubGroup);
                        }];
                    }
                    
                    // Wait for all DataHub fallback requests
                    dispatch_group_notify(dataHubGroup, dispatch_get_main_queue(), ^{
                        NSLog(@"✅ Data fetching complete: %lu/%lu symbols (Cache + Stooq + DataHub)",
                              (unsigned long)resultData.count, (unsigned long)symbols.count);
                        
                        if (resultData.count == 0) {
                            NSError *error = [NSError errorWithDomain:@"ScoreTableWidget"
                                                                 code:-1
                                                             userInfo:@{NSLocalizedDescriptionKey: @"No data could be loaded for any symbol"}];
                            if (completion) completion(@{}, error);
                        } else {
                            if (completion) completion([resultData copy], nil);
                        }
                    });
                } else {
                    // All symbols found in Stooq
                    NSLog(@"✅ Data fetching complete: %lu/%lu symbols (Cache + Stooq)",
                          (unsigned long)resultData.count, (unsigned long)symbols.count);
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (resultData.count == 0) {
                            NSError *error = [NSError errorWithDomain:@"ScoreTableWidget"
                                                                 code:-1
                                                             userInfo:@{NSLocalizedDescriptionKey: @"No data could be loaded for any symbol"}];
                            if (completion) completion(@{}, error);
                        } else {
                            if (completion) completion([resultData copy], nil);
                        }
                    });
                }
            }];
        } else {
            // No StooqDataManager, go directly to DataHub
            NSLog(@"⚠️ StooqDataManager not available, using DataHub for all symbols");
            
            dispatch_group_t dataHubGroup = dispatch_group_create();
            
            for (NSString *symbol in missingSymbols) {
                dispatch_group_enter(dataHubGroup);
                
                [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                                   timeframe:requirements.timeframe
                                                    barCount:requirements.minimumBars
                                           needExtendedHours:NO
                                                  completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
                    
                    if (self.isCancelled) {
                        NSLog(@"❌ Fetch cancelled during DataHub for %@", symbol);
                        dispatch_group_leave(dataHubGroup);
                        return;
                    }
                    
                    if (bars && bars.count > 0 && [self isDataValid:bars forRequirements:requirements]) {
                        NSLog(@"✅ DataHub: Got valid data for %@", symbol);
                        @synchronized (resultData) {
                            resultData[symbol] = bars;
                            self.symbolDataCache[symbol] = bars;
                        }
                    }
                    
                    dispatch_group_leave(dataHubGroup);
                }];
            }
            
            dispatch_group_notify(dataHubGroup, dispatch_get_main_queue(), ^{
                NSLog(@"✅ Data fetching complete: %lu/%lu symbols (Cache + DataHub)",
                      (unsigned long)resultData.count, (unsigned long)symbols.count);
                
                if (resultData.count == 0) {
                    NSError *error = [NSError errorWithDomain:@"ScoreTableWidget"
                                                         code:-1
                                                     userInfo:@{NSLocalizedDescriptionKey: @"No data could be loaded for any symbol"}];
                    if (completion) completion(@{}, error);
                } else {
                    if (completion) completion([resultData copy], nil);
                }
            });
        }
    });
}

- (BOOL)isDataValid:(NSArray<HistoricalBarModel *> *)data forRequirements:(DataRequirements *)requirements {
    if (!data || data.count < requirements.minimumBars) {
        return NO;
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

        // ✅ FIX: This was the original bug - using requirements.timeframe instead of minimumBars
        // Now this code path is not used anymore since we moved to performFetchDataForSymbols
        [self.stooqManager loadDataForSymbols:symbols
                                      minBars:requirements.minimumBars
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
            [self hideLoadingUI];
            
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
