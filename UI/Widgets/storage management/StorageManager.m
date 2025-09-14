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
#import "StorageMetadataCache.h"


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

@property (nonatomic, strong) StorageMetadataCache *metadataCache;
@property (nonatomic, strong) NSTimer *consistencyCheckTimer;
@property (nonatomic, strong) NSString *storageDirectory;
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
    
    NSLog(@"🚀 StorageManager initializing with cache system...");
    
    // ✅ NUOVO: Initialize cache system
    self.metadataCache = [StorageMetadataCache sharedCache];
    self.storageDirectory = [ChartWidget savedChartDataDirectory];
    
    // Setup notification observers
    [self setupNotificationObservers];
    
    // ✅ NUOVO: Initialize cache (with persistence fallback)
    [self initializeCacheSystem];
    
    // Auto-register existing continuous storage files from cache
    [self autoDiscoverContinuousStoragesFromCache];
    
    // ✅ NUOVO: Start consistency check timer (30 minutes)
    [self startConsistencyCheckTimer];
    
    // Start master timer for health checks
    [self startMasterTimer];
    
    _isInitialized = YES;
    NSLog(@"✅ StorageManager initialized with %ld active storages", (long)self.totalActiveStorages);
}

- (void)initializeCacheSystem {
    NSLog(@"📦 Initializing cache system...");
    
    // Try loading from UserDefaults first (fast startup)
    [self.metadataCache loadFromUserDefaults];
    
    // If no cached data, build from filesystem
    if (self.metadataCache.totalCount == 0) {
        NSLog(@"📦 No cached metadata found - building from filesystem");
        [self.metadataCache buildCacheFromDirectory:self.storageDirectory];
    } else {
        NSLog(@"📦 Loaded %ld items from cached metadata", (long)self.metadataCache.totalCount);
    }
}

- (void)autoDiscoverContinuousStoragesFromCache {
    NSArray<StorageMetadataItem *> *continuousItems = self.metadataCache.continuousItems;
    
    NSLog(@"🔍 Auto-discovering continuous storage from cache...");
    NSLog(@"🚀 Using CACHED METADATA - no file loading!");
    
    for (StorageMetadataItem *item in continuousItems) {
        [self registerContinuousStorageWithFilenameParsingOnly:item.filePath];
    }
    
    NSLog(@"📋 Auto-discovered %ld continuous storage files from cache", (long)continuousItems.count);
}

- (void)startConsistencyCheckTimer {
    // Timer after 30 minutes for consistency check
    self.consistencyCheckTimer = [NSTimer scheduledTimerWithTimeInterval:(30.0 * 60.0)
                                                                   target:self
                                                                 selector:@selector(performScheduledConsistencyCheck:)
                                                                 userInfo:nil
                                                                  repeats:NO];
    
    NSLog(@"⏰ Consistency check scheduled for 30 minutes from now");
}

- (void)performScheduledConsistencyCheck:(NSTimer *)timer {
    NSLog(@"🔍 Performing scheduled consistency check...");
    
    [self.metadataCache performConsistencyCheck:self.storageDirectory completion:^(NSInteger inconsistencies) {
        if (inconsistencies > 0) {
            NSLog(@"⚠️ Found %ld inconsistencies during consistency check", (long)inconsistencies);
            // Save updated cache
            [self.metadataCache saveToUserDefaults];
        } else {
            NSLog(@"✅ Consistency check passed - no inconsistencies found");
        }
    }];
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
    NSLog(@"🚀 Using FILENAME PARSING ONLY - no file loading!");
    
    for (NSString *filePath in continuousFiles) {
        // ✅ Use filename parsing only
        [self registerContinuousStorageWithFilenameParsingOnly:filePath];
    }
    
    NSLog(@"📋 Auto-discovered %ld continuous storage files using filename parsing", (long)continuousFiles.count);
}

#pragma mark - Lazy Loading for Updates

- (SavedChartData *)loadSavedDataForActiveItem:(ActiveStorageItem *)item {
    // Load SavedChartData ONLY when needed for updates
    if (!item.savedData) {
        NSLog(@"📄 Lazy loading SavedChartData for update: %@", [item.filePath lastPathComponent]);
        // todo carica i metadata?
        item.savedData = [SavedChartData loadFromFile:item.filePath];
        
        if (item.savedData) {
            // Schedule updates now that we have the data
            [self scheduleUpdateForStorageItem:item];
            NSLog(@"✅ Lazy loaded and scheduled updates for: %@", item.savedData.symbol);
        } else {
            NSLog(@"❌ Failed to lazy load SavedChartData: %@", item.filePath);
        }
    }
    
    return item.savedData;
}

#pragma mark - New Registry Management (Filename Parsing Only)

- (BOOL)registerContinuousStorageWithFilenameParsingOnly:(NSString *)filePath {
    NSString *filename = [filePath lastPathComponent];
    
    // Quick validation using filename parsing
    if (![SavedChartData isNewFormatFilename:filename]) {
        NSLog(@"⚠️ Skipping old format file: %@", filename);
        return NO;
    }
    
    NSString *typeStr = [SavedChartData typeFromFilename:filename];
    if (![typeStr isEqualToString:@"Continuous"]) {
        NSLog(@"⚠️ File is not continuous storage: %@", filename);
        return NO;
    }
    
    // Check if already registered
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if ([item.filePath isEqualToString:filePath]) {
            NSLog(@"ℹ️ Storage already registered: %@", filename);
            return YES;
        }
    }
    
    // ✅ Create ActiveStorageItem WITHOUT loading SavedChartData
    ActiveStorageItem *item = [[ActiveStorageItem alloc] init];
    item.filePath = filePath;
    item.savedData = nil; // We'll load this ONLY when actually needed for updates
    item.failureCount = 0;
    item.isPaused = NO;
    
    // Add to registry immediately
    [self.mutableActiveStorages addObject:item];
    
    NSLog(@"✅ Registered continuous storage (filename parsing): %@",
          [SavedChartData symbolFromFilename:filename]);
    
    return YES;
}



- (BOOL)registerContinuousStorage:(NSString *)filePath {
    NSString *filename = [filePath lastPathComponent];
    
    // Quick validation using filename parsing
    if (![SavedChartData isNewFormatFilename:filename]) {
        NSLog(@"⚠️ Skipping old format file: %@", filename);
        return NO;
    }
    
    NSString *typeStr = [SavedChartData typeFromFilename:filename];
    if (![typeStr isEqualToString:@"Continuous"]) {
        NSLog(@"⚠️ File is not continuous storage: %@", filename);
        return NO;
    }
    
    // Check if already registered
    for (ActiveStorageItem *item in self.mutableActiveStorages) {
        if ([item.filePath isEqualToString:filePath]) {
            NSLog(@"ℹ️ Storage already registered: %@", filename);
            return YES;
        }
    }
    
    // ✅ Create ActiveStorageItem WITHOUT loading SavedChartData
    ActiveStorageItem *item = [[ActiveStorageItem alloc] init];
    item.filePath = filePath;
    item.savedData = nil; // We'll load this ONLY when actually needed for updates
    item.failureCount = 0;
    item.isPaused = NO;
    
    // Add to registry immediately
    [self.mutableActiveStorages addObject:item];
    
    NSLog(@"✅ Registered continuous storage (filename parsing): %@",
          [SavedChartData symbolFromFilename:filename]);
    
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
    
    // ✅ For scheduling, we need the SavedChartData
    SavedChartData *storage = [self loadSavedDataForActiveItem:item];
    if (!storage) {
        NSLog(@"⚠️ Cannot schedule updates without SavedChartData: %@", item.filePath);
        return;
    }
    
    // Calculate next update date based on timeframe
    NSDate *nextUpdate = [self calculateNextUpdateDateForStorage:storage];
    storage.nextScheduledUpdate = nextUpdate;
    
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
          storage.symbol, [storage timeframeDescription], timeUntilUpdate / 3600.0);
}

- (NSDate *)calculateNextUpdateDateForStorage:(SavedChartData *)savedData {
    NSDate *baseDate = savedData.lastSuccessfulUpdate ?: savedData.endDate;
    NSTimeInterval updateInterval;
    
    // Update intervals based on timeframe
    switch (savedData.timeframe) {
        case BarTimeframe1Min:
            updateInterval = 30 * 24 * 60 * 60; // 30 days for 1min
            break;
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            updateInterval = 241 * 24 * 60 * 60; // 241 days (8 months) for 5min+
            break;
        case BarTimeframeDaily:
        case BarTimeframeWeekly:
        case BarTimeframeMonthly:
            updateInterval = 365 * 24 * 60 * 60; // 1 year for daily+
            break;
        default:
            updateInterval = 241 * 24 * 60 * 60; // Default to 8 months
            break;
    }
    
    return [baseDate dateByAddingTimeInterval:updateInterval];
}

- (void)logInitializationPerformance {
    NSLog(@"📊 StorageManager Initialization Performance:");
    NSLog(@"   🚀 Method: FILENAME PARSING ONLY");
    NSLog(@"   📁 Files discovered: %ld", (long)self.mutableActiveStorages.count);
    NSLog(@"   💾 File loading: ZERO (lazy loading only)");
    NSLog(@"   ⚡ Performance: MAXIMUM (instant initialization)");
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
                NSLog(@"⏸️ Paused automatic updates for: %@", [item.filePath lastPathComponent]);
            } else {
                [self scheduleUpdateForStorageItem:item];
                NSLog(@"▶️ Resumed automatic updates for: %@", [item.filePath lastPathComponent]);
            }
            
            [self.metadataCache performConsistencyCheck:self.storageDirectory completion:nil];

            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"StorageManagerDidUpdateRegistry"
                                                                object:self
                                                              userInfo:@{@"action": paused ? @"paused" : @"resumed", @"filePath": filePath}];
            break;
        }
    }
}

#pragma mark - Update Operations
- (void)performUpdateForStorageItem:(ActiveStorageItem *)item
                         completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    if (!item) {
        NSError *error = [NSError errorWithDomain:@"StorageManager"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid storage item"}];
        if (completion) completion(NO, error);
        return;
    }
    
    // Lazy load SavedChartData if not already loaded
    if (!item.savedData) {
        item.savedData = [self loadSavedDataForActiveItem:item];
        if (!item.savedData) {
            NSError *error = [NSError errorWithDomain:@"StorageManager"
                                                 code:1002
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to load SavedChartData for update"}];
            if (completion) completion(NO, error);
            return;
        }
    }
    
    SavedChartData *storage = item.savedData;
    
    NSLog(@"🔄 Performing update for %@ [%@]", storage.symbol, storage.timeframeDescription);
    [self postUpdateNotification:@"updating" forStorage:storage];
    
    // Calculate new date range for update
    NSDate *fromDate = storage.endDate;
    NSDate *toDate = [NSDate date];
    
    // Request new data from DataHub
    [[DataHub shared] getHistoricalBarsForSymbol:storage.symbol
                                        timeframe:storage.timeframe
                                        startDate:fromDate
                                          endDate:toDate
                                needExtendedHours:storage.includesExtendedHours
                                       completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            if (!bars || bars.count == 0) {
                NSLog(@"ℹ️ No new data available for %@ - storage is up to date", storage.symbol);
                
                // Update next scheduled time even if no new data
                storage.nextScheduledUpdate = [self calculateNextUpdateDateForStorage:storage];
                
                // Save the updated schedule
                NSError *saveError;
                NSString *updatedFilePath = [storage saveToFileWithFilenameUpdate:item.filePath error:&saveError];
                
                if (updatedFilePath) {
                    // Update file path if filename changed
                    if (![updatedFilePath isEqualToString:item.filePath]) {
                        [self.metadataCache handleFileRenamed:item.filePath newPath:updatedFilePath];
                        item.filePath = updatedFilePath;
                    } else {
                        [self.metadataCache handleFileUpdated:updatedFilePath];
                    }
                    
                    // Save cache
                    [self.metadataCache saveToUserDefaults];
                }
                
                [self postUpdateNotification:@"up_to_date" forStorage:storage];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(YES, nil);
                });
                return;
            }
            
            NSLog(@"📥 Received %ld new bars for %@", (long)bars.count, storage.symbol);
            
            // Validate data compatibility
            if (![storage isCompatibleWithBars:bars]) {
                NSError *compatibilityError = [NSError errorWithDomain:@"StorageManager"
                                                                  code:1003
                                                              userInfo:@{NSLocalizedDescriptionKey: @"New data is incompatible with existing storage"}];
                [self handleUpdateFailureForItem:item error:compatibilityError];
                [self postUpdateNotification:@"failed" forStorage:storage];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(NO, compatibilityError);
                });
                return;
            }
            
            // Merge new bars with existing data
            BOOL mergeSuccess = [storage mergeWithNewBars:bars overlapBarCount:3];
            
            if (!mergeSuccess) {
                NSError *mergeError = [NSError errorWithDomain:@"StorageManager"
                                                          code:1004
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to merge new data with existing storage"}];
                [self handleUpdateFailureForItem:item error:mergeError];
                [self postUpdateNotification:@"failed" forStorage:storage];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(NO, mergeError);
                });
                return;
            }
            
            // Update metadata
            storage.lastSuccessfulUpdate = [NSDate date];
            storage.nextScheduledUpdate = [self calculateNextUpdateDateForStorage:storage];
            
            // Save updated storage to file with filename update
            NSError *saveError;
            NSString *updatedFilePath = [storage saveToFileWithFilenameUpdate:item.filePath error:&saveError];
            
            if (updatedFilePath) {
                NSLog(@"✅ Update completed for %@ - added %ld bars", storage.symbol, (long)bars.count);
                
                // Reset failure count on success
                item.failureCount = 0;
                item.lastFailureDate = nil;
                
                // Update file path if filename changed
                if (![updatedFilePath isEqualToString:item.filePath]) {
                    [self.metadataCache handleFileRenamed:item.filePath newPath:updatedFilePath];
                    item.filePath = updatedFilePath;
                } else {
                    [self.metadataCache handleFileUpdated:updatedFilePath];
                }
                
                // Save cache
                [self.metadataCache saveToUserDefaults];
                
                [self postUpdateNotification:@"completed" forStorage:storage];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(YES, nil);
                });
                
            } else {
                NSLog(@"❌ Failed to save updated storage for %@: %@", storage.symbol, saveError.localizedDescription);
                [self handleUpdateFailureForItem:item error:saveError];
                [self postUpdateNotification:@"failed" forStorage:storage];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(NO, saveError);
                });
            }
            
            // Schedule next update
            [self scheduleUpdateForStorageItem:item];
        });
    }];
}


- (NSTimeInterval)timeframeToSeconds:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:
            return 60;
        case BarTimeframe5Min:
            return 300;
        case BarTimeframe15Min:
            return 900;
        case BarTimeframe30Min:
            return 1800;
        case BarTimeframe1Hour:
            return 3600;
        case BarTimeframe4Hour:
            return 14400;
        case BarTimeframeDaily:
            return 86400;
        case BarTimeframeWeekly:
            return 604800;
        case BarTimeframeMonthly:
            return 2629746; // Average month
        default:
            return 3600; // Default to 1 hour
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

- (void)postUpdateNotification:(NSString *)status forStorage:(SavedChartData *)storage {
    NSDictionary *userInfo = @{
        @"symbol": storage.symbol ?: @"Unknown",
        @"timeframe": storage.timeframeDescription ?: @"Unknown",
        @"status": status,
        @"timestamp": [NSDate date]
    };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"StorageManagerUpdateStatusChanged"
                                                        object:self
                                                      userInfo:userInfo];
    
    NSLog(@"📢 Posted update notification: %@ - %@", status, storage.symbol);
}
#pragma mark - Manual Updates

- (void)forceUpdateForStorage:(NSString *)filePath
                   completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    // Find active storage item
    ActiveStorageItem *item = nil;
    for (ActiveStorageItem *activeItem in self.mutableActiveStorages) {
        if ([activeItem.filePath isEqualToString:filePath]) {
            item = activeItem;
            break;
        }
    }
    
    if (!item) {
        // Try to register if not found
        NSLog(@"⚠️ Storage not in registry - attempting to register: %@", filePath);
        if ([self registerContinuousStorageWithFilenameParsingOnly:filePath]) {
            // Retry find after registration
            for (ActiveStorageItem *activeItem in self.mutableActiveStorages) {
                if ([activeItem.filePath isEqualToString:filePath]) {
                    item = activeItem;
                    break;
                }
            }
        }
        
        if (!item) {
            NSError *error = [NSError errorWithDomain:@"StorageManager"
                                                 code:1005
                                             userInfo:@{NSLocalizedDescriptionKey: @"Storage not found in active registry"}];
            if (completion) completion(NO, error);
            return;
        }
    }
    
    NSLog(@"🔧 Force updating storage: %@", [item.filePath lastPathComponent]);
    
    // Invalidate timer to avoid conflicts
    [item.updateTimer invalidate];
    item.updateTimer = nil;
    
    // Perform update
    [self performUpdateForStorageItem:item completion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"✅ Force update completed successfully");
            
            // ✅ NUOVO: Update cache after successful update
            [self updateCacheForFilePath:item.filePath];
            
        } else {
            NSLog(@"❌ Force update failed: %@", error.localizedDescription);
        }
        
        // Reschedule timer after update
        if (!item.isPaused) {
            [self scheduleUpdateForStorageItem:item];
        }
        
        // Send notification of registry update
        [[NSNotificationCenter defaultCenter] postNotificationName:@"StorageManagerDidUpdateRegistry"
                                                            object:self
                                                          userInfo:@{@"action": @"forceUpdate", @"filePath": filePath}];
        
        if (completion) completion(success, error);
    }];
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
                BOOL saveSuccess = [storage saveToFileWithFilenameUpdate:item.filePath error:&saveError];
                
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
        case BarTimeframe1Min: return @"1min";
        case BarTimeframe5Min: return @"5min";
        case BarTimeframe15Min: return @"15min";
        case BarTimeframe30Min: return @"30min";
        case BarTimeframe1Hour: return @"1hour";
        case BarTimeframe4Hour: return @"4hour";
        case BarTimeframeDaily: return @"daily";
        case BarTimeframeWeekly: return @"weekly";
        case BarTimeframeMonthly: return @"monthly";
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
            // ✅ CORREZIONE: Lazy load se necessario
            if (!item.savedData) {
                item.savedData = [SavedChartData loadFromFile:item.filePath];
                if (!item.savedData) {
                    NSLog(@"❌ Cannot load SavedChartData for conversion: %@", filePath);
                    return;
                }
            }
            
            // Convert the SavedChartData to snapshot
            [item.savedData convertToSnapshot];
            
            
            // todo correggere save to file con il filepath contenente metadata [storage saveToFileWithFilenameUpdate:item.filePath error:&saveError];
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
                
                // ✅ AGGIUNTO: Invalida cache e invia notifica
                [self.metadataCache performConsistencyCheck:self.storageDirectory completion:nil];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"StorageManagerDidUpdateRegistry"
                                                                    object:self
                                                                  userInfo:@{@"action": @"convertedToSnapshot", @"filePath": filePath}];
                
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


- (void)updateCacheForFilePath:(NSString *)filePath {
    // Update cache metadata after file modification
    [self.metadataCache handleFileUpdated:filePath];
    
    // Save to UserDefaults for persistence
    [self.metadataCache saveToUserDefaults];
    
    NSLog(@"📦 Updated cache for file: %@", [filePath lastPathComponent]);
}


- (void)deleteStorageItem:(NSString *)filePath completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    NSLog(@"🗑️ Deleting storage item: %@", filePath);
    
    // 1. Remove from continuous registry if needed
    [self unregisterContinuousStorage:filePath];
    
    // 2. Delete the file
    NSError *error;
    BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    
    if (deleted) {
        NSLog(@"✅ Successfully deleted storage file: %@", filePath);
        
        // ✅ NUOVO: Update cache after deletion
        [self.metadataCache handleFileDeleted:filePath];
        
        // Send notification
        [[NSNotificationCenter defaultCenter] postNotificationName:@"StorageManagerDidUpdateRegistry"
                                                            object:self
                                                          userInfo:@{@"action": @"deleted", @"filePath": filePath}];
    } else {
        NSLog(@"❌ Failed to delete storage file: %@", error.localizedDescription);
    }
    
    if (completion) {
        completion(deleted, error);
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
    
    NSLog(@"💾 Saved registry state for %ld storages (filename parsing mode)", (long)storageStates.count);
}

- (void)loadRegistryState {
    NSArray *storageStates = [[NSUserDefaults standardUserDefaults] objectForKey:@"StorageManagerRegistry"];
    
    if (!storageStates) return;
    
    NSLog(@"📖 Loading registry state for %ld storages (filename parsing mode)", (long)storageStates.count);
    
    for (NSDictionary *state in storageStates) {
        NSString *filePath = state[@"filePath"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            // ✅ Use filename parsing for registry restoration
            if ([self registerContinuousStorageWithFilenameParsingOnly:filePath]) {
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
    NSArray<StorageMetadataItem *> *cachedItems = self.metadataCache.allItems;
    return [self createUnifiedStorageItemsFromCachedItems:cachedItems];
}

- (NSArray<UnifiedStorageItem *> *)continuousStorageItems {
    NSArray<StorageMetadataItem *> *cachedItems = self.metadataCache.continuousItems;
    return [self createUnifiedStorageItemsFromCachedItems:cachedItems];
}

- (NSArray<UnifiedStorageItem *> *)snapshotStorageItems {
    NSArray<StorageMetadataItem *> *cachedItems = self.metadataCache.snapshotItems;
    return [self createUnifiedStorageItemsFromCachedItems:cachedItems];
}

// Helper method to convert cached items to UnifiedStorageItems
- (NSArray<UnifiedStorageItem *> *)createUnifiedStorageItemsFromCachedItems:(NSArray<StorageMetadataItem *> *)cachedItems {
    NSMutableArray<UnifiedStorageItem *> *unifiedItems = [NSMutableArray array];
    
    for (StorageMetadataItem *cachedItem in cachedItems) {
        UnifiedStorageItem *unifiedItem = [[UnifiedStorageItem alloc] init];
        unifiedItem.filePath = cachedItem.filePath;
        unifiedItem.dataType = cachedItem.dataType;
        unifiedItem.savedData = nil; // Lazy loading when needed
        
        // Link to ActiveStorageItem if it's continuous
        if (cachedItem.isContinuous) {
            for (ActiveStorageItem *activeItem in self.mutableActiveStorages) {
                if ([activeItem.filePath isEqualToString:cachedItem.filePath]) {
                    unifiedItem.activeItem = activeItem;
                    break;
                }
            }
        }
        
        [unifiedItems addObject:unifiedItem];
    }
    
    // Sort by creation date (newest first)
    [unifiedItems sortUsingComparator:^NSComparisonResult(UnifiedStorageItem *obj1, UnifiedStorageItem *obj2) {
        StorageMetadataItem *item1 = [self.metadataCache itemForPath:obj1.filePath];
        StorageMetadataItem *item2 = [self.metadataCache itemForPath:obj2.filePath];
        
        NSDate *date1 = item1.creationDate ?: [NSDate distantPast];
        NSDate *date2 = item2.creationDate ?: [NSDate distantPast];
        
        return [date2 compare:date1];
    }];
    
    return [unifiedItems copy];
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
    
    // ✅ NUOVO: Save cache on app termination
    [self.consistencyCheckTimer invalidate];
    [self.metadataCache saveToUserDefaults];
    
    NSLog(@"💾 StorageManager: Cache saved on dealloc");
}
@end
