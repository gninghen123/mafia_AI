//
//  ComparisonChartView.h
//  TradingApp
//
//  Custom NSView for comparing model statistics over time
//  Displays multi-line chart with coordinated crosshair
//

#import <Cocoa/Cocoa.h>
#import "BacktestModels.h"

NS_ASSUME_NONNULL_BEGIN

@class ComparisonChartView;

#pragma mark - Delegate Protocol

@protocol ComparisonChartViewDelegate <NSObject>
@optional

/// Called when crosshair moves (for coordinating with candlestick chart)
- (void)comparisonChartView:(ComparisonChartView *)chartView
     didMoveCrosshairToDate:(nullable NSDate *)date;

@end

#pragma mark - Comparison Chart View

@interface ComparisonChartView : NSView

#pragma mark - Properties

/// Delegate for user interactions
@property (nonatomic, weak, nullable) id<ComparisonChartViewDelegate> delegate;

/// Backtest session with results
@property (nonatomic, strong, nullable) BacktestSession *session;

/// Currently displayed metric key
/// Valid values: "symbolCount", "winRate", "avgGain", "avgLoss", "tradeCount", "winLossRatio"
@property (nonatomic, strong, nullable) NSString *metricKey;

/// Model colors (modelID → NSColor)
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSColor *> *modelColors;

#pragma mark - Crosshair

/// Whether to show crosshair
@property (nonatomic, assign) BOOL showCrosshair;

/// Crosshair X position (in view coordinates)
@property (nonatomic, assign) CGFloat crosshairX;

#pragma mark - Public Methods

/**
 * Set backtest session and update display
 * @param session BacktestSession with daily results
 * @param metricKey Metric to display
 * @param colors Dictionary mapping modelID to NSColor
 */
- (void)setSession:(BacktestSession *)session
        metricKey:(NSString *)metricKey
      modelColors:(NSDictionary<NSString *, NSColor *> *)colors;

/**
 * Update displayed metric
 * @param metricKey New metric to display
 */
- (void)setMetricKey:(NSString *)metricKey;

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
