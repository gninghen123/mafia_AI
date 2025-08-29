

//
//  IBKRDataSource.m - IMPLEMENTAZIONE UNIFICATA
//  TradingApp
//

#import "IBKRDataSource.h"
#import "CommonTypes.h"
#import "IBKRLoginManager.h"

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
        
        // Setup request tracking
        _pendingRequests = [NSMutableDictionary dictionary];
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
    
    // Usa IBKRLoginManager per gestire Client Portal
    IBKRLoginManager *loginManager = [IBKRLoginManager sharedManager];
    
    [loginManager ensureClientPortalReadyWithCompletion:^(BOOL ready, NSError *error) {
        if (ready) {
            self.connectionStatus = IBKRConnectionStatusAuthenticated;
            self->_isConnected = YES;
            
            if (completion) completion(YES, nil);
        } else {
            self.connectionStatus = IBKRConnectionStatusError;
            self->_isConnected = NO;
            
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

// ✅ UNIFICATO: Accounts (era getAccountsWithCompletion)
- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to IBKR"}];
        if (completion) completion(@[], error);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kIBKRClientPortalBaseURL, kIBKRAccountsEndpoint];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"GET";
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
            if (error) {
                if (completion) completion(@[], error);
            } else {
                // ✅ RITORNA DATI RAW IBKR accounts
                NSArray *accounts = @[];
                if ([result isKindOfClass:[NSArray class]]) {
                    accounts = (NSArray *)result;
                } else if ([result isKindOfClass:[NSDictionary class]]) {
                    accounts = @[result];
                }
                
                if (completion) completion(accounts, nil);
            }
        }];
    }];
    
    [task resume];
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
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@/%@/positions",
                          kIBKRClientPortalBaseURL, kIBKRPortfolioEndpoint, accountId];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"GET";
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
            // ✅ RITORNA DATI RAW IBKR positions
            NSArray *positions = @[];
            if ([result isKindOfClass:[NSArray class]]) {
                positions = (NSArray *)result;
            }
            
            if (completion) completion(positions, error);
        }];
    }];
    
    [task resume];
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
    
    NSString *urlString = [NSString stringWithFormat:@"%@/iserver/account/orders", kIBKRClientPortalBaseURL];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"GET";
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleGenericResponse:data response:response error:error completion:^(id result, NSError *error) {
            // ✅ RITORNA DATI RAW IBKR orders
            NSArray *orders = @[];
            if ([result isKindOfClass:[NSArray class]]) {
                orders = (NSArray *)result;
            }
            
            if (completion) completion(orders, error);
        }];
    }];
    
    [task resume];
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


#pragma mark - bypass ssl security for localhost

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

@end
