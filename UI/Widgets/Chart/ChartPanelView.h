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
@class ChartAlertRenderer;
#import "ChartAlertRenderer.h"
#import "AlertEditController.h"

@class ChartWidget;
@class ChartObjectRenderer;
@class ChartObjectsManager;

@interface ChartPanelView : NSView


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


@end
