//
//  GridWindow.h
//  TradingApp
//
//  Grid window containing multiple widgets in a layout
//

#import <Cocoa/Cocoa.h>
#import "GridTemplate.h"

@class BaseWidget;
@class AppDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface GridWindow : NSWindow <NSWindowDelegate, NSSplitViewDelegate>

// Properties
@property (nonatomic, strong) NSMutableArray<BaseWidget *> *widgets;
@property (nonatomic, strong) GridTemplate *currentTemplate;
@property (nonatomic, strong) NSString *gridName;
@property (nonatomic, weak) AppDelegate *appDelegate;

// Accessory view controls
@property (nonatomic, strong) NSPopUpButton *templateSelector;
@property (nonatomic, strong) NSButton *addWidgetButton;
@property (nonatomic, strong) NSButton *settingsButton;

// Layout
@property (nonatomic, strong) NSSplitView *mainSplitView;
@property (nonatomic, strong) NSMutableDictionary<GridPosition, BaseWidget *> *widgetPositions;

// Initialization
- (instancetype)initWithTemplate:(GridTemplateType)templateType
                            name:(nullable NSString *)name
                     appDelegate:(AppDelegate *)appDelegate;

// Widget Management
- (void)addWidget:(BaseWidget *)widget atPosition:(GridPosition)position;
- (void)removeWidget:(BaseWidget *)widget;
- (BaseWidget *)detachWidget:(BaseWidget *)widget; // Returns widget for new FloatingWindow

// Template Management
- (void)changeTemplate:(GridTemplateType)newTemplateType;

// Serialization
- (NSDictionary *)serializeState;
- (void)restoreState:(NSDictionary *)state;

@end

NS_ASSUME_NONNULL_END
