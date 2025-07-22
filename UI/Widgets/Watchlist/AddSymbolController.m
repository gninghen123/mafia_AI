//
//  AddSymbolController.m
//  mafia_AI
//

#import "AddSymbolController.h"
#import "DataHub.h"

@interface AddSymbolController ()

@end

@implementation AddSymbolController

- (instancetype)initWithWatchlistName:(NSString *)watchlistName {
    self = [super initWithWindowNibName:@"AddSymbolController"];
    if (self) {
        _watchlistName = watchlistName;
    }
    return self;
}

- (instancetype)init {
    return [self initWithWatchlistName:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Configure window
    self.window.title = @"Add Symbol";
    
    // Clear fields
    self.symbolTextField.stringValue = @"";
    self.nameTextField.stringValue = @"";
    self.exchangeTextField.stringValue = @"";
    
    // Hide progress indicator
    [self.progressIndicator setHidden:YES];
    self.statusLabel.stringValue = @"";
    
    // Enable add button only when symbol is entered
    [self updateAddButtonState];
    
    // Set up notifications for text field changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textFieldDidChange:)
                                               name:NSControlTextDidChangeNotification
                                             object:self.symbolTextField];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)textFieldDidChange:(NSNotification *)notification {
    [self updateAddButtonState];
}

- (void)updateAddButtonState {
    self.addButton.enabled = self.symbolTextField.stringValue.length > 0;
}

- (IBAction)addSymbol:(id)sender {
    NSString *symbol = [self.symbolTextField.stringValue uppercaseString];
    NSString *name = self.nameTextField.stringValue;
    NSString *exchange = self.exchangeTextField.stringValue;
    
    if (symbol.length == 0) {
        [self showError:@"Please enter a symbol"];
        return;
    }
    
    // Show progress
    [self.progressIndicator setHidden:NO];
    [self.progressIndicator startAnimation:self];
    self.addButton.enabled = NO;
    self.cancelButton.enabled = NO;
    self.statusLabel.stringValue = @"Adding symbol...";
    
    // Since we don't have MarketDataService, we'll add the symbol directly
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.progressIndicator stopAnimation:self];
        [self.progressIndicator setHidden:YES];
        
        // Call completion handler with the new symbol
        if (self.completionHandler) {
            self.completionHandler(@[symbol]);
        }
        
        // Close window
        [self.window close];
    });
}

- (IBAction)cancel:(id)sender {
    if (self.completionHandler) {
        self.completionHandler(@[]);
    }
    [self.window close];
}

- (void)showError:(NSString *)error {
    self.statusLabel.stringValue = error;
    self.statusLabel.textColor = [NSColor systemRedColor];
    
    // Clear error after 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = @"";
        self.statusLabel.textColor = [NSColor labelColor];
    });
}
@end
