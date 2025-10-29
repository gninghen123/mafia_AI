//
//  NewsWidget.m
//  TradingApp
//
//  Enhanced News Widget V2 - Final Complete Implementation
//  Features: Multi-symbol search, sortable columns, splitview preview, historical data integration
//

#import "NewsWidget.h"
#import "NewsPreferencesWindowController.h"
#import "DataHub.h"
#import "DataHub+News.h"
#import "DataHub+MarketData.h"
#import "CommonTypes.h"
#import <objc/runtime.h>

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
    
    NSLog(@"📰 NewsWidget V2: Initialized with splitview and sorting");
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
    
    // Create split view
    self.splitView = [[NSSplitView alloc] init];
    self.splitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.splitView.vertical = NO; // Horizontal split (top/bottom)
    self.splitView.dividerStyle = NSSplitViewDividerStyleThin;
    [self.contentView addSubview:self.splitView];
    
    // Create table view
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.allowsColumnSelection = NO;
    self.tableView.allowsColumnReordering = YES;
    self.tableView.allowsColumnResizing = YES;
    self.tableView.headerView = [[NSTableHeaderView alloc] init];
    
    // Create scroll view for table
    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 1800, 900)];
    self.scrollView.documentView = self.tableView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    
    // Create preview text view
    self.previewTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 1800, 300)];
    self.previewTextView.editable = NO;
    self.previewTextView.selectable = YES;
    self.previewTextView.richText = YES;
    self.previewTextView.importsGraphics = NO;
    self.previewTextView.allowsDocumentBackgroundColorChange = NO;
    self.previewTextView.backgroundColor = [NSColor controlBackgroundColor];
    self.previewTextView.string = @"Select a news item to view details";
    
    // Create scroll view for preview
    self.previewScrollView = [[NSScrollView alloc] init];
    self.previewScrollView.documentView = self.previewTextView;
    self.previewScrollView.hasVerticalScroller = YES;
    self.previewScrollView.hasHorizontalScroller = NO;
    self.previewScrollView.autohidesScrollers = YES;
    
    // Add views to split view
    [self.splitView addSubview:self.scrollView];
    [self.splitView addSubview:self.previewScrollView];
    
    [self setupConstraints];
}

- (void)setupTableView {
    // Date Column - SORTABLE
    NSTableColumn *dateColumn = [[NSTableColumn alloc] initWithIdentifier:@"date"];
    dateColumn.title = @"Date";
    dateColumn.width = 100;
    dateColumn.minWidth = 80;
    NSSortDescriptor *dateSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"publishedDate" ascending:NO];
    dateColumn.sortDescriptorPrototype = dateSortDescriptor;
    [self.tableView addTableColumn:dateColumn];
    
    // Symbol Column - SORTABLE
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    NSSortDescriptor *symbolSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"symbol" ascending:YES];
    symbolColumn.sortDescriptorPrototype = symbolSortDescriptor;
    [self.tableView addTableColumn:symbolColumn];
    
    // Title Column - SORTABLE
    NSTableColumn *titleColumn = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    titleColumn.title = @"Title";
    titleColumn.width = 400;
    titleColumn.minWidth = 200;
    NSSortDescriptor *titleSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"headline" ascending:YES];
    titleColumn.sortDescriptorPrototype = titleSortDescriptor;
    [self.tableView addTableColumn:titleColumn];
    
    // Color Indicators Column
    NSTableColumn *colorColumn = [[NSTableColumn alloc] initWithIdentifier:@"colors"];
    colorColumn.title = @"Type";
    colorColumn.width = 80;
    colorColumn.minWidth = 60;
    [self.tableView addTableColumn:colorColumn];
    
    // Source Column - SORTABLE
    NSTableColumn *sourceColumn = [[NSTableColumn alloc] initWithIdentifier:@"source"];
    sourceColumn.title = @"Source";
    sourceColumn.width = 100;
    sourceColumn.minWidth = 80;
    NSSortDescriptor *sourceSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"source" ascending:YES];
    sourceColumn.sortDescriptorPrototype = sourceSortDescriptor;
    [self.tableView addTableColumn:sourceColumn];
    
    // Variation % Column
    NSTableColumn *variationColumn = [[NSTableColumn alloc] initWithIdentifier:@"variation"];
    variationColumn.title = @"Var %";
    variationColumn.width = 80;
    variationColumn.minWidth = 60;
    NSSortDescriptor *variationSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"variation" ascending:NO];
    variationColumn.sortDescriptorPrototype = variationSortDescriptor;
    [self.tableView addTableColumn:variationColumn];
    
    // Priority/Strength Column - SORTABLE
    NSTableColumn *priorityColumn = [[NSTableColumn alloc] initWithIdentifier:@"priority"];
    priorityColumn.title = @"Strength";
    priorityColumn.width = 80;
    priorityColumn.minWidth = 60;
    NSSortDescriptor *prioritySortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"priority" ascending:NO];
    priorityColumn.sortDescriptorPrototype = prioritySortDescriptor;
    [self.tableView addTableColumn:priorityColumn];
    
    // Set default sort (by date, newest first)
    self.tableView.sortDescriptors = @[dateSortDescriptor];
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
        
        // Split view constraints
        [self.splitView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:8],
        [self.splitView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.splitView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.splitView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
    ]];
    
    // Set initial split position (70% table, 30% preview)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.splitView setPosition:300 ofDividerAtIndex:0];
    });
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
        [self updatePreview:nil];
        return;
    }
    
    NSArray<NSString *> *inputComponents = [self parseSearchInput:searchInput];
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
    
    NSInteger limit = self.newsLimit > 0 ? self.newsLimit : 50;
    if (uniqueNews.count > limit) {
        uniqueNews = [uniqueNews subarrayWithRange:NSMakeRange(0, limit)];
    }
    
    self.allNews = uniqueNews;
    
    // Calculate variation percentages with historical data
    [self calculateVariationPercentagesForNews:uniqueNews completion:^(NSArray<NewsModel *> *enrichedNews) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allNews = enrichedNews;
            [self applySortingAndFilters];
            [self showLoadingState:NO];
            [self updateStatus:[NSString stringWithFormat:@"Loaded %lu news items", (unsigned long)self.filteredNews.count]];
        });
    }];
}

#pragma mark - Historical Data Integration

- (void)calculateVariationPercentagesForNews:(NSArray<NewsModel *> *)news
                                  completion:(void(^)(NSArray<NewsModel *> *enrichedNews))completion {
    
    if (news.count == 0) {
        completion(news);
        return;
    }
    
    // Get unique symbols from news
    NSMutableSet<NSString *> *uniqueSymbols = [NSMutableSet set];
    NSDate *earliestDate = nil;
    NSDate *latestDate = nil;
    
    for (NewsModel *newsItem in news) {
        if (newsItem.symbol && newsItem.symbol.length > 0) {
            [uniqueSymbols addObject:newsItem.symbol.uppercaseString];
        }
        
        // Find date range
        if (!earliestDate || [newsItem.publishedDate compare:earliestDate] == NSOrderedAscending) {
            earliestDate = newsItem.publishedDate;
        }
        if (!latestDate || [newsItem.publishedDate compare:latestDate] == NSOrderedDescending) {
            latestDate = newsItem.publishedDate;
        }
    }
    
    if (uniqueSymbols.count == 0 || !earliestDate) {
        completion(news);
        return;
    }
    
    // Add buffer to date range
    NSCalendar *calendar = [NSCalendar currentCalendar];
    earliestDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-7 toDate:earliestDate options:0];
    latestDate = latestDate ?: [NSDate date];
    
    NSLog(@"📊 NewsWidget: Calculating variations for %lu symbols from %@ to %@",
          (unsigned long)uniqueSymbols.count, earliestDate, latestDate);
    
    // Load historical data for all symbols
    [self loadHistoricalDataForSymbols:[uniqueSymbols allObjects]
                              fromDate:earliestDate
                                toDate:latestDate
                            completion:^(NSDictionary<NSString *, NSArray *> *historicalData) {
        
        // Calculate variations for each news item
        [self.symbolVariations removeAllObjects];
        
        for (NewsModel *newsItem in news) {
            if (!newsItem.symbol || newsItem.symbol.length == 0) continue;
            
            NSString *symbol = newsItem.symbol.uppercaseString;
            NSArray *bars = historicalData[symbol];
            
            if (bars && bars.count > 0) {
                NSNumber *variation = [self calculateVariationForSymbol:symbol
                                                                 onDate:newsItem.publishedDate
                                                       withHistoricalData:bars];
                if (variation) {
                    NSString *key = [NSString stringWithFormat:@"%@_%@", symbol, @(newsItem.publishedDate.timeIntervalSince1970)];
                    self.symbolVariations[key] = variation;
                }
            }
        }
        
        completion(news);
    }];
}

- (void)loadHistoricalDataForSymbols:(NSArray<NSString *> *)symbols
                            fromDate:(NSDate *)fromDate
                              toDate:(NSDate *)toDate
                          completion:(void(^)(NSDictionary<NSString *, NSArray *> *historicalData))completion {
    
    NSMutableDictionary<NSString *, NSArray *> *allHistoricalData = [NSMutableDictionary dictionary];
    __block NSInteger remainingRequests = symbols.count;
    
    if (remainingRequests == 0) {
        completion(allHistoricalData);
        return;
    }
    
    DataHub *dataHub = [DataHub shared];
    
    for (NSString *symbol in symbols) {
        // Call DataHub to get historical daily data
        [dataHub getHistoricalBarsForSymbol:symbol timeframe:BarTimeframeDaily startDate:fromDate endDate:toDate needExtendedHours:NO completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                remainingRequests--;
                
                if (bars ) {
                    allHistoricalData[symbol] = bars;
                } else  {
                    NSLog(@"⚠️ NewsWidget: Failed to load historical data for %@: error downloading data", symbol );
                }
                
                if (remainingRequests == 0) {
                    completion([allHistoricalData copy]);
                }
            });
        }];
    }
}

- (NSNumber *)calculateVariationForSymbol:(NSString *)symbol
                                   onDate:(NSDate *)newsDate
                         withHistoricalData:(NSArray<HistoricalBarModel *> *)historicalBars {
    
    if (!historicalBars || historicalBars.count < 2) return nil;
    
    HistoricalBarModel *newsDateBar = nil;
    HistoricalBarModel *previousBar = nil;
    
    // Find the bar closest to the news date
    NSTimeInterval smallestTimeDiff = DBL_MAX;
    
    for (HistoricalBarModel *bar in historicalBars) {
        NSTimeInterval timeDiff = fabs([bar.date timeIntervalSinceDate:newsDate]);
        if (timeDiff < smallestTimeDiff) {
            smallestTimeDiff = timeDiff;
            newsDateBar = bar;
        }
    }
    
    if (!newsDateBar) return nil;
    
    // Find previous trading day
    NSInteger newsBarIndex = [historicalBars indexOfObject:newsDateBar];
    if (newsBarIndex > 0) {
        previousBar = historicalBars[newsBarIndex - 1];
    }
    
    if (!previousBar) return nil;
    
    // Calculate percentage change
    double previousClose = previousBar.close;
    double newsDateClose = newsDateBar.close;
    
    if (previousClose <= 0) return nil;
    
    double variationPercent = ((newsDateClose - previousClose) / previousClose) * 100.0;
    
    return @(variationPercent);
}

#pragma mark - Filtering and Sorting

- (void)applySortingAndFilters {
    NSMutableArray<NewsModel *> *filtered = [NSMutableArray arrayWithArray:self.allNews];
    
    // ✅ 1. Applica filtro parole escluse
    if (self.excludeKeywords.count > 0) {
        [filtered filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NewsModel *news, NSDictionary *bindings) {
            return ![self newsItem:news containsAnyExcludedKeywords:self.excludeKeywords];
        }]];
    }
    
    // ✅ 2. Controlla se si sta ordinando per "variation"
    NSSortDescriptor *sortDescriptor = self.tableView.sortDescriptors.firstObject;
    if (sortDescriptor && [sortDescriptor.key isEqualToString:@"variation"]) {
        BOOL ascending = sortDescriptor.ascending;
        
        [filtered sortUsingComparator:^NSComparisonResult(NewsModel *a, NewsModel *b) {
            NSString *keyA = [NSString stringWithFormat:@"%@_%@", a.symbol.uppercaseString, @(a.publishedDate.timeIntervalSince1970)];
            NSString *keyB = [NSString stringWithFormat:@"%@_%@", b.symbol.uppercaseString, @(b.publishedDate.timeIntervalSince1970)];
            NSNumber *varA = self.symbolVariations[keyA];
            NSNumber *varB = self.symbolVariations[keyB];
            
            double valA = varA ? varA.doubleValue : 0.0;
            double valB = varB ? varB.doubleValue : 0.0;
            
            if (valA == valB) return NSOrderedSame;
            if (ascending) {
                return valA < valB ? NSOrderedAscending : NSOrderedDescending;
            } else {
                return valA > valB ? NSOrderedAscending : NSOrderedDescending;
            }
        }];
    }
    // ✅ 3. Per tutte le altre colonne, usa sortDescriptors standard
    else if (self.tableView.sortDescriptors.count > 0) {
        [filtered sortUsingDescriptors:self.tableView.sortDescriptors];
    }
    
    // ✅ 4. Aggiorna i dati mostrati
    self.filteredNews = [filtered copy];
    [self.tableView reloadData];
    
    // ✅ 5. Resetta la preview quando i dati cambiano
    [self updatePreview:nil];
}

- (void)clearAllFilters {
    [self applySortingAndFilters];
}

#pragma mark - Table View Sorting Delegate

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    [self applySortingAndFilters];
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
        NSString *key = [NSString stringWithFormat:@"%@_%@", newsItem.symbol.uppercaseString, @(newsItem.publishedDate.timeIntervalSince1970)];
        NSNumber *variation = self.symbolVariations[key];
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
        
    NSString *key = [NSString stringWithFormat:@"%@_%@", newsItem.symbol.uppercaseString, @(newsItem.publishedDate.timeIntervalSince1970)];
    NSNumber *variation = self.symbolVariations[key];
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
            [self updatePreview:selectedNews];
            NSLog(@"📰 Selected news: %@ - %@", selectedNews.symbol, selectedNews.headline);
        } else {
            [self updatePreview:nil];
        }
    }

    - (void)tableView:(NSTableView *)tableView didDoubleClickOnRow:(NSInteger)row {
        if (row >= 0 && row < self.filteredNews.count) {
            NewsModel *newsItem = self.filteredNews[row];
            [self showNewsDetailModal:newsItem];
        }
    }

    #pragma mark - Preview Management

    - (void)updatePreview:(NewsModel *)newsItem {
        if (!newsItem) {
            self.previewTextView.string = @"Select a news item to view details";
            return;
        }
        
        // Create rich text content
        NSMutableAttributedString *content = [[NSMutableAttributedString alloc] init];
        
        // Title
        NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"📰 %@\n", newsItem.headline ?: @"No Title"]];
        [title addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:16] range:NSMakeRange(0, title.length)];
        [title addAttribute:NSForegroundColorAttributeName value:[NSColor labelColor] range:NSMakeRange(0, title.length)];
        [content appendAttributedString:title];
        
        // Metadata line
        NSString *metadataString = [NSString stringWithFormat:@"📅 %@ • 📊 %@ • 🏢 %@\n\n",
                                   [self.dateFormatter stringFromDate:newsItem.publishedDate],
                                   newsItem.symbol ?: @"--",
                                   newsItem.source ?: @"Unknown"];
        
    NSString *key = [NSString stringWithFormat:@"%@_%@", newsItem.symbol.uppercaseString, @(newsItem.publishedDate.timeIntervalSince1970)];
    NSNumber *variation = self.symbolVariations[key];
    if (variation) {
        metadataString = [NSString stringWithFormat:@"📅 %@ • 📊 %@ (%.2f%%) • 🏢 %@\n\n",
                         [self.dateFormatter stringFromDate:newsItem.publishedDate],
                         newsItem.symbol ?: @"--",
                         variation.doubleValue,
                         newsItem.source ?: @"Unknown"];
    }
        
        NSMutableAttributedString *metadata = [[NSMutableAttributedString alloc] initWithString:metadataString];
        [metadata addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:13] range:NSMakeRange(0, metadata.length)];
        [metadata addAttribute:NSForegroundColorAttributeName value:[NSColor secondaryLabelColor] range:NSMakeRange(0, metadata.length)];
        [content appendAttributedString:metadata];
        
        // Separator
        NSMutableAttributedString *separator = [[NSMutableAttributedString alloc] initWithString:@"───────────────────────────────────────\n\n"];
        [separator addAttribute:NSForegroundColorAttributeName value:[NSColor separatorColor] range:NSMakeRange(0, separator.length)];
        [content appendAttributedString:separator];
        
        // Summary/Content
        NSString *summaryText = newsItem.summary ?: @"No summary available.";
        NSMutableAttributedString *summary = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n\n", summaryText]];
        [summary addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:14] range:NSMakeRange(0, summary.length)];
        [summary addAttribute:NSForegroundColorAttributeName value:[NSColor labelColor] range:NSMakeRange(0, summary.length)];
        [content appendAttributedString:summary];
        
        // URL Link (if available)
        if (newsItem.url && newsItem.url.length > 0) {
            NSMutableAttributedString *urlLink = [[NSMutableAttributedString alloc] initWithString:@"🔗 Read Full Article"];
            [urlLink addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:14] range:NSMakeRange(0, urlLink.length)];
            [urlLink addAttribute:NSForegroundColorAttributeName value:[NSColor linkColor] range:NSMakeRange(0, urlLink.length)];
            [urlLink addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(0, urlLink.length)];
            [urlLink addAttribute:NSLinkAttributeName value:newsItem.url range:NSMakeRange(0, urlLink.length)];
            [content appendAttributedString:urlLink];
        }
        
        // Set the content
        [self.previewTextView.textStorage setAttributedString:content];
        
        // Enable link clicking
        self.previewTextView.linkTextAttributes = @{
            NSForegroundColorAttributeName: [NSColor linkColor],
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
        };
    }

    - (void)showNewsDetailModal:(NewsModel *)newsItem {
        // Create modal window
        NSRect windowFrame = NSMakeRect(0, 0, 600, 500);
        NSWindow *modalWindow = [[NSWindow alloc] initWithContentRect:windowFrame
                                                            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                              backing:NSBackingStoreBuffered
                                                                defer:NO];
        modalWindow.title = @"News Detail";
        modalWindow.minSize = NSMakeSize(400, 300);
        [modalWindow center];
        
        // Create content
        NSScrollView *scrollView = [[NSScrollView alloc] init];
        scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        scrollView.hasVerticalScroller = YES;
        scrollView.hasHorizontalScroller = NO;
        scrollView.autohidesScrollers = YES;
        
        NSTextView *textView = [[NSTextView alloc] init];
        textView.editable = NO;
        textView.selectable = YES;
        textView.richText = YES;
        textView.importsGraphics = NO;
        textView.allowsDocumentBackgroundColorChange = NO;
        textView.backgroundColor = [NSColor controlBackgroundColor];
        
        scrollView.documentView = textView;
        
        // Create close button
        NSButton *closeButton = [NSButton buttonWithTitle:@"Close" target:nil action:nil];
        closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        closeButton.keyEquivalent = @"\r";
        
        // Set close action
        __weak NSWindow *weakWindow = modalWindow;
        closeButton.target = closeButton;
        closeButton.action = @selector(closeModal:);
        objc_setAssociatedObject(closeButton, @"modalWindow", modalWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Add to window
        [modalWindow.contentView addSubview:scrollView];
        [modalWindow.contentView addSubview:closeButton];
        
        // Setup constraints
        [NSLayoutConstraint activateConstraints:@[
            [scrollView.topAnchor constraintEqualToAnchor:modalWindow.contentView.topAnchor constant:20],
            [scrollView.leadingAnchor constraintEqualToAnchor:modalWindow.contentView.leadingAnchor constant:20],
            [scrollView.trailingAnchor constraintEqualToAnchor:modalWindow.contentView.trailingAnchor constant:-20],
            [scrollView.bottomAnchor constraintEqualToAnchor:closeButton.topAnchor constant:-20],
            
            [closeButton.trailingAnchor constraintEqualToAnchor:modalWindow.contentView.trailingAnchor constant:-20],
            [closeButton.bottomAnchor constraintEqualToAnchor:modalWindow.contentView.bottomAnchor constant:-20],
            [closeButton.widthAnchor constraintEqualToConstant:80]
        ]];
        
        // Create detailed content
        [self populateDetailView:textView withNewsItem:newsItem];
        
        // Show modal
        [NSApp runModalForWindow:modalWindow];
    }

    - (void)populateDetailView:(NSTextView *)textView withNewsItem:(NewsModel *)newsItem {
        NSMutableAttributedString *content = [[NSMutableAttributedString alloc] init];
        
        // Large title
        NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n\n", newsItem.headline ?: @"No Title"]];
        [title addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:20] range:NSMakeRange(0, title.length)];
        [title addAttribute:NSForegroundColorAttributeName value:[NSColor labelColor] range:NSMakeRange(0, title.length)];
        [content appendAttributedString:title];
        
        // Detailed metadata
        NSString *detailMetadata = [NSString stringWithFormat:@"Symbol: %@\nDate: %@\nSource: %@\nType: %@\nPriority: %ld/5\n\n",
                                   newsItem.symbol ?: @"--",
                                   [self.dateFormatter stringFromDate:newsItem.publishedDate],
                                   newsItem.source ?: @"Unknown",
                                   newsItem.type ?: @"news",
                                   (long)newsItem.priority];
        
    NSString *key = [NSString stringWithFormat:@"%@_%@", newsItem.symbol.uppercaseString, @(newsItem.publishedDate.timeIntervalSince1970)];
    NSNumber *variation = self.symbolVariations[key];
    if (variation) {
        detailMetadata = [NSString stringWithFormat:@"Symbol: %@ (%.2f%%)\nDate: %@\nSource: %@\nType: %@\nPriority: %ld/5\n\n",
                         newsItem.symbol ?: @"--",
                         variation.doubleValue,
                         [self.dateFormatter stringFromDate:newsItem.publishedDate],
                         newsItem.source ?: @"Unknown",
                         newsItem.type ?: @"news",
                         (long)newsItem.priority];
    }
        
        NSMutableAttributedString *metadata = [[NSMutableAttributedString alloc] initWithString:detailMetadata];
        [metadata addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:14] range:NSMakeRange(0, metadata.length)];
        [metadata addAttribute:NSForegroundColorAttributeName value:[NSColor secondaryLabelColor] range:NSMakeRange(0, metadata.length)];
        [content appendAttributedString:metadata];
        
        // Content
        NSString *fullContent = newsItem.summary ?: @"No detailed content available.";
        NSMutableAttributedString *summary = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n\n", fullContent]];
        [summary addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:15] range:NSMakeRange(0, summary.length)];
        [summary addAttribute:NSForegroundColorAttributeName value:[NSColor labelColor] range:NSMakeRange(0, summary.length)];
        [content appendAttributedString:summary];
        
        // URL
        if (newsItem.url && newsItem.url.length > 0) {
            NSMutableAttributedString *urlSection = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Full Article: %@", newsItem.url]];
            [urlSection addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:14] range:NSMakeRange(0, urlSection.length)];
            [urlSection addAttribute:NSForegroundColorAttributeName value:[NSColor linkColor] range:NSMakeRange(14, newsItem.url.length)];
            [urlSection addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(14, newsItem.url.length)];
            [urlSection addAttribute:NSLinkAttributeName value:newsItem.url range:NSMakeRange(14, newsItem.url.length)];
            [content appendAttributedString:urlSection];
        }
        
        [textView.textStorage setAttributedString:content];
        textView.linkTextAttributes = @{
            NSForegroundColorAttributeName: [NSColor linkColor],
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
        };
    }

    // Helper method for close button
    - (void)closeModal:(NSButton *)sender {
        NSWindow *modalWindow = objc_getAssociatedObject(sender, @"modalWindow");
        [NSApp stopModal];
        [modalWindow close];
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
        
        // Convert enabledNewsSources to string-based dictionary for NSUserDefaults
        NSMutableDictionary *enabledSourcesForStorage = [NSMutableDictionary dictionary];
        for (NSNumber *sourceType in self.enabledNewsSources.allKeys) {
            NSString *sourceKey = [sourceType stringValue];
            NSNumber *enabled = self.enabledNewsSources[sourceType];
            enabledSourcesForStorage[sourceKey] = enabled;
        }
        [defaults setObject:enabledSourcesForStorage forKey:kNewsWidgetEnabledSources];
        
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
        
        // Convert string-based dictionary back to NSNumber keys
        NSDictionary *savedSourcesFromStorage = [defaults objectForKey:kNewsWidgetEnabledSources];
        if (savedSourcesFromStorage) {
            self.enabledNewsSources = [NSMutableDictionary dictionary];
            for (NSString *sourceKey in savedSourcesFromStorage.allKeys) {
                NSNumber *sourceType = @([sourceKey integerValue]);
                NSNumber *enabled = savedSourcesFromStorage[sourceKey];
                self.enabledNewsSources[sourceType] = enabled;
            }
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

    @end
