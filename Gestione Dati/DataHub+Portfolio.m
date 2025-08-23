//
//  DataHub+Portfolio.m
//  TradingApp
//
//  Implementation of multi-account portfolio management
//

#import "DataHub+Portfolio.h"
#import "DataManager.h"
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
    // Implementation depends on broker API format
    AccountModel *account = [[AccountModel alloc] init];
    // TODO: Implement conversion based on Schwab API format
    return account;
}

- (PortfolioSummaryModel *)convertRawPortfolioSummaryToModel:(NSDictionary *)rawSummary {
    // Implementation depends on broker API format
    PortfolioSummaryModel *summary = [[PortfolioSummaryModel alloc] init];
    // TODO: Implement conversion based on Schwab API format
    return summary;
}

- (AdvancedPositionModel *)convertRawPositionToModel:(NSDictionary *)rawPosition {
    // Implementation depends on broker API format
    AdvancedPositionModel *position = [[AdvancedPositionModel alloc] init];
    // TODO: Implement conversion based on Schwab API format
    return position;
}

- (AdvancedOrderModel *)convertRawOrderToModel:(NSDictionary *)rawOrder {
    // Implementation depends on broker API format
    AdvancedOrderModel *order = [[AdvancedOrderModel alloc] init];
    // TODO: Implement conversion based on Schwab API format
    return order;
}

// Cache management methods
- (void)cachePortfolioSummary:(PortfolioSummaryModel *)summary forKey:(NSString *)key { /* TODO */ }
- (void)cachePositions:(NSArray *)positions forKey:(NSString *)key { /* TODO */ }
- (void)cacheOrders:(NSArray *)orders forKey:(NSString *)key { /* TODO */ }
- (PortfolioSummaryModel *)getCachedPortfolioSummary:(NSString *)key { return nil; /* TODO */ }
- (NSArray *)getCachedPositions:(NSString *)key { return nil; /* TODO */ }
- (NSArray *)getCachedOrders:(NSString *)key { return nil; /* TODO */ }
- (BOOL)isCacheFresh:(NSString *)key withTTL:(NSTimeInterval)ttl { return NO; /* TODO */ }

- (void)startPortfolioPollingForAccount:(NSString *)accountId {
    // TODO: Implement portfolio-specific polling timers
}

- (void)stopPortfolioPollingForCurrentAccount {
    // TODO: Stop existing timers
}

@end
