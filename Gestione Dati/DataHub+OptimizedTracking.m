//
//  DataHub+OptimizedTracking.m
//  Implementazione del sistema di tracking ottimizzato
//

#import "DataHub+OptimizedTracking.h"
#import "DataHub+Private.h"
#import <objc/runtime.h>

// Buffer Keys
static const void *kPendingInteractionCountsKey = &kPendingInteractionCountsKey;
static const void *kPendingLastInteractionsKey = &kPendingLastInteractionsKey;
static const void *kPendingFirstInteractionsKey = &kPendingFirstInteractionsKey;
static const void *kPendingArchiveSymbolsKey = &kPendingArchiveSymbolsKey;

// Timer Keys
static const void *kUserDefaultsBackupTimerKey = &kUserDefaultsBackupTimerKey;
static const void *kCoreDataFlushTimerKey = &kCoreDataFlushTimerKey;

// State Keys
static const void *kLastUserDefaultsBackupKey = &kLastUserDefaultsBackupKey;
static const void *kLastCoreDataFlushKey = &kLastCoreDataFlushKey;
static const void *kIsOptimizedTrackingActiveKey = &kIsOptimizedTrackingActiveKey;

@implementation DataHub (OptimizedTracking)

#pragma mark - Associated Properties

- (NSMutableDictionary *)pendingInteractionCounts {
    NSMutableDictionary *dict = objc_getAssociatedObject(self, kPendingInteractionCountsKey);
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, kPendingInteractionCountsKey, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return dict;
}

- (NSMutableDictionary *)pendingLastInteractions {
    NSMutableDictionary *dict = objc_getAssociatedObject(self, kPendingLastInteractionsKey);
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, kPendingLastInteractionsKey, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return dict;
}

- (NSMutableSet *)pendingFirstInteractions {
    NSMutableSet *set = objc_getAssociatedObject(self, kPendingFirstInteractionsKey);
    if (!set) {
        set = [NSMutableSet set];
        objc_setAssociatedObject(self, kPendingFirstInteractionsKey, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}

- (NSMutableSet *)pendingArchiveSymbols {
    NSMutableSet *set = objc_getAssociatedObject(self, kPendingArchiveSymbolsKey);
    if (!set) {
        set = [NSMutableSet set];
        objc_setAssociatedObject(self, kPendingArchiveSymbolsKey, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}

- (NSTimer *)userDefaultsBackupTimer {
    return objc_getAssociatedObject(self, kUserDefaultsBackupTimerKey);
}

- (void)setUserDefaultsBackupTimer:(NSTimer *)timer {
    objc_setAssociatedObject(self, kUserDefaultsBackupTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTimer *)coreDataFlushTimer {
    return objc_getAssociatedObject(self, kCoreDataFlushTimerKey);
}

- (void)setCoreDataFlushTimer:(NSTimer *)timer {
    objc_setAssociatedObject(self, kCoreDataFlushTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDate *)lastUserDefaultsBackup {
    return objc_getAssociatedObject(self, kLastUserDefaultsBackupKey);
}

- (void)setLastUserDefaultsBackup:(NSDate *)date {
    objc_setAssociatedObject(self, kLastUserDefaultsBackupKey, date, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDate *)lastCoreDataFlush {
    return objc_getAssociatedObject(self, kLastCoreDataFlushKey);
}

- (void)setLastCoreDataFlush:(NSDate *)date {
    objc_setAssociatedObject(self, kLastCoreDataFlushKey, date, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isOptimizedTrackingActive {
    NSNumber *value = objc_getAssociatedObject(self, kIsOptimizedTrackingActiveKey);
    return value ? [value boolValue] : NO;
}

- (void)setOptimizedTrackingActive:(BOOL)active {
    objc_setAssociatedObject(self, kIsOptimizedTrackingActiveKey, @(active), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - System Lifecycle

- (void)initializeOptimizedTracking {
    [self loadTrackingConfiguration];
    
    if (!self.optimizedTrackingEnabled) {
        NSLog(@"⚠️ Optimized tracking disabled in preferences - using legacy immediate saves");
        return;
    }
    
    NSLog(@"🚀 Initializing optimized tracking system...");
    
    // Clear any existing state
    [self shutdownOptimizedTracking];
    
    // Initialize buffers (properties initialize themselves)
    [self pendingInteractionCounts];
    [self pendingLastInteractions];
    [self pendingFirstInteractions];
    [self pendingArchiveSymbols];
    
    // Setup timers based on configuration
    [self setupOptimizedTimers];
    
    // Setup app lifecycle observers
    [self setupAppLifecycleObservers];
    
    // Restore any pending data from crash
    [self restorePendingDataFromUserDefaults];
    
    // Mark as active
    [self setOptimizedTrackingActive:YES];
    
    NSLog(@"✅ Optimized tracking system initialized");
    NSLog(@"   UserDefaults backup: every %.0f minutes", self.userDefaultsBackupInterval / 60.0);
    NSLog(@"   Core Data flush: %@", self.coreDataFlushInterval > 0 ? [NSString stringWithFormat:@"every %.0f minutes", self.coreDataFlushInterval / 60.0] : @"app close only");
    NSLog(@"   Max batch size: %ld symbols", (long)self.maxBatchSize);
}

- (void)shutdownOptimizedTracking {
    if (![self isOptimizedTrackingActive]) return;
    
    NSLog(@"🔄 Shutting down optimized tracking system...");
    
    // Invalidate timers
    [self.userDefaultsBackupTimer invalidate];
    [self.coreDataFlushTimer invalidate];
    [self setUserDefaultsBackupTimer:nil];
    [self setCoreDataFlushTimer:nil];
    
    // Flush any pending data
    [self performEmergencyFlushSync];
    
    // Remove observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidResignActiveNotification object:nil];
    
    // Mark as inactive
    [self setOptimizedTrackingActive:NO];
    
    NSLog(@"✅ Optimized tracking system shut down");
}

- (void)setupOptimizedTimers {
    // UserDefaults backup timer
    if (self.userDefaultsBackupInterval > 0) {
        NSTimer *udTimer = [NSTimer scheduledTimerWithTimeInterval:self.userDefaultsBackupInterval
                                                            target:self
                                                          selector:@selector(performScheduledUserDefaultsBackup)
                                                          userInfo:nil
                                                           repeats:YES];
        [self setUserDefaultsBackupTimer:udTimer];
        NSLog(@"⏰ UserDefaults backup timer set: every %.0f seconds", self.userDefaultsBackupInterval);
    }
    
    // Core Data flush timer (if not app-close-only)
    if (self.coreDataFlushInterval > 0) {
        NSTimer *cdTimer = [NSTimer scheduledTimerWithTimeInterval:self.coreDataFlushInterval
                                                            target:self
                                                          selector:@selector(performScheduledCoreDataFlush)
                                                          userInfo:nil
                                                           repeats:YES];
        [self setCoreDataFlushTimer:cdTimer];
        NSLog(@"⏰ Core Data flush timer set: every %.0f seconds", self.coreDataFlushInterval);
    } else {
        NSLog(@"⏰ Core Data flush: app-close-only mode");
    }
}

@end
