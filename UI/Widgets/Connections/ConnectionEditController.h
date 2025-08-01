//
//  ConnectionEditController.h
//  mafia_AI
//
//  Window controller for creating/editing stock connections
//

#import <Cocoa/Cocoa.h>
#import "ConnectionModel.h"  // Usa il file esistente

@interface ConnectionEditController : NSWindowController

// Properties - USA ConnectionModel esistente
@property (nonatomic, strong, nullable) ConnectionModel *connectionModel; // nil = create, non-nil = edit
@property (nonatomic, readonly) BOOL isEditing;

// Callbacks
@property (nonatomic, copy, nullable) void (^onSave)(ConnectionModel *connectionModel);
@property (nonatomic, copy, nullable) void (^onCancel)(void);

// Factory methods
+ (instancetype)controllerForCreating;
+ (instancetype)controllerForEditing:(ConnectionModel *)connectionModel;

// Main action
- (void)showWindow;

@end
