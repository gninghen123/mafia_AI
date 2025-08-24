
//
//  IBKRTestWidget.m
//  TradingApp
//

#import "IBKRTestWidget.h"
#import "DownloadManager.h"
#import "CommonTypes.h"
#import "IBKRDataSource.h"

@implementation IBKRTestWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.config = [IBKRConfiguration sharedConfiguration];
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    [self setupUI];
    [self updateUI];
}

- (void)setupUI {
    NSView *container = self.contentView;
    
    NSStackView *mainStackView = [[NSStackView alloc] init];
    mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
    mainStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStackView.spacing = 10;
    mainStackView.alignment = NSLayoutAttributeLeading;
    mainStackView.distribution = NSStackViewDistributionFill;
    [container addSubview:mainStackView];
    
    // Status section
    NSTextField *statusTitle = [self createLabelWithText:@"IBKR Connection Status:" bold:YES];
    [mainStackView addArrangedSubview:statusTitle];
    
    self.statusLabel = [self createLabelWithText:@"Not connected" bold:NO];
    [mainStackView addArrangedSubview:self.statusLabel];
    
    // Configuration section
    NSTextField *configTitle = [self createLabelWithText:@"Configuration:" bold:YES];
    [mainStackView addArrangedSubview:configTitle];
    
    self.configLabel = [self createLabelWithText:@"Loading configuration..." bold:NO];
    [mainStackView addArrangedSubview:self.configLabel];
    
    // Configuration preset buttons
    NSView *presetButtonsView = [[NSView alloc] init];
    presetButtonsView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.twsPresetButton = [self createButtonWithTitle:@"TWS Preset" action:@selector(twsPresetButtonClicked:)];
    self.gatewayPresetButton = [self createButtonWithTitle:@"Gateway Preset" action:@selector(gatewayPresetButtonClicked:)];
    
    [presetButtonsView addSubview:self.twsPresetButton];
    [presetButtonsView addSubview:self.gatewayPresetButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.twsPresetButton.leadingAnchor constraintEqualToAnchor:presetButtonsView.leadingAnchor],
        [self.twsPresetButton.topAnchor constraintEqualToAnchor:presetButtonsView.topAnchor],
        [self.twsPresetButton.widthAnchor constraintEqualToConstant:100],
        [self.twsPresetButton.heightAnchor constraintEqualToConstant:25],
        
        [self.gatewayPresetButton.leadingAnchor constraintEqualToAnchor:self.twsPresetButton.trailingAnchor constant:10],
        [self.gatewayPresetButton.topAnchor constraintEqualToAnchor:presetButtonsView.topAnchor],
        [self.gatewayPresetButton.widthAnchor constraintEqualToConstant:120],
        [self.gatewayPresetButton.heightAnchor constraintEqualToConstant:25],
        
        [presetButtonsView.trailingAnchor constraintGreaterThanOrEqualToAnchor:self.gatewayPresetButton.trailingAnchor],
        [presetButtonsView.bottomAnchor constraintEqualToAnchor:self.gatewayPresetButton.bottomAnchor],
        [presetButtonsView.heightAnchor constraintEqualToConstant:25]
    ]];
    
    [mainStackView addArrangedSubview:presetButtonsView];
    
    // Action buttons
    NSView *actionButtonsView = [[NSView alloc] init];
    actionButtonsView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.connectButton = [self createButtonWithTitle:@"Connect" action:@selector(connectButtonClicked:)];
    self.testQuoteButton = [self createButtonWithTitle:@"Test Quote" action:@selector(testQuoteButtonClicked:)];
    self.testHistoricalButton = [self createButtonWithTitle:@"Test Historical" action:@selector(testHistoricalButtonClicked:)];
    self.testAccountsButton = [self createButtonWithTitle:@"Test Accounts" action:@selector(testAccountsButtonClicked:)];
    self.testAllSourcesButton = [self createButtonWithTitle:@"Test All Sources" action:@selector(testAllSourcesButtonClicked:)];
    
    [actionButtonsView addSubview:self.connectButton];
    [actionButtonsView addSubview:self.testQuoteButton];
    [actionButtonsView addSubview:self.testHistoricalButton];
    [actionButtonsView addSubview:self.testAccountsButton];
    [actionButtonsView addSubview:self.testAllSourcesButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.connectButton.leadingAnchor constraintEqualToAnchor:actionButtonsView.leadingAnchor],
        [self.connectButton.topAnchor constraintEqualToAnchor:actionButtonsView.topAnchor],
        [self.connectButton.widthAnchor constraintEqualToConstant:80],
        [self.connectButton.heightAnchor constraintEqualToConstant:30],
        
        [self.testQuoteButton.leadingAnchor constraintEqualToAnchor:self.connectButton.trailingAnchor constant:5],
        [self.testQuoteButton.topAnchor constraintEqualToAnchor:actionButtonsView.topAnchor],
        [self.testQuoteButton.widthAnchor constraintEqualToConstant:80],
        [self.testQuoteButton.heightAnchor constraintEqualToConstant:30],
        
        [self.testHistoricalButton.leadingAnchor constraintEqualToAnchor:self.testQuoteButton.trailingAnchor constant:5],
        [self.testHistoricalButton.topAnchor constraintEqualToAnchor:actionButtonsView.topAnchor],
        [self.testHistoricalButton.widthAnchor constraintEqualToConstant:90],
        [self.testHistoricalButton.heightAnchor constraintEqualToConstant:30],
        
        [self.testAccountsButton.leadingAnchor constraintEqualToAnchor:self.testHistoricalButton.trailingAnchor constant:5],
        [self.testAccountsButton.topAnchor constraintEqualToAnchor:actionButtonsView.topAnchor],
        [self.testAccountsButton.widthAnchor constraintEqualToConstant:90],
        [self.testAccountsButton.heightAnchor constraintEqualToConstant:30],
        
        [self.testAllSourcesButton.leadingAnchor constraintEqualToAnchor:self.testAccountsButton.trailingAnchor constant:5],
        [self.testAllSourcesButton.topAnchor constraintEqualToAnchor:actionButtonsView.topAnchor],
        [self.testAllSourcesButton.widthAnchor constraintEqualToConstant:100],
        [self.testAllSourcesButton.heightAnchor constraintEqualToConstant:30],
        
        [actionButtonsView.trailingAnchor constraintGreaterThanOrEqualToAnchor:self.testAllSourcesButton.trailingAnchor],
        [actionButtonsView.bottomAnchor constraintEqualToAnchor:self.testAllSourcesButton.bottomAnchor],
        [actionButtonsView.heightAnchor constraintEqualToConstant:30]
    ]];
    
    [mainStackView addArrangedSubview:actionButtonsView];
    
    // Results section
    NSTextField *resultsTitle = [self createLabelWithText:@"Test Results:" bold:YES];
    [mainStackView addArrangedSubview:resultsTitle];
    
    // ScrollView + TextView standard setup
    self.resultsScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.resultsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultsScrollView.hasVerticalScroller = YES;
    self.resultsScrollView.hasHorizontalScroller = NO;
    self.resultsScrollView.autohidesScrollers = YES;
    self.resultsScrollView.borderType = NSBezelBorder;

    self.resultsTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];
    self.resultsTextView.minSize = NSMakeSize(0, 0);
    self.resultsTextView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    self.resultsTextView.verticallyResizable = YES;
    self.resultsTextView.horizontallyResizable = NO;
    self.resultsTextView.autoresizingMask = NSViewWidthSizable;
    self.resultsTextView.editable = NO;
    self.resultsTextView.font = [NSFont fontWithName:@"Monaco" size:11];
    self.resultsTextView.string = @"Ready for IBKR testing...\n";
    self.resultsTextView.textContainer.widthTracksTextView = YES;
    self.resultsTextView.backgroundColor = [NSColor textBackgroundColor];

    self.resultsScrollView.documentView = self.resultsTextView;
    self.resultsScrollView.contentView.documentView = self.resultsTextView;
    [mainStackView addArrangedSubview:self.resultsScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStackView.topAnchor constraintEqualToAnchor:container.topAnchor constant:20],
        [mainStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [mainStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [mainStackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-20],
        
        [self.resultsScrollView.heightAnchor constraintGreaterThanOrEqualToConstant:200]
    ]];
}

- (NSTextField *)createLabelWithText:(NSString *)text bold:(BOOL)bold {
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.stringValue = text;
    label.bezeled = NO;
    label.editable = NO;
    label.backgroundColor = [NSColor clearColor];
    if (bold) {
        label.font = [NSFont boldSystemFontOfSize:12];
    }
    return label;
}

- (NSButton *)createButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [[NSButton alloc] init];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title];
    button.target = self;
    button.action = action;
    return button;
}

#pragma mark - Actions

- (void)connectButtonClicked:(id)sender {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    BOOL isConnected = [downloadManager isDataSourceConnected:DataSourceTypeIBKR];
    
    if (isConnected) {
        [self appendResult:@"Disconnecting from IBKR..."];
        [downloadManager disconnectDataSource:DataSourceTypeIBKR];
        [self updateUI];
        [self appendResult:@"Disconnected from IBKR"];
    } else {
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
    [self appendResult:@"Testing quote request for AAPL (direct IBKR call)..."];
    
    // Get IBKR data source directly
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // First try the direct IBKR approach
    [self testDirectIBKRQuote:@"AAPL"];
}

- (void)testDirectIBKRQuote:(NSString *)symbol {
    // Access IBKR data source directly to bypass priority system
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if (!ibkrSource) {
        [self appendResult:@"❌ IBKR data source not found"];
        return;
    }
    
    if (!ibkrSource.isConnected) {
        [self appendResult:@"❌ IBKR not connected"];
        return;
    }
    
    [ibkrSource requestMarketData:symbol completion:^(NSDictionary *quote, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self appendResult:[NSString stringWithFormat:@"❌ Direct IBKR quote failed: %@", error.localizedDescription]];
            } else {
                [self appendResult:[NSString stringWithFormat:@"✅ Direct IBKR quote successful for %@", symbol]];
                [self appendResult:[NSString stringWithFormat:@"📊 IBKR Quote data: %@", quote]];
            }
        });
    }];
}

- (void)testHistoricalButtonClicked:(id)sender {
    [self appendResult:@"Testing historical data request for AAPL (direct IBKR call)..."];
    [self testDirectIBKRHistorical:@"AAPL"];
}

- (void)testDirectIBKRHistorical:(NSString *)symbol {
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if (!ibkrSource) {
        [self appendResult:@"❌ IBKR data source not found"];
        return;
    }
    
    if (!ibkrSource.isConnected) {
        [self appendResult:@"❌ IBKR not connected"];
        return;
    }
    
    [ibkrSource requestHistoricalData:symbol
                             duration:@"1 M"
                              barSize:@"1 day"
                           completion:^(NSArray *bars, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self appendResult:[NSString stringWithFormat:@"❌ Direct IBKR historical failed: %@", error.localizedDescription]];
            } else {
                [self appendResult:[NSString stringWithFormat:@"✅ Direct IBKR historical successful: %lu bars", (unsigned long)bars.count]];
                if (bars.count > 0) {
                    [self appendResult:[NSString stringWithFormat:@"📈 First bar: %@", bars.firstObject]];
                }
            }
        });
    }];
}

- (void)testAccountsButtonClicked:(id)sender {
    [self appendResult:@"Testing account information request (direct IBKR call)..."];
    [self testDirectIBKRAccounts];
}

- (void)testDirectIBKRAccounts {
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if (!ibkrSource) {
        [self appendResult:@"❌ IBKR data source not found"];
        return;
    }
    
    if (!ibkrSource.isConnected) {
        [self appendResult:@"❌ IBKR not connected"];
        return;
    }
    
    [ibkrSource getAccountsWithCompletion:^(NSArray<NSString *> *accounts, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self appendResult:[NSString stringWithFormat:@"❌ Direct IBKR accounts failed: %@", error.localizedDescription]];
            } else {
                [self appendResult:[NSString stringWithFormat:@"✅ Direct IBKR accounts successful: %@", accounts]];
            }
        });
    }];
}

// Helper method to get IBKR data source directly
- (IBKRDataSource *)getIBKRDataSource {
    // This is a bit of a hack, but we need to access the internal data sources
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // Try to use reflection to get the registered IBKR data source
    // This bypasses the priority system completely
    NSDictionary *dataSources = [downloadManager valueForKey:@"dataSources"];
    if (dataSources) {
        id dataSourceInfo = dataSources[@(DataSourceTypeIBKR)];
        if (dataSourceInfo) {
            id dataSource = [dataSourceInfo valueForKey:@"dataSource"];
            if ([dataSource isKindOfClass:[IBKRDataSource class]]) {
                return (IBKRDataSource *)dataSource;
            }
        }
    }
    
    return nil;
}

- (void)testAllSourcesButtonClicked:(id)sender {
    [self appendResult:@"🔍 Testing all data sources for quote comparison..."];
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    NSArray *sourceTypes = @[@(DataSourceTypeSchwab), @(DataSourceTypeIBKR), @(DataSourceTypeWebull), @(DataSourceTypeOther)];
    NSArray *sourceNames = @[@"Schwab", @"IBKR", @"Webull", @"Other"];
    
    for (NSInteger i = 0; i < sourceTypes.count; i++) {
        DataSourceType sourceType = [sourceTypes[i] integerValue];
        NSString *sourceName = sourceNames[i];
        
        BOOL isConnected = [downloadManager isDataSourceConnected:sourceType];
        NSString *statusStr = isConnected ? @"🟢" : @"🔴";
        
        [self appendResult:[NSString stringWithFormat:@"%@ Testing %@...", statusStr, sourceName]];
        
        [downloadManager executeRequest:DataRequestTypeQuote
                             parameters:@{@"symbol": @"AAPL"}
                        preferredSource:sourceType
                             completion:^(id result, DataSourceType usedSource, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [self appendResult:[NSString stringWithFormat:@"❌ %@ failed: %@", sourceName, error.localizedDescription]];
                } else {
                    NSString *actualSource = (usedSource == sourceType) ? sourceName : [NSString stringWithFormat:@"Fallback (%ld)", (long)usedSource];
                    [self appendResult:[NSString stringWithFormat:@"✅ %@ → %@", sourceName, actualSource]];
                }
            });
        }];
    }
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
    
    if (isConnected) {
        self.statusLabel.stringValue = @"✅ Connected to IBKR";
        self.statusLabel.textColor = [NSColor systemGreenColor];
        [self.connectButton setTitle:@"Disconnect"];
    } else {
        self.statusLabel.stringValue = @"❌ Not connected to IBKR";
        self.statusLabel.textColor = [NSColor systemRedColor];
        [self.connectButton setTitle:@"Connect"];
    }
    
    self.configLabel.stringValue = [self.config connectionURLString];
    
    self.testQuoteButton.enabled = YES;
    self.testHistoricalButton.enabled = YES;
    self.testAccountsButton.enabled = isConnected;
    self.testAllSourcesButton.enabled = YES;
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
        
        NSRange range = NSMakeRange(newText.length, 0);
        [self.resultsTextView scrollRangeToVisible:range];
    });
}

- (void)clearResults {
    self.resultsTextView.string = @"Results cleared.\n";
}

- (NSString *)widgetTitle {
    return @"IBKR Test";
}

@end
