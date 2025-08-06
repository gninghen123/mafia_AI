//
//  ChartObjectModels.m
//  TradingApp
//
//  Implementation of runtime models for chart objects
//

#import "ChartObjectModels.h"
#import "DataHub.h"
#import "DataHub+ChartObjects.h"

#pragma mark - ControlPointModel Implementation

@implementation ControlPointModel

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)pointWithDate:(NSDate *)date valuePercent:(double)percent indicator:(NSString *)indicator {
    return [[self alloc] initWithDate:date valuePercent:percent indicator:indicator];
}

- (instancetype)initWithDate:(NSDate *)date valuePercent:(double)percent indicator:(NSString *)indicator {
    self = [super init];
    if (self) {
        _dateAnchor = date;
        _valuePercent = percent;
        _indicatorRef = indicator ?: @"close";
        _isSelected = NO;
        _isDragging = NO;
        _screenPoint = NSZeroPoint;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    ControlPointModel *copy = [[ControlPointModel alloc] initWithDate:self.dateAnchor
                                                          valuePercent:self.valuePercent
                                                             indicator:self.indicatorRef];
    copy.screenPoint = self.screenPoint;
    copy.isSelected = self.isSelected;
    copy.isDragging = self.isDragging;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.dateAnchor forKey:@"dateAnchor"];
    [coder encodeDouble:self.valuePercent forKey:@"valuePercent"];
    [coder encodeObject:self.indicatorRef forKey:@"indicatorRef"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSDate *date = [coder decodeObjectOfClass:[NSDate class] forKey:@"dateAnchor"];
    double percent = [coder decodeDoubleForKey:@"valuePercent"];
    NSString *indicator = [coder decodeObjectOfClass:[NSString class] forKey:@"indicatorRef"];
    
    return [self initWithDate:date valuePercent:percent indicator:indicator];
}

- (NSDictionary *)toDictionary {
    return @{
        @"dateAnchor": @([self.dateAnchor timeIntervalSince1970]),
        @"valuePercent": @(self.valuePercent),
        @"indicatorRef": self.indicatorRef ?: @"close"
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    NSTimeInterval timestamp = [dict[@"dateAnchor"] doubleValue];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    double percent = [dict[@"valuePercent"] doubleValue];
    NSString *indicator = dict[@"indicatorRef"] ?: @"close";
    
    return [self pointWithDate:date valuePercent:percent indicator:indicator];
}

@end

#pragma mark - ObjectStyleModel Implementation

@implementation ObjectStyleModel

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _color = [NSColor systemBlueColor];
        _thickness = 2.0;
        _lineType = ChartLineTypeSolid;
        _opacity = 1.0;
        _font = [NSFont systemFontOfSize:12];
        _textColor = [NSColor labelColor];
        _backgroundColor = [NSColor controlBackgroundColor];
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    ObjectStyleModel *copy = [[ObjectStyleModel alloc] init];
    copy.color = [self.color copy];
    copy.thickness = self.thickness;
    copy.lineType = self.lineType;
    copy.opacity = self.opacity;
    copy.font = [self.font copy];
    copy.textColor = [self.textColor copy];
    copy.backgroundColor = [self.backgroundColor copy];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.color forKey:@"color"];
    [coder encodeDouble:self.thickness forKey:@"thickness"];
    [coder encodeInteger:self.lineType forKey:@"lineType"];
    [coder encodeDouble:self.opacity forKey:@"opacity"];
    [coder encodeObject:self.font forKey:@"font"];
    [coder encodeObject:self.textColor forKey:@"textColor"];
    [coder encodeObject:self.backgroundColor forKey:@"backgroundColor"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _color = [coder decodeObjectOfClass:[NSColor class] forKey:@"color"] ?: [NSColor systemBlueColor];
        _thickness = [coder decodeDoubleForKey:@"thickness"] ?: 2.0;
        _lineType = [coder decodeIntegerForKey:@"lineType"];
        _opacity = [coder decodeDoubleForKey:@"opacity"] ?: 1.0;
        _font = [coder decodeObjectOfClass:[NSFont class] forKey:@"font"];
        _textColor = [coder decodeObjectOfClass:[NSColor class] forKey:@"textColor"];
        _backgroundColor = [coder decodeObjectOfClass:[NSColor class] forKey:@"backgroundColor"];
    }
    return self;
}

+ (instancetype)defaultStyleForObjectType:(ChartObjectType)type {
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    
    switch (type) {
        case ChartObjectTypeTrendline:
            return [self trendlineStyle];
            
        case ChartObjectTypeHorizontalLine:
            style.color = [NSColor systemOrangeColor];
            style.thickness = 1.5;
            style.lineType = ChartLineTypeDashed;
            break;
            
        case ChartObjectTypeFibonacci:
            return [self fibonacciStyle];
            
        case ChartObjectTypeTarget:
            style.color = [NSColor systemGreenColor];
            style.thickness = 2.0;
            style.lineType = ChartLineTypeSolid;
            break;
            
        case ChartObjectTypeFreeDrawing:
            style.color = [NSColor systemPurpleColor];
            style.thickness = 3.0;
            style.lineType = ChartLineTypeSolid;
            break;
            
        default:
            // Keep default values
            break;
    }
    
    return style;
}

+ (instancetype)trendlineStyle {
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    style.color = [NSColor systemBlueColor];
    style.thickness = 2.0;
    style.lineType = ChartLineTypeSolid;
    style.opacity = 0.8;
    return style;
}

+ (instancetype)fibonacciStyle {
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    style.color = [NSColor systemTealColor];
    style.thickness = 1.0;
    style.lineType = ChartLineTypeDashed;
    style.opacity = 0.7;
    return style;
}

+ (instancetype)textStyle {
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    style.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    style.textColor = [NSColor labelColor];
    style.backgroundColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.9];
    return style;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Color as hex string
    if (self.color) {
        dict[@"color"] = [self colorToHexString:self.color];
    }
    
    dict[@"thickness"] = @(self.thickness);
    dict[@"lineType"] = @(self.lineType);
    dict[@"opacity"] = @(self.opacity);
    
    // Font as dictionary
    if (self.font) {
        dict[@"font"] = @{
            @"name": self.font.fontName,
            @"size": @(self.font.pointSize)
        };
    }
    
    // Text colors
    if (self.textColor) {
        dict[@"textColor"] = [self colorToHexString:self.textColor];
    }
    if (self.backgroundColor) {
        dict[@"backgroundColor"] = [self colorToHexString:self.backgroundColor];
    }
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    
    // Color from hex string
    NSString *colorHex = dict[@"color"];
    if (colorHex) {
        style.color = [self colorFromHexString:colorHex];
    }
    
    style.thickness = [dict[@"thickness"] doubleValue] ?: 2.0;
    style.lineType = [dict[@"lineType"] integerValue];
    style.opacity = [dict[@"opacity"] doubleValue] ?: 1.0;
    
    // Font from dictionary
    NSDictionary *fontDict = dict[@"font"];
    if (fontDict) {
        NSString *fontName = fontDict[@"name"];
        CGFloat fontSize = [fontDict[@"size"] doubleValue] ?: 12.0;
        style.font = [NSFont fontWithName:fontName size:fontSize] ?: [NSFont systemFontOfSize:fontSize];
    }
    
    // Text colors
    NSString *textColorHex = dict[@"textColor"];
    if (textColorHex) {
        style.textColor = [self colorFromHexString:textColorHex];
    }
    
    NSString *backgroundColorHex = dict[@"backgroundColor"];
    if (backgroundColorHex) {
        style.backgroundColor = [self colorFromHexString:backgroundColorHex];
    }
    
    return style;
}

- (NSString *)colorToHexString:(NSColor *)color {
    NSColor *rgbColor = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
            (int)(rgbColor.redComponent * 255),
            (int)(rgbColor.greenComponent * 255),
            (int)(rgbColor.blueComponent * 255),
            (int)(rgbColor.alphaComponent * 255)];
}

+ (NSColor *)colorFromHexString:(NSString *)hexString {
    if (![hexString hasPrefix:@"#"] || hexString.length != 9) {
        return [NSColor systemBlueColor]; // Default fallback
    }
    
    NSString *hex = [hexString substringFromIndex:1];
    unsigned int r, g, b, a;
    
    [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&r];
    [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&g];
    [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&b];
    [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(6, 2)]] scanHexInt:&a];
    
    return [NSColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a/255.0];
}

@end

#pragma mark - ChartObjectModel Implementation

@implementation ChartObjectModel

+ (instancetype)objectWithType:(ChartObjectType)type name:(NSString *)name {
    return [[self alloc] initWithType:type name:name];
}

- (instancetype)initWithType:(ChartObjectType)type name:(NSString *)name {
    self = [super init];
    if (self) {
        _objectID = [[NSUUID UUID] UUIDString];
        _name = name ?: [self defaultNameForType:type];
        _type = type;
        _controlPoints = [NSMutableArray array];
        _style = [ObjectStyleModel defaultStyleForObjectType:type];
        _isVisible = YES;
        _isLocked = NO;
        _isSelected = NO;
        _isInEditMode = NO;
        _creationDate = [NSDate date];
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    ChartObjectModel *copy = [[ChartObjectModel alloc] initWithType:self.type name:self.name];
    copy.objectID = [[NSUUID UUID] UUIDString]; // New ID for copy
    copy.isVisible = self.isVisible;
    copy.isLocked = self.isLocked;
    copy.style = [self.style copy];
    copy.customProperties = [self.customProperties copy];
    
    // Copy control points
    for (ControlPointModel *point in self.controlPoints) {
        [copy addControlPoint:[point copy]];
    }
    
    return copy;
}

- (NSString *)defaultNameForType:(ChartObjectType)type {
    switch (type) {
        case ChartObjectTypeTrendline:
            return @"Trendline";
        case ChartObjectTypeHorizontalLine:
            return @"Horizontal Line";
        case ChartObjectTypeFibonacci:
            return @"Fibonacci";
      
        case ChartObjectTypeFreeDrawing:
            return @"Drawing";
        case ChartObjectTypeTarget:
            return @"Price Target";
      
        case ChartObjectTypeRectangle:
            return @"Rectangle";
        case ChartObjectTypeCircle:
            return @"Circle";
        default:
            return @"Object";
    }
}

- (void)addControlPoint:(ControlPointModel *)point {
    if (point) {
        [self.controlPoints addObject:point];
        self.lastModified = [NSDate date];
    }
}

- (void)removeControlPoint:(ControlPointModel *)point {
    if (point) {
        [self.controlPoints removeObject:point];
        self.lastModified = [NSDate date];
    }
}

- (void)removeControlPointAtIndex:(NSUInteger)index {
    if (index < self.controlPoints.count) {
        [self.controlPoints removeObjectAtIndex:index];
        self.lastModified = [NSDate date];
    }
}

- (ControlPointModel *)controlPointNearPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    for (ControlPointModel *controlPoint in self.controlPoints) {
        CGFloat distance = hypot(controlPoint.screenPoint.x - point.x,
                                controlPoint.screenPoint.y - point.y);
        if (distance <= tolerance) {
            return controlPoint;
        }
    }
    return nil;
}

- (NSString *)displayName {
    return self.name ?: [self defaultNameForType:self.type];
}

- (BOOL)isValidForType {
    switch (self.type) {
        case ChartObjectTypeTrendline:
        case ChartObjectTypeHorizontalLine:
        
            
        case ChartObjectTypeFibonacci:
            return self.controlPoints.count >= 2;
            
        case ChartObjectTypeTarget:
            return self.controlPoints.count >= 1;
            
        case ChartObjectTypeFreeDrawing:
            return self.controlPoints.count >= 2;
            
        case ChartObjectTypeRectangle:
        case ChartObjectTypeCircle:
            return self.controlPoints.count >= 2;
            
        default:
            return self.controlPoints.count > 0;
    }
}

- (NSRect)boundingRect {
    if (self.controlPoints.count == 0) {
        return NSZeroRect;
    }
    
    CGFloat minX = CGFLOAT_MAX;
    CGFloat maxX = -CGFLOAT_MAX;
    CGFloat minY = CGFLOAT_MAX;
    CGFloat maxY = -CGFLOAT_MAX;
    
    for (ControlPointModel *point in self.controlPoints) {
        NSPoint screenPoint = point.screenPoint;
        minX = MIN(minX, screenPoint.x);
        maxX = MAX(maxX, screenPoint.x);
        minY = MIN(minY, screenPoint.y);
        maxY = MAX(maxY, screenPoint.y);
    }
    
    // Add some padding for line thickness
    CGFloat padding = self.style.thickness + 5;
    return NSMakeRect(minX - padding, minY - padding,
                     (maxX - minX) + (2 * padding),
                     (maxY - minY) + (2 * padding));
}

@end

#pragma mark - ChartLayerModel Implementation

@implementation ChartLayerModel

+ (instancetype)layerWithName:(NSString *)name {
    return [[self alloc] initWithName:name];
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        _layerID = [[NSUUID UUID] UUIDString];
        _name = name ?: @"Untitled Layer";
        _objects = [NSMutableArray array];
        _isVisible = YES;
        _orderIndex = 0;
        _creationDate = [NSDate date];
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    ChartLayerModel *copy = [[ChartLayerModel alloc] initWithName:self.name];
    copy.isVisible = self.isVisible;
    copy.orderIndex = self.orderIndex;
    
    // Copy all objects
    for (ChartObjectModel *object in self.objects) {
        [copy addObject:[object copy]];
    }
    
    return copy;
}

- (void)addObject:(ChartObjectModel *)object {
    if (object) {
        [self.objects addObject:object];
        self.lastModified = [NSDate date];
    }
}

- (void)removeObject:(ChartObjectModel *)object {
    if (object) {
        [self.objects removeObject:object];
        self.lastModified = [NSDate date];
    }
}

- (void)removeObjectWithID:(NSString *)objectID {
    ChartObjectModel *objectToRemove = [self objectWithID:objectID];
    if (objectToRemove) {
        [self removeObject:objectToRemove];
    }
}

- (nullable ChartObjectModel *)objectWithID:(NSString *)objectID {
    for (ChartObjectModel *object in self.objects) {
        if ([object.objectID isEqualToString:objectID]) {
            return object;
        }
    }
    return nil;
}

- (NSUInteger)visibleObjectsCount {
    NSUInteger count = 0;
    for (ChartObjectModel *object in self.objects) {
        if (object.isVisible) {
            count++;
        }
    }
    return count;
}

- (NSArray<ChartObjectModel *> *)visibleObjects {
    NSMutableArray *visibleObjects = [NSMutableArray array];
    for (ChartObjectModel *object in self.objects) {
        if (object.isVisible) {
            [visibleObjects addObject:object];
        }
    }
    return [visibleObjects copy];
}

@end

#pragma mark - ChartObjectsManager Implementation

@implementation ChartObjectsManager

+ (instancetype)managerForSymbol:(NSString *)symbol {
    return [[self alloc] initWithSymbol:symbol];
}

- (instancetype)initWithSymbol:(NSString *)symbol {
    self = [super init];
    if (self) {
        _currentSymbol = symbol ?: @"";
        _layers = [NSMutableArray array];
        _activeLayer = nil;
        _selectedObject = nil;
        _selectedControlPoint = nil;
    }
    return self;
}

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

- (ChartObjectModel *)createObjectOfType:(ChartObjectType)type inLayer:(ChartLayerModel *)layer {
    if (!layer) {
        NSLog(@"❌ ChartObjectsManager: Cannot create object - no layer specified");
        return nil;
    }
    
    // Generate unique name using static method
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

- (nullable ChartObjectModel *)objectAtPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    // Test in reverse layer order (top layers first)
    for (ChartLayerModel *layer in [self.layers reverseObjectEnumerator]) {
        if (!layer.isVisible) continue;
        
        // Test objects in reverse order (newest first)
        for (ChartObjectModel *object in [layer.objects reverseObjectEnumerator]) {
            if (!object.isVisible) continue;
            
            NSRect boundingRect = [object boundingRect];
            NSRect testRect = NSInsetRect(NSMakeRect(point.x, point.y, 0, 0), -tolerance, -tolerance);
            
            if (NSIntersectsRect(boundingRect, testRect)) {
                return object;
            }
        }
    }
    
    return nil;
}

- (nullable ControlPointModel *)controlPointAtPoint:(NSPoint)point tolerance:(CGFloat)tolerance {
    // Only test selected object's control points
    if (!self.selectedObject) return nil;
    
    return [self.selectedObject controlPointNearPoint:point tolerance:tolerance];
}

- (void)loadFromDataHub {
    if (self.currentSymbol.length == 0) return;
    
    [[DataHub shared] loadChartObjectsForSymbol:self.currentSymbol completion:^(NSArray<ChartLayerModel *> *layers) {
        [self.layers removeAllObjects];
        [self.layers addObjectsFromArray:layers];
        
        // Set first layer as active
        self.activeLayer = self.layers.firstObject;
        
        NSLog(@"📊 ChartObjectsManager: Loaded %lu layers for symbol %@",
              (unsigned long)layers.count, self.currentSymbol);
    }];
}

- (void)saveToDataHub {
    if (self.currentSymbol.length == 0) return;
    
    [[DataHub shared] saveChartObjects:self.layers forSymbol:self.currentSymbol];
    
    NSLog(@"💾 ChartObjectsManager: Saved %lu layers for symbol %@",
          (unsigned long)self.layers.count, self.currentSymbol);
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
      
        case ChartObjectTypeFreeDrawing:
            return @"Drawing";
        case ChartObjectTypeTarget:
            return @"Price Target";
      
        case ChartObjectTypeRectangle:
            return @"Rectangle";
        case ChartObjectTypeCircle:
            return @"Circle";
        default:
            return @"Object";
    }
}

- (NSString *)generateUniqueNameWithBase:(NSString *)baseName inLayer:(ChartLayerModel *)layer {
    NSString *uniqueName = baseName;
    NSUInteger counter = 1;
    
    while ([self isNameTaken:uniqueName inLayer:layer]) {
        uniqueName = [NSString stringWithFormat:@"%@ #%lu", baseName, (unsigned long)counter];
        counter++;
    }
    
    return uniqueName;
}

- (BOOL)isNameTaken:(NSString *)name inLayer:(ChartLayerModel *)layer {
    for (ChartObjectModel *object in layer.objects) {
        if ([object.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

@end
