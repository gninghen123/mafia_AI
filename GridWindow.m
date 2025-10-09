//
//  GridWindow.m
//  TradingApp
//
//  Grid window containing multiple widgets in a layout
//

#import "GridWindow.h"
#import "BaseWidget.h"
#import "AppDelegate.h"
#import "WidgetTypeManager.h"
#import "workspacemanager.h"

@interface GridWindow ()
@property (nonatomic, strong) NSView *containerView;
@property (nonatomic, assign) NSInteger rows;
@property (nonatomic, assign) NSInteger cols;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSLayoutConstraint *> *splitConstraints;
@end

@implementation GridWindow

#pragma mark - Initialization

- (instancetype)initWithTemplate:(GridTemplateType)templateType
                            name:(nullable NSString *)name
                     appDelegate:(AppDelegate *)appDelegate {
    NSRect contentRect = NSMakeRect(100, 100, 1200, 800);
    self = [super initWithContentRect:contentRect
                            styleMask:NSWindowStyleMaskTitled |
                                     NSWindowStyleMaskClosable |
                                     NSWindowStyleMaskMiniaturizable |
                                     NSWindowStyleMaskResizable
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        _widgets = [NSMutableArray array];
        _widgetPositions = [NSMutableDictionary dictionary];
        _splitConstraints = [NSMutableDictionary dictionary];
        _currentTemplate = [GridTemplate templateWithType:templateType];
        _gridName = name ?: _currentTemplate.displayName;
        _appDelegate = appDelegate;

        // Set default grid size for template
        [self configureGridForTemplate:_currentTemplate];

        // Window setup
        self.title = [NSString stringWithFormat:@"Grid: %@", _gridName];
        self.delegate = self;
        self.releasedWhenClosed = NO;

        // Configure window behavior
        [self configureWindowBehavior];

        // Setup UI
        [self setupContainerView];
        [self setupAccessoryView];
        [self setupLayout];

        // Populate initial empty positions with placeholder BaseWidget
        for (NSInteger r = 1; r <= self.rows; r++) {
            for (NSInteger c = 1; c <= self.cols; c++) {
                NSString *matrixCode = [NSString stringWithFormat:@"%ld%ld", (long)r, (long)c];
                if (!self.widgetPositions[matrixCode]) {
                    BaseWidget *placeholder = [[BaseWidget alloc] initWithType:@"BaseWidget"];
                    [placeholder loadView];
                    [self addWidget:placeholder atMatrixCode:matrixCode];
                }
            }
        }

        NSLog(@"🏗️ GridWindow: Created with template: %@", _currentTemplate.displayName);
    }
    return self;
}

#pragma mark - Matrix Grid Configuration

- (void)configureGridForTemplate:(GridTemplate *)template {
    // Example: Map template to rows/cols (you can adjust per your template types)
    if ([template.templateType isEqualToString:@"quad"]) {
        self.rows = 2; self.cols = 2;
    } else if ([template.templateType isEqualToString:@"triple_horizontal"]) {
        self.rows = 1; self.cols = 3;
    } else if ([template.templateType isEqualToString:@"list_chart"]) {
        self.rows = 1; self.cols = 2;
    } else if ([template.templateType isEqualToString:@"list_dual_chart"]) {
        self.rows = 2; self.cols = 2;
    } else {
        self.rows = 1; self.cols = 1;
    }
}

#pragma mark - Window Configuration

- (void)configureWindowBehavior {
    self.backgroundColor = [NSColor windowBackgroundColor];
    self.hasShadow = YES;
    self.movableByWindowBackground = NO; // Grid has controls, don't move by background
    
    // Normal window level
    self.level = NSNormalWindowLevel;
    
    // Collection behavior
    self.collectionBehavior = NSWindowCollectionBehaviorManaged |
                             NSWindowCollectionBehaviorParticipatesInCycle |
                             NSWindowCollectionBehaviorFullScreenPrimary;
    
    // Minimum size
    self.minSize = NSMakeSize(600, 400);
}

#pragma mark - UI Setup

- (void)setupContainerView {
    self.containerView = [[NSView alloc] initWithFrame:self.contentView.bounds];
    self.containerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.contentView addSubview:self.containerView];
}

- (void)setupAccessoryView {
    // Create accessory view
    NSView *accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 28)];
    
    // Template selector popup
    self.templateSelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 140, 24)];
    self.templateSelector.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Populate with templates
    [self.templateSelector removeAllItems];
    for (GridTemplate *template in [GridTemplate allTemplates]) {
        [self.templateSelector addItemWithTitle:template.displayName];
        [[self.templateSelector lastItem] setRepresentedObject:template.templateType];
    }
    
    // Select current template
    [self.templateSelector selectItemAtIndex:0]; // TODO: select current template
    self.templateSelector.target = self;
    self.templateSelector.action = @selector(templateSelectorChanged:);
    
    [accessory addSubview:self.templateSelector];
    
    // Add widget button
    self.addWidgetButton = [NSButton buttonWithTitle:@"+" target:self action:@selector(addWidgetButtonClicked:)];
    self.addWidgetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addWidgetButton.bezelStyle = NSBezelStyleRounded;
    [accessory addSubview:self.addWidgetButton];
    
    // Settings button
    self.settingsButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Settings"]
                                             target:self
                                             action:@selector(settingsButtonClicked:)];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingsButton.bezelStyle = NSBezelStyleRounded;
    self.settingsButton.bordered = YES;
    [accessory addSubview:self.settingsButton];
    
    // Layout accessory controls
    [NSLayoutConstraint activateConstraints:@[
        [self.templateSelector.leadingAnchor constraintEqualToAnchor:accessory.leadingAnchor constant:8],
        [self.templateSelector.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        [self.templateSelector.widthAnchor constraintEqualToConstant:140],
        
        [self.addWidgetButton.leadingAnchor constraintEqualToAnchor:self.templateSelector.trailingAnchor constant:8],
        [self.addWidgetButton.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        [self.addWidgetButton.widthAnchor constraintEqualToConstant:32],
        
        [self.settingsButton.leadingAnchor constraintEqualToAnchor:self.addWidgetButton.trailingAnchor constant:8],
        [self.settingsButton.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        [self.settingsButton.widthAnchor constraintEqualToConstant:32]
    ]];
    
    // Add to titlebar
    NSTitlebarAccessoryViewController *accessoryVC = [[NSTitlebarAccessoryViewController alloc] init];
    accessoryVC.view = accessory;
    accessoryVC.layoutAttribute = NSLayoutAttributeRight;
    [self addTitlebarAccessoryViewController:accessoryVC];
    
    NSLog(@"✅ GridWindow: Accessory view setup complete");
}

- (void)setupLayout {
    // Clear existing layout
    for (NSView *subview in self.containerView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Create split view from template
    self.mainSplitView = [self.currentTemplate createLayoutView];
    if (!self.mainSplitView) {
        NSLog(@"❌ GridWindow: Failed to create layout from template");
        return;
    }
    
    self.mainSplitView.delegate = self;
    self.mainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.mainSplitView];
    
    // Pin split view to container
    [NSLayoutConstraint activateConstraints:@[
        [self.mainSplitView.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [self.mainSplitView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.mainSplitView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [self.mainSplitView.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor]
    ]];
    
    NSLog(@"✅ GridWindow: Layout setup complete for template: %@", self.currentTemplate.displayName);
}

#pragma mark - Widget Management
- (void)setupCallbacksForWidget:(BaseWidget *)widget {
    __weak typeof(self) weakSelf = self;

    widget.onTypeChange = ^(BaseWidget *sourceWidget, NSString *newType) {
        [weakSelf transformWidget:sourceWidget toType:newType];
    };

    widget.onRemoveRequest = ^(BaseWidget *widgetToRemove) {
        [weakSelf removeWidget:widgetToRemove];
    };
}
- (void)addWidget:(BaseWidget *)widget atMatrixCode:(NSString *)matrixCode {
    if (!widget) {
        NSLog(@"⚠️ GridWindow: Cannot add nil widget");
        return;
    }
    // Validate matrix code
    NSInteger row = [[matrixCode substringToIndex:1] integerValue];
    NSInteger col = [[matrixCode substringFromIndex:1] integerValue];
    if (row < 1 || row > self.rows || col < 1 || col > self.cols) {
        NSLog(@"⚠️ GridWindow: Invalid matrix code %@", matrixCode);
        return;
    }
    if (self.widgetPositions[matrixCode]) {
        NSLog(@"⚠️ GridWindow: Matrix code %@ already occupied", matrixCode);
        return;
    }
    NSLog(@"➕ GridWindow: Adding widget %@ at matrix %@", widget.widgetType, matrixCode);
    [self.widgets addObject:widget];
    self.widgetPositions[matrixCode] = widget;
    [self setupCallbacksForWidget:widget];
    [self insertWidgetIntoMatrixLayout:widget atMatrixCode:matrixCode];
    NSLog(@"✅ GridWindow: Widget added successfully. Total widgets: %ld", (long)self.widgets.count);
}

// Widget callback setup unchanged

// Insert widget into matrix-based grid layout
- (void)insertWidgetIntoMatrixLayout:(BaseWidget *)widget atMatrixCode:(NSString *)matrixCode {
    // Remove any existing view at this position
    NSView *widgetView = widget.view;
    // Tag the view for easy lookup (optional)
    widgetView.identifier = matrixCode;    // Compute frame for matrix cell
    CGFloat w = self.containerView.bounds.size.width / self.cols;
    CGFloat h = self.containerView.bounds.size.height / self.rows;
    NSInteger row = [[matrixCode substringToIndex:1] integerValue];
    NSInteger col = [[matrixCode substringFromIndex:1] integerValue];
    CGFloat x = (col - 1) * w;
    CGFloat y = self.containerView.bounds.size.height - (row * h);
    widgetView.frame = NSMakeRect(x, y, w, h);
    widgetView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.containerView addSubview:widgetView];
}

// --- Removed template-specific layout insertion methods ---

// Widget removal for matrix-based system
- (void)removeWidget:(BaseWidget *)widget {
    if (![self.widgets containsObject:widget]) {
        NSLog(@"⚠️ GridWindow: Widget not found in grid");
        return;
    }
    NSLog(@"🗑️ GridWindow: Removing widget %@", widget.widgetType);
    NSString *matrixCodeToRemove = nil;
    for (NSString *matrixCode in self.widgetPositions) {
        if (self.widgetPositions[matrixCode] == widget) {
            matrixCodeToRemove = matrixCode;
            break;
        }
    }
    if (matrixCodeToRemove) {
        [self.widgetPositions removeObjectForKey:matrixCodeToRemove];
    }
    [self.widgets removeObject:widget];
    [widget.view removeFromSuperview];
    NSLog(@"✅ GridWindow: Widget removed. Remaining widgets: %ld", (long)self.widgets.count);
    // Optionally: add a placeholder BaseWidget here if desired
    if (self.widgets.count == 0) {
        NSLog(@"🪟 GridWindow: No widgets remaining, closing window");
        [self close];
    }
}

// Detach widget for matrix-based system
- (BaseWidget *)detachWidget:(BaseWidget *)widget {
    if (![self.widgets containsObject:widget]) {
        return nil;
    }
    NSLog(@"📤 GridWindow: Detaching widget %@", widget.widgetType);
    NSString *matrixCodeToRemove = nil;
    for (NSString *matrixCode in self.widgetPositions) {
        if (self.widgetPositions[matrixCode] == widget) {
            matrixCodeToRemove = matrixCode;
            break;
        }
    }
    if (matrixCodeToRemove) {
        [self.widgetPositions removeObjectForKey:matrixCodeToRemove];
    }
    [self.widgets removeObject:widget];
    [widget.view removeFromSuperview];
    widget.onTypeChange = nil;
    widget.onRemoveRequest = nil;
    if (self.widgets.count == 0) {
        [self close];
    }
    return widget;
}

#pragma mark - Template Management

- (void)changeTemplate:(GridTemplateType)newTemplateType {
    NSLog(@"🔄 GridWindow: Changing template from %@ to %@", self.currentTemplate.displayName, newTemplateType);
    NSArray *currentWidgets = [self.widgets copy];
    for (BaseWidget *widget in currentWidgets) {
        [widget.view removeFromSuperview];
    }
    [self.widgets removeAllObjects];
    [self.widgetPositions removeAllObjects];

    self.currentTemplate = [GridTemplate templateWithType:newTemplateType];
    [self configureGridForTemplate:self.currentTemplate];
    [self setupLayout];

    NSInteger maxWidgetsForNewTemplate = self.rows * self.cols;
    NSInteger widgetsToAdd = MIN(currentWidgets.count, maxWidgetsForNewTemplate);
    NSInteger widgetIndex = 0;
    for (NSInteger r = 1; r <= self.rows; r++) {
        for (NSInteger c = 1; c <= self.cols; c++) {
            NSString *matrixCode = [NSString stringWithFormat:@"%ld%ld", (long)r, (long)c];
            if (widgetIndex < widgetsToAdd) {
                BaseWidget *widget = currentWidgets[widgetIndex++];
                [self addWidget:widget atMatrixCode:matrixCode];
            } else {
                // Placeholders for empty
                BaseWidget *placeholder = [[BaseWidget alloc] initWithType:@"BaseWidget"];
                [placeholder loadView];
                [self addWidget:placeholder atMatrixCode:matrixCode];
            }
        }
    }
    if (currentWidgets.count > maxWidgetsForNewTemplate) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Template Change";
        alert.informativeText = [NSString stringWithFormat:
            @"New template supports %ld widgets. %ld widgets were removed.",
            (long)maxWidgetsForNewTemplate,
            (long)(currentWidgets.count - maxWidgetsForNewTemplate)];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
    NSLog(@"✅ GridWindow: Template changed successfully");
}

#pragma mark - Widget Transformation

- (void)transformWidget:(BaseWidget *)oldWidget toType:(NSString *)newType {
    NSLog(@"🔄 GridWindow: Transforming widget to type: %@", newType);
    NSString *matrixCode = nil;
    for (NSString *code in self.widgetPositions) {
        if (self.widgetPositions[code] == oldWidget) {
            matrixCode = code;
            break;
        }
    }
    if (!matrixCode) {
        NSLog(@"❌ GridWindow: Could not find matrix code for widget");
        return;
    }
    Class widgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:newType];
    if (!widgetClass) {
        NSLog(@"❌ GridWindow: No class found for type: %@", newType);
        return;
    }
    BaseWidget *newWidget = [[widgetClass alloc] initWithType:newType];
    [newWidget loadView];
    newWidget.widgetID = oldWidget.widgetID;
    newWidget.chainActive = oldWidget.chainActive;
    newWidget.chainColor = oldWidget.chainColor;
    [oldWidget.view removeFromSuperview];
    [self.widgets removeObject:oldWidget];
    [self.widgetPositions removeObjectForKey:matrixCode];
    [self addWidget:newWidget atMatrixCode:matrixCode];
    if (self.appDelegate) {
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];
    }
    NSLog(@"✅ GridWindow: Widget transformed successfully");
}

#pragma mark - Action Methods

- (void)templateSelectorChanged:(NSPopUpButton *)sender {
    NSMenuItem *selectedItem = [sender selectedItem];
    GridTemplateType newType = [selectedItem representedObject];
    
    if (![newType isEqualToString:self.currentTemplate.templateType]) {
        [self changeTemplate:newType];
    }
}

- (void)addWidgetButtonClicked:(NSButton *)sender {
    NSLog(@"➕ GridWindow: Add widget button clicked");
    
    // Check if grid is full
    if (self.widgets.count >= self.currentTemplate.maxWidgets) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Grid Full";
        alert.informativeText = [NSString stringWithFormat:
            @"This template supports maximum %ld widgets.",
            (long)self.currentTemplate.maxWidgets];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Show widget type selector
    [self showWidgetTypeSelector];
}

- (void)showWidgetTypeSelector {
    NSMenu *menu = [[NSMenu alloc] init];
    
    NSArray *widgetTypes = [[WidgetTypeManager sharedManager] availableWidgetTypes];
    for (NSString *widgetType in widgetTypes) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:widgetType
                                                      action:@selector(addWidgetOfType:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = widgetType;
        [menu addItem:item];
    }
    
    // Show menu at button
    NSPoint location = NSMakePoint(0, self.addWidgetButton.bounds.size.height);
    [menu popUpMenuPositioningItem:nil atLocation:location inView:self.addWidgetButton];
}

- (void)addWidgetOfType:(NSMenuItem *)sender {
    NSString *widgetType = [sender representedObject];
    NSLog(@"➕ GridWindow: Adding widget of type: %@", widgetType);
    // Find next available matrix position
    NSString *nextMatrix = nil;
    for (NSInteger r = 1; r <= self.rows; r++) {
        for (NSInteger c = 1; c <= self.cols; c++) {
            NSString *code = [NSString stringWithFormat:@"%ld%ld", (long)r, (long)c];
            BaseWidget *existing = self.widgetPositions[code];
            if (!existing || [existing.widgetType isEqualToString:@"BaseWidget"]) {
                nextMatrix = code;
                goto found;
            }
        }
    }
found:
    if (!nextMatrix) {
        NSLog(@"⚠️ GridWindow: No available matrix cell");
        return;
    }
    // Remove placeholder if present
    BaseWidget *existing = self.widgetPositions[nextMatrix];
    if (existing && [existing.widgetType isEqualToString:@"BaseWidget"]) {
        [self removeWidget:existing];
    }
    Class widgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:widgetType];
    BaseWidget *widget = [[widgetClass alloc] initWithType:widgetType];
    [widget loadView];
    [self addWidget:widget atMatrixCode:nextMatrix];
}

- (void)settingsButtonClicked:(NSButton *)sender {
    NSLog(@"⚙️ GridWindow: Settings button clicked");
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Rename grid
    NSMenuItem *renameItem = [[NSMenuItem alloc] initWithTitle:@"Rename Grid..."
                                                        action:@selector(renameGrid:)
                                                 keyEquivalent:@""];
    renameItem.target = self;
    [menu addItem:renameItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Save as preset
    NSMenuItem *saveItem = [[NSMenuItem alloc] initWithTitle:@"Save as Preset..."
                                                      action:@selector(saveAsPreset:)
                                               keyEquivalent:@""];
    saveItem.target = self;
    [menu addItem:saveItem];
    
    // Show menu
    NSPoint location = NSMakePoint(0, self.settingsButton.bounds.size.height);
    [menu popUpMenuPositioningItem:nil atLocation:location inView:self.settingsButton];
}

- (void)renameGrid:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Grid";
    alert.informativeText = @"Enter a new name for this grid:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = self.gridName;
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        self.gridName = input.stringValue;
        self.title = [NSString stringWithFormat:@"Grid: %@", self.gridName];
        NSLog(@"✅ GridWindow: Renamed to: %@", self.gridName);
    }
}

- (void)saveAsPreset:(id)sender {
    NSLog(@"💾 GridWindow: Save as preset - TODO");
    // TODO: Implement preset saving via WorkspaceManager
}

#pragma mark - Serialization

- (NSDictionary *)serializeState {
    NSMutableArray *widgetStates = [NSMutableArray array];
    for (NSString *matrixCode in self.widgetPositions) {
        BaseWidget *widget = self.widgetPositions[matrixCode];
        NSDictionary *widgetState = [widget serializeState];
        NSMutableDictionary *positionedState = [widgetState mutableCopy];
        positionedState[@"matrixCode"] = matrixCode;
        positionedState[@"widgetClass"] = NSStringFromClass([widget class]);
        // Save frame for proportional resizing
        if (widget.view) {
            positionedState[@"widgetFrame"] = NSStringFromRect(widget.view.frame);
        }
        [widgetStates addObject:positionedState];
    }
    return @{
        @"gridName": self.gridName,
        @"templateType": self.currentTemplate.templateType,
        @"frame": NSStringFromRect(self.frame),
        @"rows": @(self.rows),
        @"cols": @(self.cols),
        @"widgets": widgetStates
    };
}

- (void)restoreState:(NSDictionary *)state {
    NSLog(@"🔄 GridWindow: Restoring state...");
    NSString *frameString = state[@"frame"];
    if (frameString) {
        NSRect frame = NSRectFromString(frameString);
        if (!NSIsEmptyRect(frame)) {
            [self setFrame:frame display:NO];
        }
    }
    self.gridName = state[@"gridName"] ?: @"Untitled Grid";
    self.title = [NSString stringWithFormat:@"Grid: %@", self.gridName];
    GridTemplateType templateType = state[@"templateType"];
    if (templateType) {
        self.currentTemplate = [GridTemplate templateWithType:templateType];
        [self configureGridForTemplate:self.currentTemplate];
        [self setupLayout];
    }
    if (state[@"rows"]) self.rows = [state[@"rows"] integerValue];
    if (state[@"cols"]) self.cols = [state[@"cols"] integerValue];
    NSArray *widgetStates = state[@"widgets"];
    for (NSDictionary *widgetState in widgetStates) {
        NSString *widgetClassName = widgetState[@"widgetClass"];
        NSString *matrixCode = widgetState[@"matrixCode"];
        Class widgetClass = NSClassFromString(widgetClassName);
        if (!widgetClass) {
            NSLog(@"⚠️ GridWindow: Unknown widget class: %@", widgetClassName);
            continue;
        }
        NSString *widgetType = widgetState[@"widgetType"];
        BaseWidget *widget = [[widgetClass alloc] initWithType:widgetType];
        [widget loadView];
        [widget restoreState:widgetState];
        [self addWidget:widget atMatrixCode:matrixCode];
        // Restore frame if present (proportional resizing will adjust on window resize)
        if (widgetState[@"widgetFrame"]) {
            NSRect wframe = NSRectFromString(widgetState[@"widgetFrame"]);
            widget.view.frame = wframe;
        }
    }
    NSLog(@"✅ GridWindow: State restored with %ld widgets", (long)self.widgets.count);
}

#pragma mark - Proportional Resize

- (void)resizeAllWidgetsProportionally {
    CGFloat w = self.containerView.bounds.size.width / self.cols;
    CGFloat h = self.containerView.bounds.size.height / self.rows;
    for (NSString *matrixCode in self.widgetPositions) {
        BaseWidget *widget = self.widgetPositions[matrixCode];
        NSInteger row = [[matrixCode substringToIndex:1] integerValue];
        NSInteger col = [[matrixCode substringFromIndex:1] integerValue];
        CGFloat x = (col - 1) * w;
        CGFloat y = self.containerView.bounds.size.height - (row * h);
        widget.view.frame = NSMakeRect(x, y, w, h);
    }
}

- (void)windowDidResize:(NSNotification *)notification {
    [self resizeAllWidgetsProportionally];
}

#pragma mark - NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMinCoordinate:(CGFloat)proposedMinimumPosition
         ofSubviewAt:(NSInteger)dividerIndex {
    return proposedMinimumPosition < 100 ? 100 : proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMaxCoordinate:(CGFloat)proposedMaximumPosition
         ofSubviewAt:(NSInteger)dividerIndex {
    CGFloat maxPosition = (splitView.isVertical ? splitView.bounds.size.width : splitView.bounds.size.height) - 100;
    return proposedMaximumPosition > maxPosition ? maxPosition : proposedMaximumPosition;
}

#pragma mark - NSWindowDelegate

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    NSLog(@"🪟 GridWindow: Window closing");
    for (BaseWidget *widget in self.widgets) {
        widget.onTypeChange = nil;
        widget.onRemoveRequest = nil;
    }
    if (self.appDelegate) {
        [self.appDelegate unregisterGridWindow:self];
    }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (self.widgets.count > 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Close Grid?";
        alert.informativeText = [NSString stringWithFormat:
            @"This grid contains %ld widget(s). Close anyway?",
            (long)self.widgets.count];
        [alert addButtonWithTitle:@"Close"];
        [alert addButtonWithTitle:@"Cancel"];
        return [alert runModal] == NSAlertFirstButtonReturn;
    }
    return YES;
}

@end
