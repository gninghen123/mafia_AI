//
//  SpotlightSearchWindow.h
//  TradingApp
//
//  Main Spotlight Search Window with dual-table layout
//  Supports symbol search and widget selection with category buttons
//

#import <Cocoa/Cocoa.h>
#import "SpotlightCategoryButton.h"
#import "SpotlightModels.h"

NS_ASSUME_NONNULL_BEGIN

@class GlobalSpotlightManager;

@interface SpotlightSearchWindow : NSWindow <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate, SpotlightCategoryButtonDelegate>

#pragma mark - Properties

@property (nonatomic, weak) GlobalSpotlightManager *spotlightManager;

// UI Components - Top Bar
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) SpotlightCategoryButton *dataSourceButton;
@property (nonatomic, strong) SpotlightCategoryButton *widgetTargetButton;

// UI Components - Tables
@property (nonatomic, strong) NSScrollView *symbolsScrollView;
@property (nonatomic, strong) NSTableView *symbolsTable;
@property (nonatomic, strong) NSScrollView *widgetsScrollView;
@property (nonatomic, strong) NSTableView *widgetsTable;

// Data Arrays
@property (nonatomic, strong) NSArray<SymbolSearchResult *> *symbolResults;
@property (nonatomic, strong) NSArray<WidgetOption *> *widgetOptions;

// State Management
@property (nonatomic, assign) BOOL isSymbolsTableActive;
@property (nonatomic, assign) NSInteger selectedSymbolIndex;
@property (nonatomic, assign) NSInteger selectedWidgetIndex;

// Search State
@property (nonatomic, strong) NSString *currentSearchText;
@property (nonatomic, strong) NSTimer *searchDelayTimer;

#pragma mark - Initialization

/**
 * Initialize with spotlight manager
 * @param spotlightManager Parent spotlight manager
 */
- (instancetype)initWithSpotlightManager:(GlobalSpotlightManager *)spotlightManager;

#pragma mark - Window Management

/**
 * Show window with initial text
 * @param initialText Initial text to populate search field
 */
- (void)showWithInitialText:(NSString *)initialText;

/**
 * Hide window and reset state
 */
- (void)hideWindow;

/**
 * Position window at center of screen
 */
- (void)centerWindow;

#pragma mark - Search Management

/**
 * Perform symbol search with current text
 * @param searchText Text to search for
 */
- (void)performSymbolSearch:(NSString *)searchText;

/**
 * Filter widget options based on search text
 * @param searchText Text to filter widgets
 */
- (void)filterWidgetOptions:(NSString *)searchText;

/**
 * Reset search and clear results
 */
- (void)resetSearch;

#pragma mark - Navigation

/**
 * Switch active table (left/right arrow keys)
 * @param toSymbols YES for symbols table, NO for widgets table
 */
- (void)switchActiveTable:(BOOL)toSymbols;

/**
 * Move selection up in active table
 */
- (void)moveSelectionUp;

/**
 * Move selection down in active table
 */
- (void)moveSelectionDown;

/**
 * Execute action for currently selected item
 */
- (void)executeSelectedAction;

#pragma mark - UI Setup

/**
 * Setup window appearance and layout
 */
- (void)setupWindowAppearance;

/**
 * Create and configure UI components
 */
- (void)createUIComponents;

/**
 * Setup layout constraints
 */
- (void)setupLayoutConstraints;

#pragma mark - Selection Management

/**
 * Update visual selection in tables
 */
- (void)updateTableSelections;

/**
 * Get currently selected symbol result
 * @return Selected symbol result or nil
 */
- (nullable SymbolSearchResult *)selectedSymbolResult;

/**
 * Get currently selected widget option
 * @return Selected widget option or nil
 */
- (nullable WidgetOption *)selectedWidgetOption;

@end

NS_ASSUME_NONNULL_END
