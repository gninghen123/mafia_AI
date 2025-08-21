//
//  ChartWidget+Patterns.h
//  TradingApp
//
//  Extension for Chart Patterns integration
//

#import "ChartWidget.h"
#import "ChartPatternModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChartWidget (Patterns)

#pragma mark - Interactive Pattern Creation

/// Show interactive pattern creation dialog
- (void)createPatternLabelInteractive;

/// Create pattern label programmatically
/// @param patternType The pattern type
/// @param notes Optional user notes
/// @param completion Completion block with success status and created pattern
- (void)createPatternLabel:(NSString *)patternType
                     notes:(nullable NSString *)notes
                completion:(void(^)(BOOL success, ChartPatternModel * _Nullable pattern, NSError * _Nullable error))completion;

#pragma mark - Pattern Loading

/// Load pattern into chart widget
/// @param pattern The pattern to load
- (void)loadPattern:(ChartPatternModel *)pattern;

/// Show pattern library dialog for loading
- (void)showPatternLibraryInteractive;

#pragma mark - Context Menu Integration

/// Add pattern menu items to existing context menu
- (void)addPatternMenuItemsToMenu:(NSMenu *)menu;

#pragma mark - Context Menu Actions

/// Context menu action for creating pattern label
- (IBAction)contextMenuCreatePatternLabel:(id)sender;

/// Context menu action for showing pattern library
- (IBAction)contextMenuShowPatternLibrary:(id)sender;

/// Context menu action for pattern management
- (IBAction)contextMenuManagePatterns:(id)sender;

#pragma mark - Pattern Management

/// Get patterns for current symbol
/// @return Array of patterns for the current symbol
- (NSArray<ChartPatternModel *> *)getPatternsForCurrentSymbol;

/// Show pattern management window
- (void)showPatternManagementWindow;

@end

NS_ASSUME_NONNULL_END
