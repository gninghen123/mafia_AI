//
//  CHChartData.m
//  ChartWidget
//
//  Implementation of chart data management
//

#import "CHChartData.h"
#import "CHDataPoint.h"

@interface CHChartData ()
@property (nonatomic, strong) NSMutableArray<NSMutableArray<CHDataPoint *> *> *mutableSeries;
@end

@implementation CHChartData

#pragma mark - Initialization

+ (instancetype)chartData {
    return [[self alloc] init];
}

+ (instancetype)chartDataWithSeries:(NSArray<NSArray<CHDataPoint *> *> *)series {
    CHChartData *data = [[self alloc] init];
    for (NSArray<CHDataPoint *> *singleSeries in series) {
        [data addSeries:singleSeries];
    }
    return data;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableSeries = [NSMutableArray array];
        _seriesNames = @[];
        _seriesColors = @[];
        _customMinX = CGFLOAT_MAX;
        _customMaxX = CGFLOAT_MAX;
        _customMinY = CGFLOAT_MAX;
        _customMaxY = CGFLOAT_MAX;
        _shouldNormalizeData = NO;
        _shouldSortByX = NO;
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CHChartData *copy = [[CHChartData allocWithZone:zone] init];
    
    // Deep copy series
    for (NSArray<CHDataPoint *> *series in self.mutableSeries) {
        NSMutableArray<CHDataPoint *> *seriesCopy = [NSMutableArray array];
        for (CHDataPoint *point in series) {
            [seriesCopy addObject:[point copy]];
        }
        [copy.mutableSeries addObject:seriesCopy];
    }
    
    copy.seriesNames = [self.seriesNames copy];
    copy.seriesColors = [self.seriesColors copy];
    copy.customMinX = self.customMinX;
    copy.customMaxX = self.customMaxX;
    copy.customMinY = self.customMinY;
    copy.customMaxY = self.customMaxY;
    copy.shouldNormalizeData = self.shouldNormalizeData;
    copy.shouldSortByX = self.shouldSortByX;
    
    return copy;
}

#pragma mark - Properties

- (NSInteger)seriesCount {
    return self.mutableSeries.count;
}

- (NSArray<NSArray<CHDataPoint *> *> *)allSeries {
    return [self.mutableSeries copy];
}

#pragma mark - Series Management

- (void)addSeries:(NSArray<CHDataPoint *> *)series {
    [self addSeries:series withName:nil];
}

- (void)addSeries:(NSArray<CHDataPoint *> *)series withName:(NSString *)name {
    if (!series) return;
    
    NSMutableArray<CHDataPoint *> *mutableSeries = [series mutableCopy];
    
    // Update series index for all points
    NSInteger seriesIndex = self.mutableSeries.count;
    for (NSInteger i = 0; i < mutableSeries.count; i++) {
        CHDataPoint *point = mutableSeries[i];
        point.seriesIndex = seriesIndex;
        point.pointIndex = i;
    }
    
    [self.mutableSeries addObject:mutableSeries];
    
    // Update metadata arrays
    if (name) {
        NSMutableArray *names = [self.seriesNames mutableCopy];
        [names addObject:name];
        self.seriesNames = names;
    }
    
    if (self.shouldSortByX) {
        [self sortSeriesAtIndex:seriesIndex];
    }
}

- (void)insertSeries:(NSArray<CHDataPoint *> *)series atIndex:(NSInteger)index {
    if (!series || index < 0 || index > self.mutableSeries.count) return;
    
    NSMutableArray<CHDataPoint *> *mutableSeries = [series mutableCopy];
    [self.mutableSeries insertObject:mutableSeries atIndex:index];
    
    // Update all series indices
    [self updateSeriesIndices];
}

- (void)removeSeries:(NSArray<CHDataPoint *> *)series {
    [self.mutableSeries removeObject:series];
    [self updateSeriesIndices];
}

- (void)removeSeriesAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.mutableSeries.count) return;
    
    [self.mutableSeries removeObjectAtIndex:index];
    
    // Update metadata
    if (index < self.seriesNames.count) {
        NSMutableArray *names = [self.seriesNames mutableCopy];
        [names removeObjectAtIndex:index];
        self.seriesNames = names;
    }
    
    if (index < self.seriesColors.count) {
        NSMutableArray *colors = [self.seriesColors mutableCopy];
        [colors removeObjectAtIndex:index];
        self.seriesColors = colors;
    }
    
    [self updateSeriesIndices];
}

- (void)removeAllSeries {
    [self.mutableSeries removeAllObjects];
    self.seriesNames = @[];
    self.seriesColors = @[];
}

#pragma mark - Data Access

- (NSArray<CHDataPoint *> *)seriesAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.mutableSeries.count) return nil;
    return [self.mutableSeries[index] copy];
}

- (CHDataPoint *)dataPointInSeries:(NSInteger)seriesIndex atIndex:(NSInteger)pointIndex {
    if (seriesIndex < 0 || seriesIndex >= self.mutableSeries.count) return nil;
    
    NSArray<CHDataPoint *> *series = self.mutableSeries[seriesIndex];
    if (pointIndex < 0 || pointIndex >= series.count) return nil;
    
    return series[pointIndex];
}

- (NSString *)nameForSeriesAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.seriesNames.count) return nil;
    return self.seriesNames[index];
}

- (NSColor *)colorForSeriesAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.seriesColors.count) return nil;
    return self.seriesColors[index];
}

#pragma mark - Data Manipulation

- (void)sortAllSeriesByX {
    for (NSInteger i = 0; i < self.mutableSeries.count; i++) {
        [self sortSeriesAtIndex:i];
    }
}

- (void)sortSeriesAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.mutableSeries.count) return;
    
    NSMutableArray<CHDataPoint *> *series = self.mutableSeries[index];
    [series sortUsingComparator:^NSComparisonResult(CHDataPoint *p1, CHDataPoint *p2) {
        if (p1.x < p2.x) return NSOrderedAscending;
        if (p1.x > p2.x) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    // Update point indices
    for (NSInteger i = 0; i < series.count; i++) {
        series[i].pointIndex = i;
    }
}

- (void)applyTransform:(CGAffineTransform)transform {
    for (NSInteger i = 0; i < self.mutableSeries.count; i++) {
        [self applyTransform:transform toSeriesAtIndex:i];
    }
}

- (void)applyTransform:(CGAffineTransform)transform toSeriesAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.mutableSeries.count) return;
    
    NSMutableArray<CHDataPoint *> *series = self.mutableSeries[index];
    for (CHDataPoint *point in series) {
        CGPoint transformed = CGPointApplyAffineTransform(CGPointMake(point.x, point.y), transform);
        point.x = transformed.x;
        point.y = transformed.y;
    }
}

#pragma mark - Statistics

- (CGFloat)minXValue {
    CGFloat minX = CGFLOAT_MAX;
    
    for (NSArray<CHDataPoint *> *series in self.mutableSeries) {
        for (CHDataPoint *point in series) {
            minX = MIN(minX, point.x);
        }
    }
    
    return minX == CGFLOAT_MAX ? 0 : minX;
}

- (CGFloat)maxXValue {
    CGFloat maxX = -CGFLOAT_MAX;
    
    for (NSArray<CHDataPoint *> *series in self.mutableSeries) {
        for (CHDataPoint *point in series) {
            maxX = MAX(maxX, point.x);
        }
    }
    
    return maxX == -CGFLOAT_MAX ? 0 : maxX;
}

- (CGFloat)minYValue {
    CGFloat minY = CGFLOAT_MAX;
    
    for (NSArray<CHDataPoint *> *series in self.mutableSeries) {
        for (CHDataPoint *point in series) {
            minY = MIN(minY, point.y);
        }
    }
    
    return minY == CGFLOAT_MAX ? 0 : minY;
}

- (CGFloat)maxYValue {
    CGFloat maxY = -CGFLOAT_MAX;
    
    for (NSArray<CHDataPoint *> *series in self.mutableSeries) {
        for (CHDataPoint *point in series) {
            maxY = MAX(maxY, point.y);
        }
    }
    
    return maxY == -CGFLOAT_MAX ? 0 : maxY;
}

- (CGFloat)meanYValueForSeriesAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.mutableSeries.count) return 0;
    
    NSArray<CHDataPoint *> *series = self.mutableSeries[index];
    if (series.count == 0) return 0;
    
    CGFloat sum = 0;
    for (CHDataPoint *point in series) {
        sum += point.y;
    }
    
    return sum / series.count;
}

- (CGFloat)sumYValuesForSeriesAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.mutableSeries.count) return 0;
    
    CGFloat sum = 0;
    for (CHDataPoint *point in self.mutableSeries[index]) {
        sum += point.y;
    }
    
    return sum;
}

#pragma mark - Convenience Methods

- (BOOL)isEmpty {
    return self.mutableSeries.count == 0;
}

- (NSInteger)maxPointCountInAnySeries {
    NSInteger maxCount = 0;
    
    for (NSArray<CHDataPoint *> *series in self.mutableSeries) {
        maxCount = MAX(maxCount, series.count);
    }
    
    return maxCount;
}

- (NSInteger)totalPointCount {
    NSInteger total = 0;
    
    for (NSArray<CHDataPoint *> *series in self.mutableSeries) {
        total += series.count;
    }
    
    return total;
}

#pragma mark - Private Methods

- (void)updateSeriesIndices {
    for (NSInteger seriesIndex = 0; seriesIndex < self.mutableSeries.count; seriesIndex++) {
        NSArray<CHDataPoint *> *series = self.mutableSeries[seriesIndex];
        for (NSInteger pointIndex = 0; pointIndex < series.count; pointIndex++) {
            CHDataPoint *point = series[pointIndex];
            point.seriesIndex = seriesIndex;
            point.pointIndex = pointIndex;
        }
    }
}

@end
