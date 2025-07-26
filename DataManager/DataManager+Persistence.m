//
//  DataManager+Persistence.m
//  mafia_AI
//

#import "DataManager+Persistence.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "DataAdapterFactory.h"
#import "DataSourceAdapter.h"
#import <objc/runtime.h>

// Chiavi per proprietà associate
static const char kAutoSaveToDataHubKey;
static const char kSaveHistoricalDataKey;
static const char kSaveMarketListsKey;

@implementation DataManager (Persistence)

#pragma mark - Proprietà Associate

- (BOOL)autoSaveToDataHub {
    NSNumber *value = objc_getAssociatedObject(self, &kAutoSaveToDataHubKey);
    return value ? [value boolValue] : YES; // Default: YES
}

- (void)setAutoSaveToDataHub:(BOOL)autoSave {
    objc_setAssociatedObject(self, &kAutoSaveToDataHubKey, @(autoSave), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)saveHistoricalData {
    NSNumber *value = objc_getAssociatedObject(self, &kSaveHistoricalDataKey);
    return value ? [value boolValue] : YES;
}

- (void)setSaveHistoricalData:(BOOL)save {
    objc_setAssociatedObject(self, &kSaveHistoricalDataKey, @(save), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)saveMarketLists {
    NSNumber *value = objc_getAssociatedObject(self, &kSaveMarketListsKey);
    return value ? [value boolValue] : YES;
}

- (void)setSaveMarketLists:(BOOL)save {
    objc_setAssociatedObject(self, &kSaveMarketListsKey, @(save), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Metodi di Salvataggio

- (void)saveQuoteToDataHub:(NSDictionary *)quoteData forSymbol:(NSString *)symbol {
    if (!self.autoSaveToDataHub) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        // Converti in formato standard per DataHub
        NSMutableDictionary *standardData = [NSMutableDictionary dictionary];
        
        // Mappa i campi dal formato DataManager al formato DataHub
        standardData[@"symbol"] = symbol;
        standardData[@"name"] = quoteData[@"name"] ?: symbol;
        standardData[@"exchange"] = quoteData[@"exchange"] ?: @"";
        
        // Prezzi
        standardData[@"currentPrice"] = quoteData[@"last"] ?: @0;
        standardData[@"previousClose"] = quoteData[@"previousClose"] ?: @0;
        standardData[@"open"] = quoteData[@"open"] ?: @0;
        standardData[@"high"] = quoteData[@"high"] ?: @0;
        standardData[@"low"] = quoteData[@"low"] ?: @0;
        
        // Variazioni
        standardData[@"change"] = quoteData[@"change"] ?: @0;
        standardData[@"changePercent"] = quoteData[@"changePercent"] ?: @0;
        
        // Volume
        standardData[@"volume"] = quoteData[@"volume"] ?: @0;
        standardData[@"avgVolume"] = quoteData[@"avgVolume"] ?: @0;
        
        // Altri dati
        standardData[@"marketCap"] = quoteData[@"marketCap"] ?: @0;
        standardData[@"pe"] = quoteData[@"pe"] ?: @0;
        standardData[@"eps"] = quoteData[@"eps"] ?: @0;
        standardData[@"beta"] = quoteData[@"beta"] ?: @0;
        
        // Timestamp
        standardData[@"marketTime"] = quoteData[@"timestamp"] ?: [NSDate date];
        
        // Salva nel DataHub
        [[DataHub shared] saveMarketQuote:standardData forSymbol:symbol];
        
        NSLog(@"DataManager: Saved quote for %@ to DataHub", symbol);
    });
}

- (void)saveHistoricalBarsToDataHub:(NSArray *)bars forSymbol:(NSString *)symbol timeframe:(NSInteger)timeframe {
    if (!self.autoSaveToDataHub || !self.saveHistoricalData) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSMutableArray *standardBars = [NSMutableArray array];
        
        for (NSDictionary *bar in bars) {
            NSMutableDictionary *standardBar = [NSMutableDictionary dictionary];
            
            standardBar[@"date"] = bar[@"date"];
            standardBar[@"open"] = bar[@"open"] ?: @0;
            standardBar[@"high"] = bar[@"high"] ?: @0;
            standardBar[@"low"] = bar[@"low"] ?: @0;
            standardBar[@"close"] = bar[@"close"] ?: @0;
            standardBar[@"adjustedClose"] = bar[@"adjustedClose"] ?: bar[@"close"] ?: @0;
            standardBar[@"volume"] = bar[@"volume"] ?: @0;
            
            [standardBars addObject:standardBar];
        }
        
        [[DataHub shared] saveHistoricalBars:standardBars forSymbol:symbol timeframe:timeframe];
        
        NSLog(@"DataManager: Saved %lu historical bars for %@ to DataHub",
              (unsigned long)bars.count, symbol);
    });
}

- (void)saveMarketListToDataHub:(NSArray *)items listType:(NSString *)listType timeframe:(NSString *)timeframe {
    if (!self.autoSaveToDataHub || !self.saveMarketLists) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSMutableArray *performers = [NSMutableArray array];
        
        for (NSDictionary *item in items) {
            NSMutableDictionary *performer = [NSMutableDictionary dictionary];
            
            performer[@"symbol"] = item[@"symbol"];
            performer[@"name"] = item[@"name"] ?: item[@"symbol"];
            performer[@"price"] = item[@"price"] ?: @0;
            performer[@"changePercent"] = item[@"changePercent"] ?: @0;
            performer[@"volume"] = item[@"volume"] ?: @0;
            
            [performers addObject:performer];
        }
        
        [[DataHub shared] saveMarketPerformers:performers
                                      listType:listType
                                     timeframe:timeframe];
        
        NSLog(@"DataManager: Saved %lu items for %@ list to DataHub",
              (unsigned long)items.count, listType);
    });
}

#pragma mark - Sincronizzazione Bulk

- (void)syncAllCachedDataToDataHub {
    NSLog(@"DataManager: Starting bulk sync to DataHub...");
    
    // Ottieni tutti i simboli dalla cache
    NSArray *cachedSymbols = [self getAllCachedSymbols];
    
    for (NSString *symbol in cachedSymbols) {
        [self syncSymbolDataToDataHub:symbol];
    }
    
    NSLog(@"DataManager: Bulk sync completed for %lu symbols", (unsigned long)cachedSymbols.count);
}

- (void)syncSymbolDataToDataHub:(NSString *)symbol {
    // Ottieni quote dalla cache
    NSDictionary *cachedQuote = [self getCachedQuoteForSymbol:symbol];
    if (cachedQuote) {
        [self saveQuoteToDataHub:cachedQuote forSymbol:symbol];
    }
}

#pragma mark - Pulizia

- (void)cleanOldDataFromDataHub:(NSInteger)daysToKeep {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [[DataHub shared] cleanOldQuotes:daysToKeep];
        [[DataHub shared] cleanOldMarketPerformers:daysToKeep * 24]; // Converti in ore
        
        NSLog(@"DataManager: Cleaned old data from DataHub (keeping last %ld days)", (long)daysToKeep);
    });
}

#pragma mark - Helper Methods

- (NSArray *)getAllCachedSymbols {
    // Questo metodo dovrebbe essere implementato nel DataManager principale
    // Per ora restituiamo un array vuoto
    return @[];
}

- (NSDictionary *)getCachedQuoteForSymbol:(NSString *)symbol {
    // Questo metodo dovrebbe essere implementato nel DataManager principale
    // Per ora restituiamo nil
    return nil;
}

@end
