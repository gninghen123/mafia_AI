//
//  DataHub+MarketData.h
//  mafia_AI
//
//  Estensione del DataHub per gestire i dati di mercato
//  Updated with intelligent caching and automatic data fetching
//

#import "DataHub.h"
#import "MarketQuote+CoreDataClass.h"
#import "HistoricalBar+CoreDataClass.h"
#import "MarketPerformer+CoreDataClass.h"
#import "CompanyInfo+CoreDataClass.h"
#import "CommonTypes.h"  // Per BarTimeframe

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
- (void)getQuoteForSymbol:(NSString *)symbol
               completion:(void(^)(MarketQuote * _Nullable quote, BOOL isLive))completion;

// Get multiple quotes
- (void)getQuotesForSymbols:(NSArray<NSString *> *)symbols
                 completion:(void(^)(NSDictionary<NSString *, MarketQuote *> *quotes, BOOL isLive))completion;

// Force refresh quote (bypasses cache)
- (void)refreshQuoteForSymbol:(NSString *)symbol
                   completion:(void(^)(MarketQuote * _Nullable quote, NSError * _Nullable error))completion;

#pragma mark - Historical Data with Smart Caching

// Get historical data with automatic refresh if stale
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
- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     completion:(void(^)(CompanyInfo * _Nullable info, BOOL isFresh))completion;

#pragma mark - Market Lists

// Get market performers (gainers/losers) with automatic refresh
- (void)getMarketPerformersForList:(NSString *)listType
                        timeframe:(NSString *)timeframe
                       completion:(void(^)(NSArray<MarketPerformer *> *performers, BOOL isFresh))completion;

#pragma mark - Data Freshness Management

// Check if data is stale based on type and last update
- (BOOL)isDataStale:(NSDate *)lastUpdate forType:(DataFreshnessType)type;

// Get TTL for data type
- (NSTimeInterval)TTLForDataType:(DataFreshnessType)type;

// Check if there's a pending request
- (BOOL)hasPendingRequestForSymbol:(NSString *)symbol dataType:(DataFreshnessType)type;

#pragma mark - Batch Operations

// Request quotes for multiple symbols
- (void)refreshQuotesForSymbols:(NSArray<NSString *> *)symbols;

// Prefetch data for symbols (useful for watchlists)
- (void)prefetchDataForSymbols:(NSArray<NSString *> *)symbols;

#pragma mark - Cache Management

// Clear all market data cache
- (void)clearMarketDataCache;

// Clear cache for specific symbol
- (void)clearCacheForSymbol:(NSString *)symbol;

// Get cache statistics
- (NSDictionary *)getCacheStatistics;


@end

NS_ASSUME_NONNULL_END
