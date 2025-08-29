//
//  IBKRWebSocketDataSource.h
//  TradingApp
//
//  TCP Fallback DataSource for IBKR Gateway (porta 4002)
//  Interfaccia IDENTICA a IBKRDataSource REST calls
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IBKRWebSocketDataSource : NSObject

#pragma mark - Connection Management
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSInteger port;
@property (nonatomic, readonly) NSInteger clientId;

- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port clientId:(NSInteger)clientId;
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion;
- (void)disconnect;

#pragma mark - Account Data (Identical interface to REST)
/// Returns EXACT same format as REST /iserver/accounts
- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *_Nullable error))completion;

/// Returns EXACT same format as REST /portfolio/accounts/{accountId}/positions
- (void)fetchPositionsForAccount:(NSString *)accountId
                      completion:(void (^)(NSArray *positions, NSError *_Nullable error))completion;

/// Returns EXACT same format as REST /iserver/account/orders
- (void)fetchOrdersForAccount:(NSString *)accountId
                   completion:(void (^)(NSArray *orders, NSError *_Nullable error))completion;

#pragma mark - Historical Data (Identical interface to REST)
/// Returns EXACT same format as REST /iserver/marketdata/history
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(NSString *)timeframe  // "1min", "1h", "1d" etc
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                          completion:(void (^)(NSArray *bars, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
