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
- (void)invalidateChartContent; // Force redraw of chart data
- (void)updateCrosshairOnly;    // Update only crosshair layer

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


@end
