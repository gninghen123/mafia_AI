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
    
    
    NSTableColumn *templateColumn = [[NSTableColumn alloc] initWithIdentifier:@"TemplateColumn"];
      templateColumn.title = @"Template Structure";
      templateColumn.width = 250;  // Larghezza adeguata per il panel
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
    
    // Check template name
    if (![self.currentTemplate.templateName isEqualToString:self.originalTemplate.templateName]) {
        return YES;
    }
    
    // Check panel count
    if (self.currentTemplate.panels.count != self.originalTemplate.panels.count) {
        return YES;
    }
    
    // ✅ AGGIUNTO: Check individual panel changes
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
        
        // ✅ IMPORTANTE: Check childIndicatorsData changes
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
        // ✅ PULITO: Solo panels, nessun "+Add Panel" placeholder
        NSInteger count = self.currentTemplate.panels.count;
        NSLog(@"🔢 IndicatorsPanel: Root level children count: %ld", (long)count);
        return count;
    }
    
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        // ✅ MOSTRA CHILD INDICATORS DAI DATI DEL PANEL
        NSInteger childCount = panel.childIndicatorsData.count;
        NSLog(@"🔢 IndicatorsPanel: Panel '%@' children count: %ld", panel.displayName, (long)childCount);
        return childCount;
    }
    
    // TODO: Implementare quando avremo TechnicalIndicatorBase nelle runtime models
    if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        // ✅ PULITO: Solo children reali, nessun "+Add Child" placeholder
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
        // ✅ RIMOSSO: Nessun "Add Panel..." placeholder
        NSLog(@"❌ IndicatorsPanel: Invalid panel index %ld", (long)index);
        return nil;
    }
    
    if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        // ✅ RESTITUISCI CHILD INDICATORS DAI DATI
        if (index < panel.childIndicatorsData.count) {
            NSDictionary *childIndicatorData = panel.childIndicatorsData[index];
            NSLog(@"📋 IndicatorsPanel: Panel '%@' child %ld: %@", panel.displayName, (long)index, childIndicatorData[@"indicatorID"]);
            return childIndicatorData; // Restituiamo il dictionary con i dati
        }
        
        NSLog(@"❌ IndicatorsPanel: Invalid indicator index %ld for panel '%@'", (long)index, panel.displayName);
        return nil;
    }
    
    // TODO: Implementare quando avremo TechnicalIndicatorBase
    if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        if (index < indicator.childIndicators.count) {
            TechnicalIndicatorBase *child = indicator.childIndicators[index];
            NSLog(@"📋 IndicatorsPanel: Indicator '%@' child %ld: '%@'", indicator.shortName, (long)index, child.shortName);
            return child;
        }
        // ✅ RIMOSSO: Nessun "Add Child..." placeholder
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
        
    }  else if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
        TechnicalIndicatorBase *indicator = item;
        NSString *icon = indicator.isRootIndicator ? @"📈" : @"➖";
        cellView.textField.stringValue = [NSString stringWithFormat:@"%@ %@", icon, indicator.name ?: indicator.shortName];
        cellView.textField.textColor = indicator.isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for indicator: %@", cellView.textField.stringValue);
        
    }  else if ([item isKindOfClass:[NSDictionary class]]) {
        // ✅ NUOVO: Child indicator data
        NSDictionary *indicatorData = item;
        NSString *indicatorID = indicatorData[@"indicatorID"];
        BOOL isVisible = [indicatorData[@"isVisible"] boolValue];
        
        NSString *displayName = [self displayNameForIndicator:indicatorID indicatorInfo:nil];
        cellView.textField.stringValue = [NSString stringWithFormat:@"📈 %@", displayName];
        cellView.textField.textColor = isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        NSLog(@"🎨 IndicatorsPanel: Configured cell for child indicator: %@", displayName);
    } else {
        // ✅ RIMOSSO: Tutti i casi kAddPanelItem, kAddIndicatorItem, kAddChildItem
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
    
    if (item == nil) {
        // ✅ ROOT LEVEL: Add Panel
        NSMenuItem *addPanelItem = [[NSMenuItem alloc] initWithTitle:@"Add Panel" action:nil keyEquivalent:@""];
        NSMenu *panelSubmenu = [self createPanelTypesSubmenu];
        addPanelItem.submenu = panelSubmenu;
        [menu addItem:addPanelItem];
    } else if ([item isKindOfClass:[ChartPanelTemplateModel class]]) {
        ChartPanelTemplateModel *panel = item;
        
        // ✅ PANEL CONTEXT: Add Indicator, Configure, Remove
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
        
    }  else if ([item isKindOfClass:[TechnicalIndicatorBase class]]) {
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

- (void)addPanelFromMenu:(NSMenuItem *)sender {
    NSDictionary *data = sender.representedObject;
    NSString *indicatorID = data[@"indicatorID"];
    NSString *panelName = data[@"panelName"];
    double defaultHeight = [data[@"defaultHeight"] doubleValue];
    
    [self addPanelWithType:panelName rootIndicator:indicatorID defaultHeight:defaultHeight];
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



/// Verifica se un indicatore è adatto come root di un pannello
- (BOOL)isIndicatorSuitableForPanel:(NSString *)indicatorID indicatorInfo:(NSDictionary *)info {
    // ✅ LOGIC: La maggior parte degli indicatori può essere root di un pannello
    // Per ora, accettiamo tutti gli indicatori disponibili
    return YES;
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



- (void)showCustomIndicatorDialog:(NSMenuItem *)sender {
    NSDictionary *itemData = sender.representedObject;
    ChartPanelTemplateModel *panel = [itemData[@"panel"] isEqual:[NSNull null]] ? nil : itemData[@"panel"];
    
    NSLog(@"🔧 IndicatorsPanel: Show custom indicator dialog for panel: %@", panel.displayName ?: @"(none)");
    
    // TODO: Implementare custom indicator dialog
    // - PineScript editor
    // - Import from file
    // - Indicator library browser
}

- (void)showAddPanelDialog:(NSMenuItem *)sender {
    NSLog(@"🎯 IndicatorsPanel: Show Add Panel Dialog");
    
    // ✅ DYNAMIC: Usa IndicatorRegistry per ottenere indicatori disponibili
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry hardcodedIndicatorIdentifiers];
    NSArray<NSString *> *panelSuitableIndicators = [self filterIndicatorsForPanelTypes:availableIndicators];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Panel";
    alert.informativeText = @"Select the type of panel to add:";
    alert.alertStyle = NSAlertStyleInformational;
    
    // ✅ DYNAMIC: Aggiungi button per ogni indicatore disponibile
    NSMutableArray<NSDictionary *> *panelOptions = [NSMutableArray array];
    
    for (NSString *indicatorID in [panelSuitableIndicators sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
        NSString *panelName = [self panelNameForIndicator:indicatorID indicatorInfo:indicatorInfo];
        double defaultHeight = [self defaultHeightForIndicator:indicatorID];
        
        [alert addButtonWithTitle:panelName];
        [panelOptions addObject:@{
            @"indicatorID": indicatorID,
            @"panelName": panelName,
            @"defaultHeight": @(defaultHeight)
        }];
    }
    
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        // ✅ DYNAMIC: Map button index to panel option
        NSInteger optionIndex = returnCode - NSAlertFirstButtonReturn;
        
        if (optionIndex >= 0 && optionIndex < panelOptions.count) {
            NSDictionary *selectedOption = panelOptions[optionIndex];
            NSString *indicatorID = selectedOption[@"indicatorID"];
            NSString *panelName = selectedOption[@"panelName"];
            double defaultHeight = [selectedOption[@"defaultHeight"] doubleValue];
            
            [self addPanelWithType:panelName rootIndicator:indicatorID defaultHeight:defaultHeight];
        }
        // Else: Cancel button pressed
    }];
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
#pragma mark - Context Menu Actions - DA IMPLEMENTARE


- (void)showAddIndicatorDialog:(NSMenuItem *)sender {
    ChartPanelTemplateModel *panel = sender.representedObject;
    NSLog(@"🎯 IndicatorsPanel: Show Add Indicator Menu for panel: %@", panel.displayName);
    
    // ✅ SOSTITUIRE: Crea menu gerarchico invece di dialog
    NSMenu *indicatorMenu = [self createHierarchicalIndicatorMenuForPanel:panel];
    
    // Mostra menu al punto del click
    NSEvent *currentEvent = [NSApp currentEvent];
    [NSMenu popUpContextMenu:indicatorMenu withEvent:currentEvent forView:self.templateOutlineView];
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

- (NSDictionary<NSString *, NSArray<NSString *> *> *)categorizeIndicatorsForMenu:(NSArray<NSString *> *)indicators {
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *categories = [NSMutableDictionary dictionary];
    
    // ✅ DEFINISCI CATEGORIE
    categories[@"Moving Averages"] = [NSMutableArray array];
    categories[@"Oscillators"] = [NSMutableArray array];
    categories[@"Volume"] = [NSMutableArray array];
    categories[@"Volatility"] = [NSMutableArray array];
    categories[@"Price Action"] = [NSMutableArray array];
    categories[@"Other"] = [NSMutableArray array];
    
    for (NSString *indicatorID in indicators) {
        // ✅ LOGIC: Categorizza per nome
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
    
    // ✅ REMOVE EMPTY CATEGORIES
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *categoryName in categories.allKeys) {
        if (categories[categoryName].count > 0) {
            result[categoryName] = [categories[categoryName] copy];
        }
    }
    
    return [result copy];
}

- (void)showAddChildIndicatorDialog:(NSMenuItem *)sender {
    TechnicalIndicatorBase *parentIndicator = sender.representedObject;
    NSLog(@"🎯 IndicatorsPanel: Show Add Child Indicator Dialog for parent: %@", parentIndicator.shortName);
    
    // ✅ DYNAMIC: Usa IndicatorRegistry per child indicators
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry hardcodedIndicatorIdentifiers];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Child Indicator";
    alert.informativeText = [NSString stringWithFormat:@"Add child indicator to %@:", parentIndicator.shortName];
    alert.alertStyle = NSAlertStyleInformational;
    
    // ✅ DYNAMIC: Solo indicatori che possono essere children
    NSMutableArray<NSDictionary *> *childOptions = [NSMutableArray array];
    
    for (NSString *indicatorID in [availableIndicators sortedArrayUsingSelector:@selector(compare:)]) {
        // Filter: most indicators can be children, but exclude some like SecurityIndicator
        if (![indicatorID isEqualToString:@"SecurityIndicator"]) {
            NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
            NSString *displayName = [self displayNameForIndicator:indicatorID indicatorInfo:indicatorInfo];
            
            [alert addButtonWithTitle:[NSString stringWithFormat:@"%@ on %@", displayName, parentIndicator.shortName]];
            [childOptions addObject:@{
                @"indicatorID": indicatorID,
                @"displayName": displayName
            }];
        }
    }
    
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        NSInteger optionIndex = returnCode - NSAlertFirstButtonReturn;
        
        if (optionIndex >= 0 && optionIndex < childOptions.count) {
            NSDictionary *selectedOption = childOptions[optionIndex];
            NSString *childType = selectedOption[@"indicatorID"];
            
            NSLog(@"✅ Adding %@ as child of %@", childType, parentIndicator.shortName);
            // TODO: Implementare aggiunta child indicator
            [self refreshTemplateDisplay];
        }
    }];
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

- (void)configurePanelSettings:(NSMenuItem *)sender {
    ChartPanelTemplateModel *panel = sender.representedObject;
    NSLog(@"⚙️ IndicatorsPanel: Configure Panel Settings: %@", panel.displayName);
    
    [self showPanelConfigurationDialog:panel];
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


- (void)addIndicatorToPanel:(NSMenuItem *)sender {
    NSDictionary *data = sender.representedObject;
    ChartPanelTemplateModel *panel = data[@"panel"];
    NSString *indicatorID = data[@"indicatorID"];
    NSDictionary *indicatorInfo = data[@"indicatorInfo"];
    
    NSLog(@"✅ Adding %@ indicator to panel: %@", indicatorID, panel.displayName);
    
    // ✅ TODO: IMPLEMENTARE L'AGGIUNTA REALE
    // Per ora aggiungiamo ai childIndicatorsData del panel
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
    
    NSLog(@"✅ Indicator added to panel data. Panel now has %ld child indicators", (long)childIndicators.count);
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

- (void)addPanelWithType:(NSString *)panelType rootIndicator:(NSString *)rootIndicator defaultHeight:(double)defaultHeight {
    if (!self.currentTemplate) {
        NSLog(@"❌ Cannot add panel - no current template");
        return;
    }
    
    NSLog(@"➕ Adding %@ panel with root indicator %@", panelType, rootIndicator);
    
    // ✅ STEP 1: Calcola nuove altezze con redistribuzione
    NSUInteger currentPanelCount = self.currentTemplate.panels.count;
    NSUInteger newPanelCount = currentPanelCount + 1;
    
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
                                                                       order:currentPanelCount];
    
    // ✅ STEP 4: Aggiungi al template
    [self.currentTemplate addPanel:newPanel];
    
    // ✅ STEP 5: Normalizza le altezze per sicurezza
    [self.currentTemplate normalizeHeights];
    
    // ✅ STEP 6: Aggiorna UI
    [self refreshTemplateDisplay];
    [self updateButtonStates];
    
    NSLog(@"✅ Panel added successfully. Total height: %.3f", [self.currentTemplate totalHeight]);
    [self logPanelHeights];
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
    [self logPanelHeights];
}


- (void)showPanelConfigurationDialog:(ChartPanelTemplateModel *)panel {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Panel Configuration";
    alert.informativeText = [NSString stringWithFormat:@"Configure %@ Panel", panel.displayName];
    alert.alertStyle = NSAlertStyleInformational;
    
    // ✅ ACCESSORY VIEW: Crea form per configurazione
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 120)];
    
    // Panel Name
    NSTextField *nameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 90, 80, 20)];
    nameLabel.stringValue = @"Panel Name:";
    nameLabel.editable = NO;
    nameLabel.bordered = NO;
    nameLabel.backgroundColor = [NSColor clearColor];
    [accessoryView addSubview:nameLabel];
    
    NSTextField *nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 90, 180, 20)];
    nameField.stringValue = panel.panelName ?: panel.displayName;
    nameField.tag = 1001; // Per ritrovarlo dopo
    [accessoryView addSubview:nameField];
    
    // Panel Height
    NSTextField *heightLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 60, 80, 20)];
    heightLabel.stringValue = @"Height (%):";
    heightLabel.editable = NO;
    heightLabel.bordered = NO;
    heightLabel.backgroundColor = [NSColor clearColor];
    [accessoryView addSubview:heightLabel];
    
    NSTextField *heightField = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 60, 80, 20)];
    heightField.stringValue = [NSString stringWithFormat:@"%.0f", panel.relativeHeight * 100];
    heightField.tag = 1002; // Per ritrovarlo dopo
    [accessoryView addSubview:heightField];
    
    // Root Indicator Type
    NSTextField *indicatorLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 30, 80, 20)];
    indicatorLabel.stringValue = @"Root Indicator:";
    indicatorLabel.editable = NO;
    indicatorLabel.bordered = NO;
    indicatorLabel.backgroundColor = [NSColor clearColor];
    [accessoryView addSubview:indicatorLabel];
    
    // ✅ DYNAMIC: Popola popup con indicatori da registry
    NSPopUpButton *indicatorPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(100, 30, 180, 20)];
    
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    NSArray<NSString *> *availableIndicators = [registry hardcodedIndicatorIdentifiers];
    NSArray<NSString *> *panelSuitableIndicators = [self filterIndicatorsForPanelTypes:availableIndicators];
    
    // Aggiungi opzioni dinamicamente
    for (NSString *indicatorID in [panelSuitableIndicators sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *indicatorInfo = [registry indicatorInfoForIdentifier:indicatorID];
        NSString *displayName = [self displayNameForIndicator:indicatorID indicatorInfo:indicatorInfo];
        [indicatorPopup addItemWithTitle:displayName];
        indicatorPopup.lastItem.representedObject = indicatorID; // Store the actual ID
    }
    
    // ✅ SELECT CURRENT: Trova e seleziona l'indicatore corrente
    for (NSInteger i = 0; i < indicatorPopup.numberOfItems; i++) {
        NSMenuItem *item = [indicatorPopup itemAtIndex:i];
        if ([item.representedObject isEqualToString:panel.rootIndicatorType]) {
            [indicatorPopup selectItemAtIndex:i];
            break;
        }
    }
    
    indicatorPopup.tag = 1003; // Per ritrovarlo dopo
    [accessoryView addSubview:indicatorPopup];
    
    alert.accessoryView = accessoryView;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self applyPanelConfiguration:panel fromAccessoryView:accessoryView];
        }
    }];
}

- (void)applyPanelConfiguration:(ChartPanelTemplateModel *)panel fromAccessoryView:(NSView *)accessoryView {
    // ✅ RECUPERA VALORI dal form
    NSTextField *nameField = [accessoryView viewWithTag:1001];
    NSTextField *heightField = [accessoryView viewWithTag:1002];
    NSPopUpButton *indicatorPopup = [accessoryView viewWithTag:1003];
    
    NSString *newName = nameField.stringValue;
    double newHeightPercent = [heightField.stringValue doubleValue];
    NSString *newRootIndicator = indicatorPopup.selectedItem.representedObject; // Get the actual ID
    
    // ✅ VALIDAZIONE
    if (newHeightPercent < 5 || newHeightPercent > 95) {
        NSAlert *errorAlert = [[NSAlert alloc] init];
        errorAlert.messageText = @"Invalid Height";
        errorAlert.informativeText = @"Panel height must be between 5% and 95%";
        errorAlert.alertStyle = NSAlertStyleWarning;
        [errorAlert runModal];
        return;
    }
    
    NSLog(@"💾 Applying panel configuration: %@ -> Name: %@, Height: %.0f%%, Root: %@",
          panel.displayName, newName, newHeightPercent, newRootIndicator);
    
    // ✅ APPLICA MODIFICHE
    panel.panelName = newName.length > 0 ? newName : nil;
    panel.rootIndicatorType = newRootIndicator;
    
    // ✅ GESTIONE CAMBIO ALTEZZA con redistribuzione
    double newHeight = newHeightPercent / 100.0;
    double heightDifference = newHeight - panel.relativeHeight;
    
    if (fabs(heightDifference) > 0.01) { // Solo se cambio significativo
        panel.relativeHeight = newHeight;
        
        // Redistribuisci la differenza sugli altri pannelli
        NSArray<ChartPanelTemplateModel *> *otherPanels = [self.currentTemplate.panels filteredArrayUsingPredicate:
                                                           [NSPredicate predicateWithFormat:@"panelID != %@", panel.panelID]];
        
        if (otherPanels.count > 0) {
            double redistributeAmount = -heightDifference / otherPanels.count;
            for (ChartPanelTemplateModel *otherPanel in otherPanels) {
                otherPanel.relativeHeight += redistributeAmount;
                otherPanel.relativeHeight = MAX(0.05, otherPanel.relativeHeight); // Minimo 5%
            }
        }
        
        // Normalizza per sicurezza
        [self.currentTemplate normalizeHeights];
    }
    
    // ✅ AGGIORNA UI
    [self refreshTemplateDisplay];
    [self updateButtonStates];
    
    NSLog(@"✅ Panel configuration applied successfully. Total height: %.3f", [self.currentTemplate totalHeight]);
    [self logPanelHeights];
}

#pragma mark - Utility Methods

- (void)logPanelHeights {
    NSLog(@"📊 Current panel heights:");
    for (ChartPanelTemplateModel *panel in [self.currentTemplate orderedPanels]) {
        NSLog(@"   - %@: %.1f%%", panel.displayName, panel.relativeHeight * 100);
    }
    NSLog(@"   Total: %.3f", [self.currentTemplate totalHeight]);
}


#pragma mark - Dynamic Registry Helper Methods

/// Filtra indicatori adatti per essere root indicators di pannelli
- (NSArray<NSString *> *)filterIndicatorsForPanelTypes:(NSArray<NSString *> *)indicators {
    NSMutableArray<NSString *> *suitable = [NSMutableArray array];
    
    // ✅ FILTER LOGIC: La maggior parte degli indicatori può essere root di un pannello
    // Escludiamo solo alcuni che non hanno senso come panel root
    NSSet<NSString *> *excludedIndicators = [NSSet setWithArray:@[
        // Aggiungi qui indicatori che NON dovrebbero essere root di panel
        // Es: @"UtilityIndicator", @"HelperIndicator"
    ]];
    
    for (NSString *indicatorID in indicators) {
        if (![excludedIndicators containsObject:indicatorID]) {
            [suitable addObject:indicatorID];
        }
    }
    
    return [suitable copy];
}

/// Genera nome display per pannello basato su indicatore
- (NSString *)panelNameForIndicator:(NSString *)indicatorID indicatorInfo:(NSDictionary *)indicatorInfo {
    // Convert indicatorID to user-friendly panel name
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
    
    // Fallback: Generate from indicatorID
    NSString *cleanName = [indicatorID stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
    return [NSString stringWithFormat:@"%@ Panel", cleanName];
}

/// Altezza default per tipo di indicatore
- (double)defaultHeightForIndicator:(NSString *)indicatorID {
    // Panel heights based on common usage
    static NSDictionary *defaultHeights = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultHeights = @{
            @"SecurityIndicator": @0.6,  // 60% for main chart
            @"VolumeIndicator": @0.2,    // 20% for volume
            @"RSI": @0.15,               // 15% for oscillators
            @"SMA": @0.0,                // 0% - should be overlay on existing panel
            @"EMA": @0.0,                // 0% - should be overlay on existing panel
            @"ATR": @0.15,               // 15% for volatility indicators
            @"BB": @0.0                  // 0% - should be overlay on existing panel
        };
    });
    
    NSNumber *height = defaultHeights[indicatorID];
    return height ? [height doubleValue] : 0.2; // Default 20%
}

/// Display name per indicatore
- (NSString *)displayNameForIndicator:(NSString *)indicatorID indicatorInfo:(NSDictionary *)indicatorInfo {
    // Try to get display name from indicator info
    NSString *displayName = indicatorInfo[@"displayName"];
    if (displayName && displayName.length > 0) {
        return displayName;
    }
    
    // Fallback: Pretty format the indicatorID
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
    return prettyName ?: indicatorID; // Ultimate fallback
}


@end
