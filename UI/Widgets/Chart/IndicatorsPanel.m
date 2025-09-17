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

@interface IndicatorsPanel () <NSComboBoxDataSource, NSComboBoxDelegate>

@property (nonatomic, strong) NSVisualEffectView *backgroundView;
@property (nonatomic, strong) NSView *headerView;
@property (nonatomic, strong) NSView *footerView;

@property (nonatomic, strong) NSStackView *mainStackView;

// UI Components (readwrite for internal use)
@property (nonatomic, assign) BOOL isUpdatingComboBoxSelection;

@property (nonatomic, strong, readwrite) NSComboBox *templateComboBox;          // ✅ FIXED: readwrite
@property (nonatomic, strong, readwrite) NSButton *templateSettingsButton;
@property (nonatomic, strong, readwrite) NSButton *templateSaveButton;
@property (nonatomic, strong, readwrite) NSOutlineView *templateOutlineView;
@property (nonatomic, strong, readwrite) NSScrollView *outlineScrollView;
@property (nonatomic, strong, readwrite) NSButton *applyButton;
@property (nonatomic, strong, readwrite) NSButton *resetButton;
@property (nonatomic, strong, readwrite) NSButton *saveAsButton;


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
    self.templateComboBox.usesDataSource = YES;
    self.templateComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateComboBox.dataSource = self;
    self.templateComboBox.delegate = self;
    self.templateComboBox.hasVerticalScroller = YES;
    self.templateComboBox.numberOfVisibleItems = 10;
    
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

// Versione aggiornata che mantiene la selezione corrente della ComboBox invece di forzare sempre il primo template
- (void)loadAvailableTemplates:(NSArray<ChartTemplateModel *> *)templates {
    self.isLoadingTemplates = YES;
    self.availableTemplates = templates;
    
    NSLog(@"📋 IndicatorsPanel: Loaded %ld runtime templates", (long)templates.count);
    
   
    
    // Mantieni la selezione corrente se esiste
    NSInteger indexToSelect = 0; // default
    if (self.currentTemplate) {
        for (NSUInteger i = 0; i < self.availableTemplates.count; i++) {
            if ([self.availableTemplates[i].templateID isEqualToString:self.currentTemplate.templateID]) {
                indexToSelect = i;
                break;
            }
        }
    }
    [self.templateComboBox reloadData];
    if (self.availableTemplates.count > 0) {
        [self selectTemplate:self.availableTemplates[indexToSelect]];
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
    
    // ✅ FIXED: Usa flag per prevenire loop
    self.isUpdatingComboBoxSelection = YES;
    
    // Find template by ID and update combo box
    NSInteger index = NSNotFound;
    for (NSUInteger i = 0; i < self.availableTemplates.count; i++) {
        ChartTemplateModel *tempTemplate = self.availableTemplates[i];
        if ([tempTemplate.templateID isEqualToString:template.templateID]) {
            index = i;
            break;
        }
    }
    
    if (index != NSNotFound && index >= 0 && index < (NSInteger)self.availableTemplates.count) {
        [self.templateComboBox selectItemAtIndex:index];
    } else {
        [self.templateComboBox selectItemAtIndex:-1];
    }
    
    // ✅ RESET flag
    self.isUpdatingComboBoxSelection = NO;
    
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


- (BOOL)hasChangesToApply {
    if (!self.currentTemplate || !self.originalTemplate) {
        return NO;
    }
    
    // ✅ MAIN CASE: Different template selected from ComboBox
    if (![self.currentTemplate.templateID isEqualToString:self.originalTemplate.templateID]) {
        NSLog(@"📝 Different template selected: current='%@' vs original='%@'",
              self.currentTemplate.templateName, self.originalTemplate.templateName);
        return YES;
    }
    
    // ✅ SECONDARY CASE: Same template but modified content
    if (![self.currentTemplate.templateName isEqualToString:self.originalTemplate.templateName]) {
        return YES;
    }
    
    // ✅ Check if panels structure changed
    if (self.currentTemplate.panels.count != self.originalTemplate.panels.count) {
        return YES;
    }
    
    // ✅ Check if individual panels changed
    for (NSUInteger i = 0; i < self.currentTemplate.panels.count; i++) {
        ChartPanelTemplateModel *currentPanel = self.currentTemplate.panels[i];
        ChartPanelTemplateModel *originalPanel = self.originalTemplate.panels[i];
        
        if (![currentPanel.panelID isEqualToString:originalPanel.panelID] ||
            ![currentPanel.rootIndicatorType isEqualToString:originalPanel.rootIndicatorType] ||
            currentPanel.relativeHeight != originalPanel.relativeHeight ||
            currentPanel.displayOrder != originalPanel.displayOrder) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)hasUnsavedChanges {
    return [self hasChangesToApply];
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
            
            // ✅ USA PRIMA "type", poi fallback a "indicatorID" per retrocompatibilità
            NSString *indicatorType = childIndicatorData[@"type"] ?: childIndicatorData[@"indicatorID"];
            NSString *instanceID = childIndicatorData[@"instanceID"];
            NSDictionary *parameters = childIndicatorData[@"parameters"];
            
            if (!indicatorType) {
                NSLog(@"❌ IndicatorsPanel: Missing indicator type in childIndicatorData");
                return nil;
            }
            
            IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
            TechnicalIndicatorBase *indicator = [registry createIndicatorWithIdentifier:indicatorType parameters:parameters];
            
            if (indicator) {
                // ✅ ASSEGNA L'instanceID COME indicatorID (se esiste)
                if (instanceID) {
                    indicator.indicatorID = instanceID;
                }
                // Set additional properties from metadata
                indicator.isVisible = [childIndicatorData[@"isVisible"] boolValue];
                
                NSLog(@"📋 IndicatorsPanel: Panel '%@' child %ld: %@ indicator (instanceID: %@)",
                      panel.displayName, (long)index, indicatorType, instanceID);
                return indicator;
            } else {
                NSLog(@"❌ IndicatorsPanel: Failed to create indicator %@ from registry", indicatorType);
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
    if (self.isLoadingTemplates || self.isUpdatingComboBoxSelection) {
        NSLog(@"⏳ IndicatorsPanel: Ignoring combo box change (loading:%@ updating:%@)",
              self.isLoadingTemplates ? @"YES" : @"NO",
              self.isUpdatingComboBoxSelection ? @"YES" : @"NO");
        return;
    }

    NSInteger selectedIndex = [self.templateComboBox indexOfSelectedItem];
    NSLog(@"👆 IndicatorsPanel: ComboBox selection changed to index: %ld", (long)selectedIndex);

    if (selectedIndex >= 0 && selectedIndex < (NSInteger)self.availableTemplates.count) {
        ChartTemplateModel *selectedTemplate = self.availableTemplates[selectedIndex];

        // ✅ Set flag before updating currentTemplate
        self.isUpdatingComboBoxSelection = YES;
        // ✅ FIXED: Update current template but keep original unchanged
        // This allows the Apply button to be enabled when a different template is selected
        self.currentTemplate = [selectedTemplate createWorkingCopy];
        // NOTE: self.originalTemplate stays the same (the currently applied template)

        // ✅ Update UI displays
        [self refreshTemplateDisplay];
        [self updateButtonStates]; // ✅ This will now enable Apply/Reset buttons
        // ✅ Reset flag after updating
        self.isUpdatingComboBoxSelection = NO;

        /*
        // Notify delegate of selection (but don't apply yet)
        !!!!!!! commentatta perche riazzera la selezione del templatecombobox
        if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didSelectTemplate:)]) {
          //  [self.delegate indicatorsPanel:self didSelectTemplate:selectedTemplate];
        }
         */
    }
}


#pragma mark - Button Actions - UPDATED with Template Settings Menu

- (void)templateSettingsAction:(NSButton *)sender {
    NSLog(@"⚙️ IndicatorsPanel: Template settings action");
    
    if (!self.currentTemplate) {
        NSLog(@"⚠️ No current template for settings");
        return;
    }
    
    // ✅ Create template settings menu
    NSMenu *settingsMenu = [self createTemplateSettingsMenu];
    
    // ✅ Show popup menu below the button
    NSRect buttonFrame = sender.frame;
    NSPoint menuOrigin = NSMakePoint(NSMinX(buttonFrame), NSMinY(buttonFrame));
    
    [settingsMenu popUpMenuPositioningItem:nil atLocation:menuOrigin inView:sender.superview];
}

// ✅ NEW: Create template settings menu
- (NSMenu *)createTemplateSettingsMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    
    BOOL isDefault = self.currentTemplate.isDefault;
    BOOL canDelete = !isDefault && self.availableTemplates.count > 1;
    
    // ✅ Rename Template
    NSMenuItem *renameItem = [[NSMenuItem alloc] initWithTitle:@"Rename Template..."
                                                        action:@selector(renameCurrentTemplate:)
                                                 keyEquivalent:@""];
    renameItem.target = self;
    renameItem.enabled = !isDefault; // Can't rename default template
    [menu addItem:renameItem];
    
    // ✅ Duplicate Template
    NSMenuItem *duplicateItem = [[NSMenuItem alloc] initWithTitle:@"Duplicate Template..."
                                                           action:@selector(duplicateCurrentTemplate:)
                                                    keyEquivalent:@""];
    duplicateItem.target = self;
    [menu addItem:duplicateItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // ✅ Delete Template
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Template..."
                                                        action:@selector(deleteCurrentTemplate:)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    deleteItem.enabled = canDelete;
    if (!canDelete) {
        if (isDefault) {
            deleteItem.title = @"Delete Template (Cannot delete default)";
        } else {
            deleteItem.title = @"Delete Template (Last template)";
        }
    }
    [menu addItem:deleteItem];
    
    return menu;
}

#pragma mark - Template Management Actions - NEW

// ✅ NEW: Rename current template
- (void)renameCurrentTemplate:(NSMenuItem *)sender {
    if (!self.currentTemplate || self.currentTemplate.isDefault) {
        NSLog(@"❌ Cannot rename default template");
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Template";
    alert.informativeText = @"Enter a new name for the template:";
    alert.alertStyle = NSAlertStyleInformational;
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    input.stringValue = self.currentTemplate.templateName;
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
            [self performRenameTemplate:self.currentTemplate newName:input.stringValue];
        }
    }];
}

// ✅ NEW: Duplicate current template
- (void)duplicateCurrentTemplate:(NSMenuItem *)sender {
    if (!self.currentTemplate) {
        NSLog(@"❌ No current template to duplicate");
        return;
    }
    
    // ✅ Generate unique name with "Copy #N" pattern
    NSString *baseName = self.currentTemplate.templateName;
    NSString *newName = [self generateUniqueCopyName:baseName];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Duplicate Template";
    alert.informativeText = @"Enter a name for the duplicate template:";
    alert.alertStyle = NSAlertStyleInformational;
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    input.stringValue = newName;
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Duplicate"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
            [self performDuplicateTemplate:self.currentTemplate newName:input.stringValue];
        }
    }];
}

// ✅ NEW: Delete current template
- (void)deleteCurrentTemplate:(NSMenuItem *)sender {
    if (!self.currentTemplate || self.currentTemplate.isDefault || self.availableTemplates.count <= 1) {
        NSLog(@"❌ Cannot delete template: default=%@ count=%ld",
              self.currentTemplate.isDefault ? @"YES" : @"NO",
              (long)self.availableTemplates.count);
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Template";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the template '%@'? This action cannot be undone.",
                            self.currentTemplate.templateName];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self performDeleteTemplate:self.currentTemplate];
        }
    }];
}

#pragma mark - Template Operations Implementation - NEW

// ✅ NEW: Perform rename operation
- (void)performRenameTemplate:(ChartTemplateModel *)template newName:(NSString *)newName {
    NSLog(@"📝 Renaming template '%@' to '%@'", template.templateName, newName);
    
    // Update template name
    template.templateName = newName;
    template.modifiedDate = [NSDate date];
    
    // Save via DataHub
    [[DataHub shared] saveChartTemplate:template completion:^(BOOL success, ChartTemplateModel *savedTemplate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && savedTemplate) {
                NSLog(@"✅ Template renamed successfully");
                
                // Reload templates and maintain selection
                [self reloadTemplatesAndSelect:savedTemplate];
                
            } else {
                NSLog(@"❌ Failed to rename template");
                [self showErrorAlert:@"Rename Failed"
                             message:@"Could not rename the template. Please try again."];
            }
        });
    }];
}

// ✅ NEW: Perform duplicate operation
- (void)performDuplicateTemplate:(ChartTemplateModel *)sourceTemplate newName:(NSString *)newName {
    NSLog(@"📋 Duplicating template '%@' as '%@'", sourceTemplate.templateName, newName);
    
    // Use DataHub's duplicate method
    [[DataHub shared] duplicateChartTemplate:sourceTemplate.templateID
                                     newName:newName
                                  completion:^(BOOL success, ChartTemplateModel *newTemplate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && newTemplate) {
                NSLog(@"✅ Template duplicated successfully");
                
                // Reload templates and select the new duplicate
                [self reloadTemplatesAndSelect:newTemplate];
                
            } else {
                NSLog(@"❌ Failed to duplicate template");
                [self showErrorAlert:@"Duplicate Failed"
                             message:@"Could not duplicate the template. Please try again."];
            }
        });
    }];
}

// ✅ NEW: Perform delete operation
- (void)performDeleteTemplate:(ChartTemplateModel *)template {
    NSLog(@"🗑️ Deleting template '%@'", template.templateName);
    
    // Find next template to select after deletion
    ChartTemplateModel *nextTemplate = [self findNextTemplateAfterDeleting:template];
    
    // Delete via DataHub
    [[DataHub shared] deleteChartTemplate:template.templateID completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"✅ Template deleted successfully");
                NSMutableArray *mutableTemplates = [self.availableTemplates mutableCopy];
                   [mutableTemplates removeObject:template];
                   self.availableTemplates = [mutableTemplates copy];
                
                // Reload templates and select next available
                [self reloadTemplatesAndSelect:nextTemplate];
                
            } else {
                NSLog(@"❌ Failed to delete template");
                [self showErrorAlert:@"Delete Failed"
                             message:@"Could not delete the template. Please try again."];
            }
        });
    }];
}

#pragma mark - Helper Methods - NEW

// ✅ NEW: Generate unique copy name with "Copy #N" pattern
- (NSString *)generateUniqueCopyName:(NSString *)baseName {
    NSString *copyName = [NSString stringWithFormat:@"%@ Copy", baseName];
    
    // Check if base copy name exists
    if (![self templateNameExists:copyName]) {
        return copyName;
    }
    
    // Find next available number
    NSInteger copyNumber = 2;
    NSString *numberedCopyName;
    
    do {
        numberedCopyName = [NSString stringWithFormat:@"%@ Copy %ld", baseName, (long)copyNumber];
        copyNumber++;
    } while ([self templateNameExists:numberedCopyName] && copyNumber < 100); // Safety limit
    
    return numberedCopyName;
}

// ✅ NEW: Check if template name exists
- (BOOL)templateNameExists:(NSString *)name {
    for (ChartTemplateModel *template in self.availableTemplates) {
        if ([template.templateName isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

// ✅ NEW: Find next template to select after deletion
- (ChartTemplateModel *)findNextTemplateAfterDeleting:(ChartTemplateModel *)templateToDelete {
    NSInteger currentIndex = [self.availableTemplates indexOfObject:templateToDelete];
    
    if (currentIndex == NSNotFound) {
        return self.availableTemplates.firstObject;
    }
    
    // Try next template first
    if (currentIndex + 1 < self.availableTemplates.count) {
        return self.availableTemplates[currentIndex + 1];
    }
    
    // Try previous template
    if (currentIndex > 0) {
        return self.availableTemplates[currentIndex - 1];
    }
    
    // Fallback to first available (shouldn't happen if we have > 1 template)
    return self.availableTemplates.firstObject;
}

// ✅ NEW: Reload templates and select specific one
- (void)reloadTemplatesAndSelect:(ChartTemplateModel *)templateToSelect {
    if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestTemplateAction:forTemplate:)]) {
        // Use the optional delegate method if available
        [self.delegate indicatorsPanel:self didRequestTemplateAction:@"reload" forTemplate:templateToSelect];
    } else {
        // Fallback: Ask delegate to reload via ChartWidget
        NSLog(@"🔄 Requesting template reload from delegate");
        // The ChartWidget will call loadAvailableTemplates again
    }
}

// ✅ NEW: Show error alert
- (void)showErrorAlert:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"OK"];
    
    if (self.window) {
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
    } else {
        [alert runModal];
    }
}

- (void)applyAction:(NSButton *)sender {
    NSLog(@"✅ IndicatorsPanel: Apply action - requesting template application");
    
    if (self.currentTemplate && [self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestApplyTemplate:)]) {
        [self.delegate indicatorsPanel:self didRequestApplyTemplate:self.currentTemplate];
        
        // ✅ AFTER successful apply, sync the originalTemplate
        // This will disable the Apply/Reset buttons until next change
        self.originalTemplate = [self.currentTemplate createWorkingCopy];
        [self updateButtonStates];
    }
}
- (void)resetAction:(NSButton *)sender {
    NSLog(@"🔄 IndicatorsPanel: Reset action");
    
    if (!self.originalTemplate) return;
    
    // ✅ Reset to original template (the one currently applied)
    self.currentTemplate = [self.originalTemplate createWorkingCopy];
    
    // ✅ Update ComboBox selection to match the reset template
    self.isUpdatingComboBoxSelection = YES;
    
    NSInteger index = NSNotFound;
    for (NSUInteger i = 0; i < self.availableTemplates.count; i++) {
        ChartTemplateModel *template = self.availableTemplates[i];
        if ([template.templateID isEqualToString:self.originalTemplate.templateID]) {
            index = i;
            break;
        }
    }
    
    if (index != NSNotFound) {
        [self.templateComboBox selectItemAtIndex:index];
    }
    
    self.isUpdatingComboBoxSelection = NO;
    
    // ✅ Update UI
    [self refreshTemplateDisplay];
    [self updateButtonStates]; // This will disable Apply/Reset buttons
}


- (void)saveAsAction:(NSButton *)sender {
    NSLog(@"💾 IndicatorsPanel: Save As action");
    [self showSaveAsDialog];
}

- (void)updateButtonStates {
    BOOL hasTemplate = (self.currentTemplate != nil);
    BOOL hasChanges = [self hasChangesToApply]; // ✅ NEW: Different logic
    
    self.applyButton.enabled = hasTemplate && hasChanges;
    self.resetButton.enabled = hasTemplate && hasChanges;
    self.saveAsButton.enabled = hasTemplate;
    
    NSLog(@"🔘 Button states: hasTemplate=%@ hasChanges=%@ → Apply=%@ Reset=%@",
          hasTemplate ? @"YES" : @"NO",
          hasChanges ? @"YES" : @"NO",
          self.applyButton.enabled ? @"ON" : @"OFF",
          self.resetButton.enabled ? @"ON" : @"OFF");
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
        
        // ✅ MENU PRINCIPALE: Add Child Indicator (con submenu gerarchico)
        if ([indicator canHaveChildren]) {
            NSMenuItem *addChildItem = [[NSMenuItem alloc] initWithTitle:@"Add Child Indicator" action:nil keyEquivalent:@""];
            NSMenu *childIndicatorSubmenu = [self createHierarchicalChildIndicatorMenuForIndicator:indicator];
            addChildItem.submenu = childIndicatorSubmenu;
            [menu addItem:addChildItem];
            
            [menu addItem:[NSMenuItem separatorItem]];
        }
        
        // ✅ CONFIGURAZIONE INDICATOR
        NSMenuItem *configureIndicatorItem = [[NSMenuItem alloc] initWithTitle:@"Configure Indicator..."
                                                                        action:@selector(configureIndicator:)
                                                                 keyEquivalent:@""];
        configureIndicatorItem.target = self;
        configureIndicatorItem.representedObject = indicator;
        [menu addItem:configureIndicatorItem];
        
        // ✅ RIMOZIONE INDICATOR
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
    
    // ✅ STRUTTURA STANDARDIZZATA
    NSMutableArray *childIndicators = [panel.childIndicatorsData mutableCopy] ?: [NSMutableArray array];
    
    NSDictionary *newIndicator = @{
        @"type": indicatorID,                               // ✅ Type per la creazione
        @"instanceID": [[NSUUID UUID] UUIDString],         // ✅ UUID unico
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
    
    NSLog(@"✅ Indicator added to panel data. Panel now has %ld indicators", (long)childIndicators.count);
}

- (void)configurePanelSettings:(NSMenuItem *)sender {
   /* ChartPanelTemplateModel *panel = sender.representedObject;
    NSLog(@"⚙️ IndicatorsPanel: Opening Panel Settings for: %@", panel.displayName);
    
    [PanelSettingsDialog showSettingsForPanel:panel
                                  parentWindow:self.window
                                    completion:^(BOOL saved, ChartPanelTemplateModel *updatedPanel) {
        if (saved && updatedPanel) {
            NSLog(@"✅ Panel settings updated: %@", updatedPanel.displayName);
            
            // Find and replace the panel in current template
            NSMutableArray *panels = [self.currentTemplate.panels mutableCopy];
            for (NSUInteger i = 0; i < panels.count; i++) {
                ChartPanelTemplateModel *existingPanel = panels[i];
                if ([existingPanel.panelID isEqualToString:panel.panelID]) {
                    panels[i] = updatedPanel;
                    break;
                }
            }
            
            // Update template
            self.currentTemplate.panels = [panels copy];
            
            // Refresh UI
            [self refreshTemplateDisplay];
            [self updateButtonStates];
            
            // Enable apply button
            self.applyButton.enabled = YES;
            self.resetButton.enabled = YES;
        }
    }];*/
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
    NSLog(@"⚙️ IndicatorsPanel: Opening Indicator Configuration for: %@", indicator.shortName);
    
    [IndicatorConfigurationDialog showConfigurationForIndicator:indicator
                                                   parentWindow:self.window
                                                     completion:^(BOOL saved, NSDictionary *updatedParameters) {
        if (saved && updatedParameters) {
            NSLog(@"✅ Indicator parameters updated: %@", indicator.shortName);
            
            // Apply updated parameters to indicator
            indicator.parameters = updatedParameters;
            
            // If this is a child indicator, update the childIndicatorsData
            [self updateChildIndicatorDataForIndicator:indicator withParameters:updatedParameters];
            
            // Refresh UI
            [self refreshTemplateDisplay];
            [self updateButtonStates];
            
            // Enable apply button
            self.applyButton.enabled = YES;
            self.resetButton.enabled = YES;
        }
    }];
}

- (void)removeIndicator:(NSMenuItem *)sender {
    TechnicalIndicatorBase *indicator = sender.representedObject;
    NSLog(@"🗑️ IndicatorsPanel: Remove Indicator: %@", indicator.shortName);
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Remove Indicator";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to remove %@?", indicator.shortName];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            // Perform actual removal
            BOOL removed = [self removeIndicatorFromTemplateData:indicator];
            
            if (removed) {
                NSLog(@"✅ Indicator removed: %@", indicator.shortName);
                [self refreshTemplateDisplay];
                [self updateButtonStates];
                
                // Enable apply button
                self.applyButton.enabled = YES;
                self.resetButton.enabled = YES;
            } else {
                NSLog(@"❌ Failed to remove indicator: %@", indicator.shortName);
            }
        }
    }];
}

- (BOOL)removeIndicatorFromTemplateData:(TechnicalIndicatorBase *)indicator {
    for (ChartPanelTemplateModel *panel in self.currentTemplate.panels) {
        NSMutableArray *childIndicators = [panel.childIndicatorsData mutableCopy];
        
        for (NSUInteger i = 0; i < childIndicators.count; i++) {
            NSDictionary *childData = childIndicators[i];
            
            // ✅ MATCH CORRETTO: Usa instanceID (che ora è l'indicatorID dell'istanza)
            if ([childData[@"instanceID"] isEqualToString:indicator.indicatorID]) {
                
                // Remove from array
                [childIndicators removeObjectAtIndex:i];
                
                // Update panel
                panel.childIndicatorsData = [childIndicators copy];
                
                NSLog(@"✅ Removed indicator with instanceID: %@", indicator.indicatorID);
                return YES;
            }
        }
    }
    
    NSLog(@"⚠️ Could not find indicator to remove with instanceID: %@", indicator.indicatorID);
    return NO;
}



- (void)showAddChildIndicatorDialog:(NSMenuItem *)sender {
    TechnicalIndicatorBase *parentIndicator = sender.representedObject;
    NSLog(@"🎯 IndicatorsPanel: Opening Add Child Indicator Dialog for parent: %@", parentIndicator.shortName);
    
    // Create and show selection dialog
    [self showChildIndicatorSelectionDialogForParent:parentIndicator];
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
    NSLog(@"💾 IndicatorsPanel: Opening Save As dialog");
    
    if (!self.currentTemplate) {
        NSLog(@"❌ No current template to save");
        return;
    }
    
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
            
            // ✅ FIXED: Create complete template with all data
            ChartTemplateModel *templateToSave = [self.currentTemplate createWorkingCopy];
            templateToSave.templateID = [[NSUUID UUID] UUIDString];
            templateToSave.templateName = input.stringValue;
            templateToSave.isDefault = NO;
            templateToSave.createdDate = [NSDate date];
            templateToSave.modifiedDate = [NSDate date];
            
            // Assign new IDs to all panels to avoid conflicts
            for (ChartPanelTemplateModel *panel in templateToSave.panels) {
                panel.panelID = [[NSUUID UUID] UUIDString];
            }
            
            NSLog(@"💾 Saving complete template: %@ (ID: %@)",
                  templateToSave.templateName, templateToSave.templateID);
            
            // ✅ FIXED: Call new delegate method with complete template instead of didRequestCreateTemplate
            if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestSaveTemplate:)]) {
                [self.delegate indicatorsPanel:self didRequestSaveTemplate:templateToSave];
            } else {
                NSLog(@"❌ Delegate does not implement didRequestSaveTemplate:");
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
#pragma mark - child indicator


- (NSMenu *)createHierarchicalChildIndicatorMenuForIndicator:(TechnicalIndicatorBase *)parentIndicator {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // ✅ HARDCODED CHILD INDICATORS SUBMENU
    NSMenuItem *hardcodedItem = [[NSMenuItem alloc] initWithTitle:@"Hardcoded Indicators" action:nil keyEquivalent:@""];
    NSMenu *hardcodedSubmenu = [self createCategorizedChildIndicatorSubmenuForIndicator:parentIndicator];
    hardcodedItem.submenu = hardcodedSubmenu;
    [menu addItem:hardcodedItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // ✅ CUSTOM CHILD INDICATORS SUBMENU
    NSMenuItem *customItem = [[NSMenuItem alloc] initWithTitle:@"Custom Indicators" action:nil keyEquivalent:@""];
    NSMenu *customSubmenu = [self createCustomChildIndicatorSubmenuForIndicator:parentIndicator];
    customItem.submenu = customSubmenu;
    [menu addItem:customItem];
    
    return menu;
}

- (NSMenu *)createCategorizedChildIndicatorSubmenuForIndicator:(TechnicalIndicatorBase *)parentIndicator {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry hardcodedIndicatorIdentifiers];
    
    // ✅ FILTER: Solo indicatori che possono essere figli di questo parent
    NSArray<NSString *> *compatibleIndicators = [self filterIndicatorsCompatibleWithParent:availableIndicators parentIndicator:parentIndicator];
    
    // ✅ CATEGORIZE: Raggruppa per tipo (stesso metodo del panel)
    NSDictionary<NSString *, NSArray<NSString *> *> *categories = [self categorizeIndicatorsForMenu:compatibleIndicators];
    
    for (NSString *categoryName in [categories.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:categoryName action:nil keyEquivalent:@""];
        NSMenu *categorySubmenu = [[NSMenu alloc] init];
        
        NSArray<NSString *> *indicatorsInCategory = categories[categoryName];
        for (NSString *indicatorID in [indicatorsInCategory sortedArrayUsingSelector:@selector(compare:)]) {
            NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
            NSString *displayName = [self displayNameForIndicator:indicatorID indicatorInfo:indicatorInfo];
            
            NSMenuItem *indicatorItem = [[NSMenuItem alloc] initWithTitle:displayName
                                                                   action:@selector(addChildIndicatorToIndicator:)
                                                            keyEquivalent:@""];
            indicatorItem.target = self;
            indicatorItem.representedObject = @{
                @"parentIndicator": parentIndicator,
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

- (NSMenu *)createCustomChildIndicatorSubmenuForIndicator:(TechnicalIndicatorBase *)parentIndicator {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    // ✅ CUSTOM CHILD INDICATOR OPTIONS
    NSMenuItem *importItem = [[NSMenuItem alloc] initWithTitle:@"Import from File..."
                                                        action:@selector(importCustomChildIndicator:)
                                                 keyEquivalent:@""];
    importItem.target = self;
    importItem.representedObject = parentIndicator;
    [submenu addItem:importItem];
    
    NSMenuItem *pineScriptItem = [[NSMenuItem alloc] initWithTitle:@"PineScript Editor..."
                                                            action:@selector(showPineScriptEditorForChild:)
                                                     keyEquivalent:@""];
    pineScriptItem.target = self;
    pineScriptItem.representedObject = parentIndicator;
    [submenu addItem:pineScriptItem];
    
    NSMenuItem *libraryItem = [[NSMenuItem alloc] initWithTitle:@"Browse Library..."
                                                         action:@selector(browseChildIndicatorLibrary:)
                                                  keyEquivalent:@""];
    libraryItem.target = self;
    libraryItem.representedObject = parentIndicator;
    [submenu addItem:libraryItem];
    
    return submenu;
}

#pragma mark - Child Indicator Actions

- (void)addChildIndicatorToIndicator:(NSMenuItem *)sender {
    NSDictionary *data = sender.representedObject;
    TechnicalIndicatorBase *parentIndicator = data[@"parentIndicator"];
    NSString *indicatorID = data[@"indicatorID"];
    NSDictionary *indicatorInfo = data[@"indicatorInfo"];
    
    NSLog(@"✅ Adding %@ child indicator to parent: %@", indicatorID, parentIndicator.shortName);
    
    // ✅ TROVA IL PANEL CHE CONTIENE QUESTO INDICATOR
    ChartPanelTemplateModel *containingPanel = [self findPanelContainingIndicator:parentIndicator];
    if (!containingPanel) {
        NSLog(@"❌ Could not find panel containing indicator: %@", parentIndicator.shortName);
        return;
    }
    
    // ✅ STRUTTURA STANDARDIZZATA (come addChildIndicator)
    NSMutableArray *childIndicators = [containingPanel.childIndicatorsData mutableCopy] ?: [NSMutableArray array];
    
    NSDictionary *newChildIndicator = @{
        @"type": indicatorID,                               // ✅ Type per la creazione
        @"instanceID": [[NSUUID UUID] UUIDString],         // ✅ UUID unico
        @"parameters": indicatorInfo[@"defaultParameters"] ?: @{},
        @"isVisible": @YES,
        @"displayOrder": @(childIndicators.count),
        @"parentIndicatorID": parentIndicator.indicatorID
    };
    
    [childIndicators addObject:newChildIndicator];
    containingPanel.childIndicatorsData = [childIndicators copy];
    
    // ✅ AGGIORNA UI
    [self refreshTemplateDisplay];
    [self updateButtonStates];
    
    // ✅ FORCE ENABLE Apply button
    self.applyButton.enabled = YES;
    self.resetButton.enabled = YES;
    
    NSLog(@"✅ Child indicator added. Panel now has %ld child indicators", (long)childIndicators.count);
}
#pragma mark - Helper Methods per Child Indicators

- (NSArray<NSString *> *)filterIndicatorsCompatibleWithParent:(NSArray<NSString *> *)indicators
                                               parentIndicator:(TechnicalIndicatorBase *)parentIndicator {
    
    NSMutableArray<NSString *> *compatibleIndicators = [[NSMutableArray alloc] init];
    
    // ✅ LOGICA DI COMPATIBILITÀ
    NSString *parentType = NSStringFromClass([parentIndicator class]);
    
    for (NSString *indicatorID in indicators) {
        // ✅ REGOLE DI COMPATIBILITÀ (esempi)
        
        // Moving averages possono avere oscillatori come figli
        if ([parentType isEqualToString:@"EMAIndicator"] || [parentType isEqualToString:@"SMAIndicator"]) {
            if ([indicatorID isEqualToString:@"RSI"] ||
                [indicatorID isEqualToString:@"MACD"] ||
                [indicatorID isEqualToString:@"Stochastic"]) {
                [compatibleIndicators addObject:indicatorID];
            }
        }
        
        // Security indicator può avere qualsiasi figlio
        if ([parentType isEqualToString:@"SecurityIndicator"]) {
            [compatibleIndicators addObject:indicatorID];
        }
        
        // Volume indicator può avere volume-based children
        if ([parentType isEqualToString:@"VolumeIndicator"]) {
            if ([indicatorID isEqualToString:@"VWAP"] ||
                [indicatorID isEqualToString:@"VolumeProfile"]) {
                [compatibleIndicators addObject:indicatorID];
            }
        }
        
        // ✅ DEFAULT: Se non ci sono regole specifiche, permetti tutto
        if (compatibleIndicators.count == 0) {
            [compatibleIndicators addObject:indicatorID];
        }
    }
    
    return [compatibleIndicators copy];
}

- (ChartPanelTemplateModel *)findPanelContainingIndicator:(TechnicalIndicatorBase *)indicator {
    // ✅ CERCA NELL'ATTUALE TEMPLATE
    if (!self.currentTemplate) return nil;
    
    for (ChartPanelTemplateModel *panel in self.currentTemplate.panels) {
        // Check if it's the root indicator
        if ([panel.rootIndicatorType isEqualToString:NSStringFromClass([indicator class])]) {
            return panel;
        }
        
        // Check if it's in child indicators
        for (NSDictionary *childData in panel.childIndicatorsData) {
            NSString *childIndicatorID = childData[@"indicatorID"];
            if ([childIndicatorID isEqualToString:NSStringFromClass([indicator class])]) {
                return panel;
            }
        }
    }
    
    return nil;
}

// ✅ STUBS per azioni custom (implementare più tardi)
- (void)importCustomChildIndicator:(NSMenuItem *)sender {
    NSLog(@"📥 Import custom child indicator - TODO");
}

- (void)showPineScriptEditorForChild:(NSMenuItem *)sender {
    NSLog(@"🌲 PineScript editor for child - TODO");
}

- (void)showChildIndicatorSelectionDialogForParent:(TechnicalIndicatorBase *)parentIndicator {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Child Indicator";
    alert.informativeText = [NSString stringWithFormat:@"Select an indicator to add as child of %@:", parentIndicator.shortName];
    alert.alertStyle = NSAlertStyleInformational;
    
    // Create popup for indicator selection
    NSPopUpButton *indicatorPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 250, 24)];
    
    // Get compatible indicators
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry allIndicatorIdentifiers];
    NSArray<NSString *> *compatibleIndicators = [self filterIndicatorsCompatibleWithParent:availableIndicators
                                                                          parentIndicator:parentIndicator];
    
    // Populate popup
    for (NSString *indicatorID in compatibleIndicators) {
        NSString *displayName = [self friendlyNameForIndicatorType:indicatorID];
        [indicatorPopup addItemWithTitle:displayName];
        indicatorPopup.lastItem.representedObject = indicatorID;
    }
    
    if (compatibleIndicators.count == 0) {
        [indicatorPopup addItemWithTitle:@"No compatible indicators available"];
        indicatorPopup.enabled = NO;
    }
    
    alert.accessoryView = indicatorPopup;
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Configure & Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            // Add with default parameters
            NSString *selectedIndicatorID = indicatorPopup.selectedItem.representedObject;
            if (selectedIndicatorID) {
                [self addChildIndicator:selectedIndicatorID toParent:parentIndicator withParameters:@{}];
            }
        } else if (returnCode == NSAlertSecondButtonReturn) {
            // Configure then add
            NSString *selectedIndicatorID = indicatorPopup.selectedItem.representedObject;
            if (selectedIndicatorID) {
                [self configureAndAddChildIndicator:selectedIndicatorID toParent:parentIndicator];
            }
        }
    }];
}

- (void)configureAndAddChildIndicator:(NSString *)indicatorID toParent:(TechnicalIndicatorBase *)parentIndicator {
    // Create temporary indicator for configuration
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    TechnicalIndicatorBase *tempIndicator = [registry createIndicatorWithIdentifier:indicatorID parameters:@{}];
    
    if (tempIndicator) {
        [IndicatorConfigurationDialog showConfigurationForIndicator:tempIndicator
                                                       parentWindow:self.window
                                                         completion:^(BOOL saved, NSDictionary *updatedParameters) {
            if (saved) {
                [self addChildIndicator:indicatorID
                               toParent:parentIndicator
                         withParameters:updatedParameters ?: @{}];
            }
        }];
    } else {
        // Fallback to default parameters
        [self addChildIndicator:indicatorID toParent:parentIndicator withParameters:@{}];
    }
}


- (void)browseChildIndicatorLibrary:(NSMenuItem *)sender {
    NSLog(@"📚 Browse child indicator library - TODO");
}

- (void)addChildIndicator:(NSString *)indicatorID
                 toParent:(TechnicalIndicatorBase *)parentIndicator
           withParameters:(NSDictionary *)parameters {
    
    // Find the panel containing the parent indicator
    ChartPanelTemplateModel *containingPanel = [self findPanelContainingIndicator:parentIndicator];
    if (!containingPanel) {
        NSLog(@"❌ Could not find panel containing parent indicator: %@", parentIndicator.shortName);
        return;
    }
    
    // ✅ STRUTTURA STANDARDIZZATA
    NSMutableArray *childIndicators = [containingPanel.childIndicatorsData mutableCopy] ?: [NSMutableArray array];
    
    NSDictionary *newChildIndicator = @{
        @"type": indicatorID,                               // ✅ Type per la creazione
        @"instanceID": [[NSUUID UUID] UUIDString],         // ✅ UUID unico
        @"parameters": parameters,
        @"isVisible": @YES,
        @"displayOrder": @(childIndicators.count),
        @"parentIndicatorID": parentIndicator.indicatorID
    };
    
    [childIndicators addObject:newChildIndicator];
    containingPanel.childIndicatorsData = [childIndicators copy];
    
    // Update UI
    [self refreshTemplateDisplay];
    [self updateButtonStates];
    
    // Force enable Apply button
    self.applyButton.enabled = YES;
    self.resetButton.enabled = YES;
    
    NSLog(@"✅ Added child indicator %@ to parent %@. Panel now has %ld child indicators",
          indicatorID, parentIndicator.shortName, (long)childIndicators.count);
}

// ✅ NUOVO METODO: Update child indicator data
- (void)updateChildIndicatorDataForIndicator:(TechnicalIndicatorBase *)indicator
                              withParameters:(NSDictionary *)parameters {
    
    // Find the panel and child indicator data to update
    for (ChartPanelTemplateModel *panel in self.currentTemplate.panels) {
        NSMutableArray *childIndicators = [panel.childIndicatorsData mutableCopy];
        
        for (NSUInteger i = 0; i < childIndicators.count; i++) {
            NSMutableDictionary *childData = [childIndicators[i] mutableCopy];
            
            // ✅ MATCH CORRETTO: Usa instanceID (che ora è l'indicatorID dell'istanza)
            if ([childData[@"instanceID"] isEqualToString:indicator.indicatorID]) {
                
                // Update parameters
                childData[@"parameters"] = parameters;
                childIndicators[i] = [childData copy];
                
                // Update panel
                panel.childIndicatorsData = [childIndicators copy];
                
                NSLog(@"✅ Updated child indicator data for: %@", indicator.shortName);
                return;
            }
        }
    }
    
    NSLog(@"⚠️ Could not find child indicator data to update for: %@", indicator.shortName);
}


// ✅ NUOVO METODO: Helper per nomi friendly
- (NSString *)friendlyNameForIndicatorType:(NSString *)indicatorType {
    // Remove "Indicator" suffix and add spaces
    NSString *name = [indicatorType stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
    
    // Add spaces before capital letters
    NSMutableString *friendlyName = [[NSMutableString alloc] init];
    for (NSUInteger i = 0; i < name.length; i++) {
        unichar c = [name characterAtIndex:i];
        
        if (i > 0 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c]) {
            [friendlyName appendString:@" "];
        }
        
        [friendlyName appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return [friendlyName copy];
}

@end
