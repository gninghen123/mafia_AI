//
//  NewsWidget.m
//  TradingApp
//
//  Enhanced News Widget V2 - Clean Implementation
//

#import "NewsWidget.h"
#import "NewsPreferencesWindowController.h"
#import "DataHub.h"
#import "DataHub+News.h"
#import "DataHub+MarketData.h"
#import "CommonTypes.h"

// UserDefaults Keys
static NSString *const kNewsWidgetEnabledSources = @"NewsWidget_EnabledSources";
static NSString *const kNewsWidgetColorKeywords = @"NewsWidget_ColorKeywords";
static NSString *const kNewsWidgetExcludeKeywords = @"NewsWidget_ExcludeKeywords";
static NSString *const kNewsWidgetNewsLimit = @"NewsWidget_NewsLimit";
static NSString *const kNewsWidgetAutoRefresh = @"NewsWidget_AutoRefresh";
static NSString *const kNewsWidgetRefreshInterval = @"NewsWidget_RefreshInterval";

// Default Colors (Hex Strings)
static NSString *const kDefaultYellowColor = @"FFEB3B";
static NSString *const kDefaultPinkColor = @"E91E63";
static NSString *const kDefaultBlueColor = @"2196F3";
static NSString *const kDefaultGreenColor = @"4CAF50";
static NSString *const kDefaultRedColor = @"F44336";

@interface NewsWidget ()
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *symbolVariations;
@end

@implementation NewsWidget

#pragma mark - BaseWidget Overrides

- (void)updateContentForType:(NSString *)newType {
    // NewsWidget doesn't change based on type
}

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    state[@"currentSymbols"] = self.currentSymbols ?: @[];
    state[@"searchInput"] = self.searchField.stringValue ?: @"";
    
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    NSArray *savedSymbols = state[@"currentSymbols"];
    if (savedSymbols && savedSymbols.count > 0) {
        self.currentSymbols = savedSymbols;
        self.searchField.stringValue = [savedSymbols componentsJoinedByString:@","];
    }
    
    NSString *savedSearchInput = state[@"searchInput"];
    if (savedSearchInput && savedSearchInput.length > 0) {
        self.searchField.stringValue = savedSearchInput;
    }
    
    if (self.currentSymbols.count > 0) {
        [self loadNewsForSymbols:self.currentSymbols];
    }
}

#pragma mark - Chain Integration

- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"📰 NewsWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
    
    if (symbols.count == 0) return;
    
    self.searchField.stringValue = [symbols componentsJoinedByString:@","];
    [self searchForInput:self.searchField.stringValue];
    
    NSString *senderType = NSStringFromClass([sender class]);
    [self showChainFeedback:[NSString stringWithFormat:@"📰 Loading news for %lu symbols from %@",
                           (unsigned long)symbols.count, senderType]];
}

- (void)sendCurrentSymbolsToChain {
    if (self.currentSymbols.count > 0) {
        [self sendSymbolsToChain:self.currentSymbols];
    }
}

#pragma mark - Utility Methods

- (NSArray<NewsModel *> *)removeDuplicateNews:(NSArray<NewsModel *> *)news {
    NSMutableArray<NewsModel *> *uniqueNews = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIdentifiers = [NSMutableSet set];
    
    for (NewsModel *newsItem in news) {
        NSString *identifier;
        if (newsItem.url && newsItem.url.length > 0) {
            identifier = newsItem.url;
        } else {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateFormat = @"yyyy-MM-dd";
            NSString *dateString = [dateFormatter stringFromDate:newsItem.publishedDate];
            identifier = [NSString stringWithFormat:@"%@_%@_%@",
                         newsItem.headline ?: @"",
                         newsItem.symbol ?: @"",
                         dateString];
        }
        
        if (![seenIdentifiers containsObject:identifier]) {
            [seenIdentifiers addObject:identifier];
            [uniqueNews addObject:newsItem];
        }
    }
    
    return [uniqueNews copy];
}

- (void)showLoadingState:(BOOL)loading {
    if (loading) {
        self.progressIndicator.hidden = NO;
        [self.progressIndicator startAnimation:nil];
        self.refreshButton.enabled = NO;
    } else {
        self.progressIndicator.hidden = YES;
        [self.progressIndicator stopAnimation:nil];
        self.refreshButton.enabled = YES;
    }
    
    self.isLoading = loading;
}

- (void)updateStatus:(NSString *)status {
    self.statusLabel.stringValue = status ?: @"";
}

#pragma mark - Color Helper Methods

- (NSColor *)colorFromHexString:(NSString *)hexString {
    if (!hexString || hexString.length != 6) return nil;
    
    unsigned int hexValue;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if (![scanner scanHexInt:&hexValue]) return nil;
    
    CGFloat red = ((hexValue & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((hexValue & 0x00FF00) >> 8) / 255.0;
    CGFloat blue = (hexValue & 0x0000FF) / 255.0;
    
    return [NSColor colorWithRed:red green:green blue:blue alpha:1.0];
}

- (NSString *)hexStringFromColor:(NSColor *)color {
    NSColor *rgbColor = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (!rgbColor) return @"000000";
    
    int red = (int)(rgbColor.redComponent * 255);
    int green = (int)(rgbColor.greenComponent * 255);
    int blue = (int)(rgbColor.blueComponent * 255);
    
    return [NSString stringWithFormat:@"%02X%02X%02X", red, green, blue];
}

#pragma mark - Lifecycle

- (void)setupContentView {
    [super setupContentView];
    
    // Initialize date formatter
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateStyle = NSDateFormatterShortStyle;
    
    // Load preferences first
    [self loadPreferences];
    
    // Initialize data arrays
    self.allNews = @[];
    self.filteredNews = @[];
    self.currentSymbols = @[];
    self.symbolVariations = [NSMutableDictionary dictionary];
    
    [self createNewsUI];
    [self setupTableView];
    [self startAutoRefreshIfEnabled];
    
    NSLog(@"📰 NewsWidget V2: Initialized with %lu enabled sources",
          (unsigned long)self.enabledNewsSources.count);
}

- (void)dealloc {
    [self stopAutoRefresh];
}

#pragma mark - UI Creation

- (void)createNewsUI {
    // Search Field
    self.searchField = [[NSTextField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = @"Enter symbols (AAPL,MSFT) or keywords";
    self.searchField.target = self;
    self.searchField.action = @selector(searchFieldChanged:);
    [self.contentView addSubview:self.searchField];
    
    // Refresh Button
    self.refreshButton = [NSButton buttonWithTitle:@"🔄" target:self action:@selector(refreshNews:)];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.refreshButton.bezelStyle = NSBezelStyleTexturedRounded;
    [self.contentView addSubview:self.refreshButton];
    
    // Preferences Button
    self.preferencesButton = [NSButton buttonWithTitle:@"⚙️" target:self action:@selector(showPreferences:)];
    self.preferencesButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.preferencesButton.bezelStyle = NSBezelStyleTexturedRounded;
    [self.contentView addSubview:self.preferencesButton];
    
    // Clear Filters Button
    self.clearFiltersButton = [NSButton buttonWithTitle:@"Clear Filters" target:self action:@selector(clearAllFilters:)];
    self.clearFiltersButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.clearFiltersButton.bezelStyle = NSBezelStyleTexturedRounded;
    [self.contentView addSubview:self.clearFiltersButton];
    
    // Status Label
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.stringValue = @"Enter symbols or keywords to search news";
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [self.contentView addSubview:self.statusLabel];
    
    // Progress Indicator
    self.progressIndicator = [[NSProgressIndicator alloc] init];
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
    self.progressIndicator.hidden = YES;
    [self.contentView addSubview:self.progressIndicator];
    
    // Create table view
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.headerView = [[NSTableHeaderView alloc] init];
    
    // Create scroll view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.tableView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    [self.contentView addSubview:self.scrollView];
    
    [self setupConstraints];
}

- (void)setupTableView {
    // Date Column
    NSTableColumn *dateColumn = [[NSTableColumn alloc] initWithIdentifier:@"date"];
    dateColumn.title = @"Date";
    dateColumn.width = 100;
    dateColumn.minWidth = 80;
    [self.tableView addTableColumn:dateColumn];
    
    // Symbol Column
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    [self.tableView addTableColumn:symbolColumn];
    
    // Title Column
    NSTableColumn *titleColumn = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    titleColumn.title = @"Title";
    titleColumn.width = 400;
    titleColumn.minWidth = 200;
    [self.tableView addTableColumn:titleColumn];
    
    // Color Indicators Column
    NSTableColumn *colorColumn = [[NSTableColumn alloc] initWithIdentifier:@"colors"];
    colorColumn.title = @"Type";
    colorColumn.width = 80;
    colorColumn.minWidth = 60;
    [self.tableView addTableColumn:colorColumn];
    
    // Source Column
    NSTableColumn *sourceColumn = [[NSTableColumn alloc] initWithIdentifier:@"source"];
    sourceColumn.title = @"Source";
    sourceColumn.width = 100;
    sourceColumn.minWidth = 80;
    [self.tableView addTableColumn:sourceColumn];
    
    // Variation % Column
    NSTableColumn *variationColumn = [[NSTableColumn alloc] initWithIdentifier:@"variation"];
    variationColumn.title = @"Var %";
    variationColumn.width = 80;
    variationColumn.minWidth = 60;
    [self.tableView addTableColumn:variationColumn];
    
    // Priority/Strength Column
    NSTableColumn *priorityColumn = [[NSTableColumn alloc] initWithIdentifier:@"priority"];
    priorityColumn.title = @"Strength";
    priorityColumn.width = 80;
    priorityColumn.minWidth = 60;
    [self.tableView addTableColumn:priorityColumn];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Search panel constraints
        [self.searchField.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.searchField.trailingAnchor constraintEqualToAnchor:self.refreshButton.leadingAnchor constant:-8],
        
        [self.refreshButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.refreshButton.widthAnchor constraintEqualToConstant:40],
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.preferencesButton.leadingAnchor constant:-4],
        
        [self.preferencesButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.preferencesButton.widthAnchor constraintEqualToConstant:40],
        [self.preferencesButton.trailingAnchor constraintEqualToAnchor:self.clearFiltersButton.leadingAnchor constant:-4],
        
        [self.clearFiltersButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.clearFiltersButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        
        // Status and progress constraints
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.searchField.bottomAnchor constant:8],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        
        [self.progressIndicator.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor],
        [self.progressIndicator.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        
        // Table view constraints
        [self.scrollView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:8],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
    ]];
}

#pragma mark - Search and Loading

- (IBAction)searchFieldChanged:(id)sender {
    NSString *searchInput = [self.searchField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self searchForInput:searchInput];
}

- (IBAction)refreshNews:(id)sender {
    if (self.currentSymbols.count > 0) {
        [self searchForInput:[self.currentSymbols componentsJoinedByString:@","]];
    }
}

- (IBAction)showPreferences:(id)sender {
    [self showPreferences];
}

- (IBAction)clearAllFilters:(id)sender {
    [self clearAllFilters];
}

- (void)searchForInput:(NSString *)searchInput {
    if (!searchInput || searchInput.length == 0) {
        [self updateStatus:@"Enter symbols or keywords to search"];
        self.allNews = @[];
        self.filteredNews = @[];
        [self.tableView reloadData];
        return;
    }
    
    // Parse input - could be symbols separated by commas
    NSArray<NSString *> *inputComponents = [self parseSearchInput:searchInput];
    
    // For now, treat all input as symbols
    self.currentSymbols = inputComponents;
    [self loadNewsForSymbols:inputComponents];
}

- (NSArray<NSString *> *)parseSearchInput:(NSString *)input {
    NSArray<NSString *> *components = [input componentsSeparatedByString:@","];
    NSMutableArray<NSString *> *cleanComponents = [NSMutableArray array];
    
    for (NSString *component in components) {
        NSString *cleaned = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].uppercaseString;
        if (cleaned.length > 0) {
            [cleanComponents addObject:cleaned];
        }
    }
    
    return [cleanComponents copy];
}

- (void)loadNewsForSymbols:(NSArray<NSString *> *)symbols {
    self.isLoading = YES;
    [self showLoadingState:YES];
    [self updateStatus:[NSString stringWithFormat:@"Loading news for %lu symbols...", (unsigned long)symbols.count]];
    
    NSMutableArray<NewsModel *> *allNewsResults = [NSMutableArray array];
    __block NSInteger remainingRequests = symbols.count;
    
    DataHub *dataHub = [DataHub shared];
    
    for (NSString *symbol in symbols) {
        NSArray<NSNumber *> *enabledSources = [self getEnabledNewsSourceTypes];
        
        [dataHub getAggregatedNewsForSymbol:symbol
                                fromSources:enabledSources
                                 completion:^(NSArray<NewsModel *> *news, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                remainingRequests--;
                
                if (news && !error) {
                    [allNewsResults addObjectsFromArray:news];
                }
                
                if (remainingRequests == 0) {
                    [self handleMultiSymbolNewsResponse:allNewsResults];
                }
                
                CGFloat progress = 1.0 - ((CGFloat)remainingRequests / symbols.count);
                [self updateStatus:[NSString stringWithFormat:@"Loading... %.0f%%", progress * 100]];
            });
        }];
    }
}

- (void)handleMultiSymbolNewsResponse:(NSArray<NewsModel *> *)allNews {
    NSArray<NewsModel *> *uniqueNews = [self removeDuplicateNews:allNews];
    NSArray<NewsModel *> *sortedNews = [uniqueNews sortedArrayUsingComparator:^NSComparisonResult(NewsModel *obj1, NewsModel *obj2) {
        return [obj2.publishedDate compare:obj1.publishedDate];
    }];
    
    NSInteger limit = self.newsLimit > 0 ? self.newsLimit : 50;
    if (sortedNews.count > limit) {
        sortedNews = [sortedNews subarrayWithRange:NSMakeRange(0, limit)];
    }
    
    self.allNews = sortedNews;
    [self applyFilters];
    [self showLoadingState:NO];
    [self updateStatus:[NSString stringWithFormat:@"Loaded %lu news items", (unsigned long)self.filteredNews.count]];
}

#pragma mark - Filtering

- (void)applyFilters {
    NSMutableArray<NewsModel *> *filtered = [NSMutableArray arrayWithArray:self.allNews];
    
    // Apply exclusion keywords filter
    if (self.excludeKeywords.count > 0) {
        [filtered filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NewsModel *news, NSDictionary *bindings) {
            return ![self newsItem:news containsAnyExcludedKeywords:self.excludeKeywords];
        }]];
    }
    
    self.filteredNews = [filtered copy];
    [self.tableView reloadData];
}

- (void)clearAllFilters {
    self.filterDateFrom = nil;
    self.filterDateTo = nil;
    [self applyFilters];
}

#pragma mark - Color System

- (NSColor *)colorForNewsItem:(NewsModel *)newsItem {
    NSArray<NSColor *> *colors = [self allColorsForNewsItem:newsItem];
    return colors.firstObject;
}

- (NSArray<NSColor *> *)allColorsForNewsItem:(NewsModel *)newsItem {
    NSMutableArray<NSColor *> *matchingColors = [NSMutableArray array];
    
    for (NSString *colorHex in self.colorKeywordMapping.allKeys) {
        NSString *keywords = self.colorKeywordMapping[colorHex];
        if ([self newsItem:newsItem matchesKeywords:keywords]) {
            NSColor *color = [self colorFromHexString:colorHex];
            if (color) {
                [matchingColors addObject:color];
            }
        }
    }
    
    return [matchingColors copy];
}

- (BOOL)newsItem:(NewsModel *)newsItem matchesKeywords:(NSString *)keywords {
    if (!keywords || keywords.length == 0) return NO;
    
    NSArray<NSString *> *keywordList = [keywords componentsSeparatedByString:@","];
    NSString *searchText = [NSString stringWithFormat:@"%@ %@",
                           newsItem.headline ?: @"",
                           newsItem.summary ?: @""].lowercaseString;
    
    for (NSString *keyword in keywordList) {
        NSString *trimmedKeyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
        if (trimmedKeyword.length > 0 && [searchText containsString:trimmedKeyword]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)newsItem:(NewsModel *)newsItem containsAnyExcludedKeywords:(NSArray<NSString *> *)excludedKeywords {
    NSString *searchText = [NSString stringWithFormat:@"%@ %@",
                           newsItem.headline ?: @"",
                           newsItem.summary ?: @""].lowercaseString;
    
    for (NSString *excludedKeyword in excludedKeywords) {
        NSString *trimmedKeyword = [excludedKeyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
        if (trimmedKeyword.length > 0 && [searchText containsString:trimmedKeyword]) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredNews.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredNews.count) return nil;
    
    NewsModel *newsItem = self.filteredNews[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"date"]) {
        return [self.dateFormatter stringFromDate:newsItem.publishedDate];
    } else if ([identifier isEqualToString:@"symbol"]) {
        return newsItem.symbol ?: @"";
    } else if ([identifier isEqualToString:@"title"]) {
        return newsItem.headline ?: @"";
    } else if ([identifier isEqualToString:@"source"]) {
        return newsItem.source ?: @"";
    } else if ([identifier isEqualToString:@"variation"]) {
        NSNumber *variation = self.symbolVariations[newsItem.symbol.uppercaseString];
        if (variation) {
            return [NSString stringWithFormat:@"%.2f%%", variation.doubleValue];
        }
        return @"--";
    } else if ([identifier isEqualToString:@"priority"]) {
        NSInteger priority = newsItem.priority > 0 ? newsItem.priority : 3;
        NSMutableString *stars = [NSMutableString string];
        for (NSInteger i = 0; i < priority && i < 5; i++) {
            [stars appendString:@"⭐"];
        }
        return stars;
    }
    
    return @"";
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredNews.count) return nil;
    
    NewsModel *newsItem = self.filteredNews[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"colors"]) {
        return [self createColorIndicatorViewForNewsItem:newsItem];
    } else if ([identifier isEqualToString:@"variation"]) {
        return [self createVariationViewForNewsItem:newsItem];
    }
    
    // Default text field view
    NSTextField *textField = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!textField) {
        textField = [[NSTextField alloc] init];
        textField.identifier = identifier;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.editable = NO;
    }
    
    textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row] ?: @"";
    
    return textField;
}

- (NSView *)createColorIndicatorViewForNewsItem:(NewsModel *)newsItem {
    NSView *containerView = [[NSView alloc] init];
    containerView.identifier = @"colors";
    
    NSArray<NSColor *> *colors = [self allColorsForNewsItem:newsItem];
    
    if (colors.count == 0) return containerView;
    
    CGFloat squareSize = 12.0;
    CGFloat spacing = 2.0;
    
    for (NSInteger i = 0; i < colors.count && i < 3; i++) {
        NSView *colorSquare = [[NSView alloc] init];
        colorSquare.wantsLayer = YES;
        colorSquare.layer.backgroundColor = colors[i].CGColor;
        colorSquare.layer.cornerRadius = 2.0;
        colorSquare.translatesAutoresizingMaskIntoConstraints = NO;
        
        [containerView addSubview:colorSquare];
        
        [NSLayoutConstraint activateConstraints:@[
            [colorSquare.widthAnchor constraintEqualToConstant:squareSize],
            [colorSquare.heightAnchor constraintEqualToConstant:squareSize],
            [colorSquare.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
            [colorSquare.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:i * (squareSize + spacing)]
        ]];
    }
    
    return containerView;
}

- (NSView *)createVariationViewForNewsItem:(NewsModel *)newsItem {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.identifier = @"variation";
    textField.bordered = NO;
    textField.backgroundColor = [NSColor clearColor];
    textField.editable = NO;
    
    NSNumber *variation = self.symbolVariations[newsItem.symbol.uppercaseString];
    if (variation) {
        double value = variation.doubleValue;
        textField.stringValue = [NSString stringWithFormat:@"%.2f%%", value];
        
        if (value > 0) {
            textField.textColor = [NSColor systemGreenColor];
        } else if (value < 0) {
            textField.textColor = [NSColor systemRedColor];
        } else {
            textField.textColor = [NSColor labelColor];
        }
    } else {
        textField.stringValue = @"--";
        textField.textColor = [NSColor secondaryLabelColor];
    }
    
    return textField;
}

#pragma mark - Table View Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.filteredNews.count) {
        NewsModel *selectedNews = self.filteredNews[selectedRow];
        NSLog(@"📰 Selected news: %@ - %@", selectedNews.symbol, selectedNews.headline);
    }
}

- (void)tableView:(NSTableView *)tableView didDoubleClickOnRow:(NSInteger)row {
    if (row >= 0 && row < self.filteredNews.count) {
        NewsModel *newsItem = self.filteredNews[row];
        if (newsItem.url && newsItem.url.length > 0) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:newsItem.url]];
        }
    }
}

#pragma mark - Preferences Management

- (void)showPreferences {
    if (!self.preferencesController) {
        self.preferencesController = [[NewsPreferencesWindowController alloc] initWithNewsWidget:self];
    }
    
    [self.preferencesController.window makeKeyAndOrderFront:nil];
    [self.preferencesController refreshUI];
}

- (void)savePreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:self.enabledNewsSources forKey:kNewsWidgetEnabledSources];
    [defaults setObject:self.colorKeywordMapping forKey:kNewsWidgetColorKeywords];
    [defaults setObject:self.excludeKeywords forKey:kNewsWidgetExcludeKeywords];
    [defaults setInteger:self.newsLimit forKey:kNewsWidgetNewsLimit];
    [defaults setBool:self.autoRefresh forKey:kNewsWidgetAutoRefresh];
    [defaults setDouble:self.refreshInterval forKey:kNewsWidgetRefreshInterval];
    
    [defaults synchronize];
    
    NSLog(@"📰 NewsWidget: Preferences saved");
}

- (void)loadPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSDictionary *savedSources = [defaults objectForKey:kNewsWidgetEnabledSources];
    if (savedSources) {
        self.enabledNewsSources = [savedSources mutableCopy];
    } else {
        [self resetNewsSourcesPreferencesToDefaults];
    }
    
    NSDictionary *savedColors = [defaults objectForKey:kNewsWidgetColorKeywords];
    if (savedColors) {
        self.colorKeywordMapping = [savedColors mutableCopy];
    } else {
        [self resetColorMappingToDefaults];
    }
    
    NSArray *savedExcludeKeywords = [defaults objectForKey:kNewsWidgetExcludeKeywords];
    self.excludeKeywords = savedExcludeKeywords ?: @[];
    
    self.newsLimit = [defaults integerForKey:kNewsWidgetNewsLimit];
    if (self.newsLimit <= 0) self.newsLimit = 50;
    
    self.autoRefresh = [defaults objectForKey:kNewsWidgetAutoRefresh] ? [defaults boolForKey:kNewsWidgetAutoRefresh] : YES;
    
    self.refreshInterval = [defaults doubleForKey:kNewsWidgetRefreshInterval];
    if (self.refreshInterval <= 0) self.refreshInterval = 300;
    
    NSLog(@"📰 NewsWidget: Preferences loaded");
}

- (void)resetPreferencesToDefaults {
    [self resetNewsSourcesPreferencesToDefaults];
    [self resetColorMappingToDefaults];
    
    self.excludeKeywords = @[];
    self.newsLimit = 50;
    self.autoRefresh = YES;
    self.refreshInterval = 300;
    
    [self savePreferences];
}

- (void)resetNewsSourcesPreferencesToDefaults {
    self.enabledNewsSources = [NSMutableDictionary dictionary];
    
    NSArray<NSNumber *> *allNewsSources = @[
        @(DataRequestTypeNews),
        @(DataRequestTypeGoogleFinanceNews),
        @(DataRequestTypeYahooFinanceNews),
        @(DataRequestTypeSECFilings),
        @(DataRequestTypeSeekingAlphaNews)
    ];
    
    for (NSNumber *sourceType in allNewsSources) {
        self.enabledNewsSources[sourceType] = @YES;
    }
}

- (void)resetColorMappingToDefaults {
    self.colorKeywordMapping = [NSMutableDictionary dictionary];
    
    self.colorKeywordMapping[kDefaultYellowColor] = @"4-k,inside,insider";
    self.colorKeywordMapping[kDefaultPinkColor] = @"private placement,pp,offering,secondary offering";
    self.colorKeywordMapping[kDefaultBlueColor] = @"q1,q2,q3,q4,quarter,quarterly,earnings";
    self.colorKeywordMapping[kDefaultGreenColor] = @"acquisition,merger,buyout,deal";
    self.colorKeywordMapping[kDefaultRedColor] = @"lawsuit,investigation,sec,warning";
}

- (NSArray<NSNumber *> *)getEnabledNewsSourceTypes {
    NSMutableArray<NSNumber *> *enabledSources = [NSMutableArray array];
    
    for (NSNumber *sourceType in self.enabledNewsSources.allKeys) {
        if ([self.enabledNewsSources[sourceType] boolValue]) {
            [enabledSources addObject:sourceType];
        }
    }
    
    return [enabledSources copy];
}

#pragma mark - Auto Refresh

- (void)startAutoRefreshIfEnabled {
    [self stopAutoRefresh];
    
    if (self.autoRefresh && self.refreshInterval > 0) {
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:self.refreshInterval
                                                             target:self
                                                           selector:@selector(autoRefreshTriggered:)
                                                           userInfo:nil
                                                            repeats:YES];
        NSLog(@"📰 NewsWidget: Auto-refresh enabled (%.0f seconds)", self.refreshInterval);
    }
}

- (void)stopAutoRefresh {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
        NSLog(@"📰 NewsWidget: Auto-refresh stopped");
    }
}

- (void)autoRefreshTriggered:(NSTimer *)timer {
    if (self.currentSymbols.count > 0 && !self.isLoading) {
        NSLog(@"📰 NewsWidget: Auto-refresh triggered");
        [self refreshNews:nil];
    }
}



@end
