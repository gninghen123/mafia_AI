//
//  AlertEditController.h
//  mafia_AI
//
//  Window controller per creare/modificare alert
//  UPDATED: Pattern corretto come ChartPreferencesWindow
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"

@interface AlertEditController : NSWindowController <NSTextFieldDelegate>

@property (nonatomic, strong) AlertModel *alert; // nil for new alert
@property (nonatomic, copy) void (^completionHandler)(AlertModel *alert, BOOL saved);

// Initialization
- (instancetype)initWithAlert:(AlertModel *)alert;
- (instancetype)initWithAlert:(AlertModel *)alert isEditing:(BOOL)isEditing; // ✅ NUOVO - mode esplicito

// Window management
- (void)showAlertEditWindow;

@end
