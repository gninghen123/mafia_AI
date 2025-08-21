//
//  DataHub+ChartPatterns.h
//  TradingApp
//
//  DataHub extension for Chart Patterns persistence
//

#import "DataHub.h"
#import "ChartPatternModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (ChartPatterns)

#pragma mark - CRUD Operations

/// Create a new chart pattern
/// @param patternType The pattern type (e.g., "Head & Shoulders")
/// @param savedDataRef UUID reference to SavedChartData file
/// @param notes Optional user notes
/// @return Created ChartPatternModel or nil if failed
- (nullable ChartPatternModel *)createPatternWithType:(NSString *)patternType
                                   savedDataReference:(NSString *)savedDataRef
                                                notes:(nullable NSString *)notes;

/// Get all chart patterns
/// @return Array of ChartPatternModel objects
- (NSArray<ChartPatternModel *> *)getAllPatterns;

/// Get patterns filtered by type
/// @param patternType The pattern type to filter by
/// @return Array of ChartPatternModel objects
- (NSArray<ChartPatternModel *> *)getPatternsOfType:(NSString *)patternType;

/// Get patterns for a specific symbol
/// @param symbol The symbol to filter by
/// @return Array of ChartPatternModel objects
- (NSArray<ChartPatternModel *> *)getPatternsForSymbol:(NSString *)symbol;

/// Get pattern by ID
/// @param patternID The pattern ID to find
/// @return ChartPatternModel or nil if not found
- (nullable ChartPatternModel *)getPatternWithID:(NSString *)patternID;

/// Update existing pattern
/// @param pattern The pattern model to update
/// @return YES if successful, NO if failed
- (BOOL)updatePattern:(ChartPatternModel *)pattern;

/// Delete pattern by ID
/// @param patternID The pattern ID to delete
/// @return YES if successful, NO if not found
- (BOOL)deletePatternWithID:(NSString *)patternID;

#pragma mark - Pattern Types Management

/// Get all unique pattern types used in the database
/// @return Array of pattern type strings
- (NSArray<NSString *> *)getAllPatternTypes;

/// Add a new pattern type to the known types list (stored in UserDefaults)
/// @param newType The new pattern type to add
- (void)addPatternType:(NSString *)newType;

/// Get default pattern types
/// @return Array of default pattern type strings
- (NSArray<NSString *> *)getDefaultPatternTypes;

/// Get all pattern types (default + user-added)
/// @return Array of all pattern type strings for autocomplete
- (NSArray<NSString *> *)getAllKnownPatternTypes;

#pragma mark - Validation

/// Check if pattern type is valid (non-empty, reasonable length)
/// @param patternType The pattern type to validate
/// @return YES if valid, NO if invalid
- (BOOL)isValidPatternType:(NSString *)patternType;

/// Check if SavedChartData exists for reference
/// @param savedDataRef The UUID reference to check
/// @return YES if SavedChartData file exists, NO if missing
- (BOOL)savedDataExistsForReference:(NSString *)savedDataRef;

#pragma mark - Cleanup Operations

/// Find patterns that reference missing SavedChartData files
/// @return Array of orphaned ChartPatternModel objects
- (NSArray<ChartPatternModel *> *)findOrphanedPatterns;

/// Find SavedChartData files that are not referenced by any pattern
/// @return Array of UUID strings for orphaned SavedChartData
- (NSArray<NSString *> *)findOrphanedSavedData;

/// Clean up orphaned patterns (with user confirmation)
/// @param orphanedPatterns Array of patterns to delete
/// @param completion Completion block with cleanup results
- (void)cleanupOrphanedPatterns:(NSArray<ChartPatternModel *> *)orphanedPatterns
                     completion:(void(^)(NSInteger deletedCount, NSError * _Nullable error))completion;

#pragma mark - Statistics

/// Get pattern statistics
/// @return Dictionary with pattern counts by type
- (NSDictionary<NSString *, NSNumber *> *)getPatternStatistics;

/// Get total pattern count
/// @return Total number of patterns
- (NSInteger)getTotalPatternCount;

@end

NS_ASSUME_NONNULL_END
