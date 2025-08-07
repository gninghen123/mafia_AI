//
//  ObjectsPanel.m
//  TradingApp
//

#import "ObjectsPanel.h"
#import <QuartzCore/QuartzCore.h>

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
    // NEW: Lock Creation Toggle
     self.lockCreationToggle = [NSButton buttonWithTitle:@"🔒 Lock"
                                                   target:self
                                                   action:@selector(toggleLockMode:)];
     self.lockCreationToggle.translatesAutoresizingMaskIntoConstraints = NO;
     self.lockCreationToggle.bezelStyle = NSBezelStyleRounded;
     self.lockCreationToggle.buttonType = NSButtonTypePushOnPushOff; // Toggle behavior
     self.lockCreationToggle.controlSize = NSControlSizeSmall;
     self.lockCreationToggle.font = [NSFont systemFontOfSize:10];
     [self.backgroundView addSubview:self.lockCreationToggle];
    
    
    // Main stack view for object buttons
    self.buttonsStackView = [[NSStackView alloc] init];
    self.buttonsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.buttonsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.buttonsStackView.spacing = 6;
    self.buttonsStackView.alignment = NSLayoutAttributeLeading;
    self.buttonsStackView.distribution = NSStackViewDistributionFillEqually;
    
    [self addSubview:self.buttonsStackView];
    
    // Separator line
    self.separatorView = [[NSView alloc] init];
    self.separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.separatorView.wantsLayer = YES;
    self.separatorView.layer.backgroundColor = [NSColor separatorColor].CGColor;
    
    [self addSubview:self.separatorView];
    
    // Object Manager button at bottom
    self.objectManagerButton = [NSButton buttonWithTitle:@"Manage Objects..."
                                                  target:self
                                                  action:@selector(showObjectManager:)];
    self.objectManagerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectManagerButton.bezelStyle = NSBezelStyleRounded;
    self.objectManagerButton.controlSize = NSControlSizeSmall;
    self.objectManagerButton.font = [NSFont systemFontOfSize:11];
    self.objectManagerButton.toolTip = @"Open Object Manager window";
    
    [self addSubview:self.objectManagerButton];
    
    // SIDEBAR PATTERN: Width constraint sempre fissa
    [self.widthAnchor constraintEqualToConstant:self.panelWidth].active = YES;
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Title
        [titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        
        // NEW: Lock toggle
        [self.lockCreationToggle.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [self.lockCreationToggle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.lockCreationToggle.widthAnchor constraintEqualToConstant:80],
        [self.lockCreationToggle.heightAnchor constraintEqualToConstant:20],
        
        // Buttons stack (updated topAnchor)
        [self.buttonsStackView.topAnchor constraintEqualToAnchor:self.lockCreationToggle.bottomAnchor constant:12],
        [self.buttonsStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.buttonsStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        
        // Separator line (unchanged)
        [self.separatorView.topAnchor constraintEqualToAnchor:self.buttonsStackView.bottomAnchor constant:12],
        [self.separatorView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.separatorView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.separatorView.heightAnchor constraintEqualToConstant:0.5],
        
        // Object Manager button (unchanged)
        [self.objectManagerButton.topAnchor constraintEqualToAnchor:self.separatorView.bottomAnchor constant:12],
        [self.objectManagerButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.objectManagerButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.objectManagerButton.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-12]
    ]];
}

- (void)createObjectButtons {
    NSArray<NSDictionary *> *objectTypes = @[
        @{@"title": @"Horizontal Line", @"type": @(ChartObjectTypeHorizontalLine)},
        @{@"title": @"Trend Line", @"type": @(ChartObjectTypeTrendline)},
        @{@"title": @"Rectangle", @"type": @(ChartObjectTypeRectangle)},
        @{@"title": @"Fibonacci", @"type": @(ChartObjectTypeFibonacci)},
        @{@"title": @"Trailing Fibo", @"type": @(ChartObjectTypeTrailingFibo)},
        @{@"title": @"Trailing Between", @"type": @(ChartObjectTypeTrailingFiboBetween)}
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
    NSLog(@"🎨 ObjectsPanel: Created %lu object buttons with toggle behavior", (unsigned long)buttons.count);
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
        
        if ([self.delegate respondsToSelector:@selector(objectsPanel:didDeactivateObjectType:)]) {
            [self.delegate objectsPanel:self didDeactivateObjectType:objectType];
        }
        
        NSLog(@"⚪ ObjectsPanel: Deactivated %@", sender.title);
    }
}

- (void)showObjectManager:(NSButton *)sender {
    NSLog(@"🎨 ObjectsPanel: Object Manager button clicked");
    
    if ([self.delegate respondsToSelector:@selector(objectsPanelDidRequestShowManager:)]) {
        [self.delegate objectsPanelDidRequestShowManager:self];
    }
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

@end
