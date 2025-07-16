//
//  BaseWidget.m
//  TradingApp
//

#import "BaseWidget.h"
#import "WidgetTypeManager.h"

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
        _chainedWidgets = [NSMutableSet set];
        _chainColor = [NSColor systemBlueColor];
        _collapsed = NO;
        _savedHeight = 200;
        _availableWidgetTypes = [[WidgetTypeManager sharedManager] availableWidgetTypes];

    }
    return self;
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

    self.chainButton = [self createHeaderButton:@"\U0001F517" action:@selector(showChainMenu:)];
    [self updateChainButtonColor];

    self.addButton = [self createHeaderButton:@"+" action:@selector(showAddMenu:)];

    [headerStack addArrangedSubview:self.closeButton];
    if (self.collapseButton) {
        [headerStack addArrangedSubview:self.collapseButton];
    }
    [headerStack addArrangedSubview:self.titleComboBox];
    [headerStack addArrangedSubview:self.chainButton];
 //   [headerStack addArrangedSubview:self.addButton];
//todo
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
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.bordered = NO;
    button.font = [NSFont systemFontOfSize:12];
    
    [button.widthAnchor constraintEqualToConstant:20].active = YES;
    [button.heightAnchor constraintEqualToConstant:20].active = YES;
    
    return button;
}

- (void)setupContentView {
    self.contentViewInternal = [[NSView alloc] init];
    self.contentViewInternal.wantsLayer = YES;
    self.contentViewInternal.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    
    // Add placeholder content
    NSTextField *placeholder = [[NSTextField alloc] init];
    placeholder.stringValue = [NSString stringWithFormat:@"%@ Content", self.widgetType];
    placeholder.editable = NO;
    placeholder.bordered = NO;
    placeholder.backgroundColor = [NSColor clearColor];
    placeholder.alignment = NSTextAlignmentCenter;
    placeholder.textColor = [NSColor secondaryLabelColor];
    
    [self.contentViewInternal addSubview:placeholder];
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [placeholder.centerXAnchor constraintEqualToAnchor:self.contentViewInternal.centerXAnchor],
        [placeholder.centerYAnchor constraintEqualToAnchor:self.contentViewInternal.centerYAnchor]
    ]];
    
    [self.mainStackView addArrangedSubview:self.contentViewInternal];
}


#pragma mark - NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    return self.availableWidgetTypes.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    return self.availableWidgetTypes[index];
}

- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    return [self.availableWidgetTypes indexOfObjectPassingTest:^BOOL(NSString *obj, NSUInteger idx, BOOL *stop) {
        return [obj caseInsensitiveCompare:string] == NSOrderedSame;
    }];
}

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)uncompletedString {
    for (NSString *type in self.availableWidgetTypes) {
        if ([type.lowercaseString hasPrefix:uncompletedString.lowercaseString]) {
            return type;
        }
    }
    return nil;
}

#pragma mark - NSComboBoxDelegate

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSLog(@"comboBoxSelectionDidChange for widget %@", self.widgetID);
    [self applyTypeFromComboBox];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    [self applyTypeFromComboBox];
}

- (void)applyTypeFromComboBox {
    NSString *newType = self.titleComboBox.stringValue;
  
    if (newType.length == 0) {
        self.titleComboBox.stringValue = @"";
        return;
    }

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ==[cd] %@", newType];
    NSArray *matches = [self.availableWidgetTypes filteredArrayUsingPredicate:predicate];

    if (matches.count > 0) {
        NSString *correctType = matches[0];
        
        Class widgetClass = [[WidgetTypeManager sharedManager] widgetClassForType:correctType];
       

        BOOL needsRebuild = ![correctType isEqualToString:self.widgetType] ||
                            (widgetClass != nil && widgetClass != [self class]);
        
        NSLog(@"Needs rebuild: %@ (type different: %@, class different: %@)",
              needsRebuild ? @"YES" : @"NO",
              ![correctType isEqualToString:self.widgetType] ? @"YES" : @"NO",
              (widgetClass != nil && widgetClass != [self class]) ? @"YES" : @"NO");

        if (needsRebuild) {
            self.widgetType = correctType;
            self.titleComboBox.stringValue = correctType;

            if (self.onTypeChange) {
                self.onTypeChange(self, correctType);
            } else {
            }
        } else {
         // todo do nothing se non necessita rebuild   [self updateContentForType:correctType];
            NSLog(@"stesso widget");
        }
    } else {
        self.titleComboBox.stringValue = self.widgetType;
        NSBeep();
    }
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
    // TODO: Implement chain connection UI
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:@"Connect to Widget..." action:nil keyEquivalent:@""];
    [menu addItemWithTitle:@"Disconnect All" action:@selector(disconnectAllChains:) keyEquivalent:@""];
    
    [menu popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
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
        [stack addArrangedSubview:[self createAddButton:@"Add Above ↑" direction:WidgetAddDirectionTop]];
        [stack addArrangedSubview:[self createAddButton:@"Add Below ↓" direction:WidgetAddDirectionBottom]];
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
    NSButton *button = [[NSButton alloc] init];
    button.title = title;
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.tag = direction;
    button.target = self;
    button.action = @selector(addWidgetInDirection:);
    return button;
}

- (void)addWidgetInDirection:(NSButton *)sender {
    [self.addPopover close];
    if (self.onAddRequest) {
        WidgetAddDirection direction = (WidgetAddDirection)sender.tag;
        self.onAddRequest(self, direction);
    }
}

#pragma mark - Collapse Functionality

- (void)toggleCollapse {
    self.collapsed = !self.collapsed;
    
    if (self.collapsed) {
        self.savedHeight = self.view.frame.size.height;
        self.contentViewInternal.hidden = YES;
        self.collapseButton.title = @"+";
        
        // Notify container to update layout
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WidgetDidCollapse"
                                                            object:self];
    } else {
        self.contentViewInternal.hidden = NO;
        self.collapseButton.title = @"−";
        
        // Notify container to update layout
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WidgetDidExpand"
                                                            object:self];
    }
}

- (CGFloat)collapsedHeight {
    return 30; // Height of header only
}

- (CGFloat)expandedHeight {
    return self.savedHeight;
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidBeginEditing:(NSNotification *)notification {
    // Clear placeholder appearance when starting to edit
    if ([self.widgetType isEqualToString:@"Empty Widget"] &&
        self.titleFieldInternal.stringValue.length == 0) {
        // Field is ready for input
    }
}
/*
- (void)controlTextDidEndEditing:(NSNotification *)obj {
    NSString *newType = self.titleFieldInternal.stringValue;
    
    // If empty, revert to previous type
    if (newType.length == 0) {
        if ([self.widgetType isEqualToString:@"Empty Widget"]) {
            self.titleFieldInternal.placeholderString = @"Type widget name...";
        } else {
            self.titleFieldInternal.stringValue = self.widgetType;
        }
        return;
    }
    
    if (![newType isEqualToString:self.widgetType]) {
        // Check if this is a valid widget type (case insensitive)
        NSArray *availableTypes = [[WidgetTypeManager sharedManager] availableWidgetTypes];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ==[cd] %@", newType];
        NSArray *matches = [availableTypes filteredArrayUsingPredicate:predicate];
        
        if (matches.count > 0) {
            // Use the correctly cased version
            NSString *correctType = matches[0];
            self.widgetType = correctType;
            self.titleFieldInternal.stringValue = correctType;
            self.titleFieldInternal.placeholderString = @"";
            
            // Check if we need to transform to a different widget class
            Class widgetClass = [[WidgetTypeManager sharedManager] widgetClassForType:correctType];
            if (widgetClass && widgetClass != [self class]) {
                // Need to transform to a different widget type
                if (self.onTypeChange) {
                    self.onTypeChange(self, correctType);
                }
            } else {
                // Just update the content for the same widget class
                [self updateContentForType:correctType];
            }
        } else {
            // Invalid type, revert to previous
            if ([self.widgetType isEqualToString:@"Empty Widget"]) {
                self.titleFieldInternal.stringValue = @"";
                self.titleFieldInternal.placeholderString = @"Type widget name...";
            } else {
                self.titleFieldInternal.stringValue = self.widgetType;
            }
            NSBeep();
        }
    }
}
*/
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(complete:)) {
        // Handle tab completion
        NSString *currentText = textView.string;
        
        if (currentText.length > 0) {
            NSArray *completions = [self control:control
                                        textView:textView
                                     completions:nil
                             forPartialWordRange:NSMakeRange(0, currentText.length)
                             indexOfSelectedItem:nil];
            
            if (completions.count > 0) {
                // Cast to NSString and use it
                NSString *completion = (NSString *)completions[0];
                textView.string = completion;
                textView.selectedRange = NSMakeRange(completion.length, 0);
                return YES;
            }
        }
    }
    return NO;
}
/*
- (void)controlTextDidEndEditing:(NSNotification *)obj {
    NSString *newType = self.titleFieldInternal.stringValue;
    
    // If empty, revert to previous type
    if (newType.length == 0) {
        if ([self.widgetType isEqualToString:@"Empty Widget"]) {
            self.titleFieldInternal.placeholderString = @"Type widget name...";
        } else {
            self.titleFieldInternal.stringValue = self.widgetType;
        }
        return;
    }
    
    if (![newType isEqualToString:self.widgetType]) {
        // Check if this is a valid widget type (case insensitive)
        NSArray *availableTypes = [[WidgetTypeManager sharedManager] availableWidgetTypes];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ==[cd] %@", newType];
        NSArray *matches = [availableTypes filteredArrayUsingPredicate:predicate];
        
        if (matches.count > 0) {
            // Use the correctly cased version
            NSString *correctType = matches[0];
            self.widgetType = correctType;
            self.titleFieldInternal.stringValue = correctType;
            self.titleFieldInternal.placeholderString = @"";
            
            // Check if we need to transform to a different widget class
            Class widgetClass = [[WidgetTypeManager sharedManager] widgetClassForType:correctType];
            if (widgetClass && widgetClass != [self class]) {
                // Need to transform to a different widget type
                if (self.onTypeChange) {
                    self.onTypeChange(self, correctType);
                }
            } else {
                // Just update the content for the same widget class
                [self updateContentForType:correctType];
            }
        } else {
            // Invalid type, revert to previous
            if ([self.widgetType isEqualToString:@"Empty Widget"]) {
                self.titleFieldInternal.stringValue = @"";
                self.titleFieldInternal.placeholderString = @"Type widget name...";
            } else {
                self.titleFieldInternal.stringValue = self.widgetType;
            }
            NSBeep();
        }
    }
}
*/
- (NSArray<NSString *> *)control:(NSControl *)control
                        textView:(NSTextView *)textView
                     completions:(NSArray<NSString *> *)words
             forPartialWordRange:(NSRange)charRange
             indexOfSelectedItem:(NSInteger *)index {
    // Get available widget types from WidgetTypeManager
    NSArray *availableTypes = [[WidgetTypeManager sharedManager] availableWidgetTypes];
    NSString *partial = [[textView string] substringWithRange:charRange];
    
    // Case insensitive search
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", partial];
    NSArray *matches = [availableTypes filteredArrayUsingPredicate:predicate];
    
    // Sort matches to put exact matches first (case insensitive)
    matches = [matches sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        // If one is an exact match (case insensitive), put it first
        if ([obj1 caseInsensitiveCompare:partial] == NSOrderedSame) {
            return NSOrderedAscending;
        }
        if ([obj2 caseInsensitiveCompare:partial] == NSOrderedSame) {
            return NSOrderedDescending;
        }
        // Otherwise sort alphabetically
        return [obj1 caseInsensitiveCompare:obj2];
    }];
    
    if (index && matches.count > 0) {
        *index = 0; // Select first match by default
    }
    
    return matches;
}

#pragma mark - Content Updates

- (void)updateContentForType:(NSString *)newType {
    // This method should be overridden by specific widget subclasses
    // For now, just update the placeholder
    for (NSView *subview in self.contentViewInternal.subviews) {
        [subview removeFromSuperview];
    }
    
    NSTextField *placeholder = [[NSTextField alloc] init];
    if ([newType isEqualToString:@"Empty Widget"]) {
        placeholder.stringValue = @"Select a widget type above";
    } else {
        placeholder.stringValue = [NSString stringWithFormat:@"%@ Content", newType];
    }
    placeholder.editable = NO;
    placeholder.bordered = NO;
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

#pragma mark - Chain Management

- (void)addChainedWidget:(BaseWidget *)widget {
    [self.chainedWidgets addObject:widget];
    [self updateChainButtonColor];
}

- (void)removeChainedWidget:(BaseWidget *)widget {
    [self.chainedWidgets removeObject:widget];
    [self updateChainButtonColor];
}

- (void)broadcastUpdate:(NSDictionary *)update {
    for (BaseWidget *widget in self.chainedWidgets) {
        [widget receiveUpdate:update fromWidget:self];
    }
}

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    // Override in subclasses to handle updates
}

- (void)updateChainButtonColor {
    if (self.chainedWidgets.count > 0) {
        self.chainButton.contentTintColor = self.chainColor;
    } else {
        self.chainButton.contentTintColor = nil;
    }
}

- (void)disconnectAllChains:(id)sender {
    [self.chainedWidgets removeAllObjects];
    [self updateChainButtonColor];
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    return @{
        @"widgetID": self.widgetID,
        @"widgetType": self.widgetType,
        @"collapsed": @(self.collapsed),
        @"savedHeight": @(self.savedHeight),
        @"chainedWidgetIDs": [self.chainedWidgets.allObjects valueForKey:@"widgetID"]
    };
}

- (void)restoreState:(NSDictionary *)state {
    self.widgetID = state[@"widgetID"] ?: [[NSUUID UUID] UUIDString];
    self.widgetType = state[@"widgetType"] ?: @"Empty Widget";
    self.collapsed = [state[@"collapsed"] boolValue];
    self.savedHeight = [state[@"savedHeight"] doubleValue] ?: 200;
    
    if ([self.widgetType isEqualToString:@"Empty Widget"]) {
        self.titleFieldInternal.stringValue = @"";
        self.titleFieldInternal.placeholderString = @"Type widget name...";
    } else {
        self.titleFieldInternal.stringValue = self.widgetType;
        self.titleFieldInternal.placeholderString = @"";
    }
    
    [self updateContentForType:self.widgetType];
    
    if (self.collapsed) {
        [self toggleCollapse];
    }
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
