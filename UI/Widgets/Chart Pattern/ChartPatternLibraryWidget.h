//
//  ChartPatternLibraryWidget.h
//  TradingApp
//
//  Chart Pattern Library Widget - Browse and manage chart patterns
//

#import "BaseWidget.h"
#import "ChartPatternModel.h"
#import "SavedChartData.h"         // ✅ Import completo invece di forward declaration
#import "ChartWidget+SaveData.h"   // ✅ Import per accedere ai metodi di classe

@class ChartPatternManager;

NS_ASSUME_NONNULL_BEGIN

@interface ChartPatternLibraryWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate>

#pragma mark - UI Components

/// Main table view showing patterns
@property (nonatomic, strong) NSTableView *patternsTableView;

/// Scroll view for table
@property (nonatomic, strong) NSScrollView *scrollView;

/// Pattern type filter popup
@property (nonatomic, strong) NSPopUpButton *patternTypeFilter;

/// Toolbar with action buttons
@property (nonatomic, strong) NSView *toolbarView;

/// Action buttons
@property (nonatomic, strong) NSButton *createTypeButton;    // ✅ CORRETTO: era newTypeButton (violava Cocoa naming)
@property (nonatomic, strong) NSButton *renameTypeButton;
@property (nonatomic, strong) NSButton *deleteTypeButton;
@property (nonatomic, strong) NSButton *refreshButton;

/// Info label
@property (nonatomic, strong) NSTextField *infoLabel;

#pragma mark - Data Management

/// Pattern manager for business logic
@property (nonatomic, strong) ChartPatternManager *patternManager;

/// All patterns (unfiltered)
@property (nonatomic, strong) NSArray<ChartPatternModel *> *allPatterns;

/// Filtered patterns (shown in table)
@property (nonatomic, strong) NSArray<ChartPatternModel *> *filteredPatterns;

/// All pattern types
@property (nonatomic, strong) NSArray<NSString *> *patternTypes;

/// Currently selected filter type (nil = "All Types")
@property (nonatomic, strong, nullable) NSString *selectedFilterType;

#pragma mark - Public Methods

/// Refresh pattern data from manager
- (void)refreshPatternData;

/// Filter patterns by type
/// @param patternType Pattern type to filter by, nil for all
- (void)filterPatternsByType:(nullable NSString *)patternType;

/// Load selected pattern into target chart widget via chain
- (void)loadSelectedPatternToChain;

#pragma mark - Pattern Type Management

/// Show dialog to create new pattern type
- (void)showCreatePatternTypeDialog;

/// Show dialog to rename selected pattern type
- (void)showRenamePatternTypeDialog;

/// Show dialog to delete selected pattern type
- (void)showDeletePatternTypeDialog;

#pragma mark - Pattern Management

/// Delete selected pattern with confirmation
- (void)deleteSelectedPatternWithConfirmation;

/// Show pattern details/edit dialog
- (void)showPatternDetailsDialog;

#pragma mark - Action Methods

- (IBAction)patternTypeFilterChanged:(id)sender;
- (IBAction)createTypeButtonClicked:(id)sender;    // ✅ CORRETTO: era newTypeButtonClicked
- (IBAction)renameTypeButtonClicked:(id)sender;
- (IBAction)deleteTypeButtonClicked:(id)sender;
- (IBAction)refreshButtonClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END
