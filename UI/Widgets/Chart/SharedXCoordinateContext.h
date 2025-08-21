// SharedXCoordinateContext.h
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

extern const CGFloat CHART_Y_AXIS_WIDTH;
extern const CGFloat CHART_MARGIN_LEFT;
extern const CGFloat CHART_MARGIN_RIGHT;

@class HistoricalBarModel;

NS_ASSUME_NONNULL_BEGIN

/// Shared X-axis coordinate context for all chart panels
/// Manages bar positioning, spacing, and horizontal navigation
@interface SharedXCoordinateContext : NSObject

#pragma mark - Chart Data Context (X-axis only)
@property (nonatomic, strong, nullable) NSArray<HistoricalBarModel *> *chartData;
@property (nonatomic, assign) NSInteger visibleStartIndex;
@property (nonatomic, assign) NSInteger visibleEndIndex;
@property (nonatomic, assign) CGFloat containerWidth;  // ✅ RENAMED

#pragma mark - Trading Context (for X-axis calculations)
@property (nonatomic, assign) NSInteger barsPerDay;
@property (nonatomic, assign) NSInteger currentTimeframeMinutes;

#pragma mark - X Coordinate Conversion Methods
- (CGFloat)screenXForBarCenter:(NSInteger)barIndex;
- (CGFloat)screenXForBarIndex:(NSInteger)barIndex;
- (NSInteger)barIndexForScreenX:(CGFloat)screenX;
- (CGFloat)screenXForDate:(NSDate *)date;
- (CGFloat)chartAreaWidth;
- (CGFloat)barWidth;
- (CGFloat)barSpacing;

#pragma mark - Validation
- (BOOL)isValidForConversion;

@end

NS_ASSUME_NONNULL_END
