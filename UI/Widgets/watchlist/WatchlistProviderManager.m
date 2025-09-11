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
    NSLog(@"⚡ ensureProvidersLoadedForCategory: %@", categoryName);
    
    if ([categoryName isEqualToString:@"Market Lists"] && self.mutableMarketListProviders.count == 0) {
        NSLog(@"⚡ Force loading: Market Lists");
        [self loadMarketListProviders];
    } else if ([categoryName isEqualToString:@"Tag Lists"]) {
        // ✅ FIX: SEMPRE ricarica i tag (potrebbero essere cambiati)
        NSLog(@"⚡ Force loading: Tag Lists (always reload)");
        [self loadTagListProviders];
    } else if ([categoryName isEqualToString:@"Archives"] && self.mutableArchiveProviders.count == 0) {
        NSLog(@"⚡ Force loading: Archives");
        [self loadArchiveProviders];
    }
    
    NSLog(@"⚡ ensureProvidersLoadedForCategory completed: %@", categoryName);
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
    NSLog(@"📋 Loading Manual Watchlist Providers (excluding Archive- prefixed)");
    
    // Remove existing manual providers from cache
    for (id<WatchlistProvider> provider in self.mutableManualProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableManualProviders removeAllObjects];
    
    // Load from DataHub
    NSArray<WatchlistModel *> *watchlists = [[DataHub shared] getAllWatchlistModels];
    
    for (WatchlistModel *watchlist in watchlists) {
        // ✅ FIX: Skip watchlists with "Archive-" prefix - they belong to Archives category
        if ([watchlist.name hasPrefix:@"Archive-"]) {
            NSLog(@"   📦 Skipping archive watchlist: %@", watchlist.name);
            continue;
        }
        
        // ✅ Only create manual providers for non-archive watchlists
        ManualWatchlistProvider *provider = [[ManualWatchlistProvider alloc] initWithWatchlistModel:watchlist];
        [self.mutableManualProviders addObject:provider];
        self.providerCache[provider.providerId] = provider;
        
        NSLog(@"   📝 Added manual watchlist: %@", watchlist.name);
    }
    
    NSLog(@"✅ Loaded %lu manual watchlist providers (archives excluded)",
          (unsigned long)self.mutableManualProviders.count);
}

- (void)loadMarketListProviders {
    // ✅ CAMBIAMENTO IMPORTANTE: Non creiamo più automaticamente tutte le combinazioni
    // I provider verranno creati on-demand dalla struttura gerarchica del menu
    
    // Remove existing market providers from cache
    for (id<WatchlistProvider> provider in self.mutableMarketListProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableMarketListProviders removeAllObjects];
    
    NSLog(@"📊 Market list providers cleared - will be created on-demand via hierarchical menu");
}

- (NSArray<id<WatchlistProvider>> *)providersForCategory:(NSString *)categoryName {
    // ✅ SPECIAL CASE: Market Lists category returns empty array
    // because providers are created dynamically in the hierarchical menu
    if ([categoryName isEqualToString:@"Market Lists"]) {
        NSLog(@"📊 Market Lists category - returning empty array (hierarchical menu handles creation)");
        return @[];
    }
    
    // ✅ Standard categories return their cached providers
    if ([categoryName isEqualToString:@"Manual Watchlists"]) {
        return self.manualWatchlistProviders;
    } else if ([categoryName isEqualToString:@"Baskets"]) {
        return self.basketProviders;
    } else if ([categoryName isEqualToString:@"Tag Lists"]) {
        return self.tagListProviders;
    } else if ([categoryName isEqualToString:@"Archives"]) {
        return self.archiveProviders;
    }
    
    return @[];
}

#pragma mark - ✅ UPDATED: Provider Lookup with On-Demand Creation

- (nullable id<WatchlistProvider>)providerWithId:(NSString *)providerId {
    // ✅ Check cache first
    id<WatchlistProvider> cachedProvider = self.providerCache[providerId];
    if (cachedProvider) {
        return cachedProvider;
    }
    
    // ✅ SPECIAL CASE: Market list providers - create on demand
    if ([providerId hasPrefix:@"market:"]) {
        return [self createMarketProviderFromId:providerId];
    }
    
    // ✅ Standard provider lookup
    return nil;
}
 

#pragma mark - ✅ NEW: Dynamic Market Provider Creation

- (nullable id<WatchlistProvider>)createMarketProviderFromId:(NSString *)providerId {
    // ✅ Parse provider ID format: "market:marketType:timeframe"
    NSArray<NSString *> *components = [providerId componentsSeparatedByString:@":"];
    if (components.count != 3) {
        NSLog(@"❌ Invalid market provider ID format: %@", providerId);
        return nil;
    }
    
    MarketListType marketType = (MarketListType)[components[1] integerValue];
    MarketTimeframe timeframe = (MarketTimeframe)[components[2] integerValue];
    
    // ✅ Create and cache the provider
    MarketListProvider *provider = [[MarketListProvider alloc] initWithMarketType:marketType timeframe:timeframe];
    self.providerCache[provider.providerId] = provider;
    
    NSLog(@"✅ Created on-demand market provider: %@", provider.displayName);
    return provider;
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
    NSLog(@"🏷️ Loading tag list providers (SYNC VERSION)...");
    
    // Remove existing tag providers from cache
    for (id<WatchlistProvider> provider in self.mutableTagListProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableTagListProviders removeAllObjects];
    
    // ✅ FIX: Use sync version to avoid loading issues
    NSArray<NSString *> *activeTags = [self discoverActiveTags];
    NSLog(@"🏷️ Found %lu active tags to create providers for", (unsigned long)activeTags.count);
    
    if (activeTags.count == 0) {
        NSLog(@"⚠️ No active tags found - tag system might be empty or not working");
        return;
    }
    
    for (NSString *tag in activeTags) {
        TagListProvider *provider = [[TagListProvider alloc] initWithTag:tag];
        [self.mutableTagListProviders addObject:provider];
        self.providerCache[provider.providerId] = provider;
        NSLog(@"🏷️ Created provider for tag: %@", tag);
    }
    
    NSLog(@"✅ Loaded %lu tag list providers", (unsigned long)self.mutableTagListProviders.count);
}

- (void)loadArchiveProviders {
    NSLog(@"📦 Loading Archive Providers (Archive- prefixed only)");
    
    // Clear existing archive providers
    for (id<WatchlistProvider> provider in self.mutableArchiveProviders) {
        [self.providerCache removeObjectForKey:provider.providerId];
    }
    [self.mutableArchiveProviders removeAllObjects];
    
    // Load from DataHub - only Archive- prefixed watchlists
    NSArray<WatchlistModel *> *watchlists = [[DataHub shared] getAllWatchlistModels];
    
    for (WatchlistModel *watchlist in watchlists) {
        // ✅ FIX: Only process watchlists with "Archive-" prefix
        if (![watchlist.name hasPrefix:@"Archive-"]) {
            continue;
        }
        
        // Extract archive key (remove "Archive-" prefix)
        NSString *archiveKey = [watchlist.name substringFromIndex:8]; // "Archive-" = 8 chars
        
        // Create ArchiveProvider with the key
        ArchiveProvider *provider = [[ArchiveProvider alloc] initWithArchiveKey:archiveKey];
        [self.mutableArchiveProviders addObject:provider];
        self.providerCache[provider.providerId] = provider;
        
        NSLog(@"   📦 Added archive provider: %@ (key: %@)", watchlist.name, archiveKey);
    }
    
    NSLog(@"✅ Loaded %lu archive providers", (unsigned long)self.mutableArchiveProviders.count);
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
    // ✅ DEPRECATED: This method is no longer used for the hierarchical menu
    // but kept for compatibility. Returns empty array.
    NSLog(@"⚠️ createAllMarketListProviders called - returning empty array (hierarchical menu used instead)");
    return @[];
}

- (BOOL)isValidMarketTypeTimeframeCombination:(MarketListType)marketType timeframe:(MarketTimeframe)timeframe {
    switch (marketType) {
        case MarketListTypeTopGainers:
        case MarketListTypeTopLosers:
            // ✅ Gainers/Losers support standard timeframes
            return (timeframe == MarketTimeframePreMarket ||
                    timeframe == MarketTimeframeAfterHours ||
                    timeframe == MarketTimeframeFiveMinutes ||
                    timeframe == MarketTimeframeOneDay ||
                    timeframe == MarketTimeframeFiveDays ||
                    timeframe == MarketTimeframeOneMonth ||
                    timeframe == MarketTimeframeThreeMonths ||
                    timeframe == MarketTimeframeFiftyTwoWeeks);
            
        case MarketListTypeEarnings:
            // ✅ Earnings support earnings-specific timeframes
            return (timeframe == MarketTimeframeEarningsTodayBMO ||
                    timeframe == MarketTimeframeEarningsTodayAMC ||
                    timeframe == MarketTimeframeEarningsLast5Days ||
                    timeframe == MarketTimeframeEarningsLast10Days);
            
        case MarketListTypeETF:
        case MarketListTypeIndustry:
            // ✅ ETF/Industry require no timeframe
            return (timeframe == MarketTimeframeNone);
            
        default:
            return NO;
    }
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
    NSLog(@"🏷️ Starting tag discovery...");
    
    __block NSArray<NSString *> *discoveredTags = @[];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[DataHub shared] discoverAllActiveTagsWithCompletion:^(NSArray<NSString *> *tags) {
        discoveredTags = tags ?: @[];
        NSLog(@"🏷️ DataHub returned %lu tags: %@", (unsigned long)discoveredTags.count, discoveredTags);
        dispatch_semaphore_signal(semaphore);
    }];
    
    // ✅ FIX: Increase timeout for tag discovery
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
    long result = dispatch_semaphore_wait(semaphore, timeout);
    
    if (result != 0) {
        NSLog(@"❌ Tag discovery TIMEOUT after 5 seconds!");
        return @[];
    }
    
    NSLog(@"✅ Tag discovery completed with %lu tags", (unsigned long)discoveredTags.count);
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
