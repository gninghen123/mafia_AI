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

// Callbacks
@property (nonatomic, copy) void (^onRemoveRequest)(BaseWidget *widget);
@property (nonatomic, copy) void (^onAddRequest)(BaseWidget *widget, WidgetAddDirection direction);
@property (nonatomic, copy) void (^onTypeChange)(BaseWidget *widget, NSString *newType);

// Chain system - NEW PROPERTIES
@property (nonatomic, assign) BOOL chainActive;
@property (nonatomic, strong) NSColor *chainColor;  // Colore della chain quando attiva

// REMOVED: @property (nonatomic, strong) NSMutableSet *chainedWidgets;

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType;

// Widget lifecycle
- (void)setupHeaderView;
- (void)setupContentView;
- (void)updateContentForType:(NSString *)newType;

// State management
- (NSDictionary *)serializeState;
- (void)restoreState:(NSDictionary *)state;

// Chain management - UPDATED METHODS
- (void)setChainActive:(BOOL)active withColor:(NSColor *)color;
- (void)broadcastUpdate:(NSDictionary *)update;
- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender;

// REMOVED: - (void)addChainedWidget:(BaseWidget *)widget;
// REMOVED: - (void)removeChainedWidget:(BaseWidget *)widget;

// Collapse functionality
- (void)toggleCollapse;
- (CGFloat)collapsedHeight;
- (CGFloat)expandedHeight;
- (void)setupViews;

@end
