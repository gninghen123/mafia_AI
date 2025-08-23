//
//  DataHub+Portfolio.m
//  TradingApp
//
//  Implementation of multi-account portfolio management
//

#import "DataHub+Portfolio.h"
#import "DataManager+Portfolio.h"  // ✅ AGGIUNTO IMPORT
#import "DataHub+MarketData.h"     // ✅ AGGIUNTO IMPORT per subscribeToQuoteUpdatesForSymbol
#import "SchwabDataSource.h"
#import "DataHub+Private.h"

// Portfolio notification names
NSString * const PortfolioAccountsUpdatedNotification = @"PortfolioAccountsUpdatedNotification";
NSString * const PortfolioSummaryUpdatedNotification = @"PortfolioSummaryUpdatedNotification";
NSString * const PortfolioPositionsUpdatedNotification = @"PortfolioPositionsUpdatedNotification";
NSString * const PortfolioOrdersUpdatedNotification = @"PortfolioOrdersUpdatedNotification";
NSString * const PortfolioOrderStatusChangedNotification = @"PortfolioOrderStatusChangedNotification";
NSString * const PortfolioOrderFilledNotification = @"PortfolioOrderFilledNotification";

@implementation DataHub (Portfolio)

#pragma mark - Account Discovery

- (void)getAvailableAccountsWithCompletion:(void(^)(NSArray<AccountModel *> *accounts, NSError *error))completion {
    if (!completion) return;
    
    NSLog(@"📱 DataHub: Getting available accounts across all brokers");
    
    // Request accounts from DataManager (which will use DownloadManager to select best source)
    [[DataManager sharedManager] requestAccountsWithCompletion:^(NSArray *rawAccounts, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to get accounts: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        // Convert raw account data to AccountModel objects
        NSMutableArray<AccountModel *> *accountModels = [NSMutableArray array];
        
        for (NSDictionary *rawAccount in rawAccounts) {
            AccountModel *account = [self convertRawAccountToModel:rawAccount];
            if (account) {
                [accountModels addObject:account];
            }
        }
        
        NSLog(@"✅ DataHub: Loaded %lu accounts", (unsigned long)accountModels.count);
        
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
    
    [[DataManager sharedManager] requestAccountDetails:accountId completion:^(NSDictionary *rawDetails, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        AccountModel *account = [self convertRawAccountToModel:rawDetails];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(account, nil);
        });
    }];
}

#pragma mark - Portfolio Data with Smart Caching

- (void)getPortfolioSummaryForAccount:(NSString *)accountId completion:(void(^)(PortfolioSummaryModel *summary, BOOL isFresh))completion {
    if (!accountId || !completion) return;
    
    NSString *cacheKey = [NSString stringWithFormat:@"portfolio_summary_%@", accountId];
    
    // Check cache first (30 second TTL for portfolio summary)
    PortfolioSummaryModel *cachedSummary = [self getCachedPortfolioSummary:cacheKey];
    BOOL isCacheFresh = [self isCacheFresh:cacheKey withTTL:30.0];
    
    if (isCacheFresh && cachedSummary) {
        NSLog(@"✅ DataHub: Returning fresh cached portfolio summary for account %@", accountId);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cachedSummary, YES);
        });
        return;
    }
    
    // Return stale data first if available
    if (cachedSummary) {
        NSLog(@"📤 DataHub: Returning stale cached portfolio summary for %@, fetching fresh...", accountId);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cachedSummary, NO);
        });
    }
    
    // Fetch fresh data
    [[DataManager sharedManager] requestPortfolioSummary:accountId completion:^(NSDictionary *rawSummary, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to get portfolio summary for %@: %@", accountId, error);
            if (!cachedSummary) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, NO);
                });
            }
            return;
        }
        
        PortfolioSummaryModel *summary = [self convertRawPortfolioSummaryToModel:rawSummary];
        if (summary) {
            // Cache the fresh data
            [self cachePortfolioSummary:summary forKey:cacheKey];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(summary, YES);
                
                // Broadcast update
                [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioSummaryUpdatedNotification
                                                                    object:self
                                                                  userInfo:@{@"accountId": accountId, @"summary": summary}];
            });
        }
    }];
}

- (void)getPositionsForAccount:(NSString *)accountId completion:(void(^)(NSArray<AdvancedPositionModel *> *positions, BOOL isFresh))completion {
    if (!accountId || !completion) return;
    
    NSString *cacheKey = [NSString stringWithFormat:@"positions_%@", accountId];
    
    // Check cache (5 minute TTL for position list, prices updated real-time separately)
    NSArray<AdvancedPositionModel *> *cachedPositions = [self getCachedPositions:cacheKey];
    BOOL isCacheFresh = [self isCacheFresh:cacheKey withTTL:300.0]; // 5 minutes
    
    if (isCacheFresh && cachedPositions) {
        NSLog(@"✅ DataHub: Returning fresh cached positions for account %@ (%lu positions)",
              accountId, (unsigned long)cachedPositions.count);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cachedPositions, YES);
        });
        return;
    }
    
    // Return stale data first if available
    if (cachedPositions) {
        NSLog(@"📤 DataHub: Returning stale cached positions for %@, fetching fresh...", accountId);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cachedPositions, NO);
        });
    }
    
    // Fetch fresh positions
    [[DataManager sharedManager] requestPositions:accountId completion:^(NSArray *rawPositions, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to get positions for %@: %@", accountId, error);
            if (!cachedPositions) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(@[], NO);
                });
            }
            return;
        }
        
        NSMutableArray<AdvancedPositionModel *> *positions = [NSMutableArray array];
        
        for (NSDictionary *rawPosition in rawPositions) {
            AdvancedPositionModel *position = [self convertRawPositionToModel:rawPosition];
            if (position) {
                [positions addObject:position];
            }
        }
        
        // Cache the fresh positions
        [self cachePositions:positions forKey:cacheKey];
        
        NSLog(@"✅ DataHub: Loaded %lu positions for account %@", (unsigned long)positions.count, accountId);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([positions copy], YES);
            
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
    
    NSString *cacheKey = [NSString stringWithFormat:@"orders_%@_%@", accountId, statusFilter ?: @"all"];
    
    // Different TTL based on order status
    NSTimeInterval ttl = 15.0; // 15 seconds for active orders
    if (statusFilter && ([statusFilter isEqualToString:@"FILLED"] || [statusFilter isEqualToString:@"CANCELLED"])) {
        ttl = 300.0; // 5 minutes for completed orders
    }
    
    // Check cache
    NSArray<AdvancedOrderModel *> *cachedOrders = [self getCachedOrders:cacheKey];
    BOOL isCacheFresh = [self isCacheFresh:cacheKey withTTL:ttl];
    
    if (isCacheFresh && cachedOrders) {
        NSLog(@"✅ DataHub: Returning fresh cached orders for account %@ (filter: %@, %lu orders)",
              accountId, statusFilter ?: @"all", (unsigned long)cachedOrders.count);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cachedOrders, YES);
        });
        return;
    }
    
    // Return stale data first
    if (cachedOrders) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cachedOrders, NO);
        });
    }
    
    // Fetch fresh orders
    [[DataManager sharedManager] requestOrders:accountId withStatus:statusFilter completion:^(NSArray *rawOrders, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to get orders for %@: %@", accountId, error);
            if (!cachedOrders) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(@[], NO);
                });
            }
            return;
        }
        
        NSMutableArray<AdvancedOrderModel *> *orders = [NSMutableArray array];
        
        for (NSDictionary *rawOrder in rawOrders) {
            AdvancedOrderModel *order = [self convertRawOrderToModel:rawOrder];
            if (order) {
                [orders addObject:order];
            }
        }
        
        // Cache the fresh orders
        [self cacheOrders:orders forKey:cacheKey];
        
        NSLog(@"✅ DataHub: Loaded %lu orders for account %@", (unsigned long)orders.count, accountId);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([orders copy], YES);
            
            // Broadcast update
            [[NSNotificationCenter defaultCenter] postNotificationName:PortfolioOrdersUpdatedNotification
                                                                object:self
                                                              userInfo:@{@"accountId": accountId, @"orders": orders}];
        });
    }];
}

#pragma mark - Smart Subscription System

- (void)subscribeToPortfolioUpdatesForAccount:(NSString *)accountId {
    if (!accountId) return;
    
    NSLog(@"📡 DataHub: Subscribing to portfolio updates for account %@", accountId);
    
    // Stop any existing portfolio subscription
    [self stopPortfolioPollingForCurrentAccount];
    
    // Store current account
    [[NSUserDefaults standardUserDefaults] setObject:accountId forKey:@"CurrentPortfolioAccountId"];
    
    // Load positions to get symbols for real-time pricing
    [self getPositionsForAccount:accountId completion:^(NSArray<AdvancedPositionModel *> *positions, BOOL isFresh) {
        
        // Subscribe to real-time prices for all position symbols
        NSMutableSet *symbols = [NSMutableSet set];
        for (AdvancedPositionModel *position in positions) {
            [symbols addObject:position.symbol];
        }
        
        NSLog(@"📈 DataHub: Subscribing to real-time prices for %lu symbols in account %@",
              (unsigned long)symbols.count, accountId);
        
        for (NSString *symbol in symbols) {
            [self subscribeToQuoteUpdatesForSymbol:symbol];
        }
        
        // Start portfolio-specific polling timers
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

#pragma mark - Helper Methods (Private Implementation)

- (AccountModel *)convertRawAccountToModel:(NSDictionary *)rawAccount {
    if (!rawAccount || ![rawAccount isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AccountModel *account = [[AccountModel alloc] init];
    
    // Map common fields from Schwab API response
    account.accountId = rawAccount[@"accountNumber"] ?: rawAccount[@"accountId"] ?: @"";
    account.accountType = rawAccount[@"type"] ?: rawAccount[@"accountType"] ?: @"UNKNOWN";
    account.brokerName = @"SCHWAB"; // Default to Schwab for now
    account.displayName = [NSString stringWithFormat:@"SCHWAB-%@", [account.accountId substringFromIndex:MAX(0, (NSInteger)account.accountId.length - 4)]];
    account.isConnected = YES; // If we got data, assume connected
    account.isPrimary = NO; // Will be set elsewhere
    account.lastUpdated = [NSDate date];
    
    NSLog(@"🔄 Converted raw account to AccountModel: %@", account.displayName);
    
    return account;
}

- (PortfolioSummaryModel *)convertRawPortfolioSummaryToModel:(NSDictionary *)rawSummary {
    if (!rawSummary || ![rawSummary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    PortfolioSummaryModel *summary = [[PortfolioSummaryModel alloc] init];
    
    // Map Schwab API fields to our model
    summary.accountId = rawSummary[@"accountNumber"] ?: rawSummary[@"accountId"] ?: @"";
    summary.brokerName = @"SCHWAB";
    
    // Extract portfolio values
    NSDictionary *balances = rawSummary[@"currentBalances"] ?: rawSummary[@"balances"] ?: rawSummary;
    
    summary.totalValue = [balances[@"liquidationValue"] doubleValue] ?: [balances[@"totalValue"] doubleValue];
    summary.dayPL = [balances[@"dayPL"] doubleValue] ?: 0.0;
    summary.dayPLPercent = [balances[@"dayPLPercent"] doubleValue] ?: 0.0;
    summary.buyingPower = [balances[@"buyingPower"] doubleValue] ?: [balances[@"availableFunds"] doubleValue];
    summary.cashBalance = [balances[@"cashBalance"] doubleValue] ?: [balances[@"moneyMarketFund"] doubleValue];
    summary.marginUsed = [balances[@"marginUsed"] doubleValue] ?: 0.0;
    summary.dayTradesLeft = [balances[@"dayTradesLeft"] integerValue] ?: 3; // Default PDT limit
    summary.lastUpdated = [NSDate date];
    
    NSLog(@"🔄 Converted raw portfolio summary - Total: $%.0f, Day P&L: $%.0f",
          summary.totalValue, summary.dayPL);
    
    return summary;
}

- (AdvancedPositionModel *)convertRawPositionToModel:(NSDictionary *)rawPosition {
    if (!rawPosition || ![rawPosition isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedPositionModel *position = [[AdvancedPositionModel alloc] init];
    
    // Extract instrument info
    NSDictionary *instrument = rawPosition[@"instrument"] ?: @{};
    position.symbol = instrument[@"symbol"] ?: rawPosition[@"symbol"] ?: @"";
    position.accountId = rawPosition[@"accountNumber"] ?: rawPosition[@"accountId"] ?: @"";
    
    // Position quantities and costs
    position.quantity = [rawPosition[@"longQuantity"] doubleValue] - [rawPosition[@"shortQuantity"] doubleValue];
    position.avgCost = [rawPosition[@"averagePrice"] doubleValue] ?: [rawPosition[@"averageCost"] doubleValue];
    
    // Market data (will be updated real-time)
    position.currentPrice = [rawPosition[@"marketValue"] doubleValue] / MAX(1, ABS(position.quantity));
    position.marketValue = [rawPosition[@"marketValue"] doubleValue];
    
    // P&L calculations
    double totalCost = position.quantity * position.avgCost;
    position.unrealizedPL = position.marketValue - totalCost;
    if (totalCost != 0) {
        position.unrealizedPLPercent = (position.unrealizedPL / totalCost) * 100.0;
    }
    
    position.priceLastUpdated = [NSDate date];
    
    NSLog(@"🔄 Converted raw position - %@ %.0f shares @ $%.2f",
          position.symbol, position.quantity, position.avgCost);
    
    return position;
}

- (AdvancedOrderModel *)convertRawOrderToModel:(NSDictionary *)rawOrder {
    if (!rawOrder || ![rawOrder isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    AdvancedOrderModel *order = [[AdvancedOrderModel alloc] init];
    
    // Basic order info
    order.orderId = rawOrder[@"orderId"] ?: rawOrder[@"orderNumber"] ?: @"";
    order.accountId = rawOrder[@"accountNumber"] ?: rawOrder[@"accountId"] ?: @"";
    order.status = rawOrder[@"status"] ?: @"UNKNOWN";
    order.orderType = rawOrder[@"orderType"] ?: @"UNKNOWN";
    order.timeInForce = rawOrder[@"duration"] ?: rawOrder[@"timeInForce"] ?: @"DAY";
    
    // Extract order leg info (Schwab uses orderLegCollection)
    NSArray *orderLegs = rawOrder[@"orderLegCollection"] ?: @[];
    if (orderLegs.count > 0) {
        NSDictionary *firstLeg = orderLegs[0];
        NSDictionary *instrument = firstLeg[@"instrument"] ?: @{};
        
        order.symbol = instrument[@"symbol"] ?: @"";
        order.side = firstLeg[@"instruction"] ?: @"";
        order.quantity = [firstLeg[@"quantity"] doubleValue];
        order.filledQuantity = [rawOrder[@"filledQuantity"] doubleValue];
    }
    
    // Prices
    order.price = [rawOrder[@"price"] doubleValue];
    order.stopPrice = [rawOrder[@"stopPrice"] doubleValue];
    order.avgFillPrice = [rawOrder[@"avgFillPrice"] doubleValue];
    
    // Dates
    NSString *enteredTime = rawOrder[@"enteredTime"];
    if (enteredTime) {
        // Parse ISO date string
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        order.createdDate = [formatter dateFromString:enteredTime] ?: [NSDate date];
    } else {
        order.createdDate = [NSDate date];
    }
    
    order.updatedDate = [NSDate date];
    
    NSLog(@"🔄 Converted raw order - %@ %@ %.0f %@ @ $%.2f",
          order.side, order.symbol, order.quantity, order.orderType, order.price);
    
    return order;
}

// Cache management methods
- (void)cachePortfolioSummary:(PortfolioSummaryModel *)summary forKey:(NSString *)key {
    // TODO: Implement portfolio summary caching
    NSLog(@"📝 TODO: Cache portfolio summary for key %@", key);
}

- (void)cachePositions:(NSArray *)positions forKey:(NSString *)key {
    // TODO: Implement positions caching
    NSLog(@"📝 TODO: Cache %lu positions for key %@", (unsigned long)[positions count], key);
}

- (void)cacheOrders:(NSArray *)orders forKey:(NSString *)key {
    // TODO: Implement orders caching
    NSLog(@"📝 TODO: Cache %lu orders for key %@", (unsigned long)[orders count], key);
}

- (PortfolioSummaryModel *)getCachedPortfolioSummary:(NSString *)key {
    // TODO: Implement portfolio summary cache retrieval
    NSLog(@"📝 TODO: Get cached portfolio summary for key %@", key);
    return nil;
}

- (NSArray *)getCachedPositions:(NSString *)key {
    // TODO: Implement positions cache retrieval
    NSLog(@"📝 TODO: Get cached positions for key %@", key);
    return nil;
}

- (NSArray *)getCachedOrders:(NSString *)key {
    // TODO: Implement orders cache retrieval
    NSLog(@"📝 TODO: Get cached orders for key %@", key);
    return nil;
}

- (BOOL)isCacheFresh:(NSString *)key withTTL:(NSTimeInterval)ttl {
    // TODO: Implement cache freshness check
    NSLog(@"📝 TODO: Check cache freshness for key %@ with TTL %.0fs", key, ttl);
    return NO;
}

- (void)startPortfolioPollingForAccount:(NSString *)accountId {
    // TODO: Implement portfolio-specific polling timers
    NSLog(@"📝 TODO: Start portfolio polling for account %@", accountId);
}

- (void)stopPortfolioPollingForCurrentAccount {
    // TODO: Stop existing timers
    NSLog(@"📝 TODO: Stop portfolio polling for current account");
}

@end
