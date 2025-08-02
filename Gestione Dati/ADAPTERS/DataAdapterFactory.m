// DataAdapterFactory.m
// Updated implementation with OtherDataAdapter

#import "DataAdapterFactory.h"
#import "SchwabDataAdapter.h"
#import "WebullDataAdapter.h"
#import "OtherDataAdapter.h"

@implementation DataAdapterFactory

+ (id<DataSourceAdapter>)adapterForDataSource:(DataSourceType)sourceType {
    switch (sourceType) {
        case DataSourceTypeSchwab:
            return [[SchwabDataAdapter alloc] init];
            
        case DataSourceTypeWebull:
            return [[WebullDataAdapter alloc] init];
            
        case DataSourceTypeOther:  // NUOVO: OtherDataSource adapter
            return [[OtherDataAdapter alloc] init];
            
        case DataSourceTypeCustom:
            // Keep for any actual custom implementations
            return [[WebullDataAdapter alloc] init]; // Fallback for now
            
        default:
            NSLog(@"Warning: No adapter for data source type %ld", (long)sourceType);
            return nil;
    }
}

@end
