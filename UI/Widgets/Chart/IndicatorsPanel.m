//
// IndicatorsPanel.m - PARTE 1
// TradingApp
//
// Side panel implementation for chart template and indicators management
// AGGIORNATO COMPLETAMENTE per ChartTemplateModel (Runtime Models)
//

#import "IndicatorsPanel.h"
#import "DataHub+ChartTemplates.h"
#import "IndicatorRegistry.h"
#import "Quartz/Quartz.h"
#import "TechnicalIndicatorBase+Hierarchy.h"  // ✅ AGGIUNTO: Questo risolve gli errori
#import "TechnicalIndicatorBase.h"


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
        
        // Header constraints
        [self.templateComboBox.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
        [self.templateComboBox.trailingAnchor constraintEqualToAnchor:self.templateSettingsButton.leadingAnchor constant:-8],
        [self.templateComboBox.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.templateSettingsButton.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
        [self.templateSettingsButton.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.templateSettingsButton.widthAnchor constraintEqualToConstant:30],
        [self.headerView.heightAnchor constraintEqualToConstant:24],
        
        // Outline scroll view
        [self.outlineScrollView.heightAnchor constraintGreaterThanOrEqualToConstant:200],
        
        // Footer constraints
        [self.applyButton.leadingAnchor constraintEqualToAnchor:self.footerView.leadingAnchor],
        [self.resetButton.centerXAnchor constraintEqualToAnchor:self.footerView.centerXAnchor],
        [self.saveAsButton.trailingAnchor constraintEqualToAnchor:self.footerView.trailingAnchor],
        [self.applyButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor],
        [self.resetButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor],
        [self.saveAsButton.centerYAnchor constraintEqualToAnchor:self.footerView.centerYAnchor],
        [self.footerView.heightAnchor constraintEqualToConstant:32]
    ]];
}

#pragma mark - Public Methods - AGGIORNATI per runtime models

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
        self.widthConstraint.constant = self.panelWidth;
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

- (void)loadAvailableTemplates:(NSArray<ChartTemplateModel *> *)templates {
    NSLog(@"📋 IndicatorsPanel: Loading %ld runtime templates", (long)templates.count);
    
    self.availableTemplates = [templates copy];
    [self.templateComboBox reloadData];
    
    // Select first template if none selected
    if (!self.currentTemplate && templates.count > 0) {
        [self selectTemplate:templates.firstObject];
    }
    
    NSLog(@"✅ IndicatorsPanel: Templates loaded and combo box updated");
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
    
    // ✅ AGGIUNTO: Verifica che ci siano templates disponibili
    if (self.availableTemplates.count == 0) {
        NSLog(@"⚠️ IndicatorsPanel: No available templates, cannot update combo box selection");
        [self refreshTemplateDisplay];
        [self updateButtonStates];
        return;
    }
    
    // Cerca il template per ID
    for (NSUInteger i = 0; i < self.availableTemplates.count; i++) {
        ChartTemplateModel *tempTemplate = self.availableTemplates[i];
        if ([tempTemplate.templateID isEqualToString:template.templateID]) {
            index = i;
            break;
        }
    }
    
    // ✅ CORREZIONE CRITICA: Solo seleziona se l'indice è valido E l'array non è vuoto
    if (index != NSNotFound &&
        index >= 0 &&
        index < (NSInteger)self.availableTemplates.count &&
        self.availableTemplates.count > 0) {
        
        [self.templateComboBox selectItemAtIndex:index];
        
    } else {
   
        
        // ✅ SAFE FALLBACK: Non selezionare niente invece di crashare
        [self.templateComboBox selectItemAtIndex:-1];  // Clear selection safely
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

#pragma mark - NSOutlineView DataSource - AGGIORNATO per runtime models

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (!self.currentTemplate) {
        NSLog(@"⚠️ IndicatorsPanel: No current template, returning 0 children");
        return 0;
    }
    
    if (item == nil) {
        // Root level: panels + "Add Panel" row
        NSInteger count = self.currentTemplate.panels.count + 1;
        NSLog(@"🔢 IndicatorsPanel: Root level children count: %ld", (long)count);
        return count;
    }
    
    // ✅ AGGIORNATO: Usa ChartPanelTemplateModel invece di ChartPanelTemplate
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        // Per ora semplificato: solo il root indicator (i child indicators saranno implementati dopo)
        // Panel level: root indicator + "Add Indicator" row
        NSInteger childCount = 1;  // Root indicator sempre presente per il template
        childCount += 1; // "Add Indicator..." row
        NSLog(@"🔢 IndicatorsPanel: Panel '%@' children count: %ld", panel.displayName, (long)childCount);
        return childCount;
    }
    
    // TODO: Implementare quando avremo TechnicalIndicatorBase nelle runtime models
    if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        // Indicator level: children + "Add Child" row (if supported)
        NSInteger childCount = indicator.childIndicators.count + ([indicator canHaveChildren] ? 1 : 0);
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
        // Root level
        if (index < self.currentTemplate.panels.count) {
            NSArray<ChartPanelTemplateModel *> *orderedPanels = [self.currentTemplate orderedPanels];
            ChartPanelTemplateModel *panel = orderedPanels[index];
            NSLog(@"📋 IndicatorsPanel: Root child %ld: Panel '%@'", (long)index, panel.displayName);
            return panel;
        } else {
            NSLog(@"📋 IndicatorsPanel: Root child %ld: Add Panel item", (long)index);
            return kAddPanelItem; // "Add Panel..." row
        }
    }
    
    // ✅ AGGIORNATO: Usa ChartPanelTemplateModel
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        if (index == 0) {
            // Per ora restituiamo una stringa che rappresenta il root indicator
            // TODO: Quando avremo TechnicalIndicatorBase nei runtime models, restituire l'indicator vero
            NSString *rootIndicatorDescription = [NSString stringWithFormat:@"Root: %@", panel.rootIndicatorType];
            NSLog(@"📋 IndicatorsPanel: Panel '%@' child %ld: %@", panel.displayName, (long)index, rootIndicatorDescription);
            return rootIndicatorDescription;
        } else {
            NSLog(@"📋 IndicatorsPanel: Panel '%@' child %ld: Add Indicator item", panel.displayName, (long)index);
            return kAddIndicatorItem; // "Add Indicator..." row
        }
    }
    
    // TODO: Implementare quando avremo TechnicalIndicatorBase
    if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        if (index < indicator.childIndicators.count) {
            TechnicalIndicatorBase *child = indicator.childIndicators[index];
            NSLog(@"📋 IndicatorsPanel: Indicator '%@' child %ld: '%@'", indicator.shortName, (long)index, child.shortName);
            return child;
        } else {
            NSLog(@"📋 IndicatorsPanel: Indicator '%@' child %ld: Add Child item", indicator.shortName, (long)index);
            return kAddChildItem; // "Add Child..." row
        }
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
    
    // ✅ AGGIORNATO: Configure cell content per runtime models
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        NSString *panelTypeName = [self displayNameForPanelType:panel.rootIndicatorType];
        cellView.textField.stringValue = [NSString stringWithFormat:@"📊 %@ Panel (%.0f%%)",
                                         panelTypeName, panel.relativeHeight * 100];
        cellView.textField.textColor = [NSColor labelColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for panel: %@", cellView.textField.stringValue);
        
    } else if ([item isKindOfClass:[NSString class]] && [item hasPrefix:@"Root:"]) {
        // Temporary root indicator representation
        cellView.textField.stringValue = [NSString stringWithFormat:@"📈 %@", item];
        cellView.textField.textColor = [NSColor labelColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for root indicator: %@", cellView.textField.stringValue);
        
    } else if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        NSString *icon = indicator.isRootIndicator ? @"📈" : @"➖";
        cellView.textField.stringValue = [NSString stringWithFormat:@"%@ %@", icon, indicator.name ?: indicator.shortName];
        cellView.textField.textColor = indicator.isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for indicator: %@", cellView.textField.stringValue);
        
    } else if ([item isEqualToString:kAddPanelItem]) {
        cellView.textField.stringValue = @"➕ Add Panel...";
        cellView.textField.textColor = [NSColor systemBlueColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for Add Panel");
        
    } else if ([item isEqualToString:kAddIndicatorItem]) {
        cellView.textField.stringValue = @"➕ Add Indicator...";
        cellView.textField.textColor = [NSColor systemBlueColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for Add Indicator");
        
    } else if ([item isEqualToString:kAddChildItem]) {
        cellView.textField.stringValue = @"➕ Add Child...";
        cellView.textField.textColor = [NSColor systemBlueColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for Add Child");
        
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
        [NSString stringWithFormat:@"%@ (Default)", template.templateName] : template.templateName;
    
    NSLog(@"📋 IndicatorsPanel: ComboBox item %ld: %@", (long)index, displayName);
    return displayName;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedIndex = self.templateComboBox.indexOfSelectedItem;
    
    NSLog(@"🔄 IndicatorsPanel: ComboBox selection changed to index: %ld", (long)selectedIndex);
    
    // ✅ CORREZIONE: Verifica che l'indice sia valido
    if (selectedIndex >= 0 && selectedIndex < (NSInteger)self.availableTemplates.count) {
        ChartTemplateModel *selectedTemplate = self.availableTemplates[selectedIndex];
        NSLog(@"✅ IndicatorsPanel: Valid selection - template: %@", selectedTemplate.templateName);
        
        [self selectTemplate:selectedTemplate];
        
        // Notify delegate
        if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didSelectTemplate:)]) {
            [self.delegate indicatorsPanel:self didSelectTemplate:selectedTemplate];
        }
    } else {
        NSLog(@"⚠️ IndicatorsPanel: Invalid selection index %ld (available: %ld)",
              (long)selectedIndex, (long)self.availableTemplates.count);
    }
}

#pragma mark - Dynamic Context Menu System - SCALABILE

- (NSMenu *)contextMenuForItem:(id)item {
    NSMenu *menu = [[NSMenu alloc] init];
    
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        // ✅ DINAMICO: Crea submenu per indicatori basato su registry
        NSMenuItem *addIndicatorItem = [[NSMenuItem alloc] initWithTitle:@"Add Indicator"
                                                                  action:nil
                                                           keyEquivalent:@""];
        NSMenu *indicatorSubmenu = [self createIndicatorSubmenuForPanel:panel];
        addIndicatorItem.submenu = indicatorSubmenu;
        [menu addItem:addIndicatorItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItem:[self createRemovePanelMenuItemForPanel:panel]];
        [menu addItem:[self createPanelSettingsMenuItemForPanel:panel]];
        
    } else if ([item isEqualToString:kAddPanelItem]) {
        
        // ✅ DINAMICO: Crea submenu per pannelli basato su indicator types
        NSMenu *panelSubmenu = [self createPanelTypesSubmenu];
        NSMenuItem *addPanelItem = [[NSMenuItem alloc] initWithTitle:@"Add Panel" action:nil keyEquivalent:@""];
        addPanelItem.submenu = panelSubmenu;
        [menu addItem:addPanelItem];
        
    } else if ([item isEqualToString:kAddIndicatorItem] || [item isEqualToString:kAddChildItem]) {
        
        // ✅ DINAMICO: Menu per aggiungere indicatori (stesso del panel)
        NSMenu *indicatorSubmenu = [self createIndicatorSubmenuForContext:item];
        for (NSMenuItem *menuItem in indicatorSubmenu.itemArray) {
            [menu addItem:[menuItem copy]];
        }
        
    } else if ([item isKindOfClass:[NSString class]] && [item hasPrefix:@"Root:"]) {
        // Context menu per root indicator temporaneo
        NSMenuItem *configureItem = [[NSMenuItem alloc] initWithTitle:@"Configure Root Indicator..."
                                                               action:@selector(configureRootIndicator:)
                                                        keyEquivalent:@""];
        configureItem.target = self;
        configureItem.representedObject = item;
        [menu addItem:configureItem];
    }
    
    return menu.itemArray.count > 0 ? menu : nil;
}

#pragma mark - Dynamic Submenu Creation

/// Crea submenu dinamico per indicatori basato su IndicatorRegistry
- (NSMenu *)createIndicatorSubmenuForPanel:(ChartPanelTemplateModel *)panel {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry hardcodedIndicatorIdentifiers];
    
    // ✅ CATEGORIZATION: Raggruppa per categorie
    NSDictionary<NSString *, NSArray<NSString *> *> *categorizedIndicators = [self categorizeIndicators:availableIndicators];
    
    for (NSString *category in [categorizedIndicators.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        // Create category submenu
        NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:category action:nil keyEquivalent:@""];
        NSMenu *categorySubmenu = [[NSMenu alloc] init];
        
        NSArray<NSString *> *indicatorsInCategory = categorizedIndicators[category];
        for (NSString *indicatorID in [indicatorsInCategory sortedArrayUsingSelector:@selector(compare:)]) {
            
            // Get indicator info from registry
            NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
            NSString *displayName = indicatorInfo[@"displayName"] ?: indicatorID;
            
            NSMenuItem *indicatorItem = [[NSMenuItem alloc] initWithTitle:displayName
                                                                   action:@selector(addIndicatorDynamically:)
                                                            keyEquivalent:@""];
            indicatorItem.target = self;
            
            // ✅ DYNAMIC DATA: Store all needed info in representedObject
            NSDictionary *itemData = @{
                @"action": @"addIndicator",
                @"panel": panel ?: [NSNull null],
                @"indicatorID": indicatorID,
                @"indicatorInfo": indicatorInfo
            };
            indicatorItem.representedObject = itemData;
            
            [categorySubmenu addItem:indicatorItem];
        }
        
        categoryItem.submenu = categorySubmenu;
        [submenu addItem:categoryItem];
    }
    
    // ✅ FUTURE: Add "Custom Indicators..." option
    [submenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *customItem = [[NSMenuItem alloc] initWithTitle:@"Custom Indicators..."
                                                        action:@selector(showCustomIndicatorDialog:)
                                                 keyEquivalent:@""];
    customItem.target = self;
    customItem.representedObject = @{@"action": @"showCustomDialog", @"panel": panel ?: [NSNull null]};
    [submenu addItem:customItem];
    
    return submenu;
}

/// Crea submenu dinamico per tipi di pannelli basato su IndicatorRegistry
- (NSMenu *)createPanelTypesSubmenu {
    NSMenu *submenu = [[NSMenu alloc] init];
    
    // ✅ DYNAMIC: Query IndicatorRegistry for available indicators
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry hardcodedIndicatorIdentifiers];
    
    // ✅ FILTER: Solo indicatori che possono essere root indicators per pannelli
    NSArray<NSString *> *panelSuitableIndicators = [self filterIndicatorsForPanelTypes:availableIndicators];
    
    // Create menu items dynamically
    for (NSString *indicatorID in [panelSuitableIndicators sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
        
        // Create display name for panel
        NSString *panelName = [self panelNameForIndicator:indicatorID indicatorInfo:indicatorInfo];
        double defaultHeight = [self defaultHeightForIndicator:indicatorID];
        
        NSMenuItem *panelItem = [[NSMenuItem alloc] initWithTitle:panelName
                                                           action:@selector(addPanelDynamically:)
                                                    keyEquivalent:@""];
        panelItem.target = self;
        
        // ✅ DYNAMIC DATA: Store indicator info for panel creation
        NSDictionary *panelData = @{
            @"name": panelName,
            @"rootIndicator": indicatorID,
            @"defaultHeight": @(defaultHeight),
            @"indicatorInfo": indicatorInfo
        };
        panelItem.representedObject = panelData;
        [submenu addItem:panelItem];
    }
    
    // ✅ FUTURE: Add option for custom panel with indicator selection
    if (submenu.itemArray.count > 0) {
        [submenu addItem:[NSMenuItem separatorItem]];
    }
    
    NSMenuItem *customPanelItem = [[NSMenuItem alloc] initWithTitle:@"Custom Panel..."
                                                             action:@selector(showCustomPanelDialog:)
                                                      keyEquivalent:@""];
    customPanelItem.target = self;
    [submenu addItem:customPanelItem];
    
    return submenu;
}

/// Crea submenu per contesto specifico (Add Indicator vs Add Child)
- (NSMenu *)createIndicatorSubmenuForContext:(NSString *)context {
    // Same as createIndicatorSubmenuForPanel but without panel reference
    return [self createIndicatorSubmenuForPanel:nil];
}

#pragma mark - Helper Menu Items

- (NSMenuItem *)createRemovePanelMenuItemForPanel:(ChartPanelTemplateModel *)panel {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Remove Panel"
                                                  action:@selector(removePanelDynamically:)
                                           keyEquivalent:@""];
    item.target = self;
    item.representedObject = panel;
    return item;
}

- (NSMenuItem *)createPanelSettingsMenuItemForPanel:(ChartPanelTemplateModel *)panel {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Panel Settings..."
                                                  action:@selector(configurePanelSettings:)
                                           keyEquivalent:@""];
    item.target = self;
    item.representedObject = panel;
    return item;
}

#pragma mark - Panel Type Helpers

/// Filtra indicatori adatti per essere root indicators di pannelli
- (NSArray<NSString *> *)filterIndicatorsForPanelTypes:(NSArray<NSString *> *)indicators {
    NSMutableArray<NSString *> *suitable = [NSMutableArray array];
    
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    
    for (NSString *indicatorID in indicators) {
        NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
        
        // ✅ FILTER LOGIC: Determina se l'indicatore è adatto come root di un pannello
        if ([self isIndicatorSuitableForPanel:indicatorID indicatorInfo:indicatorInfo]) {
            [suitable addObject:indicatorID];
        }
    }
    
    return [suitable copy];
}

/// Verifica se un indicatore è adatto come root di un pannello
- (BOOL)isIndicatorSuitableForPanel:(NSString *)indicatorID indicatorInfo:(NSDictionary *)info {
    // ✅ LOGIC: La maggior parte degli indicatori può essere root di un pannello
    // Per ora, accettiamo tutti gli indicatori disponibili
    return YES;
}

/// Genera nome display per pannello basato su indicatore
- (NSString *)panelNameForIndicator:(NSString *)indicatorID indicatorInfo:(NSDictionary *)info {
    // ✅ NAMING LOGIC: Crea nomi user-friendly per i pannelli
    
    // Usa display name se disponibile
    NSString *displayName = info[@"displayName"];
    if (displayName) {
        return [NSString stringWithFormat:@"%@ Panel", displayName];
    }
    
    // Fallback: cleanup del nome ID
    NSString *cleanName = [indicatorID stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
    return [NSString stringWithFormat:@"%@ Panel", cleanName];
}

/// Determina altezza default per pannello basato su tipo indicatore
- (double)defaultHeightForIndicator:(NSString *)indicatorID {
    // ✅ HEIGHT LOGIC: Assegna altezze sensate basate sul tipo di indicatore
    
    if ([indicatorID isEqualToString:@"SecurityIndicator"]) {
        return 0.6;  // Security panel gets most space
    } else if ([indicatorID isEqualToString:@"VolumeIndicator"]) {
        return 0.25; // Volume needs moderate space
    } else if ([[self categoryForIndicator:indicatorID] isEqualToString:@"Oscillators"]) {
        return 0.2;  // Oscillators are typically smaller
    } else if ([[self categoryForIndicator:indicatorID] isEqualToString:@"Moving Averages"]) {
        return 0.15; // Moving averages can be small (often overlaid)
    } else {
        return 0.25; // Default moderate size
    }
}

#pragma mark - Indicator Categorization

/// Categorizza indicatori per tipo (Moving Averages, Oscillators, etc.)
- (NSDictionary<NSString *, NSArray<NSString *> *> *)categorizeIndicators:(NSArray<NSString *> *)indicators {
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *categories = [NSMutableDictionary dictionary];
    
    // ✅ CATEGORIZATION RULES: Define categories based on indicator ID patterns
    for (NSString *indicatorID in indicators) {
        NSString *category = [self categoryForIndicator:indicatorID];
        
        if (!categories[category]) {
            categories[category] = [NSMutableArray array];
        }
        [categories[category] addObject:indicatorID];
    }
    
    // Convert mutable arrays to immutable
    NSMutableDictionary<NSString *, NSArray<NSString *> *> *result = [NSMutableDictionary dictionary];
    for (NSString *key in categories) {
        result[key] = [categories[key] copy];
    }
    
    return [result copy];
}

/// Determina categoria per indicatore
- (NSString *)categoryForIndicator:(NSString *)indicatorID {
    // ✅ PATTERN MATCHING: Categorize based on indicator type
    if ([indicatorID containsString:@"MA"] || [indicatorID isEqualToString:@"EMA"] || [indicatorID isEqualToString:@"SMA"]) {
        return @"Moving Averages";
    } else if ([indicatorID isEqualToString:@"RSI"] || [indicatorID isEqualToString:@"Stochastic"] || [indicatorID containsString:@"CCI"]) {
        return @"Oscillators";
    } else if ([indicatorID isEqualToString:@"MACD"] || [indicatorID containsString:@"Signal"]) {
        return @"Trend Indicators";
    } else if ([indicatorID isEqualToString:@"VolumeIndicator"] || [indicatorID containsString:@"Volume"]) {
        return @"Volume";
    } else if ([indicatorID isEqualToString:@"SecurityIndicator"] || [indicatorID containsString:@"Price"]) {
        return @"Price Action";
    } else if ([indicatorID containsString:@"Bollinger"] || [indicatorID containsString:@"Band"]) {
        return @"Bands & Channels";
    } else {
        return @"Other";
    }
}

#pragma mark - Dynamic Action Methods - SCALABILI

/// ✅ UNIVERSAL ACTION: Un solo metodo per aggiungere qualsiasi indicatore
- (void)addIndicatorDynamically:(NSMenuItem *)sender {
    NSDictionary *itemData = sender.representedObject;
    
    NSString *action = itemData[@"action"];
    ChartPanelTemplateModel *panel = [itemData[@"panel"] isEqual:[NSNull null]] ? nil : itemData[@"panel"];
    NSString *indicatorID = itemData[@"indicatorID"];
    NSDictionary *indicatorInfo = itemData[@"indicatorInfo"];
    
    NSLog(@"✅ IndicatorsPanel: Adding indicator '%@' to panel '%@'",
          indicatorID, panel.displayName ?: @"(none)");
    
    // TODO: Implementare l'aggiunta effettiva dell'indicatore
    // Per ora solo log
}

/// ✅ UNIVERSAL ACTION: Un solo metodo per aggiungere qualsiasi pannello
- (void)addPanelDynamically:(NSMenuItem *)sender {
    NSDictionary *panelData = sender.representedObject;
    
    NSString *panelName = panelData[@"name"];
    NSString *rootIndicator = panelData[@"rootIndicator"];
    double defaultHeight = [panelData[@"defaultHeight"] doubleValue];
    
    NSLog(@"✅ IndicatorsPanel: Adding panel '%@' with root indicator '%@'",
          panelName, rootIndicator);
    
    if (self.currentTemplate) {
        ChartPanelTemplateModel *newPanel = [ChartPanelTemplateModel panelWithID:nil
                                                                            name:[panelName stringByReplacingOccurrencesOfString:@" Panel" withString:@""]
                                                                 rootIndicatorType:rootIndicator
                                                                          height:defaultHeight
                                                                           order:self.currentTemplate.panels.count];
        
        [self.currentTemplate addPanel:newPanel];
        [self refreshTemplateDisplay];
        [self updateButtonStates];
    }
}

/// ✅ UNIVERSAL ACTION: Un solo metodo per rimuovere pannelli
- (void)removePanelDynamically:(NSMenuItem *)sender {
    ChartPanelTemplateModel *panel = sender.representedObject;
    
    NSLog(@"🗑️ IndicatorsPanel: Remove panel: %@", panel.displayName);
    
    if (self.currentTemplate && panel) {
        [self.currentTemplate removePanel:panel];
        [self refreshTemplateDisplay];
        [self updateButtonStates];
    }
}

#pragma mark - Button Actions & Helper Methods

- (void)updateButtonStates {
    BOOL hasTemplate = (self.currentTemplate != nil);
    BOOL hasChanges = [self hasUnsavedChanges];
    
    self.applyButton.enabled = hasTemplate && hasChanges;
    self.resetButton.enabled = hasTemplate && hasChanges;
    self.saveAsButton.enabled = hasTemplate;
}



#pragma mark - NSOutlineView DataSource - AGGIORNATO per runtime models


- (NSString *)displayNameForPanelType:(NSString *)panelType {
    // Map root indicator types to display names
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
    return displayName ?: [panelType stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
}

#pragma mark - Action Methods - AGGIORNATI per runtime models

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
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = [NSString stringWithFormat:@"%@ Copy", self.currentTemplate.templateName];
    alert.accessoryView = input;
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSString *templateName = input.stringValue.length > 0 ? input.stringValue : @"Untitled Template";
            
            if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestCreateTemplate:)]) {
                [self.delegate indicatorsPanel:self didRequestCreateTemplate:templateName];
            }
        }
    }];
}

#pragma mark - Template Management Actions

- (void)renameTemplate:(NSMenuItem *)sender {
    if (!self.currentTemplate) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Template";
    alert.informativeText = @"Enter a new name for the template:";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = self.currentTemplate.templateName;
    alert.accessoryView = input;
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
            self.currentTemplate.templateName = input.stringValue;
            self.currentTemplate.modifiedDate = [NSDate date];
            [self updateButtonStates];
            [self.templateComboBox reloadData];
        }
    }];
}

- (void)duplicateTemplate:(NSMenuItem *)sender {
    if (!self.currentTemplate) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Duplicate Template";
    alert.informativeText = @"Enter a name for the duplicate template:";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Duplicate"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = [NSString stringWithFormat:@"%@ Copy", self.currentTemplate.templateName];
    alert.accessoryView = input;
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
            // Create duplicate template
            ChartTemplateModel *duplicate = [self.currentTemplate createWorkingCopy];
            duplicate.templateID = [[NSUUID UUID] UUIDString];
            duplicate.templateName = input.stringValue;
            duplicate.isDefault = NO;
            duplicate.createdDate = [NSDate date];
            duplicate.modifiedDate = [NSDate date];
            
            // Assign new IDs to all panels
            for (ChartPanelTemplateModel *panel in duplicate.panels) {
                panel.panelID = [[NSUUID UUID] UUIDString];
            }
            
            if ([self.delegate respondsToSelector:@selector(indicatorsPanel:didRequestCreateTemplate:)]) {
                [self.delegate indicatorsPanel:self didRequestCreateTemplate:duplicate.templateName];
            }
        }
    }];
}

- (void)exportTemplate:(NSMenuItem *)sender {
    if (!self.currentTemplate) return;
    
    NSLog(@"📤 IndicatorsPanel: Export template: %@", self.currentTemplate.templateName);
    // TODO: Implement template export functionality
}

- (void)deleteTemplate:(NSMenuItem *)sender {
    if (!self.currentTemplate) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Template";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the template '%@'?", self.currentTemplate.templateName];
    alert.alertStyle = NSAlertStyleCritical;
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSLog(@"🗑️ IndicatorsPanel: Delete template: %@", self.currentTemplate.templateName);
            // TODO: Implement template deletion via delegate
        }
    }];
}

#pragma mark - Placeholder Action Methods - Future Implementation

- (void)configurePanelSettings:(NSMenuItem *)sender {
    ChartPanelTemplateModel *panel = sender.representedObject;
    NSLog(@"⚙️ IndicatorsPanel: Configure panel settings: %@", panel.displayName);
    
    // TODO: Implementare panel settings dialog
    // - Panel height adjustment
    // - Panel name change
    // - Root indicator change/configuration
}

- (void)configureRootIndicator:(NSMenuItem *)sender {
    NSString *rootIndicatorDescription = sender.representedObject;
    NSLog(@"⚙️ IndicatorsPanel: Configure root indicator: %@", rootIndicatorDescription);
    
    // TODO: Implementare root indicator configuration
}

- (void)showCustomIndicatorDialog:(NSMenuItem *)sender {
    NSDictionary *itemData = sender.representedObject;
    ChartPanelTemplateModel *panel = [itemData[@"panel"] isEqual:[NSNull null]] ? nil : itemData[@"panel"];
    
    NSLog(@"🔧 IndicatorsPanel: Show custom indicator dialog for panel: %@", panel.displayName ?: @"(none)");
    
    // TODO: Implementare custom indicator dialog
    // - PineScript editor
    // - Import from file
    // - Indicator library browser
}

- (void)showCustomPanelDialog:(NSMenuItem *)sender {
    NSLog(@"🔧 IndicatorsPanel: Show custom panel dialog");
    
    // TODO: Implementare custom panel dialog
    // - Panel type selection
    // - Custom indicator selection
    // - Panel configuration
}

#pragma mark - Right-Click Support - AGGIORNATO per runtime models

// ✅ AGGIORNATO: Override per gestire right-click sull'outline view
- (void)rightMouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSPoint outlinePoint = [self.templateOutlineView convertPoint:point fromView:self];
    NSInteger row = [self.templateOutlineView rowAtPoint:outlinePoint];
    
    NSLog(@"🖱️ IndicatorsPanel: Right-click at row %ld", (long)row);
    
    if (row >= 0) {
        // Select the row first
        [self.templateOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        
        // Get the item and show context menu
        id item = [self.templateOutlineView itemAtRow:row];
        NSMenu *contextMenu = [self contextMenuForItem:item];
        
        if (contextMenu) {
            [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self.templateOutlineView];
        }
    } else {
        [super rightMouseDown:event];
    }
}

#pragma mark - Window Management

- (NSWindow *)window {
    // La classe NSView ha già una proprietà window - usala direttamente
    return [super window];
}

#pragma mark - Debugging & Logging

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> Template: %@ (%ld panels), Visible: %@",
            NSStringFromClass(self.class), self,
            self.currentTemplate.templateName ?: @"None",
            (long)self.currentTemplate.panels.count,
            self.isVisible ? @"YES" : @"NO"];
}

#pragma mark - Cleanup

- (void)dealloc {
    NSLog(@"♻️ IndicatorsPanel: Deallocating");
    
    // Clear delegates
    self.templateComboBox.dataSource = nil;
    self.templateComboBox.delegate = nil;
    self.templateOutlineView.dataSource = nil;
    self.templateOutlineView.delegate = nil;
}

@end
