//
//  WatchlistManagerController.m
//  mafia_AI
//

#import "WatchlistManagerController.h"  // QUESTO È IL FIX PRINCIPALE!
#import "DataHub.h"
#import "Watchlist+CoreDataClass.h"
#import "AddSymbolController.h"

@interface WatchlistManagerController ()
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSArray<Watchlist *> *watchlists;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *deleteButton;
@property (nonatomic, strong) NSButton *doneButton;
@end

@implementation WatchlistManagerController

- (instancetype)init {
    self = [super initWithWindowNibName:@""];
    if (self) {
        [self setupWindow];
        [self loadWatchlists];
    }
    return self;
}

- (void)setupWindow {
    // Create window
    NSRect frame = NSMakeRect(0, 0, 400, 300);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Manage Watchlists";
    window.minSize = NSMakeSize(300, 200);
    self.window = window;
    
    NSView *contentView = window.contentView;
    
    // Table view
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 24;
    self.tableView.allowsMultipleSelection = NO;
    
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
    self.addButton = [NSButton buttonWithTitle:@"Add" target:self action:@selector(addWatchlist:)];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.addButton];
    
    self.deleteButton = [NSButton buttonWithTitle:@"Delete" target:self action:@selector(deleteWatchlist:)];
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteButton.enabled = NO;
    [contentView addSubview:self.deleteButton];
    
    self.doneButton = [NSButton buttonWithTitle:@"Done" target:self action:@selector(done:)];
    self.doneButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.doneButton];
    
    // Auto Layout
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [scrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [scrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.addButton.topAnchor constant:-20],
        
        [self.addButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [self.addButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        
        [self.deleteButton.leadingAnchor constraintEqualToAnchor:self.addButton.trailingAnchor constant:10],
        [self.deleteButton.bottomAnchor constraintEqualToAnchor:self.addButton.bottomAnchor],
        
        [self.doneButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [self.doneButton.bottomAnchor constraintEqualToAnchor:self.addButton.bottomAnchor]
    ]];
}

- (void)loadWatchlists {
    self.watchlists = [[DataHub shared] getAllWatchlists];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)addWatchlist:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Watchlist";
    alert.informativeText = @"Enter a name for the new watchlist:";
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    alert.accessoryView = input;
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *name = input.stringValue;
        if (name.length > 0) {
            [[DataHub shared] createWatchlistWithName:name];
            [self loadWatchlists];
            
            if (self.completionHandler) {
                self.completionHandler(YES);
            }
        }
    }
}

- (void)deleteWatchlist:(id)sender {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.watchlists.count) return;
    
    Watchlist *watchlist = self.watchlists[selectedRow];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Watchlist?";
    alert.informativeText = [NSString stringWithFormat:@"Delete watchlist '%@'?", watchlist.name];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [[DataHub shared] deleteWatchlist:watchlist];
        [self loadWatchlists];
        
        if (self.completionHandler) {
            self.completionHandler(YES);
        }
    }
}

- (void)done:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.watchlists.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.watchlists.count) return nil;
    
    Watchlist *watchlist = self.watchlists[row];
    
    if ([tableColumn.identifier isEqualToString:@"name"]) {
        return watchlist.name;
    } else if ([tableColumn.identifier isEqualToString:@"count"]) {
        return [NSString stringWithFormat:@"%lu", (unsigned long)watchlist.symbols.count];
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    self.deleteButton.enabled = (self.tableView.selectedRow >= 0);
}

@end
