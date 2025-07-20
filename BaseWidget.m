//
//  BaseWidget.m
//  TradingApp
//

#import "BaseWidget.h"
#import "WidgetTypeManager.h"

// Notification name for chain updates
static NSString *const kWidgetChainUpdateNotification = @"WidgetChainUpdateNotification";

// Keys for notification userInfo
static NSString *const kChainColorKey = @"chainColor";
static NSString *const kChainUpdateKey = @"update";
static NSString *const kChainSenderKey = @"sender";

@interface BaseWidget () <NSTextFieldDelegate, NSTextViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate>

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
@property (nonatomic, strong) NSComboBox *titleComboBox;
@property (nonatomic, strong) NSStackView *mainStackView;
@property (nonatomic, strong) NSArray<NSString *> *availableWidgetTypes;
@property (nonatomic, strong) NSMenu *chainColorMenu;
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
        _chainActive = NO;
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
    self.mainStackView = [[NSStackView alloc] init];
    self.mainStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.mainStackView.spacing = 0;
    self.mainStackView.distribution = NSStackViewDistributionFill;

    [self setupHeaderView];

    [self.view addSubview:self.mainStackView];
    self.mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
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

- (void)broadcastUpdate:(NSDictionary *)update {
    if (!self.chainActive) return;
    
    // Includi il colore della chain nel messaggio
    NSMutableDictionary *notification = [NSMutableDictionary dictionary];
    notification[kChainColorKey] = self.chainColor;
    notification[kChainUpdateKey] = update;
    notification[kChainSenderKey] = self;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kWidgetChainUpdateNotification
                                                        object:nil
                                                      userInfo:notification];
}

- (void)handleChainNotification:(NSNotification *)notification {
    // Ignora se la chain non è attiva
    if (!self.chainActive) return;
    
    // Ignora le notifiche da se stesso
    BaseWidget *sender = notification.userInfo[kChainSenderKey];
    if (sender == self) return;
    
    // Controlla se il colore matcha
    NSColor *broadcastColor = notification.userInfo[kChainColorKey];
    if (broadcastColor && [self colorsMatch:self.chainColor with:broadcastColor]) {
        NSDictionary *update = notification.userInfo[kChainUpdateKey];
        [self receiveUpdate:update fromWidget:sender];
    }
}

- (BOOL)colorsMatch:(NSColor *)color1 with:(NSColor *)color2 {
    // Confronta i colori convertendoli in RGB per evitare problemi con diversi color spaces
    NSColor *rgb1 = [color1 colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    NSColor *rgb2 = [color2 colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    
    CGFloat tolerance = 0.01;
    return fabs(rgb1.redComponent - rgb2.redComponent) < tolerance &&
           fabs(rgb1.greenComponent - rgb2.greenComponent) < tolerance &&
           fabs(rgb1.blueComponent - rgb2.blueComponent) < tolerance;
}

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    // Override in subclasses to handle updates
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
    
    [self.mainStackView addArrangedSubview:self.contentViewInternal];
    
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

@end
