//
//  ChartPanelView.h
//  TradingApp
//
//  Individual chart panel for rendering specific indicators
//  UPDATED: Includes ChartObjectRenderer integration
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"
#import "ChartObjectModels.h"
#import "ChartAlertRenderer.h"
#import "AlertEditController.h"
#import "ChartObjectSettingsWindow.h"
#import "SharedXCoordinateContext.h"
#import "PanelYCoordinateContext.h"
#pragma mark - Import ChartWidget for constants
#import "ChartWidget.h"  // Per accedere a CHART_Y_AXIS_WIDTH, CHART_MARGIN_LEFT, CHART_MARGIN_RIGHT

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
    
    // Convenience combinations
    ChartLayerInvalidationNativeAll      = (ChartLayerInvalidationChartContent |
                                            ChartLayerInvalidationYAxis |
                                            ChartLayerInvalidationCrosshair |
                                            ChartLayerInvalidationSelection),
                                            
    ChartLayerInvalidationExternalAll    = (ChartLayerInvalidationObjects |
                                            ChartLayerInvalidationObjectsEditing |
                                            ChartLayerInvalidationAlerts |
                                            ChartLayerInvalidationAlertsEditing),
                                            
    ChartLayerInvalidationAll            = (ChartLayerInvalidationNativeAll |
                                            ChartLayerInvalidationExternalAll)
};


@class ChartAlertRenderer;
@class ChartWidget;
@class ChartObjectRenderer;
@class ChartObjectsManager;

@interface ChartPanelView : NSView

@property (nonatomic, strong) CALayer *yAxisLayer;

@property (nonatomic, weak) SharedXCoordinateContext *sharedXContext;     // WEAK - shared
@property (nonatomic, strong) PanelYCoordinateContext *panelYContext;

@property (nonatomic, weak) ChartObjectSettingsWindow *objectSettingsWindow;

@property (nonatomic, strong) ChartAlertRenderer *alertRenderer;

// Panel configuration
@property (nonatomic, strong) NSString *panelType; // "security", "volume", etc.
@property (nonatomic, weak) ChartWidget *chartWidget;
@property (nonatomic, strong) NSButton *logScaleCheckbox;  // 🆕 NEW: Checkbox per scala logaritmica

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

// NUOVO: Objects rendering
@property (nonatomic, strong) ChartObjectRenderer *objectRenderer;

@property (nonatomic, strong, nullable) ChartObjectSettingsWindow *activeSettingsWindow;


- (void)setupAlertRenderer;

// NUOVO: Alert interaction
- (void)startEditingAlertAtPoint:(NSPoint)point;
- (void)stopEditingAlert;

// Initialization
- (instancetype)initWithType:(NSString *)type;

// NUOVO: Setup with objects manager
- (void)setupObjectsRendererWithManager:(ChartObjectsManager *)objectsManager;

// Data update
- (void)updateWithData:(NSArray<HistoricalBarModel *> *)data
            startIndex:(NSInteger)startIndex
              endIndex:(NSInteger)endIndex;


// Rendering
- (void)setCrosshairPoint:(NSPoint)point visible:(BOOL)visible;

// NUOVO: Objects interaction
- (void)startCreatingObjectOfType:(ChartObjectType)objectType;
- (void)startEditingObjectAtPoint:(NSPoint)point;
- (void)stopEditingObject;

- (void)drawYAxisContent;
- (double)calculateOptimalTickStep:(double)range targetTicks:(NSInteger)targetTicks;

- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext;



// ============================================================
// NUOVI METODI: Gestione Y Range autonoma
// ============================================================

/// Calcola automaticamente il range Y in base al panelType e ai dati visibili
- (void)calculateOwnYRange;

/// Calcola Y range per pannello security (prezzi OHLC)
- (void)calculateSecurityYRange:(NSInteger)startIdx endIndex:(NSInteger)endIdx;

/// Calcola Y range per pannello volume (0 - maxVolume)
- (void)calculateVolumeYRange:(NSInteger)startIdx endIndex:(NSInteger)endIdx;

/// Esegue pan verticale locale (solo security panel)
- (void)panVerticallyWithDelta:(CGFloat)deltaY;

/// Reset del pan verticale ai valori originali
- (void)resetYRangeOverride;


#pragma mark - Unified Layer Management

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
/// Updates SharedXContext for external renderers and invalidates coordinate-dependent layers
/// @param reason Debug string describing the coordinate change
- (void)invalidateCoordinateDependentLayersWithReason:(NSString * _Nullable)reason;

/// Lightweight method for mouse-driven updates (crosshair, hover effects)
/// Only invalidates lightweight layers for optimal performance
- (void)invalidateInteractionLayers;

/// Emergency method to force redraw of everything
/// Should be used sparingly, only when layer state is corrupted
- (void)forceRedrawAllLayers;

@end
