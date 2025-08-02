//
//  DataHub+SeasonalData.h
//  TradingApp
//
//  Category for handling seasonal quarterly data requests
//

#import "DataHub.h"

@class SeasonalDataModel;

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (SeasonalData)

#pragma mark - Seasonal Data Requests

/**
 * Request seasonal quarterly data for a symbol and data type
 * Handles caching with 6-hour TTL for quarterly data
 *
 * @param symbol The stock symbol (e.g., "AAPL")
 * @param dataType The data type from Zacks (e.g., "revenue", "eps_diluted")
 * @param completion Completion block with SeasonalDataModel or error
 */
- (void)requestSeasonalDataForSymbol:(NSString *)symbol
                            dataType:(NSString *)dataType
                          completion:(void (^)(SeasonalDataModel * _Nullable data, NSError * _Nullable error))completion;

/**
 * Force refresh seasonal data (bypasses cache)
 */
- (void)refreshSeasonalDataForSymbol:(NSString *)symbol
                            dataType:(NSString *)dataType
                          completion:(void (^)(SeasonalDataModel * _Nullable data, NSError * _Nullable error))completion;

/**
 * Get cached seasonal data if available (returns immediately)
 */
- (nullable SeasonalDataModel *)getCachedSeasonalDataForSymbol:(NSString *)symbol
                                                      dataType:(NSString *)dataType;

/**
 * Clear seasonal data cache for a specific symbol/dataType
 */
- (void)clearSeasonalCacheForSymbol:(NSString *)symbol dataType:(NSString *)dataType;

/**
 * Clear all seasonal data cache
 */
- (void)clearAllSeasonalCache;

#pragma mark - Cache Statistics

/**
 * Get seasonal cache statistics for debugging
 */
- (NSDictionary *)seasonalCacheStatistics;

@end

NS_ASSUME_NONNULL_END
