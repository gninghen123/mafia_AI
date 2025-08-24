
//
//  IBKRConfiguration.m
//  TradingApp
//

#import "IBKRConfiguration.h"

// UserDefaults keys
static NSString *const kIBKRHost = @"IBKR.Host";
static NSString *const kIBKRPort = @"IBKR.Port";
static NSString *const kIBKRClientId = @"IBKR.ClientId";
static NSString *const kIBKRConnectionType = @"IBKR.ConnectionType";
static NSString *const kIBKRAutoConnect = @"IBKR.AutoConnect";
static NSString *const kIBKRAutoRetry = @"IBKR.AutoRetry";
static NSString *const kIBKRDebugLogging = @"IBKR.DebugLogging";

// Default values
static NSString *const kDefaultHost = @"127.0.0.1";
static NSInteger const kDefaultTWSPort = 7497;
static NSInteger const kDefaultGatewayPort = 4002;
static NSInteger const kDefaultClientId = 1;

@implementation IBKRConfiguration

#pragma mark - Singleton

+ (instancetype)sharedConfiguration {
    static IBKRConfiguration *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self resetToDefaults];
        [self loadFromUserDefaults];
    }
    return self;
}

#pragma mark - Presets

- (void)loadTWSPreset {
    self.host = kDefaultHost;
    self.port = kDefaultTWSPort;
    self.connectionType = IBKRConnectionTypeTWS;
    self.clientId = kDefaultClientId;
    
    NSLog(@"🏭 IBKRConfiguration: Created IBKRDataSource with configuration: %@", [self connectionURLString]);
    
    return dataSource;
}



- (void)loadGatewayPreset {
    self.host = kDefaultHost;
    self.port = kDefaultGatewayPort;
    self.connectionType = IBKRConnectionTypeGateway;
    self.clientId = kDefaultClientId;
    
    NSLog(@"📋 IBKRConfiguration: Loaded Gateway preset (%@:%ld)", self.host, (long)self.port);
}

- (void)loadPaperTradingPreset {
    self.host = kDefaultHost;
    self.port = kDefaultTWSPort;  // Paper trading typically uses TWS
    self.connectionType = IBKRConnectionTypeTWS;
    self.clientId = kDefaultClientId;
    
    NSLog(@"📋 IBKRConfiguration: Loaded Paper Trading preset");
}

#pragma mark - Persistence

- (void)loadFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *savedHost = [defaults stringForKey:kIBKRHost];
    if (savedHost.length > 0) {
        self.host = savedHost;
    }
    
    NSInteger savedPort = [defaults integerForKey:kIBKRPort];
    if (savedPort > 0) {
        self.port = savedPort;
    }
    
    NSInteger savedClientId = [defaults integerForKey:kIBKRClientId];
    if (savedClientId > 0) {
        self.clientId = savedClientId;
    }
    
    self.connectionType = [defaults integerForKey:kIBKRConnectionType];
    self.autoConnectEnabled = [defaults boolForKey:kIBKRAutoConnect];
    self.autoRetryEnabled = [defaults boolForKey:kIBKRAutoRetry];
    self.debugLoggingEnabled = [defaults boolForKey:kIBKRDebugLogging];
    
    NSLog(@"📋 IBKRConfiguration: Loaded from UserDefaults - %@:%ld (clientId: %ld)",
          self.host, (long)self.port, (long)self.clientId);
}

- (void)saveToUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:self.host forKey:kIBKRHost];
    [defaults setInteger:self.port forKey:kIBKRPort];
    [defaults setInteger:self.clientId forKey:kIBKRClientId];
    [defaults setInteger:self.connectionType forKey:kIBKRConnectionType];
    [defaults setBool:self.autoConnectEnabled forKey:kIBKRAutoConnect];
    [defaults setBool:self.autoRetryEnabled forKey:kIBKRAutoRetry];
    [defaults setBool:self.debugLoggingEnabled forKey:kIBKRDebugLogging];
    
    [defaults synchronize];
    
    NSLog(@"💾 IBKRConfiguration: Saved to UserDefaults");
}

- (void)resetToDefaults {
    self.host = kDefaultHost;
    self.port = kDefaultTWSPort;
    self.clientId = kDefaultClientId;
    self.connectionType = IBKRConnectionTypeTWS;
    self.autoConnectEnabled = NO;  // Default to disabled for safety
    self.autoRetryEnabled = NO;
    self.debugLoggingEnabled = NO;
    
    NSLog(@"🔄 IBKRConfiguration: Reset to defaults");
}

#pragma mark - Validation

- (BOOL)isConfigurationValid:(NSError **)error {
    // Validate host
    if (!self.host || self.host.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"IBKRConfiguration"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Host cannot be empty"}];
        }
        return NO;
    }
    
    // Validate port range
    if (self.port < 1 || self.port > 65535) {
        if (error) {
            *error = [NSError errorWithDomain:@"IBKRConfiguration"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Port must be between 1 and 65535"}];
        }
        return NO;
    }
    
    // Validate client ID
    if (self.clientId < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"IBKRConfiguration"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Client ID must be non-negative"}];
        }
        return NO;
    }
    
    // Warn about common port configurations
    if (self.port != kDefaultTWSPort && self.port != kDefaultGatewayPort) {
        NSLog(@"⚠️ IBKRConfiguration: Using non-standard port %ld (TWS: %ld, Gateway: %ld)",
              (long)self.port, (long)kDefaultTWSPort, (long)kDefaultGatewayPort);
    }
    
    return YES;
}

- (NSString *)connectionURLString {
    return [NSString stringWithFormat:@"%@:%ld (clientId: %ld, type: %@)",
            self.host,
            (long)self.port,
            (long)self.clientId,
            self.connectionType == IBKRConnectionTypeTWS ? @"TWS" : @"Gateway"];
}

#pragma mark - Factory Methods

- (IBKRDataSource *)createDataSource {
    IBKRDataSource *dataSource = [[IBKRDataSource alloc] initWithHost:self.host
                                                                 port:self.port
                                                             clientId:self.clientId
                                                       connectionType:self.connectionType];
    
    dataSource.debugLogging = self.debugLoggingEnabled;
    
    NSLog(@"
