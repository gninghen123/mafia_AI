//
//  MainWindowController.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>

@class ToolbarController;
@class PanelController;
@class LayoutManager;

@interface MainWindowController : NSWindowController <NSSplitViewDelegate>

@property (nonatomic, strong) ToolbarController *toolbarController;
@property (nonatomic, strong) PanelController *leftPanelController;
@property (nonatomic, strong) PanelController *centerPanelController;
@property (nonatomic, strong) PanelController *rightPanelController;
@property (nonatomic, strong) LayoutManager *layoutManager;  // ← AGGIUNGI QUESTA


// Layout management
- (void)saveLayoutWithName:(NSString *)layoutName;
- (void)loadLayoutWithName:(NSString *)layoutName;
- (NSArray *)availableLayouts;

@end
