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
    
    [self setupBackgroundView];
    [self setupLayout];
    [self createObjectButtons];
    
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
    NSTextField *titleLabel = [NSTextField labelWithString:@"Drawing Tools"];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [NSFont boldSystemFontOfSize:12];
    titleLabel.alignment = NSTextAlignmentCenter;
    
    [self addSubview:titleLabel];
    
    // Controls row
    NSView *controlsRow = [[NSView alloc] init];
    controlsRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:controlsRow];
    
    // Lock mode toggle
    self.lockCreationToggle = [NSButton buttonWithTitle:@"🔒 Lock"
                                                 target:self
                                                 action:@selector(toggleLockMode:)];
    self.lockCreationToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.lockCreationToggle.bezelStyle = NSBezelStyleRounded;
    self.lockCreationToggle.buttonType = NSButtonTypePushOnPushOff;
    self.lockCreationToggle.font = [NSFont systemFontOfSize:10];
    self.lockCreationToggle.toolTip = @"Lock creation mode - stays active after placing object";
    [controlsRow addSubview:self.lockCreationToggle];
    
    // Clear all button
    NSButton *clearAllButton = [NSButton buttonWithTitle:@"Clear All"
                                                 target:self
                                                 action:@selector(clearAllObjects:)];
    clearAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    clearAllButton.bezelStyle = NSBezelStyleRounded;
    clearAllButton.font = [NSFont systemFontOfSize:10];
    clearAllButton.toolTip = @"Delete all objects";
    clearAllButton.bezelColor = NSColor.systemRedColor;
    [self addSubview:clearAllButton];
    
    // NEW: Snap controls row
    NSView *snapRow = [[NSView alloc] init];
    snapRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:snapRow];
    
    // Snap icon (magnete)
    self.snapIconLabel = [NSTextField labelWithString:@"🧲"];
    self.snapIconLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.snapIconLabel.font = [NSFont systemFontOfSize:14];
    self.snapIconLabel.toolTip = @"Snap to OHLC values";
    [snapRow addSubview:self.snapIconLabel];
    
    // Snap intensity slider (0-10)
    self.snapIntensitySlider = [[NSSlider alloc] init];
    self.snapIntensitySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.snapIntensitySlider.sliderType = NSSliderTypeLinear;
    self.snapIntensitySlider.minValue = 0.0;
    self.snapIntensitySlider.maxValue = 10.0;
    self.snapIntensitySlider.numberOfTickMarks = 11;
    self.snapIntensitySlider.allowsTickMarkValuesOnly = YES;
    self.snapIntensitySlider.tickMarkPosition = NSTickMarkPositionBelow;
    
    // Load from UserDefaults
    CGFloat savedIntensity = [[NSUserDefaults standardUserDefaults] floatForKey:@"ChartSnapIntensity"];
    self.snapIntensitySlider.doubleValue = savedIntensity;
    
    self.snapIntensitySlider.target = self;
    self.snapIntensitySlider.action = @selector(snapIntensityChanged:);
    self.snapIntensitySlider.toolTip = @"Snap: 0=off, 10=strong";
    [snapRow addSubview:self.snapIntensitySlider];
    
    // Snap value label
    self.snapValueLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"%.0f", savedIntensity]];
    self.snapValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.snapValueLabel.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular];
    self.snapValueLabel.alignment = NSTextAlignmentCenter;
    [snapRow addSubview:self.snapValueLabel];
    
    // Buttons stack view
    self.buttonsStackView = [[NSStackView alloc] init];
    self.buttonsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.buttonsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.buttonsStackView.alignment = NSLayoutAttributeLeading;
    self.buttonsStackView.spacing = 4;
    
    [self addSubview:self.buttonsStackView];
    
    // Separator line
    self.separatorView = [[NSView alloc] init];
    self.separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.separatorView.wantsLayer = YES;
    self.separatorView.layer.backgroundColor = [NSColor separatorColor].CGColor;
    [self addSubview:self.separatorView];
    
    // Object Manager button
    self.objectManagerButton = [NSButton buttonWithTitle:@"Obj Manager"
                                                  target:self
                                                  action:@selector(showObjectManager:)];
    self.objectManagerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectManagerButton.bezelStyle = NSBezelStyleRounded;
    self.objectManagerButton.font = [NSFont systemFontOfSize:11];
    [self addSubview:self.objectManagerButton];
    
    // ===== ANNOTATIONS SECTION (NEW) =====

    // Separator prima della sezione annotations
    self.annotationsSeparator = [NSBox new];
    self.annotationsSeparator.boxType = NSBoxSeparator;
    self.annotationsSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.annotationsSeparator];

    // Section title
    self.annotationsTitle = [[NSTextField alloc] init];
    self.annotationsTitle.stringValue = @"Annotations:";
    self.annotationsTitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.annotationsTitle.textColor = [NSColor secondaryLabelColor];
    self.annotationsTitle.editable = NO;
    self.annotationsTitle.bordered = NO;
    self.annotationsTitle.backgroundColor = [NSColor clearColor];
    self.annotationsTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.annotationsTitle];

    // Checkboxes
    self.showNewsCheckbox = [self createAnnotationCheckbox:@"📰 News"
                                                        tag:0  // ChartAnnotationTypeNews
                                                   selected:YES];
    [self addSubview:self.showNewsCheckbox];

    self.showNotesCheckbox = [self createAnnotationCheckbox:@"📝 Notes"
                                                         tag:1  // ChartAnnotationTypeNote
                                                    selected:YES];
    [self addSubview:self.showNotesCheckbox];

    self.showMessagesCheckbox = [self createAnnotationCheckbox:@"💬 Messages"
                                                            tag:2  // ChartAnnotationTypeUserMessage
                                                       selected:NO];
    [self addSubview:self.showMessagesCheckbox];

    self.showAlertsCheckbox = [self createAnnotationCheckbox:@"⚠️ Alerts"
                                                          tag:3  // ChartAnnotationTypeAlert
                                                     selected:YES];
    [self addSubview:self.showAlertsCheckbox];

    self.showEventsCheckbox = [self createAnnotationCheckbox:@"📅 Events"
                                                          tag:4  // ChartAnnotationTypeEvent
                                                     selected:NO];
    [self addSubview:self.showEventsCheckbox];

    // Relevance slider row
    self.annotationRelevanceRow = [[NSView alloc] init];
    self.annotationRelevanceRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.annotationRelevanceRow];

    NSTextField *relevanceLabel = [[NSTextField alloc] init];
    relevanceLabel.stringValue = @"Min Score:";
    relevanceLabel.font = [NSFont systemFontOfSize:10];
    relevanceLabel.textColor = [NSColor secondaryLabelColor];
    relevanceLabel.editable = NO;
    relevanceLabel.bordered = NO;
    relevanceLabel.backgroundColor = [NSColor clearColor];
    relevanceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.annotationRelevanceRow addSubview:relevanceLabel];

    self.annotationRelevanceSlider = [[NSSlider alloc] init];
    self.annotationRelevanceSlider.minValue = 0;
    self.annotationRelevanceSlider.maxValue = 100;
    self.annotationRelevanceSlider.doubleValue = 50;
    self.annotationRelevanceSlider.target = self;
    self.annotationRelevanceSlider.action = @selector(annotationRelevanceChanged:);
    self.annotationRelevanceSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.annotationRelevanceRow addSubview:self.annotationRelevanceSlider];

    self.annotationRelevanceLabel = [[NSTextField alloc] init];
    self.annotationRelevanceLabel.stringValue = @"50";
    self.annotationRelevanceLabel.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightMedium];
    self.annotationRelevanceLabel.textColor = [NSColor secondaryLabelColor];
    self.annotationRelevanceLabel.alignment = NSTextAlignmentRight;
    self.annotationRelevanceLabel.editable = NO;
    self.annotationRelevanceLabel.bordered = NO;
    self.annotationRelevanceLabel.backgroundColor = [NSColor clearColor];
    self.annotationRelevanceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.annotationRelevanceRow addSubview:self.annotationRelevanceLabel];

    // ⚠️ IMPORTANTE: Attiva i constraints INTERNI di relevanceRow SUBITO
    [NSLayoutConstraint activateConstraints:@[
        [relevanceLabel.leadingAnchor constraintEqualToAnchor:self.annotationRelevanceRow.leadingAnchor],
        [relevanceLabel.centerYAnchor constraintEqualToAnchor:self.annotationRelevanceRow.centerYAnchor],
        [relevanceLabel.widthAnchor constraintEqualToConstant:70],
        
        [self.annotationRelevanceSlider.leadingAnchor constraintEqualToAnchor:relevanceLabel.trailingAnchor constant:4],
        [self.annotationRelevanceSlider.centerYAnchor constraintEqualToAnchor:self.annotationRelevanceRow.centerYAnchor],
        [self.annotationRelevanceSlider.trailingAnchor constraintEqualToAnchor:self.annotationRelevanceLabel.leadingAnchor constant:-4],
        
        [self.annotationRelevanceLabel.trailingAnchor constraintEqualToAnchor:self.annotationRelevanceRow.trailingAnchor],
        [self.annotationRelevanceLabel.centerYAnchor constraintEqualToAnchor:self.annotationRelevanceRow.centerYAnchor],
        [self.annotationRelevanceLabel.widthAnchor constraintEqualToConstant:30],
        
        [self.annotationRelevanceRow.heightAnchor constraintEqualToConstant:24]
    ]];

    // Add note button
    self.addNoteButton = [NSButton buttonWithTitle:@"+ Add Note"
                                            target:self
                                            action:@selector(addNoteClicked:)];
    self.addNoteButton.bezelStyle = NSBezelStyleRounded;
    self.addNoteButton.controlSize = NSControlSizeSmall;
    self.addNoteButton.font = [NSFont systemFontOfSize:11];
    self.addNoteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.addNoteButton];
    
    // ===== CONSTRAINTS GLOBALI (TUTTI GLI ELEMENTI) =====
    [NSLayoutConstraint activateConstraints:@[
        // Title
        [titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        
        // Controls row
        [controlsRow.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [controlsRow.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [controlsRow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [controlsRow.heightAnchor constraintEqualToConstant:22],
        
        // Lock toggle
        [self.lockCreationToggle.leadingAnchor constraintEqualToAnchor:controlsRow.leadingAnchor],
        [self.lockCreationToggle.centerYAnchor constraintEqualToAnchor:controlsRow.centerYAnchor],
        [self.lockCreationToggle.widthAnchor constraintEqualToConstant:65],
        
        // Clear all button
        [clearAllButton.topAnchor constraintEqualToAnchor:controlsRow.bottomAnchor constant:8],
        [clearAllButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [clearAllButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [clearAllButton.heightAnchor constraintEqualToConstant:20],
        
        // Snap row
        [snapRow.topAnchor constraintEqualToAnchor:clearAllButton.bottomAnchor constant:8],
        [snapRow.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [snapRow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [snapRow.heightAnchor constraintEqualToConstant:22],
        
        // Snap controls
        [self.snapIconLabel.leadingAnchor constraintEqualToAnchor:snapRow.leadingAnchor],
        [self.snapIconLabel.centerYAnchor constraintEqualToAnchor:snapRow.centerYAnchor],
        [self.snapIconLabel.widthAnchor constraintEqualToConstant:20],
        
        [self.snapIntensitySlider.leadingAnchor constraintEqualToAnchor:self.snapIconLabel.trailingAnchor constant:4],
        [self.snapIntensitySlider.centerYAnchor constraintEqualToAnchor:snapRow.centerYAnchor],
        [self.snapIntensitySlider.trailingAnchor constraintEqualToAnchor:self.snapValueLabel.leadingAnchor constant:-4],
        
        [self.snapValueLabel.trailingAnchor constraintEqualToAnchor:snapRow.trailingAnchor],
        [self.snapValueLabel.centerYAnchor constraintEqualToAnchor:snapRow.centerYAnchor],
        [self.snapValueLabel.widthAnchor constraintEqualToConstant:20],
        
        // Buttons stack
        [self.buttonsStackView.topAnchor constraintEqualToAnchor:snapRow.bottomAnchor constant:12],
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
        
        // ===== ANNOTATIONS CONSTRAINTS =====
        
        // Annotations separator
        [self.annotationsSeparator.topAnchor constraintEqualToAnchor:self.objectManagerButton.bottomAnchor constant:16],
        [self.annotationsSeparator.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.annotationsSeparator.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.annotationsSeparator.heightAnchor constraintEqualToConstant:0.5],
        
        // Annotations title
        [self.annotationsTitle.topAnchor constraintEqualToAnchor:self.annotationsSeparator.bottomAnchor constant:12],
        [self.annotationsTitle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        
        // Checkboxes
        [self.showNewsCheckbox.topAnchor constraintEqualToAnchor:self.annotationsTitle.bottomAnchor constant:8],
        [self.showNewsCheckbox.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.showNewsCheckbox.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        
        [self.showNotesCheckbox.topAnchor constraintEqualToAnchor:self.showNewsCheckbox.bottomAnchor constant:4],
        [self.showNotesCheckbox.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.showNotesCheckbox.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        
        [self.showMessagesCheckbox.topAnchor constraintEqualToAnchor:self.showNotesCheckbox.bottomAnchor constant:4],
        [self.showMessagesCheckbox.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.showMessagesCheckbox.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        
        [self.showAlertsCheckbox.topAnchor constraintEqualToAnchor:self.showMessagesCheckbox.bottomAnchor constant:4],
        [self.showAlertsCheckbox.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.showAlertsCheckbox.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        
        [self.showEventsCheckbox.topAnchor constraintEqualToAnchor:self.showAlertsCheckbox.bottomAnchor constant:4],
        [self.showEventsCheckbox.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.showEventsCheckbox.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        
        // Relevance row (SOLO posizionamento - contenuto interno già fatto sopra)
        [self.annotationRelevanceRow.topAnchor constraintEqualToAnchor:self.showEventsCheckbox.bottomAnchor constant:12],
        [self.annotationRelevanceRow.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.annotationRelevanceRow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        
        // Add note button
        [self.addNoteButton.topAnchor constraintEqualToAnchor:self.annotationRelevanceRow.bottomAnchor constant:12],
        [self.addNoteButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.addNoteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [self.addNoteButton.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-12]
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
        @{@"title": @"Trailing F 2CP", @"type": @(ChartObjectTypeTrailingFiboBetween)},
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
        
        [button.widthAnchor constraintEqualToConstant:90].active = YES;
    }
    
    self.objectButtons = [buttons copy];
    NSLog(@"🎨 ObjectsPanel: Created %lu object buttons including Channel and Target", (unsigned long)buttons.count);
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
    
    
   
        // Se il panel è nascosto, posiziona dove sarebbe stato il panel
        NSRect windowFrame = self.window.frame;
        managerFrame.origin.x = windowFrame.origin.x + 20; // Margine dal bordo
        managerFrame.origin.y = windowFrame.origin.y + windowFrame.size.height - managerFrame.size.height - 60; // Sotto la toolbar
    
    
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


- (IBAction)clearAllObjects:(NSButton *)sender {
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

#pragma mark - NEW: Snap Actions

- (void)snapIntensityChanged:(NSSlider *)sender {
    CGFloat intensity = sender.doubleValue;
    
    // Update label con feedback più descrittivo
    if (intensity == 0) {
        self.snapValueLabel.stringValue = @"OFF";
        self.snapValueLabel.textColor = [NSColor secondaryLabelColor];
    } else if (intensity <= 3) {
        self.snapValueLabel.stringValue = [NSString stringWithFormat:@"%.0f", intensity];
        self.snapValueLabel.textColor = [NSColor systemGreenColor];
    } else if (intensity <= 7) {
        self.snapValueLabel.stringValue = [NSString stringWithFormat:@"%.0f", intensity];
        self.snapValueLabel.textColor = [NSColor systemOrangeColor];
    } else {
        self.snapValueLabel.stringValue = [NSString stringWithFormat:@"%.0f", intensity];
        self.snapValueLabel.textColor = [NSColor systemRedColor]; // Super aggressivo
    }
    
    // Save to UserDefaults
    [[NSUserDefaults standardUserDefaults] setFloat:intensity forKey:@"ChartSnapIntensity"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Update icon appearance based on intensity
    if (intensity == 0) {
        self.snapIconLabel.stringValue = @"🚫"; // No snap
        self.snapIconLabel.toolTip = @"Snap disabled";
    } else if (intensity <= 5) {
        self.snapIconLabel.stringValue = @"🧲"; // Normal snap
        self.snapIconLabel.toolTip = [NSString stringWithFormat:@"Normal snap: %.0f", intensity];
    } else {
        self.snapIconLabel.stringValue = @"⚡"; // Super aggressive snap
        self.snapIconLabel.toolTip = [NSString stringWithFormat:@"Super aggressive snap: %.0f", intensity];
    }
    
    NSLog(@"🧲 ObjectsPanel: Snap intensity changed to %.0f (%@)",
          intensity, intensity > 7 ? @"SUPER AGGRESSIVE" : intensity > 0 ? @"ACTIVE" : @"OFF");
}

#pragma mark - NEW: Snap Public Methods

- (CGFloat)getSnapIntensity {
    return self.snapIntensitySlider.doubleValue;
}

- (void)setSnapIntensity:(CGFloat)intensity {
    intensity = MAX(0.0, MIN(10.0, intensity)); // Clamp 0-10
    self.snapIntensitySlider.doubleValue = intensity;
    [self snapIntensityChanged:self.snapIntensitySlider];
}


#pragma mark - Annotation Helpers

- (NSButton *)createAnnotationCheckbox:(NSString *)title tag:(NSInteger)tag selected:(BOOL)selected {
    NSButton *checkbox = [NSButton checkboxWithTitle:title
                                              target:self
                                              action:@selector(annotationCheckboxChanged:)];
    checkbox.tag = tag;
    checkbox.state = selected ? NSControlStateValueOn : NSControlStateValueOff;
    checkbox.font = [NSFont systemFontOfSize:11];
    checkbox.translatesAutoresizingMaskIntoConstraints = NO;
    return checkbox;
}

#pragma mark - Annotation Actions

- (void)annotationCheckboxChanged:(NSButton *)sender {
    NSInteger annotationType = sender.tag;
    BOOL isEnabled = (sender.state == NSControlStateValueOn);
    
    NSLog(@"📍 ObjectsPanel: Annotation type %ld %@", (long)annotationType, isEnabled ? @"enabled" : @"disabled");
    
    // Notifica il delegate (ChartWidget)
    if ([self.delegate respondsToSelector:@selector(objectsPanel:didChangeAnnotationType:enabled:)]) {
        [self.delegate objectsPanel:self didChangeAnnotationType:annotationType enabled:isEnabled];
    }
}

- (void)annotationRelevanceChanged:(NSSlider *)sender {
    NSInteger score = (NSInteger)sender.doubleValue;
    self.annotationRelevanceLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)score];
    
    NSLog(@"📍 ObjectsPanel: Relevance score changed to %ld", (long)score);
    
    // Notifica il delegate
    if ([self.delegate respondsToSelector:@selector(objectsPanel:didChangeMinimumRelevanceScore:)]) {
        [self.delegate objectsPanel:self didChangeMinimumRelevanceScore:score];
    }
}

- (void)addNoteClicked:(id)sender {
    NSLog(@"📝 ObjectsPanel: Add Note clicked");
    
    // Notifica il delegate per aprire finestra creazione nota
    if ([self.delegate respondsToSelector:@selector(objectsPanelDidRequestAddNote:)]) {
        [self.delegate objectsPanelDidRequestAddNote:self];
    }
}


@end
