//
//  ChartObjectsManager.m - UPDATED with Name Management Methods
//  mafia_AI
//
//  Created by fabio gattone on 08/08/25.
//

#import "ChartObjectsManager.h"
#import "DataHub.h"
#import "DataHub+ChartObjects.h"
#import "ChartObjectRenderer.h"

@implementation ChartObjectsManager

+ (instancetype)managerForSymbol:(NSString *)symbol {
    return [[self alloc] initWithSymbol:symbol];
}

- (instancetype)initWithSymbol:(NSString *)symbol {
    self = [super init];
    if (self) {
        _currentSymbol = symbol ? symbol : @"";
        _layers = [NSMutableArray array];
        _activeLayer = nil;
        _selectedObject = nil;
        _selectedControlPoint = nil;
    }
    return self;
}

#pragma mark - Layer Management

- (ChartLayerModel *)createLayerWithName:(NSString *)name {
    ChartLayerModel *layer = [ChartLayerModel layerWithName:name];
    layer.orderIndex = self.layers.count;
    layer.creationDate = [NSDate date];

    [self.layers addObject:layer];
    
    // Set as active if it's the first layer
    if (!self.activeLayer) {
        self.activeLayer = layer;
    }
    
    NSLog(@"✅ ChartObjectsManager: Created layer '%@' for symbol %@", name, self.currentSymbol);
    return layer;
}

- (void)deleteLayer:(ChartLayerModel *)layer {
    if (!layer) return;
    
    [self.layers removeObject:layer];
    
    // Update active layer if needed
    if (self.activeLayer == layer) {
        self.activeLayer = self.layers.firstObject;
    }
    
    // Clear selection if selected object was in deleted layer
    if (self.selectedObject && [layer.objects containsObject:self.selectedObject]) {
        [self clearSelection];
    }
    
    NSLog(@"🗑️ ChartObjectsManager: Deleted layer '%@'", layer.name);
}

- (void)moveLayer:(ChartLayerModel *)layer toIndex:(NSUInteger)index {
    if (!layer || ![self.layers containsObject:layer]) return;
    
    [self.layers removeObject:layer];
    [self.layers insertObject:layer atIndex:MIN(index, self.layers.count)];
    
    // Update order indices
    [self.layers enumerateObjectsUsingBlock:^(ChartLayerModel *l, NSUInteger idx, BOOL *stop) {
        l.orderIndex = idx;
    }];
    
    NSLog(@"🔄 ChartObjectsManager: Moved layer '%@' to index %lu", layer.name, (unsigned long)index);
}

#pragma mark - ✅ NUOVO: Name Management Methods (spostati dalla UI)

- (NSString *)generateUniqueLayerName:(NSString *)baseName {
    NSString *uniqueName = baseName;
    NSInteger counter = 1;
    
    while ([self layerNameExists:uniqueName]) {
        uniqueName = [NSString stringWithFormat:@"%@ %ld", baseName, (long)counter];
        counter++;
    }
    
    NSLog(@"🏷️ ChartObjectsManager: Generated unique layer name '%@' from base '%@'", uniqueName, baseName);
    return uniqueName;
}

- (BOOL)layerNameExists:(NSString *)name {
    for (ChartLayerModel *layer in self.layers) {
        if ([layer.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)generateUniqueObjectName:(NSString *)baseName inLayer:(ChartLayerModel *)layer {
    NSString *uniqueName = baseName;
    NSInteger counter = 1;
    
    while ([self objectNameExists:uniqueName inLayer:layer]) {
        uniqueName = [NSString stringWithFormat:@"%@ %ld", baseName, (long)counter];
        counter++;
    }
    
    NSLog(@"🏷️ ChartObjectsManager: Generated unique object name '%@' from base '%@' in layer '%@'",
          uniqueName, baseName, layer.name);
    return uniqueName;
}

- (BOOL)objectNameExists:(NSString *)name inLayer:(ChartLayerModel *)layer {
    if (!layer) return NO;
    
    for (ChartObjectModel *object in layer.objects) {
        if ([object.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Object Management

- (ChartObjectModel *)createObjectOfType:(ChartObjectType)type inLayer:(ChartLayerModel *)layer {
    // ✅ CORREZIONE: Se non è specificato un layer, usa/crea layer automaticamente
    if (!layer) {
        layer = [self ensureActiveLayerForObjectCreation];
    }
    
    if (!layer) {
        NSLog(@"❌ ChartObjectsManager: Cannot create object - failed to get/create layer");
        return nil;
    }
    
    // ✅ CORREZIONE: Usa il nuovo metodo per nomi unici
    NSString *baseName = [self defaultNameForObjectType:type];
    NSString *uniqueName = [self generateUniqueObjectName:baseName inLayer:layer];
    
    ChartObjectModel *object = [ChartObjectModel objectWithType:type name:uniqueName];
    [layer addObject:object];
    
    // Set as active layer
    self.activeLayer = layer;
    
    NSLog(@"✅ ChartObjectsManager: Created object '%@' in layer '%@' (not saved yet)", uniqueName, layer.name);
    return object;
}

- (void)deleteObject:(ChartObjectModel *)object {
    if (!object) return;
    
    // Find and remove from layer
    for (ChartLayerModel *layer in self.layers) {
        if ([layer.objects containsObject:object]) {
            [layer removeObject:object];
            break;
        }
    }
    
    // Clear selection if this object was selected
    if (self.selectedObject == object) {
        [self clearSelection];
    }
    
    // ✅ SALVA SUBITO per le delete (ok per operazioni distruttive)
    [self saveToDataHub];
    
    NSLog(@"🗑️ ChartObjectsManager: Deleted object '%@' and saved", object.name);
}

- (void)moveObject:(ChartObjectModel *)object toLayer:(ChartLayerModel *)targetLayer {
    if (!object || !targetLayer) return;
    
    // Remove from current layer
    for (ChartLayerModel *layer in self.layers) {
        if ([layer.objects containsObject:object]) {
            [layer removeObject:object];
            break;
        }
    }
    
    // Add to target layer
    [targetLayer addObject:object];
    
    NSLog(@"🔄 ChartObjectsManager: Moved object '%@' to layer '%@'", object.name, targetLayer.name);
}

#pragma mark - Selection

- (void)selectObject:(ChartObjectModel *)object {
    // Clear previous selection
    [self clearSelection];
    
    if (object) {
        self.selectedObject = object;
        object.isSelected = YES;
        
        NSLog(@"🎯 ChartObjectsManager: Selected object '%@'", object.name);
    }
}

- (void)selectControlPoint:(ControlPointModel *)controlPoint ofObject:(ChartObjectModel *)object {
    // Select the object first
    [self selectObject:object];
    
    if (controlPoint) {
        self.selectedControlPoint = controlPoint;
        controlPoint.isSelected = YES;
        
        NSLog(@"🎯 ChartObjectsManager: Selected control point of object '%@'", object.name);
    }
}

- (void)clearSelection {
    if (self.selectedObject) {
        self.selectedObject.isSelected = NO;
        self.selectedObject = nil;
    }
    
    if (self.selectedControlPoint) {
        self.selectedControlPoint.isSelected = NO;
        self.selectedControlPoint = nil;
    }
}

#pragma mark - Hit Testing

- (nullable ChartObjectModel *)objectAtPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    NSLog(@"🔍 ChartObjectsManager: objectAtPoint called with point (%.1f, %.1f)", point.x, point.y);
    
    // ✅ SOLUZIONE: Delega al renderer se disponibile
    if (self.coordinateRenderer) {
        NSLog(@"🎯 ChartObjectsManager: Delegating to renderer for proper coordinate conversion");
        return [self.coordinateRenderer objectAtScreenPoint:point tolerance:tolerance];
    }
    
    // ❌ FALLBACK: Metodo vecchio (broken) per compatibilità
    NSLog(@"⚠️ ChartObjectsManager: No renderer available - using fallback method");
    
    // Search from top layer to bottom (reverse order)
    for (ChartLayerModel *layer in [self.layers reverseObjectEnumerator]) {
        if (!layer.isVisible) continue;
        
        // Search from top object to bottom (reverse order)
        for (ChartObjectModel *object in [layer.objects reverseObjectEnumerator]) {
            if (!object.isVisible) continue;
            
            // Check if point hits this object
            // TODO: PROBLEMA NOTO - boundingRect usa coordinate chart, non view
            NSRect boundingRect = [object boundingRect];
            NSRect expandedRect = NSInsetRect(boundingRect, -tolerance, -tolerance);
            
            if (NSPointInRect(point, expandedRect)) {
                NSLog(@"⚠️ ChartObjectsManager: Found object '%@' using fallback method (may be inaccurate)", object.name);
                return object;
            }
        }
    }
    
    NSLog(@"🔍 ChartObjectsManager: No object found at point");
    return nil;
}

- (nullable ControlPointModel *)controlPointAtPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    // Check selected object first
    if (self.selectedObject) {
        ControlPointModel *controlPoint = [self.selectedObject controlPointNearPoint:point tolerance:tolerance];
        if (controlPoint) {
            return controlPoint;
        }
    }
    
    // Check all visible objects
    for (ChartLayerModel *layer in [self.layers reverseObjectEnumerator]) {
        if (!layer.isVisible) continue;
        
        for (ChartObjectModel *object in [layer.objects reverseObjectEnumerator]) {
            if (!object.isVisible) continue;
            
            ControlPointModel *controlPoint = [object controlPointNearPoint:point tolerance:tolerance];
            if (controlPoint) {
                return controlPoint;
            }
        }
    }
    
    return nil;
}

#pragma mark - Persistence

- (void)loadFromDataHub {
    NSLog(@"📥 ChartObjectsManager: Starting load for symbol %@", self.currentSymbol);
    
    DataHub *dataHub = [DataHub shared];
    [dataHub loadChartObjectsForSymbol:self.currentSymbol completion:^(NSArray<ChartLayerModel *> *layers) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"📥 ChartObjectsManager: Received %lu layers from DataHub", (unsigned long)layers.count);
            
            [self.layers removeAllObjects];
            [self.layers addObjectsFromArray:layers];
            
            // Set first layer as active if no active layer
            if (layers.count > 0 && !self.activeLayer) {
                self.activeLayer = layers.firstObject;
            }
            
            // ✅ DEBUG: Log dei layer caricati
            for (ChartLayerModel *layer in layers) {
                NSLog(@"📋 Loaded layer '%@' with %lu objects", layer.name, (unsigned long)layer.objects.count);
            }
            
            // ✅ AGGIUNTO: Posta notification quando load completato
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ChartObjectsManagerDataLoaded"
                                                                object:self
                                                              userInfo:@{@"symbol": self.currentSymbol ?: @""}];
            
            NSLog(@"✅ ChartObjectsManager: Load completed for symbol %@", self.currentSymbol);
        });
    }];
}

- (void)saveToDataHub {
    NSLog(@"💾 ChartObjectsManager: Starting save for symbol %@ with %lu layers",
          self.currentSymbol, (unsigned long)self.layers.count);
    
    DataHub *dataHub = [DataHub shared];
    [dataHub saveChartObjects:self.layers forSymbol:self.currentSymbol];
    
    // ✅ DEBUG: Log dei layer salvati
    for (ChartLayerModel *layer in self.layers) {
        NSLog(@"💾 Saved layer '%@' with %lu objects", layer.name, (unsigned long)layer.objects.count);
    }
    
    NSLog(@"✅ ChartObjectsManager: Save completed for symbol %@", self.currentSymbol);
}

#pragma mark - Private Helpers

- (NSString *)defaultNameForObjectType:(ChartObjectType)type {
    switch (type) {
        case ChartObjectTypeTrendline:
            return @"Trendline";
        case ChartObjectTypeHorizontalLine:
            return @"Horizontal Line";
        case ChartObjectTypeFibonacci:
            return @"Fibonacci";
        case ChartObjectTypeTrailingFibo:
            return @"Trailing Fibonacci";
        case ChartObjectTypeTrailingFiboBetween:
            return @"Trailing Fibonacci Between";
        case ChartObjectTypeTarget:
            return @"Price Target";
        case ChartObjectTypeCircle:
            return @"Circle";
        case ChartObjectTypeRectangle:
            return @"Rectangle";
        case ChartObjectTypeChannel:
            return @"Channel";
        case ChartObjectTypeFreeDrawing:
            return @"Free Drawing";
        case ChartObjectTypeOval:
            return @"Oval";
        default:
            return @"Object";
    }
}

// ✅ DEPRECATED: Manteniamo per backward compatibility ma usiamo il nuovo metodo
- (NSString *)generateUniqueNameWithBase:(NSString *)baseName inLayer:(ChartLayerModel *)layer {
    NSLog(@"⚠️ ChartObjectsManager: Using deprecated generateUniqueNameWithBase:inLayer: - use generateUniqueObjectName:inLayer: instead");
    return [self generateUniqueObjectName:baseName inLayer:layer];
}

- (BOOL)nameExistsInLayer:(NSString *)name layer:(ChartLayerModel *)layer {
    NSLog(@"⚠️ ChartObjectsManager: Using deprecated nameExistsInLayer:layer: - use objectNameExists:inLayer: instead");
    return [self objectNameExists:name inLayer:layer];
}

- (void)clearAllObjects {
    // Clear all objects from all layers
    for (ChartLayerModel *layer in self.layers) {
        [layer.objects removeAllObjects];
        layer.lastModified = [NSDate date];
    }
    
    // Clear selection
    [self clearSelection];
    
    // ✅ AUTO-SAVE dopo clear all
    [self saveToDataHub];
    
    NSLog(@"🗑️ ChartObjectsManager: Cleared all objects from all layers and saved");
}

- (void)invalidateAllRenderers {
    // Invia notifica per far ridisegnare tutti i chart che usano questo manager
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChartObjectsManagerDidChangeVisibility"
                                                        object:self
                                                      userInfo:@{@"symbol": self.currentSymbol}];
}

- (void)saveChanges {
    [self saveToDataHub];
    NSLog(@"💾 ChartObjectsManager: Manual save completed");
}

#pragma mark - ✅ CORREZIONE: Lazy Layer Creation con nome unico

- (ChartLayerModel *)ensureActiveLayerForObjectCreation {
    // Se esiste già un layer attivo, usalo
    if (self.activeLayer) {
        NSLog(@"📋 ChartObjectsManager: Using existing active layer '%@'", self.activeLayer.name);
        return self.activeLayer;
    }
    
    // Se esistono layer ma nessuno è attivo, prendi il primo
    if (self.layers.count > 0) {
        self.activeLayer = self.layers.firstObject;
        NSLog(@"📋 ChartObjectsManager: Set first layer '%@' as active", self.activeLayer.name);
        return self.activeLayer;
    }
    
    // ✅ LAZY CREATION: Se non esistono layer, crea "Default" automaticamente con nome unico
    NSLog(@"💡 ChartObjectsManager: No layers exist - creating default layer for object creation");
    
    // ✅ CORREZIONE: Usa generateUniqueLayerName invece di nome fisso!
    NSString *uniqueName = [self generateUniqueLayerName:@"Default"];
    ChartLayerModel *defaultLayer = [self createLayerWithName:uniqueName];
    
    // NON salvare ancora - sarà salvato quando l'oggetto viene completato
    NSLog(@"✅ ChartObjectsManager: Created lazy layer '%@' (not saved yet)", defaultLayer.name);
    
    return defaultLayer;
}

#pragma mark - Symbol Management

- (void)setCurrentSymbol:(NSString *)currentSymbol {
    NSString *previousSymbol = _currentSymbol;
    
    // Evita lavoro inutile se è lo stesso symbol
    if ([currentSymbol isEqualToString:previousSymbol]) {
        return;
    }
    
    NSLog(@"🔄 ChartObjectsManager: Changing symbol from '%@' to '%@'", previousSymbol ?: @"none", currentSymbol);
    
    // Aggiorna il symbol
    _currentSymbol = currentSymbol ? currentSymbol : @"";
    
    // Clear stato precedente
    [self clearSelection];
    
    // Clear layers precedenti
    [self.layers removeAllObjects];
    self.activeLayer = nil;
    
    // Carica dati per il nuovo symbol
    [self loadFromDataHub];
    
    // Invalida renderer se esiste
    if (self.coordinateRenderer) {
        [self.coordinateRenderer invalidateObjectsLayer];
        [self.coordinateRenderer invalidateEditingLayer];
        NSLog(@"✅ ChartObjectsManager: Invalidated renderer for symbol change");
    }
    
    NSLog(@"✅ ChartObjectsManager: Symbol change completed - loading data for '%@'", _currentSymbol);
}

@end
