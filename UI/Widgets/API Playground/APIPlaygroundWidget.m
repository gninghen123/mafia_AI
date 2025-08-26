//
//  APIPlaygroundWidget.m (UPDATED - UNIFIED IMPLEMENTATION)
//  TradingApp
//

#import "APIPlaygroundWidget.h"
#import "DownloadManager.h"
#import "MarketData.h"

@interface APIPlaygroundWidget () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSStackView *controlsContainer;
@property (nonatomic, strong) NSMutableArray *tableColumns;
@end

@implementation APIPlaygroundWidget

- (instancetype)init {
    self = [super init];
    if (self) {
        self.widgetType = @"APIPlayground";
        self.resultData = [NSMutableArray array];
        self.tableColumns = [NSMutableArray array];
        self.currentRequestType = APIPlaygroundRequestTypeQuote;
        self.preferredDataSource = DataSourceTypeOther; // Auto-select
    }
    return self;
}

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.resultData = [NSMutableArray array];
        self.tableColumns = [NSMutableArray array];
        self.currentRequestType = APIPlaygroundRequestTypeQuote;
        self.preferredDataSource = DataSourceTypeOther;
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    [self setupTabs];
    [self setupUnifiedTab];
    [self setupResultsViews];
    [self updateControlsVisibilityForRequestType:self.currentRequestType];
}

#pragma mark - Tab Setup

- (void)setupTabs {
    self.tabView = [[NSTabView alloc] init];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.tabView];
    
    // Unified API Calls Tab
    NSTabViewItem *unifiedTab = [[NSTabViewItem alloc] initWithIdentifier:@"unified"];
    unifiedTab.label = @"Unified API Calls";
    self.unifiedTabView = [[NSView alloc] init];
    unifiedTab.view = self.unifiedTabView;
    [self.tabView addTabViewItem:unifiedTab];
    
    // Legacy Historical Tab (keep existing functionality)
    NSTabViewItem *historicalTab = [[NSTabViewItem alloc] initWithIdentifier:@"historical"];
    historicalTab.label = @"Legacy Historical";
    self.historicalTabView = [[NSView alloc] init];
    historicalTab.view = self.historicalTabView;
    [self.tabView addTabViewItem:historicalTab];
    
    // Select unified tab by default
    [self.tabView selectFirstTabViewItem:nil];
    
    // Layout tab view
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.tabView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.tabView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - Unified Tab Setup

- (void)setupUnifiedTab {
    const CGFloat padding = 12;
    
    // Request Type Selection
    NSTextField *requestTypeLabel = [self createLabel:@"Request Type:"];
    self.requestTypePopup = [[NSPopUpButton alloc] init];
    [self.requestTypePopup addItemsWithTitles:@[
        @"Single Quote",
        @"Batch Quotes",
        @"Historical Bars",
        @"Top Gainers",
        @"Top Losers",
        @"ETF List",
        @"52 Week Highs",
        @"Market List",
        @"Accounts",
        @"Account Details",
        @"Positions",
        @"Orders",
        @"Order Book",
        @"Fundamentals"
    ]];
    [self.requestTypePopup setTarget:self];
    [self.requestTypePopup setAction:@selector(requestTypeChanged:)];
    
    // Data Source Selection
    NSTextField *dataSourceLabel = [self createLabel:@"Data Source:"];
    self.dataSourcePopup = [[NSPopUpButton alloc] init];
    [self.dataSourcePopup addItemsWithTitles:@[
        @"Auto Select (Best Available)",
        @"Schwab API",
        @"IBKR API",
        @"Webull API",
        @"Yahoo Finance"
    ]];
    [self.dataSourcePopup setTarget:self];
    [self.dataSourcePopup setAction:@selector(dataSourceChanged:)];
    
    // Symbol Input
    NSTextField *symbolLabel = [self createLabel:@"Symbol:"];
    self.symbolField = [self createTextField:@"AAPL"];
    
    NSTextField *symbolsLabel = [self createLabel:@"Symbols (comma separated):"];
    self.symbolsField = [self createTextField:@"AAPL,MSFT,GOOGL"];
    
    // Historical Data Controls
    NSTextField *timeframeLabel = [self createLabel:@"Timeframe:"];
    self.timeframePopup = [[NSPopUpButton alloc] init];
    [self.timeframePopup addItemsWithTitles:@[
        @"1 Minute", @"5 Minutes", @"15 Minutes", @"30 Minutes", @"1 Hour", @"Daily", @"Weekly"
    ]];
    [self.timeframePopup selectItemWithTitle:@"Daily"];
    
    NSTextField *startLabel = [self createLabel:@"Start Date:"];
       self.startDatePicker = [[NSDatePicker alloc] init];
       
       // CORREZIONE: Controllo versione per NSDatePickerStyleCompact
      
           // Fallback per versioni precedenti
           self.startDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
           self.startDatePicker.datePickerMode = NSDatePickerModeSingle;
       
       
       self.startDatePicker.dateValue = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitMonth
                                                                                  value:-1
                                                                                 toDate:[NSDate date]
                                                                                options:0];
       
       NSTextField *endLabel = [self createLabel:@"End Date:"];
       self.endDatePicker = [[NSDatePicker alloc] init];
       
       // CORREZIONE: Stesso controllo versione per endDatePicker
     
           self.endDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
           self.endDatePicker.datePickerMode = NSDatePickerModeSingle;
       
       
       self.endDatePicker.dateValue = [NSDate date];
    
    
    NSTextField *barCountLabel = [self createLabel:@"Bar Count:"];
    self.barCountField = [self createTextField:@"100"];
    self.barCountField.formatter = [[NSNumberFormatter alloc] init];
    
    self.extendedHoursCheckbox = [NSButton buttonWithTitle:@"Extended Hours"
                                                    target:nil
                                                    action:nil];
    self.extendedHoursCheckbox.buttonType = NSButtonTypeSwitch;
    
    // Market List Controls
    NSTextField *limitLabel = [self createLabel:@"Max Results:"];
    self.limitField = [self createTextField:@"50"];
    self.limitField.formatter = [[NSNumberFormatter alloc] init];
    
    NSTextField *marketTimeframeLabel = [self createLabel:@"Market Timeframe:"];
    self.marketTimeframePopup = [[NSPopUpButton alloc] init];
    [self.marketTimeframePopup addItemsWithTitles:@[
        @"Current Day", @"5 Days", @"1 Month", @"52 Weeks"
    ]];
    
    // Account Controls
    NSTextField *accountLabel = [self createLabel:@"Account ID:"];
    self.accountIdField = [self createTextField:@""];
    
    // Parameters Summary
    self.parametersLabel = [self createLabel:@""];
    self.parametersLabel.textColor = [NSColor secondaryLabelColor];
    self.parametersLabel.font = [NSFont systemFontOfSize:11];
    
    // Action Buttons
    self.executeButton = [NSButton buttonWithTitle:@"Execute Request"
                                            target:self
                                            action:@selector(executeUnifiedRequest)];
    self.executeButton.bezelStyle = NSBezelStyleRounded;
    self.executeButton.keyEquivalent = @"\r";
    
    self.clearButton = [NSButton buttonWithTitle:@"Clear Results"
                                          target:self
                                          action:@selector(clearAllResults)];
    self.clearButton.bezelStyle = NSBezelStyleRounded;
    
    self.ccopyRawButton = [NSButton buttonWithTitle:@"Copy Raw Response"
                                            target:self
                                            action:@selector(copyRawResponseToClipboard)];
    self.ccopyRawButton.bezelStyle = NSBezelStyleRounded;
    
    // Status
    self.statusLabel = [self createLabel:@"Ready"];
    self.statusLabel.textColor = [NSColor systemGreenColor];
    
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    [self.loadingIndicator sizeToFit];
    
    // Layout with Stack Views
    NSStackView *row1 = [self createHorizontalStack:@[requestTypeLabel, self.requestTypePopup,
                                                      dataSourceLabel, self.dataSourcePopup]];
    
    NSStackView *row2 = [self createHorizontalStack:@[symbolLabel, self.symbolField,
                                                      symbolsLabel, self.symbolsField]];
    
    NSStackView *row3 = [self createHorizontalStack:@[timeframeLabel, self.timeframePopup,
                                                      startLabel, self.startDatePicker,
                                                      endLabel, self.endDatePicker]];
    
    NSStackView *row4 = [self createHorizontalStack:@[barCountLabel, self.barCountField,
                                                      self.extendedHoursCheckbox,
                                                      limitLabel, self.limitField]];
    
    NSStackView *row5 = [self createHorizontalStack:@[marketTimeframeLabel, self.marketTimeframePopup,
                                                      accountLabel, self.accountIdField]];
    
    NSStackView *row6 = [self createHorizontalStack:@[self.parametersLabel]];
    
    NSStackView *buttonsRow = [self createHorizontalStack:@[self.statusLabel,
                                                           self.loadingIndicator,
                                                           [[NSView alloc] init], // Spacer
                                                           self.executeButton,
                                                           self.clearButton,
                                                           self.ccopyRawButton]];
    
    // Controls Container
    self.controlsContainer = [[NSStackView alloc] init];
    self.controlsContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.controlsContainer.spacing = 8;
    self.controlsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.controlsContainer addArrangedSubview:row1];
    [self.controlsContainer addArrangedSubview:row2];
    [self.controlsContainer addArrangedSubview:row3];
    [self.controlsContainer addArrangedSubview:row4];
    [self.controlsContainer addArrangedSubview:row5];
    [self.controlsContainer addArrangedSubview:row6];
    [self.controlsContainer addArrangedSubview:buttonsRow];
    
    [self.unifiedTabView addSubview:self.controlsContainer];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsContainer.topAnchor constraintEqualToAnchor:self.unifiedTabView.topAnchor constant:padding],
        [self.controlsContainer.leadingAnchor constraintEqualToAnchor:self.unifiedTabView.leadingAnchor constant:padding],
        [self.controlsContainer.trailingAnchor constraintEqualToAnchor:self.unifiedTabView.trailingAnchor constant:-padding]
    ]];
}

#pragma mark - Results Views Setup

- (void)setupResultsViews {
    const CGFloat padding = 12;
    
    // Table View for structured data
    self.tableScrollView = [[NSScrollView alloc] init];
    self.tableScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableScrollView.hasVerticalScroller = YES;
    self.tableScrollView.hasHorizontalScroller = YES;
    self.tableScrollView.autohidesScrollers = YES;
    [self.unifiedTabView addSubview:self.tableScrollView];
    
    self.resultsTableView = [[NSTableView alloc] init];
    self.resultsTableView.dataSource = self;
    self.resultsTableView.delegate = self;
    self.resultsTableView.allowsMultipleSelection = YES;
    self.resultsTableView.usesAlternatingRowBackgroundColors = YES;
    self.tableScrollView.documentView = self.resultsTableView;
    
    // Text View for raw response
    self.textScrollView = [[NSScrollView alloc] init];
    self.textScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textScrollView.hasVerticalScroller = YES;
    self.textScrollView.autohidesScrollers = YES;
    [self.unifiedTabView addSubview:self.textScrollView];
    
    self.rawResponseTextView = [[NSTextView alloc] init];
    self.rawResponseTextView.editable = NO;
    self.rawResponseTextView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.rawResponseTextView.textColor = [NSColor textColor];
    self.textScrollView.documentView = self.rawResponseTextView;
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Table view (top half of results area)
        [self.tableScrollView.topAnchor constraintEqualToAnchor:self.controlsContainer.bottomAnchor constant:padding],
        [self.tableScrollView.leadingAnchor constraintEqualToAnchor:self.unifiedTabView.leadingAnchor constant:padding],
        [self.tableScrollView.trailingAnchor constraintEqualToAnchor:self.unifiedTabView.trailingAnchor constant:-padding],
        
        // Text view (bottom half)
        [self.textScrollView.topAnchor constraintEqualToAnchor:self.tableScrollView.bottomAnchor constant:padding],
        [self.textScrollView.leadingAnchor constraintEqualToAnchor:self.unifiedTabView.leadingAnchor constant:padding],
        [self.textScrollView.trailingAnchor constraintEqualToAnchor:self.unifiedTabView.trailingAnchor constant:-padding],
        [self.textScrollView.bottomAnchor constraintEqualToAnchor:self.unifiedTabView.bottomAnchor constant:-padding],
        
        // Equal height distribution
        [self.tableScrollView.heightAnchor constraintEqualToAnchor:self.textScrollView.heightAnchor multiplier:1.0]
    ]];
}

#pragma mark - Request Type Management

- (void)requestTypeChanged:(NSPopUpButton *)sender {
    self.currentRequestType = (APIPlaygroundRequestType)sender.indexOfSelectedItem;
    [self updateControlsVisibilityForRequestType:self.currentRequestType];
    [self updateParametersDisplay];
}

- (void)dataSourceChanged:(NSPopUpButton *)sender {
    switch (sender.indexOfSelectedItem) {
        case 0: self.preferredDataSource = DataSourceTypeOther; break; // Auto select
        case 1: self.preferredDataSource = DataSourceTypeSchwab; break;
        case 2: self.preferredDataSource = DataSourceTypeIBKR; break;
        case 3: self.preferredDataSource = DataSourceTypeWebull; break;
        case 4: self.preferredDataSource = DataSourceTypeOther; break; // Yahoo
        default: self.preferredDataSource = DataSourceTypeOther; break;
    }
    [self updateParametersDisplay];
}

- (void)updateControlsVisibilityForRequestType:(APIPlaygroundRequestType)requestType {
    // Hide all controls first
    self.symbolField.hidden = YES;
    self.symbolsField.hidden = YES;
    self.timeframePopup.hidden = YES;
    self.startDatePicker.hidden = YES;
    self.endDatePicker.hidden = YES;
    self.barCountField.hidden = YES;
    self.extendedHoursCheckbox.hidden = YES;
    self.limitField.hidden = YES;
    self.marketTimeframePopup.hidden = YES;
    self.accountIdField.hidden = YES;
    
    // Show relevant controls based on request type
    switch (requestType) {
        case APIPlaygroundRequestTypeQuote:
            self.symbolField.hidden = NO;
            break;
            
        case APIPlaygroundRequestTypeBatchQuotes:
            self.symbolsField.hidden = NO;
            break;
            
        case APIPlaygroundRequestTypeHistoricalBars:
            self.symbolField.hidden = NO;
            self.timeframePopup.hidden = NO;
            self.startDatePicker.hidden = NO;
            self.endDatePicker.hidden = NO;
            self.barCountField.hidden = NO;
            self.extendedHoursCheckbox.hidden = NO;
            break;
            
        case APIPlaygroundRequestTypeTopGainers:
        case APIPlaygroundRequestTypeTopLosers:
        case APIPlaygroundRequestTypeETFList:
        case APIPlaygroundRequestType52WeekHigh:
        case APIPlaygroundRequestTypeMarketList:
            self.limitField.hidden = NO;
            self.marketTimeframePopup.hidden = NO;
            break;
            
        case APIPlaygroundRequestTypeAccountDetails:
        case APIPlaygroundRequestTypePositions:
        case APIPlaygroundRequestTypeOrders:
            self.accountIdField.hidden = NO;
            break;
            
        case APIPlaygroundRequestTypeAccounts:
            // No additional controls needed
            break;
            
        case APIPlaygroundRequestTypeOrderBook:
        case APIPlaygroundRequestTypeFundamentals:
            self.symbolField.hidden = NO;
            break;
    }
}

#pragma mark - Request Execution

- (void)executeUnifiedRequest {
    [self updateParametersDisplay];
    [self clearAllResults];
    
    self.executeButton.enabled = NO;
    self.executeButton.title = @"Executing...";
    self.statusLabel.stringValue = @"Executing request...";
    self.statusLabel.textColor = [NSColor systemOrangeColor];
    [self.loadingIndicator startAnimation:nil];
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    switch (self.currentRequestType) {
        case APIPlaygroundRequestTypeQuote:{
            parameters[@"symbol"] = self.symbolField.stringValue;
            // CORREZIONE: executeMarketDataRequest con preferredSource
            self.activeRequestID = [downloadManager executeMarketDataRequest:DataRequestTypeQuote
                                                                  parameters:parameters
                                                             preferredSource:self.preferredDataSource
                                                                  completion:^(id result, DataSourceType usedSource, NSError *error) {
                [self handleUnifiedResponse:result usedSource:usedSource error:error];
            }];
            break;
    }
        case APIPlaygroundRequestTypeBatchQuotes: {
            NSString *symbolsString = self.symbolsField.stringValue;
            NSArray *symbols = [symbolsString componentsSeparatedByString:@","];
            NSMutableArray *trimmedSymbols = [NSMutableArray array];
            for (NSString *symbol in symbols) {
                [trimmedSymbols addObject:[symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            }
            parameters[@"symbols"] = trimmedSymbols;
            
            // CORREZIONE: executeMarketDataRequest
            self.activeRequestID = [downloadManager executeMarketDataRequest:DataRequestTypeBatchQuotes
                                                                  parameters:parameters
                                                             preferredSource:self.preferredDataSource
                                                                  completion:^(id result, DataSourceType usedSource, NSError *error) {
                [self handleUnifiedResponse:result usedSource:usedSource error:error];
            }];
            break;
        }
            
        case APIPlaygroundRequestTypeHistoricalBars:{
            parameters[@"symbol"] = self.symbolField.stringValue;
            parameters[@"timeframe"] = @([self selectedBarTimeframe]);
            parameters[@"startDate"] = self.startDatePicker.dateValue;
            parameters[@"endDate"] = self.endDatePicker.dateValue;
            parameters[@"needExtendedHours"] = @(self.extendedHoursCheckbox.state == NSControlStateValueOn);
            
            // CORREZIONE: executeMarketDataRequest
            self.activeRequestID = [downloadManager executeMarketDataRequest:DataRequestTypeHistoricalBars
                                                                  parameters:parameters
                                                             preferredSource:self.preferredDataSource
                                                                  completion:^(id result, DataSourceType usedSource, NSError *error) {
                [self handleUnifiedResponse:result usedSource:usedSource error:error];
            }];
            break;
        }
        case APIPlaygroundRequestTypeTopGainers:{
            parameters[@"limit"] = @([self.limitField.stringValue integerValue]);
            // CORREZIONE: executeMarketDataRequest
            self.activeRequestID = [downloadManager executeMarketDataRequest:DataRequestTypeTopGainers
                                                                  parameters:parameters
                                                             preferredSource:self.preferredDataSource
                                                                  completion:^(id result, DataSourceType usedSource, NSError *error) {
                [self handleUnifiedResponse:result usedSource:usedSource error:error];
            }];
            break;
        }
        case APIPlaygroundRequestTypeTopLosers:{
            parameters[@"limit"] = @([self.limitField.stringValue integerValue]);
            // CORREZIONE: executeMarketDataRequest
            self.activeRequestID = [downloadManager executeMarketDataRequest:DataRequestTypeTopLosers
                                                                  parameters:parameters
                                                             preferredSource:self.preferredDataSource
                                                                  completion:^(id result, DataSourceType usedSource, NSError *error) {
                [self handleUnifiedResponse:result usedSource:usedSource error:error];
            }];
            break;
        }
        case APIPlaygroundRequestTypeETFList:{
            parameters[@"limit"] = @([self.limitField.stringValue integerValue]);
            // CORREZIONE: executeMarketDataRequest
            self.activeRequestID = [downloadManager executeMarketDataRequest:DataRequestTypeETFList
                                                                  parameters:parameters
                                                             preferredSource:self.preferredDataSource
                                                                  completion:^(id result, DataSourceType usedSource, NSError *error) {
                [self handleUnifiedResponse:result usedSource:usedSource error:error];
            }];
            break;
        }
        // Account requests necessitano gestione diversa
        case APIPlaygroundRequestTypeAccounts:
            [self executeAccountsRequestForAllBrokers];
            return;
            
        case APIPlaygroundRequestTypeAccountDetails:
        case APIPlaygroundRequestTypePositions:
        case APIPlaygroundRequestTypeOrders:
            [self executeAccountDataRequest:self.currentRequestType parameters:parameters];
            return;
            
        default:
            [self handleUnifiedResponse:nil
                             usedSource:DataSourceTypeOther
                                  error:[NSError errorWithDomain:@"APIPlayground"
                                                            code:400
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Request type not implemented yet"}]];
            break;
    }
}

- (void)handleUnifiedResponse:(id)result usedSource:(DataSourceType)usedSource error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.executeButton.enabled = YES;
        self.executeButton.title = @"Execute Request";
        [self.loadingIndicator stopAnimation:nil];
        
        if (error) {
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
            self.statusLabel.textColor = [NSColor systemRedColor];
            self.lastRawResponse = [NSString stringWithFormat:@"ERROR: %@", error.localizedDescription];
        } else {
            NSString *sourceName = [self dataSourceNameForType:usedSource];
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Success via %@", sourceName];
            self.statusLabel.textColor = [NSColor systemGreenColor];
            
            // Populate results
            [self populateTableWithData:result];
            
            // Generate raw response
            NSError *jsonError;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result
                                                               options:NSJSONWritingPrettyPrinted
                                                                 error:&jsonError];
            if (jsonData) {
                self.lastRawResponse = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            } else {
                self.lastRawResponse = [NSString stringWithFormat:@"Result: %@", result];
            }
        }
        
        // Display results
        NSString *summary = [self generateRequestSummary];
        [self displayRawResponse:self.lastRawResponse withSummary:summary];
    });
}

#pragma mark - Results Display

- (void)populateTableWithData:(id)data {
    [self.resultData removeAllObjects];
    
    // Clear existing columns
    for (NSTableColumn *column in [self.resultsTableView.tableColumns copy]) {
        [self.resultsTableView removeTableColumn:column];
    }
    
    if ([data isKindOfClass:[NSArray class]]) {
        NSArray *arrayData = (NSArray *)data;
        if (arrayData.count > 0) {
            // Create columns based on first object
            id firstObject = arrayData[0];
            [self createColumnsForObject:firstObject];
            
            // Add all data
            [self.resultData addObjectsFromArray:arrayData];
        }
    } else if ([data isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictData = (NSDictionary *)data;
        
        if (self.currentRequestType == APIPlaygroundRequestTypeBatchQuotes) {
            // Handle batch quotes - dictionary with symbol keys
            [self createColumnsForBatchQuotes];
            for (NSString *symbol in dictData) {
                MarketData *quote = dictData[symbol];
                if ([quote isKindOfClass:[MarketData class]]) {
                    [self.resultData addObject:@{
                        @"symbol": symbol,
                        @"last": quote.last ?: @0,
                        @"change": quote.change ?: @0,
                        @"changePercent": quote.changePercent ?: @0,
                        @"volume": quote.volume ?: @0,
                        @"bid": quote.bid ?: @0,
                        @"ask": quote.ask ?: @0
                    }];
                }
            }
        } else {
            // Single object - create columns and add to array
            [self createColumnsForObject:dictData];
            [self.resultData addObject:dictData];
        }
    }
    
    [self.resultsTableView reloadData];
}

- (void)createColumnsForObject:(id)object {
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)object;
        NSArray *sortedKeys = [dict.allKeys sortedArrayUsingSelector:@selector(compare:)];
        
        for (NSString *key in sortedKeys) {
            NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:key];
            column.title = [key capitalizedString];
            column.width = [self columnWidthForKey:key];
            [self.resultsTableView addTableColumn:column];
        }
    } else if ([object respondsToSelector:@selector(propertyNames)]) {
        // Handle custom objects with property names method
        NSArray *properties = [object performSelector:@selector(propertyNames)];
        for (NSString *property in properties) {
            NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:property];
            column.title = [property capitalizedString];
            column.width = [self columnWidthForKey:property];
            [self.resultsTableView addTableColumn:column];
        }
    }
}

- (void)createColumnsForBatchQuotes {
    NSArray *columnTitles = @[@"Symbol", @"Last", @"Change", @"Change %", @"Volume", @"Bid", @"Ask"];
    NSArray *columnIDs = @[@"symbol", @"last", @"change", @"changePercent", @"volume", @"bid", @"ask"];
    
    for (NSInteger i = 0; i < columnTitles.count; i++) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:columnIDs[i]];
        column.title = columnTitles[i];
        column.width = [self columnWidthForKey:columnIDs[i]];
        [self.resultsTableView addTableColumn:column];
    }
}

- (CGFloat)columnWidthForKey:(NSString *)key {
    NSDictionary *widths = @{
        @"symbol": @80,
        @"timestamp": @160,
        @"date": @160,
        @"last": @80,
        @"open": @80,
        @"high": @80,
        @"low": @80,
        @"close": @80,
        @"volume": @100,
        @"change": @80,
        @"changePercent": @90,
        @"bid": @80,
        @"ask": @80,
        @"name": @200,
        @"marketCap": @120
    };
    
    NSNumber *width = widths[key.lowercaseString];
    return width ? width.doubleValue : 120; // Default width
}

- (void)displayRawResponse:(NSString *)response withSummary:(NSString *)summary {
    NSMutableString *fullText = [NSMutableString string];
    
    if (summary) {
        [fullText appendString:summary];
        [fullText appendString:@"\n\n"];
        [fullText appendString:@"=== RAW RESPONSE ===\n"];
    }
    
    if (response) {
        [fullText appendString:response];
    } else {
        [fullText appendString:@"No response data"];
    }
    
    self.rawResponseTextView.string = fullText;
}

- (NSString *)generateRequestSummary {
    NSMutableString *summary = [NSMutableString string];
    
    // Request info
    [summary appendFormat:@"=== REQUEST SUMMARY ===\n"];
    [summary appendFormat:@"Request Type: %@\n", [self requestTypeDisplayName]];
    [summary appendFormat:@"Preferred Source: %@\n", [self dataSourceNameForType:self.preferredDataSource]];
    [summary appendFormat:@"Timestamp: %@\n", [NSDate date]];
    
    // Parameters
    [summary appendString:@"\nParameters:\n"];
    switch (self.currentRequestType) {
        case APIPlaygroundRequestTypeQuote:
            [summary appendFormat:@"  Symbol: %@\n", self.symbolField.stringValue];
            break;
            
        case APIPlaygroundRequestTypeBatchQuotes:
            [summary appendFormat:@"  Symbols: %@\n", self.symbolsField.stringValue];
            break;
            
        case APIPlaygroundRequestTypeHistoricalBars:
            [summary appendFormat:@"  Symbol: %@\n", self.symbolField.stringValue];
            [summary appendFormat:@"  Timeframe: %@\n", [self.timeframePopup titleOfSelectedItem]];
            [summary appendFormat:@"  Start Date: %@\n", self.startDatePicker.dateValue];
            [summary appendFormat:@"  End Date: %@\n", self.endDatePicker.dateValue];
            [summary appendFormat:@"  Extended Hours: %@\n", self.extendedHoursCheckbox.state == NSControlStateValueOn ? @"YES" : @"NO"];
            break;
            
        case APIPlaygroundRequestTypeTopGainers:
        case APIPlaygroundRequestTypeTopLosers:
        case APIPlaygroundRequestTypeETFList:
            [summary appendFormat:@"  Max Results: %@\n", self.limitField.stringValue];
            [summary appendFormat:@"  Timeframe: %@\n", [self.marketTimeframePopup titleOfSelectedItem]];
            break;
            
        case APIPlaygroundRequestTypeAccountDetails:
        case APIPlaygroundRequestTypePositions:
        case APIPlaygroundRequestTypeOrders:
            [summary appendFormat:@"  Account ID: %@\n", self.accountIdField.stringValue];
            break;
            
        default:
            [summary appendString:@"  (No specific parameters)\n"];
            break;
    }
    
    // Results summary
    [summary appendFormat:@"\nResults: %lu items\n", (unsigned long)self.resultData.count];
    
    return [summary copy];
}

#pragma mark - NSTableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.resultData.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.resultData.count) return nil;
    
    id rowData = self.resultData[row];
    NSString *columnID = tableColumn.identifier;
    
    if ([rowData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)rowData;
        id value = dict[columnID];
        
        // Format numeric values
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *number = (NSNumber *)value;
            
            if ([columnID containsString:@"percent"] || [columnID containsString:@"Percent"]) {
                return [NSString stringWithFormat:@"%.2f%%", number.doubleValue];
            } else if ([columnID isEqualToString:@"volume"]) {
                return [self formatVolume:number.longLongValue];
            } else if ([columnID containsString:@"price"] ||
                      [columnID isEqualToString:@"last"] ||
                      [columnID isEqualToString:@"open"] ||
                      [columnID isEqualToString:@"high"] ||
                      [columnID isEqualToString:@"low"] ||
                      [columnID isEqualToString:@"close"] ||
                      [columnID isEqualToString:@"bid"] ||
                      [columnID isEqualToString:@"ask"]) {
                return [NSString stringWithFormat:@"%.2f", number.doubleValue];
            }
            
            return [number stringValue];
        } else if ([value isKindOfClass:[NSDate class]]) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            return [formatter stringFromDate:(NSDate *)value];
        }
        
        return [value description] ?: @"";
    }
    
    return @"";
}

#pragma mark - Utility Methods

- (NSString *)formatVolume:(long long)volume {
    if (volume >= 1000000000) {
        return [NSString stringWithFormat:@"%.2fB", volume / 1000000000.0];
    } else if (volume >= 1000000) {
        return [NSString stringWithFormat:@"%.2fM", volume / 1000000.0];
    } else if (volume >= 1000) {
        return [NSString stringWithFormat:@"%.2fK", volume / 1000.0];
    }
    return [NSString stringWithFormat:@"%lld", volume];
}

- (BarTimeframe)selectedBarTimeframe {
    NSString *selected = [self.timeframePopup titleOfSelectedItem];
    
    if ([selected isEqualToString:@"1 Minute"]) return BarTimeframe1Min;
    if ([selected isEqualToString:@"5 Minutes"]) return BarTimeframe5Min;
    if ([selected isEqualToString:@"15 Minutes"]) return BarTimeframe15Min;
    if ([selected isEqualToString:@"30 Minutes"]) return BarTimeframe30Min;
    if ([selected isEqualToString:@"1 Hour"]) return BarTimeframe1Hour;
    if ([selected isEqualToString:@"Daily"]) return BarTimeframeDaily;
    if ([selected isEqualToString:@"Weekly"]) return BarTimeframeWeekly;
    
    return BarTimeframeDaily; // Default
}

- (NSString *)requestTypeDisplayName {
    NSArray *displayNames = @[
        @"Single Quote",
        @"Batch Quotes",
        @"Historical Bars",
        @"Top Gainers",
        @"Top Losers",
        @"ETF List",
        @"52 Week Highs",
        @"Market List",
        @"Accounts",
        @"Account Details",
        @"Positions",
        @"Orders",
        @"Order Book",
        @"Fundamentals"
    ];
    
    if (self.currentRequestType < displayNames.count) {
        return displayNames[self.currentRequestType];
    }
    return @"Unknown";
}

- (NSString *)dataSourceNameForType:(DataSourceType)type {
    switch (type) {
        case DataSourceTypeSchwab: return @"Schwab API";
        case DataSourceTypeIBKR: return @"IBKR API";
        case DataSourceTypeWebull: return @"Webull API";
        case DataSourceTypeYahoo: return @"Yahoo Finance";
        case DataSourceTypeOther: return @"Auto Select";
        default: return @"Unknown";
    }
}

- (void)updateParametersDisplay {
    NSString *parametersText = [NSString stringWithFormat:@"Request: %@ | Source: %@",
                               [self requestTypeDisplayName],
                               [self dataSourceNameForType:self.preferredDataSource]];
    self.parametersLabel.stringValue = parametersText;
}

- (void)copyRawResponseToClipboard {
    if (self.lastRawResponse) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard setString:self.lastRawResponse forType:NSPasteboardTypeString];
        
        self.statusLabel.stringValue = @"Raw response copied to clipboard";
        self.statusLabel.textColor = [NSColor systemBlueColor];
        
        // Reset status after 2 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.statusLabel.stringValue = @"Ready";
            self.statusLabel.textColor = [NSColor systemGreenColor];
        });
    }
}

- (void)clearAllResults {
    [self.resultData removeAllObjects];
    [self.resultsTableView reloadData];
    self.rawResponseTextView.string = @"";
    self.lastRawResponse = nil;
    
    self.statusLabel.stringValue = @"Ready";
    self.statusLabel.textColor = [NSColor systemGreenColor];
}

#pragma mark - Helper Methods (from existing code)

- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:12];
    return label;
}

- (NSTextField *)createTextField:(NSString *)placeholder {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = placeholder;
    textField.stringValue = placeholder;
    return textField;
}

- (NSStackView *)createHorizontalStack:(NSArray<NSView *> *)views {
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.spacing = 8;
    stack.alignment = NSLayoutAttributeCenterY;
    
    for (NSView *view in views) {
        [stack addArrangedSubview:view];
    }
    
    return stack;
}

#pragma mark - Request Cancellation

- (void)cancelActiveRequest {
    if (self.activeRequestID) {
        [[DownloadManager sharedManager] cancelRequest:self.activeRequestID];
        self.activeRequestID = nil;
        
        self.executeButton.enabled = YES;
        self.executeButton.title = @"Execute Request";
        [self.loadingIndicator stopAnimation:nil];
        
        self.statusLabel.stringValue = @"Request cancelled";
        self.statusLabel.textColor = [NSColor systemOrangeColor];
    }
}

#pragma mark - Widget Lifecycle

- (void)dealloc {
    [self cancelActiveRequest];
}

- (NSDictionary *)serializeState {
    return @{
        @"widgetType": self.widgetType,
        @"currentRequestType": @(self.currentRequestType),
        @"preferredDataSource": @(self.preferredDataSource),
        @"symbol": self.symbolField.stringValue ?: @"",
        @"symbols": self.symbolsField.stringValue ?: @""
    };
}

- (void)restoreState:(NSDictionary *)state {
    if (state[@"currentRequestType"]) {
        self.currentRequestType = [state[@"currentRequestType"] integerValue];
        [self.requestTypePopup selectItemAtIndex:self.currentRequestType];
    }
    
    if (state[@"preferredDataSource"]) {
        self.preferredDataSource = [state[@"preferredDataSource"] integerValue];
        // Update popup selection based on data source type
        NSInteger popupIndex = 0; // Auto select
        switch (self.preferredDataSource) {
            case DataSourceTypeSchwab: popupIndex = 1; break;
            case DataSourceTypeIBKR: popupIndex = 2; break;
            case DataSourceTypeWebull: popupIndex = 3; break;
            case DataSourceTypeOther: popupIndex = 4; break;
            default: popupIndex = 0; break;
        }
        [self.dataSourcePopup selectItemAtIndex:popupIndex];
    }
    
    if (state[@"symbol"]) {
        self.symbolField.stringValue = state[@"symbol"];
    }
    
    if (state[@"symbols"]) {
        self.symbolsField.stringValue = state[@"symbols"];
    }
    
    [self updateControlsVisibilityForRequestType:self.currentRequestType];
    [self updateParametersDisplay];
}

@end
