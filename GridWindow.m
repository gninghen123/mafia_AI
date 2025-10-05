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

@interface GridWindow ()
@property (nonatomic, strong) NSView *containerView;
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
        
        NSLog(@"🏗️ GridWindow: Created with template: %@", _currentTemplate.displayName);
    }
    
    return self;
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

- (void)addWidget:(BaseWidget *)widget atPosition:(GridPosition)position {
    if (!widget) {
        NSLog(@"⚠️ GridWindow: Cannot add nil widget");
        return;
    }
    
    // Check if position is valid for current template
    if (![self.currentTemplate.availablePositions containsObject:position]) {
        NSLog(@"⚠️ GridWindow: Position %@ not available in template %@", position, self.currentTemplate.displayName);
        return;
    }
    
    // Check if position already occupied
    if (self.widgetPositions[position]) {
        NSLog(@"⚠️ GridWindow: Position %@ already occupied", position);
        return;
    }
    
    NSLog(@"➕ GridWindow: Adding widget %@ at position %@", widget.widgetType, position);
    
    // Add widget to tracking
    [self.widgets addObject:widget];
    self.widgetPositions[position] = widget;
    
    // Setup widget callbacks
    [self setupCallbacksForWidget:widget];
    
    // Add widget view to layout
    [self insertWidgetIntoLayout:widget atPosition:position];
    
    NSLog(@"✅ GridWindow: Widget added successfully. Total widgets: %ld", (long)self.widgets.count);
}

- (void)setupCallbacksForWidget:(BaseWidget *)widget {
    __weak typeof(self) weakSelf = self;
    
    widget.onTypeChange = ^(BaseWidget *sourceWidget, NSString *newType) {
        [weakSelf transformWidget:sourceWidget toType:newType];
    };
    
    widget.onRemoveRequest = ^(BaseWidget *widgetToRemove) {
        [weakSelf removeWidget:widgetToRemove];
    };
    
    // onAddRequest rimosso - non serve nel grid
}

- (void)insertWidgetIntoLayout:(BaseWidget *)widget atPosition:(GridPosition)position {
    NSView *widgetView = widget.view;
    
    if ([self.currentTemplate.templateType isEqualToString:GridTemplateTypeListChart]) {
        [self insertWidgetForListChart:widgetView atPosition:position];
        
    } else if ([self.currentTemplate.templateType isEqualToString:GridTemplateTypeListDualChart]) {
        [self insertWidgetForListDualChart:widgetView atPosition:position];
        
    } else if ([self.currentTemplate.templateType isEqualToString:GridTemplateTypeTripleHorizontal]) {
        [self insertWidgetForTripleHorizontal:widgetView atPosition:position];
        
    } else if ([self.currentTemplate.templateType isEqualToString:GridTemplateTypeQuad]) {
        [self insertWidgetForQuad:widgetView atPosition:position];
    }
}

#pragma mark - Layout Insertion Methods

- (void)insertWidgetForListChart:(NSView *)widgetView atPosition:(GridPosition)position {
    // Simple 2-panel: left (30%) | right (70%)
    [self.mainSplitView addArrangedSubview:widgetView];
    
    // Set split position after layout
    if (self.mainSplitView.subviews.count == 2) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CGFloat position = self.mainSplitView.bounds.size.width * 0.30;
            [self.mainSplitView setPosition:position ofDividerAtIndex:0];
        });
    }
}

- (void)insertWidgetForListDualChart:(NSView *)widgetView atPosition:(GridPosition)position {
    // Left (25%) | Right split (top 50% | bottom 50%)
    
    if ([position isEqualToString:GridPositionLeft]) {
        // Add to main split left
        [self.mainSplitView addArrangedSubview:widgetView];
        
    } else {
        // Need right split view
        NSSplitView *rightSplit = nil;
        for (NSView *subview in self.mainSplitView.arrangedSubviews) {
            if ([subview isKindOfClass:[NSSplitView class]]) {
                rightSplit = (NSSplitView *)subview;
                break;
            }
        }
        
        if (!rightSplit) {
            // Create right split if doesn't exist
            rightSplit = [[NSSplitView alloc] init];
            rightSplit.vertical = NO;
            rightSplit.dividerStyle = NSSplitViewDividerStyleThin;
            rightSplit.delegate = self;
            [self.mainSplitView addArrangedSubview:rightSplit];
        }
        
        [rightSplit addArrangedSubview:widgetView];
        
        // Set positions after layout
        if (self.mainSplitView.arrangedSubviews.count == 2 && rightSplit.arrangedSubviews.count == 2) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.mainSplitView setPosition:self.mainSplitView.bounds.size.width * 0.25 ofDividerAtIndex:0];
                [rightSplit setPosition:rightSplit.bounds.size.height * 0.50 ofDividerAtIndex:0];
            });
        }
    }
}

- (void)insertWidgetForTripleHorizontal:(NSView *)widgetView atPosition:(GridPosition)position {
    // Three equal horizontal sections
    [self.mainSplitView addArrangedSubview:widgetView];
    
    // Set equal positions after all added
    if (self.mainSplitView.arrangedSubviews.count == 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CGFloat width = self.mainSplitView.bounds.size.width;
            [self.mainSplitView setPosition:width * 0.33 ofDividerAtIndex:0];
            [self.mainSplitView setPosition:width * 0.67 ofDividerAtIndex:1];
        });
    }
}

- (void)insertWidgetForQuad:(NSView *)widgetView atPosition:(GridPosition)position {
    // 2x2 grid: top split (left|right) / bottom split (left|right)
    
    NSSplitView *topSplit = nil;
    NSSplitView *bottomSplit = nil;
    
    // Find or create splits
    for (NSView *subview in self.mainSplitView.arrangedSubviews) {
        if ([subview isKindOfClass:[NSSplitView class]]) {
            if (!topSplit) {
                topSplit = (NSSplitView *)subview;
            } else {
                bottomSplit = (NSSplitView *)subview;
            }
        }
    }
    
    if (!topSplit) {
        topSplit = [[NSSplitView alloc] init];
        topSplit.vertical = YES;
        topSplit.dividerStyle = NSSplitViewDividerStyleThin;
        topSplit.delegate = self;
        [self.mainSplitView addArrangedSubview:topSplit];
    }
    
    if (!bottomSplit) {
        bottomSplit = [[NSSplitView alloc] init];
        bottomSplit.vertical = YES;
        bottomSplit.dividerStyle = NSSplitViewDividerStyleThin;
        bottomSplit.delegate = self;
        [self.mainSplitView addArrangedSubview:bottomSplit];
    }
    
    // Add to appropriate split
    if ([position isEqualToString:GridPositionTopLeft] || [position isEqualToString:GridPositionTopRight]) {
        [topSplit addArrangedSubview:widgetView];
    } else {
        [bottomSplit addArrangedSubview:widgetView];
    }
    
    // Set positions after all added
    if (topSplit.arrangedSubviews.count == 2 && bottomSplit.arrangedSubviews.count == 2) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mainSplitView setPosition:self.mainSplitView.bounds.size.height * 0.50 ofDividerAtIndex:0];
            [topSplit setPosition:topSplit.bounds.size.width * 0.50 ofDividerAtIndex:0];
            [bottomSplit setPosition:bottomSplit.bounds.size.width * 0.50 ofDividerAtIndex:0];
        });
    }
}

#pragma mark - Widget Removal

- (void)removeWidget:(BaseWidget *)widget {
    if (![self.widgets containsObject:widget]) {
        NSLog(@"⚠️ GridWindow: Widget not found in grid");
        return;
    }
    
    NSLog(@"🗑️ GridWindow: Removing widget %@", widget.widgetType);
    
    // Find and remove from position tracking
    GridPosition positionToRemove = nil;
    for (GridPosition position in self.widgetPositions) {
        if (self.widgetPositions[position] == widget) {
            positionToRemove = position;
            break;
        }
    }
    
    if (positionToRemove) {
        [self.widgetPositions removeObjectForKey:positionToRemove];
    }
    
    // Remove from widgets array
    [self.widgets removeObject:widget];
    
    // Remove view from hierarchy
    [widget.view removeFromSuperview];
    
    NSLog(@"✅ GridWindow: Widget removed. Remaining widgets: %ld", (long)self.widgets.count);
    
    // Close window if no widgets left
    if (self.widgets.count == 0) {
        NSLog(@"🪟 GridWindow: No widgets remaining, closing window");
        [self close];
    }
}

- (BaseWidget *)detachWidget:(BaseWidget *)widget {
    if (![self.widgets containsObject:widget]) {
        return nil;
    }
    
    NSLog(@"📤 GridWindow: Detaching widget %@", widget.widgetType);
    
    // Remove from grid (but don't deallocate)
    GridPosition positionToRemove = nil;
    for (GridPosition position in self.widgetPositions) {
        if (self.widgetPositions[position] == widget) {
            positionToRemove = position;
            break;
        }
    }
    
    if (positionToRemove) {
        [self.widgetPositions removeObjectForKey:positionToRemove];
    }
    
    [self.widgets removeObject:widget];
    [widget.view removeFromSuperview];
    
    // Clear callbacks (will be reassigned by new FloatingWindow)
    widget.onTypeChange = nil;
    widget.onRemoveRequest = nil;
    // onAddRequest rimosso
    
    NSLog(@"✅ GridWindow: Widget detached successfully");
    
    // Close if empty
    if (self.widgets.count == 0) {
        [self close];
    }
    
    return widget;
}

#pragma mark - Template Management

- (void)changeTemplate:(GridTemplateType)newTemplateType {
    NSLog(@"🔄 GridWindow: Changing template from %@ to %@",
          self.currentTemplate.displayName, newTemplateType);
    
    // Save current widgets
    NSArray *currentWidgets = [self.widgets copy];
    
    // Clear current layout
    for (BaseWidget *widget in currentWidgets) {
        [widget.view removeFromSuperview];
    }
    [self.widgets removeAllObjects];
    [self.widgetPositions removeAllObjects];
    
    // Set new template
    self.currentTemplate = [GridTemplate templateWithType:newTemplateType];
    
    // Rebuild layout
    [self setupLayout];
    
    // Re-add widgets if they fit
    NSInteger maxWidgetsForNewTemplate = self.currentTemplate.maxWidgets;
    NSInteger widgetsToAdd = MIN(currentWidgets.count, maxWidgetsForNewTemplate);
    
    for (NSInteger i = 0; i < widgetsToAdd; i++) {
        BaseWidget *widget = currentWidgets[i];
        GridPosition position = [self.currentTemplate positionForWidgetAtIndex:i];
        [self addWidget:widget atPosition:position];
    }
    
    // Alert if widgets were lost
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
    
    // Find widget position
    GridPosition position = nil;
    for (GridPosition pos in self.widgetPositions) {
        if (self.widgetPositions[pos] == oldWidget) {
            position = pos;
            break;
        }
    }
    
    if (!position) {
        NSLog(@"❌ GridWindow: Could not find position for widget");
        return;
    }
    
    // Create new widget
    Class widgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:newType];
    if (!widgetClass) {
        NSLog(@"❌ GridWindow: No class found for type: %@", newType);
        return;
    }
    
    BaseWidget *newWidget = [[widgetClass alloc] initWithType:newType];
    [newWidget loadView];
    
    // Copy state
    newWidget.widgetID = oldWidget.widgetID;
    newWidget.chainActive = oldWidget.chainActive;
    newWidget.chainColor = oldWidget.chainColor;
    
    // Remove old widget
    [oldWidget.view removeFromSuperview];
    [self.widgets removeObject:oldWidget];
    [self.widgetPositions removeObjectForKey:position];
    
    // Add new widget
    [self addWidget:newWidget atPosition:position];
    
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
    
    // Find next available position
    GridPosition nextPosition = nil;
    for (GridPosition position in self.currentTemplate.availablePositions) {
        if (!self.widgetPositions[position]) {
            nextPosition = position;
            break;
        }
    }
    
    if (!nextPosition) {
        NSLog(@"⚠️ GridWindow: No available position");
        return;
    }
    
    // Create widget
    Class widgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:widgetType];
    BaseWidget *widget = [[widgetClass alloc] initWithType:widgetType];
    [widget loadView];
    
    // Add to grid
    [self addWidget:widget atPosition:nextPosition];
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
    
    for (GridPosition position in self.widgetPositions) {
        BaseWidget *widget = self.widgetPositions[position];
        NSDictionary *widgetState = [widget serializeState];
        
        NSMutableDictionary *positionedState = [widgetState mutableCopy];
        positionedState[@"gridPosition"] = position;
        positionedState[@"widgetClass"] = NSStringFromClass([widget class]);
        
        [widgetStates addObject:positionedState];
    }
    
    return @{
        @"gridName": self.gridName,
        @"templateType": self.currentTemplate.templateType,
        @"frame": NSStringFromRect(self.frame),
        @"widgets": widgetStates
    };
}

- (void)restoreState:(NSDictionary *)state {
    NSLog(@"🔄 GridWindow: Restoring state...");
    
    // Restore frame
    NSString *frameString = state[@"frame"];
    if (frameString) {
        NSRect frame = NSRectFromString(frameString);
        if (!NSIsEmptyRect(frame)) {
            [self setFrame:frame display:NO];
        }
    }
    
    // Restore grid name
    self.gridName = state[@"gridName"] ?: @"Untitled Grid";
    self.title = [NSString stringWithFormat:@"Grid: %@", self.gridName];
    
    // Restore template
    GridTemplateType templateType = state[@"templateType"];
    if (templateType) {
        self.currentTemplate = [GridTemplate templateWithType:templateType];
        [self setupLayout];
    }
    
    // Restore widgets
    NSArray *widgetStates = state[@"widgets"];
    for (NSDictionary *widgetState in widgetStates) {
        NSString *widgetClassName = widgetState[@"widgetClass"];
        GridPosition position = widgetState[@"gridPosition"];
        
        Class widgetClass = NSClassFromString(widgetClassName);
        if (!widgetClass) {
            NSLog(@"⚠️ GridWindow: Unknown widget class: %@", widgetClassName);
            continue;
        }
        
        NSString *widgetType = widgetState[@"widgetType"];
        BaseWidget *widget = [[widgetClass alloc] initWithType:widgetType];
        [widget loadView];
        [widget restoreState:widgetState];
        
        [self addWidget:widget atPosition:position];
    }
    
    NSLog(@"✅ GridWindow: State restored with %ld widgets", (long)self.widgets.count);
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
    
    // Cleanup widgets
    for (BaseWidget *widget in self.widgets) {
        widget.onTypeChange = nil;
        widget.onRemoveRequest = nil;
    }
    
    // Notify AppDelegate to unregister
    if (self.appDelegate) {
        [self.appDelegate unregisterGridWindow:self];
    }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    // Confirm if widgets have unsaved state
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
