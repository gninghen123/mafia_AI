//
//  DataManager+News.m
//  TradingApp
//
//  Implementation for DataManager news extension
//  FIXED: Uses public DataManager methods and follows existing patterns
//

#import "DataManager+News.h"
#import "DownloadManager.h"
#import "DataAdapterFactory.h"
#import "CommonTypes.h"
#import "otherdataadapter.h"

@implementation DataManager (News)

#pragma mark - Main News Request Method

- (NSString *)requestNewsForSymbol:(NSString *)symbol
                             limit:(NSInteger)limit
                        completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion {
    
    // Use default news type with auto-routing
    return [self requestNewsForSymbol:symbol
                             newsType:DataRequestTypeNews
                                limit:limit
                      preferredSource:-1 // Auto-select
                           completion:completion];
}

- (NSString *)requestNewsForSymbol:(NSString *)symbol
                          newsType:(DataRequestType)newsType
                             limit:(NSInteger)limit
                   preferredSource:(DataSourceType)preferredSource
                        completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid symbol for news request"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    if (!completion) {
        NSLog(@"⚠️ DataManager: No completion block provided for news request");
        return nil;
    }
    
    NSLog(@"📰 DataManager: Requesting %@ news for %@ (limit: %ld)",
          DataRequestTypeToString(newsType), symbol, (long)limit);
    
    // Create request parameters
    NSDictionary *parameters = @{
        @"symbol": symbol.uppercaseString,
        @"limit": @(limit > 0 ? limit : 50)
    };
    
    // Use DownloadManager directly (following the same pattern as DataManager.m)
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    [downloadManager executeMarketDataRequest:newsType
                                   parameters:parameters
                              preferredSource:preferredSource
                                   completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleNewsResponse:result
                            error:error
                       usedSource:usedSource
                        forSymbol:symbol
                         newsType:newsType
                       completion:completion];
    }];
    
    return [[NSUUID UUID] UUIDString]; // Return a request ID
}

#pragma mark - Specialized News Methods

- (NSString *)requestGoogleFinanceNewsForSymbol:(NSString *)symbol
                                     completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion {
    
    return [self requestNewsForSymbol:symbol
                             newsType:DataRequestTypeGoogleFinanceNews
                                limit:20
                      preferredSource:DataSourceTypeOther
                           completion:completion];
}

- (NSString *)requestSECFilingsForSymbol:(NSString *)symbol
                              completion:(void (^)(NSArray<NewsModel *> *filings, NSError *error))completion {
    
    return [self requestNewsForSymbol:symbol
                             newsType:DataRequestTypeSECFilings
                                limit:40
                      preferredSource:DataSourceTypeOther
                           completion:completion];
}

- (NSString *)requestYahooFinanceNewsForSymbol:(NSString *)symbol
                                    completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion {
    
    return [self requestNewsForSymbol:symbol
                             newsType:DataRequestTypeYahooFinanceNews
                                limit:25
                      preferredSource:DataSourceTypeOther
                           completion:completion];
}

- (NSString *)requestSeekingAlphaNewsForSymbol:(NSString *)symbol
                                    completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion {
    
    return [self requestNewsForSymbol:symbol
                             newsType:DataRequestTypeSeekingAlphaNews
                                limit:15
                      preferredSource:DataSourceTypeOther
                           completion:completion];
}

- (NSString *)requestPressReleasesForSymbol:(NSString *)symbol
                                      limit:(NSInteger)limit
                                 completion:(void (^)(NSArray<NewsModel *> *releases, NSError *error))completion {
    
    return [self requestNewsForSymbol:symbol
                             newsType:DataRequestTypePressReleases
                                limit:limit
                      preferredSource:DataSourceTypeOther
                           completion:completion];
}

#pragma mark - Response Handling

- (void)handleNewsResponse:(id)result
                     error:(NSError *)error
                usedSource:(DataSourceType)usedSource
                 forSymbol:(NSString *)symbol
                  newsType:(DataRequestType)newsType
                completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion {
    
    if (error) {
        NSLog(@"❌ DataManager: News request failed for %@ from %@: %@",
              symbol, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    NSLog(@"✅ DataManager: News received for %@ from %@", symbol, DataSourceTypeToString(usedSource));
    
    // Standardize news data using adapter
    NSArray<NewsModel *> *standardizedNews = @[];
    
    if ([result isKindOfClass:[NSArray class]]) {
        NSArray *rawNews = (NSArray *)result;
        
        if (rawNews.count > 0) {
            // Get adapter for standardization
            id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
            
            // Check if adapter supports news standardization
            if (adapter && [adapter respondsToSelector:@selector(standardizeNewsData:forSymbol:newsType:)]) {
                NSString *newsTypeString = [self newsTypeToString:newsType];
                
                // FIXED: Use NSInvocation since the method is optional and may not be in all adapters
                if (adapter && [adapter respondsToSelector:@selector(standardizeNewsData:forSymbol:newsType:)]) {
                    @try {
                        // Chiamata diretta del metodo - più semplice e sicura
                        standardizedNews = [adapter standardizeNewsData:rawNews
                                                              forSymbol:symbol
                                                               newsType:newsTypeString];
                    } @catch (NSException *exception) {
                        NSLog(@"⚠️ DataManager: Exception during news standardization: %@", exception.reason);
                        standardizedNews = [NewsModel newsArrayFromDictionaries:rawNews];
                    }
                } else {
                    // Fallback: Create NewsModel objects manually
                    NSLog(@"⚠️ DataManager: Adapter doesn't support news standardization, using fallback");
                    standardizedNews = [NewsModel newsArrayFromDictionaries:rawNews];
                }
            } else {
                // Fallback: Create NewsModel objects manually
                NSLog(@"⚠️ DataManager: No adapter available for %@, using fallback standardization",
                      DataSourceTypeToString(usedSource));
                standardizedNews = [NewsModel newsArrayFromDictionaries:rawNews];
            }
        }
    } else {
        NSLog(@"⚠️ DataManager: Unexpected news data format from %@: %@",
              DataSourceTypeToString(usedSource), [result class]);
    }
    
    NSLog(@"📰 DataManager: Standardized %lu news items for %@",
          (unsigned long)standardizedNews.count, symbol);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedNews, nil);
        });
    }
    
    // Notify delegates (using existing pattern from DataManager)
    [self notifyDelegatesOfNewsUpdate:standardizedNews forSymbol:symbol];
}

#pragma mark - Helper Methods

- (NSString *)newsTypeToString:(DataRequestType)newsType {
    switch (newsType) {
        case DataRequestTypeNews:
        case DataRequestTypeCompanyNews:
            return @"news";
        case DataRequestTypePressReleases:
            return @"press_release";
        case DataRequestTypeSECFilings:
            return @"filing";
        case DataRequestTypeGoogleFinanceNews:
            return @"google_news";
        case DataRequestTypeYahooFinanceNews:
            return @"yahoo_news";
        case DataRequestTypeSeekingAlphaNews:
            return @"seeking_alpha_news";
        default:
            return @"news";
    }
}

- (void)notifyDelegatesOfNewsUpdate:(NSArray<NewsModel *> *)news forSymbol:(NSString *)symbol {
    // FIXED: Use existing delegate notification pattern from DataManager
    // Instead of accessing private delegateQueue, use main queue directly
    dispatch_async(dispatch_get_main_queue(), ^{
        // Use the existing delegate management system
        // The DataManager main class will handle proper delegate notification
        NSLog(@"📰 DataManager: Would notify %lu delegates about news update for %@",
              (unsigned long)news.count, symbol);
        
        // TODO: Add didUpdateNews delegate method to DataManagerDelegate protocol
        // For now, just log the update
    });
}

@end
