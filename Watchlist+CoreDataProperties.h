//
//  Watchlist+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "Watchlist+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN
@class Symbol;

@interface Watchlist (CoreDataProperties)

+ (NSFetchRequest<Watchlist *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *colorHex;
@property (nullable, nonatomic, copy) NSDate *creationDate;
@property (nullable, nonatomic, copy) NSDate *lastModified;
@property (nullable, nonatomic, copy) NSString *name;
@property (nonatomic) int64_t sortOrder;
@property (nullable, nonatomic, retain) NSSet<Symbol *> *symbols;

@end

@interface Watchlist (CoreDataGeneratedAccessors)

- (void)addSymbolsObject:(Symbol *)value;
- (void)removeSymbolsObject:(Symbol *)value;
- (void)addSymbols:(NSSet<Symbol *> *)values;
- (void)removeSymbols:(NSSet<Symbol *> *)values;

@end

NS_ASSUME_NONNULL_END
