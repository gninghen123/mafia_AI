//
//  ChartAnnotationRenderer.h
//  TradingApp
//
//  Annotation rendering engine for chart panels with CALayer-based drawing
//  ✅ REFACTORED: Follows pattern of AlertRenderer/ObjectRenderer
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ChartAnnotation.h"

@class ChartPanelView;
@class ChartAnnotationsManager;
@class SharedXCoordinateContext;
@class PanelYCoordinateContext;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Chart Annotation Renderer

@interface ChartAnnotationRenderer : NSObject <CALayerDelegate>

#pragma mark - Context and Dependencies

/// Weak reference to the chart panel view
@property (nonatomic, weak) ChartPanelView *panelView;

/// Reference to the annotations manager (data source)
@property (nonatomic, strong) ChartAnnotationsManager *manager;

/// ✅ NEW: Coordinate contexts (matching other renderers)
@property (nonatomic, weak) SharedXCoordinateContext *sharedXContext;
@property (nonatomic, weak) PanelYCoordinateContext *panelYContext;

#pragma mark - Rendering Layers

/// Static annotations layer
@property (nonatomic, strong) CALayer *annotationsLayer;

#pragma mark - State

/// Currently displayed annotations (cached for performance)
@property (nonatomic, strong, readwrite) NSMutableArray<ChartAnnotation *> *visibleAnnotations;  // ✅ NSMutableArray

/// Hovered annotation (for interactive feedback)
@property (nonatomic, strong, nullable) ChartAnnotation *hoveredAnnotation;

#pragma mark - Initialization

/// Initialize annotation renderer for chart panel
/// @param panelView The chart panel view that will contain annotation layers
/// @param manager The annotations manager providing data
- (instancetype)initWithPanelView:(ChartPanelView *)panelView
                          manager:(ChartAnnotationsManager *)manager;

#pragma mark - Layer Management

/// Update layer frames when panel resizes
- (void)updateLayerFrames;

#pragma mark - Rendering

/// Render all visible annotations to annotationsLayer
- (void)renderAllAnnotations;

/// Force redraw of annotations layer
- (void)invalidateAnnotationsLayer;

/// Clear all rendered content
- (void)clearAllAnnotations;

#pragma mark - Coordinate Conversion

/// Convert annotation date to screen X coordinate
/// @param date Annotation date
/// @return X coordinate in panel, or -9999 if not visible
- (CGFloat)screenXForDate:(NSDate *)date;

/// Check if date is visible in current chart range
/// @param date Date to check
/// @return YES if date is within visible range
- (BOOL)isDateVisible:(NSDate *)date;

#pragma mark - Hit Testing

/// Find annotation at screen point
/// @param screenPoint Point in panel coordinates
/// @param tolerance Hit test tolerance in pixels
/// @return ChartAnnotation if found, nil otherwise
- (nullable ChartAnnotation *)annotationAtScreenPoint:(NSPoint)screenPoint
                                            tolerance:(CGFloat)tolerance;

/// Get all annotations near a point
/// @param screenPoint Point in panel coordinates
/// @param tolerance Hit test tolerance in pixels
/// @return Array of annotations near point
- (NSArray<ChartAnnotation *> *)annotationsNearPoint:(NSPoint)screenPoint
                                           tolerance:(CGFloat)tolerance;

#pragma mark - Interactive Feedback

/// Update hover state at mouse position
/// @param screenPoint Current mouse position
- (void)updateHoverAtPoint:(NSPoint)screenPoint;

/// Clear hover state
- (void)clearHover;

@end

NS_ASSUME_NONNULL_END
