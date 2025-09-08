//
//  PanelSettingsDialog.h
//  TradingApp
//
//  Dialog for configuring chart panel settings
//

#import <Cocoa/Cocoa.h>
#import "ChartTemplateModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^PanelSettingsCompletionBlock)(BOOL saved, ChartPanelTemplateModel * _Nullable updatedPanel);

@interface PanelSettingsDialog : NSWindowController

#pragma mark - Properties
@property (nonatomic, strong, readonly) ChartPanelTemplateModel *panelTemplate;
@property (nonatomic, strong, readonly) ChartPanelTemplateModel *originalPanel;
@property (nonatomic, strong) ChartPanelTemplateModel *workingPanel;
@property (nonatomic, copy, nullable) PanelSettingsCompletionBlock completionBlock;

#pragma mark - UI Components - Basic Info
@property (weak) IBOutlet NSTextField *panelNameField;
@property (weak) IBOutlet NSTextField *rootIndicatorLabel;
@property (weak) IBOutlet NSPopUpButton *rootIndicatorPopup;
@property (weak) IBOutlet NSTextField *displayOrderField;

#pragma mark - UI Components - Height & Layout
@property (weak) IBOutlet NSSlider *heightSlider;
@property (weak) IBOutlet NSTextField *heightLabel;
@property (weak) IBOutlet NSTextField *heightPercentageLabel;
@property (weak) IBOutlet NSButton *autoHeightToggle;

#pragma mark - UI Components - Root Indicator Configuration
@property (weak) IBOutlet NSScrollView *rootIndicatorScrollView;
@property (weak) IBOutlet NSStackView *rootIndicatorStackView;
@property (weak) IBOutlet NSButton *configureRootIndicatorButton;

#pragma mark - UI Components - Child Indicators
@property (weak) IBOutlet NSOutlineView *childIndicatorsOutlineView;
@property (weak) IBOutlet NSButton *addChildIndicatorButton;
@property (weak) IBOutlet NSButton *removeChildIndicatorButton;
@property (weak) IBOutlet NSButton *configureChildIndicatorButton;

#pragma mark - UI Components - Actions
@property (weak) IBOutlet NSButton *saveButton;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSButton *resetButton;

#pragma mark - Class Methods
/// Create and show panel settings dialog
/// @param panelTemplate The panel template to configure
/// @param parentWindow Parent window for sheet presentation
/// @param completion Completion block called when dialog closes
+ (void)showSettingsForPanel:(ChartPanelTemplateModel *)panelTemplate
                parentWindow:(NSWindow *)parentWindow
                  completion:(PanelSettingsCompletionBlock)completion;

#pragma mark - Initialization
- (instancetype)initWithPanelTemplate:(ChartPanelTemplateModel *)panelTemplate;

#pragma mark - Dialog Management
- (void)showAsSheetForWindow:(NSWindow *)parentWindow completion:(PanelSettingsCompletionBlock)completion;

#pragma mark - Actions - Basic
- (IBAction)saveAction:(NSButton *)sender;
- (IBAction)cancelAction:(NSButton *)sender;
- (IBAction)resetAction:(NSButton *)sender;

#pragma mark - Actions - Height & Layout
- (IBAction)heightSliderChanged:(NSSlider *)sender;
- (IBAction)autoHeightToggled:(NSButton *)sender;

#pragma mark - Actions - Root Indicator
- (IBAction)rootIndicatorChanged:(NSPopUpButton *)sender;
- (IBAction)configureRootIndicator:(NSButton *)sender;

#pragma mark - Actions - Child Indicators
- (IBAction)addChildIndicator:(NSButton *)sender;
- (IBAction)removeChildIndicator:(NSButton *)sender;
- (IBAction)configureChildIndicator:(NSButton *)sender;

#pragma mark - Setup Methods
- (void)setupUI;
- (void)setupRootIndicatorPopup;
- (void)setupChildIndicatorsOutlineView;
- (void)updateHeightControls;

#pragma mark - Validation
- (BOOL)validatePanelSettings:(NSError **)error;

@end
