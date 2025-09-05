//
//  DataHub+News.h
//  TradingApp
//
//  Extension for DataHub to handle news data with caching
//  Uses memory cache only (no CoreData persistence for news)
//

#import "DataHub.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

// News cache TTL (Time To Live) in seconds
typedef NS_ENUM(NSInteger, NewsCacheTTL) {
    NewsCacheTTLShort = 300,     // 5 minutes for breaking news
    NewsCacheTTLMedium = 900,    // 15 minutes for regular news
    NewsCacheTTLLong = 3600      // 1 hour for press releases/filings
};

@interface DataHub (News)

#pragma mark - News Data Management

/**
 * Get news for symbol with automatic caching
 * @param symbol Stock symbol
 * @param limit Maximum number of news items
 * @param forceRefresh If YES, bypasses cache and fetches fresh data
 * @param completion Completion handler with NewsModel array and freshness indicator
 */
- (void)getNewsForSymbol:(NSString *)symbol
                   limit:(NSInteger)limit
            forceRefresh:(BOOL)forceRefresh
              completion:(void(^)(NSArray<NewsModel *> *news, BOOL isFresh, NSError * _Nullable error))completion;

/**
 * Get specific type of news for symbol
 * @param symbol Stock symbol
 * @param newsType Type of news (from DataRequestType enum)
 * @param completion Completion handler with NewsModel array
 */
- (void)getNewsForSymbol:(NSString *)symbol
                newsType:(DataRequestType)newsType
              completion:(void(^)(NSArray<NewsModel *> *news, BOOL isFresh, NSError * _Nullable error))completion;

/**
 * Get aggregated news from multiple sources
 * @param symbol Stock symbol
 * @param sources Array of DataRequestType values for news sources
 * @param completion Completion handler with combined and sorted NewsModel array
 */
- (void)getAggregatedNewsForSymbol:(NSString *)symbol
                       fromSources:(NSArray<NSNumber *> *)sources
                        completion:(void(^)(NSArray<NewsModel *> *news, NSError * _Nullable error))completion;

#pragma mark - Cache Management

/**
 * Clear news cache for specific symbol
 * @param symbol Stock symbol (nil to clear all)
 */
- (void)clearNewsCacheForSymbol:(nullable NSString *)symbol;

/**
 * Get cache statistics for debugging
 * @return Dictionary with cache info
 */
- (NSDictionary *)getNewsCacheStatistics;

/**
 * Preload news for symbols (background loading)
 * @param symbols Array of symbol strings
 */
- (void)preloadNewsForSymbols:(NSArray<NSString *> *)symbols;

@end

NS_ASSUME_NONNULL_END
