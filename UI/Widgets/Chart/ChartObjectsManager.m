//
//  ChartObjectsManager.m
//  mafia_AI
//
//  Created by fabio gattone on 08/08/25.
//

#import "ChartObjectsManager.h"
#import "DataHub.h"
#import "DataHub+ChartObjects.h"
#import "ChartObjectRenderer.h"  // ✅ AGGIUNGERE QUESTA RIGA

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
    layer.creationDate = [NSDate date];  // ✅ AGGIUNGI QUESTA RIGA

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

#pragma mark - Object Management

- (ChartObjectModel *)createObjectOfType:(ChartObjectType)type inLayer:(ChartLayerModel *)layer {
    if (!layer) {
        NSLog(@"❌ ChartObjectsManager: Cannot create object - no layer specified");
        return nil;
    }
    
    // Generate unique name
    NSString *baseName = [self defaultNameForObjectType:type];
    NSString *uniqueName = [self generateUniqueNameWithBase:baseName inLayer:layer];
    
    ChartObjectModel *object = [ChartObjectModel objectWithType:type name:uniqueName];
    [layer addObject:object];
    
    // ✅ AUTO-SAVE dopo creazione
    [self saveToDataHub];
    
    NSLog(@"✅ ChartObjectsManager: Created object '%@' in layer '%@' and saved", uniqueName, layer.name);
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
    
    // ✅ AUTO-SAVE dopo delete
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

- (NSString *)generateUniqueNameWithBase:(NSString *)baseName inLayer:(ChartLayerModel *)layer {
    NSString *uniqueName = baseName;
    NSInteger counter = 1;
    
    while ([self nameExistsInLayer:uniqueName layer:layer]) {
        uniqueName = [NSString stringWithFormat:@"%@ %ld", baseName, (long)counter];
        counter++;
    }
    
    return uniqueName;
}

- (BOOL)nameExistsInLayer:(NSString *)name layer:(ChartLayerModel *)layer {
    for (ChartObjectModel *object in layer.objects) {
        if ([object.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
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
@end
