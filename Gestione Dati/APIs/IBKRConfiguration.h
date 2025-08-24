//
//  IBKRConfiguration.h
//  TradingApp
//
//  Configuration helper for Interactive Brokers connection settings
//

#import <Foundation/Foundation.h>
#import "IBKRDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface IBKRConfiguration : NSObject

#pragma mark - Singleton

+ (instancetype)sharedConfiguration;

#pragma mark - Connection Settings

/// Host for TWS/IB Gateway connection
@property (nonatomic, strong) NSString *host;

/// Port for TWS/IB Gateway connection
@property (nonatomic, assign) NSInteger port;

/// Client ID for IBKR connection
@property (nonatomic, assign) NSInteger clientId;

/// Connection type (TWS or Gateway)
@property (nonatomic, assign) IBKRConnectionType connectionType;

/// Auto-connect enabled
@property (nonatomic, assign) BOOL autoConnectEnabled;

/// Auto-retry enabled
@property (nonatomic, assign) BOOL autoRetryEnabled;

/// Debug logging enabled
@property (nonatomic, assign) BOOL debugLoggingEnabled;

#pragma mark - Presets

/// Load TWS preset (port 7497)
- (void)loadTWSPreset;

/// Load IB Gateway preset (port 4002)
- (void)loadGatewayPreset;

/// Load paper trading preset
- (void)loadPaperTradingPreset;

#pragma mark - Persistence

/// Load configuration from NSUserDefaults
- (void)loadFromUserDefaults;

/// Save configuration to NSUserDefaults
- (void)saveToUserDefaults;

/// Reset to default values
- (void)resetToDefaults;

#pragma mark - Validation

/// Validate current configuration
- (BOOL)isConfigurationValid:(NSError **)error;

/// Get connection URL string
- (NSString *)connectionURLString;

#pragma mark - Factory Methods

/// Create IBKRDataSource with current configuration
- (IBKRDataSource *)createDataSource;

@end

NS_ASSUME_NONNULL_END
