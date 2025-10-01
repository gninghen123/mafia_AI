//
//  ScreenerWidget.h
//  TradingApp
//
//  Yahoo Finance Stock Screener Widget - ADVANCED FILTERS VERSION
//

#import "BaseWidget.h"

@class NSTableView, NSTabView, NSTextField, NSButton, NSProgressIndicator, NSPopUpButton, NSSegmentedControl, NSScrollView;

// ============================================================================
// MISSING ENUM DEFINITIONS - AGGIUNTI PER COMPILAZIONE
// ============================================================================

typedef NS_ENUM(NSInteger, YahooScreenerType) {
    YahooScreenerTypeMostActive,
    YahooScreenerTypeGainers,
    YahooScreenerTypeLosers,
    YahooScreenerTypeCustom
};


// ============================================================================
// ADVANCED FILTER TYPES
// ============================================================================

typedef NS_ENUM(NSInteger, AdvancedFilterType) {
    AdvancedFilterTypeNumber,
    AdvancedFilterTypeRange,
    AdvancedFilterTypeSelect,
    AdvancedFilterTypeBoolean
};

typedef NS_ENUM(NSInteger, AdvancedFilterComparison) {
    AdvancedFilterEqual,           // eq
    AdvancedFilterGreaterThan,     // gt
    AdvancedFilterLessThan,        // lt
    AdvancedFilterBetween,         // btwn
    AdvancedFilterContains         // contains
};


// ============================================================================
// ADVANCED FILTER MODEL
// ============================================================================

@interface AdvancedScreenerFilter : NSObject
@property (nonatomic, strong) NSString *key;              // API key (e.g., "minPE")
@property (nonatomic, strong) NSString *displayName;      // UI name (e.g., "Min P/E Ratio")
@property (nonatomic, assign) AdvancedFilterType type;
@property (nonatomic, strong) NSArray<NSString *> *options; // For select type
@property (nonatomic, strong) NSNumber *value;            // Current value
@property (nonatomic, strong) NSNumber *minValue;         // For ranges
@property (nonatomic, strong) NSNumber *maxValue;         // For ranges
@property (nonatomic, assign) BOOL isActive;              // Whether filter is enabled

+ (instancetype)filterWithKey:(NSString *)key
                  displayName:(NSString *)displayName
                         type:(AdvancedFilterType)type;
+ (instancetype)selectFilterWithKey:(NSString *)key
                        displayName:(NSString *)displayName
                            options:(NSArray<NSString *> *)options;
@end

// ============================================================================
// FILTER CATEGORY MODEL
// ============================================================================

@interface FilterCategory : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *categoryKey;
@property (nonatomic, strong) NSArray<AdvancedScreenerFilter *> *filters;
@property (nonatomic, assign) BOOL isExpanded;

+ (instancetype)categoryWithName:(NSString *)name
                             key:(NSString *)key
                         filters:(NSArray<AdvancedScreenerFilter *> *)filters;
@end

// ============================================================================
// ENHANCED SCREENER RESULT MODEL
// ============================================================================

@interface YahooScreenerResult : NSObject
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSNumber *price;
@property (nonatomic, strong) NSNumber *change;
@property (nonatomic, strong) NSNumber *changePercent;
@property (nonatomic, strong) NSNumber *volume;
@property (nonatomic, strong) NSNumber *marketCap;
@property (nonatomic, strong) NSString *sector;
@property (nonatomic, strong) NSString *exchange;

// Enhanced financial metrics
@property (nonatomic, strong) NSNumber *trailingPE;
@property (nonatomic, strong) NSNumber *forwardPE;
@property (nonatomic, strong) NSNumber *priceToBook;
@property (nonatomic, strong) NSNumber *priceToSales;
@property (nonatomic, strong) NSNumber *pegRatio;
@property (nonatomic, strong) NSNumber *dividendYield;
@property (nonatomic, strong) NSNumber *beta;
@property (nonatomic, strong) NSNumber *fiftyTwoWeekLow;
@property (nonatomic, strong) NSNumber *fiftyTwoWeekHigh;

+ (instancetype)resultFromYahooData:(NSDictionary *)data;
@end

// ============================================================================
// MAIN WIDGET CLASS - ADVANCED VERSION
// ============================================================================

@interface ScreenerWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate>

#pragma mark - Configuration Properties

@property (nonatomic, assign) NSInteger maxResults;              // Default 100
@property (nonatomic, assign) BOOL autoRefresh;                 // Auto refresh every 30s
@property (nonatomic, strong) NSString *selectedPreset;         // Current screener preset

#pragma mark - Data Properties

@property (nonatomic, strong, readonly) NSMutableArray<YahooScreenerResult *> *currentResults;
@property (nonatomic, strong, readonly) NSMutableArray<FilterCategory *> *filterCategories;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, AdvancedScreenerFilter *> *activeFilters;



// Filter UI Elements - BASIC FINANCIAL RATIOS
@property (nonatomic, strong) NSTextField *peRatioMinField;
@property (nonatomic, strong) NSTextField *peRatioMaxField;
@property (nonatomic, strong) NSTextField *pegRatioMinField;
@property (nonatomic, strong) NSTextField *pegRatioMaxField;
@property (nonatomic, strong) NSTextField *priceToBookMinField;
@property (nonatomic, strong) NSTextField *priceToBookMaxField;
@property (nonatomic, strong) NSTextField *dividendYieldMinField;
@property (nonatomic, strong) NSTextField *dividendYieldMaxField;
@property (nonatomic, strong) NSTextField *betaMinField;
@property (nonatomic, strong) NSTextField *betaMaxField;

// EXPANDED FINANCIAL FILTERS
@property (nonatomic, strong) NSTextField *forwardPEMinField;
@property (nonatomic, strong) NSTextField *forwardPEMaxField;
@property (nonatomic, strong) NSTextField *epsTrailingTwelveMonthsMinField;
@property (nonatomic, strong) NSTextField *epsTrailingTwelveMonthsMaxField;
@property (nonatomic, strong) NSTextField *epsForwardMinField;
@property (nonatomic, strong) NSTextField *epsForwardMaxField;
@property (nonatomic, strong) NSTextField *trailingAnnualDividendYieldMinField;
@property (nonatomic, strong) NSTextField *trailingAnnualDividendYieldMaxField;
@property (nonatomic, strong) NSTextField *dividendRateMinField;
@property (nonatomic, strong) NSTextField *dividendRateMaxField;

// PRICE & VOLUME FILTERS
@property (nonatomic, strong) NSTextField *priceMinField;
@property (nonatomic, strong) NSTextField *priceMaxField;
@property (nonatomic, strong) NSTextField *intradayMarketCapMinField;
@property (nonatomic, strong) NSTextField *intradayMarketCapMaxField;
@property (nonatomic, strong) NSTextField *dayVolumeMinField;
@property (nonatomic, strong) NSTextField *dayVolumeMaxField;
@property (nonatomic, strong) NSTextField *averageDailyVolume3MonthMinField;
@property (nonatomic, strong) NSTextField *averageDailyVolume3MonthMaxField;

// PERFORMANCE FILTERS
@property (nonatomic, strong) NSTextField *oneDayPercentChangeMinField;
@property (nonatomic, strong) NSTextField *oneDayPercentChangeMaxField;
@property (nonatomic, strong) NSTextField *fiveDayPercentChangeMinField;
@property (nonatomic, strong) NSTextField *fiveDayPercentChangeMaxField;
@property (nonatomic, strong) NSTextField *oneMonthPercentChangeMinField;
@property (nonatomic, strong) NSTextField *oneMonthPercentChangeMaxField;
@property (nonatomic, strong) NSTextField *threeMonthPercentChangeMinField;
@property (nonatomic, strong) NSTextField *threeMonthPercentChangeMaxField;
@property (nonatomic, strong) NSTextField *sixMonthPercentChangeMinField;
@property (nonatomic, strong) NSTextField *sixMonthPercentChangeMaxField;
@property (nonatomic, strong) NSTextField *fiftyTwoWeekPercentChangeMinField;
@property (nonatomic, strong) NSTextField *fiftyTwoWeekPercentChangeMaxField;

// CATEGORY FILTERS
@property (nonatomic, strong) NSPopUpButton *secTypePopup;
@property (nonatomic, strong) NSPopUpButton *exchangePopup;
@property (nonatomic, strong) NSPopUpButton *industryPopup;
@property (nonatomic, strong) NSPopUpButton *peerGroupPopup;


@property (nonatomic, strong) NSButton *combineWithBasicCheckbox;

#pragma mark - Public Methods

/**
 * Refresh data with current filters
 */
- (void)refreshData;

/**
 * Load available filters from backend
 */
- (void)loadAvailableFilters;

/**
 * Apply advanced filters
 */
- (void)applyAdvancedFilters;

/**
 * Clear all filters
 */
- (void)clearAllFilters;

/**
 * Add or update a filter
 */
- (void)setFilter:(NSString *)key withValue:(id)value;

/**
 * Remove a filter
 */
- (void)removeFilter:(NSString *)key;

/**
 * Export current results to CSV
 */
- (void)exportResultsToCSV;

/**
 * Save current filter preset
 */
- (void)saveFilterPreset:(NSString *)presetName;

/**
 * Load filter preset
 */
- (void)loadFilterPreset:(NSString *)presetName;

@end
