// ============================================================================
// DataHub+SmartTracking.m - SMART SYMBOL TRACKING CATEGORY
// ============================================================================
// PHILOSOPHY: Only track REAL user interactions
// - Chain symbol focus (with anti-spam)
// - Connection creation/modification (active work)
// - Tag management (active categorization)
// - NO: watchlist operations, symbol creation, market data
// ============================================================================

#import "DataHub+SmartTracking.h"
#import "DataHub+Private.h"
#import "StockConnection+CoreDataClass.h"  // ✅ ADD: For StockConnection access
#import "Symbol+CoreDataClass.h"           // ✅ ADD: For Symbol access
#import <objc/runtime.h>                   // ✅ ADD: For associated objects

// Associated object keys for category properties
static const void *kLastChainSymbolKey = &kLastChainSymbolKey;
static const void *kLastChainSymbolTimeKey = &kLastChainSymbolTimeKey;
static const void *kChainDeduplicationTimeoutKey = &kChainDeduplicationTimeoutKey;

// Smart tracking state using associated objects
@implementation DataHub (SmartTracking)

#pragma mark - Associated Properties

- (NSString *)lastChainSymbol {
    return objc_getAssociatedObject(self, kLastChainSymbolKey);
}

- (void)setLastChainSymbol:(NSString *)lastChainSymbol {
    objc_setAssociatedObject(self, kLastChainSymbolKey, lastChainSymbol, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDate *)lastChainSymbolTime {
    return objc_getAssociatedObject(self, kLastChainSymbolTimeKey);
}

- (void)setLastChainSymbolTime:(NSDate *)lastChainSymbolTime {
    objc_setAssociatedObject(self, kLastChainSymbolTimeKey, lastChainSymbolTime, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTimeInterval)chainDeduplicationTimeout {
    NSNumber *number = objc_getAssociatedObject(self, kChainDeduplicationTimeoutKey);
    return number ? [number doubleValue] : 300.0; // Default 5 minutes
}

- (void)setChainDeduplicationTimeout:(NSTimeInterval)chainDeduplicationTimeout {
    objc_setAssociatedObject(self, kChainDeduplicationTimeoutKey, @(chainDeduplicationTimeout), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Smart Tracking Initialization

- (void)initializeSmartTracking {
    // ✅ Initialize anti-spam state
    self.chainDeduplicationTimeout = 300.0; // 5 minutes default
    self.lastChainSymbol = nil;
    self.lastChainSymbolTime = nil;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // ✅ ONLY smart tracking observers
    [center addObserver:self
               selector:@selector(trackChainSymbolChange:)
                   name:@"WidgetChainUpdateNotification"  // Direct string value
                 object:nil];
    
    [center addObserver:self
               selector:@selector(trackConnectionWork:)
                   name:DataHubConnectionsUpdatedNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(trackTagWork:)
                   name:@"DataHubSymbolTagAdded"
                 object:nil];
    
    [center addObserver:self
               selector:@selector(trackTagWork:)
                   name:@"DataHubSymbolTagRemoved"
                 object:nil];
    
    NSLog(@"✅ DataHub: Smart tracking initialized (chain + connections + tags only)");
}

#pragma mark - SMART: Chain Symbol Tracking (With Anti-Spam)

- (void)trackChainSymbolChange:(NSNotification *)notification {
    // Check both possible keys for the update data
    NSDictionary *update = notification.userInfo[@"update"];
    if (!update) {
        // Try alternative key structure
        update = notification.userInfo[@"chainUpdate"];
    }
    if (!update) {
        // Try direct access to chain data
        NSArray *symbols = notification.userInfo[@"symbols"];
        NSString *action = notification.userInfo[@"action"];
        if (symbols && action) {
            update = @{@"action": action, @"symbols": symbols};
        }
    }
    if (!update) return;
    
    NSString *action = update[@"action"];
    NSArray *symbols = update[@"symbols"];
    
    if (![action isEqualToString:@"setSymbols"] || symbols.count == 0) return;
    
    // ✅ SMART: Only track the PRIMARY symbol (first in array)
    NSString *primarySymbol = symbols.firstObject;
    if (!primarySymbol || ![primarySymbol isKindOfClass:[NSString class]]) return;
    
    NSString *normalizedSymbol = primarySymbol.uppercaseString;
    NSDate *now = [NSDate date];
    
    // ✅ ANTI-SPAM: Check if same symbol as last time
    BOOL isDuplicate = NO;
    if (self.lastChainSymbol && [self.lastChainSymbol isEqualToString:normalizedSymbol]) {
        if (self.lastChainSymbolTime) {
            NSTimeInterval timeSince = [now timeIntervalSinceDate:self.lastChainSymbolTime];
            isDuplicate = (timeSince < self.chainDeduplicationTimeout);
        }
    }
    
    if (isDuplicate) {
        NSLog(@"🔄 Chain symbol %@ ignored (duplicate within %.0fs)",
              normalizedSymbol, self.chainDeduplicationTimeout);
        return;
    }
    
    // ✅ TRACK: Real user focus on this symbol
    Symbol *symbolEntity = [self getSymbolWithName:normalizedSymbol];
    if (!symbolEntity) {
        // Create symbol without initial tracking
        symbolEntity = [self createSymbolWithName:normalizedSymbol];
    }
    
    if (symbolEntity) {
        [self incrementInteractionForSymbol:symbolEntity];
        
        // Update anti-spam state
        self.lastChainSymbol = normalizedSymbol;
        self.lastChainSymbolTime = now;
        
        NSLog(@"🎯 Chain focus: %@ (interaction: %d)",
              normalizedSymbol, symbolEntity.interactionCount);
    }
}

#pragma mark - SMART: Connection Work Tracking

- (void)trackConnectionWork:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *action = userInfo[@"action"];
    StockConnection *connection = userInfo[@"connection"];
    
    // ✅ TRACK: Only when actively creating/modifying connections
    if (![action isEqualToString:@"created"] && ![action isEqualToString:@"updated"]) {
        return;
    }
    
    if (!connection || ![connection isKindOfClass:[StockConnection class]]) return;
    
    NSMutableSet<NSString *> *symbolsToTrack = [NSMutableSet set];
    
    // Collect all involved symbols
    if (connection.sourceSymbol && connection.sourceSymbol.symbol) {
        [symbolsToTrack addObject:connection.sourceSymbol.symbol];
    }
    
    for (Symbol *symbolEntity in connection.targetSymbols) {
        if ([symbolEntity isKindOfClass:[Symbol class]] && symbolEntity.symbol) {
            [symbolsToTrack addObject:symbolEntity.symbol];
        }
    }
    
    // ✅ Track each symbol (user is actively working on correlations)
    for (NSString *symbolName in symbolsToTrack) {
        Symbol *symbolEntity = [self getSymbolWithName:symbolName];
        if (symbolEntity) {
            [self incrementInteractionForSymbol:symbolEntity];
            NSLog(@"🔗 Connection work: %@ (interaction: %d)",
                  symbolName, symbolEntity.interactionCount);
        }
    }
    
    if (symbolsToTrack.count > 0) {
        NSLog(@"🔗 Connection %@: tracked %lu symbols for active work",
              action, (unsigned long)symbolsToTrack.count);
    }
}

#pragma mark - SMART: Tag Work Tracking

- (void)trackTagWork:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    Symbol *symbol = userInfo[@"symbol"];
    NSString *tag = userInfo[@"tag"];
    
    if (!symbol || ![symbol isKindOfClass:[Symbol class]]) return;
    
    // ✅ TRACK: User is actively categorizing this symbol
    [self incrementInteractionForSymbol:symbol];
    
    NSString *action = [notification.name hasSuffix:@"Added"] ? @"added" : @"removed";
    NSLog(@"🏷️ Tag %@: '%@' %@ %@ (interaction: %d)",
          action, tag, (action ? @"to" : @"from"), symbol.symbol, symbol.interactionCount);
}

#pragma mark - Configuration

- (void)setChainDeduplicationTimeout:(NSTimeInterval)timeout {
    kChainDeduplicationTimeoutKey = timeout;
    NSLog(@"⚙️ Chain deduplication timeout set to %.0f seconds", timeout);
}

- (NSTimeInterval)getChainDeduplicationTimeout {
    return self.chainDeduplicationTimeout;
}

- (void)clearChainDeduplicationState {
    self.lastChainSymbol = nil;
    self.lastChainSymbolTime = nil;
    NSLog(@"🧹 Chain deduplication state cleared");
}

#pragma mark - Debugging and Analytics

- (NSDictionary *)getSmartTrackingStats {
    NSArray<Symbol *> *allSymbols = [self getAllSymbols];
    
    NSInteger zeroInteractions = 0;
    NSInteger lowInteractions = 0;  // 1-3
    NSInteger mediumInteractions = 0; // 4-10
    NSInteger highInteractions = 0;   // 11+
    
    for (Symbol *symbol in allSymbols) {
        if (symbol.interactionCount == 0) {
            zeroInteractions++;
        } else if (symbol.interactionCount <= 3) {
            lowInteractions++;
        } else if (symbol.interactionCount <= 10) {
            mediumInteractions++;
        } else {
            highInteractions++;
        }
    }
    
    return @{
        @"totalSymbols": @(allSymbols.count),
        @"zeroInteractions": @(zeroInteractions),
        @"lowInteractions": @(lowInteractions),
        @"mediumInteractions": @(mediumInteractions),
        @"highInteractions": @(highInteractions),
        @"lastChainSymbol": self.lastChainSymbol ?: @"None",
        @"chainTimeout": @(self.chainDeduplicationTimeout)
    };
}

- (void)generateSmartTrackingReport {
    NSLog(@"\n📊 SMART TRACKING REPORT");
    NSLog(@"=========================");
    
    NSDictionary *stats = [self getSmartTrackingStats];
    NSInteger total = [stats[@"totalSymbols"] integerValue];
    
    if (total == 0) {
        NSLog(@"No symbols in database");
        return;
    }
    
    NSLog(@"📈 Interaction Distribution:");
    NSLog(@"   Zero interactions: %@ (%.1f%%)", stats[@"zeroInteractions"],
          ([stats[@"zeroInteractions"] doubleValue] * 100.0) / total);
    NSLog(@"   Low (1-3): %@ (%.1f%%)", stats[@"lowInteractions"],
          ([stats[@"lowInteractions"] doubleValue] * 100.0) / total);
    NSLog(@"   Medium (4-10): %@ (%.1f%%)", stats[@"mediumInteractions"],
          ([stats[@"mediumInteractions"] doubleValue] * 100.0) / total);
    NSLog(@"   High (11+): %@ (%.1f%%)", stats[@"highInteractions"],
          ([stats[@"highInteractions"] doubleValue] * 100.0) / total);
    
    NSLog(@"🎯 Last Chain Symbol: %@", stats[@"lastChainSymbol"]);
    NSLog(@"⏰ Chain Timeout: %@ seconds", stats[@"chainTimeout"]);
    
    NSLog(@"SMART TRACKING REPORT COMPLETE\n");
}

- (NSArray<Symbol *> *)getMostInteractedSymbols:(NSInteger)limit {
    NSArray<Symbol *> *allSymbols = [self getAllSymbols];
    
    // Sort by interaction count descending
    NSArray<Symbol *> *sortedSymbols = [allSymbols sortedArrayUsingComparator:^NSComparisonResult(Symbol *a, Symbol *b) {
        if (a.interactionCount > b.interactionCount) return NSOrderedAscending;
        if (a.interactionCount < b.interactionCount) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    // Return top N
    NSInteger actualLimit = MIN(limit, sortedSymbols.count);
    return [sortedSymbols subarrayWithRange:NSMakeRange(0, actualLimit)];
}

- (void)logTopInteractedSymbols:(NSInteger)limit {
    NSArray<Symbol *> *topSymbols = [self getMostInteractedSymbols:limit];
    
    NSLog(@"\n🏆 TOP %ld INTERACTED SYMBOLS", (long)limit);
    NSLog(@"==============================");
    
    for (NSInteger i = 0; i < topSymbols.count; i++) {
        Symbol *symbol = topSymbols[i];
        NSLog(@"%2ld. %@ (%d interactions)",
              (long)(i + 1), symbol.symbol, symbol.interactionCount);
    }
    
    NSLog(@"TOP SYMBOLS COMPLETE\n");
}

#pragma mark - Manual Testing Methods

- (void)simulateChainFocus:(NSString *)symbol {
    if (!symbol) return;
    
    NSLog(@"🧪 SIMULATE: Chain focus on %@", symbol);
    
    // Simulate the notification structure from BaseWidget.m
    NSDictionary *fakeChainUpdate = @{
        @"update": @{
            @"action": @"setSymbols",
            @"symbols": @[symbol]
        },
        @"chainColor": [NSColor systemBlueColor],
        @"sender": self
    };
    
    NSString *notificationName = @"WidgetChainUpdateNotification";
    
    NSNotification *fakeNotification = [NSNotification notificationWithName:notificationName
                                                                      object:nil
                                                                    userInfo:fakeChainUpdate];
    
    [self trackChainSymbolChange:fakeNotification];
}

- (void)simulateTagWork:(NSString *)symbol tag:(NSString *)tag action:(NSString *)action {
    if (!symbol || !tag || !action) return;
    
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    if (!symbolEntity) {
        symbolEntity = [self createSymbolWithName:symbol];
    }
    
    NSLog(@"🧪 SIMULATE: Tag %@ '%@' %@ %@", action, tag, action, symbol);
    
    NSString *notificationName = [action isEqualToString:@"added"] ?
        @"DataHubSymbolTagAdded" : @"DataHubSymbolTagRemoved";
    
    NSNotification *fakeNotification = [NSNotification notificationWithName:notificationName
                                                                      object:self
                                                                    userInfo:@{
                                                                        @"symbol": symbolEntity,
                                                                        @"tag": tag
                                                                    }];
    
    [self trackTagWork:fakeNotification];
}

@end
