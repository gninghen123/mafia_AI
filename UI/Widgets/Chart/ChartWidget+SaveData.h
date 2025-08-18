//
//  ChartWidget+SaveData.h
//  TradingApp
//
//  Extension per il salvataggio delle barre visibili e continuous storage
//

#import "ChartWidget.h"
#import "SavedChartData.h"

NS_ASSUME_NONNULL_BEGIN

// Forward declaration to access private properties
@interface ChartWidget (SaveDataPrivate)
- (NSArray<HistoricalBarModel *> *)chartData;
@end

@interface ChartWidget (SaveData)

#pragma mark - Save Visible Range (Snapshot)

/// Save currently visible bars as snapshot with user interaction
- (void)saveVisibleRangeAsSnapshotInteractive;

/// Save currently visible bars as snapshot programmatically
/// @param notes Optional user notes
/// @param completion Completion block with success status and file path
- (void)saveVisibleRangeAsSnapshot:(nullable NSString *)notes
                        completion:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion;

#pragma mark - Save Full Data (Continuous)

/// Save all loaded data as continuous storage with user interaction
- (void)saveFullDataAsContinuousInteractive;

/// Save all loaded data as continuous storage programmatically
/// @param notes Optional user notes
/// @param completion Completion block with success status and file path
- (void)saveFullDataAsContinuous:(nullable NSString *)notes
                      completion:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion;

#pragma mark - Load Saved Data

/// Show load dialog and apply saved data to chart
- (void)loadSavedDataInteractive;

/// Load saved data from file and apply to chart
/// @param filePath Path to the saved chart data file
/// @param completion Completion block with success status
- (void)loadSavedDataFromFile:(NSString *)filePath
                   completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

#pragma mark - File Management

/// Get the default directory for saved chart data
+ (NSString *)savedChartDataDirectory;

/// Ensure the saved chart data directory exists
+ (BOOL)ensureSavedChartDataDirectoryExists:(NSError **)error;

/// Get list of all saved chart data files
+ (NSArray<NSString *> *)availableSavedChartDataFiles;

/// Get list of saved chart data files filtered by type
+ (NSArray<NSString *> *)availableSavedChartDataFilesOfType:(SavedChartDataType)dataType;

/// Delete a saved chart data file
+ (BOOL)deleteSavedChartDataFile:(NSString *)filePath error:(NSError **)error;

#pragma mark - Context Menu Integration

/// Add save data menu items to existing context menu
- (void)addSaveDataMenuItemsToMenu:(NSMenu *)menu;

@end

NS_ASSUME_NONNULL_END

