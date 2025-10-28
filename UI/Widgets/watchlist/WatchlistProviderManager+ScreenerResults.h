//
//  WatchlistProviderManager+ScreenerResults.h
//  TradingApp
//
//  Extension to load Stooq Screener archived results
//

#import "WatchlistProviderManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface WatchlistProviderManager (ScreenerResults)

#pragma mark - Screener Results Loading

/**
 * Load providers from the most recent screener session (last 7 days)
 * Creates one provider per ModelResult in the session
 */
- (void)loadScreenerResultProviders;

/**
 * Load providers asynchronously (for lazy loading)
 */
- (void)loadScreenerResultProvidersAsync;

/**
 * Reset loading state (call from refreshAllProviders)
 */
+ (void)resetScreenerProvidersState;

/**
 * Get path to screener archive directory
 * @return Full path to directory containing session JSON files
 */
- (NSString *)screenerArchiveDirectory;

/**
 * Find the most recent session file (within last 7 days)
 * @return Full path to session file, or nil if none found
 */
- (nullable NSString *)findMostRecentSessionFile;

@end

NS_ASSUME_NONNULL_END
