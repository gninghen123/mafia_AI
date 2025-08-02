//
//  SymbolDatabaseWidget.h
//  mafia_AI
//

#import "BaseWidget.h"

@class Symbol;

@interface SymbolDatabaseWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate, NSMenuDelegate>

// UI Elements
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *mainTableView;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSPopUpButton *tagFilterButton;
@property (nonatomic, strong) NSButton *addSymbolButton;
@property (nonatomic, strong) NSButton *favoriteFilterButton;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// Data
@property (nonatomic, strong) NSArray<Symbol *> *symbols;
@property (nonatomic, strong) NSArray<Symbol *> *filteredSymbols;
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, strong) NSString *selectedTagFilter;
@property (nonatomic, assign) BOOL showOnlyFavorites;

// Methods
- (void)loadSymbols;
- (void)applyFilters;
- (void)refreshData;

// Actions
- (void)addSymbol:(id)sender;
- (void)deleteSelectedSymbols:(id)sender;
- (void)toggleFavoriteForSelectedSymbols:(id)sender;
- (void)searchFieldChanged:(id)sender;
- (void)tagFilterChanged:(id)sender;
- (void)favoriteFilterToggled:(id)sender;

@end
