//
//  Watchlist+CoreDataClass.m
//  mafia_AI
//

#import "Watchlist+CoreDataClass.h"
#import "Symbol+CoreDataClass.h"

@implementation Watchlist

#pragma mark - Symbol Relationship Management

- (void)addSymbolObject:(Symbol *)symbol {
    if (!symbol) {
        NSLog(@"❌ addSymbolObject: symbol is nil");
        return;
    }
    
    [self addSymbolsObject:symbol];  // Usa il metodo generato da Core Data
    self.lastModified = [NSDate date];
    
    NSLog(@"✅ Added symbol %@ to watchlist %@", symbol.symbol, self.name);
}

- (void)removeSymbolObject:(Symbol *)symbol {
    if (!symbol) {
        NSLog(@"❌ removeSymbolObject: symbol is nil");
        return;
    }
    
    [self removeSymbolsObject:symbol];  // Usa il metodo generato da Core Data
    self.lastModified = [NSDate date];
    
    NSLog(@"✅ Removed symbol %@ from watchlist %@", symbol.symbol, self.name);
}

- (void)addSymbolsFromSet:(NSSet<Symbol *> *)symbols {
    if (!symbols || symbols.count == 0) return;
    
    [self addSymbols:symbols];  // Usa il metodo generato da Core Data
    self.lastModified = [NSDate date];
    
    NSLog(@"✅ Added %lu symbols to watchlist %@", (unsigned long)symbols.count, self.name);
}

- (void)removeSymbolsFromSet:(NSSet<Symbol *> *)symbols {
    if (!symbols || symbols.count == 0) return;
    
    [self removeSymbols:symbols];  // Usa il metodo generato da Core Data
    self.lastModified = [NSDate date];
    
    NSLog(@"✅ Removed %lu symbols from watchlist %@", (unsigned long)symbols.count, self.name);
}
- (void)addSymbolWithName:(NSString *)symbolName context:(NSManagedObjectContext *)context {
    if (!symbolName || symbolName.length == 0 || !context) {
        NSLog(@"❌ addSymbolWithName: Invalid parameters - symbolName: %@, context: %@", symbolName, context);
        return;
    }
    
    // RICORDA: Normalizzazione UPPERCASE!
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // Check if symbol already exists in this watchlist
    if ([self containsSymbolWithName:normalizedSymbol]) {
        NSLog(@"⚠️ Symbol %@ already exists in watchlist %@", normalizedSymbol, self.name);
        return;
    }
    
    // ✅ FIXED: Find or create Symbol entity
    Symbol *symbolEntity = [self findOrCreateSymbolWithName:normalizedSymbol inContext:context];
    if (!symbolEntity) {
        NSLog(@"❌ Failed to find/create symbol entity: %@", normalizedSymbol);
        return;
    }
    
    // Add to watchlist
    [self addSymbolObject:symbolEntity];
    
    NSLog(@"✅ Added symbol %@ to watchlist %@ via string method", normalizedSymbol, self.name);
}

- (void)removeSymbolWithName:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) {
        NSLog(@"❌ removeSymbolWithName: symbolName is empty");
        return;
    }
    
    // RICORDA: Normalizzazione UPPERCASE!
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // ✅ FIXED: Find symbol entity in this watchlist
    Symbol *symbolToRemove = nil;
    for (Symbol *symbol in self.symbols) {
        if ([symbol.symbol isEqualToString:normalizedSymbol]) {
            symbolToRemove = symbol;
            break;
        }
    }
    
    if (symbolToRemove) {
        [self removeSymbolObject:symbolToRemove];
        NSLog(@"✅ Removed symbol %@ from watchlist %@", normalizedSymbol, self.name);
    } else {
        NSLog(@"⚠️ Symbol %@ not found in watchlist %@", normalizedSymbol, self.name);
    }
}

- (BOOL)containsSymbolWithName:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) return NO;
    
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // ✅ FIXED: Safe iteration through NSSet<Symbol *>
    for (Symbol *symbol in self.symbols) {
        if ([symbol isKindOfClass:[Symbol class]] &&
            [symbol.symbol isEqualToString:normalizedSymbol]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<NSString *> *)symbolNames {
    NSMutableArray *names = [NSMutableArray array];
    
    // ✅ FIXED: Safe conversion NSSet<Symbol *> → NSArray<NSString *>
    for (Symbol *symbol in self.symbols) {
        if ([symbol isKindOfClass:[Symbol class]] &&
            symbol.symbol &&
            [symbol.symbol isKindOfClass:[NSString class]]) {
            [names addObject:symbol.symbol];
        } else {
            NSLog(@"⚠️ Invalid symbol entity in watchlist %@: %@", self.name, symbol);
        }
    }
    
    return [names copy];
}

- (NSArray<NSString *> *)sortedSymbolNames {
    NSArray<NSString *> *names = [self symbolNames];
    return [names sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

#pragma mark - MISSING: Helper Method for Symbol Finding/Creation

- (Symbol *)findOrCreateSymbolWithName:(NSString *)symbolName inContext:(NSManagedObjectContext *)context {
    if (!symbolName || symbolName.length == 0 || !context) return nil;
    
    // RICORDA: Normalizzazione UPPERCASE!
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // Try to find existing symbol in context
    NSFetchRequest *request = [Symbol fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", normalizedSymbol];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ Error finding symbol %@: %@", normalizedSymbol, error);
        return nil;
    }
    
    if (results.count > 0) {
        // Return existing
        return results.firstObject;
    }
    
    // Create new symbol
    Symbol *symbol = [NSEntityDescription insertNewObjectForEntityForName:@"Symbol"
                                                   inManagedObjectContext:context];
    symbol.symbol = normalizedSymbol;
    symbol.creationDate = [NSDate date];
    symbol.firstInteraction = [NSDate date];
    symbol.lastInteraction = [NSDate date];
    symbol.interactionCount = 1;
    symbol.isFavorite = NO;
    symbol.tags = @[];
    
    NSLog(@"✅ Created new symbol: %@", normalizedSymbol);
    
    return symbol;
}

#pragma mark - VALIDATION: Watchlist Symbol Consistency

- (void)validateSymbolConsistency {
    NSLog(@"\n🔍 VALIDATION: Watchlist '%@' Symbol Consistency", self.name);
    NSLog(@"======================================================");
    
    NSInteger validSymbols = 0;
    NSInteger invalidSymbols = 0;
    NSMutableArray *issues = [NSMutableArray array];
    
    for (id obj in self.symbols) {
        if ([obj isKindOfClass:[Symbol class]]) {
            Symbol *symbol = (Symbol *)obj;
            if (symbol.symbol && [symbol.symbol isKindOfClass:[NSString class]]) {
                validSymbols++;
                NSLog(@"   ✅ %@ (interactions: %d)", symbol.symbol, symbol.interactionCount);
            } else {
                invalidSymbols++;
                [issues addObject:[NSString stringWithFormat:@"Symbol entity missing .symbol property: %@", obj]];
            }
        } else {
            invalidSymbols++;
            [issues addObject:[NSString stringWithFormat:@"Non-Symbol object: %@", NSStringFromClass([obj class])]];
        }
    }
    
    NSLog(@"SUMMARY:");
    NSLog(@"✅ Valid symbols: %ld", (long)validSymbols);
    NSLog(@"❌ Invalid symbols: %ld", (long)invalidSymbols);
    
    if (issues.count > 0) {
        NSLog(@"ISSUES:");
        for (NSString *issue in issues) {
            NSLog(@"   - %@", issue);
        }
    }
    
    // Test string methods
    NSArray<NSString *> *symbolNames = [self symbolNames];
    NSLog(@"String conversion test: %lu symbols → %lu names",
          (unsigned long)self.symbols.count, (unsigned long)symbolNames.count);
    
    if (symbolNames.count != self.symbols.count) {
        NSLog(@"❌ MISMATCH: symbols.count ≠ symbolNames.count");
    }
    
    NSLog(@"VALIDATION COMPLETE\n");
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<Watchlist: %@ (%lu symbols)>",
            self.name, (unsigned long)self.symbols.count];
}

@end
