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

// Associated object keys
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
    
    // Create toggle button
    [self createIndicatorsPanelToggleButton];
    
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
    
    NSLog(@"✅ Indicators UI setup completed");
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
    // Position next to objects panel toggle (if it exists)
    NSButton *objectsToggle = self.objectsPanelToggle;
    
    if (objectsToggle) {
        // Place to the right of objects toggle
        [NSLayoutConstraint activateConstraints:@[
            [self.indicatorsPanelToggle.trailingAnchor constraintEqualToAnchor:objectsToggle.leadingAnchor constant:-4],
            [self.indicatorsPanelToggle.centerYAnchor constraintEqualToAnchor:objectsToggle.centerYAnchor],
            [self.indicatorsPanelToggle.widthAnchor constraintEqualToConstant:32],
            [self.indicatorsPanelToggle.heightAnchor constraintEqualToConstant:32]
        ]];
    } else {
        // Place in top-right corner
        [NSLayoutConstraint activateConstraints:@[
            [self.indicatorsPanelToggle.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
            [self.indicatorsPanelToggle.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
            [self.indicatorsPanelToggle.widthAnchor constraintEqualToConstant:32],
            [self.indicatorsPanelToggle.heightAnchor constraintEqualToConstant:32]
        ]];
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
    if (self.currentChartTemplate) {
        [self.indicatorsPanel selectTemplate:self.currentChartTemplate];
    }
}

- (void)refreshIndicatorsRendering {
    for (NSString *panelID in self.indicatorRenderers.allKeys) {
        ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelID];
        [renderer invalidateIndicatorLayers];
    }
}

#pragma mark - Panel Management

- (ChartPanelView *)createChartPanelFromTemplate:(ChartPanelTemplate *)panelTemplate {
    ChartPanelView *panelView = [[ChartPanelView alloc] initWithType:panelTemplate.rootIndicatorType];
    
    // Configure panel properties
    panelView.panelTemplate = panelTemplate;
    
    // Setup indicator renderer for the panel
    [self setupIndicatorRendererForPanel:panelView];
    
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
        NSLog(@"⚠️ Panel count mismatch during height redistribution");
        return;
    }
    
    // Apply relative heights to split view
    for (NSInteger i = 0; i < orderedPanels.count; i++) {
        ChartPanelTemplate *panelTemplate = orderedPanels[i];
        // Note: Actual height distribution implementation depends on your split view setup
        // This is a placeholder for the height distribution logic
        NSLog(@"📏 Panel %ld height: %.2f%%", (long)i, panelTemplate.relativeHeight * 100);
    }
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
    
    NSLog(@"🎯 Applying template: %@", template.templateName);
    
    // Store current template
    self.currentChartTemplate = template;
    
    // Update panels
    [self updatePanelsWithTemplate:template];
    
    // Calculate indicators
    [self calculateAllIndicators];
    
    // Update indicators panel
    [self updateIndicatorsPanel];
    
    NSLog(@"✅ Template applied successfully: %@", template.templateName);
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
    if (!self.currentChartTemplate || !self.currentChartData) return;
    
    for (ChartPanelTemplate *panelTemplate in self.currentChartTemplate.panels) {
        [self calculateIndicatorsForPanel:panelTemplate];
    }
}

- (void)calculateIndicatorsForPanel:(ChartPanelTemplate *)panelTemplate {
    if (!panelTemplate.rootIndicator || !self.currentChartData) return;
    
    // Calculate the entire indicator tree for this panel
    [panelTemplate.rootIndicator calculateIndicatorTree:self.currentChartData];
    
    // Update rendering
    ChartIndicatorRenderer *renderer = [self getIndicatorRendererForPanel:panelTemplate.panelID];
    if (renderer) {
        [renderer renderIndicatorTree:panelTemplate.rootIndicator];
    }
    
    NSLog(@"📊 Calculated indicators for panel: %@", panelTemplate.displayName);
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
    return self.indicatorRenderers[panelID];
}

- (void)setupIndicatorRendererForPanel:(ChartPanelView *)panelView {
    if (!panelView.panelTemplate) return;
    
    NSString *panelID = panelView.panelTemplate.panelID;
    
    // Create renderer if it doesn't exist
    ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelID];
    if (!renderer) {
        renderer = [[ChartIndicatorRenderer alloc] initWithPanelView:panelView];
        self.indicatorRenderers[panelID] = renderer;
        NSLog(@"🎨 Created indicator renderer for panel: %@", panelID);
    }
}

#pragma mark - UI State Management

- (void)updateIndicatorsPanelToggleState:(BOOL)isVisible {
    self.isIndicatorsPanelVisible = isVisible;
    
    // Update button appearance
    if (isVisible) {
        self.indicatorsPanelToggle.state = NSControlStateValueOn;
    } else {
        self.indicatorsPanelToggle.state = NSControlStateValueOff;
    }
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
    NSString *title = @"Template Application Error";
    NSString *message = [NSString stringWithFormat:@"Failed to apply template '%@': %@",
                        template.templateName, error.localizedDescription];
    [self showErrorAlert:title message:message];
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
    [self applyTemplate:template];
}

- (void)indicatorsPanel:(id)panel didRequestApplyTemplate:(ChartTemplate *)template {
    [self applyTemplate:template];
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
    [self saveCurrentTemplateAs:templateName completion:^(BOOL success, NSError *error) {
        if (!success) {
            [self showErrorAlert:@"Template Save Error" message:error.localizedDescription];
        }
    }];
}

- (void)indicatorsPanel:(id)panel didChangeVisibility:(BOOL)isVisible {
    [self handleIndicatorsPanelVisibilityChange:isVisible animated:YES];
}

- (void)indicatorsPanel:(id)panel didRequestTemplateAction:(NSString *)action forTemplate:(ChartTemplate *)template {
    if ([action isEqualToString:@"duplicate"]) {
        NSString *newName = [NSString stringWithFormat:@"%@ Copy", template.templateName];
        [self duplicateTemplate:template newName:newName completion:^(ChartTemplate *newTemplate, NSError *error) {
            if (!newTemplate) {
                [self showErrorAlert:@"Template Duplicate Error" message:error.localizedDescription];
            }
        }];
        
    } else if ([action isEqualToString:@"delete"]) {
        NSAlert *confirmAlert = [[NSAlert alloc] init];
        confirmAlert.messageText = @"Delete Template";
        confirmAlert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?", template.templateName];
        confirmAlert.alertStyle = NSAlertStyleWarning;
        [confirmAlert addButtonWithTitle:@"Delete"];
        [confirmAlert addButtonWithTitle:@"Cancel"];
        
        NSModalResponse response = [confirmAlert runModal];
        if (response == NSAlertFirstButtonReturn) {
            [self deleteTemplate:template completion:^(BOOL success, NSError *error) {
                if (!success) {
                    [self showErrorAlert:@"Template Delete Error" message:error.localizedDescription];
                }
            }];
        }
        
    } else if ([action isEqualToString:@"export"]) {
        // Show save panel for export
        NSSavePanel *savePanel = [NSSavePanel savePanel];
        savePanel.allowedFileTypes = @[@"json"];
        savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@.json", template.templateName];
        
        NSModalResponse response = [savePanel runModal];
        if (response == NSModalResponseOK) {
            NSError *error;
            NSData *exportData = [[DataHub shared] exportTemplate:template error:&error];
            if (exportData) {
                BOOL success = [exportData writeToURL:savePanel.URL atomically:YES];
                if (!success) {
                    [self showErrorAlert:@"Export Error" message:@"Failed to write template file"];
                }
            } else {
                [self showErrorAlert:@"Export Error" message:error.localizedDescription];
            }
        }
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

@end
