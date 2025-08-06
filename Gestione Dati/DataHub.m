//
//  DataHub.m
//  mafia_AI
//
#import "BaseWidget.h"
#import "DataHub.h"
#import "DataHub+Private.h"
#import "Watchlist+CoreDataClass.h"
#import "Watchlist+CoreDataProperties.h"
#import "Alert+CoreDataClass.h"
#import "StockConnection+CoreDataClass.h"
#import "connectionmodel.h"
#import "DataHub+Connections.h"

// Notification constants (copiati da BaseWidget.m)
static NSString *const kWidgetChainUpdateNotification = @"WidgetChainUpdateNotification";
static NSString *const kChainColorKey = @"chainColor";
static NSString *const kChainUpdateKey = @"update";
static NSString *const kChainSenderKey = @"sender";
// Notification names
NSString *const DataHubSymbolsUpdatedNotification = @"DataHubSymbolsUpdatedNotification";
NSString *const DataHubWatchlistUpdatedNotification = @"DataHubWatchlistUpdatedNotification";
NSString *const DataHubAlertTriggeredNotification = @"DataHubAlertTriggeredNotification";
NSString *const DataHubConnectionsUpdatedNotification = @"DataHubConnectionsUpdatedNotification";
NSString *const DataHubModelsUpdatedNotification = @"DataHubModelsUpdatedNotification";
NSString *const DataHubDataLoadedNotification = @"DataHubDataLoadedNotification";

// Le proprietà sono già dichiarate in DataHub+Private.h
// Non servono ridichiarazioni qui
//@interface DataHub : NSObject
//@property (nonatomic, strong) NSMutableArray<Symbol *> *symbols;


//@end
@implementation DataHub

#pragma mark - Singleton

+ (instancetype)shared {
    static DataHub *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [sharedInstance setupCoreDataStack];
        [sharedInstance loadInitialData];
        [sharedInstance startAlertMonitoring];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Legacy properties
        _symbolDataCache = [NSMutableDictionary dictionary];
        _watchlists = [NSMutableArray array];
        _alerts = [NSMutableArray array];
        _connections = [NSMutableArray array];
        _tradingModels = [NSMutableArray array];
        _cache = [NSMutableDictionary dictionary];
        _pendingRequests = [NSMutableDictionary dictionary];
        [self setupSymbolTrackingObservers];

        // NEW: Initialize market data caches
        [self initializeMarketDataCaches];
    }
    return self;
}

- (void)initializeMarketDataCaches {
    if (!_quotesCache) {
        _quotesCache = [NSMutableDictionary dictionary];
        _historicalCache = [NSMutableDictionary dictionary];
        _companyInfoCache = [NSMutableDictionary dictionary];
        _cacheTimestamps = [NSMutableDictionary dictionary];
        _activeQuoteRequests = [NSMutableSet set];
        _activeHistoricalRequests = [NSMutableSet set];
        _subscribedSymbols = [NSMutableSet set];
        
        // NEW: Initialize market lists cache
        _marketListsCache = [NSMutableDictionary dictionary];
        _marketListsCacheTimestamps = [NSMutableDictionary dictionary];
    }
}

#pragma mark - Core Data Stack

- (void)setupCoreDataStack {
    self.persistentContainer = [[NSPersistentContainer alloc] initWithName:@"TradingDataModel"];
    
    [self.persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
        if (error != nil) {
            NSLog(@"Failed to load Core Data stack: %@", error);
            // In production, handle this error appropriately
        } else {
            self.mainContext = self.persistentContainer.viewContext;
            NSLog(@"Core Data stack loaded successfully");
        }
    }];
}

- (void)saveContext {
    NSError *error = nil;
    if ([self.mainContext hasChanges] && ![self.mainContext save:&error]) {
        NSLog(@"Failed to save context: %@", error);
        // In production, handle this error appropriately
    }
}

#pragma mark - Initial Data Loading

- (void)loadInitialData {
    [self loadWatchlists];
    [self loadAlerts];
    [self loadConnections];
    [self loadSymbols];

    // Notify that initial data is loaded
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubDataLoadedNotification
                                                        object:self];
}

#pragma mark - Symbol Data Management
- (void)updateSymbolData:(NSDictionary *)data forSymbol:(NSString *)symbol {
    if (!data || !symbol) return;
    
    // Aggiorna la cache in memoria
    [self.symbolDataCache setObject:data forKey:symbol];
    
    // Notifica gli osservatori
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubSymbolsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"symbol": symbol, @"data": data}];
}



- (NSDictionary *)getDataForSymbol:(NSString *)symbol {
    if (!symbol) return nil;
    
    @synchronized(self.symbolDataCache) {
        return self.symbolDataCache[symbol];
    }
}

- (void)removeDataForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    @synchronized(self.symbolDataCache) {
        [self.symbolDataCache removeObjectForKey:symbol];
    }
}

#pragma mark - Watchlist Management

#pragma mark - Watchlist Management (RuntimeModels for UI)

- (NSArray<WatchlistModel *> *)getAllWatchlistModels {
    NSArray<Watchlist *> *coreDataWatchlists = [self getAllWatchlists];
    NSMutableArray<WatchlistModel *> *runtimeModels = [NSMutableArray array];
    
    for (Watchlist *coreDataWatchlist in coreDataWatchlists) {
        WatchlistModel *runtimeModel = [self convertWatchlistCoreDataToRuntimeModel:coreDataWatchlist]; // ✅ NOME SPECIFICO
        if (runtimeModel) {
            [runtimeModels addObject:runtimeModel];
        }
    }
    
    return [runtimeModels copy];
}

- (WatchlistModel *)createWatchlistModelWithName:(NSString *)name {
    // Create in Core Data first
    Watchlist *coreDataWatchlist = [self createWatchlistWithName:name];
    
    // Convert to RuntimeModel for UI
    return [self convertCoreDataToRuntimeModel:coreDataWatchlist];
}

- (void)deleteWatchlistModel:(WatchlistModel *)watchlistModel {
    if (!watchlistModel || !watchlistModel.name) return;
    
    // Find the corresponding Core Data object
    Watchlist *coreDataWatchlist = [self findWatchlistByName:watchlistModel.name];
    if (coreDataWatchlist) {
        [self deleteWatchlist:coreDataWatchlist];
    }
}

- (void)addSymbol:(NSString *)symbol toWatchlistModel:(WatchlistModel *)watchlistModel {
    if (!watchlistModel || !watchlistModel.name || !symbol) return;
    
    // Find the corresponding Core Data object
    Watchlist *coreDataWatchlist = [self findWatchlistByName:watchlistModel.name];
    if (coreDataWatchlist) {
        [self addSymbol:symbol toWatchlist:coreDataWatchlist];
        
        // Update the RuntimeModel
        NSMutableArray *symbols = [watchlistModel.symbols mutableCopy] ?: [NSMutableArray array];
        NSString *upperSymbol = symbol.uppercaseString;
        if (![symbols containsObject:upperSymbol]) {
            [symbols addObject:upperSymbol];
            watchlistModel.symbols = symbols;
            watchlistModel.lastModified = [NSDate date];
        }
    }
}

- (void)removeSymbol:(NSString *)symbol fromWatchlistModel:(WatchlistModel *)watchlistModel {
    if (!watchlistModel || !watchlistModel.name || !symbol) return;
    
    // Find the corresponding Core Data object
    Watchlist *coreDataWatchlist = [self findWatchlistByName:watchlistModel.name];
    if (coreDataWatchlist) {
        [self removeSymbol:symbol fromWatchlist:coreDataWatchlist];
        
        // Update the RuntimeModel
        NSMutableArray *symbols = [watchlistModel.symbols mutableCopy];
        NSString *upperSymbol = symbol.uppercaseString;
        [symbols removeObject:upperSymbol];
        watchlistModel.symbols = symbols;
        watchlistModel.lastModified = [NSDate date];
    }
}

- (NSArray<NSString *> *)getSymbolsForWatchlistModel:(WatchlistModel *)watchlistModel {
    return watchlistModel.symbols ?: @[];
}

- (void)updateWatchlistModel:(WatchlistModel *)watchlistModel newName:(NSString *)newName {
    if (!watchlistModel || !watchlistModel.name || !newName) return;
    
    // Find the corresponding Core Data object
    Watchlist *coreDataWatchlist = [self findWatchlistByName:watchlistModel.name];
    if (coreDataWatchlist) {
        [self updateWatchlistName:coreDataWatchlist newName:newName];
        
        // Update the RuntimeModel
        watchlistModel.name = newName;
        watchlistModel.lastModified = [NSDate date];
    }
}

#pragma mark - Helper Methods

- (Watchlist *)findWatchlistByName:(NSString *)name {
    for (Watchlist *watchlist in self.watchlists) {
        if ([watchlist.name isEqualToString:name]) {
            return watchlist;
        }
    }
    return nil;
}
- (void)loadWatchlists {
    NSFetchRequest *request = [Watchlist fetchRequest];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES]];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error loading watchlists: %@", error);
    } else {
        [self.watchlists setArray:results];
    }
}

- (NSArray<Watchlist *> *)getAllWatchlists {
    return [self.watchlists copy];
}

- (Watchlist *)createWatchlistWithName:(NSString *)name {
    Watchlist *watchlist = [NSEntityDescription insertNewObjectForEntityForName:@"Watchlist"
                                                         inManagedObjectContext:self.mainContext];
    watchlist.name = name;
    watchlist.creationDate = [NSDate date];
    watchlist.lastModified = [NSDate date];
    watchlist.symbols = @[];
    watchlist.sortOrder = self.watchlists.count;
    
    [self.watchlists addObject:watchlist];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"created", @"watchlist": watchlist}];
    
    return watchlist;
}

- (void)deleteWatchlist:(Watchlist *)watchlist {
    [self.watchlists removeObject:watchlist];
    [self.mainContext deleteObject:watchlist];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"deleted"}];
}

- (void)addSymbol:(NSString *)symbol toWatchlist:(Watchlist *)watchlist {
    NSMutableArray *symbols = [watchlist.symbols mutableCopy] ?: [NSMutableArray array];
    if (![symbols containsObject:symbol]) {
        [symbols addObject:symbol];
        watchlist.symbols = symbols;
        watchlist.lastModified = [NSDate date];
        [self saveContext];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                            object:self
                                                          userInfo:@{@"action": @"symbolAdded", @"watchlist": watchlist, @"symbol": symbol}];
    }
}

- (void)removeSymbol:(NSString *)symbol fromWatchlist:(Watchlist *)watchlist {
    NSMutableArray *symbols = [watchlist.symbols mutableCopy];
    [symbols removeObject:symbol];
    watchlist.symbols = symbols;
    watchlist.lastModified = [NSDate date];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"symbolRemoved", @"watchlist": watchlist, @"symbol": symbol}];
}

- (NSArray<NSString *> *)getSymbolsForWatchlist:(Watchlist *)watchlist {
    return watchlist.symbols ?: @[];
}

- (void)updateWatchlistName:(Watchlist *)watchlist newName:(NSString *)newName {
    watchlist.name = newName;
    watchlist.lastModified = [NSDate date];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"updated", @"watchlist": watchlist}];
}

#pragma mark - Alert Management

- (void)loadAlerts {
    NSFetchRequest *request = [Alert fetchRequest];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error loading alerts: %@", error);
    } else {
        [self.alerts setArray:results];
    }
}

- (void)startAlertMonitoring {
    // Check alerts every 5 seconds
    self.alertCheckTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                            target:self
                                                          selector:@selector(checkAlerts)
                                                          userInfo:nil
                                                           repeats:YES];
}



- (NSArray<Alert *> *)getAlertsForSymbol:(NSString *)symbol {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    return [self.alerts filteredArrayUsingPredicate:predicate];
}

- (Alert *)createAlertForSymbol:(NSString *)symbol
                      condition:(NSString *)condition
                          value:(double)value
                         active:(BOOL)active {
    
    Alert *alert = [NSEntityDescription insertNewObjectForEntityForName:@"Alert"
                                                  inManagedObjectContext:self.mainContext];
    alert.symbol = symbol;
    alert.conditionString = condition;
    alert.triggerValue = value;
    alert.isActive = active;
    alert.isTriggered = NO;
    alert.creationDate = [NSDate date];
    alert.notificationEnabled = YES;
    
    [self.alerts addObject:alert];
    [self saveContext];
    
    return alert;
}

- (void)updateAlert:(Alert *)alert {
    [self saveContext];
}

- (void)checkAlerts {
    for (Alert *alert in self.getActiveAlerts) {
        [self checkAlert:alert];
    }
}

- (void)checkAlertsForSymbol:(NSString *)symbol {
    NSArray *symbolAlerts = [self getAlertsForSymbol:symbol];
    for (Alert *alert in symbolAlerts) {
        if (alert.isActive) {
            [self checkAlert:alert];
        }
    }
}

- (void)checkAlert:(Alert *)alert {
    NSDictionary *symbolData = [self getDataForSymbol:alert.symbol];
    if (!symbolData) return;
    
    double currentPrice = [symbolData[@"price"] doubleValue];
    BOOL shouldTrigger = NO;
    
    if ([alert.conditionString isEqualToString:@"above"]) {
        shouldTrigger = currentPrice > alert.triggerValue;
    } else if ([alert.conditionString isEqualToString:@"below"]) {
        shouldTrigger = currentPrice < alert.triggerValue;
    }
    
    if (shouldTrigger && !alert.isTriggered) {
        [self triggerAlert:alert];
    }
}

- (void)triggerAlert:(Alert *)alert {
    alert.isTriggered = YES;
    alert.triggerDate = [NSDate date];
    alert.isActive = NO;
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubAlertTriggeredNotification
                                                        object:self
                                                      userInfo:@{@"alert": alert}];
    
    // Show notification if enabled
    if (alert.notificationEnabled) {
        [self showNotificationForAlert:alert];
    }
}

- (void)showNotificationForAlert:(Alert *)alert {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Price Alert Triggered";
    notification.informativeText = [NSString stringWithFormat:@"%@ %@ %.2f",
                                    alert.symbol, alert.conditionString, alert.triggerValue];
    notification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark - Connection Management

- (void)loadConnections {
    NSFetchRequest *request = [StockConnection fetchRequest];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error loading connections: %@", error);
    } else {
        [self.connections setArray:results];
    }
}

- (NSArray<StockConnection *> *)getAllConnections {
    return [self.connections copy];
}

- (NSArray<StockConnection *> *)getConnectionsForSymbol:(NSString *)symbol {
    NSMutableArray *relevantConnections = [NSMutableArray array];
    
    for (StockConnection *connection in self.connections) {
        if ([connection.symbols containsObject:symbol]) {
            [relevantConnections addObject:connection];
        }
    }
    
    return relevantConnections;
}

- (StockConnection *)createConnectionWithSymbols:(NSArray<NSString *> *)symbols
                                             type:(ConnectionType)type
                                      description:(NSString *)description
                                           source:(NSString *)source
                                              url:(NSString *)url {
    
    StockConnection *connection = [NSEntityDescription insertNewObjectForEntityForName:@"StockConnection"
                                                                inManagedObjectContext:self.mainContext];
    connection.symbols = symbols;
    connection.connectionType = type;
    connection.connectionDescription = description;
    connection.source = source;
    connection.url = url;
    connection.creationDate = [NSDate date];
    
    [self.connections addObject:connection];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"created", @"connection": connection}];
    
    return connection;
}

- (void)deleteConnection:(StockConnection *)connection {
    [self.connections removeObject:connection];
    [self.mainContext deleteObject:connection];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"deleted"}];
}

#pragma mark - Trading Models Management

- (NSArray<TradingModel *> *)getAllTradingModels {
    return [self.tradingModels copy];
}

- (NSArray<TradingModel *> *)getActiveModels {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %d", ModelStatusActive];
    return [self.tradingModels filteredArrayUsingPredicate:predicate];
}

- (NSArray<TradingModel *> *)getModelsForSymbol:(NSString *)symbol {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    return [self.tradingModels filteredArrayUsingPredicate:predicate];
}

- (TradingModel *)createTradingModelWithSymbol:(NSString *)symbol
                                           type:(ModelType)type
                                           name:(NSString *)name
                                     parameters:(NSDictionary *)parameters {
    
    TradingModel *model = [NSEntityDescription insertNewObjectForEntityForName:@"TradingModel"
                                                        inManagedObjectContext:self.mainContext];
    model.symbol = symbol;
    model.modelType = type;
    model.status = ModelStatusPending;
    model.setupDate = [NSDate date];
    // name e parameters non esistono nel model, li salviamo in notes come JSON
    if (name || parameters) {
        NSMutableDictionary *extraData = [NSMutableDictionary dictionary];
        if (name) extraData[@"name"] = name;
        if (parameters) extraData[@"parameters"] = parameters;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extraData options:0 error:nil];
        model.notes = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    [self.tradingModels addObject:model];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubModelsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"created", @"model": model}];
    
    return model;
}

- (void)updateModel:(TradingModel *)model {
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubModelsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"updated", @"model": model}];
}

- (void)deleteModel:(TradingModel *)model {
    [self.tradingModels removeObject:model];
    [self.mainContext deleteObject:model];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubModelsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"deleted"}];
}

#pragma mark - Debug

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"DataHub: %lu watchlists, %lu alerts, %lu connections, %lu models, %lu cached symbols",
            (unsigned long)self.watchlists.count,
            (unsigned long)self.alerts.count,
            (unsigned long)self.connections.count,
            (unsigned long)self.tradingModels.count,
            (unsigned long)self.symbolDataCache.count];
}

- (void)printDataHubStatus {
    NSLog(@"=== DataHub Status ===");
    NSLog(@"Watchlists: %lu", (unsigned long)self.watchlists.count);
    for (Watchlist *watchlist in self.watchlists) {
        NSLog(@"  - %@: %lu symbols", watchlist.name, (unsigned long)watchlist.symbols.count);
    }
    
    NSLog(@"Active Alerts: %lu", (unsigned long)self.getActiveAlerts.count);
    NSLog(@"Total Connections: %lu", (unsigned long)self.connections.count);
    NSLog(@"Active Trading Models: %lu", (unsigned long)self.getActiveModels.count);
    NSLog(@"Cached Symbols: %lu", (unsigned long)self.symbolDataCache.count);
    NSLog(@"Core Data Persistent Store: %@",
          self.persistentContainer.persistentStoreDescriptions.firstObject.URL.lastPathComponent ?:
          @"Not loaded");
}





#pragma mark - Alert Management (RuntimeModels for UI)

- (NSArray<AlertModel *> *)getAllAlertModels {
    NSArray<Alert *> *coreDataAlerts = [self getAllAlerts];
    NSMutableArray<AlertModel *> *runtimeModels = [NSMutableArray array];
    
    for (Alert *coreDataAlert in coreDataAlerts) {
        AlertModel *runtimeModel = [self convertCoreDataToRuntimeModel:coreDataAlert];
        if (runtimeModel) {
            [runtimeModels addObject:runtimeModel];
        }
    }
    
    return [runtimeModels copy];
}

- (AlertModel *)createAlertModelWithSymbol:(NSString *)symbol
                              triggerValue:(double)triggerValue
                           conditionString:(NSString *)conditionString
                      notificationEnabled:(BOOL)notificationEnabled
                                     notes:(NSString *)notes {
    // Create in Core Data first
    Alert *coreDataAlert = [self createAlertWithSymbol:symbol
                                           triggerValue:triggerValue
                                        conditionString:conditionString
                                   notificationEnabled:notificationEnabled
                                                  notes:notes];
    
    // Convert to RuntimeModel for UI
    return [self convertCoreDataToRuntimeModel:coreDataAlert];
}

- (void)deleteAlertModel:(AlertModel *)alertModel {
    if (!alertModel || !alertModel.symbol) return;
    
    // Find the corresponding Core Data object
    Alert *coreDataAlert = [self findAlertBySymbolAndValue:alertModel.symbol
                                               triggerValue:alertModel.triggerValue
                                            conditionString:alertModel.conditionString];
    if (coreDataAlert) {
        [self deleteAlert:coreDataAlert];
    }
}

- (void)updateAlertModel:(AlertModel *)alertModel {
    if (!alertModel || !alertModel.symbol) return;
    
    // Find the corresponding Core Data object
    Alert *coreDataAlert = [self findAlertBySymbolAndValue:alertModel.symbol
                                               triggerValue:alertModel.triggerValue
                                            conditionString:alertModel.conditionString];
    if (coreDataAlert) {
        [self updateCoreDataFromRuntimeModel:coreDataAlert withModel:alertModel];
        [self saveContext];
        
        // Notify UI
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubAlertTriggeredNotification
                                                            object:self
                                                          userInfo:@{@"alert": alertModel}];
    }
}

#pragma mark - Alert Core Data Operations (Private)

- (NSArray<Alert *> *)getAllAlerts {
    NSFetchRequest *request = [Alert fetchRequest];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    NSError *error;
    NSArray *alerts = [self.mainContext executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Error fetching alerts: %@", error);
        return @[];
    }
    
    return alerts ?: @[];
}

- (Alert *)createAlertWithSymbol:(NSString *)symbol
                    triggerValue:(double)triggerValue
                 conditionString:(NSString *)conditionString
            notificationEnabled:(BOOL)notificationEnabled
                           notes:(NSString *)notes {
    
    Alert *alert = [NSEntityDescription insertNewObjectForEntityForName:@"Alert"
                                                 inManagedObjectContext:self.mainContext];
    alert.symbol = symbol.uppercaseString;
    alert.triggerValue = triggerValue;
    alert.conditionString = conditionString;
    alert.isActive = YES;
    alert.isTriggered = NO;
    alert.notificationEnabled = notificationEnabled;
    alert.notes = notes;
    alert.creationDate = [NSDate date];
    
    [self saveContext];
    return alert;
}

- (void)deleteAlert:(Alert *)alert {
    [self.mainContext deleteObject:alert];
    [self saveContext];
}

- (Alert *)findAlertBySymbolAndValue:(NSString *)symbol
                        triggerValue:(double)triggerValue
                     conditionString:(NSString *)conditionString {
    NSFetchRequest *request = [Alert fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@ AND triggerValue == %f AND conditionString == %@",
                        symbol.uppercaseString, triggerValue, conditionString];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Error finding alert: %@", error);
        return nil;
    }
    
    return results.firstObject;
}

#pragma mark - Alert Conversion Methods (Private)
- (WatchlistModel *)convertWatchlistCoreDataToRuntimeModel:(Watchlist *)coreDataWatchlist {
    if (!coreDataWatchlist) return nil;
    
    WatchlistModel *model = [[WatchlistModel alloc] init];
    
    // Basic properties
    model.name = coreDataWatchlist.name;
    model.creationDate = coreDataWatchlist.creationDate ?: [NSDate date];
    model.lastModified = coreDataWatchlist.lastModified ?: [NSDate date];
    model.symbols = coreDataWatchlist.symbols ?: @[];
    model.sortOrder = coreDataWatchlist.sortOrder;
    
    return model;
}

- (AlertModel *)convertCoreDataToRuntimeModel:(Alert *)coreDataAlert {
    if (!coreDataAlert) return nil;
    
    AlertModel *model = [[AlertModel alloc] init];
    model.symbol = coreDataAlert.symbol;
    model.triggerValue = coreDataAlert.triggerValue;
    model.conditionString = coreDataAlert.conditionString;
    model.isActive = coreDataAlert.isActive;
    model.isTriggered = coreDataAlert.isTriggered;
    model.notificationEnabled = coreDataAlert.notificationEnabled;
    model.notes = coreDataAlert.notes;
    model.creationDate = coreDataAlert.creationDate;
    model.triggerDate = coreDataAlert.triggerDate;
    
    return model;
}

- (void)updateCoreDataFromRuntimeModel:(Alert *)coreDataAlert withModel:(AlertModel *)runtimeModel {
    if (!coreDataAlert || !runtimeModel) return;
    
    coreDataAlert.symbol = runtimeModel.symbol;
    coreDataAlert.triggerValue = runtimeModel.triggerValue;
    coreDataAlert.conditionString = runtimeModel.conditionString;
    coreDataAlert.isActive = runtimeModel.isActive;
    coreDataAlert.isTriggered = runtimeModel.isTriggered;
    coreDataAlert.notificationEnabled = runtimeModel.notificationEnabled;
    coreDataAlert.notes = runtimeModel.notes;
    coreDataAlert.triggerDate = runtimeModel.triggerDate;
}

#pragma mark - Alert Monitoring

- (void)checkAlertsWithCurrentPrices:(NSDictionary<NSString *, NSNumber *> *)currentPrices {
    NSArray<AlertModel *> *activeAlerts = [self getActiveAlerts];
    
    for (AlertModel *alert in activeAlerts) {
        NSNumber *currentPriceNumber = currentPrices[alert.symbol];
        if (currentPriceNumber) {
            double currentPrice = currentPriceNumber.doubleValue;
            
            // Get previous price for crosses detection
            double previousPrice = [self getPreviousPriceForSymbol:alert.symbol];
            
            if ([alert shouldTriggerWithCurrentPrice:currentPrice previousPrice:previousPrice]) {
                [self triggerAlertModel:alert];
            }
        }
    }
}

- (NSArray<AlertModel *> *)getActiveAlerts {
    NSArray<AlertModel *> *allAlerts = [self getAllAlertModels];
    NSPredicate *activePredicate = [NSPredicate predicateWithFormat:@"isActive == YES AND isTriggered == NO"];
    return [allAlerts filteredArrayUsingPredicate:activePredicate];
}

- (void)triggerAlertModel:(AlertModel *)alert {
    alert.isTriggered = YES;
    alert.triggerDate = [NSDate date];
    [self updateAlertModel:alert];
    
    if (alert.notificationEnabled) {
        [self showNotificationForAlertModel:alert];
    }
}

- (void)showNotificationForAlertModel:(AlertModel *)alert {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Price Alert";
    notification.informativeText = [NSString stringWithFormat:@"%@ has %@ %@",
                                   alert.symbol,
                                   alert.conditionString,
                                   [alert formattedTriggerValue]];
    notification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (double)getPreviousPriceForSymbol:(NSString *)symbol {
    // Implement this based on your price history storage
    // For now, return current price (no crosses detection)
    MarketQuoteModel *quote = [self getDataForSymbol:symbol];
    return quote ? quote.last.doubleValue : 0.0;
}

// ====== AGGIUNGI QUESTI METODI A DataHub.m ======

#pragma mark - Symbol Management

- (void)loadSymbols {
    NSFetchRequest *request = [Symbol fetchRequest];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"interactionCount" ascending:NO],
                               [NSSortDescriptor sortDescriptorWithKey:@"symbol" ascending:YES]];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error loading symbols: %@", error);
        self.symbols = [NSMutableArray array];
    } else {
        self.symbols = [results mutableCopy];
        NSLog(@"DataHub: Loaded %lu symbols", (unsigned long)self.symbols.count);
    }
}

- (NSArray<Symbol *> *)getAllSymbols {
    return [self.symbols copy];
}

- (Symbol *)createSymbolWithName:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) return nil;
    
    // RICORDA: Normalizzazione UPPERCASE!
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // Check se esiste già
    Symbol *existingSymbol = [self getSymbolWithName:normalizedSymbol];
    if (existingSymbol) {
        // Incrementa interazione e ritorna esistente
        [self incrementInteractionForSymbol:existingSymbol];
        return existingSymbol;
    }
    
    // Crea nuovo
    Symbol *symbol = [NSEntityDescription insertNewObjectForEntityForName:@"Symbol"
                                                   inManagedObjectContext:self.mainContext];
    symbol.symbol = normalizedSymbol;
    symbol.creationDate = [NSDate date];
    symbol.firstInteraction = [NSDate date];
    symbol.lastInteraction = [NSDate date];
    symbol.interactionCount = 1;
    symbol.isFavorite = NO;
    symbol.tags = @[];
    
    [self.symbols addObject:symbol];
    [self saveContext];
    
    NSLog(@"DataHub: Created new symbol: %@", normalizedSymbol);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubSymbolCreated"
                                                        object:self
                                                      userInfo:@{@"symbol": symbol}];
    
    return symbol;
}

- (Symbol *)getSymbolWithName:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) return nil;
    
    // RICORDA: Normalizzazione UPPERCASE!
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    for (Symbol *symbol in self.symbols) {
        if ([symbol.symbol isEqualToString:normalizedSymbol]) {
            return symbol;
        }
    }
    return nil;
}

- (void)deleteSymbol:(Symbol *)symbol {
    if (!symbol) return;
    
    [self.symbols removeObject:symbol];
    [self.mainContext deleteObject:symbol];
    [self saveContext];
    
    NSLog(@"DataHub: Deleted symbol: %@", symbol.symbol);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubSymbolDeleted"
                                                        object:self
                                                      userInfo:@{@"symbolName": symbol.symbol}];
}

- (void)incrementInteractionForSymbol:(Symbol *)symbol {
    if (!symbol) return;
    
    symbol.interactionCount++;
    symbol.lastInteraction = [NSDate date];
    
    // Se è la prima volta, imposta firstInteraction
    if (!symbol.firstInteraction) {
        symbol.firstInteraction = [NSDate date];
    }
    
    [self saveContext];
    
    NSLog(@"DataHub: Symbol %@ interaction count: %d", symbol.symbol, symbol.interactionCount);
}

- (void)incrementInteractionForSymbolName:(NSString *)symbolName {
    // Convenience method - crea symbol se non esiste
    Symbol *symbol = [self createSymbolWithName:symbolName];
    // createSymbolWithName già incrementa se esiste, quindi non serve altro
}

#pragma mark - Symbol Tag Management

- (void)addTag:(NSString *)tag toSymbol:(Symbol *)symbol {
    if (!tag || !symbol) return;
    
    NSMutableArray *currentTags = [symbol.tags mutableCopy] ?: [NSMutableArray array];
    
    // Normalizza tag (lowercase per consistency)
    NSString *normalizedTag = tag.lowercaseString;
    
    if (![currentTags containsObject:normalizedTag]) {
        [currentTags addObject:normalizedTag];
        symbol.tags = [currentTags copy];
        [self saveContext];
        
        NSLog(@"DataHub: Added tag '%@' to symbol %@", normalizedTag, symbol.symbol);
    }
}

- (void)removeTag:(NSString *)tag fromSymbol:(Symbol *)symbol {
    if (!tag || !symbol) return;
    
    NSMutableArray *currentTags = [symbol.tags mutableCopy];
    NSString *normalizedTag = tag.lowercaseString;
    
    [currentTags removeObject:normalizedTag];
    symbol.tags = [currentTags copy];
    [self saveContext];
    
    NSLog(@"DataHub: Removed tag '%@' from symbol %@", normalizedTag, symbol.symbol);
}

- (NSArray<NSString *> *)getAllTags {
    NSMutableSet<NSString *> *allTags = [NSMutableSet set];
    
    for (Symbol *symbol in self.symbols) {
        if (symbol.tags) {
            [allTags addObjectsFromArray:symbol.tags];
        }
    }
    
    return [[allTags allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<Symbol *> *)getSymbolsWithTag:(NSString *)tag {
    if (!tag) return @[];
    
    NSString *normalizedTag = tag.lowercaseString;
    NSMutableArray<Symbol *> *matchingSymbols = [NSMutableArray array];
    
    for (Symbol *symbol in self.symbols) {
        if ([symbol.tags containsObject:normalizedTag]) {
            [matchingSymbols addObject:symbol];
        }
    }
    
    return [matchingSymbols copy];
}
// ====== AGGIUNGI A DataHub.m - Setup Symbol Tracking ======

#pragma mark - Symbol Tracking Setup

- (void)setupSymbolTrackingObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // Chain system notifications (già con array di simboli)
    [center addObserver:self
               selector:@selector(trackSymbolsFromChainNotification:)
                   name:kWidgetChainUpdateNotification
                 object:nil];
    
    // DataHub internal notifications (singolo simbolo)
    [center addObserver:self
               selector:@selector(trackSymbolFromDataHubNotification:)
                   name:DataHubWatchlistUpdatedNotification
                 object:nil];
    
    // Connection notifications (se esistono)
    [center addObserver:self
               selector:@selector(trackSymbolFromDataHubNotification:)
                   name:DataHubConnectionsUpdatedNotification
                 object:nil];
  
    NSLog(@"DataHub: Symbol tracking observers registered");
}

#pragma mark - Symbol Tracking Handlers

- (void)trackSymbolsFromChainNotification:(NSNotification *)notification {
    // Chain notifications hanno già formato standardizzato
    NSDictionary *update = notification.userInfo[kChainUpdateKey];
    
    if (!update) return;
    
    NSString *action = update[@"action"];
    NSArray *symbols = update[@"symbols"];
    
    if ([action isEqualToString:@"setSymbols"] && symbols.count > 0) {
        [self trackSymbolInteractions:symbols context:@"chain_broadcast"];
    }
}

- (void)trackSymbolFromDataHubNotification:(NSNotification *)notification {
    // DataHub notifications con formato misto
    NSString *notificationName = notification.name;
    NSDictionary *userInfo = notification.userInfo;
    
    NSArray *symbolsToTrack = [self extractSymbolsFromNotification:userInfo
                                                   notificationName:notificationName];
    
    if (symbolsToTrack.count > 0) {
        NSString *context = [self contextFromNotificationName:notificationName
                                                        action:userInfo[@"action"]];
        [self trackSymbolInteractions:symbolsToTrack context:context];
    }
}

- (NSArray<NSString *> *)extractSymbolsFromNotification:(NSDictionary *)userInfo
                                        notificationName:(NSString *)notificationName {
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    
    // Estrai simboli da diversi formati
    
    // 1. Array di simboli (formato chain)
    if (userInfo[@"symbols"]) {
        [symbols addObjectsFromArray:userInfo[@"symbols"]];
    }
    
    // 2. Simbolo singolo (formato DataHub)
    if (userInfo[@"symbol"]) {
        [symbols addObject:userInfo[@"symbol"]];
    }
    
    // 3. Simboli da Connection (COMMENTATO per ora - implementa quando hai ConnectionModel)
    /*
    if ([notificationName isEqualToString:DataHubConnectionsUpdatedNotification]) {
        NSString *connectionID = userInfo[@"connectionID"];
        if (connectionID) {
            // TODO: Implementa quando hai ConnectionModel disponibile
            // ConnectionModel *connection = [self getConnectionWithID:connectionID];
            // if (connection && connection.symbols) {
            //     [symbols addObjectsFromArray:connection.symbols];
            // }
        }
    }
    */
    
    // 4. Simboli da Watchlist
    if ([notificationName isEqualToString:DataHubWatchlistUpdatedNotification]) {
        Watchlist *watchlist = userInfo[@"watchlist"];
        if (watchlist && watchlist.symbols) {
            [symbols addObjectsFromArray:watchlist.symbols];
        }
    }
    
    return [symbols copy];
}

- (NSString *)contextFromNotificationName:(NSString *)notificationName action:(NSString *)action {
    // Mappa notification → context per tracking
    
    if ([notificationName isEqualToString:DataHubWatchlistUpdatedNotification]) {
        if ([action isEqualToString:@"symbolAdded"]) return @"watchlist_add";
        if ([action isEqualToString:@"symbolRemoved"]) return @"watchlist_remove";
        if ([action isEqualToString:@"created"]) return @"watchlist_create";
        return @"watchlist_update";
    }
    
    if ([notificationName isEqualToString:DataHubConnectionsUpdatedNotification]) {
        if ([action isEqualToString:@"created"]) return @"connection_create";
        if ([action isEqualToString:@"deleted"]) return @"connection_delete";
        return @"connection_update";
    }
    
    return @"unknown";
}

- (void)trackSymbolInteractions:(NSArray<NSString *> *)symbols context:(NSString *)context {
    if (symbols.count == 0) return;
    
    NSLog(@"DataHub: Tracking %lu symbol interactions (context: %@): %@",
          (unsigned long)symbols.count, context, symbols);
    
    for (NSString *symbolName in symbols) {
        if (symbolName.length > 0) {
            // Questo metodo crea il simbolo se non esiste e incrementa counter
            [self incrementInteractionForSymbolName:symbolName];
        }
    }
    
    // Opzionale: Post notification che il tracking è avvenuto
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubSymbolsTracked"
                                                        object:self
                                                      userInfo:@{
                                                          @"symbols": symbols,
                                                          @"context": context,
                                                          @"count": @(symbols.count)
                                                      }];
}

#pragma mark - Public Symbol Tracking API

- (void)trackExplicitSymbolInteraction:(NSString *)symbolName context:(NSString *)context {
    // Metodo pubblico per tracking esplicito da widget/UI
    if (symbolName.length == 0) return;
    
    [self trackSymbolInteractions:@[symbolName] context:context];
}

- (void)trackExplicitSymbolInteractions:(NSArray<NSString *> *)symbols context:(NSString *)context {
    // Metodo pubblico per tracking esplicito di array simboli
    [self trackSymbolInteractions:symbols context:context];
}


- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
