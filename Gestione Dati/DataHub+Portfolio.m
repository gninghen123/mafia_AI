//
//  DataHub+Portfolio.m - SECURE IMPLEMENTATION
//  TradingApp
//
//  🛡️ SECURITY: ALL portfolio methods require specific DataSource
//  Implementation of portfolio methods for DataHub (NOT DataManager)
//

#import "DataHub+Portfolio.h"
#import "DataManager.h"
#import "DataManager+Portfolio.h"

// Portfolio notification names (defined here)
NSString * const PortfolioAccountsUpdatedNotification = @"PortfolioAccountsUpdatedNotification";
NSString * const PortfolioSummaryUpdatedNotification = @"PortfolioSummaryUpdatedNotification";
NSString * const PortfolioPositionsUpdatedNotification = @"PortfolioPositionsUpdatedNotification";
NSString * const PortfolioOrdersUpdatedNotification = @"PortfolioOrdersUpdatedNotification";
NSString * const PortfolioOrderStatusChangedNotification = @"PortfolioOrderStatusChangedNotification";
NSString * const PortfolioOrderFilledNotification = @"PortfolioOrderFilledNotification";

@implementation DataHub (Portfolio)

#pragma mark - 🛡️ SECURE Account Discovery (Broker-Specific Only)

- (void)getAccountsFromBroker:(DataSourceType)brokerType
                   completion:(void(^)(NSArray<AccountModel *> *accounts, BOOL isFresh, NSError * _Nullable error))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for getAccountsFromBroker");
        return;
    }
    
    NSLog(@"🛡️ DataHub: Getting accounts from broker %@", DataSourceTypeToString(brokerType));
    
    // DataHub acts as a caching/coordination layer over DataManager
    // Use the internal method that actually exists and filter by broker type
    [[DataManager sharedManager] requestAccountsWithCompletion:^(NSArray *allAccounts, NSError *error) {
        
        NSMutableArray<AccountModel *> *accountsForBroker = [NSMutableArray array];
        BOOL isFresh = YES;
        
        if (!error && allAccounts) {
            for (AccountModel *account in allAccounts) {
                if ([account.brokerName isEqualToString:DataSourceTypeToString(brokerType)]) {
                    [accountsForBroker addObject:account];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([accountsForBroker copy], isFresh, error);
        });
    }];
}

- (void)getAccountDetails:(NSString *)accountId
               fromBroker:(DataSourceType)brokerType
               completion:(void(^)(AccountModel * _Nullable account, BOOL isFresh, NSError * _Nullable error))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for getAccountDetails");
        return;
    }
    
    if (!accountId || accountId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid account ID"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, NO, error);
        });
        return;
    }
    
    NSLog(@"🛡️ DataHub: Getting account details for %@ from broker %@", accountId, DataSourceTypeToString(brokerType));
    
    // Forward to DataManager
    [[DataManager sharedManager] requestAccountDetails:accountId
                                 fromDataSource:brokerType
                                     completion:^(NSDictionary *accountDetails, NSError *error) {
        
        AccountModel *accountModel = nil;
        BOOL isFresh = YES;
        
        if (!error && accountDetails) {
            accountModel = [[AccountModel alloc] initWithDictionary:accountDetails];
            accountModel.brokerName = DataSourceTypeToString(brokerType);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(accountModel, isFresh, error);
        });
    }];
}

- (void)checkBrokerConnectionStatus:(DataSourceType)brokerType
                         completion:(void(^)(BOOL isConnected, NSError * _Nullable error))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for checkBrokerConnectionStatus");
        return;
    }
    
    NSLog(@"🔌 DataHub: Checking connection status for broker %@", DataSourceTypeToString(brokerType));
    
    // This could check DataManager/DownloadManager connection status
    // For now, implement a basic version
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // TODO: Implement actual connection check
        BOOL isConnected = YES; // Placeholder
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(isConnected, nil);
        });
    });
}

#pragma mark - 🛡️ SECURE Portfolio Data (Broker-Specific Only)

- (void)getPortfolioSummaryForAccount:(NSString *)accountId
                           fromBroker:(DataSourceType)brokerType
                           completion:(void(^)(PortfolioSummaryModel * _Nullable summary, BOOL isFresh))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for getPortfolioSummaryForAccount");
        return;
    }
    
    if (!accountId || accountId.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, NO);
        });
        return;
    }
    
    NSLog(@"💼 DataHub: Getting portfolio summary for account %@ from broker %@", accountId, DataSourceTypeToString(brokerType));
    
    // Forward to DataManager for portfolio summary
    [[DataManager sharedManager] requestPortfolioSummary:accountId
                                    fromDataSource:brokerType
                                        completion:^(NSDictionary *summaryData, NSError *error) {
        
        PortfolioSummaryModel *summaryModel = nil;
        BOOL isFresh = YES;
        
        if (!error && summaryData) {
            summaryModel = [[PortfolioSummaryModel alloc] init];
            
            // Populate summary model from dictionary
            summaryModel.accountId = summaryData[@"accountId"] ?: accountId;
            summaryModel.brokerName = DataSourceTypeToString(brokerType);
            summaryModel.totalValue = [summaryData[@"totalValue"] doubleValue];
            summaryModel.dayPL = [summaryData[@"dayPL"] doubleValue];
            summaryModel.dayPLPercent = [summaryData[@"dayPLPercent"] doubleValue];
            summaryModel.buyingPower = [summaryData[@"buyingPower"] doubleValue];
            summaryModel.cashBalance = [summaryData[@"cashBalance"] doubleValue];
            summaryModel.marginUsed = [summaryData[@"marginUsed"] doubleValue];
            summaryModel.dayTradesLeft = [summaryData[@"dayTradesLeft"] integerValue];
            summaryModel.lastUpdated = summaryData[@"lastUpdated"] ? : [NSDate date];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(summaryModel, isFresh);
        });
    }];
}

- (void)getPositionsForAccount:(NSString *)accountId
                    fromBroker:(DataSourceType)brokerType
                    completion:(void(^)(NSArray<AdvancedPositionModel *> * _Nullable positions, BOOL isFresh))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for getPositionsForAccount");
        return;
    }
    
    if (!accountId || accountId.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, NO);
        });
        return;
    }
    
    NSLog(@"🏦 DataHub: Getting positions for account %@ from broker %@", accountId, DataSourceTypeToString(brokerType));
    
    // Forward to DataManager for positions
    [[DataManager sharedManager] requestPositions:accountId
                                    fromDataSource:brokerType
                                        completion:^(NSArray *positionsArray, NSError *error) {
        
        NSMutableArray<AdvancedPositionModel *> *positionModels = [NSMutableArray array];
        BOOL isFresh = YES;
        
        if (!error && positionsArray) {
            for (id positionData in positionsArray) {
                if ([positionData isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *dict = (NSDictionary *)positionData;
                    
                    AdvancedPositionModel *positionModel = [[AdvancedPositionModel alloc] init];
                    positionModel.symbol = dict[@"symbol"] ?: @"";
                    positionModel.accountId = dict[@"accountId"] ?: accountId;
                    positionModel.quantity = [dict[@"quantity"] doubleValue];
                    positionModel.avgCost = [dict[@"avgCost"] doubleValue];
                    positionModel.currentPrice = [dict[@"currentPrice"] doubleValue];
                    positionModel.bidPrice = [dict[@"bidPrice"] doubleValue];
                    positionModel.askPrice = [dict[@"askPrice"] doubleValue];
                    positionModel.dayHigh = [dict[@"dayHigh"] doubleValue];
                    positionModel.dayLow = [dict[@"dayLow"] doubleValue];
                    positionModel.dayOpen = [dict[@"dayOpen"] doubleValue];
                    positionModel.previousClose = [dict[@"previousClose"] doubleValue];
                    positionModel.marketValue = [dict[@"marketValue"] doubleValue];
                    positionModel.unrealizedPL = [dict[@"unrealizedPL"] doubleValue];
                    positionModel.unrealizedPLPercent = [dict[@"unrealizedPLPercent"] doubleValue];
                    positionModel.priceLastUpdated = dict[@"lastUpdated"] ?: [NSDate date];
                    
                    [positionModels addObject:positionModel];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([positionModels copy], isFresh);
        });
    }];
}

- (void)getOrdersForAccount:(NSString *)accountId
                 fromBroker:(DataSourceType)brokerType
                 withStatus:(NSString * _Nullable)statusFilter
                 completion:(void(^)(NSArray<AdvancedOrderModel *> * _Nullable orders, BOOL isFresh))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for getOrdersForAccount");
        return;
    }
    
    if (!accountId || accountId.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, NO);
        });
        return;
    }
    
    NSLog(@"📋 DataHub: Getting orders for account %@ from broker %@ with status filter: %@",
          accountId, DataSourceTypeToString(brokerType), statusFilter ?: @"all");
    
    // Forward to DataManager for orders
    [[DataManager sharedManager] requestOrders:accountId
                                fromDataSource:brokerType
                                    withStatus:statusFilter
                                    completion:^(NSArray *ordersArray, NSError *error) {
        
        NSMutableArray<AdvancedOrderModel *> *orderModels = [NSMutableArray array];
        BOOL isFresh = YES;
        
        if (!error && ordersArray) {
            for (id orderData in ordersArray) {
                if ([orderData isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *dict = (NSDictionary *)orderData;
                    
                    AdvancedOrderModel *orderModel = [[AdvancedOrderModel alloc] init];
                    // Populate order model from dictionary
                    orderModel.orderId = dict[@"orderId"] ?: @"";
                    orderModel.accountId = dict[@"accountId"] ?: accountId;
                    orderModel.symbol = dict[@"symbol"] ?: @"";
                    orderModel.orderType = dict[@"orderType"] ?: @"MARKET";
                    orderModel.side = dict[@"side"] ?: @"BUY";
                    orderModel.status = dict[@"status"] ?: @"PENDING";
                    orderModel.timeInForce = dict[@"timeInForce"] ?: @"DAY";
                    orderModel.quantity = [dict[@"quantity"] doubleValue];
                    orderModel.filledQuantity = [dict[@"filledQuantity"] doubleValue];
                    orderModel.price = [dict[@"price"] doubleValue];
                    orderModel.stopPrice = [dict[@"stopPrice"] doubleValue];
                    orderModel.avgFillPrice = [dict[@"avgFillPrice"] doubleValue];
                    
                    NSString *createdDateStr = dict[@"createdDate"];
                    if (createdDateStr) {
                        orderModel.createdDate = [NSDate dateWithTimeIntervalSince1970:[createdDateStr doubleValue]];
                    }
                    
                    NSString *updatedDateStr = dict[@"updatedDate"];
                    if (updatedDateStr) {
                        orderModel.updatedDate = [NSDate dateWithTimeIntervalSince1970:[updatedDateStr doubleValue]];
                    }
                    
                    [orderModels addObject:orderModel];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([orderModels copy], isFresh);
        });
    }];
}

#pragma mark - 🛡️ SECURE Trading Operations (Broker-Specific Only)

- (void)placeOrder:(NSDictionary *)orderData
        forAccount:(NSString *)accountId
        withBroker:(DataSourceType)brokerType
        completion:(void(^)(NSString * _Nullable orderId, NSError * _Nullable error))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for placeOrder");
        return;
    }
    
    if (!accountId || accountId.length == 0 || !orderData) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid order parameters"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, error);
        });
        return;
    }
    
    NSLog(@"🚨 DataHub: Placing order for account %@ via broker %@", accountId, DataSourceTypeToString(brokerType));
    
    // Forward to DataManager's secure trading methods
    [[DataManager sharedManager] placeOrder:orderData
                                 forAccount:accountId
                             usingDataSource:brokerType
                                  completion:^(NSString *orderId, NSError *error) {
        
        if (!error && orderId) {
            // Broadcast notification about successful order placement
            [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioOrderStatusChangedNotification
                                                                object:self
                                                              userInfo:@{
                                                                  @"orderId": orderId,
                                                                  @"accountId": accountId,
                                                                  @"brokerType": @(brokerType),
                                                                  @"status": @"PLACED"
                                                              }];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(orderId, error);
        });
    }];
}

- (void)cancelOrder:(NSString *)orderId
         forAccount:(NSString *)accountId
         withBroker:(DataSourceType)brokerType
         completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for cancelOrder");
        return;
    }
    
    if (!accountId || accountId.length == 0 || !orderId || orderId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid cancel order parameters"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, error);
        });
        return;
    }
    
    NSLog(@"❌ DataHub: Cancelling order %@ for account %@ via broker %@", orderId, accountId, DataSourceTypeToString(brokerType));
    
    // Forward to DataManager's secure trading methods
    [[DataManager sharedManager] cancelOrder:orderId
                                  forAccount:accountId
                             usingDataSource:brokerType
                                  completion:^(BOOL success, NSError *error) {
        
        if (success && !error) {
            // Broadcast notification about successful order cancellation
            [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioOrderStatusChangedNotification
                                                                object:self
                                                              userInfo:@{
                                                                  @"orderId": orderId,
                                                                  @"accountId": accountId,
                                                                  @"brokerType": @(brokerType),
                                                                  @"status": @"CANCELLED"
                                                              }];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    }];
}

- (void)modifyOrder:(NSString *)orderId
        withNewData:(NSDictionary *)newOrderData
         forAccount:(NSString *)accountId
         withBroker:(DataSourceType)brokerType
         completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    if (!completion) {
        NSLog(@"⚠️ DataHub+Portfolio: No completion block provided for modifyOrder");
        return;
    }
    
    if (!accountId || accountId.length == 0 || !orderId || orderId.length == 0 || !newOrderData) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid modify order parameters"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, error);
        });
        return;
    }
    
    NSLog(@"🔧 DataHub: Modifying order %@ for account %@ via broker %@", orderId, accountId, DataSourceTypeToString(brokerType));
    
    // For now, implement modify as cancel + place new order
    // TODO: Implement proper order modification when brokers support it
    [self cancelOrder:orderId forAccount:accountId withBroker:brokerType completion:^(BOOL cancelSuccess, NSError *cancelError) {
        if (cancelSuccess && !cancelError) {
        [self placeOrder:newOrderData forAccount:accountId withBroker:brokerType completion:^(NSString *newOrderId, NSError *placeError) {
                if (!placeError && newOrderId) {
                    // Broadcast notification about order modification
                    [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioOrderStatusChangedNotification
                                                                        object:self
                                                                      userInfo:@{
                                                                          @"originalOrderId": orderId,
                                                                          @"newOrderId": newOrderId,
                                                                          @"accountId": accountId,
                                                                          @"brokerType": @(brokerType),
                                                                          @"status": @"MODIFIED"}];
                }
                
                completion(!placeError && newOrderId != nil, placeError);
            }];
        } else {
            completion(NO, cancelError);
        }
    }];
}

#pragma mark - 🔧 SECURE Subscription System (Broker-Specific)

- (void)subscribeToPortfolioUpdatesForAccount:(NSString *)accountId
                                   fromBroker:(DataSourceType)brokerType {
    
    if (!accountId || accountId.length == 0) {
        NSLog(@"⚠️ DataHub+Portfolio: Invalid account ID for portfolio subscription");
        return;
    }
    
    NSLog(@"🔔 DataHub: Subscribing to portfolio updates for account %@ from broker %@", accountId, DataSourceTypeToString(brokerType));
    
    // TODO: Implement subscription logic
    // This would typically involve setting up real-time data streams
}

- (void)unsubscribeFromPortfolioUpdatesForAccount:(NSString *)accountId
                                       fromBroker:(DataSourceType)brokerType {
    
    if (!accountId || accountId.length == 0) {
        NSLog(@"⚠️ DataHub+Portfolio: Invalid account ID for portfolio unsubscription");
        return;
    }
    
    NSLog(@"🔕 DataHub: Unsubscribing from portfolio updates for account %@ from broker %@", accountId, DataSourceTypeToString(brokerType));
    
    // TODO: Implement unsubscription logic
}

#pragma mark - 🛠️ Utility Methods

- (NSArray<NSNumber *> *)getConnectedBrokers {
    NSLog(@"🔌 DataHub: Getting list of connected brokers");
    
    // TODO: Implement logic to check which brokers are actually connected
    // For now, return a placeholder list
    return @[@(DataSourceTypeSchwab), @(DataSourceTypeIBKR)];
}

- (void)clearPortfolioCacheForAccount:(NSString *)accountId
                           fromBroker:(DataSourceType)brokerType {
    
    if (!accountId || accountId.length == 0) {
        NSLog(@"⚠️ DataHub+Portfolio: Invalid account ID for cache clearing");
        return;
    }
    
    NSLog(@"🗑️ DataHub: Clearing portfolio cache for account %@ from broker %@", accountId, DataSourceTypeToString(brokerType));
    
    // TODO: Implement cache clearing logic
    // This would clear any cached portfolio data for the specific account/broker combination
}

@end
