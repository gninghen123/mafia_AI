//
//  IndicatorConfigurationDialog.h
//  TradingApp
//
//  Dialog for configuring technical indicator parameters
//

#import <Cocoa/Cocoa.h>
#import "TechnicalIndicatorBase.h"
#import "TechnicalIndicatorBase+Hierarchy.h"

typedef void(^IndicatorConfigurationCompletionBlock)(BOOL saved, NSDictionary * _Nullable updatedParameters);

@interface IndicatorConfigurationDialog : NSWindowController

#pragma mark - Properties
@property (nonatomic, strong, readonly) TechnicalIndicatorBase *indicator;
@property (nonatomic, strong, readonly) NSDictionary *originalParameters;
@property (nonatomic, strong) NSDictionary *currentParameters;
@property (nonatomic, copy, nullable) IndicatorConfigurationCompletionBlock completionBlock;

#pragma mark - UI Components (ora strong invece di weak - creati programmaticamente)
@property (strong) NSTextField *indicatorNameLabel;
@property (strong) NSTextField *indicatorDescriptionLabel;
@property (strong) NSScrollView *parametersScrollView;
@property (strong) NSStackView *parametersStackView;
@property (strong) NSButton *saveButton;
@property (strong) NSButton *cancelButton;
@property (strong) NSButton *resetButton;
@property (strong) NSTabView *tabView;

// Appearance Tab
@property (strong) NSColorWell *colorWell;
@property (strong) NSSlider *lineWidthSlider;
@property (strong) NSTextField *lineWidthLabel;
@property (strong) NSButton *visibilityToggle;

// Advanced Tab
@property (strong) NSTextView *notesTextView;

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
