//
//  ObjectsPanel.m
//  TradingApp
//

#import "ObjectsPanel.h"
#import <QuartzCore/QuartzCore.h>
#import "ChartObjectManagerWindow.h"
#import "DataHub.h"


@interface ObjectsPanel ()
@property (nonatomic, strong, readwrite) NSStackView *buttonsStackView;
@property (nonatomic, strong, readwrite) NSButton *objectManagerButton;
@property (nonatomic, strong, readwrite) NSArray<NSButton *> *objectButtons;
@property (nonatomic, strong, readwrite) NSVisualEffectView *backgroundView;
@property (nonatomic, strong) NSView *separatorView;



@end

@implementation ObjectsPanel

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _panelWidth = 180;
    _isVisible = NO;
    
    [self setupBackgroundView];
    [self setupLayout];
    [self createObjectButtons];
    [self setupInitialState];
    
    NSLog(@"🎨 ObjectsPanel: Initialized with width %.1f", _panelWidth);
}

#pragma mark - UI Setup

- (void)setupBackgroundView {
    self.backgroundView = [[NSVisualEffectView alloc] init];
    self.backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundView.material = NSVisualEffectMaterialSidebar;
    self.backgroundView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.backgroundView.state = NSVisualEffectStateActive;
    
    // Subtle border
    self.backgroundView.wantsLayer = YES;
    self.backgroundView.layer.borderColor = [NSColor separatorColor].CGColor;
    self.backgroundView.layer.borderWidth = 0.5;
    self.backgroundView.layer.cornerRadius = 8.0;
    
    [self addSubview:self.backgroundView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.backgroundView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.backgroundView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.backgroundView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (void)setupLayout {
    // Title label
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.stringValue = @"Drawing Tools";
    titleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    titleLabel.textColor = [NSColor secondaryLabelColor];
    titleLabel.alignment = NSTextAlignmentCenter;
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    
    [self addSubview:titleLabel];
    
    // RIGA DI CONTROLLI: Lock e Clear All affiancati
    NSView *controlsRow = [[NSView alloc] init];
    controlsRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backgroundView addSubview:controlsRow];
    
    // Lock button
    self.lockCreationToggle = [NSButton buttonWithTitle:@"🔒 Lock"
                                                   target:self
                                                   action:@selector(toggleLockMode:)];
    self.lockCreationToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.lockCreationToggle.bezelStyle = NSBezelStyleRounded;
    self.lockCreationToggle.buttonType = NSButtonTypePushOnPushOff;
    self.lockCreationToggle.controlSize = NSControlSizeSmall;
    self.lockCreationToggle.font = [NSFont systemFontOfSize:10];
    [controlsRow addSubview:self.lockCreationToggle];
    
    // Clear All button
    NSButton *clearAllButton = [NSButton buttonWithTitle:@"🗑️ Clear"
                                                   target:self
                                                   action:@selector(clearAllObjects:)];
    clearAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    clearAllButton.bezelStyle = NSBezelStyleRounded;
    clearAllButton.controlSize = NSControlSizeSmall;
    clearAllButton.font = [NSFont systemFontOfSize:10];
    clearAllButton.contentTintColor = [NSColor systemRedColor];
    [controlsRow addSubview:clearAllButton];
    
    // Main stack view for object buttons
    self.buttonsStackView = [[NSStackView alloc] init];
    self.buttonsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.buttonsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.buttonsStackView.spacing = 6;
    self.buttonsStackView.alignment = NSLayoutAttributeCenterX;
    [self.backgroundView addSubview:self.buttonsStackView];
        
    // Separator line
    self.separatorView = [[NSView alloc] init];
    self.separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.separatorView.wantsLayer = YES;
    self.separatorView.layer.backgroundColor = [NSColor separatorColor].CGColor;
    [self.backgroundView addSubview:self.separatorView];
    
    // Object Manager button
    self.objectManagerButton = [NSButton buttonWithTitle:@"⚙️ Manage Objects"
                                                   target:self
                                                   action:@selector(showObjectManager:)];
    self.objectManagerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectManagerButton.bezelStyle = NSBezelStyleRounded;
    self.objectManagerButton.controlSize = NSControlSizeSmall;
    self.objectManagerButton.font = [NSFont systemFontOfSize:11];
    [self.backgroundView addSubview:self.objectManagerButton];
    
    // CONSTRAINTS AGGIORNATE - NON PIÙ SOVRAPPOSTE
    [NSLayoutConstraint activateConstraints:@[
        // Title
        [titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        
        // Controls row (Lock + Clear All)
        [controlsRow.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [controlsRow.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [controlsRow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [controlsRow.heightAnchor constraintEqualToConstant:24],
        
        // Lock button (metà sinistra)
        [self.lockCreationToggle.leadingAnchor constraintEqualToAnchor:controlsRow.leadingAnchor],
        [self.lockCreationToggle.centerYAnchor constraintEqualToAnchor:controlsRow.centerYAnchor],
        [self.lockCreationToggle.widthAnchor constraintEqualToConstant:75],
        [self.lockCreationToggle.heightAnchor constraintEqualToConstant:20],
        
        // Clear All button (metà destra)
        [clearAllButton.trailingAnchor constraintEqualToAnchor:controlsRow.trailingAnchor],
        [clearAllButton.centerYAnchor constraintEqualToAnchor:controlsRow.centerYAnchor],
        [clearAllButton.widthAnchor constraintEqualToConstant:75],
        [clearAllButton.heightAnchor constraintEqualToConstant:20],
        
        // Buttons stack
        [self.buttonsStackView.topAnchor constraintEqualToAnchor:controlsRow.bottomAnchor constant:12],
        [self.buttonsStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.buttonsStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        
        // Separator line
        [self.separatorView.topAnchor constraintEqualToAnchor:self.buttonsStackView.bottomAnchor constant:12],
        [self.separatorView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.separatorView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.separatorView.heightAnchor constraintEqualToConstant:0.5],
        
        // Object Manager button
        [self.objectManagerButton.topAnchor constraintEqualToAnchor:self.separatorView.bottomAnchor constant:12],
        [self.objectManagerButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.objectManagerButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.objectManagerButton.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-12]
    ]];
}


- (void)createObjectButtons {
    // AGGIORNATO: Includi TUTTI gli oggetti implementati
    NSArray<NSDictionary *> *objectTypes = @[
        @{@"title": @"Horizontal Line", @"type": @(ChartObjectTypeHorizontalLine)},
        @{@"title": @"Trend Line", @"type": @(ChartObjectTypeTrendline)},
        @{@"title": @"Rectangle", @"type": @(ChartObjectTypeRectangle)},
        @{@"title": @"Fibonacci", @"type": @(ChartObjectTypeFibonacci)},
        @{@"title": @"Trailing Fibo", @"type": @(ChartObjectTypeTrailingFibo)},
        @{@"title": @"Trailing Between", @"type": @(ChartObjectTypeTrailingFiboBetween)},
        @{@"title": @"Channel", @"type": @(ChartObjectTypeChannel)},        // AGGIUNTO
        @{@"title": @"Target", @"type": @(ChartObjectTypeTarget)},
        @{@"title": @"Free Draw", @"type": @(ChartObjectTypeFreeDrawing)},  
        @{@"title": @"Circle", @"type": @(ChartObjectTypeCircle)}
    ];
    
    NSMutableArray<NSButton *> *buttons = [[NSMutableArray alloc] init];
    
    for (NSDictionary *objType in objectTypes) {
        NSButton *button = [NSButton buttonWithTitle:objType[@"title"]
                                              target:self
                                              action:@selector(objectButtonClicked:)];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.bezelStyle = NSBezelStyleRounded;
        button.controlSize = NSControlSizeSmall;
        button.font = [NSFont systemFontOfSize:11];
        button.tag = [objType[@"type"] integerValue];
        button.alignment = NSTextAlignmentLeft;
        
        // IMPORTANT: Push-On-Push-Off behavior for toggle
        button.buttonType = NSButtonTypePushOnPushOff;
        
        [self.buttonsStackView addArrangedSubview:button];
        [buttons addObject:button];
        
        [button.widthAnchor constraintEqualToConstant:164].active = YES;
    }
    
    self.objectButtons = [buttons copy];
    NSLog(@"🎨 ObjectsPanel: Created %lu object buttons including Channel and Target", (unsigned long)buttons.count);
}

- (void)setupInitialState {
    // SIDEBAR PATTERN: Start nascosto senza conflitti di constraint
    self.hidden = YES;
    self.isVisible = NO;
    
    NSLog(@"🎨 ObjectsPanel: Initial state - hidden");
}

#pragma mark - Actions

// SOSTITUIRE il metodo objectButtonClicked esistente:
- (void)objectButtonClicked:(NSButton *)sender {
    ChartObjectType objectType = (ChartObjectType)sender.tag;
    
    NSLog(@"🎨 ObjectsPanel: Button clicked for type %ld, state: %ld",
          (long)objectType, (long)sender.state);
    
    if (sender.state == NSControlStateValueOn) {
        // Button pressed IN - activate
        [self setActiveButton:sender forType:objectType];
        
        if ([self.delegate respondsToSelector:@selector(objectsPanel:didActivateObjectType:withLockMode:)]) {
            [self.delegate objectsPanel:self
                   didActivateObjectType:objectType
                            withLockMode:self.isLockModeEnabled];
        }
        
        NSLog(@"🔘 ObjectsPanel: Activated %@ (Lock: %@)",
              sender.title, self.isLockModeEnabled ? @"ON" : @"OFF");
    } else {
        // Button pressed OUT - deactivate
        [self clearActiveButton];
        
      
        NSLog(@"⭕ ObjectsPanel: Deactivated drawing mode");
    }
    
    // ✅ NUOVO: Refresh manager se è aperto (dopo creazione oggetti)
    [self refreshObjectManager];
}
#pragma mark - ChartObjectManager Integration

- (void)showObjectManager:(NSButton *)sender {
    NSLog(@"⚙️ ObjectsPanel: Opening Object Manager");
    
    // Ottieni riferimenti necessari dal delegate
    DataHub *dataHub = [DataHub shared];
    ChartObjectsManager *objectsManager = nil;
    NSString *currentSymbol = @"UNKNOWN";
    
    // Ottieni objectsManager e currentSymbol dal delegate
    if ([self.delegate respondsToSelector:@selector(objectsManager)]) {
        objectsManager = [self.delegate performSelector:@selector(objectsManager)];
    }
    
    if ([self.delegate respondsToSelector:@selector(currentSymbol)]) {
        currentSymbol = [self.delegate performSelector:@selector(currentSymbol)] ?: @"UNKNOWN";
    }
    
    if (!objectsManager) {
        NSLog(@"❌ ObjectsPanel: No objects manager available");
        return;
    }
    
    if (!self.objectManagerWindow) {
        // Crea la finestra manager
        self.objectManagerWindow = [[ChartObjectManagerWindow alloc]
                                   initWithObjectsManager:objectsManager
                                                  dataHub:dataHub
                                                   symbol:currentSymbol];
        
        // Configura posizionamento finestra intelligente
        [self positionManagerWindow];
        
        NSLog(@"✅ Created ChartObjectManagerWindow for symbol: %@", currentSymbol);
    } else {
        // Aggiorna per il symbol corrente
        [self.objectManagerWindow updateForSymbol:currentSymbol];
    }
    
    // Mostra la finestra
    [self.objectManagerWindow makeKeyAndOrderFront:nil];
    
    NSLog(@"🪟 ChartObjectManagerWindow opened and brought to front");
}

- (void)updateManagerForSymbol:(NSString *)symbol {
    if (self.objectManagerWindow && symbol) {
        [self.objectManagerWindow updateForSymbol:symbol];
        NSLog(@"🔄 ObjectsPanel: Updated manager for symbol %@", symbol);
    } else if (self.objectManagerWindow) {
        NSLog(@"⚠️ ObjectsPanel: Manager window exists but symbol is nil");
    } else {
        NSLog(@"💡 ObjectsPanel: No manager window to update (will create when needed)");
    }
}

- (void)refreshObjectManager {
    if (self.objectManagerWindow) {
        [self.objectManagerWindow refreshContent];
        NSLog(@"🔄 ObjectsPanel: Refreshed manager content");
    } else {
        NSLog(@"💡 ObjectsPanel: No manager window to refresh");
    }
}
#pragma mark - Private Helper Methods

- (void)positionManagerWindow {
    if (!self.objectManagerWindow || !self.window) return;
    
    // Ottieni frame del panel corrente in screen coordinates
    NSRect panelScreenFrame = [self.window convertRectToScreen:self.frame];
    NSRect managerFrame = self.objectManagerWindow.frame;
    
    // Posiziona la finestra manager
    if (self.isVisible) {
        // Se il panel è visibile, posiziona a destra
        managerFrame.origin.x = panelScreenFrame.origin.x + panelScreenFrame.size.width + 10;
        managerFrame.origin.y = panelScreenFrame.origin.y;
    } else {
        // Se il panel è nascosto, posiziona dove sarebbe stato il panel
        NSRect windowFrame = self.window.frame;
        managerFrame.origin.x = windowFrame.origin.x + 20; // Margine dal bordo
        managerFrame.origin.y = windowFrame.origin.y + windowFrame.size.height - managerFrame.size.height - 60; // Sotto la toolbar
    }
    
    // Assicurati che sia visibile sullo schermo
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
    
    // Aggiusta X se esce dal bordo destro
    if (managerFrame.origin.x + managerFrame.size.width > screenFrame.origin.x + screenFrame.size.width) {
        managerFrame.origin.x = screenFrame.origin.x + screenFrame.size.width - managerFrame.size.width - 20;
    }
    
    // Aggiusta Y se esce dai bordi
    if (managerFrame.origin.y + managerFrame.size.height > screenFrame.origin.y + screenFrame.size.height) {
        managerFrame.origin.y = screenFrame.origin.y + screenFrame.size.height - managerFrame.size.height - 20;
    }
    
    if (managerFrame.origin.y < screenFrame.origin.y) {
        managerFrame.origin.y = screenFrame.origin.y + 20;
    }
    
    [self.objectManagerWindow setFrame:managerFrame display:NO];
    
    NSLog(@"📍 Positioned manager window at: x=%.0f, y=%.0f", managerFrame.origin.x, managerFrame.origin.y);
}


#pragma mark - Public Methods

- (void)toggleVisibilityAnimated:(BOOL)animated {
    if (self.isVisible) {
        [self hideAnimated:animated];
    } else {
        [self showAnimated:animated];
    }
}

- (void)showAnimated:(BOOL)animated {
    if (self.isVisible) return;
    
    self.isVisible = YES;
    
    // SIDEBAR PATTERN: Solo show/hide, nessuna animazione width
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.25;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            context.allowsImplicitAnimation = YES;
            
            self.hidden = NO;
            
        } completionHandler:^{
            NSLog(@"🎨 ObjectsPanel: Show animation completed");
            
            if ([self.delegate respondsToSelector:@selector(objectsPanel:didChangeVisibility:)]) {
                [self.delegate objectsPanel:self didChangeVisibility:YES];
            }
        }];
    } else {
        self.hidden = NO;
        
        if ([self.delegate respondsToSelector:@selector(objectsPanel:didChangeVisibility:)]) {
            [self.delegate objectsPanel:self didChangeVisibility:YES];
        }
    }
}

- (void)hideAnimated:(BOOL)animated {
    if (!self.isVisible) return;
    
    self.isVisible = NO;
    
    // SIDEBAR PATTERN: Solo show/hide, nessuna animazione width
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.25;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            context.allowsImplicitAnimation = YES;
            
            self.hidden = YES;
            
        } completionHandler:^{
            NSLog(@"🎨 ObjectsPanel: Hide animation completed");
            
            if ([self.delegate respondsToSelector:@selector(objectsPanel:didChangeVisibility:)]) {
                [self.delegate objectsPanel:self didChangeVisibility:NO];
            }
        }];
    } else {
        self.hidden = YES;
        
        if ([self.delegate respondsToSelector:@selector(objectsPanel:didChangeVisibility:)]) {
            [self.delegate objectsPanel:self didChangeVisibility:NO];
        }
    }
}

- (void)updateButtonStatesWithActiveType:(ChartObjectType)activeType {
    for (NSButton *button in self.objectButtons) {
        if (button.tag == activeType) {
            button.state = NSControlStateValueOn;
        } else {
            button.state = NSControlStateValueOff;
        }
    }
}

#pragma mark - Private Methods

- (void)highlightButton:(NSButton *)button {
    // Temporary visual feedback
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @1.0;
    scaleAnimation.toValue = @0.95;
    scaleAnimation.duration = 0.1;
    scaleAnimation.autoreverses = YES;
    
    [button.layer addAnimation:scaleAnimation forKey:@"buttonPress"];
}


- (void)toggleLockMode:(NSButton *)sender {
    self.isLockModeEnabled = (sender.state == NSControlStateValueOn);
    
    NSLog(@"🔒 ObjectsPanel: Lock mode %@", self.isLockModeEnabled ? @"ENABLED" : @"DISABLED");
    
    // Update button title
    sender.title = self.isLockModeEnabled ? @"🔓 Lock" : @"🔒 Lock";
}

- (ChartObjectType)getActiveObjectType {
    return self.currentActiveButton ? self.currentActiveObjectType : -1;
}

- (void)clearActiveButton {
    if (self.currentActiveButton) {
        self.currentActiveButton.state = NSControlStateValueOff;
        self.currentActiveButton = nil;
        self.currentActiveObjectType = -1;
        
        NSLog(@"🔄 ObjectsPanel: Cleared active button");
    }
}


- (void)clearAllObjects:(NSButton *)sender {
    NSLog(@"🗑️ ObjectsPanel: Clear All objects requested");
    
    // Conferma dialog (codice esistente)
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Clear All Objects";
    alert.informativeText = @"Are you sure you want to delete all chart objects? This action cannot be undone.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Delete All"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        // User confirmed - notify delegate
        if ([self.delegate respondsToSelector:@selector(objectsPanelDidRequestClearAll:)]) {
            [self.delegate objectsPanelDidRequestClearAll:self];
            
            // ✅ NUOVO: Refresh manager dopo clear all
            [self refreshObjectManager];
        }
    }
}


- (void)setActiveButton:(NSButton *)button forType:(ChartObjectType)type {
    // Clear any existing active button first (only one can be active)
    [self clearActiveButton];
    
    // Set new active button
    self.currentActiveButton = button;
    self.currentActiveObjectType = type;
    button.state = NSControlStateValueOn;
}

- (void)objectCreationCompleted {
    // Called when object creation is finished
    if (!self.isLockModeEnabled) {
        [self clearActiveButton];
        NSLog(@"✅ ObjectsPanel: Object completed - button cleared (no lock)");
    } else {
        NSLog(@"🔒 ObjectsPanel: Object completed - button stays active (lock mode)");
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    // Chiudi la finestra manager quando il panel viene deallocato
    if (self.objectManagerWindow) {
        [self.objectManagerWindow close];
        self.objectManagerWindow = nil;
    }
}

@end
