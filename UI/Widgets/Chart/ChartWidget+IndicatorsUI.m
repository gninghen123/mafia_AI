//
//  ChartWidget+IndicatorsUI.m - AGGIORNATO per runtime models
//  TradingApp
//
//  ChartWidget extension implementation using ChartTemplateModel (runtime models)
//

#import "ChartWidget+IndicatorsUI.h"
#import "DataHub+ChartTemplates.h"
#import "ChartPanelView.h"
#import <objc/runtime.h>
#import "TechnicalIndicatorBase+Hierarchy.h"
#import "ChartIndicatorRenderer.h"
#import "IndicatorRegistry.h"


#pragma mark - Associated Object Keys

static const void *kIndicatorsPanelToggleKey = &kIndicatorsPanelToggleKey;
static const void *kIndicatorsPanelKey = &kIndicatorsPanelKey;
static const void *kIsIndicatorsPanelVisibleKey = &kIsIndicatorsPanelVisibleKey;
static const void *kSplitViewTrailingConstraintKey = &kSplitViewTrailingConstraintKey;
static const void *kCurrentChartTemplateKey = &kCurrentChartTemplateKey;
static const void *kAvailableTemplatesKey = &kAvailableTemplatesKey;
static const void *kIndicatorRenderersKey = &kIndicatorRenderersKey;

@implementation ChartWidget (IndicatorsUI)

#pragma mark - Associated Objects - AGGIORNATI per runtime models

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

// ✅ AGGIORNATO: currentChartTemplate ora è ChartTemplateModel (runtime model)
- (ChartTemplateModel *)currentChartTemplate {
    return objc_getAssociatedObject(self, kCurrentChartTemplateKey);
}

- (void)setCurrentChartTemplate:(ChartTemplateModel *)template {
    objc_setAssociatedObject(self, kCurrentChartTemplateKey, template, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ✅ AGGIORNATO: availableTemplates ora è array di ChartTemplateModel
- (NSMutableArray<ChartTemplateModel *> *)availableTemplates {
    NSMutableArray *templates = objc_getAssociatedObject(self, kAvailableTemplatesKey);
    if (!templates) {
        templates = [NSMutableArray array];
        [self setAvailableTemplates:templates];
    }
    return templates;
}

- (void)setAvailableTemplates:(NSMutableArray<ChartTemplateModel *> *)templates {
    objc_setAssociatedObject(self, kAvailableTemplatesKey, templates, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString *, ChartIndicatorRenderer *> *)indicatorRenderers {
    NSMutableDictionary *renderers = objc_getAssociatedObject(self, kIndicatorRenderersKey);
    if (!renderers) {
        renderers = [NSMutableDictionary dictionary];
        [self setIndicatorRenderers:renderers];
    }
    return renderers;
}

- (void)setIndicatorRenderers:(NSMutableDictionary<NSString *, ChartIndicatorRenderer *> *)renderers {
    objc_setAssociatedObject(self, kIndicatorRenderersKey, renderers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Setup and Initialization

- (void)setupIndicatorsUI {
    self.indicatorsPanel = [[IndicatorsPanel alloc] init];
    self.indicatorsPanel.delegate = self;
    self.indicatorsPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.indicatorsPanel setFrame:NSMakeRect(0, 0, 280, 1900)];
}

#pragma mark - Template Management - AGGIORNATO per runtime models

- (void)loadAvailableTemplates:(void(^)(BOOL success))completion {
  
    
    NSLog(@"📋 Loading available templates from DataHub...");
    
    [[DataHub shared] getAllChartTemplates:^(NSArray<ChartTemplateModel *> *templates) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (templates && templates.count > 0) {
                self.availableTemplates = [templates mutableCopy];
                
                // Update indicators panel if exists
                if (self.indicatorsPanel) {
                    [self.indicatorsPanel loadAvailableTemplates:templates];
                }
                
                NSLog(@"✅ Loaded %ld templates", (long)templates.count);
                if (completion) completion(YES);
            } else {
                NSLog(@"⚠️ No templates found");
                if (completion) completion(NO);
            }
        });
    }];
}




// ✅ METODO PRINCIPALE AGGIORNATO per ChartTemplateModel
- (void)applyTemplate:(ChartTemplateModel *)template {
    if (!template) {
        NSLog(@"❌ Cannot apply nil template");
        return;
    }
    
    NSLog(@"🎨 Applying template: %@ (runtime model)", template.templateName);
    
    // ✅ Validate template first
    NSError *validationError;
    if (![template isValidWithError:&validationError]) {
        NSLog(@"❌ Template validation failed: %@", validationError.localizedDescription);
        [self handleTemplateApplicationError:validationError template:template];
        return;
    }
    
    // ✅ STEP 1: Remove existing panels from split view
    [self removeExistingPanelsFromSplitView];
    
    // ✅ STEP 2: Create panels from template using runtime models
    NSArray<ChartPanelTemplateModel *> *orderedPanels = [template orderedPanels];
    
    for (ChartPanelTemplateModel *panelTemplate in orderedPanels) {
        ChartPanelView *panelView = [self createChartPanelFromTemplate:panelTemplate];
        if (panelView) {
            [self.chartPanels addObject:panelView];
            [self.panelsSplitView addSubview:panelView];
            NSLog(@"📊 Created panel: %@ -> %@ (%.0f%%)",
                  panelTemplate.rootIndicatorType,
                  [panelTemplate displayName],
                  panelTemplate.relativeHeight * 100);
        }
    }
    
    // ✅ STEP 3: Redistribute panel heights
    [self redistributePanelHeights:template];
    
    // ✅ STEP 4: Setup renderers for all panels
    [self setupRenderersForAllPanels];
    
    // ✅ STEP 5: Set current template
    self.currentChartTemplate = template;
    
    // Save as last used quando applicato con successo
       if (template && template.templateID) {
           [self saveLastUsedTemplate:template];
       }
    
    // ✅ STEP 6: Update with chart data if available
    if (self.currentChartData && self.currentChartData.count > 0) {
        [self updateIndicatorsWithChartData:self.currentChartData];
        [self updateAllPanelsWithCurrentData];
    }
    
    NSLog(@"✅ Template applied successfully: %@ (%ld panels created)",
          template.templateName, (long)self.chartPanels.count);
    
    // ✅ STEP 7: Update indicators panel UI
    [self updateIndicatorsPanel];
}

- (ChartPanelView *)createChartPanelFromTemplate:(ChartPanelTemplateModel *)panelTemplate {
    if (!panelTemplate) {
        NSLog(@"❌ Cannot create panel from nil template");
        return nil;
    }
    
    NSLog(@"🏗️ Creating panel from template: %@ (%@)",
          [panelTemplate displayName], panelTemplate.rootIndicatorType);
    
    // ✅ STEP 1: Determine panel type from root indicator
    NSString *panelType = [self panelTypeForRootIndicator:panelTemplate.rootIndicatorType];
    
    // ✅ STEP 2: Create panel view
    ChartPanelView *panelView = [[ChartPanelView alloc] initWithType:panelType];
    panelView.translatesAutoresizingMaskIntoConstraints = NO;
    panelView.chartWidget = self;
    
    // ✅ STEP 3: Create and configure root indicator
    TechnicalIndicatorBase *rootIndicator = [self createRootIndicatorFromTemplate:panelTemplate];
    if (!rootIndicator) {
        NSLog(@"❌ Failed to create root indicator for panel: %@", panelTemplate.rootIndicatorType);
        return nil;
    }
    
    // ✅ STEP 4: **CRITICAL FIX** - Create CHILD INDICATORS from template data!
    NSArray<TechnicalIndicatorBase *> *childIndicators = [self createChildIndicatorsFromData:panelTemplate.childIndicatorsData];
    
    // ✅ STEP 4b: Add child indicators to root indicator
    for (TechnicalIndicatorBase *childIndicator in childIndicators) {
        NSLog(@"🔗 Adding child indicator %@ to parent %@", childIndicator.shortName, rootIndicator.shortName);
        [rootIndicator addChildIndicator:childIndicator];
        
        // ✅ CRITICAL: Set the needsRendering flag!
        childIndicator.needsRendering = YES;
        NSLog(@"✅ Set needsRendering=YES for child indicator: %@", childIndicator.shortName);
    }
    
    // ✅ STEP 4c: Also set needsRendering for root
    rootIndicator.needsRendering = YES;
    NSLog(@"✅ Set needsRendering=YES for root indicator: %@", rootIndicator.shortName);
    
    NSLog(@"📊 Created panel with %ld child indicators total", (long)childIndicators.count);
    
    // ✅ STEP 5: Create indicator renderer and give it the root indicator
    ChartIndicatorRenderer *renderer = [[ChartIndicatorRenderer alloc] initWithPanelView:panelView];
    renderer.rootIndicator = rootIndicator;
    
    // ✅ STEP 6: Set renderer on panel view
    panelView.indicatorRenderer = renderer;
    
    // ✅ STEP 7: Store renderer in ChartWidget dictionary with panel ID
    if (!self.indicatorRenderers) {
        self.indicatorRenderers = [[NSMutableDictionary alloc] init];
    }
    self.indicatorRenderers[panelTemplate.panelID] = renderer;
    
    // ✅ STEP 8: Calculate and render indicators if we have chart data
    if (self.currentChartData && self.currentChartData.count > 0) {
        NSLog(@"🧮 About to calculate indicators with %ld bars", (long)self.currentChartData.count);
        [self calculateAndRenderIndicatorsForRenderer:renderer withData:self.currentChartData];
    } else {
        NSLog(@"⚠️ No chart data available for calculation");
    }
    
    return panelView;
}

- (void)calculateAndRenderIndicatorsForRenderer:(ChartIndicatorRenderer *)renderer
                                       withData:(NSArray<HistoricalBarModel *> *)chartData {
    
    if (!renderer.rootIndicator) {
        NSLog(@"⚠️ No root indicator to calculate and render");
        return;
    }
    
    NSLog(@"🧮 Calculating indicator tree with %lu data points", (unsigned long)chartData.count);
    NSLog(@"🔍 Root indicator: %@, has %ld children",
          renderer.rootIndicator.shortName,
          (long)renderer.rootIndicator.childIndicators.count);
    
    @try {
        // ✅ CALCULATE ROOT INDICATOR
        [renderer.rootIndicator calculateWithBars:chartData];
        NSLog(@"✅ Calculated root indicator: %@", renderer.rootIndicator.shortName);
        
        // ✅ CALCULATE ALL CHILD INDICATORS
        for (TechnicalIndicatorBase *childIndicator in renderer.rootIndicator.childIndicators) {
            NSLog(@"🧮 Calculating child indicator: %@", childIndicator.shortName);
            [childIndicator calculateWithBars:chartData];
            NSLog(@"✅ Calculated child indicator: %@", childIndicator.shortName);
        }
        
    } @catch (NSException *exception) {
        NSLog(@"❌ Failed to calculate indicator tree %@: %@", renderer.rootIndicator.shortName, exception.reason);
        return;
    }
    
    // ✅ RENDER THE ENTIRE TREE
    @try {
        [renderer renderIndicatorTree:renderer.rootIndicator];
        NSLog(@"✅ Rendered indicator tree for: %@", renderer.rootIndicator.shortName);
    } @catch (NSException *exception) {
        NSLog(@"❌ Failed to render indicators: %@", exception.reason);
    }
}


#pragma mark - Helper Methods for Indicator Creation

- (TechnicalIndicatorBase *)createRootIndicatorFromTemplate:(ChartPanelTemplateModel *)panelTemplate {
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    
    // Create root indicator with its parameters
    TechnicalIndicatorBase *rootIndicator = [registry createIndicatorWithIdentifier:panelTemplate.rootIndicatorType
                                                                         parameters:panelTemplate.rootIndicatorParams];
    
    if (rootIndicator) {
        // Set additional properties
        rootIndicator.indicatorID = panelTemplate.panelID; // Use panel ID as root indicator ID
        rootIndicator.isVisible = YES;
        
        NSLog(@"✅ Created root indicator: %@ (%@)",
              rootIndicator.shortName, panelTemplate.rootIndicatorType);
    } else {
        NSLog(@"❌ Failed to create root indicator: %@", panelTemplate.rootIndicatorType);
    }
    
    return rootIndicator;
}


- (NSArray<TechnicalIndicatorBase *> *)createAllIndicatorsFromTemplate:(ChartPanelTemplateModel *)panelTemplate
                                                          rootIndicator:(TechnicalIndicatorBase *)rootIndicator {
    
    NSMutableArray<TechnicalIndicatorBase *> *allIndicators = [[NSMutableArray alloc] init];
    
    // Add root indicator first
    [allIndicators addObject:rootIndicator];
    
    // Create child indicators from childIndicatorsData
    if (panelTemplate.childIndicatorsData && panelTemplate.childIndicatorsData.count > 0) {
        NSArray<TechnicalIndicatorBase *> *childIndicators = [self createChildIndicatorsFromData:panelTemplate.childIndicatorsData];
        [allIndicators addObjectsFromArray:childIndicators];
    }
    
    NSLog(@"📊 Created %lu total indicators for panel (%lu children)",
          (unsigned long)allIndicators.count,
          (unsigned long)(allIndicators.count - 1));
    
    return [allIndicators copy];
}

- (NSArray<TechnicalIndicatorBase *> *)createChildIndicatorsFromData:(NSArray<NSDictionary *> *)childIndicatorsData {
    
    if (!childIndicatorsData || childIndicatorsData.count == 0) {
        NSLog(@"📝 No child indicators data to convert");
        return @[];
    }
    
    NSMutableArray<TechnicalIndicatorBase *> *childIndicators = [[NSMutableArray alloc] init];
    IndicatorRegistry *registry = [IndicatorRegistry sharedRegistry];
    
    for (NSDictionary *childData in childIndicatorsData) {
        NSString *indicatorID = childData[@"indicatorID"];
        NSDictionary *parameters = childData[@"parameters"];
        
        if (!indicatorID) {
            NSLog(@"⚠️ Skipping child indicator with missing indicatorID");
            continue;
        }
        
        // Create the indicator
        TechnicalIndicatorBase *childIndicator = [registry createIndicatorWithIdentifier:indicatorID
                                                                              parameters:parameters];
        
        if (childIndicator) {
            // Set additional properties from metadata
            childIndicator.indicatorID = childData[@"instanceID"] ?: [[NSUUID UUID] UUIDString];
            childIndicator.isVisible = [childData[@"isVisible"] boolValue] ?: YES;
            
            // Set display properties if available
            if (childData[@"displayColor"]) {
                NSData *colorData = childData[@"displayColor"];
                NSColor *color = [NSUnarchiver unarchiveObjectWithData:colorData];
                if (color) {
                    childIndicator.displayColor = color;
                }
            }
            
            if (childData[@"lineWidth"]) {
                childIndicator.lineWidth = [childData[@"lineWidth"] floatValue];
            }
            
            [childIndicators addObject:childIndicator];
            NSLog(@"✅ Created child indicator: %@ from %@", childIndicator.shortName, indicatorID);
        } else {
            NSLog(@"❌ Failed to create child indicator: %@", indicatorID);
        }
    }
    
    NSLog(@"📊 Created %lu child indicators from data", (unsigned long)childIndicators.count);
    return [childIndicators copy];
}

// ✅ HELPER: Determine panel type from root indicator type
- (NSString *)panelTypeForRootIndicator:(NSString *)rootIndicatorType {
    if ([rootIndicatorType isEqualToString:@"security"] ||
        [rootIndicatorType isEqualToString:@"SecurityIndicator"]) {
        return @"security";
    } else if ([rootIndicatorType isEqualToString:@"volume"] ||
               [rootIndicatorType isEqualToString:@"VolumeIndicator"]) {
        return @"volume";
    } else {
        return @"oscillator"; // Default for all other indicators
    }
}
// ✅ AGGIORNATO per ChartTemplateModel
// Updated: Use Auto Layout constraints for relative heights instead of manual frames
- (void)redistributePanelHeights:(ChartTemplateModel *)template {
    if (!template || !self.panelsSplitView) {
        NSLog(@"❌ Cannot redistribute heights - missing template or split view");
        return;
    }

    NSArray<ChartPanelTemplateModel *> *orderedPanels = [template orderedPanels];
    NSArray<NSView *> *splitSubviews = self.panelsSplitView.arrangedSubviews;

    if (orderedPanels.count != splitSubviews.count) {
        NSLog(@"⚠️ Panel count mismatch during height redistribution (%ld template vs %ld views)",
              (long)orderedPanels.count, (long)splitSubviews.count);
        return;
    }

    if (orderedPanels.count <= 1) {
        NSLog(@"📏 Single panel - no dividers to adjust");
        return;
    }

    NSLog(@"📏 Redistributing panel heights with Auto Layout constraints...");

    // Remove any existing height constraints
    for (NSView *panelView in splitSubviews) {
        NSMutableArray *toRemove = [NSMutableArray array];
        for (NSLayoutConstraint *constraint in panelView.constraints) {
            if (constraint.firstAttribute == NSLayoutAttributeHeight) {
                [toRemove addObject:constraint];
            }
        }
        [panelView removeConstraints:toRemove];
    }

    // Set new height constraints based on relativeHeight
    for (NSUInteger i = 0; i < orderedPanels.count; i++) {
        ChartPanelTemplateModel *panelTemplate = orderedPanels[i];
        NSView *panelView = splitSubviews[i];

        NSLayoutConstraint *heightConstraint =
            [panelView.heightAnchor constraintEqualToAnchor:self.panelsSplitView.heightAnchor
                                                 multiplier:panelTemplate.relativeHeight];
        heightConstraint.active = YES;

        NSLog(@"📐 Panel %lu (%@): set height constraint to %.0f%% of split view",
              (unsigned long)i, [panelTemplate displayName], panelTemplate.relativeHeight * 100);
    }

//    [self.panelsSplitView layoutSubtreeIfNeeded];

    NSLog(@"✅ Panel heights redistributed with constraints successfully");
}


#pragma mark - IndicatorsPanelDelegate - AGGIORNATO per runtime models

- (void)indicatorsPanel:(id)panel didRequestTemplateAction:(NSString *)action forTemplate:(ChartTemplateModel *)template {
    NSLog(@"🔧 Template action requested: %@ for template: %@", action, template.templateName ?: @"nil");
    
    if ([action isEqualToString:@"reload"]) {
        // ✅ Reload templates and select specific one
        [self loadAvailableTemplates:^(BOOL success) {
            if (success && template) {
                // Find template by ID in reloaded list
                ChartTemplateModel *reloadedTemplate = nil;
                for (ChartTemplateModel *t in self.availableTemplates) {
                    if ([t.templateID isEqualToString:template.templateID]) {
                        reloadedTemplate = t;
                        break;
                    }
                }
                
                if (reloadedTemplate) {
                    [self.indicatorsPanel selectTemplate:reloadedTemplate];
                } else if (self.availableTemplates.count > 0) {
                    // Template was deleted, select first available
                    [self.indicatorsPanel selectTemplate:self.availableTemplates.firstObject];
                }
            }
        }];
        
    } else if ([action isEqualToString:@"delete"]) {
        // ✅ Handle template deletion
        NSLog(@"🗑️ Handling template deletion via delegate");
        // The actual deletion is handled in IndicatorsPanel, this is just notification
        
    } else if ([action isEqualToString:@"duplicate"] || [action isEqualToString:@"rename"]) {
        // ✅ Handle template modification
        NSLog(@"📝 Handling template modification via delegate");
        // The actual operation is handled in IndicatorsPanel, this is just notification
        
    } else {
        NSLog(@"⚠️ Unknown template action: %@", action);
    }
}

// ✅ AGGIORNATO signature per ChartTemplateModel
- (void)indicatorsPanel:(id)panel didSelectTemplate:(ChartTemplateModel *)template {
    NSLog(@"👆 User selected runtime template: %@", template.templateName);
    
    // Non applicare subito il template, aspettiamo che l'utente clicchi "Apply"
    [self updateIndicatorsPanel];
}

// ✅ AGGIORNATO signature per ChartTemplateModel
- (void)indicatorsPanel:(id)panel didRequestApplyTemplate:(ChartTemplateModel *)template {
    NSLog(@"✨ User requested to apply runtime template: %@", template.templateName);
    
    if (!template) {
        NSLog(@"❌ Cannot apply nil template");
        return;
    }
    
    // ✅ Apply the selected template
    [self applyTemplate:template];
    
    // ✅ Show feedback
    [self showTemporaryMessage:[NSString stringWithFormat:@"Applied template: %@", template.templateName]];
}

- (void)indicatorsPanel:(id)panel didRequestSaveTemplate:(ChartTemplateModel *)template {
    NSLog(@"💾 User requested to save complete template: %@", template.templateName);
    
    if (!template) {
        NSLog(@"❌ Cannot save nil template");
        [self showErrorAlert:@"Save Failed" message:@"No template data to save."];
        return;
    }
    
    // ✅ Direct save to DataHub - no need to recreate from panels
    [[DataHub shared] saveChartTemplate:template completion:^(BOOL success, ChartTemplateModel *savedTemplate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && savedTemplate) {
                NSLog(@"✅ Template saved successfully: %@", savedTemplate.templateName);
                
                // Reload templates to include the new one
                [self loadAvailableTemplates:^(BOOL loadSuccess) {
                    if (loadSuccess) {
                        // Select the newly saved template
                        [self.indicatorsPanel selectTemplate:savedTemplate];
                        
                        // Show success message
                        [self showTemporaryMessage:[NSString stringWithFormat:@"Template '%@' saved!", savedTemplate.templateName]];
                    }
                }];
                
            } else {
                NSLog(@"❌ Failed to save template: %@", template.templateName);
                [self showErrorAlert:@"Save Failed"
                             message:[NSString stringWithFormat:@"Could not save template '%@'. Please try again.", template.templateName]];
            }
        });
    }];
}


#pragma mark - Template Actions - AGGIORNATI per runtime models

// ✅ AGGIORNATO per ChartTemplateModel
- (void)duplicateTemplate:(ChartTemplateModel *)template {
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
        
        // ✅ USA NUOVA API con runtime models
        [[DataHub shared] duplicateChartTemplate:template.templateID
                                         newName:input.stringValue
                                      completion:^(BOOL success, ChartTemplateModel *newTemplate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success || !newTemplate) {
                    [self showErrorAlert:@"Duplication Failed"
                                 message:@"Could not duplicate template"];
                } else {
                    NSLog(@"✅ Runtime template duplicated successfully: %@", newTemplate.templateName);
                    
                    // Refresh template list
                    [self loadAvailableTemplates];
                    
                    // Select the new duplicated template
                    [self.indicatorsPanel selectTemplate:newTemplate];
                    
                    // Show success feedback
                    [self showTemporaryMessage:[NSString stringWithFormat:@"Template '%@' duplicated!", input.stringValue]];
                }
            });
        }];
    }
}

// ✅ AGGIORNATO per ChartTemplateModel
- (void)deleteTemplateWithConfirmation:(ChartTemplateModel *)template {
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
        
        // ✅ USA NUOVA API
        [[DataHub shared] deleteChartTemplate:template.templateID completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
                    [self showErrorAlert:@"Deletion Failed"
                                 message:@"Could not delete template"];
                } else {
                    NSLog(@"✅ Runtime template deleted successfully: %@", template.templateName);
                    
                    // If this was the current template, switch to default
                    if (self.currentChartTemplate &&
                        [self.currentChartTemplate.templateID isEqualToString:template.templateID]) {
                        
                        // Load default template
                        [[DataHub shared] getDefaultChartTemplate:^(ChartTemplateModel *defaultTemplate) {
                            if (defaultTemplate) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self applyTemplate:defaultTemplate];
                                });
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

#pragma mark - Helper Methods - AGGIORNATI




- (NSArray<NSDictionary *> *)extractChildIndicatorsFromPanel:(ChartPanelView *)panelView {
    
    // ✅ STEP 1: Get indicator renderer from panel
    ChartIndicatorRenderer *renderer = panelView.indicatorRenderer;
    if (!renderer) {
        NSLog(@"⚠️ No indicator renderer found in panel %@", panelView.panelType);
        return @[];
    }
    
    // ✅ STEP 2: Get root indicator from renderer
    TechnicalIndicatorBase *rootIndicator = renderer.rootIndicator;
    if (!rootIndicator) {
        NSLog(@"⚠️ No root indicator found in renderer for panel %@", panelView.panelType);
        return @[];
    }
    
    // ✅ STEP 3: Extract child indicators from root indicator
    NSArray<TechnicalIndicatorBase *> *childIndicators = rootIndicator.childIndicators;
    if (!childIndicators || childIndicators.count == 0) {
        NSLog(@"📝 No child indicators found in panel %@", panelView.panelType);
        return @[];
    }
    
    NSLog(@"🔍 Found %ld child indicators in panel %@",
          (long)childIndicators.count, panelView.panelType);
    
    // ✅ STEP 4: Convert child indicators to serializable data
    NSMutableArray<NSDictionary *> *childIndicatorsData = [[NSMutableArray alloc] init];
    
    for (TechnicalIndicatorBase *childIndicator in childIndicators) {
        // ✅ Create serializable dictionary for each child indicator
        NSDictionary *childData = @{
            @"indicatorID": NSStringFromClass([childIndicator class]),
            @"instanceID": childIndicator.indicatorID ?: [[NSUUID UUID] UUIDString],
            @"parameters": childIndicator.parameters ?: @{},
            @"isVisible": @(childIndicator.isVisible),
            @"displayOrder": @([childIndicators indexOfObject:childIndicator])
        };
        
        [childIndicatorsData addObject:childData];
        
        NSLog(@"   💾 Serialized child: %@ (visible: %@)",
              childData[@"indicatorID"], childData[@"isVisible"]);
    }
    
    return [childIndicatorsData copy];
}

- (NSString *)rootIndicatorTypeForPanelType:(NSString *)panelType {
    if ([panelType isEqualToString:@"security"]) {
        return @"SecurityIndicator";
    } else if ([panelType isEqualToString:@"volume"]) {
        return @"VolumeIndicator";
    } else {
        // Per altri tipi di pannello, potrebbe essere necessario determinare
        // il tipo di root indicator dalla configurazione esistente
        return @"OscillatorIndicator";
    }
}

// ✅ AGGIORNATO per ChartTemplateModel
- (void)handleTemplateApplicationError:(NSError *)error template:(ChartTemplateModel *)template {
    NSLog(@"❌ Template application error for '%@': %@", template.templateName, error.localizedDescription);
    
    NSString *errorMessage = [NSString stringWithFormat:@"Failed to apply template: %@", error.localizedDescription];
    [self showErrorAlert:@"Template Application Failed" message:errorMessage];
    
    // ✅ Try to fallback to default template using new API
    [[DataHub shared] getDefaultChartTemplate:^(ChartTemplateModel *defaultTemplate) {
        if (defaultTemplate) {
            NSLog(@"🔄 Falling back to default template");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self applyTemplate:defaultTemplate];
                [self showTemporaryMessage:@"Reverted to default template"];
            });
        }
    }];
}

#pragma mark - UI Helpers

- (void)updateIndicatorsPanel {
    if (!self.indicatorsPanel) {
        NSLog(@"⚠️ Indicators panel not available for update");
        return;
    }
    
    // ✅ Load available templates first using runtime models
    if (self.availableTemplates.count > 0) {
        [self.indicatorsPanel loadAvailableTemplates:self.availableTemplates];
    }
    
    // ✅ Select current template if available using runtime model
    if (self.currentChartTemplate) {
        [self.indicatorsPanel selectTemplate:self.currentChartTemplate];
    }
    
    NSLog(@"🔄 Indicators panel updated with current runtime template: %@",
          self.currentChartTemplate.templateName ?: @"None");
}

- (void)showErrorAlert:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = title;
        alert.informativeText = message;
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    });
}


// ✅ AGGIORNATO signature per ChartTemplateModel
- (void)renameTemplate:(ChartTemplateModel *)template {
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
        
        // ✅ Create updated template with new name
        ChartTemplateModel *renamedTemplate = [template createWorkingCopy];
        renamedTemplate.templateName = input.stringValue;
        renamedTemplate.modifiedDate = [NSDate date];
        
        // ✅ Save using new API
        [[DataHub shared] saveChartTemplate:renamedTemplate completion:^(BOOL success, ChartTemplateModel *savedTemplate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
                    [self showErrorAlert:@"Rename Failed" message:@"Could not rename template"];
                } else {
                    NSLog(@"✅ Runtime template renamed to: %@", input.stringValue);
                    
                    // Refresh template list
                    [self loadAvailableTemplates];
                    
                    // Show success feedback
                    [self showTemporaryMessage:[NSString stringWithFormat:@"Template renamed to '%@'", input.stringValue]];
                }
            });
        }];
    }
}

// ✅ AGGIORNATO per ChartTemplateModel
- (void)exportTemplate:(ChartTemplateModel *)template {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"json"];
    savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@.json", template.templateName];
    
    NSModalResponse response = [savePanel runModal];
    if (response == NSModalResponseOK) {
        
        // ✅ Export using new API
        [[DataHub shared] exportChartTemplate:template completion:^(BOOL success, NSData *jsonData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success && jsonData) {
                    BOOL writeSuccess = [jsonData writeToURL:savePanel.URL atomically:YES];
                    if (writeSuccess) {
                        [self showTemporaryMessage:@"Template exported successfully"];
                        NSLog(@"✅ Runtime template exported: %@", template.templateName);
                    } else {
                        [self showErrorAlert:@"Export Error" message:@"Failed to write template file"];
                    }
                } else {
                    [self showErrorAlert:@"Export Error" message:@"Failed to export template"];
                }
            });
        }];
    }
}

#pragma mark - Additional Helper Methods

- (void)removeExistingPanelsFromSplitView {
    NSLog(@"🧹 Removing %ld existing panels...", (long)self.chartPanels.count);
    
    // Remove panels from split view
    for (ChartPanelView *panel in self.chartPanels) {
        [panel removeFromSuperview];
    }
    
    // Clear the array
    [self.chartPanels removeAllObjects];
    
    // Reset renderers dictionary
    [self.indicatorRenderers removeAllObjects];
    
    // ✅ ALTERNATIVE: Remove ALL subviews from split view to be sure
    NSArray *allSubviews = [self.panelsSplitView.subviews copy];
    for (NSView *subview in allSubviews) {
        [subview removeFromSuperview];
        NSLog(@"🧹 Removed subview: %@", NSStringFromClass(subview.class));
    }
    
    NSLog(@"✅ Existing panels and placeholder removed from split view");
}


- (void)setupRenderersForAllPanels {
    NSLog(@"🎨 Setting up renderers for all panels...");
    
    for (ChartPanelView *panel in self.chartPanels) {
        // ✅ Setup indicator renderer
        [self setupIndicatorRendererForPanel:panel];
        
        // ✅ Setup objects renderer (only for security panel)
        if ([panel.panelType isEqualToString:@"security"]) {
            if (!panel.objectRenderer) {
                [panel setupObjectsRendererWithManager:self.objectsManager];
                NSLog(@"🔧 Setup objects renderer for security panel");
            }
        }
        
        // ✅ Setup alert renderer (only for security panel)
        if ([panel.panelType isEqualToString:@"security"]) {
            if (!panel.alertRenderer) {
                [panel setupAlertRenderer];
                NSLog(@"🚨 Setup alert renderer for security panel");
            }
        }
    }
    
    NSLog(@"✅ All renderers setup completed");
}

- (void)setupIndicatorRendererForPanel:(ChartPanelView *)panelView {
    if (!panelView) {
        NSLog(@"⚠️ Cannot setup indicator renderer - panel view is nil");
        return;
    }
    
    // Generate unique key for this panel
    NSString *panelKey = [NSString stringWithFormat:@"%@_%p", panelView.panelType, (void *)panelView];
    
    // Create renderer if it doesn't exist
    ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelKey];
    if (!renderer) {
        renderer = [[ChartIndicatorRenderer alloc] initWithPanelView:panelView];
        self.indicatorRenderers[panelKey] = renderer;
        NSLog(@"🎨 Created indicator renderer for panel: %@", panelView.panelType);
    } else {
        NSLog(@"♻️ Reusing existing indicator renderer for panel: %@", panelView.panelType);
    }
}

- (void)updateIndicatorsWithChartData:(NSArray<HistoricalBarModel *> *)chartData {
    if (!chartData || chartData.count == 0) {
        NSLog(@"⚠️ No chart data available for indicators update");
        return;
    }
    
    NSLog(@"🔄 Updating indicators with %ld data points...", (long)chartData.count);
    
    // ✅ Update all indicator renderers
    for (NSString *panelKey in self.indicatorRenderers.allKeys) {
        ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelKey];
        [renderer invalidateIndicatorLayers];
        NSLog(@"📊 Updated indicators for panel: %@", panelKey);
    }
    
    NSLog(@"✅ All indicators updated with new data");
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
    
    // ✅ SIMPLIFIED: Use existing ChartWidget method that now handles indicators automatically
    [self synchronizePanels];
    
    // ✅ REMOVED: Manual indicator refresh - now automatic
    // ❌ LEGACY: [self refreshIndicatorsRendering]; // ← NOT NEEDED ANYMORE
    
    NSLog(@"✅ All panels updated with current data (%ld bars) - indicators included automatically",
          (long)self.currentChartData.count);
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


- (void)recalculateAllIndicators {
    NSLog(@"🧮 Starting indicator recalculation for all panels");
    
    // ✅ STEP 1: Ottieni i dati correnti (potrebbero essere appena cambiati)
    NSArray<HistoricalBarModel *> *currentData = [self valueForKey:@"chartData"]; // Usa KVC per accedere ai dati privati
    
    if (!currentData || currentData.count == 0) {
        NSLog(@"⚠️ No chart data available for indicator recalculation");
        return;
    }
    
    NSLog(@"📊 Recalculating indicators with %ld bars of data", (long)currentData.count);
    
    // ✅ STEP 2: Recalcola TUTTI gli indicatori per ogni panel
    NSInteger recalculatedCount = 0;
    
    for (NSString *panelID in self.indicatorRenderers.allKeys) {
        ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelID];
        
        if (!renderer.rootIndicator) {
            NSLog(@"⚠️ Panel %@ has no root indicator to recalculate", panelID);
            continue;
        }
        
        NSLog(@"🧮 Recalculating indicators for panel: %@", panelID);
        
        @try {
            // ✅ RECALCULATE ROOT INDICATOR con i nuovi dati
            [renderer.rootIndicator calculateWithBars:currentData];
            NSLog(@"✅ Recalculated root indicator: %@", renderer.rootIndicator.shortName);
            
            // ✅ RECALCULATE ALL CHILD INDICATORS ricorsivamente
            for (TechnicalIndicatorBase *childIndicator in renderer.rootIndicator.childIndicators) {
                [self recalculateIndicatorRecursively:childIndicator withData:currentData];
            }
            
            // ✅ STEP 3: Marca che serve re-rendering
            [renderer markAllIndicatorsForRerendering];
            
            // ✅ STEP 4: Force immediate re-rendering
            [renderer renderIndicatorTree:renderer.rootIndicator];
            
            recalculatedCount++;
            NSLog(@"✅ Panel %@ indicators recalculated and re-rendered", panelID);
            
        } @catch (NSException *exception) {
            NSLog(@"❌ Failed to recalculate indicators for panel %@: %@", panelID, exception.reason);
        }
    }
    
    NSLog(@"🎯 Indicator recalculation completed - %ld panels processed", (long)recalculatedCount);
}

- (void)recalculateIndicatorRecursively:(TechnicalIndicatorBase *)indicator
                                withData:(NSArray<HistoricalBarModel *> *)chartData {
    @try {
        // Calcola l'indicatore figlio
        [indicator calculateWithBars:chartData];
        NSLog(@"  ✅ Recalculated child indicator: %@", indicator.shortName);
        
        // Ricorsivo per i suoi figli
        for (TechnicalIndicatorBase *grandChild in indicator.childIndicators) {
            [self recalculateIndicatorRecursively:grandChild withData:chartData];
        }
        
    } @catch (NSException *exception) {
        NSLog(@"  ❌ Failed to recalculate child indicator %@: %@", indicator.shortName, exception.reason);
    }
}


// ✅ METODO AGGIUNTIVO: Per forzare recalcolo con dati specifici
- (void)recalculateAllIndicatorsWithNewData:(NSArray<HistoricalBarModel *> *)newData {
    if (!newData || newData.count == 0) {
        NSLog(@"⚠️ No data provided for indicator recalculation");
        return;
    }
    
    NSLog(@"🧮 Force recalculating indicators with %ld new bars", (long)newData.count);
    
    for (NSString *panelID in self.indicatorRenderers.allKeys) {
        ChartIndicatorRenderer *renderer = self.indicatorRenderers[panelID];
        
        if (renderer.rootIndicator) {
            @try {
                // Calcola con i nuovi dati
                [renderer.rootIndicator calculateWithBars:newData];
                
                // Calcola i figli
                for (TechnicalIndicatorBase *child in renderer.rootIndicator.childIndicators) {
                    [self recalculateIndicatorRecursively:child withData:newData];
                }
                
                // Re-render
                [renderer markAllIndicatorsForRerendering];
                [renderer renderIndicatorTree:renderer.rootIndicator];
                
                NSLog(@"✅ Panel %@ recalculated with new data", panelID);
                
            } @catch (NSException *exception) {
                NSLog(@"❌ Failed to recalculate panel %@ with new data: %@", panelID, exception.reason);
            }
        }
    }
}

@end
