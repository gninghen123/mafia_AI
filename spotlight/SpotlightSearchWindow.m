//
//  SpotlightSearchWindow.m
//  TradingApp
//
//  Main Spotlight Search Window Implementation
//

#import "SpotlightSearchWindow.h"
#import "GlobalSpotlightManager.h"
#import "AppDelegate.h"
#import "DataHub.h"

static const CGFloat kWindowWidth = 600.0;
static const CGFloat kWindowHeight = 400.0;
static const CGFloat kSearchFieldHeight = 30.0;
static const CGFloat kButtonHeight = 25.0;
static const CGFloat kMargin = 10.0;

@interface SpotlightSearchWindow ()
@property (nonatomic, strong) NSView *contentContainer;
@property (nonatomic, strong) NSView *topBarView;
@property (nonatomic, strong) NSView *tablesView;
@end

@implementation SpotlightSearchWindow

#pragma mark - Initialization

- (instancetype)initWithSpotlightManager:(GlobalSpotlightManager *)spotlightManager {
    NSRect windowFrame = NSMakeRect(0, 0, kWindowWidth, kWindowHeight);
    
    self = [super initWithContentRect:windowFrame
                            styleMask:NSWindowStyleMaskBorderless
                              backing:NSBackingStoreBuffered
                                defer:NO];
    
    if (self) {
        _spotlightManager = spotlightManager;
        _isSymbolsTableActive = YES; // Start with symbols table active
        _selectedSymbolIndex = 0;
        _selectedWidgetIndex = 0;
        
        [self setupWindowAppearance];
        [self createUIComponents];
        [self setupLayoutConstraints];
        
        // Initialize with default widget options
        self.widgetOptions = [WidgetOption defaultWidgetOptions];
        
        NSLog(@"🔍 SpotlightSearchWindow: Initialized");
    }
    return self;
}

#pragma mark - Window Management

- (void)showWithInitialText:(NSString *)initialText {
    // Set initial text
    self.searchField.stringValue = initialText ?: @"";
    self.currentSearchText = initialText ?: @"";
    
    // Reset state
    self.selectedSymbolIndex = 0;
    self.selectedWidgetIndex = 0;
    self.isSymbolsTableActive = YES;
    
    // Center and show window
    [self centerWindow];
    [self makeKeyAndOrderFront:nil];
    
    // Focus search field
    [self makeFirstResponder:self.searchField];
    
    // Update category button states
    [self.dataSourceButton setActiveState:YES];
    [self.widgetTargetButton setActiveState:NO];
    
    // Perform initial search if we have text
    if (initialText.length > 0) {
        [self performSymbolSearch:initialText];
    }
    
    // Filter widgets based on initial text
    [self filterWidgetOptions:initialText ?: @""];
    
    [self updateTableSelections];
    
    NSLog(@"✨ SpotlightSearchWindow: Shown with text: '%@'", initialText);
}

- (void)hideWindow {
    [self orderOut:nil];
    [self resetSearch];
    
    // Cancel any pending search timers
    if (self.searchDelayTimer) {
        [self.searchDelayTimer invalidate];
        self.searchDelayTimer = nil;
    }
}

- (void)centerWindow {
    NSScreen *screen = [NSScreen mainScreen];
    if (screen) {
        NSRect screenFrame = screen.visibleFrame;
        NSRect windowFrame = self.frame;
        
        NSPoint center = NSMakePoint(
            screenFrame.origin.x + (screenFrame.size.width - windowFrame.size.width) / 2,
            screenFrame.origin.y + (screenFrame.size.height - windowFrame.size.height) / 2
        );
        
        [self setFrameOrigin:center];
    }
}

#pragma mark - Search Management

- (void)performSymbolSearch:(NSString *)searchText {
    if (!searchText || searchText.length == 0) {
        self.symbolResults = @[];
        [self.symbolsTable reloadData];
        return;
    }
    
    // Use DataHub to search for symbols
    DataSourceType selectedSource = self.dataSourceButton.selectedDataSource;
    
    [[DataHub shared] searchSymbolsWithQuery:searchText
                                  dataSource:selectedSource
                                       limit:10
                                  completion:^(NSArray<SymbolSearchResult *> *results, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ Symbol search error: %@", error);
                self.symbolResults = @[];
            } else {
                self.symbolResults = results ?: @[];
                NSLog(@"🔍 Found %lu symbol results for '%@'", (unsigned long)self.symbolResults.count, searchText);
            }
            
            // Reset selection to first item
            self.selectedSymbolIndex = 0;
            [self.symbolsTable reloadData];
            [self updateTableSelections];
        });
    }];
}

- (void)filterWidgetOptions:(NSString *)searchText {
    if (!searchText || searchText.length == 0) {
        self.widgetOptions = [WidgetOption defaultWidgetOptions];
    } else {
        NSString *lowercaseSearch = searchText.lowercaseString;
        NSArray<WidgetOption *> *allOptions = [WidgetOption defaultWidgetOptions];
        
        NSMutableArray<WidgetOption *> *filteredOptions = [NSMutableArray array];
        
        for (WidgetOption *option in allOptions) {
            NSString *lowercaseName = option.widgetName.lowercaseString;
            if ([lowercaseName containsString:lowercaseSearch] ||
                [lowercaseName hasPrefix:lowercaseSearch]) {
                [filteredOptions addObject:option];
            }
        }
        
        self.widgetOptions = [filteredOptions copy];
    }
    
    // Reset selection to first item
    self.selectedWidgetIndex = 0;
    [self.widgetsTable reloadData];
    [self updateTableSelections];
}

- (void)resetSearch {
    self.currentSearchText = @"";
    self.symbolResults = @[];
    self.widgetOptions = [WidgetOption defaultWidgetOptions];
    self.selectedSymbolIndex = 0;
    self.selectedWidgetIndex = 0;
    
    [self.symbolsTable reloadData];
    [self.widgetsTable reloadData];
}

#pragma mark - Navigation

- (void)switchActiveTable:(BOOL)toSymbols {
    if (self.isSymbolsTableActive == toSymbols) return;
    
    self.isSymbolsTableActive = toSymbols;
    
    // Update button states
    [self.dataSourceButton setActiveState:toSymbols];
    [self.widgetTargetButton setActiveState:!toSymbols];
    
    [self updateTableSelections];
    
    NSLog(@"🔄 SpotlightSearchWindow: Switched to %@ table", toSymbols ? @"symbols" : @"widgets");
}

- (void)moveSelectionUp {
    if (self.isSymbolsTableActive) {
        if (self.selectedSymbolIndex > 0) {
            self.selectedSymbolIndex--;
        } else {
            // Wrap to bottom
            self.selectedSymbolIndex = MAX(0, (NSInteger)self.symbolResults.count - 1);
        }
    } else {
        if (self.selectedWidgetIndex > 0) {
            self.selectedWidgetIndex--;
        } else {
            // Wrap to bottom
            self.selectedWidgetIndex = MAX(0, (NSInteger)self.widgetOptions.count - 1);
        }
    }
    
    [self updateTableSelections];
}

- (void)moveSelectionDown {
    if (self.isSymbolsTableActive) {
        if (self.selectedSymbolIndex < (NSInteger)self.symbolResults.count - 1) {
            self.selectedSymbolIndex++;
        } else {
            // Wrap to top
            self.selectedSymbolIndex = 0;
        }
    } else {
        if (self.selectedWidgetIndex < (NSInteger)self.widgetOptions.count - 1) {
            self.selectedWidgetIndex++;
        } else {
            // Wrap to top
            self.selectedWidgetIndex = 0;
        }
    }
    
    [self updateTableSelections];
}

- (void)executeSelectedAction {
    if (self.isSymbolsTableActive) {
        [self executeSymbolAction];
    } else {
        [self executeWidgetAction];
    }
}

- (void)executeSymbolAction {
    SymbolSearchResult *selectedResult = [self selectedSymbolResult];
    if (!selectedResult) return;
    
    NSLog(@"📈 Executing symbol action for: %@", selectedResult.symbol);
    
    // Get AppDelegate to open ChartWidget in center panel
    AppDelegate *appDelegate = self.spotlightManager.appDelegate;
    if (appDelegate && appDelegate.mainWindowController) {
        // Open ChartWidget in center panel with the selected symbol
        [self openChartWidgetWithSymbol:selectedResult.symbol];
    }
    
    // Hide spotlight
    [self.spotlightManager hideSpotlight];
}

- (void)executeWidgetAction {
    WidgetOption *selectedOption = [self selectedWidgetOption];
    if (!selectedOption) return;
    
    NSLog(@"🔧 Executing widget action for: %@", selectedOption.widgetName);
    
    // Get target panel type
    SpotlightWidgetTarget target = self.widgetTargetButton.selectedWidgetTarget;
    
    // Get AppDelegate to open widget
    AppDelegate *appDelegate = self.spotlightManager.appDelegate;
    if (appDelegate) {
        if (target == SpotlightWidgetTargetFloating) {
            // Open as floating window
            [self openFloatingWidget:selectedOption.widgetType];
        } else {
            // Open in specified panel
            PanelType panelType = [SpotlightCategoryButton panelTypeForWidgetTarget:target];
            [self openWidgetInPanel:selectedOption.widgetType panelType:panelType];
        }
    }
    
    // Hide spotlight
    [self.spotlightManager hideSpotlight];
}

#pragma mark - Widget Opening Methods

- (void)openChartWidgetWithSymbol:(NSString *)symbol {
    AppDelegate *appDelegate = self.spotlightManager.appDelegate;
    
    // Try to get existing ChartWidget in center panel, or create new one
    // This would need integration with MainWindowController
    // For now, we'll create a floating ChartWidget and set the symbol
    
    [appDelegate openFloatingWidget:@"Chart Widget"];
    
    // TODO: Find the newly created ChartWidget and set its symbol
    // This requires additional methods in AppDelegate to track and configure widgets
}

- (void)openFloatingWidget:(NSString *)widgetType {
    AppDelegate *appDelegate = self.spotlightManager.appDelegate;
    [appDelegate openFloatingWidget:widgetType];
}

- (void)openWidgetInPanel:(NSString *)widgetType panelType:(PanelType)panelType {
    // This would need integration with MainWindowController to open widgets in specific panels
    // For now, fallback to floating window
    [self openFloatingWidget:widgetType];
}

#pragma mark - Selection Management

- (void)updateTableSelections {
    // Update symbols table selection
    if (self.isSymbolsTableActive && self.symbolResults.count > 0) {
        NSInteger safeIndex = MIN(self.selectedSymbolIndex, (NSInteger)self.symbolResults.count - 1);
        NSIndexSet *symbolIndexSet = [NSIndexSet indexSetWithIndex:safeIndex];
        [self.symbolsTable selectRowIndexes:symbolIndexSet byExtendingSelection:NO];
    } else {
        [self.symbolsTable deselectAll:nil];
    }
    
    // Update widgets table selection
    if (!self.isSymbolsTableActive && self.widgetOptions.count > 0) {
        NSInteger safeIndex = MIN(self.selectedWidgetIndex, (NSInteger)self.widgetOptions.count - 1);
        NSIndexSet *widgetIndexSet = [NSIndexSet indexSetWithIndex:safeIndex];
        [self.widgetsTable selectRowIndexes:widgetIndexSet byExtendingSelection:NO];
    } else {
        [self.widgetsTable deselectAll:nil];
    }
}

- (nullable SymbolSearchResult *)selectedSymbolResult {
    if (self.selectedSymbolIndex >= 0 && self.selectedSymbolIndex < (NSInteger)self.symbolResults.count) {
        return self.symbolResults[self.selectedSymbolIndex];
    }
    return nil;
}

- (nullable WidgetOption *)selectedWidgetOption {
    if (self.selectedWidgetIndex >= 0 && self.selectedWidgetIndex < (NSInteger)self.widgetOptions.count) {
        return self.widgetOptions[self.selectedWidgetIndex];
    }
    return nil;
}

#pragma mark - UI Setup

- (void)setupWindowAppearance {
    // Window properties
    self.level = NSFloatingWindowLevel;
    self.hasShadow = YES;
    self.movable = NO;
    self.restorable = NO;
    
    // Background and appearance
    self.backgroundColor = [NSColor windowBackgroundColor];
    self.titlebarAppearsTransparent = YES;
    self.titleVisibility = NSWindowTitleHidden;
    
    // Corner radius and border
    self.contentView.wantsLayer = YES;
    self.contentView.layer.cornerRadius = 10.0;
    self.contentView.layer.masksToBounds = YES;
}

- (void)createUIComponents {
    // Main content container
    self.contentContainer = [[NSView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.contentContainer];
    
    // Top bar view
    self.topBarView = [[NSView alloc] init];
    self.topBarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.topBarView];
    
    // Search field
    self.searchField = [[NSTextField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = @"Search symbols or widgets...";
    self.searchField.delegate = self;
    [self.topBarView addSubview:self.searchField];
    
    // Category buttons
    self.dataSourceButton = [[SpotlightCategoryButton alloc] initWithCategoryType:SpotlightCategoryTypeDataSource];
    self.dataSourceButton.delegate = self;
    [self.topBarView addSubview:self.dataSourceButton];
    
    self.widgetTargetButton = [[SpotlightCategoryButton alloc] initWithCategoryType:SpotlightCategoryTypeWidgetTarget];
    self.widgetTargetButton.delegate = self;
    [self.topBarView addSubview:self.widgetTargetButton];
    
    // Tables view container
    self.tablesView = [[NSView alloc] init];
    self.tablesView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.tablesView];
    
    // Symbols table
    self.symbolsTable = [[NSTableView alloc] init];
    self.symbolsTable.delegate = self;
    self.symbolsTable.dataSource = self;
    self.symbolsTable.headerView = nil;
    
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    [self.symbolsTable addTableColumn:symbolColumn];
    
    self.symbolsScrollView = [[NSScrollView alloc] init];
    self.symbolsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolsScrollView.documentView = self.symbolsTable;
    self.symbolsScrollView.hasVerticalScroller = YES;
    [self.tablesView addSubview:self.symbolsScrollView];
    
    // Widgets table
    self.widgetsTable = [[NSTableView alloc] init];
    self.widgetsTable.delegate = self;
    self.widgetsTable.dataSource = self;
    self.widgetsTable.headerView = nil;
    
    NSTableColumn *widgetColumn = [[NSTableColumn alloc] initWithIdentifier:@"widget"];
    widgetColumn.title = @"Widget";
    [self.widgetsTable addTableColumn:widgetColumn];
    
    self.widgetsScrollView = [[NSScrollView alloc] init];
    self.widgetsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.widgetsScrollView.documentView = self.widgetsTable;
    self.widgetsScrollView.hasVerticalScroller = YES;
    [self.tablesView addSubview:self.widgetsScrollView];
}

- (void)setupLayoutConstraints {
    // Content container fills window
    [NSLayoutConstraint activateConstraints:@[
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    // Top bar layout
    [NSLayoutConstraint activateConstraints:@[
        [self.topBarView.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:kMargin],
        [self.topBarView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:kMargin],
        [self.topBarView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-kMargin],
        [self.topBarView.heightAnchor constraintEqualToConstant:kSearchFieldHeight + kMargin]
    ]];
    
    // Search field layout
    [NSLayoutConstraint activateConstraints:@[
        [self.searchField.topAnchor constraintEqualToAnchor:self.topBarView.topAnchor],
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.topBarView.leadingAnchor],
        [self.searchField.heightAnchor constraintEqualToConstant:kSearchFieldHeight]
    ]];
    
    // Category buttons layout
    [NSLayoutConstraint activateConstraints:@[
        [self.dataSourceButton.topAnchor constraintEqualToAnchor:self.topBarView.topAnchor],
        [self.dataSourceButton.leadingAnchor constraintEqualToAnchor:self.searchField.trailingAnchor constant:kMargin],
        [self.dataSourceButton.heightAnchor constraintEqualToConstant:kSearchFieldHeight],
        [self.dataSourceButton.widthAnchor constraintGreaterThanOrEqualToConstant:80]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.widgetTargetButton.topAnchor constraintEqualToAnchor:self.topBarView.topAnchor],
        [self.widgetTargetButton.leadingAnchor constraintEqualToAnchor:self.dataSourceButton.trailingAnchor constant:kMargin],
        [self.widgetTargetButton.trailingAnchor constraintEqualToAnchor:self.topBarView.trailingAnchor],
        [self.widgetTargetButton.heightAnchor constraintEqualToConstant:kSearchFieldHeight],
        [self.widgetTargetButton.widthAnchor constraintGreaterThanOrEqualToConstant:100]
    ]];
    
    // Tables view layout
    [NSLayoutConstraint activateConstraints:@[
        [self.tablesView.topAnchor constraintEqualToAnchor:self.topBarView.bottomAnchor constant:kMargin],
        [self.tablesView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:kMargin],
        [self.tablesView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-kMargin],
        [self.tablesView.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-kMargin]
    ]];
    
    // Split tables layout (50/50)
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolsScrollView.topAnchor constraintEqualToAnchor:self.tablesView.topAnchor],
        [self.symbolsScrollView.leadingAnchor constraintEqualToAnchor:self.tablesView.leadingAnchor],
        [self.symbolsScrollView.bottomAnchor constraintEqualToAnchor:self.tablesView.bottomAnchor],
        [self.symbolsScrollView.trailingAnchor constraintEqualToAnchor:self.tablesView.centerXAnchor constant:-5]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.widgetsScrollView.topAnchor constraintEqualToAnchor:self.tablesView.topAnchor],
        [self.widgetsScrollView.leadingAnchor constraintEqualToAnchor:self.tablesView.centerXAnchor constant:5],
        [self.widgetsScrollView.trailingAnchor constraintEqualToAnchor:self.tablesView.trailingAnchor],
        [self.widgetsScrollView.bottomAnchor constraintEqualToAnchor:self.tablesView.bottomAnchor]
    ]];
}

#pragma mark - Keyboard Handling

- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case 126: // Up arrow
            [self moveSelectionUp];
            break;
        case 125: // Down arrow
            [self moveSelectionDown];
            break;
        case 123: // Left arrow
            [self switchActiveTable:YES]; // Switch to symbols table
            break;
        case 124: // Right arrow
            [self switchActiveTable:NO]; // Switch to widgets table
            break;
        case 36:  // Return
            [self executeSelectedAction];
            break;
        case 53:  // Escape
            [self.spotlightManager hideSpotlight];
            break;
        default:
            [super keyDown:event];
            break;
    }
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)obj {
    if (obj.object == self.searchField) {
        NSString *searchText = self.searchField.stringValue;
        self.currentSearchText = searchText;
        
        // Cancel previous timer
        if (self.searchDelayTimer) {
            [self.searchDelayTimer invalidate];
        }
        
        // Start new timer for delayed search (avoid too many API calls)
        self.searchDelayTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                                  target:self
                                                                selector:@selector(delayedSearch)
                                                                userInfo:nil
                                                                 repeats:NO];
    }
}

- (void)delayedSearch {
    [self performSymbolSearch:self.currentSearchText];
    [self filterWidgetOptions:self.currentSearchText];
}

#pragma mark - NSTableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.symbolsTable) {
        return self.symbolResults.count;
    } else if (tableView == self.widgetsTable) {
        return self.widgetOptions.count;
    }
    return 0;
}

#pragma mark - NSTableView Delegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.bordered = NO;
        textField.editable = NO;
        textField.backgroundColor = [NSColor clearColor];
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:5],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-5],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    if (tableView == self.symbolsTable && row < (NSInteger)self.symbolResults.count) {
        SymbolSearchResult *result = self.symbolResults[row];
        cellView.textField.stringValue = result.displayString;
    } else if (tableView == self.widgetsTable && row < (NSInteger)self.widgetOptions.count) {
        WidgetOption *option = self.widgetOptions[row];
        cellView.textField.stringValue = option.widgetName;
    }
    
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = notification.object;
    
    if (tableView == self.symbolsTable) {
        NSInteger selectedRow = tableView.selectedRow;
        if (selectedRow >= 0) {
            self.selectedSymbolIndex = selectedRow;
            self.isSymbolsTableActive = YES;
            [self.dataSourceButton setActiveState:YES];
            [self.widgetTargetButton setActiveState:NO];
            
            // Deselect widgets table
            [self.widgetsTable deselectAll:nil];
        }
    } else if (tableView == self.widgetsTable) {
        NSInteger selectedRow = tableView.selectedRow;
        if (selectedRow >= 0) {
            self.selectedWidgetIndex = selectedRow;
            self.isSymbolsTableActive = NO;
            [self.dataSourceButton setActiveState:NO];
            [self.widgetTargetButton setActiveState:YES];
            
            // Deselect symbols table
            [self.symbolsTable deselectAll:nil];
        }
    }
}

#pragma mark - SpotlightCategoryButtonDelegate

- (void)spotlightCategoryButton:(SpotlightCategoryButton *)button didSelectDataSource:(DataSourceType)dataSource {
    NSLog(@"📊 SpotlightSearchWindow: Data source changed to %@",
          [SpotlightCategoryButton displayNameForDataSource:dataSource]);
    
    // Re-perform search with new data source
    if (self.currentSearchText.length > 0) {
        [self performSymbolSearch:self.currentSearchText];
    }
}

- (void)spotlightCategoryButton:(SpotlightCategoryButton *)button didSelectWidgetTarget:(SpotlightWidgetTarget)target {
    NSLog(@"🎯 SpotlightSearchWindow: Widget target changed to %@",
          [SpotlightCategoryButton displayNameForWidgetTarget:target]);
    
    // No immediate action needed, will be used when executing widget action
}

@end
