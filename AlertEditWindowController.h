//
//  AlertEditWindowController.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>
#import "AlertEntry.h"

@interface AlertEditWindowController : NSWindowController

@property (nonatomic, strong) AlertEntry *originalAlert;
@property (nonatomic, strong) AlertEntry *editedAlert;

// UI Elements
@property (nonatomic, strong) NSTextField *symbolField;
@property (nonatomic, strong) NSTextField *priceField;
@property (nonatomic, strong) NSPopUpButton *typePopup;
@property (nonatomic, strong) NSTextField *notesField;
@property (nonatomic, strong) NSButton *activeCheckbox;
@property (nonatomic, strong) NSButton *okButton;
@property (nonatomic, strong) NSButton *cancelButton;

// Prezzi correnti
@property (nonatomic, strong) NSTextField *currentPriceLabel;
@property (nonatomic, strong) NSTextField *bidLabel;
@property (nonatomic, strong) NSTextField *askLabel;

- (instancetype)initWithAlert:(AlertEntry *)alert;
- (void)updateCurrentPrices;

@end
