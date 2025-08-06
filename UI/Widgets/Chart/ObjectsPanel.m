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
        // Title at top
        [titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        
        // Buttons stack in middle
        [self.buttonsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [self.buttonsStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.buttonsStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        
        // Separator line
        [self.separatorView.topAnchor constraintEqualToAnchor:self.buttonsStackView.bottomAnchor constant:12],
        [self.separatorView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.separatorView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.separatorView.heightAnchor constraintEqualToConstant:0.5],
        
        // Object Manager button at bottom
        [self.objectManagerButton.topAnchor constraintEqualToAnchor:self.separatorView.bottomAnchor constant:12],
        [self.objectManagerButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.objectManagerButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.objectManagerButton.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-12]
    ]];
}

- (void)createObjectButtons {
    NSArray<NSDictionary *> *objectTypes = @[
        @{@"title": @"Horizontal Line", @"type": @(ChartObjectTypeHorizontalLine)},
        @{@"title": @"Vertical Line", @"type": @(ChartObjectTypeVerticalLine)},
        @{@"title": @"Trend Line", @"type": @(ChartObjectTypeTrendline)},
        @{@"title": @"Rectangle", @"type": @(ChartObjectTypeRectangle)},
        @{@"title": @"Text Label", @"type": @(ChartObjectTypeText)},
        @{@"title": @"Fibonacci", @"type": @(ChartObjectTypeFibonacci)}
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
        
        [self.buttonsStackView addArrangedSubview:button];
        [buttons addObject:button];
        
        // Pulsanti si adattano alla larghezza del pannello automaticamente
        [button.widthAnchor constraintEqualToConstant:164].active = YES;
    }
    
    self.objectButtons = [buttons copy];
    NSLog(@"🎨 ObjectsPanel: Created %lu object buttons", (unsigned long)buttons.count);
}

- (void)setupInitialState {
    // SIDEBAR PATTERN: Start nascosto senza conflitti di constraint
    self.hidden = YES;
    self.isVisible = NO;
    
    NSLog(@"🎨 ObjectsPanel: Initial state - hidden");
}

#pragma mark - Actions

- (void)objectButtonClicked:(NSButton *)sender {
    ChartObjectType type = (ChartObjectType)sender.tag;
    
    NSLog(@"🎨 ObjectsPanel: Button clicked for type %ld (%@)", (long)type, sender.title);
    
    // Visual feedback - brief highlight
    [self highlightButton:sender];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(objectsPanel:didRequestCreateObjectOfType:)]) {
        [self.delegate objectsPanel:self didRequestCreateObjectOfType:type];
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

@end
