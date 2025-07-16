//
//  AlertEditWindowController.m
//  TradingApp
//

#import "AlertEditWindowController.h"
#import "DataManager.h"

@interface AlertEditWindowController () <NSTextFieldDelegate>

@property (nonatomic, strong) NSTimer *priceUpdateTimer;

@end

@implementation AlertEditWindowController

- (instancetype)initWithAlert:(AlertEntry *)alert {
    // FIXED: Usa init invece di initWithWindowNibName:nil
    self = [super init];
    if (self) {
        _originalAlert = alert;
        _editedAlert = alert ? [alert copy] : [[AlertEntry alloc] init];
        
        [self setupWindow];
        [self setupUI];
        [self loadAlertData];
        
        // Timer per aggiornamento prezzi
        _priceUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                              target:self
                                                            selector:@selector(updateCurrentPrices)
                                                            userInfo:nil
                                                             repeats:YES];
    }
    return self;
}

- (void)dealloc {
    [_priceUpdateTimer invalidate];
}

- (void)setupWindow {
    NSRect frame = NSMakeRect(0, 0, 400, 350);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.title = self.originalAlert ? @"Modifica Alert" : @"Nuovo Alert";
    self.window = window;
}

// Sostituisci il metodo setupUI nell'AlertEditWindowController.m con questo completo:

- (void)setupUI {
    NSView *contentView = self.window.contentView;
    
    // Symbol field
    NSTextField *symbolLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 280, 100, 20)];
    symbolLabel.stringValue = @"Simbolo:";
    symbolLabel.editable = NO;
    symbolLabel.bezeled = NO;
    symbolLabel.drawsBackground = NO;
    [contentView addSubview:symbolLabel];
    
    self.symbolField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 280, 250, 25)];
    self.symbolField.placeholderString = @"ES. AAPL";
    self.symbolField.delegate = self;
    [contentView addSubview:self.symbolField];
    
    // Type popup
    NSTextField *typeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 240, 100, 20)];
    typeLabel.stringValue = @"Tipo Alert:";
    typeLabel.editable = NO;
    typeLabel.bezeled = NO;
    typeLabel.drawsBackground = NO;
    [contentView addSubview:typeLabel];
    
    self.typePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, 240, 250, 25)];
    [self.typePopup addItemWithTitle:@"Prezzo Sopra"];
    [self.typePopup addItemWithTitle:@"Prezzo Sotto"];
    [contentView addSubview:self.typePopup];
    
    // Nel metodo setupUI, trova la sezione del priceField e sostituisci con:

    // Price field
    NSTextField *priceLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 200, 100, 20)];
    priceLabel.stringValue = @"Prezzo Target:";
    priceLabel.editable = NO;
    priceLabel.bezeled = NO;
    priceLabel.drawsBackground = NO;
    [contentView addSubview:priceLabel];

    self.priceField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 200, 250, 25)];
    self.priceField.placeholderString = @"0.00000";

    // FIXED: Formatter che accetta sempre il punto come separatore decimale
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 5;

    // Forza l'uso del punto come separatore decimale (stile US)
    formatter.decimalSeparator = @".";
    formatter.groupingSeparator = @"";  // Disabilita il separatore delle migliaia
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];

    self.priceField.formatter = formatter;
    [contentView addSubview:self.priceField];
    
    // Current prices
    NSTextField *currentLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 160, 100, 20)];
    currentLabel.stringValue = @"Prezzi Correnti:";
    currentLabel.editable = NO;
    currentLabel.bezeled = NO;
    currentLabel.drawsBackground = NO;
    [contentView addSubview:currentLabel];
    
    self.currentPriceLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 160, 80, 20)];
    self.currentPriceLabel.stringValue = @"Last: --";
    self.currentPriceLabel.editable = NO;
    self.currentPriceLabel.bezeled = NO;
    self.currentPriceLabel.drawsBackground = NO;
    [contentView addSubview:self.currentPriceLabel];
    
    self.bidLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(220, 160, 80, 20)];
    self.bidLabel.stringValue = @"Bid: --";
    self.bidLabel.editable = NO;
    self.bidLabel.bezeled = NO;
    self.bidLabel.drawsBackground = NO;
    [contentView addSubview:self.bidLabel];
    
    self.askLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(310, 160, 80, 20)];
    self.askLabel.stringValue = @"Ask: --";
    self.askLabel.editable = NO;
    self.askLabel.bezeled = NO;
    self.askLabel.drawsBackground = NO;
    [contentView addSubview:self.askLabel];
    
    // Notes field
    NSTextField *notesLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 120, 100, 20)];
    notesLabel.stringValue = @"Note:";
    notesLabel.editable = NO;
    notesLabel.bezeled = NO;
    notesLabel.drawsBackground = NO;
    [contentView addSubview:notesLabel];
    
    self.notesField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 120, 250, 25)];
    self.notesField.placeholderString = @"Note opzionali...";
    [contentView addSubview:self.notesField];
    
    // Active checkbox
    self.activeCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(130, 80, 200, 25)];
    self.activeCheckbox.buttonType = NSSwitchButton;
    self.activeCheckbox.title = @"Alert Attivo";
    self.activeCheckbox.state = NSControlStateValueOn;
    [contentView addSubview:self.activeCheckbox];
    
    // Buttons
    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(210, 20, 80, 30)];
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.title = @"Annulla";
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelAction:);
    [contentView addSubview:self.cancelButton];
    
    self.okButton = [[NSButton alloc] initWithFrame:NSMakeRect(300, 20, 80, 30)];
    self.okButton.bezelStyle = NSBezelStyleRounded;
    self.okButton.title = @"OK";
    self.okButton.target = self;
    self.okButton.action = @selector(okAction:);
    self.okButton.keyEquivalent = @"\r";
    [contentView addSubview:self.okButton];
}

- (void)loadAlertData {
    if (self.originalAlert) {
        self.symbolField.stringValue = self.originalAlert.symbol ?: @"";
        self.priceField.doubleValue = self.originalAlert.targetPrice;
        [self.typePopup selectItemAtIndex:self.originalAlert.alertType];
        self.notesField.stringValue = self.originalAlert.notes ?: @"";
        self.activeCheckbox.state = (self.originalAlert.status == AlertStatusActive) ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    [self updateCurrentPrices];
}

- (void)updateCurrentPrices {
    NSString *symbol = self.symbolField.stringValue;
    if (symbol.length == 0) {
        self.currentPriceLabel.stringValue = @"Last: --";
        self.bidLabel.stringValue = @"Bid: --";
        self.askLabel.stringValue = @"Ask: --";
        return;
    }
    
    NSDictionary *symbolData = [[DataManager sharedManager] dataForSymbol:symbol];
    if (symbolData) {
        double last = [symbolData[@"last"] doubleValue];
        double bid = [symbolData[@"bid"] doubleValue];
        double ask = [symbolData[@"ask"] doubleValue];
        
        self.currentPriceLabel.stringValue = [NSString stringWithFormat:@"Last: %.5f", last];
        self.bidLabel.stringValue = [NSString stringWithFormat:@"Bid: %.5f", bid];
        self.askLabel.stringValue = [NSString stringWithFormat:@"Ask: %.5f", ask];
        
        // Se è un nuovo alert e il campo prezzo è vuoto, precompila con ask + 1 tick
        if (!self.originalAlert && self.priceField.doubleValue == 0 && ask > 0) {
            double tickSize = [[DataManager sharedManager] tickSizeForSymbol:symbol];
            self.priceField.doubleValue = ask + tickSize;
        }
    } else {
        self.currentPriceLabel.stringValue = @"Last: N/A";
        self.bidLabel.stringValue = @"Bid: N/A";
        self.askLabel.stringValue = @"Ask: N/A";
    }
}

#pragma mark - Actions

- (void)okAction:(id)sender {
    // DEBUG: Verifica i valori dei campi PRIMA della validazione
    NSLog(@"okAction - Valori campi:");
    NSLog(@"  Symbol: '%@'", self.symbolField.stringValue);
    NSLog(@"  Price string: '%@'", self.priceField.stringValue);
    NSLog(@"  Price double: %.5f", self.priceField.doubleValue);
    NSLog(@"  Type index: %ld", (long)self.typePopup.indexOfSelectedItem);
    
    // Validazione
    if (self.symbolField.stringValue.length == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Errore";
        alert.informativeText = @"Inserisci un simbolo valido.";
        [alert runModal];
        return;
    }
    
    // FIXED: Debug se il prezzo è 0 e perché
    if (self.priceField.doubleValue <= 0) {
        NSLog(@"ERRORE: Prezzo non valido");
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Errore";
        alert.informativeText = @"Inserisci un prezzo target valido.";
        [alert runModal];
        return;
    }
    
    // FIXED: Assicurati che il nuovo alert abbia un ID e data di creazione
    if (!self.editedAlert.alertID) {
        self.editedAlert.alertID = [[NSUUID UUID] UUIDString];
        NSLog(@"Generato nuovo ID: %@", self.editedAlert.alertID);
    }
    if (!self.editedAlert.creationDate) {
        self.editedAlert.creationDate = [NSDate date];
        NSLog(@"Impostata data di creazione");
    }
    
    // Aggiorna l'alert
    self.editedAlert.symbol = self.symbolField.stringValue;
    self.editedAlert.targetPrice = self.priceField.doubleValue;
    self.editedAlert.alertType = self.typePopup.indexOfSelectedItem;
    self.editedAlert.notes = self.notesField.stringValue ?: @"";
    
    if (self.activeCheckbox.state == NSControlStateValueOn) {
        self.editedAlert.status = AlertStatusActive;
    } else {
        self.editedAlert.status = AlertStatusDisabled;
    }
    
    // DEBUG: Log dopo l'aggiornamento
    NSLog(@"Alert aggiornato: ID=%@, Symbol=%@, Price=%.5f, Type=%ld, Status=%ld",
          self.editedAlert.alertID,
          self.editedAlert.symbol,
          self.editedAlert.targetPrice,
          (long)self.editedAlert.alertType,
          (long)self.editedAlert.status);
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}
- (void)cancelAction:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object == self.symbolField) {
        [self updateCurrentPrices];
    }
}

@end
