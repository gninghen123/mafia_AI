//
// IndicatorRegistry.h
// TradingApp
//
// Registry for managing all available technical indicators
//

#import <Foundation/Foundation.h>
#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Indicator Registry

@interface IndicatorRegistry : NSObject

#pragma mark - Singleton
+ (instancetype)sharedRegistry;

#pragma mark - Registration

/// Register a hardcoded indicator class
/// @param indicatorClass Class that implements TechnicalIndicatorBase
/// @param identifier Unique identifier for the indicator
- (void)registerIndicatorClass:(Class)indicatorClass withIdentifier:(NSString *)identifier;

/// Register a PineScript indicator
/// @param script PineScript source code
/// @param identifier Unique identifier
/// @param error Error pointer for compilation failures
/// @return YES if registration successful
- (BOOL)registerPineScriptIndicator:(NSString *)script
                     withIdentifier:(NSString *)identifier
                              error:(NSError **)error;

#pragma mark - Factory Methods

/// Create indicator instance by identifier
/// @param identifier Indicator identifier
/// @param parameters Custom parameters (nil for defaults)
/// @return Configured indicator instance
- (nullable TechnicalIndicatorBase *)createIndicatorWithIdentifier:(NSString *)identifier
                                                        parameters:(nullable NSDictionary<NSString *, id> *)parameters;

/// Create indicator instance by class
/// @param indicatorClass Indicator class
/// @param parameters Custom parameters (nil for defaults)
/// @return Configured indicator instance
- (nullable TechnicalIndicatorBase *)createIndicatorWithClass:(Class)indicatorClass
                                                   parameters:(nullable NSDictionary<NSString *, id> *)parameters;

#pragma mark - Discovery

/// Get all registered indicator identifiers
/// @return Array of identifier strings
- (NSArray<NSString *> *)allIndicatorIdentifiers;

/// Get all hardcoded indicator identifiers
/// @return Array of hardcoded indicator identifiers
- (NSArray<NSString *> *)hardcodedIndicatorIdentifiers;

/// Get all PineScript indicator identifiers
/// @return Array of PineScript indicator identifiers
- (NSArray<NSString *> *)pineScriptIndicatorIdentifiers;

/// Get indicator display information
/// @param identifier Indicator identifier
/// @return Dictionary with name, description, parameters info
- (nullable NSDictionary<NSString *, id> *)indicatorInfoForIdentifier:(NSString *)identifier;

#pragma mark - Validation

/// Check if indicator is registered
/// @param identifier Indicator identifier
/// @return YES if registered
- (BOOL)isIndicatorRegistered:(NSString *)identifier;

/// Get indicator class for identifier
/// @param identifier Indicator identifier
/// @return Indicator class or nil if not found
- (nullable Class)indicatorClassForIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
