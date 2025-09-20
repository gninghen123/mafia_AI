//
//  SavedChartData.h
//  TradingApp
//
//  Model per il salvataggio delle barre visibili del chart in binary plist
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"
#import "CommonTypes.h"

@class ChartWidget;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SavedChartDataType) {
    SavedChartDataTypeSnapshot,    // Range specifico, immutabile
    SavedChartDataTypeContinuous   // Range aperto, aggiornabile
};

@interface SavedChartData : NSObject

#pragma mark - Core Properties

/// Unique identifier for this saved chart data
@property (nonatomic, strong) NSString *chartID;

/// Symbol associated with this chart data
@property (nonatomic, strong) NSString *symbol;

/// Timeframe of the saved data (using BarTimeframe enum)
@property (nonatomic, assign) BarTimeframe timeframe;

/// Type of saved data (snapshot vs continuous)
@property (nonatomic, assign) SavedChartDataType dataType;

/// Start date of the saved range
@property (nonatomic, strong) NSDate *startDate;

/// End date of the saved range
@property (nonatomic, strong) NSDate *endDate;

/// Array of historical bars in the saved range
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *historicalBars;

/// Creation timestamp
@property (nonatomic, strong) NSDate *creationDate;

/// Last update timestamp (for continuous data)
@property (nonatomic, strong, nullable) NSDate *lastUpdateDate;

/// Whether data includes extended hours (after-hours, pre-market)
@property (nonatomic, assign) BOOL includesExtendedHours;

/// Optional user notes
@property (nonatomic, strong, nullable) NSString *notes;

#pragma mark - Continuous Storage Properties

/// For continuous storage: indicates if data has gaps that couldn't be filled
@property (nonatomic, assign) BOOL hasGaps;

/// For continuous storage: last successful API update attempt
@property (nonatomic, strong, nullable) NSDate *lastSuccessfulUpdate;

/// For continuous storage: next scheduled update date
@property (nonatomic, strong, nullable) NSDate *nextScheduledUpdate;

#pragma mark - Metadata Properties (Readonly)

/// Total number of bars saved
@property (nonatomic, readonly) NSInteger barCount;

/// Duration of the saved range in minutes
@property (nonatomic, readonly) NSInteger rangeDurationMinutes;

/// Human readable description of the timeframe
@property (nonatomic, readonly) NSString *timeframeDescription;

/// File size estimation in bytes
@property (nonatomic, readonly) NSInteger estimatedFileSize;

#pragma mark - Initialization

/// Initialize with chart widget's current visible range (SNAPSHOT)
/// @param chartWidget The chart widget to save data from
/// @param notes Optional user notes
- (instancetype)initSnapshotWithChartWidget:(ChartWidget *)chartWidget notes:(nullable NSString *)notes;

/// Initialize with chart widget's full data range (CONTINUOUS)
/// @param chartWidget The chart widget to save data from
/// @param notes Optional user notes
- (instancetype)initContinuousWithChartWidget:(ChartWidget *)chartWidget notes:(nullable NSString *)notes;

/// Initialize from dictionary (for loading from plist)
/// @param dictionary Dictionary loaded from binary plist
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

#pragma mark - Data Management

/// Merge new bars with existing data (for continuous storage updates)
/// @param newBars Array of new bars to merge
/// @param overlapBarCount Number of bars to expect as overlap
/// @return YES if merge was successful, NO if data incompatible
- (BOOL)mergeWithNewBars:(NSArray<HistoricalBarModel *> *)newBars overlapBarCount:(NSInteger)overlapBarCount;

/// Convert continuous storage to snapshot (when gaps become irreversible)
- (void)convertToSnapshot;

#pragma mark - Serialization

/// Convert to dictionary for binary plist storage
- (NSDictionary *)toDictionary;

/// Create SavedChartData from binary plist file
/// @param filePath Path to the binary plist file
+ (nullable instancetype)loadFromFile:(NSString *)filePath;

/// Save to binary plist file
/// @param filePath Path where to save the binary plist
/// @param error Error pointer for any save issues
- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error;

#pragma mark - Helper Methods

/// Generate a human-readable filename for saving
- (NSString *)suggestedFilename;

/// Get formatted date range string for UI display
- (NSString *)formattedDateRange;

/// Validate that the saved data is still valid
- (BOOL)isDataValid;

/// Check if this data is compatible for merging with new bars
/// @param newBars Bars to check compatibility with
/// @return YES if compatible (same symbol, timeframe, extended hours setting)
- (BOOL)isCompatibleWithBars:(NSArray<HistoricalBarModel *> *)newBars;

/// Calculate days until next API limit expiration
- (NSInteger)daysUntilAPILimitExpiration;


+(void)convertMyFewFiles;

@end

NS_ASSUME_NONNULL_END
