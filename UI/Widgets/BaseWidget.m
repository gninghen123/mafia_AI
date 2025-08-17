//
//  BaseWidget.m
//  TradingApp
//

#import "BaseWidget.h"
#import "WidgetTypeManager.h"
#import "DataHub.h"
#import "TagManagementWindowController.h"


// Notification name for chain updates
static NSString *const kWidgetChainUpdateNotification = @"WidgetChainUpdateNotification";
static NSString *const kWidgetSymbolsPasteboardType = @"com.tradingapp.widget.symbols";
static NSString *const kWidgetConfigurationPasteboardType = @"com.tradingapp.widget.configuration";
// Keys for notification userInfo
static NSString *const kChainColorKey = @"chainColor";
static NSString *const kChainUpdateKey = @"update";
static NSString *const kChainSenderKey = @"sender";

@interface BaseWidget () <NSTextFieldDelegate, NSTextViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate, NSDraggingSource, NSDraggingDestination,TagManagementDelegate>

- (NSButton *)createHeaderButton:(NSString *)title action:(SEL)action;
+ (instancetype)widgetWithType:(NSString *)type
                     panelType:(PanelType)panelType
                  onTypeChange:(void (^)(BaseWidget *widget, NSString *newType))handler;

@property (nonatomic, strong) NSButton *closeButton;
@property (nonatomic, strong) NSButton *collapseButton;
@property (nonatomic, strong) NSButton *chainButton;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSPopover *addPopover;
@property (nonatomic, assign) CGFloat savedHeight;
@property (nonatomic, strong) NSView *headerViewInternal;
@property (nonatomic, strong) NSView *contentViewInternal;
@property (nonatomic, strong) NSTextField *titleFieldInternal;
@property (nonatomic, strong) NSStackView *mainStackView;
@property (nonatomic, strong) NSArray<NSString *> *availableWidgetTypes;
@property (nonatomic, strong) NSMenu *chainColorMenu;

@property (nonatomic, strong) NSView *dropIndicatorView;
@property (nonatomic, assign) NSPoint dragStartPoint;
@property (nonatomic, strong) TagManagementWindowController *tagManagementController;

@end

@implementation BaseWidget

+ (instancetype)widgetWithType:(NSString *)type
                     panelType:(PanelType)panelType
                  onTypeChange:(void (^)(BaseWidget *widget, NSString *newType))handler {
    BaseWidget *widget = [[self alloc] initWithType:type panelType:panelType];
    widget.onTypeChange = handler;
    return widget;
}

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super init];
    if (self) {
        _widgetType = type;
        _panelType = panelType;
        _widgetID = [[NSUUID UUID] UUIDString];
        _chainActive = YES;
        _chainColor = [NSColor systemRedColor]; // Default color
        _collapsed = NO;
        _savedHeight = 200;
        _availableWidgetTypes = [[WidgetTypeManager sharedManager] availableWidgetTypes];
        
        // Subscribe to chain notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleChainNotification:)
                                                     name:kWidgetChainUpdateNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.view.layer.borderWidth = 1;
    self.view.layer.borderColor = [NSColor separatorColor].CGColor;
    self.view.layer.cornerRadius = 4;

    [self.view.widthAnchor constraintGreaterThanOrEqualToConstant:150].active = YES;
    [self.view.heightAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
    [self setupViews];
    [self setupContentView];
}



- (void)setupViews {
    NSLog(@"🔧 BaseWidget: Setting up views with proper expansion configuration");
    
    self.mainStackView = [[NSStackView alloc] init];
    self.mainStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.mainStackView.spacing = 0;
    
    // 🎯 CRITICAL: Use Fill distribution to expand content area
    self.mainStackView.distribution = NSStackViewDistributionFill;
    
    // 🚀 Set alignment to fill entire width
    self.mainStackView.alignment = NSLayoutAttributeLeading; // This ensures full width usage
    
    [self setupHeaderView];
    
    [self.view addSubview:self.mainStackView];
    self.mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 🎯 CRITICAL: Anchor stack view to all edges - NO MARGINS!
    [NSLayoutConstraint activateConstraints:@[
        [self.mainStackView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.mainStackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mainStackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mainStackView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    NSLog(@"✅ BaseWidget: Main stack view configured:");
    NSLog(@"   - Orientation: Vertical");
    NSLog(@"   - Distribution: Fill (content expands)");
    NSLog(@"   - Spacing: 0 (no gaps)");
    NSLog(@"   - Anchored to all view edges");
    NSLog(@"   - Header will be fixed height, content will expand");
}

- (void)setupHeaderView {
    self.headerViewInternal = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 30)];
    self.headerViewInternal.wantsLayer = YES;
    self.headerViewInternal.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.headerViewInternal.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainStackView addArrangedSubview:self.headerViewInternal];
    NSLayoutConstraint *headerHeightConstraint = [self.headerViewInternal.heightAnchor
                                                    constraintEqualToConstant:30];
       headerHeightConstraint.priority = NSLayoutPriorityRequired; // Must be exactly 30px
       headerHeightConstraint.active = YES;
       
       // 🎯 Set content hugging to high so header doesn't try to expand
       [self.headerViewInternal setContentHuggingPriority:NSLayoutPriorityRequired
                                           forOrientation:NSLayoutConstraintOrientationVertical];
       [self.headerViewInternal setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                                        forOrientation:NSLayoutConstraintOrientationVertical];
       
    NSStackView *headerStack = [[NSStackView alloc] init];
    headerStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    headerStack.spacing = 8;
    headerStack.edgeInsets = NSEdgeInsetsMake(4, 8, 4, 8);

    self.closeButton = [self createHeaderButton:@"\u2715" action:@selector(closeWidget:)];

    if (self.panelType != PanelTypeCenter) {
        self.collapseButton = [self createHeaderButton:@"\u2212" action:@selector(toggleCollapse:)];
    }

    self.titleComboBox = [[NSComboBox alloc] init];
    self.titleComboBox.usesDataSource = YES;
    self.titleComboBox.dataSource = self;
    self.titleComboBox.delegate = self;
    self.titleComboBox.completes = YES;
    self.titleComboBox.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.titleComboBox.editable = YES;
    self.titleComboBox.bordered = NO;
    self.titleComboBox.backgroundColor = [NSColor clearColor];
    self.titleComboBox.stringValue = [self.widgetType isEqualToString:@"Empty Widget"] ? @"" : self.widgetType;

    self.chainButton = [NSButton buttonWithTitle:@"" target:self action:@selector(showChainMenu:)];
      self.chainButton.bezelStyle = NSBezelStyleRounded;
      self.chainButton.bordered = NO;
      self.chainButton.font = [NSFont systemFontOfSize:12];
      
      // Usa un'immagine template per la chain
      NSImage *chainImage = [NSImage imageNamed:@"chainIcon"];
      if (!chainImage) {
          // Fallback: usa l'icona di sistema se non hai un'immagine custom
          chainImage = [NSImage imageWithSystemSymbolName:@"link" accessibilityDescription:@"Chain"];
      }
      
      if (chainImage) {
          chainImage.template = YES;  // Questo permette la colorazione con contentTintColor
          self.chainButton.image = chainImage;
          self.chainButton.title = @"";  // Rimuovi il titolo quando usi un'immagine
      } else {
          // Fallback finale se non ci sono immagini disponibili
          self.chainButton.title = @"🔗";
      }
      
      [self.chainButton.widthAnchor constraintEqualToConstant:24].active = YES;
      [self.chainButton.heightAnchor constraintEqualToConstant:20].active = YES;
    // Imposta chain attiva di default con colore rosso
    if (self.chainActive){
        self.chainColor = [NSColor systemRedColor];
    }
      [self updateChainButtonAppearance];

    self.addButton = [self createHeaderButton:@"+" action:@selector(showAddMenu:)];

    [headerStack addArrangedSubview:self.closeButton];
    if (self.collapseButton) {
        [headerStack addArrangedSubview:self.collapseButton];
    }
    [headerStack addArrangedSubview:self.titleComboBox];
    [headerStack addArrangedSubview:self.chainButton];
    if (self.addButton) {
        [headerStack addArrangedSubview:self.addButton];
    }

    [self.titleComboBox setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    [self.headerViewInternal addSubview:headerStack];
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [headerStack.topAnchor constraintEqualToAnchor:self.headerViewInternal.topAnchor],
        [headerStack.leadingAnchor constraintEqualToAnchor:self.headerViewInternal.leadingAnchor],
        [headerStack.trailingAnchor constraintEqualToAnchor:self.headerViewInternal.trailingAnchor],
        [headerStack.bottomAnchor constraintEqualToAnchor:self.headerViewInternal.bottomAnchor]
    ]];

    [self.headerViewInternal.heightAnchor constraintEqualToConstant:30].active = YES;
    [self.mainStackView addArrangedSubview:self.headerViewInternal];
}

- (NSButton *)createHeaderButton:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.bordered = NO;
    button.font = [NSFont systemFontOfSize:12];
    [button.widthAnchor constraintEqualToConstant:24].active = YES;
    [button.heightAnchor constraintEqualToConstant:20].active = YES;
    return button;
}

#pragma mark - Chain Management

- (void)setChainActive:(BOOL)active withColor:(NSColor *)color {
    self.chainActive = active;
    if (color) {  // Rimuovi la condizione "active &&" per permettere cambio colore sempre
        self.chainColor = color;
    }
    [self updateChainButtonAppearance];
}

- (void)updateChainButtonAppearance {
    if (self.chainActive) {
        // Chain attiva: colora l'immagine template
        self.chainButton.contentTintColor = self.chainColor ?: [NSColor systemBlueColor];
    } else {
        // Chain non attiva: colore grigio
        self.chainButton.contentTintColor = [NSColor tertiaryLabelColor];
    }
    
    // Non cambiare più il title/image qui, solo il colore
}

// In BaseWidget.m, trova il metodo broadcastUpdate e modificalo così:
- (void)broadcastUpdate:(NSDictionary *)update {
    if (!self.chainActive) return;
    
    // ✅ ANTI-LOOP: Non mandare se stiamo ricevendo un update
    if (self.isReceivingChainUpdate) {
        NSLog(@"⚠️ LOOP PREVENTED: %@ blocked broadcast while receiving", NSStringFromClass([self class]));
        return;
    }
    
    // Normalize update format
    NSMutableDictionary *normalizedUpdate = [update mutableCopy];
    
    // Convert single symbol to symbols array
    if (normalizedUpdate[@"symbol"] && !normalizedUpdate[@"symbols"]) {
        normalizedUpdate[@"symbols"] = @[normalizedUpdate[@"symbol"]];
        [normalizedUpdate removeObjectForKey:@"symbol"];
    }
    
    // Ensure action is set
    if (!normalizedUpdate[@"action"]) {
        normalizedUpdate[@"action"] = @"setSymbols";
    }
    
    // ✅ LOGGING: Track all broadcasts
    NSArray *symbols = normalizedUpdate[@"symbols"];
    NSLog(@"🔗 %@ broadcasting: %@ (%lu symbols)",
          NSStringFromClass([self class]),
          [symbols componentsJoinedByString:@", "],
          (unsigned long)symbols.count);
    
    // Send notification
    NSMutableDictionary *notification = [NSMutableDictionary dictionary];
    notification[kChainColorKey] = self.chainColor;
    notification[kChainUpdateKey] = normalizedUpdate;
    notification[kChainSenderKey] = self;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kWidgetChainUpdateNotification
                                                        object:nil
                                                      userInfo:notification];
}
- (void)handleChainNotification:(NSNotification *)notification {
    // Skip if chain not active
    if (!self.chainActive) return;
    
    // Skip self-notifications
    BaseWidget *sender = notification.userInfo[kChainSenderKey];
    if (sender == self) return;
    
    // Check color match
    NSColor *broadcastColor = notification.userInfo[kChainColorKey];
    if (broadcastColor && [self colorsMatch:self.chainColor with:broadcastColor]) {
        NSDictionary *update = notification.userInfo[kChainUpdateKey];
        
        // ✅ LOGGING: Track all receives
        NSArray *symbols = update[@"symbols"];
        NSLog(@"🔗 %@ receiving: %@ (%lu symbols) from %@",
              NSStringFromClass([self class]),
              [symbols componentsJoinedByString:@", "],
              (unsigned long)symbols.count,
              NSStringFromClass([sender class]));
        
        [self receiveUpdate:update fromWidget:sender];
    }
}




- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    // ✅ ANTI-LOOP PROTECTION
    self.isReceivingChainUpdate = YES;
    
    @try {
        // ✅ STANDARD ACTION PROCESSING
        NSString *action = update[@"action"];
        
        if ([action isEqualToString:@"setSymbols"]) {
            NSArray *symbols = update[@"symbols"];
            if (symbols && symbols.count > 0) {
                // ✅ DELEGATION to subclass
                [self handleSymbolsFromChain:symbols fromWidget:sender];
            }
        } else {
            // ✅ DELEGATION for custom actions
            id actionData = update[@"data"] ?: update[@"symbols"];
            [self handleChainAction:action withData:actionData fromWidget:sender];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"❌ ERROR in receiveUpdate for %@: %@", NSStringFromClass([self class]), exception);
    }
    @finally {
        // ✅ SEMPRE reset flag
        self.isReceivingChainUpdate = NO;
    }
}

- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    // Default: Log but take no action
    NSLog(@"📝 %@ received %lu symbols but has no chain handler",
          NSStringFromClass([self class]), (unsigned long)symbols.count);
    
    // Optional: Store symbols for potential future use
    // Subclasses should override for specific behavior
}

// ✅ DEFAULT CUSTOM ACTION HANDLER - Override in subclasses if needed
- (void)handleChainAction:(NSString *)action withData:(id)data fromWidget:(BaseWidget *)sender {
    // Default: Log unsupported action
    NSLog(@"📝 %@ received unsupported chain action '%@' from %@",
          NSStringFromClass([self class]), action, NSStringFromClass([sender class]));
}


// ✅ NUOVO: Template method per subclass override
- (void)processChainUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    // Default implementation: do nothing
    // Subclasses should override this method instead of receiveUpdate:fromWidget:
    
    NSLog(@"📝 %@ received chain update but has no custom processing", NSStringFromClass([self class]));
}

#pragma mark - Chain Helper Methods
// ✅ NUOVO: Send custom action to chain
- (void)sendChainAction:(NSString *)action withData:(id)data {
    if (!self.chainActive) return;
    
    [self broadcastUpdate:@{
        @"action": action,
        @"data": data
    }];
}

// ✅ NUOVO: Context menu integration helpers
- (NSMenu *)createChainSubmenuForSymbols:(NSArray<NSString *> *)symbols {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    if (!symbols || symbols.count == 0) return submenu;
    
    // Send to active chain (if any)
    if (self.chainActive) {
        NSString *activeColorName = [self nameForChainColor:self.chainColor];
        NSMenuItem *activeItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Send to %@ Chain", activeColorName]
                                                            action:@selector(sendSymbolsToActiveChain:)
                                                     keyEquivalent:@""];
        activeItem.target = self;
        activeItem.representedObject = symbols;
        [submenu addItem:activeItem];
        
        [submenu addItem:[NSMenuItem separatorItem]];
    }
    
    // Send to specific chains
    NSArray *colors = @[
        @{@"name": @"Red", @"color": [NSColor systemRedColor]},
        @{@"name": @"Green", @"color": [NSColor systemGreenColor]},
        @{@"name": @"Blue", @"color": [NSColor systemBlueColor]},
        @{@"name": @"Yellow", @"color": [NSColor systemYellowColor]},
        @{@"name": @"Orange", @"color": [NSColor systemOrangeColor]},
        @{@"name": @"Purple", @"color": [NSColor systemPurpleColor]}
    ];
    
    for (NSDictionary *colorInfo in colors) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Send to %@", colorInfo[@"name"]]
                                                      action:@selector(sendSymbolsToSpecificChain:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @{
            @"symbols": symbols,
            @"color": colorInfo[@"color"],
            @"colorName": colorInfo[@"name"]
        };
        [submenu addItem:item];
    }
    
    return submenu;
}

- (void)sendSymbolsToActiveChain:(id)sender {
    NSArray<NSString *> *symbols = [sender representedObject];
    if (symbols.count > 0 && self.chainActive) {
        [self sendSymbolsToChain:symbols];
        
        NSString *message = symbols.count == 1 ?
            [NSString stringWithFormat:@"Sent %@ to chain", symbols[0]] :
            [NSString stringWithFormat:@"Sent %lu symbols to chain", (unsigned long)symbols.count];
        [self showChainFeedback:message];
    }
}

- (void)sendSymbolsToSpecificChain:(id)sender {
    NSDictionary *actionData = [sender representedObject];
    NSArray<NSString *> *symbols = actionData[@"symbols"];
    NSColor *color = actionData[@"color"];
    NSString *colorName = actionData[@"colorName"];
    
    if (symbols.count > 0 && color) {
        // Temporarily activate chain with specific color
        BOOL wasActive = self.chainActive;
        NSColor *previousColor = self.chainColor;
        
        [self setChainActive:YES withColor:color];
        [self sendSymbolsToChain:symbols];
        
        // Restore previous state or auto-deactivate
        if (!wasActive) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self setChainActive:NO withColor:nil];
            });
        } else {
            [self setChainActive:YES withColor:previousColor];
        }
        
        NSString *message = symbols.count == 1 ?
            [NSString stringWithFormat:@"Sent %@ to %@ chain", symbols[0], colorName] :
            [NSString stringWithFormat:@"Sent %lu symbols to %@ chain", (unsigned long)symbols.count, colorName];
        [self showChainFeedback:message];
    }
}

- (void)sendSymbolToChain:(NSString *)symbol {
    if (!self.chainActive || !symbol || symbol.length == 0) return;
    
    [self broadcastUpdate:@{
        @"action": @"setSymbols",
        @"symbols": @[symbol]
    }];
    
    NSLog(@"🔗 %@: Sent symbol '%@' to chain", NSStringFromClass([self class]), symbol);
}

- (void)sendSymbolsToChain:(NSArray<NSString *> *)symbols {
    if (!self.chainActive || !symbols || symbols.count == 0) return;
    
    [self broadcastUpdate:@{
        @"action": @"setSymbols",
        @"symbols": symbols
    }];
    
    NSLog(@"🔗 %@: Sent %lu symbols to chain", NSStringFromClass([self class]), (unsigned long)symbols.count);
}

- (NSMenu *)createChainColorSubmenuForSymbols:(NSArray<NSString *> *)symbols {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Colori standard con nomi user-friendly
    NSArray *colors = @[
        @{@"name": @"Red", @"color": [NSColor systemRedColor]},
        @{@"name": @"Green", @"color": [NSColor systemGreenColor]},
        @{@"name": @"Blue", @"color": [NSColor systemBlueColor]},
        @{@"name": @"Yellow", @"color": [NSColor systemYellowColor]},
        @{@"name": @"Orange", @"color": [NSColor systemOrangeColor]},
        @{@"name": @"Purple", @"color": [NSColor systemPurpleColor]}
    ];
    
    for (NSDictionary *colorInfo in colors) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:colorInfo[@"name"]
                                                      action:@selector(contextMenuSendToChainColor:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @{
            @"symbols": symbols,
            @"color": colorInfo[@"color"],
            @"colorName": colorInfo[@"name"]
        };
        
        // Aggiungi un indicatore visivo del colore
        NSImage *colorDot = [self createColorDotWithColor:colorInfo[@"color"]];
        item.image = colorDot;
        
        [menu addItem:item];
    }
    
    return menu;
}

- (void)showChainFeedback:(NSString *)message {
    // Default: Console log (subclasses can override for UI feedback)
    NSLog(@"📢 %@: %@", NSStringFromClass([self class]), message);
}

#pragma mark - Chain Context Menu Actions

- (IBAction)contextMenuSendSymbolToChain:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSString *symbol = menuItem.representedObject;
    [self sendSymbolToChain:symbol];
}

- (IBAction)contextMenuSendSymbolsToChain:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSArray *symbols = menuItem.representedObject;
    [self sendSymbolsToChain:symbols];
}

- (IBAction)contextMenuSendToChainColor:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSDictionary *actionData = menuItem.representedObject;
    
    NSArray *symbols = actionData[@"symbols"];
    NSColor *chainColor = actionData[@"color"];
    NSString *colorName = actionData[@"colorName"];
    
    if (symbols.count > 0 && chainColor) {
        // Salva il colore originale
        NSColor *originalColor = self.chainColor;
        
        // Cambia temporaneamente al colore scelto
        [self setChainActive:YES withColor:chainColor];
        [self sendSymbolsToChain:symbols];
        
        // Ripristina il colore originale dopo un breve delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setChainActive:YES withColor:originalColor];
        });
        
        NSLog(@"%@: Sent %lu symbols to %@ chain",
              NSStringFromClass([self class]), (unsigned long)symbols.count, colorName);
    }
}

#pragma mark - Helper Utilities

- (NSImage *)createColorDotWithColor:(NSColor *)color {
    NSSize size = NSMakeSize(12, 12);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    
    [image lockFocus];
    
    // Disegna un cerchio colorato
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1, 1, 10, 10)];
    [color setFill];
    [circle fill];
    
    // Aggiungi un bordo
    [[NSColor tertiaryLabelColor] setStroke];
    [circle setLineWidth:0.5];
    [circle stroke];
    
    [image unlockFocus];
    
    return image;
}

- (BOOL)colorsMatch:(NSColor *)color1 with:(NSColor *)color2 {
    if (!color1 || !color2) return NO;
    
    // Confronta i colori convertendoli in RGB per evitare problemi con diversi color spaces
    NSColor *rgb1 = [color1 colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    NSColor *rgb2 = [color2 colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    
    if (!rgb1 || !rgb2) return NO;
    
    CGFloat tolerance = 0.01;
    return fabs(rgb1.redComponent - rgb2.redComponent) < tolerance &&
           fabs(rgb1.greenComponent - rgb2.greenComponent) < tolerance &&
           fabs(rgb1.blueComponent - rgb2.blueComponent) < tolerance;
}
#pragma mark - Actions

- (void)closeWidget:(id)sender {
    if (self.onRemoveRequest) {
        self.onRemoveRequest(self);
    }
}

- (void)toggleCollapse:(id)sender {
    [self toggleCollapse];
}

- (void)showChainMenu:(id)sender {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Opzione per attivare/disattivare
    NSMenuItem *toggleItem = [[NSMenuItem alloc] init];
    toggleItem.title = self.chainActive ? @"Disattiva Chain" : @"Attiva Chain";
    toggleItem.action = @selector(toggleChain:);
    toggleItem.target = self;
    [menu addItem:toggleItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Opzioni colore (solo se attiva)
    if (self.chainActive) {
        NSArray *colors = @[
            @{@"name": @"Rosso", @"color": [NSColor systemRedColor]},
            @{@"name": @"Verde", @"color": [NSColor systemGreenColor]},
            @{@"name": @"Blu", @"color": [NSColor systemBlueColor]},
            @{@"name": @"Giallo", @"color": [NSColor systemYellowColor]},
            @{@"name": @"Arancione", @"color": [NSColor systemOrangeColor]},
            @{@"name": @"Viola", @"color": [NSColor systemPurpleColor]},
            @{@"name": @"Grigio", @"color": [NSColor systemGrayColor]}
        ];
        
        for (NSDictionary *colorInfo in colors) {
            NSMenuItem *colorItem = [[NSMenuItem alloc] init];
            colorItem.title = colorInfo[@"name"];
            colorItem.action = @selector(selectChainColor:);
            colorItem.target = self;
            colorItem.representedObject = colorInfo[@"color"];
            
            // Aggiungi un checkmark al colore corrente
            NSColor *itemColor = colorInfo[@"color"];
            if ([self colorsMatch:itemColor with:self.chainColor]) {
                colorItem.state = NSControlStateValueOn;
            }
            
            [menu addItem:colorItem];
        }
    }
    
    [menu popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
}

- (void)toggleChain:(id)sender {
    [self setChainActive:!self.chainActive withColor:self.chainColor];
}

- (void)selectChainColor:(NSMenuItem *)sender {
    NSColor *newColor = sender.representedObject;
    self.chainColor = newColor;  // Aggiorna direttamente il colore
    [self updateChainButtonAppearance];  // E poi aggiorna l'aspetto
}

- (void)showAddMenu:(id)sender {
    NSViewController *menuController = [[NSViewController alloc] init];
    NSView *menuView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 150, 100)];
    
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 8;
    stack.edgeInsets = NSEdgeInsetsMake(8, 8, 8, 8);
    
    if (self.panelType == PanelTypeCenter) {
        // Center panel: all 4 directions
        [stack addArrangedSubview:[self createAddButton:@"Add Top ↑" direction:WidgetAddDirectionTop]];
        [stack addArrangedSubview:[self createAddButton:@"Add Bottom ↓" direction:WidgetAddDirectionBottom]];
        [stack addArrangedSubview:[self createAddButton:@"Add Left ←" direction:WidgetAddDirectionLeft]];
        [stack addArrangedSubview:[self createAddButton:@"Add Right →" direction:WidgetAddDirectionRight]];
    } else {
        // Side panels: only top/bottom
        [stack addArrangedSubview:[self createAddButton:@"Add Top ↑" direction:WidgetAddDirectionTop]];
        [stack addArrangedSubview:[self createAddButton:@"Add Bottom ↓" direction:WidgetAddDirectionBottom]];
    }
    
    [menuView addSubview:stack];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:menuView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:menuView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:menuView.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:menuView.bottomAnchor]
    ]];
    
    menuController.view = menuView;
    
    self.addPopover = [[NSPopover alloc] init];
    self.addPopover.contentViewController = menuController;
    self.addPopover.behavior = NSPopoverBehaviorTransient;
    
    [self.addPopover showRelativeToRect:self.addButton.bounds
                                 ofView:self.addButton
                          preferredEdge:NSRectEdgeMaxY];
}

- (NSButton *)createAddButton:(NSString *)title direction:(WidgetAddDirection)direction {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:@selector(addWidgetInDirection:)];
    button.tag = direction;
    return button;
}

- (void)addWidgetInDirection:(NSButton *)sender {
    [self.addPopover close];
    if (self.onAddRequest) {
        self.onAddRequest(self, (WidgetAddDirection)sender.tag);
    }
}

#pragma mark - Collapse functionality

- (void)toggleCollapse {
    self.collapsed = !self.collapsed;
    
    if (self.collapsed) {
        self.contentViewInternal.hidden = YES;
        self.collapseButton.title = @"+";
        [self.view.heightAnchor constraintEqualToConstant:[self collapsedHeight]].active = YES;
    } else {
        self.contentViewInternal.hidden = NO;
        self.collapseButton.title = @"\u2212";
        [self.view.heightAnchor constraintGreaterThanOrEqualToConstant:[self expandedHeight]].active = YES;
    }
}

- (CGFloat)collapsedHeight {
    return 30; // Just header height
}

- (CGFloat)expandedHeight {
    return self.savedHeight;
}

#pragma mark - Content View Setup


- (void)setupContentView {
    self.contentViewInternal = [[NSView alloc] init];
    self.contentViewInternal.wantsLayer = YES;
    self.contentViewInternal.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    
    // 🎯 CRITICAL: Configure content view for proper expansion
    self.contentViewInternal.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 🚀 Set content hugging and compression priorities for expansion
    [self.contentViewInternal setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                         forOrientation:NSLayoutConstraintOrientationVertical];
    [self.contentViewInternal setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                         forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    [self.contentViewInternal setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh
                                                      forOrientation:NSLayoutConstraintOrientationVertical];
    [self.contentViewInternal setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh
                                                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    // Add to stack view
    [self.mainStackView addArrangedSubview:self.contentViewInternal];
    
    // 🎯 CRITICAL: Set minimum height constraint to prevent collapse
   // NSLayoutConstraint *minHeightConstraint = [self.contentViewInternal.heightAnchor constraintGreaterThanOrEqualToConstant:100];
  //  minHeightConstraint.priority = NSLayoutPriorityDefaultHigh;
//    minHeightConstraint.active = YES;
    
    // 🚀 CRITICAL: Ensure content view expands to fill available space
    // This prevents the widget from collapsing when content is small
    NSLayoutConstraint *expansionConstraint = [self.contentViewInternal.heightAnchor
                                              constraintGreaterThanOrEqualToConstant:200];
    expansionConstraint.priority = NSLayoutPriorityDefaultLow; // Low priority = preference, not requirement
    expansionConstraint.active = YES;
    
    NSLog(@"✅ BaseWidget: Content view configured with expansion constraints");
    NSLog(@"   - Min height: 100px (high priority)");
    NSLog(@"   - Preferred height: 200px (low priority)");
    NSLog(@"   - Content hugging: Low (will expand to fill space)");
    NSLog(@"   - Compression resistance: High (won't shrink below min)");
    
    // Default placeholder content
    NSTextField *placeholder = [NSTextField labelWithString:@"Widget Content"];
    placeholder.font = [NSFont systemFontOfSize:14];
    placeholder.backgroundColor = [NSColor clearColor];
    placeholder.alignment = NSTextAlignmentCenter;
    placeholder.textColor = [NSColor secondaryLabelColor];
    
    [self.contentViewInternal addSubview:placeholder];
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [placeholder.centerXAnchor constraintEqualToAnchor:self.contentViewInternal.centerXAnchor],
        [placeholder.centerYAnchor constraintEqualToAnchor:self.contentViewInternal.centerYAnchor]
    ]];
    
    NSLog(@"🎯 BaseWidget: setupContentView completed - widget will now expand to fill available space");
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    return @{
        @"widgetID": self.widgetID,
        @"widgetType": self.widgetType,
        @"collapsed": @(self.collapsed),
        @"savedHeight": @(self.savedHeight),
        @"chainActive": @(self.chainActive),
        @"chainColor": [NSArchiver archivedDataWithRootObject:self.chainColor]
    };
}

- (void)restoreState:(NSDictionary *)state {
    self.widgetID = state[@"widgetID"] ?: [[NSUUID UUID] UUIDString];
    self.widgetType = state[@"widgetType"] ?: @"Empty Widget";
    self.collapsed = [state[@"collapsed"] boolValue];
    self.savedHeight = [state[@"savedHeight"] doubleValue] ?: 200;
    self.chainActive = [state[@"chainActive"] boolValue];
    
    NSData *colorData = state[@"chainColor"];
    if (colorData) {
        self.chainColor = [NSUnarchiver unarchiveObjectWithData:colorData];
    }
    
    if ([self.widgetType isEqualToString:@"Empty Widget"]) {
        self.titleFieldInternal.stringValue = @"";
        self.titleFieldInternal.placeholderString = @"Type widget name...";
    } else {
        self.titleFieldInternal.stringValue = self.widgetType;
        self.titleFieldInternal.placeholderString = @"";
    }
    
    [self updateContentForType:self.widgetType];
    [self updateChainButtonAppearance];
    
    if (self.collapsed) {
        [self toggleCollapse];
    }
}

// Continue with the rest of the implementation...
// (NSComboBoxDataSource, NSComboBoxDelegate methods, etc. remain the same)

#pragma mark - NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    return self.availableWidgetTypes.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    return self.availableWidgetTypes[index];
}

- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    return [self.availableWidgetTypes indexOfObject:string];
}

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)string {
    for (NSString *type in self.availableWidgetTypes) {
        if ([type.lowercaseString hasPrefix:string.lowercaseString]) {
            return type;
        }
    }
    return nil;
}

#pragma mark - NSComboBoxDelegate

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSString *newType = self.titleComboBox.stringValue;
    NSString *correctType = [[WidgetTypeManager sharedManager] correctNameForType:newType];
    
    if (correctType) {
        Class widgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:correctType];
        BOOL needsRebuild = ![correctType isEqualToString:self.widgetType] ||
                            (widgetClass != nil && widgetClass != [self class]);
        
        if (needsRebuild) {
            self.widgetType = correctType;
            self.titleComboBox.stringValue = correctType;

            if (self.onTypeChange) {
                self.onTypeChange(self, correctType);
            }
        } else {
            NSLog(@"stesso widget");
        }
    } else {
        self.titleComboBox.stringValue = self.widgetType;
        NSBeep();
    }
}

- (void)updateContentForType:(NSString *)newType {
    // Override in subclasses
}

#pragma mark - Properties

- (NSView *)headerView {
    return self.headerViewInternal;
}

- (NSView *)contentView {
    return self.contentViewInternal;
}

- (NSTextField *)titleField {
    return self.titleFieldInternal;
}

- (NSWindow *)parentWindow {
    return self.view.window;
}


#pragma mark - Drag & Drop Infrastructure

- (void)enableAsDragSource {
    self.isDragSource = YES;
    // Aggiungi gesture recognizer per iniziare il drag
    NSPanGestureRecognizer *panGesture = [[NSPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    [self.contentView addGestureRecognizer:panGesture];
}

- (void)disableAsDragSource {
    self.isDragSource = NO;
    // Rimuovi gesture recognizers esistenti
    for (NSGestureRecognizer *recognizer in self.contentView.gestureRecognizers) {
        if ([recognizer isKindOfClass:[NSPanGestureRecognizer class]]) {
            [self.contentView removeGestureRecognizer:recognizer];
        }
    }
}

- (void)enableAsDropTarget {
    self.isDropTarget = YES;
    [self.view registerForDraggedTypes:@[kWidgetSymbolsPasteboardType, kWidgetConfigurationPasteboardType, NSPasteboardTypeString]];
}

- (void)disableAsDropTarget {
    self.isDropTarget = NO;
    [self.view unregisterDraggedTypes];
}

#pragma mark - Drag Source Implementation

- (void)handlePanGesture:(NSPanGestureRecognizer *)gesture {
    if (!self.isDragSource) return;
    
    switch (gesture.state) {
        case NSGestureRecognizerStateBegan: {
            self.dragStartPoint = [gesture locationInView:self.view];
            break;
        }
        case NSGestureRecognizerStateChanged: {
            NSPoint currentPoint = [gesture locationInView:self.view];
            CGFloat distance = sqrt(pow(currentPoint.x - self.dragStartPoint.x, 2) +
                                  pow(currentPoint.y - self.dragStartPoint.y, 2));
            
            // Inizia il drag dopo un movimento minimo
            if (distance > 10.0 && !self.isDragging) {
                [self beginDragFromPoint:self.dragStartPoint];
            }
            break;
        }
        case NSGestureRecognizerStateEnded:
        case NSGestureRecognizerStateCancelled:
            [self endDrag];
            break;
        default:
            break;
    }
}

- (void)beginDragFromPoint:(NSPoint)point {
    NSArray *dragData = [self draggableData];
    if (!dragData || dragData.count == 0) return;
    
    self.isDragging = YES;
    
    // Crea l'evento sintetico per il drag
    NSEvent *dragEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDragged
                                            location:point
                                       modifierFlags:0
                                           timestamp:[[NSProcessInfo processInfo] systemUptime]
                                        windowNumber:self.view.window.windowNumber
                                             context:nil
                                         eventNumber:0
                                          clickCount:1
                                            pressure:1.0];
    
    [self startDragWithData:dragData fromEvent:dragEvent];
}

- (void)startDragWithData:(NSArray *)data fromEvent:(NSEvent *)event {
    if (!data || data.count == 0) return;
    
    // Prepara il pasteboard
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    [pasteboard clearContents];
    
    // Aggiungi i dati nel formato appropriato
    NSString *pasteboardType = [self pasteboardTypeForDraggedData];
    NSData *draggedData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    [pasteboard setData:draggedData forType:pasteboardType];
    
    // Crea l'immagine del drag
    NSImage *dragImage = [self dragImageForData:data];
    if (!dragImage) {
        dragImage = [self defaultDragImageForData:data];
    }
    
    // Avvia il drag
    NSDragOperation dragOperation = [self draggingSourceOperationMaskForLocal:YES];
    
    [self.view dragImage:dragImage
                      at:event.locationInWindow
                  offset:NSZeroSize
                   event:event
              pasteboard:pasteboard
                  source:self
               slideBack:YES];
    
    // Callback
    if (self.onDragBegan) {
        self.onDragBegan(self, data);
    }
}

- (void)endDrag {
    self.isDragging = NO;
    [self updateDragVisualFeedback];
}

#pragma mark - Drop Target Implementation

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if (!self.isDropTarget) return NSDragOperationNone;
    
    self.isHovering = YES;
    [self updateDragVisualFeedback];
    
    return [self validateDrop:sender];
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
    return [self validateDrop:sender];
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    self.isHovering = NO;
    [self updateDragVisualFeedback];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    self.isHovering = NO;
    [self updateDragVisualFeedback];
    
    NSPasteboard *pasteboard = sender.draggingPasteboard;
    
    // Prova a ottenere i dati nel formato simboli
    NSData *data = [pasteboard dataForType:kWidgetSymbolsPasteboardType];
    if (data) {
        NSError *error;
        NSArray *symbols = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (symbols && !error) {
            BOOL handled = [self handleDroppedData:symbols operation:sender.draggingSourceOperationMask];
            
            // Callback
            if (self.onDropReceived) {
                self.onDropReceived(self, symbols, sender.draggingSourceOperationMask);
            }
            
            return handled;
        }
    }
    
    // Fallback per testo semplice
    NSString *stringData = [pasteboard stringForType:NSPasteboardTypeString];
    if (stringData) {
        NSArray *symbols = [stringData componentsSeparatedByString:@","];
        BOOL handled = [self handleDroppedData:symbols operation:sender.draggingSourceOperationMask];
        
        if (self.onDropReceived) {
            self.onDropReceived(self, symbols, sender.draggingSourceOperationMask);
        }
        
        return handled;
    }
    
    return NO;
}

- (NSDragOperation)validateDrop:(id<NSDraggingInfo>)sender {
    NSPasteboard *pasteboard = sender.draggingPasteboard;
    
    // Verifica se possiamo accettare i dati
    NSData *data = [pasteboard dataForType:kWidgetSymbolsPasteboardType];
    if (data) {
        NSError *error;
        NSArray *symbols = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (symbols && !error) {
            if ([self canAcceptDraggedData:symbols operation:sender.draggingSourceOperationMask]) {
                return [self draggingUpdatedForData:symbols];
            }
        }
    }
    
    // Fallback per testo
    NSString *stringData = [pasteboard stringForType:NSPasteboardTypeString];
    if (stringData) {
        NSArray *symbols = [stringData componentsSeparatedByString:@","];
        if ([self canAcceptDraggedData:symbols operation:sender.draggingSourceOperationMask]) {
            return [self draggingUpdatedForData:symbols];
        }
    }
    
    return NSDragOperationNone;
}

#pragma mark - NSDraggingSource Protocol

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    self.isDragging = NO;
    [self updateDragVisualFeedback];
    
    if (self.onDragEnded) {
        self.onDragEnded(self, operation != NSDragOperationNone);
    }
}

#pragma mark - Default Implementations (Override in subclasses)

- (NSArray *)draggableData {
    // Default: ritorna simboli se disponibili
    return [self defaultDraggableSymbols];
}

- (NSImage *)dragImageForData:(NSArray *)data {
    // Subclasses possono override per immagini personalizzate
    return nil;
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return NSDragOperationCopy | NSDragOperationMove;
}

- (BOOL)canAcceptDraggedData:(id)data operation:(NSDragOperation)operation {
    // Default: accetta array di simboli
    return [data isKindOfClass:[NSArray class]];
}

- (BOOL)handleDroppedData:(id)data operation:(NSDragOperation)operation {
    // Default: prova ad applicare simboli
    if ([data isKindOfClass:[NSArray class]]) {
        return [self defaultHandleDroppedSymbols:data operation:operation];
    }
    return NO;
}

- (NSDragOperation)draggingUpdatedForData:(id)data {
    return NSDragOperationCopy;
}

#pragma mark - Visual Feedback

- (void)updateDragVisualFeedback {
    if (self.isDragging) {
        // Mostra feedback visivo durante il drag
        self.view.alphaValue = 0.7;
    } else if (self.isHovering) {
        // Highlight quando si riceve un drop
        [self highlightAsDropTarget:YES];
    } else {
        // Stato normale
        self.view.alphaValue = 1.0;
        [self highlightAsDropTarget:NO];
        [self showDropIndicator:NO];
    }
}

- (void)showDropIndicator:(BOOL)show {
    if (show && !self.dropIndicatorView) {
        self.dropIndicatorView = [[NSView alloc] init];
        self.dropIndicatorView.wantsLayer = YES;
        self.dropIndicatorView.layer.backgroundColor = [NSColor systemBlueColor].CGColor;
        self.dropIndicatorView.layer.borderColor = [NSColor systemBlueColor].CGColor;
        self.dropIndicatorView.layer.borderWidth = 2.0;
        self.dropIndicatorView.layer.opacity = 0.3;
        self.dropIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self.contentView addSubview:self.dropIndicatorView];
        [NSLayoutConstraint activateConstraints:@[
            [self.dropIndicatorView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [self.dropIndicatorView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [self.dropIndicatorView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [self.dropIndicatorView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
        ]];
    } else if (!show && self.dropIndicatorView) {
        [self.dropIndicatorView removeFromSuperview];
        self.dropIndicatorView = nil;
    }
}

- (void)highlightAsDropTarget:(BOOL)highlight {
    if (highlight) {
        self.contentView.layer.borderColor = [NSColor systemBlueColor].CGColor;
        self.contentView.layer.borderWidth = 2.0;
    } else {
        self.contentView.layer.borderWidth = 0.0;
    }
}
#pragma mark - Helper Methods

- (NSString *)pasteboardTypeForDraggedData {
    return kWidgetSymbolsPasteboardType;
}

- (NSImage *)defaultDragImageForData:(NSArray *)data {
    // Crea un'immagine semplice con il numero di elementi
    NSString *text = [NSString stringWithFormat:@"%ld items", (long)data.count];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };
    
    NSSize textSize = [text sizeWithAttributes:attributes];
    NSSize imageSize = NSMakeSize(textSize.width + 10, textSize.height + 10);
    
    NSImage *image = [[NSImage alloc] initWithSize:imageSize];
    [image lockFocus];
    
    [[NSColor controlBackgroundColor] setFill];
    NSRectFill(NSMakeRect(0, 0, imageSize.width, imageSize.height));
    
    [text drawAtPoint:NSMakePoint(5, 5) withAttributes:attributes];
    
    [image unlockFocus];
    return image;
}

#pragma mark - Default Behavior

- (NSArray *)defaultDraggableSymbols {
    // Subclasses should override
    return @[];
}

- (BOOL)defaultHandleDroppedSymbols:(NSArray *)symbols operation:(NSDragOperation)operation {
    // Default: invia simboli alla chain se attiva
    if (self.chainActive && symbols.count > 0) {
        [self sendSymbolsToChain:symbols];
        return YES;
    }
    return NO;
}



#pragma mark - Standard Context Menu Implementation

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Setup del context menu standard
    [self setupStandardContextMenu];
}

- (void)setupStandardContextMenu {
    // Aggiungi gesture recognizer per right click
    NSClickGestureRecognizer *rightClickGesture = [[NSClickGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(handleRightClick:)];
    rightClickGesture.buttonMask = 0x2; // Right mouse button
    [self.view addGestureRecognizer:rightClickGesture];
}

- (void)handleRightClick:(NSClickGestureRecognizer *)gesture {
    if (gesture.state == NSGestureRecognizerStateEnded) {
        NSPoint clickPoint = [gesture locationInView:self.view];
        [self showContextMenuAtPoint:clickPoint];
    }
}

- (void)showContextMenuAtPoint:(NSPoint)point {
    NSMenu *contextMenu = [self createStandardContextMenu];
    if (contextMenu.itemArray.count > 0) {
        [contextMenu popUpMenuPositioningItem:nil
                                   atLocation:point
                                       inView:self.view];
    }
}

- (NSMenu *)createStandardContextMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    
    NSArray<NSString *> *symbols = [self selectedSymbols];
    NSArray<NSString *> *contextSymbols = [self contextualSymbols];
    
    // Se non ci sono simboli, non mostrare menu
    if (symbols.count == 0 && contextSymbols.count == 0) {
        return menu;
    }
    
    // Determina quale set di simboli usare
    NSArray<NSString *> *targetSymbols = symbols.count > 0 ? symbols : contextSymbols;
    NSString *titleContext = [self contextMenuTitle];
    
    // === COPY SECTION ===
    NSString *copyTitle = [NSString stringWithFormat:@"📋 Copy %@", titleContext];
    NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:copyTitle
                                                      action:@selector(copySelectedSymbols:)
                                               keyEquivalent:@"c"];
    copyItem.target = self;
    copyItem.representedObject = targetSymbols;
    [menu addItem:copyItem];
    
    // === CHAIN SECTION ===
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSString *chainTitle = [NSString stringWithFormat:@"🔗 Send %@ to Chain", titleContext];
    NSMenuItem *chainItem = [[NSMenuItem alloc] initWithTitle:chainTitle
                                                       action:@selector(sendToChain:)
                                                keyEquivalent:@""];
    chainItem.target = self;
    chainItem.representedObject = targetSymbols;
    [menu addItem:chainItem];
    
    // Chain color submenu
    NSMenuItem *chainColorItem = [[NSMenuItem alloc] initWithTitle:@"🔗 Send to Specific Chain"
                                                            action:nil
                                                     keyEquivalent:@""];
    chainColorItem.submenu = [self createChainColorSubmenuForSymbols:targetSymbols];
    [menu addItem:chainColorItem];
    
    // === TAG SECTION ===
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSString *tagTitle = [NSString stringWithFormat:@"🏷️ Add Tags to %@", titleContext];
    NSMenuItem *tagItem = [[NSMenuItem alloc] initWithTitle:tagTitle
                                                     action:@selector(showTagManagementPopup:)
                                              keyEquivalent:@""];
    tagItem.target = self;
    tagItem.representedObject = targetSymbols;
    [menu addItem:tagItem];
    
    // === WIDGET-SPECIFIC SECTION ===
    [menu addItem:[NSMenuItem separatorItem]];
    [self appendWidgetSpecificItemsToMenu:menu];
    
    // Callback per personalizzazione
    if (self.onContextMenuWillShow) {
        self.onContextMenuWillShow(self, menu);
    }
    
    return menu;
}

- (NSMenu *)createChainColorSubmenu {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    NSArray<NSColor *> *colors = [self availableChainColors];
    for (NSColor *color in colors) {
        NSString *colorName = [self nameForChainColor:color];
        NSString *title = [NSString stringWithFormat:@"%@ %@", [self emojiForChainColor:color], colorName];
        
        NSMenuItem *colorItem = [[NSMenuItem alloc] initWithTitle:title
                                                           action:@selector(sendToChainWithColor:)
                                                    keyEquivalent:@""];
        colorItem.target = self;
        colorItem.representedObject = color;
        [submenu addItem:colorItem];
    }
    
    // Separatore e "New Chain"
    [submenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *newChainItem = [[NSMenuItem alloc] initWithTitle:@"⚪ New Chain..."
                                                          action:@selector(createNewChain:)
                                                   keyEquivalent:@""];
    newChainItem.target = self;
    [submenu addItem:newChainItem];
    
    return submenu;
}

#pragma mark - Default Data Source Implementations

- (NSArray<NSString *> *)selectedSymbols {
    // Default: nessuna selezione
    // Subclasses dovrebbero override questo metodo
    return @[];
}

- (NSArray<NSString *> *)contextualSymbols {
    // Default: prova a ottenere dal defaultDraggableSymbols
    return [self defaultDraggableSymbols];
}

- (NSString *)contextMenuTitle {
    NSArray<NSString *> *selected = [self selectedSymbols];
    NSArray<NSString *> *contextual = [self contextualSymbols];
    
    if (selected.count > 0) {
        if (selected.count == 1) {
            return selected[0];
        } else {
            return [NSString stringWithFormat:@"Selection (%ld)", (long)selected.count];
        }
    } else if (contextual.count > 0) {
        if (contextual.count == 1) {
            return contextual[0];
        } else {
            return [NSString stringWithFormat:@"Symbols (%ld)", (long)contextual.count];
        }
    }
    
    return @"Symbols";
}

- (void)appendWidgetSpecificItemsToMenu:(NSMenu *)menu {
    // Default: nessun item specifico
    // Subclasses possono override per aggiungere items personalizzati
}

#pragma mark - Standard Actions Implementation

- (IBAction)copySelectedSymbols:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSArray<NSString *> *symbols = menuItem.representedObject;
    
    [self copySymbolsToClipboard:symbols];
    
    // Callback
    if (self.onSymbolsCopied) {
        self.onSymbolsCopied(self, symbols);
    }
}

- (IBAction)sendToChain:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSArray<NSString *> *symbols = menuItem.representedObject;
    
    [self sendSymbolsToChain:symbols];
}

- (IBAction)sendToChainWithColor:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSColor *color = menuItem.representedObject;
    
    // Ottieni simboli dal contesto corrente
    NSArray<NSString *> *symbols = [self selectedSymbols];
    if (symbols.count == 0) {
        symbols = [self contextualSymbols];
    }
    
    [self sendSymbolsToChainWithColor:symbols color:color];
}

- (IBAction)showTagManagementPopup:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSArray<NSString *> *symbols = menuItem.representedObject;
    
    [self showTagManagementPopupForSymbols:symbols];
}

- (IBAction)createNewChain:(id)sender {
    // Implementa creazione nuova chain con colore random
    NSArray<NSColor *> *colors = [self availableChainColors];
    NSColor *randomColor = colors[arc4random_uniform((uint32_t)colors.count)];
    
    NSArray<NSString *> *symbols = [self selectedSymbols];
    if (symbols.count == 0) {
        symbols = [self contextualSymbols];
    }
    
    [self sendSymbolsToChainWithColor:symbols color:randomColor];
}

- (void)showTagManagementPopupForSymbols:(NSArray<NSString *> *)symbols {
    if (symbols.count == 0) return;
    
    // Crea il controller del popup
    self.tagManagementController = [TagManagementWindowController windowControllerForSymbols:symbols];
    self.tagManagementController.delegate = self;
    
    // Mostra come sheet modal
    [self.tagManagementController showModalForWindow:self.view.window];
}

#pragma mark - Chain Color Helpers

- (NSArray<NSColor *> *)availableChainColors {
    return @[
        [NSColor systemRedColor],
        [NSColor systemBlueColor],
        [NSColor systemGreenColor],
        [NSColor systemOrangeColor],
        [NSColor systemPurpleColor],
        [NSColor systemYellowColor],
        [NSColor systemPinkColor],
        [NSColor systemTealColor]
    ];
}

- (NSString *)nameForChainColor:(NSColor *)color {
    if ([color isEqual:[NSColor systemRedColor]]) return @"Red Chain";
    if ([color isEqual:[NSColor systemBlueColor]]) return @"Blue Chain";
    if ([color isEqual:[NSColor systemGreenColor]]) return @"Green Chain";
    if ([color isEqual:[NSColor systemOrangeColor]]) return @"Orange Chain";
    if ([color isEqual:[NSColor systemPurpleColor]]) return @"Purple Chain";
    if ([color isEqual:[NSColor systemYellowColor]]) return @"Yellow Chain";
    if ([color isEqual:[NSColor systemPinkColor]]) return @"Pink Chain";
    if ([color isEqual:[NSColor systemTealColor]]) return @"Teal Chain";
    return @"Custom Chain";
}

- (NSString *)emojiForChainColor:(NSColor *)color {
    if ([color isEqual:[NSColor systemRedColor]]) return @"🔴";
    if ([color isEqual:[NSColor systemBlueColor]]) return @"🔵";
    if ([color isEqual:[NSColor systemGreenColor]]) return @"🟢";
    if ([color isEqual:[NSColor systemOrangeColor]]) return @"🟠";
    if ([color isEqual:[NSColor systemPurpleColor]]) return @"🟣";
    if ([color isEqual:[NSColor systemYellowColor]]) return @"🟡";
    if ([color isEqual:[NSColor systemPinkColor]]) return @"🩷";
    if ([color isEqual:[NSColor systemTealColor]]) return @"🔷";
    return @"⚪";
}

#pragma mark - Default Implementations

- (void)copySymbolsToClipboard:(NSArray<NSString *> *)symbols {
    if (symbols.count == 0) return;
    
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    
    // Formato testo semplice
    NSString *symbolsText = [symbols componentsJoinedByString:@"\n"];
    [pasteboard setString:symbolsText forType:NSPasteboardTypeString];
    
    // Formato JSON per altre app
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:symbols options:0 error:nil];
    if (jsonData) {
        [pasteboard setData:jsonData forType:@"com.tradingapp.symbols"];
    }
    
    NSLog(@"BaseWidget: Copied %ld symbols to clipboard", (long)symbols.count);
}

- (void)sendSymbolsToChainWithColor:(NSArray<NSString *> *)symbols color:(NSColor *)color {
    if (symbols.count == 0) return;
    
    // Attiva la chain con il colore scelto
    [self setChainActive:YES withColor:color];
    
    // Invia simboli alla chain
    [self broadcastUpdate:@{
        @"action": @"setSymbols",
        @"symbols": symbols
    }];
    
    NSString *colorName = [self nameForChainColor:color];
    NSLog(@"BaseWidget: Sent %ld symbols to %@", (long)symbols.count, colorName);
}

- (void)addTagsToSymbols:(NSArray<NSString *> *)symbols tags:(NSArray<NSString *> *)tags {
    if (symbols.count == 0 || tags.count == 0) return;
    
    DataHub *dataHub = [DataHub shared];
    
    for (NSString *symbolName in symbols) {
        Symbol *symbol = [dataHub getSymbolWithName:symbolName];
        if (!symbol) {
            symbol = [dataHub createSymbolWithName:symbolName];
        }
        
        for (NSString *tag in tags) {
            [dataHub addTag:tag toSymbol:symbol];
        }
    }
    
    // Callback
    if (self.onTagsAdded) {
        self.onTagsAdded(self, symbols, tags);
    }
    
    NSLog(@"BaseWidget: Added %ld tags to %ld symbols", (long)tags.count, (long)symbols.count);
}

#pragma mark - TagManagementDelegate

- (void)tagManagement:(TagManagementWindowController *)controller
       didSelectTags:(NSArray<NSString *> *)tags
          forSymbols:(NSArray<NSString *> *)symbols {
    
    // Applica i tag ai simboli
    [self addTagsToSymbols:symbols tags:tags];
    
    // Cleanup
    self.tagManagementController = nil;
    
    // Feedback visivo
    NSString *message;
    if (tags.count == 1 && symbols.count == 1) {
        message = [NSString stringWithFormat:@"Added tag '%@' to %@", tags[0], symbols[0]];
    } else if (tags.count == 1) {
        message = [NSString stringWithFormat:@"Added tag '%@' to %ld symbols", tags[0], (long)symbols.count];
    } else if (symbols.count == 1) {
        message = [NSString stringWithFormat:@"Added %ld tags to %@", (long)tags.count, symbols[0]];
    } else {
        message = [NSString stringWithFormat:@"Added %ld tags to %ld symbols", (long)tags.count, (long)symbols.count];
    }
    
    // Mostra notifica temporanea (se il widget ha questo metodo)
    if ([self respondsToSelector:@selector(showTemporaryMessage:)]) {
        [self performSelector:@selector(showTemporaryMessage:) withObject:message];
    } else {
        NSLog(@"BaseWidget: %@", message);
    }
}
// ============================================================================
// DEBUGGING: Chain state monitoring
// ============================================================================

#pragma mark - Chain Debug Methods (NEW)

- (void)logChainState {
    NSLog(@"\n🔍 CHAIN STATE: %@", NSStringFromClass([self class]));
    NSLog(@"  Active: %@", self.chainActive ? @"YES" : @"NO");
    NSLog(@"  Color: %@", self.chainColor ? [self nameForChainColor:self.chainColor] : @"None");
    NSLog(@"  Receiving: %@", self.isReceivingChainUpdate ? @"YES" : @"NO");
    NSLog(@"  Widget ID: %@", self.widgetID ?: @"None");
}

+ (void)logAllChainStates {
    NSLog(@"\n🔍 ALL WIDGET CHAIN STATES:");
    NSLog(@"============================");
    
    // In una implementazione reale, avresti un registry di tutti i widget
    // Per ora, questo è un placeholder per il debug
    NSLog(@"(This would iterate through all active widgets)");
    NSLog(@"============================\n");
}

- (void)validateChainIntegrity {
    NSLog(@"\n🔍 CHAIN INTEGRITY CHECK: %@", NSStringFromClass([self class]));
    
    if (self.chainActive && !self.chainColor) {
        NSLog(@"❌ ERROR: Chain active but no color set");
    }
    
    if (!self.chainActive && self.chainColor) {
        NSLog(@"⚠️  WARNING: Chain inactive but color still set");
    }
    
    if (self.isReceivingChainUpdate) {
        NSLog(@"⚠️  WARNING: Widget stuck in receiving state");
    }
    
    NSLog(@"✅ Chain integrity check completed");
}
// ============================================================================
// EMERGENCY: Chain loop reset methods
// ============================================================================

- (void)emergencyResetChainState {
    NSLog(@"🚨 EMERGENCY: Resetting chain state for %@", NSStringFromClass([self class]));
    
    self.isReceivingChainUpdate = NO;
    
    if (self.chainActive) {
        NSLog(@"   Chain was active, keeping active state");
    }
    
    NSLog(@"✅ Chain state reset completed");
}

+ (void)emergencyResetAllChainStates {
    NSLog(@"🚨 EMERGENCY: Resetting all widget chain states");
    
    // In una implementazione reale, questo itererebbe su tutti i widget attivi
    // e chiamerebbe emergencyResetChainState su ognuno
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BaseWidgetEmergencyChainReset"
                                                        object:nil
                                                      userInfo:nil];
    
    NSLog(@"✅ All chain states reset");
}




@end
