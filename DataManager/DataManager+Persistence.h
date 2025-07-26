//
//  DataManager+Persistence.h
//  mafia_AI
//
//  Estensione per collegare DataManager con DataHub
//  Gestisce il salvataggio automatico dei dati in Core Data
//

#import <Foundation/Foundation.h>
#import "DataManager.h"


@class DataManager;

NS_ASSUME_NONNULL_BEGIN

@interface DataManager (Persistence)

// Configurazione
@property (nonatomic, assign) BOOL autoSaveToDataHub;  // Default: YES
@property (nonatomic, assign) BOOL saveHistoricalData; // Default: YES
@property (nonatomic, assign) BOOL saveMarketLists;    // Default: YES

// Metodi di salvataggio espliciti
- (void)saveQuoteToDataHub:(NSDictionary *)quoteData forSymbol:(NSString *)symbol;
- (void)saveHistoricalBarsToDataHub:(NSArray *)bars forSymbol:(NSString *)symbol timeframe:(NSInteger)timeframe;
- (void)saveMarketListToDataHub:(NSArray *)items listType:(NSString *)listType timeframe:(NSString *)timeframe;

// Sincronizzazione bulk
- (void)syncAllCachedDataToDataHub;
- (void)syncSymbolDataToDataHub:(NSString *)symbol;

// Pulizia
- (void)cleanOldDataFromDataHub:(NSInteger)daysToKeep;

@end

NS_ASSUME_NONNULL_END
