//
//  WidgetContainerView.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>
#import "TradingAppTypes.h"

@class BaseWidget;
@class PanelController;

@interface WidgetContainerView : NSView <NSSplitViewDelegate>

@property (nonatomic, weak) PanelController *panelController;

// Widget management
- (void)addWidget:(BaseWidget *)widget;
- (void)removeWidget:(BaseWidget *)widget;
- (void)insertWidget:(BaseWidget *)widget
       relativeToWidget:(BaseWidget *)relativeWidget
          inDirection:(WidgetAddDirection)direction;

// Clear all widgets
- (void)clearAllWidgets;

// Replace widget view
- (void)replaceWidget:(BaseWidget *)oldWidget withWidget:(BaseWidget *)newWidget;

// Serialization
- (NSDictionary *)serializeStructure;
- (void)restoreStructure:(NSDictionary *)structure
         withWidgetStates:(NSArray *)widgetStates
         panelController:(PanelController *)panelController;

@end
