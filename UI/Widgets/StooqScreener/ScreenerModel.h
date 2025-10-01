//
//  ScreenerModel.h
//  TradingApp
//
//  Represents a screening model (pipeline of sequential screeners)
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ============================================================================
// SCREENER STEP
// ============================================================================

@interface ScreenerStep : NSObject

/// ID of the screener to execute
@property (nonatomic, strong) NSString *screenerID;

/// Where to get input symbols: "universe" or "previous"
@property (nonatomic, strong) NSString *inputSource;

/// Parameters for this screener execution
@property (nonatomic, strong) NSDictionary *parameters;

/// Factory method
+ (instancetype)stepWithScreenerID:(NSString *)screenerID
                       inputSource:(NSString *)inputSource
                        parameters:(NSDictionary *)parameters;

/// Convert to/from dictionary (for JSON serialization)
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

// ============================================================================
// STEP RESULT (intermediate result of one screener step)
// ============================================================================

@interface StepResult : NSObject

/// Screener ID that produced this result
@property (nonatomic, strong) NSString *screenerID;

/// Display name of the screener
@property (nonatomic, strong) NSString *screenerName;

/// Symbols that passed this step
@property (nonatomic, strong) NSArray<NSString *> *symbols;

/// Input count (how many symbols came in)
@property (nonatomic, assign) NSInteger inputCount;

/// Execution time in seconds
@property (nonatomic, assign) NSTimeInterval executionTime;

@end

// ============================================================================
// MODEL RESULT (final result of entire model execution)
// ============================================================================

@interface ModelResult : NSObject

/// Model ID
@property (nonatomic, strong) NSString *modelID;

/// Model display name
@property (nonatomic, strong) NSString *modelName;

/// Execution timestamp
@property (nonatomic, strong) NSDate *executionTime;

/// Final symbols (output of last step)
@property (nonatomic, strong) NSArray<NSString *> *finalSymbols;

/// Intermediate results from each step (for debugging/analysis)
@property (nonatomic, strong) NSArray<StepResult *> *stepResults;

/// Total execution time
@property (nonatomic, assign) NSTimeInterval totalExecutionTime;

/// Initial universe size
@property (nonatomic, assign) NSInteger initialUniverseSize;

@end

// ============================================================================
// SCREENER MODEL
// ============================================================================

@interface ScreenerModel : NSObject

/// Unique identifier
@property (nonatomic, strong) NSString *modelID;

/// Display name
@property (nonatomic, strong) NSString *displayName;

/// Description of what this model does
@property (nonatomic, strong, nullable) NSString *modelDescription;

/// Sequential steps (screener pipeline)
@property (nonatomic, strong) NSArray<ScreenerStep *> *steps;

/// Schedule: "manual", "daily_eod", "intraday"
@property (nonatomic, strong) NSString *schedule;

/// Is this model enabled?
@property (nonatomic, assign) BOOL isEnabled;

/// Creation/modification dates
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *modifiedAt;

#pragma mark - Factory Methods

+ (instancetype)modelWithID:(NSString *)modelID
                displayName:(NSString *)displayName
                      steps:(NSArray<ScreenerStep *> *)steps;

#pragma mark - Validation

/// Check if model is valid (has steps, screeners exist, etc.)
- (BOOL)isValid;

/// Get total minimum bars required across all steps
- (NSInteger)totalMinBarsRequired;

#pragma mark - Serialization

/// Convert to dictionary (for JSON save)
- (NSDictionary *)toDictionary;

/// Create from dictionary (for JSON load)
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

/// Save to JSON file
- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error;

/// Load from JSON file
+ (nullable instancetype)loadFromFile:(NSString *)filePath error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
