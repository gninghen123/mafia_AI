//
//  IndicatorsPanel.h
//  TradingApp
//
//  Side panel for chart template and indicators management
//  CLEANED: Contains only methods actually implemented in .m file
//  ARCHITETTURA: Usa ChartTemplateModel (runtime models)
//

#import <Cocoa/Cocoa.h>
#import "ChartTemplateModels.h"
#import "TechnicalIndicatorBase.h"
#import "IndicatorConfigurationDialog.h"
#import "IndicatorRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@class IndicatorsPanel;

#pragma mark - Delegate Protocol

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
/// @param template ChartTemplateModel target template
- (void)indicatorsPanel:(id)panel didRequestTemplateAction:(NSString *)action forTemplate:(ChartTemplateModel *)template;

@end

@interface IndicatorsPanel : NSView <NSOutlineViewDataSource, NSOutlineViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate>

#pragma mark - Configuration
@property (nonatomic, weak, nullable) id<IndicatorsPanelDelegate> delegate;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) CGFloat panelWidth;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;

#pragma mark - UI Components (readonly)
@property (nonatomic, strong, readwrite) NSComboBox *templateComboBox;
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
- (NSMenu *)createHierarchicalChildIndicatorMenuForIndicator:(TechnicalIndicatorBase *)parentIndicator;
- (NSMenu *)createCategorizedChildIndicatorSubmenuForIndicator:(TechnicalIndicatorBase *)parentIndicator;
- (NSMenu *)createCustomChildIndicatorSubmenuForIndicator:(TechnicalIndicatorBase *)parentIndicator;

#pragma mark - Context Menu Actions
- (void)addPanelFromMenu:(NSMenuItem *)sender;
- (void)addIndicatorToPanel:(NSMenuItem *)sender;
- (void)configurePanelSettings:(NSMenuItem *)sender;
- (void)removePanelWithConfirmation:(NSMenuItem *)sender;
- (void)configureIndicator:(NSMenuItem *)sender;
- (void)removeIndicator:(NSMenuItem *)sender;
- (void)showAddChildIndicatorDialog:(NSMenuItem *)sender;
- (void)addChildIndicatorToIndicator:(NSMenuItem *)sender;

#pragma mark - Placeholder Actions (TODO)
- (void)importCustomIndicator:(NSMenuItem *)sender;
- (void)showPineScriptEditor:(NSMenuItem *)sender;
- (void)browseIndicatorLibrary:(NSMenuItem *)sender;
- (void)importCustomChildIndicator:(NSMenuItem *)sender;
- (void)showPineScriptEditorForChild:(NSMenuItem *)sender;
- (void)browseChildIndicatorLibrary:(NSMenuItem *)sender;

#pragma mark - Panel Management
- (void)addPanelWithType:(NSString *)panelType rootIndicator:(NSString *)rootIndicator defaultHeight:(double)defaultHeight;
- (void)removePanel:(ChartPanelTemplateModel *)panel;

#pragma mark - Child Indicator Helpers
- (NSArray<NSString *> *)filterIndicatorsCompatibleWithParent:(NSArray<NSString *> *)indicators parentIndicator:(TechnicalIndicatorBase *)parentIndicator;
- (ChartPanelTemplateModel *)findPanelContainingIndicator:(TechnicalIndicatorBase *)indicator;

#pragma mark - Right-Click Support
- (void)rightMouseDown:(NSEvent *)event;

#pragma mark - Window Management
- (NSWindow *)window;

#pragma mark - Cleanup
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END
