//
//  BaseWidget.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>
#import "TradingAppTypes.h"

@interface BaseWidget : NSViewController

@property (nonatomic, strong) NSString *widgetType;
@property (nonatomic, strong) NSString *widgetID;
@property (nonatomic, assign) PanelType panelType;
@property (nonatomic, assign, getter=isCollapsed) BOOL collapsed;
@property (nonatomic, weak, readonly) NSWindow *parentWindow;

// UI Components
@property (nonatomic, strong, readonly) NSView *headerView;
@property (nonatomic, strong, readonly) NSView *contentView;
@property (nonatomic, strong, readonly) NSTextField *titleField;
@property (nonatomic, strong, readonly) NSButton *chainButton;

// Callbacks
@property (nonatomic, copy) void (^onRemoveRequest)(BaseWidget *widget);
@property (nonatomic, copy) void (^onAddRequest)(BaseWidget *widget, WidgetAddDirection direction);
@property (nonatomic, copy) void (^onTypeChange)(BaseWidget *widget, NSString *newType);

// Chain connections
@property (nonatomic, strong) NSMutableSet *chainedWidgets;
@property (nonatomic, strong) NSColor *chainColor;

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType;

// Widget lifecycle
- (void)setupHeaderView;
- (void)setupContentView;
- (void)updateContentForType:(NSString *)newType;

// State management
- (NSDictionary *)serializeState;
- (void)restoreState:(NSDictionary *)state;

// Chain management (advanced)
- (NSArray<BaseWidget *> *)findAvailableWidgetsForConnection;
- (void)connectToWidget:(NSMenuItem *)sender;
- (void)disconnectFromWidget:(NSMenuItem *)sender;
- (void)showConnectionFeedback:(NSString *)message success:(BOOL)success;
- (BOOL)hasConnectedChartWidgets;
- (BOOL)hasConnectedWidgetsOfType:(Class)widgetClass;
- (NSArray<BaseWidget *> *)connectedWidgetsOfType:(Class)widgetClass;
- (void)addChainedWidget:(BaseWidget *)widget;
- (void)removeChainedWidget:(BaseWidget *)widget;
- (void)broadcastUpdate:(NSDictionary *)update;
// Collapse functionality
- (void)toggleCollapse;
- (CGFloat)collapsedHeight;
- (CGFloat)expandedHeight;
- (void)setupViews;

@end
