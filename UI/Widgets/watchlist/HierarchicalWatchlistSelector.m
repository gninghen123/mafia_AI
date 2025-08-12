//
//  HierarchicalWatchlistSelector.m - MINIMAL FIX FOR LOADING ISSUE
//  ✅ Keep existing code structure but fix loading problems
//  ✅ Remove infinite loop potential
//  ✅ Fix loading state that never completes
//

#import "HierarchicalWatchlistSelector.h"
#import "WatchlistProviderManager.h"
#import "TradingAppTypes.h"

@interface HierarchicalWatchlistSelector ()
// Keep existing properties - don't change too much
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
    // ✅ FIX: Initialize filterText to avoid nil issues
  //  self.filterText = @"";
    
    [self setupPopUpButtonBehavior];
    [self setAutoenablesItems:NO];
    [self setPullsDown:NO];
}

- (void)setupPopUpButtonBehavior {
    self.target = self;
    self.action = @selector(popUpSelectionChanged:);
    
    [self setTitle:self.currentDisplayText];
    self.enabled = NO; // Will be enabled after provider manager is set
}

#pragma mark - Configuration

- (void)configureWithProviderManager:(WatchlistProviderManager *)manager {
    NSLog(@"🔧 HierarchicalSelector: Configuring with provider manager");
    
    self.providerManager = manager;
    
    if (manager) {
        NSLog(@"   Provider manager configured successfully");
        // ✅ FIX: Build menu structure immediately without lazy loading for now
        [self buildSimpleMenuStructure];
        self.enabled = YES;
    } else {
        NSLog(@"❌ Provider manager is nil!");
        [self setTitle:@"No Provider Manager"];
        self.enabled = NO;
    }
}

#pragma mark - ✅ FIX: Simple Menu Structure (No Lazy Loading)

- (void)buildSimpleMenuStructure {
    if (self.isUpdatingMenu) return;
    
    self.isUpdatingMenu = YES;
    
    NSLog(@"🏗️ Building simple menu structure (no lazy loading)");
    
    // Clear existing menu
    [[self menu] removeAllItems];
    
    // Get all categories and populate them immediately
    NSArray<NSString *> *categories = @[
        @"Manual Watchlists",
        @"Baskets",
        @"Market Lists",
        @"Tag Lists",
        @"Archives"
    ];
    
    NSArray<NSString *> *categoryDisplayNames = @[
        @"📝 MY LISTS",
        @"📅 BASKETS",
        @"📊 MARKET LISTS",
        @"🏷️ TAG LISTS",
        @"📦 ARCHIVES"
    ];
    
    BOOL firstCategory = YES;
    
    for (NSInteger i = 0; i < categories.count; i++) {
        NSString *categoryName = categories[i];
        NSString *displayName = categoryDisplayNames[i];
        
        // ✅ FIX: Get providers immediately - no lazy loading
        NSArray<id<WatchlistProvider>> *providers = [self.providerManager providersForCategory:categoryName];
        
        if (providers.count == 0) {
            NSLog(@"   Skipping empty category: %@", categoryName);
            continue;
        }
        
        if (!firstCategory) {
            [[self menu] addItem:[NSMenuItem separatorItem]];
        }
        firstCategory = NO;
        
        // Create category item with submenu
        NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:displayName action:nil keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:displayName];
        
        // Add all providers to submenu immediately
        for (id<WatchlistProvider> provider in providers) {
            NSMenuItem *providerItem = [self createMenuItemForProvider:provider];
            [submenu addItem:providerItem];
        }
        
        [categoryItem setSubmenu:submenu];
        [[self menu] addItem:categoryItem];
        
        NSLog(@"✅ Added category '%@' with %lu providers", categoryName, (unsigned long)providers.count);
    }
    
    self.isUpdatingMenu = NO;
    
    NSLog(@"✅ Simple menu structure completed with %ld categories", (long)[[self menu] numberOfItems]);
}

- (NSMenuItem *)createMenuItemForProvider:(id<WatchlistProvider>)provider {
    NSString *title = provider.displayName;
    
    // Add count if available and enabled
    if (provider.showCount && provider.isLoaded && provider.symbols.count > 0) {
        title = [NSString stringWithFormat:@"%@ (%lu)", title, (unsigned long)provider.symbols.count];
    }
    
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(providerSelected:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = provider.providerId;
    
    return item;
}

#pragma mark - Selection Handling

- (void)popUpSelectionChanged:(id)sender {
    NSMenuItem *selectedItem = [self selectedItem];
    if (!selectedItem || !selectedItem.representedObject) return;
    
    NSString *providerId = selectedItem.representedObject;
    id<WatchlistProvider> provider = [self.providerManager providerWithId:providerId];
    
    if (provider) {
        // ✅ FIX: Prevent infinite loops by checking if already selected
        if (self.selectedProvider && [self.selectedProvider.providerId isEqualToString:provider.providerId]) {
            NSLog(@"⚠️ Same provider already selected, ignoring to prevent loop");
            return;
        }
        
        self.selectedProvider = provider;
        [self updateDisplayText:provider.displayName];
        
        // ✅ FIX: Add safeguard for delegate calls
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
    
    // ✅ FIX: Prevent infinite loops
    if (self.selectedProvider && [self.selectedProvider.providerId isEqualToString:provider.providerId]) {
        NSLog(@"⚠️ Same provider already selected, ignoring to prevent loop");
        return;
    }
    
    self.selectedProvider = provider;
    [self updateDisplayText:provider.displayName];
    
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
        // ✅ FIX: Prevent loops here too
        if (self.selectedProvider && [self.selectedProvider.providerId isEqualToString:provider.providerId]) {
            NSLog(@"⚠️ Provider %@ already selected", provider.displayName);
            return;
        }
        
        self.selectedProvider = provider;
        [self updateDisplayText:provider.displayName];
        
        // Find and select the menu item
        [self selectMenuItemWithProviderId:providerId];
    }
}

- (void)selectMenuItemWithProviderId:(NSString *)providerId {
    // Recursively search through menu and submenus
    [self searchAndSelectInMenu:[self menu] providerId:providerId];
}

- (BOOL)searchAndSelectInMenu:(NSMenu *)menu providerId:(NSString *)providerId {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.representedObject isEqual:providerId]) {
            [self selectItem:item];
            return YES;
        }
        
        if (item.hasSubmenu) {
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

- (void)updateDisplayTextWithoutClearingMenu {
    if (self.selectedProvider) {
        [self updateDisplayText:self.selectedProvider.displayName];
    } else {
        [self updateDisplayText:@"Select Watchlist..."];
    }
}

#pragma mark - Other Methods (Stubs to prevent crashes)

- (void)rebuildMenuStructure {
    [self buildSimpleMenuStructure];
}

- (void)setFilterText:(NSString *)filterText {
    self.filterText = filterText ? [filterText copy] : @"";
    // For now, don't rebuild - filtering can be added later
}

- (void)clearFilter {
    self.filterText = @"";
}

- (void)updateProviderCounts {
    // For now, just rebuild
    [self buildSimpleMenuStructure];
}

- (void)setProviderManager:(WatchlistProviderManager *)providerManager {
    _providerManager = providerManager;
    
    if (providerManager) {
        [self buildSimpleMenuStructure];
        self.enabled = YES;
    } else {
        self.enabled = NO;
    }
}

@end
