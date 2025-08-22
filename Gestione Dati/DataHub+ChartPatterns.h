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

/// Create a new chart pattern with date range
/// @param patternType The pattern type (e.g., "Head & Shoulders")
/// @param savedDataRef UUID reference to SavedChartData file
/// @param startDate Start date of the pattern
/// @param endDate End date of the pattern
/// @param notes Optional user notes
/// @return Created ChartPatternModel or nil if failed
- (nullable ChartPatternModel *)createPatternWithType:(NSString *)patternType
                                   savedDataReference:(NSString *)savedDataRef
                                       patternStartDate:(NSDate *)startDate
                                         patternEndDate:(NSDate *)endDate
                                                notes:(nullable NSString *)notes;

/// Create a new chart pattern (legacy - uses full SavedChartData date range)
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

/// Get patterns for a specific symbol within a date range
/// @param symbol The symbol to filter by
/// @param startDate Start date filter (inclusive)
/// @param endDate End date filter (inclusive)
/// @return Array of ChartPatternModel objects
- (NSArray<ChartPatternModel *> *)getPatternsForSymbol:(NSString *)symbol
                                             startDate:(NSDate *)startDate
                                               endDate:(NSDate *)endDate;

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
/// @return YES if file exists, NO if not found
- (BOOL)savedDataExistsForReference:(NSString *)savedDataRef;

/// Validate pattern date range against SavedChartData
/// @param startDate Pattern start date
/// @param endDate Pattern end date
/// @param savedDataRef UUID reference to SavedChartData
/// @return YES if dates are valid and within SavedChartData range
- (BOOL)validatePatternDateRange:(NSDate *)startDate
                         endDate:(NSDate *)endDate
              forSavedDataReference:(NSString *)savedDataRef;

#pragma mark - Cleanup Operations

/// Find patterns with missing SavedChartData
/// @return Array of orphaned patterns
- (NSArray<ChartPatternModel *> *)findOrphanedPatterns;

/// Find patterns with invalid date ranges
/// @return Array of patterns with invalid date ranges
- (NSArray<ChartPatternModel *> *)findPatternsWithInvalidDateRanges;

/// Find SavedChartData files not referenced by any pattern
/// @return Array of orphaned SavedChartData UUIDs
- (NSArray<NSString *> *)findOrphanedSavedData;

/// Clean up orphaned patterns with user confirmation
/// @param completion Completion block with cleanup results
- (void)cleanupOrphanedPatternsWithCompletion:(void(^)(NSInteger deletedCount, NSError * _Nullable error))completion;

/// Clean up specified orphaned patterns (direct deletion)
/// @param orphanedPatterns Array of patterns to delete
/// @param completion Completion block with cleanup results
- (void)cleanupOrphanedPatterns:(NSArray<ChartPatternModel *> *)orphanedPatterns
                     completion:(void(^)(NSInteger deletedCount, NSError * _Nullable error))completion;

/// Fix patterns with invalid date ranges by setting them to full SavedChartData range
/// @param completion Completion block with fix results
- (void)fixInvalidPatternDateRangesWithCompletion:(void(^)(NSInteger fixedCount, NSError * _Nullable error))completion;

#pragma mark - Statistics

/// Get pattern statistics by type
/// @return Dictionary mapping pattern types to counts
- (NSDictionary<NSString *, NSNumber *> *)getPatternStatistics;

/// Get total pattern count
/// @return Total number of patterns in database
- (NSInteger)getTotalPatternCount;

#pragma mark - Migration Support

/// Migrate patterns from old format (without date ranges) to new format
/// @param completion Completion block with migration results
- (void)migratePatternDateRangesWithCompletion:(void(^)(NSInteger migratedCount, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
