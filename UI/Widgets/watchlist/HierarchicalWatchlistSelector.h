//
//  HierarchicalWatchlistSelector.h - UPDATED: Lazy submenu loading support
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"
#import "commonTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class WatchlistProviderManager;
@protocol WatchlistProvider;

@protocol HierarchicalWatchlistSelectorDelegate <NSObject>
- (void)hierarchicalSelector:(id)selector didSelectProvider:(id<WatchlistProvider>)provider;
- (void)hierarchicalSelector:(id)selector willShowMenuForCategory:(NSString *)categoryName;
@end

@interface HierarchicalWatchlistSelector : NSPopUpButton

#pragma mark - Configuration

@property (nonatomic, weak) id<HierarchicalWatchlistSelectorDelegate> selectorDelegate;
@property (nonatomic, strong) WatchlistProviderManager *providerManager;

#pragma mark - Current State

// Selected provider
@property (nonatomic, strong, nullable) id<WatchlistProvider> selectedProvider;
@property (nonatomic, strong) NSString *currentDisplayText;

// Search filtering
@property (nonatomic, strong) NSString *filterText;

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

// Search filtering
- (void)setFilterText:(NSString *)filterText;
- (void)clearFilter;

// ✅ NEW: Lazy loading methods
- (void)loadSubmenuForCategory:(NSString *)categoryName;

@end

NS_ASSUME_NONNULL_END
