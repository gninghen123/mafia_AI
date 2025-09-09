// FILENAME PARSER SEMPLICE - SavedChartData+FilenameParsing.h
// Parser leggero per estrarre metadati dai filename senza creare oggetti complessi

#import "SavedChartData.h"

NS_ASSUME_NONNULL_BEGIN

@interface SavedChartData (FilenameParsing)

#pragma mark - Simple Filename Parsing (No Object Creation)

/// Extract symbol from filename
/// @param filename The filename to parse
/// @return Symbol string or nil if not parseable
+ (nullable NSString *)symbolFromFilename:(NSString *)filename;

/// Extract timeframe description from filename
/// @param filename The filename to parse
/// @return Timeframe string (e.g., "5min", "1h", "1d")
+ (nullable NSString *)timeframeFromFilename:(NSString *)filename;

/// Extract timeframe enum from filename
/// @param filename The filename to parse
/// @return BarTimeframe enum value
+ (BarTimeframe)timeframeEnumFromFilename:(NSString *)filename;

/// Extract type from filename
/// @param filename The filename to parse
/// @return "Continuous" or "Snapshot"
+ (nullable NSString *)typeFromFilename:(NSString *)filename;

/// Extract bar count from filename
/// @param filename The filename to parse
/// @return Number of bars
+ (NSInteger)barCountFromFilename:(NSString *)filename;

/// Extract start date from filename
/// @param filename The filename to parse
/// @return Start date or nil if not parseable
+ (nullable NSDate *)startDateFromFilename:(NSString *)filename;

/// Extract end date from filename
/// @param filename The filename to parse
/// @return End date or nil if not parseable
+ (nullable NSDate *)endDateFromFilename:(NSString *)filename;

/// Extract date range string for display
/// @param filename The filename to parse
/// @return Formatted date range string (e.g., "Jan 1 - Aug 27")
+ (nullable NSString *)dateRangeStringFromFilename:(NSString *)filename;

/// Extract extended hours flag from filename
/// @param filename The filename to parse
/// @return YES if includes extended hours
+ (BOOL)extendedHoursFromFilename:(NSString *)filename;

/// Extract has gaps flag from filename
/// @param filename The filename to parse
/// @return YES if has gaps
+ (BOOL)hasGapsFromFilename:(NSString *)filename;

/// Extract creation date from filename
/// @param filename The filename to parse
/// @return Creation date or nil if not parseable
+ (nullable NSDate *)creationDateFromFilename:(NSString *)filename;

/// Extract last update date from filename (for continuous storage)
/// @param filename The filename to parse
/// @return Last update date or nil if not parseable
+ (nullable NSDate *)lastUpdateFromFilename:(NSString *)filename;

/// Get file size from filesystem
/// @param filePath Full path to the file
/// @return File size in bytes
+ (NSInteger)fileSizeFromPath:(NSString *)filePath;

/// Check if filename follows the new format
/// @param filename The filename to check
/// @return YES if filename has new format with metadata
+ (BOOL)isNewFormatFilename:(NSString *)filename;

@end

NS_ASSUME_NONNULL_END
