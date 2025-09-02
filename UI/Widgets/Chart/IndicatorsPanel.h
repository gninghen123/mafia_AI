//
// IndicatorsPanel.h
// TradingApp
//
// Side panel for chart template and indicators management
//

#import <Cocoa/Cocoa.h>
#import "ChartTemplate+CoreDataClass.h"
#import "ChartPanelTemplate+CoreDataClass.h"
#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IndicatorsPanelDelegate <NSObject>

@required
/// Called when user selects a different template
/// @param panel The indicators panel instance
/// @param template The selected template
- (void)indicatorsPanel:(id)panel didSelectTemplate:(ChartTemplate *)template;

/// Called when user requests to apply current template changes
/// @param panel The indicators panel instance
/// @param template The template to apply
- (void)indicatorsPanel:(id)panel didRequestApplyTemplate:(ChartTemplate *)template;

/// Called when user requests to add a new indicator
/// @param panel The indicators panel instance
/// @param indicatorType The type of indicator to add
/// @param targetPanel The panel to add indicator to (or nil for new panel)
/// @param parentIndicator The parent indicator (or nil for root level)
- (void)indicatorsPanel:(id)panel
     didRequestAddIndicator:(NSString *)indicatorType
               toPanel:(ChartPanelTemplate * _Nullable)targetPanel
          parentIndicator:(TechnicalIndicatorBase * _Nullable)parentIndicator;

/// Called when user requests to remove an indicator
/// @param panel The indicators panel instance
/// @param indicator The indicator to remove
- (void)indicatorsPanel:(id)panel didRequestRemoveIndicator:(TechnicalIndicatorBase *)indicator;

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
/// @param template The target template
- (void)indicatorsPanel:(id)panel didRequestTemplateAction:(NSString *)action forTemplate:(ChartTemplate *)template;

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

#pragma mark - Data Management
@property (nonatomic, strong) NSArray<ChartTemplate *> *availableTemplates;
@property (nonatomic, strong, nullable) ChartTemplate *currentTemplate;    // Working copy
@property (nonatomic, strong, nullable) ChartTemplate *originalTemplate;   // Original reference

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

/// Load and display available templates
/// @param templates Array of available templates
- (void)loadAvailableTemplates:(NSArray<ChartTemplate *> *)templates;

/// Select and display specific template
/// @param template Template to select and display
- (void)selectTemplate:(ChartTemplate *)template;

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
