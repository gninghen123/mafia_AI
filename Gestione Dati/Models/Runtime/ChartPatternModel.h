// ============================================================================
// ChartPatternModel.h - VERSIONE PULITA
// ============================================================================

//
//  ChartPatternModel.h - CLEANED VERSION
//  TradingApp
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"

@class SavedChartData;

NS_ASSUME_NONNULL_BEGIN

@interface ChartPatternModel : NSObject

#pragma mark - Core Properties

/// Unique identifier for this pattern
@property (nonatomic, strong) NSString *patternID;

/// Pattern type (e.g., "Head & Shoulders", "Cup & Handle")
@property (nonatomic, strong) NSString *patternType;

/// UUID reference to SavedChartData file
@property (nonatomic, strong) NSString *savedDataReference;

/// Pattern creation date
@property (nonatomic, strong) NSDate *creationDate;

/// Optional user notes
@property (nonatomic, strong, nullable) NSString *additionalNotes;

#pragma mark - Pattern Time Range Properties

/// Start date of the pattern within the SavedChartData
@property (nonatomic, strong) NSDate *patternStartDate;

/// End date of the pattern within the SavedChartData
@property (nonatomic, strong) NSDate *patternEndDate;

#pragma mark - Derived Properties (Readonly)

/// Symbol from connected SavedChartData (readonly)
@property (nonatomic, readonly, nullable) NSString *symbol;

/// Timeframe from connected SavedChartData (readonly)
@property (nonatomic, readonly) BarTimeframe timeframe;

/// Bar count for the pattern time range (readonly)
@property (nonatomic, readonly) NSInteger patternBarCount;

/// Bar count from connected SavedChartData (readonly) - Full dataset
@property (nonatomic, readonly) NSInteger totalBarCount;

/// Human readable pattern display info
@property (nonatomic, readonly) NSString *displayInfo;

/// Whether the connected SavedChartData exists on disk
@property (nonatomic, readonly) BOOL hasValidSavedData;

/// Whether the pattern date range is valid (startDate < endDate and within SavedChartData range)
@property (nonatomic, readonly) BOOL hasValidDateRange;

#pragma mark - Initialization

/// Initialize with core properties and pattern date range
/// @param patternType The pattern type
/// @param savedDataReference UUID reference to SavedChartData
/// @param startDate Start date of the pattern
/// @param endDate End date of the pattern
/// @param notes Optional user notes
- (instancetype)initWithPatternType:(NSString *)patternType
                 savedDataReference:(NSString *)savedDataReference
                      patternStartDate:(NSDate *)startDate
                        patternEndDate:(NSDate *)endDate
                              notes:(nullable NSString *)notes;

/// Initialize from dictionary (for loading from Core Data)
/// @param dictionary Dictionary from Core Data
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

#pragma mark - Business Logic Methods

/// Load the connected SavedChartData from disk
/// @return SavedChartData object or nil if file doesn't exist
- (nullable SavedChartData *)loadConnectedSavedData;

/// Get bars for the pattern time range only
/// @return Array of HistoricalBarModel objects within pattern date range
- (nullable NSArray *)getPatternBars;

/// Get start and end indices for the pattern within the SavedChartData
/// @param startIndex Output parameter for start index
/// @param endIndex Output parameter for end index
/// @return YES if valid indices found, NO if pattern dates are outside SavedChartData range
- (BOOL)getPatternIndicesWithStartIndex:(NSInteger *)startIndex endIndex:(NSInteger *)endIndex;

/// Update pattern type, date range and notes
/// @param patternType New pattern type
/// @param startDate New start date
/// @param endDate New end date
/// @param notes New notes
- (void)updatePatternType:(NSString *)patternType
           patternStartDate:(NSDate *)startDate
             patternEndDate:(NSDate *)endDate
                    notes:(nullable NSString *)notes;

/// Validate that the referenced SavedChartData exists
/// @return YES if SavedChartData file exists on disk
- (BOOL)validateSavedDataReference;

/// Validate that pattern date range is within SavedChartData bounds
/// @return YES if pattern dates are valid and within SavedChartData range
- (BOOL)validatePatternDateRange;

#pragma mark - Serialization

/// Convert to dictionary for Core Data storage
/// @return Dictionary representation
- (NSDictionary *)toDictionary;

/// Human readable description for debugging
- (NSString *)debugDescription;

@end

NS_ASSUME_NONNULL_END
