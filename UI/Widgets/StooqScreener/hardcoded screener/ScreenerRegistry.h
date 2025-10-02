//
//  ScreenerRegistry.h
//  TradingApp
//
//  Registry for all available screeners
//

#import <Foundation/Foundation.h>
#import "BaseScreener.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScreenerRegistry : NSObject

#pragma mark - Singleton

+ (instancetype)sharedRegistry;

#pragma mark - Registration

/**
 * Register a screener instance
 * @param screener Screener instance to register
 */
- (void)registerScreener:(BaseScreener *)screener;

/**
 * Register screener class (will instantiate on demand)
 * @param screenerClass Class that inherits from BaseScreener
 */
- (void)registerScreenerClass:(Class)screenerClass;

#pragma mark - Access

/**
 * Get screener by ID
 * @param screenerID Screener identifier
 * @return Screener instance or nil if not found
 */
- (nullable BaseScreener *)screenerWithID:(NSString *)screenerID;

/**
 * Get all registered screener IDs
 * @return Array of screener IDs
 */
- (NSArray<NSString *> *)allScreenerIDs;

/**
 * Get all registered screeners
 * @return Array of screener instances
 */
- (NSArray<BaseScreener *> *)allScreeners;

/**
 * Check if screener is registered
 * @param screenerID Screener identifier
 * @return YES if registered
 */
- (BOOL)isScreenerRegistered:(NSString *)screenerID;

#pragma mark - Information

/**
 * Get screener info dictionary
 * @param screenerID Screener identifier
 * @return Dictionary with displayName, description, minBarsRequired
 */
- (nullable NSDictionary *)infoForScreener:(NSString *)screenerID;

@end

NS_ASSUME_NONNULL_END
