//
//  ModelManager.h
//  TradingApp
//
//  Manages screener models (load, save, list)
//

#import <Foundation/Foundation.h>
#import "ScreenerModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ModelManager : NSObject

#pragma mark - Singleton

+ (instancetype)sharedManager;

#pragma mark - Model Directory

/// Get the directory where models are stored
+ (NSString *)modelsDirectory;

/// Ensure models directory exists
+ (BOOL)ensureModelsDirectoryExists;

#pragma mark - Model Management

/// Load all models from disk
- (NSArray<ScreenerModel *> *)loadAllModels;

/// Get model by ID
- (nullable ScreenerModel *)modelWithID:(NSString *)modelID;

/// Save model to disk
- (BOOL)saveModel:(ScreenerModel *)model error:(NSError **)error;

/// Delete model
- (BOOL)deleteModel:(NSString *)modelID error:(NSError **)error;

/// Refresh models from disk
- (void)refreshModels;

#pragma mark - Available Models

/// All loaded models
@property (nonatomic, readonly) NSArray<ScreenerModel *> *allModels;

/// Enabled models only
@property (nonatomic, readonly) NSArray<ScreenerModel *> *enabledModels;

#pragma mark - Validation

/// Check if model ID is unique
- (BOOL)isModelIDAvailable:(NSString *)modelID;

/// Validate model before saving
- (BOOL)validateModel:(ScreenerModel *)model error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
