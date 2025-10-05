//
//  PineScriptEditorWidget.h
//  TradingApp
//
//  Widget for creating custom indicators with PineScript-like language
//  Integrates with IndicatorRegistry for registration and validation
//

#import "BaseWidget.h"
#import "TechnicalIndicatorBase.h"
#import "IndicatorRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@class PineScriptEditorWidget;

#pragma mark - PineScript Editor Delegate

@protocol PineScriptEditorDelegate <NSObject>
@optional
/// Called when indicator is successfully created and compiled
/// @param editor The editor widget
/// @param indicator Created indicator instance
/// @param identifier Unique identifier for the indicator
- (void)pineScriptEditor:(PineScriptEditorWidget *)editor
       didCreateIndicator:(TechnicalIndicatorBase *)indicator
           withIdentifier:(NSString *)identifier;

/// Called when editor wants to test indicator on current chart data
/// @param editor The editor widget
/// @param script PineScript source code
/// @param identifier Temporary identifier for testing
- (void)pineScriptEditor:(PineScriptEditorWidget *)editor
         didRequestTest:(NSString *)script
         withIdentifier:(NSString *)identifier;
@end

#pragma mark - PineScript Compilation Result

@interface PineScriptCompilationResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, strong, nullable) NSString *errorMessage;
@property (nonatomic, assign) NSInteger errorLine;
@property (nonatomic, assign) NSInteger errorColumn;
@property (nonatomic, strong, nullable) NSArray<NSString *> *warnings;
@property (nonatomic, strong, nullable) NSDictionary *metadata; // Name, description, parameters
@end

#pragma mark - PineScript Editor Widget

@interface PineScriptEditorWidget : BaseWidget

#pragma mark - Delegate
@property (nonatomic, weak, nullable) id<PineScriptEditorDelegate> delegate;

#pragma mark - UI Components
@property (nonatomic, strong) NSTextView *codeTextView;
@property (nonatomic, strong) NSScrollView *codeScrollView;
@property (nonatomic, strong) NSTextView *outputTextView;
@property (nonatomic, strong) NSScrollView *outputScrollView;
@property (nonatomic, strong) NSTextField *indicatorNameField;
@property (nonatomic, strong) NSTextField *descriptionField;
@property (nonatomic, strong) NSButton *compileButton;
@property (nonatomic, strong) NSButton *testButton;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *loadButton;
@property (nonatomic, strong) NSButton *createNewButton;
@property (nonatomic, strong) NSPopUpButton *templatePopup;
@property (nonatomic, strong) NSProgressIndicator *compilationProgress;
@property (nonatomic, strong) NSSplitView *mainSplitView;
@property (nonatomic, strong) NSSplitView *editorSplitView;

#pragma mark - State
@property (nonatomic, strong, nullable) NSString *currentScript;
@property (nonatomic, strong, nullable) NSString *currentIndicatorID;
@property (nonatomic, strong, nullable) PineScriptCompilationResult *lastCompilationResult;
@property (nonatomic, assign) BOOL hasUnsavedChanges;
@property (nonatomic, strong, nullable) NSURL *currentFileURL;

#pragma mark - Initialization


// ✅ METODO per impostare il delegate dopo l'inizializzazione
- (void)setDelegate:(nullable id<PineScriptEditorDelegate>)delegate;
#pragma mark - Public Actions
/// Compile current script and check for errors
- (void)compileScript;

/// Test compiled indicator (requires delegate)
- (void)testIndicator;

/// Save current indicator to registry
- (void)saveIndicator;

/// Load script from file
- (void)loadScript;

/// Create new script from template
- (void)newScript;

/// Load script content directly
/// @param script PineScript source code
/// @param name Indicator name
- (void)loadScriptContent:(NSString *)script withName:(NSString *)name;

#pragma mark - Script Templates
/// Get available script templates
- (NSArray<NSDictionary *> *)availableTemplates;

/// Load template by name
/// @param templateName Name of the template to load
- (void)loadTemplate:(NSString *)templateName;

#pragma mark - Validation and Compilation
/// Validate script syntax
/// @param script PineScript source to validate
/// @return Compilation result with errors/warnings
- (PineScriptCompilationResult *)validateScript:(NSString *)script;

/// Extract metadata from script (name, description, parameters)
/// @param script PineScript source
/// @return Dictionary with metadata or nil if extraction fails
- (nullable NSDictionary *)extractMetadataFromScript:(NSString *)script;

@end

NS_ASSUME_NONNULL_END
