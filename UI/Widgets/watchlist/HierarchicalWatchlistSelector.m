//
//  HierarchicalWatchlistSelector.m - IMPLEMENTAZIONE SOLO SUBMENU
//  FIXED: Errore ARC "Implicit conversion of 'MarketListType' to 'id' is disallowed with ARC"
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
    [self setAutoenablesItems:NO];
    [self setPullsDown:NO];
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
            // Add separator
            NSMenuItem *separator = [NSMenuItem separatorItem];
            [[self menu] addItem:separator];
        }
        firstCategory = NO;
        
        NSLog(@"🏗️ Building category: %@ with %lu providers", categoryName, (unsigned long)providers.count);
        
        // Create parent menu item for category
        NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:displayName action:nil keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:displayName];
        
        // Add providers to submenu
        for (id<WatchlistProvider> provider in providers) {
            NSMenuItem *providerItem = [self createMenuItemForProvider:provider];
            [submenu addItem:providerItem];
        }
        
        [categoryItem setSubmenu:submenu];
        [[self menu] addItem:categoryItem];
        
        NSLog(@"✅ Added category '%@' with %lu items", categoryName, (unsigned long)submenu.numberOfItems);
    }
    
    NSLog(@"🏗️ Submenu structure completed with %ld categories", (long)[[self menu] numberOfItems]);
}

- (NSMenuItem *)createMenuItemForProvider:(id<WatchlistProvider>)provider {
    NSString *title = provider.displayName;
    
    // Add count if available and enabled
    if (provider.showCount && provider.isLoaded && provider.symbols.count > 0) {
        title = [NSString stringWithFormat:@"%@ (%lu)", title, (unsigned long)provider.symbols.count];
    }
    
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(providerSelected:) keyEquivalent:@""];
    item.target = self;
    
    // ✅ FIX ARC: Usa NSString invece di enum direttamente
    item.representedObject = provider.providerId;
    
    return item;
}

// ✅ FIX ARC: Helper methods corretti per market lists
- (NSString *)keyForMarketType:(MarketListType)marketType {
    switch (marketType) {
        case MarketListTypeTopGainers: return @"TopGainers";
        case MarketListTypeTopLosers: return @"TopLosers";
        case MarketListTypeEarnings: return @"Earnings";
        case MarketListTypeETF: return @"ETF";
        case MarketListTypeIndustry: return @"Industry";
        default: return @"Other";
    }
}

- (NSString *)displayNameForMarketTypeKey:(NSString *)typeKey {
    if ([typeKey isEqualToString:@"TopGainers"]) return @"🚀 Top Gainers";
    if ([typeKey isEqualToString:@"TopLosers"]) return @"📉 Top Losers";
    if ([typeKey isEqualToString:@"Earnings"]) return @"📈 Earnings";
    if ([typeKey isEqualToString:@"ETF"]) return @"🏛️ ETF";
    if ([typeKey isEqualToString:@"Industry"]) return @"🏭 Industry";
    return typeKey;
}

// ✅ FIX ARC: Metodo per convertire da stringa a enum (se necessario)
- (MarketListType)marketTypeFromKey:(NSString *)typeKey {
    if ([typeKey isEqualToString:@"TopGainers"]) return MarketListTypeTopGainers;
    if ([typeKey isEqualToString:@"TopLosers"]) return MarketListTypeTopLosers;
    if ([typeKey isEqualToString:@"Earnings"]) return MarketListTypeEarnings;
    if ([typeKey isEqualToString:@"ETF"]) return MarketListTypeETF;
    if ([typeKey isEqualToString:@"Industry"]) return MarketListTypeIndustry;
    return MarketListTypeTopGainers; // Default
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
    
    // ✅ FIX ARC: representedObject è già NSString (providerId)
    NSString *providerId = selectedItem.representedObject;
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    
    NSLog(@"🔍 Looking for provider with ID: %@", providerId);
    NSLog(@"🔍 Found provider: %@", provider ? provider.displayName : @"NOT FOUND");
    
    if (!provider) {
        NSLog(@"❌ Provider with ID '%@' not found!", providerId);
        return;
    }
    
    // Store selection
    self.selectedProvider = provider;
    
    // Update display text
    [self updateDisplayTextWithoutClearingMenu];
    
    // Notify delegate
    if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:didSelectProvider:)]) {
        NSLog(@"📢 Notifying delegate of provider selection: %@", provider.displayName);
        [self.selectorDelegate hierarchicalSelector:self didSelectProvider:provider];
    } else {
        NSLog(@"⚠️ No delegate or delegate doesn't implement didSelectProvider:");
    }
}

- (void)providerSelected:(NSMenuItem *)sender {
    NSLog(@"🎯 HierarchicalSelector: providerSelected called directly");
    NSLog(@"   Selected item: %@", sender.title);
    NSLog(@"   RepresentedObject: %@", sender.representedObject);
    
    if (!sender.representedObject) {
        NSLog(@"⚠️ No representedObject in selected menu item");
        return;
    }
    
    // ✅ FIX ARC: representedObject è NSString (providerId)
    NSString *providerId = sender.representedObject;
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    
    if (!provider) {
        NSLog(@"❌ Provider with ID '%@' not found!", providerId);
        return;
    }
    
    NSLog(@"✅ Direct provider selection: %@", provider.displayName);
    
    // Store selection
    self.selectedProvider = provider;
    
    // Update display text
    [self updateDisplayTextWithoutClearingMenu];
    
    // Notify delegate
    if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:didSelectProvider:)]) {
        NSLog(@"📢 Notifying delegate of provider selection: %@", provider.displayName);
        [self.selectorDelegate hierarchicalSelector:self didSelectProvider:provider];
    }
}

#pragma mark - Provider Selection

- (void)selectProviderWithId:(NSString *)providerId {
    NSLog(@"🎯 HierarchicalSelector: selectProviderWithId called with: %@", providerId);
    
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    
    if (!provider) {
        NSLog(@"❌ Cannot select provider with ID '%@' - not found", providerId);
        return;
    }
    
    NSLog(@"✅ Programmatic selection of provider: %@", provider.displayName);
    
    // Don't notify delegate for programmatic selection to avoid loops
    if (self.selectedProvider == provider) {
        NSLog(@"   Provider already selected, skipping notification");
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
