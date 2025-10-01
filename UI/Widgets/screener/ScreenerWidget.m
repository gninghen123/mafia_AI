//
//  ScreenerWidget.m - ADVANCED FILTERS COMPLETE IMPLEMENTATION
//  TradingApp
//
//  Yahoo Finance Stock Screener Widget with Full Filter Support
//

#import <objc/runtime.h>
#import "ScreenerWidget.h"
#import "DataHub.h"
#import "YahooScreenerAPI.h"

// ============================================================================
// ADVANCED FILTER IMPLEMENTATIONS
// ============================================================================

@implementation AdvancedScreenerFilter

+ (instancetype)filterWithKey:(NSString *)key
                  displayName:(NSString *)displayName
                         type:(AdvancedFilterType)type {
    AdvancedScreenerFilter *filter = [[AdvancedScreenerFilter alloc] init];
    filter.key = key;
    filter.displayName = displayName;
    filter.type = type;
    filter.isActive = NO;
    return filter;
}

+ (instancetype)selectFilterWithKey:(NSString *)key
                        displayName:(NSString *)displayName
                            options:(NSArray<NSString *> *)options {
    AdvancedScreenerFilter *filter = [self filterWithKey:key displayName:displayName type:AdvancedFilterTypeSelect];
    filter.options = options;
    return filter;
}

@end

@implementation FilterCategory

+ (instancetype)categoryWithName:(NSString *)name
                             key:(NSString *)key
                         filters:(NSArray<AdvancedScreenerFilter *> *)filters {
    FilterCategory *category = [[FilterCategory alloc] init];
    category.name = name;
    category.categoryKey = key;
    category.filters = filters;
    category.isExpanded = NO;
    return category;
}

@end

@implementation YahooScreenerResult

+ (instancetype)resultFromYahooData:(NSDictionary *)data {
    YahooScreenerResult *result = [[YahooScreenerResult alloc] init];
    
    // Basic data
    result.symbol = data[@"symbol"] ?: @"";
    result.name = data[@"longName"] ?: data[@"shortName"] ?: @"";
    result.price = data[@"regularMarketPrice"] ?: @0;
    result.change = data[@"regularMarketChange"] ?: @0;
    result.changePercent = data[@"regularMarketChangePercent"] ?: @0;
    result.volume = data[@"regularMarketVolume"] ?: @0;
    result.marketCap = data[@"marketCap"] ?: @0;
    result.sector = data[@"sector"] ?: @"";
    result.exchange = data[@"fullExchangeName"] ?: @"";
    
    // Enhanced financial metrics
    result.trailingPE = data[@"trailingPE"] ?: @0;
    result.forwardPE = data[@"forwardPE"] ?: @0;
    result.priceToBook = data[@"priceToBook"] ?: @0;
    result.priceToSales = data[@"priceToSales"] ?: @0;
    result.pegRatio = data[@"pegRatio"] ?: @0;
    result.dividendYield = data[@"dividendYield"] ?: @0;
    result.beta = data[@"beta"] ?: @0;
    result.fiftyTwoWeekLow = data[@"fiftyTwoWeekLow"] ?: @0;
    result.fiftyTwoWeekHigh = data[@"fiftyTwoWeekHigh"] ?: @0;
    
    return result;
}

@end

// ============================================================================
// MAIN WIDGET IMPLEMENTATION
// ============================================================================

@interface ScreenerWidget ()

// UI Components - Main Tabs
@property (nonatomic, strong) NSTabView *tabView;
@property (nonatomic, strong) NSTableView *resultsTable;
@property (nonatomic, strong) NSScrollView *tableScrollView;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *exportButton;

// UI Components - Basic Filters Tab
@property (nonatomic, strong) NSView *basicFiltersTabView;
@property (nonatomic, strong) NSPopUpButton *screenerTypePopup;
@property (nonatomic, strong) NSTextField *maxResultsField;
@property (nonatomic, strong) NSButton *autoRefreshCheckbox;

// Quick Filters
@property (nonatomic, strong) NSTextField *minVolumeField;
@property (nonatomic, strong) NSTextField *minMarketCapField;
@property (nonatomic, strong) NSPopUpButton *sectorPopup;

// UI Components - Advanced Filters Tab
@property (nonatomic, strong) NSView *advancedFiltersTabView;
@property (nonatomic, strong) NSOutlineView *filtersOutlineView;
@property (nonatomic, strong) NSScrollView *filtersScrollView;
@property (nonatomic, strong) NSButton *addFilterButton;
@property (nonatomic, strong) NSButton *clearAdvancedFiltersButton;
@property (nonatomic, strong) NSButton *applyAdvancedFiltersButton;

// Filter UI Elements


// Action Buttons
@property (nonatomic, strong) NSButton *applyFiltersButton;
@property (nonatomic, strong) NSButton *clearFiltersButton;
@property (nonatomic, strong) NSTextField *apiStatusValueField;

// Data Properties
@property (nonatomic, strong) NSMutableArray<YahooScreenerResult *> *currentResults;
@property (nonatomic, strong) NSMutableArray<FilterCategory *> *filterCategories;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AdvancedScreenerFilter *> *activeFilters;
@property (nonatomic, strong) NSTimer *refreshTimer;

// Internal state
@property (nonatomic, assign) YahooScreenerType screenerType;

@end

@implementation ScreenerWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Yahoo Screener";
        
        // Initialize properties
        _maxResults = 100;
        _autoRefresh = NO;
        _screenerType = YahooScreenerTypeMostActive;
        _currentResults = [NSMutableArray array];
        _filterCategories = [NSMutableArray array];
        _activeFilters = [NSMutableDictionary dictionary];
        
        // Setup UI
        [self loadView];
        [self setupUI];
        [self loadAvailableFilters];
        
        // Initial data load
        [self refreshData];
    }
    return self;
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
    
    // Setup all tabs
    [self setupResultsTab];
    [self setupBasicFiltersTab];
    [self setupAdvancedFiltersTab];
    
    // Tab view constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.tabView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.tabView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];
    
    // Check API service availability
    [[YahooScreenerAPI sharedManager] checkServiceAvailability:^(BOOL available, NSString *version) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (available) {
                NSLog(@"✅ Yahoo Screener API service available (version: %@)", version ?: @"unknown");
                self.statusLabel.stringValue = @"Ready - API service connected";
                [self updateAPIStatus:@"Connected" color:[NSColor systemGreenColor]];
            } else {
                NSLog(@"❌ Yahoo Screener API service unavailable");
                self.statusLabel.stringValue = @"Warning - API service unavailable";
                self.statusLabel.textColor = [NSColor systemOrangeColor];
                [self updateAPIStatus:@"Disconnected" color:[NSColor systemRedColor]];
            }
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
    self.refreshButton.action = @selector(refreshData);
    [controlsView addSubview:self.refreshButton];
    
    self.exportButton = [[NSButton alloc] init];
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.exportButton.title = @"📄 Export CSV";
    self.exportButton.bezelStyle = NSBezelStyleRounded;
    self.exportButton.target = self;
    self.exportButton.action = @selector(exportResultsToCSV);
    [controlsView addSubview:self.exportButton];
    
    // Results table with enhanced columns
    self.resultsTable = [[NSTableView alloc] init];
    self.resultsTable.delegate = self;
    self.resultsTable.dataSource = self;
    self.resultsTable.headerView = [[NSTableHeaderView alloc] init];
    self.resultsTable.usesAlternatingRowBackgroundColors = YES;
    
    [self setupEnhancedTableColumns];
    
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

#pragma mark - Basic Filters Tab Setup

- (void)setupBasicFiltersTab {
    NSTabViewItem *basicFiltersTab = [[NSTabViewItem alloc] initWithIdentifier:@"basic_filters"];
    basicFiltersTab.label = @"Basic Filters";
    
    self.basicFiltersTabView = [[NSView alloc] init];
    
    CGFloat yPosition = 20;
    
    // Screener Type section
    NSTextField *typeLabel = [self createLabel:@"Screener Type:"];
    [self.basicFiltersTabView addSubview:typeLabel];
    
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
    self.screenerTypePopup.target = self;
    self.screenerTypePopup.action = @selector(screenerTypeChanged:);
    [self.basicFiltersTabView addSubview:self.screenerTypePopup];
    
    // Settings section
    NSTextField *settingsLabel = [self createLabel:@"Settings:"];
    [self.basicFiltersTabView addSubview:settingsLabel];
    
    NSTextField *maxResultsLabel = [self createLabel:@"Max Results:"];
    [self.basicFiltersTabView addSubview:maxResultsLabel];
    
    self.maxResultsField = [[NSTextField alloc] init];
    self.maxResultsField.translatesAutoresizingMaskIntoConstraints = NO;
    self.maxResultsField.stringValue = @"100";
    [self.basicFiltersTabView addSubview:self.maxResultsField];
    
    self.autoRefreshCheckbox = [[NSButton alloc] init];
    self.autoRefreshCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.autoRefreshCheckbox.buttonType = NSButtonTypeSwitch;
    self.autoRefreshCheckbox.title = @"Auto-refresh (30s)";
    self.autoRefreshCheckbox.target = self;
    self.autoRefreshCheckbox.action = @selector(autoRefreshChanged:);
    [self.basicFiltersTabView addSubview:self.autoRefreshCheckbox];
    
    // Quick Filters section
    NSTextField *quickFiltersLabel = [self createLabel:@"Quick Filters:"];
    [self.basicFiltersTabView addSubview:quickFiltersLabel];
    
    NSTextField *minVolumeLabel = [self createLabel:@"Min Volume:"];
    [self.basicFiltersTabView addSubview:minVolumeLabel];
    
    self.minVolumeField = [[NSTextField alloc] init];
    self.minVolumeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.minVolumeField.placeholderString = @"e.g. 1000000";
    [self.basicFiltersTabView addSubview:self.minVolumeField];
    
    NSTextField *minMarketCapLabel = [self createLabel:@"Min Market Cap:"];
    [self.basicFiltersTabView addSubview:minMarketCapLabel];
    
    self.minMarketCapField = [[NSTextField alloc] init];
    self.minMarketCapField.translatesAutoresizingMaskIntoConstraints = NO;
    self.minMarketCapField.placeholderString = @"e.g. 1000000000";
    [self.basicFiltersTabView addSubview:self.minMarketCapField];
    
    NSTextField *sectorLabel = [self createLabel:@"Sector:"];
    [self.basicFiltersTabView addSubview:sectorLabel];
    
    self.sectorPopup = [[NSPopUpButton alloc] init];
    self.sectorPopup.translatesAutoresizingMaskIntoConstraints = NO;
   // [self setupSectorPopup];
    [self.basicFiltersTabView addSubview:self.sectorPopup];
    
    // Filter action buttons
    self.applyFiltersButton = [[NSButton alloc] init];
    self.applyFiltersButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyFiltersButton.title = @"Apply Filters";
    self.applyFiltersButton.bezelStyle = NSBezelStyleRounded;
    self.applyFiltersButton.target = self;
    self.applyFiltersButton.action = @selector(applyBasicFilters);
    [self.basicFiltersTabView addSubview:self.applyFiltersButton];
    
    self.clearFiltersButton = [[NSButton alloc] init];
    self.clearFiltersButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.clearFiltersButton.title = @"Clear Filters";
    self.clearFiltersButton.bezelStyle = NSBezelStyleRounded;
    self.clearFiltersButton.target = self;
    self.clearFiltersButton.action = @selector(clearAllFilters);
    [self.basicFiltersTabView addSubview:self.clearFiltersButton];
    
    // API Configuration section
    NSTextField *apiConfigLabel = [self createLabel:@"API Configuration:"];
    [self.basicFiltersTabView addSubview:apiConfigLabel];
    
    NSButton *testConnectionButton = [[NSButton alloc] init];
    testConnectionButton.translatesAutoresizingMaskIntoConstraints = NO;
    testConnectionButton.title = @"Test Connection";
    testConnectionButton.bezelStyle = NSBezelStyleRounded;
    testConnectionButton.target = self;
    testConnectionButton.action = @selector(testConnectionButtonClicked:);
    [self.basicFiltersTabView addSubview:testConnectionButton];
    
    NSTextField *apiStatusLabel = [self createLabel:@"API Status:"];
    [self.basicFiltersTabView addSubview:apiStatusLabel];
    
    self.apiStatusValueField = [[NSTextField alloc] init];
    self.apiStatusValueField.translatesAutoresizingMaskIntoConstraints = NO;
    self.apiStatusValueField.editable = NO;
    self.apiStatusValueField.bezeled = NO;
    self.apiStatusValueField.backgroundColor = [NSColor clearColor];
    self.apiStatusValueField.font = [NSFont systemFontOfSize:11];
    self.apiStatusValueField.stringValue = @"Checking...";
    self.apiStatusValueField.textColor = [NSColor secondaryLabelColor];
    [self.basicFiltersTabView addSubview:self.apiStatusValueField];
    
    // Layout constraints for basic filters
    [self setupBasicFiltersConstraints:typeLabel
                         settingsLabel:settingsLabel
                       maxResultsLabel:maxResultsLabel
                     quickFiltersLabel:quickFiltersLabel
                        minVolumeLabel:minVolumeLabel
                     minMarketCapLabel:minMarketCapLabel
                           sectorLabel:sectorLabel
                       apiConfigLabel:apiConfigLabel
                   testConnectionButton:testConnectionButton
                       apiStatusLabel:apiStatusLabel];
    
    basicFiltersTab.view = self.basicFiltersTabView;
    [self.tabView addTabViewItem:basicFiltersTab];
}

#pragma mark - Advanced Filters Tab Setup

- (void)setupAdvancedFiltersTab {
    NSTabViewItem *advancedTab = [[NSTabViewItem alloc] initWithIdentifier:@"advanced_filters"];
    advancedTab.label = @"Advanced Filters";
    
    self.advancedFiltersTabView = [[NSView alloc] init];
    
    // Title
    NSTextField *titleLabel = [self createSectionLabel:@"Advanced Financial Filters"];
    [self.advancedFiltersTabView addSubview:titleLabel];
    
    // Setup financial ratio filters
    [self setupFinancialRatioFilters];
    
    // Action buttons for advanced filters
    self.applyAdvancedFiltersButton = [[NSButton alloc] init];
    self.applyAdvancedFiltersButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyAdvancedFiltersButton.title = @"Apply Advanced Filters";
    self.applyAdvancedFiltersButton.bezelStyle = NSBezelStyleRounded;
    self.applyAdvancedFiltersButton.target = self;
    self.applyAdvancedFiltersButton.action = @selector(applyAdvancedFilters);
    [self.advancedFiltersTabView addSubview:self.applyAdvancedFiltersButton];

    self.clearAdvancedFiltersButton = [[NSButton alloc] init];
    self.clearAdvancedFiltersButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.clearAdvancedFiltersButton.title = @"Clear Advanced";
    self.clearAdvancedFiltersButton.bezelStyle = NSBezelStyleRounded;
    self.clearAdvancedFiltersButton.target = self;
    self.clearAdvancedFiltersButton.action = @selector(clearAdvancedFilters);
    [self.advancedFiltersTabView addSubview:self.clearAdvancedFiltersButton];

    // NUOVO CHECKBOX - Aggiungi questo dopo clearAdvancedFiltersButton
    self.combineWithBasicCheckbox = [[NSButton alloc] init];
    self.combineWithBasicCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.combineWithBasicCheckbox.buttonType = NSButtonTypeSwitch;
    self.combineWithBasicCheckbox.title = @"Combine with basic filters (most active)";
    self.combineWithBasicCheckbox.state = NSControlStateValueOn; // Default: combinare
    self.combineWithBasicCheckbox.font = [NSFont systemFontOfSize:11];
    [self.advancedFiltersTabView addSubview:self.combineWithBasicCheckbox];

    // Setup advanced filters constraints
    [self setupAdvancedFiltersConstraints:titleLabel];
    
    advancedTab.view = self.advancedFiltersTabView;
    [self.tabView addTabViewItem:advancedTab];
}

#pragma mark - Financial Ratio Filters Setup


- (void)addRangeFilterWithLabel:(NSString *)labelText
                       minField:(NSTextField **)minField
                       maxField:(NSTextField **)maxField
                     atPosition:(CGFloat *)yPosition
                        spacing:(CGFloat)spacing {
    
    NSTextField *label = [self createLabel:labelText];
    [self.advancedFiltersTabView addSubview:label];
    
    NSTextField *minLabel = [self createSmallLabel:@"Min:"];
    [self.advancedFiltersTabView addSubview:minLabel];
    
    NSTextField *minTextField = [[NSTextField alloc] init];
    minTextField.translatesAutoresizingMaskIntoConstraints = NO;
    minTextField.placeholderString = @"0";
    [self.advancedFiltersTabView addSubview:minTextField];
    *minField = minTextField; // Assegnazione diretta
    
    NSTextField *maxLabel = [self createSmallLabel:@"Max:"];
    [self.advancedFiltersTabView addSubview:maxLabel];
    
    NSTextField *maxTextField = [[NSTextField alloc] init];
    maxTextField.translatesAutoresizingMaskIntoConstraints = NO;
    maxTextField.placeholderString = @"∞";
    [self.advancedFiltersTabView addSubview:maxTextField];
    *maxField = maxTextField; // Assegnazione diretta
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:*yPosition],
        [label.widthAnchor constraintEqualToConstant:130],
        [minLabel.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [minLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [minTextField.leadingAnchor constraintEqualToAnchor:minLabel.trailingAnchor constant:5],
        [minTextField.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [minTextField.widthAnchor constraintEqualToConstant:80],
        [maxLabel.leadingAnchor constraintEqualToAnchor:minTextField.trailingAnchor constant:10],
        [maxLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [maxTextField.leadingAnchor constraintEqualToAnchor:maxLabel.trailingAnchor constant:5],
        [maxTextField.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [maxTextField.widthAnchor constraintEqualToConstant:80]
    ]];
    
    *yPosition += spacing;
}

// Metodo helper per dropdown
- (void)addDropdownWithLabel:(NSString *)labelText
                       popup:(NSPopUpButton **)popup
                     options:(NSArray<NSString *> *)options
                  atPosition:(CGFloat *)yPosition
                     spacing:(CGFloat)spacing {
    
    NSTextField *label = [self createLabel:labelText];
    [self.advancedFiltersTabView addSubview:label];
    
    NSPopUpButton *popupButton = [[NSPopUpButton alloc] init];
    popupButton.translatesAutoresizingMaskIntoConstraints = NO;
    [popupButton removeAllItems];
    for (NSString *option in options) {
        [popupButton addItemWithTitle:option];
    }
    [self.advancedFiltersTabView addSubview:popupButton];
    *popup = popupButton; // Assegnazione diretta
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:*yPosition],
        [label.widthAnchor constraintEqualToConstant:130],
        [popupButton.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [popupButton.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [popupButton.widthAnchor constraintEqualToConstant:200]
    ]];
    
    *yPosition += spacing;
}

// Ora il setupFinancialRatioFilters completo ma compatto:
// NUOVI METODI HELPER SENZA DOPPI PUNTATORI
// Sostituiscono i vecchi metodi addRangeFilterWithLabel e addDropdownWithLabel

#pragma mark - Helper Methods per Filtri (Versione Pulita)

/**
 * Crea un filtro range e lo aggiunge alla UI
 * Ritorna i field creati in un array [minField, maxField]
 */
- (NSArray<NSTextField *> *)addRangeFilterWithLabel:(NSString *)labelText
                                         atPosition:(CGFloat *)yPosition
                                            spacing:(CGFloat)spacing {
    
    // Crea la label principale
    NSTextField *label = [self createLabel:labelText];
    [self.advancedFiltersTabView addSubview:label];
    
    // Crea le label min/max
    NSTextField *minLabel = [self createSmallLabel:@"Min:"];
    [self.advancedFiltersTabView addSubview:minLabel];
    
    NSTextField *maxLabel = [self createSmallLabel:@"Max:"];
    [self.advancedFiltersTabView addSubview:maxLabel];
    
    // Crea i field min/max
    NSTextField *minField = [[NSTextField alloc] init];
    minField.translatesAutoresizingMaskIntoConstraints = NO;
    minField.placeholderString = @"0";
    [self.advancedFiltersTabView addSubview:minField];
    
    NSTextField *maxField = [[NSTextField alloc] init];
    maxField.translatesAutoresizingMaskIntoConstraints = NO;
    maxField.placeholderString = @"∞";
    [self.advancedFiltersTabView addSubview:maxField];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Label principale
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:*yPosition],
        [label.widthAnchor constraintEqualToConstant:130],
        
        // Min label e field
        [minLabel.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [minLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [minLabel.widthAnchor constraintEqualToConstant:35],
        
        [minField.leadingAnchor constraintEqualToAnchor:minLabel.trailingAnchor constant:5],
        [minField.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [minField.widthAnchor constraintEqualToConstant:80],
        
        // Max label e field
        [maxLabel.leadingAnchor constraintEqualToAnchor:minField.trailingAnchor constant:10],
        [maxLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [maxLabel.widthAnchor constraintEqualToConstant:35],
        
        [maxField.leadingAnchor constraintEqualToAnchor:maxLabel.trailingAnchor constant:5],
        [maxField.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [maxField.widthAnchor constraintEqualToConstant:80]
    ]];
    
    // Aggiorna la posizione Y
    *yPosition += spacing;
    
    // Ritorna i field creati
    return @[minField, maxField];
}

/**
 * Crea un dropdown filter e lo aggiunge alla UI
 * Ritorna il popup button creato
 */
- (NSPopUpButton *)addDropdownWithLabel:(NSString *)labelText
                                options:(NSArray<NSString *> *)options
                             atPosition:(CGFloat *)yPosition
                                spacing:(CGFloat)spacing {
    
    // Crea la label
    NSTextField *label = [self createLabel:labelText];
    [self.advancedFiltersTabView addSubview:label];
    
    // Crea il popup button
    NSPopUpButton *popupButton = [[NSPopUpButton alloc] init];
    popupButton.translatesAutoresizingMaskIntoConstraints = NO;
    [popupButton removeAllItems];
    for (NSString *option in options) {
        [popupButton addItemWithTitle:option];
    }
    [self.advancedFiltersTabView addSubview:popupButton];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:*yPosition],
        [label.widthAnchor constraintEqualToConstant:130],
        
        [popupButton.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [popupButton.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [popupButton.widthAnchor constraintEqualToConstant:200]
    ]];
    
    // Aggiorna la posizione Y
    *yPosition += spacing;
    
    // Ritorna il popup creato
    return popupButton;
}

/**
 * Crea una label di sezione con stile bold
 */
- (NSTextField *)createSectionLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.editable = NO;
    label.selectable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont boldSystemFontOfSize:14];
    label.textColor = [NSColor labelColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

/**
 * Crea una label normale
 */
- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.editable = NO;
    label.selectable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:12];
    label.textColor = [NSColor labelColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

/**
 * Crea una piccola label per Min/Max
 */
- (NSTextField *)createSmallLabel:(NSString *)text {
    NSTextField *label = [self createLabel:text];
    label.font = [NSFont systemFontOfSize:10];
    label.textColor = [NSColor secondaryLabelColor];
    return label;
}

#pragma mark - setupFinancialRatioFilters (VERSIONE PULITA)

- (void)setupFinancialRatioFilters {
    CGFloat yPosition = 60;
    CGFloat spacing = 35;
    
    // ========================================================================
    // SEZIONE 1: BASIC FINANCIAL RATIOS
    // ========================================================================
    
    NSTextField *basicLabel = [self createSectionLabel:@"Basic Financial Ratios"];
    [self.advancedFiltersTabView addSubview:basicLabel];
    [NSLayoutConstraint activateConstraints:@[
        [basicLabel.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [basicLabel.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:yPosition]
    ]];
    yPosition += 40;
    
    // P/E Ratio
    NSArray *peFields = [self addRangeFilterWithLabel:@"P/E Ratio:" atPosition:&yPosition spacing:spacing];
    self.peRatioMinField = peFields[0];
    self.peRatioMaxField = peFields[1];
    
    // Forward P/E
    NSArray *forwardPEFields = [self addRangeFilterWithLabel:@"Forward P/E:" atPosition:&yPosition spacing:spacing];
    self.forwardPEMinField = forwardPEFields[0];
    self.forwardPEMaxField = forwardPEFields[1];
    
    // PEG Ratio
    NSArray *pegFields = [self addRangeFilterWithLabel:@"PEG Ratio:" atPosition:&yPosition spacing:spacing];
    self.pegRatioMinField = pegFields[0];
    self.pegRatioMaxField = pegFields[1];
    
    // Price-to-Book
    NSArray *ptbFields = [self addRangeFilterWithLabel:@"Price-to-Book:" atPosition:&yPosition spacing:spacing];
    self.priceToBookMinField = ptbFields[0];
    self.priceToBookMaxField = ptbFields[1];
    
    // Beta
    NSArray *betaFields = [self addRangeFilterWithLabel:@"Beta:" atPosition:&yPosition spacing:spacing];
    self.betaMinField = betaFields[0];
    self.betaMaxField = betaFields[1];
    
    yPosition += 20;
    
    // ========================================================================
    // SEZIONE 2: EARNINGS & DIVIDENDS
    // ========================================================================
    
    NSTextField *earningsLabel = [self createSectionLabel:@"Earnings & Dividends"];
    [self.advancedFiltersTabView addSubview:earningsLabel];
    [NSLayoutConstraint activateConstraints:@[
        [earningsLabel.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [earningsLabel.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:yPosition]
    ]];
    yPosition += 40;
    
    // EPS (TTM)
    NSArray *epsFields = [self addRangeFilterWithLabel:@"EPS (TTM):" atPosition:&yPosition spacing:spacing];
    self.epsTrailingTwelveMonthsMinField = epsFields[0];
    self.epsTrailingTwelveMonthsMaxField = epsFields[1];
    
    // EPS (Forward)
    NSArray *epsForwardFields = [self addRangeFilterWithLabel:@"EPS (Forward):" atPosition:&yPosition spacing:spacing];
    self.epsForwardMinField = epsForwardFields[0];
    self.epsForwardMaxField = epsForwardFields[1];
    
    // Dividend Yield (%)
    NSArray *divYieldFields = [self addRangeFilterWithLabel:@"Dividend Yield (%):" atPosition:&yPosition spacing:spacing];
    self.dividendYieldMinField = divYieldFields[0];
    self.dividendYieldMaxField = divYieldFields[1];
    
    // Annual Dividend Yield (%)
    NSArray *annualDivFields = [self addRangeFilterWithLabel:@"Annual Div Yield (%):" atPosition:&yPosition spacing:spacing];
    self.trailingAnnualDividendYieldMinField = annualDivFields[0];
    self.trailingAnnualDividendYieldMaxField = annualDivFields[1];
    
    // Dividend Rate ($)
    NSArray *divRateFields = [self addRangeFilterWithLabel:@"Dividend Rate ($):" atPosition:&yPosition spacing:spacing];
    self.dividendRateMinField = divRateFields[0];
    self.dividendRateMaxField = divRateFields[1];
    
    yPosition += 20;
    
    // ========================================================================
    // SEZIONE 3: PRICE & VOLUME
    // ========================================================================
    
    NSTextField *priceLabel = [self createSectionLabel:@"Price & Volume"];
    [self.advancedFiltersTabView addSubview:priceLabel];
    [NSLayoutConstraint activateConstraints:@[
        [priceLabel.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [priceLabel.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:yPosition]
    ]];
    yPosition += 40;
    
    // Price ($)
    NSArray *priceFields = [self addRangeFilterWithLabel:@"Price ($):" atPosition:&yPosition spacing:spacing];
    self.priceMinField = priceFields[0];
    self.priceMaxField = priceFields[1];
    
    // Market Cap ($)
    NSArray *marketCapFields = [self addRangeFilterWithLabel:@"Market Cap ($):" atPosition:&yPosition spacing:spacing];
    self.intradayMarketCapMinField = marketCapFields[0];
    self.intradayMarketCapMaxField = marketCapFields[1];
    
    // Day Volume
    NSArray *volumeFields = [self addRangeFilterWithLabel:@"Day Volume:" atPosition:&yPosition spacing:spacing];
    self.dayVolumeMinField = volumeFields[0];
    self.dayVolumeMaxField = volumeFields[1];
    
    // Average Volume (3M)
    NSArray *avgVolumeFields = [self addRangeFilterWithLabel:@"Avg Vol (3M):" atPosition:&yPosition spacing:spacing];
    self.averageDailyVolume3MonthMinField = avgVolumeFields[0];
    self.averageDailyVolume3MonthMaxField = avgVolumeFields[1];
    
    yPosition += 20;
    
    // ========================================================================
    // SEZIONE 4: PERFORMANCE (% CHANGE)
    // ========================================================================
    
    NSTextField *perfLabel = [self createSectionLabel:@"Performance (% Change)"];
    [self.advancedFiltersTabView addSubview:perfLabel];
    [NSLayoutConstraint activateConstraints:@[
        [perfLabel.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [perfLabel.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:yPosition]
    ]];
    yPosition += 40;
    
    // 1 Day (%)
    NSArray *oneDayFields = [self addRangeFilterWithLabel:@"1 Day (%):" atPosition:&yPosition spacing:spacing];
    self.oneDayPercentChangeMinField = oneDayFields[0];
    self.oneDayPercentChangeMaxField = oneDayFields[1];
    
    // 5 Day (%)
    NSArray *fiveDayFields = [self addRangeFilterWithLabel:@"5 Day (%):" atPosition:&yPosition spacing:spacing];
    self.fiveDayPercentChangeMinField = fiveDayFields[0];
    self.fiveDayPercentChangeMaxField = fiveDayFields[1];
    
    // 1 Month (%)
    NSArray *oneMonthFields = [self addRangeFilterWithLabel:@"1 Month (%):" atPosition:&yPosition spacing:spacing];
    self.oneMonthPercentChangeMinField = oneMonthFields[0];
    self.oneMonthPercentChangeMaxField = oneMonthFields[1];
    
    // 3 Month (%)
    NSArray *threeMonthFields = [self addRangeFilterWithLabel:@"3 Month (%):" atPosition:&yPosition spacing:spacing];
    self.threeMonthPercentChangeMinField = threeMonthFields[0];
    self.threeMonthPercentChangeMaxField = threeMonthFields[1];
    
    // 6 Month (%)
    NSArray *sixMonthFields = [self addRangeFilterWithLabel:@"6 Month (%):" atPosition:&yPosition spacing:spacing];
    self.sixMonthPercentChangeMinField = sixMonthFields[0];
    self.sixMonthPercentChangeMaxField = sixMonthFields[1];
    
    // 52 Week (%)
    NSArray *fiftyTwoWeekFields = [self addRangeFilterWithLabel:@"52 Week (%):" atPosition:&yPosition spacing:spacing];
    self.fiftyTwoWeekPercentChangeMinField = fiftyTwoWeekFields[0];
    self.fiftyTwoWeekPercentChangeMaxField = fiftyTwoWeekFields[1];
    
    yPosition += 20;
    
    // ========================================================================
    // SEZIONE 5: CATEGORIES
    // ========================================================================
    
    NSTextField *catLabel = [self createSectionLabel:@"Categories"];
    [self.advancedFiltersTabView addSubview:catLabel];
    [NSLayoutConstraint activateConstraints:@[
        [catLabel.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [catLabel.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:yPosition]
    ]];
    yPosition += 40;
    
    // Security Type
    self.secTypePopup = [self addDropdownWithLabel:@"Security Type:"
                                           options:@[@"All Types", @"Stock", @"ETF", @"Index", @"Mutual Fund"]
                                        atPosition:&yPosition
                                           spacing:spacing];
    
    // Exchange
    self.exchangePopup = [self addDropdownWithLabel:@"Exchange:"
                                            options:@[@"All Exchanges", @"NYSE", @"NASDAQ", @"AMEX", @"OTC"]
                                         atPosition:&yPosition
                                            spacing:spacing];
    
    // Industry
    self.industryPopup = [self addDropdownWithLabel:@"Industry:"
                                            options:[self getIndustryOptions]
                                         atPosition:&yPosition
                                            spacing:spacing];
    
    // Peer Group
    self.peerGroupPopup = [self addDropdownWithLabel:@"Peer Group:"
                                             options:@[@"All Groups", @"Large Cap", @"Mid Cap", @"Small Cap", @"Micro Cap"]
                                          atPosition:&yPosition
                                             spacing:spacing];
}

#pragma mark - Helper per Industry Options

- (NSArray<NSString *> *)getIndustryOptions {
    return @[
        @"All Industries",
        @"Software",
        @"Semiconductors",
        @"Biotechnology",
        @"Pharmaceuticals",
        @"Banks",
        @"Insurance",
        @"Real Estate",
        @"Oil & Gas",
        @"Utilities",
        @"Retail",
        @"Automotive",
        @"Aerospace & Defense",
        @"Telecommunications",
        @"Media & Entertainment",
        @"Food & Beverage",
        @"Consumer Goods",
        @"Industrial Equipment",
        @"Construction",
        @"Transportation"
    ];
}

- (void)addRangeFilter:(NSString *)labelText
              minField:(NSTextField **)minField
              maxField:(NSTextField **)maxField
                  yPos:(CGFloat)yPos {
    
    NSTextField *label = [self createLabel:labelText];
    [self.advancedFiltersTabView addSubview:label];
    
    NSTextField *minLabel = [self createSmallLabel:@"Min:"];
    [self.advancedFiltersTabView addSubview:minLabel];
    
    *minField = [[NSTextField alloc] init];
    (*minField).translatesAutoresizingMaskIntoConstraints = NO;
    (*minField).placeholderString = @"0";
    [self.advancedFiltersTabView addSubview:*minField];
    
    NSTextField *maxLabel = [self createSmallLabel:@"Max:"];
    [self.advancedFiltersTabView addSubview:maxLabel];
    
    *maxField = [[NSTextField alloc] init];
    (*maxField).translatesAutoresizingMaskIntoConstraints = NO;
    (*maxField).placeholderString = @"∞";
    [self.advancedFiltersTabView addSubview:*maxField];
    
    // Constraints for range filter
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:yPos],
        [label.widthAnchor constraintEqualToConstant:120],
        
        [minLabel.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [minLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [minLabel.widthAnchor constraintEqualToConstant:30],
        
        [(*minField).leadingAnchor constraintEqualToAnchor:minLabel.trailingAnchor constant:5],
        [(*minField).centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [(*minField).widthAnchor constraintEqualToConstant:80],
        
        [maxLabel.leadingAnchor constraintEqualToAnchor:(*minField).trailingAnchor constant:10],
        [maxLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [maxLabel.widthAnchor constraintEqualToConstant:30],
        
        [(*maxField).leadingAnchor constraintEqualToAnchor:maxLabel.trailingAnchor constant:5],
        [(*maxField).centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [(*maxField).widthAnchor constraintEqualToConstant:80]
    ]];
}


- (void)collectFinancialRatioFilters {
    // BASIC FINANCIAL RATIOS
    [self collectRangeFilter:@"trailingPE"
                 displayName:@"P/E Ratio"
                    minField:self.peRatioMinField
                    maxField:self.peRatioMaxField];
    
    [self collectRangeFilter:@"forwardPE"
                 displayName:@"Forward P/E"
                    minField:self.forwardPEMinField
                    maxField:self.forwardPEMaxField];
    
    [self collectRangeFilter:@"pegRatio"
                 displayName:@"PEG Ratio"
                    minField:self.pegRatioMinField
                    maxField:self.pegRatioMaxField];
    
    [self collectRangeFilter:@"priceToBook"
                 displayName:@"Price-to-Book"
                    minField:self.priceToBookMinField
                    maxField:self.priceToBookMaxField];
    
    [self collectRangeFilter:@"beta"
                 displayName:@"Beta"
                    minField:self.betaMinField
                    maxField:self.betaMaxField];
    
    // EARNINGS & DIVIDENDS
    [self collectRangeFilter:@"epsTrailingTwelveMonths"
                 displayName:@"EPS (TTM)"
                    minField:self.epsTrailingTwelveMonthsMinField
                    maxField:self.epsTrailingTwelveMonthsMaxField];
    
    [self collectRangeFilter:@"epsForward"
                 displayName:@"EPS (Forward)"
                    minField:self.epsForwardMinField
                    maxField:self.epsForwardMaxField];
    
    [self collectRangeFilter:@"dividendYield"
                 displayName:@"Dividend Yield"
                    minField:self.dividendYieldMinField
                    maxField:self.dividendYieldMaxField];
    
    [self collectRangeFilter:@"trailingAnnualDividendYield"
                 displayName:@"Annual Dividend Yield"
                    minField:self.trailingAnnualDividendYieldMinField
                    maxField:self.trailingAnnualDividendYieldMaxField];
    
    [self collectRangeFilter:@"dividendRate"
                 displayName:@"Dividend Rate"
                    minField:self.dividendRateMinField
                    maxField:self.dividendRateMaxField];
    
    // PRICE & VOLUME
    [self collectRangeFilter:@"price"
                 displayName:@"Price"
                    minField:self.priceMinField
                    maxField:self.priceMaxField];
    
    [self collectRangeFilter:@"intradaymarketcap"
                 displayName:@"Market Cap"
                    minField:self.intradayMarketCapMinField
                    maxField:self.intradayMarketCapMaxField];
    
    [self collectRangeFilter:@"dayvolume"
                 displayName:@"Day Volume"
                    minField:self.dayVolumeMinField
                    maxField:self.dayVolumeMaxField];
    
    [self collectRangeFilter:@"averageDailyVolume3Month"
                 displayName:@"Average Daily Volume (3M)"
                    minField:self.averageDailyVolume3MonthMinField
                    maxField:self.averageDailyVolume3MonthMaxField];
    
    // PERFORMANCE FILTERS
    [self collectRangeFilter:@"oneDayPercentChange"
                 displayName:@"1 Day % Change"
                    minField:self.oneDayPercentChangeMinField
                    maxField:self.oneDayPercentChangeMaxField];
    
    [self collectRangeFilter:@"fiveDayPercentChange"
                 displayName:@"5 Day % Change"
                    minField:self.fiveDayPercentChangeMinField
                    maxField:self.fiveDayPercentChangeMaxField];
    
    [self collectRangeFilter:@"oneMonthPercentChange"
                 displayName:@"1 Month % Change"
                    minField:self.oneMonthPercentChangeMinField
                    maxField:self.oneMonthPercentChangeMaxField];
    
    [self collectRangeFilter:@"threeMonthPercentChange"
                 displayName:@"3 Month % Change"
                    minField:self.threeMonthPercentChangeMinField
                    maxField:self.threeMonthPercentChangeMaxField];
    
    [self collectRangeFilter:@"sixMonthPercentChange"
                 displayName:@"6 Month % Change"
                    minField:self.sixMonthPercentChangeMinField
                    maxField:self.sixMonthPercentChangeMaxField];
    
    [self collectRangeFilter:@"fiftyTwoWeekPercentChange"
                 displayName:@"52 Week % Change"
                    minField:self.fiftyTwoWeekPercentChangeMinField
                    maxField:self.fiftyTwoWeekPercentChangeMaxField];
    
    // CATEGORY FILTERS
    [self collectSelectFilter:@"sec_type"
                  displayName:@"Security Type"
                        popup:self.secTypePopup];
    
    [self collectSelectFilter:@"exchange"
                  displayName:@"Exchange"
                        popup:self.exchangePopup];
    
    [self collectSelectFilter:@"industry"
                  displayName:@"Industry"
                        popup:self.industryPopup];
    
    [self collectSelectFilter:@"peer_group"
                  displayName:@"Peer Group"
                        popup:self.peerGroupPopup];
}

// METODI HELPER PER RACCOGLIERE I FILTRI

- (void)collectRangeFilter:(NSString *)key
               displayName:(NSString *)displayName
                  minField:(NSTextField *)minField
                  maxField:(NSTextField *)maxField {
    
    // ✅ CONTROLLA che i field esistano
    if (!minField || !maxField) {
        NSLog(@"❌ collectRangeFilter: Field is nil for key %@", key);
        return;
    }
    
    // ✅ CONTROLLA se almeno uno dei field ha un valore
    BOOL hasMinValue = minField.stringValue.length > 0;
    BOOL hasMaxValue = maxField.stringValue.length > 0;
    
    if (!hasMinValue && !hasMaxValue) {
        // Nessun filtro da applicare
        return;
    }
    
    // ✅ CREA il filtro
    AdvancedScreenerFilter *filter = [AdvancedScreenerFilter filterWithKey:key
                                                               displayName:displayName
                                                                      type:AdvancedFilterTypeRange];
    
    // ✅ GESTIONE SICURA dei valori NSNumber
    if (hasMinValue) {
        // Crea NSNumber e mantienilo in scope
        double minValue = [minField.stringValue doubleValue];
        filter.minValue = [NSNumber numberWithDouble:minValue];
        NSLog(@"✅ Min value for %@: %.2f", key, minValue);
    } else {
        filter.minValue = nil;
    }
    
    if (hasMaxValue) {
        // Crea NSNumber e mantienilo in scope
        double maxValue = [maxField.stringValue doubleValue];
        filter.maxValue = [NSNumber numberWithDouble:maxValue];
        NSLog(@"✅ Max value for %@: %.2f", key, maxValue);
    } else {
        filter.maxValue = nil;
    }
    
    // ✅ IMPOSTA gli altri parametri
    filter.isActive = YES;
    
    // ✅ SALVA il filtro
    [self.activeFilters setObject:filter forKey:key];
    
    NSLog(@"✅ Added range filter: %@ (min=%@, max=%@)",
          displayName,
          filter.minValue ?: @"nil",
          filter.maxValue ?: @"nil");
}


- (void)collectSelectFilter:(NSString *)key
                displayName:(NSString *)displayName
                      popup:(NSPopUpButton *)popup {
    
    NSString *selectedValue = popup.titleOfSelectedItem;
    if (![selectedValue hasPrefix:@"All"]) {
        AdvancedScreenerFilter *filter = [AdvancedScreenerFilter filterWithKey:key
                                                                   displayName:displayName
                                                                          type:AdvancedFilterTypeSelect];
        filter.value = selectedValue;
        filter.isActive = YES;
        self.activeFilters[key] = filter;
    }
}


- (void)setupSectionLabel:(NSTextField *)label atPosition:(CGFloat *)yPosition {
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:*yPosition],
        [label.widthAnchor constraintEqualToConstant:300]
    ]];
    *yPosition += 25;
}



- (void)addSelectFilterAtPosition:(CGFloat *)yPosition
                            label:(NSString *)labelText
                            popup:(NSPopUpButton **)popup
                          options:(NSArray<NSString *> *)options
                          spacing:(CGFloat)spacing {
    
    NSTextField *label = [self createLabel:labelText];
    [self.advancedFiltersTabView addSubview:label];
    
    *popup = [[NSPopUpButton alloc] init];
    (*popup).translatesAutoresizingMaskIntoConstraints = NO;
    [(*popup) removeAllItems];
    for (NSString *option in options) {
        [(*popup) addItemWithTitle:option];
    }
    [self.advancedFiltersTabView addSubview:*popup];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:*yPosition],
        [label.widthAnchor constraintEqualToConstant:130],
        
        [(*popup).leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [(*popup).centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [(*popup).widthAnchor constraintEqualToConstant:200]
    ]];
    
    *yPosition += spacing;
}


- (void)addRangeFilterAtPosition:(CGFloat *)yPosition
                           label:(NSString *)labelText
                        minField:(NSTextField **)minField
                        maxField:(NSTextField **)maxField
                         spacing:(CGFloat)spacing {
    
    NSTextField *label = [self createLabel:labelText];
    [self.advancedFiltersTabView addSubview:label];
    
    NSTextField *minLabel = [self createSmallLabel:@"Min:"];
    [self.advancedFiltersTabView addSubview:minLabel];
    
    *minField = [[NSTextField alloc] init];
    (*minField).translatesAutoresizingMaskIntoConstraints = NO;
    (*minField).placeholderString = @"0";
    [self.advancedFiltersTabView addSubview:*minField];
    
    NSTextField *maxLabel = [self createSmallLabel:@"Max:"];
    [self.advancedFiltersTabView addSubview:maxLabel];
    
    *maxField = [[NSTextField alloc] init];
    (*maxField).translatesAutoresizingMaskIntoConstraints = NO;
    (*maxField).placeholderString = @"∞";
    [self.advancedFiltersTabView addSubview:*maxField];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:*yPosition],
        [label.widthAnchor constraintEqualToConstant:130],
        
        [minLabel.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [minLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [minLabel.widthAnchor constraintEqualToConstant:35],
        
        [(*minField).leadingAnchor constraintEqualToAnchor:minLabel.trailingAnchor constant:5],
        [(*minField).centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [(*minField).widthAnchor constraintEqualToConstant:80],
        
        [maxLabel.leadingAnchor constraintEqualToAnchor:(*minField).trailingAnchor constant:10],
        [maxLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [maxLabel.widthAnchor constraintEqualToConstant:35],
        
        [(*maxField).leadingAnchor constraintEqualToAnchor:maxLabel.trailingAnchor constant:5],
        [(*maxField).centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [(*maxField).widthAnchor constraintEqualToConstant:80]
    ]];
    
    *yPosition += spacing;
}

- (void)addSingleFilter:(NSString *)labelText
                  field:(NSTextField **)field
                   yPos:(CGFloat)yPos
            placeholder:(NSString *)placeholder {
    
    NSTextField *label = [self createLabel:labelText];
    [self.advancedFiltersTabView addSubview:label];
    
    *field = [[NSTextField alloc] init];
    (*field).translatesAutoresizingMaskIntoConstraints = NO;
    (*field).placeholderString = placeholder;
    [self.advancedFiltersTabView addSubview:*field];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:yPos],
        [label.widthAnchor constraintEqualToConstant:150],
        
        [(*field).leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:10],
        [(*field).centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [(*field).widthAnchor constraintEqualToConstant:100]
    ]];
}

#pragma mark - Enhanced Table Setup

- (void)setupEnhancedTableColumns {
    // Basic columns
    [self addTableColumn:@"symbol" title:@"Symbol" width:80];
    [self addTableColumn:@"name" title:@"Name" width:180];
    [self addTableColumn:@"price" title:@"Price" width:80];
    [self addTableColumn:@"changePercent" title:@"Change %" width:80];
    [self addTableColumn:@"volume" title:@"Volume" width:100];
    [self addTableColumn:@"marketCap" title:@"Market Cap" width:120];
    
    // Enhanced financial columns
    [self addTableColumn:@"trailingPE" title:@"P/E" width:60];
    [self addTableColumn:@"pegRatio" title:@"PEG" width:60];
    [self addTableColumn:@"priceToBook" title:@"P/B" width:60];
    [self addTableColumn:@"dividendYield" title:@"Div %" width:60];
    [self addTableColumn:@"beta" title:@"Beta" width:60];
    [self addTableColumn:@"sector" title:@"Sector" width:120];
    
}

- (void)addTableColumn:(NSString *)identifier title:(NSString *)title width:(CGFloat)width {
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier];
    column.title = title;
    column.width = width;
    column.minWidth = width * 0.7;
    column.sortDescriptorPrototype = [[NSSortDescriptor alloc] initWithKey:identifier ascending:YES];
    [self.resultsTable addTableColumn:column];
}

#pragma mark - Helper Methods



#pragma mark - Constraints Setup Methods

- (void)setupBasicFiltersConstraints:(NSTextField *)typeLabel
                       settingsLabel:(NSTextField *)settingsLabel
                     maxResultsLabel:(NSTextField *)maxResultsLabel
                   quickFiltersLabel:(NSTextField *)quickFiltersLabel
                      minVolumeLabel:(NSTextField *)minVolumeLabel
                   minMarketCapLabel:(NSTextField *)minMarketCapLabel
                         sectorLabel:(NSTextField *)sectorLabel
                     apiConfigLabel:(NSTextField *)apiConfigLabel
                 testConnectionButton:(NSButton *)testConnectionButton
                     apiStatusLabel:(NSTextField *)apiStatusLabel {
    
    [NSLayoutConstraint activateConstraints:@[
        // Screener Type
        [typeLabel.topAnchor constraintEqualToAnchor:self.basicFiltersTabView.topAnchor constant:20],
        [typeLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [self.screenerTypePopup.topAnchor constraintEqualToAnchor:typeLabel.bottomAnchor constant:8],
        [self.screenerTypePopup.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        [self.screenerTypePopup.trailingAnchor constraintEqualToAnchor:self.basicFiltersTabView.trailingAnchor constant:-20],
        
        // Settings
        [settingsLabel.topAnchor constraintEqualToAnchor:self.screenerTypePopup.bottomAnchor constant:20],
        [settingsLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [maxResultsLabel.topAnchor constraintEqualToAnchor:settingsLabel.bottomAnchor constant:8],
        [maxResultsLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [self.maxResultsField.centerYAnchor constraintEqualToAnchor:maxResultsLabel.centerYAnchor],
        [self.maxResultsField.leadingAnchor constraintEqualToAnchor:maxResultsLabel.trailingAnchor constant:8],
        [self.maxResultsField.widthAnchor constraintEqualToConstant:80],
        
        [self.autoRefreshCheckbox.topAnchor constraintEqualToAnchor:maxResultsLabel.bottomAnchor constant:8],
        [self.autoRefreshCheckbox.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        // Quick Filters
        [quickFiltersLabel.topAnchor constraintEqualToAnchor:self.autoRefreshCheckbox.bottomAnchor constant:20],
        [quickFiltersLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [minVolumeLabel.topAnchor constraintEqualToAnchor:quickFiltersLabel.bottomAnchor constant:8],
        [minVolumeLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [self.minVolumeField.centerYAnchor constraintEqualToAnchor:minVolumeLabel.centerYAnchor],
        [self.minVolumeField.leadingAnchor constraintEqualToAnchor:minVolumeLabel.trailingAnchor constant:8],
        [self.minVolumeField.trailingAnchor constraintEqualToAnchor:self.basicFiltersTabView.trailingAnchor constant:-20],
        
        [minMarketCapLabel.topAnchor constraintEqualToAnchor:minVolumeLabel.bottomAnchor constant:8],
        [minMarketCapLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [self.minMarketCapField.centerYAnchor constraintEqualToAnchor:minMarketCapLabel.centerYAnchor],
        [self.minMarketCapField.leadingAnchor constraintEqualToAnchor:minMarketCapLabel.trailingAnchor constant:8],
        [self.minMarketCapField.trailingAnchor constraintEqualToAnchor:self.basicFiltersTabView.trailingAnchor constant:-20],
        
        [sectorLabel.topAnchor constraintEqualToAnchor:minMarketCapLabel.bottomAnchor constant:8],
        [sectorLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [self.sectorPopup.centerYAnchor constraintEqualToAnchor:sectorLabel.centerYAnchor],
        [self.sectorPopup.leadingAnchor constraintEqualToAnchor:sectorLabel.trailingAnchor constant:8],
        [self.sectorPopup.trailingAnchor constraintEqualToAnchor:self.basicFiltersTabView.trailingAnchor constant:-20],
        
        // Action buttons
        [self.applyFiltersButton.topAnchor constraintEqualToAnchor:self.sectorPopup.bottomAnchor constant:20],
        [self.applyFiltersButton.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        [self.applyFiltersButton.widthAnchor constraintEqualToConstant:120],
        
        [self.clearFiltersButton.centerYAnchor constraintEqualToAnchor:self.applyFiltersButton.centerYAnchor],
        [self.clearFiltersButton.leadingAnchor constraintEqualToAnchor:self.applyFiltersButton.trailingAnchor constant:12],
        [self.clearFiltersButton.widthAnchor constraintEqualToConstant:120],
        
        // API Configuration
        [apiConfigLabel.topAnchor constraintEqualToAnchor:self.clearFiltersButton.bottomAnchor constant:30],
        [apiConfigLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [testConnectionButton.topAnchor constraintEqualToAnchor:apiConfigLabel.bottomAnchor constant:8],
        [testConnectionButton.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        [testConnectionButton.widthAnchor constraintEqualToConstant:140],
        
        [apiStatusLabel.topAnchor constraintEqualToAnchor:testConnectionButton.bottomAnchor constant:12],
        [apiStatusLabel.leadingAnchor constraintEqualToAnchor:self.basicFiltersTabView.leadingAnchor constant:20],
        
        [self.apiStatusValueField.centerYAnchor constraintEqualToAnchor:apiStatusLabel.centerYAnchor],
        [self.apiStatusValueField.leadingAnchor constraintEqualToAnchor:apiStatusLabel.trailingAnchor constant:8],
        [self.apiStatusValueField.trailingAnchor constraintEqualToAnchor:self.basicFiltersTabView.trailingAnchor constant:-20]
    ]];
}

- (void)setupAdvancedFiltersConstraints:(NSTextField *)titleLabel {
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.advancedFiltersTabView.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        
        // Bottom section con checkbox
        [self.combineWithBasicCheckbox.bottomAnchor constraintEqualToAnchor:self.advancedFiltersTabView.bottomAnchor constant:-20],
        [self.combineWithBasicCheckbox.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [self.combineWithBasicCheckbox.trailingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.trailingAnchor constant:-20],
        
        // Apply button sopra checkbox
        [self.applyAdvancedFiltersButton.bottomAnchor constraintEqualToAnchor:self.combineWithBasicCheckbox.topAnchor constant:-12],
        [self.applyAdvancedFiltersButton.leadingAnchor constraintEqualToAnchor:self.advancedFiltersTabView.leadingAnchor constant:20],
        [self.applyAdvancedFiltersButton.widthAnchor constraintEqualToConstant:160],
        
        // Clear button accanto ad Apply
        [self.clearAdvancedFiltersButton.centerYAnchor constraintEqualToAnchor:self.applyAdvancedFiltersButton.centerYAnchor],
        [self.clearAdvancedFiltersButton.leadingAnchor constraintEqualToAnchor:self.applyAdvancedFiltersButton.trailingAnchor constant:12],
        [self.clearAdvancedFiltersButton.widthAnchor constraintEqualToConstant:130]
    ]];
}
#pragma mark - Data Methods

- (void)refreshData {
    self.statusLabel.stringValue = @"Loading...";
    [self.refreshButton setEnabled:NO];
    
    // Check if we have advanced filters active
    if (self.activeFilters.count > 0) {
        [self applyAdvancedFilters];
        return;
    }
    
    // Use basic screener or quick filters
    YahooScreenerPreset preset = [self convertScreenerTypeToPreset];
    
    // Check for basic filters
    NSNumber *minVolume = [self getMinVolumeFilter];
    NSNumber *minMarketCap = [self getMinMarketCapFilter];
    NSString *sector = [self getSectorFilter];
    
    if (minVolume || minMarketCap || sector) {
        // Use quick screener
        [[YahooScreenerAPI sharedManager] fetchQuickScreener:preset
                                                   minVolume:minVolume
                                                minMarketCap:minMarketCap
                                                      sector:sector
                                                  maxResults:self.maxResults
                                                  completion:^(NSArray<YahooScreenerResult *> *results, NSError *error) {
            [self handleScreenerResults:results error:error];
        }];
    } else {
        // Use basic preset screener
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
            self.statusLabel.textColor = [NSColor systemRedColor];
            
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
        self.statusLabel.textColor = [NSColor labelColor];
        
        NSLog(@"✅ ScreenerWidget: Successfully loaded %lu results", (unsigned long)results.count);
    });
}

#pragma mark - Filter Methods

- (void)loadAvailableFilters {
    [self.filterCategories removeAllObjects];
    
    // Basic Financial Ratios Category
    NSArray<AdvancedScreenerFilter *> *basicRatioFilters = @[
        [AdvancedScreenerFilter filterWithKey:@"trailingPE" displayName:@"Trailing P/E" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"forwardPE" displayName:@"Forward P/E" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"pegRatio" displayName:@"PEG Ratio" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"priceToBook" displayName:@"Price-to-Book" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"beta" displayName:@"Beta" type:AdvancedFilterTypeRange]
    ];
    
    FilterCategory *basicRatiosCategory = [FilterCategory categoryWithName:@"Basic Financial Ratios"
                                                                       key:@"basic_ratios"
                                                                   filters:basicRatioFilters];
    [self.filterCategories addObject:basicRatiosCategory];
    
    // Earnings & Dividends Category
    NSArray<AdvancedScreenerFilter *> *earningsFilters = @[
        [AdvancedScreenerFilter filterWithKey:@"epsTrailingTwelveMonths" displayName:@"EPS (TTM)" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"epsForward" displayName:@"EPS (Forward)" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"dividendYield" displayName:@"Dividend Yield %" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"trailingAnnualDividendYield" displayName:@"Annual Dividend Yield %" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"dividendRate" displayName:@"Dividend Rate ($)" type:AdvancedFilterTypeRange]
    ];
    
    FilterCategory *earningsCategory = [FilterCategory categoryWithName:@"Earnings & Dividends"
                                                                    key:@"earnings"
                                                                filters:earningsFilters];
    [self.filterCategories addObject:earningsCategory];
    
    // Price & Volume Category
    NSArray<AdvancedScreenerFilter *> *priceVolumeFilters = @[
        [AdvancedScreenerFilter filterWithKey:@"price" displayName:@"Price ($)" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"intradaymarketcap" displayName:@"Market Cap ($)" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"dayvolume" displayName:@"Day Volume" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"averageDailyVolume3Month" displayName:@"Avg Volume (3M)" type:AdvancedFilterTypeRange]
    ];
    
    FilterCategory *priceVolumeCategory = [FilterCategory categoryWithName:@"Price & Volume"
                                                                       key:@"price_volume"
                                                                   filters:priceVolumeFilters];
    [self.filterCategories addObject:priceVolumeCategory];
    
    // Performance Category
    NSArray<AdvancedScreenerFilter *> *performanceFilters = @[
        [AdvancedScreenerFilter filterWithKey:@"oneDayPercentChange" displayName:@"1 Day % Change" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"fiveDayPercentChange" displayName:@"5 Day % Change" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"oneMonthPercentChange" displayName:@"1 Month % Change" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"threeMonthPercentChange" displayName:@"3 Month % Change" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"sixMonthPercentChange" displayName:@"6 Month % Change" type:AdvancedFilterTypeRange],
        [AdvancedScreenerFilter filterWithKey:@"fiftyTwoWeekPercentChange" displayName:@"52 Week % Change" type:AdvancedFilterTypeRange]
    ];
    
    FilterCategory *performanceCategory = [FilterCategory categoryWithName:@"Performance (% Change)"
                                                                       key:@"performance"
                                                                   filters:performanceFilters];
    [self.filterCategories addObject:performanceCategory];
    
    // Categories Category
    NSArray<AdvancedScreenerFilter *> *categoryFilters = @[
        [AdvancedScreenerFilter selectFilterWithKey:@"sec_type" displayName:@"Security Type" options:@[@"All Types", @"Stock", @"ETF", @"Index", @"Mutual Fund"]],
        [AdvancedScreenerFilter selectFilterWithKey:@"exchange" displayName:@"Exchange" options:@[@"All Exchanges", @"NYSE", @"NASDAQ", @"AMEX", @"OTC"]],
        [AdvancedScreenerFilter selectFilterWithKey:@"industry" displayName:@"Industry" options:[self getIndustryOptions]],
        [AdvancedScreenerFilter selectFilterWithKey:@"peer_group" displayName:@"Peer Group" options:@[@"All Groups", @"Large Cap", @"Mid Cap", @"Small Cap", @"Micro Cap"]]
    ];
    
    FilterCategory *categoriesCategory = [FilterCategory categoryWithName:@"Categories"
                                                                      key:@"categories"
                                                                  filters:categoryFilters];
    [self.filterCategories addObject:categoriesCategory];
    
    NSLog(@"✅ ScreenerWidget: Loaded %lu filter categories with comprehensive filters", (unsigned long)self.filterCategories.count);
}

- (void)applyAdvancedFilters {
    [self.activeFilters removeAllObjects];
    
    // Collect all active advanced filters
    [self collectFinancialRatioFilters];
    
    if (self.activeFilters.count == 0) {
        [self refreshData];
        return;
    }
    
    // AGGIUNGI QUESTA LINEA - Leggi maxResults dal campo UI
    NSInteger maxResults = [self.maxResultsField.stringValue integerValue];
    if (maxResults <= 0) {
        maxResults = 100; // fallback
    }
    
    self.statusLabel.stringValue = @"Applying advanced filters...";
    [self.refreshButton setEnabled:NO];
    
    // Convert to YahooScreenerFilter array
    NSMutableArray<YahooScreenerFilter *> *filters = [NSMutableArray array];
    for (NSString *key in self.activeFilters) {
        AdvancedScreenerFilter *advFilter = self.activeFilters[key];
        YahooScreenerFilter *filter = [self convertToYahooFilter:advFilter];
        if (filter) {
            [filters addObject:filter];
        }
    }
    
    BOOL combineWithBasic = (self.combineWithBasicCheckbox.state == NSControlStateValueOn);
    
    // USA maxResults dal campo UI invece di self.maxResults
    [self fetchAdvancedScreenerWithFilters:filters
                            combineWithBasic:combineWithBasic
                                  maxResults:maxResults  // <- CORRETTO
                                  completion:^(NSArray<YahooScreenerResult *> *results, NSError *error) {
        [self handleScreenerResults:results error:error];
    }];
}


- (void)fetchAdvancedScreenerWithFilters:(NSArray<YahooScreenerFilter *> *)filters
                          combineWithBasic:(BOOL)combineWithBasic
                                maxResults:(NSInteger)maxResults
                                completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *error))completion {
    
    // Chiama il nuovo metodo di YahooScreenerAPI
    [[YahooScreenerAPI sharedManager] fetchAdvancedScreenerWithFilters:filters
                                                        combineWithBasic:combineWithBasic
                                                              maxResults:maxResults
                                                              completion:completion];
}

- (YahooScreenerFilter *)convertToYahooFilter:(AdvancedScreenerFilter *)advFilter {
    YahooScreenerFilter *filter = [[YahooScreenerFilter alloc] init];
    filter.field = advFilter.key;
    
    if (advFilter.type == AdvancedFilterTypeRange) {
        if (advFilter.minValue && advFilter.maxValue) {
            filter.comparison = YahooFilterBetween;
            filter.values = @[advFilter.minValue, advFilter.maxValue];
        } else if (advFilter.minValue) {
            filter.comparison = YahooFilterGreaterThan;
            filter.values = @[advFilter.minValue];
        } else if (advFilter.maxValue) {
            filter.comparison = YahooFilterLessThan;
            filter.values = @[advFilter.maxValue];
        } else {
            return nil; // No valid range
        }
    } else if (advFilter.type == AdvancedFilterTypeNumber) {
        filter.comparison = YahooFilterGreaterThan;
        filter.values = @[advFilter.value];
    } else if (advFilter.type == AdvancedFilterTypeSelect) {
        filter.comparison = YahooFilterEqual;
        filter.values = @[advFilter.value];
    } else {
        return nil; // Unsupported type
    }
    
    return filter;
}

- (void)clearAllFilters {
    [self clearBasicFilters];
    [self clearAdvancedFilters];
}

- (void)clearBasicFilters {
    self.minVolumeField.stringValue = @"";
    self.minMarketCapField.stringValue = @"";
    [self.sectorPopup selectItemAtIndex:0]; // "All Sectors"
    NSLog(@"🗑️ ScreenerWidget: Cleared basic filters");
}

- (void)clearAdvancedFilters {
    [self.activeFilters removeAllObjects];
    
    // BASIC FINANCIAL RATIOS
    self.peRatioMinField.stringValue = @"";
    self.peRatioMaxField.stringValue = @"";
    self.forwardPEMinField.stringValue = @"";
    self.forwardPEMaxField.stringValue = @"";
    self.pegRatioMinField.stringValue = @"";
    self.pegRatioMaxField.stringValue = @"";
    self.priceToBookMinField.stringValue = @"";
    self.priceToBookMaxField.stringValue = @"";
    self.betaMinField.stringValue = @"";
    self.betaMaxField.stringValue = @"";
    
    // EARNINGS & DIVIDENDS
    self.epsTrailingTwelveMonthsMinField.stringValue = @"";
    self.epsTrailingTwelveMonthsMaxField.stringValue = @"";
    self.epsForwardMinField.stringValue = @"";
    self.epsForwardMaxField.stringValue = @"";
    self.dividendYieldMinField.stringValue = @"";
    self.dividendYieldMaxField.stringValue = @"";
    self.trailingAnnualDividendYieldMinField.stringValue = @"";
    self.trailingAnnualDividendYieldMaxField.stringValue = @"";
    self.dividendRateMinField.stringValue = @"";
    self.dividendRateMaxField.stringValue = @"";
    
    // PRICE & VOLUME
    self.priceMinField.stringValue = @"";
    self.priceMaxField.stringValue = @"";
    self.intradayMarketCapMinField.stringValue = @"";
    self.intradayMarketCapMaxField.stringValue = @"";
    self.dayVolumeMinField.stringValue = @"";
    self.dayVolumeMaxField.stringValue = @"";
    self.averageDailyVolume3MonthMinField.stringValue = @"";
    self.averageDailyVolume3MonthMaxField.stringValue = @"";
    
    // PERFORMANCE
    self.oneDayPercentChangeMinField.stringValue = @"";
    self.oneDayPercentChangeMaxField.stringValue = @"";
    self.fiveDayPercentChangeMinField.stringValue = @"";
    self.fiveDayPercentChangeMaxField.stringValue = @"";
    self.oneMonthPercentChangeMinField.stringValue = @"";
    self.oneMonthPercentChangeMaxField.stringValue = @"";
    self.threeMonthPercentChangeMinField.stringValue = @"";
    self.threeMonthPercentChangeMaxField.stringValue = @"";
    self.sixMonthPercentChangeMinField.stringValue = @"";
    self.sixMonthPercentChangeMaxField.stringValue = @"";
    self.fiftyTwoWeekPercentChangeMinField.stringValue = @"";
    self.fiftyTwoWeekPercentChangeMaxField.stringValue = @"";
    
    // CATEGORY FILTERS
    [self.secTypePopup selectItemAtIndex:0];
    [self.exchangePopup selectItemAtIndex:0];
    [self.industryPopup selectItemAtIndex:0];
    [self.peerGroupPopup selectItemAtIndex:0];
    
    NSLog(@"🗑️ ScreenerWidget: Cleared all advanced filters");
}


#pragma mark - Action Methods

- (IBAction)screenerTypeChanged:(id)sender {
    NSInteger selectedIndex = self.screenerTypePopup.indexOfSelectedItem;
    self.screenerType = (YahooScreenerType)selectedIndex;
    NSLog(@"🎯 ScreenerWidget: Changed screener type to index %ld", (long)selectedIndex);
    [self refreshData];
}

- (IBAction)autoRefreshChanged:(id)sender {
    self.autoRefresh = (self.autoRefreshCheckbox.state == NSControlStateValueOn);
    [self updateAutoRefreshTimer];
}

- (void)applyBasicFilters {
    // Update maxResults from UI
    NSInteger maxResults = [self.maxResultsField.stringValue integerValue];
    if (maxResults > 0) {
        self.maxResults = maxResults;
    }
    
    [self refreshData];
}

- (IBAction)testConnectionButtonClicked:(id)sender {
    self.apiStatusValueField.stringValue = @"Testing...";
    
    [[YahooScreenerAPI sharedManager] checkServiceAvailability:^(BOOL available, NSString *version) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            if (available) {
                alert.messageText = @"Connection Successful";
                alert.informativeText = [NSString stringWithFormat:@"API service is available\nVersion: %@", version ?: @"unknown"];
                [self updateAPIStatus:@"Connected" color:[NSColor systemGreenColor]];
            } else {
                alert.messageText = @"Connection Failed";
                alert.informativeText = @"Unable to reach Yahoo Screener API service. Please check your internet connection and backend service.";
                [self updateAPIStatus:@"Failed" color:[NSColor systemRedColor]];
            }
            [alert runModal];
        });
    }];
}

#pragma mark - Helper Methods

- (void)updateAPIStatus:(NSString *)status color:(NSColor *)color {
    if (self.apiStatusValueField) {
        self.apiStatusValueField.stringValue = status;
        self.apiStatusValueField.textColor = color;
    }
}

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

- (YahooScreenerPreset)convertScreenerTypeToPreset {
    switch (self.screenerType) {
        case YahooScreenerTypeMostActive: return YahooScreenerPresetMostActive;
        case YahooScreenerTypeGainers: return YahooScreenerPresetGainers;
        case YahooScreenerTypeLosers: return YahooScreenerPresetLosers;
        case YahooScreenerTypeCustom: return YahooScreenerPresetCustom;
        default: return YahooScreenerPresetMostActive;
    }
}

- (NSNumber *)getMinVolumeFilter {
    NSString *text = self.minVolumeField.stringValue;
    if (text.length > 0) {
        double value = [text doubleValue];
        return value > 0 ? @(value) : nil;
    }
    return nil;
}

- (NSNumber *)getMinMarketCapFilter {
    NSString *text = self.minMarketCapField.stringValue;
    if (text.length > 0) {
        double value = [text doubleValue];
        return value > 0 ? @(value) : nil;
    }
    return nil;
}

- (NSString *)getSectorFilter {
    NSString *selectedSector = self.sectorPopup.titleOfSelectedItem;
    if (![selectedSector isEqualToString:@"All Sectors"]) {
        return selectedSector;
    }
    return nil;
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
    
    // Enhanced CSV header with all metrics
    [csvContent appendString:@"Symbol,Name,Price,Change %,Volume,Market Cap,P/E,PEG,P/B,Div %,Beta,Sector\n"];
    
    // Data rows with enhanced metrics
    for (YahooScreenerResult *result in self.currentResults) {
        NSString *marketCapFormatted = [self formatMarketCap:result.marketCap];
        NSString *volumeFormatted = [self formatNumber:result.volume];
        
        [csvContent appendFormat:@"%@,\"%@\",%.2f,%.2f,%@,%@,%.2f,%.2f,%.2f,%.2f,%.2f,\"%@\"\n",
         result.symbol,
         result.name,
         result.price.doubleValue,
         result.changePercent.doubleValue,
         volumeFormatted,
         marketCapFormatted,
         result.trailingPE.doubleValue,
         result.pegRatio.doubleValue,
         result.priceToBook.doubleValue,
         result.dividendYield.doubleValue,
         result.beta.doubleValue,
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
            alert.informativeText = [NSString stringWithFormat:@"Exported %lu results with enhanced metrics to %@",
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
    if (!changePercent || [changePercent isEqual:[NSNull null]]) {
        return @"N/A";
    }
    
    double value = changePercent.doubleValue;
    NSString *sign = value >= 0 ? @"+" : @"";
    return [NSString stringWithFormat:@"%@%.2f%%", sign, value];
}

- (NSString *)formatFinancialRatio:(NSNumber *)ratio {
    if (!ratio || [ratio isEqual:[NSNull null]]) {
        return @"N/A";
    }
    
    double value = ratio.doubleValue;
    if (value == 0) {
        return @"N/A";
    }
    
    return [NSString stringWithFormat:@"%.2f", value];
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
        if (result.price && ![result.price isEqual:[NSNull null]]) {
            return [NSString stringWithFormat:@"$%.2f", result.price.doubleValue];
        }
        return @"N/A";
    } else if ([identifier isEqualToString:@"changePercent"]) {
        if (result.changePercent && ![result.changePercent isEqual:[NSNull null]]) {
            return [self formatChangePercent:result.changePercent];
        }
        return @"N/A";
    } else if ([identifier isEqualToString:@"volume"]) {
        if (result.volume && ![result.volume isEqual:[NSNull null]]) {
            return [self formatNumber:result.volume];
        }
        return @"N/A";
    } else if ([identifier isEqualToString:@"marketCap"]) {
        if (result.marketCap && ![result.marketCap isEqual:[NSNull null]]) {
            return [self formatMarketCap:result.marketCap];
        }
        return @"N/A";
    } else if ([identifier isEqualToString:@"trailingPE"]) {
        return [self formatFinancialRatio:result.trailingPE];
    } else if ([identifier isEqualToString:@"pegRatio"]) {
        return [self formatFinancialRatio:result.pegRatio];
    } else if ([identifier isEqualToString:@"priceToBook"]) {
        return [self formatFinancialRatio:result.priceToBook];
    } else if ([identifier isEqualToString:@"dividendYield"]) {
        if (result.dividendYield && ![result.dividendYield isEqual:[NSNull null]]) {
            double yield = result.dividendYield.doubleValue;
            return yield > 0 ? [NSString stringWithFormat:@"%.2f%%", yield] : @"N/A";
        }
        return @"N/A";
    } else if ([identifier isEqualToString:@"beta"]) {
        return [self formatFinancialRatio:result.beta];
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
    NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
    
    // Color-code change percentage
    if ([identifier isEqualToString:@"changePercent"]) {
        double changePercent = result.changePercent.doubleValue;
        
        if (changePercent > 0) {
            textCell.textColor = [NSColor systemGreenColor];
        } else if (changePercent < 0) {
            textCell.textColor = [NSColor systemRedColor];
        } else {
            textCell.textColor = [NSColor labelColor];
        }
    }
    // Color-code financial ratios for better readability
    else if ([identifier isEqualToString:@"trailingPE"]) {
        if (result.trailingPE && ![result.trailingPE isEqual:[NSNull null]]) {
            double pe = result.trailingPE.doubleValue;
            if (pe > 0 && pe < 15) {
                textCell.textColor = [NSColor systemGreenColor];
            } else if (pe > 30) {
                textCell.textColor = [NSColor systemOrangeColor];
            } else {
                textCell.textColor = [NSColor labelColor];
            }
        } else {
            textCell.textColor = [NSColor labelColor];
        }
    }
    // Color-code dividend yield
    else if ([identifier isEqualToString:@"dividendYield"]) {
        if (result.dividendYield && ![result.dividendYield isEqual:[NSNull null]]) {
            double yield = result.dividendYield.doubleValue;
            if (yield > 4.0) {
                textCell.textColor = [NSColor systemGreenColor];
            } else {
                textCell.textColor = [NSColor labelColor];
            }
        } else {
            textCell.textColor = [NSColor labelColor];
        }
    }
    else {
        // Reset to default color for other columns
        textCell.textColor = [NSColor labelColor];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.resultsTable.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.currentResults.count) {
        YahooScreenerResult *result = self.currentResults[selectedRow];
        NSLog(@"📊 ScreenerWidget: Selected %@ - %@ (P/E: %.2f, PEG: %.2f)",
              result.symbol, result.name, result.trailingPE.doubleValue, result.pegRatio.doubleValue);
        
        // Future enhancement: Could trigger chart widget or add to watchlist
    }
}

#pragma mark - Public API Implementation

- (void)setFilter:(NSString *)key withValue:(id)value {
    AdvancedScreenerFilter *filter = [AdvancedScreenerFilter filterWithKey:key
                                                                displayName:key
                                                                       type:AdvancedFilterTypeNumber];
    filter.value = value;
    filter.isActive = YES;
    self.activeFilters[key] = filter;
    
    NSLog(@"🔧 ScreenerWidget: Set filter %@ = %@", key, value);
}

- (void)removeFilter:(NSString *)key {
    [self.activeFilters removeObjectForKey:key];
    NSLog(@"🗑️ ScreenerWidget: Removed filter %@", key);
}

- (void)saveFilterPreset:(NSString *)presetName {
    // Future implementation: Save current filter configuration
    NSLog(@"💾 ScreenerWidget: Save preset '%@' (not implemented yet)", presetName);
}

- (void)loadFilterPreset:(NSString *)presetName {
    // Future implementation: Load saved filter configuration
    NSLog(@"📂 ScreenerWidget: Load preset '%@' (not implemented yet)", presetName);
}

#pragma mark - State Persistence

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    
    state[@"maxResults"] = @(self.maxResults);
    state[@"autoRefresh"] = @(self.autoRefresh);
    state[@"screenerType"] = @(self.screenerType);
    state[@"selectedPreset"] = self.selectedPreset ?: @"";
    
    // Save basic filter values
    state[@"minVolume"] = self.minVolumeField.stringValue ?: @"";
    state[@"minMarketCap"] = self.minMarketCapField.stringValue ?: @"";
    state[@"selectedSector"] = self.sectorPopup.titleOfSelectedItem ?: @"All Sectors";
    
    // Save advanced filter values
    NSMutableDictionary *advancedFilters = [NSMutableDictionary dictionary];
    
    // BASIC FINANCIAL RATIOS
    advancedFilters[@"peRatioMin"] = self.peRatioMinField.stringValue ?: @"";
    advancedFilters[@"peRatioMax"] = self.peRatioMaxField.stringValue ?: @"";
    advancedFilters[@"forwardPEMin"] = self.forwardPEMinField.stringValue ?: @"";
    advancedFilters[@"forwardPEMax"] = self.forwardPEMaxField.stringValue ?: @"";
    advancedFilters[@"pegRatioMin"] = self.pegRatioMinField.stringValue ?: @"";
    advancedFilters[@"pegRatioMax"] = self.pegRatioMaxField.stringValue ?: @"";
    advancedFilters[@"priceToBookMin"] = self.priceToBookMinField.stringValue ?: @"";
    advancedFilters[@"priceToBookMax"] = self.priceToBookMaxField.stringValue ?: @"";
    advancedFilters[@"betaMin"] = self.betaMinField.stringValue ?: @"";
    advancedFilters[@"betaMax"] = self.betaMaxField.stringValue ?: @"";
    
    // EARNINGS & DIVIDENDS
    advancedFilters[@"epsTrailingTwelveMonthsMin"] = self.epsTrailingTwelveMonthsMinField.stringValue ?: @"";
    advancedFilters[@"epsTrailingTwelveMonthsMax"] = self.epsTrailingTwelveMonthsMaxField.stringValue ?: @"";
    advancedFilters[@"epsForwardMin"] = self.epsForwardMinField.stringValue ?: @"";
    advancedFilters[@"epsForwardMax"] = self.epsForwardMaxField.stringValue ?: @"";
    advancedFilters[@"dividendYieldMin"] = self.dividendYieldMinField.stringValue ?: @"";
    advancedFilters[@"dividendYieldMax"] = self.dividendYieldMaxField.stringValue ?: @"";
    advancedFilters[@"trailingAnnualDividendYieldMin"] = self.trailingAnnualDividendYieldMinField.stringValue ?: @"";
    advancedFilters[@"trailingAnnualDividendYieldMax"] = self.trailingAnnualDividendYieldMaxField.stringValue ?: @"";
    advancedFilters[@"dividendRateMin"] = self.dividendRateMinField.stringValue ?: @"";
    advancedFilters[@"dividendRateMax"] = self.dividendRateMaxField.stringValue ?: @"";
    
    // PRICE & VOLUME
    advancedFilters[@"priceMin"] = self.priceMinField.stringValue ?: @"";
    advancedFilters[@"priceMax"] = self.priceMaxField.stringValue ?: @"";
    advancedFilters[@"intradayMarketCapMin"] = self.intradayMarketCapMinField.stringValue ?: @"";
    advancedFilters[@"intradayMarketCapMax"] = self.intradayMarketCapMaxField.stringValue ?: @"";
    advancedFilters[@"dayVolumeMin"] = self.dayVolumeMinField.stringValue ?: @"";
    advancedFilters[@"dayVolumeMax"] = self.dayVolumeMaxField.stringValue ?: @"";
    advancedFilters[@"averageDailyVolume3MonthMin"] = self.averageDailyVolume3MonthMinField.stringValue ?: @"";
    advancedFilters[@"averageDailyVolume3MonthMax"] = self.averageDailyVolume3MonthMaxField.stringValue ?: @"";
    
    // PERFORMANCE
    advancedFilters[@"oneDayPercentChangeMin"] = self.oneDayPercentChangeMinField.stringValue ?: @"";
    advancedFilters[@"oneDayPercentChangeMax"] = self.oneDayPercentChangeMaxField.stringValue ?: @"";
    advancedFilters[@"fiveDayPercentChangeMin"] = self.fiveDayPercentChangeMinField.stringValue ?: @"";
    advancedFilters[@"fiveDayPercentChangeMax"] = self.fiveDayPercentChangeMaxField.stringValue ?: @"";
    advancedFilters[@"oneMonthPercentChangeMin"] = self.oneMonthPercentChangeMinField.stringValue ?: @"";
    advancedFilters[@"oneMonthPercentChangeMax"] = self.oneMonthPercentChangeMaxField.stringValue ?: @"";
    advancedFilters[@"threeMonthPercentChangeMin"] = self.threeMonthPercentChangeMinField.stringValue ?: @"";
    advancedFilters[@"threeMonthPercentChangeMax"] = self.threeMonthPercentChangeMaxField.stringValue ?: @"";
    advancedFilters[@"sixMonthPercentChangeMin"] = self.sixMonthPercentChangeMinField.stringValue ?: @"";
    advancedFilters[@"sixMonthPercentChangeMax"] = self.sixMonthPercentChangeMaxField.stringValue ?: @"";
    advancedFilters[@"fiftyTwoWeekPercentChangeMin"] = self.fiftyTwoWeekPercentChangeMinField.stringValue ?: @"";
    advancedFilters[@"fiftyTwoWeekPercentChangeMax"] = self.fiftyTwoWeekPercentChangeMaxField.stringValue ?: @"";
    
    // CATEGORY FILTERS
    advancedFilters[@"secType"] = self.secTypePopup.titleOfSelectedItem ?: @"All Types";
    advancedFilters[@"exchange"] = self.exchangePopup.titleOfSelectedItem ?: @"All Exchanges";
    advancedFilters[@"industry"] = self.industryPopup.titleOfSelectedItem ?: @"All Industries";
    advancedFilters[@"peerGroup"] = self.peerGroupPopup.titleOfSelectedItem ?: @"All Groups";
    
    state[@"advancedFilters"] = advancedFilters;
    
    return [state copy];
}


- (void)restoreState:(NSDictionary *)state {
    self.maxResults = [state[@"maxResults"] integerValue] ?: 100;
    self.autoRefresh = [state[@"autoRefresh"] boolValue];
    self.screenerType = (YahooScreenerType)[state[@"screenerType"] integerValue];
    self.selectedPreset = state[@"selectedPreset"];
    
    // Restore basic filter values
    self.minVolumeField.stringValue = state[@"minVolume"] ?: @"";
    self.minMarketCapField.stringValue = state[@"minMarketCap"] ?: @"";
    
    NSString *selectedSector = state[@"selectedSector"] ?: @"All Sectors";
    [self.sectorPopup selectItemWithTitle:selectedSector];
    
    // Restore advanced filter values
    NSDictionary *advancedFilters = state[@"advancedFilters"];
    if (advancedFilters) {
        // BASIC FINANCIAL RATIOS
        self.peRatioMinField.stringValue = advancedFilters[@"peRatioMin"] ?: @"";
        self.peRatioMaxField.stringValue = advancedFilters[@"peRatioMax"] ?: @"";
        self.forwardPEMinField.stringValue = advancedFilters[@"forwardPEMin"] ?: @"";
        self.forwardPEMaxField.stringValue = advancedFilters[@"forwardPEMax"] ?: @"";
        self.pegRatioMinField.stringValue = advancedFilters[@"pegRatioMin"] ?: @"";
        self.pegRatioMaxField.stringValue = advancedFilters[@"pegRatioMax"] ?: @"";
        self.priceToBookMinField.stringValue = advancedFilters[@"priceToBookMin"] ?: @"";
        self.priceToBookMaxField.stringValue = advancedFilters[@"priceToBookMax"] ?: @"";
        self.betaMinField.stringValue = advancedFilters[@"betaMin"] ?: @"";
        self.betaMaxField.stringValue = advancedFilters[@"betaMax"] ?: @"";
        
        // EARNINGS & DIVIDENDS
        self.epsTrailingTwelveMonthsMinField.stringValue = advancedFilters[@"epsTrailingTwelveMonthsMin"] ?: @"";
        self.epsTrailingTwelveMonthsMaxField.stringValue = advancedFilters[@"epsTrailingTwelveMonthsMax"] ?: @"";
        self.epsForwardMinField.stringValue = advancedFilters[@"epsForwardMin"] ?: @"";
        self.epsForwardMaxField.stringValue = advancedFilters[@"epsForwardMax"] ?: @"";
        self.dividendYieldMinField.stringValue = advancedFilters[@"dividendYieldMin"] ?: @"";
        self.dividendYieldMaxField.stringValue = advancedFilters[@"dividendYieldMax"] ?: @"";
        self.trailingAnnualDividendYieldMinField.stringValue = advancedFilters[@"trailingAnnualDividendYieldMin"] ?: @"";
        self.trailingAnnualDividendYieldMaxField.stringValue = advancedFilters[@"trailingAnnualDividendYieldMax"] ?: @"";
        self.dividendRateMinField.stringValue = advancedFilters[@"dividendRateMin"] ?: @"";
        self.dividendRateMaxField.stringValue = advancedFilters[@"dividendRateMax"] ?: @"";
        
        // PRICE & VOLUME
        self.priceMinField.stringValue = advancedFilters[@"priceMin"] ?: @"";
        self.priceMaxField.stringValue = advancedFilters[@"priceMax"] ?: @"";
        self.intradayMarketCapMinField.stringValue = advancedFilters[@"intradayMarketCapMin"] ?: @"";
        self.intradayMarketCapMaxField.stringValue = advancedFilters[@"intradayMarketCapMax"] ?: @"";
        self.dayVolumeMinField.stringValue = advancedFilters[@"dayVolumeMin"] ?: @"";
        self.dayVolumeMaxField.stringValue = advancedFilters[@"dayVolumeMax"] ?: @"";
        self.averageDailyVolume3MonthMinField.stringValue = advancedFilters[@"averageDailyVolume3MonthMin"] ?: @"";
        self.averageDailyVolume3MonthMaxField.stringValue = advancedFilters[@"averageDailyVolume3MonthMax"] ?: @"";
        
        // PERFORMANCE
        self.oneDayPercentChangeMinField.stringValue = advancedFilters[@"oneDayPercentChangeMin"] ?: @"";
        self.oneDayPercentChangeMaxField.stringValue = advancedFilters[@"oneDayPercentChangeMax"] ?: @"";
        self.fiveDayPercentChangeMinField.stringValue = advancedFilters[@"fiveDayPercentChangeMin"] ?: @"";
        self.fiveDayPercentChangeMaxField.stringValue = advancedFilters[@"fiveDayPercentChangeMax"] ?: @"";
        self.oneMonthPercentChangeMinField.stringValue = advancedFilters[@"oneMonthPercentChangeMin"] ?: @"";
        self.oneMonthPercentChangeMaxField.stringValue = advancedFilters[@"oneMonthPercentChangeMax"] ?: @"";
        self.threeMonthPercentChangeMinField.stringValue = advancedFilters[@"threeMonthPercentChangeMin"] ?: @"";
        self.threeMonthPercentChangeMaxField.stringValue = advancedFilters[@"threeMonthPercentChangeMax"] ?: @"";
        self.sixMonthPercentChangeMinField.stringValue = advancedFilters[@"sixMonthPercentChangeMin"] ?: @"";
        self.sixMonthPercentChangeMaxField.stringValue = advancedFilters[@"sixMonthPercentChangeMax"] ?: @"";
        self.fiftyTwoWeekPercentChangeMinField.stringValue = advancedFilters[@"fiftyTwoWeekPercentChangeMin"] ?: @"";
        self.fiftyTwoWeekPercentChangeMaxField.stringValue = advancedFilters[@"fiftyTwoWeekPercentChangeMax"] ?: @"";
        
        // CATEGORY FILTERS
        [self.secTypePopup selectItemWithTitle:advancedFilters[@"secType"] ?: @"All Types"];
        [self.exchangePopup selectItemWithTitle:advancedFilters[@"exchange"] ?: @"All Exchanges"];
        [self.industryPopup selectItemWithTitle:advancedFilters[@"industry"] ?: @"All Industries"];
        [self.peerGroupPopup selectItemWithTitle:advancedFilters[@"peerGroup"] ?: @"All Groups"];
    }
    
    // Update UI controls
    self.maxResultsField.stringValue = [@(self.maxResults) stringValue];
    self.autoRefreshCheckbox.state = self.autoRefresh ? NSControlStateValueOn : NSControlStateValueOff;
    [self.screenerTypePopup selectItemAtIndex:self.screenerType];
    
    [self updateAutoRefreshTimer];
    
    NSLog(@"🔄 ScreenerWidget: Restored state with %lu active filters", (unsigned long)self.activeFilters.count);
}


@end
