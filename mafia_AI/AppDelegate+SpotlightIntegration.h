// AppDelegate+SpotlightIntegration.h
//  Integration methods for Spotlight Search in AppDelegate
//

#import "AppDelegate.h"
#import "TradingAppTypes.h"


@class GlobalSpotlightManager;
@class ChartWidget;

@interface AppDelegate (SpotlightIntegration)

#pragma mark - Spotlight Manager

@property (nonatomic, strong) GlobalSpotlightManager *spotlightManager;

/**
 * Initialize spotlight search system
 */
- (void)initializeSpotlightSearch;

#pragma mark - Chart Widget Integration

/**
 * Open ChartWidget in center panel with specific symbol
 * @param symbol Stock symbol to load
 */
- (void)openChartWidgetInCenterPanelWithSymbol:(NSString *)symbol;

/**
 * Get existing ChartWidget from center panel or create new one
 * @return ChartWidget instance in center panel
 */
- (ChartWidget *)getOrCreateChartWidgetInCenterPanel;

/**
 * Find ChartWidget in center panel
 * @return Existing ChartWidget or nil
 */
- (ChartWidget *)findChartWidgetInCenterPanel;

#pragma mark - Panel Widget Management

/**
 * Open widget in specific panel
 * @param widgetType Widget type identifier
 * @param panelType Target panel type
 */
- (void)openWidget:(NSString *)widgetType inPanel:(PanelType)panelType;

/**
 * Get current focused widget
 * @return Currently focused widget or nil
 */
- (BaseWidget *)getCurrentFocusedWidget;

@end
