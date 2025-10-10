//
//  CandlestickChartView.h
//  TradingApp
//
//  Custom NSView for drawing candlestick charts with zoom and range selection
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@class CandlestickChartView;

#pragma mark - Delegate Protocol

@protocol CandlestickChartViewDelegate <NSObject>
@optional

/// Called when user selects a date range by dragging
- (void)candlestickChartView:(CandlestickChartView *)chartView
         didSelectDateRange:(NSDate *)startDate
                    endDate:(NSDate *)endDate;

/// Called when crosshair moves (for coordinating with comparison chart)
- (void)candlestickChartView:(CandlestickChartView *)chartView
       didMoveCrosshairToDate:(nullable NSDate *)date
                          bar:(nullable HistoricalBarModel *)bar;

@end

#pragma mark - Candlestick Chart View

@interface CandlestickChartView : NSView

#pragma mark - Properties

/// Delegate for user interactions
@property (nonatomic, weak, nullable) id<CandlestickChartViewDelegate> delegate;

/// Historical bars to display
@property (nonatomic, strong, nullable) NSArray<HistoricalBarModel *> *bars;

/// Symbol name (for display)
@property (nonatomic, strong, nullable) NSString *symbolName;

#pragma mark - Zoom & Range

/// Current visible range (indices in bars array)
@property (nonatomic, assign) NSInteger visibleStartIndex;
@property (nonatomic, assign) NSInteger visibleEndIndex;

#pragma mark - Crosshair

/// Whether to show crosshair
@property (nonatomic, assign) BOOL showCrosshair;

/// Crosshair X position (in view coordinates)
@property (nonatomic, assign) CGFloat crosshairX;

#pragma mark - Public Methods

/**
 * Set data and update display
 * @param bars Array of HistoricalBarModel objects (must be sorted by date ascending)
 * @param symbol Symbol name for display
 */
- (void)setData:(NSArray<HistoricalBarModel *> *)bars symbol:(NSString *)symbol;

/**
 * Zoom to specific date range
 * @param startDate Start date
 * @param endDate End date
 */
- (void)zoomToDateRange:(NSDate *)startDate endDate:(NSDate *)endDate;

/**
 * Zoom in (show fewer bars)
 */
- (void)zoomIn;

/**
 * Zoom out (show more bars)
 */
- (void)zoomOut;

/**
 * Reset zoom to show all bars
 */
- (void)zoomAll;

/**
 * Show crosshair at specific X coordinate (called from external)
 * @param x X coordinate in view space
 */
- (void)showCrosshairAtX:(CGFloat)x;

/**
 * Hide crosshair
 */
- (void)hideCrosshair;

@end

NS_ASSUME_NONNULL_END
