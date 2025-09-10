//
//  ToolbarController.m
//  TradingApp
//

#import "ToolbarController.h"
#import "MainWindowController.h"
#import "PreferencesWindowController.h"

// Toolbar item identifiers
static NSString *const ToolbarItemPreferences = @"Preferences";

static NSString *const ToolbarItemLeftPanel = @"LeftPanel";
static NSString *const ToolbarItemRightPanel = @"RightPanel";
static NSString *const ToolbarItemLayoutSelector = @"LayoutSelector";
static NSString *const ToolbarItemSaveLayout = @"SaveLayout";

@interface ToolbarController ()
@property (nonatomic, strong) NSPopUpButton *layoutPopup;
@property (nonatomic, strong) NSTextField *layoutNameField;
@property (nonatomic, strong) NSButton *leftPanelButton;
@property (nonatomic, strong) NSButton *rightPanelButton;
@end

@implementation ToolbarController

- (void)refreshLayoutMenu {
    [self updateLayoutMenu];
}


- (void)setupToolbarForWindow:(NSWindow *)window {
    self.toolbar = [[NSToolbar alloc] initWithIdentifier:@"MainToolbar"];
    self.toolbar.delegate = self;
    self.toolbar.allowsUserCustomization = YES;
    self.toolbar.autosavesConfiguration = YES;
    self.toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
    
    window.toolbar = self.toolbar;
    dispatch_async(dispatch_get_main_queue(), ^{
         if (self.mainWindowController) {
             [self updateLayoutMenu];
             NSLog(@"✅ Layout menu populated at startup");
         }
     });
}

#pragma mark - NSToolbarDelegate

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdentifier
  willBeInsertedIntoToolbar:(BOOL)flag {
    
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    
    if ([itemIdentifier isEqualToString:ToolbarItemLeftPanel]) {
        self.leftPanelButton = [[NSButton alloc] init];
        self.leftPanelButton.bezelStyle = NSBezelStyleTexturedRounded;
        self.leftPanelButton.title = @"☰";
        self.leftPanelButton.target = self;
        self.leftPanelButton.action = @selector(toggleLeftPanel:);
        self.leftPanelButton.toolTip = @"Toggle Left Panel";
        
        // Use only width constraint, let height be automatic
        [self.leftPanelButton.widthAnchor constraintEqualToConstant:40].active = YES;
        
        item.label = @"Left Panel";
        item.paletteLabel = @"Left Panel";
        item.view = self.leftPanelButton;
        
    } else if ([itemIdentifier isEqualToString:ToolbarItemRightPanel]) {
        self.rightPanelButton = [[NSButton alloc] init];
        self.rightPanelButton.bezelStyle = NSBezelStyleTexturedRounded;
        self.rightPanelButton.title = @"☰";
        self.rightPanelButton.target = self;
        self.rightPanelButton.action = @selector(toggleRightPanel:);
        self.rightPanelButton.toolTip = @"Toggle Right Panel";
        
        // Use only width constraint, let height be automatic
        [self.rightPanelButton.widthAnchor constraintEqualToConstant:40].active = YES;
        
        item.label = @"Right Panel";
        item.paletteLabel = @"Right Panel";
        item.view = self.rightPanelButton;
        
    } else if ([itemIdentifier isEqualToString:ToolbarItemLayoutSelector]) {
        NSView *layoutView = [[NSView alloc] init];
        
        // Create stack view for better layout management
        NSStackView *stackView = [[NSStackView alloc] init];
        stackView.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        stackView.spacing = 5;
        stackView.alignment = NSLayoutAttributeCenterY;
        
        // Create layout name field
        self.layoutNameField = [[NSTextField alloc] init];
        self.layoutNameField.placeholderString = @"Layout Name";
        self.layoutNameField.bezelStyle = NSTextFieldRoundedBezel;
        [self.layoutNameField.widthAnchor constraintEqualToConstant:180].active = YES;
        
        // Create layout popup
        self.layoutPopup = [[NSPopUpButton alloc] init];
        [self.layoutPopup addItemWithTitle:@"Layouts"];
        [[self.layoutPopup menu] addItem:[NSMenuItem separatorItem]];
        [self.layoutPopup.widthAnchor constraintEqualToConstant:115].active = YES;
        [self updateLayoutMenu];
        
        [stackView addArrangedSubview:self.layoutNameField];
        [stackView addArrangedSubview:self.layoutPopup];
        
        [layoutView addSubview:stackView];
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [stackView.centerXAnchor constraintEqualToAnchor:layoutView.centerXAnchor],
            [stackView.centerYAnchor constraintEqualToAnchor:layoutView.centerYAnchor],
            [stackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:layoutView.leadingAnchor],
            [stackView.trailingAnchor constraintLessThanOrEqualToAnchor:layoutView.trailingAnchor]
        ]];
        
        // Set only width for the container
        [layoutView.widthAnchor constraintEqualToConstant:300].active = YES;
        
        item.label = @"Layout";
        item.paletteLabel = @"Layout Selector";
        item.view = layoutView;
        
    } else if ([itemIdentifier isEqualToString:ToolbarItemSaveLayout]) {
        NSButton *saveButton = [[NSButton alloc] init];
        saveButton.bezelStyle = NSBezelStyleTexturedRounded;
        saveButton.title = @"Save Layout";
        saveButton.target = self;
        saveButton.action = @selector(saveLayout:);
        
        // Use only width constraint, let height be automatic
        [saveButton.widthAnchor constraintEqualToConstant:80].active = YES;
        
        item.label = @"Save";
        item.paletteLabel = @"Save Layout";
        item.view = saveButton;
    }else if ([itemIdentifier isEqualToString:ToolbarItemPreferences]) {
        NSButton *preferencesButton = [[NSButton alloc] init];
        preferencesButton.bezelStyle = NSBezelStyleTexturedRounded;
        preferencesButton.title = @"⚙️";
        preferencesButton.target = self;
        preferencesButton.action = @selector(showPreferences:);
        preferencesButton.toolTip = @"Preferences";
        
        [preferencesButton.widthAnchor constraintEqualToConstant:40].active = YES;
        
        item.label = @"Preferences";
        item.paletteLabel = @"Preferences";
        item.view = preferencesButton;
    }
    
    return item;
}

- (void)showPreferences:(id)sender {
    [[PreferencesWindowController sharedController] showPreferences];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        ToolbarItemLeftPanel,
        NSToolbarFlexibleSpaceItemIdentifier,
        ToolbarItemLayoutSelector,
        ToolbarItemSaveLayout,
        NSToolbarFlexibleSpaceItemIdentifier,
        ToolbarItemPreferences,  // ← Aggiungi questo
        ToolbarItemRightPanel
    ];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        ToolbarItemLeftPanel,
        ToolbarItemRightPanel,
        ToolbarItemLayoutSelector,
        ToolbarItemSaveLayout,
        ToolbarItemPreferences,  // ← Aggiungi questo
        NSToolbarFlexibleSpaceItemIdentifier,
        NSToolbarSpaceItemIdentifier
    ];
}

#pragma mark - Actions

- (void)toggleLeftPanel:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleLeftPanel" object:nil];
}

- (void)toggleRightPanel:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleRightPanel" object:nil];
}

- (void)saveLayout:(id)sender {
    NSString *layoutName = self.layoutNameField.stringValue;
    if (layoutName.length == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Please enter a layout name";
        alert.informativeText = @"You must provide a name to save the layout.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    [self.mainWindowController saveLayoutWithName:layoutName];
    [self updateLayoutMenu];
    
    // Clear the text field
    self.layoutNameField.stringValue = @"";
}

- (void)loadLayout:(NSMenuItem *)sender {
    NSString *layoutName = sender.title;
    [self.mainWindowController loadLayoutWithName:layoutName];
}

- (void)updateLayoutMenu {
    // Remove all items except the first two (title and separator)
    NSMenu *menu = [self.layoutPopup menu];
    while (menu.numberOfItems > 2) {
        [menu removeItemAtIndex:2];
    }
    
    // Add available layouts
    NSArray *layouts = [self.mainWindowController availableLayouts];
    for (NSString *layoutName in layouts) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:layoutName
                                                       action:@selector(loadLayout:)
                                                keyEquivalent:@""];
        item.target = self;
        [menu addItem:item];
    }
    
    // Add separator and delete option if there are layouts
    if (layouts.count > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Layout..."
                                                            action:@selector(showDeleteMenu:)
                                                     keyEquivalent:@""];
        deleteItem.target = self;
        [menu addItem:deleteItem];
    }
}

- (void)showDeleteMenu:(id)sender {
    // TODO: Implement layout deletion UI
}

@end
