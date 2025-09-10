//
//  GlobalSpotlightManager.h
//  TradingApp
//
//  Global Spotlight Search Manager
//  Intercepts keyboard input and shows spotlight search overlay
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class AppDelegate;
@class SpotlightSearchWindow;

@interface GlobalSpotlightManager : NSObject

#pragma mark - Properties

@property (nonatomic, weak) AppDelegate *appDelegate;
@property (nonatomic, strong) SpotlightSearchWindow *searchWindow;
@property (nonatomic, strong) id globalKeyboardMonitor;
@property (nonatomic, assign) BOOL isSpotlightVisible;

#pragma mark - Initialization

- (instancetype)initWithAppDelegate:(AppDelegate *)appDelegate;

#pragma mark - Keyboard Monitoring

/**
 * Setup global keyboard event monitoring
 * Intercepts alphanumeric keys when app is active
 */
- (void)setupGlobalKeyboardMonitoring;

/**
 * Remove keyboard monitoring (called on dealloc)
 */
- (void)removeKeyboardMonitoring;

#pragma mark - Spotlight Control

/**
 * Show spotlight window with initial character
 * @param character Initial character to populate search field
 */
- (void)showSpotlightWithCharacter:(NSString *)character;

/**
 * Hide spotlight window
 */
- (void)hideSpotlight;

/**
 * Toggle spotlight visibility
 */
- (void)toggleSpotlight;

#pragma mark - Focus Management

/**
 * Get currently focused widget window
 * @return Currently focused window or nil
 */
- (NSWindow *)getCurrentFocusedWindow;

/**
 * Check if a text field is currently being edited
 * @return YES if user is typing in a text field
 */
- (BOOL)isTextFieldActive;

@end

NS_ASSUME_NONNULL_END
