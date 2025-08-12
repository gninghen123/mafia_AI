//
//  WatchlistProviders.m
//  Concrete implementations of watchlist provider protocol
//

#import "WatchlistProviders.h"
#import "DataHub.h"
#import "DataHub+WatchlistProviders.h"

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
    // TODO: Implement market data loading based on your DataManager API
    // This is a placeholder - you'll need to implement based on your market data system
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Simulate API call delay
        [NSThread sleepForTimeInterval:0.5];
        
        // Placeholder symbols - replace with actual market data API call
        NSArray<NSString *> *mockSymbols = @[@"AAPL", @"MSFT", @"GOOGL", @"AMZN", @"TSLA"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(mockSymbols, nil);
            }
        });
    });
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
    return [NSString stringWithFormat:@"🏷️ %@", self.tag];
}

- (NSString *)categoryName {
    return @"Tag Lists";
}

- (BOOL)canAddSymbols { return NO; }
- (BOOL)canRemoveSymbols { return NO; }
- (BOOL)isAutoUpdating { return YES; }
- (BOOL)showCount { return NO; } // Don't show count until loaded

- (NSArray<NSString *> *)symbols {
    return nil; // Will be loaded on demand
}

- (BOOL)isLoaded {
    return NO; // Always load fresh from tag system
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    [[DataHub shared] getSymbolsWithTag:self.tag completion:^(NSArray<NSString *> *symbols) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ TagListProvider (%@): Loaded %lu symbols with tag '%@'",
                  [self displayName], (unsigned long)symbols.count, self.tag);
            if (completion) {
                completion(symbols ?: @[], nil);
            }
        });
    }];
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
    return [NSString stringWithFormat:@"📦 %@", self.archiveKey];
}

- (NSString *)categoryName {
    return @"Archives";
}

- (BOOL)canAddSymbols { return NO; }
- (BOOL)canRemoveSymbols { return NO; }
- (BOOL)isAutoUpdating { return NO; }
- (BOOL)showCount { return YES; }

- (NSArray<NSString *> *)symbols {
    return nil; // Will be loaded on demand
}

- (BOOL)isLoaded {
    return NO; // Always load fresh from archive system
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    // TODO: Implement archive loading based on your archive system
    // This is a placeholder - you'll need to implement based on your archive storage
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Simulate loading from archive system
        [NSThread sleepForTimeInterval:0.3];
        
        // Placeholder - replace with actual archive loading logic
        NSArray<NSString *> *archivedSymbols = @[]; // Empty for now
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ ArchiveProvider (%@): Loaded %lu symbols from archive '%@'",
                  [self displayName], (unsigned long)archivedSymbols.count, self.archiveKey);
            if (completion) {
                completion(archivedSymbols, nil);
            }
        });
    });
}

@end
