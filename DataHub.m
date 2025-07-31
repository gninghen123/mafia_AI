//
//  DataHub.m
//  mafia_AI
//

#import "DataHub.h"
#import "DataHub+Private.h"
#import "datamodels/Watchlist+CoreDataClass.h"
#import "datamodels/Watchlist+CoreDataProperties.h"
#import "Alert+CoreDataClass.h"
#import "StockConnection+CoreDataClass.h"
#import "TradingModel+CoreDataClass.h"

// Notification names
NSString *const DataHubSymbolsUpdatedNotification = @"DataHubSymbolsUpdatedNotification";
NSString *const DataHubWatchlistUpdatedNotification = @"DataHubWatchlistUpdatedNotification";
NSString *const DataHubAlertTriggeredNotification = @"DataHubAlertTriggeredNotification";
NSString *const DataHubConnectionsUpdatedNotification = @"DataHubConnectionsUpdatedNotification";
NSString *const DataHubModelsUpdatedNotification = @"DataHubModelsUpdatedNotification";
NSString *const DataHubDataLoadedNotification = @"DataHubDataLoadedNotification";

// Le proprietà sono già dichiarate in DataHub+Private.h
// Non servono ridichiarazioni qui

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
        WatchlistModel *runtimeModel = [self convertCoreDataToRuntimeModel:coreDataWatchlist];
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


@end
