//
//  Watchlist+CoreDataClass.h
//  mafia_AI
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface Watchlist : NSManagedObject

// Convenience methods
- (void)addSymbol:(NSString *)symbol;
- (void)removeSymbol:(NSString *)symbol;
- (BOOL)containsSymbol:(NSString *)symbol;
- (NSArray<NSString *> *)sortedSymbols;

@end

NS_ASSUME_NONNULL_END

#import "Watchlist+CoreDataProperties.h"
