//
//  HierarchicalWatchlistSelector.h
//  TradingApp
//
//  Custom NSPopUpButton with support for hierarchical categories and submenus
//  Handles the complex structure: Category > Provider > Timeframe (for market lists)
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"
#import "WatchlistTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class WatchlistProviderManager;
@protocol WatchlistProvider;

// Category configuration for expansion behavior
@interface ProviderCategoryConfig : NSObject
@property (nonatomic, strong) NSString *categoryName;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, assign) BOOL alwaysExpanded;      // Baskets always expanded
@property (nonatomic, assign) NSInteger autoExpandLimit; // Auto-expand if ≤ this many items
@property (nonatomic, assign) BOOL rememberState;       // Remember user's expand/collapse preference
@end

@protocol HierarchicalWatchlistSelectorDelegate <NSObject>
- (void)hierarchicalSelector:(id)selector didSelectProvider:(id<WatchlistProvider>)provider;
- (void)hierarchicalSelector:(id)selector willShowMenuForCategory:(NSString *)categoryName;
@end

@interface HierarchicalWatchlistSelector : NSPopUpButton

#pragma mark - Configuration

@property (nonatomic, weak) id<HierarchicalWatchlistSelectorDelegate> selectorDelegate;
@property (nonatomic, strong) WatchlistProviderManager *providerManager;

// Category management
@property (nonatomic, strong) NSArray<ProviderCategoryConfig *> *categoryConfigs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *categoryExpansionState;

#pragma mark - Current State

// Selected provider
@property (nonatomic, strong, nullable) id<WatchlistProvider> selectedProvider;
@property (nonatomic, strong) NSString *currentDisplayText;

// Loading state
@property (nonatomic, assign) BOOL isUpdatingMenu;

#pragma mark - Public Methods

// Setup
- (void)configureWithProviderManager:(WatchlistProviderManager *)manager;

// Menu management
- (void)rebuildMenuStructure;
- (void)updateProviderCounts;

// Selection
- (void)selectProviderWithId:(NSString *)providerId;
- (void)selectDefaultProvider;

// Category state
- (void)setCategoryExpanded:(BOOL)expanded forCategory:(NSString *)categoryName;
- (BOOL)isCategoryExpanded:(NSString *)categoryName;

#pragma mark - Menu Construction

// Category menu builders
- (NSMenu *)buildManualWatchlistsSubmenu;
- (NSMenu *)buildMarketListsSubmenu;
- (NSMenu *)buildBasketsSubmenu;
- (NSMenu *)buildTagListsSubmenu;
- (NSMenu *)buildArchivesSubmenu;

// Utility
- (NSMenuItem *)createCategoryHeaderItem:(NSString *)title icon:(NSString *)icon expanded:(BOOL)expanded;
- (NSMenuItem *)createProviderItem:(id<WatchlistProvider>)provider;
- (NSMenuItem *)createSubmenuItem:(NSString *)title providers:(NSArray<id<WatchlistProvider>> *)providers;

@end

NS_ASSUME_NONNULL_END
