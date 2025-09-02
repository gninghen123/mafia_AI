//
// IndicatorsPanel.m
// TradingApp
//
// Side panel implementation for chart template and indicators management
//

#import "IndicatorsPanel.h"
#import "DataHub+ChartTemplates.h"

// Outline view item types
static NSString *const kAddPanelItem = @"ADD_PANEL";
static NSString *const kAddIndicatorItem = @"ADD_INDICATOR";
static NSString *const kAddChildItem = @"ADD_CHILD";

@interface IndicatorsPanel ()

@property (nonatomic, strong) NSVisualEffectView *backgroundView;
@property (nonatomic, strong) NSView *headerView;
@property (nonatomic, strong) NSView *footerView;
@property (nonatomic, strong) NSStackView *mainStackView;

// UI Components (readwrite for internal use)
@property (nonatomic, strong, readwrite) NSComboBox *templateComboBox;
@property (nonatomic, strong, readwrite) NSButton *templateSettingsButton;
@property (nonatomic, strong, readwrite) NSButton *templateSaveButton;
@property (nonatomic, strong, readwrite) NSOutlineView *templateOutlineView;
@property (nonatomic, strong, readwrite) NSScrollView *outlineScrollView;
@property (nonatomic, strong, readwrite) NSButton *applyButton;
@property (nonatomic, strong, readwrite) NSButton *resetButton;
@property (nonatomic, strong, readwrite) NSButton *saveAsButton;

// State
@property (nonatomic, assign) BOOL isLoadingTemplates;

@end

@implementation IndicatorsPanel

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupDefaults];
        [self setupUI];
        [self setupConstraints];
    }
    return self;
}

- (void)setupDefaults {
    self.isVisible = NO;
    self.panelWidth = 280.0;
    self.availableTemplates = @[];
    self.currentTemplate = nil;
    self.originalTemplate = nil;
    self.isLoadingTemplates = NO;
}

#pragma mark - UI Setup

- (void)setupUI {
    // Background with visual effect
    self.backgroundView = [[NSVisualEffectView alloc] init];
    self.backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundView.material = NSVisualEffectMaterialSidebar;
    self.backgroundView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.backgroundView.state = NSVisualEffectStateActive;
    [self addSubview:self.backgroundView];
    
    // Main stack view
    self.mainStackView = [[NSStackView alloc] init];
    self.mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.mainStackView.alignment = NSLayoutAttributeCenterX;
    self.mainStackView.distribution = NSStackViewDistributionFill;
    self.mainStackView.spacing = 8;
    [self.backgroundView addSubview:self.mainStackView];
    
    [self setupHeaderView];
    [self setupOutlineView];
    [self setupFooterView];
}

- (void)setupHeaderView {
    self.headerView = [[NSView alloc] init];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Template selection combo box
    self.templateComboBox = [[NSComboBox alloc] init];
    self.templateComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateComboBox.placeholderString = @"Select Template...";
    self.templateComboBox.dataSource = self;
    self.templateComboBox.delegate = self;
    [self.headerView addSubview:self.templateComboBox];
    
    // Template settings button (⚙️)
    self.templateSettingsButton = [[NSButton alloc] init];
    self.templateSettingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateSettingsButton.title = @"⚙️";
    self.templateSettingsButton.bezelStyle = NSBezelStyleRegularSquare;
    self.templateSettingsButton.target = self;
    self.templateSettingsButton.action = @selector(templateSettingsAction:);
    [self.headerView addSubview:self.templateSettingsButton];
    
    // Template save button (💾)
    self.templateSaveButton = [[NSButton alloc] init];
    self.templateSaveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateSaveButton.title = @"💾";
    self.templateSaveButton.bezelStyle = NSBezelStyleRegularSquare;
    self.templateSaveButton.target = self;
    self.templateSaveButton.action = @selector(templateSaveAction:);
    [self.headerView addSubview:self.templateSaveButton];
    
    [self.mainStackView addArrangedSubview:self.headerView];
    
    // Header constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.heightAnchor constraintEqualToConstant:32],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.mainStackView.leadingAnchor constant:8],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.mainStackView.trailingAnchor constant:-8],
        
        [self.templateComboBox.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
        [self.templateComboBox.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.templateComboBox.trailingAnchor constraintEqualToAnchor:self.templateSettingsButton.leadingAnchor constant:-4],
        
        [self.templateSettingsButton.trailingAnchor constraintEqualToAnchor:self.templateSaveButton.leadingAnchor constant:-2],
        [self.templateSettingsButton.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.templateSettingsButton.widthAnchor constraintEqualToConstant:28],
        [self.templateSettingsButton.heightAnchor constraintEqualToConstant:28],
        
        [self.templateSaveButton.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
        [self.templateSaveButton.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.templateSaveButton.widthAnchor constraintEqualToConstant:28],
        [self.templateSaveButton.heightAnchor constraintEqualToConstant:28]
    ]];
}

- (void)setupOutlineView {
    // Scroll view container
    self.outlineScrollView = [[NSScrollView alloc] init];
    self.outlineScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.outlineScrollView.hasVerticalScroller = YES;
    self.outlineScrollView.hasHorizontalScroller = NO;
    self.outlineScrollView.autohidesScrollers = YES;
    self.outlineScrollView.borderType = NSBezelBorder;
    
    // Outline view
    self.templateOutlineView = [[NSOutlineView alloc] init];
    self.templateOutlineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateOutlineView.headerView = nil; // No header
    self.templateOutlineView.rowSizeStyle = NSTableViewRowSizeStyleSmall;
    self.templateOutlineView.floatsGroupRows = NO;
    self.templateOutlineView.allowsMultipleSelection = NO;
    self.templateOutlineView.allowsEmptySelection = YES;
    self.templateOutlineView.indentationPerLevel = 16.0;
    self.templateOutlineView.dataSource = self;
    self.templateOutlineView.delegate = self;
    
    // Add single column
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"TemplateColumn"];
    column.title = @"Template";
    column.minWidth = 200;
    column.maxWidth = 400;
    [self.templateOutlineView addTableColumn:column];
    
    self.outlineScrollView.documentView = self.templateOutlineView;
    [self.mainStackView addArrangedSubview:self.outlineScrollView];
}

- (void)setupFooterView {
    self.footerView = [[NSView alloc] init];
    self.footerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Apply button
    self.applyButton = [[NSButton alloc] init];
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyButton.title = @"Apply";
    self.applyButton.bezelStyle = NSBezelStyleRounded;
    self.applyButton.target = self;
    self.applyButton.action = @selector(applyAction:);
    [self.footerView addSubview:self.applyButton];
    
    // Reset button
    self.resetButton = [[NSButton alloc] init];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetButton.title = @"Reset";
    self.resetButton.bezelStyle = NSBezelStyleRounded;
    self.resetButton.target = self;
    self.resetButton.action = @selector(resetAction:);
    [self.footerView addSubview:self.resetButton];
    
    // Save As button
    self.saveAsButton = [[NSButton alloc] init];
    self.saveAsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveAsButton.title = @"Save As...";
    self.saveAsButton.bezelStyle = NSBezelStyleRounded;
    self.saveAsButton.target = self;
    self.saveAsButton.action = @selector(saveAsAction:);
    [self.footerView addSubview:self.saveAsButton];
    
    [self.mainStackView addArrangedSubview:self.footerView];
    
    // Footer constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.footerView.heightAnchor constraintEqualToConstant:40],
        [self.footerView.leadingAnchor constraintEqualToAnchor:self.mainStackView.leadingAnchor constant:8],
        [self.footerView.trailingAnchor constraintEqualToAnchor:self.mainStackView.trailingAnchor constant:-8],
        
        [self.applyButton.leadingAnchor constraintEqualToAnchor:self.footerView.leadingAnchor],
        [self.applyButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor],
        [self.applyButton.widthAnchor constraintEqualToConstant:60],
        
        [self.resetButton.centerXAnchor constraintEqualToAnchor:self.footerView.centerXAnchor],
        [self.resetButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor],
        [self.resetButton.widthAnchor constraintEqualToConstant:60],
        
        [self.saveAsButton.trailingAnchor constraintEqualToAnchor:self.footerView.trailingAnchor],
        [self.saveAsButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor],
        [self.saveAsButton.widthAnchor constraintEqualToConstant:80]
    ]];
}

- (void)setupConstraints {
    // Width constraint for animation
    self.widthConstraint = [self.widthAnchor constraintEqualToConstant:0]; // Start hidden
    self.widthConstraint.active = YES;
    
    // Background view fills the panel
    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.backgroundView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.backgroundView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.backgroundView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    
    // Main stack view constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.mainStackView.topAnchor constraintEqualToAnchor:self.backgroundView.topAnchor constant:8],
        [self.mainStackView.leadingAnchor constraintEqualToAnchor:self.backgroundView.leadingAnchor],
        [self.mainStackView.trailingAnchor constraintEqualToAnchor:self.backgroundView.trailingAnchor],
        [self.mainStackView.bottomAnchor constraintEqualToAnchor:self.backgroundView.bottomAnchor constant:-8]
    ]];
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
    self.widthConstraint.constant = self.panelWidth;
    
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.25;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.widthConstraint.animator setConstant:self.panelWidth];
        } completionHandler:^{
            if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didChangeVisibility:)]) {
                [self.delegate indicatorsPanel:self didChangeVisibility:YES];
            }
        }];
    } else {
        if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didChangeVisibility:)]) {
            [self.delegate indicatorsPanel:self didChangeVisibility:YES];
        }
    }
}

- (void)hideAnimated:(BOOL)animated {
    if (!self.isVisible) return;
    
    self.isVisible = NO;
    
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.25;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.widthConstraint.animator setConstant:0];
        } completionHandler:^{
            if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didChangeVisibility:)]) {
                [self.delegate indicatorsPanel:self didChangeVisibility:NO];
            }
        }];
    } else {
        self.widthConstraint.constant = 0;
        if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didChangeVisibility:)]) {
            [self.delegate indicatorsPanel:self didChangeVisibility:NO];
        }
    }
}

- (void)loadAvailableTemplates:(NSArray<ChartTemplate *> *)templates {
    self.availableTemplates = [templates copy];
    [self.templateComboBox reloadData];
    
    // Select first template if none selected
    if (!self.currentTemplate && templates.count > 0) {
        [self selectTemplate:templates.firstObject];
    }
}

- (void)selectTemplate:(ChartTemplate *)template {
    if (!template) return;
    
    self.originalTemplate = template;
    self.currentTemplate = [template createWorkingCopy];
    
    // Update combo box selection
    NSInteger index = [self.availableTemplates indexOfObjectPassingTest:^BOOL(ChartTemplate *obj, NSUInteger idx, BOOL *stop) {
        return [obj.templateID isEqualToString:template.templateID];
    }];
    
    if (index != NSNotFound) {
        [self.templateComboBox selectItemAtIndex:index];
    }
    
    [self refreshTemplateDisplay];
    [self updateButtonStates];
}

- (void)refreshTemplateDisplay {
    [self.templateOutlineView reloadData];
    [self.templateOutlineView expandItem:nil expandChildren:YES]; // Expand all by default
}

- (void)resetToOriginalTemplate {
    if (!self.originalTemplate) return;
    
    self.currentTemplate = [self.originalTemplate createWorkingCopy];
    [self refreshTemplateDisplay];
    [self updateButtonStates];
}

- (BOOL)hasUnsavedChanges {
    if (!self.currentTemplate || !self.originalTemplate) return NO;
    
    // Simple comparison - could be made more sophisticated
    return ![self.currentTemplate.templateName isEqualToString:self.originalTemplate.templateName] ||
           self.currentTemplate.panels.count != self.originalTemplate.panels.count;
}

- (NSString *)displayNameForPanelType:(NSString *)panelType {
    if ([panelType isEqualToString:@"SecurityIndicator"]) return @"Security";
    if ([panelType isEqualToString:@"VolumeIndicator"]) return @"Volume";
    if ([panelType isEqualToString:@"RSIIndicator"]) return @"RSI";
    if ([panelType isEqualToString:@"MACDIndicator"]) return @"MACD";
    
    // Remove "Indicator" suffix for display
    return [panelType stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
}

- (NSMenu *)contextMenuForItem:(id)item {
    NSMenu *menu = [[NSMenu alloc] init];
    
    if ([item isKindOfClass:[ChartPanelTemplate class]]) {
        [menu addItemWithTitle:@"Add Indicator..." action:@selector(addIndicatorToPanel:) keyEquivalent:@""];
        [menu addItemWithTitle:@"Remove Panel" action:@selector(removePanel:) keyEquivalent:@""];
        [menu addItemWithTitle:@"Panel Settings..." action:@selector(configurePanelSettings:) keyEquivalent:@""];
        
    } else if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        
        if (!indicator.isRootIndicator) {
            [menu addItemWithTitle:@"Remove Indicator" action:@selector(removeIndicator:) keyEquivalent:@""];
        }
        
        [menu addItemWithTitle:@"Configure..." action:@selector(configureIndicator:) keyEquivalent:@""];
        
        if ([indicator canHaveChildren]) {
            [menu addItemWithTitle:@"Add Child Indicator..." action:@selector(addChildIndicator:) keyEquivalent:@""];
        }
        
    } else if ([item isEqualToString:kAddPanelItem]) {
        [menu addItemWithTitle:@"Security Panel" action:@selector(addSecurityPanel:) keyEquivalent:@""];
        [menu addItemWithTitle:@"Volume Panel" action:@selector(addVolumePanel:) keyEquivalent:@""];
        [menu addItemWithTitle:@"RSI Panel" action:@selector(addRSIPanel:) keyEquivalent:@""];
        [menu addItemWithTitle:@"MACD Panel" action:@selector(addMACDPanel:) keyEquivalent:@""];
        
    } else if ([item isEqualToString:kAddIndicatorItem] || [item isEqualToString:kAddChildItem]) {
        [menu addItemWithTitle:@"SMA..." action:@selector(addSMAIndicator:) keyEquivalent:@""];
        [menu addItemWithTitle:@"EMA..." action:@selector(addEMAIndicator:) keyEquivalent:@""];
        [menu addItemWithTitle:@"RSI..." action:@selector(addRSIIndicator:) keyEquivalent:@""];
        [menu addItemWithTitle:@"MACD..." action:@selector(addMACDIndicator:) keyEquivalent:@""];
    }
    
    return menu.itemArray.count > 0 ? menu : nil;
}

#pragma mark - Private Methods

- (void)updateButtonStates {
    BOOL hasTemplate = (self.currentTemplate != nil);
    BOOL hasChanges = [self hasUnsavedChanges];
    
    self.applyButton.enabled = hasTemplate && hasChanges;
    self.resetButton.enabled = hasTemplate && hasChanges;
    self.saveAsButton.enabled = hasTemplate;
    self.templateSaveButton.enabled = hasTemplate;
    self.templateSettingsButton.enabled = hasTemplate;
}

#pragma mark - Action Methods

- (IBAction)templateSettingsAction:(NSButton *)sender {
    if (!self.currentTemplate) return;
    
    // Show template settings (rename, duplicate, delete, etc.)
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:@"Rename..." action:@selector(renameTemplate:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Duplicate..." action:@selector(duplicateTemplate:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Export..." action:@selector(exportTemplate:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Delete" action:@selector(deleteTemplate:) keyEquivalent:@""];
    
    [NSMenu popUpContextMenu:menu withEvent:[NSApp currentEvent] forView:sender];
}

- (IBAction)templateSaveAction:(NSButton *)sender {
    if (!self.currentTemplate) return;
    
    if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestApplyTemplate:)]) {
        [self.delegate indicatorsPanel:self didRequestApplyTemplate:self.currentTemplate];
    }
    
    // Update original template reference
    self.originalTemplate = [self.currentTemplate createWorkingCopy];
    [self updateButtonStates];
}

- (IBAction)applyAction:(NSButton *)sender {
    if (!self.currentTemplate) return;
    
    if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestApplyTemplate:)]) {
        [self.delegate indicatorsPanel:self didRequestApplyTemplate:self.currentTemplate];
    }
}

- (IBAction)resetAction:(NSButton *)sender {
    [self resetToOriginalTemplate];
}

- (IBAction)saveAsAction:(NSButton *)sender {
    if (!self.currentTemplate) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Save Template As";
    alert.informativeText = @"Enter a name for the new template:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Template name";
    input.stringValue = [NSString stringWithFormat:@"%@ Copy", self.currentTemplate.templateName];
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
        if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestCreateTemplate:)]) {
            [self.delegate indicatorsPanel:self didRequestCreateTemplate:input.stringValue];
        }
    }
}

#pragma mark - Template Action Methods

- (void)renameTemplate:(NSMenuItem *)sender {
    // Implementation for renaming template
}

- (void)duplicateTemplate:(NSMenuItem *)sender {
    // Implementation for duplicating template
}

- (void)exportTemplate:(NSMenuItem *)sender {
    // Implementation for exporting template
}

- (void)deleteTemplate:(NSMenuItem *)sender {
    // Implementation for deleting template
}

#pragma mark - Panel Action Methods

- (void)addIndicatorToPanel:(NSMenuItem *)sender {
    // Implementation for adding indicator to panel
}

- (void)removePanel:(NSMenuItem *)sender {
    // Implementation for removing panel
}

- (void)configurePanelSettings:(NSMenuItem *)sender {
    // Implementation for panel settings
}

#pragma mark - Indicator Action Methods

- (void)removeIndicator:(NSMenuItem *)sender {
    // Implementation for removing indicator
}

- (void)configureIndicator:(NSMenuItem *)sender {
    // Implementation for configuring indicator
}

- (void)addChildIndicator:(NSMenuItem *)sender {
    // Implementation for adding child indicator
}

#pragma mark - Add Panel Methods

- (void)addSecurityPanel:(NSMenuItem *)sender {
    // Implementation for adding security panel
}

- (void)addVolumePanel:(NSMenuItem *)sender {
    // Implementation for adding volume panel
}

- (void)addRSIPanel:(NSMenuItem *)sender {
    // Implementation for adding RSI panel
}

- (void)addMACDPanel:(NSMenuItem *)sender {
    // Implementation for adding MACD panel
}

#pragma mark - Add Indicator Methods

- (void)addSMAIndicator:(NSMenuItem *)sender {
    // Implementation for adding SMA indicator
}

- (void)addEMAIndicator:(NSMenuItem *)sender {
    // Implementation for adding EMA indicator
}

- (void)addRSIIndicator:(NSMenuItem *)sender {
    // Implementation for adding RSI indicator
}

- (void)addMACDIndicator:(NSMenuItem *)sender {
    // Implementation for adding MACD indicator
}

#pragma mark - NSOutlineView DataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (!self.currentTemplate) return 0;
    
    if (item == nil) {
        // Root level: panels + "Add Panel" row
        return self.currentTemplate.panels.count + 1;
    }
    
    if ([item isKindOfClass:[ChartPanelTemplate class]]) {
        ChartPanelTemplate *panel = item;
        // Panel level: root indicator + children + "Add Indicator" row
        NSInteger childCount = panel.rootIndicator ? 1 : 0;
        childCount += panel.rootIndicator.childIndicators.count;
        childCount += 1; // "Add Indicator..." row
        return childCount;
    }
    
    if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        // Indicator level: children + "Add Child" row (if supported)
        return indicator.childIndicators.count + ([indicator canHaveChildren] ? 1 : 0);
    }
    
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        // Root level
        if (index < self.currentTemplate.panels.count) {
            return [self.currentTemplate orderedPanels][index];
        } else {
            return kAddPanelItem; // "Add Panel..." row
        }
    }
    
    if ([item isKindOfClass:[ChartPanelTemplate class]]) {
        ChartPanelTemplate *panel = item;
        NSInteger currentIndex = 0;
        
        // Root indicator first
        if (panel.rootIndicator && index == currentIndex) {
            return panel.rootIndicator;
        }
        if (panel.rootIndicator) currentIndex++;
        
        // Child indicators
        if (index < currentIndex + panel.rootIndicator.childIndicators.count) {
            return panel.rootIndicator.childIndicators[index - currentIndex];
        }
        
        // "Add Indicator..." row
        return kAddIndicatorItem;
    }
    
    if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        if (index < indicator.childIndicators.count) {
            return indicator.childIndicators[index];
        } else {
            return kAddChildItem; // "Add Child..." row
        }
    }
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

#pragma mark - NSOutlineView Delegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSTableCellView *cellView = [outlineView makeViewWithIdentifier:@"IndicatorCell" owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = @"IndicatorCell";
        
        // Create text field
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.editable = NO;
        textField.font = [NSFont systemFontOfSize:12];
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        // Constraints
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4]
        ]];
    }
    
    // Configure cell content
    if ([item isKindOfClass:[ChartPanelTemplate class]]) {
        ChartPanelTemplate *panel = item;
        NSString *panelTypeName = [self displayNameForPanelType:panel.rootIndicatorType];
        cellView.textField.stringValue = [NSString stringWithFormat:@"📊 %@ Panel (%.0f%%)",
                                         panelTypeName, panel.relativeHeight * 100];
        cellView.textField.textColor = [NSColor labelColor];
        
    } else if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        NSString *icon = indicator.isRootIndicator ? @"📈" : @"➖";
        cellView.textField.stringValue = [NSString stringWithFormat:@"%@ %@", icon, [indicator displayName]];
        cellView.textField.textColor = indicator.isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        
    } else if ([item isEqualToString:kAddPanelItem]) {
        cellView.textField.stringValue = @"➕ Add Panel...";
        cellView.textField.textColor = [NSColor systemBlueColor];
        
    } else if ([item isEqualToString:kAddIndicatorItem]) {
        cellView.textField.stringValue = @"➕ Add Indicator...";
        cellView.textField.textColor = [NSColor systemBlueColor];
        
    } else if ([item isEqualToString:kAddChildItem]) {
        cellView.textField.stringValue = @"➕ Add Child...";
        cellView.textField.textColor = [NSColor systemBlueColor];
    }
    
    return cellView;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    // Handle selection changes if needed
}

- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn {
    // Handle column clicks for sorting if needed
}

#pragma mark - NSComboBox DataSource & Delegate

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    return self.availableTemplates.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (index < self.availableTemplates.count) {
        ChartTemplate *template = self.availableTemplates[index];
        return template.isDefault ? [NSString stringWithFormat:@"%@ (Default)", template.templateName] : template.templateName;
    }
    return nil;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedIndex = self.templateComboBox.indexOfSelectedItem;
    if (selectedIndex >= 0 && selectedIndex < self.availableTemplates.count) {
        ChartTemplate *selectedTemplate = self.availableTemplates[selectedIndex];
        [self selectTemplate:selectedTemplate];
        
        // Notify delegate
        if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didSelectTemplate:)]) {
            [self.delegate indicatorsPanel:self didSelectTemplate:selectedTemplate];
        }
    }
}

@end
