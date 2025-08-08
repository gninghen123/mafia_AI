//
//  ChartObjectsManager.m
//  mafia_AI
//
//  Created by fabio gattone on 08/08/25.
//

#import "ChartObjectsManager.h"
#import "DataHub.h"
#import "DataHub+ChartObjects.h"

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
    
    NSLog(@"✅ ChartObjectsManager: Created object '%@' in layer '%@'", uniqueName, layer.name);
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
    
    NSLog(@"🗑️ ChartObjectsManager: Deleted object '%@'", object.name);
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
    // Search from top layer to bottom (reverse order)
    for (ChartLayerModel *layer in [self.layers reverseObjectEnumerator]) {
        if (!layer.isVisible) continue;
        
        // Search from top object to bottom (reverse order)
        for (ChartObjectModel *object in [layer.objects reverseObjectEnumerator]) {
            if (!object.isVisible) continue;
            
            // Check if point hits this object
            // TODO: Implement proper hit testing based on object type
            NSRect boundingRect = [object boundingRect];
            NSRect expandedRect = NSInsetRect(boundingRect, -tolerance, -tolerance);
            
            if (NSPointInRect(point, expandedRect)) {
                return object;
            }
        }
    }
    
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
    DataHub *dataHub = [DataHub shared];
    [dataHub loadChartObjectsForSymbol:self.currentSymbol completion:^(NSArray<ChartLayerModel *> *layers) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.layers removeAllObjects];
            [self.layers addObjectsFromArray:layers];
            
            // Set first layer as active if no active layer
            if (layers.count > 0 && !self.activeLayer) {
                self.activeLayer = layers.firstObject;
            }
            
            NSLog(@"📥 ChartObjectsManager: Loaded %lu layers for symbol %@", (unsigned long)layers.count, self.currentSymbol);
        });
    }];
}

- (void)saveToDataHub {
    DataHub *dataHub = [DataHub shared];
    [dataHub saveChartObjects:self.layers forSymbol:self.currentSymbol];
    
    NSLog(@"💾 ChartObjectsManager: Saved %lu layers for symbol %@", (unsigned long)self.layers.count, self.currentSymbol);
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
    
    NSLog(@"🗑️ ChartObjectsManager: Cleared all objects from all layers");
}


@end
