//
//  DataManager+Portfolio.m
//  TradingApp
//
//  Implementation of portfolio and account management for DataManager
//

#import "DataManager+Portfolio.h"
#import "DownloadManager.h"

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
    
    // Store request info using private method from main DataManager
    [self setValue:requestInfo forKey:requestID inActiveRequests:YES];
    
    // Use DownloadManager to execute accounts request
    [[DownloadManager sharedManager] executeRequest:DataRequestTypeAccountInfo
                                         parameters:@{}
                                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        [self handleAccountsResponse:result
                               error:error
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
    
    // Process accounts response - assume result is already an array of accounts
    NSArray *accounts = nil;
    if ([result isKindOfClass:[NSArray class]]) {
        accounts = (NSArray *)result;
    } else if ([result isKindOfClass:[NSDictionary class]]) {
        // Some APIs return accounts in a wrapper object
        NSDictionary *resultDict = (NSDictionary *)result;
        accounts = resultDict[@"accounts"] ?: @[result];
    } else {
        accounts = @[];
    }
    
    NSLog(@"✅ DataManager: Retrieved %lu accounts", (unsigned long)accounts.count);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(accounts, nil);
        });
    }
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
    
    NSArray *positions = nil;
    if ([result isKindOfClass:[NSArray class]]) {
        positions = (NSArray *)result;
    } else if ([result isKindOfClass:[NSDictionary class]]) {
        NSDictionary *resultDict = (NSDictionary *)result;
        positions = resultDict[@"positions"] ?: @[];
    } else {
        positions = @[];
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
    
    NSArray *orders = nil;
    if ([result isKindOfClass:[NSArray class]]) {
        orders = (NSArray *)result;
    } else if ([result isKindOfClass:[NSDictionary class]]) {
        NSDictionary *resultDict = (NSDictionary *)result;
        orders = resultDict[@"orders"] ?: @[];
    } else {
        orders = @[];
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
