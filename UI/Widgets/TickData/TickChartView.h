//
//  TickChartView.h
//  mafia_AI
//
//  Custom view for displaying tick-by-tick price and volume chart
//

#import <Cocoa/Cocoa.h>
#import "TickDataModel.h"

@class TickChartWidget;

@interface TickChartView : NSView

@property (nonatomic, weak) TickChartWidget *widget;
@property (nonatomic, strong) NSArray<TickDataModel *> *tickData;

// Chart configuration
@property (nonatomic) BOOL showVolume;          // Show volume bars below price
@property (nonatomic) BOOL showVWAP;            // Show VWAP line
@property (nonatomic) BOOL showBuySellColors;   // Color code by direction

// Update methods
- (void)updateWithTickData:(NSArray<TickDataModel *> *)tickData;
- (void)redrawChart;

@end
