
//
//  StorageSystemInitializer.m
//  TradingApp
//

#import "StorageSystemInitializer.h"
#import "StorageManager.h"
#import "DataHub+StorageIntegration.h"
#import "ChartWidget+SaveData.h"

@interface StorageSystemInitializer ()
@property (nonatomic, assign) BOOL systemInitialized;
@property (nonatomic, strong) NSDate *initializationDate;
@property (nonatomic, strong) NSMutableArray<NSString *> *initializationLog;
@end

@implementation StorageSystemInitializer

#pragma mark - Singleton

+ (instancetype)sharedInitializer {
    static StorageSystemInitializer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _systemInitialized = NO;
        _initializationLog = [NSMutableArray array];
    }
    return self;
}

#pragma mark - System Initialization

- (void)initializeStorageSystemWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    if (self.systemInitialized) {
        NSLog(@"✅ Storage system already initialized");
        if (completion) completion(YES, nil);
        return;
    }
    
    NSLog(@"🚀 Initializing complete storage system (Phase 2)...");
    self.initializationDate = [NSDate date];
    [self.initializationLog removeAllObjects];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL success = YES;
        NSError *error = nil;
        
        @try {
            // Step 1: Ensure storage directory exists
            [self logStep:@"Creating storage directory structure"];
            if (![self ensureStorageDirectoryStructure]) {
                success = NO;
                error = [NSError errorWithDomain:@"StorageSystemInitializer"
                                            code:1001
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to create storage directory"}];
            }
            
            // Step 2: Initialize StorageManager
            if (success) {
                [self logStep:@"Initializing StorageManager"];
                StorageManager *manager = [StorageManager sharedManager];
                // Apply default configuration
                manager.maxRetryCount = 10;
                manager.gapToleranceDays = 15;
                manager.automaticUpdatesEnabled = YES;
            }
            
            // Step 3: Initialize DataHub storage integration
            if (success) {
                [self logStep:@"Setting up DataHub integration"];
                DataHub *dataHub = [DataHub shared];
                dataHub.storageIntegrationEnabled = YES;
                dataHub.opportunisticUpdatesEnabled = YES;
                dataHub.opportunisticUpdateThreshold = 10;
                [dataHub initializeStorageManagerIntegration];
            }
            
            // Step 4: Setup notification observers
            if (success) {
                [self logStep:@"Setting up system notifications"];
                [self setupSystemNotifications];
            }
            
            // Step 5: Perform initial health check
            if (success) {
                [self logStep:@"Performing initial health check"];
                [self performInitialHealthCheck];
            }
            
            // Step 6: Mark as initialized
            if (success) {
                [self logStep:@"System initialization complete"];
                self.systemInitialized = YES;
                
                // Log final statistics
                StorageManager *manager = [StorageManager sharedManager];
                NSLog(@"✅ Storage system initialized successfully:");
                NSLog(@"   Total active storages: %ld", (long)manager.totalActiveStorages);
                NSLog(@"   Storages with errors: %ld", (long)manager.storagesWithErrors);
                NSLog(@"   Automatic updates: %@", manager.automaticUpdatesEnabled ? @"enabled" : @"disabled");
                NSLog(@"   Initialization time: %.2f seconds", [[NSDate date] timeIntervalSinceDate:self.initializationDate]);
            }
            
        } @catch (NSException *exception) {
            success = NO;
            error = [NSError errorWithDomain:@"StorageSystemInitializer"
                                        code:1002
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Exception during initialization: %@", exception.reason]}];
            NSLog(@"❌ Exception during storage system initialization: %@", exception);
        }
        
        // Return to main queue for completion
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(success, error);
            }
        });
    });
}

- (BOOL)ensureStorageDirectoryStructure {
    NSString *storageDir = [ChartWidget savedChartDataDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    BOOL isDirectory;
    if (![fileManager fileExistsAtPath:storageDir isDirectory:&isDirectory]) {
        NSError *error;
        BOOL created = [fileManager createDirectoryAtPath:storageDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
        if (!created) {
            NSLog(@"❌ Failed to create storage directory: %@", error.localizedDescription);
            return NO;
        }
        NSLog(@"📁 Created storage directory: %@", storageDir);
    } else if (!isDirectory) {
        NSLog(@"❌ Storage path exists but is not a directory: %@", storageDir);
        return NO;
    }
    
    return YES;
}

- (void)setupSystemNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Listen for app lifecycle events
    [nc addObserver:self
           selector:@selector(handleAppDidFinishLaunching:)
               name:NSApplicationDidFinishLaunchingNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(handleAppWillTerminate:)
               name:NSApplicationWillTerminateNotification
             object:nil];
    
    // Listen for storage system events
    [nc addObserver:self
           selector:@selector(handleStorageSystemEvent:)
               name:@"StorageSystemHealthAlert"
             object:nil];
}

- (void)performInitialHealthCheck {
    StorageManager *manager = [StorageManager sharedManager];
    NSInteger totalStorages = manager.totalActiveStorages;
    NSInteger errorStorages = manager.storagesWithErrors;
    
    if (totalStorages > 0) {
        NSLog(@"🏥 Initial health check: %ld active storages, %ld with errors",
              (long)totalStorages, (long)errorStorages);
        
        if (errorStorages > 0) {
            NSLog(@"⚠️ Found %ld storages with errors - may need attention", (long)errorStorages);
        }
    } else {
        NSLog(@"ℹ️ No active continuous storages found - system ready for new storages");
    }
}

- (void)logStep:(NSString *)step {
    NSString *logEntry = [NSString stringWithFormat:@"[%.2fs] %@",
                         [[NSDate date] timeIntervalSinceDate:self.initializationDate], step];
    [self.initializationLog addObject:logEntry];
    NSLog(@"🔧 %@", logEntry);
}

#pragma mark - System Status

- (BOOL)isSystemInitialized {
    return self.systemInitialized;
}

- (NSString *)systemStatus {
    if (!self.systemInitialized) {
        return @"❌ Not Initialized";
    }
    
    StorageManager *manager = [StorageManager sharedManager];
    NSInteger total = manager.totalActiveStorages;
    NSInteger errors = manager.storagesWithErrors;
    NSInteger paused = manager.pausedStorages;
    
    if (total == 0) {
        return @"🔄 Ready (No active storages)";
    } else if (errors > 0) {
        return [NSString stringWithFormat:@"⚠️ %ld error(s) of %ld", (long)errors, (long)total];
    } else if (paused == total) {
        return [NSString stringWithFormat:@"⏸️ All paused (%ld)", (long)total];
    } else {
        return [NSString stringWithFormat:@"✅ Operational (%ld active)", (long)(total - paused)];
    }
}

- (NSInteger)totalActiveStorages {
    return [[StorageManager sharedManager] totalActiveStorages];
}

- (NSDate *)nextScheduledUpdate {
    ActiveStorageItem *nextItem = [[StorageManager sharedManager] nextStorageToUpdate];
    return nextItem ? nextItem.savedData.nextScheduledUpdate : nil;
}

#pragma mark - Configuration Presets

- (void)applyDevelopmentConfiguration {
    NSLog(@"🔧 Applying development configuration...");
    
    StorageManager *manager = [StorageManager sharedManager];
    manager.maxRetryCount = 3; // Shorter retry for testing
    manager.gapToleranceDays = 5; // Shorter tolerance for testing
    manager.automaticUpdatesEnabled = YES;
    
    DataHub *dataHub = [DataHub shared];
    dataHub.storageIntegrationEnabled = YES;
    dataHub.opportunisticUpdatesEnabled = YES;
    dataHub.opportunisticUpdateThreshold = 5; // Lower threshold for testing
    
    NSLog(@"✅ Development configuration applied");
}

- (void)applyProductionConfiguration {
    NSLog(@"🔧 Applying production configuration...");
    
    StorageManager *manager = [StorageManager sharedManager];
    manager.maxRetryCount = 10; // Standard retry count
    manager.gapToleranceDays = 15; // Standard tolerance
    manager.automaticUpdatesEnabled = YES;
    
    DataHub *dataHub = [DataHub shared];
    dataHub.storageIntegrationEnabled = YES;
    dataHub.opportunisticUpdatesEnabled = YES;
    dataHub.opportunisticUpdateThreshold = 10; // Standard threshold
    
    NSLog(@"✅ Production configuration applied");
}

- (void)resetSystemForTesting {
    NSLog(@"🧪 Resetting storage system for testing...");
    
    // Stop all timers
    [[StorageManager sharedManager] stopAllTimers];
    
    // Clear registry (but don't delete files)
    StorageManager *manager = [StorageManager sharedManager];
    for (ActiveStorageItem *item in manager.activeStorages) {
        [manager unregisterContinuousStorage:item.filePath];
    }
    
    // Reset initialization state
    self.systemInitialized = NO;
    [self.initializationLog removeAllObjects];
    
    NSLog(@"✅ System reset complete - ready for testing");
}

#pragma mark - Health Checks

- (void)performSystemHealthCheck:(void(^)(BOOL healthy, NSArray<NSString *> *issues))completion {
    NSLog(@"🏥 Performing comprehensive system health check...");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSString *> *issues = [NSMutableArray array];
        BOOL healthy = YES;
        
        // Check 1: System initialization
        if (!self.systemInitialized) {
            [issues addObject:@"Storage system not initialized"];
            healthy = NO;
        }
        
        // Check 2: Storage directory accessibility
        NSString *storageDir = [ChartWidget savedChartDataDirectory];
        if (![[NSFileManager defaultManager] fileExistsAtPath:storageDir]) {
            [issues addObject:@"Storage directory does not exist"];
            healthy = NO;
        }
        
        // Check 3: StorageManager state
        StorageManager *manager = [StorageManager sharedManager];
        NSInteger errorStorages = manager.storagesWithErrors;
        if (errorStorages > 0) {
            [issues addObject:[NSString stringWithFormat:@"%ld storage(s) have errors", (long)errorStorages]];
            // This is a warning, not a fatal issue
        }
        
        // Check 4: File system integrity
        NSArray<NSString *> *storageFiles = [ChartWidget availableSavedChartDataFilesOfType:SavedChartDataTypeContinuous];
        NSInteger registeredCount = manager.totalActiveStorages;
        
        if (storageFiles.count != registeredCount) {
            [issues addObject:[NSString stringWithFormat:@"File/registry mismatch: %ld files vs %ld registered",
                              (long)storageFiles.count, (long)registeredCount]];
        }
        
        // Check 5: DataHub integration
        DataHub *dataHub = [DataHub shared];
        if (!dataHub.storageIntegrationEnabled) {
            [issues addObject:@"DataHub storage integration disabled"];
        }
        
        // Check 6: Timer system
        ActiveStorageItem *nextItem = manager.nextStorageToUpdate;
        if (manager.totalActiveStorages > 0 && !nextItem && manager.automaticUpdatesEnabled) {
            [issues addObject:@"No timers scheduled despite active storages"];
            healthy = NO;
        }
        
        NSLog(@"🏥 Health check complete: %@ (%ld issues)", healthy ? @"HEALTHY" : @"ISSUES FOUND", (long)issues.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(healthy, [issues copy]);
            }
        });
    });
}

- (void)attemptAutoRecovery {
    NSLog(@"🔧 Attempting automatic system recovery...");
    
    [self performSystemHealthCheck:^(BOOL healthy, NSArray<NSString *> *issues) {
        if (healthy) {
            NSLog(@"✅ System is healthy - no recovery needed");
            return;
        }
        
        NSLog(@"🔧 Found %ld issues - attempting recovery...", (long)issues.count);
        
        for (NSString *issue in issues) {
            if ([issue containsString:@"Storage directory does not exist"]) {
                [self ensureStorageDirectoryStructure];
                NSLog(@"🔧 Fixed: Recreated storage directory");
                
            } else if ([issue containsString:@"not initialized"]) {
                [self initializeStorageSystemWithCompletion:^(BOOL success, NSError *error) {
                    if (success) {
                        NSLog(@"🔧 Fixed: Reinitialized storage system");
                    } else {
                        NSLog(@"❌ Failed to reinitialize: %@", error.localizedDescription);
                    }
                }];
                
            } else if ([issue containsString:@"File/registry mismatch"]) {
                // Re-register continuous storage files
                NSArray<NSString *> *storageFiles = [ChartWidget availableSavedChartDataFilesOfType:SavedChartDataTypeContinuous];
                StorageManager *manager = [StorageManager sharedManager];
                
                for (NSString *filePath in storageFiles) {
                    [manager registerContinuousStorage:filePath];
                }
                NSLog(@"🔧 Fixed: Re-registered %ld storage files", (long)storageFiles.count);
                
            } else if ([issue containsString:@"integration disabled"]) {
                DataHub *dataHub = [DataHub shared];
                dataHub.storageIntegrationEnabled = YES;
                [dataHub initializeStorageManagerIntegration];
                NSLog(@"🔧 Fixed: Re-enabled DataHub integration");
                
            } else if ([issue containsString:@"No timers scheduled"]) {
                [[StorageManager sharedManager] startAllTimers];
                NSLog(@"🔧 Fixed: Restarted all timers");
            }
        }
        
        NSLog(@"✅ Auto-recovery complete");
    }];
}

#pragma mark - Notification Handlers

- (void)handleAppDidFinishLaunching:(NSNotification *)notification {
    // Perform delayed initialization after app is fully loaded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.systemInitialized) {
            [self initializeStorageSystemWithCompletion:^(BOOL success, NSError *error) {
                if (!success) {
                    NSLog(@"❌ Failed to initialize storage system on app launch: %@", error.localizedDescription);
                }
            }];
        }
    });
}

- (void)handleAppWillTerminate:(NSNotification *)notification {
    NSLog(@"🛑 App terminating - performing storage system cleanup...");
    
    // Ensure all timers are stopped and state is saved
    [[StorageManager sharedManager] stopAllTimers];
    
    // Log final statistics
    if (self.systemInitialized) {
        StorageManager *manager = [StorageManager sharedManager];
        NSLog(@"📊 Final storage statistics:");
        NSLog(@"   Total active storages: %ld", (long)manager.totalActiveStorages);
        NSLog(@"   Storages with errors: %ld", (long)manager.storagesWithErrors);
        NSLog(@"   System uptime: %.0f minutes", [[NSDate date] timeIntervalSinceDate:self.initializationDate] / 60.0);
    }
}

- (void)handleStorageSystemEvent:(NSNotification *)notification {
    NSString *eventType = notification.userInfo[@"eventType"];
    NSString *message = notification.userInfo[@"message"];
    
    NSLog(@"🚨 Storage system event: %@ - %@", eventType, message);
    
    // Auto-recovery for critical events
    if ([eventType isEqualToString:@"CRITICAL"]) {
        [self attemptAutoRecovery];
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
