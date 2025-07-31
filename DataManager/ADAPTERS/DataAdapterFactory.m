// DataAdapterFactory.m
// Fixed implementation with correct DataSourceType values

#import "DataAdapterFactory.h"
#import "SchwabDataAdapter.h"
#import "WebullDataAdapter.h"

@implementation DataAdapterFactory

+ (id<DataSourceAdapter>)adapterForDataSource:(DataSourceType)sourceType {
    switch (sourceType) {
        case DataSourceTypeSchwab:
            return [[SchwabDataAdapter alloc] init];
            
        case DataSourceTypeCustom:
            // Webull uses Custom type in the current implementation
            return [[WebullDataAdapter alloc] init];
            
        default:
            NSLog(@"Warning: No adapter for data source type %ld", (long)sourceType);
            return nil;
    }
}

@end
