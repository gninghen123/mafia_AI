//
//  StorageSystemInitializer.h
//  TradingApp
//
//  Inizializzatore per il sistema completo di storage automatico Fase 2
//  Da chiamare all'avvio dell'app per attivare tutto il sistema
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Singleton per inizializzare e coordinare tutto il sistema di storage automatico
@interface StorageSystemInitializer : NSObject

#pragma mark - Singleton

+ (instancetype)sharedInitializer;

#pragma mark - System Initialization

/// Inizializza tutto il sistema di storage automatico
/// Deve essere chiamato dopo l'inizializzazione di DataHub
/// @param completion Block chiamato al completamento dell'inizializzazione
- (void)initializeStorageSystemWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/// Verifica se il sistema è completamente inizializzato
@property (nonatomic, readonly) BOOL isSystemInitialized;

#pragma mark - System Status

/// Stato corrente del sistema di storage
@property (nonatomic, readonly) NSString *systemStatus;

/// Numero totale di storage attivi
@property (nonatomic, readonly) NSInteger totalActiveStorages;

/// Prossimo update programmato
@property (nonatomic, readonly, nullable) NSDate *nextScheduledUpdate;

#pragma mark - Configuration

/// Configurazione predefinita per development/testing
- (void)applyDevelopmentConfiguration;

/// Configurazione predefinita per production
- (void)applyProductionConfiguration;

/// Reset completo del sistema (per testing)
- (void)resetSystemForTesting;

#pragma mark - Health Checks

/// Esegue un health check completo del sistema
/// @param completion Block con risultati del check
- (void)performSystemHealthCheck:(void(^)(BOOL healthy, NSArray<NSString *> *issues))completion;

/// Risolve automaticamente problemi comuni
- (void)attemptAutoRecovery;

@end
NS_ASSUME_NONNULL_END
