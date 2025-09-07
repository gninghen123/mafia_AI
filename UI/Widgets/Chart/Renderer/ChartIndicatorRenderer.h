//
// ChartIndicatorRenderer.h
// TradingApp
//
// Renderer for technical indicators display in chart panels
// ✅ UPDATED: Native CGPath support for macOS compatibility
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "TechnicalIndicatorBase.h"

@class ChartPanelView;
@class SharedXCoordinateContext;
@class PanelYCoordinateContext;

NS_ASSUME_NONNULL_BEGIN

@interface ChartIndicatorRenderer : NSObject

#pragma mark - Properties
@property (nonatomic, weak) ChartPanelView *panelView;
@property (nonatomic, strong) CALayer *indicatorsLayer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CAShapeLayer *> *indicatorLayers;
@property (nonatomic, strong, nullable) TechnicalIndicatorBase *rootIndicator;
@property (nonatomic, strong) NSMutableDictionary *cachedPathKeys;

#pragma mark - Initialization
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

/// Update layer bounds with specific rect
/// @param bounds New bounds for layers
- (void)updateLayerBoundsWithRect:(CGRect)bounds;

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

/// Render area fill indicator
/// @param indicator Area indicator to render
/// @param layer Target layer
- (void)renderAreaIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

/// Render signal markers (buy/sell arrows, crosses)
/// @param indicator Signal indicator to render
/// @param layer Target layer
- (void)renderSignalIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

/// Render bands indicator (Bollinger Bands, Keltner Channels)
/// @param indicator Bands indicator to render
/// @param layer Target layer
- (void)renderBandsIndicator:(TechnicalIndicatorBase *)indicator layer:(CAShapeLayer *)layer;

#pragma mark - Path Creation Helpers - UPDATED FOR CGPATH
/// Create line CGPath from indicator data points
/// @param dataPoints Array of IndicatorDataModel points
/// @return CGPathRef for line rendering (CALLER MUST RELEASE)
- (CGPathRef)createCGLinePathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints CF_RETURNS_RETAINED;

/// Create histogram bars CGPath from data points
/// @param dataPoints Array of IndicatorDataModel points
/// @param baselineY Y coordinate for histogram baseline
/// @return CGPathRef for histogram rendering (CALLER MUST RELEASE)
- (CGPathRef)createCGHistogramPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints
                                       baselineY:(CGFloat)baselineY CF_RETURNS_RETAINED;

/// Create area CGPath from data points
/// @param dataPoints Array of IndicatorDataModel points
/// @param baselineY Y coordinate for area baseline
/// @return CGPathRef for area rendering (CALLER MUST RELEASE)
- (CGPathRef)createCGAreaPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints
                                  baselineY:(CGFloat)baselineY CF_RETURNS_RETAINED;

/// Create signal markers CGPath from data points
/// @param dataPoints Array of IndicatorDataModel points
/// @return CGPathRef for signal rendering (CALLER MUST RELEASE)
- (CGPathRef)createCGSignalPathFromDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints CF_RETURNS_RETAINED;

#pragma mark - Coordinate Conversion
/// Convert timestamp to X coordinate
/// @param timestamp Data point timestamp
/// @return X coordinate in panel
- (CGFloat)xCoordinateForTimestamp:(NSDate *)timestamp;

/// Convert value to Y coordinate
/// @param value Data point value
/// @return Y coordinate in panel
- (CGFloat)yCoordinateForValue:(double)value;

#pragma mark - Style and Color Helpers
/// Get default stroke color for indicator
/// @param indicator Indicator instance
/// @return Default stroke color
- (NSColor *)defaultStrokeColorForIndicator:(TechnicalIndicatorBase *)indicator;

/// Get default line width for indicator
/// @param indicator Indicator instance
/// @return Default line width
- (CGFloat)defaultLineWidthForIndicator:(TechnicalIndicatorBase *)indicator;

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

/// Check if path needs recalculation (legacy cache management)
/// @param indicator Indicator to check
/// @return YES if path needs recalculation
- (BOOL)needsPathRecalculation:(TechnicalIndicatorBase *)indicator;

/// Cache CGPath metadata for future reuse
/// @param indicator Indicator to cache path for
/// @param cgPath The CGPath to cache metadata for
- (void)cacheCGPathForIndicator:(TechnicalIndicatorBase *)indicator cgPath:(CGPathRef)cgPath;

/// Cache indicator rendering data for performance
/// @param indicator Indicator to cache
- (void)cacheRenderingDataForIndicator:(TechnicalIndicatorBase *)indicator;

/// Clear cached rendering data
/// @param indicatorID Indicator identifier
- (void)clearCachedDataForIndicator:(NSString *)indicatorID;

/// Batch render multiple indicators efficiently
/// @param indicators Array of indicators to render
- (void)batchRenderIndicators:(NSArray<TechnicalIndicatorBase *> *)indicators;

/// Batch render visible indicators with optimization
/// @param indicators Array of indicators to render in visible range
- (void)batchRenderVisibleIndicators:(NSArray<TechnicalIndicatorBase *> *)indicators;

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

#pragma mark - Cleanup
/// Cleanup resources and remove layers
- (void)cleanup;

/// Remove all layers from superlayer
- (void)removeAllLayers;

#pragma mark - Visibility Management
/// Toggle visibility of all child indicators (keeps root visible)
/// @param visible Whether child indicators should be visible
- (void)setChildIndicatorsVisible:(BOOL)visible;

/// Set visibility recursively for indicators
/// @param indicators Array of indicators to modify
/// @param visible Whether indicators should be visible
- (void)setVisibilityRecursively:(NSArray<TechnicalIndicatorBase *> *)indicators visible:(BOOL)visible;

/// Mark all indicators for re-rendering (sets needsRendering flag)
- (void)markAllIndicatorsForRerendering;

/// Mark indicators recursively for re-rendering
/// @param indicators Array of indicators to mark
- (void)markIndicatorsRecursively:(NSArray<TechnicalIndicatorBase *> *)indicators;

#pragma mark - Coordinate System - UPDATED FOR AUTO-RENDERING
/// Update coordinate contexts with auto-rendering
/// @param chartData Current chart data
/// @param startIndex Visible start index
/// @param endIndex Visible end index
/// @param yMin Y-axis minimum value
/// @param yMax Y-axis maximum value
/// @param bounds Panel bounds
- (void)updateCoordinateContext:(NSArray<HistoricalBarModel *> *)chartData
                     startIndex:(NSInteger)startIndex
                       endIndex:(NSInteger)endIndex
                      yRangeMin:(double)yMin
                      yRangeMax:(double)yMax
                         bounds:(CGRect)bounds;

/// Update shared X context reference with auto-rendering
/// @param sharedXContext Updated shared X coordinate context
- (void)updateSharedXContext:(SharedXCoordinateContext *)sharedXContext;

/// Update panel Y context reference with auto-rendering
/// @param panelYContext Updated panel Y coordinate context
- (void)updatePanelYContext:(PanelYCoordinateContext *)panelYContext;

@end

NS_ASSUME_NONNULL_END
