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

// Refresh timer
@property (nonatomic, strong) NSTimer *refreshTimer;

@end

// Window controller for managing watchlists
@interface WatchlistManagerController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, copy) void (^completionHandler)(BOOL changed);

@end

// Window controller for adding symbols
@interface AddSymbolController : NSWindowController <NSTextFieldDelegate>

@property (nonatomic, strong) Watchlist *watchlist;
@property (nonatomic, copy) void (^completionHandler)(NSArray<NSString *> *symbols);

- (instancetype)initWithWatchlist:(Watchlist *)watchlist;

@end
