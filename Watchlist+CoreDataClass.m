//
//  Watchlist+CoreDataClass.m
//  mafia_AI
//

#import "Watchlist+CoreDataClass.h"
#import "Symbol+CoreDataClass.h"

@implementation Watchlist

#pragma mark - Symbol Relationship Management

- (void)addSymbolObject:(Symbol *)symbol {
    if (!symbol) return;
    
    [self addSymbolsObject:symbol];  // Usa il metodo generato da Core Data
    self.lastModified = [NSDate date];
}

- (void)removeSymbolObject:(Symbol *)symbol {
    if (!symbol) return;
    
    [self removeSymbolsObject:symbol];  // Usa il metodo generato da Core Data
    self.lastModified = [NSDate date];
}

- (void)addSymbolsFromSet:(NSSet<Symbol *> *)symbols {
    if (!symbols || symbols.count == 0) return;
    
    [self addSymbols:symbols];  // Usa il metodo generato da Core Data
    self.lastModified = [NSDate date];
}

- (void)removeSymbolsFromSet:(NSSet<Symbol *> *)symbols {
    if (!symbols || symbols.count == 0) return;
    
    [self removeSymbols:symbols];  // Usa il metodo generato da Core Data
    self.lastModified = [NSDate date];
}

#pragma mark - String-based Convenience Methods

- (void)addSymbolWithName:(NSString *)symbolName context:(NSManagedObjectContext *)context {
    if (!symbolName || symbolName.length == 0 || !context) return;
    
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // Find or create Symbol entity
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Symbol"];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", normalizedSymbol];
    
    NSError *error;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    Symbol *symbol;
    if (results.count > 0) {
        symbol = results.firstObject;
    } else {
        // Create new Symbol
        symbol = [NSEntityDescription insertNewObjectForEntityForName:@"Symbol" inManagedObjectContext:context];
        symbol.symbol = normalizedSymbol;
        symbol.creationDate = [NSDate date];
        symbol.interactionCount = 0;
        symbol.isFavorite = NO;
    }
    
    [self addSymbolObject:symbol];
}

- (void)removeSymbolWithName:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) return;
    
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    for (Symbol *symbol in self.symbols) {
        if ([symbol.symbol isEqualToString:normalizedSymbol]) {
            [self removeSymbolObject:symbol];
            break;
        }
    }
}

- (BOOL)containsSymbolWithName:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) return NO;
    
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    for (Symbol *symbol in self.symbols) {
        if ([symbol.symbol isEqualToString:normalizedSymbol]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<NSString *> *)symbolNames {
    NSMutableArray *names = [NSMutableArray array];
    for (Symbol *symbol in self.symbols) {
        [names addObject:symbol.symbol];
    }
    return [names copy];
}

- (NSArray<NSString *> *)sortedSymbolNames {
    return [[self symbolNames] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}



#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<Watchlist: %@ (%lu symbols)>",
            self.name, (unsigned long)self.symbols.count];
}

@end
