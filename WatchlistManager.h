//
//  WatchlistManager.h
//  TradingApp
//
//  Manages all watchlists and symbol properties globally
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface WatchlistData : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSMutableArray<NSString *> *symbols;
@property (nonatomic, strong) NSDate *createdDate;
@property (nonatomic, strong) NSDate *lastModified;
@property (nonatomic, assign) BOOL isDynamic;
@property (nonatomic, strong) NSString *dynamicTag;  // Tag per watchlist dinamiche

- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name dynamicTag:(NSString *)tag;
- (NSDictionary *)toDictionary;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
@end

@interface SymbolProperties : NSObject
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSColor *color;
@property (nonatomic, strong) NSMutableSet<NSString *> *tags;
@property (nonatomic, strong) NSString *note;

- (instancetype)initWithSymbol:(NSString *)symbol;
- (NSDictionary *)toDictionary;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
@end

@interface WatchlistManager : NSObject

+ (instancetype)sharedManager;

// Watchlist management
- (NSArray<NSString *> *)availableWatchlistNames;
- (WatchlistData *)watchlistWithName:(NSString *)name;
- (void)saveWatchlist:(WatchlistData *)watchlist;
- (void)deleteWatchlistWithName:(NSString *)name;
- (WatchlistData *)createWatchlistWithName:(NSString *)name;
- (WatchlistData *)createDynamicWatchlistWithName:(NSString *)name forTag:(NSString *)tag;

// Dynamic watchlist management
- (void)updateDynamicWatchlists;
- (NSArray<NSString *> *)symbolsWithTag:(NSString *)tag;
- (NSArray<NSString *> *)availableTags;

// Symbol operations
- (void)addSymbol:(NSString *)symbol toWatchlist:(NSString *)watchlistName;
- (void)removeSymbol:(NSString *)symbol fromWatchlist:(NSString *)watchlistName;

// Symbol properties (global across all watchlists)
- (SymbolProperties *)propertiesForSymbol:(NSString *)symbol;
- (void)setColor:(NSColor *)color forSymbol:(NSString *)symbol;
- (void)addTag:(NSString *)tag toSymbol:(NSString *)symbol;
- (void)removeTag:(NSString *)tag fromSymbol:(NSString *)symbol;
- (void)setNote:(NSString *)note forSymbol:(NSString *)symbol;

// Bulk operations
- (void)addSymbols:(NSArray<NSString *> *)symbols toWatchlist:(NSString *)watchlistName;

// Persistence
- (void)saveAllData;
- (void)loadAllData;

@end
