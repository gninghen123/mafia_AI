//
//  DataHub+TrackingPreferences.h
//  Performance tracking configuration and preferences management
//

#import "DataHub.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TrackingPresetMode) {
    TrackingPresetModeRealTime,      // Every interaction saved immediately
    TrackingPresetModeBalanced,      // Default: 10min UserDefaults, 1h Core Data
    TrackingPresetModePerformance,   // 30min UserDefaults, 4h Core Data
    TrackingPresetModeMinimal        // 60min UserDefaults, app close only Core Data
};

@interface DataHub (TrackingPreferences)

#pragma mark - Configuration Properties

/// Enable/disable optimized tracking system
@property (nonatomic, assign) BOOL optimizedTrackingEnabled;

/// UserDefaults backup interval in seconds (default: 600 = 10 minutes)
@property (nonatomic, assign) NSTimeInterval userDefaultsBackupInterval;

/// Core Data flush interval in seconds (default: 3600 = 1 hour)
@property (nonatomic, assign) NSTimeInterval coreDataFlushInterval;

/// Maximum symbols to process in one batch (default: 1000)
@property (nonatomic, assign) NSInteger maxBatchSize;

/// Chunk size for background processing (default: 100)
@property (nonatomic, assign) NSInteger chunkSize;

/// Force Core Data flush when app goes to background
@property (nonatomic, assign) BOOL flushOnAppBackground;

/// Force Core Data flush when app terminates
@property (nonatomic, assign) BOOL flushOnAppTerminate;

#pragma mark - Preset Management

/// Apply a preset configuration
/// @param preset The preset mode to apply
- (void)applyTrackingPreset:(TrackingPresetMode)preset;

/// Get current preset mode (or TrackingPresetModeCustom if custom settings)
- (TrackingPresetMode)getCurrentPresetMode;

#pragma mark - Configuration Methods

/// Load tracking configuration from NSUserDefaults
- (void)loadTrackingConfiguration;

/// Save current tracking configuration to NSUserDefaults
- (void)saveTrackingConfiguration;

/// Reset all tracking settings to default values
- (void)resetTrackingConfigurationToDefaults;

/// Apply configuration changes and restart timers
- (void)applyTrackingConfiguration;

#pragma mark - Validation

/// Validate configuration values and fix if needed
/// @return YES if configuration was valid, NO if corrections were made
- (BOOL)validateTrackingConfiguration;

/// Get human-readable description of current configuration
- (NSString *)getTrackingConfigurationDescription;

#pragma mark - Statistics and Monitoring

/// Get current tracking statistics
- (NSDictionary *)getTrackingStatistics;

/// Get next scheduled backup/flush times
- (NSDictionary *)getNextScheduledOperations;

/// Force immediate UserDefaults backup
- (void)forceUserDefaultsBackup;

/// Force immediate Core Data flush
- (void)forceCoreDataFlushWithCompletion:(void(^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
