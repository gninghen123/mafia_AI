

//
//  AlertEditController.m
//  mafia_AI
//
//  Window controller per creare/modificare alert
//  UPDATED: Pattern corretto come ChartPreferencesWindow - NO SHEET!
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

// ✅ AGGIUNGI: Store original values for cancel (come ChartPreferencesWindow)
@property (nonatomic, strong) NSString *originalSymbol;
@property (nonatomic, assign) double originalTriggerValue;
@property (nonatomic, strong) NSString *originalConditionString;
@property (nonatomic, assign) BOOL originalNotificationEnabled;
@property (nonatomic, strong) NSString *originalNotes;

@end

@implementation AlertEditController

#pragma mark - Initialization

- (instancetype)initWithAlert:(AlertModel *)alert {
    // ✅ COMPORTAMENTO ORIGINALE per retrocompatibilità
    return [self initWithAlert:alert isEditing:(alert != nil)];
}

// ✅ NUOVO: Init con mode esplicito
- (instancetype)initWithAlert:(AlertModel *)alert isEditing:(BOOL)isEditing {
    // Create window programmatically
    NSRect windowFrame = NSMakeRect(0, 0, 400, 300);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        _alert = alert;
        _isEditing = isEditing; // ✅ USA IL PARAMETRO ESPLICITO, NON LA LOGICA ALERT != NIL
        
        // Store original values for cancel
        if (alert) {
            _originalSymbol = alert.symbol;
            _originalTriggerValue = alert.triggerValue;
            _originalConditionString = alert.conditionString;
            _originalNotificationEnabled = alert.notificationEnabled;
            _originalNotes = alert.notes;
        }
        
        [self setupWindow];
        [self createControls];
        [self loadCurrentValues];
        
        NSLog(@"🏗️ AlertEditController created - Alert: %@, IsEditing: %@",
              alert ? @"YES" : @"NO", isEditing ? @"YES" : @"NO");
    }
    return self;
}

#pragma mark - Window Setup

- (void)setupWindow {
    NSWindow *window = self.window;
    
    // ✅ MODIFICATO: Non usare NSFloatingWindowLevel - causa problemi con eventi
    window.title = self.isEditing ? @"Edit Alert" : @"New Alert";
    window.level = NSNormalWindowLevel; // ← CAMBIATO da NSFloatingWindowLevel
    
    // ✅ AGGIUNTO: Assicura che la window possa ricevere eventi
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder:self.symbolField];
    
    // Center on screen
    [window center];
    
    NSLog(@"🪟 AlertEditController window setup completed");
}


- (void)createControls {
    NSView *contentView = self.window.contentView;
    
    // Symbol Section
    NSTextField *symbolLabel = [self createLabel:@"Symbol:" frame:NSMakeRect(20, 220, 100, 20)];
    [contentView addSubview:symbolLabel];
    
    self.symbolField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 218, 240, 24)];
    self.symbolField.placeholderString = @"e.g., AAPL";
    self.symbolField.delegate = self;
    [contentView addSubview:self.symbolField];
    
    // Condition Section
    NSTextField *conditionLabel = [self createLabel:@"Condition:" frame:NSMakeRect(20, 180, 100, 20)];
    [contentView addSubview:conditionLabel];
    
    self.conditionPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, 178, 240, 24)];
    [self.conditionPopup addItemWithTitle:@"Above"];
    [self.conditionPopup addItemWithTitle:@"Below"];
    [self.conditionPopup addItemWithTitle:@"Crosses Above"];
    [self.conditionPopup addItemWithTitle:@"Crosses Below"];
    [contentView addSubview:self.conditionPopup];
    
    // Value Section
    NSTextField *valueLabel = [self createLabel:@"Trigger Value:" frame:NSMakeRect(20, 140, 100, 20)];
    [contentView addSubview:valueLabel];
    
    self.valueField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 138, 240, 24)];
    self.valueField.placeholderString = @"0.00";
    self.valueField.delegate = self;
    [contentView addSubview:self.valueField];
    
    // Notification Section
    self.notificationCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 100, 350, 24)];
    [self.notificationCheckbox setButtonType:NSButtonTypeSwitch];
    [self.notificationCheckbox setTitle:@"Show notification when triggered"];
    [self.notificationCheckbox setState:NSControlStateValueOn];
    [contentView addSubview:self.notificationCheckbox];
    
    // Notes Section
    NSTextField *notesLabel = [self createLabel:@"Notes:" frame:NSMakeRect(20, 70, 100, 20)];
    [contentView addSubview:notesLabel];
    
    self.notesField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 68, 240, 24)];
    self.notesField.placeholderString = @"Optional notes...";
    [contentView addSubview:self.notesField];
    
    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(190, 20, 80, 32)];
        [self.cancelButton setTitle:@"Cancel"];
        [self.cancelButton setBezelStyle:NSBezelStyleRounded];
        [self.cancelButton setKeyEquivalent:@"\033"]; // Escape key
        [self.cancelButton setTarget:self]; // ← Esplicito
        [self.cancelButton setAction:@selector(cancelAlert:)]; // ← Esplicito
        [self.cancelButton setEnabled:YES];
        [contentView addSubview:self.cancelButton];
        
        self.saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(280, 20, 80, 32)];
        [self.saveButton setTitle:self.isEditing ? @"Update" : @"Create"];
        [self.saveButton setBezelStyle:NSBezelStyleRounded];
        [self.saveButton setKeyEquivalent:@"\r"]; // Enter key
        [self.saveButton setTarget:self]; // ← Esplicito
        [self.saveButton setAction:@selector(saveAlert:)]; // ← Esplicito
        [self.saveButton setEnabled:YES];
        [contentView addSubview:self.saveButton];
    
    NSLog(@"✅ Alert edit controls created - Save target: %@, Cancel target: %@",
          self.saveButton.target, self.cancelButton.target);
}

#pragma mark - Helper Methods

- (NSTextField *)createLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:13];
    return label;
}

#pragma mark - Data Loading

- (void)loadCurrentValues {
    if (!self.alert) {
        NSLog(@"💡 Loading defaults for new alert");
        return;
    }
    
    // Load current alert values
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
    
    NSLog(@"📊 Loaded alert values - Symbol: %@, Value: %.2f, Condition: %@",
          self.alert.symbol, self.alert.triggerValue, self.alert.conditionString);
}

#pragma mark - Actions

- (IBAction)saveAlert:(id)sender {
    NSLog(@"🚨 SAVE ALERT CALLED! Sender: %@, Target: %@, Action: %@",
          sender, [sender target], NSStringFromSelector([sender action]));
    
    // ✅ AGGIUNTO: Debug completo per capire perché non funziona
    if (!sender) {
        NSLog(@"❌ Sender is nil!");
        return;
    }
    
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
        
        NSLog(@"✅ Updated existing alert: %@ at %.2f", symbol, triggerValue);
    } else {
        // Create new alert
        resultAlert = [[DataHub shared] createAlertModelWithSymbol:symbol
                                                       triggerValue:triggerValue
                                                    conditionString:conditionString
                                               notificationEnabled:notificationEnabled
                                                              notes:notes];
        
        NSLog(@"✅ Created new alert: %@ at %.2f", symbol, triggerValue);
    }
    
    // ✅ MIGLIORATO: Chiusura più robusta
    [self closeWindowAndComplete:resultAlert saved:YES];
}

- (IBAction)cancelAlert:(id)sender {
    NSLog(@"❌ CANCEL ALERT CALLED! Sender: %@", sender);
    
    // ✅ MIGLIORATO: Chiusura più robusta
    [self closeWindowAndComplete:nil saved:NO];
}

#pragma mark - Window Management

- (void)showAlertEditWindow {
    [self loadCurrentValues];
    
    // ✅ MIGLIORATO: Setup più robusto della window
    NSWindow *window = self.window;
    [window center];
    [window makeKeyAndOrderFront:nil];
    
    // ✅ AGGIUNTO: Assicura focus sui controlli
    [window makeFirstResponder:self.symbolField];
    
    // ✅ AGGIUNTO: Debug per verificare button targets
    NSLog(@"🔍 Button debug - Save target: %@, action: %@",
          self.saveButton.target, NSStringFromSelector(self.saveButton.action));
    NSLog(@"🔍 Button debug - Cancel target: %@, action: %@",
          self.cancelButton.target, NSStringFromSelector(self.cancelButton.action));
    
    NSLog(@"🪟 Alert edit window opened and focused");
}
- (void)closeWindowAndComplete:(AlertModel *)alert saved:(BOOL)saved {
    NSLog(@"🔻 Closing alert edit window - saved: %@", saved ? @"YES" : @"NO");
    
    // Call completion handler BEFORE closing window
    if (self.completionHandler) {
        self.completionHandler(alert, saved);
    }
    
    // ✅ MIGLIORATO: Chiusura più robusta
    NSWindow *window = self.window;
    [window orderOut:self];
  
    NSLog(@"✅ Alert edit window closed successfully");
}

- (void)closeWindow {
    // ✅ DEPRECATO: Usa il nuovo metodo unificato
    [self closeWindowAndComplete:nil saved:NO];
}


#pragma mark - Error Handling

- (void)showErrorAlert:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Invalid Input";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    alert.alertStyle = NSAlertStyleWarning;
    
    // ✅ Show as sheet on this window
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
