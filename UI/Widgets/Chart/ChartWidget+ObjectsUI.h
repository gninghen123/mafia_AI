//
//  ChartWidget+ObjectsUI.h
//  TradingApp
//
//  Extension for Chart Objects UI integration
//

#import "ChartWidget.h"
#import "ChartObjectModels.h"
#import "ObjectsPanel.h"

@interface ChartWidget (ObjectsUI)

#pragma mark - Objects UI Properties
@property (nonatomic, strong) NSButton *objectsPanelToggle;
@property (nonatomic, strong) ObjectsPanel *objectsPanel;
@property (nonatomic, strong) ChartObjectsManager *objectsManager;
@property (nonatomic, assign) BOOL isObjectsPanelVisible;

#pragma mark - Objects UI Methods
- (void)setupObjectsUI;
- (void)toggleObjectsPanel:(id)sender;
- (void)showObjectManager:(id)sender;

@end
