//
//  ScreenedSymbol.h
//  TradingApp
//
//  Represents a symbol that passed screening with selection state
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScreenedSymbol : NSObject

#pragma mark - Core Properties

/// Symbol ticker
@property (nonatomic, strong) NSString *symbol;

/// User selection state (for multi-selection operations)
@property (nonatomic, assign) BOOL isSelected;

/// Which step added this symbol (0-based index, -1 if from universe)
@property (nonatomic, assign) NSInteger addedAtStep;

/// Additional metadata (price, volume, indicators, etc.)
@property (nonatomic, strong, nullable) NSMutableDictionary *metadata;

#pragma mark - Factory Methods

/**
 * Create a screened symbol
 * @param symbol Symbol ticker
 * @param addedAtStep Which step added this symbol
 * @return Initialized symbol
 */
+ (instancetype)symbolWithName:(NSString *)symbol addedAtStep:(NSInteger)addedAtStep;

/**
 * Create a screened symbol with metadata
 * @param symbol Symbol ticker
 * @param addedAtStep Which step added this symbol
 * @param metadata Additional data
 * @return Initialized symbol
 */
+ (instancetype)symbolWithName:(NSString *)symbol
                  addedAtStep:(NSInteger)addedAtStep
                     metadata:(nullable NSDictionary *)metadata;

#pragma mark - Metadata Helpers

/**
 * Set a metadata value
 * @param value Value to store
 * @param key Key name
 */
- (void)setMetadataValue:(id)value forKey:(NSString *)key;

/**
 * Get a metadata value
 * @param key Key name
 * @return Stored value or nil
 */
- (nullable id)metadataValueForKey:(NSString *)key;

/**
 * Check if has metadata for key
 * @param key Key name
 * @return YES if metadata exists
 */
- (BOOL)hasMetadataForKey:(NSString *)key;

#pragma mark - Serialization

/**
 * Convert to dictionary (for JSON serialization)
 * @return Dictionary representation
 */
- (NSDictionary *)toDictionary;

/**
 * Create from dictionary (for JSON deserialization)
 * @param dict Dictionary with symbol data
 * @return Initialized symbol or nil
 */
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

#pragma mark - Comparison

/**
 * Compare symbols by name
 * @param other Other symbol
 * @return Comparison result
 */
- (NSComparisonResult)compare:(ScreenedSymbol *)other;

@end

NS_ASSUME_NONNULL_END
