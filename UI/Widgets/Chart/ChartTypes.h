//
//  ChartTypes.h
//  TradingApp
//
//  Chart-specific enums and constants
//

#ifndef ChartTypes_h
#define ChartTypes_h

#import <Foundation/Foundation.h>

// Visualization types for indicators
typedef NS_ENUM(NSInteger, VisualizationType) {
    VisualizationTypeLine,          // Simple line
    VisualizationTypeCandlestick,   // OHLC candlesticks (security only)
    VisualizationTypeHistogram,     // Volume bars
    VisualizationTypeArea,          // Filled area under line
    VisualizationTypeDots           // Scatter plot points
};

// Indicator categories
typedef NS_ENUM(NSInteger, IndicatorCategory) {
    IndicatorCategorySecurity,      // Price-based (candlestick, line chart)
    IndicatorCategoryVolume,        // Volume-based indicators
    IndicatorCategoryMomentum,      // RSI, MACD, etc.
    IndicatorCategoryTrend,         // Moving averages, Bollinger bands
    IndicatorCategoryVolatility,    // ATR, etc.
    IndicatorCategoryCustom         // User-defined indicators
};

// Panel types
typedef NS_ENUM(NSInteger, ChartPanelType) {
    ChartPanelTypeMain,            // Main price panel (cannot be deleted)
    ChartPanelTypeSecondary        // Secondary indicator panels (can be deleted)
};

// Chart rendering quality
typedef NS_ENUM(NSInteger, ChartRenderingQuality) {
    ChartRenderingQualityFast,     // Low quality for fast scrolling
    ChartRenderingQualityNormal,   // Standard quality
    ChartRenderingQualityHigh      // High quality for screenshots
};

// Timeframe mappings (to work with existing CommonTypes BarTimeframe)
typedef NS_ENUM(NSInteger, ChartTimeframeIndex) {
    ChartTimeframeIndex1Min = 0,
    ChartTimeframeIndex5Min = 1,
    ChartTimeframeIndex15Min = 2,
    ChartTimeframeIndex1Hour = 3,
    ChartTimeframeIndex1Day = 4,
    ChartTimeframeIndex1Week = 5
};

// Drawing constants
static const CGFloat kChartMinPanelHeight = 80.0;
static const CGFloat kChartDefaultPanelHeight = 200.0;
static const CGFloat kChartMainPanelHeight = 400.0;
static const CGFloat kChartPanelSpacing = 2.0;
static const CGFloat kChartBorderWidth = 1.0;
static const CGFloat kChartDefaultLineWidth = 1.5;
static const CGFloat kChartCrosshairLineWidth = 1.0;

// Color constants
#define kChartUpColor [NSColor colorWithRed:0.0 green:0.8 blue:0.2 alpha:1.0]
#define kChartDownColor [NSColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0]
#define kChartVolumeUpColor [NSColor colorWithRed:0.0 green:0.6 blue:0.8 alpha:0.7]
#define kChartVolumeDownColor [NSColor colorWithRed:0.8 green:0.4 blue:0.4 alpha:0.7]
#define kChartBorderColor [NSColor separatorColor]
#define kChartBackgroundColor [NSColor controlBackgroundColor]
#define kChartCrosshairColor [[NSColor labelColor] colorWithAlphaComponent:0.7]

#endif /* ChartTypes_h */
