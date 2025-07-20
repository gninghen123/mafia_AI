//
//  WebullDataSource.h
//  TradingApp
//
//  Webull API data source implementation
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"

@interface WebullDataSource : NSObject <DataSourceProtocol>

// Market Lists
- (void)fetchTopGainersWithRankType:(NSString *)rankType
                           pageSize:(NSInteger)pageSize
                         completion:(void (^)(NSArray *gainers, NSError *error))completion;

- (void)fetchTopLosersWithRankType:(NSString *)rankType
                          pageSize:(NSInteger)pageSize
                        completion:(void (^)(NSArray *losers, NSError *error))completion;

- (void)fetchETFListWithCompletion:(void (^)(NSArray *etfs, NSError *error))completion;

// Quotes
- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

// Historical Data
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                          timeframe:(NSString *)timeframe
                              count:(NSInteger)count
                         completion:(void (^)(NSArray *bars, NSError *error))completion;

@end
