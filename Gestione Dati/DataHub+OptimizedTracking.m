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


#pragma mark - Testing and Debug

- (void)simulateHighTrackingLoad {
    NSLog(@"🧪 Simulating high tracking load...");
    
    NSArray *testSymbols = @[@"AAPL", @"GOOGL", @"MSFT", @"TSLA", @"AMZN", @"META", @"NVDA", @"NFLX", @"CRM", @"ORCL"];
    
    // Simulate 100 interactions
    for (int i = 0; i < 100; i++) {
        NSString *symbol = testSymbols[i % testSymbols.count];
        [self trackSymbolInteraction:symbol context:@"test"];
        [self trackSymbolForArchive:symbol];
    }
    
    NSLog(@"🧪 Simulated 100 interactions across %lu symbols", (unsigned long)testSymbols.count);
    
    // Print buffer stats
    NSDictionary *stats = [self getBufferStatistics];
    NSLog(@"🧪 Buffer stats: %@", stats);
}

- (void)debugTrackingSystemStatus {
    NSLog(@"\n🔍 TRACKING SYSTEM DEBUG STATUS:");
    NSLog(@"================================");
    NSLog(@"Optimized tracking enabled: %@", self.optimizedTrackingEnabled ? @"YES" : @"NO");
    NSLog(@"Optimized tracking active: %@", [self isOptimizedTrackingActive] ? @"YES" : @"NO");
    NSLog(@"UserDefaults interval: %.0f seconds", self.userDefaultsBackupInterval);
    NSLog(@"Core Data interval: %.0f seconds", self.coreDataFlushInterval);
    NSLog(@"Max batch size: %ld", (long)self.maxBatchSize);
    NSLog(@"Chunk size: %ld", (long)self.chunkSize);
    
    if ([self isOptimizedTrackingActive]) {
        NSDictionary *bufferStats = [self getBufferStatistics];
        NSLog(@"Buffer statistics: %@", bufferStats);
        
        NSDictionary *timestamps = [self getLastOperationTimestamps];
        NSLog(@"Last operations: %@", timestamps);
    }
    
    NSLog(@"================================\n");
}

@end

- (void)setupAppLifecycleObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // App termination - immediate flush
    [nc addObserver:self
           selector:@selector(handleAppWillTerminate:)
               name:NSApplicationWillTerminateNotification
             object:nil];
    
    // App background - conditional flush
    if (self.flushOnAppBackground) {
        [nc addObserver:self
               selector:@selector(handleAppDidResignActive:)
                   name:NSApplicationDidResignActiveNotification
                 object:nil];
    }
    
    NSLog(@"📱 App lifecycle observers setup");
}

#pragma mark - Core Tracking Methods

- (void)trackSymbolInteraction:(NSString *)symbolName {
    [self trackSymbolInteraction:symbolName context:@"general"];
}

- (void)trackSymbolInteraction:(NSString *)symbolName context:(NSString *)context {
    if (!symbolName || symbolName.length == 0) return;
    
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // If optimized tracking disabled, use legacy method
    if (!self.optimizedTrackingEnabled || ![self isOptimizedTrackingActive]) {
        [self legacyTrackSymbolInteraction:normalizedSymbol];
        return;
    }
    
    @synchronized(self.pendingInteractionCounts) {
        // Update interaction count
        NSNumber *currentCount = self.pendingInteractionCounts[normalizedSymbol] ?: @0;
        self.pendingInteractionCounts[normalizedSymbol] = @([currentCount intValue] + 1);
        
        // Update last interaction time
        self.pendingLastInteractions[normalizedSymbol] = [NSDate date];
        
        // Check if this is first interaction ever for this symbol
        Symbol *existingSymbol = [self getSymbolWithName:normalizedSymbol];
        if (!existingSymbol || !existingSymbol.firstInteraction) {
            [self.pendingFirstInteractions addObject:normalizedSymbol];
        }
        
        NSLog(@"📊 Tracked interaction: %@ (context: %@, pending: %@)",
              normalizedSymbol, context, self.pendingInteractionCounts[normalizedSymbol]);
        
        // Check if buffer is getting too large
        [self checkBufferSizeAndFlushIfNeeded];
    }
}

- (void)trackSymbolForArchive:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) return;
    
    NSString *normalizedSymbol = symbolName.uppercaseString;
    
    // If optimized tracking disabled, use legacy method
    if (!self.optimizedTrackingEnabled || ![self isOptimizedTrackingActive]) {
        [self legacyAddSymbolToTodayArchive:normalizedSymbol];
        return;
    }
    
    @synchronized(self.pendingArchiveSymbols) {
        [self.pendingArchiveSymbols addObject:normalizedSymbol];
        
        NSLog(@"📅 Queued for archive: %@ (total pending: %lu)",
              normalizedSymbol, (unsigned long)self.pendingArchiveSymbols.count);
        
        // Check if buffer is getting too large
        [self checkBufferSizeAndFlushIfNeeded];
    }
}

- (void)checkBufferSizeAndFlushIfNeeded {
    NSUInteger totalPendingItems = self.pendingInteractionCounts.count + self.pendingArchiveSymbols.count;
    
    if (totalPendingItems >= self.maxBatchSize) {
        NSLog(@"⚠️ Buffer size limit reached (%lu >= %ld) - forcing flush",
              (unsigned long)totalPendingItems, (long)self.maxBatchSize);
        [self performImmediateCoreDataFlush:^(BOOL success) {
            NSLog(@"🔄 Emergency flush completed: %@", success ? @"SUCCESS" : @"FAILED");
        }];
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(self.pendingInteractionCounts) {
            if (self.pendingInteractionCounts.count == 0 && self.pendingArchiveSymbols.count == 0) {
                NSLog(@"⏭️ Skipping Core Data flush - no pending data");
                if (completion) completion(YES);
                return;
            }
            
            // Create snapshots and clear buffers immediately
            NSDictionary *interactionCounts = [self.pendingInteractionCounts copy];
            NSDictionary *lastInteractions = [self.pendingLastInteractions copy];
            NSSet *firstInteractions = [self.pendingFirstInteractions copy];
            NSSet *archiveSymbols = [self.pendingArchiveSymbols copy];
            
            // Clear buffers so new interactions can accumulate
            [self.pendingInteractionCounts removeAllObjects];
            [self.pendingLastInteractions removeAllObjects];
            [self.pendingFirstInteractions removeAllObjects];
            [self.pendingArchiveSymbols removeAllObjects];
            
            NSLog(@"📦 Processing batch: %lu interactions, %lu archive symbols",
                  (unsigned long)interactionCounts.count, (unsigned long)archiveSymbols.count);
            
            // Process in background
            [self processBatchInBackground:interactionCounts
                          lastInteractions:lastInteractions
                         firstInteractions:firstInteractions
                            archiveSymbols:archiveSymbols
                                completion:completion];
        }
    });
}

- (void)processBatchInBackground:(NSDictionary *)interactionCounts
                lastInteractions:(NSDictionary *)lastInteractions
               firstInteractions:(NSSet *)firstInteractions
                  archiveSymbols:(NSSet *)archiveSymbols
                      completion:(void(^)(BOOL success))completion {
    
    NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    backgroundContext.parentContext = self.mainContext;
    
    [backgroundContext performBlock:^{
        BOOL success = YES;
        
        @try {
            // Process interaction updates in chunks
            NSArray *symbols = [interactionCounts allKeys];
            NSUInteger totalSymbols = symbols.count;
            NSUInteger processedSymbols = 0;
            
            while (processedSymbols < totalSymbols) {
                NSUInteger remainingSymbols = totalSymbols - processedSymbols;
                NSUInteger currentChunkSize = MIN(self.chunkSize, remainingSymbols);
                
                NSRange chunkRange = NSMakeRange(processedSymbols, currentChunkSize);
                NSArray *chunk = [symbols subarrayWithRange:chunkRange];
                
                [self processInteractionChunk:chunk
                             interactionCounts:interactionCounts
                              lastInteractions:lastInteractions
                             firstInteractions:firstInteractions
                                     inContext:backgroundContext];
                
                processedSymbols += currentChunkSize;
                
                NSLog(@"📦 Processed chunk %lu/%lu (%lu symbols)",
                      (unsigned long)(processedSymbols / self.chunkSize),
                      (unsigned long)((totalSymbols + self.chunkSize - 1) / self.chunkSize),
                      (unsigned long)currentChunkSize);
            }
            
            // Process archive symbols
            [self processArchiveSymbols:archiveSymbols inContext:backgroundContext];
            
            // Save background context
            NSError *error = nil;
            if (![backgroundContext save:&error]) {
                NSLog(@"❌ Error saving background context: %@", error);
                success = NO;
            }
            
        } @catch (NSException *exception) {
            NSLog(@"❌ Exception during batch processing: %@", exception);
            success = NO;
        }
        
        // Save parent context on main thread
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = nil;
                if ([self.mainContext save:&error]) {
                    [self setLastCoreDataFlush:[NSDate date]];
                    
                    // Clear UserDefaults backup after successful flush
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PendingSymbolUpdates"];
                    
                    NSLog(@"✅ Core Data flush completed successfully");
                    if (completion) completion(YES);
                } else {
                    NSLog(@"❌ Error saving main context: %@", error);
                    if (completion) completion(NO);
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO);
            });
        }
    }];
}

- (void)processInteractionChunk:(NSArray *)symbols
               interactionCounts:(NSDictionary *)interactionCounts
                lastInteractions:(NSDictionary *)lastInteractions
               firstInteractions:(NSSet *)firstInteractions
                       inContext:(NSManagedObjectContext *)context {
    
    for (NSString *symbolName in symbols) {
        Symbol *symbol = [self findOrCreateSymbolWithName:symbolName inContext:context];
        if (!symbol) continue;
        
        // Update interaction count
        NSNumber *pendingCount = interactionCounts[symbolName];
        if (pendingCount) {
            symbol.interactionCount += [pendingCount intValue];
        }
        
        // Update last interaction
        NSDate *lastInteraction = lastInteractions[symbolName];
        if (lastInteraction) {
            symbol.lastInteraction = lastInteraction;
        }
        
        // Set first interaction if needed
        if ([firstInteractions containsObject:symbolName] && !symbol.firstInteraction) {
            symbol.firstInteraction = lastInteraction ?: [NSDate date];
        }
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
        @"backupTimestamp": [NSDate date],
        @"version": @"1.0"
    };
}

- (void)restorePendingDataFromUserDefaults {
    NSDictionary *backup = [[NSUserDefaults standardUserDefaults] objectForKey:@"PendingSymbolUpdates"];
    if (!backup) return;
    
    NSLog(@"🔄 Restoring pending data from crash backup...");
    
    // Restore interaction counts
    NSDictionary *counts = backup[@"pendingInteractionCounts"];
    if (counts) {
        [self.pendingInteractionCounts addEntriesFromDictionary:counts];
    }
    
    // Restore last interactions
    NSDictionary *interactions = backup[@"pendingLastInteractions"];
    if (interactions) {
        [self.pendingLastInteractions addEntriesFromDictionary:interactions];
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
    
    NSDate *backupTime = backup[@"backupTimestamp"];
    NSLog(@"✅ Restored pending data from %@: %lu interactions, %lu archive symbols",
          backupTime, (unsigned long)self.pendingInteractionCounts.count, (unsigned long)self.pendingArchiveSymbols.count);
    
    // Process restored data immediately
    [self performImmediateCoreDataFlush:^(BOOL success) {
        NSLog(@"🔄 Crash recovery flush completed: %@", success ? @"SUCCESS" : @"FAILED");
    }];
}

#pragma mark - Statistics and Monitoring

- (NSDictionary *)getBufferStatistics {
    @synchronized(self.pendingInteractionCounts) {
        return @{
            @"pendingInteractionCount": @(self.pendingInteractionCounts.count),
            @"pendingArchiveCount": @(self.pendingArchiveSymbols.count),
            @"totalPendingItems": @(self.pendingInteractionCounts.count + self.pendingArchiveSymbols.count),
            @"maxBatchSize": @(self.maxBatchSize),
            @"bufferUtilization": @((double)(self.pendingInteractionCounts.count + self.pendingArchiveSymbols.count) / self.maxBatchSize),
            @"isOptimizedTrackingActive": @([self isOptimizedTrackingActive])
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
@end
