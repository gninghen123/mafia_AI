//
//  Symbol+CoreDataClass.m
//  mafia_AI
//

#import "Symbol+CoreDataClass.h"
#import "Alert+CoreDataClass.h"
#import "Watchlist+CoreDataClass.h"
#import "StockConnection+CoreDataClass.h"
#import "MarketQuote+CoreDataClass.h"
#import "HistoricalBar+CoreDataClass.h"
#import "CompanyInfo+CoreDataClass.h"
#import "TradingModel+CoreDataClass.h"

@implementation Symbol

#pragma mark - Convenience Methods

- (void)incrementInteraction {
    self.interactionCount++;
    self.lastInteraction = [NSDate date];
    
    if (!self.firstInteraction) {
        self.firstInteraction = [NSDate date];
    }
}

- (NSArray<NSString *> *)allRelatedSymbols {
    NSMutableSet<NSString *> *relatedSymbols = [NSMutableSet set];
    
    // From source connections
    for (StockConnection *connection in self.sourceConnections) {
        for (Symbol *target in connection.targetSymbols) {
            [relatedSymbols addObject:target.symbol];
        }
    }
    
    // From target connections
    for (StockConnection *connection in self.targetConnections) {
        if (connection.sourceSymbol) {
            [relatedSymbols addObject:connection.sourceSymbol.symbol];
        }
        // Also add other targets in the same connection
        for (Symbol *target in connection.targetSymbols) {
            if (![target.symbol isEqualToString:self.symbol]) {
                [relatedSymbols addObject:target.symbol];
            }
        }
    }
    
    return [relatedSymbols allObjects];
}

- (NSInteger)activeConnectionsCount {
    NSInteger count = 0;
    
    for (StockConnection *connection in self.sourceConnections) {
        if (connection.isActive) count++;
    }
    
    for (StockConnection *connection in self.targetConnections) {
        if (connection.isActive) count++;
    }
    
    return count;
}

- (NSInteger)activeAlertsCount {
    NSInteger count = 0;
    
    for (Alert *alert in self.alerts) {
        if (alert.isActive && !alert.isTriggered) count++;
    }
    
    return count;
}

- (NSArray<Watchlist *> *)sortedWatchlists {
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES];
    return [self.watchlists sortedArrayUsingDescriptors:@[sortDescriptor]];
}

- (MarketQuote *)latestMarketQuote {
    if (self.marketQuotes.count == 0) return nil;
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"lastUpdate" ascending:NO];
    NSArray *sortedQuotes = [self.marketQuotes sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    return sortedQuotes.firstObject;
}

- (NSArray<HistoricalBar *> *)historicalBarsForTimeframe:(int16_t)timeframe limit:(NSInteger)limit {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"timeframe == %d", timeframe];
    NSSet *filteredBars = [self.historicalBars filteredSetUsingPredicate:predicate];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
    NSArray *sortedBars = [filteredBars sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    if (limit > 0 && sortedBars.count > limit) {
           NSInteger startIndex = MAX(0, sortedBars.count - limit);
           NSRange range = NSMakeRange(startIndex, sortedBars.count - startIndex);
           return [sortedBars subarrayWithRange:range];
       }
    
    return sortedBars;
}

#pragma mark - Tag Management

- (void)addTag:(NSString *)tag {
    if (!tag || tag.length == 0) return;
    
    NSMutableArray *currentTags = [self.tags mutableCopy] ?: [NSMutableArray array];
    NSString *normalizedTag = tag.lowercaseString;
    
    if (![currentTags containsObject:normalizedTag]) {
        [currentTags addObject:normalizedTag];
        self.tags = [currentTags copy];
    }
}

- (void)removeTag:(NSString *)tag {
    if (!tag || tag.length == 0) return;
    
    NSMutableArray *currentTags = [self.tags mutableCopy];
    NSString *normalizedTag = tag.lowercaseString;
    
    [currentTags removeObject:normalizedTag];
    self.tags = [currentTags copy];
}

- (BOOL)hasTag:(NSString *)tag {
    if (!tag || tag.length == 0) return NO;
    
    NSString *normalizedTag = tag.lowercaseString;
    return [self.tags containsObject:normalizedTag];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<Symbol: %@ (interactions: %d, connections: %ld, alerts: %ld, watchlists: %ld)>",
            self.symbol, self.interactionCount,
            (long)[self activeConnectionsCount],
            (long)[self activeAlertsCount],
            (long)self.watchlists.count];
}

@end
