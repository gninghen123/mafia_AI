//
//  CHChartDelegate.h
//  ChartWidget
//
//  Protocol for handling chart interactions and events
//

#import <Foundation/Foundation.h>

@class CHChartView;
@class CHDataPoint;

@protocol CHChartDelegate <NSObject>

@optional
// Selection events
- (void)chartView:(CHChartView *)chartView didSelectDataPoint:(CHDataPoint *)dataPoint inSeries:(NSInteger)series;
- (void)chartViewDidDeselectDataPoint:(CHChartView *)chartView;

// Hover events
- (void)chartView:(CHChartView *)chartView didHoverOverDataPoint:(CHDataPoint *)dataPoint inSeries:(NSInteger)series;
- (void)chartViewDidEndHovering:(CHChartView *)chartView;

// Animation callbacks
- (void)chartViewWillBeginAnimating:(CHChartView *)chartView;
- (void)chartViewDidFinishAnimating:(CHChartView *)chartView;

// Customization
- (BOOL)chartView:(CHChartView *)chartView shouldSelectDataPoint:(CHDataPoint *)dataPoint inSeries:(NSInteger)series;
- (BOOL)chartView:(CHChartView *)chartView shouldAnimateTransition:(BOOL)animated;

// Zoom and pan events (for interactive charts)
- (void)chartView:(CHChartView *)chartView didZoomToScale:(CGFloat)scale;
- (void)chartView:(CHChartView *)chartView didPanByOffset:(CGPoint)offset;

// Drawing customization
- (void)chartView:(CHChartView *)chartView willDrawDataPoint:(CHDataPoint *)dataPoint inSeries:(NSInteger)series;
- (void)chartView:(CHChartView *)chartView didDrawDataPoint:(CHDataPoint *)dataPoint inSeries:(NSInteger)series;

@end
