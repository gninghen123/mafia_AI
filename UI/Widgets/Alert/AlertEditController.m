//
//  AlertEditController.m
//  mafia_AI
//
//  Window controller per creare/modificare alert
//  UPDATED: Usa solo DataHub e RuntimeModels
//

#import "AlertEditController.h"
#import "DataHub.h"

@interface AlertEditController ()

// UI Components
@property (nonatomic, strong) NSTextField *symbolField;
@property (nonatomic, strong) NSPopUpButton *conditionPopup;
@property (nonatomic, strong) NSTextField *valueField;
@property (nonatomic, strong) NSButton *notificationCheckbox;
@property (nonatomic, strong) NSTextField *notesField;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *cancelButton;

// State
@property (nonatomic, assign) BOOL isEditing;

@end

@implementation AlertEditController

- (instancetype)initWithAlert:(AlertModel *)alert {
    if (self = [super init]) {
        _alert = alert;
        _isEditing = (alert != nil);
        [self setupWindow];
    }
    return self;
}

- (void)setupWindow {
    // Create window
    NSRect windowFrame = NSMakeRect(0, 0, 400, 300);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.title = self.isEditing ? @"Edit Alert" : @"New Alert";
    window.level = NSFloatingWindowLevel;
    [window center];
    
    self.window = window;
    
    [self setupContentView];
    [self populateFields];
}

- (void)setupContentView {
    NSView *contentView = self.window.contentView;
    
    // Symbol field
    NSTextField *symbolLabel = [self createLabel:@"Symbol:"];
    self.symbolField = [self createTextField];
    self.symbolField.placeholderString = @"e.g., AAPL";
    self.symbolField.delegate = self;
    
    // Condition popup
    NSTextField *conditionLabel = [self createLabel:@"Condition:"];
    self.conditionPopup = [[NSPopUpButton alloc] init];
    [self.conditionPopup addItemWithTitle:@"Above"];
    [self.conditionPopup addItemWithTitle:@"Below"];
    [self.conditionPopup addItemWithTitle:@"Crosses Above"];
    [self.conditionPopup addItemWithTitle:@"Crosses Below"];
    
    // Value field
    NSTextField *valueLabel = [self createLabel:@"Trigger Value:"];
    self.valueField = [self createTextField];
    self.valueField.placeholderString = @"0.00";
    self.valueField.delegate = self;
    
    // Notification checkbox
    self.notificationCheckbox = [[NSButton alloc] init];
    [self.notificationCheckbox setButtonType:NSButtonTypeSwitch];
    self.notificationCheckbox.title = @"Show notification when triggered";
    self.notificationCheckbox.state = NSControlStateValueOn;
    
    // Notes field
    NSTextField *notesLabel = [self createLabel:@"Notes:"];
    self.notesField = [self createTextField];
    self.notesField.placeholderString = @"Optional notes...";
    
    // Buttons
    self.cancelButton = [[NSButton alloc] init];
    [self.cancelButton setTitle:@"Cancel"];
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancel:);
    
    self.saveButton = [[NSButton alloc] init];
    [self.saveButton setTitle:self.isEditing ? @"Update" : @"Create"];
    self.saveButton.bezelStyle = NSBezelStyleRounded;
    self.saveButton.keyEquivalent = @"\r"; // Enter key
    self.saveButton.target = self;
    self.saveButton.action = @selector(save:);
    
    // Layout all components
    [self layoutComponents:@[
        symbolLabel, self.symbolField,
        conditionLabel, self.conditionPopup,
        valueLabel, self.valueField,
        self.notificationCheckbox,
        notesLabel, self.notesField,
        self.cancelButton, self.saveButton
    ] inContentView:contentView];
}

- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.editable = NO;
    label.bezeled = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont boldSystemFontOfSize:12];
    return label;
}

- (NSTextField *)createTextField {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.bezelStyle = NSTextFieldSquareBezel;
    textField.bezeled = YES;
    return textField;
}

- (void)layoutComponents:(NSArray *)components inContentView:(NSView *)contentView {
    for (NSView *component in components) {
        component.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:component];
    }
    
    // Create constraints
    NSTextField *symbolLabel = components[0];
    NSTextField *conditionLabel = components[2];
    NSTextField *valueLabel = components[4];
    NSTextField *notesLabel = components[7];
    
    [NSLayoutConstraint activateConstraints:@[
        // Symbol
        [symbolLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [symbolLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [symbolLabel.widthAnchor constraintEqualToConstant:100],
        
        [self.symbolField.topAnchor constraintEqualToAnchor:symbolLabel.topAnchor],
        [self.symbolField.leadingAnchor constraintEqualToAnchor:symbolLabel.trailingAnchor constant:10],
        [self.symbolField.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        // Condition
        [conditionLabel.topAnchor constraintEqualToAnchor:symbolLabel.bottomAnchor constant:20],
        [conditionLabel.leadingAnchor constraintEqualToAnchor:symbolLabel.leadingAnchor],
        [conditionLabel.widthAnchor constraintEqualToConstant:100],
        
        [self.conditionPopup.topAnchor constraintEqualToAnchor:conditionLabel.topAnchor],
        [self.conditionPopup.leadingAnchor constraintEqualToAnchor:conditionLabel.trailingAnchor constant:10],
        [self.conditionPopup.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        // Value
        [valueLabel.topAnchor constraintEqualToAnchor:conditionLabel.bottomAnchor constant:20],
        [valueLabel.leadingAnchor constraintEqualToAnchor:symbolLabel.leadingAnchor],
        [valueLabel.widthAnchor constraintEqualToConstant:100],
        
        [self.valueField.topAnchor constraintEqualToAnchor:valueLabel.topAnchor],
        [self.valueField.leadingAnchor constraintEqualToAnchor:valueLabel.trailingAnchor constant:10],
        [self.valueField.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        // Notification checkbox
        [self.notificationCheckbox.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:20],
        [self.notificationCheckbox.leadingAnchor constraintEqualToAnchor:symbolLabel.leadingAnchor],
        [self.notificationCheckbox.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        // Notes
        [notesLabel.topAnchor constraintEqualToAnchor:self.notificationCheckbox.bottomAnchor constant:20],
        [notesLabel.leadingAnchor constraintEqualToAnchor:symbolLabel.leadingAnchor],
        [notesLabel.widthAnchor constraintEqualToConstant:100],
        
        [self.notesField.topAnchor constraintEqualToAnchor:notesLabel.topAnchor],
        [self.notesField.leadingAnchor constraintEqualToAnchor:notesLabel.trailingAnchor constant:10],
        [self.notesField.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        // Buttons
        [self.saveButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [self.saveButton.widthAnchor constraintEqualToConstant:80],
        
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:self.saveButton.bottomAnchor],
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor constant:-10],
        [self.cancelButton.widthAnchor constraintEqualToConstant:80]
    ]];
}

- (void)populateFields {
    if (self.alert) {
        self.symbolField.stringValue = self.alert.symbol ?: @"";
        self.valueField.stringValue = [NSString stringWithFormat:@"%.2f", self.alert.triggerValue];
        self.notificationCheckbox.state = self.alert.notificationEnabled ? NSControlStateValueOn : NSControlStateValueOff;
        self.notesField.stringValue = self.alert.notes ?: @"";
        
        // Set condition popup
        if ([self.alert.conditionString isEqualToString:@"above"]) {
            [self.conditionPopup selectItemAtIndex:0];
        } else if ([self.alert.conditionString isEqualToString:@"below"]) {
            [self.conditionPopup selectItemAtIndex:1];
        } else if ([self.alert.conditionString isEqualToString:@"crosses_above"]) {
            [self.conditionPopup selectItemAtIndex:2];
        } else if ([self.alert.conditionString isEqualToString:@"crosses_below"]) {
            [self.conditionPopup selectItemAtIndex:3];
        }
    }
}

#pragma mark - Actions

- (void)save:(id)sender {
    // Validate input
    NSString *symbol = [self.symbolField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].uppercaseString;
    NSString *valueString = [self.valueField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (symbol.length == 0) {
        [self showErrorAlert:@"Please enter a symbol."];
        return;
    }
    
    if (valueString.length == 0) {
        [self showErrorAlert:@"Please enter a trigger value."];
        return;
    }
    
    double triggerValue = valueString.doubleValue;
    if (triggerValue <= 0) {
        [self showErrorAlert:@"Please enter a valid trigger value greater than 0."];
        return;
    }
    
    // Get condition string
    NSString *conditionString;
    NSInteger selectedIndex = self.conditionPopup.indexOfSelectedItem;
    switch (selectedIndex) {
        case 0: conditionString = @"above"; break;
        case 1: conditionString = @"below"; break;
        case 2: conditionString = @"crosses_above"; break;
        case 3: conditionString = @"crosses_below"; break;
        default: conditionString = @"above"; break;
    }
    
    BOOL notificationEnabled = (self.notificationCheckbox.state == NSControlStateValueOn);
    NSString *notes = [self.notesField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (notes.length == 0) notes = nil;
    
    // Create or update alert
    AlertModel *resultAlert;
    
    if (self.isEditing) {
        // Update existing alert
        self.alert.symbol = symbol;
        self.alert.triggerValue = triggerValue;
        self.alert.conditionString = conditionString;
        self.alert.notificationEnabled = notificationEnabled;
        self.alert.notes = notes;
        
        [[DataHub shared] updateAlertModel:self.alert];
        resultAlert = self.alert;
    } else {
        // Create new alert
        resultAlert = [[DataHub shared] createAlertModelWithSymbol:symbol
                                                       triggerValue:triggerValue
                                                    conditionString:conditionString
                                               notificationEnabled:notificationEnabled
                                                              notes:notes];
    }
    
    // Close and call completion
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    
    if (self.completionHandler) {
        self.completionHandler(resultAlert, YES);
    }
}

- (void)cancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    
    if (self.completionHandler) {
        self.completionHandler(nil, NO);
    }
}

- (void)showErrorAlert:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Invalid Input";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

#pragma mark - Text Field Delegate

- (void)controlTextDidChange:(NSNotification *)obj {
    // Auto-uppercase symbol field
    if (obj.object == self.symbolField) {
        NSString *text = self.symbolField.stringValue;
        self.symbolField.stringValue = text.uppercaseString;
    }
}

@end
