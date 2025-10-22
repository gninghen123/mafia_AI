//
//  GridWindow.m (Part 1 of 3)
//  TradingApp
//
//  Grid window implementation - Initialization & Setup
//

#import "GridWindow.h"
#import "BaseWidget.h"
#import "AppDelegate.h"
#import "WidgetTypeManager.h"
#import "WorkspaceManager.h"
#import "GridPresetManager.h"

@interface GridWindow ()
@property (nonatomic, strong) NSView *containerView;
@property (nonatomic, assign, readwrite) NSInteger rows;
@property (nonatomic, assign, readwrite) NSInteger cols;
@end

@implementation GridWindow

#pragma mark - Initialization

- (instancetype)initWithTemplate:(GridTemplate *)template
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
        _rowSplitViews = [NSMutableArray array];
        _currentTemplate = template ?: [GridTemplate templateWithRows:2 cols:2 displayName:@"2×2 Grid"];
        _rows = _currentTemplate.rows;
        _cols = _currentTemplate.cols;
        _gridName = name ?: _currentTemplate.displayName;
        _appDelegate = appDelegate;

        // Window setup
        self.title = [NSString stringWithFormat:@"Grid: %@", _gridName];
        self.delegate = self;
        self.releasedWhenClosed = NO;

        // Configure window
        [self configureWindowBehavior];

        // Setup UI
        [self setupContainerView];
        [self setupAccessoryView];
        [self buildGridLayout];

        // Populate with empty placeholder widgets
        [self populateEmptyCells];

        NSLog(@"🏗️ GridWindow: Created %ldx%ld grid '%@'",
              (long)self.rows, (long)self.cols, self.gridName);
    }
    return self;
}

#pragma mark - Window Configuration

- (void)configureWindowBehavior {
    self.backgroundColor = [NSColor windowBackgroundColor];
    self.hasShadow = YES;
    self.movableByWindowBackground = YES;
    self.minSize = NSMakeSize(600, 400);
}

- (void)setupContainerView {
    self.containerView = [[NSView alloc] initWithFrame:self.contentView.bounds];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.containerView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

- (void)setupAccessoryView {
    NSView *accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 32)];
    
    // Label "Layout:"
    NSTextField *layoutLabel = [[NSTextField alloc] init];
    layoutLabel.translatesAutoresizingMaskIntoConstraints = NO;
    layoutLabel.stringValue = @"Layout:";
    layoutLabel.editable = NO;
    layoutLabel.bordered = NO;
    layoutLabel.backgroundColor = [NSColor clearColor];
    layoutLabel.font = [NSFont systemFontOfSize:11];
    [accessory addSubview:layoutLabel];
    
    // Rows stepper
    self.rowsStepper = [[NSStepper alloc] init];
    self.rowsStepper.translatesAutoresizingMaskIntoConstraints = NO;
    self.rowsStepper.minValue = 1;
    self.rowsStepper.maxValue = 3;
    self.rowsStepper.integerValue = self.rows;
    self.rowsStepper.target = self;
    self.rowsStepper.action = @selector(gridSizeChanged:);
    [accessory addSubview:self.rowsStepper];
    
    // Rows label
    self.rowsLabel = [[NSTextField alloc] init];
    self.rowsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.rowsLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)self.rows];
    self.rowsLabel.editable = NO;
    self.rowsLabel.bordered = NO;
    self.rowsLabel.backgroundColor = [NSColor clearColor];
    self.rowsLabel.alignment = NSTextAlignmentCenter;
    self.rowsLabel.font = [NSFont systemFontOfSize:11];
    [accessory addSubview:self.rowsLabel];
    
    // "×" label
    NSTextField *timesLabel = [[NSTextField alloc] init];
    timesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timesLabel.stringValue = @"×";
    timesLabel.editable = NO;
    timesLabel.bordered = NO;
    timesLabel.backgroundColor = [NSColor clearColor];
    timesLabel.font = [NSFont systemFontOfSize:11];
    [accessory addSubview:timesLabel];
    
    // Cols stepper
    self.colsStepper = [[NSStepper alloc] init];
    self.colsStepper.translatesAutoresizingMaskIntoConstraints = NO;
    self.colsStepper.minValue = 1;
    self.colsStepper.maxValue = 3;
    self.colsStepper.integerValue = self.cols;
    self.colsStepper.target = self;
    self.colsStepper.action = @selector(gridSizeChanged:);
    [accessory addSubview:self.colsStepper];
    
    // Cols label
    self.colsLabel = [[NSTextField alloc] init];
    self.colsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.colsLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)self.cols];
    self.colsLabel.editable = NO;
    self.colsLabel.bordered = NO;
    self.colsLabel.backgroundColor = [NSColor clearColor];
    self.colsLabel.alignment = NSTextAlignmentCenter;
    self.colsLabel.font = [NSFont systemFontOfSize:11];
    [accessory addSubview:self.colsLabel];
    
    // Add Widget button
    self.addWidgetButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameAddTemplate]
                                               target:self
                                               action:@selector(addWidgetButtonClicked:)];
    self.addWidgetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addWidgetButton.bezelStyle = NSBezelStyleRounded;
    self.addWidgetButton.bordered = YES;
    [accessory addSubview:self.addWidgetButton];
    
    // Settings button
    self.settingsButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameActionTemplate]
                                              target:self
                                              action:@selector(settingsButtonClicked:)];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingsButton.bezelStyle = NSBezelStyleRounded;
    self.settingsButton.bordered = YES;
    [accessory addSubview:self.settingsButton];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Layout label
        [layoutLabel.leadingAnchor constraintEqualToAnchor:accessory.leadingAnchor constant:8],
        [layoutLabel.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        
        // Rows: label + stepper
        [self.rowsLabel.leadingAnchor constraintEqualToAnchor:layoutLabel.trailingAnchor constant:8],
        [self.rowsLabel.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        [self.rowsLabel.widthAnchor constraintEqualToConstant:20],
        
        [self.rowsStepper.leadingAnchor constraintEqualToAnchor:self.rowsLabel.trailingAnchor constant:2],
        [self.rowsStepper.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        
        // ×
        [timesLabel.leadingAnchor constraintEqualToAnchor:self.rowsStepper.trailingAnchor constant:8],
        [timesLabel.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        
        // Cols: label + stepper
        [self.colsLabel.leadingAnchor constraintEqualToAnchor:timesLabel.trailingAnchor constant:8],
        [self.colsLabel.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        [self.colsLabel.widthAnchor constraintEqualToConstant:20],
        
        [self.colsStepper.leadingAnchor constraintEqualToAnchor:self.colsLabel.trailingAnchor constant:2],
        [self.colsStepper.centerYAnchor constraintEqualToAnchor:accessory.centerYAnchor],
        
        // Buttons
        [self.addWidgetButton.leadingAnchor constraintEqualToAnchor:self.colsStepper.trailingAnchor constant:16],
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

#pragma mark - Grid Layout Building

- (void)buildGridLayout {
    // Clear existing layout
    [self.containerView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.rowSplitViews removeAllObjects];
    
    // Create main vertical split view (for rows)
    self.mainSplitView = [[NSSplitView alloc] init];
    self.mainSplitView.vertical = NO; // Horizontal dividers = vertical split
    self.mainSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.mainSplitView.delegate = self;
    self.mainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.mainSplitView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.mainSplitView.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [self.mainSplitView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.mainSplitView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [self.mainSplitView.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor]
    ]];
    
    // Create one horizontal split view for each row
    for (NSInteger r = 0; r < self.rows; r++) {
        NSSplitView *rowSplit = [[NSSplitView alloc] init];
        rowSplit.vertical = YES; // Vertical dividers = horizontal split
        rowSplit.dividerStyle = NSSplitViewDividerStyleThin;
        rowSplit.delegate = self;
        [self.rowSplitViews addObject:rowSplit];
        [self.mainSplitView addArrangedSubview:rowSplit];
        
        // Create container views for each column in this row
        for (NSInteger c = 0; c < self.cols; c++) {
            NSView *cellContainer = [[NSView alloc] init];
            cellContainer.wantsLayer = YES;
            cellContainer.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
            [rowSplit addArrangedSubview:cellContainer];
        }
    }
    
    // Apply proportions from template
    [self applyProportionsFromTemplate];
    
    NSLog(@"🏗️ GridWindow: Built %ldx%ld grid layout", (long)self.rows, (long)self.cols);
}

- (void)populateEmptyCells {
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
    
    // Validate matrix code format and bounds
    if (matrixCode.length != 2) {
        NSLog(@"⚠️ GridWindow: Invalid matrix code format: %@", matrixCode);
        return;
    }
    
    NSInteger row = [[matrixCode substringToIndex:1] integerValue];
    NSInteger col = [[matrixCode substringFromIndex:1] integerValue];
    
    if (row < 1 || row > self.rows || col < 1 || col > self.cols) {
        NSLog(@"⚠️ GridWindow: Matrix code %@ out of bounds (%ldx%ld grid)",
              matrixCode, (long)self.rows, (long)self.cols);
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
    [self insertWidgetIntoCell:widget atMatrixCode:matrixCode];
    
    NSLog(@"✅ GridWindow: Widget added. Total widgets: %ld", (long)self.widgets.count);
}

- (void)insertWidgetIntoCell:(BaseWidget *)widget atMatrixCode:(NSString *)matrixCode {
    NSInteger row = [[matrixCode substringToIndex:1] integerValue];
    NSInteger col = [[matrixCode substringFromIndex:1] integerValue];
    
    // Get the row split view (0-indexed)
    if (row - 1 >= self.rowSplitViews.count) {
        NSLog(@"❌ GridWindow: Row index out of bounds");
        return;
    }
    
    NSSplitView *rowSplit = self.rowSplitViews[row - 1];
    
    // Get the cell container (0-indexed)
    if (col - 1 >= rowSplit.arrangedSubviews.count) {
        NSLog(@"❌ GridWindow: Column index out of bounds");
        return;
    }
    
    NSView *cellContainer = rowSplit.arrangedSubviews[col - 1];
    
    // Remove any existing widget view in this cell
    [cellContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    // Add widget view to cell container
    NSView *widgetView = widget.view;
    widgetView.translatesAutoresizingMaskIntoConstraints = NO;
    [cellContainer addSubview:widgetView];
    
    [NSLayoutConstraint activateConstraints:@[
        [widgetView.topAnchor constraintEqualToAnchor:cellContainer.topAnchor],
        [widgetView.leadingAnchor constraintEqualToAnchor:cellContainer.leadingAnchor],
        [widgetView.trailingAnchor constraintEqualToAnchor:cellContainer.trailingAnchor],
        [widgetView.bottomAnchor constraintEqualToAnchor:cellContainer.bottomAnchor]
    ]];
}

- (void)removeWidget:(BaseWidget *)widget {
    if (![self.widgets containsObject:widget]) {
        NSLog(@"⚠️ GridWindow: Widget not found in grid");
        return;
    }
    
    NSLog(@"🗑️ GridWindow: Removing widget %@", widget.widgetType);
    
    // Find and remove from positions
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
    
    NSLog(@"✅ GridWindow: Widget removed. Remaining: %ld", (long)self.widgets.count);
    
    // Close window if no widgets remain
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
    
    // Find matrix code
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
    
    // Clear callbacks
    widget.onTypeChange = nil;
    widget.onRemoveRequest = nil;
    
    if (self.widgets.count == 0) {
        [self close];
    }
    
    return widget;
}

- (void)transformWidget:(BaseWidget *)oldWidget toType:(NSString *)newType {
    NSLog(@"🔄 GridWindow: Transforming widget to type: %@", newType);
    
    // Find matrix code
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
    
    // Get widget class
    Class widgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:newType];
    if (!widgetClass) {
        NSLog(@"❌ GridWindow: No class found for type: %@", newType);
        return;
    }
    
    // Create new widget
    BaseWidget *newWidget = [[widgetClass alloc] initWithType:newType];
    [newWidget loadView];
    
    // Transfer properties
    newWidget.widgetID = oldWidget.widgetID;
    newWidget.chainActive = oldWidget.chainActive;
    newWidget.chainColor = oldWidget.chainColor;
    
    // Replace in grid
    [oldWidget.view removeFromSuperview];
    [self.widgets removeObject:oldWidget];
    [self.widgetPositions removeObjectForKey:matrixCode];
    
    [self addWidget:newWidget atMatrixCode:matrixCode];
    
    // Auto-save workspace
    if (self.appDelegate) {
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];
    }
    
    NSLog(@"✅ GridWindow: Widget transformed successfully");
}

#pragma mark - Layout Updates

- (void)gridSizeChanged:(NSStepper *)sender {
    NSInteger newRows = self.rowsStepper.integerValue;
    NSInteger newCols = self.colsStepper.integerValue;
    
    // Update labels
    self.rowsLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)newRows];
    self.colsLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)newCols];
    
    // Check if dimensions actually changed
    if (newRows == self.rows && newCols == self.cols) {
        return;
    }
    
    NSLog(@"🔄 GridWindow: Grid size changed from %ldx%ld to %ldx%ld",
          (long)self.rows, (long)self.cols, (long)newRows, (long)newCols);
    
    [self updateGridDimensions:newRows cols:newCols];
}

- (void)updateGridDimensions:(NSInteger)newRows cols:(NSInteger)newCols {
    // Calculate widgets that will be lost
    NSInteger oldCapacity = self.rows * self.cols;
    NSInteger newCapacity = newRows * newCols;
    
    // Count non-placeholder widgets
    NSInteger realWidgetCount = 0;
    for (BaseWidget *widget in self.widgets) {
        if (![widget.widgetType isEqualToString:@"BaseWidget"]) {
            realWidgetCount++;
        }
    }
    
    NSInteger widgetsToLose = MAX(0, realWidgetCount - newCapacity);
    
    // Show warning if widgets will be lost
    if (widgetsToLose > 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Grid Resize Warning";
        alert.informativeText = [NSString stringWithFormat:
            @"Resizing to %ldx%ld grid will remove %ld widget(s). Continue?",
            (long)newRows, (long)newCols, (long)widgetsToLose];
        [alert addButtonWithTitle:@"Continue"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSModalResponse response = [alert runModal];
        if (response != NSAlertFirstButtonReturn) {
            // Reset steppers to current values
            self.rowsStepper.integerValue = self.rows;
            self.colsStepper.integerValue = self.cols;
            self.rowsLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)self.rows];
            self.colsLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)self.cols];
            return;
        }
    }
    
    // Proceed with rebuild
    [self rebuildGridLayout];
}

- (void)rebuildGridLayout {
    NSInteger newRows = self.rowsStepper.integerValue;
    NSInteger newCols = self.colsStepper.integerValue;
    
    NSLog(@"🏗️ GridWindow: Rebuilding grid layout to %ldx%ld", (long)newRows, (long)newCols);
    
    // Save existing widgets (excluding placeholders)
    NSMutableArray<BaseWidget *> *existingWidgets = [NSMutableArray array];
    for (BaseWidget *widget in self.widgets) {
        if (![widget.widgetType isEqualToString:@"BaseWidget"]) {
            [existingWidgets addObject:widget];
            [widget.view removeFromSuperview];
        }
    }
    
    // Clear current state
    [self.widgets removeAllObjects];
    [self.widgetPositions removeAllObjects];
    
    // Update dimensions
    self.rows = newRows;
    self.cols = newCols;
    
    // Update template
    self.currentTemplate.rows = newRows;
    self.currentTemplate.cols = newCols;
    [self.currentTemplate resetToUniformProportions];
    self.currentTemplate.displayName = [NSString stringWithFormat:@"%ldx%ld Grid",
                                        (long)newRows, (long)newCols];
    
    // Rebuild UI
    [self buildGridLayout];
    
    // Re-add widgets up to new capacity
    NSInteger widgetIndex = 0;
    NSInteger newCapacity = newRows * newCols;
    
    for (NSInteger r = 1; r <= newRows; r++) {
        for (NSInteger c = 1; c <= newCols; c++) {
            NSString *matrixCode = [NSString stringWithFormat:@"%ld%ld", (long)r, (long)c];
            
            if (widgetIndex < existingWidgets.count) {
                // Add existing widget
                BaseWidget *widget = existingWidgets[widgetIndex++];
                [self addWidget:widget atMatrixCode:matrixCode];
            } else {
                // Add placeholder
                BaseWidget *placeholder = [[BaseWidget alloc] initWithType:@"BaseWidget"];
                [placeholder loadView];
                [self addWidget:placeholder atMatrixCode:matrixCode];
            }
        }
    }
    
    // Update title
    self.gridName = self.currentTemplate.displayName;
    self.title = [NSString stringWithFormat:@"Grid: %@", self.gridName];
    
    NSLog(@"✅ GridWindow: Grid rebuilt successfully with %ld widgets", (long)self.widgets.count);
    
    // Auto-save
    if (self.appDelegate) {
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];
    }
}


#pragma mark - Proportions Management

- (void)captureCurrentProportions {
    if (!self.mainSplitView || self.rowSplitViews.count == 0) {
        NSLog(@"⚠️ GridWindow: Cannot capture proportions - split views not initialized");
        return;
    }
    
    NSMutableArray<NSNumber *> *rowHeights = [NSMutableArray arrayWithCapacity:self.rows];
    NSMutableArray<NSNumber *> *columnWidths = [NSMutableArray arrayWithCapacity:self.cols];
    
    // Capture row heights from main split view
    CGFloat totalHeight = self.mainSplitView.bounds.size.height;
    if (totalHeight > 0) {
        for (NSView *rowView in self.mainSplitView.arrangedSubviews) {
            CGFloat proportion = rowView.frame.size.height / totalHeight;
            [rowHeights addObject:@(proportion)];
        }
    }
    
    // Capture column widths from first row's split view (assuming uniform columns)
    if (self.rowSplitViews.count > 0) {
        NSSplitView *firstRowSplit = self.rowSplitViews[0];
        CGFloat totalWidth = firstRowSplit.bounds.size.width;
        
        if (totalWidth > 0) {
            for (NSView *colView in firstRowSplit.arrangedSubviews) {
                CGFloat proportion = colView.frame.size.width / totalWidth;
                [columnWidths addObject:@(proportion)];
            }
        }
    }
    
    // Update template with captured proportions
    if (rowHeights.count == self.rows && columnWidths.count == self.cols) {
        self.currentTemplate.rowHeights = rowHeights;
        self.currentTemplate.columnWidths = columnWidths;
        
        NSLog(@"📏 GridWindow: Captured proportions - Rows: %@, Cols: %@", rowHeights, columnWidths);
    } else {
        NSLog(@"⚠️ GridWindow: Proportion count mismatch - expected %ldx%ld, got %ldx%ld",
              (long)self.rows, (long)self.cols,
              (long)rowHeights.count, (long)columnWidths.count);
    }
}

- (void)applyProportionsFromTemplate {
    if (![self.currentTemplate validateProportions]) {
        NSLog(@"⚠️ GridWindow: Invalid template proportions, using uniform");
        [self.currentTemplate resetToUniformProportions];
    }
    
    // Apply proportions after a short delay to ensure layout is complete
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self applyRowProportions];
        [self applyColumnProportions];
    });
    
    NSLog(@"📐 GridWindow: Applied proportions from template");
}

- (void)applyRowProportions {
    if (self.mainSplitView.arrangedSubviews.count != self.currentTemplate.rowHeights.count) {
        return;
    }
    
    CGFloat totalHeight = self.mainSplitView.bounds.size.height;
    if (totalHeight <= 0) return;
    
    // Calculate target positions for dividers
    CGFloat currentY = 0;
    for (NSInteger i = 0; i < self.currentTemplate.rowHeights.count - 1; i++) {
        CGFloat proportion = [self.currentTemplate.rowHeights[i] doubleValue];
        currentY += totalHeight * proportion;
        
        // Set divider position
        [self.mainSplitView setPosition:currentY ofDividerAtIndex:i];
    }
}

- (void)applyColumnProportions {
    for (NSSplitView *rowSplit in self.rowSplitViews) {
        if (rowSplit.arrangedSubviews.count != self.currentTemplate.columnWidths.count) {
            continue;
        }
        
        CGFloat totalWidth = rowSplit.bounds.size.width;
        if (totalWidth <= 0) continue;
        
        // Calculate target positions for dividers
        CGFloat currentX = 0;
        for (NSInteger i = 0; i < self.currentTemplate.columnWidths.count - 1; i++) {
            CGFloat proportion = [self.currentTemplate.columnWidths[i] doubleValue];
            currentX += totalWidth * proportion;
            
            // Set divider position
            [rowSplit setPosition:currentX ofDividerAtIndex:i];
        }
    }
}

#pragma mark - NSSplitViewDelegate

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    // Automatically capture proportions when user drags dividers
    [self captureCurrentProportions];
}

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMinCoordinate:(CGFloat)proposedMinimumPosition
         ofSubviewAt:(NSInteger)dividerIndex {
    return proposedMinimumPosition < 100 ? 100 : proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMaxCoordinate:(CGFloat)proposedMaximumPosition
         ofSubviewAt:(NSInteger)dividerIndex {
    CGFloat maxPosition = (splitView.isVertical ?
                          splitView.bounds.size.width :
                          splitView.bounds.size.height) - 100;
    return proposedMaximumPosition > maxPosition ? maxPosition : proposedMaximumPosition;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    return NO; // Prevent collapsing cells
}

#pragma mark - Action Methods

- (void)addWidgetButtonClicked:(NSButton *)sender {
    NSLog(@"➕ GridWindow: Add widget button clicked");
    
    // Check if grid is full (no BaseWidget placeholders)
    BOOL hasFreeCell = NO;
    for (BaseWidget *widget in self.widgets) {
        if ([widget.widgetType isEqualToString:@"BaseWidget"]) {
            hasFreeCell = YES;
            break;
        }
    }
    
    if (!hasFreeCell) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Grid Full";
        alert.informativeText = [NSString stringWithFormat:
            @"This %ldx%ld grid is full (%ld widgets). Remove a widget or resize the grid.",
            (long)self.rows, (long)self.cols, (long)(self.rows * self.cols)];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
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
    
    // Find first free cell (BaseWidget placeholder)
    NSString *targetMatrix = nil;
    for (NSInteger r = 1; r <= self.rows; r++) {
        for (NSInteger c = 1; c <= self.cols; c++) {
            NSString *code = [NSString stringWithFormat:@"%ld%ld", (long)r, (long)c];
            BaseWidget *existing = self.widgetPositions[code];
            if (existing && [existing.widgetType isEqualToString:@"BaseWidget"]) {
                targetMatrix = code;
                goto found;
            }
        }
    }
found:
    
    if (!targetMatrix) {
        NSLog(@"⚠️ GridWindow: No free cell found");
        return;
    }
    
    // Remove placeholder
    BaseWidget *placeholder = self.widgetPositions[targetMatrix];
    if (placeholder) {
        [self.widgets removeObject:placeholder];
        [placeholder.view removeFromSuperview];
        [self.widgetPositions removeObjectForKey:targetMatrix];
    }
    
    // Create new widget
    Class widgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:widgetType];
    if (!widgetClass) {
        NSLog(@"❌ GridWindow: Unknown widget type: %@", widgetType);
        return;
    }
    
    BaseWidget *newWidget = [[widgetClass alloc] initWithType:widgetType];
    [newWidget loadView];
    [self addWidget:newWidget atMatrixCode:targetMatrix];
    
    // Auto-save
    if (self.appDelegate) {
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];
    }
    
    NSLog(@"✅ GridWindow: Widget %@ added at %@", widgetType, targetMatrix);
}

- (void)settingsButtonClicked:(NSButton *)sender {
    NSMenu *menu = [[NSMenu alloc] init];
    
    NSMenuItem *renameItem = [[NSMenuItem alloc] initWithTitle:@"Rename Grid..."
                                                        action:@selector(renameGrid:)
                                                 keyEquivalent:@""];
    renameItem.target = self;
    [menu addItem:renameItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *saveItem = [[NSMenuItem alloc] initWithTitle:@"Save as Preset..."
                                                      action:@selector(saveAsPreset:)
                                               keyEquivalent:@""];
    saveItem.target = self;
    [menu addItem:saveItem];
    
    NSPoint location = NSMakePoint(0, self.settingsButton.bounds.size.height);
    [menu popUpMenuPositioningItem:nil atLocation:location inView:self.settingsButton];
}

- (void)renameGrid:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename Grid";
    alert.informativeText = @"Enter a new name for this grid:";
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = self.gridName;
    alert.accessoryView = input;
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        self.gridName = input.stringValue;
        self.title = [NSString stringWithFormat:@"Grid: %@", self.gridName];
        NSLog(@"✅ GridWindow: Renamed to: %@", self.gridName);
    }
}

- (void)saveAsPreset:(id)sender {
    // Capture current proportions first
    [self captureCurrentProportions];

    // Show dialog to get preset name
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Save Grid as Preset";
    alert.informativeText = [NSString stringWithFormat:@"Save this %ldx%ld grid layout as a reusable preset.\nEnter a name:", (long)self.rows, (long)self.cols];

    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 250, 24)];
    input.placeholderString = @"My Custom Grid";
    input.stringValue = self.gridName;
    alert.accessoryView = input;

    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *presetName = input.stringValue;

        if (presetName.length == 0) {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Invalid Name";
            errorAlert.informativeText = @"Preset name cannot be empty";
            [errorAlert addButtonWithTitle:@"OK"];
            [errorAlert runModal];
            return;
        }

        // Check if preset already exists
        if ([[GridPresetManager sharedManager] presetExistsWithName:presetName]) {
            NSAlert *overwriteAlert = [[NSAlert alloc] init];
            overwriteAlert.messageText = @"Preset Already Exists";
            overwriteAlert.informativeText = [NSString stringWithFormat:@"A preset named '%@' already exists. Overwrite?", presetName];
            [overwriteAlert addButtonWithTitle:@"Overwrite"];
            [overwriteAlert addButtonWithTitle:@"Cancel"];

            if ([overwriteAlert runModal] != NSAlertFirstButtonReturn) {
                return;
            }
        }

        // Save preset
        BOOL success = [[GridPresetManager sharedManager] savePreset:self.currentTemplate
                                                            withName:presetName];

        if (success) {
            NSAlert *successAlert = [[NSAlert alloc] init];
            successAlert.messageText = @"Preset Saved";
            successAlert.informativeText = [NSString stringWithFormat:@"Grid preset '%@' saved successfully.\nYou can now create new grids with this layout from the File > New Grid menu.", presetName];
            [successAlert addButtonWithTitle:@"OK"];
            [successAlert runModal];

            NSLog(@"✅ GridWindow: Saved preset '%@' (%ldx%ld)",
                  presetName, (long)self.rows, (long)self.cols);

            // Notify AppDelegate to refresh menu
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GridPresetsDidChange"
                                                                object:nil];
        } else {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Save Failed";
            errorAlert.informativeText = @"Failed to save preset. Please try again.";
            [errorAlert addButtonWithTitle:@"OK"];
            [errorAlert runModal];

            NSLog(@"❌ GridWindow: Failed to save preset '%@'", presetName);
        }
    }
}

#pragma mark - Serialization

- (NSDictionary *)serializeState {
    // Capture current proportions before saving
    [self captureCurrentProportions];
    
    NSMutableArray *widgetStates = [NSMutableArray array];
    for (NSString *matrixCode in self.widgetPositions) {
        BaseWidget *widget = self.widgetPositions[matrixCode];
        
        // Skip placeholder widgets
        if ([widget.widgetType isEqualToString:@"BaseWidget"]) {
            continue;
        }
        
        NSDictionary *widgetState = [widget serializeState];
        NSMutableDictionary *positionedState = [widgetState mutableCopy];
        positionedState[@"matrixCode"] = matrixCode;
        positionedState[@"widgetClass"] = NSStringFromClass([widget class]);
        [widgetStates addObject:positionedState];
    }
    
    return @{
        @"gridName": self.gridName ?: @"Untitled Grid",
        @"frame": NSStringFromRect(self.frame),
        @"template": [self.currentTemplate serialize],
        @"widgets": widgetStates
    };
}

- (void)restoreState:(NSDictionary *)state {
    NSLog(@"🔄 GridWindow: Restoring state...");
    
    // Restore window frame
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
    NSDictionary *templateDict = state[@"template"];
    if (templateDict) {
        self.currentTemplate = [GridTemplate deserialize:templateDict];
        if (self.currentTemplate) {
            self.rows = self.currentTemplate.rows;
            self.cols = self.currentTemplate.cols;
            
            // Update stepper values
            self.rowsStepper.integerValue = self.rows;
            self.colsStepper.integerValue = self.cols;
            self.rowsLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)self.rows];
            self.colsLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)self.cols];
            
            // Rebuild layout with restored dimensions
            [self buildGridLayout];
        }
    }
    
    // Restore widgets
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
        
        // Remove placeholder if present
        BaseWidget *placeholder = self.widgetPositions[matrixCode];
        if (placeholder) {
            [self.widgets removeObject:placeholder];
            [placeholder.view removeFromSuperview];
            [self.widgetPositions removeObjectForKey:matrixCode];
        }
        
        [self addWidget:widget atMatrixCode:matrixCode];
    }
    
    // Fill remaining cells with placeholders
    [self populateEmptyCells];
    
    NSLog(@"✅ GridWindow: State restored with %ld widgets", (long)self.widgets.count);
}

#pragma mark - Window Delegate

- (void)windowWillClose:(NSNotification *)notification {
    // Capture final proportions before closing
    [self captureCurrentProportions];
    
    // Auto-save workspace
    if (self.appDelegate) {
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];
    }
}

@end
