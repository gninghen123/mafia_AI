//
// IndicatorsPanel.m - PARTE 1/3
// TradingApp
//
// Side panel implementation for chart template and indicators management
// AGGIORNATO COMPLETAMENTE per ChartTemplateModel (Runtime Models)
//

#import "IndicatorsPanel.h"
#import "DataHub+ChartTemplates.h"
#import "IndicatorRegistry.h"
#import "Quartz/Quartz.h"
#import "TechnicalIndicatorBase+Hierarchy.h"
#import "TechnicalIndicatorBase.h"

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
    self.mainStackView.spacing = 8;
    self.mainStackView.edgeInsets = NSEdgeInsetsMake(12, 12, 12, 12);
    [self.backgroundView addSubview:self.mainStackView];
    
    [self setupHeader];
    [self setupTemplateOutlineView];
    [self setupFooter];
}

- (void)setupHeader {
    self.headerView = [[NSView alloc] init];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Template combo box
    self.templateComboBox = [[NSComboBox alloc] init];
    self.templateComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateComboBox.dataSource = self;
    self.templateComboBox.delegate = self;
    self.templateComboBox.hasVerticalScroller = YES;
    self.templateComboBox.numberOfVisibleItems = 10;
    self.templateComboBox.usesDataSource = YES;
    
    // Template settings button
    self.templateSettingsButton = [[NSButton alloc] init];
    self.templateSettingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateSettingsButton.title = @"⚙️";
    self.templateSettingsButton.target = self;
    self.templateSettingsButton.action = @selector(templateSettingsAction:);
    
    [self.headerView addSubview:self.templateComboBox];
    [self.headerView addSubview:self.templateSettingsButton];
    
    [self.mainStackView addArrangedSubview:self.headerView];
}

- (void)setupTemplateOutlineView {
    // Create outline view
    self.templateOutlineView = [[NSOutlineView alloc] init];
    self.templateOutlineView.dataSource = self;
    self.templateOutlineView.delegate = self;
    self.templateOutlineView.headerView = nil;
    self.templateOutlineView.rowSizeStyle = NSTableViewRowSizeStyleSmall;
    
    // ✅ FIX CRITICO: Aggiungere la NSTableColumn mancante
    NSTableColumn *templateColumn = [[NSTableColumn alloc] initWithIdentifier:@"TemplateColumn"];
    templateColumn.title = @"Template Structure";
    templateColumn.width = 250;
    templateColumn.minWidth = 180;
    templateColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    [self.templateOutlineView addTableColumn:templateColumn];
    
    // Create scroll view
    self.outlineScrollView = [[NSScrollView alloc] init];
    self.outlineScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.outlineScrollView.documentView = self.templateOutlineView;
    self.outlineScrollView.hasVerticalScroller = YES;
    self.outlineScrollView.hasHorizontalScroller = NO;
    self.outlineScrollView.autohidesScrollers = YES;
    
    [self.mainStackView addArrangedSubview:self.outlineScrollView];
}

- (void)setupFooter {
    self.footerView = [[NSView alloc] init];
    self.footerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Apply button
    self.applyButton = [[NSButton alloc] init];
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyButton.title = @"Apply";
    self.applyButton.target = self;
    self.applyButton.action = @selector(applyAction:);
    
    // Reset button
    self.resetButton = [[NSButton alloc] init];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetButton.title = @"Reset";
    self.resetButton.target = self;
    self.resetButton.action = @selector(resetAction:);
    
    // Save As button
    self.saveAsButton = [[NSButton alloc] init];
    self.saveAsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveAsButton.title = @"Save As...";
    self.saveAsButton.target = self;
    self.saveAsButton.action = @selector(saveAsAction:);
    
    [self.footerView addSubview:self.applyButton];
    [self.footerView addSubview:self.resetButton];
    [self.footerView addSubview:self.saveAsButton];
    
    [self.mainStackView addArrangedSubview:self.footerView];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Background view
        [self.backgroundView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.backgroundView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.backgroundView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.backgroundView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        
        // Main stack view
        [self.mainStackView.leadingAnchor constraintEqualToAnchor:self.backgroundView.leadingAnchor],
        [self.mainStackView.trailingAnchor constraintEqualToAnchor:self.backgroundView.trailingAnchor],
        [self.mainStackView.topAnchor constraintEqualToAnchor:self.backgroundView.topAnchor],
        [self.mainStackView.bottomAnchor constraintEqualToAnchor:self.backgroundView.bottomAnchor],
        
        // Header view constraints
        [self.headerView.heightAnchor constraintEqualToConstant:32],
        [self.templateComboBox.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
        [self.templateComboBox.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.templateComboBox.trailingAnchor constraintEqualToAnchor:self.templateSettingsButton.leadingAnchor constant:-8],
        [self.templateSettingsButton.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
        [self.templateSettingsButton.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.templateSettingsButton.widthAnchor constraintEqualToConstant:24],
        
        // Footer view constraints
        [self.footerView.heightAnchor constraintEqualToConstant:32],
        [self.applyButton.leadingAnchor constraintEqualToAnchor:self.footerView.leadingAnchor],
        [self.applyButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor],
        [self.resetButton.leadingAnchor constraintEqualToAnchor:self.applyButton.trailingAnchor constant:8],
        [self.resetButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor],
        [self.saveAsButton.trailingAnchor constraintEqualToAnchor:self.footerView.trailingAnchor],
        [self.saveAsButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor]
    ]];
}

#pragma mark - Animation

- (void)toggleVisibilityAnimated:(BOOL)animated {
    self.isVisible = !self.isVisible;
    
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.25;
            context.allowsImplicitAnimation = YES;
            
            if (self.widthConstraint) {
                self.widthConstraint.constant = self.isVisible ? self.panelWidth : 0;
            }
            self.alphaValue = self.isVisible ? 1.0 : 0.0;
            
            [self.superview layoutSubtreeIfNeeded];
        }];
    } else {
        if (self.widthConstraint) {
            self.widthConstraint.constant = self.isVisible ? self.panelWidth : 0;
        }
        self.alphaValue = self.isVisible ? 1.0 : 0.0;
    }
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didChangeVisibility:)]) {
        [self.delegate indicatorsPanel:self didChangeVisibility:self.isVisible];
    }
}

- (void)showAnimated:(BOOL)animated {
    if (!self.isVisible) {
        [self toggleVisibilityAnimated:animated];
    }
}

- (void)hideAnimated:(BOOL)animated {
    if (self.isVisible) {
        [self toggleVisibilityAnimated:animated];
    }
}

#pragma mark - Template Management - AGGIORNATO per runtime models

- (void)loadAvailableTemplates:(NSArray<ChartTemplateModel *> *)templates {
    self.isLoadingTemplates = YES;
    self.availableTemplates = templates;
    
    NSLog(@"📋 IndicatorsPanel: Loaded %ld runtime templates", (long)templates.count);
    
    [self.templateComboBox reloadData];
    
    // Select first template if none selected
    if (self.availableTemplates.count > 0 && !self.currentTemplate) {
        [self selectTemplate:self.availableTemplates[0]];
    }
    
    self.isLoadingTemplates = NO;
}

- (void)selectTemplate:(ChartTemplateModel *)template {
    if (!template) {
        NSLog(@"⚠️ IndicatorsPanel: Cannot select nil template");
        return;
    }
    
    NSLog(@"👆 IndicatorsPanel: Selecting runtime template: %@", template.templateName);
    
    self.originalTemplate = template;
    self.currentTemplate = [template createWorkingCopy];
    
    // ✅ CORREZIONE: Update combo box selection - find template by ID
    NSInteger index = NSNotFound;
    
    if (self.availableTemplates.count == 0) {
        NSLog(@"⚠️ IndicatorsPanel: No available templates, cannot update combo box selection");
        [self refreshTemplateDisplay];
        [self updateButtonStates];
        return;
    }
    
    for (NSUInteger i = 0; i < self.availableTemplates.count; i++) {
        ChartTemplateModel *tempTemplate = self.availableTemplates[i];
        if ([tempTemplate.templateID isEqualToString:template.templateID]) {
            index = i;
            break;
        }
    }
    
    if (index != NSNotFound &&
        index >= 0 &&
        index < (NSInteger)self.availableTemplates.count &&
        self.availableTemplates.count > 0) {
        
        [self.templateComboBox selectItemAtIndex:index];
        
    } else {
        [self.templateComboBox selectItemAtIndex:-1];
    }
    
    [self refreshTemplateDisplay];
    [self updateButtonStates];
}

- (void)refreshTemplateDisplay {
    [self.templateOutlineView reloadData];
    [self.templateOutlineView expandItem:nil expandChildren:YES];
}

- (void)resetToOriginalTemplate {
    if (!self.originalTemplate) return;
    
    self.currentTemplate = [self.originalTemplate createWorkingCopy];
    [self refreshTemplateDisplay];
    [self updateButtonStates];
}

- (BOOL)hasUnsavedChanges {
    if (!self.currentTemplate || !self.originalTemplate) return NO;
    
    // Check template name
    if (![self.currentTemplate.templateName isEqualToString:self.originalTemplate.templateName]) {
        return YES;
    }
    
    // Check panel count
    if (self.currentTemplate.panels.count != self.originalTemplate.panels.count) {
        return YES;
    }
    
    // ✅ Check individual panel changes including childIndicatorsData
    NSArray<ChartPanelTemplateModel *> *currentPanels = [self.currentTemplate orderedPanels];
    NSArray<ChartPanelTemplateModel *> *originalPanels = [self.originalTemplate orderedPanels];
    
    for (NSUInteger i = 0; i < currentPanels.count; i++) {
        ChartPanelTemplateModel *currentPanel = currentPanels[i];
        ChartPanelTemplateModel *originalPanel = originalPanels[i];
        
        // Check panel properties
        if (![currentPanel.rootIndicatorType isEqualToString:originalPanel.rootIndicatorType] ||
            fabs(currentPanel.relativeHeight - originalPanel.relativeHeight) > 0.01 ||
            currentPanel.childIndicatorsData.count != originalPanel.childIndicatorsData.count) {
            return YES;
        }
        
        // Check childIndicatorsData changes
        if (![currentPanel.childIndicatorsData isEqualToArray:originalPanel.childIndicatorsData]) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - NSOutlineView DataSource - AGGIORNATO per runtime models

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (!self.currentTemplate) {
        NSLog(@"⚠️ IndicatorsPanel: No current template, returning 0 children");
        return 0;
    }
    
    if (item == nil) {
        // ✅ PULITO: Solo panels, nessun placeholder
        NSInteger count = self.currentTemplate.panels.count;
        NSLog(@"🔢 IndicatorsPanel: Root level children count: %ld", (long)count);
        return count;
    }
    
    // ✅ AGGIORNATO: Usa ChartPanelTemplateModel
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        // ✅ MOSTRA CHILD INDICATORS CREATI DAL CHILDINDICATORSDATA
        NSInteger childCount = panel.childIndicatorsData.count;
        NSLog(@"🔢 IndicatorsPanel: Panel '%@' children count: %ld", panel.displayName, (long)childCount);
        return childCount;
    }
    
    // ✅ AGGIORNATO: TechnicalIndicatorBase reali
    if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        NSInteger childCount = indicator.childIndicators.count;
        NSLog(@"🔢 IndicatorsPanel: Indicator '%@' children count: %ld", indicator.shortName, (long)childCount);
        return childCount;
    }
    
    NSLog(@"🔢 IndicatorsPanel: Unknown item type, returning 0 children");
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (!self.currentTemplate) {
        NSLog(@"❌ IndicatorsPanel: No current template for child at index %ld", (long)index);
        return nil;
    }
    
    if (item == nil) {
        // ✅ PULITO: Solo panels reali
        if (index < self.currentTemplate.panels.count) {
            NSArray<ChartPanelTemplateModel *> *orderedPanels = [self.currentTemplate orderedPanels];
            ChartPanelTemplateModel *panel = orderedPanels[index];
            NSLog(@"📋 IndicatorsPanel: Root child %ld: Panel '%@'", (long)index, panel.displayName);
            return panel;
        }
        NSLog(@"❌ IndicatorsPanel: Invalid panel index %ld", (long)index);
        return nil;
    }
    
    // ✅ AGGIORNATO: Crea TechnicalIndicatorBase dal childIndicatorsData
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        if (index < panel.childIndicatorsData.count) {
            NSDictionary *childIndicatorData = panel.childIndicatorsData[index];
            
            // ✅ CONVERTIRE: Da dictionary a TechnicalIndicatorBase reale
            NSString *indicatorID = childIndicatorData[@"indicatorID"];
            NSDictionary *parameters = childIndicatorData[@"parameters"];
            
            IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
            TechnicalIndicatorBase *indicator = [registry createIndicatorWithIdentifier:indicatorID parameters:parameters];
            
            if (indicator) {
                // Set additional properties from metadata
                indicator.isVisible = [childIndicatorData[@"isVisible"] boolValue];
                
                NSLog(@"📋 IndicatorsPanel: Panel '%@' child %ld: %@ indicator", panel.displayName, (long)index, indicatorID);
                return indicator;
            } else {
                NSLog(@"❌ IndicatorsPanel: Failed to create indicator %@ from registry", indicatorID);
                return nil;
            }
        }
        NSLog(@"❌ IndicatorsPanel: Invalid indicator index %ld for panel '%@'", (long)index, panel.displayName);
        return nil;
    }
    
    // ✅ AGGIORNATO: TechnicalIndicatorBase children
    if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        if (index < indicator.childIndicators.count) {
            TechnicalIndicatorBase *child = indicator.childIndicators[index];
            NSLog(@"📋 IndicatorsPanel: Indicator '%@' child %ld: '%@'", indicator.shortName, (long)index, child.shortName);
            return child;
        }
        NSLog(@"❌ IndicatorsPanel: Invalid child index %ld for indicator '%@'", (long)index, indicator.shortName);
        return nil;
    }
    
    NSLog(@"❌ IndicatorsPanel: Unknown item type for child at index %ld", (long)index);
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    BOOL expandable = [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
    NSLog(@"🔍 IndicatorsPanel: Item expandable check: %@ -> %@",
          [item isKindOfClass:[ChartPanelTemplateModel class]] ? ((ChartPanelTemplateModel *)item).displayName : [item description],
          expandable ? @"YES" : @"NO");
    return expandable;
}

#pragma mark - NSOutlineView Delegate - AGGIORNATO per runtime models

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
    
    // ✅ PULITO: Configure cell content solo per item reali
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        NSString *panelTypeName = [self displayNameForPanelType:panel.rootIndicatorType];
        cellView.textField.stringValue = [NSString stringWithFormat:@"📊 %@ Panel (%.0f%%)",
                                          panelTypeName, panel.relativeHeight * 100];
        cellView.textField.textColor = [NSColor labelColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for panel: %@", cellView.textField.stringValue);
        
    } else if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        NSString *icon = indicator.isRootIndicator ? @"📈" : @"➖";
        cellView.textField.stringValue = [NSString stringWithFormat:@"%@ %@", icon, indicator.name ?: indicator.shortName];
        cellView.textField.textColor = indicator.isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for indicator: %@", cellView.textField.stringValue);
        
    } else {
        cellView.textField.stringValue = [NSString stringWithFormat:@"? %@", [item description]];
        cellView.textField.textColor = [NSColor secondaryLabelColor];
        NSLog(@"⚠️ IndicatorsPanel: Unknown item type for cell: %@", [item description]);
    }
    
    return cellView;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [self.templateOutlineView selectedRow];
    id selectedItem = [self.templateOutlineView itemAtRow:selectedRow];
    
    NSLog(@"👆 IndicatorsPanel: Outline selection changed to row %ld: %@",
          (long)selectedRow,
          [selectedItem isKindOfClass:[ChartPanelTemplateModel class]] ? ((ChartPanelTemplateModel *)selectedItem).displayName : [selectedItem description]);
}

#pragma mark - NSComboBox DataSource & Delegate - AGGIORNATI per runtime models

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    NSInteger count = self.availableTemplates.count;
    NSLog(@"🔢 IndicatorsPanel: ComboBox requesting count: %ld", (long)count);
    return count;
}

- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.availableTemplates.count) {
        NSLog(@"❌ IndicatorsPanel: Invalid combo box index: %ld (available: %ld)", (long)index, (long)self.availableTemplates.count);
        return nil;
    }
    
    ChartTemplateModel *template = self.availableTemplates[index];
    NSString *displayName = template.isDefault ?
    [NSString stringWithFormat:@"%@ (Default)", template.templateName] :
    template.templateName;
    
    NSLog(@"📝 IndicatorsPanel: ComboBox item %ld: %@", (long)index, displayName);
    return displayName;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    if (self.isLoadingTemplates) {
        NSLog(@"⏳ IndicatorsPanel: Ignoring combo box change during template loading");
        return;
    }
    
    NSInteger selectedIndex = [self.templateComboBox indexOfSelectedItem];
    NSLog(@"👆 IndicatorsPanel: ComboBox selection changed to index: %ld", (long)selectedIndex);
    
    if (selectedIndex >= 0 && selectedIndex < (NSInteger)self.availableTemplates.count) {
        ChartTemplateModel *selectedTemplate = self.availableTemplates[selectedIndex];
        
        // Notify delegate of selection (not application)
        if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didSelectTemplate:)]) {
            [self.delegate indicatorsPanel:self didSelectTemplate:selectedTemplate];
        }
        
        // Update current template for editing
        [self selectTemplate:selectedTemplate];
    }
}

#pragma mark - Button Actions

- (void)templateSettingsAction:(NSButton *)sender {
    NSLog(@"⚙️ IndicatorsPanel: Template settings action");
    // TODO: Show template settings menu/popup
}

- (void)applyAction:(NSButton *)sender {
    NSLog(@"✅ IndicatorsPanel: Apply action - requesting template application");
    
    if (self.currentTemplate && [self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestApplyTemplate:)]) {
        [self.delegate indicatorsPanel:self didRequestApplyTemplate:self.currentTemplate];
    }
}

- (void)resetAction:(NSButton *)sender {
    NSLog(@"🔄 IndicatorsPanel: Reset action");
    [self resetToOriginalTemplate];
}

- (void)saveAsAction:(NSButton *)sender {
    NSLog(@"💾 IndicatorsPanel: Save As action");
    [self showSaveAsDialog];
}

- (void)updateButtonStates {
    BOOL hasTemplate = (self.currentTemplate != nil);
    BOOL hasChanges = [self hasUnsavedChanges];
    
    self.applyButton.enabled = hasTemplate && hasChanges;
    self.resetButton.enabled = hasTemplate && hasChanges;
    self.saveAsButton.enabled = hasTemplate;
}

#pragma mark - Context Menu - PULITO e SEMPLIFICATO

- (NSMenu *)contextMenuForItem:(id)item {
    NSMenu *menu = [[NSMenu alloc] init];
    
    if (item == nil) {
        // ✅ ROOT LEVEL: Add Panel
        NSMenuItem *addPanelItem = [[NSMenuItem alloc] initWithTitle:@"Add Panel" action:nil keyEquivalent:@""];
        NSMenu *panelSubmenu = [self createPanelTypesSubmenu];
        addPanelItem.submenu = panelSubmenu;
        [menu addItem:addPanelItem];
        
    } else if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        // ✅ PANEL CONTEXT UNIFICATO: Add Indicator (con submenu), Configure Panel, Remove Panel
        NSMenuItem *addIndicatorItem = [[NSMenuItem alloc] initWithTitle:@"Add Indicator" action:nil keyEquivalent:@""];
        NSMenu *indicatorSubmenu = [self createHierarchicalIndicatorMenuForPanel:panel];
        addIndicatorItem.submenu = indicatorSubmenu;
        [menu addItem:addIndicatorItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *configurePanelItem = [[NSMenuItem alloc] initWithTitle:@"Configure Panel..."
                                                                    action:@selector(configurePanelSettings:)
                                                             keyEquivalent:@""];
        configurePanelItem.target = self;
        configurePanelItem.representedObject = panel;
        [menu addItem:configurePanelItem];
        
        // ✅ REMOVE con conferma per Security panel
        NSString *removeTitle = [panel.rootIndicatorType isEqualToString:@"SecurityIndicator"] ?
                               @"Remove Security Panel..." : @"Remove Panel";
        NSMenuItem *removePanelItem = [[NSMenuItem alloc] initWithTitle:removeTitle
                                                                 action:@selector(removePanelWithConfirmation:)
                                                          keyEquivalent:@""];
        removePanelItem.target = self;
        removePanelItem.representedObject = panel;
        [menu addItem:removePanelItem];
        
    } else if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        
        // ✅ INDICATOR CONTEXT: Add Child (se supportato), Configure, Remove
        if ([indicator canHaveChildren]) {
            NSMenuItem *addChildItem = [[NSMenuItem alloc] initWithTitle:@"Add Child Indicator..."
                                                                  action:@selector(showAddChildIndicatorDialog:)
                                                           keyEquivalent:@""];
            addChildItem.target = self;
            addChildItem.representedObject = indicator;
            [menu addItem:addChildItem];
            
            [menu addItem:[NSMenuItem separatorItem]];
        }
        
        NSMenuItem *configureIndicatorItem = [[NSMenuItem alloc] initWithTitle:@"Configure Indicator..."
                                                                        action:@selector(configureIndicator:)
                                                                 keyEquivalent:@""];
        configureIndicatorItem.target = self;
        configureIndicatorItem.representedObject = indicator;
        [menu addItem:configureIndicatorItem];
        
        NSMenuItem *removeIndicatorItem = [[NSMenuItem alloc] initWithTitle:@"Remove Indicator"
                                                                     action:@selector(removeIndicator:)
                                                              keyEquivalent:@""];
        removeIndicatorItem.target = self;
        removeIndicatorItem.representedObject = indicator;
        [menu addItem:removeIndicatorItem];
    }
    
    return menu.itemArray.count > 0 ? menu : nil;
}

#pragma mark - Menu Creation Methods

- (NSMenu *)createPanelTypesSubmenu {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry hardcodedIndicatorIdentifiers];
    NSArray<NSString *> *panelSuitableIndicators = [self filterIndicatorsForPanelTypes:availableIndicators];
    
    for (NSString *indicatorID in [panelSuitableIndicators sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
        NSString *panelName = [self panelNameForIndicator:indicatorID indicatorInfo:indicatorInfo];
        
        NSMenuItem *panelItem = [[NSMenuItem alloc] initWithTitle:panelName
                                                           action:@selector(addPanelFromMenu:)
                                                    keyEquivalent:@""];
        panelItem.target = self;
        panelItem.representedObject = @{
            @"indicatorID": indicatorID,
            @"panelName": panelName,
            @"defaultHeight": @([self defaultHeightForIndicator:indicatorID])
        };
        [submenu addItem:panelItem];
    }
    
    return submenu;
}

- (NSMenu *)createHierarchicalIndicatorMenuForPanel:(ChartPanelTemplateModel *)panel {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // ✅ HARDCODED SUBMENU
    NSMenuItem *hardcodedItem = [[NSMenuItem alloc] initWithTitle:@"Hardcoded Indicators" action:nil keyEquivalent:@""];
    NSMenu *hardcodedSubmenu = [self createCategorizedIndicatorSubmenuForPanel:panel];
    hardcodedItem.submenu = hardcodedSubmenu;
    [menu addItem:hardcodedItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // ✅ CUSTOM SUBMENU
    NSMenuItem *customItem = [[NSMenuItem alloc] initWithTitle:@"Custom Indicators" action:nil keyEquivalent:@""];
    NSMenu *customSubmenu = [self createCustomIndicatorSubmenu:panel];
    customItem.submenu = customSubmenu;
    [menu addItem:customItem];
    
    return menu;
}

- (NSMenu *)createCategorizedIndicatorSubmenuForPanel:(ChartPanelTemplateModel *)panel {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry hardcodedIndicatorIdentifiers];
    
    // ✅ CATEGORIZE: Raggruppa per tipo
    NSDictionary<NSString *, NSArray<NSString *> *> *categories = [self categorizeIndicatorsForMenu:availableIndicators];
    
    for (NSString *categoryName in [categories.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:categoryName action:nil keyEquivalent:@""];
        NSMenu *categorySubmenu = [[NSMenu alloc] init];
        
        NSArray<NSString *> *indicatorsInCategory = categories[categoryName];
        for (NSString *indicatorID in [indicatorsInCategory sortedArrayUsingSelector:@selector(compare:)]) {
            NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
            NSString *displayName = [self displayNameForIndicator:indicatorID indicatorInfo:indicatorInfo];
            
            NSMenuItem *indicatorItem = [[NSMenuItem alloc] initWithTitle:displayName
                                                                   action:@selector(addIndicatorToPanel:)
                                                            keyEquivalent:@""];
            indicatorItem.target = self;
            indicatorItem.representedObject = @{
                @"panel": panel,
                @"indicatorID": indicatorID,
                @"indicatorInfo": indicatorInfo
            };
            [categorySubmenu addItem:indicatorItem];
        }
        
        categoryItem.submenu = categorySubmenu;
        [submenu addItem:categoryItem];
    }
    
    return submenu;
}

- (NSMenu *)createCustomIndicatorSubmenu:(ChartPanelTemplateModel *)panel {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    // ✅ CUSTOM INDICATOR OPTIONS
    NSMenuItem *importItem = [[NSMenuItem alloc] initWithTitle:@"Import from File..."
                                                        action:@selector(importCustomIndicator:)
                                                 keyEquivalent:@""];
    importItem.target = self;
    importItem.representedObject = panel;
    [submenu addItem:importItem];
    
    NSMenuItem *pineScriptItem = [[NSMenuItem alloc] initWithTitle:@"PineScript Editor..."
                                                            action:@selector(showPineScriptEditor:)
                                                     keyEquivalent:@""];
    pineScriptItem.target = self;
    pineScriptItem.representedObject = panel;
    [submenu addItem:pineScriptItem];
    
    NSMenuItem *libraryItem = [[NSMenuItem alloc] initWithTitle:@"Browse Library..."
                                                         action:@selector(browseIndicatorLibrary:)
                                                  keyEquivalent:@""];
    libraryItem.target = self;
    libraryItem.representedObject = panel;
    [submenu addItem:libraryItem];
    
    return submenu;
}

#pragma mark - Context Menu Actions

- (void)addPanelFromMenu:(NSMenuItem *)sender {
    NSDictionary *data = sender.representedObject;
    NSString *indicatorID = data[@"indicatorID"];
    NSString *panelName = data[@"panelName"];
    double defaultHeight = [data[@"defaultHeight"] doubleValue];
    
    [self addPanelWithType:panelName rootIndicator:indicatorID defaultHeight:defaultHeight];
}

- (void)addIndicatorToPanel:(NSMenuItem *)sender {
    NSDictionary *data = sender.representedObject;
    ChartPanelTemplateModel *panel = data[@"panel"];
    NSString *indicatorID = data[@"indicatorID"];
    NSDictionary *indicatorInfo = data[@"indicatorInfo"];
    
    NSLog(@"✅ Adding %@ indicator to panel: %@", indicatorID, panel.displayName);
    
    // ✅ AGGIUNTA REALE: Aggiungi ai childIndicatorsData del panel
    NSMutableArray *childIndicators = [panel.childIndicatorsData mutableCopy] ?: [NSMutableArray array];
    
    NSDictionary *newIndicator = @{
        @"indicatorID": indicatorID,
        @"type": indicatorID,
        @"parameters": indicatorInfo[@"defaultParameters"] ?: @{},
        @"isVisible": @YES,
        @"displayOrder": @(childIndicators.count)
    };
    
    [childIndicators addObject:newIndicator];
    panel.childIndicatorsData = [childIndicators copy];
    
    // ✅ AGGIORNA UI
    [self refreshTemplateDisplay];
    [self updateButtonStates];
    
    // ✅ FORCE ENABLE Apply button
    self.applyButton.enabled = YES;
    self.resetButton.enabled = YES;
    
    NSLog(@"✅ Indicator added to panel data. Panel now has %ld child indicators", (long)childIndicators.count);
}

- (void)configurePanelSettings:(NSMenuItem *)sender {
    ChartPanelTemplateModel *panel = sender.representedObject;
    NSLog(@"⚙️ IndicatorsPanel: Configure Panel Settings: %@", panel.displayName);
    // TODO: Implementare Panel Settings Dialog (include anche root indicator config)
}

- (void)removePanelWithConfirmation:(NSMenuItem *)sender {
    ChartPanelTemplateModel *panel = sender.representedObject;
    
    // ✅ CONFERMA SPECIALE per Security Panel
    if ([panel.rootIndicatorType isEqualToString:@"SecurityIndicator"]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Remove Security Panel";
        alert.informativeText = @"Are you sure you want to remove the Security panel? This will remove the main price chart.";
        alert.alertStyle = NSAlertStyleCritical;
        [alert addButtonWithTitle:@"Remove"];
        [alert addButtonWithTitle:@"Cancel"];
        
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSAlertFirstButtonReturn) {
                [self removePanel:panel];
            }
        }];
    } else {
        // ✅ RIMOZIONE DIRETTA per altri panel
        [self removePanel:panel];
    }
}

- (void)configureIndicator:(NSMenuItem *)sender {
    TechnicalIndicatorBase *indicator = sender.representedObject;
    NSLog(@"⚙️ IndicatorsPanel: Configure Indicator: %@", indicator.shortName);
    
    // TODO: Implementare dialog di configurazione per singoli indicatori
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Configure Indicator";
    alert.informativeText = [NSString stringWithFormat:@"Configuration dialog for %@ not implemented yet", indicator.shortName];
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)removeIndicator:(NSMenuItem *)sender {
    TechnicalIndicatorBase *indicator = sender.representedObject;
    NSLog(@"🗑️ IndicatorsPanel: Remove Indicator: %@", indicator.shortName);
    
    // TODO: Implementare rimozione indicator con conferma
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Remove Indicator";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to remove %@?", indicator.shortName];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSLog(@"✅ Removing indicator: %@", indicator.shortName);
            // TODO: Implementare rimozione effettiva
            [self refreshTemplateDisplay];
        }
    }];
}

- (void)showAddChildIndicatorDialog:(NSMenuItem *)sender {
    TechnicalIndicatorBase *parentIndicator = sender.representedObject;
    NSLog(@"🎯 IndicatorsPanel: Show Add Child Indicator Dialog for parent: %@", parentIndicator.shortName);
    
    // TODO: Implementare aggiunta child indicator
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Child Indicator";
    alert.informativeText = [NSString stringWithFormat:@"Add child indicator to %@ not implemented yet", parentIndicator.shortName];
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

// ✅ PLACEHOLDER METHODS per le azioni custom
- (void)importCustomIndicator:(NSMenuItem *)sender {
    NSLog(@"📁 Import custom indicator - not implemented yet");
    // TODO: Implementare import da file
}

- (void)showPineScriptEditor:(NSMenuItem *)sender {
    NSLog(@"📝 PineScript editor - not implemented yet");
    // TODO: Implementare editor PineScript
}

- (void)browseIndicatorLibrary:(NSMenuItem *)sender {
    NSLog(@"📚 Browse indicator library - not implemented yet");
    // TODO: Implementare browser libreria
}

#pragma mark - Panel Management with Height Redistribution

- (void)addPanelWithType:(NSString *)panelType rootIndicator:(NSString *)rootIndicator defaultHeight:(double)defaultHeight {
    if (!self.currentTemplate) {
        NSLog(@"❌ Cannot add panel - no current template");
        return;
    }
    
    NSLog(@"➕ Adding %@ panel with root indicator %@", panelType, rootIndicator);
    
    // ✅ STEP 2: Redistribuisci le altezze esistenti
    double remainingHeight = 1.0 - defaultHeight;
    for (ChartPanelTemplateModel *existingPanel in self.currentTemplate.panels) {
        existingPanel.relativeHeight = (existingPanel.relativeHeight / [self.currentTemplate totalHeight]) * remainingHeight;
    }
    
    // ✅ STEP 3: Crea nuovo panel
    ChartPanelTemplateModel *newPanel = [ChartPanelTemplateModel panelWithID:nil
                                                                        name:panelType
                                                             rootIndicatorType:rootIndicator
                                                                      height:defaultHeight
                                                                       order:self.currentTemplate.panels.count];
    
    // ✅ STEP 4: Aggiungi al template
    [self.currentTemplate addPanel:newPanel];
    
    // ✅ STEP 5: Normalizza le altezze per sicurezza
    [self.currentTemplate normalizeHeights];
    
    // ✅ STEP 6: Aggiorna UI
    [self refreshTemplateDisplay];
    [self updateButtonStates];
    
    NSLog(@"✅ Panel added successfully. Total height: %.3f", [self.currentTemplate totalHeight]);
}

- (void)removePanel:(ChartPanelTemplateModel *)panel {
    if (!self.currentTemplate || !panel) {
        NSLog(@"❌ Cannot remove panel - invalid parameters");
        return;
    }
    
    NSLog(@"🗑️ Removing panel: %@", panel.displayName);
    
    // ✅ STEP 1: Rimuovi dal template
    [self.currentTemplate removePanel:panel];
    
    // ✅ STEP 2: Redistribuisci automaticamente le altezze rimanenti
    [self.currentTemplate normalizeHeights];
    
    // ✅ STEP 3: Aggiorna UI
    [self refreshTemplateDisplay];
    [self updateButtonStates];
    
    NSLog(@"✅ Panel removed successfully. Total height: %.3f", [self.currentTemplate totalHeight]);
}

#pragma mark - Helper Methods

- (NSArray<NSString *> *)filterIndicatorsForPanelTypes:(NSArray<NSString *> *)indicators {
    NSMutableArray<NSString *> *suitable = [NSMutableArray array];
    
    NSSet<NSString *> *excludedIndicators = [NSSet setWithArray:@[]];
    
    for (NSString *indicatorID in indicators) {
        if (![excludedIndicators containsObject:indicatorID]) {
            [suitable addObject:indicatorID];
        }
    }
    
    return [suitable copy];
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)categorizeIndicatorsForMenu:(NSArray<NSString *> *)indicators {
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *categories = [NSMutableDictionary dictionary];
    
    categories[@"Moving Averages"] = [NSMutableArray array];
    categories[@"Oscillators"] = [NSMutableArray array];
    categories[@"Volume"] = [NSMutableArray array];
    categories[@"Volatility"] = [NSMutableArray array];
    categories[@"Price Action"] = [NSMutableArray array];
    categories[@"Other"] = [NSMutableArray array];
    
    for (NSString *indicatorID in indicators) {
        if ([indicatorID containsString:@"MA"] || [indicatorID isEqualToString:@"SMA"] || [indicatorID isEqualToString:@"EMA"]) {
            [categories[@"Moving Averages"] addObject:indicatorID];
        } else if ([indicatorID isEqualToString:@"RSI"] || [indicatorID containsString:@"MACD"] || [indicatorID containsString:@"Stoch"]) {
            [categories[@"Oscillators"] addObject:indicatorID];
        } else if ([indicatorID containsString:@"Volume"]) {
            [categories[@"Volume"] addObject:indicatorID];
        } else if ([indicatorID isEqualToString:@"ATR"] || [indicatorID containsString:@"BB"]) {
            [categories[@"Volatility"] addObject:indicatorID];
        } else if ([indicatorID isEqualToString:@"SecurityIndicator"]) {
            [categories[@"Price Action"] addObject:indicatorID];
        } else {
            [categories[@"Other"] addObject:indicatorID];
        }
    }
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *categoryName in categories.allKeys) {
        if (categories[categoryName].count > 0) {
            result[categoryName] = [categories[categoryName] copy];
        }
    }
    
    return [result copy];
}

- (NSString *)panelNameForIndicator:(NSString *)indicatorID indicatorInfo:(NSDictionary *)indicatorInfo {
    static NSDictionary *panelNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        panelNames = @{
            @"SecurityIndicator": @"Security Panel",
            @"VolumeIndicator": @"Volume Panel",
            @"RSI": @"RSI Panel",
            @"SMA": @"SMA Panel",
            @"EMA": @"EMA Panel",
            @"ATR": @"ATR Panel",
            @"BB": @"Bollinger Bands Panel"
        };
    });
    
    NSString *panelName = panelNames[indicatorID];
    if (panelName) {
        return panelName;
    }
    
    NSString *cleanName = [indicatorID stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
    return [NSString stringWithFormat:@"%@ Panel", cleanName];
}

- (double)defaultHeightForIndicator:(NSString *)indicatorID {
    static NSDictionary *defaultHeights = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultHeights = @{
            @"SecurityIndicator": @0.6,
            @"VolumeIndicator": @0.2,
            @"RSI": @0.15,
            @"SMA": @0.0,
            @"EMA": @0.0,
            @"ATR": @0.15,
            @"BB": @0.0
        };
    });
    
    NSNumber *height = defaultHeights[indicatorID];
    return height ? [height doubleValue] : 0.2;
}

- (NSString *)displayNameForIndicator:(NSString *)indicatorID indicatorInfo:(NSDictionary *)indicatorInfo {
    NSString *displayName = indicatorInfo[@"displayName"];
    if (displayName && displayName.length > 0) {
        return displayName;
    }
    
    static NSDictionary *displayNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        displayNames = @{
            @"SecurityIndicator": @"Security (Price Chart)",
            @"VolumeIndicator": @"Volume",
            @"RSI": @"RSI (Relative Strength Index)",
            @"SMA": @"SMA (Simple Moving Average)",
            @"EMA": @"EMA (Exponential Moving Average)",
            @"ATR": @"ATR (Average True Range)",
            @"BB": @"Bollinger Bands"
        };
    });
    
    NSString *prettyName = displayNames[indicatorID];
    return prettyName ?: indicatorID;
}

- (NSString *)displayNameForPanelType:(NSString *)panelType {
    static NSDictionary *displayNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        displayNames = @{
            @"SecurityIndicator": @"Security",
            @"VolumeIndicator": @"Volume",
            @"RSIIndicator": @"RSI",
            @"MACDIndicator": @"MACD",
            @"EMA": @"EMA",
            @"SMA": @"SMA",
            @"BollingerBands": @"Bollinger Bands",
            @"Stochastic": @"Stochastic"
        };
    });
    
    NSString *displayName = displayNames[panelType];
    return displayName ?: panelType;
}

- (void)showSaveAsDialog {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Save Template As";
    alert.informativeText = @"Enter a name for the new template:";
    alert.alertStyle = NSAlertStyleInformational;
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    input.stringValue = [NSString stringWithFormat:@"%@ Copy", self.currentTemplate.templateName];
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
            ChartTemplateModel *duplicate = [self.currentTemplate createWorkingCopy];
            duplicate.templateID = [[NSUUID UUID] UUIDString];
            duplicate.templateName = input.stringValue;
            duplicate.isDefault = NO;
            duplicate.createdDate = [NSDate date];
            duplicate.modifiedDate = [NSDate date];
            
            for (ChartPanelTemplateModel *panel in duplicate.panels) {
                panel.panelID = [[NSUUID UUID] UUIDString];
            }
            
            if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestCreateTemplate:)]) {
                [self.delegate indicatorsPanel:self didRequestCreateTemplate:duplicate.templateName];
            }
        }
    }];
}

#pragma mark - Right-Click Support

- (void)rightMouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSPoint outlinePoint = [self.templateOutlineView convertPoint:point fromView:self];
    NSInteger row = [self.templateOutlineView rowAtPoint:outlinePoint];
    
    NSLog(@"🖱️ IndicatorsPanel: Right-click at row %ld", (long)row);
    
    if (row >= 0) {
        [self.templateOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        
        id item = [self.templateOutlineView itemAtRow:row];
        NSMenu *contextMenu = [self contextMenuForItem:item];
        
        if (contextMenu) {
            [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self.templateOutlineView];
        }
    } else {
        id item = nil;
        NSMenu *contextMenu = [self contextMenuForItem:item];
        
        if (contextMenu) {
            [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self.templateOutlineView];
        }
    }
}

#pragma mark - Window Management

- (NSWindow *)window {
    return [super window];
}

#pragma mark - Cleanup

- (void)dealloc {
    NSLog(@"♻️ IndicatorsPanel: Deallocating");
    
    self.templateComboBox.dataSource = nil;
    self.templateComboBox.delegate = nil;
    self.templateOutlineView.dataSource = nil;
    self.templateOutlineView.delegate = nil;
}

@end
