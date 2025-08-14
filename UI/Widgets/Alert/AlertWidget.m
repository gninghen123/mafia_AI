//
//  AlertWidget.m
//  mafia_AI
//
//  Widget per la gestione degli alert di prezzo
//  UPDATED: Usa solo DataHub e RuntimeModels
//

#import "AlertWidget.h"
#import "DataHub.h"

@interface AlertWidget ()
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation AlertWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        _currentFilter = 0; // Default to "All"
        _alerts = @[];
        _filteredAlerts = @[];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup

- (void)setupDateFormatter {
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateStyle = NSDateFormatterShortStyle;
    self.dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    // ✅ SAFETY: Aggiungi locale per evitare problemi di formattazione
    self.dateFormatter.locale = [NSLocale currentLocale];
    
    NSLog(@"✅ AlertWidget: Date formatter configured with locale: %@", self.dateFormatter.locale.localeIdentifier);
}

- (void)registerForNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(alertsUpdated:)
                                                 name:DataHubAlertTriggeredNotification
                                               object:nil];
}

- (void)setupContentView {
    [super setupContentView];
    
    NSView *container = self.contentView;
    
    // Main scroll view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSNoBorder;
    
    // Table view
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 40;
    self.tableView.intercellSpacing = NSMakeSize(0, 1);
    self.tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    self.tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    self.tableView.target = self;
    self.tableView.doubleAction = @selector(tableViewDoubleClick:);
    [self createTableColumns];
    self.scrollView.documentView = self.tableView;
    
    // Top toolbar
    NSView *toolbar = [self createToolbar];
    
    // Layout
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [container addSubview:toolbar];
    [container addSubview:self.scrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [toolbar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [toolbar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [toolbar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [toolbar.heightAnchor constraintEqualToConstant:44],
        
        [self.scrollView.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
    
    
    [self setupDateFormatter];
    [self registerForNotifications];
    [self loadAlerts];
    
}

- (NSView *)createToolbar {
    NSView *toolbar = [[NSView alloc] init];
    
    // Filter control
    self.filterControl = [[NSSegmentedControl alloc] init];
    self.filterControl.segmentCount = 3;
    [self.filterControl setLabel:@"All" forSegment:0];
    [self.filterControl setLabel:@"Active" forSegment:1];
    [self.filterControl setLabel:@"Triggered" forSegment:2];
    [self.filterControl setWidth:60 forSegment:0];
    [self.filterControl setWidth:60 forSegment:1];
    [self.filterControl setWidth:80 forSegment:2];
    self.filterControl.selectedSegment = 0;
    self.filterControl.target = self;
    self.filterControl.action = @selector(filterChanged:);
    
    // Add button
    self.addButton = [[NSButton alloc] init];
    [self.addButton setTitle:@"Add Alert"];
    self.addButton.bezelStyle = NSBezelStyleRounded;
    self.addButton.target = self;
    self.addButton.action = @selector(addAlert:);
    
    // Delete button
    self.deleteButton = [[NSButton alloc] init];
    [self.deleteButton setTitle:@"Delete"];
    self.deleteButton.bezelStyle = NSBezelStyleRounded;
    self.deleteButton.target = self;
    self.deleteButton.action = @selector(deleteAlert:);
    self.deleteButton.enabled = NO;
    
    // Status label
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.editable = NO;
    self.statusLabel.bezeled = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [self updateStatusLabel];
    
    // Layout
    self.filterControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [toolbar addSubview:self.filterControl];
    [toolbar addSubview:self.addButton];
    [toolbar addSubview:self.deleteButton];
    [toolbar addSubview:self.statusLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.filterControl.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor constant:8],
        [self.filterControl.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:toolbar.centerXAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        [self.deleteButton.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor constant:-8],
        [self.deleteButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        [self.addButton.trailingAnchor constraintEqualToAnchor:self.deleteButton.leadingAnchor constant:-8],
        [self.addButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor]
    ]];
    
    return toolbar;
}

- (void)createTableColumns {
    // Symbol column
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    [self.tableView addTableColumn:symbolColumn];
    
    // Condition column
    NSTableColumn *conditionColumn = [[NSTableColumn alloc] initWithIdentifier:@"condition"];
    conditionColumn.title = @"Condition";
    conditionColumn.width = 100;
    conditionColumn.minWidth = 80;
    [self.tableView addTableColumn:conditionColumn];
    
    // Value column
    NSTableColumn *valueColumn = [[NSTableColumn alloc] initWithIdentifier:@"value"];
    valueColumn.title = @"Trigger Value";
    valueColumn.width = 100;
    valueColumn.minWidth = 80;
    [self.tableView addTableColumn:valueColumn];
    
    // Status column
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = @"Status";
    statusColumn.width = 80;
    statusColumn.minWidth = 60;
    [self.tableView addTableColumn:statusColumn];
    
    // Created column
    NSTableColumn *createdColumn = [[NSTableColumn alloc] initWithIdentifier:@"created"];
    createdColumn.title = @"Created";
    createdColumn.width = 120;
    createdColumn.minWidth = 100;
    [self.tableView addTableColumn:createdColumn];
    
    // Notes column
    NSTableColumn *notesColumn = [[NSTableColumn alloc] initWithIdentifier:@"notes"];
    notesColumn.title = @"Notes";
    notesColumn.width = 150;
    notesColumn.minWidth = 100;
    [self.tableView addTableColumn:notesColumn];
}

#pragma mark - Data Loading

- (void)loadAlerts {
    // Load from DataHub using RuntimeModels
    self.alerts = [[DataHub shared] getAllAlertModels];
    [self applyFilter];
}

- (void)applyFilter {
    NSPredicate *filterPredicate;
    
    switch (self.currentFilter) {
        case 1: // Active
            filterPredicate = [NSPredicate predicateWithFormat:@"isActive == YES AND isTriggered == NO"];
            break;
        case 2: // Triggered
            filterPredicate = [NSPredicate predicateWithFormat:@"isTriggered == YES"];
            break;
        default: // All
            filterPredicate = nil;
            break;
    }
    
    if (filterPredicate) {
        self.filteredAlerts = [self.alerts filteredArrayUsingPredicate:filterPredicate];
    } else {
        self.filteredAlerts = [self.alerts copy];
    }
    
    [self.tableView reloadData];
    [self updateStatusLabel];
    [self updateButtonStates];
}

- (void)updateStatusLabel {
    NSInteger total = self.alerts.count;
    NSInteger active = [[self.alerts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isActive == YES AND isTriggered == NO"]] count];
    NSInteger triggered = [[self.alerts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isTriggered == YES"]] count];
    
    self.statusLabel.stringValue = [NSString stringWithFormat:@"%ld total, %ld active, %ld triggered", total, active, triggered];
}

- (void)updateButtonStates {
    NSInteger selectedRow = self.tableView.selectedRow;
    self.deleteButton.enabled = (selectedRow >= 0);
}

#pragma mark - Actions

- (void)filterChanged:(id)sender {
    self.currentFilter = self.filterControl.selectedSegment;
    [self applyFilter];
}

- (void)addAlert:(id)sender {
    self.alertEditController = [[AlertEditController alloc] initWithAlert:nil];
    if (!self.alertEditController) {
            NSLog(@"❌ Failed to create AlertEditController!");
            return;
        }
        
        NSLog(@"✅ AlertEditController created: %@", self.alertEditController);
        
        // ✅ COMPLETION HANDLER con cleanup
        __weak typeof(self) weakSelf = self;
        self.alertEditController.completionHandler = ^(AlertModel *alert, BOOL saved) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            NSLog(@"📝 AlertEditController completion - saved: %@", saved ? @"YES" : @"NO");
            
            if (saved && alert) {
                [strongSelf loadAlerts];
            }
            
            // ✅ PULISCI REFERENCE SOLO DOPO COMPLETION
            strongSelf.alertEditController = nil;
            NSLog(@"🧹 AlertEditController reference cleared");
        };
        
        // ✅ USA PATTERN ChartPreferencesWindow INVECE DI SHEET
        [self.alertEditController showAlertEditWindow];
        
        NSLog(@"🪟 AlertEditController shown, reference maintained: %@", self.alertEditController);
    }

- (void)deleteAlert:(id)sender {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.filteredAlerts.count) return;
    
    AlertModel *alert = self.filteredAlerts[selectedRow];
    
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"Delete Alert";
    confirmAlert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the alert for %@?", alert.symbol];
    [confirmAlert addButtonWithTitle:@"Delete"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    confirmAlert.alertStyle = NSAlertStyleWarning;
    
    [confirmAlert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [[DataHub shared] deleteAlertModel:alert];
            [self loadAlerts];
        }
    }];
}


- (void)tableViewDoubleClick:(id)sender {
    NSInteger clickedRow = self.tableView.clickedRow;
    if (clickedRow >= 0) {
        [self tableView:self.tableView didDoubleClickAtRow:clickedRow];
    }
}


#pragma mark - Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredAlerts.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredAlerts.count) return nil;
    
    AlertModel *alert = self.filteredAlerts[row];
    NSString *identifier = tableColumn.identifier;
    
    // ✅ SAFETY CHECK: Alert non deve essere nil
    if (!alert) {
        NSLog(@"⚠️ AlertWidget: Alert at row %ld is nil!", (long)row);
        return nil;
    }
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.font = [NSFont systemFontOfSize:12];
        
        cellView.textField = textField;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:textField];
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-4],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // ✅ SAFETY CHECK: TextField non deve essere nil
    if (!cellView.textField) {
        NSLog(@"⚠️ AlertWidget: cellView.textField is nil for identifier: %@", identifier);
        return cellView;
    }
    
    // Set cell content based on column - CON PROTECTION DA NIL
    if ([identifier isEqualToString:@"symbol"]) {
        NSString *symbolValue = alert.symbol ?: @"--";
        cellView.textField.stringValue = symbolValue;
        cellView.textField.font = [NSFont boldSystemFontOfSize:12];
        
    } else if ([identifier isEqualToString:@"condition"]) {
        NSString *conditionText = @"--";
        if (alert.conditionString) {
            if ([alert.conditionString isEqualToString:@"above"]) {
                conditionText = @"Above";
            } else if ([alert.conditionString isEqualToString:@"below"]) {
                conditionText = @"Below";
            } else if ([alert.conditionString isEqualToString:@"crosses_above"]) {
                conditionText = @"Crosses Above";
            } else if ([alert.conditionString isEqualToString:@"crosses_below"]) {
                conditionText = @"Crosses Below";
            } else {
                conditionText = alert.conditionString; // Fallback
            }
        }
        cellView.textField.stringValue = conditionText;
        
    } else if ([identifier isEqualToString:@"value"]) {
        // ✅ SAFE: Usa formato semplice invece di currency formatter
        NSString *valueText = [NSString stringWithFormat:@"%.2f", alert.triggerValue];
        cellView.textField.stringValue = valueText;
        cellView.textField.alignment = NSTextAlignmentRight;
        
    } else if ([identifier isEqualToString:@"status"]) {
        // ✅ SAFE: Status string sicuro
        NSString *statusText = @"Unknown";
        if (alert.isTriggered) {
            statusText = @"Triggered";
            cellView.textField.textColor = [NSColor systemRedColor];
        } else if (alert.isActive) {
            statusText = @"Active";
            cellView.textField.textColor = [NSColor systemGreenColor];
        } else {
            statusText = @"Inactive";
            cellView.textField.textColor = [NSColor secondaryLabelColor];
        }
        cellView.textField.stringValue = statusText;
        
    } else if ([identifier isEqualToString:@"created"]) {
        NSString *createdText = @"--";
        if (alert.creationDate && self.dateFormatter) {
            @try {
                createdText = [self.dateFormatter stringFromDate:alert.creationDate];
                if (!createdText) createdText = @"--";
            } @catch (NSException *exception) {
                NSLog(@"⚠️ Date formatting error: %@", exception.reason);
                createdText = @"--";
            }
        }
        cellView.textField.stringValue = createdText;
        cellView.textField.font = [NSFont systemFontOfSize:11];
        cellView.textField.textColor = [NSColor secondaryLabelColor];
        
    } else if ([identifier isEqualToString:@"notes"]) {
        NSString *notesText = alert.notes ?: @"";
        cellView.textField.stringValue = notesText;
        cellView.textField.font = [NSFont systemFontOfSize:11];
        cellView.textField.textColor = [NSColor tertiaryLabelColor];
        
    } else {
        // ✅ FALLBACK per colonne sconosciute
        cellView.textField.stringValue = @"--";
        NSLog(@"⚠️ AlertWidget: Unknown column identifier: %@", identifier);
    }
    
    return cellView;
}
#pragma mark - Table View Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updateButtonStates];
}

- (void)tableView:(NSTableView *)tableView didDoubleClickAtRow:(NSInteger)row {
    if (row >= 0 && row < self.filteredAlerts.count) {
        AlertModel *alert = self.filteredAlerts[row];
        
        NSLog(@"✏️ Double-click edit alert: %@", alert.symbol);
        
        // ✅ MANTIENI STRONG REFERENCE
        self.alertEditController = [[AlertEditController alloc] initWithAlert:alert];
        
        __weak typeof(self) weakSelf = self;
        self.alertEditController.completionHandler = ^(AlertModel *editedAlert, BOOL saved) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (saved) {
                [strongSelf loadAlerts];
            }
            
            // ✅ PULISCI REFERENCE
            strongSelf.alertEditController = nil;
        };
        
        [self.alertEditController showAlertEditWindow];
    }
}


#pragma mark - Notifications

- (void)alertsUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadAlerts];
    });
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    state[@"currentFilter"] = @(self.currentFilter);
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    if (state[@"currentFilter"]) {
        self.currentFilter = [state[@"currentFilter"] integerValue];
        self.filterControl.selectedSegment = self.currentFilter;
        [self applyFilter];
    }
}

@end
