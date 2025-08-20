//
//  DataHub+ChartObjects.m
//  TradingApp
//

#import "DataHub+ChartObjects.h"
#import "ChartLayer+CoreDataClass.h"
#import "ChartObject+CoreDataClass.h"
#import "Symbol+CoreDataClass.h"

@implementation DataHub (ChartObjects)

#pragma mark - Chart Layers Management

- (NSArray<ChartLayerModel *> *)getChartLayersForSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return @[];
    
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    if (!symbolEntity) return @[];
    
    NSMutableArray<ChartLayerModel *> *layerModels = [NSMutableArray array];
    
    // Sort layers by orderIndex
    NSSortDescriptor *orderSort = [NSSortDescriptor sortDescriptorWithKey:@"orderIndex" ascending:YES];
    NSArray *sortedLayers = [symbolEntity.chartLayers sortedArrayUsingDescriptors:@[orderSort]];
    
    for (ChartLayer *coreDataLayer in sortedLayers) {
        ChartLayerModel *layerModel = [self layerModelFromCoreData:coreDataLayer];
        [layerModels addObject:layerModel];
    }
    
    NSLog(@"📊 DataHub: Loaded %lu chart layers for symbol %@", (unsigned long)layerModels.count, symbol);
    return [layerModels copy];
}

- (ChartLayerModel *)createChartLayerForSymbol:(NSString *)symbol name:(NSString *)name {
    Symbol *symbolEntity = [self createSymbolWithName:symbol]; // Creates or gets existing
    
    ChartLayer *coreDataLayer = [NSEntityDescription insertNewObjectForEntityForName:@"ChartLayer"
                                                              inManagedObjectContext:self.mainContext];
    coreDataLayer.layerID = [[NSUUID UUID] UUIDString];
    coreDataLayer.name = name;
    coreDataLayer.isVisible = YES;
    coreDataLayer.orderIndex = (int16_t)[symbolEntity.chartLayers count]; // Add at end
    coreDataLayer.creationDate = [NSDate date];
    coreDataLayer.symbol = symbolEntity;
    
    [self saveContext];
    
    ChartLayerModel *layerModel = [self layerModelFromCoreData:coreDataLayer];
    
    NSLog(@"✅ DataHub: Created chart layer '%@' for symbol %@", name, symbol);
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartLayerCreated"
                                                        object:self
                                                      userInfo:@{@"symbol": symbol, @"layer": layerModel}];
    
    return layerModel;
}

- (void)saveChartLayer:(ChartLayerModel *)layer forSymbol:(NSString *)symbol {
    if (!layer || !symbol) return;
    
    // Find existing or create new
    ChartLayer *coreDataLayer = [self findChartLayerWithID:layer.layerID];
    if (!coreDataLayer) {
        Symbol *symbolEntity = [self createSymbolWithName:symbol];
        coreDataLayer = [NSEntityDescription insertNewObjectForEntityForName:@"ChartLayer"
                                                      inManagedObjectContext:self.mainContext];
        coreDataLayer.layerID = layer.layerID;
        coreDataLayer.symbol = symbolEntity;
    }
    
    // Update properties
    coreDataLayer.name = layer.name;
    coreDataLayer.isVisible = layer.isVisible;
    coreDataLayer.orderIndex = (int16_t)layer.orderIndex;
    coreDataLayer.lastModified = [NSDate date];
    if (!coreDataLayer.creationDate) {
        coreDataLayer.creationDate = layer.creationDate ?: [NSDate date];
    }
    [self saveContext];
    
    NSLog(@"💾 DataHub: Saved chart layer %@ for symbol %@", layer.name, symbol);
}

- (void)deleteChartLayerWithID:(NSString *)layerID {
    ChartLayer *coreDataLayer = [self findChartLayerWithID:layerID];
    if (!coreDataLayer) return;
    
    NSString *layerName = coreDataLayer.name;
    NSString *symbol = coreDataLayer.symbol.symbol;
    
    [self.mainContext deleteObject:coreDataLayer];
    [self saveContext];
    
    NSLog(@"🗑️ DataHub: Deleted chart layer %@ for symbol %@", layerName, symbol);
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartLayerDeleted"
                                                        object:self
                                                      userInfo:@{@"symbol": symbol, @"layerID": layerID}];
}

- (void)updateChartLayer:(NSString *)layerID visible:(BOOL)isVisible orderIndex:(NSInteger)orderIndex {
    ChartLayer *coreDataLayer = [self findChartLayerWithID:layerID];
    if (!coreDataLayer) return;
    
    coreDataLayer.isVisible = isVisible;
    coreDataLayer.orderIndex = (int16_t)orderIndex;
    coreDataLayer.lastModified = [NSDate date];
    
    [self saveContext];
    
    NSLog(@"🔄 DataHub: Updated chart layer %@ - visible:%@ order:%ld",
          layerID, isVisible ? @"YES" : @"NO", (long)orderIndex);
}

#pragma mark - Chart Objects Management

- (void)saveChartObject:(ChartObjectModel *)object toLayerID:(NSString *)layerID {
    if (!object || !layerID) return;
    
    ChartLayer *layer = [self findChartLayerWithID:layerID];
    if (!layer) {
        NSLog(@"❌ DataHub: Cannot save object - layer %@ not found", layerID);
        return;
    }
    
    // Find existing or create new
    ChartObject *coreDataObject = [self findChartObjectWithID:object.objectID];
    if (!coreDataObject) {
        coreDataObject = [NSEntityDescription insertNewObjectForEntityForName:@"ChartObject"
                                                       inManagedObjectContext:self.mainContext];
        coreDataObject.objectUUID = object.objectID;
        coreDataObject.creationDate = object.creationDate ?: [NSDate date];
    }
    
    // Update properties
    coreDataObject.name = object.name;
    coreDataObject.type = (int16_t)object.type;
    coreDataObject.isVisible = object.isVisible;
    coreDataObject.isLocked = object.isLocked;
    coreDataObject.lastModified = [NSDate date];
    coreDataObject.layer = layer;
    
    // Serialize control points
    NSMutableArray *controlPointsData = [NSMutableArray array];
    for (ControlPointModel *point in object.controlPoints) {
        [controlPointsData addObject:[point toDictionary]];
    }
    coreDataObject.controlPointsData = [controlPointsData copy];
    
    // Serialize style
    coreDataObject.styleData = [object.style toDictionary];
    
    // Custom properties
    coreDataObject.customProperties = object.customProperties;
    
    [self saveContext];
    
    NSLog(@"💾 DataHub: Saved chart object %@ to layer %@", object.name, layerID);
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartObjectSaved"
                                                        object:self
                                                      userInfo:@{@"object": object, @"layerID": layerID}];
}

- (void)deleteChartObjectWithID:(NSString *)objectID {
    ChartObject *coreDataObject = [self findChartObjectWithID:objectID];
    if (!coreDataObject) return;
    
    NSString *objectName = coreDataObject.name;
    NSString *layerID = coreDataObject.layer.layerID;
    
    [self.mainContext deleteObject:coreDataObject];
    [self saveContext];
    
    NSLog(@"🗑️ DataHub: Deleted chart object %@", objectName);
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartObjectDeleted"
                                                        object:self
                                                      userInfo:@{@"objectID": objectID, @"layerID": layerID}];
}

- (void)moveChartObject:(NSString *)objectID toLayerID:(NSString *)targetLayerID {
    ChartObject *coreDataObject = [self findChartObjectWithID:objectID];
    ChartLayer *targetLayer = [self findChartLayerWithID:targetLayerID];
    
    if (!coreDataObject || !targetLayer) return;
    
    NSString *oldLayerID = coreDataObject.layer.layerID;
    coreDataObject.layer = targetLayer;
    coreDataObject.lastModified = [NSDate date];
    
    [self saveContext];
    
    NSLog(@"🔄 DataHub: Moved object %@ from layer %@ to %@", objectID, oldLayerID, targetLayerID);
}

- (void)updateChartObject:(NSString *)objectID visible:(BOOL)isVisible locked:(BOOL)isLocked {
    ChartObject *coreDataObject = [self findChartObjectWithID:objectID];
    if (!coreDataObject) return;
    
    coreDataObject.isVisible = isVisible;
    coreDataObject.isLocked = isLocked;
    coreDataObject.lastModified = [NSDate date];
    
    [self saveContext];
    
    NSLog(@"🔄 DataHub: Updated object %@ - visible:%@ locked:%@",
          objectID, isVisible ? @"YES" : @"NO", isLocked ? @"YES" : @"NO");
}

#pragma mark - Bulk Operations

- (void)loadChartObjectsForSymbol:(NSString *)symbol completion:(void(^)(NSArray<ChartLayerModel *> *layers))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<ChartLayerModel *> *layers = [self getChartLayersForSymbol:symbol];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(layers);
        });
    });
}

// ✅ CORREZIONE: Modifica del metodo saveChartObjects in DataHub+ChartObjects.m
// Aggiunge logica per rimuovere oggetti orfani da CoreData

- (void)saveChartObjects:(NSArray<ChartLayerModel *> *)layers forSymbol:(NSString *)symbol {
    // ✅ STEP 1: Ottieni tutti gli oggetti esistenti in CoreData per questo symbol
    NSMutableSet<NSString *> *existingObjectIDs = [NSMutableSet set];
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    if (symbolEntity) {
        for (ChartLayer *layer in symbolEntity.chartLayers) {
            for (ChartObject *object in layer.objects) {
                [existingObjectIDs addObject:object.objectUUID];
            }
        }
    }
    
    // ✅ STEP 2: Salva tutti i layer e oggetti attuali
    NSMutableSet<NSString *> *currentObjectIDs = [NSMutableSet set];
    for (ChartLayerModel *layer in layers) {
        [self saveChartLayer:layer forSymbol:symbol];
        
        for (ChartObjectModel *object in layer.objects) {
            [self saveChartObject:object toLayerID:layer.layerID];
            [currentObjectIDs addObject:object.objectID];
        }
    }
    
    // ✅ STEP 3: Identifica e rimuovi oggetti orfani
    NSMutableSet<NSString *> *orphanedObjectIDs = [existingObjectIDs mutableCopy];
    [orphanedObjectIDs minusSet:currentObjectIDs]; // Rimuovi quelli che esistono ancora
    
    NSUInteger orphanedCount = orphanedObjectIDs.count;
    if (orphanedCount > 0) {
        NSLog(@"🧹 DataHub: Found %lu orphaned objects to delete for symbol %@",
              (unsigned long)orphanedCount, symbol);
        
        // Rimuovi ogni oggetto orfano
        for (NSString *orphanedID in orphanedObjectIDs) {
            [self deleteChartObjectWithID:orphanedID];
        }
        
        NSLog(@"✅ DataHub: Cleaned up %lu orphaned objects", (unsigned long)orphanedCount);
    }
    
    NSLog(@"💾 DataHub: Bulk saved %lu layers with %lu total objects for symbol %@",
          (unsigned long)layers.count, (unsigned long)currentObjectIDs.count, symbol);
}

- (void)clearChartObjectsForSymbol:(NSString *)symbol {
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    if (!symbolEntity) return;
    
    NSUInteger deletedCount = 0;
    for (ChartLayer *layer in [symbolEntity.chartLayers copy]) {
        deletedCount += layer.objects.count;
        [self.mainContext deleteObject:layer];
    }
    
    [self saveContext];
    
    NSLog(@"🗑️ DataHub: Cleared %lu chart objects for symbol %@", (unsigned long)deletedCount, symbol);
}

#pragma mark - Statistics and Utilities

- (NSUInteger)getChartObjectsCountForSymbol:(NSString *)symbol {
    Symbol *symbolEntity = [self getSymbolWithName:symbol];
    if (!symbolEntity) return 0;
    
    NSUInteger totalCount = 0;
    for (ChartLayer *layer in symbolEntity.chartLayers) {
        totalCount += layer.objects.count;
    }
    
    return totalCount;
}

- (NSArray<NSString *> *)getSymbolsWithChartObjects {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Symbol"];
    request.predicate = [NSPredicate predicateWithFormat:@"chartLayers.@count > 0"];
    
    NSError *error;
    NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error fetching symbols with chart objects: %@", error);
        return @[];
    }
    
    NSMutableArray<NSString *> *symbolNames = [NSMutableArray array];
    for (Symbol *symbol in symbols) {
        [symbolNames addObject:symbol.symbol];
    }
    
    return [symbolNames copy];
}

#pragma mark - Private Helpers

- (nullable ChartLayer *)findChartLayerWithID:(NSString *)layerID {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"ChartLayer"];
    request.predicate = [NSPredicate predicateWithFormat:@"layerID == %@", layerID];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error finding chart layer: %@", error);
        return nil;
    }
    
    return results.firstObject;
}

- (nullable ChartObject *)findChartObjectWithID:(NSString *)objectID {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"ChartObject"];
    request.predicate = [NSPredicate predicateWithFormat:@"objectUUID == %@", objectID];

    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error finding chart object: %@", error);
        return nil;
    }
    
    return results.firstObject;
}

- (ChartLayerModel *)layerModelFromCoreData:(ChartLayer *)coreDataLayer {
    ChartLayerModel *model = [ChartLayerModel layerWithName:coreDataLayer.name];
    model.layerID = coreDataLayer.layerID;
    model.isVisible = coreDataLayer.isVisible;
    model.orderIndex = coreDataLayer.orderIndex;
    model.creationDate = coreDataLayer.creationDate;
    model.lastModified = coreDataLayer.lastModified;
    
    // Load objects
    NSSortDescriptor *creationSort = [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES];
    NSArray *sortedObjects = [coreDataLayer.objects sortedArrayUsingDescriptors:@[creationSort]];
    
    for (ChartObject *coreDataObject in sortedObjects) {
        ChartObjectModel *objectModel = [self objectModelFromCoreData:coreDataObject];
        [model addObject:objectModel];
    }
    
    return model;
}

- (ChartObjectModel *)objectModelFromCoreData:(ChartObject *)coreDataObject {
    ChartObjectModel *model = [ChartObjectModel objectWithType:(ChartObjectType)coreDataObject.type
                                                          name:coreDataObject.name];
    if (coreDataObject.objectUUID && [coreDataObject.objectUUID isKindOfClass:[NSString class]]) {
          model.objectID = coreDataObject.objectUUID;
      } else {
          model.objectID = [[NSUUID UUID] UUIDString];
          NSLog(@"⚠️ DataHub: Generated new objectID for object %@", coreDataObject.name);
      }
    model.isVisible = coreDataObject.isVisible;
    model.isLocked = coreDataObject.isLocked;
    model.creationDate = coreDataObject.creationDate;
    model.lastModified = coreDataObject.lastModified;
    model.customProperties = coreDataObject.customProperties;
    
    // Deserialize control points
    [model.controlPoints removeAllObjects];
    if (coreDataObject.controlPointsData) {
        for (NSDictionary *pointData in coreDataObject.controlPointsData) {
            ControlPointModel *point = [ControlPointModel fromDictionary:pointData];
            if (point) {
                [model addControlPoint:point];
            }
        }
    }
    
    // Deserialize style
    if (coreDataObject.styleData) {
        model.style = [ObjectStyleModel fromDictionary:coreDataObject.styleData];
    } else {
        model.style = [ObjectStyleModel defaultStyleForObjectType:(ChartObjectType)coreDataObject.type];
    }
    
    return model;
}

#pragma mark - Temporary Cleanup Methods (DEBUG/DEVELOPMENT ONLY)

/// ⚠️ METODO TEMPORANEO: Cancella TUTTI i chart objects e layers da TUTTI i symboli
/// Usare solo per risolvere conflitti di struttura dati durante sviluppo
- (void)clearAllChartObjectsAndLayers {
    NSLog(@"🚨 DataHub: Starting COMPLETE chart objects cleanup (ALL SYMBOLS)");
    
    // Get all symbols that have chart objects
    NSArray<NSString *> *symbolsWithObjects = [self getSymbolsWithChartObjects];
    NSUInteger totalSymbols = symbolsWithObjects.count;
    
    NSLog(@"🎯 DataHub: Found %lu symbols with chart objects to clear", (unsigned long)totalSymbols);
    
    // Count total objects before deletion (for logging)
    NSUInteger totalObjectsCount = 0;
    NSUInteger totalLayersCount = 0;
    
    for (NSString *symbol in symbolsWithObjects) {
        NSUInteger objectCount = [self getChartObjectsCountForSymbol:symbol];
        NSArray<ChartLayerModel *> *layers = [self getChartLayersForSymbol:symbol];
        
        totalObjectsCount += objectCount;
        totalLayersCount += layers.count;
        
        NSLog(@"  📊 %@: %lu objects in %lu layers", symbol, (unsigned long)objectCount, (unsigned long)layers.count);
    }
    
    // Perform deletion using Core Data batch delete for efficiency
    [self performBatchDeleteChartObjects];
    [self performBatchDeleteChartLayers];
    
    // Force save context
    [self saveContext];
    
    // Verify deletion
    NSArray<NSString *> *remainingSymbols = [self getSymbolsWithChartObjects];
    
    NSLog(@"✅ DataHub: COMPLETE cleanup finished!");
    NSLog(@"   📊 Deleted: %lu objects from %lu layers across %lu symbols",
          (unsigned long)totalObjectsCount, (unsigned long)totalLayersCount, (unsigned long)totalSymbols);
    NSLog(@"   🔍 Remaining symbols with objects: %lu", (unsigned long)remainingSymbols.count);
    
    if (remainingSymbols.count > 0) {
        NSLog(@"⚠️ Warning: Some symbols still have objects: %@", remainingSymbols);
    }
    
    // Post global notification for UI refresh
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartObjectsGlobalClear"
                                                        object:self
                                                      userInfo:@{@"deletedObjects": @(totalObjectsCount),
                                                                @"deletedLayers": @(totalLayersCount),
                                                                @"affectedSymbols": symbolsWithObjects}];
}

/// Helper method for batch deletion of chart objects
- (void)performBatchDeleteChartObjects {
    NSFetchRequest *deleteObjectsRequest = [NSFetchRequest fetchRequestWithEntityName:@"ChartObject"];
    NSBatchDeleteRequest *batchDeleteObjects = [[NSBatchDeleteRequest alloc] initWithFetchRequest:deleteObjectsRequest];
    batchDeleteObjects.resultType = NSBatchDeleteResultTypeCount;
    
    NSError *error;
    NSBatchDeleteResult *result = [self.mainContext executeRequest:batchDeleteObjects error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error batch deleting chart objects: %@", error);
    } else {
        NSLog(@"🗑️ DataHub: Batch deleted %@ chart objects", result.result);
    }
}

/// Helper method for batch deletion of chart layers
- (void)performBatchDeleteChartLayers {
    NSFetchRequest *deleteLayersRequest = [NSFetchRequest fetchRequestWithEntityName:@"ChartLayer"];
    NSBatchDeleteRequest *batchDeleteLayers = [[NSBatchDeleteRequest alloc] initWithFetchRequest:deleteLayersRequest];
    batchDeleteLayers.resultType = NSBatchDeleteResultTypeCount;
    
    NSError *error;
    NSBatchDeleteResult *result = [self.mainContext executeRequest:batchDeleteLayers error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error batch deleting chart layers: %@", error);
    } else {
        NSLog(@"🗑️ DataHub: Batch deleted %@ chart layers", result.result);
    }
}

/// ⚠️ METODO ALTERNATIVO: Cancella tutto per un singolo symbol (più sicuro)
/// @param symbol Il symbol da pulire (nil per saltare)
- (void)clearAllChartObjectsForSingleSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) {
        NSLog(@"⚠️ DataHub: Invalid symbol provided for cleanup");
        return;
    }
    
    NSLog(@"🧹 DataHub: Cleaning ALL chart objects for symbol: %@", symbol);
    
    NSUInteger objectCount = [self getChartObjectsCountForSymbol:symbol];
    NSArray<ChartLayerModel *> *layers = [self getChartLayersForSymbol:symbol];
    
    NSLog(@"  📊 Found %lu objects in %lu layers to delete", (unsigned long)objectCount, (unsigned long)layers.count);
    
    // Use existing method
    [self clearChartObjectsForSymbol:symbol];
    
    // Verify cleanup
    NSUInteger remainingObjects = [self getChartObjectsCountForSymbol:symbol];
    NSArray<ChartLayerModel *> *remainingLayers = [self getChartLayersForSymbol:symbol];
    
    NSLog(@"✅ DataHub: Symbol %@ cleanup complete", symbol);
    NSLog(@"   🔍 Remaining: %lu objects in %lu layers", (unsigned long)remainingObjects, (unsigned long)remainingLayers.count);
}

@end
