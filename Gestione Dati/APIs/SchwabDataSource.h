//
//  SchwabDataSource.h - REFACTORED: AUTH REMOVED
//  TradingApp
//
//  ✅ REFACTORED: Rimossa tutta la logica di autenticazione (ora in SchwabLoginManager)
//  ✅ MANTIENE: Tutti i metodi di market data, account, trading (INVARIATI)
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"
#import "CommonTypes.h"

@interface SchwabDataSource : NSObject <DataSource>

#pragma mark - DataSource Protocol - UNIFIED METHODS (INVARIATI)

// Connection Management (UNIFIED)
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)disconnect;

// Market Data (UNIFIED - Required) - NON MODIFICATI
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

// Historical Data (UNIFIED - Required) - NON MODIFICATI
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

#pragma mark - Portfolio Data (UNIFIED - Optional for brokers) - NON MODIFICATI
- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion;
- (void)fetchAccountDetails:(NSString *)accountId
                 completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion;
- (void)fetchPositionsForAccount:(NSString *)accountId
                      completion:(void (^)(NSArray *positions, NSError *error))completion;
- (void)fetchOrdersForAccount:(NSString *)accountId
                   completion:(void (^)(NSArray *orders, NSError *error))completion;

#pragma mark - Trading Operations (UNIFIED - Optional for brokers) - NON MODIFICATI
- (void)placeOrderForAccount:(NSString *)accountId
                   orderData:(NSDictionary *)orderData
                  completion:(void (^)(NSString *orderId, NSError *error))completion;
- (void)cancelOrderForAccount:(NSString *)accountId
                      orderId:(NSString *)orderId
                   completion:(void (^)(BOOL success, NSError *error))completion;

@end
