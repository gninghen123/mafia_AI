//
// TechnicalIndicatorBase.h
// TradingApp
//
// Base abstract class for all technical indicators
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "runtimemodels.h"  // From RuntimeModels

@class IndicatorDataModel;

typedef NS_ENUM(NSInteger, IndicatorType) {
    IndicatorTypeHardcoded,      // Built-in indicators (EMA, SMA, etc.)
    IndicatorTypePineScript      // Custom PineScript indicators
};

typedef NS_ENUM(NSInteger, IndicatorSeriesType) {
    IndicatorSeriesTypeLine,     // Line plot (most indicators)
    IndicatorSeriesTypeHistogram, // Histogram/bars
    IndicatorSeriesTypeArea,     // Area fill
    IndicatorSeriesTypeSignal    // Signal arrows/markers
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

#pragma mark - Output Data
@property (nonatomic, strong, nullable) NSArray<IndicatorDataModel *> *outputSeries;
@property (nonatomic, assign, readonly) NSInteger minimumBarsRequired;

#pragma mark - Calculation State
@property (nonatomic, assign, readonly) BOOL isCalculated;
@property (nonatomic, strong, nullable) NSError *lastError;

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
@property (nonatomic, assign) IndicatorSeriesType seriesType;  // Line, histogram, etc.
@property (nonatomic, strong, nullable) NSColor *color;   // Display color
@property (nonatomic, assign) double anchorValue;         // For relative positioning
@property (nonatomic, assign) BOOL isSignal;              // For buy/sell signals

// Convenience initializers
+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                       seriesType:(IndicatorSeriesType)type;

+ (instancetype)dataWithTimestamp:(NSDate *)timestamp
                            value:(double)value
                       seriesName:(NSString *)seriesName
                       seriesType:(IndicatorSeriesType)type
                            color:(NSColor *)color;

@end

NS_ASSUME_NONNULL_END
