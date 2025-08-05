//
//  DataHub+ChartObjects.h
//  TradingApp
//
//  DataHub extension for Chart Objects persistence
//

#import "DataHub.h"
#import "ChartObjectModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (ChartObjects)

#pragma mark - Chart Layers Management

/// Get all chart layers for a specific symbol
/// @param symbol The symbol to fetch layers for
/// @return Array of ChartLayerModel objects
- (NSArray<ChartLayerModel *> *)getChartLayersForSymbol:(NSString *)symbol;

/// Create a new chart layer for a symbol
/// @param symbol The symbol to create the layer for
/// @param name The layer name
/// @return The created ChartLayerModel
- (ChartLayerModel *)createChartLayerForSymbol:(NSString *)symbol name:(NSString *)name;

/// Save chart layer to Core Data
/// @param layer The layer model to save
/// @param symbol The symbol this layer belongs to
- (void)saveChartLayer:(ChartLayerModel *)layer forSymbol:(NSString *)symbol;

/// Delete chart layer
/// @param layerID The layer ID to delete
- (void)deleteChartLayerWithID:(NSString *)layerID;

/// Update layer visibility and order
/// @param layerID The layer ID
/// @param isVisible Whether the layer should be visible
/// @param orderIndex The display order
- (void)updateChartLayer:(NSString *)layerID visible:(BOOL)isVisible orderIndex:(NSInteger)orderIndex;

#pragma mark - Chart Objects Management

/// Save chart object to Core Data
/// @param object The object model to save
/// @param layerID The layer ID this object belongs to
- (void)saveChartObject:(ChartObjectModel *)object toLayerID:(NSString *)layerID;

/// Delete chart object
/// @param objectID The object ID to delete
- (void)deleteChartObjectWithID:(NSString *)objectID;

/// Move object to different layer
/// @param objectID The object ID to move
/// @param targetLayerID The target layer ID
- (void)moveChartObject:(NSString *)objectID toLayerID:(NSString *)targetLayerID;

/// Update object properties
/// @param objectID The object ID
/// @param isVisible Whether the object should be visible
/// @param isLocked Whether the object should be locked
- (void)updateChartObject:(NSString *)objectID visible:(BOOL)isVisible locked:(BOOL)isLocked;

#pragma mark - Bulk Operations

/// Load complete chart objects structure for a symbol
/// @param symbol The symbol to load objects for
/// @param completion Completion block with loaded layers
- (void)loadChartObjectsForSymbol:(NSString *)symbol completion:(void(^)(NSArray<ChartLayerModel *> *layers))completion;

/// Save complete chart objects structure for a symbol
/// @param layers Array of layers to save
/// @param symbol The symbol to save objects for
- (void)saveChartObjects:(NSArray<ChartLayerModel *> *)layers forSymbol:(NSString *)symbol;

/// Clear all chart objects for a symbol
/// @param symbol The symbol to clear objects for
- (void)clearChartObjectsForSymbol:(NSString *)symbol;

#pragma mark - Statistics and Utilities

/// Get chart objects count for a symbol
/// @param symbol The symbol to count objects for
/// @return Total number of objects across all layers
- (NSUInteger)getChartObjectsCountForSymbol:(NSString *)symbol;

/// Get symbols that have chart objects
/// @return Array of symbol strings that have chart objects
- (NSArray<NSString *> *)getSymbolsWithChartObjects;

@end

NS_ASSUME_NONNULL_END
