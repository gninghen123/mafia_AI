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
#import "ChartWidget.h"
#import "AppDelegate.h"
#import "FloatingWidgetWindow.h"
#import "SavedChartData+FilenameParsing.h"


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
}

// ========================================================================
// CORREZIONI PER ESPANDERE LA VIEW ORIZZONTALMENTE - StorageManagementWidget.m
// ========================================================================

// 1. SOSTITUISCI COMPLETAMENTE IL METODO createStorageManagementUI

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
    
    // 🎯 CRITICAL: Set minimum width per evitare compressione
    [container.widthAnchor constraintGreaterThanOrEqualToConstant:800].active = YES;
    
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
    statusStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    statusStack.spacing = 16;
    statusStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create label pairs (title + value) - MIGLIORATO
    NSTextField *totalLabel = [[NSTextField alloc] init];
    totalLabel.stringValue = @"Total:";
    totalLabel.editable = NO;
    totalLabel.bordered = NO;
    totalLabel.backgroundColor = [NSColor clearColor];
    totalLabel.font = [NSFont boldSystemFontOfSize:11];
    
    self.totalStoragesLabel = [[NSTextField alloc] init];
    self.totalStoragesLabel.stringValue = @"0";
    self.totalStoragesLabel.editable = NO;
    self.totalStoragesLabel.bordered = NO;
    self.totalStoragesLabel.backgroundColor = [NSColor clearColor];
    self.totalStoragesLabel.font = [NSFont systemFontOfSize:11];
    
    NSTextField *continuousLabel = [[NSTextField alloc] init];
    continuousLabel.stringValue = @"Continuous:";
    continuousLabel.editable = NO;
    continuousLabel.bordered = NO;
    continuousLabel.backgroundColor = [NSColor clearColor];
    continuousLabel.font = [NSFont boldSystemFontOfSize:11];
    
    self.continuousStoragesLabel = [[NSTextField alloc] init];
    self.continuousStoragesLabel.stringValue = @"0";
    self.continuousStoragesLabel.editable = NO;
    self.continuousStoragesLabel.bordered = NO;
    self.continuousStoragesLabel.backgroundColor = [NSColor clearColor];
    self.continuousStoragesLabel.font = [NSFont systemFontOfSize:11];
    
    NSTextField *snapshotLabel = [[NSTextField alloc] init];
    snapshotLabel.stringValue = @"Snapshot:";
    snapshotLabel.editable = NO;
    snapshotLabel.bordered = NO;
    snapshotLabel.backgroundColor = [NSColor clearColor];
    snapshotLabel.font = [NSFont boldSystemFontOfSize:11];
    
    self.snapshotStoragesLabel = [[NSTextField alloc] init];
    self.snapshotStoragesLabel.stringValue = @"0";
    self.snapshotStoragesLabel.editable = NO;
    self.snapshotStoragesLabel.bordered = NO;
    self.snapshotStoragesLabel.backgroundColor = [NSColor clearColor];
    self.snapshotStoragesLabel.font = [NSFont systemFontOfSize:11];
    
    NSTextField *errorLabel = [[NSTextField alloc] init];
    errorLabel.stringValue = @"Errors:";
    errorLabel.editable = NO;
    errorLabel.bordered = NO;
    errorLabel.backgroundColor = [NSColor clearColor];
    errorLabel.font = [NSFont boldSystemFontOfSize:11];
    
    self.errorStoragesLabel = [[NSTextField alloc] init];
    self.errorStoragesLabel.stringValue = @"0";
    self.errorStoragesLabel.editable = NO;
    self.errorStoragesLabel.bordered = NO;
    self.errorStoragesLabel.backgroundColor = [NSColor clearColor];
    self.errorStoragesLabel.font = [NSFont systemFontOfSize:11];
    
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
    
    // Create table view with EXPANDED COLUMNS
    self.storageTableView = [[NSTableView alloc] init];
    self.storageTableView.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    self.storageTableView.rowHeight = 24;
    self.storageTableView.intercellSpacing = NSMakeSize(4, 2);
    
    // 🎯 LARGHEZZE COLONNE ESPANSE per visibilità completa
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 100;          // Aumentata da 80
    symbolColumn.minWidth = 80;
    symbolColumn.maxWidth = 150;
    [self.storageTableView addTableColumn:symbolColumn];
    
    NSTableColumn *timeframeColumn = [[NSTableColumn alloc] initWithIdentifier:@"timeframe"];
    timeframeColumn.title = @"Timeframe";
    timeframeColumn.width = 100;       // Aumentata da 80
    timeframeColumn.minWidth = 80;
    timeframeColumn.maxWidth = 120;
    [self.storageTableView addTableColumn:timeframeColumn];
    
    NSTableColumn *typeColumn = [[NSTableColumn alloc] initWithIdentifier:@"type"];
    typeColumn.title = @"Type";
    typeColumn.width = 90;             // Aumentata da 80
    typeColumn.minWidth = 80;
    typeColumn.maxWidth = 100;
    [self.storageTableView addTableColumn:typeColumn];
    
    NSTableColumn *rangeColumn = [[NSTableColumn alloc] initWithIdentifier:@"range"];
    rangeColumn.title = @"Date Range";
    rangeColumn.width = 180;           // Aumentata da 120
    rangeColumn.minWidth = 150;
    rangeColumn.maxWidth = 250;
    [self.storageTableView addTableColumn:rangeColumn];
    
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = @"Status";
    statusColumn.width = 120;          // Aumentata da 100
    statusColumn.minWidth = 100;
    statusColumn.maxWidth = 150;
    [self.storageTableView addTableColumn:statusColumn];
    
    NSTableColumn *actionsColumn = [[NSTableColumn alloc] initWithIdentifier:@"actions"];
    actionsColumn.title = @"Actions";
    actionsColumn.width = 80;
    actionsColumn.minWidth = 60;
    actionsColumn.maxWidth = 100;
    [self.storageTableView addTableColumn:actionsColumn];
    
    // 🎯 ABILITA HEADERS per vedere meglio le colonne
    self.storageTableView.headerView = [[NSTableHeaderView alloc] init];
    
    // 🎯 ABILITA COLUMN RESIZING
    for (NSTableColumn *column in self.storageTableView.tableColumns) {
        column.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    }
    
    // Wrap table in scroll view con scrolling orizzontale
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.documentView = self.storageTableView;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = YES;  // 🎯 IMPORTANTE: Abilita scroll orizzontale
    scrollView.autohidesScrollers = YES;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create status labels
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.stringValue = @"Initializing...";
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.nextUpdateLabel = [[NSTextField alloc] init];
    self.nextUpdateLabel.stringValue = @"No updates scheduled";
    self.nextUpdateLabel.editable = NO;
    self.nextUpdateLabel.bordered = NO;
    self.nextUpdateLabel.backgroundColor = [NSColor clearColor];
    self.nextUpdateLabel.font = [NSFont systemFontOfSize:11];
    self.nextUpdateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add all subviews to container
    [container addSubview:self.filterSegmentedControl];
    [container addSubview:statusStack];
    [container addSubview:buttonStack];
    [container addSubview:scrollView];
    [container addSubview:self.statusLabel];
    [container addSubview:self.nextUpdateLabel];
    
    // 🎯 CONSTRAINTS OTTIMIZZATI per larghezza espansa
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
        [statusStack.heightAnchor constraintEqualToConstant:25],
        
        // Button stack below status
        [buttonStack.topAnchor constraintEqualToAnchor:statusStack.bottomAnchor constant:8],
        [buttonStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [buttonStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [buttonStack.heightAnchor constraintEqualToConstant:30],
        
        // Table view in middle - 🎯 MINIMA ALTEZZA GARANTITA
        [scrollView.topAnchor constraintEqualToAnchor:buttonStack.bottomAnchor constant:8],
        [scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.statusLabel.topAnchor constant:-8],
        [scrollView.heightAnchor constraintGreaterThanOrEqualToConstant:300], // 🎯 MINIMA ALTEZZA
        
        // Status labels at bottom
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.nextUpdateLabel.topAnchor constant:-4],
        [self.statusLabel.heightAnchor constraintEqualToConstant:18],
        
        [self.nextUpdateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.nextUpdateLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.nextUpdateLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [self.nextUpdateLabel.heightAnchor constraintEqualToConstant:18]
    ]];
    
    [self setupTableView];
}


- (void)setupTableView {
    // Configure table view
    [self.storageTableView setDataSource:self];
    [self.storageTableView setDelegate:self];
    
    self.storageTableView.doubleAction = @selector(handleTableDoubleClick:);
       self.storageTableView.target = self;
    self.storageTableView.allowsColumnReordering = YES;
      self.storageTableView.allowsColumnResizing = YES;
      self.storageTableView.allowsColumnSelection = YES; // abilita selezione intestazioni
      self.storageTableView.allowsEmptySelection = YES;
      self.storageTableView.allowsMultipleSelection = NO;
      self.storageTableView.allowsTypeSelect = YES;

      // 🎯 ABILITA ORDINAMENTO NATIVO COLONNE
    for (NSTableColumn *column in self.storageTableView.tableColumns) {
        NSSortDescriptor *sortDescriptor =
        [NSSortDescriptor sortDescriptorWithKey:column.identifier
                                      ascending:YES
                                       selector:@selector(localizedCaseInsensitiveCompare:)];
        column.sortDescriptorPrototype = sortDescriptor;
    }
    
    // Setup context menu
    [self.storageTableView setMenu:[self createContextMenu]];
    
    NSLog(@"✅ StorageManagementWidget UI setup complete with expanded view");
    NSLog(@"   - Container minimum width: 800px");
    NSLog(@"   - Table columns total width: ~680px");
    NSLog(@"   - Horizontal scrolling: enabled");
    NSLog(@"   - Column resizing: enabled");
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    NSSortDescriptor *descriptor = tableView.sortDescriptors.firstObject;
    if (!descriptor) return;
    
    NSString *key = descriptor.key;
    BOOL ascending = descriptor.ascending;
    
    self.storageItems = [self.storageItems sortedArrayUsingComparator:^NSComparisonResult(UnifiedStorageItem *a, UnifiedStorageItem *b) {
        NSString *valueA = [self valueForColumnKey:key fromItem:a];
        NSString *valueB = [self valueForColumnKey:key fromItem:b];
        return ascending ? [valueA compare:valueB options:NSCaseInsensitiveSearch]
                         : [valueB compare:valueA options:NSCaseInsensitiveSearch];
    }];
    
    [self.storageTableView reloadData];
}

- (NSString *)valueForColumnKey:(NSString *)key fromItem:(UnifiedStorageItem *)item {
    NSString *filename = [item.filePath lastPathComponent];
    
    if ([key isEqualToString:@"symbol"]) {
        return [SavedChartData symbolFromFilename:filename] ?: @"";
    } else if ([key isEqualToString:@"timeframe"]) {
        return [SavedChartData timeframeFromFilename:filename] ?: @"";
    } else if ([key isEqualToString:@"type"]) {
        return [SavedChartData typeFromFilename:filename] ?: @"";
    } else if ([key isEqualToString:@"range"]) {
        return [SavedChartData dateRangeStringFromFilename:filename] ?: @"";
    } else if ([key isEqualToString:@"status"]) {
        return [self statusStringForStorageItem:item] ?: @"";
    }
    return @""; // default
}

- (void)dealloc {
    [self stopAutoRefresh];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)setupNotificationObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // ✅ PRINCIPALE: Ascolta aggiornamenti del registry
    [nc addObserver:self
           selector:@selector(handleStorageManagerUpdate:)
               name:@"StorageManagerDidUpdateRegistry"
             object:nil];
    
    // ✅ NUOVO: Ascolta cambi di stato degli updates
    [nc addObserver:self
           selector:@selector(handleStorageUpdateStatusChange:)
               name:@"StorageManagerUpdateStatusChanged"
             object:nil];
    
    // ✅ NUOVO: Ascolta creazione di nuovi storage
    [nc addObserver:self
           selector:@selector(handleNewStorageCreated:)
               name:@"NewContinuousStorageCreated"
             object:nil];
    
    NSLog(@"📡 StorageManagementWidget: Notification observers setup complete");
}
- (NSMenu *)createContextMenu {
    NSMenu *contextMenu = [[NSMenu alloc] init];
    
    [contextMenu addItemWithTitle:@"🔬 Open in New Window" action:@selector(contextMenuOpenInWindow:) keyEquivalent:@""];
    [contextMenu addItem:[NSMenuItem separatorItem]];
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


- (void)contextMenuOpenInWindow:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        UnifiedStorageItem *item = self.storageItems[selectedRow];
        [self openChartDataInFloatingWindow:item];
    }
}

#pragma mark - Data Management

- (IBAction)refreshStorageList:(id)sender {
    NSLog(@"🔄 Refreshing storage list...");
    
    // ✅ AGGIUNTO: Indicatore visivo di refresh
    if (sender) {
        [self showStatusMessage:@"🔄 Refreshing..." duration:1.0];
    }
    

    
    
    // Apply current filter to get the right data
    [self applyCurrentFilter];
    
    // Reload table
    [self.storageTableView reloadData];
    
    // Update status display
    [self updateStatusDisplay];
    
    NSLog(@"🔄 Storage list refreshed: %ld items displayed", (long)self.storageItems.count);
    
    // ✅ AGGIUNTO: Feedback finale
    if (sender) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showStatusMessage:@"✅ Refresh complete" duration:1.5];
        });
    }
}

- (void)updateStatusDisplay {
    StorageManager *manager = [StorageManager sharedManager];
    
    // Update statistics labels
    self.totalStoragesLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)manager.totalActiveStorages];
    
    // Calcolo storage continui vs snapshot
    NSInteger continuousCount = manager.continuousStorageItems.count;
    NSInteger snapshotCount = manager.snapshotStorageItems.count;
    
    // ✅ AGGIUNTO: Verifica esistenza label prima di aggiornare
    if (self.continuousStoragesLabel) {
        self.continuousStoragesLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)continuousCount];
    }
    
    if (self.snapshotStoragesLabel) {
        self.snapshotStoragesLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)snapshotCount];
    }
    
    if (self.errorStoragesLabel) {
        NSInteger errorCount = manager.storagesWithErrors;
        self.errorStoragesLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)errorCount];
        
        // ✅ AGGIUNTO: Colore rosso se ci sono errori
        self.errorStoragesLabel.textColor = errorCount > 0 ? [NSColor systemRedColor] : [NSColor labelColor];
    }
    
    // Next update info
    if (self.nextUpdateLabel) {
        ActiveStorageItem *nextItem = manager.nextStorageToUpdate;
        if (nextItem && nextItem.savedData && nextItem.savedData.nextScheduledUpdate) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterShortStyle;
            
            NSString *nextUpdateString = [NSString stringWithFormat:@"Next: %@ at %@",
                                        nextItem.savedData.symbol,
                                        [formatter stringFromDate:nextItem.savedData.nextScheduledUpdate]];
            self.nextUpdateLabel.stringValue = nextUpdateString;
        } else {
            self.nextUpdateLabel.stringValue = @"No updates scheduled";
        }
    }
    
    // Status summary
    if (self.statusLabel) {
        NSString *statusText;
        if (continuousCount == 0 && snapshotCount == 0) {
            statusText = @"No storage items found";
        } else if (!manager.automaticUpdatesEnabled) {
            statusText = @"⏸️ Automatic updates paused";
        } else {
            NSInteger pausedCount = manager.pausedStorages;
            NSInteger errorCount = manager.storagesWithErrors;
            
            if (errorCount > 0) {
                statusText = [NSString stringWithFormat:@"⚠️ %ld active, %ld errors", (long)(continuousCount - pausedCount - errorCount), (long)errorCount];
            } else if (pausedCount > 0) {
                statusText = [NSString stringWithFormat:@"✅ %ld active, %ld paused", (long)(continuousCount - pausedCount), (long)pausedCount];
            } else {
                statusText = [NSString stringWithFormat:@"✅ All %ld storages active", (long)continuousCount];
            }
        }
        
        self.statusLabel.stringValue = statusText;
    }
    
    // Update button states
    if (self.pauseAllButton) {
        self.pauseAllButton.title = manager.automaticUpdatesEnabled ? @"⏸️ Pause All" : @"▶️ Resume All";
    }
    
    if (self.updateAllButton) {
        self.updateAllButton.enabled = (manager.totalActiveStorages > 0);
    }
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
    
    UnifiedStorageItem *item = self.storageItems[row];
    NSString *filename = [item.filePath lastPathComponent];
    NSString *columnIdentifier = tableColumn.identifier;
    
    if ([columnIdentifier isEqualToString:@"symbol"]) {
        NSString *symbol = [SavedChartData symbolFromFilename:filename];
        return symbol ?: @"Unknown";
        
    } else if ([columnIdentifier isEqualToString:@"timeframe"]) {
        NSString *timeframe = [SavedChartData timeframeFromFilename:filename];
        return timeframe ?: @"Unknown";
        
    } else if ([columnIdentifier isEqualToString:@"type"]) {
        NSString *type = [SavedChartData typeFromFilename:filename];
        return type ?: @"Unknown";
        
    } else if ([columnIdentifier isEqualToString:@"range"]) {
        NSString *dateRange = [SavedChartData dateRangeStringFromFilename:filename];
        return dateRange ?: @"No data";
        
    } else if ([columnIdentifier isEqualToString:@"bars"]) {
        NSInteger barCount = [SavedChartData barCountFromFilename:filename];
        return [NSString stringWithFormat:@"%ld bars", (long)barCount];
        
    } else if ([columnIdentifier isEqualToString:@"status"]) {
        return [self statusStringForStorageItem:item];
        
    } else if ([columnIdentifier isEqualToString:@"actions"]) {
        return @"•••";
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
        UnifiedStorageItem *item = self.storageItems[selectedRow];
        [self forceUpdateStorage:item];
    }
}

- (void)contextMenuPauseResume:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        UnifiedStorageItem *item = self.storageItems[selectedRow];
        [self pauseResumeStorage:item];
    }
}

- (void)contextMenuConvertToSnapshot:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        UnifiedStorageItem *item = self.storageItems[selectedRow];
        [self convertToSnapshot:item];
    }
}

- (void)contextMenuShowDetails:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        UnifiedStorageItem *item = self.storageItems[selectedRow];
        [self showStorageDetails:item];
    }
}

- (void)contextMenuShowInFinder:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        UnifiedStorageItem *item = self.storageItems[selectedRow];
        [self openStorageLocation:item];
    }
}

- (void)contextMenuDeleteStorage:(id)sender {
    NSInteger selectedRow = self.storageTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.storageItems.count) {
        UnifiedStorageItem *item = self.storageItems[selectedRow];
        [self deleteStorage:item];
    }
}


#pragma mark - Individual Storage Actions

- (void)forceUpdateStorage:(UnifiedStorageItem *)item {
    if (!item.isContinuous) {
        NSString *symbol = [SavedChartData symbolFromFilename:[item.filePath lastPathComponent]] ?: @"Unknown";
        NSLog(@"⚠️ Cannot update snapshot storage: %@", symbol);
        return;
    }
    
    // ✅ CORREZIONE: Usa filename parsing per symbol invece di savedData
    NSString *symbol = item.savedData ? item.savedData.symbol : [SavedChartData symbolFromFilename:[item.filePath lastPathComponent]];
    NSLog(@"🔧 Force updating storage: %@", symbol ?: @"Unknown");
    
    [[StorageManager sharedManager] forceUpdateForStorage:item.filePath
                                               completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"✅ Force update successful for %@", symbol ?: @"Unknown");
            } else {
                NSLog(@"❌ Force update failed for %@: %@", symbol ?: @"Unknown", error.localizedDescription);
                
                NSAlert *errorAlert = [[NSAlert alloc] init];
                errorAlert.messageText = @"Update Failed";
                errorAlert.informativeText = [NSString stringWithFormat:@"Failed to update %@:\n%@",
                                             symbol ?: @"Unknown", error.localizedDescription];
                errorAlert.alertStyle = NSAlertStyleWarning;
                [errorAlert runModal];
            }
            
            [self refreshStorageList:nil];
        });
    }];
}

- (void)pauseResumeStorage:(UnifiedStorageItem *)item {
    if (!item.isContinuous || !item.activeItem) {
        NSLog(@"⚠️ Cannot pause/resume snapshot or inactive storage: %@", item.savedData.symbol);
        return;
    }
    
    BOOL newPausedState = !item.activeItem.isPaused;
    
    [[StorageManager sharedManager] setPaused:newPausedState forStorage:item.filePath];
    
    NSLog(@"%@ storage: %@", newPausedState ? @"⏸️ Paused" : @"▶️ Resumed", item.savedData.symbol);
    
    [self refreshStorageList:nil];
}

- (void)convertToSnapshot:(UnifiedStorageItem *)item {
    if (!item.isContinuous) {
        NSLog(@"⚠️ Cannot convert snapshot to snapshot: %@", item.savedData.symbol);
        return;
    }
    
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

- (void)deleteStorage:(UnifiedStorageItem *)item {
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"⚠️ Delete Storage?";
    confirmAlert.informativeText = [NSString stringWithFormat:@"Permanently delete %@ [%@] storage?\n\n⚠️ This action cannot be undone!",
                                   item.savedData.symbol, [item.savedData timeframeDescription]];
    confirmAlert.alertStyle = NSAlertStyleCritical;
    [confirmAlert addButtonWithTitle:@"Delete"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    if ([confirmAlert runModal] == NSAlertFirstButtonReturn) {
        [[StorageManager sharedManager] deleteStorageItem:item.filePath
                                               completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSLog(@"✅ Storage deleted: %@", item.savedData.symbol);
                } else {
                    NSLog(@"❌ Failed to delete storage: %@", error.localizedDescription);
                    
                    NSAlert *errorAlert = [[NSAlert alloc] init];
                    errorAlert.messageText = @"Delete Failed";
                    errorAlert.informativeText = [NSString stringWithFormat:@"Failed to delete storage:\n%@", error.localizedDescription];
                    errorAlert.alertStyle = NSAlertStyleWarning;
                    [errorAlert runModal];
                }
                
                [self refreshStorageList:nil];
            });
        }];
    }
}

- (void)showStorageDetails:(UnifiedStorageItem *)item {
    // ✅ OTTIMIZZAZIONE: Get all metadata from filename first
    NSString *filename = [item.filePath lastPathComponent];
    NSDictionary *metadata = [self getStorageMetadataFromFilename:filename fallbackItem:item];
    
    // Create details string using parsed metadata
    NSMutableString *details = [NSMutableString string];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    NSDateFormatter *shortFormatter = [[NSDateFormatter alloc] init];
    shortFormatter.dateStyle = NSDateFormatterShortStyle;
    shortFormatter.timeStyle = NSDateFormatterNoStyle;
    
    // Basic info from parsed metadata
    [details appendFormat:@"Symbol: %@\n", metadata[@"symbol"]];
    [details appendFormat:@"Timeframe: %@\n", metadata[@"timeframe"]];
    [details appendFormat:@"Type: %@\n", metadata[@"type"]];
    [details appendFormat:@"Bars: %@\n", metadata[@"barCount"]];
    [details appendFormat:@"Range: %@\n", metadata[@"dateRange"]];
    [details appendFormat:@"Extended Hours: %@\n", [metadata[@"extendedHours"] boolValue] ? @"Yes" : @"No"];
    [details appendFormat:@"Has Gaps: %@\n", [metadata[@"hasGaps"] boolValue] ? @"Yes" : @"No"];
    [details appendFormat:@"File Size: %@ KB\n", metadata[@"fileSizeKB"]];
    
    // Creation date from filename
    if (metadata[@"creationDate"]) {
        [details appendFormat:@"Created: %@\n", [dateFormatter stringFromDate:metadata[@"creationDate"]]];
    }
    
    // Additional info for continuous storage (if activeItem exists)
    if (item.isContinuous && item.activeItem) {
        [details appendFormat:@"Failure Count: %ld\n", (long)item.activeItem.failureCount];
        [details appendFormat:@"Paused: %@\n", item.activeItem.isPaused ? @"Yes" : @"No"];
        
        // These require loading the saved data (only if needed)
        if (item.savedData) {
            if (item.savedData.lastSuccessfulUpdate) {
                [details appendFormat:@"Last Update: %@\n", [dateFormatter stringFromDate:item.savedData.lastSuccessfulUpdate]];
            }
            if (item.savedData.nextScheduledUpdate && !item.activeItem.isPaused) {
                [details appendFormat:@"Next Update: %@\n", [dateFormatter stringFromDate:item.savedData.nextScheduledUpdate]];
            }
        } else {
            [details appendString:@"[Additional update info requires loading file]\n"];
        }
    }
    
    [details appendFormat:@"\nFile Path: %@\n", item.filePath];
    [details appendFormat:@"Data Source: %@", metadata[@"source"]];
    
    // Show in alert
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Storage Details: %@", metadata[@"symbol"]];
    alert.informativeText = details;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}



- (void)openStorageLocation:(UnifiedStorageItem *)item {
    [[NSWorkspace sharedWorkspace] selectFile:item.filePath inFileViewerRootedAtPath:nil];
}

#pragma mark - Status Helpers

- (NSString *)statusStringForStorageItem:(UnifiedStorageItem *)item {
    NSString *filename = [item.filePath lastPathComponent];
    
    if (item.isContinuous && item.activeItem) {
        ActiveStorageItem *activeItem = item.activeItem;
        
        if (activeItem.isPaused) {
            return @"⏸️ Paused";
        } else if (activeItem.failureCount > 0) {
            return [NSString stringWithFormat:@"⚠️ %ld failures", (long)activeItem.failureCount];
        } else {
            NSDate *lastUpdate = [SavedChartData lastUpdateFromFilename:filename];
            if (lastUpdate) {
                NSTimeInterval timeSinceUpdate = [[NSDate date] timeIntervalSinceDate:lastUpdate];
                if (timeSinceUpdate < 3600) return @"✅ Recent";
                if (timeSinceUpdate < 86400) return @"🔄 Active";
                return @"🕐 Stale";
            }
            return @"🔄 Active";
        }
    } else {
        NSDate *creationDate = [SavedChartData creationDateFromFilename:filename];
        if (creationDate) {
            NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:creationDate];
            if (age < 86400) return @"📸 Recent";
            if (age < 604800) return @"📸 This week";
            return @"📸 Archived";
        }
        return @"📸 Snapshot";
    }
}

- (NSColor *)statusColorForStorageItem:(UnifiedStorageItem *)item {
    if (item.isSnapshot) {
        return [NSColor systemBlueColor];
    }
    
    if (item.activeItem) {
        ActiveStorageItem *activeItem = item.activeItem;
        if (activeItem.isPaused) {
            return [NSColor systemYellowColor];
        } else if (activeItem.failureCount > 0) {
            return [NSColor systemRedColor];
        } else if (item.savedData.hasGaps) {
            return [NSColor systemOrangeColor];
        } else if (item.savedData.nextScheduledUpdate && [item.savedData.nextScheduledUpdate compare:[NSDate date]] == NSOrderedAscending) {
            return [NSColor systemOrangeColor];
        } else {
            return [NSColor systemGreenColor];
        }
    }
    
    return [NSColor systemGrayColor];
}

- (NSString *)typeStringForStorageItem:(UnifiedStorageItem *)item {
    return item.isContinuous ? @"Continuous" : @"Snapshot";
}



#pragma mark - Notification Handlers

- (void)handleStorageManagerUpdate:(NSNotification *)notification {
    NSString *action = notification.userInfo[@"action"];
    
    // ✅ CORREZIONE: Ignora le notifiche di refresh che causano loop
    if ([action isEqualToString:@"refreshCompleted"]) {
        NSLog(@"📢 StorageManagementWidget ignoring refreshCompleted to prevent loop");
        return;
    }
    
    NSLog(@"📢 StorageManagementWidget received update: %@", action ?: @"unknown");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshStorageList:nil];
    });
}

- (void)handleStorageUpdateStatusChange:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    NSString *status = notification.userInfo[@"status"];
    
    NSLog(@"📊 Storage update status: %@ - %@", symbol, status);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update solo la UI se necessario (non force refresh completo)
        [self updateStatusDisplay];
        
        // ✅ AGGIUNTO: Feedback per status importanti
        if ([status isEqualToString:@"Completed"]) {
            [self showStatusMessage:[NSString stringWithFormat:@"✅ %@ updated", symbol] duration:2.0];
        } else if ([status isEqualToString:@"Failed"]) {
            [self showStatusMessage:[NSString stringWithFormat:@"❌ %@ update failed", symbol] duration:3.0];
        }
    });
}
- (void)handleNewStorageCreated:(NSNotification *)notification {
    NSString *filePath = notification.userInfo[@"filePath"];
    
    NSLog(@"🆕 New storage created: %@", [filePath lastPathComponent]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshStorageList:nil];
        [self showStatusMessage:@"🆕 New storage created" duration:2.0];
    });
}
- (void)showStatusMessage:(NSString *)message duration:(NSTimeInterval)duration {
    // Update status label temporarily
    NSString *originalStatus = self.statusLabel.stringValue;
    self.statusLabel.stringValue = message;
    
    // ✅ AGGIUNTO: Cambio colore per feedback visivo
    NSColor *originalColor = self.statusLabel.textColor;
    self.statusLabel.textColor = [NSColor systemBlueColor];
    
    // Restore after delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = originalStatus;
        self.statusLabel.textColor = originalColor;
    });
}

- (IBAction)filterTypeChanged:(NSSegmentedControl *)sender {
    // Update current filter based on selected segment
    self.currentFilter = (StorageFilterType)sender.selectedSegment;
    
    NSLog(@"🔍 Filter changed to: %@",
          self.currentFilter == StorageFilterTypeAll ? @"All" :
          self.currentFilter == StorageFilterTypeContinuous ? @"Continuous" : @"Snapshot");
    
    // Apply filter and refresh display
    [self applyCurrentFilter];
    [self.storageTableView reloadData];
    [self updateStatusDisplay];
}

// 2. AGGIUNGI IL METODO applyCurrentFilter nella sezione #pragma mark - Data Management

- (void)applyCurrentFilter {
    StorageManager *manager = [StorageManager sharedManager];
    NSArray<UnifiedStorageItem *> *allItems = manager.allStorageItems;
    
    switch (self.currentFilter) {
        case StorageFilterTypeAll:
            self.storageItems = allItems;
            break;
            
        case StorageFilterTypeContinuous:
            self.storageItems = manager.continuousStorageItems;
            break;
            
        case StorageFilterTypeSnapshot:
            self.storageItems = manager.snapshotStorageItems;
            break;
    }
    
    NSLog(@"🔍 Applied filter: %ld items displayed", (long)self.storageItems.count);
}

#pragma mark - Double-Click Handler

- (void)handleTableDoubleClick:(id)sender {
    NSInteger clickedRow = self.storageTableView.clickedRow;
    
    if (clickedRow < 0 || clickedRow >= self.storageItems.count) {
        NSLog(@"⚠️ Invalid double-click row: %ld", (long)clickedRow);
        return;
    }
    
    UnifiedStorageItem *selectedItem = self.storageItems[clickedRow];
    
    NSLog(@"🔬 Double-click detected: Opening %@ [%@] in chart window",
          selectedItem.savedData.symbol, selectedItem.savedData.timeframeDescription);
    
    [self openChartDataInFloatingWindow:selectedItem];
}

// 4. AGGIUNGI QUESTO METODO HELPER (CORE LOGIC)

- (void)openChartDataInFloatingWindow:(UnifiedStorageItem *)storageItem {
    // Get app delegate
    AppDelegate *appDelegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
    if (!appDelegate) {
        NSLog(@"❌ Cannot get AppDelegate");
        return;
    }
    
    // Create chart widget
    ChartWidget *chartWidget = [[ChartWidget alloc] initWithType:@"Chart Widget"];
    if (!chartWidget) {
        NSLog(@"❌ Failed to create ChartWidget");
        return;
    }
    
    // ✅ OTTIMIZZAZIONE: Get metadata from filename instead of loading savedData
    NSString *filename = [storageItem.filePath lastPathComponent];
    NSString *symbol, *timeframeStr, *typeStr;
    
    if ([SavedChartData isNewFormatFilename:filename]) {
        // ✅ FAST: Use filename parsing
        symbol = [SavedChartData symbolFromFilename:filename] ?: @"Unknown";
        timeframeStr = [SavedChartData timeframeFromFilename:filename] ?: @"Unknown";
        typeStr = [SavedChartData typeFromFilename:filename] ?: @"Unknown";
    } else if (storageItem.savedData) {
        // ❌ FALLBACK: Use already loaded data (if available)
        symbol = storageItem.savedData.symbol ?: @"Unknown";
        timeframeStr = storageItem.savedData.timeframeDescription ?: @"Unknown";
        typeStr = storageItem.savedData.dataType == SavedChartDataTypeContinuous ? @"CONTINUOUS" : @"SNAPSHOT";
    } else {
        // ❌ ULTIMATE FALLBACK: Load file (rare case)
        NSLog(@"⚠️ Loading file for window title (old format): %@", filename);
        SavedChartData *tempData = [SavedChartData loadFromFile:storageItem.filePath];
        symbol = tempData.symbol ?: @"Unknown";
        timeframeStr = tempData.timeframeDescription ?: @"Unknown";
        typeStr = tempData.dataType == SavedChartDataTypeContinuous ? @"CONTINUOUS" : @"SNAPSHOT";
    }
    
    // Create window title using parsed/cached data
    NSString *windowTitle = [NSString stringWithFormat:@"🔬 Chart Data: %@ [%@] (%@)",
                            symbol, timeframeStr, typeStr];
    
    // Determine window size based on content
    NSSize windowSize = NSMakeSize(1000, 700);
    
    // Create floating window
    FloatingWidgetWindow *chartWindow = [appDelegate createFloatingWindowWithWidget:chartWidget
                                                                               title:windowTitle
                                                                                size:windowSize];
    
    if (!chartWindow) {
        NSLog(@"❌ Failed to create floating window");
        return;
    }
    
    // Load chart data in background (this is the only unavoidable file loading)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *filePath = storageItem.filePath;
        
        [chartWidget loadSavedDataFromFile:filePath completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSLog(@"✅ Successfully loaded chart data: %@ in floating window", symbol);
                    [chartWindow makeKeyAndOrderFront:self];
                    [self showBriefSuccessMessage:[NSString stringWithFormat:@"Opened %@ chart", symbol]];
                } else {
                    NSLog(@"❌ Failed to load chart data: %@", error.localizedDescription);
                    [chartWindow close];
                    [self showLoadErrorDialog:error forSymbol:symbol];
                }
            });
        }];
    });
}


// 5. AGGIUNGI QUESTI METODI HELPER PER UX

#pragma mark - UX Helper Methods

- (void)showBriefSuccessMessage:(NSString *)message {
    // Brief flash message in status label
    NSString *originalStatus = self.statusLabel.stringValue;
    NSColor *originalColor = self.statusLabel.textColor;
    
    self.statusLabel.stringValue = [NSString stringWithFormat:@"✅ %@", message];
    self.statusLabel.textColor = [NSColor systemGreenColor];
    
    // Restore original after 2 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = originalStatus;
        self.statusLabel.textColor = originalColor;
    });
}

- (void)showLoadErrorDialog:(NSError *)error forSymbol:(NSString *)symbol {
    NSAlert *errorAlert = [[NSAlert alloc] init];
    errorAlert.messageText = @"Failed to Open Chart Data";
    errorAlert.informativeText = [NSString stringWithFormat:@"Could not load chart data for %@:\n\n%@",
                                 symbol, error.localizedDescription ?: @"Unknown error"];
    errorAlert.alertStyle = NSAlertStyleWarning;
    [errorAlert addButtonWithTitle:@"OK"];
    [errorAlert runModal];
}



@end
