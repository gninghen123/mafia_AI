//
// ChartWidget+IndicatorsUI.h
// TradingApp
//
// ChartWidget extension for indicators panel UI integration
//

#import "ChartWidget.h"
#import "IndicatorsPanel.h"
#import "ChartTemplate+CoreDataClass.h"
#import "ChartIndicatorRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChartWidget (IndicatorsUI) <IndicatorsPanelDelegate>

#pragma mark - UI Components
@property (nonatomic, strong) NSButton *indicatorsPanelToggle;
@property (nonatomic, strong) IndicatorsPanel *indicatorsPanel;
@property (nonatomic, assign) BOOL isIndicatorsPanelVisible;
@property (nonatomic, strong) NSLayoutConstraint *splitViewTrailingConstraint;

#pragma mark - Template Management
@property (nonatomic, strong, nullable) ChartTemplate *currentChartTemplate;
@property (nonatomic, strong) NSMutableArray<ChartTemplate *> *availableTemplates;

#pragma mark - Rendering
@property (nonatomic, strong) NSMutableDictionary<NSString *, ChartIndicatorRenderer *> *indicatorRenderers; // panelID -> renderer

#pragma mark - Setup and Initialization

/// Setup indicators UI components
- (void)setupIndicatorsUI;

/// Load available templates from DataHub
- (void)loadAvailableTemplates;

/// Apply template to chart panels
/// @param template Template to apply
- (void)applyTemplate:(ChartTemplate *)template;

/// Create default template if none exists
- (void)ensureDefaultTemplateExists;

#pragma mark - UI Actions

/// Toggle indicators panel visibility
/// @param sender The toggle button
- (IBAction)toggleIndicatorsPanel:(NSButton *)sender;

/// Update indicators panel with current state
- (void)updateIndicatorsPanel;

/// Refresh indicators rendering in all panels
- (void)refreshIndicatorsRendering;

#pragma mark - Panel Management

/// Create chart panel from template
/// @param panelTemplate Template for the panel
/// @return Created chart panel view
- (ChartPanelView *)createChartPanelFromTemplate:(ChartPanelTemplate *)panelTemplate;

/// Update existing panels with template changes
/// @param template Updated template
- (void)updatePanelsWithTemplate:(ChartTemplate *)template;

/// Redistribute panel heights based on template
/// @param template Template with height specifications
- (void)redistributePanelHeights:(ChartTemplate *)template;

#pragma mark - Indicator Management

/// Add indicator to specific panel
/// @param indicator Indicator to add
/// @param panelTemplate Target panel template
/// @param parentIndicator Parent indicator (nil for root level)
- (void)addIndicator:(TechnicalIndicatorBase *)indicator
           toPanel:(ChartPanelTemplate *)panelTemplate
      parentIndicator:(TechnicalIndicatorBase * _Nullable)parentIndicator;

/// Remove indicator from panel
/// @param indicator Indicator to remove
- (void)removeIndicator:(TechnicalIndicatorBase *)indicator;

/// Configure indicator parameters
/// @param indicator Indicator to configure
- (void)configureIndicator:(TechnicalIndicatorBase *)indicator;

/// Calculate all indicators in template
- (void)calculateAllIndicators;

/// Calculate indicators for specific panel
/// @param panelTemplate Panel to calculate indicators for
- (void)calculateIndicatorsForPanel:(ChartPanelTemplate *)panelTemplate;

#pragma mark - Template Actions

/// Save current template
/// @param templateName Name for the template
/// @param completion Completion block
- (void)saveCurrentTemplateAs:(NSString *)templateName
                   completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/// Duplicate template
/// @param sourceTemplate Template to duplicate
/// @param newName New template name
/// @param completion Completion block
- (void)duplicateTemplate:(ChartTemplate *)sourceTemplate
                  newName:(NSString *)newName
               completion:(void(^)(ChartTemplate * _Nullable newTemplate, NSError * _Nullable error))completion;

/// Delete template
/// @param template Template to delete
/// @param completion Completion block
- (void)deleteTemplate:(ChartTemplate *)template
            completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/// Reset to original template
- (void)resetToOriginalTemplate;

#pragma mark - Data Flow

/// Update indicators with new chart data
/// @param chartData New historical bar data
- (void)updateIndicatorsWithChartData:(NSArray<HistoricalBarModel *> *)chartData;

/// Get indicator renderer for panel
/// @param panelID Panel identifier
/// @return Indicator renderer for the panel
- (ChartIndicatorRenderer * _Nullable)getIndicatorRendererForPanel:(NSString *)panelID;

/// Setup indicator renderer for panel
/// @param panelView Panel view to setup renderer for
- (void)setupIndicatorRendererForPanel:(ChartPanelView *)panelView;

#pragma mark - UI State Management

/// Update toggle button state
/// @param isVisible Whether panel is visible
- (void)updateIndicatorsPanelToggleState:(BOOL)isVisible;

/// Handle panel visibility change animations
/// @param isVisible New visibility state
/// @param animated Whether to animate the change
- (void)handleIndicatorsPanelVisibilityChange:(BOOL)isVisible animated:(BOOL)animated;

/// Position indicators panel toggle button
- (void)positionIndicatorsPanelToggleButton;

#pragma mark - Validation and Error Handling

/// Validate template before applying
/// @param template Template to validate
/// @param error Error pointer for validation failures
/// @return YES if template is valid
- (BOOL)validateTemplate:(ChartTemplate *)template error:(NSError **)error;

/// Handle template application errors
/// @param error Error that occurred
/// @param template Template that failed to apply
- (void)handleTemplateApplicationError:(NSError *)error template:(ChartTemplate *)template;

/// Show error alert
/// @param title Alert title
/// @param message Error message
- (void)showErrorAlert:(NSString *)title message:(NSString *)message;

#pragma mark - Cleanup

/// Clean up indicators UI resources
- (void)cleanupIndicatorsUI;


#pragma mark - Missing Method Declarations

/// Update all panels with current chart data
- (void)updateAllPanelsWithCurrentData;

/// Rename existing template
/// @param template Template to rename
- (void)renameTemplate:(ChartTemplate *)template;

/// Export template to file
/// @param template Template to export
- (void)exportTemplate:(ChartTemplate *)template;



@end

NS_ASSUME_NONNULL_END
