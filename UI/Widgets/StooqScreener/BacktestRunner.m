//
//  BacktestRunner.m
//  TradingApp
//

#import "BacktestRunner.h"
#import "BacktestCacheHelper.h"
#import "ScreenerRegistry.h"
#import "BaseScreener.h"
#import <Cocoa/Cocoa.h>

@interface BacktestRunner ()

@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) double currentProgress;
@property (nonatomic, strong) dispatch_queue_t backtestQueue;
@property (nonatomic, strong) NSDate *executionStartTime;

@end

@implementation BacktestRunner

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _backtestQueue = dispatch_queue_create("com.tradingapp.backtest", DISPATCH_QUEUE_SERIAL);
        _running = NO;
        _currentProgress = 0.0;
    }
    return self;
}

#pragma mark - Accessors

- (BOOL)isRunning {
    @synchronized (self) {
        return _running;
    }
}

- (double)progress {
    @synchronized (self) {
        return _currentProgress;
    }
}

#pragma mark - Execution

- (void)runBacktestForModels:(NSArray<ScreenerModel *> *)models
                   startDate:(NSDate *)startDate
                     endDate:(NSDate *)endDate
                 masterCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache
              benchmarkSymbol:(NSString *)benchmarkSymbol {
    
    // Validation
    if (self.isRunning) {
        NSLog(@"⚠️ BacktestRunner: Already running");
        return;
    }
    
    if (!models || models.count == 0) {
        [self notifyError:[NSError errorWithDomain:@"BacktestRunner"
                                              code:-1
                                          userInfo:@{NSLocalizedDescriptionKey: @"No models provided"}]];
        return;
    }
    
    if (!startDate || !endDate || [startDate compare:endDate] == NSOrderedDescending) {
        [self notifyError:[NSError errorWithDomain:@"BacktestRunner"
                                              code:-2
                                          userInfo:@{NSLocalizedDescriptionKey: @"Invalid date range"}]];
        return;
    }
    
    if (!masterCache || masterCache.count == 0) {
        [self notifyError:[NSError errorWithDomain:@"BacktestRunner"
                                              code:-3
                                          userInfo:@{NSLocalizedDescriptionKey: @"Empty or nil cache"}]];
        return;
    }
    
    // Mark as running
    @synchronized (self) {
        _running = YES;
        _currentProgress = 0.0;
    }
    
    self.executionStartTime = [NSDate date];
    
    // Notify start
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(backtestRunnerDidStart:)]) {
            [self.delegate backtestRunnerDidStart:self];
        }
    });
    
    // Execute on background queue
    dispatch_async(self.backtestQueue, ^{
        [self executeBacktestWithModels:models
                              startDate:startDate
                                endDate:endDate
                            masterCache:masterCache
                         benchmarkSymbol:benchmarkSymbol];
    });
}

- (void)executeBacktestWithModels:(NSArray<ScreenerModel *> *)models
                        startDate:(NSDate *)startDate
                          endDate:(NSDate *)endDate
                      masterCache:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)masterCache
                   benchmarkSymbol:(NSString *)benchmarkSymbol {
    
    NSLog(@"🚀 BacktestRunner: Starting backtest");
    NSLog(@"   Date range: %@ → %@", startDate, endDate);
    NSLog(@"   Models: %lu", (unsigned long)models.count);
    NSLog(@"   Cache symbols: %lu", (unsigned long)masterCache.count);
    NSLog(@"   Benchmark: %@", benchmarkSymbol);
    
    // STEP 1: Preparation
    [self notifyPreparation:@"Generating trading dates..."];
    
    NSArray<NSDate *> *tradingDates = [BacktestRunner generateTradingDatesFrom:startDate toDate:endDate];
    
    if (tradingDates.count == 0) {
        [self notifyError:[NSError errorWithDomain:@"BacktestRunner"
                                              code:-4
                                          userInfo:@{NSLocalizedDescriptionKey: @"No trading dates in range"}]];
        return;
    }
    
    NSLog(@"   Trading days: %lu", (unsigned long)tradingDates.count);
    
    // STEP 2: Extract benchmark bars
    [self notifyPreparation:@"Loading benchmark data..."];
    
    NSArray<HistoricalBarModel *> *benchmarkBars = masterCache[benchmarkSymbol];
    if (!benchmarkBars || benchmarkBars.count == 0) {
        NSLog(@"⚠️ Benchmark symbol '%@' not found in cache, continuing without benchmark", benchmarkSymbol);
    }
    
    // STEP 3: Assign colors to models
    NSDictionary<NSString *, NSColor *> *modelColors = [BacktestRunner assignRandomColorsToModels:models];
    
    // STEP 4: Notify execution start
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(backtestRunner:didStartExecutionForDays:models:)]) {
            [self.delegate backtestRunner:self
                didStartExecutionForDays:tradingDates.count
                                  models:models.count];
        }
    });
    
    // STEP 5: Execute backtest
    NSMutableArray<DailyBacktestResult *> *allResults = [NSMutableArray array];
    NSInteger totalIterations = tradingDates.count * models.count;
    NSInteger currentIteration = 0;
    
    for (NSInteger dayIndex = 0; dayIndex < tradingDates.count; dayIndex++) {
        NSDate *currentDate = tradingDates[dayIndex];
        
        // Check for cancellation
        if (!self.isRunning) {
            NSLog(@"⚠️ BacktestRunner: Cancelled at day %ld/%lu",
                  (long)(dayIndex + 1), (unsigned long)tradingDates.count);
            [self notifyCancel];
            return;
        }
        
        // Notify date start
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(backtestRunner:didStartDate:dayNumber:totalDays:)]) {
                [self.delegate backtestRunner:self
                                 didStartDate:currentDate
                                    dayNumber:dayIndex + 1
                                    totalDays:tradingDates.count];
            }
        });
        
        // Slice cache to this date
        NSDictionary *dateCache = [BacktestCacheHelper sliceCache:masterCache upToDate:currentDate];
        
        if (dateCache.count == 0) {
            NSLog(@"⚠️ No data available for date %@, skipping", currentDate);
            continue;
        }
        
        NSLog(@"📅 Processing %@ (%ld/%lu) - %lu symbols available",
              currentDate, (long)(dayIndex + 1), (unsigned long)tradingDates.count,
              (unsigned long)dateCache.count);
        
        // Execute each model with this cache
        for (ScreenerModel *model in models) {
            
            // Check cancellation again
            if (!self.isRunning) {
                [self notifyCancel];
                return;
            }
            
            NSDate *modelStartTime = [NSDate date];
            
            // Execute model (reuse existing execution logic)
            NSArray<NSString *> *screenedSymbols = [self executeModel:model
                                                          withUniverse:dateCache.allKeys
                                                                 cache:dateCache];
            
            NSTimeInterval modelTime = [[NSDate date] timeIntervalSinceDate:modelStartTime];
            
            // Create result
            NSArray<ScreenedSymbol *> *screenedSymbolObjects = [self createScreenedSymbolsArray:screenedSymbols];
            
            DailyBacktestResult *result = [DailyBacktestResult resultWithDate:currentDate
                                                                     modelName:model.displayName
                                                                       modelID:model.modelID
                                                               screenedSymbols:screenedSymbolObjects];
            result.executionTime = modelTime;
            
            [allResults addObject:result];
            
            // Notify model completion
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(backtestRunner:didCompleteModel:onDate:symbolCount:)]) {
                    [self.delegate backtestRunner:self
                                 didCompleteModel:model.displayName
                                           onDate:currentDate
                                      symbolCount:screenedSymbols.count];
                }
            });
            
            // Update progress
            currentIteration++;
            [self updateProgress:(double)currentIteration / (double)totalIterations];
        }
    }
    
    // STEP 6: Create session
    NSTimeInterval totalTime = [[NSDate date] timeIntervalSinceDate:self.executionStartTime];
    
    BacktestSession *session = [[BacktestSession alloc] init];
    session.startDate = startDate;
    session.endDate = endDate;
    session.benchmarkSymbol = benchmarkSymbol;
    session.benchmarkBars = benchmarkBars;
    session.models = models;
    session.dailyResults = [allResults copy];
    session.totalExecutionTime = totalTime;
    session.modelColors = modelColors;
    
    NSLog(@"✅ BacktestRunner: Completed successfully");
    NSLog(@"   Total results: %lu", (unsigned long)allResults.count);
    NSLog(@"   Execution time: %.2fs", totalTime);
    
    // Mark as done
    @synchronized (self) {
        _running = NO;
    }
    
    // Notify completion
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(backtestRunner:didFinishWithSession:)]) {
            [self.delegate backtestRunner:self didFinishWithSession:session];
        }
    });
}

#pragma mark - Model Execution (Reuses existing screener logic)

- (NSArray<NSString *> *)executeModel:(ScreenerModel *)model
                         withUniverse:(NSArray<NSString *> *)universe
                                cache:(NSDictionary *)cache {
    
    NSArray<NSString *> *currentSymbols = universe;
    
    for (ScreenerStep *step in model.steps) {
        BaseScreener *screener = [[ScreenerRegistry sharedRegistry] screenerWithID:step.screenerID];
        
        if (!screener) {
            NSLog(@"⚠️ Screener not found: %@", step.screenerID);
            continue;
        }
        
        // Set parameters
        screener.parameters = step.parameters;
        
        // Determine input
        NSArray<NSString *> *inputSymbols = [step.inputSource isEqualToString:@"universe"]
            ? universe
            : currentSymbols;
        
        // Execute screener with cache (EXISTING METHOD - NO CHANGES NEEDED!)
        currentSymbols = [screener executeOnSymbols:inputSymbols cachedData:cache];
    }
    
    return currentSymbols;
}

- (NSArray<ScreenedSymbol *> *)createScreenedSymbolsArray:(NSArray<NSString *> *)symbols {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:symbols.count];
    
    for (NSString *symbol in symbols) {
        ScreenedSymbol *ss = [[ScreenedSymbol alloc] init];
        ss.symbol = symbol;
        ss.isSelected = NO;
        [result addObject:ss];
    }
    
    return [result copy];
}

#pragma mark - Cancellation

- (void)cancel {
    @synchronized (self) {
        if (_running) {
            NSLog(@"🛑 BacktestRunner: Cancelling...");
            _running = NO;
        }
    }
}

#pragma mark - Progress Updates

- (void)updateProgress:(double)progress {
    @synchronized (self) {
        _currentProgress = progress;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(backtestRunner:didUpdateProgress:)]) {
            [self.delegate backtestRunner:self didUpdateProgress:progress];
        }
    });
}

#pragma mark - Delegate Notifications

- (void)notifyPreparation:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(backtestRunner:didStartPreparationWithMessage:)]) {
            [self.delegate backtestRunner:self didStartPreparationWithMessage:message];
        }
    });
}

- (void)notifyError:(NSError *)error {
    @synchronized (self) {
        _running = NO;
    }
    
    NSLog(@"❌ BacktestRunner error: %@", error.localizedDescription);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(backtestRunner:didFailWithError:)]) {
            [self.delegate backtestRunner:self didFailWithError:error];
        }
    });
}

- (void)notifyCancel {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(backtestRunnerDidCancel:)]) {
            [self.delegate backtestRunnerDidCancel:self];
        }
    });
}

#pragma mark - Utility Class Methods

+ (NSInteger)calculateMaxBarsForModels:(NSArray<ScreenerModel *> *)models {
    NSInteger maxBars = 0;
    
    for (ScreenerModel *model in models) {
        for (ScreenerStep *step in model.steps) {
            BaseScreener *screener = [[ScreenerRegistry sharedRegistry] screenerWithID:step.screenerID];
            if (screener && screener.minBarsRequired > maxBars) {
                maxBars = screener.minBarsRequired;
            }
        }
    }
    
    return maxBars > 0 ? maxBars : 50; // Default 50 if nothing found
}

+ (NSArray<NSDate *> *)generateTradingDatesFrom:(NSDate *)startDate
                                         toDate:(NSDate *)endDate {
    
    NSMutableArray<NSDate *> *dates = [NSMutableArray array];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *currentDate = startDate;
    
    while ([currentDate compare:endDate] != NSOrderedDescending) {
        // Check if weekend
        NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:currentDate];
        
        // 1 = Sunday, 7 = Saturday
        if (weekday != 1 && weekday != 7) {
            [dates addObject:currentDate];
        }
        
        // Move to next day
        currentDate = [calendar dateByAddingUnit:NSCalendarUnitDay
                                           value:1
                                          toDate:currentDate
                                         options:0];
    }
    
    return [dates copy];
}

+ (NSDictionary<NSString *, NSColor *> *)assignRandomColorsToModels:(NSArray<ScreenerModel *> *)models {
    
    // Predefined color palette (distinct colors for charts)
    NSArray<NSColor *> *colorPalette = @[
        [NSColor systemRedColor],
        [NSColor systemBlueColor],
        [NSColor systemGreenColor],
        [NSColor systemOrangeColor],
        [NSColor systemPurpleColor],
        [NSColor systemPinkColor],
        [NSColor systemTealColor],
        [NSColor systemBrownColor],
        [NSColor systemIndigoColor],
        [NSColor systemCyanColor]
    ];
    
    NSMutableDictionary<NSString *, NSColor *> *colorMap = [NSMutableDictionary dictionary];
    
    for (NSInteger i = 0; i < models.count; i++) {
        ScreenerModel *model = models[i];
        NSColor *color = colorPalette[i % colorPalette.count];
        colorMap[model.modelID] = color;
    }
    
    return [colorMap copy];
}

@end
