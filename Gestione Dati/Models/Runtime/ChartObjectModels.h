//
//  ChartObjectModels.h
//  mafia_AI
//
//  Runtime models for chart objects and drawing tools
//  NEW: Using absolute price values instead of percentage deltas
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enums

typedef NS_ENUM(NSInteger, ChartObjectType) {
    ChartObjectTypeTrendline = 0,              // 2 CP
    ChartObjectTypeHorizontalLine = 1,         // 1 CP
    ChartObjectTypeFibonacci = 2,              // 2 CP
    ChartObjectTypeTrailingFibo = 3,           // 1 CP + dinamico
    ChartObjectTypeTrailingFiboBetween = 4,    // 2 CP + dinamico
    ChartObjectTypeTarget = 5,                 // 3 CP (buy, stop, target)
    ChartObjectTypeCircle = 6,                 // 2 CP
    ChartObjectTypeRectangle = 7,              // 2 CP
    ChartObjectTypeChannel = 8,                // 3 CP (2 per trend + 1 distanza)
    ChartObjectTypeFreeDrawing = 9,            // N CP
    ChartObjectTypeOval = 10                   // 2 CP (come rectangle ma ovale)
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
@property (nonatomic, strong) NSDate *dateAnchor;          // X-axis anchor (specific date)
@property (nonatomic, assign) double absoluteValue;       // Y-axis as absolute price value
@property (nonatomic, strong) NSString *indicatorRef;     // Reference indicator for metadata/context

// Runtime state (not persisted)
@property (nonatomic, assign) NSPoint screenPoint;        // Current screen coordinates
@property (nonatomic, assign) BOOL isSelected;            // For editing
@property (nonatomic, assign) BOOL isDragging;            // During drag operation

// Initialization
+ (instancetype)pointWithDate:(NSDate *)date absoluteValue:(double)value indicator:(NSString *)indicator;
- (instancetype)initWithDate:(NSDate *)date absoluteValue:(double)value indicator:(NSString *)indicator;

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

NS_ASSUME_NONNULL_END
