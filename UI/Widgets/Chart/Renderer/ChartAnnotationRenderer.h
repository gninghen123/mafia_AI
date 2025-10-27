//
//  ChartAnnotationRenderer.h
//  mafia_AI
//
//  Rendering layer for chart annotations
//  Handles visual display and coordinate conversion
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ChartAnnotation.h"

NS_ASSUME_NONNULL_BEGIN

@class ChartAnnotationsManager;
@class ChartPanelView;
@class ChartAnnotationMarker;

/**
 * Renderer for chart annotations
 *
 * Responsibilities:
 * - Rendering markers on chart
 * - Coordinate conversion (delegates to ChartPanelView)
 * - Visual updates (position, visibility)
 *
 * Does NOT handle:
 * - Data loading (done by ChartAnnotationsManager)
 * - Filtering (done by ChartAnnotationsManager)
 * - Business logic (done by ChartAnnotationsManager)
 */
@interface ChartAnnotationRenderer : NSObject

#pragma mark - References

/**
 * Weak reference to the chart panel view (coordinator)
 */
@property (nonatomic, weak) ChartPanelView *panelView;

/**
 * Reference to the annotations manager (data source)
 */
@property (nonatomic, strong) ChartAnnotationsManager *manager;

/**
 * Parent layer for annotations
 */
@property (nonatomic, weak) CALayer *annotationsLayer;

#pragma mark - State

/**
 * Currently displayed markers
 */
@property (nonatomic, strong, readonly) NSArray<ChartAnnotationMarker *> *visibleMarkers;

#pragma mark - Initialization

/**
 * Initialize with panel view and manager
 */
- (instancetype)initWithPanelView:(ChartPanelView *)panelView
                          manager:(ChartAnnotationsManager *)manager;

#pragma mark - Rendering

/**
 * Render all annotations in the specified layer
 * Creates markers for filtered annotations from manager
 * @param layer Parent layer for annotation markers
 */
- (void)renderInLayer:(CALayer *)layer;

/**
 * Update positions of all markers
 * Call this when chart pans/zooms
 */
- (void)updateAllMarkerPositions;

/**
 * Clear all markers
 */
- (void)clearAllMarkers;

/**
 * Force full re-render
 * Removes all markers and recreates them
 */
- (void)invalidate;

#pragma mark - Coordinate Conversion

/**
 * Convert date to screen position
 * Delegates to panelView for coordinate conversion
 * @param date Date to convert
 * @return Screen position (CGPoint) or CGPointZero if date not visible
 */
- (CGPoint)screenPositionForDate:(NSDate *)date;

/**
 * Check if date is visible in current chart range
 */
- (BOOL)isDateVisible:(NSDate *)date;

#pragma mark - Interaction

/**
 * Get marker at screen point
 * @param point Screen point
 * @param tolerance Hit test tolerance in pixels
 * @return Marker at point or nil
 */
- (nullable ChartAnnotationMarker *)markerAtPoint:(CGPoint)point
                                        tolerance:(CGFloat)tolerance;

/**
 * Get all markers near a point
 */
- (NSArray<ChartAnnotationMarker *> *)markersNearPoint:(CGPoint)point
                                             tolerance:(CGFloat)tolerance;

@end

#pragma mark - ChartAnnotationMarker

/**
 * Visual marker for a single annotation
 * Simple view that displays icon + optional popup
 */
@interface ChartAnnotationMarker : NSView

@property (nonatomic, strong) ChartAnnotation *annotation;
@property (nonatomic, assign) CGPoint chartPosition;
@property (nonatomic, strong) CAShapeLayer *iconLayer;
@property (nonatomic, strong) NSTextField *popupLabel;
@property (nonatomic, assign) BOOL isHighlighted;

- (instancetype)initWithAnnotation:(ChartAnnotation *)annotation;
- (void)updatePosition:(CGPoint)position;
- (void)showPopup;
- (void)hidePopup;

@end

NS_ASSUME_NONNULL_END
