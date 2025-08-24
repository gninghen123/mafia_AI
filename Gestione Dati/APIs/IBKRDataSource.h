//
//  IBKRDataSource.h
//  TradingApp
//
//  Interactive Brokers API data source implementation
//  Integrates with TWS/IB Gateway via IB API or REST
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IBKRConnectionType) {
    IBKRConnectionTypeTWS,      // TWS (Trader Workstation)
    IBKRConnectionTypeGateway   // IB Gateway (headless)
};

typedef NS_ENUM(NSInteger, IBKRConnectionStatus) {
    IBKRConnectionStatusDisconnected,
    IBKRConnectionStatusConnecting,
    IBKRConnectionStatusConnected,
    IBKRConnectionStatusAuthenticated,
    IBKRConnectionStatusError
};

@interface IBKRDataSource : NSObject <DataSource>

#pragma mark - Initialization

/// Initialize with default connection parameters
- (instancetype)init;

/// Initialize with custom connection settings
- (instancetype)initWithHost:(NSString *)host
                        port:(NSInteger)port
                    clientId:(NSInteger)clientId
              connectionType:(IBKRConnectionType)connectionType;

#pragma mark - Connection Management

/// Connect to TWS/IB Gateway
/// @param completion Completion block with success status and error
- (void)connectWithCompletion:(nullable void (^)(BOOL success, NSError * _Nullable error))completion;

/// Disconnect from TWS/IB Gateway
- (void)disconnect;

/// Check if connection is active
@property (nonatomic, readonly) BOOL isConnected;

/// Current connection status
@property (nonatomic, readonly) IBKRConnectionStatus connectionStatus;

/// Connection parameters (read-only)
@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSInteger port;
@property (nonatomic, readonly) NSInteger clientId;
@property (nonatomic, readonly) IBKRConnectionType connectionType;

#pragma mark - Account Information

/// Get available accounts
- (void)getAccountsWithCompletion:(void (^)(NSArray<NSString *> * _Nullable accounts, NSError * _Nullable error))completion;

/// Get account summary
- (void)getAccountSummary:(NSString *)accountId
               completion:(void (^)(NSDictionary * _Nullable summary, NSError * _Nullable error))completion;

/// Get positions for account
- (void)getPositions:(NSString *)accountId
          completion:(void (^)(NSArray * _Nullable positions, NSError * _Nullable error))completion;

/// Get orders for account
- (void)getOrders:(NSString *)accountId
       completion:(void (^)(NSArray * _Nullable orders, NSError * _Nullable error))completion;

#pragma mark - Market Data

/// Request market data for symbol
- (void)requestMarketData:(NSString *)symbol
               completion:(void (^)(NSDictionary * _Nullable quote, NSError * _Nullable error))completion;

/// Request historical data
- (void)requestHistoricalData:(NSString *)symbol
                     duration:(NSString *)duration  // e.g., "1 D", "1 W", "1 M"
                      barSize:(NSString *)barSize    // e.g., "1 min", "5 mins", "1 day"
                   completion:(void (^)(NSArray * _Nullable bars, NSError * _Nullable error))completion;

/// Request real-time bars (streaming)
- (void)requestRealTimeBars:(NSString *)symbol
                    barSize:(NSInteger)barSize
                 completion:(void (^)(NSDictionary * _Nullable bar, NSError * _Nullable error))completion;

#pragma mark - Contract Information

/// Search for contracts by symbol
- (void)searchContracts:(NSString *)symbol
             completion:(void (^)(NSArray * _Nullable contracts, NSError * _Nullable error))completion;

/// Get contract details
- (void)getContractDetails:(NSInteger)contractId
                completion:(void (^)(NSDictionary * _Nullable details, NSError * _Nullable error))completion;

#pragma mark - Order Management

/// Place order
- (void)placeOrder:(NSInteger)orderId
          contract:(NSDictionary *)contractInfo
             order:(NSDictionary *)orderInfo
        completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// Cancel order
- (void)cancelOrder:(NSInteger)orderId
         completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// Modify order
- (void)modifyOrder:(NSInteger)orderId
           contract:(NSDictionary *)contractInfo
              order:(NSDictionary *)orderInfo
         completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

#pragma mark - Configuration

/// Set market data type (1 = live, 2 = frozen, 3 = delayed, 4 = delayed frozen)
- (void)setMarketDataType:(NSInteger)marketDataType;

/// Request market data subscriptions
- (void)requestMarketDataType:(void (^)(NSInteger currentType, NSError * _Nullable error))completion;

#pragma mark - Error Handling & Logging

/// Enable/disable debug logging
@property (nonatomic, assign) BOOL debugLogging;

/// Last connection error
@property (nonatomic, readonly, nullable) NSError *lastConnectionError;

/// Connection statistics
- (NSDictionary *)connectionStatistics;

@end

NS_ASSUME_NONNULL_END
