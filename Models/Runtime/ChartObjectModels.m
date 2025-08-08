//
//  ChartObjectModels.m
//  mafia_AI
//
//  Implementation of runtime models for chart objects
//

#import "ChartObjectModels.h"

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

#pragma mark - Color Helpers

- (NSString *)colorToHexString:(NSColor *)color {
    NSColor *rgbColor = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
            (int)(rgbColor.redComponent * 255),
            (int)(rgbColor.greenComponent * 255),
            (int)(rgbColor.blueComponent * 255),
            (int)(rgbColor.alphaComponent * 255)];
}

+ (NSColor *)colorFromHexString:(NSString *)hexString {
    if (!hexString || hexString.length < 7) {
        return [NSColor systemBlueColor]; // fallback
    }
    
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    
    unsigned int red, green, blue, alpha = 255;
    
    [[NSScanner scannerWithString:[cleanString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
    [[NSScanner scannerWithString:[cleanString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
    [[NSScanner scannerWithString:[cleanString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
    
    if (cleanString.length >= 8) {
        [[NSScanner scannerWithString:[cleanString substringWithRange:NSMakeRange(6, 2)]] scanHexInt:&alpha];
    }
    
    return [NSColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:alpha/255.0];
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
    return self.name ?: @"Untitled Object";
}

- (BOOL)isValidForType {
    NSUInteger requiredPoints = 0;
    
    switch (self.type) {
        case ChartObjectTypeTrendline:
            requiredPoints = 2;
            break;
        case ChartObjectTypeHorizontalLine:
            requiredPoints = 1;
            break;
        case ChartObjectTypeFibonacci:
            requiredPoints = 2;
            break;
        case ChartObjectTypeTrailingFibo:
            requiredPoints = 1;
            break;
        case ChartObjectTypeTrailingFiboBetween:
            requiredPoints = 2;
            break;
        case ChartObjectTypeTarget:
            requiredPoints = 3;
            break;
        case ChartObjectTypeCircle:
        case ChartObjectTypeRectangle:
        case ChartObjectTypeOval:
            requiredPoints = 2;
            break;
        case ChartObjectTypeChannel:
            requiredPoints = 3;
            break;
        case ChartObjectTypeFreeDrawing:
            requiredPoints = 1; // At least one point
            break;
        default:
            requiredPoints = 1;
            break;
    }
    
    return self.controlPoints.count >= requiredPoints;
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
        minX = MIN(minX, point.screenPoint.x);
        maxX = MAX(maxX, point.screenPoint.x);
        minY = MIN(minY, point.screenPoint.y);
        maxY = MAX(maxY, point.screenPoint.y);
    }
    
    return NSMakeRect(minX, minY, maxX - minX, maxY - minY);
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
