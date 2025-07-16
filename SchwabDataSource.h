//
//  SchwabDataSource.h
//  TradingApp
//
//  Schwab API data source implementation
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"

@interface SchwabDataSource : NSObject <DataSourceProtocol>

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
- (void)fetchQuoteForSymbols:(NSArray<NSString *> *)symbols
                  completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

- (void)fetchMarketHours:(NSString *)market
              completion:(void (^)(NSDictionary *hours, NSError *error))completion;

- (void)fetchPriceHistory:(NSString *)symbol
               periodType:(NSString *)periodType
                   period:(NSInteger)period
            frequencyType:(NSString *)frequencyType
                frequency:(NSInteger)frequency
               completion:(void (^)(NSDictionary *priceHistory, NSError *error))completion;

@end
