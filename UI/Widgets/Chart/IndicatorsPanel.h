//
// IndicatorsPanel.h - UPDATED for Runtime Models
// TradingApp
//
// Side panel for chart template and indicators management
// ARCHITETTURA: Usa ChartTemplateModel (runtime models) invece di Core Data
//

#import <Cocoa/Cocoa.h>
#import "ChartTemplateModels.h"  // ✅ AGGIORNATO: Runtime models invece di Core Data
#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

@class IndicatorsPanel;

#pragma mark - Delegate Protocol - AGGIORNATO per runtime models

@protocol IndicatorsPanelDelegate <NSObject>

@required
/// Called when user selects a template
/// @param panel The indicators panel instance
/// @param template ChartTemplateModel (runtime model) that was selected
- (void)indicatorsPanel:(id)panel didSelectTemplate:(ChartTemplateModel *)template;  // ✅ AGGIORNATO

/// Called when user requests to apply the selected template
/// @param panel The indicators panel instance
/// @param template ChartTemplateModel (runtime model) to apply
- (void)indicatorsPanel:(id)panel didRequestApplyTemplate:(ChartTemplateModel *)template;  // ✅ AGGIORNATO

/// Called when user requests to configure an indicator
/// @param panel The indicators panel instance
/// @param indicator The indicator to configure
- (void)indicatorsPanel:(id)panel didRequestConfigureIndicator:(TechnicalIndicatorBase *)indicator;

/// Called when user requests to create a new template
/// @param panel The indicators panel instance
/// @param templateName The name for the new template
- (void)indicatorsPanel:(id)panel didRequestCreateTemplate:(NSString *)templateName;

@optional
/// Called when panel visibility changes
/// @param panel The indicators panel instance
/// @param isVisible Whether the panel is now visible
- (void)indicatorsPanel:(id)panel didChangeVisibility:(BOOL)isVisible;

/// Called when user requests template management actions
/// @param panel The indicators panel instance
/// @param action The action type ("duplicate", "rename", "delete", "export")
/// @param template ChartTemplateModel (runtime model) target template
- (void)indicatorsPanel:(id)panel didRequestTemplateAction:(NSString *)action forTemplate:(ChartTemplateModel *)template;  // ✅ AGGIORNATO

@end

@interface IndicatorsPanel : NSView <NSOutlineViewDataSource, NSOutlineViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate>

#pragma mark - Configuration
@property (nonatomic, weak, nullable) id<IndicatorsPanelDelegate> delegate;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) CGFloat panelWidth;

#pragma mark - UI Components
@property (nonatomic, strong, readonly) NSComboBox *templateComboBox;
@property (nonatomic, strong, readonly) NSButton *templateSettingsButton;
@property (nonatomic, strong, readonly) NSButton *templateSaveButton;
@property (nonatomic, strong, readonly) NSOutlineView *templateOutlineView;
@property (nonatomic, strong, readonly) NSScrollView *outlineScrollView;
@property (nonatomic, strong, readonly) NSButton *applyButton;
@property (nonatomic, strong, readonly) NSButton *resetButton;
@property (nonatomic, strong, readonly) NSButton *saveAsButton;

#pragma mark - Data Management - AGGIORNATO per runtime models
@property (nonatomic, strong) NSArray<ChartTemplateModel *> *availableTemplates;  // ✅ AGGIORNATO
@property (nonatomic, strong, nullable) ChartTemplateModel *currentTemplate;     // ✅ AGGIORNATO: Working copy
@property (nonatomic, strong, nullable) ChartTemplateModel *originalTemplate;    // ✅ AGGIORNATO: Original reference

#pragma mark - Animation
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;

#pragma mark - Public Methods

/// Toggle panel visibility with animation
/// @param animated Whether to animate the transition
- (void)toggleVisibilityAnimated:(BOOL)animated;

/// Show panel with animation
/// @param animated Whether to animate the transition
- (void)showAnimated:(BOOL)animated;

/// Hide panel with animation
/// @param animated Whether to animate the transition
- (void)hideAnimated:(BOOL)animated;

/// Load and display available templates - AGGIORNATO per runtime models
/// @param templates Array of ChartTemplateModel (runtime models)
- (void)loadAvailableTemplates:(NSArray<ChartTemplateModel *> *)templates;  // ✅ AGGIORNATO

/// Select and display specific template - AGGIORNATO per runtime models
/// @param template ChartTemplateModel (runtime model) to select and display
- (void)selectTemplate:(ChartTemplateModel *)template;  // ✅ AGGIORNATO

/// Refresh the outline view display
- (void)refreshTemplateDisplay;

/// Reset current template to original state
- (void)resetToOriginalTemplate;

/// Check if current template has unsaved changes
/// @return YES if there are unsaved changes
- (BOOL)hasUnsavedChanges;

/// Get display name for panel type
/// @param panelType The panel type identifier
/// @return Human-readable panel name
- (NSString *)displayNameForPanelType:(NSString *)panelType;

/// Create context menu for outline view items
/// @param item The clicked item
/// @return Context menu for the item
- (NSMenu *)contextMenuForItem:(id)item;

@end

NS_ASSUME_NONNULL_END
