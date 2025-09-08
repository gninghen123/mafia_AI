
//
//  IndicatorConfigurationDialog.m
//  TradingApp
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
    // Load XIB
    self = [super initWithWindowNibName:@"IndicatorConfigurationDialog"];
    if (self) {
        _indicator = indicator;
        _originalParameters = [indicator.parameters copy] ?: @{};
        _currentParameters = [_originalParameters mutableCopy];
        _parameterControls = [[NSMutableArray alloc] init];
        _controlValueMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self setupUI];
    [self setupParameterControls];
    [self updateAppearanceControls];
}

#pragma mark - UI Setup

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
    
    // Configure parameters scroll view
    self.parametersScrollView.hasVerticalScroller = YES;
    self.parametersScrollView.hasHorizontalScroller = NO;
    self.parametersScrollView.autohidesScrollers = YES;
}

- (NSString *)getIndicatorDescription {
    // Get description from indicator class or use default
    if ([self.indicator respondsToSelector:@selector(indicatorDescription)]) {
        return [self.indicator performSelector:@selector(indicatorDescription)];
    }
    
    return [NSString stringWithFormat:@"%@ technical indicator with configurable parameters",
            self.indicator.shortName ?: @"Technical"];
}

#pragma mark - Parameter Controls Setup

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

- (NSView *)createControlForParameter:(NSString *)parameterName
                                value:(id)value
                                rules:(NSDictionary *)rules {
    
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
    
    // Create appropriate control based on value type and rules
    NSView *control = [self createInputControlForValue:value rules:rules parameterName:parameterName];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    
    [containerView addSubview:label];
    [containerView addSubview:control];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [containerView.heightAnchor constraintEqualToConstant:30],
        [label.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:120],
        [control.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:8],
        [control.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [control.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
        [control.heightAnchor constraintEqualToConstant:24]
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

- (NSSlider *)createSliderForParameter:(NSString *)parameterName
                                 value:(NSNumber *)value
                                   min:(double)minValue
                                   max:(double)maxValue {
    
    NSSlider *slider = [[NSSlider alloc] init];
    slider.minValue = minValue;
    slider.maxValue = maxValue;
    slider.doubleValue = [value doubleValue];
    slider.target = self;
    slider.action = @selector(parameterControlChanged:);
    
    // Store mapping
    self.controlValueMap[parameterName] = slider;
    
    return slider;
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
