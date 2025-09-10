//
//  GlobalSpotlightManager.m
//  TradingApp
//
//  Global Spotlight Search Manager Implementation
//

#import "GlobalSpotlightManager.h"
#import "SpotlightSearchWindow.h"
#import "AppDelegate.h"

@implementation GlobalSpotlightManager

#pragma mark - Initialization

- (instancetype)initWithAppDelegate:(AppDelegate *)appDelegate {
    self = [super init];
    if (self) {
        _appDelegate = appDelegate;
        _isSpotlightVisible = NO;
        
        [self setupGlobalKeyboardMonitoring];
        
        NSLog(@"🔍 GlobalSpotlightManager: Initialized with keyboard monitoring");
    }
    return self;
}

- (void)dealloc {
    [self removeKeyboardMonitoring];
}

#pragma mark - Keyboard Monitoring

- (void)setupGlobalKeyboardMonitoring {
    // Remove existing monitor if any
    [self removeKeyboardMonitoring];
    
    // Setup global key monitor for alphanumeric keys
    self.globalKeyboardMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                                        handler:^(NSEvent *event) {
        [self handleGlobalKeyEvent:event];
    }];
    
    NSLog(@"⌨️ GlobalSpotlightManager: Global keyboard monitoring enabled");
}

- (void)removeKeyboardMonitoring {
    if (self.globalKeyboardMonitor) {
        [NSEvent removeMonitor:self.globalKeyboardMonitor];
        self.globalKeyboardMonitor = nil;
        NSLog(@"⌨️ GlobalSpotlightManager: Global keyboard monitoring disabled");
    }
}

- (void)handleGlobalKeyEvent:(NSEvent *)event {
    // Only handle when app is active and no text field is being edited
    if (![NSApp isActive] || [self isTextFieldActive] || self.isSpotlightVisible) {
        return;
    }
    
    // Get the character from the key event
    NSString *characters = event.charactersIgnoringModifiers;
    if (characters.length == 0) return;
    
    unichar character = [characters characterAtIndex:0];
    
    // Check if it's an alphanumeric character
    if ([self isAlphanumericCharacter:character]) {
        NSString *characterString = [NSString stringWithFormat:@"%C", character];
        NSLog(@"🔍 GlobalSpotlightManager: Intercepted character: %@", characterString);
        
        // Show spotlight with the intercepted character
        [self showSpotlightWithCharacter:characterString];
    }
}

- (BOOL)isAlphanumericCharacter:(unichar)character {
    return [[NSCharacterSet alphanumericCharacterSet] characterIsMember:character];
}

#pragma mark - Spotlight Control

- (void)showSpotlightWithCharacter:(NSString *)character {
    if (self.isSpotlightVisible) {
        // If already visible, just append to search field
        if (self.searchWindow.searchField) {
            NSString *currentText = self.searchWindow.searchField.stringValue;
            self.searchWindow.searchField.stringValue = [currentText stringByAppendingString:character];
            [self.searchWindow performSymbolSearch:self.searchWindow.searchField.stringValue];
        }
        return;
    }
    
    // Create search window if needed
    if (!self.searchWindow) {
        self.searchWindow = [[SpotlightSearchWindow alloc] initWithSpotlightManager:self];
    }
    
    // Show window with initial character
    [self.searchWindow showWithInitialText:character];
    self.isSpotlightVisible = YES;
    
    NSLog(@"✨ GlobalSpotlightManager: Spotlight shown with character: %@", character);
}

- (void)hideSpotlight {
    if (!self.isSpotlightVisible) return;
    
    [self.searchWindow hideWindow];
    self.isSpotlightVisible = NO;
    
    NSLog(@"🫥 GlobalSpotlightManager: Spotlight hidden");
}

- (void)toggleSpotlight {
    if (self.isSpotlightVisible) {
        [self hideSpotlight];
    } else {
        [self showSpotlightWithCharacter:@""];
    }
}

#pragma mark - Focus Management

- (NSWindow *)getCurrentFocusedWindow {
    return [NSApp keyWindow];
}

- (BOOL)isTextFieldActive {
    NSWindow *keyWindow = [NSApp keyWindow];
    if (!keyWindow) return NO;
    
    NSResponder *firstResponder = keyWindow.firstResponder;
    
    // Check if first responder is a text field or text view
    if ([firstResponder isKindOfClass:[NSTextField class]] ||
        [firstResponder isKindOfClass:[NSTextView class]] ||
        [firstResponder isKindOfClass:[NSSearchField class]]) {
        
        // Additional check: make sure it's actually editable
        if ([firstResponder isKindOfClass:[NSTextField class]]) {
            NSTextField *textField = (NSTextField *)firstResponder;
            return textField.isEditable;
        }
        
        if ([firstResponder isKindOfClass:[NSTextView class]]) {
            NSTextView *textView = (NSTextView *)firstResponder;
            return textView.isEditable;
        }
        
        return YES;
    }
    
    // Check if we're in field editor mode
    if ([firstResponder isKindOfClass:[NSText class]]) {
        NSText *fieldEditor = (NSText *)firstResponder;
        return fieldEditor.delegate != nil; // Field editor has a delegate when active
    }
    
    return NO;
}

@end
