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

#pragma mark - Constants for Y-Axis Layout

#define CHART_MARGIN_LEFT 10
#define CHART_MARGIN_RIGHT 10
#define Y_AXIS_WIDTH 60
#define CHART_MARGIN_RIGHT_WITH_AXIS (CHART_MARGIN_RIGHT + Y_AXIS_WIDTH)

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
              endIndex:(NSInteger)endIndex
             yRangeMin:(double)yMin
             yRangeMax:(double)yMax;

// Rendering
- (void)setCrosshairPoint:(NSPoint)point visible:(BOOL)visible;
- (void)invalidateChartContent; // Force redraw of chart data
- (void)updateCrosshairOnly;    // Update only crosshair layer

// NUOVO: Objects interaction
- (void)startCreatingObjectOfType:(ChartObjectType)objectType;
- (void)startEditingObjectAtPoint:(NSPoint)point;
- (void)stopEditingObject;


- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext;

@end
