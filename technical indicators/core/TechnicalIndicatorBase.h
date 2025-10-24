//
// TechnicalIndicatorBase.h
// TradingApp
//
// Base abstract class for all technical indicators
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"  // From RuntimeModels

@class IndicatorDataModel;

typedef NS_ENUM(NSInteger, PriceDirection) {
    PriceDirectionNeutral = 0,    // Grigio: close == previousClose
    PriceDirectionUp = 1,         // Verde: close > previousClose
    PriceDirectionDown = -1       // Rosso: close < previousClose
};

typedef NS_ENUM(NSInteger, IndicatorType) {
    IndicatorTypeHardcoded,      // Built-in indicators (EMA, SMA, etc.)
    IndicatorTypePineScript      // Custom PineScript indicators
};

// ✅ SPOSTATO QUI da RawDataSeriesIndicator.h
typedef NS_ENUM(NSInteger, VisualizationType) {
    VisualizationTypeCandlestick,   // OHLC candlesticks
    VisualizationTypeLine,          // Simple line
    VisualizationTypeArea,          // Area fill
    VisualizationTypeHistogram,     // Histogram bars (volume)
    VisualizationTypeOHLC,          // OHLC bars
    VisualizationTypeStep           // Step line
};

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Technical Indicator Base (Abstract)

@interface TechnicalIndicatorBase : NSObject

#pragma mark - Core Properties
@property (nonatomic, strong, readonly) NSString *indicatorID;      // Unique identifier
@property (nonatomic, strong, readonly) NSString *name;             // Display name
@property (nonatomic, strong, readonly) NSString *shortName;        // Short name (e.g. "RSI")
@property (nonatomic, assign, readonly) IndicatorType type;         // Hardcoded vs PineScript
@property (nonatomic, strong) NSDictionary<NSString *, id> *parameters;  // Configurable params

#pragma mark - ✅ NEW: Visualization Properties
@property (nonatomic, assign) VisualizationType visualizationType;  // How to render this indicator

#pragma mark - Output Data
@property (nonatomic, strong, nullable) NSArray<IndicatorDataModel *> *outputSeries;
@property (nonatomic, assign, readonly) NSInteger minimumBarsRequired;

#pragma mark - Calculation State
@property (nonatomic, assign) BOOL isCalculated;  // Made writable
@property (nonatomic, strong, nullable) NSError *lastError;  // Made writable

#pragma mark - Initialization (Subclasses must override)

/// Initialize indicator with custom parameters
/// @param parameters Configuration dictionary
- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters;

#pragma mark - Abstract Methods (Must be implemented by subclasses)

/// Calculate indicator values for given bars
/// @param bars Array of HistoricalBarModel objects
- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars;

/// Get minimum number of bars required for calculation
/// @return Minimum bars needed (e.g. 14 for RSI(14))
- (NSInteger)minimumBarsRequired;

/// Get default parameters for this indicator
/// @return Dictionary of default parameter values
+ (NSDictionary<NSString *, id> *)defaultParameters;

/// Get parameter validation rules
/// @return Dictionary describing parameter constraints
+ (NSDictionary<NSString *, id> *)parameterValidationRules;

#pragma mark - ✅ NEW: Visualization Methods

/// Get the default visualization type for this indicator
/// @return Default visualization type
- (VisualizationType)defaultVisualizationType;

/// Get display name for visualization type
/// @param vizType Visualization type
/// @return Human-readable name
+ (NSString *)displayNameForVisualizationType:(VisualizationType)vizType;

#pragma mark - Validation

/// Validate parameters before calculation
/// @param parameters Parameters to validate
/// @param error Error pointer for validation failures
/// @return YES if valid, NO otherwise
- (BOOL)validateParameters:(NSDictionary<NSString *, id> *)parameters error:(NSError **)error;

/// Check if indicator can calculate with given bars
/// @param bars Input bar data
/// @return YES if calculation is possible
- (BOOL)canCalculateWithBars:(NSArray<HistoricalBarModel *> *)bars;

#pragma mark - Utility
- (NSColor*)defaultColor;
/// Reset calculation state (clears output and errors)
- (void)reset;

/// Get indicator description for UI
- (NSString *)displayDescription;

@end

#pragma mark - Indicator Data Model

@interface IndicatorDataModel : NSObject

@property (nonatomic, strong) NSDate *timestamp;          // Bar timestamp
@property (nonatomic, assign) double value;               // Indicator value
@property (nonatomic, strong) NSString *seriesName;       // "RSI", "BB_Upper", etc.
@property (nonatomic, assign) VisualizationType seriesType;  // ✅ UPDATED: ora usa VisualizationType
@property (nonatomic, strong, nullable) NSColor *color;   // Display color
@property (nonatomic, assign) double anchorValue;         // For relative positioning
@property (nonatomic, assign) BOOL isSignal;              // For buy/sell signals
@property (nonatomic, assign) PriceDirection priceDirection;  // ✅ NUOVO: Direzione prezzo per colori

// Convenience initializers
+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                       seriesType:(VisualizationType)type;

+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                       seriesType:(VisualizationType)type
                            color:(NSColor *)color;
+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                       seriesType:(VisualizationType)type
                            color:(nullable NSColor *)color
                   priceDirection:(PriceDirection)priceDirection;
@end

NS_ASSUME_NONNULL_END
