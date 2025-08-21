//
//  ChartObjectManagerWindow.m
//  TradingApp
//
//  Implementation completa con outline view espanso + drag&drop + menu contestuale
//

#import "ChartObjectManagerWindow.h"
#import "DataHub+ChartObjects.h"
#import "ChartObjectSettingsWindow.h"
#import <QuartzCore/QuartzCore.h>

@interface ChartObjectManagerWindow ()
@property (nonatomic, strong) NSView *contentContainer;
@property (nonatomic, strong) NSScrollView *layersScrollView;
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
    
    // Outline view espanso a tutta la view (MODIFICATO)
    [self setupExpandedOutlineView];
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
}

- (void)setupExpandedOutlineView {
    // ✅ NUOVA IMPLEMENTAZIONE: Outline view espanso a tutta la view
    self.layersOutlineView = [[NSOutlineView alloc] init];
    self.layersOutlineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.layersOutlineView.dataSource = self;
    self.layersOutlineView.delegate = self;
    self.layersOutlineView.headerView = nil;
    self.layersOutlineView.allowsMultipleSelection = NO; // ✅ NO selection multipla
    self.layersOutlineView.indentationPerLevel = 20;
    self.layersOutlineView.intercellSpacing = NSMakeSize(0, 2);
    
    // ✅ CORREZIONE: Configurazione context menu
    // Il menu viene generato dinamicamente tramite menuForTableColumn:item:
    // Ma dobbiamo assicurarci che il delegate method venga chiamato
    
    // ✅ Drag & Drop setup per oggetti tra layer
    [self.layersOutlineView registerForDraggedTypes:@[@"ChartObjectDragType"]];
    self.layersOutlineView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleSourceList;
    
    // Add single column per layer + oggetti
    NSTableColumn *itemColumn = [[NSTableColumn alloc] initWithIdentifier:@"ItemColumn"];
    itemColumn.title = @"Layers & Objects";
    itemColumn.width = 300;
    [self.layersOutlineView addTableColumn:itemColumn];
    
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = self.layersOutlineView;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.borderType = NSBezelBorder;
    [self.contentContainer addSubview:scrollView];
    
    self.layersScrollView = scrollView;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Container
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        
        // Symbol label (top left)
        [self.symbolLabel.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [self.symbolLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        
        // Layer toolbar (top right)
        [self.layerToolbar.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [self.layerToolbar.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [self.layerToolbar.heightAnchor constraintEqualToConstant:30],
        
        // ✅ NUOVA IMPLEMENTAZIONE: Outline view espanso occupa tutto lo spazio rimanente
        [self.layersScrollView.topAnchor constraintEqualToAnchor:self.symbolLabel.bottomAnchor constant:12],
        [self.layersScrollView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.layersScrollView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [self.layersScrollView.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor],
        
        // Layer toolbar buttons layout
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

#pragma mark - Data Loading

- (void)setupNotificationObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDataHubUpdate:)
                                                 name:@"DataHubChartObjectsUpdated"
                                               object:nil];
    
    // ✅ AGGIUNTA: Ascolta quando il ChartObjectsManager completa il load
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleObjectsManagerDataLoaded:)
                                                 name:@"ChartObjectsManagerDataLoaded"
                                               object:nil];
    
    NSLog(@"✅ ObjectManagerWindow: Notification observers setup");
}

- (void)loadInitialData {
    if (!self.objectsManager || !self.currentSymbol) return;
    
    // Se non ci sono layer, assicura che ci sia un layer attivo
    if (self.objectsManager.layers.count == 0) {
        [self.objectsManager ensureActiveLayerForObjectCreation];
    }
    
    // ✅ CORREZIONE: Trigghera il load asincrono - la notification arriverà quando finito
    NSLog(@"📥 ObjectManagerWindow: Loading initial data for symbol %@", self.currentSymbol);
    [self.objectsManager loadFromDataHub];
    
    // Non fare refreshContent qui - aspettiamo la notification!
}

- (void)handleDataHubUpdate:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    if ([symbol isEqualToString:self.currentSymbol]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshContent];
            NSLog(@"🔄 ObjectManagerWindow: Refreshed from DataHub notification for %@", symbol);
        });
    }
}

- (void)handleObjectsManagerDataLoaded:(NSNotification *)notification {
    // ✅ NUOVO: Handler per quando il ChartObjectsManager finisce di caricare i dati
    NSString *symbol = notification.userInfo[@"symbol"];
    
    if ([symbol isEqualToString:self.currentSymbol]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshContent];
            NSLog(@"🔄 ObjectManagerWindow: Refreshed from ObjectsManager load completion for %@", symbol);
        });
    } else {
        NSLog(@"💡 ObjectManagerWindow: Ignoring load notification for different symbol: %@ (current: %@)",
              symbol, self.currentSymbol);
    }
}

#pragma mark - Public Methods

- (void)refreshContent {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.layersOutlineView reloadData];
        
        // Espandi tutti i layer per mostrare gli oggetti
        for (NSInteger i = 0; i < self.objectsManager.layers.count; i++) {
            [self.layersOutlineView expandItem:self.objectsManager.layers[i]];
        }
        
        NSLog(@"🔄 ChartObjectManagerWindow: Content refreshed for %@", self.currentSymbol);
    });
}

- (void)updateForSymbol:(NSString *)symbol {
    if ([symbol isEqualToString:self.currentSymbol]) return;
    
    self.currentSymbol = symbol;
    self.title = [NSString stringWithFormat:@"Chart Objects - %@", symbol];
    self.symbolLabel.stringValue = [NSString stringWithFormat:@"Symbol: %@", symbol];
    
    // Reset selection
    self.selectedLayer = nil;
    self.selectedObject = nil;
    
    // ✅ CORREZIONE: NON fare refresh immediato - aspetta la notification!
    // [self refreshContent]; ← RIMOSSO!
    
    // ✅ NUOVO: Trigghera il load asincrono - la notification arriverà quando finito
    if (self.objectsManager) {
        NSLog(@"📥 ObjectManagerWindow: Triggering async load for symbol %@", symbol);
        [self.objectsManager loadFromDataHub];
    }
    
    NSLog(@"🔄 ObjectManagerWindow: Updated for symbol %@ (waiting for data...)", symbol);
}

#pragma mark - NSOutlineViewDataSource (Struttura gerarchica layer → oggetti)

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item {
    if (item == nil) {
        // Root level - return layers count
        return self.objectsManager.layers.count;
    }
    
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        // Layer level - return objects count in this layer
        ChartLayerModel *layer = (ChartLayerModel *)item;
        return layer.objects.count;
    }
    
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

#pragma mark - NSOutlineViewDelegate (Cell rendering con icone)

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    
    NSTableCellView *cellView = [outlineView makeViewWithIdentifier:@"ItemCell" owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = @"ItemCell";
        
        // Text field
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.editable = NO;
        textField.font = [NSFont systemFontOfSize:13];
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        // Image view per icone
        NSImageView *imageView = [[NSImageView alloc] init];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
        [cellView addSubview:imageView];
        cellView.imageView = imageView;
        
        // Constraints
        [NSLayoutConstraint activateConstraints:@[
            [imageView.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [imageView.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor],
            [imageView.widthAnchor constraintEqualToConstant:16],
            [imageView.heightAnchor constraintEqualToConstant:16],
            
            [textField.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor constant:6],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        // ✅ LAYER CELL
        ChartLayerModel *layer = (ChartLayerModel *)item;
        
        cellView.textField.stringValue = layer.name;
        cellView.textField.font = [NSFont boldSystemFontOfSize:13];
        cellView.textField.textColor = layer.isVisible ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        
        // ✅ ICONA LAYER: Cartella con indicatore visibilità
        NSString *iconName = layer.isVisible ? @"📁" : @"📂";
        cellView.imageView.image = [self createEmojiImageWithText:iconName];
        
    } else if ([item isKindOfClass:[ChartObjectModel class]]) {
        // ✅ OBJECT CELL
        ChartObjectModel *object = (ChartObjectModel *)item;
        
        cellView.textField.stringValue = object.name;
        cellView.textField.font = [NSFont systemFontOfSize:12];
        
        // ✅ VISIBILITÀ: Controlla layer parent + oggetto
        ChartLayerModel *parentLayer = [self layerContainingObject:object];
        BOOL effectivelyVisible = parentLayer.isVisible && object.isVisible;
        cellView.textField.textColor = effectivelyVisible ? [NSColor labelColor] : [NSColor tertiaryLabelColor];
        
        // ✅ ICONA OGGETTO: Per tipo con SF Symbols
        cellView.imageView.image = [self iconImageForObjectType:object.type];
    }
    
    return cellView;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.layersOutlineView.selectedRow;
    if (selectedRow < 0) {
        self.selectedLayer = nil;
        self.selectedObject = nil;
        return;
    }
    
    id selectedItem = [self.layersOutlineView itemAtRow:selectedRow];
    
    if ([selectedItem isKindOfClass:[ChartLayerModel class]]) {
        self.selectedLayer = (ChartLayerModel *)selectedItem;
        self.selectedObject = nil;
        NSLog(@"🎯 Selected layer: %@", self.selectedLayer.name);
    } else if ([selectedItem isKindOfClass:[ChartObjectModel class]]) {
        self.selectedObject = (ChartObjectModel *)selectedItem;
        self.selectedLayer = [self layerContainingObject:self.selectedObject];
        NSLog(@"🎯 Selected object: %@ in layer: %@", self.selectedObject.name, self.selectedLayer.name);
    }
}

#pragma mark - Context Menu Implementation

- (NSMenu *)outlineView:(NSOutlineView *)outlineView menuForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSLog(@"🖱️ Context menu requested for item: %@", item);
    
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        NSLog(@"🖱️ Creating context menu for layer: %@", ((ChartLayerModel *)item).name);
        return [self contextMenuForLayer:(ChartLayerModel *)item];
    } else if ([item isKindOfClass:[ChartObjectModel class]]) {
        NSLog(@"🖱️ Creating context menu for object: %@", ((ChartObjectModel *)item).name);
        return [self contextMenuForObject:(ChartObjectModel *)item];
    }
    
    NSLog(@"🖱️ Creating context menu for empty area");
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
    
    // ✅ RIUSO ChartObjectSettingsWindow per edit
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

- (void)editObjectFromContext:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    
    // ✅ RIUSO del pannello ChartObjectSettingsWindow (come da richiesta)
    if (self.objectSettingsWindow) {
        [self.objectSettingsWindow close];
    }
    
    self.objectSettingsWindow = [[ChartObjectSettingsWindow alloc]
                                initWithObject:object
                                objectsManager:self.objectsManager];
    
    if (self.objectSettingsWindow) {
        [self.objectSettingsWindow makeKeyAndOrderFront:nil];
        NSLog(@"🎨 Opened settings window for object '%@'", object.name);
    } else {
        NSLog(@"❌ Failed to create settings window for object '%@'", object.name);
    }
}

- (void)duplicateObjectFromContext:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    ChartLayerModel *layer = [self layerContainingObject:object];
    
    if (layer) {
        ChartObjectModel *duplicate = [object copy];
        duplicate.name = [self generateUniqueObjectName:[NSString stringWithFormat:@"%@ Copy", object.name] inLayer:layer];
        
        // ✅ CORRETTO: Aggiungi direttamente al layer
        [layer addObject:duplicate];
        [self.objectsManager saveToDataHub];
        [self refreshContent];
        
        NSLog(@"📋 Duplicated object '%@' as '%@'", object.name, duplicate.name);
    }
}

- (void)deleteObjectFromContext:(NSMenuItem *)menuItem {
    ChartObjectModel *object = menuItem.representedObject;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Object";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?", object.name];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [self.objectsManager deleteObject:object];
        [self.objectsManager saveToDataHub];
        [self refreshContent];
        
        NSLog(@"🗑️ Deleted object '%@'", object.name);
    }
}

- (void)moveObjectToLayerFromContext:(NSMenuItem *)menuItem {
    NSDictionary *info = menuItem.representedObject;
    ChartObjectModel *object = info[@"object"];
    ChartLayerModel *targetLayer = info[@"layer"];
    
    [self.objectsManager moveObject:object toLayer:targetLayer];
    [self.objectsManager saveToDataHub];
    [self refreshContent];
    
    NSLog(@"📁 Moved object '%@' to layer '%@'", object.name, targetLayer.name);
}

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

#pragma mark - Right-Click Setup

- (void)setupRightClickHandling {
    // ✅ AGGIUNTA: Gestione manuale del right-click per NSOutlineView
    // Alcuni NSOutlineView non chiamano menuForTableColumn automaticamente
    
    // Aggiungi gesture recognizer per right-click
    NSClickGestureRecognizer *rightClickGesture = [[NSClickGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(handleRightClick:)];
    rightClickGesture.buttonMask = 0x2; // Right mouse button
    [self.layersOutlineView addGestureRecognizer:rightClickGesture];
    
    NSLog(@"✅ Right-click gesture recognizer added to outline view");
}

- (void)handleRightClick:(NSClickGestureRecognizer *)gesture {
    if (gesture.state != NSGestureRecognizerStateEnded) return;
    
    NSPoint clickPoint = [gesture locationInView:self.layersOutlineView];
    NSInteger clickedRow = [self.layersOutlineView rowAtPoint:clickPoint];
    
    NSLog(@"🖱️ Right-click detected at point (%.1f, %.1f), row: %ld",
          clickPoint.x, clickPoint.y, (long)clickedRow);
    
    id clickedItem = nil;
    if (clickedRow >= 0) {
        clickedItem = [self.layersOutlineView itemAtRow:clickedRow];
        
        // Seleziona il row se non è già selezionato
        if (self.layersOutlineView.selectedRow != clickedRow) {
            [self.layersOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:clickedRow]
                               byExtendingSelection:NO];
        }
    }
    
    // Crea il menu appropriato
    NSMenu *contextMenu = [self contextMenuForItem:clickedItem];
    if (contextMenu) {
        // Mostra il menu al punto del click
        [NSMenu popUpContextMenu:contextMenu
                       withEvent:[NSApp currentEvent]
                         forView:self.layersOutlineView];
        
        NSLog(@"✅ Context menu displayed with %ld items", (long)contextMenu.itemArray.count);
    } else {
        NSLog(@"⚠️ No context menu created for item: %@", clickedItem);
    }
}

- (NSMenu *)contextMenuForItem:(id)item {
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        return [self contextMenuForLayer:(ChartLayerModel *)item];
    } else if ([item isKindOfClass:[ChartObjectModel class]]) {
        return [self contextMenuForObject:(ChartObjectModel *)item];
    } else {
        return [self contextMenuForEmptyArea];
    }
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

#pragma mark - Drag & Drop Implementation

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
    // ✅ DRAG SOURCE: Solo per oggetti (non layer)
    if (items.count == 1) {
        id item = items[0];
        if ([item isKindOfClass:[ChartObjectModel class]]) {
            self.draggedObject = (ChartObjectModel *)item;
            
            [pasteboard declareTypes:@[@"ChartObjectDragType"] owner:self];
            [pasteboard setString:self.draggedObject.objectID forType:@"ChartObjectDragType"];
            
            NSLog(@"🎯 Started dragging object '%@'", self.draggedObject.name);
            return YES;
        }
    }
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
                  validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index {
    
    // ✅ DROP TARGET: Solo su layer (non su oggetti)
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        return NSDragOperationMove;
    }
    
    // Se item è nil, siamo nel root level - non permettere drop
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
         acceptDrop:(id<NSDraggingInfo>)info
               item:(id)item
         childIndex:(NSInteger)index {
    
    if (!self.draggedObject || ![item isKindOfClass:[ChartLayerModel class]]) {
        return NO;
    }
    
    ChartLayerModel *targetLayer = (ChartLayerModel *)item;
    
    // ✅ ESEGUI SPOSTAMENTO
    [self.objectsManager moveObject:self.draggedObject toLayer:targetLayer];
    [self.objectsManager saveToDataHub];
    
    // Reset drag state
    self.draggedObject = nil;
    
    // Refresh UI
    [self refreshContent];
    
    // Espandi il layer target per mostrare l'oggetto
    [self.layersOutlineView expandItem:targetLayer];
    
    NSLog(@"✅ Dropped object into layer '%@'", targetLayer.name);
    return YES;
}

#pragma mark - Layer Management Actions

- (IBAction)addLayerAction:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Layer";
    alert.informativeText = @"Enter name for the new layer:";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = @"Layer";
    alert.accessoryView = input;
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *layerName = input.stringValue.length > 0 ? input.stringValue : @"Layer";
        NSString *uniqueName = [self generateUniqueLayerName:layerName];
        
        ChartLayerModel *newLayer = [[ChartLayerModel alloc] init];
        newLayer.name = uniqueName;
        newLayer.isVisible = YES;
        newLayer.orderIndex = (NSInteger)self.objectsManager.layers.count;
        
        [self.objectsManager.layers addObject:newLayer];
        [self.objectsManager saveToDataHub];
        [self refreshContent];
        
        NSLog(@"✅ Created new layer '%@'", uniqueName);
    }
}

- (IBAction)deleteLayerAction:(id)sender {
    if (!self.selectedLayer) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Layer Selected";
        alert.informativeText = @"Please select a layer to delete.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Layer";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete layer '%@' and all its objects?", self.selectedLayer.name];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [self.objectsManager.layers removeObject:self.selectedLayer];
        [self.objectsManager saveToDataHub];
        
        self.selectedLayer = nil;
        self.selectedObject = nil;
        
        [self refreshContent];
        
        NSLog(@"🗑️ Deleted layer");
    }
}

- (IBAction)renameLayerAction:(id)sender {
    if (!self.selectedLayer) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Layer Selected";
        alert.informativeText = @"Please select a layer to rename.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Layer";
    alert.informativeText = @"Enter new name for the layer:";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = self.selectedLayer.name;
    alert.accessoryView = input;
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *newName = input.stringValue.length > 0 ? input.stringValue : self.selectedLayer.name;
        NSString *uniqueName = [self generateUniqueLayerName:newName];
        
        self.selectedLayer.name = uniqueName;
        [self.objectsManager saveToDataHub];
        [self refreshContent];
        
        NSLog(@"✏️ Renamed layer to '%@'", uniqueName);
    }
}

- (void)toggleLayerVisibility:(ChartLayerModel *)layer {
    layer.isVisible = !layer.isVisible;
    [self.objectsManager saveToDataHub];
    [self refreshContent];
    
    // ✅ NOTIFICA IL CHART PER RE-RENDER (logica visibilità corretta)
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChartObjectsVisibilityChanged"
                                                        object:self.objectsManager
                                                      userInfo:@{@"symbol": self.currentSymbol ?: @""}];
    
    NSLog(@"🎯 Layer '%@' visibility: %@ - Chart notified for re-render",
          layer.name, layer.isVisible ? @"VISIBLE" : @"HIDDEN");
}

#pragma mark - Helper Methods

- (ChartLayerModel *)layerContainingObject:(ChartObjectModel *)object {
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        if ([layer.objects containsObject:object]) {
            return layer;
        }
    }
    return nil;
}

- (NSString *)generateUniqueLayerName:(NSString *)baseName {
    NSString *uniqueName = baseName;
    NSInteger counter = 1;
    
    while ([self layerNameExists:uniqueName]) {
        uniqueName = [NSString stringWithFormat:@"%@ %ld", baseName, (long)counter];
        counter++;
    }
    
    return uniqueName;
}

- (BOOL)layerNameExists:(NSString *)name {
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        if ([layer.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)generateUniqueObjectName:(NSString *)baseName inLayer:(ChartLayerModel *)layer {
    NSString *uniqueName = baseName;
    NSInteger counter = 1;
    
    while ([self objectNameExists:uniqueName inLayer:layer]) {
        uniqueName = [NSString stringWithFormat:@"%@ %ld", baseName, (long)counter];
        counter++;
    }
    
    return uniqueName;
}

- (BOOL)objectNameExists:(NSString *)name inLayer:(ChartLayerModel *)layer {
    for (ChartObjectModel *object in layer.objects) {
        if ([object.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Icon Creation Methods

- (NSImage *)createEmojiImageWithText:(NSString *)emoji {
    NSFont *font = [NSFont systemFontOfSize:14];
    NSDictionary *attributes = @{NSFontAttributeName: font};
    NSSize textSize = [emoji sizeWithAttributes:attributes];
    
    NSSize imageSize = NSMakeSize(16, 16);
    NSImage *image = [[NSImage alloc] initWithSize:imageSize];
    
    [image lockFocus];
    NSPoint drawPoint = NSMakePoint((imageSize.width - textSize.width) / 2,
                                   (imageSize.height - textSize.height) / 2);
    [emoji drawAtPoint:drawPoint withAttributes:attributes];
    [image unlockFocus];
    
    return image;
}

- (NSImage *)iconImageForObjectType:(ChartObjectType)type {
    // ✅ ICONE SEMPLICI LINEARI COME RICHIESTO
    NSString *symbolName = [self sfSymbolNameForObjectType:type];
    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@"Object Type"];
    
    if (image) {
        // ✅ STILE: Monocromatico semplice
        NSImage *tintedImage = [image copy];
        tintedImage.template = YES;
        return tintedImage;
    }
    
    // Fallback emoji se SF Symbol non disponibile
    NSString *emoji = [self emojiForObjectType:type];
    return [self createEmojiImageWithText:emoji];
}

- (NSString *)sfSymbolNameForObjectType:(ChartObjectType)type {
    // ✅ SF SYMBOLS SEMPLICI E LINEARI
    switch (type) {
        case ChartObjectTypeHorizontalLine: return @"minus";
        case ChartObjectTypeTrendline: return @"line.diagonal";
        case ChartObjectTypeFibonacci: return @"chart.line.uptrend.xyaxis";
        case ChartObjectTypeTrailingFibo: return @"waveform.path";
        case ChartObjectTypeTrailingFiboBetween: return @"waveform.path.ecg";
        case ChartObjectTypeTarget: return @"target";
        case ChartObjectTypeRectangle: return @"rectangle";
        case ChartObjectTypeCircle: return @"circle";
        case ChartObjectTypeChannel: return @"rectangle.portrait.and.arrow.right";
        case ChartObjectTypeFreeDrawing: return @"pencil";
        case ChartObjectTypeOval: return @"oval";
        default: return @"questionmark";
    }
}

- (NSString *)emojiForObjectType:(ChartObjectType)type {
    // ✅ FALLBACK EMOJI (se SF Symbol non funziona)
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
        case ChartObjectTypeOval: return @"🥚";
        default: return @"❓";
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.objectSettingsWindow) {
        [self.objectSettingsWindow close];
    }
}

@end
