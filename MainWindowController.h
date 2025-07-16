//
//  MainWindowController.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>

@class ToolbarController;
@class PanelController;

@interface MainWindowController : NSWindowController <NSSplitViewDelegate>

@property (nonatomic, strong) ToolbarController *toolbarController;
@property (nonatomic, strong) PanelController *leftPanelController;
@property (nonatomic, strong) PanelController *centerPanelController;
@property (nonatomic, strong) PanelController *rightPanelController;

// Layout management
- (void)saveLayoutWithName:(NSString *)layoutName;
- (void)loadLayoutWithName:(NSString *)layoutName;
- (NSArray *)availableLayouts;

@end
