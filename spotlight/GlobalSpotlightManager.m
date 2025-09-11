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
    [self removeKeyboardMonitoring];
    
    NSLog(@"🔧 Setting up LOCAL keyboard monitor...");
    
    // USA addLocalMonitorForEventsMatchingMask invece di addGlobalMonitor
    self.globalKeyboardMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                                      handler:^NSEvent *(NSEvent *event) {
        NSLog(@"🎯 LOCAL monitor: Key pressed! Character: %@", event.characters);
        
        [self handleGlobalKeyEvent:event];
        
        // IMPORTANTE: Ritorna l'evento per permettere al sistema di gestirlo normalmente
        return event;
    }];
    
    if (self.globalKeyboardMonitor) {
        NSLog(@"✅ Local keyboard monitor created successfully");
    } else {
        NSLog(@"❌ Failed to create local keyboard monitor!");
    }
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
        // Se già visibile, non fare nulla - lascia che il search field gestisca
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
