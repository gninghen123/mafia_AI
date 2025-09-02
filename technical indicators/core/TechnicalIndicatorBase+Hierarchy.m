//
// TechnicalIndicatorBase+Hierarchy.m
// TradingApp
//
// Implementation of parent-child hierarchy for technical indicators
//

#import "TechnicalIndicatorBase+Hierarchy.h"
#import <objc/runtime.h>

// Associated object keys for category properties
static const void *kParentIndicatorKey = &kParentIndicatorKey;
static const void *kChildIndicatorsKey = &kChildIndicatorsKey;
static const void *kIndicatorIDKey = &kIndicatorIDKey;
static const void *kDisplayColorKey = &kDisplayColorKey;
static const void *kLineWidthKey = &kLineWidthKey;
static const void *kIsVisibleKey = &kIsVisibleKey;
static const void *kNeedsRenderingKey = &kNeedsRenderingKey;  // ✅ AGGIUNTO

@implementation TechnicalIndicatorBase (Hierarchy)

#pragma mark - Associated Objects (Properties Implementation)

- (TechnicalIndicatorBase *)parentIndicator {
    return objc_getAssociatedObject(self, kParentIndicatorKey);
}

- (void)setParentIndicator:(TechnicalIndicatorBase *)parentIndicator {
    objc_setAssociatedObject(self, kParentIndicatorKey, parentIndicator, OBJC_ASSOCIATION_ASSIGN); // Weak reference
}

- (NSMutableArray<TechnicalIndicatorBase *> *)childIndicators {
    NSMutableArray *children = objc_getAssociatedObject(self, kChildIndicatorsKey);
    if (!children) {
        children = [[NSMutableArray alloc] init];
        objc_setAssociatedObject(self, kChildIndicatorsKey, children, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return children;
}

- (void)setChildIndicators:(NSMutableArray<TechnicalIndicatorBase *> *)childIndicators {
    objc_setAssociatedObject(self, kChildIndicatorsKey, childIndicators, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)indicatorID {
    NSString *indicatorID = objc_getAssociatedObject(self, kIndicatorIDKey);
    if (!indicatorID) {
        // Generate UUID if not set
        indicatorID = [[NSUUID UUID] UUIDString];
        objc_setAssociatedObject(self, kIndicatorIDKey, indicatorID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return indicatorID;
}

- (void)setIndicatorID:(NSString *)indicatorID {
    objc_setAssociatedObject(self, kIndicatorIDKey, indicatorID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSColor *)displayColor {
    NSColor *color = objc_getAssociatedObject(self, kDisplayColorKey);
    return color ?: [self defaultDisplayColor];
}

- (void)setDisplayColor:(NSColor *)displayColor {
    objc_setAssociatedObject(self, kDisplayColorKey, displayColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)lineWidth {
    NSNumber *width = objc_getAssociatedObject(self, kLineWidthKey);
    return width ? [width floatValue] : [self defaultLineWidthForIndicator:self];
}

- (void)setLineWidth:(CGFloat)lineWidth {
    objc_setAssociatedObject(self, kLineWidthKey, @(lineWidth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isVisible {
    NSNumber *visible = objc_getAssociatedObject(self, kIsVisibleKey);
    return visible ? [visible boolValue] : YES; // Default visible
}

- (void)setIsVisible:(BOOL)isVisible {
    objc_setAssociatedObject(self, kIsVisibleKey, @(isVisible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)needsRendering {
    NSNumber *needs = objc_getAssociatedObject(self, kNeedsRenderingKey);
    return needs ? [needs boolValue] : YES; // Default YES for first render
}

- (void)setNeedsRendering:(BOOL)needsRendering {
    objc_setAssociatedObject(self, kNeedsRenderingKey, @(needsRendering), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Hierarchy Management

- (void)addChildIndicator:(TechnicalIndicatorBase *)childIndicator {
    if (!childIndicator) return;
    
    // Remove from previous parent if any
    [childIndicator removeFromParent];
    
    // Set parent relationship
    childIndicator.parentIndicator = self;
    
    // Add to children array
    [self.childIndicators addObject:childIndicator];
    
    NSLog(@"✅ Added %@ as child of %@", childIndicator.shortName, self.shortName);
}

- (void)removeChildIndicator:(TechnicalIndicatorBase *)childIndicator {
    if (!childIndicator) return;
    
    // Remove parent relationship
    childIndicator.parentIndicator = nil;
    
    // Remove from children array
    [self.childIndicators removeObject:childIndicator];
    
    NSLog(@"🗑️ Removed %@ from %@", childIndicator.shortName, self.shortName);
}

- (void)removeFromParent {
    if (self.parentIndicator) {
        [self.parentIndicator removeChildIndicator:self];
    }
}

- (NSArray<TechnicalIndicatorBase *> *)getAllDescendants {
    NSMutableArray *descendants = [[NSMutableArray alloc] init];
    
    for (TechnicalIndicatorBase *child in self.childIndicators) {
        [descendants addObject:child];
        [descendants addObjectsFromArray:[child getAllDescendants]]; // Recursive
    }
    
    return [descendants copy];
}

#pragma mark - Hierarchy Navigation

- (BOOL)isRootIndicator {
    return self.parentIndicator == nil;
}

- (NSInteger)getInheritanceLevel {
    NSInteger level = 0;
    TechnicalIndicatorBase *parent = self.parentIndicator;
    
    while (parent) {
        level++;
        parent = parent.parentIndicator;
    }
    
    return level;
}

- (TechnicalIndicatorBase *)getRootIndicator {
    TechnicalIndicatorBase *root = self;
    
    while (root.parentIndicator) {
        root = root.parentIndicator;
    }
    
    return root;
}

- (NSArray<TechnicalIndicatorBase *> *)getIndicatorPath {
    NSMutableArray *path = [[NSMutableArray alloc] init];
    TechnicalIndicatorBase *current = self;
    
    // Build path from self to root
    while (current) {
        [path insertObject:current atIndex:0]; // Insert at beginning
        current = current.parentIndicator;
    }
    
    return [path copy];
}

#pragma mark - Data Flow

- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {
    // This should be overridden by subclasses for ROOT indicators only
    NSLog(@"⚠️ calculateWithBars called on %@ - should be overridden by subclass", NSStringFromClass(self.class));
}

- (void)calculateWithParentSeries:(NSArray<NSNumber *> *)parentValues {
    // This should be overridden by subclasses for CHILD indicators only
    NSLog(@"⚠️ calculateWithParentSeries called on %@ - should be overridden by subclass", NSStringFromClass(self.class));
}

- (NSArray<NSNumber *> *)getOutputSeries {
    // Extract values from outputSeries (IndicatorDataModel array)
    NSMutableArray *values = [[NSMutableArray alloc] init];
    
    for (IndicatorDataModel *dataPoint in self.outputSeries) {
        [values addObject:@(dataPoint.value)];
    }
    
    return [values copy];
}

- (void)calculateIndicatorTree:(id)inputData {
    if (self.isRootIndicator) {
        // Root: calculate with HistoricalBarModel array
        [self calculateWithBars:(NSArray<HistoricalBarModel *> *)inputData];
    } else {
        // Child: calculate with parent series
        [self calculateWithParentSeries:(NSArray<NSNumber *> *)inputData];
    }
    
    // ✅ AGGIUNTO: Flag che i dati sono cambiati e serve re-rendering
    self.needsRendering = YES;
    
    // Calculate all children recursively
    NSArray<NSNumber *> *myOutputSeries = [self getOutputSeries];
    for (TechnicalIndicatorBase *child in self.childIndicators) {
        [child calculateIndicatorTree:myOutputSeries];
    }
}

#pragma mark - Capability Queries

- (BOOL)canHaveChildren {
    // Most indicators can have children - override to return NO for specific cases
    return YES;
}

- (BOOL)canBeChildOfType:(NSString *)parentType {
    // Basic compatibility - can be refined per indicator type
    return YES;
}

- (NSArray<NSString *> *)getSupportedChildTypes {
    // Default: common indicators that work as children
    return @[@"SMAIndicator", @"EMAIndicator", @"RSIIndicator", @"MACDIndicator"];
}

- (BOOL)hasVisualOutput {
    // Most indicators have visual output - override for utility indicators
    return YES;
}

#pragma mark - Display and UI

- (NSString *)displayName {
    // Format: "SMA(20)" or "RSI(14)"
    if (self.parameters.count > 0) {
        NSArray *paramValues = [self.parameters.allValues valueForKey:@"description"];
        NSString *paramString = [paramValues componentsJoinedByString:@","];
        return [NSString stringWithFormat:@"%@(%@)", self.shortName, paramString];
    }
    return self.shortName;
}

- (NSString *)shortDisplayName {
    return self.shortName;
}

- (NSString *)iconName {
    if (self.isRootIndicator) {
        return @"chart.line.uptrend.xyaxis";
    } else {
        return @"minus";
    }
}

- (NSColor *)defaultDisplayColor {
    // Different colors for different hierarchy levels
    switch (self.getInheritanceLevel) {
        case 0: return [NSColor systemBlueColor];      // Root
        case 1: return [NSColor systemOrangeColor];    // Child
        case 2: return [NSColor systemGreenColor];     // Grandchild
        default: return [NSColor systemPurpleColor];   // Great-grandchild+
    }
}

- (CGFloat)defaultLineWidthForIndicator:(TechnicalIndicatorBase *)indicator {
    return indicator.isRootIndicator ? 2.0 : 1.0;
}

#pragma mark - Serialization Support

- (NSDictionary<NSString *, id> *)serializeToDictionary {
    return @{
        @"class": NSStringFromClass(self.class),
        @"indicatorID": self.indicatorID,
        @"parameters": self.parameters ?: @{},
        @"displayColor": self.displayColor ? [NSArchiver archivedDataWithRootObject:self.displayColor] : [NSNull null],
        @"lineWidth": @(self.lineWidth),
        @"isVisible": @(self.isVisible)
    };
}

+ (instancetype)deserializeFromDictionary:(NSDictionary<NSString *, id> *)dictionary {
    NSString *className = dictionary[@"class"];
    Class indicatorClass = NSClassFromString(className);
    
    if (!indicatorClass) {
        NSLog(@"⚠️ Unknown indicator class: %@", className);
        return nil;
    }
    
    NSDictionary *parameters = dictionary[@"parameters"];
    TechnicalIndicatorBase *indicator = [[indicatorClass alloc] initWithParameters:parameters];
    
    indicator.indicatorID = dictionary[@"indicatorID"];
    indicator.lineWidth = [dictionary[@"lineWidth"] floatValue];
    indicator.isVisible = [dictionary[@"isVisible"] boolValue];
    
    // Deserialize color
    NSData *colorData = dictionary[@"displayColor"];
    if (colorData && ![colorData isKindOfClass:[NSNull class]]) {
        indicator.displayColor = [NSUnarchiver unarchiveObjectWithData:colorData];
    }
    
    return indicator;
}

- (NSDictionary<NSString *, id> *)serializeSubtreeToDictionary {
    NSMutableDictionary *result = [[self serializeToDictionary] mutableCopy];
    
    // Serialize children
    NSMutableArray *serializedChildren = [[NSMutableArray alloc] init];
    for (TechnicalIndicatorBase *child in self.childIndicators) {
        [serializedChildren addObject:[child serializeSubtreeToDictionary]];
    }
    result[@"children"] = serializedChildren;
    
    return [result copy];
}

+ (instancetype)deserializeSubtreeFromDictionary:(NSDictionary<NSString *, id> *)dictionary {
    TechnicalIndicatorBase *indicator = [self deserializeFromDictionary:dictionary];
    if (!indicator) return nil;
    
    // Deserialize children
    NSArray *childrenData = dictionary[@"children"];
    for (NSDictionary *childData in childrenData) {
        TechnicalIndicatorBase *child = [self deserializeSubtreeFromDictionary:childData];
        if (child) {
            [indicator addChildIndicator:child];
        }
    }
    
    return indicator;
}

#pragma mark - Validation

- (BOOL)validateConfiguration:(NSError **)error {
    // Basic validation - can be overridden
    if (!self.indicatorID || self.indicatorID.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TechnicalIndicatorError"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Indicator ID is required"}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)validateParentRelationship:(TechnicalIndicatorBase *)proposedParent error:(NSError **)error {
    if (!proposedParent) return YES; // Root indicator
    
    // Check for circular references
    TechnicalIndicatorBase *ancestor = proposedParent;
    while (ancestor) {
        if (ancestor == self) {
            if (error) {
                *error = [NSError errorWithDomain:@"TechnicalIndicatorError"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Circular reference detected in indicator hierarchy"}];
            }
            return NO;
        }
        ancestor = ancestor.parentIndicator;
    }
    
    return YES;
}

#pragma mark - Cleanup

- (void)cleanup {
    // Remove from parent
    [self removeFromParent];
    
    // Remove all children
    NSArray *childrenCopy = [self.childIndicators copy];
    for (TechnicalIndicatorBase *child in childrenCopy) {
        [child cleanup];
    }
    
    // Clear data
    [self.childIndicators removeAllObjects];
    self.outputSeries = nil;
    
    NSLog(@"🧹 Cleaned up indicator: %@", self.shortName);
}

@end
