//
//  HierarchicalWatchlistSelector.m - LAZY LOADING OPTIMIZED
//  ✅ FASE 1: Lazy menu population - carica solo categorie inizialmente
//  ✅ FASE 2: Submenu caricati solo su hover/click categoria
//  ✅ FASE 3: Simboli caricati solo su selezione provider
//

#import "HierarchicalWatchlistSelector.h"
#import "WatchlistProviderManager.h"
#import "TradingAppTypes.h"
#import "WatchlistProviders.h"  // ✅ FIX: Aggiunto import per MarketListProvider


@interface HierarchicalWatchlistSelector () <NSMenuDelegate>
// Track which categories have been loaded
@property (nonatomic, strong) NSMutableSet<NSString *> *loadedCategories;
@end

@implementation HierarchicalWatchlistSelector

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.currentDisplayText = @"Select Watchlist...";
    self.loadedCategories = [NSMutableSet set];
    
    [self setupPopUpButtonBehavior];
    [self setAutoenablesItems:NO];
    [self setPullsDown:NO];
}

- (void)setupPopUpButtonBehavior {
    self.target = self;
    self.action = @selector(popUpSelectionChanged:);
    
    [self setTitle:self.currentDisplayText];
    self.enabled = NO;
}

#pragma mark - Configuration

- (void)configureWithProviderManager:(WatchlistProviderManager *)manager {
    NSLog(@"🔧 HierarchicalSelector: Configuring with provider manager (LAZY MODE)");
    
    self.providerManager = manager;
    
    if (manager) {
        NSLog(@"   ✅ Provider manager configured - building lazy menu structure");
        [self buildLazyMenuStructure];
        self.enabled = YES;
    } else {
        NSLog(@"❌ Provider manager is nil!");
        [self setTitle:@"No Provider Manager"];
        self.enabled = NO;
    }
}

#pragma mark - ✅ LAZY MENU STRUCTURE

- (void)buildLazyMenuStructure {
    if (self.isUpdatingMenu) {
        NSLog(@"⚠️ Menu update already in progress, skipping");
        return;
    }
    
    self.isUpdatingMenu = YES;
    NSLog(@"🏗️ Building LAZY menu structure");
    
    // Clear existing menu
    [[self menu] removeAllItems];
    [self.loadedCategories removeAllObjects];
    
    // Define categories
    NSArray<NSString *> *categories = @[
        @"Manual Watchlists",
        @"Baskets",
        @"Market Lists",
       //todo @"Tag Lists",
        @"Archives"
    ];
    
    NSArray<NSString *> *categoryDisplayNames = @[
        @"📝 MY LISTS",
        @"📅 BASKETS",
        @"📊 MARKET LISTS",
        //todo@"🏷️ TAG LISTS",
        @"📦 ARCHIVES"
    ];
    
    BOOL firstCategory = YES;
    
    for (NSInteger i = 0; i < categories.count; i++) {
        NSString *categoryName = categories[i];
        NSString *displayName = categoryDisplayNames[i];
        
        if (!firstCategory) {
            [[self menu] addItem:[NSMenuItem separatorItem]];
        }
        firstCategory = NO;
        
        // ✅ FASE 1: Create category with EMPTY submenu
        NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:displayName action:nil keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:displayName];
        
        // ✅ CRITICAL: Set delegate to detect submenu opening
        submenu.delegate = self;
        
        // ✅ Store category name for lazy loading
        categoryItem.representedObject = categoryName;
        
        // ✅ Add placeholder item to show submenu arrow
        NSMenuItem *placeholderItem = [[NSMenuItem alloc] initWithTitle:@"Loading..." action:nil keyEquivalent:@""];
        placeholderItem.enabled = NO;
        [submenu addItem:placeholderItem];
        
        [categoryItem setSubmenu:submenu];
        [[self menu] addItem:categoryItem];
        
        NSLog(@"✅ Added LAZY category: %@ (submenu will load on demand)", categoryName);
    }
    
    self.isUpdatingMenu = NO;
    NSLog(@"🚀 LAZY menu structure completed - %ld categories ready for on-demand loading", (long)[[self menu] numberOfItems]);
}

#pragma mark - ✅ NSMenuDelegate - LAZY SUBMENU LOADING

- (void)menuWillOpen:(NSMenu *)menu {
    // This is called when a submenu is about to open
    NSMenuItem *parentItem = [self findParentItemForSubmenu:menu];
    if (!parentItem || !parentItem.representedObject) return;
    
    NSString *categoryName = parentItem.representedObject;
    
    // ✅ FASE 2: Load submenu content if not already loaded
    if (![self.loadedCategories containsObject:categoryName]) {
        NSLog(@"⚡ LAZY LOADING submenu for category: %@", categoryName);
        [self loadSubmenuForCategory:categoryName];
    }
}

- (NSMenuItem *)findParentItemForSubmenu:(NSMenu *)submenu {
    // Find which category item owns this submenu
    for (NSMenuItem *item in [self menu].itemArray) {
        if (item.submenu == submenu) {
            return item;
        }
    }
    return nil;
}

- (void)loadSubmenuForCategory:(NSString *)categoryName {
    if ([self.loadedCategories containsObject:categoryName]) {
        NSLog(@"⚠️ Category %@ already loaded, skipping", categoryName);
        return;
    }
    
    NSLog(@"🔄 Loading providers for category: %@", categoryName);
    
    // ✅ FASE 2: Notify delegate for potential async loading
    if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:willShowMenuForCategory:)]) {
        [self.selectorDelegate hierarchicalSelector:self willShowMenuForCategory:categoryName];
    }
    
    // ✅ Ensure providers are loaded
    [self.providerManager ensureProvidersLoadedForCategory:categoryName];
    
    // ✅ Find the submenu to populate
    NSMenuItem *categoryItem = [self findCategoryItem:categoryName];
    if (!categoryItem || !categoryItem.submenu) {
        NSLog(@"❌ Cannot find submenu for category: %@", categoryName);
        return;
    }
    
    NSMenu *submenu = categoryItem.submenu;
    
    // ✅ Clear placeholder
    [submenu removeAllItems];
    
    // ✅ SPECIAL CASE: Market Lists gets hierarchical structure
    if ([categoryName isEqualToString:@"Market Lists"]) {
        [self buildHierarchicalMarketListSubmenu:submenu];
    } else {
        // ✅ STANDARD CASE: Other categories get flat provider list
        NSArray<id<WatchlistProvider>> *providers = [self.providerManager providersForCategory:categoryName];
        NSLog(@"📊 Category %@ returned %lu providers", categoryName, (unsigned long)providers.count);
        
        if (providers.count == 0) {
            // No providers - show empty message
            NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"(No items)" action:nil keyEquivalent:@""];
            emptyItem.enabled = NO;
            [submenu addItem:emptyItem];
        } else {
            // Add all providers
            for (id<WatchlistProvider> provider in providers) {
                NSMenuItem *providerItem = [self createMenuItemForProvider:provider];
                [submenu addItem:providerItem];
            }
        }
    }
    
    // ✅ Mark as loaded
    [self.loadedCategories addObject:categoryName];
    
    NSLog(@"✅ Loaded submenu for '%@'", categoryName);
}

- (void)buildHierarchicalMarketListSubmenu:(NSMenu *)submenu {
    NSLog(@"🏗️ Building hierarchical Market Lists submenu");
    
    // ✅ Define market list structure according to requirements:
    // * topgainers -> premarket, afterhours, 5min, 1day, 5day, 1month, 3month, 52weeks
    // * toplosers -> premarket, afterhours, 5min, 1day, 5day, 1month, 3month, 52weeks
    // * earnings -> today BMO, today AMC, last 5 days, last 10 days
    // * etf -> no submenu
    // * industry -> no submenu
    
    // ✅ 1. TOP GAINERS with submenu
    NSMenuItem *gainersItem = [[NSMenuItem alloc] initWithTitle:@"🚀 Top Gainers" action:nil keyEquivalent:@""];
    NSMenu *gainersSubmenu = [[NSMenu alloc] initWithTitle:@"Top Gainers"];
    [self addTimeframeItemsToSubmenu:gainersSubmenu forMarketType:MarketListTypeTopGainers withGainerLoserTimeframes:YES];
    gainersItem.submenu = gainersSubmenu;
    [submenu addItem:gainersItem];
    
    // ✅ 2. TOP LOSERS with submenu
    NSMenuItem *losersItem = [[NSMenuItem alloc] initWithTitle:@"📉 Top Losers" action:nil keyEquivalent:@""];
    NSMenu *losersSubmenu = [[NSMenu alloc] initWithTitle:@"Top Losers"];
    [self addTimeframeItemsToSubmenu:losersSubmenu forMarketType:MarketListTypeTopLosers withGainerLoserTimeframes:YES];
    losersItem.submenu = losersSubmenu;
    [submenu addItem:losersItem];
    
    // ✅ 3. EARNINGS with submenu
    NSMenuItem *earningsItem = [[NSMenuItem alloc] initWithTitle:@"📊 Earnings" action:nil keyEquivalent:@""];
    NSMenu *earningsSubmenu = [[NSMenu alloc] initWithTitle:@"Earnings"];
    [self addTimeframeItemsToSubmenu:earningsSubmenu forMarketType:MarketListTypeEarnings withGainerLoserTimeframes:NO];
    earningsItem.submenu = earningsSubmenu;
    [submenu addItem:earningsItem];
    
    // ✅ 4. ETF (no submenu)
    NSMenuItem *etfItem = [self createDirectMarketListItem:MarketListTypeETF];
    [submenu addItem:etfItem];
    
    // ✅ 5. INDUSTRY (no submenu)
    NSMenuItem *industryItem = [self createDirectMarketListItem:MarketListTypeIndustry];
    [submenu addItem:industryItem];
    
    NSLog(@"✅ Hierarchical Market Lists submenu built with 5 main categories");
}

- (void)addTimeframeItemsToSubmenu:(NSMenu *)submenu forMarketType:(MarketListType)marketType withGainerLoserTimeframes:(BOOL)useGainerLoserTimeframes {
    
    NSArray<NSNumber *> *timeframes;
    
    if (useGainerLoserTimeframes) {
        // ✅ Top Gainers/Losers timeframes
        timeframes = @[
            @(MarketTimeframePreMarket),
            @(MarketTimeframeAfterHours),
            @(MarketTimeframeFiveMinutes),
            @(MarketTimeframeOneDay),
            @(MarketTimeframeFiveDays),
            @(MarketTimeframeOneMonth),
            @(MarketTimeframeThreeMonths),
            @(MarketTimeframeFiftyTwoWeeks)
        ];
    } else {
        // ✅ Earnings timeframes
        timeframes = @[
            @(MarketTimeframeEarningsTodayBMO),
            @(MarketTimeframeEarningsTodayAMC),
            @(MarketTimeframeEarningsLast5Days),
            @(MarketTimeframeEarningsLast10Days)
        ];
    }
    
    // ✅ Create menu item for each timeframe
    for (NSNumber *timeframeNum in timeframes) {
        MarketTimeframe timeframe = (MarketTimeframe)[timeframeNum integerValue];
        
        // ✅ Create provider for this market type + timeframe combination
        MarketListProvider *provider = [[MarketListProvider alloc] initWithMarketType:marketType timeframe:timeframe];
        
        // ✅ Create menu item
        NSMenuItem *timeframeItem = [self createMenuItemForProvider:provider];
        [submenu addItem:timeframeItem];
    }
}

- (NSMenuItem *)createDirectMarketListItem:(MarketListType)marketType {
    // ✅ Create provider with MarketTimeframeNone for ETF/Industry
    MarketListProvider *provider = [[MarketListProvider alloc] initWithMarketType:marketType timeframe:MarketTimeframeNone];
    
    // ✅ Create menu item
    return [self createMenuItemForProvider:provider];
}

// ✅ EXISTING METHOD - no changes needed, already creates proper menu items
- (NSMenuItem *)createMenuItemForProvider:(id<WatchlistProvider>)provider {
    NSString *title = provider.displayName;
    
    // ✅ FASE 3: Don't show count initially - will be loaded when selected
    // Count will be shown after provider loads symbols
    
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(providerSelected:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = provider.providerId;
    
    return item;
}

- (NSMenuItem *)findCategoryItem:(NSString *)categoryName {
    for (NSMenuItem *item in [self menu].itemArray) {
        if ([item.representedObject isEqualToString:categoryName]) {
            return item;
        }
    }
    return nil;
}




#pragma mark - Selection Handling

- (void)popUpSelectionChanged:(id)sender {
    NSMenuItem *selectedItem = [self selectedItem];
    if (!selectedItem || !selectedItem.representedObject) return;
    
    NSString *providerId = selectedItem.representedObject;
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    
    if (provider) {
        // Prevent infinite loops
        if (self.selectedProvider && [self.selectedProvider.providerId isEqualToString:provider.providerId]) {
            NSLog(@"⚠️ Same provider already selected, ignoring to prevent loop");
            return;
        }
        
        self.selectedProvider = provider;
        [self updateDisplayText:provider.displayName];
        
        // Notify delegate - this will trigger FASE 3: symbol loading
        if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:didSelectProvider:)]) {
            NSLog(@"📢 Notifying delegate of provider selection: %@", provider.displayName);
            [self.selectorDelegate hierarchicalSelector:self didSelectProvider:provider];
        }
    }
}

- (void)providerSelected:(NSMenuItem *)sender {
    NSLog(@"🎯 HierarchicalSelector: providerSelected called");
    
    if (!sender.representedObject) {
        NSLog(@"⚠️ No representedObject in selected menu item");
        return;
    }
    
    NSString *providerId = sender.representedObject;
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    
    if (!provider) {
        NSLog(@"❌ Provider with ID '%@' not found!", providerId);
        return;
    }
    
    // Prevent infinite loops
    if (self.selectedProvider && [self.selectedProvider.providerId isEqualToString:provider.providerId]) {
        NSLog(@"⚠️ Same provider already selected, ignoring to prevent loop");
        return;
    }
    
    self.selectedProvider = provider;
    [self updateDisplayText:provider.displayName];
    
    // ✅ FASE 3: This triggers symbol loading in WatchlistWidget
    if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:didSelectProvider:)]) {
        NSLog(@"📢 Notifying delegate of provider selection: %@", provider.displayName);
        [self.selectorDelegate hierarchicalSelector:self didSelectProvider:provider];
    }
}

#pragma mark - Public Interface

- (void)selectProviderWithId:(NSString *)providerId {
    if (!providerId) return;
    
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    if (provider) {
        // Prevent loops
        if (self.selectedProvider && [self.selectedProvider.providerId isEqualToString:provider.providerId]) {
            NSLog(@"⚠️ Provider %@ already selected", provider.displayName);
            return;
        }
        
        self.selectedProvider = provider;
        [self updateDisplayText:provider.displayName];
        
        // Find and select the menu item (may trigger submenu loading)
        [self selectMenuItemWithProviderId:providerId];
    }
}

- (void)selectMenuItemWithProviderId:(NSString *)providerId {
    // Search through menu and submenus - this may trigger lazy loading
    [self searchAndSelectInMenu:[self menu] providerId:providerId];
}

- (BOOL)searchAndSelectInMenu:(NSMenu *)menu providerId:(NSString *)providerId {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.representedObject isEqualToString:providerId]) {
            [self selectItem:item];
            return YES;
        }
        
        if (item.hasSubmenu) {
            // ✅ Force submenu loading if needed
            NSString *categoryName = item.representedObject;
            if (categoryName && ![self.loadedCategories containsObject:categoryName]) {
                [self loadSubmenuForCategory:categoryName];
            }
            
            if ([self searchAndSelectInMenu:item.submenu providerId:providerId]) {
                return YES;
            }
        }
    }
    return NO;
}

- (void)selectDefaultProvider {
    id<WatchlistProvider> defaultProvider = [self.providerManager defaultProvider];
    if (defaultProvider) {
        [self selectProviderWithId:defaultProvider.providerId];
    }
}

- (void)updateDisplayText:(NSString *)text {
    self.currentDisplayText = text;
    [self setTitle:text];
}

#pragma mark - Rebuild/Refresh Methods

- (void)rebuildMenuStructure {
    [self buildLazyMenuStructure];
}

- (void)updateProviderCounts {
    // Update counts for loaded categories only
    for (NSString *categoryName in self.loadedCategories) {
        NSMenuItem *categoryItem = [self findCategoryItem:categoryName];
        if (!categoryItem || !categoryItem.submenu) continue;
        
        NSArray<id<WatchlistProvider>> *providers = [self.providerManager providersForCategory:categoryName];
        
        // Update each provider item with current count
        for (NSMenuItem *item in categoryItem.submenu.itemArray) {
            if (!item.representedObject) continue;
            
            NSString *providerId = item.representedObject;
            id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
            
            if (provider && provider.showCount && provider.isLoaded && provider.symbols.count > 0) {
                NSString *baseTitle = provider.displayName;
                NSString *titleWithCount = [NSString stringWithFormat:@"%@ (%lu)", baseTitle, (unsigned long)provider.symbols.count];
                item.title = titleWithCount;
            }
        }
    }
}

#pragma mark - Search Filtering (Stub Methods)

- (void)setFilterText:(NSString *)filterText {
    _filterText = filterText ?: @"";
    // TODO: Implement search filtering if needed
}

- (void)clearFilter {
    self.filterText = @"";
    // TODO: Implement search clearing if needed
}

@end
