//
//  WatchlistProviderManager.m - LAZY LOADING OPTIMIZED (CLEAN VERSION)
//  ✅ FIX 3: Only load essential providers immediately, others on-demand
//  ✅ FIX 4: Async tag/archive discovery
//  ✅ CLEAN: Provider implementations moved to WatchlistProviders.h/.m
//

#import "WatchlistProviderManager.h"
#import "WatchlistProviders.h" // ✅ Import our separated provider classes
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

#pragma mark - ✅ FIX 3: LAZY LOADING SYSTEM

- (void)refreshAllProviders {
    NSLog(@"🔄 ProviderManager: Refreshing providers (LAZY MODE)");
    
    // Clear existing
    [self.mutableManualProviders removeAllObjects];
    [self.mutableMarketListProviders removeAllObjects];
    [self.mutableBasketProviders removeAllObjects];
    [self.mutableTagListProviders removeAllObjects];
    [self.mutableArchiveProviders removeAllObjects];
    [self.providerCache removeAllObjects];
    
    // ✅ FIX: Only load essential providers immediately
    [self loadManualWatchlistProviders];  // Always load manual watchlists
    [self loadBasketProviders];          // Always load baskets (lightweight)
    
    // ✅ FIX: Market Lists, Tag Lists, Archives will be loaded ON DEMAND
    NSLog(@"✅ ProviderManager: Core providers loaded. Others will be lazy-loaded.");
}

- (void)ensureProvidersLoadedForCategory:(NSString *)categoryName {
    if ([categoryName isEqualToString:@"Market Lists"] && self.mutableMarketListProviders.count == 0) {
        NSLog(@"⚡ Lazy loading: Market Lists");
        [self loadMarketListProviders];
    } else if ([categoryName isEqualToString:@"Tag Lists"] && self.mutableTagListProviders.count == 0) {
        NSLog(@"⚡ Lazy loading: Tag Lists");
        [self loadTagListProvidersAsync]; // Make async
    } else if ([categoryName isEqualToString:@"Archives"] && self.mutableArchiveProviders.count == 0) {
        NSLog(@"⚡ Lazy loading: Archives");
        [self loadArchiveProvidersAsync]; // Make async
    }
}

#pragma mark - Provider Management

- (void)refreshProvidersForCategory:(NSString *)categoryName {
    if ([categoryName isEqualToString:@"Manual Watchlists"]) {
        [self loadManualWatchlistProviders];
    } else if ([categoryName isEqualToString:@"Market Lists"]) {
        [self loadMarketListProviders];
    } else if ([categoryName isEqualToString:@"Baskets"]) {
        [self loadBasketProviders];
    } else if ([categoryName isEqualToString:@"Tag Lists"]) {
        [self loadTagListProvidersAsync];
    } else if ([categoryName isEqualToString:@"Archives"]) {
        [self loadArchiveProvidersAsync];
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

#pragma mark - ✅ FIX 4: ASYNC TAG/ARCHIVE LOADING

- (void)loadTagListProvidersAsync {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<NSString *> *activeTags = [self discoverActiveTags];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Remove existing tag providers from cache
            for (id<WatchlistProvider> provider in self.mutableTagListProviders) {
                [self.providerCache removeObjectForKey:provider.providerId];
            }
            [self.mutableTagListProviders removeAllObjects];
            
            for (NSString *tag in activeTags) {
                TagListProvider *provider = [[TagListProvider alloc] initWithTag:tag];
                [self.mutableTagListProviders addObject:provider];
                self.providerCache[provider.providerId] = provider;
            }
            
            NSLog(@"🏷️ Async loaded %lu tag list providers", (unsigned long)self.mutableTagListProviders.count);
            
            // Notify any waiting UI
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TagListProvidersLoaded"
                                                                object:self];
        });
    });
}

- (void)loadArchiveProvidersAsync {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<NSString *> *archiveKeys = [self discoverAvailableArchives];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Remove existing archive providers from cache
            for (id<WatchlistProvider> provider in self.mutableArchiveProviders) {
                [self.providerCache removeObjectForKey:provider.providerId];
            }
            [self.mutableArchiveProviders removeAllObjects];
            
            for (NSString *archiveKey in archiveKeys) {
                ArchiveProvider *provider = [[ArchiveProvider alloc] initWithArchiveKey:archiveKey];
                [self.mutableArchiveProviders addObject:provider];
                self.providerCache[provider.providerId] = provider;
            }
            
            NSLog(@"📦 Async loaded %lu archive providers", (unsigned long)self.mutableArchiveProviders.count);
            
            // Notify any waiting UI
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ArchiveProvidersLoaded"
                                                                object:self];
        });
    });
}

- (void)loadTagListProviders {
    // Fallback sync version for backward compatibility
    [self loadTagListProvidersAsync];
}

- (void)loadArchiveProviders {
    // Fallback sync version for backward compatibility
    [self loadArchiveProvidersAsync];
}

#pragma mark - Public Properties

- (NSArray<id<WatchlistProvider>> *)manualWatchlistProviders {
    return [self.mutableManualProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)marketListProviders {
    // Ensure loaded on access
    [self ensureProvidersLoadedForCategory:@"Market Lists"];
    return [self.mutableMarketListProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)basketProviders {
    return [self.mutableBasketProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)tagListProviders {
    // Ensure loaded on access
    [self ensureProvidersLoadedForCategory:@"Tag Lists"];
    return [self.mutableTagListProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)archiveProviders {
    // Ensure loaded on access
    [self ensureProvidersLoadedForCategory:@"Archives"];
    return [self.mutableArchiveProviders copy];
}

- (NSArray<id<WatchlistProvider>> *)allProviders {
    NSMutableArray *all = [NSMutableArray array];
    [all addObjectsFromArray:self.mutableManualProviders];
    [all addObjectsFromArray:self.marketListProviders]; // This will trigger lazy loading
    [all addObjectsFromArray:self.mutableBasketProviders];
    [all addObjectsFromArray:self.tagListProviders]; // This will trigger lazy loading
    [all addObjectsFromArray:self.archiveProviders]; // This will trigger lazy loading
    return [all copy];
}

#pragma mark - Provider Lookup

- (nullable id<WatchlistProvider>)providerWithId:(NSString *)providerId {
    return self.providerCache[providerId];
}

- (NSArray<id<WatchlistProvider>> *)providersForCategory:(NSString *)categoryName {
    NSLog(@"🔍 ProviderManager: Getting providers for category: '%@'", categoryName);
    
    // ✅ FIX: Ensure providers are loaded before returning
    [self ensureProvidersLoadedForCategory:categoryName];
    
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

#pragma mark - Manual Watchlist Management

- (void)addManualWatchlistProvider:(NSString *)watchlistName {
    [self loadManualWatchlistProviders];
}

- (void)removeManualWatchlistProvider:(NSString *)watchlistName {
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

#pragma mark - Factory Methods

- (id<WatchlistProvider>)createManualWatchlistProvider:(NSString *)watchlistName {
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
    NSMutableArray<id<WatchlistProvider>> *providers = [NSMutableArray array];
    
    // Create combinations of market types and timeframes
    NSArray<NSNumber *> *marketTypes = @[
        @(MarketListTypeTopGainers),
        @(MarketListTypeTopLosers),
        @(MarketListTypeEarnings),
        @(MarketListTypeETF),
        @(MarketListTypeIndustry)
    ];
    
    NSArray<NSNumber *> *timeframes = @[
        @(MarketTimeframeOneDay),
        @(MarketTimeframeFiveDays),
        @(MarketTimeframeOneMonth),
        @(MarketTimeframeThreeMonths),
        @(MarketTimeframeFiftyTwoWeeks)
    ];
    
    for (NSNumber *marketTypeNum in marketTypes) {
        MarketListType marketType = (MarketListType)[marketTypeNum integerValue];
        for (NSNumber *timeframeNum in timeframes) {
            MarketTimeframe timeframe = (MarketTimeframe)[timeframeNum integerValue];
            
            MarketListProvider *provider = [[MarketListProvider alloc] initWithMarketType:marketType timeframe:timeframe];
            [providers addObject:provider];
        }
    }
    
    return [providers copy];
}

- (NSArray<id<WatchlistProvider>> *)createAllBasketProviders {
    return @[
        [[BasketProvider alloc] initWithBasketType:BasketTypeToday],
        [[BasketProvider alloc] initWithBasketType:BasketTypeWeek],
        [[BasketProvider alloc] initWithBasketType:BasketTypeMonth]
    ];
}

- (NSString *)displayNameForMarketType:(MarketListType)type timeframe:(MarketTimeframe)timeframe {
    MarketListProvider *provider = [[MarketListProvider alloc] initWithMarketType:type timeframe:timeframe];
    return provider.displayName;
}

- (NSString *)displayNameForBasketType:(BasketType)type {
    BasketProvider *provider = [[BasketProvider alloc] initWithBasketType:type];
    return provider.displayName;
}

- (NSString *)iconForMarketType:(MarketListType)type {
    switch (type) {
        case MarketListTypeTopGainers: return @"🚀";
        case MarketListTypeTopLosers: return @"📉";
        case MarketListTypeEarnings: return @"📊";
        case MarketListTypeETF: return @"📈";
        case MarketListTypeIndustry: return @"🏭";
        default: return @"📊";
    }
}

#pragma mark - Tag and Archive Discovery

- (void)refreshTagListProviders {
    [self loadTagListProvidersAsync];
}

- (void)refreshArchiveProviders {
    [self loadArchiveProvidersAsync];
}

- (NSArray<NSString *> *)discoverActiveTags {
    // Synchronous version for backward compatibility
    __block NSArray<NSString *> *discoveredTags = @[];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[DataHub shared] discoverAllActiveTagsWithCompletion:^(NSArray<NSString *> *tags) {
        discoveredTags = tags ?: @[];
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_semaphore_wait(semaphore, timeout);
    
    NSLog(@"🏷️ Discovered %lu active tags: %@", (unsigned long)discoveredTags.count, discoveredTags);
    return discoveredTags;
}

- (NSArray<NSString *> *)discoverAvailableArchives {
    // Synchronous version for backward compatibility
    __block NSArray<NSString *> *discoveredArchives = @[];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[DataHub shared] discoverAvailableArchivesWithCompletion:^(NSArray<NSString *> *archiveKeys) {
        discoveredArchives = archiveKeys ?: @[];
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_semaphore_wait(semaphore, timeout);
    
    NSLog(@"📦 Discovered %lu available archives: %@", (unsigned long)discoveredArchives.count, discoveredArchives);
    return discoveredArchives;
}

@end
