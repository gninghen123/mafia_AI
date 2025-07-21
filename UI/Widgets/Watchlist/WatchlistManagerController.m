//
//  WatchlistManagerController.m
//  mafia_AI
//

#import "WatchlistWidget.h"
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
    nameColumn.title = @"Watchlist Name";
    nameColumn.width = 250;
    [self.tableView addTableColumn:nameColumn];
    
    NSTableColumn *countColumn = [[NSTableColumn alloc] initWithIdentifier:@"count"];
    countColumn.title = @"Symbols";
    countColumn.width = 80;
    [self.tableView addTableColumn:countColumn];
    
    scrollView.documentView = self.tableView;
    
    // Buttons
    self.addButton = [NSButton buttonWithTitle:@"Add" target:self action:@selector(addWatchlist:)];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.deleteButton = [NSButton buttonWithTitle:@"Delete" target:self action:@selector(deleteWatchlist:)];
    self.deleteButton.enabled = NO;
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.doneButton = [NSButton buttonWithTitle:@"Done" target:self action:@selector(done:)];
    self.doneButton.keyEquivalent = @"\r";
    self.doneButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add subviews
    [contentView addSubview:scrollView];
    [contentView addSubview:self.addButton];
    [contentView addSubview:self.deleteButton];
    [contentView addSubview:self.doneButton];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Scroll view
        [scrollView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [scrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [scrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.addButton.topAnchor constant:-20],
        
        // Buttons
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

//
//  AddSymbolController.m
//  mafia_AI
//

@interface AddSymbolController ()
@property (nonatomic, strong) NSTextView *textView;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *cancelButton;
@end

@implementation AddSymbolController

- (instancetype)initWithWatchlist:(Watchlist *)watchlist {
    self = [super initWithWindowNibName:@""];
    if (self) {
        self.watchlist = watchlist;
        [self setupWindow];
    }
    return self;
}

- (void)setupWindow {
    // Create window
    NSRect frame = NSMakeRect(0, 0, 400, 250);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = [NSString stringWithFormat:@"Add Symbols to '%@'", self.watchlist.name];
    self.window = window;
    
    NSView *contentView = window.contentView;
    
    // Instructions label
    NSTextField *label = [NSTextField labelWithString:@"Enter symbols (one per line or comma-separated):"];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Text view with scroll view
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.textView = [[NSTextView alloc] init];
    self.textView.font = [NSFont systemFontOfSize:13];
    self.textView.richText = NO;
    self.textView.automaticQuoteSubstitutionEnabled = NO;
    self.textView.delegate = self;
    
    scrollView.documentView = self.textView;
    
    // Example label
    NSTextField *exampleLabel = [NSTextField labelWithString:@"Example: AAPL, MSFT, GOOGL"];
    exampleLabel.font = [NSFont systemFontOfSize:11];
    exampleLabel.textColor = [NSColor secondaryLabelColor];
    exampleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Buttons
    self.cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancel:)];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.addButton = [NSButton buttonWithTitle:@"Add Symbols" target:self action:@selector(addSymbols:)];
    self.addButton.keyEquivalent = @"\r";
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add subviews
    [contentView addSubview:label];
    [contentView addSubview:scrollView];
    [contentView addSubview:exampleLabel];
    [contentView addSubview:self.cancelButton];
    [contentView addSubview:self.addButton];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Label
        [label.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [label.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [label.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        // Scroll view
        [scrollView.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:10],
        [scrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [scrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [scrollView.bottomAnchor constraintEqualToAnchor:exampleLabel.topAnchor constant:-5],
        
        // Example label
        [exampleLabel.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [exampleLabel.bottomAnchor constraintEqualToAnchor:self.cancelButton.topAnchor constant:-20],
        
        // Buttons
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.addButton.leadingAnchor constant:-10],
        
        [self.addButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        [self.addButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20]
    ]];
    
    // Focus on text view
    [self.window makeFirstResponder:self.textView];
}

#pragma mark - Actions

- (void)addSymbols:(id)sender {
    NSString *text = self.textView.string;
    if (text.length == 0) {
        NSBeep();
        return;
    }
    
    // Parse symbols
    NSMutableArray *symbols = [NSMutableArray array];
    
    // Split by newlines and commas
    NSArray *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSArray *parts = [line componentsSeparatedByString:@","];
        for (NSString *part in parts) {
            NSString *symbol = [[part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
            if (symbol.length > 0) {
                [symbols addObject:symbol];
            }
        }
    }
    
    // Remove duplicates
    NSOrderedSet *uniqueSymbols = [NSOrderedSet orderedSetWithArray:symbols];
    symbols = [[uniqueSymbols array] mutableCopy];
    
    if (symbols.count > 0) {
        if (self.completionHandler) {
            self.completionHandler(symbols);
        }
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    } else {
        NSBeep();
    }
}

- (void)cancel:(id)sender {
    if (self.completionHandler) {
        self.completionHandler(nil);
    }
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification {
    // Auto-capitalize while typing
    NSTextView *textView = notification.object;
    NSString *text = textView.string;
    NSString *upperText = [text uppercaseString];
    
    if (![text isEqualToString:upperText]) {
        NSRange selectedRange = textView.selectedRange;
        textView.string = upperText;
        textView.selectedRange = selectedRange;
    }
}

@end
