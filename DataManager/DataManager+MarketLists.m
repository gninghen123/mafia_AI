//
//  DataManager+MarketLists.m
//  TradingApp
//

#import "DataManager+MarketLists.h"
#import "DownloadManager.h"
#import "WebullDataSource.h"
#import "DataManager+Persistence.h"

// Define new data request types for market lists

@implementation DataManager (MarketLists)

- (NSString *)requestTopGainersWithRankType:(NSString *)rankType
                                   pageSize:(NSInteger)pageSize
                                 completion:(void (^)(NSArray *gainers, NSError *error))completion {
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    NSDictionary *parameters = @{
        @"listType": @"topGainers",
        @"rankType": rankType,
        @"pageSize": @(pageSize),
        @"requestID": requestID
    };
    
    __weak typeof(self) weakSelf = self;
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeTopGainers
                                         parameters:parameters
                                     preferredSource:DataSourceTypeCustom
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            if (completion) completion(nil, error);
        } else {
            NSArray *gainers = result;
            
            // Salva in DataHub se abilitato
            if (strongSelf && strongSelf.autoSaveToDataHub && strongSelf.saveMarketLists) {
                [strongSelf saveMarketListToDataHub:gainers
                                           listType:@"gainers"
                                          timeframe:rankType];
            }
            
            if (completion) completion(gainers, nil);
        }
    }];
    
    return requestID;
}

- (NSString *)requestTopLosersWithRankType:(NSString *)rankType
                                  pageSize:(NSInteger)pageSize
                                completion:(void (^)(NSArray *losers, NSError *error))completion {
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    NSDictionary *parameters = @{
        @"listType": @"topLosers",
        @"rankType": rankType,
        @"pageSize": @(pageSize),
        @"requestID": requestID
    };
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeTopGainers
                                         parameters:parameters
                                     preferredSource:DataSourceTypeCustom
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            NSArray *gainers = result;
            
            // NUOVO: Salva in DataHub
            if (self.autoSaveToDataHub && self.saveMarketLists) {
                [self saveMarketListToDataHub:gainers
                                     listType:@"gainers"
                                    timeframe:rankType];
            }
            
            if (completion) completion(gainers, nil);
        }
    }];
}

- (NSString *)requestETFListWithCompletion:(void (^)(NSArray *etfs, NSError *error))completion {
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    NSDictionary *parameters = @{
        @"listType": @"etfList",
        @"requestID": requestID
    };
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeETFList
                                         parameters:parameters
                                     preferredSource:DataSourceTypeCustom
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            NSArray *etfs = result;
            if (completion) completion(etfs, nil);
        }
    }];
    
    return requestID;
}

- (NSString *)requestMarketListOfType:(NSString *)listType
                           parameters:(NSDictionary *)parameters
                           completion:(void (^)(NSArray *items, NSError *error))completion {
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    
    NSMutableDictionary *requestParams = [NSMutableDictionary dictionaryWithDictionary:parameters];
    requestParams[@"listType"] = listType;
    requestParams[@"requestID"] = requestID;
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeMarketList
                                         parameters:requestParams
                                     preferredSource:DataSourceTypeCustom
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            NSArray *items = result;
            if (completion) completion(items, nil);
        }
    }];
    
    return requestID;
}

@end
