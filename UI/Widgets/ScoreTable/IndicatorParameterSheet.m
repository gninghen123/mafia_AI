//
//  IndicatorParameterSheet.m
//  TradingApp
//
//  Parameter Configuration Sheet Implementation
//

#import "IndicatorParameterSheet.h"

@interface IndicatorParameterSheet ()

@property (nonatomic, strong) NSPanel *panel;
@property (nonatomic, weak) NSWindow *parentWindow; // ✅ AGGIUNTO
@property (nonatomic, strong) IndicatorConfig *indicator;
@property (nonatomic, strong) NSMutableDictionary *workingParameters; // Editable copy
@property (nonatomic, strong) NSMutableArray<NSView *> *parameterViews; // Keep references
@property (nonatomic, copy) void(^completionHandler)(BOOL saved);

// UI Components
@property (nonatomic, strong) NSStackView *stackView;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *cancelButton;

@end

@implementation IndicatorParameterSheet

#pragma mark - Class Method

+ (instancetype)showSheetForIndicator:(IndicatorConfig *)indicator
                             onWindow:(NSWindow *)window
                           completion:(void(^)(BOOL saved))completion {
    
    IndicatorParameterSheet *sheet = [[IndicatorParameterSheet alloc] init];
    sheet.indicator = indicator;
    sheet.parentWindow = window; // ✅ SALVATO
    sheet.completionHandler = completion;
    sheet.workingParameters = [indicator.parameters mutableCopy] ?: [NSMutableDictionary dictionary];
    sheet.parameterViews = [NSMutableArray array];
    
    [sheet createPanel];
    [sheet buildUIForIndicatorType:indicator.indicatorType];
    [sheet showSheetOnWindow:window];
    
    return sheet; // ✅ RETURN INSTANCE
}

#pragma mark - Panel Setup

- (void)createPanel {
    self.panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 500, 400)
                                            styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
    
    self.panel.title = [NSString stringWithFormat:@"Configure %@", self.indicator.displayName];
    
    // Main stack view (vertical)
    self.stackView = [[NSStackView alloc] init];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.stackView.alignment = NSLayoutAttributeLeading;
    self.stackView.spacing = 15;
    self.stackView.edgeInsets = NSEdgeInsetsMake(20, 20, 20, 20);
    
    [self.panel.contentView addSubview:self.stackView];
    
    // Constraints for stack view
    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.topAnchor constraintEqualToAnchor:self.panel.contentView.topAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.panel.contentView.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.panel.contentView.trailingAnchor],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.panel.contentView.bottomAnchor constant:-60]
    ]];
    
    // Bottom buttons
    self.cancelButton = [[NSButton alloc] init];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cancelButton setTitle:@"Cancel"];
    [self.cancelButton setTarget:self];
    [self.cancelButton setAction:@selector(cancel:)];
    [self.cancelButton setBezelStyle:NSBezelStyleRounded];
    [self.panel.contentView addSubview:self.cancelButton];
    
    self.saveButton = [[NSButton alloc] init];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.saveButton setTitle:@"Save"];
    [self.saveButton setTarget:self];
    [self.saveButton setAction:@selector(save:)];
    [self.saveButton setBezelStyle:NSBezelStyleRounded];
    self.saveButton.keyEquivalent = @"\r";
    [self.panel.contentView addSubview:self.saveButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor constant:-10],
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:self.panel.contentView.bottomAnchor constant:-20],
        [self.cancelButton.widthAnchor constraintEqualToConstant:80],
        
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.panel.contentView.trailingAnchor constant:-20],
        [self.saveButton.bottomAnchor constraintEqualToAnchor:self.panel.contentView.bottomAnchor constant:-20],
        [self.saveButton.widthAnchor constraintEqualToConstant:80]
    ]];
}

#pragma mark - Dynamic UI Builder

- (void)buildUIForIndicatorType:(NSString *)type {
    // Add description label
    [self addDescriptionLabel];
    
    // Build parameter fields based on indicator type
    if ([type isEqualToString:@"DollarVolume"]) {
        [self buildDollarVolumeUI];
        
    } else if ([type isEqualToString:@"AscendingLows"]) {
        [self buildAscendingLowsUI];
        
    } else if ([type isEqualToString:@"BearTrap"]) {
        [self buildBearTrapUI];
        
    } else if ([type isEqualToString:@"UNR"]) {
        [self buildUNRUI];
        
    } else if ([type isEqualToString:@"PriceVsMA"]) {
        [self buildPriceVsMAUI];
        
    } else if ([type isEqualToString:@"VolumeSpike"]) {
        [self buildVolumeSpikeUI];
        
    } else {
        // Generic fallback
        [self buildGenericUI];
    }
}

- (void)addDescriptionLabel {
    NSTextField *descLabel = [[NSTextField alloc] init];
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    descLabel.stringValue = [self descriptionForIndicatorType:self.indicator.indicatorType];
    descLabel.editable = NO;
    descLabel.bordered = NO;
    descLabel.backgroundColor = [NSColor clearColor];
    descLabel.textColor = [NSColor secondaryLabelColor];
    descLabel.font = [NSFont systemFontOfSize:11];
    descLabel.maximumNumberOfLines = 0;
    descLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    [self.stackView addArrangedSubview:descLabel];
    [descLabel.widthAnchor constraintEqualToConstant:460].active = YES;
}

#pragma mark - Indicator-Specific UI Builders

- (void)buildDollarVolumeUI {
    // DollarVolume has NO parameters (it just filters on close*volume)
    NSTextField *infoLabel = [[NSTextField alloc] init];
    infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    infoLabel.stringValue = @"This indicator has no configurable parameters.\n\nIt calculates: Close × Volume";
    infoLabel.editable = NO;
    infoLabel.bordered = NO;
    infoLabel.backgroundColor = [NSColor clearColor];
    infoLabel.font = [NSFont systemFontOfSize:12];
    infoLabel.maximumNumberOfLines = 0;
    infoLabel.alignment = NSTextAlignmentCenter;
    
    [self.stackView addArrangedSubview:infoLabel];
    [infoLabel.widthAnchor constraintEqualToConstant:460].active = YES;
}

- (void)buildAscendingLowsUI {
    // Parameters: lookbackPeriod (default: 10)
    [self addIntegerField:@"Lookback Period"
                      key:@"lookbackPeriod"
             defaultValue:10
                  minValue:2
                  maxValue:50
                 helpText:@"Number of bars to check for ascending lows"];
}

- (void)buildBearTrapUI {
    // Parameters: supportPeriod (default: 20)
    [self addIntegerField:@"Support Period"
                      key:@"supportPeriod"
             defaultValue:20
                  minValue:5
                  maxValue:100
                 helpText:@"Number of bars to identify support level"];
}

- (void)buildUNRUI {
    // Parameters: volumeThreshold, priceChangeThreshold
    [self addDoubleField:@"Volume Threshold (multiplier)"
                     key:@"volumeThreshold"
            defaultValue:2.0
                minValue:1.0
                maxValue:10.0
                helpText:@"Volume must be this many times the average"];
    
    [self addDoubleField:@"Price Change Threshold (%)"
                     key:@"priceChangeThreshold"
            defaultValue:5.0
                minValue:1.0
                maxValue:20.0
                helpText:@"Minimum price change percentage required"];
}

- (void)buildPriceVsMAUI {
    // Parameters: maType, maPeriod, pricePoints, condition
    
    // MA Type (SMA or EMA)
    [self addPopupField:@"MA Type"
                    key:@"maType"
                options:@[@"SMA", @"EMA"]
           defaultValue:@"EMA"
               helpText:@"Type of moving average"];
    
    // MA Period
    [self addIntegerField:@"MA Period"
                      key:@"maPeriod"
             defaultValue:10
                  minValue:2
                  maxValue:200
                 helpText:@"Period for moving average calculation"];
    
    // Price Points (checkboxes for low/close/open/high)
    [self addCheckboxGroup:@"Price Points to Check"
                       key:@"pricePoints"
                   options:@[@"low", @"close", @"open", @"high"]
              defaultValue:@[@"close"]
                  helpText:@"Which price points to compare with MA"];
    
    // Condition (above or below)
    [self addPopupField:@"Condition"
                    key:@"condition"
                options:@[@"above", @"below"]
           defaultValue:@"above"
               helpText:@"Price should be above or below MA"];
}

- (void)buildVolumeSpikeUI {
    // Parameters: volumeMAPeriod (default: 20)
    [self addIntegerField:@"Volume MA Period"
                      key:@"volumeMAPeriod"
             defaultValue:20
                  minValue:5
                  maxValue:100
                 helpText:@"Period for volume moving average"];
}

- (void)buildGenericUI {
    // Fallback: show raw JSON
    NSTextField *jsonLabel = [[NSTextField alloc] init];
    jsonLabel.translatesAutoresizingMaskIntoConstraints = NO;
    jsonLabel.stringValue = @"Raw Parameters (JSON):";
    jsonLabel.editable = NO;
    jsonLabel.bordered = NO;
    jsonLabel.backgroundColor = [NSColor clearColor];
    jsonLabel.font = [NSFont boldSystemFontOfSize:12];
    
    NSTextView *jsonView = [[NSTextView alloc] init];
    jsonView.string = [self.workingParameters description];
    jsonView.editable = NO;
    jsonView.font = [NSFont fontWithName:@"Menlo" size:11];
    
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = jsonView;
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    
    [self.stackView addArrangedSubview:jsonLabel];
    [self.stackView addArrangedSubview:scrollView];
    
    [scrollView.widthAnchor constraintEqualToConstant:460].active = YES;
    [scrollView.heightAnchor constraintEqualToConstant:150].active = YES;
}

#pragma mark - UI Component Builders

- (void)addIntegerField:(NSString *)label
                    key:(NSString *)key
           defaultValue:(NSInteger)defaultValue
               minValue:(NSInteger)minValue
               maxValue:(NSInteger)maxValue
               helpText:(NSString *)helpText {
    
    NSView *row = [self createParameterRow];
    
    // Label
    NSTextField *labelField = [[NSTextField alloc] init];
    labelField.translatesAutoresizingMaskIntoConstraints = NO;
    labelField.stringValue = [label stringByAppendingString:@":"];
    labelField.editable = NO;
    labelField.bordered = NO;
    labelField.backgroundColor = [NSColor clearColor];
    labelField.alignment = NSTextAlignmentRight;
    [row addSubview:labelField];
    
    // Text field
    NSTextField *textField = [[NSTextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.integerValue = [self.workingParameters[key] integerValue] ?: defaultValue;
    textField.placeholderString = [NSString stringWithFormat:@"%ld", (long)defaultValue];
    [row addSubview:textField];
    
    // Store reference with key
    textField.identifier = key;
    [self.parameterViews addObject:textField];
    
    // Help text
    NSTextField *helpField = [[NSTextField alloc] init];
    helpField.translatesAutoresizingMaskIntoConstraints = NO;
    helpField.stringValue = helpText;
    helpField.editable = NO;
    helpField.bordered = NO;
    helpField.backgroundColor = [NSColor clearColor];
    helpField.textColor = [NSColor secondaryLabelColor];
    helpField.font = [NSFont systemFontOfSize:10];
    [row addSubview:helpField];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [labelField.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [labelField.topAnchor constraintEqualToAnchor:row.topAnchor],
        [labelField.widthAnchor constraintEqualToConstant:180],
        
        [textField.leadingAnchor constraintEqualToAnchor:labelField.trailingAnchor constant:10],
        [textField.centerYAnchor constraintEqualToAnchor:labelField.centerYAnchor],
        [textField.widthAnchor constraintEqualToConstant:100],
        
        [helpField.topAnchor constraintEqualToAnchor:textField.bottomAnchor constant:3],
        [helpField.leadingAnchor constraintEqualToAnchor:textField.leadingAnchor],
        [helpField.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [helpField.bottomAnchor constraintEqualToAnchor:row.bottomAnchor]
    ]];
    
    [self.stackView addArrangedSubview:row];
    [row.widthAnchor constraintEqualToConstant:460].active = YES;
}

- (void)addDoubleField:(NSString *)label
                   key:(NSString *)key
          defaultValue:(double)defaultValue
              minValue:(double)minValue
              maxValue:(double)maxValue
              helpText:(NSString *)helpText {
    
    NSView *row = [self createParameterRow];
    
    // Label
    NSTextField *labelField = [[NSTextField alloc] init];
    labelField.translatesAutoresizingMaskIntoConstraints = NO;
    labelField.stringValue = [label stringByAppendingString:@":"];
    labelField.editable = NO;
    labelField.bordered = NO;
    labelField.backgroundColor = [NSColor clearColor];
    labelField.alignment = NSTextAlignmentRight;
    [row addSubview:labelField];
    
    // Text field
    NSTextField *textField = [[NSTextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.doubleValue = [self.workingParameters[key] doubleValue] ?: defaultValue;
    textField.placeholderString = [NSString stringWithFormat:@"%.2f", defaultValue];
    [row addSubview:textField];
    
    textField.identifier = key;
    [self.parameterViews addObject:textField];
    
    // Help text
    NSTextField *helpField = [[NSTextField alloc] init];
    helpField.translatesAutoresizingMaskIntoConstraints = NO;
    helpField.stringValue = helpText;
    helpField.editable = NO;
    helpField.bordered = NO;
    helpField.backgroundColor = [NSColor clearColor];
    helpField.textColor = [NSColor secondaryLabelColor];
    helpField.font = [NSFont systemFontOfSize:10];
    [row addSubview:helpField];
    
    [NSLayoutConstraint activateConstraints:@[
        [labelField.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [labelField.topAnchor constraintEqualToAnchor:row.topAnchor],
        [labelField.widthAnchor constraintEqualToConstant:180],
        
        [textField.leadingAnchor constraintEqualToAnchor:labelField.trailingAnchor constant:10],
        [textField.centerYAnchor constraintEqualToAnchor:labelField.centerYAnchor],
        [textField.widthAnchor constraintEqualToConstant:100],
        
        [helpField.topAnchor constraintEqualToAnchor:textField.bottomAnchor constant:3],
        [helpField.leadingAnchor constraintEqualToAnchor:textField.leadingAnchor],
        [helpField.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [helpField.bottomAnchor constraintEqualToAnchor:row.bottomAnchor]
    ]];
    
    [self.stackView addArrangedSubview:row];
    [row.widthAnchor constraintEqualToConstant:460].active = YES;
}

- (void)addPopupField:(NSString *)label
                  key:(NSString *)key
              options:(NSArray<NSString *> *)options
         defaultValue:(NSString *)defaultValue
             helpText:(NSString *)helpText {
    
    NSView *row = [self createParameterRow];
    
    // Label
    NSTextField *labelField = [[NSTextField alloc] init];
    labelField.translatesAutoresizingMaskIntoConstraints = NO;
    labelField.stringValue = [label stringByAppendingString:@":"];
    labelField.editable = NO;
    labelField.bordered = NO;
    labelField.backgroundColor = [NSColor clearColor];
    labelField.alignment = NSTextAlignmentRight;
    [row addSubview:labelField];
    
    // Popup button
    NSPopUpButton *popup = [[NSPopUpButton alloc] init];
    popup.translatesAutoresizingMaskIntoConstraints = NO;
    [popup addItemsWithTitles:options];
    
    NSString *currentValue = self.workingParameters[key] ?: defaultValue;
    [popup selectItemWithTitle:currentValue];
    
    popup.identifier = key;
    [self.parameterViews addObject:popup];
    [row addSubview:popup];
    
    // Help text
    NSTextField *helpField = [[NSTextField alloc] init];
    helpField.translatesAutoresizingMaskIntoConstraints = NO;
    helpField.stringValue = helpText;
    helpField.editable = NO;
    helpField.bordered = NO;
    helpField.backgroundColor = [NSColor clearColor];
    helpField.textColor = [NSColor secondaryLabelColor];
    helpField.font = [NSFont systemFontOfSize:10];
    [row addSubview:helpField];
    
    [NSLayoutConstraint activateConstraints:@[
        [labelField.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [labelField.topAnchor constraintEqualToAnchor:row.topAnchor],
        [labelField.widthAnchor constraintEqualToConstant:180],
        
        [popup.leadingAnchor constraintEqualToAnchor:labelField.trailingAnchor constant:10],
        [popup.centerYAnchor constraintEqualToAnchor:labelField.centerYAnchor],
        [popup.widthAnchor constraintEqualToConstant:150],
        
        [helpField.topAnchor constraintEqualToAnchor:popup.bottomAnchor constant:3],
        [helpField.leadingAnchor constraintEqualToAnchor:popup.leadingAnchor],
        [helpField.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [helpField.bottomAnchor constraintEqualToAnchor:row.bottomAnchor]
    ]];
    
    [self.stackView addArrangedSubview:row];
    [row.widthAnchor constraintEqualToConstant:460].active = YES;
}

- (void)addCheckboxGroup:(NSString *)label
                     key:(NSString *)key
                 options:(NSArray<NSString *> *)options
            defaultValue:(NSArray<NSString *> *)defaultValue
                helpText:(NSString *)helpText {
    
    NSView *row = [self createParameterRow];
    
    // Label
    NSTextField *labelField = [[NSTextField alloc] init];
    labelField.translatesAutoresizingMaskIntoConstraints = NO;
    labelField.stringValue = [label stringByAppendingString:@":"];
    labelField.editable = NO;
    labelField.bordered = NO;
    labelField.backgroundColor = [NSColor clearColor];
    labelField.alignment = NSTextAlignmentRight;
    [row addSubview:labelField];
    
    // Checkbox container
    NSStackView *checkboxStack = [[NSStackView alloc] init];
    checkboxStack.translatesAutoresizingMaskIntoConstraints = NO;
    checkboxStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    checkboxStack.alignment = NSLayoutAttributeLeading;
    checkboxStack.spacing = 5;
    
    NSArray *currentValue = self.workingParameters[key] ?: defaultValue;
    
    for (NSString *option in options) {
        NSButton *checkbox = [[NSButton alloc] init];
        [checkbox setButtonType:NSButtonTypeSwitch];
        checkbox.title = option;
        checkbox.state = [currentValue containsObject:option] ? NSControlStateValueOn : NSControlStateValueOff;
        checkbox.identifier = [NSString stringWithFormat:@"%@.%@", key, option];
        [self.parameterViews addObject:checkbox];
        [checkboxStack addArrangedSubview:checkbox];
    }
    
    [row addSubview:checkboxStack];
    
    // Help text
    NSTextField *helpField = [[NSTextField alloc] init];
    helpField.translatesAutoresizingMaskIntoConstraints = NO;
    helpField.stringValue = helpText;
    helpField.editable = NO;
    helpField.bordered = NO;
    helpField.backgroundColor = [NSColor clearColor];
    helpField.textColor = [NSColor secondaryLabelColor];
    helpField.font = [NSFont systemFontOfSize:10];
    [row addSubview:helpField];
    
    [NSLayoutConstraint activateConstraints:@[
        [labelField.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [labelField.topAnchor constraintEqualToAnchor:row.topAnchor],
        [labelField.widthAnchor constraintEqualToConstant:180],
        
        [checkboxStack.leadingAnchor constraintEqualToAnchor:labelField.trailingAnchor constant:10],
        [checkboxStack.topAnchor constraintEqualToAnchor:row.topAnchor],
        
        [helpField.topAnchor constraintEqualToAnchor:checkboxStack.bottomAnchor constant:3],
        [helpField.leadingAnchor constraintEqualToAnchor:checkboxStack.leadingAnchor],
        [helpField.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [helpField.bottomAnchor constraintEqualToAnchor:row.bottomAnchor]
    ]];
    
    [self.stackView addArrangedSubview:row];
    [row.widthAnchor constraintEqualToConstant:460].active = YES;
}

- (NSView *)createParameterRow {
    NSView *row = [[NSView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    return row;
}

#pragma mark - Descriptions

- (NSString *)descriptionForIndicatorType:(NSString *)type {
    NSDictionary *descriptions = @{
        @"DollarVolume": @"Filters stocks by dollar volume (Close × Volume). No parameters needed.",
        @"AscendingLows": @"Identifies uptrends by checking if recent lows are consecutively ascending.",
        @"BearTrap": @"Detects bear trap patterns where price breaks below support and quickly recovers.",
        @"UNR": @"Unusual News/Rally - Identifies unusual volume spikes combined with significant price movement.",
        @"PriceVsMA": @"Compares price position relative to a moving average for trend confirmation.",
        @"VolumeSpike": @"Detects volume spikes above the average volume for increased trading activity."
    };
    
    return descriptions[type] ?: @"Configure indicator parameters below.";
}

#pragma mark - Sheet Presentation

- (void)showSheetOnWindow:(NSWindow *)window {
    [window beginSheet:self.panel completionHandler:^(NSModalResponse returnCode) {
        // Sheet closed
    }];
}

#pragma mark - Actions

- (IBAction)save:(id)sender {
    NSLog(@"💾 Save button clicked");
    
    // Collect values from UI
    [self collectParametersFromUI];
    
    // Update indicator with new parameters
    self.indicator.parameters = [self.workingParameters copy];
    
    NSLog(@"✅ Saved parameters for %@: %@", self.indicator.displayName, self.indicator.parameters);
    
    // Close sheet using saved parentWindow
    if (self.parentWindow) {
        [self.parentWindow endSheet:self.panel returnCode:NSModalResponseOK];
    } else {
        NSLog(@"⚠️ No parent window, closing panel directly");
        [self.panel close];
    }
    
    // Call completion
    if (self.completionHandler) {
        self.completionHandler(YES);
    }
}

- (IBAction)cancel:(id)sender {
    NSLog(@"❌ Cancel button clicked");
    
    // Close sheet using saved parentWindow
    if (self.parentWindow) {
        [self.parentWindow endSheet:self.panel returnCode:NSModalResponseCancel];
    } else {
        NSLog(@"⚠️ No parent window, closing panel directly");
        [self.panel close];
    }
    
    // Call completion
    if (self.completionHandler) {
        self.completionHandler(NO);
    }
}

#pragma mark - Parameter Collection

- (void)collectParametersFromUI {
    for (NSView *view in self.parameterViews) {
        NSString *identifier = view.identifier;
        
        if (!identifier || identifier.length == 0) continue;
        
        if ([view isKindOfClass:[NSTextField class]]) {
            NSTextField *textField = (NSTextField *)view;
            
            // Check if it's an integer or double field
            if ([identifier isEqualToString:@"lookbackPeriod"] ||
                [identifier isEqualToString:@"supportPeriod"] ||
                [identifier isEqualToString:@"maPeriod"] ||
                [identifier isEqualToString:@"volumeMAPeriod"]) {
                self.workingParameters[identifier] = @(textField.integerValue);
            } else {
                self.workingParameters[identifier] = @(textField.doubleValue);
            }
            
        } else if ([view isKindOfClass:[NSPopUpButton class]]) {
            NSPopUpButton *popup = (NSPopUpButton *)view;
            self.workingParameters[identifier] = popup.titleOfSelectedItem;
            
        } else if ([view isKindOfClass:[NSButton class]]) {
            NSButton *checkbox = (NSButton *)view;
            
            // Handle checkbox groups (identifier format: "key.option")
            if ([identifier containsString:@"."]) {
                NSArray *parts = [identifier componentsSeparatedByString:@"."];
                NSString *key = parts[0];
                NSString *option = parts[1];
                
                NSMutableArray *currentArray = [self.workingParameters[key] mutableCopy];
                if (!currentArray) {
                    currentArray = [NSMutableArray array];
                }
                
                if (checkbox.state == NSControlStateValueOn) {
                    if (![currentArray containsObject:option]) {
                        [currentArray addObject:option];
                    }
                } else {
                    [currentArray removeObject:option];
                }
                
                self.workingParameters[key] = [currentArray copy];
            }
        }
    }
}

@end
