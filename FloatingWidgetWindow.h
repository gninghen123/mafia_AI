//
//  FloatingWidgetWindow.h - FIXED VERSION
//  mafia_AI
//
//  Finestra fluttuante per contenere widget singoli
//

#import <Cocoa/Cocoa.h>

@class BaseWidget;
@class AppDelegate;

// ✅ FIX: Aggiungi NSWindowRestoration al protocollo
@interface FloatingWidgetWindow : NSWindow <NSWindowDelegate, NSWindowRestoration>

// Properties
@property (nonatomic, strong) BaseWidget *containedWidget;
@property (nonatomic, weak) AppDelegate *appDelegate;
@property (nonatomic, strong) NSString *widgetType;

// Initialization
- (instancetype)initWithWidget:(BaseWidget *)widget
                         title:(NSString *)title
                          size:(NSSize)size
                   appDelegate:(AppDelegate *)appDelegate;

// Widget Management
- (void)setupWidgetContainer;
- (void)configureWindowBehavior;

// Window State
- (void)saveWindowState;
- (void)restoreWindowState;

@end
