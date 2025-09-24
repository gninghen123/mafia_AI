//
//  WatchlistProviders.m
//  Concrete implementations of watchlist provider protocol
//

#import "WatchlistProviders.h"
#import "DataHub.h"
#import "DataHub+WatchlistProviders.h"
#import "DataHub+MarketData.h"
#import "TagManager.h"

@class TagManager;

#pragma mark - Manual Watchlist Provider

@implementation ManualWatchlistProvider

- (instancetype)initWithWatchlistModel:(WatchlistModel *)model {
    if (self = [super init]) {
        _watchlistModel = model;
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"manual:%@", self.watchlistModel.name];
}

- (NSString *)displayName {
    return [NSString stringWithFormat:@"📝 %@", self.watchlistModel.name];
}

- (NSString *)categoryName {
    return @"Manual Watchlists";
}

- (BOOL)canAddSymbols { return YES; }
- (BOOL)canRemoveSymbols { return YES; }
- (BOOL)isAutoUpdating { return NO; }
- (BOOL)showCount { return YES; }

- (NSArray<NSString *> *)symbols {
    return self.watchlistModel.symbols;
}

- (BOOL)isLoaded {
    return self.watchlistModel.symbols != nil;
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    if (completion) {
        completion(self.watchlistModel.symbols, nil);
    }
}

- (void)addSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    [[DataHub shared] addSymbol:symbol toWatchlistModel:self.watchlistModel];
    if (completion) {
        completion(YES, nil);
    }
}

- (void)removeSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    [[DataHub shared] removeSymbol:symbol fromWatchlistModel:self.watchlistModel];
    if (completion) {
        completion(YES, nil);
    }
}

@end

#pragma mark - Market List Provider

@implementation MarketListProvider

- (instancetype)initWithMarketType:(MarketListType)type timeframe:(MarketTimeframe)timeframe {
    if (self = [super init]) {
        _marketType = type;
        _timeframe = timeframe;
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"market:%ld:%ld", (long)self.marketType, (long)self.timeframe];
}

- (NSString *)displayName {
    // Generate display name based on market type and timeframe
    NSString *typeName;
    switch (self.marketType) {
        case MarketListTypeTopGainers:
            typeName = @"🚀 Top Gainers";
            break;
        case MarketListTypeTopLosers:
            typeName = @"📉 Top Losers";
            break;
        case MarketListTypeEarnings:
            typeName = @"📊 Earnings";
            break;
        case MarketListTypeETF:
            typeName = @"📈 ETFs";
            break;
        case MarketListTypeIndustry:
            typeName = @"🏭 Industry";
            break;
        default:
            typeName = @"📊 Market List";
            break;
    }
    
    NSString *timeframeName;
    switch (self.timeframe) {
        // ✅ Standard timeframes for Top Gainers/Losers
        case MarketTimeframePreMarket:
            timeframeName = @"Pre-Market";
            break;
        case MarketTimeframeAfterHours:
            timeframeName = @"After Hours";
            break;
        case MarketTimeframeFiveMinutes:
            timeframeName = @"5 Min";
            break;
        case MarketTimeframeOneDay:
            timeframeName = @"1 Day";
            break;
        case MarketTimeframeFiveDays:
            timeframeName = @"5 Days";
            break;
        case MarketTimeframeOneMonth:
            timeframeName = @"1 Month";
            break;
        case MarketTimeframeThreeMonths:
            timeframeName = @"3 Months";
            break;
        case MarketTimeframeFiftyTwoWeeks:
            timeframeName = @"52 Weeks";
            break;
            
        // ✅ NEW: Earnings-specific timeframes
        case MarketTimeframeEarningsTodayBMO:
            timeframeName = @"Today BMO";
            break;
        case MarketTimeframeEarningsTodayAMC:
            timeframeName = @"Today AMC";
            break;
        case MarketTimeframeEarningsLast5Days:
            timeframeName = @"Last 5 Days";
            break;
        case MarketTimeframeEarningsLast10Days:
            timeframeName = @"Last 10 Days";
            break;
            
        // ✅ NEW: No timeframe for ETF/Industry
        case MarketTimeframeNone:
            // For ETF and Industry, don't show timeframe
            return typeName;
            
        default:
            timeframeName = @"1 Day";
            break;
    }
    
    return [NSString stringWithFormat:@"%@ - %@", typeName, timeframeName];
}

- (NSString *)categoryName {
    return @"Market Lists";
}

- (BOOL)canAddSymbols { return NO; }
- (BOOL)canRemoveSymbols { return NO; }
- (BOOL)isAutoUpdating { return YES; }
- (BOOL)showCount { return YES; }

- (NSArray<NSString *> *)symbols {
    return nil; // Will be loaded on demand
}

- (BOOL)isLoaded {
    return NO; // Always load fresh from market data
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    
    // ✅ Convert enum to API strings che DataHub si aspetta
    NSString *listType = [self listTypeStringForDataHub];
    NSString *timeframe = [self timeframeStringForDataHub];
    
    NSLog(@"📊 MarketListProvider loading: %@ - %@ (via DataHub)", listType, timeframe);
    
    // ✅ CORRECT: Use the existing DataHub method
    [[DataHub shared] getMarketPerformersForList:listType
                                       timeframe:timeframe
                                      completion:^(NSArray<MarketPerformerModel *> *performers, BOOL isFresh) {
        
        // ✅ Extract symbols from MarketPerformerModel array
        NSMutableArray<NSString *> *symbols = [NSMutableArray array];
        for (MarketPerformerModel *performer in performers) {
            if (performer.symbol && performer.symbol.length > 0) {
                [symbols addObject:performer.symbol];
            }
        }
        
        NSLog(@"✅ MarketListProvider loaded %lu REAL symbols from DataHub (isFresh: %@)",
              (unsigned long)symbols.count, isFresh ? @"YES" : @"NO");
        
        // Debug: mostra alcuni simboli
        if (symbols.count > 0) {
            NSArray *sampleSymbols = [symbols subarrayWithRange:NSMakeRange(0, MIN(5, symbols.count))];
            NSLog(@"📊 Sample symbols: %@", sampleSymbols);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion([symbols copy], nil);
            }
        });
    }];
}

// ✅ CORRECT Helper methods per conversion enum -> string:

- (NSString *)listTypeStringForDataHub {
    switch (self.marketType) {
        case MarketListTypeTopGainers:
            return @"gainers";
        case MarketListTypeTopLosers:
            return @"losers";
        case MarketListTypeETF:
            return @"etf";
        case MarketListTypeEarnings:
            return @"earnings";
        case MarketListTypeIndustry:
            return @"industry";
        default:
            return @"gainers";
    }
}

// ✅ AGGIORNAMENTO del metodo per convertire timeframe in stringa per DataHub
- (NSString *)timeframeStringForDataHub {
    switch (self.timeframe) {
        case MarketTimeframePreMarket:
            return @"preMarket";
        case MarketTimeframeAfterHours:
            return @"afterMarket";
        case MarketTimeframeFiveMinutes:
            return @"5min";
        case MarketTimeframeOneDay:
            return @"1d";
        case MarketTimeframeFiveDays:
            return @"5d";
        case MarketTimeframeOneMonth:
            return @"1m";
        case MarketTimeframeThreeMonths:
            return @"3m";
        case MarketTimeframeFiftyTwoWeeks:
            return @"52w";
            
        // ✅ NEW: Earnings timeframes
        case MarketTimeframeEarningsTodayBMO:
            return @"today_bmo";
        case MarketTimeframeEarningsTodayAMC:
            return @"today_amc";
        case MarketTimeframeEarningsLast5Days:
            return @"last_5_days";
        case MarketTimeframeEarningsLast10Days:
            return @"last_10_days";
            
        // ✅ NEW: No timeframe
        case MarketTimeframeNone:
            return @""; // Empty string for ETF/Industry
            
        default:
            return @"1d";
    }
}


@end

#pragma mark - Basket Provider

@implementation BasketProvider

- (instancetype)initWithBasketType:(BasketType)type {
    if (self = [super init]) {
        _basketType = type;
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"basket:%ld", (long)self.basketType];
}

- (NSString *)displayName {
    switch (self.basketType) {
        case BasketTypeToday:
            return @"📅 Today's Symbols";
        case BasketTypeWeek:
            return @"📅 This Week";
        case BasketTypeMonth:
            return @"📅 This Month";
        default:
            return @"📅 Basket";
    }
}

- (NSString *)categoryName {
    return @"Baskets";
}

- (BOOL)canAddSymbols { return NO; }
- (BOOL)canRemoveSymbols { return NO; }
- (BOOL)isAutoUpdating { return YES; }
- (BOOL)showCount { return NO; } // Don't show count until loaded

- (NSArray<NSString *> *)symbols {
    return nil; // Will be loaded on demand
}

- (BOOL)isLoaded {
    return NO; // Always load fresh based on interactions
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    NSInteger days;
    switch (self.basketType) {
        case BasketTypeToday:
            days = 1;
            break;
        case BasketTypeWeek:
            days = 7;
            break;
        case BasketTypeMonth:
            days = 30;
            break;
        default:
            days = 1;
            break;
    }
    
    [[DataHub shared] getSymbolsWithInteractionInLastDays:days completion:^(NSArray<NSString *> *symbols) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ BasketProvider (%@): Loaded %lu symbols", [self displayName], (unsigned long)symbols.count);
            if (completion) {
                completion(symbols ?: @[], nil);
            }
        });
    }];
}

@end

#pragma mark - Tag List Provider

@implementation TagListProvider

- (instancetype)initWithTag:(NSString *)tag {
    if (self = [super init]) {
        _tag = tag;
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"tag:%@", self.tag];
}

- (NSString *)displayName {
    // ✅ ENHANCED: Show count if TagManager is ready
    TagManager *tagManager = [TagManager sharedManager];
    if (tagManager.state == TagManagerStateReady) {
        NSUInteger count = [tagManager symbolCountForTag:self.tag];
        if (count > 0) {
            return [NSString stringWithFormat:@"🏷️ %@ (%lu)", self.tag, (unsigned long)count];
        }
    }
    return [NSString stringWithFormat:@"🏷️ %@", self.tag];
}

- (NSString *)categoryName {
    return @"Tag Lists";
}

- (BOOL)canAddSymbols { return NO; }
- (BOOL)canRemoveSymbols { return NO; }
- (BOOL)isAutoUpdating { return YES; }

- (BOOL)showCount {
    // ✅ UPDATED: Show count when TagManager is ready
    return [[TagManager sharedManager] state] == TagManagerStateReady;
}

- (NSArray<NSString *> *)symbols {
    // ✅ UPDATED: Get symbols directly from TagManager
    TagManager *tagManager = [TagManager sharedManager];
    if (tagManager.state == TagManagerStateReady) {
        return [tagManager symbolsWithTag:self.tag];
    }
    return @[]; // Empty if TagManager not ready
}

- (BOOL)isLoaded {
    // ✅ UPDATED: Consider loaded if TagManager is ready and has this tag
    TagManager *tagManager = [TagManager sharedManager];
    return (tagManager.state == TagManagerStateReady) && [tagManager tagExists:self.tag];
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    // ✅ UPDATED: Use TagManager instead of DataHub async query
    TagManager *tagManager = [TagManager sharedManager];
    
    if (tagManager.state == TagManagerStateReady) {
        // ✅ IMMEDIATE: TagManager is ready, return symbols immediately
        NSArray<NSString *> *symbols = [tagManager symbolsWithTag:self.tag];
        NSLog(@"✅ TagListProvider (%@): Loaded %lu symbols with tag '%@' from TagManager",
              [self displayName], (unsigned long)symbols.count, self.tag);
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(symbols ?: @[], nil);
            });
        }
        return;
    }
    
    if (tagManager.state == TagManagerStateBuilding) {
        // ✅ WAIT: TagManager is building, wait for completion
        NSLog(@"⏳ TagListProvider (%@): TagManager building, waiting for completion...", [self displayName]);
        
        __weak typeof(self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:TagManagerDidFinishBuildingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // Remove observer (one-time use)
            [[NSNotificationCenter defaultCenter] removeObserver:strongSelf
                                                             name:TagManagerDidFinishBuildingNotification
                                                           object:nil];
            
            BOOL success = [note.userInfo[@"success"] boolValue];
            if (success) {
                // TagManager ready, try again
                [strongSelf loadSymbolsWithCompletion:completion];
            } else {
                // TagManager failed, return empty
                NSLog(@"❌ TagListProvider (%@): TagManager build failed", [strongSelf displayName]);
                if (completion) {
                    completion(@[], [NSError errorWithDomain:@"TagListProvider"
                                                        code:1
                                                    userInfo:@{NSLocalizedDescriptionKey: @"TagManager build failed"}]);
                }
            }
        }];
        return;
    }
    
    // ✅ ERROR: TagManager is in error state or empty
    NSLog(@"❌ TagListProvider (%@): TagManager not available (state: %@)",
          [self displayName], [self tagManagerStateDescription:tagManager.state]);
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], [NSError errorWithDomain:@"TagListProvider"
                                                code:2
                                            userInfo:@{NSLocalizedDescriptionKey: @"TagManager not ready"}]);
        });
    }
}

#pragma mark - Helper Methods

- (NSString *)tagManagerStateDescription:(TagManagerState)state {
    switch (state) {
        case TagManagerStateEmpty: return @"Empty";
        case TagManagerStateBuilding: return @"Building";
        case TagManagerStateReady: return @"Ready";
        case TagManagerStateError: return @"Error";
        default: return @"Unknown";
    }
}

@end


#pragma mark - Archive Provider

@implementation ArchiveProvider

- (instancetype)initWithArchiveKey:(NSString *)archiveKey {
    if (self = [super init]) {
        _archiveKey = archiveKey;
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"archive:%@", self.archiveKey];
}

- (NSString *)displayName {
    return [NSString stringWithFormat:@"📦 Archive-%@", self.archiveKey];
}

- (NSString *)categoryName {
    return @"Archives";
}

- (BOOL)canAddSymbols { return NO; }
- (BOOL)canRemoveSymbols { return NO; }
- (BOOL)isAutoUpdating { return NO; }
- (BOOL)showCount { return YES; }

- (NSArray<NSString *> *)symbols {
    // ✅ Get symbols from archived watchlist via DataHub
    WatchlistModel *archiveWatchlist = [self getArchiveWatchlist];
    return archiveWatchlist ? archiveWatchlist.symbols : @[];
}

- (BOOL)isLoaded {
    WatchlistModel *archiveWatchlist = [self getArchiveWatchlist];
    return archiveWatchlist != nil && archiveWatchlist.symbols != nil;
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        WatchlistModel *archiveWatchlist = [self getArchiveWatchlist];
        NSArray<NSString *> *symbols = archiveWatchlist ? archiveWatchlist.symbols : @[];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ ArchiveProvider (%@): Loaded %lu symbols from archive",
                  [self displayName], (unsigned long)symbols.count);
            
            if (completion) {
                completion(symbols, nil);
            }
        });
    });
}

#pragma mark - Private Helper Methods

- (WatchlistModel *)getArchiveWatchlist {
    // ✅ Find the watchlist with "Archive-{archiveKey}" name
    NSString *archiveWatchlistName = [NSString stringWithFormat:@"Archive-%@", self.archiveKey];
    
    NSArray<WatchlistModel *> *allWatchlists = [[DataHub shared] getAllWatchlistModels];
    for (WatchlistModel *watchlist in allWatchlists) {
        if ([watchlist.name isEqualToString:archiveWatchlistName]) {
            return watchlist;
        }
    }
    
    NSLog(@"⚠️ ArchiveProvider: No watchlist found with name '%@'", archiveWatchlistName);
    return nil;
}

@end
