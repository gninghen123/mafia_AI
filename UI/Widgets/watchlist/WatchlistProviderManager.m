//
//  WatchlistProviderManager.m
//  TradingApp
//
//  Factory and manager for all watchlist provider types
//

#import "WatchlistProviderManager.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "DataHub+WatchlistProviders.h"
#import "TradingAppTypes.h"

@interface WatchlistProviderManager ()

// Internal provider arrays
@property (nonatomic, strong) NSMutableArray<id<WatchlistProvider>> *mutableManualProviders;
@property (nonatomic, strong) NSMutableArray<id<WatchlistProvider>> *mutableMarketListProviders;
@property (nonatomic, strong) NSMutableArray<id<WatchlistProvider>> *mutableBasketProviders;
@property (nonatomic, strong) NSMutableArray<id<WatchlistProvider>> *mutableTagListProviders;
@property (nonatomic, strong) NSMutableArray<id<WatchlistProvider>> *mutableArchiveProviders;

// Provider lookup cache
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<WatchlistProvider>> *providerCache;

// User preferences
@property (nonatomic, strong) NSString *lastSelectedProviderId;

@end

@implementation WatchlistProviderManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static WatchlistProviderManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WatchlistProviderManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.mutableManualProviders = [NSMutableArray array];
    self.mutableMarketListProviders = [NSMutableArray array];
    self.mutableBasketProviders = [NSMutableArray array];
    self.mutableTagListProviders = [NSMutableArray array];
    self.mutableArchiveProviders = [NSMutableArray array];
    self.providerCache = [NSMutableDictionary dictionary];
    
    [self initializeProviders];
}

- (void)initializeProviders {
    [self refreshAllProviders];
}

#pragma mark - Public Properties

- (NSArray<id<WatchlistProvider>> *)manualWatchlistProviders {
    return [self.mutableManualProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)marketListProviders {
    return [self.mutableMarketListProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)basketProviders {
    return [self.mutableBasketProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)tagListProviders {
    return [self.mutableTagListProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)archiveProviders {
    return [self.mutableArchiveProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)allProviders {
    NSMutableArray *all = [NSMutableArray array];
    [all addObjectsFromArray:self.mutableManualProviders];
    [all addObjectsFromArray:self.mutableMarketListProviders];
    [all addObjectsFromArray:self.mutableBasketProviders];
    [all addObjectsFromArray:self.mutableTagListProviders];
    [all addObjectsFromArray:self.mutableArchiveProviders];
    return [all copy];
}

#pragma mark - Provider Lookup

- (nullable id<WatchlistProvider>)providerWithId:(NSString *)providerId {
    return self.providerCache[providerId];
}

- (NSArray<id<WatchlistProvider>> *)providersForCategory:(NSString *)categoryName {
    NSLog(@"🔍 ProviderManager: Getting providers for category: '%@'", categoryName);
    
    if ([categoryName isEqualToString:@"Manual Watchlists"]) {
        NSLog(@"   Returning %lu manual providers", (unsigned long)self.manualWatchlistProviders.count);
        return self.manualWatchlistProviders;
    } else if ([categoryName isEqualToString:@"Market Lists"]) {
        NSLog(@"   Returning %lu market providers", (unsigned long)self.marketListProviders.count);
        return self.marketListProviders;
    } else if ([categoryName isEqualToString:@"Baskets"]) {
        NSLog(@"   Returning %lu basket providers", (unsigned long)self.basketProviders.count);
        return self.basketProviders;
    } else if ([categoryName isEqualToString:@"Tag Lists"]) {
        NSLog(@"   Returning %lu tag providers", (unsigned long)self.tagListProviders.count);
        return self.tagListProviders;
    } else if ([categoryName isEqualToString:@"Archives"]) {
        NSLog(@"   Returning %lu archive providers", (unsigned long)self.archiveProviders.count);
        return self.archiveProviders;
    }
    
    NSLog(@"❌ Unknown category: '%@'", categoryName);
    return @[];
}

- (id<WatchlistProvider>)defaultProvider {
    // Priority: last selected > first manual watchlist > first basket
    if (self.lastSelectedProviderId) {
        id<WatchlistProvider> lastSelected = [self providerWithId:self.lastSelectedProviderId];
        if (lastSelected) return lastSelected;
    }
    
    if (self.mutableManualProviders.count > 0) {
        return self.mutableManualProviders.firstObject;
    }
    
    if (self.mutableBasketProviders.count > 0) {
        return self.mutableBasketProviders.firstObject;
    }
    
    return nil;
}

- (id<WatchlistProvider>)lastSelectedProvider {
    if (self.lastSelectedProviderId) {
        return [self providerWithId:self.lastSelectedProviderId];
    }
    return nil;
}

#pragma mark - Provider Management

- (void)refreshAllProviders {
    NSLog(@"🔄 ProviderManager: Refreshing all providers");
    
    [self.mutableManualProviders removeAllObjects];
    [self.mutableMarketListProviders removeAllObjects];
    [self.mutableBasketProviders removeAllObjects];
    [self.mutableTagListProviders removeAllObjects];
    [self.mutableArchiveProviders removeAllObjects];
    [self.providerCache removeAllObjects];
    
    [self loadManualWatchlistProviders];
    [self loadMarketListProviders];
    [self loadBasketProviders];
    [self loadTagListProviders];
    [self loadArchiveProviders];
    
    NSLog(@"✅ ProviderManager: Refresh complete - Total providers: %lu", (unsigned long)self.allProviders.count);
}

- (void)refreshProvidersForCategory:(NSString *)categoryName {
    if ([categoryName isEqualToString:@"Manual Watchlists"]) {
        [self loadManualWatchlistProviders];
    } else if ([categoryName isEqualToString:@"Market Lists"]) {
        [self loadMarketListProviders];
    } else if ([categoryName isEqualToString:@"Baskets"]) {
        [self loadBasketProviders];
    } else if ([categoryName isEqualToString:@"Tag Lists"]) {
        [self loadTagListProviders];
    } else if ([categoryName isEqualToString:@"Archives"]) {
        [self loadArchiveProviders];
    }
}

- (void)loadManualWatchlistProviders {
    // Remove existing manual providers from cache
    for (id<WatchlistProvider> provider in self.mutableManualProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableManualProviders removeAllObjects];
    
    // Load from DataHub
    NSArray<WatchlistModel *> *watchlists = [[DataHub shared] getAllWatchlistModels];
    
    for (WatchlistModel *watchlist in watchlists) {
        ManualWatchlistProvider *provider = [[ManualWatchlistProvider alloc] initWithWatchlistModel:watchlist];
        [self.mutableManualProviders addObject:provider];
        self.providerCache[provider.providerId] = provider;
    }
    
    NSLog(@"📋 Loaded %lu manual watchlist providers", (unsigned long)self.mutableManualProviders.count);
}

- (void)loadMarketListProviders {
    // Remove existing market providers from cache
    for (id<WatchlistProvider> provider in self.mutableMarketListProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableMarketListProviders removeAllObjects];
    
    // Create all combinations of market types and timeframes
    NSArray<id<WatchlistProvider>> *providers = [self createAllMarketListProviders];
    
    for (id<WatchlistProvider> provider in providers) {
        [self.mutableMarketListProviders addObject:provider];
        self.providerCache[provider.providerId] = provider;
    }
    
    NSLog(@"📊 Loaded %lu market list providers", (unsigned long)self.mutableMarketListProviders.count);
}

- (void)loadBasketProviders {
    NSLog(@"📅 Loading basket providers...");
    
    // Remove existing basket providers from cache
    for (id<WatchlistProvider> provider in self.mutableBasketProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableBasketProviders removeAllObjects];
    
    // Create basket providers
    NSArray<id<WatchlistProvider>> *providers = [self createAllBasketProviders];
    
    for (id<WatchlistProvider> provider in providers) {
        [self.mutableBasketProviders addObject:provider];
        self.providerCache[provider.providerId] = provider;
        NSLog(@"   Created basket provider: %@", provider.displayName);
    }
    
    NSLog(@"📅 Loaded %lu basket providers", (unsigned long)self.mutableBasketProviders.count);
}

- (void)loadTagListProviders {
    // Remove existing tag providers from cache
    for (id<WatchlistProvider> provider in self.mutableTagListProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableTagListProviders removeAllObjects];
    
    // Discover active tags
    NSArray<NSString *> *activeTags = [self discoverActiveTags];
    
    for (NSString *tag in activeTags) {
        TagListProvider *provider = [[TagListProvider alloc] initWithTag:tag];
        [self.mutableTagListProviders addObject:provider];
        self.providerCache[provider.providerId] = provider;
    }
    
    NSLog(@"🏷️ Loaded %lu tag list providers", (unsigned long)self.mutableTagListProviders.count);
}

- (void)loadArchiveProviders {
    // Remove existing archive providers from cache
    for (id<WatchlistProvider> provider in self.mutableArchiveProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableArchiveProviders removeAllObjects];
    
    // Discover available archives
    NSArray<NSString *> *archiveKeys = [self discoverAvailableArchives];
    
    for (NSString *archiveKey in archiveKeys) {
        ArchiveProvider *provider = [[ArchiveProvider alloc] initWithArchiveKey:archiveKey];
        [self.mutableArchiveProviders addObject:provider];
        self.providerCache[provider.providerId] = provider;
    }
    
    NSLog(@"📦 Loaded %lu archive providers", (unsigned long)self.mutableArchiveProviders.count);
}

#pragma mark - Manual Watchlist Management

- (void)addManualWatchlistProvider:(NSString *)watchlistName {
    // This will be called when a new watchlist is created externally
    // Refresh manual providers to pick up the new one
    [self loadManualWatchlistProviders];
}

- (void)removeManualWatchlistProvider:(NSString *)watchlistName {
    // Remove from our arrays
    id<WatchlistProvider> toRemove = nil;
    for (id<WatchlistProvider> provider in self.mutableManualProviders) {
        if ([provider isKindOfClass:[ManualWatchlistProvider class]]) {
            ManualWatchlistProvider *manual = (ManualWatchlistProvider *)provider;
            if ([manual.watchlistModel.name isEqualToString:watchlistName]) {
                toRemove = provider;
                break;
            }
        }
    }
    
    if (toRemove) {
        [self.mutableManualProviders removeObject:toRemove];
        [self.providerCache removeObjectForKey:toRemove.providerId];
    }
}

#pragma mark - Tag and Archive Discovery

- (void)refreshTagListProviders {
    [self loadTagListProviders];
}

- (void)refreshArchiveProviders {
    [self loadArchiveProviders];
}

#pragma mark - Factory Methods

- (id<WatchlistProvider>)createManualWatchlistProvider:(NSString *)watchlistName {
    // Find existing watchlist model
    NSArray<WatchlistModel *> *watchlists = [[DataHub shared] getAllWatchlistModels];
    for (WatchlistModel *watchlist in watchlists) {
        if ([watchlist.name isEqualToString:watchlistName]) {
            return [[ManualWatchlistProvider alloc] initWithWatchlistModel:watchlist];
        }
    }
    return nil;
}

- (id<WatchlistProvider>)createMarketListProvider:(MarketListType)type timeframe:(MarketTimeframe)timeframe {
    return [[MarketListProvider alloc] initWithMarketType:type timeframe:timeframe];
}

- (id<WatchlistProvider>)createBasketProvider:(BasketType)type {
    return [[BasketProvider alloc] initWithBasketType:type];
}

- (id<WatchlistProvider>)createTagListProvider:(NSString *)tag {
    return [[TagListProvider alloc] initWithTag:tag];
}

- (id<WatchlistProvider>)createArchiveProvider:(NSString *)archiveKey {
    return [[ArchiveProvider alloc] initWithArchiveKey:archiveKey];
}

#pragma mark - Convenience Methods

- (NSArray<id<WatchlistProvider>> *)createAllMarketListProviders {
    NSMutableArray *providers = [NSMutableArray array];
    
    // Create providers for all combinations
    for (NSInteger marketType = MarketListTypeTopGainers; marketType <= MarketListTypeIndustry; marketType++) {
        for (NSInteger timeframe = MarketTimeframePreMarket; timeframe <= MarketTimeframeFiftyTwoWeeks; timeframe++) {
            MarketListProvider *provider = [[MarketListProvider alloc] initWithMarketType:marketType timeframe:timeframe];
            [providers addObject:provider];
        }
    }
    
    return [providers copy];
}

- (NSString *)displayNameForMarketType:(MarketListType)type timeframe:(MarketTimeframe)timeframe {
    NSString *typeString = [self stringForMarketType:type];
    NSString *timeframeString = [self stringForMarketTimeframe:timeframe];
    return [NSString stringWithFormat:@"%@ - %@", typeString, timeframeString];
}

- (NSString *)iconForMarketType:(MarketListType)type {
    switch (type) {
        case MarketListTypeTopGainers: return @"🚀";
        case MarketListTypeTopLosers: return @"📉";
        case MarketListTypeEarnings: return @"💰";
        case MarketListTypeETF: return @"🏛️";
        case MarketListTypeIndustry: return @"🏭";
        default: return @"📊";
    }
}

- (NSString *)stringForMarketType:(MarketListType)type {
    switch (type) {
        case MarketListTypeTopGainers: return @"🚀 Top Gainers";
        case MarketListTypeTopLosers: return @"📉 Top Losers";
        case MarketListTypeEarnings: return @"💰 Earnings";
        case MarketListTypeETF: return @"🏛️ ETF";
        case MarketListTypeIndustry: return @"🏭 Industry";
        default: return @"📊 Market";
    }
}

- (NSString *)stringForMarketTimeframe:(MarketTimeframe)timeframe {
    switch (timeframe) {
        case MarketTimeframePreMarket: return @"PreMarket";
        case MarketTimeframeAfterHours: return @"AfterHours";
        case MarketTimeframeFiveMinutes: return @"5 Minutes";
        case MarketTimeframeOneDay: return @"1 Day";
        case MarketTimeframeFiveDays: return @"5 Days";
        case MarketTimeframeOneMonth: return @"1 Month";
        case MarketTimeframeThreeMonths: return @"3 Months";
        case MarketTimeframeFiftyTwoWeeks: return @"52 Weeks";
        default: return @"1 Day";
    }
}

- (NSArray<id<WatchlistProvider>> *)createAllBasketProviders {
    NSLog(@"📅 Creating all basket providers...");
    NSMutableArray *providers = [NSMutableArray array];
    
    // Create the 3 basket types
    for (NSInteger basketType = BasketTypeToday; basketType <= BasketTypeMonth; basketType++) {
        @try {
            NSLog(@"   Creating basket provider for type: %ld", (long)basketType);
            BasketProvider *provider = [[BasketProvider alloc] initWithBasketType:basketType];
            if (provider) {
                [providers addObject:provider];
                NSLog(@"   ✅ Created: %@", provider.displayName);
            } else {
                NSLog(@"   ❌ Failed to create provider for type: %ld", (long)basketType);
            }
        }
        @catch (NSException *exception) {
            NSLog(@"❌ Exception creating basket provider type %ld: %@", (long)basketType, exception);
        }
    }
    
    NSLog(@"📅 Created %lu basket providers total", (unsigned long)providers.count);
    return [providers copy];
}

- (NSString *)displayNameForBasketType:(BasketType)type {
    switch (type) {
        case BasketTypeToday: return @"📅 TODAY";
        case BasketTypeWeek: return @"📆 WEEK (7d)";
        case BasketTypeMonth: return @"📊 MONTH (30d)";
        default: return @"📅 Basket";
    }
}

#pragma mark - Discovery Methods

- (NSArray<NSString *> *)discoverActiveTags {
    // ✅ USA DATI REALI DA CORE DATA
    __block NSArray<NSString *> *discoveredTags = @[];
    
    // Usa metodo sincrono per compatibilità con l'interfaccia esistente
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[DataHub shared] discoverAllActiveTagsWithCompletion:^(NSArray<NSString *> *tags) {
        discoveredTags = tags ?: @[];
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Aspetta max 2 secondi
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_semaphore_wait(semaphore, timeout);
    
    NSLog(@"🏷️ Discovered %lu active tags: %@", (unsigned long)discoveredTags.count, discoveredTags);
    return discoveredTags;
}


- (NSArray<NSString *> *)discoverAvailableArchives {
    // ✅ USA DATI REALI DA FILESYSTEM
    __block NSArray<NSString *> *discoveredArchives = @[];
    
    // Usa metodo sincrono per compatibilità con l'interfaccia esistente
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[DataHub shared] discoverAvailableArchivesWithCompletion:^(NSArray<NSString *> *archiveKeys) {
        discoveredArchives = archiveKeys ?: @[];
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Aspetta max 2 secondi
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_semaphore_wait(semaphore, timeout);
    
    NSLog(@"📦 Discovered %lu available archives: %@", (unsigned long)discoveredArchives.count, discoveredArchives);
    return discoveredArchives;
}


@end

#pragma mark - Concrete Provider Implementations

// =======================================
// MANUAL WATCHLIST PROVIDER
// =======================================

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
    // Manual watchlists are always loaded (symbols come from Core Data)
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

// =======================================
// MARKET LIST PROVIDER
// =======================================

@implementation MarketListProvider

- (instancetype)initWithMarketType:(MarketListType)type timeframe:(MarketTimeframe)timeframe {
    if (self = [super init]) {
        _marketType = type;
        _timeframe = timeframe;
        _performers = nil; // Will be loaded on demand
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"market:%ld:%ld", (long)self.marketType, (long)self.timeframe];
}

- (NSString *)displayName {
    WatchlistProviderManager *manager = [WatchlistProviderManager sharedManager];
    return [manager displayNameForMarketType:self.marketType timeframe:self.timeframe];
}

- (NSString *)categoryName {
    return @"Market Lists";
}

- (BOOL)canAddSymbols { return NO; }
- (BOOL)canRemoveSymbols { return NO; }
- (BOOL)isAutoUpdating { return YES; }
- (BOOL)showCount { return NO; } // Don't show count until loaded

- (NSArray<NSString *> *)symbols {
    if (!self.performers) return nil;
    
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    for (MarketPerformerModel *performer in self.performers) {
        if (performer.symbol) {
            [symbols addObject:performer.symbol];
        }
    }
    return [symbols copy];
}

- (BOOL)isLoaded {
    return self.performers != nil;
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    // Convert enums to API strings
    NSString *listType = [self listTypeString];
    NSString *timeframeString = [self timeframeString];
    
    NSLog(@"📊 Loading market list: %@ - %@", listType, timeframeString);
    
    // Use DataHub to get market performers
    [[DataHub shared] getMarketPerformersForList:listType
                                       timeframe:timeframeString
                                      completion:^(NSArray<MarketPerformerModel *> *performers, BOOL isFresh) {
        
        self.performers = performers;
        
        NSMutableArray<NSString *> *symbols = [NSMutableArray array];
        for (MarketPerformerModel *performer in performers) {
            if (performer.symbol) {
                [symbols addObject:performer.symbol];
            }
        }
        
        NSLog(@"✅ Loaded %lu symbols for market list %@ - %@",
              (unsigned long)symbols.count, listType, timeframeString);
        
        if (completion) {
            completion([symbols copy], nil);
        }
    }];
}

- (NSString *)listTypeString {
    switch (self.marketType) {
        case MarketListTypeTopGainers: return @"gainers";
        case MarketListTypeTopLosers: return @"losers";
        case MarketListTypeEarnings: return @"earnings";
        case MarketListTypeETF: return @"etf";
        case MarketListTypeIndustry: return @"industry";
        default: return @"gainers";
    }
}

- (NSString *)timeframeString {
    switch (self.timeframe) {
        case MarketTimeframePreMarket: return @"premarket";
        case MarketTimeframeAfterHours: return @"afterhours";
        case MarketTimeframeFiveMinutes: return @"5m";
        case MarketTimeframeOneDay: return @"1d";
        case MarketTimeframeFiveDays: return @"5d";
        case MarketTimeframeOneMonth: return @"1m";
        case MarketTimeframeThreeMonths: return @"3m";
        case MarketTimeframeFiftyTwoWeeks: return @"52w";
        default: return @"1d";
    }
}

- (void)addSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // Market lists are read-only
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"WatchlistProvider"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Market lists are read-only"}];
        completion(NO, error);
    }
}

- (void)removeSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // Market lists are read-only
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"WatchlistProvider"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Market lists are read-only"}];
        completion(NO, error);
    }
}

@end

// =======================================
// BASKET PROVIDER
// =======================================

@implementation BasketProvider

- (instancetype)initWithBasketType:(BasketType)type {
    if (self = [super init]) {
        _basketType = type;
        
        // Set day range based on type
        switch (type) {
            case BasketTypeToday: _dayRange = 1; break;
            case BasketTypeWeek: _dayRange = 7; break;
            case BasketTypeMonth: _dayRange = 30; break;
        }
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"basket:%ld", (long)self.basketType];
}

- (NSString *)displayName {
    // Don't call manager during init - use direct implementation
    switch (self.basketType) {
        case BasketTypeToday: return @"📅 TODAY";
        case BasketTypeWeek: return @"📆 WEEK (7d)";
        case BasketTypeMonth: return @"📊 MONTH (30d)";
        default: return @"📅 Basket";
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
    // Will be loaded on demand
    return nil;
}

- (BOOL)isLoaded {
    return NO; // Always load fresh from interaction tracking
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    // ✅ USA DATI REALI BASATI SU INTERAZIONI
    [[DataHub shared] getSymbolsWithInteractionInLastDays:self.dayRange completion:^(NSArray<NSString *> *symbols) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ BasketProvider (%@): Loaded %lu symbols with interactions in last %ld days",
                  [self displayName], (unsigned long)symbols.count, (long)self.dayRange);
            
            if (completion) {
                completion(symbols ?: @[], nil);
            }
        });
    }];
}


- (void)addSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // Baskets are read-only (populated by interaction tracking)
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"WatchlistProvider"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Baskets are auto-populated by interaction tracking"}];
        completion(NO, error);
    }
}

- (void)removeSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // Baskets are read-only
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"WatchlistProvider"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Baskets are auto-populated by interaction tracking"}];
        completion(NO, error);
    }
}

@end

// =======================================
// TAG LIST PROVIDER
// =======================================

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
    // Will be loaded on demand
    return nil;
}

- (BOOL)isLoaded {
    return NO; // Always load fresh from tag system
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    // ✅ USA DATI REALI BASATI SU TAG
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

- (void)addSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // Tag lists are read-only (populated by tag system)
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"WatchlistProvider"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Tag lists are auto-populated by symbol tags"}];
        completion(NO, error);
    }
}

- (void)removeSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // Tag lists are read-only
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"WatchlistProvider"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Tag lists are auto-populated by symbol tags"}];
        completion(NO, error);
    }
}

@end

// =======================================
// ARCHIVE PROVIDER
// =======================================

@implementation ArchiveProvider

- (instancetype)initWithArchiveKey:(NSString *)key {
    if (self = [super init]) {
        _archiveKey = key;
        
        // Parse date from key (format: "YYYY-QX/YYYY-MM-DD")
        NSArray<NSString *> *components = [key componentsSeparatedByString:@"/"];
        if (components.count == 2) {
            NSString *dateString = components[1];
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd";
            _archiveDate = [formatter dateFromString:dateString];
        }
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"archive:%@", self.archiveKey];
}

- (NSString *)displayName {
    if (self.archiveDate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        return [NSString stringWithFormat:@"📦 %@", [formatter stringFromDate:self.archiveDate]];
    }
    return [NSString stringWithFormat:@"📦 %@", self.archiveKey];
}

- (NSString *)categoryName {
    return @"Archives";
}

- (BOOL)canAddSymbols { return NO; }
- (BOOL)canRemoveSymbols { return NO; }
- (BOOL)isAutoUpdating { return NO; }
- (BOOL)showCount { return YES; } // Show count once loaded

- (NSArray<NSString *> *)symbols {
    // Will be loaded on demand from archive files
    return nil;
}

- (BOOL)isLoaded {
    return NO; // Always load from disk
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    // ✅ USA DATI REALI DA ARCHIVI SU DISCO
    [[DataHub shared] loadArchivedBasketWithKey:self.archiveKey completion:^(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ ArchiveProvider (%@): Failed to load archive: %@", [self displayName], error.localizedDescription);
            } else {
                NSLog(@"✅ ArchiveProvider (%@): Loaded %lu symbols from archive",
                      [self displayName], (unsigned long)symbols.count);
            }
            
            if (completion) {
                completion(symbols ?: @[], error);
            }
        });
    }];
}

- (void)addSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // Archives are read-only
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"WatchlistProvider"
                                             code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: @"Archives are read-only historical data"}];
        completion(NO, error);
    }
}

- (void)removeSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // Archives are read-only
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"WatchlistProvider"
                                             code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: @"Archives are read-only historical data"}];
        completion(NO, error);
    }
}

@end
