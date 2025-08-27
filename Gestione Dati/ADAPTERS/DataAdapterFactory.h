//
//  DataAdapterFactory.h
//  TradingApp
//
//  Factory to get the right adapter for each data source
//  Updated to include YahooDataAdapter
//

#import <Foundation/Foundation.h>
#import "DataSourceAdapter.h"
#import "DownloadManager.h" // For DataSourceType enum

NS_ASSUME_NONNULL_BEGIN

@interface DataAdapterFactory : NSObject

/**
 * Returns the appropriate adapter for the specified data source type
 *
 * Supported adapters:
 * - DataSourceTypeSchwab → SchwabDataAdapter
 * - DataSourceTypeIBKR → IBKRAdapter
 * - DataSourceTypeWebull → WebullDataAdapter
 * - DataSourceTypeYahoo → YahooDataAdapter (NEW)
 * - DataSourceTypeOther → OtherDataAdapter
 * - Other types → OtherDataAdapter (fallback)
 */
+ (id<DataSourceAdapter>)adapterForDataSource:(DataSourceType)sourceType;

@end

NS_ASSUME_NONNULL_END
