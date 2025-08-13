//
//  ChartObjectRenderer.h
//  TradingApp
//
//  Chart objects rendering engine with optimized layer management
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ChartObjectModels.h"
#import "ChartObjectsManager.h"


@class ChartPanelView;
@class HistoricalBarModel;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Coordinate Context

@interface ChartCoordinateContext : NSObject
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *chartData;
@property (nonatomic, assign) NSInteger visibleStartIndex;
@property (nonatomic, assign) NSInteger visibleEndIndex;
@property (nonatomic, assign) double yRangeMin;
@property (nonatomic, assign) double yRangeMax;
@property (nonatomic, assign) CGRect panelBounds;

@property (nonatomic, assign) NSInteger barsPerDay;
@property (nonatomic, assign) NSInteger currentTimeframeMinutes;

@end

#pragma mark - Chart Object Renderer

@interface ChartObjectRenderer : NSObject

// Context and dependencies
@property (nonatomic, weak) ChartPanelView *panelView;
@property (nonatomic, strong) ChartObjectsManager *objectsManager;
@property (nonatomic, strong) ChartCoordinateContext *coordinateContext;

// Rendering layers (will be added to ChartPanelView)
@property (nonatomic, strong) CALayer *objectsLayer;        // Static objects
@property (nonatomic, strong) CALayer *objectsEditingLayer; // Object being edited

// Editing state
@property (nonatomic, strong, nullable) ChartObjectModel *editingObject;
@property (nonatomic, assign, readonly) BOOL isInCreationMode; // Made public readonly
@property (nonatomic, assign) NSPoint currentMousePosition;
@property (nonatomic, strong, nullable) ControlPointModel *hoveredControlPoint;

// NEW: Unified CP state management
@property (nonatomic, strong, nullable) ControlPointModel *currentCPSelected;

// Initialization
- (instancetype)initWithPanelView:(ChartPanelView *)panelView
                   objectsManager:(ChartObjectsManager *)objectsManager;

#pragma mark - Coordinate System

/// Convert control point to screen coordinates
/// @param controlPoint The control point to convert
/// @return Screen point in panel coordinates
- (NSPoint)screenPointFromControlPoint:(ControlPointModel *)controlPoint;

/// Convert screen point to control point (for creation/editing)
/// @param screenPoint Screen coordinates in panel
/// @param indicatorRef Reference indicator ("close", "high", "low", "open")
/// @return New control point model
- (ControlPointModel *)controlPointFromScreenPoint:(NSPoint)screenPoint
                                       indicatorRef:(NSString *)indicatorRef;

/// Update coordinate context (called when viewport changes)
/// @param chartData Current chart data
/// @param startIndex Visible start index
/// @param endIndex Visible end index
/// @param yMin Y-axis minimum value
/// @param yMax Y-axis maximum value
/// @param bounds Panel bounds
- (void)updateCoordinateContext:(NSArray<HistoricalBarModel *> *)chartData
                     startIndex:(NSInteger)startIndex
                       endIndex:(NSInteger)endIndex
                      yRangeMin:(double)yMin
                      yRangeMax:(double)yMax
                         bounds:(CGRect)bounds;

#pragma mark - Rendering

/// Render all static objects to objectsLayer
- (void)renderAllObjects;

/// Render specific object to objectsLayer
/// @param object Object to render
- (void)renderObject:(ChartObjectModel *)object;

/// Render editing object to objectsEditingLayer
- (void)renderEditingObject;

/// Force redraw of static objects layer
- (void)invalidateObjectsLayer;

/// Force redraw of editing layer only
- (void)invalidateEditingLayer;

#pragma mark - Object Creation/Editing

/// Start creating new object
/// @param objectType Type of object to create
- (void)startCreatingObjectOfType:(ChartObjectType)objectType;

/// Add control point during creation
/// @param screenPoint Screen coordinates where user clicked
- (BOOL)addControlPointAtScreenPoint:(NSPoint)screenPoint;

/// Update preview during mouse movement in creation mode
/// @param screenPoint Current mouse position
- (void)updateCreationPreviewAtPoint:(NSPoint)screenPoint;

/// Update hover state during mouse movement in editing mode
/// @param screenPoint Current mouse position
- (void)updateEditingHoverAtPoint:(NSPoint)screenPoint;

/// NEW: Update current CP coordinates (unified for creation/editing)
/// @param screenPoint New coordinates for current selected CP
- (void)updateCurrentCPCoordinates:(NSPoint)screenPoint;

/// NEW: Select a control point for editing
/// @param controlPoint CP to select
- (void)selectControlPointForEditing:(ControlPointModel *)controlPoint;

/// Finish creating current object
- (void)finishCreatingObject;

/// Cancel object creation
- (void)cancelCreatingObject;

/// Start editing existing object
/// @param object Object to edit
- (void)startEditingObject:(ChartObjectModel *)object;

/// Stop editing current object
- (void)stopEditing;

#pragma mark - Hit Testing

/// Find object at screen point
/// @param point Screen coordinates
/// @param tolerance Hit test tolerance in pixels
/// @return Object at point or nil
- (nullable ChartObjectModel *)objectAtScreenPoint:(NSPoint)point
                                          tolerance:(CGFloat)tolerance;

/// Find control point at screen point
/// @param point Screen coordinates
/// @param tolerance Hit test tolerance in pixels
/// @return Control point at point or nil
- (nullable ControlPointModel *)controlPointAtScreenPoint:(NSPoint)point
                                                tolerance:(CGFloat)tolerance;

/// Check if point is within object bounds
/// @param point Screen coordinates
/// @param object Object to test
/// @param tolerance Hit test tolerance in pixels
/// @return YES if point is within object
- (BOOL)isPoint:(NSPoint)point withinObject:(ChartObjectModel *)object tolerance:(CGFloat)tolerance;

#pragma mark - Layer Management

/// Setup renderer layers in panel view
- (void)setupLayersInPanelView;

/// Update layer frames when panel bounds change
- (void)updateLayerFrames;


- (void)consolidateCurrentCPAndPrepareNext;
- (void)notifyObjectCreationCompleted;

- (void)setObjectsVisible:(BOOL)visible;
- (BOOL)areObjectsVisible;
@end

NS_ASSUME_NONNULL_END
