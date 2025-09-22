//
//  StorageManager.h
//  TradingApp
//
//  Gestisce il sistema di storage automatico per continuous storage
//  Fase 2: Timer automatici, opportunistic updates, gap recovery
//

#import <Foundation/Foundation.h>
#import "SavedChartData.h"

NS_ASSUME_NONNULL_BEGIN

@class SavedChartData;

/// Rappresenta uno storage attivo nel registry
@interface ActiveStorageItem : NSObject
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) SavedChartData *savedData;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, assign) NSInteger failureCount;
@property (nonatomic, strong, nullable) NSDate *lastFailureDate;
@property (nonatomic, assign) BOOL isPaused;
@end

/// Rappresenta un item unificato (continuous + snapshot)
@interface UnifiedStorageItem : NSObject
@property (nonatomic, assign) SavedChartDataType dataType;
@property (nonatomic, strong) SavedChartData *savedData;
@property (nonatomic, strong, nullable) ActiveStorageItem *activeItem; // nil per snapshot
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, readonly) BOOL isContinuous;
@property (nonatomic, readonly) BOOL isSnapshot;
@end

/// Gestisce tutti i continuous storage attivi con timer automatici
@interface StorageManager : NSObject

#pragma mark - Singleton

+ (instancetype)sharedManager;

#pragma mark - Unified Storage Management (Continuous + Snapshot)

/// Lista di tutti gli storage (continuous + snapshot) per il widget unificato
@property (nonatomic, readonly) NSArray<UnifiedStorageItem *> *allStorageItems;

/// Lista solo dei continuous storage come UnifiedStorageItem
@property (nonatomic, readonly) NSArray<UnifiedStorageItem *> *continuousStorageItems;

/// Lista solo degli snapshot come UnifiedStorageItem
@property (nonatomic, readonly) NSArray<UnifiedStorageItem *> *snapshotStorageItems;

/// Carica tutti i file di storage dal filesystem
- (void)refreshAllStorageItems;

/// Elimina un qualsiasi storage (continuous o snapshot)
/// @param filePath Path del file da eliminare
/// @param completion Completion con risultato
- (void)deleteStorageItem:(NSString *)filePath
               completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

#pragma mark - Registry Management

/// Avvia il tracking di un continuous storage esistente
/// @param filePath Path al file .chartdata
/// @return YES se aggiunto con successo al registry
- (BOOL)registerContinuousStorage:(NSString *)filePath;

/// Ferma il tracking di un continuous storage
/// @param filePath Path al file da rimuovere dal tracking
- (void)unregisterContinuousStorage:(NSString *)filePath;

/// Lista di tutti gli storage attivi nel registry
@property (nonatomic, readonly) NSArray<ActiveStorageItem *> *activeStorages;

#pragma mark - Timer System

/// Avvia tutti i timer automatici per gli storage registrati
- (void)startAllTimers;

/// Ferma tutti i timer automatici
- (void)stopAllTimers;

- (void)invalidateCache;

/// Pausa/riprende un singolo storage
/// @param filePath Path del file da pausare/riprendere
/// @param paused YES per pausare, NO per riprendere
- (void)setPaused:(BOOL)paused forStorage:(NSString *)filePath;

#pragma mark - Manual Updates

/// Forza un update manuale per un specific storage
/// @param filePath Path del file da aggiornare
/// @param completion Completion con risultato
- (void)forceUpdateForStorage:(NSString *)filePath
                   completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/// Forza l'update di tutti gli storage attivi
- (void)forceUpdateAllStorages;

#pragma mark - Opportunistic Updates

/// Chiamato quando DataHub scarica nuovi dati
/// Controlla se ci sono storage compatibili da aggiornare automaticamente
/// @param symbol Simbolo scaricato
/// @param timeframe Timeframe dei dati
/// @param bars Array di nuove barre
- (void)handleOpportunisticUpdate:(NSString *)symbol
                        timeframe:(BarTimeframe)timeframe
                             bars:(NSArray<HistoricalBarModel *> *)bars;

#pragma mark - Gap Recovery

/// Converte un storage con gap irreversibili in snapshot
/// @param filePath Path del file da convertire
/// @param userConfirmed YES se l'utente ha confermato la conversione
- (void)convertStorageToSnapshot:(NSString *)filePath userConfirmed:(BOOL)userConfirmed;

/// Mostra dialog di conferma per conversion a snapshot
/// @param storageItem Item con gap da convertire
- (void)showGapRecoveryDialogForStorage:(ActiveStorageItem *)storageItem;

#pragma mark - Configuration

/// Numero massimo di retry prima di considerare gap irreversibile
@property (nonatomic, assign) NSInteger maxRetryCount; // Default: 10

/// Giorni di tolleranza per gap detection
@property (nonatomic, assign) NSInteger gapToleranceDays; // Default: 15

/// Abilita/disabilita il sistema di update automatici
@property (nonatomic, assign) BOOL automaticUpdatesEnabled; // Default: YES

#pragma mark - Statistics & Monitoring

/// Numero totale di storage attivi
@property (nonatomic, readonly) NSInteger totalActiveStorages;

/// Numero totale di snapshot salvati
@property (nonatomic, readonly) NSInteger totalSnapshotStorages;

/// Numero totale di tutti gli storage (continuous + snapshot)
@property (nonatomic, readonly) NSInteger totalAllStorages;

/// Numero di storage con errori
@property (nonatomic, readonly) NSInteger storagesWithErrors;

/// Numero di storage pausati dall'utente
@property (nonatomic, readonly) NSInteger pausedStorages;

/// Storage con prossimo update più vicino
@property (nonatomic, readonly, nullable) ActiveStorageItem *nextStorageToUpdate;



- (void)forceConsistencyCheck;


@end

NS_ASSUME_NONNULL_END
