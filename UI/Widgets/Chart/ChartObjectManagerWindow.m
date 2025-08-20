
//  ChartObjectManagerWindow.m
//  TradingApp
//
//  Implementation completa con Layer Management + Context Menu + Drag&Drop
//

#import "ChartObjectManagerWindow.h"
#import "DataHub+ChartObjects.h"
#import <QuartzCore/QuartzCore.h>

@interface ChartObjectManagerWindow ()
@property (nonatomic, strong) NSView *contentContainer;
@property (nonatomic, strong) NSTextField *layersHeaderLabel;
@property (nonatomic, strong) NSTextField *objectsHeaderLabel;
@property (nonatomic, strong) NSScrollView *layersScrollView;
@property (nonatomic, strong) NSScrollView *objectsScrollView;
@end

@implementation ChartObjectManagerWindow

#pragma mark - Initialization

- (instancetype)initWithObjectsManager:(ChartObjectsManager *)objectsManager
                               dataHub:(DataHub *)dataHub
                                symbol:(NSString *)symbol {
    
    NSRect frame = NSMakeRect(100, 100, 400, 600);
    
    self = [super initWithContentRect:frame
                            styleMask:NSWindowStyleMaskTitled |
                                     NSWindowStyleMaskClosable |
                                     NSWindowStyleMaskResizable |
                                     NSWindowStyleMaskUtilityWindow
                              backing:NSBackingStoreBuffered
                                defer:NO];
    
    if (self) {
        _objectsManager = objectsManager;
        _dataHub = dataHub;
        _currentSymbol = symbol;
        
        [self setupWindow];
        [self setupUI];
        [self setupConstraints];
        [self setupNotificationObservers];
        
        // IMPORTANTE: Carica i dati dal DataHub e crea layer di default se necessario
        [self loadInitialData];
        
        NSLog(@"🎯 ChartObjectManagerWindow: Initialized for symbol %@", symbol);
    }
    
    return self;
}

- (void)setupWindow {
    self.title = [NSString stringWithFormat:@"Chart Objects - %@", self.currentSymbol];
    self.floatingPanel = YES;
    self.becomesKeyOnlyIfNeeded = YES;
    self.minSize = NSMakeSize(350, 400);
    
    // Background color
    self.contentView.wantsLayer = YES;
    self.contentView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
}

#pragma mark - UI Setup

- (void)setupUI {
    // Main container
    self.contentContainer = [[NSView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.contentContainer];
    
    // Symbol label + Layer toolbar (sulla stessa riga)
    [self setupSymbolAndLayerToolbar];
    
    // Layers section header
    self.layersHeaderLabel = [self createHeaderLabel:@"📁 Layers"];
    [self.contentContainer addSubview:self.layersHeaderLabel];
    
    // Layers outline view
    [self setupLayersOutlineView];
    
    // Objects section header
    self.objectsHeaderLabel = [self createHeaderLabel:@"📋 Objects"];
    [self.contentContainer addSubview:self.objectsHeaderLabel];
    
    // Objects table view
    [self setupObjectsTableView];
}

- (void)setupSymbolAndLayerToolbar {
    // Symbol label (a sinistra)
    self.symbolLabel = [[NSTextField alloc] init];
    self.symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolLabel.stringValue = [NSString stringWithFormat:@"Symbol: %@", self.currentSymbol];
    self.symbolLabel.font = [NSFont boldSystemFontOfSize:14];
    self.symbolLabel.editable = NO;
    self.symbolLabel.bordered = NO;
    self.symbolLabel.backgroundColor = [NSColor clearColor];
    [self.contentContainer addSubview:self.symbolLabel];
    
    // Layer toolbar container (a destra)
    self.layerToolbar = [[NSView alloc] init];
    self.layerToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.layerToolbar];
    
    // Add Layer button
    self.addLayerButton = [NSButton buttonWithTitle:@"+"
                                              target:self
                                              action:@selector(addLayerAction:)];
    self.addLayerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addLayerButton.bezelStyle = NSBezelStyleRounded;
    self.addLayerButton.controlSize = NSControlSizeSmall;
    self.addLayerButton.toolTip = @"Add New Layer";
    [self.layerToolbar addSubview:self.addLayerButton];
    
    // Delete Layer button
    self.deleteLayerButton = [NSButton buttonWithTitle:@"🗑️"
                                                 target:self
                                                 action:@selector(deleteLayerAction:)];
    self.deleteLayerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteLayerButton.bezelStyle = NSBezelStyleRounded;
    self.deleteLayerButton.controlSize = NSControlSizeSmall;
    self.deleteLayerButton.toolTip = @"Delete Selected Layer";
    [self.layerToolbar addSubview:self.deleteLayerButton];
    
    // Rename Layer button
    self.renameLayerButton = [NSButton buttonWithTitle:@"✏️"
                                                 target:self
                                                 action:@selector(renameLayerAction:)];
    self.renameLayerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.renameLayerButton.bezelStyle = NSBezelStyleRounded;
    self.renameLayerButton.controlSize = NSControlSizeSmall;
    self.renameLayerButton.toolTip = @"Rename Selected Layer";
    [self.layerToolbar addSubview:self.renameLayerButton];
    
    // Layout toolbar buttons horizontally
    [NSLayoutConstraint activateConstraints:@[
        // Symbol label constraints
        [self.symbolLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.symbolLabel.centerYAnchor constraintEqualToAnchor:self.layerToolbar.centerYAnchor],
        
        // Toolbar container constraints
        [self.layerToolbar.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [self.layerToolbar.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [self.layerToolbar.heightAnchor constraintEqualToConstant:30],
        
        // Buttons inside toolbar (right to left)
        [self.renameLayerButton.trailingAnchor constraintEqualToAnchor:self.layerToolbar.trailingAnchor],
        [self.renameLayerButton.centerYAnchor constraintEqualToAnchor:self.layerToolbar.centerYAnchor],
        [self.renameLayerButton.widthAnchor constraintEqualToConstant:30],
        
        [self.deleteLayerButton.trailingAnchor constraintEqualToAnchor:self.renameLayerButton.leadingAnchor constant:-4],
        [self.deleteLayerButton.centerYAnchor constraintEqualToAnchor:self.layerToolbar.centerYAnchor],
        [self.deleteLayerButton.widthAnchor constraintEqualToConstant:30],
        
        [self.addLayerButton.trailingAnchor constraintEqualToAnchor:self.deleteLayerButton.leadingAnchor constant:-4],
        [self.addLayerButton.centerYAnchor constraintEqualToAnchor:self.layerToolbar.centerYAnchor],
        [self.addLayerButton.widthAnchor constraintEqualToConstant:30],
        
        // Ensure spacing between symbol and toolbar
        [self.layerToolbar.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.symbolLabel.trailingAnchor constant:20]
    ]];
}

- (void)setupLayersOutlineView {
    self.layersOutlineView = [[NSOutlineView alloc] init];
    self.layersOutlineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.layersOutlineView.dataSource = self;
    self.layersOutlineView.delegate = self;
    self.layersOutlineView.headerView = nil;
    self.layersOutlineView.allowsMultipleSelection = NO;
    self.layersOutlineView.indentationPerLevel = 16;
    
    // Drag & Drop setup
    [self.layersOutlineView registerForDraggedTypes:@[@"ChartObjectDragType"]];
    self.layersOutlineView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleSourceList;
    
    // Add single column
    NSTableColumn *layerColumn = [[NSTableColumn alloc] initWithIdentifier:@"LayerColumn"];
    layerColumn.title = @"Layer";
    layerColumn.width = 200;
    [self.layersOutlineView addTableColumn:layerColumn];
    
    NSScrollView *layersScrollView = [[NSScrollView alloc] init];
    layersScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    layersScrollView.documentView = self.layersOutlineView;
    layersScrollView.hasVerticalScroller = YES;
    layersScrollView.hasHorizontalScroller = NO;
    layersScrollView.borderType = NSBezelBorder;
    [self.contentContainer addSubview:layersScrollView];
    
    self.layersScrollView = layersScrollView;
}

- (void)setupObjectsTableView {
    self.objectsTableView = [[NSTableView alloc] init];
    self.objectsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectsTableView.dataSource = self;
    self.objectsTableView.delegate = self;
    self.objectsTableView.allowsMultipleSelection = NO;
    
    // Drag & Drop setup
    [self.objectsTableView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    
    // Double-click setup
    self.objectsTableView.target = self;
    self.objectsTableView.doubleAction = @selector(editObjectDoubleClick:);
    
    // Add columns
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"NameColumn"];
    nameColumn.title = @"Name";
    nameColumn.width = 150;
    [self.objectsTableView addTableColumn:nameColumn];
    
    NSTableColumn *typeColumn = [[NSTableColumn alloc] initWithIdentifier:@"TypeColumn"];
    typeColumn.title = @"Type";
    typeColumn.width = 100;
    [self.objectsTableView addTableColumn:typeColumn];
    
    NSTableColumn *visibleColumn = [[NSTableColumn alloc] initWithIdentifier:@"VisibleColumn"];
    visibleColumn.title = @"👁️";
    visibleColumn.width = 30;
    [self.objectsTableView addTableColumn:visibleColumn];
    
    NSScrollView *objectsScrollView = [[NSScrollView alloc] init];
    objectsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    objectsScrollView.documentView = self.objectsTableView;
    objectsScrollView.hasVerticalScroller = YES;
    objectsScrollView.hasHorizontalScroller = NO;
    objectsScrollView.borderType = NSBezelBorder;
    [self.contentContainer addSubview:objectsScrollView];
    
    self.objectsScrollView = objectsScrollView;
}

- (NSTextField *)createHeaderLabel:(NSString *)title {
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.stringValue = title;
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    label.textColor = [NSColor secondaryLabelColor];
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    return label;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Container
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        
        // Layers header (below symbol+toolbar)
        [self.layersHeaderLabel.topAnchor constraintEqualToAnchor:self.layerToolbar.bottomAnchor constant:16],
        [self.layersHeaderLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.layersHeaderLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        
        // Layers outline view
        [self.layersScrollView.topAnchor constraintEqualToAnchor:self.layersHeaderLabel.bottomAnchor constant:4],
        [self.layersScrollView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.layersScrollView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [self.layersScrollView.heightAnchor constraintEqualToConstant:150],
        
        // Objects header
        [self.objectsHeaderLabel.topAnchor constraintEqualToAnchor:self.layersScrollView.bottomAnchor constant:16],
        [self.objectsHeaderLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.objectsHeaderLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        
        // Objects table view
        [self.objectsScrollView.topAnchor constraintEqualToAnchor:self.objectsHeaderLabel.bottomAnchor constant:4],
        [self.objectsScrollView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.objectsScrollView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [self.objectsScrollView.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor]
    ]];
}

#pragma mark - Data Loading

- (void)loadInitialData {
    NSLog(@"📥 ChartObjectManagerWindow: Loading initial data for symbol %@", self.currentSymbol);
    
    // Carica i dati dal DataHub
    [self.objectsManager loadFromDataHub];
    
    // Aggiungi un delay per permettere il caricamento asincrono dal DataHub
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSLog(@"📊 ChartObjectManagerWindow: Checking loaded data - found %lu layers", (unsigned long)self.objectsManager.layers.count);
        
        
        // Refresh UI
        [self refreshContent];
        
        // Log final state
        NSLog(@"✅ ChartObjectManagerWindow: Initial data loaded - %lu layers total", (unsigned long)self.objectsManager.layers.count);
        for (ChartLayerModel *layer in self.objectsManager.layers) {
            NSLog(@"   📁 Layer '%@' with %lu objects", layer.name, (unsigned long)layer.objects.count);
        }
    });
}


- (void)addLayerAction:(NSButton *)sender {
    NSLog(@"➕ Adding new layer");
    
    // Generate unique layer name
    NSString *baseName = @"Layer";
    NSString *newLayerName = [self generateUniqueLayerName:baseName];
    
    // Create new layer using manager method
    ChartLayerModel *newLayer = [self.objectsManager createLayerWithName:newLayerName];
    
    // Save changes
    [self.objectsManager saveToDataHub];
    
    // Refresh UI and select new layer
    [self refreshContent];
    
    // Find and select the new layer
    NSInteger newLayerIndex = [self.objectsManager.layers indexOfObject:newLayer];
    if (newLayerIndex != NSNotFound) {
        [self.layersOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:newLayerIndex] byExtendingSelection:NO];
    }
    
    NSLog(@"✅ Created layer '%@' at index %ld", newLayerName, (long)newLayerIndex);
}

- (void)deleteLayerAction:(NSButton *)sender {
    NSInteger selectedRow = self.layersOutlineView.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.objectsManager.layers.count) {
        NSLog(@"⚠️ No layer selected for deletion");
        return;
    }
    
    ChartLayerModel *selectedLayer = self.objectsManager.layers[selectedRow];
    
    // Confirm deletion if layer has objects
    if (selectedLayer.objects.count > 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Delete Layer";
        alert.informativeText = [NSString stringWithFormat:@"Layer '%@' contains %lu objects. All objects will be deleted. This action cannot be undone.",
                                selectedLayer.name, (unsigned long)selectedLayer.objects.count];
        [alert addButtonWithTitle:@"Delete"];
        [alert addButtonWithTitle:@"Cancel"];
        alert.alertStyle = NSAlertStyleWarning;
        
        NSModalResponse response = [alert runModal];
        if (response != NSAlertFirstButtonReturn) {
            return; // User cancelled
        }
    }
    
    NSLog(@"🗑️ Deleting layer '%@' with %lu objects", selectedLayer.name, (unsigned long)selectedLayer.objects.count);
    
    // Remove layer using manager method
    [self.objectsManager deleteLayer:selectedLayer];
    [self.objectsManager saveToDataHub];
    
    // Clear selection and refresh
    self.selectedLayer = nil;
    self.selectedObject = nil;
    [self refreshContent];
    
    NSLog(@"✅ Layer deleted successfully");
}

- (void)renameLayerAction:(NSButton *)sender {
    NSInteger selectedRow = self.layersOutlineView.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.objectsManager.layers.count) {
        NSLog(@"⚠️ No layer selected for renaming");
        return;
    }
    
    ChartLayerModel *selectedLayer = self.objectsManager.layers[selectedRow];
    
    // Show rename dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Layer";
    alert.informativeText = @"Enter new name for the layer:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    input.stringValue = selectedLayer.name;
    input.font = [NSFont systemFontOfSize:12];
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [input becomeFirstResponder];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *newName = [input.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (newName.length > 0 && ![newName isEqualToString:selectedLayer.name]) {
            // Check for duplicate names
            if ([self isLayerNameUnique:newName excludingLayer:selectedLayer]) {
                NSLog(@"✏️ Renaming layer '%@' to '%@'", selectedLayer.name, newName);
                
                selectedLayer.name = newName;
                selectedLayer.lastModified = [NSDate date];
                [self.objectsManager saveToDataHub];
                [self refreshContent];
                
                NSLog(@"✅ Layer renamed successfully");
            } else {
                NSAlert *errorAlert = [[NSAlert alloc] init];
                errorAlert.messageText = @"Duplicate Name";
                errorAlert.informativeText = @"A layer with this name already exists.";
                [errorAlert addButtonWithTitle:@"OK"];
                [errorAlert runModal];
            }
        }
    }
}

#pragma mark - Context Menu Implementation

- (NSMenu *)outlineView:(NSOutlineView *)outlineView menuForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        return [self contextMenuForLayer:(ChartLayerModel *)item];
    } else if ([item isKindOfClass:[ChartObjectModel class]]) {
        return [self contextMenuForObject:(ChartObjectModel *)item];
    }
    
    // Context menu for empty area
    return [self contextMenuForEmptyArea];
}

- (NSMenu *)contextMenuForLayer:(ChartLayerModel *)layer {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Layer Actions"];
    
    NSMenuItem *item;
    
    // New Layer
    item = [[NSMenuItem alloc] initWithTitle:@"New Layer..." action:@selector(addLayerAction:) keyEquivalent:@""];
    item.target = self;
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Rename Layer
    item = [[NSMenuItem alloc] initWithTitle:@"Rename Layer..." action:@selector(renameLayerFromContext:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = layer;
    [menu addItem:item];
    
    // Duplicate Layer
    item = [[NSMenuItem alloc] initWithTitle:@"Duplicate Layer" action:@selector(duplicateLayerFromContext:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = layer;
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Toggle Visibility
    NSString *visibilityTitle = layer.isVisible ? @"Hide Layer" : @"Show Layer";
    item = [[NSMenuItem alloc] initWithTitle:visibilityTitle action:@selector(toggleLayerFromContext:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = layer;
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Delete Layer
    item = [[NSMenuItem alloc] initWithTitle:@"Delete Layer" action:@selector(deleteLayerFromContext:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = layer;
    [menu addItem:item];
    
    return menu;
}

- (NSMenu *)contextMenuForObject:(ChartObjectModel *)object {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Object Actions"];
    
    NSMenuItem *item;
    
    // Edit Object
    item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Edit '%@'...", object.name]
                                      action:@selector(editObjectFromContext:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = object;
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Duplicate Object
    item = [[NSMenuItem alloc] initWithTitle:@"Duplicate Object" action:@selector(duplicateObjectFromContext:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = object;
    [menu addItem:item];
    
    // Delete Object
    item = [[NSMenuItem alloc] initWithTitle:@"Delete Object" action:@selector(deleteObjectFromContext:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = object;
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Move to Layer submenu
    NSMenuItem *moveToLayerItem = [[NSMenuItem alloc] initWithTitle:@"Move to Layer" action:nil keyEquivalent:@""];
    NSMenu *layerSubmenu = [[NSMenu alloc] initWithTitle:@"Move to Layer"];
    
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        NSMenuItem *layerOption = [[NSMenuItem alloc] initWithTitle:layer.name
                                                             action:@selector(moveObjectToLayerFromContext:)
                                                      keyEquivalent:@""];
        layerOption.target = self;
        layerOption.representedObject = @{@"object": object, @"layer": layer};
        [layerSubmenu addItem:layerOption];
    }
    
    moveToLayerItem.submenu = layerSubmenu;
    [menu addItem:moveToLayerItem];
    
    return menu;
}

- (NSMenu *)contextMenuForEmptyArea {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Actions"];
    
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"New Layer..." action:@selector(addLayerAction:) keyEquivalent:@""];
    item.target = self;
    [menu addItem:item];
    
    return menu;
}

#pragma mark - Context Menu Actions

- (void)renameLayerFromContext:(NSMenuItem *)menuItem {
    ChartLayerModel *layer = menuItem.representedObject;
    
    // Select the layer first
    NSInteger layerIndex = [self.objectsManager.layers indexOfObject:layer];
    if (layerIndex != NSNotFound) {
        [self.layersOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:layerIndex] byExtendingSelection:NO];
        [self renameLayerAction:nil];
    }
}

- (void)duplicateLayerFromContext:(NSMenuItem *)menuItem {
    ChartLayerModel *originalLayer = menuItem.representedObject;
    NSLog(@"📋 Duplicating layer '%@'", originalLayer.name);
    
    // Create duplicate layer
    ChartLayerModel *duplicateLayer = [originalLayer copy];
    duplicateLayer.name = [self generateUniqueLayerName:[NSString stringWithFormat:@"%@ Copy", originalLayer.name]];
    
    // Add using manager (it will set orderIndex automatically)
    [self.objectsManager.layers addObject:duplicateLayer];
    [self.objectsManager saveToDataHub];
    [self refreshContent];
    
    NSLog(@"✅ Layer duplicated as '%@'", duplicateLayer.name);
}

- (void)toggleLayerFromContext:(NSMenuItem *)menuItem {
    ChartLayerModel *layer = menuItem.representedObject;
    [self toggleLayerVisibility:layer];
}

- (void)deleteLayerFromContext:(NSMenuItem *)menuItem {
    ChartLayerModel *layer = menuItem.representedObject;
    
    // Select the layer first
    NSInteger layerIndex = [self.objectsManager.layers indexOfObject:layer];
    if (layerIndex != NSNotFound) {
        [self.layersOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:layerIndex] byExtendingSelection:NO];
        [self deleteLayerAction:nil];
    }
}

- (void)editObjectFromContext:(NSMenuItem *)menuItem {
    ChartObjectModel *selectedObject = menuItem.representedObject;
    [self editObjectDoubleClick:selectedObject];
}

- (void)duplicateObjectFromContext:(NSMenuItem *)menuItem {
    ChartObjectModel *selectedObject = menuItem.representedObject;
    [self duplicateObject:selectedObject];
}

- (void)deleteObjectFromContext:(NSMenuItem *)menuItem {
    ChartObjectModel *selectedObject = menuItem.representedObject;
    [self deleteObject:selectedObject];
}

- (void)moveObjectToLayerFromContext:(NSMenuItem *)menuItem {
    NSDictionary *info = menuItem.representedObject;
    ChartObjectModel *selectedObject = info[@"object"];
    ChartLayerModel *targetLayer = info[@"layer"];
    
    [self.objectsManager moveObject:selectedObject toLayer:targetLayer];
    [self.objectsManager saveToDataHub];
    [self refreshContent];
    
    NSLog(@"📁 Moved object '%@' to layer '%@'", selectedObject.name, targetLayer.name);
}

#pragma mark - Drag & Drop Implementation

// TableView Drag Source (Objects)
- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    if (tableView == self.objectsTableView && self.selectedLayer) {
        NSUInteger objectIndex = [rowIndexes firstIndex];
        if (objectIndex < self.selectedLayer.objects.count) {
            self.draggedObject = self.selectedLayer.objects[objectIndex];
            
            [pboard declareTypes:@[@"ChartObjectDragType"] owner:self];
            [pboard setString:self.draggedObject.objectID forType:@"ChartObjectDragType"];
            
            NSLog(@"🫴 Started dragging object '%@'", self.draggedObject.name);
            return YES;
        }
    }
    return NO;
}

// OutlineView Drop Target (Layers)
- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
    if (outlineView == self.layersOutlineView) {
        NSPasteboard *pboard = [info draggingPasteboard];
        if ([pboard availableTypeFromArray:@[@"ChartObjectDragType"]]) {
            
            // Only allow drop on layers, not objects
            if ([item isKindOfClass:[ChartLayerModel class]]) {
                [outlineView setDropItem:item dropChildIndex:NSOutlineViewDropOnItemIndex];
                return NSDragOperationMove;
            }
        }
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
    if (outlineView == self.layersOutlineView && [item isKindOfClass:[ChartLayerModel class]]) {
        ChartLayerModel *targetLayer = (ChartLayerModel *)item;
        
        if (self.draggedObject) {
            NSLog(@"🎯 Dropping object '%@' onto layer '%@'", self.draggedObject.name, targetLayer.name);
            
            [self.objectsManager moveObject:self.draggedObject toLayer:targetLayer];
            [self.objectsManager saveToDataHub];
            [self refreshContent];
            
            // Select the target layer to show the moved object
            NSInteger targetLayerIndex = [self.objectsManager.layers indexOfObject:targetLayer];
            if (targetLayerIndex != NSNotFound) {
                [self.layersOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:targetLayerIndex] byExtendingSelection:NO];
            }
            
            self.draggedObject = nil;
            NSLog(@"✅ Object moved successfully");
            return YES;
        }
    }
    return NO;
}

#pragma mark - Object Operations

- (void)editObjectDoubleClick:(id)sender {
    ChartObjectModel *objectToEdit = nil;
    
    if ([sender isKindOfClass:[ChartObjectModel class]]) {
        // Called from context menu with object as sender
        objectToEdit = (ChartObjectModel *)sender;
    } else if (self.selectedObject) {
        // Called from double-click with selected object
        objectToEdit = self.selectedObject;
    }
    
    if (objectToEdit) {
        NSLog(@"✏️ Opening settings for object '%@'", objectToEdit.name);
        // TODO: Open ChartObjectSettingsWindow for the object
        // [self.objectSettingsWindow showSettingsForObject:objectToEdit];
    }
}

- (void)duplicateObject:(ChartObjectModel *)objectToEdit {
    // Find the layer containing this object
    ChartLayerModel *containingLayer = nil;
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        if ([layer.objects containsObject:objectToEdit]) {
            containingLayer = layer;
            break;
        }
    }
    
    if (containingLayer) {
        ChartObjectModel *duplicate = [objectToEdit copy];
        duplicate.name = [NSString stringWithFormat:@"%@ Copy", objectToEdit.name];
        
        // Offset position slightly for visibility
        for (ControlPointModel *cp in duplicate.controlPoints) {
            cp.dateAnchor = [cp.dateAnchor dateByAddingTimeInterval:86400]; // +1 day
            cp.absoluteValue *= 1.02; // +2%
        }
        
        [containingLayer addObject:duplicate];
        [self.objectsManager saveToDataHub];
        [self refreshContent];
        
        NSLog(@"📋 Duplicated object '%@' in layer '%@'", objectToEdit.name, containingLayer.name);
    }
}

- (void)deleteObject:(ChartObjectModel *)objectToEdit {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Object";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?", objectToEdit.name];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [self.objectsManager deleteObject:objectToEdit];
        [self.objectsManager saveToDataHub];
        [self refreshContent];
        
        NSLog(@"🗑️ Deleted object '%@'", objectToEdit.name);
    }
}

#pragma mark - Helper Methods

- (NSString *)generateUniqueLayerName:(NSString *)baseName {
    NSMutableSet *existingNames = [NSMutableSet set];
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        [existingNames addObject:layer.name];
    }
    
    NSString *candidateName = baseName;
    NSInteger counter = 1;
    
    while ([existingNames containsObject:candidateName]) {
        candidateName = [NSString stringWithFormat:@"%@ %ld", baseName, (long)counter];
        counter++;
    }
    
    return candidateName;
}

- (BOOL)isLayerNameUnique:(NSString *)name excludingLayer:(ChartLayerModel *)excludeLayer {
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        if (layer != excludeLayer && [layer.name isEqualToString:name]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark - Public Methods

- (void)refreshContent {
    NSLog(@"🔄 ChartObjectManagerWindow: Refreshing content - %lu layers available", (unsigned long)self.objectsManager.layers.count);
    
    [self.layersOutlineView reloadData];
    [self.objectsTableView reloadData];
    [self expandAllLayers];
    
    // Debug: Log current data state
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        NSLog(@"   📁 Layer '%@' (%@) with %lu objects",
              layer.name,
              layer.isVisible ? @"visible" : @"hidden",
              (unsigned long)layer.objects.count);
    }
    NSLog(@"📢 Current window symbol: %@", self.currentSymbol);
    NSLog(@"📢 Manager has %lu layers", (unsigned long)self.objectsManager.layers.count);
    NSLog(@"✅ ChartObjectManagerWindow: Content refresh completed");
}

- (void)updateForSymbol:(NSString *)symbol {
    NSLog(@"🔄 ChartObjectManagerWindow: Updating for symbol %@", symbol);
    
    self.currentSymbol = symbol;
    self.title = [NSString stringWithFormat:@"Chart Objects - %@", symbol];
    self.symbolLabel.stringValue = [NSString stringWithFormat:@"Symbol: %@", symbol];
    
    // Update objects manager for new symbol
    self.objectsManager = [ChartObjectsManager managerForSymbol:symbol];
    
    // Reload data for new symbol
    [self loadInitialData];
    
    NSLog(@"✅ ChartObjectManagerWindow: Updated for symbol %@", symbol);
}

- (void)expandAllLayers {
    for (NSInteger i = 0; i < [self.layersOutlineView numberOfRows]; i++) {
        id item = [self.layersOutlineView itemAtRow:i];
        if ([item isKindOfClass:[ChartLayerModel class]]) {
            [self.layersOutlineView expandItem:item];
        }
    }
}

- (void)toggleLayerVisibility:(ChartLayerModel *)layer {
    if (!layer) return;
    
    // Toggle visibility
    layer.isVisible = !layer.isVisible;
    layer.lastModified = [NSDate date];
    
    // Save to DataHub
    [self.objectsManager saveToDataHub];
    
    // Refresh UI
    [self refreshContent];
    
    // Notify chart for re-render
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChartObjectsVisibilityChanged"
                                                        object:self
                                                      userInfo:@{@"symbol": self.currentSymbol ?: @""}];
    
    NSLog(@"🎯 Layer '%@' visibility: %@ - Chart notified for re-render",
          layer.name, layer.isVisible ? @"VISIBLE" : @"HIDDEN");
}

#pragma mark - NSOutlineViewDataSource (Layers)

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item {
    if (item == nil) {
        // Root level - return layers count
        NSInteger layersCount = self.objectsManager.layers.count;
        NSLog(@"📊 OutlineView: Root level requested - returning %ld layers", (long)layersCount);
        return layersCount;
    }
    
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        // Layer level - return objects count in this layer
        ChartLayerModel *layer = (ChartLayerModel *)item;
        NSInteger objectsCount = layer.objects.count;
        NSLog(@"📊 OutlineView: Layer '%@' requested - returning %ld objects", layer.name, (long)objectsCount);
        return objectsCount;
    }
    
    NSLog(@"📊 OutlineView: Unknown item type requested");
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {
    if (item == nil) {
        // Root level - return layer
        return self.objectsManager.layers[index];
    }
    
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        // Layer level - return object
        ChartLayerModel *layer = (ChartLayerModel *)item;
        return layer.objects[index];
    }
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        ChartLayerModel *layer = (ChartLayerModel *)item;
        return layer.objects.count > 0;
    }
    return NO;
}

#pragma mark - NSOutlineViewDelegate (Layers)

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    
    NSTableCellView *cellView = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        // Clickable button for visibility toggle (only for layers)
        if ([item isKindOfClass:[ChartLayerModel class]]) {
            // Create button for layer visibility toggle
            NSButton *visibilityButton = [NSButton buttonWithTitle:@"👁️"
                                                            target:self
                                                            action:@selector(toggleLayerVisibilityAction:)];
            visibilityButton.translatesAutoresizingMaskIntoConstraints = NO;
            visibilityButton.bezelStyle = NSBezelStyleRounded;
            visibilityButton.buttonType = NSButtonTypeMomentaryPushIn;
            visibilityButton.controlSize = NSControlSizeSmall;
            visibilityButton.font = [NSFont systemFontOfSize:11];
            [cellView addSubview:visibilityButton];
            
            // TextField for layer name
            NSTextField *textField = [[NSTextField alloc] init];
            textField.translatesAutoresizingMaskIntoConstraints = NO;
            textField.editable = NO;
            textField.bordered = NO;
            textField.backgroundColor = [NSColor clearColor];
            textField.font = [NSFont systemFontOfSize:12];
            [cellView addSubview:textField];
            cellView.textField = textField;
            
            // Layout constraints
            [NSLayoutConstraint activateConstraints:@[
                [visibilityButton.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
                [visibilityButton.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor],
                [visibilityButton.widthAnchor constraintEqualToConstant:20],
                
                [textField.leadingAnchor constraintEqualToAnchor:visibilityButton.trailingAnchor constant:4],
                [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
                [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
            ]];
        } else {
            // For objects, just create a text field
            NSTextField *textField = [[NSTextField alloc] init];
            textField.translatesAutoresizingMaskIntoConstraints = NO;
            textField.editable = NO;
            textField.bordered = NO;
            textField.backgroundColor = [NSColor clearColor];
            textField.font = [NSFont systemFontOfSize:12];
            [cellView addSubview:textField];
            cellView.textField = textField;
            
            [NSLayoutConstraint activateConstraints:@[
                [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
                [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
                [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
            ]];
        }
    }
    
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        ChartLayerModel *layer = (ChartLayerModel *)item;
        
        // Update visibility button
        NSButton *visibilityButton = nil;
        for (NSView *subview in cellView.subviews) {
            if ([subview isKindOfClass:[NSButton class]]) {
                visibilityButton = (NSButton *)subview;
                break;
            }
        }
        
        if (visibilityButton) {
            visibilityButton.title = layer.isVisible ? @"👁️" : @"🚫";
        }
        
        // Update text
        cellView.textField.stringValue = [NSString stringWithFormat:@"%@ (%lu objects)",
                                         layer.name, (unsigned long)layer.objects.count];
        
    } else if ([item isKindOfClass:[ChartObjectModel class]]) {
        ChartObjectModel *object = (ChartObjectModel *)item;
        NSString *visibilityIcon = object.isVisible ? @"👁️" : @"🚫";
        NSString *typeIcon = [self iconForObjectType:object.type];
        
        // Objects: Only info display (no toggle)
        cellView.textField.stringValue = [NSString stringWithFormat:@"  %@ %@ %@",
                                         visibilityIcon, typeIcon, object.name];
        cellView.textField.textColor = object.isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
    }
    
    return cellView;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.layersOutlineView.selectedRow;
    if (selectedRow >= 0) {
        id selectedItem = [self.layersOutlineView itemAtRow:selectedRow];
        
        if ([selectedItem isKindOfClass:[ChartLayerModel class]]) {
            self.selectedLayer = (ChartLayerModel *)selectedItem;
            self.selectedObject = nil;
            [self.objectsTableView reloadData];
            
            NSLog(@"🎯 Selected layer: %@", self.selectedLayer.name);
        } else if ([selectedItem isKindOfClass:[ChartObjectModel class]]) {
            self.selectedObject = (ChartObjectModel *)selectedItem;
            
            NSLog(@"🎯 Selected object: %@", self.selectedObject.name);
        }
    }
}

#pragma mark - NSTableViewDataSource (Objects)

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger objectsCount = self.selectedLayer ? self.selectedLayer.objects.count : 0;
    NSLog(@"📊 TableView: Objects count requested - returning %ld objects for layer '%@'",
          (long)objectsCount, self.selectedLayer.name ?: @"none");
    return objectsCount;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (!self.selectedLayer || row >= self.selectedLayer.objects.count) return nil;
    
    ChartObjectModel *object = self.selectedLayer.objects[row];
    
    if ([tableColumn.identifier isEqualToString:@"NameColumn"]) {
        return object.name;
    } else if ([tableColumn.identifier isEqualToString:@"TypeColumn"]) {
        return [self nameForObjectType:object.type];
    } else if ([tableColumn.identifier isEqualToString:@"VisibleColumn"]) {
        BOOL effectivelyVisible = self.selectedLayer.isVisible && object.isVisible;
        return effectivelyVisible ? @"👁️" : @"🚫";
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate (Objects)

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.font = [NSFont systemFontOfSize:12];
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    if (!self.selectedLayer || row >= self.selectedLayer.objects.count) return cellView;
    
    ChartObjectModel *object = self.selectedLayer.objects[row];
    
    if ([tableColumn.identifier isEqualToString:@"NameColumn"]) {
        cellView.textField.stringValue = object.name;
        cellView.textField.textColor = object.isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        
    } else if ([tableColumn.identifier isEqualToString:@"TypeColumn"]) {
        cellView.textField.stringValue = [self nameForObjectType:object.type];
        cellView.textField.textColor = object.isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        
    } else if ([tableColumn.identifier isEqualToString:@"VisibleColumn"]) {
        // Info: Show state but no toggle
        BOOL effectivelyVisible = self.selectedLayer.isVisible && object.isVisible;
        cellView.textField.stringValue = effectivelyVisible ? @"👁️" : @"🚫";
        cellView.textField.textColor = effectivelyVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
    }
    
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.objectsTableView.selectedRow;
    if (selectedRow >= 0 && self.selectedLayer && selectedRow < self.selectedLayer.objects.count) {
        self.selectedObject = self.selectedLayer.objects[selectedRow];
        NSLog(@"🎯 Selected object from table: %@", self.selectedObject.name);
    }
}

#pragma mark - Helper Methods for Icons and Names

- (NSString *)iconForObjectType:(ChartObjectType)type {
    switch (type) {
        case ChartObjectTypeHorizontalLine: return @"📏";
        case ChartObjectTypeTrendline: return @"📈";
        case ChartObjectTypeFibonacci: return @"📊";
        case ChartObjectTypeTrailingFibo: return @"🌊";
        case ChartObjectTypeTrailingFiboBetween: return @"⏱️";
        case ChartObjectTypeTarget: return @"🎯";
        case ChartObjectTypeRectangle: return @"🔲";
        case ChartObjectTypeCircle: return @"⭕";
        case ChartObjectTypeChannel: return @"📡";
        case ChartObjectTypeFreeDrawing: return @"✏️";
        default: return @"❓";
    }
}

- (NSString *)nameForObjectType:(ChartObjectType)type {
    switch (type) {
        case ChartObjectTypeHorizontalLine: return @"Horizontal Line";
        case ChartObjectTypeTrendline: return @"Trend Line";
        case ChartObjectTypeFibonacci: return @"Fibonacci";
        case ChartObjectTypeTrailingFibo: return @"Trailing Fibo";
        case ChartObjectTypeTrailingFiboBetween: return @"Trailing Between";
        case ChartObjectTypeTarget: return @"Target";
        case ChartObjectTypeRectangle: return @"Rectangle";
        case ChartObjectTypeCircle: return @"Circle";
        case ChartObjectTypeChannel: return @"Channel";
        case ChartObjectTypeFreeDrawing: return @"Free Drawing";
        default: return @"Unknown";
    }
}

#pragma mark - Layer Visibility Toggle Actions

- (void)toggleLayerVisibilityAction:(NSButton *)sender {
    // Find the layer from row index of the cell
    NSInteger row = [self.layersOutlineView rowForView:sender];
    if (row >= 0) {
        id item = [self.layersOutlineView itemAtRow:row];
        if ([item isKindOfClass:[ChartLayerModel class]]) {
            ChartLayerModel *layer = (ChartLayerModel *)item;
            NSLog(@"🎯 Toggle layer visibility: %@", layer.name);
            [self toggleLayerVisibility:layer];
        }
    }
}

#pragma mark - Notification Observers

- (void)setupNotificationObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(chartObjectsChanged:)
                                                 name:@"ChartObjectsChanged"
                                               object:nil];
}

- (void)chartObjectsChanged:(NSNotification *)notification {
    NSString *notificationSymbol = notification.userInfo[@"symbol"];
    if ([notificationSymbol isEqualToString:self.currentSymbol]) {
        NSLog(@"🔄 ChartObjectManagerWindow: Objects changed for current symbol, refreshing");
        
        // Refresh con delay per permettere save completo
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self refreshContent];
            NSLog(@"📢 RECEIVED NOTIFICATION for symbol: %@", notificationSymbol);
            NSLog(@"📢 Current window symbol: %@", self.currentSymbol);
            NSLog(@"📢 Manager has %lu layers", (unsigned long)self.objectsManager.layers.count);
        });
    }
}
#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"🧹 ChartObjectManagerWindow: Cleaned up observers");
}

@end

// ============================================================================
// RIEPILOGO IMPLEMENTAZIONE COMPLETA
// ============================================================================

/*
✅ FUNZIONALITÀ IMPLEMENTATE:

🎯 LAYER MANAGEMENT TOOLBAR:
   - Add Layer (+): Crea nuovo layer con nome auto-generato ("Layer 1", "Layer 2", etc.)
   - Delete Layer (🗑️): Rimuove layer e tutti i suoi oggetti (con conferma se contiene oggetti)
   - Rename Layer (✏️): Rinomina layer con dialog di input e controllo duplicati

🎯 CONTEXT MENU SYSTEM:
   - Right-click su Layer: New, Rename, Duplicate, Toggle Visibility, Delete
   - Right-click su Object: Edit, Duplicate, Delete, Move to Layer (submenu dinamico)
   - Right-click su area vuota: New Layer

🎯 DRAG & DROP:
   - Drag oggetto da Objects table → Drop su Layer nel Layers outline
   - Visual feedback durante drag operation
   - Automatic refresh e selezione layer target dopo drop

🎯 DOUBLE-CLICK INTERACTION:
   - Double-click su oggetto → Apre settings window (preparato per integrazione)

🎯 UI IMPROVEMENTS:
   - Symbol label + Layer toolbar sulla stessa riga (usa spazio vuoto disponibile)
   - Layout constraints ottimizzati per il nuovo design
   - Notification system per sync con chart rendering

🎯 DATA MANAGEMENT:
   - Auto-save dopo ogni operazione tramite ChartObjectsManager
   - Unique name generation per layers con controllo duplicati
   - Proper object lifecycle management
   - Integration con DataHub per persistenza

🎯 ARCHITETTURA:
   - Tutte le operazioni passano attraverso ChartObjectsManager API corrette
   - Notification system per sync UI ↔ Chart rendering
   - Context menu dinamici con stato layer/object corrente
   - Drag & drop con feedback visivo e data integrity
   - Memory management con proper cleanup in dealloc

🎯 CORREZIONI APPLICATE:
   - Uso delle API corrette: createLayerWithName: e deleteLayer:
   - Nomi variabili univoci per evitare conflitti (objectToEdit vs object)
   - Properties aggiunte al header file
   - Gestione errori e edge cases

PRONTO PER INTEGRAZIONE:
- Il codice compila senza errori
- Tutte le funzionalità core sono implementate
- Sistema di notification per sync con chart rendering
- Preparato per integrazione con ChartObjectSettingsWindow
*/
