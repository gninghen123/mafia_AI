//
//  WatchlistWidget.h
//  TradingApp
//
//  NEW UNIFIED WIDGET: Replaces both WatchlistWidget and GeneralMarketWidget
//  Supports hierarchical providers with 4 types: Manual, Market Lists, Baskets, Tag Lists
//  UPDATED: Added search for watchlists and sorting for symbols
//

#import "BaseWidget.h"
#import "RuntimeModels.h"
#import "WatchlistTypes.h"
#import "TradingAppTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class WatchlistProviderManager;
@class HierarchicalWatchlistSelector;
@protocol WatchlistProvider;



@interface WatchlistWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource>

#pragma mark - UI Components
@property (nonatomic, assign) BOOL isApplyingSorting;
@property (nonatomic, assign) BOOL isPerformingMultiSelection;

// Toolbar components
@property (nonatomic, strong) NSView *toolbarView;
@property (nonatomic, strong) HierarchicalWatchlistSelector *providerSelector;
@property (nonatomic, strong) NSButton *actionsButton;

// NEW: Search functionality
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSString *searchText;

// Table view components
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;

// Loading state
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;
@property (nonatomic, strong) NSTextField *statusLabel;

#pragma mark - Provider System

// Provider management
@property (nonatomic, strong) WatchlistProviderManager *providerManager;
@property (nonatomic, strong) id<WatchlistProvider> currentProvider;

// Provider state
@property (nonatomic, assign) BOOL isLoadingProvider;
@property (nonatomic, strong) NSString *lastSelectedProviderId;

#pragma mark - Data Arrays

// Current provider data
@property (nonatomic, strong) NSArray<NSString *> *symbols;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketQuoteModel *> *quotesCache;

// Display data (filtered/sorted)
@property (nonatomic, strong) NSArray<NSString *> *displaySymbols;

#pragma mark - Layout State

// Responsive layout tracking
@property (nonatomic, assign) CGFloat currentWidth;
@property (nonatomic, assign) NSInteger visibleColumns; // 1=symbol, 2=symbol+change%, 3=symbol+change%+arrow


#pragma mark - Public Methods

// Provider selection
- (void)selectProvider:(id<WatchlistProvider>)provider;
- (void)refreshCurrentProvider;

// Layout management
- (void)updateLayoutForWidth:(CGFloat)width;

// Symbol interaction
- (void)addSymbol:(NSString *)symbol toManualWatchlist:(NSString *)watchlistName;
- (void)createWatchlistFromCurrentSelection;

#pragma mark - NEW: Search and Sorting Methods

// Search (filters watchlists in popup)
- (void)searchTextChanged:(NSTextField *)sender;
- (void)clearSearch;


// Utility methods
- (BOOL)hasSelectedSymbols;
- (NSArray<NSString *> *)selectedSymbols;

@end

NS_ASSUME_NONNULL_END
