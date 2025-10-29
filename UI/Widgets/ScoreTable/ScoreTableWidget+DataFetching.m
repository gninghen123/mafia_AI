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
    [self.currentSymbols setArray:symbols];
    
    NSLog(@"📊 Loading data for %lu symbols...", (unsigned long)symbols.count);
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Loading data for %lu symbols...", (unsigned long)symbols.count];
    [self.loadingIndicator startAnimation:nil];
    
    // Calculate requirements
    DataRequirements *requirements = [DataRequirementCalculator calculateRequirementsForStrategy:self.currentStrategy];
    
    // Start fetching
    [self fetchDataForSymbols:symbols
                 requirements:requirements
                   completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *symbolData, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isCalculating = NO;
            [self.loadingIndicator stopAnimation:nil];
            
            if (error) {
                NSLog(@"❌ Error fetching data: %@", error);
                self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
                return;
            }
            
            if (symbolData.count == 0) {
                self.statusLabel.stringValue = @"No data available";
                return;
            }
            
            // Calculate scores
            [self calculateScoresWithData:symbolData];
        });
    }];
}

#pragma mark - Data Fetching Priority Cascade

- (void)fetchDataForSymbols:(NSArray<NSString *> *)symbols
               requirements:(DataRequirements *)requirements
                 completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *symbolData, NSError *error))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSMutableDictionary *resultData = [NSMutableDictionary dictionary];
        NSMutableArray *missingSymbols = [NSMutableArray array];
        
        // PHASE 1: Check cache
        NSLog(@"📦 PHASE 1: Checking cache...");
        for (NSString *symbol in symbols) {
            NSArray *cachedData = self.symbolDataCache[symbol];
            
            if (cachedData && [self isDataValid:cachedData forRequirements:requirements]) {
                resultData[symbol] = cachedData;
                NSLog(@"✅ Cache HIT: %@", symbol);
            } else {
                [missingSymbols addObject:symbol];
                NSLog(@"⚠️ Cache MISS: %@", symbol);
            }
        }
        
        if (missingSymbols.count == 0) {
            NSLog(@"✅ All data from cache!");
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([resultData copy], nil);
            });
            return;
        }
        
        // PHASE 2: Try Stooq database (only for Daily timeframe)
        if (requirements.timeframe == BarTimeframeDaily && self.stooqManager) {
            NSLog(@"🗄️ PHASE 2: Checking Stooq database for %lu symbols...", (unsigned long)missingSymbols.count);
            
            NSMutableArray *stillMissing = [NSMutableArray array];
            
            for (NSString *symbol in missingSymbols) {
                NSArray<HistoricalBarModel *> *stooqBars = [self.stooqManager loadBarsForSymbol:symbol
                                                                                         minBars:requirements.minimumBars];
                
                if (stooqBars && stooqBars.count >= requirements.minimumBars) {
                    resultData[symbol] = stooqBars;
                    self.symbolDataCache[symbol] = stooqBars;  // Cache it
                    NSLog(@"✅ Stooq HIT: %@ (%lu bars)", symbol, (unsigned long)stooqBars.count);
                } else {
                    [stillMissing addObject:symbol];
                    NSLog(@"⚠️ Stooq MISS: %@", symbol);
                }
            }
            
            missingSymbols = stillMissing;
        }
        
        if (missingSymbols.count == 0) {
            NSLog(@"✅ All data resolved (cache + Stooq)!");
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([resultData copy], nil);
            });
            return;
        }
        
        // PHASE 3: Fallback to DataHub
        NSLog(@"🌐 PHASE 3: Requesting %lu symbols from DataHub...", (unsigned long)missingSymbols.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fetchFromDataHub:missingSymbols
                      requirements:requirements
                        completion:^(NSDictionary *dataHubData, NSError *error) {
                if (error) {
                    completion(nil, error);
                    return;
                }
                
                // Merge DataHub results
                [resultData addEntriesFromDictionary:dataHubData];
                
                // Cache DataHub results
                for (NSString *symbol in dataHubData.allKeys) {
                    self.symbolDataCache[symbol] = dataHubData[symbol];
                }
                
                NSLog(@"✅ Data fetching complete: %lu/%lu symbols",
                      (unsigned long)resultData.count, (unsigned long)symbols.count);
                
                completion([resultData copy], nil);
            }];
        });
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
