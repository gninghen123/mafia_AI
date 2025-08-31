//
//  DataHub+Connections.m
//  mafia_AI
//

#import "DataHub+Connections.h"
#import "DataHub+Private.h"
#import "StockConnection+CoreDataClass.h"
#import "DataManager.h"
#import "DataManager+AISummary.h"

@implementation DataHub (Connections)

#pragma mark - Connection Creation

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
    connection.bidirectional = YES;  // Default for this creation method
    
    // ✅ FIXED: Symbol relationships with better error handling
    if (symbols.count == 1) {
        // Single symbol - set as source only
        Symbol *symbol = [self findOrCreateSymbolWithName:symbols[0] inContext:self.mainContext];
        if (symbol) {
            connection.sourceSymbol = symbol;
        } else {
            NSLog(@"❌ Failed to create source symbol: %@", symbols[0]);
            [self.mainContext deleteObject:connection];
            return nil;
        }
    } else {
        // Multiple symbols - first as source, rest as targets
        Symbol *sourceSymbol = [self findOrCreateSymbolWithName:symbols[0] inContext:self.mainContext];
        if (!sourceSymbol) {
            NSLog(@"❌ Failed to create source symbol: %@", symbols[0]);
            [self.mainContext deleteObject:connection];
            return nil;
        }
        connection.sourceSymbol = sourceSymbol;
        
        // Add remaining symbols as targets
        NSMutableSet *targetSymbols = [NSMutableSet set];
        for (NSInteger i = 1; i < symbols.count; i++) {
            Symbol *targetSymbol = [self findOrCreateSymbolWithName:symbols[i] inContext:self.mainContext];
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"action": @"created",
                                                          @"connection": connection
                                                      }];
    
    NSLog(@"✅ Created connection with %lu symbols", (unsigned long)symbols.count);
    return connection;
}

- (ConnectionModel *)createDirectionalConnectionFromSymbol:(NSString *)sourceSymbol
                                                 toSymbols:(NSArray<NSString *> *)targetSymbols
                                                      type:(StockConnectionType)type
                                                     title:(NSString *)title {
    
    ConnectionModel *connection = [[ConnectionModel alloc] initDirectionalFromSymbol:sourceSymbol
                                                                           toSymbols:targetSymbols
                                                                                type:type
                                                                               title:title];
    
    // Crea l'entità Core Data
    StockConnection *coreDataConnection = [NSEntityDescription insertNewObjectForEntityForName:@"StockConnection"
                                                                        inManagedObjectContext:self.mainContext];
    
    [self updateConnectionCoreDataFromRuntimeModel:connection coreDataConnection:coreDataConnection];
    
    // Aggiungi alla collezione
    [self.connections addObject:coreDataConnection];
    
    // Salva
    [self saveContext];
    
    // Notifica
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"action": @"created",
                                                          @"connection": connection
                                                      }];
    
    NSLog(@"DataHub: Created directional connection '%@' from %@ to %@", title, sourceSymbol, targetSymbols);
    
    return connection;
}

- (ConnectionModel *)createBidirectionalConnectionWithSymbols:(NSArray<NSString *> *)symbols
                                                         type:(StockConnectionType)type
                                                        title:(NSString *)title {
    
    ConnectionModel *connection = [[ConnectionModel alloc] initBidirectionalWithSymbols:symbols
                                                                                    type:type
                                                                                   title:title];
    
    // Crea l'entità Core Data
    StockConnection *coreDataConnection = [NSEntityDescription insertNewObjectForEntityForName:@"StockConnection"
                                                                        inManagedObjectContext:self.mainContext];
    
    [self updateConnectionCoreDataFromRuntimeModel:connection coreDataConnection:coreDataConnection];

    // Aggiungi alla collezione
    [self.connections addObject:coreDataConnection];
    
    // Salva
    [self saveContext];
    
    // Notifica
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"action": @"created",
                                                          @"connection": connection
                                                      }];
    
    NSLog(@"DataHub: Created bidirectional connection '%@' with symbols %@", title, symbols);
    
    return connection;
}

#pragma mark - CRUD Operations

- (void)updateConnection:(ConnectionModel *)connection {
    // Trova la corrispondente entità Core Data
    StockConnection *coreDataConnection = [self findCoreDataConnectionWithID:connection.connectionID];
    
    if (coreDataConnection) {
        connection.lastModified = [NSDate date];
        [self updateConnectionCoreDataFromRuntimeModel:connection coreDataConnection:coreDataConnection];
        [self saveContext];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"action": @"updated",
                                                              @"connection": connection
                                                          }];
        
        NSLog(@"DataHub: Updated connection '%@'", connection.title);
    } else {
        NSLog(@"DataHub: WARNING - Could not find Core Data connection with ID %@", connection.connectionID);
    }
}

- (void)deleteConnection:(ConnectionModel *)connection {
    [self deleteConnectionWithID:connection.connectionID];
}

- (void)deleteConnectionWithID:(NSString *)connectionID {
    StockConnection *coreDataConnection = [self findCoreDataConnectionWithID:connectionID];
    
    if (coreDataConnection) {
        [self.connections removeObject:coreDataConnection];
        [self.mainContext deleteObject:coreDataConnection];
        [self saveContext];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"action": @"deleted",
                                                              @"connectionID": connectionID
                                                          }];
        
        NSLog(@"DataHub: Deleted connection with ID %@", connectionID);
    } else {
        NSLog(@"DataHub: WARNING - Could not find connection to delete with ID %@", connectionID);
    }
}

#pragma mark - Retrieve Connections

- (NSArray<ConnectionModel *> *)getAllConnections {
    NSMutableArray<ConnectionModel *> *runtimeModels = [NSMutableArray array];
    
    for (StockConnection *coreDataConnection in self.connections) {
        ConnectionModel *runtimeModel = [self convertCoreDataConnectionToRuntimeModel:coreDataConnection];
        if (runtimeModel) {
            [runtimeModels addObject:runtimeModel];
        }
    }
    
    return [runtimeModels copy];
}

- (NSArray<ConnectionModel *> *)getActiveConnections {
    NSMutableArray<ConnectionModel *> *activeConnections = [NSMutableArray array];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        if (connection.isActive && ![connection shouldAutoDelete]) {
            [activeConnections addObject:connection];
        }
    }
    
    return [activeConnections copy];
}

- (NSArray<ConnectionModel *> *)getConnectionsForSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) {
        NSLog(@"❌ getConnectionsForSymbol: Invalid symbol");
        return @[];
    }
    
    // Find Symbol entity first
    NSFetchRequest *symbolRequest = [Symbol fetchRequest];
    symbolRequest.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol.uppercaseString];
    
    NSError *error;
    NSArray *symbolResults = [self.mainContext executeFetchRequest:symbolRequest error:&error];
    
    if (error) {
        NSLog(@"❌ Error fetching symbol %@: %@", symbol, error);
        return @[];
    }
    
    if (symbolResults.count == 0) {
        NSLog(@"⚠️ Symbol %@ not found in database", symbol);
        return @[];
    }
    
    Symbol *symbolEntity = symbolResults.firstObject;
    NSMutableArray<ConnectionModel *> *connections = [NSMutableArray array];
    
    // ✅ Get connections where this symbol is the source
    for (StockConnection *connection in symbolEntity.sourceConnections) {
        ConnectionModel *model = [self convertCoreDataConnectionToRuntimeModel:connection];
        if (model) {
            [connections addObject:model];
        }
    }
    
    // ✅ Get connections where this symbol is a target
    for (StockConnection *connection in symbolEntity.targetConnections) {
        ConnectionModel *model = [self convertCoreDataConnectionToRuntimeModel:connection];
        if (model && ![connections containsObject:model]) {
            [connections addObject:model];
        }
    }
    
    NSLog(@"✅ Found %lu connections for symbol %@", (unsigned long)connections.count, symbol);
    return [connections copy];
}



- (NSArray<ConnectionModel *> *)getConnectionsOfType:(StockConnectionType)type {
    NSMutableArray<ConnectionModel *> *typeConnections = [NSMutableArray array];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        if (connection.connectionType == type) {
            [typeConnections addObject:connection];
        }
    }
    
    return [typeConnections copy];
}

- (nullable ConnectionModel *)getConnectionWithID:(NSString *)connectionID {
    for (ConnectionModel *connection in [self getAllConnections]) {
        if ([connection.connectionID isEqualToString:connectionID]) {
            return connection;
        }
    }
    return nil;
}

#pragma mark - Search and Filter

- (NSArray<ConnectionModel *> *)searchConnectionsWithQuery:(NSString *)query {
    if (query.length == 0) return [self getAllConnections];
    
    NSString *lowercaseQuery = [query lowercaseString];
    NSMutableArray<ConnectionModel *> *results = [NSMutableArray array];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        BOOL matches = NO;
        
        // Search in title
        if ([connection.title.lowercaseString containsString:lowercaseQuery]) {
            matches = YES;
        }
        
        // Search in description
        if (!matches && [connection.connectionDescription.lowercaseString containsString:lowercaseQuery]) {
            matches = YES;
        }
        
        // Search in symbols
        if (!matches) {
            for (NSString *symbol in [connection allInvolvedSymbols]) {
                if ([symbol.lowercaseString containsString:lowercaseQuery]) {
                    matches = YES;
                    break;
                }
            }
        }
        
        // Search in summaries
        if (!matches && [connection.effectiveSummary.lowercaseString containsString:lowercaseQuery]) {
            matches = YES;
        }
        
        // Search in tags
        if (!matches) {
            for (NSString *tag in connection.tags) {
                if ([tag.lowercaseString containsString:lowercaseQuery]) {
                    matches = YES;
                    break;
                }
            }
        }
        
        if (matches) {
            [results addObject:connection];
        }
    }
    
    return [results copy];
}

- (NSArray<ConnectionModel *> *)getConnectionsModifiedSince:(NSDate *)date {
    NSMutableArray<ConnectionModel *> *modifiedConnections = [NSMutableArray array];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        if ([connection.lastModified compare:date] == NSOrderedDescending) {
            [modifiedConnections addObject:connection];
        }
    }
    
    return [modifiedConnections copy];
}

- (NSArray<ConnectionModel *> *)getConnectionsWithStrengthAbove:(double)threshold {
    NSMutableArray<ConnectionModel *> *strongConnections = [NSMutableArray array];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        [connection updateCurrentStrength];
        if (connection.currentStrength >= threshold) {
            [strongConnections addObject:connection];
        }
    }
    
    return [strongConnections copy];
}

- (NSArray<ConnectionModel *> *)getConnectionsRequiringDecayUpdate {
    NSMutableArray<ConnectionModel *> *needsUpdate = [NSMutableArray array];
    NSDate *now = [NSDate date];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        // Update if more than 1 hour has passed since last update
        NSTimeInterval timeSinceUpdate = [now timeIntervalSinceDate:connection.lastStrengthUpdate];
        if (timeSinceUpdate > 3600) { // 1 hour
            [needsUpdate addObject:connection];
        }
    }
    
    return [needsUpdate copy];
}

#pragma mark - Symbol Relationships

- (NSArray<NSString *> *)getRelatedSymbolsForSymbol:(NSString *)symbol {
    NSMutableSet<NSString *> *relatedSymbols = [NSMutableSet set];
    
    for (ConnectionModel *connection in [self getConnectionsForSymbol:symbol]) {
        if (connection.isActive) {
            [relatedSymbols addObjectsFromArray:[connection getRelatedSymbolsForSymbol:symbol]];
        }
    }
    
    return [relatedSymbols.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSString *> *)getRelatedSymbolsForSymbol:(NSString *)symbol ofType:(StockConnectionType)type {
    NSMutableSet<NSString *> *relatedSymbols = [NSMutableSet set];
    
    for (ConnectionModel *connection in [self getConnectionsForSymbol:symbol]) {
        if (connection.isActive && connection.connectionType == type) {
            [relatedSymbols addObjectsFromArray:[connection getRelatedSymbolsForSymbol:symbol]];
        }
    }
    
    return [relatedSymbols.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<ConnectionModel *> *)getConnectionsBetweenSymbol:(NSString *)symbol1 andSymbol:(NSString *)symbol2 {
    NSMutableArray<ConnectionModel *> *betweenConnections = [NSMutableArray array];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        if ([connection involvesSymbol:symbol1] && [connection involvesSymbol:symbol2]) {
            [betweenConnections addObject:connection];
        }
    }
    
    return [betweenConnections copy];
}

- (BOOL)areSymbolsConnected:(NSString *)symbol1 andSymbol:(NSString *)symbol2 {
    return [[self getConnectionsBetweenSymbol:symbol1 andSymbol:symbol2] count] > 0;
}

#pragma mark - AI Summary Integration

- (void)generateAISummaryForConnection:(ConnectionModel *)connection
                            completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    
    if (!connection.url || connection.url.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"No URL available for AI summary"}];
        if (completion) completion(nil, error);
        return;
    }
    
    [self summarizeNewsFromURL:connection.url completion:^(NSString * _Nullable summary, NSError * _Nullable error) {
        if (summary && !error) {
            [connection setAISummary:summary];
            [self updateConnection:connection];
        }
        
        if (completion) completion(summary, error);
    }];
}

- (void)summarizeNewsFromURL:(NSString *)url
                  completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    
    // Questo metodo delega a DataManager che poi chiamerà DownloadManager -> Claude API
    // Seguendo l'architettura esistente
    
    DataManager *dataManager = [DataManager sharedManager];
    
    // Crea i parametri per la richiesta
    NSDictionary *parameters = @{
        @"url": url,
        @"requestType": @"newsSummary"
    };
    
    // Chiama DataManager per gestire la richiesta AI
    [dataManager requestAISummaryForURL:url completion:^(NSString * _Nullable summary, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(summary, error);
        });
    }];
}

#pragma mark - Strength Management

- (void)updateAllConnectionStrengths {
    NSArray<ConnectionModel *> *allConnections = [self getAllConnections];
    
    for (ConnectionModel *connection in allConnections) {
        [self updateStrengthForConnection:connection];
    }
    
    NSLog(@"DataHub: Updated strength for %lu connections", (unsigned long)allConnections.count);
}

- (void)updateStrengthForConnection:(ConnectionModel *)connection {
    [connection updateCurrentStrength];
    [self updateConnection:connection];
}

- (NSArray<ConnectionModel *> *)getConnectionsToAutoDelete {
    NSMutableArray<ConnectionModel *> *toDelete = [NSMutableArray array];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        if ([connection shouldAutoDelete]) {
            [toDelete addObject:connection];
        }
    }
    
    return [toDelete copy];
}

- (void)performAutoCleanup {
    NSArray<ConnectionModel *> *toDelete = [self getConnectionsToAutoDelete];
    
    for (ConnectionModel *connection in toDelete) {
        NSLog(@"DataHub: Auto-deleting connection '%@' (strength: %.1f%%)",
              connection.title, connection.currentStrength * 100);
        [self deleteConnection:connection];
    }
    
    if (toDelete.count > 0) {
        NSLog(@"DataHub: Auto-cleanup completed - deleted %lu connections", (unsigned long)toDelete.count);
    }
}

- (double)averageStrengthForSymbol:(NSString *)symbol {
    NSArray<ConnectionModel *> *symbolConnections = [self getConnectionsForSymbol:symbol];
    
    if (symbolConnections.count == 0) return 0.0;
    
    double totalStrength = 0.0;
    NSInteger activeCount = 0;
    
    for (ConnectionModel *connection in symbolConnections) {
        if (connection.isActive) {
            [connection updateCurrentStrength];
            totalStrength += connection.currentStrength;
            activeCount++;
        }
    }
    
    return activeCount > 0 ? totalStrength / activeCount : 0.0;
}

- (NSArray<ConnectionModel *> *)getWeakestConnections:(NSInteger)count {
    NSArray<ConnectionModel *> *allConnections = [self getActiveConnections];
    
    // Aggiorna le forze
    for (ConnectionModel *connection in allConnections) {
        [connection updateCurrentStrength];
    }
    
    // Ordina per forza (crescente)
    NSArray<ConnectionModel *> *sorted = [allConnections sortedArrayUsingComparator:^NSComparisonResult(ConnectionModel *obj1, ConnectionModel *obj2) {
        if (obj1.currentStrength < obj2.currentStrength) return NSOrderedAscending;
        if (obj1.currentStrength > obj2.currentStrength) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    NSInteger takeCount = MIN(count, sorted.count);
    return [sorted subarrayWithRange:NSMakeRange(0, takeCount)];
}

- (NSArray<ConnectionModel *> *)getStrongestConnections:(NSInteger)count {
    NSArray<ConnectionModel *> *allConnections = [self getActiveConnections];
    
    // Aggiorna le forze
    for (ConnectionModel *connection in allConnections) {
        [connection updateCurrentStrength];
    }
    
    // Ordina per forza (decrescente)
    NSArray<ConnectionModel *> *sorted = [allConnections sortedArrayUsingComparator:^NSComparisonResult(ConnectionModel *obj1, ConnectionModel *obj2) {
        if (obj1.currentStrength > obj2.currentStrength) return NSOrderedAscending;
        if (obj1.currentStrength < obj2.currentStrength) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    NSInteger takeCount = MIN(count, sorted.count);
    return [sorted subarrayWithRange:NSMakeRange(0, takeCount)];
}

#pragma mark - Helper Methods

- (StockConnection *)findCoreDataConnectionWithID:(NSString *)connectionID {
    for (StockConnection *coreDataConnection in self.connections) {
        if ([coreDataConnection.connectionID isEqualToString:connectionID]) {
            return coreDataConnection;
        }
    }
    return nil;
}

- (ConnectionModel *)convertCoreDataConnectionToRuntimeModel:(StockConnection *)coreDataConnection {
    if (!coreDataConnection) return nil;
    
    ConnectionModel *model = [[ConnectionModel alloc] init];
    
    // Basic properties
    model.connectionID = coreDataConnection.connectionID ?: [[NSUUID UUID] UUIDString];
    model.title = coreDataConnection.title ?: @"";
    model.connectionDescription = coreDataConnection.connectionDescription ?: @"";
    model.connectionType = coreDataConnection.connectionType;
    model.source = coreDataConnection.source ?: @"";
    model.url = coreDataConnection.url ?: @"";
    model.bidirectional = coreDataConnection.bidirectional;
    model.isActive = coreDataConnection.isActive;
    
    // ✅ FIXED: Symbol relationships - Convert entities to strings
    if (coreDataConnection.sourceSymbol && coreDataConnection.sourceSymbol.symbol) {
        model.sourceSymbol = coreDataConnection.sourceSymbol.symbol;
    }
    
    // ✅ FIXED: Target symbols conversion NSSet<Symbol *> → NSArray<NSString *>
    NSMutableArray<NSString *> *targetSymbolStrings = [NSMutableArray array];
    for (Symbol *symbolEntity in coreDataConnection.targetSymbols) {
        if ([symbolEntity isKindOfClass:[Symbol class]] && symbolEntity.symbol) {
            [targetSymbolStrings addObject:symbolEntity.symbol];
        }
    }
    model.targetSymbols = [targetSymbolStrings copy];
    
    // ✅ FIXED: All symbols array - Combine source + targets
    NSMutableArray<NSString *> *allSymbols = [NSMutableArray array];
    if (model.sourceSymbol) {
        [allSymbols addObject:model.sourceSymbol];
    }
    [allSymbols addObjectsFromArray:model.targetSymbols];
    model.symbols = [allSymbols copy];
    
    // AI Summary
    model.originalSummary = coreDataConnection.originalSummary ?: @"";
    model.manualSummary = coreDataConnection.manualSummary ?: @"";
    model.summarySource = coreDataConnection.summarySource;
    
    // Strength and decay
    model.initialStrength = coreDataConnection.initialStrength;
    model.currentStrength = coreDataConnection.currentStrength;
    model.decayRate = coreDataConnection.decayRate;
    model.minimumStrength = coreDataConnection.minimumStrength;
    model.strengthHorizon = coreDataConnection.strengthHorizon;
    model.autoDelete = coreDataConnection.autoDelete;
    model.lastStrengthUpdate = coreDataConnection.lastStrengthUpdate ?: [NSDate date];
    
    // Metadata
    model.notes = coreDataConnection.notes ?: @"";
    model.tags = coreDataConnection.tags ?: @[];
    model.creationDate = coreDataConnection.creationDate ?: [NSDate date];
    model.lastModified = coreDataConnection.lastModified ?: [NSDate date];
    
    return model;
}


- (void)updateConnectionCoreDataFromRuntimeModel:(ConnectionModel *)runtimeModel
                                coreDataConnection:(StockConnection *)coreDataConnection {
    
    if (!runtimeModel || !coreDataConnection) {
        NSLog(@"❌ updateConnectionCoreDataFromRuntimeModel: Invalid parameters");
        return;
    }
    
    NSManagedObjectContext *context = coreDataConnection.managedObjectContext;
    if (!context) {
        NSLog(@"❌ updateConnectionCoreDataFromRuntimeModel: No managedObjectContext");
        return;
    }
    
    // Basic fields
    coreDataConnection.connectionID = runtimeModel.connectionID ?: [[NSUUID UUID] UUIDString];
    coreDataConnection.title = runtimeModel.title ?: @"";
    coreDataConnection.connectionDescription = runtimeModel.connectionDescription ?: @"";
    coreDataConnection.connectionType = runtimeModel.connectionType;
    coreDataConnection.source = runtimeModel.source ?: @"";
    coreDataConnection.url = runtimeModel.url ?: @"";
    coreDataConnection.creationDate = runtimeModel.creationDate ?: [NSDate date];
    coreDataConnection.lastModified = runtimeModel.lastModified ?: [NSDate date];
    coreDataConnection.isActive = runtimeModel.isActive;
    coreDataConnection.bidirectional = runtimeModel.bidirectional;
    
    // ✅ FIXED: Source symbol relationship with validation
    if (runtimeModel.sourceSymbol && runtimeModel.sourceSymbol.length > 0) {
        Symbol *sourceSymbol = [self findOrCreateSymbolWithName:runtimeModel.sourceSymbol inContext:context];
        if (sourceSymbol) {
            coreDataConnection.sourceSymbol = sourceSymbol;
        } else {
            NSLog(@"❌ Failed to create/find source symbol: %@", runtimeModel.sourceSymbol);
        }
    } else {
        coreDataConnection.sourceSymbol = nil;
    }
    
    // ✅ FIXED: Target symbols relationships with validation
    NSMutableSet *targetSymbolsSet = [NSMutableSet set];
    for (NSString *symbolName in runtimeModel.targetSymbols) {
        if (symbolName && [symbolName isKindOfClass:[NSString class]] && symbolName.length > 0) {
            Symbol *symbol = [self findOrCreateSymbolWithName:symbolName inContext:context];
            if (symbol) {
                [targetSymbolsSet addObject:symbol];
            } else {
                NSLog(@"❌ Failed to create/find target symbol: %@", symbolName);
            }
        }
    }
    coreDataConnection.targetSymbols = targetSymbolsSet;
    
    // AI Summary
    coreDataConnection.originalSummary = runtimeModel.originalSummary ?: @"";
    coreDataConnection.manualSummary = runtimeModel.manualSummary ?: @"";
    coreDataConnection.summarySource = runtimeModel.summarySource;
    
    // Strength and decay
    coreDataConnection.initialStrength = runtimeModel.initialStrength;
    coreDataConnection.currentStrength = runtimeModel.currentStrength;
    coreDataConnection.decayRate = runtimeModel.decayRate;
    coreDataConnection.minimumStrength = runtimeModel.minimumStrength;
    coreDataConnection.strengthHorizon = runtimeModel.strengthHorizon;
    coreDataConnection.autoDelete = runtimeModel.autoDelete;
    coreDataConnection.lastStrengthUpdate = runtimeModel.lastStrengthUpdate ?: [NSDate date];
    
    // Metadata
    coreDataConnection.notes = runtimeModel.notes ?: @"";
    coreDataConnection.tags = runtimeModel.tags ?: @[];
    
    NSLog(@"✅ Updated Core Data connection: %@", coreDataConnection.connectionID);
}

#pragma mark - Bulk Operations

- (NSDictionary *)exportConnectionsData {
    NSArray<ConnectionModel *> *allConnections = [self getAllConnections];
    NSMutableArray *connectionsData = [NSMutableArray array];
    
    for (ConnectionModel *connection in allConnections) {
        [connectionsData addObject:[connection toDictionary]];
    }
    
    return @{
        @"connections": connectionsData,
        @"exportDate": [NSDate date],
        @"version": @"1.0"
    };
}

- (BOOL)importConnectionsData:(NSDictionary *)data error:(NSError **)error {
    NSArray *connectionsData = data[@"connections"];
    if (!connectionsData) {
        if (error) {
            *error = [NSError errorWithDomain:@"DataHub"
                                         code:400
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid import data format"}];
        }
        return NO;
    }
    
    NSInteger importedCount = 0;
    
    for (NSDictionary *connectionDict in connectionsData) {
        ConnectionModel *connection = [[ConnectionModel alloc] init];
        [connection updateFromDictionary:connectionDict];
        
        // Check if connection already exists
        ConnectionModel *existing = [self getConnectionWithID:connection.connectionID];
        if (existing) {
            // Update existing
            [connection updateFromDictionary:connectionDict];
            [self updateConnection:connection];
        } else {
            // Create new
            StockConnection *coreDataConnection = [NSEntityDescription insertNewObjectForEntityForName:@"StockConnection"
                                                                                inManagedObjectContext:self.mainContext];
            [self updateConnectionCoreDataFromRuntimeModel:connection coreDataConnection:coreDataConnection];
            [self.connections addObject:coreDataConnection];
        }
        
        importedCount++;
    }
    
    [self saveContext];
    
    NSLog(@"DataHub: Imported %ld connections", (long)importedCount);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataHubConnectionsUpdatedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"action": @"imported",
                                                          @"count": @(importedCount)
                                                      }];
    
    return YES;
}

- (void)updateMultipleConnections:(NSArray<ConnectionModel *> *)connections {
    for (ConnectionModel *connection in connections) {
        [self updateConnection:connection];
    }
}

- (void)deleteMultipleConnections:(NSArray<ConnectionModel *> *)connections {
    for (ConnectionModel *connection in connections) {
        [self deleteConnection:connection];
    }
}

#pragma mark - Statistics

- (NSInteger)totalConnectionsCount {
    return self.connections.count;
}

- (NSInteger)activeConnectionsCount {
    return [self getActiveConnections].count;
}

- (NSDictionary<NSNumber *, NSNumber *> *)connectionCountsByType {
    NSMutableDictionary<NSNumber *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    
    for (ConnectionModel *connection in [self getAllConnections]) {
        NSNumber *typeKey = @(connection.connectionType);
        NSNumber *currentCount = counts[typeKey] ?: @(0);
        counts[typeKey] = @([currentCount integerValue] + 1);
    }
    
    return [counts copy];
}

- (NSArray<NSString *> *)mostConnectedSymbols:(NSInteger)count {
    NSMutableDictionary<NSString *, NSNumber *> *symbolCounts = [NSMutableDictionary dictionary];
    
    for (ConnectionModel *connection in [self getActiveConnections]) {
        for (NSString *symbol in [connection allInvolvedSymbols]) {
            NSNumber *currentCount = symbolCounts[symbol] ?: @(0);
            symbolCounts[symbol] = @([currentCount integerValue] + 1);
        }
    }
    
    // Sort by count (descending)
    NSArray *sortedSymbols = [symbolCounts.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        NSInteger count1 = [symbolCounts[obj1] integerValue];
        NSInteger count2 = [symbolCounts[obj2] integerValue];
        if (count1 > count2) return NSOrderedAscending;
        if (count1 < count2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    NSInteger takeCount = MIN(count, sortedSymbols.count);
    return [sortedSymbols subarrayWithRange:NSMakeRange(0, takeCount)];
}

- (NSInteger)connectionsCountForType:(StockConnectionType)type {
    return [[self getConnectionsOfType:type] count];
}

- (NSArray<NSString *> *)symbolsForType:(StockConnectionType)type {
    NSMutableSet<NSString *> *symbols = [NSMutableSet set];
    
    for (ConnectionModel *connection in [self getConnectionsOfType:type]) {
        [symbols addObjectsFromArray:[connection allInvolvedSymbols]];
    }
    
    return [symbols.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

#pragma mark - Cache Management

- (void)refreshConnectionsCache {
    // Forza il reload di tutte le connections dal Core Data
    [self.connections removeAllObjects];
    [self loadConnectionsFromCoreData];
    
    NSLog(@"DataHub: Refreshed connections cache - loaded %lu connections", (unsigned long)self.connections.count);
}

- (void)clearConnectionsCache {
    // Clear cache senza toccare Core Data
    [self.connections removeAllObjects];
    
    NSLog(@"DataHub: Cleared connections cache");
}

- (void)loadConnectionsFromCoreData {
    NSFetchRequest *request = [StockConnection fetchRequest];
    NSError *error = nil;
    NSArray<StockConnection *> *fetchedConnections = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"DataHub: Error loading connections from Core Data: %@", error.localizedDescription);
        return;
    }
    
    [self.connections addObjectsFromArray:fetchedConnections];
}


#pragma mark - VALIDATION: Connection-Symbol Consistency Check

- (void)validateConnectionSymbolConsistency {
    NSLog(@"\n🔍 VALIDATION: Connection-Symbol Consistency Check");
    NSLog(@"==================================================");
    
    NSArray<StockConnection *> *connections = [self getAllConnections];
    NSInteger validConnections = 0;
    NSInteger invalidConnections = 0;
    
    for (StockConnection *connection in connections) {
        BOOL isValid = YES;
        NSMutableArray *issues = [NSMutableArray array];
        
        // Check source symbol
        if (connection.sourceSymbol) {
            if (![connection.sourceSymbol isKindOfClass:[Symbol class]] || !connection.sourceSymbol.symbol) {
                [issues addObject:@"Invalid source symbol"];
                isValid = NO;
            }
        }
        
        // Check target symbols
        for (Symbol *target in connection.targetSymbols) {
            if (![target isKindOfClass:[Symbol class]] || !target.symbol) {
                [issues addObject:@"Invalid target symbol"];
                isValid = NO;
                break;
            }
        }
        
        if (isValid) {
            validConnections++;
        } else {
            invalidConnections++;
            NSLog(@"❌ Connection %@: %@", connection.connectionID, [issues componentsJoinedByString:@", "]);
        }
    }
    
    NSLog(@"✅ Valid connections: %ld", (long)validConnections);
    NSLog(@"❌ Invalid connections: %ld", (long)invalidConnections);
    NSLog(@"CONNECTION VALIDATION COMPLETE\n");
}
@end
