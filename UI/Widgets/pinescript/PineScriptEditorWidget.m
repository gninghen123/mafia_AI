
//  PineScriptEditorWidget.m
//  TradingApp
//
//  Widget for creating custom indicators with PineScript-like language
//

#import "PineScriptEditorWidget.h"
#import "DataHub.h"

#pragma mark - PineScript Compilation Result Implementation

@implementation PineScriptCompilationResult
- (instancetype)init {
    self = [super init];
    if (self) {
        _success = NO;
        _errorLine = -1;
        _errorColumn = -1;
    }
    return self;
}
@end

#pragma mark - PineScript Editor Widget Implementation

@implementation PineScriptEditorWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)widgetType panelType:(PanelType)panelType {
    self = [super initWithType:widgetType panelType:panelType];
    if (self) {
        _hasUnsavedChanges = NO;
    }
    return self;
}

- (void)setDelegate:(id<PineScriptEditorDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark - BaseWidget Overrides

- (NSString *)widgetTitle {
    return @"PineScript Editor";
}

- (NSSize)defaultSize {
    return NSMakeSize(1000, 700);
}

- (NSSize)minimumSize {
    return NSMakeSize(600, 400);
}

- (void)setupContentView {
    [super setupContentView];
    [self setupUI];
    [self setupSyntaxHighlighting];
    [self setupTemplateMenu];
    [self loadDefaultTemplate];
}

#pragma mark - UI Setup

- (void)setupUI {
    // Main container
    NSView *container = [[NSView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:container];
    
    // Setup main split view (vertical: editor | output)
    self.mainSplitView = [[NSSplitView alloc] init];
    self.mainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainSplitView.vertical = YES;
    self.mainSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [container addSubview:self.mainSplitView];
    
    // Setup editor split view (horizontal: metadata | code)
    self.editorSplitView = [[NSSplitView alloc] init];
    self.editorSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.editorSplitView.vertical = NO;
    self.editorSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [self.mainSplitView addSubview:self.editorSplitView];
    
    // Create UI components
    [self createMetadataPanel];
    [self createCodeEditor];
    [self createOutputPanel];
    [self createToolbar];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [container.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [container.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        // Main split view fills below toolbar, with minimum height
        [self.mainSplitView.topAnchor constraintEqualToAnchor:container.topAnchor constant:44], // Space for toolbar
        [self.mainSplitView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.mainSplitView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.mainSplitView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [self.mainSplitView.heightAnchor constraintGreaterThanOrEqualToConstant:200]
    ]];
    
    // Set initial split proportions
    [self setSplitViewProportions];
}

- (void)createMetadataPanel {
    NSView *metadataPanel = [[NSView alloc] init];
    metadataPanel.translatesAutoresizingMaskIntoConstraints = NO;

    // Indicator name
    NSTextField *nameLabel = [NSTextField labelWithString:@"Indicator Name:"];
    self.indicatorNameField = [[NSTextField alloc] init];
    self.indicatorNameField.placeholderString = @"Enter indicator name...";
    self.indicatorNameField.delegate = (id<NSTextFieldDelegate>)self;

    // Description
    NSTextField *descLabel = [NSTextField labelWithString:@"Description:"];
    self.descriptionField = [[NSTextField alloc] init];
    self.descriptionField.placeholderString = @"Enter description...";
    self.descriptionField.delegate = (id<NSTextFieldDelegate>)self;

    // Template selector
    NSTextField *templateLabel = [NSTextField labelWithString:@"Template:"];
    self.templatePopup = [[NSPopUpButton alloc] init];
    self.templatePopup.target = self;
    self.templatePopup.action = @selector(templateSelected:);

    // Layout
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorNameField.translatesAutoresizingMaskIntoConstraints = NO;
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionField.translatesAutoresizingMaskIntoConstraints = NO;
    templateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.templatePopup.translatesAutoresizingMaskIntoConstraints = NO;

    // Stack rows for metadata
    NSStackView *row1 = [NSStackView stackViewWithViews:@[nameLabel, self.indicatorNameField]];
    row1.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row1.spacing = 8;
    row1.translatesAutoresizingMaskIntoConstraints = NO;
    [row1 setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
    [row1 setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

    NSStackView *row2 = [NSStackView stackViewWithViews:@[descLabel, self.descriptionField]];
    row2.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row2.spacing = 8;
    row2.translatesAutoresizingMaskIntoConstraints = NO;
    [row2 setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
    [row2 setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

    NSStackView *row3 = [NSStackView stackViewWithViews:@[templateLabel, self.templatePopup]];
    row3.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row3.spacing = 8;
    row3.translatesAutoresizingMaskIntoConstraints = NO;
    [row3 setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
    [row3 setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

    NSStackView *vstack = [NSStackView stackViewWithViews:@[row1, row2, row3]];
    vstack.orientation = NSUserInterfaceLayoutOrientationVertical;
    vstack.spacing = 12;
    vstack.edgeInsets = NSEdgeInsetsMake(12, 12, 12, 12);
    vstack.translatesAutoresizingMaskIntoConstraints = NO;
    [vstack setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
    [vstack setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

    [metadataPanel addSubview:vstack];
    // Remove frame assignments (use auto layout)

    [NSLayoutConstraint activateConstraints:@[
        [vstack.topAnchor constraintEqualToAnchor:metadataPanel.topAnchor],
        [vstack.leadingAnchor constraintEqualToAnchor:metadataPanel.leadingAnchor],
        [vstack.trailingAnchor constraintEqualToAnchor:metadataPanel.trailingAnchor],
        [vstack.bottomAnchor constraintEqualToAnchor:metadataPanel.bottomAnchor],
        [metadataPanel.heightAnchor constraintGreaterThanOrEqualToConstant:100]
    ]];

    // Let split view manage the size, so just ensure translatesAutoresizingMaskIntoConstraints = NO
    metadataPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.editorSplitView addSubview:metadataPanel];
}

- (void)createCodeEditor {
    // Create code text view with scroll view
    self.codeScrollView = [[NSScrollView alloc] init];
    self.codeScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.codeScrollView.hasVerticalScroller = YES;
    self.codeScrollView.hasHorizontalScroller = YES;
    self.codeScrollView.autohidesScrollers = YES;
    
    self.codeTextView = [[NSTextView alloc] init];
    self.codeTextView.delegate = (id<NSTextViewDelegate>)self;
    self.codeTextView.font = [NSFont fontWithName:@"SF Mono" size:13] ?: [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    self.codeTextView.automaticQuoteSubstitutionEnabled = NO;
    self.codeTextView.automaticDashSubstitutionEnabled = NO;
    self.codeTextView.automaticTextReplacementEnabled = NO;
    self.codeTextView.automaticSpellingCorrectionEnabled = NO;
    
    self.codeScrollView.documentView = self.codeTextView;
    // Remove frame assignment. Let split view manage sizing.
    self.codeScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.editorSplitView addSubview:self.codeScrollView];
    // Let split view manage, but ensure scroll view fills itself
    [NSLayoutConstraint activateConstraints:@[
        [self.codeScrollView.widthAnchor constraintGreaterThanOrEqualToConstant:200],
        [self.codeScrollView.heightAnchor constraintGreaterThanOrEqualToConstant:100]
    ]];
}

- (void)createOutputPanel {
    // Create output text view with scroll view
    self.outputScrollView = [[NSScrollView alloc] init];
    self.outputScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.outputScrollView.hasVerticalScroller = YES;
    self.outputScrollView.hasHorizontalScroller = YES;
    self.outputScrollView.autohidesScrollers = YES;

    self.outputTextView = [[NSTextView alloc] init];
    self.outputTextView.editable = NO;
    self.outputTextView.font = [NSFont fontWithName:@"SF Mono" size:11] ?: [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.outputTextView.textColor = [NSColor secondaryLabelColor];
    
    self.outputScrollView.documentView = self.outputTextView;
    // Remove frame assignment. Let split view manage sizing.
    self.outputScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainSplitView addSubview:self.outputScrollView];
    // Let split view manage, but ensure scroll view fills itself
    [NSLayoutConstraint activateConstraints:@[
        [self.outputScrollView.widthAnchor constraintGreaterThanOrEqualToConstant:100],
        [self.outputScrollView.heightAnchor constraintGreaterThanOrEqualToConstant:50]
    ]];
}

- (void)createToolbar {
    NSView *toolbar = [[NSView alloc] init];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:toolbar];
    
    // Buttons
    self.createNewButton = [NSButton buttonWithTitle:@"New" target:self action:@selector(newScript)];
    self.loadButton = [NSButton buttonWithTitle:@"Load" target:self action:@selector(loadScript)];
    self.compileButton = [NSButton buttonWithTitle:@"Compile" target:self action:@selector(compileScript)];
    self.testButton = [NSButton buttonWithTitle:@"Test" target:self action:@selector(testIndicator)];
    self.saveButton = [NSButton buttonWithTitle:@"Save" target:self action:@selector(saveIndicator)];
    
    // Progress indicator
    self.compilationProgress = [[NSProgressIndicator alloc] init];
    self.compilationProgress.style = NSProgressIndicatorStyleSpinning;
    self.compilationProgress.controlSize = NSControlSizeSmall;
    self.compilationProgress.hidden = YES;
    
    // Style buttons
    self.compileButton.bezelStyle = NSBezelStyleRounded;
    self.compileButton.keyEquivalent = @"\r"; // Enter key
    self.testButton.bezelStyle = NSBezelStyleRounded;
    self.saveButton.bezelStyle = NSBezelStyleRounded;
    
    // Layout toolbar
    NSStackView *buttonStack = [NSStackView stackViewWithViews:@[
        self.createNewButton, self.loadButton, self.compileButton, self.testButton, self.saveButton, self.compilationProgress
    ]];
    buttonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonStack.spacing = 8;
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    [toolbar addSubview:buttonStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [toolbar.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [toolbar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [toolbar.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [toolbar.heightAnchor constraintEqualToConstant:44],
        
        [buttonStack.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [buttonStack.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor constant:12]
    ]];
    
    [self updateButtonStates];
}

- (void)setSplitViewProportions {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Editor split view (metadata:code)
        NSRect editorFrame = self.editorSplitView.bounds;
        [self.editorSplitView setPosition:120 ofDividerAtIndex:0];
        
        // Main split view (editor:output)
        NSRect mainFrame = self.mainSplitView.bounds;
        [self.mainSplitView setPosition:mainFrame.size.width * 0.6 ofDividerAtIndex:0];
    });
}

#pragma mark - Syntax Highlighting

- (void)setupSyntaxHighlighting {
    // Basic syntax highlighting for PineScript-like language
    [self applySyntaxHighlighting];
}

- (void)applySyntaxHighlighting {
    NSString *text = self.codeTextView.string;
    if (!text.length) return;
    
    // Reset attributes
    [self.codeTextView.textStorage removeAttribute:NSForegroundColorAttributeName
                                             range:NSMakeRange(0, text.length)];
    
    // Keywords
    NSArray *keywords = @[@"study", @"plot", @"input", @"if", @"else", @"for", @"while", @"true", @"false", @"na", @"close", @"open", @"high", @"low", @"volume", @"sma", @"ema", @"rsi", @"atr"];
    
    for (NSString *keyword in keywords) {
        [self highlightPattern:[NSString stringWithFormat:@"\\b%@\\b", keyword]
                    withColor:[NSColor systemBlueColor]];
    }
    
    // Numbers
    [self highlightPattern:@"\\b\\d+(\\.\\d+)?\\b" withColor:[NSColor systemPurpleColor]];
    
    // Strings
    [self highlightPattern:@"\"[^\"]*\"" withColor:[NSColor systemGreenColor]];
    [self highlightPattern:@"'[^']*'" withColor:[NSColor systemGreenColor]];
    
    // Comments
    [self highlightPattern:@"//.*$" withColor:[NSColor systemGrayColor]];
}

- (void)highlightPattern:(NSString *)pattern withColor:(NSColor *)color {
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines
                                                                             error:&error];
    if (error) return;
    
    NSString *text = self.codeTextView.string;
    NSArray *matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    
    for (NSTextCheckingResult *match in matches) {
        [self.codeTextView.textStorage addAttribute:NSForegroundColorAttributeName
                                              value:color
                                              range:match.range];
    }
}

#pragma mark - Template Management

- (void)setupTemplateMenu {
    [self.templatePopup removeAllItems];
    
    NSArray *templates = [self availableTemplates];
    for (NSDictionary *template in templates) {
        [self.templatePopup addItemWithTitle:template[@"name"]];
    }
}

- (NSArray<NSDictionary *> *)availableTemplates {
    return @[
        @{
            @"name": @"Simple Moving Average",
            @"script": @"//@version=5\nstudy(\"Custom SMA\", shorttitle=\"SMA\", overlay=true)\n\nlength = input(20, \"Length\")\nsource = input(close, \"Source\")\n\nsma_value = sma(source, length)\nplot(sma_value, \"SMA\", color=color.blue)"
        },
        @{
            @"name": @"RSI Oscillator",
            @"script": @"//@version=5\nstudy(\"Custom RSI\", shorttitle=\"RSI\")\n\nlength = input(14, \"Length\")\nsource = input(close, \"Source\")\n\nrsi_value = rsi(source, length)\nplot(rsi_value, \"RSI\", color=color.purple)\nhline(70, \"Overbought\", color=color.red)\nhline(30, \"Oversold\", color=color.green)"
        },
        @{
            @"name": @"Bollinger Bands",
            @"script": @"//@version=5\nstudy(\"Custom Bollinger Bands\", shorttitle=\"BB\", overlay=true)\n\nlength = input(20, \"Length\")\nmult = input(2.0, \"Multiplier\")\nsource = input(close, \"Source\")\n\nbasis = sma(source, length)\ndev = mult * stdev(source, length)\nupper = basis + dev\nlower = basis - dev\n\nplot(basis, \"Middle\", color=color.blue)\nplot(upper, \"Upper\", color=color.red)\nplot(lower, \"Lower\", color=color.green)"
        },
        @{
            @"name": @"Empty Template",
            @"script": @"//@version=5\nstudy(\"Custom Indicator\", shorttitle=\"CI\")\n\n// Your indicator code here\nplot(close, \"Price\", color=color.blue)"
        }
    ];
}

- (void)templateSelected:(NSPopUpButton *)sender {
    NSString *selectedName = sender.selectedItem.title;
    [self loadTemplate:selectedName];
}

- (void)loadTemplate:(NSString *)templateName {
    NSArray *templates = [self availableTemplates];
    for (NSDictionary *template in templates) {
        if ([template[@"name"] isEqualToString:templateName]) {
            self.codeTextView.string = template[@"script"];
            [self applySyntaxHighlighting];
            self.hasUnsavedChanges = NO;
            [self updateButtonStates];
            [self logOutput:[NSString stringWithFormat:@"Loaded template: %@", templateName]];
            break;
        }
    }
}

- (void)loadDefaultTemplate {
    [self loadTemplate:@"Empty Template"];
}

#pragma mark - Public Actions

- (void)compileScript {
    if (!self.codeTextView.string.length) {
        [self logError:@"No script to compile"];
        return;
    }
    
    [self startCompilation];
    
    // Validate script
    PineScriptCompilationResult *result = [self validateScript:self.codeTextView.string];
    self.lastCompilationResult = result;
    
    [self finishCompilation];
    
    if (result.success) {
        [self logSuccess:@"✅ Script compiled successfully"];
        if (result.warnings.count > 0) {
            for (NSString *warning in result.warnings) {
                [self logWarning:warning];
            }
        }
    } else {
        [self logError:[NSString stringWithFormat:@"❌ Compilation failed: %@", result.errorMessage]];
        if (result.errorLine > 0) {
            [self highlightErrorLine:result.errorLine];
        }
    }
    
    [self updateButtonStates];
}

- (void)testIndicator {
    if (!self.lastCompilationResult || !self.lastCompilationResult.success) {
        [self logError:@"Please compile the script successfully before testing"];
        return;
    }
    
    if (!self.delegate || ![self.delegate respondsToSelector:@selector(pineScriptEditor:didRequestTest:withIdentifier:)]) {
        [self logError:@"No delegate available for testing"];
        return;
    }
    
    NSString *testID = [NSString stringWithFormat:@"test_%@_%@",
                       self.indicatorNameField.stringValue.length ? self.indicatorNameField.stringValue : @"indicator",
                       [[NSUUID UUID] UUIDString]];
    
    [self.delegate pineScriptEditor:self
                   didRequestTest:self.codeTextView.string
                   withIdentifier:testID];
    
    [self logOutput:@"🧪 Testing indicator on current chart..."];
}

- (void)saveIndicator {
    if (!self.lastCompilationResult || !self.lastCompilationResult.success) {
        [self logError:@"Please compile the script successfully before saving"];
        return;
    }
    
    NSString *indicatorName = self.indicatorNameField.stringValue;
    if (!indicatorName.length) {
        [self logError:@"Please enter an indicator name"];
        return;
    }
    
    // Generate unique identifier
    NSString *identifier = [indicatorName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    identifier = [identifier stringByAppendingFormat:@"_%@", [[[NSUUID UUID] UUIDString] substringToIndex:8]];
    
    // Register with IndicatorRegistry
    NSError *error;
    BOOL success = [[IndicatorRegistry sharedRegistry] registerPineScriptIndicator:self.codeTextView.string
                                                                    withIdentifier:identifier
                                                                             error:&error];
    
    if (success) {
        self.currentIndicatorID = identifier;
        self.hasUnsavedChanges = NO;
        [self logSuccess:[NSString stringWithFormat:@"✅ Indicator saved successfully as '%@'", identifier]];
        
        // Notify delegate if available
        if (self.delegate && [self.delegate respondsToSelector:@selector(pineScriptEditor:didCreateIndicator:withIdentifier:)]) {
            TechnicalIndicatorBase *indicator = [[IndicatorRegistry sharedRegistry] createIndicatorWithIdentifier:identifier parameters:nil];
            if (indicator) {
                [self.delegate pineScriptEditor:self didCreateIndicator:indicator withIdentifier:identifier];
            }
        }
    } else {
        [self logError:[NSString stringWithFormat:@"❌ Failed to save indicator: %@", error.localizedDescription]];
    }
    
    [self updateButtonStates];
}

- (void)loadScript {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowedFileTypes = @[@"pine", @"txt"];
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.allowsMultipleSelection = NO;
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSURL *fileURL = openPanel.URL;
        NSError *error;
        NSString *content = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            [self logError:[NSString stringWithFormat:@"Failed to load file: %@", error.localizedDescription]];
        } else {
            self.currentFileURL = fileURL;
            [self loadScriptContent:content withName:fileURL.lastPathComponent.stringByDeletingPathExtension];
        }
    }
}

- (void)newScript {
    if (self.hasUnsavedChanges) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Unsaved Changes";
        alert.informativeText = @"You have unsaved changes. Do you want to save before creating a new script?";
        [alert addButtonWithTitle:@"Save"];
        [alert addButtonWithTitle:@"Don't Save"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSModalResponse response = [alert runModal];
        if (response == NSAlertFirstButtonReturn) {
            [self saveIndicator];
        } else if (response == NSAlertThirdButtonReturn) {
            return; // Cancel
        }
    }
    
    [self loadDefaultTemplate];
    self.indicatorNameField.stringValue = @"";
    self.descriptionField.stringValue = @"";
    self.currentIndicatorID = nil;
    self.currentFileURL = nil;
    self.lastCompilationResult = nil;
    [self clearOutput];
    [self updateButtonStates];
}

- (void)loadScriptContent:(NSString *)script withName:(NSString *)name {
    self.codeTextView.string = script ?: @"";
    self.indicatorNameField.stringValue = name ?: @"";
    self.currentScript = script;
    self.hasUnsavedChanges = NO;
    
    // Extract metadata from script
    NSDictionary *metadata = [self extractMetadataFromScript:script];
    if (metadata) {
        if (metadata[@"name"]) {
            self.indicatorNameField.stringValue = metadata[@"name"];
        }
        if (metadata[@"description"]) {
            self.descriptionField.stringValue = metadata[@"description"];
        }
    }
    
    [self applySyntaxHighlighting];
    [self updateButtonStates];
    [self logOutput:[NSString stringWithFormat:@"Loaded script: %@", name]];
}

#pragma mark - Validation and Compilation

- (PineScriptCompilationResult *)validateScript:(NSString *)script {
    PineScriptCompilationResult *result = [[PineScriptCompilationResult alloc] init];
    
    if (!script.length) {
        result.success = NO;
        result.errorMessage = @"Empty script";
        return result;
    }
    
    // Basic validation rules for PineScript-like syntax
    NSMutableArray *warnings = [NSMutableArray array];
    NSArray *lines = [script componentsSeparatedByString:@"\n"];
    
    BOOL hasStudyDeclaration = NO;
    BOOL hasPlotFunction = NO;
    NSInteger lineNumber = 0;
    
    for (NSString *line in lines) {
        lineNumber++;
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // Skip empty lines and comments
        if (trimmedLine.length == 0 || [trimmedLine hasPrefix:@"//"]) {
            continue;
        }
        
        // Check for required study declaration
        if ([trimmedLine hasPrefix:@"study("]) {
            hasStudyDeclaration = YES;
        }
        
        // Check for plot functions
        if ([trimmedLine hasPrefix:@"plot("]) {
            hasPlotFunction = YES;
        }
        
        // Check for syntax errors
        if ([self validateLine:trimmedLine lineNumber:lineNumber result:result]) {
            continue; // Line is valid
        } else {
            return result; // Error found
        }
    }
    
    // Check required elements
    if (!hasStudyDeclaration) {
        [warnings addObject:@"Warning: No study() declaration found. Consider adding one for better compatibility."];
    }
    
    if (!hasPlotFunction) {
        [warnings addObject:@"Warning: No plot() function found. Your indicator won't produce visible output."];
    }
    
    // Success
    result.success = YES;
    result.warnings = [warnings copy];
    result.metadata = [self extractMetadataFromScript:script];
    
    return result;
}

- (BOOL)validateLine:(NSString *)line lineNumber:(NSInteger)lineNumber result:(PineScriptCompilationResult *)result {
    // Basic syntax validation
    
    // Check for unmatched parentheses
    NSInteger openParens = 0;
    for (NSUInteger i = 0; i < line.length; i++) {
        unichar c = [line characterAtIndex:i];
        if (c == '(') openParens++;
        if (c == ')') openParens--;
        if (openParens < 0) {
            result.success = NO;
            result.errorMessage = @"Unmatched closing parenthesis";
            result.errorLine = lineNumber;
            result.errorColumn = i + 1;
            return NO;
        }
    }
    
    if (openParens > 0) {
        result.success = NO;
        result.errorMessage = @"Unmatched opening parenthesis";
        result.errorLine = lineNumber;
        return NO;
    }
    
    // Check for basic function syntax
    if ([line containsString:@"("]) {
        NSRange functionRange = [line rangeOfString:@"("];
        if (functionRange.location > 0) {
            NSString *functionName = [line substringToIndex:functionRange.location];
            NSRange spaceRange = [functionName rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:NSBackwardsSearch];
            if (spaceRange.location != NSNotFound) {
                functionName = [functionName substringFromIndex:spaceRange.location + 1];
            }
            
            // Check if it's a valid function name (alphanumeric + underscore)
            NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
            NSCharacterSet *invalidChars = [validChars invertedSet];
            if ([functionName rangeOfCharacterFromSet:invalidChars].location != NSNotFound) {
                result.success = NO;
                result.errorMessage = [NSString stringWithFormat:@"Invalid function name: %@", functionName];
                result.errorLine = lineNumber;
                return NO;
            }
        }
    }
    
    return YES;
}

- (NSDictionary *)extractMetadataFromScript:(NSString *)script {
    if (!script.length) return nil;
    
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    NSArray *lines = [script componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // Extract study declaration
        if ([trimmedLine hasPrefix:@"study("]) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"study\\s*\\(\\s*\"([^\"]+)\"" options:0 error:nil];
            NSTextCheckingResult *match = [regex firstMatchInString:trimmedLine options:0 range:NSMakeRange(0, trimmedLine.length)];
            if (match && match.numberOfRanges > 1) {
                metadata[@"name"] = [trimmedLine substringWithRange:[match rangeAtIndex:1]];
            }
            
            // Extract shorttitle
            NSRegularExpression *shortRegex = [NSRegularExpression regularExpressionWithPattern:@"shorttitle\\s*=\\s*\"([^\"]+)\"" options:0 error:nil];
            NSTextCheckingResult *shortMatch = [shortRegex firstMatchInString:trimmedLine options:0 range:NSMakeRange(0, trimmedLine.length)];
            if (shortMatch && shortMatch.numberOfRanges > 1) {
                metadata[@"shortName"] = [trimmedLine substringWithRange:[shortMatch rangeAtIndex:1]];
            }
        }
        
        // Extract description from comments
        if ([trimmedLine hasPrefix:@"// Description:"]) {
            NSString *description = [trimmedLine substringFromIndex:15];
            metadata[@"description"] = [description stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
    }
    
    return metadata.count > 0 ? [metadata copy] : nil;
}

#pragma mark - UI State Management

- (void)updateButtonStates {
    self.compileButton.enabled = (self.codeTextView.string.length > 0);
    self.testButton.enabled = (self.lastCompilationResult && self.lastCompilationResult.success);
    self.saveButton.enabled = (self.lastCompilationResult && self.lastCompilationResult.success && self.indicatorNameField.stringValue.length > 0);
}

- (void)startCompilation {
    self.compilationProgress.hidden = NO;
    [self.compilationProgress startAnimation:self];
    self.compileButton.enabled = NO;
}

- (void)finishCompilation {
    [self.compilationProgress stopAnimation:self];
    self.compilationProgress.hidden = YES;
    [self updateButtonStates];
}

- (void)highlightErrorLine:(NSInteger)lineNumber {
    NSArray *lines = [self.codeTextView.string componentsSeparatedByString:@"\n"];
    if (lineNumber <= 0 || lineNumber > lines.count) return;
    
    NSUInteger charIndex = 0;
    for (NSInteger i = 0; i < lineNumber - 1; i++) {
        charIndex += [lines[i] length] + 1; // +1 for newline
    }
    
    NSUInteger lineLength = [lines[lineNumber - 1] length];
    NSRange lineRange = NSMakeRange(charIndex, lineLength);
    
    // Highlight the error line
    [self.codeTextView.textStorage addAttribute:NSBackgroundColorAttributeName
                                          value:[NSColor systemRedColor]
                                          range:lineRange];
    
    // Scroll to error line
    [self.codeTextView scrollRangeToVisible:lineRange];
}

#pragma mark - Output Management

- (void)logOutput:(NSString *)message {
    [self appendToOutput:message withColor:[NSColor labelColor]];
}

- (void)logSuccess:(NSString *)message {
    [self appendToOutput:message withColor:[NSColor systemGreenColor]];
}

- (void)logWarning:(NSString *)message {
    [self appendToOutput:message withColor:[NSColor systemOrangeColor]];
}

- (void)logError:(NSString *)message {
    [self appendToOutput:message withColor:[NSColor systemRedColor]];
}

- (void)appendToOutput:(NSString *)message withColor:(NSColor *)color {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss";
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        
        NSString *formattedMessage = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        
        NSAttributedString *attributedMessage = [[NSAttributedString alloc]
                                               initWithString:formattedMessage
                                               attributes:@{
                                                   NSForegroundColorAttributeName: color,
                                                   NSFontAttributeName: self.outputTextView.font
                                               }];
        
        [self.outputTextView.textStorage appendAttributedString:attributedMessage];
        [self.outputTextView scrollToEndOfDocument:self];
    });
}

- (void)clearOutput {
    self.outputTextView.string = @"";
}

#pragma mark - Text View Delegate

- (void)textDidChange:(NSNotification *)notification {
    if (notification.object == self.codeTextView) {
        self.hasUnsavedChanges = YES;
        [self updateButtonStates];
        
        // Apply syntax highlighting with delay to avoid performance issues
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applySyntaxHighlighting) object:nil];
        [self performSelector:@selector(applySyntaxHighlighting) withObject:nil afterDelay:0.5];
    }
}

#pragma mark - Text Field Delegate

- (void)controlTextDidChange:(NSNotification *)notification {
    [self updateButtonStates];
}

#pragma mark - BaseWidget State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    if (self.codeTextView.string) {
        state[@"script"] = self.codeTextView.string;
    }
    if (self.indicatorNameField.stringValue) {
        state[@"indicatorName"] = self.indicatorNameField.stringValue;
    }
    if (self.descriptionField.stringValue) {
        state[@"description"] = self.descriptionField.stringValue;
    }
    if (self.currentIndicatorID) {
        state[@"currentIndicatorID"] = self.currentIndicatorID;
    }
    if (self.currentFileURL) {
        state[@"currentFileURL"] = self.currentFileURL.absoluteString;
    }
    
    state[@"hasUnsavedChanges"] = @(self.hasUnsavedChanges);
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    if (state[@"script"]) {
        [self loadScriptContent:state[@"script"] withName:state[@"indicatorName"] ?: @"Restored Script"];
    }
    if (state[@"indicatorName"]) {
        self.indicatorNameField.stringValue = state[@"indicatorName"];
    }
    if (state[@"description"]) {
        self.descriptionField.stringValue = state[@"description"];
    }
    if (state[@"currentIndicatorID"]) {
        self.currentIndicatorID = state[@"currentIndicatorID"];
    }
    if (state[@"currentFileURL"]) {
        self.currentFileURL = [NSURL URLWithString:state[@"currentFileURL"]];
    }
    
    self.hasUnsavedChanges = [state[@"hasUnsavedChanges"] boolValue];
    [self updateButtonStates];
}

@end
