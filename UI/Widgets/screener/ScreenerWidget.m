//
//  ScreenerWidget.m
//  TradingApp
//
//  Yahoo Finance Stock Screener Widget Implementation
//


#import <objc/runtime.h>
#import "ScreenerWidget.h"
#import "DataHub.h"
#import "YahooScreenerAPI.h"


// ============================================================================
// YAHOO SCREENER FILTER IMPLEMENTATION
// ============================================================================

@implementation YahooScreenerFilter
@end

// ============================================================================
// YAHOO SCREENER RESULT IMPLEMENTATION
// ============================================================================

@implementation YahooScreenerResult

+ (instancetype)resultFromYahooData:(NSDictionary *)data {
    YahooScreenerResult *result = [[YahooScreenerResult alloc] init];
    
    result.symbol = data[@"symbol"] ?: @"";
    result.name = data[@"longName"] ?: data[@"shortName"] ?: @"";
    result.price = data[@"regularMarketPrice"] ?: @0;
    result.change = data[@"regularMarketChange"] ?: @0;
    result.changePercent = data[@"regularMarketChangePercent"] ?: @0;
    result.volume = data[@"regularMarketVolume"] ?: @0;
    result.marketCap = data[@"marketCap"] ?: @0;
    result.sector = data[@"sector"] ?: @"";
    result.exchange = data[@"fullExchangeName"] ?: @"";
    
    return result;
}

@end

// ============================================================================
// MAIN WIDGET IMPLEMENTATION
// ============================================================================

@interface ScreenerWidget ()

// UI Components - Main Tab
@property (nonatomic, strong) NSTabView *tabView;
@property (nonatomic, strong) NSTableView *resultsTable;
@property (nonatomic, strong) NSScrollView *tableScrollView;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *exportButton;

// UI Components - Filter Tab
@property (nonatomic, strong) NSView *filtersTabView;
@property (nonatomic, strong) NSPopUpButton *screenerTypePopup;
@property (nonatomic, strong) NSTextField *maxResultsField;
@property (nonatomic, strong) NSButton *autoRefreshCheckbox;

// Quick Filters
@property (nonatomic, strong) NSTextField *minVolumeField;
@property (nonatomic, strong) NSTextField *minMarketCapField;
@property (nonatomic, strong) NSPopUpButton *sectorPopup;
@property (nonatomic, strong) NSButton *applyFiltersButton;
@property (nonatomic, strong) NSButton *clearFiltersButton;

// Data
@property (nonatomic, strong) NSMutableArray<YahooScreenerResult *> *currentResults;
@property (nonatomic, strong) NSMutableArray<YahooScreenerFilter *> *activeFilters;
@property (nonatomic, strong) NSTimer *refreshTimer;

@end

@implementation ScreenerWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Screener";
        
        // Initialize properties
        _screenerType = YahooScreenerTypeMostActive;
        _maxResults = 100;
        _autoRefresh = NO;
        _currentResults = [NSMutableArray array];
        _activeFilters = [NSMutableArray array];
        
        // Configure API if needed
        YahooScreenerAPI *api = [YahooScreenerAPI sharedManager];
        if ([api.baseURL containsString:@"your-backend"]) {
            NSLog(@"⚠️ ScreenerWidget: Please configure YahooScreenerAPI baseURL in YahooScreenerAPI.m");
        }
        
        // Setup UI
        [self loadView];
        [self setupUI];
        
        // Initial data load (will show connection status)
        [self refreshData];
    }
    return self;
}

- (void)updateAPIStatus:(NSString *)status color:(NSColor *)color {
    NSTextField *statusField = self.apiStatusValueField;
    if (statusField) {
        dispatch_async(dispatch_get_main_queue(), ^{
            statusField.stringValue = status;
            statusField.textColor = color;
        });
    }
}

- (void)dealloc {
    [self.refreshTimer invalidate];
}

#pragma mark - UI Setup

- (void)setupUI {
    // Create main tab view
    self.tabView = [[NSTabView alloc] init];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.tabView];
    
    // Setup tabs
    [self setupResultsTab];
    [self setupFiltersTab];
    
    // Tab view constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.tabView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.tabView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];
    [[YahooScreenerAPI sharedManager] checkServiceAvailability:^(BOOL available, NSString *version) {
           dispatch_async(dispatch_get_main_queue(), ^{
               if (available) {
                   NSLog(@"✅ Yahoo Screener API service available (version: %@)", version ?: @"unknown");
                   self.statusLabel.stringValue = @"Ready - API service connected";
               } else {
                   NSLog(@"❌ Yahoo Screener API service unavailable");
                   self.statusLabel.stringValue = @"Warning - API service unavailable";
                   self.statusLabel.textColor = [NSColor systemOrangeColor];
               }
           });
       }];

}


- (IBAction)testConnectionButtonClicked:(id)sender {
    self.statusLabel.stringValue = @"Testing connection...";
    
    [[YahooScreenerAPI sharedManager] checkServiceAvailability:^(BOOL available, NSString *version) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            if (available) {
                alert.messageText = @"Connection Successful";
                alert.informativeText = [NSString stringWithFormat:@"API service is available\nVersion: %@", version ?: @"unknown"];
                self.statusLabel.stringValue = @"Connected";
                self.statusLabel.textColor = [NSColor systemGreenColor];
            } else {
                alert.messageText = @"Connection Failed";
                alert.informativeText = @"Unable to reach Yahoo Screener API service. Please check your internet connection and backend service.";
                self.statusLabel.stringValue = @"Connection failed";
                self.statusLabel.textColor = [NSColor systemRedColor];
            }
            [alert runModal];
        });
    }];
}


#pragma mark - Results Tab Setup

- (void)setupResultsTab {
    NSTabViewItem *resultsTab = [[NSTabViewItem alloc] initWithIdentifier:@"results"];
    resultsTab.label = @"Results";
    
    NSView *resultsView = [[NSView alloc] init];
    
    // Top controls
    NSView *controlsView = [[NSView alloc] init];
    controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [resultsView addSubview:controlsView];
    
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.editable = NO;
    self.statusLabel.bezeled = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.font = [NSFont systemFontOfSize:12];
    self.statusLabel.stringValue = @"Loading...";
    [controlsView addSubview:self.statusLabel];
    
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.refreshButton.title = @"🔄 Refresh";
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshButtonClicked:);
    [controlsView addSubview:self.refreshButton];
    
    self.exportButton = [[NSButton alloc] init];
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.exportButton.title = @"📄 Export CSV";
    self.exportButton.bezelStyle = NSBezelStyleRounded;
    self.exportButton.target = self;
    self.exportButton.action = @selector(exportButtonClicked:);
    [controlsView addSubview:self.exportButton];
    
    // Results table
    self.resultsTable = [[NSTableView alloc] init];
    self.resultsTable.delegate = self;
    self.resultsTable.dataSource = self;
    self.resultsTable.headerView = [[NSTableHeaderView alloc] init];
    self.resultsTable.usesAlternatingRowBackgroundColors = YES;
    
    [self setupTableColumns];
    
    self.tableScrollView = [[NSScrollView alloc] init];
    self.tableScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableScrollView.documentView = self.resultsTable;
    self.tableScrollView.hasVerticalScroller = YES;
    self.tableScrollView.hasHorizontalScroller = YES;
    self.tableScrollView.autohidesScrollers = YES;
    [resultsView addSubview:self.tableScrollView];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Controls view
        [controlsView.topAnchor constraintEqualToAnchor:resultsView.topAnchor constant:12],
        [controlsView.leadingAnchor constraintEqualToAnchor:resultsView.leadingAnchor constant:12],
        [controlsView.trailingAnchor constraintEqualToAnchor:resultsView.trailingAnchor constant:-12],
        [controlsView.heightAnchor constraintEqualToConstant:40],
        
        // Status label
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:controlsView.leadingAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor],
        
        // Export button
        [self.exportButton.trailingAnchor constraintEqualToAnchor:controlsView.trailingAnchor],
        [self.exportButton.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor],
        [self.exportButton.widthAnchor constraintEqualToConstant:120],
        
        // Refresh button
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.exportButton.leadingAnchor constant:-8],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor],
        [self.refreshButton.widthAnchor constraintEqualToConstant:100],
        
        // Table scroll view
        [self.tableScrollView.topAnchor constraintEqualToAnchor:controlsView.bottomAnchor constant:8],
        [self.tableScrollView.leadingAnchor constraintEqualToAnchor:resultsView.leadingAnchor constant:12],
        [self.tableScrollView.trailingAnchor constraintEqualToAnchor:resultsView.trailingAnchor constant:-12],
        [self.tableScrollView.bottomAnchor constraintEqualToAnchor:resultsView.bottomAnchor constant:-12]
    ]];
    
    resultsTab.view = resultsView;
    [self.tabView addTabViewItem:resultsTab];
}

#pragma mark - Filters Tab Setup

- (void)setupFiltersTab {
    NSTabViewItem *filtersTab = [[NSTabViewItem alloc] initWithIdentifier:@"filters"];
    filtersTab.label = @"Filters";
    
    self.filtersTabView = [[NSView alloc] init];
    
    // Screener Type section
    NSTextField *typeLabel = [self createLabel:@"Screener Type:"];
    [self.filtersTabView addSubview:typeLabel];
    
    self.screenerTypePopup = [[NSPopUpButton alloc] init];
    self.screenerTypePopup.translatesAutoresizingMaskIntoConstraints = NO;
       [self.screenerTypePopup addItemWithTitle:@"Most Active"];
       [self.screenerTypePopup addItemWithTitle:@"Top Gainers"];
       [self.screenerTypePopup addItemWithTitle:@"Top Losers"];
       [self.screenerTypePopup addItemWithTitle:@"Undervalued"];
       [self.screenerTypePopup addItemWithTitle:@"Growth Tech"];
       [self.screenerTypePopup addItemWithTitle:@"High Dividend"];
       [self.screenerTypePopup addItemWithTitle:@"Small Cap Growth"];
       [self.screenerTypePopup addItemWithTitle:@"Most Shorted"];
       [self.screenerTypePopup addItemWithTitle:@"Custom"];
    self.screenerTypePopup.target = self;
    self.screenerTypePopup.action = @selector(screenerTypeChanged:);
    [self.filtersTabView addSubview:self.screenerTypePopup];
    
    // Settings section
    NSTextField *settingsLabel = [self createLabel:@"Settings:"];
    [self.filtersTabView addSubview:settingsLabel];
    
    NSTextField *maxResultsLabel = [self createLabel:@"Max Results:"];
    [self.filtersTabView addSubview:maxResultsLabel];
    
    self.maxResultsField = [[NSTextField alloc] init];
    self.maxResultsField.translatesAutoresizingMaskIntoConstraints = NO;
    self.maxResultsField.stringValue = @"100";
    [self.filtersTabView addSubview:self.maxResultsField];
    
    self.autoRefreshCheckbox = [[NSButton alloc] init];
    self.autoRefreshCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.autoRefreshCheckbox.buttonType = NSButtonTypeSwitch;
    self.autoRefreshCheckbox.title = @"Auto-refresh (30s)";
    self.autoRefreshCheckbox.target = self;
    self.autoRefreshCheckbox.action = @selector(autoRefreshChanged:);
    [self.filtersTabView addSubview:self.autoRefreshCheckbox];
    
    // Quick Filters section
    NSTextField *quickFiltersLabel = [self createLabel:@"Quick Filters:"];
    [self.filtersTabView addSubview:quickFiltersLabel];
    
    NSTextField *minVolumeLabel = [self createLabel:@"Min Volume:"];
    [self.filtersTabView addSubview:minVolumeLabel];
    
    self.minVolumeField = [[NSTextField alloc] init];
    self.minVolumeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.minVolumeField.placeholderString = @"e.g. 1000000";
    [self.filtersTabView addSubview:self.minVolumeField];
    
    NSTextField *minMarketCapLabel = [self createLabel:@"Min Market Cap:"];
    [self.filtersTabView addSubview:minMarketCapLabel];
    
    self.minMarketCapField = [[NSTextField alloc] init];
    self.minMarketCapField.translatesAutoresizingMaskIntoConstraints = NO;
    self.minMarketCapField.placeholderString = @"e.g. 1000000000";
    [self.filtersTabView addSubview:self.minMarketCapField];
    
    NSTextField *sectorLabel = [self createLabel:@"Sector:"];
    [self.filtersTabView addSubview:sectorLabel];
    
    self.sectorPopup = [[NSPopUpButton alloc] init];
    self.sectorPopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sectorPopup addItemWithTitle:@"All Sectors"];
    [self.sectorPopup addItemWithTitle:@"Technology"];
    [self.sectorPopup addItemWithTitle:@"Healthcare"];
    [self.sectorPopup addItemWithTitle:@"Financial Services"];
    [self.sectorPopup addItemWithTitle:@"Consumer Cyclical"];
    [self.sectorPopup addItemWithTitle:@"Energy"];
    [self.sectorPopup addItemWithTitle:@"Industrials"];
    [self.filtersTabView addSubview:self.sectorPopup];
    
    // Filter action buttons
    self.applyFiltersButton = [[NSButton alloc] init];
    self.applyFiltersButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyFiltersButton.title = @"Apply Filters";
    self.applyFiltersButton.bezelStyle = NSBezelStyleRounded;
    self.applyFiltersButton.target = self;
    self.applyFiltersButton.action = @selector(applyFiltersButtonClicked:);
    [self.filtersTabView addSubview:self.applyFiltersButton];
    
    self.clearFiltersButton = [[NSButton alloc] init];
    self.clearFiltersButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.clearFiltersButton.title = @"Clear Filters";
    self.clearFiltersButton.bezelStyle = NSBezelStyleRounded;
    self.clearFiltersButton.target = self;
    self.clearFiltersButton.action = @selector(clearFiltersButtonClicked:);
    [self.filtersTabView addSubview:self.clearFiltersButton];
    NSTextField *apiConfigLabel = [self createLabel:@"API Configuration:"];
      [self.filtersTabView addSubview:apiConfigLabel];
      
      // Test connection button
      NSButton *testConnectionButton = [[NSButton alloc] init];
      testConnectionButton.translatesAutoresizingMaskIntoConstraints = NO;
      testConnectionButton.title = @"Test Connection";
      testConnectionButton.bezelStyle = NSBezelStyleRounded;
      testConnectionButton.target = self;
      testConnectionButton.action = @selector(testConnectionButtonClicked:);
      [self.filtersTabView addSubview:testConnectionButton];
      
      // Cache control
      NSButton *clearCacheButton = [[NSButton alloc] init];
      clearCacheButton.translatesAutoresizingMaskIntoConstraints = NO;
      clearCacheButton.title = @"Clear Cache";
      clearCacheButton.bezelStyle = NSBezelStyleRounded;
      clearCacheButton.target = self;
      clearCacheButton.action = @selector(clearCacheButtonClicked:);
      [self.filtersTabView addSubview:clearCacheButton];
      
      // API Status indicator
      NSTextField *apiStatusLabel = [self createLabel:@"API Status:"];
      [self.filtersTabView addSubview:apiStatusLabel];
      
      NSTextField *apiStatusValue = [[NSTextField alloc] init];
      apiStatusValue.translatesAutoresizingMaskIntoConstraints = NO;
      apiStatusValue.editable = NO;
      apiStatusValue.bezeled = NO;
      apiStatusValue.backgroundColor = [NSColor clearColor];
      apiStatusValue.font = [NSFont systemFontOfSize:11];
      apiStatusValue.stringValue = @"Checking...";
      apiStatusValue.textColor = [NSColor secondaryLabelColor];
      [self.filtersTabView addSubview:apiStatusValue];
      
      // Store reference for status updates
    self.apiStatusValueField = apiStatusValue;
          // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Screener Type
        [typeLabel.topAnchor constraintEqualToAnchor:self.filtersTabView.topAnchor constant:20],
        [typeLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        
        [self.screenerTypePopup.topAnchor constraintEqualToAnchor:typeLabel.bottomAnchor constant:8],
        [self.screenerTypePopup.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        [self.screenerTypePopup.trailingAnchor constraintEqualToAnchor:self.filtersTabView.trailingAnchor constant:-20],
        
        // Settings
        [settingsLabel.topAnchor constraintEqualToAnchor:self.screenerTypePopup.bottomAnchor constant:20],
        [settingsLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        
        [maxResultsLabel.topAnchor constraintEqualToAnchor:settingsLabel.bottomAnchor constant:8],
        [maxResultsLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        
        [self.maxResultsField.centerYAnchor constraintEqualToAnchor:maxResultsLabel.centerYAnchor],
        [self.maxResultsField.leadingAnchor constraintEqualToAnchor:maxResultsLabel.trailingAnchor constant:8],
        [self.maxResultsField.widthAnchor constraintEqualToConstant:80],
        
        [self.autoRefreshCheckbox.topAnchor constraintEqualToAnchor:maxResultsLabel.bottomAnchor constant:8],
        [self.autoRefreshCheckbox.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        
        // Quick Filters
        [quickFiltersLabel.topAnchor constraintEqualToAnchor:self.autoRefreshCheckbox.bottomAnchor constant:20],
        [quickFiltersLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        
        [minVolumeLabel.topAnchor constraintEqualToAnchor:quickFiltersLabel.bottomAnchor constant:8],
        [minVolumeLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        
        [self.minVolumeField.centerYAnchor constraintEqualToAnchor:minVolumeLabel.centerYAnchor],
        [self.minVolumeField.leadingAnchor constraintEqualToAnchor:minVolumeLabel.trailingAnchor constant:8],
        [self.minVolumeField.trailingAnchor constraintEqualToAnchor:self.filtersTabView.trailingAnchor constant:-20],
        
        [minMarketCapLabel.topAnchor constraintEqualToAnchor:minVolumeLabel.bottomAnchor constant:8],
        [minMarketCapLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        
        [self.minMarketCapField.centerYAnchor constraintEqualToAnchor:minMarketCapLabel.centerYAnchor],
        [self.minMarketCapField.leadingAnchor constraintEqualToAnchor:minMarketCapLabel.trailingAnchor constant:8],
        [self.minMarketCapField.trailingAnchor constraintEqualToAnchor:self.filtersTabView.trailingAnchor constant:-20],
        
        [sectorLabel.topAnchor constraintEqualToAnchor:minMarketCapLabel.bottomAnchor constant:8],
        [sectorLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        
        [self.sectorPopup.centerYAnchor constraintEqualToAnchor:sectorLabel.centerYAnchor],
        [self.sectorPopup.leadingAnchor constraintEqualToAnchor:sectorLabel.trailingAnchor constant:8],
        [self.sectorPopup.trailingAnchor constraintEqualToAnchor:self.filtersTabView.trailingAnchor constant:-20],
        
        // Action buttons
        [self.applyFiltersButton.topAnchor constraintEqualToAnchor:self.sectorPopup.bottomAnchor constant:20],
        [self.applyFiltersButton.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
        [self.applyFiltersButton.widthAnchor constraintEqualToConstant:120],
        
        [self.clearFiltersButton.centerYAnchor constraintEqualToAnchor:self.applyFiltersButton.centerYAnchor],
        [self.clearFiltersButton.leadingAnchor constraintEqualToAnchor:self.applyFiltersButton.trailingAnchor constant:12],
        [self.clearFiltersButton.widthAnchor constraintEqualToConstant:120],
        // API Configuration section
              [apiConfigLabel.topAnchor constraintEqualToAnchor:self.clearFiltersButton.bottomAnchor constant:30],
              [apiConfigLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
              
              [testConnectionButton.topAnchor constraintEqualToAnchor:apiConfigLabel.bottomAnchor constant:8],
              [testConnectionButton.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
              [testConnectionButton.widthAnchor constraintEqualToConstant:140],
              
              [clearCacheButton.centerYAnchor constraintEqualToAnchor:testConnectionButton.centerYAnchor],
              [clearCacheButton.leadingAnchor constraintEqualToAnchor:testConnectionButton.trailingAnchor constant:12],
              [clearCacheButton.widthAnchor constraintEqualToConstant:120],
              
              [apiStatusLabel.topAnchor constraintEqualToAnchor:testConnectionButton.bottomAnchor constant:12],
              [apiStatusLabel.leadingAnchor constraintEqualToAnchor:self.filtersTabView.leadingAnchor constant:20],
              
              [apiStatusValue.centerYAnchor constraintEqualToAnchor:apiStatusLabel.centerYAnchor],
              [apiStatusValue.leadingAnchor constraintEqualToAnchor:apiStatusLabel.trailingAnchor constant:8],
              [apiStatusValue.trailingAnchor constraintEqualToAnchor:self.filtersTabView.trailingAnchor constant:-20]
    ]];
    
    filtersTab.view = self.filtersTabView;
    [self.tabView addTabViewItem:filtersTab];
}

- (IBAction)clearCacheButtonClicked:(id)sender {
    [[YahooScreenerAPI sharedManager] clearCache];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Cache Cleared";
    alert.informativeText = @"All cached screener results have been cleared. Next requests will fetch fresh data.";
    [alert runModal];
    
    NSLog(@"🗑️ ScreenerWidget: Cache cleared by user");
}


#pragma mark - Table Setup

- (void)setupTableColumns {
    // Symbol column
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    [self.resultsTable addTableColumn:symbolColumn];
    
    // Name column
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = @"Name";
    nameColumn.width = 180;
    nameColumn.minWidth = 120;
    [self.resultsTable addTableColumn:nameColumn];
    
    // Price column
    NSTableColumn *priceColumn = [[NSTableColumn alloc] initWithIdentifier:@"price"];
    priceColumn.title = @"Price";
    priceColumn.width = 80;
    priceColumn.minWidth = 60;
    [self.resultsTable addTableColumn:priceColumn];
    
    // Change % column
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"changePercent"];
    changeColumn.title = @"Change %";
    changeColumn.width = 80;
    changeColumn.minWidth = 60;
    [self.resultsTable addTableColumn:changeColumn];
    
    // Volume column
    NSTableColumn *volumeColumn = [[NSTableColumn alloc] initWithIdentifier:@"volume"];
    volumeColumn.title = @"Volume";
    volumeColumn.width = 100;
    volumeColumn.minWidth = 80;
    [self.resultsTable addTableColumn:volumeColumn];
    
    // Market Cap column
    NSTableColumn *marketCapColumn = [[NSTableColumn alloc] initWithIdentifier:@"marketCap"];
    marketCapColumn.title = @"Market Cap";
    marketCapColumn.width = 120;
    marketCapColumn.minWidth = 80;
    [self.resultsTable addTableColumn:marketCapColumn];
    
    // Sector column
    NSTableColumn *sectorColumn = [[NSTableColumn alloc] initWithIdentifier:@"sector"];
    sectorColumn.title = @"Sector";
    sectorColumn.width = 120;
    sectorColumn.minWidth = 80;
    [self.resultsTable addTableColumn:sectorColumn];
}

#pragma mark - Helper Methods

- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.editable = NO;
    label.bezeled = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    label.stringValue = text;
    return label;
}

#pragma mark - Data Methods

- (void)refreshData {
    self.statusLabel.stringValue = @"Loading...";
    [self.refreshButton setEnabled:NO];
    
    // Convert widget screener type to API preset
    YahooScreenerPreset preset = [self convertScreenerTypeToPreset:self.screenerType];
    
    // Check if we have active filters - use appropriate API method
    if (self.activeFilters.count > 0) {
        // Use custom screener with filters
        [[YahooScreenerAPI sharedManager] fetchCustomScreenerWithFilters:self.activeFilters
                                                              maxResults:self.maxResults
                                                              completion:^(NSArray<YahooScreenerResult *> *results, NSError *error) {
            [self handleScreenerResults:results error:error];
        }];
    } else {
        // Use preset screener
        [[YahooScreenerAPI sharedManager] fetchScreenerResults:preset
                                                    maxResults:self.maxResults
                                                    completion:^(NSArray<YahooScreenerResult *> *results, NSError *error) {
            [self handleScreenerResults:results error:error];
        }];
    }
}


- (void)handleScreenerResults:(NSArray<YahooScreenerResult *> *)results error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshButton setEnabled:YES];
        
        if (error) {
            NSLog(@"❌ ScreenerWidget: Failed to fetch results: %@", error.localizedDescription);
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
            
            // Show error alert
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Screener Error";
            alert.informativeText = error.localizedDescription;
            [alert runModal];
            
            return;
        }
        
        // Update results
        [self.currentResults removeAllObjects];
        [self.currentResults addObjectsFromArray:results];
        
        // Update UI
        [self.resultsTable reloadData];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Loaded %lu results", (unsigned long)self.currentResults.count];
        
        NSLog(@"✅ ScreenerWidget: Successfully loaded %lu results", (unsigned long)results.count);
    });
}

// 4. Aggiungere metodo di conversione:
- (YahooScreenerPreset)convertScreenerTypeToPreset:(YahooScreenerType)type {
    // Se è custom, usa l'indice del popup per determinare il preset reale
    if (type == YahooScreenerTypeCustom) {
        NSInteger selectedIndex = self.screenerTypePopup.indexOfSelectedItem;
        switch (selectedIndex) {
            case 3: return YahooScreenerPresetUndervalued;
            case 4: return YahooScreenerPresetGrowthTech;
            case 5: return YahooScreenerPresetHighDividend;
            case 6: return YahooScreenerPresetSmallCapGrowth;
            case 7: return YahooScreenerPresetMostShorted;
            case 8: return YahooScreenerPresetCustom;
            default: return YahooScreenerPresetMostActive;
        }
    }
    
    // Standard mapping
    switch (type) {
        case YahooScreenerTypeMostActive:
            return YahooScreenerPresetMostActive;
        case YahooScreenerTypeGainers:
            return YahooScreenerPresetGainers;
        case YahooScreenerTypeLosers:
            return YahooScreenerPresetLosers;
        case YahooScreenerTypeCustom:
            return YahooScreenerPresetCustom;
        default:
            return YahooScreenerPresetMostActive;
    }
}

- (void)loadSampleData {
    // Dati di esempio per testing UI
    [self.currentResults removeAllObjects];
    
    NSArray *sampleData = @[
        @{@"symbol": @"AAPL", @"longName": @"Apple Inc.", @"regularMarketPrice": @150.25, @"regularMarketChangePercent": @2.1, @"regularMarketVolume": @45000000, @"marketCap": @2400000000000, @"sector": @"Technology"},
        @{@"symbol": @"MSFT", @"longName": @"Microsoft Corporation", @"regularMarketPrice": @280.50, @"regularMarketChangePercent": @1.8, @"regularMarketVolume": @32000000, @"marketCap": @2100000000000, @"sector": @"Technology"},
        @{@"symbol": @"GOOGL", @"longName": @"Alphabet Inc.", @"regularMarketPrice": @2650.00, @"regularMarketChangePercent": @-0.5, @"regularMarketVolume": @1500000, @"marketCap": @1750000000000, @"sector": @"Technology"}
    ];
    
    for (NSDictionary *data in sampleData) {
        YahooScreenerResult *result = [YahooScreenerResult resultFromYahooData:data];
        [self.currentResults addObject:result];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.resultsTable reloadData];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Loaded %lu results", (unsigned long)self.currentResults.count];
    });
}

#pragma mark - Action Methods

- (IBAction)refreshButtonClicked:(id)sender {
    [self refreshData];
}

- (IBAction)exportButtonClicked:(id)sender {
    [self exportResultsToCSV];
}

- (IBAction)screenerTypeChanged:(id)sender {
    NSInteger selectedIndex = self.screenerTypePopup.indexOfSelectedItem;
    
    // Map popup index to screener type
    switch (selectedIndex) {
        case 0: self.screenerType = YahooScreenerTypeMostActive; break;
        case 1: self.screenerType = YahooScreenerTypeGainers; break;
        case 2: self.screenerType = YahooScreenerTypeLosers; break;
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
            // For new presets, treat as custom for now
            self.screenerType = YahooScreenerTypeCustom;
            break;
        case 8: self.screenerType = YahooScreenerTypeCustom; break;
        default: self.screenerType = YahooScreenerTypeMostActive; break;
    }
    
    NSLog(@"🎯 ScreenerWidget: Changed screener type to index %ld", (long)selectedIndex);
    [self refreshData];
}
- (IBAction)autoRefreshChanged:(id)sender {
    self.autoRefresh = (self.autoRefreshCheckbox.state == NSControlStateValueOn);
    
    [self updateAutoRefreshTimer];
}

- (IBAction)applyFiltersButtonClicked:(id)sender {
    [self applyQuickFilters];
}

- (IBAction)clearFiltersButtonClicked:(id)sender {
    [self clearFilters];
}

#pragma mark - Filter Methods

- (void)updateAutoRefreshTimer {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    
    if (self.autoRefresh) {
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                             target:self
                                                           selector:@selector(refreshData)
                                                           userInfo:nil
                                                            repeats:YES];
        NSLog(@"📡 ScreenerWidget: Auto-refresh enabled (30s)");
    } else {
        NSLog(@"⏸️ ScreenerWidget: Auto-refresh disabled");
    }
}

- (void)applyQuickFilters {
    // Get filter values from UI
    NSNumber *minVolume = nil;
    NSNumber *minMarketCap = nil;
    NSString *sector = nil;
    
    NSString *minVolumeText = self.minVolumeField.stringValue;
    if (minVolumeText.length > 0) {
        double value = [minVolumeText doubleValue];
        if (value > 0) {
            minVolume = @(value);
        }
    }
    
    NSString *minMarketCapText = self.minMarketCapField.stringValue;
    if (minMarketCapText.length > 0) {
        double value = [minMarketCapText doubleValue];
        if (value > 0) {
            minMarketCap = @(value);
        }
    }
    
    NSString *selectedSector = self.sectorPopup.titleOfSelectedItem;
    if (![selectedSector isEqualToString:@"All Sectors"]) {
        sector = selectedSector;
    }
    
    // Max Results
    NSInteger maxResults = [self.maxResultsField.stringValue integerValue];
    if (maxResults > 0) {
        self.maxResults = maxResults;
    }
    
    // Show loading
    self.statusLabel.stringValue = @"Applying filters...";
    [self.refreshButton setEnabled:NO];
    
    // Convert screener type to preset
    YahooScreenerPreset preset = [self convertScreenerTypeToPreset:self.screenerType];
    
    // Use quick screener API
    [[YahooScreenerAPI sharedManager] fetchQuickScreener:preset
                                               minVolume:minVolume
                                            minMarketCap:minMarketCap
                                                  sector:sector
                                              maxResults:self.maxResults
                                              completion:^(NSArray<YahooScreenerResult *> *results, NSError *error) {
        [self handleScreenerResults:results error:error];
    }];
    
    NSLog(@"🔍 ScreenerWidget: Applied quick filters - Volume: %@, MarketCap: %@, Sector: %@",
          minVolume, minMarketCap, sector ?: @"All");
}

- (void)addFilter:(YahooScreenerFilter *)filter {
    [self.activeFilters addObject:filter];
    NSLog(@"📊 ScreenerWidget: Added filter for %@ with comparison %ld", filter.field, (long)filter.comparison);
}

- (void)clearFilters {
    [self.activeFilters removeAllObjects];
    
    // Reset UI
    self.minVolumeField.stringValue = @"";
    self.minMarketCapField.stringValue = @"";
    [self.sectorPopup selectItemAtIndex:0]; // "All Sectors"
    
    NSLog(@"🗑️ ScreenerWidget: Cleared all filters");
}

- (void)applyQuickFilterMinVolume:(NSNumber *)minVolume {
    YahooScreenerFilter *filter = [[YahooScreenerFilter alloc] init];
    filter.field = @"dayvolume";
    filter.comparison = YahooFilterGreaterThan;
    filter.values = @[minVolume];
    [self addFilter:filter];
}

- (void)applyQuickFilterMinMarketCap:(NSNumber *)minMarketCap {
    YahooScreenerFilter *filter = [[YahooScreenerFilter alloc] init];
    filter.field = @"intradaymarketcap";
    filter.comparison = YahooFilterGreaterThan;
    filter.values = @[minMarketCap];
    [self addFilter:filter];
}

- (void)applyQuickFilterSector:(NSString *)sector {
    YahooScreenerFilter *filter = [[YahooScreenerFilter alloc] init];
    filter.field = @"sector";
    filter.comparison = YahooFilterEqual;
    filter.values = @[sector];
    [self addFilter:filter];
}

- (void)setScreenerType:(YahooScreenerType)type {
    _screenerType = type;
    [self.screenerTypePopup selectItemAtIndex:(NSInteger)type];
    NSLog(@"🎯 ScreenerWidget: Changed screener type to %ld", (long)type);
}

#pragma mark - Export Methods

- (void)exportResultsToCSV {
    if (self.currentResults.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Data to Export";
        alert.informativeText = @"Please load some data first before exporting.";
        [alert runModal];
        return;
    }
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"csv"];
    savePanel.nameFieldStringValue = [NSString stringWithFormat:@"screener_results_%@.csv",
                                     [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                                     dateStyle:NSDateFormatterShortStyle
                                                                     timeStyle:NSDateFormatterNoStyle]];
    
    [savePanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSURL *url = savePanel.URL;
            [self exportDataToURL:url];
        }
    }];
}

- (void)exportDataToURL:(NSURL *)url {
    NSMutableString *csvContent = [NSMutableString string];
    
    // Header
    [csvContent appendString:@"Symbol,Name,Price,Change %,Volume,Market Cap,Sector\n"];
    
    // Data rows
    for (YahooScreenerResult *result in self.currentResults) {
        NSString *marketCapFormatted = [self formatMarketCap:result.marketCap];
        NSString *volumeFormatted = [self formatNumber:result.volume];
        
        [csvContent appendFormat:@"%@,\"%@\",%.2f,%.2f,%@,%@,\"%@\"\n",
         result.symbol,
         result.name,
         result.price.doubleValue,
         result.changePercent.doubleValue,
         volumeFormatted,
         marketCapFormatted,
         result.sector];
    }
    
    NSError *error;
    BOOL success = [csvContent writeToURL:url
                               atomically:YES
                                 encoding:NSUTF8StringEncoding
                                    error:&error];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        if (success) {
            alert.messageText = @"Export Successful";
            alert.informativeText = [NSString stringWithFormat:@"Exported %lu results to %@",
                                   (unsigned long)self.currentResults.count, url.lastPathComponent];
        } else {
            alert.messageText = @"Export Failed";
            alert.informativeText = error.localizedDescription;
        }
        [alert runModal];
    });
}

#pragma mark - Formatting Helpers

- (NSString *)formatMarketCap:(NSNumber *)marketCap {
    double value = marketCap.doubleValue;
    if (value >= 1e12) {
        return [NSString stringWithFormat:@"$%.2fT", value / 1e12];
    } else if (value >= 1e9) {
        return [NSString stringWithFormat:@"$%.2fB", value / 1e9];
    } else if (value >= 1e6) {
        return [NSString stringWithFormat:@"$%.2fM", value / 1e6];
    } else {
        return [NSString stringWithFormat:@"$%.0f", value];
    }
}

- (NSString *)formatNumber:(NSNumber *)number {
    double value = number.doubleValue;
    if (value >= 1e9) {
        return [NSString stringWithFormat:@"%.2fB", value / 1e9];
    } else if (value >= 1e6) {
        return [NSString stringWithFormat:@"%.2fM", value / 1e6];
    } else if (value >= 1e3) {
        return [NSString stringWithFormat:@"%.2fK", value / 1e3];
    } else {
        return [NSString stringWithFormat:@"%.0f", value];
    }
}

- (NSString *)formatChangePercent:(NSNumber *)changePercent {
    double value = changePercent.doubleValue;
    NSString *sign = value >= 0 ? @"+" : @"";
    return [NSString stringWithFormat:@"%@%.2f%%", sign, value];
}

#pragma mark - TableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.currentResults.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.currentResults.count) return @"";
    
    YahooScreenerResult *result = self.currentResults[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"symbol"]) {
        return result.symbol;
    } else if ([identifier isEqualToString:@"name"]) {
        return result.name;
    } else if ([identifier isEqualToString:@"price"]) {
        return [NSString stringWithFormat:@"$%.2f", result.price.doubleValue];
    } else if ([identifier isEqualToString:@"changePercent"]) {
        return [self formatChangePercent:result.changePercent];
    } else if ([identifier isEqualToString:@"volume"]) {
        return [self formatNumber:result.volume];
    } else if ([identifier isEqualToString:@"marketCap"]) {
        return [self formatMarketCap:result.marketCap];
    } else if ([identifier isEqualToString:@"sector"]) {
        return result.sector;
    }
    
    return @"";
}

#pragma mark - TableView Delegate

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.currentResults.count) return;
    
    YahooScreenerResult *result = self.currentResults[row];
    NSString *identifier = tableColumn.identifier;
    
    // Color-code change percentage
    if ([identifier isEqualToString:@"changePercent"]) {
        NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
        double changePercent = result.changePercent.doubleValue;
        
        if (changePercent > 0) {
            textCell.textColor = [NSColor systemGreenColor];
        } else if (changePercent < 0) {
            textCell.textColor = [NSColor systemRedColor];
        } else {
            textCell.textColor = [NSColor labelColor];
        }
    } else {
        // Reset to default color for other columns
        NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
        textCell.textColor = [NSColor labelColor];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.resultsTable.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.currentResults.count) {
        YahooScreenerResult *result = self.currentResults[selectedRow];
        NSLog(@"📊 ScreenerWidget: Selected %@ - %@", result.symbol, result.name);
        
        // TODO: Potrebbero essere aggiunte azioni come:
        // - Aprire grafico del simbolo
        // - Aggiungere a watchlist
        // - Mostrare dettagli in popup
    }
}

#pragma mark - API Integration (TODO)

/*
 * TODO: Integrare con Yahoo Finance API
 *
 * Questa è la struttura che dovrà essere implementata per chiamare
 * gli endpoint Yahoo Finance screener:
 *
 * 1. Costruire payload JSON con filtri attivi
 * 2. Fare POST request a Yahoo API
 * 3. Parsare risposta e convertire in YahooScreenerResult objects
 * 4. Aggiornare UI con nuovi risultati
 */

- (NSDictionary *)buildYahooScreenerPayload {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    
    // Basic settings
    payload[@"size"] = @(self.maxResults);
    payload[@"offset"] = @0;
    payload[@"sortField"] = @"dayvolume";
    payload[@"sortType"] = @"desc";
    payload[@"quoteType"] = @"EQUITY";
    
    // Build query with active filters
    NSMutableArray *operands = [NSMutableArray array];
    
    // Default region filter
    [operands addObject:@{
        @"operator": @"eq",
        @"operands": @[@"region", @"us"]
    }];
    
    // Add active filters
    for (YahooScreenerFilter *filter in self.activeFilters) {
        NSString *operator = [self operatorStringForComparison:filter.comparison];
        NSMutableArray *filterOperands = [NSMutableArray arrayWithObject:filter.field];
        [filterOperands addObjectsFromArray:filter.values];
        
        [operands addObject:@{
            @"operator": operator,
            @"operands": filterOperands
        }];
    }
    
    // Build final query structure
    payload[@"query"] = @{
        @"operator": @"and",
        @"operands": operands
    };
    
    return [payload copy];
}

- (NSString *)operatorStringForComparison:(YahooFilterComparison)comparison {
    switch (comparison) {
        case YahooFilterEqual:
            return @"eq";
        case YahooFilterGreaterThan:
            return @"gt";
        case YahooFilterLessThan:
            return @"lt";
        case YahooFilterBetween:
            return @"btwn";
        default:
            return @"eq";
    }
}

@end
