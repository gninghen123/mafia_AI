//
//  ChartAlertRenderer.h
//  TradingApp
//
//  Alert rendering engine for chart panels with drag-to-edit functionality
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"
#import "SharedXCoordinateContext.h"
#import "PanelYCoordinateContext.h"


@class ChartPanelView;
@class HistoricalBarModel;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Chart Alert Renderer

@interface ChartAlertRenderer : NSObject

// Context and dependencies
@property (nonatomic, weak) ChartPanelView *panelView;


@property (nonatomic, weak) SharedXCoordinateContext *sharedXContext;      // WEAK - shared
@property (nonatomic, strong) PanelYCoordinateContext *panelYContext;       // STRONG - owned

// Rendering layers (will be added to ChartPanelView)
@property (nonatomic, strong) CALayer *alertsLayer;        // Static alerts
@property (nonatomic, strong) CALayer *alertsEditingLayer; // Alert being dragged

// Data
@property (nonatomic, strong) NSArray<AlertModel *> *alerts;

// Editing state
@property (nonatomic, strong, nullable) AlertModel *draggingAlert;
@property (nonatomic, assign, readonly) BOOL isInAlertDragMode;
@property (nonatomic, assign) NSPoint dragStartPoint;
@property (nonatomic, assign) double originalTriggerValue;

#pragma mark - Initialization

/// Initialize alert renderer for chart panel
/// @param panelView The chart panel view that will contain alert layers
- (instancetype)initWithPanelView:(ChartPanelView *)panelView;

#pragma mark - Coordinate Context

/// Update coordinate context for price/screen conversions
/// @param chartData Current chart data
/// @param startIndex Visible start index
/// @param endIndex Visible end index
/// @param yMin Y-axis minimum value
/// @param yMax Y-axis maximum value
/// @param bounds Panel bounds
/// @param symbol Current symbol
- (void)updateCoordinateContext:(NSArray<HistoricalBarModel *> *)chartData
                     startIndex:(NSInteger)startIndex
                       endIndex:(NSInteger)endIndex
                      yRangeMin:(double)yMin
                      yRangeMax:(double)yMax
                         bounds:(CGRect)bounds
                  currentSymbol:(NSString *)symbol;

#pragma mark - Data Management

/// Refresh alerts from DataHub for current symbol
- (void)refreshAlerts;

/// Load alerts for specific symbol
/// @param symbol Stock symbol
- (void)loadAlertsForSymbol:(NSString *)symbol;

#pragma mark - Rendering

/// Render all static alerts to alertsLayer
- (void)renderAllAlerts;

/// Force redraw of static alerts layer
- (void)invalidateAlertsLayer;

/// Force redraw of editing layer only
- (void)invalidateAlertsEditingLayer;

#pragma mark - Hit Testing

/// Find alert at screen point
/// @param screenPoint Point in panel coordinates
/// @param tolerance Hit test tolerance in pixels
/// @return AlertModel if found, nil otherwise
- (nullable AlertModel *)alertAtScreenPoint:(NSPoint)screenPoint tolerance:(CGFloat)tolerance;

#pragma mark - Coordinate Conversion

/// Convert alert trigger value to screen Y coordinate
/// @param triggerValue Alert price value
/// @return Y coordinate in panel
- (CGFloat)screenYForTriggerValue:(double)triggerValue;

/// Convert screen Y coordinate to price value
/// @param screenY Y coordinate in panel
/// @return Price value
- (double)triggerValueForScreenY:(CGFloat)screenY;

#pragma mark - Alert Drag Operations

/// Start dragging alert
/// @param alert Alert to drag
/// @param screenPoint Initial drag point
- (void)startDraggingAlert:(AlertModel *)alert atPoint:(NSPoint)screenPoint;

/// Update drag position
/// @param screenPoint Current mouse position
- (void)updateDragToPoint:(NSPoint)screenPoint;

/// Finish drag operation with confirmation
- (void)finishDragWithConfirmation;

/// Cancel drag operation
- (void)cancelDrag;

#pragma mark - Alert Creation Helper

/// Create alert at screen point (for context menu)
/// @param screenPoint Where user right-clicked
/// @return Pre-configured AlertModel with price set
- (AlertModel *)createAlertTemplateAtScreenPoint:(NSPoint)screenPoint;

#pragma mark - Shared X Context Update

/// Update shared X context reference
/// @param sharedXContext Shared X coordinate context
- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext;
@end

NS_ASSUME_NONNULL_END
