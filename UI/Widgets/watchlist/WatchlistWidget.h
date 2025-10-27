//
//  WatchlistWidget.h
//  TradingApp
//
//  REFACTORED: Replaced hierarchical selector with segmented control + navigation
//  Supports drill-down navigation: Provider Type → Watchlist → Symbols
//

#import "BaseWidget.h"
#import "RuntimeModels.h"
#import "CommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class WatchlistProviderManager;
@protocol WatchlistProvider;

#pragma mark - Provider Type Enum

typedef NS_ENUM(NSInteger, WatchlistProviderType) {
    WatchlistProviderTypeManual = 0,
    WatchlistProviderTypeMarket,
    WatchlistProviderTypeBaskets,
    WatchlistProviderTypeTags,
    WatchlistProviderTypeArchives,
    WatchlistProviderTypeScreenerResults
};

#pragma mark - Display Mode Enum

typedef NS_ENUM(NSInteger, WatchlistDisplayMode) {
    WatchlistDisplayModeListSelection,  // Show list of watchlists
    WatchlistDisplayModeSymbols         // Show symbols in selected watchlist
};

#pragma mark - WatchlistWidget Interface

@interface WatchlistWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource>

#pragma mark - UI Components

@property (nonatomic, strong) TagManagementWindowController *tagManagementController; // ← AGGIUNGI

// State flags
@property (nonatomic, assign) BOOL isApplyingSorting;
@property (nonatomic, assign) BOOL isPerformingMultiSelection;

// Toolbar components (2 rows)
@property (nonatomic, strong) NSView *toolbarView;
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSButton *actionsButton;
@property (nonatomic, strong) NSSegmentedControl *providerTypeSegmented;


// Table view components
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;

// Loading state
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;
@property (nonatomic, strong) NSTextField *statusLabel;

#pragma mark - Provider System

// Provider management
@property (nonatomic, strong) WatchlistProviderManager *providerManager;
@property (nonatomic, strong, nullable) id<WatchlistProvider> currentProvider;

// Provider type selection
@property (nonatomic, assign) WatchlistProviderType selectedProviderType;

// Provider state
@property (nonatomic, assign) BOOL isLoadingProvider;
@property (nonatomic, strong, nullable) NSString *lastSelectedProviderId;

#pragma mark - Navigation State

// Display mode (list selection vs symbols)
@property (nonatomic, assign) WatchlistDisplayMode displayMode;

// Selected watchlist for drill-down
@property (nonatomic, strong, nullable) id<WatchlistProvider> selectedWatchlist;

// Current provider lists (for list selection mode)
@property (nonatomic, strong) NSArray<id<WatchlistProvider>> *currentProviderLists;

#pragma mark - Data Arrays

// Current provider data (symbols mode)
@property (nonatomic, strong) NSArray<NSString *> *symbols;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketQuoteModel *> *quotesCache;

// Display data (filtered/sorted)
@property (nonatomic, strong) NSArray<NSString *> *displaySymbols;

// Search
@property (nonatomic, strong) NSString *searchText;

#pragma mark - Layout State

// Responsive layout tracking
@property (nonatomic, assign) CGFloat currentWidth;
@property (nonatomic, assign) NSInteger visibleColumns; // 1=symbol, 2=symbol+change%, 3=symbol+change%+arrow

#pragma mark - Public Methods

// Provider type selection
- (void)selectProviderType:(WatchlistProviderType)type;
- (NSString *)categoryNameForProviderType:(WatchlistProviderType)type;

// Navigation
- (void)drillDownToWatchlistAtIndex:(NSInteger)index;
- (void)navigateBackToListSelection;

// Provider selection (existing - for symbols mode)
- (void)selectProvider:(id<WatchlistProvider>)provider;
- (void)refreshCurrentProvider;

// Layout management
- (void)updateLayoutForWidth:(CGFloat)width;

// Symbol interaction
- (void)addSymbol:(NSString *)symbol toManualWatchlist:(NSString *)watchlistName;
- (void)createWatchlistFromCurrentSelection;

// Search
- (void)searchTextChanged:(NSTextField *)sender;
- (void)clearSearch;

// Utility methods
- (BOOL)hasSelectedSymbols;
- (NSArray<NSString *> *)selectedSymbols;

@end

NS_ASSUME_NONNULL_END
