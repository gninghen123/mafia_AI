//
// ChartIndicatorRenderer.h
// TradingApp
//
// Renderer for technical indicators display in chart panels
// Based on ChartObjectRenderer architecture
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "TechnicalIndicatorBase.h"

@class ChartPanelView;
@class SharedXCoordinateContext;
@class PanelYCoordinateContext;

NS_ASSUME_NONNULL_BEGIN

@interface ChartIndicatorRenderer : NSObject

#pragma mark - Initialization
@property (nonatomic, weak) ChartPanelView *panelView;
@property (nonatomic, strong) CALayer *indicatorsLayer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CAShapeLayer *> *indicatorLayers;
#pragma mark - Indicator Data Management
@property (nonatomic, strong, nullable) TechnicalIndicatorBase *rootIndicator;

@property (nonatomic, strong) NSMutableDictionary *cachedPathKeys;



/// Initialize renderer with panel view
/// @param panelView Parent chart panel view
- (instancetype)initWithPanelView:(ChartPanelView *)panelView;

#pragma mark - Rendering Management

/// Render entire indicator tree
/// @param rootIndicator Root indicator with child hierarchy
- (void)renderIndicatorTree:(TechnicalIndicatorBase *)rootIndicator;

/// Render single indicator
/// @param indicator Indicator to render
- (void)renderIndicator:(TechnicalIndicatorBase *)indicator;

/// Clear all indicator layers
- (void)clearIndicatorLayers;

/// Clear specific indicator layer
/// @param indicatorID Indicator identifier
- (void)clearIndicatorLayer:(NSString *)indicatorID;

/// Invalidate and refresh all indicator layers
- (void)invalidateIndicatorLayers;

/// Invalidate specific indicator layer
/// @param indicatorID Indicator identifier
- (void)invalidateIndicatorLayer:(NSString *)indicatorID;

#pragma mark - Layer Management

/// Setup indicators layer structure
- (void)setupIndicatorsLayer;

/// Update layer bounds when panel resizes
- (void)updateLayerBounds;

/// Get or create layer for indicator
/// @param indicatorID Indicator identifier
/// @return Shape layer for the indicator
- (CAShapeLayer *)getOrCreateLayerForIndicator:(NSString *)indicatorID;

/// Configure layer properties
/// @param layer Layer to configure
/// @param indicator Indicator providing styling information
- (void)configureLayer:(CAShapeLayer *)layer forIndicator:(TechnicalIndicatorBase *)indicator;

#pragma mark - Specialized Rendering Methods

/// Render line-based indicator (SMA, EMA, etc.)
/// @param indicator Line indicator to render
/// @param layer Target layer
- (void)renderLineIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

/// Render histogram indicator (Volume, MACD histogram)
/// @param indicator Histogram indicator to render
/// @param layer Target layer
- (void)renderHistogramIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

/// Render bands indicator (Bollinger Bands, Keltner Channels)
/// @param indicator Bands indicator to render
/// @param layer Target layer
- (void)renderBandsIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

/// Render oscillator indicator with reference lines (RSI, Stochastic)
/// @param indicator Oscillator indicator to render
/// @param layer Target layer
- (void)renderOscillatorIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

/// Render signal markers (buy/sell arrows, crosses)
/// @param indicator Signal indicator to render
/// @param layer Target layer
- (void)renderSignalIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

/// Render area fill indicator
/// @param indicator Area indicator to render
/// @param layer Target layer
- (void)renderAreaIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

#pragma mark - Path Creation Helpers

/// Create line path from indicator data points
/// @param dataPoints Array of IndicatorDataModel points
/// @return Bezier path for line rendering
- (NSBezierPath *)createLinePathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints;

/// Create histogram bars path from data points
/// @param dataPoints Array of IndicatorDataModel points
/// @param baselineY Y coordinate for histogram baseline
/// @return Bezier path for histogram rendering
- (NSBezierPath *)createHistogramPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints baselineY:(CGFloat)baselineY;

/// Create filled area path from data points
/// @param dataPoints Array of IndicatorDataModel points
/// @param baselineY Y coordinate for area baseline
/// @return Bezier path for area fill
- (NSBezierPath *)createAreaPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints baselineY:(CGFloat)baselineY;

/// Create bands path (upper and lower bounds with fill)
/// @param upperPoints Upper band data points
/// @param lowerPoints Lower band data points
/// @return Bezier path for bands rendering
- (NSBezierPath *)createBandsPathFromUpperPoints:(NSArray<IndicatorDataModel *> *)upperPoints
                                     lowerPoints:(NSArray<IndicatorDataModel *> *)lowerPoints;

#pragma mark - Coordinate Conversion

/// Convert timestamp to X coordinate
/// @param timestamp Data point timestamp
/// @return X coordinate in panel view
- (CGFloat)xCoordinateForTimestamp:(NSDate *)timestamp;

/// Convert indicator value to Y coordinate
/// @param value Indicator value
/// @return Y coordinate in panel view
- (CGFloat)yCoordinateForValue:(double)value;

/// Get bar index for timestamp
/// @param timestamp Data point timestamp
/// @return Bar index in chart data
- (NSInteger)barIndexForTimestamp:(NSDate *)timestamp;

/// Check if point is within visible range
/// @param timestamp Data point timestamp
/// @return YES if point should be rendered
- (BOOL)isTimestampInVisibleRange:(NSDate *)timestamp;

#pragma mark - Styling and Appearance

/// Get default line width for indicator type
/// @param indicator Indicator instance
/// @return Default line width
- (CGFloat)defaultLineWidthForIndicator:(TechnicalIndicatorBase *)indicator;

/// Get default stroke color for indicator
/// @param indicator Indicator instance
/// @return Default stroke color
- (NSColor *)defaultStrokeColorForIndicator:(TechnicalIndicatorBase *)indicator;

/// Get default fill color for indicator
/// @param indicator Indicator instance
/// @return Default fill color (for histograms, areas)
- (NSColor *)defaultFillColorForIndicator:(TechnicalIndicatorBase *)indicator;

/// Apply visual effects to layer (shadows, gradients)
/// @param layer Target layer
/// @param indicator Indicator providing style preferences
- (void)applyVisualEffectsToLayer:(CAShapeLayer *)layer forIndicator:(TechnicalIndicatorBase *)indicator;

#pragma mark - Performance Optimization

/// Check if indicator needs re-rendering
/// @param indicator Indicator to check
/// @return YES if rendering update is needed
- (BOOL)needsRenderingUpdate:(TechnicalIndicatorBase *)indicator;

/// Cache indicator rendering data for performance
/// @param indicator Indicator to cache
- (void)cacheRenderingDataForIndicator:(TechnicalIndicatorBase *)indicator;

/// Clear cached rendering data
/// @param indicatorID Indicator identifier
- (void)clearCachedDataForIndicator:(NSString *)indicatorID;

/// Batch render multiple indicators efficiently
/// @param indicators Array of indicators to render
- (void)batchRenderIndicators:(NSArray<TechnicalIndicatorBase *> *)indicators;

#pragma mark - Animation Support

/// Animate layer appearance
/// @param layer Layer to animate
/// @param duration Animation duration
- (void)animateLayerAppearance:(CAShapeLayer *)layer duration:(NSTimeInterval)duration;

/// Animate layer update
/// @param layer Layer to animate
/// @param newPath New path for animation
/// @param duration Animation duration
- (void)animateLayerUpdate:(CAShapeLayer *)layer newPath:(CGPathRef)newPath duration:(NSTimeInterval)duration;

/// Animate layer removal
/// @param layer Layer to remove
/// @param completion Completion block
- (void)animateLayerRemoval:(CAShapeLayer *)layer completion:(void(^)(void))completion;

#pragma mark - Error Handling and Validation

/// Validate indicator data before rendering
/// @param indicator Indicator to validate
/// @param error Error pointer for validation failures
/// @return YES if indicator can be rendered
- (BOOL)validateIndicatorForRendering:(TechnicalIndicatorBase *)indicator error:(NSError **)error;

/// Handle rendering errors gracefully
/// @param error Rendering error
/// @param indicator Failed indicator
- (void)handleRenderingError:(NSError *)error forIndicator:(TechnicalIndicatorBase *)indicator;

#pragma mark - Recursive Rendering

/// Render children indicators recursively
/// @param parentIndicator Parent indicator with children
- (void)renderChildrenRecursively:(TechnicalIndicatorBase *)parentIndicator;

/// Update Z-order for layered indicators
- (void)updateIndicatorLayerZOrder;

#pragma mark - Context Integration

/// Update shared X coordinate context
/// @param sharedXContext Shared X context from chart widget
- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext;

/// Update panel Y coordinate context
/// @param panelYContext Panel-specific Y context
- (void)updatePanelYContext:(PanelYCoordinateContext *)panelYContext;

#pragma mark - Cleanup

/// Cleanup resources and remove layers
- (void)cleanup;

/// Remove all layers from superlayer
- (void)removeAllLayers;
#pragma mark - Visibility Management

/// Toggle visibility of all child indicators (keeps root visible)
/// @param visible Whether child indicators should be visible
- (void)setChildIndicatorsVisible:(BOOL)visible;

#pragma mark - Batch Rendering
/// Render all indicators in the allIndicators array
- (void)renderAllIndicators;

/// Set all indicators for this renderer
/// @param indicators Array of all indicators to manage
/// @param rootIndicator Main indicator (should be in the array)
- (void)setIndicators:(NSArray<TechnicalIndicatorBase *> *)indicators rootIndicator:(TechnicalIndicatorBase *)rootIndicator;

@end

NS_ASSUME_NONNULL_END
