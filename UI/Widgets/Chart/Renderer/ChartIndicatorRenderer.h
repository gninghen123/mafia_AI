//
// ChartIndicatorRenderer.h
// TradingApp
//
// Renderer for technical indicators display in chart panels
// ✅ REFACTORED: NSBezierPath-based rendering with CALayer delegate pattern
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "TechnicalIndicatorBase.h"  // ✅ IndicatorDataModel è dentro qui

@class ChartPanelView;
@class SharedXCoordinateContext;
@class PanelYCoordinateContext;

NS_ASSUME_NONNULL_BEGIN

@interface ChartIndicatorRenderer : NSObject <CALayerDelegate>

#pragma mark - Properties
@property (nonatomic, weak) ChartPanelView *panelView;
@property (nonatomic, strong) CALayer *indicatorsLayer;
@property (nonatomic, strong, nullable) TechnicalIndicatorBase *rootIndicator;


// ✅ NEW: Cached data for performance
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<IndicatorDataModel *> *> *cachedVisibleData;
@property (nonatomic, assign) NSInteger lastVisibleStartIndex;
@property (nonatomic, assign) NSInteger lastVisibleEndIndex;

@property (nonatomic, strong) CATextLayer *warningMessagesLayer;
@property (nonatomic, strong) NSMutableArray<NSString *> *activeWarnings;

#pragma mark - Initialization
/// Initialize renderer with panel view
/// @param panelView Parent chart panel view
- (instancetype)initWithPanelView:(ChartPanelView *)panelView;

#pragma mark - Period Optimization (NEW)
/// Check if indicator period is too short for visible range
/// @param indicator Indicator to check
/// @param visibleRange Current visible range length
/// @return YES if period is too short (period * 30 < visibleRange)
- (BOOL)isPeriodTooShortForIndicator:(TechnicalIndicatorBase *)indicator visibleRange:(NSInteger)visibleRange;

/// Extract period from indicator parameters
/// @param indicator Indicator to examine
/// @return Period value or 1 if not found
- (NSInteger)extractPeriodFromIndicator:(TechnicalIndicatorBase *)indicator;

/// Add warning message to display
/// @param message Warning message text
- (void)addWarningMessage:(NSString *)message;

/// Clear all warning messages
- (void)clearWarningMessages;

/// Update warning messages display
- (void)updateWarningMessagesDisplay;

#pragma mark - Rendering Management
/// Render entire indicator tree
/// @param rootIndicator Root indicator with child hierarchy
- (void)renderIndicatorTree:(TechnicalIndicatorBase *)rootIndicator;

/// Clear all indicator rendering
- (void)clearIndicatorLayers;

/// Invalidate and refresh all indicator layers
- (void)invalidateIndicatorLayers;

#pragma mark - Layer Management
/// Setup indicators layer structure
- (void)setupIndicatorsLayer;

/// Update layer bounds when panel resizes
- (void)updateLayerBounds;

#pragma mark - Drawing Implementation (CALayerDelegate)
/// Main drawing method called by CALayer
/// @param layer The indicators layer
/// @param ctx Graphics context for drawing
- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx;

#pragma mark - Specialized Drawing Methods
/// Draw line-based indicator (SMA, EMA, etc.)
/// @param indicator Line indicator to draw
- (void)drawLineIndicator:(TechnicalIndicatorBase *)indicator;

/// Draw histogram indicator (Volume, MACD histogram)
/// @param indicator Histogram indicator to draw
- (void)drawHistogramIndicator:(TechnicalIndicatorBase *)indicator;

/// Draw area fill indicator
/// @param indicator Area indicator to draw
- (void)drawAreaIndicator:(TechnicalIndicatorBase *)indicator;

/// Draw signal markers (buy/sell arrows, crosses)
/// @param indicator Signal indicator to draw
- (void)drawSignalIndicator:(TechnicalIndicatorBase *)indicator;

/// Draw bands indicator (Bollinger Bands, Keltner Channels)
/// @param indicator Bands indicator to draw
- (void)drawBandsIndicator:(TechnicalIndicatorBase *)indicator;

/// Draw candlestick indicator (Security data)
/// @param indicator Security indicator to draw
- (void)drawCandlestickIndicator:(TechnicalIndicatorBase *)indicator;

#pragma mark - Visible Data Optimization (UPDATED)
/// Check if visible range has changed since last render
/// @param startIndex Current visible start index
/// @param endIndex Current visible end index
/// @return YES if visible range changed
- (BOOL)hasVisibleRangeChanged:(NSInteger)startIndex endIndex:(NSInteger)endIndex;

/// Get valid visible range for indicator data
/// @param indicator Indicator to check
/// @param startIndex Visible start index
/// @param endIndex Visible end index
/// @return NSRange with clamped valid indices
- (NSRange)validVisibleRangeForIndicator:(TechnicalIndicatorBase *)indicator
                              startIndex:(NSInteger)startIndex
                                endIndex:(NSInteger)endIndex;

#pragma mark - BezierPath Creation Helpers (UPDATED - No Array Creation)
/// Create line BezierPath directly from indicator data using indices
/// @param indicator Source indicator with data
/// @param startIndex Start index in data array
/// @param endIndex End index in data array
/// @return NSBezierPath for line rendering
- (NSBezierPath *)createLinePathFromIndicator:(TechnicalIndicatorBase *)indicator
                                   startIndex:(NSInteger)startIndex
                                     endIndex:(NSInteger)endIndex;

/// Create histogram bars BezierPath directly from indicator data using indices
/// @param indicator Source indicator with data
/// @param startIndex Start index in data array
/// @param endIndex End index in data array
/// @param baselineY Y coordinate for histogram baseline
/// @return NSBezierPath for histogram rendering
- (NSBezierPath *)createHistogramPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                        startIndex:(NSInteger)startIndex
                                          endIndex:(NSInteger)endIndex
                                         baselineY:(CGFloat)baselineY;

/// Create area BezierPath directly from indicator data using indices
/// @param indicator Source indicator with data
/// @param startIndex Start index in data array
/// @param endIndex End index in data array
/// @param baselineY Y coordinate for area baseline
/// @return NSBezierPath for area rendering
- (NSBezierPath *)createAreaPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                   startIndex:(NSInteger)startIndex
                                     endIndex:(NSInteger)endIndex
                                    baselineY:(CGFloat)baselineY;

/// Create signal markers BezierPath directly from indicator data using indices
/// @param indicator Source indicator with data
/// @param startIndex Start index in data array
/// @param endIndex End index in data array
/// @return NSBezierPath for signal rendering
- (NSBezierPath *)createSignalPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                     startIndex:(NSInteger)startIndex
                                       endIndex:(NSInteger)endIndex;
#pragma mark - Coordinate Conversion
/// Convert timestamp to X coordinate using SharedXContext
/// @param timestamp Data point timestamp
/// @return X coordinate in panel
- (CGFloat)xCoordinateForTimestamp:(NSDate *)timestamp;

/// Convert value to Y coordinate using PanelYContext
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

/// Apply visual effects to path (line width, dash patterns)
/// @param path Target path
/// @param indicator Indicator providing style preferences
- (void)applyStyleToPath:(NSBezierPath *)path forIndicator:(TechnicalIndicatorBase *)indicator;

/// Get color for price direction (for colored volume bars)
/// @param direction Price direction enum
/// @param indicator Indicator instance (for potential customization)
/// @return Appropriate color for the direction
- (NSColor *)colorForPriceDirection:(PriceDirection)direction indicator:(TechnicalIndicatorBase *)indicator;


#pragma mark - Visible Data Optimization
/// Extract visible data points for rendering
/// @param dataPoints Full indicator data array
/// @param startIndex Visible start index
/// @param endIndex Visible end index
/// @return Array of visible data points only
- (NSArray<IndicatorDataModel *> *)extractVisibleDataPoints:(NSArray<IndicatorDataModel *> *)dataPoints
                                                  startIndex:(NSInteger)startIndex
                                                    endIndex:(NSInteger)endIndex;

/// Check if visible range has changed since last render
/// @param startIndex Current visible start index
/// @param endIndex Current visible end index
/// @return YES if visible range changed
- (BOOL)hasVisibleRangeChanged:(NSInteger)startIndex endIndex:(NSInteger)endIndex;

#pragma mark - Visibility Management
/// Set visibility recursively for indicators
/// @param indicators Array of indicators to modify
/// @param visible Whether indicators should be visible
- (void)setVisibilityRecursively:(NSArray<TechnicalIndicatorBase *> *)indicators visible:(BOOL)visible;

/// Mark all indicators for re-rendering (sets needsRendering flag)
- (void)markAllIndicatorsForRerendering;

#pragma name - Recursive Rendering
/// Render children indicators recursively
/// @param parentIndicator Parent indicator with children
- (void)renderChildrenRecursively:(TechnicalIndicatorBase *)parentIndicator;

#pragma mark - Cleanup
/// Cleanup resources and remove layers
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
