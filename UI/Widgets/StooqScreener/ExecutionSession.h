//
//  ExecutionSession.h
//  TradingApp
//
//  Represents a complete screening execution session (for Archive)
//

#import <Foundation/Foundation.h>
#import "ScreenerModel.h"

@class ScreenedSymbol;

NS_ASSUME_NONNULL_BEGIN

@interface ExecutionSession : NSObject

#pragma mark - Session Properties

/// Unique session identifier (UUID)
@property (nonatomic, strong) NSString *sessionID;

/// When this session was executed
@property (nonatomic, strong) NSDate *executionDate;

/// Total number of models executed
@property (nonatomic, assign) NSInteger totalModels;

/// Total unique symbols across all models
@property (nonatomic, assign) NSInteger totalSymbols;

/// Total execution time for all models
@property (nonatomic, assign) NSTimeInterval totalExecutionTime;

/// Initial universe of symbols used
@property (nonatomic, strong) NSArray<NSString *> *universe;

/// Results from each model
@property (nonatomic, strong) NSArray<ModelResult *> *modelResults;

/// Optional notes/description for this session
@property (nonatomic, strong, nullable) NSString *notes;

#pragma mark - Factory Methods

/**
 * Create a new execution session
 * @param modelResults Array of model results
 * @param universe Initial symbol universe
 * @return Initialized session
 */
+ (instancetype)sessionWithModelResults:(NSArray<ModelResult *> *)modelResults
                               universe:(NSArray<NSString *> *)universe;

/**
 * Create a session with custom date (for loading from archive)
 * @param modelResults Array of model results
 * @param universe Initial symbol universe
 * @param date Execution date
 * @return Initialized session
 */
+ (instancetype)sessionWithModelResults:(NSArray<ModelResult *> *)modelResults
                               universe:(NSArray<NSString *> *)universe
                                   date:(NSDate *)date;

#pragma mark - Analysis

/**
 * Get all unique symbols across all models
 * @return Set of unique symbols
 */
- (NSSet<NSString *> *)allUniqueSymbols;

/**
 * Get all selected symbols across all models
 * @return Array of selected ScreenedSymbol objects
 */
- (NSArray<ScreenedSymbol *> *)allSelectedSymbols;

/**
 * Get symbols that appear in multiple models
 * @return Dictionary of symbol → array of model names
 */
- (NSDictionary<NSString *, NSArray<NSString *> *> *)symbolsInMultipleModels;

/**
 * Get statistics for this session
 * @return Dictionary with stats (avg_symbols_per_model, etc.)
 */
- (NSDictionary *)statistics;

#pragma mark - Persistence

/**
 * Convert to dictionary (for JSON serialization)
 * @return Dictionary representation
 */
- (NSDictionary *)toDictionary;

/**
 * Create from dictionary (for JSON deserialization)
 * @param dict Dictionary with session data
 * @return Initialized session or nil
 */
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

/**
 * Save session to JSON file
 * @param filePath File path to save to
 * @param error Error pointer
 * @return YES if successful
 */
- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error;

/**
 * Load session from JSON file
 * @param filePath File path to load from
 * @param error Error pointer
 * @return Loaded session or nil
 */
+ (nullable instancetype)loadFromFile:(NSString *)filePath error:(NSError **)error;

#pragma mark - Display

/**
 * Get formatted execution date string
 * @return Date string (e.g., "2025-01-15 14:30")
 */
- (NSString *)formattedExecutionDate;

/**
 * Get summary string for UI display
 * @return Summary (e.g., "5 models, 127 symbols, 12.3s")
 */
- (NSString *)summaryString;

@end

NS_ASSUME_NONNULL_END
