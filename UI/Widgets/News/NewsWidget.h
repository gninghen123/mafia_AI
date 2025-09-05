//
//  NewsWidget.h
//  TradingApp
//
//  Enhanced News Widget V2 with multi-symbol search, color mapping, and filtering
//  Uses DataHub for news data with runtime models
//

#import "BaseWidget.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@class NewsPreferencesWindowController;

@interface NewsWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource>

#pragma mark - UI Components

// Search Panel
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *preferencesButton;
@property (nonatomic, strong) NSButton *clearFiltersButton;

// Results Table
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextField *statusLabel;

// Filter Controls
@property (nonatomic, strong) NSTextField *dateFromField;
@property (nonatomic, strong) NSTextField *dateToField;
@property (nonatomic, strong) NSTextField *keywordFilterField;

// Progress Indicator
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;

#pragma mark - Data Properties

@property (nonatomic, strong) NSArray<NSString *> *currentSymbols;
@property (nonatomic, strong) NSArray<NewsModel *> *allNews;        // All loaded news
@property (nonatomic, strong) NSArray<NewsModel *> *filteredNews;   // Filtered for display
@property (nonatomic, assign) BOOL isLoading;

#pragma mark - Preferences Window

@property (nonatomic, strong) NewsPreferencesWindowController *preferencesController;

#pragma mark - Configuration Properties (Persisted via UserDefaults)

// News Sources Selection
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *enabledNewsSources; // DataRequestType -> BOOL

// Color Mapping System
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *colorKeywordMapping; // ColorHex -> Keywords

// Filter Settings
@property (nonatomic, strong) NSArray<NSString *> *excludeKeywords;
@property (nonatomic, assign) NSInteger newsLimit;     // Default: 50

// Date Range Filtering
@property (nonatomic, strong, nullable) NSDate *filterDateFrom;
@property (nonatomic, strong, nullable) NSDate *filterDateTo;

// Auto-refresh
@property (nonatomic, assign) BOOL autoRefresh;        // Default: YES
@property (nonatomic, assign) NSTimeInterval refreshInterval; // Default: 300 seconds

#pragma mark - Search and Filter Methods

- (void)searchForInput:(NSString *)searchInput;
- (void)applyFilters;
- (void)clearAllFilters;

#pragma mark - Color System Methods

- (NSColor *)colorForNewsItem:(NewsModel *)newsItem;
- (NSArray<NSColor *> *)allColorsForNewsItem:(NewsModel *)newsItem;
- (BOOL)newsItem:(NewsModel *)newsItem matchesKeywords:(NSString *)keywords;

#pragma mark - Historical Data Integration

- (void)calculateVariationPercentagesForNews:(NSArray<NewsModel *> *)news
                                  completion:(void(^)(NSArray<NewsModel *> *enrichedNews))completion;

#pragma mark - Preferences Management

- (void)showPreferences;
- (void)savePreferences;
- (void)loadPreferences;
- (void)resetPreferencesToDefaults;

#pragma mark - Auto Refresh Management

- (void)startAutoRefreshIfEnabled;
- (void)stopAutoRefresh;
- (void)autoRefreshTriggered:(NSTimer *)timer;

@end

NS_ASSUME_NONNULL_END
