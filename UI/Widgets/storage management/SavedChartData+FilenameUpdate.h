#import "SavedChartData.h"

NS_ASSUME_NONNULL_BEGIN

@interface SavedChartData (FilenameUpdate)

/// Generate current filename based on latest SavedChartData state
- (NSString *)generateCurrentFilename;

/// Generate filename for specific file path, preserving directory
- (NSString *)generateUpdatedFilePath:(NSString *)currentFilePath;

/// Update filename to match current SavedChartData state
- (nullable NSString *)updateFilenameMetadata:(NSString *)currentFilePath error:(NSError **)error;

/// Check if filename needs updating (metadata mismatch)
- (BOOL)filenameNeedsUpdate:(NSString *)filePath;

/// Save to file with automatic filename update
- (nullable NSString *)saveToFileWithFilenameUpdate:(NSString *)filePath error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
