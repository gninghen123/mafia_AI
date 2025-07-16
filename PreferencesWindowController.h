//
//  PreferencesWindowController.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>

@interface PreferencesWindowController : NSWindowController

+ (instancetype)sharedController;
- (void)showPreferences;

@end
