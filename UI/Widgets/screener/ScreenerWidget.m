//
//  ScreenerWidget.m
//  mafia_AI
//
//  Implementation of STOOQ Stock Screener Widget
//

#import "ScreenerWidget.h"

@interface ScreenerWidget ()

// UI Components - Data Tab
@property (nonatomic, strong) NSTabView *tabView;
@property (nonatomic, strong) NSTableView *resultsTable;
@property (nonatomic, strong) NSScrollView *tableScrollView;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *exportButton;

// UI Components - Database Tab
@property (nonatomic, strong) NSView *databaseTabView;
@property (nonatomic, strong) NSTextField *dbStatusLabel;
@property (nonatomic, strong) NSTextField *dbPathLabel;
@property (nonatomic, strong) NSButton *initializeButton;
@property (nonatomic, strong) NSView *dropZone;
@property (nonatomic, strong) NSTextField *dropZoneLabel;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;

// Data
@property (nonatomic, strong) NSMutableArray<STOOQStockData *> *currentResults;
@property (nonatomic, strong) NSMutableArray<NSString *> *selectedCategories;
@property (nonatomic, strong) STOOQDatabaseManager *dbManager;

@end

@implementation ScreenerWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Screener";
        
        // Initialize properties
        _showVolume = YES;
        _showDollarVolume = YES;
        _maxResults = 1000;
        _currentResults = [NSMutableArray array];
        _selectedCategories = [NSMutableArray array];
        _dbManager = [STOOQDatabaseManager sharedManager];
        
        // Ensure view is loaded before setting up UI
        [self loadView];
        
        [self setupUI];
        [self updateDatabaseStatus];
        [self refreshData];
    }
    return self;
}

#pragma mark - UI Setup

- (void)setupUI {
    // Create main tab view
    self.tabView = [[NSTabView alloc] init];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.tabView];
    
    // Setup tabs
    [self setupDataTab];
    [self setupDatabaseTab];
    
    // Tab view constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.tabView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.tabView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];
}

- (void)setupDataTab {
    NSTabViewItem *dataTab = [[NSTabViewItem alloc] initWithIdentifier:@"data"];
    dataTab.label = @"Data";
    
    NSView *dataView = [[NSView alloc] init];
    
    // Status and controls at top
    NSView *controlsView = [[NSView alloc] init];
    controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [dataView addSubview:controlsView];
    
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.editable = NO;
    self.statusLabel.bezeled = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.font = [NSFont systemFontOfSize:12];
    self.statusLabel.stringValue = @"No data loaded";
    [controlsView addSubview:self.statusLabel];
    
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.refreshButton.title = @"Refresh";
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshButtonClicked:);
    [controlsView addSubview:self.refreshButton];
    
    self.exportButton = [[NSButton alloc] init];
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.exportButton.title = @"Export CSV";
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
    
    // Setup table columns
    [self setupTableColumns];
    
    self.tableScrollView = [[NSScrollView alloc] init];
    self.tableScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableScrollView.documentView = self.resultsTable;
    self.tableScrollView.hasVerticalScroller = YES;
    self.tableScrollView.hasHorizontalScroller = YES;
    self.tableScrollView.autohidesScrollers = YES;
    [dataView addSubview:self.tableScrollView];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Controls view
        [controlsView.topAnchor constraintEqualToAnchor:dataView.topAnchor constant:8],
        [controlsView.leadingAnchor constraintEqualToAnchor:dataView.leadingAnchor constant:8],
        [controlsView.trailingAnchor constraintEqualToAnchor:dataView.trailingAnchor constant:-8],
        [controlsView.heightAnchor constraintEqualToConstant:30],
        
        // Status label
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:controlsView.leadingAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor],
        
        // Export button
        [self.exportButton.trailingAnchor constraintEqualToAnchor:controlsView.trailingAnchor],
        [self.exportButton.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor],
        [self.exportButton.widthAnchor constraintEqualToConstant:100],
        
        // Refresh button
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.exportButton.leadingAnchor constant:-8],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor],
        [self.refreshButton.widthAnchor constraintEqualToConstant:80],
        
        // Table scroll view
        [self.tableScrollView.topAnchor constraintEqualToAnchor:controlsView.bottomAnchor constant:8],
        [self.tableScrollView.leadingAnchor constraintEqualToAnchor:dataView.leadingAnchor constant:8],
        [self.tableScrollView.trailingAnchor constraintEqualToAnchor:dataView.trailingAnchor constant:-8],
        [self.tableScrollView.bottomAnchor constraintEqualToAnchor:dataView.bottomAnchor constant:-8]
    ]];
    
    dataTab.view = dataView;
    [self.tabView addTabViewItem:dataTab];
}

- (void)setupDatabaseTab {
    NSTabViewItem *dbTab = [[NSTabViewItem alloc] initWithIdentifier:@"database"];
    dbTab.label = @"Database";
    
    self.databaseTabView = [[NSView alloc] init];
    
    // Database status section
    NSTextField *statusTitle = [[NSTextField alloc] init];
    statusTitle.translatesAutoresizingMaskIntoConstraints = NO;
    statusTitle.editable = NO;
    statusTitle.bezeled = NO;
    statusTitle.backgroundColor = [NSColor clearColor];
    statusTitle.font = [NSFont boldSystemFontOfSize:14];
    statusTitle.stringValue = @"Database Status";
    [self.databaseTabView addSubview:statusTitle];
    
    self.dbStatusLabel = [[NSTextField alloc] init];
    self.dbStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dbStatusLabel.editable = NO;
    self.dbStatusLabel.bezeled = NO;
    self.dbStatusLabel.backgroundColor = [NSColor clearColor];
    self.dbStatusLabel.font = [NSFont systemFontOfSize:12];
    [self.databaseTabView addSubview:self.dbStatusLabel];
    
    self.dbPathLabel = [[NSTextField alloc] init];
    self.dbPathLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dbPathLabel.editable = NO;
    self.dbPathLabel.bezeled = NO;
    self.dbPathLabel.backgroundColor = [NSColor clearColor];
    self.dbPathLabel.font = [NSFont systemFontOfSize:10];
    self.dbPathLabel.textColor = [NSColor secondaryLabelColor];
    [self.databaseTabView addSubview:self.dbPathLabel];
    
    // Initialize button
    self.initializeButton = [[NSButton alloc] init];
    self.initializeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.initializeButton.title = @"Import from Downloads/data";
    self.initializeButton.bezelStyle = NSBezelStyleRounded;
    self.initializeButton.target = self;
    self.initializeButton.action = @selector(initializeDatabaseClicked:);
    [self.databaseTabView addSubview:self.initializeButton];
    
    // Process updates button
    NSButton *processUpdatesButton = [[NSButton alloc] init];
    processUpdatesButton.translatesAutoresizingMaskIntoConstraints = NO;
    processUpdatesButton.title = @"Process Updates";
    processUpdatesButton.bezelStyle = NSBezelStyleRounded;
    processUpdatesButton.target = self;
    processUpdatesButton.action = @selector(processUpdatesClicked:);
    [self.databaseTabView addSubview:processUpdatesButton];
    
    // Drop zone section
    NSTextField *dropTitle = [[NSTextField alloc] init];
    dropTitle.translatesAutoresizingMaskIntoConstraints = NO;
    dropTitle.editable = NO;
    dropTitle.bezeled = NO;
    dropTitle.backgroundColor = [NSColor clearColor];
    dropTitle.font = [NSFont boldSystemFontOfSize:14];
    dropTitle.stringValue = @"Instructions";
    [self.databaseTabView addSubview:dropTitle];
    
    // Drop zone
    self.dropZone = [[NSView alloc] init];
    self.dropZone.translatesAutoresizingMaskIntoConstraints = NO;
    self.dropZone.wantsLayer = YES;
    self.dropZone.layer.borderWidth = 2.0;
    self.dropZone.layer.borderColor = [NSColor tertiaryLabelColor].CGColor;
    self.dropZone.layer.cornerRadius = 8.0;
    self.dropZone.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    
    [self.databaseTabView addSubview:self.dropZone];
    
    self.dropZoneLabel = [[NSTextField alloc] init];
    self.dropZoneLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dropZoneLabel.editable = NO;
    self.dropZoneLabel.bezeled = NO;
    self.dropZoneLabel.backgroundColor = [NSColor clearColor];
    self.dropZoneLabel.font = [NSFont systemFontOfSize:14];
    self.dropZoneLabel.textColor = [NSColor secondaryLabelColor];
    self.dropZoneLabel.alignment = NSTextAlignmentCenter;
    self.dropZoneLabel.stringValue = @"Place STOOQ update files in Downloads folder\nthen click 'Process Updates' button";
    [self.dropZone addSubview:self.dropZoneLabel];
    
    // Progress indicator
    self.progressIndicator = [[NSProgressIndicator alloc] init];
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
    self.progressIndicator.hidden = YES;
    [self.databaseTabView addSubview:self.progressIndicator];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Status title
        [statusTitle.topAnchor constraintEqualToAnchor:self.databaseTabView.topAnchor constant:20],
        [statusTitle.leadingAnchor constraintEqualToAnchor:self.databaseTabView.leadingAnchor constant:20],
        
        // DB status label
        [self.dbStatusLabel.topAnchor constraintEqualToAnchor:statusTitle.bottomAnchor constant:8],
        [self.dbStatusLabel.leadingAnchor constraintEqualToAnchor:self.databaseTabView.leadingAnchor constant:20],
        [self.dbStatusLabel.trailingAnchor constraintEqualToAnchor:self.databaseTabView.trailingAnchor constant:-20],
        
        // DB path label
        [self.dbPathLabel.topAnchor constraintEqualToAnchor:self.dbStatusLabel.bottomAnchor constant:4],
        [self.dbPathLabel.leadingAnchor constraintEqualToAnchor:self.databaseTabView.leadingAnchor constant:20],
        [self.dbPathLabel.trailingAnchor constraintEqualToAnchor:self.databaseTabView.trailingAnchor constant:-20],
        
        // Initialize button
        [self.initializeButton.topAnchor constraintEqualToAnchor:self.dbPathLabel.bottomAnchor constant:12],
        [self.initializeButton.leadingAnchor constraintEqualToAnchor:self.databaseTabView.leadingAnchor constant:20],
        [self.initializeButton.widthAnchor constraintEqualToConstant:200],
        
        // Process updates button
        [processUpdatesButton.topAnchor constraintEqualToAnchor:self.dbPathLabel.bottomAnchor constant:12],
        [processUpdatesButton.leadingAnchor constraintEqualToAnchor:self.initializeButton.trailingAnchor constant:12],
        [processUpdatesButton.widthAnchor constraintEqualToConstant:150],
        
        // Drop title
        [dropTitle.topAnchor constraintEqualToAnchor:self.initializeButton.bottomAnchor constant:24],
        [dropTitle.leadingAnchor constraintEqualToAnchor:self.databaseTabView.leadingAnchor constant:20],
        
        // Drop zone
        [self.dropZone.topAnchor constraintEqualToAnchor:dropTitle.bottomAnchor constant:8],
        [self.dropZone.leadingAnchor constraintEqualToAnchor:self.databaseTabView.leadingAnchor constant:20],
        [self.dropZone.trailingAnchor constraintEqualToAnchor:self.databaseTabView.trailingAnchor constant:-20],
        [self.dropZone.heightAnchor constraintEqualToConstant:100],
        
        // Drop zone label
        [self.dropZoneLabel.centerXAnchor constraintEqualToAnchor:self.dropZone.centerXAnchor],
        [self.dropZoneLabel.centerYAnchor constraintEqualToAnchor:self.dropZone.centerYAnchor],
        
        // Progress indicator
        [self.progressIndicator.centerXAnchor constraintEqualToAnchor:self.databaseTabView.centerXAnchor],
        [self.progressIndicator.topAnchor constraintEqualToAnchor:self.dropZone.bottomAnchor constant:20]
    ]];
    
    dbTab.view = self.databaseTabView;
    [self.tabView addTabViewItem:dbTab];
}

- (void)setupTableColumns {
    // Symbol column
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    [self.resultsTable addTableColumn:symbolColumn];
    
    // Category column
    NSTableColumn *categoryColumn = [[NSTableColumn alloc] initWithIdentifier:@"category"];
    categoryColumn.title = @"Category";
    categoryColumn.width = 100;
    categoryColumn.minWidth = 80;
    [self.resultsTable addTableColumn:categoryColumn];
    
    // Close column
    NSTableColumn *closeColumn = [[NSTableColumn alloc] initWithIdentifier:@"close"];
    closeColumn.title = @"Close";
    closeColumn.width = 80;
    closeColumn.minWidth = 60;
    [self.resultsTable addTableColumn:closeColumn];
    
    // Change % column
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change %";
    changeColumn.width = 80;
    changeColumn.minWidth = 70;
    [self.resultsTable addTableColumn:changeColumn];
    
    // Volume column
    NSTableColumn *volumeColumn = [[NSTableColumn alloc] initWithIdentifier:@"volume"];
    volumeColumn.title = @"Volume";
    volumeColumn.width = 100;
    volumeColumn.minWidth = 80;
    [self.resultsTable addTableColumn:volumeColumn];
    
    // $ Volume column
    NSTableColumn *dollarVolumeColumn = [[NSTableColumn alloc] initWithIdentifier:@"dollarVolume"];
    dollarVolumeColumn.title = @"$ Volume";
    dollarVolumeColumn.width = 120;
    dollarVolumeColumn.minWidth = 100;
    [self.resultsTable addTableColumn:dollarVolumeColumn];
}

#pragma mark - Actions

- (void)refreshButtonClicked:(id)sender {
    [self refreshData];
}

- (void)exportButtonClicked:(id)sender {
    [self exportResultsToCSV];
}

- (void)initializeDatabaseClicked:(id)sender {
    [self performDatabaseInitialization];
}

- (void)processUpdatesClicked:(id)sender {
    [self performUpdatesProcessing];
}

#pragma mark - Public Methods

- (void)refreshData {
    if (!self.dbManager.isDatabaseInitialized) {
        self.statusLabel.stringValue = @"Database not initialized";
        [self.currentResults removeAllObjects];
        [self.resultsTable reloadData];
        return;
    }
    
    // Load all latest stock data
    NSArray<STOOQStockData *> *allData = [self.dbManager getAllLatestStockData];
    
    // Apply max results limit
    if (allData.count > self.maxResults) {
        allData = [allData subarrayWithRange:NSMakeRange(0, self.maxResults)];
    }
    
    [self.currentResults removeAllObjects];
    [self.currentResults addObjectsFromArray:allData];
    
    // Update status
    self.statusLabel.stringValue = [NSString stringWithFormat:@"%lu stocks loaded", (unsigned long)self.currentResults.count];
    
    [self.resultsTable reloadData];
    NSLog(@"📊 ScreenerWidget: Loaded %lu stocks", (unsigned long)self.currentResults.count);
}

- (void)applyFiltersWithMinChange:(nullable NSNumber *)minChange minVolume:(nullable NSNumber *)minVolume {
    if (!self.dbManager.isDatabaseInitialized) {
        return;
    }
    
    NSArray<STOOQStockData *> *filteredData = [self.dbManager searchStocksWithMinChange:minChange
                                                                               minVolume:minVolume
                                                                              categories:self.selectedCategories.count > 0 ? self.selectedCategories : nil];
    
    // Apply max results limit
    if (filteredData.count > self.maxResults) {
        filteredData = [filteredData subarrayWithRange:NSMakeRange(0, self.maxResults)];
    }
    
    [self.currentResults removeAllObjects];
    [self.currentResults addObjectsFromArray:filteredData];
    
    self.statusLabel.stringValue = [NSString stringWithFormat:@"%lu stocks (filtered)", (unsigned long)self.currentResults.count];
    [self.resultsTable reloadData];
}

- (void)clearFilters {
    [self.selectedCategories removeAllObjects];
    [self refreshData];
}

- (void)exportResultsToCSV {
    if (self.currentResults.count == 0) {
        NSBeep();
        return;
    }
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"csv"];
    savePanel.nameFieldStringValue = @"screener_results.csv";
    
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            [self performCSVExportToURL:savePanel.URL];
        }
    }];
}

#pragma mark - Private Methods

- (void)updateDatabaseStatus {
    NSDictionary *status = [self.dbManager getDatabaseStatus];
    
    NSString *statusText;
    if ([status[@"isInitialized"] boolValue]) {
        statusText = [NSString stringWithFormat:@"✅ %@ symbols, %@ categories (%.1f MB)",
                     status[@"totalSymbols"], status[@"totalCategories"], [status[@"databaseSizeMB"] doubleValue]];
    } else {
        statusText = @"❌ Database not initialized";
    }
    
    self.dbStatusLabel.stringValue = statusText;
    self.dbPathLabel.stringValue = [NSString stringWithFormat:@"Path: %@", status[@"databasePath"]];
    
    // Update button state
    self.initializeButton.enabled = YES;
    self.refreshButton.enabled = [status[@"isInitialized"] boolValue];
    self.exportButton.enabled = [status[@"isInitialized"] boolValue];
}

- (void)performDatabaseInitialization {
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];
    self.initializeButton.enabled = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL success = [self.dbManager initializeDatabaseFromLocalDownloads];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressIndicator stopAnimation:nil];
            self.progressIndicator.hidden = YES;
            self.initializeButton.enabled = YES;
            
            [self updateDatabaseStatus];
            
            if (success) {
                [self refreshData];
                
                // Show success message
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Database Initialized Successfully";
                alert.informativeText = [NSString stringWithFormat:@"Loaded %lu symbols from Downloads/data folder.", (unsigned long)self.dbManager.totalStocksCount];
                alert.alertStyle = NSAlertStyleInformational;
                [alert runModal];
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Database Initialization Failed";
                alert.informativeText = @"Could not find Downloads/data folder next to database. Please create the folder and copy STOOQ files there.";
                alert.alertStyle = NSAlertStyleWarning;
                [alert runModal];
            }
        });
    });
}

- (void)performUpdatesProcessing {
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger processedCount = [self.dbManager processAvailableUpdates];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressIndicator stopAnimation:nil];
            self.progressIndicator.hidden = YES;
            
            [self updateDatabaseStatus];
            
            if (processedCount > 0) {
                [self refreshData];
                
                // Show success message
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Updates Processed Successfully";
                alert.informativeText = [NSString stringWithFormat:@"Processed %ld update files. Files moved to Downloads/processed folder.", (long)processedCount];
                alert.alertStyle = NSAlertStyleInformational;
                [alert runModal];
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"No Updates Found";
                alert.informativeText = @"No update files found in Downloads folder. Place STOOQ daily update files there.";
                alert.alertStyle = NSAlertStyleInformational;
                [alert runModal];
            }
        });
    });
}

- (void)performCSVExportToURL:(NSURL *)url {
    NSMutableString *csvContent = [NSMutableString string];
    
    // Header
    [csvContent appendString:@"Symbol,Category,Close,Change %,Volume,$ Volume\n"];
    
    // Data rows
    for (STOOQStockData *stock in self.currentResults) {
        [csvContent appendFormat:@"%@,%@,%.6f,%.2f,%.0f,%.2f\n",
         stock.symbol, stock.category, stock.close, stock.changePercent, stock.volume, stock.dollarVolume];
    }
    
    NSError *error;
    BOOL success = [csvContent writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (!success) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Export Failed";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleWarning;
        [alert runModal];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.currentResults.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.currentResults.count) return nil;
    
    STOOQStockData *stock = self.currentResults[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"symbol"]) {
        return stock.symbol;
    } else if ([identifier isEqualToString:@"category"]) {
        return stock.category;
    } else if ([identifier isEqualToString:@"close"]) {
        return [NSString stringWithFormat:@"%.4f", stock.close];
    } else if ([identifier isEqualToString:@"change"]) {
        return [NSString stringWithFormat:@"%.2f%%", stock.changePercent];
    } else if ([identifier isEqualToString:@"volume"]) {
        return [NSString stringWithFormat:@"%.0f", stock.volume];
    } else if ([identifier isEqualToString:@"dollarVolume"]) {
        return [NSString stringWithFormat:@"$%.2f", stock.dollarVolume];
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.currentResults.count) return;
    
    // Color coding for change %
    if ([tableColumn.identifier isEqualToString:@"change"]) {
        STOOQStockData *stock = self.currentResults[row];
        NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
        
        if (stock.changePercent > 0) {
            textCell.textColor = [NSColor systemGreenColor];
        } else if (stock.changePercent < 0) {
            textCell.textColor = [NSColor systemRedColor];
        } else {
            textCell.textColor = [NSColor labelColor];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    // Handle selection changes if needed for future features
}

#pragma mark - BaseWidget Overrides

- (NSDictionary *)serializeState {
    NSMutableDictionary *data = [[super serializeState] mutableCopy];
    
    data[@"showVolume"] = @(self.showVolume);
    data[@"showDollarVolume"] = @(self.showDollarVolume);
    data[@"maxResults"] = @(self.maxResults);
    data[@"selectedCategories"] = [self.selectedCategories copy];
    
    return data;
}

- (void)restoreState:(NSDictionary *)data {
    [super restoreState:data];
    
    if (data[@"showVolume"]) self.showVolume = [data[@"showVolume"] boolValue];
    if (data[@"showDollarVolume"]) self.showDollarVolume = [data[@"showDollarVolume"] boolValue];
    if (data[@"maxResults"]) self.maxResults = [data[@"maxResults"] integerValue];
    if (data[@"selectedCategories"]) {
        [self.selectedCategories removeAllObjects];
        [self.selectedCategories addObjectsFromArray:data[@"selectedCategories"]];
    }
    
    [self refreshData];
}

@end
