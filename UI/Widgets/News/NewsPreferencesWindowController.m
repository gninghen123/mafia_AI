//
//  NewsPreferencesWindowController.m
//  TradingApp
//
//  Complete final implementation of preferences window for NewsWidget V2
//

#import "NewsPreferencesWindowController.h"
#import "NewsWidget.h"
#import "CommonTypes.h"

@implementation NewsPreferencesWindowController

- (instancetype)initWithNewsWidget:(NewsWidget *)newsWidget {
    self = [super initWithWindowNibName:nil];
    if (self) {
        self.newsWidget = newsWidget;
        
        // Initialize data arrays
        self.sourcesList = [NSMutableArray array];
        self.colorMappings = [NSMutableArray array];
        
        [self createWindow];
        [self loadDataFromWidget];
    }
    return self;
}

- (void)createWindow {
    // Create window
    NSRect windowFrame = NSMakeRect(0, 0, 600, 500);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"News Preferences";
    window.minSize = NSMakeSize(500, 400);
    [window center];
    
    self.window = window;
    
    [self createTabView];
    [self createSourcesTab];
    [self createColorsTab];
    [self createFiltersTab];
    [self createButtonsPanel];
    
    [self setupConstraints];
}

- (void)createTabView {
    self.tabView = [[NSTabView alloc] init];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:self.tabView];
}

- (void)createSourcesTab {
    NSTabViewItem *sourcesTab = [[NSTabViewItem alloc] init];
    sourcesTab.label = @"News Sources";
    
    NSView *sourcesView = [[NSView alloc] init];
    
    // Sources table view
    self.sourcesTableView = [[NSTableView alloc] init];
    self.sourcesTableView.delegate = self;
    self.sourcesTableView.dataSource = self;
    
    // Create columns
    NSTableColumn *enabledColumn = [[NSTableColumn alloc] initWithIdentifier:@"enabled"];
    enabledColumn.title = @"Enabled";
    enabledColumn.width = 80;
    [self.sourcesTableView addTableColumn:enabledColumn];
    
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = @"Source Name";
    nameColumn.width = 200;
    [self.sourcesTableView addTableColumn:nameColumn];
    
    NSTableColumn *descColumn = [[NSTableColumn alloc] initWithIdentifier:@"description"];
    descColumn.title = @"Description";
    descColumn.width = 250;
    [self.sourcesTableView addTableColumn:descColumn];
    
    // Scroll view for sources table
    NSScrollView *sourcesScrollView = [[NSScrollView alloc] init];
    sourcesScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    sourcesScrollView.documentView = self.sourcesTableView;
    sourcesScrollView.hasVerticalScroller = YES;
    sourcesScrollView.hasHorizontalScroller = YES;
    sourcesScrollView.autohidesScrollers = YES;
    [sourcesView addSubview:sourcesScrollView];
    
    // Instructions label
    NSTextField *instructionLabel = [NSTextField labelWithString:@"Select which news sources to include in search results:"];
    instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    instructionLabel.font = [NSFont systemFontOfSize:13];
    [sourcesView addSubview:instructionLabel];
    
    // Constraints for sources tab
    [NSLayoutConstraint activateConstraints:@[
        [instructionLabel.topAnchor constraintEqualToAnchor:sourcesView.topAnchor constant:20],
        [instructionLabel.leadingAnchor constraintEqualToAnchor:sourcesView.leadingAnchor constant:20],
        [instructionLabel.trailingAnchor constraintEqualToAnchor:sourcesView.trailingAnchor constant:-20],
        
        [sourcesScrollView.topAnchor constraintEqualToAnchor:instructionLabel.bottomAnchor constant:10],
        [sourcesScrollView.leadingAnchor constraintEqualToAnchor:sourcesView.leadingAnchor constant:20],
        [sourcesScrollView.trailingAnchor constraintEqualToAnchor:sourcesView.trailingAnchor constant:-20],
        [sourcesScrollView.bottomAnchor constraintEqualToAnchor:sourcesView.bottomAnchor constant:-20]
    ]];
    
    sourcesTab.view = sourcesView;
    [self.tabView addTabViewItem:sourcesTab];
}

- (void)createColorsTab {
    NSTabViewItem *colorsTab = [[NSTabViewItem alloc] init];
    colorsTab.label = @"Colors & Keywords";
    
    NSView *colorsView = [[NSView alloc] init];
    
    // Colors table view
    self.colorsTableView = [[NSTableView alloc] init];
    self.colorsTableView.delegate = self;
    self.colorsTableView.dataSource = self;
    
    // Create columns
    NSTableColumn *colorColumn = [[NSTableColumn alloc] initWithIdentifier:@"color"];
    colorColumn.title = @"Color";
    colorColumn.width = 80;
    [self.colorsTableView addTableColumn:colorColumn];
    
    NSTableColumn *keywordsColumn = [[NSTableColumn alloc] initWithIdentifier:@"keywords"];
    keywordsColumn.title = @"Keywords (comma separated)";
    keywordsColumn.width = 400;
    [self.colorsTableView addTableColumn:keywordsColumn];
    
    // Scroll view for colors table
    NSScrollView *colorsScrollView = [[NSScrollView alloc] init];
    colorsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    colorsScrollView.documentView = self.colorsTableView;
    colorsScrollView.hasVerticalScroller = YES;
    colorsScrollView.hasHorizontalScroller = YES;
    colorsScrollView.autohidesScrollers = YES;
    [colorsView addSubview:colorsScrollView];
    
    // Buttons for color management
    self.addColorButton = [NSButton buttonWithTitle:@"Add Color" target:self action:@selector(addColorMapping:)];
    self.addColorButton.translatesAutoresizingMaskIntoConstraints = NO;
    [colorsView addSubview:self.addColorButton];
    
    self.removeColorButton = [NSButton buttonWithTitle:@"Remove Color" target:self action:@selector(removeColorMapping:)];
    self.removeColorButton.translatesAutoresizingMaskIntoConstraints = NO;
    [colorsView addSubview:self.removeColorButton];
    
    // Instructions label
    NSTextField *colorInstructionLabel = [NSTextField labelWithString:@"Configure color indicators for news types. Colors will appear in the Type column when keywords are found in news headlines."];
    colorInstructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    colorInstructionLabel.font = [NSFont systemFontOfSize:13];
    [colorsView addSubview:colorInstructionLabel];
    
    // Constraints for colors tab
    [NSLayoutConstraint activateConstraints:@[
        [colorInstructionLabel.topAnchor constraintEqualToAnchor:colorsView.topAnchor constant:20],
        [colorInstructionLabel.leadingAnchor constraintEqualToAnchor:colorsView.leadingAnchor constant:20],
        [colorInstructionLabel.trailingAnchor constraintEqualToAnchor:colorsView.trailingAnchor constant:-20],
        
        [colorsScrollView.topAnchor constraintEqualToAnchor:colorInstructionLabel.bottomAnchor constant:10],
        [colorsScrollView.leadingAnchor constraintEqualToAnchor:colorsView.leadingAnchor constant:20],
        [colorsScrollView.trailingAnchor constraintEqualToAnchor:colorsView.trailingAnchor constant:-20],
        [colorsScrollView.bottomAnchor constraintEqualToAnchor:self.addColorButton.topAnchor constant:-10],
        
        [self.addColorButton.leadingAnchor constraintEqualToAnchor:colorsView.leadingAnchor constant:20],
        [self.addColorButton.bottomAnchor constraintEqualToAnchor:colorsView.bottomAnchor constant:-20],
        
        [self.removeColorButton.leadingAnchor constraintEqualToAnchor:self.addColorButton.trailingAnchor constant:10],
        [self.removeColorButton.bottomAnchor constraintEqualToAnchor:colorsView.bottomAnchor constant:-20]
    ]];
    
    colorsTab.view = colorsView;
    [self.tabView addTabViewItem:colorsTab];
}

- (void)createFiltersTab {
    NSTabViewItem *filtersTab = [[NSTabViewItem alloc] init];
    filtersTab.label = @"Filters & Settings";
    
    NSView *filtersView = [[NSView alloc] init];
    
    // Exclude keywords section
    NSTextField *excludeLabel = [NSTextField labelWithString:@"Exclude Keywords (comma separated):"];
    excludeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    excludeLabel.font = [NSFont boldSystemFontOfSize:14];
    [filtersView addSubview:excludeLabel];
    
    NSTextField *excludeInstructionLabel = [NSTextField labelWithString:@"News containing these keywords will be filtered out from results:"];
    excludeInstructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    excludeInstructionLabel.font = [NSFont systemFontOfSize:12];
    excludeInstructionLabel.textColor = [NSColor secondaryLabelColor];
    [filtersView addSubview:excludeInstructionLabel];
    
    // Exclude keywords text view
    self.excludeKeywordsTextView = [[NSTextView alloc] init];
    self.excludeKeywordsTextView.delegate = self;
    self.excludeKeywordsTextView.font = [NSFont systemFontOfSize:13];
    
    NSScrollView *excludeScrollView = [[NSScrollView alloc] init];
    excludeScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    excludeScrollView.documentView = self.excludeKeywordsTextView;
    excludeScrollView.hasVerticalScroller = YES;
    excludeScrollView.hasHorizontalScroller = NO;
    excludeScrollView.autohidesScrollers = YES;
    [filtersView addSubview:excludeScrollView];
    
    // News limit section
    NSTextField *limitLabel = [NSTextField labelWithString:@"Maximum News Items:"];
    limitLabel.translatesAutoresizingMaskIntoConstraints = NO;
    limitLabel.font = [NSFont boldSystemFontOfSize:14];
    [filtersView addSubview:limitLabel];
    
    self.newsLimitField = [[NSTextField alloc] init];
    self.newsLimitField.translatesAutoresizingMaskIntoConstraints = NO;
    self.newsLimitField.placeholderString = @"50";
    [filtersView addSubview:self.newsLimitField];
    
    NSTextField *limitInstructionLabel = [NSTextField labelWithString:@"Maximum number of news items to load per search (default: 50)"];
    limitInstructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    limitInstructionLabel.font = [NSFont systemFontOfSize:12];
    limitInstructionLabel.textColor = [NSColor secondaryLabelColor];
    [filtersView addSubview:limitInstructionLabel];
    
    // Auto-refresh section
    NSTextField *refreshLabel = [NSTextField labelWithString:@"Auto-Refresh Settings:"];
    refreshLabel.translatesAutoresizingMaskIntoConstraints = NO;
    refreshLabel.font = [NSFont boldSystemFontOfSize:14];
    [filtersView addSubview:refreshLabel];
    
    NSButton *autoRefreshCheckbox = [NSButton checkboxWithTitle:@"Enable auto-refresh" target:self action:@selector(autoRefreshChanged:)];
    autoRefreshCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    autoRefreshCheckbox.tag = 100; // Tag for identification
    [filtersView addSubview:autoRefreshCheckbox];
    
    NSTextField *intervalLabel = [NSTextField labelWithString:@"Refresh interval (seconds):"];
    intervalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [filtersView addSubview:intervalLabel];
    
    NSTextField *refreshIntervalField = [[NSTextField alloc] init];
    refreshIntervalField.translatesAutoresizingMaskIntoConstraints = NO;
    refreshIntervalField.placeholderString = @"300";
    refreshIntervalField.tag = 101; // Tag for identification
    [filtersView addSubview:refreshIntervalField];
    
    // Constraints for filters tab
    [NSLayoutConstraint activateConstraints:@[
        // Exclude keywords section
        [excludeLabel.topAnchor constraintEqualToAnchor:filtersView.topAnchor constant:20],
        [excludeLabel.leadingAnchor constraintEqualToAnchor:filtersView.leadingAnchor constant:20],
        
        [excludeInstructionLabel.topAnchor constraintEqualToAnchor:excludeLabel.bottomAnchor constant:5],
        [excludeInstructionLabel.leadingAnchor constraintEqualToAnchor:filtersView.leadingAnchor constant:20],
        [excludeInstructionLabel.trailingAnchor constraintEqualToAnchor:filtersView.trailingAnchor constant:-20],
        
        [excludeScrollView.topAnchor constraintEqualToAnchor:excludeInstructionLabel.bottomAnchor constant:5],
        [excludeScrollView.leadingAnchor constraintEqualToAnchor:filtersView.leadingAnchor constant:20],
        [excludeScrollView.trailingAnchor constraintEqualToAnchor:filtersView.trailingAnchor constant:-20],
        [excludeScrollView.heightAnchor constraintEqualToConstant:80],
        
        // News limit section
        [limitLabel.topAnchor constraintEqualToAnchor:excludeScrollView.bottomAnchor constant:20],
        [limitLabel.leadingAnchor constraintEqualToAnchor:filtersView.leadingAnchor constant:20],
        
        [self.newsLimitField.topAnchor constraintEqualToAnchor:limitLabel.bottomAnchor constant:5],
        [self.newsLimitField.leadingAnchor constraintEqualToAnchor:filtersView.leadingAnchor constant:20],
        [self.newsLimitField.widthAnchor constraintEqualToConstant:100],
        
        [limitInstructionLabel.centerYAnchor constraintEqualToAnchor:self.newsLimitField.centerYAnchor],
        [limitInstructionLabel.leadingAnchor constraintEqualToAnchor:self.newsLimitField.trailingAnchor constant:10],
        
        // Auto-refresh section
        [refreshLabel.topAnchor constraintEqualToAnchor:self.newsLimitField.bottomAnchor constant:20],
        [refreshLabel.leadingAnchor constraintEqualToAnchor:filtersView.leadingAnchor constant:20],
        
        [autoRefreshCheckbox.topAnchor constraintEqualToAnchor:refreshLabel.bottomAnchor constant:5],
        [autoRefreshCheckbox.leadingAnchor constraintEqualToAnchor:filtersView.leadingAnchor constant:20],
        
        [intervalLabel.topAnchor constraintEqualToAnchor:autoRefreshCheckbox.bottomAnchor constant:10],
        [intervalLabel.leadingAnchor constraintEqualToAnchor:filtersView.leadingAnchor constant:20],
        
        [refreshIntervalField.centerYAnchor constraintEqualToAnchor:intervalLabel.centerYAnchor],
        [refreshIntervalField.leadingAnchor constraintEqualToAnchor:intervalLabel.trailingAnchor constant:10],
        [refreshIntervalField.widthAnchor constraintEqualToConstant:100]
    ]];
    
    filtersTab.view = filtersView;
    [self.tabView addTabViewItem:filtersTab];
}

- (void)createButtonsPanel {
    // Bottom buttons panel
    NSView *buttonsPanel = [[NSView alloc] init];
    buttonsPanel.translatesAutoresizingMaskIntoConstraints = NO;
    buttonsPanel.identifier = @"ButtonsPanel";
    [self.window.contentView addSubview:buttonsPanel];
    
    NSButton *saveButton = [NSButton buttonWithTitle:@"Save" target:self action:@selector(savePreferences:)];
    saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    saveButton.keyEquivalent = @"\r"; // Enter key
    [buttonsPanel addSubview:saveButton];
    
    NSButton *cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelPreferences:)];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    cancelButton.keyEquivalent = @"\033"; // Escape key
    [buttonsPanel addSubview:cancelButton];
    
    NSButton *resetButton = [NSButton buttonWithTitle:@"Reset to Defaults" target:self action:@selector(resetToDefaults:)];
    resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [buttonsPanel addSubview:resetButton];
    
    // Constraints for buttons panel
    [NSLayoutConstraint activateConstraints:@[
        [saveButton.trailingAnchor constraintEqualToAnchor:buttonsPanel.trailingAnchor constant:-20],
        [saveButton.centerYAnchor constraintEqualToAnchor:buttonsPanel.centerYAnchor],
        
        [cancelButton.trailingAnchor constraintEqualToAnchor:saveButton.leadingAnchor constant:-10],
        [cancelButton.centerYAnchor constraintEqualToAnchor:buttonsPanel.centerYAnchor],
        
        [resetButton.leadingAnchor constraintEqualToAnchor:buttonsPanel.leadingAnchor constant:20],
        [resetButton.centerYAnchor constraintEqualToAnchor:buttonsPanel.centerYAnchor]
    ]];
}

- (void)setupConstraints {
    NSView *buttonsPanel = nil;
    for (NSView *subview in self.window.contentView.subviews) {
        if ([subview.identifier isEqualToString:@"ButtonsPanel"]) {
            buttonsPanel = subview;
            break;
        }
    }
    
    if (buttonsPanel) {
        [NSLayoutConstraint activateConstraints:@[
            [self.tabView.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor constant:20],
            [self.tabView.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:20],
            [self.tabView.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-20],
            [self.tabView.bottomAnchor constraintEqualToAnchor:buttonsPanel.topAnchor constant:-20],
            
            [buttonsPanel.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor],
            [buttonsPanel.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor],
            [buttonsPanel.bottomAnchor constraintEqualToAnchor:self.window.contentView.bottomAnchor],
            [buttonsPanel.heightAnchor constraintEqualToConstant:60]
        ]];
    }
}

#pragma mark - Data Management

- (void)loadDataFromWidget {
    // Load sources data
    [self loadSourcesData];
    
    // Load color mappings data
    [self loadColorMappingsData];
    
    // Load other settings
    [self loadOtherSettings];
}

- (void)loadSourcesData {
    [self.sourcesList removeAllObjects];
    
    // Define all available news sources
    NSArray *allSources = @[
        @{@"type": @(DataRequestTypeNews), @"name": @"General News", @"description": @"Aggregated news from multiple sources"},
        @{@"type": @(DataRequestTypeGoogleFinanceNews), @"name": @"Google Finance", @"description": @"News from Google Finance RSS"},
        @{@"type": @(DataRequestTypeYahooFinanceNews), @"name": @"Yahoo Finance", @"description": @"News from Yahoo Finance RSS"},
        @{@"type": @(DataRequestTypeSECFilings), @"name": @"SEC Filings", @"description": @"SEC EDGAR filings and forms"},
        @{@"type": @(DataRequestTypeSeekingAlphaNews), @"name": @"Seeking Alpha", @"description": @"News and analysis from Seeking Alpha"}
    ];
    
    for (NSDictionary *sourceInfo in allSources) {
        NSNumber *sourceType = sourceInfo[@"type"];
        BOOL isEnabled = [self.newsWidget.enabledNewsSources[sourceType] boolValue];
        
        NSMutableDictionary *sourceData = [NSMutableDictionary dictionaryWithDictionary:sourceInfo];
        sourceData[@"enabled"] = @(isEnabled);
        
        [self.sourcesList addObject:sourceData];
    }
}

- (void)loadColorMappingsData {
    [self.colorMappings removeAllObjects];
    
    for (NSString *colorHex in self.newsWidget.colorKeywordMapping.allKeys) {
        NSString *keywords = self.newsWidget.colorKeywordMapping[colorHex];
        
        NSMutableDictionary *colorData = [NSMutableDictionary dictionary];
        colorData[@"colorHex"] = colorHex;
        colorData[@"keywords"] = keywords ?: @"";
        
        [self.colorMappings addObject:colorData];
    }
}

- (void)loadOtherSettings {
    // Update exclude keywords text view
    NSString *excludeKeywordsText = [self.newsWidget.excludeKeywords componentsJoinedByString:@", "];
    self.excludeKeywordsTextView.string = excludeKeywordsText ?: @"";
    
    // Update news limit field
    self.newsLimitField.integerValue = self.newsWidget.newsLimit;
    
    // Update auto-refresh settings using recursive search
    NSButton *autoRefreshCheckbox = [self findViewWithTag:100 inView:self.window.contentView];
    if (autoRefreshCheckbox && [autoRefreshCheckbox isKindOfClass:[NSButton class]]) {
        autoRefreshCheckbox.state = self.newsWidget.autoRefresh ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    NSTextField *refreshIntervalField = [self findViewWithTag:101 inView:self.window.contentView];
    if (refreshIntervalField && [refreshIntervalField isKindOfClass:[NSTextField class]]) {
        refreshIntervalField.doubleValue = self.newsWidget.refreshInterval;
    }
}

- (NSView *)findViewWithTag:(NSInteger)tag inView:(NSView *)parentView {
    if (parentView.tag == tag) {
        return parentView;
    }
    
    for (NSView *subview in parentView.subviews) {
        NSView *found = [self findViewWithTag:tag inView:subview];
        if (found) {
            return found;
        }
    }
    
    return nil;
}

- (void)refreshUI {
    [self loadDataFromWidget];
    [self.sourcesTableView reloadData];
    [self.colorsTableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.sourcesTableView) {
        return self.sourcesList.count;
    } else if (tableView == self.colorsTableView) {
        return self.colorMappings.count;
    }
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.sourcesTableView) {
        if (row >= self.sourcesList.count) return nil;
        
        NSDictionary *sourceData = self.sourcesList[row];
        NSString *identifier = tableColumn.identifier;
        
        if ([identifier isEqualToString:@"enabled"]) {
            return sourceData[@"enabled"];
        } else if ([identifier isEqualToString:@"name"]) {
            return sourceData[@"name"];
        } else if ([identifier isEqualToString:@"description"]) {
            return sourceData[@"description"];
        }
    } else if (tableView == self.colorsTableView) {
        if (row >= self.colorMappings.count) return nil;
        
        NSDictionary *colorData = self.colorMappings[row];
        NSString *identifier = tableColumn.identifier;
        
        if ([identifier isEqualToString:@"keywords"]) {
            return colorData[@"keywords"];
        }
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.sourcesTableView) {
        if (row >= self.sourcesList.count) return;
        
        NSMutableDictionary *sourceData = self.sourcesList[row];
        NSString *identifier = tableColumn.identifier;
        
        if ([identifier isEqualToString:@"enabled"]) {
            sourceData[@"enabled"] = object;
        }
    } else if (tableView == self.colorsTableView) {
        if (row >= self.colorMappings.count) return;
        
        NSMutableDictionary *colorData = self.colorMappings[row];
        NSString *identifier = tableColumn.identifier;
        
        if ([identifier isEqualToString:@"keywords"]) {
            colorData[@"keywords"] = object ?: @"";
        }
    }
}

#pragma mark - Table View Delegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = tableColumn.identifier;
    
    if (tableView == self.sourcesTableView) {
        if (row >= self.sourcesList.count) return nil;
        
        if ([identifier isEqualToString:@"enabled"]) {
            // Create checkbox for enabled column
            NSButton *checkbox = [tableView makeViewWithIdentifier:identifier owner:self];
            if (!checkbox) {
                checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(sourceEnabledChanged:)];
                checkbox.identifier = identifier;
            }
            
            NSDictionary *sourceData = self.sourcesList[row];
            checkbox.state = [sourceData[@"enabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
            checkbox.tag = row;
            
            return checkbox;
        } else {
            // Create text field for other columns
            NSTextField *textField = [tableView makeViewWithIdentifier:identifier owner:self];
            if (!textField) {
                textField = [[NSTextField alloc] init];
                textField.identifier = identifier;
                textField.bordered = NO;
                textField.backgroundColor = [NSColor clearColor];
                textField.editable = NO;
            }
            
            textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row] ?: @"";
            
            return textField;
        }
    } else if (tableView == self.colorsTableView) {
        if (row >= self.colorMappings.count) return nil;
        
        if ([identifier isEqualToString:@"color"]) {
            // Create color well for color column
            NSColorWell *colorWell = [tableView makeViewWithIdentifier:identifier owner:self];
            if (!colorWell) {
                colorWell = [[NSColorWell alloc] init];
                colorWell.identifier = identifier;
                colorWell.target = self;
                colorWell.action = @selector(colorChanged:);
            }
            
            NSDictionary *colorData = self.colorMappings[row];
            NSString *colorHex = colorData[@"colorHex"];
            NSColor *color = [self colorFromHexString:colorHex];
            colorWell.color = color ?: [NSColor blackColor];
            colorWell.tag = row;
            
            return colorWell;
        } else if ([identifier isEqualToString:@"keywords"]) {
            // Create text field for keywords column
            NSTextField *textField = [tableView makeViewWithIdentifier:identifier owner:self];
            if (!textField) {
                textField = [[NSTextField alloc] init];
                textField.identifier = identifier;
                textField.bordered = YES;
                textField.editable = YES;
                textField.target = self;
                textField.action = @selector(keywordsChanged:);
            }
            
            textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row] ?: @"";
            textField.tag = row;
            
            return textField;
        }
    }
    
    return nil;
}

#pragma mark - Action Methods

- (IBAction)addColorMapping:(id)sender {
    // Add new color mapping with default values
    NSMutableDictionary *newColorData = [NSMutableDictionary dictionary];
    newColorData[@"colorHex"] = @"FF0000"; // Default red
    newColorData[@"keywords"] = @"";
    
    [self.colorMappings addObject:newColorData];
    [self.colorsTableView reloadData];
    
    // Select the new row
    NSInteger newRow = self.colorMappings.count - 1;
    [self.colorsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
}

- (IBAction)removeColorMapping:(id)sender {
    NSInteger selectedRow = self.colorsTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.colorMappings.count) {
        [self.colorMappings removeObjectAtIndex:selectedRow];
        [self.colorsTableView reloadData];
    }
}

- (IBAction)sourceEnabledChanged:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row >= 0 && row < self.sourcesList.count) {
        NSMutableDictionary *sourceData = self.sourcesList[row];
        sourceData[@"enabled"] = @(sender.state == NSControlStateValueOn);
    }
}

- (IBAction)colorChanged:(NSColorWell *)sender {
    NSInteger row = sender.tag;
    if (row >= 0 && row < self.colorMappings.count) {
        NSMutableDictionary *colorData = self.colorMappings[row];
        NSString *hexString = [self hexStringFromColor:sender.color];
        colorData[@"colorHex"] = hexString;
    }
}

- (IBAction)keywordsChanged:(NSTextField *)sender {
    NSInteger row = sender.tag;
    if (row >= 0 && row < self.colorMappings.count) {
        NSMutableDictionary *colorData = self.colorMappings[row];
        colorData[@"keywords"] = sender.stringValue ?: @"";
    }
}

- (IBAction)autoRefreshChanged:(NSButton *)sender {
    // Auto-refresh checkbox changed - no immediate action needed
    // Will be saved when Save button is pressed
}

- (IBAction)savePreferences:(id)sender {
    [self saveDataToWidget];
    [self.newsWidget savePreferences];
    [self.window close];
}

- (IBAction)cancelPreferences:(id)sender {
    [self.window close];
}

- (IBAction)resetToDefaults:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Reset to Defaults";
    alert.informativeText = @"This will reset all preferences to their default values. Are you sure?";
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self.newsWidget resetPreferencesToDefaults];
            [self refreshUI];
        }
    }];
}

- (void)saveDataToWidget {
    // Save sources data
    NSMutableDictionary *enabledSources = [NSMutableDictionary dictionary];
    for (NSDictionary *sourceData in self.sourcesList) {
        NSNumber *sourceType = sourceData[@"type"];
        NSNumber *enabled = sourceData[@"enabled"];
        enabledSources[sourceType] = enabled;
    }
    self.newsWidget.enabledNewsSources = enabledSources;
    
    // Save color mappings data
    NSMutableDictionary *colorKeywordMapping = [NSMutableDictionary dictionary];
    for (NSDictionary *colorData in self.colorMappings) {
        NSString *colorHex = colorData[@"colorHex"];
        NSString *keywords = colorData[@"keywords"];
        if (colorHex && keywords && keywords.length > 0) {
            colorKeywordMapping[colorHex] = keywords;
        }
    }
    self.newsWidget.colorKeywordMapping = colorKeywordMapping;
    
    // Save exclude keywords
    NSString *excludeKeywordsText = self.excludeKeywordsTextView.string;
    NSArray *excludeKeywords = [excludeKeywordsText componentsSeparatedByString:@","];
    NSMutableArray *cleanedKeywords = [NSMutableArray array];
    for (NSString *keyword in excludeKeywords) {
        NSString *trimmed = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            [cleanedKeywords addObject:trimmed];
        }
    }
    self.newsWidget.excludeKeywords = [cleanedKeywords copy];
    
    // Save other settings
    self.newsWidget.newsLimit = self.newsLimitField.integerValue > 0 ? self.newsLimitField.integerValue : 50;
    
    // Use recursive search for tagged views
    NSButton *autoRefreshCheckbox = [self findViewWithTag:100 inView:self.window.contentView];
    if (autoRefreshCheckbox && [autoRefreshCheckbox isKindOfClass:[NSButton class]]) {
        self.newsWidget.autoRefresh = (autoRefreshCheckbox.state == NSControlStateValueOn);
    }
    
    NSTextField *refreshIntervalField = [self findViewWithTag:101 inView:self.window.contentView];
    if (refreshIntervalField && [refreshIntervalField isKindOfClass:[NSTextField class]]) {
        self.newsWidget.refreshInterval = refreshIntervalField.doubleValue > 0 ? refreshIntervalField.doubleValue : 300;
    }
    
    // Restart auto-refresh with new settings
    [self.newsWidget startAutoRefreshIfEnabled];
}

#pragma mark - Utility Methods

- (NSColor *)colorFromHexString:(NSString *)hexString {
    if (!hexString || hexString.length != 6) return nil;
    
    unsigned int hexValue;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if (![scanner scanHexInt:&hexValue]) return nil;
    
    CGFloat red = ((hexValue & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((hexValue & 0x00FF00) >> 8) / 255.0;
    CGFloat blue = (hexValue & 0x0000FF) / 255.0;
    
    return [NSColor colorWithRed:red green:green blue:blue alpha:1.0];
}

- (NSString *)hexStringFromColor:(NSColor *)color {
    NSColor *rgbColor = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (!rgbColor) return @"000000";
    
    int red = (int)(rgbColor.redComponent * 255);
    int green = (int)(rgbColor.greenComponent * 255);
    int blue = (int)(rgbColor.blueComponent * 255);
    
    return [NSString stringWithFormat:@"%02X%02X%02X", red, green, blue];
}

@end
