//
//  ChartPatternManager.h
//  TradingApp
//
//  Manager class for Chart Patterns - High-level business logic
//

#import <Foundation/Foundation.h>
#import "ChartPatternModel.h"

@class ChartWidget;
@class SavedChartData;

NS_ASSUME_NONNULL_BEGIN

@interface ChartPatternManager : NSObject

// Singleton
+ (instancetype)shared;

#pragma mark - High-level Operations

/// Create pattern from current chart widget state
/// @param chartWidget The chart widget to create pattern from
/// @param patternType The pattern type
/// @param notes Optional user notes
/// @return Created ChartPatternModel or nil if failed
- (nullable ChartPatternModel *)createPatternFromChartWidget:(ChartWidget *)chartWidget
                                                 patternType:(NSString *)patternType
                                                       notes:(nullable NSString *)notes;

/// Load pattern into chart widget
/// @param pattern The pattern to load
/// @param chartWidget The chart widget to load into
/// @return YES if successful, NO if failed
- (BOOL)loadPatternIntoChartWidget:(ChartPatternModel *)pattern
                       chartWidget:(ChartWidget *)chartWidget;

#pragma mark - File Operations

/// Load SavedChartData for pattern
/// @param pattern The pattern to load data for
/// @return SavedChartData object or nil if not found
- (nullable SavedChartData *)loadSavedDataForPattern:(ChartPatternModel *)pattern;

/// Get display information for pattern
/// @param pattern The pattern to get info for
/// @return Human readable display string
- (NSString *)getPatternDisplayInfo:(ChartPatternModel *)pattern;

/// Validate that pattern's SavedChartData exists
/// @param pattern The pattern to validate
/// @return YES if valid, NO if SavedChartData missing
- (BOOL)validatePattern:(ChartPatternModel *)pattern;

#pragma mark - Cleanup Operations

/// Find patterns with missing SavedChartData
/// @return Array of orphaned patterns
- (NSArray<ChartPatternModel *> *)findOrphanedPatterns;

/// Find SavedChartData files not referenced by any pattern
/// @return Array of orphaned SavedChartData UUIDs
- (NSArray<NSString *> *)findOrphanedSavedData;

/// Clean up orphaned patterns with user confirmation
/// @param completion Completion block with cleanup results
- (void)cleanupOrphanedPatternsWithCompletion:(void(^)(NSInteger deletedCount, NSError * _Nullable error))completion;

#pragma mark - Pattern Types

/// Get all known pattern types for autocomplete
/// @return Array of pattern type strings
- (NSArray<NSString *> *)getAllKnownPatternTypes;

/// Add new pattern type
/// @param patternType The new pattern type to add
- (void)addPatternType:(NSString *)patternType;

/// Validate pattern type
/// @param patternType The pattern type to validate
/// @return YES if valid, NO if invalid
- (BOOL)isValidPatternType:(NSString *)patternType;

#pragma mark - Statistics and Info

/// Get pattern statistics by type
/// @return Dictionary mapping pattern types to counts
- (NSDictionary<NSString *, NSNumber *> *)getPatternStatistics;

/// Get total pattern count
/// @return Total number of patterns
- (NSInteger)getTotalPatternCount;

/// Get patterns for symbol
/// @param symbol The symbol to get patterns for
/// @return Array of patterns for the symbol
- (NSArray<ChartPatternModel *> *)getPatternsForSymbol:(NSString *)symbol;

/// Get all patterns
/// @return Array of all patterns
- (NSArray<ChartPatternModel *> *)getAllPatterns;

#pragma mark - Interactive Creation

/// Show interactive pattern creation dialog
/// @param chartWidget The source chart widget
/// @param completion Completion block with created pattern
- (void)showPatternCreationDialogForChartWidget:(ChartWidget *)chartWidget
                                     completion:(void(^)(ChartPatternModel * _Nullable pattern, BOOL cancelled))completion;

@end

NS_ASSUME_NONNULL_END
