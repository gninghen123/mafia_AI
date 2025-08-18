//
//  DataHub+StorageIntegration.h
//  TradingApp
//
//  Extension per integrare DataHub con StorageManager
//  Gestisce opportunistic updates e notificazioni
//

#import "DataHub.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (StorageIntegration)

#pragma mark - Storage Manager Integration

/// Inizializza l'integrazione con StorageManager
/// Deve essere chiamato dopo l'inizializzazione di DataHub
- (void)initializeStorageManagerIntegration;

/// Notifica StorageManager di un download completato
/// @param symbol Simbolo scaricato
/// @param timeframe Timeframe dei dati
/// @param bars Array di barre scaricate
/// @param fromDate Data iniziale del range
/// @param toDate Data finale del range
- (void)notifyStorageManagerOfDownload:(NSString *)symbol
                             timeframe:(BarTimeframe)timeframe
                                  bars:(NSArray<HistoricalBarModel *> *)bars
                              fromDate:(NSDate *)fromDate
                                toDate:(NSDate *)toDate;

#pragma mark - Enhanced Historical Data Methods

/// Versione migliorata di requestHistoricalData che supporta opportunistic updates
/// @param symbol Simbolo da scaricare
/// @param timeframe Timeframe richiesto
/// @param fromDate Data di inizio
/// @param toDate Data di fine
/// @param completionHandler Completion handler per il risultato
- (void)requestHistoricalDataWithStorageAwareness:(NSString *)symbol
                                        timeframe:(BarTimeframe)timeframe
                                         fromDate:(NSDate *)fromDate
                                           toDate:(NSDate *)toDate
                                completionHandler:(void(^)(NSArray<HistoricalBarModel *> * _Nullable bars, NSError * _Nullable error))completionHandler;

#pragma mark - Storage-Aware Caching

/// Controlla se esistono continuous storage per un simbolo/timeframe
/// @param symbol Simbolo da controllare
/// @param timeframe Timeframe da controllare
/// @return YES se esiste uno storage continuo compatibile
- (BOOL)hasContinuousStorageForSymbol:(NSString *)symbol timeframe:(BarTimeframe)timeframe;

/// Ottiene dati da continuous storage se disponibile
/// @param symbol Simbolo richiesto
/// @param timeframe Timeframe richiesto
/// @param fromDate Data di inizio richiesta
/// @param toDate Data di fine richiesta
/// @return Array di barre dal storage, nil se non disponibile
- (NSArray<HistoricalBarModel *> * _Nullable)getStorageDataForSymbol:(NSString *)symbol
                                                           timeframe:(BarTimeframe)timeframe
                                                            fromDate:(NSDate *)fromDate
                                                              toDate:(NSDate *)toDate;

#pragma mark - Configuration

/// Abilita/disabilita l'integrazione con StorageManager
@property (nonatomic, assign) BOOL storageIntegrationEnabled; // Default: YES

/// Abilita/disabilita gli opportunistic updates automatici
@property (nonatomic, assign) BOOL opportunisticUpdatesEnabled; // Default: YES

/// Threshold per attivare opportunistic updates (numero minimo di barre overlap)
@property (nonatomic, assign) NSInteger opportunisticUpdateThreshold; // Default: 10

@end

NS_ASSUME_NONNULL_END
