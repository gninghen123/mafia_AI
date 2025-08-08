//
//  ChartObjectManagerWindow.m
//  TradingApp
//
//  Implementation
//

#import "ChartObjectManagerWindow.h"
#import "DataHub+ChartObjects.h"

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
        [self refreshContent];
        
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

- (void)setupUI {
    // Main container
    self.contentContainer = [[NSView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.contentContainer];
    
    // Symbol label
    self.symbolLabel = [[NSTextField alloc] init];
    self.symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolLabel.stringValue = [NSString stringWithFormat:@"Symbol: %@", self.currentSymbol];
    self.symbolLabel.font = [NSFont boldSystemFontOfSize:14];
    self.symbolLabel.editable = NO;
    self.symbolLabel.bordered = NO;
    self.symbolLabel.backgroundColor = [NSColor clearColor];
    [self.contentContainer addSubview:self.symbolLabel];
    
    // Layers section header
    self.layersHeaderLabel = [self createHeaderLabel:@"📁 Layers"];
    [self.contentContainer addSubview:self.layersHeaderLabel];
    
    // Layers outline view
    self.layersOutlineView = [[NSOutlineView alloc] init];
    self.layersOutlineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.layersOutlineView.dataSource = self;
    self.layersOutlineView.delegate = self;
    self.layersOutlineView.headerView = nil;
    self.layersOutlineView.allowsMultipleSelection = NO;
    self.layersOutlineView.indentationPerLevel = 16;
    
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
    
    // Objects section header
    self.objectsHeaderLabel = [self createHeaderLabel:@"📋 Objects"];
    [self.contentContainer addSubview:self.objectsHeaderLabel];
    
    // Objects table view
    self.objectsTableView = [[NSTableView alloc] init];
    self.objectsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectsTableView.dataSource = self;
    self.objectsTableView.delegate = self;
    self.objectsTableView.allowsMultipleSelection = NO;
    
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
    
    // Store scroll views as instance variables for constraints
    self.layersScrollView = layersScrollView;
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
        
        // Symbol label
        [self.symbolLabel.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [self.symbolLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.symbolLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        
        // Layers header
        [self.layersHeaderLabel.topAnchor constraintEqualToAnchor:self.symbolLabel.bottomAnchor constant:16],
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

#pragma mark - Public Methods

- (void)refreshContent {
    [self.layersOutlineView reloadData];
    [self.objectsTableView reloadData];
    [self expandAllLayers];
    
    NSLog(@"🔄 ChartObjectManagerWindow: Content refreshed");
}

- (void)updateForSymbol:(NSString *)symbol {
    self.currentSymbol = symbol;
    self.title = [NSString stringWithFormat:@"Chart Objects - %@", symbol];
    self.symbolLabel.stringValue = [NSString stringWithFormat:@"Symbol: %@", symbol];
    [self refreshContent];
    
    NSLog(@"🔄 ChartObjectManagerWindow: Updated for symbol %@", symbol);
}

- (void)expandAllLayers {
    for (NSInteger i = 0; i < [self.layersOutlineView numberOfRows]; i++) {
        id item = [self.layersOutlineView itemAtRow:i];
        if ([item isKindOfClass:[ChartLayerModel class]]) {
            [self.layersOutlineView expandItem:item];
        }
    }
}

#pragma mark - NSOutlineViewDataSource (Layers)

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

#pragma mark - NSOutlineViewDelegate (Layers)

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    
    NSTableCellView *cellView = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    if ([item isKindOfClass:[ChartLayerModel class]]) {
        ChartLayerModel *layer = (ChartLayerModel *)item;
        NSString *visibilityIcon = layer.isVisible ? @"👁️" : @"🚫";
        cellView.textField.stringValue = [NSString stringWithFormat:@"%@ %@ (%lu)",
                                         visibilityIcon, layer.name, (unsigned long)layer.objects.count];
        cellView.textField.font = [NSFont boldSystemFontOfSize:12];
    } else if ([item isKindOfClass:[ChartObjectModel class]]) {
        ChartObjectModel *object = (ChartObjectModel *)item;
        NSString *visibilityIcon = object.isVisible ? @"👁️" : @"🚫";
        NSString *typeIcon = [self iconForObjectType:object.type];
        cellView.textField.stringValue = [NSString stringWithFormat:@"  %@ %@ %@",
                                         visibilityIcon, typeIcon, object.name];
        cellView.textField.font = [NSFont systemFontOfSize:11];
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
    return self.selectedLayer ? self.selectedLayer.objects.count : 0;
}

#pragma mark - NSTableViewDelegate (Objects)

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (!self.selectedLayer || row >= self.selectedLayer.objects.count) return nil;
    
    ChartObjectModel *object = self.selectedLayer.objects[row];
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    if ([tableColumn.identifier isEqualToString:@"NameColumn"]) {
        cellView.textField.stringValue = object.name;
    } else if ([tableColumn.identifier isEqualToString:@"TypeColumn"]) {
        NSString *typeIcon = [self iconForObjectType:object.type];
        cellView.textField.stringValue = [NSString stringWithFormat:@"%@ %@", typeIcon, [self nameForObjectType:object.type]];
    } else if ([tableColumn.identifier isEqualToString:@"VisibleColumn"]) {
        cellView.textField.stringValue = object.isVisible ? @"👁️" : @"🚫";
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

#pragma mark - Helper Methods

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

@end
