
// Watchlist+CoreDataClass.h
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Symbol;

NS_ASSUME_NONNULL_BEGIN

@interface Watchlist : NSManagedObject

// Convenience methods for Symbol relationships
- (void)addSymbolObject:(Symbol *)symbol;
- (void)removeSymbolObject:(Symbol *)symbol;
- (void)addSymbolsFromSet:(NSSet<Symbol *> *)symbols;
- (void)removeSymbolsFromSet:(NSSet<Symbol *> *)symbols;

// String-based convenience methods (for backward compatibility)
- (void)addSymbolWithName:(NSString *)symbolName context:(NSManagedObjectContext *)context;
- (void)removeSymbolWithName:(NSString *)symbolName;
- (BOOL)containsSymbolWithName:(NSString *)symbolName;
- (NSArray<NSString *> *)symbolNames;
- (NSArray<NSString *> *)sortedSymbolNames;

@end

NS_ASSUME_NONNULL_END

#import "Watchlist+CoreDataProperties.h"
