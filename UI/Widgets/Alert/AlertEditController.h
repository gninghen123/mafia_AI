//
//  AlertEditController.h
//  mafia_AI
//
//  Window controller per creare/modificare alert
//

#import <Cocoa/Cocoa.h>

@class Alert;

@interface AlertEditController : NSWindowController <NSTextFieldDelegate>

@property (nonatomic, strong) Alert *alert; // nil for new alert
@property (nonatomic, copy) void (^completionHandler)(Alert *alert, BOOL saved);

- (instancetype)initWithAlert:(Alert *)alert;

@end
