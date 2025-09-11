//
//  IndicatorConfigurationDialog.m
//  TradingApp
//
//  ✅ VERSIONE CON BINDINGS REAL-TIME
//

#import "IndicatorConfigurationDialog.h"


@interface LineWidthToStringTransformer : NSValueTransformer
@end


#pragma mark - ParametersProxy KVO-compliant class
@interface ParametersProxy : NSObject
@property (nonatomic, strong) NSMutableDictionary *storage;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSArray *)allKeys;
@end

@implementation ParametersProxy
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        _storage = [dict mutableCopy];
    }
    return self;
}
- (id)valueForKey:(NSString *)key { return self.storage[key]; }
- (void)setValue:(id)value forKey:(NSString *)key {
    [self willChangeValueForKey:key];
    self.storage[key] = value;
    [self didChangeValueForKey:key];
}
- (NSArray *)allKeys { return self.storage.allKeys; }

// Subscripting support
- (id)objectForKeyedSubscript:(id)key {
    return self.storage[key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
    [self willChangeValueForKey:(NSString *)key];
    self.storage[key] = obj;
    [self didChangeValueForKey:(NSString *)key];
}
@end

@interface IndicatorConfigurationDialog ()
@property (nonatomic, strong, readwrite) TechnicalIndicatorBase *indicator;
@property (nonatomic, strong, readwrite) NSDictionary *originalParameters;
@property (nonatomic, strong) NSMutableArray<NSView *> *parameterControls;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *controlValueMap;

// ✅ NUOVO: Property per KVO sui parametri
@property (nonatomic, strong) ParametersProxy *parametersProxy;
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
    self = [super init];
    if (self) {
        _indicator = indicator;
        _originalParameters = [indicator.parameters copy] ?: @{};
        _currentParameters = [_originalParameters mutableCopy];
        _parameterControls = [[NSMutableArray alloc] init];
        _controlValueMap = [[NSMutableDictionary alloc] init];
        
        // ✅ CREA PROXY PER PARAMETERS BINDING
        [self setupParametersProxy];
        
        // ✅ SETUP KVO per refresh automatico del renderer
        [self setupKVOObservation];
        
        [self createWindowProgrammatically];
    }
    return self;
}

- (void)dealloc {
    // ✅ Rimuovi observers KVO
    [self removeKVOObservation];
}

 #pragma mark - KVO & Bindings Setup

- (void)setupParametersProxy {
    // ✅ Crea un proxy dictionary per i parametri che supporta KVO
    self.parametersProxy = [[ParametersProxy alloc] initWithDictionary:self.currentParameters];
    // 👉 Setup KVO observers for each parameter key
    [self setupParametersProxyObservers];
}

// Add KVO for all keys in parametersProxy
- (void)setupParametersProxyObservers {
    for (NSString *key in self.parametersProxy.allKeys) {
        [self.parametersProxy addObserver:self
                               forKeyPath:key
                                  options:NSKeyValueObservingOptionNew
                                  context:nil];
    }
}

- (void)setupKVOObservation {
    // ✅ Osserva le properties appearance dell'indicatore per refresh automatico
    [self.indicator addObserver:self
                     forKeyPath:@"displayColor"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
    
    [self.indicator addObserver:self
                     forKeyPath:@"lineWidth"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
    
    [self.indicator addObserver:self
                     forKeyPath:@"isVisible"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
}

- (void)removeKVOObservation {
    @try {
        [self.indicator removeObserver:self forKeyPath:@"displayColor"];
        [self.indicator removeObserver:self forKeyPath:@"lineWidth"];
        [self.indicator removeObserver:self forKeyPath:@"isVisible"];
    }
    @catch (NSException *exception) {
        NSLog(@"⚠️ KVO removal error: %@", exception);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    // Handle KVO for parameter proxy (parametersProxy)
    if (object == self.parametersProxy) {
        NSLog(@"🔄 Parameter '%@' changed to %@", keyPath, change[NSKeyValueChangeNewKey]);
        // Update indicator immediately
        [self syncParametersFromProxyToIndicator];
        [self invalidateIndicatorRendering];
        return;
    }
    NSLog(@"🔄 KVO Change detected: %@ = %@", keyPath, change[NSKeyValueChangeNewKey]);
    // ✅ Quando cambia un parametro o appearance, forza il refresh del renderer
    [self invalidateIndicatorRendering];
}

- (void)invalidateIndicatorRendering {
    // ✅ Notifica il sistema che l'indicatore è cambiato
    dispatch_async(dispatch_get_main_queue(), ^{
        // Segna che serve re-rendering
        if ([self.indicator respondsToSelector:@selector(setNeedsRendering:)]) {
            [self.indicator performSelector:@selector(setNeedsRendering:) withObject:@YES];
        }
        
        // Invalida il calcolo se necessario
        if ([self.indicator respondsToSelector:@selector(setIsCalculated:)]) {
            self.indicator.isCalculated = NO;
        }
        
        NSLog(@"🎨 Real-time indicator refresh triggered");
    });
}

#pragma mark - Window Creation (stesso codice di prima)

- (void)createWindowProgrammatically {
    NSRect windowFrame = NSMakeRect(0, 0, 600, 500);
    NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;
    
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.title = [NSString stringWithFormat:@"Configure %@", self.indicator.shortName];
    window.minSize = NSMakeSize(550, 450);
    window.maxSize = NSMakeSize(800, 700);
    
    NSView *contentView = [[NSView alloc] initWithFrame:windowFrame];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
    
    window.contentView = contentView;
    self.window = window;
    
    [self createUserInterface];
}

- (void)createUserInterface {
    NSView *contentView = self.window.contentView;
    
    self.tabView = [[NSTabView alloc] init];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.tabView];
    
    [self createButtons];
    [self createParametersTab];
    [self createAppearanceTab];
    [self createAdvancedTab];
    [self setupLayoutConstraints];
    
    // ✅ Setup UI e bindings
    [self setupUI];
    [self setupParameterControls];
    [self setupBindings]; // ✅ NUOVO!
}

#pragma mark - Bindings Setup

- (void)setupBindings {
    NSLog(@"🔗 Setting up real-time bindings...");
    
    // ✅ 1. BIND APPEARANCE CONTROLS DIRETTAMENTE ALL'INDICATORE
    [self.colorWell bind:@"value"
                toObject:self.indicator
             withKeyPath:@"displayColor"
                 options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];
    
    [self.lineWidthSlider bind:@"value"
                      toObject:self.indicator
                   withKeyPath:@"lineWidth"
                       options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];
    
    [self.visibilityToggle bind:@"value"
                       toObject:self.indicator
                    withKeyPath:@"isVisible"
                        options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];
    
    // ✅ 2. BIND LABEL DEL LINE WIDTH
    [self.lineWidthLabel bind:@"value"
                     toObject:self.indicator
                  withKeyPath:@"lineWidth"
                      options:@{NSValueTransformerNameBindingOption: @"LineWidthToStringTransformer"}];
    
    // ✅ 3. BIND PARAMETER CONTROLS AI PARAMETERS
    [self setupParameterBindings];
    
    NSLog(@"✅ Real-time bindings configured");
}

- (void)setupParameterBindings {
    // ✅ Bind ogni controllo parametro al proxy parameters
    [self.controlValueMap enumerateKeysAndObjectsUsingBlock:^(NSString *paramName, NSView *control, BOOL *stop) {
        
        NSString *keyPath = paramName;
        NSDictionary *options = @{NSContinuouslyUpdatesValueBindingOption: @YES};
        
        if ([control isKindOfClass:[NSSlider class]]) {
            [control bind:@"value" toObject:self.parametersProxy withKeyPath:keyPath options:options];
            NSLog(@"🔗 Bound slider '%@' to parameters.%@", paramName, keyPath);
            
        } else if ([control isKindOfClass:[NSTextField class]]) {
            [control bind:@"value" toObject:self.parametersProxy withKeyPath:keyPath options:options];
            NSLog(@"🔗 Bound textField '%@' to parameters.%@", paramName, keyPath);
            
        } else if ([control isKindOfClass:[NSPopUpButton class]]) {
            [control bind:@"selectedObject" toObject:self.parametersProxy withKeyPath:keyPath options:options];
            NSLog(@"🔗 Bound popUp '%@' to parameters.%@", paramName, keyPath);
        }
    }];
}

#pragma mark - Parameter Controls Setup (semplificato)

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
#pragma mark - Parameter Controls Creation

- (NSView *)createControlForParameter:(NSString *)parameterName
                                value:(id)value
                                rules:(NSDictionary *)rules {
    
    // Create a simple text field for now
    NSTextField *textField = [[NSTextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.stringValue = [value description] ?: @"";
    
    // Store mapping
    self.controlValueMap[parameterName] = textField;
    
    return textField;
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
    
    // Store mapping for binding setup
    self.controlValueMap[parameterName] = popup;
    
    return popup;
}

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
- (NSSlider *)createSliderForParameter:(NSString *)parameterName
                                 value:(NSNumber *)value
                                   min:(double)minValue
                                   max:(double)maxValue {
    
    NSSlider *slider = [[NSSlider alloc] init];
    slider.minValue = minValue;
    slider.maxValue = maxValue;
    slider.doubleValue = [value doubleValue];
    
    // ✅ NON SERVE PIÙ TARGET/ACTION - useremo bindings!
    // slider.target = self;
    // slider.action = @selector(parameterControlChanged:);
    
    // ✅ PERIODI DEVONO ESSERE NUMERI INTERI
    BOOL isPeriodParameter = [parameterName.lowercaseString containsString:@"period"] ||
                            [parameterName.lowercaseString containsString:@"length"] ||
                            [parameterName.lowercaseString containsString:@"window"] ||
                            [parameterName.lowercaseString containsString:@"span"] ||
                            [parameterName.lowercaseString containsString:@"bars"];
    
    if (isPeriodParameter) {
        slider.numberOfTickMarks = (NSInteger)(maxValue - minValue) + 1;
        slider.allowsTickMarkValuesOnly = YES;
        slider.tickMarkPosition = NSTickMarkPositionBelow;
    }
    
    // Store mapping for binding setup
    self.controlValueMap[parameterName] = slider;
    
    return slider;
}

- (NSTextField *)createNumberFieldForParameter:(NSString *)parameterName value:(NSNumber *)value {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.stringValue = [value stringValue];
    
    // ✅ NON SERVE PIÙ TARGET/ACTION
    // Store mapping for binding setup
    self.controlValueMap[parameterName] = textField;
    
    return textField;
}

- (NSTextField *)createTextFieldForParameter:(NSString *)parameterName value:(NSString *)value {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.stringValue = value ?: @"";
    
    // Store mapping for binding setup
    self.controlValueMap[parameterName] = textField;
    
    return textField;
}

#pragma mark - Actions (semplificati)

- (IBAction)saveAction:(NSButton *)sender {
    // ✅ CON I BINDINGS NON SERVE PIÙ RACCOGLIERE MANUALMENTE I VALORI!
    // I parametri sono già stati applicati in real-time
    
    // ✅ Sincronizza i parameters proxy con l'indicatore
    [self syncParametersFromProxyToIndicator];
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)cancelAction:(NSButton *)sender {
    // ✅ Ripristina i valori originali
    [self restoreOriginalValues];
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)resetAction:(NSButton *)sender {
    [self resetParametersToDefaults];
    [self updateBindingsFromDefaults];
}

#pragma mark - Parameter Sync

- (void)syncParametersFromProxyToIndicator {
    NSLog(@"🔄 Syncing parameters from proxy to indicator");
    
    // ✅ Applica i parametri dal proxy all'indicatore
    NSMutableDictionary *cleanedParams = [[NSMutableDictionary alloc] init];
    
    // Filtra i parametri, escludendo quelli di appearance
    for (NSString *key in self.parametersProxy.allKeys) {
        if (![key isEqualToString:@"displayColor"] &&
            ![key isEqualToString:@"lineWidth"] &&
            ![key isEqualToString:@"isVisible"]) {
            cleanedParams[key] = self.parametersProxy[key];
        }
    }
    
    // Applica i parametri all'indicatore
    self.indicator.parameters = [cleanedParams copy];
    
    NSLog(@"✅ Parameters synced: %@", cleanedParams);
}

- (void)restoreOriginalValues {
    NSLog(@"🔄 Restoring original indicator values");
    
    // ✅ Ripristina i valori originali dell'indicatore
    self.indicator.parameters = self.originalParameters;
    
    // Ripristina appearance values se presenti negli originalParameters
    if (self.originalParameters[@"displayColor"]) {
        self.indicator.displayColor = self.originalParameters[@"displayColor"];
    }
    if (self.originalParameters[@"lineWidth"]) {
        self.indicator.lineWidth = [self.originalParameters[@"lineWidth"] floatValue];
    }
    if (self.originalParameters[@"isVisible"]) {
        self.indicator.isVisible = [self.originalParameters[@"isVisible"] boolValue];
    }
}

- (void)updateBindingsFromDefaults {
    if ([self.indicator.class respondsToSelector:@selector(defaultParameters)]) {
        NSDictionary *defaults = [self.indicator.class defaultParameters];
        
        // ✅ Aggiorna il proxy con i default
        [self.parametersProxy setValuesForKeysWithDictionary:defaults];
        
        // ✅ Aggiorna appearance controls
        if (defaults[@"displayColor"]) {
            self.indicator.displayColor = defaults[@"displayColor"];
        }
        if (defaults[@"lineWidth"]) {
            self.indicator.lineWidth = [defaults[@"lineWidth"] floatValue];
        }
        if (defaults[@"isVisible"]) {
            self.indicator.isVisible = [defaults[@"isVisible"] boolValue];
        }
    }
}

- (void)createParametersTab {
    NSTabViewItem *parametersTab = [[NSTabViewItem alloc] initWithIdentifier:@"parameters"];
    parametersTab.label = @"Parameters";
    
    NSView *tabContentView = [[NSView alloc] init];
    
    // Header labels
    self.indicatorNameLabel = [[NSTextField alloc] init];
    self.indicatorNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorNameLabel.editable = NO;
    self.indicatorNameLabel.bezeled = NO;
    self.indicatorNameLabel.backgroundColor = [NSColor clearColor];
    self.indicatorNameLabel.font = [NSFont boldSystemFontOfSize:16];
    [tabContentView addSubview:self.indicatorNameLabel];
    
    self.indicatorDescriptionLabel = [[NSTextField alloc] init];
    self.indicatorDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorDescriptionLabel.editable = NO;
    self.indicatorDescriptionLabel.bezeled = NO;
    self.indicatorDescriptionLabel.backgroundColor = [NSColor clearColor];
    self.indicatorDescriptionLabel.font = [NSFont systemFontOfSize:12];
    self.indicatorDescriptionLabel.textColor = [NSColor secondaryLabelColor];
    [tabContentView addSubview:self.indicatorDescriptionLabel];
    
    // Scroll view per i parametri
    self.parametersScrollView = [[NSScrollView alloc] init];
    self.parametersScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.parametersScrollView.hasVerticalScroller = YES;
    self.parametersScrollView.hasHorizontalScroller = NO;
    self.parametersScrollView.autohidesScrollers = YES;
    self.parametersScrollView.borderType = NSBezelBorder;
    [tabContentView addSubview:self.parametersScrollView];
    
    // Stack view per i controlli dei parametri
    self.parametersStackView = [[NSStackView alloc] init];
    self.parametersStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.parametersStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.parametersStackView.alignment = NSLayoutAttributeLeading;
    self.parametersStackView.spacing = 8;
    
    // Document view della scroll view
    NSView *documentView = [[NSView alloc] init];
    documentView.translatesAutoresizingMaskIntoConstraints = NO;
    [documentView addSubview:self.parametersStackView];
    self.parametersScrollView.documentView = documentView;
    
    // ✅ CONSTRAINTS OTTIMIZZATI - Pattern a costanti
    const CGFloat kMargin = 16;
    const CGFloat kHeaderSpacing = 4;
    const CGFloat kContentSpacing = 16;
    const CGFloat kScrollPadding = 8;
    
    [NSLayoutConstraint activateConstraints:@[
        // Header labels - layout verticale pulito
        [self.indicatorNameLabel.topAnchor constraintEqualToAnchor:tabContentView.topAnchor constant:kMargin],
        [self.indicatorNameLabel.leadingAnchor constraintEqualToAnchor:tabContentView.leadingAnchor constant:kMargin],
        [self.indicatorNameLabel.trailingAnchor constraintEqualToAnchor:tabContentView.trailingAnchor constant:-kMargin],
        
        [self.indicatorDescriptionLabel.topAnchor constraintEqualToAnchor:self.indicatorNameLabel.bottomAnchor constant:kHeaderSpacing],
        [self.indicatorDescriptionLabel.leadingAnchor constraintEqualToAnchor:tabContentView.leadingAnchor constant:kMargin],
        [self.indicatorDescriptionLabel.trailingAnchor constraintEqualToAnchor:tabContentView.trailingAnchor constant:-kMargin],
        
        // Scroll view - riempie il resto del tab
        [self.parametersScrollView.topAnchor constraintEqualToAnchor:self.indicatorDescriptionLabel.bottomAnchor constant:kContentSpacing],
        [self.parametersScrollView.leadingAnchor constraintEqualToAnchor:tabContentView.leadingAnchor constant:kMargin],
        [self.parametersScrollView.trailingAnchor constraintEqualToAnchor:tabContentView.trailingAnchor constant:-kMargin],
        [self.parametersScrollView.bottomAnchor constraintEqualToAnchor:tabContentView.bottomAnchor constant:-kMargin],
        
        // Stack view nella document view - layout ottimizzato per scrolling
        [self.parametersStackView.topAnchor constraintEqualToAnchor:documentView.topAnchor constant:kScrollPadding],
        [self.parametersStackView.leadingAnchor constraintEqualToAnchor:documentView.leadingAnchor constant:kScrollPadding],
        [self.parametersStackView.trailingAnchor constraintEqualToAnchor:documentView.trailingAnchor constant:-kScrollPadding],
        [self.parametersStackView.bottomAnchor constraintLessThanOrEqualToAnchor:documentView.bottomAnchor constant:-kScrollPadding],
        
        // ✅ CHIAVE: width constraint corretto per evitare overflow orizzontale
        [self.parametersStackView.widthAnchor constraintEqualToAnchor:self.parametersScrollView.contentView.widthAnchor constant:-(2 * kScrollPadding)]
    ]];
    
    parametersTab.view = tabContentView;
    [self.tabView addTabViewItem:parametersTab];
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

- (void)updateParametersFromControls {
    // Placeholder - implement if not using bindings
    NSLog(@"updateParametersFromControls called");
}

- (void)createAppearanceTab {
    NSTabViewItem *appearanceTab = [[NSTabViewItem alloc] initWithIdentifier:@"appearance"];
    appearanceTab.label = @"Appearance";
    
    NSView *tabContentView = [[NSView alloc] init];
    
    // ✅ COSTANTI PER LAYOUT CONSISTENTE
    const CGFloat kMargin = 20;
    const CGFloat kRowHeight = 32;
    const CGFloat kRowSpacing = 16;
    const CGFloat kLabelWidth = 100;
    const CGFloat kControlSpacing = 16;
    const CGFloat kSliderWidth = 150;
    const CGFloat kValueLabelWidth = 50;
    
    // ✅ Color Well Row
    NSTextField *colorLabel = [self createLabel:@"Color:"];
    self.colorWell = [[NSColorWell alloc] init];
    self.colorWell.translatesAutoresizingMaskIntoConstraints = NO;
    self.colorWell.target = self;
    self.colorWell.action = @selector(colorChanged:);
    
    // ✅ Line Width Row
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
    self.lineWidthLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    
    // ✅ Visibility Toggle
    self.visibilityToggle = [[NSButton alloc] init];
    self.visibilityToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.visibilityToggle.title = @"Visible";
    [self.visibilityToggle setButtonType:NSButtonTypeSwitch];
    self.visibilityToggle.target = self;
    self.visibilityToggle.action = @selector(visibilityToggled:);
    
    // ✅ Add views
    [tabContentView addSubview:colorLabel];
    [tabContentView addSubview:self.colorWell];
    [tabContentView addSubview:lineWidthLabelText];
    [tabContentView addSubview:self.lineWidthSlider];
    [tabContentView addSubview:self.lineWidthLabel];
    [tabContentView addSubview:self.visibilityToggle];
    
    // ✅ CONSTRAINTS PULITI E ALLINEATI
    [NSLayoutConstraint activateConstraints:@[
        // Color Row - baseline alignment
        [colorLabel.topAnchor constraintEqualToAnchor:tabContentView.topAnchor constant:kMargin],
        [colorLabel.leadingAnchor constraintEqualToAnchor:tabContentView.leadingAnchor constant:kMargin],
        [colorLabel.widthAnchor constraintEqualToConstant:kLabelWidth],
        [colorLabel.heightAnchor constraintEqualToConstant:kRowHeight],
        
        [self.colorWell.leadingAnchor constraintEqualToAnchor:colorLabel.trailingAnchor constant:kControlSpacing],
        [self.colorWell.centerYAnchor constraintEqualToAnchor:colorLabel.centerYAnchor],
        [self.colorWell.widthAnchor constraintEqualToConstant:44], // Standard color well size
        [self.colorWell.heightAnchor constraintEqualToConstant:24],
        
        // Line Width Row - tri-part layout
        [lineWidthLabelText.topAnchor constraintEqualToAnchor:colorLabel.bottomAnchor constant:kRowSpacing],
        [lineWidthLabelText.leadingAnchor constraintEqualToAnchor:tabContentView.leadingAnchor constant:kMargin],
        [lineWidthLabelText.widthAnchor constraintEqualToConstant:kLabelWidth],
        [lineWidthLabelText.heightAnchor constraintEqualToConstant:kRowHeight],
        
        [self.lineWidthSlider.leadingAnchor constraintEqualToAnchor:lineWidthLabelText.trailingAnchor constant:kControlSpacing],
        [self.lineWidthSlider.centerYAnchor constraintEqualToAnchor:lineWidthLabelText.centerYAnchor],
        [self.lineWidthSlider.widthAnchor constraintEqualToConstant:kSliderWidth],
        
        [self.lineWidthLabel.leadingAnchor constraintEqualToAnchor:self.lineWidthSlider.trailingAnchor constant:8],
        [self.lineWidthLabel.centerYAnchor constraintEqualToAnchor:self.lineWidthSlider.centerYAnchor],
        [self.lineWidthLabel.widthAnchor constraintEqualToConstant:kValueLabelWidth],
        
        // Visibility Toggle - single control
        [self.visibilityToggle.topAnchor constraintEqualToAnchor:lineWidthLabelText.bottomAnchor constant:kRowSpacing],
        [self.visibilityToggle.leadingAnchor constraintEqualToAnchor:tabContentView.leadingAnchor constant:kMargin],
        [self.visibilityToggle.heightAnchor constraintEqualToConstant:kRowHeight]
    ]];
    
    appearanceTab.view = tabContentView;
    [self.tabView addTabViewItem:appearanceTab];
}

- (void)createAdvancedTab {
    NSTabViewItem *advancedTab = [[NSTabViewItem alloc] initWithIdentifier:@"advanced"];
    advancedTab.label = @"Advanced";
    
    NSView *tabContentView = [[NSView alloc] init];
    
    // ✅ COSTANTI LAYOUT
    const CGFloat kMargin = 20;
    const CGFloat kLabelHeight = 20;
    const CGFloat kContentSpacing = 8;
    
    // ✅ Notes Label
    NSTextField *notesLabel = [self createLabel:@"Notes:"];
    [tabContentView addSubview:notesLabel];
    
    // ✅ Notes Scroll View & Text View
    NSScrollView *notesScrollView = [[NSScrollView alloc] init];
    notesScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    notesScrollView.hasVerticalScroller = YES;
    notesScrollView.hasHorizontalScroller = NO;
    notesScrollView.autohidesScrollers = YES;
    notesScrollView.borderType = NSBezelBorder;
    
    self.notesTextView = [[NSTextView alloc] init];
    self.notesTextView.font = [NSFont systemFontOfSize:12];
    self.notesTextView.textColor = [NSColor textColor];
    self.notesTextView.backgroundColor = [NSColor textBackgroundColor];
    notesScrollView.documentView = self.notesTextView;
    
    [tabContentView addSubview:notesScrollView];
    
    // ✅ CONSTRAINTS OTTIMIZZATI
    [NSLayoutConstraint activateConstraints:@[
        // Notes label - fixed height, top aligned
        [notesLabel.topAnchor constraintEqualToAnchor:tabContentView.topAnchor constant:kMargin],
        [notesLabel.leadingAnchor constraintEqualToAnchor:tabContentView.leadingAnchor constant:kMargin],
        [notesLabel.trailingAnchor constraintEqualToAnchor:tabContentView.trailingAnchor constant:-kMargin],
        [notesLabel.heightAnchor constraintEqualToConstant:kLabelHeight],
        
        // Notes text view - fills remaining space
        [notesScrollView.topAnchor constraintEqualToAnchor:notesLabel.bottomAnchor constant:kContentSpacing],
        [notesScrollView.leadingAnchor constraintEqualToAnchor:tabContentView.leadingAnchor constant:kMargin],
        [notesScrollView.trailingAnchor constraintEqualToAnchor:tabContentView.trailingAnchor constant:-kMargin],
        [notesScrollView.bottomAnchor constraintEqualToAnchor:tabContentView.bottomAnchor constant:-kMargin]
    ]];
    
    advancedTab.view = tabContentView;
    [self.tabView addTabViewItem:advancedTab];
}

- (void)setupLayoutConstraints {
    NSView *contentView = self.window.contentView;
    
    // ✅ COSTANTI PER LAYOUT PULITO
    const CGFloat kWindowMargin = 16;
    const CGFloat kButtonHeight = 32;
    const CGFloat kButtonWidth = 80;
    const CGFloat kResetButtonWidth = 120;
    const CGFloat kButtonSpacing = 8;
    const CGFloat kTabButtonSpacing = 20;
    
    // ✅ CONSTRAINTS STRUTTURATI E ROBUSTI
    [NSLayoutConstraint activateConstraints:@[
        // Tab view - occupa la maggior parte della finestra
        [self.tabView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:kWindowMargin],
        [self.tabView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:kWindowMargin],
        [self.tabView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-kWindowMargin],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.saveButton.topAnchor constant:-kTabButtonSpacing],
        
        // Bottom buttons row - layout da destra a sinistra
        // Save button (primary action - rightmost)
        [self.saveButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-kWindowMargin],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-kWindowMargin],
        [self.saveButton.widthAnchor constraintEqualToConstant:kButtonWidth],
        [self.saveButton.heightAnchor constraintEqualToConstant:kButtonHeight],
        
        // Cancel button (secondary action - a sinistra del Save)
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-kWindowMargin],
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor constant:-kButtonSpacing],
        [self.cancelButton.widthAnchor constraintEqualToConstant:kButtonWidth],
        [self.cancelButton.heightAnchor constraintEqualToConstant:kButtonHeight],
        
        // Reset button (utility action - leftmost)
        [self.resetButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-kWindowMargin],
        [self.resetButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:kWindowMargin],
        [self.resetButton.widthAnchor constraintEqualToConstant:kResetButtonWidth],
        [self.resetButton.heightAnchor constraintEqualToConstant:kButtonHeight]
    ]];
}
#pragma mark - UI Setup

- (void)setupUI {
    // Set window title
    self.window.title = [NSString stringWithFormat:@"Configure %@", self.indicator.shortName];
    
    // Setup basic info
    self.indicatorNameLabel.stringValue = self.indicator.displayName ?: @"Unknown Indicator";
    self.indicatorDescriptionLabel.stringValue = [self getIndicatorDescription];
    
    // ✅ CARICA I VALORI REALI DELL'INDICATORE - non i default
    NSLog(@"🔍 Loading real indicator values - Color: %@, Width: %.1f, Visible: %@",
          self.indicator.displayColor, self.indicator.lineWidth, self.indicator.isVisible ? @"YES" : @"NO");
    
    // Setup appearance controls con i valori REALI
    NSColor *actualColor = self.indicator.displayColor;
    if (!actualColor) {
        // Se non c'è colore impostato, cerca nei parametri
        if (self.indicator.parameters[@"color"]) {
            actualColor = self.indicator.parameters[@"color"];
        } else if (self.indicator.parameters[@"displayColor"]) {
            actualColor = self.indicator.parameters[@"displayColor"];
        } else {
            actualColor = [NSColor systemOrangeColor]; // Default visibile
        }
    }
    
    CGFloat actualLineWidth = self.indicator.lineWidth;
    if (actualLineWidth <= 0) {
        // Se non c'è width impostato, cerca nei parametri
        if (self.indicator.parameters[@"lineWidth"]) {
            actualLineWidth = [self.indicator.parameters[@"lineWidth"] floatValue];
        } else {
            actualLineWidth = 2.0; // Default ragionevole
        }
    }
    
    self.colorWell.color = actualColor;
    self.lineWidthSlider.doubleValue = actualLineWidth;
    self.lineWidthLabel.stringValue = [NSString stringWithFormat:@"%.1f pt", actualLineWidth];
    self.visibilityToggle.state = self.indicator.isVisible ? @"YES" : @"NO";
    
    NSLog(@"✅ Setup appearance controls - Color: %@, Width: %.1f", actualColor, actualLineWidth);
}

- (NSString *)getIndicatorDescription {
    // Get description from indicator class or use default
    if ([self.indicator respondsToSelector:@selector(indicatorDescription)]) {
        return [self.indicator performSelector:@selector(indicatorDescription)];
    }
    
    return [NSString stringWithFormat:@"%@ technical indicator with configurable parameters",
            self.indicator.shortName ?: @"Technical"];
}
#pragma mark - Dialog Management

- (void)showAsSheetForWindow:(NSWindow *)parentWindow completion:(IndicatorConfigurationCompletionBlock)completion {
    self.completionBlock = completion;
    
    [parentWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        BOOL saved = (returnCode == NSModalResponseOK);
        
        if (completion) {
            // ✅ CON I BINDINGS, I PARAMETRI SONO GIÀ APPLICATI!
            completion(saved, saved ? self.indicator.parameters : nil);
        }
    }];
}

#pragma mark - UI Setup & Layout (stesso codice di prima ma senza gli action methods)

- (void)createButtons {
    NSView *contentView = self.window.contentView;
    
    self.saveButton = [[NSButton alloc] init];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.title = @"Save";
    self.saveButton.bezelStyle = NSBezelStyleRounded;
    self.saveButton.keyEquivalent = @"\r";
    self.saveButton.target = self;
    self.saveButton.action = @selector(saveAction:);
    [contentView addSubview:self.saveButton];
    
    self.cancelButton = [[NSButton alloc] init];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cancelButton.title = @"Cancel";
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.keyEquivalent = @"\033";
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelAction:);
    [contentView addSubview:self.cancelButton];
    
    self.resetButton = [[NSButton alloc] init];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetButton.title = @"Reset to Defaults";
    self.resetButton.bezelStyle = NSBezelStyleRounded;
    self.resetButton.target = self;
    self.resetButton.action = @selector(resetAction:);
    [contentView addSubview:self.resetButton];
}

// ✅ RESTO DEI METODI createParametersTab, createAppearanceTab, createAdvancedTab, setupLayoutConstraints
// (identici alla versione precedente - li ometto per brevità)

#pragma mark - Value Transformer per Line Width

+ (void)initialize {
    if (self == [IndicatorConfigurationDialog class]) {
        // ✅ Registra un transformer per convertire lineWidth in stringa
        [NSValueTransformer setValueTransformer:[[LineWidthToStringTransformer alloc] init]
                                        forName:@"LineWidthToStringTransformer"];
    }
}

@end

#pragma mark - Value Transformer

@implementation LineWidthToStringTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [NSString stringWithFormat:@"%.1f pt", [value floatValue]];
    }
    return @"0.0 pt";
}

@end
