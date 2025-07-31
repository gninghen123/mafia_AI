//
//  AlertEditController.h
//  mafia_AI
//
//  Window controller per creare/modificare alert
//  UPDATED: Usa solo RuntimeModels
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"

@interface AlertEditController : NSWindowController <NSTextFieldDelegate>

@property (nonatomic, strong) AlertModel *alert; // nil for new alert
@property (nonatomic, copy) void (^completionHandler)(AlertModel *alert, BOOL saved);

- (instancetype)initWithAlert:(AlertModel *)alert;

@end
