//
//  ToolbarController.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>

@class MainWindowController;

@interface ToolbarController : NSObject <NSToolbarDelegate>

@property (nonatomic, weak) MainWindowController *mainWindowController;
@property (nonatomic, strong) NSToolbar *toolbar;

- (void)setupToolbarForWindow:(NSWindow *)window;

@end
