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
            
        case DataSourceTypeInteractiveBrokers:
            // TODO: Implement when IB adapter is ready
            NSLog(@"InteractiveBrokers adapter not yet implemented");
            return nil;
            
        case DataSourceTypeTDAmeritrade:
            // TODO: Implement when TD adapter is ready
            NSLog(@"TDAmeritrade adapter not yet implemented");
            return nil;
            
        case DataSourceTypeAlpaca:
            // TODO: Implement when Alpaca adapter is ready
            NSLog(@"Alpaca adapter not yet implemented");
            return nil;
            
        default:
            NSLog(@"Warning: No adapter for data source type %ld", (long)sourceType);
            return nil;
    }
}

@end
