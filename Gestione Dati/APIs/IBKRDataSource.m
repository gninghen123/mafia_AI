//
//  IBKRDataSource.m
//  TradingApp
//

#import "IBKRDataSource.h"
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "CommonTypes.h"
#import "IBKRLoginManager.h"


// Default connection parameters
static NSString *const kDefaultHost = @"127.0.0.1";
static NSInteger const kDefaultTWSPort = 7497;
static NSInteger const kDefaultGatewayPort = 4002;
static NSInteger const kDefaultClientId = 1;

// Request timeout
static NSTimeInterval const kRequestTimeout = 30.0;

// IBKR Client Portal API Base URLs
static NSString *const kIBKRClientPortalBaseURL = @"https://localhost:5001/v1/api";
static NSString *const kIBKRPaperBaseURL = @"https://localhost:5001/v1/api";  // Paper trading

// API Endpoints
static NSString *const kIBKRAuthStatusEndpoint = @"/iserver/auth/status";
static NSString *const kIBKRTickleEndpoint = @"/tickle";
static NSString *const kIBKRMarketDataEndpoint = @"/iserver/marketdata/snapshot";
static NSString *const kIBKRHistoricalEndpoint = @"/iserver/marketdata/history";
static NSString *const kIBKRAccountsEndpoint = @"/iserver/accounts";
static NSString *const kIBKRPortfolioEndpoint = @"/portfolio/accounts";
static NSString *const kIBKRContractSearchEndpoint = @"/iserver/secdef/search";


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
    
    // Use the login manager to ensure Client Portal is ready
    IBKRLoginManager *loginManager = [IBKRLoginManager sharedManager];
    
    [loginManager ensureClientPortalReadyWithCompletion:^(BOOL ready, NSError *error) {
        if (ready) {
            // Client Portal is running and authenticated - proceed with connection
            self.connectionStatus = IBKRConnectionStatusAuthenticated;
            self->_isConnected = YES;
            self.lastConnectionError = nil;
            
            [self logDebug:@"✅ Connected to IBKR successfully"];
            [self startConnectionMonitoring];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, nil);
                });
            }
        } else {
            // Connection failed
            self.connectionStatus = IBKRConnectionStatusError;
            self->_isConnected = NO;
            self.lastConnectionError = error;
            
            [self logDebug:@"❌ IBKR connection failed: %@", error.localizedDescription];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
            }
        }
    }];
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
    
    [self logDebug:@"Requesting real market data for %@", symbol];
    
    // First, search for the contract to get conid
    [self searchContract:symbol completion:^(NSNumber *conid, NSError *searchError) {
        if (searchError || !conid) {
            NSError *error = searchError ?: [NSError errorWithDomain:@"IBKRDataSource"
                                                                code:1004
                                                            userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Contract not found for symbol %@", symbol]}];
            if (completion) completion(nil, error);
            return;
        }
        
        // Request market data snapshot
        [self requestMarketDataSnapshot:conid symbol:symbol completion:completion];
    }];
}


- (void)searchContract:(NSString *)symbol completion:(void (^)(NSNumber *conid, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRContractSearchEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // Search payload
    NSDictionary *payload = @{
        @"symbol": symbol,
        @"secType": @"STK"  // Stock
    };
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (jsonError) {
        completion(nil, jsonError);
        return;
    }
    
    request.HTTPBody = jsonData;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"IBKRDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Contract search failed with HTTP %ld", (long)httpResponse.statusCode]}];
            completion(nil, httpError);
            return;
        }
        
        // Parse response
        NSError *parseError;
        NSArray *results = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            completion(nil, parseError);
            return;
        }
        
        // Find the first matching contract
        if (results.count > 0) {
            NSDictionary *contract = results.firstObject;
            NSNumber *conid = contract[@"conid"];
            
            [self logDebug:@"Found contract for %@: conid = %@", symbol, conid];
            completion(conid, nil);
        } else {
            NSError *notFoundError = [NSError errorWithDomain:@"IBKRDataSource"
                                                         code:1005
                                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"No contracts found for symbol %@", symbol]}];
            completion(nil, notFoundError);
        }
    }];
    
    [task resume];
}

- (void)requestMarketDataSnapshot:(NSNumber *)conid
                           symbol:(NSString *)symbol
                       completion:(void (^)(NSDictionary * _Nullable quote, NSError * _Nullable error))completion {
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRMarketDataEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    
    // Add query parameters
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"conids" value:conid.stringValue],
        [NSURLQueryItem queryItemWithName:@"fields" value:@"31,84,86,88"]  // Last,Bid,Ask,Volume
    ];
    request.URL = components.URL;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"IBKRDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Market data request failed with HTTP %ld", (long)httpResponse.statusCode]}];
            completion(nil, httpError);
            return;
        }
        
        // Parse response
        NSError *parseError;
        NSArray *results = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            completion(nil, parseError);
            return;
        }
        
        if (results.count > 0) {
            NSDictionary *marketData = results.firstObject;
            
            // Convert IBKR format to our standard format
            NSDictionary *quote = @{
                @"symbol": symbol,
                @"last": marketData[@"31"] ?: @0,      // Last price
                @"bid": marketData[@"84"] ?: @0,       // Bid
                @"ask": marketData[@"86"] ?: @0,       // Ask
                @"volume": marketData[@"88"] ?: @0,    // Volume
                @"timestamp": [NSDate date]
            };
            
            [self logDebug:@"Received real market data for %@: last=%@", symbol, quote[@"last"]];
            completion(quote, nil);
        } else {
            NSError *noDataError = [NSError errorWithDomain:@"IBKRDataSource"
                                                       code:1006
                                                   userInfo:@{NSLocalizedDescriptionKey: @"No market data returned"}];
            completion(nil, noDataError);
        }
    }];
    
    [task resume];
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
    
    [self logDebug:@"Requesting real historical data for %@", symbol];
    
    // First get the contract ID
    [self searchContract:symbol completion:^(NSNumber *conid, NSError *searchError) {
        if (searchError || !conid) {
            NSError *error = searchError ?: [NSError errorWithDomain:@"IBKRDataSource"
                                                                code:1004
                                                            userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Contract not found for symbol %@", symbol]}];
            if (completion) completion(nil, error);
            return;
        }
        
        // Request historical data
        [self requestHistoricalBars:conid duration:duration barSize:barSize completion:completion];
    }];
}

- (void)requestHistoricalBars:(NSNumber *)conid
                     duration:(NSString *)duration
                      barSize:(NSString *)barSize
                   completion:(void (^)(NSArray * _Nullable bars, NSError * _Nullable error))completion {
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRHistoricalEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    
    // Convert duration and barSize to IBKR format
    NSString *period = [self convertDurationToIBKRFormat:duration];
    NSString *bar = [self convertBarSizeToIBKRFormat:barSize];
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"conid" value:conid.stringValue],
        [NSURLQueryItem queryItemWithName:@"period" value:period],
        [NSURLQueryItem queryItemWithName:@"bar" value:bar]
    ];
    request.URL = components.URL;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"IBKRDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Historical data request failed with HTTP %ld", (long)httpResponse.statusCode]}];
            completion(nil, httpError);
            return;
        }
        
        // Parse response
        NSError *parseError;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            completion(nil, parseError);
            return;
        }
        
        NSArray *dataArray = result[@"data"];
        if (!dataArray) {
            NSError *formatError = [NSError errorWithDomain:@"IBKRDataSource"
                                                       code:1007
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Unexpected historical data format"}];
            completion(nil, formatError);
            return;
        }
        
        // Convert to our standard format
        NSMutableArray *bars = [NSMutableArray array];
        for (NSDictionary *bar in dataArray) {
            NSDictionary *standardBar = @{
                @"date": [NSDate dateWithTimeIntervalSince1970:[bar[@"t"] doubleValue] / 1000.0],
                @"open": bar[@"o"] ?: @0,
                @"high": bar[@"h"] ?: @0,
                @"low": bar[@"l"] ?: @0,
                @"close": bar[@"c"] ?: @0,
                @"volume": bar[@"v"] ?: @0
            };
            [bars addObject:standardBar];
        }
        
        [self logDebug:@"Received %lu real historical bars", (unsigned long)bars.count];
        completion([bars copy], nil);
    }];
    
    [task resume];
}


- (NSString *)convertDurationToIBKRFormat:(NSString *)duration {
    // Convert "1 M" -> "1m", "1 D" -> "1d", etc.
    return [[duration lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
}

- (NSString *)convertBarSizeToIBKRFormat:(NSString *)barSize {
    // Convert "1 day" -> "1d", "1 min" -> "1min", etc.
    NSString *result = [barSize lowercaseString];
    result = [result stringByReplacingOccurrencesOfString:@" " withString:@""];
    result = [result stringByReplacingOccurrencesOfString:@"mins" withString:@"min"];
    result = [result stringByReplacingOccurrencesOfString:@"days" withString:@"d"];
    return result;
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
    
    [self logDebug:@"Requesting real account list"];
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRAccountsEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"IBKRDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Accounts request failed with HTTP %ld", (long)httpResponse.statusCode]}];
            completion(nil, httpError);
            return;
        }
        
        // Parse response
        NSError *parseError;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            completion(nil, parseError);
            return;
        }
        
        NSArray *accounts = result[@"accounts"];
        NSMutableArray *accountIds = [NSMutableArray array];
        
        for (NSDictionary *account in accounts) {
            NSString *accountId = account[@"accountId"];
            if (accountId) {
                [accountIds addObject:accountId];
            }
        }
        
        [self logDebug:@"Found %lu real accounts", (unsigned long)accountIds.count];
        completion([accountIds copy], nil);
    }];
    
    [task resume];
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
    [self logDebug:@"Starting IBKR connection monitoring"];
    
    // Send periodic tickle requests to keep the session alive
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (self.isConnected) {
            [self sendTickle];
            [NSThread sleepForTimeInterval:30.0]; // Tickle every 30 seconds
        }
    });
}

- (void)sendTickle {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRTickleEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self logDebug:@"Tickle failed: %@", error.localizedDescription];
        } else {
            [self logDebug:@"Tickle sent successfully"];
        }
    }];
    
    [task resume];
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


#pragma mark - IBKR API Helper Methods

- (void)checkClientPortalStatus:(void (^)(BOOL isRunning, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRAuthStatusEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.timeoutInterval = 10.0;
    
    // Allow self-signed certificates for localhost
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self logDebug:@"Client Portal check failed: %@", error.localizedDescription];
            completion(NO, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        BOOL isRunning = (httpResponse.statusCode == 200);
        
        [self logDebug:@"Client Portal status check: %@ (status code: %ld)",
         isRunning ? @"Running" : @"Not running", (long)httpResponse.statusCode];
        
        completion(isRunning, nil);
    }];
    
    [task resume];
}

- (void)checkAuthenticationStatus:(void (^)(BOOL isAuthenticated, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRAuthStatusEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(NO, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *httpError = [NSError errorWithDomain:@"IBKRDataSource"
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            completion(NO, httpError);
            return;
        }
        
        // Parse response
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            completion(NO, jsonError);
            return;
        }
        
        // Check if authenticated
        BOOL authenticated = [json[@"authenticated"] boolValue];
        BOOL connected = [json[@"connected"] boolValue];
        
        [self logDebug:@"Auth status - authenticated: %@, connected: %@",
         authenticated ? @"YES" : @"NO", connected ? @"YES" : @"NO"];
        
        completion(authenticated && connected, nil);
    }];
    
    [task resume];
}

#pragma mark - NSURLSessionDelegate (SSL Handling)

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    
    // Allow self-signed certificates for localhost (IBKR Client Portal)
    NSString *host = challenge.protectionSpace.host;
    
    if ([host isEqualToString:@"localhost"] || [host isEqualToString:@"127.0.0.1"]) {
        [self logDebug:@"Accepting self-signed certificate for %@", host];
        
        // Accept the server's certificate
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        // For other hosts, use default handling
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

// ALSO ADD ERROR HANDLING FOR COMMON IBKR ISSUES:

- (NSError *)handleIBKRError:(NSData *)errorData statusCode:(NSInteger)statusCode {
    NSError *parseError;
    NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:errorData options:0 error:&parseError];
    
    NSString *errorMessage;
    if (!parseError && errorDict[@"error"]) {
        errorMessage = errorDict[@"error"];
    } else {
        switch (statusCode) {
            case 401:
                errorMessage = @"Authentication required. Please login to Client Portal web interface";
                break;
            case 500:
                errorMessage = @"IBKR server error. Please check Client Portal status";
                break;
            case 503:
                errorMessage = @"IBKR service unavailable. Please restart Client Portal";
                break;
            default:
                errorMessage = [NSString stringWithFormat:@"IBKR API error (HTTP %ld)", (long)statusCode];
                break;
        }
    }
    
    return [NSError errorWithDomain:@"IBKRDataSource"
                               code:statusCode
                           userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
}

@end
