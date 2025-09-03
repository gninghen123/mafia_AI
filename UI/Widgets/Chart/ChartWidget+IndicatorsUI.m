//
// ChartWidget+IndicatorsUI.m
// TradingApp
//
// ChartWidget extension implementation for indicators panel UI integration
//

#import "ChartWidget+IndicatorsUI.h"
#import "DataHub+ChartTemplates.h"
#import "ChartPanelView.h"
#import <objc/runtime.h>

#pragma mark - Associated Object Keys

static const void *kIndicatorsPanelToggleKey = &kIndicatorsPanelToggleKey;
static const void *kIndicatorsPanelKey = &kIndicatorsPanelKey;
static const void *kIsIndicatorsPanelVisibleKey = &kIsIndicatorsPanelVisibleKey;
static const void *kSplitViewTrailingConstraintKey = &kSplitViewTrailingConstraintKey;
static const void *kCurrentChartTemplateKey = &kCurrentChartTemplateKey;
static const void *kAvailableTemplatesKey = &kAvailableTemplatesKey;
static const void *kIndicatorRenderersKey = &kIndicatorRenderersKey;

@implementation ChartWidget (IndicatorsUI)

#pragma mark - Associated Objects

- (NSButton *)indicatorsPanelToggle {
    return objc_getAssociatedObject(self, kIndicatorsPanelToggleKey);
}

- (void)setIndicatorsPanelToggle:(NSButton *)toggle {
    objc_setAssociatedObject(self, kIndicatorsPanelToggleKey, toggle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (IndicatorsPanel *)indicatorsPanel {
    return objc_getAssociatedObject(self, kIndicatorsPanelKey);
}

- (void)setIndicatorsPanel:(IndicatorsPanel *)panel {
    objc_setAssociatedObject(self, kIndicatorsPanelKey, panel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isIndicatorsPanelVisible {
    NSNumber *value = objc_getAssociatedObject(self, kIsIndicatorsPanelVisibleKey);
    return value ? [value boolValue] : NO;
}

- (void)setIsIndicatorsPanelVisible:(BOOL)visible {
    objc_setAssociatedObject(self, kIsIndicatorsPanelVisibleKey, @(visible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSLayoutConstraint *)splitViewTrailingConstraint {
    return objc_getAssociatedObject(self, kSplitViewTrailingConstraintKey);
}

- (void)setSplitViewTrailingConstraint:(NSLayoutConstraint *)constraint {
    objc_setAssociatedObject(self, kSplitViewTrailingConstraintKey, constraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ChartTemplate *)currentChartTemplate {
    return objc_getAssociatedObject(self, kCurrentChartTemplateKey);
}

- (void)setCurrentChartTemplate:(ChartTemplate *)template {
    objc_setAssociatedObject(self, kCurrentChartTemplateKey, template, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray<ChartTemplate *> *)availableTemplates {
    NSMutableArray *templates = objc_getAssociatedObject(self, kAvailableTemplatesKey);
    if (!templates) {
        templates = [[NSMutableArray alloc] init];
        objc_setAssociatedObject(self, kAvailableTemplatesKey, templates, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return templates;
}

- (void)setAvailableTemplates:(NSMutableArray<ChartTemplate *> *)templates {
    objc_setAssociatedObject(self, kAvailableTemplatesKey, templates, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString *, ChartIndicatorRenderer *> *)indicatorRenderers {
    NSMutableDictionary *renderers = objc_getAssociatedObject(self, kIndicatorRenderersKey);
    if (!renderers) {
        renderers = [[NSMutableDictionary alloc] init];
        objc_setAssociatedObject(self, kIndicatorRenderersKey, renderers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return renderers;
}

- (void)setIndicatorRenderers:(NSMutableDictionary<NSString *, ChartIndicatorRenderer *> *)renderers {
    objc_setAssociatedObject(self, kIndicatorRenderersKey, renderers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Setup and Initialization

- (void)setupIndicatorsUI {
    NSLog(@"🎨 Setting up indicators UI...");
    
    // ✅ NON creare il toggle button qui - viene creato in setupTopToolbar
    // [self createIndicatorsPanelToggleButton]; ← RIMUOVI questa linea
    
    // Create indicators panel
    self.indicatorsPanel = [[IndicatorsPanel alloc] init];
    self.indicatorsPanel.delegate = self;
    self.indicatorsPanel.panelWidth = 280;
    
    // Add panel to view hierarchy
    [self.view addSubview:self.indicatorsPanel];
    
    // Setup constraints
    [self setupIndicatorsPanelConstraints];
    
    // Load available templates
    [self loadAvailableTemplates];
    
    // Ensure default template exists
    [self ensureDefaultTemplateExists];
    
    NSLog(@"✅ Indicators UI setup completed (button created separately in toolbar)");
}

- (void)createIndicatorsPanelToggleButton {
    self.indicatorsPanelToggle = [[NSButton alloc] init];
    self.indicatorsPanelToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorsPanelToggle.title = @"📊"; // Indicators icon
    self.indicatorsPanelToggle.bezelStyle = NSBezelStyleRegularSquare;
    self.indicatorsPanelToggle.buttonType = NSButtonTypeMomentaryPushIn;
    self.indicatorsPanelToggle.target = self;
    self.indicatorsPanelToggle.action = @selector(toggleIndicatorsPanel:);
    
    // Add to header view (assuming similar to objects panel placement)
    [self.view addSubview:self.indicatorsPanelToggle];
    [self positionIndicatorsPanelToggleButton];
}

- (void)positionIndicatorsPanelToggleButton {
    // Il bottone degli indicatori dovrebbe stare a destra, prima del bottone delle preferenze
    NSButton *preferencesButton = self.preferencesButton;
    
    if (preferencesButton) {
        NSLog(@"🎯 Positioning indicators toggle relative to preferences button...");
        
        // ✅ POSIZIONA a sinistra del bottone preferences
        [NSLayoutConstraint activateConstraints:@[
            [self.indicatorsPanelToggle.trailingAnchor constraintEqualToAnchor:preferencesButton.leadingAnchor constant:-4],
            [self.indicatorsPanelToggle.centerYAnchor constraintEqualToAnchor:preferencesButton.centerYAnchor],
            [self.indicatorsPanelToggle.widthAnchor constraintEqualToConstant:32],
            [self.indicatorsPanelToggle.heightAnchor constraintEqualToConstant:24] // Stessa altezza degli altri
        ]];
        
        NSLog(@"✅ Indicators toggle positioned before preferences button");
        
    } else {
        NSLog(@"⚠️ Preferences button not found, positioning at right edge...");
        
        // Fallback: posiziona in alto a destra
        [NSLayoutConstraint activateConstraints:@[
            [self.indicatorsPanelToggle.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [self.indicatorsPanelToggle.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
            [self.indicatorsPanelToggle.widthAnchor constraintEqualToConstant:32],
            [self.indicatorsPanelToggle.heightAnchor constraintEqualToConstant:24]
        ]];
        
        NSLog(@"⚠️ Indicators toggle positioned at top-right corner");
    }
}

- (void)setupIndicatorsPanelConstraints {
    // Panel positioned on the right side
    [NSLayoutConstraint activateConstraints:@[
        [self.indicatorsPanel.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.indicatorsPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.indicatorsPanel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // Setup trailing constraint for main content area
    // This will be adjusted when panel is shown/hidden
    if (self.panelsSplitView) {
        self.splitViewTrailingConstraint = [self.panelsSplitView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor];
        self.splitViewTrailingConstraint.active = YES;
    }
}

- (void)loadAvailableTemplates {
    [[DataHub shared] loadAllChartTemplates:^(NSArray<ChartTemplate *> *templates, NSError *error) {
        if (error) {
            NSLog(@"❌ Failed to load chart templates: %@", error);
            return;
        }
        
        self.availableTemplates = [templates mutableCopy];
        [self.indicatorsPanel loadAvailableTemplates:templates];
        
        // Load default template if none selected
        if (!self.currentChartTemplate && templates.count > 0) {
            ChartTemplate *defaultTemplate = nil;
            for (ChartTemplate *template in templates) {
                if (template.isDefault) {
                    defaultTemplate = template;
                    break;
                }
            }
            
            if (defaultTemplate) {
                [self applyTemplate:defaultTemplate];
            }
        }
        
        NSLog(@"✅ Loaded %ld chart templates", (long)templates.count);
    }];
}

- (void)ensureDefaultTemplateExists {
    [[DataHub shared] defaultTemplateExists:^(BOOL exists) {
        if (!exists) {
            NSLog(@"🏗️ Creating default chart template...");
            
            [[DataHub shared] getDefaultChartTemplate:^(ChartTemplate *defaultTemplate, NSError *error) {
                if (error) {
                    NSLog(@"❌ Failed to create default template: %@", error);
                } else {
                    NSLog(@"✅ Default template created successfully");
                    [self loadAvailableTemplates]; // Reload templates
                }
            }];
        }
    }];
}

#pragma mark - UI Actions

- (IBAction)toggleIndicatorsPanel:(NSButton *)sender {
    [self.indicatorsPanel toggleVisibilityAnimated:YES];
    [self updateIndicatorsPanelToggleState:self.indicatorsPanel.isVisible];
}


- (void)updateIndicatorsPanel {
    if (!self.indicatorsPanel) {
        NSLog(@"⚠️ Indicators panel not available for update");
        return;
    }
    
    // ✅ Load available templates first usando metodo esistente
    if (self.availableTemplates.count > 0) {
        [self.indicatorsPanel loadAvailableTemplates:self.availableTemplates];
    }
    
    // ✅ Select current template if available usando metodo esistente
    if (self.currentChartTemplate) {
        [self.indicatorsPanel selectTemplate:self.currentChartTemplate];
    }
    
    NSLog(@"🔄 Indicators panel updated with current template: %@",
          self.currentChartTemplate.templateName ?: @"None");
}


- (void)refreshIndicatorsRendering {
    if (self.indicatorRenderers.count == 0) {
        NSLog(@"⚠️ No indicator renderers to refresh");
        return;
    }
    
    NSLog(@"🎨 Refreshing indicators rendering for %ld panels...", (long)self.indicatorRenderers.count);
    
    // ✅ Force refresh all indicator renderers usando solo metodi esistenti
    for (NSString *panelID in self.indicatorRenderers.allKeys) {
        ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelID];
        [renderer invalidateIndicatorLayers]; // ✅ Metodo esistente
        NSLog(@"♻️ Refreshed rendering for panel: %@", panelID);
    }
    
    // ✅ Update all panel views
    for (ChartPanelView *panel in self.chartPanels) {
        [panel setNeedsDisplay:YES];
    }
    
    NSLog(@"✅ Indicators rendering refreshed");
}


#pragma mark - Panel Management

- (ChartPanelView *)createChartPanelFromTemplate:(ChartPanelTemplate *)panelTemplate {
    if (!panelTemplate) {
        NSLog(@"❌ Cannot create panel from nil template");
        return nil;
    }
    
    NSLog(@"🏗️ Creating panel from template: %@ (%@)",
          panelTemplate.panelName ?: @"Unnamed", panelTemplate.rootIndicatorType);
    
    // ✅ STEP 1: Determina il panel type dal root indicator
    NSString *panelType = [self panelTypeForRootIndicator:panelTemplate.rootIndicatorType];
    
    // ✅ STEP 2: Crea il panel view
    ChartPanelView *panelView = [[ChartPanelView alloc] initWithType:panelType];
    panelView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // ✅ STEP 3: Configura le proprietà base
    panelView.chartWidget = self;
    panelView.panelTemplate = panelTemplate;
    
    // ✅ STEP 4: Imposta panelName se disponibile
    if (panelTemplate.panelName) {
        // Nota: ChartPanelView potrebbe non avere una proprietà panelName
        // In tal caso potresti aggiungerla o usare un tag/identifier
        NSLog(@"📝 Panel name: %@", panelTemplate.panelName);
    }
    
    NSLog(@"✅ Panel created: %@ -> %@", panelTemplate.rootIndicatorType, panelType);
    return panelView;
}

- (void)updatePanelsWithTemplate:(ChartTemplate *)template {
    // Clear existing panels
    for (ChartPanelView *panel in self.chartPanels) {
        [panel removeFromSuperview];
    }
    [self.chartPanels removeAllObjects];
    
    // Create panels from template
    NSArray<ChartPanelTemplate *> *orderedPanels = [template orderedPanels];
    for (ChartPanelTemplate *panelTemplate in orderedPanels) {
        ChartPanelView *panelView = [self createChartPanelFromTemplate:panelTemplate];
        [self.chartPanels addObject:panelView];
        [self.panelsSplitView addSubview:panelView];
    }
    
    // Redistribute heights
    [self redistributePanelHeights:template];
    
    // Update data if available
    if (self.currentChartData.count > 0) {
        [self updateIndicatorsWithChartData:self.currentChartData];
    }
}

- (void)redistributePanelHeights:(ChartTemplate *)template {
    NSArray<ChartPanelTemplate *> *orderedPanels = [template orderedPanels];
    
    if (orderedPanels.count != self.chartPanels.count) {
        NSLog(@"⚠️ Panel count mismatch during height redistribution (%ld vs %ld)",
              (long)orderedPanels.count, (long)self.chartPanels.count);
        return;
    }
    
    NSLog(@"📏 Redistributing panel heights...");
    
    // ✅ Imposta le altezze usando NSSplitView divider positions
    if (self.chartPanels.count > 1) {
        // Calcola posizioni cumulative dei divider
        CGFloat totalHeight = NSHeight(self.panelsSplitView.bounds);
        CGFloat currentPosition = 0;
        
        for (NSInteger i = 0; i < orderedPanels.count - 1; i++) { // -1 perché l'ultimo pannello non ha divider
            ChartPanelTemplate *panelTemplate = orderedPanels[i];
            currentPosition += panelTemplate.relativeHeight * totalHeight;
            
            // Imposta posizione del divider
            if (i < [self.panelsSplitView.subviews count] - 1) {
                [self.panelsSplitView setPosition:currentPosition ofDividerAtIndex:i];
                NSLog(@"📏 Divider %ld at position: %.1f (%.1f%%)",
                      (long)i, currentPosition, panelTemplate.relativeHeight * 100);
            }
        }
    }
    
    NSLog(@"✅ Panel heights redistributed");
}


- (void)applyTemplate:(ChartTemplate *)template {
    if (!template) {
        NSLog(@"⚠️ Cannot apply nil template");
        return;
    }
    
    NSError *error;
    if (![self validateTemplate:template error:&error]) {
        [self handleTemplateApplicationError:error template:template];
        return;
    }
    
    NSLog(@"🎨 Applying template: %@ (%ld panels)", template.templateName, template.panels.count);
    
    // ✅ STEP 1: Rimuovi pannelli esistenti dal split view
    [self removeExistingPanelsFromSplitView];
    
    
    // ✅ STEP 3: Crea pannelli dal template (ordinati per displayOrder)
    NSArray<ChartPanelTemplate *> *orderedPanels = [template orderedPanels];
    for (ChartPanelTemplate *panelTemplate in orderedPanels) {
        ChartPanelView *panelView = [self createChartPanelFromTemplate:panelTemplate];
        [self.chartPanels addObject:panelView];
        [self.panelsSplitView addSubview:panelView];
        
        NSLog(@"➕ Created panel: %@ (%.1f%% height)",
              panelTemplate.panelName ?: panelTemplate.rootIndicatorType,
              panelTemplate.relativeHeight * 100);
    }
    
    // ✅ STEP 4: Imposta altezze relative dei pannelli
    [self redistributePanelHeights:template];
    
    // ✅ STEP 5: Setup renderers per i nuovi pannelli
    [self setupRenderersForAllPanels];
    
    // ✅ STEP 6: Aggiorna template corrente
    self.currentChartTemplate = template;
    
    // ✅ STEP 7: Update dati se disponibili
    if (self.currentChartData && self.currentChartData.count > 0) {
        [self updateIndicatorsWithChartData:self.currentChartData];
        [self updateAllPanelsWithCurrentData]; // Refresh display
    }
    
    NSLog(@"✅ Template applied successfully: %@ (%ld panels created)",
          template.templateName, (long)self.chartPanels.count);
    
    // ✅ STEP 8: Notifica l'indicators panel del cambio template
    [self updateIndicatorsPanel];
}

#pragma mark - Supporting Methods

- (NSString *)panelTypeForRootIndicator:(NSString *)rootIndicatorType {
    // ✅ Mapping da root indicator type a panel type
    static NSDictionary *indicatorToPanelMapping = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        indicatorToPanelMapping = @{
            // Security indicators -> security panel
            @"SecurityIndicator": @"security",
            @"CandlestickIndicator": @"security",
            @"OHLCIndicator": @"security",
            @"LineIndicator": @"security",
            
            // Volume indicators -> volume panel
            @"VolumeIndicator": @"volume",
            @"VolumeProfileIndicator": @"volume",
            
            // Oscillators -> oscillator panel
            @"RSIIndicator": @"oscillator",
            @"MACDIndicator": @"oscillator",
            @"StochasticIndicator": @"oscillator",
            @"CCIIndicator": @"oscillator",
            @"WilliamsRIndicator": @"oscillator",
            
            // Custom/others -> custom panel
            @"CustomIndicator": @"custom"
        };
    });
    
    // ✅ Lookup del panel type
    NSString *panelType = indicatorToPanelMapping[rootIndicatorType];
    
    if (!panelType) {
        NSLog(@"⚠️ Unknown root indicator type: %@, defaulting to 'custom'", rootIndicatorType);
        panelType = @"custom";
    }
    
    NSLog(@"🔄 Mapped %@ -> %@", rootIndicatorType, panelType);
    return panelType;
}

- (void)setupIndicatorRendererForPanel:(ChartPanelView *)panelView {
    if (!panelView.panelTemplate) {
        NSLog(@"⚠️ Cannot setup indicator renderer - panel has no template");
        return;
    }
    
    NSString *panelID = panelView.panelTemplate.panelID;
    if (!panelID) {
        NSLog(@"⚠️ Cannot setup indicator renderer - panel template has no ID");
        return;
    }
    
    // ✅ Create renderer if it doesn't exist
    ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelID];
    if (!renderer) {
        renderer = [[ChartIndicatorRenderer alloc] initWithPanelView:panelView];
        self.indicatorRenderers[panelID] = renderer;
        NSLog(@"🎨 Created indicator renderer for panel: %@ (%@)",
              panelID, panelView.panelTemplate.rootIndicatorType);
    } else {
        NSLog(@"♻️ Reusing existing indicator renderer for panel: %@", panelID);
    }
}

- (void)updateAllPanelsWithCurrentData {
    NSLog(@"🔄 Updating all panels with current chart data");
    
    if (!self.currentChartData || self.currentChartData.count == 0) {
        NSLog(@"⚠️ No chart data available for panel update");
        return;
    }
    
    if (self.chartPanels.count == 0) {
        NSLog(@"⚠️ No chart panels available for update");
        return;
    }
    
    // ✅ Update each panel usando il metodo esistente synchronizePanels
    // Questo metodo già esistente in ChartWidget si occupa di aggiornare tutti i pannelli
    [self synchronizePanels];
    
    // ✅ Calculate and update indicators for all panels
    [self calculateAllIndicators];
    
    // ✅ Refresh all indicator renderers
    [self refreshIndicatorsRendering];
    
    NSLog(@"✅ All panels updated with current data (%ld bars)", (long)self.currentChartData.count);
}



- (void)updateIndicatorsWithChartData:(NSArray<HistoricalBarModel *> *)chartData {
    if (!chartData || chartData.count == 0) {
        NSLog(@"⚠️ No chart data available for indicators update");
        return;
    }
    
    NSLog(@"🔄 Updating indicators with %ld data points...", (long)chartData.count);
    
    // ✅ Calculate all indicators with new data
    [self calculateAllIndicators];
    
    // ✅ Update all indicator renderers usando solo metodi esistenti
    for (NSString *panelID in self.indicatorRenderers.allKeys) {
        ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelID];
        [renderer invalidateIndicatorLayers]; // ✅ Metodo esistente
        NSLog(@"📊 Updated indicators for panel: %@", panelID);
    }
    
    NSLog(@"✅ All indicators updated with new data");
}


#pragma mark - Supporting Methods for applyTemplate

- (void)removeExistingPanelsFromSplitView {
    NSLog(@"🧹 Removing %ld existing panels...", (long)self.chartPanels.count);
    
    // Rimuovi i pannelli dal split view
    for (ChartPanelView *panel in self.chartPanels) {
        [panel removeFromSuperview];
    }
    
    // Clear l'array
    [self.chartPanels removeAllObjects];
    
    // Reset renderers dictionary
    [self.indicatorRenderers removeAllObjects];
    
    self.renderersInitialized = NO; // Flag per ri-setup
}

- (void)setupRenderersForAllPanels {
    NSLog(@"🎨 Setting up renderers for all panels");
    
    // Clear existing renderers first
    for (ChartIndicatorRenderer *renderer in self.indicatorRenderers.allValues) {
        [renderer cleanup];
    }
    [self.indicatorRenderers removeAllObjects];
    
    // Create renderers for each panel
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.panelTemplate && panel.panelTemplate.rootIndicatorType) {
            
            NSString *rendererKey = [NSString stringWithFormat:@"%@_%@",
                                   panel.panelTemplate.panelID,
                                   panel.panelTemplate.rootIndicatorType];
            
            // Create indicator renderer for this panel
            ChartIndicatorRenderer *renderer = [[ChartIndicatorRenderer alloc] initWithPanelView:panel];
            if (renderer) {
                self.indicatorRenderers[rendererKey] = renderer;
                NSLog(@"📊 Created renderer for panel: %@ (%@)", panel.panelType, panel.panelTemplate.rootIndicatorType);
            } else {
                NSLog(@"⚠️ Failed to create renderer for panel: %@", panel.panelType);
            }
        }
    }
    
    NSLog(@"✅ Setup completed: %ld renderers created", (long)self.indicatorRenderers.count);
}

#pragma mark - Indicator Management

- (void)addIndicator:(TechnicalIndicatorBase *)indicator
           toPanel:(ChartPanelTemplate *)panelTemplate
      parentIndicator:(TechnicalIndicatorBase *)parentIndicator {
    
    if (!indicator || !panelTemplate) return;
    
    if (parentIndicator) {
        // Add as child indicator
        [parentIndicator addChildIndicator:indicator];
    } else {
        // Add as root level (this shouldn't happen as panels have root indicators)
        NSLog(@"⚠️ Adding indicator without parent - this may not be intended");
    }
    
    // Update serialization
    [panelTemplate serializeRootIndicator:panelTemplate.rootIndicator];
    
    // Refresh display
    [self.indicatorsPanel refreshTemplateDisplay];
    
    // Recalculate indicators
    [self calculateIndicatorsForPanel:panelTemplate];
    
    NSLog(@"➕ Added indicator %@ to panel %@", indicator.displayName, panelTemplate.displayName);
}

- (void)removeIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator || indicator.isRootIndicator) {
        NSLog(@"⚠️ Cannot remove root indicator");
        return;
    }
    
    // Remove from parent
    [indicator removeFromParent];
    
    // Find and update the panel template
    for (ChartPanelTemplate *panelTemplate in self.currentChartTemplate.panels) {
        if (panelTemplate.rootIndicator == indicator.getRootIndicator) {
            [panelTemplate serializeRootIndicator:panelTemplate.rootIndicator];
            [self calculateIndicatorsForPanel:panelTemplate];
            break;
        }
    }
    
    // Refresh display
    [self.indicatorsPanel refreshTemplateDisplay];
    
    NSLog(@"🗑️ Removed indicator: %@", indicator.displayName);
}

- (void)configureIndicator:(TechnicalIndicatorBase *)indicator {
    // Show configuration dialog for indicator
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Configure %@", indicator.displayName];
    alert.informativeText = @"Indicator configuration UI would go here";
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        // Apply configuration changes
        [self calculateAllIndicators];
        [self refreshIndicatorsRendering];
    }
}

- (void)calculateAllIndicators {
    if (!self.currentChartTemplate || !self.currentChartData || self.currentChartData.count == 0) {
        NSLog(@"⚠️ Cannot calculate indicators - missing template or data");
        return;
    }
    
    NSLog(@"🔄 Calculating all indicators for template: %@", self.currentChartTemplate.templateName);
    
    NSArray<ChartPanelTemplate *> *orderedPanels = [self.currentChartTemplate orderedPanels];
    for (ChartPanelTemplate *panelTemplate in orderedPanels) {
        [self calculateIndicatorsForPanel:panelTemplate];
    }
    
    NSLog(@"✅ All indicators calculated (%ld panels)", (long)orderedPanels.count);
}


- (void)calculateIndicatorsForPanel:(ChartPanelTemplate *)panelTemplate {
    if (!panelTemplate) {
        NSLog(@"⚠️ Cannot calculate indicators - panel template is nil");
        return;
    }
    
    if (!self.currentChartData || self.currentChartData.count == 0) {
        NSLog(@"⚠️ Cannot calculate indicators - no chart data available");
        return;
    }
    
    // ✅ Get root indicator from template
    TechnicalIndicatorBase *rootIndicator = panelTemplate.rootIndicator;
    if (!rootIndicator) {
        NSLog(@"⚠️ Panel has no root indicator to calculate");
        return;
    }
    
    NSLog(@"📊 Calculating indicators for panel: %@ (%@)",
          panelTemplate.panelName ?: panelTemplate.panelID,
          panelTemplate.rootIndicatorType);
    
    // ✅ Calculate the entire indicator tree for this panel
    [rootIndicator calculateIndicatorTree:self.currentChartData];
    
    // ✅ Update rendering for this panel
    ChartIndicatorRenderer *renderer = [self getIndicatorRendererForPanel:panelTemplate.panelID];
    if (renderer) {
        [renderer renderIndicatorTree:rootIndicator];
        NSLog(@"🎨 Updated rendering for panel: %@", panelTemplate.panelID);
    } else {
        NSLog(@"⚠️ No renderer found for panel: %@", panelTemplate.panelID);
    }
    
    NSLog(@"✅ Indicators calculated for panel: %@", panelTemplate.panelID);
}

#pragma mark - Template Actions

- (void)saveCurrentTemplateAs:(NSString *)templateName
                   completion:(void(^)(BOOL success, NSError *error))completion {
    
    if (!self.currentChartTemplate) {
        NSError *error = [NSError errorWithDomain:@"ChartWidgetIndicators"
                                             code:7001
                                         userInfo:@{NSLocalizedDescriptionKey: @"No current template to save"}];
        completion(NO, error);
        return;
    }
    
    // Create new template with given name
    ChartTemplate *newTemplate = [self.currentChartTemplate createWorkingCopy];
    newTemplate.templateID = [[NSUUID UUID] UUIDString];
    newTemplate.templateName = templateName;
    newTemplate.isDefault = NO;
    newTemplate.createdDate = [NSDate date];
    newTemplate.modifiedDate = [NSDate date];
    
    [[DataHub shared] saveChartTemplate:newTemplate completion:^(BOOL success, NSError *error) {
        if (success) {
            [self.availableTemplates addObject:newTemplate];
            [self.indicatorsPanel loadAvailableTemplates:self.availableTemplates];
            NSLog(@"✅ Template saved as: %@", templateName);
        } else {
            NSLog(@"❌ Failed to save template: %@", error);
        }
        completion(success, error);
    }];
}


- (void)duplicateTemplate:(ChartTemplate *)template {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Duplicate Template";
    alert.informativeText = @"Enter name for the duplicated template:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    input.stringValue = [NSString stringWithFormat:@"%@ Copy", template.templateName];
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Duplicate"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
        
        // ✅ Create working copy of the template
        ChartTemplate *duplicatedTemplate = [template createWorkingCopy];
        duplicatedTemplate.templateID = [[NSUUID UUID] UUIDString]; // New unique ID
        duplicatedTemplate.templateName = input.stringValue;
        duplicatedTemplate.isDefault = NO; // Duplicates are never default
        duplicatedTemplate.createdDate = [NSDate date];
        duplicatedTemplate.modifiedDate = [NSDate date];
        
        // ✅ Save the duplicated template
        [[DataHub shared] saveChartTemplate:duplicatedTemplate completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
                    [self showErrorAlert:@"Duplication Failed"
                                 message:[NSString stringWithFormat:@"Could not duplicate template: %@",
                                         error.localizedDescription]];
                } else {
                    NSLog(@"✅ Template duplicated successfully: %@", duplicatedTemplate.templateName);
                    
                    // Refresh template list
                    [self loadAvailableTemplates];
                    
                    // Select the new duplicated template
                    [self.indicatorsPanel selectTemplate:duplicatedTemplate];
                    
                    // Show success feedback
                    [self showTemporaryMessage:[NSString stringWithFormat:@"Template '%@' duplicated!", input.stringValue]];
                }
            });
        }];
    }
}



- (void)duplicateTemplate:(ChartTemplate *)sourceTemplate
                  newName:(NSString *)newName
               completion:(void(^)(ChartTemplate *newTemplate, NSError *error))completion {
    
    [[DataHub shared] duplicateChartTemplate:sourceTemplate.templateID
                                     newName:newName
                                  completion:^(ChartTemplate *newTemplate, NSError *error) {
        if (newTemplate) {
            [self.availableTemplates addObject:newTemplate];
            [self.indicatorsPanel loadAvailableTemplates:self.availableTemplates];
            NSLog(@"✅ Template duplicated: %@", newName);
        } else {
            NSLog(@"❌ Failed to duplicate template: %@", error);
        }
        completion(newTemplate, error);
    }];
}

- (void)deleteTemplate:(ChartTemplate *)template
            completion:(void(^)(BOOL success, NSError *error))completion {
    
    [[DataHub shared] deleteChartTemplate:template.templateID completion:^(BOOL success, NSError *error) {
        if (success) {
            [self.availableTemplates removeObject:template];
            [self.indicatorsPanel loadAvailableTemplates:self.availableTemplates];
            NSLog(@"🗑️ Template deleted: %@", template.templateName);
        } else {
            NSLog(@"❌ Failed to delete template: %@", error);
        }
        completion(success, error);
    }];
}

- (void)resetToOriginalTemplate {
    [self.indicatorsPanel resetToOriginalTemplate];
}

#pragma mark - Data Flow


- (ChartIndicatorRenderer *)getIndicatorRendererForPanel:(NSString *)panelID {
    if (!panelID) {
        NSLog(@"⚠️ Cannot get renderer - panel ID is nil");
        return nil;
    }
    
    ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelID];
    if (!renderer) {
        NSLog(@"⚠️ No renderer found for panel: %@", panelID);
    }
    
    return renderer;
}


#pragma mark - UI State Management

- (void)updateIndicatorsPanelToggleState:(BOOL)isVisible {
    self.isIndicatorsPanelVisible = isVisible;
    
    // ✅ Update button appearance - cambia icona per indicare stato
    if (isVisible) {
        self.indicatorsPanelToggle.title = @"📊"; // Pannello aperto
        self.indicatorsPanelToggle.state = NSControlStateValueOn;
    } else {
        self.indicatorsPanelToggle.title = @"📈"; // Pannello chiuso - icona diversa
        self.indicatorsPanelToggle.state = NSControlStateValueOff;
    }
    
    // ✅ Update split view constraints per far spazio al pannello
    if (self.splitViewTrailingConstraint) {
        CGFloat trailingConstant = isVisible ? -self.indicatorsPanel.panelWidth : 0;
        
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.25;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.splitViewTrailingConstraint.animator setConstant:trailingConstant];
        } completionHandler:nil];
    }
    
    NSLog(@"🔄 Indicators panel toggle state updated: %@ (trailing: %.0f)",
          isVisible ? @"VISIBLE" : @"HIDDEN",
          isVisible ? -self.indicatorsPanel.panelWidth : 0.0);
}

- (void)handleIndicatorsPanelVisibilityChange:(BOOL)isVisible animated:(BOOL)animated {
    // Adjust main content area constraints
    if (self.splitViewTrailingConstraint) {
        CGFloat trailingConstant = isVisible ? -self.indicatorsPanel.panelWidth : 0;
        
        if (animated) {
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.25;
                [self.splitViewTrailingConstraint.animator setConstant:trailingConstant];
            } completionHandler:nil];
        } else {
            self.splitViewTrailingConstraint.constant = trailingConstant;
        }
    }
}

#pragma mark - Validation and Error Handling

- (BOOL)validateTemplate:(ChartTemplate *)template error:(NSError **)error {
    return [[DataHub shared] validateChartTemplate:template error:error];
}

- (void)handleTemplateApplicationError:(NSError *)error template:(ChartTemplate *)template {
    NSLog(@"❌ Template application error for '%@': %@", template.templateName, error.localizedDescription);
    
    NSString *errorMessage;
    if (error.code == 4001) {
        errorMessage = @"Template validation failed. The template may be corrupted.";
    } else if (error.code == 4002) {
        errorMessage = @"Template is missing required panels.";
    } else if (error.code == 4003) {
        errorMessage = @"Template contains invalid indicator configurations.";
    } else {
        errorMessage = [NSString stringWithFormat:@"Failed to apply template: %@", error.localizedDescription];
    }
    
    [self showErrorAlert:@"Template Application Failed" message:errorMessage];
    
    // ✅ Try to fallback to default template
    [[DataHub shared] getDefaultChartTemplate:^(ChartTemplate *defaultTemplate, NSError *fallbackError) {
        if (!fallbackError && defaultTemplate) {
            NSLog(@"🔄 Falling back to default template");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self applyTemplate:defaultTemplate];
                [self showTemporaryMessage:@"Reverted to default template"];
            });
        }
    }];
}

- (void)showErrorAlert:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = title;
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

#pragma mark - IndicatorsPanelDelegate

- (void)indicatorsPanel:(id)panel didSelectTemplate:(ChartTemplate *)template {
    NSLog(@"👆 User selected template: %@", template.templateName);
    
    // Non applicare subito il template, aspettiamo che l'utente clicchi "Apply"
    // Questa è solo una selezione nella combo box
    [self updateIndicatorsPanel]; // Refresh panel display
}

- (void)indicatorsPanel:(id)panel didRequestApplyTemplate:(ChartTemplate *)template {
    NSLog(@"✨ User requested to apply template: %@", template.templateName);
    
    if (!template) {
        NSLog(@"❌ Cannot apply nil template");
        return;
    }
    
    // ✅ Applica il template selezionato
    [self applyTemplate:template];
    
    // ✅ Show temporary feedback
    [self showTemporaryMessage:[NSString stringWithFormat:@"Applied template: %@", template.templateName]];
}

- (void)indicatorsPanel:(id)panel
     didRequestAddIndicator:(NSString *)indicatorType
               toPanel:(ChartPanelTemplate *)targetPanel
          parentIndicator:(TechnicalIndicatorBase *)parentIndicator {
    
    // Create indicator instance
    Class indicatorClass = NSClassFromString(indicatorType);
    if (!indicatorClass) {
        NSLog(@"⚠️ Unknown indicator type: %@", indicatorType);
        return;
    }
    
    // Show configuration dialog for parameters
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Add %@", indicatorType];
    alert.informativeText = @"Configure indicator parameters:";
    
    // Add parameter input fields (this would be more sophisticated in real implementation)
    NSTextField *periodField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    periodField.placeholderString = @"Period (e.g., 14)";
    periodField.stringValue = @"14";
    alert.accessoryView = periodField;
    
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSDictionary *parameters = @{@"period": @([periodField.stringValue integerValue])};
        TechnicalIndicatorBase *indicator = [[indicatorClass alloc] initWithParameters:parameters];
        
        [self addIndicator:indicator toPanel:targetPanel parentIndicator:parentIndicator];
    }
}

- (void)indicatorsPanel:(id)panel didRequestRemoveIndicator:(TechnicalIndicatorBase *)indicator {
    [self removeIndicator:indicator];
}

- (void)indicatorsPanel:(id)panel didRequestConfigureIndicator:(TechnicalIndicatorBase *)indicator {
    [self configureIndicator:indicator];
}

- (void)indicatorsPanel:(id)panel didRequestCreateTemplate:(NSString *)templateName {
    NSLog(@"🆕 User requested to create template: %@", templateName);
    
    if (!templateName || templateName.length == 0) {
        [self showErrorAlert:@"Invalid Template Name" message:@"Please provide a valid template name."];
        return;
    }
    
    // ✅ Crea un nuovo template basato sui pannelli correnti
    [self createTemplateFromCurrentPanels:templateName completion:^(ChartTemplate *newTemplate, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:@"Template Creation Failed"
                             message:[NSString stringWithFormat:@"Could not create template '%@': %@",
                                     templateName, error.localizedDescription]];
            });
        } else {
            NSLog(@"✅ Template created successfully: %@", newTemplate.templateName);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Reload templates nel panel
                [self loadAvailableTemplates];
                
                // Seleziona il nuovo template
                [self.indicatorsPanel selectTemplate:newTemplate];
                
                // Show success message
                [self showTemporaryMessage:[NSString stringWithFormat:@"Template '%@' created!", templateName]];
            });
        }
    }];
}

- (void)indicatorsPanel:(id)panel didChangeVisibility:(BOOL)isVisible {
    NSLog(@"👁️ Indicators panel visibility changed: %@", isVisible ? @"VISIBLE" : @"HIDDEN");
    
    // ✅ Update toggle button state
    [self updateIndicatorsPanelToggleState:isVisible];
}

- (void)indicatorsPanel:(id)panel didRequestTemplateAction:(NSString *)action forTemplate:(ChartTemplate *)template {
    NSLog(@"🎬 User requested template action: %@ for template: %@", action, template.templateName);
    
    if ([action isEqualToString:@"duplicate"]) {
        [self duplicateTemplate:template];
    } else if ([action isEqualToString:@"rename"]) {
        [self renameTemplate:template];
    } else if ([action isEqualToString:@"delete"]) {
        [self deleteTemplateWithConfirmation:template];
    } else if ([action isEqualToString:@"export"]) {
        [self exportTemplate:template];
    } else {
        NSLog(@"❓ Unknown template action: %@", action);
    }
}
#pragma mark - Cleanup

- (void)cleanupIndicatorsUI {
    // Clean up renderers
    for (ChartIndicatorRenderer *renderer in self.indicatorRenderers.allValues) {
        [renderer cleanup];
    }
    [self.indicatorRenderers removeAllObjects];
    
    // Remove UI components
    [self.indicatorsPanel removeFromSuperview];
    [self.indicatorsPanelToggle removeFromSuperview];
    
    // Clear references
    self.indicatorsPanel = nil;
    self.indicatorsPanelToggle = nil;
    self.currentChartTemplate = nil;
    [self.availableTemplates removeAllObjects];
    
    NSLog(@"🧹 Indicators UI cleanup completed");
}

#pragma mark - Template Management Helper Methods

- (void)createTemplateFromCurrentPanels:(NSString *)templateName
                              completion:(void(^)(ChartTemplate *template, NSError *error))completion {
    
    if (self.chartPanels.count == 0) {
        NSError *error = [NSError errorWithDomain:@"ChartTemplateCreation"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"No panels available to create template from"}];
        completion(nil, error);
        return;
    }
    
    // ✅ USA SOLO metodi esistenti in DataHub+ChartTemplates
    [[DataHub shared] getDefaultChartTemplate:^(ChartTemplate *defaultTemplate, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        // Create new template based on default
        ChartTemplate *newTemplate = [defaultTemplate createWorkingCopy];
        newTemplate.templateID = [[NSUUID UUID] UUIDString];
        newTemplate.templateName = templateName;
        newTemplate.isDefault = NO;
        newTemplate.createdDate = [NSDate date];
        newTemplate.modifiedDate = [NSDate date];
        
        // Save using existing method
        [[DataHub shared] saveChartTemplate:newTemplate completion:^(BOOL success, NSError *saveError) {
            completion(success ? newTemplate : nil, saveError);
        }];
    }];
}

- (void)renameTemplate:(ChartTemplate *)template {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Template";
    alert.informativeText = @"Enter new name for the template:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    input.stringValue = template.templateName;
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
        template.templateName = input.stringValue;
        template.modifiedDate = [NSDate date];
        
        [[DataHub shared] saveChartTemplate:template completion:^(BOOL success, NSError *error) {
            if (!success) {
                [self showErrorAlert:@"Rename Failed" message:error.localizedDescription];
            } else {
                [self loadAvailableTemplates]; // Refresh
                [self showTemporaryMessage:[NSString stringWithFormat:@"Template renamed to '%@'", input.stringValue]];
            }
        }];
    }
}

- (void)exportTemplate:(ChartTemplate *)template {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"json"];
    savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@.json", template.templateName];
    
    NSModalResponse response = [savePanel runModal];
    if (response == NSModalResponseOK) {
        NSError *error;
        NSData *exportData = [[DataHub shared] exportTemplate:template error:&error];
        if (exportData) {
            BOOL success = [exportData writeToURL:savePanel.URL atomically:YES];
            if (success) {
                [self showTemporaryMessage:@"Template exported successfully"];
            } else {
                [self showErrorAlert:@"Export Error" message:@"Failed to write template file"];
            }
        } else {
            [self showErrorAlert:@"Export Error" message:error.localizedDescription];
        }
    }
}


- (void)deleteTemplateWithConfirmation:(ChartTemplate *)template {
    if (template.isDefault) {
        [self showErrorAlert:@"Cannot Delete" message:@"Default templates cannot be deleted."];
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Template";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the template '%@'? This action cannot be undone.", template.templateName];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        
        // ✅ Delete the template
        [[DataHub shared] deleteChartTemplate:template completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
                    [self showErrorAlert:@"Deletion Failed"
                                 message:[NSString stringWithFormat:@"Could not delete template: %@",
                                         error.localizedDescription]];
                } else {
                    NSLog(@"✅ Template deleted successfully: %@", template.templateName);
                    
                    // If this was the current template, switch to default
                    if (self.currentChartTemplate == template ||
                        [self.currentChartTemplate.templateID isEqualToString:template.templateID]) {
                        
                        // Load default template
                        [[DataHub shared] getDefaultChartTemplate:^(ChartTemplate *defaultTemplate, NSError *error) {
                            if (!error && defaultTemplate) {
                                [self applyTemplate:defaultTemplate];
                            }
                        }];
                    }
                    
                    // Refresh template list
                    [self loadAvailableTemplates];
                    
                    // Show success feedback
                    [self showTemporaryMessage:[NSString stringWithFormat:@"Template '%@' deleted", template.templateName]];
                }
            });
        }];
    }
}



@end
