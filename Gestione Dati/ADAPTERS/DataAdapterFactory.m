//
//  DataAdapterFactory.m
//  TradingApp
//
//  Updated implementation with YahooDataAdapter
//  Now includes dedicated Yahoo Finance adapter for JSON API format
//

#import "DataAdapterFactory.h"
#import "SchwabDataAdapter.h"
#import "WebullDataAdapter.h"
#import "OtherDataAdapter.h"
#import "IBKRAdapter.h"
#import "YahooDataAdapter.h"  // ✅ NEW: Dedicated Yahoo adapter
#import "CommonTypes.h"

@implementation DataAdapterFactory

+ (id<DataSourceAdapter>)adapterForDataSource:(DataSourceType)sourceType {
    switch (sourceType) {
        case DataSourceTypeSchwab:
            NSLog(@"📊 DataAdapterFactory: Creating SchwabDataAdapter");
            return [[SchwabDataAdapter alloc] init];
            
        case DataSourceTypeIBKR:
            NSLog(@"📊 DataAdapterFactory: Creating IBKRAdapter");
            return [[IBKRAdapter alloc] init];
            
        case DataSourceTypeWebull:
            NSLog(@"📊 DataAdapterFactory: Creating WebullDataAdapter");
            return [[WebullDataAdapter alloc] init];
            
        case DataSourceTypeYahoo:
            // ✅ NEW: Dedicated Yahoo adapter for JSON API
            NSLog(@"📊 DataAdapterFactory: Creating YahooDataAdapter for JSON API");
            return [[YahooDataAdapter alloc] init];
            
        case DataSourceTypeOther:
            // OtherDataAdapter now handles fallback/CSV APIs
            NSLog(@"📊 DataAdapterFactory: Creating OtherDataAdapter for CSV/Other APIs");
            return [[OtherDataAdapter alloc] init];
            
        case DataSourceTypeCustom:
        case DataSourceTypeClaude:
        default:
            // Fallback to OtherDataAdapter for unsupported types
            NSLog(@"⚠️ DataAdapterFactory: No specific adapter for source type %ld, using OtherDataAdapter", (long)sourceType);
            return [[OtherDataAdapter alloc] init];
    }
}

@end
