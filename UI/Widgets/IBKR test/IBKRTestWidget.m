
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
    
    
    
    //📍 COMPLETE UI SETUP - Add to the end of your setupUI method:
    
    // === CONNECTION MODE CONTROLS ===
    NSTextField *modeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 180, 300, 20)];
    [modeLabel setStringValue:@"CONNECTION MODE:"];
    [modeLabel setBezeled:NO];
    [modeLabel setDrawsBackground:NO];
    [modeLabel setEditable:NO];
    [modeLabel setSelectable:NO];
    [[modeLabel cell] setFont:[NSFont boldSystemFontOfSize:12]];
    [self.view addSubview:modeLabel];
    
    NSButton *gatewayModeButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 155, 120, 25)];
    [gatewayModeButton setTitle:@"→ Gateway Mode"];
    [gatewayModeButton setTarget:self];
    [gatewayModeButton setAction:@selector(forceGatewayMode:)];
    [self.view addSubview:gatewayModeButton];
    
    NSButton *portalModeButton = [[NSButton alloc] initWithFrame:NSMakeRect(150, 155, 120, 25)];
    [portalModeButton setTitle:@"→ Portal Mode"];
    [portalModeButton setTarget:self];
    [portalModeButton setAction:@selector(forceClientPortalMode:)];
    [self.view addSubview:portalModeButton];
    
    NSButton *connectTCPButton = [[NSButton alloc] initWithFrame:NSMakeRect(280, 155, 120, 25)];
    [connectTCPButton setTitle:@"Connect TCP"];
    [connectTCPButton setTarget:self];
    [connectTCPButton setAction:@selector(connectTCPOnly:)];
    [self.view addSubview:connectTCPButton];
    
    // === DEBUG FALLBACK SECTION ===
    NSTextField *debugLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 125, 200, 20)];
    [debugLabel setStringValue:@"DEBUG FALLBACK:"];
    [debugLabel setBezeled:NO];
    [debugLabel setDrawsBackground:NO];
    [debugLabel setEditable:NO];
    [debugLabel setSelectable:NO];
    [[debugLabel cell] setFont:[NSFont boldSystemFontOfSize:12]];
    [self.view addSubview:debugLabel];
    
    NSButton *debugStatusButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 100, 100, 25)];
    [debugStatusButton setTitle:@"Debug Status"];
    [debugStatusButton setTarget:self];
    [debugStatusButton setAction:@selector(debugFallbackStatus:)];
    [self.view addSubview:debugStatusButton];
    
    NSButton *forceConnectionButton = [[NSButton alloc] initWithFrame:NSMakeRect(130, 100, 100, 25)];
    [forceConnectionButton setTitle:@"Force TCP"];
    [forceConnectionButton setTarget:self];
    [forceConnectionButton setAction:@selector(forceFallbackConnection:)];
    [self.view addSubview:forceConnectionButton];
    
    NSButton *testFallbackButton = [[NSButton alloc] initWithFrame:NSMakeRect(240, 100, 100, 25)];
    [testFallbackButton setTitle:@"Test TCP Only"];
    [testFallbackButton setTarget:self];
    [testFallbackButton setAction:@selector(testFallbackOnly:)];
    [self.view addSubview:testFallbackButton];
    
    NSButton *testAccountsButton = [[NSButton alloc] initWithFrame:NSMakeRect(350, 100, 120, 25)];
    [testAccountsButton setTitle:@"Test w/Fallback"];
    [testAccountsButton setTarget:self];
    [testAccountsButton setAction:@selector(testAccountsWithFallback:)];
    [self.view addSubview:testAccountsButton];
    
    NSButton *deepDebugButton = [[NSButton alloc] initWithFrame:NSMakeRect(220, 180, 100, 25)];
        [deepDebugButton setTitle:@"Deep Debug"];
        [deepDebugButton setTarget:self];
        [deepDebugButton setAction:@selector(deepDebugCurrentState:)];
        [self.view addSubview:deepDebugButton];
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

// Enhanced logging for IBKR connection errors
- (void)connectButtonClicked:(id)sender {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    BOOL isConnected = [downloadManager isDataSourceConnected:DataSourceTypeIBKR];
    if (isConnected) {
        [self appendResult:@"✅ Already connected to IBKR"];
        return;
    }
    [self appendResult:[NSString stringWithFormat:@"Connecting to IBKR at %@...", [self.config connectionURLString]]];
    [downloadManager connectDataSource:DataSourceTypeIBKR completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self appendResult:@"✅ Successfully connected to IBKR"];
            } else {
                // Enhanced error logging
                [self appendResult:[NSString stringWithFormat:@"❌ Failed to connect to IBKR"]];
                if (error) {
                    [self appendResult:[NSString stringWithFormat:@"   • Description: %@", error.localizedDescription]];
                    [self appendResult:[NSString stringWithFormat:@"   • Domain: %@", error.domain]];
                    [self appendResult:[NSString stringWithFormat:@"   • Code: %ld", (long)error.code]];
                    [self appendResult:[NSString stringWithFormat:@"   • UserInfo: %@", error.userInfo]];
                }
            }
            [self updateUI];
        });
    }];
}

- (void)testQuoteButtonClicked:(id)sender {
    [self appendResult:@"Testing quote request for AAPL (direct IBKR call)..."];
    
    // Get IBKR data source directly
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // First try the direct IBKR approach
    [self testDirectIBKRQuote:@"AAPL"];
}

- (void)testDirectIBKRQuote:(NSString *)symbol {
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if (!ibkrSource) {
        [self appendResult:@"❌ IBKR data source not found"];
        return;
    }
    
    if (!ibkrSource.isConnected) {
        [self appendResult:@"❌ IBKR not connected"];
        return;
    }
    
    // ✅ CORREZIONE: Usare il nuovo metodo unificato
    [ibkrSource fetchQuoteForSymbol:symbol completion:^(id quote, NSError *error) {
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
    
    // ✅ CORREZIONE: Usare il nuovo metodo unificato con parametri corretti
    [ibkrSource fetchHistoricalDataForSymbol:symbol
                                   timeframe:BarTimeframeDaily
                                     barCount:30  // Circa 1 mese di dati
                            needExtendedHours:NO
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
    
    // ✅ QUESTO È GIÀ CORRETTO - fetchAccountsWithCompletion è il metodo unificato giusto
    [ibkrSource fetchAccountsWithCompletion:^(NSArray<NSString *> *accounts, NSError *error) {
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
        
        // CORREZIONE: Sostituito executeRequest con executeMarketDataRequest
        [downloadManager executeMarketDataRequest:DataRequestTypeQuote
                                        parameters:@{@"symbol": @"AAPL"}
                                   preferredSource:sourceType
                                        completion:^(id result, DataSourceType usedSource, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [self appendResult:[NSString stringWithFormat:@"❌ %@ failed: %@", sourceName, error.localizedDescription]];
                } else {
                    NSString *actualSource = (usedSource == sourceType) ?
                        sourceName : [NSString stringWithFormat:@"Fallback (%ld)", (long)usedSource];
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

- (IBAction)useTraditionalGateway:(id)sender {
    // ✅ FORZA l'uso del Gateway tradizionale (porta 4002)
    IBKRConfiguration *config = [IBKRConfiguration sharedConfiguration];
    [config loadGatewayPreset];  // Porta 4002, protocollo nativo
    [config saveToUserDefaults];
    
    NSLog(@"🔄 Switched to IB Gateway (port 4002)");
    [self updateUI];
    
    // Mostra istruzioni all'utente
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"IB Gateway Setup";
    alert.informativeText = @"1. Start IB Gateway (downloaded separately)\n"
                            @"2. Login with your IBKR credentials\n"
                            @"3. Enable API connections in Gateway\n"
                            @"4. Come back and click Connect";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}


#pragma mark - ✅ NEW: TCP Connection Controls

- (IBAction)forceGatewayMode:(id)sender {
    [self appendResult:@"🔄 Switching to IB Gateway mode..."];
    
    // Change configuration to use Gateway instead of Client Portal
    IBKRConfiguration *config = [IBKRConfiguration sharedConfiguration];
    [config loadGatewayPreset]; // Port 4002, TCP native protocol
    [config saveToUserDefaults];
    
    // 🎯 IMPORTANT: Disconnect current connection to force recreation with new settings
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    BOOL wasConnected = [downloadManager isDataSourceConnected:DataSourceTypeIBKR];
    
    if (wasConnected) {
        [self appendResult:@"🔌 Disconnecting current IBKR connection..."];
        [downloadManager disconnectDataSource:DataSourceTypeIBKR];
    }
    
    [self appendResult:@"✅ Configuration switched to IB Gateway (port 4002)"];
    [self appendResult:@"📋 Prerequisites:"];
    [self appendResult:@"   1. Download IB Gateway from IBKR"];
    [self appendResult:@"   2. Start IB Gateway application"];
    [self appendResult:@"   3. Login with IBKR credentials"];
    [self appendResult:@"   4. Enable API connections in Gateway settings"];
    [self appendResult:@"🔄 Click 'Connect' to connect with TCP protocol"];
    
    [self updateUI];
}

- (IBAction)forceClientPortalMode:(id)sender {
    [self appendResult:@"🔄 Switching to Client Portal mode..."];
    
    // Switch back to Client Portal (port 5001, REST API)
    IBKRConfiguration *config = [IBKRConfiguration sharedConfiguration];
    config.port = 5001; // Client Portal port
    [config saveToUserDefaults];
    
    // 🎯 IMPORTANT: Disconnect current connection to force recreation
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    BOOL wasConnected = [downloadManager isDataSourceConnected:DataSourceTypeIBKR];
    
    if (wasConnected) {
        [self appendResult:@"🔌 Disconnecting current IBKR connection..."];
        [downloadManager disconnectDataSource:DataSourceTypeIBKR];
    }
    
    [self appendResult:@"✅ Configuration switched to Client Portal (port 5001)"];
    [self appendResult:@"🔄 Click 'Connect' to connect with REST API"];
    
    [self updateUI];
}

- (IBAction)connectTCPOnly:(id)sender {
    [self appendResult:@"🔄 Connecting to TCP Gateway directly (bypassing Client Portal)..."];
    [self appendResult:@"📡 Attempting connection to IB Gateway on port 4002..."];
    
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    if (ibkrSource && [ibkrSource respondsToSelector:@selector(forceFallbackConnection)]) {
        // Ensure fallback is enabled
        if ([ibkrSource respondsToSelector:@selector(enableFallback:)]) {
            [ibkrSource enableFallback:YES];
        }
        
        [ibkrSource forceFallbackConnection];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([ibkrSource respondsToSelector:@selector(isFallbackConnected)]) {
                BOOL connected = [(id)ibkrSource isFallbackConnected];
                if (connected) {
                    [self appendResult:@"✅ TCP Gateway connected successfully"];
                    [self appendResult:@"🎯 You can now test TCP-only operations"];
                } else {
                    [self appendResult:@"❌ TCP Gateway connection failed"];
                    [self appendResult:@"💡 Troubleshooting:"];
                    [self appendResult:@"   • Is IB Gateway running?"];
                    [self appendResult:@"   • Is it listening on port 4002?"];
                    [self appendResult:@"   • Are API connections enabled?"];
                    [self appendResult:@"   • Check Gateway API settings"];
                }
            }
            [self updateUI];
        });
    } else {
        [self appendResult:@"❌ TCP fallback methods not available"];
        [self appendResult:@"⚠️ Make sure IBKRDataSource has fallback implementation"];
    }
}

- (IBAction)debugFallbackStatus:(id)sender {
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if (ibkrSource) {
        [self appendResult:@"🔍 IBKR DataSource Status:"];
        [self appendResult:[NSString stringWithFormat:@"   Primary Connected: %@", ibkrSource.isConnected ? @"YES" : @"NO"]];
        [self appendResult:[NSString stringWithFormat:@"   Host: %@:%ld", ibkrSource.host, (long)ibkrSource.port]];
        [self appendResult:[NSString stringWithFormat:@"   Client ID: %ld", (long)ibkrSource.clientId]];
        
        // Check fallback status if methods exist
        if ([ibkrSource respondsToSelector:@selector(isFallbackEnabled)]) {
            BOOL fallbackEnabled = [(id)ibkrSource isFallbackEnabled];
            [self appendResult:[NSString stringWithFormat:@"   Fallback Enabled: %@", fallbackEnabled ? @"YES" : @"NO"]];
        }
        
        if ([ibkrSource respondsToSelector:@selector(isFallbackConnected)]) {
            BOOL fallbackConnected = [(id)ibkrSource isFallbackConnected];
            [self appendResult:[NSString stringWithFormat:@"   Fallback Connected: %@", fallbackConnected ? @"YES" : @"NO"]];
        }
        
        // Show current configuration
        IBKRConfiguration *config = [IBKRConfiguration sharedConfiguration];
        [self appendResult:[NSString stringWithFormat:@"   Configuration: %@", [config connectionURLString]]];
        
        [self appendResult:@"📋 Check Xcode console for detailed logs"];
        
        // Call the debug method if it exists
        if ([ibkrSource respondsToSelector:@selector(debugFallbackStatus)]) {
            [ibkrSource debugFallbackStatus];
        }
    } else {
        [self appendResult:@"❌ IBKR DataSource not found"];
    }
}

- (IBAction)forceFallbackConnection:(id)sender {
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if (ibkrSource) {
        [self appendResult:@"🔄 Attempting TCP fallback connection..."];
        [self appendResult:@"   (Requires IB Gateway running on port 4002)"];
        
        // Call force connection if method exists
        if ([ibkrSource respondsToSelector:@selector(forceFallbackConnection)]) {
            [ibkrSource forceFallbackConnection];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self appendResult:@"✅ Check console logs for connection result"];
                if ([ibkrSource respondsToSelector:@selector(isFallbackConnected)]) {
                    BOOL connected = [(id)ibkrSource isFallbackConnected];
                    [self appendResult:[NSString stringWithFormat:@"   TCP Status: %@", connected ? @"CONNECTED" : @"FAILED"]];
                }
            });
        } else {
            [self appendResult:@"⚠️ Fallback methods not implemented yet"];
        }
    } else {
        [self appendResult:@"❌ IBKR DataSource not found"];
    }
}

- (IBAction)testFallbackOnly:(id)sender {
    [self appendResult:@"🧪 Testing TCP-only connection..."];
    [self appendResult:@"📋 Prerequisites checklist:"];
    [self appendResult:@"   ✓ Download IB Gateway (not Client Portal)"];
    [self appendResult:@"   ✓ Start IB Gateway on port 4002"];
    [self appendResult:@"   ✓ Login with IBKR credentials"];
    [self appendResult:@"   ✓ Enable API connections in Gateway"];
    
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if (ibkrSource) {
        // Enable fallback if method exists
        if ([ibkrSource respondsToSelector:@selector(enableFallback:)]) {
            [ibkrSource enableFallback:YES];
        }
        
        [self appendResult:@"🔄 Testing direct TCP connection..."];
        
        // Try to get accounts directly from IBKR
        [self testDirectIBKRAccounts];
    } else {
        [self appendResult:@"❌ IBKR DataSource not found"];
    }
}

- (IBAction)testAccountsWithFallback:(id)sender {
    [self appendResult:@"📡 Testing accounts with fallback architecture..."];
    [self appendResult:@"🔄 Will try REST first, then fallback to TCP if auth fails"];
    
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if (ibkrSource) {
        // Enable fallback system if available
        if ([ibkrSource respondsToSelector:@selector(enableFallback:)]) {
            [ibkrSource enableFallback:YES];
            [self appendResult:@"✅ Fallback system enabled"];
        } else {
            [self appendResult:@"⚠️ Using basic IBKR connection (fallback not implemented)"];
        }
        
        // Test accounts using the unified method
        if ([ibkrSource respondsToSelector:@selector(fetchAccountsWithCompletion:)]) {
            [ibkrSource fetchAccountsWithCompletion:^(NSArray *accounts, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        [self appendResult:[NSString stringWithFormat:@"❌ Accounts failed: %@", error.localizedDescription]];
                    } else {
                        [self appendResult:[NSString stringWithFormat:@"✅ Accounts success: %lu found", (unsigned long)accounts.count]];
                        
                        // Display account info
                        for (id account in accounts) {
                            if ([account isKindOfClass:[NSString class]]) {
                                [self appendResult:[NSString stringWithFormat:@"   Account: %@", (NSString *)account]];
                            } else if ([account isKindOfClass:[NSDictionary class]]) {
                                NSDictionary *accountDict = (NSDictionary *)account;
                                NSString *accountId = accountDict[@"id"] ?: accountDict[@"accountId"];
                                NSString *currency = accountDict[@"currency"] ?: @"N/A";
                                [self appendResult:[NSString stringWithFormat:@"   Account: %@ (%@)", accountId, currency]];
                            }
                        }
                        
                        // Test positions for first account if available
                        if (accounts.count > 0) {
                            [self testPositionsForFirstAccount:accounts];
                        }
                    }
                });
            }];
        } else {
            [self appendResult:@"❌ fetchAccountsWithCompletion method not available"];
        }
    } else {
        [self appendResult:@"❌ IBKR DataSource not found"];
    }
}

#pragma mark - Helper Methods

- (void)testPositionsForFirstAccount:(NSArray *)accounts {
    NSString *firstAccountId = nil;
    
    // Extract account ID from first account
    id firstAccount = accounts[0];
    if ([firstAccount isKindOfClass:[NSString class]]) {
        firstAccountId = (NSString *)firstAccount;
    } else if ([firstAccount isKindOfClass:[NSDictionary class]]) {
        NSDictionary *accountDict = (NSDictionary *)firstAccount;
        firstAccountId = accountDict[@"id"] ?: accountDict[@"accountId"];
    }
    
    if (!firstAccountId) {
        [self appendResult:@"⚠️ Could not extract account ID for positions test"];
        return;
    }
    
    [self appendResult:[NSString stringWithFormat:@"📊 Testing positions for account %@...", firstAccountId]];
    
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    
    if ([ibkrSource respondsToSelector:@selector(fetchPositionsForAccount:completion:)]) {
        [ibkrSource fetchPositionsForAccount:firstAccountId completion:^(NSArray *positions, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [self appendResult:[NSString stringWithFormat:@"❌ Positions failed: %@", error.localizedDescription]];
                } else {
                    [self appendResult:[NSString stringWithFormat:@"✅ Positions success: %lu found", (unsigned long)positions.count]];
                    
                    // Show first few positions
                    NSInteger showCount = MIN(positions.count, 3);
                    for (NSInteger i = 0; i < showCount; i++) {
                        id position = positions[i];
                        if ([position isKindOfClass:[NSDictionary class]]) {
                            NSDictionary *posDict = (NSDictionary *)position;
                            NSString *symbol = posDict[@"symbol"] ?: @"N/A";
                            NSNumber *qty = posDict[@"position"] ?: posDict[@"quantity"];
                            [self appendResult:[NSString stringWithFormat:@"   %@: %@ shares", symbol, qty ?: @"N/A"]];
                        }
                    }
                    
                    if (positions.count > 3) {
                        [self appendResult:[NSString stringWithFormat:@"   ... and %lu more positions", (unsigned long)(positions.count - 3)]];
                    }
                }
            });
        }];
    } else {
        [self appendResult:@"❌ fetchPositionsForAccount method not available"];
    }
}



- (IBAction)deepDebugCurrentState:(id)sender {
    [self appendResult:@"🔍 DEEP DEBUG - Current State Analysis"];
    [self appendResult:@"====================================="];
    
    // 1. Check configuration
    IBKRConfiguration *config = [IBKRConfiguration sharedConfiguration];
    [self appendResult:[NSString stringWithFormat:@"📋 Config Host: %@", config.host]];
    [self appendResult:[NSString stringWithFormat:@"📋 Config Port: %ld", (long)config.port]];
    [self appendResult:[NSString stringWithFormat:@"📋 Config Client ID: %ld", (long)config.clientId]];
    [self appendResult:[NSString stringWithFormat:@"📋 Config Type: %@", config.connectionType == IBKRConnectionTypeGateway ? @"Gateway" : @"TWS/Portal"]];
    
    // 2. Check DownloadManager connection status
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    BOOL dmConnected = [downloadManager isDataSourceConnected:DataSourceTypeIBKR];
    [self appendResult:[NSString stringWithFormat:@"📡 DownloadManager Connected: %@", dmConnected ? @"YES" : @"NO"]];
    
    // 3. Check actual IBKRDataSource instance
    IBKRDataSource *ibkrSource = [self getIBKRDataSource];
    if (ibkrSource) {
        [self appendResult:[NSString stringWithFormat:@"🎯 DataSource Host: %@", ibkrSource.host]];
        [self appendResult:[NSString stringWithFormat:@"🎯 DataSource Port: %ld", (long)ibkrSource.port]];
        [self appendResult:[NSString stringWithFormat:@"🎯 DataSource Client ID: %ld", (long)ibkrSource.clientId]];
        [self appendResult:[NSString stringWithFormat:@"🎯 DataSource Connected: %@", ibkrSource.isConnected ? @"YES" : @"NO"]];
        [self appendResult:[NSString stringWithFormat:@"🎯 DataSource Instance: %p", ibkrSource]];
        
        // Check if it matches config
        if (ibkrSource.port == config.port) {
            [self appendResult:@"✅ DataSource port MATCHES config"];
        } else {
            [self appendResult:[NSString stringWithFormat:@"❌ DataSource port %ld != Config port %ld", (long)ibkrSource.port, (long)config.port]];
            [self appendResult:@"🚨 PROBLEM: DataSource not updated after config change!"];
        }
    } else {
        [self appendResult:@"❌ No IBKRDataSource instance found"];
    }
    
    [self appendResult:@"====================================="];
}
@end
