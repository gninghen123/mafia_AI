//
//  DataHub.m
//  mafia_AI
//

#import "DataHub.h"
#import "Watchlist+CoreDataClass.h"
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

@interface DataHub ()
@property (nonatomic, strong, readwrite) NSPersistentContainer *persistentContainer;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *mainContext;
@property (nonatomic, strong, readwrite) NSMutableDictionary *symbolDataCache;
@property (nonatomic, strong, readwrite) NSMutableArray *watchlists;
@property (nonatomic, strong, readwrite) NSMutableArray *alerts;
@property (nonatomic, strong, readwrite) NSMutableArray *connections;
@property (nonatomic, strong, readwrite) NSMutableArray *tradingModels;
@property (nonatomic, strong) NSTimer *alertCheckTimer;
@end

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
        _symbolDataCache = [NSMutableDictionary dictionary];
        _watchlists = [NSMutableArray array];
        _alerts = [NSMutableArray array];
        _connections = [NSMutableArray array];
        _tradingModels = [NSMutableArray array];
    }
    return self;
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
    }
}

- (void)loadInitialData {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadWatchlists];
        [self loadAlerts];
        [self loadConnections];
        [self loadTradingModels];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubDataLoadedNotification object:self];
    });
}

#pragma mark - Symbol Data Management

- (void)updateSymbolData:(NSString *)symbol
              withPrice:(double)price
                 volume:(NSInteger)volume
                 change:(double)change
           changePercent:(double)changePercent {
    
    if (!symbol) return;
    
    @synchronized(self.symbolDataCache) {
        NSMutableDictionary *data = [self.symbolDataCache[symbol] mutableCopy] ?: [NSMutableDictionary dictionary];
        
        data[@"symbol"] = symbol;
        data[@"price"] = @(price);
        data[@"volume"] = @(volume);
        data[@"change"] = @(change);
        data[@"changePercent"] = @(changePercent);
        data[@"lastUpdate"] = [NSDate date];
        
        self.symbolDataCache[symbol] = data;
    }
    
    // Check alerts for this symbol
    [self checkAlertsForSymbol:symbol];
    
    // Notify observers
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubSymbolsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"symbol": symbol}];
}

- (NSDictionary *)getDataForSymbol:(NSString *)symbol {
    @synchronized(self.symbolDataCache) {
        return [self.symbolDataCache[symbol] copy];
    }
}

- (NSArray<NSString *> *)getAllSymbols {
    @synchronized(self.symbolDataCache) {
        return [self.symbolDataCache.allKeys copy];
    }
}

- (void)clearAllSymbolData {
    @synchronized(self.symbolDataCache) {
        [self.symbolDataCache removeAllObjects];
    }
}

#pragma mark - Watchlist Management

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

- (NSArray<Alert *> *)getAllAlerts {
    return [self.alerts copy];
}

- (NSArray<Alert *> *)getActiveAlerts {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isActive == YES"];
    return [self.alerts filteredArrayUsingPredicate:predicate];
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

- (void)deleteAlert:(Alert *)alert {
    [self.alerts removeObject:alert];
    [self.mainContext deleteObject:alert];
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

- (void)updateConnection:(StockConnection *)connection {
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"updated", @"connection": connection}];
}

- (void)deleteConnection:(StockConnection *)connection {
    [self.connections removeObject:connection];
    [self.mainContext deleteObject:connection];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"deleted"}];
}

- (NSArray<NSString *> *)getRelatedSymbolsFor:(NSString *)symbol {
    NSMutableSet *relatedSymbols = [NSMutableSet set];
    
    for (StockConnection *connection in [self getConnectionsForSymbol:symbol]) {
        [relatedSymbols addObjectsFromArray:connection.symbols];
    }
    
    [relatedSymbols removeObject:symbol]; // Remove the queried symbol itself
    
    return [relatedSymbols allObjects];
}

- (NSArray<StockConnection *> *)getConnectionsOfType:(ConnectionType)type {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"connectionType == %d", type];
    return [self.connections filteredArrayUsingPredicate:predicate];
}

#pragma mark - Trading Model Management

- (void)loadTradingModels {
    NSFetchRequest *request = [TradingModel fetchRequest];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"setupDate" ascending:NO]];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error loading trading models: %@", error);
    } else {
        [self.tradingModels setArray:results];
    }
}

- (NSArray<TradingModel *> *)getAllModels {
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

- (NSArray<TradingModel *> *)getModelsOfType:(ModelType)type {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"modelType == %d", type];
    return [self.tradingModels filteredArrayUsingPredicate:predicate];
}

- (TradingModel *)createModelWithSymbol:(NSString *)symbol
                                   type:(ModelType)type
                              setupDate:(NSDate *)setupDate
                             entryPrice:(double)entryPrice
                            targetPrice:(double)targetPrice
                              stopPrice:(double)stopPrice {
    
    TradingModel *model = [NSEntityDescription insertNewObjectForEntityForName:@"TradingModel"
                                                         inManagedObjectContext:self.mainContext];
    model.symbol = symbol;
    model.modelType = type;
    model.setupDate = setupDate;
    model.entryPrice = entryPrice;
    model.targetPrice = targetPrice;
    model.stopPrice = stopPrice;
    model.status = ModelStatusPending;
    model.currentOutcome = 0.0;
    
    [self.tradingModels addObject:model];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubModelsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"created", @"model": model}];
    
    return model;
}

- (void)updateModelStatus:(TradingModel *)model status:(ModelStatus)status {
    model.status = status;
    
    if (status == ModelStatusActive) {
        model.entryDate = [NSDate date];
    }
    
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubModelsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"statusChanged", @"model": model}];
}

- (void)updateModelOutcome:(TradingModel *)model currentPrice:(double)currentPrice {
    // Calculate current outcome percentage
    double outcome = ((currentPrice - model.entryPrice) / model.entryPrice) * 100.0;
    model.currentOutcome = outcome;
    
    // Check if stop or target hit
    if (currentPrice <= model.stopPrice) {
        [self closeModel:model atPrice:currentPrice];
        model.status = ModelStatusStopped;
    } else if (currentPrice >= model.targetPrice) {
        [self closeModel:model atPrice:currentPrice];
        model.status = ModelStatusClosed;
    }
    
    [self saveContext];
}

- (void)closeModel:(TradingModel *)model atPrice:(double)exitPrice {
    model.exitDate = [NSDate date];
    model.currentOutcome = ((exitPrice - model.entryPrice) / model.entryPrice) * 100.0;
    
    if (model.status != ModelStatusStopped) {
        model.status = ModelStatusClosed;
    }
    
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubModelsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"closed", @"model": model}];
}

- (void)deleteModel:(TradingModel *)model {
    [self.tradingModels removeObject:model];
    [self.mainContext deleteObject:model];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubModelsUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"deleted"}];
}

- (NSDictionary *)getModelStatistics {
    NSInteger totalModels = self.tradingModels.count;
    NSInteger activeModels = self.getActiveModels.count;
    NSInteger winnersCount = 0;
    NSInteger losersCount = 0;
    double totalGain = 0.0;
    double totalLoss = 0.0;
    
    for (TradingModel *model in self.tradingModels) {
        if (model.status == ModelStatusClosed || model.status == ModelStatusStopped) {
            if (model.currentOutcome > 0) {
                winnersCount++;
                totalGain += model.currentOutcome;
            } else if (model.currentOutcome < 0) {
                losersCount++;
                totalLoss += model.currentOutcome;
            }
        }
    }
    
    double winRate = (winnersCount + losersCount) > 0 ? (double)winnersCount / (winnersCount + losersCount) * 100 : 0;
    double avgWin = winnersCount > 0 ? totalGain / winnersCount : 0;
    double avgLoss = losersCount > 0 ? totalLoss / losersCount : 0;
    
    return @{
        @"totalModels": @(totalModels),
        @"activeModels": @(activeModels),
        @"closedModels": @(winnersCount + losersCount),
        @"winners": @(winnersCount),
        @"losers": @(losersCount),
        @"winRate": @(winRate),
        @"averageWin": @(avgWin),
        @"averageLoss": @(avgLoss),
        @"totalGain": @(totalGain),
        @"totalLoss": @(totalLoss),
        @"netResult": @(totalGain + totalLoss)
    };
}

#pragma mark - Data Export/Import

- (BOOL)exportDataToPath:(NSString *)path {
    NSMutableDictionary *exportData = [NSMutableDictionary dictionary];
    
    // Export watchlists
    NSMutableArray *watchlistData = [NSMutableArray array];
    for (Watchlist *watchlist in self.watchlists) {
        [watchlistData addObject:@{
            @"name": watchlist.name ?: @"",
            @"symbols": watchlist.symbols ?: @[],
            @"sortOrder": @(watchlist.sortOrder)
        }];
    }
    exportData[@"watchlists"] = watchlistData;
    
    // Export alerts
    NSMutableArray *alertData = [NSMutableArray array];
    for (Alert *alert in self.alerts) {
        [alertData addObject:@{
            @"symbol": alert.symbol ?: @"",
            @"condition": alert.conditionString ?: @"",
            @"triggerValue": @(alert.triggerValue),
            @"isActive": @(alert.isActive),
            @"notes": alert.notes ?: @""
        }];
    }
    exportData[@"alerts"] = alertData;
    
    // Export connections
    NSMutableArray *connectionData = [NSMutableArray array];
    for (StockConnection *connection in self.connections) {
        [connectionData addObject:@{
            @"symbols": connection.symbols ?: @[],
            @"type": @(connection.connectionType),
            @"description": connection.connectionDescription ?: @"",
            @"source": connection.source ?: @"",
            @"url": connection.url ?: @""
        }];
    }
    exportData[@"connections"] = connectionData;
    
    // Export models
    NSMutableArray *modelData = [NSMutableArray array];
    for (TradingModel *model in self.tradingModels) {
        NSMutableDictionary *modelDict = [@{
            @"symbol": model.symbol ?: @"",
            @"type": @(model.modelType),
            @"setupDate": model.setupDate ?: [NSDate date],
            @"entryPrice": @(model.entryPrice),
            @"targetPrice": @(model.targetPrice),
            @"stopPrice": @(model.stopPrice),
            @"status": @(model.status),
            @"currentOutcome": @(model.currentOutcome)
        } mutableCopy];
        
        if (model.entryDate) modelDict[@"entryDate"] = model.entryDate;
        if (model.exitDate) modelDict[@"exitDate"] = model.exitDate;
        if (model.notes) modelDict[@"notes"] = model.notes;
        
        [modelData addObject:modelDict];
    }
    exportData[@"models"] = modelData;
    
    // Save to file
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error) {
        NSLog(@"Error serializing data: %@", error);
        return NO;
    }
    
    return [jsonData writeToFile:path atomically:YES];
}

- (BOOL)importDataFromPath:(NSString *)path {
    NSError *error = nil;
    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    
    if (!jsonData) {
        NSLog(@"Failed to read file at path: %@", path);
        return NO;
    }
    
    NSDictionary *importData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if (error) {
        NSLog(@"Error parsing JSON: %@", error);
        return NO;
    }
    
    // Clear existing data
    [self clearAllData];
    
    // Import watchlists
    NSArray *watchlistData = importData[@"watchlists"];
    for (NSDictionary *dict in watchlistData) {
        Watchlist *watchlist = [self createWatchlistWithName:dict[@"name"]];
        watchlist.symbols = dict[@"symbols"];
        watchlist.sortOrder = [dict[@"sortOrder"] integerValue];
    }
    
    // Import alerts
    NSArray *alertData = importData[@"alerts"];
    for (NSDictionary *dict in alertData) {
        Alert *alert = [self createAlertForSymbol:dict[@"symbol"]
                                        condition:dict[@"condition"]
                                            value:[dict[@"triggerValue"] doubleValue]
                                           active:[dict[@"isActive"] boolValue]];
        alert.notes = dict[@"notes"];
    }
    
    // Import connections
    NSArray *connectionData = importData[@"connections"];
    for (NSDictionary *dict in connectionData) {
        [self createConnectionWithSymbols:dict[@"symbols"]
                                     type:[dict[@"type"] integerValue]
                              description:dict[@"description"]
                                   source:dict[@"source"]
                                      url:dict[@"url"]];
    }
    
    // Import models
    NSArray *modelData = importData[@"models"];
    for (NSDictionary *dict in modelData) {
        TradingModel *model = [self createModelWithSymbol:dict[@"symbol"]
                                                     type:[dict[@"type"] integerValue]
                                                setupDate:dict[@"setupDate"]
                                               entryPrice:[dict[@"entryPrice"] doubleValue]
                                              targetPrice:[dict[@"targetPrice"] doubleValue]
                                                stopPrice:[dict[@"stopPrice"] doubleValue]];
        
        model.status = [dict[@"status"] integerValue];
        model.currentOutcome = [dict[@"currentOutcome"] doubleValue];
        if (dict[@"entryDate"]) model.entryDate = dict[@"entryDate"];
        if (dict[@"exitDate"]) model.exitDate = dict[@"exitDate"];
        if (dict[@"notes"]) model.notes = dict[@"notes"];
    }
    
    [self saveContext];
    return YES;
}

- (void)backupData {
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *backupDir = [documentsPath stringByAppendingPathComponent:@"TradingBackups"];
    
    // Create backup directory if it doesn't exist
    [[NSFileManager defaultManager] createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Create backup filename with timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *backupPath = [backupDir stringByAppendingPathComponent:[NSString stringWithFormat:@"backup_%@.json", timestamp]];
    
    [self exportDataToPath:backupPath];
}

- (void)restoreFromBackup:(NSString *)backupPath {
    [self importDataFromPath:backupPath];
}

#pragma mark - Search and Filter

- (NSArray *)searchSymbols:(NSString *)query {
    NSMutableSet *results = [NSMutableSet set];
    NSString *lowercaseQuery = [query lowercaseString];
    
    // Search in watchlists
    for (Watchlist *watchlist in self.watchlists) {
        for (NSString *symbol in watchlist.symbols) {
            if ([[symbol lowercaseString] containsString:lowercaseQuery]) {
                [results addObject:symbol];
            }
        }
    }
    
    // Search in alerts
    for (Alert *alert in self.alerts) {
        if ([[alert.symbol lowercaseString] containsString:lowercaseQuery]) {
            [results addObject:alert.symbol];
        }
    }
    
    // Search in connections
    for (StockConnection *connection in self.connections) {
        for (NSString *symbol in connection.symbols) {
            if ([[symbol lowercaseString] containsString:lowercaseQuery]) {
                [results addObject:symbol];
            }
        }
    }
    
    // Search in models
    for (TradingModel *model in self.tradingModels) {
        if ([[model.symbol lowercaseString] containsString:lowercaseQuery]) {
            [results addObject:model.symbol];
        }
    }
    
    return [[results allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<Alert *> *)filterAlerts:(NSDictionary *)criteria {
    NSMutableArray *predicates = [NSMutableArray array];
    
    if (criteria[@"symbol"]) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"symbol == %@", criteria[@"symbol"]]];
    }
    
    if (criteria[@"isActive"]) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"isActive == %@", criteria[@"isActive"]]];
    }
    
    if (criteria[@"condition"]) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"conditionString == %@", criteria[@"condition"]]];
    }
    
    NSCompoundPredicate *compound = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    return [self.alerts filteredArrayUsingPredicate:compound];
}

- (NSArray<TradingModel *> *)filterModels:(NSDictionary *)criteria {
    NSMutableArray *predicates = [NSMutableArray array];
    
    if (criteria[@"symbol"]) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"symbol == %@", criteria[@"symbol"]]];
    }
    
    if (criteria[@"type"]) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"modelType == %d", [criteria[@"type"] intValue]]];
    }
    
    if (criteria[@"status"]) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"status == %d", [criteria[@"status"] intValue]]];
    }
    
    if (criteria[@"minOutcome"]) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"currentOutcome >= %f", [criteria[@"minOutcome"] doubleValue]]];
    }
    
    NSCompoundPredicate *compound = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    return [self.tradingModels filteredArrayUsingPredicate:compound];
}

#pragma mark - Helper Methods

- (void)clearAllData {
    // Remove all watchlists
    for (Watchlist *watchlist in self.watchlists) {
        [self.mainContext deleteObject:watchlist];
    }
    [self.watchlists removeAllObjects];
    
    // Remove all alerts
    for (Alert *alert in self.alerts) {
        [self.mainContext deleteObject:alert];
    }
    [self.alerts removeAllObjects];
    
    // Remove all connections
    for (StockConnection *connection in self.connections) {
        [self.mainContext deleteObject:connection];
    }
    [self.connections removeAllObjects];
    
    // Remove all models
    for (TradingModel *model in self.tradingModels) {
        [self.mainContext deleteObject:model];
    }
    [self.tradingModels removeAllObjects];
    
    [self saveContext];
}

- (void)dealloc {
    [self.alertCheckTimer invalidate];
    self.alertCheckTimer = nil;
}

@end
