
//
//  IBKRTestWidget.m
//  TradingApp
//

#import "IBKRTestWidget.h"
#import "DownloadManager.h"
#import "CommonTypes.h"

@interface IBKRTestWidget ()
@property (nonatomic, strong) IBKRConfiguration *config;
@end

@implementation IBKRTestWidget

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.config = [IBKRConfiguration sharedConfiguration];
        [self setupUI];
        [self updateUI];
    }
    return self;
}

- (void)setupUI {
    // Status section
    NSTextField *statusTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, self.bounds.size.height - 40, 200, 20)];
    statusTitle.stringValue = @"IBKR Connection Status:";
    statusTitle.bezeled = NO;
    statusTitle.editable = NO;
    statusTitle.backgroundColor = [NSColor clearColor];
    statusTitle.font = [NSFont boldSystemFontOfSize:12];
    [self addSubview:statusTitle];
    
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, self.bounds.size.height - 65, 300, 20)];
    self.statusLabel.bezeled = NO;
    self.statusLabel.editable = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    [self addSubview:self.statusLabel];
    
    // Configuration section
    NSTextField *configTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, self.bounds.size.height - 100, 200, 20)];
    configTitle.stringValue = @"Configuration:";
    configTitle.bezeled = NO;
    configTitle.editable = NO;
    configTitle.backgroundColor = [NSColor clearColor];
    configTitle.font = [NSFont boldSystemFontOfSize:12];
    [self addSubview:configTitle];
    
    self.configLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, self.bounds.size.height - 125, 400, 20)];
    self.configLabel.bezeled = NO;
    self.configLabel.editable = NO;
    self.configLabel.backgroundColor = [NSColor clearColor];
    [self addSubview:self.configLabel];
    
    // Configuration preset buttons
    self.twsPresetButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, self.bounds.size.height - 155, 100, 25)];
    [self.twsPresetButton setTitle:@"TWS Preset"];
    [self.twsPresetButton setTarget:self];
    [self.twsPresetButton setAction:@selector(twsPresetButtonClicked:)];
    [self addSubview:self.twsPresetButton];
    
    self.gatewayPresetButton = [[NSButton alloc] initWithFrame:NSMakeRect(130, self.bounds.size.height - 155, 120, 25)];
    [self.gatewayPresetButton setTitle:@"Gateway Preset"];
    [self.gatewayPresetButton setTarget:self];
    [self.gatewayPresetButton setAction:@selector(gatewayPresetButtonClicked:)];
    [self addSubview:self.gatewayPresetButton];
    
    // Action buttons
    self.connectButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, self.bounds.size.height - 195, 100, 30)];
    [self.connectButton setTitle:@"Connect"];
    [self.connectButton setTarget:self];
    [self.connectButton setAction:@selector(connectButtonClicked:)];
    [self addSubview:self.connectButton];
    
    self.testQuoteButton = [[NSButton alloc] initWithFrame:NSMakeRect(130, self.bounds.size.height - 195, 100, 30)];
    [self.testQuoteButton setTitle:@"Test Quote"];
    [self.testQuoteButton setTarget:self];
    [self.testQuoteButton setAction:@selector(testQuoteButtonClicked:)];
    [self addSubview:self.testQuoteButton];
    
    self.testHistoricalButton = [[NSButton alloc] initWithFrame:NSMakeRect(240, self.bounds.size.height - 195, 120, 30)];
    [self.testHistoricalButton setTitle:@"Test Historical"];
    [self.testHistoricalButton setTarget:self];
    [self.testHistoricalButton setAction:@selector(testHistoricalButtonClicked:)];
    [self addSubview:self.testHistoricalButton];
    
    self.testAccountsButton = [[NSButton alloc] initWithFrame:NSMakeRect(370, self.bounds.size.height - 195, 120, 30)];
    [self.testAccountsButton setTitle:@"Test Accounts"];
    [self.testAccountsButton setTarget:self];
    [self.testAccountsButton setAction:@selector(testAccountsButtonClicked:)];
    [self addSubview:self.testAccountsButton];
    
    // Results section
    NSTextField *resultsTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, self.bounds.size.height - 235, 200, 20)];
    resultsTitle.stringValue = @"Test Results:";
    resultsTitle.bezeled = NO;
    resultsTitle.editable = NO;
    resultsTitle.backgroundColor = [NSColor clearColor];
    resultsTitle.font = [NSFont boldSystemFontOfSize:12];
    [self addSubview:resultsTitle];
    
    // Results text view with scroll view
    NSRect resultsFrame = NSMakeRect(20, 20, self.bounds.size.width - 40, self.bounds.size.height - 270);
    self.resultsScrollView = [[NSScrollView alloc] initWithFrame:resultsFrame];
    self.resultsScrollView.hasVerticalScroller = YES;
    self.resultsScrollView.autohidesScrollers = NO;
    self.resultsScrollView.borderType = NSBezelBorder;
    
    self.resultsTextView = [[NSTextView alloc] init];
    self.resultsTextView.editable = NO;
    self.resultsTextView.font = [NSFont fontWithName:@"Monaco" size:11];
    self.resultsTextView.string = @"Ready for IBKR testing...\n";
    
    self.resultsScrollView.documentView = self.resultsTextView;
    [self addSubview:self.resultsScrollView];
}

#pragma mark - Actions

- (void)connectButtonClicked:(id)sender {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    BOOL isConnected = [downloadManager isDataSourceConnected:DataSourceTypeIBKR];
    
    if (isConnected) {
        // Disconnect
        [self appendResult:@"Disconnecting from IBKR..."];
        [downloadManager disconnectDataSource:DataSourceTypeIBKR];
        [self updateUI];
        [self appendResult:@"Disconnected from IBKR"];
    } else {
        // Connect
        [self appendResult:[NSString stringWithFormat:@"Connecting to IBKR at %@...", [self.config connectionURLString]]];
        
        [downloadManager connectDataSource:DataSourceTypeIBKR completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateUI];
                if (success) {
                    [self appendResult:@"✅ Successfully connected to IBKR"];
                } else {
                    [self appendResult:[NSString stringWithFormat:@"❌ Failed to connect to IBKR: %@", error.localizedDescription]];
                }
            });
        }];
    }
}

- (void)testQuoteButtonClicked:(id)sender {
    [self appendResult:@"Testing quote request for AAPL..."];
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    [downloadManager executeRequest:DataRequestTypeQuote
                         parameters:@{@"symbol": @"AAPL"}
                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self appendResult:[NSString stringWithFormat:@"❌ Quote test failed: %@", error.localizedDescription]];
            } else {
                NSString *sourceStr = (usedSource == DataSourceTypeIBKR) ? @"IBKR" : @"Other";
                [self appendResult:[NSString stringWithFormat:@"✅ Quote test successful (source: %@): %@", sourceStr, result]];
            }
        });
    }];
}

- (void)testHistoricalButtonClicked:(id)sender {
    [self appendResult:@"Testing historical data request for AAPL..."];
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    [downloadManager executeRequest:DataRequestTypeHistoricalBars
                         parameters:@{
                             @"symbol": @"AAPL",
                             @"timeframe": @(BarTimeframe1Day),
                             @"startDate": [[NSDate date] dateByAddingTimeInterval:-30*24*3600],
                             @"endDate": [NSDate date]
                         }
                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self appendResult:[NSString stringWithFormat:@"❌ Historical test failed: %@", error.localizedDescription]];
            } else {
                NSString *sourceStr = (usedSource == DataSourceTypeIBKR) ? @"IBKR" : @"Other";
                NSInteger barCount = [result isKindOfClass:[NSArray class]] ? [(NSArray *)result count] : 0;
                [self appendResult:[NSString stringWithFormat:@"✅ Historical test successful (source: %@): %ld bars", sourceStr, (long)barCount]];
            }
        });
    }];
}

- (void)testAccountsButtonClicked:(id)sender {
    [self appendResult:@"Testing account information request..."];
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    [downloadManager executeRequest:DataRequestTypeAccountInfo
                         parameters:@{}
                         completion:^(id result, DataSourceType usedSource, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self appendResult:[NSString stringWithFormat:@"❌ Account test failed: %@", error.localizedDescription]];
            } else {
                NSString *sourceStr = (usedSource == DataSourceTypeIBKR) ? @"IBKR" : @"Other";
                [self appendResult:[NSString stringWithFormat:@"✅ Account test successful (source: %@): %@", sourceStr, result]];
            }
        });
    }];
}

- (void)twsPresetButtonClicked:(id)sender {
    [self.config loadTWSPreset];
    [self.config saveToUserDefaults];
    [self updateUI];
    [self appendResult:@"📋 Loaded TWS preset configuration"];
}

- (void)gatewayPresetButtonClicked:(id)sender {
    [self.config loadGatewayPreset];
    [self.config saveToUserDefaults];
    [self updateUI];
    [self appendResult:@"📋 Loaded IB Gateway preset configuration"];
}

#pragma mark - Helper Methods

- (void)updateUI {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    BOOL isConnected = [downloadManager isDataSourceConnected:DataSourceTypeIBKR];
    
    // Update status
    if (isConnected) {
        self.statusLabel.stringValue = @"✅ Connected to IBKR";
        self.statusLabel.textColor = [NSColor systemGreenColor];
        [self.connectButton setTitle:@"Disconnect"];
    } else {
        self.statusLabel.stringValue = @"❌ Not connected to IBKR";
        self.statusLabel.textColor = [NSColor systemRedColor];
        [self.connectButton setTitle:@"Connect"];
    }
    
    // Update configuration
    self.configLabel.stringValue = [self.config connectionURLString];
    
    // Enable/disable test buttons based on connection status
    self.testQuoteButton.enabled = isConnected;
    self.testHistoricalButton.enabled = isConnected;
    self.testAccountsButton.enabled = isConnected;
}

- (void)appendResult:(NSString *)result {
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                         dateStyle:NSDateFormatterNoStyle
                                                         timeStyle:NSDateFormatterMediumStyle];
    NSString *logEntry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, result];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentText = self.resultsTextView.string;
        NSString *newText = [currentText stringByAppendingString:logEntry];
        self.resultsTextView.string = newText;
        
        // Scroll to bottom
        NSRange range = NSMakeRange(newText.length, 0);
        [self.resultsTextView scrollRangeToVisible:range];
    });
}

- (void)clearResults {
    self.resultsTextView.string = @"Results cleared.\n";
}

#pragma mark - BaseWidget Override

- (NSString *)widgetTitle {
    return @"IBKR Test";
}

@end
