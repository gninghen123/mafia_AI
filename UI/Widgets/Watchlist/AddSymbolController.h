//
//  AddSymbolController.h
//  mafia_AI
//

#import <Cocoa/Cocoa.h>

@interface AddSymbolController : NSWindowController

@property (nonatomic, copy) void (^completionHandler)(NSArray<NSString *> *symbols);
@property (nonatomic, strong) NSString *watchlistName;

// UI Outlets
@property (weak) IBOutlet NSTextField *symbolTextField;
@property (weak) IBOutlet NSTextField *nameTextField;
@property (weak) IBOutlet NSTextField *exchangeTextField;
@property (weak) IBOutlet NSButton *addButton;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *statusLabel;

// Initialization
- (instancetype)initWithWatchlistName:(NSString *)watchlistName;

// Actions
- (IBAction)addSymbol:(id)sender;
- (IBAction)cancel:(id)sender;

@end
