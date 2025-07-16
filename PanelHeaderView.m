
#import "PanelHeaderView.h"
#import "PanelController.h"

@interface PanelHeaderView ()
@property (nonatomic, strong) NSTextField *layoutNameField;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSPopUpButton *presetPopup;
@property (nonatomic, strong) NSSegmentedControl *quickPresets;
@end

@implementation PanelHeaderView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
    
    // Create horizontal stack view
    NSStackView *stackView = [[NSStackView alloc] init];
    stackView.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stackView.spacing = 8;
    stackView.edgeInsets = NSEdgeInsetsMake(5, 10, 5, 10);
    
    // Layout name field
    self.layoutNameField = [[NSTextField alloc] init];
    self.layoutNameField.placeholderString = @"Layout name";
    self.layoutNameField.bezelStyle = NSTextFieldRoundedBezel;
    [self.layoutNameField.widthAnchor constraintEqualToConstant:150].active = YES;
    
    // Save button
    self.saveButton = [[NSButton alloc] init];
    self.saveButton.title = @"Save";
    self.saveButton.bezelStyle = NSBezelStyleRounded;
    self.saveButton.target = self;
    self.saveButton.action = @selector(saveLayout:);
    
    // Preset popup
    self.presetPopup = [[NSPopUpButton alloc] init];
    [self.presetPopup addItemWithTitle:@"Load Preset"];
    [[self.presetPopup menu] addItem:[NSMenuItem separatorItem]];
    self.presetPopup.target = self;
    self.presetPopup.action = @selector(loadPreset:);
    [self updatePresetMenu];
    
    // Quick access presets (segmented control)
    self.quickPresets = [[NSSegmentedControl alloc] init];
    self.quickPresets.segmentStyle = NSSegmentStyleTexturedRounded;
    self.quickPresets.trackingMode = NSSegmentSwitchTrackingMomentary;
    self.quickPresets.target = self;
    self.quickPresets.action = @selector(loadQuickPreset:);
    [self setupQuickPresets];
    
    // Add to stack view
    [stackView addArrangedSubview:self.layoutNameField];
    [stackView addArrangedSubview:self.saveButton];
    [stackView addArrangedSubview:[NSView new]]; // Spacer
    [stackView addArrangedSubview:self.presetPopup];
    [stackView addArrangedSubview:self.quickPresets];
    
    // Make spacer expand
    NSView *spacer = stackView.arrangedSubviews[2];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow
                       forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    [self addSubview:stackView];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (void)setupQuickPresets {
    // Add some default quick presets based on panel type
    NSArray *presetNames = @[@"Default", @"Compact", @"Extended"];
    
    self.quickPresets.segmentCount = presetNames.count;
    for (NSInteger i = 0; i < presetNames.count; i++) {
        [self.quickPresets setLabel:presetNames[i] forSegment:i];
        [self.quickPresets setWidth:60 forSegment:i];
    }
}

#pragma mark - Actions

- (void)saveLayout:(id)sender {
    NSString *layoutName = self.layoutNameField.stringValue;
    if (layoutName.length == 0) {
        NSBeep();
        return;
    }
    
    [self.panelController saveCurrentLayoutAsPreset:layoutName];
    self.layoutNameField.stringValue = @"";
    [self updatePresetMenu];
}

- (void)loadPreset:(id)sender {
    NSMenuItem *selectedItem = [self.presetPopup selectedItem];
    if (selectedItem.tag == 0) return; // Skip the title item
    
    [self.panelController loadLayoutPreset:selectedItem.title];
}

- (void)loadQuickPreset:(id)sender {
    NSInteger selectedSegment = [sender selectedSegment];
    NSString *presetName = [sender labelForSegment:selectedSegment];
    
    // Try to load the preset, if it doesn't exist, create a default one
    NSArray *availablePresets = [self.panelController availablePresets];
    if ([availablePresets containsObject:presetName]) {
        [self.panelController loadLayoutPreset:presetName];
    } else {
        // Don't try to load a non-existent preset
        // Just save current state as this preset
        [self.panelController saveCurrentLayoutAsPreset:presetName];
    }
}

- (void)createDefaultPreset:(NSString *)presetName {
    // This would create different default layouts based on the preset name
    // For now, just save the current layout
    [self.panelController saveCurrentLayoutAsPreset:presetName];
}

- (void)updatePresetMenu {
    NSMenu *menu = [self.presetPopup menu];
    
    // Remove all items except the first two (title and separator)
    while (menu.numberOfItems > 2) {
        [menu removeItemAtIndex:2];
    }
    
    // Add available presets
    NSArray *presets = [self.panelController availablePresets];
    for (NSString *presetName in presets) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:presetName
                                                       action:nil
                                                keyEquivalent:@""];
        item.tag = 1; // Mark as selectable
        [menu addItem:item];
    }
    
    // Add delete option if there are presets
    if (presets.count > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Preset..."
                                                            action:@selector(showDeletePresetMenu:)
                                                     keyEquivalent:@""];
        deleteItem.target = self;
        [menu addItem:deleteItem];
    }
}

- (void)showDeletePresetMenu:(id)sender {
    // TODO: Implement preset deletion UI
}

@end
