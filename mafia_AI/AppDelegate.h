//
//  AppDelegate.h - Estensione per Tools Menu
//  TradingApp
//

#import <Cocoa/Cocoa.h>
// Forward declarations
@class BaseWidget;
@class ChartWidget;
@class FloatingWidgetWindow;
@class WidgetTypeManager;
@class MainWindowController;  // ← AGGIUNGI QUESTA LINEA

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowRestoration>

// Outlet per la finestra principale
@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) MainWindowController *mainWindowController;

// Floating Windows Management
@property (nonatomic, strong) NSMutableArray<FloatingWidgetWindow *> *floatingWindows;
@property (nonatomic, strong) WidgetTypeManager *widgetTypeManager;

#pragma mark - Universal Tools Menu Action

// 🎯 UNICA AZIONE per tutti i widget - determina il tipo dal titolo del sender
- (IBAction)openFloatingWidget:(id)sender;

#pragma mark - Window Management Actions

- (IBAction)arrangeFloatingWindows:(id)sender;
- (IBAction)closeAllFloatingWindows:(id)sender;

#pragma mark - Floating Window Management

- (FloatingWidgetWindow *)createFloatingWindowWithWidget:(BaseWidget *)widget
                                                   title:(NSString *)title
                                                    size:(NSSize)size;
- (void)registerFloatingWindow:(FloatingWidgetWindow *)window;
- (void)unregisterFloatingWindow:(FloatingWidgetWindow *)window;

#pragma mark - Microscope Window Management (NEW)

// Crea finestra microscopio specializzata per ChartWidget
- (FloatingWidgetWindow *)createMicroscopeWindowWithChartWidget:(ChartWidget *)chartWidget
                                                          title:(NSString *)title
                                                           size:(NSSize)size;


#pragma mark - Widget Creation Helper

- (BaseWidget *)createWidgetOfType:(NSString *)widgetType;
- (NSSize)defaultSizeForWidgetType:(NSString *)widgetType;

@end
