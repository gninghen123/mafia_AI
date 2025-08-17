//
//  FloatingWidgetWindow.m - FIXED VERSION
//  mafia_AI
//
//  Finestra fluttuante per contenere widget singoli
//

#import "FloatingWidgetWindow.h"
#import "BaseWidget.h"
#import "AppDelegate.h"
#import "ChartWidget.h"

@interface FloatingWidgetWindow ()
@property (nonatomic, strong) NSView *containerView;
@end

@implementation FloatingWidgetWindow

#pragma mark - Initialization

- (instancetype)initWithWidget:(BaseWidget *)widget
                         title:(NSString *)title
                          size:(NSSize)size
                   appDelegate:(AppDelegate *)appDelegate {
    
    NSRect contentRect = NSMakeRect(100, 100, size.width, size.height);
    
    self = [super initWithContentRect:contentRect
                            styleMask:NSWindowStyleMaskTitled |
                                     NSWindowStyleMaskClosable |
                                     NSWindowStyleMaskMiniaturizable |
                                     NSWindowStyleMaskResizable
                              backing:NSBackingStoreBuffered
                                defer:NO];
    
    if (self) {
        self.containedWidget = widget;
        self.appDelegate = appDelegate;
        self.widgetType = NSStringFromClass([widget class]);
        
        // Basic window setup
        self.title = title;
        self.delegate = self;
        self.releasedWhenClosed = NO;
        
        // Configure window behavior
        [self configureWindowBehavior];
        
        // Setup widget container
        [self setupWidgetContainer];
        
        // Restore previous state if available
        [self restoreWindowState];
        
        NSLog(@"🪟 FloatingWidgetWindow: Created floating window for %@ widget", self.widgetType);
    }
    
    return self;
}

#pragma mark - Widget Management

- (void)setupWidgetContainer {
    // Create container view
    self.containerView = [[NSView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.containerView];
    
    // Setup widget view
    if (self.containedWidget && self.containedWidget.view) {
        self.containedWidget.view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.containerView addSubview:self.containedWidget.view];
        
        // NUOVO: Configurazione speciale per ChartWidget microscopio
        if ([self.containedWidget isKindOfClass:[ChartWidget class]]) {
            ChartWidget *chartWidget = (ChartWidget *)self.containedWidget;
            
            // Assicurati che il ChartWidget sia configurato per floating window
            NSLog(@"🔬 FloatingWidgetWindow: Configuring ChartWidget for microscope display");
            
            // Il ChartWidget potrebbe aver bisogno di setup aggiuntivo per floating window
            // (questa parte può essere espansa in futuro se necessario)
        }
        
        // Auto Layout constraints per riempire completamente la finestra
        [NSLayoutConstraint activateConstraints:@[
            [self.containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [self.containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [self.containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [self.containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            
            [self.containedWidget.view.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
            [self.containedWidget.view.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
            [self.containedWidget.view.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
            [self.containedWidget.view.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor]
        ]];
        
        NSLog(@"✅ FloatingWidgetWindow: Widget view setup complete for %@", NSStringFromClass([self.containedWidget class]));
    } else {
        NSLog(@"⚠️ FloatingWidgetWindow: No widget view to setup");
    }
}

- (void)configureWindowBehavior {
    // Window appearance
    self.backgroundColor = [NSColor windowBackgroundColor];
    self.hasShadow = YES;
    self.movableByWindowBackground = YES;
    
    // Window level - stay above main window but below other floating windows
    self.level = NSFloatingWindowLevel;
    
    // Collection behavior
    self.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace |
                             NSWindowCollectionBehaviorFullScreenAuxiliary;
    
    // Minimum size
    self.minSize = NSMakeSize(300, 200);
    
    // ✅ FIX: SIMPLIFIED restoration setup to avoid crash
    // Only set restoration if we properly implement the protocol
    if ([FloatingWidgetWindow conformsToProtocol:@protocol(NSWindowRestoration)]) {
        self.restorationClass = [FloatingWidgetWindow class];
        self.identifier = [NSString stringWithFormat:@"FloatingWidget_%@_%p",
                          self.widgetType, (void *)self];
        NSLog(@"✅ FloatingWidgetWindow: Window restoration enabled");
    } else {
        NSLog(@"⚠️ FloatingWidgetWindow: Window restoration disabled (protocol not implemented)");
    }
}

#pragma mark - Window State Management

- (void)saveWindowState {
    NSString *baseKey = self.isMicroscopeWindow ? @"MicroscopeWindow" : @"FloatingWindow";
    NSString *key = [NSString stringWithFormat:@"%@_%@_Frame", baseKey, self.widgetType];
    NSString *frameString = NSStringFromRect(self.frame);
    [[NSUserDefaults standardUserDefaults] setObject:frameString forKey:key];
    
    NSLog(@"💾 FloatingWidgetWindow: Saved %@ state: %@",
          self.isMicroscopeWindow ? @"microscope" : @"floating", frameString);
}


- (void)restoreWindowState {
    NSString *baseKey = self.isMicroscopeWindow ? @"MicroscopeWindow" : @"FloatingWindow";
    NSString *key = [NSString stringWithFormat:@"%@_%@_Frame", baseKey, self.widgetType];
    NSString *frameString = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    
    if (frameString) {
        NSRect frame = NSRectFromString(frameString);
        if (!NSIsEmptyRect(frame)) {
            [self setFrame:frame display:NO];
            NSLog(@"🔄 FloatingWidgetWindow: Restored %@ state: %@",
                  self.isMicroscopeWindow ? @"microscope" : @"floating", frameString);
        }
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    NSLog(@"🗑️ FloatingWidgetWindow: Window closing for %@", self.widgetType);
    
    // Save state before closing
    [self saveWindowState];
    
    // Notify AppDelegate to unregister this window
    if (self.appDelegate) {
        [self.appDelegate unregisterFloatingWindow:self];
    }
    
    // Clean up widget
    if (self.containedWidget) {
        [self.containedWidget.view removeFromSuperview];
        self.containedWidget = nil;
    }
}

- (void)windowDidResize:(NSNotification *)notification {
    // Auto-save state on resize
    [self saveWindowState];
}

- (void)windowDidMove:(NSNotification *)notification {
    // Auto-save state on move
    [self saveWindowState];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    // Always allow closing
    return YES;
}

#pragma mark - NSWindowRestoration Protocol

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
    
    NSLog(@"🔄 FloatingWidgetWindow: Attempting to restore window: %@", identifier);
    
    // ✅ FIX: Proper restoration implementation
    // For now, we'll let AppDelegate handle this manually
    // This prevents crashes while maintaining the protocol conformance
    
    NSError *error = [NSError errorWithDomain:@"FloatingWidgetWindow"
                                         code:501
                                     userInfo:@{NSLocalizedDescriptionKey: @"Manual restoration via AppDelegate preferred"}];
    
    // Return nil window to indicate we'll handle restoration manually
    completionHandler(nil, error);
}

// ✅ FIX: Implement required restoration method
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    
    // Encode our custom state
    if (self.widgetType) {
        [coder encodeObject:self.widgetType forKey:@"widgetType"];
    }
    [coder encodeRect:self.frame forKey:@"windowFrame"];
    
    NSLog(@"💾 FloatingWidgetWindow: Encoded restorable state for %@", self.widgetType);
}

- (void)restoreStateWithCoder:(NSCoder *)coder {
    [super restoreStateWithCoder:coder];
    
    // Restore our custom state
    self.widgetType = [coder decodeObjectForKey:@"widgetType"];
    NSRect frame = [coder decodeRectForKey:@"windowFrame"];
    
    if (!NSIsEmptyRect(frame)) {
        [self setFrame:frame display:NO];
    }
    
    NSLog(@"🔄 FloatingWidgetWindow: Restored state from coder for %@", self.widgetType);
}

#pragma mark - Cleanup

- (void)dealloc {
    NSLog(@"♻️ FloatingWidgetWindow: Deallocating window for %@", self.widgetType);
}

- (BOOL)isMicroscopeWindow {
    return [self.title hasPrefix:@"🔬"] && [self.containedWidget isKindOfClass:[ChartWidget class]];
}

@end
