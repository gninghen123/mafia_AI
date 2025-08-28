//
//  DataHub+MarketData.h
//  mafia_AI
//
//  NEW API: Runtime models instead of Core Data objects
//  Thread-safe, performance-optimized, UI-friendly
//

#import "DataHub.h"
#import "RuntimeModels.h"  // Import our new runtime models
#import "CommonTypes.h"    // DataFreshnessType is now defined here

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (MarketData)

#pragma mark - Market Quotes with Smart Caching

// Get quote with automatic refresh if stale
// RETURNS: Runtime MarketQuoteModel object (thread-safe)
- (void)getQuoteForSymbol:(NSString *)symbol
               completion:(void(^)(MarketQuoteModel * _Nullable quote, BOOL isLive))completion;

// Get multiple quotes
// RETURNS: Dictionary of runtime MarketQuoteModel objects
- (void)getQuotesForSymbols:(NSArray<NSString *> *)symbols
                 completion:(void(^)(NSDictionary<NSString *, MarketQuoteModel *> *quotes, BOOL allLive))completion;

// Force refresh quote (bypasses cache)
- (void)refreshQuoteForSymbol:(NSString *)symbol
                   completion:(void(^)(MarketQuoteModel * _Nullable quote, NSError * _Nullable error))completion;

#pragma mark - Historical Data with Smart Caching

/**
 * Get historical bars for a symbol with extended hours option
 * @param symbol The symbol to get data for
 * @param timeframe The bar timeframe (1min, 5min, daily, etc.)
 * @param barCount Number of bars to request
 * @param needExtendedHours YES to include after-hours data, NO for regular hours only
 * @param completion Completion block with bars array and freshness
 */
- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                          barCount:(NSInteger)barCount
                  needExtendedHours:(BOOL)needExtendedHours
                        completion:(void (^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion;

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                  needExtendedHours:(BOOL)needExtendedHours
                        completion:(void(^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion;

#pragma mark - Company Information with Smart Caching

// Get company info with automatic refresh if stale
// RETURNS: Runtime CompanyInfoModel object (thread-safe)
- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     completion:(void(^)(CompanyInfoModel * _Nullable info, BOOL isFresh))completion;



#pragma mark - Batch Operations

// Refresh multiple quotes at once
- (void)refreshQuotesForSymbols:(NSArray<NSString *> *)symbols;

// Prefetch data for symbols (useful for watchlists)
- (void)prefetchDataForSymbols:(NSArray<NSString *> *)symbols;

#pragma mark - Cache Management

// Clear all market data cache (memory + Core Data)
- (void)clearMarketDataCache;

// Clear cache for specific symbol
- (void)clearCacheForSymbol:(NSString *)symbol;

// Get cache statistics for debugging
- (NSDictionary *)getCacheStatistics;

#pragma mark - Market Lists (NEW)
- (void)getMarketPerformersForList:(NSString *)listType
                         timeframe:(NSString *)timeframe
                        completion:(void (^)(NSArray<MarketPerformerModel *> *performers, BOOL isFresh))completion;

- (void)refreshMarketListForType:(NSString *)listType timeframe:(NSString *)timeframe;
- (void)clearMarketListCache;
- (NSDictionary *)getMarketListCacheStatistics;


#pragma mark - Subscription Management (UPDATED - Batch Support + Reference Counting)

// Single symbol subscription (legacy compatibility)
- (void)subscribeToQuoteUpdatesForSymbol:(NSString *)symbol;
- (void)unsubscribeFromQuoteUpdatesForSymbol:(NSString *)symbol;

// ✅ NEW: Widget-aware subscription (recommended)
- (void)subscribeToQuoteUpdatesForSymbol:(NSString *)symbol widgetId:(NSString *)widgetId;
- (void)unsubscribeFromQuoteUpdatesForSymbol:(NSString *)symbol widgetId:(NSString *)widgetId;

// ✅ NEW: Batch subscription methods (efficient for multiple symbols)
- (void)subscribeToQuoteUpdatesForSymbols:(NSArray<NSString *> *)symbols;
- (void)subscribeToQuoteUpdatesForSymbols:(NSArray<NSString *> *)symbols widgetId:(NSString *)widgetId;
- (void)unsubscribeFromQuoteUpdatesForSymbols:(NSArray<NSString *> *)symbols widgetId:(NSString *)widgetId;

// ✅ NEW: Widget lifecycle management
- (NSString *)generateWidgetId;
- (void)registerWidget:(NSString *)widgetId;
- (void)unregisterWidget:(NSString *)widgetId;

// Cleanup and statistics
- (void)unsubscribeFromAllQuoteUpdates;
- (NSDictionary *)getSubscriptionStatistics;

@end

NS_ASSUME_NONNULL_END
