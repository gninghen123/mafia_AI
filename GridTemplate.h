//
//  GridTemplate.h
//  TradingApp
//
//  Simplified grid template with dynamic rows/cols and proportions
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GridTemplate : NSObject

// Grid dimensions
@property (nonatomic, assign) NSInteger rows;          // Number of rows (1-3)
@property (nonatomic, assign) NSInteger cols;          // Number of columns (1-3)
@property (nonatomic, strong) NSString *displayName;   // User-friendly name (e.g., "2×3 Grid")

// 🆕 Custom proportions for resizable splits
@property (nonatomic, strong, nullable) NSArray<NSNumber *> *rowHeights;    // Proportions [0.0-1.0], sum = 1.0
@property (nonatomic, strong, nullable) NSArray<NSNumber *> *columnWidths;  // Proportions [0.0-1.0], sum = 1.0

#pragma mark - Initialization

/**
 * Creates a new grid template with specified dimensions
 * @param rows Number of rows (1-3)
 * @param cols Number of columns (1-3)
 * @param name Display name for the template
 * @return New GridTemplate instance with uniform proportions
 */
+ (instancetype)templateWithRows:(NSInteger)rows
                            cols:(NSInteger)cols
                     displayName:(NSString *)name;

/**
 * Creates a template with custom proportions
 * @param rows Number of rows
 * @param cols Number of columns
 * @param name Display name
 * @param rowHeights Array of NSNumber with row proportions (must sum to 1.0)
 * @param columnWidths Array of NSNumber with column proportions (must sum to 1.0)
 */
+ (instancetype)templateWithRows:(NSInteger)rows
                            cols:(NSInteger)cols
                     displayName:(NSString *)name
                      rowHeights:(nullable NSArray<NSNumber *> *)rowHeights
                    columnWidths:(nullable NSArray<NSNumber *> *)columnWidths;

#pragma mark - Proportions Management

/**
 * Resets proportions to uniform distribution
 * Example: 3 rows → [0.333, 0.333, 0.334]
 */
- (void)resetToUniformProportions;

/**
 * Validates that proportions arrays are valid
 * @return YES if proportions are valid (correct count, sum to ~1.0)
 */
- (BOOL)validateProportions;

/**
 * Total number of cells in the grid
 */
- (NSInteger)totalCells;

#pragma mark - Serialization

/**
 * Serializes the template to a dictionary for saving
 */
- (NSDictionary *)serialize;

/**
 * Restores a template from a serialized dictionary
 */
+ (instancetype)deserialize:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
