//
//  CHChartTypes.h
//  ChartWidget
//
//  Common type definitions for the chart widget system
//

#ifndef CHChartTypes_h
#define CHChartTypes_h

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

// Chart Types
typedef NS_ENUM(NSInteger, CHChartType) {
    CHChartTypeLine,
    CHChartTypeBar,
    CHChartTypePie,
    CHChartTypeArea,
    CHChartTypeScatter,
    CHChartTypeCombined
};

// Line Chart Styles
typedef NS_ENUM(NSInteger, CHLineChartStyle) {
    CHLineChartStyleStraight,      // Simple straight lines
    CHLineChartStyleSmooth,        // Bezier curves
    CHLineChartStyleStepped,       // Step/staircase style
    CHLineChartStyleSteppedMiddle  // Steps centered on points
};

// Line Chart Point Styles
typedef NS_ENUM(NSInteger, CHLineChartPointStyle) {
    CHLineChartPointStyleNone,     // No points
    CHLineChartPointStyleCircle,   // Circle points
    CHLineChartPointStyleSquare,   // Square points
    CHLineChartPointStyleDiamond,  // Diamond points
    CHLineChartPointStyleTriangle  // Triangle points
};

// Bar Chart Styles
typedef NS_ENUM(NSInteger, CHBarChartStyle) {
    CHBarChartStyleGrouped,        // Bars grouped side by side
    CHBarChartStyleStacked,        // Bars stacked on top of each other
    CHBarChartStyleHistogram,      // Histogram style
    CHBarChartStyleHorizontal      // Horizontal bars
};

// Animation Types
typedef NS_ENUM(NSInteger, CHAnimationType) {
    CHAnimationTypeNone,
    CHAnimationTypeFadeIn,
    CHAnimationTypeGrowIn,
    CHAnimationTypeSlideIn,
    CHAnimationTypeBounce
};

// Grid Line Options
typedef NS_OPTIONS(NSUInteger, CHChartGridLines) {
    CHChartGridLinesNone = 0,
    CHChartGridLinesHorizontal = 1 << 0,
    CHChartGridLinesVertical = 1 << 1,
    CHChartGridLinesBoth = CHChartGridLinesHorizontal | CHChartGridLinesVertical
};

// Axis Position
typedef NS_ENUM(NSInteger, CHAxisPosition) {
    CHAxisPositionLeft,
    CHAxisPositionRight,
    CHAxisPositionTop,
    CHAxisPositionBottom
};

// Legend Position
typedef NS_ENUM(NSInteger, CHLegendPosition) {
    CHLegendPositionTop,
    CHLegendPositionBottom,
    CHLegendPositionLeft,
    CHLegendPositionRight,
    CHLegendPositionTopLeft,
    CHLegendPositionTopRight,
    CHLegendPositionBottomLeft,
    CHLegendPositionBottomRight
};

// Data Point Types
typedef NS_ENUM(NSInteger, CHDataPointType) {
    CHDataPointTypeValue,          // Simple value point
    CHDataPointTypeCandlestick,    // OHLC candlestick
    CHDataPointTypeVolume,         // Volume data
    CHDataPointTypeCustom          // Custom data point
};

// Selection Types
typedef NS_ENUM(NSInteger, CHSelectionType) {
    CHSelectionTypeNone,
    CHSelectionTypeSingle,
    CHSelectionTypeMultiple,
    CHSelectionTypeRange
};

// Zoom Types
typedef NS_ENUM(NSInteger, CHZoomType) {
    CHZoomTypeNone,
    CHZoomTypePinch,
    CHZoomTypeWheel,
    CHZoomTypeBoth
};

// Chart Layer Types
typedef NS_ENUM(NSInteger, CHChartLayerType) {
    CHChartLayerTypeBackground,
    CHChartLayerTypeGrid,
    CHChartLayerTypeAxes,
    CHChartLayerTypeData,
    CHChartLayerTypeOverlay,
    CHChartLayerTypeAnimation
};

// Render Quality
typedef NS_ENUM(NSInteger, CHRenderQuality) {
    CHRenderQualityDraft,          // Fast rendering 
    CHRenderQualityGood,           // Standard quality
    CHRenderQualityHigh            // High quality for export
};

// Error Types
typedef NS_ENUM(NSInteger, CHChartError) {
    CHChartErrorNone,
    CHChartErrorInvalidData,
    CHChartErrorInvalidConfiguration,
    CHChartErrorRenderingFailed,
    CHChartErrorAnimationFailed
};

// Constants
extern const CGFloat CHChartDefaultLineWidth;
extern const CGFloat CHChartDefaultBarWidth;
extern const CGFloat CHChartDefaultPointRadius;
extern const NSTimeInterval CHChartDefaultAnimationDuration;
extern const NSInteger CHChartDefaultMaxDataPoints;

// Notification Names
extern NSString * const CHChartDataDidChangeNotification;
extern NSString * const CHChartSelectionDidChangeNotification;
extern NSString * const CHChartConfigurationDidChangeNotification;
extern NSString * const CHChartAnimationDidCompleteNotification;

// User Info Keys
extern NSString * const CHChartDataKey;
extern NSString * const CHChartSelectionKey;
extern NSString * const CHChartConfigurationKey;
extern NSString * const CHChartAnimationKey;

#endif /* CHChartTypes_h */
