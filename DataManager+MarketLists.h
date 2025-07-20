//
//  DataManager+MarketLists.h
//  TradingApp
//
//  Category for market lists functionality
//

#import "DataManager.h"

// Export data request type constants

@interface DataManager (MarketLists)

// Market Lists - Top Gainers/Losers
- (NSString *)requestTopGainersWithRankType:(NSString *)rankType
                                   pageSize:(NSInteger)pageSize
                                 completion:(void (^)(NSArray *gainers, NSError *error))completion;

- (NSString *)requestTopLosersWithRankType:(NSString *)rankType
                                  pageSize:(NSInteger)pageSize
                                completion:(void (^)(NSArray *losers, NSError *error))completion;

// ETF Lists
- (NSString *)requestETFListWithCompletion:(void (^)(NSArray *etfs, NSError *error))completion;

// Generic market list request
- (NSString *)requestMarketListOfType:(NSString *)listType
                           parameters:(NSDictionary *)parameters
                           completion:(void (^)(NSArray *items, NSError *error))completion;

@end
