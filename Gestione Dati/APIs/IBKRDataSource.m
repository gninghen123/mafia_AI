

//
//  IBKRDataSource.m - IMPLEMENTAZIONE UNIFICATA
//  TradingApp
//

#import "IBKRDataSource.h"
#import "CommonTypes.h"
#import "IBKRLoginManager.h"
#import "IBKRWebSocketDataSource.h"  // NEW: Import fallback


// Default connection parameters
static NSString *const kDefaultHost = @"127.0.0.1";
static NSInteger const kDefaultTWSPort = 7497;
static NSInteger const kDefaultGatewayPort = 4002;
static NSInteger const kDefaultClientId = 1;
static NSTimeInterval const kRequestTimeout = 30.0;



// IBKR Client Portal API Base URLs
static NSString *const kIBKRClientPortalBaseURL = @"https://localhost:5001/v1/api";

// API Endpoints
static NSString *const kIBKRAuthStatusEndpoint = @"/iserver/auth/status";
static NSString *const kIBKRMarketDataEndpoint = @"/iserver/marketdata/snapshot";
static NSString *const kIBKRHistoricalEndpoint = @"/iserver/marketdata/history";
static NSString *const kIBKRAccountsEndpoint = @"/iserver/accounts";
static NSString *const kIBKRPortfolioEndpoint = @"/portfolio/accounts";
static NSString *const kIBKRContractSearchEndpoint = @"/iserver/secdef/search";

@interface IBKRDataSource () <NSURLSessionDelegate> {
    NSString *_host;
    NSInteger _port;
    NSInteger _clientId;
    IBKRConnectionType _connectionType;
}

@property (nonatomic, strong) IBKRWebSocketDataSource *fallbackDataSource;
@property (nonatomic, assign) BOOL fallbackEnabled;
@property (nonatomic, assign) BOOL fallbackConnected;

// Protocol properties
@property (nonatomic, readwrite) DataSourceType sourceType;
@property (nonatomic, readwrite) DataSourceCapabilities capabilities;
@property (nonatomic, readwrite) NSString *sourceName;
@property (nonatomic, readwrite) BOOL isConnected;
@property (nonatomic, readwrite) IBKRConnectionStatus connectionStatus;

// Internal components
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *pendingRequests;

@end

@implementation IBKRDataSource

@synthesize sourceType = _sourceType;
@synthesize capabilities = _capabilities;
@synthesize sourceName = _sourceName;
@synthesize isConnected = _isConnected;

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
        _host = host.copy;
        _port = port;
        _clientId = clientId;
        _connectionType = connectionType;
        _connectionStatus = IBKRConnectionStatusDisconnected;
        
        // Protocol properties
        _sourceType = DataSourceTypeIBKR;
        _sourceName = @"Interactive Brokers";
        _capabilities = DataSourceCapabilityQuotes |
                       DataSourceCapabilityHistoricalData |
                       DataSourceCapabilityPortfolioData |
                       DataSourceCapabilityTrading |
                       DataSourceCapabilityLevel2Data |
                       DataSourceCapabilityOptions;
        _isConnected = NO;
        
        // Setup session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = kRequestTimeout;
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
               config.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
               config.HTTPShouldSetCookies = YES;
               
               // ✅ FIX 401: Aggiungi headers di default per IBKR
               config.HTTPAdditionalHeaders = @{
                   @"Accept": @"application/json",
                   @"Content-Type": @"application/json",
                   @"User-Agent": @"TradingApp/1.0",
                   @"X-Requested-With": @"XMLHttpRequest"
               };
        // Setup request tracking
        _pendingRequests = [NSMutableDictionary dictionary];
        
        _fallbackDataSource = [[IBKRWebSocketDataSource alloc] initWithHost:@"127.0.0.1"
                                                                              port:4002
                                                                          clientId:clientId];
               _fallbackEnabled = YES; // Enable by default
               _fallbackConnected = NO;
               
               NSLog(@"🔄 IBKRDataSource: Fallback to TCP Gateway enabled");
    }
    return self;
}

#pragma mark - Property Getters

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

#pragma mark - DataSource Protocol Implementation

- (BOOL)isConnected {
    return _isConnected;
}

// ✅ UNIFICATO: Implementa protocollo standard
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"IBKRDataSource: connectWithCompletion called (unified protocol)");
    
    self.connectionStatus = IBKRConnectionStatusConnecting;
    
    // 🎯 NEW LOGIC: Check if we should use Gateway or Client Portal
    if ([self shouldUseGatewayConnection]) {
        NSLog(@"🚀 IBKRDataSource: Using IB Gateway connection (port %ld)", (long)_port);
        [self connectToGatewayWithCompletion:completion];
    } else {
        NSLog(@"🌐 IBKRDataSource: Using Client Portal connection (port %ld)", (long)_port);
        [self connectToClientPortalWithCompletion:completion];
    }
}

- (BOOL)shouldUseGatewayConnection {
    // Use Gateway connection if:
    // 1. Port is 4002 (standard Gateway port)
    // 2. Port is 7497 (standard TWS port)
    // 3. ConnectionType is explicitly Gateway or TWS
    
    if (_port == 4002 || _port == 7497) {
        NSLog(@"🔍 IBKRDataSource: Port %ld detected → Using Gateway connection", (long)_port);
        return YES;
    }
    
    if (_connectionType == IBKRConnectionTypeGateway || _connectionType == IBKRConnectionTypeTWS) {
        NSLog(@"🔍 IBKRDataSource: Connection type %ld → Using Gateway connection", (long)_connectionType);
        return YES;
    }
    
    NSLog(@"🔍 IBKRDataSource: Port %ld detected → Using Client Portal connection", (long)_port);
    return NO;
}

// ✅ NEW: Gateway connection (TCP native)
- (void)connectToGatewayWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"🔄 IBKRDataSource: Attempting Gateway/TWS connection to %@:%ld", _host, (long)_port);
    
    // For now, use the fallback websocket connection we created
    if (!self.fallbackDataSource) {
        self.fallbackDataSource = [[IBKRWebSocketDataSource alloc] initWithHost:_host
                                                                           port:_port
                                                                       clientId:_clientId];
    }
    
    [self.fallbackDataSource connectWithCompletion:^(BOOL success, NSError *error) {
        if (success) {
            self.connectionStatus = IBKRConnectionStatusConnected;
            self->_isConnected = YES;
            NSLog(@"✅ IBKRDataSource: Gateway connection successful");
        } else {
            self.connectionStatus = IBKRConnectionStatusError;
            self->_isConnected = NO;
            NSLog(@"❌ IBKRDataSource: Gateway connection failed: %@", error.localizedDescription);
        }
        
        if (completion) completion(success, error);
    }];
}

// ✅ EXISTING: Client Portal connection (REST)
- (void)connectToClientPortalWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSLog(@"🔄 IBKRDataSource: Attempting Client Portal connection");
    
    // Use existing Client Portal logic
    IBKRLoginManager *loginManager = [IBKRLoginManager sharedManager];
    
    [loginManager ensureClientPortalReadyWithCompletion:^(BOOL ready, NSError *error) {
        if (ready) {
            self.connectionStatus = IBKRConnectionStatusAuthenticated;
            self->_isConnected = YES;
            NSLog(@"✅ IBKRDataSource: Client Portal connection successful");
            
            if (completion) completion(YES, nil);
        } else {
            self.connectionStatus = IBKRConnectionStatusError;
            self->_isConnected = NO;
            NSLog(@"❌ IBKRDataSource: Client Portal connection failed: %@", error.localizedDescription);
            
            if (completion) completion(NO, error);
        }
    }];
}



- (void)disconnect {
    [self.session invalidateAndCancel];
    self.connectionStatus = IBKRConnectionStatusDisconnected;
    self->_isConnected = NO;
    [self.pendingRequests removeAllObjects];
}

#pragma mark - Market Data - UNIFIED PROTOCOL

// ✅ UNIFICATO: Single quote (AGGIUNTO)
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // Prima trova il contract ID
    [self searchContract:symbol completion:^(NSNumber *conid, NSError *searchError) {
        if (searchError || !conid) {
            NSError *error = searchError ?: [NSError errorWithDomain:@"IBKRDataSource"
                                                                code:1004
                                                            userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Contract not found for symbol %@", symbol]}];
            if (completion) completion(nil, error);
            return;
        }
        
        // Request market data snapshot
        [self requestMarketDataSnapshot:conid completion:^(id rawQuote, NSError *error) {
            // ✅ RITORNA DATI RAW IBKR
            if (completion) completion(rawQuote, error);
        }];
    }];
}

// ✅ UNIFICATO: Batch quotes (AGGIUNTO)
- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion {
    
    // IBKR può fare batch con conids multipli, ma per ora facciamo requests individuali
    NSMutableDictionary *allQuotes = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    __block NSError *firstError = nil;
    
    for (NSString *symbol in symbols) {
        dispatch_group_enter(group);
        
        [self fetchQuoteForSymbol:symbol completion:^(id quote, NSError *error) {
            @synchronized(allQuotes) {
                if (error && !firstError) {
                    firstError = error;
                } else if (quote) {
                    allQuotes[symbol] = quote;
                }
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([allQuotes copy], firstError);
        });
    });
}

#pragma mark - Historical Data - UNIFIED PROTOCOL

// ✅ UNIFICATO: Historical data con date range (AGGIUNTO)
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // Converti al formato IBKR
    NSString *duration = [self calculateDurationForStartDate:startDate endDate:endDate];
    NSString *barSize = [self barSizeStringForTimeframe:timeframe];
    
    [self searchContract:symbol completion:^(NSNumber *conid, NSError *searchError) {
        if (searchError || !conid) {
            NSError *error = searchError ?: [NSError errorWithDomain:@"IBKRDataSource"
                                                                code:1004
                                                            userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Contract not found for symbol %@", symbol]}];
            if (completion) completion(nil, error);
            return;
        }
        
        [self requestHistoricalBars:conid
                           duration:duration
                            barSize:barSize
                   needExtendedHours:needExtendedHours
                         completion:^(id rawBars, NSError *error) {
            // ✅ RITORNA DATI RAW IBKR
            if (completion) completion(rawBars, error);
        }];
    }];
}

// ✅ UNIFICATO: Historical data con bar count (AGGIUNTO)
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion {
    
    // Calcola duration dal bar count richiesto
    NSString *duration = [self durationStringForBarCount:barCount timeframe:timeframe];
    NSString *barSize = [self barSizeStringForTimeframe:timeframe];
    
    // Usa il metodo base con date range calcolate
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self calculateStartDateForBarCount:barCount timeframe:timeframe fromDate:endDate];
    
    [self fetchHistoricalDataForSymbol:symbol
                             timeframe:timeframe
                             startDate:startDate
                               endDate:endDate
                     needExtendedHours:needExtendedHours
                            completion:completion];
}

#pragma mark - Portfolio Data - UNIFIED PROTOCOL

- (void)tryRESTAccountsCall:(void (^)(NSArray *accounts, NSError *error))completion {
    // Use IBKRLoginManager to ensure portal ready
    [[IBKRLoginManager sharedManager] ensureClientPortalReadyWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"❌ Client Portal not ready: %@", error.localizedDescription);
            if (completion) completion(@[], error);
            return;
        }
        
        // Make the actual REST call
        NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, @"/iserver/accounts"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = @"GET";
        [self configureRequestHeaders:request];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                NSArray *accounts = @[];
                if ([result isKindOfClass:[NSArray class]]) {
                    accounts = (NSArray *)result;
                }
                if (completion) completion(accounts, error);
            }];
        }];
        
        [task resume];
    }];
}


- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion {
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(@[], error);
        return;
    }
    
    // 🎯 SMART ROUTING: Check if we're using Gateway connection
    if ([self shouldUseGatewayConnection] && self.fallbackDataSource && self.fallbackDataSource.isConnected) {
        NSLog(@"📡 IBKRDataSource: Fetching accounts via Gateway (TCP primary)...");
        
        // Use TCP directly - no REST attempt
        [self.fallbackDataSource fetchAccountsWithCompletion:completion];
        
    } else {
        NSLog(@"📡 IBKRDataSource: Fetching accounts via Client Portal (REST primary)...");
        
        // Use existing REST with TCP fallback logic
        [self tryRESTAccountsCall:^(NSArray *accounts, NSError *error) {
            if ([self shouldUseFallback:error]) {
                NSLog(@"🔄 IBKRDataSource: REST auth failed, trying TCP fallback...");
                
                [self ensureFallbackConnectedWithCompletion:^(BOOL connected) {
                    if (connected) {
                        [self.fallbackDataSource fetchAccountsWithCompletion:^(NSArray *fallbackAccounts, NSError *fallbackError) {
                            if (fallbackError) {
                                NSLog(@"❌ IBKRDataSource: Both REST and TCP failed for accounts");
                            } else {
                                NSLog(@"✅ IBKRDataSource: Accounts retrieved via TCP fallback");
                            }
                            if (completion) completion(fallbackAccounts, fallbackError);
                        }];
                    } else {
                        NSLog(@"❌ IBKRDataSource: TCP fallback not available");
                        if (completion) completion(@[], error);
                    }
                }];
            } else {
                if (completion) completion(accounts, error);
            }
        }];
    }
}

// ✅ UNIFICATO: Account details (AGGIUNTO)
- (void)fetchAccountDetails:(NSString *)accountId
                 completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@/%@",
                          kIBKRClientPortalBaseURL, kIBKRAccountsEndpoint, accountId];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"GET";
    [self configureRequestHeaders:request];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
            // ✅ RITORNA DATI RAW IBKR account details
            if (completion) completion(result, error);
        }];
    }];
    
    [task resume];
}

// ✅ UNIFICATO: Positions (era getPositions)
- (void)fetchPositionsForAccount:(NSString *)accountId
                      completion:(void (^)(NSArray *positions, NSError *error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(@[], error);
        return;
    }
    
    // 🎯 SMART ROUTING: Check connection method
    if ([self shouldUseGatewayConnection] && self.fallbackDataSource && self.fallbackDataSource.isConnected) {
        NSLog(@"📡 IBKRDataSource: Fetching positions via Gateway (TCP primary)...");
        
        // Use TCP directly
        [self.fallbackDataSource fetchPositionsForAccount:accountId completion:completion];
        
    } else {
        NSLog(@"📡 IBKRDataSource: Fetching positions via Client Portal (REST primary)...");
        
        // Use existing REST with fallback logic
        [self tryRESTPositionsCall:accountId completion:^(NSArray *positions, NSError *error) {
            if ([self shouldUseFallback:error]) {
                NSLog(@"🔄 IBKRDataSource: REST auth failed, trying TCP fallback...");
                
                [self ensureFallbackConnectedWithCompletion:^(BOOL connected) {
                    if (connected) {
                        [self.fallbackDataSource fetchPositionsForAccount:accountId completion:^(NSArray *fallbackPositions, NSError *fallbackError) {
                            if (fallbackError) {
                                NSLog(@"❌ IBKRDataSource: Both REST and TCP failed for positions");
                            } else {
                                NSLog(@"✅ IBKRDataSource: Positions retrieved via TCP fallback");
                            }
                            if (completion) completion(fallbackPositions, fallbackError);
                        }];
                    } else {
                        NSLog(@"❌ IBKRDataSource: TCP fallback not available");
                        if (completion) completion(@[], error);
                    }
                }];
            } else {
                if (completion) completion(positions, error);
            }
        }];
    }
}


- (void)tryRESTPositionsCall:(NSString *)accountId completion:(void (^)(NSArray *positions, NSError *error))completion {
    [[IBKRLoginManager sharedManager] ensureClientPortalReadyWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/portfolio/accounts/%@/positions", kIBKRClientPortalBaseURL, accountId];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = @"GET";
        [self configureRequestHeaders:request];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                NSArray *positions = @[];
                if ([result isKindOfClass:[NSArray class]]) {
                    positions = (NSArray *)result;
                }
                if (completion) completion(positions, error);
            }];
        }];
        
        [task resume];
    }];
}


// ✅ UNIFICATO: Orders (era getOrders)
- (void)fetchOrdersForAccount:(NSString *)accountId
                   completion:(void (^)(NSArray *orders, NSError *error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(@[], error);
        return;
    }
    
    // 🎯 SMART ROUTING: Check connection method
    if ([self shouldUseGatewayConnection] && self.fallbackDataSource && self.fallbackDataSource.isConnected) {
        NSLog(@"📡 IBKRDataSource: Fetching orders via Gateway (TCP primary)...");
        
        // Use TCP directly
        [self.fallbackDataSource fetchOrdersForAccount:accountId completion:completion];
        
    } else {
        NSLog(@"📡 IBKRDataSource: Fetching orders via Client Portal (REST primary)...");
        
        // Use existing REST with fallback logic
        [self tryRESTOrdersCall:accountId completion:^(NSArray *orders, NSError *error) {
            if ([self shouldUseFallback:error]) {
                NSLog(@"🔄 IBKRDataSource: REST auth failed, trying TCP fallback...");
                
                [self ensureFallbackConnectedWithCompletion:^(BOOL connected) {
                    if (connected) {
                        [self.fallbackDataSource fetchOrdersForAccount:accountId completion:^(NSArray *fallbackOrders, NSError *fallbackError) {
                            if (fallbackError) {
                                NSLog(@"❌ IBKRDataSource: Both REST and TCP failed for orders");
                            } else {
                                NSLog(@"✅ IBKRDataSource: Orders retrieved via TCP fallback");
                            }
                            if (completion) completion(fallbackOrders, fallbackError);
                        }];
                    } else {
                        NSLog(@"❌ IBKRDataSource: TCP fallback not available");
                        if (completion) completion(@[], error);
                    }
                }];
            } else {
                if (completion) completion(orders, error);
            }
        }];
    }
}



- (void)tryRESTOrdersCall:(NSString *)accountId completion:(void (^)(NSArray *orders, NSError *error))completion {
    [[IBKRLoginManager sharedManager] ensureClientPortalReadyWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/iserver/account/orders", kIBKRClientPortalBaseURL];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = @"GET";
        [self configureRequestHeaders:request];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
                NSArray *orders = @[];
                if ([result isKindOfClass:[NSArray class]]) {
                    orders = (NSArray *)result;
                }
                if (completion) completion(orders, error);
            }];
        }];
        
        [task resume];
    }];
}
#pragma mark - Trading Operations - UNIFIED PROTOCOL

// ✅ UNIFICATO: Place order
- (void)placeOrderForAccount:(NSString *)accountId
                   orderData:(NSDictionary *)orderData
                  completion:(void (^)(NSString *orderId, NSError *error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/iserver/account/%@/orders",
                          kIBKRClientPortalBaseURL, accountId];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [self configureRequestHeaders:request];

    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:orderData options:0 error:&jsonError];
    if (jsonError) {
        if (completion) completion(nil, jsonError);
        return;
    }
    request.HTTPBody = jsonData;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handlePlaceOrderResponse:data response:response error:error completion:completion];
    }];
    
    [task resume];
}

// ✅ UNIFICATO: Cancel order
- (void)cancelOrderForAccount:(NSString *)accountId
                      orderId:(NSString *)orderId
                   completion:(void (^)(BOOL success, NSError *error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(NO, error);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/iserver/account/%@/order/%@",
                          kIBKRClientPortalBaseURL, accountId, orderId];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"DELETE";
    [self configureRequestHeaders:request];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleCancelOrderResponse:data response:response error:error completion:completion];
    }];
    
    [task resume];
}

#pragma mark - Internal Helper Methods

- (void)searchContract:(NSString *)symbol completion:(void (^)(NSNumber *conid, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRContractSearchEndpoint];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [self configureRequestHeaders:request];

    NSDictionary *searchBody = @{
        @"symbol": symbol,
        @"name": @"true",
        @"secType": @"STK"
    };
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:searchBody options:0 error:&jsonError];
    if (jsonError) {
        if (completion) completion(nil, jsonError);
        return;
    }
    request.HTTPBody = jsonData;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleContractSearchResponse:data response:response error:error symbol:symbol completion:completion];
    }];
    
    [task resume];
}

- (void)requestMarketDataSnapshot:(NSNumber *)conid completion:(void (^)(id rawQuote, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRMarketDataEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [self configureRequestHeaders:request];

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"conids" value:conid.stringValue],
        [NSURLQueryItem queryItemWithName:@"fields" value:@"31,84,86,88"]  // Last,Bid,Ask,Volume
    ];
    request.URL = components.URL;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleMarketDataResponse:data response:response error:error conid:conid completion:completion];
    }];
    
    [task resume];
}

- (void)requestHistoricalBars:(NSNumber *)conid
                     duration:(NSString *)duration
                      barSize:(NSString *)barSize
             needExtendedHours:(BOOL)needExtendedHours
                   completion:(void (^)(id rawBars, NSError *error))completion {
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRHistoricalEndpoint];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"GET";
    [self configureRequestHeaders:request];

    NSURLComponents *components = [NSURLComponents componentsWithURL:[NSURL URLWithString:urlString] resolvingAgainstBaseURL:NO];
    NSMutableArray *queryItems = [NSMutableArray array];
    
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"conid" value:conid.stringValue]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"period" value:duration]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"bar" value:barSize]];
    
    if (needExtendedHours) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"outsideRth" value:@"true"]];
    }
    
    components.queryItems = queryItems;
    request.URL = components.URL;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
            // ✅ RITORNA DATI RAW IBKR historical bars
            if (completion) completion(result, error);
        }];
    }];
    
    [task resume];
}

#pragma mark - Response Handlers

- (void)handleGenericResponse:(NSData *)data
                     response:(NSURLResponse *)response
                        error:(NSError *)error
                   completion:(void (^)(id result, NSError *error))completion {
    
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        NSError *httpError = [NSError errorWithDomain:@"IBKRDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, httpError);
        });
        return;
    }
    
    NSError *parseError;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    
    if (parseError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, parseError);
        });
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(json, nil);
    });
}

- (void)handleContractSearchResponse:(NSData *)data
                            response:(NSURLResponse *)response
                               error:(NSError *)error
                              symbol:(NSString *)symbol
                          completion:(void (^)(NSNumber *conid, NSError *error))completion {
    
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
        return;
    }
    
    NSError *parseError;
    NSArray *results = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    
    if (parseError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, parseError);
        });
        return;
    }
    
    // Trova il conid dal primo risultato
    if (results.count > 0) {
        NSDictionary *contract = results.firstObject;
        NSNumber *conid = contract[@"conid"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(conid, nil);
        });
    } else {
        NSError *notFoundError = [NSError errorWithDomain:@"IBKRDataSource"
                                                     code:1004
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Contract not found for symbol %@", symbol]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, notFoundError);
        });
    }
}

- (void)handleMarketDataResponse:(NSData *)data
                        response:(NSURLResponse *)response
                           error:(NSError *)error
                           conid:(NSNumber *)conid
                      completion:(void (^)(id rawQuote, NSError *error))completion {
    
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
        return;
    }
    
    NSError *parseError;
    NSArray *results = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    
    if (parseError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, parseError);
        });
        return;
    }
    
    if (results.count > 0) {
        NSDictionary *marketData = results.firstObject;
        
        // ✅ RITORNA DATI RAW IBKR con field codes originali
        NSDictionary *rawQuote = @{
            @"conid": conid,
            @"31": marketData[@"31"] ?: @0,  // Last price
            @"84": marketData[@"84"] ?: @0,  // Bid
            @"86": marketData[@"86"] ?: @0,  // Ask
            @"88": marketData[@"88"] ?: @0,  // Volume
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(rawQuote, nil);
        });
    } else {
        NSError *noDataError = [NSError errorWithDomain:@"IBKRDataSource"
                                                   code:1006
                                               userInfo:@{NSLocalizedDescriptionKey: @"No market data returned"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, noDataError);
        });
    }
}

- (void)handlePlaceOrderResponse:(NSData *)data
                        response:(NSURLResponse *)response
                           error:(NSError *)error
                      completion:(void (^)(NSString *orderId, NSError *error))completion {
    
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
        NSError *parseError;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        
        if (parseError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, parseError);
            });
            return;
        }
        
        NSString *orderId = result[@"orderId"] ?: result[@"id"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(orderId, nil);
        });
    } else {
        NSError *httpError = [NSError errorWithDomain:@"IBKRDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, httpError);
        });
    }
}

- (void)handleCancelOrderResponse:(NSData *)data
                         response:(NSURLResponse *)response
                            error:(NSError *)error
                       completion:(void (^)(BOOL success, NSError *error))completion {
    
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, error);
        });
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    BOOL success = (httpResponse.statusCode == 200 || httpResponse.statusCode == 204);
    
    if (!success) {
        NSError *httpError = [NSError errorWithDomain:@"IBKRDataSource"
                                                 code:httpResponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Error %ld", (long)httpResponse.statusCode]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, httpError);
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(YES, nil);
        });
    }
}

#pragma mark - IBKR Helper Methods

- (NSString *)barSizeStringForTimeframe:(BarTimeframe)timeframe {
    // ✅ MAPPATURA IBKR bar sizes
    switch (timeframe) {
        case BarTimeframe1Min:     return @"1 min";
        case BarTimeframe5Min:     return @"5 mins";
        case BarTimeframe15Min:    return @"15 mins";
        case BarTimeframe30Min:    return @"30 mins";
        case BarTimeframe1Hour:    return @"1 hour";
        case BarTimeframeDaily:    return @"1 day";
        case BarTimeframeWeekly:   return @"1 week";
        case BarTimeframeMonthly:  return @"1 month";
        default:                   return @"1 day";
    }
}

- (NSString *)durationStringForBarCount:(NSInteger)barCount timeframe:(BarTimeframe)timeframe {
    // ✅ LOGICA INTELLIGENTE per convertire barCount in duration IBKR
    
    if (timeframe < BarTimeframeDaily) {
        // Intraday: calcola giorni necessari
        NSInteger barsPerDay = [self barsPerDayForTimeframe:timeframe];
        NSInteger daysNeeded = MAX(1, (barCount + barsPerDay - 1) / barsPerDay);
        
        if (daysNeeded <= 1) return @"1 D";
        if (daysNeeded <= 7) return @"1 W";
        if (daysNeeded <= 30) return @"1 M";
        if (daysNeeded <= 365) return @"1 Y";
        return @"2 Y";
    } else {
        // Daily e superiori
        switch (timeframe) {
            case BarTimeframeDaily:
                if (barCount <= 7) return @"1 W";
                if (barCount <= 30) return @"1 M";
                if (barCount <= 90) return @"3 M";
                if (barCount <= 180) return @"6 M";
                if (barCount <= 365) return @"1 Y";
                return @"2 Y";
                
            case BarTimeframeWeekly:
                if (barCount <= 4) return @"1 M";
                if (barCount <= 12) return @"3 M";
                if (barCount <= 26) return @"6 M";
                if (barCount <= 52) return @"1 Y";
                return @"2 Y";
                
            case BarTimeframeMonthly:
                if (barCount <= 3) return @"3 M";
                if (barCount <= 6) return @"6 M";
                if (barCount <= 12) return @"1 Y";
                return @"2 Y";
                
            default:
                return @"1 Y";
        }
    }
}

- (NSInteger)barsPerDayForTimeframe:(BarTimeframe)timeframe {
    // IBKR trading hours: ~6.5 hours per day (9:30-16:00 EST)
    switch (timeframe) {
        case BarTimeframe1Min:     return 390;  // 6.5 * 60
        case BarTimeframe5Min:     return 78;   // 390 / 5
        case BarTimeframe15Min:    return 26;   // 390 / 15
        case BarTimeframe30Min:    return 13;   // 390 / 30
        case BarTimeframe1Hour:    return 6;    // 390 / 60
        default:                   return 1;
    }
}

- (NSString *)calculateDurationForStartDate:(NSDate *)startDate endDate:(NSDate *)endDate {
    NSTimeInterval interval = [endDate timeIntervalSinceDate:startDate];
    NSInteger days = (NSInteger)(interval / 86400);
    
    if (days <= 1) return @"1 D";
    if (days <= 7) return @"1 W";
    if (days <= 30) return @"1 M";
    if (days <= 90) return @"3 M";
    if (days <= 180) return @"6 M";
    if (days <= 365) return @"1 Y";
    return @"2 Y";
}

- (NSDate *)calculateStartDateForBarCount:(NSInteger)barCount
                                timeframe:(BarTimeframe)timeframe
                                 fromDate:(NSDate *)endDate {
    
    NSTimeInterval interval = 0;
    
    switch (timeframe) {
        case BarTimeframe1Min:     interval = 60; break;
        case BarTimeframe5Min:     interval = 300; break;
        case BarTimeframe15Min:    interval = 900; break;
        case BarTimeframe30Min:    interval = 1800; break;
        case BarTimeframe1Hour:    interval = 3600; break;
        case BarTimeframeDaily:    interval = 86400; break;
        case BarTimeframeWeekly:   interval = 604800; break;
        case BarTimeframeMonthly:  interval = 2592000; break;
        default:                   interval = 86400; break;
    }
    
    // Per intraday, aggiungi buffer per weekends
    NSTimeInterval totalInterval = interval * barCount;
    if (timeframe < BarTimeframeDaily) {
        totalInterval *= 1.5; // 50% buffer per weekends
    }
    
    return [endDate dateByAddingTimeInterval:-totalInterval];
}

// Token management (mantiene implementazioni esistenti dal repository)
- (void)loadTokensFromUserDefaults {
    // [MANTIENE implementazione esistente]
}

- (void)saveTokensToUserDefaults {
    // [MANTIENE implementazione esistente]
}

- (void)clearTokensFromUserDefaults {
    // [MANTIENE implementazione esistente]
}

- (void)authenticateWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    // [MANTIENE implementazione esistente OAuth2]
}

- (void)refreshTokenIfNeeded:(void (^)(BOOL success, NSError *error))completion {
    // [MANTIENE implementazione esistente]
}

- (BOOL)hasValidToken {
    // [MANTIENE implementazione esistente]
    return NO; // Placeholder
}



#pragma mark - NSURLSessionDelegate (SSL Handling)

// Accetta il certificato self-signed solo per localhost
- (void)URLSession:(NSURLSession *)session
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {

    // Controlla che sia localhost
    if ([challenge.protectionSpace.host isEqualToString:@"localhost"]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        // Comportamento di default per altri host
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}


- (void)configureRequestHeaders:(NSMutableURLRequest *)request {
    // 🍪 SESSIONE: Cookie esistente (già implementato)
    IBKRLoginManager *loginManager = [IBKRLoginManager sharedManager];
    NSString *sessionCookie = [loginManager sessionCookie];
    if (sessionCookie && sessionCookie.length > 0) {
        NSString *cookieValue = [NSString stringWithFormat:@"x-sess-uuid=%@", sessionCookie];
        [request setValue:cookieValue forHTTPHeaderField:@"Cookie"];
        NSLog(@"🍪 IBKRDataSource: Adding session cookie to request");
    } else {
        NSLog(@"⚠️ IBKRDataSource: No session cookie available - questo causerà 401!");
    }
    
    // ✅ FIX: Headers CRITICI per IBKR REST API
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"XMLHttpRequest" forHTTPHeaderField:@"X-Requested-With"];
    
    // 🔥 MANCAVANO QUESTI headers critici per auth:
    [request setValue:@"cors" forHTTPHeaderField:@"Sec-Fetch-Mode"];
    [request setValue:@"same-origin" forHTTPHeaderField:@"Sec-Fetch-Site"];
    [request setValue:@"empty" forHTTPHeaderField:@"Sec-Fetch-Dest"];
    
    // 🌍 REFERRER header (importante per IBKR)
    NSString *referer = [NSString stringWithFormat:@"https://localhost:%ld/", (long)loginManager.port];
    [request setValue:referer forHTTPHeaderField:@"Referer"];
    
    // 🎭 USER AGENT specifico per IBKR
    [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
       forHTTPHeaderField:@"User-Agent"];
    
    // ⚡ IBKR specifici headers
    [request setValue:@"1" forHTTPHeaderField:@"X-Force-Auth"];
    
    // 🔒 CACHE control per requests authenticated
    [request setValue:@"no-cache, no-store, must-revalidate" forHTTPHeaderField:@"Cache-Control"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Pragma"];
    
    NSLog(@"🔧 IBKRDataSource: Configured all authentication headers for %@", request.URL.path);
}

// ✅ AGGIUNTA: Method per verificare se abbiamo tutti gli headers necessari
- (BOOL)validateAuthenticationHeaders:(NSURLRequest *)request {
    NSDictionary *headers = request.allHTTPHeaderFields;
    
    NSArray *requiredHeaders = @[
        @"Cookie",           // Session cookie
        @"X-Requested-With", // CSRF protection
        @"Referer",          // Origin validation
        @"User-Agent"        // Browser simulation
    ];
    
    for (NSString *headerName in requiredHeaders) {
        if (!headers[headerName] || [headers[headerName] length] == 0) {
            NSLog(@"❌ MISSING HEADER: %@ - questo causerà 401!", headerName);
            return NO;
        }
    }
    
    NSLog(@"✅ All authentication headers present");
    return YES;
}

#pragma mark - Fallback Management

- (void)ensureFallbackConnectedWithCompletion:(void (^)(BOOL connected))completion {
    if (self.fallbackConnected) {
        if (completion) completion(YES);
        return;
    }
    
    [self.fallbackDataSource connectWithCompletion:^(BOOL success, NSError *error) {
        self.fallbackConnected = success;
        if (success) {
            NSLog(@"✅ IBKRDataSource: TCP fallback connected to Gateway");
        } else {
            NSLog(@"❌ IBKRDataSource: TCP fallback failed: %@", error.localizedDescription);
        }
        if (completion) completion(success);
    }];
}

- (BOOL)isAuthenticationError:(NSError *)error {
    if (!error) return NO;
    
    // Check for common auth error patterns
    if (error.code == 401) return YES; // HTTP Unauthorized
    
    NSString *description = error.localizedDescription.lowercaseString;
    return [description containsString:@"unauthorized"] ||
           [description containsString:@"authentication"] ||
           [description containsString:@"session"] ||
           [description containsString:@"cookie"];
}

- (BOOL)shouldUseFallback:(NSError *)error {
    return self.fallbackEnabled && [self isAuthenticationError:error];
}


#pragma mark - Debug & Control Methods

- (void)enableFallback:(BOOL)enabled {
    self.fallbackEnabled = enabled;
    NSLog(@"🔄 IBKRDataSource: TCP fallback %@", enabled ? @"ENABLED" : @"DISABLED");
}

- (void)forceFallbackConnection {
    NSLog(@"🔄 IBKRDataSource: Force connecting TCP fallback...");
    [self ensureFallbackConnectedWithCompletion:^(BOOL connected) {
        NSLog(@"🔄 IBKRDataSource: Force fallback result: %@", connected ? @"SUCCESS" : @"FAILED");
    }];
}

- (void)debugFallbackStatus {
    NSLog(@"🔍 IBKRDataSource Fallback Status:");
    NSLog(@"   Fallback enabled: %@", self.fallbackEnabled ? @"YES" : @"NO");
    NSLog(@"   Fallback connected: %@", self.fallbackConnected ? @"YES" : @"NO");
    NSLog(@"   Fallback datasource: %@", self.fallbackDataSource ? @"INITIALIZED" : @"NIL");
}

#pragma mark - Deallocation

- (void)dealloc {
    [self.fallbackDataSource disconnect];
}


@end
