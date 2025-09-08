//
//  IndicatorConfigurationDialog.h
//  TradingApp
//
//  Dialog for configuring technical indicator parameters
//

#import <Cocoa/Cocoa.h>
#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^IndicatorConfigurationCompletionBlock)(BOOL saved, NSDictionary * _Nullable updatedParameters);

@interface IndicatorConfigurationDialog : NSWindowController

#pragma mark - Properties
@property (nonatomic, strong, readonly) TechnicalIndicatorBase *indicator;
@property (nonatomic, strong, readonly) NSDictionary *originalParameters;
@property (nonatomic, strong) NSDictionary *currentParameters;
@property (nonatomic, copy, nullable) IndicatorConfigurationCompletionBlock completionBlock;

#pragma mark - UI Components
@property (weak) IBOutlet NSTextField *indicatorNameLabel;
@property (weak) IBOutlet NSTextField *indicatorDescriptionLabel;
@property (weak) IBOutlet NSScrollView *parametersScrollView;
@property (weak) IBOutlet NSStackView *parametersStackView;
@property (weak) IBOutlet NSButton *saveButton;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSButton *resetButton;
@property (weak) IBOutlet NSTabView *tabView;

// Appearance Tab
@property (weak) IBOutlet NSColorWell *colorWell;
@property (weak) IBOutlet NSSlider *lineWidthSlider;
@property (weak) IBOutlet NSTextField *lineWidthLabel;
@property (weak) IBOutlet NSButton *visibilityToggle;

// Advanced Tab
@property (weak) IBOutlet NSTextView *notesTextView;

#pragma mark - Class Methods
/// Create and show indicator configuration dialog
/// @param indicator The indicator to configure
/// @param parentWindow Parent window for sheet presentation
/// @param completion Completion block called when dialog closes
+ (void)showConfigurationForIndicator:(TechnicalIndicatorBase *)indicator
                         parentWindow:(NSWindow *)parentWindow
                           completion:(IndicatorConfigurationCompletionBlock)completion;

#pragma mark - Initialization
- (instancetype)initWithIndicator:(TechnicalIndicatorBase *)indicator;

#pragma mark - Dialog Management
- (void)showAsSheetForWindow:(NSWindow *)parentWindow completion:(IndicatorConfigurationCompletionBlock)completion;

#pragma mark - Actions
- (IBAction)saveAction:(NSButton *)sender;
- (IBAction)cancelAction:(NSButton *)sender;
- (IBAction)resetAction:(NSButton *)sender;
- (IBAction)colorChanged:(NSColorWell *)sender;
- (IBAction)lineWidthChanged:(NSSlider *)sender;
- (IBAction)visibilityToggled:(NSButton *)sender;

#pragma mark - Parameter Management
- (void)setupParameterControls;
- (void)updateParametersFromControls;
- (void)resetParametersToDefaults;
- (BOOL)validateParameters:(NSError **)error;

@end
