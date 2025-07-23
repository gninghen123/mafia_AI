//
//  WatchlistWidget.h
//  mafia_AI
//
//  Widget per la gestione delle watchlist
//

#import "BaseWidget.h"

@class Watchlist;

@interface WatchlistWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSTextFieldDelegate>

// UI Components - Mantenuti per compatibilità
@property (nonatomic, strong) NSSegmentedControl *watchlistSelector;
@property (nonatomic, strong) NSButton *watchlistMenuButton;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *mainTableView;
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSButton *addSymbolButton;
@property (nonatomic, strong) NSButton *removeSymbolButton;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// UI Components - Nuova interfaccia
@property (nonatomic, strong) NSPopUpButton *watchlistPopup;
@property (nonatomic, strong) NSButton *previousButton;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, strong) NSButton *favoriteButton;
@property (nonatomic, strong) NSButton *organizeButton;
@property (nonatomic, strong) NSTextField *quickAddField;
@property (nonatomic, strong) NSButton *importButton;

// UI Components - Main Area
@property (nonatomic, strong) NSView *quickAddBar;
@property (nonatomic, strong) NSView *temporarySidebar;
@property (nonatomic, strong) NSTableView *sidebarTableView;
@property (nonatomic, assign) BOOL sidebarVisible;

// Data
@property (nonatomic, strong) NSArray<Watchlist *> *watchlists;
@property (nonatomic, strong) NSArray<Watchlist *> *favoriteWatchlists;
@property (nonatomic, strong) Watchlist *currentWatchlist;
@property (nonatomic, strong) NSArray<NSString *> *symbols;
@property (nonatomic, strong) NSArray<NSString *> *filteredSymbols;
@property (nonatomic, strong) NSMutableDictionary *symbolDataCache;

// State
@property (nonatomic, assign) BOOL showOnlyFavorites;
@property (nonatomic, assign) BOOL isEditingInline;
@property (nonatomic, strong) NSString *pendingSymbol;
@property (nonatomic, assign) NSInteger editingRow;

// Drag & Drop
@property (nonatomic, strong) NSArray *draggedSymbols;
@property (nonatomic, assign) BOOL isDragging;

// Import/Export
@property (nonatomic, strong) NSArray *supportedImportFormats;

// Additional properties needed for GeneralMarketWidget compatibility
@property (nonatomic, assign) NSInteger pageSize;
@property (nonatomic, strong) NSMutableArray *dataSource;

// Refresh timer
@property (nonatomic, strong) NSTimer *refreshTimer;

// Formatters
@property (nonatomic, strong) NSNumberFormatter *priceFormatter;
@property (nonatomic, strong) NSNumberFormatter *percentFormatter;

// Methods - Setup
- (void)setupQuickAddBar;
- (void)setupTemporarySidebar;
- (void)setupFormatters;
- (void)registerForNotifications;

// Methods - Navigation
- (void)toggleSidebar;
- (void)navigateToPreviousWatchlist;
- (void)navigateToNextWatchlist;
- (void)toggleFavoriteFilter;
- (void)updateNavigationButtons;

// Methods - Data Management
- (void)loadWatchlists;
- (void)loadSymbolsForCurrentWatchlist;
- (void)refreshSymbolData;
- (void)applyFilter;

// Methods - Symbol Management
- (void)processQuickAddInput:(NSString *)input;
- (NSArray<NSString *> *)parseSymbolInput:(NSString *)input;
- (void)validateAndAddSymbols:(NSArray<NSString *> *)symbols;
- (void)removeSelectedSymbols:(id)sender;

// Methods - Import/Export
- (void)importFromCSV:(NSURL *)fileURL;
- (void)showImportDialog;

// Methods - UI Feedback
- (void)showTemporaryMessage:(NSString *)message;
- (void)flashRow:(NSInteger)row color:(NSColor *)color;

// Methods - Timer
- (void)startRefreshTimer;
- (void)refreshTimerFired:(NSTimer *)timer;

// Methods - Actions (compatibilità)
- (void)watchlistChanged:(id)sender;
- (void)showWatchlistMenu:(id)sender;
- (void)searchFieldChanged:(id)sender;
- (void)addSymbol:(id)sender;
- (void)removeSymbol:(id)sender;
- (void)manageWatchlists:(id)sender;
- (void)createWatchlist:(id)sender;
- (void)renameCurrentWatchlist:(id)sender;
- (void)deleteCurrentWatchlist:(id)sender;

// Methods - Actions (nuove)
- (void)quickAddSymbols:(id)sender;
- (void)hideQuickAddBar:(id)sender;

// Methods - Table Support
- (void)createTableColumns;

// Methods - Notifications
- (void)watchlistsUpdated:(NSNotification *)notification;
- (void)symbolDataUpdated:(NSNotification *)notification;

@end
