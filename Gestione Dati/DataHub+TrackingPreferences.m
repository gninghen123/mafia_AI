//
//  DataHub+TrackingPreferences.m
//  Performance tracking configuration implementation
//

#import "DataHub+TrackingPreferences.h"
#import "DataHub+Private.h"
#import <objc/runtime.h>
#import "DataHub+OptimizedTracking.h"

// NSUserDefaults Keys
static NSString *const kTrackingOptimizedEnabledKey = @"TrackingOptimizedEnabled";
static NSString *const kTrackingUserDefaultsIntervalKey = @"TrackingUserDefaultsInterval";
static NSString *const kTrackingCoreDataIntervalKey = @"TrackingCoreDataInterval";
static NSString *const kTrackingMaxBatchSizeKey = @"TrackingMaxBatchSize";
static NSString *const kTrackingChunkSizeKey = @"TrackingChunkSize";
static NSString *const kTrackingFlushOnBackgroundKey = @"TrackingFlushOnBackground";
static NSString *const kTrackingFlushOnTerminateKey = @"TrackingFlushOnTerminate";
static NSString *const kTrackingLastConfigSaveKey = @"TrackingLastConfigSave";

// Default Values
static const NSTimeInterval kDefaultUserDefaultsInterval = 600.0;   // 10 minutes
static const NSTimeInterval kDefaultCoreDataInterval = 3600.0;      // 1 hour
static const NSInteger kDefaultMaxBatchSize = 1000;
static const NSInteger kDefaultChunkSize = 100;

// Associated Object Keys
static const void *kOptimizedTrackingEnabledKey = &kOptimizedTrackingEnabledKey;
static const void *kUserDefaultsBackupIntervalKey = &kUserDefaultsBackupIntervalKey;
static const void *kCoreDataFlushIntervalKey = &kCoreDataFlushIntervalKey;
static const void *kMaxBatchSizeKey = &kMaxBatchSizeKey;
static const void *kChunkSizeKey = &kChunkSizeKey;
static const void *kFlushOnAppBackgroundKey = &kFlushOnAppBackgroundKey;
static const void *kFlushOnAppTerminateKey = &kFlushOnAppTerminateKey;

@implementation DataHub (TrackingPreferences)

#pragma mark - Associated Properties

- (BOOL)optimizedTrackingEnabled {
    NSNumber *value = objc_getAssociatedObject(self, kOptimizedTrackingEnabledKey);
    return value ? [value boolValue] : YES; // Default enabled
}

- (void)setOptimizedTrackingEnabled:(BOOL)optimizedTrackingEnabled {
    objc_setAssociatedObject(self, kOptimizedTrackingEnabledKey, @(optimizedTrackingEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTimeInterval)userDefaultsBackupInterval {
    NSNumber *value = objc_getAssociatedObject(self, kUserDefaultsBackupIntervalKey);
    return value ? [value doubleValue] : kDefaultUserDefaultsInterval;
}

- (void)setUserDefaultsBackupInterval:(NSTimeInterval)userDefaultsBackupInterval {
    objc_setAssociatedObject(self, kUserDefaultsBackupIntervalKey, @(userDefaultsBackupInterval), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTimeInterval)coreDataFlushInterval {
    NSNumber *value = objc_getAssociatedObject(self, kCoreDataFlushIntervalKey);
    return value ? [value doubleValue] : kDefaultCoreDataInterval;
}

- (void)setCoreDataFlushInterval:(NSTimeInterval)coreDataFlushInterval {
    objc_setAssociatedObject(self, kCoreDataFlushIntervalKey, @(coreDataFlushInterval), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)maxBatchSize {
    NSNumber *value = objc_getAssociatedObject(self, kMaxBatchSizeKey);
    return value ? [value integerValue] : kDefaultMaxBatchSize;
}

- (void)setMaxBatchSize:(NSInteger)maxBatchSize {
    objc_setAssociatedObject(self, kMaxBatchSizeKey, @(maxBatchSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)chunkSize {
    NSNumber *value = objc_getAssociatedObject(self, kChunkSizeKey);
    return value ? [value integerValue] : kDefaultChunkSize;
}

- (void)setChunkSize:(NSInteger)chunkSize {
    objc_setAssociatedObject(self, kChunkSizeKey, @(chunkSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)flushOnAppBackground {
    NSNumber *value = objc_getAssociatedObject(self, kFlushOnAppBackgroundKey);
    return value ? [value boolValue] : YES; // Default enabled
}

- (void)setFlushOnAppBackground:(BOOL)flushOnAppBackground {
    objc_setAssociatedObject(self, kFlushOnAppBackgroundKey, @(flushOnAppBackground), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)flushOnAppTerminate {
    NSNumber *value = objc_getAssociatedObject(self, kFlushOnAppTerminateKey);
    return value ? [value boolValue] : YES; // Default enabled
}

- (void)setFlushOnAppTerminate:(BOOL)flushOnAppTerminate {
    objc_setAssociatedObject(self, kFlushOnAppTerminateKey, @(flushOnAppTerminate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Preset Management

- (void)applyTrackingPreset:(TrackingPresetMode)preset {
    switch (preset) {
        case TrackingPresetModeRealTime:
            self.optimizedTrackingEnabled = NO; // Use legacy immediate saves
            self.userDefaultsBackupInterval = 60.0;    // 1 minute
            self.coreDataFlushInterval = 300.0;        // 5 minutes
            self.maxBatchSize = 100;
            self.chunkSize = 25;
            break;
            
        case TrackingPresetModeBalanced:
            self.optimizedTrackingEnabled = YES;
            self.userDefaultsBackupInterval = 600.0;   // 10 minutes
            self.coreDataFlushInterval = 3600.0;       // 1 hour
            self.maxBatchSize = 1000;
            self.chunkSize = 100;
            break;
            
        case TrackingPresetModePerformance:
            self.optimizedTrackingEnabled = YES;
            self.userDefaultsBackupInterval = 1800.0;  // 30 minutes
            self.coreDataFlushInterval = 14400.0;      // 4 hours
            self.maxBatchSize = 2000;
            self.chunkSize = 200;
            break;
            
        case TrackingPresetModeMinimal:
            self.optimizedTrackingEnabled = YES;
            self.userDefaultsBackupInterval = 3600.0;  // 1 hour
            self.coreDataFlushInterval = 0.0;          // Only on app terminate
            self.maxBatchSize = 5000;
            self.chunkSize = 500;
            break;
    }
    
    // Always enable these for data safety
    self.flushOnAppBackground = YES;
    self.flushOnAppTerminate = YES;
    
    NSLog(@"🎯 Applied tracking preset: %@", [self nameForPreset:preset]);
}

- (TrackingPresetMode)getCurrentPresetMode {
    // Check if current settings match any preset
    if (!self.optimizedTrackingEnabled &&
        self.userDefaultsBackupInterval == 60.0 &&
        self.coreDataFlushInterval == 300.0) {
        return TrackingPresetModeRealTime;
    }
    
    if (self.optimizedTrackingEnabled &&
        self.userDefaultsBackupInterval == 600.0 &&
        self.coreDataFlushInterval == 3600.0 &&
        self.maxBatchSize == 1000) {
        return TrackingPresetModeBalanced;
    }
    
    if (self.optimizedTrackingEnabled &&
        self.userDefaultsBackupInterval == 1800.0 &&
        self.coreDataFlushInterval == 14400.0 &&
        self.maxBatchSize == 2000) {
        return TrackingPresetModePerformance;
    }
    
    if (self.optimizedTrackingEnabled &&
        self.userDefaultsBackupInterval == 3600.0 &&
        self.coreDataFlushInterval == 0.0 &&
        self.maxBatchSize == 5000) {
        return TrackingPresetModeMinimal;
    }
    
    return -1; // Custom settings
}

- (NSString *)nameForPreset:(TrackingPresetMode)preset {
    switch (preset) {
        case TrackingPresetModeRealTime: return @"Real-time";
        case TrackingPresetModeBalanced: return @"Balanced";
        case TrackingPresetModePerformance: return @"Performance";
        case TrackingPresetModeMinimal: return @"Minimal";
        default: return @"Custom";
    }
}

#pragma mark - Configuration Methods

- (void)loadTrackingConfiguration {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load with fallback to defaults
    self.optimizedTrackingEnabled = [defaults objectForKey:kTrackingOptimizedEnabledKey]
        ? [defaults boolForKey:kTrackingOptimizedEnabledKey] : YES;
    
    self.userDefaultsBackupInterval = [defaults objectForKey:kTrackingUserDefaultsIntervalKey]
        ? [defaults doubleForKey:kTrackingUserDefaultsIntervalKey] : kDefaultUserDefaultsInterval;
    
    self.coreDataFlushInterval = [defaults objectForKey:kTrackingCoreDataIntervalKey]
        ? [defaults doubleForKey:kTrackingCoreDataIntervalKey] : kDefaultCoreDataInterval;
    
    self.maxBatchSize = [defaults objectForKey:kTrackingMaxBatchSizeKey]
        ? [defaults integerForKey:kTrackingMaxBatchSizeKey] : kDefaultMaxBatchSize;
    
    self.chunkSize = [defaults objectForKey:kTrackingChunkSizeKey]
        ? [defaults integerForKey:kTrackingChunkSizeKey] : kDefaultChunkSize;
    
    self.flushOnAppBackground = [defaults objectForKey:kTrackingFlushOnBackgroundKey]
        ? [defaults boolForKey:kTrackingFlushOnBackgroundKey] : YES;
    
    self.flushOnAppTerminate = [defaults objectForKey:kTrackingFlushOnTerminateKey]
        ? [defaults boolForKey:kTrackingFlushOnTerminateKey] : YES;
    
    // Validate loaded configuration
    [self validateTrackingConfiguration];
    
    NSLog(@"📱 Loaded tracking configuration: %@", [self getTrackingConfigurationDescription]);
}

- (void)saveTrackingConfiguration {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setBool:self.optimizedTrackingEnabled forKey:kTrackingOptimizedEnabledKey];
    [defaults setDouble:self.userDefaultsBackupInterval forKey:kTrackingUserDefaultsIntervalKey];
    [defaults setDouble:self.coreDataFlushInterval forKey:kTrackingCoreDataIntervalKey];
    [defaults setInteger:self.maxBatchSize forKey:kTrackingMaxBatchSizeKey];
    [defaults setInteger:self.chunkSize forKey:kTrackingChunkSizeKey];
    [defaults setBool:self.flushOnAppBackground forKey:kTrackingFlushOnBackgroundKey];
    [defaults setBool:self.flushOnAppTerminate forKey:kTrackingFlushOnTerminateKey];
    [defaults setObject:[NSDate date] forKey:kTrackingLastConfigSaveKey];
    
    [defaults synchronize];
    
    NSLog(@"💾 Saved tracking configuration: %@", [self getTrackingConfigurationDescription]);
}

- (void)resetTrackingConfigurationToDefaults {
    self.optimizedTrackingEnabled = YES;
    self.userDefaultsBackupInterval = kDefaultUserDefaultsInterval;
    self.coreDataFlushInterval = kDefaultCoreDataInterval;
    self.maxBatchSize = kDefaultMaxBatchSize;
    self.chunkSize = kDefaultChunkSize;
    self.flushOnAppBackground = YES;
    self.flushOnAppTerminate = YES;
    
    [self saveTrackingConfiguration];
    
    NSLog(@"🔄 Reset tracking configuration to defaults");
}

- (void)applyTrackingConfiguration {
    [self saveTrackingConfiguration];
    
    // ✅ NEW: Restart optimized tracking system with new configuration
    [self restartOptimizedTrackingWithNewConfiguration];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TrackingConfigurationChanged"
                                                        object:self
                                                      userInfo:@{
                                                          @"configuration": [self getTrackingStatistics]
                                                      }];
    
    NSLog(@"✅ Applied tracking configuration changes");
}


#pragma mark - Validation

- (BOOL)validateTrackingConfiguration {
    BOOL needsCorrection = NO;
    
    // Validate UserDefaults interval (1 minute to 24 hours)
    if (self.userDefaultsBackupInterval < 60.0) {
        self.userDefaultsBackupInterval = 60.0;
        needsCorrection = YES;
    } else if (self.userDefaultsBackupInterval > 86400.0) {
        self.userDefaultsBackupInterval = 86400.0;
        needsCorrection = YES;
    }
    
    // Validate Core Data interval (5 minutes to 7 days, or 0 for app-terminate-only)
    if (self.coreDataFlushInterval > 0.0 && self.coreDataFlushInterval < 300.0) {
        self.coreDataFlushInterval = 300.0;
        needsCorrection = YES;
    } else if (self.coreDataFlushInterval > 604800.0) {
        self.coreDataFlushInterval = 604800.0;
        needsCorrection = YES;
    }
    
    // Validate batch sizes
    if (self.maxBatchSize < 10) {
        self.maxBatchSize = 10;
        needsCorrection = YES;
    } else if (self.maxBatchSize > 10000) {
        self.maxBatchSize = 10000;
        needsCorrection = YES;
    }
    
    if (self.chunkSize < 5) {
        self.chunkSize = 5;
        needsCorrection = YES;
    } else if (self.chunkSize > self.maxBatchSize) {
        self.chunkSize = self.maxBatchSize / 2;
        needsCorrection = YES;
    }
    
    // UserDefaults should be more frequent than Core Data
    if (self.coreDataFlushInterval > 0.0 && self.userDefaultsBackupInterval >= self.coreDataFlushInterval) {
        self.userDefaultsBackupInterval = self.coreDataFlushInterval / 4;
        needsCorrection = YES;
    }
    
    if (needsCorrection) {
        NSLog(@"⚠️ Tracking configuration corrected during validation");
    }
    
    return !needsCorrection;
}

- (NSString *)getTrackingConfigurationDescription {
    NSMutableString *description = [NSMutableString string];
    
    [description appendFormat:@"Optimized: %@", self.optimizedTrackingEnabled ? @"YES" : @"NO"];
    [description appendFormat:@", UserDefaults: %.0fm", self.userDefaultsBackupInterval / 60.0];
    
    if (self.coreDataFlushInterval > 0.0) {
        [description appendFormat:@", Core Data: %.0fm", self.coreDataFlushInterval / 60.0];
    } else {
        [description appendString:@", Core Data: app-close"];
    }
    
    [description appendFormat:@", Batch: %ld/%ld", (long)self.chunkSize, (long)self.maxBatchSize];
    
    TrackingPresetMode preset = [self getCurrentPresetMode];
    if (preset != -1) {
        [description appendFormat:@" [%@]", [self nameForPreset:preset]];
    } else {
        [description appendString:@" [Custom]"];
    }
    
    return [description copy];
}

#pragma mark - Statistics and Monitoring

- (NSDictionary *)getTrackingStatistics {
    return @{
        @"optimizedTrackingEnabled": @(self.optimizedTrackingEnabled),
        @"userDefaultsBackupInterval": @(self.userDefaultsBackupInterval),
        @"coreDataFlushInterval": @(self.coreDataFlushInterval),
        @"maxBatchSize": @(self.maxBatchSize),
        @"chunkSize": @(self.chunkSize),
        @"flushOnAppBackground": @(self.flushOnAppBackground),
        @"flushOnAppTerminate": @(self.flushOnAppTerminate),
        @"currentPreset": [self nameForPreset:[self getCurrentPresetMode]],
        @"configurationDescription": [self getTrackingConfigurationDescription],
        @"lastConfigSave": [[NSUserDefaults standardUserDefaults] objectForKey:kTrackingLastConfigSaveKey]
    };
}

- (NSDictionary *)getNextScheduledOperations {
    if ([self isOptimizedTrackingActive]) {
        return [self getLastOperationTimestamps];
    } else {
        // Fallback to estimated times
        NSDate *now = [NSDate date];
        return @{
            @"nextUserDefaultsBackup": [NSNull null],
            @"nextCoreDataFlush": [NSNull null],
            @"estimatedOnly": @YES,
            @"optimizedTrackingActive": @NO
        };
    }
}


- (void)forceUserDefaultsBackup {
    if ([self isOptimizedTrackingActive]) {
        [self performImmediateUserDefaultsBackup];
    } else {
        NSLog(@"⚠️ Optimized tracking not active - no UserDefaults backup needed");
    }
}

- (void)forceCoreDataFlushWithCompletion:(void(^)(BOOL success))completion {
    if ([self isOptimizedTrackingActive]) {
        [self performImmediateCoreDataFlush:completion];
    } else {
        NSLog(@"⚠️ Optimized tracking not active - no Core Data flush needed");
        if (completion) completion(YES);
    }
}

@end
