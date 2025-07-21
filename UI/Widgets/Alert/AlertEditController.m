//
//  AlertEditController.m
//  mafia_AI
//

#import "AlertEditController.h"
#import "DataHub.h"
#import "Alert+CoreDataClass.h"

@interface AlertEditController () <NSTextFieldDelegate>
@property (nonatomic, strong) NSTextField *symbolField;
@property (nonatomic, strong) NSPopUpButton *conditionPopup;
@property (nonatomic, strong) NSTextField *priceField;
@property (nonatomic, strong) NSButton *activeCheckbox;
@property (nonatomic, strong) NSTextField *notesField;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *cancelButton;
@property (nonatomic, strong) NSTextField *currentPriceLabel;
@property (nonatomic, strong) NSProgressIndicator *priceLoadingIndicator;
@end

@implementation AlertEditController

- (instancetype)initWithAlert:(Alert *)alert {
    self = [super initWithWindowNibName:@""];
    if (self) {
        self.alert = alert;
        [self setupWindow];
    }
    return self;
}

- (void)setupWindow {
    // Create window
    NSRect frame = NSMakeRect(0, 0, 400, 300);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = self.alert ? @"Edit Alert" : @"New Alert";
    self.window = window;
    
    NSView *contentView = window.contentView;
    
    // Symbol field
    NSTextField *symbolLabel = [NSTextField labelWithString:@"Symbol:"];
    symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.symbolField = [[NSTextField alloc] init];
    self.symbolField.placeholderString = @"AAPL";
    self.symbolField.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolField.delegate = self;
    
    // Current price label
    self.currentPriceLabel = [NSTextField labelWithString:@""];
    self.currentPriceLabel.font = [NSFont systemFontOfSize:11];
    self.currentPriceLabel.textColor = [NSColor secondaryLabelColor];
    self.currentPriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.priceLoadingIndicator = [[NSProgressIndicator alloc] init];
    self.priceLoadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.priceLoadingIndicator.controlSize = NSControlSizeSmall;
    self.priceLoadingIndicator.hidden = YES;
    self.priceLoadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Condition popup
    NSTextField *conditionLabel = [NSTextField labelWithString:@"Alert when price:"];
    conditionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.conditionPopup = [[NSPopUpButton alloc] init];
    [self.conditionPopup addItemsWithTitles:@[@"Goes Above", @"Goes Below"]];
    self.conditionPopup.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Price field
    NSTextField *priceLabel = [NSTextField labelWithString:@"Price:"];
    priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.priceField = [[NSTextField alloc] init];
    self.priceField.placeholderString = @"150.00";
    self.priceField.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Active checkbox
    self.activeCheckbox = [NSButton checkboxWithTitle:@"Alert is active" target:nil action:nil];
    self.activeCheckbox.state = NSControlStateValueOn;
    self.activeCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Notes field
    NSTextField *notesLabel = [NSTextField labelWithString:@"Notes:"];
    notesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.notesField = [[NSTextField alloc] init];
    self.notesField.placeholderString = @"Optional notes...";
    self.notesField.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Buttons
    self.cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancel:)];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.saveButton = [NSButton buttonWithTitle:@"Save" target:self action:@selector(save:)];
    self.saveButton.keyEquivalent = @"\r";
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add all subviews
    [contentView addSubview:symbolLabel];
    [contentView addSubview:self.symbolField];
    [contentView addSubview:self.currentPriceLabel];
    [contentView addSubview:self.priceLoadingIndicator];
    [contentView addSubview:conditionLabel];
    [contentView addSubview:self.conditionPopup];
    [contentView addSubview:priceLabel];
    [contentView addSubview:self.priceField];
    [contentView addSubview:self.activeCheckbox];
    [contentView addSubview:notesLabel];
    [contentView addSubview:self.notesField];
    [contentView addSubview:self.cancelButton];
    [contentView addSubview:self.saveButton];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        // Symbol row
        [symbolLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [symbolLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        
        [self.symbolField.leadingAnchor constraintEqualToAnchor:symbolLabel.trailingAnchor constant:10],
        [self.symbolField.centerYAnchor constraintEqualToAnchor:symbolLabel.centerYAnchor],
        [self.symbolField.widthAnchor constraintEqualToConstant:100],
        
        [self.currentPriceLabel.leadingAnchor constraintEqualToAnchor:self.symbolField.trailingAnchor constant:10],
        [self.currentPriceLabel.centerYAnchor constraintEqualToAnchor:self.symbolField.centerYAnchor],
        
        [self.priceLoadingIndicator.leadingAnchor constraintEqualToAnchor:self.symbolField.trailingAnchor constant:10],
        [self.priceLoadingIndicator.centerYAnchor constraintEqualToAnchor:self.symbolField.centerYAnchor],
        
        // Condition row
        [conditionLabel.leadingAnchor constraintEqualToAnchor:symbolLabel.leadingAnchor],
        [conditionLabel.topAnchor constraintEqualToAnchor:symbolLabel.bottomAnchor constant:20],
        
        [self.conditionPopup.leadingAnchor constraintEqualToAnchor:self.symbolField.leadingAnchor],
        [self.conditionPopup.centerYAnchor constraintEqualToAnchor:conditionLabel.centerYAnchor],
        [self.conditionPopup.widthAnchor constraintEqualToConstant:150],
        
        // Price row
        [priceLabel.leadingAnchor constraintEqualToAnchor:symbolLabel.leadingAnchor],
        [priceLabel.topAnchor constraintEqualToAnchor:conditionLabel.bottomAnchor constant:20],
        
        [self.priceField.leadingAnchor constraintEqualToAnchor:self.symbolField.leadingAnchor],
        [self.priceField.centerYAnchor constraintEqualToAnchor:priceLabel.centerYAnchor],
        [self.priceField.widthAnchor constraintEqualToConstant:100],
        
        // Active checkbox
        [self.activeCheckbox.leadingAnchor constraintEqualToAnchor:self.symbolField.leadingAnchor],
        [self.activeCheckbox.topAnchor constraintEqualToAnchor:priceLabel.bottomAnchor constant:20],
        
        // Notes row
        [notesLabel.leadingAnchor constraintEqualToAnchor:symbolLabel.leadingAnchor],
        [notesLabel.topAnchor constraintEqualToAnchor:self.activeCheckbox.bottomAnchor constant:20],
        
        [self.notesField.leadingAnchor constraintEqualToAnchor:self.symbolField.leadingAnchor],
        [self.notesField.centerYAnchor constraintEqualToAnchor:notesLabel.centerYAnchor],
        [self.notesField.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        // Buttons
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor constant:-10],
        
        [self.saveButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20]
    ]];
    
    // Populate fields if editing
    if (self.alert) {
        self.symbolField.stringValue = self.alert.symbol ?: @"";
        self.conditionPopup.selectedItem.title = [self.alert.conditionString isEqualToString:@"below"] ? @"Goes Below" : @"Goes Above";
        self.priceField.stringValue = [NSString stringWithFormat:@"%.2f", self.alert.triggerValue];
        self.activeCheckbox.state = self.alert.isActive ? NSControlStateValueOn : NSControlStateValueOff;
        self.notesField.stringValue = self.alert.notes ?: @"";
        
        [self updateCurrentPrice];
    }
}

- (void)updateCurrentPrice {
    NSString *symbol = self.symbolField.stringValue;
    if (symbol.length == 0) {
        self.currentPriceLabel.stringValue = @"";
        return;
    }
    
    NSDictionary *data = [[DataHub shared] getDataForSymbol:symbol];
    if (data) {
        double price = [data[@"price"] doubleValue];
        double change = [data[@"changePercent"] doubleValue];
        
        self.currentPriceLabel.stringValue = [NSString stringWithFormat:@"Current: $%.2f (%.2f%%)", price, change];
        
        if (change > 0) {
            self.currentPriceLabel.textColor = [NSColor systemGreenColor];
        } else if (change < 0) {
            self.currentPriceLabel.textColor = [NSColor systemRedColor];
        } else {
            self.currentPriceLabel.textColor = [NSColor secondaryLabelColor];
        }
    } else {
        self.currentPriceLabel.stringValue = @"Price not available";
        self.currentPriceLabel.textColor = [NSColor secondaryLabelColor];
    }
}

#pragma mark - Actions

- (void)save:(id)sender {
    // Validate
    NSString *symbol = [self.symbolField.stringValue uppercaseString];
    if (symbol.length == 0) {
        NSBeep();
        return;
    }
    
    double price = [self.priceField doubleValue];
    if (price <= 0) {
        NSBeep();
        return;
    }
    
    NSString *condition = [self.conditionPopup.selectedItem.title isEqualToString:@"Goes Above"] ? @"above" : @"below";
    BOOL isActive = (self.activeCheckbox.state == NSControlStateValueOn);
    
    DataHub *hub = [DataHub shared];
    
    if (self.alert) {
        // Update existing
        self.alert.symbol = symbol;
        self.alert.conditionString = condition;
        self.alert.triggerValue = price;
        self.alert.isActive = isActive;
        self.alert.notes = self.notesField.stringValue;
        [hub updateAlert:self.alert];
    } else {
        // Create new
        self.alert = [hub createAlertForSymbol:symbol
                                     condition:condition
                                         value:price
                                        active:isActive];
        self.alert.notes = self.notesField.stringValue;
        [hub updateAlert:self.alert];
    }
    
    if (self.completionHandler) {
        self.completionHandler(self.alert, YES);
    }
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (void)cancel:(id)sender {
    if (self.completionHandler) {
        self.completionHandler(nil, NO);
    }
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object == self.symbolField) {
        // Cancella qualsiasi update precedente in coda
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCurrentPrice) object:nil];
        // Aggiorna dopo 0.5 secondi di pausa nella digitazione
        [self performSelector:@selector(updateCurrentPrice) withObject:nil afterDelay:0.5];
    }
}

@end
