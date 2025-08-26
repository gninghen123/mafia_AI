//
//  SchwabDataSource.h (UPDATED)
//  TradingApp
//
//  UNIFICAZIONE: Header con tutti i metodi del protocollo DataSource unificato
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"
#import "CommonTypes.h"

@interface SchwabDataSource : NSObject <DataSource>

#pragma mark - OAuth2 Authentication
- (void)authenticateWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)refreshTokenIfNeeded:(void (^)(BOOL success, NSError *error))completion;
- (BOOL)hasValidToken;

#pragma mark - DataSource Protocol - Unified Methods

// Portfolio Data (UNIFIED)
- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion;
- (void)fetchAccountDetails:(NSString *)accountId completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion;
- (void)fetchPositionsWithCompletion:(void (^)(NSArray *positions, NSError *error))completion;
- (void)fetchPositionsForAccount:(NSString *)accountId completion:(void (^)(NSArray *positions, NSError *error))completion;
- (void)fetchOrdersWithCompletion:(void (^)(NSArray *orders, NSError *error))completion;
- (void)fetchOrdersForAccount:(NSString *)accountId completion:(void (^)(NSArray *orders, NSError *error))completion;

// Trading Operations (UNIFIED)
- (void)placeOrderForAccount:(NSString *)accountId orderData:(NSDictionary *)orderData completion:(void (^)(NSString *orderId, NSError *error))completion;
- (void)cancelOrderForAccount:(NSString *)accountId orderId:(NSString *)orderId completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - Schwab-Specific Internal Methods (Private - chiamati dai metodi unificati)

// Account endpoints (INTERNAL)
- (void)fetchAccountNumbers:(void (^)(NSArray *accountNumbers, NSError *error))completion;

// Trading endpoints (INTERNAL)
- (void)placeOrder:(NSDictionary *)orderData
        forAccount:(NSString *)accountNumber
        completion:(void (^)(NSString *orderID, NSError *error))completion;

- (void)cancelOrder:(NSString *)orderID
        forAccount:(NSString *)accountNumber
        completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - Market Data (DataSource Protocol)
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;
- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion;
- (void)fetchMarketHours:(NSString *)market
              completion:(void (^)(NSDictionary *hours, NSError *error))completion;

#pragma mark - Historical Data (DataSource Protocol)
- (void)fetchPriceHistoryWithDateRange:(NSString *)symbol
                             startDate:(NSDate *)startDate
                               endDate:(NSDate *)endDate
                             timeframe:(BarTimeframe)timeframe
                 needExtendedHoursData:(BOOL)needExtendedHours
                     needPreviousClose:(BOOL)needPreviousClose
                            completion:(void (^)(NSDictionary *priceHistory, NSError *error))completion;

- (void)fetchHistoricalDataForSymbolWithCount:(NSString *)symbol
                                    timeframe:(BarTimeframe)timeframe
                                        count:(NSInteger)count
                        needExtendedHoursData:(BOOL)needExtendedHours
                             needPreviousClose:(BOOL)needPreviousClose
                                    completion:(void (^)(NSArray *bars, NSError *error))completion;

#pragma mark - Helper Methods
- (NSDate *)calculateStartDateForTimeframe:(BarTimeframe)timeframe
                                     count:(NSInteger)count
                                  fromDate:(NSDate *)endDate;

- (void)convertTimeframeToFrequency:(BarTimeframe)timeframe
                      frequencyType:(NSString **)frequencyType
                          frequency:(NSInteger *)frequency;

@end
