//
//  StorageManager.m
//  TradingApp
//
//  Implementazione del sistema di storage automatico per continuous storage
//

#import "StorageManager.h"
#import "DataHub.h"
#import "ChartWidget+SaveData.h"
#import <Cocoa/Cocoa.h>
#import "datahub+marketdata.h"
#import "SavedChartData+FilenameParsing.h"
#import "SavedChartData+FilenameUpdate.h"


#pragma mark - ActiveStorageItem Implementation

@implementation ActiveStorageItem
@end

#pragma mark - UnifiedStorageItem Implementation

@implementation UnifiedStorageItem

- (BOOL)isContinuous {
    return self.dataType == SavedChartDataTypeContinuous;
}

- (BOOL)isSnapshot {
    return self.dataType == SavedChartDataTypeSnapshot;
}

@end

#pragma mark - StorageManager Implementation

@interface StorageManager ()
@property (nonatomic, strong) NSMutableArray<ActiveStorageItem *> *mutableActiveStorages;
@property (nonatomic, strong) NSTimer *masterCheckTimer;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, strong) NSArray<UnifiedStorageItem *> *cachedAllStorageItems;
@property (nonatomic, strong) NSDate *lastFileSystemScan;
@end

@implementation StorageManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static StorageManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableActiveStorages = [NSMutableArray array];
        _maxRetryCount = 10;
        _gapToleranceDays = 15;
        _automaticUpdatesEnabled = YES;
        _isInitialized = NO;
        
        [self initializeStorageManager];
    }
    return self;
}



- (void)initializeStorageManager {
    if (_isInitialized) return;
    
    NSLog(@"🚀 StorageManager initializing automatic storage system...");
    
    // Setup notification observers
    [self setupNotificationObservers];
    
    // Auto-register existing continuous storage files
    [self autoDiscoverContinuousStorages];
    
    // Start master timer for health checks
    [self startMasterTimer];
    
    _isInitialized = YES;
    NSLog(@"✅ StorageManager initialized with %ld active storages", (long)self.totalActiveStorages);
}

- (void)setupNotificationObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Listen for new continuous storage creation
    [nc addObserver:self
           selector:@selector(handleNewContinuousStorageCreated:)
               name:@"NewContinuousStorageCreated"
             object:nil];
    
    // Listen for DataHub downloads (opportunistic updates)
    [nc addObserver:self
           selector:@selector(handleDataHubDownload:)
               name:@"DataHubHistoricalDataDownloaded"
             object:nil];
    
    // App lifecycle events
    [nc addObserver:self
           selector:@selector(handleAppWillTerminate:)
               name:NSApplicationWillTerminateNotification
             object:nil];
}

- (void)autoDiscoverContinuousStorages {
    NSString *savedDataDir = [ChartWidget savedChartDataDirectory];
    NSArray<NSString *> *continuousFiles = [ChartWidget availableSavedChartDataFilesOfType:SavedChartDataTypeContinuous];
    
    NSLog(@"🔍 Auto-discovering continuous storage files in: %@", savedDataDir);
    
    for (NSString *filePath in continuousFiles) {
        [self registerContinuousStorage:filePath];
    }
    
    NSLog(@"📋 Auto-discovered %ld continuous storage files", (long)continuousFiles.count);
}

#pragma mark - Registry Management

- (BOOL)registerContinuousStorage:(NSString *)filePath {
    if (!filePath || ![filePath containsString:@"continuous"]) {
        NSLog(@"⚠️ Invalid file path for continuous storage: %@", filePath);
        return NO;
    }
    
    // Check if already registered
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if ([item.filePath isEqualToString:filePath]) {
            NSLog(@"ℹ️ Storage already registered: %@", filePath);
            return YES;
        }
    }
    
    // Load saved data
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    if (!savedData || savedData.dataType != SavedChartDataTypeContinuous) {
        NSLog(@"❌ Failed to load continuous storage from: %@", filePath);
        return NO;
    }
    
    // Create active storage item
    ActiveStorageItem *item = [[ActiveStorageItem alloc] init];
    item.filePath = filePath;
    item.savedData = savedData;
    item.failureCount = 0;
    item.isPaused = NO;
    
    // Calculate and schedule next update
    [self scheduleUpdateForStorageItem:item];
    
    // Add to registry
    [self.mutableActiveStorages addObject:item];
    
    NSLog(@"✅ Registered continuous storage: %@ [%@] - Next update: %@",
          savedData.symbol, [savedData timeframeDescription], savedData.nextScheduledUpdate);
    
    return YES;
}

- (void)unregisterContinuousStorage:(NSString *)filePath {
    for (NSInteger i = self.mutableActiveStorages.count - 1; i >= 0; i--) {
        ActiveStorageItem *item = self.mutableActiveStorages[i];
        if ([item.filePath isEqualToString:filePath]) {
            [item.updateTimer invalidate];
            [self.mutableActiveStorages removeObjectAtIndex:i];
            NSLog(@"🗑️ Unregistered continuous storage: %@", filePath);
            break;
        }
    }
}

- (NSArray<ActiveStorageItem *> *)activeStorages {
    return [self.mutableActiveStorages copy];
}

#pragma mark - Timer System

- (void)scheduleUpdateForStorageItem:(ActiveStorageItem *)item {
    // Invalidate existing timer
    [item.updateTimer invalidate];
    
    if (!self.automaticUpdatesEnabled || item.isPaused) {
        item.updateTimer = nil;
        return;
    }
    
    // Calculate next update date based on timeframe
    NSDate *nextUpdate = [self calculateNextUpdateDateForStorage:item.savedData];
    item.savedData.nextScheduledUpdate = nextUpdate;
    
    // Calculate time interval until next update
    NSTimeInterval timeUntilUpdate = [nextUpdate timeIntervalSinceNow];
    
    if (timeUntilUpdate <= 0) {
        // Update is overdue - schedule immediately
        timeUntilUpdate = 5.0; // 5 seconds delay
    }
    
    // Create timer
    item.updateTimer = [NSTimer scheduledTimerWithTimeInterval:timeUntilUpdate
                                                        target:self
                                                      selector:@selector(timerTriggeredUpdate:)
                                                      userInfo:@{@"storageItem": item}
                                                       repeats:NO];
    
    NSLog(@"⏰ Scheduled update for %@ [%@] in %.0f hours",
          item.savedData.symbol, [item.savedData timeframeDescription], timeUntilUpdate / 3600.0);
}

- (NSDate *)calculateNextUpdateDateForStorage:(SavedChartData *)savedData {
    NSDate *baseDate = savedData.lastSuccessfulUpdate ?: savedData.endDate;
    NSTimeInterval updateInterval;
    
    // Update intervals based on timeframe
    switch (savedData.timeframe) {
        case ChartTimeframe1Min:
            updateInterval = 30 * 24 * 60 * 60; // 30 days for 1min
            break;
        case ChartTimeframe5Min:
        case ChartTimeframe15Min:
        case ChartTimeframe30Min:
        case ChartTimeframe1Hour:
        case ChartTimeframe4Hour:
            updateInterval = 241 * 24 * 60 * 60; // 241 days (8 months) for 5min+
            break;
        case ChartTimeframeDaily:
        case ChartTimeframeWeekly:
        case ChartTimeframeMonthly:
            updateInterval = 365 * 24 * 60 * 60; // 1 year for daily+
            break;
        default:
            updateInterval = 241 * 24 * 60 * 60; // Default to 8 months
            break;
    }
    
    return [baseDate dateByAddingTimeInterval:updateInterval];
}

- (void)timerTriggeredUpdate:(NSTimer *)timer {
    ActiveStorageItem *item = timer.userInfo[@"storageItem"];
    if (!item) return;
    
    NSLog(@"⏰ Timer triggered update for: %@ [%@]",
          item.savedData.symbol, [item.savedData timeframeDescription]);
    
    [self performUpdateForStorageItem:item completion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"✅ Automatic update successful for %@", item.savedData.symbol);
            item.failureCount = 0;
            item.lastFailureDate = nil;
        } else {
            NSLog(@"❌ Automatic update failed for %@: %@", item.savedData.symbol, error.localizedDescription);
            [self handleUpdateFailureForItem:item error:error];
        }
        
        // Schedule next update
        [self scheduleUpdateForStorageItem:item];
    }];
}

- (void)startAllTimers {
    if (!self.automaticUpdatesEnabled) return;
    
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        [self scheduleUpdateForStorageItem:item];
    }
    
    NSLog(@"▶️ Started all automatic update timers (%ld active)", (long)self.mutableActiveStorages.count);
}

- (void)stopAllTimers {
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        [item.updateTimer invalidate];
        item.updateTimer = nil;
    }
    
    NSLog(@"⏸️ Stopped all automatic update timers");
}

- (void)startMasterTimer {
    // Master timer for health checks every hour
    self.masterCheckTimer = [NSTimer scheduledTimerWithTimeInterval:(60 * 60) // 1 hour
                                                             target:self
                                                           selector:@selector(performMasterHealthCheck:)
                                                           userInfo:nil
                                                            repeats:YES];
}

- (void)performMasterHealthCheck:(NSTimer *)timer {
    NSLog(@"🔍 StorageManager master health check - %ld active storages", (long)self.totalActiveStorages);
    
    // Check for overdue updates
    NSDate *now = [NSDate date];
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if (!item.isPaused && item.savedData.nextScheduledUpdate &&
            [item.savedData.nextScheduledUpdate compare:now] == NSOrderedAscending) {
            
            NSLog(@"⚠️ Found overdue storage: %@ (due: %@)",
                  item.savedData.symbol, item.savedData.nextScheduledUpdate);
            
            // Reschedule immediate update
            [self scheduleUpdateForStorageItem:item];
        }
    }
}

- (void)setPaused:(BOOL)paused forStorage:(NSString *)filePath {
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if ([item.filePath isEqualToString:filePath]) {
            item.isPaused = paused;
            
            if (paused) {
                [item.updateTimer invalidate];
                item.updateTimer = nil;
                NSLog(@"⏸️ Paused automatic updates for: %@", item.savedData.symbol);
            } else {
                [self scheduleUpdateForStorageItem:item];
                NSLog(@"▶️ Resumed automatic updates for: %@", item.savedData.symbol);
            }
            break;
        }
    }
}

#pragma mark - Update Operations

- (void)performUpdateForStorageItem:(ActiveStorageItem *)item
                         completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    SavedChartData *storage = item.savedData;
    
    NSLog(@"📥 Performing automatic update for %@ [%@] from %@",
          storage.symbol, [storage timeframeDescription], storage.endDate);
    
    // Calculate date range for API request (with 3-bar overlap for safety)
    NSDate *fromDate = [storage.endDate dateByAddingTimeInterval:-(3 * [self timeframeToSeconds:storage.timeframe])];
    NSDate *toDate = [NSDate date];
    
    NSLog(@"📅 Requesting data from %@ to %@ (3-bar overlap for merge)", fromDate, toDate);
    
    // Request new data via DataHub using the correct date range method
    [[DataHub shared] getHistoricalBarsForSymbol:storage.symbol
                                       timeframe:storage.timeframe
                                       startDate:fromDate
                                         endDate:toDate
                               needExtendedHours:storage.includesExtendedHours
                                      completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
        
        if (!bars || bars.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = [NSError errorWithDomain:@"StorageManager"
                                                     code:1001
                                                 userInfo:@{NSLocalizedDescriptionKey: @"No new data received from API"}];
                if (completion) completion(NO, error);
            });
            return;
        }
        
        NSLog(@"📊 Received %ld bars for merge attempt", (long)bars.count);
        
        // Perform merge operation (we expect some overlap)
        BOOL mergeSuccess = [storage mergeWithNewBars:bars overlapBarCount:3];
        
        if (mergeSuccess) {
               // OLD: [storage saveToFile:item.filePath error:&saveError];
               // NEW: Save with automatic filename update
               NSString *updatedFilePath = [storage saveToFileWithFilenameUpdate:item.filePath error:&saveError];
               
               if (updatedFilePath) {
                   // Update registry if file path changed
                   if (![updatedFilePath isEqualToString:item.filePath]) {
                       NSLog(@"📝 Registry: Updated file path for %@", storage.symbol);
                       item.filePath = updatedFilePath;
                   }
                   completion(YES, nil);
               } else {
                   completion(NO, saveError);
               }
           }
    }];
}

- (NSTimeInterval)timeframeToSeconds:(BarTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min: return 60;
        case ChartTimeframe5Min: return 300;
        case ChartTimeframe15Min: return 900;
        case ChartTimeframe30Min: return 1800;
        case ChartTimeframe1Hour: return 3600;
        case ChartTimeframe4Hour: return 14400;
        case ChartTimeframeDaily: return 86400;
        case ChartTimeframeWeekly: return 604800;
        case ChartTimeframeMonthly: return 2592000;
        default: return 300; // Default to 5 minutes
    }
}

- (void)handleUpdateFailureForItem:(ActiveStorageItem *)item error:(NSError *)error {
    item.failureCount++;
    item.lastFailureDate = [NSDate date];
    
    NSLog(@"❌ Update failure #%ld for %@: %@", (long)item.failureCount, item.savedData.symbol, error.localizedDescription);
    
    if (item.failureCount >= self.maxRetryCount) {
        NSLog(@"🚨 Storage %@ reached maximum retry count (%ld) - checking for irreversible gap",
              item.savedData.symbol, (long)self.maxRetryCount);
        
        // Check if gap is beyond API limits
        NSTimeInterval daysSinceLastData = [[NSDate date] timeIntervalSinceDate:item.savedData.endDate] / (24 * 60 * 60);
        
        if (daysSinceLastData > self.gapToleranceDays) {
            // Gap is irreversible - show conversion dialog
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showGapRecoveryDialogForStorage:item];
            });
        } else {
            // Reset failure count and try again later
            item.failureCount = 0;
            NSLog(@"🔄 Gap still within tolerance (%.0f days) - will retry later", daysSinceLastData);
        }
    }
}

#pragma mark - Manual Updates

- (void)forceUpdateForStorage:(NSString *)filePath
                   completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if ([item.filePath isEqualToString:filePath]) {
            NSLog(@"🔧 Force updating storage: %@", item.savedData.symbol);
            
            [self performUpdateForStorageItem:item completion:^(BOOL success, NSError *error) {
                if (success) {
                    // Reset failure count and reschedule
                    item.failureCount = 0;
                    item.lastFailureDate = nil;
                    [self scheduleUpdateForStorageItem:item];
                }
                
                if (completion) completion(success, error);
            }];
            return;
        }
    }
    
    // Storage not found
    if (completion) {
        NSError *error = [NSError errorWithDomain:@"StorageManager"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Storage not found in registry"}];
        completion(NO, error);
    }
}

- (void)forceUpdateAllStorages {
    NSLog(@"🔧 Force updating all %ld active storages", (long)self.mutableActiveStorages.count);
    
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if (!item.isPaused) {
            [self performUpdateForStorageItem:item completion:^(BOOL success, NSError *error) {
                if (success) {
                    item.failureCount = 0;
                    item.lastFailureDate = nil;
                    [self scheduleUpdateForStorageItem:item];
                }
            }];
        }
    }
}

#pragma mark - Opportunistic Updates

- (void)handleOpportunisticUpdate:(NSString *)symbol
                        timeframe:(BarTimeframe)timeframe
                             bars:(NSArray<HistoricalBarModel *> *)bars {
    
    if (!bars || bars.count == 0) return;
    
    NSLog(@"🎯 Checking opportunistic update for %@ [%@] with %ld bars",
          symbol, [self timeframeToString:timeframe], (long)bars.count);
    
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        SavedChartData *storage = item.savedData;
        
        // Check compatibility
        if ([storage.symbol isEqualToString:symbol] &&
            storage.timeframe == timeframe &&
            [storage isCompatibleWithBars:bars]) {
            
            NSLog(@"🎯 Found compatible storage for opportunistic update: %@", storage.symbol);
            
            // Attempt merge
            BOOL mergeSuccess = [storage mergeWithNewBars:bars overlapBarCount:3];
            
            if (mergeSuccess) {
                // Save updated storage
                NSError *saveError;
                BOOL saveSuccess = [storage saveToFile:item.filePath error:&saveError];
                
                if (saveSuccess) {
                    NSLog(@"✅ Opportunistic update successful for %@", storage.symbol);
                    
                    // Reset timer (postpone next scheduled update)
                    item.failureCount = 0;
                    item.lastFailureDate = nil;
                    [self scheduleUpdateForStorageItem:item];
                } else {
                    NSLog(@"❌ Failed to save opportunistic update for %@: %@",
                          storage.symbol, saveError.localizedDescription);
                }
            }
        }
    }
}

- (NSString *)timeframeToString:(BarTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min: return @"1min";
        case ChartTimeframe5Min: return @"5min";
        case ChartTimeframe15Min: return @"15min";
        case ChartTimeframe30Min: return @"30min";
        case ChartTimeframe1Hour: return @"1hour";
        case ChartTimeframe4Hour: return @"4hour";
        case ChartTimeframeDaily: return @"daily";
        case ChartTimeframeWeekly: return @"weekly";
        case ChartTimeframeMonthly: return @"monthly";
        default: return @"unknown";
    }
}

#pragma mark - Gap Recovery

- (void)showGapRecoveryDialogForStorage:(ActiveStorageItem *)storageItem {
    SavedChartData *storage = storageItem.savedData;
    NSTimeInterval daysSinceLastData = [[NSDate date] timeIntervalSinceDate:storage.endDate] / (24 * 60 * 60);
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"🚨 Irreversible Data Gap Detected";
    alert.informativeText = [NSString stringWithFormat:
                             @"Continuous storage for %@ [%@] has a gap of %.0f days, which exceeds the API limit.\n\n"
                             @"Options:\n"
                             @"• Convert to Snapshot: Preserve existing data but stop automatic updates\n"
                             @"• Keep Trying: Continue attempting updates (may keep failing)\n"
                             @"• Delete: Remove this storage entirely",
                             storage.symbol, [storage timeframeDescription], daysSinceLastData];
    
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Convert to Snapshot"];
    [alert addButtonWithTitle:@"Keep Trying"];
    [alert addButtonWithTitle:@"Delete Storage"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    switch (response) {
        case NSAlertFirstButtonReturn: // Convert to Snapshot
            [self convertStorageToSnapshot:storageItem.filePath userConfirmed:YES];
            break;
            
        case NSAlertSecondButtonReturn: // Keep Trying
            storageItem.failureCount = 0; // Reset and continue
            [self scheduleUpdateForStorageItem:storageItem];
            NSLog(@"🔄 User chose to keep trying for %@", storage.symbol);
            break;
            
        case NSAlertThirdButtonReturn: // Delete
            [self deleteStorageWithConfirmation:storageItem];
            break;
            
        default: // Cancel
            NSLog(@"⏸️ User cancelled gap recovery for %@", storage.symbol);
            break;
    }
}

- (void)convertStorageToSnapshot:(NSString *)filePath userConfirmed:(BOOL)userConfirmed {
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if ([item.filePath isEqualToString:filePath]) {
            // Convert the SavedChartData to snapshot
            [item.savedData convertToSnapshot];
            
            // Save updated file
            NSError *error;
            BOOL success = [item.savedData saveToFile:filePath error:&error];
            
            if (success) {
                // Stop automatic updates for this storage
                [item.updateTimer invalidate];
                item.updateTimer = nil;
                
                // Remove from active registry
                [self.mutableActiveStorages removeObject:item];
                
                NSLog(@"📸 Successfully converted %@ to snapshot", item.savedData.symbol);
                
                // Show success notification
                if (userConfirmed) {
                    [self showNotification:@"Storage Converted"
                                   message:[NSString stringWithFormat:@"%@ converted to snapshot and preserved", item.savedData.symbol]];
                }
            } else {
                NSLog(@"❌ Failed to save converted snapshot for %@: %@", item.savedData.symbol, error.localizedDescription);
            }
            break;
        }
    }
}

- (void)deleteStorageWithConfirmation:(ActiveStorageItem *)storageItem {
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"⚠️ Confirm Storage Deletion";
    confirmAlert.informativeText = [NSString stringWithFormat:@"Are you sure you want to permanently delete the continuous storage for %@ [%@]?\n\nThis action cannot be undone.",
                                    storageItem.savedData.symbol, [storageItem.savedData timeframeDescription]];
    confirmAlert.alertStyle = NSAlertStyleCritical;
    [confirmAlert addButtonWithTitle:@"Delete"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    if ([confirmAlert runModal] == NSAlertFirstButtonReturn) {
        // Delete file
        NSError *error;
        BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:storageItem.filePath error:&error];
        
        if (deleted) {
            // Remove from registry
            [storageItem.updateTimer invalidate];
            [self.mutableActiveStorages removeObject:storageItem];
            
            NSLog(@"🗑️ Deleted storage file and removed from registry: %@", storageItem.savedData.symbol);
            [self showNotification:@"Storage Deleted"
                           message:[NSString stringWithFormat:@"%@ storage permanently deleted", storageItem.savedData.symbol]];
        } else {
            NSLog(@"❌ Failed to delete storage file: %@", error.localizedDescription);
        }
    }
}

#pragma mark - Notification Observers

- (void)handleNewContinuousStorageCreated:(NSNotification *)notification {
    NSString *filePath = notification.userInfo[@"filePath"];
    if (filePath) {
        NSLog(@"📢 New continuous storage created notification: %@", filePath);
        [self registerContinuousStorage:filePath];
    }
}

- (void)handleDataHubDownload:(NSNotification *)notification {
    // Extract download info for opportunistic updates
    NSDictionary *userInfo = notification.userInfo;
    NSString *symbol = userInfo[@"symbol"];
    NSNumber *timeframeNum = userInfo[@"timeframe"];
    NSArray<HistoricalBarModel *> *bars = userInfo[@"bars"];
    
    if (symbol && timeframeNum && bars) {
        BarTimeframe timeframe = (BarTimeframe)[timeframeNum integerValue];
        [self handleOpportunisticUpdate:symbol timeframe:timeframe bars:bars];
    }
}

- (void)handleAppWillTerminate:(NSNotification *)notification {
    NSLog(@"🛑 App terminating - saving storage registry state");
    [self stopAllTimers];
    [self.masterCheckTimer invalidate];
    
    // Save current state to user defaults for next launch
    [self saveRegistryState];
}

#pragma mark - State Persistence

- (void)saveRegistryState {
    NSMutableArray *storageStates = [NSMutableArray array];
    
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        NSDictionary *state = @{
            @"filePath": item.filePath,
            @"failureCount": @(item.failureCount),
            @"isPaused": @(item.isPaused),
            @"lastFailureDate": item.lastFailureDate ?: [NSNull null]
        };
        [storageStates addObject:state];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:storageStates forKey:@"StorageManagerRegistry"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"💾 Saved registry state for %ld storages", (long)storageStates.count);
}

- (void)loadRegistryState {
    NSArray *storageStates = [[NSUserDefaults standardUserDefaults] objectForKey:@"StorageManagerRegistry"];
    
    if (!storageStates) return;
    
    NSLog(@"📖 Loading registry state for %ld storages", (long)storageStates.count);
    
    for (NSDictionary *state in storageStates) {
        NSString *filePath = state[@"filePath"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            if ([self registerContinuousStorage:filePath]) {
                // Restore additional state
                for (ActiveStorageItem *item in self.mutableActiveStorages) {
                    if ([item.filePath isEqualToString:filePath]) {
                        item.failureCount = [state[@"failureCount"] integerValue];
                        item.isPaused = [state[@"isPaused"] boolValue];
                        
                        id lastFailureDate = state[@"lastFailureDate"];
                        if (![lastFailureDate isKindOfClass:[NSNull class]]) {
                            item.lastFailureDate = (NSDate *)lastFailureDate;
                        }
                        break;
                    }
                }
            }
        } else {
            NSLog(@"⚠️ Storage file no longer exists: %@", filePath);
        }
    }
}

#pragma mark - Unified Storage Management

- (NSArray<UnifiedStorageItem *> *)allStorageItems {
    [self refreshAllStorageItemsIfNeeded];
    return self.cachedAllStorageItems ?: @[];
}

- (NSArray<UnifiedStorageItem *> *)continuousStorageItems {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"dataType == %d", SavedChartDataTypeContinuous];
    return [self.allStorageItems filteredArrayUsingPredicate:predicate];
}

- (NSArray<UnifiedStorageItem *> *)snapshotStorageItems {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"dataType == %d", SavedChartDataTypeSnapshot];
    return [self.allStorageItems filteredArrayUsingPredicate:predicate];
}

- (void)refreshAllStorageItems {
    NSLog(@"🚀 Fast refreshing storage items using FILENAME PARSING (no file loading)...");
    
    NSArray<NSString *> *allFiles = [ChartWidget availableSavedChartDataFiles];
    NSMutableArray<UnifiedStorageItem *> *allItems = [NSMutableArray array];
    
    // 1. Add continuous storage from registry (already loaded)
    for (ActiveStorageItem *activeItem in self.mutableActiveStorages) {
        UnifiedStorageItem *unifiedItem = [[UnifiedStorageItem alloc] init];
        unifiedItem.dataType = SavedChartDataTypeContinuous;
        unifiedItem.savedData = activeItem.savedData;
        unifiedItem.activeItem = activeItem;
        unifiedItem.filePath = activeItem.filePath;
        [allItems addObject:unifiedItem];
    }
    
    // 2. Parse ALL files using FILENAME PARSING
    for (NSString *filePath in allFiles) {
        @autoreleasepool {
            NSString *filename = [filePath lastPathComponent];
            
            if (![SavedChartData isNewFormatFilename:filename]) {
                NSLog(@"⚠️ Skipping old format file: %@", filename);
                continue;
            }
            
            // Skip if already in registry
            BOOL isAlreadyInRegistry = NO;
            for (ActiveStorageItem *activeItem in self.mutableActiveStorages) {
                if ([activeItem.filePath isEqualToString:filePath]) {
                    isAlreadyInRegistry = YES;
                    break;
                }
            }
            if (isAlreadyInRegistry) continue;
            
            // Create UnifiedStorageItem from filename parsing
            UnifiedStorageItem *unifiedItem = [self createUnifiedStorageItemFromFilename:filename filePath:filePath];
            if (unifiedItem) {
                [allItems addObject:unifiedItem];
                
                // Auto-register continuous storage
                if (unifiedItem.isContinuous) {
                    NSLog(@"📋 Found unregistered continuous storage, auto-registering: %@", filename);
                    [self registerContinuousStorageFromParsedData:unifiedItem];
                }
            }
        }
    }
    
    // 3. Sort by creation date
    [allItems sortUsingComparator:^NSComparisonResult(UnifiedStorageItem *obj1, UnifiedStorageItem *obj2) {
        NSDate *date1 = [SavedChartData creationDateFromFilename:[obj1.filePath lastPathComponent]];
        NSDate *date2 = [SavedChartData creationDateFromFilename:[obj2.filePath lastPathComponent]];
        if (!date1) date1 = [NSDate distantPast];
        if (!date2) date2 = [NSDate distantPast];
        return [date2 compare:date1];
    }];
    
    self.cachedAllStorageItems = [allItems copy];
    self.lastFileSystemScan = [NSDate date];
    
    NSLog(@"✅ Fast refresh complete: %ld total items - ZERO file loading!", (long)allItems.count);
}

- (UnifiedStorageItem *)createUnifiedStorageItemFromFilename:(NSString *)filename filePath:(NSString *)filePath {
    NSString *symbol = [SavedChartData symbolFromFilename:filename];
    NSString *typeStr = [SavedChartData typeFromFilename:filename];
    
    if (!symbol || !typeStr) return nil;
    
    UnifiedStorageItem *item = [[UnifiedStorageItem alloc] init];
    item.filePath = filePath;
    item.dataType = [typeStr isEqualToString:@"Continuous"] ? SavedChartDataTypeContinuous : SavedChartDataTypeSnapshot;
    item.savedData = nil; // For snapshots, we don't need SavedChartData object
    item.activeItem = nil;
    
    return item;
}

- (void)refreshAllStorageItemsIfNeeded {
    // Refresh se non mai fatto o se è passato più di 1 minuto dall'ultimo scan
    if (!self.lastFileSystemScan ||
        [[NSDate date] timeIntervalSinceDate:self.lastFileSystemScan] > 60.0) {
        [self refreshAllStorageItems];
    }
}

- (void)deleteStorageItem:(NSString *)filePath completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    NSLog(@"🗑️ Deleting storage item: %@", filePath);
    
    // 1. Se è continuous, rimuovi dal registry
    [self unregisterContinuousStorage:filePath];
    
    // 2. Elimina il file
    NSError *error;
    BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    
    if (deleted) {
        NSLog(@"✅ Successfully deleted storage file: %@", filePath);
        // Invalida cache per trigger refresh
        self.cachedAllStorageItems = nil;
        self.lastFileSystemScan = nil;
    } else {
        NSLog(@"❌ Failed to delete storage file: %@", error.localizedDescription);
    }
    
    if (completion) {
        completion(deleted, error);
    }
}

#pragma mark - Statistics & Monitoring

- (NSInteger)totalSnapshotStorages {
    return self.snapshotStorageItems.count;
}

- (NSInteger)totalAllStorages {
    return self.allStorageItems.count;
}

- (NSInteger)totalActiveStorages {
    return self.mutableActiveStorages.count;
}

- (NSInteger)storagesWithErrors {
    NSInteger count = 0;
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if (item.failureCount > 0) count++;
    }
    return count;
}

- (NSInteger)pausedStorages {
    NSInteger count = 0;
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if (item.isPaused) count++;
    }
    return count;
}

- (ActiveStorageItem *)nextStorageToUpdate {
    ActiveStorageItem *nextItem = nil;
    NSDate *earliestDate = nil;
    
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if (!item.isPaused && item.savedData.nextScheduledUpdate) {
            if (!earliestDate || [item.savedData.nextScheduledUpdate compare:earliestDate] == NSOrderedAscending) {
                earliestDate = item.savedData.nextScheduledUpdate;
                nextItem = item;
            }
        }
    }
    
    return nextItem;
}

#pragma mark - Utility Methods

- (void)showNotification:(NSString *)title message:(NSString *)message {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = message;
    notification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark - Configuration Property Setters

- (void)setAutomaticUpdatesEnabled:(BOOL)automaticUpdatesEnabled {
    if (_automaticUpdatesEnabled != automaticUpdatesEnabled) {
        _automaticUpdatesEnabled = automaticUpdatesEnabled;
        
        if (automaticUpdatesEnabled) {
            [self startAllTimers];
            NSLog(@"✅ Automatic updates enabled");
        } else {
            [self stopAllTimers];
            NSLog(@"⏸️ Automatic updates disabled");
        }
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopAllTimers];
    [self.masterCheckTimer invalidate];
}

@end
