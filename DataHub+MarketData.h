//
//  DataHub+MarketData.h
//  mafia_AI
//
//  NEW API: Runtime models instead of Core Data objects
//  Thread-safe, performance-optimized, UI-friendly
//

#import "DataHub.h"
#import "RuntimeModels.h"  // Import our new runtime models
#import "CommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

// Data freshness types
typedef NS_ENUM(NSInteger, DataFreshnessType) {
    DataFreshnessTypeQuote,           // TTL: 5-10 seconds
    DataFreshnessTypeMarketOverview,  // TTL: 1 minute
    DataFreshnessTypeHistorical,      // TTL: 5 minutes
    DataFreshnessTypeCompanyInfo,     // TTL: 24 hours
    DataFreshnessTypeWatchlist        // TTL: Infinite (user managed)
};

@interface DataHub (MarketData)

#pragma mark - Market Quotes with Smart Caching

// Get quote with automatic refresh if stale
// RETURNS: Runtime MarketQuote object (thread-safe)
- (void)getQuoteForSymbol:(NSString *)symbol
               completion:(void(^)(MarketQuote * _Nullable quote, BOOL isLive))completion;

// Get multiple quotes
// RETURNS: Dictionary of runtime MarketQuote objects
- (void)getQuotesForSymbols:(NSArray<NSString *> *)symbols
                 completion:(void(^)(NSDictionary<NSString *, MarketQuote *> *quotes, BOOL allLive))completion;

// Force refresh quote (bypasses cache)
- (void)refreshQuoteForSymbol:(NSString *)symbol
                   completion:(void(^)(MarketQuote * _Nullable quote, NSError * _Nullable error))completion;

#pragma mark - Historical Data with Smart Caching

// Get historical data with automatic refresh if stale
// RETURNS: Array of runtime HistoricalBar objects (thread-safe)
- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                          barCount:(NSInteger)barCount
                        completion:(void(^)(NSArray<HistoricalBar *> *bars, BOOL isFresh))completion;

// Get historical data for date range
- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                        completion:(void(^)(NSArray<HistoricalBar *> *bars, BOOL isFresh))completion;

#pragma mark - Company Info

// Get company info with automatic refresh if stale
// RETURNS: Runtime CompanyInfo object
- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     completion:(void(^)(CompanyInfo * _Nullable info, BOOL isFresh))completion;

#pragma mark - Batch Operations

// Refresh multiple quotes at once
- (void)refreshQuotesForSymbols:(NSArray<NSString *> *)symbols;

// Prefetch data for better performance
- (void)prefetchDataForSymbols:(NSArray<NSString *> *)symbols;

#pragma mark - Cache Management

// Clear all market data cache
- (void)clearMarketDataCache;

// Clear cache for specific symbol
- (void)clearCacheForSymbol:(NSString *)symbol;

// Get cache statistics
- (NSDictionary *)getCacheStatistics;

#pragma mark - Subscription Management (for real-time updates)

// Subscribe to quote updates
- (void)subscribeToQuoteUpdatesForSymbol:(NSString *)symbol;
- (void)subscribeToQuoteUpdatesForSymbols:(NSArray<NSString *> *)symbols;

// Unsubscribe from updates
- (void)unsubscribeFromQuoteUpdatesForSymbol:(NSString *)symbol;
- (void)unsubscribeFromAllQuoteUpdates;

@end

NS_ASSUME_NONNULL_END
