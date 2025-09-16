//  ChartWidget+UnifiedSearch.h
//  TradingApp
//
//  Unified search field that adapts to static/normal mode
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ChartWidget.h"

// Forward declarations
@class StorageMetadataItem;

NS_ASSUME_NONNULL_BEGIN

@interface ChartWidget (UnifiedSearch) <NSComboBoxDataSource, NSComboBoxDelegate>

#pragma mark - Search Field Management

/// Setup unified search field functionality
- (void)setupUnifiedSearchField;

/// Update search field appearance and behavior based on current mode
- (void)updateSearchFieldForMode;

#pragma mark - Static Mode Search (Saved Data)

/// Search in saved data metadata cache
- (void)performSavedDataSearch:(NSString *)searchTerm;

/// Execute search and load best matching saved data
- (void)executeStaticModeSearch:(NSString *)searchTerm;

#pragma mark - Normal Mode Search (Live Symbols)

/// Search live symbols via DataHub API integration
- (void)performLiveSymbolSearch:(NSString *)searchTerm;

/// Execute normal mode entry (smart entry + symbol change)
- (void)executeNormalModeEntry:(NSString *)inputText;

/// Helper method to handle symbol change using available public interface
- (void)handleSimpleSymbolChange:(NSString *)symbol;

#pragma mark - Search Results Management

/// Current search results for dropdown
@property (nonatomic, strong, nullable) NSArray<StorageMetadataItem *> *currentSearchResults;

@end

NS_ASSUME_NONNULL_END

