//
//  DataHub+OptimizedTracking.m
//  Implementazione completa del sistema di tracking ottimizzato
//

#import "DataHub+OptimizedTracking.h"
#import "DataHub+Private.h"
#import <objc/runtime.h>
#import <AppKit/AppKit.h>
#import "DataHub+WatchlistProviders.h"


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
    }
}

- (void)setupAppLifecycleObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppWillTerminate:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppDidResignActive:)
                                                 name:NSApplicationDidResignActiveNotification
                                               object:nil];
}

#pragma mark - Public Tracking Methods

- (void)trackSymbolInteraction:(NSString *)symbolName {
    [self trackSymbolInteraction:symbolName context:nil];
}

- (void)trackSymbolInteraction:(NSString *)symbolName context:(NSString *)context {
    if (!symbolName.length) return;
    
    NSString *normalizedSymbol = [symbolName uppercaseString];
    
    // If optimized tracking is not active, fall back to legacy method
    if (![self isOptimizedTrackingActive]) {
        [self legacyTrackSymbolInteraction:normalizedSymbol];
        return;
    }
    
    @synchronized(self.pendingInteractionCounts) {
        // Update interaction count
        NSNumber *currentCount = self.pendingInteractionCounts[normalizedSymbol];
        NSInteger count = currentCount ? [currentCount integerValue] + 1 : 1;
        self.pendingInteractionCounts[normalizedSymbol] = @(count);
        
        // Update last interaction time
        self.pendingLastInteractions[normalizedSymbol] = [NSDate date];
        
        // Track first interaction if needed
        if (!currentCount) {
            [self.pendingFirstInteractions addObject:normalizedSymbol];
        }
        
        NSLog(@"📊 Buffered interaction: %@ (count: %ld%@)",
              normalizedSymbol, (long)count,
              context ? [NSString stringWithFormat:@", context: %@", context] : @"");
    }
}

- (void)trackSymbolForArchive:(NSString *)symbolName {
    if (!symbolName.length) return;
    
    NSString *normalizedSymbol = [symbolName uppercaseString];
    
    // If optimized tracking is not active, fall back to legacy method
    if (![self isOptimizedTrackingActive]) {
        [self legacyAddSymbolToTodayArchive:normalizedSymbol];
        return;
    }
    
    @synchronized(self.pendingArchiveSymbols) {
        [self.pendingArchiveSymbols addObject:normalizedSymbol];
        NSLog(@"📁 Buffered for archive: %@", normalizedSymbol);
    }
}

#pragma mark - Scheduled Operations

- (void)performScheduledUserDefaultsBackup {
    NSLog(@"⏰ Scheduled UserDefaults backup starting...");
    [self performUserDefaultsBackupWithCompletion:^(BOOL success) {
        NSLog(@"⏰ Scheduled UserDefaults backup completed: %@", success ? @"SUCCESS" : @"FAILED");
    }];
}

- (void)performScheduledCoreDataFlush {
    NSLog(@"⏰ Scheduled Core Data flush starting...");
    [self performCoreDataFlushWithCompletion:^(BOOL success) {
        NSLog(@"⏰ Scheduled Core Data flush completed: %@", success ? @"SUCCESS" : @"FAILED");
    }];
}

#pragma mark - Manual Operations

- (void)performImmediateUserDefaultsBackup {
    NSLog(@"🔄 Manual UserDefaults backup requested");
    [self performUserDefaultsBackupWithCompletion:^(BOOL success) {
        NSLog(@"🔄 Manual UserDefaults backup completed: %@", success ? @"SUCCESS" : @"FAILED");
    }];
}

- (void)performImmediateCoreDataFlush:(void(^)(BOOL success))completion {
    NSLog(@"🔄 Manual Core Data flush requested");
    [self performCoreDataFlushWithCompletion:completion];
}

#pragma mark - Backup & Flush Implementation

- (void)performUserDefaultsBackupWithCompletion:(void(^)(BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(self.pendingInteractionCounts) {
            if (self.pendingInteractionCounts.count == 0 && self.pendingArchiveSymbols.count == 0) {
                NSLog(@"⏭️ Skipping UserDefaults backup - no pending data");
                if (completion) completion(YES);
                return;
            }
            
            NSDictionary *backup = [self createBackupData];
            
            // Save to UserDefaults
            [[NSUserDefaults standardUserDefaults] setObject:backup forKey:@"PendingSymbolUpdates"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            [self setLastUserDefaultsBackup:[NSDate date]];
            
            NSLog(@"💾 UserDefaults backup saved: %lu interactions, %lu archive symbols",
                  (unsigned long)self.pendingInteractionCounts.count,
                  (unsigned long)self.pendingArchiveSymbols.count);
            
            if (completion) completion(YES);
        }
    });
}

- (void)performCoreDataFlushWithCompletion:(void(^)(BOOL success))completion {
    __weak typeof(self) weakSelf = self;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSDictionary *interactionCounts;
        __block NSDictionary *lastInteractions;
        __block NSSet *firstInteractions;
        __block NSSet *archiveSymbols;

        @synchronized (weakSelf.pendingInteractionCounts) {
            if (weakSelf.pendingInteractionCounts.count == 0 && weakSelf.pendingArchiveSymbols.count == 0) {
                NSLog(@"⏭️ Skipping Core Data flush - no pending data");
                if (completion) completion(YES);
                return;
            }

            // Create snapshot of data to flush
            interactionCounts = [weakSelf.pendingInteractionCounts copy];
            lastInteractions = [weakSelf.pendingLastInteractions copy];
            firstInteractions = [weakSelf.pendingFirstInteractions copy];
            archiveSymbols = [weakSelf.pendingArchiveSymbols copy];

            // Clear buffers immediately to avoid duplicate processing
            [weakSelf.pendingInteractionCounts removeAllObjects];
            [weakSelf.pendingLastInteractions removeAllObjects];
            [weakSelf.pendingFirstInteractions removeAllObjects];
            [weakSelf.pendingArchiveSymbols removeAllObjects];

            // Clear UserDefaults backup
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PendingSymbolUpdates"];
            [[NSUserDefaults standardUserDefaults] synchronize];

            NSLog(@"🚀 Starting Core Data flush: %lu interactions, %lu archive symbols",
                  (unsigned long)interactionCounts.count,
                  (unsigned long)archiveSymbols.count);
        }

        // Process data in background context
        NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        backgroundContext.parentContext = weakSelf.mainContext;

        [backgroundContext performBlock:^{
            @try {
                // Process interactions in batches
                [weakSelf processInteractionCounts:interactionCounts
                                   lastInteractions:lastInteractions
                                  firstInteractions:firstInteractions
                                          inContext:backgroundContext];

                // Process archive symbols
                [weakSelf processArchiveSymbols:archiveSymbols inContext:backgroundContext];

                // Save background context
                NSError *error = nil;
                if ([backgroundContext save:&error]) {
                    // Save parent context on its own queue
                    [weakSelf.mainContext performBlock:^{
                        NSError *mainError = nil;
                        if ([weakSelf.mainContext save:&mainError]) {
                            [weakSelf setLastCoreDataFlush:[NSDate date]];
                            NSLog(@"✅ Core Data flush completed successfully");
                            if (completion) completion(YES);
                        } else {
                            NSLog(@"❌ Core Data main context save failed: %@", mainError.localizedDescription);
                            if (completion) completion(NO);
                        }
                    }];
                } else {
                    NSLog(@"❌ Core Data background context save failed: %@", error.localizedDescription);
                    if (completion) completion(NO);
                }
            }
            @catch (NSException *exception) {
                NSLog(@"❌ Core Data flush exception: %@", exception.reason);
                if (completion) completion(NO);
            }
        }];
    });
}

- (void)processInteractionCounts:(NSDictionary *)interactionCounts
                  lastInteractions:(NSDictionary *)lastInteractions
                 firstInteractions:(NSSet *)firstInteractions
                         inContext:(NSManagedObjectContext *)context {
    
    NSArray *symbolNames = [interactionCounts.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSInteger totalSymbols = symbolNames.count;
    NSInteger chunkSize = self.chunkSize;
    NSInteger processedCount = 0;
    
    for (NSInteger i = 0; i < totalSymbols; i += chunkSize) {
        NSRange range = NSMakeRange(i, MIN(chunkSize, totalSymbols - i));
        NSArray *chunk = [symbolNames subarrayWithRange:range];
        
        for (NSString *symbolName in chunk) {
            Symbol *symbol = [self getSymbolWithName:symbolName inContext:context];
            if (!symbol) {
                symbol = [self createSymbolWithName:symbolName inContext:context];
            }
            
            if (symbol) {
                // Update interaction count
                NSNumber *countIncrement = interactionCounts[symbolName];
                symbol.interactionCount += [countIncrement integerValue];
                
                // Update last interaction
                NSDate *lastInteraction = lastInteractions[symbolName];
                if (lastInteraction) {
                    symbol.lastInteraction = lastInteraction;
                }
                
                // Set first interaction if this is a new symbol
                if ([firstInteractions containsObject:symbolName] && !symbol.firstInteraction) {
                    symbol.firstInteraction = lastInteraction ?: [NSDate date];
                }
            }
        }
        
        processedCount += chunk.count;
        NSLog(@"📊 Processed %ld/%ld symbols (%.1f%%)",
              (long)processedCount, (long)totalSymbols,
              (processedCount * 100.0) / totalSymbols);
    }
}

- (void)processArchiveSymbols:(NSSet *)archiveSymbols inContext:(NSManagedObjectContext *)context {
    // Use existing archive logic but in background context
    for (NSString *symbolName in archiveSymbols) {
        // TODO: Implement background-safe archive logic
        // For now, defer to main thread for archive operations
        dispatch_async(dispatch_get_main_queue(), ^{
            [self legacyAddSymbolToTodayArchive:symbolName];
        });
    }
}

#pragma mark - App Lifecycle Handlers

- (void)handleAppWillTerminate:(NSNotification *)notification {
    NSLog(@"📱 App terminating - performing emergency flush");
    if ([self isOptimizedTrackingActive] && self.flushOnAppTerminate) {
        [self performEmergencyFlushSync];
    }
}

- (void)handleAppDidResignActive:(NSNotification *)notification {
    NSLog(@"📱 App backgrounded - performing background flush");
    if ([self isOptimizedTrackingActive] && self.flushOnAppBackground) {
        [self performImmediateCoreDataFlush:^(BOOL success) {
            NSLog(@"📱 Background flush completed: %@", success ? @"SUCCESS" : @"FAILED");
        }];
    }
}

- (void)performEmergencyFlushSync {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self performImmediateCoreDataFlush:^(BOOL success) {
        NSLog(@"🚨 Emergency flush completed: %@", success ? @"SUCCESS" : @"FAILED");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Wait max 5 seconds for flush to complete
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
}

#pragma mark - Data Management

- (NSDictionary *)createBackupData {
    return @{
        @"pendingInteractionCounts": [self.pendingInteractionCounts copy] ?: @{},
        @"pendingLastInteractions": [self.pendingLastInteractions copy] ?: @{},
        @"pendingFirstInteractions": [[self.pendingFirstInteractions allObjects] copy] ?: @[],
        @"pendingArchiveSymbols": [[self.pendingArchiveSymbols allObjects] copy] ?: @[],
        @"timestamp": [NSDate date]
    };
}

- (void)restorePendingDataFromUserDefaults {
    NSDictionary *backup = [[NSUserDefaults standardUserDefaults] objectForKey:@"PendingSymbolUpdates"];
    if (!backup) return;
    
    NSDate *backupTime = backup[@"timestamp"];
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:backupTime];
    
    // Don't restore very old backups (older than 24 hours)
    if (age > 86400) {
        NSLog(@"⚠️ Backup too old (%.1f hours) - discarding", age / 3600);
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PendingSymbolUpdates"];
        return;
    }
    
    @synchronized(self.pendingInteractionCounts) {
        // Restore interaction counts
        NSDictionary *counts = backup[@"pendingInteractionCounts"];
        if (counts) {
            [self.pendingInteractionCounts addEntriesFromDictionary:counts];
        }
        
        // Restore last interactions
        NSDictionary *lastInteractions = backup[@"pendingLastInteractions"];
        if (lastInteractions) {
            [self.pendingLastInteractions addEntriesFromDictionary:lastInteractions];
        }
        
        // Restore first interactions
        NSArray *firstInteractions = backup[@"pendingFirstInteractions"];
        if (firstInteractions) {
            [self.pendingFirstInteractions addObjectsFromArray:firstInteractions];
        }
        
        // Restore archive symbols
        NSArray *archiveSymbols = backup[@"pendingArchiveSymbols"];
        if (archiveSymbols) {
            [self.pendingArchiveSymbols addObjectsFromArray:archiveSymbols];
        }
        
        NSLog(@"🔄 Restored from backup: %lu interactions, %lu archive symbols (%.1f minutes old)",
              (unsigned long)self.pendingInteractionCounts.count,
              (unsigned long)self.pendingArchiveSymbols.count,
              age / 60);
    }
}

#pragma mark - Legacy Fallback Methods

- (void)legacyTrackSymbolInteraction:(NSString *)normalizedSymbol {
    Symbol *symbol = [self getSymbolWithName:normalizedSymbol];
    if (!symbol) {
        symbol = [self createSymbolWithName:normalizedSymbol];
    }
    
    if (symbol) {
        symbol.interactionCount++;
        symbol.lastInteraction = [NSDate date];
        if (!symbol.firstInteraction) {
            symbol.firstInteraction = [NSDate date];
        }
        [self saveContext];
        
        NSLog(@"🐌 Legacy tracking: %@ (interaction: %d)", normalizedSymbol, symbol.interactionCount);
    }
}

- (void)legacyAddSymbolToTodayArchive:(NSString *)normalizedSymbol {
    // Call existing addSymbolToTodayArchive method
    [self addSymbolToTodayArchive:normalizedSymbol];
}

#pragma mark - Helper Methods for Core Data

- (Symbol *)getSymbolWithName:(NSString *)symbolName inContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [Symbol fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@", symbolName];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ Error fetching symbol %@: %@", symbolName, error.localizedDescription);
        return nil;
    }
    
    return results.firstObject;
}

- (Symbol *)createSymbolWithName:(NSString *)symbolName inContext:(NSManagedObjectContext *)context {
    Symbol *symbol = [NSEntityDescription insertNewObjectForEntityForName:@"Symbol" inManagedObjectContext:context];
    symbol.symbol = symbolName;
    symbol.interactionCount = 0;
    return symbol;
}

#pragma mark - Statistics and Monitoring

- (NSDictionary *)getBufferStatistics {
    @synchronized(self.pendingInteractionCounts) {
        NSInteger totalInteractions = 0;
        for (NSNumber *count in self.pendingInteractionCounts.allValues) {
            totalInteractions += [count integerValue];
        }
        
        return @{
            @"uniqueSymbols": @(self.pendingInteractionCounts.count),
            @"totalInteractions": @(totalInteractions),
            @"firstTimeSymbols": @(self.pendingFirstInteractions.count),
            @"archiveSymbols": @(self.pendingArchiveSymbols.count),
            @"memoryUsageEstimate": @((self.pendingInteractionCounts.count + self.pendingLastInteractions.count + self.pendingFirstInteractions.count + self.pendingArchiveSymbols.count) * 64) // Rough estimate in bytes
        };
    }
}

- (NSDictionary *)getLastOperationTimestamps {
    return @{
        @"lastUserDefaultsBackup": self.lastUserDefaultsBackup ?: [NSNull null],
        @"lastCoreDataFlush": self.lastCoreDataFlush ?: [NSNull null],
        @"nextUserDefaultsBackup": self.lastUserDefaultsBackup ? [self.lastUserDefaultsBackup dateByAddingTimeInterval:self.userDefaultsBackupInterval] : [NSNull null],
        @"nextCoreDataFlush": (self.lastCoreDataFlush && self.coreDataFlushInterval > 0) ? [self.lastCoreDataFlush dateByAddingTimeInterval:self.coreDataFlushInterval] : [NSNull null]
    };
}

- (void)clearAllPendingBuffers {
    @synchronized(self.pendingInteractionCounts) {
        [self.pendingInteractionCounts removeAllObjects];
        [self.pendingLastInteractions removeAllObjects];
        [self.pendingFirstInteractions removeAllObjects];
        [self.pendingArchiveSymbols removeAllObjects];
        
        NSLog(@"🧹 Cleared all pending buffers");
    };
}

#pragma mark - Configuration Management

- (void)restartOptimizedTrackingWithNewConfiguration {
    if ([self isOptimizedTrackingActive]) {
        NSLog(@"🔄 Restarting optimized tracking with new configuration...");
        
        // Flush any pending data before restart
        [self performImmediateCoreDataFlush:^(BOOL success) {
            NSLog(@"🔄 Pre-restart flush completed: %@", success ? @"SUCCESS" : @"FAILED");
            
            // Restart the system
            [self shutdownOptimizedTracking];
            [self initializeOptimizedTracking];
        }];
    } else {
        // Just initialize if not active
        [self initializeOptimizedTracking];
    }
}

@end
