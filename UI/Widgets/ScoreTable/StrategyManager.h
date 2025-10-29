//
//  StrategyManager.h
//  TradingApp
//
//  Manages saving, loading, and organizing scoring strategies
//

#import <Foundation/Foundation.h>
#import "ScoreTableWidget_Models.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Manages scoring strategy persistence and retrieval
 */
@interface StrategyManager : NSObject

+ (instancetype)sharedManager;

#pragma mark - Strategy CRUD

/**
 * Get all saved strategies
 */
- (NSArray<ScoringStrategy *> *)allStrategies;

/**
 * Get strategy by ID
 */
- (nullable ScoringStrategy *)strategyWithId:(NSString *)strategyId;

/**
 * Get strategy by name
 */
- (nullable ScoringStrategy *)strategyWithName:(NSString *)name;

/**
 * Save or update a strategy
 */
- (BOOL)saveStrategy:(ScoringStrategy *)strategy error:(NSError **)error;

/**
 * Delete a strategy
 */
- (BOOL)deleteStrategy:(NSString *)strategyId error:(NSError **)error;

#pragma mark - Built-in Strategies

/**
 * Get default built-in strategy
 */
- (ScoringStrategy *)defaultStrategy;

/**
 * Get all built-in strategies (not user-created)
 */
- (NSArray<ScoringStrategy *> *)builtInStrategies;

/**
 * Create default strategy if none exist
 */
- (void)ensureDefaultStrategy;

#pragma mark - Persistence

/**
 * Reload strategies from disk
 */
- (void)reloadStrategies;

/**
 * Get strategies directory path
 */
- (NSString *)strategiesDirectory;

@end

NS_ASSUME_NONNULL_END
