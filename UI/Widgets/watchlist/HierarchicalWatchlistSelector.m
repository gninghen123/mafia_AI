//
//  HierarchicalWatchlistSelector.m
//  TradingApp
//
//  Custom NSPopUpButton with hierarchical categories and submenus
//

#import "HierarchicalWatchlistSelector.h"
#import "WatchlistProviderManager.h"
#import "TradingAppTypes.h"

@implementation ProviderCategoryConfig

+ (instancetype)configWithName:(NSString *)name
                    displayName:(NSString *)displayName
                           icon:(NSString *)icon
                 alwaysExpanded:(BOOL)alwaysExpanded
               autoExpandLimit:(NSInteger)autoExpandLimit
                  rememberState:(BOOL)rememberState {
    ProviderCategoryConfig *config = [[ProviderCategoryConfig alloc] init];
    config.categoryName = name;
    config.displayName = displayName;
    config.icon = icon;
    config.alwaysExpanded = alwaysExpanded;
    config.autoExpandLimit = autoExpandLimit;
    config.rememberState = rememberState;
    return config;
}

@end

@interface HierarchicalWatchlistSelector ()

// Menu state
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *categoryItemCounts;
@property (nonatomic, assign) BOOL isPopulatingMenu;

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
    self.categoryExpansionState = [NSMutableDictionary dictionary];
    self.categoryItemCounts = [NSMutableDictionary dictionary];
    self.currentDisplayText = @"Select Watchlist...";
    
    [self setupDefaultCategoryConfigs];
    [self setupPopUpButtonBehavior];
}

- (void)setupDefaultCategoryConfigs {
    NSLog(@"🔧 Setting up default category configs");
    
    self.categoryConfigs = @[
        [ProviderCategoryConfig configWithName:@"Manual Watchlists"
                                    displayName:@"📝 MY LISTS"
                                           icon:@"📝"
                                 alwaysExpanded:NO
                               autoExpandLimit:5
                                  rememberState:YES],
        
        [ProviderCategoryConfig configWithName:@"Market Lists"
                                    displayName:@"📊 MARKET LISTS"
                                           icon:@"📊"
                                 alwaysExpanded:NO
                               autoExpandLimit:0
                                  rememberState:YES],
        
        [ProviderCategoryConfig configWithName:@"Baskets"
                                    displayName:@"📅 BASKETS"
                                           icon:@"📅"
                                 alwaysExpanded:YES
                               autoExpandLimit:10
                                  rememberState:NO],
        
        [ProviderCategoryConfig configWithName:@"Tag Lists"
                                    displayName:@"🏷️ TAG LISTS"
                                           icon:@"🏷️"
                                 alwaysExpanded:NO
                               autoExpandLimit:5
                                  rememberState:YES],
        
        [ProviderCategoryConfig configWithName:@"Archives"
                                    displayName:@"📦 ARCHIVES"
                                           icon:@"📦"
                                 alwaysExpanded:NO
                               autoExpandLimit:0
                                  rememberState:YES]
    ];
    
    for (ProviderCategoryConfig *config in self.categoryConfigs) {
        NSLog(@"   Category: '%@' -> Display: '%@'", config.categoryName, config.displayName);
    }
}

- (void)setupPopUpButtonBehavior {
    self.target = self;
    self.action = @selector(popUpSelectionChanged:);
    
    // Set initial state
    [self removeAllItems];
    [self addItemWithTitle:self.currentDisplayText];
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
        self.enabled = NO;
    }
}

#pragma mark - Menu Construction

- (void)rebuildMenuStructure {
    if (!self.providerManager || self.isUpdatingMenu) return;
    
    self.isUpdatingMenu = YES;
    
    NSLog(@"🔧 HierarchicalSelector: Rebuilding menu structure");
    NSLog(@"   Available providers: %lu", (unsigned long)self.providerManager.allProviders.count);
    
    // Clear existing menu
    [self removeAllItems];
    
    // Build hierarchical menu
    [self buildMainMenu];
    
    // Update display text
    [self updateDisplayText];
    
    self.isUpdatingMenu = NO;
    
    NSLog(@"✅ HierarchicalSelector: Menu rebuilt with %ld items", (long)self.numberOfItems);
    
    // Debug: List all menu items
    for (NSInteger i = 0; i < self.numberOfItems; i++) {
        NSMenuItem *item = [self itemAtIndex:i];
        NSLog(@"   Menu item %ld: %@", (long)i, item.title);
    }
}

- (void)buildMainMenu {
    NSLog(@"🏗️ Building main menu with categories:");
    
    BOOL firstCategory = YES;
    
    for (ProviderCategoryConfig *config in self.categoryConfigs) {
        NSArray<id<WatchlistProvider>> *providers = [self.providerManager providersForCategory:config.categoryName];
        NSLog(@"   %@ -> %lu providers", config.categoryName, (unsigned long)providers.count);
        
        if (providers.count == 0) {
            NSLog(@"   Skipping empty category: %@", config.categoryName);
            continue;
        }
        
        if (!firstCategory) {
            // Add separator between categories
            [[self menu] addItem:[NSMenuItem separatorItem]];
        }
        firstCategory = NO;
        
        [self buildCategorySection:config];
    }
    
    NSLog(@"🏗️ Main menu build complete");
}

- (void)buildCategorySection:(ProviderCategoryConfig *)config {
    NSArray<id<WatchlistProvider>> *providers = [self.providerManager providersForCategory:config.categoryName];
    
    NSLog(@"🏗️ Building category section: %@ (%lu providers)", config.categoryName, (unsigned long)providers.count);
    
    if (providers.count == 0) {
        NSLog(@"⚠️ Category %@ has no providers, skipping", config.categoryName);
        return;
    }
    
    // Store item count for this category
    self.categoryItemCounts[config.categoryName] = @(providers.count);
    
    // Determine if this category should be expanded
    BOOL isExpanded = [self shouldExpandCategory:config];
    
    NSLog(@"   Category %@ will be %@", config.categoryName, isExpanded ? @"expanded" : @"collapsed");
    
    if (isExpanded) {
        // Show providers directly under category header
        [self addCategoryHeaderItem:config expanded:YES];
        [self addProvidersDirectly:providers withIndent:YES];
    } else {
        // Show category with submenu
        [self addCategoryWithSubmenu:config providers:providers];
    }
}

- (BOOL)shouldExpandCategory:(ProviderCategoryConfig *)config {
    NSArray<id<WatchlistProvider>> *providers = [self.providerManager providersForCategory:config.categoryName];
    NSInteger providerCount = providers.count;
    
    // Always expanded categories
    if (config.alwaysExpanded) return YES;
    
    // Auto-expand if under limit
    if (config.autoExpandLimit > 0 && providerCount <= config.autoExpandLimit) return YES;
    
    // Check remembered state
    if (config.rememberState) {
        NSNumber *savedState = self.categoryExpansionState[config.categoryName];
        if (savedState) return [savedState boolValue];
    }
    
    // Default to collapsed for large categories
    return NO;
}

- (void)addCategoryHeaderItem:(ProviderCategoryConfig *)config expanded:(BOOL)expanded {
    NSString *expandIcon = expanded ? @"▼" : @"▶";
    NSString *title = [NSString stringWithFormat:@"%@ %@", expandIcon, config.displayName];
    
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(toggleCategoryExpansion:) keyEquivalent:@""];
    headerItem.target = self;
    headerItem.representedObject = config.categoryName;
    headerItem.enabled = !config.alwaysExpanded; // Can't toggle always-expanded categories
    
    // Style as header (non-selectable for provider selection)
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    headerItem.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attributes];
    
    [[self menu] addItem:headerItem];
}

- (void)addCategoryWithSubmenu:(ProviderCategoryConfig *)config providers:(NSArray<id<WatchlistProvider>> *)providers {
    NSString *title = [NSString stringWithFormat:@"▶ %@", config.displayName];
    
    NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    
    // Create submenu
    NSMenu *submenu = [[NSMenu alloc] init];
    
    // Special handling for market lists (needs sub-submenus)
    if ([config.categoryName isEqualToString:@"Market Lists"]) {
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
}

- (void)addProvidersDirectly:(NSArray<id<WatchlistProvider>> *)providers withIndent:(BOOL)indent {
    for (id<WatchlistProvider> provider in providers) {
        NSMenuItem *providerItem = [self createProviderMenuItem:provider];
        
        if (indent) {
            // Add visual indentation
            NSString *indentedTitle = [NSString stringWithFormat:@"    %@", providerItem.title];
            providerItem.title = indentedTitle;
        }
        
        [[self menu] addItem:providerItem];
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
        
        // Create market type submenu item
        NSString *typeDisplayName = [self displayNameForMarketTypeKey:typeKey];
        NSMenuItem *typeItem = [[NSMenuItem alloc] initWithTitle:typeDisplayName action:nil keyEquivalent:@""];
        
        // Create sub-submenu for timeframes
        NSMenu *timeframeSubmenu = [[NSMenu alloc] init];
        
        for (id<WatchlistProvider> provider in typeProviders) {
            NSMenuItem *timeframeItem = [self createProviderMenuItem:provider];
            // Remove the market type part from display name for cleaner submenu
            if ([provider isKindOfClass:[MarketListProvider class]]) {
                MarketListProvider *marketProvider = (MarketListProvider *)provider;
                timeframeItem.title = [self displayNameForTimeframe:marketProvider.timeframe];
            }
            [timeframeSubmenu addItem:timeframeItem];
        }
        
        typeItem.submenu = timeframeSubmenu;
        [submenu addItem:typeItem];
    }
}

- (NSString *)keyForMarketType:(MarketListType)type {
    switch (type) {
        case MarketListTypeTopGainers: return @"gainers";
        case MarketListTypeTopLosers: return @"losers";
        case MarketListTypeEarnings: return @"earnings";
        case MarketListTypeETF: return @"etf";
        case MarketListTypeIndustry: return @"industry";
        default: return @"gainers";
    }
}

- (NSString *)displayNameForMarketTypeKey:(NSString *)key {
    if ([key isEqualToString:@"gainers"]) return @"🚀 Top Gainers";
    if ([key isEqualToString:@"losers"]) return @"📉 Top Losers";
    if ([key isEqualToString:@"earnings"]) return @"💰 Earnings";
    if ([key isEqualToString:@"etf"]) return @"🏛️ ETF";
    if ([key isEqualToString:@"industry"]) return @"🏭 Industry";
    return @"📊 Market";
}

- (NSString *)displayNameForTimeframe:(MarketTimeframe)timeframe {
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

#pragma mark - Actions

- (void)popUpSelectionChanged:(id)sender {
    // Handle direct selection (should not happen in hierarchical mode)
    NSMenuItem *selectedItem = [self selectedItem];
    if (selectedItem && selectedItem.representedObject) {
        NSString *providerId = selectedItem.representedObject;
        
        id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
        if (!provider) return;
        
        // Update our selected provider
        self.selectedProvider = provider;
        [self updateDisplayText];
        
        // Notify delegate about selection
        if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:didSelectProvider:)]) {
            NSLog(@"🔄 Provider selected via popup: %@", provider.displayName);
            [self.selectorDelegate hierarchicalSelector:self didSelectProvider:provider];
        }
    }
}

- (void)providerSelected:(NSMenuItem *)sender {
    NSString *providerId = sender.representedObject;
    if (!providerId) return;
    
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    if (!provider) {
        NSLog(@"⚠️ Provider not found for menu selection: %@", providerId);
        return;
    }
    
    // Update our selected provider
    self.selectedProvider = provider;
    [self updateDisplayText];
    
    // Notify delegate about user selection
    if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:didSelectProvider:)]) {
        NSLog(@"🔄 User selected provider from menu: %@", provider.displayName);
        [self.selectorDelegate hierarchicalSelector:self didSelectProvider:provider];
    }
}

- (void)toggleCategoryExpansion:(NSMenuItem *)sender {
    NSString *categoryName = sender.representedObject;
    if (!categoryName) return;
    
    // Toggle expansion state
    BOOL currentlyExpanded = [self isCategoryExpanded:categoryName];
    [self setCategoryExpanded:!currentlyExpanded forCategory:categoryName];
    
    // Rebuild menu to reflect new state
    [self rebuildMenuStructure];
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
    [self updateDisplayText];
    
    NSLog(@"✅ Selector updated to provider: %@", provider.displayName);
}

- (void)selectDefaultProvider {
    id<WatchlistProvider> defaultProvider = [self.providerManager defaultProvider];
    if (defaultProvider) {
        [self selectProviderWithId:defaultProvider.providerId];
    }
}

- (void)updateDisplayText {
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
    
    // Update button title
    [self removeAllItems];
    [self addItemWithTitle:self.currentDisplayText];
}

#pragma mark - Category State Management

- (void)setCategoryExpanded:(BOOL)expanded forCategory:(NSString *)categoryName {
    self.categoryExpansionState[categoryName] = @(expanded);
    
    // Save to user defaults for persistence
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = [NSString stringWithFormat:@"WatchlistSelector.%@.Expanded", categoryName];
    [defaults setBool:expanded forKey:key];
}

- (BOOL)isCategoryExpanded:(NSString *)categoryName {
    // Check memory first
    NSNumber *memoryState = self.categoryExpansionState[categoryName];
    if (memoryState) {
        return [memoryState boolValue];
    }
    
    // Check user defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = [NSString stringWithFormat:@"WatchlistSelector.%@.Expanded", categoryName];
    if ([defaults objectForKey:key]) {
        BOOL expanded = [defaults boolForKey:key];
        self.categoryExpansionState[categoryName] = @(expanded);
        return expanded;
    }
    
    // Default state based on category config
    for (ProviderCategoryConfig *config in self.categoryConfigs) {
        if ([config.categoryName isEqualToString:categoryName]) {
            return config.alwaysExpanded || (config.autoExpandLimit > 0);
        }
    }
    
    return NO; // Default to collapsed
}

#pragma mark - Provider Count Updates

- (void)updateProviderCounts {
    if (self.isUpdatingMenu) return;
    
    // This method can be called to update provider counts without full rebuild
    // Useful when providers finish loading their symbols
    
    BOOL needsRebuild = NO;
    
    for (NSString *categoryName in self.categoryItemCounts.allKeys) {
        NSArray<id<WatchlistProvider>> *providers = [self.providerManager providersForCategory:categoryName];
        
        // Check if any provider now has count information that wasn't there before
        for (id<WatchlistProvider> provider in providers) {
            if (provider.showCount && provider.isLoaded && provider.symbols.count > 0) {
                needsRebuild = YES;
                break;
            }
        }
        
        if (needsRebuild) break;
    }
    
    if (needsRebuild) {
        [self rebuildMenuStructure];
    }
}

#pragma mark - NSPopUpButton Overrides

- (void)mouseDown:(NSEvent *)event {
    // Notify delegate that menu will be shown
    if (self.selectorDelegate && [self.selectorDelegate respondsToSelector:@selector(hierarchicalSelector:willShowMenuForCategory:)]) {
        // We can't know which category will be accessed, so notify for all
        for (ProviderCategoryConfig *config in self.categoryConfigs) {
            [self.selectorDelegate hierarchicalSelector:self willShowMenuForCategory:config.categoryName];
        }
    }
    
    [super mouseDown:event];
}

#pragma mark - Public Interface

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

#pragma mark - Debug

- (NSString *)description {
    return [NSString stringWithFormat:@"<HierarchicalWatchlistSelector: %@ categories, selected: %@>",
            @(self.categoryConfigs.count), self.selectedProvider.displayName ?: @"none"];
}

@end
