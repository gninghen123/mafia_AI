//
//  ConnectionsWidget.m
//  mafia_AI
//

#import "ConnectionsWidget.h"
#import "DataHub+Connections.h"
#import "ConnectionTypes.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "ConnectionEditController.h"

// Import commentati per ora - li implementeremo dopo
//#import "ConnectionDetailViewController.h"
//#import "ConnectionCreateViewController.h"

// Table view cell identifiers
static NSString * const kConnectionCellIdentifier = @"ConnectionCell";

@interface ConnectionsWidget ()

// UI Components (internal)
@property (nonatomic, strong) NSScrollView *scrollViewInternal;
@property (nonatomic, strong) NSTableView *connectionsTableViewInternal;
@property (nonatomic, strong) NSSearchField *searchFieldInternal;
@property (nonatomic, strong) NSPopUpButton *filterButtonInternal;
@property (nonatomic, strong) NSButton *addConnectionButtonInternal;
@property (nonatomic, strong) NSButton *settingsButtonInternal;
@property (nonatomic, strong) NSTextField *statusLabelInternal;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicatorInternal;

// Sheet controllers (per ora commentati)
//@property (nonatomic, strong) ConnectionDetailViewController *detailViewController;
//@property (nonatomic, strong) ConnectionCreateViewController *createViewController;

// State
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL compactView;

// Private methods
- (void)setupContextMenu;
- (void)configureCell:(NSTableCellView *)cellView withConnection:(ConnectionModel *)connection;
- (NSTableCellView *)createConnectionCellView;
- (void)populateTypeSelector:(NSPopUpButton *)selector;
- (void)showAlert:(NSString *)title message:(NSString *)message;
- (void)showTemporaryMessage:(NSString *)message;

@end

@implementation ConnectionsWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Connections";
        
        // Initialize state
        _allConnections = @[];
        _filteredConnections = @[];
        _searchText = @"";
        _selectedFilter = -1; // All types
        _showOnlyActive = YES;
        _isLoading = NO;
        _compactView = NO;
        
        // Register for notifications
        [self registerForNotifications];
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    // Create main layout
    [self createToolbar];
    [self createTableView];
    [self createStatusView];
    [self layoutComponents];
    
    // Load initial data
    [self refreshConnections];
    
    // Setup auto-refresh
    [self startAutoRefresh];
    self.connectionsTableViewInternal.doubleAction = @selector(tableViewDoubleClick:);
    self.connectionsTableViewInternal.target = self;
}

#pragma mark - UI Creation

- (void)createToolbar {
    // Search field
    self.searchFieldInternal = [[NSSearchField alloc] init];
    self.searchFieldInternal.placeholderString = @"Search connections...";
    self.searchFieldInternal.delegate = self;
    self.searchFieldInternal.target = self;
    self.searchFieldInternal.action = @selector(searchFieldChanged:);
    
    // Filter popup
    self.filterButtonInternal = [[NSPopUpButton alloc] init];
    self.filterButtonInternal.target = self;
    self.filterButtonInternal.action = @selector(filterChanged:);
    [self populateFilterMenu];
    
    // New connection button
    self.addConnectionButtonInternal = [[NSButton alloc] init];
    self.addConnectionButtonInternal.title = @"New";
    self.addConnectionButtonInternal.bezelStyle = NSBezelStyleRounded;
    self.addConnectionButtonInternal.target = self;
    self.addConnectionButtonInternal.action = @selector(createNewConnection);
    
    // Settings button
    self.settingsButtonInternal = [[NSButton alloc] init];
    self.settingsButtonInternal.title = @"⚙";
    self.settingsButtonInternal.bezelStyle = NSBezelStyleRounded;
    self.settingsButtonInternal.target = self;
    self.settingsButtonInternal.action = @selector(showSettingsMenu:);
}

// Nel metodo createTableView di ConnectionsWidget.m, aggiorna l'altezza:

- (void)createTableView {
    // Create table view
    self.connectionsTableViewInternal = [[NSTableView alloc] init];
    self.connectionsTableViewInternal.dataSource = self;
    self.connectionsTableViewInternal.delegate = self;
    self.connectionsTableViewInternal.headerView = nil;
    self.connectionsTableViewInternal.intercellSpacing = NSMakeSize(0, 4); // Più spazio tra righe
    self.connectionsTableViewInternal.rowHeight = 60; // Aumentata da 50 a 60 per strength bar
    self.connectionsTableViewInternal.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    self.connectionsTableViewInternal.allowsMultipleSelection = YES;
    
    // Create table column
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"connection"];
    column.title = @"Connection";
    column.width = 300;
    [self.connectionsTableViewInternal addTableColumn:column];
    
    // Create scroll view
    self.scrollViewInternal = [[NSScrollView alloc] init];
    self.scrollViewInternal.documentView = self.connectionsTableViewInternal;
    self.scrollViewInternal.hasVerticalScroller = YES;
    self.scrollViewInternal.hasHorizontalScroller = NO;
    self.scrollViewInternal.autohidesScrollers = YES;
    
    // Setup context menu
    [self setupContextMenu];
}

// E aggiorna anche il metodo toggleCompactView:
- (void)toggleCompactView {
    self.compactView = !self.compactView;
    
    // Update row height - ora con strength bar considerata
    self.connectionsTableViewInternal.rowHeight = self.compactView ? 45 : 60;
    [self.connectionsTableViewInternal reloadData];
    
    NSLog(@"ConnectionsWidget: Toggled compact view: %@", self.compactView ? @"ON" : @"OFF");
}

- (void)createStatusView {
    // Status label
    self.statusLabelInternal = [[NSTextField alloc] init];
    self.statusLabelInternal.editable = NO;
    self.statusLabelInternal.bordered = NO;
    self.statusLabelInternal.backgroundColor = [NSColor clearColor];
    self.statusLabelInternal.font = [NSFont systemFontOfSize:11];
    self.statusLabelInternal.textColor = [NSColor secondaryLabelColor];
    self.statusLabelInternal.stringValue = @"Loading connections...";
    
    // Loading indicator
    self.loadingIndicatorInternal = [[NSProgressIndicator alloc] init];
    self.loadingIndicatorInternal.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicatorInternal.controlSize = NSControlSizeSmall;
    self.loadingIndicatorInternal.hidden = YES;
}

- (void)layoutComponents {
    // Add all views to content view
    [self.contentView addSubview:self.searchFieldInternal];
    [self.contentView addSubview:self.filterButtonInternal];
    [self.contentView addSubview:self.addConnectionButtonInternal];
    [self.contentView addSubview:self.settingsButtonInternal];
    [self.contentView addSubview:self.scrollViewInternal];
    [self.contentView addSubview:self.statusLabelInternal];
    [self.contentView addSubview:self.loadingIndicatorInternal];
    
    // Disable autoresizing masks
    for (NSView *view in @[self.searchFieldInternal, self.filterButtonInternal,
                          self.addConnectionButtonInternal, self.settingsButtonInternal,
                          self.scrollViewInternal, self.statusLabelInternal,
                          self.loadingIndicatorInternal]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
    }
    
    // Setup constraints
    [self setupConstraints];
}

- (void)setupConstraints {
    // Toolbar constraints
    [NSLayoutConstraint activateConstraints:@[
        // Search field
        [self.searchFieldInternal.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.searchFieldInternal.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.searchFieldInternal.widthAnchor constraintGreaterThanOrEqualToConstant:150],
        
        // Filter button
        [self.filterButtonInternal.topAnchor constraintEqualToAnchor:self.searchFieldInternal.topAnchor],
        [self.filterButtonInternal.leadingAnchor constraintEqualToAnchor:self.searchFieldInternal.trailingAnchor constant:8],
        [self.filterButtonInternal.widthAnchor constraintEqualToConstant:100],
        
        // New button
        [self.addConnectionButtonInternal.topAnchor constraintEqualToAnchor:self.searchFieldInternal.topAnchor],
        [self.addConnectionButtonInternal.trailingAnchor constraintEqualToAnchor:self.settingsButtonInternal.leadingAnchor constant:-8],
        [self.addConnectionButtonInternal.widthAnchor constraintEqualToConstant:60],
        
        // Settings button
        [self.settingsButtonInternal.topAnchor constraintEqualToAnchor:self.searchFieldInternal.topAnchor],
        [self.settingsButtonInternal.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.settingsButtonInternal.widthAnchor constraintEqualToConstant:30],
        
        // Table view
        [self.scrollViewInternal.topAnchor constraintEqualToAnchor:self.searchFieldInternal.bottomAnchor constant:8],
        [self.scrollViewInternal.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.scrollViewInternal.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.scrollViewInternal.bottomAnchor constraintEqualToAnchor:self.statusLabelInternal.topAnchor constant:-8],
        
        // Status bar
        [self.statusLabelInternal.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.statusLabelInternal.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.statusLabelInternal.trailingAnchor constraintLessThanOrEqualToAnchor:self.loadingIndicatorInternal.leadingAnchor constant:-8],
        
        // Loading indicator
        [self.loadingIndicatorInternal.centerYAnchor constraintEqualToAnchor:self.statusLabelInternal.centerYAnchor],
        [self.loadingIndicatorInternal.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8]
    ]];
}

#pragma mark - Property Accessors

- (NSScrollView *)scrollView { return self.scrollViewInternal; }
- (NSTableView *)connectionsTableView { return self.connectionsTableViewInternal; }
- (NSSearchField *)searchField { return self.searchFieldInternal; }
- (NSPopUpButton *)filterButton { return self.filterButtonInternal; }
- (NSButton *)newConnectionButton { return self.addConnectionButtonInternal; }
- (NSButton *)settingsButton { return self.settingsButtonInternal; }
- (NSTextField *)statusLabel { return self.statusLabelInternal; }
- (NSProgressIndicator *)loadingIndicator { return self.loadingIndicatorInternal; }

#pragma mark - Data Management

- (void)refreshConnections {
    self.isLoading = YES;
    [self.loadingIndicatorInternal setHidden:NO];
    [self.loadingIndicatorInternal startAnimation:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Get connections from DataHub
        DataHub *dataHub = [DataHub shared];
        NSArray<ConnectionModel *> *connections = [dataHub getAllConnections];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allConnections = connections;
            [self applyFilters];
            
            self.isLoading = NO;
            [self.loadingIndicatorInternal stopAnimation:nil];
            [self.loadingIndicatorInternal setHidden:YES];
            
            [self updateStatusLabel];
            
            NSLog(@"ConnectionsWidget: Loaded %lu connections", (unsigned long)connections.count);
        });
    });
}

- (void)applyFilters {
    NSMutableArray<ConnectionModel *> *filtered = [NSMutableArray array];
    
    for (ConnectionModel *connection in self.allConnections) {
        BOOL matches = YES;
        
        // Filter by active status
        if (self.showOnlyActive && !connection.isActive) {
            matches = NO;
        }
        
        // Filter by type
        if (self.selectedFilter != -1 && connection.connectionType != self.selectedFilter) {
            matches = NO;
        }
        
        // Filter by search text
        if (self.searchText.length > 0) {
            NSString *searchLower = [self.searchText lowercaseString];
            BOOL titleMatch = [connection.title.lowercaseString containsString:searchLower];
            BOOL descMatch = [connection.connectionDescription.lowercaseString containsString:searchLower];
            BOOL symbolsMatch = NO;
            
            for (NSString *symbol in [connection allInvolvedSymbols]) {
                if ([symbol.lowercaseString containsString:searchLower]) {
                    symbolsMatch = YES;
                    break;
                }
            }
            
            if (!titleMatch && !descMatch && !symbolsMatch) {
                matches = NO;
            }
        }
        
        if (matches) {
            [filtered addObject:connection];
        }
    }
    
    // Sort by creation date (newest first)
    [filtered sortUsingComparator:^NSComparisonResult(ConnectionModel *obj1, ConnectionModel *obj2) {
        return [obj2.creationDate compare:obj1.creationDate];
    }];
    
    self.filteredConnections = [filtered copy];
    [self.connectionsTableViewInternal reloadData];
}

- (void)updateStatusLabel {
    NSString *statusText;
    NSInteger totalConnections = self.allConnections.count;
    NSInteger filteredConnections = self.filteredConnections.count;
    
    if (totalConnections == 0) {
        statusText = @"No connections";
    } else if (filteredConnections == totalConnections) {
        statusText = [NSString stringWithFormat:@"%ld connections", (long)totalConnections];
    } else {
        statusText = [NSString stringWithFormat:@"%ld of %ld connections",
                     (long)filteredConnections, (long)totalConnections];
    }
    
    self.statusLabelInternal.stringValue = statusText;
}

#pragma mark - NSTableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredConnections.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row {
    
    if (row >= self.filteredConnections.count) return nil;
    
    ConnectionModel *connection = self.filteredConnections[row];
    
    // Create custom cell view
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:kConnectionCellIdentifier owner:self];
    
    if (!cellView) {
        cellView = [self createConnectionCellView];
        cellView.identifier = kConnectionCellIdentifier;
    }
    
    [self configureCell:cellView withConnection:connection];
    
    return cellView;
}

#pragma mark - NSTableView Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.connectionsTableViewInternal.selectedRow;
    
    if (selectedRow >= 0 && selectedRow < self.filteredConnections.count) {
        ConnectionModel *selectedConnection = self.filteredConnections[selectedRow];
        NSLog(@"ConnectionsWidget: Selected connection: %@", selectedConnection.title);
    }
}

- (void)tableView:(NSTableView *)tableView didDoubleClickAtRow:(NSInteger)row {
    if (row >= 0 && row < self.filteredConnections.count) {
        ConnectionModel *connection = self.filteredConnections[row];
        [self editConnection:connection];
    }
}

#pragma mark - NSSearchField Delegate

- (void)searchFieldChanged:(NSSearchField *)sender {
    self.searchText = sender.stringValue;
    [self applyFilters];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object == self.searchFieldInternal) {
        [self searchFieldChanged:self.searchFieldInternal];
    }
}

#pragma mark - Custom Cell Creation

// Sostituisci questi metodi in ConnectionsWidget.m per celle più belle:

// Sostituisci il metodo createConnectionCellView in ConnectionsWidget.m:

- (NSTableCellView *)createConnectionCellView {
    NSTableCellView *cellView = [[NSTableCellView alloc] init];
    
    // Container con background
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 55)];
    containerView.wantsLayer = YES;
    containerView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    containerView.layer.cornerRadius = 6.0;
    
    // Type icon (left)
    NSImageView *typeIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(8, 20, 16, 16)];
    typeIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
    
    // Title label (main)
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(32, 28, 180, 18)];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    titleLabel.cell.lineBreakMode = NSLineBreakByTruncatingTail;
    
    // Symbols label (subtitle)
    NSTextField *symbolsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(32, 10, 180, 14)];
    symbolsLabel.editable = NO;
    symbolsLabel.bordered = NO;
    symbolsLabel.backgroundColor = [NSColor clearColor];
    symbolsLabel.font = [NSFont systemFontOfSize:11];
    symbolsLabel.textColor = [NSColor secondaryLabelColor];
    symbolsLabel.cell.lineBreakMode = NSLineBreakByTruncatingTail;
    
    // Date label (top right)
    NSTextField *dateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(220, 35, 70, 12)];
    dateLabel.editable = NO;
    dateLabel.bordered = NO;
    dateLabel.backgroundColor = [NSColor clearColor];
    dateLabel.font = [NSFont systemFontOfSize:9];
    dateLabel.textColor = [NSColor tertiaryLabelColor];
    dateLabel.alignment = NSTextAlignmentRight;
    
    // AI indicator (top right, next to date)
    NSImageView *aiIndicator = [[NSImageView alloc] initWithFrame:NSMakeRect(275, 35, 10, 10)];
    aiIndicator.image = [NSImage imageWithSystemSymbolName:@"brain" accessibilityDescription:@"AI Summary"];
    aiIndicator.hidden = YES;
    
    // NUOVO: Strength progress bar (bottom right)
    NSProgressIndicator *strengthBar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(220, 15, 50, 6)];
    strengthBar.style = NSProgressIndicatorStyleBar;
    strengthBar.indeterminate = NO;
    strengthBar.minValue = 0.0;
    strengthBar.maxValue = 100.0;
    strengthBar.wantsLayer = YES;
    strengthBar.layer.cornerRadius = 3.0;
    
    // NUOVO: Strength percentage label
    NSTextField *strengthLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(275, 12, 25, 12)];
    strengthLabel.editable = NO;
    strengthLabel.bordered = NO;
    strengthLabel.backgroundColor = [NSColor clearColor];
    strengthLabel.font = [NSFont systemFontOfSize:9 weight:NSFontWeightMedium];
    strengthLabel.textColor = [NSColor labelColor];
    strengthLabel.alignment = NSTextAlignmentRight;
    
    // Add all subviews
    [containerView addSubview:typeIcon];
    [containerView addSubview:titleLabel];
    [containerView addSubview:symbolsLabel];
    [containerView addSubview:dateLabel];
    [containerView addSubview:aiIndicator];
    [containerView addSubview:strengthBar];      // NUOVO
    [containerView addSubview:strengthLabel];    // NUOVO
    
    [cellView addSubview:containerView];
    
    // Set references for easy access (using tags)
    cellView.imageView = typeIcon;
    cellView.textField = titleLabel;
    symbolsLabel.tag = 100;
    dateLabel.tag = 101;
    aiIndicator.tag = 102;
    strengthLabel.tag = 104;      // NUOVO
    
    return cellView;
}

// Aggiorna anche configureCell per gestire la strength bar:
- (void)configureCell:(NSTableCellView *)cellView withConnection:(ConnectionModel *)connection {
    // Update connection strength
    [connection updateCurrentStrength];
    
    // Title
    cellView.textField.stringValue = connection.title ?: @"Untitled Connection";
    
    // Type icon
    NSString *iconName = [connection typeIcon];
    NSImage *typeImage = [NSImage imageWithSystemSymbolName:iconName accessibilityDescription:@"Connection Type"];
    if (typeImage) {
        cellView.imageView.image = typeImage;
        cellView.imageView.contentTintColor = [connection typeColor];
    }
    
    // Symbols text
    NSTextField *symbolsLabel = [cellView viewWithTag:100];
    NSString *symbolsText = [self formatSymbolsForConnection:connection];
    symbolsLabel.stringValue = symbolsText;
    
    // Date
    NSTextField *dateLabel = [cellView viewWithTag:101];
    dateLabel.stringValue = [self formatDateForConnection:connection];
    
    // AI indicator
    NSImageView *aiIndicator = [cellView viewWithTag:102];
    aiIndicator.hidden = ![connection hasSummary];
    if ([connection hasSummary]) {
        if (connection.summarySource == ConnectionSummarySourceAI) {
            aiIndicator.contentTintColor = [NSColor systemBlueColor];
            aiIndicator.toolTip = @"AI Summary";
        } else if (connection.summarySource == ConnectionSummarySourceBoth) {
            aiIndicator.contentTintColor = [NSColor systemPurpleColor];
            aiIndicator.toolTip = @"AI + Manual Summary";
        } else {
            aiIndicator.contentTintColor = [NSColor systemGrayColor];
            aiIndicator.toolTip = @"Manual Summary";
        }
    }
    
    // NUOVO: Strength bar configuration
    NSProgressIndicator *strengthBar = [cellView viewWithTag:103];
    NSTextField *strengthLabel = [cellView viewWithTag:104];
    
    double strengthPercent = connection.currentStrength * 100.0;
    strengthBar.doubleValue = strengthPercent;
    strengthLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", strengthPercent];
    
    // Color the strength bar based on value
    NSColor *strengthColor;
    if (connection.currentStrength >= 0.8) {
        strengthColor = [NSColor systemGreenColor];
    } else if (connection.currentStrength >= 0.5) {
        strengthColor = [NSColor systemYellowColor];
    } else if (connection.currentStrength >= 0.3) {
        strengthColor = [NSColor systemOrangeColor];
    } else {
        strengthColor = [NSColor systemRedColor];
    }
    
    // Apply color to progress bar (tricky in macOS, use appearance)
    if (connection.currentStrength >= 0.8) {
        strengthBar.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    } else if (connection.currentStrength >= 0.5) {
        strengthBar.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight];
    } else {
        strengthBar.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    }
    
    // Color the percentage label
    strengthLabel.textColor = strengthColor;
    
    // Add tooltip with detailed info
    NSString *strengthTooltip = [NSString stringWithFormat:@"Strength: %.1f%%\nInitial: %.1f%%\nDecay Rate: %.2f\nDays until minimum: %ld",
                                strengthPercent,
                                connection.initialStrength * 100.0,
                                connection.decayRate,
                                (long)[connection daysUntilMinimumStrength]];
    strengthBar.toolTip = strengthTooltip;
    strengthLabel.toolTip = strengthTooltip;
    
    // Container selection style
    NSView *containerView = [cellView viewWithTag:105];
    if (cellView.backgroundStyle == NSBackgroundStyleEmphasized) {
        containerView.layer.backgroundColor = [NSColor selectedControlColor].CGColor;
    } else {
        containerView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    }
}

// BONUS: Aggiungi animazione smooth per strength updates
- (void)animateStrengthUpdateForCell:(NSTableCellView *)cellView toValue:(double)newStrength {
    NSProgressIndicator *strengthBar = [cellView viewWithTag:103];
    NSTextField *strengthLabel = [cellView viewWithTag:104];
    
    if (!strengthBar || !strengthLabel) return;
    
    double currentValue = strengthBar.doubleValue;
    double targetValue = newStrength * 100.0;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.5;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        strengthBar.animator.doubleValue = targetValue;
        
        // Update label after animation
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            strengthLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", targetValue];
        });
    }];
}
// Helper methods che servono:
- (NSString *)formatSymbolsForConnection:(ConnectionModel *)connection {
    NSArray *symbols = [connection allInvolvedSymbols];
    
    if (symbols.count == 0) return @"No symbols";
    
    if (connection.bidirectional) {
        return [symbols componentsJoinedByString:@" ↔ "];
    } else {
        if (connection.sourceSymbol && connection.targetSymbols.count > 0) {
            NSString *targets = [connection.targetSymbols componentsJoinedByString:@", "];
            return [NSString stringWithFormat:@"%@ → %@", connection.sourceSymbol, targets];
        }
    }
    
    return [symbols componentsJoinedByString:@", "];
}

- (NSString *)formatDateForConnection:(ConnectionModel *)connection {
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:connection.creationDate];
    
    if (timeInterval < 60) {
        return @"now";
    } else if (timeInterval < 3600) {
        NSInteger minutes = (NSInteger)(timeInterval / 60);
        return [NSString stringWithFormat:@"%ldm", (long)minutes];
    } else if (timeInterval < 86400) {
        NSInteger hours = (NSInteger)(timeInterval / 3600);
        return [NSString stringWithFormat:@"%ldh", (long)hours];
    } else if (timeInterval < 604800) {
        NSInteger days = (NSInteger)(timeInterval / 86400);
        return [NSString stringWithFormat:@"%ldd", (long)days];
    } else {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MM/dd";
        return [formatter stringFromDate:connection.creationDate];
    }
}



#pragma mark - Actions (Simplified for now)

- (void)tableViewDoubleClick:(id)sender {
    NSInteger clickedRow = self.connectionsTableViewInternal.clickedRow;
    if (clickedRow >= 0 && clickedRow < self.filteredConnections.count) {
        ConnectionModel *connection = self.filteredConnections[clickedRow];
        [self editConnection:connection];
    }
}

- (void)createConnectionFromSymbols:(NSArray<NSString *> *)symbols {
    NSLog(@"ConnectionsWidget: Creating connection from symbols: %@", symbols);
    
    if (symbols.count < 2) {
        [self showAlert:@"Invalid Selection" message:@"Please select at least 2 symbols to create a connection."];
        return;
    }
    
    // Create quick connection dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create Connection from Chain";
    alert.informativeText = [NSString stringWithFormat:@"Create a connection between: %@", [symbols componentsJoinedByString:@", "]];
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Advanced..."];
    [alert addButtonWithTitle:@"Cancel"];
    
    // Simple form for quick creation
    NSStackView *quickStack = [[NSStackView alloc] init];
    quickStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    quickStack.spacing = 8;
    
    // Title field
    NSTextField *titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 250, 24)];
    titleField.placeholderString = @"Connection title...";
    NSString *defaultTitle = [NSString stringWithFormat:@"%@ Connection", [symbols componentsJoinedByString:@"-"]];
    titleField.stringValue = defaultTitle;
    
    // Connection type selector
    NSPopUpButton *typeSelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 250, 24)];
    [self populateTypeSelector:typeSelector];
    
    [quickStack addArrangedSubview:[NSTextField labelWithString:@"Title:"]];
    [quickStack addArrangedSubview:titleField];
    [quickStack addArrangedSubview:[NSTextField labelWithString:@"Type:"]];
    [quickStack addArrangedSubview:typeSelector];
    
    alert.accessoryView = quickStack;
    [alert.window setInitialFirstResponder:titleField];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        // Quick create - bidirectional
        NSString *title = titleField.stringValue.length > 0 ? titleField.stringValue : defaultTitle;
        StockConnectionType type = (StockConnectionType)typeSelector.selectedTag;
        
        [self createConnectionWithTitle:title
                                symbols:symbols
                                   type:type
                          bidirectional:YES
                                    url:nil
                            description:nil];
        
    } else if (response == NSAlertSecondButtonReturn) {
        // Advanced create - open full dialog
        [self createNewConnection];
    }
    // Cancel = do nothing
}

- (void)createNewConnection {
    NSLog(@"ConnectionsWidget: Opening connection creation dialog");
    
    ConnectionEditController *editController = [ConnectionEditController controllerForCreating];
    
    editController.onSave = ^(ConnectionModel *newConnectionModel) {
        NSLog(@"Connection created: %@", newConnectionModel.title);
        [self refreshConnections];
        [self showTemporaryMessage:@"Connection created successfully"];
    };
    
    editController.onCancel = ^{
        NSLog(@"Connection creation cancelled");
    };
    
    // Usa i metodi standard di NSWindowController
    [editController.window makeKeyAndOrderFront:nil];
    [editController.window center];
}


- (void)editConnection:(ConnectionModel *)connection {
    NSLog(@"ConnectionsWidget: Editing connection: %@", connection.title);
    
    ConnectionEditController *editController = [ConnectionEditController controllerForEditing:connection];
    
    editController.onSave = ^(ConnectionModel *updatedModel) {
        NSLog(@"Connection updated: %@", updatedModel.title);
        [self refreshConnections];
        [self showTemporaryMessage:@"Connection updated successfully"];
    };
    
    editController.onCancel = ^{
        NSLog(@"Connection editing cancelled");
    };
    
    [editController.window makeKeyAndOrderFront:nil];
    [editController.window center];
    
}
// Helper method per creare labels
- (NSTextField *)createLabel:(NSString *)text at:(NSPoint)point {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = NSMakeRect(point.x, point.y, 200, 17);
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    return label;
}
- (void)createConnectionWithTitle:(NSString *)title
                          symbols:(NSArray<NSString *> *)symbols
                             type:(StockConnectionType)type
                    bidirectional:(BOOL)bidirectional
                              url:(NSString *)url
                      description:(NSString *)description {
    
    DataHub *dataHub = [DataHub shared];
    ConnectionModel *connection;
    
    if (bidirectional) {
        // Create bidirectional connection
        connection = [dataHub createBidirectionalConnectionWithSymbols:symbols
                                                                   type:type
                                                                  title:title];
    } else {
        // Create directional connection (first symbol -> rest)
        NSString *sourceSymbol = symbols[0];
        NSArray *targetSymbols = symbols.count > 1 ? [symbols subarrayWithRange:NSMakeRange(1, symbols.count - 1)] : @[];
        
        connection = [dataHub createDirectionalConnectionFromSymbol:sourceSymbol
                                                          toSymbols:targetSymbols
                                                               type:type
                                                              title:title];
    }
    
    if (connection) {
        // Set additional properties
        if (description) {
            connection.connectionDescription = description;
        }
        if (url) {
            connection.url = url;
        }
        
        // Update the connection
        [dataHub updateConnection:connection];
        
        // Show success message
        [self showTemporaryMessage:[NSString stringWithFormat:@"Created connection: %@", title]];
        
        NSLog(@"ConnectionsWidget: Successfully created connection '%@' with %lu symbols",
              title, (unsigned long)symbols.count);
    } else {
        [self showAlert:@"Creation Failed" message:@"Could not create connection. Please try again."];
    }
}


- (void)deleteConnection:(ConnectionModel *)connection {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Connection";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?", connection.title];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        DataHub *dataHub = [DataHub shared];
        [dataHub deleteConnection:connection];
        [self showTemporaryMessage:@"Connection deleted"];
    }
}

- (void)filterChanged:(NSPopUpButton *)sender {
    NSInteger selectedIndex = sender.indexOfSelectedItem;
    
    if (selectedIndex == 0) {
        self.selectedFilter = -1; // All types
    } else if (selectedIndex > 1) { // Skip separator
        NSMenuItem *item = [sender.menu itemAtIndex:selectedIndex];
        self.selectedFilter = (StockConnectionType)item.tag;
    }
    
    [self applyFilters];
}

- (void)showSettingsMenu:(NSButton *)sender {
    NSMenu *menu = [[NSMenu alloc] init];
    
    NSMenuItem *activeItem = [menu addItemWithTitle:@"Show Only Active"
                                             action:@selector(toggleShowOnlyActive)
                                      keyEquivalent:@""];
    activeItem.target = self;
    activeItem.state = self.showOnlyActive ? NSControlStateValueOn : NSControlStateValueOff;
    
    [NSMenu popUpContextMenu:menu withEvent:[NSApp currentEvent] forView:sender];
}

- (void)toggleShowOnlyActive {
    self.showOnlyActive = !self.showOnlyActive;
    [self applyFilters];
}

#pragma mark - Helper Methods

- (void)populateFilterMenu {
    [self.filterButtonInternal removeAllItems];
    
    // Add "All" option
    [self.filterButtonInternal addItemWithTitle:@"All Types"];
    
    // Add separator
    [[self.filterButtonInternal menu] addItem:[NSMenuItem separatorItem]];
    
    // Add connection types
    for (NSInteger i = 0; i < 10; i++) { // Assuming 10 connection types
        StockConnectionType type = (StockConnectionType)i;
        NSString *typeString = StringFromConnectionType(type);
        NSMenuItem *item = [self.filterButtonInternal.menu addItemWithTitle:typeString
                                                                      action:nil
                                                               keyEquivalent:@""];
        item.tag = type;
    }
}

- (void)populateTypeSelector:(NSPopUpButton *)selector {
    [selector removeAllItems];
    
    for (NSInteger i = 0; i < 10; i++) {
        StockConnectionType type = (StockConnectionType)i;
        NSString *typeString = StringFromConnectionType(type);
        NSMenuItem *item = [selector.menu addItemWithTitle:typeString action:nil keyEquivalent:@""];
        item.tag = type;
    }
    
    [selector selectItemAtIndex:0];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)showTemporaryMessage:(NSString *)message {
    NSString *originalStatus = self.statusLabelInternal.stringValue;
    self.statusLabelInternal.stringValue = message;
    self.statusLabelInternal.textColor = [NSColor systemGreenColor];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.statusLabelInternal.stringValue = originalStatus;
        self.statusLabelInternal.textColor = [NSColor secondaryLabelColor];
    });
}
- (void)setupContextMenu {
    NSMenu *contextMenu = [[NSMenu alloc] init];
    
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit Connection"
                                                      action:@selector(editSelectedConnection:)
                                               keyEquivalent:@""];
    editItem.target = self;
    [contextMenu addItem:editItem];
    
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Connection"
                                                        action:@selector(deleteSelectedConnection:)
                                                 keyEquivalent:@""];
    deleteItem.target = self;
    [contextMenu addItem:deleteItem];
    
    self.connectionsTableViewInternal.menu = contextMenu;
}

- (void)editSelectedConnection:(id)sender {
    NSInteger selectedRow = self.connectionsTableViewInternal.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.filteredConnections.count) {
        ConnectionModel *connection = self.filteredConnections[selectedRow];
        [self editConnection:connection];
    }
}

- (void)deleteSelectedConnection:(id)sender {
    NSInteger selectedRow = self.connectionsTableViewInternal.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.filteredConnections.count) {
        ConnectionModel *connection = self.filteredConnections[selectedRow];
        [self deleteConnection:connection];
    }
}

- (void)contextMenuDeleteConnection:(NSMenuItem *)sender {
    ConnectionModel *connection = [self selectedConnection];
    if (connection) {
        [self deleteConnection:connection];
    }
}

- (ConnectionModel *)selectedConnection {
    NSInteger selectedRow = self.connectionsTableViewInternal.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.filteredConnections.count) {
        return self.filteredConnections[selectedRow];
    }
    return nil;
}

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(connectionsUpdated:)
               name:DataHubConnectionsUpdatedNotification
             object:nil];
}

- (void)connectionsUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshConnections];
    });
}

- (void)startAutoRefresh {
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                         target:self
                                                       selector:@selector(refreshConnections)
                                                       userInfo:nil
                                                        repeats:YES];
}

#pragma mark - Chain Integration (BaseWidget Override)

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    NSString *action = update[@"action"];
    
    if ([action isEqualToString:@"setSymbols"]) {
        NSArray *symbols = update[@"symbols"];
        if (symbols.count >= 2) {
            NSLog(@"ConnectionsWidget: Received %lu symbols from chain", (unsigned long)symbols.count);
            // TODO: Auto-create connection when we implement the creation dialog
        }
    }
}

#pragma mark - State Serialization

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    state[@"searchText"] = self.searchText ?: @"";
    state[@"selectedFilter"] = @(self.selectedFilter);
    state[@"showOnlyActive"] = @(self.showOnlyActive);
    state[@"compactView"] = @(self.compactView);
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    self.searchText = state[@"searchText"] ?: @"";
    self.selectedFilter = [state[@"selectedFilter"] integerValue];
    self.showOnlyActive = state[@"showOnlyActive"] ? [state[@"showOnlyActive"] boolValue] : YES;
    self.compactView = [state[@"compactView"] boolValue];
    
    // Update UI
    self.searchFieldInternal.stringValue = self.searchText;
    
    NSInteger filterIndex = self.selectedFilter == -1 ? 0 : self.selectedFilter + 2;
    if (filterIndex < self.filterButtonInternal.numberOfItems) {
        [self.filterButtonInternal selectItemAtIndex:filterIndex];
    }
    
    [self applyFilters];
}

#pragma mark - Memory Management

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.refreshTimer invalidate];
}
#pragma mark - Advanced Dialog Actions

- (void)initialStrengthChanged:(NSSlider *)slider {
    // Find the value label and update it
    NSView *strengthView = slider.superview;
    for (NSView *subview in strengthView.subviews) {
        if ([subview isKindOfClass:[NSTextField class]]) {
            NSTextField *label = (NSTextField *)subview;
            if (NSPointInRect(NSMakePoint(330, 0), label.frame)) {
                label.stringValue = [NSString stringWithFormat:@"%.0f%%", slider.doubleValue * 100];
                break;
            }
        }
    }
}

- (void)enableDecayChanged:(NSButton *)checkbox {
    BOOL enabled = checkbox.state == NSControlStateValueOn;
    
    // Enable/disable related controls
    NSView *strengthView = checkbox.superview;
    for (NSView *subview in strengthView.subviews) {
        if ([subview isKindOfClass:[NSSlider class]]) {
            NSSlider *slider = (NSSlider *)subview;
            if (slider.tag != 1005) { // Not the initial strength slider
                slider.enabled = enabled;
            }
        } else if ([subview isKindOfClass:[NSDatePicker class]]) {
            ((NSDatePicker *)subview).enabled = enabled;
        } else if ([subview isKindOfClass:[NSButton class]] && subview != checkbox) {
            ((NSButton *)subview).enabled = enabled;
        }
    }
}

- (void)validateSymbols:(NSButton *)button {
    NSWindow *window = button.window;
    NSTextField *symbolsField = [window.contentView viewWithTag:1002];
    
    NSString *symbolsText = symbolsField.stringValue;
    if (symbolsText.length == 0) {
        [self showAlert:@"Validation" message:@"Please enter symbols to validate."];
        return;
    }
    
    NSArray *symbols = [symbolsText componentsSeparatedByString:@","];
    NSMutableArray *cleanSymbols = [NSMutableArray array];
    NSMutableArray *invalidSymbols = [NSMutableArray array];
    
    for (NSString *symbol in symbols) {
        NSString *cleanSymbol = [[symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        if (cleanSymbol.length > 0) {
            // Basic validation - you could enhance this with real symbol lookup
            if ([cleanSymbol rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].location == NSNotFound) {
                [cleanSymbols addObject:cleanSymbol];
            } else {
                [invalidSymbols addObject:cleanSymbol];
            }
        }
    }
    
    NSString *message;
    if (invalidSymbols.count > 0) {
        message = [NSString stringWithFormat:@"Valid: %@\n\nInvalid: %@",
                  [cleanSymbols componentsJoinedByString:@", "],
                  [invalidSymbols componentsJoinedByString:@", "]];
    } else {
        message = [NSString stringWithFormat:@"All symbols are valid:\n%@", [cleanSymbols componentsJoinedByString:@", "]];
        // Update the field with cleaned symbols
        symbolsField.stringValue = [cleanSymbols componentsJoinedByString:@", "];
    }
    
    [self showAlert:@"Symbol Validation" message:message];
}

- (void)generateAISummaryInDialog:(NSButton *)button {
    NSWindow *window = button.window;
    NSTextField *urlField = [window.contentView viewWithTag:1010];
    
    NSString *url = urlField.stringValue;
    if (url.length == 0) {
        [self showAlert:@"AI Summary" message:@"Please enter a URL first."];
        return;
    }
    
    // Show progress
    button.title = @"Generating...";
    button.enabled = NO;
    
    // Simulate AI summary generation (replace with real implementation)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        button.title = @"AI Summary";
        button.enabled = YES;
        
        // Find description text view and populate it
        NSTabView *tabView = nil;
        for (NSView *subview in window.contentView.subviews) {
            if ([subview isKindOfClass:[NSTabView class]]) {
                tabView = (NSTabView *)subview;
                break;
            }
        }
        
        if (tabView) {
            NSTabViewItem *contentTab = [tabView tabViewItemAtIndex:2]; // Content tab
            NSView *contentView = contentTab.view;
            
            for (NSView *subview in contentView.subviews) {
                if ([subview isKindOfClass:[NSScrollView class]]) {
                    NSScrollView *scrollView = (NSScrollView *)subview;
                    if ([scrollView.documentView isKindOfClass:[NSTextView class]]) {
                        NSTextView *textView = (NSTextView *)scrollView.documentView;
                         // Description text view
                            textView.string = @"[AI Generated] This news article discusses a strategic partnership between the mentioned companies, focusing on technological collaboration and market expansion opportunities. The partnership is expected to have positive implications for both companies' market positions.";
                            break;
                        
                    }
                }
            }
        }
        
        [self showAlert:@"AI Summary" message:@"AI summary generated and added to description field."];
    });
}


- (void)previewConnection:(NSButton *)button {
    NSWindow *window = button.window;
    
    // Collect all form data
    NSTextField *titleField = [window.contentView viewWithTag:1001];
    NSTextField *symbolsField = [window.contentView viewWithTag:1002];
    NSPopUpButton *typeSelector = [window.contentView viewWithTag:1003];
    NSMatrix *directionMatrix = [window.contentView viewWithTag:1004];
    NSSlider *initialSlider = [window.contentView viewWithTag:1005];
    NSTextField *tagsField = [window.contentView viewWithTag:1013];
    
    // Build preview text
    NSMutableString *preview = [NSMutableString string];
    [preview appendFormat:@"PREVIEW: %@\n\n", titleField.stringValue ?: @"Untitled Connection"];
    [preview appendFormat:@"Symbols: %@\n", symbolsField.stringValue ?: @"None"];
    [preview appendFormat:@"Type: %@\n", typeSelector.titleOfSelectedItem ?: @"Unknown"];
    
    NSInteger selectedRow = [directionMatrix selectedRow];
    NSString *direction = @"Bidirectional";
    if (selectedRow == 1) direction = @"Directional";
    else if (selectedRow == 2) direction = @"Chain";
    [preview appendFormat:@"Direction: %@\n", direction];
    
    [preview appendFormat:@"Initial Strength: %.0f%%\n", initialSlider.doubleValue * 100];
    
    if (tagsField.stringValue.length > 0) {
        [preview appendFormat:@"Tags: %@\n", tagsField.stringValue];
    }
    
    [preview appendString:@"\nThis connection will be created when you click 'Create'."];
    
    // Show preview alert
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Connection Preview";
    alert.informativeText = preview;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)createConnectionFromAdvancedDialog:(NSButton *)button {
    NSWindow *window = objc_getAssociatedObject(button, @"dialogWindow");
    
    // Collect form data
    NSTextField *titleField = [window.contentView viewWithTag:1001];
    NSTextField *symbolsField = [window.contentView viewWithTag:1002];
    NSPopUpButton *typeSelector = [window.contentView viewWithTag:1003];
    NSMatrix *directionMatrix = [window.contentView viewWithTag:1004];
    NSSlider *initialSlider = [window.contentView viewWithTag:1005];
    NSButton *enableDecayCheckbox = [window.contentView viewWithTag:1006];
    NSSlider *decaySlider = [window.contentView viewWithTag:1007];
    NSDatePicker *horizonPicker = [window.contentView viewWithTag:1008];
    NSButton *autoDeleteCheckbox = [window.contentView viewWithTag:1009];
    NSTextField *urlField = [window.contentView viewWithTag:1010];
    NSTextField *tagsField = [window.contentView viewWithTag:1013];
    
    // Get description and notes from text views
    NSString *description = @"";
    NSString *notes = @"";
    
    NSTabView *tabView = nil;
    for (NSView *subview in window.contentView.subviews) {
        if ([subview isKindOfClass:[NSTabView class]]) {
            tabView = (NSTabView *)subview;
            break;
        }
    }
    
    if (tabView) {
        NSTabViewItem *contentTab = [tabView tabViewItemAtIndex:2];
        NSView *contentView = contentTab.view;
        
        for (NSView *subview in contentView.subviews) {
            if ([subview isKindOfClass:[NSScrollView class]]) {
                NSScrollView *scrollView = (NSScrollView *)subview;
                if ([scrollView.documentView isKindOfClass:[NSTextView class]]) {
                    NSTextView *textView = (NSTextView *)scrollView.documentView;
                    if (textView.tag == 1011) {
                        description = textView.string;
                    } else if (textView.tag == 1012) {
                        notes = textView.string;
                    }
                }
            }
        }
    }
    
    // Validate inputs
    NSString *title = [titleField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *symbolsString = [symbolsField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (title.length == 0) {
        [self showAlert:@"Validation Error" message:@"Please enter a connection title."];
        return;
    }
    
    if (symbolsString.length == 0) {
        [self showAlert:@"Validation Error" message:@"Please enter at least one symbol."];
        return;
    }
    
    // Parse symbols
    NSArray *rawSymbols = [symbolsString componentsSeparatedByString:@","];
    NSMutableArray *cleanSymbols = [NSMutableArray array];
    
    for (NSString *symbol in rawSymbols) {
        NSString *cleanSymbol = [[symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        if (cleanSymbol.length > 0) {
            [cleanSymbols addObject:cleanSymbol];
        }
    }
    
    if (cleanSymbols.count == 0) {
        [self showAlert:@"Validation Error" message:@"Please enter valid symbols."];
        return;
    }
    
    // Determine connection properties
    StockConnectionType type = (StockConnectionType)typeSelector.selectedTag;
    NSInteger selectedRow = [directionMatrix selectedRow];
    BOOL bidirectional = (selectedRow == 0);
    
    // Create connection with advanced properties
    ConnectionModel *connection = [self createAdvancedConnectionWithTitle:title
                                                                  symbols:cleanSymbols
                                                                     type:type
                                                            bidirectional:bidirectional
                                                                      url:urlField.stringValue.length > 0 ? urlField.stringValue : nil
                                                              description:description.length > 0 ? description : nil
                                                                    notes:notes.length > 0 ? notes : nil
                                                                     tags:tagsField.stringValue.length > 0 ? tagsField.stringValue : nil
                                                          initialStrength:initialSlider.doubleValue
                                                              enableDecay:enableDecayCheckbox.state == NSControlStateValueOn
                                                                decayRate:decaySlider.doubleValue
                                                           strengthHorizon:enableDecayCheckbox.state == NSControlStateValueOn ? horizonPicker.dateValue : nil
                                                               autoDelete:autoDeleteCheckbox.state == NSControlStateValueOn];
    
    if (connection) {
        [window close];
        [self showTemporaryMessage:[NSString stringWithFormat:@"Created advanced connection: %@", title]];
    } else {
        [self showAlert:@"Creation Failed" message:@"Could not create connection. Please try again."];
    }
}

- (void)cancelAdvancedDialog:(NSButton *)button {
    NSWindow *window = objc_getAssociatedObject(button, @"dialogWindow");
    [window close];
}

#pragma mark - Advanced Connection Creation

- (ConnectionModel *)createAdvancedConnectionWithTitle:(NSString *)title
                                               symbols:(NSArray<NSString *> *)symbols
                                                  type:(StockConnectionType)type
                                         bidirectional:(BOOL)bidirectional
                                                   url:(NSString *)url
                                           description:(NSString *)description
                                                 notes:(NSString *)notes
                                                  tags:(NSString *)tagsString
                                       initialStrength:(double)initialStrength
                                           enableDecay:(BOOL)enableDecay
                                             decayRate:(double)decayRate
                                        strengthHorizon:(NSDate *)strengthHorizon
                                            autoDelete:(BOOL)autoDelete {
    
    DataHub *dataHub = [DataHub shared];
    ConnectionModel *connection;
    
    if (bidirectional) {
        connection = [dataHub createBidirectionalConnectionWithSymbols:symbols
                                                                   type:type
                                                                  title:title];
    } else {
        NSString *sourceSymbol = symbols[0];
        NSArray *targetSymbols = symbols.count > 1 ? [symbols subarrayWithRange:NSMakeRange(1, symbols.count - 1)] : @[];
        
        connection = [dataHub createDirectionalConnectionFromSymbol:sourceSymbol
                                                          toSymbols:targetSymbols
                                                               type:type
                                                              title:title];
    }
    
    if (connection) {
        // Set basic properties
        if (description) connection.connectionDescription = description;
        if (url) connection.url = url;
        if (notes) connection.notes = notes;
        
        // Parse and set tags
        if (tagsString) {
            NSArray *rawTags = [tagsString componentsSeparatedByString:@","];
            NSMutableArray *cleanTags = [NSMutableArray array];
            for (NSString *tag in rawTags) {
                NSString *cleanTag = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (cleanTag.length > 0) {
                    [cleanTags addObject:cleanTag];
                }
            }
            connection.tags = [cleanTags copy];
        }
        
        // Set strength properties
        connection.initialStrength = initialStrength;
        connection.currentStrength = initialStrength;
        
        if (enableDecay) {
            connection.decayRate = decayRate;
            connection.strengthHorizon = strengthHorizon;
            connection.autoDelete = autoDelete;
            connection.minimumStrength = autoDelete ? 0.1 : 0.0;
        } else {
            connection.decayRate = 0.0;
            connection.strengthHorizon = nil;
            connection.autoDelete = NO;
        }
        
        connection.lastStrengthUpdate = [NSDate date];
        
        // Update the connection
        [dataHub updateConnection:connection];
        
        NSLog(@"ConnectionsWidget: Created advanced connection '%@' with %lu symbols, strength: %.1f%%, decay: %@",
              title, (unsigned long)symbols.count, initialStrength * 100, enableDecay ? @"YES" : @"NO");
    }
    
    return connection;
}

#pragma mark - Templates System

- (void)showTemplatesMenu:(NSButton *)button {
    NSMenu *templatesMenu = [[NSMenu alloc] init];
    
    // Partnership template
    NSMenuItem *partnershipItem = [templatesMenu addItemWithTitle:@"🤝 Strategic Partnership"
                                                           action:@selector(applyPartnershipTemplate:)
                                                    keyEquivalent:@""];
    partnershipItem.target = self;
    
    // Merger template
    NSMenuItem *mergerItem = [templatesMenu addItemWithTitle:@"🔄 Merger/Acquisition"
                                                      action:@selector(applyMergerTemplate:)
                                               keyEquivalent:@""];
    mergerItem.target = self;
    
    // Supplier template
    NSMenuItem *supplierItem = [templatesMenu addItemWithTitle:@"📦 Supplier Relationship"
                                                        action:@selector(applySupplierTemplate:)
                                                 keyEquivalent:@""];
    supplierItem.target = self;
    
    // Competitor template
    NSMenuItem *competitorItem = [templatesMenu addItemWithTitle:@"⚡ Competitive Response"
                                                          action:@selector(applyCompetitorTemplate:)
                                                   keyEquivalent:@""];
    competitorItem.target = self;
    
    // Sympathy template
    NSMenuItem *sympathyItem = [templatesMenu addItemWithTitle:@"📈 Sympathy Movement"
                                                        action:@selector(applySympathyTemplate:)
                                                 keyEquivalent:@""];
    sympathyItem.target = self;
    
    [templatesMenu addItem:[NSMenuItem separatorItem]];
    
    // Custom template
    NSMenuItem *customItem = [templatesMenu addItemWithTitle:@"⚙️ Save Current as Template..."
                                                      action:@selector(saveCustomTemplate:)
                                               keyEquivalent:@""];
    customItem.target = self;
    
    [NSMenu popUpContextMenu:templatesMenu withEvent:[NSApp currentEvent] forView:button];
}

- (void)applyPartnershipTemplate:(NSMenuItem *)sender {
    [self applyTemplate:@{
        @"type": @(StockConnectionTypePartnership),
        @"bidirectional": @YES,
        @"initialStrength": @0.9,
        @"enableDecay": @NO,
        @"description": @"Strategic partnership between companies focusing on mutual growth and collaboration."
    }];
}

- (void)applyMergerTemplate:(NSMenuItem *)sender {
    [self applyTemplate:@{
        @"type": @(StockConnectionTypeMerger),
        @"bidirectional": @NO,
        @"initialStrength": @1.0,
        @"enableDecay": @YES,
        @"decayRate": @0.05,
        @"description": @"Merger or acquisition activity affecting both companies' market positions."
    }];
}

- (void)applySupplierTemplate:(NSMenuItem *)sender {
    [self applyTemplate:@{
        @"type": @(StockConnectionTypeSupplier),
        @"bidirectional": @NO,
        @"initialStrength": @0.7,
        @"enableDecay": @YES,
        @"decayRate": @0.1,
        @"description": @"Supplier-customer relationship with potential market impact."
    }];
}

- (void)applyCompetitorTemplate:(NSMenuItem *)sender {
    [self applyTemplate:@{
        @"type": @(StockConnectionTypeCompetitor),
        @"bidirectional": @YES,
        @"initialStrength": @0.6,
        @"enableDecay": @YES,
        @"decayRate": @0.15,
        @"description": @"Competitive relationship where actions by one company may affect the other."
    }];
}

- (void)applySympathyTemplate:(NSMenuItem *)sender {
    [self applyTemplate:@{
        @"type": @(StockConnectionTypeSympathy),
        @"bidirectional": @YES,
        @"initialStrength": @0.5,
        @"enableDecay": @YES,
        @"decayRate": @0.2,
        @"description": @"Sympathy movement where stocks tend to move together based on market sentiment."
    }];
}

- (void)applyTemplate:(NSDictionary *)templateData {
    // Find the current dialog window
    NSWindow *currentWindow = [NSApp keyWindow];
    if (!currentWindow || ![currentWindow.title isEqualToString:@"Create New Connection"]) {
        return;
    }
    
    // Apply template values to form fields
    NSPopUpButton *typeSelector = [currentWindow.contentView viewWithTag:1003];
    NSMatrix *directionMatrix = [currentWindow.contentView viewWithTag:1004];
    NSSlider *initialSlider = [currentWindow.contentView viewWithTag:1005];
    NSButton *enableDecayCheckbox = [currentWindow.contentView viewWithTag:1006];
    NSSlider *decaySlider = [currentWindow.contentView viewWithTag:1007];
    
    // Set type
    StockConnectionType type = [templateData[@"type"] intValue];
    [typeSelector selectItemWithTag:type];
    
    // Set directionality
    BOOL bidirectional = [templateData[@"bidirectional"] boolValue];
    [directionMatrix selectCellAtRow:bidirectional ? 0 : 1 column:0];
    
    // Set strength
    double initialStrength = [templateData[@"initialStrength"] doubleValue];
    initialSlider.doubleValue = initialStrength;
    [self initialStrengthChanged:initialSlider]; // Update label
    
    // Set decay
    BOOL enableDecay = [templateData[@"enableDecay"] boolValue];
    enableDecayCheckbox.state = enableDecay ? NSControlStateValueOn : NSControlStateValueOff;
    [self enableDecayChanged:enableDecayCheckbox]; // Update dependent controls
    
    if (enableDecay && templateData[@"decayRate"]) {
        decaySlider.doubleValue = [templateData[@"decayRate"] doubleValue];
    }
    
    // Set description if provided
    NSString *description = templateData[@"description"];
    if (description) {
        // Find and update description text view
        NSTabView *tabView = nil;
        for (NSView *subview in currentWindow.contentView.subviews) {
            if ([subview isKindOfClass:[NSTabView class]]) {
                tabView = (NSTabView *)subview;
                break;
            }
        }
        
        if (tabView) {
            NSTabViewItem *contentTab = [tabView tabViewItemAtIndex:2];
            NSView *contentView = contentTab.view;
            
            for (NSView *subview in contentView.subviews) {
                if ([subview isKindOfClass:[NSScrollView class]]) {
                    NSScrollView *scrollView = (NSScrollView *)subview;
                    if ([scrollView.documentView isKindOfClass:[NSTextView class]]) {
                        NSTextView *textView = (NSTextView *)scrollView.documentView;
                        if (textView.tag == 1011) { // Description text view
                            textView.string = description;
                            break;
                        }
                    }
                }
            }
        }
    }
    
    NSLog(@"Applied template: %@", StringFromConnectionType(type));
}

- (void)saveCustomTemplate:(NSMenuItem *)sender {
    // TODO: Implement custom template saving
    [self showAlert:@"Coming Soon" message:@"Custom template saving will be available in a future update."];
}

@end
