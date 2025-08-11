//
//
//  HierarchicalWatchlistSelector.m - IMPLEMENTAZIONE SOLO SUBMENU
//

#import "HierarchicalWatchlistSelector.h"
#import "WatchlistProviderManager.h"
#import "TradingAppTypes.h"

@interface HierarchicalWatchlistSelector ()
// Simplified - no expansion state needed
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
    self.filterText = @"";
    [self setupPopUpButtonBehavior];
}

- (void)setupPopUpButtonBehavior {
    self.target = self;
    self.action = @selector(popUpSelectionChanged:);
    
    // Set initial state
    [self setTitle:self.currentDisplayText];
    self.enabled = NO; // Will be enabled after provider manager is set
}

#pragma mark - Configuration

- (void)configureWithProviderManager:(WatchlistProviderManager *)manager {
    NSLog(@"🔧 HierarchicalSelector: Configuring with provider manager");
    
    self.providerManager = manager;
    
    if (manager) {
        NSLog(@"   Provider manager has %lu total providers", (unsigned long)manager.allProviders.count);
        [self rebuildMenuStructure];
        self.enabled = YES;
    } else {
        NSLog(@"❌ Provider manager is nil!");
        [self setTitle:@"No Provider Manager"];
        self.enabled = NO;
    }
}

#pragma mark - Menu Construction (SIMPLIFIED - SOLO SUBMENU)

- (void)rebuildMenuStructure {
    if (!self.providerManager || self.isUpdatingMenu) return;
    
    self.isUpdatingMenu = YES;
    
    NSLog(@"🔧 HierarchicalSelector: Rebuilding menu structure (submenu-only)");
    NSLog(@"   Available providers: %lu", (unsigned long)self.providerManager.allProviders.count);
    NSLog(@"   Filter text: '%@'", self.filterText ?: @"");
    
    // Clear existing menu
    [[self menu] removeAllItems];
    
    // Build simple submenu structure
    [self buildSubmenuOnlyStructure];
    
    // Update display text
    [self updateDisplayTextWithoutClearingMenu];
    
    self.isUpdatingMenu = NO;
    
    NSLog(@"✅ HierarchicalSelector: Menu rebuilt with %ld categories", (long)[[self menu] numberOfItems]);
}

- (void)buildSubmenuOnlyStructure {
    NSLog(@"🏗️ Building submenu-only structure");
    
    // Define categories in order
    NSArray<NSDictionary *> *categories = @[
        @{@"name": @"Manual Watchlists", @"display": @"📝 MY LISTS", @"icon": @"📝"},
        @{@"name": @"Market Lists", @"display": @"📊 MARKET LISTS", @"icon": @"📊"},
        @{@"name": @"Baskets", @"display": @"📅 BASKETS", @"icon": @"📅"},
        @{@"name": @"Tag Lists", @"display": @"🏷️ TAG LISTS", @"icon": @"🏷️"},
        @{@"name": @"Archives", @"display": @"📦 ARCHIVES", @"icon": @"📦"}
    ];
    
    BOOL firstCategory = YES;
    
    for (NSDictionary *categoryInfo in categories) {
        NSString *categoryName = categoryInfo[@"name"];
        NSString *displayName = categoryInfo[@"display"];
        
        NSArray<id<WatchlistProvider>> *providers = [self.providerManager providersForCategory:categoryName];
        
        // Apply filter if active
        if (self.filterText && self.filterText.length > 0) {
            NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"displayName CONTAINS[cd] %@", self.filterText];
            providers = [providers filteredArrayUsingPredicate:filterPredicate];
            NSLog(@"🔍 Category '%@': %lu providers after filter", categoryName, (unsigned long)providers.count);
        }
        
        if (providers.count == 0) {
            NSLog(@"   Skipping empty category: %@", categoryName);
            continue;
        }
        
        if (!firstCategory) {
            // Add separator between categories
            [[self menu] addItem:[NSMenuItem separatorItem]];
        }
        firstCategory = NO;
        
        // Create category item with submenu
        [self addCategorySubmenu:displayName providers:providers categoryName:categoryName];
    }
    
    NSLog(@"🏗️ Submenu structure build complete");
}

- (void)addCategorySubmenu:(NSString *)displayName
                 providers:(NSArray<id<WatchlistProvider>> *)providers
              categoryName:(NSString *)categoryName {
    
    NSLog(@"📁 Creating submenu for '%@' with %lu providers", displayName, (unsigned long)providers.count);
    
    // Create main category item (always with submenu arrow >)
    NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:displayName action:nil keyEquivalent:@""];
    
    // Create submenu
    NSMenu *submenu = [[NSMenu alloc] init];
    
    // Special handling for Market Lists (needs sub-submenus for timeframes)
    if ([categoryName isEqualToString:@"Market Lists"]) {
        [self buildMarketListsSubmenu:submenu withProviders:providers];
    } else {
        // Regular submenu with direct provider items
        for (id<WatchlistProvider> provider in providers) {
            NSMenuItem *providerItem = [self createProviderMenuItem:provider];
            [submenu addItem:providerItem];
        }
    }
    
    categoryItem.submenu = submenu;
    [[self menu] addItem:categoryItem];
    
    NSLog(@"✅ Added submenu for '%@' with %lu items", displayName, (unsigned long)submenu.numberOfItems);
}

- (void)buildMarketListsSubmenu:(NSMenu *)submenu withProviders:(NSArray<id<WatchlistProvider>> *)providers {
    // Group market list providers by market type
    NSMutableDictionary<NSString *, NSMutableArray *> *groupedProviders = [NSMutableDictionary dictionary];
    
    for (id<WatchlistProvider> provider in providers) {
        if ([provider isKindOfClass:[MarketListProvider class]]) {
            MarketListProvider *marketProvider = (MarketListProvider *)provider;
            
            // Create key for market type
            NSString *typeKey = [self keyForMarketType:marketProvider.marketType];
            
            if (!groupedProviders[typeKey]) {
                groupedProviders[typeKey] = [NSMutableArray array];
            }
            [groupedProviders[typeKey] addObject:provider];
        }
    }
    
    // Create submenu items for each market type
    NSArray<NSString *> *sortedKeys = [[groupedProviders allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *typeKey in sortedKeys) {
        NSArray<id<WatchlistProvider>> *typeProviders = groupedProviders[typeKey];
        
        if (typeProviders.count == 1) {
            // Single provider - add directly
            NSMenuItem *providerItem = [self createProviderMenuItem:typeProviders.firstObject];
            [submenu addItem:providerItem];
        } else {
            // Multiple providers - create sub-submenu for timeframes
            NSString *typeDisplayName = [self displayNameForMarketTypeKey:typeKey];
            NSMenuItem *typeItem = [[NSMenuItem alloc] initWithTitle:typeDisplayName action:nil keyEquivalent:@""];
            
            NSMenu *timeframeSubmenu = [[NSMenu alloc] init];
            for (id<WatchlistProvider> provider in typeProviders) {
                NSMenuItem *timeframeItem = [self createProviderMenuItem:provider];
                [timeframeSubmenu addItem:timeframeItem];
            }
            
            typeItem.submenu = timeframeSubmenu;
            [submenu addItem:typeItem];
        }
    }
}

- (NSMenuItem *)createProviderMenuItem:(id<WatchlistProvider>)provider {
    NSString *title = provider.displayName;
    
    // Add count if provider shows count and has symbols
    if (provider.showCount && provider.isLoaded && provider.symbols.count > 0) {
        title = [NSString stringWithFormat:@"%@ (%lu)", title, (unsigned long)provider.symbols.count];
    }
    
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(providerSelected:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = provider.providerId;
    
    return item;
}

// Helper methods for market lists
- (NSString *)keyForMarketType:(MarketType)marketType {
    switch (marketType) {
        case MarketTypeSP500: return @"SP500";
        case MarketTypeNASDAQ: return @"NASDAQ";
        case MarketTypeRussell2000: return @"Russell2000";
        case MarketTypeDowJones: return @"DowJones";
        default: return @"Other";
    }
}

- (NSString *)displayNameForMarketTypeKey:(NSString *)typeKey {
    if ([typeKey isEqualToString:@"SP500"]) return @"S&P 500";
    if ([typeKey isEqualToString:@"NASDAQ"]) return @"NASDAQ";
    if ([typeKey isEqualToString:@"Russell2000"]) return @"Russell 2000";
    if ([typeKey isEqualToString:@"DowJones"]) return @"Dow Jones";
    return typeKey;
}

#pragma mark - Event Handling (SIMPLIFIED)

- (void)popUpSelectionChanged:(NSPopUpButton *)sender {
    NSMenuItem *selectedItem = [sender selectedItem];
    
    NSLog(@"🎯 HierarchicalSelector: popUpSelectionChanged called");
    NSLog(@"   Selected item: %@", selectedItem.title);
    NSLog(@"   RepresentedObject: %@", selectedItem.representedObject);
    
    if (!selectedItem || !selectedItem.representedObject) {
        NSLog(@"⚠️ No valid provider selected from menu (no representedObject)");
        return;
    }
    
    NSString *providerId = selectedItem.representedObject;
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    
    NSLog(@"🔍 Looking for provider with ID: %@", providerId);
    NSLog(@"🔍 Found provider: %@", provider ? provider.displayName : @"NOT FOUND");
    
    if (provider) {
        // Prevent loops - check if already selected
        if (self.selectedProvider && [self.selectedProvider.providerId isEqualToString:providerId]) {
            NSLog(@"⚠️ Provider already selected, avoiding delegate call");
            return;
        }
        
        // Update our selected provider
        self.selectedProvider = provider;
        [self updateDisplayTextWithoutClearingMenu];
        
        // Notify delegate about selection
        if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:didSelectProvider:)]) {
            NSLog(@"🔄 Calling delegate with provider: %@", provider.displayName);
            [self.selectorDelegate hierarchicalSelector:self didSelectProvider:provider];
        } else {
            NSLog(@"⚠️ No delegate or delegate doesn't respond to selector");
        }
    } else {
        NSLog(@"❌ Provider not found for ID: %@", providerId);
    }
}

- (void)providerSelected:(NSMenuItem *)sender {
    NSString *providerId = sender.representedObject;
    NSLog(@"🎯 HierarchicalSelector: providerSelected called with ID: %@", providerId);
    
    if (!providerId) {
        NSLog(@"❌ providerSelected: No providerId in representedObject");
        return;
    }
    
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    if (!provider) {
        NSLog(@"⚠️ Provider not found for menu selection: %@", providerId);
        return;
    }
    
    // Update our selected provider
    self.selectedProvider = provider;
    [self updateDisplayTextWithoutClearingMenu];
    
    // Notify delegate about user selection
    if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:didSelectProvider:)]) {
        NSLog(@"🔄 User selected provider from menu: %@", provider.displayName);
        [self.selectorDelegate hierarchicalSelector:self didSelectProvider:provider];
    }
}

#pragma mark - Selection Management

- (void)selectProviderWithId:(NSString *)providerId {
    if (!providerId) return;
    
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    if (!provider) {
        NSLog(@"⚠️ Provider not found for ID: %@", providerId);
        return;
    }
    
    // Prevent infinite loops - check if already selected
    if (self.selectedProvider && [self.selectedProvider.providerId isEqualToString:providerId]) {
        NSLog(@"✅ Provider already selected in selector: %@", provider.displayName);
        return;
    }
    
    self.selectedProvider = provider;
    [self updateDisplayTextWithoutClearingMenu];
    
    NSLog(@"✅ Selector updated to provider: %@", provider.displayName);
}

- (void)selectDefaultProvider {
    id<WatchlistProvider> defaultProvider = [self.providerManager defaultProvider];
    if (defaultProvider) {
        [self selectProviderWithId:defaultProvider.providerId];
    }
}

- (void)updateDisplayTextWithoutClearingMenu {
    if (self.selectedProvider) {
        // Show compact version of provider name
        NSString *displayName = self.selectedProvider.displayName;
        
        // Truncate long names for compact display
        if (displayName.length > 25) {
            displayName = [[displayName substringToIndex:22] stringByAppendingString:@"..."];
        }
        
        self.currentDisplayText = displayName;
    } else {
        self.currentDisplayText = @"Select Watchlist...";
    }
    
    // Update button title WITHOUT clearing menu
    [self setTitle:self.currentDisplayText];
}

#pragma mark - Search Filtering

- (void)setFilterText:(NSString *)filterText {
    NSLog(@"🔍 HierarchicalSelector: setFilterText called with: '%@'", filterText);
    
    _filterText = filterText ? [filterText copy] : @"";
    
    // Rebuild menu with filter applied
    [self rebuildMenuStructure];
}

- (void)clearFilter {
    NSLog(@"🔍 HierarchicalSelector: clearFilter called");
    self.filterText = @"";
}

#pragma mark - Public Interface

- (void)updateProviderCounts {
    if (self.isUpdatingMenu) return;
    
    // Simple rebuild since we don't track state anymore
    [self rebuildMenuStructure];
}

- (void)refreshMenuForCategory:(NSString *)categoryName {
    // Refresh providers for specific category and rebuild menu
    [self.providerManager refreshProvidersForCategory:categoryName];
    [self rebuildMenuStructure];
}

- (void)setProviderManager:(WatchlistProviderManager *)providerManager {
    _providerManager = providerManager;
    
    if (providerManager) {
        [self rebuildMenuStructure];
        self.enabled = YES;
    } else {
        self.enabled = NO;
    }
}

#pragma mark - NSPopUpButton Overrides

- (void)mouseDown:(NSEvent *)event {
    // Notify delegate that menu will be shown
    if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:willShowMenuForCategory:)]) {
        // Notify for all categories since we can't know which will be accessed
        NSArray<NSString *> *categories = @[@"Manual Watchlists", @"Market Lists", @"Baskets", @"Tag Lists", @"Archives"];
        for (NSString *categoryName in categories) {
            [self.selectorDelegate hierarchicalSelector:self willShowMenuForCategory:categoryName];
        }
    }
    
    [super mouseDown:event];
}

@end
