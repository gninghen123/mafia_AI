//
//  ChartObjectModels.h
//  TradingApp
//
//  Runtime models for chart objects and drawing tools
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enums

typedef NS_ENUM(NSInteger, ChartObjectType) {
    ChartObjectTypeTrendline = 0,
    ChartObjectTypeHorizontalLine = 1,
    ChartObjectTypeFibonacci = 2,
    ChartObjectTypeText = 3,
    ChartObjectTypeFreeDrawing = 4,
    ChartObjectTypeTarget = 5,
    ChartObjectTypeVerticalLine = 6,
    ChartObjectTypeRectangle = 7,
    ChartObjectTypeCircle = 8
};

typedef NS_ENUM(NSInteger, ChartLineType) {
    ChartLineTypeSolid = 0,
    ChartLineTypeDashed = 1,
    ChartLineTypeDotted = 2,
    ChartLineTypeDashDot = 3
};

#pragma mark - Control Point Model

@interface ControlPointModel : NSObject <NSCoding, NSSecureCoding, NSCopying>

// Position anchoring
@property (nonatomic, strong) NSDate *dateAnchor;          // X-axis anchor
@property (nonatomic, assign) double valuePercent;        // Y-axis as % from indicator
@property (nonatomic, strong) NSString *indicatorRef;     // "close", "high", "low", "open"

// Runtime state (not persisted)
@property (nonatomic, assign) NSPoint screenPoint;        // Current screen coordinates
@property (nonatomic, assign) BOOL isSelected;            // For editing
@property (nonatomic, assign) BOOL isDragging;            // During drag operation

// Initialization
+ (instancetype)pointWithDate:(NSDate *)date valuePercent:(double)percent indicator:(NSString *)indicator;
- (instancetype)initWithDate:(NSDate *)date valuePercent:(double)percent indicator:(NSString *)indicator;

// Utilities
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

#pragma mark - Object Style Model

@interface ObjectStyleModel : NSObject <NSCoding, NSSecureCoding, NSCopying>

// Visual properties
@property (nonatomic, strong) NSColor *color;
@property (nonatomic, assign) CGFloat thickness;
@property (nonatomic, assign) ChartLineType lineType;
@property (nonatomic, assign) CGFloat opacity;

// Text properties (for text objects)
@property (nonatomic, strong, nullable) NSFont *font;
@property (nonatomic, strong, nullable) NSColor *textColor;
@property (nonatomic, strong, nullable) NSColor *backgroundColor;

// Default styles
+ (instancetype)defaultStyleForObjectType:(ChartObjectType)type;
+ (instancetype)trendlineStyle;
+ (instancetype)fibonacciStyle;
+ (instancetype)textStyle;

// Persistence
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

#pragma mark - Chart Object Model

@interface ChartObjectModel : NSObject <NSCopying>

// Identification
@property (nonatomic, strong) NSString *objectID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) ChartObjectType type;

// Data
@property (nonatomic, strong) NSMutableArray<ControlPointModel *> *controlPoints;
@property (nonatomic, strong) ObjectStyleModel *style;

// State
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, assign) BOOL isInEditMode;

// Metadata
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong, nullable) NSDate *lastModified;
@property (nonatomic, strong, nullable) NSDictionary *customProperties;

// Initialization
+ (instancetype)objectWithType:(ChartObjectType)type name:(NSString *)name;
- (instancetype)initWithType:(ChartObjectType)type name:(NSString *)name;

// Control points management
- (void)addControlPoint:(ControlPointModel *)point;
- (void)removeControlPoint:(ControlPointModel *)point;
- (void)removeControlPointAtIndex:(NSUInteger)index;
- (ControlPointModel *)controlPointNearPoint:(NSPoint)point tolerance:(CGFloat)tolerance;

// Utilities
- (NSString *)displayName;
- (BOOL)isValidForType;
- (NSRect)boundingRect; // For hit testing and culling

@end

#pragma mark - Chart Layer Model

@interface ChartLayerModel : NSObject <NSCopying>

// Identification
@property (nonatomic, strong) NSString *layerID;
@property (nonatomic, strong) NSString *name;

// Objects
@property (nonatomic, strong) NSMutableArray<ChartObjectModel *> *objects;

// State
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) NSInteger orderIndex;

// Metadata
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong, nullable) NSDate *lastModified;

// Initialization
+ (instancetype)layerWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name;

// Object management
- (void)addObject:(ChartObjectModel *)object;
- (void)removeObject:(ChartObjectModel *)object;
- (void)removeObjectWithID:(NSString *)objectID;
- (nullable ChartObjectModel *)objectWithID:(NSString *)objectID;

// Utilities
- (NSUInteger)visibleObjectsCount;
- (NSArray<ChartObjectModel *> *)visibleObjects;

@end

#pragma mark - Chart Objects Manager

@interface ChartObjectsManager : NSObject

// Current state
@property (nonatomic, strong) NSString *currentSymbol;
@property (nonatomic, strong) NSMutableArray<ChartLayerModel *> *layers;
@property (nonatomic, weak, nullable) ChartLayerModel *activeLayer;

// Selection state
@property (nonatomic, strong, nullable) ChartObjectModel *selectedObject;
@property (nonatomic, strong, nullable) ControlPointModel *selectedControlPoint;

// Initialization
+ (instancetype)managerForSymbol:(NSString *)symbol;
- (instancetype)initWithSymbol:(NSString *)symbol;

// Layer management
- (ChartLayerModel *)createLayerWithName:(NSString *)name;
- (void)deleteLayer:(ChartLayerModel *)layer;
- (void)moveLayer:(ChartLayerModel *)layer toIndex:(NSUInteger)index;

// Object management
- (ChartObjectModel *)createObjectOfType:(ChartObjectType)type inLayer:(ChartLayerModel *)layer;
- (void)deleteObject:(ChartObjectModel *)object;
- (void)moveObject:(ChartObjectModel *)object toLayer:(ChartLayerModel *)targetLayer;

// Selection
- (void)selectObject:(ChartObjectModel *)object;
- (void)selectControlPoint:(ControlPointModel *)controlPoint ofObject:(ChartObjectModel *)object;
- (void)clearSelection;

// Hit testing
- (nullable ChartObjectModel *)objectAtPoint:(NSPoint)point tolerance:(CGFloat)tolerance;
- (nullable ControlPointModel *)controlPointAtPoint:(NSPoint)point tolerance:(CGFloat)tolerance;

// Persistence
- (void)loadFromDataHub;
- (void)saveToDataHub;

// Private helpers
- (NSString *)defaultNameForObjectType:(ChartObjectType)type;

@end

NS_ASSUME_NONNULL_END
