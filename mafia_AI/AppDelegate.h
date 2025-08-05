//
//  AppDelegate.h - Header corretto
//  TradingApp
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowRestoration>

// Outlet per la finestra principale
@property (weak) IBOutlet NSWindow *window;

@end
