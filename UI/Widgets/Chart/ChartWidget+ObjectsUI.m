//
//  ChartWidget+ObjectsUI.m
//  TradingApp
//

#import "ChartWidget+ObjectsUI.h"
#import "DataHub.h"
#import "DataHub+ChartObjects.h"
#import <objc/runtime.h>

// Associated object keys
static const void *kObjectsPanelToggleKey = &kObjectsPanelToggleKey;
static const void *kObjectsPanelKey = &kObjectsPanelKey;
static const void *kObjectsManagerKey = &kObjectsManagerKey;
static const void *kIsObjectsPanelVisibleKey = &kIsObjectsPanelVisibleKey;

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

#pragma mark - Objects UI Setup

- (void)setupObjectsUI {
    // Initialize objects manager
    self.objectsManager = [ChartObjectsManager managerForSymbol:self.currentSymbol ?: @""];
    
    // Create toggle button next to symbol field
    [self createObjectsPanelToggle];
    
    // Create objects panel
    [self createObjectsPanel];
    
    // Setup constraints
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
    // I constraint del toggle button e dell'objects panel sono già definiti
    // nel setupConstraints principale del ChartWidget
    // Qui manteniamo solo la logica specifica se necessaria
    
    NSLog(@"🎨 ChartWidget: Objects UI constraints configured");
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
    
    // Adjust main split view position
    [self adjustMainSplitViewForObjectsPanel];
    
    NSLog(@"🎨 Objects panel toggled: %@", self.isObjectsPanelVisible ? @"VISIBLE" : @"HIDDEN");
}

- (void)adjustMainSplitViewForObjectsPanel {
    // Find and update the split view leading constraint
    for (NSLayoutConstraint *constraint in self.panelsSplitView.superview.constraints) {
        if (constraint.firstItem == self.panelsSplitView &&
            constraint.firstAttribute == NSLayoutAttributeLeading) {
            
            constraint.constant = self.isObjectsPanelVisible ?
                (8 + self.objectsPanel.panelWidth + 8) :  // Panel width + margins
                14; // Original offset
            break;
        }
    }
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.25;
        context.allowsImplicitAnimation = YES;
        [self.contentView layoutSubtreeIfNeeded];
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

#pragma mark - Object Placement

- (void)startObjectPlacementMode:(ChartObjectModel *)object {
    NSLog(@"🎯 Starting placement mode for object: %@", object.name);
    
    // Set object as selected
    [self.objectsManager selectObject:object];
    
    // TODO: Set chart panels to placement mode
    // This will be implemented when we add the object layer to ChartPanelView
    
    // For now, just add a default control point for demonstration
    NSDate *currentDate = [NSDate date];
    ControlPointModel *point = [ControlPointModel pointWithDate:currentDate
                                                    valuePercent:0.5
                                                       indicator:@"close"];
    [object addControlPoint:point];
    
    // Save to DataHub
    ChartLayerModel *layer = self.objectsManager.activeLayer;
    if (layer) {
        [[DataHub shared] saveChartObject:object toLayerID:layer.layerID];
    }
    
    NSLog(@"📍 Added default control point and saved object");
}

@end
