//
//  DataManager+Portfolio.m
//  TradingApp
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
    
    // ✅ CORRETTO: Passa usedSource al handler
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeAccountInfo
                                         parameters:@{}
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleAccountsResponse:result
                               error:error
                          usedSource:usedSource  // ✅ AGGIUNTO
                           requestID:requestID
                          completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestAccountDetails:(NSString *)accountId
                         completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion {
    if (!accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:200
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid account ID"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"📱 DataManager: Requesting details for account %@", accountId);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"accountDetails",
        @"accountId": accountId,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeAccountInfo
                                         parameters:@{@"accountId": accountId}
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleAccountDetailsResponse:result
                                     error:error
                                 forAccount:accountId
                                 requestID:requestID
                                completion:completion];
    }];
    
    return requestID;
}

#pragma mark - Portfolio Data Requests

- (NSString *)requestPortfolioSummary:(NSString *)accountId
                           completion:(void (^)(NSDictionary *summary, NSError *error))completion {
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
    
    NSLog(@"📊 DataManager: Requesting portfolio summary for account %@", accountId);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"portfolioSummary",
        @"accountId": accountId,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // Portfolio summary is usually part of account details
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeAccountInfo
                                         parameters:@{@"accountId": accountId, @"includePortfolio": @YES}
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handlePortfolioSummaryResponse:result
                                       error:error
                                   forAccount:accountId
                                   requestID:requestID
                                  completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestPositions:(NSString *)accountId
                    completion:(void (^)(NSArray *positions, NSError *error))completion {
    if (!accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:202
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid account ID"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"📈 DataManager: Requesting positions for account %@", accountId);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"positions",
        @"accountId": accountId,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypePositions
                                         parameters:@{@"accountId": accountId}
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handlePositionsResponse:result
                                error:error
                           usedSource:usedSource  // ✅ AGGIUNTO
                           forAccount:accountId
                            requestID:requestID
                           completion:completion];
    }];
    
    return requestID;
}

- (NSString *)requestOrders:(NSString *)accountId
                 withStatus:(NSString *)statusFilter
                 completion:(void (^)(NSArray *orders, NSError *error))completion {
    if (!accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:203
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid account ID"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return nil;
    }
    
    NSLog(@"📋 DataManager: Requesting orders for account %@ (filter: %@)", accountId, statusFilter ?: @"all");
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"orders",
        @"accountId": accountId,
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
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeOrders
                                         parameters:[parameters copy]
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleOrdersResponse:result
                             error:error
                        usedSource:usedSource  // ✅ AGGIUNTO
                        forAccount:accountId
                         requestID:requestID
                        completion:completion];
    }];
    
    return requestID;
}

#pragma mark - Order Management

- (NSString *)placeOrder:(NSDictionary *)orderData
              forAccount:(NSString *)accountId
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
    
    NSLog(@"🔨 DataManager: Placing order for account %@", accountId);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"placeOrder",
        @"accountId": accountId,
        @"orderData": orderData,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // Use a custom request type for order placement
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeOrders
                                         parameters:@{
                                             @"accountId": accountId,
                                             @"orderData": orderData,
                                             @"action": @"place"
                                         }
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handlePlaceOrderResponse:result
                                 error:error
                            forAccount:accountId
                             requestID:requestID
                            completion:completion];
    }];
    
    return requestID;
}

- (NSString *)cancelOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
               completion:(void (^)(BOOL success, NSError *error))completion {
    if (!orderId || !accountId || orderId.length == 0 || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:211
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid order ID or account ID"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return nil;
    }
    
    NSLog(@"🗑 DataManager: Cancelling order %@ for account %@", orderId, accountId);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"cancelOrder",
        @"accountId": accountId,
        @"orderId": orderId,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeOrders
                                         parameters:@{
                                             @"accountId": accountId,
                                             @"orderId": orderId,
                                             @"action": @"cancel"
                                         }
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleCancelOrderResponse:result
                                  error:error
                              forAccount:accountId
                                 orderId:orderId
                               requestID:requestID
                              completion:completion];
    }];
    
    return requestID;
}

- (NSString *)modifyOrder:(NSString *)orderId
               forAccount:(NSString *)accountId
              newOrderData:(NSDictionary *)newOrderData
               completion:(void (^)(BOOL success, NSError *error))completion {
    if (!orderId || !accountId || !newOrderData || orderId.length == 0 || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:212
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters for order modification"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return nil;
    }
    
    NSLog(@"✏️ DataManager: Modifying order %@ for account %@", orderId, accountId);
    
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *requestInfo = [@{
        @"type": @"modifyOrder",
        @"accountId": accountId,
        @"orderId": orderId,
        @"newOrderData": newOrderData,
        @"completion": [completion copy]
    } mutableCopy];
    
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeOrders
                                         parameters:@{
                                             @"accountId": accountId,
                                             @"orderId": orderId,
                                             @"orderData": newOrderData,
                                             @"action": @"modify"
                                         }
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleModifyOrderResponse:result
                                  error:error
                             forAccount:accountId
                                orderId:orderId
                              requestID:requestID
                             completion:completion];
    }];
    
    return requestID;
}

#pragma mark - Response Handlers

- (void)handleAccountsResponse:(id)result
                         error:(NSError *)error
                    usedSource:(DataSourceType)usedSource  // ✅ AGGIUNTO
                     requestID:(NSString *)requestID
                    completion:(void (^)(NSArray *accounts, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: Accounts request failed: %@", error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // ✅ CORRETTO: Usa usedSource invece di inventare getLastUsedDataSourceType
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    
    NSArray *accounts = nil;
    
    if (adapter && [adapter respondsToSelector:@selector(standardizeAccountData:)]) {
        NSLog(@"📊 DataManager: Standardizing account data using %@ adapter", [adapter sourceName]);
        
        NSDictionary *standardizedData = [adapter standardizeAccountData:result];
        accounts = standardizedData[@"accounts"];
        
        if (!accounts) {
            NSLog(@"⚠️ DataManager: Adapter did not return expected format, using raw data");
            accounts = [self extractAccountsFromRawData:result];
        } else {
            NSLog(@"✅ DataManager: Successfully standardized %lu accounts via adapter", (unsigned long)accounts.count);
        }
    } else {
        NSLog(@"⚠️ DataManager: No adapter or standardizeAccountData method, using manual processing");
        accounts = [self extractAccountsFromRawData:result];
    }
    
    NSLog(@"✅ DataManager: Retrieved %lu accounts", (unsigned long)accounts.count);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(accounts, nil);
        });
    }
}

- (NSArray *)extractAccountsFromRawData:(id)result {
    NSArray *accounts = nil;
    
    if ([result isKindOfClass:[NSArray class]]) {
        accounts = (NSArray *)result;
    } else if ([result isKindOfClass:[NSDictionary class]]) {
        NSDictionary *resultDict = (NSDictionary *)result;
        accounts = resultDict[@"accounts"] ?: @[result];
    } else {
        accounts = @[];
    }
    
    return accounts;
}

- (void)handleAccountDetailsResponse:(id)result
                               error:(NSError *)error
                           forAccount:(NSString *)accountId
                           requestID:(NSString *)requestID
                          completion:(void (^)(NSDictionary *accountDetails, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: Account details request failed for %@: %@", accountId, error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    NSDictionary *accountDetails = nil;
    if ([result isKindOfClass:[NSDictionary class]]) {
        accountDetails = (NSDictionary *)result;
    } else {
        accountDetails = @{};
    }
    
    NSLog(@"✅ DataManager: Retrieved details for account %@", accountId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(accountDetails, nil);
        });
    }
}

- (void)handlePortfolioSummaryResponse:(id)result
                                 error:(NSError *)error
                             forAccount:(NSString *)accountId
                             requestID:(NSString *)requestID
                            completion:(void (^)(NSDictionary *summary, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: Portfolio summary request failed for %@: %@", accountId, error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Extract portfolio summary from account data
    NSDictionary *portfolioSummary = nil;
    if ([result isKindOfClass:[NSDictionary class]]) {
        NSDictionary *resultDict = (NSDictionary *)result;
        portfolioSummary = resultDict[@"portfolio"] ?: resultDict[@"balances"] ?: resultDict;
    }
    
    NSLog(@"✅ DataManager: Retrieved portfolio summary for account %@", accountId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(portfolioSummary ?: @{}, nil);
        });
    }
}

- (void)handlePositionsResponse:(id)result
                          error:(NSError *)error
                     usedSource:(DataSourceType)usedSource  // ✅ AGGIUNTO
                     forAccount:(NSString *)accountId
                      requestID:(NSString *)requestID
                     completion:(void (^)(NSArray *positions, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: Positions request failed for %@: %@", accountId, error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // ✅ CORRETTO: Usa usedSource passato dal DownloadManager
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    
    NSArray *positions = result;
    
    if ([result isKindOfClass:[NSArray class]] && adapter && [adapter respondsToSelector:@selector(standardizePositionData:)]) {
        NSLog(@"📊 DataManager: Standardizing %lu positions using %@ adapter", (unsigned long)[(NSArray*)result count], [adapter sourceName]);
        
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
        
        NSLog(@"✅ DataManager: Standardized %lu positions via adapter", (unsigned long)positions.count);
    }
    
    NSLog(@"✅ DataManager: Retrieved %lu positions for account %@", (unsigned long)positions.count, accountId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(positions, nil);
        });
    }
}

- (void)handleOrdersResponse:(id)result
                       error:(NSError *)error
                  usedSource:(DataSourceType)usedSource  // ✅ AGGIUNTO
                  forAccount:(NSString *)accountId
                   requestID:(NSString *)requestID
                  completion:(void (^)(NSArray *orders, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: Orders request failed for %@: %@", accountId, error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // ✅ CORRETTO: Usa usedSource passato dal DownloadManager
    id<DataSourceAdapter> adapter = [DataAdapterFactory adapterForDataSource:usedSource];
    
    NSArray *orders = result;
    
    if ([result isKindOfClass:[NSArray class]] && adapter && [adapter respondsToSelector:@selector(standardizeOrderData:)]) {
        NSLog(@"📊 DataManager: Standardizing %lu orders using %@ adapter", (unsigned long)[(NSArray*)result count], [adapter sourceName]);
        
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
        
        NSLog(@"✅ DataManager: Standardized %lu orders via adapter", (unsigned long)orders.count);
    }
    
    NSLog(@"✅ DataManager: Retrieved %lu orders for account %@", (unsigned long)orders.count, accountId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(orders, nil);
        });
    }
}

- (void)handlePlaceOrderResponse:(id)result
                           error:(NSError *)error
                      forAccount:(NSString *)accountId
                       requestID:(NSString *)requestID
                      completion:(void (^)(NSString *orderId, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: Place order failed for %@: %@", accountId, error.localizedDescription);
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
                                              userInfo:@{NSLocalizedDescriptionKey: @"Could not extract order ID from response"}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, parseError);
            });
        }
        return;
    }
    
    NSLog(@"✅ DataManager: Order placed successfully for %@ - ID: %@", accountId, orderId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(orderId, nil);
        });
    }
}

- (void)handleCancelOrderResponse:(id)result
                            error:(NSError *)error
                       forAccount:(NSString *)accountId
                          orderId:(NSString *)orderId
                        requestID:(NSString *)requestID
                       completion:(void (^)(BOOL success, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: Cancel order failed for %@ (order %@): %@", accountId, orderId, error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return;
    }
    
    // Assume success if no error
    NSLog(@"✅ DataManager: Order cancelled successfully for %@ - Order ID: %@", accountId, orderId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, nil);
        });
    }
}

- (void)handleModifyOrderResponse:(id)result
                            error:(NSError *)error
                       forAccount:(NSString *)accountId
                          orderId:(NSString *)orderId
                        requestID:(NSString *)requestID
                       completion:(void (^)(BOOL success, NSError *error))completion {
    
    [self removeValueForKey:requestID fromActiveRequests:YES];
    
    if (error) {
        NSLog(@"❌ DataManager: Modify order failed for %@ (order %@): %@", accountId, orderId, error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return;
    }
    
    // Assume success if no error
    NSLog(@"✅ DataManager: Order modified successfully for %@ - Order ID: %@", accountId, orderId);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, nil);
        });
    }
}

#pragma mark - Private Helper Methods

- (void)setValue:(id)value forKey:(NSString *)key inActiveRequests:(BOOL)inActiveRequests {
    // This is a helper to access the private activeRequests dictionary from main DataManager
    // In a real implementation, you'd either make activeRequests public or add this as a method to DataManager
    
    // For now, we'll use a simple approach with KVC (not recommended for production)
    NSMutableDictionary *activeRequests = [self valueForKey:@"activeRequests"];
    if (activeRequests) {
        activeRequests[key] = value;
    }
}

- (void)removeValueForKey:(NSString *)key fromActiveRequests:(BOOL)fromActiveRequests {
    NSMutableDictionary *activeRequests = [self valueForKey:@"activeRequests"];
    if (activeRequests) {
        [activeRequests removeObjectForKey:key];
    }
}

@end
