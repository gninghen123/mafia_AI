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
    
    // Toolbar con Auto Layout
    self.toolbarView = [[NSView alloc] init];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toolbarView.wantsLayer = YES;
    [self.contentView addSubview:self.toolbarView];
    
    // Search field
    self.searchField = [[NSSearchField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = @"Cerca simbolo...";
    self.searchField.delegate = self;
    self.searchField.target = self;
    self.searchField.action = @selector(searchFieldDidChange:);
    [self.toolbarView addSubview:self.searchField];
    
    // Add button
    self.addButton = [[NSButton alloc] init];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addButton.bezelStyle = NSBezelStyleRegularSquare;
    self.addButton.title = @"+";
    self.addButton.target = self;
    self.addButton.action = @selector(addNewAlert);
    self.addButton.toolTip = @"Aggiungi nuovo alert";
    
    // Debug styling
    self.addButton.wantsLayer = YES;
    self.addButton.layer.backgroundColor = [NSColor blueColor].CGColor;
    self.addButton.layer.borderWidth = 2.0;
    self.addButton.layer.borderColor = [NSColor blackColor].CGColor;
    
    [self.toolbarView addSubview:self.addButton];
    
    // Edit button
    self.editButton = [[NSButton alloc] init];
    self.editButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.editButton.bezelStyle = NSBezelStyleRegularSquare;
    self.editButton.title = @"Modifica";
    self.editButton.target = self;
    self.editButton.action = @selector(editSelectedAlert);
    self.editButton.enabled = NO;
    [self.toolbarView addSubview:self.editButton];
    
    // Delete button
    self.deleteButton = [[NSButton alloc] init];
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteButton.bezelStyle = NSBezelStyleRegularSquare;
    self.deleteButton.title = @"Elimina";
    self.deleteButton.target = self;
    self.deleteButton.action = @selector(deleteSelectedAlert);
    self.deleteButton.enabled = NO;
    [self.toolbarView addSubview:self.deleteButton];
    
    // Clear triggered button
    self.clearTriggeredButton = [[NSButton alloc] init];
    self.clearTriggeredButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.clearTriggeredButton.bezelStyle = NSBezelStyleRegularSquare;
    self.clearTriggeredButton.title = @"Pulisci Scattati";
    self.clearTriggeredButton.target = self;
    self.clearTriggeredButton.action = @selector(clearTriggeredAlerts);
    [self.toolbarView addSubview:self.clearTriggeredButton];
    
    // Table view
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.wantsLayer = YES;
    self.scrollView.layer.backgroundColor = [NSColor whiteColor].CGColor;
    
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self setupTableColumns];
    
    self.scrollView.documentView = self.tableView;
    [self.contentView addSubview:self.scrollView];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Toolbar constraints - FISSA in alto
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:40],
        
        // Search field constraints
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:10],
        [self.searchField.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.searchField.widthAnchor constraintEqualToConstant:150],
        [self.searchField.heightAnchor constraintEqualToConstant:30],
        
        // Add button constraints
        [self.addButton.leadingAnchor constraintEqualToAnchor:self.searchField.trailingAnchor constant:10],
        [self.addButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.addButton.widthAnchor constraintEqualToConstant:30],
        [self.addButton.heightAnchor constraintEqualToConstant:30],
        
        // Edit button constraints
        [self.editButton.leadingAnchor constraintEqualToAnchor:self.addButton.trailingAnchor constant:5],
        [self.editButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.editButton.widthAnchor constraintEqualToConstant:60],
        [self.editButton.heightAnchor constraintEqualToConstant:30],
        
        // Delete button constraints
        [self.deleteButton.leadingAnchor constraintEqualToAnchor:self.editButton.trailingAnchor constant:5],
        [self.deleteButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.deleteButton.widthAnchor constraintEqualToConstant:60],
        [self.deleteButton.heightAnchor constraintEqualToConstant:30],
        
        // Clear triggered button constraints
        [self.clearTriggeredButton.leadingAnchor constraintEqualToAnchor:self.deleteButton.trailingAnchor constant:5],
        [self.clearTriggeredButton.centerYAnchor constraintEqualToAnchor:self.toolbarView.centerYAnchor],
        [self.clearTriggeredButton.widthAnchor constraintEqualToConstant:100],
        [self.clearTriggeredButton.heightAnchor constraintEqualToConstant:30],
        
        // ScrollView constraints - sotto la toolbar
        [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    // Carica dati iniziali
    [self refreshData];
}

- (void)setupTableColumns {
    // Rimuovi eventuali colonne esistenti
    while (self.tableView.tableColumns.count > 0) {
        [self.tableView removeTableColumn:self.tableView.tableColumns.lastObject];
    }
    
    // Colonna Simbolo
    self.symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    self.symbolColumn.title = @"Simbolo";
    self.symbolColumn.width = 80;
    self.symbolColumn.minWidth = 60;
    self.symbolColumn.maxWidth = 120;
    [self.tableView addTableColumn:self.symbolColumn];
    
    // Colonna Tipo
    self.typeColumn = [[NSTableColumn alloc] initWithIdentifier:@"type"];
    self.typeColumn.title = @"Tipo";
    self.typeColumn.width = 80;
    self.typeColumn.minWidth = 60;
    self.typeColumn.maxWidth = 100;
    [self.tableView addTableColumn:self.typeColumn];
    
    // Colonna Prezzo
    self.priceColumn = [[NSTableColumn alloc] initWithIdentifier:@"price"];
    self.priceColumn.title = @"Prezzo Target";
    self.priceColumn.width = 100;
    self.priceColumn.minWidth = 80;
    self.priceColumn.maxWidth = 150;
    [self.tableView addTableColumn:self.priceColumn];
    
    // Colonna Status
    self.statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    self.statusColumn.title = @"Stato";
    self.statusColumn.width = 80;
    self.statusColumn.minWidth = 60;
    self.statusColumn.maxWidth = 120;
    [self.tableView addTableColumn:self.statusColumn];
    
    // Colonna Data
    self.dateColumn = [[NSTableColumn alloc] initWithIdentifier:@"date"];
    self.dateColumn.title = @"Data";
    self.dateColumn.width = 120;
    self.dateColumn.minWidth = 100;
    self.dateColumn.maxWidth = 180;
    [self.tableView addTableColumn:self.dateColumn];
    
    // Configurazioni aggiuntive della tabella
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    
    // Abilita sorting sulle colonne
    for (NSTableColumn *column in self.tableView.tableColumns) {
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:column.identifier ascending:YES];
        column.sortDescriptorPrototype = sortDescriptor;
    }
}


#pragma mark - Data Management

- (void)refreshData {
    NSLog(@"refreshData chiamato");
    
    [self.displayedAlerts removeAllObjects];
    
    NSArray *allAlerts = [[AlertManager sharedManager] allAlerts];
    NSLog(@"AlertManager ha %ld alert totali", (long)allAlerts.count);
    
    // Filtra per search se presente
    if (self.searchFilter.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"symbol CONTAINS[cd] %@", self.searchFilter];
        allAlerts = [allAlerts filteredArrayUsingPredicate:predicate];
        NSLog(@"Dopo filtro search: %ld alert", (long)allAlerts.count);
    }
    
    // Ordina per data di creazione (più recenti prima)
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO];
    allAlerts = [allAlerts sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    [self.displayedAlerts addObjectsFromArray:allAlerts];
    NSLog(@"displayedAlerts ora ha %ld elementi", (long)self.displayedAlerts.count);
    
    [self.tableView reloadData];
    NSLog(@"tableView reloadData chiamato");
    
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
    // FIXED: Pass nil to indicate this is a new alert
    NSLog(@"addNewAlert chiamato - passando nil come alert");
    [self showAlertEditSheet:nil];
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
    NSLog(@"showAlertEditSheet chiamato con alert: %@", alert ? alert.alertID : @"NIL (NUOVO)");
    
    AlertEditWindowController *editController = [[AlertEditWindowController alloc] initWithAlert:alert];
    
    [self.view.window beginSheet:editController.window completionHandler:^(NSModalResponse returnCode) {
        NSLog(@"Sheet completata con returnCode: %ld", (long)returnCode);
        
        if (returnCode == NSModalResponseOK) {
            AlertEntry *editedAlert = editController.editedAlert;
            NSLog(@"Alert editato: ID=%@, Symbol=%@, Price=%.5f",
                  editedAlert.alertID, editedAlert.symbol, editedAlert.targetPrice);
            
            // FIXED: Check if the ORIGINAL alert was nil (not the editedAlert)
            if (alert == nil) {
                NSLog(@"Aggiungendo nuovo alert (original era nil)");
                [[AlertManager sharedManager] addAlert:editedAlert];
            } else {
                NSLog(@"Aggiornando alert esistente con ID: %@", alert.alertID);
                [[AlertManager sharedManager] updateAlert:editedAlert];
            }
            
            NSLog(@"Chiamando refreshData");
            [self refreshData];
            
            // Debug: verifica il numero di alert nella tabella
            NSLog(@"Numero di alert nella tabella dopo refresh: %ld", (long)self.displayedAlerts.count);
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

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    NSString *action = update[@"action"];
 //todo
    if ([action isEqualToString:@"setSymbols"]) {
        NSArray *symbols = update[@"symbols"];
        // AlertWidget può gestire tutti i simboli
        for (NSString *symbol in symbols) {
      //      [self addNewAlert:symbol];
        }
    }
}
@end
