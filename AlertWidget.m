//
//  AlertWidget.m
//  TradingApp
//

#import "AlertWidget.h"
#import "AlertEditWindowController.h"
#import "DataManager.h"

@interface AlertWidget ()

@property (nonatomic, strong) NSTableColumn *symbolColumn;
@property (nonatomic, strong) NSTableColumn *typeColumn;
@property (nonatomic, strong) NSTableColumn *priceColumn;
@property (nonatomic, strong) NSTableColumn *statusColumn;
@property (nonatomic, strong) NSTableColumn *dateColumn;

@end

@implementation AlertWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Alert";
        _displayedAlerts = [NSMutableArray array];
        
        // Registra come delegate dell'AlertManager
        [[AlertManager sharedManager] setDelegate:self];
        
        // Osserva notifiche
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(alertsUpdated:)
                                                     name:kAlertsUpdatedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupContentView {
    [super setupContentView];
    
    // Toolbar
    self.toolbarView = [[NSView alloc] initWithFrame:NSMakeRect(0, self.contentView.frame.size.height - 40,
                                                                self.contentView.frame.size.width, 40)];
    self.toolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.contentView addSubview:self.toolbarView];
    
    // Search field
    self.searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(10, 5, 150, 30)];
    self.searchField.placeholderString = @"Cerca simbolo...";
    self.searchField.delegate = self;
    self.searchField.target = self;
    self.searchField.action = @selector(searchFieldDidChange:);
    [self.toolbarView addSubview:self.searchField];
    
    // Add button
    self.addButton = [[NSButton alloc] initWithFrame:NSMakeRect(170, 5, 30, 30)];
    self.addButton.bezelStyle = NSBezelStyleRegularSquare;
    self.addButton.title = @"+";
    self.addButton.target = self;
    self.addButton.action = @selector(addNewAlert);
    self.addButton.toolTip = @"Aggiungi nuovo alert";
    [self.toolbarView addSubview:self.addButton];
    
    // Edit button
    self.editButton = [[NSButton alloc] initWithFrame:NSMakeRect(205, 5, 60, 30)];
    self.editButton.bezelStyle = NSBezelStyleRegularSquare;
    self.editButton.title = @"Modifica";
    self.editButton.target = self;
    self.editButton.action = @selector(editSelectedAlert);
    self.editButton.enabled = NO;
    [self.toolbarView addSubview:self.editButton];
    
    // Delete button
    self.deleteButton = [[NSButton alloc] initWithFrame:NSMakeRect(270, 5, 60, 30)];
    self.deleteButton.bezelStyle = NSBezelStyleRegularSquare;
    self.deleteButton.title = @"Elimina";
    self.deleteButton.target = self;
    self.deleteButton.action = @selector(deleteSelectedAlert);
    self.deleteButton.enabled = NO;
    [self.toolbarView addSubview:self.deleteButton];
    
    // Clear triggered button
    self.clearTriggeredButton = [[NSButton alloc] initWithFrame:NSMakeRect(335, 5, 100, 30)];
    self.clearTriggeredButton.bezelStyle = NSBezelStyleRegularSquare;
    self.clearTriggeredButton.title = @"Pulisci Scattati";
    self.clearTriggeredButton.target = self;
    self.clearTriggeredButton.action = @selector(clearTriggeredAlerts);
    [self.toolbarView addSubview:self.clearTriggeredButton];
    
    // Table view
    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0,
                                                                     self.contentView.frame.size.width,
                                                                     self.contentView.frame.size.height - 40)];
    self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.borderType = NSNoBorder;
    
    self.tableView = [[NSTableView alloc] initWithFrame:self.scrollView.bounds];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 25;
    self.tableView.intercellSpacing = NSMakeSize(0, 0);
    self.tableView.headerView.wantsLayer = YES;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.doubleAction = @selector(editSelectedAlert);
    
    // Colonne
    self.symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    self.symbolColumn.title = @"Simbolo";
    self.symbolColumn.width = 80;
    self.symbolColumn.minWidth = 60;
    [self.tableView addTableColumn:self.symbolColumn];
    
    self.typeColumn = [[NSTableColumn alloc] initWithIdentifier:@"type"];
    self.typeColumn.title = @"Tipo";
    self.typeColumn.width = 60;
    self.typeColumn.minWidth = 50;
    [self.tableView addTableColumn:self.typeColumn];
    
    self.priceColumn = [[NSTableColumn alloc] initWithIdentifier:@"price"];
    self.priceColumn.title = @"Prezzo Target";
    self.priceColumn.width = 100;
    self.priceColumn.minWidth = 80;
    [self.tableView addTableColumn:self.priceColumn];
    
    self.statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    self.statusColumn.title = @"Stato";
    self.statusColumn.width = 80;
    self.statusColumn.minWidth = 60;
    [self.tableView addTableColumn:self.statusColumn];
    
    self.dateColumn = [[NSTableColumn alloc] initWithIdentifier:@"date"];
    self.dateColumn.title = @"Data";
    self.dateColumn.width = 120;
    self.dateColumn.minWidth = 100;
    [self.tableView addTableColumn:self.dateColumn];
    
    self.scrollView.documentView = self.tableView;
    [self.contentView addSubview:self.scrollView];
    
    // Carica i dati iniziali
    [self refreshData];
}

#pragma mark - Data Management

- (void)refreshData {
    [self.displayedAlerts removeAllObjects];
    
    NSArray *allAlerts = [[AlertManager sharedManager] allAlerts];
    
    // Applica filtro se presente
    if (self.searchFilter && self.searchFilter.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"symbol CONTAINS[cd] %@", self.searchFilter];
        allAlerts = [allAlerts filteredArrayUsingPredicate:predicate];
    }
    
    // Ordina per data di creazione (più recenti prima)
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO];
    allAlerts = [allAlerts sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    [self.displayedAlerts addObjectsFromArray:allAlerts];
    [self.tableView reloadData];
    
    // Aggiorna stato pulsanti
    [self updateButtonStates];
}

- (void)updateButtonStates {
    NSInteger selectedRow = self.tableView.selectedRow;
    BOOL hasSelection = (selectedRow >= 0 && selectedRow < self.displayedAlerts.count);
    
    self.editButton.enabled = hasSelection;
    self.deleteButton.enabled = hasSelection;
    
    // Abilita "Pulisci Scattati" solo se ci sono alert scattati
    NSArray *triggeredAlerts = [[AlertManager sharedManager] triggeredAlerts];
    self.clearTriggeredButton.enabled = (triggeredAlerts.count > 0);
}

#pragma mark - Actions

- (void)searchFieldDidChange:(id)sender {
    self.searchFilter = self.searchField.stringValue;
    [self refreshData];
}

- (void)addNewAlert {
    AlertEntry *newAlert = [[AlertEntry alloc] init];
    
    // Precompila con il simbolo selezionato se disponibile
    // Qui potresti ottenere il simbolo dal widget attivo o dal DataManager
    
    [self showAlertEditSheet:newAlert];
}

- (void)editSelectedAlert {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.displayedAlerts.count) {
        AlertEntry *alert = self.displayedAlerts[selectedRow];
        [self showAlertEditSheet:[alert copy]];
    }
}

- (void)deleteSelectedAlert {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.displayedAlerts.count) {
        AlertEntry *alert = self.displayedAlerts[selectedRow];
        
        NSAlert *confirmAlert = [[NSAlert alloc] init];
        confirmAlert.messageText = @"Elimina Alert";
        confirmAlert.informativeText = [NSString stringWithFormat:@"Sei sicuro di voler eliminare l'alert per %@?", alert.symbol];
        [confirmAlert addButtonWithTitle:@"Elimina"];
        [confirmAlert addButtonWithTitle:@"Annulla"];
        
        if ([confirmAlert runModal] == NSAlertFirstButtonReturn) {
            [[AlertManager sharedManager] removeAlert:alert];
            [self refreshData];
        }
    }
}

- (void)clearTriggeredAlerts {
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"Pulisci Alert Scattati";
    confirmAlert.informativeText = @"Sei sicuro di voler eliminare tutti gli alert scattati?";
    [confirmAlert addButtonWithTitle:@"Elimina"];
    [confirmAlert addButtonWithTitle:@"Annulla"];
    
    if ([confirmAlert runModal] == NSAlertFirstButtonReturn) {
        [[AlertManager sharedManager] removeTriggeredAlerts];
        [self refreshData];
    }
}

- (void)showAlertEditSheet:(AlertEntry *)alert {
    AlertEditWindowController *editController = [[AlertEditWindowController alloc] initWithAlert:alert];
    
    [self.view.window beginSheet:editController.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSModalResponseOK) {
            AlertEntry *editedAlert = editController.editedAlert;
            
            if (alert.alertID) {
                // Modifica alert esistente
                [[AlertManager sharedManager] updateAlert:editedAlert];
            } else {
                // Nuovo alert
                [[AlertManager sharedManager] addAlert:editedAlert];
            }
            
            [self refreshData];
        }
    }];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.displayedAlerts.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.displayedAlerts.count) return nil;
    
    AlertEntry *alert = self.displayedAlerts[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"symbol"]) {
        return alert.symbol;
    } else if ([identifier isEqualToString:@"type"]) {
        return alert.alertTypeString;
    } else if ([identifier isEqualToString:@"price"]) {
        return [NSString stringWithFormat:@"%.2f", alert.targetPrice];
    } else if ([identifier isEqualToString:@"status"]) {
        return alert.statusString;
    } else if ([identifier isEqualToString:@"date"]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        
        if (alert.status == AlertStatusTriggered && alert.triggerDate) {
            return [formatter stringFromDate:alert.triggerDate];
        } else {
            return [formatter stringFromDate:alert.creationDate];
        }
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (void)tableView:(NSTableView *)tableView willDisplayCell:(NSTextFieldCell *)cell
 forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.displayedAlerts.count) return;
    
    AlertEntry *alert = self.displayedAlerts[row];
    
    // Colora di rosso gli alert scattati
    if (alert.status == AlertStatusTriggered) {
        cell.textColor = [NSColor redColor];
        cell.font = [NSFont boldSystemFontOfSize:cell.font.pointSize];
    } else if (alert.status == AlertStatusDisabled) {
        cell.textColor = [NSColor grayColor];
    } else {
        cell.textColor = [NSColor labelColor];
        cell.font = [NSFont systemFontOfSize:cell.font.pointSize];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updateButtonStates];
}

#pragma mark - AlertManagerDelegate

- (void)alertManager:(id)manager didTriggerAlert:(AlertEntry *)alert {
    // Refresh per mostrare l'alert scattato in rosso
    [self refreshData];
    
    // Opzionale: seleziona l'alert scattato nella tabella
    NSUInteger index = [self.displayedAlerts indexOfObjectPassingTest:^BOOL(AlertEntry *obj, NSUInteger idx, BOOL *stop) {
        return [obj.alertID isEqualToString:alert.alertID];
    }];
    
    if (index != NSNotFound) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
        [self.tableView scrollRowToVisible:index];
    }
}

- (void)alertManagerDidUpdateAlerts:(id)manager {
    [self refreshData];
}

#pragma mark - Notifications

- (void)alertsUpdated:(NSNotification *)notification {
    [self refreshData];
}

@end
