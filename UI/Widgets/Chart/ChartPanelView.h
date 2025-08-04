//
//  ChartPanelView.h
//  TradingApp
//
//  Individual chart panel for rendering specific indicators
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"

@class ChartWidget;

@interface ChartPanelView : NSView

// Panel configuration
@property (nonatomic, strong) NSString *panelType; // "security", "volume", etc.
@property (nonatomic, weak) ChartWidget *chartWidget;

// Data
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *chartData;
@property (nonatomic, assign) NSInteger visibleStartIndex;
@property (nonatomic, assign) NSInteger visibleEndIndex;
@property (nonatomic, assign) double yRangeMin;
@property (nonatomic, assign) double yRangeMax;

// Interaction
@property (nonatomic, assign) NSPoint crosshairPoint;
@property (nonatomic, assign) BOOL crosshairVisible;

// Performance layers
@property (nonatomic, strong) CALayer *chartContentLayer;
@property (nonatomic, strong) CALayer *crosshairLayer;
@property (nonatomic, strong) CALayer *selectionLayer;

// Initialization
- (instancetype)initWithType:(NSString *)type;

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

@end
