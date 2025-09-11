// AppDelegate+SpotlightIntegration.m
//  Implementation of Spotlight integration
//

#import "AppDelegate+SpotlightIntegration.h"
#import "GlobalSpotlightManager.h"
#import "MainWindowController.h"
#import "ChartWidget.h"
#import "PanelController.h"
#import "LayoutManager.h"
#import "FloatingWidgetWindow.h"
#import <objc/runtime.h>

// Associated object key for spotlight manager
static char const * const SpotlightManagerKey = "SpotlightManagerKey";

@implementation AppDelegate (SpotlightIntegration)

#pragma mark - Property Implementation

- (GlobalSpotlightManager *)spotlightManager {
    return objc_getAssociatedObject(self, SpotlightManagerKey);
}

- (void)setSpotlightManager:(GlobalSpotlightManager *)spotlightManager {
    objc_setAssociatedObject(self, SpotlightManagerKey, spotlightManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Spotlight Manager

- (void)initializeSpotlightSearch {
    if (!self.spotlightManager) {
        self.spotlightManager = [[GlobalSpotlightManager alloc] initWithAppDelegate:self];
        NSLog(@"✨ AppDelegate: Spotlight search system initialized");
    }
}

#pragma mark - Chart Widget Integration

- (void)openChartWidgetInCenterPanelWithSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) {
        NSLog(@"⚠️ AppDelegate: Cannot open ChartWidget with empty symbol");
        return;
    }
    
    NSLog(@"📈 AppDelegate: Opening ChartWidget in center panel with symbol: %@", symbol);
    
    // Get or create ChartWidget in center panel
    ChartWidget *chartWidget = [self getOrCreateChartWidgetInCenterPanel];
    
    if (chartWidget) {
        // Ensure the widget view is loaded
        if (!chartWidget.view) {
            [chartWidget loadView];
        }
        
        // Use the existing processSmartSymbolInput method
        [chartWidget processSmartSymbolInput:symbol];
        
        // Focus main window
        [self.mainWindowController.window makeKeyAndOrderFront:nil];
        
        NSLog(@"✅ AppDelegate: ChartWidget configured with symbol: %@", symbol);
    } else {
        NSLog(@"❌ AppDelegate: Failed to get/create ChartWidget in center panel");
    }
}

- (ChartWidget *)getOrCreateChartWidgetInCenterPanel {
    // First, try to find existing ChartWidget in center panel
    ChartWidget *existingWidget = [self findChartWidgetInCenterPanel];
    if (existingWidget) {
        NSLog(@"📊 AppDelegate: Found existing ChartWidget in center panel");
        return existingWidget;
    }
    
    // If no existing widget, create new one in center panel
    return [self createChartWidgetInCenterPanel];
}

- (ChartWidget *)findChartWidgetInCenterPanel {
    if (!self.mainWindowController) return nil;
    
    // Get center panel controller directly from MainWindowController
    PanelController *centerPanel = self.mainWindowController.centerPanelController;
    if (!centerPanel) return nil;
    
    // Search through widgets in center panel
    for (BaseWidget *widget in centerPanel.widgets) {
        if ([widget isKindOfClass:[ChartWidget class]]) {
            return (ChartWidget *)widget;
        }
    }
    
    return nil;
}

- (ChartWidget *)createChartWidgetInCenterPanel {
    if (!self.mainWindowController) {
        NSLog(@"❌ AppDelegate: No main window controller available");
        return nil;
    }
    
    // Create new ChartWidget
    ChartWidget *chartWidget = (ChartWidget *)[self createWidgetOfType:@"Chart Widget"];
    if (!chartWidget) {
        NSLog(@"❌ AppDelegate: Failed to create ChartWidget");
        return nil;
    }
    
    // Get center panel controller directly from MainWindowController
    PanelController *centerPanel = self.mainWindowController.centerPanelController;
    if (!centerPanel) {
        NSLog(@"❌ AppDelegate: No center panel controller available");
        return nil;
    }
    
    // Add widget to center panel
    [centerPanel addWidget:chartWidget];
    
    NSLog(@"✅ AppDelegate: Created new ChartWidget in center panel");
    return chartWidget;
}

#pragma mark - Panel Widget Management

- (void)openWidget:(NSString *)widgetType inPanel:(PanelType)panelType {
    if (!widgetType || !self.mainWindowController) return;
    
    NSLog(@"🔧 AppDelegate: Opening %@ in panel type: %ld", widgetType, (long)panelType);
    
    // Create widget
    BaseWidget *widget = [self createWidgetOfType:widgetType];
    if (!widget) {
        NSLog(@"❌ AppDelegate: Failed to create widget: %@", widgetType);
        return;
    }
    
    // Get target panel controller based on panel type
    PanelController *panelController = nil;
    switch (panelType) {
        case PanelTypeLeft:
            panelController = self.mainWindowController.leftPanelController;
            break;
        case PanelTypeCenter:
            panelController = self.mainWindowController.centerPanelController;
            break;
        case PanelTypeRight:
            panelController = self.mainWindowController.rightPanelController;
            break;
    }
    
    if (!panelController) {
        NSLog(@"⚠️ AppDelegate: Panel not available, opening as floating window instead");
        // Fallback to floating window
        [self openFloatingWidget:widgetType];
        return;
    }
    
    // Add widget to panel
    [panelController addWidget:widget];
    
    // Focus main window
    [self.mainWindowController.window makeKeyAndOrderFront:nil];
    
    NSLog(@"✅ AppDelegate: Opened %@ in panel", widgetType);
}

#pragma mark - Widget Focus Management

- (BaseWidget *)getCurrentFocusedWidget {
    NSWindow *keyWindow = [NSApp keyWindow];
    if (!keyWindow) return nil;
    
    // Check if it's a floating widget window
    if ([keyWindow isKindOfClass:[FloatingWidgetWindow class]]) {
        FloatingWidgetWindow *floatingWindow = (FloatingWidgetWindow *)keyWindow;
        return floatingWindow.containedWidget;
    }
    
    // Check if it's the main window
    if (keyWindow == self.mainWindowController.window) {
        // Find the currently active panel and its focused widget
        // This would need more integration with PanelController to track focus
        // For now, return nil
        return nil;
    }
    
    return nil;
}

@end
