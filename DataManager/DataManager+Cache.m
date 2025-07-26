//
//  DataManager+Cache.m
//  mafia_AI
//

#import "DataManager+Cache.h"
#import <objc/runtime.h>
#import "MarketData.h"  // Aggiungi questo import

// Dichiariamo le proprietà private che vogliamo accedere
@interface DataManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketData *> *quoteCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *cacheTimestamps;
@end

@implementation DataManager (Cache)

- (NSArray<NSString *> *)getAllCachedSymbols {
    @synchronized(self.quoteCache) {
        return [self.quoteCache allKeys];
    }
}

- (NSDictionary *)getCachedQuoteForSymbol:(NSString *)symbol {
    MarketData *marketData = [self getCachedMarketDataForSymbol:symbol];
    if (!marketData) return nil;
    
    // Converti MarketData in dictionary
    return @{
        @"symbol": marketData.symbol ?: symbol,
        @"name": marketData.name ?: @"",
        @"last": marketData.last ?: @0,
        @"bid": marketData.bid ?: @0,
        @"ask": marketData.ask ?: @0,
        @"volume": marketData.volume ?: @0,
        @"open": marketData.open ?: @0,
        @"high": marketData.high ?: @0,
        @"low": marketData.low ?: @0,
        @"previousClose": marketData.previousClose ?: @0,
        @"change": marketData.change ?: @0,
        @"changePercent": marketData.changePercent ?: @0,
        @"timestamp": marketData.timestamp ?: [NSDate date]
    };
}

- (MarketData *)getCachedMarketDataForSymbol:(NSString *)symbol {
    @synchronized(self.quoteCache) {
        return self.quoteCache[symbol];
    }
}

- (void)clearAllCache {
    @synchronized(self.quoteCache) {
        [self.quoteCache removeAllObjects];
        [self.cacheTimestamps removeAllObjects];
    }
}

@end
