// ============================================================================
// DataHub+SmartTracking.h - SMART SYMBOL TRACKING CATEGORY HEADER
// ============================================================================
// Public interface for smart symbol interaction tracking
// Only tracks REAL user interactions: chain focus, connection work, tag work
// ============================================================================

#import "DataHub.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (SmartTracking)

#pragma mark - Initialization

/**
 * Initialize smart tracking observers
 * Call this after DataHub initialization
 */
- (void)initializeSmartTracking;

#pragma mark - Configuration

/**
 * Set chain deduplication timeout (default: 5 minutes)
 * Same symbol in chain within timeout won't increment again
 */
- (void)setChainDeduplicationTimeout:(NSTimeInterval)timeout;

/**
 * Get current chain deduplication timeout
 */
- (NSTimeInterval)getChainDeduplicationTimeout;

/**
 * Clear chain deduplication state (force next symbol to count)
 */
- (void)clearChainDeduplicationState;

#pragma mark - Analytics

/**
 * Get smart tracking statistics
 * @return Dictionary with interaction distribution stats
 */
- (NSDictionary *)getSmartTrackingStats;

/**
 * Generate detailed tracking report to console
 */
- (void)generateSmartTrackingReport;

/**
 * Get most interacted symbols (sorted by interaction count)
 * @param limit Maximum number of symbols to return
 * @return Array of Symbol entities sorted by interaction count descending
 */
- (NSArray<Symbol *> *)getMostInteractedSymbols:(NSInteger)limit;

/**
 * Log top interacted symbols to console
 * @param limit Number of top symbols to display
 */
- (void)logTopInteractedSymbols:(NSInteger)limit;

#pragma mark - Testing/Debugging

/**
 * Simulate chain focus for testing
 * @param symbol Symbol to simulate focus on
 */
- (void)simulateChainFocus:(NSString *)symbol;

/**
 * Simulate tag work for testing
 * @param symbol Symbol to work on
 * @param tag Tag to add/remove
 * @param action "added" or "removed"
 */
- (void)simulateTagWork:(NSString *)symbol tag:(NSString *)tag action:(NSString *)action;

@end

NS_ASSUME_NONNULL_END
