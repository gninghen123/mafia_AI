//
//  DataManager+TickData.m
//  mafia_AI
//

#import "DataManager+TickData.h"
#import "OtherDataSource+TickData.h"
#import "TickDataModel.h"

@implementation DataManager (TickData)

#pragma mark - Tick Data Requests

- (void)requestRealtimeTicksForSymbol:(NSString *)symbol
                                limit:(NSInteger)limit
                             fromTime:(NSString *)fromTime
                           completion:(void(^)(NSArray<TickDataModel *> *ticks, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSLog(@"DataManager: Requesting realtime ticks for %@ (limit: %ld, fromTime: %@)",
          symbol, (long)limit, fromTime ?: @"default");
    
    // Get OtherDataSource (Nasdaq API)
    OtherDataSource *nasdaqSource = [self getOtherDataSource];
    if (!nasdaqSource) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"Nasdaq data source not available"}];
        NSLog(@"❌ DataManager: Nasdaq data source not found");
        if (completion) completion(nil, error);
        return;
    }
    
    // Make API request
    [nasdaqSource fetchRealtimeTradesForSymbol:symbol
                                         limit:limit
                                      fromTime:fromTime
                                    completion:^(NSArray *rawTicks, NSError *error) {
        if (error) {
            NSLog(@"❌ DataManager: Failed to fetch realtime ticks for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        if (!rawTicks || rawTicks.count == 0) {
            NSLog(@"⚠️ DataManager: No realtime ticks returned for %@", symbol);
            if (completion) completion(@[], nil);
            return;
        }
        
        // Convert raw API data to standardized runtime models
        NSArray<TickDataModel *> *standardizedTicks = [self standardizeTickData:rawTicks];
        
        NSLog(@"✅ DataManager: Successfully processed %lu realtime ticks for %@",
              (unsigned long)standardizedTicks.count, symbol);
        
        if (completion) completion(standardizedTicks, nil);
    }];
}

- (void)requestExtendedTicksForSymbol:(NSString *)symbol
                           marketType:(NSString *)marketType
                           completion:(void(^)(NSArray<TickDataModel *> *ticks, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSLog(@"DataManager: Requesting extended ticks for %@ (%@)", symbol, marketType ?: @"post");
    
    // Get OtherDataSource (Nasdaq API)
    OtherDataSource *nasdaqSource = [self getOtherDataSource];
    if (!nasdaqSource) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"Nasdaq data source not available"}];
        NSLog(@"❌ DataManager: Nasdaq data source not found");
        if (completion) completion(nil, error);
        return;
    }
    
    // Make API request
    [nasdaqSource fetchExtendedTradingForSymbol:symbol
                                     marketType:marketType
                                     completion:^(NSArray *rawTicks, NSError *error) {
        if (error) {
            NSLog(@"❌ DataManager: Failed to fetch extended ticks for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        if (!rawTicks || rawTicks.count == 0) {
            NSLog(@"⚠️ DataManager: No extended ticks returned for %@", symbol);
            if (completion) completion(@[], nil);
            return;
        }
        
        // Convert raw API data to standardized runtime models
        NSArray<TickDataModel *> *standardizedTicks = [self standardizeTickData:rawTicks];
        
        NSLog(@"✅ DataManager: Successfully processed %lu extended ticks for %@",
              (unsigned long)standardizedTicks.count, symbol);
        
        if (completion) completion(standardizedTicks, nil);
    }];
}

- (void)requestFullSessionTicksForSymbol:(NSString *)symbol
                              completion:(void(^)(NSArray<TickDataModel *> *ticks, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSLog(@"DataManager: Requesting full session ticks for %@", symbol);
    
    // Get OtherDataSource (Nasdaq API)
    OtherDataSource *nasdaqSource = [self getOtherDataSource];
    if (!nasdaqSource) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"Nasdaq data source not available"}];
        NSLog(@"❌ DataManager: Nasdaq data source not found");
        if (completion) completion(nil, error);
        return;
    }
    
    // Make API request for full session
    [nasdaqSource fetchFullSessionTradesForSymbol:symbol
                                        completion:^(NSArray *rawTicks, NSError *error) {
        if (error) {
            NSLog(@"❌ DataManager: Failed to fetch full session ticks for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        if (!rawTicks || rawTicks.count == 0) {
            NSLog(@"⚠️ DataManager: No full session ticks returned for %@", symbol);
            if (completion) completion(@[], nil);
            return;
        }
        
        // Convert raw API data to standardized runtime models
        NSArray<TickDataModel *> *standardizedTicks = [self standardizeTickData:rawTicks];
        
        NSLog(@"✅ DataManager: Successfully processed %lu full session ticks for %@",
              (unsigned long)standardizedTicks.count, symbol);
        
        if (completion) completion(standardizedTicks, nil);
    }];
}

#pragma mark - Private Methods - Data Standardization

- (NSArray<TickDataModel *> *)standardizeTickData:(NSArray *)rawTickData {
    if (!rawTickData || rawTickData.count == 0) {
        return @[];
    }
    
    NSLog(@"📊 DataManager: Standardizing %lu raw tick records", (unsigned long)rawTickData.count);
    
    // Use TickDataModel factory method to standardize the data
    NSArray<TickDataModel *> *standardizedTicks = [TickDataModel ticksFromNasdaqDataArray:rawTickData];
    
    NSLog(@"✅ DataManager: Standardization complete - %lu tick models created",
          (unsigned long)standardizedTicks.count);
    
    return standardizedTicks;
}

#pragma mark - Private Helper Methods

- (OtherDataSource *)getOtherDataSource {
    // Create a new instance for now
    // TODO: In future, get from DownloadManager's registered sources
    return [[OtherDataSource alloc] init];
}

@end
