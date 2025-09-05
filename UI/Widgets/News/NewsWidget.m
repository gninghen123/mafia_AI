//
//  NewsWidget.m
//  TradingApp
//
//  Implementation of news widget with multiple source support
//

#import "NewsWidget.h"
#import "DataHub.h"
#import "DataHub+News.h"
#import "CommonTypes.h"

@interface NewsWidget ()
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation NewsWidget

#pragma mark - Lifecycle

- (void)setupContentView {
    [super setupContentView];
    
    // Initialize defaults
    self.newsLimit = 25;
    self.autoRefresh = YES;
    self.refreshInterval = 300; // 5 minutes
    self.selectedSource = 0; // All sources
    self.news = @[];
    
    [self createNewsUI];
    [self startAutoRefreshIfEnabled];
    
    NSLog(@"📰 NewsWidget: Initialized");
}

- (void)dealloc {
    [self stopAutoRefresh];
}

#pragma mark - UI Creation

- (void)createNewsUI {
    // Symbol input field
    self.symbolField = [[NSTextField alloc] init];
    self.symbolField.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolField.placeholderString = @"Enter symbol (e.g., AAPL)";
    self.symbolField.target = self;
    self.symbolField.action = @selector(symbolChanged:);
    [self.contentView addSubview:self.symbolField];
    
    // Refresh button
    self.refreshButton = [NSButton buttonWithTitle:@"⟳" target:self action:@selector(refreshNews:)];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.refreshButton.bezelStyle = NSBezelStyleTexturedRounded;
    [self.contentView addSubview:self.refreshButton];
    
    // Source selector
    self.sourceControl = [[NSSegmentedControl alloc] init];
    self.sourceControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.sourceControl.segmentCount = 5;
    [self.sourceControl setLabel:@"All" forSegment:0];
    [self.sourceControl setLabel:@"Google" forSegment:1];
    [self.sourceControl setLabel:@"Yahoo" forSegment:2];
    [self.sourceControl setLabel:@"SEC" forSegment:3];
    [self.sourceControl setLabel:@"SA" forSegment:4]; // Seeking Alpha
    self.sourceControl.selectedSegment = 0;
    self.sourceControl.target = self;
    self.sourceControl.action = @selector(sourceChanged:);
    [self.contentView addSubview:self.sourceControl];
    
    // Status label
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.stringValue = @"Enter a symbol to load news";
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [self.contentView addSubview:self.statusLabel];
    
    // Create table view
    [self createTableView];
    [self setupConstraints];
}

- (void)createTableView {
    // Create table view
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.headerView = nil;
    self.tableView.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.target = self;
    self.tableView.doubleAction = @selector(openNewsItem:);
    
    // Create columns
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"news"];
    column.title = @"News";
    [self.tableView addTableColumn:column];
    
    // Create scroll view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.tableView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    [self.contentView addSubview:self.scrollView];
}

- (void)setupConstraints {
    NSDictionary *views = @{
        @"symbolField": self.symbolField,
        @"refreshButton": self.refreshButton,
        @"sourceControl": self.sourceControl,
        @"statusLabel": self.statusLabel,
        @"scrollView": self.scrollView
    };
    
    // Horizontal constraints
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[symbolField]-4-[refreshButton(30)]-8-|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[sourceControl]-8-|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[statusLabel]-8-|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[scrollView]-0-|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    
    // Vertical constraints
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-8-[symbolField(22)]-4-[sourceControl(24)]-4-[statusLabel(16)]-4-[scrollView]-0-|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    
    // Align refresh button with symbol field
    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.refreshButton
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.symbolField
                                                                 attribute:NSLayoutAttributeCenterY
                                                                multiplier:1.0
                                                                  constant:0.0]];
}

#pragma mark - Actions

- (IBAction)symbolChanged:(id)sender {
    NSString *symbol = self.symbolField.stringValue;
    if (symbol.length > 0) {
        self.currentSymbol = symbol.uppercaseString;
        [self loadNewsForCurrentSymbol];
    }
}

- (IBAction)refreshNews:(id)sender {
    if (self.currentSymbol.length > 0) {
        [self loadNewsForCurrentSymbol];
    }
}

- (IBAction)sourceChanged:(id)sender {
    self.selectedSource = self.sourceControl.selectedSegment;
    if (self.currentSymbol.length > 0) {
        [self loadNewsForCurrentSymbol];
    }
}

- (IBAction)openNewsItem:(id)sender {
    NSInteger row = self.tableView.clickedRow;
    if (row >= 0 && row < self.news.count) {
        NewsModel *newsItem = self.news[row];
        if (newsItem.url && newsItem.url.length > 0) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:newsItem.url]];
        }
    }
}

#pragma mark - News Loading

- (void)loadNewsForCurrentSymbol {
    if (!self.currentSymbol || self.currentSymbol.length == 0) {
        return;
    }
    
    self.isLoading = YES;
    [self updateStatus:@"Loading news..."];
    
    DataHub *dataHub = [DataHub shared];
    
    if (self.selectedSource == 0) {
        // All sources - use aggregated method
        NSArray *sources = @[
            @(DataRequestTypeNews),
            @(DataRequestTypeGoogleFinanceNews),
            @(DataRequestTypeYahooFinanceNews),
            @(DataRequestTypeSECFilings),
            @(DataRequestTypeSeekingAlphaNews)
        ];
        
        [dataHub getAggregatedNewsForSymbol:self.currentSymbol
                                fromSources:sources
                                 completion:^(NSArray<NewsModel *> *news, NSError * _Nullable error) {
            [self handleNewsResponse:news error:error];
        }];
    } else {
        // Specific source
        DataRequestType newsType = [self dataRequestTypeForSource:self.selectedSource];
        
        [dataHub getNewsForSymbol:self.currentSymbol
                         newsType:newsType
                       completion:^(NSArray<NewsModel *> *news, BOOL isFresh, NSError * _Nullable error) {
            [self handleNewsResponse:news error:error];
        }];
    }
}

- (DataRequestType)dataRequestTypeForSource:(NSInteger)source {
    switch (source) {
        case 1: return DataRequestTypeGoogleFinanceNews;
        case 2: return DataRequestTypeYahooFinanceNews;
        case 3: return DataRequestTypeSECFilings;
        case 4: return DataRequestTypeSeekingAlphaNews;
        default: return DataRequestTypeNews;
    }
}

- (void)handleNewsResponse:(NSArray<NewsModel *> *)news error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isLoading = NO;
        
        if (error) {
            NSLog(@"❌ NewsWidget: Error loading news: %@", error.localizedDescription);
            [self updateStatus:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
            self.news = @[];
        } else {
            self.news = news;
            [self updateStatus:[NSString stringWithFormat:@"Loaded %lu news items", (unsigned long)news.count]];
            NSLog(@"✅ NewsWidget: Loaded %lu news items for %@", (unsigned long)news.count, self.currentSymbol);
        }
        
        [self.tableView reloadData];
    });
}

- (void)updateStatus:(NSString *)status {
    self.statusLabel.stringValue = status;
}

#pragma mark - Auto Refresh

- (void)startAutoRefreshIfEnabled {
    if (self.autoRefresh && !self.refreshTimer) {
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:self.refreshInterval
                                                             target:self
                                                           selector:@selector(autoRefreshTimer:)
                                                           userInfo:nil
                                                            repeats:YES];
        NSLog(@"📰 NewsWidget: Started auto-refresh timer (%.0f seconds)", self.refreshInterval);
    }
}

- (void)stopAutoRefresh {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
        NSLog(@"📰 NewsWidget: Stopped auto-refresh timer");
    }
}

- (void)autoRefreshTimer:(NSTimer *)timer {
    if (self.currentSymbol.length > 0 && !self.isLoading) {
        NSLog(@"📰 NewsWidget: Auto-refreshing news for %@", self.currentSymbol);
        [self loadNewsForCurrentSymbol];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.news.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.news.count) return nil;
    
    NewsModel *newsItem = self.news[row];
    
    static NSString *const kCellIdentifier = @"NewsCell";
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:kCellIdentifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = kCellIdentifier;
        
        // Create text field for the cell
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.lineBreakMode = NSLineBreakByWordWrapping;
        textField.maximumNumberOfLines = 3;
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        // Setup constraints
        [cellView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-4-[textField]-4-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:@{@"textField": textField}]];
        [cellView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-2-[textField]-2-|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:@{@"textField": textField}]];
    }
    
    // Format news item display
    NSMutableString *displayText = [NSMutableString string];
    
    // Add headline
    [displayText appendString:newsItem.headline];
    
    // Add source and date
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    NSString *dateString = [formatter stringFromDate:newsItem.publishedDate];
    
    [displayText appendFormat:@"\n%@ • %@", newsItem.source, dateString];
    
    // Add sentiment indicator
    if (newsItem.sentiment > 0) {
        [displayText appendString:@" 📈"];
    } else if (newsItem.sentiment < 0) {
        [displayText appendString:@" 📉"];
    }
    
    cellView.textField.stringValue = displayText;
    
    // Set text color based on sentiment
    if (newsItem.sentiment > 0) {
        cellView.textField.textColor = [NSColor systemGreenColor];
    } else if (newsItem.sentiment < 0) {
        cellView.textField.textColor = [NSColor systemRedColor];
    } else {
        cellView.textField.textColor = [NSColor labelColor];
    }
    
    return cellView;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 50.0; // Fixed height for each news item
}

#pragma mark - Widget Configuration

- (NSString *)widgetDisplayName {
    return @"News";
}

- (NSString *)widgetDescription {
    return @"Displays news and market sentiment from multiple sources";
}

@end
