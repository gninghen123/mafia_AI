//
//  ScreenerWidget.h
//  mafia_AI
//
//  STOOQ Stock Screener Widget
//

#import "BaseWidget.h"
#import "STOOQDatabaseManager.h"

@class NSTableView, NSTabView, NSTextField, NSButton, NSProgressIndicator;

@interface ScreenerWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate>

#pragma mark - Configuration Properties

@property (nonatomic, assign) BOOL showVolume;           // Show volume column
@property (nonatomic, assign) BOOL showDollarVolume;     // Show $volume column
@property (nonatomic, assign) NSInteger maxResults;      // Limit results count

#pragma mark - Data Properties

@property (nonatomic, strong, readonly) NSMutableArray<STOOQStockData *> *currentResults;
@property (nonatomic, strong, readonly) NSMutableArray<NSString *> *selectedCategories;

#pragma mark - Public Methods

/**
 * Refresh data and update table
 */
- (void)refreshData;

/**
 * Apply basic filters and update results
 */
- (void)applyFiltersWithMinChange:(nullable NSNumber *)minChange
                        minVolume:(nullable NSNumber *)minVolume;

/**
 * Clear all filters and show all data
 */
- (void)clearFilters;

/**
 * Export current results to CSV
 */
- (void)exportResultsToCSV;

@end
