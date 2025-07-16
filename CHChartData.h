//
//  CHChartData.h
//  ChartWidget
//
//  Model class for managing chart data series
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@class CHDataPoint;

@interface CHChartData : NSObject <NSCopying>

// Series management
@property (nonatomic, readonly) NSInteger seriesCount;
@property (nonatomic, readonly) NSArray<NSArray<CHDataPoint *> *> *allSeries;

// Series metadata
@property (nonatomic, strong) NSArray<NSString *> *seriesNames;
@property (nonatomic, strong) NSArray<NSColor *> *seriesColors;

// Data bounds (custom override)
@property (nonatomic) CGFloat customMinX;
@property (nonatomic) CGFloat customMaxX;
@property (nonatomic) CGFloat customMinY;
@property (nonatomic) CGFloat customMaxY;

// Options
@property (nonatomic) BOOL shouldNormalizeData;
@property (nonatomic) BOOL shouldSortByX;

// Initialization
+ (instancetype)chartData;
+ (instancetype)chartDataWithSeries:(NSArray<NSArray<CHDataPoint *> *> *)series;

// Series management
- (void)addSeries:(NSArray<CHDataPoint *> *)series;
- (void)addSeries:(NSArray<CHDataPoint *> *)series withName:(NSString *)name;
- (void)insertSeries:(NSArray<CHDataPoint *> *)series atIndex:(NSInteger)index;
- (void)removeSeries:(NSArray<CHDataPoint *> *)series;
- (void)removeSeriesAtIndex:(NSInteger)index;
- (void)removeAllSeries;

// Data access
- (NSArray<CHDataPoint *> *)seriesAtIndex:(NSInteger)index;
- (CHDataPoint *)dataPointInSeries:(NSInteger)seriesIndex atIndex:(NSInteger)pointIndex;
- (NSString *)nameForSeriesAtIndex:(NSInteger)index;
- (NSColor *)colorForSeriesAtIndex:(NSInteger)index;

// Data manipulation
- (void)sortAllSeriesByX;
- (void)applyTransform:(CGAffineTransform)transform;
- (void)applyTransform:(CGAffineTransform)transform toSeriesAtIndex:(NSInteger)index;

// Statistics
- (CGFloat)minXValue;
- (CGFloat)maxXValue;
- (CGFloat)minYValue;
- (CGFloat)maxYValue;
- (CGFloat)meanYValueForSeriesAtIndex:(NSInteger)index;
- (CGFloat)sumYValuesForSeriesAtIndex:(NSInteger)index;

// Convenience methods
- (BOOL)isEmpty;
- (NSInteger)maxPointCountInAnySeries;
- (NSInteger)totalPointCount;

@end
