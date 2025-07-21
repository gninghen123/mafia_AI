//
//  WatchlistWidget.h
//  mafia_AI
//
//  Widget per la gestione delle watchlist
//

#import "BaseWidget.h"

@class Watchlist;

@interface WatchlistWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate>

// UI Components
@property (nonatomic, strong) NSSegmentedControl *watchlistSelector;
@property (nonatomic, strong) NSButton *watchlistMenuButton;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSButton *addSymbolButton;
@property (nonatomic, strong) NSButton *removeSymbolButton;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// Data
@property (nonatomic, strong) NSArray<Watchlist *> *watchlists;
@property (nonatomic, strong) Watchlist *currentWatchlist;
@property (nonatomic, strong) NSArray<NSString *> *symbols;
@property (nonatomic, strong) NSArray<NSString *> *filteredSymbols;
@property (nonatomic, strong) NSMutableDictionary *symbolDataCache;

// Additional properties needed for GeneralMarketWidget compatibility
@property (nonatomic, assign) NSInteger pageSize;
@property (nonatomic, strong) NSMutableArray *dataSource;

// Refresh timer
@property (nonatomic, strong) NSTimer *refreshTimer;

@end
