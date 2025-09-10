//
//  TagManagementWindowController.m
//  TradingApp
//

#import "TagManagementWindowController.h"
#import "DataHub.h"
#import <objc/runtime.h>

@interface TagManagementWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

// UI Components
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *symbolsLabel;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tagsTableView;
@property (nonatomic, strong) NSTextField *aNewTagField;
@property (nonatomic, strong) NSButton *addTagButton;
@property (nonatomic, strong) NSButton *applyButton;
@property (nonatomic, strong) NSButton *cancelButton;

// Data - Fixed property types
@property (nonatomic, strong, readwrite) NSArray<NSString *> *symbols;
@property (nonatomic, strong) NSMutableArray<NSString *> *allTags;
@property (nonatomic, strong) NSMutableArray<NSString *> *filteredTags;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedTags;
@property (nonatomic, strong) NSMutableSet<NSString *> *existingTagsForSymbols;

@end

@implementation TagManagementWindowController

+ (instancetype)windowControllerForSymbols:(NSArray<NSString *> *)symbols {
    TagManagementWindowController *controller = [[self alloc] init];
    controller.symbols = [symbols copy];
    return controller;
}

- (instancetype)init {
    // Crea la finestra
    NSRect windowFrame = NSMakeRect(0, 0, 400, 500);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled |
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        self.selectedTags = [NSMutableSet set];
        self.existingTagsForSymbols = [NSMutableSet set];
        self.allTags = [NSMutableArray array];
        self.filteredTags = [NSMutableArray array];
        [self setupWindow];
        [self setupUI];
        [self loadData];
    }
    return self;
}

- (NSArray<NSString *> *)selectedTagsArray {
    return [self.selectedTags allObjects];
}

- (void)setupWindow {
    self.window.title = @"Manage Tags";
    self.window.minSize = NSMakeSize(350, 400);
    self.window.maxSize = NSMakeSize(600, 800);
    [self.window center];
}

- (void)setupUI {
    NSView *contentView = self.window.contentView;
    
    // Title label
    self.titleLabel = [NSTextField labelWithString:@"Add Tags to Symbols"];
    self.titleLabel.font = [NSFont boldSystemFontOfSize:16];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.titleLabel];
    
    // Symbols label
    self.symbolsLabel = [NSTextField labelWithString:@""];
    self.symbolsLabel.font = [NSFont systemFontOfSize:12];
    self.symbolsLabel.textColor = [NSColor secondaryLabelColor];
    self.symbolsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.symbolsLabel];
    
    // Search field
    self.searchField = [[NSSearchField alloc] init];
    self.searchField.placeholderString = @"Search tags...";
    self.searchField.target = self;
    self.searchField.action = @selector(searchFieldChanged:);
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.searchField];
    
    // Table view for existing tags
    self.tagsTableView = [[NSTableView alloc] init];
    self.tagsTableView.dataSource = self;
    self.tagsTableView.delegate = self;
    self.tagsTableView.allowsMultipleSelection = YES;
    
    // Create table column
    NSTableColumn *tagColumn = [[NSTableColumn alloc] initWithIdentifier:@"tag"];
    tagColumn.title = @"Available Tags";
    tagColumn.width = 200;
    [self.tagsTableView addTableColumn:tagColumn];
    
    // Scroll view for table
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.documentView = self.tagsTableView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.scrollView];
    
    // New tag field
    self.aNewTagField = [[NSTextField alloc] init];
    self.aNewTagField.placeholderString = @"Create new tag...";
    self.aNewTagField.delegate = self;
    self.aNewTagField.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.aNewTagField];
    
    // Add tag button
    self.addTagButton = [NSButton buttonWithTitle:@"+" target:self action:@selector(addNewTag:)];
    self.addTagButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.addTagButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.addTagButton];
    
    // Bottom buttons
    self.cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancel:)];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.cancelButton];
    
    self.applyButton = [NSButton buttonWithTitle:@"Apply Tags" target:self action:@selector(applyTags:)];
    self.applyButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.applyButton.keyEquivalent = @"\r"; // Enter key
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.applyButton];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    NSView *contentView = self.window.contentView;
    
    [NSLayoutConstraint activateConstraints:@[
        // Title
        [self.titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        
        // Symbols label
        [self.symbolsLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [self.symbolsLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        
        // Search field
        [self.searchField.topAnchor constraintEqualToAnchor:self.symbolsLabel.bottomAnchor constant:20],
        [self.searchField.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [self.searchField.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        // Table view
        [self.scrollView.topAnchor constraintEqualToAnchor:self.searchField.bottomAnchor constant:10],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [self.scrollView.heightAnchor constraintEqualToConstant:200],
        
        // New tag field and button
        [self.aNewTagField.topAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:15],
        [self.aNewTagField.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [self.aNewTagField.trailingAnchor constraintEqualToAnchor:self.addTagButton.leadingAnchor constant:-8],
        
        [self.addTagButton.centerYAnchor constraintEqualToAnchor:self.aNewTagField.centerYAnchor],
        [self.addTagButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [self.addTagButton.widthAnchor constraintEqualToConstant:30],
        
        // Bottom buttons
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        [self.cancelButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        
        [self.applyButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
        [self.applyButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [self.applyButton.widthAnchor constraintEqualToConstant:100]
    ]];
}

- (void)loadData {
    // Update symbols label
    if (self.symbols.count == 1) {
        self.symbolsLabel.stringValue = [NSString stringWithFormat:@"Symbol: %@", self.symbols[0]];
    } else {
        self.symbolsLabel.stringValue = [NSString stringWithFormat:@"%ld symbols selected", (long)self.symbols.count];
    }
    
    // Load all available tags
    NSArray *tagsFromDataHub = [[DataHub shared] getAllTags];
    [self.allTags removeAllObjects];
    [self.allTags addObjectsFromArray:tagsFromDataHub];
    
    [self.filteredTags removeAllObjects];
    [self.filteredTags addObjectsFromArray:self.allTags];
    
    // Load existing tags for selected symbols
    [self loadExistingTagsForSymbols];
    
    [self.tagsTableView reloadData];
    [self updateApplyButtonState];
}

- (void)loadExistingTagsForSymbols {
    [self.existingTagsForSymbols removeAllObjects];
    
    DataHub *dataHub = [DataHub shared];
    for (NSString *symbolName in self.symbols) {
        Symbol *symbol = [dataHub getSymbolWithName:symbolName];
        if (symbol && symbol.tags) {
            [self.existingTagsForSymbols addObjectsFromArray:symbol.tags];
        }
    }
}

#pragma mark - Actions

- (void)searchFieldChanged:(id)sender {
    NSString *searchText = self.searchField.stringValue;
    
    [self.filteredTags removeAllObjects];
    
    if (searchText.length == 0) {
        [self.filteredTags addObjectsFromArray:self.allTags];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", searchText];
        NSArray *filtered = [self.allTags filteredArrayUsingPredicate:predicate];
        [self.filteredTags addObjectsFromArray:filtered];
    }
    
    [self.tagsTableView reloadData];
}

- (void)addNewTag:(id)sender {
    NSString *newTag = [self.aNewTagField.stringValue stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (newTag.length == 0) return;
    
    // Normalizza il tag
    newTag = newTag.lowercaseString;
    
    // Controlla se esiste già
    if ([self.allTags containsObject:newTag]) {
        // Se esiste, selezionalo
        [self.selectedTags addObject:newTag];
        NSInteger index = [self.filteredTags indexOfObject:newTag];
        if (index != NSNotFound) {
            [self.tagsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:YES];
        }
    } else {
        // Aggiungi nuovo tag alla lista
        [self.allTags addObject:newTag];
        [self.allTags sortUsingSelector:@selector(compare:)];
        
        // Aggiorna filteredTags
        [self searchFieldChanged:self.searchField];
        
        // Seleziona il nuovo tag
        [self.selectedTags addObject:newTag];
        NSInteger index = [self.filteredTags indexOfObject:newTag];
        if (index != NSNotFound) {
            [self.tagsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:YES];
        }
    }
    
    // Pulisci il campo
    self.aNewTagField.stringValue = @"";
    [self updateApplyButtonState];
}

- (void)applyTags:(id)sender {
    if (self.selectedTags.count == 0) return;
    
    // Notifica il delegate
    if (self.delegate) {
        [self.delegate tagManagement:self
                       didSelectTags:[self.selectedTags allObjects]
                          forSymbols:self.symbols];
    }
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (void)cancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)updateApplyButtonState {
    self.applyButton.enabled = self.selectedTags.count > 0;
    
    if (self.selectedTags.count == 0) {
        self.applyButton.title = @"Apply Tags";
    } else {
        self.applyButton.title = [NSString stringWithFormat:@"Apply %ld Tags", (long)self.selectedTags.count];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredTags.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= 0 && row < self.filteredTags.count) {
        return self.filteredTags[row];
    }
    return nil;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"TagCell" owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = @"TagCell";
        
        // Text field
        NSTextField *textField = [[NSTextField alloc] init];
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.editable = NO;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        // Checkbox
        NSButton *checkbox = [[NSButton alloc] init];
        checkbox.buttonType = NSButtonTypeSwitch;
        checkbox.title = @"";
        checkbox.target = self;
        checkbox.action = @selector(tagCheckboxChanged:);
        checkbox.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:checkbox];
        
        // Store checkbox reference using associated object
        objc_setAssociatedObject(cellView, "checkbox", checkbox, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Constraints
        [NSLayoutConstraint activateConstraints:@[
            [checkbox.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:5],
            [checkbox.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor],
            [checkbox.widthAnchor constraintEqualToConstant:20],
            
            [textField.leadingAnchor constraintEqualToAnchor:checkbox.trailingAnchor constant:5],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-5],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    // Configure cell
    NSString *tag = self.filteredTags[row];
    cellView.textField.stringValue = tag;
    
    NSButton *checkbox = objc_getAssociatedObject(cellView, "checkbox");
    checkbox.tag = row;
    checkbox.state = [self.selectedTags containsObject:tag] ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Visual indication for existing tags
    if ([self.existingTagsForSymbols containsObject:tag]) {
        cellView.textField.textColor = [NSColor systemBlueColor];
        cellView.textField.font = [NSFont boldSystemFontOfSize:12];
    } else {
        cellView.textField.textColor = [NSColor labelColor];
        cellView.textField.font = [NSFont systemFontOfSize:12];
    }
    
    return cellView;
}

- (void)tagCheckboxChanged:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row >= 0 && row < self.filteredTags.count) {
        NSString *tag = self.filteredTags[row];
        
        if (sender.state == NSControlStateValueOn) {
            [self.selectedTags addObject:tag];
        } else {
            [self.selectedTags removeObject:tag];
        }
        
        [self updateApplyButtonState];
    }
}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        // Enter key pressed in new tag field
        [self addNewTag:control];
        return YES;
    }
    return NO;
}

#pragma mark - Modal Presentation

- (void)showModalForWindow:(NSWindow *)parentWindow {
    if (parentWindow) {
        [parentWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
            // Sheet completed
        }];
    } else {
        [NSApp runModalForWindow:self.window];
    }
}

@end
