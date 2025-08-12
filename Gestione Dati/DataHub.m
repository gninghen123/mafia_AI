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
#import "DataHub+SmartTracking.h"
#import "DataHub+WatchlistProviders.h"
#import <objc/runtime.h>           // per objc_setAssociatedObject


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
        
        // ✅ NEW: Initialize tracking preferences and optimized system
        [sharedInstance loadTrackingConfiguration];
        [sharedInstance initializeSmartTracking];
        [sharedInstance initializeOptimizedTracking]; // ← AGGIUNGI QUESTA RIGA
        
        NSLog(@"✅ DataHub singleton fully initialized with optimized tracking");
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



- (void)restartOptimizedTrackingWithNewConfiguration {
    NSLog(@"🔄 Restarting optimized tracking with new configuration");
    
    [self shutdownOptimizedTracking];
    [self initializeOptimizedTracking];
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
            
            // ✅ NUOVO: Setup sistema archiviazione automatica
            [self setupAutomaticArchiving];
        }
    }];
}

- (void)setupAutomaticArchiving {
    NSLog(@"🔄 Setting up automatic archiving system...");
    
    // 1. Esegui catch-up archiving all'avvio
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performCatchUpArchiving];
    });
    
    // 2. Setup timer per check giornaliero (ogni 24 ore)
    [self scheduleDailyArchiveCheck];
    
    NSLog(@"✅ Automatic archiving system configured");
}

- (void)scheduleDailyArchiveCheck {
    // Timer che verifica ogni 24 ore se ci sono nuovi giorni da archiviare
    NSTimer *dailyTimer = [NSTimer scheduledTimerWithTimeInterval:(24 * 60 * 60) // 24 ore
                                                           target:self
                                                         selector:@selector(performDailyArchiveCheck)
                                                         userInfo:nil
                                                          repeats:YES];
    
    // Mantieni riferimento per cleanup eventuale
    objc_setAssociatedObject(self, @"dailyArchiveTimer", dailyTimer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    NSLog(@"⏰ Daily archive check scheduled (every 24 hours)");
}

- (void)performDailyArchiveCheck {
    NSLog(@"⏰ Daily archive check triggered (app running continuously)");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performCatchUpArchiving];
    });
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
    return [self convertWatchlistCoreDataToRuntimeModel:coreDataWatchlist];
    
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
    if (!symbol || !watchlistModel || !watchlistModel.name) return;
    
    NSLog(@"📋 DataHub: Adding symbol %@ to watchlist %@ (CLEAN - no tracking)", symbol, watchlistModel.name);
    
    // ✅ STEP 1: Create/get symbol entity (NO automatic increment)
    Symbol *symbolEntity = [self createSymbolWithName:symbol];
    if (!symbolEntity) {
        NSLog(@"❌ Failed to create/get symbol entity: %@", symbol);
        return;
    }
    
    // ✅ STEP 2: Add to Core Data watchlist
    Watchlist *coreDataWatchlist = [self findWatchlistByName:watchlistModel.name];
    if (!coreDataWatchlist) {
        NSLog(@"❌ Watchlist not found: %@", watchlistModel.name);
        return;
    }
    
    // Check if already in watchlist
    if ([coreDataWatchlist.symbols containsObject:symbolEntity]) {
        NSLog(@"⚠️ Symbol %@ already in watchlist %@", symbol, watchlistModel.name);
        return;
    }
    
    // Add to Core Data
    [coreDataWatchlist addSymbolObject:symbolEntity];
    [self saveContext];
    
    // ✅ STEP 3: Update RuntimeModel
    NSMutableArray *symbols = [watchlistModel.symbols mutableCopy] ?: [NSMutableArray array];
    NSString *upperSymbol = symbol.uppercaseString;
    if (![symbols containsObject:upperSymbol]) {
        [symbols addObject:upperSymbol];
        watchlistModel.symbols = [symbols copy];
        watchlistModel.lastModified = [NSDate date];
    }
    
    // ✅ CLEAN: Simple notification (NO automatic tracking side effects)
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"watchlist": coreDataWatchlist,
                                                          @"action": @"symbolAdded",
                                                          @"symbol": symbol
                                                      }];
    
    NSLog(@"✅ DataHub: Added %@ to watchlist %@ (CLEAN)", symbol, watchlistModel.name);
}


- (void)addSymbols:(NSArray<NSString *> *)symbols toWatchlistModel:(WatchlistModel *)watchlistModel {
    if (!symbols || symbols.count == 0 || !watchlistModel) return;
    
    NSLog(@"📋 DataHub: Adding %lu symbols to watchlist %@ (CLEAN BULK)",
          (unsigned long)symbols.count, watchlistModel.name);
    
    Watchlist *coreDataWatchlist = [self findWatchlistByName:watchlistModel.name];
    if (!coreDataWatchlist) {
        NSLog(@"❌ Watchlist not found: %@", watchlistModel.name);
        return;
    }
    
    NSMutableArray<NSString *> *addedSymbols = [NSMutableArray array];
    
    // ✅ Process all symbols WITHOUT any tracking
    for (NSString *symbol in symbols) {
        NSString *normalizedSymbol = symbol.uppercaseString;
        
        // Create/get symbol entity (no tracking)
        Symbol *symbolEntity = [self createSymbolWithName:normalizedSymbol];
        if (!symbolEntity) continue;
        
        // Check if already in watchlist
        if ([coreDataWatchlist.symbols containsObject:symbolEntity]) {
            NSLog(@"⚠️ Symbol %@ already in watchlist, skipping", normalizedSymbol);
            continue;
        }
        
        // Add to watchlist
        [coreDataWatchlist addSymbolObject:symbolEntity];
        [addedSymbols addObject:normalizedSymbol];
    }
    
    if (addedSymbols.count == 0) {
        NSLog(@"⚠️ No new symbols added to watchlist");
        return;
    }
    
    // ✅ Save Core Data changes
    [self saveContext];
    
    // ✅ Update RuntimeModel
    NSMutableArray *existingSymbols = [watchlistModel.symbols mutableCopy] ?: [NSMutableArray array];
    for (NSString *symbol in addedSymbols) {
        if (![existingSymbols containsObject:symbol]) {
            [existingSymbols addObject:symbol];
        }
    }
    watchlistModel.symbols = [existingSymbols copy];
    watchlistModel.lastModified = [NSDate date];
    
    // ✅ CLEAN: Simple bulk notification (NO tracking side effects)
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"watchlist": coreDataWatchlist,
                                                          @"action": @"symbolsAdded",
                                                          @"symbols": addedSymbols,
                                                          @"count": @(addedSymbols.count)
                                                      }];
    
    NSLog(@"✅ DataHub: Added %lu symbols to watchlist %@ (CLEAN BULK)",
          (unsigned long)addedSymbols.count, watchlistModel.name);
}


- (void)removeSymbol:(NSString *)symbol fromWatchlistModel:(WatchlistModel *)watchlistModel {
    if (!symbol || !watchlistModel || !watchlistModel.name) return;
    
    // Find corresponding Core Data objects
    Watchlist *coreDataWatchlist = [self findWatchlistByName:watchlistModel.name];
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    
    if (!coreDataWatchlist || !symbolEntity) return;
    
    // ✅ USA RELATIONSHIP DIRETTA
    [coreDataWatchlist removeSymbolObject:symbolEntity];
    [self saveContext];
    
    // Update RuntimeModel
    NSMutableArray *symbols = [watchlistModel.symbols mutableCopy];
    NSString *upperSymbol = symbol.uppercaseString;
    if ([symbols containsObject:upperSymbol]) {
        [symbols removeObject:upperSymbol];
        watchlistModel.symbols = [symbols copy];
        watchlistModel.lastModified = [NSDate date];
    }
    
    // ✅ NOTIFICATION
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"watchlist": coreDataWatchlist,
                                                          @"action": @"symbolRemoved",
                                                          @"symbol": symbol
                                                      }];
    
    NSLog(@"✅ DataHub: Removed %@ from watchlist %@", symbol, watchlistModel.name);
}


- (NSArray<NSString *> *)getSymbolsForWatchlistModel:(WatchlistModel *)watchlistModel {
    return watchlistModel.symbols ?: @[];
}

- (void)updateWatchlistCoreDataFromRuntimeModel:(WatchlistModel *)runtimeModel
                                coreDataWatchlist:(Watchlist *)coreDataWatchlist {
    
    coreDataWatchlist.name = runtimeModel.name;
    coreDataWatchlist.lastModified = runtimeModel.lastModified ?: [NSDate date];
    coreDataWatchlist.colorHex = runtimeModel.colorHex;
    coreDataWatchlist.sortOrder = runtimeModel.sortOrder;
    
    // Update Symbol relationships
    NSManagedObjectContext *context = coreDataWatchlist.managedObjectContext;
    NSMutableSet<Symbol *> *symbolsSet = [NSMutableSet set];
    
    for (NSString *symbolName in runtimeModel.symbols) {
        Symbol *symbol = [self findOrCreateSymbolWithName:symbolName inContext:context];
        [symbolsSet addObject:symbol];
    }
    
    coreDataWatchlist.symbols = symbolsSet;
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
    if (!symbol || !watchlist) return;
    
    // ✅ USA ENTITY ESISTENTE (no tracking qui)
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    if (!symbolEntity) {
        NSLog(@"⚠️ DataHub: Symbol %@ not found for watchlist operation. Create it first.", symbol);
        return;
    }
    
    // ✅ RELATIONSHIP DIRETTA (no string methods)
    [watchlist addSymbolObject:symbolEntity];
    [self saveContext];
    
    // ✅ NOTIFICATION (per legacy compatibility)
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"watchlist": watchlist,
                                                          @"action": @"symbolAdded",
                                                          @"symbol": symbol
                                                      }];
}

- (void)removeSymbol:(NSString *)symbol fromWatchlist:(Watchlist *)watchlist {
    if (!symbol || !watchlist) return;
    
    // ✅ USA ENTITY ESISTENTE
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    if (symbolEntity) {
        [watchlist removeSymbolObject:symbolEntity];
        [self saveContext];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"watchlist": watchlist,
                                                              @"action": @"symbolRemoved",
                                                              @"symbol": symbol
                                                          }];
    }
}
- (NSArray<NSString *> *)getSymbolsForWatchlist:(Watchlist *)watchlist {
    if (!watchlist) return @[];
    
    return [watchlist symbolNames];
}

- (void)updateWatchlistName:(Watchlist *)watchlist newName:(NSString *)newName {
    watchlist.name = newName;
    watchlist.lastModified = [NSDate date];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubWatchlistUpdatedNotification
                                                        object:self
                                                      userInfo:@{@"action": @"updated", @"watchlist": watchlist}];
}


#pragma mark - DataHub Validation Methods (NEW)

- (void)validateWatchlistSymbolTracking {
    NSLog(@"\n🔍 VALIDATION: Watchlist Symbol Tracking");
    NSLog(@"==========================================");
    
    NSArray<WatchlistModel *> *watchlists = [self getAllWatchlistModels];
    NSInteger totalSymbolsInWatchlists = 0;
    NSInteger symbolsWithZeroInteractions = 0;
    
    for (WatchlistModel *watchlist in watchlists) {
        NSLog(@"📋 Watchlist: %@ (%lu symbols)", watchlist.name, (unsigned long)watchlist.symbols.count);
        
        for (NSString *symbolName in watchlist.symbols) {
            totalSymbolsInWatchlists++;
            
            Symbol *symbol = [self getSymbolWithName:symbolName];
            if (!symbol) {
                NSLog(@"   ❌ BROKEN: Symbol '%@' in watchlist but missing from database", symbolName);
            } else if (symbol.interactionCount == 0) {
                symbolsWithZeroInteractions++;
                NSLog(@"   ⚠️  WARNING: Symbol '%@' has no interactions tracked", symbolName);
            } else {
                NSLog(@"   ✅ OK: Symbol '%@' - %d interactions", symbolName, symbol.interactionCount);
            }
        }
    }
    
    NSLog(@"SUMMARY:");
    NSLog(@"- Total symbols in watchlists: %ld", (long)totalSymbolsInWatchlists);
    NSLog(@"- Symbols with zero interactions: %ld", (long)symbolsWithZeroInteractions);
    NSLog(@"- Tracking success rate: %.1f%%",
          totalSymbolsInWatchlists > 0 ?
          (100.0 * (totalSymbolsInWatchlists - symbolsWithZeroInteractions) / totalSymbolsInWatchlists) : 0.0);
    NSLog(@"==========================================\n");
}

- (void)fixWatchlistSymbolTracking {
    NSLog(@"\n🔧 FIXING: Watchlist Symbol Tracking Issues");
    NSLog(@"==========================================");
    
    NSArray<WatchlistModel *> *watchlists = [self getAllWatchlistModels];
    NSInteger fixedSymbols = 0;
    
    for (WatchlistModel *watchlist in watchlists) {
        for (NSString *symbolName in watchlist.symbols) {
            Symbol *symbol = [self getSymbolWithName:symbolName];
            
            if (!symbol) {
                // Create missing symbol
                symbol = [self createSymbolWithName:symbolName];
                fixedSymbols++;
                NSLog(@"   ✅ CREATED: Symbol '%@' with interaction tracking", symbolName);
            } else if (symbol.interactionCount == 0) {
                // Fix zero interaction count
                [self incrementInteractionForSymbol:symbol];
                fixedSymbols++;
                NSLog(@"   ✅ FIXED: Symbol '%@' interaction count updated", symbolName);
            }
        }
    }
    
    NSLog(@"FIXED: %ld symbols now have proper tracking", (long)fixedSymbols);
    NSLog(@"==========================================\n");
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
        if ([[self getSymbolsInvolvedInConnection:connection] containsObject:symbol]) {
            [relevantConnections addObject:connection];
        }
    }
    
    return relevantConnections;
}

- (StockConnection *)createConnectionWithSymbols:(NSArray<NSString *> *)symbols
                                            type:(StockConnectionType)type
                                     description:(NSString *)description
                                          source:(NSString *)source
                                             url:(NSString *)url {
    
    if (!symbols || symbols.count == 0) {
        NSLog(@"❌ createConnectionWithSymbols: No symbols provided");
        return nil;
    }
    
    // Validate symbols are strings
    for (id obj in symbols) {
        if (![obj isKindOfClass:[NSString class]] || ((NSString *)obj).length == 0) {
            NSLog(@"❌ createConnectionWithSymbols: Invalid symbol: %@", obj);
            return nil;
        }
    }
    
    StockConnection *connection = [NSEntityDescription insertNewObjectForEntityForName:@"StockConnection"
                                                                inManagedObjectContext:self.mainContext];
    
    // Set basic properties
    connection.connectionType = type;
    connection.connectionDescription = description ?: @"";
    connection.source = source ?: @"";
    connection.url = url ?: @"";
    connection.creationDate = [NSDate date];
    connection.connectionID = [[NSUUID UUID] UUIDString];
    connection.isActive = YES;
    connection.bidirectional = YES;
    
    // ✅ Create symbol entities WITHOUT automatic tracking
    if (symbols.count == 1) {
        // Single symbol - set as source only
        Symbol *symbol = [self createSymbolWithName:symbols[0]]; // Clean creation
        if (symbol) {
            connection.sourceSymbol = symbol;
        } else {
            NSLog(@"❌ Failed to create source symbol: %@", symbols[0]);
            [self.mainContext deleteObject:connection];
            return nil;
        }
    } else {
        // Multiple symbols - first as source, rest as targets
        Symbol *sourceSymbol = [self createSymbolWithName:symbols[0]]; // Clean creation
        if (!sourceSymbol) {
            NSLog(@"❌ Failed to create source symbol: %@", symbols[0]);
            [self.mainContext deleteObject:connection];
            return nil;
        }
        connection.sourceSymbol = sourceSymbol;
        
        // Add remaining symbols as targets
        NSMutableSet *targetSymbols = [NSMutableSet set];
        for (NSInteger i = 1; i < symbols.count; i++) {
            Symbol *targetSymbol = [self createSymbolWithName:symbols[i]]; // Clean creation
            if (targetSymbol) {
                [targetSymbols addObject:targetSymbol];
            } else {
                NSLog(@"❌ Failed to create target symbol: %@", symbols[i]);
            }
        }
        connection.targetSymbols = targetSymbols;
    }
    
    [self.connections addObject:connection];
    [self saveContext];
    
    // ✅ CLEAN: Simple notification (will be used later for smart tracking)
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"action": @"created",
                                                          @"connection": connection
                                                      }];
    
    NSLog(@"✅ Created connection with %lu symbols (CLEAN)", (unsigned long)symbols.count);
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


- (void)updateAlertModel:(AlertModel *)alertModel {
    if (!alertModel || !alertModel.symbol) return;
    
    // Find corresponding Core Data object
    Alert *coreDataAlert = [self findAlertBySymbolAndValue:alertModel.symbol
                                               triggerValue:alertModel.triggerValue
                                            conditionString:alertModel.conditionString];
    if (coreDataAlert) {
        [self updateCoreDataAlertFromRuntimeModel:alertModel coreDataAlert:coreDataAlert];
        [self saveContext];
        
        // Notification
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubAlertTriggeredNotification
                                                            object:self
                                                          userInfo:@{@"alert": alertModel, @"action": @"updated"}];
    }
}

- (void)deleteAlertModel:(AlertModel *)alertModel {
    if (!alertModel || !alertModel.symbol) return;
    
    // Find corresponding Core Data object
    Alert *coreDataAlert = [self findAlertBySymbolAndValue:alertModel.symbol
                                               triggerValue:alertModel.triggerValue
                                            conditionString:alertModel.conditionString];
    if (coreDataAlert) {
        [self deleteAlert:coreDataAlert];
        
        // Notification
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubAlertTriggeredNotification
                                                            object:self
                                                          userInfo:@{@"alert": alertModel, @"action": @"deleted"}];
    }
}

#pragma mark - Alert Validation Methods (NEW)

- (void)validateAlertSymbolTracking {
    NSLog(@"\n🔍 VALIDATION: Alert Symbol Tracking");
    NSLog(@"=====================================");
    
    NSArray<AlertModel *> *alerts = [self getAllAlertModels];
    NSInteger totalAlerts = alerts.count;
    NSInteger alertsWithZeroInteractions = 0;
    NSInteger alertsWithMissingSymbols = 0;
    
    for (AlertModel *alert in alerts) {
        Symbol *symbol = [self getSymbolWithName:alert.symbol];
        
        if (!symbol) {
            alertsWithMissingSymbols++;
            NSLog(@"   ❌ BROKEN: Alert for '%@' but symbol missing from database", alert.symbol);
        } else if (symbol.interactionCount == 0) {
            alertsWithZeroInteractions++;
            NSLog(@"   ⚠️  WARNING: Alert for '%@' but symbol has no interactions", alert.symbol);
        } else {
            NSLog(@"   ✅ OK: Alert for '%@' - %d interactions", alert.symbol, symbol.interactionCount);
        }
    }
    
    NSLog(@"SUMMARY:");
    NSLog(@"- Total alerts: %ld", (long)totalAlerts);
    NSLog(@"- Alerts with missing symbols: %ld", (long)alertsWithMissingSymbols);
    NSLog(@"- Alerts with zero interactions: %ld", (long)alertsWithZeroInteractions);
    NSLog(@"- Tracking success rate: %.1f%%",
          totalAlerts > 0 ?
          (100.0 * (totalAlerts - alertsWithZeroInteractions - alertsWithMissingSymbols) / totalAlerts) : 0.0);
    NSLog(@"=====================================\n");
}

- (void)fixAlertSymbolTracking {
    NSLog(@"\n🔧 FIXING: Alert Symbol Tracking Issues");
    NSLog(@"=====================================");
    
    NSArray<AlertModel *> *alerts = [self getAllAlertModels];
    NSInteger fixedSymbols = 0;
    
    for (AlertModel *alert in alerts) {
        Symbol *symbol = [self getSymbolWithName:alert.symbol];
        
        if (!symbol) {
            // Create missing symbol with proper tracking
            symbol = [self createSymbolWithName:alert.symbol];
            fixedSymbols++;
            NSLog(@"   ✅ CREATED: Symbol '%@' for alert with tracking", alert.symbol);
        } else if (symbol.interactionCount == 0) {
            // Fix zero interaction count
            [self incrementInteractionForSymbol:symbol];
            fixedSymbols++;
            NSLog(@"   ✅ FIXED: Symbol '%@' interaction count updated", alert.symbol);
        }
    }
    
    NSLog(@"FIXED: %ld symbols now have proper tracking", (long)fixedSymbols);
    NSLog(@"=====================================\n");
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


- (void)deleteAlert:(Alert *)alert {
    [self.mainContext deleteObject:alert];
    [self saveContext];
}

- (Alert *)findAlertBySymbolAndValue:(NSString *)symbol
                        triggerValue:(double)triggerValue
                     conditionString:(NSString *)conditionString {
    
    // Find Symbol entity first
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    if (!symbolEntity) return nil;
    
    NSFetchRequest *request = [Alert fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@ AND triggerValue == %f AND conditionString == %@",
                        symbolEntity, triggerValue, conditionString];
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
    model.colorHex = coreDataWatchlist.colorHex;
    model.sortOrder = coreDataWatchlist.sortOrder;
    
    // Convert Symbol relationships to string array
    NSMutableArray<NSString *> *symbolNames = [NSMutableArray array];
    for (Symbol *symbol in coreDataWatchlist.symbols) {
        [symbolNames addObject:symbol.symbol];
    }
    model.symbols = [symbolNames copy];
    
    return model;
}

- (AlertModel *)convertCoreDataToRuntimeModel:(Alert *)coreDataAlert {
    if (!coreDataAlert) return nil;
    
    AlertModel *model = [[AlertModel alloc] init];
    
    // Use Symbol relationship
    model.symbol = coreDataAlert.symbol.symbol;
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


- (void)updateCoreDataAlertFromRuntimeModel:(AlertModel *)runtimeModel
                             coreDataAlert:(Alert *)coreDataAlert {
    
    // ✅ CORREZIONE: Usa createSymbolWithName per tracking se simbolo cambia
    if (!coreDataAlert.symbol || ![coreDataAlert.symbol.symbol isEqualToString:runtimeModel.symbol]) {
        Symbol *symbolEntity = [self createSymbolWithName:runtimeModel.symbol];
        coreDataAlert.symbol = symbolEntity;
    }
    
    coreDataAlert.triggerValue = runtimeModel.triggerValue;
    coreDataAlert.conditionString = runtimeModel.conditionString;
    coreDataAlert.isActive = runtimeModel.isActive;
    coreDataAlert.isTriggered = runtimeModel.isTriggered;
    coreDataAlert.notificationEnabled = runtimeModel.notificationEnabled;
    coreDataAlert.notes = runtimeModel.notes;
    coreDataAlert.creationDate = runtimeModel.creationDate;
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
        // ✅ CLEAN: Return existing WITHOUT any increment
        NSLog(@"DataHub: Found existing symbol: %@", normalizedSymbol);
        return existingSymbol;
    }
    
    // Crea nuovo
    Symbol *symbol = [NSEntityDescription insertNewObjectForEntityForName:@"Symbol"
                                                   inManagedObjectContext:self.mainContext];
    symbol.symbol = normalizedSymbol;
    symbol.creationDate = [NSDate date];
    symbol.firstInteraction = nil; // ✅ Will be set on first REAL interaction
    symbol.lastInteraction = nil;  // ✅ Will be set on first REAL interaction
    symbol.interactionCount = 0;   // ✅ CLEAN: Start at 0
    symbol.isFavorite = NO;
    symbol.tags = @[];
    
    [self.symbols addObject:symbol];
    [self saveContext];
    
    NSLog(@"✅ DataHub: Created symbol: %@ (interactionCount: 0)", normalizedSymbol);
    
    // ✅ CLEAN: Simple creation notification, no tracking implications
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubSymbolCreated"
                                                        object:self
                                                      userInfo:@{@"symbol": symbol}];
    
    return symbol;
}


- (Symbol *)getSymbolWithName:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) return nil;
    
    // RICORDA: Normalizzazione UPPERCASE!
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // Search in memory first (faster)
    for (Symbol *symbol in self.symbols) {
        if ([symbol.symbol isEqualToString:normalizedSymbol]) {
            return symbol;
        }
    }
    
    // If not in memory, fetch from Core Data
    NSFetchRequest *request = [Symbol fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", normalizedSymbol];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ Error fetching symbol %@: %@", normalizedSymbol, error);
        return nil;
    }
    
    if (results.count > 0) {
        Symbol *symbol = results.firstObject;
        // Add to memory cache if not already there
        if (![self.symbols containsObject:symbol]) {
            [self.symbols addObject:symbol];
        }
        return symbol;
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
    
    // Set first interaction if this is the first real interaction
    if (!symbol.firstInteraction) {
        symbol.firstInteraction = [NSDate date];
    }
    
    [self saveContext];
    
    NSLog(@"✅ Manual increment: Symbol %@ interaction count: %d", symbol.symbol, symbol.interactionCount);
}

- (void)incrementInteractionForSymbolName:(NSString *)symbolName {
    // ✅ CLEAN: Just create symbol if doesn't exist, NO automatic increment
    [self createSymbolWithName:symbolName];
    
    NSLog(@"✅ DataHub: ensured symbol exists: %@", symbolName);
}

#pragma mark - Symbol Tag Management

- (void)addTag:(NSString *)tag toSymbol:(Symbol *)symbol {
    if (!tag || !symbol) return;
    
    NSMutableArray *currentTags = [symbol.tags mutableCopy] ?: [NSMutableArray array];
    NSString *normalizedTag = tag.lowercaseString;
    
    if (![currentTags containsObject:normalizedTag]) {
        [currentTags addObject:normalizedTag];
        symbol.tags = [currentTags copy];
        [self saveContext];
        
        NSLog(@"✅ DataHub: Added tag '%@' to %@ (CLEAN)", normalizedTag, symbol.symbol);
        
        // ✅ CLEAN: Simple notification (will be used later for smart tracking)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubSymbolTagAdded"
                                                            object:self
                                                          userInfo:@{
                                                              @"symbol": symbol,
                                                              @"tag": normalizedTag
                                                          }];
    }
}

- (void)removeTag:(NSString *)tag fromSymbol:(Symbol *)symbol {
    if (!tag || !symbol) return;
    
    NSMutableArray *currentTags = [symbol.tags mutableCopy];
    NSString *normalizedTag = tag.lowercaseString;
    
    if ([currentTags containsObject:normalizedTag]) {
        [currentTags removeObject:normalizedTag];
        symbol.tags = [currentTags copy];
        [self saveContext];
        
        NSLog(@"✅ DataHub: Removed tag '%@' from %@ (CLEAN)", normalizedTag, symbol.symbol);
        
        // ✅ CLEAN: Simple notification (will be used later for smart tracking)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubSymbolTagRemoved"
                                                            object:self
                                                          userInfo:@{
                                                              @"symbol": symbol,
                                                              @"tag": normalizedTag
                                                          }];
    }
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






- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSArray<NSString *> *)getSymbolsInvolvedInConnection:(StockConnection *)connection {
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    
    // Add source symbol ✅
    if (connection.sourceSymbol && connection.sourceSymbol.symbol) {
        [symbols addObject:connection.sourceSymbol.symbol];
    }
    
    // ✅ FIXED: Add target symbols with proper conversion
    for (Symbol *symbol in connection.targetSymbols) {
        if ([symbol isKindOfClass:[Symbol class]] && symbol.symbol) {
            if (![symbols containsObject:symbol.symbol]) {
                [symbols addObject:symbol.symbol];
            }
        }
    }
    
    return [symbols copy];
}

- (Symbol *)findOrCreateSymbolWithName:(NSString *)symbolName inContext:(NSManagedObjectContext *)context {
    if (!symbolName || symbolName.length == 0 || !context) return nil;
    
    // RICORDA: Normalizzazione UPPERCASE!
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // Try to find existing
    NSFetchRequest *request = [Symbol fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", normalizedSymbol];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ Error finding symbol %@: %@", normalizedSymbol, error);
        return nil;
    }
    
    if (results.count > 0) {
        // Return existing
        return results.firstObject;
    }
    
    // Create new symbol
    Symbol *symbol = [NSEntityDescription insertNewObjectForEntityForName:@"Symbol"
                                                   inManagedObjectContext:context];
    symbol.symbol = normalizedSymbol;
    symbol.creationDate = [NSDate date];
    symbol.firstInteraction = [NSDate date];
    symbol.lastInteraction = [NSDate date];
    symbol.interactionCount = 1;
    symbol.isFavorite = NO;
    symbol.tags = @[];
    
    NSLog(@"DataHub: Created symbol: %@ in context", normalizedSymbol);
    
    return symbol;
}


#pragma mark - Alert Management (RuntimeModels for UI) - FIXED

- (AlertModel *)createAlertModelWithSymbol:(NSString *)symbol
                              triggerValue:(double)triggerValue
                           conditionString:(NSString *)conditionString
                      notificationEnabled:(BOOL)notificationEnabled
                                     notes:(NSString *)notes {
    
    // ✅ TRACKING UNICO QUI (high-level, chiamato dai widget)
    Symbol *symbolEntity = [self createSymbolWithName:symbol];
    
    // ✅ CREA ALERT con Symbol entity (NO tracking aggiuntivo)
    Alert *coreDataAlert = [self createAlertWithSymbolEntity:symbolEntity
                                                 triggerValue:triggerValue
                                              conditionString:conditionString
                                         notificationEnabled:notificationEnabled
                                                        notes:notes];
    
    // Convert to RuntimeModel
    AlertModel *alertModel = [self convertCoreDataToRuntimeModel:coreDataAlert];
    
    // ✅ UNA SOLA NOTIFICATION
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubAlertTriggeredNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"alert": alertModel,
                                                          @"action": @"created"
                                                      }];
    
    NSLog(@"✅ DataHub: Created alert for %@ at %.2f (interactions: %d)",
          symbol, triggerValue, symbolEntity.interactionCount);
    
    return alertModel;
}

// ============================================================================
// NUOVO: Low-level method che usa Symbol entity (NO tracking)
// ============================================================================

- (Alert *)createAlertWithSymbolEntity:(Symbol *)symbolEntity
                          triggerValue:(double)triggerValue
                       conditionString:(NSString *)conditionString
                  notificationEnabled:(BOOL)notificationEnabled
                                 notes:(NSString *)notes {
    
    Alert *alert = [NSEntityDescription insertNewObjectForEntityForName:@"Alert"
                                                 inManagedObjectContext:self.mainContext];
    
    // ✅ USA ENTITY PASSATA (no tracking qui)
    alert.symbol = symbolEntity;
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

#pragma mark - VALIDATION: Debug Method for Type Checking

- (void)validateSymbolConsistency {
    NSLog(@"\n🔍 VALIDATION: Symbol Type Consistency Check");
    NSLog(@"==============================================");
    
    // Check symbols array consistency
    NSInteger validSymbols = 0;
    NSInteger invalidSymbols = 0;
    
    for (id obj in self.symbols) {
        if ([obj isKindOfClass:[Symbol class]]) {
            Symbol *symbol = (Symbol *)obj;
            if (symbol.symbol && [symbol.symbol isKindOfClass:[NSString class]]) {
                validSymbols++;
            } else {
                invalidSymbols++;
                NSLog(@"❌ Invalid symbol entity: %@", obj);
            }
        } else {
            invalidSymbols++;
            NSLog(@"❌ Non-Symbol object in symbols array: %@", NSStringFromClass([obj class]));
        }
    }
    
    NSLog(@"✅ Valid symbols: %ld", (long)validSymbols);
    NSLog(@"❌ Invalid symbols: %ld", (long)invalidSymbols);
    
    // Check watchlists symbol relationships
    NSArray<Watchlist *> *watchlists = [self getAllWatchlists];
    for (Watchlist *watchlist in watchlists) {
        NSLog(@"📋 Watchlist '%@':", watchlist.name);
        NSLog(@"   - symbols.count: %lu", (unsigned long)watchlist.symbols.count);
        NSLog(@"   - symbolNames: %@", [watchlist symbolNames]);
    }
    
    NSLog(@"VALIDATION COMPLETE\n");
}


- (void)validateCleanTrackingState {
    NSLog(@"\n🧹 VALIDATION: Clean Tracking State");
    NSLog(@"==================================");
    
    NSArray<Symbol *> *allSymbols = [self getAllSymbols];
    NSInteger zeroInteractions = 0;
    NSInteger nonZeroInteractions = 0;
    
    for (Symbol *symbol in allSymbols) {
        if (symbol.interactionCount == 0) {
            zeroInteractions++;
        } else {
            nonZeroInteractions++;
            NSLog(@"📊 Symbol %@ has %d interactions (pre-cleanup)",
                  symbol.symbol, symbol.interactionCount);
        }
    }
    
    NSLog(@"📈 Tracking State:");
    NSLog(@"   Zero interactions: %ld", (long)zeroInteractions);
    NSLog(@"   Non-zero interactions: %ld (existing before cleanup)", (long)nonZeroInteractions);
    NSLog(@"✅ All automatic tracking removed");
    NSLog(@"✅ Only manual increments will work now");
    NSLog(@"CLEAN STATE VALIDATION COMPLETE\n");
}



@end
