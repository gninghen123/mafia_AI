//
//  ChartObjectsManager.h
//  mafia_AI
//
//  Created by fabio gattone on 08/08/25.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ChartObjectModels.h"

NS_ASSUME_NONNULL_BEGIN
@class ChartObjectRenderer;

@interface ChartObjectsManager : NSObject

// Current state
@property (nonatomic, strong) NSString *currentSymbol;
@property (nonatomic, strong) NSMutableArray<ChartLayerModel *> *layers;
@property (nonatomic, weak, nullable) ChartLayerModel *activeLayer;


@property (nonatomic, weak, nullable) ChartObjectRenderer *coordinateRenderer;
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
- (ChartLayerModel *)ensureActiveLayerForObjectCreation;

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
- (NSString *)generateUniqueNameWithBase:(NSString *)baseName inLayer:(ChartLayerModel *)layer;

- (void)clearAllObjects;

- (void)saveChanges; // Per save manuali quando necessario


@end

NS_ASSUME_NONNULL_END
