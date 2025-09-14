//
// STEP 2: DataManager+SymbolSearch.m
// Implementation following architecture: DataManager → DownloadManager → API
//

#import "DataManager+SymbolSearch.h"
#import "DownloadManager.h"
#import "DataAdapterFactory.h"

@implementation DataManager (SymbolSearch)

- (void)searchSymbolsWithQuery:(NSString *)query
                dataSource:(DataSourceType)dataSource
                     limit:(NSInteger)limit
                completion:(void(^)(NSArray<SymbolSearchResult *> * _Nullable results, NSError * _Nullable error))completion {
    
    if (!query || query.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    
    NSLog(@"📊 DataManager: Processing symbol search for '%@'", query);
    
    // Delegate to DownloadManager (respects architecture)
    [self.downloadManager searchSymbolsWithQuery:query
                                       dataSource:dataSource
                                            limit:limit
                                       completion:^(NSArray<NSDictionary *> *rawResults, NSError *error) {
        
        if (error) {
            NSLog(@"❌ DataManager: DownloadManager search failed: %@", error.localizedDescription);
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
            return;
        }
        
        // ✅ STANDARDIZATION: Convert raw results to SymbolSearchResult via adapter
        NSMutableArray<SymbolSearchResult *> *standardizedResults = [NSMutableArray array];
        
        for (NSDictionary *rawResult in rawResults) {
            @try {
                // Use adapter pattern to standardize different API formats
                SymbolSearchResult *result = [self standardizeSymbolSearchResult:rawResult
                                                                   fromDataSource:dataSource];
                if (result) {
                    [standardizedResults addObject:result];
                }
            } @catch (NSException *exception) {
                NSLog(@"⚠️ DataManager: Failed to standardize result: %@", exception.reason);
                // Continue with other results
            }
        }
        
        NSLog(@"✅ DataManager: Standardized %ld/%ld symbol search results",
              (long)standardizedResults.count, (long)rawResults.count);
        
        // Return standardized results on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([standardizedResults copy], nil);
        });
    }];
}

- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     dataSource:(DataSourceType)dataSource
                     completion:(void(^)(CompanyInfoModel * _Nullable companyInfo, NSError * _Nullable error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager" code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    NSLog(@"🏢 DataManager: Getting company info for '%@'", symbol);
    
    // Delegate to DownloadManager
    [self.downloadManager getCompanyInfoForSymbol:symbol
                                        dataSource:dataSource
                                        completion:^(CompanyInfoModel *companyInfo, NSError *error) {
        
        // CompanyInfoModel is already standardized by DownloadManager
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(companyInfo, error);
        });
    }];
}

#pragma mark - Private Standardization Methods

- (SymbolSearchResult *)standardizeSymbolSearchResult:(NSDictionary *)rawResult
                                       fromDataSource:(DataSourceType)dataSource {
    
    // Extract common fields with fallbacks
    NSString *symbol = rawResult[@"symbol"] ?: rawResult[@"ticker"] ?: @"";
    NSString *companyName = rawResult[@"name"] ?: rawResult[@"companyName"] ?: rawResult[@"description"] ?: @"";
    NSString *exchange = rawResult[@"exchange"] ?: rawResult[@"market"] ?: @"";
    
    if (symbol.length == 0) {
        NSLog(@"⚠️ DataManager: Skipping result with missing symbol");
        return nil;
    }
    
    // Create standardized result
    SymbolSearchResult *result = [SymbolSearchResult resultWithSymbol:symbol.uppercaseString
                                                           companyName:companyName
                                                            sourceType:dataSource];
    
    // Add optional fields if available
    if (exchange.length > 0) {
        result.exchange = exchange;
    }
    
    // Set relevance based on match type
    NSString *upperSymbol = symbol.uppercaseString;
    if ([upperSymbol hasPrefix:symbol.uppercaseString]) {
        result.relevanceScore = 2.0; // Exact prefix match
    } else if ([companyName.lowercaseString containsString:symbol.lowercaseString]) {
        result.relevanceScore = 1.0; // Company name contains query
    } else {
        result.relevanceScore = 0.5; // Other match
    }
    
    return result;
}

@end
