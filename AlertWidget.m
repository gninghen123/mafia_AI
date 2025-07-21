//
//  AlertWidget.m
//  TradingApp
//
//  VERSIONE PULITA - Integrazione diretta con DataHub
//

#import "AlertWidget.h"
#import "AlertEditWindowController.h"
#import "SymbolDataHub.h"
#import "SymbolDataModels.h"

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
        self.widgetType = @"Alerts";
        _displayedAlerts = [NSMutableArray array];
        
        // RIMUOVI: [[AlertManager sharedManager] setDelegate:self];
        
        // AGGIUNGI osservatori DataHub:
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(dataHubUpdated:)
                                                     name:kSymbolDataUpdatedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(alertTriggered:)
                                                     name:kAlertTriggeredNotification
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
#pragma mark - Data Management

- (void)refreshData {
    // Carica alerts direttamente dal DataHub
    NSArray<AlertData *> *alerts = [[SymbolDataHub sharedHub] allActiveAlerts];
    
    // Converti in AlertEntry per compatibilità con UI
    NSMutableArray *entries = [NSMutableArray array];
    for (AlertData *alert in alerts) {
        AlertEntry *entry = [AlertEntry fromAlertData:alert];
        if (entry) {
            // Applica filtro se presente
            if (self.searchFilter.length > 0) {
                if ([entry.symbol.lowercaseString containsString:self.searchFilter.lowercaseString]) {
                    [entries addObject:entry];
                }
            } else {
                [entries addObject:entry];
            }
        }
    }
    
    self.displayedAlerts = entries;
    [self.tableView reloadData];
    [self updateButtonStates];
}
#pragma mark - Actions

- (void)addNewAlert {
    AlertEditWindowController *editController = [[AlertEditWindowController alloc] init];
    editController.isNewAlert = YES;
    
    [self.view.window beginSheet:editController.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSModalResponseOK) {
            AlertEntry *newAlert = editController.alert;
            
            // Aggiungi al DataHub
            NSDictionary *conditions = @{
                @"price": @(newAlert.targetPrice),
                @"comparison": newAlert.alertType == AlertTypePriceAbove ? @"above" : @"below"
            };
            
            AlertData *dataHubAlert = [[SymbolDataHub sharedHub] addAlertForSymbol:newAlert.symbol
                                                                               type:newAlert.alertType == AlertTypePriceAbove ? @"priceAbove" : @"priceBelow"
                                                                          condition:conditions];
            
            if (newAlert.notes) {
                dataHubAlert.message = newAlert.notes;
                [[SymbolDataHub sharedHub] saveContext];
            }
            
            [self refreshData];
        }
    }];
}

- (void)editSelectedAlert {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.displayedAlerts.count) return;
    
    AlertEntry *selectedAlert = self.displayedAlerts[selectedRow];
    [self showAlertEditSheet:selectedAlert];
}

- (void)deleteSelectedAlert {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.displayedAlerts.count) return;
    
    AlertEntry *alertToDelete = self.displayedAlerts[selectedRow];
    
    // Conferma eliminazione
    NSAlert *confirm = [[NSAlert alloc] init];
    confirm.messageText = @"Elimina Alert";
    confirm.informativeText = [NSString stringWithFormat:@"Sei sicuro di voler eliminare l'alert per %@?", alertToDelete.symbol];
    [confirm addButtonWithTitle:@"Elimina"];
    [confirm addButtonWithTitle:@"Annulla"];
    confirm.alertStyle = NSAlertStyleWarning;
    
    if ([confirm runModal] == NSAlertFirstButtonReturn) {
        // Trova e rimuovi dal DataHub
        NSArray<AlertData *> *alerts = [[SymbolDataHub sharedHub] alertsForSymbol:alertToDelete.symbol];

        for (AlertData *alert in alerts) {
            if ([alert.alertId isEqualToString:alertToDelete.alertID]) {
                [[SymbolDataHub sharedHub] removeAlert:alert];
                break;
            }
        }

        [self refreshData];
    }
}

- (void)clearTriggeredAlerts {
    NSAlert *confirm = [[NSAlert alloc] init];
    confirm.messageText = @"Elimina Alert Scattati";
    confirm.informativeText = @"Sei sicuro di voler eliminare tutti gli alert scattati?";
    [confirm addButtonWithTitle:@"Elimina"];
    [confirm addButtonWithTitle:@"Annulla"];
    confirm.alertStyle = NSAlertStyleWarning;
    
    if ([confirm runModal] == NSAlertFirstButtonReturn) {
        // Rimuovi tutti gli alert triggered dal DataHub
        for (AlertEntry *entry in self.displayedAlerts) {
            if (entry.status == AlertStatusTriggered) {
                NSArray<AlertData *> *alerts = [[SymbolDataHub sharedHub] alertsForSymbol:entry.symbol];
                
                for (AlertData *alert in alerts) {
                    if ([alert.alertId isEqualToString:entry.alertID]) {
                        [[SymbolDataHub sharedHub] removeAlert:alert];
                        break;
                    }
                }
            }
        }
        
        [self refreshData];
    }
}

- (void)showAlertEditSheet:(AlertEntry *)alert {
    AlertEditWindowController *editController = [[AlertEditWindowController alloc] init];
    editController.alert = alert;
    editController.isNewAlert = NO;
    
    [self.view.window beginSheet:editController.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSModalResponseOK) {
            // Aggiorna nel DataHub
            NSArray<AlertData *> *alerts = [[SymbolDataHub sharedHub] alertsForSymbol:alert.symbol];
            
            for (AlertData *dataHubAlert in alerts) {
                if ([dataHubAlert.alertId isEqualToString:alert.alertID]) {
                    // Aggiorna proprietà
                    NSNumber *newPrice = @(editController.alert.targetPrice);
                    NSMutableDictionary *conditions = [dataHubAlert.conditions mutableCopy];
                    conditions[@"price"] = newPrice;
                    dataHubAlert.conditions = conditions;
                    
                    dataHubAlert.type = editController.alert.alertType == AlertTypePriceAbove ? AlertTypePriceAbove : AlertTypePriceBelow;
                    dataHubAlert.message = editController.alert.notes;
                    
                    [[SymbolDataHub sharedHub] saveContext];
                    break;
                }
            }
            
            [self refreshData];
        }
    }];
}

#pragma mark - DataHub Notifications

-- (void)dataHubUpdated:(NSNotification *)notification {
    SymbolUpdateType updateType = [notification.userInfo[kUpdateTypeKey] integerValue];
    
    if (updateType == SymbolUpdateTypeAlerts || updateType == SymbolUpdateTypeAll) {
        [self refreshData];
    }
}

- (void)alertTriggered:(NSNotification *)notification {
    AlertData *alert = notification.userInfo[@"alert"];
    NSString *symbol = notification.userInfo[@"symbol"];
    
    // Mostra notifica
    NSUserNotification *userNotification = [[NSUserNotification alloc] init];
    userNotification.title = [NSString stringWithFormat:@"Alert Scattato: %@", symbol];
    userNotification.informativeText = alert.message ?: [NSString stringWithFormat:@"Il prezzo ha raggiunto %.2f", [alert.conditions[@"price"] doubleValue]];
    userNotification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:userNotification];
    
    // Refresh per mostrare lo stato aggiornato
    [self refreshData];
}

#pragma mark - Widget Chain

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    NSString *action = update[@"action"];
    
    if ([action isEqualToString:@"setSymbol"]) {
        NSString *symbol = update[@"symbol"];
        if (symbol) {
            // Crea nuovo alert per il simbolo ricevuto
            AlertEntry *newAlert = [AlertEntry alertWithSymbol:symbol targetPrice:0 type:AlertTypePriceAbove];
            [self showAlertEditSheet:newAlert];
        }
    }
}
@end
