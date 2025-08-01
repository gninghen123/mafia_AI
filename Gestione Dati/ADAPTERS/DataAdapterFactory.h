// =======================================
// DataAdapterFactory.h
// Factory to get the right adapter for each data source

#import "DataSourceAdapter.h"  // CAMBIATO: era DataStandardization.h
#import "DownloadManager.h" // For DataSourceType enum

@interface DataAdapterFactory : NSObject

+ (id<DataSourceAdapter>)adapterForDataSource:(DataSourceType)sourceType;

@end
