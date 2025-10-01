//
//  ScreenerBatchRunner.h
//  TradingApp
//
//  Executes multiple screener models in batch
//

#import <Foundation/Foundation.h>
#import "ScreenerModel.h"
#import "StooqDataManager.h"

NS_ASSUME_NONNULL_BEGIN

@class ScreenerBatchRunner;

// ============================================================================
// BATCH RUNNER DELEGATE
// ============================================================================

@protocol ScreenerBatchRunnerDelegate <NSObject>
@optional

/// Called when batch execution starts
- (void)batchRunnerDidStart:(ScreenerBatchRunner *)runner;

/// Called when data loading starts
- (void)batchRunner:(ScreenerBatchRunner *)runner didStartLoadingDataForSymbols:(NSInteger)symbolCount;

/// Called when data loading completes
- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishLoadingData:(NSDictionary *)cache;

/// Called when a model starts executing
- (void)batchRunner:(ScreenerBatchRunner *)runner didStartModel:(ScreenerModel *)model;

/// Called when a model completes
- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishModel:(ModelResult *)result;

/// Called when entire batch completes
- (void)batchRunner:(ScreenerBatchRunner *)runner didFinishWithResults:(NSDictionary<NSString *, ModelResult *> *)results;

/// Called on error
- (void)batchRunner:(ScreenerBatchRunner *)runner didFailWithError:(NSError *)error;

/// Called for progress updates (0.0 - 1.0)
- (void)batchRunner:(ScreenerBatchRunner *)runner didUpdateProgress:(double)progress;

@end

// ============================================================================
// BATCH RUNNER
// ============================================================================

@interface ScreenerBatchRunner : NSObject

#pragma mark - Properties

@property (nonatomic, weak, nullable) id<ScreenerBatchRunnerDelegate> delegate;
@property (nonatomic, strong) StooqDataManager *dataManager;
@property (nonatomic, readonly) BOOL isRunning;

#pragma mark - Initialization

- (instancetype)initWithDataManager:(StooqDataManager *)dataManager;

#pragma mark - Execution

/**
 * Execute multiple models
 * @param models Array of ScreenerModel to execute
 * @param universe Array of symbols to screen (if nil, uses all available symbols)
 * @param completion Called when all models complete
 */
- (void)executeModels:(NSArray<ScreenerModel *> *)models
             universe:(nullable NSArray<NSString *> *)universe
           completion:(void (^)(NSDictionary<NSString *, ModelResult *> *results, NSError *_Nullable error))completion;

/**
 * Execute single model
 * @param model ScreenerModel to execute
 * @param universe Array of symbols to screen
 * @param cachedData Pre-loaded data cache (if available)
 * @param completion Called when complete
 */
- (void)executeModel:(ScreenerModel *)model
            universe:(NSArray<NSString *> *)universe
          cachedData:(nullable NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cachedData
          completion:(void (^)(ModelResult *result, NSError *_Nullable error))completion;

/**
 * Cancel current execution
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
