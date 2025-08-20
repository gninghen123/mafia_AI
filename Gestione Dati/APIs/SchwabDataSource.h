//
//  SchwabDataSource.h
//  TradingApp
//
//  Schwab API data source implementation
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"
#import "CommonTypes.h"  // AGGIUNTO: Per BarTimeframe enum

@interface SchwabDataSource : NSObject <DataSource>

// OAuth2 Authentication
- (void)authenticateWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)refreshTokenIfNeeded:(void (^)(BOOL success, NSError *error))completion;
- (BOOL)hasValidToken;

// Account endpoints
- (void)fetchAccountNumbers:(void (^)(NSArray *accountNumbers, NSError *error))completion;
- (void)fetchAccountDetails:(NSString *)accountNumber
                 completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion;

// Trading endpoints
- (void)placeOrder:(NSDictionary *)orderData
      forAccount:(NSString *)accountNumber
      completion:(void (^)(NSString *orderID, NSError *error))completion;

- (void)cancelOrder:(NSString *)orderID
        forAccount:(NSString *)accountNumber
        completion:(void (^)(BOOL success, NSError *error))completion;

// Market data endpoints
- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                  completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

- (void)fetchMarketHours:(NSString *)market
              completion:(void (^)(NSDictionary *hours, NSError *error))completion;

// NUOVO: Metodo con date range + extended hours
- (void)fetchPriceHistoryWithDateRange:(NSString *)symbol
                             startDate:(NSDate *)startDate
                               endDate:(NSDate *)endDate
                             timeframe:(BarTimeframe)timeframe
                 needExtendedHoursData:(BOOL)needExtendedHours
                     needPreviousClose:(BOOL)needPreviousClose
                            completion:(void (^)(NSDictionary *priceHistory, NSError *error))completion;

// NUOVO: Metodo principale che supporta count + extended hours
- (void)fetchHistoricalDataForSymbolWithCount:(NSString *)symbol
                                    timeframe:(BarTimeframe)timeframe
                                        count:(NSInteger)count
                        needExtendedHoursData:(BOOL)needExtendedHours
                             needPreviousClose:(BOOL)needPreviousClose
                                    completion:(void (^)(NSArray *bars, NSError *error))completion;

// NUOVO: Helper methods
- (NSDate *)calculateStartDateForTimeframe:(BarTimeframe)timeframe
                                     count:(NSInteger)count
                                  fromDate:(NSDate *)endDate;

- (void)convertTimeframeToFrequency:(BarTimeframe)timeframe
                      frequencyType:(NSString **)frequencyType
                          frequency:(NSInteger *)frequency;

@end
