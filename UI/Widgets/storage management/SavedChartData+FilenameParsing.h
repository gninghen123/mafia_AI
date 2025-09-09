#import "SavedChartData.h"

NS_ASSUME_NONNULL_BEGIN

@interface SavedChartData (FilenameParsing)

#pragma mark - Simple Filename Parsing (No Object Creation)

/// Extract symbol from filename
+ (nullable NSString *)symbolFromFilename:(NSString *)filename;

/// Extract timeframe description from filename
+ (nullable NSString *)timeframeFromFilename:(NSString *)filename;

/// Extract timeframe enum from filename
+ (BarTimeframe)timeframeEnumFromFilename:(NSString *)filename;

/// Extract type from filename
+ (nullable NSString *)typeFromFilename:(NSString *)filename;

/// Extract bar count from filename
+ (NSInteger)barCountFromFilename:(NSString *)filename;

/// Extract start date from filename
+ (nullable NSDate *)startDateFromFilename:(NSString *)filename;

/// Extract end date from filename
+ (nullable NSDate *)endDateFromFilename:(NSString *)filename;

/// Extract date range string for display
+ (nullable NSString *)dateRangeStringFromFilename:(NSString *)filename;

/// Extract extended hours flag from filename
+ (BOOL)extendedHoursFromFilename:(NSString *)filename;

/// Extract has gaps flag from filename
+ (BOOL)hasGapsFromFilename:(NSString *)filename;

/// Extract creation date from filename
+ (nullable NSDate *)creationDateFromFilename:(NSString *)filename;

/// Extract last update date from filename
+ (nullable NSDate *)lastUpdateFromFilename:(NSString *)filename;

/// Get file size from filesystem
+ (NSInteger)fileSizeFromPath:(NSString *)filePath;

/// Check if filename follows the new format
+ (BOOL)isNewFormatFilename:(NSString *)filename;

@end

NS_ASSUME_NONNULL_END
