//
//  DataManager+Cache.h
//  mafia_AI
//
//  Metodi helper per accedere alla cache interna
//

#import "DataManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataManager (Cache)

// Accesso alla cache
- (NSArray<NSString *> *)getAllCachedSymbols;
- (NSDictionary * _Nullable)getCachedQuoteForSymbol:(NSString *)symbol;
- (MarketData * _Nullable)getCachedMarketDataForSymbol:(NSString *)symbol;

// Gestione cache
- (void)clearCacheForSymbol:(NSString *)symbol;
- (void)clearAllCache;

@end

NS_ASSUME_NONNULL_END
