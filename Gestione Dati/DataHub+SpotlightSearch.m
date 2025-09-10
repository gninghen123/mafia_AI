//
//  DataHub+SpotlightSearch.m
//  TradingApp
//
//  DataHub extension implementation for Spotlight Search
//

#import "DataHub+SpotlightSearch.h"
#import "DataHub+Private.h"
#import "DownloadManager.h"
#import "Symbol+CoreDataClass.h"
#import "CompanyInfo+CoreDataProperties.h"

@implementation DataHub (SpotlightSearch)

#pragma mark - Symbol Search for Spotlight

- (void)searchSymbolsWithQuery:(NSString *)query
                    dataSource:(DataSourceType)dataSource
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<SymbolSearchResult *> * _Nullable results, NSError * _Nullable error))completion {
    
    if (!query || query.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    
    NSLog(@"🔍 DataHub+SpotlightSearch: Searching '%@' via %@", query, @(dataSource));
    
    // First, check local symbols for quick results
    [self searchLocalSymbolsWithQuery:query limit:limit completion:^(NSArray<SymbolSearchResult *> *localResults) {
        
        // Then search via API for more comprehensive results
        [self searchAPISymbolsWithQuery:query
                              dataSource:dataSource
                                   limit:limit
                              completion:^(NSArray<SymbolSearchResult *> *apiResults, NSError *error) {
            
            // Merge and deduplicate results
            NSArray<SymbolSearchResult *> *mergedResults = [self mergeSearchResults:localResults
                                                                        withResults:apiResults
                                                                              limit:limit];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(mergedResults, error);
            });
        }];
    }];
}

- (void)searchSymbolsWithQuery:(NSString *)query
                         limit:(NSInteger)limit
                    completion:(void(^)(NSArray<SymbolSearchResult *> * _Nullable results, NSError * _Nullable error))completion {
    
    // Search using the highest priority data source available
    DataSourceType primarySource = [self getHighestPriorityDataSource];
    
    [self searchSymbolsWithQuery:query
                      dataSource:primarySource
                           limit:limit
                      completion:completion];
}

- (void)getSymbolSuggestionsForQuery:(NSString *)query
                               limit:(NSInteger)limit
                          completion:(void(^)(NSArray<SymbolSearchResult *> * _Nullable suggestions))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<SymbolSearchResult *> *suggestions = [NSMutableArray array];
        
        if (!query || query.length == 0) {
            // Return recently used symbols
            [self getRecentlyUsedSymbolsWithLimit:limit completion:^(NSArray<SymbolSearchResult *> *recent) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(recent);
                });
            }];
            return;
        }
        
        // Search in local symbols first
        [self searchLocalSymbolsWithQuery:query limit:limit completion:^(NSArray<SymbolSearchResult *> *localResults) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(localResults);
            });
        }];
    });
}

#pragma mark - Quick Symbol Actions

- (void)quickSymbolLookup:(NSString *)symbol
               dataSource:(DataSourceType)dataSource
               completion:(void(^)(SymbolSearchResult * _Nullable result, NSError * _Nullable error))completion {
    
    if (!symbol || symbol.length == 0) {
        if (completion) completion(nil, [NSError errorWithDomain:@"DataHub" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol"}]);
        return;
    }
    
    // First check if we have company info locally
    Symbol *localSymbol = [self getSymbolWithName:symbol.uppercaseString];
    if (localSymbol && localSymbol.companyInfo && localSymbol.companyInfo.name.length > 0) {
        SymbolSearchResult *result = [SymbolSearchResult resultWithSymbol:symbol
                                                              companyName:localSymbol.companyInfo.name
                                                               sourceType:DataSourceTypeLocal];
        if (completion) completion(result, nil);
        return;
    }
    
    // Otherwise, fetch from API
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    [downloadManager getCompanyInfoForSymbol:symbol
                                  dataSource:dataSource
                                  completion:^(CompanyInfoModel *companyInfo, NSError *error) {
        
        SymbolSearchResult *result = nil;
        if (companyInfo) {
            result = [SymbolSearchResult resultWithSymbol:symbol
                                              companyName:companyInfo.name
                                               sourceType:dataSource];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result, error);
        });
    }];
}

#pragma mark - Helper Methods

- (void)searchLocalSymbolsWithQuery:(NSString *)query
                              limit:(NSInteger)limit
                         completion:(void(^)(NSArray<SymbolSearchResult *> *results))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<SymbolSearchResult *> *results = [NSMutableArray array];
        
        NSString *upperQuery = query.uppercaseString;
        
        // Create fetch request for symbols
        NSFetchRequest *request = [Symbol fetchRequest];
        
        // Search by symbol name (prefix match is most important)
        NSPredicate *symbolPredicate = [NSPredicate predicateWithFormat:@"symbol BEGINSWITH %@", upperQuery];
        
        // Also search by company name if query is longer
        NSPredicate *companyPredicate = nil;
        if (query.length > 1) {
            companyPredicate = [NSPredicate predicateWithFormat:@"companyInfo.name CONTAINS[cd] %@", query];
        }
        
        // Combine predicates
        if (companyPredicate) {
            request.predicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[symbolPredicate, companyPredicate]];
        } else {
            request.predicate = symbolPredicate;
        }
        
        // Sort by interaction count and recency
        request.sortDescriptors = @[
            [NSSortDescriptor sortDescriptorWithKey:@"interactionCount" ascending:NO],
            [NSSortDescriptor sortDescriptorWithKey:@"lastInteraction" ascending:NO],
            [NSSortDescriptor sortDescriptorWithKey:@"symbol" ascending:YES]
        ];
        
        request.fetchLimit = limit;
        
        NSError *error = nil;
        NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (!error) {
            for (Symbol *symbol in symbols) {
                NSString *companyName = symbol.companyInfo ? symbol.companyInfo.name : nil;
                SymbolSearchResult *result = [SymbolSearchResult resultWithSymbol:symbol.symbol
                                                                      companyName:companyName
                                                                       sourceType:DataSourceTypeLocal];
                
                // Calculate relevance score based on match type and interaction
                if ([symbol.symbol hasPrefix:upperQuery]) {
                    result.relevanceScore = 2.0; // Exact prefix match
                } else {
                    result.relevanceScore = 1.0; // Company name match
                }
                
                // Boost score for frequently used symbols
                result.relevanceScore += (symbol.interactionCount * 0.1);
                
                [results addObject:result];
            }
        }
        
        // Sort by relevance score
        [results sortUsingComparator:^NSComparisonResult(SymbolSearchResult *obj1, SymbolSearchResult *obj2) {
            return [@(obj2.relevanceScore) compare:@(obj1.relevanceScore)];
        }];
        
        NSLog(@"📍 Found %lu local symbols for query '%@'", (unsigned long)results.count, query);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([results copy]);
        });
    });
}

- (void)searchAPISymbolsWithQuery:(NSString *)query
                       dataSource:(DataSourceType)dataSource
                            limit:(NSInteger)limit
                       completion:(void(^)(NSArray<SymbolSearchResult *> *results, NSError *error))completion {
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    [downloadManager searchSymbolsWithQuery:query
                                  dataSource:dataSource
                                       limit:limit
                                  completion:^(NSArray<NSDictionary *> *searchResults, NSError *error) {
        
        NSMutableArray<SymbolSearchResult *> *results = [NSMutableArray array];
        
        if (searchResults && !error) {
            for (NSDictionary *result in searchResults) {
                NSString *symbol = result[@"symbol"];
                NSString *companyName = result[@"name"] ?: result[@"companyName"];
                NSString *exchange = result[@"exchange"];
                
                if (symbol) {
                    SymbolSearchResult *searchResult = [SymbolSearchResult resultWithSymbol:symbol
                                                                               companyName:companyName
                                                                                sourceType:dataSource];
                    searchResult.exchange = exchange;
                    [results addObject:searchResult];
                }
            }
        }
        
        NSLog(@"🌐 Found %lu API symbols for query '%@' via %@", (unsigned long)results.count, query, @(dataSource));
        
        if (completion) completion([results copy], error);
    }];
}

- (NSArray<SymbolSearchResult *> *)mergeSearchResults:(NSArray<SymbolSearchResult *> *)localResults
                                          withResults:(NSArray<SymbolSearchResult *> *)apiResults
                                                limit:(NSInteger)limit {
    
    NSMutableArray<SymbolSearchResult *> *mergedResults = [NSMutableArray array];
    NSMutableSet<NSString *> *seenSymbols = [NSMutableSet set];
    
    // Add local results first (they have higher relevance due to usage history)
    for (SymbolSearchResult *result in localResults) {
        if (mergedResults.count >= limit) break;
        
        [mergedResults addObject:result];
        [seenSymbols addObject:result.symbol];
    }
    
    // Add API results that we haven't seen yet
    for (SymbolSearchResult *result in apiResults) {
        if (mergedResults.count >= limit) break;
        
        if (![seenSymbols containsObject:result.symbol]) {
            [mergedResults addObject:result];
            [seenSymbols addObject:result.symbol];
        }
    }
    
    return [mergedResults copy];
}

- (DataSourceType)getHighestPriorityDataSource {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // Try sources in priority order
    if ([downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        return DataSourceTypeSchwab;
    }
    if ([downloadManager isDataSourceConnected:DataSourceTypeYahoo]) {
        return DataSourceTypeYahoo;
    }
    if ([downloadManager isDataSourceConnected:DataSourceTypeIBKR]) {
        return DataSourceTypeIBKR;
    }
    if ([downloadManager isDataSourceConnected:DataSourceTypeWebull]) {
        return DataSourceTypeWebull;
    }
    
    // Fallback to Schwab even if not connected (will attempt connection)
    return DataSourceTypeSchwab;
}

- (void)getRecentlyUsedSymbolsWithLimit:(NSInteger)limit
                             completion:(void(^)(NSArray<SymbolSearchResult *> *results))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<SymbolSearchResult *> *results = [NSMutableArray array];
        
        NSFetchRequest *request = [Symbol fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"lastInteraction != nil"];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastInteraction" ascending:NO]];
        request.fetchLimit = limit;
        
        NSError *error = nil;
        NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (!error) {
            for (Symbol *symbol in symbols) {
                NSString *companyName = symbol.companyInfo ? symbol.companyInfo.name : nil;
                SymbolSearchResult *result = [SymbolSearchResult resultWithSymbol:symbol.symbol
                                                                      companyName:companyName
                                                                       sourceType:DataSourceTypeLocal];
                [results addObject:result];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([results copy]);
        });
    });
}

@end
