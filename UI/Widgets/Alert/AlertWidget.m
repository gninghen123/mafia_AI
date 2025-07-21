//
//  AlertWidget.m
//  mafia_AI
//

#import "AlertWidget.h"
#import "AlertEditController.h"
#import "DataHub.h"
#import "Alert+CoreDataClass.h"

@interface AlertWidget ()
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation AlertWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        _currentFilter = 0; // Default to "All"
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupDateFormatter];
    [self registerForNotifications];
    [self loadAlerts];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup

- (void)setupContentView {
    [super setupContentView];
    
    // Usa il contentView fornito da BaseWidget
    NSView *container = self.contentView;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Main container
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
    
    // Create columns
    [self createTableColumns];
    
    self.scrollView.documentView = self.tableView;
    
    // Top toolbar
    NSView *toolbar = [[NSView alloc] init];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Filter control
    self.filterControl = [[NSSegmentedControl alloc] init];
    self.filterControl.segmentCount = 3;
    [self.filterControl setLabel:@"All" forSegment:0];
    [self.filterControl setLabel:@"Active" forSegment:1];
    [self.filterControl setLabel:@"Triggered" forSegment:2];
    self.filterControl.selectedSegment = 0;
    self.filterControl.target = self;
    self.filterControl.action = @selector(filterChanged:);
    self.filterControl.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add button
    self.addButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameAddTemplate]
                                        target:self
                                        action:@selector(addAlert:)];
    self.addButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Delete button
    self.deleteButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameRemoveTemplate]
                                           target:self
                                           action:@selector(deleteAlert:)];
    self.deleteButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.deleteButton.enabled = NO;
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Status label
    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add to toolbar
    [toolbar addSubview:self.filterControl];
    [toolbar addSubview:self.addButton];
    [toolbar addSubview:self.deleteButton];
    [toolbar addSubview:self.statusLabel];
    
    // Add to main view
    [container addSubview:toolbar];
    [container addSubview:self.scrollView];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar
        [toolbar.topAnchor constraintEqualToAnchor:container.topAnchor constant:5],
        [toolbar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:5],
        [toolbar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-5],
        [toolbar.heightAnchor constraintEqualToConstant:30],
        
        // Filter control
        [self.filterControl.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor],
        [self.filterControl.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        // Add button
        [self.addButton.leadingAnchor constraintEqualToAnchor:self.filterControl.trailingAnchor constant:10],
        [self.addButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.addButton.widthAnchor constraintEqualToConstant:30],
        
        // Delete button
        [self.deleteButton.leadingAnchor constraintEqualToAnchor:self.addButton.trailingAnchor constant:5],
        [self.deleteButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.deleteButton.widthAnchor constraintEqualToConstant:30],
        
        // Status label
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        
        // Scroll view
        [self.scrollView.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor constant:5],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
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
    conditionColumn.width = 120;
    conditionColumn.minWidth = 100;
    [self.tableView addTableColumn:conditionColumn];
    
    // Status column
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = @"Status";
    statusColumn.width = 80;
    statusColumn.minWidth = 60;
    [self.tableView addTableColumn:statusColumn];
    
    // Date column
    NSTableColumn *dateColumn = [[NSTableColumn alloc] initWithIdentifier:@"date"];
    dateColumn.title = @"Created";
    dateColumn.width = 100;
    dateColumn.minWidth = 80;
    [self.tableView addTableColumn:dateColumn];
}

- (void)setupDateFormatter {
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateStyle = NSDateFormatterShortStyle;
    self.dateFormatter.timeStyle = NSDateFormatterNoStyle;
}

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(alertsUpdated:)
               name:DataHubAlertTriggeredNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(symbolDataUpdated:)
               name:DataHubSymbolsUpdatedNotification
             object:nil];
}

#pragma mark - Data Management

- (void)loadAlerts {
    DataHub *hub = [DataHub shared];
    
    switch (self.currentFilter) {
        case 0: // All
            self.alerts = [hub getAllAlerts];
            break;
        case 1: // Active
            self.alerts = [hub getActiveAlerts];
            break;
        case 2: // Triggered
            self.alerts = [hub filterAlerts:@{@"isTriggered": @YES}];
            break;
    }
    
    self.filteredAlerts = self.alerts;
    [self.tableView reloadData];
    [self updateStatusLabel];
}

- (void)updateStatusLabel {
    NSInteger activeCount = 0;
    for (Alert *alert in self.alerts) {
        if (alert.isActive) activeCount++;
    }
    
    self.statusLabel.stringValue = [NSString stringWithFormat:@"%ld alerts (%ld active)",
                                    self.alerts.count, activeCount];
}

#pragma mark - Actions

- (void)filterChanged:(id)sender {
    self.currentFilter = self.filterControl.selectedSegment;
    [self loadAlerts];
}

- (void)addAlert:(id)sender {
    AlertEditController *editController = [[AlertEditController alloc] initWithAlert:nil];
    editController.completionHandler = ^(Alert *alert, BOOL saved) {
        if (saved) {
            [self loadAlerts];
        }
    };
    
    [self.view.window.windowController.window beginSheet:editController.window
                                  completionHandler:^(NSModalResponse returnCode) {
        // Sheet closed
    }];
}

- (void)deleteAlert:(id)sender {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.filteredAlerts.count) {
        Alert *alert = self.filteredAlerts[selectedRow];
        
        NSAlert *confirmation = [[NSAlert alloc] init];
        confirmation.messageText = @"Delete Alert?";
        confirmation.informativeText = [NSString stringWithFormat:@"Delete alert for %@?", alert.symbol];
        [confirmation addButtonWithTitle:@"Delete"];
        [confirmation addButtonWithTitle:@"Cancel"];
        
        if ([confirmation runModal] == NSAlertFirstButtonReturn) {
            [[DataHub shared] deleteAlert:alert];
            [self loadAlerts];
        }
    }
}

#pragma mark - Notifications

- (void)alertsUpdated:(NSNotification *)notification {
    [self loadAlerts];
}

- (void)symbolDataUpdated:(NSNotification *)notification {
    // Refresh table to show updated prices
    [self.tableView reloadData];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredAlerts.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredAlerts.count) return nil;
    
    Alert *alert = self.filteredAlerts[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"symbol"]) {
        return alert.symbol;
    } else if ([identifier isEqualToString:@"condition"]) {
        return [NSString stringWithFormat:@"%@ %.2f", alert.conditionString, alert.triggerValue];
    } else if ([identifier isEqualToString:@"status"]) {
        if (alert.isTriggered) {
            return @"Triggered";
        } else if (alert.isActive) {
            return @"Active";
        } else {
            return @"Inactive";
        }
    } else if ([identifier isEqualToString:@"date"]) {
        return [self.dateFormatter stringFromDate:alert.creationDate];
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.filteredAlerts.count) return nil;
    
    Alert *alert = self.filteredAlerts[row];
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.font = [NSFont systemFontOfSize:12];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:5],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-5],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Set text
    cellView.textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row] ?: @"";
    
    // Color coding for status
    if ([tableColumn.identifier isEqualToString:@"status"]) {
        if (alert.isTriggered) {
            cellView.textField.textColor = [NSColor systemGreenColor];
        } else if (alert.isActive) {
            cellView.textField.textColor = [NSColor systemBlueColor];
        } else {
            cellView.textField.textColor = [NSColor secondaryLabelColor];
        }
    } else {
        cellView.textField.textColor = [NSColor labelColor];
    }
    
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    self.deleteButton.enabled = (self.tableView.selectedRow >= 0);
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return YES;
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
    // Implement sorting if needed
}

#pragma mark - Widget Overrides

- (void)updateData {
    [self loadAlerts];
}

- (NSDictionary *)serializeState {
    return @{
        @"widgetType": @"Alert",
        @"widgetID": self.widgetID ?: @"",
        @"currentFilter": @(self.currentFilter)
    };
}

- (void)restoreState:(NSDictionary *)state {
    if (state[@"currentFilter"]) {
        self.currentFilter = [state[@"currentFilter"] integerValue];
        self.filterControl.selectedSegment = self.currentFilter;
        [self loadAlerts];
    }
}

@end
