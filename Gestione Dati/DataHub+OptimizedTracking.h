//
//  DataHub+OptimizedTracking.h
//  Sistema di tracking ottimizzato che sostituisce le chiamate sincrone
//

#import "DataHub.h"
#import "DataHub+TrackingPreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (OptimizedTracking)

#pragma mark - Optimized Tracking System

/// Initialize the optimized tracking system
- (void)initializeOptimizedTracking;

/// Shutdown the optimized tracking system
- (void)shutdownOptimizedTracking;

/// Check if optimized tracking is currently active
- (BOOL)isOptimizedTrackingActive;

#pragma mark - Symbol Interaction Methods (Replace Existing)

/// Track symbol interaction (replaces incrementInteractionForSymbol:)
/// @param symbolName The symbol that was interacted with
- (void)trackSymbolInteraction:(NSString *)symbolName;

/// Track symbol interaction with context
/// @param symbolName The symbol that was interacted with
/// @param context Context of interaction (chain, connection, tag, etc.)
- (void)trackSymbolInteraction:(NSString *)symbolName context:(NSString *)context;

/// Track archive interaction (replaces addSymbolToTodayArchive:)
/// @param symbolName The symbol to add to today's archive
- (void)trackSymbolForArchive:(NSString *)symbolName;

#pragma mark - Manual Operations

/// Force immediate backup to UserDefaults
- (void)performImmediateUserDefaultsBackup;

/// Force immediate flush to Core Data
/// @param completion Completion block called when flush completes
- (void)performImmediateCoreDataFlush:(void(^)(BOOL success))completion;

#pragma mark - Statistics and Monitoring

/// Get current buffer statistics
- (NSDictionary *)getBufferStatistics;

/// Get last operation timestamps
- (NSDictionary *)getLastOperationTimestamps;

/// Clear all pending buffers (for testing)
- (void)clearAllPendingBuffers;


- (void)restartOptimizedTrackingWithNewConfiguration;

@end

NS_ASSUME_NONNULL_END
