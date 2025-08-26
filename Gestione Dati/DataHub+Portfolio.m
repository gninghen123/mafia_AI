//
//  DataHub+Portfolio.m
//  TradingApp
//
//  Implementation of multi-account portfolio management
//  SIMPLIFIED VERSION: No advanced caching - only standardized data from DataManager
//

#import "DataHub+Portfolio.h"
#import "DataManager+Portfolio.h"
#import "DataHub+MarketData.h"
#import "DataHub+Private.h"

// Portfolio notification names
NSString * const PortfolioAccountsUpdatedNotification = @"PortfolioAccountsUpdatedNotification";
NSString * const PortfolioSummaryUpdatedNotification = @"PortfolioSummaryUpdatedNotification";
NSString * const PortfolioPositionsUpdatedNotification = @"PortfolioPositionsUpdatedNotification";
NSString * const PortfolioOrdersUpdatedNotification = @"PortfolioOrdersUpdatedNotification";
NSString * const PortfolioOrderStatusChangedNotification = @"PortfolioOrderStatusChangedNotification";
NSString * const PortfolioOrderFilledNotification = @"PortfolioOrderFilledNotification";

@implementation DataHub (Portfolio)

#pragma mark - Account Discovery & Management

- (void)getAvailableAccountsWithCompletion:(void(^)(NSArray<AccountModel *> *accounts, NSError *error))completion {
    if (!completion) return;
    
    NSLog(@"📱 DataHub: Getting available accounts across all brokers");
    
    // Request accounts from DataManager (already standardized)
    [[DataManager sharedManager] requestAccountsWithCompletion:^(NSArray *standardizedAccounts, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to get accounts: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        // Create AccountModel objects from standardized data
        NSMutableArray<AccountModel *> *accountModels = [NSMutableArray array];
        
        for (id accountData in standardizedAccounts) {
            if ([accountData isKindOfClass:[NSDictionary class]]) {
                AccountModel *account = [self createAccountModelFromStandardizedData:(NSDictionary *)accountData];
                if (account) {
                    [accountModels addObject:account];
                }
            } else {
                NSLog(@"⚠️ DataHub: Unexpected account data format from DataManager: %@", [accountData class]);
            }
        }
        
        NSLog(@"✅ DataHub: Created %lu AccountModel objects from standardized data", (unsigned long)accountModels.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([accountModels copy], nil);
            
            // Broadcast notification
            [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioAccountsUpdatedNotification
                                                                object:self
                                                              userInfo:@{@"accounts": accountModels}];
        });
    }];
}

- (void)getAccountDetails:(NSString *)accountId completion:(void(^)(AccountModel *account, NSError *error))completion {
    if (!accountId || !completion) return;
    
    [[DataManager sharedManager] requestAccountDetails:accountId completion:^(NSDictionary *standardizedDetails, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        AccountModel *account = [self createAccountModelFromStandardizedData:standardizedDetails];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(account, nil);
        });
    }];
}

- (void)refreshAccountConnectionStatus:(NSString *)accountId completion:(void(^)(BOOL isConnected, NSError *error))completion {
    if (!accountId || !completion) return;
    
    // For now, assume connected if we can get account details
    [self getAccountDetails:accountId completion:^(AccountModel *account, NSError *error) {
        if (completion) {
            completion(account ? account.isConnected : NO, error);
        }
    }];
}

#pragma mark - Multi-Account Portfolio Data (Simplified - No Caching)

- (void)getPortfolioSummaryForAccount:(NSString *)accountId completion:(void(^)(PortfolioSummaryModel *summary, BOOL isFresh))completion {
    if (!accountId || !completion) return;
    
    NSLog(@"📊 DataHub: Getting portfolio summary for account %@", accountId);
    
    // Fetch data from DataManager (always fresh for now)
    [[DataManager sharedManager] requestPortfolioSummary:accountId completion:^(NSDictionary *standardizedSummary, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to get portfolio summary for %@: %@", accountId, error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, NO);
            });
            return;
        }
        
        PortfolioSummaryModel *summary = [self createPortfolioSummaryFromStandardizedData:standardizedSummary];
        
        NSLog(@"✅ DataHub: Loaded portfolio summary for account %@", accountId);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(summary, YES); // Always fresh since we don't cache yet
            
            // Broadcast update
            [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioSummaryUpdatedNotification
                                                                object:self
                                                              userInfo:@{@"accountId": accountId, @"summary": summary}];
        });
    }];
}

- (void)getPositionsForAccount:(NSString *)accountId completion:(void(^)(NSArray<AdvancedPositionModel *> *positions, BOOL isFresh))completion {
    if (!accountId || !completion) return;
    
    NSLog(@"📈 DataHub: Getting positions for account %@", accountId);
    
    // Fetch positions from DataManager (always fresh for now)
    [[DataManager sharedManager] requestPositions:accountId completion:^(NSArray *standardizedPositions, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to get positions for %@: %@", accountId, error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], NO);
            });
            return;
        }
        
        NSMutableArray<AdvancedPositionModel *> *positions = [NSMutableArray array];
        
        for (id positionData in standardizedPositions) {
            if ([positionData isKindOfClass:[NSDictionary class]]) {
                AdvancedPositionModel *position = [self createPositionModelFromStandardizedData:(NSDictionary *)positionData];
                if (position) {
                    [positions addObject:position];
                }
            }
        }
        
        NSLog(@"✅ DataHub: Loaded %lu positions for account %@", (unsigned long)positions.count, accountId);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([positions copy], YES); // Always fresh since we don't cache yet
            
            // Broadcast update
            [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioPositionsUpdatedNotification
                                                                object:self
                                                              userInfo:@{@"accountId": accountId, @"positions": positions}];
        });
    }];
}

- (void)getOrdersForAccount:(NSString *)accountId completion:(void(^)(NSArray<AdvancedOrderModel *> *orders, BOOL isFresh))completion {
    [self getOrdersForAccount:accountId withStatus:nil completion:completion];
}

- (void)getOrdersForAccount:(NSString *)accountId
                 withStatus:(NSString *)statusFilter
                 completion:(void(^)(NSArray<AdvancedOrderModel *> *orders, BOOL isFresh))completion {
    if (!accountId || !completion) return;
    
    NSLog(@"📋 DataHub: Getting orders for account %@ (filter: %@)", accountId, statusFilter ?: @"all");
    
    // Fetch orders from DataManager (always fresh for now)
    [[DataManager sharedManager] requestOrders:accountId withStatus:statusFilter completion:^(NSArray *standardizedOrders, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to get orders for %@: %@", accountId, error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], NO);
            });
            return;
        }
        
        NSMutableArray<AdvancedOrderModel *> *orders = [NSMutableArray array];
        
        for (id orderData in standardizedOrders) {
            if ([orderData isKindOfClass:[NSDictionary class]]) {
                AdvancedOrderModel *order = [self createOrderModelFromStandardizedData:(NSDictionary *)orderData];
                if (order) {
                    [orders addObject:order];
                }
            }
        }
        
        NSLog(@"✅ DataHub: Loaded %lu orders for account %@ (filter: %@)",
              (unsigned long)orders.count, accountId, statusFilter ?: @"all");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([orders copy], YES); // Always fresh since we don't cache yet
            
            // Broadcast update
            [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioOrdersUpdatedNotification
                                                                object:self
                                                              userInfo:@{@"accountId": accountId, @"orders": orders}];
        });
    }];
}

#pragma mark - Real-time Subscription Management

- (void)subscribeToPortfolioUpdatesForAccount:(NSString *)accountId {
    NSLog(@"📡 DataHub: Setting up portfolio subscriptions for account %@", accountId);
    
    // Store current account for subscription management
    [[NSUserDefaults standardUserDefaults] setObject:accountId forKey:@"CurrentPortfolioAccountId"];
    
    // Get positions to subscribe to symbols
    [self getPositionsForAccount:accountId completion:^(NSArray<AdvancedPositionModel *> *positions, BOOL isFresh) {
        
        // Subscribe to real-time prices for all position symbols
        NSMutableSet *symbols = [NSMutableSet set];
        for (AdvancedPositionModel *position in positions) {
            if (position.symbol && position.symbol.length > 0) {
                [symbols addObject:position.symbol];
            }
        }
        
        NSLog(@"📈 DataHub: Subscribing to real-time prices for %lu symbols in account %@",
              (unsigned long)symbols.count, accountId);
        
        for (NSString *symbol in symbols) {
            [self subscribeToQuoteUpdatesForSymbol:symbol];
        }
        
        // Start portfolio-specific polling timers (simplified for now)
        [self startPortfolioPollingForAccount:accountId];
    }];
}

- (void)switchPortfolioSubscriptionToAccount:(NSString *)accountId {
    NSString *currentAccountId = [[NSUserDefaults standardUserDefaults] stringForKey:@"CurrentPortfolioAccountId"];
    
    if ([currentAccountId isEqualToString:accountId]) {
        NSLog(@"ℹ️ DataHub: Already subscribed to account %@", accountId);
        return;
    }
    
    NSLog(@"🔄 DataHub: Switching portfolio subscription from %@ to %@", currentAccountId ?: @"none", accountId);
    [self subscribeToPortfolioUpdatesForAccount:accountId];
}

#pragma mark - Helper Methods for Creating Models from Standardized Data

- (AccountModel *)createAccountModelFromStandardizedData:(NSDictionary *)standardizedData {
    if (!standardizedData || ![standardizedData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ DataHub: Invalid standardized account data: %@", standardizedData);
        return nil;
    }
    
    AccountModel *account = [[AccountModel alloc] init];
    
    // Extract standardized fields safely
    id accountIdValue = standardizedData[@"accountId"] ?: standardizedData[@"accountNumber"];
    account.accountId = [accountIdValue isKindOfClass:[NSString class]] ? accountIdValue : @"UNKNOWN";
    
    id typeValue = standardizedData[@"type"] ?: standardizedData[@"accountType"];
    account.accountType = [typeValue isKindOfClass:[NSString class]] ? typeValue : @"UNKNOWN";
    
    id brokerValue = standardizedData[@"brokerName"] ?: standardizedData[@"brokerIndicator"];
    account.brokerName = [brokerValue isKindOfClass:[NSString class]] ? brokerValue : @"UNKNOWN";
    
    // Generate display name if not provided
    if (standardizedData[@"displayName"] && [standardizedData[@"displayName"] isKindOfClass:[NSString class]]) {
        account.displayName = standardizedData[@"displayName"];
    } else {
        // Use the formattedDisplayName method from AccountModel
        account.displayName = [account formattedDisplayName];
    }
    
    account.isConnected = [standardizedData[@"isConnected"] boolValue];
    account.isPrimary = [standardizedData[@"isPrimary"] boolValue];
    
    // Last updated date
    if ([standardizedData[@"lastUpdated"] isKindOfClass:[NSDate class]]) {
        account.lastUpdated = standardizedData[@"lastUpdated"];
    } else {
        account.lastUpdated = [NSDate date];
    }
    
    NSLog(@"✅ DataHub: Created AccountModel: %@ (ID: %@, Broker: %@)",
          account.displayName, account.accountId, account.brokerName);
    
    return account;
}

- (PortfolioSummaryModel *)createPortfolioSummaryFromStandardizedData:(NSDictionary *)standardizedData {
    if (!standardizedData || ![standardizedData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    PortfolioSummaryModel *summary = [[PortfolioSummaryModel alloc] init];
    
    // Extract standardized portfolio values
    summary.accountId = [standardizedData[@"accountId"] isKindOfClass:[NSString class]] ?
                       standardizedData[@"accountId"] : @"";
    summary.brokerName = [standardizedData[@"brokerName"] isKindOfClass:[NSString class]] ?
                        standardizedData[@"brokerName"] : @"";
    
    NSDictionary *balances = standardizedData[@"currentBalances"] ?: standardizedData[@"balances"] ?: standardizedData;
    
    summary.totalValue = [balances[@"liquidationValue"] ?: balances[@"totalValue"] ?: @0 doubleValue];
    summary.cashBalance = [balances[@"cashBalance"] ?: @0 doubleValue];
    summary.buyingPower = [balances[@"buyingPower"] ?: @0 doubleValue];
    summary.marginUsed = [balances[@"marginUsed"] ?: @0 doubleValue];
    summary.dayPL = [balances[@"dayPL"] ?: @0 doubleValue];
    summary.dayPLPercent = [balances[@"dayPLPercent"] ?: @0 doubleValue];
    
    summary.lastUpdated = [NSDate date];
    
    return summary;
}

- (AdvancedPositionModel *)createPositionModelFromStandardizedData:(NSDictionary *)standardizedData {
    if (!standardizedData || ![standardizedData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedPositionModel *position = [[AdvancedPositionModel alloc] init];
    
    // Extract standardized position data safely
    position.symbol = [standardizedData[@"symbol"] isKindOfClass:[NSString class]] ?
                     standardizedData[@"symbol"] : @"";
    position.quantity = [standardizedData[@"quantity"] ?: @0 doubleValue];
    position.avgCost = [standardizedData[@"averagePrice"] ?: standardizedData[@"avgCost"] ?: @0 doubleValue];
    position.currentPrice = [standardizedData[@"currentPrice"] ?: @0 doubleValue];
    position.marketValue = [standardizedData[@"marketValue"] ?: @0 doubleValue];
    position.unrealizedPL = [standardizedData[@"unrealizedPL"] ?: @0 doubleValue];
    position.unrealizedPLPercent = [standardizedData[@"unrealizedPLPercent"] ?: @0 doubleValue];
    
    // Set price update timestamp
    position.priceLastUpdated = [NSDate date];
    
    return position;
}

- (AdvancedOrderModel *)createOrderModelFromStandardizedData:(NSDictionary *)standardizedData {
    if (!standardizedData || ![standardizedData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedOrderModel *order = [[AdvancedOrderModel alloc] init];
    
    // Extract standardized order data safely
    order.orderId = [standardizedData[@"orderId"] isKindOfClass:[NSString class]] ?
                   standardizedData[@"orderId"] : @"";
    order.symbol = [standardizedData[@"symbol"] isKindOfClass:[NSString class]] ?
                  standardizedData[@"symbol"] : @"";
    order.side = [standardizedData[@"side"] isKindOfClass:[NSString class]] ?
                standardizedData[@"side"] : @"";
    order.orderType = [standardizedData[@"orderType"] isKindOfClass:[NSString class]] ?
                     standardizedData[@"orderType"] : @"";
    order.status = [standardizedData[@"status"] isKindOfClass:[NSString class]] ?
                  standardizedData[@"status"] : @"";
    
    order.quantity = [standardizedData[@"quantity"] ?: @0 doubleValue];
    order.filledQuantity = [standardizedData[@"filledQuantity"] ?: @0 doubleValue];
    order.price = [standardizedData[@"price"] ?: @0 doubleValue];
    order.stopPrice = [standardizedData[@"stopPrice"] ?: @0 doubleValue];
    
    // Dates
    if ([standardizedData[@"placedTime"] isKindOfClass:[NSDate class]]) {
        order.createdDate = standardizedData[@"placedTime"];
    } else if ([standardizedData[@"createdDate"] isKindOfClass:[NSDate class]]) {
        order.createdDate = standardizedData[@"createdDate"];
    }
    
    if ([standardizedData[@"lastModified"] isKindOfClass:[NSDate class]]) {
        order.updatedDate = standardizedData[@"lastModified"];
    } else if ([standardizedData[@"updatedDate"] isKindOfClass:[NSDate class]]) {
        order.updatedDate = standardizedData[@"updatedDate"];
    }
    
    return order;
}

#pragma mark - Private Helper Methods (Simplified)

- (void)startPortfolioPollingForAccount:(NSString *)accountId {
    // Simplified polling - TODO: Implement proper timers later
    NSLog(@"📊 DataHub: Portfolio polling started for account %@ (simplified)", accountId);
}

@end
