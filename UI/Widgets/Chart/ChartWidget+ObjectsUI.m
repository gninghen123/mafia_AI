//
//  ChartWidget+ObjectsUI.m
//  TradingApp
//

#import "ChartWidget+ObjectsUI.h"
#import "DataHub.h"
#import "DataHub+ChartObjects.h"
#import <objc/runtime.h>
#import "QuartzCore/QuartzCore.h"
// Associated object keys
static const void *kObjectsPanelToggleKey = &kObjectsPanelToggleKey;
static const void *kObjectsPanelKey = &kObjectsPanelKey;
static const void *kObjectsManagerKey = &kObjectsManagerKey;
static const void *kIsObjectsPanelVisibleKey = &kIsObjectsPanelVisibleKey;
static const void *kSplitViewLeadingConstraintKey = &kSplitViewLeadingConstraintKey;

@implementation ChartWidget (ObjectsUI)

#pragma mark - Associated Objects

- (NSButton *)objectsPanelToggle {
    return objc_getAssociatedObject(self, kObjectsPanelToggleKey);
}

- (void)setObjectsPanelToggle:(NSButton *)toggle {
    objc_setAssociatedObject(self, kObjectsPanelToggleKey, toggle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ObjectsPanel *)objectsPanel {
    return objc_getAssociatedObject(self, kObjectsPanelKey);
}

- (void)setObjectsPanel:(ObjectsPanel *)panel {
    objc_setAssociatedObject(self, kObjectsPanelKey, panel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ChartObjectsManager *)objectsManager {
    return objc_getAssociatedObject(self, kObjectsManagerKey);
}

- (void)setObjectsManager:(ChartObjectsManager *)manager {
    objc_setAssociatedObject(self, kObjectsManagerKey, manager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isObjectsPanelVisible {
    NSNumber *value = objc_getAssociatedObject(self, kIsObjectsPanelVisibleKey);
    return value ? [value boolValue] : NO;
}

- (void)setIsObjectsPanelVisible:(BOOL)visible {
    objc_setAssociatedObject(self, kIsObjectsPanelVisibleKey, @(visible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSLayoutConstraint *)splitViewLeadingConstraint {
    return objc_getAssociatedObject(self, kSplitViewLeadingConstraintKey);
}

- (void)setSplitViewLeadingConstraint:(NSLayoutConstraint *)constraint {
    objc_setAssociatedObject(self, kSplitViewLeadingConstraintKey, constraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Objects UI Setup

- (void)setupObjectsUI {
    // Initialize objects manager
    self.objectsManager = [ChartObjectsManager managerForSymbol:self.currentSymbol ?: @""];
    
    // Create toggle button next to symbol field
    [self createObjectsPanelToggle];
    
    // Create objects panel
    [self createObjectsPanel];
    
    // Setup constraints with sidebar pattern
    [self setupObjectsUIConstraints];
    
    NSLog(@"🎨 ChartWidget: Objects UI setup completed");
}

- (void)createObjectsPanelToggle {
    self.objectsPanelToggle = [NSButton buttonWithTitle:@"📐"
                                                target:self
                                                action:@selector(toggleObjectsPanel:)];
    self.objectsPanelToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectsPanelToggle.bezelStyle = NSBezelStyleRounded;
    self.objectsPanelToggle.toolTip = @"Show/Hide Drawing Tools";
    
    // Style simile al preferences button
    self.objectsPanelToggle.font = [NSFont systemFontOfSize:14];
    
    [self.contentView addSubview:self.objectsPanelToggle];
}

- (void)createObjectsPanel {
    self.objectsPanel = [[ObjectsPanel alloc] init];
    self.objectsPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectsPanel.delegate = self;
    
    [self.contentView addSubview:self.objectsPanel];
}

- (void)setupObjectsUIConstraints {
    // SIDEBAR PATTERN: I constraint per objectsPanel sono già definiti in setupConstraints
    // Ma il leading constraint del panelsSplitView non è memorizzato da nessuna parte
    
    NSLog(@"🔍 Searching for split view leading constraint...");
    NSLog(@"🔍 contentView constraints count: %lu", (unsigned long)self.contentView.constraints.count);
    
    // SIDEBAR PATTERN: Cerca di trovare il leading constraint del panelsSplitView
    for (NSLayoutConstraint *constraint in self.contentView.constraints) {
        NSLog(@"🔍 Constraint: %@ - firstItem: %@ - firstAttribute: %ld",
              constraint, constraint.firstItem, (long)constraint.firstAttribute);
        
        if (constraint.firstItem == self.panelsSplitView &&
            constraint.firstAttribute == NSLayoutAttributeLeading) {
            self.splitViewLeadingConstraint = constraint;
            NSLog(@"✅ Found split view leading constraint: %@", constraint);
            break;
        }
    }
    
    // FALLBACK: Se non trovato, devo controllare se il constraint è attivo
    // ma non è nei constraints di contentView (potrebbe essere nell'autoActivateConstraints)
    if (!self.splitViewLeadingConstraint) {
        NSLog(@"⚠️ Split view leading constraint not found in contentView.constraints");
        NSLog(@"🔧 Creating new leading constraint for sidebar pattern");
        
        // Prima devo disattivare eventuali constraint esistenti conflittuali
        NSLayoutConstraint *existingConstraint = nil;
        for (NSLayoutConstraint *constraint in self.panelsSplitView.superview.constraints) {
            if (constraint.firstItem == self.panelsSplitView &&
                constraint.firstAttribute == NSLayoutAttributeLeading) {
                existingConstraint = constraint;
                break;
            }
        }
        
        if (existingConstraint) {
            NSLog(@"🔧 Deactivating existing constraint: %@", existingConstraint);
            existingConstraint.active = NO;
        }
        
   
        NSLog(@"✅ Created new split view leading constraint: %@", self.splitViewLeadingConstraint);
    }
    
    NSLog(@"🎨 ChartWidget: Objects UI constraints configured with sidebar pattern - leading: %.1f",
          self.splitViewLeadingConstraint.constant);
}

#pragma mark - Objects Panel Actions

- (void)toggleObjectsPanel:(id)sender {
    [self.objectsPanel toggleVisibilityAnimated:YES];
    
    // Update toggle button state
    self.isObjectsPanelVisible = self.objectsPanel.isVisible;
    
    if (self.isObjectsPanelVisible) {
        self.objectsPanelToggle.state = NSControlStateValueOn;
    } else {
        self.objectsPanelToggle.state = NSControlStateValueOff;
    }
    
    // SIDEBAR PATTERN: Adjust main split view position
    [self adjustMainSplitViewForObjectsPanel];
    
    NSLog(@"🎨 Objects panel toggled: %@", self.isObjectsPanelVisible ? @"VISIBLE" : @"HIDDEN");
}

- (void)adjustMainSplitViewForObjectsPanel {
    // SIDEBAR PATTERN: Anima solo il leading constraint del content area
  
    if (!self.splitViewLeadingConstraint) {
        return;
    }
    
    CGFloat currentConstant = self.splitViewLeadingConstraint.constant;
    CGFloat targetConstant = self.isObjectsPanelVisible ?
        (8 + self.objectsPanel.panelWidth + 8) :  // Panel width + margins
        14; // Original offset
        
    NSLog(@"🎬 Animating split view leading: %.1f -> %.1f (panel %@)",
          currentConstant, targetConstant, self.isObjectsPanelVisible ? @"VISIBLE" : @"HIDDEN");
    NSLog(@"🎬 Split view constraint: %@", self.splitViewLeadingConstraint);
    NSLog(@"🎬 Split view frame before: %@", NSStringFromRect(self.panelsSplitView.frame));
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.25;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        context.allowsImplicitAnimation = YES;
        
        // Forza l'animazione del constraint
        [[self.splitViewLeadingConstraint animator] setConstant:targetConstant];
        
        // Forza il layout update
        [[self.contentView animator] layoutSubtreeIfNeeded];
        
    } completionHandler:^{
        NSLog(@"🎬 Split view animation completed");
        NSLog(@"🎬 Final constraint constant: %.1f", self.splitViewLeadingConstraint.constant);
        NSLog(@"🎬 Final split view frame: %@", NSStringFromRect(self.panelsSplitView.frame));
    }];
}

- (void)showObjectManager:(id)sender {
    NSLog(@"🎨 ChartWidget: Show Object Manager requested");
    // TODO: Implement ObjectManagerWindow
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Object Manager";
    alert.informativeText = @"Object Manager window will be implemented in the next phase.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

#pragma mark - ObjectsPanelDelegate

- (void)objectsPanel:(id)panel didRequestCreateObjectOfType:(ChartObjectType)type {
    NSLog(@"🎨 ChartWidget: Create object of type %ld requested", (long)type);
    
    // Create object in active layer
    ChartLayerModel *activeLayer = self.objectsManager.activeLayer;
    if (!activeLayer) {
        // Create default layer if none exists
        activeLayer = [self.objectsManager createLayerWithName:@"Analysis"];
    }
    
    ChartObjectModel *newObject = [self.objectsManager createObjectOfType:type inLayer:activeLayer];
    
    NSLog(@"✅ Created chart object: %@ (%@)", newObject.name, newObject.objectID);
    
    // Start interactive placement mode
    [self startObjectPlacementMode:newObject];
}

- (void)objectsPanelDidRequestShowManager:(id)panel {
    [self showObjectManager:panel];
}

- (void)objectsPanel:(id)panel didChangeVisibility:(BOOL)isVisible {
    self.isObjectsPanelVisible = isVisible;
    NSLog(@"🎨 ChartWidget: Objects panel visibility changed to %@", isVisible ? @"VISIBLE" : @"HIDDEN");
}

#pragma mark - Object Placement Mode (Placeholder)

- (void)startObjectPlacementMode:(ChartObjectModel *)object {
    NSLog(@"🎯 Starting placement mode for object: %@", object.name);
    // TODO: Implement interactive object placement
    // This will involve:
    // 1. Setting cursor to crosshair
    // 2. Capturing mouse events on chart panels
    // 3. Creating visual feedback during placement
    // 4. Finalizing object position on click/drag
}

@end
