//
//  DataManager+Portfolio.m (COMPLETE - NEW ARCHITECTURE)
//  TradingApp
//
//  🛡️ ACCOUNT DATA: Methods require specific DataSource parameter (NO internal determination)
//  🚨 TRADING: Methods require specific DataSource parameter (NEVER fallback)
//
//  Implementation of portfolio and account management for DataManager
//

#import "DataManager+Portfolio.h"
#import "DownloadManager.h"
#import "DataAdapterFactory.h"

@implementation DataManager (Portfolio)

#pragma mark - Account Management

- (NSString *)requestAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *error))completion {
    if (!completion) {
        NSLog(@"⚠️ DataManager+Portfolio: No completion block provided for accounts request");
        return nil;
    }
    
    NSLog(@"📱 DataManager: Requesting accounts from all connected brokers");
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"accounts",
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // 🛡️ ORCHESTRATION: Get accounts from each connected broker individually
    // DataManager orchestrates multiple broker calls since UI requested "all accounts"
    [self requestAccountsFromAllBrokersWithRequestID:requestID completion:completion];
    
    return requestID;
}

- (void)requestAccountsFromAllBrokersWithRequestID:(NSString *)requestID
                                        completion:(void (^)(NSArray *accounts, NSError *error))completion {
    
    NSMutableArray *allAccounts = [NSMutableArray array];
    NSMutableArray *errors = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    
    // List of brokers to check
    NSArray *brokerTypes = @[@(DataSourceTypeSchwab), @(DataSourceTypeIBKR), @(DataSourceTypeWebull)];
    
    for (NSNumber *brokerTypeNum in brokerTypes) {
        DataSourceType brokerType = [brokerTypeNum integerValue];
        
        // Check if broker is connected
        if (![[DownloadManager sharedManager] isDataSourceConnected:brokerType]) {
            NSLog(@"⚠️ DataManager: Broker %@ is not connected, skipping", DataSourceTypeToString(brokerType));
            continue;
        }
        
        dispatch_group_enter(group);
        
        NSLog(@"🛡️ DataManager: Requesting accounts from broker %@", DataSourceTypeToString(brokerType));
        
        // 🛡️ SECURITY: Use secure account data request with specific broker
        [[DownloadManager sharedManager] executeAccountDataRequest:DataRequestTypeAccounts
                                                        parameters:@{} // No account ID needed for accounts list
                                                    requiredSource:brokerType
                                                        completion:^(id result, DataSourceType usedSource, NSError *error) {
            if (error) {
                NSLog(@"❌ DataManager: Failed to get accounts from broker %@: %@", DataSourceTypeToString(brokerType), error.localizedDescription);
                [errors addObject:error];
            } else {
                // Standardize accounts from this broker
                NSArray *brokerAccounts = [self standardizeAccountsData:result fromSource:usedSource];
                if (brokerAccounts.count > 0) {
                    [allAccounts addObjectsFromArray:brokerAccounts];
                    NSLog(@"✅ DataManager: Got %lu accounts from broker %@", (unsigned long)brokerAccounts.count, DataSourceTypeToString(brokerType));
                }
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self removeValueForKey:requestID fromActiveRequests:YES];
        
        if (allAccounts.count == 0 && errors.count > 0) {
            // All brokers failed
            NSError *combinedError = [NSError errorWithDomain:@"DataManager"
                                                         code:500
                                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to get accounts from all brokers"}];
            completion(nil, combinedError);
        } else {
            NSLog(@"✅ DataManager: Total accounts retrieved: %lu", (unsigned long)allAccounts.count);
            completion([allAccounts copy], nil);
        }
    });
}

- (NSString *)requestAccountDetails:(NSString *)accountId
                     fromDataSource:(DataSourceType)requiredSource
                         completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion {
    if (!accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:201
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid account ID"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"🛡️ DataManager: Requesting account details for %@ from broker %@", accountId, DataSourceTypeToString(requiredSource));
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"accountDetails",
        @"accountId": accountId,
        @"requiredSource": @(requiredSource),
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // 🛡️ SECURITY: Use secure account data request with DataSource provided by caller
    [[DownloadManager sharedManager] executeAccountDataRequest:DataRequestTypeAccountInfo
                                                    parameters:@{@"accountId": accountId}
                                                requiredSource:requiredSource
                                                    completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleAccountDetailsResponse:result
                                     error:error
                                usedSource:usedSource
                                 accountId:accountId
                                 requestID:requestID
                                completion:completion];
    }];
    
    return requestID;
}

#pragma mark - Portfolio Data Requests

- (NSString *)requestPortfolioSummary:(NSString *)accountId
                       fromDataSource:(DataSourceType)requiredSource
                           completion:(void (^)(NSDictionary *summary, NSError *error))completion {
    if (!accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:202
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid account ID for portfolio summary"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"🛡️ DataManager: Requesting portfolio summary for account %@ from broker %@", accountId, DataSourceTypeToString(requiredSource));
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"portfolioSummary",
        @"accountId": accountId,
        @"requiredSource": @(requiredSource),
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // 🛡️ SECURITY: Use secure account data request with DataSource provided by caller
    [[DownloadManager sharedManager] executeAccountDataRequest:DataRequestTypeAccountInfo
                                                    parameters:@{@"accountId": accountId, @"type": @"summary"}
                                                requiredSource:requiredSource
                                                    completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handlePortfolioSummaryResponse:result
                                       error:error
                                  usedSource:usedSource
                                   accountId:accountId
                                   requestID:requestID
                                  completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestPositions:(NSString *)accountId
                fromDataSource:(DataSourceType)requiredSource
                    completion:(void (^)(NSArray *positions, NSError *error))completion {
    if (!accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:203
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid account ID for positions request"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"🛡️ DataManager: Requesting positions for account %@ from broker %@", accountId, DataSourceTypeToString(requiredSource));
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"positions",
        @"accountId": accountId,
        @"requiredSource": @(requiredSource),
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // 🛡️ SECURITY: Use secure account data request with DataSource provided by caller
    [[DownloadManager sharedManager] executeAccountDataRequest:DataRequestTypePositions
                                                    parameters:@{@"accountId": accountId}
                                                requiredSource:requiredSource
                                                    completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handlePositionsResponse:result
                                error:error
                           usedSource:usedSource
                           forAccount:accountId
                            requestID:requestID
                           completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestOrders:(NSString *)accountId
             fromDataSource:(DataSourceType)requiredSource
                 withStatus:(NSString *)statusFilter
                 completion:(void (^)(NSArray *orders, NSError *error))completion {
    if (!accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:204
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid account ID for orders request"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"🛡️ DataManager: Requesting orders for account %@ from broker %@ (status: %@)",
          accountId, DataSourceTypeToString(requiredSource), statusFilter ?: @"all");
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"orders",
        @"accountId": accountId,
        @"requiredSource": @(requiredSource),
        @"completion": [completion copy]
    } mutableCopy];
    
    if (statusFilter) {
        requestInfo[@"statusFilter"] = statusFilter;
    }
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    NSMutableDictionary *parameters = [@{@"accountId": accountId} mutableCopy];
    if (statusFilter) {
        parameters[@"statusFilter"] = statusFilter;
    }
    
    // 🛡️ SECURITY: Use secure account data request with DataSource provided by caller
    [[DownloadManager sharedManager] executeAccountDataRequest:DataRequestTypeOrders
                                                    parameters:[parameters copy]
                                                requiredSource:requiredSource
                                                    completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleOrdersResponse:result
                             error:error
                        usedSource:usedSource
                        forAccount:accountId
                         requestID:requestID
                        completion:completion];
    }];
    
    return requestID;
}

#pragma mark - 🚨 Order Management (Trading Operations)

- (NSString *)placeOrder:(NSDictionary *)orderData
              forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
              completion:(void (^)(NSString *orderId, NSError *error))completion {
    if (!orderData || !accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:210
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid order data or account ID"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"🚨 DataManager: PLACE ORDER - Account: %@ Broker: %@ OrderData: %@",
          accountId, DataSourceTypeToString(requiredSource), orderData);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"placeOrder",
        @"accountId": accountId,
        @"requiredSource": @(requiredSource),
        @"orderData": orderData,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // 🚨 SECURITY: Use secure trading request with DataSource provided by caller - NEVER fallback
    [[DownloadManager sharedManager] executeTradingRequest:DataRequestTypePlaceOrder
                                                parameters:@{
                                                    @"accountId": accountId,
                                                    @"orderData": orderData
                                                }
                                            requiredSource:requiredSource
                                                completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handlePlaceOrderResponse:result
                                 error:error
                            usedSource:usedSource
                            forAccount:accountId
                             requestID:requestID
                            completion:completion];
    }];
    
    return requestID;
}

- (NSString *)cancelOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
               completion:(void (^)(BOOL success, NSError *error))completion {
    if (!orderId || !accountId || orderId.length == 0 || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:211
                                         userInfo:@{NSLocalizedDescriptionKey: @"🚨 CRITICAL: Invalid order ID or account ID for cancel operation"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return nil;
    }
    
    NSLog(@"🚨 DataManager: CANCEL ORDER - Account: %@ OrderID: %@ Broker: %@",
          accountId, orderId, DataSourceTypeToString(requiredSource));
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"cancelOrder",
        @"accountId": accountId,
        @"requiredSource": @(requiredSource),
        @"orderId": orderId,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // 🚨 SECURITY: Use secure trading request with DataSource provided by caller - NEVER fallback
    [[DownloadManager sharedManager] executeTradingRequest:DataRequestTypeCancelOrder
                                                parameters:@{
                                                    @"accountId": accountId,
                                                    @"orderId": orderId
                                                }
                                            requiredSource:requiredSource
                                                completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleCancelOrderResponse:result
                                  error:error
                             usedSource:usedSource
                             forAccount:accountId
                                orderId:orderId
                              requestID:requestID
                             completion:completion];
    }];
    
    return requestID;
}

- (NSString *)modifyOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
          usingDataSource:(DataSourceType)requiredSource
              newOrderData:(NSDictionary *)newOrderData
               completion:(void (^)(BOOL success, NSError *error))completion {
    if (!orderId || !accountId || !newOrderData || orderId.length == 0 || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:212
                                         userInfo:@{NSLocalizedDescriptionKey: @"🚨 CRITICAL: Invalid parameters for order modification"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return nil;
    }
    
    NSLog(@"🚨 DataManager: MODIFY ORDER - Account: %@ OrderID: %@ Broker: %@",
          accountId, orderId, DataSourceTypeToString(requiredSource));
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"modifyOrder",
        @"accountId": accountId,
        @"requiredSource": @(requiredSource),
        @"orderId": orderId,
        @"newOrderData": newOrderData,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // 🚨 SECURITY: Use secure trading request with DataSource provided by caller - NEVER fallback
    [[DownloadManager sharedManager] executeTradingRequest:DataRequestTypeModifyOrder
                                                parameters:@{
                                                    @"accountId": accountId,
                                                    @"orderId": orderId,
                                                    @"newOrderData": newOrderData
                                                }
                                            requiredSource:requiredSource
                                                completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleModifyOrderResponse:result
                                  error:error
                             usedSource:usedSource
                             forAccount:accountId
                                orderId:orderId
                              requestID:requestID
                             completion:completion];
    }];
    
    return requestID;
}

#pragma mark - 📊 Response Handling

- (NSArray *)standardizeAccountsData:(id)result fromSource:(DataSourceType)usedSource {
    if (!result) return @[];
    
    // Use adapter to standardize accounts data
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    NSArray *standardizedAccounts = @[];
    
    if (adapter) {
        if ([result isKindOfClass:[NSArray class]]) {
            // Array of accounts
            NSMutableArray *accounts = [NSMutableArray array];
            for (id accountData in (NSArray *)result) {
                if ([accountData isKindOfClass:[NSDictionary class]]) {
                    id standardized = [adapter standardizeAccountData:(NSDictionary *)accountData];
                    if (standardized) {
                        [accounts addObject:standardized];
                    }
                }
            }
            standardizedAccounts = [accounts copy];
        } else if ([result isKindOfClass:[NSDictionary class]]) {
            // Single account or accounts wrapper
            id standardized = [adapter standardizeAccountData:(NSDictionary *)result];
            if (standardized) {
                if ([standardized isKindOfClass:[NSArray class]]) {
                    standardizedAccounts = (NSArray *)standardized;
                } else {
                    standardizedAccounts = @[standardized];
                }
            }
        }
        
        NSLog(@"✅ DataManager: Standardized %lu accounts from %@ via adapter",
              (unsigned long)standardizedAccounts.count, DataSourceTypeToString(usedSource));
    }
    
    return standardizedAccounts;
}

- (void)handleAccountDetailsResponse:(id)result
                               error:(NSError *)error
                          usedSource:(DataSourceType)usedSource
                           accountId:(NSString *)accountId
                           requestID:(NSString *)requestID
                          completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: 🛡️ Account details failed for %@ from %@: %@",
              accountId, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Standardize account details
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    NSDictionary *standardizedDetails = @{};
    
    if (adapter && [result isKindOfClass:[NSDictionary class]]) {
        id standardized = [adapter standardizeAccountData:(NSDictionary *)result];
        if ([standardized isKindOfClass:[NSDictionary class]]) {
            standardizedDetails = (NSDictionary *)standardized;
        }
    }
    
    NSLog(@"✅ DataManager: 🛡️ Account details retrieved for %@ from %@",
          accountId, DataSourceTypeToString(usedSource));
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedDetails, nil);
        });
    }
}

- (void)handlePortfolioSummaryResponse:(id)result
                                 error:(NSError *)error
                            usedSource:(DataSourceType)usedSource
                             accountId:(NSString *)accountId
                             requestID:(NSString *)requestID
                            completion:(void (^)(NSDictionary *summary, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: 🛡️ Portfolio summary failed for %@ from %@: %@",
              accountId, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Standardize portfolio summary data
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    NSDictionary *standardizedSummary = @{};
    
    if (adapter && [result isKindOfClass:[NSDictionary class]]) {
        id standardized = [adapter standardizeAccountData:(NSDictionary *)result];
        if ([standardized isKindOfClass:[NSDictionary class]]) {
            standardizedSummary = (NSDictionary *)standardized;
        }
    }
    
    NSLog(@"✅ DataManager: 🛡️ Portfolio summary retrieved for %@ from %@",
          accountId, DataSourceTypeToString(usedSource));
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(standardizedSummary, nil);
        });
    }
}

- (void)handlePositionsResponse:(id)result
                          error:(NSError *)error
                     usedSource:(DataSourceType)usedSource
                     forAccount:(NSString *)accountId
                      requestID:(NSString *)requestID
                     completion:(void (^)(NSArray *positions, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: 🛡️ Positions failed for %@ from %@: %@",
              accountId, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Standardize positions data
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    NSArray *positions = @[];
    
    if (adapter && [result isKindOfClass:[NSArray class]]) {
        NSMutableArray *standardizedPositions = [NSMutableArray array];
        for (NSDictionary *rawPosition in (NSArray *)result) {
            if ([rawPosition isKindOfClass:[NSDictionary class]]) {
                id standardizedPosition = [adapter standardizePositionData:rawPosition];
                if (standardizedPosition) {
                    [standardizedPositions addObject:standardizedPosition];
                }
            }
        }
        positions = [standardizedPositions copy];
        
        NSLog(@"✅ DataManager: 🛡️ Standardized %lu positions for %@ from %@ via adapter",
              (unsigned long)positions.count, accountId, DataSourceTypeToString(usedSource));
    }
    
    NSLog(@"✅ DataManager: 🛡️ Retrieved %lu positions for account %@", (unsigned long)positions.count, accountId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(positions, nil);
        });
    }
}

- (void)handleOrdersResponse:(id)result
                       error:(NSError *)error
                  usedSource:(DataSourceType)usedSource
                  forAccount:(NSString *)accountId
                   requestID:(NSString *)requestID
                  completion:(void (^)(NSArray *orders, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: 🛡️ Orders failed for %@ from %@: %@",
              accountId, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Standardize orders data
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    NSArray *orders = @[];
    
    if (adapter && [result isKindOfClass:[NSArray class]]) {
        NSMutableArray *standardizedOrders = [NSMutableArray array];
        for (NSDictionary *rawOrder in (NSArray *)result) {
            if ([rawOrder isKindOfClass:[NSDictionary class]]) {
                id standardizedOrder = [adapter standardizeOrderData:rawOrder];
                if (standardizedOrder) {
                    [standardizedOrders addObject:standardizedOrder];
                }
            }
        }
        orders = [standardizedOrders copy];
        
        NSLog(@"✅ DataManager: 🛡️ Standardized %lu orders for %@ from %@ via adapter",
              (unsigned long)orders.count, accountId, DataSourceTypeToString(usedSource));
    }
    
    NSLog(@"✅ DataManager: 🛡️ Retrieved %lu orders for account %@", (unsigned long)orders.count, accountId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(orders, nil);
        });
    }
}

- (void)handlePlaceOrderResponse:(id)result
                           error:(NSError *)error
                      usedSource:(DataSourceType)usedSource
                      forAccount:(NSString *)accountId
                       requestID:(NSString *)requestID
                      completion:(void (^)(NSString *orderId, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: 🚨 PLACE ORDER FAILED for %@ from %@: %@",
              accountId, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    NSString *orderId = nil;
    if ([result isKindOfClass:[NSDictionary class]]) {
        NSDictionary *resultDict = (NSDictionary *)result;
        orderId = resultDict[@"orderId"] ?: resultDict[@"id"] ?: resultDict[@"orderID"];
    } else if ([result isKindOfClass:[NSString class]]) {
        orderId = (NSString *)result;
    }
    
    if (!orderId) {
        NSError *parseError = [NSError errorWithDomain:@"DataManager"
                                                  code:220
                                              userInfo:@{NSLocalizedDescriptionKey: @"🚨 CRITICAL: Could not extract order ID from response"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, parseError);
            });
        }
        return;
    }
    
    NSLog(@"✅ DataManager: 🚨 ORDER PLACED SUCCESSFULLY for %@ from %@ - ID: %@",
          accountId, DataSourceTypeToString(usedSource), orderId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(orderId, nil);
        });
    }
}

- (void)handleCancelOrderResponse:(id)result
                            error:(NSError *)error
                       usedSource:(DataSourceType)usedSource
                       forAccount:(NSString *)accountId
                          orderId:(NSString *)orderId
                        requestID:(NSString *)requestID
                       completion:(void (^)(BOOL success, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: 🚨 CANCEL ORDER FAILED for %@ OrderID: %@ from %@: %@",
              accountId, orderId, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return;
    }
    
    BOOL success = NO;
    if ([result isKindOfClass:[NSNumber class]]) {
        success = [(NSNumber *)result boolValue];
    } else if ([result respondsToSelector:@selector(boolValue)]) {
        success = [result boolValue];
    } else {
        // If not a boolean, consider success = YES if no error
        success = YES;
    }
    
    NSLog(@"✅ DataManager: 🚨 CANCEL ORDER %@ for %@ OrderID: %@ from %@",
          success ? @"SUCCESS" : @"FAILED", accountId, orderId, DataSourceTypeToString(usedSource));
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, nil);
        });
    }
}

- (void)handleModifyOrderResponse:(id)result
                            error:(NSError *)error
                       usedSource:(DataSourceType)usedSource
                       forAccount:(NSString *)accountId
                          orderId:(NSString *)orderId
                        requestID:(NSString *)requestID
                       completion:(void (^)(BOOL success, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: 🚨 MODIFY ORDER FAILED for %@ OrderID: %@ from %@: %@",
              accountId, orderId, DataSourceTypeToString(usedSource), error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return;
    }
    
    BOOL success = NO;
    if ([result isKindOfClass:[NSNumber class]]) {
        success = [(NSNumber *)result boolValue];
    } else if ([result respondsToSelector:@selector(boolValue)]) {
        success = [result boolValue];
    } else {
        // If not a boolean, consider success = YES if no error
        success = YES;
    }
    
    NSLog(@"✅ DataManager: 🚨 MODIFY ORDER %@ for %@ OrderID: %@ from %@",
          success ? @"SUCCESS" : @"FAILED", accountId, orderId, DataSourceTypeToString(usedSource));
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, nil);
        });
    }
}

#pragma mark - Utility Methods

// Access activeRequests using valueForKey to bypass private property access
- (void)setValue:(id)value forKey:(NSString *)key inActiveRequests:(BOOL)flag {
    if (flag) {
        NSMutableDictionary *activeRequests = [self valueForKey:@"activeRequests"];
        if (activeRequests) {
            activeRequests[key] = value;
        }
    }
}

- (void)removeValueForKey:(NSString *)key fromActiveRequests:(BOOL)flag {
    if (flag) {
        NSMutableDictionary *activeRequests = [self valueForKey:@"activeRequests"];
        if (activeRequests) {
            [activeRequests removeObjectForKey:key];
        }
    }
}

@end
