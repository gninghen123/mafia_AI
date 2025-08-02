//
//  DataHub.h
//  mafia_AI
//
//  Hub centrale per la gestione di tutti i dati dell'applicazione
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "RuntimeModels.h"
#import "TradingModel+CoreDataClass.h"
#import "Symbol+CoreDataClass.h"
#import "Symbol+CoreDataProperties.h"


// Forward declarations
@class StockSymbol;
@class Watchlist;
@class Alert;
@class StockConnection;
@class TradingModel;
@class Symbol;


// Notification names
extern NSString *const DataHubSymbolsUpdatedNotification;
extern NSString *const DataHubWatchlistUpdatedNotification;
extern NSString *const DataHubAlertTriggeredNotification;
extern NSString *const DataHubConnectionsUpdatedNotification;
extern NSString *const DataHubModelsUpdatedNotification;
extern NSString *const DataHubDataLoadedNotification;
@class AlertModel;  
// Connection types
typedef NS_ENUM(NSInteger, ConnectionType) {
    ConnectionTypePartnership,
    ConnectionTypeOwnership,
    ConnectionTypeSympathy,
    ConnectionTypeMerger,
    ConnectionTypeSupplier,
    ConnectionTypeCompetitor,
    ConnectionTypeOther
};

// Model types
typedef NS_ENUM(NSInteger, ModelType) {
    ModelTypeGapUp,
    ModelTypeMiniCatapult,
    ModelTypeBreakout,
    ModelTypePullback,
    ModelTypeReversal,
    ModelTypeCustom
};

// Model status
typedef NS_ENUM(NSInteger, ModelStatus) {
    ModelStatusPending,
    ModelStatusActive,
    ModelStatusClosed,
    ModelStatusStopped
};

@interface DataHub : NSObject
// Core Data
@property (nonatomic, strong, readonly) NSPersistentContainer *persistentContainer;
@property (nonatomic, strong, readonly) NSManagedObjectContext *mainContext;
//symbol
@property (nonatomic, strong, readwrite) NSMutableArray<Symbol *> *symbols;
// Data caches
@property (nonatomic, strong, readonly) NSMutableDictionary *symbolDataCache;
@property (nonatomic, strong, readonly) NSMutableArray *watchlists;
@property (nonatomic, strong, readonly) NSMutableArray *alerts;
@property (nonatomic, strong, readonly) NSMutableArray *connections;
@property (nonatomic, strong, readonly) NSMutableArray *tradingModels;

// Singleton
+ (instancetype)shared;

// MARK: - Core Data Stack
- (void)setupCoreDataStack;
- (void)saveContext;

// MARK: - Symbol Data Management (from existing SymbolDataHub)
- (void)updateSymbolData:(NSString *)symbol
              withPrice:(double)price
                 volume:(NSInteger)volume
                 change:(double)change
           changePercent:(double)changePercent;
- (NSDictionary *)getDataForSymbol:(NSString *)symbol;
- (NSArray<NSString *> *)getAllSymbols;
- (void)clearAllSymbolData;

// MARK: - Watchlist Management
- (NSArray<Watchlist *> *)getAllWatchlists;
- (Watchlist *)createWatchlistWithName:(NSString *)name;
- (void)deleteWatchlist:(Watchlist *)watchlist;
- (void)addSymbol:(NSString *)symbol toWatchlist:(Watchlist *)watchlist;
- (void)removeSymbol:(NSString *)symbol fromWatchlist:(Watchlist *)watchlist;
- (NSArray<NSString *> *)getSymbolsForWatchlist:(Watchlist *)watchlist;
- (void)updateWatchlistName:(Watchlist *)watchlist newName:(NSString *)newName;
- (BOOL)isSymbolFavorite:(NSString *)symbol;
- (void)setSymbol:(NSString *)symbol favorite:(BOOL)favorite;
// MARK: - Watchlist Management (RuntimeModels for UI)
- (NSArray<WatchlistModel *> *)getAllWatchlistModels;
- (WatchlistModel *)createWatchlistModelWithName:(NSString *)name;
- (void)deleteWatchlistModel:(WatchlistModel *)watchlistModel;
- (void)addSymbol:(NSString *)symbol toWatchlistModel:(WatchlistModel *)watchlistModel;
- (void)removeSymbol:(NSString *)symbol fromWatchlistModel:(WatchlistModel *)watchlistModel;
- (NSArray<NSString *> *)getSymbolsForWatchlistModel:(WatchlistModel *)watchlistModel;
- (void)updateWatchlistModel:(WatchlistModel *)watchlistModel newName:(NSString *)newName;


// MARK: - Alert Management
- (NSArray<Alert *> *)getAllAlerts;
- (NSArray<Alert *> *)getActiveAlerts;
- (NSArray<Alert *> *)getAlertsForSymbol:(NSString *)symbol;
- (Alert *)createAlertForSymbol:(NSString *)symbol
                      condition:(NSString *)condition
                          value:(double)value
                         active:(BOOL)active;
- (void)updateAlert:(Alert *)alert;
- (void)deleteAlert:(Alert *)alert;
- (void)checkAlerts; // Called periodically to check conditions
- (void)triggerAlert:(Alert *)alert;

// MARK: - Connection Management
- (NSArray<StockConnection *> *)getAllConnections;
- (NSArray<StockConnection *> *)getConnectionsForSymbol:(NSString *)symbol;
- (StockConnection *)createConnectionWithSymbols:(NSArray<NSString *> *)symbols
                                             type:(ConnectionType)type
                                      description:(NSString *)description
                                           source:(NSString *)source
                                              url:(NSString *)url;
- (void)updateConnection:(StockConnection *)connection;
- (void)deleteConnection:(StockConnection *)connection;
- (NSArray<NSString *> *)getRelatedSymbolsFor:(NSString *)symbol;
- (NSArray<StockConnection *> *)getConnectionsOfType:(ConnectionType)type;

// MARK: - Trading Model Management
- (NSArray<TradingModel *> *)getAllModels;
- (NSArray<TradingModel *> *)getActiveModels;
- (NSArray<TradingModel *> *)getModelsForSymbol:(NSString *)symbol;
- (NSArray<TradingModel *> *)getModelsOfType:(ModelType)type;
- (TradingModel *)createModelWithSymbol:(NSString *)symbol
                                   type:(ModelType)type
                              setupDate:(NSDate *)setupDate
                             entryPrice:(double)entryPrice
                            targetPrice:(double)targetPrice
                              stopPrice:(double)stopPrice;
- (void)updateModelStatus:(TradingModel *)model status:(ModelStatus)status;
- (void)updateModelOutcome:(TradingModel *)model currentPrice:(double)currentPrice;
- (void)closeModel:(TradingModel *)model atPrice:(double)exitPrice;
- (void)deleteModel:(TradingModel *)model;
- (NSDictionary *)getModelStatistics; // Performance statistics

// MARK: - Data Export/Import
- (BOOL)exportDataToPath:(NSString *)path;
- (BOOL)importDataFromPath:(NSString *)path;
- (void)backupData;
- (void)restoreFromBackup:(NSString *)backupPath;

// MARK: - Search and Filter
- (NSArray *)searchSymbols:(NSString *)query;
- (NSArray<Alert *> *)filterAlerts:(NSDictionary *)criteria;
- (NSArray<TradingModel *> *)filterModels:(NSDictionary *)criteria;


#pragma mark - Alert Management (RuntimeModels)

/**
 * Recupera tutti gli alert come RuntimeModels per l'UI
 * @return Array di AlertModel per l'interfaccia utente
 */
- (NSArray<AlertModel *> *)getAllAlertModels;

/**
 * Crea un nuovo alert
 * @param symbol Simbolo da monitorare (es. "AAPL")
 * @param triggerValue Prezzo di trigger
 * @param conditionString Condizione: "above", "below", "crosses_above", "crosses_below"
 * @param notificationEnabled Se mostrare notifiche sistema
 * @param notes Note opzionali
 * @return Il nuovo AlertModel creato
 */
- (AlertModel *)createAlertModelWithSymbol:(NSString *)symbol
                              triggerValue:(double)triggerValue
                           conditionString:(NSString *)conditionString
                      notificationEnabled:(BOOL)notificationEnabled
                                     notes:(NSString * _Nullable)notes;

/**
 * Elimina un alert
 * @param alertModel L'AlertModel da eliminare
 */
- (void)deleteAlertModel:(AlertModel *)alertModel;

/**
 * Aggiorna un alert esistente
 * @param alertModel L'AlertModel modificato da salvare
 */
- (void)updateAlertModel:(AlertModel *)alertModel;

/**
 * Controlla tutti gli alert attivi con i prezzi correnti
 * @param currentPrices Dictionary con simbolo -> prezzo corrente
 */
- (void)checkAlertsWithCurrentPrices:(NSDictionary<NSString *, NSNumber *> *)currentPrices;

// ====== AGGIUNGI QUESTE DICHIARAZIONI A DataHub.h ======

// Dopo le dichiarazioni esistenti, aggiungi questa sezione:

// MARK: - Symbol Management
- (Symbol *)createSymbolWithName:(NSString *)symbolName;
- (Symbol *)getSymbolWithName:(NSString *)symbolName;
- (void)deleteSymbol:(Symbol *)symbol;
- (void)incrementInteractionForSymbol:(Symbol *)symbol;
- (void)incrementInteractionForSymbolName:(NSString *)symbolName;

// MARK: - Symbol Tag Management
- (void)addTag:(NSString *)tag toSymbol:(Symbol *)symbol;
- (void)removeTag:(NSString *)tag fromSymbol:(Symbol *)symbol;
- (NSArray<NSString *> *)getAllTags;
- (NSArray<Symbol *> *)getSymbolsWithTag:(NSString *)tag;
// MARK: - Symbol Tracking
- (void)trackExplicitSymbolInteraction:(NSString *)symbolName context:(NSString *)context;
- (void)trackExplicitSymbolInteractions:(NSArray<NSString *> *)symbols context:(NSString *)context;
@end
