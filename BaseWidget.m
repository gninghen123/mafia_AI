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

@property (nonatomic, strong) NSButton *closeButton;
@property (nonatomic, strong) NSButton *chainButton;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSPopover *addPopover;
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

- (instancetype)initWithType:(NSString *)type{
    self = [super init];
    if (self) {
        _widgetType = type;
        _widgetID = [[NSUUID UUID] UUIDString];
        _chainActive = YES;
        _chainColor = [NSColor systemRedColor]; // Default color
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



// In BaseWidget.m - MODIFICA il metodo setupViews

- (void)setupViews {
    NSLog(@"🔧 BaseWidget: Setting up views with proper expansion configuration");
    
    self.mainStackView = [[NSStackView alloc] init];
    self.mainStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.mainStackView.spacing = 0;
    
    // 🎯 CRITICAL: Use Fill distribution to expand content area
    self.mainStackView.distribution = NSStackViewDistributionFill;
    
    // ✅ FIX: Set alignment to LEADING for horizontal fill
    // But we need to ensure arranged subviews fill the width by NOT setting alignment constraints
    // The correct way is to use .alignment property correctly for NSStackView
    
    // For VERTICAL stack view, we want horizontal fill (width)
    // So we use NSLayoutAttributeLeft or NSLayoutAttributeRight with stretching
    // OR better: Don't set alignment and let distribution handle it
    
    // ✅ CORRECT FIX: Use alignment that allows horizontal stretching
    self.mainStackView.alignment = NSLayoutAttributeLeading;
    
    // ✅ IMPORTANT: Set detachesHiddenViews to NO to maintain layout
    self.mainStackView.detachesHiddenViews = NO;
    
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
    // Verifica tipo di finestra
    BOOL isInGrid = [self.contentView.window isKindOfClass:NSClassFromString(@"GridWindow")];
    
    if (isInGrid) {
        // In GridWindow: disabilita il menu
        NSLog(@"ℹ️ BaseWidget: Add widget not available in GridWindow. Use Grid's + button.");
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Add Widget";
        alert.informativeText = @"To add widgets in a Grid, use the '+' button in the Grid's title bar.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // In FloatingWindow: mostra menu direzioni
    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;
    
    NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:@"Add Widget..."
                                                       action:nil
                                                keyEquivalent:@""];
    titleItem.enabled = NO;
    [menu addItem:titleItem];
    [menu addItem:[NSMenuItem separatorItem]];
    
    // ↑ Sopra
    NSMenuItem *upItem = [[NSMenuItem alloc] initWithTitle:@"↑ Add Above"
                                                    action:@selector(addWidgetUp:)
                                             keyEquivalent:@""];
    upItem.target = self;
    [menu addItem:upItem];
    
    // ↓ Sotto
    NSMenuItem *downItem = [[NSMenuItem alloc] initWithTitle:@"↓ Add Below"
                                                      action:@selector(addWidgetDown:)
                                               keyEquivalent:@""];
    downItem.target = self;
    [menu addItem:downItem];
    
    // ← Sinistra
    NSMenuItem *leftItem = [[NSMenuItem alloc] initWithTitle:@"← Add to Left"
                                                      action:@selector(addWidgetLeft:)
                                               keyEquivalent:@""];
    leftItem.target = self;
    [menu addItem:leftItem];
    
    // → Destra
    NSMenuItem *rightItem = [[NSMenuItem alloc] initWithTitle:@"→ Add to Right"
                                                       action:@selector(addWidgetRight:)
                                                keyEquivalent:@""];
    rightItem.target = self;
    [menu addItem:rightItem];
    
    // Mostra menu sotto il bottone
    NSPoint location = NSMakePoint(0, NSHeight(self.addButton.bounds));
    [menu popUpMenuPositioningItem:nil atLocation:location inView:self.addButton];
}

#pragma mark - Direction Actions

- (void)addWidgetUp:(id)sender {
    [self splitFloatingWindowInDirection:@"up"];
}

- (void)addWidgetDown:(id)sender {
    [self splitFloatingWindowInDirection:@"down"];
}

- (void)addWidgetLeft:(id)sender {
    [self splitFloatingWindowInDirection:@"left"];
}

- (void)addWidgetRight:(id)sender {
    [self splitFloatingWindowInDirection:@"right"];
}

- (void)splitFloatingWindowInDirection:(NSString *)direction {
    // Verifica che sia in FloatingWindow
    if (![self.contentView.window isKindOfClass:NSClassFromString(@"FloatingWidgetWindow")]) {
        NSLog(@"⚠️ BaseWidget: Split only works in FloatingWindow");
        return;
    }
    
    id floatingWindow = self.contentView.window;
    id appDelegate = [floatingWindow valueForKey:@"appDelegate"];
    
    if (!appDelegate) {
        NSLog(@"❌ BaseWidget: AppDelegate not found");
        return;
    }
    
    // Determina dimensioni grid
    NSInteger rows = ([direction isEqualToString:@"up"] || [direction isEqualToString:@"down"]) ? 2 : 1;
    NSInteger cols = ([direction isEqualToString:@"left"] || [direction isEqualToString:@"right"]) ? 2 : 1;
    
    NSLog(@"🔄 BaseWidget: Splitting FloatingWindow → Grid %ldx%ld (%@)",
          (long)rows, (long)cols, direction);
    
    // Crea template
    Class templateClass = NSClassFromString(@"GridTemplate");
    SEL templateSelector = NSSelectorFromString(@"templateWithRows:cols:displayName:");
    
    NSMethodSignature *signature = [templateClass methodSignatureForSelector:templateSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:templateSelector];
    [invocation setTarget:templateClass];
    [invocation setArgument:&rows atIndex:2];
    [invocation setArgument:&cols atIndex:3];
    NSString *displayName = [NSString stringWithFormat:@"%ldx%ld Split", (long)rows, (long)cols];
    [invocation setArgument:&displayName atIndex:4];
    [invocation invoke];
    
    id template;
    [invocation getReturnValue:&template];
    
    // Crea GridWindow
    Class gridWindowClass = NSClassFromString(@"GridWindow");
    SEL initSelector = NSSelectorFromString(@"initWithTemplate:name:appDelegate:");
    
    signature = [gridWindowClass instanceMethodSignatureForSelector:initSelector];
    invocation = [NSInvocation invocationWithMethodSignature:signature];
    
    id gridWindow = [[gridWindowClass alloc] init];
    [invocation setSelector:initSelector];
    [invocation setTarget:gridWindow];
    [invocation setArgument:&template atIndex:2];
    [invocation setArgument:&displayName atIndex:3];
    [invocation setArgument:&appDelegate atIndex:4];
    [invocation invoke];
    [invocation getReturnValue:&gridWindow];
    
    // Determina posizioni matrixCode
    NSString *currentPos = [self matrixCodeForDirection:direction isOriginal:YES];
    NSString *newPos = [self matrixCodeForDirection:direction isOriginal:NO];
    
    NSLog(@"📍 BaseWidget: Current widget → %@, New placeholder → %@", currentPos, newPos);
    
    // Rimuovi widget da floating window
    [self.view removeFromSuperview];
    
    // Trova e rimuovi placeholder esistente alla posizione corrente
    SEL getPositionsSelector = NSSelectorFromString(@"widgetPositions");
    NSMutableDictionary *positions = [gridWindow valueForKey:@"widgetPositions"];
    BaseWidget *existingWidget = positions[currentPos];
    if (existingWidget) {
        NSMutableArray *widgets = [gridWindow valueForKey:@"widgets"];
        [widgets removeObject:existingWidget];
        [existingWidget.view removeFromSuperview];
        [positions removeObjectForKey:currentPos];
    }
    
    // Aggiungi widget corrente a grid
    SEL addSelector = NSSelectorFromString(@"addWidget:atMatrixCode:");
    signature = [gridWindow methodSignatureForSelector:addSelector];
    invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:addSelector];
    [invocation setTarget:gridWindow];
    [invocation setArgument:&self atIndex:2];
    [invocation setArgument:&currentPos atIndex:3];
    [invocation invoke];
    
    // Il placeholder nella nuova posizione è già stato creato da initWithTemplate
    
    // Aggiungi a gridWindows array
    NSMutableArray *gridWindows = [appDelegate valueForKey:@"gridWindows"];
    [gridWindows addObject:gridWindow];
    
    // Posiziona GridWindow nella stessa posizione del FloatingWindow
    NSRect floatingFrame = [floatingWindow frame];
    
    // Aumenta dimensione finestra per la griglia
    NSRect gridFrame = floatingFrame;
    if (rows == 2) {
        gridFrame.size.height = MAX(floatingFrame.size.height * 1.5, 600);
    }
    if (cols == 2) {
        gridFrame.size.width = MAX(floatingFrame.size.width * 1.5, 900);
    }
    
    [gridWindow setFrame:gridFrame display:NO];
    
    // Chiudi floating, mostra grid
    [floatingWindow performSelector:@selector(close)];
    [gridWindow performSelector:@selector(makeKeyAndOrderFront:) withObject:nil];
    
    NSLog(@"✅ BaseWidget: Split complete - GridWindow created");
}

- (NSString *)matrixCodeForDirection:(NSString *)direction isOriginal:(BOOL)isOriginal {
    if ([direction isEqualToString:@"right"]) {
        return isOriginal ? @"11" : @"12";  // Original a sinistra, nuovo a destra
    } else if ([direction isEqualToString:@"left"]) {
        return isOriginal ? @"12" : @"11";  // Original a destra, nuovo a sinistra
    } else if ([direction isEqualToString:@"up"]) {
        return isOriginal ? @"21" : @"11";  // Original sotto, nuovo sopra
    } else if ([direction isEqualToString:@"down"]) {
        return isOriginal ? @"11" : @"21";  // Original sopra, nuovo sotto
    }
    return @"11";
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
    
    // ✅ FIX: Add LEADING and TRAILING constraints to force horizontal fill
    [NSLayoutConstraint activateConstraints:@[
        [self.contentViewInternal.leadingAnchor constraintEqualToAnchor:self.mainStackView.leadingAnchor],
        [self.contentViewInternal.trailingAnchor constraintEqualToAnchor:self.mainStackView.trailingAnchor]
    ]];
    
    // 🚀 CRITICAL: Ensure content view expands to fill available space vertically
    NSLayoutConstraint *expansionConstraint = [self.contentViewInternal.heightAnchor
                                              constraintGreaterThanOrEqualToConstant:200];
    expansionConstraint.priority = NSLayoutPriorityDefaultLow;
    expansionConstraint.active = YES;
    
    NSLog(@"✅ BaseWidget: Content view configured with expansion constraints");
    NSLog(@"   - Horizontal: LEADING + TRAILING anchors to mainStackView");
    NSLog(@"   - Vertical: Min 200px (low priority)");
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
        @"chainActive": @(self.chainActive),
        @"chainColor": [NSArchiver archivedDataWithRootObject:self.chainColor]
    };
}

- (void)restoreState:(NSDictionary *)state {
    self.widgetID = state[@"widgetID"] ?: [[NSUUID UUID] UUIDString];
    self.widgetType = state[@"widgetType"] ?: @"Empty Widget";
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
    
   
}

// Continue with the rest of the implementation...
// (NSComboBoxDataSource, NSComboBoxDelegate methods, etc. remain the same)

#pragma mark - NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    if (comboBox != self.titleComboBox) {
        return 0;
    }
    return self.availableWidgetTypes.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox != self.titleComboBox) {
        return nil;
    }
    return self.availableWidgetTypes[index];
}

- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    if (comboBox != self.titleComboBox) {
        return NSNotFound;
    }
    return [self.availableWidgetTypes indexOfObject:string];
}

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)string {
    if (comboBox != self.titleComboBox) {
        return nil;
    }
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
