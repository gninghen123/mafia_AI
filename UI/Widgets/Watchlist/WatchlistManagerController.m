//
//  WatchlistManagerController.m
//  mafia_AI
//

#import "WatchlistManagerController.h"
#import "DataHub.h"
#import "Watchlist+CoreDataClass.h"

@interface WatchlistManagerController ()
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSArray<Watchlist *> *watchlists;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *deleteButton;
@property (nonatomic, strong) NSButton *doneButton;
@end

@implementation WatchlistManagerController

- (instancetype)init {
    // CRITICAL: Don't call super initWithWindowNibName - create window manually
    self = [super init];
    if (self) {
        [self setupWindow];
        [self setupUI];
        [self loadWatchlists];
    }
    return self;
}

- (void)loadWindow {
    // This method is called when window property is accessed
    // We already set up the window in init, so just ensure it's configured
    if (!self.window) {
        [self setupWindow];
    }
}

- (void)setupWindow {
    NSRect frame = NSMakeRect(0, 0, 400, 300);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Manage Watchlists";
    window.minSize = NSMakeSize(300, 200);
    [window center];
    
    // Set window delegate for proper event handling
    window.delegate = self;
    
    // CRITICAL: Set the window property directly
    self.window = window;
    
    NSLog(@"WatchlistManagerController: Window created successfully");
}

- (void)setupUI {
    if (!self.window) {
        NSLog(@"WatchlistManagerController: ERROR - No window available for UI setup");
        return;
    }
    
    NSView *contentView = self.window.contentView;
    
    // Table view setup
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.tableView = [[NSTableView alloc] init];
    
    // Set delegate and dataSource
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.rowHeight = 28;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    self.tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    
    // Create columns
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = @"Name";
    nameColumn.width = 200;
    [self.tableView addTableColumn:nameColumn];
    
    NSTableColumn *countColumn = [[NSTableColumn alloc] initWithIdentifier:@"count"];
    countColumn.title = @"Symbols";
    countColumn.width = 80;
    [self.tableView addTableColumn:countColumn];
    
    scrollView.documentView = self.tableView;
    [contentView addSubview:scrollView];
    
    // Buttons
    self.addButton = [NSButton buttonWithTitle:@"Create New Watchlist"
                                        target:self
                                        action:@selector(addWatchlist:)];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.addButton];
    
    self.deleteButton = [NSButton buttonWithTitle:@"Delete"
                                           target:self
                                           action:@selector(deleteWatchlist:)];
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteButton.enabled = NO;
    [contentView addSubview:self.deleteButton];
    
    self.doneButton = [NSButton buttonWithTitle:@"Done"
                                         target:self
                                         action:@selector(done:)];
    self.doneButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.doneButton.keyEquivalent = @"\r";
    [contentView addSubview:self.doneButton];
    
    // Auto Layout
    [NSLayoutConstraint activateConstraints:@[
        // ScrollView constraints
        [scrollView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [scrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [scrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.addButton.topAnchor constant:-20],
        
        // Add button constraints
        [self.addButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [self.addButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        
        // Delete button constraints
        [self.deleteButton.leadingAnchor constraintEqualToAnchor:self.addButton.trailingAnchor constant:10],
        [self.deleteButton.bottomAnchor constraintEqualToAnchor:self.addButton.bottomAnchor],
        
        // Done button constraints
        [self.doneButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [self.doneButton.bottomAnchor constraintEqualToAnchor:self.addButton.bottomAnchor]
    ]];
    
    NSLog(@"WatchlistManagerController: UI setup completed");
}

- (void)loadWatchlists {
    self.watchlists = [[DataHub shared] getAllWatchlists];
    NSLog(@"WatchlistManagerController: Loaded %lu watchlists", (unsigned long)self.watchlists.count);
    
    // Log watchlist names for debugging
    for (Watchlist *watchlist in self.watchlists) {
        NSLog(@"WatchlistManagerController: Watchlist - %@ (%lu symbols)",
              watchlist.name, (unsigned long)watchlist.symbols.count);
    }
    
    [self.tableView reloadData];
    
    // Reset selection and button state
    [self.tableView deselectAll:nil];
    self.deleteButton.enabled = NO;
}

#pragma mark - Actions

- (void)addWatchlist:(id)sender {
    NSLog(@"WatchlistManagerController: addWatchlist button clicked");
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Watchlist";
    alert.informativeText = @"Enter a name for the new watchlist:";
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Watchlist Name";
    alert.accessoryView = input;
    
    [alert.window setInitialFirstResponder:input];
    
    NSModalResponse response = [alert runModal];
    NSLog(@"WatchlistManagerController: Alert response: %ld", (long)response);
    
    if (response == NSAlertFirstButtonReturn) {
        NSString *name = [input.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSLog(@"WatchlistManagerController: User entered name: '%@'", name);
        
        if (name.length > 0) {
            // Check if watchlist with same name already exists
            BOOL exists = NO;
            for (Watchlist *watchlist in self.watchlists) {
                if ([watchlist.name isEqualToString:name]) {
                    exists = YES;
                    break;
                }
            }
            
            if (exists) {
                NSLog(@"WatchlistManagerController: Watchlist name already exists");
                NSAlert *errorAlert = [[NSAlert alloc] init];
                errorAlert.messageText = @"Watchlist Already Exists";
                errorAlert.informativeText = [NSString stringWithFormat:@"A watchlist named '%@' already exists.", name];
                [errorAlert addButtonWithTitle:@"OK"];
                [errorAlert runModal];
            } else {
                NSLog(@"WatchlistManagerController: Creating new watchlist: %@", name);
                [[DataHub shared] createWatchlistWithName:name];
                [self loadWatchlists];
                
                if (self.completionHandler) {
                    self.completionHandler(YES);
                }
            }
        } else {
            NSLog(@"WatchlistManagerController: Empty name entered");
        }
    }
}

- (void)deleteWatchlist:(id)sender {
    NSLog(@"WatchlistManagerController: deleteWatchlist button clicked");
    
    NSInteger selectedRow = self.tableView.selectedRow;
    NSLog(@"WatchlistManagerController: Selected row: %ld", (long)selectedRow);
    
    if (selectedRow < 0 || selectedRow >= self.watchlists.count) {
        NSLog(@"WatchlistManagerController: Invalid selection for delete");
        return;
    }
    
    Watchlist *watchlist = self.watchlists[selectedRow];
    NSLog(@"WatchlistManagerController: Attempting to delete: %@", watchlist.name);
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Watchlist?";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the watchlist '%@'? This action cannot be undone.", watchlist.name];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSLog(@"WatchlistManagerController: User confirmed deletion");
        [[DataHub shared] deleteWatchlist:watchlist];
        [self loadWatchlists];
        
        if (self.completionHandler) {
            self.completionHandler(YES);
        }
    } else {
        NSLog(@"WatchlistManagerController: User cancelled deletion");
    }
}

- (void)done:(id)sender {
    NSLog(@"WatchlistManagerController: done button clicked");
    NSLog(@"WatchlistManagerController: Window: %@", self.window);
    NSLog(@"WatchlistManagerController: Sheet parent: %@", self.window.sheetParent);
    
    // Check if window is presented as sheet
    if (self.window.sheetParent) {
        NSLog(@"WatchlistManagerController: Closing as sheet");
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    } else {
        NSLog(@"WatchlistManagerController: Closing as regular window");
        [self.window orderOut:nil];
        if ([NSApp modalWindow] == self.window) {
            NSLog(@"WatchlistManagerController: Stopping modal");
            [NSApp stopModal];
        }
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger count = self.watchlists.count;
    NSLog(@"WatchlistManagerController: numberOfRowsInTableView called, returning %ld", (long)count);
    return count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = tableColumn.identifier;
    NSLog(@"WatchlistManagerController: viewForTableColumn called for row %ld, column %@", (long)row, identifier);
    
    if (row >= self.watchlists.count) {
        NSLog(@"WatchlistManagerController: Row %ld out of bounds (count: %lu)", (long)row, (unsigned long)self.watchlists.count);
        return nil;
    }
    
    Watchlist *watchlist = self.watchlists[row];
    
    // Create or reuse cell view
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cellView) {
        NSLog(@"WatchlistManagerController: Creating new cell view for %@", identifier);
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = identifier;
        
        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.font = [NSFont systemFontOfSize:13];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:5],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-5],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Set content based on column
    if ([identifier isEqualToString:@"name"]) {
        NSString *name = watchlist.name ?: @"";
        cellView.textField.stringValue = name;
        NSLog(@"WatchlistManagerController: Set name cell to: %@", name);
    } else if ([identifier isEqualToString:@"count"]) {
        NSUInteger symbolCount = watchlist.symbols.count;
        NSString *countString = [NSString stringWithFormat:@"%lu", (unsigned long)symbolCount];
        cellView.textField.stringValue = countString;
        cellView.textField.alignment = NSTextAlignmentCenter;
        NSLog(@"WatchlistManagerController: Set count cell to: %@", countString);
    }
    
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.tableView.selectedRow;
    BOOL hasSelection = (selectedRow >= 0);
    self.deleteButton.enabled = hasSelection;
    
    NSLog(@"WatchlistManagerController: tableViewSelectionDidChange - row: %ld, delete enabled: %@",
          (long)selectedRow, hasSelection ? @"YES" : @"NO");
    
    if (hasSelection && selectedRow < self.watchlists.count) {
        Watchlist *selectedWatchlist = self.watchlists[selectedRow];
        NSLog(@"WatchlistManagerController: Selected watchlist: %@", selectedWatchlist.name);
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    NSLog(@"WatchlistManagerController: windowWillClose");
}

@end
