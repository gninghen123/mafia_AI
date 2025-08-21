//
//  ChartPatternModel.h
//  TradingApp
//
//  Runtime Model per Chart Patterns - Thread-safe, UI-ready
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

#pragma mark - Derived Properties (Readonly)

/// Symbol from connected SavedChartData (readonly)
@property (nonatomic, readonly, nullable) NSString *symbol;

/// Start date from connected SavedChartData (readonly)
@property (nonatomic, readonly, nullable) NSDate *startDate;

/// End date from connected SavedChartData (readonly)
@property (nonatomic, readonly, nullable) NSDate *endDate;

/// Timeframe from connected SavedChartData (readonly)
@property (nonatomic, readonly) BarTimeframe timeframe;

/// Bar count from connected SavedChartData (readonly)
@property (nonatomic, readonly) NSInteger barCount;

/// Human readable pattern display info
@property (nonatomic, readonly) NSString *displayInfo;

/// Whether the connected SavedChartData exists on disk
@property (nonatomic, readonly) BOOL hasValidSavedData;

#pragma mark - Initialization

/// Initialize with core properties
/// @param patternType The pattern type
/// @param savedDataReference UUID reference to SavedChartData
/// @param notes Optional user notes
- (instancetype)initWithPatternType:(NSString *)patternType
                 savedDataReference:(NSString *)savedDataReference
                              notes:(nullable NSString *)notes;

/// Initialize from dictionary (for loading from Core Data)
/// @param dictionary Dictionary from Core Data
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

#pragma mark - Business Logic Methods

/// Load the connected SavedChartData from disk
/// @return SavedChartData object or nil if file doesn't exist
- (nullable SavedChartData *)loadConnectedSavedData;

/// Update pattern type and notes
/// @param patternType New pattern type
/// @param notes New notes
- (void)updatePatternType:(NSString *)patternType notes:(nullable NSString *)notes;

/// Validate that the referenced SavedChartData exists
/// @return YES if SavedChartData file exists on disk
- (BOOL)validateSavedDataReference;

#pragma mark - Serialization

/// Convert to dictionary for Core Data storage
/// @return Dictionary representation
- (NSDictionary *)toDictionary;

/// Human readable description for debugging
- (NSString *)debugDescription;

@end

NS_ASSUME_NONNULL_END
