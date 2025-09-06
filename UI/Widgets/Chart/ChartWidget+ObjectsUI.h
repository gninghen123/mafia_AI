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

#pragma mark - Sidebar Pattern Properties
@property (nonatomic, strong) NSLayoutConstraint *splitViewLeadingConstraint;

#pragma mark - Objects UI Methods
- (void)createObjectsPanel;
- (void)toggleObjectsPanel:(id)sender;
- (void)showObjectManager:(id)sender;

@end
