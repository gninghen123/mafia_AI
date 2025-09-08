//
//  IndicatorsPanel.h
//  TradingApp
//
//  Side panel for chart template and indicators management
//  FIXED: Nuovo metodo delegate per salvare template completo + removed legacy
//  ARCHITETTURA: Usa ChartTemplateModel (runtime models)
//

#import <Cocoa/Cocoa.h>
#import "ChartTemplateModels.h"
#import "TechnicalIndicatorBase.h"
#import "IndicatorConfigurationDialog.h"
#import "IndicatorRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@class IndicatorsPanel;

#pragma mark - Delegate Protocol - UPDATED

@protocol IndicatorsPanelDelegate <NSObject>

@required
/// Called when user selects a template
/// @param panel The indicators panel instance
/// @param template ChartTemplateModel that was selected
- (void)indicatorsPanel:(id)panel didSelectTemplate:(ChartTemplateModel *)template;

/// Called when user requests to apply the selected template
/// @param panel The indicators panel instance
/// @param template ChartTemplateModel to apply
- (void)indicatorsPanel:(id)panel didRequestApplyTemplate:(ChartTemplateModel *)template;

/// Called when user requests to configure an indicator
/// @param panel The indicators panel instance
/// @param indicator The indicator to configure
- (void)indicatorsPanel:(id)panel didRequestConfigureIndicator:(TechnicalIndicatorBase *)indicator;

/// ✅ NEW: Called when user wants to save a complete template
/// @param panel The indicators panel instance
/// @param template Complete ChartTemplateModel to save (replaces didRequestCreateTemplate)
- (void)indicatorsPanel:(id)panel didRequestSaveTemplate:(ChartTemplateModel *)template;

@optional
/// Called when panel visibility changes
/// @param panel The indicators panel instance
/// @param isVisible Whether the panel is now visible
- (void)indicatorsPanel:(id)panel didChangeVisibility:(BOOL)isVisible;

/// Called when user requests template management actions
/// @param panel The indicators panel instance
/// @param action The action type ("reload", "duplicate", "rename", "delete")
/// @param template ChartTemplateModel target template (nil for reload all)
- (void)indicatorsPanel:(id)panel didRequestTemplateAction:(NSString *)action forTemplate:(ChartTemplateModel *)template;

// ❌ REMOVED: didRequestCreateTemplate - replaced by didRequestSaveTemplate

@end

@interface IndicatorsPanel : NSView <NSOutlineViewDataSource, NSOutlineViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate>

#pragma mark - Configuration
@property (nonatomic, weak, nullable) id<IndicatorsPanelDelegate> delegate;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) CGFloat panelWidth;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;

#pragma mark - UI Components (readonly)
@property (nonatomic, strong, readonly) NSComboBox *templateComboBox;
@property (nonatomic, strong, readonly) NSButton *templateSettingsButton;
@property (nonatomic, strong, readonly) NSButton *templateSaveButton;
@property (nonatomic, strong, readonly) NSOutlineView *templateOutlineView;
@property (nonatomic, strong, readonly) NSScrollView *outlineScrollView;
@property (nonatomic, strong, readonly) NSButton *applyButton;
@property (nonatomic, strong, readonly) NSButton *resetButton;
@property (nonatomic, strong, readonly) NSButton *saveAsButton;

#pragma mark - Data Management
@property (nonatomic, strong) NSArray<ChartTemplateModel *> *availableTemplates;
@property (nonatomic, strong, nullable) ChartTemplateModel *currentTemplate;     // Working copy
@property (nonatomic, strong, nullable) ChartTemplateModel *originalTemplate;   // Original for comparison

#pragma mark - State
@property (nonatomic, assign) BOOL isLoadingTemplates;

#pragma mark - Initialization
- (instancetype)init;

#pragma mark - Setup Methods (Internal)
- (void)setupDefaults;
- (void)setupUI;
- (void)setupHeader;
- (void)setupTemplateOutlineView;
- (void)setupFooter;
- (void)setupConstraints;

#pragma mark - Visibility Management
- (void)toggleVisibilityAnimated:(BOOL)animated;
- (void)showAnimated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;

#pragma mark - Template Management
- (void)loadAvailableTemplates:(NSArray<ChartTemplateModel *> *)templates;
- (void)selectTemplate:(ChartTemplateModel *)template;
- (void)refreshTemplateDisplay;
- (void)resetToOriginalTemplate;
- (BOOL)hasUnsavedChanges;

#pragma mark - Dialog Methods
/// ✅ UPDATED: Now creates and saves complete template
- (void)showSaveAsDialog;

#pragma mark - Button Actions
- (void)templateSettingsAction:(NSButton *)sender;
- (void)applyAction:(NSButton *)sender;
- (void)resetAction:(NSButton *)sender;
- (void)saveAsAction:(NSButton *)sender;
- (void)updateButtonStates;

#pragma mark - NSOutlineView DataSource & Delegate
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item;
- (void)outlineViewSelectionDidChange:(NSNotification *)notification;

#pragma mark - NSComboBox DataSource & Delegate
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox;
- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index;
- (void)comboBoxSelectionDidChange:(NSNotification *)notification;

#pragma mark - Context Menu
- (NSMenu *)contextMenuForItem:(nullable id)item;
- (NSMenu *)createAddPanelSubmenu;
- (NSMenu *)createAddIndicatorSubmenuForPanel:(ChartPanelTemplateModel *)panel;
- (NSMenu *)createCustomIndicatorSubmenuForPanel:(ChartPanelTemplateModel *)panel;

@end

NS_ASSUME_NONNULL_END
