//
//  BaseScreener.h
//  TradingApp
//
//  Base class for all screener algorithms
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseScreener : NSObject

#pragma mark - Properties (Subclasses must override)

/// Unique identifier for the screener
@property (nonatomic, readonly) NSString *screenerID;

/// Display name for UI
@property (nonatomic, readonly) NSString *displayName;

/// Detailed description of what the screener does
@property (nonatomic, readonly) NSString *descriptionText;

/// Minimum number of bars required for calculation
@property (nonatomic, readonly) NSInteger minBarsRequired;

/// Configurable parameters (set externally or from JSON)
@property (nonatomic, strong) NSDictionary *parameters;

#pragma mark - Execution

/**
 * Execute screener on list of symbols
 * @param inputSymbols Array of symbol strings to screen
 * @param cache Dictionary mapping symbol → array of HistoricalBarModel
 * @return Array of symbols that pass the screening criteria
 */
- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache;

#pragma mark - Default Parameters

/// Get default parameters for this screener
/// Subclasses should override to provide their defaults
- (NSDictionary *)defaultParameters;

#pragma mark - Helper Methods (available to subclasses)

/**
 * Get bars for a specific symbol from cache
 * @param symbol Symbol to retrieve
 * @param cache Data cache
 * @return Array of bars or nil if not found
 */
- (nullable NSArray<HistoricalBarModel *> *)barsForSymbol:(NSString *)symbol
                                                   inCache:(NSDictionary *)cache;

/**
 * Get parameter value with default fallback
 * @param key Parameter key
 * @param defaultValue Default value if not set
 * @return Parameter value or default
 */
- (double)parameterDoubleForKey:(NSString *)key
                   defaultValue:(double)defaultValue;

- (NSInteger)parameterIntegerForKey:(NSString *)key
                       defaultValue:(NSInteger)defaultValue;

- (BOOL)parameterBoolForKey:(NSString *)key
               defaultValue:(BOOL)defaultValue;

- (NSString *)parameterStringForKey:(NSString *)key
                       defaultValue:(NSString *)defaultValue;

@end

NS_ASSUME_NONNULL_END
