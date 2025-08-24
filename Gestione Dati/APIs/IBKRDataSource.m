//
//  IBKRDataSource.m
//  TradingApp
//

#import "IBKRDataSource.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "CommonTypes.h"

// Default connection parameters
static NSString *const kDefaultHost = @"127.0.0.1";
static NSInteger const kDefaultTWSPort = 7497;
static NSInteger const kDefaultGatewayPort = 4002;
static NSInteger const kDefaultClientId = 1;

// Request timeout
static NSTimeInterval const kRequestTimeout = 30.0;

@interface IBKRDataSource () {
    // Private instance variables for readonly properties
    NSString *_host;
    NSInteger _port;
    NSInteger _clientId;
    IBKRConnectionType _connectionType;
}

// Protocol properties (DataSource conformance) - internal readwrite
@property (nonatomic, readwrite) DataSourceType sourceType;
@property (nonatomic, readwrite) DataSourceCapabilities capabilities;
@property (nonatomic, readwrite) NSString *sourceName;
@property (nonatomic, readwrite) BOOL isConnected;

// Connection properties - internal readwrite
@property (nonatomic, readwrite) IBKRConnectionStatus connectionStatus;

// Internal components
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSOperationQueue *requestQueue;
@property (nonatomic, strong) NSMutableDictionary *pendingRequests;
@property (nonatomic, strong) NSError *lastConnectionError;

// Request management
@property (nonatomic, assign) NSInteger nextRequestId;

@end

@implementation IBKRDataSource

@synthesize sourceType = _sourceType;
@synthesize capabilities = _capabilities;
@synthesize sourceName = _sourceName;
@synthesize isConnected = _isConnected;

#pragma mark - Property Getters for Readonly Properties

- (NSString *)host {
    return _host;
}

- (NSInteger)port {
    return _port;
}

- (NSInteger)clientId {
    return _clientId;
}

- (IBKRConnectionType)connectionType {
    return _connectionType;
}

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithHost:kDefaultHost
                         port:kDefaultTWSPort
                     clientId:kDefaultClientId
               connectionType:IBKRConnectionTypeTWS];
}

- (instancetype)initWithHost:(NSString *)host
                        port:(NSInteger)port
                    clientId:(NSInteger)clientId
              connectionType:(IBKRConnectionType)connectionType {
    self = [super init];
    if (self) {
        // Connection configuration - use private ivars
        _host = host.copy;
        _port = port;
        _clientId = clientId;
        _connectionType = connectionType;
        _connectionStatus = IBKRConnectionStatusDisconnected;
        
        // DataSource protocol properties
        _sourceType = DataSourceTypeIBKR;
        _sourceName = @"Interactive Brokers";
        _capabilities = DataSourceCapabilityQuotes |
                       DataSourceCapabilityHistorical |
                       DataSourceCapabilityAccounts |
                       DataSourceCapabilityTrading |
                       DataSourceCapabilityRealtime |
                       DataSourceCapabilityOrderBook |
                       DataSourceCapabilityOptions;
        _isConnected = NO;
        
        // Internal setup
        _nextRequestId = 1;
        _debugLogging = NO;
        _pendingRequests = [NSMutableDictionary dictionary];
        
        // Configure network session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = kRequestTimeout;
        config.timeoutIntervalForResource = kRequestTimeout * 2;
        _session = [NSURLSession sessionWithConfiguration:config];
        
        // Setup request queue
        _requestQueue = [[NSOperationQueue alloc] init];
        _requestQueue.maxConcurrentOperationCount = 5;
        _requestQueue.name = @"IBKRDataSource.RequestQueue";
        
        [self logDebug:@"IBKRDataSource initialized for %@:%ld (clientId: %ld)",
         _host, (long)_port, (long)_clientId];
    }
    return self;
}

#pragma mark - DataSource Protocol Implementation

- (void)connectWithCompletion:(nullable void (^)(BOOL success, NSError * _Nullable error))completion {
    [self logDebug:@"Attempting connection to IBKR..."];
    
    self.connectionStatus = IBKRConnectionStatusConnecting;
    
    // Simulate connection process (in real implementation, this would connect to TWS/Gateway)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // TODO: Implement actual connection to TWS/IB Gateway
        // For now, simulate success if TWS ports are reasonable
        BOOL connectionSuccess = (_port == 7497 || _port == 4002) && [_host isEqualToString:@"127.0.0.1"];
        
        if (connectionSuccess) {
            self.connectionStatus = IBKRConnectionStatusConnected;
            self->_isConnected = YES;
            self.lastConnectionError = nil;
            [self logDebug:@"Connected to IBKR successfully"];
            
            // Start heartbeat/keepalive
            [self startConnectionMonitoring];
            
        } else {
            self.connectionStatus = IBKRConnectionStatusError;
            self->_isConnected = NO;
            NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to connect to IBKR at %@:%ld", _host, (long)_port]}];
            self.lastConnectionError = error;
            [self logDebug:@"Failed to connect to IBKR: %@", error.localizedDescription];
        }
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(connectionSuccess, connectionSuccess ? nil : self.lastConnectionError);
            });
        }
    });
}

- (void)disconnect {
    [self logDebug:@"Disconnecting from IBKR..."];
    
    self.connectionStatus = IBKRConnectionStatusDisconnected;
    self->_isConnected = NO;
    
    // Cancel all pending requests
    [self.pendingRequests removeAllObjects];
    
    // Stop connection monitoring
    [self stopConnectionMonitoring];
    
    [self logDebug:@"Disconnected from IBKR"];
}

#pragma mark - Market Data Methods

- (void)requestMarketData:(NSString *)symbol
               completion:(void (^)(NSDictionary * _Nullable quote, NSError * _Nullable error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(nil, error);
        return;
    }
    
    [self logDebug:@"Requesting market data for %@", symbol];
    
    NSInteger requestId = [self nextRequestId];
    
    // TODO: Implement actual IBKR API call
    // For now, return mock data
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Mock quote data in IBKR format
        NSDictionary *quote = @{
            @"symbol": symbol,
            @"bid": @(100.25),
            @"ask": @(100.27),
            @"last": @(100.26),
            @"lastSize": @(100),
            @"bidSize": @(50),
            @"askSize": @(75),
            @"volume": @(125000),
            @"high": @(101.50),
            @"low": @(99.80),
            @"open": @(100.10),
            @"close": @(99.95),
            @"timestamp": [NSDate date]
        };
        
        [self logDebug:@"Received market data for %@: last=%.2f", symbol, [quote[@"last"] doubleValue]];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(quote, nil);
            });
        }
    });
}

- (void)requestHistoricalData:(NSString *)symbol
                     duration:(NSString *)duration
                      barSize:(NSString *)barSize
                   completion:(void (^)(NSArray * _Nullable bars, NSError * _Nullable error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(nil, error);
        return;
    }
    
    [self logDebug:@"Requesting historical data for %@ (duration: %@, barSize: %@)", symbol, duration, barSize];
    
    NSInteger requestId = [self nextRequestId];
    
    // TODO: Implement actual IBKR historical data request
    // For now, return mock data
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Generate mock historical bars
        NSMutableArray *bars = [NSMutableArray array];
        NSDate *startDate = [[NSDate date] dateByAddingTimeInterval:-86400 * 30]; // 30 days ago
        
        for (NSInteger i = 0; i < 30; i++) {
            NSDate *barDate = [startDate dateByAddingTimeInterval:86400 * i];
            double basePrice = 100.0 + (arc4random_uniform(20) - 10);
            
            NSDictionary *bar = @{
                @"date": barDate,
                @"open": @(basePrice),
                @"high": @(basePrice + (arc4random_uniform(300) / 100.0)),
                @"low": @(basePrice - (arc4random_uniform(300) / 100.0)),
                @"close": @(basePrice + (arc4random_uniform(200) / 100.0) - 1.0),
                @"volume": @(arc4random_uniform(1000000) + 100000)
            };
            
            [bars addObject:bar];
        }
        
        [self logDebug:@"Generated %lu historical bars for %@", (unsigned long)bars.count, symbol];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([bars copy], nil);
            });
        }
    });
}

#pragma mark - Account Methods

- (void)getAccountsWithCompletion:(void (^)(NSArray<NSString *> * _Nullable accounts, NSError * _Nullable error))completion {
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(nil, error);
        return;
    }
    
    [self logDebug:@"Requesting account list"];
    
    // TODO: Implement actual account request
    // Mock response
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *accounts = @[@"DU123456", @"DU123457"]; // Mock paper trading accounts
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(accounts, nil);
            });
        }
    });
}

- (void)getAccountSummary:(NSString *)accountId
               completion:(void (^)(NSDictionary * _Nullable summary, NSError * _Nullable error))completion {
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(nil, error);
        return;
    }
    
    [self logDebug:@"Requesting account summary for %@", accountId];
    
    // TODO: Implement actual account summary request
    // Mock response
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *summary = @{
            @"AccountCode": accountId,
            @"NetLiquidation": @"100000.00",
            @"TotalCashValue": @"50000.00",
            @"BuyingPower": @"200000.00",
            @"GrossPositionValue": @"50000.00",
            @"UnrealizedPnL": @"2500.00",
            @"RealizedPnL": @"1000.00"
        };
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(summary, nil);
            });
        }
    });
}

#pragma mark - Order Management

- (void)placeOrder:(NSInteger)orderId
          contract:(NSDictionary *)contractInfo
             order:(NSDictionary *)orderInfo
        completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(NO, error);
        return;
    }
    
    [self logDebug:@"Placing order %ld", (long)orderId];
    
    // TODO: Implement actual order placement
    // Mock success
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES, nil);
            });
        }
    });
}

#pragma mark - DataSource Protocol - Market Lists

- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion {
    
    // IBKR doesn't typically provide market lists like top gainers/losers
    // This would be handled by other data sources
    NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Market lists not supported by IBKR data source"}];
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], error);
        });
    }
}

#pragma mark - DataSource Protocol - Subscriptions

- (void)subscribeToQuotes:(NSArray<NSString *> *)symbols {
    [self logDebug:@"Subscribing to quotes for %lu symbols", (unsigned long)symbols.count];
    // TODO: Implement IBKR market data subscriptions
}

- (void)unsubscribeFromQuotes:(NSArray<NSString *> *)symbols {
    [self logDebug:@"Unsubscribing from quotes for %lu symbols", (unsigned long)symbols.count];
    // TODO: Implement IBKR market data unsubscriptions
}

- (NSInteger)remainingRequests {
    // IBKR doesn't have explicit rate limits for market data
    return NSIntegerMax;
}

- (NSDate *)rateLimitResetDate {
    return nil;
}

#pragma mark - Internal Methods

- (NSInteger)nextRequestId {
    return ++_nextRequestId;  // ✅ CORRECT - increments the ivar, not the property
}

- (void)startConnectionMonitoring {
    [self logDebug:@"Starting connection monitoring"];
    // TODO: Implement heartbeat/keepalive mechanism
}

- (void)stopConnectionMonitoring {
    [self logDebug:@"Stopping connection monitoring"];
    // TODO: Stop heartbeat/keepalive mechanism
}

- (void)logDebug:(NSString *)format, ... {
    if (self.debugLogging) {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"[IBKR] %@", message);
    }
}

#pragma mark - Configuration

- (void)setMarketDataType:(NSInteger)marketDataType {
    [self logDebug:@"Setting market data type to %ld", (long)marketDataType];
    // TODO: Implement market data type setting
}

- (void)requestMarketDataType:(void (^)(NSInteger currentType, NSError * _Nullable error))completion {
    // TODO: Implement market data type request
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(1, nil); // Default to live data
        });
    }
}

- (NSDictionary *)connectionStatistics {
    return @{
        @"host": _host,
        @"port": @(_port),
        @"clientId": @(_clientId),
        @"connectionType": @(_connectionType),
        @"connectionStatus": @(self.connectionStatus),
        @"isConnected": @(self.isConnected),
        @"pendingRequests": @(self.pendingRequests.count)
    };
}

@end
