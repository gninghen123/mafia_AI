//
//  ChartPanelView.h
//  TradingApp
//
//  Individual chart panel for rendering specific indicators
//  ✅ CLEANED: Contains only methods that exist in .m file
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"
#import "ChartObjectModels.h"
#import "ChartAlertRenderer.h"
#import "AlertEditController.h"
#import "ChartObjectSettingsWindow.h"
#import "SharedXCoordinateContext.h"
#import "PanelYCoordinateContext.h"
#import "ChartPanelTemplate+CoreDataClass.h"
#import "TechnicalIndicatorBase.h"

#pragma mark - Import ChartWidget for constants
#import "ChartWidget.h"

#pragma mark - Layer Invalidation Options

/// Bitmask options for layer invalidation control
typedef NS_OPTIONS(NSUInteger, ChartLayerInvalidationOptions) {
    ChartLayerInvalidationNone           = 0,
    
    // Native layers (owned by ChartPanelView)
    ChartLayerInvalidationChartContent   = 1 << 0,  ///< Candlesticks/Volume bars
    ChartLayerInvalidationYAxis          = 1 << 1,  ///< Y-axis ticks and labels
    ChartLayerInvalidationCrosshair      = 1 << 2,  ///< Crosshair lines and bubbles
    ChartLayerInvalidationSelection      = 1 << 3,  ///< Chart portion selection rectangle
    
    // External renderer layers
    ChartLayerInvalidationObjects        = 1 << 4,  ///< Chart objects (trend lines, etc.)
    ChartLayerInvalidationObjectsEditing = 1 << 5,  ///< Object being edited/created
    ChartLayerInvalidationAlerts         = 1 << 6,  ///< Alert markers
    ChartLayerInvalidationAlertsEditing  = 1 << 7,  ///< Alert being dragged
    ChartLayerInvalidationIndicators     = 1 << 8,  ///< Technical indicators (SMA, RSI, etc.)
    
    // Convenience combinations
    ChartLayerInvalidationNativeAll      = (ChartLayerInvalidationChartContent |
                                            ChartLayerInvalidationYAxis |
                                            ChartLayerInvalidationCrosshair |
                                            ChartLayerInvalidationSelection),
                                            
    ChartLayerInvalidationExternalAll    = (ChartLayerInvalidationObjects |
                                            ChartLayerInvalidationObjectsEditing |
                                            ChartLayerInvalidationAlerts |
                                            ChartLayerInvalidationAlertsEditing |
                                            ChartLayerInvalidationIndicators),
                                            
    ChartLayerInvalidationAll            = (ChartLayerInvalidationNativeAll |
                                            ChartLayerInvalidationExternalAll)
};

// Forward declarations
@class ChartPanelTemplate;
@class ChartAlertRenderer;
@class ChartWidget;
@class ChartObjectRenderer;
@class ChartObjectsManager;
@class ChartIndicatorRenderer;

@interface ChartPanelView : NSView

#pragma mark - Properties (from .m file)
@property (nonatomic, strong, nullable) ChartPanelTemplate *panelTemplate;
@property (nonatomic, strong) CALayer *yAxisLayer;
@property (nonatomic, weak) SharedXCoordinateContext *sharedXContext;
@property (nonatomic, strong) PanelYCoordinateContext *panelYContext;
@property (nonatomic, weak) ChartObjectSettingsWindow *objectSettingsWindow;

// Panel configuration
@property (nonatomic, strong) NSString *panelType;
@property (nonatomic, weak) ChartWidget *chartWidget;
@property (nonatomic, strong) NSButton *logScaleCheckbox;

// Data
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *chartData;
@property (nonatomic, assign) NSInteger visibleStartIndex;
@property (nonatomic, assign) NSInteger visibleEndIndex;
@property (nonatomic, assign) double yRangeMin;
@property (nonatomic, assign) double yRangeMax;
@property (nonatomic, assign) double dragThreshold;
@property (nonatomic, assign) BOOL isDragging;

// Interaction
@property (nonatomic, assign) NSPoint crosshairPoint;
@property (nonatomic, assign) BOOL crosshairVisible;

// Performance layers
@property (nonatomic, strong) CALayer *chartContentLayer;
@property (nonatomic, strong) CALayer *crosshairLayer;
@property (nonatomic, strong) CALayer *chartPortionSelectionLayer;

//  renderers
@property (nonatomic, strong) ChartObjectRenderer *objectRenderer;
@property (nonatomic, strong) ChartIndicatorRenderer *indicatorRenderer;
@property (nonatomic, strong) ChartAlertRenderer *alertRenderer;

@property (nonatomic, strong, nullable) ChartObjectSettingsWindow *activeSettingsWindow;

#pragma mark - Initialization
/// Initialize panel with type
/// @param type Panel type ("security", "volume", etc.)
- (instancetype)initWithType:(NSString *)type;

#pragma mark - Setup Methods
/// Setup alert renderer
- (void)setupAlertRenderer;

/// Setup objects renderer with manager
/// @param objectsManager Objects manager instance
- (void)setupObjectsRendererWithManager:(ChartObjectsManager *)objectsManager;

#pragma mark - Data Update Methods
/// Update panel with new data and visible range
/// @param data Chart data array
/// @param startIndex Visible start index
/// @param endIndex Visible end index
- (void)updateWithData:(NSArray<HistoricalBarModel *> *)data
            startIndex:(NSInteger)startIndex
              endIndex:(NSInteger)endIndex;

/// Update shared X coordinate context
/// @param sharedXContext Shared coordinate context
- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext;

#pragma mark - Rendering Methods
/// Set crosshair point and visibility
/// @param point Crosshair position
/// @param visible Whether crosshair should be visible
- (void)setCrosshairPoint:(NSPoint)point visible:(BOOL)visible;

/// Draw Y-axis content
- (void)drawYAxisContent;

/// Draw chart content (candlesticks, volume, etc.)
- (void)drawChartContent;

/// Draw empty state when no data
- (void)drawEmptyState;

/// Draw candlesticks (for security panel)
- (void)drawCandlesticks;

/// Draw volume histogram (for volume panel)
- (void)drawVolumeHistogram;

/// Draw chart portion selection
- (void)drawChartPortionSelection;

/// Draw chart portion selection content
- (void)drawChartPortionSelectionContent;

#pragma mark - Y-Range Management
/// Calculate automatic Y range based on panel type and visible data
- (void)calculateOwnYRange;

/// Calculate Y range for security panel (OHLC prices)
/// @param startIdx Start index
/// @param endIdx End index
- (void)calculateSecurityYRange:(NSInteger)startIdx endIndex:(NSInteger)endIdx;

/// Calculate Y range for volume panel (0 - maxVolume)
/// @param startIdx Start index
/// @param endIdx End index
- (void)calculateVolumeYRange:(NSInteger)startIdx endIndex:(NSInteger)endIdx;

/// Perform vertical pan (security panel only)
/// @param deltaY Pan delta in points
- (void)panVerticallyWithDelta:(CGFloat)deltaY;

/// Reset vertical pan to original values
- (void)resetYRangeOverride;

#pragma mark - Layer Management and Invalidation
/// Primary method for layer invalidation with fine-grained control
/// @param options Bitmask specifying which layers to invalidate
/// @param updateSharedXContext Whether to update SharedXContext for external renderers
/// @param reason Debug string describing why invalidation is needed
- (void)invalidateLayers:(ChartLayerInvalidationOptions)options
    updateSharedXContext:(BOOL)updateSharedXContext
                  reason:(NSString * _Nullable)reason;

/// Convenience method for layer invalidation without SharedXContext update
/// @param options Bitmask specifying which layers to invalidate
- (void)invalidateLayers:(ChartLayerInvalidationOptions)options;

/// Specialized method for coordinate system changes (zoom/pan)
/// @param reason Debug string describing the coordinate change
- (void)invalidateCoordinateDependentLayersWithReason:(NSString * _Nullable)reason;

/// Lightweight method for mouse-driven updates (crosshair, hover effects)
- (void)invalidateInteractionLayers;

/// Emergency method to force redraw of everything
- (void)forceRedrawAllLayers;

// Specific invalidation methods
- (void)invalidateCrosshairIfVisible;
- (void)invalidateObjectsEditingIfActive;
- (void)invalidateAlertsEditingIfActive;

#pragma mark - Object Interaction Methods
/// Start creating object of specified type
/// @param objectType Type of object to create
- (void)startCreatingObjectOfType:(ChartObjectType)objectType;

/// Start editing object at point
/// @param point Point where user clicked
- (void)startEditingObjectAtPoint:(NSPoint)point;

/// Stop editing current object
- (void)stopEditingObject;

#pragma mark - Alert Interaction Methods
/// Start editing alert at point
/// @param point Point where user clicked
- (void)startEditingAlertAtPoint:(NSPoint)point;

/// Stop editing current alert
- (void)stopEditingAlert;

#pragma mark - Utility Methods
/// Calculate optimal tick step for Y-axis
/// @param range Y-axis range
/// @param targetTicks Target number of ticks
/// @return Optimal tick step value
- (double)calculateOptimalTickStep:(double)range targetTicks:(NSInteger)targetTicks;

/// Format numeric value for display
/// @param value Numeric value to format
/// @return Formatted string for display
- (NSString *)formatNumericValueForDisplay:(double)value;

/// Get visible start index from chart widget
- (NSInteger)visibleStartIndex;

/// Get visible end index from chart widget
- (NSInteger)visibleEndIndex;

#pragma mark - Internal Helper Methods
/// Update external renderers shared X context
- (void)updateExternalRenderersSharedXContext;

/// Update shared X context and invalidate layers
/// @param sharedXContext Shared coordinate context
/// @param reason Reason for update
- (void)updateSharedXContextAndInvalidate:(SharedXCoordinateContext *)sharedXContext
                                   reason:(NSString *)reason;

/// Get current creation type from object renderer
- (ChartObjectType)getCurrentCreationTypeFromRenderer;

/// Handle object settings applied
/// @param object Object that had settings applied
- (void)handleObjectSettingsApplied:(ChartObjectModel *)object;

/// Check if point is near editing object
/// @param point Point to check
/// @param object Object being edited
/// @param tolerance Hit test tolerance
- (BOOL)isPoint:(NSPoint)point nearEditingObject:(ChartObjectModel *)object tolerance:(CGFloat)tolerance;

/// Find object that owns a control point
/// @param controlPoint Control point to search for
/// @return Object that contains the control point
- (ChartObjectModel *)findObjectOwningControlPoint:(ControlPointModel *)controlPoint;

@end
