//
// STEP 1: DataManager+SymbolSearch.h
// Nuovo extension per DataManager per gestire symbol search
//

#import "DataManager.h"
#import "SpotlightModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataManager (SymbolSearch)

/**
 * Search symbols via standardized architecture flow
 * @param query Search query text
 * @param dataSource Preferred data source (optional, will auto-select if nil)
 * @param limit Maximum number of results
 * @param completion Completion with standardized SymbolSearchResult objects
 */
- (void)searchSymbolsWithQuery:(NSString *)query
                dataSource:(DataSourceType)dataSource
                     limit:(NSInteger)limit
                completion:(void(^)(NSArray<SymbolSearchResult *> * _Nullable results, NSError * _Nullable error))completion;

/**
 * Get company information for a symbol
 * @param symbol Symbol to lookup
 * @param dataSource Preferred data source
 * @param completion Completion with CompanyInfoModel
 */
- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     dataSource:(DataSourceType)dataSource
                     completion:(void(^)(CompanyInfoModel * _Nullable companyInfo, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
