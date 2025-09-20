//
//  ChartObjectModels.m
//  mafia_AI
//
//  Implementation of runtime models for chart objects
//  NEW: Using absolute price values instead of percentage deltas
//

#import "ChartObjectModels.h"

#pragma mark - ControlPointModel Implementation

@implementation ControlPointModel

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)pointWithDate:(NSDate *)date absoluteValue:(double)value indicator:(NSString *)indicator {
    return [[self alloc] initWithDate:date absoluteValue:value indicator:indicator];
}

- (instancetype)initWithDate:(NSDate *)date absoluteValue:(double)value indicator:(NSString *)indicator {
    self = [super init];
    if (self) {
        _dateAnchor = date;
        _absoluteValue = value;
        _indicatorRef = indicator ?: @"close";
        _isSelected = NO;
        _isDragging = NO;
        _screenPoint = NSZeroPoint;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    ControlPointModel *copy = [[ControlPointModel alloc] initWithDate:self.dateAnchor
                                                        absoluteValue:self.absoluteValue
                                                            indicator:self.indicatorRef];
    copy.screenPoint = self.screenPoint;
    copy.isSelected = self.isSelected;
    copy.isDragging = self.isDragging;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.dateAnchor forKey:@"dateAnchor"];
    [coder encodeDouble:self.absoluteValue forKey:@"absoluteValue"];
    [coder encodeObject:self.indicatorRef forKey:@"indicatorRef"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSDate *date = [coder decodeObjectOfClass:[NSDate class] forKey:@"dateAnchor"];
    double value = [coder decodeDoubleForKey:@"absoluteValue"];
    NSString *indicator = [coder decodeObjectOfClass:[NSString class] forKey:@"indicatorRef"];
    
    return [self initWithDate:date absoluteValue:value indicator:indicator];
}

- (NSDictionary *)toDictionary {
    return @{
        @"dateAnchor": @([self.dateAnchor timeIntervalSince1970]),
        @"absoluteValue": @(self.absoluteValue),
        @"indicatorRef": self.indicatorRef ?: @"close"
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    NSTimeInterval timestamp = [dict[@"dateAnchor"] doubleValue];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    double value = [dict[@"absoluteValue"] doubleValue];
    NSString *indicator = dict[@"indicatorRef"] ?: @"close";
    
    return [self pointWithDate:date absoluteValue:value indicator:indicator];
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
        _font = [coder decodeObjectOfClass:[NSFont class] forKey:@"font"] ?: [NSFont systemFontOfSize:12];
        _textColor = [coder decodeObjectOfClass:[NSColor class] forKey:@"textColor"] ?: [NSColor labelColor];
        _backgroundColor = [coder decodeObjectOfClass:[NSColor class] forKey:@"backgroundColor"] ?: [NSColor controlBackgroundColor];
    }
    return self;
}

+ (instancetype)defaultStyleForObjectType:(ChartObjectType)type {
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    
    switch (type) {
        case ChartObjectTypeTrendline:
            style.color = [NSColor systemBlueColor];
            style.thickness = 2.0;
            break;
            
        case ChartObjectTypeHorizontalLine:
            style.color = [NSColor systemPinkColor];
            style.thickness = 1.5;
            break;
            
        case ChartObjectTypeFibonacci:
        case ChartObjectTypeTrailingFibo:
        case ChartObjectTypeTrailingFiboBetween:
            style.color = [NSColor systemPurpleColor];
            style.thickness = 1.0;
            break;
            
        case ChartObjectTypeTarget:
            style.color = [NSColor systemGreenColor];
            style.thickness = 2.0;
            break;
            
        case ChartObjectTypeRectangle:
        case ChartObjectTypeCircle:
        case ChartObjectTypeOval:
            style.color = [NSColor systemRedColor];
            style.thickness = 1.5;
            break;
            
        case ChartObjectTypeChannel:
            style.color = [NSColor systemTealColor];
            style.thickness = 1.5;
            break;
            
        case ChartObjectTypeFreeDrawing:
            style.color = [NSColor labelColor];
            style.thickness = 1.0;
            break;
            
        default:
            break;
    }
    
    return style;
}

+ (instancetype)trendlineStyle {
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    style.color = [NSColor systemBlueColor];
    style.thickness = 2.0;
    style.lineType = ChartLineTypeSolid;
    return style;
}

+ (instancetype)fibonacciStyle {
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    style.color = [NSColor systemPurpleColor];
    style.thickness = 1.0;
    style.lineType = ChartLineTypeSolid;
    style.opacity = 0.8;
    return style;
}

+ (instancetype)textStyle {
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    style.textColor = [NSColor labelColor];
    style.backgroundColor = [NSColor controlBackgroundColor];
    style.font = [NSFont systemFontOfSize:12];
    return style;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Colors as hex strings for portability
    if (self.color) {
        NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:self.color requiringSecureCoding:YES error:nil];
        if (colorData) dict[@"color"] = colorData;
    }
    
    dict[@"thickness"] = @(self.thickness);
    dict[@"lineType"] = @(self.lineType);
    dict[@"opacity"] = @(self.opacity);
    
    if (self.font) {
        NSData *fontData = [NSKeyedArchiver archivedDataWithRootObject:self.font requiringSecureCoding:YES error:nil];
        if (fontData) dict[@"font"] = fontData;
    }
    
    if (self.textColor) {
        NSData *textColorData = [NSKeyedArchiver archivedDataWithRootObject:self.textColor requiringSecureCoding:YES error:nil];
        if (textColorData) dict[@"textColor"] = textColorData;
    }
    
    if (self.backgroundColor) {
        NSData *bgColorData = [NSKeyedArchiver archivedDataWithRootObject:self.backgroundColor requiringSecureCoding:YES error:nil];
        if (bgColorData) dict[@"backgroundColor"] = bgColorData;
    }
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    ObjectStyleModel *style = [[ObjectStyleModel alloc] init];
    
    // Restore colors from data
    if (dict[@"color"]) {
        NSColor *color = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:dict[@"color"] error:nil];
        if (color) style.color = color;
    }
    
    style.thickness = [dict[@"thickness"] doubleValue] ?: 2.0;
    style.lineType = [dict[@"lineType"] integerValue];
    style.opacity = [dict[@"opacity"] doubleValue] ?: 1.0;
    
    if (dict[@"font"]) {
        NSFont *font = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSFont class] fromData:dict[@"font"] error:nil];
        if (font) style.font = font;
    }
    
    if (dict[@"textColor"]) {
        NSColor *textColor = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:dict[@"textColor"] error:nil];
        if (textColor) style.textColor = textColor;
    }
    
    if (dict[@"backgroundColor"]) {
        NSColor *bgColor = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:dict[@"backgroundColor"] error:nil];
        if (bgColor) style.backgroundColor = bgColor;
    }
    
    return style;
}

@end

#pragma mark - ChartObjectModel Implementation

@implementation ChartObjectModel

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

+ (instancetype)objectWithType:(ChartObjectType)type name:(NSString *)name {
    return [[self alloc] initWithType:type name:name];
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
        case ChartObjectTypeHorizontalLine:
            return self.controlPoints.count >= 1;
            
        case ChartObjectTypeTrendline:
        case ChartObjectTypeFibonacci:
        case ChartObjectTypeRectangle:
        case ChartObjectTypeCircle:
        case ChartObjectTypeOval:
            return self.controlPoints.count >= 2;
            
        case ChartObjectTypeTrailingFibo:
            return self.controlPoints.count >= 1;
            
        case ChartObjectTypeTrailingFiboBetween:
            return self.controlPoints.count >= 2;
            
        case ChartObjectTypeTarget:
        case ChartObjectTypeChannel:
            return self.controlPoints.count >= 3;
            
        case ChartObjectTypeFreeDrawing:
            return self.controlPoints.count >= 1;
            
        default:
            return self.controlPoints.count > 0;
    }
}

- (NSRect)boundingRect {
    if (self.controlPoints.count == 0) {
        return NSZeroRect;
    }
    
    CGFloat minX = CGFLOAT_MAX, maxX = -CGFLOAT_MAX;
    CGFloat minY = CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
    
    for (ControlPointModel *cp in self.controlPoints) {
        NSPoint point = cp.screenPoint;
        minX = MIN(minX, point.x);
        maxX = MAX(maxX, point.x);
        minY = MIN(minY, point.y);
        maxY = MAX(maxY, point.y);
    }
    
    // Add padding for hit testing
    CGFloat padding = 10.0;
    return NSMakeRect(minX - padding, minY - padding,
                     (maxX - minX) + 2 * padding,
                     (maxY - minY) + 2 * padding);
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
        _name = name ?: @"Layer";
        _objects = [NSMutableArray array];
        _isVisible = YES;
        _orderIndex = 0;
        _creationDate = [NSDate date];
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    ChartLayerModel *copy = [[ChartLayerModel alloc] initWithName:self.name];
    copy.layerID = [[NSUUID UUID] UUIDString]; // New ID for copy
    copy.isVisible = self.isVisible;
    copy.orderIndex = self.orderIndex;
    
    // Copy objects
    for (ChartObjectModel *object in self.objects) {
        [copy addObject:[object copy]];
    }
    
    return copy;
}

- (void)addObject:(ChartObjectModel *)object {
    if (object && ![self.objects containsObject:object]) {
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
    NSMutableArray *visible = [NSMutableArray array];
    for (ChartObjectModel *object in self.objects) {
        if (object.isVisible) {
            [visible addObject:object];
        }
    }
    return [visible copy];
}

@end
