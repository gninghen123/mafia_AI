
//

#import "IndicatorConfigurationDialog.h"

@interface IndicatorConfigurationDialog ()
@property (nonatomic, strong, readwrite) TechnicalIndicatorBase *indicator;
@property (nonatomic, strong, readwrite) NSDictionary *originalParameters;
@property (nonatomic, strong) NSMutableArray<NSView *> *parameterControls;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *controlValueMap;
@end

@implementation IndicatorConfigurationDialog

#pragma mark - Class Methods

+ (void)showConfigurationForIndicator:(TechnicalIndicatorBase *)indicator
                         parentWindow:(NSWindow *)parentWindow
                           completion:(IndicatorConfigurationCompletionBlock)completion {
    
    IndicatorConfigurationDialog *dialog = [[self alloc] initWithIndicator:indicator];
    [dialog showAsSheetForWindow:parentWindow completion:completion];
}

#pragma mark - Initialization

- (instancetype)initWithIndicator:(TechnicalIndicatorBase *)indicator {
    // ✅ NON caricare XIB - creiamo tutto programmaticamente
    self = [super init];
    if (self) {
        _indicator = indicator;
        _originalParameters = [indicator.parameters copy] ?: @{};
        _currentParameters = [_originalParameters mutableCopy];
        _parameterControls = [[NSMutableArray alloc] init];
        _controlValueMap = [[NSMutableDictionary alloc] init];
        
        // ✅ Crea la finestra programmaticamente
        [self createWindowProgrammatically];
    }
    return self;
}

#pragma mark - Window Creation

- (void)createWindowProgrammatically {
    // ✅ Crea la finestra
    NSRect windowFrame = NSMakeRect(0, 0, 600, 400);
    NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;
    
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.title = [NSString stringWithFormat:@"Configure %@", self.indicator.shortName];
    window.minSize = NSMakeSize(600, 400);
    
    // ✅ Crea la content view principale
    NSView *contentView = [[NSView alloc] initWithFrame:windowFrame];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
    
    window.contentView = contentView;
    self.window = window;
    
    // ✅ Crea l'interfaccia
    [self createUserInterface];
}

- (void)createUserInterface {
    NSView *contentView = self.window.contentView;
    
    // ✅ 1. Crea il TabView
    self.tabView = [[NSTabView alloc] init];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.tabView];
    
    // ✅ 2. Crea i pulsanti
    [self createButtons];
    
    // ✅ 3. Crea i tab
    [self createParametersTab];
    [self createAppearanceTab];
    [self createAdvancedTab];
    
    // ✅ 4. Layout constraints
    [self setupLayoutConstraints];
    
    // ✅ 5. Setup iniziale
    [self setupUI];
    [self setupParameterControls];
    [self updateAppearanceControls];
}

- (void)createButtons {
    NSView *contentView = self.window.contentView;
    
    // ✅ Save Button
    self.saveButton = [[NSButton alloc] init];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.title = @"Save";
    self.saveButton.bezelStyle = NSBezelStyleRounded;
    self.saveButton.keyEquivalent = @"\r"; // Enter key
    self.saveButton.target = self;
    self.saveButton.action = @selector(saveAction:);
    [contentView addSubview:self.saveButton];
    
    // ✅ Cancel Button
    self.cancelButton = [[NSButton alloc] init];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cancelButton.title = @"Cancel";
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.keyEquivalent = @"\033"; // Escape key
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelAction:);
    [contentView addSubview:self.cancelButton];
    
    // ✅ Reset Button
    self.resetButton = [[NSButton alloc] init];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetButton.title = @"Reset to Defaults";
    self.resetButton.bezelStyle = NSBezelStyleRounded;
    self.resetButton.target = self;
    self.resetButton.action = @selector(resetAction:);
    [contentView addSubview:self.resetButton];
}

// Revised createParametersTab for flexible autolayout and horizontal resizing
- (void)createParametersTab {
    // ✅ Crea il tab item
    NSTabViewItem *parametersTab = [[NSTabViewItem alloc] initWithIdentifier:@"parameters"];
    parametersTab.label = @"Parameters";

    // ✅ Content view del tab
    NSView *tabView = [[NSView alloc] init];

    // ✅ Header labels
    self.indicatorNameLabel = [[NSTextField alloc] init];
    self.indicatorNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorNameLabel.editable = NO;
    self.indicatorNameLabel.bezeled = NO;
    self.indicatorNameLabel.backgroundColor = [NSColor clearColor];
    self.indicatorNameLabel.font = [NSFont boldSystemFontOfSize:16];
    [tabView addSubview:self.indicatorNameLabel];

    self.indicatorDescriptionLabel = [[NSTextField alloc] init];
    self.indicatorDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorDescriptionLabel.editable = NO;
    self.indicatorDescriptionLabel.bezeled = NO;
    self.indicatorDescriptionLabel.backgroundColor = [NSColor clearColor];
    self.indicatorDescriptionLabel.font = [NSFont systemFontOfSize:12];
    self.indicatorDescriptionLabel.textColor = [NSColor secondaryLabelColor];
    [tabView addSubview:self.indicatorDescriptionLabel];

    // ✅ Scroll view per i parametri
    self.parametersScrollView = [[NSScrollView alloc] init];
    self.parametersScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.parametersScrollView.hasVerticalScroller = YES;
    self.parametersScrollView.hasHorizontalScroller = NO;
    self.parametersScrollView.autohidesScrollers = YES;
    self.parametersScrollView.borderType = NSBezelBorder;
    [tabView addSubview:self.parametersScrollView];

    // ✅ Stack view per i controlli dei parametri
    self.parametersStackView = [[NSStackView alloc] init];
    self.parametersStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.parametersStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.parametersStackView.alignment = NSLayoutAttributeLeading;
    self.parametersStackView.spacing = 8;

    // ✅ Document view della scroll view
    NSView *documentView = [[NSView alloc] init];
    documentView.translatesAutoresizingMaskIntoConstraints = NO;
    [documentView addSubview:self.parametersStackView];
    self.parametersScrollView.documentView = documentView;

    // Ensure documentView resizes horizontally with the scrollView contentView
    documentView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [documentView.leadingAnchor constraintEqualToAnchor:self.parametersScrollView.contentView.leadingAnchor],
        [documentView.trailingAnchor constraintEqualToAnchor:self.parametersScrollView.contentView.trailingAnchor],
        [documentView.topAnchor constraintEqualToAnchor:self.parametersScrollView.contentView.topAnchor],
        [documentView.bottomAnchor constraintEqualToAnchor:self.parametersScrollView.contentView.bottomAnchor],
        [self.parametersStackView.widthAnchor constraintLessThanOrEqualToAnchor:documentView.widthAnchor constant:-16]
    ]];

    // ✅ Constraints per il content del tab
    [NSLayoutConstraint activateConstraints:@[
        // Header
        [self.indicatorNameLabel.topAnchor constraintEqualToAnchor:tabView.topAnchor constant:16],
        [self.indicatorNameLabel.leadingAnchor constraintEqualToAnchor:tabView.leadingAnchor constant:16],
        [self.indicatorNameLabel.trailingAnchor constraintEqualToAnchor:tabView.trailingAnchor constant:-16],

        [self.indicatorDescriptionLabel.topAnchor constraintEqualToAnchor:self.indicatorNameLabel.bottomAnchor constant:4],
        [self.indicatorDescriptionLabel.leadingAnchor constraintEqualToAnchor:tabView.leadingAnchor constant:16],
        [self.indicatorDescriptionLabel.trailingAnchor constraintEqualToAnchor:tabView.trailingAnchor constant:-16],

        // Scroll view
        [self.parametersScrollView.topAnchor constraintEqualToAnchor:self.indicatorDescriptionLabel.bottomAnchor constant:16],
        [self.parametersScrollView.leadingAnchor constraintEqualToAnchor:tabView.leadingAnchor constant:16],
        [self.parametersScrollView.trailingAnchor constraintEqualToAnchor:tabView.trailingAnchor constant:-16],
        [self.parametersScrollView.bottomAnchor constraintEqualToAnchor:tabView.bottomAnchor constant:-16],

        // Stack view nella document view
        [self.parametersStackView.topAnchor constraintEqualToAnchor:documentView.topAnchor constant:8],
        [self.parametersStackView.leadingAnchor constraintEqualToAnchor:documentView.leadingAnchor constant:8],
        [self.parametersStackView.trailingAnchor constraintEqualToAnchor:documentView.trailingAnchor constant:-8],
        [self.parametersStackView.bottomAnchor constraintLessThanOrEqualToAnchor:documentView.bottomAnchor constant:-8]
        // No rigid width constraint, allow horizontal expansion
    ]];

    parametersTab.view = tabView;
    [self.tabView addTabViewItem:parametersTab];
}

- (void)createAppearanceTab {
    NSTabViewItem *appearanceTab = [[NSTabViewItem alloc] initWithIdentifier:@"appearance"];
    appearanceTab.label = @"Appearance";
    
    NSView *tabView = [[NSView alloc] init];
    
    // ✅ Color Well
    NSTextField *colorLabel = [self createLabel:@"Color:"];
    self.colorWell = [[NSColorWell alloc] init];
    self.colorWell.translatesAutoresizingMaskIntoConstraints = NO;
    self.colorWell.target = self;
    self.colorWell.action = @selector(colorChanged:);
    
    // ✅ Line Width
    NSTextField *lineWidthLabelText = [self createLabel:@"Line Width:"];
    self.lineWidthSlider = [[NSSlider alloc] init];
    self.lineWidthSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.lineWidthSlider.minValue = 0.5;
    self.lineWidthSlider.maxValue = 5.0;
    self.lineWidthSlider.target = self;
    self.lineWidthSlider.action = @selector(lineWidthChanged:);
    
    self.lineWidthLabel = [[NSTextField alloc] init];
    self.lineWidthLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.lineWidthLabel.editable = NO;
    self.lineWidthLabel.bezeled = NO;
    self.lineWidthLabel.backgroundColor = [NSColor clearColor];
    self.lineWidthLabel.alignment = NSTextAlignmentCenter;
    
    // ✅ Visibility Toggle
    self.visibilityToggle = [[NSButton alloc] init];
    self.visibilityToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.visibilityToggle.title = @"Visible";
    [self.visibilityToggle setButtonType:NSButtonTypeSwitch];
    self.visibilityToggle.target = self;
    self.visibilityToggle.action = @selector(visibilityToggled:);
    
    // ✅ Add to view
    [tabView addSubview:colorLabel];
    [tabView addSubview:self.colorWell];
    [tabView addSubview:lineWidthLabelText];
    [tabView addSubview:self.lineWidthSlider];
    [tabView addSubview:self.lineWidthLabel];
    [tabView addSubview:self.visibilityToggle];
    
    // ✅ Layout
    [NSLayoutConstraint activateConstraints:@[
        // Color
        [colorLabel.topAnchor constraintEqualToAnchor:tabView.topAnchor constant:20],
        [colorLabel.leadingAnchor constraintEqualToAnchor:tabView.leadingAnchor constant:20],
        [self.colorWell.leadingAnchor constraintEqualToAnchor:colorLabel.trailingAnchor constant:16],
        [self.colorWell.centerYAnchor constraintEqualToAnchor:colorLabel.centerYAnchor],
        
        // Line Width
        [lineWidthLabelText.topAnchor constraintEqualToAnchor:colorLabel.bottomAnchor constant:20],
        [lineWidthLabelText.leadingAnchor constraintEqualToAnchor:tabView.leadingAnchor constant:20],
        [self.lineWidthSlider.leadingAnchor constraintEqualToAnchor:lineWidthLabelText.trailingAnchor constant:16],
        [self.lineWidthSlider.centerYAnchor constraintEqualToAnchor:lineWidthLabelText.centerYAnchor],
        [self.lineWidthSlider.widthAnchor constraintEqualToConstant:150],
        [self.lineWidthLabel.leadingAnchor constraintEqualToAnchor:self.lineWidthSlider.trailingAnchor constant:8],
        [self.lineWidthLabel.centerYAnchor constraintEqualToAnchor:self.lineWidthSlider.centerYAnchor],
        [self.lineWidthLabel.widthAnchor constraintEqualToConstant:50],
        
        // Visibility
        [self.visibilityToggle.topAnchor constraintEqualToAnchor:lineWidthLabelText.bottomAnchor constant:20],
        [self.visibilityToggle.leadingAnchor constraintEqualToAnchor:tabView.leadingAnchor constant:20]
    ]];
    
    appearanceTab.view = tabView;
    [self.tabView addTabViewItem:appearanceTab];
}

- (void)createAdvancedTab {
    NSTabViewItem *advancedTab = [[NSTabViewItem alloc] initWithIdentifier:@"advanced"];
    advancedTab.label = @"Advanced";
    
    NSView *tabView = [[NSView alloc] init];
    
    // ✅ Notes
    NSTextField *notesLabel = [self createLabel:@"Notes:"];
    
    NSScrollView *notesScrollView = [[NSScrollView alloc] init];
    notesScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    notesScrollView.hasVerticalScroller = YES;
    notesScrollView.hasHorizontalScroller = NO;
    notesScrollView.borderType = NSBezelBorder;
    
    self.notesTextView = [[NSTextView alloc] init];
    self.notesTextView.font = [NSFont systemFontOfSize:12];
    notesScrollView.documentView = self.notesTextView;
    
    [tabView addSubview:notesLabel];
    [tabView addSubview:notesScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [notesLabel.topAnchor constraintEqualToAnchor:tabView.topAnchor constant:20],
        [notesLabel.leadingAnchor constraintEqualToAnchor:tabView.leadingAnchor constant:20],
        
        [notesScrollView.topAnchor constraintEqualToAnchor:notesLabel.bottomAnchor constant:8],
        [notesScrollView.leadingAnchor constraintEqualToAnchor:tabView.leadingAnchor constant:20],
        [notesScrollView.trailingAnchor constraintEqualToAnchor:tabView.trailingAnchor constant:-20],
        [notesScrollView.bottomAnchor constraintEqualToAnchor:tabView.bottomAnchor constant:-20]
    ]];
    
    advancedTab.view = tabView;
    [self.tabView addTabViewItem:advancedTab];
}

- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.stringValue = text;
    label.editable = NO;
    label.bezeled = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:13];
    return label;
}


// Revised constraints for flexible autolayout and resizable window
- (void)setupLayoutConstraints {
    NSView *contentView = self.window.contentView;

    // Tab view should fill the available space above the buttons
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16],
        [self.tabView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [self.tabView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.saveButton.topAnchor constant:-20]
    ]];

    // Save Button
    [NSLayoutConstraint activateConstraints:@[
        [self.saveButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [self.saveButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-16],
        [self.saveButton.widthAnchor constraintEqualToConstant:80]
    ]];

    // Cancel Button
    [NSLayoutConstraint activateConstraints:@[
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor constant:-8],
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:self.saveButton.bottomAnchor],
        [self.cancelButton.widthAnchor constraintEqualToConstant:80]
    ]];

    // Reset Button
    [NSLayoutConstraint activateConstraints:@[
        [self.resetButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [self.resetButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-16],
        [self.resetButton.widthAnchor constraintEqualToConstant:120]
    ]];
}

#pragma mark - UI Setup (resto del codice invariato)

- (void)setupUI {
    // Set window title
    self.window.title = [NSString stringWithFormat:@"Configure %@", self.indicator.shortName];
    
    // Setup basic info
    self.indicatorNameLabel.stringValue = self.indicator.displayName ?: @"Unknown Indicator";
    self.indicatorDescriptionLabel.stringValue = [self getIndicatorDescription];
    
    // Setup appearance controls
    self.colorWell.color = self.indicator.displayColor ?: [NSColor systemBlueColor];
    self.lineWidthSlider.doubleValue = self.indicator.lineWidth;
    self.lineWidthLabel.stringValue = [NSString stringWithFormat:@"%.1f pt", self.indicator.lineWidth];
    self.visibilityToggle.state = self.indicator.isVisible ? NSControlStateValueOn : NSControlStateValueOff;
}

- (NSString *)getIndicatorDescription {
    // Get description from indicator class or use default
    if ([self.indicator respondsToSelector:@selector(indicatorDescription)]) {
        return [self.indicator performSelector:@selector(indicatorDescription)];
    }
    
    return [NSString stringWithFormat:@"%@ technical indicator with configurable parameters",
            self.indicator.shortName ?: @"Technical"];
}

#pragma mark - Parameter Controls Setup (resto del codice già esistente)

- (void)setupParameterControls {
    // Clear existing controls
    for (NSView *control in self.parameterControls) {
        [control removeFromSuperview];
    }
    [self.parameterControls removeAllObjects];
    [self.controlValueMap removeAllObjects];
    
    // Get parameter validation rules
    NSDictionary *validationRules = nil;
    if ([self.indicator.class respondsToSelector:@selector(parameterValidationRules)]) {
        validationRules = [self.indicator.class parameterValidationRules];
    }
    
    // Create controls for each parameter
    [self.currentParameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        NSView *controlView = [self createControlForParameter:key
                                                        value:value
                                                        rules:validationRules[key]];
        if (controlView) {
            [self.parametersStackView addArrangedSubview:controlView];
            [self.parameterControls addObject:controlView];
        }
    }];
}

// ✅ RESTO DEI METODI INVARIATI
// (createControlForParameter, createInputControlForValue, actions, etc.)

- (NSView *)createControlForParameter:(NSString *)parameterName
                                value:(id)value
                                rules:(NSDictionary *)rules {
    
    // ✅ COSTANTI PER LAYOUT CONTROLLI PARAMETRI
    const CGFloat kControlRowHeight = 32;
    const CGFloat kLabelWidth = 120;
    const CGFloat kControlSpacing = 12;
    const CGFloat kControlHeight = 24;
    
    // Create container view
    NSView *containerView = [[NSView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create label
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.stringValue = [self friendlyNameForParameter:parameterName];
    label.editable = NO;
    label.bezeled = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:13];
    label.alignment = NSTextAlignmentRight; // ✅ Right align per layout pulito
    
    // Create appropriate control based on value type and rules
    NSView *control = [self createInputControlForValue:value rules:rules parameterName:parameterName];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    
    [containerView addSubview:label];
    [containerView addSubview:control];
    
    // ✅ LAYOUT CONSTRAINTS OTTIMIZZATI
    [NSLayoutConstraint activateConstraints:@[
        // Container row height consistente
        [containerView.heightAnchor constraintEqualToConstant:kControlRowHeight],
        
        // Label - fixed width, right aligned, centered vertically
        [label.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:kLabelWidth],
        
        // Control - fills remaining space, centered vertically, fixed height
        [control.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:kControlSpacing],
        [control.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [control.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
        [control.heightAnchor constraintEqualToConstant:kControlHeight]
    ]];
    
    return containerView;
}

- (NSView *)createInputControlForValue:(id)value
                                 rules:(NSDictionary *)rules
                         parameterName:(NSString *)parameterName {
    
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *numValue = (NSNumber *)value;
        
        // Check if it should be a slider based on rules
        if (rules[@"min"] && rules[@"max"]) {
            return [self createSliderForParameter:parameterName
                                             value:numValue
                                               min:[rules[@"min"] doubleValue]
                                               max:[rules[@"max"] doubleValue]];
        } else {
            return [self createNumberFieldForParameter:parameterName value:numValue];
        }
    } else if ([value isKindOfClass:[NSString class]]) {
        return [self createTextFieldForParameter:parameterName value:(NSString *)value];
    } else if ([value isKindOfClass:[NSArray class]]) {
        return [self createPopUpForParameter:parameterName
                                       value:value
                                     options:rules[@"options"]];
    } else {
        // Default to text field
        return [self createTextFieldForParameter:parameterName
                                            value:[value description]];
    }
}

// Slider + manual value input field in a stack view
- (NSView *)createSliderForParameter:(NSString *)parameterName
                              value:(NSNumber *)value
                                min:(double)minValue
                                max:(double)maxValue {
    NSSlider *slider = [[NSSlider alloc] init];
    slider.minValue = minValue;
    slider.maxValue = maxValue;
    slider.doubleValue = [value doubleValue];
    slider.target = self;
    slider.action = @selector(parameterControlChanged:);

    // Manual input text field
    NSTextField *textField = [[NSTextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.stringValue = [value stringValue];
    textField.alignment = NSTextAlignmentCenter;
    textField.controlSize = NSControlSizeSmall;
    [textField setBezeled:YES];
    [textField setEditable:YES];
    textField.target = self;
    textField.action = @selector(parameterControlChanged:);

    // Stack view to hold slider and text field horizontally
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:slider];
    [stack addArrangedSubview:textField];

    // Optionally constrain text field width for neatness
    [textField.widthAnchor constraintEqualToConstant:60].active = YES;

    // Store mapping: store both controls in a dictionary
    self.controlValueMap[parameterName] = @{ @"slider": slider, @"textField": textField };

    return stack;
}

- (NSTextField *)createNumberFieldForParameter:(NSString *)parameterName value:(NSNumber *)value {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.stringValue = [value stringValue];
    textField.target = self;
    textField.action = @selector(parameterControlChanged:);
    
    // Store mapping
    self.controlValueMap[parameterName] = textField;
    
    return textField;
}

- (NSTextField *)createTextFieldForParameter:(NSString *)parameterName value:(NSString *)value {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.stringValue = value ?: @"";
    textField.target = self;
    textField.action = @selector(parameterControlChanged:);
    
    // Store mapping
    self.controlValueMap[parameterName] = textField;
    
    return textField;
}

- (NSPopUpButton *)createPopUpForParameter:(NSString *)parameterName
                                     value:(id)value
                                   options:(NSArray *)options {
    
    NSPopUpButton *popup = [[NSPopUpButton alloc] init];
    
    if (options) {
        for (id option in options) {
            [popup addItemWithTitle:[option description]];
        }
        
        // Select current value
        NSInteger index = [options indexOfObject:value];
        if (index != NSNotFound) {
            [popup selectItemAtIndex:index];
        }
    }
    
    popup.target = self;
    popup.action = @selector(parameterControlChanged:);
    
    // Store mapping
    self.controlValueMap[parameterName] = popup;
    
    return popup;
}

#pragma mark - Helper Methods

- (NSString *)friendlyNameForParameter:(NSString *)parameterName {
    // Convert camelCase to friendly names
    NSMutableString *friendly = [[NSMutableString alloc] init];
    
    for (NSUInteger i = 0; i < parameterName.length; i++) {
        unichar c = [parameterName characterAtIndex:i];
        
        if (i == 0) {
            [friendly appendString:[[NSString stringWithCharacters:&c length:1] uppercaseString]];
        } else if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c]) {
            [friendly appendString:@" "];
            [friendly appendString:[NSString stringWithCharacters:&c length:1]];
        } else {
            [friendly appendString:[NSString stringWithCharacters:&c length:1]];
        }
    }
    
    return [friendly copy];
}

- (void)updateAppearanceControls {
    self.colorWell.color = self.indicator.displayColor ?: [NSColor systemBlueColor];
    self.lineWidthSlider.doubleValue = self.indicator.lineWidth;
    self.lineWidthLabel.stringValue = [NSString stringWithFormat:@"%.1f pt", self.indicator.lineWidth];
    self.visibilityToggle.state = self.indicator.isVisible ? NSControlStateValueOn : NSControlStateValueOff;
}

#pragma mark - Dialog Management

- (void)showAsSheetForWindow:(NSWindow *)parentWindow completion:(IndicatorConfigurationCompletionBlock)completion {
    self.completionBlock = completion;
    
    [parentWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        BOOL saved = (returnCode == NSModalResponseOK);
        NSDictionary *parameters = saved ? self.currentParameters : nil;
        
        if (completion) {
            completion(saved, parameters);
        }
    }];
}

#pragma mark - Actions

- (IBAction)saveAction:(NSButton *)sender {
    NSError *error;
    if (![self validateParameters:&error]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Invalid Parameters";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return;
    }
    
    [self updateParametersFromControls];
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)cancelAction:(NSButton *)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)resetAction:(NSButton *)sender {
    [self resetParametersToDefaults];
    [self setupParameterControls];
    [self updateAppearanceControls];
}

- (IBAction)colorChanged:(NSColorWell *)sender {
    // Update indicator color (will be applied on save)
}

- (IBAction)lineWidthChanged:(NSSlider *)sender {
    self.lineWidthLabel.stringValue = [NSString stringWithFormat:@"%.1f pt", sender.doubleValue];
}

- (IBAction)visibilityToggled:(NSButton *)sender {
    // Update visibility (will be applied on save)
}

- (IBAction)parameterControlChanged:(id)sender {
    // Sync slider and textField for slider+field combos
    [self.controlValueMap enumerateKeysAndObjectsUsingBlock:^(NSString *paramName, id obj, BOOL *stop) {
        if ([obj isKindOfClass:[NSDictionary class]]) {
            NSSlider *slider = obj[@"slider"];
            NSTextField *textField = obj[@"textField"];
            if (sender == slider) {
                // Update textField to match slider
                textField.stringValue = [NSString stringWithFormat:@"%.2f", slider.doubleValue];
            } else if (sender == textField) {
                // Update slider to match textField, if possible
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                NSNumber *num = [formatter numberFromString:textField.stringValue];
                if (num) {
                    slider.doubleValue = [num doubleValue];
                }
            }
        }
    }];
    // Parameter values will be collected on save
    // Could add real-time preview here if needed
}

#pragma mark - Parameter Management

- (void)updateParametersFromControls {
    NSMutableDictionary *updatedParams = [[NSMutableDictionary alloc] init];
    
    [self.controlValueMap enumerateKeysAndObjectsUsingBlock:^(NSString *paramName, NSView *control, BOOL *stop) {
        id value = [self extractValueFromControl:control];
        if (value) {
            updatedParams[paramName] = value;
        }
    }];
    
    self.currentParameters = [updatedParams copy];
    
    // Also update appearance properties
    // These would be applied to the indicator by the caller
}

- (id)extractValueFromControl:(NSView *)control {
    if ([control isKindOfClass:[NSDictionary class]]) {
        // Our slider+textField combo
        NSSlider *slider = [(NSDictionary *)control objectForKey:@"slider"];
        if (slider) {
            return @(slider.doubleValue);
        }
        return nil;
    }
    if ([control isKindOfClass:[NSTextField class]]) {
        NSTextField *textField = (NSTextField *)control;
        NSString *stringValue = textField.stringValue;
        
        // Try to convert to number if possible
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        NSNumber *numberValue = [formatter numberFromString:stringValue];
        return numberValue ?: stringValue;
        
    } else if ([control isKindOfClass:[NSSlider class]]) {
        NSSlider *slider = (NSSlider *)control;
        return @(slider.doubleValue);
        
    } else if ([control isKindOfClass:[NSPopUpButton class]]) {
        NSPopUpButton *popup = (NSPopUpButton *)control;
        return popup.selectedItem.title;
    }
    
    return nil;
}

- (void)resetParametersToDefaults {
    if ([self.indicator.class respondsToSelector:@selector(defaultParameters)]) {
        NSDictionary *defaults = [self.indicator.class defaultParameters];
        self.currentParameters = [defaults mutableCopy];
    } else {
        self.currentParameters = [self.originalParameters mutableCopy];
    }
}

- (BOOL)validateParameters:(NSError **)error {
    // Basic validation - could be enhanced
    for (NSString *key in self.currentParameters) {
        id value = self.currentParameters[key];
        
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] == 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"IndicatorConfiguration"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Parameter '%@' cannot be empty", key]}];
            }
            return NO;
        }
    }
    
    return YES;
}

@end
