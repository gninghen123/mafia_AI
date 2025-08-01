//
//  Watchlist+CoreDataClass.m
//  mafia_AI
//

#import "Watchlist+CoreDataClass.h"

@implementation Watchlist

#pragma mark - Convenience Methods

- (void)addSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    NSMutableArray *currentSymbols = [self.symbols mutableCopy] ?: [NSMutableArray array];
    NSString *upperSymbol = symbol.uppercaseString;
    
    if (![currentSymbols containsObject:upperSymbol]) {
        [currentSymbols addObject:upperSymbol];
        self.symbols = currentSymbols;
        self.lastModified = [NSDate date];
    }
}

- (void)removeSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    NSMutableArray *currentSymbols = [self.symbols mutableCopy];
    NSString *upperSymbol = symbol.uppercaseString;
    
    if ([currentSymbols containsObject:upperSymbol]) {
        [currentSymbols removeObject:upperSymbol];
        self.symbols = currentSymbols;
        self.lastModified = [NSDate date];
    }
}

- (BOOL)containsSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return NO;
    
    NSString *upperSymbol = symbol.uppercaseString;
    return [self.symbols containsObject:upperSymbol];
}

- (NSArray<NSString *> *)sortedSymbols {
    return [self.symbols sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<Watchlist: %@ (%lu symbols)>",
            self.name, (unsigned long)self.symbols.count];
}

@end
