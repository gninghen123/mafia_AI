//
//  WatchlistWidget.h
//  TradingApp
//
//  Widget for displaying and managing watchlists
//

#import "BaseWidget.h"
#import "DataManager.h"
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, WatchlistRuleCondition) {
    WatchlistRuleConditionGreaterThan,
    WatchlistRuleConditionLessThan,
    WatchlistRuleConditionEqual,
    WatchlistRuleConditionNotEqual,
    WatchlistRuleConditionBetween,
    WatchlistRuleConditionContains
};

typedef NS_ENUM(NSInteger, WatchlistRuleField) {
    WatchlistRuleFieldPrice,
    WatchlistRuleFieldChange,
    WatchlistRuleFieldChangePercent,
    WatchlistRuleFieldVolume,
    WatchlistRuleFieldSymbol
};

@interface WatchlistRule : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) WatchlistRuleField field;
@property (nonatomic, assign) WatchlistRuleCondition condition;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) id secondaryValue; // For "between" conditions
@property (nonatomic, strong) NSColor *highlightColor;
@property (nonatomic, assign) BOOL enabled;

- (instancetype)initWithName:(NSString *)name
                       field:(WatchlistRuleField)field
                   condition:(WatchlistRuleCondition)condition
                       value:(id)value;

- (BOOL)evaluateWithData:(NSDictionary *)data;

+ (NSArray<WatchlistRule *> *)defaultRules;

@end

@interface WatchlistWidget : BaseWidget <DataManagerDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, NSComboBoxDataSource, NSComboBoxDelegate>

// Watchlist management
@property (nonatomic, strong) NSMutableArray<NSString *> *symbols;
@property (nonatomic, strong) NSMutableArray<WatchlistRule *> *rules;
@property (nonatomic, strong) NSString *watchlistName;

// UI Elements
@property (nonatomic, strong, readonly) NSTableView *tableView;
@property (nonatomic, strong, readonly) NSScrollView *scrollView;
@property (nonatomic, strong, readonly) NSTextField *symbolInputField;
@property (nonatomic, strong, readonly) NSButton *removeButton;
@property (nonatomic, strong, readonly) NSComboBox *watchlistComboBox;

// Watchlist operations
- (void)addSymbol:(NSString *)symbol;
- (void)addMultipleSymbols:(NSArray<NSString *> *)symbols;
- (void)removeSymbol:(NSString *)symbol;
- (void)removeSymbolAtIndex:(NSInteger)index;
- (void)clearWatchlist;

// Watchlist management
- (void)loadWatchlist:(NSString *)name;
- (void)createNewWatchlist:(id)sender;
- (void)createDynamicWatchlist:(id)sender;
- (void)duplicateWatchlist:(id)sender;
- (void)deleteCurrentWatchlist:(id)sender;

// Rule management
- (void)addRule:(WatchlistRule *)rule;
- (void)removeRule:(WatchlistRule *)rule;
- (void)applyRules;

// Data refresh
- (void)refreshData;
- (void)refreshSymbol:(NSString *)symbol;

// Multi-selection features
- (void)removeSelectedSymbols:(id)sender;

// Tag management
- (void)addTag:(NSString *)tagName toSymbols:(NSIndexSet *)selectedIndexes;
- (void)removeTag:(NSString *)tagName fromSymbols:(NSIndexSet *)selectedIndexes;

// Context menu actions
- (void)setSymbolColor:(NSMenuItem *)sender;
- (void)addTagToSelectedSymbols:(id)sender;
- (void)removeTagFromSelectedSymbols:(id)sender;
- (void)createNewListFromSelection:(id)sender;
- (void)copySelectedSymbols:(id)sender;
- (void)exportSelectionToCSV:(id)sender;

// CSV Import/Export
- (void)importCSV:(id)sender;
- (void)exportCSV:(id)sender;
- (void)importCSVFromURL:(NSURL *)fileURL;
- (void)exportCSVToURL:(NSURL *)fileURL;
- (void)exportSelectedSymbolsToURL:(NSURL *)fileURL withIndexes:(NSIndexSet *)selectedIndexes;

// Legacy single-selection methods (for backward compatibility)
- (void)addSymbolTag:(id)sender;
- (void)copySymbol:(id)sender;

// Symbol validation
- (NSArray<NSString *> *)parseSymbolsFromInput:(NSString *)input;
- (BOOL)isValidSymbol:(NSString *)symbol;

@end
