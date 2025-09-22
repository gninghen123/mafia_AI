//
//  TagManager.h
//  TradingApp
//
//  Centralizzato manager per accesso immediato a tag e simboli
//  ✅ OPZIONE 4: Rebuild in background ogni avvio - Source of Truth = CoreData
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TagManagerState) {
    TagManagerStateEmpty,       // Initial state
    TagManagerStateBuilding,    // Background building in progress
    TagManagerStateReady,       // Cache ready for use
    TagManagerStateError        // Build failed
};

// Notifications
extern NSString * const TagManagerDidStartBuildingNotification;
extern NSString * const TagManagerDidFinishBuildingNotification;
extern NSString * const TagManagerDidUpdateNotification;

@interface TagManager : NSObject

#pragma mark - Singleton

+ (instancetype)sharedManager;

#pragma mark - State

@property (nonatomic, assign, readonly) TagManagerState state;
@property (nonatomic, assign, readonly) NSTimeInterval lastBuildTime;
@property (nonatomic, assign, readonly) NSUInteger totalSymbolsWithTags;
@property (nonatomic, assign, readonly) NSUInteger totalUniqueTags;

#pragma mark - Cache Building

/**
 * Inizia il rebuild della cache in background
 * Può essere chiamato multiple volte (ignora se già in corso)
 */
- (void)buildCacheInBackground;

/**
 * Force rebuild immediato (blocking) - solo per testing
 */
- (void)rebuildCacheSync;

/**
 * Invalida la cache e forza rebuild
 */
- (void)invalidateAndRebuild;

#pragma mark - Immediate Access (O(1) performance)

/**
 * Tutti i tag attivi nel sistema (ordinati alfabeticamente)
 * @return Array di tag strings, empty se cache non pronta
 */
- (NSArray<NSString *> *)allActiveTags;

/**
 * Simboli che hanno un tag specifico (ordinati per lastInteraction)
 * @param tag Il tag da cercare
 * @return Array di symbol strings, empty se tag non trovato o cache non pronta
 */
- (NSArray<NSString *> *)symbolsWithTag:(NSString *)tag;

/**
 * Tag assegnati a un simbolo specifico
 * @param symbol Il simbolo da cercare
 * @return Array di tag strings, empty se simbolo non trovato o cache non pronta
 */
- (NSArray<NSString *> *)tagsForSymbol:(NSString *)symbol;

/**
 * Conteggio simboli per un tag
 * @param tag Il tag da contare
 * @return Numero di simboli con quel tag, 0 se non trovato o cache non pronta
 */
- (NSUInteger)symbolCountForTag:(NSString *)tag;

/**
 * Controlla se un tag esiste nel sistema
 * @param tag Il tag da verificare
 * @return YES se il tag esiste, NO altrimenti
 */
- (BOOL)tagExists:(NSString *)tag;

/**
 * Controlla se un simbolo ha un tag specifico
 * @param symbol Il simbolo da verificare
 * @param tag Il tag da cercare
 * @return YES se il simbolo ha quel tag, NO altrimenti
 */
- (BOOL)symbol:(NSString *)symbol hasTag:(NSString *)tag;

#pragma mark - Real-time Updates

/**
 * Aggiorna la cache quando viene aggiunto un tag (chiamato dalle notifications)
 * @param tag Il tag aggiunto
 * @param symbol Il simbolo modificato
 */
- (void)tagAdded:(NSString *)tag toSymbol:(NSString *)symbol;

/**
 * Aggiorna la cache quando viene rimosso un tag (chiamato dalle notifications)
 * @param tag Il tag rimosso
 * @param symbol Il simbolo modificato
 */
- (void)tagRemoved:(NSString *)tag fromSymbol:(NSString *)symbol;

/**
 * Aggiorna la cache quando un simbolo viene eliminato
 * @param symbol Il simbolo eliminato
 */
- (void)symbolDeleted:(NSString *)symbol;

#pragma mark - Debugging & Statistics

/**
 * Statistiche dettagliate della cache
 */
- (NSString *)cacheStatistics;

/**
 * Log dello stato corrente per debugging
 */
- (void)logCurrentState;

@end

NS_ASSUME_NONNULL_END
