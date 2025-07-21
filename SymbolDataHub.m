//
//  SymbolDataHub.m
//  TradingApp
//

#import "SymbolDataHub.h"
#import "SymbolDataModels.h"  // Ora questo import è sicuro perché non c'è più circolarità
#import <AppKit/AppKit.h>  // Per NSColor su macOS

// Notification keys
NSString *const kSymbolDataUpdatedNotification = @"SymbolDataUpdatedNotification";
NSString *const kSymbolDataAddedNotification = @"SymbolDataAddedNotification";
NSString *const kSymbolDataRemovedNotification = @"SymbolDataRemovedNotification";
NSString *const kAlertTriggeredNotification = @"AlertTriggeredNotification";

// UserInfo keys
NSString *const kSymbolKey = @"symbol";
NSString *const kUpdateTypeKey = @"updateType";
NSString *const kOldValueKey = @"oldValue";
NSString *const kNewValueKey = @"newValue";

@interface SymbolDataHub ()

@property (strong, nonatomic) NSPersistentContainer *persistentContainer;
@property (strong, nonatomic) NSManagedObjectContext *mainContext;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMutableSet *> *observers;
@property (strong, nonatomic) dispatch_queue_t saveQueue;

@end

@implementation SymbolDataHub

#pragma mark - Singleton

+ (instancetype)sharedHub {
    static SymbolDataHub *sharedHub = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHub = [[self alloc] init];
    });
    return sharedHub;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _observers = [NSMutableDictionary dictionary];
        _saveQueue = dispatch_queue_create("com.tradingapp.symboldatahub.save", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Core Data Stack

- (void)initializeWithCompletion:(nullable void(^)(NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self setupCoreDataStack];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil);
            }
        });
    });
}

- (void)setupCoreDataStack {
    NSPersistentContainer *container = [[NSPersistentContainer alloc] initWithName:@"SymbolDataModel"];
    
    // Configura il modello programmaticamente
    NSManagedObjectModel *model = [self createManagedObjectModel];
    container = [[NSPersistentContainer alloc] initWithName:@"SymbolDataModel" managedObjectModel:model];
    
    // Configura per supportare migrazioni leggere
    NSDictionary *options = @{
        NSMigratePersistentStoresAutomaticallyOption: @YES,
        NSInferMappingModelAutomaticallyOption: @YES
    };
    
    NSPersistentStoreDescription *storeDescription = container.persistentStoreDescriptions.firstObject;
    [storeDescription setOption:options[NSMigratePersistentStoresAutomaticallyOption]
                         forKey:NSMigratePersistentStoresAutomaticallyOption];
    [storeDescription setOption:options[NSInferMappingModelAutomaticallyOption]
                         forKey:NSInferMappingModelAutomaticallyOption];
    
    [container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
        if (error != nil) {
            NSLog(@"Failed to load persistent stores: %@", error);
            abort();
        }
    }];
    
    self.persistentContainer = container;
    self.mainContext = container.viewContext;
    self.mainContext.automaticallyMergesChangesFromParent = YES;
}

- (NSManagedObjectModel *)createManagedObjectModel {
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
    
    // SymbolData Entity
    NSEntityDescription *symbolEntity = [[NSEntityDescription alloc] init];
    symbolEntity.name = @"SymbolData";
    symbolEntity.managedObjectClassName = @"SymbolData";
    
    // Attributi base
    NSMutableArray *symbolProperties = [NSMutableArray array];
    [symbolProperties addObject:[self attributeWithName:@"symbol" type:NSStringAttributeType]];
    [symbolProperties addObject:[self attributeWithName:@"fullName" type:NSStringAttributeType optional:YES]];
    [symbolProperties addObject:[self attributeWithName:@"exchange" type:NSStringAttributeType optional:YES]];
    [symbolProperties addObject:[self attributeWithName:@"dateAdded" type:NSDateAttributeType]];
    [symbolProperties addObject:[self attributeWithName:@"lastModified" type:NSDateAttributeType]];
    [symbolProperties addObject:[self attributeWithName:@"customData" type:NSBinaryDataAttributeType optional:YES]];
    
    // TagData Entity
    NSEntityDescription *tagEntity = [[NSEntityDescription alloc] init];
    tagEntity.name = @"TagData";
    tagEntity.managedObjectClassName = @"TagData";
    
    NSMutableArray *tagProperties = [NSMutableArray array];
    [tagProperties addObject:[self attributeWithName:@"name" type:NSStringAttributeType]];
    [tagProperties addObject:[self attributeWithName:@"colorHex" type:NSStringAttributeType optional:YES]];
    [tagProperties addObject:[self attributeWithName:@"dateCreated" type:NSDateAttributeType]];
    
    // Altre entities...
    [self setupOtherEntities:model];
    
    // Relazioni
    NSRelationshipDescription *symbolTagsRelation = [[NSRelationshipDescription alloc] init];
    symbolTagsRelation.name = @"tags";
    symbolTagsRelation.destinationEntity = tagEntity;
    symbolTagsRelation.deleteRule = NSNullifyDeleteRule;
    symbolTagsRelation.minCount = 0;
    symbolTagsRelation.maxCount = 0; // to-many
    
    NSRelationshipDescription *tagSymbolsRelation = [[NSRelationshipDescription alloc] init];
    tagSymbolsRelation.name = @"symbols";
    tagSymbolsRelation.destinationEntity = symbolEntity;
    tagSymbolsRelation.deleteRule = NSNullifyDeleteRule;
    tagSymbolsRelation.minCount = 0;
    tagSymbolsRelation.maxCount = 0; // to-many
    
    symbolTagsRelation.inverseRelationship = tagSymbolsRelation;
    tagSymbolsRelation.inverseRelationship = symbolTagsRelation;
    
    [symbolProperties addObject:symbolTagsRelation];
    [tagProperties addObject:tagSymbolsRelation];
    
    symbolEntity.properties = symbolProperties;
    tagEntity.properties = tagProperties;
    
    model.entities = @[symbolEntity, tagEntity];
    
    return model;
}

- (NSAttributeDescription *)attributeWithName:(NSString *)name type:(NSAttributeType)type optional:(BOOL)optional {
    NSAttributeDescription *attribute = [[NSAttributeDescription alloc] init];
    attribute.name = name;
    attribute.attributeType = type;
    attribute.optional = optional;
    return attribute;
}

- (NSAttributeDescription *)attributeWithName:(NSString *)name type:(NSAttributeType)type {
    return [self attributeWithName:name type:type optional:NO];
}

- (void)setupOtherEntities:(NSManagedObjectModel *)model {
    NSMutableArray *allEntities = [NSMutableArray arrayWithArray:model.entities];
    
    // WatchlistDataModel Entity
    NSEntityDescription *watchlistEntity = [[NSEntityDescription alloc] init];
    watchlistEntity.name = @"WatchlistDataModel";
    watchlistEntity.managedObjectClassName = @"WatchlistDataModel";
    
    NSMutableArray *watchlistProperties = [NSMutableArray array];
    [watchlistProperties addObject:[self attributeWithName:@"name" type:NSStringAttributeType]];
    [watchlistProperties addObject:[self attributeWithName:@"watchlistId" type:NSStringAttributeType]];
    [watchlistProperties addObject:[self attributeWithName:@"dateCreated" type:NSDateAttributeType]];
    [watchlistProperties addObject:[self attributeWithName:@"lastModified" type:NSDateAttributeType]];
    [watchlistProperties addObject:[self attributeWithName:@"isDynamic" type:NSBooleanAttributeType]];
    [watchlistProperties addObject:[self attributeWithName:@"dynamicTag" type:NSStringAttributeType optional:YES]];
    [watchlistProperties addObject:[self attributeWithName:@"sortOrder" type:NSInteger64AttributeType]];
    
    // Relazione con SymbolData
    NSEntityDescription *symbolEntity = [model entitiesByName][@"SymbolData"];
    
    NSRelationshipDescription *watchlistSymbolsRelation = [[NSRelationshipDescription alloc] init];
    watchlistSymbolsRelation.name = @"symbols";
    watchlistSymbolsRelation.destinationEntity = symbolEntity;
    watchlistSymbolsRelation.deleteRule = NSNullifyDeleteRule;
    watchlistSymbolsRelation.minCount = 0;
    watchlistSymbolsRelation.maxCount = 0; // to-many
    
    NSRelationshipDescription *symbolWatchlistsRelation = [[NSRelationshipDescription alloc] init];
    symbolWatchlistsRelation.name = @"watchlists";
    symbolWatchlistsRelation.destinationEntity = watchlistEntity;
    symbolWatchlistsRelation.deleteRule = NSNullifyDeleteRule;
    symbolWatchlistsRelation.minCount = 0;
    symbolWatchlistsRelation.maxCount = 0; // to-many
    
    watchlistSymbolsRelation.inverseRelationship = symbolWatchlistsRelation;
    symbolWatchlistsRelation.inverseRelationship = watchlistSymbolsRelation;
    
    [watchlistProperties addObject:watchlistSymbolsRelation];
    
    // Aggiungi la relazione anche a SymbolData
    NSMutableArray *symbolProperties = [symbolEntity.properties mutableCopy];
    [symbolProperties addObject:symbolWatchlistsRelation];
    symbolEntity.properties = symbolProperties;
    
    watchlistEntity.properties = watchlistProperties;
    [allEntities addObject:watchlistEntity];
    
    // Aggiungi altre entities (AlertData, NoteData, etc.)
    // ... codice per altre entities ...
    
    model.entities = allEntities;
}

#pragma mark - Symbol Management

- (SymbolData *)dataForSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"SymbolData"];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol.uppercaseString];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error fetching symbol data: %@", error);
        return nil;
    }
    
    SymbolData *symbolData = results.firstObject;
    
    if (!symbolData) {
        // Crea nuovo simbolo
        symbolData = [NSEntityDescription insertNewObjectForEntityForName:@"SymbolData"
                                                  inManagedObjectContext:self.mainContext];
        symbolData.symbol = symbol.uppercaseString;
        symbolData.dateAdded = [NSDate date];
        symbolData.lastModified = [NSDate date];
        
        [self saveContext];
        
        // Notifica aggiunta nuovo simbolo
        [self postNotificationName:kSymbolDataAddedNotification
                            symbol:symbol.uppercaseString
                        updateType:SymbolUpdateTypeAll
                          oldValue:nil
                          newValue:symbolData];
    }
    
    return symbolData;
}

- (BOOL)hasDataForSymbol:(NSString *)symbol {
    if (!symbol) return NO;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"SymbolData"];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol.uppercaseString];
    request.resultType = NSCountResultType;
    
    NSError *error;
    NSUInteger count = [self.mainContext countForFetchRequest:request error:&error];
    
    return count > 0;
}

- (void)removeDataForSymbol:(NSString *)symbol {
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (symbolData) {
        [self.mainContext deleteObject:symbolData];
        [self saveContext];
        
        [self postNotificationName:kSymbolDataRemovedNotification
                            symbol:symbol
                        updateType:SymbolUpdateTypeAll
                          oldValue:symbolData
                          newValue:nil];
    }
}

- (NSArray<NSString *> *)allSymbols {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"SymbolData"];
    request.propertiesToFetch = @[@"symbol"];
    request.resultType = NSDictionaryResultType;
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"symbol" ascending:YES]];
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error fetching all symbols: %@", error);
        return @[];
    }
    
    return [results valueForKey:@"symbol"];
}

#pragma mark - Tags

- (void)addTag:(NSString *)tag toSymbol:(NSString *)symbol {
    if (!tag || !symbol) return;
    
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return;
    
    // Cerca o crea tag
    TagData *tagData = [self findOrCreateTag:tag];
    
    NSSet *oldTags = [symbolData.tags copy];
    [symbolData addTag:tagData];
    symbolData.lastModified = [NSDate date];
    
    [self saveContext];
    
    [self postNotificationName:kSymbolDataUpdatedNotification
                        symbol:symbol
                    updateType:SymbolUpdateTypeTags
                      oldValue:oldTags
                      newValue:symbolData.tags];
    [self updateDynamicWatchlists];

}

- (TagData *)findOrCreateTag:(NSString *)tagName {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TagData"];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@", tagName.lowercaseString];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    TagData *tagData = results.firstObject;
    
    if (!tagData) {
        tagData = [NSEntityDescription insertNewObjectForEntityForName:@"TagData"
                                               inManagedObjectContext:self.mainContext];
        tagData.name = tagName.lowercaseString;
        tagData.dateCreated = [NSDate date];
        
        // Genera colore casuale per il tag
        tagData.colorHex = [self generateRandomColorHex];
    }
    
    return tagData;
}

- (NSString *)generateRandomColorHex {
    // Genera colori vivaci evitando toni troppo scuri o chiari
    CGFloat hue = arc4random_uniform(360) / 360.0;
    CGFloat saturation = 0.5 + (arc4random_uniform(50) / 100.0); // 0.5-1.0
    CGFloat brightness = 0.5 + (arc4random_uniform(50) / 100.0); // 0.5-1.0
    
    NSColor *color = [NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];
    
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)(color.redComponent * 255),
            (int)(color.greenComponent * 255),
            (int)(color.blueComponent * 255)];
}

- (void)removeTag:(NSString *)tag fromSymbol:(NSString *)symbol {
    if (!tag || !symbol) return;
    
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return;
    
    TagData *tagToRemove = nil;
    for (TagData *tagData in symbolData.tags) {
        if ([tagData.name isEqualToString:tag.lowercaseString]) {
            tagToRemove = tagData;
            break;
        }
    }
    
    if (tagToRemove) {
        NSSet *oldTags = [symbolData.tags copy];
        [symbolData removeTag:tagToRemove];
        symbolData.lastModified = [NSDate date];
        
        [self saveContext];
        
        [self postNotificationName:kSymbolDataUpdatedNotification
                            symbol:symbol
                        updateType:SymbolUpdateTypeTags
                          oldValue:oldTags
                          newValue:symbolData.tags];
    }
    [self updateDynamicWatchlists];

}

- (NSArray<NSString *> *)tagsForSymbol:(NSString *)symbol {
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return @[];
    
    return [symbolData tagNames];
}

- (NSArray<NSString *> *)symbolsWithTag:(NSString *)tag {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TagData"];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@", tag.lowercaseString];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    TagData *tagData = results.firstObject;
    if (!tagData) return @[];
    
    NSMutableArray *symbols = [NSMutableArray array];
    for (SymbolData *symbolData in tagData.symbols) {
        [symbols addObject:symbolData.symbol];
    }
    
    return [symbols sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSString *> *)allAvailableTags {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"TagData"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error fetching tags: %@", error);
        return @[];
    }
    
    return [results valueForKey:@"name"];
}

#pragma mark - Notes

- (void)setNote:(NSString *)note forSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return;
    
    // Trova nota principale esistente
    NoteData *mainNote = nil;
    for (NoteData *noteData in symbolData.notes) {
        if (!noteData.author || [noteData.author isEqualToString:@"main"]) {
            mainNote = noteData;
            break;
        }
    }
    
    if (!mainNote && note.length > 0) {
        mainNote = [NSEntityDescription insertNewObjectForEntityForName:@"NoteData"
                                               inManagedObjectContext:self.mainContext];
        mainNote.author = @"main";
        mainNote.symbol = symbolData;
    }
    
    if (mainNote) {
        NSString *oldContent = mainNote.content;
        mainNote.content = note;
        mainNote.timestamp = [NSDate date];
        symbolData.lastModified = [NSDate date];
        
        [self saveContext];
        
        [self postNotificationName:kSymbolDataUpdatedNotification
                            symbol:symbol
                        updateType:SymbolUpdateTypeNotes
                          oldValue:oldContent
                          newValue:note];
    }
}

- (NSString *)noteForSymbol:(NSString *)symbol {
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return nil;
    
    for (NoteData *noteData in symbolData.notes) {
        if (!noteData.author || [noteData.author isEqualToString:@"main"]) {
            return noteData.content;
        }
    }
    
    return nil;
}

- (void)addTimestampedNote:(NSString *)note toSymbol:(NSString *)symbol {
    if (!note || !symbol) return;
    
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return;
    
    NoteData *noteData = [NSEntityDescription insertNewObjectForEntityForName:@"NoteData"
                                                      inManagedObjectContext:self.mainContext];
    noteData.content = note;
    noteData.timestamp = [NSDate date];
    noteData.author = NSUserName();
    noteData.symbol = symbolData;
    
    symbolData.lastModified = [NSDate date];
    
    [self saveContext];
    
    [self postNotificationName:kSymbolDataUpdatedNotification
                        symbol:symbol
                    updateType:SymbolUpdateTypeNotes
                      oldValue:nil
                      newValue:noteData];
}

#pragma mark - Alerts

- (AlertData *)addAlertForSymbol:(NSString *)symbol
                           type:(NSString *)type
                      condition:(NSDictionary *)condition {
    if (!symbol || !type || !condition) return nil;
    
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return nil;
    
    AlertData *alert = [NSEntityDescription insertNewObjectForEntityForName:@"AlertData"
                                                   inManagedObjectContext:self.mainContext];
    
    alert.alertId = [[NSUUID UUID] UUIDString];
    alert.type = [self alertTypeFromString:type];
    alert.conditions = condition;
    alert.status = AlertStatusActive;
    alert.dateCreated = [NSDate date];
    alert.symbol = symbolData;
    
    symbolData.lastModified = [NSDate date];
    
    [self saveContext];
    
    [self postNotificationName:kSymbolDataUpdatedNotification
                        symbol:symbol
                    updateType:SymbolUpdateTypeAlerts
                      oldValue:nil
                      newValue:alert];
    
    return alert;
}

- (AlertType)alertTypeFromString:(NSString *)typeString {
    NSDictionary *typeMap = @{
        @"priceAbove": @(AlertTypePriceAbove),
        @"priceBelow": @(AlertTypePriceBelow),
        @"volumeAbove": @(AlertTypeVolumeAbove),
        @"percentChange": @(AlertTypePercentChange),
        @"technical": @(AlertTypeTechnicalIndicator),
        @"pattern": @(AlertTypePattern),
        @"custom": @(AlertTypeCustom)
    };
    
    NSNumber *type = typeMap[typeString];
    return type ? type.integerValue : AlertTypeCustom;
}

- (void)removeAlert:(AlertData *)alert {
    if (!alert) return;
    
    NSString *symbol = alert.symbol.symbol;
    [self.mainContext deleteObject:alert];
    
    [self saveContext];
    
    [self postNotificationName:kSymbolDataUpdatedNotification
                        symbol:symbol
                    updateType:SymbolUpdateTypeAlerts
                      oldValue:alert
                      newValue:nil];
}

- (NSArray<AlertData *> *)alertsForSymbol:(NSString *)symbol {
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return @[];
    
    return [[symbolData.alerts allObjects] sortedArrayUsingDescriptors:
            @[[NSSortDescriptor sortDescriptorWithKey:@"dateCreated" ascending:NO]]];
}

- (NSArray<AlertData *> *)allActiveAlerts {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AlertData"];
    request.predicate = [NSPredicate predicateWithFormat:@"status == %d", AlertStatusActive];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"dateCreated" ascending:NO]];
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error fetching active alerts: %@", error);
        return @[];
    }
    
    return results;
}

- (void)updateAlertStatus:(AlertData *)alert triggered:(BOOL)triggered {
    if (!alert) return;
    
    AlertStatus oldStatus = alert.status;
    
    if (triggered) {
        alert.status = AlertStatusTriggered;
        alert.dateTriggered = [NSDate date];
        
        // Post notification for triggered alert
        [[NSNotificationCenter defaultCenter] postNotificationName:kAlertTriggeredNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"alert": alert,
                                                              @"symbol": alert.symbol.symbol
                                                          }];
    } else {
        alert.status = AlertStatusActive;
    }
    
    [self saveContext];
    
    [self postNotificationName:kSymbolDataUpdatedNotification
                        symbol:alert.symbol.symbol
                    updateType:SymbolUpdateTypeAlerts
                      oldValue:@(oldStatus)
                      newValue:@(alert.status)];
}

#pragma mark - Trading Configuration

- (void)setTradingConfig:(TradingConfigData *)config forSymbol:(NSString *)symbol {
    if (!config || !symbol) return;
    
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return;
    
    TradingConfigData *oldConfig = symbolData.tradingConfig;
    symbolData.tradingConfig = config;
    symbolData.lastModified = [NSDate date];
    
    [self saveContext];
    
    [self postNotificationName:kSymbolDataUpdatedNotification
                        symbol:symbol
                    updateType:SymbolUpdateTypeConfig
                      oldValue:oldConfig
                      newValue:config];
}

- (TradingConfigData *)tradingConfigForSymbol:(NSString *)symbol {
    SymbolData *symbolData = [self dataForSymbol:symbol];
    return symbolData.tradingConfig;
}

#pragma mark - Custom Data

- (void)setCustomData:(id<DataPersistable>)data
              forKey:(NSString *)key
           forSymbol:(NSString *)symbol {
    if (!data || !key || !symbol) return;
    
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData) return;
    
    // Deserializza dati custom esistenti
    NSMutableDictionary *customDict = [NSMutableDictionary dictionary];
    if (symbolData.customData) {
        NSDictionary *existing = [NSJSONSerialization JSONObjectWithData:symbolData.customData
                                                                options:0
                                                                  error:nil];
        if (existing) {
            customDict = [existing mutableCopy];
        }
    }
    
    // Aggiungi nuovi dati
    customDict[key] = [data serialize];
    
    // Serializza di nuovo
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:customDict
                                                       options:0
                                                         error:&error];
    
    if (!error) {
        symbolData.customData = jsonData;
        symbolData.lastModified = [NSDate date];
        
        [self saveContext];
        
        [self postNotificationName:kSymbolDataUpdatedNotification
                            symbol:symbol
                        updateType:SymbolUpdateTypeCustomData
                          oldValue:nil
                          newValue:data];
    }
}

- (id)customDataForKey:(NSString *)key
            forSymbol:(NSString *)symbol
                class:(Class)dataClass {
    if (!key || !symbol) return nil;
    
    SymbolData *symbolData = [self dataForSymbol:symbol];
    if (!symbolData || !symbolData.customData) return nil;
    
    NSDictionary *customDict = [NSJSONSerialization JSONObjectWithData:symbolData.customData
                                                              options:0
                                                                error:nil];
    
    NSDictionary *dataDict = customDict[key];
    if (!dataDict) return nil;
    
    if ([dataClass conformsToProtocol:@protocol(DataPersistable)]) {
        return [[dataClass alloc] initWithDictionary:dataDict];
    }
    
    return nil;
}

#pragma mark - Search

- (void)searchSymbolsWithQuery:(NSString *)query
                   completion:(SymbolSearchCompletionBlock)completion {
    if (!query || query.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"SymbolData"];
        
        // Cerca nei simboli, nomi completi e tags
        NSPredicate *symbolPredicate = [NSPredicate predicateWithFormat:@"symbol CONTAINS[cd] %@", query];
        NSPredicate *namePredicate = [NSPredicate predicateWithFormat:@"fullName CONTAINS[cd] %@", query];
        NSPredicate *tagPredicate = [NSPredicate predicateWithFormat:@"ANY tags.name CONTAINS[cd] %@", query];
        
        request.predicate = [NSCompoundPredicate orPredicateWithSubpredicates:
                           @[symbolPredicate, namePredicate, tagPredicate]];
        
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"symbol" ascending:YES]];
        
        NSError *error;
        NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(results, error);
            }
        });
    });
}

#pragma mark - Persistence

- (void)saveContext {
    dispatch_async(self.saveQueue, ^{
        NSError *error = nil;
        NSManagedObjectContext *context = self.mainContext;
        
        if ([context hasChanges] && ![context save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, error.userInfo);
        }
    });
}

- (void)forceSave {
    dispatch_sync(self.saveQueue, ^{
        NSError *error = nil;
        if ([self.mainContext hasChanges] && ![self.mainContext save:&error]) {
            NSLog(@"Force save failed: %@", error);
        }
    });
}

- (BOOL)exportDatabaseToPath:(NSString *)path error:(NSError **)error {
    // Implementazione export database
    // Potrebbe essere JSON, plist, o backup del file SQLite
    
    NSMutableDictionary *exportData = [NSMutableDictionary dictionary];
    
    // Esporta tutti i simboli
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"SymbolData"];
    NSArray *allSymbols = [self.mainContext executeFetchRequest:request error:error];
    
    if (*error) return NO;
    
    NSMutableArray *symbolsArray = [NSMutableArray array];
    for (SymbolData *symbol in allSymbols) {
        [symbolsArray addObject:[self serializeSymbolData:symbol]];
    }
    
    exportData[@"symbols"] = symbolsArray;
    exportData[@"exportDate"] = [NSDate date];
    exportData[@"version"] = @"1.0";
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:error];
    
    if (*error) return NO;
    
    return [jsonData writeToFile:path atomically:YES];
}

- (NSDictionary *)serializeSymbolData:(SymbolData *)symbolData {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"symbol"] = symbolData.symbol;
    if (symbolData.fullName) dict[@"fullName"] = symbolData.fullName;
    if (symbolData.exchange) dict[@"exchange"] = symbolData.exchange;
    dict[@"dateAdded"] = symbolData.dateAdded;
    dict[@"lastModified"] = symbolData.lastModified;
    
    // Tags
    dict[@"tags"] = [symbolData tagNames];
    
    // Notes
    NSMutableArray *notes = [NSMutableArray array];
    for (NoteData *note in symbolData.notes) {
        [notes addObject:[note serialize]];
    }
    dict[@"notes"] = notes;
    
    // Alerts
    NSMutableArray *alerts = [NSMutableArray array];
    for (AlertData *alert in symbolData.alerts) {
        [alerts addObject:[alert serialize]];
    }
    dict[@"alerts"] = alerts;
    
    // Custom data
    if (symbolData.customData) {
        NSDictionary *custom = [NSJSONSerialization JSONObjectWithData:symbolData.customData
                                                              options:0
                                                                error:nil];
        if (custom) dict[@"customData"] = custom;
    }
    
    return dict;
}

#pragma mark - Notifications

- (void)observeSymbol:(NSString *)symbol
             observer:(id)observer
             selector:(SEL)selector {
    if (!symbol || !observer) return;
    
    NSString *key = symbol ?: @"__all__";
    
    if (!self.observers[key]) {
        self.observers[key] = [NSMutableSet set];
    }
    
    [self.observers[key] addObject:observer];
    
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:selector
                                                 name:kSymbolDataUpdatedNotification
                                               object:self];
}

- (void)removeObserver:(id)observer forSymbol:(NSString *)symbol {
    if (!observer) return;
    
    if (symbol) {
        [self.observers[symbol] removeObject:observer];
    } else {
        // Rimuovi da tutti
        for (NSMutableSet *observerSet in self.observers.allValues) {
            [observerSet removeObject:observer];
        }
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:observer
                                                    name:kSymbolDataUpdatedNotification
                                                  object:self];
}

- (void)postNotificationName:(NSString *)notificationName
                      symbol:(NSString *)symbol
                  updateType:(SymbolUpdateType)updateType
                    oldValue:(id)oldValue
                    newValue:(id)newValue {
    
    NSDictionary *userInfo = @{
        kSymbolKey: symbol ?: @"",
        kUpdateTypeKey: @(updateType),
        kOldValueKey: oldValue ?: [NSNull null],
        kNewValueKey: newValue ?: [NSNull null]
    };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                        object:self
                                                      userInfo:userInfo];
}

#pragma mark - Watchlist Management

- (WatchlistDataModel *)createWatchlistWithName:(NSString *)name {
    if (!name || name.length == 0) return nil;
    
    // Verifica se esiste già
    WatchlistDataModel *existing = [self watchlistWithName:name];
    if (existing) {
        return existing;
    }
    
    WatchlistDataModel *watchlist = [NSEntityDescription insertNewObjectForEntityForName:@"WatchlistDataModel"
                                                                  inManagedObjectContext:self.mainContext];
    watchlist.name = name;
    watchlist.watchlistId = [[NSUUID UUID] UUIDString];
    watchlist.dateCreated = [NSDate date];
    watchlist.lastModified = [NSDate date];
    watchlist.isDynamic = NO;
    
    // Assegna sortOrder
    NSArray *allWatchlists = [self allWatchlists];
    watchlist.sortOrder = allWatchlists.count;
    
    [self saveContext];
    
    // Notifica
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchlistsUpdatedNotification"
                                                        object:self
                                                      userInfo:@{@"watchlist": watchlist, @"action": @"created"}];
    
    return watchlist;
}

- (WatchlistDataModel *)createDynamicWatchlistWithName:(NSString *)name forTag:(NSString *)tag {
    if (!name || !tag) return nil;
    
    WatchlistDataModel *watchlist = [self createWatchlistWithName:name];
    if (watchlist) {
        watchlist.isDynamic = YES;
        watchlist.dynamicTag = tag;
        
        // Popola con simboli che hanno questo tag
        [self updateDynamicWatchlist:watchlist];
        
        [self saveContext];
    }
    
    return watchlist;
}

- (NSArray<WatchlistDataModel *> *)allWatchlists {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"WatchlistDataModel"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES]];
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Error fetching watchlists: %@", error);
        return @[];
    }
    
    return results;
}

- (WatchlistDataModel *)watchlistWithName:(NSString *)name {
    if (!name) return nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"WatchlistDataModel"];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    return results.firstObject;
}

- (void)deleteWatchlist:(WatchlistDataModel *)watchlist {
    if (!watchlist) return;
    
    NSString *name = watchlist.name;
    [self.mainContext deleteObject:watchlist];
    [self saveContext];
    
    // Notifica
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchlistsUpdatedNotification"
                                                        object:self
                                                      userInfo:@{@"watchlistName": name, @"action": @"deleted"}];
}

- (void)addSymbol:(NSString *)symbol toWatchlist:(WatchlistDataModel *)watchlist {
    if (!symbol || !watchlist || watchlist.isDynamic) return;
    
    [watchlist addSymbol:symbol];
    [self saveContext];
    
    // Notifica
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchlistsUpdatedNotification"
                                                        object:self
                                                      userInfo:@{@"watchlist": watchlist, @"action": @"symbolAdded", @"symbol": symbol}];
}

- (void)removeSymbol:(NSString *)symbol fromWatchlist:(WatchlistDataModel *)watchlist {
    if (!symbol || !watchlist || watchlist.isDynamic) return;
    
    [watchlist removeSymbol:symbol];
    [self saveContext];
    
    // Notifica
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchlistsUpdatedNotification"
                                                        object:self
                                                      userInfo:@{@"watchlist": watchlist, @"action": @"symbolRemoved", @"symbol": symbol}];
}

- (void)updateDynamicWatchlists {
    NSArray<WatchlistDataModel *> *allWatchlists = [self allWatchlists];
    
    for (WatchlistDataModel *watchlist in allWatchlists) {
        if (watchlist.isDynamic && watchlist.dynamicTag) {
            [self updateDynamicWatchlist:watchlist];
        }
    }
    
    [self saveContext];
}

- (void)updateDynamicWatchlist:(WatchlistDataModel *)watchlist {
    if (!watchlist.isDynamic || !watchlist.dynamicTag) return;
    
    // Ottieni tutti i simboli con questo tag
    NSArray<NSString *> *symbolsWithTag = [self symbolsWithTag:watchlist.dynamicTag];
    
    // Rimuovi tutti i simboli esistenti
    [watchlist.symbols removeAllObjects];
    
    // Aggiungi i nuovi
    for (NSString *symbolName in symbolsWithTag) {
        [watchlist addSymbol:symbolName];
    }
    
    watchlist.lastModified = [NSDate date];
}


@end
