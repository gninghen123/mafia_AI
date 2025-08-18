//
//  StorageManagementWidget.m
//  TradingApp
//
//  Implementation of storage management dashboard widget
//

#import "StorageManagementWidget.h"
#import "StorageManager.h"
#import "SavedChartData.h"
#import "ChartWidget+SaveData.h"
#import <Cocoa/Cocoa.h>

@interface StorageManagementWidget ()
@property (nonatomic, assign) BOOL allStoragesPaused;
@end

@implementation StorageManagementWidget

#pragma mark - Widget Lifecycle

- (void)loadView {
    [super loadView];
    
    // Initialize with default filter
    _currentFilter = StorageFilterTypeAll;
    
    NSLog(@"📊 StorageManagementWidget loaded");
}

- (void)setupContentView {
    [super setupContentView];
    
    [self createStorageManagementUI];
    [self setupNotificationObservers];
    [self refreshStorageList:nil];
    [self startAutoRefresh];
}

- (void)createStorageManagementUI {
    // Create main container
    NSView *container = [[NSView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:container];
    
    // Pin container to content view
    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [container.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [container.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [container.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];
    
    // Create filter segmented control
    self.filterSegmentedControl = [[NSSegmentedControl alloc] init];
    [self.filterSegmentedControl setSegmentCount:3];
    [self.filterSegmentedControl setLabel:@"All" forSegment:0];
    [self.filterSegmentedControl setLabel:@"Continuous" forSegment:1];
    [self.filterSegmentedControl setLabel:@"Snapshot" forSegment:2];
    [self.filterSegmentedControl setSelectedSegment:0];
    [self.filterSegmentedControl setTarget:self];
    [self.filterSegmentedControl setAction:@selector(filterTypeChanged:)];
    self.filterSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create status labels stack
    NSStackView *statusStack = [[NSStackView alloc] init];
    statusStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;  // FIX: Complete the line
    statusStack.spacing = 16;
    statusStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create label pairs (title + value)
    NSTextField *totalLabel = [[NSTextField alloc] init];
    totalLabel.stringValue = @"Total:";
    totalLabel.editable = NO;
    totalLabel.bordered = NO;
    totalLabel.backgroundColor = [NSColor clearColor];
    totalLabel.font = [NSFont boldSystemFontOfSize:12];
    
    self.totalStoragesLabel = [[NSTextField alloc] init];
    self.totalStoragesLabel.stringValue = @"0";
    self.totalStoragesLabel.editable = NO;
    self.totalStoragesLabel.bordered = NO;
    self.totalStoragesLabel.backgroundColor = [NSColor clearColor];
    
    NSTextField *continuousLabel = [[NSTextField alloc] init];
    continuousLabel.stringValue = @"Continuous:";
    continuousLabel.editable = NO;
    continuousLabel.bordered = NO;
    continuousLabel.backgroundColor = [NSColor clearColor];
    continuousLabel.font = [NSFont boldSystemFontOfSize:12];
    
    self.continuousStoragesLabel = [[NSTextField alloc] init];
    self.continuousStoragesLabel.stringValue = @"0";
    self.continuousStoragesLabel.editable = NO;
    self.continuousStoragesLabel.bordered = NO;
    self.continuousStoragesLabel.backgroundColor = [NSColor clearColor];
    
    NSTextField *snapshotLabel = [[NSTextField alloc] init];
    snapshotLabel.stringValue = @"Snapshot:";
    snapshotLabel.editable = NO;
    snapshotLabel.bordered = NO;
    snapshotLabel.backgroundColor = [NSColor clearColor];
    snapshotLabel.font = [NSFont boldSystemFontOfSize:12];
    
    self.snapshotStoragesLabel = [[NSTextField alloc] init];
    self.snapshotStoragesLabel.stringValue = @"0";
    self.snapshotStoragesLabel.editable = NO;
    self.snapshotStoragesLabel.bordered = NO;
    self.snapshotStoragesLabel.backgroundColor = [NSColor clearColor];
    
    NSTextField *errorLabel = [[NSTextField alloc] init];
    errorLabel.stringValue = @"Errors:";
    errorLabel.editable = NO;
    errorLabel.bordered = NO;
    errorLabel.backgroundColor = [NSColor clearColor];
    errorLabel.font = [NSFont boldSystemFontOfSize:12];
    
    self.errorStoragesLabel = [[NSTextField alloc] init];
    self.errorStoragesLabel.stringValue = @"0";
    self.errorStoragesLabel.editable = NO;
    self.errorStoragesLabel.bordered = NO;
    self.errorStoragesLabel.backgroundColor = [NSColor clearColor];
    
    [statusStack addArrangedSubview:totalLabel];
    [statusStack addArrangedSubview:self.totalStoragesLabel];
    [statusStack addArrangedSubview:continuousLabel];
    [statusStack addArrangedSubview:self.continuousStoragesLabel];
    [statusStack addArrangedSubview:snapshotLabel];
    [statusStack addArrangedSubview:self.snapshotStoragesLabel];
    [statusStack addArrangedSubview:errorLabel];
    [statusStack addArrangedSubview:self.errorStoragesLabel];
    
    // Create buttons stack
    NSStackView *buttonStack = [[NSStackView alloc] init];
    buttonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonStack.spacing = 8;
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.refreshButton = [NSButton buttonWithTitle:@"🔄 Refresh" target:self action:@selector(refreshStorageList:)];
    self.pauseAllButton = [NSButton buttonWithTitle:@"⏸️ Pause All" target:self action:@selector(togglePauseAllStorages:)];
    self.updateAllButton = [NSButton buttonWithTitle:@"🔧 Update All" target:self action:@selector(forceUpdateAllStorages:)];
    
    [buttonStack addArrangedSubview:self.refreshButton];
    [buttonStack addArrangedSubview:self.pauseAllButton];
    [buttonStack addArrangedSubview:self.updateAllButton];
    
    // Create table view
    self.storageTableView = [[NSTableView alloc] init];
    self.storageTableView.headerView = nil;
    self.storageTableView.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    
    // Create table columns
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    [self.storageTableView addTableColumn:symbolColumn];
    
    NSTableColumn *timeframeColumn = [[NSTableColumn alloc] initWithIdentifier:@"timeframe"];
    timeframeColumn.title = @"Timeframe";
    timeframeColumn.width = 80;
    [self.storageTableView addTableColumn:timeframeColumn];
    
    NSTableColumn *typeColumn = [[NSTableColumn alloc] initWithIdentifier:@"type"];
    typeColumn.title = @"Type";
    typeColumn.width = 80;
    [self.storageTableView addTableColumn:typeColumn];
    
    NSTableColumn *rangeColumn = [[NSTableColumn alloc] initWithIdentifier:@"range"];
    rangeColumn.title = @"Range";
    rangeColumn.width = 120;
    [self.storageTableView addTableColumn:rangeColumn];
    
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = @"Status";
    statusColumn.width = 100;
    [self.storageTableView addTableColumn:statusColumn];
    
    NSTableColumn *actionsColumn = [[NSTableColumn alloc] initWithIdentifier:@"actions"];
    actionsColumn.title = @"Actions";
    actionsColumn.width = 100;
    [self.storageTableView addTableColumn:actionsColumn];
    
    // Wrap table in scroll view
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.documentView = self.storageTableView;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = YES;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create status labels
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.stringValue = @"Initializing...";
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.nextUpdateLabel = [[NSTextField alloc] init];
    self.nextUpdateLabel.stringValue = @"No updates scheduled";
    self.nextUpdateLabel.editable = NO;
    self.nextUpdateLabel.bordered = NO;
    self.nextUpdateLabel.backgroundColor = [NSColor clearColor];
    self.nextUpdateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add all subviews to container
    [container addSubview:self.filterSegmentedControl];
    [container addSubview:statusStack];
    [container addSubview:buttonStack];
    [container addSubview:scrollView];
    [container addSubview:self.statusLabel];
    [container addSubview:self.nextUpdateLabel];
    
    // Setup constraints - TUTTI GLI ANCHOR DEVONO ESSERE COLLEGATI AD ALTRI ANCHOR
    [NSLayoutConstraint activateConstraints:@[
        // Filter control at top
        [self.filterSegmentedControl.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.filterSegmentedControl.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.filterSegmentedControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.filterSegmentedControl.heightAnchor constraintEqualToConstant:30],
        
        // Status stack below filter
        [statusStack.topAnchor constraintEqualToAnchor:self.filterSegmentedControl.bottomAnchor constant:8],
        [statusStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [statusStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [statusStack.heightAnchor constraintEqualToConstant:30],
        
        // Button stack below status
        [buttonStack.topAnchor constraintEqualToAnchor:statusStack.bottomAnchor constant:8],
        [buttonStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [buttonStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [buttonStack.heightAnchor constraintEqualToConstant:30],
        
        // Table view in middle
        [scrollView.topAnchor constraintEqualToAnchor:buttonStack.bottomAnchor constant:8],
        [scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.statusLabel.topAnchor constant:-8],
        
        // Status labels at bottom
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.nextUpdateLabel.topAnchor constant:-4],
        [self.statusLabel.heightAnchor constraintEqualToConstant:20],
        
        [self.nextUpdateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.nextUpdateLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.nextUpdateLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [self.nextUpdateLabel.heightAnchor constraintEqualToConstant:20]
    ]];
    
    [self setupTableView];
}
- (void)setupTableView {
        // Configure table view columns
        [self.storageTableView setDataSource:self];
        [self.storageTableView setDelegate:self];
        
        // Setup columns
        NSTableColumn *symbolColumn = [self.storageTableView tableColumnWithIdentifier:@"symbol"];
        symbolColumn.title = @"Symbol";
        symbolColumn.width = 80;
        
        NSTableColumn *timeframeColumn = [self.storageTableView tableColumnWithIdentifier:@"timeframe"];
        timeframeColumn.title = @"Timeframe";
        timeframeColumn.width = 80;
        
        NSTableColumn *rangeColumn = [self.storageTableView tableColumnWithIdentifier:@"range"];
        rangeColumn.title = @"Range";
        rangeColumn.width = 120;
        
        NSTableColumn *statusColumn = [self.storageTableView tableColumnWithIdentifier:@"status"];
        statusColumn.title = @"Status";
        statusColumn.width = 100;
        
        NSTableColumn *nextUpdateColumn = [self.storageTableView tableColumnWithIdentifier:@"nextUpdate"];
        nextUpdateColumn.title = @"Next Update";
        nextUpdateColumn.width = 120;
        
        NSTableColumn *actionsColumn = [self.storageTableView tableColumnWithIdentifier:@"actions"];
        actionsColumn.title = @"Actions";
        actionsColumn.width = 100;
        
        // Enable right-click context menu
        [self.storageTableView setMenu:[self createContextMenu]];
    
}


- (void)dealloc {
    [self stopAutoRefresh];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)setupNotificationObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Listen for storage manager changes
    [nc addObserver:self
           selector:@selector(handleStorageManagerUpdate:)
               name:@"StorageManagerDidUpdateRegistry"
             object:nil];
}

- (NSMenu *)createContextMenu {
    NSMenu *contextMenu = [[NSMenu alloc] init];
    
    [contextMenu addItemWithTitle:@"🔄 Force Update" action:@selector(contextMenuForceUpdate:) keyEquivalent:@""];
    [contextMenu addItemWithTitle:@"⏸️ Pause/Resume" action:@selector(contextMenuPauseResume:) keyEquivalent:@""];
    [contextMenu addItem:[NSMenuItem separatorItem]];
    [contextMenu addItemWithTitle:@"📸 Convert to Snapshot" action:@selector(contextMenuConvertToSnapshot:) keyEquivalent:@""];
    [contextMenu addItemWithTitle:@"ℹ️ Show Details" action:@selector(contextMenuShowDetails:) keyEquivalent:@""];
    [contextMenu addItemWithTitle:@"📁 Show in Finder" action:@selector(contextMenuShowInFinder:) keyEquivalent:@""];
    [contextMenu addItem:[NSMenuItem separatorItem]];
    [contextMenu addItemWithTitle:@"🗑️ Delete Storage" action:@selector(contextMenuDeleteStorage:) keyEquivalent:@""];
    
    // Set target for all menu items
    for (NSMenuItem *item in contextMenu.itemArray) {
        item.target = self;
    }
    
    return contextMenu;
}

#pragma mark - Data Management

- (IBAction)refreshStorageList:(id)sender {
    // Get latest storage data from StorageManager
    self.storageItems = [[StorageManager sharedManager] activeStorages];
    
    // Reload table
    [self.storageTableView reloadData];
    
    // Update status display
    [self updateStatusDisplay];
    
    NSLog(@"🔄 Storage list refreshed: %ld items", (long)self.storageItems.count);
}

- (void)updateStatusDisplay {
    StorageManager *manager = [StorageManager sharedManager];
    
    // Update statistics labels - usando solo le proprietà esistenti
    self.totalStoragesLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)manager.totalActiveStorages];
    
    // Calcolo storage continui vs snapshot per le label esistenti
    NSInteger continuousCount = 0;
    NSInteger snapshotCount = 0;
    
    // Conta i tipi di storage dall'array unificato
    for (UnifiedStorageItem *item in self.storageItems) {
        if (item.dataType == SavedChartDataTypeContinuous) {
            continuousCount++;
        } else if (item.dataType == SavedChartDataTypeSnapshot) {
            snapshotCount++;
        }
    }
    
    self.continuousStoragesLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)continuousCount];
    self.snapshotStoragesLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)snapshotCount];
    self.errorStoragesLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)manager.storagesWithErrors];
    
    // Next update info
    ActiveStorageItem *nextItem = manager.nextStorageToUpdate;
    if (nextItem && nextItem.savedData.nextScheduledUpdate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        
        NSString *nextUpdateText = [NSString stringWithFormat:@"%@ [%@]",
                                   [formatter stringFromDate:nextItem.savedData.nextScheduledUpdate],
                                   nextItem.savedData.symbol];
        self.nextUpdateLabel.stringValue = nextUpdateText;
    } else {
        self.nextUpdateLabel.stringValue = @"No updates scheduled";
    }
    
    // Overall status
    if (manager.totalActiveStorages == 0) {
        self.statusLabel.stringValue = @"No active storage";
        self.statusLabel.textColor = [NSColor secondaryLabelColor];
    } else if (manager.storagesWithErrors > 0) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"⚠️ %ld storage(s) have errors", (long)manager.storagesWithErrors];
        self.statusLabel.textColor = [NSColor systemOrangeColor];
    } else if (manager.automaticUpdatesEnabled) {
        self.statusLabel.stringValue = @"✅ All storage systems operational";
        self.statusLabel.textColor = [NSColor systemGreenColor];
    } else {
        self.statusLabel.stringValue = @"⏸️ Automatic updates disabled";
        self.statusLabel.textColor = [NSColor systemYellowColor];
    }
    
    // Update button states
    self.pauseAllButton.title = manager.automaticUpdatesEnabled ? @"⏸️ Pause All" : @"▶️ Resume All";
    self.updateAllButton.enabled = (manager.totalActiveStorages > 0);
}

#pragma mark - Actions

- (IBAction)togglePauseAllStorages:(id)sender {
    StorageManager *manager = [StorageManager sharedManager];
    
    BOOL newState = !manager.automaticUpdatesEnabled;
    manager.automaticUpdatesEnabled = newState;
    
    NSLog(@"%@ automatic updates for all storages", newState ? @"▶️ Resumed" : @"⏸️ Paused");
    
    [self refreshStorageList:nil];
}

- (IBAction)forceUpdateAllStorages:(id)sender {
    NSLog(@"🔧 Force updating all storages...");
    
    // Show progress indicator
    NSProgressIndicator *progress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
    progress.style = NSProgressIndicatorStyleSpinning;
    [progress startAnimation:nil];
    
    NSAlert *progressAlert = [[NSAlert alloc] init];
    progressAlert.messageText = @"Updating Storage";
    progressAlert.informativeText = @"Force updating all active storages...";
    progressAlert.accessoryView = progress;
    
    // Start updates
    [[StorageManager sharedManager] forceUpdateAllStorages];
    
    // Refresh UI after short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshStorageList:nil];
    });
}

- (IBAction)browseStorageFiles:(id)sender {
    NSString *storageDirectory = [ChartWidget savedChartDataDirectory];
    [[NSWorkspace sharedWorkspace] openFile:storageDirectory];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.storageItems.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.storageItems.count) return nil;
    
    ActiveStorageItem *item = self.storageItems[row];
    SavedChartData *storage = item.savedData;
    
    NSString *columnIdentifier = tableColumn.identifier;
    
    if ([columnIdentifier isEqualToString:@"symbol"]) {
        return storage.symbol;
        
    } else if ([columnIdentifier isEqualToString:@"timeframe"]) {
        return [storage timeframeDescription];
        
    } else if ([columnIdentifier isEqualToString:@"range"]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MMM dd";
        NSString *startStr = [formatter stringFromDate:storage.startDate];
        NSString *endStr = [formatter stringFromDate:storage.endDate];
        return [NSString stringWithFormat:@"%@ - %@ (%ld bars)", startStr, endStr, (long)storage.barCount];
        
    } else if ([columnIdentifier isEqualToString:@"status"]) {
        return [self statusStringForStorageItem:item];
        
    } else if ([columnIdentifier isEqualToString:@"nextUpdate"]) {
        if (item.isPaused) {
            return @"⏸️ Paused";
        } else if (storage.nextScheduledUpdate) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            
            NSTimeInterval timeUntilUpdate = [storage.nextScheduledUpdate timeIntervalSinceNow];
            if (timeUntilUpdate < 0) {
                return @"⚠️ Overdue";
            } else if (timeUntilUpdate < 86400) { // Less than 1 day
                return [NSString stringWithFormat:@"In %.0f hrs", timeUntilUpdate / 3600.0];
            } else {
                return [formatter stringFromDate:storage.nextScheduledUpdate];
            }
        } else {
            return @"Not scheduled";
        }
        
    } else if ([columnIdentifier isEqualToString:@"actions"]) {
        return @"⚙️ Actions";
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.storageItems.count) return;
    
    ActiveStorageItem *item = self.storageItems[row];
    
    // Color-code status column
    if ([tableColumn.identifier isEqualToString:@"status"]) {
        NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
        textCell.textColor = [self statusColorForStorageItem:item];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    // Enable/disable actions based on selection
    NSInteger selectedRow = self.storageTableView.selectedRow;
    BOOL hasSelection = (selectedRow >= 0 && selectedRow < self.storageItems.count);
    
    // Update context menu availability
    self.storageTableView.menu.itemArray[0].enabled = hasSelection; // Force Update
    self.storageTableView.menu.itemArray[1].enabled = hasSelection; // Pause/Resume
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return YES;
}

#pragma mark - Context Menu Actions

- (void)contextMenuForceUpdate:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        ActiveStorageItem *item = self.storageItems[selectedRow];
        [self forceUpdateStorage:item];
    }
}

- (void)contextMenuPauseResume:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        ActiveStorageItem *item = self.storageItems[selectedRow];
        [self pauseResumeStorage:item];
    }
}

- (void)contextMenuConvertToSnapshot:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        ActiveStorageItem *item = self.storageItems[selectedRow];
        [self convertToSnapshot:item];
    }
}

- (void)contextMenuShowDetails:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        ActiveStorageItem *item = self.storageItems[selectedRow];
        [self showStorageDetails:item];
    }
}

- (void)contextMenuShowInFinder:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        ActiveStorageItem *item = self.storageItems[selectedRow];
        [self openStorageLocation:item];
    }
}

- (void)contextMenuDeleteStorage:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        ActiveStorageItem *item = self.storageItems[selectedRow];
        [self deleteStorage:item];
    }
}

#pragma mark - Individual Storage Actions

- (void)forceUpdateStorage:(ActiveStorageItem *)item {
    NSLog(@"🔧 Force updating storage: %@", item.savedData.symbol);
    
    [[StorageManager sharedManager] forceUpdateForStorage:item.filePath
                                               completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"✅ Force update successful for %@", item.savedData.symbol);
            } else {
                NSLog(@"❌ Force update failed for %@: %@", item.savedData.symbol, error.localizedDescription);
                
                NSAlert *errorAlert = [[NSAlert alloc] init];
                errorAlert.messageText = @"Update Failed";
                errorAlert.informativeText = [NSString stringWithFormat:@"Failed to update %@:\n%@",
                                             item.savedData.symbol, error.localizedDescription];
                errorAlert.alertStyle = NSAlertStyleWarning;
                [errorAlert runModal];
            }
            
            [self refreshStorageList:nil];
        });
    }];
}

- (void)pauseResumeStorage:(ActiveStorageItem *)item {
    BOOL newPausedState = !item.isPaused;
    
    [[StorageManager sharedManager] setPaused:newPausedState forStorage:item.filePath];
    
    NSLog(@"%@ storage: %@", newPausedState ? @"⏸️ Paused" : @"▶️ Resumed", item.savedData.symbol);
    
    [self refreshStorageList:nil];
}

- (void)convertToSnapshot:(ActiveStorageItem *)item {
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"Convert to Snapshot?";
    confirmAlert.informativeText = [NSString stringWithFormat:@"Convert %@ [%@] from continuous to snapshot storage?\n\nThis will stop automatic updates but preserve all existing data.",
                                   item.savedData.symbol, [item.savedData timeframeDescription]];
    confirmAlert.alertStyle = NSAlertStyleInformational;
    [confirmAlert addButtonWithTitle:@"Convert"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    if ([confirmAlert runModal] == NSAlertFirstButtonReturn) {
        [[StorageManager sharedManager] convertStorageToSnapshot:item.filePath userConfirmed:YES];
        [self refreshStorageList:nil];
    }
}

- (void)deleteStorage:(ActiveStorageItem *)item {
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"⚠️ Delete Storage?";
    confirmAlert.informativeText = [NSString stringWithFormat:@"Permanently delete the storage for %@ [%@]?\n\nThis action cannot be undone and will delete all saved historical data.",
                                   item.savedData.symbol, [item.savedData timeframeDescription]];
    confirmAlert.alertStyle = NSAlertStyleCritical;
    [confirmAlert addButtonWithTitle:@"Delete"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    if ([confirmAlert runModal] == NSAlertFirstButtonReturn) {
        // Delete via StorageManager
        [[StorageManager sharedManager] unregisterContinuousStorage:item.filePath];
        
        // Delete file
        NSError *error;
        BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:item.filePath error:&error];
        
        if (deleted) {
            NSLog(@"🗑️ Successfully deleted storage: %@", item.savedData.symbol);
        } else {
            NSLog(@"❌ Failed to delete storage file: %@", error.localizedDescription);
            
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Delete Failed";
            errorAlert.informativeText = [NSString stringWithFormat:@"Failed to delete storage file:\n%@", error.localizedDescription];
            errorAlert.alertStyle = NSAlertStyleWarning;
            [errorAlert runModal];
        }
        
        [self refreshStorageList:nil];
    }
}

- (void)showStorageDetails:(ActiveStorageItem *)item {
    SavedChartData *storage = item.savedData;
    
    NSAlert *detailsAlert = [[NSAlert alloc] init];
    detailsAlert.messageText = [NSString stringWithFormat:@"📊 Storage Details: %@", storage.symbol];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    NSDateFormatter *shortFormatter = [[NSDateFormatter alloc] init];
    shortFormatter.dateStyle = NSDateFormatterShortStyle;
    
    NSMutableString *details = [NSMutableString string];
    [details appendFormat:@"Symbol: %@\n", storage.symbol];
    [details appendFormat:@"Timeframe: %@\n", [storage timeframeDescription]];
    [details appendFormat:@"Type: %@\n", storage.dataType == SavedChartDataTypeContinuous ? @"Continuous" : @"Snapshot"];
    [details appendFormat:@"Bars: %ld\n", (long)storage.barCount];
    [details appendFormat:@"Range: %@ to %@\n",
             [shortFormatter stringFromDate:storage.startDate],
             [shortFormatter stringFromDate:storage.endDate]];
    [details appendFormat:@"Created: %@\n", [dateFormatter stringFromDate:storage.creationDate]];
    
    if (storage.lastSuccessfulUpdate) {
        [details appendFormat:@"Last Update: %@\n", [dateFormatter stringFromDate:storage.lastSuccessfulUpdate]];
    }
    
    if (storage.nextScheduledUpdate && !item.isPaused) {
        [details appendFormat:@"Next Update: %@\n", [dateFormatter stringFromDate:storage.nextScheduledUpdate]];
    }
    
    [details appendFormat:@"Extended Hours: %@\n", storage.includesExtendedHours ? @"Yes" : @"No"];
    [details appendFormat:@"Has Gaps: %@\n", storage.hasGaps ? @"Yes" : @"No"];
    [details appendFormat:@"Failure Count: %ld\n", (long)item.failureCount];
    [details appendFormat:@"Status: %@\n", [self statusStringForStorageItem:item]];
    
    if (storage.notes && storage.notes.length > 0) {
        [details appendFormat:@"Notes: %@\n", storage.notes];
    }
    
    [details appendFormat:@"\nFile: %@", [item.filePath lastPathComponent]];
    
    detailsAlert.informativeText = details;
    detailsAlert.alertStyle = NSAlertStyleInformational;
    [detailsAlert runModal];
}

- (void)openStorageLocation:(ActiveStorageItem *)item {
    [[NSWorkspace sharedWorkspace] selectFile:item.filePath inFileViewerRootedAtPath:nil];
}

#pragma mark - Status Helpers

- (NSString *)statusStringForStorageItem:(ActiveStorageItem *)item {
    if (item.isPaused) {
        return @"⏸️ Paused";
    } else if (item.failureCount > 0) {
        return [NSString stringWithFormat:@"❌ Failed (%ld)", (long)item.failureCount];
    } else if (item.savedData.hasGaps) {
        return @"⚠️ Has Gaps";
    } else if (item.savedData.nextScheduledUpdate && [item.savedData.nextScheduledUpdate compare:[NSDate date]] == NSOrderedAscending) {
        return @"⏰ Overdue";
    } else {
        return @"✅ Active";
    }
}

- (NSColor *)statusColorForStorageItem:(ActiveStorageItem *)item {
    if (item.isPaused) {
        return [NSColor systemYellowColor];
    } else if (item.failureCount > 0) {
        return [NSColor systemRedColor];
    } else if (item.savedData.hasGaps) {
        return [NSColor systemOrangeColor];
    } else if (item.savedData.nextScheduledUpdate && [item.savedData.nextScheduledUpdate compare:[NSDate date]] == NSOrderedAscending) {
        return [NSColor systemOrangeColor];
    } else {
        return [NSColor systemGreenColor];
    }
}

#pragma mark - Auto-refresh

- (void)startAutoRefresh {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
    }
    
    // Refresh UI every 30 seconds
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                         target:self
                                                       selector:@selector(autoRefreshTimerFired:)
                                                       userInfo:nil
                                                        repeats:YES];
    
    NSLog(@"🔄 Auto-refresh started for StorageManagementWidget");
}

- (void)stopAutoRefresh {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    
    NSLog(@"⏸️ Auto-refresh stopped for StorageManagementWidget");
}

- (void)autoRefreshTimerFired:(NSTimer *)timer {
    [self refreshStorageList:nil];
}

#pragma mark - Notification Handlers

- (void)handleStorageManagerUpdate:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshStorageList:nil];
    });
}



@end
