// DataAdapterFactory.m
// Updated implementation with OtherDataAdapter

#import "DataAdapterFactory.h"
#import "SchwabDataAdapter.h"
#import "WebullDataAdapter.h"
#import "OtherDataAdapter.h"
#import "IBKRAdapter.h"
#import "CommonTypes.h"

@implementation DataAdapterFactory

+ (id<DataSourceAdapter>)adapterForDataSource:(DataSourceType)sourceType {
    switch (sourceType) {
        case DataSourceTypeSchwab:
            return [[SchwabDataAdapter alloc] init];
            
        case DataSourceTypeIBKR:
            return [[IBKRAdapter alloc] init];
            
        case DataSourceTypeWebull:
            return [[WebullDataAdapter alloc] init];
            
        case DataSourceTypeOther:
            return [[OtherDataAdapter alloc] init];
    
            
        case DataSourceTypeYahoo:
        case DataSourceTypeCustom:
        default:
            // Fallback to OtherDataAdapter for unsupported types
            NSLog(@"⚠️ DataAdapterFactory: No specific adapter for source type %ld, using OtherDataAdapter", (long)sourceType);
            return [[OtherDataAdapter alloc] init];
    }
}

@end
