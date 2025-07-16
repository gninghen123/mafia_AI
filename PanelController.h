//
//  PanelController.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>
#import "TradingAppTypes.h"

@class BaseWidget;

@interface PanelController : NSViewController

@property (nonatomic, readonly) PanelType panelType;
@property (nonatomic, strong, readonly) NSMutableArray<BaseWidget *> *widgets;

- (instancetype)initWithPanelType:(PanelType)panelType;

// Widget management
- (void)addWidget:(BaseWidget *)widget;
- (void)removeWidget:(BaseWidget *)widget;
- (BOOL)canRemoveWidget:(BaseWidget *)widget;
- (NSInteger)widgetCount;

// Internal use - for WidgetContainerView
- (void)addWidgetToCollection:(BaseWidget *)widget;
- (void)addNewWidgetFromWidget:(BaseWidget *)sourceWidget inDirection:(WidgetAddDirection)direction;

// Layout serialization
- (NSDictionary *)serializeLayout;
- (void)restoreLayout:(NSDictionary *)layoutData;

// Layout presets
- (void)saveCurrentLayoutAsPreset:(NSString *)presetName;
- (void)loadLayoutPreset:(NSString *)presetName;
- (NSArray *)availablePresets;

@end
