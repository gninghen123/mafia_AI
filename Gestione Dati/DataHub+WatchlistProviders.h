//
//  DataHub+WatchlistProviders.h
//  TradingApp
//
//  Extensions to DataHub to support the new unified WatchlistWidget provider system
//

#import "DataHub.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (WatchlistProviders)

#pragma mark - Tag-Based Symbol Discovery

/**
 * Get all symbols that contain a specific tag in their tags array
 * @param tag The tag to search for (e.g., "earnings", "biotech")
 * @param completion Completion block with matching symbols
 */
- (void)getSymbolsWithTag:(NSString *)tag
               completion:(void(^)(NSArray<NSString *> *symbols))completion;

/**
 * Discover all unique tags currently in use across all Symbol entities
 * @param completion Completion block with array of tag strings
 */
- (void)discoverAllActiveTagsWithCompletion:(void(^)(NSArray<NSString *> *tags))completion;

/**
 * Get symbols for multiple tags (OR operation)
 * @param tags Array of tags to search for
 * @param completion Completion block with matching symbols
 */
- (void)getSymbolsWithAnyOfTags:(NSArray<NSString *> *)tags
                     completion:(void(^)(NSArray<NSString *> *symbols))completion;

#pragma mark - Interaction-Based Baskets

/**
 * Get symbols based on their last interaction within a date range
 * @param days Number of days to look back (1=today, 7=week, 30=month)
 * @param completion Completion block with symbols ordered by recent interaction
 */
- (void)getSymbolsWithInteractionInLastDays:(NSInteger)days
                                 completion:(void(^)(NSArray<NSString *> *symbols))completion;

/**
 * Get symbols interacted with today
 * @param completion Completion block with today's symbols
 */
- (void)getTodayInteractionSymbolsWithCompletion:(void(^)(NSArray<NSString *> *symbols))completion;

/**
 * Update last interaction timestamp for a symbol (called automatically by SmartTracking)
 * @param symbol The symbol to update
 */
- (void)updateLastInteractionForSymbol:(NSString *)symbol;

#pragma mark - Archive Management

/**
 * Archive current basket data to disk for historical reference
 * @param date The date key for the archive (YYYY-MM-DD format)
 * @param symbols Array of symbols to archive
 * @param completion Completion block indicating success
 */
- (void)archiveBasketSymbols:(NSArray<NSString *> *)symbols
                     forDate:(NSString *)date
                  completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/**
 * Load archived basket data from disk
 * @param archiveKey The archive key (format: "YYYY-QX/YYYY-MM-DD")
 * @param completion Completion block with archived symbols
 */
- (void)loadArchivedBasketWithKey:(NSString *)archiveKey
                       completion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion;

/**
 * Discover available archive files on disk
 * @param completion Completion block with array of archive keys
 */
- (void)discoverAvailableArchivesWithCompletion:(void(^)(NSArray<NSString *> *archiveKeys))completion;

/**
 * Automatically archive baskets older than 30 days to disk
 * This should be called periodically by the app
 */
- (void)performAutomaticBasketArchiving;

#pragma mark - Smart Symbol Discovery

/**
 * Get recently added symbols (useful for "Recent" providers)
 * @param days Number of days to look back
 * @param completion Completion block with recently added symbols
 */
- (void)getRecentlyAddedSymbolsInLastDays:(NSInteger)days
                               completion:(void(^)(NSArray<NSString *> *symbols))completion;

/**
 * Get symbols sorted by interaction frequency
 * @param limit Maximum number of symbols to return
 * @param completion Completion block with most frequently interacted symbols
 */
- (void)getMostFrequentlyUsedSymbols:(NSInteger)limit
                          completion:(void(^)(NSArray<NSString *> *symbols))completion;


#pragma mark - Daily Archive Management

/**
 * Ensure today's archive watchlist exists in Core Data
 */
- (void)ensureTodayArchiveExists;

/**
 * Add a symbol to today's archive
 * @param symbolName The symbol to add to today's archive
 */
- (void)addSymbolToTodayArchive:(NSString *)symbolName;

/**
 * Perform catch-up archiving for missed days
 */
- (void)performCatchUpArchiving;

/**
 * Archive a specific day if it has symbol activity
 * @param dateString Date in YYYY-MM-DD format
 */
- (void)archiveDayIfHasActivity:(NSString *)dateString;

/**
 * Perform archive cleanup (migrate old archives to disk)
 */
- (void)performArchiveCleanupIfNeeded;

/**
 * Get symbols that were active on a specific date
 * @param date The date to check for symbol activity
 * @return Array of symbol names that were active on that date
 */
- (NSArray<NSString *> *)getSymbolsForSpecificDate:(NSDate *)date;
@end

NS_ASSUME_NONNULL_END
