//
//  WatchlistWidget.h
//  mafia_AI
//

#import "BaseWidget.h"
#import "WatchlistCellViews.h"

@class Watchlist;


@interface WatchlistWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate>

// UI Elements
@property (nonatomic, strong) NSLayoutConstraint *sidebarWidthConstraint;

@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *mainTableView;
@property (nonatomic, strong) NSPopUpButton *watchlistPopup;
@property (nonatomic, strong) NSButton *previousButton;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, strong) NSButton *favoriteButton;
@property (nonatomic, strong) NSButton *organizeButton;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSButton *importButton;
@property (nonatomic, strong) NSButton *removeSymbolButton;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// Quick Add Bar
@property (nonatomic, strong) NSView *quickAddBar;
@property (nonatomic, strong) NSTextField *quickAddField;

// Temporary Sidebar for drag & drop
@property (nonatomic, strong) NSView *temporarySidebar;
@property (nonatomic, strong) NSTableView *sidebarTableView;

// Data
@property (nonatomic, strong) NSArray<Watchlist *> *watchlists;
@property (nonatomic, strong) Watchlist *currentWatchlist;
@property (nonatomic, strong) NSMutableArray<NSString *> *symbols;
@property (nonatomic, strong) NSMutableArray<NSString *> *filteredSymbols;
@property (nonatomic, strong) NSMutableDictionary *symbolDataCache;

// State
@property (nonatomic, strong) NSArray<NSString *> *draggedSymbols;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL showOnlyFavorites;
@property (nonatomic, assign) BOOL sidebarVisible;

// Import/Export
@property (nonatomic, strong) NSArray<NSString *> *supportedImportFormats;

// Data Arrays (legacy support)
@property (nonatomic, strong) NSArray *mainDataArray;
@property (nonatomic, strong) NSArray *sidebarDataArray;

// Methods
- (void)loadWatchlists;
- (void)loadSymbolsForCurrentWatchlist;
- (void)refreshSymbolData;
- (void)filterSymbols;

@end
