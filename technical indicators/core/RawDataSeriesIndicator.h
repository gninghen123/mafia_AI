//
// RawDataSeriesIndicator.h
// TradingApp
//
// Base class for all raw data series visualizers (Security, Volume, Fundamentals, etc.)
// These indicators don't process data, they just visualize historical series
//

#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

// =======================================
// ENUMS
// =======================================

typedef NS_ENUM(NSInteger, RawDataType) {
    RawDataTypePrice,           // OHLC price data
    RawDataTypeVolume,          // Volume data
    RawDataTypeFundamentals,    // Revenue, EPS, etc.
    RawDataTypeMarketMetrics,   // Short interest, institutional ownership
    RawDataTypeAlternative      // Social sentiment, news, etc.
};

typedef NS_ENUM(NSInteger, VisualizationType) {
    VisualizationTypeCandlestick,   // OHLC candlesticks
    VisualizationTypeLine,          // Simple line
    VisualizationTypeArea,          // Area fill
    VisualizationTypeHistogram,     // Histogram bars (volume)
    VisualizationTypeOHLC,          // OHLC bars
    VisualizationTypeStep           // Step line
};

// =======================================
// BASE CLASS
// =======================================

@interface RawDataSeriesIndicator : TechnicalIndicatorBase

#pragma mark - Core Properties
@property (nonatomic, assign) RawDataType dataType;
@property (nonatomic, assign) VisualizationType visualizationType;
@property (nonatomic, strong) NSString *dataField;  // "close", "volume", "revenue", etc.

#pragma mark - Display Properties
@property (nonatomic, strong, nullable) NSColor *seriesColor;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) BOOL showValues;      // Show numeric values on chart

#pragma mark - Initialization
- (instancetype)initWithDataType:(RawDataType)dataType
                 visualizationType:(VisualizationType)vizType
                         dataField:(NSString *)field;

#pragma mark - Abstract Methods (Override in subclasses)

/// Extract the relevant value from a historical bar
/// @param bar Historical bar data
/// @return Value to display (price, volume, etc.)
- (double)extractValueFromBar:(HistoricalBarModel *)bar;

/// Get the default color for this data type
/// @return Default color for visualization
- (NSColor *)defaultColor;

/// Get the default visualization type for this data type
/// @return Default visualization type
- (VisualizationType)defaultVisualizationType;

#pragma mark - Utility Methods

/// Convert VisualizationType to IndicatorSeriesType for rendering
/// @param vizType Visualization type from this indicator
/// @return Series type for the rendering system
+ (IndicatorSeriesType)seriesTypeFromVisualizationType:(VisualizationType)vizType;

/// Get display name for visualization type
/// @param vizType Visualization type
/// @return Human-readable name
+ (NSString *)displayNameForVisualizationType:(VisualizationType)vizType;

/// Get display name for data type
/// @param dataType Raw data type
/// @return Human-readable name
+ (NSString *)displayNameForDataType:(RawDataType)dataType;

@end

NS_ASSUME_NONNULL_END
