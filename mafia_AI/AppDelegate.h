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
@class GridWindow;  // ✅ NUOVO
@class GridTemplate;  // ✅ NUOVO



@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowRestoration>



// Outlet per la finestra principale
@property (weak) IBOutlet NSWindow *window;

// Floating Windows Management
@property (nonatomic, strong) NSMutableArray<FloatingWidgetWindow *> *floatingWindows;
@property (nonatomic, strong) WidgetTypeManager *widgetTypeManager;

@property (nonatomic, strong) NSMutableArray<GridWindow *> *gridWindows;  // ✅ NUOVO
#pragma mark - Grid Actions (NEW)

- (IBAction)openGrid:(id)sender;  // ✅ NUOVO
#pragma mark - Grid Window Management (NEW)

- (GridWindow *)createGridWindowWithTemplate:(GridTemplate *)template
                                        name:(NSString *)name;  // ✅ NOVO
- (void)registerGridWindow:(GridWindow *)window;  // ✅ NUOVO
- (void)unregisterGridWindow:(GridWindow *)window;  // ✅ NUOVO

#pragma mark - Universal Tools Menu Action

// 🎯 UNICA AZIONE per tutti i widget - determina il tipo dal titolo del sender
- (IBAction)openFloatingWidget:(id)sender;

#pragma mark - Window Management Actions

- (IBAction)arrangeFloatingWindows:(id)sender;
- (IBAction)closeAllFloatingWindows:(id)sender;
- (IBAction)closeAllGrids:(id)sender;  // ✅ NUOVO

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



- (IBAction)openPreferences:(id)sender;

// ==========================================
// FAVORITES SYSTEM - ADDITIONS TO AppDelegate.h
// ==========================================
// Add these declarations to AppDelegate.h interface

#pragma mark - Favorites Management

// Favorites notification name (add as extern in .m file)
// extern NSString *const kFavoritesDidChangeNotification;

/// Get all favorite symbols
- (NSArray<NSString *> *)favoriteSymbols;

/// Check if a symbol is in favorites
- (BOOL)isSymbolFavorite:(NSString *)symbol;

/// Add a symbol to favorites
- (void)addSymbolToFavorites:(NSString *)symbol;

/// Remove a symbol from favorites
- (void)removeSymbolFromFavorites:(NSString *)symbol;

/// Toggle favorite status for a symbol
- (void)toggleFavoriteForSymbol:(NSString *)symbol;

/// Remove all favorites (with confirmation)
- (void)removeAllFavoritesWithConfirmation:(void (^)(BOOL confirmed))completion;

/// Send all favorites to a specific chain color
- (void)sendAllFavoritesToChainWithColor:(NSColor *)color;

// ==========================================
// END FAVORITES SYSTEM ADDITIONS
// ==========================================
@end
