//
//  SymbolDataHub.h
//  TradingApp
//
//  Database centralizzato per tutte le informazioni sui simboli
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declarations
@class SymbolData;
@class AlertData;
@class TagData;
@class NoteData;
@class NewsData;
@class TradingConfigData;
@protocol DataPersistable;

// Notification keys
extern NSString * const kSymbolDataUpdatedNotification;
extern NSString * const kSymbolDataAddedNotification;
extern NSString * const kSymbolDataRemovedNotification;
extern NSString * const kAlertTriggeredNotification;

// Notification userInfo keys
extern NSString * const kSymbolKey;
extern NSString * const kUpdateTypeKey;
extern NSString * const kOldValueKey;
extern NSString * const kNewValueKey;

// Update types - RIMOSSO DA QUI perché è già in SymbolDataModels.h

// Completion blocks
typedef void (^SymbolDataCompletionBlock)(SymbolData * _Nullable symbolData, NSError * _Nullable error);
typedef void (^SymbolSearchCompletionBlock)(NSArray<SymbolData *> * _Nullable results, NSError * _Nullable error);

@interface SymbolDataHub : NSObject

// Singleton
+ (instancetype)sharedHub;

// Core Data stack
@property (readonly, strong, nonatomic) NSPersistentContainer *persistentContainer;
@property (readonly, strong, nonatomic) NSManagedObjectContext *mainContext;

// Inizializzazione
- (void)initializeWithCompletion:(nullable void(^)(NSError * _Nullable error))completion;

#pragma mark - Symbol Management

// Recupera o crea dati per un simbolo
- (SymbolData *)dataForSymbol:(NSString *)symbol;

// Verifica se esiste un simbolo
- (BOOL)hasDataForSymbol:(NSString *)symbol;

// Rimuovi tutti i dati di un simbolo
- (void)removeDataForSymbol:(NSString *)symbol;

// Recupera tutti i simboli
- (NSArray<NSString *> *)allSymbols;

// Recupera simboli con determinati criteri
- (NSArray<SymbolData *> *)symbolsWithPredicate:(NSPredicate *)predicate;

#pragma mark - Tags

// Aggiungi tag a un simbolo
- (void)addTag:(NSString *)tag toSymbol:(NSString *)symbol;

// Rimuovi tag da un simbolo
- (void)removeTag:(NSString *)tag fromSymbol:(NSString *)symbol;

// Recupera tutti i tags di un simbolo
- (NSArray<NSString *> *)tagsForSymbol:(NSString *)symbol;

// Recupera tutti i simboli con un determinato tag
- (NSArray<NSString *> *)symbolsWithTag:(NSString *)tag;

// Recupera tutti i tags disponibili
- (NSArray<NSString *> *)allAvailableTags;

#pragma mark - Notes

// Aggiungi/aggiorna nota per un simbolo
- (void)setNote:(NSString *)note forSymbol:(NSString *)symbol;

// Recupera nota per un simbolo
- (NSString * _Nullable)noteForSymbol:(NSString *)symbol;

// Aggiungi nota con timestamp
- (void)addTimestampedNote:(NSString *)note toSymbol:(NSString *)symbol;

// Recupera tutte le note con timestamp
- (NSArray<NoteData *> *)timestampedNotesForSymbol:(NSString *)symbol;

#pragma mark - Alerts

// Aggiungi alert
- (AlertData *)addAlertForSymbol:(NSString *)symbol
                           type:(NSString *)type
                        condition:(NSDictionary *)condition;

// Rimuovi alert
- (void)removeAlert:(AlertData *)alert;

// Recupera alerts per un simbolo
- (NSArray<AlertData *> *)alertsForSymbol:(NSString *)symbol;

// Recupera tutti gli alerts attivi
- (NSArray<AlertData *> *)allActiveAlerts;

// Aggiorna stato alert
- (void)updateAlertStatus:(AlertData *)alert triggered:(BOOL)triggered;

#pragma mark - News

// Salva news per un simbolo
- (void)saveNews:(NewsData *)news forSymbol:(NSString *)symbol;

// Recupera news salvate per un simbolo
- (NSArray<NewsData *> *)savedNewsForSymbol:(NSString *)symbol;

// Rimuovi news
- (void)removeNews:(NewsData *)news;

#pragma mark - Trading Configuration

// Imposta configurazione trading per simbolo
- (void)setTradingConfig:(TradingConfigData *)config forSymbol:(NSString *)symbol;

// Recupera configurazione trading
- (TradingConfigData * _Nullable)tradingConfigForSymbol:(NSString *)symbol;

#pragma mark - Custom Data

// Sistema flessibile per dati custom futuri
- (void)setCustomData:(id<DataPersistable>)data
              forKey:(NSString *)key
           forSymbol:(NSString *)symbol;

- (id _Nullable)customDataForKey:(NSString *)key
                      forSymbol:(NSString *)symbol
                          class:(Class)dataClass;

#pragma mark - Search

// Cerca simboli per nome o tag
- (void)searchSymbolsWithQuery:(NSString *)query
                   completion:(SymbolSearchCompletionBlock)completion;

#pragma mark - Persistence

// Salva tutti i cambiamenti
- (void)saveContext;

// Forza salvataggio su disco
- (void)forceSave;

// Esporta/importa database
- (BOOL)exportDatabaseToPath:(NSString *)path error:(NSError **)error;
- (BOOL)importDatabaseFromPath:(NSString *)path error:(NSError **)error;

#pragma mark - Notifications

// Registra per notifiche su un simbolo specifico
- (void)observeSymbol:(NSString *)symbol
             observer:(id)observer
             selector:(SEL)selector;

// Rimuovi osservatore
- (void)removeObserver:(id)observer forSymbol:(nullable NSString *)symbol;

#pragma mark - Watchlist Management

// Crea nuova watchlist
- (WatchlistDataModel *)createWatchlistWithName:(NSString *)name;

// Crea watchlist dinamica basata su tag
- (WatchlistDataModel *)createDynamicWatchlistWithName:(NSString *)name forTag:(NSString *)tag;

// Recupera tutte le watchlist
- (NSArray<WatchlistDataModel *> *)allWatchlists;

// Recupera watchlist per nome
- (WatchlistDataModel * _Nullable)watchlistWithName:(NSString *)name;

// Elimina watchlist
- (void)deleteWatchlist:(WatchlistDataModel *)watchlist;

// Aggiungi/rimuovi simbolo da watchlist
- (void)addSymbol:(NSString *)symbol toWatchlist:(WatchlistDataModel *)watchlist;
- (void)removeSymbol:(NSString *)symbol fromWatchlist:(WatchlistDataModel *)watchlist;

// Aggiorna watchlist dinamiche
- (void)updateDynamicWatchlists;

@end

NS_ASSUME_NONNULL_END
