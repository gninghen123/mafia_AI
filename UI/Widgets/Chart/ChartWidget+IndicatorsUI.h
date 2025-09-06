//
//  ChartWidget+IndicatorsUI.h - AGGIORNATO per runtime models
//  TradingApp
//
//  ChartWidget extension for indicators panel UI integration
//  ARCHITETTURA: Usa solo ChartTemplateModel (runtime models)
//

#import "ChartWidget.h"
#import "IndicatorsPanel.h"
#import "ChartTemplateModels.h"  // ✅ NUOVO: Runtime models invece di Core Data
#import "ChartIndicatorRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChartWidget (IndicatorsUI) <IndicatorsPanelDelegate>

#pragma mark - UI Components
@property (nonatomic, strong) NSButton *indicatorsPanelToggle;
@property (nonatomic, strong) IndicatorsPanel *indicatorsPanel;
@property (nonatomic, assign) BOOL isIndicatorsPanelVisible;
@property (nonatomic, strong) NSLayoutConstraint *splitViewTrailingConstraint;


#pragma mark - Template Management - AGGIORNATO per runtime models
@property (nonatomic, strong, nullable) ChartTemplateModel *currentChartTemplate;  // ✅ Runtime model
@property (nonatomic, strong) NSMutableArray<ChartTemplateModel *> *availableTemplates;  // ✅ Runtime models

#pragma mark - Rendering
@property (nonatomic, strong) NSMutableDictionary<NSString *, ChartIndicatorRenderer *> *indicatorRenderers; // panelID -> renderer

#pragma mark - Setup and Initialization

/// Setup indicators UI components
- (void)setupIndicatorsUI;

/// Load available templates from DataHub
- (void)loadAvailableTemplates;

/// Apply template to chart panels
/// @param template ChartTemplateModel (runtime model) to apply
- (void)applyTemplate:(ChartTemplateModel *)template;  // ✅ Runtime model

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
/// @param panelTemplate ChartPanelTemplateModel (runtime model) for the panel
/// @return Created chart panel view
- (ChartPanelView *)createChartPanelFromTemplate:(ChartPanelTemplateModel *)panelTemplate;  // ✅ Runtime model

/// Update existing panels with template changes
/// @param template ChartTemplateModel with updated configuration
- (void)updatePanelsWithTemplate:(ChartTemplateModel *)template;  // ✅ Runtime model

/// Redistribute panel heights based on template
/// @param template ChartTemplateModel with height specifications
- (void)redistributePanelHeights:(ChartTemplateModel *)template;  // ✅ Runtime model

@end

NS_ASSUME_NONNULL_END
