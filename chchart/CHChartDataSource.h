//
//  CHChartDataSource.h
//  ChartWidget
//
//  Protocol for providing data to chart views
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>


@class CHChartView;

@protocol CHChartDataSource <NSObject>

@required
// Number of data series in the chart
- (NSInteger)numberOfDataSeriesInChartView:(CHChartView *)chartView;

// Number of data points in a specific series
- (NSInteger)chartView:(CHChartView *)chartView numberOfPointsInSeries:(NSInteger)series;

// Value for a specific point in a series
- (CGFloat)chartView:(CHChartView *)chartView valueForSeries:(NSInteger)series atIndex:(NSInteger)index;

@optional
// X value for a specific point (if not provided, index is used)
- (CGFloat)chartView:(CHChartView *)chartView xValueForSeries:(NSInteger)series atIndex:(NSInteger)index;

// Label for a data series
- (NSString *)chartView:(CHChartView *)chartView labelForSeries:(NSInteger)series;

// Color for a data series
- (NSColor *)chartView:(CHChartView *)chartView colorForSeries:(NSInteger)series;

// Label for a specific data point
- (NSString *)chartView:(CHChartView *)chartView labelForPointInSeries:(NSInteger)series atIndex:(NSInteger)index;

// Minimum and maximum values for Y axis (if not provided, calculated automatically)
- (CGFloat)minimumYValueInChartView:(CHChartView *)chartView;
- (CGFloat)maximumYValueInChartView:(CHChartView *)chartView;

// Minimum and maximum values for X axis (if not provided, calculated automatically)
- (CGFloat)minimumXValueInChartView:(CHChartView *)chartView;
- (CGFloat)maximumXValueInChartView:(CHChartView *)chartView;

@end
