//
//  ScreenerBatchRunner.m
//  TradingApp
//

#import "ScreenerBatchRunner.h"
#import "ScreenerRegistry.h"
#import "BaseScreener.h"

@interface ScreenerBatchRunner ()
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) BOOL isCancelled;
@end

@implementation ScreenerBatchRunner

#pragma mark - Initialization

- (instancetype)initWithDataManager:(StooqDataManager *)dataManager {
    self = [super init];
    if (self) {
        _dataManager = dataManager;
        _isRunning = NO;
        _isCancelled = NO;
    }
    return self;
}

#pragma mark - Execution

- (void)executeModels:(NSArray<ScreenerModel *> *)models
             universe:(NSArray<NSString *> *)universe
           completion:(void (^)(NSDictionary<NSString *, ModelResult *> *, NSError *))completion {
    
    if (self.isRunning) {
        NSError *error = [NSError errorWithDomain:@"ScreenerBatchRunner"
                                             code:2001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Batch runner is already running"}];
        completion(nil, error);
        return;
    }
    
    // Validate models before execution
    for (ScreenerModel *model in models) {
        if (!model.steps || model.steps.count == 0) {
            NSError *error = [NSError errorWithDomain:@"ScreenerBatchRunner"
                                                 code:2002
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                 [NSString stringWithFormat:@"Model '%@' has no steps. Please add at least one screener.", model.displayName]}];
            completion(nil, error);
            return;
        }
    }
    
    self.isRunning = YES;
    self.isCancelled = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(batchRunnerDidStart:)]) {
            [self.delegate batchRunnerDidStart:self];
        }
    });
    
    NSLog(@"🚀 Starting batch execution of %lu models", (unsigned long)models.count);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Step 1: Determine universe
        __block NSArray<NSString *> *finalUniverse = universe;
        if (!finalUniverse) {
            finalUniverse = [self.dataManager availableSymbols];
            if (finalUniverse.count == 0) {
                NSLog(@"⚠️ No symbols available, scanning database...");
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                [self.dataManager scanDatabaseWithCompletion:^(NSArray<NSString *> *symbols, NSError *error) {
                    finalUniverse = symbols;
                    dispatch_semaphore_signal(semaphore);
                }];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            }
        }
        
        if (self.isCancelled || finalUniverse.count == 0) {
            [self finishWithResults:@{} error:nil completion:completion];
            return;
        }
        
        NSLog(@"📊 Universe size: %lu symbols", (unsigned long)finalUniverse.count);
        
        // Step 2: Calculate minimum bars required across ALL models
        NSInteger maxBarsRequired = [self calculateMaxBarsRequired:models];
        NSLog(@"📏 Maximum bars required: %ld", (long)maxBarsRequired);
        
        // Step 3: Load data for entire universe
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(batchRunner:didStartLoadingDataForSymbols:)]) {
                [self.delegate batchRunner:self didStartLoadingDataForSymbols:finalUniverse.count];
            }
        });
        
        __block NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *cachedData = nil;
        dispatch_semaphore_t dataSemaphore = dispatch_semaphore_create(0);
        
        [self.dataManager loadDataForSymbols:finalUniverse
                                     minBars:maxBarsRequired
                                  completion:^(NSDictionary<NSString *,NSArray<HistoricalBarModel *> *> *cache, NSError *error) {
            cachedData = cache;
            dispatch_semaphore_signal(dataSemaphore);
        }];
        
        dispatch_semaphore_wait(dataSemaphore, DISPATCH_TIME_FOREVER);
        
        if (self.isCancelled || !cachedData) {
            [self finishWithResults:@{} error:nil completion:completion];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(batchRunner:didFinishLoadingData:)]) {
                [self.delegate batchRunner:self didFinishLoadingData:cachedData];
            }
        });
        
        NSLog(@"✅ Data loaded: %lu symbols with sufficient data", (unsigned long)cachedData.count);
        
        // Step 4: Execute each model sequentially
        NSMutableDictionary<NSString *, ModelResult *> *results = [NSMutableDictionary dictionary];
        NSInteger completedModels = 0;
        
        for (ScreenerModel *model in models) {
            if (self.isCancelled) break;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(batchRunner:didStartModel:)]) {
                    [self.delegate batchRunner:self didStartModel:model];
                }
            });
            
            ModelResult *result = [self executeModelSync:model
                                                 universe:[cachedData allKeys]
                                               cachedData:cachedData];
            
            if (result) {
                results[model.modelID] = result;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.delegate respondsToSelector:@selector(batchRunner:didFinishModel:)]) {
                        [self.delegate batchRunner:self didFinishModel:result];
                    }
                });
            }
            
            completedModels++;
            double progress = (double)completedModels / (double)models.count;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(batchRunner:didUpdateProgress:)]) {
                    [self.delegate batchRunner:self didUpdateProgress:progress];
                }
            });
        }
        
        // Step 5: Finish
        [self finishWithResults:results error:nil completion:completion];
    });
}

- (void)executeModel:(ScreenerModel *)model
            universe:(NSArray<NSString *> *)universe
          cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cachedData
          completion:(void (^)(ModelResult *, NSError *))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ModelResult *result = [self executeModelSync:model universe:universe cachedData:cachedData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result, nil);
        });
    });
}

- (void)cancel {
    NSLog(@"🛑 Batch runner cancelled");
    self.isCancelled = YES;
}

#pragma mark - Private Helpers

- (NSInteger)calculateMaxBarsRequired:(NSArray<ScreenerModel *> *)models {
    NSInteger maxBars = 0;
    ScreenerRegistry *registry = [ScreenerRegistry sharedRegistry];
    
    for (ScreenerModel *model in models) {
        for (ScreenerStep *step in model.steps) {
            BaseScreener *screener = [registry screenerWithID:step.screenerID];
            if (screener) {
                // Set parameters before asking for minBarsRequired
                screener.parameters = step.parameters;
                NSInteger required = screener.minBarsRequired;
                if (required > maxBars) {
                    maxBars = required;
                }
            }
        }
    }
    
    return maxBars > 0 ? maxBars : 100;  // Default to 100 if nothing found
}

- (ModelResult *)executeModelSync:(ScreenerModel *)model
                         universe:(NSArray<NSString *> *)universe
                       cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cachedData {
    
    NSDate *startTime = [NSDate date];
    NSLog(@"▶️  Executing model: %@ (%@)", model.displayName, model.modelID);
    
    ModelResult *result = [[ModelResult alloc] init];
    result.modelID = model.modelID;
    result.modelName = model.displayName;
    result.executionTime = [NSDate date];
    result.initialUniverseSize = universe.count;
    
    NSMutableArray<StepResult *> *stepResults = [NSMutableArray array];
    ScreenerRegistry *registry = [ScreenerRegistry sharedRegistry];
    
    NSArray<NSString *> *currentInput = universe;
    
    // Execute each step sequentially
    for (NSInteger stepIdx = 0; stepIdx < model.steps.count; stepIdx++) {
        ScreenerStep *step = model.steps[stepIdx];
        
        NSDate *stepStartTime = [NSDate date];
        
        // Determine input for this step
        if ([step.inputSource isEqualToString:@"previous"] && stepIdx > 0) {
            // Use output from previous step
            currentInput = stepResults[stepIdx - 1].symbols;
        } else {
            // Use full universe
            currentInput = universe;
        }
        
        if (currentInput.count == 0) {
            NSLog(@"⚠️ Step %ld (%@): No input symbols, skipping", (long)stepIdx, step.screenerID);
            break;
        }
        
        // Get screener
        BaseScreener *screener = [registry screenerWithID:step.screenerID];
        if (!screener) {
            NSLog(@"❌ Screener not found: %@", step.screenerID);
            continue;
        }
        
        // Set parameters
        screener.parameters = step.parameters;
        
        // Execute screener
        NSArray<NSString *> *output = [screener executeOnSymbols:currentInput cachedData:cachedData];
        
        NSTimeInterval stepDuration = [[NSDate date] timeIntervalSinceDate:stepStartTime];
        
        // Create step result
        StepResult *stepResult = [[StepResult alloc] init];
        stepResult.screenerID = screener.screenerID;
        stepResult.screenerName = screener.displayName;
        stepResult.symbols = output;
        stepResult.inputCount = currentInput.count;
        stepResult.executionTime = stepDuration;
        
        [stepResults addObject:stepResult];
        
        NSLog(@"  ✓ Step %ld (%@): %ld → %lu symbols (%.2fs)",
              (long)stepIdx + 1,
              screener.displayName,
              (long)currentInput.count,
              (unsigned long)output.count,
              stepDuration);
    }
    
    // Set final results
    result.stepResults = [stepResults copy];
    result.finalSymbols = stepResults.count > 0 ? stepResults.lastObject.symbols : @[];
    result.totalExecutionTime = [[NSDate date] timeIntervalSinceDate:startTime];
    
    NSLog(@"✅ Model complete: %@ → %lu final symbols (%.2fs)",
          model.displayName,
          (unsigned long)result.finalSymbols.count,
          result.totalExecutionTime);
    
    return result;
}

- (void)finishWithResults:(NSDictionary<NSString *, ModelResult *> *)results
                    error:(NSError *)error
               completion:(void (^)(NSDictionary<NSString *, ModelResult *> *, NSError *))completion {
    
    self.isRunning = NO;
    self.isCancelled = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error && [self.delegate respondsToSelector:@selector(batchRunner:didFailWithError:)]) {
            [self.delegate batchRunner:self didFailWithError:error];
        }
        
        if ([self.delegate respondsToSelector:@selector(batchRunner:didFinishWithResults:)]) {
            [self.delegate batchRunner:self didFinishWithResults:results];
        }
        
        completion(results, error);
    });
}

@end
