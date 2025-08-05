
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
    self.buttonsStackView.alignment = NSLayoutAttributeLeading; // FISSO: Leading invece di CenterX
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
    
    // Width constraint (animated)
    self.widthConstraint = [self.widthAnchor constraintEqualToConstant:0];
    self.widthConstraint.active = YES;
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Title at top
        [titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        
        // Stack view for buttons - FISSO: constrainte migliori
        [self.buttonsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [self.buttonsStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.buttonsStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.buttonsStackView.widthAnchor constraintGreaterThanOrEqualToConstant:164], // NUOVO: larghezza minima
        
        // Separator line
        [self.separatorView.topAnchor constraintEqualToAnchor:self.buttonsStackView.bottomAnchor constant:12],
        [self.separatorView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.separatorView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.separatorView.heightAnchor constraintEqualToConstant:1],
        
        // Object manager button at bottom
        [self.objectManagerButton.topAnchor constraintEqualToAnchor:self.separatorView.bottomAnchor constant:8],
        [self.objectManagerButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.objectManagerButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.objectManagerButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
        [self.objectManagerButton.heightAnchor constraintEqualToConstant:28]
    ]];
}

- (void)createObjectButtons {
    NSMutableArray<NSButton *> *buttons = [NSMutableArray array];
    
    // Define object types with icons and tooltips
    NSArray<NSDictionary *> *objectTypes = @[
        @{
            @"type": @(ChartObjectTypeTrendline),
            @"title": @"📈 Trendline",
            @"tooltip": @"Draw trend line connecting two points"
        },
        @{
            @"type": @(ChartObjectTypeHorizontalLine),
            @"title": @"📏 Support/Resistance",
            @"tooltip": @"Draw horizontal support or resistance line"
        },
        @{
            @"type": @(ChartObjectTypeFibonacci),
            @"title": @"🌀 Fibonacci",
            @"tooltip": @"Fibonacci retracement levels"
        },
        @{
            @"type": @(ChartObjectTypeText),
            @"title": @"📝 Text Note",
            @"tooltip": @"Add text annotation to chart"
        },
        @{
            @"type": @(ChartObjectTypeTarget),
            @"title": @"🎯 Price Target",
            @"tooltip": @"Set price target with alerts"
        },
        @{
            @"type": @(ChartObjectTypeFreeDrawing),
            @"title": @"✏️ Free Draw",
            @"tooltip": @"Free-form drawing tool"
        },
        @{
            @"type": @(ChartObjectTypeVerticalLine),
            @"title": @"📐 Vertical Line",
            @"tooltip": @"Draw vertical line at specific time"
        },
        @{
            @"type": @(ChartObjectTypeRectangle),
            @"title": @"⬜ Rectangle",
            @"tooltip": @"Draw rectangular area"
        }
    ];
    
    for (NSDictionary *typeInfo in objectTypes) {
        ChartObjectType type = [typeInfo[@"type"] integerValue];
        NSString *title = typeInfo[@"title"];
        NSString *tooltip = typeInfo[@"tooltip"];
        
        NSButton *button = [NSButton buttonWithTitle:title
                                              target:self
                                              action:@selector(objectButtonClicked:)];
        button.tag = type;
        button.bezelStyle = NSBezelStyleRounded;
        button.controlSize = NSControlSizeRegular;
        button.font = [NSFont systemFontOfSize:12];
        button.toolTip = tooltip;
        button.alignment = NSTextAlignmentLeft;
        
        // CRITICO: Assicurati che il bottone abbia auto layout
        button.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Visual styling
        button.wantsLayer = YES;
        button.layer.cornerRadius = 6.0;
        
        [self.buttonsStackView addArrangedSubview:button];
        [buttons addObject:button];
        
        // FISSO: Constraint espliciti per dimensioni bottone
        [NSLayoutConstraint activateConstraints:@[
            [button.heightAnchor constraintEqualToConstant:34],
            // FISSO: Invece di ancorare al stackview, usa width constraint
            [button.widthAnchor constraintGreaterThanOrEqualToConstant:160] // Minimo 160px
        ]];
    }
    
    self.objectButtons = [buttons copy];
    NSLog(@"🎨 ObjectsPanel: Created %lu object buttons with fixed width", (unsigned long)buttons.count);
}

- (void)setupInitialState {
    // Start hidden
    self.hidden = YES;
    self.widthConstraint.constant = 0;
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
    self.hidden = NO;
    
    [self animateToWidth:self.panelWidth animated:animated completion:^{
        NSLog(@"🎨 ObjectsPanel: Show animation completed");
        
        if ([self.delegate respondsToSelector:@selector(objectsPanel:didChangeVisibility:)]) {
            [self.delegate objectsPanel:self didChangeVisibility:YES];
        }
    }];
}

- (void)hideAnimated:(BOOL)animated {
    if (!self.isVisible) return;
    
    self.isVisible = NO;
    
    [self animateToWidth:0 animated:animated completion:^{
        self.hidden = YES;
        NSLog(@"🎨 ObjectsPanel: Hide animation completed");
        
        if ([self.delegate respondsToSelector:@selector(objectsPanel:didChangeVisibility:)]) {
            [self.delegate objectsPanel:self didChangeVisibility:NO];
        }
    }];
}

- (void)updateButtonStatesWithActiveType:(ChartObjectType)activeType {
    for (NSButton *button in self.objectButtons) {
        if (button.tag == activeType) {
            button.state = NSControlStateValueOn;
            button.layer.backgroundColor = [NSColor selectedControlColor].CGColor;
        } else {
            button.state = NSControlStateValueOff;
            button.layer.backgroundColor = [NSColor clearColor].CGColor;
        }
    }
}

#pragma mark - Private Methods

- (void)animateToWidth:(CGFloat)targetWidth animated:(BOOL)animated completion:(void(^)(void))completion {
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.25;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            context.allowsImplicitAnimation = YES;
            
            self.widthConstraint.animator.constant = targetWidth;
            
        } completionHandler:^{
            if (completion) completion();
        }];
    } else {
        self.widthConstraint.constant = targetWidth;
        if (completion) completion();
    }
}

- (void)highlightButton:(NSButton *)button {
    // Brief visual feedback
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @1.0;
    scaleAnimation.toValue = @0.95;
    scaleAnimation.duration = 0.1;
    scaleAnimation.autoreverses = YES;
    
    [button.layer addAnimation:scaleAnimation forKey:@"buttonPress"];
    
    // Color flash
    CGColorRef originalColor = button.layer.backgroundColor;
    button.layer.backgroundColor = [NSColor selectedControlColor].CGColor;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        button.layer.backgroundColor = originalColor;
    });
}

#pragma mark - Accessibility

- (NSString *)accessibilityLabel {
    return @"Chart Drawing Tools Panel";
}

- (NSString *)accessibilityHelp {
    return @"Panel containing tools for drawing objects on charts, such as trendlines, support levels, and annotations";
}

@end
