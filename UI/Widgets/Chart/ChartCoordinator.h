//
//  ChartCoordinator.h
//  TradingApp
//
//  Coordinates crosshair, zoom, and pan between chart panels
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChartCoordinator : NSObject

#pragma mark - Crosshair State
@property (nonatomic, assign) NSPoint crosshairPosition;
@property (nonatomic, assign) BOOL crosshairVisible;

#pragma mark - Zoom and Pan State
@property (nonatomic, assign) CGFloat zoomFactor;          // 1.0 = normal, >1.0 = zoomed in
@property (nonatomic, assign) CGFloat panOffset;           // Horizontal pan offset
@property (nonatomic, assign) NSRange visibleBarsRange;    // Range of bars currently visible

#pragma mark - Data Context
@property (nonatomic, strong, nullable) NSArray<HistoricalBarModel *> *historicalData;
@property (nonatomic, assign) NSInteger maxVisibleBars;    // Maximum bars to show at once

#pragma mark - Coordinate Conversion
- (CGFloat)xPositionForBarIndex:(NSInteger)index inRect:(NSRect)rect;
- (CGFloat)yPositionForValue:(double)value inRange:(NSRange)valueRange rect:(NSRect)rect;
- (NSInteger)barIndexForXPosition:(CGFloat)x inRect:(NSRect)rect;
- (double)valueForYPosition:(CGFloat)y inRange:(NSRange)valueRange rect:(NSRect)rect;

#pragma mark - Event Handling
- (void)handleMouseMove:(NSPoint)point inRect:(NSRect)rect;
- (void)handleScroll:(CGFloat)deltaX deltaY:(CGFloat)deltaY inRect:(NSRect)rect;
- (void)handleZoom:(CGFloat)factor atPoint:(NSPoint)point inRect:(NSRect)rect;

#pragma mark - Data Management
- (void)updateHistoricalData:(NSArray<HistoricalBarModel *> *)data;
- (void)resetZoomAndPan;
- (void)autoFitToData;

#pragma mark - Value Range Calculation
- (NSRange)calculateValueRangeForData:(NSArray<HistoricalBarModel *> *)data
                                 type:(NSString *)indicatorType;

@end

NS_ASSUME_NONNULL_END
