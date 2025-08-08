//
//  ChartPanelView+DoubleClick.h
//  TradingApp
//
//  Extension for handling double-click to open object settings
//

#import "ChartPanelView.h"
#import "ChartObjectSettingsWindow.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChartPanelView (DoubleClick)

// Settings window management
@property (nonatomic, strong, nullable) ChartObjectSettingsWindow *settingsWindow;

// Double-click handling
- (void)mouseDown:(NSEvent *)event; // Override to add double-click detection
- (void)handleDoubleClickAtPoint:(NSPoint)point withEvent:(NSEvent *)event;
- (void)openObjectSettingsForObject:(ChartObjectModel *)object;

@end

NS_ASSUME_NONNULL_END
