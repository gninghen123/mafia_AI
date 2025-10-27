//
//  WatchlistProviderManager.h - UPDATED: Lazy loading support
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"
#import "CommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

@protocol WatchlistProvider;
@class WatchlistWidget;

@interface WatchlistProviderManager : NSObject

#pragma mark - Singleton

+ (instancetype)sharedManager;

#pragma mark - Provider Collections

// Organized by category for hierarchical display
@property (nonatomic, readonly) NSArray<id<WatchlistProvider>> *manualWatchlistProviders;
@property (nonatomic, readonly) NSArray<id<WatchlistProvider>> *marketListProviders;
@property (nonatomic, readonly) NSArray<id<WatchlistProvider>> *basketProviders;
@property (nonatomic, readonly) NSArray<id<WatchlistProvider>> *tagListProviders;
@property (nonatomic, readonly) NSArray<id<WatchlistProvider>> *archiveProviders;
@property (nonatomic, readonly) NSArray<id<WatchlistProvider>> *screenerProviders;

// All providers (flat list for search)
@property (nonatomic, readonly) NSArray<id<WatchlistProvider>> *allProviders;

#pragma mark - Provider Lookup

// Find providers
- (nullable id<WatchlistProvider>)providerWithId:(NSString *)providerId;
- (NSArray<id<WatchlistProvider>> *)providersForCategory:(NSString *)categoryName;

// Default selections
- (id<WatchlistProvider>)defaultProvider;
- (id<WatchlistProvider>)lastSelectedProvider;

#pragma mark - Provider Management

// Refresh provider lists
- (void)refreshAllProviders;
- (void)refreshProvidersForCategory:(NSString *)categoryName;

// ✅ NEW: Lazy loading support
- (void)ensureProvidersLoadedForCategory:(NSString *)categoryName;

// Add/remove manual watchlists
- (void)addManualWatchlistProvider:(NSString *)watchlistName;
- (void)removeManualWatchlistProvider:(NSString *)watchlistName;

// Auto-discovery for tags (now async)
- (void)refreshTagListProviders;
- (void)loadTagListProvidersAsync;

// Archive management (now async)
- (void)refreshArchiveProviders;
- (void)loadArchiveProvidersAsync;


// Screener results management
- (void)refreshScreenerProviders;
- (void)loadScreenerProvidersAsync;


#pragma mark - Factory Methods

// Create specific provider types
- (id<WatchlistProvider>)createManualWatchlistProvider:(NSString *)watchlistName;
- (id<WatchlistProvider>)createMarketListProvider:(MarketListType)type timeframe:(MarketTimeframe)timeframe;
- (id<WatchlistProvider>)createBasketProvider:(BasketType)type;
- (id<WatchlistProvider>)createTagListProvider:(NSString *)tag;
- (id<WatchlistProvider>)createArchiveProvider:(NSString *)archiveKey;

#pragma mark - Convenience Methods

// Market list helpers
- (NSArray<id<WatchlistProvider>> *)createAllMarketListProviders;
- (NSArray<id<WatchlistProvider>> *)createStandardMarketListProviders; // ← NUOVO
- (NSString *)displayNameForMarketType:(MarketListType)type timeframe:(MarketTimeframe)timeframe;
- (NSString *)iconForMarketType:(MarketListType)type;

// Basket helpers
- (NSArray<id<WatchlistProvider>> *)createAllBasketProviders;
- (NSString *)displayNameForBasketType:(BasketType)type;

// Tag discovery
- (NSArray<NSString *> *)discoverActiveTags;

// Archive helpers
- (NSArray<NSString *> *)discoverAvailableArchives;

//


@end

#pragma mark - Provider Protocol

@protocol WatchlistProvider <NSObject>

// Identity
@property (nonatomic, readonly) NSString *providerId;
@property (nonatomic, readonly) NSString *displayName;     // "🚀 Top Gainers - 1 Day"
@property (nonatomic, readonly) NSString *categoryName;    // "Market Lists"

// Capabilities
@property (nonatomic, readonly) BOOL canAddSymbols;
@property (nonatomic, readonly) BOOL canRemoveSymbols;
@property (nonatomic, readonly) BOOL isAutoUpdating;
@property (nonatomic, readonly) BOOL showCount;           // Whether to display symbol count

// Data access (lazy loaded)
@property (nonatomic, readonly) NSArray<NSString *> *symbols; // May be nil until loaded
@property (nonatomic, readonly) BOOL isLoaded;

// Loading
- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion;

// Symbol management (optional)
@optional
- (void)addSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
- (void)removeSymbol:(NSString *)symbol completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
