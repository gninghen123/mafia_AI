//
//  DataHub+SpotlightSearch.h
//  TradingApp
//
//  Extension for DataHub to support Spotlight Search functionality
//  Provides symbol search with specific data source selection
//

#import "DataHub.h"
#import "SpotlightModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (SpotlightSearch)

#pragma mark - Symbol Search for Spotlight

/**
 * Search for symbols using specific data source
 * @param query Search query text
 * @param dataSource Specific data source to use
 * @param limit Maximum number of results
 * @param completion Completion handler with SymbolSearchResult array
 */
- (void)searchSymbolsWithQuery:(NSString *)query
                    dataSource:(DataSourceType)dataSource
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<SymbolSearchResult *> * _Nullable results, NSError * _Nullable error))completion;

/**
 * Search symbols across all available data sources
 * Results are merged and sorted by relevance
 * @param query Search query text
 * @param limit Maximum number of results per source
 * @param completion Completion handler with merged results
 */
- (void)searchSymbolsWithQuery:(NSString *)query
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<SymbolSearchResult *> * _Nullable results, NSError * _Nullable error))completion;

/**
 * Get symbol suggestions based on recently used symbols
 * @param query Partial symbol query
 * @param limit Maximum number of suggestions
 * @param completion Completion handler with suggestions
 */
- (void)getSymbolSuggestionsForQuery:(NSString *)query
                               limit:(NSInteger)limit
                          completion:(void(^)(NSArray<SymbolSearchResult *> * _Nullable suggestions))completion;

#pragma mark - Quick Symbol Actions

/**
 * Perform quick symbol lookup with company information
 * @param symbol Symbol to lookup
 * @param dataSource Preferred data source
 * @param completion Completion handler with detailed symbol result
 */
- (void)quickSymbolLookup:(NSString *)symbol
               dataSource:(DataSourceType)dataSource
               completion:(void(^)(SymbolSearchResult * _Nullable result, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
